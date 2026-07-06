#!/usr/bin/env python3
"""Warbandeer Summary-column icon generator.

Every column header in Warbandeer's Summary view (`/wb summary`) uses a
64x64 32-bit uncompressed TGA that is a **white silhouette** of the source
art, tinted `ns.theme.colors.muted` at runtime (see any
`Warbandeer/views/summaryCol/*.lua` — e.g. `manacrystal.lua`,
`fieldaccolade.lua`). This tool produces one such TGA from a game icon so
new currency/tracker columns match the existing 14 headers exactly.

Pipeline for a new currency column (fully reusable):
  1. Find the currency's icon name. Wowhead `currency=<ID>` -> Warcraft Wiki
     page reports the icon file, e.g. `inv_10_gathering_bioluminescentspores_large`.
  2. Run this tool with `--icon-name <name>` to fetch the real game art from
     the Wowhead icon CDN and render the muted-style silhouette TGA:
       python Tooling/make_summary_icon.py --icon-name inv_10_gathering_bioluminescentspores_large \
           --out Warbandeer/icons/unalloyedabundance.tga --preview out.png
  3. Add the column .lua (copy an existing `summaryCol/*.lua`) with
     `iconPath = "Interface\\AddOns\\Warbandeer\\icons\\<name>.tga"` and
     `iconColor = ns.theme.colors.muted`, list it in `Warbandeer.toc`.

Alternatively pass `--src <path>` to convert a local PNG/JPG (an in-game
capture or an already-extracted BLP->PNG) instead of fetching.

House TGA format (matched byte-for-byte to the shipped icons):
  18-byte header, image type 2 (uncompressed true-color), 64x64, 32 bpp,
  descriptor 0x08 (8 alpha bits, bottom-left origin), pixels BGRA bottom-up.
  RGB is forced to white; only alpha carries the shape.

The alpha comes from the source luminance by default (`--alpha luma`),
which suits the glow-on-dark WoW icon style: bright art -> opaque, dark
background -> transparent. `--alpha channel` instead uses the source's own
alpha (for PNGs that already have transparency). `--floor`/`--gamma` clean
and shape the falloff; `--keep-color` skips the whitening for debugging.

Requires: pillow, numpy (already used by the sibling logo generators).
"""

import argparse
import io
import sys
import urllib.request

import numpy as np
from PIL import Image

# Wowhead icon CDN. `large` is the 56x56 art; we upsample to 64 to match the
# shipped icon size. Names are lowercase; some 10.x gathering icons carry an
# explicit `_large`/`_small` node-size suffix that IS part of the real name.
CDN = "https://wow.zamimg.com/images/wow/icons/large/{name}.jpg"

SIZE = 64  # shipped icons are 64x64


def fetch_icon(name: str) -> Image.Image:
    url = CDN.format(name=name.lower())
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        if r.status != 200:
            raise SystemExit(f"icon fetch failed ({r.status}): {url}")
        data = r.read()
    if len(data) < 500:
        raise SystemExit(f"icon fetch returned a placeholder ({len(data)}B): {url}")
    return Image.open(io.BytesIO(data))


def build(img: Image.Image, alpha_mode: str, floor: float, gamma: float,
          keep_color: bool, size: int) -> np.ndarray:
    img = img.convert("RGBA").resize((size, size), Image.LANCZOS)
    arr = np.asarray(img).astype(np.float32) / 255.0
    rgb, src_a = arr[..., :3], arr[..., 3]

    if alpha_mode == "channel":
        a = src_a
    else:  # luma: perceptual luminance of the (premultiplied) art
        lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
        a = lum * src_a  # respect any existing transparency

    # Lift the background floor to fully transparent, then renormalize so the
    # brightest art stays fully opaque, then shape the falloff.
    if floor > 0:
        a = np.clip((a - floor) / (1.0 - floor), 0.0, 1.0)
    peak = float(a.max())
    if peak > 0:
        a = a / peak
    if gamma != 1.0:
        a = np.power(a, gamma)

    out = np.zeros((size, size, 4), np.float32)
    out[..., :3] = rgb if keep_color else 1.0
    out[..., 3] = a
    return (np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def write_tga(rgba: np.ndarray, path: str) -> None:
    """Write the exact house format: type-2 uncompressed, 32bpp, descriptor
    0x08 (bottom-left origin), pixels BGRA, rows bottom-to-top."""
    h, w = rgba.shape[:2]
    header = bytes([
        0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        w & 0xFF, (w >> 8) & 0xFF,
        h & 0xFF, (h >> 8) & 0xFF,
        32, 0x08,
    ])
    bgra = rgba[..., [2, 1, 0, 3]]          # RGBA -> BGRA
    body = bgra[::-1].tobytes()             # bottom-left origin -> flip rows
    with open(path, "wb") as f:
        f.write(header)
        f.write(body)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--icon-name", help="WoW icon name to fetch from the Wowhead CDN")
    g.add_argument("--src", help="local PNG/JPG source image instead of fetching")
    ap.add_argument("--out", required=True, help="output .tga path")
    ap.add_argument("--alpha", choices=("luma", "channel"), default="luma",
                    help="alpha source: luminance of the art (default) or the source alpha channel")
    ap.add_argument("--floor", type=float, default=0.06,
                    help="alpha below this (0-1) is clamped to transparent, to kill the dark background (default 0.06)")
    ap.add_argument("--gamma", type=float, default=0.85,
                    help="alpha falloff shaping; <1 fattens the silhouette (default 0.85)")
    ap.add_argument("--size", type=int, default=SIZE, help="output edge in px (default 64)")
    ap.add_argument("--keep-color", action="store_true", help="keep source RGB instead of whitening (debug)")
    ap.add_argument("--preview", help="also write a PNG here for visual verification")
    args = ap.parse_args()

    img = fetch_icon(args.icon_name) if args.icon_name else Image.open(args.src)
    rgba = build(img, args.alpha, args.floor, args.gamma, args.keep_color, args.size)
    write_tga(rgba, args.out)
    if args.preview:
        Image.fromarray(rgba, "RGBA").save(args.preview)
    print(f"wrote {args.out} ({args.size}x{args.size}, {18 + args.size*args.size*4} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
