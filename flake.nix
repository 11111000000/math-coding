{
  description = "math-coding 3.0-alpha — risk-adaptive assurance protocol";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
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
      });
}
