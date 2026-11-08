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
        #
        # THE LIBRARIES MUST BE HERE, AND THEY WERE NOT. The package
        # built with the compiler and dune alone, and the build died on
        # "Library yojson not found" - while the development shell,
        # which has the same dependencies, worked. So the one thing an
        # adopting project needs - the binary - could not be built by
        # the flake at all, and nobody had built it that way: the method
        # had only ever been built in its own shell.
        #
        # A path that nobody walks is not a path. The package and the
        # shell now take the same dependencies and the same library
        # path, so the binary that the flake hands out is the binary
        # that the tests run.
        packages.default = pkgs.stdenv.mkDerivation {
          name = "mathc";
          src = ./.;
          nativeBuildInputs = [ ocamlPackages.ocaml ocamlPackages.dune_3 ] ++ ocamlDeps;
          buildInputs = [ pkgs.git ] ++ ocamlDeps;
          OCAMLPATH = ocamlPath;
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

        # The measurement stand, as a package of its own.

        # The procedure of the measurement runs the stand, and a person
        # who wants to know what the method costs must be able to run it
        # too. The measurement of 2026-11-01 told the reader to run
        # `_build/default/bin/stand.exe` - a path inside a build tree
        # that an adopter does not have. A path that nobody walks is
        # not a path.
        packages.stand = pkgs.stdenv.mkDerivation {
          name = "stand";
          src = ./.;
          nativeBuildInputs = [ ocamlPackages.ocaml ocamlPackages.dune_3 ] ++ ocamlDeps;
          buildInputs = [ pkgs.git ] ++ ocamlDeps;
          OCAMLPATH = ocamlPath;
          buildPhase = ''
            runHook preBuild
            dune build --root . bin/stand.exe
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp _build/default/bin/stand.exe $out/bin/stand
            runHook postInstall
          '';
        };

        # THE SAME TOOL, FOR A MACHINE THAT IS NOT A NIX MACHINE.
        #
        # The binary needs three C libraries and nothing else - the
        # OCaml runtime is already inside it (OCaml 5 links it in by
        # default). What ties it to this machine is the runpath: it
        # points at the C library in the nix store, so an adopter
        # outside nix would be sent after a library it does not have.
        # Here the runpath is removed, and the binary asks the system
        # for its libc - which every ordinary Linux has.
        #
        # THE GUIDE IS IN THE TOOL NOW, NOT BESIDE IT. The page for an
        # agent used to travel here as a file - and it was the page of
        # THIS repository, naming this repository's tree, so an adopter
        # who took it got a page about somebody else's project. The page
        # is GENERATED now (`mathc install`), out of the tool's own
        # help and the adopting project's own specification, so it
        # cannot name a verb that does not exist and it is about the
        # project it is installed in. The guide travels with the tool
        # because the tool without the guide is what the agent arm
        # measured: 35 tool calls spent reading the source to learn the
        # interface.
        packages.portable = pkgs.stdenv.mkDerivation {
          name = "mathc-portable";
          src = ./.;
          nativeBuildInputs = [ ocamlPackages.ocaml ocamlPackages.dune_3 pkgs.patchelf ]
            ++ ocamlDeps;
          buildInputs = [ pkgs.git ] ++ ocamlDeps;
          OCAMLPATH = ocamlPath;
          buildPhase = ''
            runHook preBuild
            dune build --root . bin/mathc.exe bin/stand.exe
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp _build/default/bin/mathc.exe $out/bin/mathc
            cp _build/default/bin/stand.exe $out/bin/stand
            runHook postInstall
          '';
          # The fixup would put the store's C library back into the
          # runpath; the point of this output is that it does not.
          postFixup = ''
            patchelf --remove-rpath $out/bin/mathc
          '';
        };
      });
}
