#!/usr/bin/env python3
"""Warbandeer Great Vault view assets.

Generates the three white TGA textures the Great Vault view (`/wb vault`) needs, all in the same
house TGA format as the other Warbandeer icons (18-byte header, type-2 uncompressed, 32bpp,
descriptor 0x08, BGRA bottom-up — see make_summary_icon.py):

  * icons/pip-full.tga   -- a filled GOLD disc; the vault view renders it inline in a table cell via
                            plain |Tpath:h:w|t markup for an UNLOCKED Great Vault slot. The colour is
                            baked in (not runtime-tinted) because inline texture markup can't carry a
                            reliable vertex-colour, unlike a Cell's own texture.
  * icons/pip-empty.tga  -- a hollow MUTED-grey ring; rendered the same way for a LOCKED slot.
  * icons/views/vault.tga -- the rail/ring nav glyph: a vault door with a central dial, a 64x64 WHITE
                            silhouette matching the sibling icons/views/*.tga glyphs (the IconStrip
                            tints it muted/text/gold per state, so it must stay white).

The pip pair is a reusable filled-disc / ring primitive; the glyph is drawn procedurally so it needs
no network / icon-name lookup. All three are 64x64, supersampled 4x then boxed down for clean edges.

Requires: pillow, numpy (already used by the sibling generators).

  python Tooling/make_vault_assets.py                     # writes all three under Warbandeer/icons
  python Tooling/make_vault_assets.py --preview out/      # also dump PNGs for visual verification
"""

import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

SIZE = 64
SS = 4  # supersample factor for smooth edges


GOLD = (230, 195, 92)    # unlocked pip (#E6C35C) — matches the mockup / theme gold
MUTED = (86, 95, 104)    # locked pip (#565F68) — theme muted


def _tga(alpha: np.ndarray, path: str, rgb=(255, 255, 255)) -> None:
    """Write a 64x64 house-format TGA: solid `rgb`, `alpha` (0..1 float, HxW) as the shape."""
    h, w = alpha.shape
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    w & 0xFF, (w >> 8) & 0xFF, h & 0xFF, (h >> 8) & 0xFF, 32, 0x08])
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = rgb
    rgba[..., 3] = (np.clip(alpha, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    bgra = rgba[..., [2, 1, 0, 3]]
    with open(path, "wb") as f:
        f.write(header)
        f.write(bgra[::-1].tobytes())


def _alpha_from(mask: Image.Image) -> np.ndarray:
    """Downsample a supersampled 'L' mask to SIZE and return a 0..1 float alpha."""
    small = mask.resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(small).astype(np.float32) / 255.0


def _preview(alpha: np.ndarray, path: str, rgb=(255, 255, 255)) -> None:
    rgba = np.zeros((*alpha.shape, 4), np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = rgb
    rgba[..., 3] = (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(path)


def disc() -> np.ndarray:
    """Filled circle, ~78% of the frame (leaves inline breathing room)."""
    d = SIZE * SS
    img = Image.new("L", (d, d), 0)
    dr = ImageDraw.Draw(img)
    m = d * 0.11
    dr.ellipse([m, m, d - m, d - m], fill=255)
    return _alpha_from(img)


def ring() -> np.ndarray:
    """Hollow ring: an outer disc with the centre punched out (~same outer radius as disc())."""
    d = SIZE * SS
    img = Image.new("L", (d, d), 0)
    dr = ImageDraw.Draw(img)
    m = d * 0.11
    dr.ellipse([m, m, d - m, d - m], fill=255)
    t = d * 0.155  # ring thickness
    dr.ellipse([m + t, m + t, d - m - t, d - m - t], fill=0)
    return _alpha_from(img)


def vault_glyph() -> np.ndarray:
    """A vault door: a rounded-square door plate with an inset border, a central dial ring + hub,
    and four short spokes — reads as a vault at rail size, white silhouette for runtime tinting."""
    d = SIZE * SS
    img = Image.new("L", (d, d), 0)
    dr = ImageDraw.Draw(img)
    m = d * 0.08
    r = d * 0.16
    # door plate (filled rounded square)
    dr.rounded_rectangle([m, m, d - m, d - m], radius=r, fill=255)
    # inset seam near the edge (thin transparent border ring)
    seam = d * 0.085
    sw = max(2, int(d * 0.018))
    dr.rounded_rectangle([m + seam, m + seam, d - m - seam, d - m - seam],
                         radius=r * 0.7, outline=0, width=sw)
    # central dial: transparent ring with a solid hub
    cx = cy = d / 2
    R = d * 0.20
    dial = max(3, int(d * 0.045))
    dr.ellipse([cx - R, cy - R, cx + R, cy + R], outline=0, width=dial)
    hub = d * 0.055
    dr.ellipse([cx - hub, cy - hub, cx + hub, cy + hub], fill=0)
    # four spokes from the hub through the dial ring
    sp = max(3, int(d * 0.03))
    reach = d * 0.30
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        dr.line([cx, cy, cx + dx * reach, cy + dy * reach], fill=0, width=sp)
    return _alpha_from(img)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap.add_argument("--icons-dir", default=os.path.join(here, "Warbandeer", "icons"),
                    help="Warbandeer/icons directory (default: alongside this repo)")
    ap.add_argument("--preview", help="also write PNGs into this dir for visual verification")
    args = ap.parse_args()

    assets = [
        (os.path.join(args.icons_dir, "pip-full.tga"), disc(), GOLD),
        (os.path.join(args.icons_dir, "pip-empty.tga"), ring(), MUTED),
        (os.path.join(args.icons_dir, "views", "vault.tga"), vault_glyph(), (255, 255, 255)),
    ]
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
    for path, alpha, rgb in assets:
        _tga(alpha, path, rgb)
        print(f"wrote {path} ({SIZE}x{SIZE}, {18 + SIZE * SIZE * 4} bytes)")
        if args.preview:
            _preview(alpha, os.path.join(args.preview, os.path.basename(path) + ".png"), rgb)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
