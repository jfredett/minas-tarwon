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

# 24-JUL-2024

## 1445

I set up canon IPs for both of the DRACs on the two R730s (DOP and BTG), but for whatever reason I
can't get to them via the DNS address, only by their IP, not a big deal for now, but annoying.

Archimedes is hooked back up to the barrier server, cleaned up some stuff in the `Justfile` and
started in on the netboot image. I need to figure out what to include in the imports path (if
anything), and then go from there.

## 2248

I think I want to rewrite a bunch of the image-building stuff.

The script I have is very clunky, and I think I could pretty easily adapt the existing script in nix
to just work with my setup directly, but I'd have to introduce a couple new ideas.

In particular, There is a sort of 'hyperparameter' that I need to introduce, something that is
specific to my setup, namely -- where I store the netboot images -- but which is not really a detail
that fits in any of the existing flakes in the blizzard, so to speak.

I suppose `minas-tarwon` is the natural place for such things, but I could also make an argument
that much of what I plan to do in `elenta` is similar.

I think, however, my idea has evolved somewhat. Where `elenta` was originally going to be the
`flying-monkey` replacement, and sort of the operational arm of the thing (with `laurelin` being the
abstract library from which `telperion` both describes the physical architecture (the 'cadaster',
and also describes abstract configurations of that architecture ('domains'). I also had intended for
`elenta` to manage mapping those `domains` onto the physical architecture.

I think I'm going to purpose `elenta` solely towards that goal, and pull all the operational stuff
into `minas-tarwon`, additionally, it can contain the 'hyperconfiguration' which can be passed into
scripts and so on (but ideally isn't referred to in and of the other flakes). The first such element
of the hyperconfiguration is the `minas-tarwon.netboot_store`, which is some structured
configuration that referents will use to know where netboot images are stored, e.g.:

```nix
minas-tarwon.netboot_store = {
    path = "/path/to/store";
    # ...
};
```

I'll try to encode as much of my scripting to nix, so it can natively refer to things, then wrap
these outputs with a just script.

# 25-JUL-2024

## 2341

Got dragon-of-perdition fixed up and booting. I also got all his interfaces bonded and running as
one unit. I need to read about the other options, but they all look pretty straightforward.

I also refactored the Justfile a bunch, and got netboot image creation moved into a flake 'app'.
It mostly works, but is quite messy, so I'm going to think about some ways to clean it up.

# 27-JUL-2024

## 0026

Big pile of stuff done today, I did a ton of refactoring and cleaning, and I did a bit of secret
scrubbing as well. I also ported over all the modules from glamdring, so it should be ready to turn
public on github after a last once-over.

laurelin and telperion are also almost there, which is moderately terrifying, I get anxious about
these things.

Rather than process those emotions, I instead work on getting the domain xmls at least temporarily
loaded with some hacky work in the flake. I also have another hack from the refactoring to pull
common configuration out of the `cadaster`, a module in `telperion` where it does not belong. I plan
to move it over to laurelin after I'm done auditing the existing cadaster and pulling all the common
config out. Ideally `cadaster` is really only the hardware configuration and stuff related to
building the base image. In the end all my machines will be a collection of `laurelin`, `glamdring`,
and `narya` configuration, everything else gets split up.

## 0042

Fixed an issue where unfree packages weren't allowed and that meant 1pass couldn't build. However,
that got me thinking that it'd be better to export `NIXPKGS_ALLOW_UNFREE`, since there is no reason
to litter the codebase with unfree tags when I can just export a variable in the devshell once that
I can turn off if I want to see if I'm using anything unfree.

## 1227

I just made public all the component repos except `elenta` and `narya`, the former because there is
nothing there (and TBH I may collapse it away into `minas-tarwon` proper), and the latter for
obvious reasons.

I started thinking about making `minas-tarwon` a bit more of a general monorepo for my projects,
which would point to moving a lot of my existing automation out to `elenta` and having just
project-management stuff in this repo, but I haven't really decided on organization yet.


# 29-JUL-2024

## 1748

Over the weekend, I mostly refactored and tweaked things, and got DOP + it's VMs up and netbooting.

I ran into an issue where building a bridge over a VLAN-split bond connection didn't seem to work. I
spent almost no time debugging in it favor of getting the lab back to a working state; and just
pulled an interface to dedicate to it. I suspect this is mostly a switching problem (enabling trunk
ports or w/e), but I want to converge both the WiFi and LAN networks eventually and split everything
via VLAN instead, so there's no point in spending time on it now when I'm just going to radically
change it later.

`barge` and `pinky` are both building but need a bit of work on their networking setup, eventually
I'll pull that config into laurelin as a module; I'm thinking about how I want to organize the
domains and get more of the libvirt config ported back into nix; but the idea is hazy right now, I
think ideally the individual networks per domain will have some `nix` representation that I can pass
in, so the function'd be something like:

```nix
laurelin = {
    networks = [
        { link = self.domains."foo.bar".networks."foo-net"; ip = "1.2.3.4"; }
        { link = self.domains."foo.bar".networks."foo-net2"; ip = "1.2.3.5"; }
        { link = self.domains."foo.bar".networks."foo-net3"; ip = "1.2.3.6"; }
    ];
};
```

This would then use the content of the `foo-net` attrset to populate all the networking config. It
*should* be possible to re-use this model for 'real' networks, but I'll probably limit it to virtual
networks to start. Ideally I can work out my abovementioned issue in virtuo and then port back.

I can do a similar thing for the `domain` side of things, have a few 'standard' domains, then set a
key in `laurelin` just for data's sake, to be used when deploying the config to a particular
host.

Unrelated to that, I started working on setting up `neotest` and want to start trying to get more of
the workflow into `vim` so I need to jump between fewer windows. `tmux` makes it hurt less, but I
want to have the lab integrated into the editor so I can more fluently manage, e.g., rebuilds and so
on. I think that comes on the back of setting up a laminar server and moving some of the
build/deploy stuff there. That also means moving towards purity/no more `--impure` builds, which is
it's own can of worms.

Finally, I need to get some way to provide DNS includes, maybe creating a more abstract 'reverse
proxy' module that both configures an nginx service but also generates a zone-file w/ appropriate
CNAMEs would work here? Something like:

```nix
laurelin = {
    services = {
        reverse-proxy = {
            "parent.domain" = {
                "subdomain" = {
                    frontendPort = 80;
                    backendPort = 8080;
                }
            };
            # ...
        };
    };
};
```

Then I would have that generate both an nginxconfig and a key that could then be pulled by the
`show-dns` function in the flake? Ideally this would allow the 'parent' to exist as `hostname.canon`,
then have it populate `hostname.parent.domain` as a CNAME to `hostname.canon` and then have the
others similarly populate based on the desired subdomain.

## 1850

I may be getting slightly ahead of myself w/ barge, I think I need to write a more general 'docker
container' module that I then feed additional items into, perhaps?

I also need a dev machine that isn't this poor old laptop.

# 1-AUG-2024

## 0112

Ran into an infinite recursion with my DNS generation, by referencing it directly, it has to query
it's own configuration to calculate it's DNS. I think this only happens for the `canon` domain
because of how I have split up the options. Since the `canon` domain is calculated from the configs,
and the config of the dns server wants to include the `canon` domain, it has to calculate it's own
config and down the rabbit hole went Alice.

I think this is straightforward to fix, but I lack the will tonight. I can rely on precomputed files
and make this a compilation step that just runs when I run a deploy. It's relatively quick to
calculate statically, then I can refer to the static copy. That also make it easy to inspect when
there are issues, and solves the 'serial number in the git repo' problem I haven't yet mentioned
(the idea of trying to remember to maintain that number will result in many many many tiny commits
full of more swear words than delta).

# 2-AUG-2024

## 2335

I'm working on committing off a bunch of work, I solved the DNS issue without adding a second phase,
it ultimately boiled down to needing to split and calculate each zone via the `nixosConfigTree`
instead of using the `nixosConfigurations` directly.

I have an annoying reversal that happens when calculating the `nixosConfigurations` that results in
the domain coming first -- I haven't fixed that yet but it's so ugly I feel obligated to mention it
in the log.

I refactored some of the `deploy` scripts but `just` is really not up to what I'm putting it
through, I think. In particular the `nix flake update` logic is a bit of a mess and often runs a
couple times. This isn't a huge issue, but it burns time; I suppose moving development to a VM will
help with that, but that would require I actually get that built, which isn't as interesting as
chasing infinite recursion bugs.

In any case, I'm getting `toto` updated tonight, which unblocks `barge` and puts me back to where I
was with `ereshkigal` before cutting over. This whole process took about a month, but I think it was
a good move, except that I truly hate dealing with multiple git repos like this. I've looked at
using `worktrees` and they aren't _quite_ what I want.

Really what I want is a monorepo that isn't a monorepo. I want each project to have an independent
history, but I also want to be able to tie commits together across repos. Right now when I make an
update in `telperion`, nothing coordinates it with `laurelin`. I _can_ do this through flakes (make
each flake track via the remote git repo, update to specific SHAs, then do everything the 'intended'
way, as I understand it), but this, plainly, sucks. Iteration on a change becomes difficult when
building it, and while it is very handy to create 'canonical' deployments of a suite of tools, it
isn't great for hacking on a lab, where purity isn't as valuable. I still want to be able to track
that compatibility information, but most of the time I want to do it outside of my actual IaC; and
instead have my 'monorepo' actually just be a bunch of independent git trees in the same git
_database_, but with an additional way to tie two commits together when they are 'compatible'.
Ideally also allowing that tie to be revoked if a later discovery shows they aren't compatible.

The idea is still a little nascent, but I think this is doable in the context of `git` but with
different semantics to the standard `git` repo. 

In any case, I need another project like I need to increase my topological genus, so I'm just going
to focus on standing up some services and getting `btg` sorted.

# 3-AUG-2024

## 0026

Had to revert `toto`, I think I remember having an issue where it would serve DNS without issue for
a while, then start refusing connections thereafter. I remember going to `unstable` helped with
that, but I don't remember the details enough. I think there is a way to simply make NSD do the pass
through, but I need to go do some reading to remember how.

## 2036

I have run into an issue with my netboot setup, which points to a more general issue I had been
punting off until now.

I have a bunch of machines I'd like to netboot that, ultimately, really shouldn't be netbooted.
"Standard" (non-EFI) netbooting has a hard limit at a 4GB Ramdisk, and tbh, I don't want to go
beyond that generally since things get quite memory hungry quickly, so while moving to an .efi-based
boot system is probably 'good' in the long term, it helps entrench a bit of bad design I admitted
while building things.

Now I'm caught out a little earlier than I wanted.

Initially I had planned to build `gehenna`, a machine that would be a nix-store-over-NFS server, but
I read that this was nontrivial and projects like `tvix` exist but aren't yet ready for production.

Ideally the system would work thus:

Boot every machine to a common nix image that is stripped to the barest essentials, and contains
only one post-boot script that asks it to be configured by some remote configurator. This base image
would mount a nix store over NFS specific to that machine, so that it can then be treated exactly as
if it were a 'regular' machine with a persistent nix store, but where that store is actually located
on the far side of a network connection. This has an obvious duplication issue (different machines
will likely share the same nix store objects, so they will be duplicated across the network), but I
figured:

1. Probably whatever native dedup happens would be sufficient to minimize the pain
2. I don't really have a big enough architecture in mind to warrant fixing that storage problem
   until I have it.

Then I read [this](https://xyno.space/post/nix-store-nfs) which made me think I could do something
about halfway between what the author does and my idea. A main .ro store with a .rw store per
machine mounted over it, I didn't actually realize this was possible with NFS, but it actually seems
pretty straightforward. The author there uses a tmpfs, but there is no reason I couldn't use a
persistent store if I preferred, then I could factor out common values periodically into the .ro
side to minimize duplication.

I think this is a good idea, but I think it's going to take a pile of work to get right, so I'm
going to focus for now on getting BTG formatted with 'real' storage so I can carve off a chunk for
my dev VM and do things 'the old fashioned way' with a real backing disk, but I definitely need to
do some more research on how to approach building `gehenna` and the NFS store.

I really like the idea of a sort of 'stem cell' VM that I can differentiate simply by mounting the
right underlying store and doing some command at it to 'activate' whatever configuration lives on
the other side of that, I don't think such a thing would be too difficult. I could also see having a
simple .ro-only approach and having builds happen entirely on the `gehenna` side rather than the
client side, design is needed.

## 2102

A brief thought on the UEFI netbooting, in particular, this solves a major defect in terms of
security, BIOS netbooting (what I'm doing now) is only over insecure protocols, fine for a closed
lab, bad for anything that might ever be exposed to the internet, UEFI netbooting can be done over
HTTPS, so definitely needs doing, for now I have BTG and DOP both standing up on a netbooted image
via BIOS netbooting, so hopefully that unblocks me and I can return to UEFI later.


# 5-AUG-2024

## 1144

I've got the format-disks stuff wrapped up in some Nix code now, I need to extend this into a
module, but essentially it just writes the `format-disks` script based on the Attrset I feed it; it
should be extensible to other machines, but does expect to be able to wipe all specified disks so
it's still an imperative management strategy, I doubt there is a good declarative one for disks
since they are essentially entirely made of statefulness.

In any case, I plan to manage these disks imperatively and track changes via the CHANGELOG in the
cadaster, so it's not a big issue.

Remaining on the TODO for this is:

1. Backups to Nancy (and thus to cloud)
2. Porting all the VMs over to use the disk I've set up
3. Setting up the NFS store on BTG

## 2331

I started moving the ZFS configuration into a dedicated module. This is pretty unnecessary but I
wanted to start it and leave a branch to come back to later. I set up the existing configuration
with a simple 'mode' flage to control whether it leaves the 'prepare' script in place, or if it just
tries to mount the datasets. I'm not automatically calculating the filesystems, but I think that
will be easier to do when it's properly a module and not just the shim.

# 7-AUG-2024

(and a bit of 6-AUG too)

## 0141

I'm doing something wrong with the filesystem definitions, I need to rebuild the pool again.

I got the script using wwns to make sure it persists, but that wasn't why the thing was breaking on
boot, to be honest, I'm not sure why it's breaking on boot, but I think I might be able to skirt all
of this because of [this](https://nixos.wiki/wiki/ZFS#Mounting_pools_at_boot), but that needs a
rebuild.

## 1142

I've got it mostly working with the automount, but I'd still like to understand what I was doing
wrong w/ the filesystem definitions; probably I needed to set different options or something, the
emergency shell never managed to start, so it's hard to figure out exactly what went wrong.

In any case, I like the way I laid out the disks and want to extend the idea of the cadaster in that
way, building a large nixos-style module system that describes all my hardware (and maybe integrates
with the nascent [nixos facter](https://github.com/numtide/nixos-facter) tool) and then can be used
to populate other parts of the configuration by reference seems pretty handy.

Ultimately I think it also points at a way out of the nix ecosystem while still maintaining the
'single common configuration system' that I like about NixOS. There's no reason to couple it to Nix
besides the convenience of the package manager, a declarative description of one's hardware and
virtual hardware architecture is useful in it's own right and could ostensibly be compiled to
instructions to configure virtually anything from a known starting state. My interest in it is
actually simpler, to boot, I just want to be able to simulate arbitrary architectures and employ
some kind of static analysis to surface issues at 'compile time'; I think getting anywhere near that
for architecture design could be extremely valuable.

## 1532

I'm going to do some tweaking to the `cadaster` idea, I'm going to split it between `narya` and
`telperion`, two items with the same underlying schema, both provided as flake outputs, `telperion`
will pull in and merge `narya`'s definitions into it's own at build time, but will otherwise be
unaware, that structure will then be available to all subsequent definitions. I'll probably just
keep the hardware defs in `telperion` for now, but they may be extracted to `laurelin` later if that
seems prudent.

The structure will be something like:

```nix

{
    compute = {
        "hostname" = {
            # metadata
        };
        # ...
    };
    storage = {
        disks = {
            "diskname" = {
                # metadata
                # includes a reference to `cadaster.compute.hostname` for where it's installed
            };
            # ...
        };
    };
    network = {
        switches = {
            "switchname" = {
                # metadata
                # Should include port maps and the like.
            };
            # ...
        };
        routers = {
            "routername" = {
                # metadata
            };
            # ...
        };
        firewalls = {
            "firewallname" = {
                # metadata
            };
            # ...
        };
    };
    racks = {

    };
    power = {

    };
    # ...
}
```

The idea is to represent each physical item in this with all it's metadata, but none of it's
configuration. Configuration then consumes this to build the actual configuration, and the
resulting configuration is then used to build the actual system images.

Essentially it's DCIM-as-code. I'm sure this has been done before, but reinventing wheels is fun.

I'm going to build each chunk as nixos modules, and then I can use that to attach additional
computed information to each section. Ideally I can use this to drive some sort of
testing/monitoring tools as well.

# 10-AUG-2024

## 1419

Working on the DNS issue with toto, I've set it up so all of KANSAS is bypassing my internal DNS so
that normal operations are maintained, and only my laptop has DNS issues, while my main machine
(Hedges) is not so-encumbered, that way I'm able to work freely on `toto` without knocking everyone
offline, maintaining the most important invariant my lab must maintain:

1. Do not interrupt the Bluey.

I think the issue is probably with the new NSD stuff, I can still resolve some `.canon` addresses
but I suspect that's just cache.

It's always DNS that gets you.


## 2251

This turned out to be a simple bit of misconfiguration, using `.canon` instead of `.emerald.city`,
and a missing port open.

I like it when it's simple.

# 11-AUG-2024

## 1512

Working on the hostkey problem, I'm starting simple, just getting it set for the non-persistent
(i.e., netbooted) machines, I also include a 'generic' one that I can use in case I don't want to
generate one right away (more for testing new netbooted machines).

I'm planning to try for a "Nix Store over NFS" approach since my netbooted machines should be more
or less RO. I think that should make 'most' of the infrastructure non-persistent; though I haven't
worked out exactly how I'm going to do the complicated dance there.

One upside of putting all my hostkeys in a single bucket is I *should* be able to pregenerate a
'known-hosts' file which I can actually trust to some extent, so that if I get an 'unknown host' it
would actually indicate something has gone awry.

At time of writing I'm just finishing up the experiment with `pinky` and will roll out the change
once it's ready. I've kept all the keys in `narya`, so they're out of the way for the moment.
Eventually these'll move to Vault and be pulled in via `turnkey`, so they won't need to be in any
repo.

This is also nice because it makes rotation pretty pleasant; I can just generate a new key, update
the relevant machines, and (eventually) regen my knownhost file appropriately.

## 2313

Got storage pools set up, I think I need to write something to sync the xmls back and forth, since
the easiest way to manage these right now is just to copy the xml back and forth and do the
adjusting in virt-manager.

# 12-AUG-2024

## 2033

Got some more stuff working w/ barge, needed to add `recommendedProxySettings` to each of the
proxied items. I still need to setup outbound VPN for these as well.

# 15-AUG-2024

## 1243

Got some stuff reorganized and pushed up. I need to build an installer image I can have `randy` boot
off of, so I can install on the 'real' disk and get to something functional, I also need to set up
backups on just the randy image independent of other things on `nancy`'s side. So some kind of
`rsync` handoff to network storage, etc.

## 1746

I think next step is a grafana/prometheus/loki stack, I'm tired of having to jump all over creation
to find logs.

# 17-AUG-2024

## 1346

Moved dashy to a raw YAML config in the repo, I'd like to next move this to a mashable nix-based one
using the existing nix->yaml conversion stuff, so I can have various parts of the infra
automatically contribute their dashy configs when dashy is enabled. 

```nix

{
    pageInfo = {
        title = "Emerald.City";
        description = "Off to see the wizard";
        navLinks = [
            { title = "Github"; path = "https://github.com/jfredett"; }
            { title = "NixOS"; path = "https://nixos.org"; }
            { title = "Dashy Docs"; path = "https://dashy.to/docs"; }
        ];
    };

    # ... snip for other sections
}

```

Should translate naturally, then the `section` section is just an attrset of section-name -> other
config.

# 18-AUG-2024

## 1013

As I work on getting the remaining `barge` services running, I'm thinking about the CI side of this
and how to keep all these machines updated.

I could set up `hydra`, but I think that's overkill for my use right now; it is nice that it's a
bespoke 'build nixos images' kind of tool, but I think I can probably get most of the value with
less setup using some `laminar` scripts that introspect on the `minas-tarwon` flake; and have it
periodically rebuild each of the `canon` images as `vm`s into a centralized nix store, then if the
target machines mount `/nix` over `nfs` and are otherwise mostly static (i.e., they don't have any
local OS state stored on whatever disks they may have), then it should be possible to verify the
image in CI, then automatically deploy when those images work alright.

Independently, I need to set up a metrics machine, and I think I'm going to create a second,
dedicated VM for it, and probably just set up the services using the other, 'just give it a
nixos-config' style container, more as an experiment than anything else. I should be able to re-use
the definitions in `laurelin` inside these containers, which would make it easier to 'promote' them
to full VMs if I wanted to, which is kind of cool -- same configuration in multiple locations.

I'd also like to experiment with `microvm.nix`, which I've read a bit about, and more generally with
microvms.

Lastly, I've removed `elenta` for now, as I'm not really doing anything with it and I don't think
it'll be necessary for a while. Right now building in place is easier, and working out the
deployment strategy for multiple domains is a problem for future Joe.

# 19-AUG-2024

## 0006

I've got loki running, promtail modules roughed in, and I just need to get the prometheus exporters
set up the same way. I've set them to opt out, since I'd rather have the logs then remain dogmatic
to the 'explicit-is-better-than-implicit' principle.

I like how promtail converts the nix code directly to JSON, and I need to steal that for Dashy, as
that gets me exactly what I want, each service can automatically provide a dashy snippet that I can
opt into on a per-dashy-instance basis.


# 20-AUG-2024

## 1738

I rigged up vpn routing, but ran into an issue where because the containers now routed through a
VPN, they cannot see my local DNS for local DNS queries. I think it should be possible to bypass
this but I don't really want to at the moment and the whole setup needs some more significant
refactoring anyway, so for the moment I'm just going to turn it all back off but leave my changes in
place.

All this happens in `narya`, though, so it's not really visible to anyone but me. Maybe someday I'll
open source that bit but for now the mystery shall remain.

Independently and in addition, I stood up `daktylos` in the `emerald.city` domain to be the
loki/prom server, and wired up exporters for nginx, systemd, and the `node` exporter. There is
definitely some overlap to unpack for these, and I'm beginning to dislike how fat `telperion`'s
flake is growing, but I think the plan will be to move the logic to `laurelin`'s library, then have
a leaner `telperion` library which does the various calculations. Domains eventually should be
flakes unto themselves, I think, so for the moment that stuff can stay put, but the `scrapeTargets`
key is definitely in need of refactoring.

I also added additional horsepower to `barge` while I work on getting things configured, I really
don't care for the `*arr` apps, they feel bloated and it's odd to have them split the way they are,
but there doesn't seem to be any reasonable alternative out there, so I think I'm stuck with them
for now.

Remaining, I need to get my dev VMs built, and I need to start thinking about NFS mounting the `nix`
store, the two things are not unrelated, but it is a big job so I might take a break from this for a
bit after I finish the work I've got going now.

## 1821

I'm exhausted. There are performance issues to chase down, and things to fix, but I'm tired so I'm
going to put this down for a few days, I think.

## 2049

One last thought before I put things down, I suspect the majority of my problem is that barge is
overloaded with IO, network, and cpu intensive tasks. I spent a little time setting up some panels
so I could better diagnose, and this not to say I didn't see it coming, I think if I split out the
rev-proxy into it's own VM that's shared between `daktylos` and `barge`, and then split the
torrent/vpn component into it's own VM(s), that should get me much closer to where I want to be. I
also suspect at least some of it has to do with the way networking is setup on BTG; since all the VM
traffic has to go in and out through the same pipe, things are simply not very quick when I'm
saturating said pipe. I may temporarily create a secondary bridge that can be dedicated to the
torrent side.

I also suspect I've got the CPUs configured in a poor topology that is confusing things and perhaps
slowing them down a bit. I should also review and ensure all the relevant kernel modules and such
are loaded -- I am at least two layers of virtualization deep, I suppose I could also try running
these as containers directly on the host, but I'm inclined to try to get this working (as eventually
I plan to run all this on k8s anyway).


# 24-AUG-2024

## 0101

```nix
nix-instantiate --eval -E 'builtins.fromJSON (builtins.readFile ./telperion/emerald.city/configs/grafana/dashboards/system-view.json)' | nixfmt
```

and

```nix
nix-instantiate --eval -E 'let template = import ./telperion/emerald.city/configs/grafana/dashboards/system-view-template.nix; in builtins.toJSON (template "daklytos")'
```

are my handy snippets of the day, the former I saw on a discourse answer, for how to quickly convert
json -> nix. I have some grafana dashboards I want to templatize, and the first step is getting them
converted. This made short work. Now I took this simple system dashboard and made it into a
template, I can then rattle off a bunch of basic dashboards for each of my services, and then
specialize them and store the specialized versions in the `configs` directory of telperion to
override it. `daktylos` uses a library function from `laurelin` to invoke the dashboards that are
already stored over there, and I'll build up some helper functions as it makes sense. Once I've got
the initial version built, when I specialize them I can import them back into the repo, and
eventually I'll set up something automated to push them to their own git repo or something.

# 27-AUG-2024

I got a bunch of things set up in glamdring over the last couple days, I'm hoping to get my workflow
more contained inside of vim itself, so that ultimately I can more or less obviate the need for tmux
and rely only on a vim server. To this end I added `neogit` (and `gitblame`, `gitgutter`, and
`diffview` to support it), `neotest`, and `toggleterm` to my setup. The quake-style terminal is
perfect for what I need most of the time, and once I sort out a good system for backgrounding
processes from it I shouldn't really need more than the one anyway. A glance of the help did suggest
it is possible to run a couple independent terminals via the plugin.

# 31-AUG-2024

## 2150

I've been working on getting some more exporters set up, and I am finding a 'next-domino' problem as
I roll out the `ipmi` exporter, I need to deploy each machine with the new config, but once I do
that I need to deploy `daktylos` to update it's configuration to search. This made me think about
how the eventual 'real' methodology rolls out; I want to be able to develop an abstract
configuration of machines such that the configuration will be the same no matter how it is
deployed, so that I can then specify the resources necessary for a machine to play a particular
role, and then separately have code that tries to efficiently deploy it using some configuration
data. Essentially separating design from deployment and creating something like a 'high level'
terraform.

This problem -- knowing what to deploy when some configuration changes -- is very similar to the
incremental compilation problem, and I think it'll be an interesting thing to build strategies for
in the operations context. For now, I just have to remember to deploy them sequentially; I think
once I set up the CI server I'll add some simple logic to allow me to trigger common build patterns
with flags or something. Ideally I could have some way to specify what parts of the config changing
it cares about, but that's probably much more complicated.

# 2-SEP-2024

## 1355

https://nix.dev/manual/nix/2.18/advanced-topics/distributed-builds.html

I need to set up a builder-file that I can put into the justfile that uses DOP, maybe a VM on BTG,
Archi, Hedges (eventually), and whatever other hardware seems reasonable to use as a builder. I
don't think I have hyprland set up correctly to use the cache, so I'm stuck compiling. I don't -- in
principle -- hate the idea of compiling it, but it is slow and it'd be nice to have it build on the
giant R730 that is otherwise unoccupied.

https://nixos.wiki/wiki/Distributed_build

That wiki indicates I might be able to specify this in nix directly (rather than through a separate
file), that'd be ideal since I can probably calculate it and have an option set within `laurelin`
that allows a machine to mark itself as a builder. That'll move nicely into the `gehenna` setup

## 2107

I think I have an idea for how to improve the way I'm handling cross-flake concerns (e.g.,
calculating DNS or scrapeTargets), these should live in a library provided by `minas-tarwon` itself,
it can pass along the other flakes for reference, but otherwise be a 'normal' nix library. Then I
can set up a just job to start a repl with this library preloaded; and be able to directly interact
with the library; and additionally I can create a 'run' job that takes an argument, evaluates it,
and shows the result, just wrapping the `nix-instantiate` command.

That'll can be used as plumbing for a nicer CLI tool at some point, but for now it should make it
easier to organize the various scripts that currently just live in the flake.

# 8-OCT-2024

## 2140

Full disclosure, I scrapped an old entry that was incoherent, I was jotting down a TODO List and not making a lot of
sense.

I got a P40 installed in BTG, and I'm working on figuring out if I can set it up as an MDEV or if I just need to
passthru to `randy` and call it. I'm leaning toward the latter. I have a 2080 also hanging around that I'll install once
the P40 is working. Between these I should have plenty of GPU horsepower to insource my LLM usage and also get a proper
dev VM built for both `randy` (for normal work) and `hardie` (for security/pentesting).

I'm hoping that if I can get the MDEV set up, I'll be able to run a few VMs backed by at least the P40, ideally it's the
main 'development' card; and then I can use later hardware for the actual compute task on DOP.

Spricht, DOP is getting set up to work as a development machine right now, the build times on `hazel` are getting out of
hand and it's not like DOP is doing anything else right now.

Besides these minor roadblocks (like having no idea how MDEV works), things proceed apace. I've been focusing much more
on [hazel](https://github.com/jfredett/hazel) recently, so the lab work has slowed. I'm using it as a testbed for some
tools I need to build for `brocard`. In particular working with `ratatui` has been pretty fun, and `tokio` less
terrifying than advertised.

# 12-OCT-2024

## 2157

I've been having an issue on DOP (and BTG, for that matter) where after running an in-place update via `just deploy
dragon-of-perdition`, for instance, it will restart some part of the networking stack and then fail to bring it back up.
Killing my SSH connection and making it a real pain to return to function.

I think this has to do with the silly 'bond everything' thing I did, but I like the silly thing so I've just gotta
figure out how to fix it and I didn't want to forget.

## 1335

I've been doing some work on the the nvim config today, getting DAP set up and generally tuning up the editor, which
I've neglected for a bit now while I got used to all the changes I made the last time I was stuck on other things.

I'm thinking I need to adjust all my keybindings to be more consistent and more focused. Right now I manage them poorly,
and there is no mnemonic consistency to them. I do prefix most of them with leader, and I generally have 2 'kinds' of
bindings, `<leader><something><leader>` and `<leader><something><space>`. I can 'arpeggiate' these, so I don't have to
hold them all down (chord), but if I type them quickly, it feels like one 'action'. I like commands to alternate between
hands, as well, so `,l,` is bad, because I hit `,` with my right hand, and then have to hit `l` with my right as well,
which is uncomfortable.

What I'd like to do is establish two kinds of commands with two separate leader keys. A "Right leads" uses my current
leader and starts and ends on the right side with the leader, a "Left leads" uses a different leader key and starts and
ends on the left hand. The third kind of command would be a 'double key' command, like `<leftleader>ll` or
`<rightleader>dd`, these need to be reserved for the most common commands, since they are by far the easiest to type so
long as I ensure that the keys are on opposite sides of the keyboard.

The goal is to have commands grouped mnemonically both by letter (i.e., the first letter of the command should be mapped
consistently to some subfunction, so all my telescopes might be `<rightleader>t<something>` (where `<something>` might
be several characters), and my Debugger commands file under `<rightleader>d<something>`. Ideally I _also_ sort command
'kinds' by hand, so that, maybe, all the commands for altering editor state (e.g., opening files or whatever) are 'left
hand' commands, and all the commands for inspecting the state of the object being edited (e.g., running tests, checking
coverage, etc) are 'right hand', not sure how to break that up yet.

This, however, will make it easier to remember commands and build up a little cheatsheet, at the moment I routinely have
to poke through my code to figure out where it all lives.

This should also make it a little easier to build up some library functions for this kind of thing. Something like:

```nix
{
    rightleader = {
        d = {
            "o" = "lua require('dap-ui').toggle()";
            "c" = "lua require('dap').continue()";
            "n" = "lua require('dap').step_over()";
            "i" = "lua require('dap').step_into()";
            "o" = "lua require('dap').step_out()";
            "d" = "lua require('dap').toggle_breakpoint()";
        };
        f = {
            "f" = "Telescope find_files";
            "b" = "Telescope buffers";
            # ...
        };
    };
    leftleader = {
        e = {
            x = {
                modes = "nox";
                action = "some action";
            }
        }
        # snip
    };
}
```

If the value on the RHS of the assignment is a string, it's interpreted as the `action` with default mode and all that,
if the value is an attrset, it must be the submodule specifying modes/actions/etc.

by default, it will assume the command is for `nox` and that it's a normal mode command ended with `<CR>`. I can then
build this object as a nix module, then use it to create the keymap and the cheatsheet. Each plugin can specify it's own
keybindings locally, which get included conditionally with the plugin.


# 27-OCT-2024

## 1109

Finished the passthrough setup for randy, next steps are to get BTG set up w/ the 2070 I have and to run cables from the
rack to my office for HDMI and DP from BTG. Then I can use `looking-glass` and BTG for near-native performance on the
VMs.

Once these are done I'll look towards migrating `mirzakhani` into this model as well; and maybe move it down to the rack
as a result. Then I'll have two hosts with plenty of GPU horsepower I can eventually MDev up.

I haven't dug too deeply into the MDev side of things, but from the little I've read so far, I'm hoping I can have a
setup which gangs up all these GPUs, less for the gaming side of things (if I have to pull one out of the gang to run
whatever, so be it), but for the compute side it'll be important. A quick test with `hashcat` got me 13GHashes/s on the
P40 alone. I can't get it to run on the 'CPU' on the VM, since it's a QEMU vCPU it doesn't see it as a 'real' CPU, but I
suspect 13GHashes/s is going to translate to a pretty good rate of speed on Brocard. Assuming I get about the same in
candidates-tested-per-second, it's 11Y of compute time, but I have good reason to believe it'll be faster (since MD5 is
compartively more complicated than what I'm doing with brocard) and hopefully I can clear the 2e64 space somewhat more
quickly without having to scale out too much.


# 27-NOV-2024

## 1214

I'm thinking I might move to an iSCSI-based approach for VMs for the near term.

The netboot experiment has been cool, but it's finicky with total available space and also it's a really slow process to
rebuild the images. I think I can get a lot of the same benefits (centralized storage, decoupled configuration, etc)
with iSCSI and eventually some kind of overlay system.

I'm going to build an iSCSI gold-image that can be cloned. It will have a baseline install of a recent NixOS, and will
be periodically mounted and updated. When creating a new machine, I'll have scripts that:

1. COW Clone this iSCSI base image
2. Create a new RW iSCSI disk
3. Configure these disks for the new machine.

The machine would then mount the two disks in an overlay, booting form the base COW clone and then writing to the RW
disk with any subsequent updates.

Machines can be periodically recreated, and any dedicated data can be placed on an independent iSCSI, so the COW clone
is just the common shared underlayment, the RW disk is for machine-specific config, and additional independent disks for
application data.

This will require a lot of automation around iSCSI creation, but for the immediate term I'll probably just make disks
per machine and install that way, a hard clone of the base image should do it. I'll serve them out of Nancy and once
it's working I can work on building a better iSCSI server.

To that end, I think I'm targeting 100GBe Ethernet out of the gate, I considered other protocols, and they may be useful
if I want to split out a backplane for data, but in the short term I'm going to keep it simple and have a single flat
network on 100GBe between all physical components that support it (currently only 3 such machines, but I expect that I
will have a few more in the future, so I'm aiming for something in the 16 port range on the switch).

Ultimately the 100GBe switch will link over a pair of 10GBe links to Condorcet, and then the majority of 'normal'
machines in the lab will still route through there, but the 100GBe backend will be used for the Racked machines to share
data, the traffic is low enough that a flat network should be fine, and I do want to move to IPv6 eventually anyway, at
which point the routing will be much simpler.

I _may_ start-from-v6 on this project, and use it as a lever to excise v4 from my lab, but tbh I'm not sure it's worth
it in the short term.

All of this mess brought to you by frustrating issues with my prometheus server not mounting NFS the way I like. Hell of
a lot easier when it just looks like a disk.

## 1619

I think I'm going to start by replacing some of the NFS-as-a-target stuff with iSCSI. NFS is really not the right tool
for what I want, which is a pile of bits that the VM can read/write from on it's own. I can still netboot the machines
but have all the data live in iSCSI volumes. I should be able to extend my existing network-storage code for this, and
I'll have to manually recreate the luns, but I should be able to query the infra code to generate an appropriate list
for Nancy at least, and then that list can eventually drive a proper iSCSI host.


## 1940

Okay, actual plan:

1. [x] I'll create NixOS-24.11 as a LUN in my Synology (Nancy)
2. [~] I'll mount this LUN on `pinky`, my lab VM, and install NixOS 24.11 on it.
3. [ ] I'll then clone this LUN to a new LUN, PINKY-24.11-ROOT, and mount it on pinky as its new root disk
4. [ ] I'll alter Pinky's configuration till it can boot from this iSCSI disk.

After this, I can recreate the other VMs using this new system, the clones will be RW per machine and full copies (since
COW doesn't seem straightforward here), but it'll get the system running and I can work on it from there.

I'm a little ways into the plan above and I don't expect it'll take to long to get running.


# 15-DEC-2024

## 0037

I've got things sorted I think. I have a spare 2070 I can use for DOP, I'll pull a bit of it's memory (half, 64GB) and
put it in BTG. `randy` will stay there for doing GPU workloads and running `ollama` models and the like for selfhosted
copilot. DOP will become my main dev machine again, with 64GB of memory and 2070 to run upstairs to my office. To
simplify things I may get a SSD for DOP, that way I can just directly install nixos on the SSD. It abandons entirely my
netbooting experiment, really, but I think it's probably the right move -- I can revisit netbooting in the future when I
have a more stable environment with all my systems running what I need them to run.

# 20-DEC-2024

## 1249

I went ahead and picked up a SSD for DOP to run it's OS off of, this should allow me to get moved _back_ over to DOP as
a dev machine, randy will still be used as a dev box, but more for GPU workloads and the like until I get it tuned up.
It'll probably be getting my test configs set against it as well, etc.

I'm going to put the 2070 in DOP as well so there is some GPU horses there, but ultimately I do want to run both DOP and
BTG as hypervisors running off iSCSI for boot. I think that gets me the best of both worlds in terms of keeping the
disks separated from the machines that manage them, and sets me up for a move to a DIY SAN eventually.

# 30-DEC-2024

## 2249

Working on setting a few things up in `glamdring`; in particualr I'm working on getting set up on a new terminal
emulator, probably `ghostty`, though `kitty` remains in contention. In particular, I figured out (via `ghostty`) how to
get kitty to work alright with `tmux` using the same (instructions)[https://ghostty.org/docs/help/terminfo] as
`ghostty`. That solved the immediate issue with `kitty` everywhere, but I do like the defaults of `ghostty` better?

In any case, the main motivation is getting image-in-terminal to work. `kitty` has the edge there right now, on account
of it working correctly in a nested `neovim-with-image.nvim-in-kitty-mode in tmux in kitty` situation, which `ghostty`
presently doesn't. I want to try the alternate backend for `image.nvim` to see if it works any better, but I know
`kitty` already has some existing integration with `nix` anyway, so it may be the better choice.

I also set up `stickybuf` and started working on `avante` integration with a local `ollama` hosted model; but I have
some networking that needs doing there as well.

Hoping I can drop my ChatGPT and Copilot subscriptions in favor of the self-hosted setup.

I also switched over to `lix` after getting stung by [9708](https://github.com/NixOS/nix/issues/9708); I don't know if
I'll stick with it, but it seems to be a drop in for now.

# 19-FEB-2025

Nearly deleted a bunch of things, fortunately I had just commited everything off.

Lemony snickets these last few weeks.
