# Adicionando uma disciplina nova

Este documento explica o fluxo completo que o kit implementa e o passo a
passo para conectar uma disciplina nova a ele. É baseado na experiência
real de configurar três disciplinas: QXD0020 (criada do zero, primeira a
usar o kit), QXD0276/Mobile (reforma de um template que já existia da
era GitHub Classroom, com um fluxo diferente) e QXD0007/POO (criada do
zero, sem nenhum repositório anterior).

## O fluxo, passo a passo

```
Aluno                                          Professor
  |                                                |
  |-- abre PR editando PROPOSTA.md -------------->|
  |   (check "validar-proposta" roda sozinho)      |
  |                                                |-- revisa, aprova
  |                                                |   ou pede mudanças
  |<----------- merge = proposta aprovada ---------|
  |                                                |
  |-- desenvolve livremente (sem gate) ----------->|
  |                                                |
  |                        (perto do prazo, professor roda
  |                         ativar-validacao-entrega.sh)
  |                                                |
  |-- abre PR editando ENTREGA.md --------------->|
  |   (check "validar-entrega" roda sozinho)       |
  |                                                |-- revisa, aprova
  |<----------- merge = entrega confirmada --------|
  |                                                |
  |                        (fim do semestre: clonar-tudo.sh)
```

Depois de criar os repositórios (e de novo perto do prazo final), rode
`verificar-colaboradores.sh` para conferir se todo mundo tem acesso de
verdade: ele distingue convite pendente (usuário existe, não aceitou —
cobrar) de usuário não encontrado (typo/errado no CSV — corrigir e rodar
`criar-repos.sh` de novo). Resposta atrasada do formulário também usa
`criar-repos.sh`: adicione a equipe ao CSV completo e rode de novo —
repositórios já existentes são detectados e pulados, só o novo é criado.

O board do GitHub Project de cada disciplina reflete esse estado sozinho:
todo PR de proposta é adicionado automaticamente ao abrir, e o workflow
nativo do Projects marca como concluído quando o PR é mesclado — sem
nenhuma automação extra da nossa parte para isso.

## Por que o fluxo é assim

**Por que `PROPOSTA.md` e `ENTREGA.md` são arquivos separados, e não um
único `README.md` cortado por um marcador** (como era originalmente):
eles são preenchidos em momentos bem diferentes do semestre e validados
por checks diferentes. Dois arquivos deixam isso óbvio pro aluno e
simplificam os scripts de validação — não precisam mais "cortar" um
arquivo antes de um marcador pra saber o que checar. Como bônus,
`README.md` fica livre pra virar a cara real do projeto, o que ajuda
quem quer usar o repositório como portfólio depois.

**Por que a validação mora num workflow reutilizável aqui no kit, e não
copiada em cada template**: corrigir um bug ou adicionar uma exigência
nova (por exemplo, quando o professor pediu para incluir uma pergunta
sobre uso de IA) se propaga para todas as disciplinas com um push só
aqui — sem precisar lembrar de replicar a mudança em cada template
manualmente.

**Por que o kit é um repositório público**: workflows reutilizáveis de
um repositório privado só podem ser chamados por outros repositórios
**privados** da mesma organização. Como os repositórios das equipes são
públicos (fazem parte do portfólio dos alunos), o kit também precisa
ser. Isso não vaza nada sensível de qualquer forma: o log do Actions já
mostra o script inteiro rodando, então manter o kit "privado" nunca
escondeu o conteúdo de verdade.

**Por que a proteção de branch não é relaxada depois da proposta
aprovada**: se relaxasse, a exigência de aprovação do professor na
entrega final também deixaria de valer. A `main` fica protegida
(aprovação de code owner + check obrigatório) o semestre inteiro; só o
*conjunto* de checks obrigatórios muda (proposta apenas → proposta +
entrega), via `ativar-validacao-entrega.sh`.

## Passo a passo: conectando uma disciplina nova

### 0. Decida o prefixo

Escolha o código da disciplina (ex: `qxd0193`). Ele vira o prefixo dos
repositórios das equipes: `qxd0193-<tema-da-equipe>`.

### 1. Repositório-template: reformar ou criar do zero?

- **Já existe um `<prefixo>-projeto-final`** de um semestre anterior
  (possivelmente da era GitHub Classroom)? Clone-o e adapte — foi o caso
  do Mobile. Preste atenção especial a `CONTRIBUTING.md`/`README.md`
  antigos: podem descrever um fluxo diferente do kit (ex: entregas em
  múltiplos estágios). Confirme com o professor antes de substituir
  silenciosamente — não assuma que o fluxo do kit é sempre um upgrade
  direto.
- **Não existe nada ainda**? Crie do zero — foi o caso da POO.
  ```bash
  mkdir <prefixo>-projeto-final && cd <prefixo>-projeto-final
  git init
  ```

### 2. Copie os documentos canônicos

```bash
cp templates/PROPOSTA.md <caminho-do-template>/PROPOSTA.md
cp templates/ENTREGA.md  <caminho-do-template>/ENTREGA.md
```

`PROPOSTA.md` normalmente não precisa de nenhuma edição — o formato já
se mostrou compartilhável entre disciplinas bem diferentes (web, mobile,
POO).

Em `ENTREGA.md`, tudo **antes** do marcador
`<!-- kit:fim-secoes-genericas -->` também não muda. Edite só o que vem
**depois** do marcador, com o que for específico da disciplina — pense
no que só faz sentido avaliar naquela stack (tecnologias e CRUD para
web, bibliotecas para mobile, diagrama de classes para POO...).

Crie também um `README.md` simples (nome do projeto + link pros outros
dois documentos) — use qualquer um dos templates existentes como
exemplo.

### 3. Adicione os workflows finos e o CODEOWNERS

Em `.github/workflows/` do template da disciplina:

```yaml
# validar-proposta.yml
name: Validar Proposta
on:
  pull_request:
    branches: [main]
jobs:
  validar-proposta:
    uses: profBruno-UFC-Qx/kit-projeto-final/.github/workflows/validar-proposta.yml@main
```

(mesma estrutura para `validar-entrega.yml`, trocando só o nome do
arquivo referenciado)

```yaml
# adicionar-ao-board.yml
name: Adicionar ao Board de Propostas
on:
  pull_request:
    types: [opened]
    branches: [main]
jobs:
  adicionar-ao-board:
    name: adicionar-ao-board
    runs-on: ubuntu-latest
    steps:
      - uses: actions/add-to-project@v1.0.2
        with:
          project-url: https://github.com/orgs/profBruno-UFC-Qx/projects/NUMERO_DO_PROJETO
          github-token: ${{ secrets.ADD_TO_PROJECT_PAT }}
```

E `.github/CODEOWNERS`:
```
* @brunomateus
```

### 4. Estrutura de pastas do projeto (opcional)

Decida se faz sentido algum scaffold de pastas (como
`backend/`/`frontend/`/`telas/` na QXD0020) ou se fica livre (como
Mobile e POO ficaram). Isso depende só da disciplina — o kit nunca dita
nada sobre a estrutura interna do projeto.

### 5. Publique e marque como template

```bash
gh repo create profBruno-UFC-Qx/<prefixo>-projeto-final --public \
  --source=. --remote=origin --push
gh api -X PATCH repos/profBruno-UFC-Qx/<prefixo>-projeto-final -f is_template=true
```
(se o repositório já existia, só o `git push` é necessário — confirme
que `visibility` já é `public` e `is_template` já é `true`)

### 6. Crie o GitHub Project (board)

`gh project create` exige o escopo `project` no token, que costuma
travar em ambientes não-interativos — mais simples pela interface web:

1. `https://github.com/orgs/profBruno-UFC-Qx/projects` → **New project**
2. Escolha o template **Board** (já vem com as automações "item
   adicionado" e "PR mesclado → Done" prontas, sem configuração extra)
3. Nome: `Propostas Projeto Final — <DISCIPLINA>`
4. Anote o número no final da URL (`.../projects/<numero>`)
5. Cole esse número em `adicionar-ao-board.yml` (passo 3), substituindo
   `NUMERO_DO_PROJETO`, e dê push

### 7. Secret `ADD_TO_PROJECT_PAT`

Se já existe (configurado como secret de **organização**, com acesso a
"All repositories"), **nada a fazer** — o repositório novo já enxerga o
secret automaticamente. Só é preciso recriá-lo se o PAT existente tiver
sido restrito a uma lista fixa de repositórios em vez de "All
repositories".

### 8. Pasta de gestão local

```bash
mkdir Gestao<DISCIPLINA>
cp config-exemplo.env Gestao<DISCIPLINA>/<prefixo>.env
# edite ORG, TEMPLATE_REPO, PREFIXO_REPO dentro do arquivo
```

### 9. Formulário de equipes

Crie um Google Form novo seguindo `formulario-google-forms.md` — os
times não são compartilhados entre disciplinas, cada uma tem o seu
formulário e o seu roster.

### 10. Pronto para o semestre

```bash
./scripts/criar-repos.sh --config Gestao<DISCIPLINA>/<prefixo>.env Gestao<DISCIPLINA>/equipes.csv
./scripts/verificar-colaboradores.sh --config Gestao<DISCIPLINA>/<prefixo>.env Gestao<DISCIPLINA>/equipes.csv
```
