#!/usr/bin/env python3
"""Warbandeer_Collected weapon-type column-icon generator.

The Weapons grid (`/collected` -> Weapons) has one column per weapon TYPE. The
columns shipped as 3-char text abbreviations (`Axe Swd Mce …`) as a placeholder;
this replaces them with 64x64 house-style white-silhouette TGAs — the same
muted-icon look every Warbandeer Summary column uses — one per
`Enum.TransmogCollectionType` the grid renders.

It reuses `make_summary_icon.py`'s pipeline (Wowhead-CDN fetch -> white silhouette
-> byte-exact house TGA); this file just carries the type -> icon-name -> output
map so the 17 icons regenerate reproducibly with one command instead of 17 ad-hoc
runs. The Lua side (`ns.WeaponTypeIcon` in WeaponViewData.lua) keys the same output
basenames by type id.

Rendered untinted via `|T…|t` markup in the column header (inline markup can't
carry a vertex colour, like the vault pips), so the silhouettes read white on the
grid's dark header backdrop.

    python Tooling/make_weapon_type_icons.py                 # regenerate all 17
    python Tooling/make_weapon_type_icons.py --only sword    # just one (by basename)
    python Tooling/make_weapon_type_icons.py --preview out/  # also dump PNGs

Requires: pillow, numpy (as make_summary_icon.py).
"""

import argparse
import os
import sys

# Reuse the house-format pipeline from the sibling generator.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_summary_icon import build, fetch_icon, write_tga  # noqa: E402

# Output dir (relative to the repo root), keyed to ns.WeaponTypeIcon's TEX prefix.
OUT_DIR = os.path.join("Warbandeer_Collected", "textures", "weapons")

# basename -> Wowhead-CDN icon name. Basenames match ns.WeaponTypeIcon in
# WeaponViewData.lua; one representative, generic icon per weapon type (no
# expansion/tier flavour, so the column reads as "the weapon", not "a weapon").
ICONS = {
    "axe":       "inv_axe_01",                  # One-Handed Axe (13)
    "sword":     "inv_sword_04",                # One-Handed Sword (14)
    "mace":      "inv_mace_01",                 # One-Handed Mace (15)
    "dagger":    "inv_weapon_shortblade_05",    # Dagger (16)
    "fist":      "inv_weapon_hand_01",          # Fist Weapon (17)
    "wand":      "inv_wand_01",                 # Wand (12)
    "axe2h":     "inv_axe_09",                  # Two-Handed Axe (20)
    "sword2h":   "inv_sword_27",                # Two-Handed Sword (21)
    "mace2h":    "inv_hammer_16",               # Two-Handed Mace (22)
    "staff":     "inv_staff_13",                # Staff (23)
    "polearm":   "inv_spear_04",                # Polearm (24)
    "bow":       "inv_weapon_bow_07",           # Bow (25)
    "gun":       "inv_weapon_rifle_01",         # Gun (26)
    "crossbow":  "inv_weapon_crossbow_01",      # Crossbow (27)
    "warglaive": "inv_weapon_glave_01",         # Warglaive (28) — WoW's historic "glave" spelling
    "shield":    "inv_shield_06",               # Shield (18)
    "offhand":   "inv_misc_orb_02",             # Held In Off-hand (19)
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="regenerate a single basename (e.g. 'sword')")
    ap.add_argument("--out-dir", default=OUT_DIR, help=f"output dir (default {OUT_DIR})")
    ap.add_argument("--preview", help="also write a PNG per icon into this dir")
    ap.add_argument("--floor", type=float, default=0.06)
    ap.add_argument("--gamma", type=float, default=0.85)
    ap.add_argument("--size", type=int, default=64)
    args = ap.parse_args()

    todo = ICONS if not args.only else {args.only: ICONS.get(args.only)}
    if args.only and not todo[args.only]:
        raise SystemExit(f"unknown basename '{args.only}' — known: {', '.join(sorted(ICONS))}")

    os.makedirs(args.out_dir, exist_ok=True)
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)

    from PIL import Image
    failed = []
    for base, name in todo.items():
        out = os.path.join(args.out_dir, f"{base}.tga")
        try:
            img = fetch_icon(name)
            rgba = build(img, "luma", args.floor, args.gamma, False, args.size)
            write_tga(rgba, out)
            if args.preview:
                Image.fromarray(rgba, "RGBA").save(os.path.join(args.preview, f"{base}.png"))
            print(f"+ {base:10s} <- {name}")
        except (Exception, SystemExit) as e:   # HTTPError (404) / placeholder (SystemExit) / decode
            print(f"! {base:10s} <- {name}: {e}")
            failed.append(base)

    if failed:
        print(f"\n{len(failed)} failed (bad icon name?): {', '.join(failed)}")
        return 1
    print(f"\nwrote {len(todo)} icon(s) to {args.out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
