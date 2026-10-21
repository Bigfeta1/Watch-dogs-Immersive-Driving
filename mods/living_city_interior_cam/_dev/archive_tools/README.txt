Watch_Dogs .fat/.dat reader (written 2026-10-20 to search game data for the near clip setting).
.fat: "FAT3", version 8, u32 count at 0x0c, 16-byte entries:
  w0 = name hash (not plain CRC32/CRC64 of the path), w1 = uncompressed size << 3 | flags,
  w2 = (offset & 7) << 29 | stored size, w3 = offset >> 3.
Stored data starting 0F F5 12 EE = chunked XMem LZX: 0x28-byte header, then per 32 KB block a
u32 size and frames "FF uu uu cc cc" + LZX data; each frame decodes alone, window bits 15.
Build: gcc -O2 -shared -fPIC -DHAVE_CONFIG_H -I. -I<libmspack>/mspack -o libmemlzx.so memlzx.c <libmspack>/mspack/lzxd.c
  (libmspack 0.11alpha source from cabextract.org.uk). wdfat.py loads libmemlzx.so from its folder.
engine_profile_default_patch.xml = patch.dat entry c529df2a, the default engine <Profile>
  (NearPassZMin="0.01" NearPassZMax="5").
