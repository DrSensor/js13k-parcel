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
      f: forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
          node.shell = with pkgs.lib; let
            inherit (pkgs) nodePackages callPackage nodeEnv;
            node = callPackage ./node-packages.nix { };
            args = overrideExisting node.args {
              dependencies = map
                (source@{ name, ... }:
                  if integrity ? ${name} then
                    (overrideExisting source rec {
                      version =
                        if nodePackages ? ${name} then nodePackages.${name}.version
                        else pkgs.${name}.version;
                      src = pkgs.fetchurl (integrity.${name} // {
                        url = "https://registry.npmjs.org/${name}/-/${name}-${version}.tgz";
                      });
                    })
                  else source)
                (filter
                  ({ packageName, ... }: # TODO: match version
                    let pkgName = last (splitString "/" packageName); in
                    nodePackages ? ${pkgName} || pkgs ? ${pkgName})
                  node.args.dependencies);
            };
            nativeBuildInputs = with pkgs; with nodePackages; [ node-gyp-build pkg-config ];
            nodeDependencies = filterAttrs
              (name: drv:
                let dependencies = map ({ packageName, ... }: last (splitString "/" packageName)) args.dependencies;
                in any ({ packageName, ... }: packageName == name) dependencies)
              nodePackages // pkgs;
            nodeDependenciesWithout = drvs: filterAttrs (name: val: any (drv: drv.name == name) drvs) nodeDependencies;
          in
          with pkgs; (nodeEnv.buildNodeShell args).override {
            inherit nativeBuildInputs;
            buildInputs = [ vips ] ++ nodeDependenciesWithout nativeBuildInputs;
            ESBUILD_BINARY_PATH = "${esbuild}/bin/esbuild";
            # npmFlags = "--sharp-local-prebuilds=${vips}/bin/vips";
            # preRebuild = ''
            #   npm config set sharp_local_prebuilds ${vips}/bin/vips
            #   # export npm_config_sharp_local_prebuilds=${vips}/bin/vips
            #   export ESBUILD_BINARY_PATH=${esbuild}/bin/esbuild
            # '';
          };
        in
        f { inherit pkgs node; inherit (pkgs) system lib stdenv; });

      # check if node2nix (in devShell) already executed
      lockExists = builtins.pathExists ./node-packages.nix;
    in
    {
      #> nix develop
      devShell = give ({ pkgs, node, lib, ... }: with pkgs; mkShell {
        inputsFrom = lib.optionals lockExists [ node.shell ];
        packages = with nodePackages; [ node2nix ]
          ++ [ dlint dprint ];

        shellHook = with node.shell;
          if lockExists then ''
            [ -d "node_modules" ] || ln -s ${nodeDependencies}/lib/node_modules node_modules
          ''
          else ''
            echo "generating node-pacakges.nix node-env.nix"
            node2nix --composition /dev/null \
                     --strip-optional-dependencies \
                     --development
            [ -d ".git" ] && git add node-packages.nix node-env.nix

            echo -e "\nPlease run$(tput bold) nix develop $(tput sgr0)again."
            exit
          '';
      });

      # extra pkgs
      overlay = final: prev: with prev.lib; (mapAttrs
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
        }))
      ) // {
        nodeEnv = final.callPackage ./node-env.nix { };
        esbuild = final.esbuild.override {
          version = with lib; let
            node = final.callPackage ./node-packages.nix { };
            sources = mapAttrs'
              (name: source: nameValuePair
                (getName (last (splitString "/" name)))
                source)
              node.sources;
          in
          sources.esbuild.version;
        };
      };
    };
}
