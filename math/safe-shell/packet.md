---
schema_version: "2.1"
name: safe-shell
proposition: "В core/main.ml 7 точек интерполяции пользовательского name в shell-команды (mkdir, git add, git mv, git commit) без Filename.quote, и run_silent всегда возвращает 0, скрывая провал git commit. Исправить: ввести helper run_cmd, который (a) квотирует аргументы через Filename.quote, (b) возвращает реальный exit code, (c) печатает stderr при ошибке. cmd_decide должен падать с exit != 0, если любой из двух git commit завершился неудачно, а не молча коммитить witness 'в никуда'."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---

## Why

(1) Shell-инъекция: имя пакета 'foo;touch /tmp/pwned' в cmd_archive приводит к выполнению touch через git mv. Это CVE-уровень уязвимость для CLI, который читает имена из чужих источников (CI, агенты, импорт пакетов). (2) run_silent (main.ml:127) возвращает 0 всегда, поэтому в cmd_decide (main.ml:262,269) провал git commit (например, pre-commit hook отверг, или файл уже закоммичен) — silent. Witness записывается и коммитится в пустоту, пользователь видит 'mathc decide: applied'.

## Antithesis

(1) Filename.quote работает только для shell, не для произвольного пользовательского ввода. Но мы интерполируем ТОЛЬКО пути к файлам, не текст пропозиции — поэтому Filename.quote достаточно. (2) Жёсткая проверка exit code может сломать сценарии, где пользователь намеренно делает dry-run через хуки или где локальный git remote не настроен — придётся бежать без witness. Это раздражает, но лучше явная ошибка, чем тихая несогласованность.

## Synthesis

Ввести run_cmd cmd_args : int (где cmd_args = string list, квотирование внутри) — обёртка вокруг Sys.command с правильным квотированием и пробросом exit code. cmd_decide проверяет результат каждого шага (mkdir, add, commit) и прерывает с exit 1 при провале, печатая stderr. Параллельно убрать run_silent (заменён). Это минимальное изменение (~30 строк), закрывает конкретные CVE-уровневые баги и не трогает UX для нормального пути. Альтернативы (полная переписка на Lwt/Async для async shell, переход на  API через libgit2) — overengineering для CLI 1k строк.
