# Исполняемая модель v5

## Типы

- `SourceRef`: вид источника, путь, необязательный раздел, digest и
  необязательная запись пересмотра: автор, причина, время, прежний digest.
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
   не может оставаться `green` и требует пересмотра. `review-source` сохраняет
   автора, причину и прежний digest, очищает waiver и инвалидирует evidence;
   без нового `run` green запрещён. Исторический ADR не переписывается.
8. Последнее evidence выбирается по `issued_at`, а при равном timestamp — по
   более поздней позиции в trail: немедленный повторный run не оставляет прежний
   исход только из-за порядка сортировки.

Носители: `lib/domain.ml`, `lib/freshness.ml`, `lib/verdict.ml`,
`format/spec.ml`, `format/evidence.ml` и их отрицательные контроли в `test/`.
