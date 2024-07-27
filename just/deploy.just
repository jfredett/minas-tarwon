@_deploy ARGS: update
  nixos-rebuild -j $PARALLEL --impure --upgrade {{ARGS}}

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{MACHINE}} via it's canonical
# domain name
[group('deploy')]
deploy TASK MACHINE:
  just deploy-to "{{MACHINE}}.canon" {{TASK}} {{MACHINE}}

# Equivalent to `nixos-rebuild {{TASK}}` on the local machine using the given {{CONFIG}}
[group('deploy')]
deploy-local TASK CONFIG:
  sudo just _deploy "--flake .#{{CONFIG}} {{TASK}}"

# Equivalent to `nixos-rebuild {{TASK}}` on the local machine using the machines hostname as the
# target
[group('deploy')]
deploy-self TASK:
  just deploy-local {{TASK}} "$(hostname)"

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{LOCATION}} (IP or DN), applying the given {{CONFIG}}
[group('deploy')]
deploy-to LOCATION TASK CONFIG:
  just _deploy "--use-remote-sudo --target-host {{LOCATION}} --flake .#{{CONFIG}} {{TASK}}"

# Create and place a netbootable image in the netboot for the MACHINE specified in the CADASTER directory (specified in the flake)
[group('deploy')]
deploy-netboot MACHINE: update
  sudo nix run \
    -j $PARALLEL \
    --impure --no-warn-dirty \
    --log-format bar-with-logs \
    ".#build-image.{{MACHINE}}"

# Create a dry-build of the configuration specified by {{CONFIG}}
[group('deploy')]
dry-build CONFIG:
  just deploy dry-build {{CONFIG}}

