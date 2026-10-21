# Living_City Speedometer First Person Fix

Local add-on for Living_City 2.9.5 (made 2026-10-12). Living_City's speedometer and fuel gauge are
map markers attached to the car (1 m above it), so in the first-person driving cameras they end up
out of view. This mod moves them to the bottom-left of the view while in first person, and puts
them back above the car in the chase cameras.

## Files

| Path | What it is |
|---|---|
| `workspace/domino/user/windycity/custom_scripts/speedometer.lua` | Patched copy of Living_City's speedometer script. Nexus Tools serves it in place of the one packed in `living_city.dat`. |
| `Speedometer_FP_CONFIG.txt` | Settings (position, first-person distance, profiler hiding, debug). Edit, save, restart the game. |
| `modconfig.json` | Nexus Tools mod manifest. |
| `_dev/speedometer_original_living_city_2.9.5.lua` | Unmodified script extracted from `living_city.dat` (sha256 `61f53547...49e9ba`). |
| `_dev/build_speedo.py` | Rebuilds the patched script from the original: `python3 build_speedo.py <original.lua> <output.lua>` |
| `_dev/sim.lua`, `_dev/sim2.lua` | Lua 5.1 simulations of the placement / profiler hiding with stubbed engine functions. |

## Setup

In Nexus Tools Mod Manager (`bin/ModManager.exe`): enable this mod, workspaces enabled, priority above
`living_city`. Check it loads: `%APPDATA%\Troplo\Nexus\cout.log` should contain a line with
`mods\living_city_speedo_fix\workspace\...\speedometer.lua`.

## How it works

- Every speedometer update (0.1 s) it reads the camera with Nexus Tools' `SH_Camera_GetEntityId()` and
  measures the camera-to-car distance. Under `Distance` (3.0 m) counts as first person (in-car view
  measured at 1.3 m; chase cameras are further).
- In first person the markers are re-attached to the car at "camera position + Offset_X/Y/Z"
  (metres, car-relative: X right, Y forward, Z up), so they sit at a fixed spot in the view.
- The Fox Mod shows the minimap (bottom-left) only while the Profiler is on. It stores that state in
  `Globals._CUSTOM_SCRIPTS._Fox_ProfilerOn`; with `Profiler_Hide = 1` the gauges hide in first person
  while it is on.
- Hiding/showing resets the labels to `-` / `-%` first (the same order Living_City uses when exiting
  a vehicle). Without this the fuel number stayed blank after the Profiler closed until the
  percentage changed, because a label set to the same text is not redrawn.

## Changes made to Living_City itself

None. The only edit outside this folder is the user's own `data_win64/Living_City_MOD_CONFIG.txt`
(`_Speedometer = 2` for MPH). Note Living_City reads that file from `data_win64/`, not the copy in
`mods/living_city/` (that one is the template used by its Nexus Tools menu).

## Bikes (added 2026-10-20)

With `living_city_interior_cam` the bike has a rider first person view. In that view (camera behind the
dashboard point) the speedometer and fuel gauge sit on the bike's dashboard, a fixed point on the bike
(`Bike_X/Y/Z`, default (0, 0.57, 0.90) m from the bike centre, estimated from a rider-view screenshot:
cluster ~21 deg below centre, ~0.5 m ahead of the camera at (0, 0.07, 1.09)), fuel `Bike_Gap` below.
The bike-mounted view (camera at (0, 0.66, 1.38), ahead of the dashboard) and cars keep the bottom
left placement. `Bike_Dash = 0` turns it off. Dry run: `_dev/sim_bike.lua <speedometer.lua> <1|0>`
(stub world; rider view -> dashboard, bike-mounted -> corner, car -> corner, both binding modes).

## Known issues / notes

- Some cars show the outside through the top-left corner in the in-car view. That camera comes from
  Living_City's `cameracontext.lib` (`Vehicles.Driving.Interior.New Interior.<class>`, one camera
  per vehicle class), not from this mod; this mod only reads the camera position. To double-check,
  set `Enabled = 0` and enter the same car.
- If Living_City is updated, rebuild: extract the new `speedometer.lua` from `living_city.dat`
  (text between `export = {}` and `_compilerVersion = 4`) and run `_dev/build_speedo.py` on it.
  The script fails loudly if a patch anchor is no longer found.

## Undo

Disable the mod in Nexus Tools, or delete this folder.
