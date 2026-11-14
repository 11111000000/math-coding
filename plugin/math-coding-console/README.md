# Math Coding console для Paseo

Плагин `plugin/math-coding-console` превращает карту Math Coding v5 в рабочую очередь решений для человека, который работает вместе с агентами. Главный экран отвечает не «сколько здесь всего данных», а **что человек должен решить сейчас, что агент может сделать сам и какой риск уже принят**.

Плагин является представлением над `mathc`, а не второй реализацией метода.

## Attention desk

### Только человек

- **Изменён источник.** Прежнее решение нужно реально пересмотреть. Агент может собрать diff и подготовить контекст, но не может записать review или подтвердить решение владельца.
- **Опровержение.** Агент может воспроизвести и исправить реализацию, но человек решает, остаётся ли claim/falsifier/control правильным контрактом.
- **Незакрытый human review.** Только человек с указанной authority и independence может закрыть review-требование. Если в одном claim есть машинная и человеческая части, машинная часть остаётся доступной агенту.
- **Claim без проверяемого условия.** Человек задаёт критерий приёмки; агент может предложить реализацию проверки.
- **Истёкший waiver.** Прежнее принятие риска больше не действует, но Attention не выдаёт это за новое решение, если каноническое состояние уже `holds`.

### Агент может действовать

- `outdated` без изменения источника — обновить evidence штатными checks;
- `never-checked` — выполнить объявленные проверки;
- `inconclusive` — расследовать неизвестность, не превращая её в assumed pass;
- `uncovered` — предложить claims и границы scope, не меняя human-owned goal.

Одинаковые пункты группируются. Если пятнадцать claims устарели, Attention показывает одну агентскую задачу, а не пятнадцать отдельных карточек.

### Уже принято

Waiver показывается как **accepted risk** только при каноническом состоянии `waived` и внутри действующего интервала. В этом случае видны issuer, срок и recovery plan, но риск не выдаётся за ожидающее решение и не маскирует `refuted`.

Приоритет human queue следует каноническому порядку `mathc next`: изменённый источник → опровержение → неизвестность → риск. Attention не вводит новый verdict или severity.

## Представления

Верхняя навигация намеренно короткая:

1. **Attention** — решения человека, делегируемая агентская работа и принятые риски;
2. **Explore** — `Claims / Proof graph / Scope`;
3. **Evidence** — история наблюдений и provenance.

Полный proof graph остаётся мощным инструментом исследования, но не занимает место первого экрана. Распределение всех claim states и mosaic находятся внутри Claims.

Claim detail дополнительно показывает **Decision boundary**: какие условия проверяет машина, где требуется человек, какой waiver действует и что агент может сделать без решения владельца.

## Работа с агентом

Кнопка **Copy brief for agent** копирует в локальный clipboard структурированный brief:

- claim, canonical state и source;
- почему пункт требует внимания;
- какое решение остаётся за человеком;
- что агент может исследовать или исправить;
- прямой запрет самостоятельно записывать review/waiver и ослаблять verifier/control.

Brief не отправляется провайдеру, plugin не создаёт агента и не отправляет prompt без действия человека.

## Граница доверия

Единственный источник verdict и состояний claim — результат:

```sh
mathc --root ROOT map --json
```

Плагин не пересчитывает freshness, independence, control reach или композицию `all`/`any`. Наблюдение `pass` не становится `holds`, waiver не становится green, а `not-run` не становится `refuted`.

`spec.json` и `.math/v5/evidence.jsonl` дают только содержимое для объяснения карты. Набор claim IDs, goal и числовые границы map/spec должны совпадать. Неизвестная схема, повреждённый JSONL, изменившийся во время чтения проект или несогласованный verdict/exit дают явную ошибку без fallback к прежнему green.

Корень проекта определяется server-side по `workspaceId` через Paseo SDK. Client не передаёт произвольный filesystem path. Процессы запускаются через argv без shell interpolation, с timeout и ограничением вывода.

По умолчанию используется `mathc` из `PATH`. Явный override обязан быть абсолютным путём и сообщать `mathc 5`. Автоматический выбор локального `_build` бинаря запрещён: смена бинаря меняет environment fingerprint и может сделать прежнее evidence устаревшим.

**Run checks** выключен по умолчанию. После явного разрешения в Settings кнопка требует второго подтверждения, выполняет объявленные проектом verifier/control commands и записывает evidence. Разрешение в Settings и UI-подтверждение защищают от случайного запуска, но не являются аутентификацией доверенного plugin-кода.

Операции одного workspace сериализованы. Очередь ограничена: если workspace занят длинным run, новый snapshot получает явную ошибку вместо бесконечного накопления запросов.

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

`test:render` собирает entry points, panel и все представления с fixture в light/compact вариантах. `test:negative` изменяет только временные копии plugin и доказывает, что проверки ломаются при неверной обработке canonical exit, рассогласовании map/spec, пропуске повреждённого JSONL, выдумывании dependency edges, принятии unsupported schema, автоматическом запуске checks, обходе запрета Run checks и делегировании изменённого источника агенту.

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
