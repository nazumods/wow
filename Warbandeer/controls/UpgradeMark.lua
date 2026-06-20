---@class Warbandeer
local ns = select(2, ...)

-- Optional integration with ShadowsOfUI-Upgrade (OptionalDep).  When that addon
-- is loaded it publishes ShadowsOfUI_UpgradeApi; these helpers turn a slot's
-- available upgrade into a cell glyph + a hover line.  Everything degrades to
-- "no marker" when the addon is absent, so the views never hard-depend on it.

-- ▲ tinted green when the upgrade is held in the character's own bags/bank, gold
-- when the best copy is in the warband bank (your "better elsewhere" case).
local HELD_ARROW    = " |cff40c040\226\150\178|r"
local WARBAND_ARROW = " |cffe6cc80\226\150\178|r"

---Best available upgrade for a character's slot, or nil (also nil when the
---upgrade addon isn't loaded).
---@param charName string
---@param slot string
---@return UpgradeResult?
local function slotUpgrade(charName, slot)
  local api = ShadowsOfUI_UpgradeApi
  return api and api:SlotUpgrade(charName, slot) or nil
end

---Cell-text glyph for a slot's available upgrade, or "" when none.
---@param charName string
---@param slot string
---@return string
function ns.UpgradeMark(charName, slot)
  local r = slotUpgrade(charName, slot)
  if not r then return "" end
  return (r.where == "warband" or r.betterElsewhere) and WARBAND_ARROW or HELD_ARROW
end

---Suggested upgrade item for a slot, for display under the equipped item: its
---link (carries name + rarity colour), the item-level gain over what's equipped,
---and whether the best copy lives in the warband bank (gold) vs the character's
---own bags/bank (green). Returns nil when there's no upgrade (or the addon's gone).
---@param charName string
---@param slot string
---@return string? link, integer? ilvlGain, boolean? warband
function ns.UpgradeSuggestion(charName, slot)
  local r = slotUpgrade(charName, slot)
  if not r then return nil end
  return r.link, r.ilvlGain, (r.where == "warband" or r.betterElsewhere) or false
end

---Set of equipped slots missing a permanent enchant for a character, keyed by
---slot name (`{ Back = true, Finger1 = true, ... }`). Empty when the character is
---fully enchanted, or when the upgrade addon isn't loaded. Built once per Detail
---render so the per-slot lookup in `_showGear` is a cheap table read.
---@param charName string
---@return table<string, boolean>
function ns.MissingEnchantSlots(charName)
  local set = {}
  local api = ShadowsOfUI_UpgradeApi
  if not api then return set end
  for _, e in ipairs(api:MissingEnchants(charName)) do
    set[e.slot] = true
  end
  return set
end

-- Resolve an EnchantSuggestion to a display name (live, so nothing is hardcoded): a
-- ClassCodex pick carries its own `name`; a bundled recipe resolves via GetSpellName;
-- an item id falls back to GetItemInfo. The Bars views use the same GetSpellName shim.
local GetSpellName = (C_Spell and C_Spell.GetSpellName) or _G.GetSpellInfo
local GetItemName = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

-- Resolve an EnchantSuggestion descriptor (shared by the enchant + gem recommenders).
---@param s table?
---@return string?
local function suggestionName(s)
  if not s then return nil end
  if s.name then return s.name end
  if s.kind == "spell" and GetSpellName then return GetSpellName(s.id) end
  if s.kind == "item" and s.id and GetItemName then return (GetItemName(s.id)) end
  return nil
end

-- Per-item accepted wrong-enchants (account-wide), keyed by "<itemID>:<enchantID>" so that
-- accepting a wrong enchant is specific to *that* enchant on *that* item — re-enchanting it
-- differently re-flags. Stored in WarbandeerDB.ignoredEnchants.
local function ignoreKey(itemID, enchantID)
  if not (itemID and enchantID) then return nil end
  return ("%d:%d"):format(itemID, enchantID)
end

---Whether the (wrong) enchant on a specific item is on the user's accept list.
---@param itemID integer?
---@param enchantID integer?
---@return boolean
function ns.IsEnchantIgnored(itemID, enchantID)
  local key = ignoreKey(itemID, enchantID)
  return key ~= nil and ns.db.ignoredEnchants[key] == true
end

---Toggle whether a specific item's current (wrong) enchant is accepted; returns the new state.
---@param itemID integer?
---@param enchantID integer?
---@return boolean ignored
function ns.ToggleEnchantIgnore(itemID, enchantID)
  local key = ignoreKey(itemID, enchantID)
  if not key then return false end
  local store = ns.db.ignoredEnchants
  store[key] = (not store[key]) or nil
  return store[key] == true
end

---Equipped slots whose applied enchant differs from the recommendation, keyed by slot →
---`{ applied, recommended, itemID, enchantID }`. This is the RAW set (does not filter the
---accept list — the view decides per slot via `ns.IsEnchantIgnored`, so it can still offer
---an un-accept on an already-accepted row). Empty when none, or the upgrade addon's absent.
---@param charName string
---@return table<string, {applied:string, recommended:string, itemID:integer?, enchantID:integer}>
function ns.EnchantMismatchSlots(charName)
  local set = {}
  local api = ShadowsOfUI_UpgradeApi
  if not (api and api.EnchantMismatches) then return set end
  for _, e in ipairs(api:EnchantMismatches(charName)) do
    set[e.slot] = { applied = e.applied, recommended = e.recommended, itemID = e.itemID, enchantID = e.enchantID }
  end
  return set
end

---Recommended enchant name for a character's slot — the enchant they should apply (per
---spec from ClassCodex when installed, else our bundled stat pick) — or nil when there's
---none (or the upgrade addon isn't loaded).
---@param charName string
---@param slot string
---@return string?
function ns.RecommendedEnchant(charName, slot)
  local api = ShadowsOfUI_UpgradeApi
  if not (api and api.RecommendedEnchant) then return nil end
  return suggestionName(api:RecommendedEnchant(charName, slot))
end

---Raw recommended-enchant suggestion for a slot — the EnchantSuggestion descriptor
---(`{ kind="item"|"spell", id, name?, stat? }`) rather than just its name, so a consumer
---can render the actual enchant's item/spell tooltip (what it grants). nil when there's no
---recommendation (or the upgrade addon isn't loaded). Sibling of ns.RecommendedEnchant.
---@param charName string
---@param slot string
---@return table?
function ns.RecommendedEnchantInfo(charName, slot)
  local api = ShadowsOfUI_UpgradeApi
  if not (api and api.RecommendedEnchant) then return nil end
  return api:RecommendedEnchant(charName, slot)
end

---Set of equipped slots with one or more empty gem sockets for a character, keyed by
---slot name → socket count (`{ Neck = 1, Finger1 = 1, ... }`). Empty when none, or the
---upgrade addon isn't loaded. Built once per Detail render (warband-wide from the stored
---socket count) — the gem sibling of ns.MissingEnchantSlots.
---@param charName string
---@return table<string, integer>
function ns.EmptySocketSlots(charName)
  local set = {}
  local api = ShadowsOfUI_UpgradeApi
  if not (api and api.MissingGems) then return set end
  for _, e in ipairs(api:MissingGems(charName)) do
    set[e.slot] = e.sockets
  end
  return set
end

---Recommended gem names for a character: the **primary** (the unique-equipped "diamond" — one
---per character) and a **secondary** (fills every other socket). Per spec from ClassCodex when
---installed, else just the bundled top-stat secondary. Either may be nil.
---@param charName string
---@return string? primary, string? secondary
function ns.RecommendedGems(charName)
  local api = ShadowsOfUI_UpgradeApi
  if not (api and api.RecommendedGems) then return nil, nil end
  local primary, secondary = api:RecommendedGems(charName)
  return suggestionName(primary), suggestionName(secondary)
end

---Raw recommended-gem suggestions for a character — the `primary`/`secondary`
---EnchantSuggestion descriptors (`{ kind="item", id, name? }`) rather than their names, so a
---consumer can render the gem's own item tooltip (its stat bonus = what it does). Either may
---be nil. Sibling of ns.RecommendedGems (the name form).
---@param charName string
---@return table? primary, table? secondary
function ns.RecommendedGemsInfo(charName)
  local api = ShadowsOfUI_UpgradeApi
  if not (api and api.RecommendedGems) then return nil, nil end
  return api:RecommendedGems(charName)
end

---One-line hover description of a slot's available upgrade, or nil when none.
---@param charName string
---@param slot string
---@return string?
function ns.UpgradeTip(charName, slot)
  local r = slotUpgrade(charName, slot)
  if not r then return nil end
  local where = r.betterElsewhere and "better one in warband bank"
    or (r.where == "warband" and "in warband bank" or "held in bags/bank")
  local stat = r.statTag and (", " .. r.statTag .. " stats") or ""
  local swap = r.pairSwap and " — main-hand + off-hand vs 2H" or ""
  return ("Upgrade: +%d ilvl (%s%s)%s"):format(r.ilvlGain, where, stat, swap)
end
