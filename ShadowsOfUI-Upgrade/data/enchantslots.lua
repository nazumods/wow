---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- Equipment slots that take a permanent enchant in the current expansion.
-- **VERIFY each expansion** — the enchantable set drifts (rings became enchantable
-- in The War Within, bracers gained "chants", etc.). The off-hand is intentionally
-- absent: it's enchantable only when it holds a weapon (not a shield / frill /
-- holdable), so enhance.lua decides it per equipped item rather than statically.
---@type table<string, boolean>
ns.EnchantableSlots = {
  Back     = true,
  Chest    = true,
  Wrist    = true,
  Legs     = true,
  Feet     = true,
  Finger1  = true,
  Finger2  = true,
  MainHand = true,
}
