# Update all flakes
[group('update')]
update: local-update remote-update

# Update all flakes if the last update was more than 15 minutes ago 
[group('update')]
remote-update:
  #!/usr/bin/env bash
  echo "$(tput bold)Updating all flakes$(tput sgr0)"

  if [ ! -f /tmp/last-update ]; then
    touch /tmp/last-update
  fi

  if [ $(($(date +%s) - $(date -r /tmp/last-update +%s))) -gt 900 ]; then
    echo "$(tput bold)-> Updating $(tput sgr0)"
    nix flake update --no-warn-dirty
    touch /tmp/last-update
  else
    echo "$(tput bold)-> Skipping update, last run was less than 15 minutes ago$(tput sgr0)"
  fi

# Update only the minas-tarwon affiliated flakes.
[group('update')]
@local-update:
  echo "$(tput bold)Updating local flakes$(tput sgr0)"
  just update-input elenta
  just update-input narya
  just update-input glamdring
  just update-input laurelin
  just update-input telperion

# Update a specific minas-tarwon affiliated flake in both the parent and child directory
[group('update')]
@update-input INPUT:
  echo "$(tput bold)-> Updating {{INPUT}}$(tput sgr0)"
  nix flake lock --no-warn-dirty --update-input {{INPUT}}
  nix flake update --no-warn-dirty {{INPUT}}/
