# Как работать с math-coding

## Ежедневный поток

### 1. Перед записью нетривиального решения

Создать пакет **до** того, как пишется код. Это и есть
curry-howard: proposition (тип) предшествует code (терму).

```sh
mathc record моё-решение "краткое утверждение на одном предложении"
git add math/моё-решение/ && git commit -m "моё-решение: краткое описание"
mathc amend моё-решение
git add math/моё-решение/witness && git commit -m "моё-решение: фиксация"
```

После этого — `mathc check` показывает `applied ✓`.

### 2. Когда proposition меняется

Никогда не редактировать `packet.md` после `witness`. Использовать
замещение:

```sh
mathc supersede моё-решение моё-решение-v2 "новое утверждение"
git add math/моё-решение/ && git commit -m "v2: новое утверждение"
mathc amend моё-решение-v2
git add math/моё-решение-v2/witness && git commit
```

Старая цепочка сохраняется в git-истории. Ядро проверяет, что
`superseded_by: моё-решение-v2` ведёт на существующий пакет.

### 3. Поиск и навигация

```sh
mathc find TTL                       # найти пакеты по подстроке
mathc grep "cache"                    # grep по proposition и имени
mathc show моё-решение                # показать полный пакет
mathc list                           # все пакеты
mathc history моё-решение            # история пакета
mathc graph моё-решение              # mermaid-цепочка замещения
```

### 4. Проверка состояния

```sh
mathc check                          # проверить все пакеты
mathc status --json                  # JSON: состояние и next steps
mathc stats                          # метрики (drift rate, applied/total)
```

## Brownfield: переход с существующего проекта

### Шаг 1. Установка

```sh
# Самый простой путь: бинарь + авто-установка скилла агента.
curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/skills/install.sh | sh
```

Это кладёт `mathc` в `~/.local/bin/` и устанавливает скилл агента
в каталоги Claude Code, opencode, Cursor и Continue. Если под
вашу OS/arch нет Release-бинаря, скрипт собирает из исходников
через opam/nix.

Если предпочитаете сборку из исходников (например, чтобы хакать
на `mathc`):

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

### Шаг 2. Инициализация

```sh
mathc init
```

Создаёт `math/`, `.mathrc`, устанавливает pre-commit hook.
Существующие файлы не трогает.

### Шаг 3. Авторизация существующего кода

Для legacy кода создать один пакет:

```sh
mathc record legacy-code "Существующий код авторизован как legacy: <краткое описание>"
git add math/legacy-code/ && git commit -m "legacy-code: авторизация"
mathc amend legacy-code
git add math/legacy-code/witness && git commit
```

Этот пакет служит маркером: «всё, что существовало до convention,
считается авторизованным как legacy».

### Шаг 4. Новые решения

Каждое новое архитектурное решение — отдельный пакет:

```sh
mathc record моё-решение "..."
git add . && git commit
mathc amend моё-решение
```

### Шаг 5. Постепенное расширение

Старые важные решения можно задним числом перевести в пакеты.
Не обязательно всё сразу. Convention сама подскажет через
`mathc status`, какие пакеты отсутствуют для существующих решений.

## Конфигурация: `.mathrc`

```yaml
# Режим подписи
SIGNING_MODE: lenient    # strict | lenient | off

# Автоматизация
AUTO_AMEND: true         # record → auto-amend после commit
AUTO_RECORD_PROMPT: true # agent предлагает создать пакет

# Substrate
SUBSTRATE_DEFAULT: none

# Lifecycle
STRICT_DRIFT_CHECK: false # strict = Fail на drift; lenient = Warn

# Schema
SCHEMA_VERSION: "2.0"

# Plugin (для будущих legacy)
PLUGINS: ["v2.0"]

# Output
DEFAULT_JSON: false
```

## Pre-commit hook (auto-installed)

`mathc init` устанавливает `.git/hooks/pre-commit`:

```sh
#!/bin/sh
exec mathc check --staged --strict
```

При каждом commit проверяются staged пакеты. Drift до попадания
в git обнаруживается автоматически.

## Эволюция convention

### Обновление frontmatter (новые поля)

Когда convention добавляет новое обязательное поле:

```sh
mathc migrate-convention
```

Анализирует все пакеты, добавляет новые поля с дефолтами, не трогает
существующие proposition/witness. Создаёт commit «convention: migration».

### Эволюция формата (новая schema_version)

Когда convention требует новой версии схемы:

```sh
# mathc migrate --from=v2.0 --to=v3.0 (отложено до v2.0.1)
```

Legacy plugins будут добавлены в v2.0.1+ для brownfield migration
из v1.0/v0.99/v0.854.