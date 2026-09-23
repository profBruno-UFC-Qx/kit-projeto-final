# Extensão universitária no projeto final

Ferramentas para lidar com a etapa de proposta/entrega quando o
projeto final pode ser caracterizado como **extensão universitária**
(Resolução CNE/CES nº 7, de 18/12/2018 — Diretrizes para a Extensão na
Educação Superior Brasileira). Opcional: use se a sua disciplina quer
incentivar/comprovar esse formato; nada aqui é obrigatório para o resto
do kit funcionar.

## Os critérios (Art. 3º da Resolução)

O que caracteriza uma ação de extensão, resumido:

1. **Interação com comunidade externa** — público-alvo real fora da
   universidade, não usuários genéricos/hipotéticos.
2. **Interação transformadora / impacto social** — mudança concreta na
   vida dessa comunidade, não um benefício abstrato.
3. **Vinculação à formação do estudante** — satisfeito por ser projeto
   de disciplina; não é o critério discriminante.
4. **Interação dialógica** — troca de mão dupla com a comunidade, não
   um serviço unidirecional.

O critério 4 é o mais difícil de verificar: o texto de uma proposta só
prova *intenção*, não que a conversa de fato aconteceu. É para isso que
serve a declaração descrita mais abaixo.

## Duas ferramentas, dois momentos

### Na proposta: avaliar se o projeto *parece* extensão

Skill `avaliar-propostas` (veja `.claude/skills/avaliar-propostas/`):
lê o `PROPOSTA.md` de cada equipe cuja proposta ainda não foi aprovada
e dá um parecer de apoio, equipe por equipe, sobre os critérios 1-3
acima. **Não é uma certificação oficial** — é um parecer para ajudar
você a decidir o que aprovar e o que pedir de ajuste antes de aprovar.

### Na entrega: comprovar que a interação dialógica aconteceu

Para as equipes cujo projeto foi tratado como extensão, use
`templates/CARTA-APRESENTACAO-STAKEHOLDER.md` e
`templates/DECLARACAO-EXTENSAO.md`:

1. **Você** (professor) adapta a carta e a declaração uma vez, com os
   dados da sua disciplina (cabeçalho de ambas), e disponibiliza os
   dois arquivos às equipes (ex: linkados na página da disciplina, ou
   por e-mail).
2. **A equipe** leva os dois documentos até o stakeholder: a carta dá
   legitimidade institucional ao pedido (explica quem está pedindo e
   por quê — reduz a chance de parecer spam/golpe para quem recebe); a
   declaração é preenchida com/pelo stakeholder, com destaque para o
   campo "qual problema este projeto pretende resolver" respondido nas
   palavras dele — isso importa mais que a assinatura em si, que
   sozinha é fácil de contornar (um conhecido do aluno poderia assinar
   sem ter havido conversa real).
3. **A equipe entrega a declaração assinada a você**, fora do Git — por
   e-mail, ou upload num Drive que só você controla. **Não commite a
   declaração no repositório da equipe nem a anexe a um PR**: ela
   contém dado pessoal de alguém que não é aluno nem participa do kit
   (nome, contato, às vezes organização), e o repositório é histórico
   permanente que pode até virar público um dia. Trate como qualquer
   outro dado pessoal de terceiro sob a LGPD — minimize o que é pedido
   (já reduzido ao essencial no template) e mantenha em um canal
   controlado por você.
4. Adicione ao `ENTREGA.md` da sua disciplina (abaixo do marcador
   `<!-- kit:fim-secoes-genericas -->`, junto com as demais seções
   específicas) um campo simples de autodeclaração, sem dado pessoal:
   ```markdown
   ## Comprovação de interação com stakeholder (extensão)
   _Se este projeto foi tratado como extensão, informe como e quando você
   entregou a declaração assinada ao professor. Se não se aplica, indique
   "Não se aplica"._
   ```
   O arquivo assinado em si continua fora do Git; este campo só registra
   que a entrega aconteceu, para você conferir.

## Limite honesto

Nem a carta, nem a declaração, nem o parecer da skill são prova
irrefutável — um aluno determinado ainda pode contornar qualquer um
desses controles. O objetivo é levantar a régua e criar um rastro
auditável, não blindar contra fraude. A decisão final sobre o que conta
como hora de extensão para fins de creditação curricular é institucional
(núcleo/pró-reitoria de extensão da sua universidade) — este kit ajuda a
organizar o processo, não substitui essa decisão.
