---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api               -- WarbandeerApi (data layer we read)
---@class ShadowsOfUI_UpgradeApi
local Upgrade = ns.UpgradeApi    -- ShadowsOfUI_UpgradeApi (what we publish)
local insert, sort = table.insert, table.sort
local GetTime = GetTime

-- Per-character aggregation: collect the best upgrade per equipment slot across a
-- character's held (bags/bank) + warband-bank pools, reconciling weapons through the
-- two-hand logic.  Single-candidate evaluation lives in evaluate.lua; the external
-- sources (world quest / vendor / arbitrary item) in upgradesources.lua.

-- Place a paired slot's candidates: the best onto the weaker equipped slot, the runner-up
-- onto the other if it also beats that slot.  Held beats warband on an ilvl tie; a warband
-- pick is flagged betterElsewhere when it left a lower held candidate unplaced.
local function resolvePair(g, equipped, ranks, out)
  local cands = g.cands
  for i, c in ipairs(cands) do c.i = i end
  sort(cands, function(a, b)
    if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
    if a.where ~= b.where then return a.where == "held" end
    return a.i < b.i
  end)
  local function cur(slot) return equipped[slot] and equipped[slot].ilvl or 0 end
  local weak, strong = g.slots[1], g.slots[2]
  if cur(strong) < cur(weak) then weak, strong = strong, weak end
  local placed = {}
  for i, slot in ipairs({ weak, strong }) do
    local c = cands[i]
    if c and c.ilvl > cur(slot) then
      placed[i] = true
      out[slot] = {
        slot = slot, link = c.link, ilvl = c.ilvl, ilvlGain = c.ilvl - cur(slot),
        where = c.where, statTag = ns.StatTag(c.link, ranks), reqLevel = c.reqLevel,
      }
    end
  end
  local heldLeft = false
  for j, c in ipairs(cands) do
    if not placed[j] and c.where == "held" then heldLeft = true end
  end
  for _, slot in ipairs({ weak, strong }) do
    local r = out[slot]
    if r then r.betterElsewhere = r.where == "warband" and heldLeft end
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
  local twoHander = ns.EquippedTwoHand(charData)

  -- Candidates for a paired slot (rings, trinkets), grouped by the pair's first slot and
  -- placed together below: the best goes to the weaker slot, the runner-up to the other.
  local pairs_ = {}

  -- Record the best (highest ilvl) candidate for each slot, per source.
  local function consider(cand, where)
    local slot, gain, ilvl, slots = ns.Evaluate(charData, cand)
    if not slot then return end
    if twoHander and (slot == "MainHand" or slot == "OffHand") then return end
    if #slots == 2 then
      local g = pairs_[slots[1]]
      if not g then g = { slots = slots, cands = {} } ; pairs_[slots[1]] = g end
      insert(g.cands, { link = cand.link, ilvl = ilvl, reqLevel = cand.reqLevel, where = where })
      return
    end
    local r = out[slot]
    if not r then r = {} ; out[slot] = r end
    local k = where == "warband" and "wb" or "held"
    if not r[k] or ilvl > r[k].ilvl then
      r[k] = { link = cand.link, ilvl = ilvl, gain = gain, reqLevel = cand.reqLevel }
    end
  end

  for _, c in ipairs(pools.bags) do consider(c, "held") end
  for _, c in ipairs(pools.bank) do consider(c, "held") end
  for _, c in ipairs(warband) do consider(c, "warband") end

  -- Resolve each slot's headline: prefer held; flag a strictly-better warband copy.
  for slot, r in pairs(out) do
    local pick, where, better = ns.PickHeadline(r)
    out[slot] = {
      slot = slot, link = pick.link, ilvl = pick.ilvl, ilvlGain = pick.gain,
      where = where, betterElsewhere = better, statTag = ns.StatTag(pick.link, ranks),
      reqLevel = pick.reqLevel,
    }
  end

  for _, g in pairs(pairs_) do resolvePair(g, equipped, ranks, out) end

  if twoHander then ns.ResolveTwoHand(charData, pools, warband, equipped, ranks, out) end
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
  -- Slot tiebreak so equal-gain entries keep a stable order across memo recomputes (else
  -- pairs() + an unstable sort reshuffles rows and changes the tooltip's top-N cut).
  sort(list, function(a, b)
    if a.ilvlGain ~= b.ilvlGain then return a.ilvlGain > b.ilvlGain end
    return a.slot < b.slot
  end)
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
