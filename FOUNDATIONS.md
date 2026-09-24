# Основания и расширения

math-coding состоит из восьми пакетов: пять оснований (`foundations/`)
и три расширения (`extensions/`). Все восемь проверяются одним и тем
же ядром — никакого специального пути для оснований не существует.

## Основания

### `math/foundations/curry-howard/`

**Тезис.** Решение есть тройка (proposition, code, witness); ядро $S$
проверяет структурное соответствие между proposition и code через
witness.

**Реализация в OCaml:** тип `decision` в `core/types.ml` —
прямое отражение тройки из изоморфизма Карри-Ховарда. proposition
есть тип, code есть терм, witness есть derivation.

**Когда применяется:** каждый пакет в проекте. Основание
curry-howard — это схема данных.

### `math/foundations/temporal/`

**Тезис.** Жизненный цикл $L$ решения есть функция от решения и
git-истории; $L$ вычисляется, а не хранится.

**Реализация в OCaml:** `Lifecycle.compute : decision -> lifecycle`
в `core/lifecycle.ml`. Возвращает `Draft | Applied | Drift | Stale`
на основании witness и `git show <sha>:math/<name>/packet.md`.

**Когда применяется:** каждый раз при `mathc check`. Если proposition
в witness-коммите отличается от текущей — drift.

### `math/foundations/constructive/`

**Тезис.** Состояние `proven` требует воспроизводимого свидетельства:
повторный запуск команды должен давать записанный код выхода.

**Реализация в OCaml:** `Repo.run_substrate` в `core/repo.ml`
запускает shell-команду, записывает код выхода во временный файл,
сравнивает с `recorded_exit`. Несовпадение → drift.

**Когда применяется:** пакеты с `substrate: shell` или `substrate: pbt`.
Без substrate — конструктивное доказательство не требуется.

### `math/foundations/categorical/`

**Тезис.** Замещение — строгий частичный порядок: иррефлексивный,
асимметричный, транзитивный.

**Реализация в OCaml:** `Check.check_supersession` в
`core/check.ml`. Проверяет, что `superseded_by` указывает на
существующий пакет в состоянии `applied`.

**Когда применяется:** каждый раз при `mathc check`. Обнаружение
цикла — `Fail`.

### `math/foundations/motivation/`

**Тезис.** Каждый пакет декларирует эпистемический регистр
(`fact`/`hypothesis`/`judgment`/`unknown`) и численную уверенность.
Поле `why` (в секции `## Why`) обязательно для `judgment`.

**Реализация в OCaml:** `Check.check_motivation` в `core/check.ml`.
Проверяет, что register ∈ допустимых, confidence ∈ [0,1],
соответствует register. why непусто.

**Когда применяется:** каждый пакет. `why` обязательно для `judgment`-
пакетов (Warn, не Fail).

## Расширения

### `math/extensions/process-fsm/`

**Тезис.** Решения существуют в пяти состояниях (`draft`, `applied`,
`reviewed`, `retired`, `abandoned`); единственный запрещённый
переход — `draft` → `reviewed` без witness.

**Реализация в OCaml:** `Check.check_fsm` в `core/check.ml`.
Сравнивает `state` пакета с наличием witness. Запрещённый переход
выдаёт `Fail`.

**Когда применяется:** каждый пакет с явным `state: reviewed`. Без
witness — отвергается.

### `math/extensions/dialectic-tas/`

**Тезис.** Пакеты с регистром `judgment` или actor `human` требуют
разделов `## Thesis`, `## Antithesis`, `## Synthesis`. Структурная
форма диалектики обязательна для человеческих суждений.

**Реализация в OCaml:** `Check.check_dialectic` в `core/check.ml`.
Парсит секции Markdown в теле packet.md. Отсутствие любой —
`Warn`.

**Когда применяется:** каждый `judgment` или `human` пакет. Warn,
не Fail — рекомендация, не требование.

### `math/extensions/actor-discipline/`

**Тезис.** Решение фиксирует автора через подписи коммитов; режим
подписи (`strict`/`lenient`/`off`) определяется проектом через
`.mathrc`.

**Реализация в OCaml:** `Repo.run_substrate` + `verify_signature` в
`core/repo.ml`. Три режима через `.mathrc: SIGNING_MODE`.

**Когда применяется:** пакеты с `actor: human` или `actor: agent`.
`strict` → Fail без подписи; `lenient` → Warn; `off` → игнорирует.

## Структура пакета (9 полей frontmatter)

```yaml
---
schema_version: "2.0"                  # обязательно
name: <unique-name>                     # обязательно
proposition: <one-sentence>             # обязательно, non-empty
register: fact|hypothesis|judgment|unknown  # обязательно
state: draft|applied|reviewed|retired|abandoned  # обязательно
superseded_by: <name>|""               # обязательно (пусто если нет)
actor: human|agent|system               # обязательно
confidence: <0.0-1.0>                 # обязательна для fact/hypothesis
beneficiary: <enum>|Other(text)         # опционально
---
```

Поле `schema_version` гарантирует, что ядро знает, какой плагин
формата использовать для парсинга. Начиная с v2.0 — обязательно.