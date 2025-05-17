#!/usr/bin/env bash

set -xe


MAC=$(echo $1 | tr -d :); shift
machine=$1; shift
domain=$1; shift


TARGET_DIR="/mnt/emerald_city_netboot/$MAC"
TMPDIR="/storage/minas-tarwon/${machine}"

echo "Preparing necessary directories"
mkdir -p $TARGET_DIR


echo "Build ${machine} image"
nix build --impure \
  --log-format bar-with-logs \
  --out-link $TMPDIR \
  ".#nixosConfigurations.\"${machine}.${domain}\".config.system.build.netboot"

# Shuffle images only if previous command succeeds -- `set -e` ensures this won't run
# unless that's true.
if [ -e $TARGET_DIR/latest ]; then
  echo "Shuffling ${machine} images"
  latest_creation_time=$(stat -c %Z "$TARGET_DIR/latest")
  timestamp=$(date -d "@$latest_creation_time" +"%d-%b-%Y-%H%MET")
  mv $TARGET_DIR/latest $TARGET_DIR/$timestamp
fi

echo "Copy ${machine} image to mount"
rsync -r --copy-links --info=progress2 --info=name0 -a $TMPDIR/ $TARGET_DIR/latest

echo "Clean up"
rm -rf $TMPDIR
