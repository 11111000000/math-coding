{
  description = "math-coding 4 — the fourth version, from nothing";

  # The same nixpkgs pin the third version uses. Two reasons, and the
  # second is the important one: the pin is a decision, not a
  # convenience, and reusing it means the sources are already in the
  # store, so the build is hermetic *and* works without a network.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/e94cb152ed51bd6e24eb4a41f1460252beb52cd2";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ocamlPackages = pkgs.ocamlPackages;

        # The toolchain, and nothing else. The fourth version has no
        # CI, no site, no plugin, no scripts: it is a library, a
        # binary, a specification and its checks. Every dependency
        # below is here because something in the tree needs it, and
        # "something in the tree" means a named library or a named
        # tool - not a habit carried from the third version.
        ocamlDeps = with ocamlPackages; [
          ocaml
          dune_3
          # JSON is read with a library, never with a parser of our
          # own. The standing specification and the wave format are
          # data; the laws that read them are OCaml.
          yojson
          # yojson's own runtime dependencies, named because a
          # findlib-style site is not resolved transitively by
          # nix-shell.
          digestif
          re
          uutf
          uchar
          base64
          cmdliner
        ];

        # The tools the checks shell out to. A check is a command the
        # project names; if that command lives outside the toolchain,
        # the check means different things on different machines, and
        # "green on my laptop" is not evidence.
        buildTools = with pkgs; [
          bash
          git
          coreutils
          findutils
          gnused
        ];

        siteLibs = pkg: "${pkg}/lib/ocaml/${ocamlPackages.ocaml.version}/site-lib";
        ocamlPath = pkgs.lib.concatMapStringsSep ":" siteLibs ocamlDeps;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "math-coding-4-dev";
          packages = ocamlDeps ++ buildTools;
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
            export OCAMLPATH="${ocamlPath}"
            echo "math-coding 4 dev shell"
            echo "  dune:   $(which dune)"
            echo "  ocaml:  $(ocaml --version)"
            echo ""
            echo "  build:  dune build --root ."
            echo "  test:   dune runtest --root . --force"
            echo "  method: dune exec --root . ./bin/mathc.exe -- map"
          '';
        };

        # The binary. Named `mathc`, because the name was fixed before
        # the code existed and a name decided later is a name nobody
        # remembers to use.
        packages.default = pkgs.stdenv.mkDerivation {
          name = "mathc";
          src = ./.;
          nativeBuildInputs = [
            ocamlPackages.ocaml
            ocamlPackages.dune_3
          ];
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
      });
}
