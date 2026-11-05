(** The vocabulary of the method.

    Everything here is a value. Nothing here reads a file, asks the
    clock, or touches a process. The laws that govern these values live
    in [Verdict]; the effects that produce them live in the adapter.

    The split is not tidiness for its own sake. A law about a value is
    a fact about the method; a law about an effect is a fact about a
    machine. Mixing them means that a proof of the law depends on
    whether the machine was in the right mood, and the proof stops
    being a proof. *)

(** What happened to one check.

    - [Verified] — the check ran and the claim survived it.
    - [Falsified] — the check ran and the claim did not.
    - [Unresolved] — the check could not be run, or ran and could not
      tell. It did NOT pass. This is the outcome the third version
      laundered into a pass, and the whole reason it exists.
    - [Refused] — the subject has no canary: there is no procedure
      that could break it, because it is a decision about meaning. The
      claim is not wrong; it is not the machine's to decide. *)
type outcome =
  | Verified
  | Falsified
  | Unresolved
  | Refused

(** What a set of results means as a whole. Three values, and no more:
    the question a verdict answers is whether anything was refuted and
    whether anything is known. *)
type verdict =
  | Green
  | Red
  | Unknown

(** A register says what kind of claim this is, and therefore what
    evidence it demands. A fact is closed by a procedure that could
    falsify it. A hypothesis is closed the same way. A judgment - a
    decision about meaning - has no procedure, and must be refused by
    the machine rather than verified by it. An undeclared claim does
    not say what it is, and the method cannot demand a proof it does
    not know the kind of: it asks instead.

    The last constructor is named [Undeclared] rather than "unknown"
    because [Unknown] already means something else and does something
    else: it is a verdict. Two meanings in one namespace are an
    ambiguity waiting to be resolved the wrong way. *)
type register =
  | Fact
  | Hypothesis
  | Judgment
  | Undeclared

(** The paths a claim is about. The subject is not a name but a place
    in the tree: two claims about "the parser" that name different
    paths are about different things, and only the paths can be
    digested. A scope that names nothing is not a scope - see
    [Verdict.law_no_vacant_subject]. *)
type scope = string list

(** The subject of a claim: what is claimed, and where. *)
type subject = {
  text : string;
  scope : scope;
}

(** A claim: a proposition about a subject, the procedure that could
    falsify it, and what that falsifier would look like. *)
type claim = {
  id : string;
  subject : subject;
  check : string;
  falsifier : string;
  register : register;
}

(** The digest of a subject, as it stands now. Evidence is bound to
    one: if the subject moves, the evidence is about a subject that no
    longer exists. *)
type binding = string

(** A result, and the subject it was obtained against. The reason says
    why the outcome is what it is - "the check exited 127" is a fact the
    human needs; a bare [Unresolved] is not. *)
type evidence = {
  claim : claim;
  outcome : outcome;
  bound_to : binding;
  reason : string option;
}

(** What the human is asked to decide. The reason is not decoration:
    a refusal without a reason is an "I do not know" with no content,
    and the third version required the reason at write time for
    exactly that reason. *)
type finding = {
  subject : string;
  outcome : outcome;
  reason : string option;
}

(** The state of one claim, as computed. Not stored: it is derived from
    the standing specification and the evidence, so it cannot fall out
    of step with either.

    The distinction that matters most is between [Outdated] and
    [NeverChecked]. Both mean "not known now", and they are different
    faults: one is evidence that has gone out of date, the other is
    work never done. A map that merged them would report a project
    with a week-old proof and a project with no proof at all as the
    same thing.

    The names differ from the outcome constructors on purpose. Two
    types with the same constructor names in one namespace are an
    ambiguity waiting to be resolved the wrong way, and the compiler
    resolves it silently. *)
type state =
  | Holds (* checked, and the claim survived *)
  | Refuted (* checked, and the claim did not *)
  | Inconclusive (* checked, and it could not tell *)
  | NotCheckable (* no canary: the claim is a judgment, not the machine's *)
  | Outdated (* there is evidence, but the subject moved since *)
  | NeverChecked (* required, and never checked *)

(** The map: the standing specification, computed. What is claimed,
    what is known, what is not covered. *)
type map = {
  states : (string * state) list;
  uncovered : string list;
}

(** A wave: a finished, green slice of work. The format is data and
    lives in [Spec]; this is the shape it parses into. *)
type wave = {
  id : string;
  title : string;
  touches : scope;
  checks : string list;
  claims : string list;
  verdicts_changed : string list;
}

(** The aim: what should become true.

    It is written by a person, and the method refuses claims that fall
    outside it. That refusal is the whole mechanism, and it needs no
    authentication to work: an agent that optimises toward what it can
    measure cannot widen its own field of operations, because the
    boundary is the aim, and changing the aim is visible in the
    history.

    The method cannot tell a person from an agent at the keyboard. It
    can attribute the aim, and it can make the aim's changes visible.
    It cannot authenticate, and it does not pretend to. *)
type goal = {
  text : string;
  scope : scope;
  by : string;
  at : string;
}

(** Is a path inside a directory?

    The comparison is on path boundaries, not on the letters: "library/"
    is not inside "lib/". Getting this wrong would let a claim about a
    similarly named directory pass as one about the intended one, and
    the mistake would be invisible - the claim would simply bind to
    the wrong files.

    Trailing slashes are removed first, so that "lib/" and "lib" name
    the same directory, and a directory contains itself. *)
let path_contains ~(dir : string) ~(path : string) : bool =
  let trim s =
    if String.length s > 1 && s.[String.length s - 1] = '/' then
      String.sub s 0 (String.length s - 1)
    else s
  in
  let d = trim dir and p = trim path in
  if p = d then true
  else if String.length p > String.length d && String.sub p 0 (String.length d) = d then
    p.[String.length d] = '/'
  else false

(** The standing specification of a project: the aim, the price of
    uncertainty that the project has agreed to pay, and the claims.

    The budget is required rather than defaulted. A budget nobody
    declared is not finite, and an uncertainty that costs nothing is
    the free escalation the principle exists to stop: "I do not know"
    would be cheaper than checking. *)
type spec = {
  goal : goal option;
  budget : int;
  claims : claim list;
}
