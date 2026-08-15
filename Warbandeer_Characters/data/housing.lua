---@type Warbandeer_Characters
local ns = select(2, ...)
local pairs, ipairs, next = pairs, ipairs, next
local tostring, format = tostring, string.format
local GetServerTime = GetServerTime

-- Per-character neighborhood-endeavor + account-wide house tracking (issue #550).
--
-- The #550 probes settled the semantics: only the SUBSCRIPTION (which endeavor a character is
-- feeding) is per-character; house favor/level + endeavor progress are account-wide PER HOUSE. So
-- the per-character `active` is a BROKER FIELD (below) — that joins the login-refresh + event
-- machinery and the missing-report audit for free — while the account-wide house identity + endeavor
-- state are cached in `db.housing` from the async house events + the `active` field's get. We never
-- mutate the active/viewing neighborhood (side-effect + taint). Data shapes + the pure shapers live
-- in data/housinginfo.lua (WoW-API-free, unit-tested); this file is the WoW-API capture side.

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

-- Data shapes (HousingNeighborhood/House/Account/Char) + the pure ns.ShapeHousing live in
-- data/housinginfo.lua (WoW-API-free, unit-tested); this file is the WoW-API capture side.

-- Lazily ensure the account-wide housing store exists (also bumped in MigrateDB v40).
---@return HousingAccount
local function account()
  local db = ns.db
  if not db.housing then db.housing = { neighborhoods = {}, houses = {} } end
  return db.housing
end

-- Resolve + remember a neighborhood's absolute faction. DoesFactionMatchNeighborhood
-- answers "does this neighborhood match the CURRENT character's faction?", so combined
-- with the current character's own faction it yields an absolute Horde/Alliance tag we can
-- store account-wide and reuse to label an offline alt's cached contribution.
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
-- nothing synchronously). Cache each house's identity + neighborhood, then kick a favor
-- request per house so HOUSE_LEVEL_FAVOR_UPDATED fills in level/favor.
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

-- Per-character endeavor state as a BROKER FIELD, so it participates in the missing-report audit
-- (missing.lua walks broker fields; a direct `toon.housing` write would silently escape it). `active`
-- is the neighborhood this character is currently feeding. The field's get (queued at login, fired on
-- NEIGHBORHOOD_INITIATIVE_UPDATED by the broker machinery) reads the loaded initiative and also
-- captures that neighborhood's ACCOUNT-WIDE endeavor state (title/progress/reset) — readable only for
-- the active neighborhood, so whichever character is subscribed keeps it fresh. It reads
-- info.neighborhoodGUID (only set once loaded), not GetActiveNeighborhood which can transiently return
-- a not-yet-loaded neighborhood right after a switch/login. Opts into `/wbc missing` as "endeavor" (at
-- any level): `active` is sticky (never reset), so a nil value means the character has never fed a
-- neighborhood endeavor — surfaced as a character not participating in the housing initiative.
local Housing = ns:RegisterBroker("housing")
Housing.fields = {
  active = {
    -- feeds /wbc missing ("endeavor") whenever a character has no active endeavor (active == nil)
    -- 145, not 140 — data/demons.lua's Warlock provider claimed 140 first, and two providers on one
    -- slot leave their relative order undeclared (#745-3, #922). 120 is glyph unlocks, 130 pets, 140
    -- demons, 150 lumber axe, so 145 is the free slot between demons and lumber axe.
    missing = { label = "endeavor", order = 145 },
    get = function(_, _, current)
      if GetPlayerOwnedHouses then GetPlayerOwnedHouses() end          -- kick the async house list
      if RequestNeighborhoodInitiativeInfo then RequestNeighborhoodInitiativeInfo() end
      local info = GetNeighborhoodInitiativeInfo and GetNeighborhoodInitiativeInfo()
      if info and info.isLoaded and info.neighborhoodGUID then
        local guid = info.neighborhoodGUID
        recordNeighborhood(guid)
        local nb = account().neighborhoods[guid]
        nb.title = info.title
        nb.progress = info.currentProgress
        nb.required = info.progressRequired
        nb.resetAt = GetServerTime() + (info.duration or 0)
        -- House XP still earnable this cycle ("Available" — a countdown, surfaced only in the
        -- Overview endeavor tooltip as "you can still earn", not as a headline count-up).
        if GetAvailableHouseXP then nb.xp = GetAvailableHouseXP() end
        return guid
      end
      return current  -- sticky: keep the last-seen active endeavor when nothing is loaded
    end,
    event = "NEIGHBORHOOD_INITIATIVE_UPDATED",
    eventDelay = 500,
  },
}

-- `/wbc dump housing` (+ `/wbc wdump housing`): the in-game reconnaissance probe. Kicks the
-- async requests at the top (so a second run a few seconds later shows warmed data), then
-- dumps every live housing/initiative read + the account cache + this character's stored state.
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
      out:line("GetNeighborhoodInitiativeInfo: nil (run again in a few seconds)")
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
      out:line("(none cached yet — run again in a few seconds)")
    else
      for guid, h in pairs(acct.houses) do
        local nb = h.neighborhoodGUID and acct.neighborhoods[h.neighborhoodGUID]
        out:line(format("  %s | name=%s | nb=%s (%s) | level=%s favor=%s", tostring(guid),
          tostring(h.name), tostring(h.neighborhoodGUID),
          faction(nb and nb.isAlliance), tostring(h.level), tostring(h.favor)))
      end
    end

    out:line("== account neighborhoods (endeavor, account-wide) ==")
    if not acct or not next(acct.neighborhoods) then
      out:line("(none captured yet — run again in a few seconds)")
    else
      for guid, nb in pairs(acct.neighborhoods) do
        out:line(format("  %s (%s) | %s  %s/%s | resetAt=%s", tostring(guid), faction(nb.isAlliance),
          tostring(nb.title), tostring(nb.progress), tostring(nb.required), tostring(nb.resetAt)))
      end
    end

    out:line("== stored per-character housing (this char) ==")
    local hb = toon.housing
    if not hb then out:line("(nil — no capture yet)"); return end
    out:line("active: " .. tostring(hb.active))
  end)
