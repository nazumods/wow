# ShadowsOfUI-WarbandInventory

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** Warbandeer · **SavedVars:** none · **Commands:** `/swinv <itemID|link>` (dev/find dump) · **API:** reads `WarbandeerApi`

Headless tooltip addon. Adds a "Warband stock" block to item tooltips listing how many of
the item each character holds (bags + personal bank), the shared warband bank, and each
guild bank, with a grand total. Assignment-form init (`local ns = LibNAddOn(...)`); no
LibNUI, no DB. Surfaces data only — all counting lives in Warbandeer_Characters.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + `ns.ColorName(name, classKey)` (wrap a character name in its class colour via `ns.Colors`, PascalCase keys matching `Character.classKey`). |
| `tooltip.lua` | `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item)` hook → `WarbandeerApi:GetItemCounts(data.id)` → renders the block. `IsShiftKeyDown()` suppresses it. Manual `/swinv` dev/find command. |

## Rendering (`tooltip.lua`)

- Calls `API:GetItemCounts(itemID)` (`ns.api` = `WarbandeerApi`, bound via `X-NUI-API`);
  returns nil when nothing is held → no block.
- **Header**: a plain `AddLine("Warband stock")` label (the total moved to the bottom).
- **Per character**: one `AddDoubleLine` — `charLabel(e)` (class-coloured name, left, with a
  ` (Realm)` suffix when the entry's `realm` is set — i.e. a different realm than the current
  character) + `total` then a muted inline source breakdown `(Bags: B, Bank: K)` (right,
  `sources()`, non-zero locations only), matching Altoholic's `Name  N (Bags: …)` style.
  Capped at `MAX_CHARS` (16); past it, the first 15 then a muted
  `+N more — /swinv <itemID> for the full list` hint (render takes the itemID so the hint
  names it). The report's `characters` list is already sorted by total desc, name asc.
- **Warband bank** (if > 0) and each **guild bank**: muted left label + count.
- **Footer**: `AddDoubleLine("Total owned", report.total)` at the very bottom — the grand
  total across every source (Altoholic's "Total owned").
- Counts run through `BreakUpLargeNumbers` (`abbr`).

## `/swinv <itemID | item link>`

Resolves an itemID from `item:(%d+)` or a bare number, prints the full breakdown to chat
(`name — N total`, then per-character `total (bags B, bank K)`, warband bank, guilds).
A testing aid (tooltip text can't be copied) and a "where is my…?" lookup. `SLASH_SUI_WINV1`.

## Gotchas

- **Shift hides the block, and that's load-bearing for freshness, not just clutter.** Shift
  toggles Blizzard's item comparison, which re-renders the tooltip — so the post-call fires
  again and the early `IsShiftKeyDown()` return takes effect immediately on press/release.
- **Counts are last-seen** (see Warbandeer_Characters): a character's bag map only updates
  while it's logged in; bank/guild counts update on bank open. Empty until alts are seen.
- **The hovered copy is included** in its character's count (the count is "total held",
  Altoholic-style), so an item in your bag reads as ≥1 for the current character.
- **No `X-Curse-Project-ID` yet** — added when the CurseForge project is created.
