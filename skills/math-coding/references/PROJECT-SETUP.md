# Установка и подключение проекта

Семантика метода полностью определена в `references/METHODOLOGY.md`. Здесь
находятся только установка, команды и ограничения текущего CLI.

## Одна команда на сервере

Из каталога исходников math-coding:

```sh
./install.sh
```

Устанавливаются без sudo:

- `~/.local/bin/mathc` — статический бинарь v5;
- `~/.local/bin/mathc-stand` — измеритель, который находит `mathc` рядом;
- `~/.local/bin/mathc.build-id` — версия и SHA-256 бинаря;
- `~/.agents/skills/math-coding/` — user-scope skill для других агентов,
  включая `references/METHODOLOGY.md` и это руководство.

Nix нужен только для сборки. Для запуска нужны системные Git, POSIX shell и
команды, объявленные проектом как verifiers. OCaml/Nix runtime не требуется.

Если `~/.local/bin` отсутствует в `PATH`, установщик напечатает нужный `export`.
Не копируйте его в shell-конфигурацию без проверки пути.

Повторный запуск идемпотентен. Изменённый существующий файл не перезаписывается
без явного решения:

```sh
./install.sh --force
```

Каждый заменённый файл сохраняется как `ИМЯ.backup`, а при совпадении имени —
как `ИМЯ.backup.PID`. Старые `mathc.backup-*` и другие файлы не трогаются.

Другие каталоги:

```sh
./install.sh --bin-dir /custom/bin --skill-dir /custom/skills/math-coding
```

Те же пути задают `MATHC_INSTALL_DIR` и `MATHC_SKILL_DIR`. Для offline/CI можно
указать уже собранный portable package через `MATHC_PACKAGE`.

## Подключение проекта

Команды выполняются из корня существующего Git-репозитория. Вместо смены cwd
можно передать `--root /absolute/path/to/project` любому глаголу.

```sh
mathc --help
mathc adopt
mathc init
mathc goal "Критичные свойства подтверждаются свежими проверками" \
  "src/,test/" "owner"
mathc add parser "parser accepts the documented format" \
  "src/parser.ml,test/parser.ml" "a rejecting fixture is accepted" fact \
  --requirement "verifier:dune runtest --root . --force test/parser.exe" \
  --control "sed -i 's/expected/broken/' test/parser.ml"
mathc run
mathc map
mathc next
mathc install
mathc doctor
```

Имена путей, владельца и команды замените на реальные. `init` выполняйте только
если `spec.json` отсутствует. Цель и владельца задаёт человек. Не переносите
пример control без проверки: он должен менять предмет claim и ломать проверку.

`mathc install` записывает только блок между `math-coding:begin/end` в
`AGENTS.md`; остальная страница сохраняется. `doctor` ничего не исправляет.

## Работа с ADR

`mathc adopt` перечисляет типичные каталоги MADR/adr-tools/arc42. Он не
импортирует их автоматически. `mathc import-adr PATH` печатает черновик и не
меняет источник или спецификацию. Активный claim объявляется явно:

```sh
mathc add storage "the storage decision is implemented" \
  "src/storage.ml,test/storage.ml" "the decision is contradicted" fact \
  --requirement "verifier:dune runtest --root . --force test/storage.exe" \
  --control "printf broken > src/storage.ml" \
  --source docs/adr/0001-storage.md
```

После изменения ADR `map` покажет `source changed` и `outdated`. Пересмотрите
решение, затем выполните:

```sh
mathc review-source storage --by owner --reason "reviewed the superseding ADR"
mathc run
mathc map
```

Не редактируйте digest вручную. Пересмотр не заменяет свежую проверку кода.

## Справка и измеритель

Для точной справки по глаголу используйте `mathc help COMMAND`, например
`mathc help add`, `mathc help run`, `mathc help review-source`. Общий
`mathc --help` перечисляет коды выхода и основной цикл.

`mathc-stand --help` описывает колонки измерения и все стоимостные параметры.
Короткий пример:

```sh
mathc-stand /absolute/path/to/project \
  --human-minutes 30 --agent-tokens 10000 \
  --person-minute-cost 1 --machine-second-cost 0.01 --token-cost 0.0001 \
  --defect-cost 100
```

Без пяти базовых стоимостных параметров ratio не вычисляется. Критерий также
требует `--defect-cost` и хотя бы одного пойманного дефекта; иначе инструмент
честно печатает, что критерий не вычислим.

## Исполняемый профиль

`fact`, `hypothesis` и `unknown` используют одни evidence rules; регистр не
снижает требования. `judgment` требует `review:WHO` и внешнего human review.
Fingerprint текущей среды должен совпадать с evidence, поэтому смена lock-файла,
toolchain или бинаря требует нового `run`.

Scope и source paths относительны к проекту и не могут быть absolute, `..` или
symlink. `Any` прекращает исполнение после первого успеха. `All` останавливается
на `fail`, но после inconclusive/infrastructure/not-run выполняет остальные
ветви, чтобы сохранить возможное позднее опровержение.

Verifier без control получает `not-run` контроля и `inconclusive`, не `refuted`.
`mathc add` создаёт `acceptance/pre-merge` с пустым `review_on`. Стандартный
`waive` принимает автора, причину, срок и recovery; compensating controls и
review triggers остаются пустыми. Эти ограничения не нужно обходить ручным
редактированием ради зелёного результата.

## Границы

- Green означает, что объявленные claims имеют текущие доказательства, а не что
  программа доказана полностью. Смотрите `uncovered` и `next`.
- Evidence в `.math/v5/` локальны и не попадают в Git. В новом clone запустите
  проверки заново.
- Не исполняйте незнакомые verifier/control-команды из чужого репозитория без
  ревизии: это shell-команды проекта.
- `record`, `waive`, `authorize`, `review-source` — журналы решений, а не
  криптографическая аутентификация или защита от владельца файлов.
