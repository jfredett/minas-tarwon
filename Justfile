set dotenv-load

[group('update')]
update:
  nix flake --no-warn-dirty update

[group('update')]
@local-update:
  echo "$(tput bold)Updating local flakes$(tput sgr0)"
  just update-input elenta
  just update-input narya
  just update-input glamdring
  just update-input laurelin
  just update-input telperion

[group('show')]
show-dns ZONE: local-update
  nix eval --no-warn-dirty --impure '.#dns.zones."{{ZONE}}"' | xargs printf

[group('show')]
show-hosts ZONE: local-update
  nix eval --no-warn-dirty --impure '.#dns.hosts."{{ZONE}}"' | xargs printf

[group('update')]
@update-input INPUT:
  echo "$(tput bold)-> Updating {{INPUT}}$(tput sgr0)"
  nix flake lock --no-warn-dirty --update-input {{INPUT}}
  nix flake update --no-warn-dirty {{INPUT}}/

[group('deploy')]
deploy TASK MACHINE: update local-update
  nixos-rebuild -j $PARALLEL --impure --use-remote-sudo --upgrade \
    --target-host "{{MACHINE}}.canon" --flake "./telperion#{{MACHINE}}" {{TASK}}

[group('deploy')]
deploy-local TASK CONFIG: update local-update
  sudo nixos-rebuild -j $PARALLEL --impure --upgrade --flake "./telperion#{{CONFIG}}" {{TASK}}

[group('deploy')]
deploy-ip TASK IP CONFIG: update local-update
  nixos-rebuild -j $PARALLEL --impure --use-remote-sudo --upgrade \
    --target-host "{{IP}}" --flake "./telperion#{{CONFIG}}" {{TASK}}
