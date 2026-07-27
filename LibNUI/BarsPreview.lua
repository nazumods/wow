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
  -- top, bottom, left, right (one physical pixel), positioned from the preview's top-left.
  -- The bottom edge's own thickness is its offset from `b`, so it takes the snapped length
  -- too — an unsnapped 1 there would leave it a hair off the box it closes.
  local px = box[1]:Pixels(1)
  box[1]:ClearAllPoints(); box[1]:SetPoint("TOPLEFT", self, "TOPLEFT", l, t);      box[1]:Width(w); box[1]:PixelHeight(1)
  box[2]:ClearAllPoints(); box[2]:SetPoint("TOPLEFT", self, "TOPLEFT", l, b + px); box[2]:Width(w); box[2]:PixelHeight(1)
  box[3]:ClearAllPoints(); box[3]:SetPoint("TOPLEFT", self, "TOPLEFT", l, t);      box[3]:Height(h); box[3]:PixelWidth(1)
  box[4]:ClearAllPoints(); box[4]:SetPoint("TOPLEFT", self, "TOPLEFT", r, t);      box[4]:Height(h); box[4]:PixelWidth(1)
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
  local normalBars, sRows = {}, {}
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
      if stance then
        sRows[#sRows + 1] = n
      else
        -- Normal bars are placed by their real on-screen position (below).
        normalBars[#normalBars + 1] = { idx = n, x = (info and info.x) or 0, y = (info and info.y) or 0, vert = isVert }
      end
    end
  end
  for j = n + 1, self._numBars do self._barRows[j].rf:Hide() end
  self._numBars = n

  -- Normal bars (a fixed on-screen home) mirror their real topography, condensed:
  -- the HORIZONTAL bars form a coordinate-compressed block (screen X→columns, Y→rows,
  -- gaps removed, order + orientation preserved); the VERTICAL bars stack side-by-side
  -- at the same height, docked to whichever side (left/right) they really sit relative
  -- to the horizontal bars. Stance/Sky pages replace Bar 1 (no fixed home) + the pet
  -- sit in a gold-outlined group centred below. Falls back to a single stacked column
  -- when a profile predates barLayout (no positions).
  local EPS = 20  -- screen px within which bars share a column/row
  local function compress(bars, getAxis, descending)
    local seen = {}
    for _, b in ipairs(bars) do seen[getAxis(b)] = true end
    local sorted = {}
    for v in pairs(seen) do sorted[#sorted + 1] = v end
    table.sort(sorted, function(a, c) if descending then return a > c else return a < c end end)
    local idx, cur, last = {}, 0, nil
    for _, v in ipairs(sorted) do
      if last == nil or math.abs(v - last) > EPS then cur = cur + 1 end
      idx[v], last = cur, v
    end
    return idx
  end
  local function avgX(bars)
    if #bars == 0 then return 0 end
    local s = 0; for _, b in ipairs(bars) do s = s + b.x end; return s / #bars
  end

  local topoRight, topoBottom = P, -P
  local hBottomY, hCenterX = -P, P  -- horizontal block's bottom + centre (stance anchors here)
  if #normalBars > 0 then
    local hasPos = false
    for _, b in ipairs(normalBars) do if b.x ~= 0 or b.y ~= 0 then hasPos = true; break end end

    if not hasPos then
      local yy = -P
      for _, b in ipairs(normalBars) do
        local rf = self._barRows[b.idx].rf
        rf:ClearAllPoints()
        rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", P, yy)
        topoRight = math.max(topoRight, P + rf:Width())
        yy = yy - rf:Height() - BAR_GAP
      end
      topoBottom = yy + BAR_GAP
      hBottomY, hCenterX = topoBottom, P + (topoRight - P) / 2
    else
      local hBars, vBars = {}, {}
      for _, b in ipairs(normalBars) do
        if b.vert then vBars[#vBars + 1] = b else hBars[#hBars + 1] = b end
      end

      -- Horizontal block: coordinate-compressed grid, local offsets from (0,0).
      local hW, hH = 0, 0
      if #hBars > 0 then
        local colOf = compress(hBars, function(b) return b.x end, false)
        local rowOf = compress(hBars, function(b) return b.y end, true)  -- higher screen-Y = upper row
        local colW, rowH, nCols, nRows = {}, {}, 0, 0
        for _, b in ipairs(hBars) do
          local rf = self._barRows[b.idx].rf
          b.col, b.row = colOf[b.x], rowOf[b.y]
          colW[b.col] = math.max(colW[b.col] or 0, rf:Width())
          rowH[b.row] = math.max(rowH[b.row] or 0, rf:Height())
          nCols = math.max(nCols, b.col); nRows = math.max(nRows, b.row)
        end
        local colX, rowYo, xa, ya = {}, {}, 0, 0
        for c = 1, nCols do colX[c] = xa; xa = xa + (colW[c] or 0) + GAP end
        for r = 1, nRows do rowYo[r] = ya; ya = ya + (rowH[r] or 0) + BAR_GAP end
        for _, b in ipairs(hBars) do b.lx, b.ly = colX[b.col], rowYo[b.row] end
        hW, hH = math.max(0, xa - GAP), math.max(0, ya - BAR_GAP)
      end

      -- Vertical block: side-by-side in screen-X order, all top-aligned.
      local vW, vH = 0, 0
      if #vBars > 0 then
        table.sort(vBars, function(a, c) return a.x < c.x end)
        local xa = 0
        for _, b in ipairs(vBars) do
          local rf = self._barRows[b.idx].rf
          b.lx, b.ly = xa, 0
          xa = xa + rf:Width() + GAP
          vH = math.max(vH, rf:Height())
        end
        vW = math.max(0, xa - GAP)
      end

      -- Dock the vertical block on the side matching its real screen-X vs the
      -- horizontal bars (right for a right-side setup, left for a left-side one).
      local vRight = (#hBars == 0) or (avgX(vBars) >= avgX(hBars))
      local hBaseX, vBaseX
      if vRight then
        hBaseX = P
        vBaseX = P + hW + (hW > 0 and GAP or 0)
      else
        vBaseX = P
        hBaseX = P + vW + (vW > 0 and GAP or 0)
      end

      for _, b in ipairs(hBars) do
        local rf = self._barRows[b.idx].rf
        rf:ClearAllPoints()
        rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", hBaseX + b.lx, -(P + b.ly))
      end
      for _, b in ipairs(vBars) do
        local rf = self._barRows[b.idx].rf
        rf:ClearAllPoints()
        rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", vBaseX + b.lx, -(P + b.ly))
      end

      topoRight  = math.max((#hBars > 0 and hBaseX + hW or P), (#vBars > 0 and vBaseX + vW or P))
      topoBottom = -(P + math.max(hH, vH))
      if #hBars > 0 then
        hBottomY, hCenterX = -(P + hH), hBaseX + hW / 2
      else
        hBottomY, hCenterX = topoBottom, P + (topoRight - P) / 2
      end
    end
  end

  -- Stance / Sky / pet group: measured, then placed horizontally CENTRED over the
  -- content width, in a single gold outline below the topographic area.
  local sMaxW = 0
  for _, ri in ipairs(sRows) do sMaxW = math.max(sMaxW, self._barRows[ri].rf:Width()) end
  local contentW = math.max(topoRight - P, sMaxW)
  -- Tuck the group just under the HORIZONTAL block (not below the taller vertical
  -- bars), centred on it — it fills the empty space beneath the horizontal bars.
  local centerX = (#normalBars > 0) and hCenterX or (P + sMaxW / 2)
  -- A wide stance page under a narrow horizontal block can push the group's left edge
  -- (centerX - sMaxW/2) past the widget's own P margin; clamp so it never escapes left.
  centerX = math.max(centerX, P + sMaxW / 2)
  local sTop = (#normalBars > 0 and #sRows > 0) and (hBottomY - GAP - STANCE_PAD) or -P
  local sy = sTop
  for _, ri in ipairs(sRows) do
    local rf = self._barRows[ri].rf
    rf:ClearAllPoints()
    rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", centerX - rf:Width() / 2, sy)
    sy = sy - rf:Height() - BAR_GAP
  end
  local sBottom = (#sRows > 0) and (sy + BAR_GAP) or topoBottom

  self:_stanceOutline(centerX - sMaxW / 2, sTop, centerX + sMaxW / 2, sBottom, #sRows > 0)

  -- Resize self to fit the content width + both areas' depth.
  local bottomEdge = math.min(topoBottom, sBottom - (#sRows > 0 and STANCE_PAD or 0))
  self:Width(math.max(P + contentW + P, P + 80 + P))
  self:Height(-bottomEdge + P)
  self:Show()
end
