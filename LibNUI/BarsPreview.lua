---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture

-- Read-only action-bar layout preview. Renders a captured profile as its bars
-- really sit on screen — horizontal bars stacked in a left column, vertical bars
-- beside them, and the true stance bars (whatever pages currently replace Bar 1)
-- in a gold-outlined group below — using the per-profile `barLayout` captured via
-- ns.wow.ReadActionBars(). Consumer-agnostic: icon/name resolution for a profile's
-- slots is supplied as callbacks (each addon has its own slot schema), and the
-- styling colours are options (defaulting to the muted-glass look).

-- ─── Layout ─────────────────────────────────────────────────────────────────────
local P, GAP  = 12, 8
local ICON_SZ, ICON_GAP = 22, 2
local CELL    = ICON_SZ + ICON_GAP   -- 24px per slot including gap
local BAR_GAP = 6                    -- gap between bar boxes
local BOX_P   = 6                    -- inner padding of each bar box
local LBL_W   = 56                   -- width of the horizontal label ("Class 1" fits)
local LBL_H   = 12                   -- height of "Bar N" label row
local LBL_GAP = 4                    -- gap between label row and icons
local STACK_W = 14                   -- width of the vertically-stacked label on vertical bars
local STANCE_PAD = 3

-- Edit Mode systemIndex → first action slot and binding command. 2/3 =
-- bottom-left/right, 4/5 = right bars, 6-8 = MultiBar5/6/7 (slots 145+).
local BAR_CMD  = {
  "ACTIONBUTTON",          "MULTIACTIONBAR1BUTTON", "MULTIACTIONBAR2BUTTON",
  "MULTIACTIONBAR3BUTTON", "MULTIACTIONBAR4BUTTON", "MULTIACTIONBAR5BUTTON",
  "MULTIACTIONBAR6BUTTON", "MULTIACTIONBAR7BUTTON",
}

-- Slot number → binding command name
local SLOT_CMD = {}
do
  local BAR_BASE = { 1, 61, 49, 25, 37, 145, 157, 169 }
  for _b, _base in ipairs(BAR_BASE) do
    for _n = 1, 12 do SLOT_CMD[_base + _n - 1] = BAR_CMD[_b] .. _n end
  end
end

-- Render order + display labels, keyed by slot-range bar (`floor((slot-1)/12)+1`,
-- slot base = `(bar-1)*12+1`). The 8 main bars carry their Edit Mode `sys` index (for
-- the optional legacy layout fallback); the class/stance pages and Bonus/Sky are
-- marked `stance` so they render in a bordered group. Game-universal.
local BAR_ORDER = {
  { bar = 1,  sys = 1, label = "Bar 1" },
  { bar = 6,  sys = 2, label = "Bar 2" },
  { bar = 5,  sys = 3, label = "Bar 3" },
  { bar = 3,  sys = 4, label = "Bar 4" },
  { bar = 4,  sys = 5, label = "Bar 5" },
  { bar = 13, sys = 6, label = "Bar 6" },
  { bar = 14, sys = 7, label = "Bar 7" },
  { bar = 15, sys = 8, label = "Bar 8" },
  { bar = 7,  label = "Class 1", stance = true },
  { bar = 8,  label = "Class 2", stance = true },
  { bar = 9,  label = "Class 3", stance = true },
  { bar = 10, label = "Class 4", stance = true },
  { bar = 12, label = "Class 5", stance = true },
  { bar = 2,  label = "Bonus",   stance = true },
  { bar = 11, label = "Sky",     stance = true },
  { pet = true, label = "Pet" },   -- from profile.petslots, not a slot range
}

-- Abbreviate a WoW key name to a compact label (e.g. "SHIFT-1" → "s-1")
local function formatKey(key)
  if not key then return nil end
  local k = key
  k = k:gsub("SHIFT%-", "s-")
  k = k:gsub("CTRL%-",  "c-")
  k = k:gsub("ALT%-",   "a-")
  k = k:gsub("NUMPAD",  "N")
  if #k > 6 then k = k:sub(1, 6) end
  return k
end

-- Tiny outlined font for keybind labels; created once on first bar render.
local _kbFont
local function kbFont()
  if not _kbFont then
    local file = NumberFontNormalSmallGray:GetFont()
    _kbFont = CreateFont("LibNUIBarsPreviewKB")
    _kbFont:SetFont(file, 7, "OUTLINE")
  end
  return _kbFont
end

-- Stack a short label vertically, one char per line, so it reads top-to-bottom down
-- the side of a vertical bar (numbers kept whole after a blank line): "Class 2" ->
-- "C\nl\na\ns\ns\n\n2". Matches the in-game bar overlay.
local function stackText(s)
  local parts = {}
  for token in string.gmatch(s, "%S+") do
    if string.match(token, "^%d+$") then
      parts[#parts + 1] = token
    else
      local chars = {}
      for k = 1, #token do chars[k] = string.sub(token, k, k) end
      parts[#parts + 1] = table.concat(chars, "\n")
    end
  end
  return table.concat(parts, "\n\n")
end

-- ─── BarsPreview ─────────────────────────────────────────────────────────────────

---@class BarsPreview: Frame
---@field resolveIcon    fun(slot: table, macroMap: table): (string|number)?  icon for a normal action slot
---@field resolveName    fun(slot: table, macroMap: table): string?           hover name for a normal slot
---@field resolvePetIcon fun(slot: table): (string|number)?                   icon for a pet-bar slot
---@field resolvePetName fun(slot: table): string?                            hover name for a pet-bar slot
---@field editLayoutFor  fun(profile: table): table?                          optional {[sys]=info} orientation fallback
---@field rowColor       table  bar-box background rgba
---@field highlightColor table  hover/selected wash rgba (HighlightBar)
---@field labelColor     table|string  bar-label colour (token or rgba)
---@field stanceColor    table  stance-group outline rgba
---@field labelFontInfo  table?  {path, size} for bar labels
---@field _barRows  table[]
---@field _numBars  number
---@field _rowByBar table   slot-range bar → the row currently rendering it (for hover highlight)
local BarsPreview = Class(Frame, function(self)
  self._barRows  = {}
  self._numBars  = 0
  self._rowByBar = {}
  self:Height(P + 20 + P)
end, {
  rowColor       = {1, 1, 1, 0.05},          -- "glass-module" inner panel
  highlightColor = {0.90, 0.80, 0.50, 0.15}, -- muted artifact-gold wash
  labelColor     = "muted",
  stanceColor    = {1, 0.82, 0, 0.35},       -- gold outline
})
ui.BarsPreview = BarsPreview

-- ─── Bar row pool ─────────────────────────────────────────────────────────────
-- Rows use absolute positioning set each time Set() is called; no chaining.

function BarsPreview:_barRow(i)
  local row = self._barRows[i]
  if row then return row end

  local rf = Frame:new{
    parent     = self,
    background = self.rowColor,
    position   = { TopLeft = {P, -P}, Width = 1, Height = 1 },
  }
  row = { rf = rf, _cells = {} }

  -- Label + icon area are repositioned per render (horizontal bars label on top;
  -- vertical bars label stacked down the left), so anchor them in _showBar.
  row.lbl = Label:new{
    parent = rf, fontInfo = self.labelFontInfo, color = self.labelColor,
    justifyH = ui.justify.Center,
  }
  row.iconArea = Frame:new{ parent = rf }

  for j = 1, 12 do
    local cell = Frame:new{
      parent     = row.iconArea,
      background = {0, 0, 0, 0.5},
      position   = { Width = ICON_SZ, Height = ICON_SZ },
    }
    cell.icon = Texture:new{
      parent   = cell,
      layer    = ui.layer.Artwork,
      position = { All = true },
    }
    cell.kb = Label:new{
      parent   = cell,
      fontObj  = kbFont(),
      position = { TopRight = {-1, -1}, Width = ICON_SZ - 2, Height = 9, Hide = true },
    }
    cell.kb._widget:SetJustifyH("RIGHT")

    -- Hover tooltip with the slot's display name (set per render as _tipText)
    cell._widget:SetMouseMotionEnabled(true)
    cell:SetScript("OnEnter", function()
      if not cell._tipText then return end
      ui.tip:AnchorTo(cell, "ANCHOR_RIGHT", 4, 0)
      ui.tip:ClearLines()
      ui.tip:AddLine(cell._tipText)
      ui.tip:Show()
    end)
    cell:SetScript("OnLeave", function() ui.tip:Hide() end)

    row._cells[j] = cell
  end

  self._barRows[i] = row
  return row
end

-- ─── Render one bar ───────────────────────────────────────────────────────────
-- isVert: fill cells top-to-bottom (column-major) and report orientation.

function BarsPreview:_showBar(rowIdx, def, base, info, slotMap, macroMap, bindMap, petMap, stance)
  local row      = self:_barRow(rowIdx)
  local numIcons = (info and info.numIcons) or (def.pet and 10) or 12
  -- A bar rendered as a stance bar (it replaces Bar 1) always draws as one
  -- horizontal row in the dedicated stance area, whatever its real orientation.
  local stacks   = stance and 1 or math.max(1, (info and info.numRows) or 1)
  local isVert   = not stance and info and info.orientation == 1

  -- Edit Mode's "rows" setting counts stacks along the bar's short axis: rows
  -- when horizontal, columns when vertical.
  local gridRows, gridCols
  if isVert then
    gridCols = stacks
    gridRows = math.ceil(numIcons / stacks)
  else
    gridRows = stacks
    gridCols = math.ceil(numIcons / stacks)
  end

  row.rf.background:Color(self.rowColor)  -- clear any leftover hover highlight
  if def.bar then self._rowByBar[def.bar] = row end   -- pet has no slot-range bar

  local iconW = gridCols * CELL - ICON_GAP
  local iconH = gridRows * CELL - ICON_GAP

  -- Horizontal bars: label on top, icons below. Vertical bars: label stacked down
  -- the left, icons to its right (matches the in-game bar overlay). vColH is the
  -- taller of the icon column and the stacked label, so a short bar's label isn't clipped.
  local vColH = iconH
  row.lbl:ClearAllPoints()
  row.iconArea:ClearAllPoints()
  if isVert then
    row.lbl:Text(stackText(def.label))
    row.lbl:JustifyH(ui.justify.Center)
    row.lbl._widget:SetJustifyV("TOP")
    row.lbl:Width(STACK_W)
    vColH = math.max(iconH, row.lbl._widget:GetStringHeight())
    row.lbl:Height(vColH)
    row.lbl:SetPoint("TOPLEFT", row.rf, "TOPLEFT", BOX_P, -BOX_P)
    row.iconArea:SetPoint("TOPLEFT", row.rf, "TOPLEFT", BOX_P + STACK_W + LBL_GAP, -BOX_P)
  else
    row.lbl:Text(def.label)
    row.lbl:JustifyH(ui.justify.Left)
    row.lbl._widget:SetJustifyV("MIDDLE")
    row.lbl:SetPoint("TOPLEFT", row.rf, "TOPLEFT", BOX_P, -BOX_P)
    row.lbl:Width(LBL_W); row.lbl:Height(LBL_H)
    row.iconArea:SetPoint("TOPLEFT", row.rf, "TOPLEFT", BOX_P, -(BOX_P + LBL_H + LBL_GAP))
  end

  for j = 1, 12 do
    local cell = row._cells[j]
    if j > numIcons then
      cell:Hide()
    else
      -- Horizontal: fill left-to-right, rows growing upward (slot 1 is the
      -- bottom row, matching in-game). Vertical: fill top-to-bottom (column-major).
      local r, c
      if isVert then
        c = math.floor((j - 1) / gridRows)
        r = (j - 1) - c * gridRows
      else
        r = math.floor((j - 1) / gridCols)
        c = (j - 1) - r * gridCols
        r = gridRows - 1 - r
      end
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", row.iconArea, "TOPLEFT", c * CELL, -r * CELL)

      -- Pet rows draw from profile.petslots (keyed by pet slot id) with no keybinds;
      -- normal bars draw from the action slot map.
      local tex, key
      if def.pet then
        local pslot = petMap and petMap[j]
        tex = pslot and self.resolvePetIcon(pslot)
        cell._tipText = pslot and self.resolvePetName(pslot)
      else
        local slotNum = base + j - 1
        local slot = slotMap[slotNum]
        tex = slot and self.resolveIcon(slot, macroMap)
        cell._tipText = slot and self.resolveName(slot, macroMap)
        local cmd = SLOT_CMD[slotNum]
        key = cmd and bindMap and bindMap[cmd]
      end
      if tex then
        cell.icon:Texture(tex)
        cell.icon:Show()
        cell.background:Color(0, 0, 0, 0.5)
      else
        cell.icon:Hide()
        cell.background:Color(0, 0, 0, 0.25)
      end

      if key then
        cell.kb:Text(key)
        cell.kb:Show()
      else
        cell.kb:Hide()
      end

      cell:Show()
    end
  end

  row.iconArea:Width(iconW)
  row.iconArea:Height(iconH)
  if isVert then
    row.rf:Width(BOX_P * 2 + STACK_W + LBL_GAP + iconW)
    row.rf:Height(BOX_P * 2 + vColH)
  else
    row.rf:Width(BOX_P * 2 + math.max(iconW, LBL_W))
    row.rf:Height(BOX_P * 2 + LBL_H + LBL_GAP + iconH)
  end
  row.rf:Show()
  return isVert
end

-- A single subtle outline drawn around the whole stance area. Given the bounding
-- box in the preview's coordinates (y negative = down), it lazily builds four edges
-- on first use and hides them when there are no stance bars.
function BarsPreview:_stanceOutline(left, top, right, bottom, on)
  if not self._stanceBox then
    if not on then return end
    local function edge()
      return Texture:new{ parent = self, color = self.stanceColor, layer = ui.layer.Overlay, position = {} }
    end
    self._stanceBox = { edge(), edge(), edge(), edge() }
  end
  local box = self._stanceBox
  if not on then
    for _, e in ipairs(box) do e:Hide() end
    return
  end
  local l, t, r, b = left - STANCE_PAD, top + STANCE_PAD, right + STANCE_PAD, bottom - STANCE_PAD
  local w, h = r - l, t - b
  -- top, bottom, left, right (1px), positioned from the preview's top-left
  box[1]:ClearAllPoints(); box[1]:SetPoint("TOPLEFT", self, "TOPLEFT", l, t);     box[1]:Size(w, 1)
  box[2]:ClearAllPoints(); box[2]:SetPoint("TOPLEFT", self, "TOPLEFT", l, b + 1); box[2]:Size(w, 1)
  box[3]:ClearAllPoints(); box[3]:SetPoint("TOPLEFT", self, "TOPLEFT", l, t);     box[3]:Size(1, h)
  box[4]:ClearAllPoints(); box[4]:SetPoint("TOPLEFT", self, "TOPLEFT", r, t);     box[4]:Size(1, h)
  for _, e in ipairs(box) do e:Show() end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

---Highlight (or clear) the preview row that renders a given slot-range bar.
---No-op for bars the preview isn't currently showing (e.g. Pet, or a disabled bar).
---@param profileBar number
---@param on boolean
function BarsPreview:HighlightBar(profileBar, on)
  local row = self._rowByBar[profileBar]
  if not row then return end
  row.rf.background:Color(on and self.highlightColor or self.rowColor)
end

---Populate from a profile and show; hide if profile is nil.
---@param profile table?
function BarsPreview:Set(profile)
  if not profile then self:Hide(); return end

  local slotMap, macroMap, petMap = {}, {}, {}
  for _, s in ipairs(profile.slots    or {}) do slotMap[s.id]  = s end
  for _, m in ipairs(profile.macros   or {}) do macroMap[m.id] = m end
  for _, p in ipairs(profile.petslots or {}) do petMap[p.id]   = p end

  -- Build command → formatted key map; prefer key1 over key2
  local bindMap = {}
  for _, b in ipairs(profile.binds or {}) do
    if b.command and not bindMap[b.command] then
      local k = b.key1 or b.key2
      if k then bindMap[b.command] = formatKey(k) end
    end
  end

  -- Real per-character geometry (addon-aware, captured with the profile); the
  -- optional editLayoutFor callback supplies an orientation fallback when a bar
  -- isn't currently on screen (e.g. the main bar paged to a stance) or for older
  -- profiles without barLayout.
  local realLayout = profile.barLayout and next(profile.barLayout) and profile.barLayout or nil
  local editLayout = self.editLayoutFor and self.editLayoutFor(profile) or nil

  -- The bar currently paging Bar 1 (the active stance/form/override page). A class
  -- page / Bonus / Sky is a *real* stance bar only when it replaces Bar 1.
  local mainPage = realLayout and realLayout.mainPage

  local function hasSlots(base)
    for slot = base, base + 11 do
      if slotMap[slot] then return true end
    end
    return false
  end

  local n = 0
  self._rowByBar = {}
  local hRows, vRows, sRows = {}, {}, {}
  for _, def in ipairs(BAR_ORDER) do
    local info, render, base, stance
    if def.pet then
      -- Pet bar: grouped with the stance bars (it's special — different cell count).
      info   = realLayout and realLayout.pet or nil
      render = next(petMap) ~= nil
      stance = true
    else
      base = (def.bar - 1) * 12 + 1
      local real = realLayout and realLayout[def.bar]
      if def.sys then
        -- A normal main bar is never hidden: render if it has content OR is enabled
        -- on screen. Orientation: live geometry if shown, else Edit Mode, else default.
        info   = real or (editLayout and editLayout[def.sys]) or nil
        render = hasSlots(base) or real ~= nil
        stance = false
      elseif real and def.bar ~= mainPage then
        -- A live class-page bar at its own position is just a normal bar.
        info, render, stance = real, true, false
      else
        -- A real stance bar: the active main-bar page, or an inactive page that only
        -- appears in its stance. Only shown when it actually has abilities on it.
        info   = real or nil
        render = hasSlots(base)
        stance = true
      end
    end
    if render then
      n = n + 1
      local isVert = self:_showBar(n, def, base, info, slotMap, macroMap, bindMap, petMap, stance)
      if stance then sRows[#sRows + 1] = n
      elseif isVert then vRows[#vRows + 1] = n
      else hRows[#hRows + 1] = n end
    end
  end
  for j = n + 1, self._numBars do self._barRows[j].rf:Hide() end
  self._numBars = n

  -- Three areas: (1) normal horizontal bars stack top-to-bottom in a left column;
  -- (2) normal vertical bars sit side by side to its right; (3) the true stance bars
  -- stack horizontally in a gold-outlined area below both.
  local hMaxW = 0
  for _, ri in ipairs(hRows) do hMaxW = math.max(hMaxW, self._barRows[ri].rf:Width()) end

  local hy = -P
  for _, ri in ipairs(hRows) do
    local rf = self._barRows[ri].rf
    rf:ClearAllPoints()
    rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", P, hy)
    hy = hy - rf:Height() - BAR_GAP
  end
  local hBottom = (#hRows > 0) and (hy + BAR_GAP) or -P

  local vx, vMaxH = P + hMaxW + (#hRows > 0 and GAP or 0), 0
  for _, ri in ipairs(vRows) do
    local rf = self._barRows[ri].rf
    rf:ClearAllPoints()
    rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", vx, -P)
    vx = vx + rf:Width() + GAP
    vMaxH = math.max(vMaxH, rf:Height())
  end
  local vBottom = (#vRows > 0) and (-P - vMaxH) or -P

  -- Stance area: start a gap below the taller of the two top areas (or at the top if
  -- there are no normal bars). All stance bars are horizontal, so they stack cleanly.
  local topBottom = math.min(hBottom, vBottom)
  local sTop = ((#hRows > 0 or #vRows > 0) and #sRows > 0) and (topBottom - GAP - STANCE_PAD) or -P
  local sy, sMaxW = sTop, 0
  for _, ri in ipairs(sRows) do
    local rf = self._barRows[ri].rf
    rf:ClearAllPoints()
    rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", P, sy)
    sy = sy - rf:Height() - BAR_GAP
    sMaxW = math.max(sMaxW, rf:Width())
  end
  local sBottom = (#sRows > 0) and (sy + BAR_GAP) or topBottom

  -- Single outline around the whole stance area.
  self:_stanceOutline(P, sTop, P + sMaxW, sBottom, #sRows > 0)

  -- Resize self to fit all three areas (stance outline adds a little padding).
  local rightEdge = P + hMaxW
  if #vRows > 0 then rightEdge = math.max(rightEdge, vx - GAP) end
  if #sRows > 0 then rightEdge = math.max(rightEdge, P + sMaxW + STANCE_PAD) end
  local bottomEdge = math.min(hBottom, vBottom, sBottom - (#sRows > 0 and STANCE_PAD or 0))
  self:Width(math.max(rightEdge + P, P + 80 + P))
  self:Height(-bottomEdge + P)
  self:Show()
end
