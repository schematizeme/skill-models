---
description: schematize-models — explica qual modelo usar para uma tarefa e por quê, pela tabela de pesos (Claude no código; externo só por mídia, segunda opinião, vantagem com fonte ou pedido do usuário).
argument-hint: "<descrição da tarefa>"
---
Roteie a tarefa em `$ARGUMENTS` **sem executar nada**. Leia `references/roteamento.md` e responda
neste formato:

0. **Portfólio:** rode `scripts/detectar.sh`; `modo: "claude-only"` -> ignore as regras de
   assinatura (comportamento de sempre). Com portfólio, aplique `references/roteamento.md` §6.
1. **Decomposição:** a tarefa mistura tipos? Separe (ex.: tela = código, logo = mídia).
2. **Por parte:** modelo recomendado, **peso do Claude** (0-10), e o **motivo** entre (a) não é
   texto, (b) segunda opinião, (c) vantagem documentada — **cite a fonte da §3** —, (d) pedido do
   usuário, (e) economia por assinatura (§6: o tipo da tarefa na taxonomia do placar, fit forte ou
   genérico, custo marginal, e o que diz `placar.sh preferir <tipo>`). Se não cai em nenhum: **Claude** (ou subagent Claude pela escada §9), e diga que
   delegar seria o defeito.
3. **Custo e egress:** se envolver externo, avise que gasta cota do usuário e o que sai da máquina.
4. **Próximo comando:** `/models-delegate`, `/models-review`, `/models-image` ou `/models-score`.

Código e refactor seguem a **escada da engineering** (Sonnet primeiro): o placar não a inverte; a
assinatura entra nos degraus Codex/Cursor e como transbordo de paralelismo.

Nunca recomende outro modelo para escrever código "porque é melhor": a casa não aceita essa
afirmação sem prova, e nenhuma foi apresentada.
