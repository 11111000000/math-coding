# Установка math-coding

> Четыре пути к рабочему бинарнику `mathc`. Выберите тот,
> что соответствует вашему окружению; все четыре поставляют
> один и тот же release-артефакт, идентифицируемый по SHA-256.

math-coding поставляется в виде четырёх независимых каналов
установки. Каждый канал — это один и тот же бинарь `mathc`,
опубликованный из одной сборки; каналы различаются тем, как
бинарь попадает на хост и какую часть окружения хоста канал
предполагает.

## Выберите канал

| Канал | Когда использовать | Команда установки |
|---|---|---|
| Release binary | По умолчанию. Linux glibc ≥ 2.35, macOS или WSL. | `curl -fsSL https://github.com/11111000000/math-coding/releases/download/edge/install.sh \| sh` |
| Docker image | Нет sudo, нет записи в `~/.local/`, ограниченный CI-раннер или нужен герметичный запуск. | `docker run --rm -v "$PWD:/repo" ghcr.io/11111000000/mathc:edge validate decisions/foo.yaml` |
| Nix run | У вас есть Nix ≥ 2.18 с включёнными flakes, и вы предпочитаете zero-install. | `nix run github:11111000000/math-coding -- validate decisions/foo.yaml` |
| Source build | Вы модифицируете `lib/` или `bin/`. | `nix develop .#test && dune build --root . bin/mathc.exe` |

Release binary — рекомендованный канал по умолчанию по двум
причинам: (a) скрипт установки проверяет SHA-256 скачанного
бинарника против `SHA256SUMS`, опубликованного в том же
релизе — это защита от MITM в сети; (b) скрипт также
устанавливает per-user opencode-скилл в той же инвокации
(`--user-skill`).

## Для AI-агентов

Существуют два пути установки скиллов для агентов, зеркально
двум каналам бинарника:

- **Per-repo** (в репозитории): скопируйте
  `dist/adoption/opencode/SKILL.md` (из `dist-adoption.tar.gz`
  релиза) в `.opencode/skills/math-coding/SKILL.md` целевого
  репозитория. Это привязывает конкретную версию
  math-coding к агентским сессиям этого репо.

- **Per-user** (на хосте): передайте `--user-skill` в
  `install.sh`. Скилл попадает в
  `${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/math-coding/SKILL.md`
  и применяется ко всем opencode-сессиям на хосте во всех
  репозиториях. После релиза перезапустите с `--upgrade`.

Per-repo путь — документированный production-контракт: поле
`compatible_with: mathc@>=X.Y.Z` в frontmatter скилла
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
проверяет один decision-файл по схеме; код выхода — 0 при
accept, 1 при reject, 2 при input error.

## Миграция с предыдущей версии

Повторный запуск `install.sh` на хосте, где уже есть `mathc`,
— no-op, когда версия совпадает (`install.sh --check`
возвращает 0). Когда версия различается, скрипт перезаписывает
бинарь на месте; per-user скилл перезаписывается только с
`--user-skill --upgrade`.

Для per-repo скиллов скопируйте новый
`dist/adoption/opencode/SKILL.md` в
`.opencode/skills/math-coding/SKILL.md` проекта. Version
pin в frontmatter — задокументированный источник истины о
том, «против какого релиза был автором этот репо».

## Заметки о песочницах

На NixOS сборки по умолчанию через `flake.nix` производят
`mathc`, слинкованный с
`/nix/store/<hash>-glibc-2.42`. Этот бинарь не запустится на
хостах с системным glibc старше 2.42. Pipeline релизов
собирает через system opam на Ubuntu 22.04; выпускаемые
бинарь слинкованы с glibc раннера и портативны на системах
с glibc 2.35+. Поставляемый `install.sh` намеренно не
доверяет локально собранному бинарю; он скачивает из релиза.

Для Alpine (musl-libc) отдельный вариант
`mathc-linux-x86_64-musl` поставляется как release asset с
версии v3.2.0-alpha; musl Docker-образ отложен до
следующего цикла (см. `decisions/docker-alpine-impl-pending.yaml`).
До тех пор пользователи Alpine скачивают musl-бинарь
напрямую из `assets/` релиза.

## Интеграция через MCP

`mathc` поставляется вместе с компаньоном `mathc_mcp` — JSON-RPC 2.0 сервером по stdio.
Сервер экспонирует 11 методов `mathc/<name>`:

`mathc/validate`, `mathc/explain`, `mathc/packages`, `mathc/mode`,
`mathc/re-evaluate`, `mathc/rebuttals`, `mathc/self-check`,
`mathc/gate`, `mathc/attest`, `mathc/record`,
`mathc/re-evaluate-decisions`.

Read-only методы перечислены в
`decisions/mcp-server-impl-2026-10.yaml`, read-write методы — в
`ux-3-mcp-read-write-2026-10.yaml`. Обе категории
эмитятся из одного allowlist в `lib/mcp/dispatch.ml`.

Протокол: один JSON-RPC запрос на строку stdin, один ответ на
строку stdout. stderr зарезервирован для диагностики сервера.
EOF на stdin приводит к чистому выходу с кодом 0.

Запуск сервера напрямую:

  $ ~/.local/bin/mathc_mcp     # читает JSON-RPC из stdin, пишет в stdout

MCP-aware агент (opencode, Claude Code, Cursor) может запустить
этот бинарь как stdio MCP-сервер. Агент увидит `mathc::validate`
и другие методы как прямые вызовы tools, без обращения через `bash`.

## AI-агенты

Агент в opencode/Claude Code/Cursor может либо запустить `mathc`
через `bash`, либо подключиться к `mathc_mcp` через JSON-RPC stdio
(см. §"Интеграция через MCP" выше).

## См. также

- `adoption/SKILL.md` — канонический скилл агента.
- `USAGE.md` — runbook адопшна (установка бинарника + первое
  решение).
- `decisions/install-tooling-2026-10.yaml` — решение,
  вводящее эти четыре канала.
- `OCAML_BEST_PRACTICES.md` §11.28 (дисциплина флага `-fSL`
  в `curl | sh` install-скриптах).