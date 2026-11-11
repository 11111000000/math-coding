# math-coding v5

Слой проверки связей между ADR и спецификациями, обязательствами, кодом и
доказательствами. Показывает, что подтверждено, что устарело и что остаётся
неизвестным.

## Статус

Активная и единственная реализация — v5 в `main`. Старые код, ветки, теги,
worktree и установленные бинари удалены; прежние состояния остаются только
в истории Git.

- `GOAL.md` — ценность и критерий пользы.
- `PHILOSOPHY.md` — десять принципов.
- `AXIOMS.md` — исполняемая модель.
- `docs/ENGINEERING-PRACTICES.md` — обязательные инженерные правила.
- `docs/V5-ARCHITECTURE-AND-PLAN.md` — архитектура и этапы.
- `docs/V5-DEFECT-CATALOG.md` — обязательные сценарии отказов.
- `docs/measurements/` — измерения текущей v5.

## Установка для других проектов и агентов

Из этого каталога выполните одну команду:

```sh
./install.sh
```

Без sudo устанавливаются статические `~/.local/bin/mathc` и
`~/.local/bin/mathc-stand`, `mathc.build-id` и user-scope skill в
`~/.agents/skills/math-coding`. Nix нужен только для сборки, для запуска нужны
системные Git, POSIX shell и проектные verifier-команды. Если каталога нет в
`PATH`, установщик печатает нужный `export`.

Повторная установка идемпотентна. Если уже установлен другой `mathc`, сначала
проверьте его: `./install.sh` откажется перезаписывать чужой файл. Явное
`./install.sh --force` разрешает обновление и сохраняет прежние файлы как
`*.backup`. Проверьте `mathc --version`: ожидается `mathc 5`.

Другие пути задаются `--bin-dir`, `--skill-dir` или переменными
`MATHC_INSTALL_DIR` и `MATHC_SKILL_DIR`. `MATHC_PACKAGE` позволяет установить
уже собранный portable package без обращения к Nix.

Подключение существующего Git-проекта:

```sh
cd /path/to/project
mathc --help
mathc help add
mathc adopt
mathc init                    # только если spec.json отсутствует
mathc goal "ЦЕЛЬ" "src/,test/" "ВЛАДЕЛЕЦ"
mathc add ID "ТРЕБОВАНИЕ" "src/file.ml,test/file.ml" "ОПРОВЕРЖИТЕЛЬ" fact \
  --requirement "verifier:КОМАНДА_ПРОЕКТА" \
  --control "КОМАНДА_ЛОМАЕТ_ПРЕДМЕТ"
mathc run
mathc map
mathc install
mathc doctor
```

Вместо `cd` можно передавать `--root /absolute/path`. Цель и владельца задаёт
человек. Полное руководство находится в
`skills/math-coding/references/PROJECT-SETUP.md`; новые агенты получают его
вместе с user-scope skill.

## Разработка

```sh
nix develop
dune build --root .
dune runtest --root . --force
./_build/default/bin/mathc.exe --root . map
./_build/default/bin/mathc.exe --root . next
```

Основной цикл: `init → goal → add → run → map/next`. ADR импортируется
только read-only и никогда не активирует обязательство автоматически.

## Связь с ADR и пересмотр

`import-adr PATH` печатает черновик и не меняет ни ADR, ни `spec.json`.
`adopt` только перечисляет обнаруженные источники. После ревью человек
объявляет активное обязательство явно:

```sh
mathc add ID "ТРЕБОВАНИЕ" SCOPE "ОПРОВЕРЖИТЕЛЬ" fact \
  --requirement "verifier:КОМАНДА" \
  --control "КОМАНДА_ЛОМАЕТ_ПРЕДМЕТ" \
  --source docs/adr/0001-decision.md
```

`--source` сохраняет digest существующего файла, но не включает ADR в scope
и ничего в него не пишет. Изменение ADR даёт `source_changed`, переводит
обязательство в `outdated` и отменяет зелёный вердикт до пересмотра.
`re-evaluate` печатает JSON-список `needs_re_evaluation`, а `next` подсказывает
команду пересмотра:

```sh
mathc review-source ID --by ВЛАДЕЛЕЦ --reason "ПРИЧИНА_ПЕРЕСМОТРА"
mathc run
mathc map
```

`review-source` сохраняет автора, причину, время и прежний digest, очищает
waiver и не переписывает ADR. Он не подтверждает код: старые доказательства
остаются устаревшими, поэтому `run` обязателен. Как и другие человеческие
решения, это журнал владельца, а не аутентификация.

## Регистры, среда и пути

`fact` и `hypothesis` могут подтверждаться verifier'ом. `judgment` требует
`review:WHO` и внешнего человеческого review; machine-only judgment не
устанавливается. Fingerprint среды должен совпадать с evidence: смена
toolchain или lock-файла делает evidence устаревшим.

Scope и source paths относительны к проекту и не могут быть absolute, `..` или
symlink. `Any` прекращает исполнение после первого успешного варианта, а `All`
останавливается на первом неуспехе. Ошибки Git, setup и truncation stdout не
выдаются за пустое покрытие или успешную проверку.

## Человеческие решения и границы

- `record ID AUTHORITY --by WHO --outcome OUTCOME` записывает человеческий
  review только для объявленного требования `review:AUTHORITY`. Допустимы
  `pass`, `fail`, `inconclusive`, `infrastructure-error`, `not-run`.
- `waive ID --by WHO --reason WHY --valid-for DAYS --recovery ACTION`
  фиксирует ограниченный по времени риск; это не `pass` и не покрывает `fail`.
- `authorize --by WHO --reason WHY` действует только при наличии
  `policy.json` и подтверждает текущие защищённые изменения указанным в
  политике лицом. Это журнал разрешения, а не система аутентификации.
- `install` обновляет только маркированный блок в `AGENTS.md`; `doctor`
  проверяет настройку без исправлений.

Коды выхода: `0` — green или успешное действие, `1` — red/запрет защищённого
перехода, `2` — ошибка вызова, `3` — unknown/vacant или невозможность вычислить
состояние. Точные коды по глаголу показывает `mathc help COMMAND`.
Повреждённый след доказательств не игнорируется и не считается отсутствием
доказательств.

Пакеты: `nix build .#default`, `nix build .#stand`, `nix build .#portable`.
`.#stand` включает рядом `mathc`, поэтому не требует ручной настройки `MATHC`.
`mathc-stand --help` описывает колонки и стоимостные параметры.

```sh
sh test/package_smoke.sh
sh test/package_smoke.sh portable
```

Smoke создаёт временный проект и проверяет реальный цикл, `stand`, `install` и
`doctor`. Portable-проверка дополнительно требует static ELF, отсутствие
динамического loader, вызывает `install.sh` в отдельные каталоги и использует
установленные `mathc`/`mathc-stand` и skill вне Nix store. Для работы с
репозиторием по-прежнему нужны системные `git`, POSIX shell и команды, которые
проект сам объявил verifier'ами: portable убирает зависимость от OCaml/Nix
runtime, а не от проверяемого инструментария проекта.

Граница текущего статуса: unit/integration/package checks не доказывают рост
эффективности разработки. Трёхрукий внешний benchmark (агент, чек-лист, v5)
ещё не выполнен; полный граф зависимостей ADR остаётся отдельной работой.
