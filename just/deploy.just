#TODO: Rebuild this so much. It's a mess.

@_deploy *ARGS: update
  just _deploy-direct {{ARGS}}

@_deploy-direct *ARGS:
  nixos-rebuild -j $PARALLEL --impure --upgrade {{ARGS}}

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{MACHINE}} via it's canonical domain name
[group('deploy')]
deploy MACHINE DOMAIN="canon" TASK="test":
  just deploy-to "{{MACHINE}}.{{DOMAIN}}" {{MACHINE}} {{DOMAIN}} {{TASK}}

# Equivalent to `nixos-rebuild {{TASK}}` on the local machine using the given {{CONFIG}}
[group('deploy')]
deploy-local CONFIG TASK="test":
  sudo just _deploy "--flake .#\"{{CONFIG}}.canon\" {{TASK}}"

# Equivalent to `nixos-rebuild {{TASK}}` on the local machine using the machines hostname as the target
[group('deploy')]
deploy-self TASK="test":
  just deploy-local "$(hostname)" {{TASK}}

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{LOCATION}} (IP or DN), applying the given {{CONFIG}}
[group('deploy')]
deploy-to LOCATION CONFIG DOMAIN="canon" TASK="test": update
  just _deploy-direct "--use-remote-sudo --target-host {{LOCATION}} --flake .#"{{CONFIG}}.{{DOMAIN}}" {{TASK}}"

# Equivalent to deploy-to, but skips the update
[group('deploy')]
deploy-no-update LOCATION CONFIG DOMAIN="canon" TASK="test":
  just _deploy-direct "--use-remote-sudo --target-host {{LOCATION}} --flake .#"{{CONFIG}}.{{DOMAIN}}" {{TASK}}"

# Create and place a netbootable image in the netboot for the MACHINE specified in the DOMAIN defined in telperion
[group('deploy')]
deploy-netboot MACHINE DOMAIN="canon": update
  sudo nix run \
    -j $PARALLEL \
    --impure --no-warn-dirty \
    --log-format bar-with-logs \
    ".#build.\"{{DOMAIN}}\".{{MACHINE}}"

# Create a dry-build of the configuration specified by {{CONFIG}}
[group('deploy')]
dry-build MACHINE DOMAIN: update
  just _deploy-direct "dry-build --flake .#\"{{MACHINE}}.{{DOMAIN}}\""

# Build new images of all netbootables
[group('deploy')]
deploy-all-netboot: update
  just deploy-netboot babylon-the-great
  just deploy-netboot dragon-of-perdition
  just deploy-netboot pinky emerald.city
  just deploy-netboot barge emerald.city
  just deploy-netboot daktylos emerald.city

# UNSAFE: Deploy everything based on the configuration in the current checkout of the repo.
[group('unsafe')]
deploy-all: update
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





