---
description: schematize-models — context compact: grava o handoff no archive e roda /compact.
---
Antes de compactar, **grave o handoff** em `<projeto>/<projeto>_archive/context/` no par
**context + checklist** do padrão da `schematize-archive` (prefixo `AAAA-MM-DD-<slug>-`), FEITO vs
ABERTO. Inclua: as delegações feitas (provedor, motivo (a)-(d), resultado revisado), os achados
externos ainda **não reproduzidos**, as imagens geradas (caminho + licença não verificada) e o
custo/egress já avisado ao usuário. Só então rode `/compact`.
