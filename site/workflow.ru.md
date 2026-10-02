# Workflow

> **От intent до revision.** Workflow math-coding — это
> пятисостоянийный FSM из `decisions/decision.yaml`,
> применённый как дисциплина. Шесть шагов, один бинарь.

## 1. Сформулируйте intent

Откройте `decisions/<id>.yaml` с `intent:`. Intent это
«почему»; «что именно обещаем» приходит следом. Запись
без intent — запись о пустоте.

```yaml
intent: |
  Добавить структурированный лог вердиктов пар
  decision-obligation, чтобы ревьюеры могли ответить
  «безопасно ли мёрджить?» без перечитывания ядра.
```

## 2. Зафиксируйте обязательство

Обязательство — **фальсифицируемое утверждение**. Блок
`obligation` называет верификацию:

```yaml
commitment: |
  mc packages --format=html рендерит HTML-сетку пар
  decision-obligation с вердиктами.
obligation:
  - id: packages-kernel-walker
    acceptance:
      all:
        - verifier: mc packages --format=json
          result: pass
```

## 3. Реализуйте

`lib/packages.ml` и `bin/Mathc.ml` меняются, чтобы
выполнить обязательство. Реализация остаётся на OCaml,
без побочных эффектов, ~700 строк плюс бинарь.

## 4. Аттестуйте

Запустите `scripts/generate-attestations.py` после
каждой реализации. Скрипт создаёт
`attestations/<sha>.json` для каждой пары. Закоммитьте
файлы аттестаций.

## 5. Проверьте gate

`mc gate BASE HEAD` запускается против заполненного
хранилища. Код выхода: `0` для `pass`, `1` для `block`,
`3` для `unknown`. CI-блокирующий шаг — `mc self-check`.

## 6. Self-verify

`mc self-check` запускается против **всего** графа
решений. Код выхода возводит merge в main. Self-check
возвращает JSON с `verdict`, `subjects_count`,
`pass_count` и `kernel_digest` (SHA-256 бинаря,
который произвёл вердикт).

## Развёрнутый пример

Решение о добавлении `mc packages` прошло шесть шагов в
коммите `5d1046a`:

| Шаг | Коммит | Верификатор |
|-----|--------|-------------|
| 1. Сформулировать intent | `mc-packages-subcommand@1` | блок `intent:` |
| 2. Зафиксировать | тот же | `commitment:` + `obligation:` |
| 3. Реализовать | `lib/packages.ml`, `bin/Mathc.ml` | `dune build` exit 0 |
| 4. Аттестовать | `attestations/mc-packages-subcommand-*.json` | `mc packages --format=json` |
| 5. Gate | `tests/cli/gate-{pass,fail,stale}.t` | cram зелёные |
| 6. Self-verify | `tests/cli/self-check-pass.t` | cram зелёный |

Шестиступенчатая петля — это ядро, применяющее A3 к
себе. [Axioms](axioms.html) для формального
утверждения.