---
name: math-coding
description: Link ADR and requirements to fresh, independently checked evidence. Use when integrating mathc into a repository, checking what is actually verified, handling a changed ADR, or reviewing an agent's completion claim.
---

# math-coding v5

Используй `mathc` как слой доказательств поверх существующих ADR, тестов и CI,
а не как их замену. Нужен Git-репозиторий; `spec.json` создаётся один раз.

## Перед началом

Получи от человека три значения: **AIM**, **SCOPE** и **OWNER**. Не выдумывай
scope: он ограничивает карту покрытия. Для точной справки используй
`mathc help COMMAND`, например `mathc help add` или `mathc help run`.

## Быстрый старт

Выполняй команды в корне проекта или передавай `--root ABSOLUTE_PATH`.

```sh
mathc --help
mathc adopt
mathc init
mathc goal "ЦЕЛЬ_ОТ_ЧЕЛОВЕКА" "src/,test/" "ВЛАДЕЛЕЦ"
mathc add ID "ТРЕБОВАНИЕ" "src/file.ml" "ЧТО_ОПРОВЕРГАЕТ" fact \
  --requirement "verifier:КОМАНДА_ПРОВЕРКИ" \
  --control "КОМАНДА_ЛОМАЕТ_ПРЕДМЕТ"
mathc run
mathc map
mathc next
```

`init` отклонит существующий `spec.json`. Не заменяй существующую цель.
`adopt` ничего не пишет. После настройки:

```sh
mathc install
mathc doctor
```

`install` обновляет только маркированный блок `AGENTS.md`. Он не устанавливает
бинарь. Для установки бинаря и этого skill используется `install.sh` из
репозитория math-coding; подробности — `references/PROJECT-SETUP.md`.

## Если в проекте ещё нет проверяемого предмета

Создай маленький предмет и честную проверку. В scope claim включи и предмет, и
файл проверки — иначе инфраструктура проверки останется в `uncovered`.

```sh
mkdir -p scripts test
printf '#!/bin/sh\nprintf "hello math-coding\\n"\n' > scripts/hello.sh
printf '#!/bin/sh\n[ "$(sh scripts/hello.sh)" = "hello math-coding" ]\n' > test/check_hello.sh
chmod +x scripts/hello.sh test/check_hello.sh
mathc goal "проверить независимую установку" "scripts/,test/" "owner"
mathc add hello "hello script prints the expected text" \
  "scripts/hello.sh,test/check_hello.sh" "the check accepts another text" fact \
  --requirement "verifier:sh test/check_hello.sh" \
  --control "sed -i 's/hello math-coding/hello broken/' scripts/hello.sh"
mathc run
mathc map
```

Control обязан менять предмет claim и заставлять verifier упасть. `run`
печатает `negative control proven`, только когда это действительно произошло.

## Правила доказательств

- Начинай с 1–3 важных claims, а не с описания всего репозитория.
- Каждый verifier должен иметь control, который меняет его предмет и заставляет
  проверку упасть. `run` доказывает это в изолированной копии.
- `map`, `next`, `context`, `adopt`, `import-adr` — read-only. `run` исполняет
  проектные команды и пишет evidence в `.math/v5/`; это не read-only операция.
- `0` — успех/green; `1` — refuted/protected; `2` — ошибка вызова;
  `3` — unknown/vacant. Код `3` нельзя выдавать за успех.
- Green относится только к объявленным claims. Сообщай `uncovered`, unknown и
  инфраструктурные отказы вместе с ним.
- `uncovered` ограничен scope цели; служебные файлы метода и сгенерированная
  agent page в него не входят.
- Не редактируй evidence trail, не ослабляй verifier и не меняй control ради
  зелёного результата.

## ADR и человеческие решения

`add --source PATH` связывает claim с digest ADR. После изменения ADR:

```sh
mathc re-evaluate
mathc review-source ID --by ВЛАДЕЛЕЦ --reason "ПРИЧИНА_ПЕРЕСМОТРА"
mathc run
mathc map
```

Выполняй `review-source` только после реального пересмотра решения человеком.
Команда сохраняет автора, причину и прежний digest, очищает waiver и не даёт
green без нового `run`. ADR не переписывается.

`record`, `waive`, `authorize` и `review-source` фиксируют решения, а не
аутентифицируют личность. Не присваивай себе человеческое review и не создавай
waiver без разрешения человека. Не коммить и не публикуй без явного запроса.

## Измеритель

`mathc-stand` сравнивает время полного протокола с прямым запуском verifier'ов.
Он не заменяет внешний benchmark. Справка и смысл колонок:

```sh
mathc-stand --help
```

Если установленный `mathc --version` не печатает `mathc 5`, сообщи об этом, а
не смешивай команды старой и новой версий.
