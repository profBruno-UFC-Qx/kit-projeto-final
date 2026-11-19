#!/usr/bin/env bash
# Roda a suíte de testes do template contra o código de cada aluno de uma
# pasta gerada por coletar-entregas.sh, e grava <pasta>/_testes.tsv.
#
# Cada entrega é copiada para uma pasta temporária e recebe por cima os
# testes e os arquivos de build do template — assim um aluno que editou
# (ou apagou) os testes é avaliado pelos testes originais, e a pasta do
# aluno não é tocada. A coluna "testes_alterados" registra se o aluno
# mexeu em src/test.
#
# "O template" de cada aluno é a versão que ele recebeu (coluna "template"
# do _entregas.tsv gravado por coletar-entregas.sh), não necessariamente a
# atual: se os testes do template mudaram no meio da atividade, o aluno é
# avaliado pelos testes que tinha. Sem manifesto, usa _template/.
#
# Uso: testar-entregas.sh entregas-ppNN

set -uo pipefail

PASTA="${1:?Uso: $0 entregas-ppNN}"
[ -d "$PASTA/_template" ] || { echo "Não achei $PASTA/_template — rode coletar-entregas.sh antes."; exit 1; }
MANIFESTO="$PASTA/_entregas.tsv"

template_do_aluno() {
  local t=""
  [ -f "$MANIFESTO" ] && t=$(awk -F'\t' -v u="$1" '$1 == u { print $5 }' "$MANIFESTO")
  [ -n "$t" ] && [ -d "$PASTA/$t" ] && echo "$PASTA/$t" || echo "$PASTA/_template"
}

SAIDA="$PASTA/_testes.tsv"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf 'usuario\tresultado\ttotal\tfalhas\ttestes_alterados\n' > "$SAIDA"

for dir in "$PASTA"/*/; do
  usuario=$(basename "$dir")
  [[ "$usuario" == _template* ]] && continue
  TEMPLATE=$(template_do_aluno "$usuario")

  alterados="não"
  diff -rq "$TEMPLATE/src/test" "$dir/src/test" >/dev/null 2>&1 || alterados="sim"

  # Entrega sem nenhuma mudança em src/main: nada a testar.
  if diff -rq "$TEMPLATE/src/main" "$dir/src/main" >/dev/null 2>&1; then
    printf '%s\tsem código\t\t\t%s\n' "$usuario" "$alterados" >> "$SAIDA"
    echo "➖ $usuario — sem código"
    continue
  fi

  trabalho="$TMP/$usuario"
  rsync -a --exclude .git --exclude build --exclude .gradle "$dir" "$trabalho/"
  rm -rf "$trabalho/src/test"
  cp -R "$TEMPLATE/src/test" "$trabalho/src/test"
  for f in build.gradle settings.gradle gradlew gradle; do
    rm -rf "${trabalho:?}/$f"
    cp -R "$TEMPLATE/$f" "$trabalho/$f"
  done

  (cd "$trabalho" && ./gradlew test -q >"$trabalho/_saida.log" 2>&1)
  relatorios=("$trabalho"/build/test-results/test/*.xml)

  if [ ! -e "${relatorios[0]}" ]; then
    printf '%s\tnão compila\t\t\t%s\n' "$usuario" "$alterados" >> "$SAIDA"
    cp "$trabalho/_saida.log" "$PASTA/$usuario.testes.log"
    echo "❌ $usuario — não compila (log em $PASTA/$usuario.testes.log)"
    continue
  fi

  read -r total falhas < <(cat "${relatorios[@]}" | awk '
    /<testsuite / {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^tests=/)    { gsub(/[^0-9]/, "", $i); t += $i }
        if ($i ~ /^failures=/) { gsub(/[^0-9]/, "", $i); f += $i }
        if ($i ~ /^errors=/)   { gsub(/[^0-9]/, "", $i); f += $i }
      }
    }
    END { print t + 0, f + 0 }')

  resultado="passa"
  [ "$falhas" -gt 0 ] && resultado="falha"
  printf '%s\t%s\t%s\t%s\t%s\n' "$usuario" "$resultado" "$total" "$falhas" "$alterados" >> "$SAIDA"
  echo "$([ "$resultado" = passa ] && echo ✅ || echo ⚠️ ) $usuario — $((total - falhas))/$total"
done

echo ""
echo "Resultado em $SAIDA"
