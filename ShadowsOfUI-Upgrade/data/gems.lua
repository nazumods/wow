---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- The **fallback** recommended gem, used only when ClassCodex isn't installed (its
-- per-spec primary gem is preferred — see `enhance.lua`). ClassCodex's primary gem is
-- role-specific (a different "diamond" per spec), which we don't hand-maintain; instead
-- the fallback offers a **secondary-stat** gem matched to the character's top stat (any
-- class can socket any of these), mirroring how the enchant fallback picks ring variants.
--
-- `byStat` maps a secondary stat → the cut-gem **itemId** (names resolve live via
-- GetItemInfo at the surface). **Regenerate each season** like `enchants`/`vendorgear`.
-- Midnight (12.0.x) "Flawless" cut gems (itemIds from ClassCodex's gem data) — the
-- adjective encodes the stat (Quick=Haste, Deadly=Crit, Masterful=Mastery,
-- Versatile=Versatility); confirm each gem's stat in-game when regenerating.
---@class GemFallback
---@field byStat table<string, number>  secondary-stat token → cut-gem itemId

---@type GemFallback
ns.Gems = {
  byStat = {
    haste       = 240900,  -- Flawless Quick Amethyst
    crit        = 240898,  -- Flawless Deadly Amethyst
    mastery     = 240892,  -- Flawless Masterful Peridot
    versatility = 240894,  -- Flawless Versatile Peridot
  },
}
