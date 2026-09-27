open Stdlib

type kind = Decision | Obligation | Attestation | Waiver | Change

type t =
  | Ref of { kind : kind; id : string; revision : string option }
  | Parent of { kind : kind; id : string; parent : string }
  | Subject of { kind : kind; id : string }

let parse_kind s =
  match s with
  | "decision" -> Some Decision
  | "obligation" -> Some Obligation
  | "attestation" -> Some Attestation
  | "waiver" -> Some Waiver
  | "change" -> Some Change
  | _ -> None

let parse s =
  let parse_one piece =
    match String.split_on_char '@' piece with
    | [ k_id ] -> (
        match String.split_on_char ':' k_id with
        | [ k; id ] -> (
            match parse_kind k with
            | Some kind -> Some (Ref { kind; id; revision = None })
            | None -> None)
        | _ -> None)
    | [ k_id; rev ] -> (
        match String.split_on_char ':' k_id with
        | [ k; id ] -> (
            match parse_kind k with
            | Some kind -> Some (Ref { kind; id; revision = Some rev })
            | None -> None)
        | _ -> None)
    | _ -> None
  in
  match parse_one s with
  | Some _ as r -> r
  | None -> (
      match String.split_on_char ':' s with
      | [ k; rest ] -> (
          match parse_kind k with
          | Some kind -> Some (Subject { kind; id = rest })
          | None -> None)
      | _ -> None)
