<!--
  Seção genérica para compor a página "Projeto Final" do site de cada
  disciplina (formato Jekyll + tema Just the Docs, mesmo padrão usado em
  fundamentals-of-web-programming/projeto_final/index.md). Cobre só o
  PROCESSO (igual em todas as disciplinas) — não fala de tecnologia,
  requisitos mínimos ou critérios de avaliação, que continuam sendo
  seções próprias de cada site.

  Antes de colar isso no site de uma disciplina:
  - troque LINK_DO_FORMULARIO pelo link do Google Form daquela disciplina
  - ajuste os prazos na lista de âncoras do topo da página (fora deste
    trecho)
  - se o site já tiver seções tipo "Envio das telas" (entrega
    intermediária) que não existem no fluxo do kit, decida se elas
    continuam como um requisito à parte da disciplina ou se são
    descontinuadas — não são cobertas por nenhum check automático
-->

## Como funciona a entrega do projeto final <a name="fluxo"></a>

O projeto final não usa mais o GitHub Classroom. O fluxo passa por um
formulário, um repositório de equipe já pronto no GitHub, e duas
aprovações do professor via Pull Request: uma na proposta, outra na
entrega final.

### Formulário e repositório da equipe <a name="formulario"></a>

Preencha o formulário abaixo — uma resposta por equipe (um integrante
preenche pelos demais):

<a href="LINK_DO_FORMULARIO" class="btn" target="_blank">Formulário de equipes</a>

- Informe o tema do projeto e, para cada integrante, nome completo,
  matrícula e o **link do perfil do GitHub** (ex: `github.com/seu-usuario`).

{: .warning }
Confira o link do perfil do GitHub de cada integrante antes de enviar. É
por ele que o professor adiciona cada um como colaborador do repositório
da equipe — um link errado significa que a pessoa errada (ou ninguém)
recebe acesso.

Depois que o professor processar as respostas, cada integrante recebe um
**convite de colaborador** (por e-mail, ou em
<a href="https://github.com/notifications" target="_blank">github.com/notifications</a>)
para o repositório da equipe, já criado a partir do template da
disciplina. **Aceite o convite** e clone o repositório:

```bash
git clone https://github.com/profBruno-UFC-Qx/<nome-do-repositorio>.git
```

{: .note }
> O trabalho pode ser feito em equipe.

<hr>

### Envio da proposta <a name="envio-proposta"></a>

No repositório da equipe, crie uma branch e edite o arquivo
**`PROPOSTA.md`**, preenchendo todas as seções (objetivo, público-alvo,
funcionalidades, entidades...):

```bash
git checkout -b proposta
# edite PROPOSTA.md
git add PROPOSTA.md
git commit -m "Proposta do projeto"
git push origin proposta
```

Abra um **Pull Request** da branch `proposta` para `main` no GitHub. Um
check automático confere se todas as seções foram preenchidas (sem o
texto de exemplo). O professor revisa o conteúdo e aprova (ou pede
ajustes) diretamente no PR — **o desenvolvimento só está oficialmente
liberado depois do merge**.

{: .highlight }
> Os temas devem ser distintos entre as equipes da disciplina. A ordem de
> envio determina a prioridade sobre um tema — se já tiver sido escolhido
> por outra equipe, proponha um novo.

<hr>

### Desenvolvimento <a name="desenvolvimento"></a>

Depois da proposta aprovada, desenvolva o projeto livremente em uma ou
mais branches, sem precisar de aprovação do professor a cada commit ou PR
intermediário. A branch `main` só recebe o merge da proposta e, mais
adiante, o merge da entrega final — todo o código da equipe deve estar
incluído na branch usada na entrega.

{: .warning }
TODOS os membros da equipe devem se envolver na escrita de código.

<hr>

### Entrega final <a name="envio-entrega"></a>

Próximo ao prazo final, garanta que todo o código do projeto está na
branch, crie/atualize uma branch e edite o arquivo **`ENTREGA.md`**
preenchendo: como executar o projeto, credenciais de acesso para teste,
uso de ferramentas de Inteligência Artificial e as maiores dificuldades
encontradas.

```bash
git checkout -b entrega-final
# edite ENTREGA.md
git add ENTREGA.md
git commit -m "Entrega final"
git push origin entrega-final
```

Abra um Pull Request da branch `entrega-final` para `main`. Um check
automático confere se as seções obrigatórias de `ENTREGA.md` foram
preenchidas. O professor revisa e aprova — **o merge desse PR é a
confirmação formal da entrega**.

{: .warning }
> Na data final, todo o código deve estar disponível no GitHub. Não serão
> aceitos trabalhos enviados em formato compactado (zip, rar etc.) nem
> implementados em um único commit.
>
> Caso o trabalho seja feito em equipe, cada membro deve usar o próprio
> usuário do GitHub para escrever código.
