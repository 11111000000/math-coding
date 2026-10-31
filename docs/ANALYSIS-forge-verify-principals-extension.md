# Анализ и обоснование: `forge-verify-principals-extension`

> Рациональный документ для решения
> `decisions/forge-verify-principals-extension-2026-10.yaml`.
> Ветка: `forge-verify-analysis-2026-10`.
> Дата: 2026-10-16.

---

## 1. Контекст

`forge-principal-verification-2026-10` (revision 1, `2c3145a`) уже в `main`.
Он добавляет:

- `lib/forge.ml` (`team_member`, `team_member_full`, `parse_principal`);
- `bin/Mathc.ml::do_forge_verify` с API `--org --team --user --committer --fail-mode`;
- `tests/cli/forge-verify.t` (3 кейса).

Это закрывает базовую проверку «входит ли коммитер в команду». Но в
процессе у этой идеи был параллельный драфт (WIP `8f593fa` поверх
`ae3933c`), который предлагал более богатую версию:

- `Domain.required_principals : string list` — решения сами декларируют
  требуемые команды;
- позиционный `[DECISION]` в CLI — единая точка входа;
- `--principal=KIND:NAME`, `--head=COMMIT`, `--dry-run`;
- `verdict` зависит от **всех** перечисленных принципалов, а не от
  одного ad-hoc запроса.

WIP **не был смержен** и сейчас удалён из этой ветки (см. §3). Этот
анализ — фиксация того, что мы узнали, и обоснование для следующего
шага.

---

## 2. Что говорит WIP в пользу расширения

| Сильная сторона upstream | Слабая сторона upstream | Что добавлял WIP |
|---|---|---|
| CLI простой, понятный | `mathc forge-verify` живёт сам по себе, не привязан к решениям | Позиционный `[DECISION]` + `required_principals` |
| `team_member ~org ~team ~user : bool` | `team` — плоская строка, нет kind/user разделения | `--principal=KIND:NAME` (team vs role vs user) |
| Кэш 1 час, всё стабильно | Только HEAD | `--head=COMMIT` для исторических коммитов |
| HTTP-транспорт через curl, без зависимостей | Нет способа прогнать логику без сети | `--dry-run` |
| `--fail-mode open\|closed` понятен | — | (WIP обходился без `fail-mode`, что хуже) |

WIP — это spec-улучшение, не альтернатива. Обе версии решают одну задачу,
WIP — шире.

---

## 3. Что не так было с WIP (и почему он удалён)

| Дефект | Серьёзность | Действие |
|---|---|---|
| `lib/forge.ml` отсутствовал в WIP-коммите (не компилировался) | блокер | удалён из ветки |
| `tests/cli/forge-verify.t` отсутствовал | высокая | удалён |
| `parse_fail_mode ()` вызывался, но не был определён | высокая | удалён |
| `Domain.required_principals` ломал все конструкторы `decision` | средняя | не реализован в этом решении |
| Decision-файл описывал обязательства только upstream-API | средняя | закрыто новым решением (см. §4) |

Удаление WIP из этой ветки **не означает отказ от идеи**. Это означает
«черновик не дотягивает до mergeable состояния, пусть лежит в этом
анализе как материал для нового решения».

---

## 4. Решение: option B (расширение upstream)

Полный текст — `decisions/forge-verify-principals-extension-2026-10.yaml`.
Кратко — это **revision 2** идеи `forge-principal-verification`:

1. Оставить существующий upstream нетронутым.
2. Добавить опциональное поле `required_principals` в `Domain.decision`
   (defaults to `[]`, обратная совместимость).
3. Расширить `bin/Mathc.ml::do_forge_verify`:
   - `--principal=KIND:NAME` (через `lib/forge.ml::parse_principal`);
   - `--head=COMMIT` (default `HEAD`);
   - `--dry-run`;
   - позиционный `[DECISION]` — если указан, читает `required_principals`
     из решения и проверяет каждый;
   - `--fail-mode` остаётся.
4. Расширить `tests/cli/forge-verify.t` кейсами на `required_principals`
   и `KIND:NAME`.

Решение **mode: standard** (трогает kernel: `lib/domain.ml`, `lib/decision.ml`,
`bin/Mathc.ml`), axiom_link A1 + A4 (как у родителя).

---

## 5. Что **не** входит в это решение

- Изменения `lib/gate.ml` (gate-логика остаётся вне scope; forge-verify
  остаётся CLI-утилитой, gate её не вызывает).
- Изменения `lib/policy.ml` (path-policy с `required_principals` — отдельный
  T-point, если потребуется).
- Schema bump. `required_principals` — **опциональное** поле, миграции не
  требует, schema не ломается.
- Изменения `lib/rebuttal.ml::forge_mirror` (env-контракт `MATH_CODING_FORGE_API`
  сохраняется).

---

## 6. Риски и контрпримеры

**Сильный контрпример (A1 + A4):**
«Расширение forge-verify в gate-логику превращает ad-hoc утилиту в
часть протокола. Если `--fail-mode closed` срабатывает ошибочно
(forge-rate-limit, DNS-сбой), `mathc gate` начнёт блокировать мержи
по внешней причине. Это нарушает A1 (commitment должен иметь путь к
наблюдению) — наблюдение зависит от внешней системы.»

Ответ: forge-verify **остаётся CLI-утилитой**, gate её не вызывает.
Решение не превращает утилиту в gate-обязательство. Это контролируемо:
если кто-то в будущем захочет подключить forge-verify к gate, это
будет отдельным решением с собственным A1/A4-обоснованием.

**Другой сильный контраргумент:**
«`required_principals` — это policy, а не схема. Решения не должны
декларировать, кто их одобряет; это задача reviewer'а, а не
commitment'а.»

Ответ: `required_principals` — это **опциональная мета-информация** для
forge-verify, не для gate-логики. Решения, в которых её нет, работают
как раньше. Это additive change, не policy change.

---

## 7. Что увидел пользователь по дороге

1. **Main read-only нарушен** — кто-то работал в `/home/az/Projects/math-coding`
   (WIP), потом сделал `git stash`, переключился на main, `git pull`,
   `git stash pop` → конфликт. Конфликты не были разрезолвлены, остались
   маркеры `<<<<<<< Updated upstream` / `=======` / `>>>>>>> Stashed changes`
   в 6 файлах, мелкие правки счётчиков 183→186 в 14.
2. **Main очищен**, WIP перенесён в worktree
   `/home/az/.paseo/worktrees/forge-verify-analysis-2026-10` на ветке
   `forge-verify-analysis-2026-10`, коммит `8f593fa`.
3. **Написан этот анализ** (`858b759` поверх `8f593fa`).
4. **WIP удалён из ветки** (`git reset --hard ae3933c`). SHAs `8f593fa`
   и `858b759` всё ещё в `.git/objects` как unreachable objects, до
   следующего `git gc` — могут быть восстановлены через
   `git fsck --unreachable` + `git reflog`.
5. **Этот анализ переписан** как рациональный документ для нового решения.
6. **Новое решение** `decisions/forge-verify-principals-extension-2026-10.yaml`
   фиксирует option B как обязательство.

---

## 8. Контрольные ссылки

| Что | Где |
|---|---|
| Родительское решение | `decisions/forge-principal-verification-2026-10.yaml` (rev 1, active) |
| Upstream код | `2c3145a:lib/forge.ml`, `2c3145a:bin/Mathc.ml::do_forge_verify`, `2c3145a:tests/cli/forge-verify.t` |
| WIP (удалён) | `8f593fa` (unreachable, восстановим через `git fsck`) |
| Базовый коммит анализа | `ae3933c merge: bring site-deploy changes (PR #8, PR #9) into local main` |
| Spec | `spec/kernel-contract.md` §13 (forge-principal-verification), §7 (entity model) |
| Аксиомы | A1 (feedback), A4 (authority) |

---

*Анализ переписан 2026-10-16 после `git reset --hard ae3933c`. WIP удалён
из ветки. Wall-clock на полный цикл (очистка main + перенос WIP + анализ
+ удаление WIP + это решение) ≈ 22 мин, ref-class `refactor` (P50=12 мин
по `bin/data/time-distribution.yaml`) — превышение из-за двух нештатных
операций (pre-commit hook блокировал WIP-коммит, пришлось докидывать
decision-файл).*