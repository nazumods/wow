#!/usr/bin/env python3
"""Warbandeer Endeavors summary-column art (issue #550).

Generates the crests + header glyph the Summary "Endeavors" column needs. The four crest TGAs are
baked-colour (inline |Tpath:h:w|t markup can't carry a reliable vertex colour — same reason as the
Great Vault pips, make_vault_assets.py — and the gold-ringed variant needs TWO colours anyway). Both
faction crests reuse the existing white silhouettes (icons/{alliance,horde}.tga):

  icons/endeavor-alliance.tga       -- blue Alliance crest (Overview house block)
  icons/endeavor-alliance-sub.tga   -- blue Alliance crest + gold border box (endeavor being fed)
  icons/endeavor-horde.tga          -- red Horde crest (Overview house block)
  icons/endeavor-horde-sub.tga      -- red Horde crest + gold border box (endeavor being fed)
  icons/endeavors.tga               -- white carpenter's-hammer column header (muted-tinted at runtime)

The plain + sub crests keep the crest at the same scale, so only the ring differs. All 64x64, house
TGA format (18-byte header, type-2 uncompressed, 32bpp, descriptor 0x08, BGRA bottom-up), SS 4x.

Requires: pillow, numpy (already used by the sibling generators).

  python Tooling/make_endeavor_assets.py                  # writes all five under Warbandeer/icons
  python Tooling/make_endeavor_assets.py --preview out/   # also dump PNGs for visual verification
"""

import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

SIZE = 64
SS = 4  # supersample factor for smooth edges

ALLIANCE = (102, 187, 255)  # ns.factionIcon Alliance vertexColor {0.400,0.733,1.000} * 255
HORDE = (255, 32, 32)       # ns.factionIcon Horde vertexColor {1.000,0.125,0.125} * 255
GOLD = (230, 195, 92)       # theme gold (#E6C35C) — the subscribed border box

CREST_SCALE = 0.80  # crest fills ~80% of the frame; the margin holds the ring
RING_INSET = 0.03   # border box sits ~3% in from the frame edge
RING_WIDTH = 0.05   # border stroke as a fraction of the frame (~2px at 64)
RING_RADIUS = 0.22  # rounded-corner radius fraction


def _crest_alpha(path: str) -> Image.Image:
    """Load a white house-format crest TGA; return its silhouette as an 'L' mask at SIZE*SS."""
    img = Image.open(path).convert("RGBA")
    a = np.asarray(img).astype(np.float32)[..., 3] / 255.0
    if a.min() > 0.99:  # source carries no real alpha shape -> fall back to luminance
        a = np.asarray(img.convert("L")).astype(np.float32) / 255.0
    mask = Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "L")
    return mask.resize((SIZE * SS, SIZE * SS), Image.LANCZOS)


def _rgba_img(color, alpha: np.ndarray) -> Image.Image:
    """A solid-`color` RGBA image shaped by `alpha` (0..1 float, square)."""
    d = alpha.shape[0]
    out = np.zeros((d, d, 4), np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = color
    out[..., 3] = (np.clip(alpha, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def compose(crest_mask: Image.Image, color, ringed: bool) -> Image.Image:
    """Faction-coloured crest (+ optional gold border box), downsampled to a SIZE RGBA image."""
    d = SIZE * SS
    cs = int(d * CREST_SCALE)
    crest = crest_mask.resize((cs, cs), Image.LANCZOS)
    canvas = Image.new("L", (d, d), 0)
    canvas.paste(crest, ((d - cs) // 2, (d - cs) // 2))
    result = _rgba_img(color, np.asarray(canvas).astype(np.float32) / 255.0)

    if ringed:
        ring = Image.new("L", (d, d), 0)
        dr = ImageDraw.Draw(ring)
        m = d * RING_INSET
        dr.rounded_rectangle([m, m, d - 1 - m, d - 1 - m], radius=d * RING_RADIUS,
                             outline=255, width=max(2, int(d * RING_WIDTH)))
        result = Image.alpha_composite(result, _rgba_img(GOLD, np.asarray(ring).astype(np.float32) / 255.0))

    return result.resize((SIZE, SIZE), Image.LANCZOS)


def endeavor_glyph() -> Image.Image:
    """An upright carpenter's hammer (claw head over a straight handle) — the Endeavors column
    header, a 64x64 WHITE silhouette muted-tinted at runtime like the sibling icons/*.tga headers.
    A single tool by design: a crossed hammer + saw smudges to a blob at 16px. Returns the SS mask."""
    d = SIZE * SS
    img = Image.new("L", (d, d), 0)
    dr = ImageDraw.Draw(img)
    dr.rounded_rectangle([d * 0.455, d * 0.34, d * 0.545, d * 0.82], radius=d * 0.035, fill=255)  # handle
    dr.rounded_rectangle([d * 0.30, d * 0.20, d * 0.70, d * 0.36], radius=d * 0.04, fill=255)      # head
    dr.polygon([(d * 0.30, d * 0.24), (d * 0.20, d * 0.30), (d * 0.30, d * 0.34)], fill=255)       # claw beak
    dr.rectangle([d * 0.245, d * 0.30, d * 0.30, d * 0.325], fill=0)                               # claw notch
    return img


def _tga(img: Image.Image, path: str) -> None:
    """Write a SIZE x SIZE house-format TGA (type-2 uncompressed, 32bpp, BGRA, bottom-up)."""
    rgba = np.asarray(img.convert("RGBA")).astype(np.uint8)
    h, w, _ = rgba.shape
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    w & 0xFF, (w >> 8) & 0xFF, h & 0xFF, (h >> 8) & 0xFF, 32, 0x08])
    bgra = rgba[..., [2, 1, 0, 3]]
    with open(path, "wb") as f:
        f.write(header)
        f.write(bgra[::-1].tobytes())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    icons = os.path.join(here, "Warbandeer", "icons")
    ap.add_argument("--icons-dir", default=icons, help="Warbandeer/icons directory")
    ap.add_argument("--preview", help="also write PNGs into this dir for visual verification")
    args = ap.parse_args()

    factions = [("alliance", ALLIANCE), ("horde", HORDE)]
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
    for name, color in factions:
        crest = _crest_alpha(os.path.join(args.icons_dir, name + ".tga"))
        for suffix, ringed in (("", False), ("-sub", True)):
            img = compose(crest, color, ringed)
            path = os.path.join(args.icons_dir, "endeavor-" + name + suffix + ".tga")
            _tga(img, path)
            print(f"wrote {path} ({SIZE}x{SIZE}, {18 + SIZE * SIZE * 4} bytes)")
            if args.preview:
                img.save(os.path.join(args.preview, "endeavor-" + name + suffix + ".png"))

    # Endeavors column header glyph (white silhouette, muted-tinted at runtime).
    galpha = np.asarray(endeavor_glyph().resize((SIZE, SIZE), Image.LANCZOS)).astype(np.float32) / 255.0
    gpath = os.path.join(args.icons_dir, "endeavors.tga")
    _tga(_rgba_img((255, 255, 255), galpha), gpath)
    print(f"wrote {gpath} ({SIZE}x{SIZE}, {18 + SIZE * SIZE * 4} bytes)")
    if args.preview:
        bg = Image.new("RGBA", (SIZE, SIZE), (26, 26, 30, 255))
        Image.alpha_composite(bg, _rgba_img((140, 148, 158), galpha)).save(   # muted-ish, for verification
            os.path.join(args.preview, "endeavors.png"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
