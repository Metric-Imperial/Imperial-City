"""Write the flat albedo textures as DXT1 DDS with a full mip chain.

Sollumz embeds textures as D3DFMT_DXT1 and only accepts DDS, but there is no
DDS encoder on this machine. A DXT1 block is trivial when the block is a single
colour: both endpoints are that colour and every 2-bit index is 0. Per-block
jitter gives the surface some variation without needing a real encoder.
"""
import os, struct, random

OUT = r"E:\FiveM - Custom Recipe\_work\smelter\textures"
SIZE = 128
COLOURS = {
    # Aged bronze, not brass. 198,150,58 rendered as near-primary yellow under
    # GTA's sun -- flat albedo has no shading to knock it back, so it needs to
    # start darker and less saturated than it looks correct on screen.
    "imperial_smelter_brass": (150, 112, 52),
    "imperial_smelter_red":   (158, 42, 38),
    "imperial_smelter_fire":  (255, 168, 46),
    "imperial_smelter_iron":  (72, 74, 80),
    # Flat normal: 128,128,255 means "surface is exactly as modelled".
    "imperial_smelter_flat_n": (128, 128, 255),
}

def rgb565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)

def header(w, h, mips):
    pf = struct.pack("<8I", 32, 0x4, 0x31545844, 0, 0, 0, 0, 0)  # DDPF_FOURCC 'DXT1'
    return (b"DDS " + struct.pack("<7I", 124, 0x000A1007, h, w,
                                  max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 8, 0, mips)
            + b"\x00" * 44 + pf + struct.pack("<5I", 0x401008, 0, 0, 0, 0))

def level_bytes(w, h, base, rng):
    out = bytearray()
    for _ in range(max(1, (h + 3) // 4)):
        for _ in range(max(1, (w + 3) // 4)):
            n = rng.randint(-10, 10)
            c = rgb565(*[max(0, min(255, v + n)) for v in base])
            out += struct.pack("<HHI", c, c, 0)   # both endpoints equal, all idx 0
    return out

os.makedirs(OUT, exist_ok=True)
for name, base in COLOURS.items():
    rng = random.Random(1337)
    w = h = SIZE
    mips, body = 0, bytearray()
    while w >= 1 and h >= 1:
        body += level_bytes(w, h, base, rng)
        mips += 1
        if w == 1 and h == 1:
            break
        w, h = max(1, w // 2), max(1, h // 2)
    path = os.path.join(OUT, name + ".dds")
    with open(path, "wb") as f:
        f.write(header(SIZE, SIZE, mips))
        f.write(bytes(body))
    print("wrote %s  %dx%d  mips=%d  %d bytes" % (name + ".dds", SIZE, SIZE, mips,
                                                  os.path.getsize(path)))
