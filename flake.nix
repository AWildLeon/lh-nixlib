{
  description = "Leon's Public Flake parts.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    nuschtosSearch = {
      url = "github:NuschtOS/search";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    notnft = {
      url = "github:chayleaf/notnft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        self,
        lib,
        ...
      }:
      {
        flake.lib = import ./lib { inherit lib; };

        perSystem =
          {
            lib,
            system,
            ...
          }:
          {
            _module.args.pkgs = import self.inputs.nixpkgs {
              inherit system;
            };
            _module.args.pkgsUnstable = import self.inputs.nixos-unstable {
              inherit system;
            };
            _module.args.lh.lib = import ./lib { inherit lib; };
          };

        imports = [
          ./modules/part.nix
          ./packages/part.nix
          ./parts/nix-develop.nix
          ./parts/options-search.nix
          ./parts/treefmt.nix
          inputs.treefmt-nix.flakeModule
        ];
        systems = [
          # Dont beg me to support macOS, I wont. fork this and add it yourself if you want it. Any PR adding macOS support will be closed without comment.
          "x86_64-linux"
          "aarch64-linux"
        ];
      }
    );
}
