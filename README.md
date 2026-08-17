# kit-projeto-final

Ferramentas compartilhadas para o fluxo de projeto final de disciplinas
que usam equipes + repositório-template por equipe no GitHub:
proposta escrita → aprovação → desenvolvimento → entrega final validada
→ coleta em lote. Substitui o que o GitHub Classroom fazia antes de ser
descontinuado.

Este repositório cobre só o **processo** (criação de repositórios,
formato padrão de proposta/entrega, validação, aprovação, coleta). A
estrutura interna de cada projeto (pastas, stack, linguagem) é decidida
por cada disciplina, no próprio template dela.

## O que tem aqui

- `.github/workflows/validar-proposta.yml` — workflow reutilizável que
  valida `PROPOSTA.md` (seções obrigatórias presentes, placeholders
  substituídos)
- `.github/workflows/validar-entrega.yml` — workflow reutilizável que
  valida as seções genéricas de `ENTREGA.md` (como executar, credenciais
  de teste, uso de IA, dificuldades encontradas)
- `templates/PROPOSTA.md` e `templates/ENTREGA.md` — conteúdo canônico a
  copiar para o template de cada disciplina
- `scripts/criar-repos.sh` — cria os repositórios das equipes a partir
  do template da disciplina, adiciona colaboradores, protege a `main`
  (aprovação do professor + check de proposta obrigatórios)
- `scripts/ativar-validacao-entrega.sh` — roda perto do prazo final,
  passa a exigir também o check de entrega para mesclar na `main`
- `scripts/clonar-tudo.sh` — clona/atualiza em lote no fim do semestre
- `formulario-google-forms.md` — especificação dos campos do formulário
  de coleta de equipes
- `config-exemplo.env` — modelo do arquivo de configuração por disciplina

## Configuração única (por disciplina, ao adotar o kit)

1. Habilite, nas configurações deste repositório
   (Settings → Actions → General → Access), o acesso aos workflows
   reutilizáveis para toda a organização — necessário para que os
   templates de outras disciplinas (também privados/públicos na mesma
   org) consigam referenciar os workflows daqui.

2. No template da disciplina (ex: `qxd0020-projeto-final`):
   - Copie `templates/PROPOSTA.md` para a raiz como `PROPOSTA.md`
   - Copie `templates/ENTREGA.md` para a raiz como `ENTREGA.md`, e
     adicione abaixo do marcador `<!-- kit:fim-secoes-genericas -->` as
     seções específicas da disciplina (tecnologias, entregáveis
     próprios, etc.)
   - Adicione `.github/workflows/validar-proposta.yml` e
     `.github/workflows/validar-entrega.yml` referenciando os workflows
     deste repositório (veja o exemplo abaixo)
   - Adicione um `CODEOWNERS` marcando o professor como dono de
     `PROPOSTA.md` e `ENTREGA.md`
   - Marque o repositório como **template** (Settings → Template repository)

   Exemplo de workflow "fino" no template da disciplina:
   ```yaml
   name: Validar Proposta
   on:
     pull_request:
       branches: [main]
   jobs:
     validar-proposta:
       uses: profBruno-UFC-Qx/kit-projeto-final/.github/workflows/validar-proposta.yml@main
   ```
   (o mesmo padrão vale para `validar-entrega.yml`)

3. Crie uma pasta de gestão para a disciplina (fora do template, ex:
   `GestaoQXD0020/`) com uma cópia de `config-exemplo.env` preenchida e
   o roster (`equipes.csv`) daquele semestre.

## Fluxo por semestre/disciplina

```
./scripts/criar-repos.sh --config GestaoQXD0020/qxd0020.env GestaoQXD0020/equipes.csv
# ... alunos abrem PR de proposta, professor revisa e aprova ...
# ... perto do prazo final ...
./scripts/ativar-validacao-entrega.sh --config GestaoQXD0020/qxd0020.env GestaoQXD0020/equipes.csv
# ... alunos abrem PR de entrega, professor revisa e aprova ...
./scripts/clonar-tudo.sh --config GestaoQXD0020/qxd0020.env GestaoQXD0020/equipes.csv ./entregas-2026-2
```
