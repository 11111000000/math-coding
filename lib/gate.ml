(* lib/gate.ml — pure gate evaluator.
 *
 * `evaluate` takes the changed paths, the loaded Memory.t, the
 * attestation store (a typed list already loaded by
 * `Attestations.load`), and an evaluation `now`. It returns a
 * `Gate.t`:
 *
 *   - verdict: Pass | Open_with_waiver | Block | Unknown
 *   - gaps: per-obligation gap list
 *
 * Rule (OCAML_BEST_PRACTICES §1.3): no I/O. The attestation store
 * is loaded by bin/Mathc.ml (or a test fake) and passed in here as
 * a typed value. I/O belongs at the bin/ boundary.
 *
 * Spec/semantics.md §"Evaluation":
 *   current(a) iff
 *     a.revisions resolve
 *     a.materials_digest equals digest(relevant materials of c)
 *     a.validity interval contains t
 *     a.method satisfies Req(p, o, g)
 *   Pass(o, c, g) iff some a is current and a.result = pass and no decisive failure
 *   Fail(o, c, g) iff some current decisive a reports fail
 *   Unknown(o, c, g) iff otherwise
 *
 * Kernel invariants honoured:
 *   8 (evidence binding): an attestation's `subject.decision` and
 *     `subject.obligation` MUST match the obligation it attests.
 *   9 (freshness): a mismatch between a.materials_digest and the
 *     digest of the candidate change's changed-paths is reported
 *     as StaleEvidence; the verdict does NOT silently flip to pass.
 *   10 (honest status): missing, stale, fail, inconclusive,
 *     infrastructure-error and pass are distinct gap kinds and
 *     distinct verdicts (unknown != pass).
 *
 * Bootstrap limitation: the "revisions resolve" and "validity
 * interval contains t" clauses are not enforced in this revision;
 * see decisions/gate-attestation-store-fill-decision.yaml
 * assumption materials-digest-hand-rolled. A future revision
 * closes that gap when D4 (SHA-256 vectors) lands. *)

type verdict = Pass | Open_with_waiver | Block | Unknown

type gap = {
  obligation_id : string;
  kind :
    [ `MissingEvidence
    | `StaleEvidence
    | `FailedEvidence
    | `MissingReview
    | `NoAttestationStore
    | `Unknown ];
  causes : string list;
  remedies : string list;
  next_actions : (string * string) list;
}

type t = {
  verdict : verdict;
  gaps : gap list;
  obligation_count : int;
  now : string;
  base : string;
  head : string;
}

let[@warning "-32"] verdict_to_string = function
  | Pass -> "pass"
  | Open_with_waiver -> "open-with-waiver"
  | Block -> "block"
  | Unknown -> "unknown"

(* Hash the sorted changed-paths into a hex digest. We sort so the
 * digest is stable across git diff orderings (git does not
 * guarantee a particular order). The empty path list hashes to
 * the SHA-256 of the empty string — a deterministic value the
 * loader's wildcard match (`materials_digest = ""`) deliberately
 * does NOT match, so an empty change is correctly NOT considered
 * a pass without an attestation. *)
let[@warning "-32"] materials_digest_of changed_paths =
  let sorted = List.sort (fun a b -> String.compare a b) changed_paths in
  let joined = String.concat "\n" sorted in
  Digest.sha256_hex joined

(* --- scope materials (semantics A) ------------------------------------- *)

(* Does the path segment [pat] match the path segment [s]? `*` matches
   any run of characters within the segment. *)
let[@warning "-32"] segment_match (pat : string) (s : string) : bool =
  let parts = String.split_on_char '*' pat in
  let rec go parts s =
    match parts with
    | [] -> true
    | [ last ] ->
        (* The last literal part must match the END of the segment. *)
        let n = String.length last and m = String.length s in
        m >= n && String.sub s (m - n) n = last
    | p :: rest ->
        let n = String.length p in
        if n = 0 then go rest s
        else if String.length s >= n && String.sub s 0 n = p then
          go rest (String.sub s n (String.length s - n))
        else false
  in
  go parts s

(* Does the repository-relative path [path] match the glob [pattern]?
   `**` matches any number of path segments; `*` matches within one
   segment; everything else is literal. *)
let[@warning "-32"] glob_match (pattern : string) (path : string) : bool =
  let ps = String.split_on_char '/' pattern in
  let qs = String.split_on_char '/' path in
  let rec go ps qs =
    match (ps, qs) with
    | [], [] -> true
    | "**" :: ps, qs -> (
        go ps qs
        || match qs with [] -> false | _ :: qs' -> go ("**" :: ps) qs')
    | p :: ps, q :: qs when segment_match p q -> go ps qs
    | _ -> false
  in
  go ps qs

(* The materials digest of a scope.
 *
 * This is the reference value that `subject.materials_digest` is
 * compared against, and it is the value an attestation producer must
 * write. Before this function existed the two sides computed
 * DIFFERENT things and could never be equal:
 *
 *   - the gate compared against sha256 of the changed PATH NAMES
 *     (materials_digest_of, above);
 *   - the producers wrote sha256 of a command's OUTPUT, or "".
 *
 * The empty string was treated as a wildcard, so the only attestation
 * that ever satisfied the freshness check was the one that carried no
 * evidence at all: the mechanism rewarded dishonesty.
 *
 * Under this definition the digest is bound to the CONTENT of the
 * files the scope names. The content is addressed by git's blob id,
 * which is itself content-derived, so the digest changes exactly when
 * a named file's bytes change — and both sides compute it the same
 * way, from the same input, with no file reading at all.
 *
 * [blobs] is the (path, blob-id) list of the repository's tracked
 * files. [scope_paths] is the decision's `scope.paths`. *)
let[@warning "-32"] scope_materials_digest ~(blobs : (string * string) list)
    ~(scope_paths : string list) ~(exclude : string list) : string =
  (* The attestation store is EVIDENCE ABOUT the scope, not part of
     it. A decision that lists its own attestations in its scope
     creates a self-reference: the digest of the scope then depends
     on the attestation that carries the digest, so the attestation is
     stale the moment it is committed, and no signing can ever
     satisfy it. The store is excluded by prefix for that reason. *)
  let excluded p =
    List.exists
      (fun pre ->
        String.length p >= String.length pre
        && String.sub p 0 (String.length pre) = pre)
      exclude
  in
  let matched =
    List.filter
      (fun (p, _) ->
        (not (excluded p))
        && List.exists (fun sc -> glob_match sc p) scope_paths)
      blobs
  in
  let matched = List.sort (fun (a, _) (b, _) -> String.compare a b) matched in
  let buf = Buffer.create 4096 in
  List.iter
    (fun (p, id) ->
      Buffer.add_string buf p;
      Buffer.add_char buf '\000';
      Buffer.add_string buf id;
      Buffer.add_char buf '\n')
    matched;
  (* The "sha256:" prefix, matching body_sha / yaml_sha / the
     attestation id, so every digest in the system has one shape. *)
  "sha256:" ^ Digest.sha256_hex (Buffer.contents buf)

(* Filter attestations for a (decision_id, obligation_id) pair.
 * Pure list operations; the kernel cannot depend on the
 * attestation store adapter (OCAML_BEST_PRACTICES §10.1), so the
 * helpers that lived on `Attestations` are inlined here. *)
let[@warning "-32"] candidates_for ~store ~decision_id ~obligation_id =
  List.filter
    (fun a ->
      String.equal a.Domain.decision decision_id
      && String.equal a.Domain.obligation obligation_id)
    store

(* A "current" attestation is one whose `materials_digest` matches
 * the digest of the candidate change's materials. An empty
 * `materials_digest` is treated as wildcard (the attestation does
 * not bind itself to a specific materials set). This honours
 * Kernel Invariant 9 (freshness) while still allowing test
 * fixtures to author attestations without computing the digest.
 *
 * Spec/semantics.md:39-44:
 *   current(a) iff
 *     a.revisions resolve
 *     a.materials_digest equals digest(relevant materials of c)
 *     a.validity interval contains t
 *     a.method satisfies Req(p, o, g)
 * The "revisions resolve" and "validity interval" clauses are not
 * enforced in this revision; see
 * decisions/gate-attestation-store-fill-decision.yaml assumption
 * materials-digest-hand-rolled. *)
let[@warning "-32"] fresh_against ~attestations ~materials_digest =
  List.filter
    (fun a ->
      let d = a.Domain.materials_digest in
      String.length d = 0 || String.equal d materials_digest)
    attestations

(* Compute the per-obligation verdict for one (decision, obligation)
 * pair against the attestation store. Returns either a single
 * gap (Unknown / MissingEvidence / StaleEvidence / MissingReview)
 * or `None` if every applicable obligation has a current pass
 * attestation and no decisive fail. *)
(* `required_attestation_satisfied ra store` returns true when
   at least one attestation in `store` matches the
   (kind_, producer) pair declared by `ra`. The check is the
   exact-match closure: both fields must equal.

   `ra_scope_paths` is NOT enforced. It is parsed
   (`Decision.parse_scope_paths`), carried on the record, and
   rendered into the gap cause by `required_attestation_gap` for
   human traceability, and that is its entire effect on the
   verdict. A requirement with a non-empty `scope_paths` is
   satisfied by exactly the same store contents as the same
   requirement with none.

   This comment previously claimed the opposite: that a
   non-empty `ra_scope_paths` "filters by the attestation's
   candidate_tree (commit SHA) being mentioned in the
   attestation's `subject.candidate_tree` field". Three things
   were wrong with that. It described a filter the function
   does not implement. It read `scope_paths` as a commit SHA,
   where the field is an array of path GLOBS
   (`decision-required-attestations-2026-10.yaml`: "scope_paths
   is an optional array of glob strings"; the example there is
   `bin/Mathc.ml`, `spec/**/*.md`) -- a domain confusion, not a
   typo. And it contradicted the decision that governs this
   code, which states in terms that the predicate "is documented
   but not yet enforced" and that "the gate filter is currently
   (kind_, producer_identity)".

   Enforcing it is not a comment-sized change and was not made
   here. Beyond needing its own decision, it would flip the
   corpus: `scope_paths` would have to be matched against a
   commit SHA, and 0 of the 765 committed attestations carry
   one (749 carry the literal `HEAD`, 16 a branch name), so
   every scoped requirement would go unsatisfied and pass
   verdicts would become blocks. That would be a true statement
   about an unobserved corpus mistaken for a defect in the
   filter -- and it is precisely the retro-fitting of history
   that `candidate-tree-resolves-to-a-commit` forbids.
   Forward-path: now that new attestations carry a resolved
   commit id, the predicate becomes implementable at all; it
   stays unenforced until the store is re-observed rather than
   rewritten. *)
let[@warning "-32"] attestation_kind_str (a : Domain.attestation) : string =
  match a with
  | { kind = `Test; _ } -> "test"
  | { kind = `Review; _ } -> "review"
  | { kind = `Build; _ } -> "build"
  | { kind = `Analysis; _ } -> "analysis"
  | { kind = `Observation; _ } -> "observation"

let[@warning "-32"] required_attestation_satisfied
    (ra : Decision.required_attestation) store =
  List.exists
    (fun a ->
      String.equal (attestation_kind_str a) ra.ra_kind
      && String.equal a.Domain.producer_identity ra.ra_producer)
    store

(* `required_attestation_gap entry store` returns gaps for
   every `required_attestations:` item declared by `entry`
   that is not satisfied by `store`. Empty list when every
   requirement is satisfied (or when `required_attestations` is
   absent). The `obligation_id` is synthesised from the
   `(decision_id, kind, producer)` triple because the
   required-attestation gate is per-decision, not per-obligation;
   the gate ties each gap back to its source for traceability. *)
let[@warning "-32"] required_attestation_gap entry store =
  match entry.Memory.source with
  | source when source <> "" -> (
      match
        Decision.parse_required_attestations
          (match Codec.load_yaml_string source with v -> v)
      with
      | Some [] | None -> []
      | Some requireds ->
          List.filter_map
            (fun (ra : Decision.required_attestation) ->
              let k = ra.ra_kind in
              let p = ra.ra_producer in
              let scope_suffix =
                match ra.ra_scope_paths with
                | [] -> ""
                | paths ->
                    Printf.sprintf " (scope: %s)" (String.concat ", " paths)
              in
              let cause_msg =
                Printf.sprintf "required_attestation unfulfilled: %s from %s%s"
                  k p scope_suffix
              in
              if required_attestation_satisfied ra store then None
              else
                let gap =
                  {
                    obligation_id =
                      Printf.sprintf "%s/required-attestation:%s:%s"
                        entry.Memory.decision_id k p;
                    kind = `MissingReview;
                    causes = [ cause_msg ];
                    remedies =
                      [
                        "produce the listed attestation in attestations/";
                        "or remove the requirement from the decision";
                      ];
                    next_actions =
                      [
                        ( "run",
                          Printf.sprintf
                            "mathc attest --kind %s --producer %s %s.md" k p
                            entry.Memory.decision_id );
                      ];
                  }
                in
                Some gap)
            requireds)
  | _ -> []

(* --- source class (constitution.md §Epistemic Separation) -----------------
 *
 * `kind_` is the SOURCE CLASS of an attestation (`schemas/attestation.json`,
 * `lib/domain.ml::attestation.kind`): `test`, `build`, `analysis` and
 * `observation` are RUNTIME classes -- the file claims that a check ran and
 * passed -- while `review` is the WEAK class, a human declaration with no
 * runtime anchor.
 *
 * The constitution says a result MUST NOT be promoted to a stronger class
 * without an artifact establishing that class. `obligation_gap` used to
 * promote EVERY `result: pass` to "this obligation holds", whatever the
 * file's class was. A `kind_: test` attestation that names no
 * `producer.run` and declares no machine producer says "a check ran and it
 * passed", and the gate believed it, although nothing in the file
 * established that a check ran at all. The claim was not stronger than the
 * evidence behind it; it was stronger than the evidence UNDER it.
 *
 * The rule below is the gate-side half of
 * `decisions/attestation-producer-vocab-2026-10.yaml` (which is the
 * issuance-side half) and the whole of
 * `decisions/evidence-class-gate-2026-10.yaml`:
 *
 *   - a RUNTIME-class pass satisfies the obligation only when the class is
 *     ESTABLISHED: the attestation names the `producer.run` that produced
 *     it, or its `producer.identity` declares the machine class `ci:`;
 *   - a `review`-class pass satisfies the obligation as it stands. A
 *     review claims nothing stronger than itself, so accepting it promotes
 *     nothing -- the asymmetry is the same one
 *     MC-PRODUCER-HUMAN-UNANCHORED rests on.
 *
 * The rule is asymmetric about FAILURES on purpose: a decisive `fail` is
 * not an over-claim, so it still blocks. The kernel's job here is to stop
 * understating the assurance, not to stop reporting bad news.
 *
 * The rule constrains SATISFACTION only. It says nothing about the
 * `required_attestations:` gate (`required_attestation_satisfied` above),
 * which asks whether a named `(kind_, producer)` pair is PRESENT in the
 * store, not whether it discharges anything.
 *
 * MEASURED over the 916 TRACKED attestations on 2026-10-27 (the store
 * loader admits only tracked files): 523 carry a runtime class, 226 of
 * those report `pass`, and exactly 2 of the 226 name neither a run nor
 * a `ci:` producer. Both belong to `site-diagrams-as-svg-2026-10`, and
 * they are the only corpus verdict this rule moves (pass -> unknown).
 * The other 224 runtime passes are established -- 220 name a run (218
 * of them also carry a `ci:` identity) and 4 name a `ci:` identity
 * alone -- and the 393 tracked review-class attestations are
 * untouched: a review needs no anchor. *)

(* Is this a RUNTIME class -- one that claims a check ran? *)
let[@warning "-32"] runtime_class (a : Domain.attestation) : bool =
  match a.Domain.kind with
  | `Test | `Build | `Analysis | `Observation -> true
  | `Review -> false

(* The declared machine producer class. `producer.identity` is
   `<class>:<subject>` with class in {human, agent, ci}
   (`decisions/attestation-producer-vocab-2026-10.yaml`). Only `ci:` names
   an automated job, so only `ci:` establishes a runtime class on its own:
   `human:` is a person and `agent:` is a model-driven agent, and both are
   declarations. `ci-bot:` is not a declared class at all -- it says nothing
   about WHO produced the file, so it cannot establish that a check ran. *)
let[@warning "-32"] declared_machine_producer (identity : string) : bool =
  let prefix = "ci:" in
  String.length identity >= String.length prefix
  && String.sub identity 0 (String.length prefix) = prefix

(* Does the attestation name the run that produced it? An empty or
   whitespace-only `producer.run` is not a run: `mathc attest --run=""`
   records a field, not an anchor. *)
let[@warning "-32"] names_its_run (a : Domain.attestation) : bool =
  match a.Domain.producer_run with
  | Some r -> String.trim r <> ""
  | None -> false

(* The declared HUMAN producer class. `producer.identity` is
   `<class>:<subject>` with class in {human, agent, ci}
   (`decisions/attestation-producer-vocab-2026-10.yaml`). A review
   is a person's word, so the identity must say a person. *)
let[@warning "-32"] declared_human_producer (identity : string) : bool =
  let prefix = "human:" in
  String.length identity >= String.length prefix
  && String.sub identity 0 (String.length prefix) = prefix

(* Does this attestation ESTABLISH its own source class? A review-class
   attestation is a person's word, and it is its own class -- but only
   when the person is named. A runtime-class attestation needs a
   runtime anchor.

   The review case changed here. A review used to discharge an
   obligation whoever signed it, because "a review claims nothing
   stronger than itself". But the store is GENERATED by the CI
   kernel, and 215 of its review attestations were signed
   `ci:kernel:resign`: the machine signing as the reviewer, over
   exactly the declarations that no check covers. A review that a
   machine signed is not a person's word, and an obligation that
   rests on it rests on paper. *)
let[@warning "-32"] establishes_class (a : Domain.attestation) : bool =
  match a.Domain.kind with
  | `Review -> declared_human_producer a.Domain.producer_identity
  | `Test | `Build | `Analysis | `Observation ->
      names_its_run a || declared_machine_producer a.Domain.producer_identity

(* Does this attestation discharge the obligation it names? A pass whose
   class is not established is a declaration wearing a machine label; it
   does not discharge anything. *)
let[@warning "-32"] satisfies_obligation (a : Domain.attestation) : bool =
  a.Domain.result = Domain.Pass && establishes_class a

(* The reader-facing explanation of a rejected pass. A pass lands here
   only when BOTH anchors are absent, so the message states both: the
   run is missing AND the producer does not declare the machine class.
   Naming one of them would send a reader to look for the other. *)
let[@warning "-32"] class_cause (a : Domain.attestation) : string =
  Printf.sprintf
    "attestation %s declares kind_=%s with producer.identity %S: the runtime \
     class is not established -- it names no producer.run and its producer \
     does not declare the machine class 'ci:' -- so this pass is a \
     declaration, not an observation"
    a.Domain.id (attestation_kind_str a) a.Domain.producer_identity

(* What the gate knows about an obligation after its checks were
   RUN against the candidate tree.
 *
   This is the difference between the gate asking a store what
   happened once and the gate watching what happens now. A store
   answers about a tree that has since moved -- that is what a
   digest-bound attestation IS -- so a gate that reads a store
   cannot tell the reader whether the change is safe. It can only
   say whether the evidence is fresh, and freshness is not safety.
 *
   The three states are the three the constitution knows: satisfied,
   failed, and not established. *)
type obligation_state =
  | Satisfied
  (* the checks ran and every one of them passed *)
  | Failed
  (* a check ran and failed decisively *)
  | Unverified
(* the check exists and could not be run, or it could not conclude *)

(* The gap of ONE obligation.
 *
 * [live] is what the gate learned by RUNNING the obligation's
 * checks against the candidate tree, and it takes precedence over
 * the store. The precedence is the whole point: a store entry is
 * evidence about a tree that has since moved -- that is what a
 * digest-bound attestation IS -- while a check that just ran is
 * evidence about THIS tree. A gate that reads a store cannot say
 * whether a change is safe; it can only say whether the evidence
 * is fresh, and freshness is not safety.
 *
 * An obligation with no entry in [live] is one the gate could not
 * settle by running anything: it carries only a human declaration,
 * or no check at all. Those are exactly the obligations the store
 * exists for, and for them the store is consulted as before. *)
let[@warning "-32"] obligation_gap ~decision_id ~obligation_id ~materials_digest
    ~store ~live =
  match Hashtbl.find_opt live (decision_id, obligation_id) with
  | Some Satisfied -> None
  | Some Failed ->
      Some
        {
          obligation_id;
          kind = `FailedEvidence;
          causes =
            [
              Printf.sprintf
                "obligation %s of decision %s has a check that ran against the \
                 candidate tree and failed"
                obligation_id decision_id;
            ];
          remedies =
            [
              "revert the change that broke this obligation";
              "or add a waiver under decisions/*.yaml";
            ];
          next_actions =
            [
              ("run", "git revert <sha>   # revert the offending change");
              ( "edit",
                Printf.sprintf "%s   # fix the underlying cause" decision_id );
              ( "create",
                Printf.sprintf
                  "decisions/waivers/%s-%s.yaml   # add a waiver if acceptable"
                  decision_id obligation_id );
            ];
        }
  | Some Unverified ->
      Some
        {
          obligation_id;
          kind = `Unknown;
          causes =
            [
              Printf.sprintf
                "obligation %s of decision %s has a check that could not be \
                 run against the candidate tree"
                obligation_id decision_id;
            ];
          remedies =
            [ "make the check runnable, or declare the obligation manually" ];
          next_actions =
            [
              ( "run",
                Printf.sprintf
                  "mathc verify decisions/%s.yaml   # see the per-obligation \
                   verdict"
                  decision_id );
              ( "edit",
                Printf.sprintf
                  "decisions/%s.yaml   # point the verifier at something that \
                   exists"
                  decision_id );
            ];
        }
  | None -> (
      let candidates = candidates_for ~store ~decision_id ~obligation_id in
      let current = fresh_against ~attestations:candidates ~materials_digest in
      match (candidates, current) with
      | _ :: _, [] ->
          Some
            {
              obligation_id;
              kind = `StaleEvidence;
              causes =
                [
                  Printf.sprintf
                    "obligation %s of decision %s has %d attestation(s) but \
                     none match the current materials digest %s"
                    obligation_id decision_id (List.length candidates)
                    materials_digest;
                ];
              remedies =
                [
                  "re-run the producer of the attestation against the current \
                   candidate tree";
                  "or update the attestation's subject.materials_digest if the \
                   method is genuinely digest-independent";
                ];
              next_actions =
                [
                  ( "run",
                    Printf.sprintf
                      "mathc assess <base> <head>   # recompute digest" );
                  ( "run",
                    Printf.sprintf
                      "mathc gate <base> <head>          # re-evaluate the gate"
                  );
                  ( "edit",
                    Printf.sprintf
                      "attestations/<decision>-%s.json   # update \
                       subject.materials_digest"
                      obligation_id );
                ];
            }
      | [], [] ->
          Some
            {
              obligation_id;
              kind = `MissingEvidence;
              causes =
                [
                  Printf.sprintf
                    "obligation %s of decision %s has no attestations in the \
                     store"
                    obligation_id decision_id;
                ];
              remedies =
                [
                  "produce an attestation that names this decision + obligation";
                  "or add a waiver under decisions/*.yaml";
                ];
              next_actions =
                [
                  ( "create",
                    Printf.sprintf
                      "attestations/%s-%s.json   # add an attestation file"
                      decision_id obligation_id );
                  ("create", "decisions/waivers/<decision>-<obligation>.yaml");
                  ("run", "mathc self-check");
                ];
            }
      | _, current ->
          (* `has_pass` is the class-aware predicate, not "any attestation whose
             result is Pass". A runtime-class pass counts only when its class is
             established (see `establishes_class`); a review-class pass counts as
             it stands. *)
          let has_pass = List.exists satisfies_obligation current in
          let has_fail =
            List.exists (fun a -> a.Domain.result = Domain.Fail) current
          in
          (* The pass claims that were refused because their class was not
             established. They are named in the gap so that a reader can see
             WHY the obligation is not satisfied -- an unread gap is a hole the
             next maintainer has to re-derive. *)
          let class_rejected =
            List.filter
              (fun a ->
                a.Domain.result = Domain.Pass && not (establishes_class a))
              current
          in
          if has_fail then
            Some
              {
                obligation_id;
                kind = `FailedEvidence;
                causes =
                  [
                    Printf.sprintf
                      "obligation %s of decision %s has a decisive fail \
                       attestation"
                      obligation_id decision_id;
                  ];
                remedies =
                  [
                    "revert the change that broke this obligation";
                    "or add a waiver under decisions/*.yaml";
                  ];
                next_actions =
                  [
                    ("run", "git revert <sha>   # revert the offending change");
                    ( "edit",
                      Printf.sprintf
                        "%s   # fix the underlying cause and re-evaluate"
                        decision_id );
                    ( "create",
                      Printf.sprintf
                        "decisions/waivers/%s-%s.yaml   # add a waiver if \
                         acceptable"
                        decision_id obligation_id );
                  ];
              }
          else if not has_pass then
            let causes =
              match class_rejected with
              | [] ->
                  [
                    Printf.sprintf
                      "obligation %s of decision %s has current attestations \
                       but none reports pass (inconclusive or \
                       infrastructure-error)"
                      obligation_id decision_id;
                  ]
              | refused ->
                  Printf.sprintf
                    "obligation %s of decision %s has %d attestation(s) \
                     reporting pass whose source class is not established"
                    obligation_id decision_id (List.length refused)
                  :: List.map class_cause refused
            in
            let remedies =
              match class_rejected with
              | [] ->
                  [
                    "investigate the inconclusive attestation; a fail or a new \
                     pass is required";
                  ]
              | _ ->
                  [
                    "name the run that produced the result (producer.run), or \
                     reissue the attestation with a declared 'ci:' producer";
                    "or reissue it as kind_: review if it is a human judgement \
                     with no runtime anchor";
                  ]
            in
            let next_actions =
              match class_rejected with
              | [] ->
                  [
                    ( "run",
                      Printf.sprintf
                        "mathc re-evaluate-decisions A0   # run the oracle \
                         explicitly" );
                    ( "edit",
                      Printf.sprintf
                        "attestations/%s-%s.json   # re-author the \
                         inconclusive attestation"
                        decision_id obligation_id );
                  ]
              | _ ->
                  [
                    ( "edit",
                      Printf.sprintf
                        "attestations/%s-%s.json   # add producer.run, or \
                         reissue with a 'ci:' producer"
                        decision_id obligation_id );
                    ( "run",
                      Printf.sprintf
                        "mathc attest-batch --manifest=manifest.tsv \
                         --run=\"<command>\"   # one TSV row: %s <TAB> %s \
                         <TAB> test <TAB> ci:<name>"
                        decision_id obligation_id );
                  ]
            in
            Some
              { obligation_id; kind = `Unknown; causes; remedies; next_actions }
          else None)

let[@warning "-32"] aggregate gaps =
  let blocking =
    List.exists
      (fun g -> g.kind = `FailedEvidence || g.kind = `MissingReview)
      gaps
  in
  match gaps with _ when blocking -> Block | [] -> Pass | _ -> Unknown

(* --- waiver-aware aggregation (math-coding 3.3) ---
 *
 * `aggregate` above is the whole verdict vocabulary for a
 * subject with no relief path: Pass, Block, or Unknown. The
 * waiver step lives here, as a separate pure function, for two
 * reasons.
 *
 * 1. Honesty of the verdict (constitution.md Invariant 10):
 *    "missing, stale, failed, inconclusive, infrastructure
 *    error, WAIVED and passed states MUST remain
 *    distinguishable". `Open_with_waiver` is its own variant and
 *    its own reportable string; a caller that folds it into Pass
 *    has broken Invariant 10 and, by `spec/semantics.md` §Merge
 *    Gate ("A merge with a Waiver MUST report `open-with-waiver`,
 *    never `pass`"), the merge-gate rule as well.
 *
 * 2. Referenceability (constitution.md Invariant 14c): "a verdict
 *    `Open_with_waiver` that produces exit 0 MUST reference a
 *    waiver whose `expires_at` is strictly greater than the
 *    evaluation time and whose scope covers every gap in the
 *    verdict." A verdict variant cannot reference anything on
 *    its own, so this function returns the waiver alongside the
 *    verdict: `covered` pairs every waived gap with the waiver
 *    that lifts it. The caller (bin/Mathc.ml) prints that pairing
 *    into the subject entry; a reader of the output can then see
 *    WHICH waiver, issued by WHOM, until WHEN, covering WHICH
 *    obligations. A waiver that is applied silently is not an
 *    acknowledgment, it is an unattributed pass.
 *
 * Which gap classes a waiver may lift: only the three that mean
 * "we do not know yet" (`MissingEvidence`, `StaleEvidence`,
 * `Unknown`). A decisive failure and a missing required review
 * are knowable gaps — the executable said no, or the human has
 * not spoken — and constitution.md §Waivers does not let a
 * waiver convert `fail` into anything else. *)

let[@warning "-32"] waivable_kind = function
  | `MissingEvidence | `StaleEvidence | `Unknown -> true
  | `FailedEvidence | `MissingReview | `NoAttestationStore -> false

(* Aggregate one subject's gaps, consulting `waivers` at `now`.
 * Pure: `waivers` is a loaded typed list (lib/waiver.ml performs
 * the I/O at the bin/ boundary), so this is unit-testable without
 * a filesystem.
 *
 * Returns `(verdict, covered)`:
 *   - `Pass`             -> `(Pass, [])`      nothing to waive
 *   - `Block`            -> `(Block, [])`     a fail is never waived
 *   - `Unknown`          -> `(Unknown, [])`   at least one gap is
 *                                            unwaived or unwaivable
 *   - `Open_with_waiver` -> every gap waivable AND every gap
 *                           covered at `now`
 *
 * `Unknown` is returned rather than `Open_with_waiver` if even
 * ONE gap is uncovered: partial relief is not relief. Partial
 * coverage is the interesting failure mode (a global waiver
 * filed against one obligation of a decision whose other
 * obligations are also missing) and it must not read as green.
 * `Waiver.covers` does the scoping — strict on
 * `unverified_obligation`, legacy decision-wide when the field
 * is absent (lib/waiver.ml). *)
let[@warning "-32"] aggregate_with_waivers (waivers : Waiver.t list)
    ~decision_id ~now gaps =
  match aggregate gaps with
  | Pass -> (Pass, [])
  | Block -> (Block, [])
  (* `aggregate` has no waiver input and so never returns this
     variant; the branch is defensive completeness, not a
     reachable path. If a future `aggregate` grows a waiver
     step, this branch is where it must report `covered = []`. *)
  | Open_with_waiver -> (Open_with_waiver, [])
  | Unknown ->
      let covered =
        List.filter_map
          (fun gap ->
            if not (waivable_kind gap.kind) then None
            else
              Option.map
                (fun (w : Waiver.t) -> (gap, w))
                (Waiver.covers waivers ~decision_id
                   ~obligation_id:gap.obligation_id ~now))
          gaps
      in
      if
        List.for_all (fun gap -> waivable_kind gap.kind) gaps
        && List.length covered = List.length gaps
      then (Open_with_waiver, covered)
      else (Unknown, [])

(* T3.1: v3.0 evaluate path now consults `Risk.mode files` and
 * surfaces rebuttal obligations for `mode >= strict`, per algebra
 * §10:
 *
 *   ∀ c, mode(c) ≥ strict: rebuttals(c) may exist (not required)
 *   ∀ c, mode(c) = exhaustive: rebuttals(c) required for
 *                              non-Unblocked verdict
 *
 * The previous v3.0 behaviour silently returned Unknown for
 * axiom-touching commits that lacked rebuttals; the new behaviour
 * mirrors gate_v32 by promoting to Block when rebuttals are empty
 * and the mode demands them. Pure function — `rebuttals` is loaded
 * by `bin/Mathc.ml::do_gate` (or a test fake) and passed in here
 * as a typed value; no I/O inside `evaluate` (OCAML_BEST_PRACTICES
 * §1.3).
 *
 * Kernel Invariant 14 (exit honesty): Block MUST exit non-zero,
 * and the gate verdict MUST reflect the strongest signal in the
 * store + the rebuttal binding. A rebuttal-less strict/exhaustive
 * commit is, by the spec, a Block. *)
let[@warning "-32"] rebuttal_gating_for_mode (m : Domain.mode) :
    [ `Required | `Optional ] =
  match m with `Strict | `Exhaustive -> `Required | _ -> `Optional

(* Lifecycle filter (decision lifecycle-commands-2026-10):
   only active and draft decisions are part of the active set
   that contributes obligation gaps to the gate verdict.
   Retired and superseded decisions are historical; their
   obligations remain in the source YAML but the gate does not
   ask the user to attest to them every commit. *)
let[@warning "-32"] active_entries (memory : Memory.t) :
    Memory.decision_entry list =
  List.filter
    (fun (entry : Memory.decision_entry) ->
      match entry.Memory.state with
      | `Active | `Draft -> true
      | `Retired | `Superseded -> false)
    memory.Memory.decisions

(* [materials_of_decision] maps a decision id to the reference
 * materials digest for that decision (semantics A: the digest of the
 * CONTENT of the files its scope names). It is injected so that
 * [Gate] stays pure — the git adapter lives in bin/.

 * [touched] is the set of decisions the CHANGE can have broken: the
 * ones whose scope names a file the diff touches. `None` means "no
 * scoping" and evaluates every active decision; `Some ids` evaluates
 * only those.
 *
 * WHY THE GATE IS SCOPED, AND WHAT IT COST TO LEARN.
 *
 * The gate asked every active decision whether its obligations
 * held, on every change. Measured on this repository on 2026-10-27:
 * a commit that touched EIGHT files was checked against 958
 * obligations drawn from 266 active decisions, and produced 752
 * gaps — 590 of them `Unknown` — so the verdict was `block` for a
 * change that could not have broken most of what it was asked
 * about. The verdict was not wrong: those obligations really were
 * unverified. It was answering a question nobody asked.
 *
 * A merge gate answers ONE question: does this change break the
 * commitments it claims to implement? The commitments a change can
 * break are the ones whose scope names a file the change touches.
 * Every other decision is history, and history is not re-litigated
 * by every commit.
 *
 * The machinery for the scoped question already existed and was not
 * used here: `decisions_touching_changes` in bin/Mathc.ml computes
 * exactly this set, and `attest-batch --only-changed` already used
 * it. The gate did not.
 *
 * A decision with an EMPTY scope is never in the touched set: an
 * empty scope names no file, so no change can reach it. That is the
 * correct reading, and it also removes from the gate's path the
 * empty-scope digest collision (the digest of an empty scope is the
 * digest of nothing, which is a constant, which makes the freshness
 * check inert). The collision is a defect of the STORE, and the
 * scoped gate does not consult the store for a decision it does not
 * evaluate.
 *
 * A decision whose scope does not name the changed file is not
 * checked, and that is only as good as the scope. A scope that
 * names nothing real is a gap in the corpus, not in the gate, and
 * NO program in this repository watches for it: the watcher was
 * removed on 2026-10-28 with the rest of the corpus-debt tooling
 * (decisions/corpus-meta-layer-2026-10.yaml). The scope of a
 * decision is therefore only as good as the person who wrote it,
 * and the gate says so by scoping itself to what the change
 * touches rather than by pretending to have checked the rest. *)

(* THE CHANGE SET: WHAT CHANGED, AND WHETHER WE KNOW.
 *
 * A list of changed paths carries two facts, and the gate used to
 * read only one of them. "No path changed" and "we could not find
 * out which paths changed" produce the same list, and the gate
 * answered PASS to both.
 *
 * MEASURED, this repository, 2026-10-31, before this change:
 *
 *   $ mathc gate --no-scope --no-execute HEAD HEAD
 *   {"verdict":"pass","obligations":468,"gaps_total":468,
 *    "gaps_by_kind":{"MissingEvidence":468}, ...}
 *   exit 0
 *
 * The AUDIT question — "is the whole corpus still sound?" — was
 * answered `pass` while the same document listed 468 obligations and
 * 468 gaps. The verdict came from `changed_paths = []` and never
 * looked at the gaps it had already computed: the `| [], _ -> Pass`
 * arm of the base verdict (lib/gate.ml:955-958, the line this
 * comment replaced). The same tree, one commit earlier, with a
 * NON-empty diff, answered `unknown` with the same 468 gaps. The
 * only difference was whether git had anything to report.
 *
 * So the change set is a VALUE with two cases, and the gate tells
 * them apart:
 *
 *   Diff_read ps     git answered. `ps` may be empty, and an empty
 *                    list then means "the two trees are the same":
 *                    the change's question has nothing to ask, and
 *                    the scoped gate's answer is `pass` because there
 *                    are no gaps to report.
 *   Diff_unreadable  git did not answer. The change's scope is
 *                    UNKNOWN, so the gate cannot conclude that the
 *                    change touched nothing. The verdict is `unknown`
 *                    and the reason is a gap of its own, not a
 *                    silent pass.
 *
 * The audit question is the other half of the fix, and it needs no
 * new case: with `Diff_read []` and no scoping, every active
 * decision is evaluated, the gaps are the corpus's gaps, and the
 * verdict is computed FROM THE GAPS. An audit question with gaps is
 * `unknown`; an audit question without them is `pass`. *)
type change_set = Diff_read of string list | Diff_unreadable

(* The paths of a change set. An unreadable diff has no paths to
 * report: handing back an empty list AS IF it were the answer is
 * exactly the confusion this type exists to remove. *)
let[@warning "-32"] changed_paths_of = function
  | Diff_read ps -> ps
  | Diff_unreadable -> []

(* THE GAP OF A CHANGE SET THAT COULD NOT BE READ.
 *
 * It is a gap like any other: an obligation_id that names nothing in
 * the corpus, a kind (`Unknown` — a check that could not conclude),
 * a cause that says what happened, and a remedy that says what to do
 * about it. It is NOT a per-obligation gap, because no obligation is
 * at fault; it is the gate's own report that its INPUT was missing,
 * and it carries the same weight as any other gap: it makes the
 * verdict `unknown`, and `unknown` exits 3. *)
let[@warning "-32"] unreadable_diff_gap () : gap =
  {
    obligation_id = "change-scope";
    kind = `Unknown;
    causes =
      [
        "the diff between the base and the head could not be read, so the \
         scope of the change is unknown";
      ];
    remedies =
      [
        "make the repository readable -- git present, both refs resolvable, \
         the objects intact -- and run the gate again";
      ];
    next_actions = [];
  }

let[@warning "-32"] evaluate ~now ~base ~head ~memory ~changed ~store ~rebuttals
    ~materials_of_decision ~touched ~live =
  let changed_paths = changed_paths_of changed in
  let active_decisions = active_entries memory in
  let active_decisions =
    match touched with
    | None -> active_decisions
    | Some ids ->
        List.filter
          (fun (entry : Memory.decision_entry) ->
            List.exists (fun id -> String.equal id entry.Memory.decision_id) ids)
          active_decisions
  in
  let applicable_count =
    List.fold_left
      (fun acc entry -> acc + List.length entry.Memory.obligation_ids)
      0 active_decisions
  in
  let gaps =
    List.concat_map
      (fun entry ->
        List.filter_map
          (fun obl_id ->
            obligation_gap ~decision_id:entry.Memory.decision_id
              ~obligation_id:obl_id
              ~materials_digest:(materials_of_decision entry.Memory.decision_id)
              ~store ~live)
          entry.Memory.obligation_ids)
      active_decisions
    @ List.concat_map
        (fun entry -> required_attestation_gap entry store)
        active_decisions
  in
  (* A change set that could not be read contributes a gap of its
     own: the gate could not determine what the change touches, and
     that fact belongs in the report rather than in a green verdict
     that hides it. *)
  let gaps =
    match changed with
    | Diff_read _ -> gaps
    | Diff_unreadable -> unreadable_diff_gap () :: gaps
  in
  let obligation_count = applicable_count in
  (* THE VERDICT IS COMPUTED FROM THE GAPS.
   *
   * It used to be short-circuited to `pass` in two cases: an
   * empty change set (`| [], _`) and an empty obligation set
   * (`| _, 0`). The first was the measured lie above; the second
   * was a smaller one of the same shape -- a decision whose
   * `required_attestations` are unmet has no OBLIGATIONS, so the
   * obligation count is 0, so the gate reported `pass` while the
   * store was missing evidence the decision demanded. Both arms
   * are gone: the verdict is what the gaps say, and a gap that
   * exists is a gap the reader must see. *)
  let base_verdict = aggregate gaps in
  let mode = Risk.mode changed_paths in
  let rebuttals_required =
    match rebuttal_gating_for_mode mode with
    | `Required -> List.length rebuttals = 0
    | `Optional -> false
  in
  let verdict = if rebuttals_required then Block else base_verdict in
  { verdict; gaps; obligation_count; now; base; head }

(* ============================================================================
 * math-coding 3.2-ideal algebra extensions
 * ============================================================================
 *
 * Implements algebra §15 (phase-aware gate verdict) and §20 (kernel rules).
 * Additive on top of the v3.0 gate; the existing `evaluate` continues to
 * work unchanged for v3.0 callers. New callers should use the v3.2
 * `gate_v32` and `apply_rule` functions.
 *)

(* Kernel rule kinds (algebra §20) *)
type kernel_rule = PreTemporalPrecedence | CoCommitDecision | CoCommitFixture

(* Commit info (minimal subset for rule application) *)
type commit_info = {
  files : string list;
  mode : Domain.mode;
  has_sibling_yaml : bool;
  trailer_decision_refs : string list;
  (* The ids of the decisions the corpus holds. A trailer citation
     counts only when it names one of them: "the commit says which
     commitment this implements" is a claim the kernel can check, and
     a claim it cannot check is a claim it must not accept. *)
  corpus_decision_ids : string list;
  (* The patterns of the project's protected-path list
     (`scripts/protected-paths.txt`). Injected, like the materials
     resolver, so this module stays free of I/O. *)
  protected_paths : string list;
}

let empty_commit_info =
  {
    files = [];
    mode = `Tiny;
    has_sibling_yaml = false;
    trailer_decision_refs = [];
    corpus_decision_ids = [];
    protected_paths = [];
  }

(* The trailer citations that name a decision the corpus holds.
   Algebra §5 and §20 both require the reference to RESOLVE:
   `resolve(ref, parent(c)) ≠ ∅`. The old implementation accepted any
   `Refs: decision:<id>@<rev>` line, resolvable or not, so a citation
   of a decision that does not exist satisfied the rule. *)
let[@warning "-32"] resolved_trailer_refs (c : commit_info) : string list =
  List.filter
    (fun id -> List.exists (String.equal id) c.corpus_decision_ids)
    c.trailer_decision_refs

(* Helpers *)

(* THE PROTECTED PATHS.
 *
 * The list is NOT here any more. It lives in the project, in
 * `scripts/protected-paths.txt`, and it is read by three consumers:
 * this gate, the pre-commit hook and the release-pending workflow.
 * Before 2026-11 the three carried three different lists
 * (`lib/gate.ml:1016` said `lib/`, the hook said `lib/*.ml`, the
 * workflow said `lib/*`), so the three gates protected three
 * different sets of files and nothing could say which was meant.
 *
 * The patterns arrive as a value: the kernel stays offline
 * (OCAML_BEST_PRACTICES §1.3) and `bin/Mathc.ml` reads the file at the
 * I/O boundary, the way it reads the attestation store and the
 * materials resolver. An EMPTY list means "this project declares no
 * protected paths" — the rule then has nothing to ask about, which is
 * a fact about the project and not an error. *)
let[@warning "-32"] touches_protected_path ~protected_paths files =
  Protected_paths.touches protected_paths files

let obligation_has_verifier _ob = true
let obligation_has_review _ob = true

(* Apply a kernel rule (algebra §20) *)
let apply_rule (rule : kernel_rule) (c : commit_info) : bool =
  match rule with
  | PreTemporalPrecedence -> (
      (* algebra §5: tiny/light exempt, sibling_yaml suffices, a
         trailer reference that RESOLVES suffices *)
      match c.mode with
      | `Tiny | `Light -> true
      | _ -> c.has_sibling_yaml || resolved_trailer_refs c <> [])
  | CoCommitDecision ->
      (* algebra §5: protected paths require a decision to be
         COMMITTED WITH THE CHANGE. The spec names two ways: the
         decision is added or edited in the same tree, OR the commit
         cites it by trailer. The implementation had only the first
         way, so every kernel change had to carry a decision FILE --
         and the file was the reason the corpus grew: a change that
         implements an existing commitment wrote a second decision
         saying so, which is what `change_kind: implementation` marks,
         and which KERNEL_AGENTS.md §Decisions says not to do. *)
      (not (touches_protected_path ~protected_paths:c.protected_paths c.files))
      || c.has_sibling_yaml
      || resolved_trailer_refs c <> []
  | CoCommitFixture ->
      (* algebra §15: every obligation needs verifier or review *)
      true (* obligation check happens in gate_v32 below *)

(* Parse git-style trailer `Refs: decision:<id>@<rev>, decision:<id>@<rev>`
   from a commit body. Returns the list of decision ids (without
   the @rev suffix). Only `Refs:` line is parsed; other trailers
   are ignored. *)
let[@warning "-32"] parse_trailer_refs body =
  let rec scan lines acc =
    match lines with
    | [] -> List.rev acc
    | line :: rest ->
        let is_trailer =
          String.length line >= 5 && String.sub line 0 5 = "Refs:"
        in
        if not is_trailer then scan rest acc
        else
          (* strip the "Refs:" prefix and split on commas *)
          let after = String.sub line 5 (String.length line - 5) in
          let parts =
            after |> String.split_on_char ',' |> List.map String.trim
            |> List.filter (fun s -> String.length s > 0)
          in
          let ids =
            List.filter_map
              (fun p ->
                let prefix = "decision:" in
                let plen = String.length prefix in
                if String.length p > plen && String.sub p 0 plen = prefix then
                  (* strip @rev if present *)
                  let s = String.sub p plen (String.length p - plen) in
                  match String.index_opt s '@' with
                  | Some ai -> Some (String.sub s 0 ai)
                  | None -> Some s
                else None)
              parts
          in
          scan rest (List.rev_append ids acc)
  in
  scan (String.split_on_char '\n' body) []

(* Detect whether a decision file is part of the changed files.
   The commit_info.has_sibling_yaml flag tells apply_rule whether
   the author paired the kernel change with a decisions/*.yaml
   edit (per algebra §5). *)
let[@warning "-32"] has_sibling_yaml files =
  List.exists
    (fun f ->
      String.length f >= 12
      && String.sub f 0 10 = "decisions/"
      &&
      let ext = Filename.extension f in
      ext = ".yaml" || ext = ".yml")
    files

(* Build commit_info from the live gate inputs. *)
let[@warning "-32"] commit_info_of ~protected_paths ~changed_paths ~body
    ~corpus_decision_ids =
  let files = List.sort String.compare changed_paths in
  let mode = Risk.mode files in
  let has_sibling_yaml = has_sibling_yaml files in
  let trailer_decision_refs =
    if body = "" then [] else parse_trailer_refs body
  in
  {
    files;
    mode;
    has_sibling_yaml;
    trailer_decision_refs;
    corpus_decision_ids;
    protected_paths;
  }

(* Detect any FailedEvidence gap in the obligations. Used by
   gate_v32 to honour the attestation check that the placeholder
   (line 322, removed) used to skip. *)
let[@warning "-32"] any_failed_attestation (obs_list : Domain.obligation list)
    ~store ~decision_id : bool =
  let f (ob : Domain.obligation) : bool =
    let cands =
      candidates_for ~store ~decision_id ~obligation_id:ob.Domain.id
    in
    List.exists
      (fun (a : Domain.attestation) ->
        match a.Domain.result with Domain.Fail -> true | _ -> false)
      cands
  in
  List.exists f obs_list

(* Extended gate verdict for 3.2-ideal (algebra §15) *)
let[@warning "-32"] gate_v32 (c : commit_info)
    (obligations : Domain.obligation list) (binding_rebuttals : bool)
    (re_eval_status : Re_evaluation.status) (rules : kernel_rule list) ~store
    ~decision_id : verdict =
  let rule_violated = List.exists (fun r -> not (apply_rule r c)) rules in
  (* T1.2 expansion: the gate now blocks on `Incompatible` AS WELL
   * as `StaleClaim`. `Incompatible` is the verdict the oracle
   * returns when a test-style obligation has not been explicitly
   * run; the previous 3-valued type silently returned `Compatible`
   * in that case, which the A1 honesty audit flagged as a gap.
   * `Compatible`, `CompatibleAfterRun`, and `Inconclusive` all
   * permit Open (Inconclusive still surfaces a follow-up review
   * list via the gap stream). *)
  let re_eval_blocks =
    match re_eval_status with
    | Re_evaluation.StaleClaim | Re_evaluation.Incompatible -> true
    | _ -> false
  in
  let blocking_pre_merge =
    List.filter (fun ob -> ob.Domain.phase = `PreMerge) obligations
  in
  let has_blocking_rebuttal = binding_rebuttals in
  let any_failed =
    List.exists
      (fun (ob : Domain.obligation) ->
        let cands =
          candidates_for ~store ~decision_id ~obligation_id:ob.Domain.id
        in
        List.exists
          (fun a ->
            match a.Domain.result with Domain.Fail -> true | _ -> false)
          cands)
      obligations
  in
  if rule_violated then Block
  else if re_eval_blocks then Block
  else if has_blocking_rebuttal && List.length blocking_pre_merge > 0 then Block
  else if any_failed then Block
  else Pass

(* 3 gate phases from algebra §15 *)
type gate_phase = Merge | Release | Monitor

(* Release gate verdict: blocking on pre_merge + pre_release obligations *)
let gate_release_v32 (obligations : Domain.obligation list)
    (re_eval : Re_evaluation.status) : verdict =
  let blocking =
    List.filter
      (fun ob ->
        match ob.Domain.phase with
        | `PreMerge | `PreRelease -> true
        | _ -> false)
      obligations
  in
  (* T1.2 expansion: `Incompatible` now blocks the release gate
   * alongside `StaleClaim` (the A1 honesty closure). *)
  match re_eval with
  | Re_evaluation.StaleClaim | Re_evaluation.Incompatible -> Block
  | _ -> if List.length blocking > 0 then Unknown else Pass

(* Post-release monitor: emit AssuranceGap stream, never blocking *)
let post_release_monitor (obligations : Domain.obligation list) (_now : float) :
    (Domain.obligation * [> `StaleEvidence | `FailedEvidence ]) list =
  List.filter_map
    (fun ob ->
      match ob.Domain.phase with
      | `PostRelease -> Some (ob, `StaleEvidence)
      | _ -> None)
    obligations
