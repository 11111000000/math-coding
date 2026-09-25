---
schema_version: "2.1"
name: ux-polish
proposition: "cmd_status (main.ml:597) предлагает 'mathc supersede <name> <name>-v2' для всех Drift пакетов, даже если пакет уже имеет непустое superseded_by — это может привести к двойной суперсессии (v2 уже есть, теперь будет v3). cmd_archive (main.ml:439) использует 'git mv' но не коммитит, оставляя staged-перемещения в working tree — следующий 'git commit -m ...' утащит их в чужой коммит. cmd_stats (navigate.ml:190) считает chains как пары (A→B, B→C), а не реальные цепочки — для графа длины 3 выводит '2 chains' вместо '1 chain'."
register: judgment
state: applied
actor: agent
confidence: 1.00
kind: fix
beneficiary: system
superseded_by:
---

## Why

(1) cmd_status рекомендует действия, которые могут создать проблемы. Drift + уже-superseded — это либо регрессия против convention (двойная суперсессия), либо баг в предыдущем пакете, который не лечится supersede. Различие не анализируется — все Drift рекомендуются к замене. (2) cmd_archive создаёт staged-перемещения, которые нужно отдельно коммитить. Это несовместимо с cmd_decide, который коммитит сам, и в отличие от record/amend/archive не имеет --no-commit флага. Результат: пользователь видит 'mathc archive: foo -> archived/...' но не понимает, что нужно сделать ещё git commit. (3) cmd_stats путает пары и цепочки. Если есть v1→v2→v3, выводится 'chains: v1→v2, v2→v3' — две пары, но одна цепочка. Число удваивается для каждой глубокой цепи, искажая метрику.

## Antithesis

(1) Усложнение cmd_status — добавление проверки superseded_by увеличивает функцию. Альтернатива: не предлагать supersede если proposition совпадает с последним superseded. (2) Добавление --commit флага — ещё одна точка конфигурации. Можно просто оставить git mv без коммита (текущее поведение) и задокументировать. (3) Транзитивное замыкание для cmd_stats — это O(N²) обход графа в наивной реализации. Для 25 пакетов это нормально, для 2500 — медленно.

## Synthesis

(1) cmd_status: не предлагать supersede для пакета с непустым superseded_by. Если superseded_by=Some v2, значит следующий шаг — ревью v2, а не новая версия. (2) cmd_archive: добавить --commit флаг, по умолчанию OFF (backward-compat), при включении — git commit сразу после mv. (3) cmd_stats: для каждого applied пакета с superseded_by рекурсивно собрать цепочку до конца (пока superseded_by is None или target не найден), посчитать уникальные 'roots' (цепочки с shared стартом — отдельные цепочки). Цепочки считаются через Set для дедупликации.
