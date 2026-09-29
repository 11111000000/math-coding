{
  description = "math-coding 3.0-alpha — risk-adaptive assurance protocol";

  inputs = {
    # Pinned to commit e94cb152ed51bd6e24eb4a41f1460252beb52cd2
    # (current flake.lock value). Do NOT change without a
    # decisions/decision.yaml revision listing old and new narHash
    # (axiom A3: self-application).
    nixpkgs.url = "github:NixOS/nixpkgs/e94cb152ed51bd6e24eb4a41f1460252beb52cd2";
    flake-utils.url = "github:numtide/flake-utils";
    # pre-commit-hooks.nix provides shellcheck + nix-flake-check hooks
    # for the fmt check derivation (see obligation
    # ocamlformat-fmt-clean); ocamlformat itself runs through `dune
    # fmt` and is added to ocamlDeps below.
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = { self, nixpkgs, flake-utils, pre-commit-hooks }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ocamlPackages = pkgs.ocamlPackages;
        ocamlVersion = ocamlPackages.ocaml.version;
        ocamlSelect = p: [ p.dune_3 ];
        # All OCaml packages needed for tests, including transitive deps
        # of alcotest. nix-shell does not auto-resolve transitive closures
        # for findlib-style sites; we enumerate them explicitly.
        ocamlDeps = with ocamlPackages; [
          ocaml
          alcotest
          astring
          fmt
          cmdliner
          uutf
          seq
          re
          stdlib-shims
          # ocamlformat (conventional profile; see .ocamlformat) is
          # the formatter backend for `dune fmt`. Pinned at 0.29.x by
          # the current nixpkgs revision.
          ocamlformat
        ];
        buildTools = with pkgs; [
          bashInteractive
          git
          gnumake
          gnused
          gnugrep
          coreutils
          findutils
          diffutils
          which
          jq
          shellcheck
          shfmt
          nixpkgs-fmt
          prettier
          pandoc
        ];
        siteLibs = pkg: "${pkg}/lib/ocaml/${ocamlVersion}/site-lib";
        ocamlPath = pkgs.lib.concatMapStringsSep ":" siteLibs ocamlDeps;
      in
      {
        # Default shell: kernel + CLI only.
        devShells.default = pkgs.mkShell {
          name = "math-coding-dev";
          packages = [
            ocamlPackages.ocaml
          ] ++ ocamlSelect ocamlPackages ++ buildTools;
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
            echo "math-coding 3.0-alpha dev shell (kernel only)"
            echo "  dune:   $(which dune)"
            echo "  ocaml:  $(ocaml --version)"
            echo ""
            echo "  run 'dune build' to compile kernel + CLI"
            echo "  run 'nix develop .#test' to enable alcotest"
            echo "  run 'mc validate FILE' to validate a decision"
          '';
        };

        # Test shell: kernel + CLI + conformance suite.
        devShells.test = pkgs.mkShell {
          name = "math-coding-dev-test";
          packages = ocamlDeps ++ ocamlSelect ocamlPackages ++ buildTools;
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
            export OCAMLPATH="${ocamlPath}"
            echo "math-coding 3.0-alpha dev shell (with tests)"
            echo "  dune:    $(which dune)"
            echo "  ocaml:   $(ocaml --version)"
            echo "  alcotest: via dune-package"
            echo "  OCAMLPATH entries: $(echo "$OCAMLPATH" | tr ':' '\n' | wc -l)"
            echo ""
            echo "  run 'dune test' to run conformance suite"
            echo "  run 'dune build' to compile kernel + CLI"
            echo "  run 'mc validate FILE' to validate a decision"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          name = "mathc";
          src = ./.;
          nativeBuildInputs = [
            ocamlPackages.ocaml
          ] ++ ocamlSelect ocamlPackages;
          buildInputs = [ pkgs.git ];
          buildPhase = ''
            runHook preBuild
            dune build --root . bin/mathc.exe
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp _build/default/bin/mathc.exe $out/bin/mathc
            runHook postInstall
          '';
        };

        checks.default = pkgs.stdenv.mkDerivation {
          name = "math-coding-tests";
          src = ./.;
          nativeBuildInputs = ocamlDeps ++ ocamlSelect ocamlPackages;
          buildPhase = ''
            runHook preBuild
            export OCAMLPATH="${ocamlPath}"
            dune build --root . @tests/runtest
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            touch $out/ok
            runHook postInstall
          '';
        };

         # ocamlformat-fmt-clean: pre-commit-hooks.nix run for shellcheck
        # and ocamlformat. The dune-fmt check itself is in scripts/fmt-check.sh,
        # invoked by the fmt-clean fixture; it is also wired here via the
        # ocamlformat hook so `nix flake check` catches formatting drift on every
        # commit, not only when scripts/check.sh runs.
        #
        # Plus a decision-fixture-co-commit hook: a commit that touches
        # any kernel/protected file under lib/ or bin/ or spec/ MUST
        # also touch at least one decisions/*.yaml (decisions) and at
        # least one tests/fixtures/*.sh (fixture) in the same commit,
        # OR be a pure-deferral decision. This closes the T4/T6-style
        # "kernel change without decisions entry" deficit observed
        # in the 2026-09-27 session (see ROADMAP.md §P1). Implemented
        # as a tiny shell script invoked from pre-commit-hooks.nix.
        checks.fmt = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            shellcheck = {
              enable = true;
              # Excluded rules (documented per-rule):
              #   SC2164 — `cd $(dirname $0)/../..` warns "use cd ...
              #            || exit". The codebase pattern uses
              #            `set -uo pipefail` at the top of every
              #            shell script; under pipefail a failed cd
              #            really does abort the script, and
              #            rewriting 17 fixture files is out of scope
              #            for the fmt obligation.
              #   SC2016 — single-quoted `bash -c '...'` snippets
              #            (see trap log §11.9). The pattern is
              #            intentional so nix-develop's outer shell
              #            does not expand `$` inside the nix shell.
              # -S INFO downgrades everything from "warning" to
              # "info" so a single unused-variable note doesn't fail
              # the build.
              args = [ "-e" "SC2164" "-e" "SC2016" "-S" "info" ];
            };
            ocamlformat = {
              enable = true;
              # Pin to the conventional profile; see .ocamlformat.
              args = [ "--profile" "conventional" "-m" "80" ];
            };
            # decision-fixture-co-commit: ensure that any commit
            # touching kernel files (lib/, bin/Mathc.ml, spec/) also
            # touches decisions/*.yaml (decision) and tests/fixtures/*.sh
            # (fixture). The script returns nonzero when the rule is
            # violated; pre-commit-hooks.nix surfaces the failure
            # before the commit lands.
            decision-fixture-co-commit = {
              enable = true;
              entry = ./scripts/pre-commit/decision-fixture-co-commit.sh;
              types = [ "ocaml" "shell" "markdown" "yaml" ];
              pass_filenames = true;
            };
          };
        };
      });
}
