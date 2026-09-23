#!/usr/bin/env bash
# Busca o PROPOSTA.md de cada equipe do CSV, do jeito que ele está agora
# para revisão, e classifica cada uma em "fonte" para que quem for
# avaliar (ex: a skill avaliar-propostas) saiba o que já foi decidido e
# não precisa reavaliar:
#
#   pendente          — PR de proposta aberta, ainda sem aprovação do
#                        code owner (professor). É o caso que precisa de
#                        avaliação.
#   aprovada-pr        — PR de proposta aberta, já aprovada pelo code
#                        owner (branch protection exige 1 aprovação de
#                        code owner para mesclar — reviewDecision da API
#                        do GitHub). Decisão já tomada, só falta mesclar.
#   aprovada-mesclada  — sem PR aberta, mas há PROPOSTA.md na branch
#                        padrão: só chega lá depois de aprovada (mesma
#                        exigência de branch protection). Decisão já
#                        tomada.
#   ausente            — sem PR aberta e sem PROPOSTA.md na branch
#                        padrão: equipe ainda não enviou proposta.
#
# Só lê pela API — não clona nada. Proposta é texto (não há código pra
# cruzar nesse estágio do fluxo), então não há necessidade de clone raso
# como em coletar-entregas.sh (atividades práticas).
#
# Uso: ./coletar-propostas.sh --config disciplina.env equipes.csv [pasta-destino]
#
# Saída em pasta-destino/:
#   <slug-do-tema>.md   — conteúdo do PROPOSTA.md (quando encontrado)
#   _propostas.csv      — tema,slug,repo,pr_url,fonte

set -uo pipefail

# Evita que o gh mande respostas para um pager interativo (less, via
# $PAGER/$GH_PAGER do usuário), o que pausaria o script em cada
# repositório do loop esperando 'q'.
export GH_PAGER=cat

if [ "${1:-}" != "--config" ] || [ -z "${2:-}" ]; then
  echo "Uso: $0 --config disciplina.env equipes.csv [pasta-destino]"
  exit 1
fi

CONFIG="$2"
CSV="${3:-equipes.csv}"
DESTINO="${4:-./propostas-coletadas}"

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
if [ "$IDX_TEMA" -lt 0 ]; then
  echo "O cabeçalho do CSV precisa ter a coluna 'tema' (outras colunas são ignoradas)."
  exit 1
fi

slugificar() {
  # Mesma normalização de scripts/clonar-tudo.sh, para que o nome do
  # repositório calculado aqui bata com o que criar-repos.sh de fato criou.
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

mkdir -p "$DESTINO"
SAIDA_CSV="$DESTINO/_propostas.csv"
echo "tema,slug,repo,pr_url,fonte" > "$SAIDA_CSV"

total=0
pendentes=0
aprovadas=0
ausentes=0

while IFS=$'\x1f' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  tema="${campos[$IDX_TEMA]:-}"
  [ -z "$tema" ] && continue
  total=$((total + 1))
  slug=$(slugificar "$tema")
  repo="$ORG/${PREFIXO_REPO}-${slug}"
  arquivo="$DESTINO/$slug.md"

  if ! gh repo view "$repo" >/dev/null 2>&1; then
    echo "❌ $tema — repositório não existe ($repo)"
    echo "\"$tema\",$slug,$repo,,ausente" >> "$SAIDA_CSV"
    ausentes=$((ausentes + 1))
    continue
  fi

  # PR de proposta aberta mais recente (se houver mais de uma, algo
  # incomum já mereceria uma olhada manual — pega a mais recente), com o
  # reviewDecision que a própria API do GitHub calcula a partir da
  # exigência de branch protection (1 aprovação de code owner).
  pr_info=$(gh pr list --repo "$repo" --state open --json number,url,headRefName,reviewDecision \
    --jq 'sort_by(.number) | last | "\(.url)\t\(.headRefName)\t\(.reviewDecision // "")"' 2>/dev/null)

  if [ -n "$pr_info" ]; then
    IFS=$'\t' read -r pr_url head_ref review_decision <<< "$pr_info"

    if [ "$review_decision" = "APPROVED" ]; then
      echo "🟢 $tema — PR já aprovada pelo professor, não avaliada ($pr_url)"
      echo "\"$tema\",$slug,$repo,$pr_url,aprovada-pr" >> "$SAIDA_CSV"
      aprovadas=$((aprovadas + 1))
      continue
    fi

    if conteudo=$(gh api "repos/$repo/contents/PROPOSTA.md?ref=$head_ref" \
        -H "Accept: application/vnd.github.raw" 2>/dev/null); then
      printf '%s\n' "$conteudo" > "$arquivo"
      echo "✅ $tema — PR aberta, pendente de avaliação ($pr_url)"
      echo "\"$tema\",$slug,$repo,$pr_url,pendente" >> "$SAIDA_CSV"
      pendentes=$((pendentes + 1))
      continue
    fi
  fi

  # Sem PR aberta pendente — tenta a branch padrão. Só chega lá depois de
  # aprovada (mesma exigência de branch protection), então já é decisão
  # tomada, não precisa reavaliar.
  if conteudo=$(gh api "repos/$repo/contents/PROPOSTA.md" \
      -H "Accept: application/vnd.github.raw" 2>/dev/null); then
    printf '%s\n' "$conteudo" > "$arquivo"
    echo "🟢 $tema — já mesclada (aprovada), não avaliada"
    echo "\"$tema\",$slug,$repo,,aprovada-mesclada" >> "$SAIDA_CSV"
    aprovadas=$((aprovadas + 1))
  else
    echo "❌ $tema — sem PR aberta e sem PROPOSTA.md na branch padrão (ainda não enviou)"
    echo "\"$tema\",$slug,$repo,,ausente" >> "$SAIDA_CSV"
    ausentes=$((ausentes + 1))
  fi
done < <(tail -n +2 "$CSV" | tr -d '\r' | csv_para_campos)

echo ""
echo "Concluído: $total equipe(s) — $pendentes pendente(s) de avaliação, $aprovadas já aprovada(s) (não avaliadas), $ausentes sem proposta."
echo "Conteúdo em $DESTINO/ ($(basename "$SAIDA_CSV") tem tema, repo, PR e a coluna 'fonte' com a classificação)."
