#!/usr/bin/env bash
# Vermelho primeiro do placar.sh: HOME falso, relógio injetado e `gh` FALSO (stubs.lib.sh).
# Efeito externo nunca sai de teste: MODELS_GH_BIN aponta SEMPRE para o stub, e o HOME falso não tem
# credencial; nenhum caso chama a rede nem cria issue real.
#
# EXCEÇÃO DECLARADA (piso.md §1): harness de teste roda `set -u` sem `-e` — precisa continuar depois
# de um caso vermelho para reportar todos.
# shellcheck disable=SC2016  # `bash -c '...'` com aspas simples é intencional: o script roda no subshell
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=stubs.lib.sh
. "$AQUI/stubs.lib.sh"
P="$AQUI/placar.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT INT TERM
ok=0; fail=0
command -v jq >/dev/null 2>&1 || { echo "placar.test.sh: jq ausente; não há como provar" >&2; exit 2; }
B="$T/bin"; mkstubs "$B" gh
H="$T/home"; mkdir -p "$H"
PL="$H/.claude/schematize/models-score.jsonl"
ST="$H/.claude/schematize/models-placar.json"
NOW="2026-10-15T12:00:00Z"

# run [VAR=val ...] -- <args do placar>; define RC, OUT, ERR, LOG (chamadas ao gh)
run() {
  local envs=() ctl=("STUB_LOG=$T/log")
  while [ "$1" != "--" ]; do case "$1" in STUB_*) ctl+=("$1") ;; *) envs+=("$1") ;; esac; shift; done; shift
  rm -f "$T/log" "$T/log.corpo"; stubctl "$B" "${ctl[@]}"
  OUT="$(env -i PATH="/usr/bin:/bin" HOME="$H" MODELS_PLACAR_NOW="$NOW" MODELS_GH_BIN="$B/gh" "${envs[@]}" bash "$P" "$@" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"; LOG="$(cat "$T/log" 2>/dev/null || true)"
}
esperar() { # nome exit [agulha | !agulha] (procura em OUT, ERR e LOG)
  local nome="$1" esp="$2"; shift 2
  if [ "$RC" != "$esp" ]; then echo "  ✖ $nome: exit $RC, esperado $esp"; echo "      err: $ERR"; fail=$((fail+1)); return; fi
  local a
  for a in "$@"; do
    case "$a" in
      '!'*) if grep -qF -- "${a#!}" <<<"$OUT$ERR$LOG"; then echo "  ✖ $nome: NÃO devia conter \"${a#!}\""; fail=$((fail+1)); return; fi ;;
      *)    if ! grep -qF -- "$a" <<<"$OUT$ERR$LOG"; then echo "  ✖ $nome: faltou \"$a\""; echo "      out: $OUT"; fail=$((fail+1)); return; fi ;;
    esac
  done
  echo "  ✔ $nome"; ok=$((ok+1))
}
verifica() { # nome <comando de teste>
  local nome="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "  ✔ $nome"; ok=$((ok+1)); else echo "  ✖ $nome"; fail=$((fail+1)); fi
}
nlinhas() { if [ -s "$PL" ]; then wc -l < "$PL" | tr -d ' '; else echo 0; fi; }
# reg <ferramenta> <tipo> <resultado> <dur> [modelo] [nota]
reg() {
  local a=(registrar --ferramenta "$1" --tipo "$2" --resultado "$3" --duracao "$4")
  if [ -n "${5:-}" ]; then a+=(--modelo "$5"); fi
  if [ -n "${6:-}" ]; then a+=(--nota "$6"); fi
  run -- "${a[@]}"
}

echo "== vermelho: valor fora do vocabulário é recusado e nada é gravado =="
run -- registrar --ferramenta codex --tipo codigo --resultado ok --duracao 5 --nota "projeto-secreto-acme"; esperar nota-livre-recusada 4 "texto livre é proibido"
run -- registrar --ferramenta codex --tipo "src/app/login.ts" --resultado ok --duracao 5;                  esperar tipo-caminho-recusado 4 "tipo fora do vocabulário"
run -- registrar --ferramenta meu-repo --tipo codigo --resultado ok --duracao 5;                           esperar ferramenta-livre-recusada 4 "ferramenta fora do vocabulário"
run -- registrar --ferramenta codex --tipo codigo --resultado "deu bom" --duracao 5;                       esperar resultado-livre-recusado 4 "resultado fora do vocabulário"
run -- registrar --ferramenta codex --tipo codigo --resultado ok --duracao 5 --modelo /var/app/proj;     esperar modelo-com-caminho-recusado 4 "só o nome do modelo"
run -- registrar --ferramenta codex --tipo codigo --resultado ok --duracao abc;                            esperar duracao-invalida 4 "inteiro"
run -- registrar --ferramenta codex --tipo codigo --resultado ok --duracao 5 --prompt "refatore o login"; esperar campo-extra-recusado 4 "vocabulário fechado"
run -- registrar --ferramenta claude-subagent --tipo codigo --resultado ok --duracao 5;                    esperar subagent-sem-modelo 4 "haiku|sonnet|opus"
verifica nada-gravado-nos-recusados test "$(nlinhas)" = 0

echo "== verde: registrar =="
reg codex codigo ok 12 gpt-5.6-terra;                    esperar registrar-ok 0
ID1="$OUT"
verifica id-hex-12 test "${#ID1}" = 12
reg claude-subagent teste falhou 40 sonnet timeout;      esperar registrar-subagent 0
verifica arquivo-modo-600 test "$(stat -c %a "$PL")" = 600
verifica so-campos-do-vocabulario jq -es 'all(.[]; (keys - ["id","ts","ferramenta","modelo","tipo","resultado","duracao_s","nota"]) == [])' "$PL"
verifica nada-sensivel-no-arquivo bash -c '! grep -qE "home|/tmp|/src|acme|login|\.ts" "$1"' _ "$PL"

echo "== ajustar (o revisor corrige o resultado) =="
run -- ajustar "$ID1" corrigido-pelo-revisor --nota ignorou-instrucao; esperar ajustar-por-id 0 "corrigido-pelo-revisor"
verifica ajuste-gravado jq -es '.[0].resultado=="corrigido-pelo-revisor" and .[0].nota=="ignorou-instrucao" and length==2' "$PL"
run -- ajustar ultimo falhou --ferramenta codex;              esperar ajustar-ultimo-da-ferramenta 0
verifica ajuste-ultimo jq -es '.[0].resultado=="falhou" and .[1].resultado=="falhou"' "$PL"
run -- ajustar 000000000000 ok;                               esperar ajustar-id-inexistente 1 "não encontrado"
run -- ajustar ultimo talvez;                                 esperar ajustar-resultado-invalido 4 "vocabulário"
run -- ajustar ultimo ok --nota "texto livre";                esperar ajustar-nota-livre 4 "vocabulário"

echo "== resumo e preferir (agregação) =="
rm -f "$PL" "$ST"
for _ in 1 2 3 4; do reg codex teste ok 10 >/dev/null; done
reg codex teste falhou 20 padrao erro-cli >/dev/null
reg codex teste indisponivel 0 >/dev/null
for _ in 1 2 3 4 5; do reg cursor teste ok 30 >/dev/null; done
reg cursor teste corrigido-pelo-revisor 30 >/dev/null
reg gemini pesquisa ok 8 >/dev/null
run -- resumo --json
verifica codex-teste-agregado bash -c 'printf "%s" "$1" | jq -e ".[] | select(.ferramenta==\"codex\" and .tipo==\"teste\") | .n==5 and .ok==4 and .falhou==1 and .indisponivel==1 and .duracao_media_s==12"' _ "$OUT"
verifica cursor-teste-agregado bash -c 'printf "%s" "$1" | jq -e ".[] | select(.ferramenta==\"cursor\") | .n==6 and .ok==5 and .corrigido==1"' _ "$OUT"
run -- resumo;                                           esperar resumo-tabela 0 "codex" "teste" "80" "!acme"
run -- preferir teste;                                   esperar preferir-ranking 0 "cursor"
verifica cursor-primeiro-codex-segundo bash -c 'printf "%s\n" "$1" | head -n1 | grep -q "^cursor" && printf "%s\n" "$1" | sed -n 2p | grep -q "^codex"' _ "$OUT"
run -- preferir pesquisa;                                esperar preferir-minimo-de-amostras 1 "!gemini"
run -- preferir pesquisa --min 1;                        esperar preferir-min-1 0 "gemini"
run -- preferir visual-ui;                               esperar preferir-sem-historico 1
run -- preferir "outro";                                 esperar preferir-tipo-invalido 4 "vocabulário"

echo "== publicar: prévia (dry-run) não envia nada =="
rm -f "$ST"
run -- publicar --dry-run
esperar dry-run-previa 0 "NO NOME DA SUA CONTA GITHUB" "PRÉVIA EXATA" "Placar 2026-W42" "schematizeme/schematize-models-placar" "| codex | teste |" "nada foi enviado" "!gh issue create -R schematizeme/schematize-models-placar --title \"Placar 2026-W42\" --body \"Coment"
verifica dry-run-nao-chama-gh test ! -s "$T/log"
verifica dry-run-nao-grava-estado test ! -e "$ST"
verifica previa-sem-ts-nem-id bash -c '! printf "%s" "$1" | grep -qE "20[0-9]{2}-[0-9]{2}-[0-9]{2}T|[0-9a-f]{12}\"" ' _ "$OUT"

echo "== publicar: sem opt-in não publica =="
run -- publicar;                                         esperar sem-optin-manual 3 "sem opt-in"
verifica sem-optin-nao-chama-gh test ! -s "$T/log"
run -- publicar --auto;                                  esperar sem-optin-auto-silencioso 0
verifica auto-silencioso-sem-saida test -z "$OUT$ERR"
run -- optin on;                                         esperar optin-exige-confirmacao 3 "NO NOME DA SUA CONTA GITHUB"
verifica optin-nao-gravado test ! -e "$ST"

echo "== publicar: opt-in, amostras mínimas, gh ausente/deslogado =="
run -- optin on --confirmo;                              esperar optin-on 0
verifica optin-gravado jq -e '.optin==true' "$ST"
run MODELS_GH_BIN=/nao/existe -- publicar --auto;        esperar gh-ausente-silencioso 0
verifica gh-ausente-sem-saida test -z "$OUT$ERR"
run MODELS_GH_BIN=/nao/existe -- publicar;               esperar gh-ausente-avisa 0 "gh ausente"
run STUB_GH_AUTH=0 -- publicar --auto;                   esperar gh-deslogado-silencioso 0 "auth status" "!issue create" "!issue comment"
verifica deslogado-nao-grava-publicacao jq -e '.ultima_publicacao==null' "$ST"

echo "== publicar: poucas amostras não sai (não vaza padrão individual) =="
H_SAVE="$H"; H="$T/home-pouco"; mkdir -p "$H"; PL="$H/.claude/schematize/models-score.jsonl"; ST="$H/.claude/schematize/models-placar.json"
for _ in 1 2 3 4; do reg codex teste ok 5 >/dev/null; done
run -- optin on --confirmo >/dev/null
run -- publicar;                                         esperar menos-de-5-nao-publica 0 "amostras insuficientes (4 < 5)" "!issue"
verifica menos-de-5-nao-chama-comment test ! -s "$T/log"
H="$H_SAVE"; PL="$H/.claude/schematize/models-score.jsonl"; ST="$H/.claude/schematize/models-placar.json"

echo "== publicar: verde (issue da semana criada, comentário igual à prévia) =="
run -- publicar --dry-run;                               PREVIA="$(printf '%s\n' "$OUT" | sed -n '/^--- PRÉVIA EXATA/,/^--- FIM/p' | sed '1d;$d')"
run -- publicar;                                         esperar publica-verde 0 "auth status" "issue list" "issue create -R schematizeme/schematize-models-placar --title Placar 2026-W42" "issue comment 7 -R schematizeme/schematize-models-placar --body-file"
verifica comentario-igual-a-previa bash -c '[ "$(cat "$1")" = "$2" ]' _ "$T/log.corpo" "$PREVIA"
verifica publicacao-gravada jq -e '.ultima_publicacao=="2026-10-15T12:00:00Z" and .optin==true' "$ST"
verifica comentario-sem-ts-id-caminho bash -c '! grep -qE "20[0-9]{2}-[0-9]{2}-[0-9]{2}T|/home|/tmp|gh[a-z]_" "$1"' _ "$T/log.corpo"

echo "== publicar: frequência (1x por semana) e janela desde a última publicação =="
run -- publicar --auto;                                  esperar dentro-do-intervalo-nao-republica 0 "!issue comment"
verifica nada-no-intervalo test -z "$ERR"
NOW="2026-10-16T12:00:00Z"
for _ in 1 2 3 4 5 6; do reg codex docs ok 7 >/dev/null; done
NOW="2026-10-23T12:00:00Z"
run STUB_GH_ISSUES='[{"number":3,"title":"Placar 2026-W43"}]' -- publicar --auto
esperar proxima-semana-reusa-issue-existente 0 "issue comment 3 -R" "!issue create"
verifica janela-so-novas bash -c 'grep -q "6 delegações" "$1" && ! grep -q "| teste |" "$1"' _ "$T/log.corpo"
NOW="2026-10-15T12:00:00Z"

echo "== publicar: falha de rede/permissão é ignorada e não grava =="
H_SAVE="$H"; H="$T/home-falha"; mkdir -p "$H"; PL="$H/.claude/schematize/models-score.jsonl"; ST="$H/.claude/schematize/models-placar.json"
for _ in 1 2 3 4 5 6; do reg codex mecanico ok 3 >/dev/null; done
run -- optin on --confirmo >/dev/null
run STUB_GH_COMMENT_RC=1 -- publicar --auto;             esperar comentario-falhou-silencioso 0 "issue comment"
verifica falha-nao-grava-publicacao jq -e '.ultima_publicacao==null' "$ST"
run -- optin off;                                        esperar optin-off 0
run -- publicar --auto;                                  esperar optin-off-nao-publica 0 "!issue"
H="$H_SAVE"; PL="$H/.claude/schematize/models-score.jsonl"; ST="$H/.claude/schematize/models-placar.json"

echo "== status =="
run -- status;                                           esperar status 0 "registros_locais:" "optin_publicacao: true" "ultima_publicacao: 2026-10-23T12:00:00Z"

echo; echo "placar.test.sh: $ok ok, $fail falhas"
[ "$fail" -eq 0 ]
