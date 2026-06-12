---@type Warbandeer
local ns = select(2, ...)
-- luacheck: globals WarbandeerBarsApi UnitClass
local ui = ns.ui
local insert, sort = table.insert, table.sort
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local Button = ui.Button
local FilterDropdown = ns.FilterDropdown
local theme = ns.theme

-- ─── Layout ───────────────────────────────────────────────────────────────────

local VIEW_W  = 300
local P, GAP  = 12, 8
local DD_W    = math.floor((VIEW_W - 2 * P - GAP) / 2)  -- 134
local DD_H    = 20
local HDR_H   = 14
local ROW_H   = 22
local ROW_GAP = 2
local MAX_ROWS = 12
local NAME_W  = 150
local SPEC_W  = VIEW_W - 2 * P - NAME_W - GAP   -- 118

local SPEC_DD_X = P + DD_W + GAP

-- Absolute Y offsets (negative = down from view top)
local DD_Y   = -P
local DIV_Y  = DD_Y  - DD_H  - GAP
local HDR_Y  = DIV_Y - 1     - GAP
local LIST_Y = HDR_Y - HDR_H - 4

-- ─── BarsView ─────────────────────────────────────────────────────────────────

---@class BarsView: Frame
---@field _classID      string?
---@field _specID       number?
---@field _rows         table[]
---@field _numShown     number
---@field _selected     table?
---@field _results      table[]
---@field _specDD       FilterDropdown?
---@field _previewFrame BarsPreviewFrame?
---@field _applyFrame   BarsApplyFrame?
local BarsView = Class(Frame, function(self)
  self._classID  = nil
  self._specID   = nil
  self._rows     = {}
  self._numShown = 0
  self._selected = nil
  self._results  = {}

  -- Class selector (spec selector is rebuilt when class changes; see _buildSpecDD)
  local clsOpts = {{ key = nil, label = "All Classes" }}
  for _, cls in ipairs(ns.CLASSES) do
    insert(clsOpts, { key = cls.id, label = cls.name })
  end
  self.clsDD = FilterDropdown:new{
    parent    = self,
    options   = clsOpts,
    selected  = nil,
    width     = DD_W,
    menuWidth = DD_W,
    onSelect  = function(_, key) self:_setClass(key) end,
    position  = { TopLeft = {P, DD_Y} },
  }

  -- Divider
  Texture:new{
    parent   = self, color = theme.colors.divider,
    position = { TopLeft = {P, DIV_Y}, Width = VIEW_W - 2 * P, Height = 1 },
  }

  -- Column headers
  Label:new{
    parent   = self, text = "CHARACTER",
    fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {P, HDR_Y}, Width = NAME_W, Height = HDR_H },
  }
  Label:new{
    parent   = self, text = "SPEC",
    fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {P + NAME_W + GAP, HDR_Y}, Width = SPEC_W, Height = HDR_H },
  }

  -- Empty-list message
  self.emptyMsg = Label:new{
    parent   = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {P, LIST_Y}, Width = VIEW_W - 2 * P, Height = 20, Hide = true },
  }

  self:Width(VIEW_W)
  self:Height(-LIST_Y + 20 + GAP)
end, {})
BarsView.name = "bars"
BarsView._title = "Bars"
BarsView._iconRotation = math.pi / 2
ns.views.BarsView = BarsView

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

function BarsView:OnNavigate()
  -- Only reset the filter to the current player's class — and default the
  -- selection to the current character/spec profile — when there is no
  -- existing selection; preserves a cross-class selection on re-open.
  if not self._selected then
    local _, classToken = UnitClass("player")
    self._classID = classToken
    self._specID  = nil
    self.clsDD:Select(classToken)
    if WarbandeerBarsApi then
      self._selected = WarbandeerBarsApi:GetProfile()
    end
  end
end

function BarsView:OnBeforeShow()
  self:_buildSpecDD()
  self:_buildResultList()
end

-- ─── Spec dropdown (rebuilt per class) ───────────────────────────────────────

function BarsView:_buildSpecDD()
  if self._specDD then self._specDD:Hide() end
  local opts = {{ key = nil, label = "All Specs" }}
  for _, s in ipairs(self:_specsForClass(self._classID)) do
    insert(opts, { key = s.id, label = s.name })
  end
  self._specDD = FilterDropdown:new{
    parent    = self,
    options   = opts,
    selected  = self._specID,
    width     = DD_W,
    menuWidth = DD_W,
    onSelect  = function(_, key) self:_setSpec(key) end,
    position  = { TopLeft = {SPEC_DD_X, DD_Y} },
  }
end

function BarsView:_specsForClass(classID)
  if not WarbandeerBarsApi or not classID then return {} end
  local seen, specs = {}, {}
  for _, p in ipairs(WarbandeerBarsApi:GetAllProfiles()) do
    if p.class == classID and not seen[p.specID] then
      seen[p.specID] = true
      insert(specs, { id = p.specID, name = p.spec or "?" })
    end
  end
  sort(specs, function(a, b) return a.name < b.name end)
  return specs
end

function BarsView:_setClass(key)
  self._classID = key
  self._specID  = nil
  self:_buildSpecDD()
  self:_buildResultList()
end

function BarsView:_setSpec(key)
  self._specID = key
  self:_buildResultList()
end

-- ─── Result rows ──────────────────────────────────────────────────────────────

function BarsView:_resultRow(i)
  local row = self._rows[i]
  if row then return row end

  row = Button:new{
    parent     = self,
    glow       = false,
    background = {0, 0, 0, 0},
    position   = { Width = VIEW_W - 2 * P, Height = ROW_H },
  }
  row.nameLbl = Label:new{
    parent   = row, fontInfo = theme.fonts.body,
    position = { TopLeft = {0, -4}, Width = NAME_W, Height = ROW_H - 8 },
    wordWrap = false,
  }
  row.specLbl = Label:new{
    parent   = row, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {NAME_W + GAP, -4}, Width = SPEC_W, Height = ROW_H - 8 },
    wordWrap = false,
  }

  local r = row
  r.OnClick = function() self:_selectProfile(r._profile) end
  r.OnEnter = function()
    if self._selected ~= r._profile then r.background:Color(theme.colors.hover) end
  end
  r.OnLeave = function() self:_paintRow(r) end

  self._rows[i] = row
  return row
end

-- ─── List & selection ─────────────────────────────────────────────────────────

-- Resting backdrop for a result row: muted-gold wash if selected, transparent otherwise.
function BarsView:_paintRow(row)
  if self._selected == row._profile then
    row.background:Color(theme.colors.selected)
  else
    row.background:Color(0, 0, 0, 0)
  end
end

function BarsView:_buildResultList()
  self._results = {}
  if WarbandeerBarsApi then
    for _, p in ipairs(WarbandeerBarsApi:GetAllProfiles()) do
      if (not self._classID or p.class   == self._classID)
      and (not self._specID  or p.specID == self._specID) then
        insert(self._results, p)
      end
    end
    sort(self._results, function(a, b)
      if a.char ~= b.char then return a.char < b.char end
      return (a.spec or "") < (b.spec or "")
    end)
  end

  -- Invalidate selection if no longer in results
  if self._selected then
    local ok = false
    for _, p in ipairs(self._results) do if p == self._selected then ok = true; break end end
    if not ok then
      self._selected = nil
      if self._previewFrame then self._previewFrame:Hide() end
      if self._applyFrame   then self._applyFrame:Hide()   end
    end
  end

  local n = math.min(#self._results, MAX_ROWS)
  if n == 0 then
    self.emptyMsg:Text(WarbandeerBarsApi and "No matching profiles" or "Warbandeer Bars not loaded")
    self.emptyMsg:Show()
  else
    self.emptyMsg:Hide()
  end

  for i = 1, n do
    local p   = self._results[i]
    local row = self:_resultRow(i)
    row._profile = p
    row.nameLbl:Text(p.char)
    row.specLbl:Text(p.spec or "?")
    for _, cls in ipairs(ns.CLASSES) do
      if cls.id == p.class then row.nameLbl:Color(cls.color); break end
    end
    self:_paintRow(row)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self, "TOPLEFT", P, LIST_Y - (i - 1) * (ROW_H + ROW_GAP))
    row:Show()
  end

  for i = n + 1, #self._rows do self._rows[i]:Hide() end
  self._numShown = n

  -- Restore preview for the surviving selection (e.g. after closing and re-opening)
  if self._selected then
    self:_showSelection(self._selected)
  end

  self:_resize()
end

function BarsView:_getPreviewFrame()
  if not self._previewFrame then
    -- Parented to the view (shows/hides with it), docked right of the window.
    self._previewFrame = ns.BarsPreviewFrame:new{
      parent   = self,
      position = { TopLeft = {ns.MainWindow or self, ui.edge.TopRight, 8, 0} },
    }
  end
  return self._previewFrame
end

function BarsView:_getApplyFrame()
  if not self._applyFrame then
    -- Parented to the view (shows/hides with it), docked below the main window.
    self._applyFrame = ns.BarsApplyFrame:new{
      parent   = self,
      position = { TopLeft = {ns.MainWindow or self, ui.edge.BottomLeft, 0, -8} },
    }
  end
  return self._applyFrame
end

-- Show the preview + apply panels for a profile.
function BarsView:_showSelection(p)
  self:_getPreviewFrame():Set(p)
  self:_getApplyFrame():Set(p)
end

function BarsView:_selectProfile(p)
  if not p then return end
  self._selected = p
  for i = 1, self._numShown do self:_paintRow(self._rows[i]) end
  self:_showSelection(p)
end

function BarsView:_resize()
  local n = self._numShown
  local h = -LIST_Y + (n > 0 and n * ROW_H + (n - 1) * ROW_GAP or 20) + GAP
  self:Height(h)
  if ns.MainWindow then ns.MainWindow:Fit() end
end
