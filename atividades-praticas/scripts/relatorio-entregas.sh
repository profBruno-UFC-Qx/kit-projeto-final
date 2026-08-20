#!/usr/bin/env bash
# Dá visibilidade de quais atividades estão completas/incompletas: para
# cada aluno do CSV, olha o repositório da atividade e reporta se existe,
# e o resultado mais recente dos checks "Validar Relato" e "Testes" na
# branch padrão. Só lê, não altera nada — rode quantas vezes quiser.
#
# Uso: ./relatorio-entregas.sh --config config/pp01.env roster.csv [--csv saida.csv]

set -uo pipefail

if [ "${1:-}" != "--config" ] || [ -z "${2:-}" ]; then
  echo "Uso: $0 --config config/ppNN.env roster.csv [--csv saida.csv]"
  exit 1
fi

CONFIG="$2"
CSV="${3:-roster.csv}"
SAIDA_CSV=""
if [ "${4:-}" = "--csv" ] && [ -n "${5:-}" ]; then
  SAIDA_CSV="$5"
fi

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
IDX_NOME=$(indice_coluna "nome")
IDX_MATRICULA=$(indice_coluna "matricula")
if [ "$IDX_USUARIO" -lt 0 ]; then
  echo "O cabeçalho do CSV precisa ter a coluna 'usuario_github' (outras colunas são ignoradas)."
  exit 1
fi

extrair_usuario() {
  printf '%s' "$1" \
    | xargs \
    | sed -E 's#^(https?://)?(www\.)?github\.com/##i; s#/+$##'
}

conclusao_check() {
  # $1 = repo (org/nome), $2 = ref, $3 = trecho do nome do check
  local repo="$1" ref="$2" trecho="$3"
  gh api "repos/$repo/commits/$ref/check-runs" --paginate --jq \
    ".check_runs[] | select(.name | test(\"$trecho\")) | .conclusion" 2>/dev/null \
    | head -n 1
}

simbolo() {
  case "$1" in
    success) echo "✅" ;;
    failure) echo "❌" ;;
    "") echo "—" ;;
    *) echo "⏳" ;;
  esac
}

if [ -n "$SAIDA_CSV" ]; then
  echo "matricula,nome,usuario_github,repo,existe,relato,testes" > "$SAIDA_CSV"
fi

printf "%-14s %-25s %-8s %-8s %s\n" "USUARIO" "NOME" "RELATO" "TESTES" "REPO"

while IFS=',' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  usuario=$(extrair_usuario "${campos[$IDX_USUARIO]:-}")
  [ -z "$usuario" ] && continue
  nome="${campos[$IDX_NOME]:-}"
  matricula="${campos[$IDX_MATRICULA]:-}"

  repo="$ORG/${PREFIXO_REPO}-${usuario}"

  default_branch=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null)
  if [ -z "$default_branch" ]; then
    printf "%-14s %-25s %-8s %-8s %s\n" "$usuario" "$nome" "—" "—" "(sem repo)"
    [ -n "$SAIDA_CSV" ] && echo "$matricula,$nome,$usuario,,não,," >> "$SAIDA_CSV"
    continue
  fi

  relato=$(conclusao_check "$repo" "$default_branch" "validar-relato")
  testes=$(conclusao_check "$repo" "$default_branch" "testes")

  printf "%-14s %-25s %-8s %-8s %s\n" "$usuario" "$nome" "$(simbolo "$relato")" "$(simbolo "$testes")" "$repo"
  [ -n "$SAIDA_CSV" ] && echo "$matricula,$nome,$usuario,$repo,sim,$relato,$testes" >> "$SAIDA_CSV"
done < <(tail -n +2 "$CSV")

[ -n "$SAIDA_CSV" ] && echo "" && echo "Relatório salvo em $SAIDA_CSV"
