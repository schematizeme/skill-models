#!/usr/bin/env bash
# Vermelho primeiro do delegar.sh, com CLIs FALSOS no PATH (nunca o modelo real).
#
# EXCEÇÃO DECLARADA (piso.md §1): harness de teste roda `set -u` sem `-e` — precisa continuar depois
# de um caso vermelho para reportar todos.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=stubs.lib.sh
. "$AQUI/stubs.lib.sh"
D="$AQUI/delegar.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT INT TERM
ok=0; fail=0
B="$T/bin"; mkstubs "$B" codex gemini cursor-agent
mkdir -p "$T/home" "$T/proj"
printf 'Resuma o arquivo README em 3 linhas.\n' > "$T/prompt.txt"

# run <ENV...> -- <args do delegar>; define RC, OUT (stdout), ERR (stderr)
run() {
  local envs=() ctl=("STUB_LOG=$T/log")
  while [ "$1" != "--" ]; do case "$1" in STUB_*) ctl+=("$1") ;; *) envs+=("$1") ;; esac; shift; done; shift
  rm -f "$T/log"; stubctl "$B" "${ctl[@]}"
  OUT="$(env -i PATH="$B:/usr/bin:/bin" HOME="$T/home" MODELS_OUT_DIR="$T/out" "${envs[@]}" bash "$D" "$@" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"; LOG="$(cat "$T/log" 2>/dev/null || true)"
}
# esperar <nome> <exit> [agulha-na-saída|stderr|log ...]
esperar() {
  local nome="$1" esp="$2"; shift 2
  if [ "$RC" != "$esp" ]; then echo "  ✖ $nome: exit $RC, esperado $esp"; echo "      err: $ERR"; fail=$((fail+1)); return; fi
  local a
  for a in "$@"; do
    case "$a" in
      '!'*) if grep -qF -- "${a#!}" <<<"$OUT$ERR$LOG"; then echo "  ✖ $nome: NÃO devia conter \"${a#!}\""; fail=$((fail+1)); return; fi ;;
      *)    if ! grep -qF -- "$a" <<<"$OUT$ERR$LOG"; then echo "  ✖ $nome: faltou \"$a\""; echo "      log: $LOG"; fail=$((fail+1)); return; fi ;;
    esac
  done
  echo "  ✔ $nome"; ok=$((ok+1))
}

echo "== uso inválido (vermelhos) =="
run -- codex "$T/prompt.txt" --sandbox danger-full-access;           esperar sandbox-full-access-vetado 4 "vetados"
run -- codex "$T/prompt.txt" --yolo;                                  esperar flag-yolo-inexistente 4 "não há flag perigosa"
run -- codex "$T/prompt.txt" --dangerously-bypass-approvals-and-sandbox; esperar flag-dangerously-inexistente 4 "não há flag perigosa"
run -- openai "$T/prompt.txt";                                        esperar provedor-invalido 4 "provedor inválido"
run -- codex "$T/nao-existe.txt";                                     esperar prompt-inexistente 4 "inexistente ou vazio"
: > "$T/vazio.txt"; run -- codex "$T/vazio.txt";                      esperar prompt-vazio 4 "inexistente ou vazio"
run -- codex "$T/prompt.txt" --timeout abc;                           esperar timeout-invalido 4 "inteiro"
run -- codex "$T/prompt.txt" --model '-x;rm';                         esperar model-injecao 4 "caracteres inválidos"
run -- codex "$T/prompt.txt" --cwd "$T/nao-existe";                   esperar cwd-inexistente 4 "não é diretório"

echo "== segredo no prompt é recusado (exit 3) =="
printf 'use esta chave AKIAABCDEFGHIJKLMNOP para ler o bucket\n' > "$T/s1.txt";             run -- codex "$T/s1.txt";  esperar segredo-aws 3 "SEGREDO" "!codex exec"
printf -- '-----BEGIN RSA PRIVATE KEY-----\nabc\n' > "$T/s2.txt";                              run -- codex "$T/s2.txt";  esperar segredo-chave-privada 3 "SEGREDO"
printf 'api_key = "abcdef0123456789abcd"\n' > "$T/s3.txt";                                     run -- gemini "$T/s3.txt"; esperar segredo-atribuicao 3 "SEGREDO"
printf 'Authorization: Bearer abcdefghijklmnopqrstuvwx\n' > "$T/s4.txt";                       run -- cursor "$T/s4.txt"; esperar segredo-bearer 3 "SEGREDO"

echo "== provedor ausente =="
mkdir -p "$T/vazio-bin"; B_SAVE="$B"; B="$T/vazio-bin"
run -- codex "$T/prompt.txt"; esperar codex-ausente 2 "não encontrado"
B="$B_SAVE"

echo "== verde: codex =="
run ANTHROPIC_API_KEY=sk-ant-NAO-VAZAR-123456789012345 STUB_ENVFILE="$T/env1" -- codex "$T/prompt.txt" --cwd "$T/proj"
esperar codex-readonly-default 0 'exec -s read-only' '--ephemeral' '--skip-git-repo-check' '"confiavel":false' '"sandbox":"read-only"' '!dangerously' '!danger-full-access' 'AVISO de custo'
if grep -q 'ANTHROPIC_API_KEY' "$T/env1" 2>/dev/null; then echo "  ✖ vazamento: ANTHROPIC_API_KEY chegou ao CLI externo"; fail=$((fail+1)); else echo "  ✔ ambiente-limpo-sem-segredo-da-sessao"; ok=$((ok+1)); fi
run -- codex "$T/prompt.txt" --sandbox workspace-write --model gpt-5.5 --cwd "$T/proj"
esperar codex-workspace-write 0 'exec -s workspace-write' '-m gpt-5.5' '!--skip-git-repo-check'
if [ -s "$T/out/resposta.txt" ]; then echo "  ✔ saida-em-arquivo"; ok=$((ok+1)); else echo "  ✖ saida-em-arquivo: resposta.txt vazio"; fail=$((fail+1)); fi

echo "== verde: gemini e cursor =="
run -- gemini "$T/prompt.txt" --cwd "$T/proj"
esperar gemini-plan-default 0 '--approval-mode plan' '--output-format text' '!yolo' '!--sandbox'
run -- gemini "$T/prompt.txt" --sandbox workspace-write
esperar gemini-auto-edit 0 '--approval-mode auto_edit' '!yolo'
run -- cursor "$T/prompt.txt" --cwd "$T/proj"
esperar cursor-ask-default 0 '--mode ask' '--workspace' '!--force' '!--yolo'
run -- cursor "$T/prompt.txt" --sandbox workspace-write
esperar cursor-write-sandboxed 0 '--sandbox enabled' '--force' '!--yolo'

echo "== falha e timeout =="
run STUB_RC=3 -- codex "$T/prompt.txt";                  esperar cli-falhou 1 '"exit_cli":3'
run STUB_SLEEP=5 -- gemini "$T/prompt.txt" --timeout 1;  esperar timeout-duro 124 'timeout'

echo "== placar: registro automático (vocabulário fechado, sem conteúdo) =="
PL="$T/home/.claude/schematize/models-score.jsonl"; rm -f "$PL"
run -- codex "$T/prompt.txt" --tipo teste;                 esperar tipo-ok 0 '"placar_id":"' 'placar.sh ajustar'
run STUB_RC=3 -- gemini "$T/prompt.txt" --tipo review;     esperar tipo-falha 1 '"placar_id":"'
run STUB_SLEEP=5 -- cursor "$T/prompt.txt" --tipo docs --timeout 1; esperar tipo-timeout 124
run -- codex "$T/prompt.txt";                              esperar sem-tipo-nao-registra 0 '"placar_id":""' 'sem --tipo'
run -- codex "$T/prompt.txt" --tipo segredo;               esperar tipo-invalido 4 "--tipo inválido"
mkdir -p "$T/vazio-bin2"; B_SAVE="$B"; B="$T/vazio-bin2"; run -- codex "$T/prompt.txt" --tipo mecanico; esperar tipo-indisponivel 2 "não encontrado"; B="$B_SAVE"
if jq -es 'length==4 and (map(.resultado)==["ok","falhou","travou","indisponivel"]) and (map(.nota)==[null,"erro-cli","timeout",null])' "$PL" >/dev/null 2>&1; then echo "  ✔ placar-4-linhas-ok-falhou-travou-indisponivel"; ok=$((ok+1)); else echo "  ✖ placar inesperado: $(cat "$PL" 2>/dev/null)"; fail=$((fail+1)); fi
if grep -qE "$T|README|Resuma|/home|/tmp" "$PL" 2>/dev/null; then echo "  ✖ placar vazou caminho/prompt"; fail=$((fail+1)); else echo "  ✔ placar-sem-caminho-nem-prompt"; ok=$((ok+1)); fi

echo; echo "delegar.test.sh: $ok ok, $fail falhas"
[ "$fail" -eq 0 ]
