{
  description = "Zenn CLI environment";

  # == usage ==
  # 1. edit node-pkgs/package.json to specify the package name and version
  #    or add packages by:
  #    nix-shell -p nodejs_24 --run 'cd node-pkgs && npm add -D <package-name>@<version> --package-lock-only'
  # 2. update node-pkgs/package-lock.json by:
  #    nix-shell -p nodejs_24 --run 'cd node-pkgs && npm install --package-lock-only'
  # 3. use the dev shell by: 
  #    nix develop

  # == NOTE ==
  # using nodejs_24, if you need other version, change nodejs
  # if you need to select a different package.json, change npmRoot

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) importNpmLock;
        nodejs = pkgs.nodejs_24;
        npmRoot = ./node-pkgs;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.treefmt
            importNpmLock.hooks.linkNodeModulesHook
          ];
          npmDeps = importNpmLock.buildNodeModules {
            inherit npmRoot nodejs;
          };
        };
        
        # for updating package.json and package-lock.json
        # enter the shell by:
        #   nix develop .#node
        devShells.node = pkgs.mkShell {
          packages = [
            nodejs
          ];
          shellHook = ''
            cd node-pkgs
            echo "Node.js version: $(node -v)
            add:
            npm install -D <package-name>@<version> --package-lock-only
            remove:
            npm uninstall -D <package-name> --package-lock-only
            convert package.json to package-lock.json:
            npm install --package-lock-only"
          '';
        };
      }
    );
}
