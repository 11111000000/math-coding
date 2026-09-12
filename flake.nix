{
  description = "math-coding v1.0 — Curry-Howard convention for AI coding agents";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ocamlPackages = pkgs.ocamlPackages;
        ocamlSelect = p:
          [ p.dune_3 p.findlib p.yaml p.yojson p.alcotest p.qcheck ];
      in
      {
        devShells.default = pkgs.mkShell {
          name = "math-coding-dev";
          packages = [ ocamlPackages.ocaml ] ++ ocamlSelect ocamlPackages ++ (with pkgs; [
            git
            pkg-config
            gnumake
          ]);
          shellHook = ''
            export PATH="${ocamlPackages.ocaml}/bin:$PATH"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          name = "math-coding";
          src = ./.;
          nativeBuildInputs = [ ocamlPackages.ocaml ] ++ ocamlSelect ocamlPackages;
          buildInputs = [ pkgs.git pkgs.pkg-config ];
          buildPhase = ''
            runHook preBuild
            dune build --profile=release
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin $out/libexec/math-coding
            install -Dm755 _build/default/math-coding $out/bin/math-coding
            install -Dm755 scripts/install.sh $out/libexec/math-coding/install.sh
            cp -r docs $out/libexec/math-coding/docs
            runHook postInstall
          '';
        };
      });
}
