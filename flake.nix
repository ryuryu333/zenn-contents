{
  description = "Zenn CLI environment";

  # == NOTE ==
  # use 'task' command to find available tasks
  #   e.g. task lint, task install...
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
            pkgs.lychee
            pkgs.go-task
            importNpmLock.hooks.linkNodeModulesHook
          ];
          npmDeps = importNpmLock.buildNodeModules {
            inherit npmRoot nodejs;
          };
        };

        # for updating package.json and package-lock.json
        devShells.node = pkgs.mkShell {
          packages = [
            nodejs
            pkgs.npm-check-updates
          ];
        };
      }
    );
}
