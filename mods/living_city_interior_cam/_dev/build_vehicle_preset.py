"""Builds the living_city_interior_cam camera vehicle preset database (bike first person).

Usage: python3 build_vehicle_preset.py <fcb.py dir> <base cameravehiclepreset.lib> <cameracontext.lib> <output.lib>

Base is the game's own generated/databases/generic/cameravehiclepreset.lib (patch.dat entry 66e917ec;
no mod changes it). Each "Vehicles.BaseVehiclePreset.*" entry maps camera modes to cameras by the
camera's hidKey (field aad19ca0). A mode can also blend, with speed, from its camera to a speed variant
(child dd510595/2de0bce2: camera a16e4285, reached at 8a791d8c = 42 m/s), starting at the mode's own
8a791d8c (3 m/s).

Bike presets: VehiculeInterior (player first person) maps to a 3rd person bike camera and its speed
variant to the 3rd person 42 m/s bike camera. Changes, bike VehiculeInterior modes only:
  - camera -> Living_City's "Vehicles.Driving.Interior.New Interior.bike" (rider view)
  - speed variant -> "Vehicles.Driving.Interior.New Interior.bike.42 m/s", which build_interior_cam.py
    places where the rider's head goes when he tucks at speed, so the view follows the tuck.
The speed variant object is shared with the bikes' 3rd person modes, so the file is written expanded
(every shared object written out in full, no back references), like the database Nexus Tools builds
for the game, and only the copies under the bike VehiculeInterior modes are changed.
"""
import struct
import sys

sys.path.insert(0, sys.argv[1])
import fcb  # noqa: E402

NAME_FIELD = 0x9d8873f8  # string name of an entry
CAMERA_FIELD = 0xaad19ca0  # camera hidKey of a mode
VARIANT_CAMERA_FIELD = 0xa16e4285  # camera hidKey of a speed variant
SPEED_FIELD = 0x8a791d8c  # mode: blend start speed; variant: full blend speed (m/s)
RIDER_CAMERA = 'Vehicles.Driving.Interior.New Interior.bike'
RIDER_TUCK_CAMERA = 'Vehicles.Driving.Interior.New Interior.bike.42 m/s'
VEHICULE_INTERIOR = fcb.crc('VehiculeInterior')

base = open(sys.argv[2], 'rb').read()
root = fcb.parse(base)['root']


def name_of(o):
    for h, b, _ in o.fields:
        if h == NAME_FIELD:
            return b[:-1].decode('latin1')


keys = {}
for cam in fcb.parse(open(sys.argv[3], 'rb').read())['root'].children:
    keys[name_of(cam)] = next(b for h, b, _ in cam.fields if h == fcb.crc('hidKey'))
rider_key, tuck_key = keys[RIDER_CAMERA], keys[RIDER_TUCK_CAMERA]


def count(n):
    return bytes([n]) if n < 0xFE else b'\xff' + struct.pack('<I', n)


edits = []
written = [0]


def write(o, out, ctx):
    """ctx: None, 'vi' (a bike VehiculeInterior mode) or 'vi_child' (anything below one)."""
    written[0] += 1
    out += count(len(o.children)) + struct.pack('<I', o.hash) + count(len(o.fields))
    for h, b, _ in o.fields:
        new = b
        if ctx == 'vi' and h == CAMERA_FIELD:
            new = rider_key
        elif ctx == 'vi_child' and h == VARIANT_CAMERA_FIELD:
            new = tuck_key
        if new != b:
            edits.append((ctx, '%08x' % h, b.hex(), new.hex()))
        out += struct.pack('<I', h) + count(len(new)) + new
    for c in o.children:
        child_ctx = ctx
        if ctx is None and o in presets_bike and c.hash == VEHICULE_INTERIOR:
            child_ctx = 'vi'
        elif ctx in ('vi', 'vi_child'):
            child_ctx = 'vi_child'
        write(c, out, child_ctx)


presets_bike = [p for p in root.children if name_of(p).startswith('Vehicles.BaseVehiclePreset.Bike')]
body = bytearray()
write(root, body, None)
n_obj = written[0]
version, flags = struct.unpack_from('<HH', base, 4)
data = b'nbCF' + struct.pack('<HHII', version, flags, n_obj, n_obj - 1) + bytes(body)
open(sys.argv[4], 'wb').write(data)

# check: the output reads back as the base with only the intended values changed
out_root = fcb.parse(data)['root']
changed = []


def compare(a, b, path):
    assert a.hash == b.hash and len(a.fields) == len(b.fields) and len(a.children) == len(b.children), path
    for (h1, v1, _), (h2, v2, _) in zip(a.fields, b.fields):
        assert h1 == h2, path
        if v1 != v2:
            changed.append((path, '%08x' % h1, v1.hex(), v2.hex()))
    for c1, c2 in zip(a.children, b.children):
        compare(c1, c2, path + '/%08x' % c1.hash)


compare(root, out_root, '')
assert all(h in ('%08x' % CAMERA_FIELD, '%08x' % VARIANT_CAMERA_FIELD) for _, h, _, _ in changed)
for path, h, old, new in changed:
    print('%s %s %s -> %s' % (path.split('/')[1] if path else '', h, old, new))
print('bike presets:', len(presets_bike), 'values changed:', len(changed), 'objects:', n_obj, 'size:', len(data))
