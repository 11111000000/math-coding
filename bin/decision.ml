open Domain

(* The decision of a person about a claim, and the revision of it. The material
   of a decision is the decision itself: a document that carries it may keep
   growing without making the decision stale, and the revision is how the
   person says that the decision changed. *)

(* The human attestation of a claim: the record of a person. An answer and a
   revision are the same record; only the reason and the time differ. *)
let human_evidence ~root ~claim ~requirement ~by ~outcome ~valid_for ~run ~evidence_ref =
  { claim_id = claim.id; requirement;
    candidate_tree = Option.value ~default:"unborn" (Git.head_commit root);
    materials_digest = Git.binding_of_scope root ~scope:claim.scope;
    definition_digest = definition_digest claim; verifier_digest = verifier_digest claim;
    environment = Project.environment root;
    producer = { class_ = "human"; identity = by; run };
    independence = External; outcome; issued_at = Execution.now ();
    valid_until = Option.map (fun days -> Execution.now () + (days * 86400)) valid_for;
    evidence_ref; control_reach = None }

(* The revision of a human decision. It covers the review branches whose last
   decision this person made; the owner of the claim speaks for all of them.
   The previous decision stays in the journal. *)
let revise ~root ~claim ~records ~by ~reason ~outcome ~valid_for =
  let reviews = Project.reviews_of_claim claim in
  if reviews = [] then Error "the claim is not settled by a human review"
  else
    let mine =
      List.filter
        (fun requirement ->
          match Verdict.latest claim requirement records with
          | Some evidence -> evidence.producer.class_ = "human" && evidence.producer.identity = by
          | None -> false)
        reviews
    in
    let branches = if mine <> [] then mine else if claim.owner = Some by then reviews else [] in
    if branches = [] then Error ("there is no decision of " ^ by ^ " to revise")
    else (
      List.iter
        (fun requirement ->
          Trail.append root
            (human_evidence ~root ~claim ~requirement ~by ~outcome ~valid_for
               ~run:None ~evidence_ref:(Some reason)))
        branches;
      Ok ())

(* The review of a changed source. The record of the review keeps the author,
   the reason, the time and the previous digest, the accepted risk is dropped
   and the checks still have to run again. *)
let review_source ~root ~spec ~id ~by ~reason =
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> Error ("there is no claim " ^ id)
  | Some claim -> (
      match claim.source with
      | None -> Error "the claim has no source to review"
      | Some source ->
          if by = "" || reason = "" then Error "review-source needs --by and --reason"
          else if claim.owner <> Some by then Error "only the claim owner can review its source"
          else
            match Git.digest_of_repo_file root source.path with
            | None -> Error ("source file not found: " ^ source.path)
            | Some digest when digest = source.digest -> Error "the source has not changed"
            | Some digest ->
                let previous_digest = source.digest in
                let review = Some { by; reason; at = Execution.now (); previous_digest } in
                let source = { source with digest; review } in
                let claims = List.map (fun current ->
                  if current.id = id then { current with source = Some source; waiver = None } else current) spec.claims in
                Project.save_spec root { spec with claims };
                Printf.printf "claim %s source review recorded; next: mathc run\n" id;
                Ok ())
