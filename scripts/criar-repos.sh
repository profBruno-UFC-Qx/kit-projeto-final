#!/usr/bin/env bash
# Cria um repositório por equipe a partir do template de uma disciplina,
# adiciona os colaboradores e protege a branch main (aprovação do
# professor + check de validação da proposta obrigatórios).
#
# Uso: ./criar-repos.sh --config disciplina.env equipes.csv
#
# disciplina.env deve definir:
#   ORG            (ex: profBruno-UFC-Qx)
#   TEMPLATE_REPO  (ex: profBruno-UFC-Qx/qxd0020-projeto-final)
#   PREFIXO_REPO   (ex: qxd0020)
#   CHECK_PROPOSTA (nome do check exigido desde a criação; padrão:
#                   "validar-proposta / validar-proposta" — o nome do
#                   check-run de um job que chama um workflow reutilizável
#                   é "<job do chamador> / <job do workflow chamado>", não
#                   só o id do job. Confirmado empiricamente; se você
#                   renomear o job no template ou no kit, o valor aqui
#                   precisa acompanhar.
#
# CSV esperado: precisa ter no cabeçalho as colunas "tema" e
#   "usuarios_github" (em qualquer posição/ordem). Outras colunas (ex:
#   "disciplina", vindas de uma planilha exportada com mais campos do que
#   o necessário) são ignoradas.
#   usuarios_github: usuários do GitHub separados por ";", cada um como
#   "usuario" ou como link do perfil ("github.com/usuario" ou
#   "https://github.com/usuario") — os dois formatos são aceitos. Campos
#   vazios entre ";" (ex: equipe menor que o número de colunas do
#   formulário) são ignorados.
#
# Reexecutável: se um repositório do CSV já existir, ele é pulado (sem
# recriar nem duplicar colaboradores/proteção). Isso permite adicionar
# uma equipe atrasada rodando o script de novo com o CSV atualizado
# (todas as equipes + a nova), sem precisar de um caminho separado.

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
: "${TEMPLATE_REPO:?defina TEMPLATE_REPO em $CONFIG}"
: "${PREFIXO_REPO:?defina PREFIXO_REPO em $CONFIG}"
CHECK_PROPOSTA="${CHECK_PROPOSTA:-validar-proposta / validar-proposta}"

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
IDX_USUARIOS=$(indice_coluna "usuarios_github")
if [ "$IDX_TEMA" -lt 0 ] || [ "$IDX_USUARIOS" -lt 0 ]; then
  echo "O cabeçalho do CSV precisa ter as colunas 'tema' e 'usuarios_github' (outras colunas são ignoradas)."
  exit 1
fi

slugificar() {
  # Mapeamento explícito de acentos em vez de `iconv //TRANSLIT`, cujo
  # comportamento varia entre libiconv (macOS) e glibc (Linux) e pode
  # inserir caracteres de combinação em vez de remover o acento.
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
  # Aceita tanto "usuario" quanto "github.com/usuario" (com ou sem
  # protocolo/www/barra final) e devolve só o usuário.
  printf '%s' "$1" \
    | xargs \
    | sed -E 's#^(https?://)?(www\.)?github\.com/##i; s#/+$##'
}

temas=()
slugs=()
usuarios_por_equipe=()

while IFS=',' read -r -a campos; do
  [ "${#campos[@]}" -eq 0 ] && continue
  tema="${campos[$IDX_TEMA]:-}"
  usuarios="${campos[$IDX_USUARIOS]:-}"
  [ -z "$tema" ] && continue
  slug=$(slugificar "$tema")
  temas+=("$tema")
  slugs+=("$slug")
  usuarios_por_equipe+=("$usuarios")
done < <(tail -n +2 "$CSV")

if [ "${#temas[@]}" -eq 0 ]; then
  echo "Nenhuma equipe encontrada em $CSV."
  exit 1
fi

duplicados=0
for i in "${!slugs[@]}"; do
  for j in "${!slugs[@]}"; do
    if [ "$i" -lt "$j" ] && [ "${slugs[$i]}" = "${slugs[$j]}" ]; then
      echo "❌ Tema duplicado (mesmo slug '${slugs[$i]}'): \"${temas[$i]}\" e \"${temas[$j]}\""
      duplicados=1
    fi
  done
done

if [ "$duplicados" -ne 0 ]; then
  echo ""
  echo "Corrija os temas duplicados no CSV antes de continuar. Nenhum repositório foi criado."
  exit 1
fi

listar_usuarios() {
  # Junta os usuários não-vazios de uma lista separada por ";" com ", ",
  # ignorando campos vazios (ex: colunas de membros sem preenchimento).
  local usuario resultado="" brutos
  IFS=';' read -ra brutos <<< "$1"
  for usuario in "${brutos[@]}"; do
    usuario=$(extrair_usuario "$usuario")
    if [ -n "$usuario" ]; then
      resultado="${resultado:+$resultado, }$usuario"
    fi
  done
  echo "$resultado"
}

echo "Serão criados ${#temas[@]} repositórios em $ORG a partir de $TEMPLATE_REPO:"
echo ""
for i in "${!temas[@]}"; do
  echo "  ${PREFIXO_REPO}-${slugs[$i]}"
  echo "    tema: ${temas[$i]}"
  echo "    colaboradores: $(listar_usuarios "${usuarios_por_equipe[$i]}")"
done
echo ""
read -r -p "Confirma a criação desses ${#temas[@]} repositórios? [s/N] " resposta
case "$resposta" in
  [sS]) ;;
  *) echo "Cancelado."; exit 0 ;;
esac

for i in "${!temas[@]}"; do
  slug="${slugs[$i]}"
  repo="$ORG/${PREFIXO_REPO}-${slug}"
  tema="${temas[$i]}"

  echo ""
  echo "== Criando $repo =="

  if ! gh repo create "$repo" \
    --template "$TEMPLATE_REPO" \
    --public \
    --description "$tema"; then
    if gh repo view "$repo" >/dev/null 2>&1; then
      echo "  ℹ️  $repo já existe, pulando (equipe adicionada em execução anterior)."
    else
      echo "❌ Falha ao criar $repo, pulando."
    fi
    continue
  fi

  IFS=';' read -ra usuarios <<< "${usuarios_por_equipe[$i]}"
  for usuario in "${usuarios[@]}"; do
    usuario_limpo=$(extrair_usuario "$usuario")
    [ -z "$usuario_limpo" ] && continue
    echo "  adicionando colaborador: $usuario_limpo"
    gh api "repos/$repo/collaborators/$usuario_limpo" -X PUT -f permission=push \
      || echo "  ⚠️  não consegui adicionar $usuario_limpo (verifique o usuário)"
  done

  echo "  aplicando proteção de branch em main (check obrigatório: $CHECK_PROPOSTA)"
  gh api "repos/$repo/branches/main/protection" -X PUT --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["$CHECK_PROPOSTA"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "require_code_owner_reviews": true
  },
  "restrictions": null
}
EOF
done

echo ""
echo "Concluído. A branch main de cada repositório exige revisão do"
echo "code owner + o check '$CHECK_PROPOSTA'. Rode verificar-colaboradores.sh"
echo "para conferir se todos os usuários do GitHub foram adicionados"
echo "corretamente. Quando chegar perto do prazo de entrega final, rode"
echo "ativar-validacao-entrega.sh para também exigir o check de entrega."
