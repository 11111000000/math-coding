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

(** The options of one invocation.

    A record and not a tuple of nine: the tool has fifteen options now,
    and a tuple of fifteen is a tuple somebody reads wrong. The fields
    are mutable because the parser fills them in one at a time, and a
    parser that returned a finished record would have to build it in
    fifteen places. *)
type options = {
  mutable root : string;
  mutable reason : string;
  mutable json : bool;
  mutable version : bool;
  mutable by : string;
  mutable outcome : string;
  mutable control : string;
  mutable valid_for : string;
  mutable requirements : string list;
  (* The wave's own fields. The wave carries the reasoning of the plan
     and the objection against it, and a verb that cannot say those is
     a verb that cannot create a wave. *)
  mutable intent : string;
  mutable objection : string;
  mutable refuted_by : string;
  mutable checks : string list;
  mutable claims : string list;
  mutable commitments : string list;
  mutable touches : string list;
}

let read_file path =
  let channel = open_in path in
  let content = In_channel.input_all channel in
  close_in channel;
  content

(* ------------------------------------------------------------------ *)
(* The standing specification and the trail.                            *)
(* ------------------------------------------------------------------ *)

let spec_path () = Filename.concat (root ()) "spec.json"

(** The standing specification of THIS project.

    THE MISSING SPECIFICATION WAS A GREEN VERDICT. When there was no
    spec.json, the loader returned an empty specification - no aim, no
    claims, no waves - and the map then computed a verdict over it and
    printed "green". A directory that is not a project of the method
    was therefore reported as a project with nothing wrong with it, and
    the agent that asked got a clean bill of health for a tree it had
    never looked at.

    That is the false green, and it is the worst kind of lie this
    method could tell: it is not a wrong answer to the question asked,
    it is a right answer to a question nobody asked. The empty project
    is green - that is the law of vacancy, and it is about a project
    that says so. A directory with no specification says nothing, and
    about it the method cannot tell.

    So the answer is not an empty specification but no answer: the
    method says that there is no standing specification here, and it
    exits with the code of "we could not tell" - three, never zero. *)
let load_spec () : Domain.spec =
  let path = spec_path () in
  if not (Sys.file_exists path) then (
    Printf.eprintf
      "mathc: there is no standing specification here: this is not a project of the \
       method (mathc init)\n";
    exit 3)
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
    checked at all, is not.

    A PLAN IS NOT AN UNCERTAINTY. A promise about code that is not there
    yet is not a thing the method could have checked, and it is not
    resolved by checking it either - it is resolved by writing the
    code. So it does not cost the budget. The exception matters: a
    scope that covers code that IS there, and also names a path that is
    not, is priced as usual - the uncertainty about the code that
    exists is real, and the hole does not make it free.

    And this cannot be used to escape the budget: a promise about
    nothing that exists covers no files, so it hides no file and
    settles no question. The map still shows it, and it still has to be
    checked once there is something to check. *)
let consumption_of (claims : Domain.claim list) : int =
  let states = states_of claims in
  let claim_of id = List.find_opt (fun (c : Domain.claim) -> c.id = id) claims in
  let covers (c : Domain.claim) = Git.files_covered (root ()) c.subject.scope <> [] in
  List.fold_left
    (fun n (id, state) ->
      match claim_of id with
      | Some c -> n + Verdict.cost_of_claim ~covers c state
      | None -> n)
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
  let uncovered = Git.uncovered (root ()) claims files in
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
                   ( "control",
                     match
                       List.find_opt
                         (fun (c : Domain.claim) -> c.id = id)
                         claims
                     with
                     | Some c -> (
                         match c.control with
                         | Some _ -> `String "the check is proven able to fail"
                         | None ->
                             `String
                               "the check is not proven able to fail: declare its control")
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
                          if Verdict.expired (Unix.time ()) e.valid_until then `String "the term is over"
                          else `String "the subject moved"
                      | _ -> `Null );
                    (* WHY the subject cannot be bound. A plan about code
                       that is not there yet is not the same thing as a
                       claim nobody checked, and the machine form of the
                       map says which is which. *)
                    ( "subject",
                      match
                        List.find_opt (fun (c : Domain.claim) -> c.id = id) claims
                      with
                      | Some c -> (
                          match Git.missing_paths (root ()) c.subject.scope with
                          | [] -> `Null
                          | missing ->
                              `String
                                (if List.length missing = List.length c.subject.scope then
                                   "the subject is not there yet"
                                 else "the subject has a hole"))
                      | None -> `Null ) ])

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
    let uncovered = Git.uncovered (root ()) claims files in
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
              if Verdict.expired (Unix.time ()) e.valid_until then " (the term is over)"
              else " (the subject moved)"
          | _ -> ""
        in
        (* THE CHECK THAT WAS NOT SHOWN ABLE TO FAIL. The map said
           this in its machine form for a long time - `map --json` has a
           field for it - and the human map did not, so the two forms of
           the same map disagreed about the same claim. A claim whose
           check has never been shown to fail is NOT the same claim as
           one whose check has: the first is a promise, the second is a
           proof, and the map that merges them reports a promise as a
           proof.

           The law is A16: a check that cannot fail proves nothing.
           The control is what shows it can. So the map says which is
           which, in the same breath as the state. *)
        let control_note =
          match List.find_opt (fun (c : Domain.claim) -> c.id = id) claims with
          | Some c -> (
              match c.Domain.control with
              | Some _ -> ""
              | None -> " (the check is not proven able to fail)")
          | None -> ""
        in
        (* WHY the check could not tell. An inconclusive claim without
           its reason is a shrug with a state attached. *)
        let reason_note =
          match state with
          | Domain.Inconclusive -> (
              match
                List.find_opt
                  (fun (e : Domain.evidence) ->
                    e.claim.id = id
                    && (match e.outcome with
                       | Domain.Unresolved | Domain.Refused -> true
                       | _ -> false))
                  (latest_evidence claims)
              with
              | Some e -> (
                  match e.reason with
                  | Some r -> " (" ^ r ^ ")"
                  | None -> "")
              | None -> "")
          | _ -> ""
        in
        (* THE SUBJECT THAT IS NOT THERE YET. A claim about code that
           does not exist yet is a plan, and the map says so - it does
           not leave the reader to guess whether the claim is unchecked
           or impossible. The word "never checked" alone would say both
           at once, and a reader who has to guess is a reader who
           guesses wrong. *)
        let subject_note =
          match List.find_opt (fun (c : Domain.claim) -> c.id = id) claims with
          | Some c -> (
              match Git.missing_paths (root ()) c.subject.scope with
              | [] -> ""
              | missing ->
                  " ("
                  ^ (if List.length missing = List.length c.subject.scope then
                       "the subject is not there yet"
                     else "the subject has a hole")
                  ^ ")")
          | None -> ""
        in
        Printf.printf "  %-24s %s%s%s%s%s%s\n" id
          (match state with
          | Domain.Holds -> "holds"
          | Domain.Refuted -> "refuted"
          | Domain.Inconclusive -> "inconclusive"
          | Domain.NotCheckable -> "not checkable"
          | Domain.Outdated -> "outdated"
          | Domain.NeverChecked -> "never checked"
          | Domain.Accepted -> "accepted by a person")
          anchor why subject_note control_note reason_note)
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
              (* No digest: the subject is not there yet, or it has a
                 hole. Both are said in words, because the reader acts
                 differently in each - write it, or finish it - and a
                 bare "no digest" is a shrug. *)
              Printf.printf "%s: %s\n" claim.id
                (Git.why_no_digest (root ()) claim.subject.scope);
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
                      (* THE NEGATIVE CONTROL OF THE CHECK. A check that
                         passes proves nothing until it is shown that it
                         CAN fail. The claim carries the command that
                         shows it - a test over a broken fixture - and
                         that command must fail. If the check still
                         passes where it had to fail, then it cannot
                         see the subject, and the proof is no proof:
                         the claim is not established, and it says
                         why.

                         This is the rule the method has always kept
                         for its own tests, now kept for the claims of
                         the projects that adopt it. The limit: the
                         method sees that the control passed and not
                         why it passed - the same way it cannot see
                         what a check checks, only whether it can
                         fail. *)
                      let outcome, reason =
                        match (outcome, claim.control) with
                        | Domain.Verified, Some control ->
                            let code = Exec.exit_code_of ~root:(root ()) control in
                            if code = 0 then
                              ( Domain.Unresolved,
                                Some
                                  "the check passed where its negative control had to fail: \
                                   it cannot see the subject" )
                            else (outcome, reason)
                        | _ -> (outcome, reason)
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
  let uncovered = Git.uncovered (root ()) claims files in
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
      (* THE NEXT WORK IS NOT ALWAYS "CHECK IT". A claim whose subject
         is not there yet cannot be checked - the next work is to WRITE
         it. Telling the agent to check a thing that does not exist is
         how a queue leads an agent in a circle. *)
      let claim = List.find_opt (fun (c : Domain.claim) -> c.id = id) claims in
      (match claim with
      | Some c -> (
          match Git.missing_paths (root ()) c.subject.scope with
          | [] ->
              Printf.printf "next: check the claim %s - it is not known now\n" id
          | missing ->
              Printf.printf
                "next: write the subject of the claim %s - missing: %s\n" id
                (String.concat ", " missing))
      | None -> Printf.printf "next: check the claim %s - it is not known now\n" id);
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

(** A wave, as data.

    The writer lives here and not in the codec, for the same reason the
    map's writer lives here: the codec says how the outside is shaped,
    and the things the protocol writes are the protocol's own. The
    codec's ceiling is a decision that was made before this code
    existed, and the answer to "the codec outgrew its ceiling" is to
    move code out of it, not to move the ceiling.

    What matters is that the writer and the reader are one pair: the
    wave the verb writes is read back by the same codec, so a wave that
    cannot be read cannot be written either. *)
let wave_to_json (w : Domain.wave) : Yojson.Safe.t =
  `Assoc
    [ ("id", `String w.Domain.id);
      ("title", `String w.Domain.title);
      ("intent", `String w.Domain.intent);
      ("touches", `List (List.map (fun p -> `String p) w.Domain.touches));
      ("checks", `List (List.map (fun c -> `String c) w.Domain.checks));
      ("claims", `List (List.map (fun c -> `String c) w.Domain.claims));
      ( "commitment",
        `List
          (List.map
             (fun (c : Domain.commitment) ->
               `Assoc
                 [ ("claim", `String c.Domain.claim);
                   ("state", `String (Domain.state_name c.Domain.state)) ])
             w.Domain.commitment) );
      ("objection", `String w.Domain.objection);
      ("refuted_by", `String w.Domain.refuted_by) ]

(** wave: create a unit of work.

    THE WAVE WAS WRITE-ONLY. `next` reads the waves, `close` reads
    them, and NOTHING created them: the only way to make one was to
    write the JSON by hand. In this repository that was survivable -
    the waves here were made exactly that way - but in a foreign
    project the mechanism was simply unusable: the queue would never
    name a wave, and closing one would answer "no wave" for ever.

    So the wave is a verb now. And it keeps the discipline of the
    format rather than softening it: a wave without its reasoning, or
    without the objection against it, or without a check that must
    pass, or without a promise that can be checked, is not a wave, and
    the verb refuses it. The friction belongs here: this is where an
    agent that wants to skip the dialectic tries to skip it.

    And the promise must name a claim that is declared. A wave that
    promises a claim nobody declared can never close - the closing
    compares the promise with the state of the claim - so it would sit
    in the queue for ever, and the queue would be lying about what it
    leads to. *)
let verb_wave (id : string) (title : string) (o : options) =
  let refuse why =
    Printf.eprintf "mathc: the wave is not created: %s\n" why;
    2
  in
  let spec = load_spec () in
  let rec parse_commit acc = function
    | [] -> Ok (List.rev acc)
    | text :: rest -> (
        match String.index_opt text '=' with
        | None -> Error (Printf.sprintf "a promise is CLAIM=STATE; got %S" text)
        | Some i ->
            let claim = String.sub text 0 i in
            let state = String.sub text (i + 1) (String.length text - i - 1) in
            (match Spec.state_of_name state with
            | Some s -> parse_commit ({ Domain.claim; state = s } :: acc) rest
            | None -> Error (Printf.sprintf "%S is not a state of a claim" state)))
  in
  let problem =
    if id = "" then Some "the wave needs an id"
    else if String.contains id '/' || String.contains id '\\' then
      Some "the id of a wave is a name, not a path"
    else if title = "" then Some "the wave needs a title"
    else if o.intent = "" then
      Some "the wave needs an intent: why this unit of work and what it assumes"
    else if o.objection = "" then
      Some "the wave needs the strongest objection against this approach"
    else if o.refuted_by = "" then
      Some
        "the wave needs what would refute it: an objection with no answer is a \
         complaint, and a complaint is not a plan"
    else if o.checks = [] then
      Some "the wave needs at least one check: a wave that runs nothing is a wish"
    else if o.commitments = [] then
      Some
        "the wave needs at least one promise: a wave that promises nothing is not \
         a unit of work"
    else None
  in
  match problem with
  | Some why -> refuse why
  | None -> (
      match parse_commit [] o.commitments with
      | Error e -> refuse e
      | Ok commitments ->
          let unknown =
            List.filter_map
              (fun (c : Domain.commitment) ->
                if List.exists (fun (x : Domain.claim) -> x.id = c.claim) spec.Domain.claims
                then None
                else Some c.claim)
              commitments
          in
          (match unknown with
          | claim :: _ ->
              refuse
                (Printf.sprintf
                   "the wave promises the claim %S, which is not declared: a promise \
                    about a claim nobody declared can never be met"
                   claim)
          | [] ->
              let dir = Filename.concat (root ()) "waves" in
              let path = Filename.concat dir (id ^ ".json") in
              if Sys.file_exists path then
                refuse (Printf.sprintf "there is already a wave %S" id)
              else (
                if not (Sys.file_exists dir) then Unix.mkdir dir 0o755;
                (* The claims the wave touches are the claims it promises,
                   unless it says otherwise: a wave that names them is
                   saying what it is about. *)
                let claims =
                  if o.claims <> [] then o.claims
                  else
                    List.map
                      (fun (c : Domain.commitment) -> c.Domain.claim)
                      commitments
                in
                let wave =
                  {
                    Domain.id;
                    title;
                    intent = o.intent;
                    touches = o.touches;
                    checks = o.checks;
                    claims;
                    commitment = commitments;
                    objection = o.objection;
                    refuted_by = o.refuted_by;
                  }
                in
                (* THE WRITER PROVES ITSELF BY THE READER. The wave is
                   written and read back with the same codec: a wave
                   that cannot be read cannot stand, and saying so here
                   is better than a queue full of unreadable waves. *)
                let json = wave_to_json wave in
                let text = Yojson.Safe.pretty_to_string json ^ "\n" in
                (match Spec.parse_wave_string text with
                | Error e ->
                    refuse ("the wave is not readable: " ^ Spec.message_of e)
                | Ok _ ->
                    let channel = open_out path in
                    output_string channel text;
                    close_out channel;
                    Printf.printf "wave %s created:\n" id;
                    Printf.printf "  %s\n" path;
                    Printf.printf "  promises: %s\n"
                      (String.concat ", "
                         (List.map
                            (fun (c : Domain.commitment) ->
                              c.Domain.claim ^ " " ^ Domain.state_name c.Domain.state)
                            commitments));
                    Printf.printf "  checks: %s\n" (String.concat ", " o.checks);
                    print_endline
                      "next: mathc next names the wave, and mathc close closes it when \
                       its promises are met";
                    0))))

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
          (* The reason is RECORDED, not only printed: a reason that
             lives in the output of one process is a reason nobody can
             check. *)
          Trail.append_act (root ()) "goal"
            [ ("was", old.text); ("now", goal.text); ("by", goal.by);
              ("reason", reason) ];
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
let verb_add id subject scope requirements falsifier register control =
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
              (fun claim_prefix -> Git.path_contains ~dir:prefix ~path:claim_prefix)
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
          control = (if control = "" then None else Some control);
        }
      in
      save_spec { spec with claims = spec.Domain.claims @ [ claim ] };
      Printf.printf "claim %s declared\n" id;
      (* THE SUBJECT MAY NOT BE THERE YET, AND THAT IS NOT A REFUSAL.
         A promise about code that does not exist yet is a plan, and a
         plan is a legitimate thing to write down - it is how a project
         says what it is going to build before it builds it. What the
         method will not do is pretend the plan is proven: nothing can
         be bound to a subject that is not there, so the claim stays
         unknown, and the map says which of the two it is.

         The refusal that used to stand here made the method unusable
         in an empty repository: the first claim of a greenfield
         project could not be declared, and the project whose empty
         state the method calls legal could never leave it. *)
      let missing = Git.missing_paths (root ()) scope in
      if missing <> [] then (
        Printf.printf "  %s\n" (Git.why_no_digest (root ()) scope);
        print_endline
          "  nothing can be bound to it yet; write the subject and run the check");
      0

(** budget: the price of uncertainty, changed by a person.

    THE BUDGET COULD NOT BE CHANGED. It was set once, by `init`, and
    then it stood for ever - and a project that grows past its first
    three uncertainties had no way to say so except by editing the
    specification by hand. That is exactly the friction the method
    keeps elsewhere: the aim needs a reason to be replaced, and the
    budget needed the same and had none.

    So the budget is a verb, and it is the person's verb: a number and
    a reason. The number stands in the specification, which is
    committed; the reason is written to the trail, which is the
    method's record of acts - and the limit of that place is named
    there: the trail is not committed, so a reason does not survive a
    fresh clone. *)
let verb_budget (budget : int) (reason : string) =
  let spec = load_spec () in
  if reason = "" then (
    Printf.eprintf
      "mathc: the budget is not changed: it needs a reason, because a budget nobody        explained is a number with no owner\n";
    2)
  else if budget < 0 then (
    Printf.eprintf "mathc: the budget must not be negative\n";
    2)
  else
    let was = spec.Domain.budget in
    save_spec { spec with Domain.budget = budget };
    Trail.append_act (root ()) "budget"
      [ ("was", string_of_int was); ("now", string_of_int budget);
        ("reason", reason) ];
    Printf.printf "the uncertainty budget is %d, and the reason is recorded:\n" budget;
    Printf.printf "  was: %d\n" was;
    Printf.printf "  reason: %s\n" reason;
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

(** The help, as text.

    It is a value and not a printing, because the page for agents is
    made of it: the page must name every verb the tool has, and the
    only way to be sure of that is to take the verbs from the same
    place the reader takes them. A second list of the verbs, kept by
    hand, would be a second truth - and the method has been bitten by
    exactly that. *)
let usage_text () =
  String.concat "\n"
    [
      "mathc - the protocol of math-coding";
      "";
      "  mathc init [BUDGET]      prepare a project; adoption costs one file";
      "  mathc goal TEXT SCOPE BY      state the aim (a person does this)";
      "  mathc add ID SUBJECT SCOPE FALSIFIER REGISTER --requirement verifier:CMD";
      "                               declare a claim (an agent does this);";
      "                               --requirement may be repeated, and may be review:WHO;";
      "                               --control CMD is the command that breaks the subject";
      "                                 and must fail with it: a check that cannot fail proves nothing";
      "                               a claim without a requirement is refused";
      "  mathc accept ID BY REASON      a person takes responsibility for an uncertainty";
      "  mathc budget N            the price of uncertainty, changed by a person;";
      "                               --reason says why";
      "  mathc map               the standing specification: claims, states, uncovered";
      "  mathc route             what needs a person, and why";
      "  mathc run                execute the checks, bind the results, write the trail";
      "  mathc record CLAIM REQ --by WHO --outcome V";
      "                               take evidence from outside: a person, a CI run;";
      "                               --valid-for DAYS says how long the proof counts";
      "  mathc next               the next work, one item";
      "  mathc wave ID TITLE     create a unit of work: a wave";
      "                               --intent WHY --objection THE STRONGEST OBJECTION";
      "                               --refuted-by WHAT WOULD REFUTE IT";
      "                               --check CMD (may be repeated)";
      "                               --commit CLAIM=STATE (may be repeated)";
      "                               --claim ID and --touches PATH may be repeated";
      "  mathc close WAVE         close a wave whose verdicts changed";
      "  mathc draft DIR          the third version's decisions, as draft claims";
      "  mathc install            write the page for agents into this project";
      "  mathc mcp                the machine surface for agents: JSON-RPC over stdio";
      "  mathc propose            drafts of claims for a project that has code and none";
      "                               --check CMD may be repeated: the project's own checks";
      "  mathc doctor             check that this project is set up for the method";
      "";
      "  --root DIR               the project (default: the working directory)";
      "  --reason TEXT            why an aim is being replaced";
      "  --json                   the map as data, for programs";
      "  --version                the version and the build-id of this binary";
    ]

let usage () = print_endline (usage_text ())

(** THE PAGE FOR AGENTS.

    THE PAGE NEVER REACHED ANYBODY. It travelled with the portable
    binary as `share/math-coding/AGENTS.md` - a path that nobody put
    anywhere - and the only way it ever got into a project was a human
    copying it by hand. The measurement of 2026-11-07 says so in three
    words: "AGENTS.md - в руку A". And the page that was copied was
    written for THIS repository: it names `lib/`, `format/`, `adapter/`,
    `bin/`, `test/`, `waves/*.json` and `spec.json`, and tells an agent
    to run `nix develop` and `dune runtest --root . --force`. Copied
    into a Python project, it names a tree that is not there.

    So the page is GENERATED, and it is generated out of two things
    that cannot drift: the tool's own help - so it cannot name a verb
    that does not exist - and the standing specification - so it is
    about THIS project, its aim, its claims and its checks. The page is
    never a copy of anything.

    And it is written in the tool's language, English, because the
    mechanical parts of it are the tool's own words. The project's own
    prose stays where it is: the aim and the claims are quoted as they
    were written. *)
let entry_page () =
  let spec = load_spec () in
  let states = states_of spec.Domain.claims in
  let b = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  add "## math-coding in this project\n\n";
  add "This block is written by `mathc install` and by nothing else.\n";
  add "Everything outside it belongs to the project and is never touched.\n";
  add "Re-run `mathc install` after the specification changes;\n";
  add "`mathc doctor` says whether this block is current.\n\n";
  add "### The aim\n\n";
  (match spec.Domain.goal with
  | Some g ->
      add "%s\n\n" g.Domain.text;
      add "Stated by %s, over %s.\n\n" g.Domain.by
        (String.concat ", " g.Domain.scope)
  | None ->
      add
        "There is no aim yet. The aim belongs to a person, and it is the boundary\n\
         of the work:\n\n```sh\nmathc goal \"...\" SCOPE \"who\"\n```\n\n");
  add "### The verbs\n\n```sh\n";
  Buffer.add_string b (usage_text ());
  add "```\n\n";
  add "### What is declared\n\n";
  if spec.Domain.claims = [] then
    add
      "Nothing is declared yet, and that is a legal state, not a defect. The map\n\
       says so:\n\n```sh\nmathc --root . map\n```\n\n"
  else (
    add "| claim | state | how it is closed |\n|---|---|---|\n";
    List.iter
      (fun (id, state) ->
        let checks =
          match List.find_opt (fun (c : Domain.claim) -> c.id = id) spec.Domain.claims with
          | Some c ->
              String.concat "; "
                (List.map
                   (fun (r : Domain.requirement) ->
                     match r with
                     | Domain.Verified_by spec -> "`" ^ spec ^ "`"
                     | Domain.Reviewed_by who -> "review by " ^ who)
                   c.Domain.requirements)
          | None -> ""
        in
        add "| `%s` | %s | %s |\n" id (Domain.state_name state) checks)
      states;
    add "\n");
  add "### If you are an agent here\n\n";
  add
    "1. Start with the map: `mathc --root . map` - what is claimed, what is known,\n\
    \   what is not covered. The map never refuses.\n";
  add
    "2. Declare what you are working on: `mathc --root . add <id> \"<subject>\" \\\n\
    \   \"<scopes, comma-separated>\" \"<what would refute it>\" <register> \\\n\
    \   --requirement \"verifier:<command>\" --control \"<command>\"`. The control is\n\
    \   the command that breaks the subject and must fail with it: a check that\n\
    \   cannot fail proves nothing, and the map says whose check is proven able\n\
    \   to fail.\n";
  add
    "3. Run the checks: `mathc --root . run` - the method runs them and binds every\n\
    \   proof to the content it ran against.\n";
  add
    "4. Make a unit of work: `mathc --root . wave <id> \"<title>\" --intent \"...\" \\\n\
    \   --objection \"...\" --refuted-by \"...\" --check \"<command>\" \\\n\
    \   --commit \"<claim>=<state>\"`, and close it with `mathc --root . close\n\
    \   <wave>` when its promises are met.\n";
  add
    "5. If the map says there is no uncertainty left and nothing uncovered, the\n\
    \   right move is to say that there is nothing to improve. Recursion without\n\
    \   the right to stop is not self-improvement, it is cancer.\n";
  Buffer.contents b

(** The markers of the block the tool owns. Everything outside them is
    the project's, and the tool never touches it. *)
let block_begin = "<!-- math-coding:begin -->"
let block_end = "<!-- math-coding:end -->"

(** Put the block into the text, replacing the old one if it is there.

    A project that has its own AGENTS.md keeps it: the tool owns a
    marked span and writes nothing outside it. A page that names a verb
    the tool no longer has is worse than no page - the agent follows it
    into a verb that does not exist - and that is why the block is
    rewritten rather than left. *)
let with_block (text : string) (block : string) : string =
  match Git.index_of text block_begin with
  | None -> (if text = "" then block ^ "\n" else text ^ "\n" ^ block ^ "\n")
  | Some i -> (
      match Git.index_from text (i + String.length block_begin) block_end with
      | None -> text ^ "\n" ^ block ^ "\n"
      | Some j ->
          let head = String.sub text 0 i in
          let tail =
            String.sub text (j + String.length block_end)
              (String.length text - j - String.length block_end)
          in
          head ^ block ^ tail)

(** install: put the page for agents into the project.

    It writes one file - or one marked block in a file that is already
    there - and it writes nothing else. The method adds no artifact to
    a project by inertia: the page is asked for, and `doctor` can take
    it away again by saying it is not there. *)
let verb_install () =
  let spec_path = spec_path () in
  if not (Sys.file_exists spec_path) then (
    Printf.eprintf
      "mathc: there is no standing specification here: this is not a project of the \
       method (mathc init)\n";
    3)
  else
    let path = Filename.concat (root ()) "AGENTS.md" in
    let existing = if Sys.file_exists path then Some (read_file path) else None in
    let block = block_begin ^ "\n" ^ entry_page () ^ block_end in
    let text = with_block (match existing with Some t -> t | None -> "") block in
    let channel = open_out path in
    output_string channel text;
    close_out channel;
    Printf.printf "the page for agents is written:\n  %s\n" path;
    (match existing with
    | Some _ ->
        Printf.printf
          "  the block between the markers was rewritten; the rest of the file is \
           untouched\n"
    | None -> Printf.printf "  the file is new\n");
    print_endline "  check it: mathc doctor";
    0

(** The verbs of the tool, as its own help names them. The page has to
    name every one of them: a page that names a verb the tool does not
    have sends an agent into a verb that is not there, and a page that
    omits one hides a tool the agent needed. *)
let verbs_of_help (help : string) : string list =
  help
  |> String.split_on_char '\n'
  |> List.filter_map (fun line ->
         let trimmed = String.trim line in
         if String.length trimmed > 6 && String.sub trimmed 0 6 = "mathc " then
           let rest = String.sub trimmed 6 (String.length trimmed - 6) in
           match String.index_opt rest ' ' with
           | Some i -> Some (String.sub rest 0 i)
           | None -> Some rest
         else None)

(** Does the text contain the word, and not a longer word with it
    inside? "init" must not be found in "initialise". *)
let contains_word (haystack : string) (needle : string) =
  let n = String.length haystack and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  let is_word_char c =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
    || c = '_'
  in
  while (not !found) && !i + m <= n do
    let at = !i in
    if String.sub haystack at m = needle then (
      let before_ok = at = 0 || not (is_word_char haystack.[at - 1]) in
      let after = at + m in
      let after_ok = after >= n || not (is_word_char haystack.[after]) in
      if before_ok && after_ok then found := true);
    i := !i + 1
  done;
  !found

(** doctor: is this project set up for the method?

    It changes nothing. It says what is missing, what is stale and what
    cannot be told, and it distinguishes the three: a thing that is
    wrong is red, a thing that is not there yet cannot be told, and a
    thing that is in order is silent. *)
let verb_doctor () =
  let broken = ref 0 in
  let unknown = ref 0 in
  let ok what = Printf.printf "  ok      %s\n" what in
  let bad what =
    Printf.printf "  wrong   %s\n" what;
    incr broken
  in
  let cannot what =
    Printf.printf "  unknown %s\n" what;
    incr unknown
  in
  Printf.printf "the method, checking %s\n\n" (root ());
  (* The tree. The method binds proofs to the content of a tree, and
     there is no tree without git. *)
  if Git.is_repository (root ()) then ok "this is a git repository"
  else cannot "this is not a git repository: the method binds proofs to a tree";
  (* The specification, and everything that needs one. *)
  if Sys.file_exists (spec_path ()) then (
    ok "the standing specification is there";
    let spec = load_spec () in
    (* The aim. *)
    (match spec.Domain.goal with
    | Some _ -> ok "the aim is stated"
    | None -> cannot "there is no aim: mathc goal");
    (* The page for agents. *)
    let path = Filename.concat (root ()) "AGENTS.md" in
    if not (Sys.file_exists path) then
      bad "there is no page for agents: mathc install"
    else (
      let text = read_file path in
      (match Git.index_of text block_begin with
      | None -> bad "the page for agents has no math-coding block: mathc install"
      | Some _ -> (
          match Git.index_of text block_end with
          | None -> bad "the math-coding block is not closed: mathc install"
          | Some _ ->
              let current =
                with_block text (block_begin ^ "\n" ^ entry_page () ^ block_end)
              in
              if current = text then ok "the page for agents is current"
              else bad "the page for agents is out of date: mathc install"));
      (* And it names every verb the tool has. *)
      let verbs = verbs_of_help (usage_text ()) in
      let unnamed =
        List.filter (fun verb -> not (contains_word text verb)) verbs
      in
      if unnamed = [] then ok "the page names every verb the tool has"
      else
        bad
          (Printf.sprintf "the page does not name %s"
             (String.concat ", " unnamed)));
    (* The claims that have no control: their checks are not proven able
       to fail, and the map says so - but a person should know too. *)
    let without_control =
      List.filter_map
        (fun (c : Domain.claim) ->
          if c.Domain.control = None then Some c.Domain.id else None)
        spec.Domain.claims
    in
    if without_control = [] then ok "every claim carries a control for its check"
    else
      Printf.printf
        "  note    %s %s no control: %s check is not proven able to fail\n"
        (if List.length without_control = 1 then "one claim has" else "claims have")
        (String.concat ", " without_control)
        (if List.length without_control = 1 then "its" else "their"))
  else cannot "there is no standing specification: mathc init";
  Printf.printf "\n";
  if !broken > 0 then 1 else if !unknown > 0 then 3 else 0

(** The top-level directory a file belongs to.

    The groups are how a person sees the shape of an uncovered
    surface: "twelve files here, seventy there" is a shape, and
    "eighty-two files" is a number. *)
let top_directory (path : string) : string =
  match String.index_opt path '/' with
  | Some i -> String.sub path 0 (i + 1)
  | None -> path

(** propose: drafts for a project that has code and no claims.

    THE GAP. The map prints the uncovered surface and `next` names the
    first uncovered file, and neither turns that into a claim: the
    first claims of a foreign project were written by hand. In the
    measurement of 2026-11-01 the declarations were made by hand on
    three projects, and the numbers that came out of it - 390 files
    outside the coverage - were the numbers of a method whose first
    step was still manual.

    So the drafts are made. And they are DRAFTS: the register and the
    falsifier belong to the person, and the control - the command that
    must fail on the broken sample - nobody can write for them. The
    checks the project uses are taken from the project where the
    project says them out loud, and from the conventions of its
    ecosystem where it does not; the second kind is marked as such,
    because a convention passed off as a fact would be a claim about
    someone else's project that the method cannot support.

    A draft decides nothing. It is printed, not written into the
    specification: the person takes it, fills what only they can fill,
    and declares it with `add`. *)
let verb_propose (o : options) =
  let spec = load_spec () in
  let files = Git.tracked_files (root ()) in
  let uncovered = Git.uncovered (root ()) spec.Domain.claims files in
  (* The groups of the uncovered surface. *)
  let groups =
    List.fold_left
      (fun acc file ->
        let dir = top_directory file in
        match List.assoc_opt dir acc with
        | Some n -> (dir, n + 1) :: List.remove_assoc dir acc
        | None -> (dir, 1) :: acc)
      [] uncovered
    |> List.sort compare
  in
  (* The checks: what the project says, then the conventions, then what
     the person named on the command line. *)
  let found = Project.checks_of (root ()) in
  let named =
    List.map
      (fun c ->
        { Project.command = c; source = "named on the command line"; exact = true; test_like = true })
      o.checks
  in
  let checks = found @ named in
  (* THE CHECK OF THE CODE, AND NOT THE FIRST CHECK OF THE LIST. A
     project opens its scripts with the things that are not checks:
     "dev", "build", "start". A draft whose proof is a dev server
     proves nothing, and the method exists to catch exactly that - so
     the draft is made only over a check that looks like a check of
     the code, and if there is none, there is no draft and the tool
     says so. *)
  let of_the_code =
    List.filter (fun (c : Project.check) -> c.Project.test_like) checks
  in
  let groups_scope = List.map fst groups in
  let draft =
    if uncovered = [] then None
    else if of_the_code = [] then None
    else
      let chosen = List.hd of_the_code in
      let command = chosen.Project.command in
      Some
        (`Assoc
          [
            ("id", `String "the-project-is-checked");
            ( "subject",
              `String
                "the code this project has is checked by the project's own checks" );
            ( "scope",
              `List (List.map (fun p -> `String p) groups_scope) );
            ( "requirements",
              `List
                [ `Assoc
                    [ ("kind", `String "verifier"); ("spec", `String command) ] ] );
            ( "falsifier",
              `String (Printf.sprintf "%s fails" command) );
            ("register", `String "fact");
            ( "control",
              `String
                "WRITE ME: a check over a broken sample of the scope, which must \
                 fail with it - a check that cannot fail proves nothing" );
          ])
  in
  Printf.printf "the uncovered surface: %d file(s) in %d group(s)\n"
    (List.length uncovered) (List.length groups);
  (* The biggest groups first, and not all of them: a project with two
     hundred files in its root would otherwise print two hundred lines
     and say nothing. *)
  let by_size = List.sort (fun (_, a) (_, b) -> compare b a) groups in
  let shown = 20 in
  List.iteri
    (fun i (dir, n) ->
      if i < shown then Printf.printf "  %-30s %d\n" dir n
      else if i = shown then
        Printf.printf "  ... and %d more group(s)\n" (List.length groups - shown))
    by_size;
  Printf.printf "\nthe checks this project has:\n";
  if checks = [] then
    print_endline
      "  none were found. Name them: mathc propose --check \"the command\""
  else
    List.iter
      (fun (c : Project.check) ->
        Printf.printf "  %-40s %s%s\n" c.Project.command
          (if c.Project.exact then c.Project.source
           else c.Project.source ^ " - a convention, confirm it")
          (if
             of_the_code <> []
             && c.Project.command = (List.hd of_the_code).Project.command
           then "  <- the draft is made over this one"
           else if not c.Project.test_like then "  (not a check of the code)" else ""))
      checks;
  print_endline "";
  (match draft with
  | None ->
      if uncovered = [] then
        print_endline "nothing is uncovered, so there is nothing to propose"
      else if checks = [] then
        print_endline
          "no draft: the project's checks are not known yet. Name them and ask again"
      else
        print_endline
          "no draft: none of the project's checks is a check of the code - \"dev\", \
           \"build\" and \"start\" are not proofs. Name the check of the code and ask \
           again:\n  mathc propose --check \"the command\""
  | Some json ->
      print_endline
        "a draft - which decides nothing. The register and the falsifier are yours to \
         confirm,\n\
         and the control must be written: a check over a broken sample, which must fail \
         with it.";
      print_endline "";
      print_endline (Yojson.Safe.pretty_to_string json));
  0

(** The command line. The options are the project root, the reason an aim
    is being replaced, and the fields of the verbs that take them;
    everything else is a verb. An unknown option is an error rather than
    a verb, because a typo that silently becomes a verb is a method that
    reports something the user did not ask for. *)
let parse_args (args : string list) : string list * options =
  let o =
    {
      root = "";
      reason = "";
      json = false;
      version = false;
      by = "";
      outcome = "verified";
      control = "";
      valid_for = "";
      requirements = [];
      intent = "";
      objection = "";
      refuted_by = "";
      checks = [];
      claims = [];
      commitments = [];
      touches = [];
    }
  in
  let rec loop acc = function
    | [] -> (List.rev acc, o)
    | "--root" :: dir :: rest ->
        o.root <- dir;
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
        o.reason <- text;
        loop acc rest
    | "--by" :: text :: rest ->
        o.by <- text;
        loop acc rest
    | "--outcome" :: text :: rest ->
        o.outcome <- text;
        loop acc rest
    | "--control" :: text :: rest ->
        (* The negative control of the check: the command that breaks the
           subject and must fail with it. *)
        o.control <- text;
        loop acc rest
    | "--valid-for" :: text :: rest ->
        (* How long the proof counts. The content may be exactly the
           right one and the proof still too old to stand: the
           deployment moved, the dependency changed, the review was for
           a release that is over. The term is what says so. *)
        o.valid_for <- text;
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
        o.requirements <- o.requirements @ [ text ];
        loop acc rest
    | "--intent" :: text :: rest ->
        o.intent <- text;
        loop acc rest
    | "--objection" :: text :: rest ->
        o.objection <- text;
        loop acc rest
    | "--refuted-by" :: text :: rest ->
        o.refuted_by <- text;
        loop acc rest
    | "--check" :: text :: rest ->
        o.checks <- o.checks @ [ text ];
        loop acc rest
    | "--claim" :: text :: rest ->
        o.claims <- o.claims @ [ text ];
        loop acc rest
    | "--commit" :: text :: rest ->
        o.commitments <- o.commitments @ [ text ];
        loop acc rest
    | "--touches" :: text :: rest ->
        o.touches <- o.touches @ [ text ];
        loop acc rest
    | "--json" :: rest ->
        o.json <- true;
        loop acc rest
    | "--version" :: rest ->
        o.version <- true;
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
  loop [] args

(** A comma-separated list of paths. The scope of a claim is a list of
    path prefixes, and the list is written the way a shell would write
    it: comma-separated. *)
let split_scope (text : string) : string list =
  String.split_on_char ',' text |> List.map String.trim |> List.filter (fun s -> s <> "")

(** The version, and the build-id.

    The rule is old and was not kept: "the binary tells itself apart by
    the build-id - the hash of its own bytes is printed next to the
    version, so that two different binaries of one version cannot be
    confused with each other." It is kept now, and it is printed by the
    binary and not by the packaging that built it: the hash is of the
    bytes that are actually running. *)
let version_text () =
  let build =
    match Exec.own_path () with
    | Some path -> (
        match Git.hash_of_file path with Some h -> h | None -> "unknown")
    | None -> "unknown"
  in
  Printf.sprintf "mathc 4
build %s
" build

let () =
  let positional, o = parse_args (Array.to_list Sys.argv |> List.tl) in
  if o.root <> "" then set_root o.root;
  if o.version then (
    print_string (version_text ());
    exit 0);
  match positional with
  | [] | [ "--help" ] | [ "-h" ] ->
      usage ();
      exit 0
  | verb :: _ -> (
      (* A flag that belongs to one verb and is accepted by another is a
         flag that is silently ignored, and a method that ignores what
         it was told reports something the user did not ask for. *)
      (* The verbs a flag belongs to. A flag may have more than one
         owner - --check names the checks a wave must pass, and the
         checks a project has, and the value means the same in both -
         but it may not have an owner that is not there: a flag that
         another verb accepts and ignores is a flag the method was
         told something with and then threw away. *)
      let owners flag =
        match flag with
        | "--check" -> Some [ "wave"; "propose" ]
        | "--requirement" | "--control" -> Some [ "add" ]
        | "--intent" | "--objection" | "--refuted-by" | "--claim" | "--commit"
        | "--touches" -> Some [ "wave" ]
        | "--by" | "--outcome" | "--valid-for" -> Some [ "record" ]
        | _ -> None
      in
      let used_flags =
        List.filter_map
          (fun (flag, used) -> if used then Some flag else None)
          [
            ("--requirement", o.requirements <> []);
            ("--control", o.control <> "");
            ("--intent", o.intent <> "");
            ("--objection", o.objection <> "");
            ("--refuted-by", o.refuted_by <> "");
            ("--check", o.checks <> []);
            ("--claim", o.claims <> []);
            ("--commit", o.commitments <> []);
            ("--touches", o.touches <> []);
            ("--by", o.by <> "");
            ("--outcome", o.outcome <> "verified");
            ("--valid-for", o.valid_for <> "");
          ]
      in
      List.iter
        (fun flag ->
          match owners flag with
          | Some vs when not (List.mem verb vs) ->
              Printf.eprintf "mathc: %s belongs to %s\n" flag
                (String.concat " or " vs);
              exit 2
          | _ -> ())
        used_flags;
      let code =
        match verb with
        | "goal" -> (
            match positional with
            | _ :: text :: scope :: by :: _ ->
                verb_goal text (split_scope scope) by o.reason
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
                (match parse_all [] o.requirements with
                | Error e ->
                    Printf.eprintf "mathc: %s\n" e;
                    2
                | Ok rs ->
                    verb_add id subject (split_scope scope) rs falsifier register
                      o.control)
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
        | "budget" -> (
            match positional with
            | _ :: budget :: _ -> (
                match int_of_string_opt budget with
                | Some b when b >= 0 -> verb_budget b o.reason
                | _ ->
                    Printf.eprintf "mathc: the budget must be a non-negative integer\n";
                    2)
            | _ ->
                Printf.eprintf "mathc: budget needs a number and a reason\n";
                2)
        | "accept" -> (
            match positional with
            | _ :: id :: by :: reason :: _ -> verb_accept id by reason
            | _ ->
                Printf.eprintf "mathc: accept needs ID BY REASON\n";
                2)
        | "map" -> verb_map o.json
        | "route" -> verb_route ()
        | "run" -> verb_run ()
        | "record" -> (
            match positional with
            | _ :: claim_id :: spec :: _ ->
                verb_record claim_id spec o.by o.outcome o.reason o.valid_for
            | _ ->
                Printf.eprintf
                  "mathc: record needs CLAIM REQUIREMENT --by WHO --outcome OUTCOME\n";
                2)
        | "next" -> verb_next ()
        | "install" -> verb_install ()
        | "propose" -> verb_propose o
        | "mcp" ->
            (* The machine surface for agents. It speaks on stdout, so
               nothing else may be printed there. *)
            Mcp.mcp_loop ~root:(root ());
            0
        | "doctor" -> verb_doctor ()
        | "wave" -> (
            match positional with
            | _ :: id :: title :: _ -> verb_wave id title o
            | _ ->
                Printf.eprintf "mathc: wave needs ID TITLE --intent ... --objection ...\n";
                2)
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
