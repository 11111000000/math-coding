open Domain

(* The state of every claim together with what the journal could not say. *)
type evaluated_state = {
  id : string;
  state : state;
  changed : bool;
  reason : Verdict.reason;
  (* The digest of the subject as it is now; missing when the subject cannot
     be digested. *)
  materials : string option;
  (* The branches that no evidence settles yet, with the state each of them
     stands in: what still has to close for the claim to hold. *)
  open_branches : (requirement * state) list;
}

type evaluation = { states : evaluated_state list; damaged : Trail.damage list }

(* The claims a partial run has work for, and the ones it leaves alone. *)
type selection = {
  to_execute : claim list;
  current : claim list;
  settled : claim list;
  human : claim list;
  blind : claim list;
}

(* The environment of the project: the operating system and the lock file of
   the toolchain. The binary is not part of it. The binary is the tool, and
   the tool is an observer - it is not the place the check ran - so it is
   written beside the environment and never inside it. A change of the binary
   therefore does not make an observation stale. *)
let environment root : Domain.environment =
  let lock = Filename.concat root "flake.lock" in
  let toolchain = if Sys.file_exists lock then Io.read_file lock else "" in
  { class_ = "local"; fingerprint = Domain.digest_string (Sys.os_type ^ "\n" ^ toolchain) }

(* The tool that writes the records down: the binary itself. Its fingerprint
   is empty when the binary cannot be digested - an unknown tool is not a
   changed tool, and the map says that it does not know. *)
let tool () : Domain.tool =
  let fingerprint = match Git.digest_of_file Sys.executable_name with Some digest -> digest | None -> "" in
  { class_ = "mathc"; fingerprint }

(* The requirements of a claim that the method evaluates. A judgment takes
   only its review branches: a machine check cannot settle a human decision. *)
let requirements_of_claim (claim : claim) =
  match claim.register with
  | Judgment -> List.filter_map Verdict.judgment_requirements claim.requirements
  | Fact | Hypothesis | Undeclared -> claim.requirements

(* The review branches of a claim: the branches that only a person can settle.
   A decision is bound to the decision, not to the bytes of the document that
   carries it, so the branches of a decision are found by their kind. *)
let rec review_branches = function
  | Verifier _ -> []
  | Review _ as requirement -> [ requirement ]
  | All requirements | Any requirements -> List.concat_map review_branches requirements

(* The reviews a claim waits for: the review branches of its active
   requirements. *)
let reviews_of_claim (claim : claim) =
  List.concat_map review_branches (requirements_of_claim claim)

(* The branches of a claim that no evidence settles yet: what still has to
   close for the claim to hold. Every branch is asked on its own, so a branch
   that no evidence settles is left out and a settled one is not. *)
let open_branches_of ~now ~environment ~tool ?materials (claim : claim) evidence =
  List.filter_map
    (fun requirement ->
      (* The branch is judged against the definition of the whole claim: that
         is the definition its evidence was recorded against. *)
      let state, _ =
        Verdict.explain_claim ~now ~environment ~tool ?materials ~requirements:[ requirement ] claim evidence
      in
      if state = Holds then None else Some (requirement, state))
    (requirements_of_claim claim)

(* Whether the source a claim is bound to has changed since the digest was
   taken. A changed source outranks every other reason for staleness. *)
let source_changed root (claim : claim) =
  match claim.source with
  | None -> false
  | Some source -> Git.digest_of_repo_file root source.path <> Some source.digest

let evaluate root spec =
  match Trail.read root with
  | Error error -> Error error
  | Ok journal -> (
      match Git.repository_files root with
      | Error error -> Error error
      | Ok files ->
          let now = int_of_float (Unix.time ()) in
          let current_environment = environment root in
          let current_tool = tool () in
          let states =
            List.map
              (fun (claim : claim) ->
                let materials = Git.digest_of_scope ~files root ~scope:claim.scope in
                let state, reason = Verdict.explain_claim ~now ~environment:current_environment
                  ~tool:current_tool ?materials claim journal.records in
                let open_branches =
                  open_branches_of ~now ~environment:current_environment ~tool:current_tool ?materials claim
                    journal.records
                in
                let changed = source_changed root claim in
                (* A changed source outranks every other reason for staleness. *)
                if changed then
                  { id = claim.id; state = Outdated; changed = true; reason = Why_source_changed;
                    materials; open_branches }
                else { id = claim.id; state; changed = false; reason; materials; open_branches })
              (Domain.active_claims spec)
          in
          Ok { states; damaged = journal.damaged })

let uncovered root spec =
  let goal_scope = match spec.goal with Some goal -> goal.scope | None -> [] in
  Git.uncovered root (Domain.active_claims spec) ~goal_scope

let states root spec =
  match evaluate root spec with
  | Error error -> Error error
  | Ok evaluation -> Ok (List.map (fun item -> item.id, item.state) evaluation.states)

(* Whether a branch holds a machine check. A claim with no machine check is
   closed by a human, and the run has no work for it. *)
let rec has_machine_check = function
  | Verifier _ -> true
  | Review _ -> false
  | All requirements | Any requirements -> List.exists has_machine_check requirements

(* The claims a partial run has work for. The rule is the rule of freshness
   the map already uses: a claim whose evidence still holds is left alone,
   because its evidence speaks for itself and a check that holds is not worth
   paying for again. A refuted claim is left alone as well: a refutation is a
   finding for a human, and its evidence is fresh by definition, so running
   it again would pay for nothing. A claim the human accepted a risk for is
   left alone too. A claim whose subject cannot be digested is executed
   anyway: the method does not skip a claim it cannot see. *)
let selection root spec =
  match evaluate root spec with
  | Error error -> Error error
  | Ok evaluation ->
      let to_execute = ref [] and current = ref [] and settled = ref [] in
      let human = ref [] and blind = ref [] in
      List.iter
        (fun (claim : claim) ->
          match List.find_opt (fun item -> item.id = claim.id) evaluation.states with
          | None -> ()
          | Some item ->
              let checkable = List.exists has_machine_check (requirements_of_claim claim) in
              if item.state = Holds || item.state = Observed then
                if checkable && item.materials = None then (
                  to_execute := claim :: !to_execute;
                  blind := claim :: !blind)
                else current := claim :: !current
              else if not checkable then human := claim :: !human
              else
                match item.state with
                | Refuted | Waived -> settled := claim :: !settled
                | Holds -> ()
                | Observed -> current := claim :: !current
                | Outdated | Inconclusive | NeverChecked ->
                    to_execute := claim :: !to_execute)
        (Domain.active_claims spec);
      Ok { to_execute = List.rev !to_execute; current = List.rev !current;
           settled = List.rev !settled; human = List.rev !human; blind = List.rev !blind }

(* What a partial run did, in words a reader can act on: how many claims it
   executed and how many it left alone, and why. *)
let selection_words (selection : selection) =
  let executed = List.length selection.to_execute in
  let total =
    executed + List.length selection.current + List.length selection.settled
    + List.length selection.human
  in
  Printf.sprintf "partial run: %d of %d claim(s) executed; %d left current; %d left refuted or waived; %d waiting for a human"
    executed total (List.length selection.current) (List.length selection.settled)
    (List.length selection.human)

(* The claims the run cannot see. They are executed anyway, and the run says
   so: a map that cannot see a change is not a reason to skip the claim. *)
let blind_words (selection : selection) =
  match selection.blind with
  | [] -> None
  | blind ->
      Some (Printf.sprintf "the subject of %d claim(s) cannot be seen; they are executed anyway"
              (List.length blind))
