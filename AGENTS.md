# AGENTS.md — math-coding v5

Активная и единственная линия — v5 в `main`. Старые реализации, ветки, теги,
worktree и бинари удалены. Не возвращай старый код без сценария и
отрицательного контроля.

Для использования в других проектах запусти `./install.sh`: бинари попадут в
`~/.local/bin`, user-scope skill — в `~/.agents/skills/math-coding`. Существующий
другой CLI не перезаписывай без разрешения человека; `./install.sh --force`
сохраняет прежние файлы как `*.backup`. `mathc --version` должен печатать
`mathc 5`. Руководство — `skills/math-coding/references/PROJECT-SETUP.md`.

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

Цель и владельца задаёт человек. `mathc --help` работает и до создания
спецификации, `mathc help COMMAND` описывает отдельный глагол. Дополнительные
глаголы: `context`, `waive`, `record`, `install`, `doctor`, `adopt`,
`import-adr`, `import-junit`, `authorize`,
`re-evaluate`, `review-source`, `mcp`. У `add` необязательный `--source PATH`
привязывает существующий ADR по digest, не изменяя его. `source_changed`
означает `outdated`, а не green. `review-source ID --by ВЛАДЕЛЕЦ --reason WHY`
сохраняет ревизию и прежний digest, очищает waiver; после него обязателен новый
`run`. `record --outcome` принимает только пять значений домена. `authorize` не
работает без `policy.json`; это журнал, не аутентификация.

## Запреты

- Не добавлять параллельную модель или старую реализацию рядом с новой.
- Не использовать `filter_map` для потери ошибок формата.
- Не писать свои YAML/XML/Markdown-парсеры.
- Не менять живое дерево при `map`, `next`, `context` и controls.
- Не выдавать `Holds` без свежести, control reach `subject` и независимости.
- Не принимать evidence иной версии и не повышать доверие fallback'ом.
- Не добавлять команды и поля без accepting/rejecting fixtures.

После изменений проверь `git diff --check`, сборку, все тесты и фактический
сценарий пользователя. Не коммить и не публикуй без явного разрешения.

<!-- math-coding:begin -->
## math-coding in this project

v5 keeps evidence linked, fresh, and independent

12 claim(s).

```sh
mathc map
mathc next
mathc context
mathc run
```

Every verb: mathc help mathc init mathc goal mathc add mathc run mathc map mathc next mathc context mathc waive mathc record mathc install mathc doctor mathc adopt mathc import-adr mathc import-junit mathc authorize mathc re-evaluate mathc review-source mathc mcp
<!-- math-coding:end -->
