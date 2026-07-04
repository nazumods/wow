---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo
local GetItemStats = C_Item.GetItemStats
local GetItemQualityByID = C_Item.GetItemQualityByID
local ARTIFACT = Enum.ItemQuality.Artifact

-- Both weapon slots — a Titan's-Grip wielder's two-hander can go in either hand, so
-- it contests both (targeting the weaker), unlike a normal 2H which maps to MainHand.
local TWO_HAND_SLOTS = { "MainHand", "OffHand" }

-- Single-candidate evaluation: given one loose item (a bag/bank/warband/world-quest/
-- vendor candidate) decide whether it upgrades a usable slot for a character, how well
-- its secondaries fit, and reconcile the two-hand ↔ dual-wield weapon comparison. The
-- per-character aggregation (best per slot, held vs warband) lives in upgrade.lua; the
-- external-source surfaces (world quest / vendor / arbitrary item) in upgradesources.lua.
-- Both consume the primitives this file publishes on `ns`.

-- Artifact-quality items (the Heart of Azeroth, Legion artifact weapons) scale by
-- their own systems, so GetDetailedItemLevelInfo reports an inflated effective
-- ilvl — a legacy Heart sitting in a bank otherwise "upgrades" a real neck.  They
-- can never be a current-content upgrade, so drop them outright.  Prefer the quality
-- captured at scan time (data/gearbag.lua, data/bank.lua store it on the candidate):
-- GetItemQualityByID returns nil for an item not in the client cache, which is the
-- common case for an *offline* alt's stored bank/bag gear — so without the stored
-- quality a legacy Heart slips past this gate and gets recommended.  Falls back to the
-- live lookup for candidates without a stored quality (a loaded tooltip item, etc.).
local function isArtifact(cand)
  if not cand or not cand.itemID then return false end
  local q = cand.quality
  if q == nil then q = GetItemQualityByID(cand.itemID) end
  return q == ARTIFACT
end

-- Secondary-stat → GetItemStats key.  Versatility has reported under more than one
-- key across builds, so it's summed over a small candidate set.
local STAT_MOD = {
  crit    = "ITEM_MOD_CRIT_RATING_SHORT",
  haste   = "ITEM_MOD_HASTE_RATING_SHORT",
  mastery = "ITEM_MOD_MASTERY_RATING_SHORT",
}
local VERS_MODS = { "ITEM_MOD_VERSATILITY", "ITEM_MOD_CR_VERSATILITY_DAMAGE_DONE_SHORT" }

-- Primary-stat → GetItemStats key.  ITEM_MOD_AGI_STR_INT_SHORT is the flexible
-- "to your highest stat" primary, which fits every spec.
local PRIMARY_MOD = {
  str = "ITEM_MOD_STRENGTH_SHORT",
  agi = "ITEM_MOD_AGILITY_SHORT",
  int = "ITEM_MOD_INTELLECT_SHORT",
}
local FLEX_PRIMARY = "ITEM_MOD_AGI_STR_INT_SHORT"

-- Reject an item carrying the wrong primary stat for the spec (the gap class
-- proficiency leaves open — e.g. an Intellect dagger is rogue-equippable but
-- useless).  Permissive on the unknowns: passes when the spec's primary is
-- unknown, the item's stats aren't loaded, it carries no primary at all
-- (rings/necks/cloaks/off-hands — universal), it has the flexible all-stat
-- primary, or it carries the wanted one.  Only an item with some OTHER primary
-- and not the wanted one is rejected.
local function primaryFits(link, want)
  if not want or not link or not GetItemStats then return true end
  local stats = GetItemStats(link)
  if not stats then return true end
  if (stats[FLEX_PRIMARY] or 0) > 0 then return true end
  if (stats[PRIMARY_MOD[want]] or 0) > 0 then return true end
  for stat, mod in pairs(PRIMARY_MOD) do
    if stat ~= want and (stats[mod] or 0) > 0 then return false end
  end
  return true
end

---@class UpgradeResult
---@field slot string equipment slot the item would replace (the weaker one for rings/trinkets)
---@field link string candidate item link
---@field ilvl integer candidate item level
---@field ilvlGain integer candidate ilvl − the replaced slot's ilvl
---@field statTag string? "good" (a top-priority secondary) | "off" | nil (unknown)
---@field where string? "held" (own bags/bank) | "warband" (account bank)
---@field betterElsewhere boolean? a warband-bank copy beats the best held upgrade
---@field pairSwap boolean? part of a 2H → (main-hand + off-hand) swap, not a lone-slot upgrade
---@field reqLevel integer? candidate's required character level (from the data layer's scan-time capture; nil when unknown)

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
ns.StatTag = statTag

-- Resolve a candidate's static fields, filling any the data layer didn't store.
local function candInfo(cand)
  local equipLoc, classID, subClassID = cand.equipLoc, cand.classID, cand.subClassID
  if not equipLoc then
    equipLoc, classID, subClassID = ns.api:ClassifyGearItem(cand.itemID)
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
  if isArtifact(cand) then return nil end

  local equipLoc, classID, subClassID = candInfo(cand)
  if not equipLoc then return nil end
  local slots = ns.CompetingSlots(equipLoc)
  if not slots then return nil end
  -- A character holding an off-hand (a shield tank — Prot Paladin/Warrior — or a
  -- dual-wielder — DW Frost DK, Enhancement, Windwalker, rogues) must keep it: a
  -- two-hander is never an upgrade for them, since equipping it drops the off-hand
  -- the spec needs.  The exception is a Titan's-Grip Fury warrior already dual-wielding
  -- two-handers — there a 2H replaces the weaker of the two equipped hands, so it
  -- contests both weapon slots.
  -- Mirror of the two-hand wielder's guard (which rejects a lone 1H/off-hand). Keyed
  -- off the equipped config, so it follows the character's actual build (DW vs 2H Frost,
  -- SMF vs Titan's-Grip Fury) with no spec table; a true single-2H wielder has an empty
  -- off-hand and is handled by resolveTwoHand instead.
  if equipped.OffHand and ns.IsTwoHand(equipLoc, subClassID) then
    if ns.EquippedDualTwoHand(charData) then slots = TWO_HAND_SLOTS else return nil end
  end
  if not ns.CanEquip(charData.classKey, equipLoc, classID, subClassID) then return nil end
  if not primaryFits(cand.link, ns.PrimaryStat(charData)) then return nil end

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
ns.Evaluate = evaluate

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
ns.PickHeadline = pickHeadline

-- equipLoc of an equipped slot.  Cached alt equipment from before equipLoc was
-- stored only carries the link, so derive it on the fly (GetItemInfoInstant is
-- synchronous and works from any link, cached or not).
local function slotEquipLoc(item)
  if not item then return nil end
  if item.equipLoc and item.equipLoc ~= "" then return item.equipLoc end
  if item.link then return (select(4, GetItemInfoInstant(item.link))) end
  return nil
end

-- Weapon subclass of an equipped slot (field 7 of GetItemInfoInstant), derived from
-- the link when the stored item predates the field — mirrors slotEquipLoc.  Needed to
-- tell a one-handed wand from a two-handed gun/crossbow (they share INVTYPE_RANGEDRIGHT).
local function slotSubClass(item)
  if not item then return nil end
  if item.subClassID then return item.subClassID end
  if item.link then return (select(7, GetItemInfoInstant(item.link))) end
  return nil
end

-- Whether the character currently wields a two-hander (so the off-hand is occupied
-- by it, not genuinely empty).
---@param charData Character
---@return boolean
local function equippedTwoHand(charData)
  local eq = charData.equipment and charData.equipment.slots
  return (eq and ns.IsTwoHand(slotEquipLoc(eq.MainHand), slotSubClass(eq.MainHand))) == true
end
ns.EquippedTwoHand = equippedTwoHand

-- Whether the character dual-wields two two-handers (a Titan's-Grip Fury warrior):
-- both weapon slots hold a 2H, so the off-hand isn't a shield/frill a 2H would strand —
-- a 2H upgrades either hand.  Distinguishes TG from a shield/dual-wield off-hand build.
---@param charData Character
---@return boolean
local function equippedDualTwoHand(charData)
  local eq = charData.equipment and charData.equipment.slots
  if not eq or not eq.OffHand then return false end
  return ns.IsTwoHand(slotEquipLoc(eq.MainHand), slotSubClass(eq.MainHand))
     and ns.IsTwoHand(slotEquipLoc(eq.OffHand), slotSubClass(eq.OffHand))
end
ns.EquippedDualTwoHand = equippedDualTwoHand

-- Evaluate one candidate from an *external* source (a world quest, a vendor) the
-- same way the held/warband finder does, then apply the guard a single lone item
-- can't satisfy for a two-hand wielder: with the off-hand occupied by the 2H, a
-- bare off-hand or 1H isn't an upgrade — only another 2H is (mirrors ItemUpgrades'
-- tooltip guard).  Returns (slot, ilvlGain, candIlvl) or nil.  `cand` must carry
-- `equipLoc` for the 2H test (external candidates always store it).
---@param charData Character
---@param cand table GearCandidate-shaped
---@param twoHander boolean whether the character currently wields a two-hander
local function evaluateExternal(charData, cand, twoHander)
  local slot, gain, ilvl = evaluate(charData, cand)
  if not slot then return nil end
  -- A two-hand wielder can't use a lone 1H or off-hand (a single item can't form the
  -- 1H + off-hand pair equipping a 2H would need); only another two-hander is an upgrade.
  -- (A Titan's-Grip dual-2H wielder's 2H candidate was already routed to the weaker hand
  -- by evaluate, and passes this test.)
  if twoHander and not ns.IsTwoHand(cand.equipLoc, cand.subClassID) then return nil end
  return slot, gain, ilvl
end
ns.EvaluateExternal = evaluateExternal

-- Two-hand reconciliation.  A two-hander fills both weapon slots' worth of stats,
-- so the off-hand isn't really empty and a lone off-hand (or lone main-hand 1H)
-- isn't an upgrade — only a *better two-hander*, or a main-hand-1H + off-hand pair
-- whose combined budget beats the 2H, is.  Writes the resolved MainHand/OffHand
-- entries straight into `out` (the per-slot pass skipped them for this character).
local function resolveTwoHand(charData, pools, warband, equipped, ranks, out)
  local mhIlvl = equipped.MainHand.ilvl or 0
  local primary = ns.PrimaryStat(charData)
  -- Titan's Grip: the off-hand also holds a two-hander, so it isn't nominally empty —
  -- a better 2H replaces the weaker of the two hands rather than doubling the main hand.
  local dualTwoHand = ns.EquippedDualTwoHand(charData)

  -- Best equippable candidate per weapon role, held vs warband.
  local acc = { mh1h = {}, mh2h = {}, off = {} }
  local function scan(cands, where)
    local k = where == "warband" and "wb" or "held"
    for _, cand in ipairs(cands) do
      local equipLoc, classID, subClassID = candInfo(cand)
      local role = equipLoc and ns.WeaponRole(equipLoc, subClassID)
      if role and not isArtifact(cand)
          and ns.CanEquip(charData.classKey, equipLoc, classID, subClassID)
          and primaryFits(cand.link, primary) then
        local ilvl = cand.ilvl or (cand.link and GetDetailedItemLevelInfo(cand.link))
        local b = acc[role]
        if ilvl and (not b[k] or ilvl > b[k].ilvl) then
          b[k] = { link = cand.link, ilvl = ilvl, reqLevel = cand.reqLevel }
        end
      end
    end
  end
  scan(pools.bags, "held")
  scan(pools.bank, "held")
  scan(warband, "warband")

  local newMH, mhWhere, mhBetter = pickHeadline(acc.mh2h)

  -- Titan's Grip: both hands hold a 2H (current budget = MH + OH), so a better 2H just
  -- swaps into the weaker hand — no doubled-budget 1H+off-hand pairing.
  if dualTwoHand then
    if not newMH then return end
    local weakSlot, weakIlvl = "MainHand", mhIlvl
    local ohIlvl = equipped.OffHand.ilvl or 0
    if ohIlvl < weakIlvl then weakSlot, weakIlvl = "OffHand", ohIlvl end
    if newMH.ilvl > weakIlvl then
      out[weakSlot] = {
        slot = weakSlot, link = newMH.link, ilvl = newMH.ilvl, ilvlGain = newMH.ilvl - weakIlvl,
        where = mhWhere, betterElsewhere = mhBetter, statTag = statTag(newMH.link, ranks),
        reqLevel = newMH.reqLevel,
      }
    end
    return
  end

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
      reqLevel = newMH.reqLevel,
    }
  elseif pairBudget and pairBudget > cur then
    -- Net budget gain is shared across both hands; show the average per-hand gain on
    -- each mark (≥ 1) so neither off-by-itself piece reads as a loss.
    local gain = math.max(1, math.floor((pairBudget - cur) / 2 + 0.5))
    out.MainHand = {
      slot = "MainHand", link = oneH.link, ilvl = oneH.ilvl, ilvlGain = gain,
      where = mh1hWhere, betterElsewhere = mh1hBetter, statTag = statTag(oneH.link, ranks),
      pairSwap = true, reqLevel = oneH.reqLevel,
    }
    out.OffHand = {
      slot = "OffHand", link = offH.link, ilvl = offH.ilvl, ilvlGain = gain,
      where = offWhere, betterElsewhere = offBetter, statTag = statTag(offH.link, ranks),
      pairSwap = true, reqLevel = offH.reqLevel,
    }
  end
end
ns.ResolveTwoHand = resolveTwoHand
