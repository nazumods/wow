"""Procedural flag logo — draws the suite flag scene from scratch in PIL.

SUPERSEDED by make_addon_logo.py, which reuses the original photo flag and
matches the sibling logos far more closely. Kept as a reference for the
palette/geometry and as a fallback if a non-photo variant is ever wanted.

Usage: python Tooling/procedural_flag_logo.py <Text> <out.png>
"""
import math
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 1024
TEXT = sys.argv[1] if len(sys.argv) > 1 else "Inventory"
OUT = sys.argv[2] if len(sys.argv) > 2 else "logo_procedural.png"

# --- palette sampled from sibling logos ---
SKY_TOP = (92, 138, 205)
SKY_BOT = (182, 210, 245)
G_SHADOW = (55, 98, 30)
G_MID = (110, 167, 63)
G_HIGH = (154, 198, 95)
POLE_LIGHT = (214, 222, 232)
POLE_MID = (151, 171, 193)
POLE_DARK = (96, 112, 134)
TEXTCOL = (21, 21, 18)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


# --- sky gradient ---
sky = Image.new("RGB", (S, S))
px = sky.load()
for y in range(S):
    t = y / (S - 1)
    c = lerp(SKY_TOP, SKY_BOT, t ** 0.85)
    for x in range(S):
        px[x, y] = c

# --- clouds: soft blurred white blobs, lower 2/3 ---
clouds = Image.new("L", (S, S), 0)
cd = ImageDraw.Draw(clouds)
blobs = [
    (170, 720, 240, 70), (250, 760, 200, 60), (120, 700, 150, 55),
    (760, 800, 300, 80), (860, 850, 220, 65), (640, 830, 180, 55),
    (500, 900, 260, 70), (900, 620, 170, 55), (60, 880, 200, 60),
    (400, 690, 150, 45),
]
for cx, cy, rw, rh in blobs:
    cd.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=255)
clouds = clouds.filter(ImageFilter.GaussianBlur(38))
white = Image.new("RGB", (S, S), (247, 250, 254))
# fade clouds so they read as soft, ~78% opacity max
clouds = clouds.point(lambda v: int(v * 0.78))
sky = Image.composite(white, sky, clouds)

base = sky.convert("RGBA")

# ---------------------------------------------------------------
# Flag rendered flat (with folds + text), then warped to wave.
# ---------------------------------------------------------------
FW, FH = 880, 470          # flat flag size (large — fills the frame)
fx0, fy0 = 112, 236        # where flag hoist (top-left) sits on canvas

flag = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
fp = flag.load()
for x in range(FW):
    hx = x / FW
    edge = 1.0 - 0.16 * hx          # darken toward the flying (right) edge
    for y in range(FH):
        vy = y / FH
        # DIAGONAL folds: bands slant top-left -> bottom-right
        u = hx - 0.32 * vy
        fold = 0.5 + 0.42 * math.sin(u * math.pi * 5.2 - 0.6) \
                    + 0.16 * math.sin(u * math.pi * 11.0 + 1.3)
        fold = max(0.0, min(1.0, fold))
        if fold < 0.5:
            col = lerp(G_SHADOW, G_MID, fold / 0.5)
        else:
            col = lerp(G_MID, G_HIGH, (fold - 0.5) / 0.5)
        shade = (1.0 - 0.10 * vy) * edge      # gentle top-lighting
        fp[x, y] = (int(col[0] * shade), int(col[1] * shade),
                    int(col[2] * shade), 255)

# --- text on the flat flag ---
fdraw = ImageDraw.Draw(flag)
font = ImageFont.truetype(r"C:/Windows/Fonts/OLDENGL.TTF", 166)
tb = fdraw.textbbox((0, 0), TEXT, font=font)
tw, th = tb[2] - tb[0], tb[3] - tb[1]
tx = (FW - tw) // 2 - tb[0]
ty = (FH - th) // 2 - tb[1]
# subtle light emboss then dark letters (stroke thickens the blackletter,
# since Old English Text MT has no bold weight)
fdraw.text((tx + 3, ty + 4), TEXT, font=font, fill=(230, 240, 220, 90),
           stroke_width=2, stroke_fill=(230, 240, 220, 90))
fdraw.text((tx, ty), TEXT, font=font, fill=TEXTCOL + (255,),
           stroke_width=2, stroke_fill=TEXTCOL + (255,))

# ---------------------------------------------------------------
# Warp: per-column vertical displacement (wave) + slight droop.
# ---------------------------------------------------------------
AMP = 44           # wave amplitude px
warp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
flag_px = flag.load()
warp_px = warp.load()
for sx in range(FW):
    hx = sx / FW
    # anchor the hoist (hx=0) at the pole: wave grows from ~0 at left
    grow = min(1.0, hx / 0.12)
    dy = AMP * grow * math.sin(hx * math.pi * 2.3 + 0.4) \
         + 14 * grow * math.sin(hx * math.pi * 4.6) \
         - 74 * hx            # tilt: flag flies UP to the right
    # vertical squash toward flying edge for flutter
    squash = 1.0 - 0.08 * hx
    for sy in range(FH):
        r, g, b, a = flag_px[sx, sy]
        if a == 0:
            continue
        oy = fy0 + dy + (sy - FH / 2) * squash + FH / 2
        ox = fx0 + sx
        iy = int(oy)
        ix = int(ox)
        if 0 <= ix < S and 0 <= iy < S:
            warp_px[ix, iy] = (r, g, b, a)
            if 0 <= iy + 1 < S:      # fill 1px seam from squash
                warp_px[ix, iy + 1] = (r, g, b, a)

# ---------------------------------------------------------------
# Flagpole drawn BEHIND the flag (thin, mostly hidden; finial peeks
# above the hoist). Pole -> then flag composited over it.
# ---------------------------------------------------------------
draw = ImageDraw.Draw(base)
pole_x = fx0 - 4
pw = 18
for i in range(pw):
    t = i / (pw - 1)
    if t < 0.4:
        c = lerp(POLE_DARK, POLE_LIGHT, t / 0.4)
    else:
        c = lerp(POLE_LIGHT, POLE_DARK, (t - 0.4) / 0.6)
    draw.line([(pole_x + i, 150), (pole_x + i, S - 30)], fill=c + (255,))
# gold finial ball, above the flag hoist
bx, by, br = pole_x + pw // 2, 150, 24
for i in range(br, 0, -1):
    t = i / br
    c = lerp((255, 236, 150), (176, 132, 30), 1 - t)
    draw.ellipse([bx - i, by - i, bx + i, by + i], fill=c + (255,))
draw.ellipse([bx - br, by - br, bx + br, by + br], outline=(120, 90, 20, 255), width=2)

# flag over the pole
base.alpha_composite(warp)

base.convert("RGB").save(OUT)
print("saved", OUT)
