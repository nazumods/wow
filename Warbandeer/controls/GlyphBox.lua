---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local theme = ns.theme
local floor, max = math.floor, math.max
local GetIcon = C_Item.GetItemIconByID
local GetInfo = C_Item.GetItemInfo
local RequestItem = C_Item.RequestLoadItemDataByID
local QUESTION_ICON = 134400 -- inv_misc_questionmark, for an item whose icon isn't cached yet

local C_Spec = C_SpecializationInfo
local GetNumSpecs = (C_Spec and C_Spec.GetNumSpecializationsForClassID) or _G.GetNumSpecializationsForClassID
local GetSpecInfo = (C_Spec and C_Spec.GetSpecializationInfoForClassID) or _G.GetSpecializationInfoForClassID

-- Appearance box (Detail view, right column beneath Consumables): the character's cosmetic
-- appearance state, in up to two sections —
--   * "Appearance Glyphs"  — glyphs APPLIED to the character's spells, PER SPEC. A spec-icon
--     picker selects which spec to show; it defaults to the character's active spec. Applied
--     state is discovered per spec (WoW only surfaces the active spec's glyphs reliably), so a
--     spec never captured reads "? / N" (unknown), not "0 / N". Rendered as a labeled LIST:
--     glyph items nearly all share one generic tome icon, so the name distinguishes them.
--   * "Barbershop Unlocks"  — ACCOUNT-WIDE Druid Marks / travel-form glyphs + Warlock demon
--     Grimoires (WarbandeerApi:GetAppearanceUnlocks). Rendered as an icon GRID.
-- Every entry hovers to its item tooltip. The whole box hides (zero height) for a class with
-- neither system (e.g. Evoker). Modelled on ConsumablesBox / SuggestedBox (Populate → height).

local PAD = 12          -- panel inner padding (matches the gear panel)
local HEADER_GAP = 6    -- section header → its content
local SECT_GAP = 12     -- gap between the two sections
local ROW_H = 18        -- one glyph list row
local ROW_ICON = 14     -- glyph list-row icon edge
local ICON = 26         -- unlock grid icon edge
local GAP = 5           -- gap between grid icons
local SPEC_ICON = 20    -- spec-picker button edge
local SPEC_GAP = 5      -- gap between spec buttons
local STRIP_GAP = 8     -- spec strip → glyph list

---@class GlyphBox: Frame
---@field onSpecChange fun()?  called when the spec picker changes, so the host re-lays-out
---@field _char Character?    the character last populated (spec selection resets on change)
---@field _specSel integer?   the currently-selected spec id
---@field _rows table[]        pooled glyph list rows
---@field _nRows integer
---@field _cells table[]      pooled unlock grid cells
---@field _nCells integer
---@field _specBtns table[]   pooled spec-picker buttons
---@field _nSpecBtns integer
---@field _headers Label[]    pooled section-header labels
local GlyphBox = Class(Frame, function(self)
  self._rows = {}
  self._nRows = 0
  self._cells = {}
  self._nCells = 0
  self._specBtns = {}
  self._nSpecBtns = 0
  self._headers = {}
end, {
  background = theme.colors.module,
})
ns.GlyphBox = GlyphBox

-- The class's specs as { id, name, icon }, in spec order (static class data; works for alts).
---@param classId integer
---@return { id: integer, name: string, icon: integer }[]
local function classSpecs(classId)
  local out = {}
  for i = 1, (GetNumSpecs(classId) or 0) do
    local id, name, _, icon = GetSpecInfo(classId, i)
    if id then out[#out + 1] = { id = id, name = name, icon = icon } end
  end
  return out
end

-- Resolve an item's icon fileID (fallback to a question mark + request a load) and its link
-- (fallback to a bare item link + request a load), for a cell/row about to show it.
---@param itemID integer
---@return integer icon, string link
local function itemVisual(itemID)
  local link = select(2, GetInfo(itemID))
  if not link then RequestItem(itemID) end
  return GetIcon(itemID) or QUESTION_ICON, link or ("item:" .. itemID)
end

-- Grab (or lazily create) a pooled section-header label.
---@param i integer
---@return Label
function GlyphBox:_header(i)
  local h = self._headers[i]
  if h then h:Show(); return h end
  h = Label:new{
    parent = self, fontInfo = theme.fonts.caps, color = theme.colors.muted,
    justifyH = ui.justify.Left, wordWrap = false,
  }
  self._headers[i] = h
  return h
end

-- Grab (or lazily create) a pooled spec-picker button: a spec icon that selects its spec on
-- click and shows the spec name on hover. Selected has a gold border + full colour; a spec with
-- captured data is normal; one never scanned is dimmed.
---@param i integer
---@return table
function GlyphBox:_specBtn(i)
  local b = self._specBtns[i]
  if b then return b end

  local frame = Frame:new{ parent = self, position = { Width = SPEC_ICON, Height = SPEC_ICON } }
  local border = Texture:new{
    parent = frame, layer = ui.layer.Background, color = theme.colors.gold,
    position = {
      TopLeft     = { frame, ui.edge.TopLeft, -1, 1 },
      BottomRight = { frame, ui.edge.BottomRight, 1, -1 },
      Hide = true,
    },
  }
  local icon = Texture:new{ parent = frame, layer = ui.layer.Artwork, position = { All = true } }

  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function()
    if frame._specName then
      local m = theme.colors.muted
      ns.AnchorTip(frame)
      ui.tip:ClearLines()
      ui.tip:AddLine(frame._specName)
      -- Explain a dimmed spec: WoW only exposes the active spec's glyphs, so an unplayed spec's
      -- applied state is unknown until it's next the active spec.
      if not frame._hasData then ui.tip:AddLine("Not yet scanned — play this spec to capture", m[1], m[2], m[3]) end
      ui.tip:Show()
    end
  end)
  frame:SetScript("OnLeave", function() ui.tip:Hide() end)
  frame:SetScript("OnMouseUp", function()
    if frame._specId and frame._specId ~= self._specSel then
      self._specSel = frame._specId
      if self.onSpecChange then self.onSpecChange() end
    end
  end)

  b = { frame = frame, icon = icon, border = border }
  self._specBtns[i] = b
  return b
end

-- Grab (or lazily create) a pooled glyph list row: a small icon + the glyph name.
---@param i integer
---@return table
function GlyphBox:_row(i)
  local row = self._rows[i]
  if row then return row end

  local frame = Frame:new{ parent = self, position = { Height = ROW_H } }
  local icon = Texture:new{
    parent = frame, layer = ui.layer.Artwork,
    position = { Left = { frame, ui.edge.Left, 0, 0 }, Width = ROW_ICON, Height = ROW_ICON },
  }
  local name = Label:new{
    parent = frame, fontInfo = theme.fonts.body, justifyH = ui.justify.Left, wordWrap = false,
    position = { Left = { frame, ui.edge.Left, ROW_ICON + 6, 0 }, Right = { frame, ui.edge.Right, 0, 0 } },
  }
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function()
    if frame._itemLink then ns.ShowItemTooltip(frame, frame._itemLink, nil, true) end
  end)
  frame:SetScript("OnLeave", function() ns.HideItemTooltip() end)

  row = { frame = frame, icon = icon, name = name }
  self._rows[i] = row
  return row
end

-- Grab (or lazily create) a pooled unlock grid cell: an item icon with a gold "owned" border.
---@param i integer
---@return table
function GlyphBox:_cell(i)
  local cell = self._cells[i]
  if cell then return cell end

  local frame = Frame:new{ parent = self, position = { Width = ICON, Height = ICON } }
  local border = Texture:new{
    parent = frame, layer = ui.layer.Background, color = theme.colors.gold,
    position = {
      TopLeft     = { frame, ui.edge.TopLeft, -1, 1 },
      BottomRight = { frame, ui.edge.BottomRight, 1, -1 },
      Hide = true,
    },
  }
  local icon = Texture:new{ parent = frame, layer = ui.layer.Artwork, position = { All = true } }

  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function()
    if frame._itemLink then ns.ShowItemTooltip(frame, frame._itemLink, nil, true) end
  end)
  frame:SetScript("OnLeave", function() ns.HideItemTooltip() end)

  cell = { frame = frame, icon = icon, border = border }
  self._cells[i] = cell
  return cell
end

-- Fill the box for `char` and return its content height (0 when the class has neither system —
-- the box hides and reserves no space). The caller sets the box width first.
---@param char Character
---@return number height
function GlyphBox:Populate(char)
  -- Selected spec: reset to the character's active spec when the subject changes; otherwise keep
  -- the picker's choice across re-renders. Fall back to the active/first spec if it went stale.
  local activeSpec = char.basic and char.basic.specialization and char.basic.specialization.id
  if char ~= self._char then self._char = char; self._specSel = activeSpec end
  local specs = classSpecs(char.classId)
  local validSel = false
  for _, sp in ipairs(specs) do if sp.id == self._specSel then validSel = true; break end end
  if not validSel then self._specSel = activeSpec or (specs[1] and specs[1].id) end

  local applied, scanned = ns.api:GetAppliedGlyphs(char.name, self._specSel)
  local tomes = ns.api:GetLearnedTomes(char.name)
  local unlocks = ns.api:GetAppearanceUnlocks(char.name)
  local hasApplied = applied and #applied > 0
  local hasTomes = tomes and #tomes > 0
  local hasUnlocks = unlocks and #unlocks > 0
  if not hasApplied and not hasTomes and not hasUnlocks then self:Hide(); return 0 end

  local c = theme.colors
  local innerW = self:Width() - 2 * PAD
  local y = PAD
  local ri, ci, hi, si = 0, 0, 0, 0

  -- A section header with an owned/total count (green when complete). `unknown` (the spec was
  -- never scanned) shows "? / total" instead — applied state is undiscovered, not none.
  local function header(title, owned, total, unknown)
    hi = hi + 1
    local hdr = self:_header(hi)
    hdr:ClearAllPoints()
    hdr:TopLeft(self, ui.edge.TopLeft, PAD, -y)
    if unknown then
      hdr:Text(("%s   ? / %d"):format(title, total)):Color(c.muted)
    else
      hdr:Text(("%s   %d / %d"):format(title, owned, total))
      hdr:Color((owned == total and total > 0) and c.green or c.muted)
    end
    y = y + hdr:Height() + HEADER_GAP
  end

  -- Section 1 — applied glyphs for the selected spec, with a spec-icon picker above the list.
  if hasApplied then
    local owned = 0
    for _, it in ipairs(applied) do if it.applied then owned = owned + 1 end end
    header("APPEARANCE GLYPHS", owned, #applied, not scanned)

    -- Spec picker strip (only worth showing when the class has more than one spec).
    if #specs > 1 then
      local storedBySpec = char.glyphs and char.glyphs.applied
      local x = PAD
      for _, sp in ipairs(specs) do
        si = si + 1
        local btn = self:_specBtn(si)
        btn.frame:ClearAllPoints()
        btn.frame:TopLeft(self, ui.edge.TopLeft, x, -y)
        btn.icon:Texture(sp.icon or QUESTION_ICON)
        local selected = sp.id == self._specSel
        local hasData = storedBySpec and storedBySpec[sp.id] ~= nil
        local shade = selected and 1 or (hasData and 0.75 or 0.4)
        btn.icon:SetVertexColor(shade, shade, shade, 1)
        if selected then btn.border:Show() else btn.border:Hide() end
        btn.frame._specId = sp.id
        btn.frame._specName = sp.name
        btn.frame._hasData = hasData
        btn.frame:Show()
        x = x + SPEC_ICON + SPEC_GAP
      end
      y = y + SPEC_ICON + STRIP_GAP
    end

    for _, it in ipairs(applied) do
      ri = ri + 1
      local row = self:_row(ri)
      row.frame:ClearAllPoints()
      row.frame:TopLeft(self, ui.edge.TopLeft, PAD, -y)
      row.frame:Width(innerW)
      local icon, link = itemVisual(it.itemID)
      row.icon:Texture(icon)
      row.icon:SetVertexColor(it.applied and 1 or 0.3, it.applied and 1 or 0.3, it.applied and 1 or 0.34, 1)
      row.name:Text(it.label):Color(it.applied and c.green or c.muted)
      row.frame._itemLink = link
      row.frame:Show()
      y = y + ROW_H
    end
    y = y + SECT_GAP
  end

  -- Section 2 — learned class tomes (Druid Tome of the Wilds), a labeled list like the glyphs:
  -- known in green, missing muted. The "Tome of the Wilds: " prefix is dropped (the header says it).
  if hasTomes then
    local owned = 0
    for _, it in ipairs(tomes) do if it.known then owned = owned + 1 end end
    header("TOME OF THE WILDS", owned, #tomes)
    for _, it in ipairs(tomes) do
      ri = ri + 1
      local row = self:_row(ri)
      row.frame:ClearAllPoints()
      row.frame:TopLeft(self, ui.edge.TopLeft, PAD, -y)
      row.frame:Width(innerW)
      local icon, link = itemVisual(it.itemID)
      row.icon:Texture(icon)
      row.icon:SetVertexColor(it.known and 1 or 0.3, it.known and 1 or 0.3, it.known and 1 or 0.34, 1)
      row.name:Text((it.label:gsub("^Tome of the Wilds: ", ""))):Color(it.known and c.green or c.muted)
      row.frame._itemLink = link
      row.frame:Show()
      y = y + ROW_H
    end
    y = y + SECT_GAP
  end

  -- Section 3 — account-wide unlocks, as an icon grid (distinct icons): owned full-colour with
  -- a gold border, missing dimmed.
  if hasUnlocks then
    local owned = 0
    for _, it in ipairs(unlocks) do if it.unlocked then owned = owned + 1 end end
    header("BARBERSHOP UNLOCKS", owned, #unlocks)
    local perRow = max(1, floor((innerW + GAP) / (ICON + GAP)))
    local col = 0
    for _, it in ipairs(unlocks) do
      ci = ci + 1
      local cell = self:_cell(ci)
      cell.frame:ClearAllPoints()
      cell.frame:TopLeft(self, ui.edge.TopLeft, PAD + col * (ICON + GAP), -y)
      local icon, link = itemVisual(it.itemID)
      cell.icon:Texture(icon)
      if it.unlocked then
        cell.icon:SetVertexColor(1, 1, 1, 1)
        cell.border:Show()
      else
        cell.icon:SetVertexColor(0.3, 0.3, 0.34, 1)
        cell.border:Hide()
      end
      cell.frame._itemLink = link
      cell.frame:Show()
      col = col + 1
      if col >= perRow then col = 0; y = y + ICON + GAP end
    end
    if col > 0 then y = y + ICON + GAP end
    y = y + SECT_GAP
  end

  for i = ri + 1, self._nRows do self._rows[i].frame:Hide() end
  self._nRows = ri
  for i = ci + 1, self._nCells do self._cells[i].frame:Hide() end
  self._nCells = ci
  for i = si + 1, self._nSpecBtns do self._specBtns[i].frame:Hide() end
  self._nSpecBtns = si
  for i = hi + 1, #self._headers do self._headers[i]:Hide() end

  y = y - SECT_GAP + PAD -- trim the trailing section gap, add bottom padding
  self:Height(y)
  self:Show()
  return y
end
