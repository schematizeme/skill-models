---
description: schematize-models — carrega à força TODO o corpo normativo (roteamento, delegação, mídia, versões) e passa a aplicá-lo nesta sessão.
---
Carregue **agora** o corpo normativo da skill `schematize-models`. A partir daqui, nesta sessão,
isto **não é opcional**.

1. **Leia na íntegra, sem trabalhar de memória.** Caminho:
   `.claude/skills/schematize-models/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-models/references/*.md` (global):
   - `roteamento.md` — o princípio (Claude no código, peso máximo), os quatro motivos para
     delegar, tabela tarefa x modelo x peso, vantagens **só com fonte**, a regra "Claude orquestra,
     despacha e REVISA", custo e egress.
   - `delegacao.md` — contrato da subtarefa, sandbox/aprovação por CLI, segredo, saída externa não
     confiável, falha.
   - `midia.md` — imagem nunca pelo Claude; o fluxo detectar -> perguntar -> gerar -> salvar; o
     texto sem rodeio quando nada está disponível; como cada CLI gera imagem hoje.
   - `stack-versoes.md` — anexo volátil: flags reais, versões e fontes, com data e o que foi
     verificado.
2. **Rode a detecção** antes de opinar sobre qualquer delegação:
   `bash .claude/skills/schematize-models/scripts/detectar.sh` (ou o caminho global).
3. **Aplique daqui em diante** a toda tarefa que considere outro modelo, e diga qual piso está
   aplicando quando ele mudar o que você ia fazer.
