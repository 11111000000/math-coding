---
schema_version: "2.1"
name: render-quality
proposition: "render_packet_body в core/render.ml понимает только '## ' (h3), параграфы и блоки кода — нет '### ' (h4), '#### ' (h5), упорядоченных и неупорядоченных списков. Пакеты с богатой иерархией теряют форматирование при рендере. Также cmd_render для каждого пакета открывает packet.md дважды — один раз через Parse.parse_packet, второй раз через Parse.extract_body. Исправить: добавить обработку ###/####, -/1. списков (минимально); в cmd_render читать packet.md один раз и передавать содержимое явно в render_packet_page."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---

## Why

render_packet_body (render.ml:210) — единственный markdown-парсер в проекте. Если пользователь пишет пакет с ### Details, - bullet, 1. ordered, эти конструкции рендерятся как параграфы с буквальными # и - в начале. Это регрессия против README, который pandoc рендерит корректно. На сайте видны пакеты типа 'process-fsm' с иерархией секций — но невооружённым глазом видно, что вложенные секции теряются. Двойное открытие packet.md — мелкая, но реальная проблема: 25 пакетов × 2 = 50 чтений, тогда как одно чтение достаточно.

## Antithesis

Полноценный markdown-парсер — pandoc. Можно отдать тело пакета pandoc-у, как делается для README/MANIFESTO. Но (a) pandoc создаёт полный HTML-документ, который придётся вытаскивать из body, (b) pandoc-fenced-divs для mathjax-блоков будут опасны (могут сломать layout), (c) регрессия для пакетов с ## Синтезис (диалектика) — pandoc их перенумерует/переиндексирует. Минимальный парсер в OCaml лучше: предсказуемо, контролируемо, детерминировано.

## Synthesis

Минимальный markdown: ### → h4, #### → h5, '- x' → <ul><li>x</li></ul>, '1. x' → <ol><li>x</li></ol>, '*' и '+' как аналоги '-' (триггеры списка). Inline-разметку (**bold**, *italic*) — пропускаем как plain text, чтобы не множить edge cases. В cmd_render: ввести render_packet_page_with_content packet_dir raw_content, который принимает уже прочитанное содержимое. Parse.extract_body работает с string. Кэш: вычислить содержимое один раз в render_site_loop, передать обоим вызовам.
