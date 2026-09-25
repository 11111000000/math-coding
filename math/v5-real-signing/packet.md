---
schema_version: "2.1"
name: v5-real-signing
proposition: "check_actor в core/check.ml всегда возвращает Pass для SIGNING_MODE=Strict, не вызывая Repo.verify_commit_signature. То есть 'strict mode' в .mathrc — декоративный флаг. Реализовать: в Strict режиме, если decision.witness = Some w, вызвать Repo.verify_commit_signature w.sha; если подписи нет — Fail. В Lenient — Warn. В Off — Pass без проверки."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---

## Why

V5 (actor discipline) — один из семи инвариантов ядра, документирован в FOUNDATIONS.md ('Signed commits fix author — three signing modes') и в .mathrc ('SIGNING_MODE: strict | lenient | off'). Но в коде Strict mode — пустой ярлык: возвращает Pass независимо от того, подписан ли witness-коммит. Это даёт ложное чувство безопасности: пользователь ставит SIGNING_MODE: strict в .mathrc, ожидая, что непроверенные коммиты будут Fail, но они проходят. conventions applies to itself: actor-discipline пакет сам говорит про три режима, и текущий код нарушает собственную конвенцию.

## Antithesis

Строгая проверка подписей требует, чтобы git был настроен с GPG или SSH signing key. На большинстве CI это не настроено. Если сразу сделать V5 Fail на unsigned, проект ломается для всех, кто использует mathc init без предварительной настройки signing. Нужна либо миграция (поменять default на 'off'), либо ступенчатое внедрение (Warn сейчас, Fail потом). Также: Repo.verify_commit_signature возвращает None и для случая, когда git verify-commit падает по другой причине (например, GPG agent не запущен) — false negative.

## Synthesis

Реализовать в три уровня по текущему SIGNING_MODE: Off — Pass без проверки (текущее поведение, ничего не меняем); Lenient — Warn если witness есть и не подписан, Pass если подписан или witness нет; Strict — Fail если witness есть и не подписан, Pass иначе. default в .mathrc остаётся off (как сейчас). false negative от GPG agent — известная проблема git, но она проявляется как 'не подписан', что для Strict даёт Fail — пользователь увидит ошибку и поймёт, что нужно настроить GPG. Это правильное поведение: лучше Fail с шумом, чем Pass с тихой дырой. Дополнительно: убрать мёртвые let _ = actor_str in / let _ = reg_str in из check_actor.
