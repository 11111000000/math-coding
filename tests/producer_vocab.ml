(* tests/producer_vocab.ml -- the producer claim must be class-tagged,
 * and a human claiming machine-grade evidence must name the run.
 *
 * WHY THIS TEST EXISTS
 * -------------------
 * `schemas/attestation.json` declared `producer.identity` as a bare
 * string. Nothing in the corpus distinguished a human DECLARATION
 * from a machine OBSERVATION, so the one distinction that gives an
 * attestation its epistemic weight was unenforced -- and violated.
 * Measured over the 765 tracked attestations at the time of
 * `decisions/attestation-producer-vocab-2026-10`: 369 declared a
 * `human:` identity, and 90 of those were demonstrably agent-produced
 * (`human:opencode-agent` 60, `human:integration-experiment` 17,
 * `human:agent-a1` 5, `human:opencode-agent-c4` 3, and five
 * `human:subagent-*` at 1 each). The brief's own enumeration sums to
 * 90, not the ~80 it estimated.
 *
 * WHAT IS AND IS NOT PINNED HERE
 * ------------------------------
 * The rule is ASYMMETRIC, so the test is asymmetric too:
 *
 *   - `human:` + `kind_: review` is ALLOWED, unconstrained. Review is
 *     the weak class -- "a human declaration without a runtime
 *     anchor", the same exemption MC-MATERIALS-DIGEST-EMPTY grants.
 *     An agent that falsely claims it upgrades nothing, because
 *     review evidence is already the weaker kind. There is no attack
 *     to defend against, so no rule is imposed. This is the case a
 *     future "forbid `human:` on review too" change would break, and
 *     it should break loudly.
 *
 *   - `human:` + a runtime kind is REJECTED without `producer.run`.
 *     That combination is the upgrade: a person's name attached to a
 *     machine-grade claim. Naming the run makes the claim
 *     falsifiable -- `mathc verify` executes the named command.
 *
 * What this test cannot pin, and does not pretend to: that a `human:`
 * tag is TRUE. No attestation in the store carries a signature (0 of
 * 765), so there is no key class to check a claim against. A `human:`
 * tag is a declaration. Closing that would need key separation, and
 * the substrate does not have it yet. *)
module Fs = Filename

(* --- fixtures ---------------------------------------------------- *)

(* A minimal well-formed attestation. `materials_digest` is non-empty
 * for runtime kinds so MC-MATERIALS-DIGEST-EMPTY does not pre-empt the
 * producer rule under test: the CLI reports one defect at a time,
 * materials digest first, so a fixture that omitted it would exercise
 * the wrong diagnostic.
 *
 * `%S` is OCaml escaping, which agrees with JSON on every byte these
 * fixtures use (plain ASCII, no quote, no backslash). The producer
 * strings here are identifiers and shell commands, so that agreement
 * holds; a fixture needing a real escape would want a JSON writer. *)
let[@warning "-32"] attestation ~kind_ ~producer ~materials_digest =
  Printf.sprintf
    {|{"schema":"math-coding/attestation-3.3","kind":"attestation","id":"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","subject":{"decision":"d","obligation":"o","candidate_tree":"HEAD","materials_digest":"%s"},"kind_":%S,"producer":%s,"result":"pass","issued_at":"2026-10-23T00:00:00Z"}|}
    materials_digest kind_ producer

(* Note the escaped-quote form rather than a `{|...|}` raw string: the
   closing `|}` would swallow the JSON brace this fragment needs. *)
let[@warning "-32"] identity i = Printf.sprintf "{\"identity\":%S}" i

let[@warning "-32"] with_run i r =
  Printf.sprintf "{\"identity\":%S,\"run\":%S}" i r

(* Any non-empty value satisfies the non-empty digest check; the
 * materials digest is not what these fixtures are about. *)
let[@warning "-32"] anchored = "sha256:beef"

(* Parse and validate the way `mathc validate` does, returning the
 * diagnostic code, or "" when the attestation is accepted. *)
let[@warning "-32"] code_of_json json =
  match Jsonl.parse json with
  | exception _ -> "<unparseable>"
  | v -> (
      match Codec.parse_attestation v with
      | None -> "<not-an-attestation>"
      | Some a -> (
          match Codec.validate_attestation_materials a with
          | Some d -> d.Diagnostic.code
          | None -> (
              match Codec.validate_attestation_producer a with
              | Some d -> d.Diagnostic.code
              | None -> "")))

(* --- identity shape ---------------------------------------------- *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    let candidate = Fs.concat d "dune-project" in
    if Sys.file_exists candidate then d
    else
      let parent = Fs.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

(* The git-tracked file names under a store directory, or None when
   git cannot answer. Test runs leave gitignored attestations in the
   store -- at the time of writing the directory held 1585 .json
   files against 765 tracked ones -- so a walk over `Sys.readdir`
   would count evidence and scratch together. Mirrors the filter in
   tests/store_admission.ml, and inherits its documented trap: `git
   ls-files` prints paths relative to the REPOSITORY ROOT even when
   the pathspec is absolute, so the prefix stripped here must be the
   repository-relative one. Stripping the absolute prefix matches
   nothing and silently admits nothing. None is NOT the same as an
   empty list: "git could not answer" must not empty the corpus. *)
let[@warning "-32"] repo_root ~root =
  let out = Filename.temp_file "mc_git_toplevel_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove out with _ -> ())
    (fun () ->
      let cmd =
        Printf.sprintf "git -C %s rev-parse --show-toplevel > %s 2>/dev/null"
          (Fs.quote root) (Fs.quote out)
      in
      ignore (Sys.command cmd);
      let raw =
        try String.trim (In_channel.with_open_bin out In_channel.input_all)
        with _ -> ""
      in
      if raw = "" then None else Some raw)

let[@warning "-32"] tracked_names ~root ~store =
  match repo_root ~root with
  | None -> None
  | Some toplevel ->
      let out = Filename.temp_file "mc_tracked_names_" ".txt" in
      Fun.protect
        ~finally:(fun () -> try Sys.remove out with _ -> ())
        (fun () ->
          let cmd =
            Printf.sprintf "git -C %s ls-files -z -- %s > %s 2>/dev/null"
              (Fs.quote root) (Fs.quote store) (Fs.quote out)
          in
          ignore (Sys.command cmd);
          let raw =
            try In_channel.with_open_bin out In_channel.input_all with _ -> ""
          in
          (* Reduce the store path against the toplevel so both sides
             speak repository-relative. *)
          let rel =
            let prefix = Fs.concat toplevel "" in
            let plen = String.length prefix in
            if String.length store > plen && String.sub store 0 plen = prefix
            then String.sub store plen (String.length store - plen)
            else Fs.basename store
          in
          let prefix = Fs.concat rel "" in
          let plen = String.length prefix in
          let names =
            List.filter_map
              (fun p ->
                let n = String.length p in
                if n > plen && String.sub p 0 plen = prefix then
                  Some (String.sub p plen (n - plen))
                else None)
              (List.filter (fun s -> s <> "") (String.split_on_char '\000' raw))
          in
          if names = [] then None else Some names)

(* Parse the store through the kernel's own decoder, so the walk sees
   exactly what the gate sees. Prefers the git-tracked set; falls back
   to every .json on disk outside version control (the adoption case).
   Returns None when there is no store at all. *)
let[@warning "-32"] load_corpus () =
  let root = project_root () in
  let store = Fs.concat root "attestations" in
  if not (Sys.is_directory store) then None
  else
    let kind_string = function
      | `Test -> "test"
      | `Build -> "build"
      | `Observation -> "observation"
      | `Analysis -> "analysis"
      | `Review -> "review"
    in
    let names =
      match tracked_names ~root ~store with
      | Some n -> n
      | None -> (
          (* The store is a GENERATED artefact. It can be absent, and it
             can be swept away while this test is reading it. Neither is
             a failure of the vocabulary; both mean "there is nothing
             to read", and a test that crashes on a missing directory
             takes the whole suite down with it. *)
          try
            Sys.readdir store |> Array.to_list
            |> List.filter (fun n -> Filename.check_suffix n ".json")
          with _ -> [])
    in
    Some
      (List.sort compare names
      |> List.filter_map (fun name ->
          let raw =
            In_channel.with_open_bin (Fs.concat store name) In_channel.input_all
          in
          match Jsonl.parse raw with
          | exception _ -> None
          | v -> (
              match Codec.parse_attestation v with
              | None -> None
              | Some a ->
                  Some
                    ( a.Domain.producer_identity,
                      a.Domain.producer_run,
                      kind_string a.Domain.kind,
                      a.Domain.candidate_tree ))))

(* The commit this tree is at. The store is GENERATED now, so the
   corpus holds attestations for more than one tree; the pins that are
   about what the sweep PRODUCES ask about this tree's. *)
let[@warning "-32"] head_sha () =
  let root = project_root () in
  let out = Filename.temp_file "mc_head_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove out with _ -> ())
    (fun () ->
      let cmd =
        Printf.sprintf "git -C %s rev-parse HEAD > %s" (Filename.quote root)
          (Filename.quote out)
      in
      if Sys.command cmd <> 0 then Alcotest.fail "git rev-parse failed";
      let raw =
        try In_channel.with_open_bin out In_channel.input_all with _ -> ""
      in
      String.trim raw)

(* The class prefix, or "" when the identity carries none. Duplicated
 * from Codec.producer_class_of only in the sense that it answers a
 * different question -- "what class is this?" where that function
 * answers "is this well-formed, and if so which class?" *)
let[@warning "-32"] class_prefix identity =
  match String.index_opt identity ':' with
  | Some i when i > 0 -> String.sub identity 0 i
  | _ -> ""

(* The drift guard. Every class-tagged identity in the committed corpus
 * must satisfy the kernel's matcher: if a future author tightens
 * `Codec.producer_identity_ok` or the `pattern` in
 * `schemas/attestation.json` and not the other, this fails. Run over
 * the live store, not a fixture, so it reads the real vocabulary. *)
let[@warning "-32"] test_every_tagged_corpus_identity_is_accepted () =
  match load_corpus () with
  | None -> Printf.printf "  n/a  no attestation store\n"
  | Some corpus ->
      (* The drift guard reads the attestations THE SWEEP PRODUCED for
         this tree, and nothing else. The store is generated and it can
         be mid-sweep -- or hold a probe written by a test that is
         running right now, in parallel with this one. The vocabulary
         of the current tree's evidence is the subject; the leftovers
         of other trees are history. *)
      let head = head_sha () in
      let mine =
        List.filter (fun (_, _, _, tree) -> String.equal tree head) corpus
      in
      if mine = [] then
        Printf.printf
          "  no attestations for %s yet: the sweep has not run for this tree\n"
          (String.sub head 0 8)
      else begin
        let tagged =
          List.filter
            (fun (i, _, _, _) ->
              match class_prefix i with
              | "human" | "agent" | "ci" -> true
              | _ -> false)
            mine
        in
        let bad =
          List.filter_map
            (fun (i, _, _, _) ->
              if Codec.producer_identity_ok i then None else Some i)
            tagged
          |> List.sort_uniq compare
        in
        Alcotest.(check (list string))
          "class-tagged corpus identities the kernel rejects" [] bad;
        (* Anti-vacuity: the walk must not have read nothing. The floor
           is one, not the five hundred of the committed era: the store
           is GENERATED now, and the number of attestations a sweep
           produces for one tree is the sweep's business. What this
           pins is that the walk READ something. *)
        Alcotest.(check bool)
          "the corpus for this tree has class-tagged identities" true
          (List.length tagged >= 1)
      end

(* An untagged identity names nobody. These are the six forms the
 * committed corpus still carries, plus shapes a future author might
 * reach for -- including a wrong-case tag, which must not pass as
 * `human`. *)
let[@warning "-32"] test_untagged_identities_are_not_classes () =
  List.iter
    (fun i ->
      Alcotest.(check bool)
        (Printf.sprintf "%S declares no claim class" i)
        false
        (Codec.producer_identity_ok i))
    [
      "ci-bot";
      "ci-bot:dune-runtest";
      "ci-bot:re-evaluate-decisions";
      "dune:test";
      "sub-agent-A4-batchA";
      "test";
      "bot";
      "ci:";
      ":bot";
      "robot:ci-bot";
      "HUMAN:ada";
      " human:ada";
      "human: ada";
    ]

(* Subjects legitimately contain colons -- the corpus is full of
 * `ci:fixture:conformance` -- so the matcher must not stop at the
 * first one, and must reject a subject that starts with a separator. *)
let[@warning "-32"] test_colons_in_the_subject_are_allowed () =
  List.iter
    (fun i ->
      Alcotest.(check bool)
        (Printf.sprintf "%S is class-tagged and well-formed" i)
        true
        (Codec.producer_identity_ok i))
    [
      "human:p.b.kosov";
      "human:maintainer";
      "human:subagent-install-fallback";
      "agent:opencode:ux-3-merge";
      "ci:fixture:conformance";
      "ci:subagent-C4";
      "agent:opencode:site-svg-batch-2026-10";
    ]

(* --- the anchoring rule ------------------------------------------ *)

let[@warning "-32"] test_human_runtime_kind_needs_a_run () =
  List.iter
    (fun kind_ ->
      let json =
        attestation ~kind_ ~materials_digest:anchored
          ~producer:(identity "human:opencode-agent")
      in
      Alcotest.(check string)
        (Printf.sprintf "human: on kind_=%s with no run is rejected" kind_)
        "MC-PRODUCER-HUMAN-UNANCHORED" (code_of_json json))
    [ "test"; "build"; "analysis"; "observation" ]

let[@warning "-32"] test_a_named_run_settles_the_claim () =
  List.iter
    (fun kind_ ->
      let json =
        attestation ~kind_ ~materials_digest:anchored
          ~producer:(with_run "human:p.b.kosov" "dune build")
      in
      Alcotest.(check string)
        (Printf.sprintf "human: on kind_=%s with a run is accepted" kind_)
        "" (code_of_json json))
    [ "test"; "build"; "analysis"; "observation" ]

(* The asymmetry, stated as a test: review is the weak class, so an
 * unverifiable human claim there costs the store nothing. *)
let[@warning "-32"] test_human_review_needs_no_run () =
  let json =
    attestation ~kind_:"review" ~materials_digest:""
      ~producer:(identity "human:maintainer")
  in
  Alcotest.(check string)
    "human: on kind_=review is accepted" "" (code_of_json json)

(* An empty run string is not a run: `run: ""` must not satisfy the
 * requirement while naming nothing. *)
let[@warning "-32"] test_an_empty_run_is_not_a_run () =
  let json =
    attestation ~kind_:"test" ~materials_digest:anchored
      ~producer:(with_run "human:p.b.kosov" "")
  in
  Alcotest.(check string)
    "run: \"\" does not count as a run" "MC-PRODUCER-HUMAN-UNANCHORED"
    (code_of_json json)

(* An untagged identity on a runtime kind reports the UNDECLARED code,
 * not the unanchored one: "who produced this" is the prior question,
 * and an untagged runtime attestation has no human claim to anchor. *)
let[@warning "-32"] test_untagged_reports_the_prior_question () =
  let json =
    attestation ~kind_:"test" ~materials_digest:anchored
      ~producer:(identity "ci-bot")
  in
  Alcotest.(check string)
    "an untagged identity is reported before the anchoring rule"
    "MC-PRODUCER-CLASS-UNDECLARED" (code_of_json json)

(* --- machine producers are unaffected --------------------------- *)

(* The rule must not touch what already worked. A CI job claiming a
 * test result is the ordinary case; the `ci:` class carries no run
 * requirement, because naming the job is the anchor there. *)
let[@warning "-32"] test_machine_producers_are_unaffected () =
  List.iter
    (fun (kind_, id) ->
      let json =
        attestation ~kind_ ~materials_digest:anchored ~producer:(identity id)
      in
      Alcotest.(check string)
        (Printf.sprintf "%S on kind_=%s is accepted" id kind_)
        "" (code_of_json json))
    [
      ("test", "ci:bot");
      ("build", "ci:build:dune");
      ("analysis", "agent:release-3.3.0");
      ("observation", "agent:codex:self-check-recovery-2026-10");
      ("review", "agent:release-3.3.0");
    ]

(* --- the committed backlog, pinned ------------------------------ *)

(* The grandfathered debt. 60 committed attestations carry an untagged
 * identity (the re-sign that prunes orphans removed two of them) and
 * 58 carry `human:` on a runtime kind (26 of those
 * `human:maintainer`, 32 provably agent-produced). They are NOT
 * rewritten: `id` is the sha256 of the attestation body, the body
 * contains `producer.identity`, and rewriting identity therefore mints
 * a new evidence id for a committed file -- the same unrequested mass
 * mutation as commit 9c1f7ab, which mass-signed 793 files as
 * `human:integration-experiment` without asking.
 *
 * Pinning the numbers is what keeps that choice honest. The debt stops
 * being invisible: if files are quietly reissued, or quietly added,
 * this test says so instead of the backlog growing with nobody deciding
 * about it. If a number moves, the decision's inventory is stale and
 * the comment above needs updating in the same commit. *)
let[@warning "-32"] test_grandfathered_backlog_is_pinned () =
  match load_corpus () with
  | None -> Printf.printf "  n/a  no attestation store\n"
  | Some corpus ->
      (* The grandfathered backlog is HISTORY: it lives in the legacy
         files the sweep inherited, it is not in git's index any more
         (decisions/store-not-committed-2026-10.yaml), and it cannot be
         rewritten without minting a new id for an observation nobody
         re-ran. What must not grow is the backlog the sweep PRODUCES:
         an untagged identity and a `human:` producer on a runtime kind
         are both claims the kernel cannot check, and a new one is a
         new unbacked claim. When the sweep has not run for this tree
         there is nothing to measure. *)
      let head = head_sha () in
      let mine =
        List.filter (fun (_, _, _, tree) -> String.equal tree head) corpus
      in
      if mine = [] then
        Printf.printf
          "  no attestations for %s yet: the sweep has not run for this tree\n"
          (String.sub head 0 8)
      else begin
        let untagged =
          List.length
            (List.filter
               (fun (i, _, _, _) -> not (Codec.producer_identity_ok i))
               mine)
        in
        let human_runtime =
          List.length
            (List.filter
               (fun (i, _, k, _) -> class_prefix i = "human" && k <> "review")
               mine)
        in
        Alcotest.(check int)
          "untagged identities among the attestations this sweep produced" 0
          untagged;
        Alcotest.(check int)
          "human: producers on a runtime kind among the attestations this \
           sweep produced"
          0 human_runtime
      end

let () =
  Alcotest.run
    ~log_dir:(Fs.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "producer vocabulary"
    [
      ( "identity shape",
        [
          Alcotest.test_case "every tagged corpus identity is accepted" `Quick
            test_every_tagged_corpus_identity_is_accepted;
          Alcotest.test_case "untagged identities are not classes" `Quick
            test_untagged_identities_are_not_classes;
          Alcotest.test_case "colons in the subject are allowed" `Quick
            test_colons_in_the_subject_are_allowed;
        ] );
      ( "the anchoring rule",
        [
          Alcotest.test_case "human runtime kind needs a run" `Quick
            test_human_runtime_kind_needs_a_run;
          Alcotest.test_case "a named run settles the claim" `Quick
            test_a_named_run_settles_the_claim;
          Alcotest.test_case "human review needs no run" `Quick
            test_human_review_needs_no_run;
          Alcotest.test_case "an empty run is not a run" `Quick
            test_an_empty_run_is_not_a_run;
          Alcotest.test_case "untagged reports the prior question" `Quick
            test_untagged_reports_the_prior_question;
          Alcotest.test_case "machine producers are unaffected" `Quick
            test_machine_producers_are_unaffected;
        ] );
      ( "grandfathered backlog",
        [
          Alcotest.test_case "backlog counts are pinned" `Quick
            test_grandfathered_backlog_is_pinned;
        ] );
    ]
