#!/usr/bin/env bash
# Vermelho primeiro do imagem.sh, com CLIs FALSOS no PATH (nunca o modelo real, nunca a cota).
#
# EXCEÇÃO DECLARADA (piso.md §1): harness de teste roda `set -u` sem `-e` — precisa continuar depois
# de um caso vermelho para reportar todos.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=stubs.lib.sh
. "$AQUI/stubs.lib.sh"
I="$AQUI/imagem.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT INT TERM
ok=0; fail=0
B="$T/bin"; mkstubs "$B" codex gemini cursor-agent
mkdir -p "$T/home" "$T/out" "$T/codexhome"

run() { # run <ENV...> -- <args>
  local envs=() ctl=("STUB_LOG=$T/log" "STUB_STDIN=$T/stdin")
  while [ "$1" != "--" ]; do case "$1" in STUB_*) ctl+=("$1") ;; *) envs+=("$1") ;; esac; shift; done; shift
  rm -f "$T/log" "$T/stdin"; rm -rf "$T/codexhome/generated_images"; stubctl "$B" "${ctl[@]}" "CODEX_HOME=$T/codexhome"
  OUT="$(env -i PATH="$B:/usr/bin:/bin" HOME="$T/home" CODEX_HOME="$T/codexhome" "${envs[@]}" bash "$I" "$@" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"; LOG="$(cat "$T/log" 2>/dev/null || true)"
}
esperar() {
  local nome="$1" esp="$2"; shift 2
  if [ "$RC" != "$esp" ]; then echo "  ✖ $nome: exit $RC, esperado $esp"; echo "      err: $ERR"; fail=$((fail+1)); return; fi
  local a
  for a in "$@"; do
    case "$a" in
      '!'*) if grep -qF -- "${a#!}" <<<"$OUT$ERR$LOG"; then echo "  ✖ $nome: NÃO devia conter \"${a#!}\""; fail=$((fail+1)); return; fi ;;
      *)    if ! grep -qF -- "$a" <<<"$OUT$ERR$LOG"; then echo "  ✖ $nome: faltou \"$a\""; fail=$((fail+1)); return; fi ;;
    esac
  done
  echo "  ✔ $nome"; ok=$((ok+1))
}

echo "== uso inválido (vermelhos) =="
run -- codex;                                              esperar sem-argumentos 4 "uso:"
run -- openai "um gato" "$T/out/a.png";                    esperar provedor-invalido 4 "provedor inválido"
: > "$T/out/existe.png"; run -- codex "um gato" "$T/out/existe.png"; esperar nao-sobrescreve 4 "não sobrescrevo"
run -- codex "um gato" "$T/nao-existe/a.png";              esperar dir-saida-inexistente 4 "não existe"
run -- codex "chave AKIAABCDEFGHIJKLMNOP" "$T/out/s.png";  esperar segredo-no-prompt 3 "segredo" "!codex exec"
run -- codex "gato" "$T/out/t.png" --timeout 0;            esperar timeout-invalido 4 "inválido"

echo "== sem escolha automática de provedor / caminhos não suportados =="
run -- cursor "um gato" "$T/out/c.png";                    esperar cursor-sem-imagem 2 "não tem geração de imagem"
run -- gemini "um gato" "$T/out/g.png";                    esperar gemini-sem-flag-nao-roda 2 "NÃO VERIFICADO"
if [ -z "$LOG" ]; then echo "  ✔ gemini-sem-flag-nem-invoca-o-cli"; ok=$((ok+1)); else echo "  ✖ gemini invocado sem a flag: $LOG"; fail=$((fail+1)); fi
if [ ! -e "$T/out/g.png" ]; then echo "  ✔ gemini-sem-flag-nao-gera-arquivo"; ok=$((ok+1)); else echo "  ✖ gemini gerou arquivo sem a flag"; fail=$((fail+1)); fi
run -- gemini "um gato" "$T/out/g2.png" --aceito-aprovacao-automatica; esperar gemini-sem-chave 2 "NANOBANANA_API_KEY"
mkdir -p "$T/vazio"; B_SAVE="$B"; B="$T/vazio"; run -- codex "um gato" "$T/out/n.png"; esperar codex-ausente 2 "não encontrado"; B="$B_SAVE"

echo "== vermelho: o modelo roda mas NÃO gera imagem =="
run -- codex "um gato" "$T/out/vazio.png";                 esperar sem-imagem-nao-declara-sucesso 1 "NÃO produziu imagem"
if [ ! -e "$T/out/vazio.png" ]; then echo "  ✔ sem-imagem-nao-cria-saida"; ok=$((ok+1)); else echo "  ✖ criou saída sem imagem"; fail=$((fail+1)); fi
run STUB_RC=5 -- codex "um gato" "$T/out/falha.png";       esperar codex-falha 1 "codex saiu com 5"
run STUB_SLEEP=5 -- codex "um gato" "$T/out/to.png" --timeout 1; esperar codex-timeout 124 "timeout"

echo "== verde: codex gera, copia e registra proveniência =="
run STUB_IMG=1 -- codex "um gato astronauta" "$T/out/gato.png"
esperar codex-gera 0 'exec -s read-only' '--ephemeral' '"licenca":"nao verificada' '!dangerously' 'AVISO de custo'
if [ -s "$T/out/gato.png" ]; then echo "  ✔ arquivo-copiado"; ok=$((ok+1)); else echo "  ✖ arquivo de saída ausente"; fail=$((fail+1)); fi
if jq -e '.provedor=="codex" and (.licenca|startswith("NAO VERIFICADA"))' "$T/out/gato.png.origem.json" >/dev/null 2>&1; then echo "  ✔ origem-json-honesta-sobre-licenca"; ok=$((ok+1)); else echo "  ✖ origem.json inválido"; fail=$((fail+1)); fi
if grep -q 'image_gen' "$T/stdin" 2>/dev/null && grep -q 'um gato astronauta' "$T/stdin"; then echo "  ✔ prompt-pede-image_gen"; ok=$((ok+1)); else echo "  ✖ prompt enviado ao codex sem image_gen"; fail=$((fail+1)); fi

echo; echo "imagem.test.sh: $ok ok, $fail falhas"
[ "$fail" -eq 0 ]
