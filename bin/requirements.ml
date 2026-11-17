(* The requirements of a claim ask for work in an order, and a run stops at a
   certain point. The protocol arm of a run and the price arm of the measurer
   share this traversal, so the two arms cannot disagree about the work the
   protocol does.

   A leaf is a requirement an arm has to deal with on its own: a check the arm
   runs, or a human review that no arm can run. The arm says what a leaf costs
   and what it proves; this module says which leaves run and when the run
   stops. *)

(* The outcome of a requirement is the outcome of the protocol. The state of a
   claim and the outcome of a requirement share a constructor name, so the
   constructors of the outcome are named here and not left to the inference. *)
type outcome = Domain.outcome = Pass | Fail | Inconclusive | Infrastructure_error | Not_run

let rec run ~leaf requirement =
  match requirement with
  | Domain.Review _ | Domain.Verifier _ -> leaf requirement
  | Domain.All requirements ->
      (* A conjunction stops at the first rejection and goes on after an
         inconclusive or a failed start, so that a later rejection is not lost. *)
      let rec loop = function
        | [] -> Pass
        | requirement :: rest ->
            let outcome = run ~leaf requirement in
            match outcome with
            | Pass -> loop rest
            | Fail -> Fail
            | (Inconclusive | Infrastructure_error | Not_run) as outcome ->
                (match loop rest with
                 | Fail -> Fail
                 | Pass | Inconclusive | Infrastructure_error | Not_run -> outcome)
      in
      loop requirements
  | Domain.Any requirements ->
      (* The alternatives stop at the first confirmation. *)
      let rec loop = function
        | [] -> Inconclusive
        | requirement :: rest ->
            let outcome = run ~leaf requirement in
            if outcome = Pass then Pass else loop rest
      in
      loop requirements
