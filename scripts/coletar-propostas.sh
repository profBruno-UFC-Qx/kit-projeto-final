#!/usr/bin/env bash
# Busca o PROPOSTA.md de cada equipe do CSV, do jeito que ele está agora
# para revisão: se a equipe tem uma Pull Request de proposta aberta, lê o
# conteúdo dessa PR (branch da proposta, ainda não mesclada — normal no
# fluxo de projeto final, que exige aprovação do professor via
# CODEOWNERS antes de mesclar); senão, cai para o conteúdo da branch
# padrão (proposta já aprovada/mesclada, ou você está reconferindo depois).
#
# Só lê pela API — não clona nada. Proposta é texto (não há código pra
# cruzar nesse estágio do fluxo), então não há necessidade de clone raso
# como em coletar-entregas.sh (atividades práticas).
#
# Uso: ./coletar-propostas.sh --config disciplina.env equipes.csv [pasta-destino]
#
# Saída em pasta-destino/:
#   <slug-do-tema>.md   — conteúdo do PROPOSTA.md
#   _propostas.csv      — tema,slug,repo,pr_url,fonte (pr|branch-padrao|ausente)

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
com_pr_aberta=0
sem_pr_aberta=0
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
  # incomum já mereceria uma olhada manual — pega a mais recente).
  pr_info=$(gh pr list --repo "$repo" --state open --json number,url,headRefName \
    --jq 'sort_by(.number) | last | "\(.url) \(.headRefName)"' 2>/dev/null)

  if [ -n "$pr_info" ]; then
    pr_url="${pr_info% *}"
    head_ref="${pr_info##* }"
    if conteudo=$(gh api "repos/$repo/contents/PROPOSTA.md?ref=$head_ref" \
        -H "Accept: application/vnd.github.raw" 2>/dev/null); then
      printf '%s\n' "$conteudo" > "$arquivo"
      echo "✅ $tema — PR aberta ($pr_url)"
      echo "\"$tema\",$slug,$repo,$pr_url,pr" >> "$SAIDA_CSV"
      com_pr_aberta=$((com_pr_aberta + 1))
      continue
    fi
  fi

  # Sem PR aberta (ou sem PROPOSTA.md nela) — tenta a branch padrão
  # (proposta já mesclada, ou você está reconferindo depois da aprovação).
  if conteudo=$(gh api "repos/$repo/contents/PROPOSTA.md" \
      -H "Accept: application/vnd.github.raw" 2>/dev/null); then
    printf '%s\n' "$conteudo" > "$arquivo"
    echo "⚠️  $tema — sem PR aberta, lendo da branch padrão (já mesclada?)"
    echo "\"$tema\",$slug,$repo,,branch-padrao" >> "$SAIDA_CSV"
    sem_pr_aberta=$((sem_pr_aberta + 1))
  else
    echo "❌ $tema — sem PR aberta e sem PROPOSTA.md na branch padrão (ainda não enviou)"
    echo "\"$tema\",$slug,$repo,,ausente" >> "$SAIDA_CSV"
    ausentes=$((ausentes + 1))
  fi
done < <(tail -n +2 "$CSV" | tr -d '\r' | csv_para_campos)

echo ""
echo "Concluído: $total equipe(s) — $com_pr_aberta com PR aberta, $sem_pr_aberta via branch padrão, $ausentes sem proposta."
echo "Conteúdo em $DESTINO/ ($(basename "$SAIDA_CSV") tem o mapeamento tema→PR)."
