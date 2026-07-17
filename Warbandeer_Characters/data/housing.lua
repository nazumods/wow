---@type Warbandeer_Characters
local ns = select(2, ...)
local pairs, ipairs, next = pairs, ipairs, next
local tostring, format = tostring, string.format
local GetServerTime = GetServerTime

-- Per-character neighborhood-endeavor + house-XP capture (issue #550).
--
-- Housing reads are almost all ASYNC: C_Housing.GetPlayerOwnedHouses() returns nothing
-- synchronously — the owned-house list only arrives via PLAYER_HOUSE_LIST_UPDATED, and
-- per-house level/favor only via HOUSE_LEVEL_FAVOR_UPDATED (in response to
-- GetCurrentHouseLevelFavor). The neighborhood endeavor is sync-readable once loaded
-- (GetNeighborhoodInitiativeInfo().isLoaded), warmed by RequestNeighborhoodInitiativeInfo.
-- So this broker CAPTURES from those events + a login kick rather than a plain get, and
-- never mutates the active/viewing neighborhood (SetActiveNeighborhood/SetViewingNeighborhood
-- have real side effects and taint risk). It's a last-seen snapshot, like `titles`/`demons`.
--
-- FIRST CUT — pending the in-game `/wbc dump housing` probe. The exact "earned XP" field
-- and whether reads work outside the housing UI are confirmed by that probe before the
-- Summary column is finalized; the probe's live section is the source of truth regardless
-- of whether this capture guesses right.

local H = C_Housing
local GetPlayerOwnedHouses      = H and H.GetPlayerOwnedHouses
local GetCurrentHouseLevelFavor = H and H.GetCurrentHouseLevelFavor
local GetMaxHouseLevel          = H and H.GetMaxHouseLevel
local DoesFactionMatchNeighborhood = H and H.DoesFactionMatchNeighborhood
local GetTrackedHouseGuid       = H and H.GetTrackedHouseGuid
local HasHousingExpansionAccess = H and H.HasHousingExpansionAccess
local IsHousingServiceEnabled   = H and H.IsHousingServiceEnabled
local IsInsideHouse             = H and H.IsInsideHouse
local IsInsideOwnHouse          = H and H.IsInsideOwnHouse
local IsOnNeighborhoodMap       = H and H.IsOnNeighborhoodMap

local I = C_NeighborhoodInitiative
local GetActiveNeighborhood         = I and I.GetActiveNeighborhood
local GetNeighborhoodInitiativeInfo = I and I.GetNeighborhoodInitiativeInfo
local RequestNeighborhoodInitiativeInfo = I and I.RequestNeighborhoodInitiativeInfo
local GetAvailableHouseXP           = I and I.GetAvailableHouseXP
local IsInitiativeEnabled           = I and I.IsInitiativeEnabled
local PlayerHasInitiativeAccess     = I and I.PlayerHasInitiativeAccess

-- Account-wide neighborhood/house identity. *Which* house a neighborhood belongs to
-- (Horde vs Alliance) is account-global, so it lives here — that lets an offline alt's
-- cached per-character contribution be labelled by faction without that alt being logged
-- in. Per-house level/favor (the house's total, not per-contributor) is cached alongside.
---@class HousingNeighborhood
---@field isAlliance boolean?  absolute faction of the neighborhood (nil until resolved)
---@field name string?         neighborhood display name

---@class HousingHouse
---@field neighborhoodGUID string?
---@field name string?
---@field level integer?
---@field favor integer?

---@class HousingAccount
---@field neighborhoods table<string, HousingNeighborhood>  keyed by neighborhoodGUID
---@field houses table<string, HousingHouse>                keyed by houseGUID

---@class WarbandeerCharactersDB
---@field housing HousingAccount?

-- Per-character endeavor state. XP is credited AT EARN TIME to the subscribed
-- neighborhood, so a character that switches keeps an independent running total per
-- neighborhood until that neighborhood's cycle resets.
---@class HousingBroker: Broker
---@field subscribed string?              active (subscribed) neighborhoodGUID
---@field earned table<string, integer>   neighborhoodGUID -> this char's contribution this cycle
---@field cycle table<string, integer>    neighborhoodGUID -> currentCycleID the `earned` was recorded under
---@field availableXP integer?            unspent earned house-XP pool (current subscription)
---@field title string?                   current endeavor title
---@field scannedAt integer?              last capture (epoch)

---@class Character
---@field housing HousingBroker?

-- Lazily ensure the account-wide housing store exists (also bumped in MigrateDB v40).
---@return HousingAccount
local function account()
  local db = ns.db
  if not db.housing then db.housing = { neighborhoods = {}, houses = {} } end
  return db.housing
end

-- Resolve + remember a neighborhood's absolute faction. DoesFactionMatchNeighborhood
-- answers "does this neighborhood match the CURRENT character's faction?", so combined
-- with the current character's own faction it yields an absolute Horde/Alliance tag we
-- can store account-wide and reuse to label an offline alt's cached contribution.
local function recordNeighborhood(guid, name)
  if not guid then return end
  local nb = account().neighborhoods[guid]
  if not nb then nb = {}; account().neighborhoods[guid] = nb end
  if name then nb.name = name end
  if nb.isAlliance == nil and DoesFactionMatchNeighborhood and ns.currentData then
    local matches = DoesFactionMatchNeighborhood(guid)
    if matches ~= nil then nb.isAlliance = (matches == ns.currentData.isAlliance) end
  end
end

-- PLAYER_HOUSE_LIST_UPDATED delivers the owned-house list (GetPlayerOwnedHouses returns
-- nothing synchronously). Cache each house's identity + neighborhood, then kick a
-- favor request per house so HOUSE_LEVEL_FAVOR_UPDATED fills in level/favor.
ns:registerEvent("PLAYER_HOUSE_LIST_UPDATED", function(_, houseInfos)
  if not houseInfos then return end
  local acct = account()
  for _, h in ipairs(houseInfos) do
    if h.houseGUID then
      local house = acct.houses[h.houseGUID]
      if not house then house = {}; acct.houses[h.houseGUID] = house end
      house.neighborhoodGUID = h.neighborhoodGUID
      house.name = h.houseName
      recordNeighborhood(h.neighborhoodGUID, h.neighborhoodName)
      if GetCurrentHouseLevelFavor then GetCurrentHouseLevelFavor(h.houseGUID) end
    end
  end
end)

-- HOUSE_LEVEL_FAVOR_UPDATED delivers a HouseLevelFavor { houseGUID, houseLevel, houseFavor }.
ns:registerEvent("HOUSE_LEVEL_FAVOR_UPDATED", function(_, favor)
  if not favor or not favor.houseGUID then return end
  local house = account().houses[favor.houseGUID]
  if not house then house = {}; account().houses[favor.houseGUID] = house end
  house.level = favor.houseLevel
  house.favor = favor.houseFavor
end)

local Housing = ns:RegisterBroker("housing")
Housing.fields = {
  ---@class HousingBroker
  ---@field endeavor HousingBroker
  endeavor = {
    missing = false,
    -- Reads the currently-loaded (subscribed) initiative synchronously and merges it into
    -- the per-neighborhood `earned` map. Also kicks the async house-list + initiative
    -- refresh so the next capture (and the events they raise) have fresh data. Sticky: a
    -- transient/early read where nothing is loaded keeps the existing per-neighborhood totals.
    get = function(_, _, current)
      current = current or { earned = {}, cycle = {} }
      current.earned = current.earned or {}
      current.cycle = current.cycle or {}
      if GetPlayerOwnedHouses then GetPlayerOwnedHouses() end
      if RequestNeighborhoodInitiativeInfo then RequestNeighborhoodInitiativeInfo() end
      if GetActiveNeighborhood then current.subscribed = GetActiveNeighborhood() end
      local info = GetNeighborhoodInitiativeInfo and GetNeighborhoodInitiativeInfo()
      if info and info.isLoaded and info.neighborhoodGUID then
        local guid = info.neighborhoodGUID
        current.earned[guid] = info.playerTotalContribution
        current.cycle[guid] = info.currentCycleID
        current.title = info.title
        recordNeighborhood(guid)
      end
      if GetAvailableHouseXP then current.availableXP = GetAvailableHouseXP() end
      current.scannedAt = GetServerTime()
      return current
    end,
    event = "NEIGHBORHOOD_INITIATIVE_UPDATED",
    eventDelay = 500,
  },
}

-- `/wbc dump housing` (+ `/wbc wdump housing`): the in-game reconnaissance probe. Kicks the
-- async requests at the top (so a second run a few seconds later shows warmed data), then
-- dumps every live housing/initiative read + the account cache + this character's stored
-- state, so the real API behaviour (field values, readability by context) is confirmable.
local function bool(fn) return tostring(fn and fn()) end
local function faction(isAlliance)
  if isAlliance == nil then return "?" end
  return isAlliance and "Alliance" or "Horde"
end

ns:registerDump("housing", "Housing / Endeavors",
  "Live housing + neighborhood-endeavor API probe for the current character",
  function(_, out)
    local toon = ns.currentData
    if not toon then out:line("No current character."); return end
    if GetPlayerOwnedHouses then GetPlayerOwnedHouses() end
    if RequestNeighborhoodInitiativeInfo then RequestNeighborhoodInitiativeInfo() end
    local acct = ns.db.housing

    out:line("== context ==")
    out:line("this char faction: " .. faction(toon.isAlliance))
    out:line("HasHousingExpansionAccess: " .. bool(HasHousingExpansionAccess) ..
             "  IsHousingServiceEnabled: " .. bool(IsHousingServiceEnabled))
    out:line("IsInitiativeEnabled: " .. bool(IsInitiativeEnabled) ..
             "  PlayerHasInitiativeAccess: " .. bool(PlayerHasInitiativeAccess))
    out:line("IsInsideHouse: " .. bool(IsInsideHouse) ..
             "  IsInsideOwnHouse: " .. bool(IsInsideOwnHouse) ..
             "  IsOnNeighborhoodMap: " .. bool(IsOnNeighborhoodMap))
    out:line("GetTrackedHouseGuid: " .. tostring(GetTrackedHouseGuid and GetTrackedHouseGuid()) ..
             "  GetMaxHouseLevel: " .. tostring(GetMaxHouseLevel and GetMaxHouseLevel()))

    out:line("== active neighborhood / endeavor (live) ==")
    local active = GetActiveNeighborhood and GetActiveNeighborhood()
    out:line("GetActiveNeighborhood: " .. tostring(active))
    if active and DoesFactionMatchNeighborhood then
      local m = DoesFactionMatchNeighborhood(active)
      out:line("  DoesFactionMatchNeighborhood: " .. tostring(m) ..
               "  -> " .. (m == nil and "?" or faction(m == toon.isAlliance)))
    end
    out:line("GetAvailableHouseXP: " .. tostring(GetAvailableHouseXP and GetAvailableHouseXP()))
    local info = GetNeighborhoodInitiativeInfo and GetNeighborhoodInitiativeInfo()
    if not info then
      out:line("GetNeighborhoodInitiativeInfo: nil (not loaded — run again in a few seconds," ..
               " or open the Housing dashboard)")
    else
      out:line("initiative.isLoaded: " .. tostring(info.isLoaded) ..
               "  neighborhoodGUID: " .. tostring(info.neighborhoodGUID))
      out:line("  initiativeID: " .. tostring(info.initiativeID) ..
               "  currentCycleID: " .. tostring(info.currentCycleID))
      out:line("  title: " .. tostring(info.title))
      out:line("  currentProgress/progressRequired: " .. tostring(info.currentProgress) ..
               " / " .. tostring(info.progressRequired))
      out:line("  playerTotalContribution: " .. tostring(info.playerTotalContribution))
      out:line("  duration: " .. tostring(info.duration) ..
               "  #tasks: " .. tostring(info.tasks and #info.tasks) ..
               "  #milestones: " .. tostring(info.milestones and #info.milestones))
    end

    out:line("== owned houses (account cache, async) ==")
    if not acct or not next(acct.houses) then
      out:line("(none cached yet — GetPlayerOwnedHouses is async; run again in a few seconds)")
    else
      for guid, h in pairs(acct.houses) do
        local nb = h.neighborhoodGUID and acct.neighborhoods[h.neighborhoodGUID]
        out:line(format("  %s | name=%s | nb=%s (%s) | level=%s favor=%s", tostring(guid),
          tostring(h.name), tostring(h.neighborhoodGUID),
          faction(nb and nb.isAlliance), tostring(h.level), tostring(h.favor)))
      end
    end

    out:line("== stored per-character housing (this char) ==")
    local hb = toon.housing
    if not hb then out:line("(nil — no capture yet)"); return end
    out:line("subscribed: " .. tostring(hb.subscribed) ..
             "  availableXP: " .. tostring(hb.availableXP) .. "  title: " .. tostring(hb.title))
    out:line("scannedAt: " .. tostring(hb.scannedAt))
    if hb.earned and next(hb.earned) then
      for guid, xp in pairs(hb.earned) do
        local nb = acct and acct.neighborhoods[guid]
        out:line(format("  earned[%s] = %s  (%s, cycle %s)", tostring(guid), tostring(xp),
          faction(nb and nb.isAlliance), tostring(hb.cycle and hb.cycle[guid])))
      end
    else
      out:line("  earned: (empty)")
    end
  end)
