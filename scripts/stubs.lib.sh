# shellcheck shell=bash
# stubs.lib.sh — biblioteca dos testes (sourceada, não executável): cria CLIs FALSOS de codex,
# gemini e cursor-agent. Os testes NUNCA chamam o modelo real: o PATH dos casos contém só os stubs
# e /usr/bin:/bin, então o codex verdadeiro (~/.npm-global/bin) fica invisível.
# strict-ok: biblioteca sourceada — `set -e` mudaria as opções do shell do chamador (piso.md §1).

# mkstubs <dir-bin> <lista: codex gemini cursor-agent agent-outro>
mkstubs() {
  local bin="$1"; shift
  mkdir -p "$bin"
  local n
  for n in "$@"; do
    case "$n" in
      codex) cat > "$bin/codex" <<'STUB'
#!/usr/bin/env bash
# shellcheck disable=SC1091
. "$(dirname "$0")/ctl.env" 2>/dev/null
echo "codex $*" >> "${STUB_LOG:-/dev/null}"
case "${1:-}" in
  --version) echo "codex-cli 9.9.9"; exit 0 ;;
  login) if [ "${STUB_CODEX_AUTH:-1}" = 1 ]; then echo "Logged in using ChatGPT"; exit 0; else echo "Not logged in"; exit 1; fi ;;
  exec)
    shift; out=""
    while [ "$#" -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
    cat > "${STUB_STDIN:-/dev/null}"
    if [ -n "${STUB_ENVFILE:-}" ]; then env > "$STUB_ENVFILE"; fi
    if [ -n "${STUB_SLEEP:-}" ]; then sleep "$STUB_SLEEP"; fi
    if [ -n "$out" ]; then echo "resposta falsa do codex" > "$out"; fi
    if [ -n "${STUB_IMG:-}" ]; then mkdir -p "${CODEX_HOME:?}/generated_images/t1"; printf '\x89PNG fake' > "$CODEX_HOME/generated_images/t1/exec-fake.png"; fi
    exit "${STUB_RC:-0}" ;;
esac
exit 0
STUB
      ;;
      gemini) cat > "$bin/gemini" <<'STUB'
#!/usr/bin/env bash
# shellcheck disable=SC1091
. "$(dirname "$0")/ctl.env" 2>/dev/null
echo "gemini $*" >> "${STUB_LOG:-/dev/null}"
[ "${1:-}" = "--version" ] && { echo "0.99.0"; exit 0; }
cat > "${STUB_STDIN:-/dev/null}"
if [ -n "${STUB_ENVFILE:-}" ]; then env > "$STUB_ENVFILE"; fi
if [ -n "${STUB_SLEEP:-}" ]; then sleep "$STUB_SLEEP"; fi
echo "resposta falsa do gemini"
exit "${STUB_RC:-0}"
STUB
      ;;
      cursor-agent) cat > "$bin/cursor-agent" <<'STUB'
#!/usr/bin/env bash
# shellcheck disable=SC1091
. "$(dirname "$0")/ctl.env" 2>/dev/null
echo "cursor-agent $*" >> "${STUB_LOG:-/dev/null}"
case "${1:-}" in
  --version) echo "2099.01.01-stub"; exit 0 ;;
  status) if [ "${STUB_CURSOR_AUTH:-1}" = 1 ]; then echo "Logged in as fake@example.com"; exit 0; else echo "Not logged in"; exit 1; fi ;;
esac
if [ -n "${STUB_ENVFILE:-}" ]; then env > "$STUB_ENVFILE"; fi
if [ -n "${STUB_SLEEP:-}" ]; then sleep "$STUB_SLEEP"; fi
echo "resposta falsa do cursor"
exit "${STUB_RC:-0}"
STUB
      ;;
      agent-outro) cat > "$bin/agent" <<'STUB'
#!/usr/bin/env bash
# `agent` genérico que NÃO é o Cursor: o detector tem de ignorá-lo
echo "usage: agent [options] (ferramenta qualquer)"
exit 0
STUB
      ;;
      *) echo "mkstubs: stub desconhecido: $n" >&2; return 1 ;;
    esac
  done
  chmod +x "$bin"/* 2>/dev/null || true
}

# stubctl <dir-bin> [VAR=valor ...] — grava o arquivo de controle que os stubs leem (o CLI sob teste
# roda com ambiente limpo, então variáveis STUB_* não chegam por env).
stubctl() {
  local bin="$1"; shift
  : > "$bin/ctl.env"
  local kv
  for kv in "$@"; do printf 'export %s=%q\n' "${kv%%=*}" "${kv#*=}" >> "$bin/ctl.env"; done
}
