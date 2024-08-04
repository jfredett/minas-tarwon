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
  sudo just _deploy "--flake .#\"canon.{{CONFIG}}\" {{TASK}}"

# Equivalent to `nixos-rebuild {{TASK}}` on the local machine using the machines hostname as the target
[group('deploy')]
deploy-self TASK="test":
  just deploy-local "$(hostname)" {{TASK}}

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{LOCATION}} (IP or DN), applying the given {{CONFIG}}
[group('deploy')]
deploy-to LOCATION CONFIG DOMAIN="canon" TASK="test": update
  just _deploy-direct "--use-remote-sudo --target-host {{LOCATION}} --flake .#"{{DOMAIN}}.{{CONFIG}}" {{TASK}}"

# Equivalent to deploy-to, but skips the update
[group('deploy')]
deploy-no-update LOCATION CONFIG DOMAIN="canon" TASK="test":
  just _deploy-direct "--use-remote-sudo --target-host {{LOCATION}} --flake .#"{{DOMAIN}}.{{CONFIG}}" {{TASK}}"

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
dry-build CONFIG:
  just deploy dry-build {{CONFIG}}

