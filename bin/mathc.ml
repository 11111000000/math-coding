(** The method's binary.

    Seven verbs, and each of them is one move of the protocol. The
    command line is the whole interface: an agent runs one command and
    gets the next step, not a report to interpret.

    WHERE THE FRICTION IS, AND WHERE IT IS NOT.

    Reading the state must be cheap. `map`, `route` and `next` are one
    command each and they never fail on a project that has not adopted
    the method: an empty project is green, and the map of an empty
    project says so.

    The friction is in the three places where agents make mistakes.
    `add` refuses a claim it cannot bind or cannot refute. `run` never
    turns a check that did not run into a check that passed. `close`
    refuses a wave whose verdicts did not change, because a wave that
    changes nothing is a wave that did not happen. *)

let project_root = ref "."

let set_root r = project_root := r

let root () = !project_root

let read_file path =
  let channel = open_in path in
  let content = In_channel.input_all channel in
  close_in channel;
  content

(* ------------------------------------------------------------------ *)
(* The standing specification and the trail.                            *)
(* ------------------------------------------------------------------ *)

let spec_path () = Filename.concat (root ()) "spec.json"

let load_spec () : Domain.spec =
  let path = spec_path () in
  if not (Sys.file_exists path) then
    { goal = None; budget = 0; claims = []; closed_waves = [] }
  else
    match Spec.parse_spec_string (read_file path) with
    | Ok spec -> spec
    | Error e ->
        Printf.eprintf "mathc: the standing specification is not readable: %s\n"
          (Spec.message_of e);
        exit 2

(** Save the specification. The file is machine-managed, so it is
    written whole; the aim and the claims in it are data, and the
    method is what manages them. *)
let save_spec (spec : Domain.spec) =
  let json = Spec.spec_to_json spec in
  let channel = open_out (spec_path ()) in
  output_string channel (Yojson.Safe.pretty_to_string json);
  output_char channel '\n';
  close_out channel

(** The newest evidence for each claim. The trail may hold many runs of
    the same claim; the last one is the one that counts. *)
(** The latest evidence for each requirement of each claim.

    The trail says what happened: which requirement of which claim was
    closed, with which outcome, bound to which digest, produced by whom.
    The DEFINITION of the claim - its subject, its requirements, its
    register - lives in the standing specification, and the trail only
    points at it. So the claim is taken from the specification and the
    evidence is attached to it; the trail's own copy of the claim is
    not trusted for anything but the identifier.

    The latest line for a requirement wins: an older run does not
    overrule a newer one. But a newer one does not overrule a subject
    that has since moved either - that is the binding's work, and it
    happens in [Verdict.state_of_evidence]. *)
let latest_evidence (claims : Domain.claim list) : Domain.evidence list =
  let find id = List.find_opt (fun (c : Domain.claim) -> c.id = id) claims in
  let trail = Trail.read (root ()) in
  List.fold_left
    (fun (acc : Domain.evidence list) (e : Domain.evidence) ->
      match find e.claim.id with
      | None -> acc
      | Some claim ->
          let e = { e with Domain.claim } in
          List.filter
            (fun (x : Domain.evidence) ->
              x.claim.id <> e.claim.id || x.requirement <> e.requirement)
            acc
          @ [ e ])
    [] trail

(** The current digest of a claim's subject, if the scope names
    anything. *)
let binding_of (claim : Domain.claim) : Domain.binding option =
  Git.digest_of_scope (root ()) claim.subject.scope

(** The production facts of a proof: the commit the content was read
    from and the moment of production.

    The content the method binds to is the content of HEAD - the
    committed tree - so the commit is exactly the one the proof is
    about, and not an approximation of it. A repository with no commits
    has no HEAD, and then there is nothing to anchor to: the field is
    absent rather than empty. *)
let production_facts () =
  ( Git.head_commit (root ()),
    Some (Printf.sprintf "%.0f" (Unix.time ())) )

(** The state of every claim, computed. *)
let states_of (claims : Domain.claim list) : (string * Domain.state) list =
  let evidence = latest_evidence claims in
  (* The moment, once, for the whole computation: two claims must not
     be judged against two different nows. *)
  let now = Unix.time () in
  List.map
    (fun (claim : Domain.claim) ->
      (claim.id, Verdict.state_of_claim claim (binding_of claim) now evidence))
    claims

(** How much of the uncertainty budget the project has spent. Only an
    answer is free: a claim that was refuted is answered, and a claim
    that was not checked, or whose subject moved, or that cannot be
    checked at all, is not. *)
let consumption_of (claims : Domain.claim list) : int =
  let states = states_of claims in
  List.fold_left
    (fun n (_, state) ->
      match state with
      | Domain.Holds | Domain.Refuted | Domain.Accepted -> n
      | _ -> n + 1)
    0 states

(* ------------------------------------------------------------------ *)
(* The verbs.                                                           *)
(* ------------------------------------------------------------------ *)

(** map: the standing specification of the project, computed. What is
    claimed, what is known, what is not covered. *)
(** The map, as data. The same map the human reads, in a form a program
    can read: the measurement stand consumes this, and so can an
    agent that wants to decide what to do next without parsing prose.

    The map is the method's main artifact, and an artifact that only a
    person can read is an artifact that no program can check. *)
let map_to_json (spec : Domain.spec) : Yojson.Safe.t =
  let claims = spec.Domain.claims in
  let states = states_of claims in
  let files = Git.tracked_files (root ()) in
  let uncovered = Git.uncovered claims files in
  let verdict = Verdict.verdict_of_states (List.map snd states) in
  (* The names of the states live in the codec: the map and the wave's
     promises must say the same thing about them, and a name written
     twice is two truths. *)
  let state_name = Domain.state_name in
  `Assoc
    [ ( "verdict",
        `String
          (match verdict with
          | Domain.Green -> "green"
          | Domain.Red -> "red"
          | Domain.Unknown -> "unknown") );
      ("exit", `Int (Verdict.verdict_to_exit verdict));
      ("claims", `Int (List.length claims));
      ("uncertainty_consumed", `Int (consumption_of claims));
      ("uncertainty_budget", `Int spec.Domain.budget);
      ("uncovered", `Int (List.length uncovered));
      ( "goal",
        match spec.Domain.goal with
        | None -> `Null
        | Some g ->
            `Assoc
              [ ("text", `String g.text);
                ("scope", `List (List.map (fun p -> `String p) g.Domain.scope));
                ("by", `String g.by) ] );
      ( "states",
        `List
          (List.map
             (fun (id, state) ->
               `Assoc
                 [ ("id", `String id);
                   ("state", `String (state_name state));
                   (* The act the proof belongs to: the commit its
                      content was read from, and who produced it. A
                      state says what is known; this says where the
                      knowing came from. *)
                   ( "at_commit",
                     match
                       List.find_opt
                         (fun (e : Domain.evidence) -> e.claim.id = id)
                         (latest_evidence claims)
                     with
                     | Some e -> (
                         match e.at_commit with
                         | Some c -> `String c
                         | None -> `Null)
                     | None -> `Null );
                   ( "produced_by",
                     match
                       List.find_opt
                         (fun (e : Domain.evidence) -> e.claim.id = id)
                         (latest_evidence claims)
                     with
                     | Some e -> `String e.producer
                     | None -> `Null );
                   (* WHY the proof does not count, when it does not:
                     the content moved under it, or its term is over.
                     Two different faults, and the map must not merge
                     them. *)
                   ( "outdated_because",
                     match
                       List.find_opt
                         (fun (e : Domain.evidence) -> e.claim.id = id)
                         (latest_evidence claims)
                     with
                     | Some e when state = Domain.Outdated ->
                         if Verdict.expired (Unix.time ()) e then `String "the term is over"
                         else `String "the subject moved"
                     | _ -> `Null ) ])
             states) );
      ( "uncovered_paths",
        `List (List.map (fun f -> `String f) uncovered) )]

let verb_map json =
  let spec = load_spec () in
  if json then (
    print_endline (Yojson.Safe.pretty_to_string (map_to_json spec));
    Verdict.verdict_to_exit (Verdict.verdict_of_states (List.map snd (states_of spec.Domain.claims))))
  else
    let claims = spec.Domain.claims in
    let states = states_of claims in
    let files = Git.tracked_files (root ()) in
    let uncovered = Git.uncovered claims files in
    let verdict = Verdict.verdict_of_states (List.map snd states) in
    Printf.printf "verdict: %s (exit %d)\n"
      (match verdict with
      | Domain.Green -> "green"
      | Domain.Red -> "red"
      | Domain.Unknown -> "unknown")
      (Verdict.verdict_to_exit verdict);
    Printf.printf "claims: %d\n" (List.length claims);
    List.iter
      (fun (id, state) ->
        (* The commit the proof was produced from, when there is one: the
           state says what is known, the commit says where the knowing
           came from. *)
        let evidence_of_claim =
          List.find_opt
            (fun (e : Domain.evidence) -> e.claim.id = id)
            (latest_evidence claims)
        in
        let anchor =
          match evidence_of_claim with
          | Some e -> (
              match e.at_commit with
              | Some c -> " " ^ String.sub c 0 (min 7 (String.length c))
              | None -> "")
          | None -> ""
        in
        (* Why a proof does not count: the content moved under it, or
           its term is over. The two faults are told apart, because the
           map that merges them reports a week-old proof and a proof
           nobody may rely on as the same thing. *)
        let why =
          match (state, evidence_of_claim) with
          | Domain.Outdated, Some e ->
              if Verdict.expired (Unix.time ()) e then " (the term is over)"
              else " (the subject moved)"
          | _ -> ""
        in
        Printf.printf "  %-24s %s%s%s\n" id
          (match state with
          | Domain.Holds -> "holds"
          | Domain.Refuted -> "refuted"
          | Domain.Inconclusive -> "inconclusive"
          | Domain.NotCheckable -> "not checkable"
          | Domain.Outdated -> "outdated"
          | Domain.NeverChecked -> "never checked"
          | Domain.Accepted -> "accepted by a person")
          anchor why)
      states;
    Printf.printf "uncertainty: %d of %d consumed\n"
      (consumption_of claims) spec.Domain.budget;
    Printf.printf "uncovered: %d tracked file(s) no claim covers\n" (List.length uncovered);
    List.iter (fun f -> Printf.printf "  %s\n" f) uncovered;
    Verdict.verdict_to_exit verdict

(** route: what needs a person, and why. *)
let verb_route () =
  let spec = load_spec () in
  let claims = spec.Domain.claims in
  let evidence = latest_evidence claims in
  let findings = Verdict.route binding_of claims evidence in
  if findings = [] then print_endline "nothing needs a person"
  else
    List.iter
      (fun (f : Domain.finding) ->
        Printf.printf "%s: %s%s\n" f.subject
          (match f.outcome with
          | Domain.Unresolved -> "unresolved"
          | Domain.Refused -> "refused"
          | _ -> "?")
          (match f.reason with
          | Some r -> " (" ^ r ^ ")"
          | None -> ""))
      findings;
  0

(** run: execute the checks, bind the results to the subject as it
    stands, and write them to the trail.

    Only the VERIFIER requirements are run here: they are commands, and
    the method runs commands. A REVIEW requirement is closed by a
    person, and the method cannot be one - it records what a person
    says, with [mathc record], and it does not pretend to have looked.

    That is the whole difference between the two kinds, and it is the
    difference the third version enforced and this one had lost. *)
let verb_run () =
  let spec = load_spec () in
  let claims = spec.Domain.claims in
  if claims = [] then (
    print_endline "nothing to run: the standing specification is empty";
    0)
  else
    let results =
      List.map
        (fun (claim : Domain.claim) ->
          match binding_of claim with
          | None ->
              Printf.printf
                "%s: no digest - the scope names no existing path, so nothing can be \
                 bound\n"
                claim.id;
              []
          | Some binding ->
              List.filter_map
                (fun (r : Domain.requirement) ->
                  match r with
                  | Reviewed_by authority ->
                      Printf.printf "%s: reviewed by %s - not the method's to do\n"
                        claim.id authority;
                      None
                  | Verified_by command ->
                      let outcome, reason =
                        Exec.run_claim_command ~root:(root ()) command
                          claim.register
                      in
                      Printf.printf "%s: %s\n" claim.id
                        (match outcome with
                        | Domain.Verified -> "verified"
                        | Domain.Falsified -> "falsified"
                        | Domain.Unresolved -> "unresolved"
                        | Domain.Refused -> "refused");
                      let at_commit, at = production_facts () in
                      Some
                        ( {
                          Domain.claim;
                          requirement = r;
                          outcome;
                          bound_to = binding;
                          producer = command;
                          reason;
                          at_commit;
                          at;
                          valid_until = None;
                        } ))
                claim.requirements)
        claims
    in
    List.iter (fun e -> Trail.append (root ()) e) (List.concat results);
    let states = states_of claims in
    Verdict.verdict_to_exit (Verdict.verdict_of_states (List.map snd states))

(** record: take evidence from outside.

    The method runs commands, and it can record what it ran. It cannot
    be a person who looked, and it cannot be a CI run, and it cannot be
    an observation from a deployment. The third version had a separate
    kind of record for each of those, and this one had no way to
    accept any evidence it did not produce itself - which is a strange
    thing for a method whose subject is other people's work.

    So: [mathc record CLAIM SPEC --by WHO --outcome OUTCOME] closes the
    requirement of CLAIM that names SPEC, and says who produced it. A
    verifier requirement is closed by a record of the same command;
    a review requirement is closed by the authority's word. The binding
    is the subject's digest as it stands now, so the record is about
    the subject as it is, not as it was. *)
let verb_record claim_id spec by outcome (reason : string) (valid_for : string) =
  let spec_loaded = load_spec () in
  let refuse why =
    Printf.eprintf "mathc: %s\n" why;
    2
  in
  let problem =
    if by = "" then Some "a record needs a producer: --by"
    else if spec = "" then Some "a record needs the requirement it closes"
    else if valid_for <> "" && int_of_string_opt valid_for = None then
      Some "the term of a proof is a number of days"
    else None
  in
  match problem with
  | Some why -> refuse why
  | None ->
  let outcome =
    match outcome with
    | "verified" -> Domain.Verified
    | "falsified" -> Domain.Falsified
    | "unresolved" -> Domain.Unresolved
    | "refused" -> Domain.Refused
    | other -> failwith ("unknown outcome: " ^ other)
  in
  match
    List.find_opt (fun (c : Domain.claim) -> c.id = claim_id) spec_loaded.Domain.claims
  with
  | None -> refuse (Printf.sprintf "there is no claim %S" claim_id)
  | Some claim -> (
      match
        List.find_opt
          (fun (r : Domain.requirement) ->
            match r with
            | Verified_by c -> c = spec
            | Reviewed_by a -> a = spec)
          claim.requirements
      with
      | None ->
          refuse
            (Printf.sprintf
               "the claim %s has no requirement %S; its requirements are: %s" claim_id
               spec
               (String.concat ", "
                  (List.map
                     (fun (r : Domain.requirement) ->
                       match r with
                       | Verified_by c -> c
                       | Reviewed_by a -> a)
                     claim.requirements)))
      | Some requirement -> (
          match binding_of claim with
          | None ->
              refuse "the scope names no existing path, so nothing could be bound"
          | Some binding ->
              (* THE ATTESTATION GOES TO THE SPECIFICATION, NOT TO THE
                 TRAIL. The trail holds what a machine can produce
                 again, and a person's word cannot be produced again
                 by anybody - so a review that lived only in the trail
                 was lost the moment the trail was rebuilt, and the
                 claim fell back to never checked. The specification is
                 committed; the trail is not.

                 The requirement is named by the thing it names, the
                 way `record` names it, and the state is the one the
                 proof leaves the requirement in. *)
              let at_commit, at = production_facts () in
              let at = match at with Some t -> t | None -> "0" in
              let valid_until =
                match int_of_string_opt valid_for with
                | Some days ->
                    Some
                      (Printf.sprintf "%.0f"
                         (Unix.time () +. (float_of_int days *. 86400.0)))
                | None -> None
              in
              let spec_of (r : Domain.requirement) =
                match r with
                | Domain.Verified_by spec -> spec
                | Domain.Reviewed_by spec -> spec
              in
              let attestation =
                {
                  Domain.requirement = spec_of requirement;
                  who = by;
                  outcome;
                  reason = (if reason = "" then None else Some reason);
                  bound_to = binding;
                  at;
                  valid_until;
                }
              in
              save_spec
                {
                  spec_loaded with
                  Domain.claims =
                    List.map
                      (fun (c : Domain.claim) ->
                        if c.id = claim_id then
                          { c with attestations = c.attestations @ [ attestation ] }
                        else c)
                      spec_loaded.Domain.claims;
                };
              Printf.printf "recorded: %s closed by %s (%s)\n" claim_id by
                (match outcome with
                | Domain.Verified -> "verified"
                | Domain.Falsified -> "falsified"
                | Domain.Unresolved -> "unresolved"
                | Domain.Refused -> "refused");
              Printf.printf
                "  the attestation is in the specification, and the subject it was produced against is %s\n"
                (String.sub binding 0 (min 12 (String.length binding)));
              0))

(** The waves of a project, in the order they were declared. A wave is
    a slice of work; the queue is these waves that are not yet
    finished. *)
let waves_of () : Domain.wave list =
  let dir = Filename.concat (root ()) "waves" in
  if not (Sys.file_exists dir) then []
  else
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun name -> Filename.check_suffix name ".json")
    |> List.sort compare
    |> List.filter_map (fun name ->
           match Spec.parse_wave_string (read_file (Filename.concat dir name)) with
           | Ok wave -> Some wave
           | Error _ -> None)

(** next: the next work. Not a list to choose from - one item.

    It is a WAVE when there is one, and a claim when there is not. A
    wave is the larger unit: it carries the checks that must pass and
    the verdicts it declares, and it is what an agent is given to
    carry out. When the waves are exhausted, what remains is a claim
    that needs checking, or a part of the tree nobody has claimed.

    And it EXECUTES: a wave whose checks pass and whose declared
    verdicts are established is finished, and the method says so. A
    queue that only names work is a list; a queue that finishes work is
    a protocol. *)
let verb_next () =
  let spec = load_spec () in
  let claims = spec.Domain.claims in
  let states = states_of claims in
  let files = Git.tracked_files (root ()) in
  let uncovered = Git.uncovered claims files in
  (* A refuted claim is the most urgent work there is: something that
     was believed is now known to be false. It comes first, before the
     claims nobody has looked at. *)
  let refuted =
    List.filter_map
      (fun (id, state) ->
        match state with Domain.Refuted -> Some id | _ -> None)
      states
  in
  let needs_check =
    List.filter_map
      (fun (id, state) ->
        match state with
        | Domain.NeverChecked | Domain.Outdated | Domain.Inconclusive -> Some id
        | _ -> None)
      states
  in
  (* A CLOSED WAVE LEAVES THE QUEUE. The queue used to be the first
     wave by name, and closing a wave changed nothing about it, so
     `next` returned the same closed wave for ever: the queue was a
     catalogue, and the agent that was supposed to be led by it was
     led by hand. A wave that is closed is recorded in the standing
     specification - it is a fact about the work, not about the
     subject - and it is skipped here. *)
  let waves =
    waves_of ()
    |> List.filter (fun (w : Domain.wave) -> not (List.mem w.Domain.id spec.Domain.closed_waves))
  in
  match (waves, refuted, needs_check, uncovered) with
  | wave :: _, _, _, _ ->
      (* A wave is the unit of work. It is executed here: its checks
         run, and if its declared verdicts are established afterwards,
         the wave is finished and the method says so. *)
      Printf.printf "next: wave %s - %s\n" wave.Domain.id wave.Domain.title;
      Printf.printf "  the objection it carries: %s\n" wave.Domain.objection;
      Printf.printf "  what would refute it: %s\n" wave.Domain.refuted_by;
      (* The output of the checks follows, and it is theirs, not ours.
         Ours must come first even when both go into one pipe, so ours
         is flushed before the checks run. *)
      flush stdout;
      let failing =
        List.filter
          (fun check ->
            let outcome, _ = Exec.run_check_in ~root:(root ()) check in
            outcome <> Domain.Verified)
          wave.Domain.checks
      in
      if failing <> [] then (
        Printf.printf "  its checks did not pass:\n";
        List.iter (fun c -> Printf.printf "    %s\n" c) failing;
        1)
      else
        let after = states_of claims in
        (* The same criterion the closing uses: every promise met. *)
        let unmet =
          List.filter
            (fun (promise : Domain.commitment) ->
              match List.assoc_opt promise.claim after with
              | Some state -> state <> promise.state
              | None -> true)
            wave.Domain.commitment
        in
        if unmet = [] then (
          Printf.printf "  the wave is finished: its checks pass and every promise is met\n";
          0)
        else (
          Printf.printf
            "  the wave is not finished: %d of its promises are not met\n"
            (List.length unmet);
          List.iter
            (fun (promise : Domain.commitment) ->
              let state = List.assoc_opt promise.claim after in
              Printf.printf "    %s: promised %s, has %s\n" promise.claim
                (Domain.state_name promise.state)
                (match state with
                | Some s -> Domain.state_name s
                | None -> "no such claim"))
            unmet;
          0)
  | [], id :: _, _, _ ->
      Printf.printf "next: the claim %s is refuted - it was believed and is not\n" id;
      0
  | [], [], id :: _, _ ->
      Printf.printf "next: check the claim %s - it is not known now\n" id;
      0
  | [], [], [], first :: _ ->
      Printf.printf "next: nothing is unverified; %d tracked file(s) are uncovered, starting with %s\n"
        (List.length uncovered) first;
      0
  | [], [], [], [] ->
      print_endline "next: nothing to do - every claim is known and everything is covered";
      0

(** close: close a wave.

    A wave declares which verdicts it changes. Closing it means two
    things were true: the wave's checks pass, and the verdicts it
    declared are now established. A wave whose checks fail is not
    closed; a wave that declared a verdict it did not establish is
    not closed either, and the reason says which.

    The comparison is against the DECLARATION, not against the state
    a moment before the checks ran. A wave does work over hours, and
    the verdicts it establishes are established when the work is done,
    not in the second before somebody remembers to close it.

    CLOSING RECORDS THE CLOSURE. A wave that is closed leaves the
    queue: `next` skips it. The closure is written to the standing
    specification, because it is a fact about the work - a unit of work
    is done or it is not - and the specification is committed, so the
    queue is the same for everybody and in every fresh clone. The trail
    is not the place for it: the trail says what ran, and a wave that
    ran is not a wave that finished. *)
let verb_close id =
  let path = Filename.concat (root ()) (Filename.concat "waves" (id ^ ".json")) in
  if not (Sys.file_exists path) then (
    Printf.eprintf "mathc: no wave %S\n" id;
    2)
  else
    match Spec.parse_wave_string (read_file path) with
    | Error e ->
        Printf.eprintf "mathc: the wave is not readable: %s\n" (Spec.message_of e);
        2
    | Ok wave -> (
        let spec = load_spec () in
        (* A wave that is already closed is not an error: closing it
           twice says nothing new, and the method has no reason to make
           the person remember whether they did it. *)
        if List.mem id spec.Domain.closed_waves then (
          Printf.printf "wave %s is already closed\n" id;
          0)
        else
        let claims = spec.Domain.claims in
        let failing =
          List.filter
            (fun check ->
              let outcome, _ = Exec.run_check_in ~root:(root ()) check in
              outcome <> Domain.Verified)
            wave.checks
        in
        if failing <> [] then (
          Printf.eprintf
            "mathc: wave %s is not closed: %d of its checks did not pass\n" wave.id
            (List.length failing);
          List.iter (fun c -> Printf.eprintf "  %s\n" c) failing;
          1)
        else
          let states = states_of claims in
          (* THE PROMISE IS THE CRITERION. A wave says which claims
             will be in which state when it is done, and it closes only
             when every promise is met. The older rule demanded that
             every claim the wave touched end up holding, which could
             not say what a wave whose work disproves something
             promises - and a promise nobody checks is a wish.

             The promise names the state explicitly, so the states are
             compared with the states the claims actually have, and
             the comparison is mechanical. *)
          let unmet =
            List.filter
              (fun (promise : Domain.commitment) ->
                match List.assoc_opt promise.claim states with
                | Some state -> state <> promise.state
                | None -> true)
              wave.Domain.commitment
          in
          if unmet <> [] then (
            Printf.eprintf
              "mathc: wave %s is not closed: %d of its promises are not met\n"
              wave.id (List.length unmet);
            List.iter
              (fun (promise : Domain.commitment) ->
                let state = List.assoc_opt promise.claim states in
                Printf.eprintf "  %s: promised %s, has %s\n" promise.claim
                  (Domain.state_name promise.state)
                  (match state with
                  | Some s -> Domain.state_name s
                  | None -> "no such claim"))
              unmet;
            1)
          else (
            (* The closure is recorded in the standing specification, so
               that the queue moves: `next` skips the closed waves, and
               the progress of the plan survives a fresh clone, because
               the specification is committed and the trail is not. *)
            save_spec { spec with Domain.closed_waves = spec.Domain.closed_waves @ [ id ] };
            Printf.printf "wave %s closed; every promise it made is met:\n" wave.id;
            Printf.printf "  the objection it carried: %s\n" wave.objection;
            Printf.printf "  what would refute it: %s\n" wave.refuted_by;
            List.iter
              (fun (promise : Domain.commitment) ->
                Printf.printf "  %s: %s\n" promise.claim
                  (Domain.state_name promise.state))
              wave.Domain.commitment;
            0))

(** draft: the decisions of the third version, as drafts of claims.

    The old decisions are not ported. What is ported is the mechanical
    part of them - the scope and the verifiers, read off the old file
    without understanding it - and the rest is left to the person who
    owns the claim: the register, the falsifier, and whether the old
    decision is still true at all.

    So the output is a draft, and it says so: the register is left
    undeclared, and the falsifier is a placeholder that must be written
    by hand. A draft that says what to decide is worth more than a
    port that decides. *)
let verb_draft (dir : string) =
  let drafts, skipped = V3.drafts_of dir in
  let skipped_with_verifiers = V3.skipped_of dir in
  let claims =
    List.map
      (fun (c : Domain.claim) ->
        `Assoc
          [
            ("id", `String c.id);
            ("subject", `String c.subject.text);
            ("scope", `List (List.map (fun p -> `String p) c.subject.scope));
            ( "requirements",
              `List
                (List.map
                   (fun (r : Domain.requirement) ->
                     `Assoc
                       (match r with
                       | Domain.Verified_by spec ->
                           [ ("kind", `String "verifier"); ("spec", `String spec) ]
                       | Domain.Reviewed_by spec ->
                           [ ("kind", `String "review"); ("spec", `String spec) ]))
                   c.requirements) );
            ("falsifier", `String c.falsifier);
            ("register", `String "unknown");
          ])
      drafts
  in
  Printf.printf "drafts: %d, skipped: %d\n\n" (List.length drafts)
    (List.length skipped);
  print_endline
    "The register and the falsifier are left to you: a decision is carried across as a\n\
     draft, and a draft decides nothing. The register is unknown - say what kind of\n\
     claim it is.";
  print_endline "";
  print_endline (Yojson.Safe.pretty_to_string (`List claims));
  List.iter
    (fun (name, verifiers) ->
      Printf.printf "skipped %s: no scope" name;
      if verifiers <> [] then
        Printf.printf " (the verifiers it had: %s)" (String.concat ", " verifiers);
      print_newline ())
    skipped_with_verifiers;
  0

(** A requirement, as it is written on the command line: a kind, a
    colon, and the thing itself. The kind is what makes the evidence
    countable - a command and a person are different kinds of
    confirmation, and a rule that asks for both is asking for a
    confirmation that does not come from one place. *)
let parse_requirement (text : string) : (Domain.requirement, string) result =
  match String.index_opt text ':' with
  | None -> Error ("expected verifier:SPEC or review:SPEC, got " ^ text)
  | Some i ->
      let kind = String.sub text 0 i in
      let spec = String.sub text (i + 1) (String.length text - i - 1) in
      if spec = "" then Error "the requirement names nothing"
      else
        match kind with
        | "verifier" -> Ok (Domain.Verified_by spec)
        | "review" -> Ok (Domain.Reviewed_by spec)
        | other -> Error (Printf.sprintf "unknown kind %S: verifier or review" other)

(** The aim. This is the human's move, and the method cannot tell a
    human from an agent at the keyboard - it can only attribute the
    aim and make its changes visible. What it CAN enforce is that the
    aim does not change silently: replacing one needs a reason, and
    the reason is recorded.

    The aim carries a scope, and that scope is the boundary of the
    work: a claim outside it is refused. An agent that optimises
    toward what it can measure must not be able to widen its own field
    of operations. *)
let verb_goal text scope by reason =
  let spec = load_spec () in
  let problem =
    if text = "" then Some "the aim needs a text"
    else if scope = [] then
      Some "the aim needs a scope: an aim about nothing aims at nothing"
    else if reason = "" && spec.goal <> None then
      Some
        "there is already an aim, and replacing it needs a reason: --reason \"...\""
    else None
  in
  match problem with
  | Some why ->
      Printf.eprintf "mathc: %s\n" why;
      2
  | None ->
      let goal =
        { Domain.text; scope; by; at = string_of_int (int_of_float (Unix.time ())) }
      in
      save_spec { spec with goal = Some goal };
      (match spec.goal with
      | Some old ->
          Printf.printf "the aim was replaced, and the reason is recorded:\n";
          Printf.printf "  was: %s\n" old.text;
          Printf.printf "  now: %s\n" goal.text;
          Printf.printf "  reason: %s\n" reason
      | None ->
          Printf.printf "the aim is set:\n  %s\n  by %s\n" goal.text goal.by);
      0

(** Declare a claim. This is the agent's move, and it is where the
    method puts most of its friction - because this is where agents
    make their mistakes.

    The refusals, and why each one is here:

    - no aim: the method does not accept claims before there is
      something to be true about. Work without an aim optimises
      toward whatever happens to be measurable.
    - the scope names nothing: a claim that cannot be bound cannot be
      falsified either, and an unbound claim is the door the third
      version's wildcard came through.
    - the scope is outside the aim: see above.
    - an empty check or an empty falsifier: a promise with no
      procedure and nothing that would refute it is a request, not a
      claim.
    - the identifier is taken: two claims with one name cannot both be
      checked, and the map would lie about one of them.
    - the budget of uncertainty is spent: at that point there are three
      ways out - find a check, ask for authority, or stop - and adding
      a claim is none of them. *)
let verb_add id subject scope requirements falsifier register =
  let spec = load_spec () in
  let refuse why =
    Printf.eprintf "mathc: the claim is not accepted: %s\n" why;
    2
  in
  (* Is the claim inside the aim? The aim's scope is the boundary of
     the work, and an agent that optimises toward what it can measure
     must not be able to widen its own field of operations. *)
  let inside_aim =
    match spec.goal with
    | None -> false
    | Some goal ->
        List.exists
          (fun prefix ->
            List.exists
              (fun claim_prefix -> Domain.path_contains ~dir:prefix ~path:claim_prefix)
              scope)
          goal.Domain.scope
  in
  let problem =
    match spec.goal with
    | None ->
        Some "there is no aim yet. State one first: mathc goal"
    | Some _ ->
        if scope = [] then
          Some "the scope is empty: a claim about nothing is not a claim"
        else if requirements = [] then
          Some "the requirements are empty: a promise with no way to be closed is not a claim"
        else if falsifier = "" then
          Some "the falsifier is empty: nothing would refute this claim"
        else if List.exists (fun (c : Domain.claim) -> c.Domain.id = id) spec.Domain.claims then
          Some (Printf.sprintf "the claim %S already exists" id)
        else if not inside_aim then
          Some
            (Printf.sprintf
               "the scope is outside the aim. The aim covers %s; this claim is about %s"
               (String.concat ", " (match spec.goal with Some g -> g.Domain.scope | None -> []))
               (String.concat ", " scope))
        else if not (Git.scope_exists (root ()) scope) then
          Some
            "the scope names a path that is not in this tree, so the subject would \
             have a hole in it and nothing could be bound to it"
        else
          let consumption = consumption_of spec.Domain.claims in
          if consumption >= spec.Domain.budget then
            Some
              (Printf.sprintf
                 "the uncertainty budget is spent: %d of %d are consumed. Find a check, \
                  ask for authority, or stop"
                 consumption spec.Domain.budget)
          else None
  in
  match problem with
  | Some why -> refuse why
  | None ->
      let register =
        match register with
        | "fact" -> Domain.Fact
        | "hypothesis" -> Domain.Hypothesis
        | "judgment" -> Domain.Judgment
        | "unknown" -> Domain.Undeclared
        | other -> failwith ("unknown register: " ^ other)
      in
      let claim =
        {
          Domain.id;
          subject = { text = subject; scope };
          requirements;
          falsifier;
          register;
          accepted = None;
          attestations = [];
        }
      in
      save_spec { spec with claims = spec.Domain.claims @ [ claim ] };
      Printf.printf "claim %s declared\n" id;
      0

(** accept: a person takes responsibility for one claim's uncertainty.

    This is the second of the three ways out the principle leaves when
    the budget is spent: find a check, ask for authority, or stop. It
    is not an answer - the claim is still not known, and the verdict
    still counts it as unknown - it is a decision about whose problem
    the uncertainty is. The reason is required, because an acceptance
    without one is a shrug with a date on it.

    The acceptance is recorded in the standing specification, so the
    map can show it, and in the trail, so the history of who took
    responsibility for what can be read later. *)
let verb_accept id by reason =
  let spec = load_spec () in
  let problem =
    if by = "" then Some "an acceptance needs a name: who took responsibility"
    else if reason = "" then Some "an acceptance needs a reason"
    else None
  in
  match problem with
  | Some why ->
      Printf.eprintf "mathc: %s\n" why;
      2
  | None -> (
  match List.find_opt (fun (c : Domain.claim) -> c.id = id) spec.Domain.claims with
  | None ->
      Printf.eprintf "mathc: there is no claim %S\n" id;
      2
  | Some claim ->
      let accepted = Some (by, reason) in
      save_spec
        {
          spec with
          claims =
            List.map
              (fun (c : Domain.claim) -> if c.id = id then { c with accepted } else c)
              spec.Domain.claims;
        };
      Printf.printf "claim %s: accepted by %s\n" id by;
      Printf.printf "  %s\n" reason;
      0)

(** init: prepare a project for the method.

    Adoption must cost nothing, and this is what that means in
    practice: one file, with no aim and no claims, so that the first
    thing the method says is "there is nothing to check yet" rather
    than a list of things to fill in. The aim is the person's, and it
    is not set here.

    The file is the PROJECT's own - its specification of itself, in the
    same way a test suite is the project's own. Nothing else is added:
    no scripts, no configuration the project did not ask for, no
    artifact that travels by inertia. *)
let verb_init budget =
  let path = spec_path () in
  if Sys.file_exists path then (
    Printf.eprintf "mathc: there is already a standing specification\n";
    2)
  else (
    save_spec { goal = None; budget; claims = []; closed_waves = [] };
    Printf.printf "the standing specification is created:\n";
    Printf.printf "  %s\n" path;
    Printf.printf "  uncertainty budget: %d\n\n" budget;
    print_endline "next: state the aim (a person does this)";
    print_endline "  mathc goal \"...\" lib/,test/ \"who\"";
    0)

(* ------------------------------------------------------------------ *)

let usage () =
  print_endline "mathc - the protocol of math-coding";
  print_endline "";
  print_endline "  mathc init [BUDGET]      prepare a project; adoption costs one file";
  print_endline "  mathc goal TEXT SCOPE BY      state the aim (a person does this)";
  print_endline "  mathc add ID SUBJECT SCOPE FALSIFIER REGISTER --requirement verifier:CMD";
  print_endline "                               declare a claim (an agent does this);";
  print_endline "                               --requirement may be repeated, and may be review:WHO;";
  print_endline "                               a claim without a requirement is refused";
  print_endline "  mathc accept ID BY REASON      a person takes responsibility for an uncertainty";
  print_endline "  mathc map               the standing specification: claims, states, uncovered";
  print_endline "  mathc route             what needs a person, and why";
  print_endline "  mathc run                execute the checks, bind the results, write the trail";
  print_endline "  mathc record CLAIM REQ --by WHO --outcome V";
  print_endline "                               take evidence from outside: a person, a CI run;";
  print_endline "                               --valid-for DAYS says how long the proof counts";
  print_endline "  mathc next               the next work, one item";
  print_endline "  mathc close WAVE         close a wave whose verdicts changed";
  print_endline "  mathc draft DIR          the third version's decisions, as draft claims";
  print_endline "";
  print_endline "  --root DIR               the project (default: the working directory)";
  print_endline "  --reason TEXT            why an aim is being replaced";
  print_endline "  --json                   the map as data, for programs"

(** The command line. The only options are the project root and the
    reason an aim is being replaced; everything else is a verb. An
    unknown option is an error rather than a verb, because a typo that
    silently becomes a verb is a method that reports something the
    user did not ask for. *)
let parse_args (args : string list) :
    string list * string * bool * string * string * string * string * string list =
  let root_flag = ref "" in
  let reason = ref "" in
  let json = ref false in
  let by = ref "" in
  let recorded_outcome = ref "verified" in
  let recorded_reason = ref "" in
  let valid_for = ref "" in
  let requirements = ref [] in
  let rec loop acc = function
    | [] -> (List.rev acc, !reason, !json)
    | "--root" :: dir :: rest ->
        root_flag := dir;
        loop acc rest
    | "--root" :: [] ->
        Printf.eprintf "mathc: --root needs a directory\n";
        exit 2
    | "--reason" :: text :: rest ->
        (* ONE FLAG, TWO USES, AND NEITHER MAY BE LOST. The reason
           belongs to the aim that is being replaced, and to the proof
           that is being recorded. They are never used together - one
           verb at a time - and before this the flag filled only the
           first of the two, so a recorded proof kept no reason at all
           and said nothing about it. *)
        reason := text;
        recorded_reason := text;
        loop acc rest
    | "--by" :: text :: rest ->
        by := text;
        loop acc rest
    | "--outcome" :: text :: rest ->
        recorded_outcome := text;
        loop acc rest
    | "--valid-for" :: text :: rest ->
        (* How long the proof counts. The content may be exactly the
           right one and the proof still too old to stand: the
           deployment moved, the dependency changed, the review was for
           a release that is over. The term is what says so. *)
        valid_for := text;
        loop acc rest
    | "--requirement" :: text :: rest ->
        (* The requirements of a claim. They are named on the command
           line, because a requirement is the way a claim is closed and
           it must be said out loud: a command that exits zero and a
           person who looked are different kinds of confirmation.

           This branch was MISSING once, and the flag was documented in
           the usage text while the parser dropped it on the floor. The
           consequence was that `add` could never be given a
           requirement, so it refused every claim with "the requirements
           are empty", and the only way to declare a claim was to edit
           the specification by hand. The defect was invisible because
           the usage text said the flag worked, and a usage text is a
           description, not a check. *)
        requirements := text :: !requirements;
        loop acc rest
    | "--json" :: rest ->
        json := true;
        loop acc rest
    | "--requirement" :: [] ->
        Printf.eprintf "mathc: --requirement needs a requirement\n";
        exit 2
    | "--reason" :: [] ->
        Printf.eprintf "mathc: --reason needs a text\n";
        exit 2
    | "--valid-for" :: [] ->
        Printf.eprintf "mathc: --valid-for needs a number of days\n";
        exit 2
    | ("-" | "--") :: _ ->
        Printf.eprintf "mathc: unknown option\n";
        exit 2
    | a :: rest -> loop (a :: acc) rest
  in
  let positional, reason, json = loop [] args in
  if !root_flag <> "" then set_root !root_flag;
  ( positional,
    reason,
    json,
    !by,
    !recorded_outcome,
    !recorded_reason,
    !valid_for,
    List.rev !requirements )

(** A comma-separated list of paths. The scope of a claim is a list of
    path prefixes, and the list is written the way a shell would write
    it: comma-separated. *)
let split_scope (text : string) : string list =
  String.split_on_char ',' text |> List.map String.trim |> List.filter (fun s -> s <> "")

let () =
  let positional, reason, json, by, recorded_outcome, recorded_reason, valid_for,
      requirements =
    parse_args (Array.to_list Sys.argv |> List.tl)
  in
  match positional with
  | [] | [ "--help" ] | [ "-h" ] ->
      usage ();
      exit 0
  | verb :: _ -> (
      (* A flag that belongs to one verb and is accepted by another is a
         flag that is silently ignored, and a method that ignores what
         it was told reports something the user did not ask for. *)
      if verb <> "add" && requirements <> [] then (
        Printf.eprintf "mathc: --requirement belongs to add\n";
        exit 2);
      let code =
        match verb with
        | "goal" -> (
            match positional with
            | _ :: text :: scope :: by :: _ ->
                verb_goal text (split_scope scope) by reason
            | _ ->
                Printf.eprintf "mathc: goal needs TEXT SCOPE BY\n";
                2)
        | "add" -> (
            match positional with
            | _ :: id :: subject :: scope :: falsifier :: register :: _ ->
                let rec parse_all acc = function
                  | [] -> Ok (List.rev acc)
                  | text :: rest -> (
                      match parse_requirement text with
                      | Ok r -> parse_all (r :: acc) rest
                      | Error e -> Error e)
                in
                (match parse_all [] requirements with
                | Error e ->
                    Printf.eprintf "mathc: %s\n" e;
                    2
                | Ok rs ->
                    verb_add id subject (split_scope scope) rs falsifier register)
            | _ ->
                Printf.eprintf
                  "mathc: add needs ID SUBJECT SCOPE CHECK FALSIFIER REGISTER\n";
                2)
        | "init" -> (
            match positional with
            | _ :: budget :: _ -> (
                match int_of_string_opt budget with
                | Some b when b >= 0 -> verb_init b
                | _ ->
                    Printf.eprintf "mathc: the budget must be a non-negative integer\n";
                    2)
            | _ -> verb_init 3)
        | "accept" -> (
            match positional with
            | _ :: id :: by :: reason :: _ -> verb_accept id by reason
            | _ ->
                Printf.eprintf "mathc: accept needs ID BY REASON\n";
                2)
        | "map" -> verb_map json
        | "route" -> verb_route ()
        | "run" -> verb_run ()
        | "record" -> (
            match positional with
            | _ :: claim_id :: spec :: _ ->
                verb_record claim_id spec by recorded_outcome recorded_reason
                  valid_for
            | _ ->
                Printf.eprintf
                  "mathc: record needs CLAIM REQUIREMENT --by WHO --outcome OUTCOME\n";
                2)
        | "next" -> verb_next ()
        | "draft" -> (
            match positional with
            | _ :: dir :: _ -> verb_draft dir
            | _ ->
                Printf.eprintf "mathc: draft needs a directory with decisions/\n";
                2)
        | "close" -> (
            match positional with
            | _ :: id :: _ -> verb_close id
            | _ ->
                Printf.eprintf "mathc: close needs a wave id\n";
                2)
        | other ->
            Printf.eprintf "mathc: unknown verb %S\n" other;
            usage ();
            2
      in
      exit code)
