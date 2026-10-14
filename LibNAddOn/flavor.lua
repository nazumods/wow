---@class LibNAddOn
local ns = select(2, ...)

-- Client-flavor detection and the feature table that gates systems a flavor lacks.
--
-- Forever (the WoW 1.x "Camelot" client) is Mainline-family: it exposes C_Housing,
-- C_WeeklyRewards, C_PerksProgram and friends with no server system behind them, so "does
-- the API exist" is NOT a feature test there. Anything a flavor lacks is recorded once,
-- in UNSUPPORTED below, and addons ask `ns:Supports("housing")` instead of probing C_*.
-- Detect with `ns.flavor` / `ns:Supports(feature)`; never with `GetBuildInfo()` ranges.

-- Which game systems are ABSENT on which client flavor; anything not listed exists everywhere.
local UNSUPPORTED = {
  forever = {
    specializations = true,  -- Blizzard_DeprecatedSpecialization is not loaded; Camelot has no specs
    housing = true,
    delves = true,
    mythicPlus = true,
    encounterJournal = true,
    travelersLog = true,     -- Trading Post / Perks Program
    garrison = true,
    legion = true,           -- artifacts, class halls, order-hall mounts, Legion achievements
    greatVault = true,       -- UNVERIFIED: off until the beta probes (#952) show it works
    warbandBank = true,      -- UNVERIFIED: same
  },
}

---The TOC `## X-Game:` value as the client reports it ("[Game]" expands per client), or nil.
---@return string?
local function tocGame()
  local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata
  return getMeta and getMeta("LibNAddOn", "X-Game") or nil
end

---@return "forever"|"retail"
local function detect()
  if WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then return "forever" end
  local game = tocGame()
  if game == "Camelot" or game == "Forever" then return "forever" end
  return "retail"
end

local id = detect()

---@class Flavor
---@field id "forever"|"retail"
---@field isForever boolean
---@field isRetail boolean

---@class LibNAddOn
---@field flavor Flavor the detected client flavor
ns.flavor = { id = id, isForever = id == "forever", isRetail = id == "retail" }

---Does the detected client flavor have this game system? Anything not in the feature table is
---supported everywhere.
---@class LibNAddOn
---@field Supports fun(feature: string): boolean
---@param feature string e.g. "housing", "specializations", "legion", "greatVault"
---@return boolean
function ns.Supports(feature)
  local off = UNSUPPORTED[ns.flavor.id]
  return not (off and off[feature])
end

---@class LibNAddOn
---@field linkFlavor fun(addOn: AddOn) add `flavor` and `Supports` to an addon
function ns.linkFlavor(addOn)
  addOn.flavor = ns.flavor
  function addOn:Supports(feature) return ns.Supports(feature) end
end

-- `/lib flavor`: LibNAddOn's namespace isn't global, so this is the in-game way to read the
-- detected flavor and the signals behind it. Skipped when there is no command registry (the
-- busted harness loads this file into a bare namespace).
if ns.registerCommand then
  ns:registerCommand("flavor", "", function()
    ns.Print(("flavor: %s (WOW_PROJECT_ID %s, WOW_PROJECT_CAMELOT %s, X-Game %s)"):format(
      ns.flavor.id, tostring(WOW_PROJECT_ID), tostring(WOW_PROJECT_CAMELOT), tostring(tocGame())))
  end, "print the detected client flavor and the signals behind it")
end
