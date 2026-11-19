"""Build Death Timer's four downed-NPC wisp meshes and their colour palettes from vanilla's Soul Cairn wisp.

    python tools/make_wisps.py <extracted vanilla folder> [--dump]

<extracted vanilla folder> holds, at their Data-relative paths (extract them from the vanilla BSAs):
    meshes\\actors\\dlc01\\soulwisp\\character assets\\dlcsoulcairnwisp.nif   (Skyrim - Meshes0.bsa)
    textures\\effects\\gradients\\gradwhitchlight.dds                          (Skyrim - Textures5.bsa)

Writes into mod/:
    meshes\\DeathTimer\\Wisp<Colour>.nif                       one per state
    textures\\effects\\gradients\\DeathTimer\\GradWisp<Colour>.dds  the recoloured palette each mesh points to

The vanilla wisp gets its colour from a greyscale "palette" gradient (GradWhitchlight) plus the emissive colours of
its shaders; both are replaced per colour. Everything else (shapes, animation, size) stays vanilla. The mesh has no
collision object, so arrows and the crosshair pass through it. Needs Pillow and texconv
(C:\\Modding\\SSEEdit 4.1.5f\\Edit Scripts\\Texconvx64.exe).
"""

import os
import struct
import subprocess
import sys
import tempfile

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(REPO, 'mod')
TEXCONV = r'C:\Modding\SSEEdit 4.1.5f\Edit Scripts\Texconvx64.exe'
SRC_NIF = r'meshes\actors\dlc01\soulwisp\character assets\dlcsoulcairnwisp.nif'
SRC_PAL = r'textures\effects\gradients\gradwhitchlight.dds'
OLD_PAL = r'textures\effects\gradients\GradWhitchlight.dds'

# name: (palette ramp dark -> bright, emissive rgb 0-1). Decided with the user 2026-11-19 (SKY-288).
COLOURS = {
    'Blue':   ('06121e,1c4670,5a9ad8,b4dcff,f2faff', (0.55, 0.78, 1.0)),   # knocked out
    'Yellow': ('1a1a00,6a6a00,d8d000,fff860,ffffe0', (1.0, 1.0, 0.35)),    # dying, plenty of time
    'Orange': ('200c00,702800,dc5c00,ff9a30,fff0dc', (1.0, 0.5, 0.1)),     # dying, half gone
    'Red':    ('200000,6e0000,cc1010,ff4a3c,ffe0dc', (1.0, 0.12, 0.08)),   # dying, last 20%
}


# --- NIF 20.2.0.7 (Skyrim SE, stream 100) ---

class Nif:
    def __init__(self, data):
        self.b = bytearray(data)
        b = self.b
        p = b.index(b'\n') + 1
        version, = struct.unpack_from('<I', b, p); p += 4
        p += 1
        p += 4  # user version
        nblocks, = struct.unpack_from('<I', b, p); p += 4
        bsver, = struct.unpack_from('<I', b, p); p += 4
        if version != 0x14020007 or bsver != 100:
            raise SystemExit(f'not a Skyrim SE nif (version {version:#x}, bs {bsver})')
        for _ in range(3):
            p += 1 + b[p]
        ntypes, = struct.unpack_from('<H', b, p); p += 2
        names = []
        for _ in range(ntypes):
            n, = struct.unpack_from('<I', b, p); names.append(b[p + 4:p + 4 + n].decode()); p += 4 + n
        idx = struct.unpack_from(f'<{nblocks}H', b, p); p += 2 * nblocks
        self.types = [names[i & 0x7FFF] for i in idx]
        self.sizes_at = p
        self.sizes = list(struct.unpack_from(f'<{nblocks}I', b, p)); p += 4 * nblocks
        nstr, = struct.unpack_from('<I', b, p); p += 8
        self.strings = []
        for _ in range(nstr):
            n, = struct.unpack_from('<I', b, p); self.strings.append(b[p + 4:p + 4 + n].decode()); p += 4 + n
        ngroups, = struct.unpack_from('<I', b, p); p += 4 + 4 * ngroups
        self.data_at = p

    def starts(self):
        out, o = [], self.data_at
        for s in self.sizes:
            out.append(o); o += s
        return out

    def name(self, i):
        o = self.starts()[i]
        if self.types[i] == 'BSLightingShaderProperty':
            o += 4  # shader type comes first
        si, = struct.unpack_from('<i', self.b, o)
        return self.strings[si] if 0 <= si < len(self.strings) else ''

    def effect_fields(self, i):
        """Offsets inside BSEffectShaderProperty i: emissive colour (4 floats), and the greyscale texture string."""
        b, o = self.b, self.starts()[i]
        o += 4  # name
        n, = struct.unpack_from('<I', b, o); o += 4 + 4 * n  # extra data
        o += 4  # controller
        o += 8  # shader flags 1, 2
        o += 16  # uv offset, uv scale
        n, = struct.unpack_from('<I', b, o); o += 4 + n  # source texture
        o += 4  # clamp mode, lighting influence, env map min lod, unknown byte
        o += 16  # falloff angles and opacities
        emissive = o
        o += 16 + 4 + 4  # emissive colour, emissive multiple, soft falloff depth
        return emissive, o

    def lighting_emissive(self, i):
        b, o = self.b, self.starts()[i]
        o += 4 + 4  # shader type, name
        n, = struct.unpack_from('<I', b, o); o += 4 + 4 * n
        o += 4 + 8 + 16 + 4  # controller, flags, uv offset/scale, texture set ref
        return o

    def replace_string_in_block(self, off, new):
        """Replace the sized string at off (inside a block) and fix that block's size."""
        b = self.b
        n, = struct.unpack_from('<I', b, off)
        nb = new.encode()
        blk = max(i for i, s in enumerate(self.starts()) if s <= off)
        b[off:off + 4 + n] = struct.pack('<I', len(nb)) + nb
        self.sizes[blk] += len(nb) - n
        struct.pack_into(f'<{len(self.sizes)}I', b, self.sizes_at, *self.sizes)


def dump(nif):
    for i, t in enumerate(nif.types):
        if t == 'BSEffectShaderProperty':
            e, g = nif.effect_fields(i)
            col = struct.unpack_from('<4f', nif.b, e)
            mult, = struct.unpack_from('<f', nif.b, e + 16)
            n, = struct.unpack_from('<I', nif.b, g)
            print(f'{i:3} effect   emissive {tuple(round(c, 3) for c in col)} x{mult:.2f}  palette {nif.b[g + 4:g + 4 + n].decode()}')
        elif t == 'BSLightingShaderProperty':
            e = nif.lighting_emissive(i)
            col = struct.unpack_from('<3f', nif.b, e)
            mult, = struct.unpack_from('<f', nif.b, e + 12)
            print(f'{i:3} lighting {nif.name(i)!r} emissive {tuple(round(c, 3) for c in col)} x{mult:.2f}')
        elif t in ('NiNode', 'BSFadeNode', 'BSOrderedNode', 'NiBillboardNode') or 'Collision' in t or t.startswith('bhk'):
            print(f'{i:3} {t} {nif.name(i)!r}')


def ramp(stops, t):
    cols = [tuple(int(s[k:k + 2], 16) for k in (0, 2, 4)) for s in stops.split(',')]
    x = t * (len(cols) - 1)
    k = min(int(x), len(cols) - 2)
    f = x - k
    return tuple(round(cols[k][c] + (cols[k + 1][c] - cols[k][c]) * f) for c in range(3))


def make_palette(src, out_dds, stops):
    im = Image.open(src).convert('RGBA')
    px = im.load()
    lum = lambda p: 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
    vals = [lum(px[x, y]) for x in range(im.width) for y in range(im.height)]
    lo, hi = min(vals), max(vals)
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            t = (lum(p) - lo) / (hi - lo) if hi > lo else 1.0
            px[x, y] = ramp(stops, t) + (p[3],)
    with tempfile.TemporaryDirectory() as tmp:
        png = os.path.join(tmp, os.path.splitext(os.path.basename(out_dds))[0] + '.png')
        im.save(png)
        os.makedirs(os.path.dirname(out_dds), exist_ok=True)
        subprocess.run([TEXCONV, '-nologo', '-y', '-f', 'BC3_UNORM', '-m', '0', '-o', os.path.dirname(out_dds), png],
                       check=True, stdout=subprocess.DEVNULL)
        written = os.path.splitext(out_dds)[0] + '.DDS'  # texconv writes an upper-case extension
        if os.path.exists(written):
            os.replace(written, out_dds)


def main():
    src = sys.argv[1]
    data = open(os.path.join(src, SRC_NIF), 'rb').read()
    if '--dump' in sys.argv:
        dump(Nif(data))
        return
    for colour, (stops, rgb) in COLOURS.items():
        pal_rel = rf'textures\effects\gradients\DeathTimer\GradWisp{colour}.dds'
        make_palette(os.path.join(src, SRC_PAL), os.path.join(MOD, pal_rel), stops)
        nif = Nif(data)
        # back to front, so a string length change never moves a block still to be edited
        for i in reversed(range(len(nif.types))):
            t = nif.types[i]
            if t == 'BSEffectShaderProperty':
                e, g = nif.effect_fields(i)
                struct.pack_into('<3f', nif.b, e, *rgb)
                n, = struct.unpack_from('<I', nif.b, g)
                if nif.b[g + 4:g + 4 + n].decode().lower() == OLD_PAL.lower():
                    nif.replace_string_in_block(g, pal_rel)
            elif t == 'BSLightingShaderProperty':
                struct.pack_into('<3f', nif.b, nif.lighting_emissive(i), *rgb)
        out = os.path.join(MOD, 'meshes', 'DeathTimer', f'Wisp{colour}.nif')
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, 'wb').write(nif.b)
        Nif(bytes(nif.b))  # re-reads cleanly
        print(f'{colour}: {os.path.relpath(out, REPO)}, {pal_rel}')


if __name__ == '__main__':
    main()
