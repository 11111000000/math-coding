(** The verdict of a set of claims.

    A claim is a statement about a subject, a procedure that could
    falsify it, and the falsifier itself. The verdict is what the set
    of results means as a whole.

    The four outcomes are distinct because they are distinct facts: a
    check that ran and passed, a check that ran and failed, a check that
    could not be run, and a refusal to decide at all. Collapsing them
    is how a protocol starts reporting green on evidence it never
    gathered. *)

type outcome =
  | Verified
  | Falsified
  | Unresolved
  | Refused

type claim = {
  subject : string;
  check : string;
  falsifier : string;
}

(** A checked claim: the claim and what came of checking it. The name
    is not [result] because that is a type in the standard library, and
    a shadowed name is a shadowed name. *)
type checked = {
  claim : claim;
  outcome : outcome;
}

(** A finding is what the human is asked to look at: the two outcomes
    that a machine cannot settle on its own. *)
type finding = {
  subject : string;
  outcome : outcome;
}

type verdict =
  | Green
  | Red
  | Unknown

(** The law of aggregation, in the order of severity.

    An empty set is Green: there is nothing to check, and "nothing to
    check" is not a defect. A falsified claim is Red whatever else
    happened. An unresolved claim is Unknown, which is not Red but is
    also not Green. Everything else is Green — including a refusal,
    which is a legitimate result and is routed to the human rather
    than counted as a failure. *)
let aggregate (results : checked list) : verdict =
  match results with
  | [] -> Green
  | _ ->
      if List.exists (fun (r : checked) -> r.outcome = Falsified) results then Red
      else if List.exists (fun (r : checked) -> r.outcome = Unresolved) results then Unknown
      else Green

(** The route: what the human is asked to decide. An unresolved claim
    and a refused claim both need a person; nothing else does. *)
let route (results : checked list) : finding list =
  List.filter_map
    (fun (r : checked) ->
      match r.outcome with
      | Unresolved | Refused -> Some { subject = r.claim.subject; outcome = r.outcome }
      | Verified | Falsified -> None)
    results

(** The exit code. Three values, because "we could not tell" and "it is
    wrong" must not share a code: a caller that treats them alike will
    treat a missing tool as a passing check. *)
let verdict_to_exit = function Green -> 0 | Red -> 1 | Unknown -> 3
