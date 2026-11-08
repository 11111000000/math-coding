(** The project's own checks.

    The method does not bring its checks to a foreign project: a
    project that does not run its own checks has nothing for the method
    to check. So somebody has to ask the project what its checks are -
    and the asking must not be a guess dressed as a fact.

    Two kinds of answer are given here, and they are told apart:

    - **Read from the project.** A `package.json` is JSON, and JSON is
      read with a library, so the scripts of a JavaScript project are
      the project's own words, not a guess about them.

    - **A convention.** A Cargo project checks itself with `cargo test`,
      a Go project with `go test ./...`, a Python project with `pytest`.
      These are conventions, not facts: a project may deviate, and the
      tool says which is which, so the person who owns the project can
      correct it. A convention that was passed off as a fact would be
      a claim about someone else's project that the method cannot
      support - and this is exactly the fault the method exists to
      catch.

    What is NOT here: a parser for every ecosystem. A Makefile's
    targets, a `pom.xml`, a `build.gradle` - each of them is a format
    with its own rules, and a hand-rolled reader of each is a source of
    quiet losses. The person's own `--check` covers them, and the tool
    says so. *)

let read_file (path : string) : string option =
  if not (Sys.file_exists path) then None
  else
    let channel = open_in path in
    let content = In_channel.input_all channel in
    close_in channel;
    Some content

(** One check of the project.

    [test_like] says whether the check looks like a check OF THE CODE
    rather than something else: a build, a server, a formatter. The
    difference matters because the first check of a list is often not
    a check at all - a `package.json` usually opens with "dev" and
    "build", and a method that took the first entry would propose a
    dev server as the proof that the code is right. *)
type check = {
  command : string;
  source : string;
  (* The project said it out loud, or it is a convention of its
     ecosystem. *)
  exact : bool;
  test_like : bool;
}

(** The names a check of the code carries.

    "test", "check", "verify", "ci", "spec" - and anything that starts
    with them, so that "test:unit" counts too. A linter does not: it
    says the code is well-formed, not that it is right. *)
let is_a_test_name (name : string) : bool =
  let starts_with prefix =
    String.length name >= String.length prefix
    && String.sub name 0 (String.length prefix) = prefix
  in
  List.exists
    (fun prefix -> name = prefix || starts_with (prefix ^ ":") || starts_with (prefix ^ "-"))
    [ "test"; "check"; "verify"; "ci"; "spec" ]

(** The scripts of a `package.json`, read with the JSON library.

    The scripts are the project's own commands, so the command that
    runs one is `npm run <name>` - and that is the whole translation
    from the file to a command line. *)
let checks_of_package_json (root : string) : check list =
  let path = Filename.concat root "package.json" in
  match read_file path with
  | None -> []
  | Some content -> (
      match Yojson.Safe.from_string content with
      | json -> (
          match json with
          | `Assoc pairs -> (
              match List.assoc_opt "scripts" pairs with
              | Some (`Assoc scripts) ->
                  List.filter_map
                    (fun (name, value) ->
                      match value with
                      | `String _ ->
                          Some
                            {
                              command = "npm run " ^ name;
                              source = "package.json:scripts." ^ name;
                              exact = true;
                              test_like = is_a_test_name name;
                            }
                      | _ -> None)
                    scripts
              | _ -> [])
          | _ -> [])
      | exception Yojson.Json_error _ -> [])

(** The conventions, one per ecosystem.

    Each of them is a fact about the ecosystem and a guess about the
    project, and the `exact` field says so: `true` for a fact read
    from the project, `false` for a convention. *)
let checks_by_convention (root : string) : check list =
  let has name = Sys.file_exists (Filename.concat root name) in
  let out = ref [] in
  if has "Cargo.toml" then
    out :=
      {
        command = "cargo test";
        source = "convention: a Cargo project";
        exact = false;
        test_like = true;
      }
      :: !out;
  if has "go.mod" then
    out :=
      {
        command = "go test ./...";
        source = "convention: a Go project";
        exact = false;
        test_like = true;
      }
      :: !out;
  if has "pyproject.toml" || has "pytest.ini" || has "setup.cfg"
     || has "setup.py" || has "tox.ini"
  then
    out :=
      {
        command = "pytest";
        source = "convention: a Python project";
        exact = false;
        test_like = true;
      }
      :: !out;
  List.rev !out

(** What the project says its checks are.

    The order matters and is the order of trust: what the project says
    out loud comes first, and the conventions follow. A person reading
    the list sees the project's own words before the guesses. *)
let checks_of (root : string) : check list =
  checks_of_package_json root @ checks_by_convention root
