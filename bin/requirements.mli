(* The traversal of a requirement tree: which leaves run and when the run
   stops. The protocol arm of a run and the price arm of the measurer share
   it, so the two arms cannot disagree about the work the protocol does. *)

type outcome = Domain.outcome = Pass | Fail | Inconclusive | Infrastructure_error | Not_run

val run : leaf:(Domain.requirement -> outcome) -> Domain.requirement -> outcome
