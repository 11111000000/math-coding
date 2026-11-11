# AGENTS.md — math-coding v5

Активная ветка: `feat/v5-clean-slate`. Прежняя реализация: `archive/v4` и
тег `v4-baseline`. Не импортируй старый код без сценария и отрицательного
контроля.

## Команды

```sh
nix develop
dune build --root .
dune runtest --root . --force
./_build/default/bin/mathc.exe --root . map
./_build/default/bin/mathc.exe --root . next
```

## Архитектура

- `lib/` — чистые типы и вычисления, без I/O.
- `format/` — строгие версионированные кодеки через библиотеки.
- `adapter/` — git, процессы, источники, изолированные проверки.
- `bin/` — маленький CLI, MCP и измеритель.
- `test/` — accepting и rejecting fixtures.
- `docs/lineage/v4/` — история, не активная спецификация.

Перед изменением прочти `docs/ENGINEERING-PRACTICES.md` и
`docs/V5-ARCHITECTURE-AND-PLAN.md`.

## Рабочий цикл

```sh
mathc init
mathc goal "ЦЕЛЬ" "SCOPE" "ВЛАДЕЛЕЦ"
mathc add ID "ТРЕБОВАНИЕ" "SCOPE" "ОПРОВЕРЖИТЕЛЬ" fact \
  --requirement "verifier:КОМАНДА" --control "ЛОМАЕТ_ПРЕДМЕТ"
mathc run
mathc map
mathc next
```

Дополнительные глаголы: `context`, `waive`, `record`, `migrate`, `install`,
`doctor`, `adopt`, `import-adr`, `import-junit`, `authorize`, `re-evaluate`,
`mcp`. У `add` необязательный `--source PATH` привязывает существующий ADR по
digest, не изменяя его. `source_changed` означает `outdated`, а не green;
`re-evaluate` перечисляет обязательный пересмотр, но не принимает новое решение
за человека. `record --outcome` принимает только пять значений домена.
`authorize` не работает без `policy.json`; это журнал, не аутентификация.

## Запреты

- Не добавлять параллельную модель или старую реализацию рядом с новой.
- Не использовать `filter_map` для потери ошибок формата.
- Не писать свои YAML/XML/Markdown-парсеры.
- Не менять живое дерево при `map`, `next`, `context` и controls.
- Не выдавать `Holds` без свежести, control reach `subject` и независимости.
- Не повышать доверие старым свидетельствам при миграции.
- Не добавлять команды и поля без accepting/rejecting fixtures.

После изменений проверь `git diff --check`, сборку, все тесты и фактический
сценарий пользователя. Не коммить и не публикуй без явного разрешения.

<!-- math-coding:begin -->
## math-coding in this project

v5 keeps evidence linked, fresh, and independent

9 claim(s).

```sh
mathc map
mathc next
mathc context
mathc run
```

Every verb: mathc init mathc goal mathc add mathc run mathc map mathc next mathc context mathc waive mathc record mathc migrate mathc install mathc doctor mathc adopt mathc import-adr mathc import-junit mathc authorize mathc re-evaluate mathc mcp
<!-- math-coding:end -->
