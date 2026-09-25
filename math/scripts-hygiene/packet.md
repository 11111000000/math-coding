---
schema_version: "2.1"
name: scripts-hygiene
proposition: "scripts/render.sh использует 'set -u' но не 'set -e' — при ошибке dune build или mathc render скрипт продолжает работу и пишет OK в конце. Также 'for d in math/*/' без nullglob — пустой math/ вызывает цикл с литералом 'math/*/'. scripts/migrate-v2-to-v2-y.sh расходится с mathc init: разный .mathrc (мёртвые поля SCHEMA_VERSION, SUBSTRATE_DEFAULT, STRICT_DRIFT_CHECK, DEFAULT_JSON), pre-commit ставится в .git/hooks/ вместо .git-hooks/ + core.hooksPath. Два пути bootstrap → два пути багов."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---

## Why

(1) render.sh без set -e: реальный баг. Если dune build падает (например, на circular dependency), скрипт молча продолжает, делает render с бинарём прошлой версии, выводит 'render OK' — пользователь думает, что всё прошло. (2) migrate-v2-to-v2-y.sh: создаёт несовместимый .mathrc с SCHEMA_VERSION (которое не читается ядром, удалено в Phase 1.4) и другими мёртвыми полями; ставит hook в .git/hooks/ что не работает с core.hooksPath=.git-hooks, который выставил mathc init. Brownfield-миграция ломает bootstrap.

## Antithesis

(1) set -e слишком агрессивен — некоторые команды должны завершаться с ошибкой без aborting скрипта (например, 'command -v dune' для проверки). Можно использовать '|| true' явно. (2) Удаление migrate-v2-to-v2-y.sh — breaking change для пользователей, которые его запускали. Альтернатива: оставить, но пометить как legacy в комментарии.

## Synthesis

(1) render.sh: добавить 'set -e', 'set -o pipefail', использовать 'shopt -s nullglob' (или проверку 'ls math/ | grep' вместо glob). Каждый pipeline-компонент должен проверять свой exit code через '|| { echo ...; exit 1; }'. (2) migrate-v2-to-v2-y.sh: переписать .mathrc-блок на актуальную версию (как в mathc init, но без мёртвого SCHEMA_VERSION), использовать ту же логику hooksPath. Это фактически превращает migrate в 'mathc init + install hooks', что и есть его назначение.
