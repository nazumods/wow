"""Generate an addon logo in the suite's Warbandeer crest style — identical every time.

Reuses the Warbandeer crest base (stag emblem, WARBANDEER title banner, purple
ribbon reading "ADDON NAME"): erases the ribbon's placeholder text and resets
it with the given text in the measured house typography (bold sans, tan ink),
sized to fit the ribbon between its fixed flanking arrow glyphs.

Usage (from anywhere):
    python Tooling/make_addon_logo.py Characters --out Warbandeer_Characters/logo.png

Only the ribbon text varies; every other parameter is a fixed constant so
repeated runs (and future logos) come out in exactly the same style. Output is
a 1024x1024 PNG like the sibling logos.

Requires: pillow, and the Windows font Arial Bold (C:/Windows/Fonts/arialbd.ttf).
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

TOOLING_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SOURCE = os.path.join(TOOLING_DIR, "assets", "warbandeer_base.png")

FONT_CANDIDATES = [
    r"C:/Windows/Fonts/arialbd.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/Library/Fonts/Arial Bold.ttf",
]

# --- fixed style constants (measured from the crest base's own source art,
# a 400x400 image; output is upscaled to match the sibling logos) ---
OUT_SIZE = 1024
SOURCE_SIZE = 400
SCALE = OUT_SIZE / SOURCE_SIZE

RIBBON_FILL = (81, 63, 81)          # sampled purple ribbon fill
TEXT_COLOR = (191, 176, 138)        # sampled tan ink
# placeholder text's erase zone (source-image px), clear of the ribbon's
# flanking arrow glyphs (arrows sit at x 125-133 and x 265-273)
ERASE_BOX = (137, 309, 263, 329)
CAP_HEIGHT = 34                     # target rendered cap-height, in OUT_SIZE px
SLOT_PAD = 10                       # margin kept clear of the erase box edges, in OUT_SIZE px


def _load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    raise FileNotFoundError("no Arial Bold found in: " + ", ".join(FONT_CANDIDATES))


def make_logo(text, source=DEFAULT_SOURCE, out="logo.png"):
    im = Image.open(source).convert("RGB").resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)
    x0, y0, x1, y1 = (round(v * SCALE) for v in ERASE_BOX)

    # erase the placeholder text with a soft-edged fill — the ribbon is a flat
    # color, so a plain rectangle blends invisibly into the surrounding purple
    fill_layer = Image.new("RGB", im.size, RIBBON_FILL)
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rectangle([x0, y0, x1, y1], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    im = Image.composite(fill_layer, im, mask)

    # size the text from the target cap-height, then condense to fit the slot
    # width if the word is too wide for it
    text = text.upper()
    slot_w = (x1 - SLOT_PAD) - (x0 + SLOT_PAD)
    probe = Image.new("L", (10, 10), 0)
    pd = ImageDraw.Draw(probe)
    probe_size = 100
    cap_box = pd.textbbox((0, 0), "AH", font=_load_font(probe_size))
    size = max(10, round(probe_size * CAP_HEIGHT / (cap_box[3] - cap_box[1])))
    font = _load_font(size)
    tb = pd.textbbox((0, 0), text, font=font)
    tw = tb[2] - tb[0]
    if tw > slot_w:
        size = max(10, int(size * slot_w / tw))
        font = _load_font(size)
        tb = pd.textbbox((0, 0), text, font=font)
        tw = tb[2] - tb[0]

    cx = (x0 + x1) / 2
    cy = round((ERASE_BOX[1] + ERASE_BOX[3]) / 2 * SCALE)
    d = ImageDraw.Draw(im)
    d.text((cx - tw / 2 - tb[0], cy - (tb[3] - tb[1]) / 2 - tb[1]), text, font=font, fill=TEXT_COLOR)

    im.save(out)
    print("saved", out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("text", help="ribbon suffix to set (e.g. Characters)")
    ap.add_argument("--source", default=DEFAULT_SOURCE,
                    help="base crest PNG (default: Tooling/assets/warbandeer_base.png)")
    ap.add_argument("--out", default="logo.png", help="output PNG path")
    args = ap.parse_args()
    make_logo(args.text, args.source, args.out)
