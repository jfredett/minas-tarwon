set dotenv-load

[private]
@default:
  just --list

# Update all flakes
[group('update')]
update: local-update remote-update

# Update all flakes if the last update was more than 15 minutes ago 
[group('update')]
remote-update:
  #!/usr/bin/env bash
  echo "$(tput bold)Updating all flakes$(tput sgr0)"

  if [ ! -f /tmp/last-update ]; then
    touch /tmp/last-update
  fi

  if [ $(($(date +%s) - $(date -r /tmp/last-update +%s))) -gt 900 ]; then
    echo "$(tput bold)-> Updating $(tput sgr0)"
    nix flake update --no-warn-dirty
    touch /tmp/last-update
  else
    echo "$(tput bold)-> Skipping update, last run was less than 15 minutes ago$(tput sgr0)"
  fi

# Update only the minas-tarwon affiliated flakes.
[group('update')]
@local-update:
  echo "$(tput bold)Updating local flakes$(tput sgr0)"
  just update-input elenta
  just update-input narya
  just update-input glamdring
  just update-input laurelin
  just update-input telperion

# Update a specific minas-tarwon affiliated flake in both the parent and child directory
[group('update')]
@update-input INPUT:
  echo "$(tput bold)-> Updating {{INPUT}}$(tput sgr0)"
  nix flake lock --no-warn-dirty --update-input {{INPUT}}
  nix flake update --no-warn-dirty {{INPUT}}/

# Create a DNS Zonefile for all items in the cadaster, by their canonical IP.
[group('show')]
show-dns ZONE: update
  nix eval --no-warn-dirty --impure '.#dns.zones."{{ZONE}}"' | xargs printf

# Create a hostsfile including all items in the cadaster, by their canonical IP.
[group('show')]
show-hosts ZONE: update
  nix eval --no-warn-dirty --impure '.#dns.hosts."{{ZONE}}"' | xargs printf



### DEPLOY JOBS

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
  sudo just deploy-local {{TASK}} $(hostname)

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


### UTILITY

# rsync source to target, copying symlink targets
[group('utility')]
rsync SOURCE TARGET:
  sudo rsync -r --copy-links --info=progress2 --info=name0 -a "{{SOURCE}}" "{{TARGET}}"

# Start a Nix REPL
[group('utility')]
repl:
  nix --extra-experimental-features "flakes repl-flake" \
    repl -f '<nixpkgs>'

### GIT

# Push all repositories
[group('git')]
push:
  git push
  mani exec -a git push

[group('git')]
status:
  git status --short
  mani exec -a git status -- --short

[group('git')]
commit-locks:
  git add flake.lock
  git ci -m 'Update flake.lock'
  mani exec -a git add flake.lock
  mani exec -a -- git ci -m 'Update flake.lock'
