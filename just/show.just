# Create a DNS Zonefile for all items in the cadaster, by their canonical IP.
[group('show')]
show-dns ZONE: update
  nix eval --no-warn-dirty --impure '.#genDNS.zones."{{ZONE}}"' | xargs printf
