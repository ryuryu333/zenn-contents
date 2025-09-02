{
  description = "Zenn CLI environment";

  # == usage ==
  # 1. use the dev shell by:
  #      nix develop
  # 2. edit node-pkgs/package.json to specify the package name and version by:
  #      npm install -D <package-name>@<version> --package-lock-only
  #      npm uninstall -D <package-name> --package-lock-only
  # 3. re-enter the dev shell by:
  #      exit
  #      nix develop

  # == NOTE ==
  # using nodejs_24, if you need other version, change nodejs
  # if you need to select a different package.json, change npmRoot
  # you MUST use npm `--package-lock-only` option
  # to ensure the lockfile is updated correctly

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
            pkgs.lychee
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
            pkgs.npm-check-updates
          ];
          shellHook = ''
            cd node-pkgs
            echo "Node.js version: $(node -v)
            == add ==
            npm install -D <package-name>@<version> --package-lock-only
            == remove ==
            npm uninstall -D <package-name> --package-lock-only
            == check update ==
            ncu
            == update package.json ==
            ncu -u
            == convert package.json to package-lock.json ==
            npm install --package-lock-only"
          '';
        };
      }
    );
}
