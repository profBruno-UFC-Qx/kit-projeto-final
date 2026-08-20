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
#   "github.com/usuario" ou "https://github.com/usuario".
#
# Reexecutável: se um repositório do CSV já existir, ele é pulado (sem
# recriar nem duplicar colaborador/proteção). Isso permite adicionar um
# aluno atrasado rodando o script de novo com o CSV atualizado (todos os
# alunos + o novo), sem precisar de um caminho separado.

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
: "${TEMPLATE_REPO:?defina TEMPLATE_REPO em $CONFIG}"
: "${PREFIXO_REPO:?defina PREFIXO_REPO em $CONFIG}"
CHECK_RELATO="${CHECK_RELATO:-validar-relato / validar-relato}"
PRIVADO="${PRIVADO:-true}"

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
while IFS=',' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  usuario=$(extrair_usuario "${campos[$IDX_USUARIO]:-}")
  [ -z "$usuario" ] && continue
  usuarios+=("$usuario")
done < <(tail -n +2 "$CSV")

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

  echo "  aplicando proteção de branch em $default_branch (check obrigatório: $CHECK_RELATO)"
  gh api "repos/$repo/branches/$default_branch/protection" -X PUT --input - <<EOF
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
