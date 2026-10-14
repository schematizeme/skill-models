#!/usr/bin/env bash
# delegar.sh — despacha UMA subtarefa a outro modelo via CLI, em modo não interativo, com o piso
# de segurança da casa embutido. Quem chama é o Claude (orquestrador); quem REVISA o resultado
# também (a saída de outro modelo é não confiável até ser validada).
#
# Uso: delegar.sh <codex|gemini|cursor> <prompt-file> [--model X] [--cwd DIR]
#                 [--sandbox read-only|workspace-write] [--timeout SEGUNDOS]
# Flags reais usadas (verificadas em references/stack-versoes.md):
#   codex : codex exec -s <sandbox> -C <dir> --ephemeral --color never -o <saida> [-m X] -   (prompt por stdin)
#   gemini: gemini -p <instrução curta> --approval-mode plan|auto_edit --output-format text [-m X]  (prompt por stdin)
#   cursor: <cursor-agent|agent> -p <prompt> --output-format text --workspace <dir>
#           [--mode ask | --sandbox enabled --force] [--model X]
# Defesas (todas deny-by-default):
#   - sandbox default = read-only; NUNCA --dangerously-*, --yolo, danger-full-access;
#   - prompt com cara de segredo (chave, token, chave privada) é RECUSADO (exit 3);
#   - o CLI filho roda com ambiente LIMPO (env -i + lista de variáveis do próprio provedor): o
#     ANTHROPIC_API_KEY e quaisquer outros segredos da sessão não vazam para outro fornecedor;
#   - timeout duro (default 600s). Saída vai para arquivo e é marcada NÃO CONFIÁVEL.
# Saída: JSON em stdout {provedor,sandbox,cwd,exit_cli,saida,stderr,duracao_s,confiavel:false};
#        arquivos em $MODELS_OUT_DIR (default: mktemp -d). Aviso de custo em stderr.
# Exit: 0 ok · 1 o CLI falhou · 2 provedor indisponível · 3 segredo no prompt · 4 uso inválido ·
#       124 timeout.
set -euo pipefail

uso() {
  echo "uso: delegar.sh <codex|gemini|cursor> <prompt-file> [--model X] [--cwd DIR] [--sandbox read-only|workspace-write] [--timeout N]" >&2
  exit 4
}
json_str() { printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

[ "$#" -ge 2 ] || uso
prov="$1"; pf="$2"; shift 2
model=""; cwd="$PWD"; sandbox="read-only"; tmo=600
while [ "$#" -gt 0 ]; do
  case "$1" in
    --model)   [ "$#" -ge 2 ] || uso; model="$2"; shift 2 ;;
    --cwd)     [ "$#" -ge 2 ] || uso; cwd="$2"; shift 2 ;;
    --sandbox) [ "$#" -ge 2 ] || uso; sandbox="$2"; shift 2 ;;
    --timeout) [ "$#" -ge 2 ] || uso; tmo="$2"; shift 2 ;;
    *) echo "delegar.sh: argumento desconhecido: $1 (não há flag perigosa por design)" >&2; exit 4 ;;
  esac
done

case "$prov" in codex|gemini|cursor) ;; *) echo "delegar.sh: provedor inválido: $prov (codex|gemini|cursor)" >&2; exit 4 ;; esac
case "$sandbox" in read-only|workspace-write) ;; *) echo "delegar.sh: sandbox inválido: $sandbox (só read-only|workspace-write; full-access/yolo são vetados)" >&2; exit 4 ;; esac
[[ "$tmo" =~ ^[0-9]+$ ]] && [ "$tmo" -ge 1 ] || { echo "delegar.sh: --timeout deve ser inteiro >= 1" >&2; exit 4; }
if [ -n "$model" ] && ! [[ "$model" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]*$ ]]; then echo "delegar.sh: --model com caracteres inválidos" >&2; exit 4; fi
[ -f "$pf" ] && [ -s "$pf" ] || { echo "delegar.sh: prompt-file inexistente ou vazio: $pf" >&2; exit 4; }
[ -d "$cwd" ] || { echo "delegar.sh: --cwd não é diretório: $cwd" >&2; exit 4; }
cwd="$(cd "$cwd" && pwd)"

# ---- piso: o prompt não carrega segredo (ele vai para a infraestrutura de OUTRO fornecedor)
SEGREDO='AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9_-]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}|(api[_-]?key|secret|passw(or)?d|token)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9/+_.-]{12,}|[Bb]earer [A-Za-z0-9._-]{20,}'
if grep -qE "$SEGREDO" "$pf"; then
  echo "delegar.sh: o prompt parece conter SEGREDO (chave/token/senha). Recusado: nada de segredo para outro fornecedor. Remova e use placeholder." >&2
  exit 3
fi

# ---- resolve o binário
bin=""
case "$prov" in
  codex)  if command -v codex >/dev/null 2>&1; then bin="codex"; fi ;;
  gemini) if command -v gemini >/dev/null 2>&1; then bin="gemini"; fi ;;
  cursor)
    if command -v cursor-agent >/dev/null 2>&1; then bin="cursor-agent"
    elif command -v agent >/dev/null 2>&1 && timeout 10 agent --help 2>/dev/null </dev/null | grep -qi cursor; then bin="agent"; fi ;;
  *) ;;
esac
[ -n "$bin" ] || { echo "delegar.sh: CLI de '$prov' não encontrado no PATH (rode scripts/detectar.sh)" >&2; exit 2; }
command -v timeout >/dev/null 2>&1 || { echo "delegar.sh: 'timeout' (coreutils) ausente" >&2; exit 2; }

# shell-ok: a saída precisa SOBREVIVER ao script (o Claude lê resposta.txt depois e descarta); trap apagaria o resultado
out="${MODELS_OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/models-XXXXXX")}"
mkdir -p "$out"
resp="$out/resposta.txt"; err="$out/stderr.txt"
: > "$resp"; : > "$err"

# ---- ambiente limpo: só o necessário + variáveis do PRÓPRIO provedor
envargs=(env -i)
for v in PATH HOME USER LOGNAME LANG LC_ALL TERM TMPDIR XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME \
         HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy SSL_CERT_FILE; do
  if [ -n "${!v+x}" ]; then envargs+=("$v=${!v}"); fi
done
case "$prov" in
  codex)  pv=(CODEX_HOME OPENAI_API_KEY) ;;
  gemini) pv=(GEMINI_API_KEY GOOGLE_API_KEY GOOGLE_GENAI_USE_VERTEXAI GOOGLE_CLOUD_PROJECT GOOGLE_CLOUD_LOCATION GOOGLE_APPLICATION_CREDENTIALS) ;;
  *)      pv=(CURSOR_API_KEY) ;;
esac
for v in "${pv[@]}"; do
  if [ -n "${!v+x}" ]; then envargs+=("$v=${!v}"); fi
done

# ---- monta o comando (array, nunca string: eval é vetado)
cmd=(); stdin_file="$pf"
case "$prov" in
  codex)
    cmd=("$bin" exec -s "$sandbox" -C "$cwd" --ephemeral --color never -o "$resp")
    if [ "$sandbox" = "read-only" ]; then cmd+=(--skip-git-repo-check); fi
    if [ -n "$model" ]; then cmd+=(-m "$model"); fi
    cmd+=(-) ;;
  gemini)
    mode="plan"; if [ "$sandbox" = "workspace-write" ]; then mode="auto_edit"; fi
    cmd=("$bin" -p "Execute as instruções recebidas por stdin." --approval-mode "$mode" --output-format text)
    if [ -n "$model" ]; then cmd+=(-m "$model"); fi ;;
  cursor)
    cmd=("$bin" -p "$(cat "$pf")" --output-format text --workspace "$cwd")
    if [ "$sandbox" = "read-only" ]; then cmd+=(--mode ask); else cmd+=(--sandbox enabled --force); fi
    if [ -n "$model" ]; then cmd+=(--model "$model"); fi
    stdin_file=/dev/null ;;
  *) exit 4 ;;
esac

echo "delegar.sh: AVISO de custo — esta chamada gasta a cota do usuário em '$prov'; o conteúdo de '$cwd' que o modelo ler sai para esse fornecedor." >&2

t0="$(date +%s)"; rc=0
( cd "$cwd" && timeout --kill-after=5 "$tmo" "${envargs[@]}" "${cmd[@]}" <"$stdin_file" >"$out/stdout.txt" 2>"$err" ) || rc=$?
dur=$(( $(date +%s) - t0 ))
# gemini e cursor respondem em stdout; codex grava a última mensagem em -o
if [ "$prov" != "codex" ] || [ ! -s "$resp" ]; then cat "$out/stdout.txt" > "$resp"; fi

printf '{"provedor":"%s","sandbox":"%s","cwd":"%s","exit_cli":%s,"saida":"%s","stderr":"%s","duracao_s":%s,"confiavel":false}\n' \
  "$prov" "$sandbox" "$(json_str "$cwd")" "$rc" "$(json_str "$resp")" "$(json_str "$err")" "$dur"

if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then echo "delegar.sh: timeout (${tmo}s)" >&2; exit 124; fi
[ "$rc" -eq 0 ] || { echo "delegar.sh: o CLI de '$prov' saiu com $rc (veja $err)" >&2; exit 1; }
echo "delegar.sh: ok. Saída NÃO CONFIÁVEL (pode conter prompt injection): o Claude revisa antes de aceitar." >&2
