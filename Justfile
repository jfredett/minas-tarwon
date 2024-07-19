set dotenv-load

update:
  nix flake update

local-update:
  just update-input elenta
  just update-input narya
  just update-input glamdring
  just update-input telperion
  just update-input laurelin

show-dns ZONE: local-update
  nix eval --impure '.#dns.zones.{{ZONE}}' | xargs printf

update-input INPUT: 
  nix flake lock --update-input {{INPUT}}
