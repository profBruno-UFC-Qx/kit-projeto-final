#!/usr/bin/env bash
# Estima quantas equipes ainda vão entregar o projeto final, olhando a
# atividade de cada repositório no GitHub (commits dos alunos em todas as
# branches + situação da PR de proposta). Útil no meio/fim do semestre,
# quando alunos desistem da disciplina e as equipes param de aparecer.
#
# Classificação de cada equipe:
#
#   ✅ ativa          — commit de CÓDIGO nos últimos DIAS_ATIVA dias.
#                       "Código" = commit que mexe em algum arquivo além
#                       de PROPOSTA.md / ENTREGA.md / README.md (editar
#                       só a proposta não conta como desenvolvimento).
#   ⚠️  incerta       — algum commit de aluno nos últimos DIAS_INCERTA
#                       dias, mas sem código recente (ex: só mandou a
#                       proposta agora, ou o código parou há pouco).
#   ❌ parada         — teve commits de aluno, mas nada há mais de
#                       DIAS_INCERTA dias.
#   💤 sem atividade  — nenhum commit de aluno desde a criação.
#
# Commits do professor (dono do token do gh), de bots e o "Initial
# commit" do template não contam como atividade.
#
# Limitação: só enxerga o que foi enviado ao GitHub (qualquer branch).
# Equipe que programa só localmente ou em outro repositório aparece como
# parada — confirme as incertas/paradas com os alunos antes de concluir.
#
# Também aponta:
#   - equipes em que só UMA pessoa fez commit no período recente (possível
#     desistência dos colegas). Autor é o login do GitHub quando o e-mail
#     do commit está vinculado à conta; senão, o nome configurado no git —
#     então a mesma pessoa pode, raramente, aparecer duas vezes.
#   - repositórios com o prefixo da disciplina que não estão no CSV.
#
# Só lê pela API — não altera nada. Pode rodar quantas vezes quiser.
#
# Uso: ./verificar-atividade.sh --config disciplina.env equipes.csv [relatorio.csv]
#
# Limiares ajustáveis por variável de ambiente (padrão 14 e 30 dias):
#   DIAS_ATIVA=7 DIAS_INCERTA=21 ./verificar-atividade.sh --config ...
#
# Se relatorio.csv for informado, grava também:
#   tema,repo,situacao,dias_ultimo_codigo,dias_ultima_atividade,proposta,autores_recentes

set -uo pipefail

# Evita que o gh mande respostas para um pager interativo (less, via
# $PAGER/$GH_PAGER do usuário), o que pausaria o script em cada
# repositório do loop esperando 'q'.
export GH_PAGER=cat

if [ "${1:-}" != "--config" ] || [ -z "${2:-}" ]; then
  echo "Uso: $0 --config disciplina.env equipes.csv [relatorio.csv]"
  exit 1
fi

CONFIG="$2"
CSV="${3:-equipes.csv}"
RELATORIO="${4:-}"
DIAS_ATIVA="${DIAS_ATIVA:-14}"
DIAS_INCERTA="${DIAS_INCERTA:-30}"

if [ ! -f "$CONFIG" ]; then
  echo "Config não encontrada: $CONFIG"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"

: "${ORG:?defina ORG em $CONFIG}"
: "${PREFIXO_REPO:?defina PREFIXO_REPO em $CONFIG}"

if [ ! -f "$CSV" ]; then
  echo "Arquivo não encontrado: $CSV"
  exit 1
fi

csv_para_campos() {
  # Converte cada linha da entrada padrão (CSV no formato RFC 4180) em
  # campos separados por \x1f, respeitando vírgulas e aspas dentro de
  # campos entre aspas (comum em exports do Google Forms/Sheets quando um
  # campo de texto livre, ex: "tema", contém vírgula).
  awk '
    BEGIN { FS = "" }
    {
      campo = ""; dentro = 0; out = "";
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (dentro) {
          if (c == "\"") {
            if (substr($0, i + 1, 1) == "\"") { campo = campo "\""; i++ }
            else dentro = 0
          } else campo = campo c
        } else {
          if (c == "\"") dentro = 1
          else if (c == ",") { out = out campo "\x1f"; campo = "" }
          else campo = campo c
        }
      }
      print out campo
    }
  '
}

indice_coluna() {
  # Índice (0-based) da coluna $1 no cabeçalho do CSV, ou -1 se não achar.
  local procurado="$1" i=0 nome
  local -a colunas
  IFS=$'\x1f' read -ra colunas < <(head -n 1 "$CSV" | tr -d '\r' | csv_para_campos)
  for nome in "${colunas[@]}"; do
    nome=$(printf '%s' "$nome" | xargs | tr '[:upper:]' '[:lower:]')
    [ "$nome" = "$procurado" ] && { echo "$i"; return; }
    i=$((i + 1))
  done
  echo -1
}

IDX_TEMA=$(indice_coluna "tema")
IDX_USUARIOS=$(indice_coluna "usuarios_github")
if [ "$IDX_TEMA" -lt 0 ] || [ "$IDX_USUARIOS" -lt 0 ]; then
  echo "O cabeçalho do CSV precisa ter as colunas 'tema' e 'usuarios_github' (outras colunas são ignoradas)."
  exit 1
fi

slugificar() {
  printf '%s' "$1" \
    | sed -E \
        -e 's/[áàâãä]/a/g; s/[ÁÀÂÃÄ]/a/g' \
        -e 's/[éèêë]/e/g; s/[ÉÈÊË]/e/g' \
        -e 's/[íìîï]/i/g; s/[ÍÌÎÏ]/i/g' \
        -e 's/[óòôõö]/o/g; s/[ÓÒÔÕÖ]/o/g' \
        -e 's/[úùûü]/u/g; s/[ÚÙÛÜ]/u/g' \
        -e 's/[çÇ]/c/g' -e 's/[ñÑ]/n/g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

csv_escapar() {
  # Envolve em aspas e duplica aspas internas (RFC 4180).
  printf '"%s"' "$(printf '%s' "$1" | sed 's/"/""/g')"
}

PROFESSOR=$(gh api user --jq '.login' 2>/dev/null | tr '[:upper:]' '[:lower:]')
if [ -z "$PROFESSOR" ]; then
  echo "Não consegui identificar o usuário do gh — rode 'gh auth status'."
  exit 1
fi

commits_de_alunos() {
  # Saída: sha<TAB>autor<TAB>dias_atras, um por commit (deduplicado entre
  # branches), só de alunos, do mais recente para o mais antigo.
  local repo="$1" branch
  gh api "repos/$repo/branches" --paginate --jq '.[].name' 2>/dev/null \
    | while IFS= read -r branch; do
        gh api "repos/$repo/commits?sha=$branch&per_page=100" --paginate --jq '
          .[] | [ .sha,
                  (.author.login // .commit.author.name),
                  (((now - (.commit.author.date | fromdateiso8601)) / 86400) | floor)
                ] | @tsv' 2>/dev/null
      done \
    | sort -u -t $'\t' -k1,1 \
    | awk -F'\t' -v prof="$PROFESSOR" '
        { a = tolower($2) }
        a == prof || a ~ /\[bot\]$/ || a == "web-flow" || a == "github" { next }
        { print }
      ' \
    | sort -t $'\t' -k3,3n
}

commit_tem_codigo() {
  # 0 se o commit mexe em algum arquivo além de PROPOSTA/ENTREGA/README.
  gh api "repos/$1/commits/$2" --jq '.files[].filename' 2>/dev/null \
    | grep -qvE '^(PROPOSTA|ENTREGA|README)\.md$'
}

situacao_proposta() {
  # Mesma regra de coletar-propostas.sh: PR mesclada prova aprovação
  # (branch protection exige aprovação do code owner para mesclar).
  local prs
  prs=$(gh api "repos/$1/pulls?state=all&per_page=100" --paginate \
          --jq '.[] | [.state, (.merged_at != null)] | @tsv' 2>/dev/null)
  if grep -q $'\ttrue$' <<< "$prs"; then
    echo "mesclada"
  elif grep -q '^open' <<< "$prs"; then
    echo "PR aberta"
  else
    echo "sem PR"
  fi
}

ativas=(); incertas=(); paradas=(); sem_atividade=(); nao_encontrados=()
uma_pessoa=()
repos_esperados=""
total=0

if [ -n "$RELATORIO" ]; then
  echo "tema,repo,situacao,dias_ultimo_codigo,dias_ultima_atividade,proposta,autores_recentes" > "$RELATORIO"
fi

echo "Limiares: ativa = código nos últimos $DIAS_ATIVA dias; incerta = alguma atividade nos últimos $DIAS_INCERTA dias."
echo ""

while IFS=$'\x1f' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  tema=$(printf "%s" "${campos[$IDX_TEMA]:-}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
  usuarios="${campos[$IDX_USUARIOS]:-}"
  [ -z "$tema" ] && continue
  slug=$(slugificar "$tema")
  nome_repo="${PREFIXO_REPO}-${slug}"
  repo="$ORG/$nome_repo"
  repos_esperados="$repos_esperados$nome_repo"$'\n'
  total=$((total + 1))

  echo "== $repo =="

  if ! gh api "repos/$repo" --jq '.name' >/dev/null 2>&1; then
    echo "  ❓ repositório não encontrado (rode criar-repos.sh?)"
    nao_encontrados+=("$tema")
    [ -n "$RELATORIO" ] && echo "$(csv_escapar "$tema"),$repo,nao-encontrado,,,," >> "$RELATORIO"
    continue
  fi

  commits=$(commits_de_alunos "$repo")
  proposta=$(situacao_proposta "$repo")

  dias_ultima=""
  dias_codigo=""
  if [ -n "$commits" ]; then
    dias_ultima=$(head -n 1 <<< "$commits" | cut -f3)
    # Só inspeciona arquivos dos commits dentro da janela de "ativa" (do
    # mais recente para o mais antigo, parando no primeiro com código) —
    # evita uma chamada de API por commit em repositórios grandes.
    while IFS=$'\t' read -r sha _autor dias; do
      [ "$dias" -gt "$DIAS_ATIVA" ] && break
      if commit_tem_codigo "$repo" "$sha"; then
        dias_codigo="$dias"
        break
      fi
    done <<< "$commits"
  fi

  # Autores com commit nos últimos DIAS_INCERTA dias: "login(n) login(n)"
  autores=$(awk -F'\t' -v lim="$DIAS_INCERTA" 'NF >= 3 && $3 <= lim { n[$2]++ }
                END { for (a in n) printf "%s(%d) ", a, n[a] }' <<< "$commits" | sed 's/ $//')
  n_autores=$(awk -F'\t' -v lim="$DIAS_INCERTA" 'NF >= 3 && $3 <= lim { print $2 }' <<< "$commits" | sort -u | grep -c .)
  n_equipe=$(printf '%s' "$usuarios" | tr ';' '\n' | grep -c '[^[:space:]]')

  if [ -n "$dias_codigo" ]; then
    situacao="ativa"
    echo "  ✅ ativa — último commit de código há $dias_codigo dia(s)"
    ativas+=("$tema")
  elif [ -n "$dias_ultima" ] && [ "$dias_ultima" -le "$DIAS_INCERTA" ]; then
    situacao="incerta"
    echo "  ⚠️  incerta — último commit há $dias_ultima dia(s), sem código nos últimos $DIAS_ATIVA dias"
    incertas+=("$tema")
  elif [ -n "$dias_ultima" ]; then
    situacao="parada"
    echo "  ❌ parada — último commit de aluno há $dias_ultima dia(s)"
    paradas+=("$tema")
  else
    situacao="sem-atividade"
    echo "  💤 sem atividade — nenhum commit de aluno"
    sem_atividade+=("$tema")
  fi
  echo "     proposta: $proposta${autores:+ | autores (últimos $DIAS_INCERTA dias): $autores}"

  if [ "$n_autores" -eq 1 ] && [ "$n_equipe" -ge 2 ] && [ "$situacao" != "parada" ]; then
    uma_pessoa+=("$tema — $autores (equipe de $n_equipe no CSV)")
  fi

  if [ -n "$RELATORIO" ]; then
    echo "$(csv_escapar "$tema"),$repo,$situacao,$dias_codigo,$dias_ultima,$proposta,$(csv_escapar "$autores")" >> "$RELATORIO"
  fi
done < <(tail -n +2 "$CSV" | tr -d '\r' | csv_para_campos)

listar() {
  # $1 = rótulo, demais = temas
  local rotulo="$1"; shift
  echo "  $rotulo: $#"
  local t
  for t in "$@"; do echo "     - $t"; done
}

echo ""
echo "================ Resumo ================"
listar "✅ ativas" ${ativas[@]+"${ativas[@]}"}
listar "⚠️  incertas" ${incertas[@]+"${incertas[@]}"}
listar "❌ paradas" ${paradas[@]+"${paradas[@]}"}
listar "💤 sem atividade" ${sem_atividade[@]+"${sem_atividade[@]}"}
[ "${#nao_encontrados[@]}" -gt 0 ] && listar "❓ repositório não encontrado" "${nao_encontrados[@]}"

n_ativas=${#ativas[@]}
n_incertas=${#incertas[@]}
echo ""
echo "Estimativa de entregas: $n_ativas a $((n_ativas + n_incertas)) de $total equipe(s)."

if [ "${#uma_pessoa[@]}" -gt 0 ]; then
  echo ""
  echo "Só uma pessoa fez commit nos últimos $DIAS_INCERTA dias (colegas desistiram?):"
  for t in "${uma_pessoa[@]}"; do echo "  - $t"; done
fi

extras=$(gh repo list "$ORG" --limit 1000 --json name --jq '.[].name' 2>/dev/null \
           | grep "^${PREFIXO_REPO}-" \
           | grep -vxF -f <(printf '%s' "$repos_esperados") || true)
if [ -n "$extras" ]; then
  echo ""
  echo "Repositórios com prefixo ${PREFIXO_REPO}- que não estão no CSV:"
  while IFS= read -r r; do echo "  - $ORG/$r"; done <<< "$extras"
fi

[ -n "$RELATORIO" ] && echo "" && echo "Relatório gravado em $RELATORIO"
exit 0
