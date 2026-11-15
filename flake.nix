{
  description = "math-coding v5 — source-linked evidence and re-evaluation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/e94cb152ed51bd6e24eb4a41f1460252beb52cd2";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ocamlPackages = pkgs.ocamlPackages;
        minimalOcamlDeps = packageSet: with packageSet; [ yojson digestif eqaf omd xmlm uutf uchar ];
        ocamlDeps = (with ocamlPackages; [ ocaml dune_3 ]) ++ minimalOcamlDeps ocamlPackages;
        staticOcamlPackages = pkgs.pkgsStatic.ocamlPackages.overrideScope (_: super: {
          yojson = super.yojson.overrideAttrs (_: { doCheck = false; });
          digestif = super.digestif.overrideAttrs (_: { doCheck = false; });
          omd = super.omd.overrideAttrs (_: { doCheck = false; });
          xmlm = super.xmlm.overrideAttrs (_: { doCheck = false; });
        });
        siteLibs = packageSet: pkg: "${pkg}/lib/ocaml/${packageSet.ocaml.version}/site-lib";
        ocamlPath = pkgs.lib.concatMapStringsSep ":" (siteLibs ocamlPackages) ocamlDeps;
        mkBinary = { name, target }:
          pkgs.stdenv.mkDerivation {
            inherit name;
            src = ./.;
            nativeBuildInputs = [ ocamlPackages.ocaml ocamlPackages.dune_3 ] ++ ocamlDeps;
            buildInputs = minimalOcamlDeps ocamlPackages;
            OCAMLPATH = ocamlPath;
            buildPhase = ''
              runHook preBuild
              dune build --root . ${target}
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp _build/default/${target} $out/bin/${name}
              runHook postInstall
            '';
          };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "math-coding-5-dev";
          packages = ocamlDeps ++ (with pkgs; [ bash git coreutils findutils gnused nodejs_22 ]);
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
            export OCAMLPATH="${ocamlPath}"
            # The notice goes to stderr: `nix develop -c mathc map --json` must
            # produce nothing but the map on stdout, and the banner is the
            # shell's chatter, not the method's answer.
            echo "math-coding 5 dev shell" >&2
            echo "  dune:   $(which dune)" >&2
            echo "  ocaml:  $(ocaml --version)" >&2
            echo "" >&2
            echo "  build:  dune build --root ." >&2
            echo "  test:   dune runtest --root . --force" >&2
            echo "  method: dune exec --root . ./bin/mathc.exe -- map" >&2
          '';
        };

        packages.default = mkBinary { name = "mathc"; target = "bin/mathc.exe"; };
        packages.stand = pkgs.symlinkJoin {
          name = "mathc-with-stand";
          paths = [
            (mkBinary { name = "mathc"; target = "bin/mathc.exe"; })
            (mkBinary { name = "stand"; target = "bin/stand.exe"; })
          ];
        };

        packages.portable = pkgs.pkgsStatic.stdenv.mkDerivation {
          name = "mathc-portable";
          src = ./.;
          nativeBuildInputs = [ staticOcamlPackages.ocaml staticOcamlPackages.dune_3 ]
            ++ minimalOcamlDeps staticOcamlPackages;
          buildInputs = minimalOcamlDeps staticOcamlPackages;
          OCAMLPATH = pkgs.lib.concatMapStringsSep ":" (siteLibs staticOcamlPackages)
            (minimalOcamlDeps staticOcamlPackages);
          NIX_LDFLAGS = "-static";
          dontPatchElf = true;
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
        };
      });
}
