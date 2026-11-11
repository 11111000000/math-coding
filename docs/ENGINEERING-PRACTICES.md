# Инженерные практики v5

Это правила разработки данной реализации. Доменная модель определяется в
[методологии](../skills/math-coding/references/METHODOLOGY.md), а её точный
текущий профиль — в `AXIOMS.md`.

Это обязательные правила, а не рекомендации по вкусу. «Идеальный код» здесь
означает проверяемый, понятный, воспроизводимый и безопасный в изменении.

## 1. OCaml: типы и интерфейсы

- Публичный модуль имеет `.mli`. Скрывайте реализацию и инварианты, а не
  экспортируйте всё подряд.
- Недопустимые состояния не должны быть представимы. Не смешивайте
  `pass`, `fail`, `not-run`, `infrastructure-error`, waiver и review.
- Ожидаемые отказы возвращаются через `result`. Исключения — для ошибок
  программирования и genuinely exceptional boundaries.
- Не используйте `_ -> None`, `Option.value ~default` и catch-all для
  сокрытия повреждённых данных.
- Не оставляйте `failwith` на пользовательском вводе.
- Матчи исчерпывающи; новый вариант домена требует осознанного решения во
  всех местах, а не молчаливого fallback.
- Чистые вычисления не знают о файлах, времени, процессах и глобальном
  mutable state. Эффекты находятся в адаптерах и передаются параметрами.
- Простые модули лучше универсальных. Не применяйте functors/GADTs/PPX
  без измеримого выигрыша в безопасности или читаемости.
- Не используйте глобальные mutable registries, синглтоны и скрытые кэши.
- Обычный модуль ограничен примерно 200–250 строками, CLI dispatch — 100,
  `mathc.ml` — 50.

Источники: [OCaml Result](https://ocaml.org/manual/5.4/api/Result.html),
[OCaml modules](https://ocaml.org/manual/5.4/modules.html),
[OCaml compilation](https://ocaml.org/manual/5.4/comp.html).

## 2. Эффекты, процессы и Git

- Освобождение ресурсов — `Fun.protect`, `In_channel.with_open_*` и
  симметричные cleanup. Временные каталоги и процессы всегда убираются.
- По умолчанию argv, а не shell. Shell-команда разрешена только как явный
  вход проекта; cwd, environment и quoting централизованы.
- Каждый запуск имеет timeout, stdout/stderr, cwd и класс исхода:
  `pass/fail/inconclusive/infrastructure-error/not-run`.
- Падение assertion не смешивается с невозможностью запуска, timeout,
  сигналом и отсутствием программы. Setup и Git errors возвращаются явно.
- Вывод процессов ограничен; truncation — инфраструктурная ошибка, а не полный
  вывод и не pass.
- Нет destructive Git restore на живом дереве. Controls идут в независимой
  копии с overlay рабочего дерева, включая untracked файлы; режим файла
  сохраняется.
- Git вывод для имён файлов — NUL-delimited. Пути проверяются на traversal,
  symlink и границы каталога. Scope/source paths не могут быть absolute или
  содержать `..`; symlink не копируется.
- Параллельные агенты не делят живое дерево и не используют общий кэш без
  ключа «содержимое + окружение + определение + verifier».
- Записи атомарны: временный файл, fsync при необходимости, rename.

## 3. Форматы и доказательства

- Схема версионируется. Неизвестные и повторные поля отклоняются на любом
  уровне вложенности.
- YAML/XML/Markdown читаются библиотеками: `yojson`, `omd`, `xmlm`.
  Свой parser запрещён.
- Отсутствие поля, `null`, пустая строка и пустой список — разные вещи.
- Evidence иной версии отклоняется; доверие не повышается fallback'ом.
- Digest включает предмет, определение, verifier и environment.
- Provenance содержит producer/run, timestamp, источник и evidence ref.
  Подпись подтверждает авторство, не истинность.
- Ошибки не отбрасываются через `filter_map`: документ отклоняется целиком.

Источник: [SLSA build provenance](https://slsa.dev/spec/v1.2/build-provenance).

## 4. Сборка и зависимости

- Toolchain закреплён в `flake.lock`. Сборка поддерживается только в
  `nix develop`; расхождение версий компилятора и библиотек — дефект.
- При подключении OCamlFormat `.ocamlformat` содержит `profile = default` и
  точную `version`; инструмент закрепляется в dev shell. Проверка — `dune build
  @fmt`, принятие — reviewed `dune promote`. В текущей v5 форматтер ещё не
  включён: это оставшаяся работа, а не выполненная проверка.
- Тесты запускаются `dune runtest --root . --force`, потому что часть
  проверок читает дерево вне зависимостей dune.
- Предупреждения разбираются осознанно. Нет глобального blanket disable;
  локальное подавление имеет причину и минимальную область.
- Каждая зависимость должна быть использована. Версии `omd` и `xmlm`
  закрепляются после проверки совместимости с пином.
- Поставка проверяется на чистом клоне и установленным бинарём, а не
  только через `_build`.
- Portable не содержит Nix interpreter/RPATH и проверяется вне Nix store.

Источники: [Dune formatting](https://dune.readthedocs.io/en/stable/howto/formatting.html),
[OCamlFormat getting started](https://ocaml.org/p/ocamlformat/latest/doc/getting_started.html),
[Dune tests](https://dune.readthedocs.io/en/stable/tests.html).

## 5. Проверки

- Четыре уровня: чистые свойства, интеграция CLI/MCP, установленный пакет,
  внешний benchmark.
- У каждой проверки есть accepting и rejecting fixture. Она должна
  доказать, что способна упасть по существу.
- Golden/expect output никогда не принимается автоматически без ревью.
- Проверка присутствия фразы не заменяет проверку поведения.
- Тест объявляет в Dune все вызываемые бинари и читаемые установочные файлы;
  случайное наличие артефакта в `_build` не является зависимостью.
- Нет сети, часов, случайности и порядка выполнения без фиксации.
- Инфраструктурный сбой не превращается в red assertion или green pass.
- Независимый reviewer проверяет не только код, но и изменения тестов,
  схемы и критериев приёмки.

## 6. Производительность

- Сначала измерение, потом оптимизация.
- Git и процессы батчатся; дерево хешируется один раз за вычисление.
- Кэш не разделяет ответы между разными деревьями, схемами, verifier и
  окружением.
- Параллелизм, число файлов, байты, вывод и время ограничены.
- Порядок вывода детерминирован и стабилен для машин и snapshot review.

## 7. Агентная инфраструктура

- Сначала простейший workflow. Автономный агент добавляется только там,
  где динамический выбор действительно нужен.
- Исполнитель и проверяющий разделены контекстом. Проверяющий не может
  молча ослабить oracle.
- `map`, `next`, `context` read-only. Запись и исполнение — отдельные,
  явные действия.
- Цель, waiver, protected transitions, удаление, публикация и расширение
  полномочий требуют человека.
- Содержимое репозитория и вывод инструментов — untrusted input, а не
  инструкции с более высоким приоритетом.
- Инструменты минимальны по функциям и permissions. Общий shell не
  предлагается как универсальная capability.
- Secrets не попадают в контекст, traces, stdout/stderr и evidence.
- Каждый run имеет stop condition, timeout, лимиты и способ восстановления.
- Контекст ограничен текущей задачей, изменениями, отказами и неизвестным.
- Измеряется результат принятого изменения, а не число claims и вызовов.

Источники: [Anthropic, Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents),
[OWASP Excessive Agency](https://genai.owasp.org/llmrisk/llm062025-excessive-agency/),
[NIST Generative AI Profile](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf).

## 8. MCP

Целевая спецификация: `2026-07-28`, с явной negotiation совместимости.

- `initialize` и capabilities корректны; stdout содержит только JSON-RPC.
- `tools/list` детерминирован. `inputSchema` содержит `required` и
  `additionalProperties: false`.
- Доменный результат находится в `structuredContent` и соответствует
  `outputSchema`; текстовая копия допускается для совместимости.
- Protocol error и tool execution error не смешиваются.
- Вход валидируется, вывод sanitize и ограничивается, вызов имеет timeout.
- Аннотации инструментов не считаются доверенными без доверенного сервера.
- Пользователь может отклонить вызов; sensitive operations требуют
  подтверждения.
- Идентификаторы state handles не заменяют авторизацию.

Источники: [MCP Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[MCP Security Best Practices](https://modelcontextprotocol.io/specification/2026-07-28/basic/security_best_practices),
[MCP server logging](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-server).

## 9. Телеметрия и оценка

- run_id, task_id, provider/model/build-id, tool calls, latency, tokens,
  outcome и cost связаны одним следом.
- Данные секретов и личного содержимого не записываются в traces.
- Benchmark объявляется до прогона, имеет baseline, checklist arm,
  независимую оценку и все исходы, включая неудачи.
- Главный отказ — ложный `green`. Он останавливает релиз.

Ориентир: [OpenTelemetry GenAI attributes](https://opentelemetry.io/docs/specs/semconv/registry/attributes/gen-ai/).

## 10. Definition of done для каждого PR

1. Типы и `.mli` соответствуют изменению.
2. Accepting/rejecting fixtures добавлены и доказали свою силу.
3. `git diff --check`, `dune build`, `dune runtest --force` зелёные.
4. Пользовательский сценарий проверен на реальном бинаре.
5. Форматы, документация и комментарии не описывают старое поведение.
6. Нет неучтённых зависимостей, файлов, side effects и новых uncovered
   смысловых дыр.
7. Установленный пакет и `doctor` проверены там, где это затронуто.
8. Решение зафиксировано с причиной и возражением, а не только кодом.
