# Исполняемая модель v5

## Типы

- `SourceRef`: вид источника, путь, необязательный раздел, digest.
- `Claim` (obligation): текст, scope, источник, род, фаза, владелец,
  требования, falsifier, register, control и необязательный waiver.
- `Evidence`: obligation, requirement, candidate tree, materials/definition/
  verifier digests, environment, producer, independence, outcome, issue/expiry,
  evidence reference и control reach.
- `Waiver`: gap, scope, issuer, issue/expiry, reason, compensating controls,
  recovery и review triggers.
- `ExecutionLog`: отдельное наблюдение стоимости, не доказательство.

## Законы

1. `Unknown != pass`; `waived != pass`; `not-run != fail`.
2. Пустой набор обязательств даёт `vacant`, а не подтверждённый `green`.
3. `Refuted` доминирует над остальными состояниями.
4. Доказательство устаревает при изменении определения обязательства,
   verifier, среды или окончания срока.
5. Машинный `Holds` требует свежего `pass`, control reach `subject` и
   выполненных требований независимости.
6. Waiver действует только в `[issued_at, expires_at)` и не покрывает `Refuted`.
7. Изменение ADR меняет source digest; обязательство становится `outdated`,
   не может оставаться `green` и требует пересмотра. Историческое решение при
   этом не переписывается, новое решение не принимается автоматически.
8. Миграция не повышает доверие: старое свидетельство без обязательных
   привязок остаётся `legacy_unverified`.

Носители: `lib/domain.ml`, `lib/freshness.ml`, `lib/verdict.ml`,
`format/spec.ml`, `format/evidence.ml` и их отрицательные контроли в `test/`.
