# Math Coding console для Paseo

Плагин `plugin/math-coding-console` показывает состояние Math Coding v5 в workspace текущего проекта. Он является представлением над `mathc`, а не второй реализацией метода.

## Граница доверия

Единственный источник verdict и состояний claim — результат:

```sh
mathc --root ROOT map --json
```

Плагин не пересчитывает freshness, independence, control reach или композицию `all`/`any`. Наблюдение `pass` не становится `holds`, waiver не становится green, а `not-run` не становится `refuted`.

`spec.json` и `.math/v5/evidence.jsonl` дают только содержимое для объяснения карты. Набор claim IDs, goal и числовые границы map/spec должны совпадать. Неизвестная схема, повреждённый JSONL, изменившийся во время чтения проект или несогласованный verdict/exit дают явную ошибку без fallback к прежнему green.

## Поверхности

- `Math Coding` workspace panel показывает Map, Claims, Evidence и Coverage.
- Command Center action и `/mc` открывают тот же panel.
- Settings screen задают абсолютный путь к `mathc`, интервал read-only refresh и разрешение **Run checks**.

Refresh, polling, фильтры и навигация выполняют только `map`. **Run checks** выключен по умолчанию. После явного разрешения в Settings кнопка требует второго подтверждения, выполняет объявленные проектом verifier/control commands и записывает evidence. Разрешение в Settings и UI-подтверждение являются защитой от случайного запуска, а не аутентификацией доверенного plugin-кода.

## Graph

Граф строится из существующих данных v5:

```text
Goal / Source → Claim → all/any requirement tree
Claim → declared scope
Goal → uncovered path
```

При выборе claim detail показывает цепочку `Source → Claim → Requirement → Evidence → producer/environment/control/digests`.

Общий scope нескольких claims обозначен как `shared declared scope`, а не dependency. Claim-to-claim и ADR-to-ADR связей в v5 нет, поэтому plugin их не рисует. Evidence не раздувает общий граф: история загружается для выбранного claim.

Claim state и evidence outcome используют разные словари и разные визуальные обозначения. Цвет никогда не является единственным носителем смысла.

## Server boundary

Корень проекта определяется server-side по `workspaceId` через Paseo SDK. Client не передаёт произвольный filesystem path. Процессы запускаются через argv без shell interpolation, с timeout и ограничением вывода.

По умолчанию используется `mathc` из `PATH`. Явный override обязан быть абсолютным путём и сообщать `mathc 5`. Автоматический выбор локального `_build` бинаря запрещён: смена бинаря меняет environment fingerprint и может сделать прежнее evidence устаревшим.

Операции одного workspace сериализованы. Очередь ограничена: если workspace занят длинным run, новый snapshot получает явную ошибку вместо бесконечного накопления запросов. Одновременный `run` для одного дерева не запускается.

## Связь с standing specification

Текущая human-owned specification этого репозитория описывает ядро v5 и не менялась вместе с plugin. Поэтому `plugin/` не входит в goal scope и не создаёт скрытого claim. Поставка plugin защищена отдельным CI job, который выполняет typecheck, unit tests, render checks, отрицательные контроли и client audit.

## Разработка

```sh
cd plugin/math-coding-console
npm install
npm run typecheck
npm test
npm run test:render
npm run test:negative
npm run audit:client
npm pack --dry-run --ignore-scripts
```

`test:render` собирает entry points, panel и все представления с fixture в light/compact вариантах. `test:negative` изменяет только временные копии plugin и доказывает, что проверки ломаются при неверной обработке canonical exit, рассогласовании map/spec, пропуске повреждённого JSONL, выдумывании dependency edges, принятии unsupported schema, автоматическом запуске checks и обходе запрета Run checks.

После изменений:

```sh
git diff --check
nix develop -c dune build --root .
nix develop -c dune runtest --root . --force
nix develop -c ./_build/default/bin/mathc.exe --root . run
```

После merge:

```sh
paseo plugin install /absolute/path/to/math-coding/plugin/math-coding-console
paseo plugin enable math-coding-console
paseo plugin reload math-coding-console
paseo plugin ls
paseo plugin logs math-coding-console
```
