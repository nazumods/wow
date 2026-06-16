---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- Equipment slots that take a permanent enchant in the current expansion.
-- **VERIFY each expansion** — the enchantable set drifts. Midnight (12.0.x) moved it
-- noticeably: Head and Shoulder are enchantable again, while Cloak (Back) and Wrist are
-- NOT — the Enchanting profession has no recipe for them (a full recipe-tree dump,
-- learned and unlearned, carries none). Legs stay in: their enchant is a Tailoring /
-- Leatherworking spellthread / armour kit, not an Enchanting recipe, so the Enchanting
-- tree says nothing about them. The off-hand is intentionally absent here: it's
-- enchantable only when it holds a weapon (not a shield / frill / holdable), so
-- enhance.lua decides it per equipped item rather than statically.
---@type table<string, boolean>
ns.EnchantableSlots = {
  Head     = true,
  Shoulder = true,
  Chest    = true,
  Legs     = true,
  Feet     = true,
  Finger1  = true,
  Finger2  = true,
  MainHand = true,
}
