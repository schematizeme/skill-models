#!/usr/bin/env bash
# placar.sh — placar LOCAL de ferramentas delegadas (codex, cursor, gemini, subagents Claude) e
# publicação opt-in, agregada e anônima, num repositório público de feedback.
#
# Motivo: o roteamento por assinatura (references/roteamento.md §6) precisa de evidência de quem
# entrega bem em qual tipo de tarefa; sem registro, a escolha vira opinião. E o feedback agregado
# dos usuários melhora a skill sem que ninguém precise abrir issue à mão.
# Como funciona: cada delegação vira UMA linha JSONL em ~/.claude/schematize/models-score.jsonl com
# campos de vocabulário FECHADO (ferramenta, tipo, resultado, nota) mais modelo e duração. Nada de
# código, caminho, nome de projeto, prompt ou texto livre: o script recusa (exit 4) qualquer valor
# fora do vocabulário. `publicar` agrega e posta UM comentário na issue da semana ISO.
#
# Uso:
#   placar.sh registrar --ferramenta F --tipo T --resultado R --duracao N [--modelo M] [--nota N]
#                       (imprime o id da linha; chamado por delegar.sh e imagem.sh)
#   placar.sh ajustar <id|ultimo> <resultado> [--nota N] [--ferramenta F]   (o revisor corrige)
#   placar.sh resumo [--dias N] [--json]            tabela ferramenta x tipo (n, %ok, %corr, %falha)
#   placar.sh preferir <tipo> [--min N] [--dias N]  ranking com histórico suficiente (exit 1 = sem)
#   placar.sh status                                opt-in, contagens, última publicação
#   placar.sh optin <on --confirmo|off|previa>      liga/desliga a publicação; previa = dry-run
#   placar.sh publicar [--auto] [--agora] [--dry-run]
# Vocabulário fechado:
#   ferramenta: codex cursor gemini claude-subagent (claude-subagent exige --modelo haiku|sonnet|opus)
#   tipo:       codigo refactor teste review visual-ui imagem docs pesquisa mecanico
#   resultado:  ok corrigido-pelo-revisor falhou travou indisponivel
#   nota:       timeout saida-truncada ignorou-instrucao sem-saida erro-cli auth cota alucinou fora-de-escopo
# Ambiente (testes): MODELS_PLACAR_DIR (dir dos arquivos), MODELS_PLACAR_NOW (relógio ISO UTC),
#   MODELS_GH_BIN (binário do gh; os testes apontam para um stub: efeito externo nunca sai de teste),
#   MODELS_PLACAR_REPO (repo de destino).
# Exit: 0 ok · 1 sem resultado (sem histórico/sem registro) · 2 dependência ausente (jq) ·
#       3 opt-in necessário · 4 uso inválido ou valor fora do vocabulário.
set -euo pipefail

REPO_PADRAO="schematizeme/schematize-models-placar"
MIN_PUBLICAR=5
INTERVALO_DIAS=7
TIPOS="codigo refactor teste review visual-ui imagem docs pesquisa mecanico"
RESULTADOS="ok corrigido-pelo-revisor falhou travou indisponivel"
NOTAS="timeout saida-truncada ignorou-instrucao sem-saida erro-cli auth cota alucinou fora-de-escopo"
FERRAMENTAS="codex cursor gemini claude-subagent"
CORPO=""
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "placar.sh: $1" >&2; exit "${2:-4}"; }
em_lista() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

[ -n "${HOME:-}" ] || [ -n "${MODELS_PLACAR_DIR:-}" ] || die "HOME ausente" 4
DIR="${MODELS_PLACAR_DIR:-$HOME/.claude/schematize}"
ARQ="$DIR/models-score.jsonl"
EST="$DIR/models-placar.json"
REPO="${MODELS_PLACAR_REPO:-$REPO_PADRAO}"
GH="${MODELS_GH_BIN:-gh}"

agora() {
  if [ -n "${MODELS_PLACAR_NOW:-}" ]; then
    [[ "$MODELS_PLACAR_NOW" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || die "MODELS_PLACAR_NOW inválido" 4
    printf '%s' "$MODELS_PLACAR_NOW"
  else date -u +%Y-%m-%dT%H:%M:%SZ; fi
}
exige_jq() { command -v jq >/dev/null 2>&1 || die "jq ausente (necessário para este subcomando)" 2; }
# registros íntegros, uma linha JSON por registro; linha corrompida é ignorada
ler() { [ -s "$ARQ" ] || return 0; jq -cR 'fromjson? | select(type == "object")' "$ARQ"; }
desde_dias() { # N -> instante ISO de N dias atrás (relativo ao relógio)
  local n; n="$(agora)"; date -u -d "$n - $1 days" +%Y-%m-%dT%H:%M:%SZ
}

# agregador compartilhado: entrada = array de registros; saída = array de células ferramenta x tipo
AGREGA='
  def rot: .ferramenta + (if .ferramenta == "claude-subagent" then "/" + .modelo else "" end);
  def c(f): map(select(f)) | length;
  map(. + {label: rot}) | group_by([.label, .tipo]) | map({
    ferramenta: .[0].label, tipo: .[0].tipo,
    n: c(.resultado != "indisponivel"),
    ok: c(.resultado == "ok"),
    corrigido: c(.resultado == "corrigido-pelo-revisor"),
    falhou: c(.resultado == "falhou" or .resultado == "travou"),
    indisponivel: c(.resultado == "indisponivel"),
    duracao_media_s: (map(select(.resultado != "indisponivel") | .duracao_s) | if length == 0 then 0 else ((add / length) | round) end)
  }) | sort_by(.ferramenta, .tipo)'

cmd_registrar() {
  local f="" m="" t="" r="" d="" nota=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --ferramenta) [ "$#" -ge 2 ] || die "falta valor de $1"; f="$2"; shift 2 ;;
      --modelo)     [ "$#" -ge 2 ] || die "falta valor de $1"; m="$2"; shift 2 ;;
      --tipo)       [ "$#" -ge 2 ] || die "falta valor de $1"; t="$2"; shift 2 ;;
      --resultado)  [ "$#" -ge 2 ] || die "falta valor de $1"; r="$2"; shift 2 ;;
      --duracao)    [ "$#" -ge 2 ] || die "falta valor de $1"; d="$2"; shift 2 ;;
      --nota)       [ "$#" -ge 2 ] || die "falta valor de $1"; nota="$2"; shift 2 ;;
      *) die "registrar: argumento desconhecido (o placar só aceita campos do vocabulário fechado)" ;;
    esac
  done
  em_lista "$f" "$FERRAMENTAS" || die "ferramenta fora do vocabulário (${FERRAMENTAS// /|})"
  em_lista "$t" "$TIPOS" || die "tipo fora do vocabulário (${TIPOS// /|})"
  em_lista "$r" "$RESULTADOS" || die "resultado fora do vocabulário (${RESULTADOS// /|})"
  [[ "$d" =~ ^[0-9]{1,6}$ ]] || die "--duracao deve ser inteiro de segundos"
  if [ -n "$nota" ]; then em_lista "$nota" "$NOTAS" || die "nota fora do vocabulário (${NOTAS// /|}); texto livre é proibido"; fi
  if [ "$f" = "claude-subagent" ]; then
    case "$m" in haiku|sonnet|opus) ;; *) die "claude-subagent exige --modelo haiku|sonnet|opus" ;; esac
  else
    [ -n "$m" ] || m="padrao"
    # só nome de modelo: sem barra (caminho), sem espaço, curto
    [[ "$m" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$ ]] || die "--modelo deve ser só o nome do modelo (até 32 chars, sem barra nem espaço)"
  fi
  local id ts linha
  id="$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
  ts="$(agora)"
  linha="$(printf '{"id":"%s","ts":"%s","ferramenta":"%s","modelo":"%s","tipo":"%s","resultado":"%s","duracao_s":%s' \
    "$id" "$ts" "$f" "$m" "$t" "$r" "$d")"
  if [ -n "$nota" ]; then linha+="$(printf ',"nota":"%s"' "$nota")"; fi
  linha+='}'
  ( umask 077; mkdir -p "$DIR"; printf '%s\n' "$linha" >> "$ARQ" )
  printf '%s\n' "$id"
}

cmd_ajustar() {
  exige_jq
  [ "$#" -ge 2 ] || die "uso: ajustar <id|ultimo> <resultado> [--nota N] [--ferramenta F]"
  local alvo="$1" res="$2" nota="" filtro=""; shift 2
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --nota)       [ "$#" -ge 2 ] || die "falta valor de $1"; nota="$2"; shift 2 ;;
      --ferramenta) [ "$#" -ge 2 ] || die "falta valor de $1"; filtro="$2"; shift 2 ;;
      *) die "ajustar: argumento desconhecido: $1" ;;
    esac
  done
  em_lista "$res" "$RESULTADOS" || die "resultado fora do vocabulário (${RESULTADOS// /|})"
  if [ -n "$nota" ]; then em_lista "$nota" "$NOTAS" || die "nota fora do vocabulário"; fi
  if [ -n "$filtro" ]; then em_lista "$filtro" "$FERRAMENTAS" || die "ferramenta fora do vocabulário"; fi
  [ -s "$ARQ" ] || die "placar vazio" 1
  local id="$alvo"
  if [ "$alvo" = "ultimo" ]; then
    id="$(ler | jq -r --arg f "$filtro" 'select($f == "" or .ferramenta == $f) | .id' | tail -n 1)"
    [ -n "$id" ] || die "nenhum registro para ajustar" 1
  fi
  [[ "$id" =~ ^[0-9a-f]{12}$ ]] || die "id inválido"
  ler | jq -e --arg id "$id" 'select(.id == $id)' >/dev/null || die "id não encontrado" 1
  local tmp; tmp="$(mktemp "$DIR/.score.XXXXXX")"
  # shell-ok: o temporário mora no mesmo diretório do destino para o mv ser atômico
  trap 'rm -f "${tmp:?}"' EXIT INT TERM
  ler | jq -c --arg id "$id" --arg r "$res" --arg n "$nota" \
    'if .id == $id then .resultado = $r | (if $n != "" then .nota = $n else . end) else . end' > "$tmp"
  mv -- "$tmp" "$ARQ"
  trap - EXIT INT TERM
  echo "placar.sh: $id -> $res"
}

cmd_resumo() {
  exige_jq
  local dias="" json=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dias) [ "$#" -ge 2 ] || die "falta valor de $1"; dias="$2"; shift 2 ;;
      --json) json=1; shift ;;
      *) die "resumo: argumento desconhecido: $1" ;;
    esac
  done
  local desde="0000"
  if [ -n "$dias" ]; then [[ "$dias" =~ ^[0-9]{1,4}$ ]] || die "--dias inválido"; desde="$(desde_dias "$dias")"; fi
  local cel
  cel="$(ler | jq -s --arg d "$desde" "map(select(.ts >= \$d)) | $AGREGA")"
  if [ "$json" -eq 1 ]; then printf '%s\n' "$cel"; return 0; fi
  if [ "$(printf '%s' "$cel" | jq 'length')" -eq 0 ]; then echo "placar vazio (nenhuma delegação registrada na janela)"; return 1; fi
  printf '%-22s %-10s %4s %6s %6s %7s %5s %6s\n' ferramenta tipo n '%ok' '%corr' '%falha' indisp 'dur(s)'
  printf '%s' "$cel" | jq -r '.[] | [.ferramenta, .tipo, .n,
      (if .n == 0 then 0 else ((.ok * 1000 / .n | round) / 10) end),
      (if .n == 0 then 0 else ((.corrigido * 1000 / .n | round) / 10) end),
      (if .n == 0 then 0 else ((.falhou * 1000 / .n | round) / 10) end),
      .indisponivel, .duracao_media_s] | @tsv' |
    while IFS=$'\t' read -r a b c d e f g h; do
      printf '%-22s %-10s %4s %6s %6s %7s %5s %6s\n' "$a" "$b" "$c" "$d" "$e" "$f" "$g" "$h"
    done
}

cmd_preferir() {
  exige_jq
  [ "$#" -ge 1 ] || die "uso: preferir <tipo> [--min N] [--dias N]"
  local tipo="$1" min=5 dias=90; shift
  em_lista "$tipo" "$TIPOS" || die "tipo fora do vocabulário (${TIPOS// /|})"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --min)  [ "$#" -ge 2 ] || die "falta valor de $1"; min="$2"; shift 2 ;;
      --dias) [ "$#" -ge 2 ] || die "falta valor de $1"; dias="$2"; shift 2 ;;
      *) die "preferir: argumento desconhecido: $1" ;;
    esac
  done
  [[ "$min" =~ ^[0-9]{1,4}$ ]] || die "--min inválido"
  [[ "$dias" =~ ^[0-9]{1,4}$ ]] || die "--dias inválido"
  local desde saida; desde="$(desde_dias "$dias")"
  # score = (ok + 0,5 x corrigido) / n: falha e travamento já pesam no denominador
  saida="$(ler | jq -s -r --arg d "$desde" --arg t "$tipo" --argjson min "$min" \
    "map(select(.ts >= \$d)) | $AGREGA | map(select(.tipo == \$t and .n >= \$min))
     | map(. + {score: ((.ok + 0.5 * .corrigido) / .n)}) | sort_by(-.score, -.n)
     | .[] | [.ferramenta, (.score * 100 | round / 100), .n] | @tsv")"
  [ -n "$saida" ] || return 1
  printf '%s\n' "$saida"
}

estado_json() { if [ -s "$EST" ]; then cat "$EST"; else echo '{}'; fi; }
estado_set() { # filtro-jq [args-jq...]
  exige_jq
  local filtro="$1"; shift
  ( umask 077; mkdir -p "$DIR" )
  local tmp; tmp="$(mktemp "$DIR/.estado.XXXXXX")"
  # shell-ok: o temporário mora no mesmo diretório do destino para o mv ser atômico
  trap 'rm -f "${tmp:?}"' EXIT INT TERM
  estado_json | jq -c "$@" "$filtro" > "$tmp"
  mv -- "$tmp" "$EST"
  trap - EXIT INT TERM
}

total_registros() { ler | wc -l | tr -d ' '; }
janela() { # registros posteriores à última publicação
  local ult; ult="$(estado_json | jq -r '.ultima_publicacao // "0000"')"
  ler | jq -c --arg u "$ult" 'select(.ts > $u)'
}

cmd_status() {
  exige_jq
  local optin ult pend
  optin="$(estado_json | jq -r '.optin // false')"
  ult="$(estado_json | jq -r '.ultima_publicacao // "nunca"')"
  pend="$(janela | wc -l | tr -d ' ')"
  echo "registros_locais: $(total_registros)"
  echo "pendentes_de_publicacao: $pend (minimo $MIN_PUBLICAR)"
  echo "optin_publicacao: $optin"
  echo "ultima_publicacao: $ult"
  echo "repo_destino: $REPO"
  echo "arquivo: $ARQ"
}

semana_iso() { date -u -d "$(agora)" +%G-W%V; }

versao_skill() { if [ -s "$AQUI/../VERSION" ]; then tr -d '\n' < "$AQUI/../VERSION"; else printf 'desconhecida'; fi; }

# monta o corpo EXATO do comentário (stdin: registros da janela). Só agregados: sem ts, sem id.
monta_corpo() {
  local regs semana ver n cel notas
  regs="$(jq -s '.')"
  semana="$(semana_iso)"; ver="$(versao_skill)"
  n="$(printf '%s' "$regs" | jq 'length')"
  cel="$(printf '%s' "$regs" | jq "$AGREGA")"
  notas="$(printf '%s' "$regs" | jq -c 'map(select(.nota != null) | .nota) | group_by(.) | map({key: .[0], value: length}) | from_entries')"
  echo "<!-- placar-models v1 -->"
  echo "**Placar anônimo** — skill schematize-models v$ver, semana $semana, $n delegações."
  echo
  echo "| ferramenta | tipo | n | ok | corrigido | falhou/travou | indisponível | duração média (s) |"
  echo "|---|---|---|---|---|---|---|---|"
  printf '%s' "$cel" | jq -r '.[] | "| \(.ferramenta) | \(.tipo) | \(.n) | \(.ok) | \(.corrigido) | \(.falhou) | \(.indisponivel) | \(.duracao_media_s) |"'
  echo
  echo "Notas (contagem): $(printf '%s' "$notas" | jq -r 'if length == 0 then "nenhuma" else to_entries | map("\(.key)=\(.value)") | join(", ") end')"
  echo
  echo '<details><summary>JSON</summary>'
  echo
  echo '```json'
  jq -n --arg v "$ver" --arg s "$semana" --argjson n "$n" --argjson c "$cel" --argjson no "$notas" \
    '{versao_esquema: 1, skill: $v, semana: $s, delegacoes: $n, celulas: $c, notas: $no}'
  echo '```'
  echo
  echo '</details>'
}

AVISO_AUTORIA='AVISO: o comentário é publicado NO NOME DA SUA CONTA GITHUB, num repositório público. O conteúdo é anônimo (só contagens agregadas, sem código, caminho, projeto nem prompt); a autoria NÃO é anônima.'

cmd_optin() {
  [ "$#" -ge 1 ] || die "uso: optin <on --confirmo|off|previa>"
  case "$1" in
    previa) cmd_publicar --dry-run ;;
    off) estado_set '.optin = false'; echo "placar.sh: publicação desligada; o placar segue local." ;;
    on)
      if [ "${2:-}" != "--confirmo" ]; then
        echo "$AVISO_AUTORIA" >&2
        echo "placar.sh: veja a prévia (optin previa) e confirme com: optin on --confirmo" >&2
        exit 3
      fi
      estado_set ".optin = true | .optin_em = \$t" --arg t "$(agora)"
      echo "placar.sh: publicação semanal ligada (mínimo $MIN_PUBLICAR amostras)." ;;
    *) die "optin: use on --confirmo | off | previa" ;;
  esac
}

cmd_publicar() {
  local auto=0 agora_flag=0 dry=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --auto) auto=1; shift ;;
      --agora) agora_flag=1; shift ;;
      --dry-run) dry=1; shift ;;
      *) die "publicar: argumento desconhecido: $1" ;;
    esac
  done
  # em --auto nada pode falhar para fora: o placar nunca bloqueia o trabalho
  if [ "$auto" -eq 1 ]; then
    command -v jq >/dev/null 2>&1 || return 0
  else exige_jq; fi
  msg() { if [ "$auto" -eq 0 ]; then echo "placar.sh: $1" >&2; fi; }

  local regs n; regs="$(janela)"
  n="$(printf '%s' "$regs" | grep -c . || true)"
  local semana; semana="$(semana_iso)"
  local titulo="Placar $semana"

  if [ "$dry" -eq 1 ]; then
    echo "$AVISO_AUTORIA"
    echo "Repositório: $REPO · issue: \"$titulo\" (criada se não existir) · $n delegações na janela (mínimo $MIN_PUBLICAR)."
    echo "--- PRÉVIA EXATA DO COMENTÁRIO ---"
    if [ "$n" -gt 0 ]; then printf '%s\n' "$regs" | monta_corpo; else echo "(nada a publicar)"; fi
    echo "--- FIM DA PRÉVIA ---"
    echo "Comandos que seriam executados (nada foi enviado):"
    echo "  gh issue list -R $REPO --state all --search \"$titulo in:title\" --json number,title"
    echo "  gh issue create -R $REPO --title \"$titulo\" --body <texto fixo>   (só se não existir)"
    echo "  gh issue comment <n> -R $REPO --body-file <prévia acima>"
    return 0
  fi

  [ "$(estado_json | jq -r '.optin // false')" = "true" ] || {
    msg "publicação sem opt-in: nada enviado (use: optin previa; depois optin on --confirmo)"
    [ "$auto" -eq 1 ] && return 0; exit 3; }
  if [ "$n" -lt "$MIN_PUBLICAR" ]; then msg "amostras insuficientes ($n < $MIN_PUBLICAR): nada enviado"; return 0; fi
  if [ "$agora_flag" -eq 0 ]; then
    local ult lim; ult="$(estado_json | jq -r '.ultima_publicacao // ""')"
    if [ -n "$ult" ]; then
      lim="$(date -u -d "$ult + $INTERVALO_DIAS days" +%Y-%m-%dT%H:%M:%SZ)"
      if [[ "$(agora)" < "$lim" ]]; then msg "última publicação em $ult; próxima a partir de $lim"; return 0; fi
    fi
  fi
  command -v "$GH" >/dev/null 2>&1 || { msg "gh ausente: placar fica local"; return 0; }
  timeout 20 "$GH" auth status >/dev/null 2>&1 || { msg "gh sem autenticação: placar fica local"; return 0; }

  local num url
  CORPO="$(mktemp "${TMPDIR:-/tmp}/placar-corpo-XXXXXX")"
  # shell-ok: apagado no trap de saída do script (CORPO é global para o trap enxergar)
  trap 'rm -f "${CORPO:?}"' EXIT INT TERM
  printf '%s\n' "$regs" | monta_corpo > "$CORPO"
  num="$(timeout 30 "$GH" issue list -R "$REPO" --state all --limit 100 --search "$titulo in:title" --json number,title 2>/dev/null \
        | jq -r --arg t "$titulo" '[.[] | select(.title == $t) | .number] | min // empty' 2>/dev/null || true)"
  if [ -z "$num" ]; then
    url="$(timeout 30 "$GH" issue create -R "$REPO" --title "$titulo" \
      --body "Comentários agregados e anônimos de delegação da semana $semana. O que é coletado e o que não é: README do repositório." 2>/dev/null || true)"
    num="${url##*/}"
    [[ "$num" =~ ^[0-9]+$ ]] || { msg "não consegui criar a issue da semana: placar fica local"; return 0; }
  fi
  if timeout 30 "$GH" issue comment "$num" -R "$REPO" --body-file "$CORPO" >/dev/null 2>&1; then
    estado_set ".ultima_publicacao = \$t" --arg t "$(agora)"
    msg "publicado em $REPO#$num ($n delegações, semana $semana)"
  else msg "falha ao comentar (rede/permissão): placar fica local"; fi
  return 0
}

[ "$#" -ge 1 ] || die "uso: placar.sh registrar|ajustar|resumo|preferir|status|optin|publicar ..."
sub="$1"; shift
case "$sub" in
  registrar) cmd_registrar "$@" ;;
  ajustar)   cmd_ajustar "$@" ;;
  resumo)    cmd_resumo "$@" ;;
  preferir)  cmd_preferir "$@" ;;
  status)    cmd_status "$@" ;;
  optin)     cmd_optin "$@" ;;
  publicar)  cmd_publicar "$@" ;;
  *) die "subcomando desconhecido: $sub" ;;
esac
