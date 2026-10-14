#!/usr/bin/env bash
# imagem.sh — gera UMA imagem por modelo EXTERNO e salva em arquivo. Imagem NUNCA sai de modelo
# Claude (piso da casa). Quem escolhe o provedor é o USUÁRIO (o comando /models-image pergunta);
# este script nunca escolhe sozinho: o provedor é argumento obrigatório.
#
# Uso: imagem.sh <codex|gemini|cursor> "<prompt>" <arquivo-de-saida> [--timeout N] [--aceito-aprovacao-automatica]
# Caminhos:
#   codex  — VERIFICADO (doc local do skill `imagegen` do Codex 0.162.1 + 211 PNGs na máquina): a
#            ferramenta built-in `image_gen` gera sem OPENAI_API_KEY (usa o login ChatGPT) e salva em
#            $CODEX_HOME/generated_images/<thread>/*.png. Este script roda `codex exec` em sandbox
#            read-only num dir vazio, pega o arquivo NOVO e copia para <saida>.
#   gemini — NÃO VERIFICADO headless: só a extensão `nanobanana` (gemini-cli-extensions) gera imagem
#            e ela precisa de NANOBANANA_API_KEY; a doc não diz se roda em `gemini -p`, e uma
#            ferramenta MCP em headless exige aprovação automática (yolo). Por isso só roda com
#            --aceito-aprovacao-automatica, num dir temporário vazio; sem a flag, sai 2 e explica.
#   cursor — sem geração de imagem documentada: sai 2.
# Nunca sobrescreve: <saida> existente = exit 4. Grava <saida>.origem.json (proveniência) e NÃO
# afirma licença: direitos de uso dependem dos termos do provedor e do plano do usuário.
# Exit: 0 ok · 1 rodou mas não produziu imagem · 2 provedor/caminho indisponível · 3 segredo no
#       prompt · 4 uso inválido · 124 timeout.
set -euo pipefail

uso() { echo 'uso: imagem.sh <codex|gemini|cursor> "<prompt>" <saida.png> [--timeout N] [--aceito-aprovacao-automatica]' >&2; exit 4; }
json_str() { printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

[ "$#" -ge 3 ] || uso
prov="$1"; prompt="$2"; saida="$3"; shift 3
tmo=900; yolo=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout) [ "$#" -ge 2 ] || uso; tmo="$2"; shift 2 ;;
    --aceito-aprovacao-automatica) yolo=1; shift ;;
    *) echo "imagem.sh: argumento desconhecido: $1" >&2; exit 4 ;;
  esac
done
case "$prov" in codex|gemini|cursor) ;; *) echo "imagem.sh: provedor inválido: $prov" >&2; exit 4 ;; esac
[[ "$tmo" =~ ^[0-9]+$ ]] && [ "$tmo" -ge 1 ] || { echo "imagem.sh: --timeout inválido" >&2; exit 4; }
[ -n "$prompt" ] || { echo "imagem.sh: prompt vazio" >&2; exit 4; }
if [ -e "$saida" ]; then echo "imagem.sh: $saida já existe; não sobrescrevo (use outro nome, ex.: -v2)" >&2; exit 4; fi
[ -d "$(dirname "$saida")" ] || { echo "imagem.sh: diretório de saída não existe: $(dirname "$saida")" >&2; exit 4; }

SEGREDO='AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9_-]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}|(api[_-]?key|secret|passw(or)?d|token)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9/+_.-]{12,}'
if printf '%s' "$prompt" | grep -qE "$SEGREDO"; then echo "imagem.sh: o prompt parece conter segredo; recusado" >&2; exit 3; fi

if [ "$prov" = "cursor" ]; then
  echo "imagem.sh: o Cursor CLI não tem geração de imagem documentada (verificado na doc em 2026-10-14). Escolha Codex ou Gemini." >&2; exit 2
fi
command -v "$prov" >/dev/null 2>&1 || { echo "imagem.sh: CLI '$prov' não encontrado (rode scripts/detectar.sh)" >&2; exit 2; }
command -v timeout >/dev/null 2>&1 || { echo "imagem.sh: 'timeout' ausente" >&2; exit 2; }

work="$(mktemp -d "${TMPDIR:-/tmp}/models-img-XXXXXX")"
trap 'rm -rf "${work:?}"' EXIT INT TERM
marker="$work/.marker"; : > "$marker"
saida_abs="$(cd "$(dirname "$saida")" && pwd)/$(basename "$saida")"
echo "imagem.sh: AVISO de custo — gasta a cota do usuário em '$prov'; o prompt sai para esse fornecedor." >&2

achada=""
if [ "$prov" = "codex" ]; then
  ch="${CODEX_HOME:-$HOME/.codex}/generated_images"
  mkdir -p "$work/cwd"
  instr="Use a ferramenta built-in de geração de imagem (image_gen) para gerar UMA imagem conforme a descrição abaixo. Não escreva nem edite arquivos. Ao terminar responda só: ok.
Descrição: $prompt"
  rc=0
  cenv=(env -i "PATH=$PATH" "HOME=$HOME" "LANG=${LANG:-C}")
  if [ -n "${CODEX_HOME:-}" ]; then cenv+=("CODEX_HOME=$CODEX_HOME"); fi
  printf '%s' "$instr" | ( cd "$work/cwd" && timeout --kill-after=5 "$tmo" "${cenv[@]}" \
      codex exec -s read-only -C "$work/cwd" --skip-git-repo-check --ephemeral --color never -o "$work/msg.txt" - >"$work/out.txt" 2>"$work/err.txt" ) || rc=$?
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then echo "imagem.sh: timeout (${tmo}s)" >&2; exit 124; fi
  if [ "$rc" -ne 0 ]; then echo "imagem.sh: codex saiu com $rc: $(head -c 400 "$work/err.txt")" >&2; exit 1; fi
  # arquivo(s) NOVOS (depois do marcador). Se outro codex gerar imagem em paralelo, pode haver mais de um.
  mapfile -t cands < <(find "$ch" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -newer "$marker" -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)
  if [ "${#cands[@]}" -gt 1 ]; then echo "imagem.sh: ${#cands[@]} imagens novas em $ch; usando a mais recente (confira se não é de outra sessão)" >&2; fi
  achada="${cands[0]:-}"
else
  if [ "$yolo" -ne 1 ]; then
    cat >&2 <<'MSG'
imagem.sh: caminho do Gemini NÃO VERIFICADO em modo headless.
  A imagem vem da extensão `nanobanana` (gemini extensions install https://github.com/gemini-cli-extensions/nanobanana,
  com NANOBANANA_API_KEY). A doc não confirma uso em `gemini -p`, e ferramenta MCP em headless exige aprovação
  automática. Opções: (a) rodar /generate no gemini interativo; (b) repetir com --aceito-aprovacao-automatica
  (roda `--approval-mode yolo` num diretório temporário vazio, por sua conta e risco).
MSG
    exit 2
  fi
  nk="${NANOBANANA_API_KEY:-${GEMINI_API_KEY:-}}"
  [ -n "$nk" ] || { echo "imagem.sh: falta NANOBANANA_API_KEY (ou GEMINI_API_KEY)" >&2; exit 2; }
  mkdir -p "$work/cwd"; rc=0
  ( cd "$work/cwd" && timeout --kill-after=5 "$tmo" env -i PATH="$PATH" HOME="$HOME" LANG="${LANG:-C}" NANOBANANA_API_KEY="$nk" \
      gemini -p "Use a extensão nanobanana para gerar uma imagem: $prompt" --approval-mode yolo --output-format text >"$work/out.txt" 2>"$work/err.txt" </dev/null ) || rc=$?
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then echo "imagem.sh: timeout (${tmo}s)" >&2; exit 124; fi
  if [ "$rc" -ne 0 ]; then echo "imagem.sh: gemini saiu com $rc: $(head -c 400 "$work/err.txt")" >&2; exit 1; fi
  achada="$(find "$work/cwd" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)"
fi

[ -n "$achada" ] && [ -s "$achada" ] || { echo "imagem.sh: o modelo terminou mas NÃO produziu imagem (não declaro sucesso). Veja a resposta dele e tente de novo." >&2; exit 1; }
cp -- "$achada" "$saida_abs"
printf '{"provedor":"%s","gerado_em":"%s","prompt":"%s","arquivo":"%s","licenca":"NAO VERIFICADA: direitos de uso comercial dependem dos termos do provedor e do plano do usuario; confirmar antes de publicar","origem_local":"%s"}\n' \
  "$prov" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(json_str "$prompt")" "$(json_str "$saida_abs")" "$(json_str "$achada")" > "$saida_abs.origem.json"
printf '{"provedor":"%s","arquivo":"%s","origem":"%s","licenca":"nao verificada (ver .origem.json)"}\n' "$prov" "$(json_str "$saida_abs")" "$(json_str "$saida_abs.origem.json")"
