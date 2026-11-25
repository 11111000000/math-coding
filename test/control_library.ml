open Helpers

let () =
  let root = in_repo "." in
  let result = Process.run ~root "sh test/control_library.sh" in
  check "the library of controls mutates common subjects" (result.code = 0);
  print_endline "control-library: PASS"
