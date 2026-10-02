# math-coding

> **Дисциплина записывать решения раньше кода.** Ядро —
> один статический бинарь; пакеты — простой текст и
> живут в `decisions/`; вердикты производят `mc gate` и
> `mc self-check`.

## Что это такое

math-coding связывает конкретное изменение с
обязательствами, которых оно может коснуться, и с
ограниченными доказательствами этих обязательств. Не
доказывает корректность ПО. Рабочая цепочка:

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

Каждое архитектурное обязательство записывается
**раньше** кода, и ядро проверяет обязательство против
кода при каждом merge. Дисциплина называется
**mathoding** — math-coding как методология.

## Что оно поставляет

- Ядро (`mc`), один OCaml-бинарь, ~700 строк плюс
  транзитивные модули.
- Восемь принципов, каждый задокументирован как пакет
  в `decisions/` и верифицируем cram-фикстурой в
  `tests/cli/`.
- Статический сайт (этот), генерируемый `mc render`,
  деплоится на GitHub Pages.

## Пять аксиом + три расширения

| Группа | Принцип | Что утверждает |
|--------|---------|-----------------|
| основа | `bootstrap-v3` | ядро может проверить этот репозиторий |
| основа | `kernel-conformance-runner` | каждая фикстура перечислена и запущена |
| основа | `validate-and-context` | каждое решение парсится и открывает капсулу |
| основа | `gate-decision` | вердикт ворот проверен сценарно |
| основа | `attestation-store-fill` | хранилище аттестаций заполнено |
| расширение | `mc-explain-subcommand` | `mc explain` разрешает `decision:` ссылки |
| расширение | `mc-self-check-subcommand` | `mc self-check` возвращает автоматический вердикт |
| расширение | `mc-packages-subcommand` | `mc packages` — поверхность первого класса |

См. [Foundations](foundations.html) для полного
отображения каждой аксиомы в механизм ядра и
обязательство верификации.

## Быстрый старт

```sh
nix develop .#test
dune build
dune test
mc self-check     # выводит JSON-вердикт; exit 0 = pass
```

Чтобы отрендерить сайт локально:

```sh
scripts/render.sh         # собирает mathc, запускает
                          # `mc render`, проверяет
                          # allowlist
python3 -m http.server -d dist/ 8000
# откройте http://localhost:8000/
```

## Команды

| команда | назначение |
|---------|------------|
| `mc validate FILE` | распарсить FILE как решение |
| `mc context BASE HEAD --budget N` | вывести JSON-капсулу контекста |
| `mc explain DETAIL_REF` | разрешить `decision:<id>` в тело |
| `mc assess BASE HEAD` | список изменённых путей |
| `mc attest FILE` | распарсить JUnit-XML отчёт |
| `mc time-estimate --class ... --count N` | прогноз по референсному классу |
| `mc gate BASE HEAD` | вердикт ворот против хранилища аттестаций |
| `mc self-check` | автоматическая самопроверка |
| `mc packages --format=text\|json\|html` | сетка пакетов |
| `mc render [--lang en\|ru\|both]` | отрендерить статический сайт |

## Где что лежит

| путь | что |
|------|-----|
| `lib/` | чистые OCaml-модули ядра |
| `bin/` | dispatcher CLI `mc` |
| `decisions/` | пакеты decision + obligation (поверхность assurance) |
| `attestations/` | аттестации по SHA (поверхность доказательств) |
| `axioms/` | пять аксиом как Markdown |
| `spec/` | constitution + semantics + algebra (формальный слой) |
| `site/` | опубликованная проза, на EN + RU |
| `tests/cli/*.t` | cram-фикстуры для CLI |
| `tests/*.ml` | юнит- и conformance-тесты ядра |

## См. также

- [Manifesto](manifesto.html) — зачем это существует.
- [Methodology](methodology.html) — дисциплина.
- [Axioms](axioms.html) — пять аксиом.
- [Foundations](foundations.html) — аксиомы → OCaml.
- [Workflow](workflow.html) — шестиступенчатая петля.
- [FAQ](faq.html) — самые частые вопросы.
- [Contributing](contributing.html) — как внести вклад.
- [Packages](packages.html) — живая поверхность assurance.
- `AGENTS.md` — протокол агента.
- `ROADMAP.md` — очередь приоритетов.
- `PACKAGES.md` — единственный источник истины о том, что
  существует.

## Лицензия

Apache-2.0. См. `LICENSE` и `NOTICE`.