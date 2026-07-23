---@type Warbandeer_Collected
local ns = select(2, ...)

-- Class-restricted enchant illusions (#653) — the shimmer effects only one class can apply.
--
-- This map used to be derived by walking `ns.Sets` for the `kind = "illusion"` group that
-- `data/weapons.lua` added to the ARMOR grid (#516). That group is gone: illusions were never a
-- transmog *set*, they're already browsable in the look builder's Illusions tab (`ns.Illusions`,
-- which renders them with collected marks and a shift-click wanted star), and carrying them as a
-- grid row meant a "Weapons" entry in the armour Category picker for two rows that belonged
-- elsewhere.
--
-- What the group WAS still load-bearing for is exactly this: which class owns which illusion.
-- `ns.Illusions(classID)` needs it to scope the tab to the previewed class — `GetIllusions()` only
-- enumerates the LOGGED-IN character's usable illusions, so a Rogue previewing a Shaman set would
-- otherwise never see the imbues, and would see Poisoned on every class. Losing this map degrades
-- silently (every illusion reads as generic), which is why it moved out ahead of the deletion
-- rather than with it.
--
-- Illusion sourceIDs are hard-coded and confirmed in game (2026-07-18); ids run ~5000+, gathered by
-- dumping `GetIllusions()` on each class. `GetIllusionInfo`/`GetIllusionStrings` resolve them
-- account-wide and cross-class, so an illusion the viewer can't use still renders.

---@class Warbandeer_Collected
---@field RestrictedIllusions table<number, number>  illusion sourceID → the one chrClassID that can apply it
ns.RestrictedIllusions = {
  [5364] = 4,   -- Rogue — Poisoned (the applied weapon-poison shimmer)
  [5869] = 6,   -- Death Knight — Rune of Razorice (runeforge)
  [5872] = 7,   -- Shaman — Flametongue
  [5873] = 7,   -- Shaman — Frostbrand
  [5871] = 7,   -- Shaman — Earthliving
  [5875] = 7,   -- Shaman — Windfury
  [5874] = 7,   -- Shaman — Rockbiter
}
