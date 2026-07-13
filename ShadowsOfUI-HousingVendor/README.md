# ShadowsOfUI-HousingVendor

Tells you, **at a glance**, which housing decor you already own and which is worth buying — right on the item icons, whether you're **shopping at a vendor** or **sorting your bags and bank**, without hovering.

Housing decor vendors sell a long grid of furniture, and the item tooltip already buries the useful bits — how many you own, and whether a piece grants a one-time **House XP bonus** the first time you collect it — one hover at a time. The same questions come up over a decor item sitting in your bags: *do I already have this in storage, or is adding it a waste?* This addon surfaces both directly on the icon:

- **Storage count** — the number you have **in storage** (ready to place) is stamped on the bottom-left corner of every decor icon you already own. A greyed-out **0** means you own it but every copy is already placed.
- **First-acquisition star** — a gold **★** on the top-left corner marks decor that awards a **first-time House XP bonus** and that you **don't own yet**. That's the stuff worth grabbing for the bonus.
- **Owned check** *(off by default)* — a green check on the top-left for decor you already own, for anyone who turns the storage count off.

Everything else the icon draws — price, affordability, stack counts, Blizzard's own red/grey cues — is left untouched. Non-decor items are ignored entirely.

## Where the overlays appear

- **Merchant** window (always on).
- **Bags** and **Bank** — the default Blizzard frames.
- **Bagnon / Bagnonium** bag buttons, if you use that bag replacement.

Each surface can be turned off independently (see Settings).

## Settings

In **Options → AddOns → Shadows of UI → Housing Vendor**. The three **indicators** control *what* is drawn (on every surface); the **surface** toggles control *where*.

| Setting | Default | Effect |
|---|---|---|
| Storage count | On | Stamp the in-storage owned count on decor you own |
| First-acquisition star | On | Gold star on unowned decor that grants a first-time House XP bonus |
| Owned check | Off | Green check on decor you already own |
| In bags | On | Show the indicators on decor in your bags |
| In bank | On | Show the indicators on decor in your bank |
| In Bagnon | On | Show the indicators on Bagnon / Bagnonium bag buttons |

## Commands

- `/shvendor` — print the current indicator and surface settings.
- `/shvendor itemtest` — dump the resolved owned/stored/bonus values for the item currently under your cursor (a diagnostic aid you won't normally need).

## Changelog

A **Changelog** button in this addon's settings opens its release history in a scrollable, copyable window.

## Dependencies

- **LibNAddOn**
- **Bagnon / Bagnonium** *(optional)* — only needed for the Bagnon overlay.

## Notes

- Overlays are drawn on housing-decor items only, on the Merchant window's Buy tab and on bag/bank slots.
- Ownership data comes from the game's housing catalog, which finishes loading a moment after you log in — the counts fill in on their own and refresh whenever your storage changes.
- If you also run **Collectible Tints** (ShadowsOfUI-Collectibles), it reuses this addon's decor detection rather than computing owned-state a second time.
- No window, and no saved data beyond the indicator and surface toggles.
