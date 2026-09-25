---
schema_version: "2.1"
name: review-real-signing
proposition: "cmd_review обещает '(signed)' в help, но в реализации (cmd_transition) просто меняет state на reviewed без проверки подписи. Это вводит в заблуждение: пользователь думает, что review подтверждает подпись, но проверки нет. Два варианта фикса: (a) реализовать проверку через Repo.verify_commit_signature в Strict режиме, (b) убрать '(signed)' из help и оставить как soft transition. Выбираю (a) — поведение лучше согласуется с convention 'self-application', потому что reviewed пакеты должны быть реально подписаны."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---

## Why

reviewed state в math-coding FSM (V4) — единственное состояние, требующее human sign-off. Это документировано как 'reviewed requires human sign-off' в check_actor V5 warn-сообщении. Но команда 'mathc review' не делает проверки: ни подписи коммита, ни того, что текущий actor — human. Получается, что state=reviewed — это просто ярлык без операционного содержания. Это нарушает convention applies to itself: kernel S не должен иметь фичу, которая ничего не проверяет.

## Antithesis

Проверка подписи в cmd_review дублирует V5: kernel S уже делает это в Strict режиме через check_actor, и cmd_review ничего не добавляет. Если пользователь работает в Off/Lenient режиме, проверка молча пропускается — reviewed state ничем не отличается от applied. Дополнительная сложность без пропорциональной пользы.

## Synthesis

Реализовать проверку подписи в cmd_review через Repo.verify_commit_signature. В Strict режиме: если witness есть и не подписан — exit 1 с понятной ошибкой. В Lenient: warn, но allow (соответствует поведению V5). В Off: пропустить (как V5). Это делает reviewed state операционно значимым, а не ярлыком. Обновить help: '(signed)' → '(transition; Strict mode requires signed witness)'.
