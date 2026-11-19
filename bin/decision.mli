open Domain

(* The human attestation of a claim: the record of a person. An answer and a
   revision are the same record; only the reason and the time differ. *)
val human_evidence :
  root:string -> claim:claim -> requirement:requirement -> by:string -> outcome:outcome ->
  valid_for:int option -> run:string option -> evidence_ref:string option -> evidence

(* The revision of a human decision. It covers the review branches whose last
   decision this person made; the owner of the claim speaks for all of them.
   The previous decision stays in the journal. *)
val revise :
  root:string -> claim:claim -> records:evidence list -> by:string -> reason:string ->
  outcome:outcome -> valid_for:int option -> (unit, string) result

(* The review of a changed source. The record keeps the author, the reason, the
   time and the previous digest, the accepted risk is dropped and the checks
   still have to run again. *)
val review_source :
  root:string -> spec:spec -> id:string -> by:string -> reason:string -> (unit, string) result
