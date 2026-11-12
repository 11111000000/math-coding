# math-coding v5

Слой проверки связей между требованиями, решениями, кодом и доказательствами.
Показывает, что подтверждено, что устарело, что остаётся неизвестным и какая
часть заявленной области не покрыта.

## Методология

Самостоятельное нормативное описание:
**[Math Coding: методология связанных, свежих и проверяемых доказательств](skills/math-coding/references/METHODOLOGY.md)**.
Оно не требует знания истории проекта и определяет понятия, протокол,
вердикты, человеческие решения, рабочий цикл и границы применимости.

Карта остальных документов:

- `GOAL.md` — назначение, гипотеза пользы и критерии измерения.
- `PHILOSOPHY.md` — принципы и их мотивировка.
- `AXIOMS.md` — точный контракт текущей реализации и ограничения CLI.
- `docs/ENGINEERING-PRACTICES.md` — обязательные инженерные правила.
- `docs/V5-ARCHITECTURE-AND-PLAN.md` — архитектура, этапы и история решений.
- `docs/V5-DEFECT-CATALOG.md` — отрицательные сценарии и safety case.
- `docs/measurements/` — универсальный протокол измерения, валидатор ledger и
  синтетические fixtures, не нормы метода. Полевые данные — инвентаризация
  интеграции, журналы задач, сравнения и отчёты — ведутся во внешнем
  репозитории лаборатории, отдельно от этого репозитория.

## Установка

Из каталога исходников:

```sh
./install.sh
```

Без sudo устанавливаются статические `~/.local/bin/mathc` и
`~/.local/bin/mathc-stand`, `mathc.build-id` и user-scope skill в
`~/.agents/skills/math-coding`. Вместе со skill устанавливаются руководство по
подключению и полная методология. Nix нужен только для сборки; для запуска
нужны системные Git, POSIX shell и проектные verifier-команды.

Повторная установка идемпотентна. Чужой или изменённый файл не перезаписывается
без явного `./install.sh --force`; заменяемые файлы сохраняются как `*.backup`.
Другие пути задаются `--bin-dir`, `--skill-dir` или переменными
`MATHC_INSTALL_DIR` и `MATHC_SKILL_DIR`. `MATHC_PACKAGE` выбирает уже собранный
portable package.

Проверка установки:

```sh
mathc --version             # ожидается mathc 5
mathc --help
mathc help add
```

Полное руководство: `skills/math-coding/references/PROJECT-SETUP.md`.

## Подключение проекта

Внутри существующего Git-репозитория:

```sh
mathc adopt
mathc init                    # только если spec.json отсутствует
mathc goal "ЦЕЛЬ" "src/,test/" "ВЛАДЕЛЕЦ"
mathc add ID "ТРЕБОВАНИЕ" "src/file.ml,test/file.ml" "ОПРОВЕРЖИТЕЛЬ" fact \
  --requirement "verifier:КОМАНДА_ПРОЕКТА" \
  --control "КОМАНДА_ЛОМАЕТ_ПРЕДМЕТ"
mathc run
mathc install
mathc doctor
```

Вместо смены каталога можно передать `--root /absolute/path`. Цель и владельца
задаёт человек. В scope claim включаются и предмет, и файлы проверки.

`run` выполняет verifier на кандидате и negative control в изолированной копии,
затем показывает текущие verdict, состояния, `uncovered` и одно следующее
действие; `run --json` отдаёт ту же карту в JSON. Машинный `holds` требует
свежего `pass`, достаточной независимости и контроля, который изменил предмет и
заставил verifier отклонить изменение.

`Green` означает, что все объявленные claims имеют `holds`. Он не означает
полное покрытие или доказательство правильности программы; смотрите `uncovered`
и `next`.

## Источники и человеческие решения

`adopt` и `import-adr` read-only. Активное обязательство объявляется явно через
`add --source PATH`. Изменение источника требует реального пересмотра и нового
запуска:

```sh
mathc re-evaluate
mathc review-source ID --by ВЛАДЕЛЕЦ --reason "ПРИЧИНА_ПЕРЕСМОТРА"
mathc run
```

Пересмотр сохраняет автора, причину, время и прежний digest, очищает waiver и
не переписывает источник.

- `record` фиксирует фактически выполненное человеческое review для объявленного
  `review:AUTHORITY`.
- `waive` фиксирует ограниченный по сроку риск; это не `pass` и не покрытие
  `fail`.
- `authorize` записывает разрешение защищённого перехода по `policy.json`.
- Эти команды ведут журнал решений, а не аутентифицируют личность.
- `install` обновляет только маркированный блок `AGENTS.md`; `doctor` проверяет
  настройку без исправлений.

Коды выхода: `0` — green/успешное действие, `1` — red/защищённый отказ, `2` —
ошибка вызова, `3` — unknown/vacant/uncomputable. Точную справку показывает
`mathc help COMMAND`.

## Разработка

```sh
nix develop
dune build --root .
dune runtest --root . --force
./_build/default/bin/mathc.exe --root . map
./_build/default/bin/mathc.exe --root . next
```

Пакеты: `nix build .#default`, `nix build .#stand`, `nix build .#portable`.
Проверки поставки:

```sh
sh test/package_smoke.sh
sh test/package_smoke.sh portable
sh test/agent_onboarding.sh
```

Для `agent_onboarding.sh` используются `MATHC` и `MATHC_STAND`; точную команду
показывает self-run claim `external-onboarding` в `spec.json`.

Сайт генерируется из исходных страниц, спецификации и живой карты:

```sh
sh site/build.sh
sh site/check.sh
```

`site/dist` является игнорируемым результатом сборки.

## Текущий статус

Unit, integration, package и onboarding checks проверяют реализацию, но не
доказывают рост эффективности разработки. Внешнее сравнение трёх рук — обычная
работа, чек-лист и полный протокол — ещё не выполнено. Его самостоятельный
протокол находится в `docs/measurements/BENCHMARK-PROTOCOL.md`.

Полный граф зависимостей ADR остаётся отдельной работой. Evidence локальны и не
попадают в Git; в новом clone проверки выполняются заново.
