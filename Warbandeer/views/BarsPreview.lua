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
local BarsPreview = Class(Frame, function(self)
  self._barRows = {}
  self._numBars = 0
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

function BarsPreview:_showBar(rowIdx, sysIdx, barLayout, slotMap, macroMap, bindMap)
  local row      = self:_barRow(rowIdx)
  local numIcons = (barLayout and barLayout.numIcons) or 12
  local stacks   = math.max(1, (barLayout and barLayout.numRows) or 1)
  local base     = BAR_BASE[sysIdx]
  local isVert   = barLayout and barLayout.orientation == 1

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

  row.lbl:Text("Bar " .. sysIdx)

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

  -- Render all non-empty bars; track which row indices are vertical
  local n = 0
  local hRows, vRows = {}, {}
  for sysIdx = 1, #BAR_BASE do
    local base = BAR_BASE[sysIdx]
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
