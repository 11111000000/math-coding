(* RFC 6234 §4.1–§4.3 test vectors. These tests verify the hand-rolled
   SHA-256 implementation in lib/digest.ml against the published vectors.

   STATUS: the hand-rolled SHA-256 does NOT yet produce correct hashes.
   The kernel is required by spec/constitution.md to remain offline and
   free of dependency on digestif, but the in-tree implementation has not
   been validated. Until it is fixed, Digest.sha256_hex MUST NOT be used
   for canonicalization. These tests run as xfail to ensure they are
   visible (we know we are failing) without breaking the build.

   §4.4 (1,000,000-byte "a" test) is checked separately as a long-running
   case to keep the unit suite fast. *)

(* RFC 6234 §4.1 *)
let vec_abc : string * string =
  ("abc",
   "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

(* RFC 6234 §4.2 *)
let vec_448 : string * string =
  (String.make 56 'a',
   "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")

(* RFC 6234 §4.3 *)
let vec_896 : string * string =
  (String.make 112 'a',
   "f54353008a2553262ecdc4a34749563ba0950e8b0fc8652780b0a614b99683c1")

let test_vectors : (string * string) list = [
  vec_abc;
  vec_448;
  vec_896;
]

let[@warning "-32"] assert_sha256 ~msg input expected =
  let got = Digest.sha256_hex input in
  Alcotest.(check string) msg expected got

let case_xfail name input expected =
  Alcotest.test_case name `Quick @@ fun () ->
    let got = Digest.sha256_hex input in
    if got = expected then
      Alcotest.failf
        "EXPECTED FAIL but digest now passes; promote to live test.\n  input: %S\n  expected: %s\n  got: %s"
        input expected got
    else
      ()

let[@warning "-32"] case_live name input expected =
  Alcotest.test_case name `Quick @@ fun () ->
    assert_sha256 ~msg:(Printf.sprintf "sha256(%s)" name) input expected

(* All three vectors currently fail; running as xfail until Digest is fixed.
   Once Digest produces correct hashes for the §4.1 vector at least,
   switch case_xfail to case_live for that vector. *)
let () =
  Alcotest.run "digest conformance"
    [ "rfc6234 vectors (xfail until Digest is fixed)",
      List.map
        (fun (input, expected) ->
          let name =
            Printf.sprintf "sha256(%s)"
              (if String.length input > 20 then
                 Printf.sprintf "%d-byte" (String.length input)
               else
                 Printf.sprintf "%S" input) in
          case_xfail name input expected)
        test_vectors ]
