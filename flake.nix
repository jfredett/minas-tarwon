{
  description = "Minas Tarwon";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    elenta = {
      url = "git+file:./elenta";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    laurelin = {
      url = "git+file:./laurelin";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    narya = {
      url = "git+file:./narya";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    glamdring = {
      url = "git+file:./glamdring";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    telperion = {
      url = "git+file:./telperion";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        laurelin.follows = "laurelin";
      };
    };
  };

  outputs = { self, nixpkgs, devenv, flake-utils, nixos-generators, nix-index-database, telperion, ... } @ inputs: let
    systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
    forAllSystems = f: builtins.listToAttrs (map (name: { inherit name; value = f name; }) systems);
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      default = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [{
          packages = with pkgs; [
            mani
            git
            just
          ];
        }];
      };
    });

    dns = telperion.dns;
  };


}
