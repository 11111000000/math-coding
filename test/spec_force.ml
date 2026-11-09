(* EVERY CHECK OF THE METHOD IS RUN AGAIN, NOT REMEMBERED.

   Dune caches the result of a test by its dependencies, and a test that
   READS THE TREE - which is what the lints and the guards do - has no
   dependency on the tree. So a check that does not say "--force"
   reports the result of an earlier run, and a mutation of the subject
   is not noticed: the control cannot bite, because the check never ran.

   That is not a hypothesis: twenty-nine of the method's own claims
   carried a check that dune had cached, and every control of theirs
   was reported as "the check passed where its negative control had to
   fail" - the check had not looked at the broken subject at all, it
   had remembered an earlier answer.

   So the method's own claims are read here from the standing
   specification, and every one of them must be a check that is run
   again. A check that does not say so is a comment with a command
   attached.

   THE NEGATIVE CONTROL. The check must be able to say no: a
   specification whose requirement has lost the "--force" must be
   rejected - which is the very mutation the control of this claim
   makes. *)

let read_file path =
  let channel = open_in path in
  let content = In_channel.input_all channel in
  close_in channel;
  content

(* The source tree, as the other tests find it: the build directory is
   always named _build, so the source tree is its parent. *)
let source_root () =
  let rec loop d =
    if Filename.basename d = "_build" then Filename.dirname d
    else
      let parent = Filename.dirname d in
      if parent = d then d else loop parent
  in
  loop (Sys.getcwd ())

let in_repo path = Filename.concat (source_root ()) path

let string_field name (json : Yojson.Safe.t) : string =
  match json with
  | `Assoc pairs -> (
      match List.assoc_opt name pairs with
      | Some (`String s) -> s
      | _ -> "")
  | _ -> ""

let list_field name (json : Yojson.Safe.t) : Yojson.Safe.t list =
  match json with
  | `Assoc pairs -> (
      match List.assoc_opt name pairs with
      | Some (`List items) -> items
      | _ -> [])
  | _ -> []

(* A check that is run again, or one that is not. The nix builds are
   exempt: nix does not cache a failed build, and a flake that does not
   parse fails every time it is asked. *)
let contains hay needle =
  let n = String.length hay and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  while (not !found) && !i + m <= n do
    if String.sub hay !i m = needle then found := true else i := !i + 1
  done;
  !found

let is_run_again (cmd : string) : bool =
  contains cmd "--force" || contains cmd "nix build"

let () =
  let spec = Yojson.Safe.from_string (read_file (in_repo "spec.json")) in
  let claims = list_field "claims" spec in
  List.iter
    (fun claim ->
      List.iter
        (fun r ->
          (* A review is closed by a person, not run by a command: there
             is nothing for a cache to remember. *)
          let kind = string_field "kind" r in
          let cmd = string_field "spec" r in
          if kind = "verifier" && cmd <> "" && not (is_run_again cmd) then
            failwith
              (Printf.sprintf
                 "the check of a claim is remembered, not run again: %s" cmd))
        (list_field "requirements" claim))
    claims;
  print_endline "spec-force: PASS"
