#!/usr/bin/env bash
# Cria um repositório individual por aluno a partir do template de uma
# atividade prática, dentro da sua org, adiciona o aluno como colaborador
# (push) e protege a branch padrão exigindo Pull Request + o check
# "Validar Relato" para poder mesclar — sem exigir aprovação humana (não
# há etapa de proposta nem revisão de code owner, diferente do
# kit-projeto-final: atividades práticas são individuais e não têm essa
# etapa).
#
# Uso: ./criar-repos.sh --config config/pp01.env roster.csv
#
# config/ppNN.env deve definir:
#   ORG            (ex: profBruno-UFC-Qx)
#   TEMPLATE_REPO  (ex: profBruno-UFC-Qx/conta-bancaria-simples)
#   PREFIXO_REPO   (ex: pp01)
#   CHECK_RELATO   (nome do check exigido; padrão:
#                   "validar-relato / validar-relato" — o nome do
#                   check-run de um job que chama um workflow reutilizável
#                   é "<job do chamador> / <job do workflow chamado>", não
#                   só o id do job. Só ajuste se renomear o job no
#                   template ou no kit.)
#   PRIVADO        ("true" ou "false", padrão "true" — repositório privado
#                   evita que um aluno veja a solução do outro.)
#
# CSV esperado: precisa ter no cabeçalho a coluna "usuario_github" (em
#   qualquer posição/ordem). Outras colunas (ex: "matricula", "nome") são
#   ignoradas por este script, mas úteis para você e para
#   verificar-colaboradores.sh. Aceita tanto "usuario" quanto
#   "github.com/usuario" ou "https://github.com/usuario". O parsing do
#   CSV é tolerante a quebras de linha CRLF e a campos entre aspas
#   contendo vírgula (comum quando um campo de texto livre, ex: "nome",
#   tem vírgula e o Google Forms/Sheets aspeia o campo no export).
#
# Reexecutável: se um repositório do CSV já existir, ele é pulado (sem
# recriar nem duplicar colaborador/proteção). Isso permite adicionar um
# aluno atrasado rodando o script de novo com o CSV atualizado (todos os
# alunos + o novo), sem precisar de um caminho separado.

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
: "${TEMPLATE_REPO:?defina TEMPLATE_REPO em $CONFIG}"
: "${PREFIXO_REPO:?defina PREFIXO_REPO em $CONFIG}"
CHECK_RELATO="${CHECK_RELATO:-validar-relato / validar-relato}"
PRIVADO="${PRIVADO:-true}"

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
  # Índice (0-based) da coluna $1 no cabeçalho do CSV, ou -1 se não achar.
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
  # Aceita tanto "usuario" quanto "github.com/usuario" (com ou sem
  # protocolo/www/barra final) e devolve só o usuário.
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

echo "Serão criados ${#usuarios[@]} repositórios em $ORG a partir de $TEMPLATE_REPO:"
echo ""
for usuario in "${usuarios[@]}"; do
  echo "  ${PREFIXO_REPO}-${usuario}  (colaborador: $usuario)"
done
echo ""
echo "Repositórios privados: $PRIVADO"
read -r -p "Confirma a criação desses ${#usuarios[@]} repositórios? [s/N] " resposta
case "$resposta" in
  [sS]) ;;
  *) echo "Cancelado."; exit 0 ;;
esac

flag_privacidade="--public"
[ "$PRIVADO" = "true" ] && flag_privacidade="--private"

for usuario in "${usuarios[@]}"; do
  repo="$ORG/${PREFIXO_REPO}-${usuario}"

  echo ""
  echo "== Criando $repo =="

  if ! gh repo create "$repo" \
    --template "$TEMPLATE_REPO" \
    "$flag_privacidade"; then
    if gh repo view "$repo" >/dev/null 2>&1; then
      echo "  ℹ️  $repo já existe, pulando (aluno adicionado em execução anterior)."
    else
      echo "❌ Falha ao criar $repo, pulando."
      continue
    fi
  fi

  echo "  adicionando colaborador: $usuario"
  gh api "repos/$repo/collaborators/$usuario" -X PUT -f permission=push \
    || echo "  ⚠️  não consegui adicionar $usuario (verifique o usuário)"

  default_branch=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null)
  if [ -z "$default_branch" ]; then
    echo "  ⚠️  não consegui ler a branch padrão de $repo, proteção não aplicada."
    continue
  fi

  # Repo criado a partir de template é gerado de forma assíncrona: a
  # criação retorna antes do branch (com o conteúdo do template) existir
  # de fato, o que causa "Branch not found" se a proteção for aplicada
  # cedo demais. Espera o branch aparecer antes de continuar.
  tentativas=0
  until gh api "repos/$repo/branches/$default_branch" >/dev/null 2>&1; do
    tentativas=$((tentativas + 1))
    if [ "$tentativas" -ge 15 ]; then
      echo "  ⚠️  branch $default_branch de $repo não apareceu após $((tentativas * 2))s; tentando proteger mesmo assim."
      break
    fi
    sleep 2
  done

  echo "  aplicando proteção de branch em $default_branch (check obrigatório: $CHECK_RELATO)"
  gh api "repos/$repo/branches/$default_branch/protection" -X PUT --input - <<EOF \
    || echo "  ⚠️  não consegui proteger a branch $default_branch de $repo (rode o script de novo para tentar de novo)"
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["$CHECK_RELATO"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null
}
EOF
done

echo ""
echo "Concluído. A branch de cada repositório exige Pull Request + o check"
echo "'$CHECK_RELATO' para mesclar (sem aprovação humana obrigatória)."
echo "Rode verificar-colaboradores.sh para conferir se todos os usuários"
echo "do GitHub foram adicionados corretamente."
