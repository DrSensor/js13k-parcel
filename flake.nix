{
  inputs = {
    npmlock2nix.url = "github:nix-community/npmlock2nix";
    npmlock2nix.flake = false;
  };
  outputs = inputs@{ self, nixpkgs, ... }:
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
      #> nix develop
      devShell = give ({ pkgs, mkYarnShell, ... }: mkYarnShell {
        src = ./.;
        pkgConfig.sharp = with pkgs; {
          nativeBuildInputs = [ pkg-config ]; # ++ [ nodePackages.node-gyp nodejs python3 ];
          buildInputs = with nodePackages; [ vips node-gyp ]; #++ [ python3 nodejs pkgconfig ];
          # yarnPreBuild = ''
          #   mkdir -p $HOME/.node-gyp/${nodejs.version}
          #   echo 9 > $HOME/.node-gyp/${nodejs.version}/installVersion
          #   ln -sfv ${nodejs}/include $HOME/.node-gyp/${nodejs.version}
          #   export npm_config_nodedir=${nodejs}
          # '';
          postInstall = ''
            node-gyp rebuild
          '';
        };
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
        # nodejs = prev.nodejs-16_x;
        # nodejs-headers = with final; fetchTarball {
        #   name = "node-v${nodejs.version}-headers";
        #   url = "https://nodejs.org/download/release/v${nodejs.version}/node-v${nodejs.version}-headers.tar.gz";
        #   sha256 = "sha256:0cnax7hi0f0iwk3yvbzggl2f10dvlmwwwwiaf7jabbb065snkf23"; # 14.17.6
        #   # sha256 = "sha256:1a9y9al9n79axzwjqk9ybi5hv9y8z1dkafhv3vncv3vvfpklq2sc"; # 16.8.0
        # };
        mkYarnShell = with final; attrs@{ src, yarnLock ? src + "/yarn.lock", ... }: with yarn2nix-moretea;
          if pathExists yarnLock then
            mkYarnPackage
              (attrs // {
                extraBuildInputs = (attrs.buildInputs or [ ]) ++ (attrs.packages or [ ]);
                nativeBuildInputs = (attrs.inputsFrom or [ ]) ++ (attrs.nativeBuildInputs or [ ]);
                shellHook = linkNodeModulesHook + ''
                  export NODE_PATH=$node_modules
                  export PATH=$node_modules/.bin/:$PATH
                '';
                # avoid rebuild yarn2nix
                yarnNix = attrs.yarnNix or runCommand "yarn.nix" { } ''
                  export PATH=${makeBinPath [ yarn2nix ]}:$PATH
                  yarn2nix --lockfile ${yarnLock} --no-patch > $out
                '';
              })
          else # auto-generate yarn.lock
            let missing-npmLock = !(pathExists (src + "/package-lock.json")); in
            mkShell {
              packages = [ yarn ] ++ optional missing-npmLock nodejs;
              shellHook = ''
                trap "mv package.json{.backup,}" INT
                set -e ignoreeof

                cp package.json{,.backup}
              '' + (optionalString missing-npmLock ''
                npm --version; npm install --package-lock-only
              '') + ''
                yarn import
                mv package.json{.backup,}
                git add package-lock.json yarn.lock

                echo -e "Please run$(tput bold) nix develop $(tput sgr0)again!\n"
                exit
              '';
            };
      };
    };
}
