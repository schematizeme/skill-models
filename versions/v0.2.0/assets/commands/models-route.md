---
description: schematize-models — explica qual modelo usar para uma tarefa e por quê, pela tabela de pesos (Claude no código; externo só por mídia, segunda opinião, vantagem com fonte ou pedido do usuário).
argument-hint: "<descrição da tarefa>"
---
Roteie a tarefa em `$ARGUMENTS` **sem executar nada**. Leia `references/roteamento.md` e responda
neste formato:

1. **Decomposição:** a tarefa mistura tipos? Separe (ex.: tela = código, logo = mídia).
2. **Por parte:** modelo recomendado, **peso do Claude** (0-10), e o **motivo** entre (a) não é
   texto, (b) segunda opinião, (c) vantagem documentada — **cite a fonte da §3** —, (d) pedido do
   usuário. Se não cai em nenhum: **Claude** (ou subagent Claude pela escada §9), e diga que
   delegar seria o defeito.
3. **Custo e egress:** se envolver externo, avise que gasta cota do usuário e o que sai da máquina.
4. **Próximo comando:** `/models-delegate`, `/models-review` ou `/models-image`.

Nunca recomende outro modelo para escrever código "porque é melhor": a casa não aceita essa
afirmação sem prova, e nenhuma foi apresentada.
