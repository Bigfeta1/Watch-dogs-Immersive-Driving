# Living_City Interior Camera Tweaks

Local add-on for Living_City 2.9.5 (started 2026-10-12). Changes the first person in-car cameras
(the "inside the car" driving view) so you can look around more freely. Separate from
`living_city_speedo_fix` so it can be disabled on its own.

## What it changes (v0.9)

All 19 camera entries named `Vehicles.Driving.Interior*` in `cameracontext.lib`:

| Field | Before (Living_City) | Now |
|---|---|---|
| `Rotation/fRotationPitchMin`, `fRotationPitchMax` | 0 / 0 (no up/down) | -35 / 15 (v0.1-v0.7: -35 / 35) |
| `Rotation/fRotationYawMin`, `fRotationYawMax` | -110 / 60 standing, -20 / 5 at speed (`.42 m/s` entries) | -60 / 60 everywhere |
| root `vectorIdealMin/Mid/Max` | (0, 0, 0.36..0.67) | (0, 0, 0) |
| `Ideal/vectorOffset{Min,Mid,Max}{Front,Back,Left,Right}` | e.g. Front (0, -0.16, 1.025), Left/Right x = -/+0.12 | (0, 0, 0) |
| `Input/fInputYawSpeed`, `fInputPitchSpeed` | 70 / 70 | 120 / 120 |
| `Input/fInputYawExtraSpeed`, `fInputYawExtraSpeedAngleThreshold` | 0 / 60 | 120000 / 0 |
| `Input/fInputDampUp`, `fInputDampDown` | 4.5 / 6.5 | 30 / 30 (v0.4: 6.5 / 7.5) |
| `Follow/fFollowMinSpeedAfterInput` | 0 | 7.5 (value used by every chase camera) |
| `Pivot/vectorPivotOffset` | e.g. (0.1, 0.12, -0.72) | + root ideal + Ideal `vectorOffsetMinFront`, e.g. (0.1, -0.04, 0.685) |

Nothing else in the file is touched (verified: same size, 495 fields differ, all in the 19 in-car cameras).

History:
- v0.1: pitch ±35, at-speed yaw = standing yaw. Tested: up/down works; right side over-extended
  (the 110° side); camera moved back when looking up / forward when looking down.
- v0.2: symmetric yaw ±60; ideal offset folded into the pivot. The camera sat 0.36–0.67 m straight
  above its rotation point, so pitching swung it back/forward (yaw around a vertical axis didn't).

- v0.2 tested: camera ended up behind the character's head when looking up. Measured with
  `camlog.lua` (Muscle_Retro_02, parked): pitch moved the camera on a 1.02 m circle; fitted arm
  (0, -0.163, 1.009) = `Ideal/vectorOffsetMinFront` (0, -0.16, 1.025); predicted vs logged position at
  -35° pitch within 1 cm. Left/Right offsets (x -/+0.12) slid the camera ~0.25 m on yaw.
  Pitch -35 = looking down (camera moved forward), +35 = up.
- v0.3: those 12 direction offsets folded into the pivot (Min Front) and zeroed, so the camera
  should rotate in place. Same values in all 19 in-car cameras.
- v0.3 tested (Agile_04, parked): camera stayed at (-0.274, -0.346, 1.007) within ~1 mm through yaw
  ±60 and pitch ±35. Fixed. Yaw sign: +yaw = looking left (`fRotationYawMax` is the left limit,
  `fRotationYawMin` the right). Living_City's original: left 60 / right 110 standing, left 5 / right 20 at speed.
- "Steppy" movement measured per tick (45 ticks/s = Nexus Tools fpsLimit 45): no stutter, but turning
  ramps up over ~7 ticks then is capped at 3.11 deg/tick = 140 deg/s whatever the mouse does.
  Rule that fits both cameras: cap = 2 x (fInputYawSpeed + fInputYawExtraSpeed): in-car 2 x (70 + 0)
  = 140 deg/s; on foot (Avatar.Default.Normal) 2 x (120 + 120) = 480 deg/s, measured 10.67 deg/tick.
  fRotationLag was not the cause.
- Snap-back measured: after ~1-2 s without input the camera returns to centre with a fixed curve
  (4.44, 8.23, 10.52, 10.91, 9.59, 7.25 ... deg/tick); mouse input interrupts it.
- v0.4: input values from the PCGamingWiki camera speed limit remover (120 / 120 / 120000 / 0) and
  the on-foot damping 6.5 / 7.5.
- v0.4 tested: cap rose to 5.82 deg/tick (~260 deg/s), so the "2 x (speed + extra)" rule was wrong
  (fInputYawExtraSpeed 120000 had no visible effect). Turning still ramps up over ~6 ticks (~0.15 s,
  about 1/6.5 s). Yaw recenters after ~1-2 s idle; pitch springs back within ~0.2 s.
- Follow fields that split cameras exactly: all 144 car cameras (3rd person + interior) have
  `fFollowYawDeadAngle` = 0 and unnamed `00d01c62` = 0; on-foot cameras (no recentering) 100-120 / 30.
- v0.5: those two set to 180 / 90 (above the rotation limits) to stop recentering; damping 30 / 30
  to test whether damping is the ~0.15 s lag.
- v0.5 tested: no recentering at all (held 6.8 s at +60, 6.3 s at -60, ~2 s at +-35 pitch), so
  `fFollowYawDeadAngle` = yaw recentering and `00d01c62` = pitch recentering (confirmed). Lag NOT
  fixed: on foot a turn reaches 90% of its peak speed in 2-4 ticks, in-car 6-22 ticks with the first
  ticks at 1-5% of peak. Damping 30 did not explain it; cause still unknown.
- User's target behaviour: parked = free look that stays; when driving starts, recenter once; while
  driving, free look that recenters after ~5 s idle; back to free look when stopped.
- v0.6 test: recentering off only on standing entries, on for `.42 m/s` entries (believed to be the
  at-speed variants). Logger gained `speed_kmh` (GetVehicleSpeed, as Living_City's speedometer).
- v0.6 tested (drove up to 96 km/h): no recentering while driving, so the `.42 m/s` entries were not
  used. Side effect found: with the dead angles at 180 the camera kept its WORLD direction while the
  car turned (312.2-315.3 s: car yaw 56 -> 0 deg, camera world yaw 23-26 deg). Follow = the camera
  turning with the car, not just snap-back; it must stay on while driving.
- v0.7 test: dead angles back to Living_City's 0; `fFollowMinSpeedAfterInput` 0 -> 7.5 (all chase
  cameras use 7.5). Expected if the name is right: no follow after mouse input until the car moves.
- v0.7 tested: user confirmed the recentering behaviour works. New issue: looking up, the top of the
  roof disappears. User observed the cut line slides as the camera moves (roof exists from outside),
  i.e. the renderer's near clip plane. Checked: the camera does not move on pitch (v0.3 log); the
  `Lens` block is depth of field only (names found by CRC: `bLensDOFEnabled`, `bNearDOFEnabled`,
  `bFarDOFEnabled`, `fLensFocusLag`, `fLensFocusLagNear`, `fLensFocusLagFar`, `fFocalLength`,
  `fFStop`, `vec2FocusRange`); Nexus Tools' Lua camera API has only FOV/position/freecam/lock.
- v0.8 test: camera lowered `CAMERA_DROP` = 0.10 m (pivot z) in all 19 in-car cameras. Rejected
  before testing (user: eye level must not change); reverted, output byte-identical to v0.7.
- Near clip search (2026-10-20): unpacked common/patch/patch1 archives (`_dev/archive_tools/`).
  No camera near-plane field found by CRC name search across all 1619 nbCF databases. The only
  near setting found: engine profile `<Profile NearPassZMin="0.01" NearPassZMax="5">`, also
  editable live in Nexus Tools (render config window, "Rendering Features" tab, "Near Pass Range").
  Effect on the roof cut not yet tested. Fallback agreed with user: limit pitch-up (option 1).
  User could not find those sliders in Nexus Tools. cout.log shows the game loads
  `engine\settings\DefaultRenderConfig.xml` after FileHookManager scans workspaces; archive entry
  c529df2a (patch) is that file. Test: `workspace/engine/settings/defaultrenderconfig.xml` = patch copy
  with only `NearPassZMin` 0.01 -> 0.001. Delete that file to undo.
  Result: roof cut unchanged, but that run's cout.log has no DefaultRenderConfig.xml line at all
  (previous run logged it twice), so loading was unconfirmed. Next test: ZMin 0.001, ZMax 5 -> 0.3,
  plus marker `DisableRealtrees="1"` (trees vanish = file is loaded).
  Result: trees gone, so the loose `workspace/engine/settings/defaultrenderconfig.xml` override IS
  loaded (even though cout.log doesn't list it). Marker reverted.
  Roof cut unchanged with ZMin 0.001 / ZMax 0.3 -> near pass is not the roof clipping. Override
  removed. No other near clip setting found: going with option 1 (limit pitch up).
- Pitch measurement (camlog, parked, user paused where the cut starts): Offroad_04 pickup held at
  +35 (no cut at the limit); Agile_04 sports car paused at +19.75 (yaw -17) and +16.0 (yaw -25).
- v0.8: `fRotationPitchMax` 35 -> 15 on all 19 in-car cameras (38 bytes differ from v0.7).
  Assumes PitchMax is the up side (YawMax is left); to verify with the next log.
- Bike: user wants rider-eye free look on motorcycles. Only bike-mounted first person view is
  available. Log (Bike_01): camera at (0, 0.66, 1.38) from the bike, yaw/pitch fixed 0.
  `Interior.New Interior.bike` (rider camera, already edited) is never used on bikes.
  `Bumper.Bike` / `Bumper.Bike.02`: input speeds 0, rotation limits 0, mode fields 4 (in-car 3).
- v0.9 test (Bumper.Bike made mouse-rotatable) dropped before testing: user wants the rider's own
  view (body and bike visible), not the bike-mounted one. Reverted (cameracontext == v0.8).
- Found how vehicles get their cameras: `generated/databases/generic/cameravehiclepreset.lib`
  (patch.dat 66e917ec, no mod overrides it). Each `Vehicles.BaseVehiclePreset.*` maps modes
  (VehiculeNormal, VehiculeBumper, VehiculeInterior, ...) to a camera by its hidKey (field aad19ca0);
  a `dd510595/2de0bce2` child holds a speed variant (field a16e4285, threshold 8a791d8c = 42 m/s).
  Cars: VehiculeInterior = `Interior.New Interior.<class>`. All bike presets: VehiculeInterior =
  a third person bike camera, so bikes have no rider view.
- v0.9: `workspace/generated/databases/generic/cameravehiclepreset.lib`, built by
  `_dev/build_vehicle_preset.py` from `_dev/cameravehiclepreset_base_patch.lib`: the 3 bike
  VehiculeInterior camera keys -> `Interior.New Interior.bike` (344d9f00); 12 bytes differ.
  The 42 m/s speed variant is shared with other bike modes and left alone (third person above ~151 km/h).
- v0.9 tested: no rider view. cout.log confirms our cameravehiclepreset.lib was merged, and the
  merged DB has the bike VehiculeInterior = 344d9f00, but the log shows the camera key on a bike
  only cycles bike-mounted (0, 0.7, 1.4) and third person (0, -4, 2.3): the Interior mode is never
  selected on bikes. Key signal is "cameraswitch" (action map common_camera_switch).
- Engine call found in the game's Domino box `domino/system/setinvehiclecamera.lua`:
  `SetInVehicleCamera(playerId, type)`, Normal 0, Classic 1, Bumper 2, Interior 3, Hollywood 4.
- v0.10 test: `workspace/living_city_interior_cam/bike_fp.lua` (luaAutoStart) calls
  SetInVehicleCamera(player, 3) once per bike entry; result in cout.log.
- v0.10 tested: the forced Interior view works on bikes (cout.log "SetInVehicleCamera(Interior): ok").
  User: sees the bike but no rider body; camera lags. Log: camera at (0, -0.01, 1.09) from the bike
  (bike-mounted view is at 1.38), and it slides back with speed (y -1.5 m at 50 km/h, back to 0
  when slowing). Bike vs car interior camera differ only in pivot offset, `Pivot/845e26fa`
  (bool: car 1, bike empty) and `fCollisionVisibleRadius` (bike 10, car -1); Follow/lag fields equal.
- Logger gained head_x/y/z: player "Head" bone via GetEntityBonePosition(entity, bone, axis, 0)
  (signature from the game's domino/system GetPositionBox; bone names seen: Head, neck, LeftHand,
  RightHand), same reference space as the camera, to place the bike camera at eye level.
- Head logging crashed the logger ("arithmetic on a userdata value"): GetEntityBonePosition returns
  userdata. Now guarded; first call's result types go to cout.log ("head bone: ...").
- v0.10 screenshot (riding): camera ~1.5 m behind the bike, rider not drawn at all.
- v0.11 test: `fCollisionVisibleRadius` 10 -> -1 on both bike interior cameras (car interior -1 =
  body visible, bike 3rd person 0.1 = visible, bike interior 10 = not visible). 4 bytes differ vs v0.8.
- v0.11 tested: rider is drawn now (user confirmed). Camera still drops behind when accelerating.
- v0.12 test: `Pivot/845e26fa` (unnamed bool) set to 1 on both bike interior cameras. It is 1 on all
  37 bumper and 17 car interior cameras (locked to the vehicle) and empty on all 120 3rd person
  cameras (trailing) and on the bike interior ones. Empty -> 1 grows the file by 1 byte each
  (512029 bytes); safe because cameracontext.lib has no field data back references and object
  back references are indices. The build asserts every other field is unchanged.
- v0.12 tested: still drifts, more with speed. User test: drift only in the rider view, never in
  the bike-mounted view. Logger crashed again on the head bone maths (GetEntityBonePosition returns
  userdata); the head block is now fully pcall-guarded (dry run with userdata stubs keeps logging).
- 3-way diff (bike-mounted ok / bike rider drifts / car interior ok): rider == car interior except
  the position; bike-mounted has Pivot 490ce11e / 9b8e4f3f = 5, rider and car = 12.
- v0.13 test: bike rider cameras Pivot 490ce11e / 9b8e4f3f 12 -> 5, vectorPivotOffset
  (0, -1.07, 0.23) (origin for 5 derived from Bumper.Bike: offset (0,-0.4,0.52) logged at
  (0,0.66,1.38) -> origin (0,1.06,0.86); keeps the old resting spot (0,-0.01,1.09)).
- v0.13 result: game crashed while loading the world (cout.log ends during load, no error line).
  Reverted the camera file to the v0.12 state (bike pivot type 12, flag 1, visible radius -1);
  logger head guard kept. Pending: confirm the game loads again.
- Still crashed with the v0.12 camera file. Both crash runs end ~0.5 s after the mod's scripts start
  (= logger's first sample). Before the pcall guard, the head-bone error stopped the logger after
  one sample; with the guard it keeps calling GetEntityBonePosition every tick during loading.
  Test: logger off (InteriorCam_Config.Log = 0).
- Logger off -> game loads (user drove; drift still there with the v0.12 file). So the crashes came
  from calling GetEntityBonePosition every tick while loading; head code removed from camlog.lua
  for good (do not call GetEntityBonePosition per tick). The v0.13 crash run also had that logger,
  so the pivot type 5 change was never really tested.
- v0.14 test: v0.13 pivot change re-enabled (type 5, offset (0,-1.07,0.23)), logger on (no head code).
- v0.14 tested (log): at rest exactly the planned spot (0.01, 0.00, 1.09); drift unchanged: steady
  per-speed offset back and up (y -1.44 m at 13.9 m/s, -3.15 m at 22.7 m/s; z 1.09 -> 1.38;
  y ~ -0.0074 v^2 at low speed, -0.0061 v^2 at 22 m/s). Not a catch-up lag: constant at constant speed.
- v0.15 test: Bumper.Bike's whole Follow and Alignment blocks copied onto both bike rider cameras
  (identical field layout; mode enums 3 -> 4, follow params). Rotation kept (mouse look).
  fFollowMinSpeedAfterInput becomes Bumper.Bike's 0 there.
- v0.15 tested (log): drift unchanged (-1.44 m at 13.9 m/s; up to -3.4 m at 24 m/s, z up to 1.6).
  Follow/Alignment ruled out. Also seen: up to 2.5 m sideways while turning.
- v0.16 test: everything else copied from Bumper.Bike onto the bike rider cameras: root fields
  (vec2IdealSpeedRange (-1,0) -> (2,38), fCollisionRadius, fCollisionLagDecompress; not name/ids or
  fCollisionVisibleRadius), FOV block, Ideal, f390740b, Pivot (not position / 845e26fa).
  Rider vs bike-mounted now differ only in Rotation, Input, Lens, position, fFollowMinSpeedAfterInput.
- v0.16 tested (screenshot at 73 mph): still drifts. So not the camera entry.
- Cause found in cameravehiclepreset.lib: each VehiculeInterior mode blends from its camera to a speed
  variant (child dd510595/2de0bce2, camera a16e4285, full at 8a791d8c = 42 m/s) starting at the mode's
  own 8a791d8c = 3 m/s. Cars: variant = another interior camera (invisible). Bikes: variant =
  3rdPerson.42 m/s.bike, so the rider view slid toward the chase camera. Log fits: drift starts
  ~3 m/s; 1.44 m back at 13.9 m/s = (13.9-3)/(42-3) = 28% of the ~5 m chase distance.
- v0.17: bike VehiculeInterior blend start 3 -> 41 m/s (values used only by bike interior modes;
  the shared variant object is not touched). v0.12-v0.16 camera edits removed: cameracontext.lib is
  byte-identical to v0.11 (rider visible).
- v0.17 tested: user "MUCH better", camera stays with the rider. Screenshot: camera inside the head
  (inside of the mask/mouth visible at the top of the view, chin edge ~15 deg above centre).
- v0.18: bike rider camera moved up 0.12 m, forward 0.08 m (`BIKE_EYE_SHIFT`, estimate from the
  screenshot): pivot (0, 0.34, 1.025) -> (0, 0.42, 1.145). 12 bytes differ from v0.11.
- v0.18b: user: height was never an issue, only too far back. Shift is forward only, 0.08 m:
  pivot (0, 0.42, 1.025). Do not change the bike camera height.
- v0.18b tested: user loves it. Camera fixed relative to the bike at all speeds (rider-view log:
  y 0.07-0.09, z 1.08-1.09 from 0 to 128 km/h); the rider animation tucks forward with speed, so the
  cap brim (liked) and at 80 mph the sunglasses (not liked) come into view. Bike top speed in log:
  128 km/h = 35.6 m/s, below the 41 m/s blend start.
- v0.19: another 0.04 m forward: pivot (0, 0.46, 1.025).
- v0.19 tested: 0.12 m forward clips the cap edges and the brim disappears; back to 0.08 m.
- v0.20: view follows the rider's tuck. build_vehicle_preset.py now writes cameravehiclepreset.lib
  expanded (no back references, same size/object count as the copy Nexus Tools builds: 2063389 bytes,
  33438 objects; by content it equals that copy except the intended values). Bike VehiculeInterior:
  blend start back to 3 m/s, speed variant -> "Interior.New Interior.bike.42 m/s" (hidKey dc8bd34e),
  placed at rider position + BIKE_TUCK_SHIFT (0, 0.06, -0.05) (estimate). Bike 3rd person modes keep
  their own variant. Untested.
- Asked: hide only the head on bikes. Searched the game's scripts: only EnableFaceMask/DisableFaceMask
  (Aiden's face mask, Player State Controller) and whole-avatar hiding (fCollisionVisibleRadius); no
  head / cap / glasses toggle found.
- v0.20 tested: "much better"; at 80 mph the cap brim is right above the camera and cut by the near clip.
- v0.21: tuck camera lower: BIKE_TUCK_SHIFT (0, 0.06, -0.09) -> pivot (0, 0.48, 0.935). Parked view unchanged.
- v0.21 tested: straight riding fixed (brim fine). In turns the face (nose under the brim) still shows.
  Camera log by bike roll: the camera is locked to the bike frame (at 35 deg lean it is 0.59 m to the
  side and rolled ~29 deg with the bike), so it is the rider who moves differently in a lean.
  The only blend available follows speed, not lean.
- Speedometer bike dashboard placement turned off for now (living_city_speedo_fix config Bike_Dash = 0).
- Head sampler added to camlog.lua (InteriorCam_Config.HeadLog = 1): head_log.csv, raw world values as
  text, ~2/s from OnUpdate, only after 3 s seated on a bike (never during loading, which is when the
  per-tick calls crashed the game). Dry run: no bone calls while loading/on foot/in a car.
- Head sampler ran without crashing (90 rows), but while moving it puts the head ~0.9-1.0 m behind the
  bike centre at any speed: not usable for placement (lags the bike / other frame). At rest: head bone
  ~0.15 m above the camera, 0.21 m left (foot down).
- v0.22: user "98% done": face shows a little in slow turns (~15 mph). Low-speed camera 0.08 -> 0.10 m
  forward: pivot (0, 0.44, 1.025); tuck camera unchanged at (0, 0.48, 0.935).
- v0.23: v0.22 "much better, still slightly forward": low-speed camera 0.10 -> 0.11 m: pivot (0, 0.45, 1.025); tuck camera unchanged.
- Near clip: Codex found the active first person camera object's near plane = 0.25 m (runtime memory,
  Disrupt_b64.dll). Investigation continues in `Watch_Dogs/CAMERA_NEAR_CLIP_HANDOFF_FOR_CLAUDE.md`
  (research tools in `_dev/nearclip/`, local only).
- `_dev/fcb.py` fixed: an object back reference (0xFE count) is an index into the objects parsed so
  far, not a byte offset (cameracontext.lib never uses one; cameravehiclepreset.lib does).

## Files

| Path | What it is |
|---|---|
| `workspace/generated/databases/generic/cameracontext.lib` | The modified camera database. Nexus Tools merges it as a "workspace" DB source. |
| `workspace/living_city_interior_cam/camlog.lua` | Debug camera logger, auto-started by Nexus Tools (`luaAutoStart` in `modconfig.json`). Samples once per game tick (self-rescheduling `SH_NextTick`; `OnUpdate` alone only ran ~2 Hz) and records the camera position relative to the car (seated) or the player (on foot), x right / y forward / z up, plus camera and reference angles. |
| `InteriorCam_CONFIG.txt` | `InteriorCam_Config.Log = 1` turns the logger on (0 = off). Restart the game after editing. |
| `camera_log.csv` | Logger output, overwritten each game start. |
| `_dev/cameracontext_base_graphic_tweaks.lib` | Base used: Living_City Graphic_Tweaks' copy (= Living_City's + an FOV tweak on 78 entries). |
| `_dev/cameracontext_living_city_2.9.5.lib` | Living_City's own copy, for reference. |
| `_dev/build_interior_cam.py` | Rebuild: `python3 build_interior_cam.py <_dev dir> <base.lib> <output.lib>`. Refuses to edit values shared with other fields. |
| `_dev/fcb.py` | Minimal reader for the `nbCF` binary format. |
| `_dev/names_confirmed.txt`, `names_unconfirmed.txt` | Field names found so far (CRC32 of the name = field hash). |
| `_dev/brute.c`, `brute4.c` | CRC32 name search used to find field names. |

## How the field names were found

Fields are stored as CRC32 hashes of their names. Names came from Nexus Tools' `bin/TroploNexusTools/db_cache.bin`,
four from a PCGamingWiki mod (`fInputYawSpeed`, `fInputPitchSpeed`, `fInputYawExtraSpeed`,
`fInputYawExtraSpeedAngleThreshold`), and a search over `<type prefix><Block><Words>` combinations.
"Confirmed" = clean name, right block, right value size. "Unconfirmed" = plausible match whose
behaviour hasn't been tested (the snap-back candidates `bFollowYaw` / `bFollowPitch`).

## Setup / checking it loads

Nexus Tools Mod Manager: enable, workspaces enabled, priority above `living_city` and
`living_city_graphic_tweaks`. New workspace files may need a manual rescan in Nexus Tools.
In `%APPDATA%\Troplo\Nexus\cout.log` look for
`cameracontext.lib[DB SOURCE] type=workspace mod=living_city_interior_cam`.
The merged result the game uses is `%APPDATA%\Troplo\Nexus\databases\CameraContext.lib`.

## Plan / open items

- LATER (user, 2026-10-12): revisit yaw limits. Now ±60 both ways. Left (driver window side,
  `fRotationYawMax`) may feel tight at 60; options discussed: left 80–90, keep right 60
  (`fRotationYawMin` = -60; Living_City original right was -110 and over-extended).

1. (v0.1) up/down + full left/right at speed. Pitch sign unknown, so the range is symmetric.
2. Smoothness: in-car cameras have `fRotationLag = 0`; the smooth on-foot interior camera has 0.9.
3. Snap-back: test `Follow/bFollowYaw`, `bFollowPitch` (both 1 in-car), `fFollowMinSpeedAfterInput`.

## Undo

Disable the mod in Nexus Tools, or delete this folder.
