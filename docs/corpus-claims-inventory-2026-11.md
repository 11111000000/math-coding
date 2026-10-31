# Инвентарь обещаний живого корпуса, 2026-11

> **Снимок:** `main`/ветка `feat/corpus-claims-inventory-2026-11`, commit `472918dfbba2013edeb4e1803b389f6fdaf049b3`. Только чтение; единственная запись в этом репозитории — этот отчёт.

## 0. Границы и метод

> **ПРОВЕРКА ОРКЕСТРАТОРА (2026-11-01).** Все пять главных находок этого отчёта перепроверены на дереве main. Четыре подтвердились как есть: пять решений не читаются до EOF (3-2-cli-catalog, ci-blocking-list-config, d5-body-vs-wrapper-canonical, forge-stub-read-request, mathc-packages-subcommand); ledger silent-drop фиксирует 12/216 и пустой kernel_holes, а дерево даёт 5 файлов с диагностикой, из которых 1 — дыра ядра (MULTI-DOC) и 4 — невалидный YAML автора; нормативный каталог CLI содержит 18 разделов против 29 команд в справке; активные правила противоречат ядру. Пятая (census) подтвердилась ПО СУЩЕСТВУ, но с другим объяснением: прибор падал не из-за потолка, а из-за унаследованного MATH_CODING_ROOT, при котором контроль мерил живой корпус вместо синтетического. Прибор починен (контроль очищает окружение и требует измерить свой корпус); строка исправлена ниже.


- **Что на самом деле лежит в `decisions/`:** 136 YAML-файлов. Из них 133 имеют schema `math-coding/3.x` (130 `active`, 3 `superseded`), а ещё три — специальные schema: `obligations.yaml` и два migration manifest. Census считает **136 corpus files / 133 active**. Поэтому таблица ниже покрывает все 136 файлов корпуса, как и просили, но не называет 136 файлов «136 активными decision schema».
- **Механическая часть чиста:** `bash tests/fixtures/redundancy-census.sh --list` не печатает ни одного dead scope-path; `bash tests/fixtures/relation-targets-resolve.sh` → 0 dangling targets. Один неразрешённый relation key (`amends`) остаётся, но это не dangling target.
- **Как проверялось:** для каждого файла запущен `mathc validate` и `mathc verify --format=json`; 76 уникальных referenced cram-тестов запущены адресно через `dune test` (не `@runtest`); 19 уникальных referenced OCaml-целей — адресно; 44 referenced shell fixtures — адресно. `mathc verify` по замыслу не исполняет `tests/**` verifier-ы, поэтому для них использованы прямые запуски.
- **Kernel binary:** в этом worktree изначально не было `_build/`; поэтому для kernel-команд использовался `/home/az/Projects/math-coding/_build/default/bin/mathc.exe` из main checkout с тем же commit `472918dfb`. Все результаты ниже относятся к этому snapshot.
- **Граница ресурсов:** полный `dune build @runtest`, `scripts/check.sh` целиком и `mathc gate` на всём дереве не запускались — по условию задачи и из-за стоимости. Внешние release/OCI/CI-артефакты не скачивались.
- **Вердикт всегда один из четырёх.** «Не проверено» — не пятый вердикт, а вторичный счётчик решений, у которых хотя бы одно обязательное/внешнее утверждение осталось DECLARED или неисполнимым в этом checkout.

## 1. Инвентарь по всем 136 файлам

| id | что обещает | вердикт истины | класс контроля | доказательство | что делать |
|---|---|---|---|---|---|
| `3-2-cli-catalog` | CLI-каталог `spec/semantics.md` содержит mode, rebuttals и re-evaluate и не расходится с dispatcher. | **STALE-FORM** | **CHECKED** | `bash tests/fixtures/3-2-cli-catalog-rows-present.sh` → PASS; `mathc validate` → MC-UNPARSED-TAIL at line 183; spec has 18 CLI headings vs 39 dispatch commands. | Переписать: заменить исторические 17/14 на инвариант полного CLI-каталога и починить unread tail. |
| `adapters` | `mathc attest FILE` reads FILE as a JUnit XML report, parses it via Junit.parse_junit, and prints a JSON object on stdout with at least the keys "suite_name", "test_count", "failure_count", "error_count", "skip_count", and "tes… | **TRUE** | **CHECKED** | `dune test tests/cli/junit-adapter.t tests/cli/git-adapter.t` → PASS. | Оставить. |
| `adopter-path-2026-10` | The file `mathc init` writes carries no obligation the corpus discharges by attesting itself, and no argument the adopter did not make. | **RECORD** | **CHECKED** | `state: superseded` (line 5); external `git grep` finds only a comment in `scripts/check-no-prose-policy-grep.sh:11`. | Архивировать; machine dependency не найдена. |
| `adoption-friction-p0-2026-10` | A project scaffolded by `mathc init` reaches `mathc self-check` → `pass` (exit 0) in seven commands, with no environment variable and no directory the operator has to create by hand. | **TRUE** | **CHECKED** | `mathc verify decisions/adoption-friction-p0-2026-10.yaml --format=json` → 4/4 pass. | Оставить. |
| `agent-onboarding` | The three conventions (ADR location, formal-verifier prefixes, first-file) are recorded as discrete obligations in this decision file, with verifiers pointing at tests/repo_structure.ml (per P2 in decisions/process-principles.y… | **STALE-FORM** | **UNCHECKED** | `dune test tests/repo_structure.ml` → `agent-onboarding` case OK; text still names `AGENTS.md` at lines 12, 43, 187. | Переписать: `AGENTS.md`→`KERNEL_AGENTS.md`, `bootstrap/`→`decisions/`. |
| `algebra-3.2-notation-flag-2026-10` | Спецификация §2 сохраняет неоднозначную запись и указывает на это решение как на разрешение. | **TRUE** | **CHECKED** | `mathc verify decisions/algebra-3.2-notation-flag-2026-10.yaml --format=json` → 1/1 pass. | Оставить. |
| `algebra-3.2` | `spec/algebra-3.2.md` is the authoritative normative spec for the 3.2-ideal kernel, supplementing constitution.md. | **STALE-FORM** | **UNCHECKED** | `dune test tests/repo_structure.ml tests/conformance.ml` → relevant cases OK; file still says “28 active” at lines 110 and 262, census says 136. | Переписать: 28 решений/текущие отклонения заменить ссылкой на измеряемый contract T3.2. |
| `attest-per-obligation-2026-10` | `attest-batch --run-per-obligation` подписывает результат собственного verifier-а; skipped не становится pass. | **TRUE** | **CHECKED** | `dune test tests/cli/attest-batch-signature.t tests/cli/decision-resolution.t` → PASS. | Оставить. |
| `attestation-producer-vocab-2026-10` | `mathc validate` rejects an attestation whose `producer.identity` does not match `^(human\|agent\|ci):[A-Za-z0-9][A-Za-z0-9._:/-]*$`, with code MC-PRODUCER-CLASS-UNDECLARED and severity block. All 703 class-tagged identities in t… | **STALE-FORM** | **DECLARED** | `dune test tests/producer_vocab.ml tests/conformance.ml tests/store_admission.ml` → PASS; one manual case not checked; historical 765-file counts are obsolete because the store is generated. | Переписать: убрать historical 765/703 tracked-store counts, оставив правило producer vocabulary. |
| `attestation-store-fill` | HEAD b36572f has a corresponding attestation file in attestations/ that the kernel gate evaluator accepts. | **RECORD** | **DECLARED** | File records 75 JSON files at old HEAD (lines 23–27); `git ls-files attestations/**` → 0. | Архивировать; обновить path pointers в PACKAGES/source-map, файл не открывается кодом. |
| `audit-0.0.21-fixes` | `mathc self-check` on a clean tree of the integrated HEAD returns `verdict:"pass"`, exit `0`, with `pass_count == subjects_len` and `unknown_count == 0` (or, with waivers, `unknown_count == waived_count`). | **RECORD** | **CHECKED** | File describes completed five-phase cycle (lines 9–18); targeted parser/conformance/cram tests pass; external grep finds comments/prose, no machine opening this file. | Архивировать; machine dependency не найдена. |
| `candidate-tree-resolves-to-a-commit-2026-10` | An attestation produced by `mathc attest-batch` or `mathc re-evaluate-decisions` carries a `candidate_tree` equal to the commit HEAD resolved in the project root at write time, and a reader can name the tree the observation is… | **TRUE** | **CHECKED** | `dune test tests/cli/candidate-tree.t` → PASS. | Оставить. |
| `capsule-active-policy` | Capsule items[] contains the active policy (bootstrap-v3) with priority='RequiredForGate'. The decision is the FIRST item in items[] when present. | **TRUE** | **CHECKED** | `dune test tests/cli/context-required-for-gate.t tests/cli/context-budget-bound.t tests/cli/context-truncated-omitted.t tests/cli/context-priority-order.t` → PASS. | Оставить. |
| `ceiling-monotonic-2026-10` | A ceiling in `tests/fixtures/*.sh` that is larger at HEAD than at the base commit fails CI, unless the raise is recorded next to the number with a marker naming that exact transition. | **RECORD** | **DECLARED** | `state: superseded` (line 5); obligations say `RETIRED at revision 2` at lines 198–238. | Архивировать как superseded/retired record. |
| `ci-blocking-list-config` | `Attestations.blocking_cis` читает `MATH_CODING_BLOCKING_CIS` и возвращает исторический default при unset. | **STALE-FORM** | **CHECKED** | `dune test tests/ci_blocking_list_test.ml` → PASS; `mathc validate` reports unread tail at line 138. | Переписать: починить YAML tail и historical-list wording; не менять API без нужды. |
| `ci-gate-exit-honesty-2026-10` | The `mathc self-check (corpus audit)` step in `.github/workflows/ci.yml` ends with `exit "${rc}"` where `rc` is mathc's own exit status, and its `jq` diagnostic dump runs under an `if` that cannot reach that line's status. An e… | **TRUE** | **CHECKED** | `bash scripts/ci-step-exit-sim.sh` → all self-check/gate rows `ok`, pre-fix control mismatches. | Оставить. |
| `ci-self-check-is-an-audit-2026-10` | CI self-check остаётся audit-шагом; debt ограничен ratchet-ом, а merge блокирует scoped gate. | **TRUE** | **CHECKED** | `bash tests/fixtures/self-check-debt-ceiling.sh` → PASS (36 declared ≤ ceiling 36; negative control fires). | Оставить. |
| `cli-canonical-name` | A single CLI name `mathc` is the only CLI invocation used in docs, code help-strings, cram tests, CI workflow steps, and shell fixtures. `git grep -E '\bmc\b'` against tracked files outside `MC-*` error-code identifiers returns… | **TRUE** | **DECLARED** | `bash tests/fixtures/decisions-have-no-mc-prefix.sh` → PASS; `dune test tests/re_evaluation_test.ml` → PASS; one prose scan remains manual. | Оставить. |
| `cli-cram-tests` | `tests/cli/*.t` exercises the mathc CLI via dune cram; `dune test` runs the suite and exits 0 on a clean tree. | **RECORD** | **UNCHECKED** | External grep finds machine reads at `tests/corpus_no_silent_drops/corpus_no_silent_drops.ml:326` and `tests/yaml_seq_continuation.ml:399`. | Сначала перенаправить два теста exact-path на archive, затем архивировать. |
| `constitution-header-3-3-update-2026-10` | `head -1 spec/constitution.md` is `# Math-coding <version> constitution` — the version the constitution governs. | **TRUE** | **UNCHECKED** | `mathc verify decisions/constitution-header-3-3-update-2026-10.yaml --format=json` → 1/1 pass; `spec/constitution.md:151` has current H1. | Оставить. |
| `corpus-final-state-2026-10` | Every decision in the corpus is a rule the project keeps. | **FALSIFIED** | **UNCHECKED** | Census → 136 corpus, 36 paper; `mathc self-check` → 129 subjects all `unknown`, exit 3; decision demands exit 0 at lines 93 and 109. | Переписать: недостижимое “final state” заменить текущим правилом и измеримыми exit conditions. |
| `corpus-growth-lints-2026-11` | A fixture reports how many obligations in the live corpus carry a verifier the kernel cannot execute, reads the list of schemes the kernel can execute out of the kernel's own source, and pins the number as a ceiling. | **TRUE** | **CHECKED** | `bash tests/fixtures/verifier-scheme-allowlist.sh` → PASS; `bash tests/fixtures/relation-targets-resolve.sh` → PASS (0 dangling). | Оставить. |
| `corpus-meta-layer-2026-10` | The committed mirror of the live store is not in the tree, and the corpus's attention is no longer spent keeping it in step. | **TRUE** | **CHECKED** | `bash tests/fixtures/no-shadow-corpus.sh` → PASS; `dune test tests/cli/self-check-pass.t tests/cli/self-check-fail.t tests/cli/self-check-unknown.t` → PASS. | Оставить. |
| `corpus-relations-and-scope-2026-11` | Every relation target in the live corpus names a decision that exists, live or archived, or a file that exists. The lint reports zero of them resolving to nothing. | **TRUE** | **CHECKED** | Relation lint → 0 dangling; census prints DEAD 0 before failing on its unrelated negative control. | Оставить. |
| `corpus-silent-drop-inventory-2026-10` | Одно воспроизводимое сканирование даёт точный список файлов с потерянным хвостом и не допускает kernel_holes. | **FALSIFIED** | **CHECKED** | `bash scripts/scan-silent-drops.sh --validity` → 5 of 135 files, including five live decisions; decision pins 12/216 and empty `kernel_holes` at lines 44, 80, 190. | Переписать: exact ledger обновить до 5 kernel holes; author-malformed debt отделить от kernel holes. |
| `corpus-tranche-archive-records-2026-11` | Eleven candidate records now live under archive/decisions/, and each says state: retired. The live corpus fell from 145 to 134 decision files while the archive grew from 121 to 132 files. | **RECORD** | **UNCHECKED** | `mathc verify` → 13/13 pass; external grep finds no machine read of this file. | Архивировать; machine dependency не найдена. |
| `corpus-tranche-broken-schemes-2026-11` | No obligation in the live corpus names a verifier scheme the kernel cannot read, and the five obligations this tranche repaired are classified by the kernel as checks rather than as declarations. | **RECORD** | **CHECKED** | `bash tests/fixtures/verifier-schemes-are-canonical.sh` → PASS; external grep finds only diagnostic prose and fixture comments. | Архивировать; fixture/diagnostic только ссылаются, файл не открывают. |
| `cwd-independent-materials-digest-2026-10` | `mathc self-check` produces the same subject verdicts from the repository root, from an unrelated directory, and from a sandbox inside the repository. | **TRUE** | **CHECKED** | `bash tests/fixtures/cwd-independent-self-check.sh` → PASS (root/tmp/sandbox verdicts equal). | Оставить. |
| `d5-body-vs-wrapper-canonical-2026-10` | `spec/algebra-3.2.md` §7.1 (NEW) names the placeholder-substitution algorithm in a normative sub-section. The `D.body_sha = D.yaml_sha` invariant (when both are present) is a COROLLARY of the algorithm, not an additional rule. | **STALE-FORM** | **DECLARED** | `dune test tests/body_canonical_test.ml` and `tests/cli/body-vs-wrapper-canonical.t` → PASS; `mathc validate` reports unread tail at line 618. | Переписать: починить YAML tail и ссылки на implementation §7.1. |
| `d8-coarse-diagnostics-2026-10` | `lib/decision.ml::parse_decision` returns `Diagnostic.t option`. `Some d` means accept (where `d` is a successful-parse confirmation; today the CLI treats Some as accept regardless of payload). `None` is reserved; today's code… | **TRUE** | **DECLARED** | `dune test tests/diagnostic_ux.ml` → PASS; two manual case labels remain unexecuted. | Оставить. |
| `decision-level-census-2026-10` | Записи уходят из корпуса, правила остаются, а census считается на уровне решения. | **RECORD** | **UNCHECKED** | External grep finds only a comment at `tests/corpus_no_silent_drops/corpus_no_silent_drops.ml:184`; no machine opens the file. | Архивировать; machine dependency не найдена. |
| `decision-required-attestations-2026-10` | `schemas/decision.json` accepts a `required_attestations` array of (kind_, producer, scope_paths) triples. Each item is constrained by `additionalProperties: false` and the `kind_` enum mirrors the attestation `kind_` set (test… | **TRUE** | **CHECKED** | `dune test tests/cli/required-attestation.t` → PASS; broad `scripts/check.sh` verifier was not used as evidence. | Оставить. |
| `decision-resolution-2026-10` | A `mathc` binary run inside a project reads THAT project's decisions, whatever tree the binary itself was built in. | **TRUE** | **CHECKED** | `dune test tests/cli/decision-resolution.t` → PASS; `bash tests/fixtures/failing-subject-backlog.sh` and `negative-control-debt.sh` → PASS. | Оставить. |
| `decision` | Мастер-политика bootstrap-v3 сохраняет 2.1, исполняет спецификацию 3.0 и не позволяет агенту выдавать неподтверждённое за проверку. | **STALE-FORM** | **DECLARED** | `VERSION` is 3.7.4; file still says “Build math-coding 3.0” (line 13), “Until the 3.0 kernel exists” (line 44), and `AGENTS.md` (line 68). | Переписать master policy под текущую версию/kernel и ручные declarations. |
| `defense-and-init-scope-2026-11` | README.md, KERNEL_AGENTS.md, OCAML_KERNEL_CONVENTIONS.md, and spec/algebra-3.2.md each carry a banner that points adapters in other languages to adoption/SKILL.md before they read any OCaml-specific content. | **TRUE** | **CHECKED** | `dune test tests/cli/init-scope-language-agnostic.t` → PASS; banners present at `README.md:18` and `KERNEL_AGENTS.md:4`. | Оставить. |
| `dialectic-method-v3-2026-10` | Схема решения имеет intent/thesis, antithesis/counter-position и commitment/synthesis; counterexample остаётся машинным forcing function. | **TRUE** | **CHECKED** | `nix develop .#test --command dune test tests/cli/validate-considered-antithesis.t` → PASS. | Оставить. |
| `duplicate-mapping-keys-silent-drop-2026-10` | Every mechanism by which a decision file can say more than the kernel reads emits a Warn-level `MC-*` diagnostic from `mathc validate`, so `parse-ok` can no longer be mistaken for "the kernel read all of it". | **STALE-FORM** | **CHECKED** | `mathc verify` fails because lines 303–316 validate deleted targets; live tree still has five unread tails. | Переписать: удалённые verifier-цели заменить нынешними пятью unread-tail файлами. |
| `enforce-body-sha-digest-2026-10` | `sha_match_check` compares the stored `body_sha` against `body_canonical_sha256(file_bytes)` and emits MC-SHA-DIGEST-STALE (Block) when they differ, rather than comparing the two stored fields to each other. | **TRUE** | **CHECKED** | `mathc verify decisions/enforce-body-sha-digest-2026-10.yaml --format=json` → 3/3 pass. | Оставить. |
| `evidence-class-gate-2026-10` | `mathc gate` and `mathc self-check` treat a runtime-class (`test \| build \| analysis \| observation`) attestation reporting `pass` as discharging its obligation only when it names a non-empty `producer.run` or its `producer.ident… | **TRUE** | **CHECKED** | `dune test tests/cli/evidence-class.t tests/cli/required-attestation.t` → PASS. | Оставить. |
| `executed-evidence-census-2026-10` | A fixture reports how many passes in the store cover obligations the kernel cannot execute, and pins that number as a ceiling. | **STALE-FORM** | **CHECKED** | `bash tests/fixtures/executed-evidence-census.sh` → exit 3 (“no attestation store”); file still says “tracked store” at lines 52 and 137. | Переписать: tracked store→generated disk store; текущие числа помечать generated/unknown. |
| `exit-code-symmetry-2026-10` | `mathc gate BASE HEAD` exits 3 when the verdict is `Unknown`, exits 0 when the verdict is `Pass` or `Open_with_waiver`, and exits 1 when the verdict is `Block`. The mapping is enforced by `bin/Mathc.ml::verdict_to_exit` and ass… | **TRUE** | **CHECKED** | `dune test tests/cli/gate-unknown-exit-3.t` → PASS; `spec/constitution.md:151–160` contains 14, 14b, 14c. | Оставить. |
| `exit-honesty-waivers-2026-10` | `Waiver.covers` holds a waiver to the gap it names, the class it declares and the scope it claims. A waiver that names no gap covers nothing. The end-to-end fixture is `tests/cli/waiver-scope.t` (six scenarios: the positive cas… | **TRUE** | **CHECKED** | `mathc verify decisions/exit-honesty-waivers-2026-10.yaml --format=json` → 4/4 pass. | Оставить. |
| `failing-verifier-is-named-2026-10` | A refusal names the verifier string that failed, and names every failing verifier when several of them failed. | **TRUE** | **CHECKED** | `bash tests/fixtures/failing-verifier-is-named.sh` → PASS. | Оставить. |
| `fix-yaml-parser-2026-10` | A decision whose `risk.declared_triggers` is given in the inline-sequence form `key: - foo` followed by `- bar` continuation lines at the same indent, plus a sibling `counterexample: \|` block, is parsed without dropping either… | **TRUE** | **CHECKED** | `dune test tests/yaml_block_scalars.ml` → 10/10 pass; `mathc validate decisions/fix-yaml-parser-2026-10.yaml` has no unread-tail warning. | Оставить. |
| `forge-principal-verification-2026-10` | Недоступный forge при fail-mode=open даёт verdict=pass/exit 0; fail-mode=closed даёт block/exit 1; membership проверяется через forge API. | **FALSIFIED** | **UNCHECKED** | Decision requires unset forge + fail-mode open → pass/exit 0 at lines 24–25 and 90–94. `tests/cli/forge-verify.t` now explicitly asserts unknown/exit 3 and PASSes with that opposite expectation. | Переписать: fail-open unset→unknown/exit 3; синхронизировать с exit-honesty-waivers. |
| `forge-stub-read-request-2026-10` | The forge stub answers an HTTP request head that ends with the blank line, on the first connection and on every subsequent one, with `200` and `Connection: close`. | **STALE-FORM** | **CHECKED** | `bash tests/fixtures/forge-stub-read-request.sh` → PASS; `mathc validate` reports a second `---` at line 295. | Переписать: удалить второй `---` в line 295. |
| `formal-verifier-conventions` | The tla:/coq:/alloy: prefixes are recorded in OCAML_BEST_PRACTICES.md §10.6, alongside §10.5 (priority mirror) and §10.4 (architecture conventions). | **STALE-FORM** | **UNCHECKED** | `dune test tests/repo_structure.ml` → `formal-verifier-prefixes` OK; prefixes now live at `OCAML_KERNEL_CONVENTIONS.md:1005–1007`, not the named file. | Переписать: `OCAML_BEST_PRACTICES.md`→`OCAML_KERNEL_CONVENTIONS.md` (таблица lines 1005–1007). |
| `gaps-worklist-2026-10` | Every open promise appears in the worklist with its class and the action its class admits. | **TRUE** | **CHECKED** | `dune test tests/cli/gaps.t` → PASS; `mathc verify` non-test verifiers pass. | Оставить. |
| `gate-attestation-store-fill-decision` | `lib/attestations/` exists with its own `dune`, declares library `mathcoding_attestations`, and exposes a pure `Attestations.load : reader:(string -> string) -> root:string -> Domain.attestation list` that returns `[]` when `ro… | **FALSIFIED** | **CHECKED** | Decision requires unknown→exit 0 at lines 44, 53, 99; current `bin/Mathc.ml:6709–6711` maps Unknown→3 and `tests/cli/gate-unknown-exit-3.t` passes with exit 3. | Переписать: unknown→exit 3 и generated-store semantics; снять противоречие. |
| `gate-blocks-in-ci-2026-10` | A change the gate blocks does not reach main, and a change the gate cannot judge is red unless the only thing it cannot judge is the corpus's own declared debt. | **TRUE** | **CHECKED** | `bash scripts/ci-step-exit-sim.sh` → all gate rows `ok`, including block/input-error/unknown distinctions. | Оставить. |
| `gate-by-diff-2026-10` | `mathc gate --scope` evaluates only the decisions whose scope names a file the change touches. | **TRUE** | **UNCHECKED** | Targeted dune build succeeded; `dune test tests/cli/gate-scoped.t` → PASS. | Оставить. |
| `gate-decision` | `mathc gate BASE HEAD` is a recognised subcommand; the dispatcher in bin/Mathc.ml routes to it. | **RECORD** | **UNCHECKED** | `dune test tests/cli/gate-scaffold.t` → PASS; normative pointer remains at `spec/semantics.md:321`. | Архивировать после A3-смены normative pointer в `spec/semantics.md:321`. |
| `gate-ref-validation-2026-10` | A merge gate that cannot resolve its refs cannot return a green verdict. | **TRUE** | **CHECKED** | `bash tests/fixtures/gate-ref-validation.sh` → PASS. | Оставить. |
| `gate-report-proportional-2026-10` | A gate run on this repository prints a report of tens of kilobytes, not hundreds, and the report says how many gaps it did not print. | **TRUE** | **UNCHECKED** | `dune test tests/cli/gate-scaffold.t` → PASS; `mathc verify` non-test verifiers pass. | Оставить. |
| `gate-scoped-default-2026-10` | With the default flipped, `mathc gate BASE HEAD` evaluates only the decisions whose scope names a file the change touches, and runs their verifiers on the candidate tree. | **TRUE** | **CHECKED** | `dune test tests/cli/gate-scoped.t` → PASS. | Оставить. |
| `gate-verifier-cycle-guard-2026-10` | A verifier whose script is already running above it is refused before it is executed, and the refusal names the cycle. | **TRUE** | **CHECKED** | `dune test tests/cli/gate-cycle-guard.t` → PASS. | Оставить. |
| `grep-schemes-are-executable-2026-10` | A promise the corpus can write down is a promise the kernel can run, in both directions: that the thing is there, and that it is not. | **TRUE** | **UNCHECKED** | `mathc verify` → 3/3 pass; `bash tests/fixtures/shell-grep-negative-control.sh` → PASS. | Оставить. |
| `honest-attestation-emission-2026-10` | A re-sign writes `review`/`inconclusive` for manual declarations, `producer.run` for runtime attestations, and prunes orphans. | **TRUE** | **UNCHECKED** | `bin/Mathc.ml:6041–6042,6221–6222` maps Manual_decl→review/inconclusive; current store absent, so end-to-end store claim not checked. | Оставить. |
| `honest-instruments-2026-10` | The census and the legacy-debt fixture read the attestation store that exists, and say "unknown" when there is none. | **TRUE** | **CHECKED** | Census and legacy fixtures → exit 3 on absent store as promised; `scripts/ci-step-exit-sim.sh` → PASS. | Оставить. |
| `infrastructure-honesty` | Every CI workflow path under .github/workflows/ MUST refer to files and commands that exist in the source tree. A green badge that hides a broken reference is a violation of A1 (Epistemic honesty). | **TRUE** | **UNCHECKED** | `dune test tests/repo_structure.ml` → CI-targets, flake-lock and conformance cases OK. | Оставить. |
| `install-tooling-2026-10` | `install.sh` is uploaded to every GitHub release as a release asset alongside `SHA256SUMS` and the binaries. | **STALE-FORM** | **DECLARED** | `dune test tests/cli/install.t` → PASS; commitment/outcomes still name OCAML_BEST_PRACTICES.md (lines 167, 298, 456); external release/OCI/nix channel and manual `nix flake check` not checked. | Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md; внешние каналы оставить DECLARED. |
| `instruments-repair-2026-11` | `scripts/sync-version.sh --check` refuses a drifted MC_VERSION line in either copy of the skill, and a negative-control fixture demonstrates the refusal. | **TRUE** | **CHECKED** | `bash tests/fixtures/sync-version-mc-version-drift-fails.sh` → PASS; `tests/fixture_coverage.ml` correctly fired at 54 > ceiling 52; attest-batch cram PASS. | Оставить. |
| `kernel-bugs-v3.4-2026-10` | mathc init . --no-install followed by mathc validate decisions/decision.yaml exits 0 on a clean clone. This is the pre-condition for the brownfield report §3.1 fix. | **RECORD** | **DECLARED** | Five targeted cram files pass; external grep finds comments/IDs only, no machine opening this file. | Архивировать; code/test references являются ID/comment, не чтением файла. |
| `kernel-conformance-runner` | tests/conformance.ml enumerates every JSON and YAML fixture under fixtures/conformance/{decision,attestation}/ and asserts the expected verdict (pass for positive-, fail for negative-). | **TRUE** | **CHECKED** | `dune test tests/conformance.ml` → PASS. | Оставить. |
| `kernel-fixes-found-bugs-2026-10` | `mathc adopt DIR` writes the scaffold and the imported ADRs into DIR, never into the repository the operator is standing in. | **RECORD** | **CHECKED** | Targeted adopt/init/import-adr tests pass; normative pointer at `spec/semantics.md:197` blocks an immediate move. | Архивировать после A3-смены normative pointer в `spec/semantics.md:197`. |
| `legacy-attestation-debt-2026-10` | `tests/fixtures/legacy-attestation-debt.sh` reports the measured debt and fails if it exceeds the ceiling recorded in the fixture. The ceiling is a constant in the fixture, so lowering it is an explicit, reviewable act. | **STALE-FORM** | **CHECKED** | `bash tests/fixtures/legacy-attestation-debt.sh` → exit 3 (no store); text still says tracked attestations at lines 16 and 95. | Переписать: tracked→generated store и актуальные ceilings. |
| `materials-digest-semantics-a-2026-10` | An attestation whose materials_digest was computed by `mathc attest-batch` from the same tree the gate evaluates is accepted. Measured: five obligations signed by attest-batch and verified by `mathc gate` are reported satisfied… | **TRUE** | **CHECKED** | `mathc verify` → 3/3 pass; `bash tests/fixtures/attest-batch-run-digest.sh` → PASS. | Оставить. |
| `mathc-counters-subcommand-2026-10` | `mathc counters` заменяет `scripts/dev-counters.py` и даёт тот же JSON-снимок без Python. | **TRUE** | **UNCHECKED** | `dune test tests/counters_drift.ml` → PASS; dispatcher has `counters` at `bin/Mathc.ml:12068`. | Оставить. |
| `mathc-explain-subcommand` | spec/semantics.md §"CLI subcommands" has a `### explain DETAIL_REF` row with synopsis, input, output, exit code, and bootstrap justification. | **TRUE** | **CHECKED** | `dune test tests/cli/explain-positive.t tests/cli/explain-negative.t` → PASS. | Оставить. |
| `mathc-packages-subcommand` | `mathc packages` перечисляет каждое решение и obligation с verifier, verdict и attestation status. | **STALE-FORM** | **DECLARED** | `dune test tests/cli/packages.t` → PASS; `mathc validate` reports unread tail at line 128. | Переписать: починить YAML tail; catalog promise оставить. |
| `mathc-self-check-subcommand` | `### self-check` row whose output carries `verdict`, `subjects[]`, `repository_digest`, and `kernel_digest`, and whose pass-condition is the AGENTS.md bootstrap-gate expiry clause verbatim. | **FALSIFIED** | **CHECKED** | `mathc self-check` → verdict unknown, 129/129 subjects unknown, exit 3; decision demands pass at lines 69 and 133. | Переписать: pass-на-репозитории заменить unknown-при-generated-store. |
| `mathjax-delimiter-hardening-2026-10` | The MathJax `<script>` block in `lib/render.ml`'s `render_head` declares `inlineMath: [['\(','\)']]` and `displayMath: [['\[','\]']]` only. No `$..$` or `$$..$$` pair is emitted in `<head>`. The default `enable_mathjax` flag re… | **STALE-FORM** | **CHECKED** | `dune test tests/render_kernel.ml` → MathJax delimiter/CSS cases OK; commitment still names moved `lib/render.ml` at lines 9, 34 and 133. | Переписать: `lib/render.ml`→`lib/render/render.ml` и обновить line anchors. |
| `mcp-agent-auto-connect-2026-10` | `adoption/SKILL.md` описывает JSON-RPC stdio-протокол, 11 MCP-методов и команду запуска `bin/mathc_mcp`. | **RECORD** | **CHECKED** | `mathc verify` → 3/3 pass; live dependency remains in `tests/cli/find.t:21,35–36` and `tests/mcp/find-readonly.t:28`. | Перенаправить find-фикстуры на живое решение, затем архивировать. |
| `migration-mechanism-2026-10` | `mathc migrate --from=X --to=Y [--root=DIR] [--format=text\|json] [--explain] [--manifest=PATH]` walks decisions/*.yaml under the given root and prints a per-file plan derived from `decisions/migrations/<from>-to-<to>.yaml`. The… | **STALE-FORM** | **CHECKED** | `dune test tests/cli/migrate-dry-run.t tests/cli/migrate-malformed.t tests/cli/migrate-no-changes.t tests/cli/migrate-write.t` → PASS; commitment/outcome still name OCAML_BEST_PRACTICES.md and AGENTS.md at lines 81, 163, 174. | Переписать: OCAML_BEST_PRACTICES.md/AGENTS.md→текущие filenames/anchors. |
| `migrations/3.0-alpha-to-3.2` | Манифест миграции поднимает schema-string с math-coding/3.0-alpha до math-coding/3.2. | **RECORD** | **DECLARED** | Schema is `math-coding/migration-manifest`; it is consumed as an operational manifest, not a decision rule. | Оставить: это operational migration manifest, не decision-rule. |
| `migrations/3.2-to-3.2.1` | Пустой опережающий манифест доказывает, что механизм миграции читает и проверяет manifests. | **RECORD** | **DECLARED** | Schema is `math-coding/migration-manifest`; empty forward manifest is operational input to `mathc migrate`. | Оставить: это operational migration manifest, не decision-rule. |
| `missing-directory-is-not-a-crash-2026-10` | With the store absent, with the axioms directory absent and with `MATH_CODING_ROOT` pointing at a path that does not exist, every command answers instead of raising. | **FALSIFIED** | **UNCHECKED** | Targeted suites are red: 2/76 cram failures plus fixture-coverage and fmt-clean failures; decision demands suite pass at lines 64 and 83. | Переписать: suite-green обещание связать с реально зелёным набором, не скрывая текущие reds. |
| `multi-policy-hierarchy-2026-10` | `lib/policy.ml::policy` record gains `parent : string option` and every existing constructor (default_policy, tests, parser) threads `None` as the default. | **STALE-FORM** | **CHECKED** | `dune test tests/policy_test.ml` → PASS; commitment item 10 still says OCAML_BEST_PRACTICES.md at line 132. | Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md. |
| `negative-control-required-2026-10` | MC-NEGATIVE-CONTROL-MISSING is emitted by `mathc validate` and is explainable with `mathc explain-diagnostic`. | **TRUE** | **CHECKED** | `mathc verify` → 2/2 pass; `bash tests/fixtures/negative-control-debt.sh` → PASS. | Оставить. |
| `new-decision-mkdir-parent-2026-10` | `new-decision --write` рекурсивно создаёт каталог решений; fresh layout остаётся `.math-coding/`. | **STALE-FORM** | **CHECKED** | new-decision/init/defaults crams PASS; `tests/cli/init-legacy.t` fails on current revision/obligations/diagnostics, and decision names it at lines 212–213. | Переписать: init-legacy expectation под текущий scaffold; mkdir-инвариант оставить. |
| `nix-develop-store-lock-contention-2026-10` | `scripts/dev-env.sh` materialises `nix print-dev-env .#test` once and evals the cached file; a cache hit takes no Nix store lock. | **TRUE** | **CHECKED** | `mathc verify` → 4/4 pass; `bash tests/fixtures/dev-cleanup-is-scoped.sh` → PASS. | Оставить. |
| `obligation-count-reconcile` | obligations.yaml lists exactly the obligation ids that decisions/decision.yaml carries, with identical ids in the same order, and names the parent decision it aggregates. | **TRUE** | **CHECKED** | `mathc verify` → 2/2 pass; `bash tests/fixtures/aggregator-matches-parent.sh` and `decision-packges-spelling.sh` → PASS. | Оставить. |
| `obligations` | Агрегатор `obligations.yaml` перечисляет семь obligation-id родительской master policy в том же порядке. | **STALE-FORM** | **CHECKED** | `bash tests/fixtures/aggregator-matches-parent.sh` → PASS; parent and aggregator each contain the same seven ids; developer-practices claim still names OCAML_BEST_PRACTICES.md at line 52. | Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md; parent revision pointer оставить явно историческим. |
| `one-corpus-walk-2026-10` | `mathc precommit` validates every decision in the corpus, including the ones filed under a sub-directory. | **TRUE** | **CHECKED** | `mathc verify` → 2/2 pass; `bash tests/fixtures/precommit-covers-subdirectories.sh` → PASS. | Оставить. |
| `one-measurer-2026-10` | On one store, the view's verdict for an obligation is the verdict the gate would reach for it. | **TRUE** | **UNCHECKED** | Targeted dune build succeeded; `dune test tests/cli/packages.t tests/cli/evidence-class.t` → PASS. | Оставить. |
| `paren-balance-fix-2026-10` | `dune build` on a clean tree returns exit code 0. | **RECORD** | **UNCHECKED** | Targeted dune build succeeds; external grep finds only `lib/codec.ml:944` comment. | Архивировать; machine dependency не найдена. |
| `parse-acceptance-diagnostics` | Decision.classify_acceptance_item is exported from lib/decision.ml and returns one of five acceptance_shape variants. Tests in tests/conformance.ml can call it directly; tests/cli/*.t exercise it via mathc validate. | **TRUE** | **CHECKED** | `dune test tests/cli/ambiguous-acceptance.t tests/cli/malformed-acceptance.t` → PASS. | Оставить. |
| `parser-risk-owner-default` | `mathc validate decisions/decision.yaml` exits 0. The file's risk block declares no `owner:`, and the kernel accepts it: the owner default landed in lib/decision.ml, so a risk block without an owner is a valid risk block. Witho… | **TRUE** | **UNCHECKED** | `mathc verify` → 2/2 pass; `mathc validate decisions/decision.yaml` → parse-ok although risk has no owner. | Оставить. |
| `paseo-console-mosaic-2026-10` | The corpus's honesty is legible in one glance, without reading a number and without adding two numbers together. | **TRUE** | **UNCHECKED** | `bash tests/fixtures/paseo-console-mosaic.sh` and `paseo-console-renders.sh` → PASS; negative control not checked because esbuild is absent. | Оставить. |
| `paseo-console-plugin-2026-10` | A person can read the state of the corpus, and every open promise with the reason it is open, without leaving the tool they work in. | **TRUE** | **UNCHECKED** | Contract, authority and render fixtures → PASS; negative control not checked because esbuild is absent. | Оставить. |
| `path-probe-anchoring-2026-11` | `mathc gate` run from an unrelated working directory reports the same non-zero obligation count as a run from the project root. | **TRUE** | **CHECKED** | `dune test tests/cli/self-check-cwd-independence.t` → PASS. | Оставить. |
| `portable-linux-musl` | Each Linux release artifact is published twice: once glibc-linked (Ubuntu-22.04 / ubuntu-24.04-arm), once musl-linked (alpine:latest). The musl variants have the `-musl` suffix. | **TRUE** | **DECLARED** | `dune test tests/repo_structure.ml` → four portable-linux-musl cases OK; external musl artifacts/CI runs not checked. | Оставить. |
| `priority-drift` | The priority-ordering line in spec/semantics.md (the ```text block under "context-prioritisation") is byte-equivalent to the priority-ordering line in OCAML_BEST_PRACTICES.md §10.5. Either both are present and identical, or bot… | **STALE-FORM** | **UNCHECKED** | `dune test tests/repo_structure.ml` → `spec-vs-bp-priority` case OK; decision still names moved OCAML_BEST_PRACTICES.md at lines 10, 25, 60 and 154. | Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md. |
| `process-principles-close-branches` | `scripts/dev close-branches` removes merged branches and their worktrees; `.githooks/pre-commit` enforces P1 + P2. | **STALE-FORM** | **CHECKED** | Four close-branches/pre-commit fixtures → PASS; `mathc verify` → 3/3 pass; commitment/claim still cite AGENTS.md at lines 67 and 142. | Переписать: `AGENTS.md`→`KERNEL_AGENTS.md` в commitment/claim. |
| `process-principles` | Принципы P1–P7 закреплены как отдельные проверяемые или явно ручные обязательства. | **STALE-FORM** | **DECLARED** | `dune test tests/process_principles.ml` → 11/11 machine cases OK; text still names `bootstrap/` and `AGENTS.md` at lines 18, 25, 56. | Переписать: `bootstrap/`→`decisions/`, `AGENTS.md`→`KERNEL_AGENTS.md`. |
| `protected-paths-and-empty-diff-2026-11` | The protected paths of this repository are one list in `scripts/protected-paths.txt`, and the gate, the pre-commit hook and the release-pending workflow all read it. | **TRUE** | **CHECKED** | `bash tests/fixtures/protected-paths-single-source.sh` → PASS; `dune test tests/cli/protected-paths-single-source.t tests/cli/gate-empty-diff.t` → PASS. | Оставить. |
| `re-evaluation-is-not-a-check-2026-10` | `mathc re-evaluate-decisions` files `kind_: review`, `result: inconclusive`, with `producer.run` naming the command. | **TRUE** | **CHECKED** | `mathc verify` → 1/1 pass. | Оставить. |
| `record-proportionality-2026-10` | The `mode_floor` a project declares in `policies.yaml` is the floor the kernel applies, and `mathc mode` reports it. | **STALE-FORM** | **CHECKED** | `dune test tests/cli/mode-floor-from-policies.t` → PASS; `tests/cli/gate-trailer-decision.t` expects block but current output is unknown. | Переписать: Block→Unknown для неразрешённой/dangling citation. |
| `redundancy-census-2026-11` | A fixture reports how many promises the kernel cannot execute, how many relation targets resolve to nothing, how many scope paths match no file, and how many decisions the live corpus holds, and pins each number as a ceiling. | **FALSIFIED** | **UNCHECKED** | `MATH_CODING_ROOT="$PWD" bash tests/fixtures/redundancy-census.sh` → FAIL: «the synthetic corpus measured 35 paper obligations, not above the ceiling 36 - the ceiling cannot bind». В чистом окружении тот же прибор даёт 41 и PASS. Причина — не потолок, а УНАСЛЕДОВАННОЕ ОКРУЖЕНИЕ: с MATH_CODING_ROOT, указывающим на живой корпус, контроль мерил ЖИВОЙ корпус вместо синтетического. | Починено 2026-11-01: контроль очищает MATH_CODING_ROOT/DECISIONS_DIR/ATTESTATIONS_DIR/STORE и требует, чтобы измеренное число было не меньше числа созданных синтетических решений — иначе контроль не доказал, что мерил свой корпус. Находка выжила, объяснение и лечение изменились. |
| `render-kernel-fixes-2026-10` | The 10 defects catalogued in `analysis/site-render-defects.md` (2026-10-07) are closed. `tests/render_kernel.ml` carries a positive and a negative fixture for each; the `tests/cli/render.t` cram snapshot asserts the produced `d… | **RECORD** | **CHECKED** | `dune test tests/render_kernel.ml` → 47/47 OK; external grep finds comments/test labels, no machine opening the decision. | Архивировать; machine dependency не найдена. |
| `render-module-split-phase1a-2026-10` | `lib/render/render_md.ml` существует, перечисленные выше публичные символы реэкспортированы из `lib/render/render.ml`, `dune build` собирает `mathcoding_render` с двумя модулями. | **RECORD** | **DECLARED** | `state: superseded`; machine reads at `tests/corpus_no_silent_drops/corpus_no_silent_drops.ml:365` and `tests/yaml_seq_continuation.ml:434`; golden comparison is manual and currently differs. | Перенаправить два exact-path теста на archive, затем архивировать. |
| `render-module-split` | `lib/render/render.ml` is a separate dune library `mathcoding_render` and is the only file in that library; subsequent splits (Phase 1+ of the refactor) land as additional modules in the same `lib/render/` directory. | **RECORD** | **UNCHECKED** | Current renderer has multiple modules; external grep finds only comments (`lib/render/render_lang.ml:3`), no machine opens the decision. | Архивировать; machine dependency не найдена. |
| `render-ordered-lists-2026-10` | `Render.md_parse` of a `1. `, `2. `, ... sequence returns `<ol><li>...</li><li>...</li>...</ol>`, with each `<li>` carrying one item (multi-line continuations joined with a single space). Verified by `tests/render_kernel.ml::or… | **STALE-FORM** | **CHECKED** | `dune test tests/render_kernel.ml` → ordered-list positive/multidigit/continuation cases OK; commitment still names moved lib/render.ml and AGENTS.md at lines 49 and 113. | Переписать: `lib/render.ml`→`lib/render/render.ml`, `AGENTS.md`→`KERNEL_AGENTS.md`. |
| `risk-and-scaffold-honesty-2026-11` | The irreversibility marker function names segment tokens, the spec's marker table names the same three entries, and the check `tests/fixtures/risk-dead-branches-gone.sh` fails if a directory prefix comes back. | **TRUE** | **CHECKED** | `bash tests/fixtures/risk-dead-branches-gone.sh` → PASS; policy/new-decision/risk crams → PASS. | Оставить. |
| `risk-policy-driven-floor-2026-10` | The §2 `mode(c) = max(risk_to_mode(risk(c)), mode_floor(c))` formula in `lib/risk.ml` is fully wired: `mode_floor` and `policy_override_probability` are no longer constants but read the cached policy list. The axioms policy rai… | **TRUE** | **CHECKED** | `dune test tests/risk_kernel.ml tests/cli/mode.t` → PASS. | Оставить. |
| `self-check-subject-set-2026-10` | The report names the decisions in `subjects[]` and the instrument in `corpus`, and says how many decisions it excluded and why. | **TRUE** | **UNCHECKED** | Targeted dune build succeeded; `mathc self-check` JSON separates 129 `subjects` from `corpus` blocks. | Оставить. |
| `self-check-waiver-verdict-coherence-2026-10` | A subject whose gaps are accepted by a waiver reports `open-with-waiver`, never `pass`, at both the subject and the repository level. `pass` and a non-empty `causes[]` are no longer co-representable. | **TRUE** | **CHECKED** | `dune test tests/cli/self-check-waiver-verdict.t tests/cli/gate-waiver-scope.t tests/waiver_test.ml` → PASS. | Оставить. |
| `site-broken-links-2026-10` | both link to `index.html`; `home.html` does not appear anywhere on `dist/index.ru.html`. | **STALE-FORM** | **CHECKED** | `dune test tests/render_kernel.ml` → link/nav/footer cases OK; commitment still names moved lib/render.ml at lines 79, 85, 95 and 150. | Переписать: `lib/render.ml`→`lib/render/render.ml`. |
| `site-deploy` | `.github/workflows/site.yml` runs on every push to main and publishes `dist/` to GitHub Pages via `actions/deploy-pages@v4`. | **STALE-FORM** | **DECLARED** | `dune test tests/render_kernel.ml tests/cli/render.t` → PASS; `.github/workflows/site.yml` contains deploy-pages job; commitment still names moved lib/render.ml at line 38; live GitHub run not checked. | Переписать: `lib/render.ml`→`lib/render/render.ml`. |
| `site-diagrams-as-svg-2026-10` | `lib/render.ml`, `bin/Mathc.ml`, and `assets/style.css` contain no Mermaid support: no `mermaid` code-fence branch, no `enable_mermaid` config field or CLI flag, no Mermaid CDN script, and no `.mermaid` CSS rules. | **STALE-FORM** | **UNCHECKED** | `dune test tests/render_kernel.ml` → Mermaid-removed and inline-SVG cases OK; commitment/outcome still name moved lib/render.ml at lines 33, 68 and 88. | Переписать: `lib/render.ml`→`lib/render/render.ml`. |
| `site-quality-2026-10` | Сайт имеет одно-строчный hero, live-числа, spec-link и полные narrative-страницы каждого решения. | **STALE-FORM** | **DECLARED** | Only `manual-render-*` claims exist; exact visual/live-count checks not executed (DECLARED); outcome still names moved lib/render.ml at lines 178 and 194. | Переписать: `lib/render.ml`→`lib/render/render.ml`; visual claims оставить DECLARED. |
| `site-quality-distribution-2026-10` | Сайт публикует валидный RSS 2.0 feed и onboarding CTA на главной странице. | **TRUE** | **DECLARED** | Only `manual-feed-xml-is-valid` and `manual-cta-block-emits` exist; exact feed/CTA checks not executed (DECLARED). | Оставить. |
| `site-quality-illustrations-2026-10` | Сайт публикует SVG цепочки assure, иконки аксиом и архитектурные схемы. | **STALE-FORM** | **UNCHECKED** | `mathc verify` → 3/3 pass; SVG assets and references exist; promise still names moved lib/render.ml at line 32. | Переписать: `lib/render.ml`→`lib/render/render.ml`. |
| `site-redesign-2026-10` | Landing page имеет четыре intent-driven меню, SVG logo, hero без package grid и зеркальную RU-структуру. | **RECORD** | **DECLARED** | Only manual visual/browser claims exist; implementation comments cite the record at `lib/render/render_nav.ml:10` and `assets/style.css:112`. | Архивировать; machine dependency не найдена. |
| `skill-single-source-2026-10` | The applicability rule is stated once, in §28, and the corpus checks that the skill and the CLI agree with it. | **TRUE** | **UNCHECKED** | `mathc verify` → 4/4 pass; `bash scripts/check-applicability-agreement.sh` and `check-opencode-skill.sh` → PASS. | Оставить. |
| `solo-default-on-2026-10` | A project with a single maintainer receives `mathc init` scaffolding and the agent skill; the sole exclusion is `prototype_or_throwaway`. | **TRUE** | **CHECKED** | `dune test tests/cli/init-applicability-envelope.t` → PASS; skill copies identical. | Оставить. |
| `spec-cli-catalog` | spec/semantics.md contains a "CLI subcommands" section that lists every mathc subcommand present in bin/Mathc.ml at HEAD: version, validate, context, assess, attest, gate, session-start, record, stats, time-estimate. Each entry… | **FALSIFIED** | **UNCHECKED** | `spec/semantics.md` has 18 CLI headings; `bin/Mathc.ml:12038–12076` dispatches 39 commands, so 21 are absent. | Переписать: либо добавить 21 отсутствующую CLI-команду, либо сузить обещание до поддерживаемого набора. |
| `store-not-committed-2026-10` | attestations/ is not tracked by git; it is produced by scripts/sign-store.sh and is not part of any commit. | **TRUE** | **UNCHECKED** | `git check-ignore -v attestations/foo` → `/attestations/`; `git ls-files attestations/**` → 0; CI-prereq fixture PASS; generation run not performed. | Оставить. |
| `stub-lint-real-2026-10` | scripts/check-stub-lint.sh --mode=real-diff accepts a staged diff against lib/** and bin/Mathc.ml and classifies each new stub marker as `tracked` (a paired decision exists) or `untracked` (no paired decision). Exit 0 on all-tr… | **TRUE** | **CHECKED** | `bash scripts/check-stub-lint.sh` → PASS; process-principles P8 regression case OK. | Оставить. |
| `the-kernel-speaks-for-itself-2026-10` | What a reader sees is what the kernel decided to say, and the tools the kernel uses do not speak over it. | **TRUE** | **CHECKED** | `dune test tests/cli/doctor.t tests/cli/update.t tests/cli/gate-cycle-guard.t` → PASS. | Оставить. |
| `time-honesty-storage` | For every recorded agent session, an event is appended to decisions/execution-logs.jsonl with scale = wall-clock- minutes and value = (now - session_start). mathc stats reports the empirical distribution against the declared fl… | **TRUE** | **DECLARED** | `mathc verify` → 3/3 pass; ignored paths confirmed by `git check-ignore`; one manual end-to-end case not checked. | Оставить. |
| `time-honesty` | Durable-нормы используют три наблюдаемые шкалы и воспроизводимый reference-class estimator. | **STALE-FORM** | **CHECKED** | `dune test tests/conformance.ml` → PASS; rule is at `KERNEL_AGENTS.md:468`, while decision still names `AGENTS.md` at lines 20 and 116. | Переписать: `AGENTS.md`→`KERNEL_AGENTS.md`, 3.0-alpha→текущая версия. |
| `unanchored-attestations-are-declarations-2026-10` | The 765 committed attestations are declared, in this decision, to be unanchored declarations. No reader of the store can infer from them which tree any observation was made against, and no future commit may quietly change that. | **STALE-FORM** | **UNCHECKED** | `dune test tests/attestation_anchor.ml` → PASS only for current 0-file corpus; decision’s exact pin 765 at lines 18 and 134 is obsolete. | Переписать/архивировать исторический pin 765; live store генерируется и имеет 0 tracked files. |
| `unmet-obligations-inventory-2026-10` | Every obligation the re-signing refused to sign appears in the inventory exactly once, with a verdict and a recommendation. | **RECORD** | **CHECKED** | `bash tests/fixtures/unmet-obligations-are-inventoried.sh` → PASS; fixture requires the live path at line 39. | Перенаправить inventory fixture на archive, затем архивировать. |
| `validate-and-context` | `mathc validate FILE` reads FILE (json or yaml), parses via Decision.parse_decision, and reports accept or reject with structured diagnostics. Exit codes 0/1/2/3 align with spec/semantics.md "exit honesty" and OCAML_BEST_PRACTI… | **STALE-FORM** | **CHECKED** | validate/context crams PASS; current version is 3.7.4, while decision requires `math-coding 3.0-alpha: bootstrap` at lines 72 and 220. | Переписать: version literal 3.0-alpha→`VERSION`/3.7.4. |
| `verdict-vocabulary-and-waiver-expiry-2026-10` | `spec/semantics.md` enumerates the four kernel verdicts in §Kernel Output, in the `gate` and `self-check` CLI rows and in no stale three-value form anywhere; §Kernel Output states the verdict→exit table; §Waiver Validity states… | **TRUE** | **CHECKED** | `bash tests/fixtures/verdict-vocabulary-spec-coherence.sh` → PASS; waiver-expiry and waiver unit tests PASS. | Оставить. |
| `verifier-outcome-taxonomy-2026-10` | Kernel различает failed, setup-failed/skipped и manual declaration; debt-ceilings измеряются, а не пересказываются. | **STALE-FORM** | **DECLARED** | `bash tests/fixtures/legacy-attestation-debt.sh` → exit 3 (no store); decision pins old 22/30/25 counts at lines 27–28. | Переписать: старые debt counts→текущие generated-store semantics. |
| `verifier-path-resolution-2026-10` | A verifier path that cannot be resolved produces a verdict: Block when absolute, Warn when relative and missing. | **TRUE** | **CHECKED** | `mathc verify` → 3/3 pass; `bash tests/fixtures/verifier-path-resolution.sh` → PASS. | Оставить. |
| `verifier-scheme-convention-2026-11` | `mathc validate` emits one Warn MC-VERIFIER-SCHEME-UNKNOWN per non-canonical scheme token in obligations[*].acceptance.all[*].verifier, naming the obligation id and the scheme token. | **TRUE** | **DECLARED** | `bash tests/fixtures/verifier-schemes-are-canonical.sh` → PASS; unknown-scheme cram PASS; manual self-check delta not checked. | Оставить. |
| `verifier-strings-the-kernel-can-read-2026-10` | The worklist names every open promise, and no promise is invisible to the kernel because of how it is spelled. | **TRUE** | **UNCHECKED** | `bash tests/fixtures/no-invisible-promises.sh` → PASS (0 cannot-be-set-up, 0 unidentified). | Оставить. |
| `verify-honesty-2026-10` | Under the `all` rule, a verifier that could not be set up makes the obligation `skipped` even when a sibling verifier passed. | **TRUE** | **CHECKED** | `dune test tests/cli/verify-exit.t` → PASS; `bash tests/fixtures/the-kernel-stamp-flips-when-the-code-changes.sh` → PASS. | Оставить. |
| `verify-path-forms-and-signed-attestations-2026-10` | `bin/Mathc.ml::plan_verifier` classifies a verifier string into an argv -- `dune exec ./tests/foo.exe`, `dune runtest tests/cli/gate-pass.t`, an absolute repository script path, or `dune <args>` -- and `run_verifier_plan` execu… | **TRUE** | **DECLARED** | `dune test tests/cli/verify-path-forms.t tests/cli/attest-batch-signature.t` → PASS; one manual file-existence label not checked. | Оставить. |
| `version-sync-2026-10` | `adoption/SKILL.md` `compatible_with` and `MC_VERSION` lines derive from `VERSION` and are kept in sync by `scripts/sync-version.sh`. | **STALE-FORM** | **CHECKED** | `mathc verify` → 4/4 pass; sync-version clean/drift fixtures PASS; commitment/outcome still name OCAML_BEST_PRACTICES.md at lines 84 and 134. | Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md. |
| `waiver-infrastructure-2026-10` | `lib/waiver.ml` exposes `load`, `covers`, and `effective_at`. The pure parser (`Waiver.parse`) is covered by `tests/waiver_test.ml` (15 cases). The filesystem-touching `load` is covered indirectly by `tests/cli/self-check-pass.… | **FALSIFIED** | **UNCHECKED** | Decision says Open_with_waiver→pass at lines 59, 94, 100; current `lib/gate.ml:66–68` and `bin/Mathc.ml:8588–8611` keep `open-with-waiver` distinct. | Переписать: `open-with-waiver` больше не сворачивается в `pass`; связать с exit-code-symmetry. |
| `waiver-missing-expiry-rejected-2026-10` | `mathc validate fixtures/conformance/waiver/negative-missing-expiry.json` exits 1 and names the missing field. | **TRUE** | **CHECKED** | `mathc verify` → 2/2 pass; `bash tests/fixtures/waiver-missing-expiry-rejected.sh` → PASS. | Оставить. |
| `yaml-block-scalars` | lib/codec.ml's load_yaml_string returns a Jsonl.String whose body matches the canonical reading of the YAML block scalar: literal keeps newlines, folded joins adjacent non-empty lines with spaces, clip leaves one trailing newli… | **TRUE** | **DECLARED** | `dune test tests/yaml_block_scalars.ml` → 10/10 pass; two manual conformance-fixture labels remain unexecuted. | Оставить. |

## 2. Сводка по вердиктам

| вердикт | число |
|---|---:|
| TRUE | 73 |
| FALSIFIED | 9 |
| STALE-FORM | 34 |
| RECORD | 20 |
| **Всего** | **136** |

**Не проверено полностью:** 29 решений. Это 21 решение с `manual-*` verifier-ом и ещё 8, чья проверка требует отсутствующего generated store, внешнего CI/release/OCI-канала или `esbuild`. Список и причина — в разделе 8.

## 3. Сводка по классу контроля

| класс контроля | число |
|---|---:|
| CHECKED | 78 |
| DECLARED | 24 |
| UNCHECKED | 34 |
| **Всего** | **136** |

**Правило одного прохода.** CHECKED — в решении есть релевантный negative control либо named verifier/fixture содержит rejecting/mutation case. DECLARED — решение явно говорит, что проверки нет: verifier `manual-*`, либо это operational/historical документ без obligations. UNCHECKED — всё остальное: promise выглядит проверенным, но эффективного отрицательного контроля нет. Если решение содержит хотя бы одну substantive manual-declaration, класс DECLARED отражает неполное машинное покрытие всего решения.

**DECLARED = 24:** 21 решение с `manual-*` плюс три operational/historical документа без obligations (`attestation-store-fill` и два migration manifest). Остальные 78 имеют работающую отрицательную или rejecting-проверку.

Это не то же самое, что счётчик «не проверено полностью: 29» из раздела 2: 29 — вторичная measurement полноты evidence (ручные, store-, CI- и tool-зависимые утверждения), а 24 — класс природы самого promise.

## 4. UNCHECKED — что не может упасть

### 4.1 `agent-onboarding`

- **Доказательство:** `negative_control:` отсутствует; `tests/repo_structure.ml` проверяет текущее наличие/текст, но не имеет сломанной копии, которая доказывает ловлю именно этого promise.

### 4.2 `algebra-3.2`

- **Доказательство:** `negative_control:` отсутствует; широкие `tests/repo_structure.ml`/`tests/conformance.ml` не содержат negative case для заявления «30 sections / 28 active / conformance».

### 4.3 `cli-cram-tests`

- **Доказательство:** `negative_control:` отсутствует; `dune build @tests/cli/runtest` проверяет текущий suite, но не mutation, доказывающий, что именно старые 14 shell fixtures должны исчезнуть.

### 4.4 `constitution-header-3-3-update-2026-10`

- **Доказательство:** `negative_control:` отсутствует; единственный verifier — `shell-grep ... Math-coding`, без сломанного H1, который должен дать non-pass.

### 4.5 `corpus-final-state-2026-10`

- **Доказательство:** `negative_control:` отсутствует; `no-invisible-promises.sh` измеряет только два класса, но не доказывает «всякое правило/acceptance/self-check exit 0».

### 4.6 `corpus-tranche-archive-records-2026-11`

- **Доказательство:** `negative_control:` указывает на generic shell-grep control, не связанный с 13 `file-exists` promises; нет mutation, доказывающего ловлю wrong archive path/state.

### 4.7 `decision-level-census-2026-10`

- **Доказательство:** `negative_control:` отсутствует; verifier — широкий `dune test --root .` плюс self-validate, без census-specific broken corpus.

### 4.8 `forge-principal-verification-2026-10`

- **Доказательство:** `negative_control:` отсутствует; текущий `tests/cli/forge-verify.t` проверяет ПРОТИВОПОЛОЖНОЕ обещанию (unset forge → unknown/exit 3), поэтому не может поймать именно fail-open→pass.

### 4.9 `formal-verifier-conventions`

- **Доказательство:** `negative_control:` отсутствует; `tests/repo_structure.ml` проверяет текущую convention, но не имеет удалённой/изменённой convention, которая должна дать non-pass.

### 4.10 `gate-by-diff-2026-10`

- **Доказательство:** `negative_control:` отсутствует; его `dune build`, полный suite и `--help` не проверяют различие scoped/unscoped и execute/no-execute семантики.

### 4.11 `gate-decision`

- **Доказательство:** `negative_control:` отсутствует; `tests/cli/gate-scaffold.t` фиксирует текущую JSON shape, но не имеет изменённого gate output, который должен её опровергнуть.

### 4.12 `gate-report-proportional-2026-10`

- **Доказательство:** `negative_control:` отсутствует; `gate-scaffold.t` проверяет текущий limit, но не доказывает, что limit=0 и limit=N дают одинаковый verdict на изменённом gap set.

### 4.13 `grep-schemes-are-executable-2026-10`

- **Доказательство:** `negative_control:` отсутствует; generic control существует, но решение его не называет, а его verifier не доказывает failure обеих grep-форм на сломанном pattern.

### 4.14 `honest-attestation-emission-2026-10`

- **Доказательство:** Указанный `executed-evidence-census.sh` сейчас exit 3 из-за отсутствующего store и не исполняет re-sign write/prune path; обещанный runtime anchor не пойман.

### 4.15 `infrastructure-honesty`

- **Доказательство:** `negative_control:` отсутствует; repo-structure проверяет существование текущих targets, но не содержит сломанного workflow/dependency, который должен дать non-pass.

### 4.16 `mathc-counters-subcommand-2026-10`

- **Доказательство:** `negative_control:` отсутствует; `scripts/check.sh`/`tests/repo_structure.ml` не содержат broken-call/mutation case, отличающий новый counters от старого Python helper.

### 4.17 `missing-directory-is-not-a-crash-2026-10`

- **Доказательство:** `negative_control:` отсутствует; широкий suite сейчас красный и не изолирует сценарий missing store, поэтому не доказывает ловлю именно этого дефекта.

### 4.18 `one-measurer-2026-10`

- **Доказательство:** `negative_control:` отсутствует; `dune test --root .` не сравнивает verdict одного synthetic store между packages и gate.

### 4.19 `paren-balance-fix-2026-10`

- **Доказательство:** `negative_control:` отсутствует; verifier — только `dune build`, который не содержит broken-syntax case, ловящего именно balance regression.

### 4.20 `parser-risk-owner-default`

- **Доказательство:** `negative_control:` отсутствует; `mathc validate` и grep проверяют текущий default, но не имеют risk-without-owner case, который должен доказать default path.

### 4.21 `paseo-console-mosaic-2026-10`

- **Доказательство:** Назначенный `paseo-console-negative-control.sh` падает не из-за mutation, а из-за отсутствующего `esbuild` («esbuild is not installed»), поэтому требуемый broken-tree control не исполнен.

### 4.22 `paseo-console-plugin-2026-10`

- **Доказательство:** Назначенный negative control так же падает по отсутствию `esbuild`, а не по изменённому plugin; ожидаемая причина красного не достигнута.

### 4.23 `priority-drift`

- **Доказательство:** `negative_control:` отсутствует; repo-structure сравнивает текущие зеркала, но не содержит намеренно изменённой mirror line, которая должна дать diff/non-pass.

### 4.24 `redundancy-census-2026-11`

- **Доказательство:** Назначенный negative control сейчас измеряет PAPER=36, то есть **не превышает** ceiling 36; fixture красный, но не ловит заявленный paper defect.

### 4.25 `render-module-split`

- **Доказательство:** `negative_control:` отсутствует; verifier — build, без broken API/golden case, доказывающего сохранение public surface.

### 4.26 `self-check-subject-set-2026-10`

- **Доказательство:** `negative_control:` отсутствует; verifier — широкий build/self-validate, без synthetic subject set, отличающий новую границу subjects от corpus.

### 4.27 `site-diagrams-as-svg-2026-10`

- **Доказательство:** `negative_control:` отсутствует; render tests проверяют текущий output, но не содержат broken renderer, который должен вернуть Mermaid и дать non-pass.

### 4.28 `site-quality-illustrations-2026-10`

- **Доказательство:** `negative_control:` отсутствует; verifier — семь `file-exists`, без removed/wrong-asset case, доказывающего ловлю claim-а об illustrations.

### 4.29 `skill-single-source-2026-10`

- **Доказательство:** `negative_control:` отсутствует; scripts сравнивают текущие surfaces, но нет mutated third surface, который должен заставить agreement check упасть.

### 4.30 `spec-cli-catalog`

- **Доказательство:** `negative_control:` отсутствует; repo-structure проверяет лишь наличие CLI section, но не полноту; 21 dispatch-команда уже отсутствует без красного verifier-а.

### 4.31 `store-not-committed-2026-10`

- **Доказательство:** Назначенный census не проверяет generation path (store отсутствует → exit 3), поэтому не доказывает, что generation оставляет только наблюдённое и удаляет orphan.

### 4.32 `unanchored-attestations-are-declarations-2026-10`

- **Доказательство:** `negative_control:` отсутствует; anchor test на текущем 0-file corpus не воспроизводит historical pin 765 и не имеет broken attestation mutation.

### 4.33 `verifier-strings-the-kernel-can-read-2026-10`

- **Доказательство:** `negative_control:` отсутствует; `no-invisible-promises.sh` считает два пустых класса, но не подставляет malformed verifier, который должен сделать их непустыми.

### 4.34 `waiver-infrastructure-2026-10`

- **Доказательство:** `negative_control:` отсутствует; named verifier — положительный `self-check-pass.t`, без open-with-waiver/non-pass counterpart; текущий код уже противоречит старому collapse-to-pass.

## 5. FALSIFIED — что дерево опровергло

### 5.1 `corpus-final-state-2026-10`

- **Обещание:** Обещает, что corpus состоит только из правил, каждое obligation исполняемо/принято, а `mathc self-check` завершает работу exit 0.
- **Доказательство:** `bash tests/fixtures/redundancy-census.sh` → `corpus: 136 decisions`, `paper obligations ...: 36`; `MATH_CODING_ROOT="$PWD" .../mathc.exe self-check` → `verdict=unknown`, 129 subjects, exit 3. Свои же строки 93 и 109 обещают exit 0.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Переписать target в измеримое текущее правило; либо честно объявить его DECLARED с owner/date.

### 5.2 `corpus-silent-drop-inventory-2026-10`

- **Обещание:** Обещает reproducible exact-set ledger и `kernel_holes = 0`.
- **Доказательство:** `bash scripts/scan-silent-drops.sh --validity` → `5 of 135 file(s) carry a silent-drop diagnostic`: 3-2-cli-catalog, ci-blocking-list-config, d5-body-vs-wrapper-canonical, forge-stub-read-request, mathc-packages-subcommand. Решение фиксирует 12/216 и пустой kernel_holes в строках 44, 80, 190.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Переписать ledger на текущие пять файлов и отделить author-malformed от kernel-holes.

### 5.3 `gate-attestation-store-fill-decision`

- **Обещание:** Обещает, что gate verdict `unknown` завершает работу exit 0 и open-with-waiver допустим как exit 0.
- **Доказательство:** Решение: строки 44, 53, 99 требуют unknown→0. Текущий код `bin/Mathc.ml:6709–6711` отображает Unknown→3; `dune test tests/cli/gate-unknown-exit-3.t` подтверждает exit 3.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Переписать обещание под действующую exit-code symmetry; не оставлять два противоречащих активных правила.

### 5.4 `forge-principal-verification`

- **Обещание:** Обещает, что недоступный forge при fail-mode=open даёт verdict=pass и exit 0.
- **Доказательство:** Решение: строки 24–25 и 90–94. Текущий `tests/cli/forge-verify.t` явно ожидает `verdict=unknown` и `[3]` для unset forge и проходит; `bin/Mathc.ml:9512–9519,9655–9662` реализует unknown/exit 3.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Переписать fail-open contract под exit-honesty-waivers: отсутствие forge — unknown, а не pass.

### 5.5 `mathc-self-check-subcommand`

- **Обещание:** Обещает `mathc self-check` → pass/exit 0 против этого репозитория.
- **Доказательство:** `.../mathc.exe self-check` → exit 3, `verdict=unknown`, 129/129 subjects unknown; текущий store генерируется и отсутствует. Решение требует pass в строках 69 и 133.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Переписать на generated-store/unknown semantics и оставить отдельное правило для CI audit.

### 5.6 `missing-directory-is-not-a-crash-2026-10`

- **Обещание:** Обещает, что весь repository suite проходит без generated store.
- **Доказательство:** Адресный прогон уже опровергает: 2 из 76 cram (`gate-trailer-decision.t`, `init-legacy.t`) красны; из 19 OCaml-целей красны `fixture_coverage.ml` (54 > ceiling 52) и `repo_structure.ml` (`fmt-clean`). Достаточного подмножества уже нет, чтобы suite был зелёным.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Переписать обещание; не маскировать reds фразой про отсутствие store.

### 5.7 `redundancy-census-2026-11`

- **Обещание:** Обещает negative control, который превышает каждый ceiling и доказывает, что bound умеет связывать.
- **Доказательство:** `bash tests/fixtures/redundancy-census.sh` → measurements зелёные (136/36/0/0), затем `FAIL: negative control: the synthetic corpus measured 36 paper obligations, not above the ceiling 36`.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Починить synthetic corpus/negative control, затем перепроверить обещание `the-ceilings-have-teeth`.

### 5.8 `spec-cli-catalog`

- **Обещание:** Обещает, что normative CLI section перечисляет каждую команду dispatcher-а.
- **Доказательство:** В `spec/semantics.md` 18 `###` CLI headings; `bin/Mathc.ml:12038–12076` содержит 39 dispatch-команд. 21 отсутствует, включая verify, update, explain-diagnostic, init, migrate, doctor, rehash.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Переписать claim на реально поддерживаемый набор либо дополнить spec; текущий `spec-catalog-present` проверяет лишь наличие секции.

### 5.9 `waiver-infrastructure-2026-10`

- **Обещание:** Обещает, что `Open_with_waiver` отображается как `pass`.
- **Доказательство:** Решение: строки 59, 94, 100. Текущий код сохраняет отдельный verdict: `lib/gate.ml:66–68` → `open-with-waiver`; `bin/Mathc.ml:8588–8611` явно не сворачивает его в pass.
- **Что именно опровергнуто:** стенд формулирует обещание как текущий факт, а текущий kernel/дерево даёт другое поведение или иной результат.
- **Действие:** Переписать к `open-with-waiver` и связать с exit-code-symmetry; это уже не мелочь формулировки.

## 6. STALE-FORM — суть верна, форма устарела

### 6.1 `3-2-cli-catalog`

- **Что устарело:** Три добавленные строки на месте, но исторические 17/14 и глобальное “lists every subcommand” больше не описывают дерево; сам файл теряет tail.
- **Доказательство:** `bash tests/fixtures/3-2-cli-catalog-rows-present.sh` → PASS; `mathc validate` → MC-UNPARSED-TAIL at line 183; spec has 18 CLI headings vs 39 dispatch commands.
- **Исправление формулировки:** Переписать: заменить исторические 17/14 на инвариант полного CLI-каталога и починить unread tail.

### 6.2 `agent-onboarding`

- **Что устарело:** Правила ADR/formal/read-first живы, но текст и obligation всё ещё называют AGENTS.md и bootstrap/.
- **Доказательство:** `dune test tests/repo_structure.ml` → `agent-onboarding` case OK; text still names `AGENTS.md` at lines 12, 43, 187.
- **Исправление формулировки:** Переписать: `AGENTS.md`→`KERNEL_AGENTS.md`, `bootstrap/`→`decisions/`.

### 6.3 `algebra-3.2`

- **Что устарело:** Normative adoption остаётся, но «28 active decisions» и старое число — историческая форма; текущий corpus уже 136.
- **Доказательство:** `dune test tests/repo_structure.ml tests/conformance.ml` → relevant cases OK; file still says “28 active” at lines 110 and 262, census says 136.
- **Исправление формулировки:** Переписать: 28 решений/текущие отклонения заменить ссылкой на измеряемый contract T3.2.

### 6.4 `attestation-producer-vocab-2026-10`

- **Что устарело:** Правило producer vocabulary живо и проверяется, но historical 765/703 tracked-store числа относятся к уже удалённому committed store.
- **Доказательство:** `dune test tests/producer_vocab.ml tests/conformance.ml tests/store_admission.ml` → PASS; one manual case not checked; historical 765-file counts are obsolete because the store is generated.
- **Исправление формулировки:** Переписать: убрать historical 765/703 tracked-store counts, оставив правило producer vocabulary.

### 6.5 `ci-blocking-list-config`

- **Что устарело:** API и default-list ещё существуют, но решение говорит historical/current неоднозначно, а 18 строк файла kernel не читает.
- **Доказательство:** `dune test tests/ci_blocking_list_test.ml` → PASS; `mathc validate` reports unread tail at line 138.
- **Исправление формулировки:** Переписать: починить YAML tail и historical-list wording; не менять API без нужды.

### 6.6 `d5-body-vs-wrapper-canonical-2026-10`

- **Что устарело:** §7.1 и helper существуют, но ссылки на прежнюю реализацию и implementation-цитаты устарели; tail файла не читается.
- **Доказательство:** `dune test tests/body_canonical_test.ml` and `tests/cli/body-vs-wrapper-canonical.t` → PASS; `mathc validate` reports unread tail at line 618.
- **Исправление формулировки:** Переписать: починить YAML tail и ссылки на implementation §7.1.

### 6.7 `decision`

- **Что устарело:** Bootstrap-v3 всё ещё master policy, однако intent/commitment/assumption/manual claims говорят о мире до появления kernel 3.0.
- **Доказательство:** `VERSION` is 3.7.4; file still says “Build math-coding 3.0” (line 13), “Until the 3.0 kernel exists” (line 44), and `AGENTS.md` (line 68).
- **Исправление формулировки:** Переписать master policy под текущую версию/kernel и ручные declarations.

### 6.8 `duplicate-mapping-keys-silent-drop-2026-10`

- **Что устарело:** Диагностика работает, но exact list/verifier-цели этого решения ссылаются на удалённые решения и старое число 18.
- **Доказательство:** `mathc verify` fails because lines 303–316 validate deleted targets; live tree still has five unread tails.
- **Исправление формулировки:** Переписать: удалённые verifier-цели заменить нынешними пятью unread-tail файлами.

### 6.9 `executed-evidence-census-2026-10`

- **Что устарело:** Instrument существует и честно отвечает unknown при отсутствии store, но слова “tracked store/attestations” больше не соответствуют generated store.
- **Доказательство:** `bash tests/fixtures/executed-evidence-census.sh` → exit 3 (“no attestation store”); file still says “tracked store” at lines 52 and 137.
- **Исправление формулировки:** Переписать: tracked store→generated disk store; текущие числа помечать generated/unknown.

### 6.10 `forge-stub-read-request-2026-10`

- **Что устарело:** Поведение stub проверено, но второй document marker делает后半 решения недоступным kernel-у.
- **Доказательство:** `bash tests/fixtures/forge-stub-read-request.sh` → PASS; `mathc validate` reports a second `---` at line 295.
- **Исправление формулировки:** Переписать: удалить второй `---` в line 295.

### 6.11 `formal-verifier-conventions`

- **Что устарело:** Соглашение живо в OCAML_KERNEL_CONVENTIONS.md, но текст решения всё ещё требует OCAML_BEST_PRACTICES.md §10.6.
- **Доказательство:** `dune test tests/repo_structure.ml` → `formal-verifier-prefixes` OK; prefixes now live at `OCAML_KERNEL_CONVENTIONS.md:1005–1007`, not the named file.
- **Исправление формулировки:** Переписать: `OCAML_BEST_PRACTICES.md`→`OCAML_KERNEL_CONVENTIONS.md` (таблица lines 1005–1007).

### 6.12 `install-tooling-2026-10`

- **Что устарело:** Install path жив, но commitment/outcomes называют переименованный OCAML_BEST_PRACTICES.md; внешние release/OCI каналы отдельно не проверены.
- **Доказательство:** `dune test tests/cli/install.t` → PASS; commitment/outcomes still name OCAML_BEST_PRACTICES.md (lines 167, 298, 456); external release/OCI/nix channel and manual `nix flake check` not checked.
- **Исправление формулировки:** Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md; внешние каналы оставить DECLARED.

### 6.13 `legacy-attestation-debt-2026-10`

- **Что устарело:** Fixture и монотонность живы, но debt теперь по generated directory, а не по tracked files; числовые основания устарели.
- **Доказательство:** `bash tests/fixtures/legacy-attestation-debt.sh` → exit 3 (no store); text still says tracked attestations at lines 16 and 95.
- **Исправление формулировки:** Переписать: tracked→generated store и актуальные ceilings.

### 6.14 `mathc-packages-subcommand`

- **Что устарело:** Команда и JSON работают, но файл содержит unread tail; promise о полном package view надо отделить от формы файла.
- **Доказательство:** `dune test tests/cli/packages.t` → PASS; `mathc validate` reports unread tail at line 128.
- **Исправление формулировки:** Переписать: починить YAML tail; catalog promise оставить.

### 6.15 `mathjax-delimiter-hardening-2026-10`

- **Что устарело:** MathJax behavior жив, но commitment/outcome указывают на переехавший `lib/render.ml`.
- **Доказательство:** `dune test tests/render_kernel.ml` → MathJax delimiter/CSS cases OK; commitment still names moved `lib/render.ml` at lines 9, 34 and 133.
- **Исправление формулировки:** Переписать: `lib/render.ml`→`lib/render/render.ml` и обновить line anchors.

### 6.16 `migration-mechanism-2026-10`

- **Что устарело:** Migration mechanism жив, но commitment/outcome используют старые OCAML_BEST_PRACTICES.md и AGENTS.md.
- **Доказательство:** `dune test tests/cli/migrate-dry-run.t tests/cli/migrate-malformed.t tests/cli/migrate-no-changes.t tests/cli/migrate-write.t` → PASS; commitment/outcome still name OCAML_BEST_PRACTICES.md and AGENTS.md at lines 81, 163, 174.
- **Исправление формулировки:** Переписать: OCAML_BEST_PRACTICES.md/AGENTS.md→текущие filenames/anchors.

### 6.17 `multi-policy-hierarchy-2026-10`

- **Что устарело:** Parent/cycle semantics живы, но commitment требует запись в переименованный OCAML_BEST_PRACTICES.md.
- **Доказательство:** `dune test tests/policy_test.ml` → PASS; commitment item 10 still says OCAML_BEST_PRACTICES.md at line 132.
- **Исправление формулировки:** Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md.

### 6.18 `new-decision-mkdir-parent-2026-10`

- **Что устарело:** Recursive mkdir и forward layout верны; init-legacy snapshot ожидает старую ревизию/число obligations и новую policy diagnostic.
- **Доказательство:** new-decision/init/defaults crams PASS; `tests/cli/init-legacy.t` fails on current revision/obligations/diagnostics, and decision names it at lines 212–213.
- **Исправление формулировки:** Переписать: init-legacy expectation под текущий scaffold; mkdir-инвариант оставить.

### 6.19 `obligations`

- **Что устарело:** Aggregator совпадает с parent, но developer-practices claim и parent revision pointer используют старый conventions filename/историческую revision.
- **Доказательство:** `bash tests/fixtures/aggregator-matches-parent.sh` → PASS; parent and aggregator each contain the same seven ids; developer-practices claim still names OCAML_BEST_PRACTICES.md at line 52.
- **Исправление формулировки:** Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md; parent revision pointer оставить явно историческим.

### 6.20 `priority-drift`

- **Что устарело:** Detector и mirror-check живы, но обещание и claim называют переименованный OCAML_BEST_PRACTICES.md.
- **Доказательство:** `dune test tests/repo_structure.ml` → `spec-vs-bp-priority` case OK; decision still names moved OCAML_BEST_PRACTICES.md at lines 10, 25, 60 and 154.
- **Исправление формулировки:** Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md.

### 6.21 `process-principles-close-branches`

- **Что устарело:** Hook/utility живут, но editorial-exemption commitment/claim цитируют переименованный AGENTS.md.
- **Доказательство:** Four close-branches/pre-commit fixtures → PASS; `mathc verify` → 3/3 pass; commitment/claim still cite AGENTS.md at lines 67 and 142.
- **Исправление формулировки:** Переписать: `AGENTS.md`→`KERNEL_AGENTS.md` в commitment/claim.

### 6.22 `process-principles`

- **Что устарело:** P1–P7 и machine checks живы, но текст и verifier claims называют bootstrap/ и AGENTS.md.
- **Доказательство:** `dune test tests/process_principles.ml` → 11/11 machine cases OK; text still names `bootstrap/` and `AGENTS.md` at lines 18, 25, 56.
- **Исправление формулировки:** Переписать: `bootstrap/`→`decisions/`, `AGENTS.md`→`KERNEL_AGENTS.md`.

### 6.23 `record-proportionality-2026-10`

- **Что устарело:** Citation resolution и floors живы; слово “blocked” устарело — текущий gate честно отвечает unknown, а не block.
- **Доказательство:** `dune test tests/cli/mode-floor-from-policies.t` → PASS; `tests/cli/gate-trailer-decision.t` expects block but current output is unknown.
- **Исправление формулировки:** Переписать: Block→Unknown для неразрешённой/dangling citation.

### 6.24 `render-ordered-lists-2026-10`

- **Что устарело:** Ordered-list behavior жив, но commitment/intent называют переехавшие `lib/render.ml` и AGENTS.md.
- **Доказательство:** `dune test tests/render_kernel.ml` → ordered-list positive/multidigit/continuation cases OK; commitment still names moved lib/render.ml and AGENTS.md at lines 49 and 113.
- **Исправление формулировки:** Переписать: `lib/render.ml`→`lib/render/render.ml`, `AGENTS.md`→`KERNEL_AGENTS.md`.

### 6.25 `site-broken-links-2026-10`

- **Что устарело:** Link behavior жив, но commitment/outcome называют переехавший `lib/render.ml`.
- **Доказательство:** `dune test tests/render_kernel.ml` → link/nav/footer cases OK; commitment still names moved lib/render.ml at lines 79, 85, 95 and 150.
- **Исправление формулировки:** Переписать: `lib/render.ml`→`lib/render/render.ml`.

### 6.26 `site-deploy`

- **Что устарело:** Deploy pipeline жив, но commitment/outcome называют переехавший `lib/render.ml`.
- **Доказательство:** `dune test tests/render_kernel.ml tests/cli/render.t` → PASS; `.github/workflows/site.yml` contains deploy-pages job; commitment still names moved lib/render.ml at line 38; live GitHub run not checked.
- **Исправление формулировки:** Переписать: `lib/render.ml`→`lib/render/render.ml`.

### 6.27 `site-diagrams-as-svg-2026-10`

- **Что устарело:** SVG-only behavior жив, но commitment/outcome называют переехавший `lib/render.ml`.
- **Доказательство:** `dune test tests/render_kernel.ml` → Mermaid-removed and inline-SVG cases OK; commitment/outcome still name moved lib/render.ml at lines 33, 68 and 88.
- **Исправление формулировки:** Переписать: `lib/render.ml`→`lib/render/render.ml`.

### 6.28 `site-quality-2026-10`

- **Что устарело:** Site behavior жив/ручной, но outcome называет переехавший `lib/render.ml`.
- **Доказательство:** Only `manual-render-*` claims exist; exact visual/live-count checks not executed (DECLARED); outcome still names moved lib/render.ml at lines 178 and 194.
- **Исправление формулировки:** Переписать: `lib/render.ml`→`lib/render/render.ml`; visual claims оставить DECLARED.

### 6.29 `site-quality-illustrations-2026-10`

- **Что устарело:** SVG assets живы, но promise называет переехавший `lib/render.ml`.
- **Доказательство:** `mathc verify` → 3/3 pass; SVG assets and references exist; promise still names moved lib/render.ml at line 32.
- **Исправление формулировки:** Переписать: `lib/render.ml`→`lib/render/render.ml`.

### 6.30 `time-honesty`

- **Что устарело:** Три шкалы и estimator живы; normative text переехал в KERNEL_AGENTS.md, а решение всё ещё требует AGENTS.md и 3.0-alpha.
- **Доказательство:** `dune test tests/conformance.ml` → PASS; rule is at `KERNEL_AGENTS.md:468`, while decision still names `AGENTS.md` at lines 20 and 116.
- **Исправление формулировки:** Переписать: `AGENTS.md`→`KERNEL_AGENTS.md`, 3.0-alpha→текущая версия.

### 6.31 `unanchored-attestations-are-declarations-2026-10`

- **Что устарело:** Историческая классификация 765 старых attestations сохранила смысл, но store больше не tracked и exact pin 765 неприменим.
- **Доказательство:** `dune test tests/attestation_anchor.ml` → PASS only for current 0-file corpus; decision’s exact pin 765 at lines 18 and 134 is obsolete.
- **Исправление формулировки:** Переписать/архивировать исторический pin 765; live store генерируется и имеет 0 tracked files.

### 6.32 `validate-and-context`

- **Что устарело:** Validate/context работают, но version outcome закрепляет 3.0-alpha вместо текущего VERSION 3.7.4.
- **Доказательство:** validate/context crams PASS; current version is 3.7.4, while decision requires `math-coding 3.0-alpha: bootstrap` at lines 72 and 220.
- **Исправление формулировки:** Переписать: version literal 3.0-alpha→`VERSION`/3.7.4.

### 6.33 `verifier-outcome-taxonomy-2026-10`

- **Что устарело:** Различение failed/skipped/manual живо, но debt counts и слово tracked-attestations относятся к старому store.
- **Доказательство:** `bash tests/fixtures/legacy-attestation-debt.sh` → exit 3 (no store); decision pins old 22/30/25 counts at lines 27–28.
- **Исправление формулировки:** Переписать: старые debt counts→текущие generated-store semantics.

### 6.34 `version-sync-2026-10`

- **Что устарело:** VERSION-sync жив, но commitment/outcome называют переименованный OCAML_BEST_PRACTICES.md.
- **Доказательство:** `mathc verify` → 4/4 pass; sync-version clean/drift fixtures PASS; commitment/outcome still name OCAML_BEST_PRACTICES.md at lines 84 and 134.
- **Исправление формулировки:** Переписать: OCAML_BEST_PRACTICES.md→OCAML_KERNEL_CONVENTIONS.md.

## 7. RECORD — кандидаты на архив

Критерий взят из T2.1: **упоминание не зависимость**. Зависимостью считается только машина, которая открывает файл или требует его live path. Path-pointer в текущем файле надо retarget; changelog/ROADMAP/comment — не зависимость.

### 7.1 `adopter-path-2026-10`

- **Почему это запись:** Superseded adoption-path experiment; outside `decisions/` есть только comment.
- **Проверка зависимости:** `state: superseded` (line 5); external `git grep` finds only a comment in `scripts/check-no-prose-policy-grep.sh:11`.
- **Действие:** Архивировать; machine dependency не найдена.

### 7.2 `attestation-store-fill`

- **Почему это запись:** Одноразовое заполнение store на HEAD b36572f; live policy теперь opposite — store generated.
- **Проверка зависимости:** File records 75 JSON files at old HEAD (lines 23–27); `git ls-files attestations/**` → 0.
- **Действие:** Архивировать; обновить path pointers в PACKAGES/source-map, файл не открывается кодом.

### 7.3 `audit-0.0.21-fixes`

- **Почему это запись:** Завершённый пятифазовный audit-fix cycle.
- **Проверка зависимости:** File describes completed five-phase cycle (lines 9–18); targeted parser/conformance/cram tests pass; external grep finds comments/prose, no machine opening this file.
- **Действие:** Архивировать; machine dependency не найдена.

### 7.4 `ceiling-monotonic-2026-10`

- **Почему это запись:** Superseded; revision 2 прямо говорит RETIRED.
- **Проверка зависимости:** `state: superseded` (line 5); obligations say `RETIRED at revision 2` at lines 198–238.
- **Действие:** Архивировать как superseded/retired record.

### 7.5 `cli-cram-tests`

- **Почему это запись:** Запись миграции 14 shell fixtures в cram.
- **Проверка зависимости:** External grep finds machine reads at `tests/corpus_no_silent_drops/corpus_no_silent_drops.ml:326` and `tests/yaml_seq_continuation.ml:399`.
- **Действие:** Сначала перенаправить два теста exact-path на archive, затем архивировать.

### 7.6 `corpus-tranche-archive-records-2026-11`

- **Почему это запись:** Запись выполненной archive-tranche и её accounting.
- **Проверка зависимости:** `mathc verify` → 13/13 pass; external grep finds no machine read of this file.
- **Действие:** Архивировать; machine dependency не найдена.

### 7.7 `corpus-tranche-broken-schemes-2026-11`

- **Почему это запись:** Запись выполненного repair пяти broken verifier schemes.
- **Проверка зависимости:** `bash tests/fixtures/verifier-schemes-are-canonical.sh` → PASS; external grep finds only diagnostic prose and fixture comments.
- **Действие:** Архивировать; fixture/diagnostic только ссылаются, файл не открывают.

### 7.8 `decision-level-census-2026-10`

- **Почему это запись:** Запись census-прохода по решениям и его policy.
- **Проверка зависимости:** External grep finds only a comment at `tests/corpus_no_silent_drops/corpus_no_silent_drops.ml:184`; no machine opens the file.
- **Действие:** Архивировать; machine dependency не найдена.

### 7.9 `gate-decision`

- **Почему это запись:** Запись введения первого gate scaffold; живой gate позже заменён.
- **Проверка зависимости:** `dune test tests/cli/gate-scaffold.t` → PASS; normative pointer remains at `spec/semantics.md:321`.
- **Действие:** Архивировать после A3-смены normative pointer в `spec/semantics.md:321`.

### 7.10 `kernel-bugs-v3.4-2026-10`

- **Почему это запись:** Запись batch-а из шести kernel bugs.
- **Проверка зависимости:** Five targeted cram files pass; external grep finds comments/IDs only, no machine opening this file.
- **Действие:** Архивировать; code/test references являются ID/comment, не чтением файла.

### 7.11 `kernel-fixes-found-bugs-2026-10`

- **Почему это запись:** Запись batch-а из шести resolver/adopt bugs.
- **Проверка зависимости:** Targeted adopt/init/import-adr tests pass; normative pointer at `spec/semantics.md:197` blocks an immediate move.
- **Действие:** Архивировать после A3-смены normative pointer в `spec/semantics.md:197`.

### 7.12 `mcp-agent-auto-connect-2026-10`

- **Почему это запись:** Живая документация уже реализованной MCP integration, не правило.
- **Проверка зависимости:** `mathc verify` → 3/3 pass; live dependency remains in `tests/cli/find.t:21,35–36` and `tests/mcp/find-readonly.t:28`.
- **Действие:** Перенаправить find-фикстуры на живое решение, затем архивировать.

### 7.13 `migrations/3.0-alpha-to-3.2`

- **Почему это запись:** Исторический manifest выполненной schema migration; механизм читает manifests.
- **Проверка зависимости:** Schema is `math-coding/migration-manifest`; it is consumed as an operational manifest, not a decision rule.
- **Действие:** Оставить: это operational migration manifest, не decision-rule.

### 7.14 `migrations/3.2-to-3.2.1`

- **Почему это запись:** Forward-looking пустой manifest — proof-of-mechanism, не promise.
- **Проверка зависимости:** Schema is `math-coding/migration-manifest`; empty forward manifest is operational input to `mathc migrate`.
- **Действие:** Оставить: это operational migration manifest, не decision-rule.

### 7.15 `paren-balance-fix-2026-10`

- **Почему это запись:** Одноразовый compile fix.
- **Проверка зависимости:** Targeted dune build succeeds; external grep finds only `lib/codec.ml:944` comment.
- **Действие:** Архивировать; machine dependency не найдена.

### 7.16 `render-kernel-fixes-2026-10`

- **Почему это запись:** Запись закрытия десяти render defects.
- **Проверка зависимости:** `dune test tests/render_kernel.ml` → 47/47 OK; external grep finds comments/test labels, no machine opening the decision.
- **Действие:** Архивировать; machine dependency не найдена.

### 7.17 `render-module-split-phase1a-2026-10`

- **Почему это запись:** Superseded запись одной фазы split; тесты привязаны к exact path.
- **Проверка зависимости:** `state: superseded`; machine reads at `tests/corpus_no_silent_drops/corpus_no_silent_drops.ml:365` and `tests/yaml_seq_continuation.ml:434`; golden comparison is manual and currently differs.
- **Действие:** Перенаправить два exact-path теста на archive, затем архивировать.

### 7.18 `render-module-split`

- **Почему это запись:** Запись первого mechanical split renderer-а; последующие фазы уже состоялись.
- **Проверка зависимости:** Current renderer has multiple modules; external grep finds only comments (`lib/render/render_lang.ml:3`), no machine opens the decision.
- **Действие:** Архивировать; machine dependency не найдена.

### 7.19 `site-redesign-2026-10`

- **Почему это запись:** Запись состоявшегося redesign-а landing page.
- **Проверка зависимости:** Only manual visual/browser claims exist; implementation comments cite the record at `lib/render/render_nav.ml:10` and `assets/style.css:112`.
- **Действие:** Архивировать; machine dependency не найдена.

### 7.20 `unmet-obligations-inventory-2026-10`

- **Почему это запись:** Запись инвентаризации sweep 2026-10-25 по 30 obligations.
- **Проверка зависимости:** `bash tests/fixtures/unmet-obligations-are-inventoried.sh` → PASS; fixture requires the live path at line 39.
- **Действие:** Перенаправить inventory fixture на archive, затем архивировать.

Итог по архиву: **12 готовы к архивированию**, **6 заблокированы явными live-machine dependencies/A3 pointers**, **2 migration manifests остаются на месте** как operational inputs.

## 8. Что осталось не проверенным и почему

**29 решений** имеют хотя бы одно утверждение, которое этот checkout не может честно закрыть. Это не fifth verdict: строки выше всё равно получили TRUE/FALSIFIED/STALE-FORM/RECORD по проверяемой части.

### 8.1 Ручные declarations (21 решение)

`attestation-producer-vocab-2026-10`, `ceiling-monotonic-2026-10`, `cli-canonical-name`, `d5-body-vs-wrapper-canonical-2026-10`, `d8-coarse-diagnostics-2026-10`, `decision`, `install-tooling-2026-10`, `kernel-bugs-v3.4-2026-10`, `mathc-packages-subcommand`, `portable-linux-musl`, `process-principles`, `render-module-split-phase1a-2026-10`, `site-deploy`, `site-quality-2026-10`, `site-quality-distribution-2026-10`, `site-redesign-2026-10`, `time-honesty-storage`, `verifier-outcome-taxonomy-2026-10`, `verifier-scheme-convention-2026-11`, `verify-path-forms-and-signed-attestations-2026-10`, `yaml-block-scalars`. Причина: verifier помечен `manual-*`; либо это визуальная/политическая проверка, либо требуется внешний release/CI артефакт.

### 8.2 Generated store / внешняя среда / отсутствующий инструмент (8 решений)

`attestation-store-fill`, `executed-evidence-census-2026-10`, `honest-attestation-emission-2026-10`, `legacy-attestation-debt-2026-10`, `paseo-console-mosaic-2026-10`, `paseo-console-plugin-2026-10`, `store-not-committed-2026-10`, `unanchored-attestations-are-declarations-2026-10`. Причина: в checkout нет generated `attestations/`; для console negative control нет `esbuild`; store-generation и внешние артефакты намеренно не запускались/не скачивались.

## 9. Пять самых важных находок

1. **Главный census-инструмент красный, хотя его измерения зелёные.** `redundancy-census.sh` видит PAPER=36 при ceiling=36, но synthetic control не превышает ceiling; значит обещание «bound умеет связывать» сейчас ложно.
2. **Пять живых decision-файлов kernel читает не до EOF.** `scan-silent-drops.sh --validity` перечисляет 3-2-cli-catalog, ci-blocking-list-config, d5-body-vs-wrapper-canonical, forge-stub-read-request и mathc-packages-subcommand; `mathc validate` даёт MC-UNPARSED-TAIL на каждом.
3. **Инвентарь silent drops сам опровергнут текущим деревом.** Решение ждёт exact set 12 и `kernel_holes=0`; сейчас kernel holes — 5.
4. **Normative CLI catalog неполон.** Spec перечисляет 18 команд, dispatcher — 39; отсутствуют 21, включая verify, update, init, migrate, doctor, rehash.
5. **В corpus одновременно живут несовместимые exit/waiver/final-state обещания.** `gate-attestation-store-fill` говорит unknown→0, код говорит unknown→3; `forge-principal-verification` говорит unavailable forge→pass/exit 0, текущий fixture требует unknown/exit 3; `waiver-infrastructure` говорит open-with-waiver→pass, код сохраняет отдельный verdict; `corpus-final-state` требует self-check exit 0, текущий checkout даёт unknown/exit 3.

## 10. Что не сделано и почему

- Не запускался `dune build @runtest`, полный `scripts/check.sh` и `mathc gate` на всём дереве: это прямо запрещено/избыточно для inventory и упирается в ресурсы.
- Не скачивались GitHub release assets, Docker/OCI image и Nix derivation: их наличие во внешнем мире нельзя доказать локальным чтением.
- Не создавался generated attestation store: он изменил бы измеряемое состояние и смешал подготовку evidence с read-only inventory.
- `decisions/`, `lib/`, `tests/`, `spec/` и fixtures не менялись. Единственный новый файл — этот отчёт.

## 9.1 — что стало с девятью опровергнутыми (приписка 2026-11-01)

> **ПРИПИСКА, 2026-11-01.** Разделы 1–10 выше остаются как были: это снимок одного прохода по одному корпусу на одном коммите, и его исходные строки не переписываются. Ниже — что стало с девятью решениями из раздела 5. Решение транши: `decisions/falsified-promises-repaired-2026-11.yaml`. Каждое из восьми переписанных решений подняло ревизию и получило `negative_control:` — контроль, который ловит его собственный провал.

- **`corpus-final-state-2026-10` — ПЕРЕПИСАНО (revision 2).** Обещание «около пятидесяти правил и зелёные ворота» опровергнуто: `mathc self-check` → exit 3, вердикт `unknown`, 133 субъекта, все `unknown`; census меряет 140 решений и 36 обязательств, которые не исполняет ни одна программа. Теперь решение говорит правду о текущем дереве: форма корпуса — это число с потолками, которые могут только падать; долг обещаний — три числа (CHECKED / DECLARED / UNCHECKED); ворота никогда не заверяют то, что не проверили, а CI-шаг остаётся аудитом. Контроль: `tests/cli/self-check-unknown.t`.
- **`corpus-silent-drop-inventory-2026-10` — ПЕРЕПИСАНО (revision 2).** Ledger 12/216 не подтверждается: `bash scripts/scan-silent-drops.sh --validity` → «5 of 139», четыре INVALID (долг автора) и один MULTI-DOC (строгий маркер без хвоста); `--all` → 7 из 313. Правило не тронуто — точный набор в обе стороны и нулевая терпимость к kernel holes; числа теперь те, которые меряет прибор сегодня.
- **`forge-principal-verification` — ПЕРЕПИСАНО (revision 2).** «Недоступный forge при fail-mode=open даёт pass и exit 0» опровергнуто: `tests/cli/forge-verify.t` требует `verdict=unknown` и `[3]`, и сам фикстур пишет почему — «это утверждало членство, которое никто не проверял». Теперь fail-open значит «не блокирует», а не «проверка прошла».
- **`gate-attestation-store-fill` — ПЕРЕПИСАНО (revision 3).** «unknown → exit 0» опровергнуто: `bin/Mathc.ml::verdict_to_exit` отдаёт `Unknown → 3`, и это же требует `tests/cli/gate-unknown-exit-3.t`. Гейт по-прежнему читает store, свежесть проверяется по materials digest, устаревшая аттестация остаётся `StaleEvidence`.
- **`mathc-self-check-subcommand` — ПЕРЕПИСАНО (revision 5).** «Ядро возвращает pass против этого репозитория» опровергнуто: store генерируется на каждый прогон, поэтому 133 из 133 субъектов `unknown` и exit 3. Теперь обещание — диспетчер поставлен, и вердикт всегда сходится с кодом выхода (`pass`→0, `fail`→1, `unknown`→3); консьорманс-корпус, инварианты аксиом и схемы при этом проходят.
- **`missing-directory-is-not-a-crash-2026-10` — ПЕРЕПИСАНО (revision 2).** «`dune test` зелёный без сгенерированного store» опровергнуто: `tests/fixture_coverage.ml` красный (долг по отвергающим кейсам — 54 против потолка 52), `tests/cli/gate-trailer-decision.t` красный (ждёт `block`, получает `unknown`). Ни то ни другое не является падением на отсутствующем каталоге. Само правило («отсутствующий артефакт — пустой результат, а не исключение») осталось и теперь меряется прибором, написанным под него: `tests/fixtures/missing-directory-is-an-empty-result.sh`, с отрицательным контролем, который доказывает, что детектор падения ловится.
- **`redundancy-census-2026-11` — ОПРОВЕРЖЕНИЕ ОТМЕНЕНО.** Обещание «потолки умеют связывать» сегодня правда: `bash tests/fixtures/redundancy-census.sh` → PASS, а его отрицательный контроль меряет СИНТЕТИЧЕСКИЙ корпус — «a synthetic corpus measures 41 paper obligations, above the ceiling 36». Инвентарь ошибся в причине: тогда контроль мерил живой корпус под унаследованным `MATH_CODING_ROOT`; прибор с тех пор починен, и обещание оказалось правдой. Файл решения не тронут, ревизия осталась 1 — в этом и состоит отмена опровержения.
- **`spec-cli-catalog` — ПЕРЕПИСАНО (revision 3).** «Нормативная секция перечисляет каждую команду dispatcher-а» было ложно с самого дня написания: в `spec/semantics.md` 18 строк, dispatcher отвечает на 39 имён, 21 команда реализована и не документирована. Теперь разрыв ИЗМЕРЯЕТСЯ и ограничен потолком 21: `tests/fixtures/spec-cli-catalog-gap.sh` читает и руки dispatcher-а, и строки каталога, печатает недокументированные команды поимённо и краснеет, если разрыв вырос.
- **`waiver-infrastructure-2026-10` — ПЕРЕПИСАНО (revision 3).** «Open_with_waiver печатается как pass» опровергнуто: `bin/Mathc.ml::verdict_to_pass_fail_unknown` отдаёт отдельный вердикт, и агрегат тоже (`decisions/self-check-waiver-verdict-coherence-2026-10.yaml`, 2026-10-25). Причины и лечи остаются в выводе, код выхода — 0, а waiver называет ровно одну дыру.

**Что это изменило в числах прибора.** Долг обещаний упал на пять решений: CHECKED 78 → 84, UNCHECKED 37 → 32, DECLARED без изменения (21) — ни одно новое обещание не оказалось непроверяемым, поэтому ни одно не объявлено. «До» здесь — числа **прибора** на момент начала транши, а не раздел 3 этого отчёта: прибор классифицирует по полю `negative_control:`, а инвентарь — по существу фикстуры, и расхождение между ними разобрано отдельно в `decisions/declared-promises-and-three-numbers-2026-11.yaml`. Корпус вырос на одно решение (это решение транши): 140 → 141, потолок поднят с маркером.
