# Mídia: imagem nunca sai de modelo Claude (schematize-models)

> Parte da skill **schematize-models**. Piso inegociável da casa, vale para toda skill do
> catálogo. Detalhe técnico volátil (nome de ferramenta, extensão, versão): `stack-versoes.md`.

## 1. A regra

**Imagem, visual gerado e mídia NUNCA são produzidos por modelo Claude.** Isso inclui "desenhar" em
SVG/ASCII/CSS/canvas como **substituto** de uma ilustração, logo, ícone de marca, foto ou
arte. A razão é de qualidade, e é honesta: **a qualidade do visual que o Claude gera é
inversamente proporcional à do código que ele escreve — sai ruim de verdade.** (Diagrama
técnico, gráfico de dados e layout feitos **em código** — Mermaid, SVG programático, CSS — são
engenharia, não "imagem gerada", e ficam com o Claude.)

## 2. O fluxo obrigatório (`/models-image`)

1. **Detectar** (`scripts/detectar.sh`): quais entre Codex e Gemini estão **instalados e
   autenticados**.
2. **Perguntar** ao usuário **qual usar** (AskUserQuestion; opções = só os utilizáveis). **O Claude
   nunca escolhe sozinho**, nem "o melhor", nem "o único": mesmo com um só disponível, pergunta (o
   gasto de cota e o envio do prompt a um fornecedor são do usuário decidir).
3. **Gerar** via o escolhido (`scripts/imagem.sh <provedor> "<prompt>" <saida>`).
4. **Salvar em arquivo e reportar**: caminho, provedor, prompt, data, e a **licença como está**: o
   script grava `<saida>.origem.json` com a licença marcada **NÃO VERIFICADA** — os direitos de uso
   (comercial ou não) dependem dos termos do provedor e do plano do usuário; o Claude **não
   afirma** que é livre para uso comercial.
5. **Revisar**: o Claude abre a imagem (leitura de imagem) e confere se atende o brief antes de
   dizer que está pronta; imagem que não bate -> nova rodada, não "serve".

## 3. Nenhum utilizável

Mensagem **sem rodeio** (use este texto, adaptando só o contexto):

> Não há Codex nem Gemini utilizáveis nesta máquina. Eu não gero imagem: o visual gerado pelo
> Claude tem qualidade inversamente proporcional à do meu código — sai muito ruim, e entregar isso
> sairia caro para a sua marca. Opções: (1) instalar e autenticar o **Codex CLI** ou o **Gemini
> CLI** (te guio, ver `stack-versoes.md`); (2) **banco de imagens com licença comercial** (confira
> a licença de cada arquivo); (3) **asset do cliente/designer**. Qual prefere?

Nunca "quebrar o galho" com SVG artesanal, emoji ou imagem gerada pelo Claude "só por ora".

## 4. COMO cada CLI gera imagem hoje (verificado x não verificado)

| CLI | Caminho | Status | Evidência |
|---|---|---|---|
| **Codex** | ferramenta built-in `image_gen` do agente (o skill `imagegen` do Codex: "Does not require OPENAI_API_KEY"); o arquivo cai em `$CODEX_HOME/generated_images/<thread>/` | **VERIFICADO** nesta máquina em 2026-10-14: `codex exec` em sandbox read-only gerou um PNG (~1 MB) e `imagem.sh` o copiou | skill empacotado em `~/.codex/skills/.system/imagegen`; `codex features list` mostra `image_generation` stable/true; 211 PNGs prévios; smoke real |
| **Codex (fallback)** | `scripts/image_gen.py` do skill, com API da OpenAI e `OPENAI_API_KEY` | **só pela doc do skill**, não usado aqui; o skill manda pedir ao usuário antes | idem |
| **Gemini CLI** | **não é nativo**: a doc do Gemini CLI diz que MCP pode agregar "media generation with Imagen, Veo or Lyria"; a extensão oficial da comunidade **`nanobanana`** (`gemini extensions install https://github.com/gemini-cli-extensions/nanobanana`) gera/edita imagem com `NANOBANANA_API_KEY`, salva em `./nanobanana-output/` | **NÃO VERIFICADO** em headless: Gemini CLI ausente nesta máquina; a doc não diz se `/generate` funciona em `gemini -p`, e ferramenta MCP em headless exige aprovação automática | README da extensão; doc do Gemini CLI |
| **Cursor CLI** | nenhum documentado | **sem caminho** | doc do Cursor CLI não cita geração de imagem |

Por isso `imagem.sh` para Gemini **recusa por padrão** (exit 2, explica) e só roda com
`--aceito-aprovacao-automatica`, num diretório temporário vazio — e a skill diz que **não
verificou**. Sem a flag o caminho recomendado é o `/generate` no Gemini interativo.

## 5. O que o Claude pode fazer com mídia

- **Integrar** o asset gerado (caminho, `alt`, dimensões, otimização) — código é com ele.
- **Escrever o prompt** de imagem (briefing visual: sujeito, estilo, formato, restrições).
- **Revisar** o resultado contra o brief e contra marca/legibilidade.
- **Recusar** a gerar. Só isso.
