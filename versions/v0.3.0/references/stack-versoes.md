# Anexo volátil — CLIs de outros modelos (schematize-models)

> Parte da skill **schematize-models**. **Fonte volátil:** tudo aqui tem prazo de validade e é
> atualizado **à parte** do corpo normativo, que não crava número nem flag de terceiro.
>
> **Verificado em: 2026-10-14.** Cadência: antes de cada release da skill e sempre que um CLI mudar
> de versão maior. Marca: **[máquina]** = rodado/lido nesta máquina; **[doc]** = só pela doc
> oficial citada; **[não verificado]** = não consegui confirmar.

## Estado desta máquina (2026-10-14)

| CLI | Presente | Versão | Autenticado |
|---|---|---|---|
| Codex | sim, `~/.npm-global/bin/codex` (pacote npm `@openai/codex`) | `codex-cli 0.162.1` | sim, "Logged in using ChatGPT" (`codex login status`, exit 0) |
| Gemini CLI | **ausente** | - | - |
| Cursor CLI (`cursor-agent`/`agent`) | **ausente**; `/usr/bin/cursor` é o **editor**, não o agent CLI | - | - |

Tudo o que se diz de Gemini e Cursor abaixo é **[doc]**: **nunca foi executado aqui**.

## Codex CLI **[máquina]**

Fonte: `codex --help`, `codex exec --help`, `codex exec review --help`, `codex features list`
(0.162.1) e a doc `learn.chatgpt.com/docs/codex/cli` (redirect de `developers.openai.com/codex/cli`;
repo `github.com/openai/codex`).

Não interativo: `codex exec [OPTIONS] [PROMPT]` (prompt omitido ou `-` = lê do stdin). Flags usadas pela skill:

| Flag | Significado (do `--help`) |
|---|---|
| `-s, --sandbox <MODE>` | `read-only`, `workspace-write`, `danger-full-access` (a skill só usa as duas primeiras) |
| `-C, --cd <DIR>` | diretório de trabalho |
| `-m, --model <MODEL>` | modelo |
| `-o, --output-last-message <FILE>` | grava a última mensagem do agente |
| `--ephemeral` | não persiste arquivos de sessão |
| `--skip-git-repo-check` | roda fora de repo git (a skill só passa em read-only) |
| `--color never`, `--json` | cor; eventos em JSONL |
| `--output-schema <FILE>` | JSON Schema do formato da resposta final |

Vetadas pela skill: `--dangerously-bypass-approvals-and-sandbox`, `-s danger-full-access`,
`--dangerously-bypass-hook-trust`. `codex exec review` existe (`--uncommitted`, `--base <BRANCH>`,
`--commit <SHA>`): revisão nativa do Codex, alternativa a mandar o diff no prompt.

Autenticação: `codex login status` (exit 0 = logado) **[máquina]**; `codex login` para entrar.
Instalação: `npm i -g @openai/codex` (é como está instalado aqui; **[não verificado]** na doc
oficial desta sessão, que não listou o comando).

Imagem **[máquina]**: `codex features list` lista `image_generation` como **stable, true**; o skill
empacotado `~/.codex/skills/.system/imagegen` (lido nesta máquina) diz: modo padrão = ferramenta
built-in `image_gen`, "Does not require `OPENAI_API_KEY`"; arquivos em
`$CODEX_HOME/generated_images/...` (a skill **não** aceita argumento de destino: gera e depois copia);
fallback `scripts/image_gen.py` exige `OPENAI_API_KEY`. **Smoke real em 2026-10-14**: `imagem.sh codex`
gerou um PNG em ~43 s. Nome do modelo de imagem: a doc do skill cita `gpt-image-2` (e
`gpt-image-1.5` só sob pedido); fontes de terceiros divergem sobre o padrão -> **[não verificado]**
qual modelo o built-in usa hoje. A página oficial `.../codex/image-generation` devolveu 404 nesta
sessão.

## Gemini CLI **[doc]**

Fontes: `github.com/google-gemini/gemini-cli` (README), `geminicli.com/docs/cli/headless`,
`geminicli.com/docs/cli/cli-reference` (lidas em 2026-10-14).

| Flag | Descrição (da doc) |
|---|---|
| `-p, --prompt` | "Prompt text. Appended to stdin input if provided. Forces non-interactive mode." |
| `-m, --model` | modelo |
| `--approval-mode` | "default, auto_edit, yolo, plan" |
| `-y, --yolo` | **Deprecated** (use `--approval-mode=yolo`); vetado pela skill |
| `-s, --sandbox` | "Run in a sandboxed environment" (depende de ambiente de sandbox; a skill não usa) |
| `-o, --output-format` | `text`, `json`, `stream-json` |
| `--include-directories` | diretórios extras no workspace |
| `-v, --version` | versão |

Headless: JSON traz `response`, `stats`, `error`; exit codes `0` ok, `1` erro geral/API, `42`
entrada inválida, `53` limite de turnos. **`plan`** é o modo somente-leitura que a skill usa como
read-only; **[não verificado]** na prática (CLI ausente aqui).

Autenticação: login Google (interativo), `GEMINI_API_KEY`, ou Vertex (`GOOGLE_API_KEY` +
`GOOGLE_GENAI_USE_VERTEXAI=true`). **Não há comando de status documentado**: `detectar.sh` só
consegue dizer "provável" (env/arquivo OAuth local, heurística **não documentada**) ou
"desconhecido". Instalação: a doc cita as tags npm `@latest/@preview/@nightly`; o pacote é
`@google/gemini-cli` **[não verificado]** nesta sessão (confirme no README).

Aviso a conferir: um resultado de busca citou que o Gemini CLI seria substituído por um "Antigravity
CLI" em 18 de junho; as páginas oficiais lidas **não** mencionam isso **[não verificado]** — se o
binário mudar de nome, `detectar.sh` precisa aprender o novo.

Imagem **[doc, não verificado em headless]**: sem geração nativa; MCP pode agregar mídia
(Imagen/Veo/Lyria, segundo o README); extensão `gemini-cli-extensions/nanobanana`
(`gemini extensions install https://github.com/gemini-cli-extensions/nanobanana`): comandos
`/generate`, `/edit`, `/restore`, `/icon`, `/pattern`, `/story`, `/diagram`; exige
`NANOBANANA_API_KEY`; modelo padrão `gemini-3.1-flash-image-preview` (opcional `NANOBANANA_MODEL`);
saída em `./nanobanana-output/`. O README **não diz** se roda em `gemini -p`.

Vantagens citadas em `roteamento.md` §3: `ai.google.dev/gemini-api/docs/long-context` (janelas de 1M
tokens ou mais), `ai.google.dev/gemini-api/docs/google-search` (grounding com citações),
`geminicli.com/docs/tools/web-search` (`google_web_search`).

## Cursor CLI **[doc]**

Fontes: `cursor.com/docs/cli/headless`, `cursor.com/docs/cli/reference/parameters` (lidas em
2026-10-14; `docs.cursor.com` redireciona para `cursor.com/docs`). A doc atual chama o comando
**`agent`**; o nome histórico é **`cursor-agent`** — `detectar.sh` aceita os dois (e `agent` só se
`--help` se identificar como Cursor, porque `agent` é nome genérico).

| Flag/comando | Descrição (da doc) |
|---|---|
| `-p, --print` | respostas no console, para script; dá acesso a todas as ferramentas, inclusive escrita e shell |
| `--output-format` | `text` (padrão), `json`, `stream-json` (só com `--print`) |
| `--model` | modelo |
| `-f, --force` / `--yolo` | permite comandos exceto os negados; **escrita em `--print` exige `--force`** |
| `--mode` | `plan` ou `ask` (somente-leitura/Q&A); padrão = agent |
| `--sandbox` | `enabled` ou `disabled` |
| `--workspace` | diretório de trabalho |
| `--api-key` / `CURSOR_API_KEY` | autenticação para scripts (a skill usa env, nunca `--api-key`: argumento aparece em `ps`) |
| `status` (alias `whoami`), `login`, `about` | status de autenticação, login, versão/conta |

Mapeamento da skill: read-only = `--mode ask`; workspace-write = `--sandbox enabled --force`.
Instalação: `curl https://cursor.com/install -fsS | bash` (macOS/Linux/WSL) — **a skill não
executa instalador; mostra o comando e o usuário decide**. **[não verificado]**: o que `status`
imprime quando deslogado (o detector procura "not logged in/authenticated", "login required");
se o prompt por stdin é aceito (por isso a skill passa o prompt como argumento `-p`).
Imagem: **nenhuma documentada**.

## Regra que NÃO é volátil

O **roteamento por peso** (`roteamento.md`), a **regra de mídia** (`midia.md`) e o **piso de
segurança** (`delegacao.md`) valem independentemente de versão. Flag e nome mudam; "Claude no
código, imagem nunca pelo Claude, saída externa não confiável" não.
