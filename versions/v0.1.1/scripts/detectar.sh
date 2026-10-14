#!/usr/bin/env bash
# detectar.sh — descobre quais CLIs de OUTROS modelos (codex, gemini, cursor-agent) existem nesta
# máquina, a versão, e se estão autenticados — SEM gastar token (nunca chama o modelo).
#
# Motivo: o Claude só pode rotear para um modelo externo que existe e está logado; descobrir isso
# por tentativa-e-erro gasta cota do usuário e polui a sessão. Este script responde antes.
# Como funciona: para cada provedor procura o binário no PATH, pede `--version` (timeout curto) e
# checa a autenticação pelo meio MAIS BARATO documentado:
#   codex  -> `codex login status` (exit 0 = logado)                          [verificado nesta máquina]
#   cursor -> env CURSOR_API_KEY, senão `<bin> status` (doc oficial do Cursor CLI)  [só pela doc]
#   gemini -> NÃO há comando de status documentado: env GEMINI_API_KEY/GOOGLE_API_KEY ou o arquivo
#             local de OAuth do Gemini CLI contam como "provavel"; sem nada = "desconhecido"
# Valores de `autenticado`: sim | provavel | nao | desconhecido. `utilizavel` = sim ou provavel.
# Entrada: nenhuma. Saída: JSON em stdout ({"provedores":[...],"utilizaveis":[...]}).
# Exit: 0 = há ao menos um utilizável · 1 = nenhum utilizável (não é erro: é a resposta).
#       2 = faltou ferramenta básica (timeout).
set -euo pipefail

command -v timeout >/dev/null 2>&1 || { echo "detectar.sh: 'timeout' (coreutils) ausente" >&2; exit 2; }

json_str() { printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# primeira linha da saída do comando, com timeout curto; vazio se falhar
cmd_1linha() { timeout 10 "$@" 2>/dev/null </dev/null | head -n 1 || true; }

emite() { # nome binario caminho versao auth base obs
  local util="false"
  case "$5" in sim|provavel) util="true" ;; *) ;; esac
  printf '{"nome":"%s","binario":"%s","caminho":"%s","versao":"%s","autenticado":"%s","base_auth":"%s","utilizavel":%s,"obs":"%s"}' \
    "$(json_str "$1")" "$(json_str "$2")" "$(json_str "$3")" "$(json_str "$4")" \
    "$(json_str "$5")" "$(json_str "$6")" "$util" "$(json_str "$7")"
}

itens=(); utilizaveis=()
registra() { itens+=("$1"); if [[ "$1" == *'"utilizavel":true'* ]]; then utilizaveis+=("\"$2\""); fi; }

# ---- codex
if p="$(command -v codex 2>/dev/null)"; then
  v="$(cmd_1linha codex --version)"
  if timeout 10 codex login status >/dev/null 2>&1 </dev/null; then a="sim"; b="codex login status (exit 0)"
  else a="nao"; b="codex login status falhou: rode 'codex login'"; fi
  registra "$(emite codex codex "$p" "$v" "$a" "$b" "geração de imagem: ferramenta built-in image_gen (ver references/midia.md)")" codex
else
  registra "$(emite codex codex "" "" nao "binário ausente" "instalar: npm i -g @openai/codex (ver references/stack-versoes.md)")" codex
fi

# ---- gemini
if p="$(command -v gemini 2>/dev/null)"; then
  v="$(cmd_1linha gemini --version)"
  if [ -n "${GEMINI_API_KEY:-}" ]; then a="provavel"; b="env GEMINI_API_KEY presente (validade não checada)"
  elif [ -n "${GOOGLE_API_KEY:-}" ]; then a="provavel"; b="env GOOGLE_API_KEY presente (validade não checada)"
  elif [ -s "${HOME:-/nonexistent}/.gemini/oauth_creds.json" ]; then a="provavel"; b="credencial OAuth local presente (heurística; não documentada)"
  else a="desconhecido"; b="sem comando de status documentado e sem credencial detectável: pergunte ao usuário"; fi
  registra "$(emite gemini gemini "$p" "$v" "$a" "$b" "imagem só via extensão nanobanana (ver references/midia.md)")" gemini
else
  registra "$(emite gemini gemini "" "" nao "binário ausente" "instalar: npm i -g @google/gemini-cli (ver references/stack-versoes.md)")" gemini
fi

# ---- cursor: o binário é `cursor-agent` (legado) ou `agent` (nome atual na doc). `/usr/bin/cursor`
# é o EDITOR e nunca conta. `agent` é nome genérico: só vale se se identificar como Cursor.
bin=""
if command -v cursor-agent >/dev/null 2>&1; then bin="cursor-agent"
elif command -v agent >/dev/null 2>&1 && timeout 10 agent --help 2>/dev/null </dev/null | grep -qi 'cursor'; then bin="agent"
fi
if [ -n "$bin" ]; then
  p="$(command -v "$bin")"; v="$(cmd_1linha "$bin" --version)"
  if [ -n "${CURSOR_API_KEY:-}" ]; then a="provavel"; b="env CURSOR_API_KEY presente (validade não checada)"
  else
    st="$(timeout 15 "$bin" status 2>&1 </dev/null || true)"
    if [ -n "$st" ] && ! printf '%s' "$st" | grep -qiE 'not (logged|authenticated)|login required|unauthenticated|please log ?in'; then
      a="sim"; b="'$bin status' sem aviso de deslogado"
    else a="nao"; b="'$bin status' indica deslogado: rode '$bin login'"; fi
  fi
  registra "$(emite cursor "$bin" "$p" "$v" "$a" "$b" "sem geração de imagem documentada")" cursor
else
  registra "$(emite cursor cursor-agent "" "" nao "binário ausente (o 'cursor' do sistema é o editor, não o agent CLI)" "instalar: curl https://cursor.com/install -fsS | bash (ver references/stack-versoes.md)")" cursor
fi

sep=""; out='{"provedores":['
for it in "${itens[@]}"; do out+="$sep$it"; sep=","; done
sep=""; out+='],"utilizaveis":['
for u in "${utilizaveis[@]+"${utilizaveis[@]}"}"; do out+="$sep$u"; sep=","; done
out+=']}'
printf '%s\n' "$out"

[ "${#utilizaveis[@]}" -gt 0 ]
