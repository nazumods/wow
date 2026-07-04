---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api               -- WarbandeerApi (data layer we read)
---@class ShadowsOfUI_UpgradeApi
local Upgrade = ns.UpgradeApi    -- ShadowsOfUI_UpgradeApi (what we publish)
local insert, sort = table.insert, table.sort
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo

-- Upgrades from sources outside a character's own bag/bank/warband pools: active
-- world-quest rewards, bundled faction-quartermaster gear, and an arbitrary item
-- (the tooltip "upgrades <alt>" check).  Each runs candidates through the same
-- evaluation the held/warband finder uses (evaluate.lua), held to the same bar.

---@class WorldQuestUpgrade: UpgradeResult
---@field questID integer source world quest
---@field title string world-quest title
---@field zone string? zone the quest is in
---@field mapID integer? zone uiMapID (for opening the world map to the quest)

---Active world-quest rewards that would upgrade an equipped slot for a character,
---sorted by ilvl gained.  Reads the per-character world-quest reward cache from the
---data layer (`WarbandeerApi:GetWorldQuestRewards`, which already drops expired
---quests) and runs each reward through the same evaluation the held/warband finder
---uses — class/primary proficiency, multi-slot targeting, the two-hand guard, and
---the stat tag — so a WQ reward is held to the same bar as loose gear.  Each result
---carries its quest metadata so the consumer can say "do <title> in <zone>".  Empty
---when the data layer exposes no cache, or nothing qualifies.
---@param charName string
---@return WorldQuestUpgrade[]
function Upgrade:WorldQuestUpgrades(charName)
  local charData = API:GetCharacterData(charName)
  if not charData or not charData.classKey then return {} end
  if not API.GetWorldQuestRewards then return {} end  -- older data layer
  local ranks = ns.StatRanks(charData)
  local twoHander = ns.EquippedTwoHand(charData)
  local out = {}
  for _, rw in ipairs(API:GetWorldQuestRewards(charName)) do
    local slot, gain, ilvl = ns.EvaluateExternal(charData, rw, twoHander)
    if slot then
      insert(out, {
        slot = slot, link = rw.link, ilvl = ilvl, ilvlGain = gain,
        statTag = ns.StatTag(rw.link, ranks),
        questID = rw.questID, title = rw.title, zone = rw.zone, mapID = rw.mapID,
      })
    end
  end
  sort(out, function(a, b) return a.ilvlGain > b.ilvlGain end)
  return out
end

---@class VendorUpgrade: UpgradeResult
---@field quartermaster string vendor NPC to buy the piece from
---@field zone string? zone the quartermaster is in
---@field mapID integer? zone uiMapID (for opening the world map to the quartermaster)
---@field cost string human-readable price ("25 Voidlight Marl")

-- Best equippable option for a vendor-gear entry: keep only the options the
-- character can equip (CanEquip selects the right armour type for body slots and
-- passes every option for armour-type-less slots like necks), then prefer one with
-- a top-priority stat (statTag "good") over an off-stat one — so a neck's two
-- variants collapse to the better-fitting single suggestion.  nil when the
-- character can equip none of the options.
---@param charData Character
---@param entry VendorGearEntry
---@param ranks table<string, integer>?
---@return VendorGearOption?
local function pickVendorOption(charData, entry, ranks)
  local best, bestRank
  for _, opt in ipairs(entry.options) do
    if ns.CanEquip(charData.classKey, entry.equipLoc, entry.classID, opt.subClassID) then
      local rank = ns.StatTag(opt.link, ranks) == "good" and 1 or 2
      if not best or rank < bestRank then best, bestRank = opt, rank end
    end
  end
  return best
end

---Faction-quartermaster gear pieces that would upgrade an equipped slot for a
---character, sorted by ilvl gained.  Reads the bundled `ns.VendorGear` list (fixed
---game data — no data-layer cache) and runs the best equippable option per slot
---through the same evaluation the held/warband/world-quest finders use (class/
---primary proficiency, multi-slot targeting, the two-hand guard, the stat tag).
---A piece gated above the character's level (`entry.reqLevel`) is skipped — it
---isn't a viable upgrade until they ding into it.  Each result carries its purchase
---metadata so the consumer can say "buy <item> from <quartermaster> for <cost>".  A
---character already wearing equal-or-better in every slot yields nothing.
---@param charName string
---@return VendorUpgrade[]
function Upgrade:VendorUpgrades(charName)
  local charData = API:GetCharacterData(charName)
  if not charData or not charData.classKey then return {} end
  local ranks = ns.StatRanks(charData)
  local twoHander = ns.EquippedTwoHand(charData)
  local charLevel = charData.basic and charData.basic.level
  local out = {}
  for _, entry in ipairs(ns.VendorGear or {}) do
    -- Skip a piece the character can't yet equip: a quartermaster item gated above
    -- the character's level isn't a viable upgrade until they ding into it.
    local belowLevel = entry.reqLevel and charLevel and charLevel < entry.reqLevel
    local opt = not belowLevel and pickVendorOption(charData, entry, ranks)
    if opt then
      local cand = {
        link = opt.link, itemID = opt.itemID, ilvl = entry.ilvl,
        equipLoc = entry.equipLoc, classID = entry.classID, subClassID = opt.subClassID,
      }
      local slot, gain, ilvl = ns.EvaluateExternal(charData, cand, twoHander)
      if slot then
        insert(out, {
          slot = slot, link = opt.link, ilvl = ilvl, ilvlGain = gain,
          statTag = ns.StatTag(opt.link, ranks),
          quartermaster = entry.quartermaster, zone = entry.zone,
          mapID = entry.mapID, cost = entry.cost,
        })
      end
    end
  end
  sort(out, function(a, b) return a.ilvlGain > b.ilvlGain end)
  return out
end

---@class ItemUpgradeEntry
---@field name string character name
---@field classKey string
---@field slot string
---@field ilvlGain integer
---@field statTag string?

---Which characters a specific item would upgrade (by item level for a usable
---slot).  Drives the item tooltip — "keep this, it upgrades <alt>".  Sorted by
---ilvl gained.  Returns nil when the link isn't equippable gear.
---
---`boundTo` restricts the check to a single character: pass the holder's name for
---a soulbound item (only useful to whoever it's already bound to), or nil for an
---unbound item (BoE / Warbound until equipped) that any character could use.
---
---`ilvl` is the item's *effective* (context-scaled) level, which the caller should
---supply when known (the tooltip reads it off the displayed "Item Level" line) so
---a downscaled item is measured the same way equipped slots are.  Without it we
---fall back to the link's unscaled `GetDetailedItemLevelInfo`, which over-reports
---an item the player sees downscaled (true 655 shown as 102) and fakes an upgrade.
---@param link string item link or id
---@param boundTo string? character the item is soulbound to, or nil if unbound
---@param ilvl integer? effective item level (preferred over the link's unscaled ilvl)
---@return ItemUpgradeEntry[]?
function Upgrade:ItemUpgrades(link, boundTo, ilvl)
  local itemID, _, _, equipLoc, _, classID, subClassID = GetItemInfoInstant(link)
  if not itemID or not ns.CompetingSlots(equipLoc or "") then return nil end
  local cand = {
    link = link, itemID = itemID, equipLoc = equipLoc, classID = classID,
    subClassID = subClassID, ilvl = ilvl or GetDetailedItemLevelInfo(link),
  }
  -- Soulbound → only the holder; unbound → every character.
  local chars
  if boundTo then
    local c = API:GetCharacterData(boundTo)
    chars = c and { c } or {}
  else
    chars = API:GetAllCharacters()
  end
  local out = {}
  for _, charData in ipairs(chars) do
    local slot, gain = ns.Evaluate(charData, cand)
    -- A single item can't establish the main-hand + off-hand pair a 2H wielder would
    -- need, so a lone off-hand or 1H isn't an upgrade for them — only a 2H is.  (A
    -- Titan's-Grip dual-2H wielder's 2H was already routed to the weaker hand by Evaluate.)
    if slot and ns.EquippedTwoHand(charData) and not ns.IsTwoHand(cand.equipLoc, cand.subClassID) then
      slot = nil
    end
    if slot then
      insert(out, {
        name = charData.name, classKey = charData.classKey, slot = slot, ilvlGain = gain,
        statTag = ns.StatTag(link, ns.StatRanks(charData)),
      })
    end
  end
  if #out == 0 then return nil end
  sort(out, function(a, b) return a.ilvlGain > b.ilvlGain end)
  return out
end
