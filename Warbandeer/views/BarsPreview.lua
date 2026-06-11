---@type Warbandeer
local ns = select(2, ...)
-- luacheck: globals WarbandeerBarsApi NumberFontNormalSmallGray CreateFont
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local TitleFrame = ui.TitleFrame
local theme = ns.theme

-- ─── Layout ─────────────────────────────────────────────────────────────────────
local P, GAP  = 12, 8
local ICON_SZ, ICON_GAP = 22, 2
local CELL    = ICON_SZ + ICON_GAP   -- 24px per slot including gap
local BAR_GAP = 6                    -- vertical gap between bar rows
local LBL_W   = 36                   -- width of "Bar N" label

-- Edit Mode systemIndex → first action slot.
-- Indices 4/5 are MULTIACTIONBAR1/2 (right bars), 6 is MULTIACTIONBAR3 (bottom-left).
local BAR_BASE = { 1, 61, 25, 49, 37, 13, 73, 85 }

-- Slot number → binding command name (standard WoW action slot layout)
local SLOT_CMD = {}
for _n = 1, 12 do
  SLOT_CMD[_n]      = "ACTIONBUTTON"          .. _n
  SLOT_CMD[12 + _n] = "MULTIACTIONBAR3BUTTON" .. _n
  SLOT_CMD[24 + _n] = "MULTIACTIONBAR5BUTTON" .. _n
  SLOT_CMD[36 + _n] = "MULTIACTIONBAR4BUTTON" .. _n
  SLOT_CMD[48 + _n] = "MULTIACTIONBAR2BUTTON" .. _n
  SLOT_CMD[60 + _n] = "MULTIACTIONBAR1BUTTON" .. _n
  SLOT_CMD[72 + _n] = "MULTIACTIONBAR6BUTTON" .. _n
end

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

-- Tiny outlined font for keybind labels; created once on first bar render
local _kbFont
local function kbFont()
  if not _kbFont then
    local file = NumberFontNormalSmallGray:GetFont()
    _kbFont = CreateFont("WarbandeerBarsKB")
    _kbFont:SetFont(file, 7, "OUTLINE")
  end
  return _kbFont
end

local GetSpellTex = (C_Spell and C_Spell.GetSpellTexture) or _G.GetSpellTexture
local GetItemTex  = (C_Item  and C_Item.GetItemIconByID)  or _G.GetItemIcon

local function slotTex(slot, macroMap)
  if not slot then return nil end
  local t = slot.type
  if t == "spell" then
    return GetSpellTex and GetSpellTex(slot.index) or nil
  elseif t == "item" then
    return GetItemTex  and GetItemTex(slot.index)  or nil
  elseif t == "macro" then
    local m = macroMap[slot.index]
    return m and ("Interface\\Icons\\" .. m.icon) or nil
  elseif t == "summonmount" then
    return "Interface\\Icons\\ability_mount_summonplayersmount"
  elseif t == "summonpet" then
    return "Interface\\Icons\\inv_pet_achievement_capturer"
  elseif t == "equipmentset" then
    return "Interface\\Icons\\inv_misc_enggizmos_19"
  elseif t == "flyout" then
    return "Interface\\Icons\\ability_hunter_displacement"
  end
end

-- ─── BarsPreview ─────────────────────────────────────────────────────────────────

---@class BarsPreview: Frame
---@field _barRows  table[]
---@field _numBars  number
local BarsPreview = Class(Frame, function(self)
  self._barRows = {}
  self._numBars = 0
  self.header = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {P, -P} },
  }
  self:Height(P + 20 + P)
end, {
  background = theme.colors.module,
})
ns.BarsPreview = BarsPreview

-- ─── Bar row pool ─────────────────────────────────────────────────────────────
-- Rows use absolute positioning set each time Set() is called; no chaining.

function BarsPreview:_barRow(i)
  local row = self._barRows[i]
  if row then return row end

  local rf = Frame:new{
    parent = self,
    position = { TopLeft = {P, -P}, Width = 1, Height = 1 },
  }
  row = { rf = rf, _cells = {} }

  row.lbl = Label:new{
    parent = rf, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { Left = {0, 0}, Width = LBL_W, Top = {0, 0} },
  }
  row.iconArea = Frame:new{
    parent = rf,
    position = { Left = {LBL_W + GAP, 0}, Top = {0, 0} },
  }

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
    row._cells[j] = cell
  end

  self._barRows[i] = row
  return row
end

-- ─── Render one bar ───────────────────────────────────────────────────────────
-- isVert: fill cells top-to-bottom (column-major) and report orientation.

function BarsPreview:_showBar(rowIdx, sysIdx, barLayout, slotMap, macroMap, bindMap)
  local row      = self:_barRow(rowIdx)
  local numIcons = (barLayout and barLayout.numIcons) or 12
  local numRows  = math.max(1, (barLayout and barLayout.numRows) or 1)
  local numCols  = math.ceil(numIcons / numRows)
  local base     = BAR_BASE[sysIdx] or ((sysIdx - 1) * 12 + 1)
  local isVert   = barLayout and barLayout.orientation == 1

  row.lbl:Text("Bar " .. sysIdx)

  for j = 1, 12 do
    local cell = row._cells[j]
    if j > numIcons then
      cell:Hide()
    else
      local slotNum = base + j - 1
      -- Horizontal: fill left-to-right. Vertical: fill top-to-bottom (column-major).
      local r, c
      if isVert then
        c = math.floor((j - 1) / numRows)
        r = (j - 1) - c * numRows
      else
        r = math.floor((j - 1) / numCols)
        c = (j - 1) - r * numCols
      end
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", row.iconArea, "TOPLEFT", c * CELL, -r * CELL)

      local tex = slotTex(slotMap[slotNum], macroMap)
      if tex then
        cell.icon:Texture(tex)
        cell.icon:Show()
        cell.background:Color(0, 0, 0, 0.5)
      else
        cell.icon:Hide()
        cell.background:Color(0, 0, 0, 0.25)
      end

      local cmd = SLOT_CMD[slotNum]
      local key = cmd and bindMap and bindMap[cmd]
      if key then
        cell.kb:Text(key)
        cell.kb:Show()
      else
        cell.kb:Hide()
      end

      cell:Show()
    end
  end

  local iconW = numCols * CELL - ICON_GAP
  local iconH = numRows * CELL - ICON_GAP
  row.iconArea:Width(iconW)
  row.iconArea:Height(iconH)
  row.rf:Width(LBL_W + GAP + iconW)
  row.rf:Height(iconH)
  row.rf:Show()
  return isVert
end

-- ─── Public API ───────────────────────────────────────────────────────────────

---Populate from a profile and show; hide if profile is nil.
---@param profile table?
function BarsPreview:Set(profile)
  if not profile then self:Hide(); return end

  local slotMap, macroMap = {}, {}
  for _, s in ipairs(profile.slots  or {}) do slotMap[s.id]  = s end
  for _, m in ipairs(profile.macros or {}) do macroMap[m.id] = m end

  -- Build command → formatted key map; prefer key1 over key2
  local bindMap = {}
  for _, b in ipairs(profile.binds or {}) do
    if b.command and not bindMap[b.command] then
      local k = b.key1 or b.key2
      if k then bindMap[b.command] = formatKey(k) end
    end
  end

  local barsApi    = WarbandeerBarsApi
  local layoutBars = (barsApi and profile.layoutName
    and barsApi:GetLayout(profile.layoutName)) or {}

  local bindStr = profile.bindingSet == 2 and "  ·  Per-Char Binds" or ""
  local layStr  = profile.layoutName and ("  ·  " .. profile.layoutName) or ""
  self.header:Text(profile.spec .. bindStr .. layStr)

  -- Render all non-empty bars; track which row indices are vertical
  local n = 0
  local hRows, vRows = {}, {}
  for sysIdx = 1, 8 do
    local base = BAR_BASE[sysIdx] or ((sysIdx - 1) * 12 + 1)
    local hasSeen = false
    for slot = base, base + 11 do
      if slotMap[slot] then hasSeen = true; break end
    end
    if hasSeen then
      n = n + 1
      local isVert = self:_showBar(n, sysIdx, layoutBars[sysIdx], slotMap, macroMap, bindMap)
      if isVert then
        vRows[#vRows + 1] = n
      else
        hRows[#hRows + 1] = n
      end
    end
  end
  for j = n + 1, self._numBars do self._barRows[j].rf:Hide() end
  self._numBars = n

  -- Measure column widths
  local hMaxW, vMaxW = 0, 0
  for _, ri in ipairs(hRows) do hMaxW = math.max(hMaxW, self._barRows[ri].rf:Width()) end
  for _, ri in ipairs(vRows) do vMaxW = math.max(vMaxW, self._barRows[ri].rf:Width()) end

  -- Absolute-position all rows into two columns anchored to self
  local headerH   = P + self.header:Height() + GAP
  local leftX     = P
  local rightX    = P + hMaxW + (#vRows > 0 and GAP or 0)

  local hy = -headerH
  for _, ri in ipairs(hRows) do
    local rf = self._barRows[ri].rf
    rf:ClearAllPoints()
    rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", leftX, hy)
    hy = hy - rf:Height() - BAR_GAP
  end

  local vy = -headerH
  for _, ri in ipairs(vRows) do
    local rf = self._barRows[ri].rf
    rf:ClearAllPoints()
    rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", rightX, vy)
    vy = vy - rf:Height() - BAR_GAP
  end

  -- Resize self to fit both columns
  local hColH = math.max(0, -hy - headerH - BAR_GAP)
  local vColH = math.max(0, -vy - headerH - BAR_GAP)
  local totalH = headerH + math.max(hColH, vColH)
  local totalW = P + hMaxW + (#vRows > 0 and GAP + vMaxW or 0) + P
  self:Width(math.max(totalW, P + 80 + P))
  self:Height(totalH + P)
  self:Show()
end

-- ─── BarsPreviewFrame (separate floating window) ─────────────────────────────

local FRAME_W = 354

---@class BarsPreviewFrame: TitleFrame
local BarsPreviewFrame = Class(TitleFrame, function(self)
  self._preview = BarsPreview:new{
    parent   = self,
    position = { TopLeft = {0, -30}, Width = FRAME_W, Hide = true },
  }
  self:Width(FRAME_W)
  self:Height(30)
  self:Hide()
end, {
  special    = true,
  name       = "WarbandeerBarsPreview",
  title      = "Warbandeer | Bars",
  theme      = ns.theme,
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
})
ns.BarsPreviewFrame = BarsPreviewFrame

function BarsPreviewFrame:Set(profile)
  if not profile then self:Hide(); return end
  self:Title(profile.char .. "  \226\128\148  " .. (profile.spec or "?"))
  self._preview:Set(profile)
  local w = self._preview:Width()
  self:Width(w)
  self._preview._widget:SetWidth(w)
  self:Height(30 + self._preview:Height())
  self:Show()
end
