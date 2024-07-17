update:
  nix flake update

dns ZONE: update
  nix eval './telperion#dns.zones.{{ZONE}}' | xargs printf
