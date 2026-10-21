"""Watch_Dogs .fat/.dat reader (FAT3 v8): entries 16 bytes, LZX (XMem) chunked containers."""
import os, struct, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))

def entries(fat):
    d = open(fat, 'rb').read()
    n = struct.unpack_from('<I', d, 12)[0]
    for i in range(n):
        h, w1, w2, w3 = struct.unpack_from('<4I', d, 16 + i * 16)
        yield dict(hash=h, usize=w1 >> 3, flags=w1 & 7, size=w2 & 0x1fffffff, off=(w3 << 3) | (w2 >> 29))

import ctypes
_lib = ctypes.CDLL(os.path.join(HERE, 'libmemlzx.so'))

def unlzx(payload, ulen, wbits=15):
    out = ctypes.create_string_buffer(ulen)
    r = _lib.lzx_frame(payload, ctypes.c_long(len(payload)), out, ctypes.c_long(ulen), wbits)
    if r != ulen: raise ValueError('lzx err %d' % r)
    return out.raw

def frames(b):
    """yield (uncompressed, payload) for each XMem frame, scanning past block headers / padding."""
    p = 0x28
    while p < len(b):
        q = b.find(b'\xff', p)
        if q < 0: return
        if q + 5 > len(b): return
        u, c = struct.unpack_from('>HH', b, q + 1)
        if 0 < u <= 0x8000 and 0 < c <= 0x8000 and q + 5 + c <= len(b) and q - p <= 16:
            yield u, b[q + 5:q + 5 + c]
            p = q + 5 + c
        else:
            p = q + 1

def read(dat, e):
    with open(dat, 'rb') as f:
        f.seek(e['off']); b = f.read(e['size'])
    if b[:4] != b'\x0f\xf5\x12\xee':
        return b
    out = b''.join(unlzx(pl, u) for u, pl in frames(b))
    if len(out) != e['usize']: raise ValueError('size %d != %d' % (len(out), e['usize']))
    return out
