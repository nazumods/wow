"""Generate an addon logo in the suite's flag style — identical every time.

Reuses the Warbandeer_Collected photo flag as the base: masks out its word,
inpaints the cloth, and re-sets the requested text along the original word's
own flow curve, with typography measured from the original (tall-letter
height 166px, ~24px stems, condensed blackletter, pale halo).

Usage (from anywhere):
    python Tooling/make_addon_logo.py Inventory --out ShadowsOfUI-WarbandInventory/logo.png

Only the text varies; every other parameter is a fixed constant so repeated
runs (and future logos) come out in exactly the same style. Output is a
1024x1024 PNG like the sibling logos.

Requires: pillow, numpy, opencv-python-headless, and the Windows font
Old English Text MT (C:/Windows/Fonts/OLDENGL.TTF).
"""
import argparse
import os

import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter

TOOLING_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SOURCE = os.path.join(TOOLING_DIR, "assets", "warbandeer_flag_base.png")
FONT = r"C:/Windows/Fonts/OLDENGL.TTF"

# --- fixed style constants (measured from the original logos) ---
FONT_SIZE = 230          # gives the original's 166px tall-letter height
TARGET_W = 740           # condensed word width (original word is 688px)
STROKE = 2               # pre-thicken stems so they land ~24px after condense
INK = np.array([21.0, 21.0, 18.0])
HALO_COL = np.array([175.0, 205.0, 120.0])
TEXT_BAND = (slice(300, 640), slice(140, 900))   # where the source word lives


def make_logo(text, source=DEFAULT_SOURCE, out="logo.png"):
    im = Image.open(source).convert("RGB")
    a = np.asarray(im)
    size = im.size[0]

    # -----------------------------------------------------------
    # 1. Mask the source text (dark glyph pixels inside the flag).
    # -----------------------------------------------------------
    dark = (a[:, :, 0] < 80) & (a[:, :, 1] < 80) & (a[:, :, 2] < 70)
    region = np.zeros_like(dark)
    region[TEXT_BAND] = True
    mask = (dark & region).astype(np.uint8) * 255

    # original text geometry BEFORE dilation
    ys, xs = np.where(mask > 0)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    # per-column vertical centreline of the source text -> flow curve
    cols, cys = [], []
    for x in range(x0, x1 + 1):
        yy = np.where(mask[:, x] > 0)[0]
        if len(yy) > 4:
            cols.append(x)
            cys.append(yy.mean())
    poly = np.polyfit(cols, cys, 3)          # cubic follows the cloth wave
    flow = np.poly1d(poly)

    # dilate mask to cover antialiased edges + halo, then inpaint
    kern = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (25, 25))
    grown = cv2.dilate(mask, kern)
    bgr = cv2.cvtColor(a, cv2.COLOR_RGB2BGR)
    clean = cv2.inpaint(bgr, grown, 15, cv2.INPAINT_NS)
    # the inpaint leaves subtle bright blotches where glyphs/halo were —
    # low-pass just the masked region so it reads as smooth cloth
    blurred = cv2.GaussianBlur(clean, (0, 0), 12)
    feather = cv2.GaussianBlur(grown, (0, 0), 6).astype(np.float64) / 255.0
    clean = (clean.astype(np.float64) * (1 - feather[:, :, None] * 0.85)
             + blurred.astype(np.float64) * feather[:, :, None] * 0.85)
    clean_rgb = cv2.cvtColor(clean.astype(np.uint8), cv2.COLOR_BGR2RGB)

    # -----------------------------------------------------------
    # 2. Render the text flat, condense, then bend along the flow.
    # -----------------------------------------------------------
    probe = Image.new("L", (1400, 500), 0)
    pd = ImageDraw.Draw(probe)
    font = ImageFont.truetype(FONT, FONT_SIZE)
    tb = pd.textbbox((0, 0), text, font=font, stroke_width=STROKE)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    txt = Image.new("L", (tw + 40, th + 120), 0)
    td = ImageDraw.Draw(txt)
    td.text((20 - tb[0], 40 - tb[1]), text, font=font, fill=255,
            stroke_width=STROKE, stroke_fill=255)
    # horizontal condense to the target width
    ratio = TARGET_W / tw
    txt = txt.resize((int(txt.width * ratio), txt.height), Image.LANCZOS)
    txt_a = np.asarray(txt)

    # place: same horizontal centre as the source word
    cx = (x0 + x1) / 2
    left = int(cx - txt.width / 2)
    mean_flow = np.mean([flow(x) for x in range(x0, x1 + 1)])

    canvas = Image.fromarray(clean_rgb).convert("RGB")
    overlay = np.zeros((size, size), dtype=np.float64)
    for sx in range(txt.width):
        gx = left + sx
        if not (0 <= gx < size):
            continue
        dy = flow(min(max(gx, x0), x1)) - mean_flow   # cloth flow offset
        col = txt_a[:, sx]
        yy = np.where(col > 0)[0]
        if len(yy) == 0:
            continue
        # column centred on flow line
        ccy = (y0 + y1) / 2 + dy
        top = int(round(ccy - txt.height / 2))
        for sy in yy:
            gy = top + sy
            if 0 <= gy < size:
                overlay[gy, gx] = max(overlay[gy, gx], col[sy] / 255.0)

    # slight blur to match photographic antialiasing
    overlay_img = Image.fromarray((overlay * 255).astype(np.uint8))
    overlay_img = overlay_img.filter(ImageFilter.GaussianBlur(0.7))
    ov = np.asarray(overlay_img).astype(np.float64) / 255.0

    out_a = np.asarray(canvas).astype(np.float64)

    # pale halo around the glyphs (the originals have one) — blurred and
    # slightly grown copy of the glyph alpha, drawn beneath the ink
    halo_img = overlay_img.filter(ImageFilter.MaxFilter(5))
    halo_img = halo_img.filter(ImageFilter.GaussianBlur(2.2))
    halo = np.asarray(halo_img).astype(np.float64) / 255.0
    halo = np.clip(halo - ov, 0, 1)            # ring only, not under ink
    ha = halo[:, :, None] * 0.55
    out_a = out_a * (1 - ha) + HALO_COL[None, None, :] * ha

    # near-black ink on top
    alpha = ov[:, :, None] * 0.96
    out_a = out_a * (1 - alpha) + INK[None, None, :] * alpha
    Image.fromarray(out_a.astype(np.uint8)).save(out)
    print("saved", out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("text", help="word to set on the flag (e.g. Inventory)")
    ap.add_argument("--source", default=DEFAULT_SOURCE,
                    help="base flag photo (default: Tooling/assets/warbandeer_flag_base.png)")
    ap.add_argument("--out", default="logo.png", help="output PNG path")
    args = ap.parse_args()
    make_logo(args.text, args.source, args.out)
