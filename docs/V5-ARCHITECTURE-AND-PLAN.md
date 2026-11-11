# V5: архитектура и реализация

## Решение

Выбрана **clean-slate v5 в `main`**, а не orphan. Прежние реализации, ветки,
теги, worktree и установленные бинари удалены.

Это не эволюция с двумя реализациями в одном дереве. Старые состояния
остаются только в истории Git. Новые модули написаны с нуля, а дефекты и
знания перенесены как сценарии.

## Почему не постепенное сосуществование

- Прежний монолитный `bin/mathc.ml` содержал 2754 строки и почти все обязанности.
- Ядро и codec достигли потолков 798/800 и 399/400.
- Claim/evidence не имели SourceRef, environment и independence.
- Controls работали через изменение живого дерева.
- MCP и stand измеряли не ту поверхность.
- Старые тесты закрепляли бы старую семантику.

Переносить нужно свойства и сценарии, а не большие файлы.

## Модель

```text
ADR / specification / task
          ↓ SourceRef + source digest + section
      obligation
          ↓ scope + acceptance + phase + independence
          code
          ↓ materials + definition + verifier + environment
        evidence
          ↓
     gap → run / waiver / re-evaluation
```

`ExecutionLog` о стоимости отделён от `Evidence` о правильности.

## Структура

- `lib/domain.ml` — типы и canonical digests.
- `lib/freshness.ml` — чистые freshness rules.
- `lib/verdict.ml` — состояния и агрегация.
- `format/json_helpers.ml` — строгие JSON predicates.
- `format/spec.ml` — единственный строгий формат spec v5.
- `format/evidence.ml` — evidence codec.
- `adapter/` — Git, processes, source/ADR/JUnit, isolated runs.
- `bin/` — маленький dispatch, отдельные commands, справка, MCP, stand.
- `test/` — свойства и accepting/rejecting fixtures.

## Этапы

### M0. Baseline

- Старые исполняемые версии и archive refs удалены.
- Каталог дефектов и измерение независимого onboarding сохранены как данные.
- Зафиксированы benchmark и границы.

### M1. Ядро и форматы

- Типы, verdict/freshness, spec/evidence codecs.
- Fingerprint среды сравнивается точно; `judgment` требует внешний review.
- Строгие ошибки, никаких молчаливых fallback.
- Пустое состояние — `vacant`.

### M2. Пользовательский цикл

- `init`, `goal`, `add`, `run`, `map`, `next`, `waive`.
- Read-only map/next/context.
- Per-command help доступен без spec.json.

### M3. SourceRef и ADR

- MADR/adr-tools detection и read-only import через `omd`.
- `source_changed` при изменении ADR.
- `acceptance.all` и `acceptance.any` сохраняются.
- Нет автоматической активации и placeholder scope.

### M4. Evidence и waiver

- Все digests и environment/producer/run; права файла входят в materials digest.
- Paths ограничены проектом, symlink не попадает в snapshot.
- JUnit через `xmlm`.
- Waiver с expiry/recovery, без превращения fail в pass.
- Controls — независимые копии, без restore живого дерева.

### M5. Re-evaluation и agent surface

- Текущая реализация вычисляет pending по изменённому source, claim и
  evidence. Полный граф зависимостей между ADR — отдельная следующая работа,
  с rejecting fixtures; он не заявлен как реализованный.
- `review-source` сохраняет автора, причину и прежний digest, очищает waiver;
  свежий `run` обязателен и автоматический green запрещён.
- Protected transitions требуют policy и явной авторизации.
- Текущий MCP: protocol negotiation, JSON-RPC/schema validation, outputSchema,
  structuredContent и structured errors.
- Context capsule и маленький основной цикл; `--help` доступен без spec.json.
- Покрытие ограничено scope цели и не считает служебные файлы методом.

### M6. Пилот и поставка

- Чистый clone, все тесты, portable smoke вне Nix store.
- `install.sh` проверяет кандидатов до атомарной замены static `mathc`,
  `mathc-stand`, build-id и user-scope skill; rollback при failed upgrade
  сохраняет прежний бинарь.
- MADR, no-ADR, weak-checks и handoff projects.
- Независимый агент проходит onboarding только по установленному skill.
- CI: быстрые проверки и отдельный cached portable/self-run job.
- Три руки: agent, checklist, v5 — внешний benchmark ещё предстоит выполнить;
  текущие unit/integration checks его не заменяют.
- Решение принимается по внешнему результату, не по числу claims.

## Definition of done этапа

- `.mli` и типы соответствуют коду.
- Accepting/rejecting fixtures доказали силу.
- `git diff --check`, build и forced tests зелёные.
- Реальный пользовательский сценарий проверен бинарём.
- Документация не описывает старое поведение.
- Нет параллельной модели или скрытого runtime fallback.
- Пакет и doctor проверены там, где это затронуто.

## Stop rules

- Известный ложный `green` — стоп релиза.
- Потеря пользовательского дерева — стоп исполнения controls.
- Два независимых отрицательных пилота против чек-листа — упрощение,
  а не добавление новых механизмов.
