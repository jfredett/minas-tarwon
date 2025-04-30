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
      in {
        devshells.default = {
          motd = ''A Tower of Stone in a Field somewhere, Hitharwasar.'';

          packages = with pkgs; [
            busybox
            cloc
            git
            git-filter-repo
            kubernetes-helm
            ipmitool
            just
            kubectl
            k9s
            mani
            nixfmt-rfc-style
            openssl
            plantuml
            timg
          ];
        };

        # FIXME: Port this, netboot is borken anyway.

        apps = let
          netboot_dir = "/mnt/emerald_city_netboot";
          tmpdir = "/storage/minas-tarwon";
          mkScript = name: script: flake-utils.lib.mkApp {
            drv = pkgs.writeScriptBin name script;
          };
          mkBuildScriptFor = domain: machine: configuration: let
            config = configuration.config;
          in (mkScript machine /*bash*/ ''
            set -e

            mac=$(echo "${config.laurelin.netboot.mac}" | tr -d :)
            target_dir=${netboot_dir}/$mac
            tmpdir=${tmpdir}/${machine}

            echo "Preparing necessary directories"
            mkdir -p $target_dir

            echo "Build ${machine} image"
            nix build --impure \
              --log-format bar-with-logs \
              --out-link $tmpdir \
              ".#nixosConfigurations.\"${machine}.${domain}\".config.system.build.netboot"

            # Shuffle images only if previous command succeeds -- `set -e` ensures this won't run
            # unless that's true.
            if [ -e $target_dir/latest ]; then
              echo "Shuffling ${machine} images"
              latest_creation_time=$(stat -c %Z "$target_dir/latest")
              timestamp=$(date -d "@$latest_creation_time" +"%d-%b-%Y-%H%MET")
              mv $target_dir/latest $target_dir/$timestamp
            fi

            echo "Copy ${machine} image to mount"
            rsync -r --copy-links --info=progress2 --info=name0 -a $tmpdir/ $target_dir/latest

            echo "Clean up"
            rm -rf $tmpdir
            '');
          mkBuildables = domain: builtins.mapAttrs (mkBuildScriptFor domain) telperion.nixosConfigTree."${domain}";
        in if (system == "x86_64-linux") then {
          # BUG: This seems to break `nix flake show`
          canon = mkBuildables "canon";
          # build = {
          #   canon = mkBuildables "canon";
          #   "emerald.city" = mkBuildables "emerald.city";
          # };
        } else { };


      };
    };
}
