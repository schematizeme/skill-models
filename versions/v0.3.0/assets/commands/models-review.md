---
description: schematize-models — segunda opinião cruzada de um diff por outro modelo (Codex/Gemini/Cursor); o Claude consolida e reproduz cada achado antes de repassar.
argument-hint: "[provedor] [base..cabeça | arquivos]"
---
Faça a **revisão cruzada** do diff em `$ARGUMENTS` (padrão: `git diff` não commitado):

1. **O Claude revisa primeiro** (a revisão de código é dele, peso 10); a revisão externa é a
   **segunda** opinião (motivo (b)), não a primeira.
2. **Detecte** (`/models-detect`) e escolha o provedor com o usuário se houver mais de um.
3. **Avise custo/egress**: o diff sai da máquina. Em repo de cliente, **pergunte**. Sem segredo no
   diff (rode `git diff | grep` nos padrões de chave; se achar, não envie).
4. **Monte o prompt-file** com o diff e o contrato (`delegacao.md` §1): Objetivo = "listar defeitos
   de correção, segurança e regressão"; Aceite = "cada achado cita `arquivo:linha` e a evidência;
   máximo 10; diga 'nenhum achado' se não houver"; Fora de escopo = "não editar arquivos".
5. **Despache** em `read-only` por `scripts/delegar.sh ... --tipo review` (alternativa só Codex: `codex exec review
   --uncommitted`/`--base <BRANCH>`/`--commit <SHA>`, ver `stack-versoes.md`).
6. **Consolide:** para cada achado externo, **reproduza** (leia o código, rode o teste). Classifique:
   **confirmado** (com a prova), **refutado** (com a prova) ou **hipótese não confirmada**. Divergência
   com a sua revisão não é voto: decide a evidência. Entregue ao usuário a lista consolidada, sua
   e do externo, com o rótulo de cada um.
7. **Placar:** registre a revisão externa (`delegar.sh ... --tipo review`) e ajuste o resultado
   depois de consolidar (`placar.sh ajustar <placar_id> corrigido-pelo-revisor|falhou`: achado
   refutado ou alucinado é `falhou`, nota `alucinou`). Por fim, `placar.sh publicar --auto`
   (silencioso sem opt-in; nunca bloqueia).
