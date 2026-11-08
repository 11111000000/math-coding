# Постановки

> Author: agent on behalf of Petr Kosov <p.b.kosov@yandex.ru>
> Date: 2026-11-01
> Status: формальная часть метода. Типы, определения и законы.
> Язык — компактный, с именами по смыслу.

## 0. Четыре текста и четыре роли

| Текст | Что фиксирует | Чем проверяется |
|---|---|---|
| `GOAL.md` | зачем метод и как измеряется его полезность | измерение на чужих проектах |
| `PHILOSOPHY.md` | границы (О1–О6) и принципы (П1–П15) | — |
| **этот** | что именно утверждается: типы, определения, законы | код и его отрицательные контроли |
| код | исполняемая спецификация | сборка |

**Этот текст не вторая истина, а адресат для доказательства.** Код —
спецификация для исполнения. Эти уравнения — спецификация для
доказательства: формальный бэкенд (шаг H) строится **из них**, и
эквивалентность его ограничений этим уравнениям проверяется, а не
объявляется. Текст, который расходился бы с кодом, был бы второй
истиной; поэтому каждое уравнение ниже указывает свой носитель в коде,
а расхождение ловится сборкой.

## 1. Нотация

Записи и области — строки. `⊥` — «неизвестно» в трёхзначной логике
выводов: из `⊥` не следует `⊤`, и наоборот.

```text
Scope       := list path                  -- префиксы путей
Digest      := string                    -- хеш содержимого покрытых путей

Subject     := { text : string ; scope : Scope }
Register    := Fact | Hypothesis | Judgment | Undeclared
Requirement := Verified_by string | Reviewed_by string

Claim       := { id : string
              ; subject : Subject
              ; requirements : list Requirement
              ; falsifier : string
              ; register : Register
              ; accepted : option (who × why) }

Outcome     := Verified | Falsified | Unresolved | Refused
Evidence    := { claim : Claim
              ; requirement : Requirement
              ; outcome : Outcome
              ; bound : Digest
              ; producer : string
              ; reason : option string }

State       := Holds | Refuted | Inconclusive | NotCheckable
              | Outdated | NeverChecked | Accepted

Verdict     := Green | Red | Unknown
```

**Имена — по смыслу, и различают то, что различать надо.**

- `Verified` / `Falsified` — исход **одной** проверки: прошла / не прошла.
- `Holds` / `Refuted` — состояние **утверждения**: держится / опровергнуто.
- `Inconclusive` — проверка исполнилась и не смогла решить.
- `NotCheckable` — **машина не решает**: предмет не имеет канарейки.
- `Outdated` — свидетельство есть, но предмет с тех пор изменился.
- `NeverChecked` — заявлено и не проверено.
- `Accepted` — человек взял ответственность за неопределённость.
- `Undeclared` — утверждение не говорит, какого оно рода.

Различение `Verified`/`Holds` и `Unresolved`/`Inconclusive` — не
косметика: первое говорит о проверке, второе — об утверждении.

## 2. Определения

```text
P(scope)      := пути дерева, покрытые префиксами scope
D(scope)      := D(P(scope))                 -- дайджест содержимого
fresh(e)      := e.bound = D(subject(e.claim).scope)
state(c)      := сворачивание состояний требований c (см. A6)
verdict(S)    := Green, если S = ∅; иначе свёртка по объединению
```

`D` — хеш содержимого файлов, которые область покрывает, **в рабочем
дереве**. Он меняется ровно тогда, когда меняется содержимое, и не
меняется от того, в каком порядке область перечисляет пути.

**Рабочее дерево, а не закоммиченное.** Доказательство получается
прогоном проверок, а проверки идут по рабочему дереву; значит, и
привязка обязана быть к тому же, что прогонялось. Иначе доказательство
об изменённом файле окажется привязано к закоммиченному содержимому, и
утверждение скажет «держится» о том, чего доказательство не видело. Это
тот же «wildcard» третьей версии в новой одежде: свидетельство об одном
отвечает за другое.

Пустое множество путей даёт пустой дайджест, а пустой дайджест в
третьей версии был «wildcard свежести»: свидетельство, выданное за
свежее, совпадало с любым деревом.

## 3. Законы

Каждый закон — утверждение о типе из §1. Справа — носитель в коде.

### A1. Агрегация есть моноид

```text
combine(Green, x)  = x                    combine(x, Green)  = x
combine(Red, x)    = Red                  combine(x, Red)    = Red
combine(Unknown, Unknown) = Unknown
combine(Unknown, Green)  = Unknown        combine(Green, Unknown) = Unknown
```

Отсюда: `combine` коммутативен и ассоциативен. `Green` — единица,
`Red` — поглотитель.

*Носитель:* `Verdict.combine` (`lib/verdict.ml`).
*Контроль:* `Verdict.law_commutative`, `law_associative`, `law_unit`,
`law_absorbing`, `law_order`.

### A2. Пустое множество — зелёное

```text
verdict(∅) = Green
```

Пустой набор утверждений — не дефект. Внедрение не должно платить за
то, что ещё не начато.

**И пустой ПРОЕКТ — не пустой каталог.** Закон о пустоте говорит о
проекте, который сказал о себе, что он проект: у него есть спецификация,
и множество его утверждений пусто. Каталог, в котором спецификации нет,
не проект, и о нём метод **не знает ничего** — а «не знаю» и «всё
хорошо» это разные ответы, и второй неправдив.

Ложный зелёный был ровно этой формой: загрузчик спецификации при
отсутствии файла возвращал пустую спецификацию, и карта считала по ней
вердикт и печатала «green». Каталог, который метод никогда не видел,
получал чистый диагноз. Теперь такого каталога нет: метод говорит, что
здесь нет стоящей спецификации, и выходит с кодом «не знаю».

*Носитель:* `Verdict.law_vacancy_is_green`; пустой каталог — `load_spec`
(нет спецификации — нет ответа, а не пустой ответ).

### A3. Привязка определяет свежесть

```text
fresh(e)  ⟺  e.bound_to = D(subject(e.claim).scope)
```

Свидетельство привязано к предмету **и к его содержимому**. Результат
без привязки — рассказ, переживающий изменение предмета.

И **срок действия доказательства** — второе условие свежести:

```text
fresh(e)  ⟺  e.bound_to = D(scope)  ∧  (e.valid_until = ⊥ ∨ now < e.valid_until)
```

Привязка отвечает на вопрос «то же ли содержимое?»; срок — на вопрос
«действует ли ещё это доказательство?». Доказательство может быть о
самом нужном содержимом и при этом протухнуть: выкатка сменилась,
зависимость обновилась, ревью относилось к уже вышедшему релизу. Ни
содержимое, ни истинность этого не видят — видит только срок.

*Носитель:* `Verdict.state_of_evidence`, `Verdict.expired`,
`Verdict.law_expired_is_never_verified`, `Verdict.law_outdated_is_never_verified`.
*Контроль:* сломанная реализация — та, что игнорирует срок, — отвергается
законом (см. `test/laws.ml`).

### A4. Протухшее не бывает держащимся

```text
∀ e ∈ Evidence, ∀ c :
    e.claim = c ∧ ¬fresh(e)  ⟹  state(c) ≠ Holds
```

Доказательство, относящееся к вчерашнему предмету, сегодня не является
доказательством. **Никогда** — ни в одну сторону.

*Носитель:* `Verdict.law_outdated_is_never_verified`.

### A5. Регистр запрещает машине решать

```text
∀ c : register(c) = Judgment  ⟹
    ∀ o ∈ Outcome : apply_register(Judgment, o) ∉ {Verified, Falsified}
```

Суждение не может быть ни подтверждено, ни опровергнуто машиной: упавшая
процедура — факт о процедуре, а не опровержение того, что должно быть
истинным о смысле. Отказ двусторонний.

*Носитель:* `Verdict.apply_register`, `law_judgment_is_never_verified`.

### A6. Состояние утверждения — свёртка состояний требований

```text
state(r) = Holds          если свежее свидетельство с исходом Verified
          | Refuted        если свежее свидетельство с исходом Falsified
          | Inconclusive   если свежее свидетельство с исходом Unresolved
          | NotCheckable   если свежее свидетельство с исходом Refused
          | Outdated       если свидетельство есть, но не свежее
          | NeverChecked   если свидетельства нет

state(c) = Refuted        если какое-то требование Refuted
          | NotCheckable   иначе, если какое-то требование NotCheckable
          | Holds         иначе, если все требования Holds
          | NeverChecked  иначе, если ни одно требование не проверено
          | Outdated      иначе, если все требования проверены, но устарели
          | Inconclusive  иначе (закрыто не всё)
```

Порядок уточнений не произволен: **одно опровергнутое требование
решает всё** — истина о части есть, истина о целом ложна. Требование,
которое машина решить не может, означает «нечем проверить» и не даёт
утверждению быть держащимся. Иначе — по виду неопределённости: если
не проверено ничего, утверждение **не проверено**; если проверено, но
предмет с тех пор изменился — **протухло**; если закрыто не всё —
**неизвестно**.

Требуемые состояния — все семь; ни одно не означает «молчание».

*Носитель:* `Verdict.state_of_requirements`.
*Проверка полноты:* `state(c) ∈ State` для любого `c` — по построению,
и набором — тестом.

### A7. Принятие ответственности покрывает только неопределённость

```text
∀ c : accepted(c) ≠ ⊥ ∧ computed(c) ∈ {Holds, Refuted}  ⟹  state(c) = computed(c)
∀ c : accepted(c) ≠ ⊥ ∧ computed(c) ∉ {Holds, Refuted}  ⟹  state(c) = Accepted
```

Принять опровергнутое — значит спрятать находку. Принятие неопределённость
покрывает; ответ — никогда.

*Носитель:* `Verdict.apply_acceptance`, `law_acceptance_never_changes_an_answer`.

### A8. Принятое неопределённо

```text
∀ c : state(c) = Accepted  ⟹  verdict({c}) = Unknown
```

Принятое неопределённо остаётся неопределённым: принятие — это решение о
том, чья это проблема, а не ответ на вопрос.

*Носитель:* `Verdict.verdict_of_state`.

### A9. Ответ тотален

```text
∀ c : state(c) ∈ State
```

Ни одно утверждение не остаётся без состояния, и ни одно состояние не
означает «молчание». Пустое множество требований и требование без
свидетельства — разные вещи, и оба названы.

*Носитель:* `Verdict.state_of_requirements`; следствие — `test/laws.ml`.

### A10. Свидетельство принадлежит своему утверждению

```text
∀ e₁, e₂ : e₁.claim = e₂.claim ∧ e₁.requirement = e₂.requirement
              ⟹  latest(e₁, e₂) определено однозначно
```

Два утверждения часто делят одну проверку — один набор тестов проверяет
несколько правил, — и свидетельство одного не отвечает за другое. Сопоставление
идёт по **утверждению и требованию**.

*Носитель:* `Verdict.state_of_requirements`; закреплено `test/laws.ml`
(`check_evidence_does_not_crosstalk`).

### A11. Проверка обязана быть привязана к существующему предмету

```text
∀ c : scope(c) ≠ ∅  ∧  ∀ p ∈ scope(c) : P(p) ≠ ∅
```

Проверка, запущенная не о том, проходит вхолостую: компилятор, которому
указали на несуществующие пути, выходит с нулём. Значит, «проверено» без
предмета не значит ничего.

И предмет должен быть **цельным**: области, в которой часть путей есть, а
части нет, не существует. Дайджест вычисляется по тем путям, которые
разрешились, — а это дайджест части предмета, и он ничего не говорит о
части, которой нет. Такая область не связывается вовсе, и утверждение с
ней не может быть исполнено.

Закон говорит о **проверке**, а не об объявлении: предмет нужен той
проверке, которая к нему привязывается. Обещание же может быть
объявлено раньше, чем предмет появится, — см. A17.

*Носитель:* `Git.digest_of_scope` (нет дайджеста, если хоть один путь области
не разрешился; пустая область — тоже нет дайджеста),
`Git.scope_exists` (каждый путь области существует),
`Verdict.law_no_partial_subject`, `Verdict.law_no_vacant_subject`.
*Контроль:* сломанный адаптер — тот, что хеширует найденные пути и молча
выбрасывает ненайденные, — отвергается законом (см. `test/adapter_scope.ml`).

### A16. Проверка, которая не может упасть, ничего не доказывает

```text
∀ c : проверка(c) проходит  ⟹  её контроль падает
```

Проверка, прошедшая на предмете, доказывает, что предмет таков, каким
проверка его видит, — и ничего больше. Чтобы это было доказательством,
проверка обязана уметь **не сойтись**: нужен отрицательный контроль, то
есть команда, которая ломает предмет и обязана на нём падать.

Третья версия требовала этого от себя и ни от кого другого; четвёртая
сохранила правило для своих проверок и потеряла его для утверждений
принимаемых проектов, — и цена этого вышла в обоих замерах 2026-11-07:
утверждение «счётчик корзины показывает число изделий» было проверено
`typecheck` и признано верным, хотя код делал `sum + 1`, а typecheck
логическую ошибку не видит. Метод записал ложное утверждение как
доказанное.

Поэтому утверждение несёт **контроль** проверки: команду, которая
ломает предмет и обязана на нём падать. Метод исполняет её, и если
проверка проходит там, где обязана была упасть, — она предмета не
видит, и доказательства нет: утверждение не установлено, и карта
называет причину.

Граница метода названа, а не спрятана: он видит, что контроль прошёл, и
не видит, почему он прошёл. Почему контроль прошёл вместо того, чтобы
упасть, знает тот, кто его написал.

*Носитель:* `Verdict.state_of_evidence` (через `Exec.exit_code_of`),
поле `control` в утверждении.
*Контроль:* проверка, которая проходит там, где её контроль обязан был
упасть, не читает утверждение как доказанное (см. `test/cli.ml`).

### A12. Неопределённость стоит; ответ — нет

```text
cost(Verified) = cost(Falsified) = 0
cost(Unresolved) = cost(Refused) = 1
cost(Accepted) = 0
```

Принятое **не тратит бюджет**: ответственность перешла к человеку, и
это второй из трёх выходов при исчерпании (найти проверку — потребовать
полномочий — остановиться). При этом вердикт принятого остаётся
неизвестным (A8): бюджет — это то, что метод **должен**, а не то, что
он **знает**.

Бесплатная неопределённость делает «я не знаю» дешевле проверки. Бюджет
объявляется в спецификации и обязателен: неопределённость, которую
никто не оценил, — не конечный ресурс.

*Носитель:* `Verdict.cost_of_outcome`, `law_only_answers_are_free`.

### A13. Коды выхода различают три ответа

```text
exit(Green) = 0   exit(Red) = 1   exit(Unknown) = 3
```

Три значения, и ни одно не делится с другим: вызывающий, который
смешивает «прошло» и «не знаю», трактует отсутствие инструмента как
успех.

*Носитель:* `Verdict.verdict_to_exit`, `law_exit_codes_distinct`.

### A14. Выход проверки — один из четырёх

```text
exit_code(check) = 0 ⟹ Verified      1 ⟹ Falsified
                 = 2 ⟹ Unresolved    3 ⟹ Refused
                 иначе ⟹ Unresolved
```

Последняя строка — самая важная. Команда, которой нет, возвращает 127, и
127 **не** «прошло». Причина лаундеринга — в том, что отсутствие
исхода читалось как успех.

*Носитель:* `adapter/exec.ml` (`outcome_of_exit`).
### A15. Незакрытое требование доходит до человека

```text
∀ c, r ∈ requirements(c) :
    r = Reviewed_by(a) ∧ ¬ closed(c, r)  ⟹  (c, "ждёт ревью от a") ∈ route(c)
```

Маршрут, собранный только из свидетельств, **молчал бы** о требовании,
которое может закрыть только человек: свидетельства нет, потому что его
ещё не смотрели, — и это не отсутствие данных, а **запрос**. Метод,
который держит обещание человеку и никогда о нём не напоминает, —
это метод, который обещания не выполняет.

*Носитель:* `Verdict.route`.

### A17. План стоит ноль; неизвестность о существующем коде стоит единицу

```text
∀ c : ¬отвечен(c) ∧ предмет(c) ≠ ∅  ⟹  cost(c) = 1
∀ c : отвечен(c) ∨ предмет(c) = ∅   ⟹  cost(c) = 0
```

Обещание о коде, которого **ещё нет**, — это план, а не неизвестность.
План разрешается написанием кода, а не проверкой: проверять нечего, и
цена бюджета за этот план — ноль. Как только код появляется, обещание
становится обычным утверждением и стоит как обычное утверждение.

Обратная сторона названа прямо: дыра в области **не** делает
неизвестность бесплатной. Область, в которой есть код и нет ещё одного
пути, покрывает код — и неопределённость об этом коде настоящая, и она
стоит единицу.

**И это не лазейка в бюджет.** План не покрывает ни одного файла: он
ничего не прячет и ничего не решает. Карта показывает его отдельно, и
он начинает стоить, как только появляется код, — то есть ровно тогда,
когда его можно и нужно проверить.

Закон A11 при этом не тронут: **проверке** предмет нужен целиком, и
проверка о предмете, которого нет, не исполняется. Изменилось только
место отказа: объявление обещания не требует, чтобы предмет уже
существовал. Отказ стоял не там, где стоял, и из-за этого метод был
неприменим к пустому репозиторию — а пустой проект сам метод называет
законным состоянием. Законное состояние, из которого нельзя выйти, —
не состояние, а тупик.

*Носитель:* `Verdict.cost_of_claim`, `Verdict.law_the_budget_prices_uncertainty`;
объявление плана — `add` (не отказывает), карта — `map` («предмета ещё
нет»).
*Контроль:* три сломанных бюджета — который charges планы, который не
charges ничего и который charges ответы — отвергаются законом (см.
`test/laws.ml`).

## 4. Принципы и их носители

Каждый принцип `PHILOSOPHY.md` получает здесь носителя — или честно
значит, что носителя у него нет.

| Принцип | Закон | Носитель | Состояние |
|---|---|---|---|
| П1 проверяемость | A11, A14 | `Git.digest_of_scope`, `outcome_of_exit` | частично: содержание проверки метод не проверяет |
| П2 связка | A3, A4 | `state_of_evidence` | полностью |
| П3 нет ответа ≠ ответ | A2, A8, A13 | `verdict_to_exit` | полностью |
| П4 непокрытая поверхность | A6, A10 | `Git.uncovered` | полностью |
| П5 полномочия объявляются | — | область цели; `add` отказывает вне её | полностью |
| П6 человек в истоке | A15 | `goal.by`, `accept` требует имени, маршрут показывает ожидающее ревью | полностью: атрибуция, не аутентификация |
| П7 регистр | A5 | `apply_register` | полностью |
| П8 цена неопределённости | A12, A17 | `budget` в спецификации, меняется глаголом с причиной; `add` отказывает; принятое бюджет не тратит; план (обещание о несуществующем коде) не тратит | полностью |
| П9 тишина — норма | — | — | ритуала нет; тишины тоже нет — карта говорит всегда |
| П10 самоприложение | — | `bin/stand.ml` | полностью |
| П11 не дороже того, что ловит | — | критерий в `GOAL.md` | измеримо на чужих проектах |
| П12 диалектика на плане | — | `waves/*.json`: `intent`, `objection`, `refuted_by` | полностью |
| П13 изменение объявляет | — | `waves/*.json`: `commitment` — обещание, которое проверяется при закрытии | полностью |
| П14 цикл вычисляется | A3, A4 | нет хранимого состояния | полностью |
| П15 трение принадлежит методу | — | `add`, `run`, `close`, `accept`, `record`, `goal`, `budget`, `wave` отказывают; `map`, `route`, `next`, `install`, `doctor`, `propose` — нет | полностью |

## 5. Что здесь не утверждается

- **Полнота содержания.** Метод знает, что проверка привязана к
  существующему предмету (A11), и не знает, что она проверяет именно то.
  Это граница метода, а не недоработка: содержание проверки — вопрос
  смысла, и он закрывается человеком.
- **Полезность.** Ни один закон этого текста не говорит, что метод
  полезен. Полезность измеряется по `GOAL.md`, и измеряется на чужих
  проектах.
- **Аутентификация.** Метод не отличает человека от агента за клавиатурой.
  Он атрибутирует и делает изменения видимыми — и это всё, что он обещает.

## 6. Соглашение об именах

Имена в коде — английские, по смыслу: `Holds` — «держится», `Outdated` —
«протухло», `NotCheckable` — «нечем проверить». Русские equivalents даны
в §1; при расхождении текстов **код — источник истины для исполнения**,
этот текст — для доказательства, и расхождение между ними означает, что
один из них устарел.

Расхождение ловится: каждый закон выше имеет сломанную реализацию в
`test/laws.ml`, которую закон обязан отвергнуть, — и набор краснеет.

## Как устроено ядро — словами, которые стоит у кода

Это пересказ кода: те же законы, те же решения, те же границы.
Код — спецификация для исполнения; этот раздел — для чтения.

The acceptance, as a separate step over the computed state.

    A person may take responsibility for an UNCERTAINTY, and for
    nothing else. They may not take responsibility for an answer: a
    refuted claim is not uncertain, it is false, and accepting it does
    not un-refute it. An acceptance that covered answers would let a
    person bury a finding, which is the opposite of what an acceptance
    is for.

    The step is separate from the computation for a reason that is not
    tidiness: a law that talks about acceptance can only be refuted if
    the acceptance is a function of the state, and not of everything
    at once. Stated over the whole computation, a broken function that
    ignores its input would satisfy the law by being broken in the same
    way twice.

What the human is asked to decide.

    Two kinds of item, and the second is the one that was missing. A
    requirement that only a person can close - a review - and that
    nobody has closed yet, is NOT an absence of evidence: it is a
    request. A route built from evidence alone would never show it, and
    the method would keep a promise to the human that it never
    delivered and never asked for.

    So the route is computed from the CLAIMS, not from the evidence:
    what the evidence could not settle, and what is waiting for a
    person.

(* Each law is stated over the function it constrains, not over the
   implementation directly. That is not a stylistic choice: a law that
   can only be evaluated on the code it constrains is a description of
   that code, and a description cannot be refuted. Stated over the
   function, the law can be checked against a broken one as well as
   against the real one, and a law that accepts a broken
   implementation is exposed.

   The broken implementations live in the test suite, where they are
   required to be REJECTED.

The law of the term: a proof whose term is over is not a proof.

    The binding says whether the content is the same; the term says
    whether the proof still counts. A proof can be about exactly the
    right content and still be too old to stand - the deployment
    moved, the dependency changed, the review was for the release that
    is over. Neither the content nor the truth can see that.

    So the law is stated over the function that decides, and the broken
    version - one that ignores the term - must be rejected by it.

A subject is whole or it is not: a scope with a path that is not in
    the tree is a subject with a hole in it, and a digest of such a
    subject says nothing about the part that is missing.

    The core cannot see the tree - that is the adapter's business - so
    the law is stated over the two functions that decide: the one that
    computes the digest of a scope, and the one that says whether a
    path is there. The law says that a digest exists only for a scope
    whose every path exists. A subject that is partly missing has no
    digest, and a claim that cannot be bound cannot be run.

    This law exists because the defect was real and quiet: the adapter
    used to hash the paths it found and drop the ones it did not, so a
    scope of one real directory and one missing path produced a digest
    and a green verdict, and the part that was missing was invisible.
    The broken version of the adapter is offered to this law in the
    test suite, and the law has to reject it.

The law of the register: a judgment is not the machine's to decide.

    A judgment - a decision about meaning, an interface, a priority -
    has no canary. There is no procedure that breaks it, because
    breaking it is not what would disprove it. So a check that says
    "yes" to a judgment does not establish the judgment; it
    establishes that some procedure ran, which is a different fact.

    And a check that says "no" does not refute it either. A failed
    procedure is a fact about the procedure, not about what should be
    true about meaning. So the rule is applied to the outcome in both
    directions: whatever the machine finds, a judgment arrives at the
    person.

    What is NOT changed is a check that could not run at all: that is
    a gap in the evidence, and a gap stays a gap whoever owns the
    claim.

