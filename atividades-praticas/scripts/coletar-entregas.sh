#!/usr/bin/env bash
# Clona (raso, --depth=1) o template da atividade e o repositório de cada
# aluno do CSV, um por pasta. Serve de base para cruzar o RELATO.md com o
# código de fato entregue: comparando cada repositório de aluno com
# `_template/` dá pra ver exatamente o que o aluno mudou, sem o ruído do
# boilerplate do template (wrapper do Gradle, workflows, etc.).
#
# Clone raso: pega só o estado final da entrega, não o histórico de
# commits — suficiente para comparar código, mais rápido e mais leve que
# um clone completo. Se algum dia precisar do histórico (ex: quantas
# tentativas/commits um aluno levou), use scripts/clonar-tudo.sh como
# referência para um clone completo.
#
# Qual estado é "a entrega": a main é protegida, então o aluno entrega por
# PR — e nem todo aluno mescla o PR. Por isso o script olha o PR mais
# recente (maior número) do repositório: se ele ainda está aberto, a pasta
# do aluno fica no head desse PR (refs/pull/N/head, que existe mesmo se a
# branch foi apagada); se foi mesclado ou não há PR, fica na branch padrão.
# Um PR aberto antigo, superado por um PR mais novo já mesclado, é
# ignorado.
#
# Além das pastas, grava <pasta-destino>/_entregas.tsv com, por aluno:
# usuário, nome (se o CSV tiver a coluna "nome"), de onde veio o código
# (main / PR#N aberto / sem repositório) e o estado de todos os PRs. Mais
# de um PR aberto (comum em quem edita pelo editor web do GitHub, que abre
# um PR por arquivo editado) gera aviso: a entrega pode estar espalhada
# entre eles e precisa ser remontada à mão.
#
# Pasta de destino é local e não deve ser versionada (contém código de
# alunos) — o .gitignore do kit já ignora "entregas-*/".
#
# Reexecutável: repositório já clonado é atualizado (fetch + checkout do
# estado da entrega) em vez de clonado de novo — alterações locais nas
# pastas dos alunos são descartadas.
#
# Uso: ./coletar-entregas.sh --config config/pp01.env roster.csv [pasta-destino]

set -uo pipefail

# Evita que o gh mande respostas para um pager interativo (less, via
# $PAGER/$GH_PAGER do usuário), o que pausaria o script em cada
# repositório do loop esperando 'q'.
export GH_PAGER=cat

if [ "${1:-}" != "--config" ] || [ -z "${2:-}" ]; then
  echo "Uso: $0 --config config/ppNN.env roster.csv [pasta-destino]"
  exit 1
fi

CONFIG="$2"
CSV="${3:-roster.csv}"
DESTINO="${4:-./entregas-relatos}"

if [ ! -f "$CONFIG" ]; then
  echo "Config não encontrada: $CONFIG"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"

: "${ORG:?defina ORG em $CONFIG}"
: "${PREFIXO_REPO:?defina PREFIXO_REPO em $CONFIG}"
: "${TEMPLATE_REPO:?defina TEMPLATE_REPO em $CONFIG}"

if [ ! -f "$CSV" ]; then
  echo "Arquivo não encontrado: $CSV"
  exit 1
fi

csv_para_campos() {
  # Converte cada linha da entrada padrão (CSV no formato RFC 4180) em
  # campos separados por \x1f, respeitando vírgulas e aspas dentro de
  # campos entre aspas (comum em exports do Google Forms/Sheets quando um
  # campo de texto livre, ex: "nome", contém vírgula).
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

IDX_USUARIO=$(indice_coluna "usuario_github")
if [ "$IDX_USUARIO" -lt 0 ]; then
  echo "O cabeçalho do CSV precisa ter a coluna 'usuario_github' (outras colunas são ignoradas)."
  exit 1
fi

IDX_NOME=$(indice_coluna "nome")

extrair_usuario() {
  printf '%s' "$1" \
    | xargs \
    | sed -E 's#^(https?://)?(www\.)?github\.com/##i; s#/+$##'
}

clonar_ou_atualizar() {
  # $1 = repo (org/nome), $2 = pasta de destino, $3 = ref a deixar no
  # checkout (opcional; padrão = branch padrão do remoto)
  local repo="$1" pasta="$2" ref="${3:-HEAD}"
  if [ ! -d "$pasta/.git" ]; then
    gh repo clone "$repo" "$pasta" -- --depth=1 -q || return 1
    [ "$ref" = "HEAD" ] && return 0
  fi
  git -C "$pasta" fetch --depth=1 -q origin "$ref" \
    && git -C "$pasta" checkout -q -f --detach FETCH_HEAD
}

# Imprime "numero estado" de todos os PRs do repositório, do mais recente
# para o mais antigo (estado: OPEN, MERGED ou CLOSED).
listar_prs() {
  gh pr list -R "$1" --state all --limit 100 --json number,state \
    --jq 'sort_by(-.number)[] | "\(.number) \(.state)"'
}

mkdir -p "$DESTINO"

echo "== Template ($TEMPLATE_REPO) =="
if clonar_ou_atualizar "$TEMPLATE_REPO" "$DESTINO/_template"; then
  echo "  ok"
else
  echo "  ⚠️  não consegui clonar/atualizar o template — o diff contra o template não vai funcionar"
fi

usuarios=()
nomes=()
while IFS=$'\x1f' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  usuario=$(extrair_usuario "${campos[$IDX_USUARIO]:-}")
  [ -z "$usuario" ] && continue
  usuarios+=("$usuario")
  if [ "$IDX_NOME" -ge 0 ]; then
    nomes+=("$(printf '%s' "${campos[$IDX_NOME]:-}" | xargs)")
  else
    nomes+=("")
  fi
done < <(tail -n +2 "$CSV" | tr -d '\r' | csv_para_campos)

if [ "${#usuarios[@]}" -eq 0 ]; then
  echo "Nenhum aluno encontrado em $CSV."
  exit 1
fi

echo ""
echo "== ${#usuarios[@]} aluno(s) =="
MANIFESTO="$DESTINO/_entregas.tsv"
printf 'usuario\tnome\torigem\tprs\n' > "$MANIFESTO"

sem_repo=0
sem_relato=0
em_pr_aberto=0
for i in "${!usuarios[@]}"; do
  usuario="${usuarios[$i]}"
  nome="${nomes[$i]}"
  repo="$ORG/${PREFIXO_REPO}-${usuario}"
  pasta="$DESTINO/$usuario"

  if ! gh repo view "$repo" >/dev/null 2>&1; then
    echo "❌ $usuario — repositório não existe ($repo)"
    printf '%s\t%s\tsem repositório\t\n' "$usuario" "$nome" >> "$MANIFESTO"
    sem_repo=$((sem_repo + 1))
    continue
  fi

  prs=$(listar_prs "$repo")
  ultimo_pr="" ultimo_estado="" abertos=0 resumo_prs=""
  if [ -n "$prs" ]; then
    read -r ultimo_pr ultimo_estado <<< "$(head -n 1 <<< "$prs")"
    abertos=$(awk '$2 == "OPEN"' <<< "$prs" | wc -l | tr -d ' ')
    resumo_prs=$(awk '{ printf "%s#%s %s", (NR > 1 ? ", " : ""), $1, $2 }' <<< "$prs")
  fi

  ref="HEAD"
  origem="main"
  if [ "${ultimo_estado:-}" = "OPEN" ]; then
    ref="refs/pull/$ultimo_pr/head"
    origem="PR#$ultimo_pr aberto"
    em_pr_aberto=$((em_pr_aberto + 1))
  fi

  if ! clonar_ou_atualizar "$repo" "$pasta" "$ref"; then
    echo "⚠️  $usuario — falha ao clonar/atualizar $repo"
    printf '%s\t%s\tfalha ao clonar\t%s\n' "$usuario" "$nome" "$resumo_prs" >> "$MANIFESTO"
    continue
  fi
  printf '%s\t%s\t%s\t%s\n' "$usuario" "$nome" "$origem" "$resumo_prs" >> "$MANIFESTO"

  aviso=""
  [ "$origem" != "main" ] && aviso=" ($origem, não mesclado)"
  [ "$abertos" -gt 1 ] && aviso="$aviso — ⚠️  $abertos PRs abertos, a entrega pode estar espalhada entre eles: $resumo_prs"
  if [ -f "$pasta/RELATO.md" ]; then
    echo "✅ $usuario$aviso"
  else
    echo "⚠️  $usuario — clonado, mas sem RELATO.md na raiz (não entregou ainda?)$aviso"
    sem_relato=$((sem_relato + 1))
  fi
done

echo ""
echo "Concluído. Repositórios em $DESTINO/ ($sem_repo sem repositório, $sem_relato sem RELATO.md, $em_pr_aberto em PR aberto)."
echo "Origem de cada entrega: $MANIFESTO"
echo "Pasta local, não versionada (veja .gitignore) — pode apagar quando terminar a análise:"
echo "  rm -rf $DESTINO"
