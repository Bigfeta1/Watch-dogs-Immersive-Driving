# Watch Dogs Immersive Driving

Two Nexus Tools mods for Watch_Dogs (PC) with Living_City 2.9.5, built 2026-10:

| Mod | What it does | Details |
|---|---|---|
| `mods/living_city_interior_cam` | First person in-car camera: look up (15°) / down (35°) and left/right (60°), smooth turning, camera rotates in place, free look while parked, recenters once you drive; camera shifts away from the driver's face when looking left. Motorcycles get a rider first person view: rider visible, look up 70° / down 12°, rider hidden when looking up, camera leans forward with speed and holds until 1 s after stopping, looking around while riding returns to forward after 2 s. Cars and bikes start in first person when you get in; on bikes the camera key cycles 3rd person -> bike-mounted -> rider view without a 3rd person frame in between (needs `NearClipFix.asi`). | [README](mods/living_city_interior_cam/README.md) (full history and test results) |
| `NearClipFix.asi` (in `mods/living_city_interior_cam/_dev/near_clip_fix/`) | ASI plugin: lowers the camera near clip plane (game 0.25 m, now 0.13 m) so car roofs and nearby geometry are no longer cut away; also drives the bike rider lean, the look-up hide and the bike camera key frame hold. Settings in `NearClipFix.ini`, live-reloaded. Steam build only (checks the exact engine build and code bytes, otherwise does nothing). | [README section "Near clip fix"](mods/living_city_interior_cam/README.md) |
| `mods/living_city_speedo_fix` | Living_City's speedometer and fuel gauge readable in first person (bottom left of the view), hidden while The Fox Mod's profiler is up. | [README](mods/living_city_speedo_fix/README.md) |

## Install / restore

1. Copy both folders from `mods/` into `Watch_Dogs/data_win64/mods/`.
2. In the Nexus Tools Mod Manager enable both, with workspaces enabled, above `living_city` and
   `living_city_graphic_tweaks` in priority. Rescan if new workspace files are not picked up.
3. `Living_City_MOD_CONFIG.txt` is the Living_City settings file used here (goes in `Watch_Dogs/data_win64/`).
4. Copy `mods/living_city_interior_cam/_dev/near_clip_fix/NearClipFix.asi` and `NearClipFix.ini` into
   `Watch_Dogs/bin/` (loaded by the `dinput8.dll` ASI loader that Nexus Tools installs). Delete the `.asi` to remove.

Requires Living_City 2.9.5 (and its Graphic_Tweaks, which the camera database is based on) and Nexus Tools.

## Backing up again

`./sync.sh` copies the current mod files from the game install into this repo (edit `GAME_MODS` if the
game lives elsewhere), then commit and push.

## Contents note

The camera databases (`workspace/generated/databases/generic/*.lib`) are edited copies of the game's and
Living_City's files, and `_dev/` holds the unmodified base copies they are built from. The speedometer
script is Living_City's with changes. Watch_Dogs is © Ubisoft; Living_City belongs to its authors.
