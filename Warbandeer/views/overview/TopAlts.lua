---@type Warbandeer
local ns = select(2, ...)
local insert = table.insert
local floor, max = math.floor, math.max
local ui = ns.ui
local Class, TableFrame = ns.lua.Class, ui.TableFrame
local theme = ns.theme

ns.overview = ns.overview or {}

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}

-- ─── Top Characters gear columns ────────────────────────────────────────────
-- The Top Characters table appends one column per raid difficulty (RF/N/H/M)
-- showing how many appearance pieces of the selected raid's class set that class
-- still needs, mirroring the Collected view (number missing, or a green check
-- when complete). Data is read from the sibling Collected addon via the
-- WarbandeerCollectedApi global (OptionalDep). The four difficulty variants of a
-- raid are sibling Collected groups that share one group id and differ only by the
-- difficulty suffix in their name (see Warbandeer_Collected/data/sets.lua).
-- Like the Collected view, each set cell also carries the wanted-star + tier-letter
-- overlays (TopAlts:_refreshMarks/_applyCellMarks in TopAltsMarks.lua), a Shift-click
-- wanted toggle, and a live refresh on dressing-room rating edits.

-- Raids selectable via the titlebar dropdown; `key` is the shared Collected group id.
-- Exposed on ns.overview so the Overview view's BuildFilter can drive the raid picker.
local RAIDS = {
  { key = 372, label = "Voidspire" },
}
local DEFAULT_RAID = RAIDS[1].key
ns.overview.RAIDS = RAIDS

-- Difficulty columns in display order; `suffix` matches the Collected group-name suffix.
local DIFFS = {
  { label = "RF", suffix = "Raid Finder" },
  { label = "N",  suffix = "Normal" },
  { label = "H",  suffix = "Heroic" },
  { label = "M",  suffix = "Mythic" },
}
local GEAR_W = 26   -- width of each difficulty column

-- 10-shade red→green gradient keyed by collected fraction (matches the /collected DataView grid).
local shades = {
  {165/255,   0/255,  38/255, 1},
  {215/255,  48/255,  39/255, 1},
  {244/255, 109/255,  67/255},
  {253/255, 174/255,  97/255},
  {254/255, 224/255, 139/255},
  {217/255, 239/255, 139/255},
  {166/255, 217/255, 106/255},
  {102/255, 189/255,  99/255},
  { 26/255, 152/255,  80/255},
  {      0, 104/255,  55/255},
}

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = { Center = {}, Size = {13, 13} },
}

-- Resolve a raid id to its four difficulty groups, keyed by difficulty suffix.
---@param api table?  WarbandeerCollectedApi (nil when Collected isn't loaded)
---@param raidId number
---@return table<string, table>  suffix -> Collected group
local function raidGroups(api, raidId)
  local out = {}
  if not api then return out end
  for _, grp in ipairs(api.Sets) do
    if grp.id == raidId then
      for _, d in ipairs(DIFFS) do
        if grp.name:find(d.suffix, 1, true) then out[d.suffix] = grp end
      end
    end
  end
  return out
end

-- Cell data for one class's set in one difficulty: green check when complete, the
-- uncollected count (red→green shaded) otherwise, "–" when unscanned, blank when
-- the class has no set or Collected isn't available. A scanned cell carries the
-- Collected view's own hover/click — hover shows the shared per-slot source InfoTip,
-- left-click opens the 3D dressing room, Shift-click toggles the set's wanted flag.
-- Every real set cell carries its setId so _refreshMarks can draw the wanted-star +
-- tier-letter overlays. GetData's decorate() wraps the hover to also drive the row
-- highlight (and falls back to opening Detail where there's no set click).
---@param tbl TopAlts  owning table (for _applyCellMarks on the wanted toggle)
---@param api table?  WarbandeerCollectedApi
---@param grp table?  the difficulty group, or nil
---@param classId number
---@return table  cell data
local function gearCell(tbl, api, grp, classId)
  if not (api and grp) then return {} end
  local set = grp.sets[classId]
  if not (set and set.id) then return {} end
  local status = api:SetStatus(grp.id, set.id)
  if not status then
    return { setId = set.id, text = "–", justifyH = ui.justify.Center, color = theme.colors.muted }
  end
  local onEnter = function(c) api:ShowInfoTip(grp, set, c, ns.InfoTipPosition(c)) end
  local onLeave = function() api:HideInfoTip() end
  -- Left-click previews the set; Shift-click flags/unflags it wanted (button-agnostic,
  -- matching the Collected view) and re-applies this cell's overlays from live state.
  local onClick = function(c)
    if IsShiftKeyDown() then
      api:ToggleWanted(set.id)
      tbl:_applyCellMarks(c, set.id)
      -- Tell Collected as well (#765): the mutator is a plain setter, so without this the flag
      -- lands in the DB and every other surface — both grids, the shared dressing room — stays
      -- stale until something else rebuilds them. Capability-guarded like the OnRatingsChanged
      -- subscription in CollectedView: this is a cross-addon call with real released version skew,
      -- and an older Collected has no publish method.
      if api.NotifyRatingsChanged then api:NotifyRatingsChanged(set.id) end
    else
      -- Dock the room onto Warbandeer's own window. Without an explicit host ResolveDockHost
      -- falls back to ns:Open(), putting the whole /collected window on screen just to have
      -- something to hang the doll off — it only looked right when an earlier click in the
      -- embedded Collected view had already left a host behind. An older Collected predates
      -- the host param and harmlessly discards it, so this needs no capability guard.
      api:ShowDressingRoom(grp, set, ns.MainWindow)
    end
  end
  if status == true or status.collected >= status.total then
    return {
      setId = set.id,
      atlas = GreenCheck.atlas, atlasSize = GreenCheck.atlasSize,
      position = GreenCheck.position,
      onEnter = onEnter, onLeave = onLeave, onClick = onClick,
    }
  end
  return {
    setId = set.id,
    text = status.total - status.collected,
    justifyH = ui.justify.Center,
    color = shades[max(1, floor(status.collected / status.total * 10))],
    fontInfo = ns.theme.fonts.number,
    onEnter = onEnter, onLeave = onLeave, onClick = onClick,
  }
end

-- Static + difficulty columns for the Top Characters table (level / name / ilvl,
-- then one centered column per RF/N/H/M difficulty).
local topAltsCols = {
  {width = 20, backdrop = TransparentBackdrop},
  {width = 100, backdrop = TransparentBackdrop},
  {width = 30, backdrop = TransparentBackdrop},
}
for _, d in ipairs(DIFFS) do
  insert(topAltsCols, {
    width = GEAR_W, name = d.label,
    justifyH = ui.justify.Center, backdrop = TransparentBackdrop,
  })
end

-- Table of top toon per class
---@class TopAlts: TableFrame
---@field _toons Character[]  row index -> character (kept in sync by GetData)
---@field _raidId number      currently selected raid (Collected group id)
---@field _playerRace number? cached canonical race id the tier-letter overlays resolve against
---@field GetData fun(self: TopAlts): table  builds the top-character rows
---@field SetRaid fun(self: TopAlts, raidId: number)  re-render gear cells for a raid
---@field Refresh fun(self: TopAlts)  rebuild rows from current data + raid
---@field _applyCellMarks fun(self: TopAlts, cell: Cell, setId: number?)  set one cell's wanted/tier overlays (TopAltsMarks.lua)
---@field _refreshMarks fun(self: TopAlts)  re-apply every set cell's wanted/tier overlays (TopAltsMarks.lua)
local TopAlts = Class(TableFrame, function(self)
  -- fit col 2 to the widest name
  local w = 0
  for _, r in ipairs(self.cells) do
    if r[2] and r[2].label then
      w = math.max(w, r[2].label._widget:GetUnboundedStringWidth())
    end
  end
  if w > 0 then
    local delta = w - self.cols[2]:Width()
    self.cols[2]:Width(w)
    self.rowArea:Width(self.rowArea:Width() + delta)
    self:Width(self:Width() + delta)
  end
  -- Hover/click is driven per-cell (see GetData's decorate), not by a mouse-enabled
  -- row: an interactive row sits above the cells and swallows their tooltips/clicks.
  self:_refreshMarks()   -- the constructor-time update() ran before our override was mixed in
end, {
  headerHeight = 18,
  headerWidth = 0,
  _raidId = DEFAULT_RAID,
  colInfo = topAltsCols,
  GetData = function(self)
    local toons = ns.api.GetAllCharacters()
    local top = {}
    for _, toon in pairs(toons) do
      if not top[toon.classKey] or ns.byLevelIlvl(toon, top[toon.classKey]) then
        top[toon.classKey] = toon
      end
    end
    top = ns.lua.lists.values(top)
    table.sort(top, ns.byLevelIlvl)
    local api = WarbandeerCollectedApi
    local groups = raidGroups(api, self._raidId)
    local data = {}
    self._toons = {}
    for idx, toon in ipairs(top) do
      -- addRow only for genuinely new rows so GetData is re-runnable (raid change /
      -- OnBeforeShow) without duplicating rows; update() reuses the existing cells.
      if not self.rows[idx] then self:addRow({backdrop = TransparentBackdrop}) end
      insert(self._toons, toon)

      -- Cells drive hover + click (the row isn't mouse-enabled): like
      -- SummaryView:decorateRow, every cell chains the row highlight onto its hover
      -- and opens Detail on click unless it carries its own (ilvl → Gear, set →
      -- dressing room). idx is resolved lazily so the closures survive re-sorts.
      local function decorate(cell, defaultClick)
        local onEnter, onLeave, onClick = cell.onEnter, cell.onLeave, cell.onClick
        cell.onEnter = function(c) self:_hover(idx, true);  if onEnter then onEnter(c) end end
        cell.onLeave = function(c) self:_hover(idx, false); if onLeave then onLeave(c) end end
        cell.onClick = onClick or defaultClick
        return cell
      end
      local function openDetail() self:_openDetail(idx) end

      -- Per-slot ilvl breakdown for the ilvl-cell tooltip (matches the Summary column).
      local ilvlLines = ns.IlvlTooltipLines(toon)
      local row = {
        decorate({
          text = toon.basic.level,
          color = NORMAL_FONT_COLOR,
          fontInfo = ns.theme.fonts.number,
        }, openDetail),
        decorate({
          text = toon.name,
          color = ns.Colors[toon.classKey],
        }, openDetail),
        decorate({
          text = ns.IlvlColor(ns.ilvlOf(toon)),
          justifyH = ui.justify.Right,
          fontInfo = ns.theme.fonts.number,
          onEnter = function(c)
            if #ilvlLines == 0 then return end
            ns.AnchorTip(c)
            ui.tip:ClearLines()
            for _, l in ipairs(ilvlLines) do ui.tip:AddLine(l) end
            ui.tip:Show()
          end,
          onLeave = function() ui.tip:Hide() end,
          onClick = function() ns:view("gear") end,
        }, openDetail),
      }
      for _, d in ipairs(DIFFS) do
        insert(row, decorate(gearCell(self, api, groups[d.suffix], toon.classId), openDetail))
      end
      insert(data, row)
    end
    return data
  end,
})
ns.overview.TopAlts = TopAlts

-- Highlight (or clear) row `i` — transparent at rest, theme hover on enter. Called
-- from every cell's hover (the row itself isn't mouse-enabled; cells drive it).
---@param i integer  row index
---@param on boolean
function TopAlts:_hover(i, on)
  local row = self.rows[i]
  if not row then return end
  if on then row.backdrop:Color(theme.colors.hover) else row.backdrop:Color(0, 0, 0, 0) end
end

-- Open row `i`'s character in the Detail view.
---@param i integer  row index
function TopAlts:_openDetail(i)
  local win, toon = ns.MainWindow, self._toons[i]
  if not (win and toon) then return end
  win:getView("detail"):Select(toon)
  win:view("detail")
end

-- Refresh overlays after the base table (re)builds its cells.
function TopAlts:update()
  TableFrame.update(self)
  self:_refreshMarks()
end

-- Rebuild rows + cells from current character data and the selected raid.
function TopAlts:Refresh()
  self.data = self:GetData()
  self:update()
end

-- Switch the gear columns to a different raid and re-render.
---@param raidId number
function TopAlts:SetRaid(raidId)
  if self._raidId == raidId then return end
  self._raidId = raidId
  self:Refresh()
end
