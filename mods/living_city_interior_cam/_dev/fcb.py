"""Minimal reader for Dunia/Disrupt 'nbCF' binary object files (version 3)."""
import struct
import zlib


class Obj:
    def __init__(self, offset, hash_):
        self.offset = offset
        self.hash = hash_
        self.fields = []  # (hash, data, data_offset)
        self.children = []


def read_count(d, p):
    v = d[p]
    if v < 0xFE:
        return v, False, p + 1
    n = struct.unpack_from('<I', d, p + 1)[0]
    return n, v == 0xFE, p + 5


def parse(d):
    assert d[:4] == b'nbCF', d[:4]
    version, flags, n_obj, n_val = struct.unpack_from('<HHII', d, 4)
    p = 16
    by_offset = {}
    objects = []

    def read_obj(p):
        start = p
        n_child, is_off, p = read_count(d, p)
        if is_off:
            # back reference: index into the objects parsed so far
            return objects[n_child], p
        h = struct.unpack_from('<I', d, p)[0]
        p += 4
        o = Obj(start, h)
        by_offset[start] = o
        objects.append(o)
        n_fields, f_off, p = read_count(d, p)
        if f_off:
            ref = by_offset_fields[p - 5 - n_fields] if False else None
            raise ValueError('field list offset at %d' % start)
        for _ in range(n_fields):
            fh = struct.unpack_from('<I', d, p)[0]
            p += 4
            size_pos = p
            size, s_off, p = read_count(d, p)
            if s_off:
                ref = size_pos - size
                rsize, _, rp = read_count(d, ref)
                o.fields.append((fh, d[rp:rp + rsize], rp))
            else:
                o.fields.append((fh, d[p:p + size], p))
                p += size
        for _ in range(n_child):
            c, p = read_obj(p)
            o.children.append(c)
        return o, p

    by_offset_fields = {}
    root, end = read_obj(p)
    return dict(version=version, flags=flags, n_obj=n_obj, n_val=n_val, root=root, end=end, size=len(d))


def crc(name):
    return zlib.crc32(name.encode()) & 0xffffffff
