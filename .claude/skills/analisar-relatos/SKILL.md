---
name: analisar-relatos
description: Lê o RELATO.md e o código entregue por todos os alunos de uma atividade prática (ppNN) e sintetiza os pontos mais relevantes para discutir em sala de aula — dificuldades recorrentes, uso de IA, e onde o relato bate ou destoa do código de fato entregue. Use quando o usuário pedir para avaliar/analisar os relatos de uma atividade, preparar uma discussão em sala sobre uma atividade, ou pedir para cruzar relato com código.
---

# Analisar relatos de uma atividade prática

Gera um documento de apoio para discussão em sala a partir dos
`RELATO.md` (e do código) de todos os alunos de uma atividade prática
(`ppNN`) do `kit-projeto-final`.

## Quando usar

O usuário pede para avaliar/resumir os relatos de uma atividade, ou
preparar pontos para discutir em sala sobre uma atividade prática. Se o
usuário não disser qual atividade (`ppNN`) e qual CSV de roster usar,
pergunte antes de continuar — não adivinhe.

## Passo 1 — Coletar

Rode, a partir de `atividades-praticas/`:

```
./scripts/coletar-entregas.sh --config config/ppNN.env <roster.csv> entregas-ppNN
```

Isso clona (raso) o template da atividade em `entregas-ppNN/_template/`
e o repositório de cada aluno em `entregas-ppNN/<usuario>/`. A pasta é
local e ignorada pelo git (veja `.gitignore` na raiz do kit) — nunca a
adicione a um commit.

Note quem ficou de fora (sem repositório, sem `RELATO.md`) — isso também
é um ponto para o resumo ("N alunos ainda sem entrega").

## Passo 2 — Ler cada aluno: relato + diff contra o template

Para cada pasta de aluno em `entregas-ppNN/` (exceto `_template/`):

1. Leia `RELATO.md` — extraia as respostas de cada seção (dificuldades,
   grau de dificuldade 1-5, quão interessante 1-5, tempo gasto, uso de
   IA, com quem fez).
2. Compare com o template para ver o que o aluno de fato mudou, sem o
   ruído do boilerplate:
   ```
   diff -rq --exclude=.git --exclude=RELATO.md entregas-ppNN/_template/ entregas-ppNN/<usuario>/
   ```
   Para os arquivos que aparecerem como diferentes, rode
   `diff -u entregas-ppNN/_template/<arquivo> entregas-ppNN/<usuario>/<arquivo>`
   para ver o que mudou de fato.

Isso te dá, por aluno, um par (o que ele disse) × (o que ele entregou).
Use esse par para notar padrões — não para julgar aluno a aluno; a saída
final é agregada e anônima (ver Passo 3).

Exemplos do tipo de relação que vale procurar:
- Aluno relata dificuldade em X — o diff mostra retrabalho/gambiarra em X?
  Ou X está bem resolvido, sugerindo que a dificuldade foi superada?
- Aluno diz "não usei IA" — o código tem marcas típicas de geração por
  IA (comentários genéricos demais, padrões fora do que foi ensinado em
  aula)? Trate isso como hipótese a mencionar com cautela, nunca como
  acusação — não é evidência definitiva.
- Aluno diz ter achado fácil (nota 1-2) mas o diff mostra solução
  incompleta/com atalhos — ou o oposto, achou difícil mas a solução é
  sólida.
- Vários alunos travando no mesmo método/conceito, visível tanto no
  relato quanto no código (bom candidato a puxar em sala).

## Passo 3 — Sintetizar

Produza um resumo **agregado e anônimo** (sem nomear aluno nenhum —
agrupe por tema: "vários alunos relataram...", "N de M alunos..."), com:

- **Números**: quantos entregaram, média/distribuição de grau de
  dificuldade, de "quão interessante", de tempo gasto.
- **Dificuldades recorrentes**: temas que se repetem nos relatos,
  cruzados com o que o diff mostra sobre esses trechos de código.
- **Uso de IA**: padrões de como/quando os alunos usaram (ou não)
  ferramentas de IA, e qualquer padrão notável entre o relatado e o
  código (mencionado com cautela, como hipótese).
- **Discrepâncias interessantes**: onde relato e código não batem, de
  forma agregada (ex: "N alunos disseram achar fácil, mas o código
  sugere retrabalho considerável").
- **Perguntas sugeridas para puxar a discussão em sala** — 4 a 6
  perguntas abertas, construídas a partir dos pontos acima.

## Passo 4 — Salvar e limpar

Salve o resumo como um arquivo Markdown local (não um Artifact — decisão
já tomada com o usuário), fora do `kit-projeto-final` versionado — ao
lado do roster, ex: `GestaoQXD0007/discussao-ppNN.md` — a não ser que o
usuário peça outro caminho.

Depois de gerar o resumo, avise que `entregas-ppNN/` contém clones locais
de repositórios privados de alunos e pergunte se pode apagar
(`rm -rf entregas-ppNN`) — só apague com confirmação explícita.
