#!/usr/bin/env bash
# Reenvia o convite de colaborador para os alunos que não têm acesso ao
# repositório da atividade: convite expirado (o GitHub expira convites
# após 7 dias) ou usuário que nunca chegou a ser adicionado. Convites
# ainda válidos e colaboradores ativos são deixados em paz.
#
# Um convite expirado não pode ser "reenviado": ele é removido e um novo é
# criado, o que também reinicia o prazo de 7 dias. Ao final, o script
# imprime o link direto de aceite de cada convite novo, para você poder
# repassar aos alunos (github.com/<org>/<repo>/invitations).
#
# Mostra o que vai fazer e pede confirmação antes de alterar qualquer
# coisa. Reexecutável: quem já aceitou ou ainda tem convite válido é
# ignorado.
#
# Uso: ./reenviar-convites.sh --config config/pp01.env roster.csv

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

# Fase 1: só lê o estado atual e decide o que fazer com cada aluno.
# Cada linha de $acoes é "<acao>|<usuario>|<id do convite expirado>".
acoes=()
echo "Verificando ${#usuarios[@]} aluno(s) em $ORG (${PREFIXO_REPO}-*)..."
echo ""
for usuario in "${usuarios[@]}"; do
  repo="$ORG/${PREFIXO_REPO}-${usuario}"
  usuario_lower=$(printf '%s' "$usuario" | tr '[:upper:]' '[:lower:]')

  if ! gh repo view "$repo" >/dev/null 2>&1; then
    echo "❌ $repo — repositório não existe (rode criar-repos.sh)"
    continue
  fi

  colaboradores=$(gh api "repos/$repo/collaborators" --paginate --jq '.[].login' 2>/dev/null | tr '[:upper:]' '[:lower:]')
  if grep -qx "$usuario_lower" <<< "$colaboradores"; then
    echo "✅ $repo — $usuario já é colaborador"
    continue
  fi

  # Uma linha "<id> <expired> <login>" por convite do repositório.
  convite=$(gh api "repos/$repo/invitations" --paginate \
      --jq '.[] | "\(.id) \(.expired) \(.invitee.login)"' 2>/dev/null \
    | awk -v u="$usuario_lower" 'tolower($3) == u { print $1, $2; exit }')

  if [ -z "$convite" ]; then
    echo "➕ $repo — $usuario sem convite (será convidado)"
    acoes+=("novo|$usuario|")
  else
    id_convite="${convite%% *}"
    expirado="${convite##* }"
    if [ "$expirado" = "true" ]; then
      echo "🔁 $repo — convite de $usuario expirado (será removido e recriado)"
      acoes+=("renovar|$usuario|$id_convite")
    else
      echo "⏳ $repo — $usuario tem convite válido (aceite em https://github.com/$repo/invitations)"
    fi
  fi
done

echo ""
if [ "${#acoes[@]}" -eq 0 ]; then
  echo "Nada a reenviar."
  exit 0
fi

read -r -p "Enviar ${#acoes[@]} convite(s) agora? [s/N] " resposta
case "$resposta" in
  [sS]) ;;
  *) echo "Cancelado."; exit 0 ;;
esac

# Fase 2: aplica.
enviados=()
falhas=0
for acao in "${acoes[@]}"; do
  IFS='|' read -r tipo usuario id_convite <<< "$acao"
  repo="$ORG/${PREFIXO_REPO}-${usuario}"

  if [ "$tipo" = "renovar" ]; then
    if ! gh api "repos/$repo/invitations/$id_convite" -X DELETE >/dev/null 2>&1; then
      echo "⚠️  não consegui remover o convite expirado de $usuario em $repo"
      falhas=$((falhas + 1))
      continue
    fi
  fi

  if gh api "repos/$repo/collaborators/$usuario" -X PUT -f permission=push >/dev/null 2>&1; then
    echo "✉️  convite enviado: $usuario → $repo"
    enviados+=("https://github.com/$repo/invitations  ($usuario)")
  else
    echo "⚠️  não consegui convidar $usuario em $repo (verifique o usuário)"
    falhas=$((falhas + 1))
  fi
done

echo ""
echo "Resumo: ${#enviados[@]} convite(s) enviado(s), $falhas falha(s)."
if [ "${#enviados[@]}" -gt 0 ]; then
  echo ""
  echo "Link de aceite de cada aluno (vale por 7 dias; o aluno também recebe e-mail"
  echo "e vê o convite em https://github.com/notifications):"
  printf '  %s\n' "${enviados[@]}"
fi
