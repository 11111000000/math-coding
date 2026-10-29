{
  description = "math-coding 3.3.3 — risk-adaptive assurance protocol";

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
          ounit2
          qcheck
          qcheck-core
          qcheck-ounit
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
          # merlin + ocaml-lsp enable `.merlin`-driven IDE tooling.
          # ocaml-lsp 1.27.0 wraps the merlin backend and exposes
          # the LSP protocol; editors (VSCode ocaml-platform,
          # neovim nvim-lspconfig, emacs lsp-mode) start this
          # binary when opening *.ml files. `.merlin` at the
          # project root is hand-written because the dune version
          # pinned in this nixpkgs revision has the
          # `(using merlin-conf ...)` extension removed.
          merlin
          ocaml-lsp
        ];
        # The tools the conformance suite SHELLS OUT TO. A test that
        # calls `rg` or `yq` must find the SAME tool the developer
        # found, or the suite is green on one machine and red on
        # another -- the failure mode measured on 2026-10-27, when
        # three cram fixtures passed locally (the tools were in the
        # ambient system PATH) and failed in CI (the runner image
        # has yq 4.x, no ripgrep, and a different python3).
        #
        # `yq` here is the kislyuk jq-wrapper (3.x), NOT mikefarah's
        # Go implementation (4.x): the fixtures assert the jq-wrapper's
        # output shape, and the two differ. Declaring the version is
        # what makes the assertion mean anything.
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
          ripgrep
          yq
          python3
          curl
        ];
        siteLibs = pkg: "${pkg}/lib/ocaml/${ocamlVersion}/site-lib";
        ocamlPath = pkgs.lib.concatMapStringsSep ":" siteLibs ocamlDeps;
      in
      {
        # Default shell: kernel + CLI only.
        # `render` helper: closes site-deploy@1 obligation
        # `render-kernel-impl`. The script builds mathc via
        # scripts/dev build, runs `mathc render --out dist/`, copies
        # assets/, and verifies the output allowlist; non-zero on any
        # missing file (so it is its own attestation, per the
        # decision's declared acceptance verifiers).
        # `mathc` is NOT on PATH in EITHER devShell. It exists only as
        # `packages.default` below, and `mkShell` does not put a package
        # derivation on PATH -- its `packages` list is `ocamlDeps ++ dune
        # ++ buildTools`, none of which is the binary. The shellHook
        # banner in both shells used to advertise `run 'mathc validate
        # FILE'`, a command the shell cannot resolve; on a machine with
        # no stray ~/.local/bin/mathc that advice is a `command not
        # found`. Both banners now name a build path that was verified
        # to work. See decisions/gate-truth-mathc-path-2026-10.yaml.
        devShells.default = pkgs.mkShell {
          name = "math-coding-dev";
          packages = [
            ocamlPackages.ocaml
          ] ++ ocamlSelect ocamlPackages ++ buildTools;
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
            echo "math-coding 3.3.3 dev shell (kernel only)"
            echo "  dune:   $(which dune)"
            echo "  ocaml:  $(ocaml --version)"
            echo ""
            echo "  run 'scripts/render.sh' to render the site (site-deploy@1: render-kernel-impl)"
            echo "  run 'dune build bin/mathc.exe' to compile kernel + CLI"
            echo "  run 'nix develop .#test' to enable alcotest"
            echo "  validate a decision: '_build/default/bin/mathc.exe validate FILE'"
          '';
        };

        # Test shell: kernel + CLI + conformance suite.
        # `render` helper: closes site-deploy@1 obligation
        # `render-kernel-impl` (same script as in devShells.default;
        # included here so the test-shell oneline mirrors the default-
        # shell oneline and a developer who `nix develop .#test` to
        # run conformance + render in one session sees the entry).
        devShells.test = pkgs.mkShell {
          name = "math-coding-dev-test";
          packages = ocamlDeps ++ ocamlSelect ocamlPackages ++ buildTools;
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
            export OCAMLPATH="${ocamlPath}"
            echo "math-coding 3.3.3 dev shell (with tests)"
            echo "  dune:    $(which dune)"
            echo "  ocaml:   $(ocaml --version)"
            echo "  alcotest: via dune-package"
            echo "  OCAMLPATH entries: $(echo "$OCAMLPATH" | tr ':' '\n' | wc -l)"
            echo ""
            echo "  run 'scripts/render.sh' to render the site (site-deploy@1: render-kernel-impl)"
            echo "  run 'dune test' to run conformance suite"
            echo "  run 'dune build' to compile kernel + CLI"
            echo "  validate a decision: 'dune build --root . && _build/install/default/bin/mathc validate FILE'"
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
        # apps.default: enables `nix run github:11111000000/math-coding
        # -- <args>`. Closes `decisions/install-tooling-2026-10.yaml`
        # outcome `nix-run-derivation-exists`. The same `mathc`
        # binary ships as `packages.default`; the `apps` stanza is
        # the no-install entry path for Nix users. The
        # `self.packages.${system}.default` reference is explicit
        # so the evaluator resolves to the top-level packages
        # attr rather than the inner `packages` field of
        # `devShells.default = pkgs.mkShell { packages = [...]; }`
        # at line 87 (which would otherwise shadow the path lookup).
        apps = rec {
          mathc = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/mathc";
          };
          default = mathc;
        };

        checks.default = pkgs.stdenv.mkDerivation {
          name = "math-coding-tests";
          src = ./.;
          # python3 is needed by the forge stub the CLI's forge
          # verifier talks to; curl and git are needed by the
          # fixtures. All three were missing here, and the build had
          # been failing behind the red CI step for weeks.
          nativeBuildInputs = ocamlDeps ++ ocamlSelect ocamlPackages ++ [ pkgs.python3 pkgs.curl pkgs.git ];
          buildPhase = ''
            runHook preBuild
            export OCAMLPATH="${ocamlPath}"
            # `dune test`, not `dune build @tests/runtest`: the
            # former RUNS the suite with dune's own sandbox (the
            # cram tests get the binary and the fixtures through the
            # declared deps), the latter only builds.
            # The cram tests call the kernel through
            # $INSIDE_DUNE/bin/mathc.exe, so dune builds the binary
            # for them: the deps name the real target, `mathc.exe`.
            dune test --root .
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
              # `entry = "${pkgs.shellcheck}/bin/shellcheck"` is the
              # upstream default; redeclared here so the entry is
              # resolved at flake-eval time even when other hooks in
              # the same `checks.fmt` use explicit `entry`. Without
              # this, pre-commit-hooks.nix sometimes evaluates the
              # `args` accessor before `entry` is finalised and
              # throws "no value defined".
              entry = "${pkgs.shellcheck}/bin/shellcheck";
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
              # ocamlformat is not a built-in pre-commit-hooks.nix
              # hook, so `entry` must be set explicitly. We resolve
              # it from the same `ocamlPackages.ocamlformat` that the
              # devShell uses, so the fmt check matches the editor
              # invocation.
              # `--check` and ONE file per invocation: the upstream
              # hook passes every file at once, and ocamlformat
              # refuses more than one input unless --check is given.
              # The profile and the margin come from the repository's
              # own .ocamlformat, so the hook and `dune fmt` cannot
              # disagree about the shape.
              # The project's OWN format check, not a second one:
              # `scripts/fmt-check.sh` is what `dune fmt --preview`
              # means here, and the hook and the developer cannot
              # disagree about the shape of the tree. The hook is
              # given no file names: the check is of the tree.
              # The project's OWN format check, run with the
              # tools it needs on PATH: `scripts/fmt-check.sh` asks
              # `ocamlformat --check` (dune's own `fmt --preview`
              # takes a lock and has nothing to do with
              # formatting). The hook and the developer cannot
              # disagree about the shape of the tree, and the check
              # is of the tree, not of the files the commit touched.
              entry = "${pkgs.writeShellScript "mathc-fmt-check" ''
                export PATH=${pkgs.lib.makeBinPath [ ocamlPackages.ocamlformat ]}:$PATH
                export MATH_CODING_ROOT="$PWD"
                exec bash ${./scripts/fmt-check.sh}
              ''}";
              pass_filenames = false;
            };
            # decision-fixture-co-commit: ensure that any commit
            # touching kernel files (lib/, bin/Mathc.ml, spec/) also
            # touches decisions/*.yaml (decision) and tests/fixtures/*.sh
            # (fixture). The script returns nonzero when the rule is
            # violated; pre-commit-hooks.nix surfaces the failure
            # before the commit lands.
            decision-fixture-co-commit = {
              enable = true;
              entry = "scripts/pre-commit/decision-fixture-co-commit.sh";
              types = [ "ocaml" "shell" "markdown" "yaml" ];
              pass_filenames = true;
            };
          };
        };
      });
}
