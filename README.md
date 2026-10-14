# schematize-models

> **Claude orquestra; outros modelos são subagents de exceção.** Esta skill despacha trabalho ao
> OpenAI Codex CLI, ao Google Gemini CLI e ao Cursor CLI **sem perder o piso**: o Claude fica com
> código, revisão e arquitetura (peso máximo); **imagem nunca sai do Claude**; a saída externa é
> **não confiável** até ele validar; escrita é **deny-by-default**.

Pacote de **skill normativa para [Claude Code](https://claude.com/claude-code)**.
Parte do catálogo **schematize skills**.

## Por que ela existe

Sem regra, o Claude gera imagem sozinho — e o visual dele tem qualidade inversamente proporcional à
do código: sai ruim de verdade. E delegar a outro modelo "porque sim" gasta a cota do usuário, vaza
contexto para outro fornecedor e aceita saída sem revisão. Esta skill fecha os dois buracos.

## Instalar

### Pelo app schematize (recomendado)

```bash
schematize install models    # requer o CLI schematize instalado
```

### Manual

```bash
git clone https://github.com/schematizeme/skill-models.git /tmp/skill-models
bash /tmp/skill-models/install.sh .        # instala em .claude/ do projeto atual
bash /tmp/skill-models/install.sh "$HOME"  # ou global (~/.claude)
```

Os CLIs externos **não** vêm junto: instale e autentique só os que quiser (ver
`references/stack-versoes.md`). Sem nenhum, `/models-image` explica as alternativas.

## O que tem dentro

- **SKILL.md** — o contrato: 9 pisos inegociáveis, fronteiras e o mapa de references.
- **references/** — `roteamento` (pesos e vantagens com fonte), `delegacao` (contrato, sandbox,
  segredo, saída não confiável), `midia` (a regra e como cada CLI gera imagem), `stack-versoes`
  (anexo volátil com data e o que foi verificado).
- **scripts/** — `detectar.sh`, `delegar.sh`, `imagem.sh`, cada um com `.test.sh` (CLIs falsos no
  PATH, casos vermelhos plantados, nunca o modelo real).
- **assets/commands/** — `/models-help`, `-load`, `-detect`, `-route`, `-delegate`, `-review`,
  `-image`, `-claude`, `-cc`, `-handoff`. **assets/CLAUDE.md** — regra sempre-on.

## Comandos

| Comando | O que faz |
|---|---|
| `/models-detect` | quais CLIs existem, versão e autenticação (JSON, sem gastar token) |
| `/models-route` | qual modelo usar para uma tarefa e por quê |
| `/models-delegate` | despacha uma subtarefa com contrato; o Claude revisa |
| `/models-review` | segunda opinião cruzada de um diff; o Claude consolida |
| `/models-image` | imagem fora do Claude: detecta, **pergunta qual usar**, gera, salva, reporta |
| `/models-help` · `/models-load` · `/models-claude` · `/models-cc` · `/models-handoff` | utilitários da casa |

## Versão

**v0.1.0** — changelog em `CHANGELOG.md`. Fatos voláteis (flags, versões) em
`references/stack-versoes.md`, com data de verificação.

## Regra de ouro

**Código é do Claude; imagem nunca é; e o que vem de fora só entra depois de revisado.**

MIT.
