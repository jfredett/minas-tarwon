{
  # TODO: use flake-utils.lib.meld to merge everything?

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

    laurelin = {
      url = "git+file:./laurelin";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        hyprland.follows = "hyprland";
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
        hyprland.follows = "hyprland";
      };
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";


    devshell.url = "github:numtide/devshell";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    telperion = {
      url = "git+file:./telperion";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        laurelin.follows = "laurelin";
        narya.follows = "narya";
        glamdring.follows = "glamdring";
      };
    };
  };

  outputs = { self, nixpkgs, devshell, flake-parts, flake-utils, nixos-generators, nix-index-database, telperion, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];

      systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      flake = {
        nixosConfigurations = telperion.nixosConfigurations;
        genDNS = telperion.genDNS;
      };

      perSystem = { pkgs, system, ...}: let
        pkgs-unfree = import nixpkgs { inherit system; config.allowUnfree = true; };
      in {
        devshells.default = {
          motd = ''A Tower of Stone in a Field somewhere, Hitharwasar.'';

          env = [
            { name = "VAULT_ADDR"; value = "https://vault.emerald.city"; }
          ];

          packages = with pkgs-unfree; [
            busybox
            cloc
            git
            git-filter-repo
            ipmitool
            just
            k9s
            kubectl
            kubernetes-helm
            mani
            nixfmt-rfc-style
            openssl
            operator-sdk
            plantuml
            postgresql
            terraform
            vault
            timg
          ];
        };
      };
    };
}
