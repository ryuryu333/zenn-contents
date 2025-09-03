{
  description = "Zenn CLI environment";

  # == USAGE ==
  # you can use the following commands in this environment
  # e.g. 
  #   task               -> run linters 
  #   task add zenn-cli  -> add zenn-cli to package.json and package-lock.json
  # cf. Taskfile.yml or run 'task -l'
  # * add:                   Add package to package.json and package-lock.json (requires args e.g. <PackageName>@<Version>)      (aliases: install)
  # * check:                 Check for outdated packages before update
  # * lint:                  [default] Run linters
  # * reload:                Reload Nix devShell environment
  # * remove:                Remove package from package.json and package-lock.json (requires args e.g. <PackageName>)      (aliases: uninstall)
  # * update:                Update packages and refresh package-lock.json
  # * update-lockfile:       Refresh package-lock.json from package.json
  # * update-packages:       Update packages to the latest version (only package.json)

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
