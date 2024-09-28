# Push all repositories
[group('git')]
push:
  git push
  mani exec -a git push

alias st := status
# Show git status for all repos
[group('git')]
status:
  git status --short
  mani exec -a git status -- --short

# Update all lock files, assumes empty staging area
[group('git')]
commit-locks:
  git add flake.lock
  git ci -m 'Update flake.lock'
  mani exec -a git add flake.lock
  mani exec -a -- git ci -m 'Update flake.lock'

refresh-locks:
  rm flake.lock
  nix flake update
  mani exec -a rm flake.lock
  mani exec -a nix flake update
  just commit-locks
