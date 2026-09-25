---
schema_version: "2.1"
name: cleanup-dead-code
proposition: "core/plugin.ml, core/current.ml, core/migrate.ml объявлены в dune как модули, но ни один из их публичных API не вызывается из main.ml или тестов. plugin.ml Format_v2_0 делегирует обратно в Parse.parse_packet; load_plugin нигде не вызывается. current.ml validate_schema_version и apply_defaults — dead code. migrate.ml migrate_packet — no-op. Удалить эти три модуля и убрать из dune. Канонизировать schema_version на 2.1 (все новые пакеты уже пишут 2.1, kernel принимает 2.0 для backward-compat)."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---

## Why

Мёртвый код — техдолг. plugin.ml, current.ml, migrate.ml были заготовлены для будущих версий формата (v1.0, v0.99, v0.854) и миграций схемы. Но фактически ни один путь выполнения их не использует. dune собирает их при каждом билде, тесты покрывают 0% их кода, и они дают ложное ощущение, что plugin architecture существует (хотя это просто обёртка над Parse.parse_packet). Удаление снижает cognitive load без потери функциональности.

## Antithesis

Эти модули были заготовлены под будущее. Их удаление делает невозможным добавить legacy plugins (v1.0, v0.99, v0.854) без переписывания. Если в какой-то момент понадобится миграция со старой схемы, придётся заново реализовать plugin.ml. Также: канонизация schema_version на 2.1 сломает все существующие пакеты с schema_version: 2.0 (их ~8 штук), что потребует миграции.

## Synthesis

Удалить три модуля. Их стоимость восстановления низкая (< 200 строк кода), а текущая стоимость содержания — высокая (читатель тратит время, пытаясь понять, что они делают, и не находит потребителя). Что касается schema_version: kernel уже принимает ОБОИХ (Pass для 2.0 и 2.1 в check.ml), так что backward compatibility сохранена. Канонизация здесь означает только 'cmd_decide пишет 2.1, новые пакеты должны быть 2.1'. Существующие 2.0 пакеты продолжат работать. Никакой миграции не требуется.
