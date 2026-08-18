#!/usr/bin/env bash
# Confere se os usuários do GitHub listados no CSV de cada equipe
# realmente têm acesso ao repositório: colaborador aceito, convite ainda
# pendente (usuário existe, mas não aceitou), ou nem encontrado (typo /
# usuário inexistente). Rode depois de criar-repos.sh e de novo perto do
# prazo final, quantas vezes quiser — só lê o estado atual, não altera
# nada.
#
# Uso: ./verificar-colaboradores.sh --config disciplina.env equipes.csv

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

extrair_usuario() {
  printf '%s' "$1" \
    | xargs \
    | sed -E 's#^(https?://)?(www\.)?github\.com/##i; s#/+$##'
}

total_pendentes=0
total_nao_encontrados=0

while IFS=',' read -r tema usuarios; do
  [ -z "$tema" ] && continue
  slug=$(slugificar "$tema")
  repo="$ORG/${PREFIXO_REPO}-${slug}"

  colaboradores=$(gh api "repos/$repo/collaborators" --paginate --jq '.[].login' 2>/dev/null | tr '[:upper:]' '[:lower:]')
  pendentes=$(gh api "repos/$repo/invitations" --paginate --jq '.[].invitee.login' 2>/dev/null | tr '[:upper:]' '[:lower:]')

  echo "== $repo =="
  IFS=';' read -ra lista_usuarios <<< "$usuarios"
  for usuario in "${lista_usuarios[@]}"; do
    usuario_limpo=$(extrair_usuario "$usuario")
    [ -z "$usuario_limpo" ] && continue
    usuario_lower=$(printf '%s' "$usuario_limpo" | tr '[:upper:]' '[:lower:]')

    if grep -qx "$usuario_lower" <<< "$colaboradores"; then
      echo "  ✅ $usuario_limpo — colaborador ativo"
    elif grep -qx "$usuario_lower" <<< "$pendentes"; then
      echo "  ⏳ $usuario_limpo — convite pendente (cobrar aceite)"
      total_pendentes=$((total_pendentes + 1))
    else
      echo "  ❌ $usuario_limpo — não encontrado (corrija o CSV e rode criar-repos.sh de novo)"
      total_nao_encontrados=$((total_nao_encontrados + 1))
    fi
  done
done < <(tail -n +2 "$CSV")

echo ""
echo "Resumo: $total_pendentes convite(s) pendente(s), $total_nao_encontrados usuário(s) não encontrado(s)."
