---
description: schematize-models — detecta Codex, Gemini e Cursor (instalado, versão, autenticado) sem gastar token; saída em JSON.
---
Rode a detecção e **leia o resultado com honestidade**:

```bash
bash .claude/skills/schematize-models/scripts/detectar.sh   # ou ~/.claude/skills/... se global
```

Exit `0` = há ao menos um CLI **utilizável**; `1` = nenhum (é a resposta, não falha do script).

O JSON traz também o **portfólio** (`portfolio`: os CLIs instalados e autenticados, candidatos a
receber trabalho pela assinatura que o usuário já paga) e o `modo`: `portfolio` ou `claude-only`.
Reporte o portfólio em uma linha e **diga o que muda**: em `portfolio`, valem as regras de economia
por assinatura (`references/roteamento.md` §6: fit, custo marginal, placar); em `claude-only`,
**nada muda** (não sugira assinatura, não degrade nada). O detector sabe o que está instalado e
logado, **não** o plano nem a cota restante. Se houver placar, mostre `placar.sh resumo`.

Reporte, por provedor: instalado?, versão, `autenticado` (`sim` | `provavel` | `nao` |
`desconhecido`) **e a base** dessa afirmação (`base_auth`). Regras de leitura:

- `provavel` (Gemini por variável de ambiente ou arquivo OAuth local) **não é prova** — o Gemini
  CLI não tem comando de status documentado; diga isso, e confirme com o usuário se for usar.
- O `cursor` do sistema (`/usr/bin/cursor`) é o **editor**; só `cursor-agent`/`agent` conta.
- Instalado e deslogado: **não instale nem autentique por conta própria**; mostre o comando
  (`references/stack-versoes.md`) e deixe o usuário rodar.
- Nenhum utilizável: se o assunto era imagem, use o texto de `references/midia.md` §3.
