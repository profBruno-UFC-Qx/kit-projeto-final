# Formulário de coleta de equipes (Google Forms)

Uma resposta por **equipe** (não por aluno). Um integrante preenche pela equipe toda. Vale para qualquer disciplina que use o kit.

## Campos

1. **Tema proposto do projeto** — resposta curta, obrigatório.
   Vira o nome do repositório (`<prefixo-da-disciplina>-<tema-em-slug>`),
   então peça que seja específico o bastante para não colidir com outra
   equipe (o `criar-repos.sh` rejeita temas duplicados).

2. Para cada **Membro 1 a Membro 10**, três campos de resposta curta:
   - `Nome completo - Membro N`
   - `Matrícula - Membro N`
   - `Link do perfil do GitHub - Membro N`

   Peça o link (`github.com/usuario`) em vez de só o usuário — é
   clicável na hora de conferir e reduz erro de digitação. Os scripts do
   kit aceitam tanto o link quanto o usuário puro, então não é preciso
   extrair nada manualmente ao montar o CSV (veja a seção abaixo).

   Apenas os três campos do **Membro 1** são obrigatórios. Membros 2 a 10
   ficam como opcionais (o Google Forms permite desmarcar "obrigatório"
   por campo). Isso cobre equipes de tamanho variável sem travar o
   formulário num número fixo.

   Dica ao montar o form: use a opção "Duplicar pergunta" três vezes por
   membro e ajuste o número, é mais rápido que criar do zero.

## Convertendo a planilha de respostas para o CSV dos scripts

O Google Forms exporta uma linha por equipe, mas em formato "largo" (uma
coluna por campo de cada membro). Os scripts do kit esperam um CSV
simples de 2 colunas: `tema,usuarios_github` (usuários separados por `;`).

Numa coluna auxiliar da planilha de respostas, monte a lista de links com
uma fórmula, por exemplo (ajuste as letras de coluna para onde ficaram os
campos "Link do perfil do GitHub"):

```
=TEXTJOIN(";", TRUE, K2, N2, Q2, T2, W2, Z2, AC2, AF2, AI2, AL2)
```

Se sua planilha não tiver `TEXTJOIN` (ou o parâmetro de ignorar vazios
não funcionar direito), não tem problema usar uma concatenação simples
que deixa `;` vazios entre os membros que não preencheram, por exemplo:

```
=K2&";"&N2&";"&Q2&";"&T2&";"&W2&";"&Z2&";"&AC2&";"&AF2&";"&AI2&";"&AL2
```

Os scripts do kit ignoram campos vazios entre `;` automaticamente.

Depois copie as colunas necessárias para um novo arquivo/aba e salve como
CSV com um cabeçalho contendo pelo menos `tema` e `usuarios_github` (em
qualquer posição). Colunas extras — como uma coluna `disciplina` que sua
planilha já traga por padrão — são ignoradas, não precisa removê-las
manualmente. Não precisa extrair o usuário do link antes de colar — os
scripts do kit aceitam `github.com/usuario` ou o link completo direto no
CSV. Para 15-20 equipes por disciplina/semestre, copiar/colar manualmente
é mais simples do que automatizar essa etapa.

## Respostas atrasadas

Se um aluno responder depois do prazo e a equipe for aceita mesmo assim,
não é preciso nada especial: adicione a linha correspondente ao
`equipes.csv` (completo, com as equipes anteriores) e rode
`criar-repos.sh` de novo — repositórios já existentes são detectados e
pulados automaticamente, só o novo é criado.
