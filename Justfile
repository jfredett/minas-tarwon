set dotenv-load

@default:
  just --list

# Update all flakes
[group('update')]
update:
  nix flake --no-warn-dirty update

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
  #nix flake update --no-warn-dirty {{INPUT}}/

# Create a DNS Zonefile for all items in the cadaster, by their canonical IP.
[group('show')]
show-dns ZONE: local-update
  nix eval --no-warn-dirty --impure '.#dns.zones."{{ZONE}}"' | xargs printf

# Create a hostsfile including all items in the cadaster, by their canonical IP.
[group('show')]
show-hosts ZONE: local-update
  nix eval --no-warn-dirty --impure '.#dns.hosts."{{ZONE}}"' | xargs printf



### DEPLOY JOBS

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{MACHINE}}
[group('deploy')]
deploy TASK MACHINE: update
  nixos-rebuild -j $PARALLEL --impure --use-remote-sudo --upgrade \
    --target-host "{{MACHINE}}.canon" --flake ".#{{MACHINE}}" {{TASK}}

# Equivalent to `nixos-rebuild {{TASK}}` on the local machine using the given {{CONFIG}}
[group('deploy')]
deploy-local TASK CONFIG: update
  sudo nixos-rebuild -j $PARALLEL --impure --upgrade --flake ".#{{CONFIG}}" {{TASK}}

# Equivalent to `nixos-rebuild {{TASK}}` on the machine specified by {{IP}}, applying the given {{CONFIG}}
[group('deploy')]
deploy-ip TASK IP CONFIG: update
  nixos-rebuild -j $PARALLEL --impure --use-remote-sudo --upgrade \
    --target-host "{{IP}}" --flake ".#{{CONFIG}}" {{TASK}}

# Create and place a netbootable image in the netboot directory (specified in the flake)
[group('deploy')]
deploy-netboot CONFIG: update
  sudo nix run \
    --impure --no-warn-dirty \
    --log-format bar-with-logs \
    ".#build-image.{{CONFIG}}"

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
