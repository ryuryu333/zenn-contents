{
  description = "Zenn CLI environment";

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
        my-node-pkgs = import ./node-pkgs/default.nix {
          inherit pkgs system;
          nodejs = pkgs.nodejs_24;
        };
        inherit (my-node-pkgs) nodeDependencies;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            nodeDependencies
            pkgs.treefmt
            ];
          shellHook = ''
            ln -s ${nodeDependencies}/lib/node_modules ./node_modules
            export PATH="${nodeDependencies}/bin:$PATH"
            ln -s $NODE_PATH node_modules
          '';
        };
      }
    );
}
