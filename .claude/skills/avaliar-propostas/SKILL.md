---
name: avaliar-propostas
description: Lê o PROPOSTA.md de todas as equipes de uma disciplina de projeto final (aberto ou já mesclado) e dá um parecer de apoio sobre se o sistema proposto pode ser caracterizado como extensão universitária, segundo os critérios do MEC/CNE. Use quando o usuário pedir para avaliar/revisar propostas de uma disciplina, checar se um projeto é extensão, ou preparar a aprovação de propostas.
---

# Avaliar propostas de projeto final (extensão universitária)

Dá um parecer de apoio, equipe por equipe, sobre se a `PROPOSTA.md`
descreve um sistema que pode ser caracterizado como **extensão
universitária**, para ajudar na revisão/aprovação das propostas.

## Quando usar

O usuário pede para avaliar/revisar as propostas de uma disciplina, ou
perguntar se os projetos propostos caracterizam extensão. Se não disser
qual disciplina (config) e qual `equipes.csv`, pergunte antes de
continuar — não adivinhe.

## Passo 1 — Coletar

Rode, a partir da raiz do `kit-projeto-final`:

```
./scripts/coletar-propostas.sh --config <disciplina.env> <equipes.csv> propostas-<disciplina>
```

Isso busca, por equipe, o `PROPOSTA.md` da Pull Request de proposta
aberta (o estado normal nesse ponto do fluxo — a proposta só é mesclada
depois da aprovação do professor via CODEOWNERS) ou, se não houver PR
aberta, da branch padrão. Só lê pela API, não clona nada. A pasta de
saída é local e não deve ser versionada.

`propostas-<disciplina>/_propostas.csv` traz, por equipe, o slug, o
repositório e a URL da PR (se houver) — use para saber onde comentar,
se o usuário pedir isso no Passo 4.

Equipes sem proposta (nem PR aberta, nem na branch padrão) também
entram no resumo — não são um erro, apenas um estado a reportar.

## Passo 2 — Critérios (Resolução CNE/CES nº 7/2018)

Avalie cada `PROPOSTA.md` contra estes elementos, que caracterizam ação
de extensão segundo o Art. 3º da Resolução CNE/CES nº 7, de 18/12/2018
(Diretrizes para a Extensão na Educação Superior Brasileira):

1. **Interação com comunidade externa** — o público-alvo é um grupo
   real fora da universidade (ex: uma ONG, um grupo de produtores, um
   bairro, uma categoria profissional específica) — não usuários
   genéricos/hipotéticos nem um sistema de uso só interno.
2. **Interação transformadora / impacto social** — o impacto descrito é
   uma mudança concreta na vida dessa comunidade, não só um benefício
   abstrato ou genérico ("vai facilitar a vida das pessoas").
3. **Vinculação à formação do estudante** — meramente satisfeito por
   ser um projeto de disciplina; não é o critério discriminante.
4. **Interação dialógica** (mão dupla, não serviço unidirecional) — a
   proposta menciona alguma demanda real identificada junto à
   comunidade, ou é um tema genérico escolhido sem esse vínculo?

O texto da proposta só prova *intenção* — não prova que a interação
dialógica de fato aconteceu. Deixe isso explícito no parecer.

## Passo 3 — Parecer por equipe

Para cada equipe, produza:
- **Veredito**: "parece extensão", "não parece extensão", ou "indefinido
  — falta informação" (nunca force um sim/não quando o texto for vago;
  isso é mais útil ao professor do que uma resposta binária errada).
- **Por quê**: 1-2 frases citando o que na proposta sustenta o veredito
  (público-alvo, impacto descrito).
- **O que perguntar/pedir à equipe**, se o veredito for "indefinido" ou
  "não parece" mas houver potencial (ex: "quem exatamente é o
  público-alvo? Foi conversado com alguém desse grupo?").

Este é um **parecer de apoio, não uma certificação oficial** — deixe
isso explícito no início do documento final. A decisão sobre
creditação como hora de extensão é institucional (núcleo/pró-reitoria
de extensão), não algo que uma leitura de texto decide sozinha.

## Passo 4 — Salvar (e, só se pedido, comentar nas PRs)

Salve o parecer completo como Markdown local, fora do kit versionado
(ex: ao lado do `equipes.csv` da disciplina), a não ser que o usuário
peça outro caminho.

Comentar diretamente nas PRs das equipes (`gh pr comment <url> --body
...`, usando a URL de `_propostas.csv`) é uma ação que expõe o parecer
aos alunos — só faça isso se o usuário pedir explicitamente, nunca por
iniciativa própria, e confirme antes de disparar os comentários.

## Limpeza

Ao final, pergunte se pode apagar a pasta `propostas-<disciplina>/`
(conteúdo de proposta de equipes, não deve ficar acumulado sem
necessidade) — só apague com confirmação explícita.
