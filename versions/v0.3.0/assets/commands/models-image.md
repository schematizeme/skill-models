---
description: schematize-models — gera imagem FORA do Claude: detecta Codex/Gemini autenticados, PERGUNTA ao usuário qual usar, gera, salva em arquivo e reporta caminho e licença (não verificada).
argument-hint: "<descrição da imagem> [arquivo de saída]"
---
Imagem/visual gerado/mídia **nunca por modelo Claude** (`references/midia.md`). Para `$ARGUMENTS`:

1. **Detecte:** `bash .claude/skills/schematize-models/scripts/detectar.sh`. Considere só
   **codex** e **gemini** (o Cursor CLI não tem geração de imagem documentada) com `utilizavel: true`.
2. **Nenhum utilizável -> pare e diga, sem rodeio** (texto de `midia.md` §3): o visual gerado pelo
   Claude tem qualidade inversamente proporcional à do código dele — sai muito ruim. Ofereça:
   (1) instalar/autenticar **Codex** ou **Gemini** (mostre o comando de `stack-versoes.md`; o usuário
   executa); (2) **banco de imagens com licença comercial**; (3) **asset do cliente/designer**.
   **Não** gere SVG/ASCII/imagem "para quebrar o galho".
3. **Pergunte ao usuário qual usar — com `AskUserQuestion`**, opções = só os utilizáveis. **Nunca
   escolha sozinho**, nem se houver um só. Avise: gasta a cota dele naquele provedor e o prompt sai
   para lá. Se escolher **Gemini**, diga que o caminho headless **não foi verificado** (precisa da
   extensão `nanobanana`, `NANOBANANA_API_KEY` e aprovação automática); prefira o `/generate`
   interativo dele, ou peça a flag `--aceito-aprovacao-automatica` explicitamente.
4. **Escreva o prompt de imagem** (sujeito, estilo, formato/proporção, restrições, sem texto
   embutido se não precisar; **sem segredo, sem dado pessoal de terceiros**).
5. **Gere:** `bash .../scripts/imagem.sh <provedor> "<prompt>" <saida.png>` (não sobrescreve; use
   `-v2` para nova versão). Exit `1` = o modelo não produziu imagem: **não declare sucesso**.
6. **Revise** a imagem (abra o arquivo) contra o brief; não bate -> nova rodada.
7. **Reporte:** caminho do arquivo, provedor, prompt, e a **licença como NÃO VERIFICADA** (cite o
   `.origem.json`): direitos de uso comercial dependem dos termos do provedor e do plano do
   usuário — **não afirme** que é livre.
