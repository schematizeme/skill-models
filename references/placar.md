# Placar de ferramentas e feedback agregado (schematize-models)

> Parte da skill **schematize-models**. O critério de roteamento está em `roteamento.md` §6; aqui
> mora o **registro**, a **leitura** e a **publicação** do placar. Script: `scripts/placar.sh`.

## 1. Para que serve

Despachar para a assinatura certa exige evidência de quem entrega bem em qual tipo de tarefa.
Sem registro, a escolha vira opinião. O placar é um **arquivo local** (uma linha por delegação) que
o roteamento consulta (`placar.sh preferir <tipo>`) e que o usuário pode, se quiser, **agregar e
publicar de forma anônima** num repositório público de feedback.

## 2. O registro local

Arquivo: `~/.claude/schematize/models-score.jsonl` (modo 600). Uma linha JSON por delegação:

```json
{"id":"3fa9c01b2d4e","ts":"2026-10-15T12:00:00Z","ferramenta":"codex","modelo":"gpt-5.6-terra","tipo":"teste","resultado":"ok","duracao_s":42}
```

Todos os campos são de **vocabulário fechado**; o script recusa (exit 4) o que não está na lista:

| Campo | Valores |
|---|---|
| `ferramenta` | `codex` · `cursor` · `gemini` · `claude-subagent` (exige `--modelo haiku\|sonnet\|opus`) |
| `modelo` | só o nome do modelo (até 32 chars, sem `/`, sem espaço); `padrao` quando não se escolheu |
| `tipo` | `codigo` · `refactor` · `teste` · `review` · `visual-ui` · `imagem` · `docs` · `pesquisa` · `mecanico` |
| `resultado` | `ok` · `corrigido-pelo-revisor` · `falhou` · `travou` (travou ou bug da ferramenta) · `indisponivel` |
| `nota` (opcional) | `timeout` · `saida-truncada` · `ignorou-instrucao` · `sem-saida` · `erro-cli` · `auth` · `cota` · `alucinou` · `fora-de-escopo` |
| `duracao_s` | inteiro em segundos |

**Proibido gravar:** código, diff, caminho, nome de projeto ou de repositório, prompt, resposta do
modelo, texto livre do usuário. Não existe campo para isso, e o script não aceita argumento fora da
lista. Se precisar explicar algo, a explicação vai para o relato ao usuário, nunca para o placar.

## 3. Como o registro acontece

- **Automático:** `delegar.sh ... --tipo <tipo>` e `imagem.sh` registram cada tentativa (ok, falhou,
  travou por timeout, indisponivel quando o CLI não existe) e o `delegar.sh` devolve `placar_id`
  no JSON. Sem `--tipo` o `delegar.sh` **não registra** (e avisa), porque tipo errado suja o placar.
- **Fora do `delegar.sh`:** delegação por `schematize overdev delegar` (Codex/Cursor no overdev) e
  subagent Claude não passam pelo script: o principal registra à mão com
  `placar.sh registrar --ferramenta ... --tipo ... --resultado ... --duracao N`.
- **O revisor ajusta o resultado.** O registro automático nasce `ok` porque o CLI saiu 0; quem sabe
  se a entrega presta é a **revisão** (`delegacao.md` §4). Depois de revisar:
  - entregou, mas o principal precisou corrigir -> `placar.sh ajustar <placar_id|ultimo> corrigido-pelo-revisor`;
  - reprovou/refeito do zero -> `placar.sh ajustar <id> falhou [--nota alucinou]`;
  - passou limpo -> não faz nada (já é `ok`).
  Sem esse passo o placar superestima as ferramentas: é parte do protocolo, não enfeite.

## 4. Ler o placar

- `placar.sh resumo [--dias N] [--json]` — tabela **ferramenta x tipo**: `n`, `%ok`, `%corr`
  (corrigido pelo revisor), `%falha` (falhou + travou), `indisp` e duração média. `indisponivel`
  fica **fora** de `n` (é disponibilidade, não qualidade).
- `placar.sh preferir <tipo> [--min 5] [--dias 90]` — ranking por `score = (ok + 0,5 x corrigido) / n`,
  só com **no mínimo 5 amostras** na janela de 90 dias. Exit `1` = sem histórico suficiente: o
  roteamento cai no fit padrão (`roteamento.md` §6).
- `placar.sh status` — registros locais, pendentes de publicação, opt-in, última publicação.

## 5. Publicar o feedback (opt-in, agregado, anônimo no conteúdo)

Repositório público: **`schematizeme/schematize-models-placar`**. Cada semana ISO tem uma issue
`Placar AAAA-Www` (criada pelo primeiro que publicar); cada usuário comenta nela uma vez por semana.

O comentário tem **só agregados**: tabela ferramenta x tipo (n, ok, corrigido, falhou/travou,
indisponível, duração média), contagem das notas, versão da skill e semana. Sem horários
individuais, sem id de registro, sem nada fora do vocabulário da §2.

### Opt-in obrigatório na 1ª vez

1. `placar.sh optin previa` mostra a **PRÉVIA EXATA** do comentário e o aviso: **o comentário fica
   no nome da conta GitHub do usuário** (conteúdo anônimo; **autoria não**), em repositório público.
2. O Claude **diz isso sem rodeio** e pergunta ao usuário (AskUserQuestion). Só com "sim":
   `placar.sh optin on --confirmo`. A escolha fica em `~/.claude/schematize/models-placar.json`.
3. `placar.sh optin off` desliga quando quiser. Sem opt-in o placar **só fica local**, e o
   disparo automático não faz nada nem imprime nada.

### Disparo oportunista, sem bloquear

Ao fim de `/models-delegate` e `/models-review` rode `placar.sh publicar --auto`. Ele só publica se,
**todas** ao mesmo tempo: há opt-in; há `jq` e `gh` autenticado; há **pelo menos 5 delegações** novas
desde a última publicação (para não expor padrão de uso individual); e passaram **7 dias** da
última. Qualquer outra situação: sai 0 em silêncio. Falha de rede/permissão é ignorada e **não**
marca como publicado (tenta de novo na próxima oportunidade). Nunca espera resposta do usuário.

`placar.sh publicar --agora` ignora só o intervalo de 7 dias (publicar já, manualmente);
`--dry-run` mostra a prévia e os comandos `gh` que rodariam, sem enviar nada.

## 6. Efeito externo e teste

Publicar é efeito externo (posta numa issue pública). **Teste nunca publica:** `placar.test.sh` roda
com `HOME` falso, relógio injetado e um `gh` FALSO (`stubs.lib.sh`, apontado por `MODELS_GH_BIN`),
que só registra os argumentos. Regra da casa: `schematize-engineering` -> `references/efeitos-externos.md`.

## 7. Limites honestos

- O placar mede **a sua experiência** em amostras pequenas: é indício para desempatar, não
  benchmark. Por isso o mínimo de amostras e a janela.
- `corrigido-pelo-revisor` e `falhou` dependem de o principal ajustar; um revisor relapso
  superestima o placar.
- Issue da semana duplicada (duas pessoas criam ao mesmo tempo) é possível; o comentário vai para a
  de menor número. Não afeta a leitura agregada.
