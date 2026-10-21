"""Builds the living_city_interior_cam camera database.

Usage: python3 build_interior_cam.py <fcb.py dir> <base cameracontext.lib> <output.lib>

Base is Living_City Graphic_Tweaks' cameracontext.lib (= Living_City's + its FOV tweak).
Only in-car first person cameras ("Vehicles.Driving.Interior*") are changed, in place:
values keep their size, so nothing else in the file moves.
"""
import struct
import sys
from collections import defaultdict

sys.path.insert(0, sys.argv[1])
import fcb  # noqa: E402

PITCH_MIN = -35.0
# v0.8: up limit 35 -> 15. Looking up, the roof gets cut by the renderer's near clip (not settable:
# not in cameracontext.lib, render config NearPassZMin/Max had no effect). Measured (camlog, user
# paused where the cut starts): Agile_04 19.75 and 16.0 deg up; Offroad_04 pickup fine at 35.
# Assumes fRotationPitchMax is the up side (as fRotationYawMax is left); check with the log.
PITCH_MAX = 15.0
YAW_LIMIT = 60.0  # symmetric left/right limit (was -110 / 60, right side over-extended)
# mouse input: Living_City's in-car cameras cap turning at 2 x (YawSpeed + YawExtraSpeed) = 140 deg/s
# (measured 3.11 deg/tick at 45 fps; on foot 120 + 120 -> 480 deg/s measured). Values from the
# PCGamingWiki "camera speed limit remover"; damping from the on-foot camera (Avatar.Default.Normal).
# auto recentering: every car camera has fFollowYawDeadAngle = 0 and field 00d01c62 = 0, on-foot
# cameras (which don't recenter) 100-120 and 30. Unconfirmed meaning: angle within which the camera
# doesn't follow (recenter). Set above the rotation limits.
# v0.5/v0.6 (dead angles 180 / 90) stopped recentering but also stopped the camera turning with the
# car while driving (it kept its world direction), and the ".42 m/s" entries were not used up to
# 96 km/h. v0.7 keeps Living_City's dead angles (0) and tests fFollowMinSpeedAfterInput instead
# (7.5 on every chase camera, 0 in-car): no following after input until the car is moving.
# v0.8: looking up, the roof is cut by the renderer's near clip plane (cut line slides with the
# camera, roof present from outside). The near distance isn't in cameracontext.lib (Lens block =
# DOF fields only) nor in Nexus Tools' Lua API, so the camera is moved down, away from the roof.
CAMERA_DROP = 0.0  # metres (v0.8 tried 0.10; rejected by user: eye level must not change)
FOLLOW = {
    'fFollowMinSpeedAfterInput': 7.5,
}
INPUT = {
    'fInputYawSpeed': 120.0,
    'fInputPitchSpeed': 120.0,
    'fInputYawExtraSpeed': 120000.0,
    'fInputYawExtraSpeedAngleThreshold': 0.0,
    'fInputDampUp': 30.0,  # v0.4 6.5 (on-foot value) still lagged ~6 ticks
    'fInputDampDown': 30.0,
}
SPEED_SUFFIX = '.42 m/s'
NAME_FIELD = 0x9d8873f8  # string name of a camera entry

data = bytearray(open(sys.argv[2], 'rb').read())
root = fcb.parse(bytes(data))['root']

# every data offset used by any field, to refuse editing shared values
users = defaultdict(int)


def count_users(o):
    for _, _, off in o.fields:
        users[off] += 1
    for c in o.children:
        count_users(c)


count_users(root)


def name_of(cam):
    for h, b, _ in cam.fields:
        if h == NAME_FIELD:
            return b[:-1].decode('latin1')


def block(cam, block_name):
    return next(c for c in cam.children if c.hash == fcb.crc(block_name))


def field(blk, field_name):
    return next((b, off) for h, b, off in blk.fields if h == fcb.crc(field_name))


def root_field(cam, field_name):
    return next((b, off) for h, b, off in cam.fields if h == fcb.crc(field_name))


def field_any(blk, key):
    h = key if isinstance(key, int) else fcb.crc(key)
    return next((b, off) for fh, b, off in blk.fields if fh == h)


def get_f(cam, block_name, field_name):
    b, _ = field(block(cam, block_name), field_name)
    return struct.unpack('<f', b)[0]


edits = []


def set_f(cam, block_name, field_name, value):
    b, off = field(block(cam, block_name), field_name)
    assert len(b) == 4, (name_of(cam), field_name)
    assert users[off] == 1, ('shared value', name_of(cam), field_name)
    old = struct.unpack('<f', b)[0]
    if old != value:
        struct.pack_into('<f', data, off, value)
        edits.append((name_of(cam), field_name, old, value))


def set_vec(cam, b_off, value):
    b, off = b_off
    assert len(b) == 12, name_of(cam)
    assert users[off] == 1, ('shared value', name_of(cam))
    old = struct.unpack('<3f', b)
    if old != tuple(value):
        struct.pack_into('<3f', data, off, *value)
        edits.append((name_of(cam), 'vec@%d' % off, old, tuple(value)))


cams = {name_of(c): c for c in root.children}
interior = sorted(n for n in cams if n and n.startswith('Vehicles.Driving.Interior'))

for n in interior:
    cam = cams[n]
    # 1. allow looking up and down
    set_f(cam, 'Rotation', 'fRotationPitchMin', PITCH_MIN)
    set_f(cam, 'Rotation', 'fRotationPitchMax', PITCH_MAX)
    # 2. same symmetric left/right range standing and at speed
    set_f(cam, 'Rotation', 'fRotationYawMin', -YAW_LIMIT)
    set_f(cam, 'Rotation', 'fRotationYawMax', YAW_LIMIT)
    # 6. recentering only once the car moves after free look (v0.7 test)
    for k, v in FOLLOW.items():
        b, off = field_any(block(cam, 'Follow'), k)
        assert len(b) == 4 and users[off] == 1, (n, k)
        old = struct.unpack('<f', b)[0]
        if old != v:
            struct.pack_into('<f', data, off, v)
            edits.append((n, k if isinstance(k, str) else '%08x' % k, old, v))
    # 5. mouse input speed / damping
    for k, v in INPUT.items():
        set_f(cam, 'Input', k, v)
    # 3. rotate in place: move the ideal offset (camera above its rotation point) into the pivot offset
    ideals = [root_field(cam, k) for k in ('vectorIdealMin', 'vectorIdealMid', 'vectorIdealMax')]
    ideal = struct.unpack('<3f', ideals[0][0])
    assert all(struct.unpack('<3f', b) == ideal for b, _ in ideals), n
    # 4. same for the per-direction offsets of the Ideal block: the camera sat on a ~1.02 m arm
    #    above its rotation point (measured with camlog.lua: pitch arm (0, -0.163, 1.009) vs
    #    vectorOffsetMinFront (0, -0.16, 1.025)), and Left/Right shifted it by +-0.12 m.
    offsets = [field(block(cam, 'Ideal'), 'vectorOffset' + a + b)
               for b in ('Front', 'Back', 'Left', 'Right') for a in ('Min', 'Mid', 'Max')]
    front = struct.unpack('<3f', field(block(cam, 'Ideal'), 'vectorOffsetMinFront')[0])
    pivot = field(block(cam, 'Pivot'), 'vectorPivotOffset')
    pv = struct.unpack('<3f', pivot[0])
    drop = (0.0, 0.0, -CAMERA_DROP)
    set_vec(cam, pivot, tuple(pv[i] + ideal[i] + front[i] + drop[i] for i in range(3)))
    for b_off in ideals + offsets:
        set_vec(cam, b_off, (0.0, 0.0, 0.0))

# v0.11 test: on bikes the rider isn't drawn in this view (screenshot: camera behind the bike, no
# rider). fCollisionVisibleRadius: car interior -1 (body visible), bike 3rd person 0.1 (visible),
# bike interior 10 (not visible). Use the car value on the bike interior cameras.
for n in ('Vehicles.Driving.Interior.New Interior.bike', 'Vehicles.Driving.Interior.New Interior.bike.42 m/s'):
    b, off = root_field(cams[n], 'fCollisionVisibleRadius')
    assert len(b) == 4 and users[off] == 1, n
    old = struct.unpack('<f', b)[0]
    struct.pack_into('<f', data, off, -1.0)
    edits.append((n, 'fCollisionVisibleRadius', old, -1.0))

# v0.18: bike rider view sits inside the head (screenshot: inside of the mask/mouth at the top of the
# view). User: too far back only; the height is fine (do not change it). Move it forward.
# v0.19: at the bike's top speed (80 mph / 128 km/h logged) the rider tucks forward and the camera sees
# the sunglasses; user likes the cap brim showing. Another 0.04 m forward.
# v0.19 tested (0.12): too far, the cap edges get clipped and the brim disappears. Back to 0.08.
# v0.22: face shows a little in slow turns (~15 mph, tuck blend only ~9%). 0.08 -> 0.10 at low speed
# (0.12 clipped the cap edges). The tuck camera stays at the same absolute spot (BIKE_TUCK_SHIFT -0.02 y).
# v0.23: v0.22 "much better but still needs to be pushed forward slightly": 0.10 -> 0.11.
BIKE_EYE_SHIFT = (0.0, 0.11, 0.0)  # x right, y forward, z up (metres)
for n in ('Vehicles.Driving.Interior.New Interior.bike', 'Vehicles.Driving.Interior.New Interior.bike.42 m/s'):
    b, off = field(block(cams[n], 'Pivot'), 'vectorPivotOffset')
    cur = struct.unpack_from('<3f', data, off)
    set_vec(cams[n], (b, off), tuple(cur[i] + BIKE_EYE_SHIFT[i] for i in range(3)))

# v0.20: the rider tucks forward/down with speed, so a fixed camera ends up in his head (sunglasses at
# 80 mph). build_vehicle_preset.py makes the bike rider mode blend, with speed (3 -> 42 m/s), to the
# ".42 m/s" camera. Put that one where the tucked head is: the view then follows the tuck. 80 mph
# (35.6 m/s, the logged top speed) is 84% of the blend. Estimate, to tune from the user's look.
# v0.21: v0.20 tested "much better", but at 80 mph the cap brim sits right above the camera and gets cut
# by the near clip (not settable). Lower the tuck camera to move away from the brim.
BIKE_TUCK_SHIFT = (0.0, 0.03, -0.09)  # extra, at full blend (42 m/s); keeps the tuck spot fixed
n = 'Vehicles.Driving.Interior.New Interior.bike.42 m/s'
b, off = field(block(cams[n], 'Pivot'), 'vectorPivotOffset')
cur = struct.unpack_from('<3f', data, off)
set_vec(cams[n], (b, off), tuple(cur[i] + BIKE_TUCK_SHIFT[i] for i in range(3)))

# v0.12-v0.16 (bike rider camera: Pivot 845e26fa flag, pivot type 5, Follow/Alignment/FOV/root/Pivot
# copied from Bumper.Bike) did not change the drift and were removed. The drift was the bike
# VehiculeInterior mode blending to its 42 m/s variant, a 3rd person camera: fixed in
# build_vehicle_preset.py. See README history.

open(sys.argv[3], 'wb').write(data)
for e in edits:
    print('%-58s %-18s %s -> %s' % e)
print('cameras:', len(interior), 'edits:', len(edits))
