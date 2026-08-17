#!/usr/bin/env bash
# Clona (ou atualiza, se já clonado) o repositório de cada equipe listada
# no CSV de roster de uma disciplina, um por pasta.
#
# Uso: ./clonar-tudo.sh --config disciplina.env equipes.csv [pasta-destino]

set -uo pipefail

if [ "${1:-}" != "--config" ] || [ -z "${2:-}" ]; then
  echo "Uso: $0 --config disciplina.env equipes.csv [pasta-destino]"
  exit 1
fi

CONFIG="$2"
CSV="${3:-equipes.csv}"
DESTINO="${4:-./entregas}"

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

mkdir -p "$DESTINO"

while IFS=',' read -r tema _usuarios; do
  [ -z "$tema" ] && continue
  slug=$(slugificar "$tema")
  repo="$ORG/${PREFIXO_REPO}-${slug}"
  pasta="$DESTINO/${slug}"

  if [ -d "$pasta/.git" ]; then
    echo "== Atualizando $repo =="
    git -C "$pasta" pull
  else
    echo "== Clonando $repo =="
    gh repo clone "$repo" "$pasta"
  fi
done < <(tail -n +2 "$CSV")

echo ""
echo "Concluído. Repositórios em $DESTINO/"
