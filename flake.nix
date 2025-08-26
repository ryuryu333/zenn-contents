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
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.zenn-cli
            my-node-pkgs."textlint-15.2.2"
            my-node-pkgs."textlint-rule-preset-ja-spacing-2.4.3"
            my-node-pkgs."textlint-rule-preset-ja-technical-writing-12.0.2"
            ];
        };
      }
    );
}
