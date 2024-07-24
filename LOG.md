# 20-JUL-2024

## 2307

Overall today I've got `toto`, `nancy`, and `archimedes` all on the `10.255.0.0/16` network, mostly
manually configured. I need to build the deploy script in `elenta` and get the netboot image
generation and direct configuration application working.

I saw a recurrence of an old issue where ssh connections hang after some amount of time, I think it
relates to old DHCP leases, and I believe I've resolved it.

The other thing I am missing is some tooling to manage the switches. I'm hopeful I can repair the
old switch which died (prompting all this work happening so suddenly, I had planned a more gentle
transition), but I need a way to better manage the switch configuration, so I'd like to add tooling
in `elenta` to manage that as well.

In the short term I may just port `flying-monkey` and `build-img` from `ereshkigal` and serve them
out of `elenta`; `elenta` can pull in `narya` and `telperion` and provide a version of
`flying-monkey` to manually manage machines based on their `canon` address. I'd like to improve the
ergonomics to just need the `canon` name of the machine, then have it look up the IP at least
optionally without relying on DNS.

I can also have it introspect and get the `MAC` of the relevant machine for image building, the CLI
should be something like:


```shell

# Build an image and place it at the specified location
$ elenta build-image --config '.#machine-role' --out /path/to/store/image
# Build an image for the given MAC, store it under that MAC in the given 'store'
$ elenta build-image --config '.#machine-role' --mac 00:11:22:33:44:55 --store /path/to/netboot/store
# Build an image for the given machine by it's canon, with the given role.
$ elenta build-image --config '.#machine-role' --canon 'machine.canon' --store /path/to/netboot/store

# Deploy a role to a machine by it's canon name, do not boot to it on reboot (equiv to `nixos-rebuild test`)
$ elenta deploy --config '.#machine-role' --canon 'machine.canon'
# Deploy a role to a machine and set it to boot to it on reboot (equiv to `nixos-rebuild switch`)
$ elenta switch --config '.#machine-role' --canon 'machine.canon'

# Optionally use `--no-dns` to look up the mapping directly in telperion (useful for IP changes)
$ elenta deploy --config '.#machine-role' --canon 'machine.canon' --no-dns
```

`elenta` is going to have a concept of `constellations`, which I suppose are similar to helm charts
or compose files, excepting that it's a mapping of machine roles to machines, and expects that
configurations support whatever other systems you want to run.

The upshot of these is that you gain a separation between arbitrary physical hardware and the
logical design of your architecture. You can spend all your time designing an entirely abstract
architecture, and then distribute roles to machines independently.

The API I think looks a bit like

```nix
# Note this is a sketch, I don't think you can import flake components like that.
rec {
    roles = {
        reverse-proxy = import "flake:telperion#domains.example.tld.roles.reverse-proxy";
        app-server = import "flake:telperion#domains.example.tld.roles.app-server";
        database = import "flake:telperion#domains.example.tld.roles.database";
    };
    mapping = {
        domain = "example.tld";
        redirect_bare_to = "www";
        machines = {
            "www" = {
                role = roles.reverse-proxy;
                host = "server-a.canon";
                extraOpts = {
                    # Arbitrary extra options to pass to the role
                };
            };
            "app" = {
                role = roles.app-server;
                # Since these two are on the same machine, the mapping will try to merge the two
                # configurations, if they can't be merged, it will fail with an error.
                host = "server-a.canon";
            };

            # Here we might assume that the roles have modes which tell it how to look for other db
            # instances, again, the goal of this is to try to only think about the allocation of
            # roles to hardware, and only pass information as is strictly necessary.
            "db-a" = {
                role = roles.database;
                host = "server-b.canon";
                extraOpts = {
                    mode = "primary";
                };
            };
            "db-b" = {
                role = roles.database;
                host = "server-c.canon";
                extraOpts = {
                    mode = "secondary";
                };
            };

        }
    };
}
```

`elenta` will have access to the full mapping and can pass that down to the role configurations, so
roles can look up items in the constellation and use that for static service discovery; elenta can
also use this mapping to generate DNS configuration that creates a zonefile for the particular
domain that creates all the necessary records.

Eventually it'd be cool to include switch configurations as well.


# 21-JUL-2024

## 1306

I was thinking about the constellation file a little more last night, and I think I prefer this
design instead:

```nix
rec {
    "machine.canon.lan" = {
        hostConfig = "null | { literal, module } | import ./path/to/machine-role";
        vms = {
            "vm1" = "{ literal, module } | import";
            # ...
        };
        containers = {
            "container1" = "{ literal, module } | import";
            # ...
        };

        # arbitrary config available to be placed and used here.
    };
    "machine2.canon.wifi" = {
        # ...
    };
    # ...
}
```

The `"machine"` key is the canon name of the machine, and there are options to configure items at
the host level, to spin up vms, or containers. `vms` and `containers` both take literal
configurations and spin up containers/vms on the target. Additionally if these items are non-empty,
it will contribute appropriate configuration to the host to support them.

Canon addresses are also extended to include protocol type, this is something I'm toying with, I'd
prefer to have all interfaces bonded and then have a single logical address, but I'm not sure how
good of an idea it is to bond wireless and LAN interfaces, so I'm toying with separating them at
least at that level.

Unrelated, the issue I saw with `toto` seems to have resolved itself, so I'm guessing it was just
stale DHCP leases causing trouble.


## 1410

One of the things I'm going to want to figure out is some mechanism to figure out when machines need
to be updated to match a specific SHA within the context of a specific constellation. Ultimately I
want a tool that can take a constellation and figure out how to rebuild everything to bring the
constellation into compliance with the config. Not sure how to do that yet, I'm sure there is some
git magic to be done, but I'm not sure what it is yet.

## 1645

I'm a little stuck, trying to build up to the constellation/role/machine mapping system is going to
take a lot longer than I'd like, and I'm considering just manually managing the machines directly
for the short term and then extracting configurations out after the fact. This will inevitably leave
a big mess in the cadaster, but I think I can limit it by putting all the bespoke config in it's own
file and relying on the laurelin modules directly there.

If I do that, then I can develop all the modules, get them tested and wired up, then the
constellation stuff won't have the issue of needing to have both the modules and wireup system
debugged.

I'm going to go that route, and just add a `bespoke.nix` into which all the stuff that 'should' be a
machine role will go into, then later I can start to unpack that.

This also means that I can build everything around the .canon domain for now.

## 2132

Definitely liking the idea from earlier, I'm just placing it in the `config.nix` for now, but I
should be able to stand up everything pretty quickly this way, I can just use a `flying-monkey`
style script right now. I have a ton of pending changes to close in `telperion` and `laurelin` now,
so I'm going to work on that tonight and then probably take some time this week to start getting the
deployment pipeline working and `nfs` and `dns` working for the `canon` domain.


# 22-JUL-2024

## 0916

I think I've got a better idea on how to organize things.

A deployment of a constellation is a derivation. It's build phase creates and caches all the
cross-environment artifacts (zonefiles, images, etc), it's install phase is a script that gathers
those artifacts and deploys them to the target machines and ensures all netboot images are up to
date.

`elenta` should provide these derivations given the constellation input, and then `minas-tarwon` can
take those derivations and apply them to the target machines.

Two different derivations are 'compatible' if they do not:

1. Overallocate any underlying machine
2. Have contradictory configurations (i.e., colliding ports, colliding filesystem
   assignments/mounts, etc).
3. Can be `mkMerge`d with each other and still have any assertions/tests pass

Ultimately this would allow breaking down that 'main' derivation into, e.g., a derivation per
machine or however else I want to break things up. It also makes the deployment pipeline
straightforward. "Here are a bunch of constellations that `elenta` compiles down to a single script
that you run from a provisioning machine to deploy everything specified." Rollback is just applying
the previous derivation + whatever backup restoration should be done.

Automating a pre-deploy backup can be part of the `installPhase` of the derivation.

Eventually it'd be cool to have the `merge` bit be smart and try to create, e.g., VMs and stuff
dynamically, so it just becomes a 'map machine roles to resources, don't care about where they are
hosted'

## 1054

I think I'm just going to leverage `just` in the `minas-tarwon` repo to port over the
`flying-monkey` stuff. It can do the basic deployment from `telperion` -> machine config for now.

## 2317

I set up `just` to do deploys now, porting over `flying-monkey` was pretty easy, I rather like
`just`.

Next I need to get the `canon` domain hosted. I just need to see how to refer to my own flake, I am
pretty sure I can just pass it down as a special arg. Not sure.

# 23-JUL-2024

## 0014

Got deploys tested, and am now serving the `.canon` domain on `toto`. I realized I need to get
`ifrit` added to the cadaster, and it presents a wrinkle, as it is on multiple networks, and thus
would need multiple canon IPs, since bonding these is not really reasonable since they _need_ to
serve actually indepentent networks in my architecture. My topology splits lab and non-lab networks,
and I want my firewall to maintain that separation, while having, ideally, a single flat network
that stretches across both. Moving the point of failure to my firewall, instead of the lab switch.

This is the theory, and it means that `ifrit` will need at least two entries. I think that's okay,
and ultimately it makes convenient the fact that I'm stealing a whole TLD for this. I can just use
subdomains.

!!! CAUTION

This, by the way, is not a good way to use DNS, there are a variety of ways to exploit this kind of
thing if you aren't careful, but this lab is confined to me, for the most part, and ultimately I'm
not super worried as I do plan to make sure requests for these domains never leave the network. This
can itself be bad because if the domains are 'real' (i.e., if you're split-horizoning a real
domain), then you can block an otherwise 'correct' lookup. Generally you'll be fine if you use weird
TLDs and block all outgoing DNS for those TLDs (which is what I do). You can be much safer by just
buying a domain and using that, but I like punned names and I don't want to pay for a problem I'm
unlikely to ever actually have.

Each independent network on ifrit can have it's own subdomain to point to the gateway. This means
that when I start serving multiple domains and layering VLANs, I can have as many subdomains as I
like.

In any case, next step is to get `ifrit` into the cadaster and update the DNS stuff to allow for
multiple subdomains for ifrit. Then I can update `ifrit` to point it's clients at the DNS IP and I
think I'm basically back up and running in the new setup.

## 1220

Looking at a new issue, `toto` has two IPs on the same interface, one is virtual, and `iptables` nor
`nftables`-based local firewalls seem to be able to handle this case with the built-in networking
module. I'm not sure I understand exactly how things are getting generated just yet, but my guess is
that this is not a typical way to cut up a network and so the implementation is not robust to my
particular breed of weirdo.

If I turn off the firewall, everything works, and so I know the issue is local to the machine. I
tried just inspecting both the configurations generated by my config and they both look 'fine' in
the sense that they should happily be sending packets to the specified interface, so after some
consternation, I turned my attention further up the stack.

The tipoff to this was looking at the `dmesg` output as I tried to hit port 53 w/ an nmap scan; it
shows that when I run the `nmap` against that port, it sees the incoming connection as originating
from the `enp2s0` interface, and not the `enp2s0_dns` virtual interface. `enp2s0` does not have `53`
open.

I tried opening `53` on `enp2s0` itself and sure enough everything works fine. So for now I suppose
I'll just have to open the sum of all the ports I want on the `enp2s0` interface and then later do
something bespoke to handle my weird networking idea.

I'm now seeing what I suspect is a very straightforward "need to turn some ports on" issue on the
switch, so that's tonight's project.

## 1738

Truly confusing, even with the extra port, it actually just shows the port as open, doesn't actually
respond correctly. For now I've just disabled the firewall entirely, I'm sure I'm doing something
silly, I just can't track down what at the moment.

## 2205

Got the DNS configured for both KANSAS and CONDORCET. I should probably add the wifi router and
cable modem to the cadaster (and really everything in the racks, I suppose it should try to cover
everything that touches my network, at least).

## 2212

I also updated NFS rules for nancy. This gets network storage back to functional.

