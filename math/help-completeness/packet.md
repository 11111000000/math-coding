---
schema_version: "2.1"
name: help-completeness
proposition: "cmd_help в core/main.ml устарел: не упоминает --no-commit (реализован), V1-V7 раскиданы по doc без явной карты (V1=structure, V2=lifecycle, V3=register, V4=FSM, V5=actor, V6=supersession, V7=dialectic), и при опечатке в флаге extract_flags тихо роняет его в позиционные. Исправить: добавить секцию V1..V7 с пояснениями, добавить --no-commit в раздел 'decide', добавить предупреждение в extract_flags при неизвестном флаге (но не exit — позиционные тоже валидны)."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---

## Why

Help — это первый источник документации. Если он врёт про флаги (--no-commit молча работает, но не документирован), пользователь узнаёт о фиче случайно или не узнаёт. Карта V-номеров отсутствует в одном месте — приходится читать 5 файлов (FOUNDATIONS, AGENTS, README, kernel S, .mathrc), чтобы понять, что V4=FSM, а не 'frontmatter'. Извлечение флагов с опечатками молча проглатывает --typo, маскируя баги в скриптах.

## Antithesis

Длинный help раздражает пользователя. V-карта может стать таблицей в отдельном файле, но cmd_help должен быть компактным — это экран терминала. Предупреждение о неизвестных флагах при неаккуратной реализации превратит mathc в комбайн warning'ов и сделает вывод шумным.

## Synthesis

Добавить в cmd_help (a) секцию 'Verdicts' с расшифровкой V1..V7, (b) строку 'Flags: ... --no-commit (skip auto-commit in decide)' в описание decide. extract_flags: добавить 'unknown flag' warning только если флаг начинается с '--' и не в списке известных — НЕ менять silent drop для других случаев (позиционные остаются позиционными). Компактно, не шумно.
