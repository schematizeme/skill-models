---
description: schematize-models — placar de ferramentas (Codex, Cursor, Gemini, subagents): ver, ajustar o resultado após revisar, publicar o feedback agregado (opt-in) e ligar/desligar.
argument-hint: "[ver | ajustar <id|ultimo> <resultado> | publicar | optin on|off]"
---
Placar de ferramentas (`references/placar.md`). Script: `scripts/placar.sh`. Em `$ARGUMENTS`, pelo
verbo (padrão: **ver**):

- **ver:** `placar.sh resumo` (ferramenta x tipo: n, %ok, %corr, %falha) e `placar.sh status`.
  Mostre a tabela e diga com honestidade quando a amostra é pequena (< 5 por célula não ranqueia).
- **ajustar `<id|ultimo> <resultado>`:** depois de **revisar** uma entrega, corrija o resultado
  (`corrigido-pelo-revisor` ou `falhou`; opcional `--nota` de categoria fechada). O id vem do
  `placar_id` do `delegar.sh`.
- **publicar:** `placar.sh publicar --agora`. Sem opt-in, **não publica**: siga "ligar" abaixo.
- **ligar (`optin on`):** primeiro `placar.sh optin previa` e **mostre ao usuário a prévia exata do
  comentário**. Diga **sem rodeio**: o comentário fica **no nome da conta GitHub dele**, em
  repositório público (`schematizeme/schematize-models-placar`); o conteúdo é anônimo (só contagens
  agregadas), a **autoria não é**. Pergunte (AskUserQuestion). Só com "sim":
  `placar.sh optin on --confirmo`. Precisa de `gh` autenticado e `jq`; sem eles nada é publicado.
- **desligar (`optin off`):** `placar.sh optin off`; o placar segue local.

Pisos: o placar **nunca** recebe código, caminho, nome de projeto, prompt nem texto livre (o script
recusa); publicar é no máximo 1x por semana e só com >= 5 amostras; falha de rede é ignorada.
