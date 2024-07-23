set dotenv-load

update:
  nix flake update

local-update:
  just update-input elenta
  just update-input narya
  just update-input glamdring
  just update-input laurelin
  just update-input telperion

show-dns ZONE: local-update
  nix eval --impure '.#dns.zones."{{ZONE}}"' | xargs printf

show-hosts ZONE: local-update
  nix eval --impure '.#dns.hosts."{{ZONE}}"' | xargs printf

update-input INPUT: 
  nix flake lock --update-input {{INPUT}}

deploy TASK MACHINE: update local-update
  nixos-rebuild -j $PARALLEL --impure --use-remote-sudo --upgrade \
    --target-host "{{MACHINE}}.canon" --flake "./telperion#{{MACHINE}}" {{TASK}}

deploy-ip TASK IP CONFIG: update local-update
  nixos-rebuild -j $PARALLEL --impure --use-remote-sudo --upgrade \
    --target-host "{{IP}}" --flake "./telperion#{{CONFIG}}" {{TASK}}
