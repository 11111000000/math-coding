# Исполняемая модель

Этот документ фиксирует фактический контракт текущей реализации.
[Методология](skills/math-coding/references/METHODOLOGY.md) определяет смысл
модели самостоятельно; здесь перечислены вычислимые правила и границы CLI.

## Типы

- `SourceRef`: вид источника, путь, необязательный раздел, digest и
  необязательная запись пересмотра: автор, причина, время, прежний digest.
- `Claim`: текст, scope, источник, род, фаза, владелец, события пересмотра,
  условия подтверждения, falsifier, register, control и необязательный waiver.
- `Evidence`: claim, requirement, candidate tree, materials/definition/verifier
  digests, environment, producer, independence, outcome, issue/expiry, evidence
  reference и control reach.
- `Waiver`: gap, scope, issuer, issue/expiry, reason, compensating controls,
  recovery и review triggers.
- `ExecutionLog`: отдельный тип наблюдения стоимости, не доказательство.

Носители: `lib/domain.ml`, `lib/freshness.ml`, `lib/verdict.ml`,
`format/spec.ml`, `format/evidence.ml` и отрицательные контроли в `test/`.

## Границы текущего профиля

- `mathc add` создаёт `acceptance/pre-merge`, назначает владельца из цели и
  оставляет `review_on` пустым. `import-adr` создаёт неактивный черновик с
  пустыми scope и requirements и регистром `unknown`.
- `kind`, `phase` и `review_on` входят в definition digest, но текущий CLI не
  использует их для расписания или автоматического пересмотра.
- `fact`, `hypothesis` и `unknown` используют одни правила evidence. Регистр
  фиксирует характер утверждения и не снижает требования. `judgment`
  рассматривает только review requirements.
- Текущий `add --source` связывает источник как `madr`; остальные виды
  `SourceRef` поддержаны кодеком и служат типу источника, а не автоматическому
  импорту.
- Локальный verifier получает `fresh-context`; `record` создаёт human evidence
  с уровнем `external`. Это процедурное происхождение, не независимая экспертиза
  требования и не аутентификация.
- `NotCheckable` присутствует в домене и агрегации, но текущий `run` не создаёт
  это состояние.
- `ExecutionLog` не создаётся текущим CLI. Измеритель стоимости не превращает
  свои наблюдения в `Evidence`.
- Стандартный `waive` записывает reason, expiry и recovery, оставляя
  compensating controls и review triggers пустыми. Эти поля кодека не меняют
  вердикт.

## Наблюдения

1. Код verifier `0` означает `pass`, `1` — `fail`, `2` или `3` —
   `inconclusive`, `126` или `127` — `not-run`. Сигнал, тайм-аут и другие коды
   — `infrastructure-error`. Обрезанный stdout/stderr также означает
   `infrastructure-error`.
2. Исход процесса не равен состоянию claim. `not-run` не означает `Refuted`, а
   `pass` не означает `Holds`.
3. Если исходный verifier не вернул `pass`, control не нужен для классификации
   этого наблюдения. Если verifier вернул `pass` без control, записывается
   `not-run` результата контроля, и машинное `Holds` запрещено.

## Свежесть и независимость

4. Evidence устаревает при изменении materials, definition, verifier/control,
   environment, окончания срока или времени выдачи в будущем.
5. Materials digest вычисляется по фактическим tracked/untracked файлам scope,
   включая режимы, а не только по HEAD. Пустой или неполный scope digest не
   образует.
6. Текущий environment fingerprint включает digest бинаря `mathc`, `Sys.os_type`
   и содержимое `flake.lock`, если файл есть. Текущий fingerprint должен точно
   совпадать с evidence.
7. Машинное `Holds` требует свежего `pass`, control reach `subject` и
   independence не ниже `fresh-context`. Недостаток control/independence при
   `pass` даёт `Inconclusive`.
8. Для review требуется объявленный минимум independence и свежая attestation.
   Несоответствие требованию делает attestation неприменимой; `fail` ревью
   опровергает, `pass` подтверждает.

## Композиция условий

9. Верхний список requirements является конъюнкцией. `All` имеет `Holds`, только
   если все ветви `Holds`; любая `Refuted` ветвь опровергает его.
10. При исполнении `All` после `pass` выполняется следующая ветвь, после `fail`
    исполнение прекращается, а после `inconclusive`, `infrastructure-error` или
    `not-run` остальные ветви выполняются, чтобы поздний `fail` не был потерян.
11. `Any` имеет `Holds`, если хотя бы одна ветвь `Holds`, и `Refuted`, только
    если все непустые альтернативы `Refuted`. Во время исполнения первый `pass`
    прекращает перебор; остальные исходы не прекращают его.
12. Пустой набор states конъюнкции даёт `NeverChecked`; пустой `Any` даёт
    `Inconclusive`. Отсутствие evidence для одной ветви не скрывает `Refuted`
    другой.

## Состояния и вердикт

13. Состояния claim: `Holds`, `Refuted`, `Inconclusive`, `NotCheckable`,
    `Outdated`, `NeverChecked`, `Waived`.
14. Последняя evidence для requirement выбирается по `issued_at`, при равном
    timestamp — по более поздней позиции в trail.
15. Пустой набор claims даёт `Vacant`. Непустой набор даёт `Red`, если хотя бы
    один claim `Refuted`; `Green`, если все `Holds`; иначе `Unknown`.
16. `Inconclusive`, `NotCheckable`, `Outdated`, `NeverChecked` и `Waived`
    отображаются в `Unknown`, не в `Green` и не автоматически в `Red`.
17. Waiver действует только в `[issued_at, expires_at)`, помечает подходящий
    неопределённый gap как `Waived` и не покрывает `Refuted`.

## Источники и покрытие

18. Изменение source digest даёт `source_changed` и `Outdated`.
    `review-source` сохраняет автора, причину и прежний digest, очищает waiver
    и меняет definition digest. Без нового `run` прежнее evidence не подходит.
19. `uncovered` вычисляется в goal scope и не входит в вердикт claims. `Green`
    с непокрытыми файлами возможен; `next` продолжает направлять к ним после
    восстановления claims. Служебные файлы метода исключены из покрытия.
20. Scope/source paths относительны к проекту и не могут быть absolute,
    traversal или symlink. Ошибки repository surface не становятся пустым
    доказательством или пустым coverage.

## Безопасность исполнения

21. `map`, `next`, `context`, `adopt` и `import-adr` read-only. `run` исполняет
    проектные shell-команды и добавляет локальные evidence в `.math/v5/`.
22. Controls исполняются в изолированной копии текущего дерева. Они не меняют
    живой предмет. Evidence другой схемы и повреждённый trail отклоняются без
    fallback или повышения доверия.
