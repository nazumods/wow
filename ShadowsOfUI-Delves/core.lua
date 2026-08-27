---@class ShadowsOfUI_Delves: AddOn
local ns = LibNAddOn(...)
---@type LibNUI
local ui = ns.ui

-- "Changelog" button in settings (ns.changelog from changelog.lua).
ns:RegisterChangelog("Shadows of UI")

-- The tier a max-level character is assumed to run (the spec: Tier 11 for level-90s).
local MAX_TIER = 11

-- Which tier's average to show for the current character: T11 at the level cap, else nil so the
-- API falls back to an all-tiers average (delve tiers are a max-level concept).  Cap-tracking via
-- ns.wow.maxLevel, so this follows the cap rather than hard-coding 90.
---@return integer?
function ns.AssumedTier()
  return ns.wow.Player:isMaxLevel() and MAX_TIER or nil
end

-- Seconds -> "m:ss" (the shared LibNAddOn formatter; kept as a local alias for the call sites).
ns.FormatDuration = ns.lua.strings.duration

-- The delve's specific name (GetScenarioInfo().name is the generic "Delves"), resolved the same
-- way the tracker keys its runs so `/sdelves dump` looks them up correctly.
local function delveName()
  local n = GetInstanceInfo()
  if n and n ~= "" then return n end
  local mapID = C_Map.GetBestMapForUnit("player")
  local mi = mapID and C_Map.GetMapInfo(mapID)
  return mi and mi.name
end

-- /sdelves — dev/calibration aid, opened in a copyable window (tooltip/chat text can't be copied).
-- No argument dumps the live delve state used by the tracker (the in-game source for the name + tier
-- readout) — compare the name candidates against the map pin; `dump` shows the recorded stats for the
-- current delve.  It also surfaces the 12.1 structured Delve fields (GetActiveDelveTier tier/
-- difficultyID, GetTieredEntranceType, HasActiveLair/IsInLair): the probe targets for #411.
SLASH_SUI_DELVES1 = "/sdelves"
SlashCmdList["SUI_DELVES"] = function(msg)
  msg = msg and strtrim(msg):lower() or ""

  if msg == "dump" then
    local name = delveName()
    if not name then ns.Print("Not in a delve.") return end
    local stats = ns.api:GetDelveStats(name, ns.AssumedTier())
    if not stats then ns.Print(("No recorded runs for '%s'."):format(name)) return end
    local lines = { ("Delve stats for '%s':"):format(name) }
    for _, s in ipairs(stats) do
      local xp = s.avgXp and (", avg %s XP over %d"):format(BreakUpLargeNumbers(s.avgXp), s.xpCount) or ""
      lines[#lines + 1] = ("  %s: %s (%s, %d run(s)%s)"):format(s.name, ns.FormatDuration(s.avg), s.scope, s.count, xp)
    end
    ui.ToggleCopyWindow("Delve stats", table.concat(lines, "\n"))
    return
  end

  local scen = C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo and C_ScenarioInfo.GetScenarioInfo()
  local step = C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo and C_ScenarioInfo.GetScenarioStepInfo()
  local mapID = C_Map.GetBestMapForUnit("player")
  local mi = mapID and C_Map.GetMapInfo(mapID)
  local lines = {
    "Delve live state (name candidates — match against the map pin):",
    "  instance name: " .. tostring(GetInstanceInfo()),
    "  map name: " .. tostring(mi and mi.name),
    "  scenario name: " .. tostring(scen and scen.name),
    "  step title: " .. tostring(step and step.title),
    "  -> using: " .. tostring(delveName()),
    "  IsDelveInProgress: " .. tostring(C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress()),
    "  HasActiveDelve: " .. tostring(C_DelvesUI and C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve()),
  }
  local setID = step and step.widgetSetID
  lines[#lines + 1] = "  widgetSetID: " .. tostring(setID)
  if setID and C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID then
    for _, w in ipairs(C_UIWidgetManager.GetAllWidgetsBySetID(setID)) do
      local viz = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo
        and C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(w.widgetID)
      lines[#lines + 1] = ("    widget %s type=%s tierText=%s"):format(tostring(w.widgetID), tostring(w.widgetType), viz and tostring(viz.tierText) or "n/a")
    end
  end
  lines[#lines + 1] = "  AssumedTier: " .. tostring(ns.AssumedTier())
  -- 12.1 structured Delve fields (additive APIs — each guarded so this stays inert on older clients).
  -- Probe targets for #411: a numeric tier from GetActiveDelveTier (compare against the header
  -- widget's tierText above), the new difficultyID, the tiered-entrance type (Lairs = 4), and the
  -- Lair / companion-Flavor readouts.
  local D = C_DelvesUI
  local tierInfo = D and D.GetActiveDelveTier and D.GetActiveDelveTier()
  local etType = D and D.GetTieredEntranceType and D.GetTieredEntranceType()
  local ET_LABELS = { [0] = "Invalid", [1] = "Delve", [2] = "Sites", [3] = "WorldTier", [4] = "Lairs" }
  lines[#lines + 1] = "  --- 12.1 structured fields ---"
  lines[#lines + 1] = "  GetActiveDelveTier.tier: " .. tostring(tierInfo and tierInfo.tier)
  lines[#lines + 1] = "  GetActiveDelveTier.difficultyID: " .. tostring(tierInfo and tierInfo.difficultyID)
  lines[#lines + 1] = "  GetActiveDelveTier.suggestedILvl: " .. tostring(tierInfo and tierInfo.suggestedILvl)
  lines[#lines + 1] = ("  GetTieredEntranceType: %s (%s)"):format(tostring(etType), etType and ET_LABELS[etType] or "?")
  lines[#lines + 1] = "  HasActiveLair: " .. tostring(D and D.HasActiveLair and D.HasActiveLair())
  lines[#lines + 1] = "  IsInLair: " .. tostring(D and D.IsInLair and D.IsInLair())
  lines[#lines + 1] = "  GetFlavorNodeForCompanion: " .. tostring(D and D.GetFlavorNodeForCompanion and D.GetFlavorNodeForCompanion())
  lines[#lines + 1] = "  GetFlavorNodeNameForCompanion: " .. tostring(D and D.GetFlavorNodeNameForCompanion and D.GetFlavorNodeNameForCompanion())
  ui.ToggleCopyWindow("Delve live state", table.concat(lines, "\n"))
end
