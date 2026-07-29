---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, StatChart = ui.Frame, ui.Label, ns.StatChart
local theme = ns.theme
local D = ns.detail

local canaccessvalue = canaccessvalue

-- Treat a "secret" combat value (one tainted code can't do arithmetic on) as absent, so a
-- rating/percent captured before the data layer began filtering them — or any future secret
-- value — can't crash the delta/radar math. The data layer (data/stats.lua) already drops
-- them at capture; this guards values already in the DB.
local function safeNum(v)
  if v == nil then return nil end
  if canaccessvalue and not canaccessvalue(v) then return nil end
  return v
end

local DetailView = ns.views.DetailView
local Top, Left, Right = ui.edge.Top, ui.edge.Left, ui.edge.Right
local TopLeft, BottomLeft, BottomRight = ui.edge.TopLeft, ui.edge.BottomLeft, ui.edge.BottomRight

-- The secondary-stat 2×2 grid under the Item Level / Playtime cards: Crit + Mastery on
-- top, Haste + Versatility below — each cell the effective % (incl. base, as the paperdoll
-- shows) over the gear rating. Values come from the data layer's stored `stats.secondary`
-- (warband-wide last-seen). The spec's top-priority stat is tinted gold when ShadowsOfUI-
-- Upgrade is loaded (OptionalDep, via `StatRanks`); plain otherwise.
local CELLS = {
  { key = "crit",        label = "Critical Strike", col = 0, row = 0 },
  { key = "mastery",     label = "Mastery",         col = 1, row = 0 },
  { key = "haste",       label = "Haste",           col = 0, row = 1 },
  { key = "versatility", label = "Versatility",     col = 1, row = 1 },
}

-- The character's tier-1 secondary stats (a set), for the gold highlight; empty when the
-- upgrade addon isn't loaded or the spec/priority is unknown.
local function topStats(charName)
  local api = ShadowsOfUI_UpgradeApi
  local ranks = api and api.StatRanks and api:StatRanks(charName)
  local set = {}
  if ranks then
    for stat, tier in pairs(ranks) do if tier == 1 then set[stat] = true end end
  end
  return set
end

-- The rating's status vs its Archon target (within 5% = on-target, over, under), mirroring
-- ClassCodex's classification — each carries an inline colour `code` (for the "571 / 869"
-- number) and the matching `label` (for the hover). nil = no target.
local DELTA = {
  at    = { code = "|cff73d973", label = "In target range" },
  above = { code = "|cff66b3ff", label = "Over target" },
  below = { code = "|cffe67373", label = "Under target" },
}
local function deltaState(current, target)
  if not (current and target and target > 0) then return nil end
  local pct = (current - target) / target * 100
  if math.abs(pct) < 5 then return "at" end
  return pct > 0 and "above" or "below"
end

-- Plain-language description of what each cell's bold percentage means in game (the
-- effective stat percentage, base included — as the paperdoll shows). Shown on the
-- percentage's own hover, separate from the cell's target tooltip.
local EXPLAIN = {
  crit        = "Your chance for an attack or spell to critically strike for increased damage or healing.",
  haste       = "Speeds up your attacks, spell casts, and many periodic effects and resource generation.",
  mastery     = "Improves a bonus specific to your specialization; what it boosts depends on your spec.",
  versatility = "Increases the damage and healing you deal, and reduces damage you take (at half the listed value).",
}

-- Hover tooltip over just the percentage value: the stat name + a plain-language note
-- on what the percent means. Armed on every cell, regardless of whether a target exists.
-- A cell may carry a per-character override title/body (mastery → its spec's named
-- passive + effect, set in `_showStats`); otherwise the static stat name + `EXPLAIN`.
local function showPctTip(frame, entry)
  local m = theme.colors.muted
  ns.AnchorTip(frame)
  ui.tip:MaxWidth(240)
  ui.tip:ClearLines()
  ui.tip:AddLine(entry._pctTitle or entry.label)
  ui.tip:AddLine(entry._pctBody or EXPLAIN[entry.key], m[1], m[2], m[3])
  ui.tip:Show()
end

-- Resolve the mastery cell's per-character override from the captured passive spell id
-- (`stats.secondary.mastery.spell`): "Mastery: <name>" as the title and the spell's own
-- description as the body. Returns nil,nil to fall back to the generic note when the
-- character has no stored spell (not yet re-scanned) or it doesn't resolve yet.
--
-- The description prefers the character's own scan-time capture: GetSpellDescription
-- substitutes the *logged-in* character's mastery coefficient, so it is only ever right for
-- our own record. For an alt it is contamination, not a fallback -- an alt cached before the
-- field existed (i.e. every alt until its next login) would otherwise show this character's
-- figures under that alt's mastery (#741). Such an alt gets an explicit not-captured line
-- naming the one action that fills it, rather than a silent gap that reads as a bug.
local NOT_CAPTURED = "Log in on this character to capture its mastery description."
---@param sec table?     the character's stats.secondary
---@param isSelf boolean true when `sec` belongs to the logged-in character
local function masteryOverride(sec, isSelf)
  local m = sec and sec.mastery
  local spellID = m and m.spell
  if not spellID then return nil, nil end
  local name = C_Spell.GetSpellName(spellID)
  if not name then return nil, nil end
  local desc = m.description or (isSelf and C_Spell.GetSpellDescription(spellID)) or nil
  if desc == nil or desc == "" then return name, not isSelf and NOT_CAPTURED or nil end
  return name, desc
end

-- Hover tooltip for a stat cell that has an Archon target: the stat name, the colour-matched
-- status line + signed delta, and the current/target ratings. No-op when the cell has no target.
local function showStatTip(cell)
  local t = cell._tip
  if not t then return end
  local d = DELTA[t.state]
  ns.AnchorTip(cell)
  ui.tip:MaxWidth(nil)
  ui.tip:ClearLines()
  ui.tip:AddLine(t.label)
  local diff = t.current - t.target
  ui.tip:AddLine(("%s%s|r |cffb0b0b0(%s%d)|r"):format(d.code, d.label, diff >= 0 and "+" or "−", math.abs(diff)))
  ui.tip:AddLine(("|cff808080%d / %d target|r"):format(t.current, t.target))
  ui.tip:Show()
end

-- Lazily build the 4-cell grid (fixed layout; values filled by `_showStats`).
function DetailView:_buildStatGrid()
  if self._statCells then return end
  local c = theme.colors
  -- Two narrower columns with the radar centred in the gap between them.
  local cellW = (D.PANEL_W - D.STATS_CHART - 2 * D.GAP) / 2
  local grid = Frame:new{
    parent = self,
    position = { TopLeft = {D.P, -D.STATS_TOP}, Width = D.PANEL_W, Height = D.STATS_H },
  }
  -- Radar chart filling the centre channel, vertically centred over the grid.
  self._statChart = StatChart:new{
    parent = grid, radius = D.STATS_CHART / 2 - 4,
    position = {
      TopLeft = {(D.PANEL_W - D.STATS_CHART) / 2, -(D.STATS_H - D.STATS_CHART) / 2},
      Width = D.STATS_CHART, Height = D.STATS_CHART,
    },
  }
  self._statCells = {}
  for i, spec in ipairs(CELLS) do
    local cell = Frame:new{
      parent = grid, background = c.module,
      position = {
        TopLeft = {spec.col == 0 and 0 or (D.PANEL_W - cellW), -spec.row * D.STATS_ROW_H},
        Width = cellW, Height = D.STATS_ROW_H - 6,
      },
    }
    local name = Label:new{
      parent = cell, fontInfo = theme.fonts.subcaps, color = c.muted, justifyH = ui.justify.Center,
      text = spec.label:upper(),
      position = { Top = {cell, Top, 0, -5}, Left = {cell, Left, 6, 0}, Right = {cell, Right, -6, 0} },
    }
    local pct = Label:new{
      parent = cell, fontInfo = theme.fonts.number, color = c.text, justifyH = ui.justify.Left,
      position = { BottomLeft = {cell, BottomLeft, 8, 5} },
    }
    local rating = Label:new{
      parent = cell, fontInfo = theme.fonts.stat, color = c.muted, justifyH = ui.justify.Right,
      position = { BottomRight = {cell, BottomRight, -8, 6} },
    }
    -- Hover shows the target status (only armed in `_showStats` when a target exists).
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function() showStatTip(cell) end)
    cell:SetScript("OnLeave", function() ui.tip:Hide() end)
    -- A hit area over just the percentage value (tracks the label as its text resizes):
    -- hovering it explains what the percent means. As a child frame it captures the
    -- hover in place of the cell's target tooltip, leaving the rest of the cell on it.
    local pctHit = Frame:new{
      parent = cell,
      position = { TopLeft = {pct, TopLeft, -3, 3}, BottomRight = {pct, BottomRight, 3, -3} },
    }
    local entry = { key = spec.key, label = spec.label, name = name, pct = pct, rating = rating, frame = cell }
    self._statCells[i] = entry
    pctHit:EnableMouse(true)
    pctHit:SetScript("OnEnter", function() showPctTip(pctHit, entry) end)
    pctHit:SetScript("OnLeave", function() ui.tip:Hide() end)
  end
end

-- Fill the grid from the character's stored secondary stats, tinting its top-priority stat
-- and showing each rating against its Archon target ("571 / 869", status-coloured) when
-- ClassCodex supplies one.
function DetailView:_showStats()
  self:_buildStatGrid()
  local c = theme.colors
  local sec = self._char.stats and self._char.stats.secondary
  local top = topStats(self._char.name)
  local api = ShadowsOfUI_UpgradeApi
  local targets = api and api.StatTargets and api:StatTargets(self._char.name)
  -- Constant per render: only our own record may resolve a mastery description live (#741).
  local isSelf = self._char.name == ns.api.GetCurrentCharacter()
  for _, cell in ipairs(self._statCells) do
    local s = sec and sec[cell.key]
    local hot = top[cell.key]
    -- Secret values (combat ratings/percentages) read back as nil so the math below is safe.
    local ratingVal = s and safeNum(s.rating)
    local pctVal = s and safeNum(s.pct)
    cell.name:Color(hot and c.gold or c.muted)
    -- Mastery's meaning is spec-specific: name it from the captured passive spell.
    if cell.key == "mastery" then cell._pctTitle, cell._pctBody = masteryOverride(sec, isSelf) end
    local target = s and targets and targets[cell.key]
    local state = (ratingVal and target) and deltaState(ratingVal, target) or nil
    cell.frame._tip = state and { label = cell.label, state = state, current = ratingVal, target = target } or nil
    if s then
      cell.pct:Text(pctVal and ("%.2f%%"):format(pctVal) or "—"):Color(hot and c.gold or c.text)
      if state then
        cell.rating:Text(("%s%d|r |cff808080/ %d|r"):format(DELTA[state].code, ratingVal, target))
      else
        cell.rating:Text(ratingVal and tostring(ratingVal) or "")
      end
    else
      cell.pct:Text("—"):Color(c.muted)
      cell.rating:Text("")
    end
  end
  -- Feed the centre radar the four gear ratings (0 when unscanned), plotted as
  -- fulfilment vs each stat's Archon target, tinting tier-1 gold.
  local function rating(key) local s = sec and sec[key]; return (s and safeNum(s.rating)) or 0 end
  self._statChart:Set(rating("crit"), rating("haste"), rating("mastery"), rating("versatility"), top, targets)
end
