#!/usr/bin/env bash
# Rebaixa cada aluno do CSV de colaborador (push) para leitura (pull) no
# repositório da atividade, depois do prazo: o aluno continua vendo o
# próprio código e PRs abertos, mas não consegue mais dar push nem
# abrir/atualizar Pull Request. Reversível a qualquer momento — rode
# criar-repos.sh de novo (ele readiciona com push) ou veja "Reabrir
# prazo" no fim deste arquivo.
#
# Não fecha PR aberto nem apaga nada; só impede novas alterações.
#
# Uso: ./travar-entregas.sh --config config/pp01.env roster.csv

set -uo pipefail

# Evita que o gh mande respostas para um pager interativo (less, via
# $PAGER/$GH_PAGER do usuário), o que pausaria o script em cada
# repositório do loop esperando 'q'.
export GH_PAGER=cat

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

extrair_usuario() {
  printf '%s' "$1" \
    | xargs \
    | sed -E 's#^(https?://)?(www\.)?github\.com/##i; s#/+$##'
}

usuarios=()
while IFS=$'\x1f' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  usuario=$(extrair_usuario "${campos[$IDX_USUARIO]:-}")
  [ -z "$usuario" ] && continue
  usuarios+=("$usuario")
done < <(tail -n +2 "$CSV" | tr -d '\r' | csv_para_campos)

if [ "${#usuarios[@]}" -eq 0 ]; then
  echo "Nenhum aluno encontrado em $CSV."
  exit 1
fi

# Fase 1: só lê o estado atual e decide quem precisa ser rebaixado.
a_rebaixar=()
echo "Verificando ${#usuarios[@]} aluno(s) em $ORG (${PREFIXO_REPO}-*)..."
echo ""
for usuario in "${usuarios[@]}"; do
  repo="$ORG/${PREFIXO_REPO}-${usuario}"

  if ! gh repo view "$repo" >/dev/null 2>&1; then
    echo "❌ $repo — repositório não existe, pulando"
    continue
  fi

  permissao=$(gh api "repos/$repo/collaborators/$usuario/permission" --jq '.permission' 2>/dev/null)

  case "$permissao" in
    "")
      echo "⚠️  $repo — $usuario não é colaborador, pulando"
      ;;
    read)
      echo "🔒 $repo — $usuario já está como leitura"
      ;;
    admin|maintain)
      echo "⚠️  $repo — $usuario tem permissão '$permissao' (acima de push), pulando — ajuste manualmente se for intencional"
      ;;
    *)
      echo "🔓 $repo — $usuario está como '$permissao' (será rebaixado para leitura)"
      a_rebaixar+=("$usuario")
      ;;
  esac
done

echo ""
if [ "${#a_rebaixar[@]}" -eq 0 ]; then
  echo "Nada a travar."
  exit 0
fi

read -r -p "Rebaixar ${#a_rebaixar[@]} aluno(s) para leitura agora? [s/N] " resposta
case "$resposta" in
  [sS]) ;;
  *) echo "Cancelado."; exit 0 ;;
esac

# Fase 2: aplica.
travados=0
falhas=0
for usuario in "${a_rebaixar[@]}"; do
  repo="$ORG/${PREFIXO_REPO}-${usuario}"
  if gh api "repos/$repo/collaborators/$usuario" -X PUT -f permission=pull >/dev/null 2>&1; then
    echo "🔒 $usuario → leitura em $repo"
    travados=$((travados + 1))
  else
    echo "⚠️  não consegui rebaixar $usuario em $repo"
    falhas=$((falhas + 1))
  fi
done

echo ""
echo "Resumo: $travados aluno(s) rebaixado(s) para leitura, $falhas falha(s)."

# Reabrir prazo (dar push de volta a um aluno específico):
#   gh api repos/$ORG/${PREFIXO_REPO}-<usuario>/collaborators/<usuario> -X PUT -f permission=push
# Ou rode criar-repos.sh de novo com o CSV completo — ele readiciona com
# push quem já é colaborador do repositório (a permissão é atualizada).
