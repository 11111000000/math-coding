# math-coding

> Практика записывать решения перед кодом.

## Что это

math-coding — это практика, при которой proposition
записывается раньше, чем пишется код. Решение существует
как утверждение (тип по Curry-Howard), код — как его
реализация (терм), фиксация — как доказательство inhabitation.
Каждое нетривиальное архитектурное решение проекта становится
пакетом, проверяемым ядром.

Что math-coding делает с решением, когда решение проходит
через соглашение:

- **фиксирует утверждение** — proposition записывается в
  `packet.md` раньше, чем пишется код;
- **привязывает к коду** — через `witness` (SHA в git)
  утверждение и код становятся проверяемой связью;
- **проверяет ядром** — `mathc check` обнаруживает расхождение
  (изменение кода без обновления утверждения), структурные
  ошибки (пустое утверждение, нарушение автомата состояний,
  нарушения частичного порядка);
- **эволюционирует через замещение** — изменение утверждения
  порождает новый пакет, прежняя цепочка сохраняется как
  родословная;
- **фиксирует автора** — кто принял решение (человек, агент
  или система), с возможностью проверки через подписи;
- **требует осмотрительности** — для решений человека явно
  рассматривается возможный вред (обратимость, смягчение).

## Что внутри

Восемь пакетов. Около семисот строк на OCaml. Один бинарь.
Только текст и git. Без серверов, без баз данных, без
фреймворков.

- **curry-howard** — решение = (утверждение, код, фиксация)
- **temporal** — стадии вычисляются из истории git
- **constructive** — доказательство = повторный запуск и код выхода
- **categorical** — замещение = строгий частичный порядок
- **motivation** — регистр и обоснование; осмотрительность для решений человека
- **process-fsm** — три состояния, один запрещённый переход
- **dialectic-tas** — тезис, антитезис, синтез для суждений
- **actor-discipline** — подписи фиксируют, кто решил

Соглашение применяется к самому себе: основания — это пакеты,
проверяемые тем же ядром.

## Быстрый старт

```sh
mathc init
mathc record моё-решение "TTL = 60 секунд с ручной инвалидацией"
git add math/моё-решение/ && git commit -m "моё-решение: политика TTL"
mathc amend моё-решение
git add math/моё-решение/witness && git commit -m "моё-решение: фиксация"
mathc check
# моё-решение: применено ✓
```

## Команды

| команда | назначение |
|---|---|
| `mathc init` | инициализация проекта (структура + pre-commit + .mathrc) |
| `mathc record <имя> "<утверждение>"` | создать пакет |
| `mathc amend <имя>` | установить фиксацию на текущий коммит |
| `mathc supersede <старое> <новое> "<утверждение>"` | заместить решение |
| `mathc check` | проверить все пакеты |
| `mathc status --json` | состояние и следующие шаги в формате JSON |
| `mathc render` | сгенерировать сайт в формате HTML |
| `mathc review <имя>` | перевести в состояние «проверено» (требуется подпись) |
| `mathc find <подстрока>` | найти пакеты по подстроке |
| `mathc grep <шаблон>` | grep по утверждению и имени |
| `mathc show <имя>` | показать полный пакет |
| `mathc list` | список всех пакетов |
| `mathc history <имя>` | история пакета и версии |
| `mathc graph <имя>` | mermaid-диаграмма цепочки замещения |
| `mathc stats` | метрики (дрейф, применено/всего) |
| `mathc migrate-convention` | обновить пакеты до текущей схемы соглашения |

## Установка

```sh
# Самый простой путь: бинарь + авто-установка скилла агента.
curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/skills/install.sh | sh
```

Это ставит `mathc` в `~/.local/bin/` и копирует `SKILL.md`
в `~/.claude/skills/math-coding/`, `~/.config/opencode/skills/math-coding/`
и аналогичные каталоги Cursor и Continue.

Если для вашей OS/arch нет GitHub Release, скрипт собирает
из исходников через opam или nix.

### Сборка из исходников

```sh
git clone https://github.com/11111000000/math-coding
cd math-coding
nix develop --command sh scripts/install.sh
# или
opam switch create 5.2.0 && opam install dune
sh scripts/install.sh
```

Бинарь окажется в `$XDG_DATA_HOME/math-coding/current/mathc`.
Обёртка `./mathc` в корне проекта указывает на него.

### Скачать бинарь напрямую

Пять платформ автоматически собираются при каждом push в `main`
и публикуются как rolling [`edge`](https://github.com/11111000000/math-coding/releases/tag/edge)
prerelease:

| Платформа | Бинарь | Размер |
|---|---|---|
| Linux x86_64        | [`mathc-linux-x86_64`](https://github.com/11111000000/math-coding/releases/download/edge/mathc-linux-x86_64)       | ~4.4 MB |
| Linux aarch64       | [`mathc-linux-aarch64`](https://github.com/11111000000/math-coding/releases/download/edge/mathc-linux-aarch64)     | ~4.9 MB |
| macOS Intel         | [`mathc-darwin-x86_64`](https://github.com/11111000000/math-coding/releases/download/edge/mathc-darwin-x86_64)     | ~2.0 MB |
| macOS Apple Silicon | [`mathc-darwin-aarch64`](https://github.com/11111000000/math-coding/releases/download/edge/mathc-darwin-aarch64) | ~2.0 MB |
| Windows x86_64      | [`mathc-windows-x86_64.exe`](https://github.com/11111000000/math-coding/releases/download/edge/mathc-windows-x86_64.exe) | ~5.7 MB |

Стабильные релизы по тегам публикуют тот же набор по адресу
`releases/download/<tag>/...`. Переопределяется при установке
через `MATH_CODING_VERSION=v1.2.3 sh`.

## Документация

- [MANIFESTO.md](MANIFESTO.md) — восемь принципов, академическое изложение
- [FOUNDATIONS.md](FOUNDATIONS.md) — описание пакетов
- [WORKFLOW.md](WORKFLOW.md) — как работать, brownfield, миграция
- [FAQ.md](FAQ.md) — десять частых вопросов
- [math/modeling/](math/modeling/) — формальная модель (LaTeX)
- [AGENTS.md](AGENTS.md) — протокол для ИИ-агентов
- [skills/math-coding/SKILL.md](skills/math-coding/SKILL.md) — bootstrap для opencode / claude-code

## Лицензия

Living Beings License — см. [LICENSE](LICENSE).