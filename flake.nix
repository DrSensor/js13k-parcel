{
  # inputs = { };
  outputs = inputs@{ self, nixpkgs }:
    let
      # dlint and dprint only available on this systems. (github.com releases archieve)
      givenSystems = [ "x86_64-linux" "x86_64-darwin" "x86_64-windows" ];

      # collection of hash value for external/patched packages
      integrity = import ./integrity.nix;

      # Helpers to instantiate nixpkgs for supported system types.
      give = with nixpkgs.lib; let forAllSystems = f: genAttrs givenSystems (system: f system); in
      f: forAllSystems (system: f (import nixpkgs { inherit system; overlays = [ self.overlay ]; }));
    in
    {
      # nix develop
      devShell = give ({ pkgs, mkShell, lib, ... }: with lib;
        let packageManagers = with pkgs.nodePackages;
        (optional (pathExists ./pnpm-lock.yaml) pnpm) ++
        (optional (pathExists ./yarn.lock) yarn) ++
        (optional
          ((hasInfix "slim" pkgs.nodejs) && (
            (pathExists ./package-lock.json) ||
            (all (lock: !(pathExists lock)) [ ./yarn.lock ./pnpm-lock.yaml ])
          ))
          npm); in
        mkShell {
          packages = with pkgs; [ nodejs dlint dprint ] ++ packageManagers
            # some native packages related to package.json
            ++ [ vips ] # npm:sharp which used by npm:@parcel/transformer-image
            ++ [ pkg-config ]; # to make dynamic linking of libs from nixpkgs working
          shellHook = with pkgs.nodePackages; ''
            function oninterrupt {
              mv package.json{.backup,}
              rm -fr node_modules
            }
            cp package.json{,.backup}
            trap "oninterrupt" EXIT INT

            chmod +x scripts/*
          '' + (
            if 0 == count isDerivation packageManagers
            then ''
              [ -d node_modules ] || npm install
            ''
            else if pathExists ./package-lock.json
            then ''
              [ -d node_modules ] || npm install
              for pkg in ${toString (remove npm (map nodePackages-getName packageManagers))}
                do $pkg import
              done
            ''
            else ''
              if [ ! -d node_modules ]
                then ${nodePackages-getName (head packageManagers)} install
                for pm in ${toString (map nodePackages-getName (tail packageManagers))}
                do
                  [ $pm == npm  ] && npm install --package-lock-only
                  [ $pm == yarn ] && yarn generate-lock-entry
                  [ $pm == pnpm ] && pnpm install --lockfile-only
              done; fi
            ''
          ) + ''
            mv package.json{.backup,}
            trap - EXIT INT
            export NODE_PATH=$(realpath ./node_modules)
            export PATH=$(realpath ./node_modules/.bin):$(realpath ./scripts):$PATH
          '';
        });

      # extra pkgs
      overlay = final: prev: with prev.lib; {
        lib = prev.lib // rec {
          nodePackages-prefix = "node_";
          nodePackages-getName = drv: removePrefix nodePackages-prefix (getName drv);
        };
      } // mapAttrs
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
        (filterAttrs (name: value: value ? github || value ? url) (recursiveUpdate integrity {
          dlint.github = "denoland/deno_lint";
          dprint.github = "dprint/dprint";
        }));
    };
}
