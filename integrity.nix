{
  # use `nix run -- nixpkgs#nix-prefetch fetchzip --url -E "https://github.com/${owner}/${repo}/releases/latest/download/${name}-${target}.zip""`
  # dprint.x86_64-linux.sha256 = "";
  # dlint.x86_64-linux.sha256 = "";
  # dprint.x86_64-darwin.sha256 = "";
  # dlint.x86_64-darwin.sha256 = "";
  # dprint.x86_64-windows.sha256 = "";
  # dlint.x86_64-windows.sha256 = "";

  # use `nix run -- nixpkgs#nix-prefetch fetchzip --url -E "https://registry.npmjs.org/${packageName}/-/${packageName}-${version}.tgz"`
  # esbuild.sha512 = "";
  # https://github.com/msteen/nix-prefetch/issues/3#issuecomment-876771025
  # nix-prefetch '{ sha256 }: (callPackage (import ./default.nix) { }).go-modules.overrideAttrs (_: { modSha256 = sha256; })'
}
