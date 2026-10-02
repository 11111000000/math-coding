# Contributing

> **Протокол применяется к себе.** Pull request'ы,
> затрагивающие ядро, конституцию, схемы или
> authority-правила, следуют `AGENTS.md`
> §Self-application. Pull request'ы ко всему остальному
> следуют рабочей цепочке.

## Рабочая цепочка

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

Каждый коммит в `main` закрывает хотя бы одно
обязательство. Никакое обязательство не закрывается без
позитивной + негативной фикстуры. Никакое изменение ядра
не поставляется без решения в `decisions/*.yaml` под
активной политикой.

## Ветвление

- **Tier 1+**: feature-ветка от `main`, называется
  `<group>/<slug>` (например, `site/tufte-redesign`,
  `mc/packages-html`).
- **Tier 3+**: разнесите по нескольким PR согласно
  `OCAML_BEST_PRACTICES.md` §P4 порядку merge: сначала
  решения, затем фикстуры, затем чистые помощники ядра,
  в конце `bin/Mathc.ml`.
- **Сначала worktree**: каждое изменение происходит в
  git-worktree (см. skill `worktree-first`).

## Pre-commit проверки

Запустите `scripts/dev verify` перед `git commit`. Он
выполнит:

1. `pkill` устаревших `dune`/`nix develop` (чистит
   `_build/.lock`)
2. `dune build`
3. `dune test`
4. `scripts/fmt-check.sh`
5. `scripts/check.sh`

Каждый шаг независим, чтобы сбой на шаге 3 не пропускал
шаг 4. ~30-60 с всего.

## Защищённые переходы политики

Изменения в конституции, ядре, gate-правилах,
authority-правилах или waiver-правилах требуют **всего**
перечисленного (по `AGENTS.md` §Self-application):

1. решения под текущими активными правилами;
2. сильнейший практический контраргумент;
3. позитивные и негативные conformance-фикстуры;
4. путь миграции и восстановления;
5. авторизацию от предыдущей активной политики;
6. явный список изменяемых вердиктов.

Кандидатные правила не могут авторизовать собственное
принятие.

## Conventional Commits prefix

Используйте `Conventional Commits` для subject коммита
(≤72 символа):

```
feat(scope): summary
fix(scope): summary
refactor(scope): summary
docs(scope): summary
chore(scope): summary
attestations: ...
ci: ...
```

PR-заголовки следуют той же конвенции. Scope должен
называть затронутый пакет или модуль ядра
(`mc-self-check`, `lib/render`, `bin/Mathc`,
`decisions/site-deploy` и т.п.).

## Time-honest коммиты

Каждое сообщение коммита, упоминающее длительность,
сопровождается фразой в скобках, называющей шкалу и
референсный класс:

```text
feat(kernel): add risk classifier (kernel-change p95≈150min,
  ref: SWE-bench-V 2025-Q4)
```

Анти-паттерны (которые майнтер отвергнет):

- «Потратил два дня на это.» — wall-clock-minutes
  без session-start.
- «Быстрый фикс, несколько минут.» — утверждение о
  длительности без записи.
- «Неделя вдумчивой работы.» — смешивает wall-clock и
  субъективное внимание.

## Мелкие напоминания

- Все решения должны иметь frontmatter (`schema`, `id`,
  `revision`); см. формат в `decisions/decision.yaml`.
- Все обязательства должны объявлять верификатор;
  см. конвенции блока `acceptance:` в
  `OCAML_BEST_PRACTICES.md` §2.4.
- Все cram-фикстуры живут в `tests/cli/*.t`; никогда не
  пересоздавайте `tests/cram/`.
- Все оценки времени ссылаются на референсный класс
  из `bin/data/time-distribution.yaml` через
  `mc time-estimate`.

## Когда застряли

Лог OCaml-ловушек в `OCAML_BEST_PRACTICES.md` §11.
Прочтите его перед добавлением нового. Если следующая
ошибка не там, исправьте корневую причину и добавьте
новую запись о ловушке до merge.

## См. также

- [README](readme.html) — презентация проекта.
- [Workflow](workflow.html) — шестиступенчатая петля.
- [FAQ](faq.html) — самые частые вопросы.
- `AGENTS.md` §Self-application — чек-лист защищённой
  политики.
- `OCAML_BEST_PRACTICES.md` — конвенция OCaml.