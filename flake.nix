{
  # inputs = { };
  outputs = inputs@{ self, nixpkgs }:
    let
      # dlint and dprint only available on this systems. (github.com releases archieve)
      givenSystems = [ "x86_64-linux" "x86_64-darwin" "x86_64-windows" ];

      # Helpers to instantiate nixpkgs for supported system types.
      give = with nixpkgs.lib; let forAllSystems = f: genAttrs givenSystems (system: f system); in
      f: forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
          node = with pkgs; callPackage ./package-lock.nix { };
        in
        f { inherit pkgs node; inherit (pkgs) system lib stdenv; });

      # check if node2nix (in devShell) already executed
      lockExists = builtins.pathExists ./package-lock.nix;
    in
    {
      # nix develop
      devShell = give ({ pkgs, lib, node, ... }: with pkgs; mkShell {
        inputsFrom = lib.optionals lockExists [ node.shell ];
        packages = with nodePackages; [ node2nix ]
          ++ [ dlint dprint ];

        shellHook = with node.shell;
          if lockExists then ''
            [ -d "node_modules" ] || ln -s ${nodeDependencies}/lib/node_modules node_modules
          '' else ''
            echo "generating package-lock.nix node-pacakges.nix node-env.nix"
            node2nix --composition package-lock.nix \
                     --strip-optional-dependencies \
                     --development
            [ -d ".git" ] && git add package-lock.nix node-packages.nix node-env.nix

            echo -e "\nPlease run$(tput bold) nix develop $(tput sgr0)again."
            exit
          '';
      });

      # extra pkgs
      overlay = final: prev: with prev.lib; mapAttrs
        (pname: value@{ version ? "latest", bin ? pname, ... }: with final; let
          target = with systems.parse; tripleFromSystem (mkSystemFromString system);
          integrity' = mapAttrs
            (name: package:
              if package ? ${system} then package.${system} else
              if package ? ${target} then package.${target}
              else package)
            integrity;
        in
        stdenv.mkDerivation {
          inherit pname version;
          # since it only available in .zip
          src = fetchzip (integrity'.${pname} // {
            url = with value;
              if value ? github then "https://github.com/${github}/releases/${version}/download/${pname}-${target}.zip"
              else url;
          });
          installPhase = ''
            install -m755 -D ${bin} $out/bin/${pname}
          '';
        })
        (recursiveUpdate (import ./integrity.nix) {
          dlint.github = "denoland/deno_lint";
          dprint.github = "dprint/dprint";
        });
    };
}
