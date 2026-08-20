# atividades-praticas

Ferramentas compartilhadas para o fluxo de atividades práticas
individuais: um repositório por aluno por atividade, criado dentro da
org a partir de um template, com `RELATO.md` substituindo o formulário
Google Forms e a branch protegida (Pull Request + check obrigatório para
poder mesclar).

Faz parte do mesmo `kit-projeto-final`, mas é um fluxo separado: aqui não
existe etapa de proposta — as atividades são individuais e de escopo
fechado, então "criar o repositório" e "poder submeter" acontecem na
mesma proteção de branch, sem uma fase de aprovação prévia. Os workflows
reutilizáveis (`validar-relato.yml`, `testes.yml`) ficam em
`.github/workflows/` na raiz do repositório — GitHub só permite workflow
reutilizável ali, não dentro desta subpasta.

## O que tem aqui

- `../.github/workflows/validar-relato.yml` — workflow reutilizável que
  valida as seções genéricas de `RELATO.md` (nome, matrícula, com quem
  fez, dificuldades, autoavaliação, tempo gasto, uso de IA)
- `../.github/workflows/testes.yml` — workflow reutilizável que roda
  `./gradlew test` em todo push
- `templates/RELATO.md` — conteúdo canônico a copiar para a raiz de cada
  repositório-template de atividade
- `templates/roster-exemplo.csv` — modelo do CSV de alunos (colunas
  `matricula`, `nome`, `usuario_github`)
- `config/pp01.env` … `pp06.env` — um arquivo de configuração por
  atividade prática atual, já apontando para o template certo
- `scripts/criar-repos.sh` — cria um repositório por aluno a partir do
  template da atividade, adiciona o aluno como colaborador e protege a
  branch (PR + check `Validar Relato` obrigatórios, sem exigir aprovação
  humana)
- `scripts/verificar-colaboradores.sh` — relata usuários com convite
  pendente (não aceito) ou não encontrados (typo/inexistente)
- `scripts/relatorio-entregas.sh` — visibilidade de quem entregou: para
  cada aluno do roster, mostra se o repositório existe e o resultado mais
  recente dos checks `Validar Relato` e `Testes`

## Adicionando isso a um template de atividade nova

1. Copie `templates/RELATO.md` para a raiz do template, como `RELATO.md`.
2. Adicione `.github/workflows/relato.yml` no template:
   ```yaml
   name: Validar Relato
   on:
     push:
   jobs:
     validar-relato:
       uses: profBruno-UFC-Qx/kit-projeto-final/.github/workflows/validar-relato.yml@main
   ```
3. Adicione `.github/workflows/testes.yml` no template:
   ```yaml
   name: Testes
   on:
     push:
   jobs:
     testes:
       uses: profBruno-UFC-Qx/kit-projeto-final/.github/workflows/testes.yml@main
   ```
4. Confirme que o repositório continua marcado como **template**
   (Settings → Template repository).
5. Crie `config/ppNN.env` aqui, copiando um dos existentes e ajustando
   `TEMPLATE_REPO` e `PREFIXO_REPO`.

## Fluxo por atividade (com roster de alunos)

O roster (`matricula,nome,usuario_github`) é coletado uma vez por
semestre e reaproveitado nas seis atividades — só muda o
`config/ppNN.env` a cada rodada.

```
./scripts/criar-repos.sh --config config/pp01.env GestaoQXD0007/roster.csv
./scripts/verificar-colaboradores.sh --config config/pp01.env GestaoQXD0007/roster.csv
# ... alunos fazem push numa branch, abrem PR pra main, e mesclam quando
#     "Validar Relato" ficar verde (não precisa da sua aprovação) ...
./scripts/relatorio-entregas.sh --config config/pp01.env GestaoQXD0007/roster.csv --csv entregas-pp01.csv
```

Resposta atrasada do roster: adicione o aluno ao CSV completo (todos os
alunos + o novo) e rode `criar-repos.sh` de novo — repositórios já
existentes são detectados e pulados automaticamente.

Repositório do aluno é criado **privado** por padrão (`PRIVADO="true"` no
config) — evita que um aluno veja a solução do outro. Ajuste no
`config/ppNN.env` se preferir público.
