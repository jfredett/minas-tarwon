# Create a DNS Zonefile for all items in the cadaster, by their canonical IP.
[group('show')]
show-dns ZONE: update
  nix eval --no-warn-dirty --impure '.#dns.zones."{{ZONE}}"' | xargs printf

# Create a hostsfile including all items in the cadaster, by their canonical IP.
[group('show')]
show-hosts ZONE: update
  nix eval --no-warn-dirty --impure '.#dns.hosts."{{ZONE}}"' | xargs printf

