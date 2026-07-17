---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local theme = ns.theme
local Class, Texture, Button, Label = ns.lua.Class, ui.Texture, ui.Button, ui.Label
local map = ns.lua.lists.map

-- Faction modes, left→right (also the segment order) — the Alliance/Horde/Both display methodology
-- is modelled on the Summary view's, kept self-contained here so Summary stays untouched.
local FACTIONS = { "alliance", "horde", "both" }
local FACTION_COLOR = {
  alliance = { 0.40, 0.733, 1.0, 1 },
  horde    = { 1.0,  0.125, 0.125, 1 },
  both     = theme.colors.gold,
}

local SCROLLBAR_W = 16
local WINDOW_CHROME = 34
local FOOTER_H = 18
local COL_GUTTER = 5

-- A large roster (or the merged "both" list) can exceed the screen; cap the scroll viewport so the
-- window stays within ~95% of the display height and the rows scroll instead.
local function maxTableHeight()
  return UIParent:GetHeight() * 0.95 - WINDOW_CHROME
end

-- colInfo for the vault columns: uppercased headers, a gutter left of every column but the first,
-- and the outer columns inset off the table edge. A fresh list per table.
local function buildColInfo()
  return map(ns.VaultColumns, function(c, i)
    local info = {}
    for k, v in pairs(c.colInfo) do info[k] = v end
    if info.name and info.name ~= "" then info.name = info.name:upper() end
    if i > 1 then info.padLeft = (info.padLeft or 0) + COL_GUTTER end
    if i == 1 then info.hPadL = 8 end
    if i == #ns.VaultColumns then info.hPadR = 8 end
    return info
  end)
end

---@class VaultView: Frame
---@field alliance VaultRoster
---@field horde VaultRoster
---@field both VaultRoster
---@field footer Label                        warband tally under the table
---@field _scrolls table<string, ScrollFrame>  faction mode -> the table's capped scroll host
---@field _faction "alliance"|"horde"|"both"
---@field _segments table<string, Frame>?      titlebar faction segments (built by BuildFilter)
---@field _filter Frame?                        titlebar faction segmented control
---@field _healed table<string, boolean>        faction tables already cold-font-healed while visible
local VaultView = Class(ui.Frame, function(self)
  local current = ns.api:GetCharacterData()
  self._faction = (not current or current.isAlliance) and "alliance" or "horde"
  self._healed = {}
  self._scrolls = {}

  -- Each table renders its header + column backgrounds; only its row area scrolls (hosted in a
  -- ScrollFrame just below the header), so header + footer stay pinned for a tall warband.
  local function makeTable(faction)
    local tbl = ns.VaultRoster:new{
      parent = self,
      position = { TopLeft = { 0, 0 } },
      faction = faction,
      colInfo = buildColInfo(),
    }
    local scroll = ui.ScrollFrame:new{
      parent = self,
      scrollbar = true,
      scrollbarWidth = SCROLLBAR_W,
      position = { TopLeft = { 0, -tbl.headerHeight } },
    }
    scroll:Child(tbl.rowArea)
    self._scrolls[faction] = scroll
    return tbl
  end
  self.alliance = makeTable("alliance")
  self.horde    = makeTable("horde")
  self.both     = makeTable("both")

  self.footer = Label:new{
    parent = self,
    color = { 1, 1, 1, 0.55 },
    justifyH = ui.justify.Left,
    position = { TopLeft = { 2, -1 } },
  }

  self:layout()
  self:_healFaction(self._faction)
end, {
  name = "vault",
  background = theme.colors.window,
})
VaultView.name = "vault"
VaultView._title = "Great Vault"
ns.views.VaultView = VaultView

---@return VaultRoster
function VaultView:_activeTable()
  if self._faction == "horde" then return self.horde end
  if self._faction == "both" then return self.both end
  return self.alliance
end

-- Warband tally under the table: character count + how many have an unclaimed vault reward.
function VaultView:_updateFooter()
  local toons = self:_activeTable()._toons
  local n, unclaimed = #toons, 0
  for _, t in ipairs(toons) do
    if t.weeklies and t.weeklies.hasUnclaimedVault then unclaimed = unclaimed + 1 end
  end
  local s = n .. (n == 1 and " character" or " characters")
  if unclaimed > 0 then s = s .. "   |cffe6c35c" .. unclaimed .. "|r with an unclaimed reward" end
  self.footer:Text(s)
end

function VaultView:layout()
  for _, f in ipairs(FACTIONS) do
    local shown = self._faction == f
    self[f]:SetShown(shown)
    self._scrolls[f]:SetShown(shown)
  end

  local t = self:_activeTable()
  local scroll = self._scrolls[self._faction]
  local headerH = t.headerHeight
  local rowsH = t.rowArea:Height()
  local avail = maxTableHeight() - headerH - FOOTER_H
  -- treat a roster within ~0.5px of fitting as fitting, so float noise never trips a scrollbar
  local capH = rowsH <= avail + 0.5 and rowsH or avail
  scroll:Height(capH)
  scroll:Refresh()
  local scrolling = scroll:Scrolls()  -- reserve the gutter only when the bar actually shows
  scroll:Width(t:Width() + (scrolling and SCROLLBAR_W or 0))
  t:Height(headerH + capH)  -- table frame covers header + visible rows (column backgrounds)

  self:_updateFooter()
  self.footer:ClearAllPoints()
  self.footer:TopLeft(scroll, ui.edge.BottomLeft, 2, -4)

  self:Width(scroll:Width())
  self:Height(headerH + capH + FOOTER_H)
end

---@param mode "alliance"|"horde"|"both"
function VaultView:setFaction(mode)
  if self._faction == mode then return end
  self._faction = mode
  self:updateFilter()
  self:_activeTable():OnBeforeShow()  -- refresh the newly shown roster before sizing
  self:layout()
  self:_healFaction(mode)
  if ns.MainWindow then ns.MainWindow:Fit() end
end

-- Cold-session cell-font heal, once per faction, one tick after it first becomes visible (see
-- ns.HealCellFonts): only the shown roster can be healed, so the two that start hidden are healed
-- the first time they're switched to.
---@param faction "alliance"|"horde"|"both"
function VaultView:_healFaction(faction)
  if self._healed[faction] then return end
  ns:after(50, function()
    if self._faction ~= faction then return end
    self._healed[faction] = true
    ns.HealCellFonts(self[faction])
  end)
end

function VaultView:OnBeforeShow()
  ns.api:RefreshCurrentCharacterField("weeklies", "vault")
  ns.api:RefreshCurrentCharacterField("weeklies", "vaultSlots")
  ns.api:RefreshCurrentCharacterField("weeklies", "keystone")
  ns.api:RefreshCurrentCharacterField("weeklies", "dungeons")
  ns.api:RefreshCurrentCharacterField("weeklies", "hasUnclaimedVault")
  ns.api:RefreshCurrentCharacterField("weeklies", "delversBounty")
  ns.api:RefreshCurrentCharacterField("instances", "locks")
  self:_activeTable():OnBeforeShow()
  self:layout()
end

-- Segment order, left to right, for both build + update (mirrors the Summary faction control).
local FACTION_SEGS = {
  { mode = "alliance", label = "ALLIANCE", icons = { true },        w = 82 },
  { mode = "horde",    label = "HORDE",    icons = { false },       w = 62 },
  { mode = "both",     label = "BOTH",     icons = { true, false }, w = 74 },
}

-- Faction filter: a joined 3-segment control (Alliance / Horde / Both), one active at a time. Each
-- segment is a bordered box with its faction crest(s) + a mono-caps label; the active one is tinted
-- its faction accent, inactive ones muted. Built into the titlebar by MainWindow.
---@param parent Frame
---@return Frame
function VaultView:BuildFilter(parent)
  local BH, PAD, ICON, GAP, IGAP = 20, 6, 13, 4, 2
  local totalW = 0
  for _, s in ipairs(FACTION_SEGS) do totalW = totalW + s.w end
  local box = ui.Frame:new{ parent = parent, position = { Width = totalW, Height = BH } }

  self._segments = {}
  local x = 0
  for _, seg in ipairs(FACTION_SEGS) do
    local b = ui.Frame:new{ parent = box, position = { Left = { box, ui.edge.Left, x, 0 }, Width = seg.w, Height = BH } }
    b.border = Texture:new{ parent = b, layer = ui.layer.Background, position = { All = true } }
    Texture:new{ parent = b, layer = ui.layer.Border, color = { 0.05, 0.05, 0.06, 0.92 },
      position = { TopLeft = { 1, -1 }, BottomRight = { -1, 1 } } }
    b.button = Button:new{ parent = b, position = { All = true }, glow = false,
      OnClick = function() self:setFaction(seg.mode) end }
    local isz = #seg.icons > 1 and 11 or ICON
    local ix = PAD
    for _, isAlliance in ipairs(seg.icons) do
      local ico = ns.factionIcon[isAlliance]
      local t = Texture:new{ parent = b.button, layer = ui.layer.Artwork, position = { Left = { ix, 0 }, Size = { isz, isz } } }
      t:Texture(ico.path)
      t:Coords(unpack(ico.coords))
      t:SetVertexColor(unpack(ico.vertexColor))
      ix = ix + isz + IGAP
    end
    b.label = Label:new{ parent = b.button, fontInfo = { theme.fonts.caps[1], 10 },
      position = { Left = { ix - IGAP + GAP, 0 } }, text = seg.label }
    self._segments[seg.mode] = b
    x = x + seg.w
  end

  self._filter = box
  self:updateFilter()
  return box
end

-- Tint each segment to reflect the active faction (accent border + label vs. muted + dimmed).
function VaultView:updateFilter()
  if not self._segments then return end
  for _, seg in ipairs(FACTION_SEGS) do
    local b = self._segments[seg.mode]
    if b then
      local active = self._faction == seg.mode
      local col = active and FACTION_COLOR[seg.mode] or theme.colors.muted
      b.label:Color(col)
      local bc = active and FACTION_COLOR[seg.mode] or theme.colors.border
      b.border:Color(bc[1], bc[2], bc[3], active and 0.9 or 0.4)
      b.button:Alpha(active and 1 or 0.7)
    end
  end
end
