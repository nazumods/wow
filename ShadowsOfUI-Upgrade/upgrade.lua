---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api               -- WarbandeerApi (data layer we read)
---@class ShadowsOfUI_UpgradeApi
local Upgrade = ns.UpgradeApi    -- ShadowsOfUI_UpgradeApi (what we publish)
local insert, sort = table.insert, table.sort
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo
local GetItemStats = C_Item.GetItemStats
local GetTime = GetTime

-- Secondary-stat → GetItemStats key.  Versatility has reported under more than one
-- key across builds, so it's summed over a small candidate set.
local STAT_MOD = {
  crit    = "ITEM_MOD_CRIT_RATING_SHORT",
  haste   = "ITEM_MOD_HASTE_RATING_SHORT",
  mastery = "ITEM_MOD_MASTERY_RATING_SHORT",
}
local VERS_MODS = { "ITEM_MOD_VERSATILITY", "ITEM_MOD_CR_VERSATILITY_DAMAGE_DONE_SHORT" }

---@class UpgradeResult
---@field slot string equipment slot the item would replace (the weaker one for rings/trinkets)
---@field link string candidate item link
---@field ilvl integer candidate item level
---@field ilvlGain integer candidate ilvl − the replaced slot's ilvl
---@field statTag string? "good" (a top-priority secondary) | "off" | nil (unknown)
---@field where string? "held" (own bags/bank) | "warband" (account bank)
---@field betterElsewhere boolean? a warband-bank copy beats the best held upgrade
---@field pairSwap boolean? part of a 2H → (main-hand + off-hand) swap, not a lone-slot upgrade

-- Tag how well an item's secondaries fit the spec priority: "good" if it carries
-- a top-tier stat, else "off".  nil when stats or priority aren't known yet.
local function statTag(link, ranks)
  if not ranks or not link or not GetItemStats then return nil end
  local stats = GetItemStats(link)
  if not stats then return nil end
  local best
  for key, mod in pairs(STAT_MOD) do
    if (stats[mod] or 0) > 0 and ranks[key] and (not best or ranks[key] < best) then best = ranks[key] end
  end
  local vers = 0
  for _, m in ipairs(VERS_MODS) do vers = vers + (stats[m] or 0) end
  if vers > 0 and ranks.versatility and (not best or ranks.versatility < best) then best = ranks.versatility end
  if not best then return nil end
  return best == 1 and "good" or "off"
end

-- Resolve a candidate's static fields, filling any the data layer didn't store.
local function candInfo(cand)
  local equipLoc, classID, subClassID = cand.equipLoc, cand.classID, cand.subClassID
  if not equipLoc then
    equipLoc, classID, subClassID = API:ClassifyGearItem(cand.itemID)
  end
  return equipLoc, classID, subClassID
end

-- Evaluate one candidate against a character: returns (slot, ilvlGain, candIlvl)
-- when it's an ilvl upgrade for a usable slot, else nil.  For multi-slot items
-- (rings/trinkets) it targets the WEAKER equipped slot — the one you'd replace.
local function evaluate(charData, cand)
  -- Without a scanned equipment set we can't tell an upgrade from a naked slot,
  -- so don't guess (else every warband item "upgrades" a barely-logged alt).
  local equipped = charData.equipment and charData.equipment.slots
  if not equipped then return nil end

  local equipLoc, classID, subClassID = candInfo(cand)
  if not equipLoc then return nil end
  local slots = ns.CompetingSlots(equipLoc)
  if not slots then return nil end
  if not ns.CanEquip(charData.classKey, equipLoc, classID, subClassID) then return nil end

  local candIlvl = cand.ilvl or (cand.link and GetDetailedItemLevelInfo(cand.link))
  if not candIlvl then return nil end

  local worstSlot, worstIlvl
  for _, slot in ipairs(slots) do
    local cur = equipped[slot]
    local ilvl = (cur and cur.ilvl) or 0 -- an empty slot is always an upgrade
    if not worstIlvl or ilvl < worstIlvl then worstSlot, worstIlvl = slot, ilvl end
  end
  if candIlvl <= worstIlvl then return nil end
  return worstSlot, candIlvl - worstIlvl, candIlvl
end

-- Prefer a held copy; a strictly-higher warband copy wins and flags betterElsewhere.
-- `b` carries `held` / `wb` candidate tables (each at least { link, ilvl }).
---@return table? pick, string? where, boolean? betterElsewhere
local function pickHeadline(b)
  local held, wb = b.held, b.wb
  if held and wb then
    if wb.ilvl > held.ilvl then return wb, "warband", true end
    return held, "held", false
  end
  if held then return held, "held", false end
  if wb then return wb, "warband", false end
  return nil
end

-- equipLoc of an equipped slot.  Cached alt equipment from before equipLoc was
-- stored only carries the link, so derive it on the fly (GetItemInfoInstant is
-- synchronous and works from any link, cached or not).
local function slotEquipLoc(item)
  if not item then return nil end
  if item.equipLoc and item.equipLoc ~= "" then return item.equipLoc end
  if item.link then return (select(4, GetItemInfoInstant(item.link))) end
  return nil
end

-- Whether the character currently wields a two-hander (so the off-hand is occupied
-- by it, not genuinely empty).
---@param charData Character
---@return boolean
local function equippedTwoHand(charData)
  local eq = charData.equipment and charData.equipment.slots
  return (eq and ns.IsTwoHand(slotEquipLoc(eq.MainHand))) == true
end

-- Two-hand reconciliation.  A two-hander fills both weapon slots' worth of stats,
-- so the off-hand isn't really empty and a lone off-hand (or lone main-hand 1H)
-- isn't an upgrade — only a *better two-hander*, or a main-hand-1H + off-hand pair
-- whose combined budget beats the 2H, is.  Writes the resolved MainHand/OffHand
-- entries straight into `out` (the per-slot pass skipped them for this character).
local function resolveTwoHand(charData, pools, warband, equipped, ranks, out)
  local mhIlvl = equipped.MainHand.ilvl or 0

  -- Best equippable candidate per weapon role, held vs warband.
  local acc = { mh1h = {}, mh2h = {}, off = {} }
  local function scan(cands, where)
    local k = where == "warband" and "wb" or "held"
    for _, cand in ipairs(cands) do
      local equipLoc, classID, subClassID = candInfo(cand)
      local role = equipLoc and ns.WeaponRole(equipLoc)
      if role and ns.CanEquip(charData.classKey, equipLoc, classID, subClassID) then
        local ilvl = cand.ilvl or (cand.link and GetDetailedItemLevelInfo(cand.link))
        local b = acc[role]
        if ilvl and (not b[k] or ilvl > b[k].ilvl) then b[k] = { link = cand.link, ilvl = ilvl } end
      end
    end
  end
  scan(pools.bags, "held")
  scan(pools.bank, "held")
  scan(warband, "warband")

  local newMH, mhWhere, mhBetter = pickHeadline(acc.mh2h)
  local oneH, mh1hWhere, mh1hBetter = pickHeadline(acc.mh1h)
  local offH, offWhere, offBetter = pickHeadline(acc.off)

  -- Score configs in a shared "doubled ilvl" budget so a 2H (one item ≈ two hands)
  -- compares to a 1H + off-hand pair.  Current setup = 2 × the equipped 2H ilvl.
  local cur = 2 * mhIlvl
  local twoBudget  = newMH and 2 * newMH.ilvl or nil               -- swap to a better 2H
  local pairBudget = (oneH and offH) and (oneH.ilvl + offH.ilvl) or nil  -- 2H → 1H + off-hand

  if twoBudget and twoBudget > cur and (not pairBudget or twoBudget >= pairBudget) then
    out.MainHand = {
      slot = "MainHand", link = newMH.link, ilvl = newMH.ilvl, ilvlGain = newMH.ilvl - mhIlvl,
      where = mhWhere, betterElsewhere = mhBetter, statTag = statTag(newMH.link, ranks),
    }
  elseif pairBudget and pairBudget > cur then
    -- Net budget gain is shared across both hands; show the average per-hand gain on
    -- each mark (≥ 1) so neither off-by-itself piece reads as a loss.
    local gain = math.max(1, math.floor((pairBudget - cur) / 2 + 0.5))
    out.MainHand = {
      slot = "MainHand", link = oneH.link, ilvl = oneH.ilvl, ilvlGain = gain,
      where = mh1hWhere, betterElsewhere = mh1hBetter, statTag = statTag(oneH.link, ranks),
      pairSwap = true,
    }
    out.OffHand = {
      slot = "OffHand", link = offH.link, ilvl = offH.ilvl, ilvlGain = gain,
      where = offWhere, betterElsewhere = offBetter, statTag = statTag(offH.link, ranks),
      pairSwap = true,
    }
  end
end

-- Best upgrade per slot for a character across its held + warband pools.
---@param charData Character
---@return table<string, UpgradeResult>
local function computeUpgrades(charData)
  if not charData or not charData.classKey then return {} end
  local ranks = ns.StatRanks(charData)
  local pools = API:GetCharacterGearCandidates(charData.name)
  local warband = API:GetWarbandBankGear()
  local equipped = charData.equipment and charData.equipment.slots
  local out = {}

  -- A two-hander leaves the off-hand nominally empty; route both weapon slots through
  -- resolveTwoHand instead of the per-slot pass, so a bare off-hand (or 1H) doesn't
  -- masquerade as an upgrade against the empty slot.
  local twoHander = equippedTwoHand(charData)

  -- Record the best (highest ilvl) candidate for each slot, per source.
  local function consider(cand, where)
    local slot, gain, ilvl = evaluate(charData, cand)
    if not slot then return end
    if twoHander and (slot == "MainHand" or slot == "OffHand") then return end
    local r = out[slot]
    if not r then r = {} ; out[slot] = r end
    local k = where == "warband" and "wb" or "held"
    if not r[k] or ilvl > r[k].ilvl then r[k] = { link = cand.link, ilvl = ilvl, gain = gain } end
  end

  for _, c in ipairs(pools.bags) do consider(c, "held") end
  for _, c in ipairs(pools.bank) do consider(c, "held") end
  for _, c in ipairs(warband) do consider(c, "warband") end

  -- Resolve each slot's headline: prefer held; flag a strictly-better warband copy.
  for slot, r in pairs(out) do
    local pick, where, better = pickHeadline(r)
    out[slot] = {
      slot = slot, link = pick.link, ilvl = pick.ilvl, ilvlGain = pick.gain,
      where = where, betterElsewhere = better, statTag = statTag(pick.link, ranks),
    }
  end

  if twoHander then resolveTwoHand(charData, pools, warband, equipped, ranks, out) end
  return out
end

-- Short-lived memo so a single view build — GearView calls SlotUpgrade once per
-- slot (16×/character) — recomputes a character's upgrades only once.  The
-- underlying data changes rarely (bank/bag/equipment scans), so a ~2s TTL is
-- invisible and there's no invalidation bookkeeping.
local CACHE_TTL = 2
local cache = {}
local function cachedUpgrades(charData)
  if not charData then return {} end
  local now = GetTime()
  local c = cache[charData.name]
  if c and (now - c.t) < CACHE_TTL then return c.result end
  local result = computeUpgrades(charData)
  cache[charData.name] = { t = now, result = result }
  return result
end

-------------------------------------------------------------------------------
-- Published API (ShadowsOfUI_UpgradeApi) — consumed by Warbandeer (OptionalDep).
-------------------------------------------------------------------------------

---Best available upgrade for a single equipment slot, or nil.
---@param charName string
---@param slot string equipment slot name (Head, Finger1, MainHand, …)
---@return UpgradeResult?
function Upgrade:SlotUpgrade(charName, slot)
  return cachedUpgrades(API:GetCharacterData(charName))[slot]
end

---All slots with an available upgrade for a character, sorted by ilvl gained.
---@param charName string
---@return UpgradeResult[]
function Upgrade:CharacterUpgrades(charName)
  local list = {}
  for _, r in pairs(cachedUpgrades(API:GetCharacterData(charName))) do insert(list, r) end
  sort(list, function(a, b) return a.ilvlGain > b.ilvlGain end)
  return list
end

---How many slots a character has an available upgrade for.
---@param charName string
---@return integer
function Upgrade:CharacterUpgradeCount(charName)
  local n = 0
  for _ in pairs(cachedUpgrades(API:GetCharacterData(charName))) do n = n + 1 end
  return n
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
---@param link string item link or id
---@param boundTo string? character the item is soulbound to, or nil if unbound
---@return ItemUpgradeEntry[]?
function Upgrade:ItemUpgrades(link, boundTo)
  local itemID, _, _, equipLoc, _, classID, subClassID = GetItemInfoInstant(link)
  if not itemID or not ns.CompetingSlots(equipLoc or "") then return nil end
  local cand = {
    link = link, itemID = itemID, equipLoc = equipLoc, classID = classID,
    subClassID = subClassID, ilvl = GetDetailedItemLevelInfo(link),
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
    local slot, gain = evaluate(charData, cand)
    -- A single item can't establish the main-hand + off-hand pair a 2H wielder would
    -- need, so a lone off-hand or 1H isn't an upgrade for them — only a 2H is.
    if slot and equippedTwoHand(charData)
        and (slot == "OffHand" or (slot == "MainHand" and not ns.IsTwoHand(cand.equipLoc))) then
      slot = nil
    end
    if slot then
      insert(out, {
        name = charData.name, classKey = charData.classKey, slot = slot, ilvlGain = gain,
        statTag = statTag(link, ns.StatRanks(charData)),
      })
    end
  end
  if #out == 0 then return nil end
  sort(out, function(a, b) return a.ilvlGain > b.ilvlGain end)
  return out
end
