---
schema_version: "2.1"
name: parser-quote-escapes
proposition: "yaml_string_value в core/parse.ml снимал парные кавычки, но не понимал escape-последовательностей внутри строки. Любая внутренняя кавычка ломала парсинг и теряла хвост proposition. Исправлено: внутри double-quoted значения backslash+quote теперь даёт литеральную кавычку. Backslash+backslash и прочие backslash-комбинации оставлены как есть, чтобы не сломать LaTeX-стиль идентификаторов в существующих пакетах."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---
## Why

Конвенция не запрещает кавычки внутри proposition, но парсер терял их вместе с хвостом значения. Это молчаливо ограничивало формулировки: нельзя было сослаться на строковый литерал или цитату в самом тексте proposition.

## Antithesis

Полноценный YAML-парсер — это другой проект (math-coding явно отказался, см. parse.ml:5-6). Альтернатива — задокументировать ограничение и просить авторов избегать кавычек. Но propositions естественно содержат кавычки (имена опций, цитаты), и запрет создаёт трение.

## Synthesis

Добавить минимальный escape-процессор: внутри double-quoted значения только backslash-quote → литеральная кавычка. Backslash+backslash НЕ схлопывается — иначе сломаются существующие пакеты вроде latex-textsc-rm, где backslash-textsc записано буквально. ~15 строк кода, два теста.


