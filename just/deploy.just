#TODO: Rebuild this so much. It's a mess.

@_deploy *ARGS:
    sudo just _deploy-direct {{ARGS}}

@_deploy-direct *ARGS:
    nixos-rebuild -j ${PARALLEL:=1} --impure --upgrade {{ARGS}}

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{MACHINE}} via it's canonical domain name
[group('deploy')]
deploy MACHINE DOMAIN="canon" TASK="test" *ARGS:
    just deploy-to "{{MACHINE}}.{{DOMAIN}}" {{MACHINE}} {{DOMAIN}} {{TASK}} {{ARGS}}

# Equivalent to `nixos-rebuild {{TASK}}` on the local machine using the given {{CONFIG}}
[group('deploy')]
deploy-local CONFIG TASK="test":
    just _deploy "--flake .#\"{{CONFIG}}.canon\" {{TASK}}"

# Equivalent to `nixos-rebuild {{TASK}}` on the local machine using the machines hostname as the target
[group('deploy')]
deploy-self TASK="test":
    just deploy-local "$(hostname)" {{TASK}}

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{LOCATION}} (IP or DN), applying the given {{CONFIG}}
[group('deploy')]
deploy-to LOCATION CONFIG DOMAIN="canon" TASK="test":
    just _deploy-direct "--sudo --target-host {{LOCATION}} --flake .#"{{CONFIG}}.{{DOMAIN}}" {{TASK}}"

# Equivalent to deploy-to, but skips the update
[group('deploy')]
deploy-no-update LOCATION CONFIG DOMAIN="canon" TASK="test":
    just _deploy-direct "--target-host {{LOCATION}} --flake .#"{{CONFIG}}.{{DOMAIN}}" {{TASK}}"

# Create and place a netbootable image in the netboot for the MACHINE specified in the DOMAIN defined in telperion
[group('deploy')]
deploy-netboot MACHINE DOMAIN="canon":
    #!/usr/bin/env bash

    nix run \
        -j ${PARALLEL:=4} \
        --impure --no-warn-dirty \
        ".#build.\"{{DOMAIN}}\".{{MACHINE}}"


# Create a dry-build of the configuration specified by {{CONFIG}}
[group('deploy')]
dry-build MACHINE DOMAIN:
    just _deploy-direct "dry-build --flake .#\"{{MACHINE}}.{{DOMAIN}}\""

# Build new images of all netbootables
[group('deploy')]
deploy-all-netboot:
    just deploy-netboot babylon-the-great
    just deploy-netboot dragon-of-perdition
    just deploy-netboot pinky emerald.city
    just deploy-netboot barge emerald.city
    just deploy-netboot daktylos emerald.city

# UNSAFE: Deploy everything based on the configuration in the current checkout of the repo.
[group('unsafe')]
deploy-all:
    # deploy the netboot machines w/ just 'test', building the images is a separate job since it sucks
    # so much disk space while it does it.
    just deploy babylon-the-great
    just deploy dragon-of-perdition
    just deploy pinky emerald.city
    just deploy barge emerald.city
    just deploy daktylos emerald.city

    # deploy all the HDD-based machines
    just deploy toto canon switch
    just deploy archimedes canon switch
    just deploy maiasaura canon switch
    just deploy randy emerald.city switch



build MACHINE DOMAIN MAC:
    #!/usr/bin/env bash
    set -xe

    # mac=$(echo "${config.laurelin.netboot.mac}" | tr -d :)
    mac="{{MAC}}"
    machine="{{MACHINE}}"
    domain="{{DOMAIN}}"
    target_dir="/mnt/emerald_city_netboot/$mac"
    # BUG: This will only work on Archi
    tmpdir=/storage/minas-tarwon/${machine}

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

