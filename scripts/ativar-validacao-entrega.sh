#!/usr/bin/env bash
# Passa a exigir também o check de validação da entrega final na branch
# main de cada repositório da disciplina. Rode isso perto do prazo de
# entrega — antes disso, ENTREGA.md legitimamente ainda está incompleto
# (só é preenchido ao final), então não faz sentido bloquear desde a
# criação do repositório.
#
# Uso: ./ativar-validacao-entrega.sh --config disciplina.env equipes.csv

set -uo pipefail

if [ "${1:-}" != "--config" ] || [ -z "${2:-}" ]; then
  echo "Uso: $0 --config disciplina.env equipes.csv"
  exit 1
fi

CONFIG="$2"
CSV="${3:-equipes.csv}"

if [ ! -f "$CONFIG" ]; then
  echo "Config não encontrada: $CONFIG"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"

: "${ORG:?defina ORG em $CONFIG}"
: "${PREFIXO_REPO:?defina PREFIXO_REPO em $CONFIG}"
# Nomes de check-run de um job que chama um workflow reutilizável seguem
# o formato "<job do chamador> / <job do workflow chamado>" (confirmado
# empiricamente), não só o id do job.
CHECK_PROPOSTA="${CHECK_PROPOSTA:-validar-proposta / validar-proposta}"
CHECK_ENTREGA="${CHECK_ENTREGA:-validar-entrega / validar-entrega}"

if [ ! -f "$CSV" ]; then
  echo "Arquivo não encontrado: $CSV"
  exit 1
fi

indice_coluna() {
  # Índice (0-based) da coluna $1 no cabeçalho do CSV, ou -1 se não achar.
  local procurado="$1" i=0 nome
  local -a colunas
  IFS=',' read -ra colunas < <(head -n 1 "$CSV")
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

echo "Isso vai exigir o check '$CHECK_ENTREGA' (além de '$CHECK_PROPOSTA') para"
echo "mesclar na main de todos os repositórios listados em $CSV."
read -r -p "Confirma? [s/N] " resposta
case "$resposta" in
  [sS]) ;;
  *) echo "Cancelado."; exit 0 ;;
esac

while IFS=',' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  tema="${campos[$IDX_TEMA]:-}"
  [ -z "$tema" ] && continue
  slug=$(slugificar "$tema")
  repo="$ORG/${PREFIXO_REPO}-${slug}"

  echo "== Atualizando proteção de $repo =="
  gh api "repos/$repo/branches/main/protection" -X PUT --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["$CHECK_PROPOSTA", "$CHECK_ENTREGA"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "require_code_owner_reviews": true
  },
  "restrictions": null
}
EOF
done < <(tail -n +2 "$CSV")

echo ""
echo "Concluído."
