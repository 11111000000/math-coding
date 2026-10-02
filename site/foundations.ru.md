# Основания

> **От аксиом к OCaml.** Каждое основание — пакет в
> `decisions/`, отображающий аксиому в механизм ядра
> и обязательство верификации.

## A0 — Разделение → `bootstrap-v3`

**Аксиома.** Виды различны; цепочка идёт одним путём.
`intent ≠ decision ≠ obligation ≠ change ≠ attestation ≠
observation ≠ revision`.

**Механизм.** Закрытые варианты в `lib/domain.ml` для
каждого вида; префиксы на документ; закрытые
`additionalProperties` в JSON-схемах под `schemas/`.
Парсер отвергает любой документ, чей id не принадлежит
закрытому множеству.

**Верификация.** Обязательство `packages-kernel-walker` в
`decisions/mc-packages-subcommand.yaml` перечисляет каждое
решение в репозитории и эмитирует типизированный JSON;
walker падает на виде, не входящем в закрытое множество.

## A1 — Обратная связь → `attestation-store-fill`

**Аксиома.** У каждого обязательства есть путь к наблюдению:
`commitment → prediction → observation → revision`. Без
наблюдения обязательство — пожелание.

**Механизм.** `attestations/*.json` записывает каждую
пару «решение — обязательство» как вердикт `pass | fail |
stale | unknown | missing | no_store`. `lib/attestations.ml`
загружает хранилище и соединяет записи с gate ядра.

**Верификация.** `scripts/generate-attestations.py`
производит 80 файлов аттестаций в каждом релизе;
`mc gate BASE HEAD` отвечает `gate-pass.t` /
`gate-fail.t` / `gate-stale.t` зелёным (cram-фикстуры в
`tests/cli/`).

## A2 — Инварианты и восстановление → `kernel-conformance-runner`

**Аксиома.** Для каждого инварианта `I` оператор
восстановления `R` авторизован. Решение конечно.

**Механизм.** `lib/gate.ml` оценивает каждое обязательство
против хранилища аттестаций и эмитирует типизированные
`Gate.gap` записи с `causes` и `remedies`. Ядро никогда
не блокирует merge, не назвав remedy.

**Верификация.** `tests/conformance.ml` перечисляет каждую
фикстуру и проверяет, что runner не падает; `mc
self-check` возвращает `pass` на чистом `main` HEAD.

## A3 — Само-применение → `mc-self-check-subcommand`

**Аксиома.** Правила управляют своими изменениями:
`(K_n, P_n) → (K_{n+1}, P_{n+1})` требует Gate Open,
Conformance Pass, Migration round-trip, VerdictDiff в
DeclaredSemanticChanges, SelfVerify Pass.

**Механизм.** `mc self-check` обходит каждое решение в
`decisions/` и эмитирует JSON-вердикт, называющий ядро,
которое его произвело (SHA-256 бинаря), и digest
репозитория. Вердикт управляется **текущими** правилами,
до повышения до lock.

**Верификация.** `tests/cli/self-check-{pass,fail,unknown}.t`
зелёные; обязательство `mc-self-check-dispatcher-shipped`
в `decisions/mc-self-check-subcommand.yaml` выполнено.

## A4 — Забота → `validate-and-context`

**Аксиома.** Для каждого обязательства: кому выгодно,
кто страдает, кто ответственен, когда пересмотрим.

**Механизм.** `decision.risk.owner`, `obligation.decision`,
`assumption.owner`, `waiver.issuer`,
`attestation.producer_identity` — **обязательные** поля
в своих схемах. Парсер отвергает решение без владельца.

**Верификация.** `fixtures/conformance/decision/negative-*.yaml`
отвергаются `Decision.parse_decision` за отсутствие
обязательных полей; `fixtures/conformance/decision/positive-*.yaml`
принимаются.

## Расширения

Три расширения добавляют поверхность ядра без изменения
пяти оснований:

| Расширение | Поверхность | Cram-фикстура |
|------------|-------------|----------------|
| `mc-explain-subcommand` | `mc explain decision:foo` → `{kind,id,digest,path,body}` | `explain-{positive,negative}.t` |
| `mc-self-check-subcommand` | `mc self-check` → JSON-вердикт | `self-check-{pass,fail,unknown}.t` |
| `mc-packages-subcommand` | `mc packages --format=text\|json\|html` → список пакетов | `packages.t` |

Ядро на v3.0.0.20 поставляет все восемь. Сайт на
[Packages](packages.html) — живой вердикт всех восьми.