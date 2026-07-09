---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local CleanFrame = ui.CleanFrame
local theme = ns.theme

-- ─── Layout ─────────────────────────────────────────────────────────────────────
local P, GAP  = 12, 8
local ICON_SZ, ICON_GAP = 22, 2
local CELL    = ICON_SZ + ICON_GAP   -- 24px per slot including gap
local BAR_GAP = 6                    -- gap between bar boxes
local BOX_P   = 6                    -- inner padding of each bar box
local LBL_W   = 36                   -- width of "Bar N" label
local LBL_H   = 12                   -- height of "Bar N" label row
local LBL_GAP = 4                    -- gap between label row and icons

-- Edit Mode systemIndex (Enum.EditModeActionBarSystemIndices) → first action
-- slot and binding command. 2/3 = bottom-left/right, 4/5 = right bars,
-- 6-8 = MultiBar5/6/7 (slots 145+; 73-144 are stance/possess pages).
local BAR_BASE = { 1, 61, 49, 25, 37, 145, 157, 169 }
local BAR_CMD  = {
  "ACTIONBUTTON",          "MULTIACTIONBAR1BUTTON", "MULTIACTIONBAR2BUTTON",
  "MULTIACTIONBAR3BUTTON", "MULTIACTIONBAR4BUTTON", "MULTIACTIONBAR5BUTTON",
  "MULTIACTIONBAR6BUTTON", "MULTIACTIONBAR7BUTTON",
}

-- Slot number → binding command name
local SLOT_CMD = {}
for _b, _base in ipairs(BAR_BASE) do
  for _n = 1, 12 do SLOT_CMD[_base + _n - 1] = BAR_CMD[_b] .. _n end
end

-- Render order + display labels, keyed by slot-range bar (`floor((slot-1)/12)+1`,
-- slot base = `(bar-1)*12+1`). The 8 main bars carry their Edit Mode `sys` index
-- (for the legacy layout fallback); the class/stance pages and Bonus/Sky are marked
-- `stance` so they render in a bordered group. Mirrors the apply panel's TOGGLES.
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
}

-- Subtle gold outline marking the stance/class-page group apart from normal bars.
local STANCE_BORDER = { theme.colors.gold[1], theme.colors.gold[2], theme.colors.gold[3], 0.35 }

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

local GetSpellTex  = (C_Spell and C_Spell.GetSpellTexture) or _G.GetSpellTexture
local GetSpellName = (C_Spell and C_Spell.GetSpellName)    or _G.GetSpellInfo
local GetItemTex   = (C_Item  and C_Item.GetItemIconByID)  or _G.GetItemIcon

local function slotTex(slot, macroMap)
  if not slot then return nil end
  local t = slot.type
  if t == "spell" then
    return GetSpellTex and GetSpellTex(slot.index) or nil
  elseif t == "item" or t == "toy" then
    return slot.index and GetItemTex and GetItemTex(slot.index) or nil
  elseif t == "macro" then
    -- Captured macro icons are numeric fileIDs (as strings); legacy ones may be
    -- bare texture names or full paths.
    local ic = macroMap[slot.index] and macroMap[slot.index].icon
    if not ic then return nil end
    local fileID = tonumber(ic)
    if fileID then return fileID end
    if ic:find("\\") or ic:find("/") then return ic end
    return "Interface\\Icons\\" .. ic
  elseif t == "summonmount" then
    -- Mounts/pets are account-wide, so journal lookups work cross-character.
    -- The "Random Favorite Mount" pseudo-ID has no journal entry.
    local _, _, icon = C_MountJournal.GetMountInfoByID(slot.index)
    return icon or "Interface\\Icons\\achievement_guildperk_mountup"
  elseif t == "summonpet" then
    local icon = slot.strindex and select(9, C_PetJournal.GetPetInfoByPetID(slot.strindex))
    return icon or "Interface\\Icons\\inv_pet_achievement_capturer"
  elseif t == "equipmentset" then
    return "Interface\\Icons\\inv_misc_enggizmos_19"
  elseif t == "flyout" then
    -- Flyout IDs have no texture of their own; show the first known spell's,
    -- or any spell's when viewing a character that the player can't match
    -- (isKnown is evaluated against the logged-in character).
    local _, _, numSlots = GetFlyoutInfo(slot.index)
    local fallback
    for i = 1, numSlots or 0 do
      local spellID, _, isKnown = GetFlyoutSlotInfo(slot.index, i)
      if spellID and spellID > 0 then
        local tex = GetSpellTex(spellID)
        if tex and isKnown then return tex end
        fallback = fallback or tex
      end
    end
    return fallback
  end
end

-- Display name for the hover tooltip; nil when nothing sensible is known.
local function slotName(slot, macroMap)
  if not slot then return nil end
  local t = slot.type
  if t == "spell" or t == "companion" then
    return GetSpellName and GetSpellName(slot.index) or nil
  elseif t == "item" or t == "toy" then
    return slot.index and C_Item.GetItemNameByID(slot.index) or nil
  elseif t == "macro" then
    local m = macroMap[slot.index]
    return m and m.name
  elseif t == "flyout" then
    return (GetFlyoutInfo(slot.index))
  elseif t == "summonmount" then
    local name = C_MountJournal.GetMountInfoByID(slot.index)
    return name or "Random Favorite Mount"
  elseif t == "summonpet" then
    local customName, petName
    if slot.strindex then
      customName = select(2, C_PetJournal.GetPetInfoByPetID(slot.strindex))
      petName    = select(8, C_PetJournal.GetPetInfoByPetID(slot.strindex))
    end
    return customName or petName or "Battle Pet"
  elseif t == "equipmentset" then
    return slot.strindex
  end
end

-- ─── BarsPreview ─────────────────────────────────────────────────────────────────

---@class BarsPreview: Frame
---@field _barRows  table[]
---@field _numBars  number
---@field _rowByBar table   slot-range bar → the row currently rendering it (for hover highlight)
local BarsPreview = Class(Frame, function(self)
  self._barRows  = {}
  self._numBars  = 0
  self._rowByBar = {}
  self:Height(P + 20 + P)
end, {})
---@class Warbandeer
---@field BarsPreview BarsPreview
ns.BarsPreview = BarsPreview

-- ─── Bar row pool ─────────────────────────────────────────────────────────────
-- Rows use absolute positioning set each time Set() is called; no chaining.

function BarsPreview:_barRow(i)
  local row = self._barRows[i]
  if row then return row end

  local rf = Frame:new{
    parent     = self,
    background = theme.colors.module,
    position   = { TopLeft = {P, -P}, Width = 1, Height = 1 },
  }
  row = { rf = rf, _cells = {} }

  row.lbl = Label:new{
    parent = rf, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {BOX_P, -BOX_P}, Width = LBL_W, Height = LBL_H },
  }
  row.iconArea = Frame:new{
    parent = rf,
    position = { TopLeft = {BOX_P, -(BOX_P + LBL_H + LBL_GAP)} },
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

function BarsPreview:_showBar(rowIdx, def, base, info, slotMap, macroMap, bindMap)
  local row      = self:_barRow(rowIdx)
  local numIcons = (info and info.numIcons) or 12
  local stacks   = math.max(1, (info and info.numRows) or 1)
  local isVert   = info and info.orientation == 1

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

  row.lbl:Text(def.label)
  row.rf.background:Color(theme.colors.module)  -- clear any leftover hover highlight
  self._rowByBar[def.bar] = row
  self:_stanceBorder(row, def.stance)

  for j = 1, 12 do
    local cell = row._cells[j]
    if j > numIcons then
      cell:Hide()
    else
      local slotNum = base + j - 1
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

      local tex = slotTex(slotMap[slotNum], macroMap)
      cell._tipText = slotName(slotMap[slotNum], macroMap)
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

  local iconW = gridCols * CELL - ICON_GAP
  local iconH = gridRows * CELL - ICON_GAP
  row.iconArea:Width(iconW)
  row.iconArea:Height(iconH)
  row.rf:Width(BOX_P * 2 + math.max(iconW, LBL_W))
  row.rf:Height(BOX_P * 2 + LBL_H + LBL_GAP + iconH)
  row.rf:Show()
  return isVert
end

-- Lazily add (or toggle) a subtle gold outline marking a stance/class-page row.
-- Edges anchor to the bar box and track its size; pooled rows reused as normal
-- bars hide the outline.
function BarsPreview:_stanceBorder(row, on)
  if not row.border then
    if not on then return end
    local rf = row.rf
    local function edge(pts)
      return Texture:new{ parent = rf, color = STANCE_BORDER, layer = ui.layer.Overlay, position = pts }
    end
    row.border = {
      edge{ TopLeft     = {rf, ui.edge.TopLeft,     0, 0}, TopRight    = {rf, ui.edge.TopRight,    0, 0}, Height = 1 },
      edge{ BottomLeft  = {rf, ui.edge.BottomLeft,  0, 0}, BottomRight = {rf, ui.edge.BottomRight, 0, 0}, Height = 1 },
      edge{ TopLeft     = {rf, ui.edge.TopLeft,     0, 0}, BottomLeft  = {rf, ui.edge.BottomLeft,  0, 0}, Width  = 1 },
      edge{ TopRight    = {rf, ui.edge.TopRight,    0, 0}, BottomRight = {rf, ui.edge.BottomRight, 0, 0}, Width  = 1 },
    }
  end
  for _, e in ipairs(row.border) do
    if on then e:Show() else e:Hide() end
  end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

---Highlight (or clear) the preview row that renders a given slot-range bar.
---No-op for bars the preview isn't currently showing (e.g. Pet, or a disabled bar).
---@param profileBar number
---@param on boolean
function BarsPreview:HighlightProfileBar(profileBar, on)
  local row = self._rowByBar[profileBar]
  if not row then return end
  row.rf.background:Color(on and theme.colors.selected or theme.colors.module)
end

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

  -- Prefer the real per-character geometry (addon-aware, captured with the profile);
  -- fall back to the Edit Mode layout for profiles captured before barLayout existed
  -- (or captured before frames were positioned, leaving it empty).
  local realLayout = profile.barLayout and next(profile.barLayout) and profile.barLayout or nil
  local editLayout = (not realLayout and WarbandeerBarsApi and profile.layoutName
    and WarbandeerBarsApi:GetLayout(profile.layoutName)) or nil

  -- With real geometry, render every bar the character has enabled (even empty ones);
  -- on the legacy path, render every bar that has slots. Track which rows are vertical.
  local n = 0
  self._rowByBar = {}
  local hRows, vRows = {}, {}
  for _, def in ipairs(BAR_ORDER) do
    local base = (def.bar - 1) * 12 + 1
    local info, render
    if realLayout then
      info   = realLayout[def.bar]
      render = info ~= nil
    elseif def.sys then
      -- Legacy path (pre-v2 profiles): only the 8 main bars, with slots, matching
      -- pre-#419 behavior — no real geometry to place the stance pages by.
      for slot = base, base + 11 do
        if slotMap[slot] then render = true; break end
      end
      info = editLayout and editLayout[def.sys] or nil
    end
    if render then
      n = n + 1
      local isVert = self:_showBar(n, def, base, info, slotMap, macroMap, bindMap)
      if isVert then vRows[#vRows + 1] = n else hRows[#hRows + 1] = n end
    end
  end
  for j = n + 1, self._numBars do self._barRows[j].rf:Hide() end
  self._numBars = n

  -- Horizontal bars stack top-to-bottom in a left column; vertical bars sit
  -- side by side to its right (stacking them too would get really tall).
  local hMaxW = 0
  for _, ri in ipairs(hRows) do hMaxW = math.max(hMaxW, self._barRows[ri].rf:Width()) end

  local hy = -P
  for _, ri in ipairs(hRows) do
    local rf = self._barRows[ri].rf
    rf:ClearAllPoints()
    rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", P, hy)
    hy = hy - rf:Height() - BAR_GAP
  end

  local vx, vMaxH = P + hMaxW + (#hRows > 0 and GAP or 0), 0
  for _, ri in ipairs(vRows) do
    local rf = self._barRows[ri].rf
    rf:ClearAllPoints()
    rf._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", vx, -P)
    vx = vx + rf:Width() + GAP
    vMaxH = math.max(vMaxH, rf:Height())
  end

  -- Resize self to fit both groups
  local hColH = math.max(0, -hy - P - BAR_GAP)
  local totalH = P + math.max(hColH, vMaxH)
  local totalW = (#vRows > 0 and vx - GAP or P + hMaxW) + P
  self:Width(math.max(totalW, P + 80 + P))
  self:Height(totalH + P)
  self:Show()
end

-- ─── BarsPreviewFrame (companion box docked right of the main window) ────────
-- Plain box like the IconStrip rail: parented to the Bars view so it only shows
-- while that view does, and inherits the main window's strata/level.

---@class BarsPreviewFrame: CleanFrame
---@field title Label          "<character> — <spec>" heading
---@field _preview BarsPreview
local BarsPreviewFrame = Class(CleanFrame, function(self)
  self.title = Label:new{
    parent   = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {P, -P}, Height = LBL_H },
    wordWrap = false,
  }
  self._preview = BarsPreview:new{
    parent   = self,
    position = { TopLeft = {0, -(P + LBL_H)}, Hide = true },
  }
  self:Hide()
end, {
  -- anchored to the (already clamped) window — same rule as IconStrip
  clamped    = false,
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
})
---@class Warbandeer
---@field BarsPreviewFrame BarsPreviewFrame
ns.BarsPreviewFrame = BarsPreviewFrame

---Forward a bar highlight to the inner preview (driven by the apply panel's toggle hover).
---@param profileBar number
---@param on boolean
function BarsPreviewFrame:HighlightProfileBar(profileBar, on)
  self._preview:HighlightProfileBar(profileBar, on)
end

---Point the preview box at a profile and show it; hide if profile is nil.
---@param profile table?
function BarsPreviewFrame:Set(profile)
  if not profile then self:Hide(); return end
  self.title:Text(profile.char .. "  \226\128\148  " .. (profile.spec or "?"))
  self._preview:Set(profile)
  local w = self._preview:Width()
  self.title:Width(w - 2 * P)
  self:Width(w)
  self._preview._widget:SetWidth(w)
  self:Height(P + LBL_H + self._preview:Height())
  self:Show()
end
