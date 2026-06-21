# ShadowsOfUI-Reputations

Shows **which of your characters stand where with a faction**, account-wide — so you can see
at a glance who's still grinding a reputation and who's already Exalted.

The cross-alt standings appear in two places:

- **On the Reputation tab** (character pane → Reputation): hover any faction and the tooltip
  gains a "Standing across your warband:" block — one line per character, highest standing
  first, the value **green when maxed** and marked **Paragon** when earning paragon rewards.
  Account-wide factions (shared across your whole warband) show a single **Warband Wide** line
  instead of repeating the same standing for every character.
- **On faction-tied item tooltips**: hover a commendation, reputation token, tabard or
  paragon cache and the same block appears — so you can tell at a glance **which alt to mail
  that rep token to** (one that isn't Exalted yet).

`/sreps <factionID or faction name>` prints the same breakdown to chat — a testing aid and a
quick "who's exalted with X?" lookup.

## Requirements

- **LibNAddOn**
- **Warbandeer_Characters** — provides the per-character reputation data this addon reads
  (captured automatically each login and whenever your reputation changes).
- **Warbandeer** *(optional)* — not required; listed only for sensible load order.

## Notes

- Standings are **last-seen**: a character's reputations refresh while it's logged in, so a
  freshly installed setup fills in as you log each alt in once. (`/wbc missing` lists
  characters not yet captured.)
- The item-tooltip match is **by faction name** appearing in the tooltip text — robust within
  one client/locale, but an item that doesn't name its faction won't trigger the block.
- There is no window and no saved data of its own — it reads Warbandeer_Characters' cache.
