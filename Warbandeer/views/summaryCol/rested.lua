---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- rested
local RestCapColor = {0.3, 1, 0.3, 1}
local RestHighColor = {1, 0.82, 0, 1}
local RestMidColor  = {1, 1, 1, 1}
local RestLowColor  = {0.7, 0.7, 0.7, 1}
local REST_CAP = 1.5
local REST_CAP_PANDAREN = 3.0  -- Inner Peace racial doubles the rested cap
local REST_RATE_RESTING = 0.05 / (8 * 3600)    -- 5% per 8h logged off in inn/city
local REST_RATE_AWAY    = 0.0125 / (8 * 3600)  -- 1.25% per 8h logged off elsewhere

local function restCap(toon)
  return toon.race == "Pandaren" and REST_CAP_PANDAREN or REST_CAP
end

local function formatElapsed(s)
  if s < 60 then return s.."s ago" end
  if s < 3600 then return math.floor(s / 60).."m ago" end
  if s < 86400 then return math.floor(s / 3600).."h ago" end
  return math.floor(s / 86400).."d ago"
end

local function projectedRest(xp, isCurrent, cap)
  if not xp then return nil end
  local rest = xp.restPercent
  local elapsed = 0
  if not isCurrent and xp.recordedAt then
    elapsed = GetServerTime() - xp.recordedAt
    if elapsed > 0 then
      local rate = xp.isResting and REST_RATE_RESTING or REST_RATE_AWAY
      rest = math.min(cap, rest + elapsed * rate)
    end
  end
  return rest, elapsed
end

local function getRestPercent(toon)
  if toon.basic.level >= ns.wow.maxLevel then return "" end
  local xp = toon.basic.xp
  if not xp then return "" end
  local isCurrent = toon.name == ns.api.GetCurrentCharacter()
  local cap = restCap(toon)
  local rest, elapsed = projectedRest(xp, isCurrent, cap)
  local pct = math.floor(rest * 100 + 0.5)
  if pct == 0 then return "" end
  local capPct = math.floor(cap * 100 + 0.5)
  local color
  if pct >= capPct - 1 then color = RestCapColor
  elseif pct >= 100 then color = RestHighColor
  elseif pct >= 50 then color = RestMidColor
  else color = RestLowColor end
  local xpPct = math.floor(xp.percent * 100 + 0.5)
  local recordedPct = math.floor(xp.restPercent * 100 + 0.5)
  return {
    text = pct.."%",
    justifyH = ui.justify.Right,
    color = color,
    onEnter = function(self)
      ns.AnchorTip(self)
      ui.tip:ClearLines()
      ui.tip:AddLine("Rest XP")
      ui.tip:AddLine(("XP: %d%%"):format(xpPct))
      if isCurrent or elapsed == 0 then
        ui.tip:AddLine(("Rest: %d%% of max XP (cap %d%%)"):format(pct, capPct))
      else
        ui.tip:AddLine(("Rest: %d%% (projected, cap %d%%)"):format(pct, capPct))
        local where = xp.isResting and "in rested area" or "outside rested area"
        ui.tip:AddLine(("Recorded: %d%% %s, %s"):format(recordedPct, where, formatElapsed(elapsed)))
      end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "rested", label = "Rested",
    -- reuses the Milestones view's moon glyph (renamed from midnight.tga)
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\views\\milestones.tga",
    iconColor = ns.theme.colors.muted,
    width = 40,
    justifyH = ui.justify.Right,
    tooltip = {
      "Rest XP",
      "Rested XP as a percent of max XP (150% = full rest cap). Recorded on login and as the character gains XP. Hidden for max-level characters.",
    },
    getData = getRestPercent,
  }
)
