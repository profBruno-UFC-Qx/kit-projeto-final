---
name: analisar-relatos
description: Lê o RELATO.md e o código entregue por todos os alunos de uma atividade prática (ppNN), roda os testes e procura código quase idêntico entre entregas, e gera dois documentos — um resumo anônimo para discutir em sala (dificuldades recorrentes, uso de IA, onde o relato bate ou destoa do código) e um identificado, só para o professor usar na avaliação. Use quando o usuário pedir para avaliar/analisar os relatos de uma atividade, preparar uma discussão em sala sobre uma atividade, ou pedir para cruzar relato com código.
---

# Analisar relatos de uma atividade prática

Gera, a partir dos `RELATO.md` e do código de todos os alunos de uma
atividade prática (`ppNN`) do `kit-projeto-final`, dois documentos:

- `discussao-ppNN.md` — **anônimo e agregado**, pode ser levado à sala;
- `avaliacao-ppNN.md` — **identificado**, só para o professor, com quem
  está por trás de cada ponto (é usado na avaliação).

São arquivos separados de propósito: o anônimo pode ser projetado ou
compartilhado sem risco de expor alunos.

## Quando usar

O usuário pede para avaliar/resumir os relatos de uma atividade, ou
preparar pontos para discutir em sala sobre uma atividade prática. Se o
usuário não disser qual atividade (`ppNN`) e qual CSV de roster usar,
pergunte antes de continuar — não adivinhe. Montar o roster (ex: juntar
retardatários) é responsabilidade do usuário, não da skill: use o CSV
indicado como está.

## Passo 1 — Coletar

Rode, a partir de `atividades-praticas/`:

```
./scripts/coletar-entregas.sh --config config/ppNN.env <roster.csv> entregas-ppNN
```

Isso clona (raso) o template da atividade em `entregas-ppNN/_template/`
e o repositório de cada aluno em `entregas-ppNN/<usuario>/`. A pasta é
local e ignorada pelo git (veja `.gitignore` na raiz do kit) — nunca a
adicione a um commit.

A `main` dos repositórios é protegida e muitos alunos entregam por PR
**sem mesclar**. O script já trata isso: se o PR mais recente do aluno
está aberto, a pasta fica no head desse PR; se não, na branch padrão. Ele
grava `entregas-ppNN/_entregas.tsv` (usuário, nome, origem — `main` ou
`PR#N aberto` — e o estado de todos os PRs). Use o nome desse manifesto
no relatório identificado.

Trate à mão os avisos de **mais de um PR aberto** (típico de quem edita
pelo editor web do GitHub, que abre um PR por arquivo): veja o que cada
PR toca com `gh pr view N -R <org>/<repo> --json files` e remonte a
entrega (ex: `RELATO.md` de um PR, código de outro) com
`git -C <pasta> fetch --depth=1 origin refs/pull/N/head` +
`git -C <pasta> show FETCH_HEAD:<arquivo> > <pasta>/<arquivo>`. Quando
um PR posterior piora a entrega (ex: um PR antigo passava nos testes e o
novo não compila), registre isso no relatório identificado.

Note quem ficou de fora (sem repositório, sem `RELATO.md`, relato ainda
igual ao template, código igual ao template).

## Passo 2 — Testes e similaridade (automático)

Ainda em `atividades-praticas/`, rode os dois scripts da skill:

```
../.claude/skills/analisar-relatos/scripts/testar-entregas.sh entregas-ppNN
python3 ../.claude/skills/analisar-relatos/scripts/similaridade.py entregas-ppNN
```

- `testar-entregas.sh` roda os testes **do template** sobre o código de
  cada aluno (em cópia temporária — um aluno que alterou os testes é
  avaliado pelos originais) e grava `entregas-ppNN/_testes.tsv`
  (resultado: passa / falha / não compila / sem código; total e falhas;
  se o aluno mexeu nos testes). Log de quem não compila fica em
  `entregas-ppNN/<usuario>.testes.log`.
- `similaridade.py` compara só o código escrito pelo aluno (descarta o
  que veio do template) entre todos os pares e marca os pares acima do
  limiar (padrão 0,6), sempre listando os 5 mais parecidos. **Abra o
  código de cada par marcado** antes de concluir qualquer coisa: exercício
  curto converge para soluções parecidas; o que pesa é coincidência em
  detalhes arbitrários (nomes, ordem, o mesmo bug). Cruze com o "com quem
  você fez" dos dois relatos — a discrepância interessante é quando um
  declara a colaboração e o outro diz "sozinho".

## Passo 3 — Ler cada aluno: relato + diff contra o template

Para cada pasta de aluno em `entregas-ppNN/` (exceto `_template/`):

1. Leia `RELATO.md` — extraia as respostas de cada seção (dificuldades,
   grau de dificuldade 1-5, quão interessante 1-5, tempo gasto, uso de
   IA, com quem fez).
2. Compare com o template para ver o que o aluno de fato mudou, sem o
   ruído do boilerplate:
   ```
   diff -rq --exclude=.git --exclude=RELATO.md --exclude=build --exclude=.gradle entregas-ppNN/_template/ entregas-ppNN/<usuario>/
   ```
   Para os arquivos que aparecerem como diferentes, rode
   `diff -u entregas-ppNN/_template/<arquivo> entregas-ppNN/<usuario>/<arquivo>`
   para ver o que mudou de fato.

Isso te dá, por aluno, um par (o que ele disse) × (o que ele entregou),
mais o resultado dos testes. **Anote quem é quem em cada ponto** — o
relatório identificado precisa disso; o anônimo só usa as contagens.

Exemplos do tipo de relação que vale procurar:
- Aluno relata dificuldade em X — o diff mostra retrabalho/gambiarra em X?
  Ou X está bem resolvido, sugerindo que a dificuldade foi superada?
- Aluno diz "não usei IA" — o código tem marcas típicas de geração por
  IA (comentários genéricos demais, padrões fora do que foi ensinado em
  aula)? Trate isso como hipótese a mencionar com cautela, nunca como
  acusação — não é evidência definitiva. Vale também no relatório
  identificado.
- Aluno diz ter achado fácil (nota 1-2) mas o diff mostra solução
  incompleta/com atalhos — ou o oposto, achou difícil mas a solução é
  sólida.
- Testes falhando e o relato não menciona — o aluno chegou a rodar os
  testes?
- Vários alunos travando no mesmo método/conceito, visível tanto no
  relato quanto no código (bom candidato a puxar em sala).
- Relatos apontando inconsistência no próprio enunciado/template
  (README × testes × exemplo) — confira nos arquivos do `_template/` e,
  se procede, registre como ajuste sugerido no template.

## Passo 4 — Sintetizar

### `discussao-ppNN.md` — anônimo

Resumo **agregado e anônimo** (sem nomear aluno nenhum nem dar detalhe
que identifique alguém — agrupe por tema: "vários alunos relataram...",
"N de M alunos..."), com:

- **Números**: quantos entregaram (e como: PR mesclado × aberto),
  resultado dos testes, média/distribuição de grau de dificuldade, de
  "quão interessante", de tempo gasto.
- **Dificuldades recorrentes**: temas que se repetem nos relatos,
  cruzados com o que o diff mostra sobre esses trechos de código.
- **Uso de IA**: padrões de como/quando os alunos usaram (ou não)
  ferramentas de IA, e qualquer padrão notável entre o relatado e o
  código (mencionado com cautela, como hipótese).
- **Discrepâncias interessantes**: onde relato e código não batem, de
  forma agregada (ex: "N alunos disseram achar fácil, mas o código
  sugere retrabalho considerável"; "um par de entregas quase idênticas").
- **Perguntas sugeridas para puxar a discussão em sala** — 4 a 6
  perguntas abertas, construídas a partir dos pontos acima.
- **Ajustes sugeridos no template**, se algum relato ou o código
  revelou problema no enunciado/testes.

### `avaliacao-ppNN.md` — identificado, só para o professor

Espelha as seções do anônimo, mas diz **quem** (nome + usuário do
GitHub, do `_entregas.tsv`):

- **Tabela por aluno**: origem da entrega (PR mesclado/aberto/nenhuma),
  testes (x/y, não compila, sem código), dificuldade, interesse, tempo,
  uso de IA declarado (resumo curto), com quem fez, e uma coluna de
  observações (o que chamou atenção no código ou no relato).
- **Quem não entregou** (sem código e/ou relato vazio).
- **Por dificuldade recorrente**: a lista de quem relatou e de quem
  apresentou o problema no código.
- **Similaridade**: cada par marcado pelo script, com a nota, o que
  coincide (ex: o mesmo bug) e o que cada relato declara sobre
  colaboração.
- **Discrepâncias relato × código e hipóteses de uso de IA**, por aluno
  — sempre como hipótese, com o que no código motivou a observação.
- **Entregas que merecem atenção na avaliação**: testes falhando,
  entrega quebrada por PR posterior, PR não mesclado, entrega espalhada
  em vários PRs.

### Onde salvar

Salve os dois como arquivos Markdown locais (não Artifact — decisão já
tomada com o usuário), fora do `kit-projeto-final` versionado — ao lado
do roster, ex: `GestaoQXD0007/discussao-ppNN.md` e
`GestaoQXD0007/avaliacao-ppNN.md` — a não ser que o usuário peça outro
caminho. Nunca publique nem versione o `avaliacao-ppNN.md`.

## Passo 5 — Limpar

Depois de gerar os documentos, avise que `entregas-ppNN/` contém clones
locais de repositórios privados de alunos e pergunte se pode apagar
(`rm -rf entregas-ppNN`) — só apague com confirmação explícita.
