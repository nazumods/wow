---@type Warbandeer
local ns = select(2, ...)
local floor, max, min = math.floor, math.max, math.min
local ui = ns.ui
local lists = ns.lua.lists
local prepend = lists.prepend
local Colors = ns.Colors
local theme = ns.theme
local Class, Frame, Label, TableFrame = ns.lua.Class, ui.Frame, ui.Label, ui.TableFrame
local Button, Texture = ui.Button, ui.Texture

-- Transmog-set collection grid, sourced from the sibling Collected addon via the
-- WarbandeerCollectedApi global (OptionalDep). Mirrors that addon's own DataView:
-- one row per set group, one column per class, cell = uncollected appearance count
-- shaded red→green by completion (green check when a class set is fully collected).
-- Lockout columns/side-panel are intentionally omitted here — see Collected's own
-- /collected window for those.

local MAX_GRID_H   = 460  -- cap the scrollable row area; window stays usable
local SCROLLBAR_W  = 20

-- 10-shade red→green gradient keyed by collected fraction (matches Collected/DataView)
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
  -- Centered, ~one character wide so it lines up with the numeric count cells.
  position = { Center = {}, Size = {13, 13} },
}

-- PTR ("upcoming") cell mark: a muted blue dot, no completion shade — the live
-- client has no collection data for sets that aren't out yet (mirrors Collected).
local UPCOMING = {0.55, 0.70, 0.95, 1}
local UPCOMING_GLYPH = "•"

-- A class set counts as fully collected when the scan flagged the base set (true)
-- or every appearance is owned (remaining <= 0). The `or` short-circuits before
-- indexing `status`, so passing the boolean `true` is safe.
local function isComplete(status)
  return status == true or status.collected >= status.total
end

-- The live view instance, captured in CollectedView's constructor so the grid's
-- Shift-click handler and the ratings-changed listener can refresh its header.
local _view

-- ─── Grid (TableFrame) ──────────────────────────────────────────────────────

---@class CollectedGrid: TableFrame
---@field _wantedOnly boolean? blank cells for sets that aren't flagged wanted
---@field _ptr boolean? show the PTR-only "upcoming" sets (api.PtrSets) instead of live
---@field _playerRace number? cached canonical race id the rank pips resolve against
local Grid = Class(TableFrame, function(self)
  -- Auto-size the (zero-width) name column to the widest group label, then grow
  -- the row area + frame to match (the base table built it at width 0).
  local w = 0
  for _, r in ipairs(self.cells) do
    if r[1] and r[1].label then w = max(w, r[1].label:Width()) end
  end
  self.cols[1]:Width(w)
  self.rowArea:Width(self.rowArea:Width() + w)
  self:Width(self:Width() + w)
  self:_refreshMarks()   -- the constructor-time update() ran before our override was mixed in
end, {
  headerHeight = 28,
  _reverse = true,   -- default to newest set-group first
  _wantedOnly = false,
  _ptr = false,
  colInfo = prepend(
    lists.map(ns.icons.classes, function(icon)
      return {
        atlas = icon,
        atlasSize = false,
        width = 28,
        padding = 2,
        justifyH = ui.justify.Center,
        backdrop = {color = Colors.TransparentBlack},
      }
    end),
    { width = 0, backdrop = {color = Colors.TransparentBlack} }  -- group-name column
  ),
  GetData = function(self)
    local api = WarbandeerCollectedApi
    if not api then return {} end
    -- PTR mode renders the upcoming-only delta (api.PtrSets); live mode renders api.Sets.
    local src = (self._ptr and api.PtrSets) or api.Sets
    -- Default order is source order (oldest expansion first); _reverse flips to newest first.
    local groups = src
    if self._reverse then
      groups = {}
      for i = #src, 1, -1 do groups[#groups + 1] = src[i] end
    end
    return lists.map(groups, function(grp)
      local gstat = api:GroupStatus(grp.id)
      -- One positional cell per class slot (blank {} where a class has no set).
      local r = lists.map(grp.sets, function(set)
        -- Blank class slot.
        if not set.id then return {} end
        -- Live: only show scanned sets. PTR: every entry is "upcoming" (the live
        -- client has no collection data), so skip the scan gate.
        local status = gstat and gstat[set.id]
        if not self._ptr and not status then return {} end
        -- "Wanted only" blanks non-wanted cells, mirroring the /collected window.
        if self._wantedOnly and not WarbandeerCollectedApi:IsWanted(set.id) then return {} end
        -- Same per-slot source tooltip as the /collected window (via the API) on
        -- every cell — complete or partial; a fully-collected set shows all green.
        local onEnter = function(c)
          WarbandeerCollectedApi:ShowInfoTip(grp, set, c, ns.InfoTipPosition(c))
        end
        local onLeave = function() WarbandeerCollectedApi:HideInfoTip() end
        -- Left-click previews the set; Shift-click flags/unflags it as wanted. Both
        -- work for PTR-only sets (wanted is keyed by the global setId; the dressing
        -- room resolves on a PTR client, and on live prints a "preview on the PTR"
        -- hint instead of opening an empty viewer — see Collected's DressingRoom).
        local onClick = function(c)
          if IsShiftKeyDown() then
            local nowWanted = WarbandeerCollectedApi:ToggleWanted(set.id)
            if self._wantedOnly and not nowWanted then
              self.data = self:GetData(); self:update()
            else
              self:_applyCellMarks(c, set.id)
            end
            if _view then _view:RefreshWanted() end
          else
            WarbandeerCollectedApi:ShowDressingRoom(grp, set, self._reverse)
          end
        end
        -- Upcoming (PTR): a muted dot, no count/completion shade.
        if self._ptr then
          return {
            setId = set.id,
            text = UPCOMING_GLYPH,
            justifyH = ui.justify.Center,
            color = UPCOMING,
            onEnter = onEnter, onLeave = onLeave, onClick = onClick,
          }
        end
        if isComplete(status) then
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
          onEnter = onEnter,
          onLeave = onLeave,
          onClick = onClick,
        }
      end)
      -- grp.sets can stop short of the newest classes (no Demon Hunter/Evoker entry
      -- in older raids), leaving those columns cell-less. Pad to the full class count
      -- so they blank out instead of keeping another row's value on re-sort.
      for i = #r + 1, #ns.icons.classes do r[i] = {} end
      table.insert(r, 1, { text = grp.name })
      return r
    end)
  end,
})

-- Per-cell rating overlays (gold wanted star top-left, tier letter in its tier
-- color top-right), mirroring Collected's own grid. Driven by live API state, so a
-- refresh after any update()/re-sort/toggle is enough.
local STAR = 11

---@param cell Cell
---@param setId number?
function Grid:_applyCellMarks(cell, setId)
  local api = WarbandeerCollectedApi
  if api and setId and api:IsWanted(setId) then
    if not cell._wantStar then
      cell._wantStar = Texture:new{
        parent = cell, layer = ui.layer.Overlay,
        atlas = api.WantedIcon, atlasSize = false,
        position = { TopLeft = {1, -1}, Size = {STAR, STAR} },
      }
    end
    cell._wantStar:Show()
  elseif cell._wantStar then
    cell._wantStar:Hide()
  end

  local rank = api and setId and api:EffectiveRank(setId, self._playerRace)
  if rank then
    if not cell._rankPip then
      cell._rankPip = Label:new{
        parent = cell, layer = ui.layer.Overlay, fontObj = "GameFontNormalSmall",
        position = { TopRight = {-1, 0} },
      }
    end
    cell._rankPip:Text(rank)
    cell._rankPip:Color(api.RankColors[rank])
    cell._rankPip:Show()
  elseif cell._rankPip then
    cell._rankPip:Hide()
  end
end

function Grid:_refreshMarks()
  local api = WarbandeerCollectedApi
  self._playerRace = api and api:PlayerRace()
  for r = 1, #self.cells do
    local row = self.cells[r]
    for c = 1, #self.cols do
      local cell = row[c]
      if cell then
        local data = cell.data
        self:_applyCellMarks(cell, type(data) == "table" and data.setId or nil)
      end
    end
  end
end

function Grid:update()
  TableFrame.update(self)
  self:_refreshMarks()
end

---Toggle the "wanted only" filter, rebuilding the grid so non-wanted cells blank out.
---@return boolean wantedOnly  the new filter state
function Grid:ToggleWantedOnly()
  self._wantedOnly = not self._wantedOnly
  self.data = self:GetData()
  self:update()
  return self._wantedOnly
end

---Switch between live and PTR ("upcoming") data, rebuilding the grid.
---@param on boolean  true → show api.PtrSets (upcoming), false → live api.Sets
---@return boolean ptr  the new mode
function Grid:SetPtr(on)
  self._ptr = on
  self.data = self:GetData()
  self:update()
  return self._ptr
end

-- ─── CollectedView ──────────────────────────────────────────────────────────

---@class CollectedView: Frame
---@field grid CollectedGrid
---@field scroll ScrollFrame
---@field counter Label
---@field wantedCount Label running "★ N" wanted-set count (mirrors the /collected window)
---@field emptyMsg Label
---@field _wantedBorder Texture "wanted only" filter border (gold while active)
---@field _ptrBorder Texture live/PTR toggle border (gold while in PTR mode)
---@field _sortBorder Texture raid-order toggle border (gold once newest-first)
---@field _sortLabel Label raid-order toggle caption
local CollectedView = Class(Frame, function(self)
  _view = self

  self.grid = Grid:new{
    parent = self,
    position = { TopLeft = {0, 0} },
  }

  local rowsH = self.grid.rowArea:Height()
  local capH = min(MAX_GRID_H, rowsH)
  local gridW = self.grid:Width()

  self.scroll = ui.ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {0, -self.grid.headerHeight},
      Width   = gridW,
      Height  = capH,
    },
  }
  self.scroll:Child(self.grid.rowArea)

  -- Counter rides the grid's header row, over the empty group-name column and in
  -- line with the class icons (mirrors the /collected window). Created after the
  -- grid so it draws above the header cells; vertically centred in the header.
  local hdrPad = (self.grid.headerHeight - theme.fonts.title[2]) / 2
  self.counter = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.text,
    position = { TopLeft = {2, -hdrPad} },
    text = "",
  }
  self.wantedCount = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.gold,
    position = { Left = {self.counter, ui.edge.Right, 16, 0} },
    text = "",
  }

  -- Shown when there's nothing to render (Collected not installed / never scanned).
  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {2, -self.grid.headerHeight - 6}, Width = 280, Height = 20, Hide = true },
  }

  self:Width(gridW + SCROLLBAR_W)
  self:Height(self.grid.headerHeight + capH + 4)
end, {})
CollectedView.name = "collected"
CollectedView._title = "Collected"
ns.views.CollectedView = CollectedView

-- Live-refresh this view's grid when a rating changes in the shared dressing room
-- (registered once at load; Collected loads first via the OptionalDep order).
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnRatingsChanged then
  WarbandeerCollectedApi:OnRatingsChanged(function()
    local g = _view and _view.grid
    if not g then return end
    if g._wantedOnly then g.data = g:GetData(); g:update() else g:_refreshMarks() end
    _view:RefreshWanted()
  end)
end

-- Refresh counts, grid data, and the empty-state message each time the view shows
-- (so a /collected scan run after the view was built is reflected on next open).
function CollectedView:OnBeforeShow()
  self:_render()
end

-- Render the active dataset (live or PTR). PTR mode needs no scan — it lists the
-- upcoming-only delta with a count + the PTR build instead of collected/total.
function CollectedView:_render()
  local api = WarbandeerCollectedApi
  if not api then
    self.counter:Text("")
    self.wantedCount:Text("")
    self.emptyMsg:Text("Collected add-on not loaded")
    self.emptyMsg:Show()
    return
  end
  if self.grid._ptr then
    self.emptyMsg:Hide()
    local n = 0
    for _, grp in ipairs(api.PtrSets or {}) do
      for _, set in ipairs(grp.sets) do if set.id then n = n + 1 end end
    end
    self.counter:Text(api.PtrBuild and ("Upcoming: %d  ·  PTR %s"):format(n, api.PtrBuild.ptr) or ("Upcoming: " .. n))
    self:RefreshWanted()
    self.grid.data = self.grid:GetData()
    self.grid:update()
    return
  end
  if not api:IsScanned() then
    self.counter:Text("")
    self.wantedCount:Text("")
    self.emptyMsg:Text("Run /collected scan to populate")
    self.emptyMsg:Show()
    return
  end
  self.emptyMsg:Hide()
  local collected, total = api:Counts()
  self.counter:Text("Sets: " .. collected .. " / " .. total)
  self:RefreshWanted()
  self.grid.data = self.grid:GetData()
  self.grid:update()
end

-- Refresh the running wanted-set count in the header (gold star + N), matching the
-- /collected window. The star is drawn from the shared WantedIcon atlas rather than
-- a literal glyph so it renders in the body font.
function CollectedView:RefreshWanted()
  local api = WarbandeerCollectedApi
  self.wantedCount:Text(api and (("|A:%s:14:14|a %d"):format(api.WantedIcon, api:WantedCount())) or "")
end

-- Titlebar control: three toggle buttons — a live/PTR preview switch, a "wanted
-- only" filter, and a raid (row) order flip (oldest/newest-first). Mirrors GearView's
-- filter chrome and the /collected window's own title-bar toggles.
function CollectedView:BuildFilter(parent)
  local BW, BH, PAD, GAP = 96, 20, 8, 6
  local box = Frame:new{ parent = parent, position = { Width = BW * 3 + GAP * 2, Height = BH } }

  -- One framed toggle at x; returns its (recolorable) border and caption.
  local function toggle(xoff, text, active, onClick)
    local b = Frame:new{ parent = box, position = { TopLeft = {xoff, 0}, Width = BW, Height = BH } }
    local border = Texture:new{
      parent = b, layer = ui.layer.Background,
      position = { All = true }, color = active and theme.colors.gold or theme.colors.divider,
    }
    Texture:new{
      parent = b, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
    }
    local btn = Button:new{ parent = b, position = { All = true }, glow = false, OnClick = onClick }
    local label = Label:new{
      parent = btn, fontInfo = {theme.fonts.caps[1], 10}, justifyH = ui.justify.Center,
      position = { Left = {PAD, 0}, Right = {-PAD, 0} }, text = text,
    }
    return border, label
  end

  self._ptrBorder = (toggle(0, "PTR PREVIEW", false, function()
    local on = self.grid:SetPtr(not self.grid._ptr)
    self._ptrBorder:Color(on and theme.colors.gold or theme.colors.divider)
    self:_render()
  end))

  self._wantedBorder = (toggle(BW + GAP, "WANTED ONLY", false, function()
    local on = self.grid:ToggleWantedOnly()
    self._wantedBorder:Color(on and theme.colors.gold or theme.colors.divider)
  end))

  self._sortBorder, self._sortLabel = toggle((BW + GAP) * 2, "NEWEST FIRST", true, function() self:_toggleSort() end)

  return box
end

-- Flip the grid's row order in place (cells are reused; see Cell:Label).
function CollectedView:_toggleSort()
  self.grid._reverse = not self.grid._reverse
  self._sortLabel:Text(self.grid._reverse and "NEWEST FIRST" or "OLDEST FIRST")
  self._sortBorder:Color(self.grid._reverse and theme.colors.gold or theme.colors.divider)
  self.grid.data = self.grid:GetData()
  self.grid:update()
end
