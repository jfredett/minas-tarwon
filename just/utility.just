# rsync source to target, copying symlink targets
[group('utility')]
rsync SOURCE TARGET:
  sudo rsync -r --copy-links --info=progress2 --info=name0 -a "{{SOURCE}}" "{{TARGET}}"

# Start a Nix REPL
[group('utility')]
repl: update
  nix --extra-experimental-features "flakes repl-flake" \
    repl -f '<nixpkgs>'

cloc *args:
  cloc --vcs=git --exclude-ext=.rc . narya glamdring laurelin telperion turnkey {{args}}

host-key PATH:
  ssh-keygen -f "{{PATH}}.ed25519.key" -N "" -t ed25519


restart-service HOST SERVICE:
  ssh "{{HOST}}" "sudo systemctl restart {{SERVICE}}"
