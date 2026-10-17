# HTML-шаблоны в файлах — дизайн-документ

> Дизайн-документ. Сессия: `wks_c10629bbd41628bf` «Анализ кода и выделение рендера».
> Базовая ревизия: `a73b6a6` (main). Автор: агент сессии. Дата: 2026-10-17.
> **Замещает** подход из `docs/plans/render-module-split-phase1-2026-10.md`
> (тот предлагал 6-фазный сплит «ради сплита»; после диалектики с
> пользователем цель переопределена: HTML — в файлы, чистота — восстановить,
> дубликат — убрать, новые зависимости — не тащить).

## 0. Цель

Вынести статический HTML из `lib/render/render.ml` в шаблонные файлы,
свести три копии домашней страницы (`render_index` / `render_index_ru` /
`render_index_zh`) к одной функции, и при этом вернуть рендеру
**задекларированную, но нарушенную чистоту** (см. §3). Ноль новых
зависимостей.

## 1. Принципы качества, по которым сверяемся

Цитаты из `OCAML_BEST_PRACTICES.md` (это стандарт проекта, не внешняя
эстетика):

- **§1.3 — «No I/O in lib/».** Кернел — side-effect-free, детерминирован.
  `spec/constitution.md:127` требует: *«equal canonical inputs and equal
  evaluation time produce equal verdicts»*.
- **§2.1 — «variants over strings».** Если поле — «одно из N», это вариант,
  а не строка.
- **§2.5 — «records vs tuples».** Для 3+ полей — record, не кортеж.
- **§4.1 — «Result vs exception»** — ошибки ловятся на границе `bin/`, не
  размазаны `try … with _ -> None` по `lib/`.
- **§1.2 — boundary.** `bin/` делает argv/I/O/exit; `lib/` — чистые функции.

## 2. Диагноз текущего состояния (что именно нечисто)

`render.ml` начинается с комментария (строки 26–28):

> «The render function is pure: it takes a `reader` callback …
> The dispatcher is the only caller that performs I/O.»

Но фактически I/O происходит **внутри** `lib/render/`:

| Место | Что делает | Нарушение |
|---|---|---|
| `read_spec_files ()` (2328) | `Sys.readdir`, `open_in_bin` по `spec/` | §1.3 |
| `read_version_file` (2282) | читает `./VERSION`, лезет в `DUNE_SOURCEROOT` | §1.3 |
| `default_config` (2802) | зовёт `read_version_file` при конструировании | §1.3 |
| `config.languages : string list` (2268) | stringly-typed `"en"/"ru"/"zh"` | §2.1 |
| `site_pages : (string * string * string) list` | тройка `(name, title, body_md)` | §2.5 |
| `DUNE_SOURCEROOT` в `read_spec_files`/`read_version_file` | инфильтрация build-системы в логику | §1.3 дух |

При этом **хорошая половина уже правильная**: `bin/Mathc.ml` уже читает
`site/*.md` (`load_md`) и `VERSION` (`read_cli_version`) и передаёт их в
`Render.build_pages` как данные. Чистота нарушена ровно в двух функциях и
двух типах — а не системно. Это чинится точечно.

## 3. Ключевое дизайн-решение: граница выноса

Не выносить в файлы **всё** — выносить только то, что является *данными*.
Условную/динамическую сборку оставляем в коде, но параметризуем.

| Текущая функция | Строки | Что это | Решение |
|---|---|---|---|
| `render_index` / `_ru` / `_zh` | 1290–1645 | статичный HTML + 2 подстановки (`version`, `policy_id`) | **→ файлы** `index.en/ru/zh.html`, функция схлопывается в одну |
| `render_dashboard` | 2862–2954 | статичный HTML | **→ файл** `dashboard.html` |
| `render_graph_html` | 2955–3039 | статичный HTML | **→ файл** `graph.html` |
| `render_head` | 1202–1248 | условный (MathJax script on/off) | остаётся в коде |
| `render_nav` | 1019–1140 | условный (active link, lang toggle) | остаётся в коде |
| `render_footer` | 1141–1201 | условный (sibling langs) | остаётся в коде |
| `render_page` | 1249–1274 | скелет-сборка | остаётся в коде |
| `render_decision_page` + YAML-сабсет | 1646–2180 | динамика из `decisions_data` | остаётся в коде |
| `render_spec_page` / `render_axiom_page` | 2181–2280 | контент из файлов | остаётся в коде |
| `render_rss_feed` | 2747–2800 | цикл по `<item>` | остаётся в коде |
| `read_spec_files` / `read_version_file` | 2282–2360 | I/O | **переезжают в `bin/`** |

**Почему граница именно здесь.** `{{var}}`-подстановка покрывает только
простую замену строк. Условные блоки (MathJax, lang-toggle, sibling-nav,
RSS-цикл) — это *логика*; чтобы выразить их в файлах, нужен `{% if %}` /
`{% for %}` — то есть mini-templating engine, который мы **уже решили не
писать** (см. анализ зависимостей: Jingoo/Mustache — перебор, свой — ошибка).
Поэтому в файлы уходит чистый статичный HTML; всё условное остаётся
OCaml-кодом, но с корректными типами.

Выгода от выноса — это ~1500 строк HTML и тройной дубликат `render_index`,
плюс исчезает второй источник истины (`assets/dashboard.html`/`graph.html`
↔ строки в `.ml`).

## 4. Типы

```ocaml
(* lang — вариант, не строка (§2.1). *)
type lang = En | Ru | Zh

val lang_code   : lang -> string      (* "en" | "ru" | "zh" *)
val lang_of_code : string -> lang option   (* парсинг на границе CLI *)
val lang_suffix : lang -> string      (* "" | ".ru" | ".zh" *)
val lang_page   : lang -> string      (* "index.html" | "index.ru.html" | ... *)

(* article — record, не тройка (§2.5). *)
type article = { name : string; title : string; body_md : string }

(* page — как сейчас, без изменений. *)
type page = { path : string; body : string }

(* config — languages теперь lang list, не string list. *)
type config = {
  site_base : string;
  enable_mathjax : bool;
  enable_lang_toggle : bool;
  languages : lang list;
  version : string;
}
```

## 5. Шаблоны как данные

Шаблоны читает **`bin/Mathc.ml`**, рендер получает готовый record:

```ocaml
(* lib/render/render.ml *)
type templates = {
  index : (lang * string) list;   (* En→html, Ru→html, Zh→html *)
  dashboard : string;
  graph : string;
}

val substitute : (string * string) list -> string -> string
(* substitute ["{{version}}", v; "{{policy_id}}", p] template
   — фиксированная замена, НЕ шаблонизатор. ~15 строк на Str.global_replace. *)

val render_index
  :  lang:lang
  -> version:string
  -> policy_id:string
  -> templates
  -> string
```

`read_templates` живёт в `bin/Mathc.ml` рядом с `load_md` (чтение
`render/templates/*.html`), повторяя паттерн `read_spec_files`, но **на
правильной стороне границы**.

## 6. Расположение файлов

```
render/templates/               ← источник истины, прямой UTF-8
  index.en.html
  index.ru.html
  index.zh.html
  dashboard.html
  graph.html
```

НЕ кладём в `assets/`: там лежат статические ассеты, которые копируются в
`dist/assets/` как есть, и там же уже живут «review-копии»
`dashboard.html`/`graph.html` — тот самый двойной источник истины, который
дизайн устраняет. После выноса `assets/dashboard.html` и
`assets/graph.html` удаляются; единственная копия — в `render/templates/`.

## 7. Поток данных (после)

```
bin/Mathc.ml                                  ← весь I/O здесь
  load_md (site/*.md, axioms/*.md)
  load_spec (spec/*.md)                       ← переехало из read_spec_files
  read_cli_version (VERSION)                  ← уже здесь
  read_templates (render/templates/*.html)    ← новое
    ↓  Render.render_input  (record)
Render.build_pages  (чистая: input → page list)
    ↓  page list
bin/Mathc.ml
  write_file dist/*.html, index.json, feed.xml
```

## 8. Входной record вместо десяти именованных аргументов

Сейчас `build_pages` принимает 10 аргументов. Чистое решение — собрать их
в один record, чтобы сигнатура читалась:

```ocaml
type decision_datum = string * string * string option  (* id * ob_html * yaml_body *)
type spec_file     = string * string                   (* base * body_md *)

type render_input = {
  config : config;
  package_html : string;
  policy_id : string;
  decisions_data : decision_datum list;
  articles : article list;        (* EN *)
  articles_ru : article list;
  articles_zh : article list;
  axioms : (string * string) list;   (* id * body_md *)
  spec_files : spec_file list;       (* вместо read_spec_files () *)
  templates : templates;
}

val build_pages : render_input -> page list
```

## 9. План по фазам (двух-шаговый, не «6 фаз»)

### Фаза A — типы и чистота (без HTML-файлов, поведение не меняется)

1. `type lang` + `lang_of_code`/`lang_code`/`lang_suffix`/`lang_page`.
2. `config.languages : string list` → `lang list`; обновить `bin/Mathc.ml`
   (место `match !lang_arg with "en" -> …` на 3947–3955).
3. `article` record вместо тройки `(name, title, body_md)`.
4. Перенести `read_spec_files`/`read_version_file` в `bin/Mathc.ml`; рендер
   получает `spec_files` и `version` как данные. Убрать `DUNE_SOURCEROOT`
   из `lib/`.
5. Golden-снапшоты (`tests/cli/render.t`, `tests/render_kernel.exe`) должны
   пройти без единого изменения — это *то же* поведение.

### Фаза B — HTML в файлы

1. Создать `render/templates/{index.en,index.ru,index.zh,dashboard,graph}.html`
   (кириллица — прямым UTF-8, без `\xd0`).
2. `read_templates` в `bin/Mathc.ml`; `substitute` в `lib/render/`.
3. Схлопнуть `render_index`×3 → `render_index ~lang`; удалить
   `render_dashboard`/`render_graph_html` из `.ml` (читают из `templates`).
4. Удалить `assets/dashboard.html`/`assets/graph.html`.
5. Golden-снапшоты = доказательство «ни байта не разошлось».

### Фаза C (опционально, отложить)

Разделить похудевший `render.ml` (~3040 → ~1500 строк) на
`render_md.ml` / `render_yaml.ml` — **только если** compile time реально
начнёт болеть. Не прелюдия к A/B.

## 10. Контрпримеры

1. **«Подстановка `{{var}}` сломает HTML с `{{` в тексте».** Проверка:
   в текущих шаблонах нет литеральных `{{`/`}}`; `substitute` заменяет
   ровно известные ключи, неизвестные оставляет как есть. Negative-fixture
   в тестах: шаблон с `{{unknown}}` остаётся без изменений.
2. **«Перенос кириллицы из `\xd0` в UTF-8 разъедет байты».** Отражается
   golden-снапшотом `tests/cli/render.t` — сравнение должно быть по
   раскодированному тексту, а не по escape-последовательности. Если
   diff появится — это сигнал, что RU-текст при переносе искажён.
3. **«Фаза A (перенос read_spec_files в bin) сломает тесты, которые грузят
   рендер из `_build/default/tests/`».** Мitigation: `bin/Mathc.ml` читает
   пути с явным `~root`, а `DUNE_SOURCEROOT` остаётся **только** в `bin/`
   как источник этого `root`; тесты, которые хотят чистый рендер, передают
   `spec_files` в памяти (unit-тест без ФС).

## 11. Evidence-план

| Фаза | Обязательство | Verifier | Файл |
|---|---|---|---|
| A | `config.languages : lang list` компилируется, поведение то же | `dune build` + `render_kernel.exe` | `tests/render_kernel.ml` |
| A | `read_spec_files`/`read_version_file` удалены из `lib/` | `dune build` (no-I/O grep по `lib/`) | — |
| A | golden-снапшоты без изменений | `tests/cli/render.t` cram | `tests/cli/render.t` |
| B | `render_index ~lang` выдаёт тот же HTML для En/Ru/Zh | `render_kernel.exe` (3 кейса) | `tests/render_kernel.ml` |
| B | `substitute` заменяет известные, оставляет неизвестные | unit + negative | `tests/render_kernel.ml` |
| B | `dist/dashboard.html`/`graph.html` идентичны до/после | cram | `tests/cli/render.t` |
| B | `assets/dashboard.html`/`graph.html` удалены, единственный источник | `grep` | — |

## 12. Оценка времени

Референс-класс (`bin/data/time-distribution.yaml`):

- Фаза A (типы + перенос I/O, поведение не меняется): `refactor`,
  P50 ≈ 12 мин, P95 ≈ 45 мин.
- Фаза B (HTML в файлы + `substitute` + схлопнуть index): `feature-add`
  (новый механизм подстановки) + `multi-file-edit`, P50 ≈ 20+9 ≈ 29 мин,
  P95 ≈ 70+30 ≈ 100 мин.

Суммарно (A+B): **P50 ≈ 40 мин, P95 ≈ 150 мин** wall-clock. Это один
PR-цикл, не серия.

## 13. Требование протокола

Фазы A и B задевают `lib/` → каждая требует парного решения
(`decisions/render-html-templates-2026-10.yaml@1` с двумя obligations
под фазы A и B, или два решения). Публичный API `Render.*` для вызова из
`bin/Mathc.ml` меняется в A (сигнатура `build_pages` → record) и в B
(`render_index` → `~lang`) — это контролируемое изменение контракта,
оформляется через `change_kind: implementation` + обязательство
`render-library-builds`.

## 14. Связанные документы

- `decisions/render-module-split.yaml@1` (Phase 0 — уже сделано).
- `OCAML_BEST_PRACTICES.md` §1.2, §1.3, §2.1, §2.5, §4.1.
- `decisions/render-dashboard-2026-10.yaml@1` (причина двойного источника
  `assets/dashboard.html` — устраняем).
- `decisions/render-kernel-fixes-2026-10.yaml@1` (golden-снапшоты, на
  которые опирается evidence).
- Предыдущий план: `docs/plans/render-module-split-phase1-2026-10.md`
  (замещён этим документом).