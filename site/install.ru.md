# Установка math-coding

> Четыре пути к рабочему бинарнику `mathc`. Выберите
> тот, что соответствует вашему окружению; все четыре
> поставляют один и тот же release-артефакт,
> идентифицируемый по SHA-256.

math-coding поставляется в виде четырёх независимых
каналов установки. Каждый канал — это один и тот же
бинарь `mathc`, опубликованный из одной сборки; каналы
различаются тем, как бинарь попадает на хост и какую
часть окружения хоста канал предполагает.

## Выберите канал

> Нативные каналы в первую очередь; Docker — резерв. Если ни один нативный канал не работает, см. [Если нативная установка не работает](#если-нативная-установка-не-работает) ниже.

| Канал | Когда использовать | Команда установки |
|---|---|---|
| Release binary | По умолчанию. Linux glibc ≥ 2.35, macOS или WSL. | `curl -fsSL https://github.com/11111000000/math-coding/releases/download/v${VERSION}/install.sh \| sh` |
| Docker image | Нет sudo, нет записи в `~/.local/`, ограниченный CI-раннер или нужен герметичный запуск. | `docker run --rm -v "$PWD:/repo" ghcr.io/11111000000/mathc:${VERSION} validate decisions/foo.yaml` |
| Nix run | У вас есть Nix ≥ 2.18 с включёнными flakes, и вы предпочитаете zero-install. | `nix run github:11111000000/math-coding -- validate decisions/foo.yaml` |
| Source build | Вы модифицируете `lib/` или `bin/`. | `nix develop .#test && dune build --root . bin/mathc.exe` |

Release binary — рекомендованный канал по умолчанию по
двум причинам: (a) скрипт установки проверяет SHA-256
скачанного бинарника против `SHA256SUMS`, опубликованного
в том же релизе, — это защита от MITM в сети; (b) скрипт
также устанавливает per-user opencode-скилл в той же
инвокации (`--user-skill`).

## Если нативная установка не работает

Если `curl | sh`, Windows-установщик, `nix run` или
сборка из исходников не работают на вашем хосте
(корпоративный прокси блокирует `raw.githubusercontent.com`,
Alpine/musl libc, иммутабельный CI-раннер без доступа на
запись в `~/.local/`), Docker-образ — это всегда
доступный резервный канал. Образ
`ghcr.io/11111000000/mathc:<VERSION>` собирается и
подписывается CI этого репозитория при каждом push
тега релиза; установка на хост не требуется.

```sh
docker run --rm -v "$PWD:/repo" \
  ghcr.io/11111000000/mathc:<VERSION> \
  validate decisions/foo.yaml
```

Та же команда работает для любой подкоманды. Замените
`<VERSION>` на тег релиза (например, `v3.3.0`) или на
`edge` для самого свежего коммита в `main`. Тег `:edge`
пересобирается и публикуется при каждом push в `main`;
ежедневный healthcheck-workflow проверяет, что образ
по-прежнему запускается.

## Для AI-агентов

Существуют два пути установки скиллов агентов, зеркально
двум каналам бинарника:

- **Per-repo** (в репозитории): скопируйте
  `dist/adoption/opencode/SKILL.md` (из
  `dist-adoption.tar.gz` релиза) в
  `.opencode/skills/math-coding/SKILL.md` целевого
  репозитория. Это привязывает конкретную версию
  math-coding к агентским сессиям этого репо.

- **Per-user** (на хосте): передайте `--user-skill` в
  `install.sh`. Скилл попадает в
  `${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/math-coding/SKILL.md`
  и применяется ко всем opencode-сессиям на хосте во всех
  репозиториях. После релиза перезапустите с `--upgrade`.

Per-repo путь — документированный production-контракт:
поле `compatible_with: mathc@>=X.Y.Z` во вводной части
(`adoption/SKILL.md:188`) обеспечивает version pin.
Per-user путь — это удобство для «скаффолдинга нового
math-coding проекта»: `install.sh --user-skill --upgrade`
после каждого релиза поддерживает скилл в актуальном
состоянии.

## Проверка

После любой установки проверьте:

```bash
mathc version
mathc self-check
mathc validate decisions/<ваше-первое-решение>.yaml
```

`mathc version` печатает строку версии из бинарника.
`mathc self-check` запускает ядро против текущего
репозитория и сообщает pass/unknown/fail. `mathc validate`
проверяет один decision-файл по схеме; код выхода — 0
при accept, 1 при reject, 2 при input error.

## Скаффолдинг нового проекта

Когда `mathc` доступен в PATH, рекомендуемый путь
адопшна для нового проекта:

```bash
cd /path/to/new-project
mathc init .                 # скаффолдит decisions/, attestations/,
                              # decisions/decision.yaml, .githooks/
```

`mathc init` (решение `ux-3-init-subcommand-2026-10`):

- Создаёт `decisions/` и `attestations/` в целевом
  каталоге.
- Записывает `decisions/decision.yaml` с активной
  политикой (verbatim-копия шаблона install-tooling,
  `math-coding/3.2`).
- Устанавливает `.githooks/pre-commit` (если не
  указан `--no-install`).
- **Отказывает** при наличии `docs/arc42/`, `docs/adr/`
  или `adr/`, если не передан `--merge`. Сообщение
  об отказе называет обнаруженную конвенцию и
  указывает на `mathc import-adr` (ниже) как путь для
  brownfield.
- Флаги: `--agent` (размещение скилла на конкретной
  платформе, сейчас — no-op сверх валидации ввода),
  `--from-adr` (отложено), `--no-install`, `--merge`.

Для проекта с существующими MADR или adr-tools ADR
используйте `mathc import-adr` пофайлово (решение
`ux-3-import-adr-subcommand-2026-10`):

```bash
# Один файл (печатает YAML в stdout)
mathc import-adr docs/adr/0001-use-postgres.md

# Все MADR-файлы (записывает в decisions/<id>.yaml;
# ревьюер заполняет scope.paths[] до того, как mathc
# validate принимает)
for f in docs/adr/*.md; do
  mathc import-adr "$f" --write
done
```

## Миграция с предыдущей версии

Повторный запуск `install.sh` на хосте, где уже есть
`mathc`, — no-op, когда версия совпадает (`install.sh
--check` возвращает 0). Когда версия различается, скрипт
перезаписывает бинарь на месте; per-user скилл
перезаписывается только с `--user-skill --upgrade`.

Для per-repo скиллов скопируйте новый
`dist/adoption/opencode/SKILL.md` в
`.opencode/skills/math-coding/SKILL.md` проекта. Version
pin во вводной части — задокументированный источник истины
о том, «против какого релиза был автором этот репо».

## Заметки о песочницах

На NixOS сборки по умолчанию через `flake.nix` производят
`mathc`, слинкованный с `/nix/store/<hash>-glibc-2.42`.
Этот бинарь не запустится на хостах с системным glibc
старше 2.42. Конвейер релизов `release.yml` собирает
через system opam на Ubuntu 22.04; выпускаемые бинари
слинкованы с glibc раннера и портативны на системах с
glibc 2.35+. Поставляемый `install.sh` намеренно не
доверяет локально собранному бинарю; он скачивает из
релиза.

Для Alpine (musl-libc) отдельный вариант
`mathc-linux-x86_64-musl` поставляется как release asset с
v3.2.0-alpha; musl Docker-образ отложен до следующего
цикла (см. `decisions/docker-alpine-impl-pending.yaml`).
До тех пор пользователи Alpine скачивают musl-бинарь
напрямую из списка `assets/` релиза.

## См. также

- `adoption/SKILL.md` — канонический скилл агента.
- `USAGE.md` — runbook адопшна (установка бинарника +
  первое решение).
- `decisions/install-tooling-2026-10.yaml` — решение,
  вводящее эти четыре канала.
- `OCAML_BEST_PRACTICES.md` §11.28 (дисциплина флага
  `-fSL` в install-скриптах вида `curl | sh`).
