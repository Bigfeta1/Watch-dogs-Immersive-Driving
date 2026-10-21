# Watch Dogs Immersive Driving

Two Nexus Tools mods for Watch_Dogs (PC) with Living_City 2.9.5, built 2026-10:

| Mod | What it does | Details |
|---|---|---|
| `mods/living_city_interior_cam` | First person in-car camera: look up (15°) / down (35°) and left/right (60°), smooth turning, camera rotates in place, free look while parked, recenters once you drive. Motorcycles get a rider first person view (rider visible, follows the riding tuck with speed). | [README](mods/living_city_interior_cam/README.md) (full history and test results) |
| `mods/living_city_speedo_fix` | Living_City's speedometer and fuel gauge readable in first person (bottom left of the view), hidden while The Fox Mod's profiler is up. | [README](mods/living_city_speedo_fix/README.md) |

## Install / restore

1. Copy both folders from `mods/` into `Watch_Dogs/data_win64/mods/`.
2. In the Nexus Tools Mod Manager enable both, with workspaces enabled, above `living_city` and
   `living_city_graphic_tweaks` in priority. Rescan if new workspace files are not picked up.
3. `Living_City_MOD_CONFIG.txt` is the Living_City settings file used here (goes in `Watch_Dogs/data_win64/`).

Requires Living_City 2.9.5 (and its Graphic_Tweaks, which the camera database is based on) and Nexus Tools.

## Backing up again

`./sync.sh` copies the current mod files from the game install into this repo (edit `GAME_MODS` if the
game lives elsewhere), then commit and push.

## Contents note

The camera databases (`workspace/generated/databases/generic/*.lib`) are edited copies of the game's and
Living_City's files, and `_dev/` holds the unmodified base copies they are built from. The speedometer
script is Living_City's with changes. Watch_Dogs is © Ubisoft; Living_City belongs to its authors.
