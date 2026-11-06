# Форматы: v3 против v4 — где лежат решения и что с ними стало

> Автор: агент по поручению Petr Kosov <p.b.kosov@yandex.ru>
> Дата: 2026-11-06
> Статус: разбор. Ничего не объявляет и не чинит — описывает, где
> лежит работа в четвёртой версии и что от третьей при этом
> сохранилось.
>
> Все числа в этом документе пересчитаны по дереву, и процедура
> пересчёта приведена рядом с ними: число, у которого нет носителя,
> здесь не появляется.

## Короткий ответ

В третьей версии решение было **файлом на решение**: `decisions/*.yaml`,
134 файла, у каждого 28 полей, из них обязательные — `intent`,
`commitment`, `scope`, `outcomes`, `obligations`. Цепочка была
цельной: замысел → контракт → обязательства → аттестация, привязанная
к коммиту и к содержимому.

В четвёртой версии решения как вида сущности **нет**. Есть две единицы:

| Единица | Где | Что это |
|---|---|---|
| **Правило** | `spec.json`, поле `claims[]` | утверждение: предмет, требования, опровержитель, регистр |
| **Работа** | `waves/*.json` | единица плана: замысел, проверки, обязательства, возражение, чем опровергается |
| **Доказательство** | `.math/trail.jsonl` | что исполнилось, чем закрыто, на чём и когда |

Итого три файла и 259 строк на весь метод. Решение живёт в git:
сообщения коммитов и ревью — это и есть его след.

## Что лежит в третьей версии

Проверено по ветке `feat/v3-line-2026-11`:

```text
решений:                 134 файла
строк в них:             36 570
полей в схеме решения:    28
обязательных:             7 (schema, id, intent, commitment, scope, outcomes, obligations)
кода в lib/ и bin/:      32 349 строк (49 файлов)
архивных решений:        148, из них со state: active — 104
```

Что означали ключевые поля:

- **`intent`** — замысел с обоснованием: какой пробел, почему так, что
  отброшено, с ревизиями («revision 2: …»). Рассуждение решения.
- **`commitment`** — **контракт**, а не отметка. Пример из
  `decisions/adapters.yaml`: «`bin/Mathc.ml` gains two new subcommands:
  `attest FILE` and `assess BASE HEAD`», коды выхода (0 — успех, 2 —
  неверный путь, 3 — необработанное исключение), состав ключей JSON,
  «the kernel remains unchanged». Это проверяемое утверждение о том,
  что будет верно.
- **`obligations[]`** — каждое со своим MUST-утверждением и
  `acceptance.verifier`.
- **аттестация** — `subject{decision, decision_digest, obligation,
  obligation_digest, candidate_tree, materials_digest}`, `producer`
  с классом (`human:` / `agent:` / `ci:`), `valid_until`, `issued_at`.
  Это и был тот якорь, который связывал решение с тем, что сделано:
  `candidate_tree` — коммит.

## Что лежит в четвёртой версии

```text
spec.json:        101 строка   цель, бюджет, закрытые волны, 8 утверждений
waves/*.json:     111 строк    4 единицы работы
.math/trail.jsonl: 47 строк    доказательства (не в git)
```

Утверждение: `id`, `subject{text, scope[]}`, `requirements[{kind,
spec}]`, `falsifier`, `register`, `accepted`. Доказательство: `claim`,
`kind`, `requirement`, `outcome`, `bound_to` (дайджест содержимого),
`producer`, `reason`, `at_commit`, `at`, `valid_until`.

Волна: `id`, `title`, `intent`, `touches`, `checks`, `claims`,
`commitment[{claim, state}]`, `objection`, `refuted_by`.

## На какой вопрос отвечает каждая форма

| Вопрос | v4 | v3 |
|---|---|---|
| что верно сейчас | `claim.subject` + область, **вычисляется** | `commitment` / `outcomes`, хранится |
| чем это проверено | `requirement` (команда) + доказательство | `acceptance.verifier` + аттестация |
| кто подтвердил и когда | `producer` + `at` + `at_commit` | `producer` с классом + `issued_at` |
| протухло ли доказательство | дайджест содержимого **и** срок (`valid_until`) | `valid_until` + `materials_digest` |
| **каким изменением закрыто обязательство** | **`at_commit` — коммит, из которого взято содержимое** | `candidate_tree` + `obligation_digest` |
| **почему так решили** | **`intent` волны** | `intent` решения |
| **что обязано стать верным, точно** | **`commitment` волны: какое утверждение в каком состоянии** | `commitment` (контракт) + `obligations[]` |
| автор и дата решения | только у цели (`by`/`at`) | `id`, `revision`, `state`, `time` в каждой записи |
| цена для адоптера | один закоммиченный файл (`spec.json`) плюс след `.math/` в дереве | 20 650 строк YAML на `wavecode` — 14% текста проекта |

## Диалектика

**Тезис (v3).** Решение без контракта — пожелание; свидетельство без
якоря — рассказ. Хранить надо и замысел, и обязательство, и
доказательство, привязанное к конкретному артефакту.

**Антитезис (v4, до нынешней правки).** Корпус — могила метода:
36 570 строк YAML против 32 349 строк кода, который он охранял; 104
архивные записи продолжали говорить `state: active`; цена падала не на
метод, а на чужой репозиторий.

**Синтез.** Разделение было верным, но в одну кучу попали и дорогое, и
дешёвое:

- **Дорогое и неверное** — хранить замысел и контракт в каждой из
  134 записей. Это 273 строки YAML на решение, чтобы сказать то же,
  что четвёртая версия говорит строкой `subject` и одним требованием.
- **Дешёвое и стоящее** — **три якоря**, и все три теперь есть:
  1. к **содержимому** (`bound_to`) — был и в v3, и в v4; в v4 он
     лучше: свежесть вычисляется, а не хранится, и вредный
     «wildcard» закрыт;
  2. к **акту** (`at_commit`) — был в v3 (`candidate_tree`), был потерян
     вместе с корпусом, восстановлен 06.11;
  3. **срок** (`valid_until`) — был в v3, был потерян, восстановлен
     06.11.
- И **точность контракта**: в v4 проверяемая часть утверждения —
  команда, а содержание команды метод не проверяет (принцип П1
  частично, и так честно записано). Обязательство волны эту точность
  возвращает в том виде, в каком она проверяема: «какое утверждение
  будет в каком состоянии».

## Чего в v4 по-прежнему нет — и почему это не дефект

- **Единицы «решение».** Её нет намеренно: решение — это то, что
  человек сказал, и его след в git; метод оперирует правилами и
  работой. Вернуть единицу «решение» — значит вернуть корпус, а с ним
  и 14% чужого проекта, и второй источник истины.
- **Содержания команды проверки.** Метод не знает, что именно
  проверяет команда: он её исполняет. Это и есть та половина П1,
  которая остаётся частичной, и метод говорит об этом прямо.
- **Аутентификации.** `review:owner` закрывается записью с любым
  `--by`. Метод атрибутирует и делает изменения видимыми — и это всё,
  что он обещает.

## Проверка чисел

```sh
# решения и строки в них (ветка v3)
git ls-tree -r --name-only feat/v3-line-2026-11 | grep -c '^decisions/.*\.yaml$'
git ls-tree -r --name-only feat/v3-line-2026-11 | grep '^decisions/.*\.yaml$' \
  | while read f; do
      git cat-file blob "$(git rev-parse feat/v3-line-2026-11:"$f")" | wc -l
    done | awk '{s+=$1} END {print s}'

# код v3 в lib/ и bin/
git ls-tree -r --name-only feat/v3-line-2026-11 | grep -E '^(lib|bin)/.*\.ml$' \
  | while read f; do git show feat/v3-line-2026-11:"$f"; done | wc -l

# архивные решения, которые продолжали говорить active
git ls-tree -r --name-only feat/v3-line-2026-11 | grep '^archive/decisions/.*\.yaml$' \
  | while read f; do
      git show feat/v3-line-2026-11:"$f" | grep -m1 '^state:' | grep -q 'active' && echo x
    done | wc -l

# текущий метод
wc -l spec.json waves/*.json .math/trail.jsonl
```

## Одна оговорка о числах, которые здесь не названы

В отчёте о родстве написано, что `spec/kernel-contract.md` расходится
с кодом в 18 местах. Это **не измерение**: тот же отчёт приводит
проверку этого числа и её результат — «список D-1…D-18 в репозитории
отсутствует; проверяемы только три названных пункта» (`docs/
METHODOLOGY-LINEAGE-2026-11.md`, раздел «Расхождения»). Проверенных
случаев пять: три подтверждены (порог `counterexample`, пять статусов
`re-evaluation`, невызываемые фазы `pre_release`/`post_release`), один
оказался протухшим (лаундеринг подписи, исправлен коммитом
`35015a6d` за неделю до разбора), и один не подтвердился (тот самый
список D-1…D-18).

Поэтому число 18 в чужой прозе не повторяется здесь как факт. Число,
у которого нет носителя, — это ровно то, чем был этот замер до
06.11.

## Как устроены форматы — словами, которые стоят у кода

Это пересказ кодекa: как читаются и пишутся обе формы. Код —
спецификация для исполнения; этот раздел — для чтения.

The formats, and the only place they are read.

    A format is read by a library, never by a parser of our own. The
    third version wrote its own YAML reader and lost data in ways
    nobody noticed for months; the rule against hand-written parsers
    came out of that loss, and this file is the rule being kept.

    The two formats are the standing specification of a project and the
    wave. Both are strict: an unknown field is an error, not silence.
    A format that silently ignores what it does not understand is a
    format that lets an agent believe it did something it did not.

    The shapes are chosen so that a translation into a formal modelling
    language is a mapping and not a rewrite. A claim, a scope of paths,
    an evidence, a verdict: four entities and three relations. That is
    all a temporal model of this method needs.

A parse failure, with the reason a human can act on.

(* Sequencing for results. Reading a format is a sequence of
   requirements, and the first failure is the one worth reporting.

The error, as a sentence. A refusal must be READABLE: the callers
    print this, and before this function existed they had to raise an
    exception to get a string out of an error - so a malformed file
    killed the tool with a stack trace instead of saying what was
    wrong with it.

(* ------------------------------------------------------------------

(* Strict object reading.

(* ------------------------------------------------------------------

Read an object with exactly the given fields. An unknown field is
    an error: the whole point of a strict format is that a typo is
    loud. A format that silently ignores what it does not understand is
    a format that lets an agent believe it did something it did not.

(* ------------------------------------------------------------------

(* The standing specification.

(* ------------------------------------------------------------------

Parse one claim. Every field is required, and the scope must not be
    empty: a claim about nothing is not a claim. Whether the scope
    names anything in the tree is the adapter's business - see
    [Verdict.law_no_vacant_subject] and the rule the adapter enforces
    on top of it.

The requirements of a claim: how it must be closed. Each one names
    a kind - a command, or an authority - and the thing itself. All of
    them are required: a rule closed by one of two means is not the
    rule that was stated.

What an attestation concluded.

The proofs that came from outside, and must not be lost.

    They are optional: a specification written before this field
    existed is still a specification, and the attestations start
    empty. Each one names the requirement it closes - by the thing it
    names, the way `record` does - who produced it, what it concluded,
    the subject it was produced against, and when.

Parse the aim. It is optional in the file - a project that has not
    stated one yet is a project the method accepts claims from
    nowhere, and [mathc add] is where that is refused.

Parse the standing specification: the aim, the price of uncertainty
    the project agreed to pay, and the claims.

    The budget is required. A budget nobody declared is not finite, and
    an uncertainty that costs nothing makes "I do not know" cheaper
    than checking - which is the free escalation the principle exists
    to stop.

(* The closed waves are optional: a specification written before
         this field existed is still a specification, and the plan's
         progress starts empty.

Write the specification back. The file is machine-managed: it is
    read and written by the method, and the aim and the claims are
    data in it.

(* ------------------------------------------------------------------

(* The wave.

(* ------------------------------------------------------------------

The state, as the outside writes it.

    The names are the shape of the outside, so they live in the codec
    and not in the core: the core holds the states as values, and two
    places - the map and the wave's promises - have to say the same
    thing about them. A name written twice is two truths.

The promises of a wave: which claim, and which state it will be in
    when the wave is done.

Parse a wave: a finished, green slice of work.

    The wave carries THREE things the older format kept in a file per
    decision: the intent (why this unit of work), the promise (which
    claim will be in which state when it is done) and the dialectic
    (the strongest objection and what would refute it). The promise
    is the part that can be checked, and the check is the closing of
    the wave.

