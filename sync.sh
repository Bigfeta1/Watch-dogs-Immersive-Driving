#!/bin/sh
# Copies the two mods from the game install into this repo (run before committing a new backup).
# Skips test logs, Python caches and _dev/nearclip (106 MB memory dump, over GitHub's file limit).
set -e
GAME_MODS="${GAME_MODS:-/mnt/d/Games/Steam/steamapps/common/Watch_Dogs/data_win64/mods}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HERE/mods"
for mod in living_city_interior_cam living_city_speedo_fix; do
  rsync -a --delete \
    --exclude 'camera_log.csv' --exclude 'head_log.csv' \
    --exclude '__pycache__' --exclude '_dev/nearclip' \
    "$GAME_MODS/$mod/" "$HERE/mods/$mod/"
done
cp "$GAME_MODS/../Living_City_MOD_CONFIG.txt" "$HERE/Living_City_MOD_CONFIG.txt"
echo "synced from $GAME_MODS"
