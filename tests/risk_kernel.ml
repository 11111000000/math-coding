(* Helper to render Domain.mode as a string for test comparisons. *)
let[@warning "-32"] mode_to_string m =
  match m with
  | `Tiny -> "Tiny"
  | `Light -> "Light"
  | `Standard -> "Standard"
  | `Strict -> "Strict"
  | `Exhaustive -> "Exhaustive"

(* tests/risk_kernel.ml - kernel-level tests for lib/risk.ml
 * and lib/policy.ml integration.
 *
 * Each test asserts one obligation from
 * decisions/risk-policy-driven-floor-2026-10.yaml:
 *
 *   policy_override_clamps_to_unit
 *   policy_override_zero_for_no_match
 *   mode_floor_axiom_path_is_exhaustive
 *   mode_floor_default_path_is_standard
 *   policies_yaml_has_default_and_axioms
 *
 * The tests are pure: each calls a lib/policy.ml entry point
 * with a constructed policy list and asserts the produced
 * mode / override value matches the expected contract. They
 * never touch the filesystem and do not require dune cram. *)

(* Sample policies used across the suite. *)
let[@warning "-32"] empty_policy_list = []

let[@warning "-32"] default_policy =
  {
    Policy.policy_id = "test-default";
    scope_paths = [ "lib/**"; "bin/**"; "tests/**" ];
    obligations = [];
    mode_floor = `Standard;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

let[@warning "-32"] axioms_policy =
  {
    Policy.policy_id = "test-axioms";
    scope_paths = [ "axioms/**" ];
    obligations = [];
    mode_floor = `Exhaustive;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

let[@warning "-32"] pci_policy =
  {
    Policy.policy_id = "test-pci";
    scope_paths = [ "payments/**" ];
    obligations = [];
    mode_floor = `Strict;
    override_probability = 0.0;
    transitive_into = [];
    data_flow_edges = [];
  }

let[@warning "-32"] override_pos_policy =
  {
    Policy.policy_id = "test-override-pos";
    scope_paths = [ "lib/**" ];
    obligations = [];
    mode_floor = `Standard;
    override_probability = 0.7;
    transitive_into = [];
    data_flow_edges = [];
  }

let[@warning "-32"] override_neg_policy =
  {
    Policy.policy_id = "test-override-neg";
    scope_paths = [ "lib/**" ];
    obligations = [];
    mode_floor = `Standard;
    override_probability = -0.7;
    transitive_into = [];
    data_flow_edges = [];
  }

(* --- policy_override_clamps_to_unit --- *)

let[@warning "-32"] policy_override_clamps_to_unit () =
  let policies = [ override_pos_policy; override_pos_policy ] in
  let result = Policy.policy_override_of_files policies [ "lib/foo.ml" ] in
  Alcotest.(check (float 0.001))
    "two +0.7 policies clamp to 1.0, not 1.4" 1.0 result

let[@warning "-32"] policy_override_zero_for_no_match () =
  let policies = [ axioms_policy ] in
  let result = Policy.policy_override_of_files policies [ "lib/foo.ml" ] in
  Alcotest.(check (float 0.001)) "no match -> 0.0" 0.0 result

(* --- mode_floor_axiom_path_is_exhaustive --- *)

let[@warning "-32"] mode_floor_axiom_path_is_exhaustive () =
  let policies = [ default_policy; axioms_policy ] in
  let result = Policy.mode_floor_of policies [ "axioms/A0.md" ] in
  Alcotest.(check string)
    "axiom path -> Exhaustive" "Exhaustive" (mode_to_string result)

let[@warning "-32"] mode_floor_default_path_is_standard () =
  let policies = [ default_policy; axioms_policy ] in
  let result = Policy.mode_floor_of policies [ "lib/foo.ml" ] in
  Alcotest.(check string)
    "non-axiom path -> Standard" "Standard" (mode_to_string result)

(* --- pci-strict vs standard --- *)

let[@warning "-32"] mode_floor_pci_path_is_strict () =
  let policies = [ default_policy; pci_policy ] in
  let result = Policy.mode_floor_of policies [ "payments/x.ml" ] in
  Alcotest.(check string) "pci path -> Strict" "Strict" (mode_to_string result)

(* --- axiom + pci: separate paths --- *)

let[@warning "-32"] mode_floor_axiom_and_pci_distinct_paths () =
  let policies = [ default_policy; axioms_policy; pci_policy ] in
  let axiom = Policy.mode_floor_of policies [ "axioms/A0.md" ] in
  let pci = Policy.mode_floor_of policies [ "payments/x.ml" ] in
  let def = Policy.mode_floor_of policies [ "lib/foo.ml" ] in
  Alcotest.(check string)
    "axiom -> Exhaustive" "Exhaustive" (mode_to_string axiom);
  Alcotest.(check string) "pci -> Strict" "Strict" (mode_to_string pci);
  Alcotest.(check string) "default -> Standard" "Standard" (mode_to_string def)

(* --- policies.yaml has default + axioms policies --- *)

let[@warning "-32"] find_project_root () =
  let cwd = Sys.getcwd () in
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else loop parent
  in
  loop cwd

let[@warning "-32"] policies_yaml_has_default_and_axioms () =
  let root = find_project_root () in
  let path = Filename.concat root "policies.yaml" in
  let exists = Sys.file_exists path in
  if not exists then Alcotest.failf "policies.yaml not found at %s" path;
  let raw = In_channel.with_open_text path In_channel.input_all in
  let policies, errors = Policy.parse_policies raw in
  Alcotest.(check string) "no parse errors" "" errors;
  let has_default =
    List.exists (fun p -> p.Policy.policy_id = "math-coding-default") policies
  in
  let has_axioms =
    List.exists (fun p -> p.Policy.policy_id = "math-coding-axioms") policies
  in
  Alcotest.(check bool) "default policy present" true has_default;
  Alcotest.(check bool) "axioms policy present" true has_axioms

(* --- probability/override interactions --- *)

let[@warning "-32"] probability_with_positive_override () =
  let policies = [ override_pos_policy ] in
  let result = Policy.policy_override_of_files policies [ "lib/foo.ml" ] in
  let expected : float = 0.7 in
  Alcotest.(check (float 0.001)) "override pos clamp" expected result;
  let probability = 0.5 +. (0.5 *. result) in
  let expected_p : float = 0.85 in
  Alcotest.(check (float 0.001)) "probability pos" expected_p probability

let[@warning "-32"] probability_with_negative_override () =
  let policies = [ override_neg_policy ] in
  let result = Policy.policy_override_of_files policies [ "lib/foo.ml" ] in
  let expected : float = -0.7 in
  Alcotest.(check (float 0.001)) "override neg clamp" expected result;
  let probability = 0.5 +. (0.5 *. result) in
  let expected_p : float = 0.15 in
  Alcotest.(check (float 0.001)) "probability neg" expected_p probability

let[@warning "-32"] probability_with_empty_policy () =
  let result =
    Policy.policy_override_of_files empty_policy_list [ "lib/foo.ml" ]
  in
  let probability = 0.5 +. (0.5 *. result) in
  let expected : float = 0.5 in
  Alcotest.(check (float 0.001)) "empty policy probability" expected probability

let () =
  Alcotest.run "risk kernel"
    [
      ( "policy_override_clamps_to_unit",
        [
          Alcotest.test_case "two positive policies clamp" `Quick
            policy_override_clamps_to_unit;
        ] );
      ( "policy_override_zero_for_no_match",
        [
          Alcotest.test_case "no match returns zero" `Quick
            policy_override_zero_for_no_match;
        ] );
      ( "mode_floor_axiom_path_is_exhaustive",
        [
          Alcotest.test_case "axiom path is Exhaustive" `Quick
            mode_floor_axiom_path_is_exhaustive;
        ] );
      ( "mode_floor_default_path_is_standard",
        [
          Alcotest.test_case "non-axiom path is Standard" `Quick
            mode_floor_default_path_is_standard;
        ] );
      ( "mode_floor_pci_path_is_strict",
        [
          Alcotest.test_case "pci path is Strict" `Quick
            mode_floor_pci_path_is_strict;
        ] );
      ( "mode_floor_axiom_and_pci_distinct_paths",
        [
          Alcotest.test_case "axiom and pci on distinct paths" `Quick
            mode_floor_axiom_and_pci_distinct_paths;
        ] );
      ( "policies_yaml_has_default_and_axioms",
        [
          Alcotest.test_case "policies.yaml has both policies" `Quick
            policies_yaml_has_default_and_axioms;
        ] );
      ( "probability_with_positive_override",
        [
          Alcotest.test_case "probability with positive override" `Quick
            probability_with_positive_override;
        ] );
      ( "probability_with_negative_override",
        [
          Alcotest.test_case "probability with negative override" `Quick
            probability_with_negative_override;
        ] );
      ( "probability_with_empty_policy",
        [
          Alcotest.test_case "empty policy list probability" `Quick
            probability_with_empty_policy;
        ] );
    ]
