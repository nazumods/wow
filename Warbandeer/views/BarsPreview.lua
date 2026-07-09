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
local LBL_W   = 56                   -- width of the horizontal label ("Class 1" fits)
local LBL_H   = 12                   -- height of "Bar N" label row
local LBL_GAP = 4                    -- gap between label row and icons
local STACK_W = 14                   -- width of the vertically-stacked label on vertical bars

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
  { pet = true, label = "Pet" },   -- from profile.petslots, not a slot range; a normal bar
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

-- Pet-bar slot icon/name: spell abilities resolve by ID; command tokens use the
-- texture captured with the profile (name-only can't resolve cross-character).
local function petTex(slot)
  if not slot then return nil end
  if slot.type == "spell" then return GetSpellTex and GetSpellTex(slot.index) or nil end
  return slot.tex   -- token (captured texture)
end
local function petName(slot)
  if not slot then return nil end
  if slot.type == "spell" then return GetSpellName and GetSpellName(slot.index) or nil end
  return slot.strindex   -- token command name
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

  -- Label + icon area are repositioned per render (horizontal bars label on top;
  -- vertical bars label stacked down the left), so anchor them in _showBar.
  row.lbl = Label:new{
    parent = rf, fontInfo = theme.fonts.body, color = theme.colors.muted,
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

  row.rf.background:Color(theme.colors.module)  -- clear any leftover hover highlight
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
        tex = petTex(pslot)
        cell._tipText = petName(pslot)
      else
        local slotNum = base + j - 1
        tex = slotTex(slotMap[slotNum], macroMap)
        cell._tipText = slotName(slotMap[slotNum], macroMap)
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

-- A single subtle gold outline drawn around the whole stance area. Given the
-- bounding box in the preview's coordinates (y negative = down), it lazily builds
-- four edges on first use and hides them when there are no stance bars.
local STANCE_PAD = 3
function BarsPreview:_stanceOutline(left, top, right, bottom, on)
  if not self._stanceBox then
    if not on then return end
    local function edge()
      return Texture:new{ parent = self, color = STANCE_BORDER, layer = ui.layer.Overlay, position = {} }
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
function BarsPreview:HighlightProfileBar(profileBar, on)
  local row = self._rowByBar[profileBar]
  if not row then return end
  row.rf.background:Color(on and theme.colors.selected or theme.colors.module)
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

  -- Real per-character geometry (addon-aware, captured with the profile); the Edit
  -- Mode layout is the orientation fallback when a bar isn't currently on screen
  -- (e.g. the main bar paged to a stance) or for pre-v2 profiles.
  local realLayout = profile.barLayout and next(profile.barLayout) and profile.barLayout or nil
  local editLayout = (WarbandeerBarsApi and profile.layoutName
    and WarbandeerBarsApi:GetLayout(profile.layoutName)) or nil

  -- The bar currently paging Bar 1 (the active stance/form/override page). A class
  -- page / Bonus / Sky is a *real* stance bar only when it replaces Bar 1 — i.e. it
  -- is this page, or it isn't a live bar of its own (an inactive page that only
  -- shows in its stance). Determined per profile, so it works for any class.
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
      -- Pet bar: grouped with the stance bars (it's special — different cell count —
      -- and more like them than a normal active bar). Shown whenever a pet bar was
      -- captured (hunters and warlocks always have one).
      info   = realLayout and realLayout.pet or nil
      render = next(petMap) ~= nil
      stance = true
    else
      base = (def.bar - 1) * 12 + 1
      local real = realLayout and realLayout[def.bar]
      if def.sys then
        -- A normal main bar is never hidden: render if it has content OR is enabled on
        -- screen (a main bar paged to a stance reports no live buttons, but it's still a
        -- real bar). Orientation: live geometry if shown, else Edit Mode, else default.
        info   = real or (editLayout and editLayout[def.sys]) or nil
        render = hasSlots(base) or real ~= nil
        stance = false
      elseif real and def.bar ~= mainPage then
        -- A live class-page bar at its own position is just a normal bar (its real
        -- orientation), not a stance bar.
        info, render, stance = real, true, false
      else
        -- A real stance bar: the active main-bar page, or an inactive page that only
        -- appears in its stance. Only shown when it actually has abilities on it (an
        -- empty, unused stance page like a spare Class 5 stays hidden). Horizontal.
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
  -- (whatever pages currently replace Bar 1) stack horizontally in a gold-outlined
  -- area below both.
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

  -- Single gold outline around the whole stance area.
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

-- ─── BarsPreviewFrame (companion box docked right of the main window) ────────
-- Plain box like the IconStrip rail: parented to the Bars view so it only shows
-- while that view does, and inherits the main window's strata/level.

---@class BarsPreviewFrame: CleanFrame
---@field title Label          "<character> — <spec>" heading
---@field _preview BarsPreview
---@field _dragStrip Frame     invisible grip over the heading row; drags the main window
---@field _dragBound boolean?  true once the strip has been wired to ns.MainWindow
local BarsPreviewFrame = Class(CleanFrame, function(self)
  self.title = Label:new{
    parent   = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {P, -P}, Height = LBL_H },
    wordWrap = false,
  }
  -- Invisible grip over the heading row (only — leaves the preview cells below it
  -- free for their hover tooltips). Anchored to both top corners so it spans the box
  -- and tracks width changes; wired to drag the main window in Set() (see below).
  self._dragStrip = Frame:new{
    parent   = self,
    position = {
      TopLeft  = {self, ui.edge.TopLeft, 0, 0},
      TopRight = {self, ui.edge.TopRight, 0, 0},
      Height   = P + LBL_H,
    },
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
  -- Bind the heading grip to the main window once it exists (it always does by the
  -- time a profile is shown — the window must be open for the Bars view to appear).
  if ns.MainWindow and not self._dragBound then
    ns.MainWindow:BindDragHandle(self._dragStrip)
    self._dragBound = true
  end
  self.title:Text(profile.char .. "  \226\128\148  " .. (profile.spec or "?"))
  self._preview:Set(profile)
  local w = self._preview:Width()
  self.title:Width(w - 2 * P)
  self:Width(w)
  self._preview._widget:SetWidth(w)
  self:Height(P + LBL_H + self._preview:Height())
  self:Show()
end
