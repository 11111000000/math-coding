# Анализ кода и выделение рендера — Phase 1+ планы

> Плановый документ. Сессия: `wks_c10629bbd41628bf` «Анализ кода и выделение рендера».
> Базовая ревизия: `a73b6a6` (main → `Merge render-split-2026-10`).
> Автор: агент сессии. Дата: 2026-10-17.

## 0. Контекст и границы

- **Что анализировалось.** Состояние `lib/render/render.ml` сразу после коммита
  `eb0a38b refactor(render): move lib/render.ml into separate mathcoding_render library`,
  смёрженного в `main` как `a73b6a6`. Сам же коммит — реализация решения
  `decisions/render-module-split.yaml@1`, чей `commitment` прямо говорит:
  *«subsequent splits (Phase 1+ of the refactor) land as additional modules
  in the same `lib/render/` directory»*. Этот документ — план именно
  Phase 1+ (реальное разделение на модули), а не повторение Phase 0
  (которая уже сделана).
- **Что НЕ удалось получить.** Транскрипт предыдущей Paseo-сессии
  `wks_7088cec3bcfba2ed` «Анализ сессии рендера и план» напрямую
  недоступен из этого контекста; анализ сделан по текущему состоянию
  репозитория и по тексту решения `render-module-split@1`, а не по
  дословному содержимому той сессии. Если пользователь хочет
  сверки с той сессией — нужен либо её транскрипт, либо повторный
  созвон.
- **Что НЕ меняется этим документом.** Публичный API рендера
  (`Render.config`, `Render.build_pages`, `Render.md_parse`,
  `Render.rss_*`, `Render.default_version`, `Render.page`,
  `Render.nav_groups_*`, `Render.html_escape`, `Render.html_of_fragments`)
  остаётся бит-в-бит совместимым. Изменение только внутреннее.

## 1. Что есть сейчас

`lib/render/render.ml` — единственный модуль dune-библиотеки
`mathcoding_render`. 3040 строк, 3040+ символов, ~133 KB. Никаких
внутренних под-модулей кроме `String_set`. Все «горячие точки»
лежат рядом без разделителей.

Потребители (вызовы `Render.*`):

| Файл | Какие вызовы |
|---|---|
| `bin/Mathc.ml` (6364 строки) | `Render.read_version_file`, `Render.default_version`, `Render.config`, `Render.build_pages`, `Render.rss_*`, `Render.extract_intent_summary`, `Render.render_rss_feed`, `Render.page.{path,body}` |
| `bin/md_probe.ml` | `Render.md_parse` (CLI-утилита для отладки парсера) |
| `tests/render_kernel.ml` (1362 строки) | `Render.md_parse`, `Render.config`, `Render.default_config`, `Render.build_pages`, `Render.page.{path,body}` |
| `bin/dune`, `tests/dune` | `(libraries … mathcoding_render)` |

Внутренне файл распадается на 9 логических кластеров. Границы
найдены по сигнатурам верхнего уровня (`grep -nE '^let(\[@warning "-32"\]|\s)+\w+'`):

| # | Кластер | Строки | Публичные символы | Зависит от |
|---|---|---|---|---|
| 1 | **Markdown subset** | 30–779 | `html_escape`, `html_of_fragments`, `md_inline_parse`, `md_inline`, `code_fence_tag`, `md_parse` | `Buffer`, `String`, `Str` |
| 2 | **Navigation data** | 780–1015 | `nav_groups_en/ru/zh`, `nav_groups_for`, `lang_href_for`, `sibling_translation_href` | кластер 1 (`html_escape`) |
| 3 | **GitHub helpers** | 1015–1018 | `github_origin`, `github_blob` | — |
| 4 | **Page chrome** | 1018–1279 | `render_nav`, `render_footer`, `render_head`, `render_page` | кластеры 2, 3 |
| 5 | **Index pages** | 1279–1645 | `render_axioms_section`, `render_index`, `render_index_ru`, `render_index_zh` | кластеры 1, 4 |
| 6 | **Decision pages + YAML subset** | 1645–2180 | `render_decision_page`, YAML-хелперы (`indent_of`, `trim_block_lines`, `find_top_key`, `block_end`, `top_scalar`, `top_block`, `top_object_list`, `top_string_list`), `render_yaml_*`, `strip_boilerplate`, `render_decision_yaml` | кластеры 1, 4 |
| 7 | **Axiom/Spec pages** | 2180–2281 | `render_spec_page`, `render_axiom_page` | кластеры 1, 4 |
| 8 | **FS / orchestrator** | 2281–2686 | `read_version_file`, `read_spec_files`, `default_version`, `build_pages`, `type page`, `type config` | кластеры 1, 4–7, `mathcoding_core` |
| 9 | **Extras (RSS + embedded SPAs)** | 2686–3040 | `rss_escape`, `extract_intent_summary`, `render_rss_feed`, `default_config`, `render_dashboard`, `render_graph_html`, `type rss_decision_item` | кластеры 1, 4, 8 |

Сейчас весь этот граф зависимостей свёрнут в один файл; компилятор
видит только `Buffer` × `String` × `str` × `unix` × `mathcoding_core`,
но не видит, что `md_parse` не зависит от `nav_groups_en`, а
`render_dashboard` не зависит от `YAML subset`. Это и есть
**главная потеря** монолита: тащится всё или ничего.

## 2. Риски текущего состояния

1. **Compile time.** Один `.ml` → один `.cmi` → любая мелкая правка
   в одном кластере пересобирает всё, что зависит от
   `mathcoding_render` (`bin/Mathc.exe`, `tests/render_kernel.exe`,
   `bin/md_probe.exe`). Цикл «поправил → собрал» стоит ощутимо.
2. **Audit-границы.** `lib/render/render.ml:2802` (по умолчанию
   `enable_mathjax = true`) и `:2747` (RSS `pubDate` хардкод
   `"Mon, 12 Oct 2026 14:30:00 GMT"`) — оба комментария ссылаются
   на решения `mathjax-delimiter-hardening-2026-10@1` и т.п.
   Когда всё в одном файле, эти обоснования размазываются по 3000
   строк и ревью их пропускает.
3. **Изоляция изменений.** Любая правка в YAML-сабсете (кластер 6)
   сейчас формально задевает и `md_parse`, и `nav_groups`, и
   `render_dashboard`. Это даёт ложное «blast radius» в diff-статах
   и в `git blame`.
4. **Test granularity.** `tests/render_kernel.ml` грузит весь модуль
   сразу; низкоуровневый парсер (`md_inline_parse`) нельзя
   дёрнуть из теста без подъёма всего `mathcoding_render`. Это
   видно в строках 58, 192, 206, 218… — каждый тест зовёт
   `Render.md_parse` верхнего уровня.
5. **Traps в `OCAML_BEST_PRACTICES.md:§11`.** Любой долгий
   набор под-парсеров в одном файле ловит §11.24 (nested-match
   edit-loop) и §11.34 (per-binary test gating).

## 3. Контрпример

**Сильнейший контрпример к разделению.** «Markdown subset
(кластер 1) и YAML subset (кластер 6) переиспользуют одни и те
же под-функции (`indent_of`, `trim_block_lines`)». Если это так
после поверхностного прочтения — разделение YAML-сабсета в
отдельный модуль породит циклическую зависимость между
`render_yaml.ml` и `md_subset.ml`.

**Ответ (что показывает код).** Сейчас `indent_of`/`trim_block_lines`/
`find_top_key`/`block_end` живут на строках 1670–1796 и
используются только `render_decision_yaml`, `render_yaml_*`,
`strip_boilerplate` и `render_spec_page` (через
`render_decision_yaml`). `md_parse` их **не зовёт** — он работает
со строками по `#`-префиксам, а не по YAML-индентам. Значит,
YAML-сабсет самодостаточен и может стать отдельным модулем
(`render_yaml.ml`) без циклов.

Слабый контрпример: «после разделения под-модулей поведение
рендера разойдётся с уже сделанными golden-снапшотами». Здесь
защита — cram-снапшоты `tests/cli/render.t` (28+ кейсов) и
1362-строчный `tests/render_kernel.ml`; любая регрессия
зажжёт хотя бы один тест ещё до того, как доберётся до PR.

## 4. Планы (Phase 1+)

Раскладка на **5 фаз**, каждая — отдельная ветка и
отдельное решение (по протоколу P1 каждое задевает `lib/`).
Все фразы ниже — это уже *содержимое* будущих
`decisions/render-module-split-phaseN-2026-10.yaml@1`,
а не новые обязательства «сверху».

### Phase 1A — `render_md.ml` (Markdown subset, 750 строк)
- Новый модуль `lib/render/render_md.ml`. Содержит кластер 1
  (строки 30–779 текущего файла) плюс вспомогательный
  `String_set` (строго локальный — сейчас он шарится между
  Markdown и `build_pages`).
- Экспортирует: `Render.html_escape`, `Render.html_of_fragments`,
  `Render.md_inline_parse`, `Render.md_inline`, `Render.code_fence_tag`,
  `Render.md_parse`. Всё остальное в `render.ml` ссылается на них
  через `Render.Md.*` (внутренние callsite-переименования
  допустимы — публичные имена сохраняются).
- Зависимости: `mathcoding_core`, `unix`, `str`.
- Риск: пересечение по `Buffer.create 64` на 70-й строке
  (html_of_fragments используется и в `md_parse`, и в
  `render_yaml_object_list_section`). Решение — оставить
  `html_of_fragments` в `render_md.ml` и сделать
  его частью публичной поверхности этой фазы; `render_yaml.ml`
  импортирует `Render.Md.html_of_fragments`.

### Phase 1B — `render_nav.ml` (Navigation + chrome, 480 строк)
- `lib/render/render_nav.ml`. Кластеры 2, 3, 4 (строки 780–1279).
- Экспортирует: `Render.nav_groups_en/ru/zh`, `Render.nav_groups_for`,
  `Render.lang_href_for`, `Render.sibling_translation_href`,
  `Render.github_origin`, `Render.github_blob`,
  `Render.render_nav`, `Render.render_footer`,
  `Render.render_head`, `Render.render_page`.
- Зависимости: `Render.Md.html_escape` (из 1A).
- Здесь же — единственный новый публичный символ: тип `Render.nav_link`
  и `Render.nav_group` сейчас экспортируются как типы верхнего
  уровня; они переезжают в сигнатуру `render_nav.ml`.

### Phase 1C — `render_pages.ml` (Index + Decision + Axiom/Spec, ~920 строк)
- `lib/render/render_pages.ml`. Кластеры 5, 6, 7 (строки 1279–2281).
- Экспортирует: `Render.render_axioms_section`, `Render.render_index`,
  `Render.render_index_ru`, `Render.render_index_zh`,
  `Render.render_decision_page`, `Render.render_decision_yaml`
  + YAML-хелперы (`indent_of`, `trim_block_lines`, `find_top_key`,
  `block_end`, `top_scalar`, `top_block`, `top_object_list`,
  `top_string_list`) + `Render.render_yaml_*`, `Render.strip_boilerplate`,
  `Render.render_spec_page`, `Render.render_axiom_page`.
- Зависимости: `Render.Md.*` (из 1A), `Render.Nav.*` (из 1B),
  `mathcoding_core`.
- Решение про YAML-сабсет: выделить ли его ещё в `render_yaml.ml`
  внутри фазы 1C? **Нет** — это сделает Phase 1D, чтобы 1C
  оставался ≤ 1000 строк (см. §OCaml_BEST_PRACTICES §3 про
  размер модуля).

### Phase 1D — `render_yaml.ml` (YAML subset, 230 строк)
- `lib/render/render_yaml.ml`. Кластер 6а (YAML-хелперы и рендеры).
- Экспортирует: `Render.indent_of`, `Render.trim_block_lines`,
  `Render.find_top_key`, `Render.block_end`, `Render.top_scalar`,
  `Render.top_block`, `Render.top_object_list`,
  `Render.top_string_list`, `Render.render_yaml_section`,
  `Render.render_quad`, `Render.render_yaml_list_section`,
  `Render.render_yaml_object_list_section`,
  `Render.strip_boilerplate`, `Render.render_yaml_obligations_section`,
  `Render.render_decision_yaml`.
- Зависимости: `Render.Md.html_escape`, `Render.Md.html_of_fragments`.
- Тип `Render.yaml_block` (строка 1662) переезжает сюда.

### Phase 1E — `render_extras.ml` (RSS + dashboard + graph, 360 строк)
- `lib/render/render_extras.ml`. Кластер 9 (строки 2686–3040).
- Экспортирует: `Render.rss_escape`, `Render.extract_intent_summary`,
  `Render.render_rss_feed`, `Render.render_dashboard`,
  `Render.render_graph_html`, тип `Render.rss_decision_item`.
- Зависимости: `Render.Md.html_escape`, `Render.Nav.render_head` (для
  единства head-блока dashboard/graph), `mathcoding_core`.
- Здесь же `Render.default_config` (строка 2802) — он шарится
  с `Render.config` (тип) и должен жить рядом с тем, кто этот
  тип определяет. Решение: оставить `type config` и `let default_config`
  в **главном** `render.ml` (см. Phase 1F), а в `render_extras.ml`
  импортировать — иначе циклическая зависимость
  `render_extras ↔ render`.

### Phase 1F — главный `render.ml` (оркестратор, ~50 строк)
- `lib/render/render.ml`. Только оркестратор + публичный фасад:
  - `type page = { path : string; body : string }`
  - `type config = { site_base : string; enable_mathjax : bool;
                     enable_lang_toggle : bool; languages : string list;
                     version : string }`
  - `let default_config = { ... }`
  - `let default_version = "math-coding"`
  - `let read_version_file ~fallback = ...`
  - `let read_spec_files () = ...`
  - `let build_pages ~package_html ~decisions_data ~policy_id ~config = ...`
- Этот файл — единственная точка, через которую `bin/Mathc.ml` и
  `tests/render_kernel.ml` общаются с рендером. Его сборка
  триггерит пересборку всех 5 под-модулей → `mathcoding_render`.
  Это **самое узкое** место по compile time, поэтому
  в нём минимум кода.

### Финальный граф зависимостей (после Phase 1F)

```text
bin/Mathc.ml, bin/md_probe.ml, tests/render_kernel.ml
                ↓
        render.ml  (orchestrator + public types)
                ↓
   ┌────────┬────┴────┬────────┬─────────┐
   │        │         │        │         │
 render_md  render_  render_  render_  render_
            nav       pages    yaml     extras
                ↓         ↓
        mathcoding_core + str + unix
```

Циклов нет (см. §3 контрпример).

## 5. Evidence-план для Phase 1A–F

| Фаза | Обязательство (verifier) | Источник | Файл теста |
|---|---|---|---|
| 1A | `md_parse` идентичен до/после на 14 кейсах | golden-снапшоты | `tests/render_kernel.ml` строки 192–345 |
| 1A | `html_escape` идентичен | прямые assert'ы | `tests/render_kernel.ml` строки 50–60 |
| 1B | nav-группы идентичны (en/ru/zh) | cram `tests/cli/render.t` | `nav.en.html`, `nav.ru.html` |
| 1B | `render_head` для mathjax-ON/OF идентичен | golden | `tests/render_kernel.ml` строки 75–98 |
| 1C | `dist/index.html`/`index.ru.html`/`index.zh.html` идентичны | cram | `tests/cli/render.t` |
| 1C | per-decision страницы идентичны | cram | `tests/cli/render.t` |
| 1D | `render_decision_yaml` идентичен | cram | `tests/cli/render.t` |
| 1D | YAML-хелперы unit-тесты | новые | `tests/render_yaml_test.ml` (новый файл, ~60 строк) |
| 1E | `dist/rss.xml` идентичен | cram | `tests/cli/render.t` |
| 1E | `dist/dashboard.html` идентичен | cram | `tests/cli/render.t` |
| 1E | `dist/graph.html` идентичен | cram | `tests/cli/render.t` |
| 1F | `build_pages` идентичен | cram `tests/cli/render.t` | end-to-end |
| 1F | `Render.config`, `Render.default_config`, `Render.page` — type-identical | ручная проверка сигнатур | n/a |

Каждая фаза добавляет **не менее одной положительной и одной
отрицательной фикстуры** в соответствующий файл (требование P2
AGENTS.md).

## 6. Референсный класс времени

`bin/data/time-distribution.yaml` (SWE-bench Verified n=500):

- класс `refactor` — P50=12 мин, P95=45 мин (одна фаза)
- класс `multi-file-edit` — P50=9 мин, P95=30 мин (один .ml-файл)
- класс `kernel-change` — P50=40 мин, P95=150 мин (фаза с правкой
  в `lib/` + новое решение + аттестация)

Каждая из фаз 1A–1F — это **refactor + multi-file-edit**:
перенести ~500–900 строк в новый файл, поправить 6 callsite'ов
(`bin/Mathc.ml`, `bin/md_probe.ml`, `tests/render_kernel.ml`,
`lib/dune`, `bin/dune`, `tests/dune`), прогнать тесты.

P50 одной фазы: 12 мин (refactor) + 9 мин × 2 (multi-file × 2
fileset'а) ≈ 30 мин wall-clock.
P95 одной фазы: 45 + 30×2 ≈ 105 мин wall-clock.

На 6 фаз суммарно: **P50 ≈ 3 часа**, **P95 ≈ 10 часов**
wall-clock. Это вне под-строки **kernel-change P95=150 мин**
потому, что split — не одна правка, а серия из 6
behavior-preserving переносов.

## 7. План коммитов и веток

| Ветка | Решение | Парная аттестация | Тест-обязательство |
|---|---|---|---|
| `render-md-split-2026-10` | `decisions/render-module-split-phase1a-2026-10.yaml@1` | `attestations/render-module-split-phase1a-md-identical.json` | `tests/render_kernel.exe` pass |
| `render-nav-split-2026-10` | `…-phase1b-2026-10.yaml@1` | `…-phase1b-nav-identical.json` | `dune build` + cram `render.t` |
| `render-pages-split-2026-10` | `…-phase1c-2026-10.yaml@1` | `…-phase1c-pages-identical.json` | cram full |
| `render-yaml-split-2026-10` | `…-phase1d-2026-10.yaml@1` | `…-phase1d-yaml-identical.json` | `tests/render_yaml_test.exe` |
| `render-extras-split-2026-10` | `…-phase1e-2026-10.yaml@1` | `…-phase1e-extras-identical.json` | cram `rss+graph+dash` |
| `render-orchestrator-2026-10` | `…-phase1f-2026-10.yaml@1` | `…-phase1f-orchestrator-identical.json` | e2e |

Каждая ветка живёт в отдельном ворктри
(`feat/<slug>-2026-10`), каждая — отдельный PR в `main`.
Между фазами `main` уже содержит результат предыдущей фазы
(merge-first, rebase-second).

## 8. Что я НЕ предлагаю

- Никаких новых публичных API. Это чистая перетасовка файлов.
- Никакой правки `lib/packages.ml`, `bin/Mathc.ml::do_render`,
  тестов. Только переименование внутренних callsite'ов
  (`Render.html_escape` → `Render.Md.html_escape`) там, где они
  приватные.
- Никаких merge всех 6 фаз в один PR. Потеряем и атомарность
  отката, и granular review.

## 9. Точки, которые я хочу подтвердить с пользователем

1. Нужен ли отдельный `tests/render_yaml_test.ml`, или YAML-сабсет
   тестируется только через `tests/render_kernel.ml` (по аналогии
   с тем, что сейчас нет `tests/render_nav_test.ml` и это
   работает через cram)?
2. Должна ли `lib/render/render.ml` после Phase 1F быть
   ≤ 100 строк, или комфортно ≤ 200?
3. В каком порядке сливать: 1A → 1B → 1C → 1D → 1E → 1F,
   или начать с 1F (orchestrator) и раскручивать «вниз» к 1A?
   Я бы шёл **снизу вверх** (1A → 1F), потому что orchestrator
   меняется последним → проще держать `main` green.

## 10. Knowledge delta (для коммита-сообщения)

```yaml
changed:
  - docs/plans/render-module-split-phase1-2026-10.md   # новый плановый документ
  - decisions/render-module-split-phase1a-2026-10.yaml # draft, режим light
preserved:
  - lib/render/render.ml                                # не тронут
  - bin/Mathc.ml, bin/md_probe.ml, tests/render_kernel.ml
evidence:
  - docs/plans/render-module-split-phase1-2026-10.md   # самодостаточен
new_assumptions:
  - YAML-сабсет (кластер 6а) самодостаточен и не зависит от md_parse
  - контрпример из §3 проверен поверхностным чтением, не unit-тестом
remaining_unknowns:
  - точный транскрипт предыдущей Paseo-сессии
    wks_7088cec3bcfba2ed «Анализ сессии рендера и план»
    — не доступен; план построен по текущему состоянию
    репозитория и тексту решения render-module-split@1
```

## 11. Связанные документы

- Решение: `decisions/render-module-split.yaml@1` (Phase 0).
- Коммит: `eb0a38b refactor(render): move lib/render.ml into separate mathcoding_render library`.
- Merge: `a73b6a6 Merge render-split-2026-10: split lib/render.ml into mathcoding_render library`.
- Тест-каркас: `tests/render_kernel.ml` (1362 строки), `tests/cli/render.t` (cram).
- Смежные решения: `decisions/render-kernel-fixes-2026-10.yaml@1`,
  `decisions/render-dashboard-2026-10.yaml@1`,
  `decisions/render-ordered-lists-2026-10.yaml@1`,
  `decisions/zh-render-2026-10.yaml@1`.
- Traps: `OCAML_BEST_PRACTICES.md:§11.24` (nested-match edit-loop),
  `OCAML_BEST_PRACTICES.md:§11.34` (per-binary test gating).
- Аксиомы: A0 (observability), A3 (provenance), A4 (intent→evidence).