# Minas Tarwon

> Minas Tarwon, n. Quenya (Late): Tower of Fieldstone.

This workspace contains my definitions for my homelab, _Minas Tarwon_. My homelab is currently made
up of a few moving parts, split into the different subrepos/subflakes.

> [!WARNING]
>
> I truly don't know how best to organize this all yet, I've adopted a 'blow everything into it's
> own repo/flake' as a starting point, the items within this repo's purview are, therefore, quite
> subject to abrupt change. I don't recommend using any of it right now, but I do hope to extract
> useful, generic stuff from it. You're most likely to find that in `laurelin`, though, not here.

> [!WARNING]
>
> You may notice reference to flakes/repos not appearing in my public github profile. This is
> deliberate, a number of private configuration values are more convenient to place into a private
> repo for the present. Eventually I hope to eliminate the need for such a thing (likely via
> `turnkey` or similar solution), but for the moment ease prevails over correctness.

## The Cadaster

The Cadaster is a list of all the hardware I own

### Pandemon.ium

Lab-dedicated machines (or near to it, really it's 'machines that belong solely to me')

1. Babylon the Great and Dragon of Perdition
    - Dell R730s
2. toto
    - SFF Boot/DNS server
3. Beatrice and Bernard
    - RPi 4s
4. Nancy
    - Synology NAS
5. Archimedes
    - Dell G7 Laptop
6. Mirzakhani
    - Windows Gaming Machine
7. Work
    - A machine provided by my employer for doing things for which they pay me.
8. Eigendeck
    - A steamdeck

### Kans.as

These are non-lab machines (really, 'machines that don't belong solely to me')

1. Maiasaura
    - SFF Media Client
2. Kepler
    - Astrophotography Control Machine
3. Hedges
    - A Mac Studio
4. Diplodocus
    - A Macbook Air

### Networking Equipment

1. Condorcet and Voltaire -- a pair of 3750E switches. Voltaire is presently broken
2. Oz -- a Netgear GS108E switch
3. Ifrit -- a SFF of unknown provenance 'pon which pfSense runs.

### Other

There may be other items I haven't listed, the 'real' list is in `telperion`.
