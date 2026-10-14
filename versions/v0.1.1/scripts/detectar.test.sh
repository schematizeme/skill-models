#!/usr/bin/env bash
# Vermelho primeiro do detectar.sh, com CLIs FALSOS no PATH (nunca o modelo real).
#
# EXCEÇÃO DECLARADA (piso.md §1): harness de teste roda `set -u` sem `-e` — precisa continuar depois
# de um caso vermelho para reportar todos.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=stubs.lib.sh
. "$AQUI/stubs.lib.sh"
D="$AQUI/detectar.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT INT TERM
ok=0; fail=0

# caso <nome> <exit-esperado> <jq-expressao-que-deve-dar-true|-> <stubs...>  (env extra via CE=)
caso() {
  local nome="$1" esp="$2" expr="$3"; shift 3
  local b="$T/$nome/bin"; mkdir -p "$T/$nome/home"
  mkstubs "$b" "$@"
  local out rc ctl=() kv
  for kv in ${CE:-}; do case "$kv" in STUB_*) ctl+=("$kv") ;; *) ;; esac; done
  stubctl "$b" "${ctl[@]+"${ctl[@]}"}"
  # shellcheck disable=SC2086 # CE é lista de VAR=valor simples, sem espaços
  out="$(env -i PATH="$b:/usr/bin:/bin" HOME="$T/$nome/home" ${CE:-} bash "$D" 2>"$T/$nome/err")"; rc=$?
  if [ "$rc" != "$esp" ]; then echo "  ✖ $nome: exit $rc, esperado $esp"; fail=$((fail+1)); return; fi
  if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then echo "  ✖ $nome: saída não é JSON válido: $out"; fail=$((fail+1)); return; fi
  if [ "$expr" != "-" ] && ! printf '%s' "$out" | jq -e "$expr" >/dev/null 2>&1; then
    echo "  ✖ $nome: asserção jq falhou: $expr"; printf '%s\n' "$out" | jq -c . | sed 's/^/      /'; fail=$((fail+1)); return; fi
  echo "  ✔ $nome"; ok=$((ok+1))
}

echo "== vermelho: nada instalado =="
CE="" caso nada 1 '(.utilizaveis|length)==0 and (.provedores|length)==3 and all(.provedores[]; .utilizavel==false)'
echo "== codex =="
CE="" caso codex-logado 0 '.utilizaveis==["codex"] and (.provedores[]|select(.nome=="codex")|.autenticado=="sim" and .versao=="codex-cli 9.9.9")' codex
CE="STUB_CODEX_AUTH=0" caso codex-deslogado 1 '(.provedores[]|select(.nome=="codex")|.autenticado=="nao" and .utilizavel==false)' codex
echo "== gemini (sem comando de status: honestidade) =="
CE="" caso gemini-sem-credencial 1 '(.provedores[]|select(.nome=="gemini")|.autenticado=="desconhecido" and .utilizavel==false)' gemini
CE="GEMINI_API_KEY=x" caso gemini-com-env 0 '(.provedores[]|select(.nome=="gemini")|.autenticado=="provavel" and .utilizavel==true)' gemini
echo "== cursor =="
CE="" caso cursor-logado 0 '(.provedores[]|select(.nome=="cursor")|.binario=="cursor-agent" and .autenticado=="sim")' cursor-agent
CE="STUB_CURSOR_AUTH=0" caso cursor-deslogado 1 '(.provedores[]|select(.nome=="cursor")|.autenticado=="nao")' cursor-agent
CE="" caso agent-generico-ignorado 1 '(.provedores[]|select(.nome=="cursor")|.caminho=="")' agent-outro
echo "== tudo junto =="
CE="" caso todos 0 '(.utilizaveis|sort)==["codex","cursor"]' codex gemini cursor-agent

echo "== o editor /usr/bin/cursor nunca conta como agent CLI =="
if [ -e /usr/bin/cursor ]; then
  CE="" caso editor-nao-conta 1 '(.provedores[]|select(.nome=="cursor")|.caminho=="")'
else echo "  - (sem /usr/bin/cursor nesta máquina; caso coberto por 'nada')"; fi

echo; echo "detectar.test.sh: $ok ok, $fail falhas"
[ "$fail" -eq 0 ]
