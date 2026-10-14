---
description: Mapa da skill schematize-models (orquestrar Codex/Gemini/Cursor como subagents; Claude no código; imagem sempre fora do Claude).
---
**schematize-models** — orquestrar subagents em outros modelos, com o piso da casa.

| Comando | O que faz |
|---|---|
| `/models-help` | esta lista |
| `/models-load` | carrega à força TODO o corpo normativo (roteamento, delegação, mídia, versões) e passa a aplicá-lo |
| `/models-detect` | quais CLIs (Codex, Gemini, Cursor) existem, versão e autenticação — JSON, sem gastar token |
| `/models-route` | explica qual modelo usar para uma tarefa e por quê (tabela de pesos) |
| `/models-delegate` | despacha uma subtarefa a outro modelo com contrato; o Claude revisa antes de aceitar |
| `/models-review` | segunda opinião cruzada de um diff por outro modelo; o Claude consolida |
| `/models-image` | gera imagem FORA do Claude: detecta, pergunta qual usar, gera, salva, reporta |
| `/models-claude` | cria ou mescla o `CLAUDE.md` sempre-on na raiz do repo |
| `/models-cc` · `/models-handoff` | context compact / handoff no archive |

Os pisos em uma linha: **Claude fica com código, revisão, refactor, arquitetura e orquestração**;
**imagem nunca pelo Claude** (sempre perguntar Codex ou Gemini); **sandbox read-only por padrão**,
sem `--yolo`/`--dangerously-*`; **sem segredo no prompt**; **saída externa é não confiável até o
Claude validar**; cada chamada **gasta a cota do usuário** e o conteúdo lido **sai para outro
fornecedor**.

Pareia com: `schematize-engineering` (orquestração §9, efeito externo), `schematize-ai` (saída não
confiável), `schematize-shell` (os scripts), `schematize-web` (integrar o asset gerado).
