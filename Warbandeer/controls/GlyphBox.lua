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

-- Appearance box (Detail view, right column beneath Consumables): the character's cosmetic
-- appearance state, in up to two sections —
--   * "Appearance Glyphs"  — glyphs APPLIED to the character's active-spec spells
--     (per-character/per-spec, WarbandeerApi:GetAppliedGlyphs). Rendered as a labeled LIST:
--     WoW glyph items nearly all share one generic per-class tome icon, so the name (not the
--     icon) is what distinguishes them — applied glyphs are named in green, unapplied muted.
--   * "Barbershop Unlocks"  — ACCOUNT-WIDE Druid Marks / travel-form glyphs + Warlock demon
--     Grimoires (WarbandeerApi:GetAppearanceUnlocks). Rendered as an icon GRID (these have
--     distinct icons): owned full-colour with a gold border, missing dimmed.
-- Every entry hovers to its item tooltip. The whole box hides (zero height) for a class with
-- neither system (e.g. Evoker). Modelled on ConsumablesBox / SuggestedBox (Populate → height).

local PAD = 12          -- panel inner padding (matches the gear panel)
local HEADER_GAP = 6    -- section header → its content
local SECT_GAP = 12     -- gap between the two sections
local ROW_H = 18        -- one glyph list row
local ROW_ICON = 14     -- glyph list-row icon edge
local ICON = 26         -- unlock grid icon edge
local GAP = 5           -- gap between grid icons

---@class GlyphBox: Frame
---@field _rows table[]     pooled glyph list rows
---@field _nRows integer     visible list rows
---@field _cells table[]    pooled unlock grid cells
---@field _nCells integer    visible grid cells
---@field _headers Label[]   pooled section-header labels
local GlyphBox = Class(Frame, function(self)
  self._rows = {}
  self._nRows = 0
  self._cells = {}
  self._nCells = 0
  self._headers = {}
end, {
  background = theme.colors.module,
})
ns.GlyphBox = GlyphBox

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

-- Grab (or lazily create) a pooled glyph list row: a small icon + the glyph name, hovering
-- to the item's tooltip. The current item link is stashed on the frame.
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

-- Grab (or lazily create) a pooled unlock grid cell: an item icon with a gold "owned" border
-- and a hover tooltip. The current item link is stashed on the frame.
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

-- Resolve an item's icon fileID (fallback to a question mark + request a load) and its link
-- (fallback to a bare item link + request a load), for a cell/row about to show it.
---@param itemID integer
---@return integer icon, string link
local function itemVisual(itemID)
  local link = select(2, GetInfo(itemID))
  if not link then RequestItem(itemID) end
  return GetIcon(itemID) or QUESTION_ICON, link or ("item:" .. itemID)
end

-- Fill the box for `char` and return its content height (0 when the class has neither system —
-- the box hides and reserves no space). The caller sets the box width first.
---@param char Character
---@return number height
function GlyphBox:Populate(char)
  -- `scanned` is false when the character's *active* spec has never been scanned (an alt not
  -- seen in this spec) — its applied state is unknown, not confirmed-none. WoW only exposes the
  -- active spec's applied glyphs, so per-spec sets fill in as the character plays each spec.
  local applied, scanned = ns.api:GetAppliedGlyphs(char.name)
  local unlocks = ns.api:GetAppearanceUnlocks(char.name)
  local hasApplied = applied and #applied > 0
  local hasUnlocks = unlocks and #unlocks > 0
  if not hasApplied and not hasUnlocks then self:Hide(); return 0 end

  local c = theme.colors
  local innerW = self:Width() - 2 * PAD
  local y = PAD
  local ri, ci, hi = 0, 0, 0

  -- A section header with an owned/total count (green when complete). `unknown` (the active
  -- spec was never scanned) shows "? / total" instead — applied state is undiscovered, not none.
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

  -- Section 1 — applied glyphs, as a labeled list (glyph icons are near-identical, so the
  -- name carries the meaning): applied names in green, unapplied muted + a dimmed icon.
  if hasApplied then
    local owned = 0
    for _, it in ipairs(applied) do if it.applied then owned = owned + 1 end end
    header("APPEARANCE GLYPHS", owned, #applied, not scanned)
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

  -- Section 2 — account-wide unlocks, as an icon grid (distinct icons): owned full-colour with
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
  for i = hi + 1, #self._headers do self._headers[i]:Hide() end

  y = y - SECT_GAP + PAD -- trim the trailing section gap, add bottom padding
  self:Height(y)
  self:Show()
  return y
end
