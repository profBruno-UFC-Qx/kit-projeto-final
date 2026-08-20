#!/usr/bin/env bash
# Confere se o usuário do GitHub de cada aluno no CSV realmente tem
# acesso ao repositório da atividade: colaborador aceito, convite ainda
# pendente (usuário existe, mas não aceitou), ou nem encontrado (typo /
# usuário inexistente). Rode depois de criar-repos.sh e de novo perto do
# prazo, quantas vezes quiser — só lê o estado atual, não altera nada.
#
# Uso: ./verificar-colaboradores.sh --config config/pp01.env roster.csv

set -uo pipefail

if [ "${1:-}" != "--config" ] || [ -z "${2:-}" ]; then
  echo "Uso: $0 --config config/ppNN.env roster.csv"
  exit 1
fi

CONFIG="$2"
CSV="${3:-roster.csv}"

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

indice_coluna() {
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

IDX_USUARIO=$(indice_coluna "usuario_github")
if [ "$IDX_USUARIO" -lt 0 ]; then
  echo "O cabeçalho do CSV precisa ter a coluna 'usuario_github' (outras colunas são ignoradas)."
  exit 1
fi

extrair_usuario() {
  printf '%s' "$1" \
    | xargs \
    | sed -E 's#^(https?://)?(www\.)?github\.com/##i; s#/+$##'
}

total_pendentes=0
total_nao_encontrados=0

while IFS=',' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  usuario=$(extrair_usuario "${campos[$IDX_USUARIO]:-}")
  [ -z "$usuario" ] && continue
  usuario_lower=$(printf '%s' "$usuario" | tr '[:upper:]' '[:lower:]')

  repo="$ORG/${PREFIXO_REPO}-${usuario}"

  colaboradores=$(gh api "repos/$repo/collaborators" --paginate --jq '.[].login' 2>/dev/null | tr '[:upper:]' '[:lower:]')
  pendentes=$(gh api "repos/$repo/invitations" --paginate --jq '.[].invitee.login' 2>/dev/null | tr '[:upper:]' '[:lower:]')

  if grep -qx "$usuario_lower" <<< "$colaboradores"; then
    echo "✅ $repo — $usuario colaborador ativo"
  elif grep -qx "$usuario_lower" <<< "$pendentes"; then
    echo "⏳ $repo — $usuario convite pendente (cobrar aceite)"
    total_pendentes=$((total_pendentes + 1))
  else
    echo "❌ $repo — $usuario não encontrado (repo não existe ou usuário não foi adicionado; rode criar-repos.sh de novo)"
    total_nao_encontrados=$((total_nao_encontrados + 1))
  fi
done < <(tail -n +2 "$CSV")

echo ""
echo "Resumo: $total_pendentes convite(s) pendente(s), $total_nao_encontrados problema(s)."
