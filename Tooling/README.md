# Tooling

Reusable development tooling for the suite. **Not an addon** — nothing here is
shipped, listed in a `.toc`, or picked up by the release pipeline (`release.sh`
skips folders without a `.toc`, and `Tooling` is on its `NON_ADDON_DIRS` list).

Check this directory **before writing a new one-off script** — the job may
already be solved here. When a scratchpad script proves reusable, promote it
into this directory with a docstring and an entry in the table below.

| Script | Purpose |
|---|---|
| `make_addon_logo.py` | **Warbandeer-family logo generator** (stag crest style). Reuses the crest base in `assets/` (`warbandeer_base.png`): erases the ribbon's "ADDON NAME" placeholder and resets it with the given text (Arial Bold, tan ink `rgb(191,176,138)` on the ribbon's purple `rgb(81,63,81)`), condensed to fit between the ribbon's fixed flanking arrows. Only the ribbon suffix varies — the "WARBANDEER" title is baked into the base and never changes. `python Tooling/make_addon_logo.py Characters --out <addon>/logo.png` |
| `make_moon_logo.py` | **ShadowsOfUI-family logo generator** (purple moon style). Reuses the moon-art base in `assets/`: inpaints out its word and re-sets the given text in the measured typography (Times New Roman, 94.4% condense, cream ink, cap height ≤79px shrinking to a 235px max width). 400×400 output. `python Tooling/make_moon_logo.py Castbar --out <addon>/logo.png` |
| `make_summary_icon.py` | **Warbandeer Summary-column icon generator.** Turns a game icon into the 64×64 32-bit white-silhouette TGA (muted-tinted at runtime) that every `Warbandeer/views/summaryCol/*.lua` header uses. Fetches the real art from the Wowhead icon CDN by name (`--icon-name inv_…`) or converts a local PNG/JPG (`--src`); alpha from source luminance, RGB forced white, house-format header written byte-for-byte. Pipeline for a new currency column: Wowhead `currency=<ID>` → Warcraft Wiki reports the icon name → run the tool → add the column `.lua` + `.toc` entry. `python Tooling/make_summary_icon.py --icon-name inv_10_gathering_bioluminescentspores_large --out Warbandeer/icons/unalloyedabundance.tga` |
| `make_vault_assets.py` | **Warbandeer Great Vault view assets.** Generates the three 64×64 house-format TGAs the `/wb vault` view needs: `icons/pip-full.tga` (gold filled disc = unlocked slot) and `icons/pip-empty.tga` (muted ring = locked slot), both rendered inline in a table cell via `\|T…\|t` markup, plus `icons/views/vault.tga` (a white vault-door rail glyph, tinted at runtime by `IconStrip` like the other view glyphs). Pip colours are baked in (inline markup can't carry a vertex colour); the glyph is drawn procedurally, so no network / icon-name lookup. `python Tooling/make_vault_assets.py [--preview out/]` |
| `assets/` | Stable base images the generators derive from: `warbandeer_base.png` (stag crest, current Warbandeer-family base) and `shadowsofui_moon_base.png` (= `ShadowsOfUI-Known/logo.png`). Snapshots so the tools keep working identically even if an addon's own logo changes. `warbandeer_flag_base.png` (green photo flag) is the superseded pre-crest base — kept for reference, no longer used by `make_addon_logo.py`. |
| `procedural_flag_logo.py` | Superseded reference: draws the whole flag scene procedurally in PIL (no photo base). Kept for the sampled palette/geometry constants. |

## Logo generation notes

- Two house styles, one generator each: **Warbandeer family** = stag crest
  with a purple ribbon (`make_addon_logo.py`), **ShadowsOfUI family** = purple
  crescent moon + cherry blossoms (`make_moon_logo.py`). Match the family to
  the addon prefix.
- The moon base (`ShadowsOfUI-Known/logo.png`) and XP's logo are 400×400
  CurseForge re-encodes (#347); the 1254×1254 originals live with nazumods.

- `make_addon_logo.py` requires only `pillow` and the Windows font
  **Arial Bold** (`C:/Windows/Fonts/arialbd.ttf`) — it falls back to the
  Arial Bold shipped with macOS when run there. `make_moon_logo.py` also
  needs `numpy`, `opencv-python-headless`, and Times New Roman.
- Output is a 1024×1024 PNG, same as the sibling logos
  (`Warbandeer*/logo.png`), upscaled from the 400×400 crest base.
- The run is deterministic: same text + same library versions → byte-identical
  output.
- The crest's ribbon-text style constants were **measured from the base
  art's own "ADDON NAME" placeholder** (tan ink `rgb(191,176,138)` on ribbon
  purple `rgb(81,63,81)`, 34px target cap-height, erase zone clear of the
  ribbon's fixed flanking arrows) — don't tweak them ad hoc or the family
  stops matching. The "WARBANDEER" title is baked into the base and is never
  regenerated; only the ribbon suffix varies per addon (main `Warbandeer`
  addon uses "Core").
