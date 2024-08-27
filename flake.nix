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

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    devenv = {
      url = "github:cachix/devenv";
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
        narya.follows = "narya";
        glamdring.follows = "glamdring";
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
        modules = [
          #{ dotenv.enable = true; }
          { packages = with pkgs; [
              busybox
              mani
              git
              just
              git-filter-repo
              cloc
              nixfmt-rfc-style
          ]; }
        ];
      };
    });

    genDNS = telperion.genDNS;
    nixosConfigurations = telperion.nixosConfigurations;

    # TODO: Clean this up somehow, probably import the script from another dir?
    apps = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
      netboot_dir = "/mnt/emerald_city_netboot";
      tmpdir = "/storage/minas-tarwon";
      mkScript = name: script: flake-utils.lib.mkApp {
        drv = pkgs.writeScriptBin name script;
      };
      mkBuildScriptFor = domain: machine: configuration: let
        config = configuration.config;
      in (mkScript machine ''
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
    in {
      # BUG: This seems to break `nix flake show`
      build = {
        canon = mkBuildables "canon";
        "emerald.city" = mkBuildables "emerald.city";
      };
    });
  };
}
