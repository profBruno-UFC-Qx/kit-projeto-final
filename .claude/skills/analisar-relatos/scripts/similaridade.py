#!/usr/bin/env python3
"""Aponta pares de entregas com código quase idêntico.

Compara, entre todos os pares de alunos de uma pasta gerada por
coletar-entregas.sh, só o que cada aluno escreveu: de cada arquivo de
código, descarta as linhas que já existem no mesmo arquivo do template
que o aluno recebeu (coluna "template" do _entregas.tsv; sem manifesto,
_template/) e normaliza espaços e comentários antes de comparar. Imprime os pares
acima do limiar e, para dar contexto, sempre os 5 mais parecidos.

Na pp01 (31 entregas), o único par de fato copiado deu 0,79 e o
seguinte, de convergência natural, 0,68 — daí o limiar padrão de 0,6:
melhor trazer um par a mais para olhar do que perder um.

Similaridade alta é um indício para olhar de perto, não uma conclusão:
exercícios curtos convergem naturalmente para soluções parecidas. O que
pesa é coincidência em detalhes arbitrários — nomes, ordem, e sobretudo
o mesmo bug.

Uso: similaridade.py entregas-ppNN [limiar=0.6]
"""

import difflib
import itertools
import re
import sys
from pathlib import Path

EXTENSOES = {".java", ".py", ".js", ".ts", ".c", ".cpp", ".h", ".kt", ".cs"}
IGNORAR = {".git", "build", ".gradle", ".idea", "node_modules"}


def normalizar(linha):
    linha = re.sub(r"//.*", "", linha)
    linha = re.sub(r"\s+", "", linha)
    return linha if linha not in {"", "/**", "*/", "*"} and not linha.startswith("*") else ""


def codigo_do_aluno(pasta, template):
    linhas = []
    for arq in sorted(pasta.rglob("*")):
        if arq.suffix not in EXTENSOES or IGNORAR & set(arq.relative_to(pasta).parts):
            continue
        rel = arq.relative_to(pasta)
        base = template / rel
        do_template = set()
        if base.exists():
            do_template = {normalizar(l) for l in base.read_text(errors="ignore").splitlines()}
        for l in arq.read_text(errors="ignore").splitlines():
            n = normalizar(l)
            if n and n not in do_template:
                linhas.append(n)
    return linhas


def main():
    raiz = Path(sys.argv[1])
    limiar = float(sys.argv[2]) if len(sys.argv) > 2 else 0.6
    templates = {}
    manifesto = raiz / "_entregas.tsv"
    if manifesto.exists():
        for linha in manifesto.read_text().splitlines()[1:]:
            campos = linha.split("\t")
            if len(campos) > 4 and campos[4] and (raiz / campos[4]).is_dir():
                templates[campos[0]] = raiz / campos[4]
    alunos = {
        p.name: codigo_do_aluno(p, templates.get(p.name, raiz / "_template"))
        for p in sorted(raiz.iterdir())
        if p.is_dir() and not p.name.startswith("_")
    }
    alunos = {k: v for k, v in alunos.items() if len(v) >= 5}

    pares = sorted(
        (
            (difflib.SequenceMatcher(None, la, lb, autojunk=False).ratio(), a, b)
            for (a, la), (b, lb) in itertools.combinations(alunos.items(), 2)
        ),
        reverse=True,
    )
    acima = [p for p in pares if p[0] >= limiar]

    print(f"{len(alunos)} entregas com código comparadas; {len(acima)} par(es) com similaridade >= {limiar}")
    for r, a, b in pares[: max(len(acima), 5)]:
        marca = "⚠️ " if r >= limiar else "   "
        print(f"{marca}{r:.2f}\t{a}\t{b}")


if __name__ == "__main__":
    main()
