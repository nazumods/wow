"""Generate a ShadowsOfUI-family addon logo (purple moon style) — identical every time.

Reuses the committed ShadowsOfUI-Known logo as the base: masks out its word,
inpaints the background, and re-sets the requested text in the measured house
typography (Times New Roman, ~94% condensed, cream ink, sized to the family's
cap-height/width rules).

Usage (from anywhere):
    python Tooling/make_moon_logo.py Castbar --out ShadowsOfUI-Castbar/logo.png

Only the text varies; every other parameter is a fixed constant so repeated
runs (and future logos) come out in exactly the same style. Output is a
400x400 PNG (the resolution CurseForge serves for project avatars).

Requires: pillow, numpy, opencv-python-headless, and Times New Roman
(C:/Windows/Fonts/times.ttf).
"""
import argparse
import os

import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SOURCE = os.path.join(REPO_ROOT, "ShadowsOfUI-Known", "logo.png")
FONT = r"C:/Windows/Fonts/times.ttf"

# --- fixed style constants (measured from the XP / Known originals) ---
CONDENSE = 0.944          # original aspect 4.089 vs Times' 4.333
MAX_CAP_H = 79            # XP's cap height (short words are height-limited)
MAX_W = 235               # Known's word width 229 (long words width-limited)
CENTER = (262, 208)       # text-block centre inside the dark disc
INK = np.array([241.0, 233.0, 221.0])


def make_logo(text, source=DEFAULT_SOURCE, out="logo.png"):
    im = Image.open(source).convert("RGB")
    a = np.asarray(im)
    size = im.size[0]

    # -----------------------------------------------------------
    # 1. Mask the source word (bright cream pixels) and inpaint.
    # -----------------------------------------------------------
    bright = (a[:, :, 0] > 170) & (a[:, :, 1] > 160) & (a[:, :, 2] > 140)
    mask = bright.astype(np.uint8) * 255
    kern = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    grown = cv2.dilate(mask, kern)
    bgr = cv2.cvtColor(a, cv2.COLOR_RGB2BGR)
    clean = cv2.inpaint(bgr, grown, 6, cv2.INPAINT_NS)
    clean_rgb = cv2.cvtColor(clean, cv2.COLOR_BGR2RGB)

    # -----------------------------------------------------------
    # 2. Size the text: cap height MAX_CAP_H unless the condensed
    #    word would exceed MAX_W, in which case shrink to fit.
    # -----------------------------------------------------------
    probe = Image.new("L", (1600, 400), 0)
    pd = ImageDraw.Draw(probe)

    def measure(sz):
        f = ImageFont.truetype(FONT, sz)
        tb = pd.textbbox((0, 0), text, font=f)
        cb = pd.textbbox((0, 0), "X", font=f)      # cap height reference
        return f, tb, (tb[2] - tb[0]) * CONDENSE, cb[3] - cb[1]

    sz = 8
    font, tb, w, cap = measure(sz)
    while True:
        f2, tb2, w2, cap2 = measure(sz + 1)
        if cap2 > MAX_CAP_H or w2 > MAX_W:
            break
        sz += 1
        font, tb, w, cap = f2, tb2, w2, cap2
    print(f"font size {sz}, cap height {cap}, condensed width {round(w)}")

    # -----------------------------------------------------------
    # 3. Render, condense, and composite at the family anchor.
    # -----------------------------------------------------------
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    txt = Image.new("L", (tw + 20, th + 20), 0)
    td = ImageDraw.Draw(txt)
    td.text((10 - tb[0], 10 - tb[1]), text, font=font, fill=255)
    txt = txt.resize((int(txt.width * CONDENSE), txt.height), Image.LANCZOS)
    txt = txt.filter(ImageFilter.GaussianBlur(0.4))   # photographic softness

    ov = np.zeros((size, size), dtype=np.float64)
    left = int(round(CENTER[0] - txt.width / 2))
    top = int(round(CENTER[1] - txt.height / 2))
    ta = np.asarray(txt).astype(np.float64) / 255.0
    y_from, x_from = max(0, -top), max(0, -left)
    y_to = min(txt.height, size - top)
    x_to = min(txt.width, size - left)
    ov[top + y_from:top + y_to, left + x_from:left + x_to] = \
        ta[y_from:y_to, x_from:x_to]

    out_a = clean_rgb.astype(np.float64)
    alpha = ov[:, :, None]
    out_a = out_a * (1 - alpha) + INK[None, None, :] * alpha
    Image.fromarray(out_a.astype(np.uint8)).save(out)
    print("saved", out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("text", help="word to set on the logo (e.g. Castbar)")
    ap.add_argument("--source", default=DEFAULT_SOURCE,
                    help="base moon logo (default: ShadowsOfUI-Known)")
    ap.add_argument("--out", default="logo.png", help="output PNG path")
    args = ap.parse_args()
    make_logo(args.text, args.source, args.out)
