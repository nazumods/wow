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
-- appearance state, in up to two icon-grid sections —
--   * "Appearance Glyphs"  — glyphs APPLIED to the character's active-spec spells
--     (per-character/per-spec, WarbandeerApi:GetAppliedGlyphs).
--   * "Barbershop Unlocks"  — ACCOUNT-WIDE Druid Marks / travel-form glyphs + Warlock demon
--     Grimoires (WarbandeerApi:GetAppearanceUnlocks).
-- Each entry is an item icon: full-colour with a gold border when owned/applied, dimmed
-- otherwise; hover shows its item tooltip. The whole box hides (zero height) for a class with
-- neither system (e.g. Evoker). Modelled on ConsumablesBox / SuggestedBox (Populate → height).

local PAD = 12          -- panel inner padding (matches the gear panel)
local ICON = 26         -- icon edge
local GAP = 5           -- gap between icons
local HEADER_GAP = 6    -- section header → its grid
local SECT_GAP = 12     -- gap between the two sections

---@class GlyphBox: Frame
---@field _cells table[]    pooled icon cells (flat pool across both sections)
---@field _n integer         number of cells currently visible
---@field _headers Label[]   pooled section-header labels
local GlyphBox = Class(Frame, function(self)
  self._cells = {}
  self._n = 0
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

-- Grab (or lazily create) a pooled icon cell: an item icon with a gold "owned" border and a
-- hover that shows the item's tooltip. The current item link is stashed on the frame.
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
  local applied = ns.api:GetAppliedGlyphs(char.name)
  local unlocks = ns.api:GetAppearanceUnlocks(char.name)
  local hasApplied = applied and #applied > 0
  local hasUnlocks = unlocks and #unlocks > 0
  if not hasApplied and not hasUnlocks then self:Hide(); return 0 end

  local c = theme.colors
  local innerW = self:Width() - 2 * PAD
  local perRow = max(1, floor((innerW + GAP) / (ICON + GAP)))
  local y = PAD
  local ci, hi = 0, 0

  -- Render one section: a header with an owned/total count, then a wrapping icon grid.
  local function section(title, items, ownedKey)
    if not items or #items == 0 then return end
    local owned = 0
    for _, it in ipairs(items) do if it[ownedKey] then owned = owned + 1 end end

    hi = hi + 1
    local hdr = self:_header(hi)
    hdr:ClearAllPoints()
    hdr:TopLeft(self, ui.edge.TopLeft, PAD, -y)
    hdr:Text(("%s   %d / %d"):format(title, owned, #items))
    hdr:Color((owned == #items) and c.green or c.muted)
    y = y + hdr:Height() + HEADER_GAP

    local col = 0
    for _, it in ipairs(items) do
      ci = ci + 1
      local cell = self:_cell(ci)
      cell.frame:ClearAllPoints()
      cell.frame:TopLeft(self, ui.edge.TopLeft, PAD + col * (ICON + GAP), -y)
      cell.icon:Texture(GetIcon(it.itemID) or QUESTION_ICON)
      if it[ownedKey] then
        cell.icon:SetVertexColor(1, 1, 1, 1)
        cell.border:Show()
      else
        cell.icon:SetVertexColor(0.3, 0.3, 0.34, 1)
        cell.border:Hide()
      end
      local _, link = GetInfo(it.itemID)
      if not link then RequestItem(it.itemID) end
      cell.frame._itemLink = link or ("item:" .. it.itemID)
      cell.frame:Show()

      col = col + 1
      if col >= perRow then col = 0; y = y + ICON + GAP end
    end
    if col > 0 then y = y + ICON + GAP end
    y = y + SECT_GAP
  end

  section("APPEARANCE GLYPHS", applied, "applied")
  section("BARBERSHOP UNLOCKS", unlocks, "unlocked")

  for i = ci + 1, self._n do self._cells[i].frame:Hide() end
  self._n = ci
  for i = hi + 1, #self._headers do self._headers[i]:Hide() end

  y = y - SECT_GAP + PAD -- trim the trailing section gap, add bottom padding
  self:Height(y)
  self:Show()
  return y
end
