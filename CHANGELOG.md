# Changelog — schematize-models

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [0.1.1] — 2026-10-14
Integração ao catálogo (grafo, skills.json, herdados) e correção do texto de precedência herdado.

### Alterado
- Blocos herdados ressincronizados com a `schematize-engineering` v0.27.0 (`tools/sync-herdados.mjs`): orquestração com a regra de imagem (nunca pelo Claude; detecta Codex/Gemini e pergunta ao usuário qual usar, Codex como sugestão) e `schematize overdev delegar` (comando do app) no lugar do falso nome de skill `schematize-overdev`.
- Bloco "Precedência e herança" passa à variante `dominio`: o texto antigo dizia que os comandos `/models-*` "cobrem só o piso da linguagem", o que é falso para skill de domínio/ferramenta.

## [0.1.0] — 2026-10-14
Primeira versão. Dois defeitos opostos pediam a skill: sem regra, o Claude **gera imagem sozinho** — e o visual que ele produz tem qualidade inversamente proporcional à do código dele, sai ruim de verdade; e, na outra ponta, delegar a outro modelo "porque sim" gasta a cota do usuário, vaza contexto para outro fornecedor e aceita saída sem revisão.

### Adicionado
- **`references/roteamento.md`** — o princípio com pesos: Claude é o melhor em código (código, revisão, refactor, arquitetura e orquestração com peso máximo); outro modelo entra só por (a) mídia, (b) segunda opinião, (c) vantagem **documentada com fonte** (contexto de 1M+ tokens e busca com citação do Gemini; imagem built-in do Codex), (d) pedido do usuário. Tabela tarefa x modelo x peso; regra "Claude orquestra, despacha e REVISA"; aviso de custo e egress.
- **`references/delegacao.md`** — contrato da subtarefa (objetivo, contexto mínimo, critérios de aceite, fora de escopo), sandbox/aprovação por CLI (read-only por padrão), segredo, saída externa **não confiável** (piso da `schematize-ai`), falha.
- **`references/midia.md`** — imagem NUNCA por modelo Claude: detectar -> **perguntar ao usuário** -> gerar -> salvar -> reportar; texto sem rodeio quando nada está disponível; como cada CLI gera imagem hoje, com o que foi **verificado** (Codex: `image_gen` built-in, smoke real) e o que **não** foi (Gemini via extensão `nanobanana` em headless).
- **`references/stack-versoes.md`** — anexo volátil: flags reais lidas em `codex --help`/`codex exec --help` e na doc oficial do Gemini CLI e do Cursor CLI, com fonte, data (2026-10-14) e marca [máquina]/[doc]/[não verificado].
- **`scripts/detectar.sh`** (JSON, sem gastar token), **`scripts/delegar.sh`** (modo não interativo dos três CLIs; read-only default; sem flag perigosa; recusa segredo no prompt; ambiente limpo no filho; timeout) e **`scripts/imagem.sh`** (Codex verificado; Gemini só com aceite explícito; nunca sobrescreve; proveniência sem afirmar licença), cada um com `.test.sh` e CLIs falsos no PATH.
- 10 comandos `/models-*` (detect, delegate, review, image, route, help, load, claude, handoff, cc) e `assets/CLAUDE.md` sempre-on.

### Verificado nesta máquina (2026-10-14)
- `detectar.sh` real: Codex 0.162.1 autenticado; Gemini e Cursor CLI ausentes.
- `delegar.sh codex` real em read-only: respondeu a um prompt trivial (exit 0, saída em arquivo).
- `imagem.sh codex` real: gerou um PNG pela ferramenta built-in em ~43 s.

### Não verificado
- Qualquer execução de Gemini CLI e Cursor CLI (ausentes aqui): flags e mapeamento de read-only vêm só da doc; geração de imagem do Gemini em headless.
