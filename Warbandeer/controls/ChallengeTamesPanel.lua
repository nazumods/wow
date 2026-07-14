---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local CleanFrame, VirtualList, Label, Frame, Texture =
  ui.CleanFrame, ui.VirtualList, ui.Label, ui.Frame, ui.Texture
local theme = ns.theme
local insert = table.insert

-- The Hunter Challenge-Tames checklist in its own companion panel, docked to the RIGHT of the pets
-- roster panel (PetsPanel) so it isn't buried beneath a large stable. Mirrors PetsPanel's chrome: a
-- CleanFrame parented to the DetailView with an explicit opaque background (the theme `window` token
-- is alpha 0, so a themed CleanFrame would render transparent), a titlebar strip (shared `"titlebar"`
-- token + `title` font, its drag grip moving the whole window) above one scrolling VirtualList. The
-- curated rare/"secret" tames (WarbandeerApi:GetChallengeTames) are grouped by category (Spirit Beasts
-- / Molten Front / Mechanical), each a caps header with an owned/total count, over tame rows tinted by
-- owned state: owned shows the matched pet's family icon full-colour with a green name + an "as <your
-- pet's name>" sub-line, missing a dim generic tame icon with a muted name + the tame's zone/how-to
-- note (mirroring the GlyphBox owned/missing look). Hunter-only — only Hunters have a tameable roster
-- to match, so no other class opens it.

local W          = 260  -- panel width (a touch narrower than the pets roster panel)
local PAD        = 8
local TITLEBAR_H = 30   -- matches the main window titlebar height
local HEADER_ROW_H = 24 -- a category caps header row (text + right-aligned count over an underline rule)
local TAME_ROW_H = 32   -- one tame row (icon + name + note/owned sub-line)
local ICON_SIZE  = 20   -- tame row icon edge (matches the pet-row icon)
local MISSING_ICON = "Interface\\Icons\\ability_hunter_beasttaming" -- generic icon for a missing (un-tamed) tame

---@class ChallengeTamesPanel: CleanFrame
---@field titlebar Frame       title strip matching the main window's titlebar
---@field title Label
---@field list VirtualList
---@field _dragStrip Frame     invisible grip over the titlebar; drags the main window
---@field _dragBound boolean?  true once the strip has been wired to ns.MainWindow
---@field _char Character?
local ChallengeTamesPanel = Class(CleanFrame, function(self)
  self.titlebar = Frame:new{
    parent = self, background = "titlebar",
    position = { TopLeft = { self, ui.edge.TopLeft }, TopRight = { self, ui.edge.TopRight }, Height = TITLEBAR_H },
  }
  self.title = Label:new{
    parent = self.titlebar, fontInfo = theme.fonts.title, justifyH = ui.justify.Center,
    justifyV = ui.justify.Middle, wordWrap = false,
    position = { Left = { self.titlebar, ui.edge.Left, PAD, 0 }, Right = { self.titlebar, ui.edge.Right, -PAD, 0 } },
  }
  self._dragStrip = Frame:new{
    parent = self,
    position = { TopLeft = { self, ui.edge.TopLeft }, TopRight = { self, ui.edge.TopRight }, Height = TITLEBAR_H },
  }
  self.list = VirtualList:new{
    parent    = self,
    scrollbar = true,
    padding   = PAD,
    spacing   = 3,
    emptyText = "No challenge tames.",
    typeOf    = function(item) return item.type end,
    rowTypes  = {
      -- Category header ("SPIRIT BEASTS" / "MOLTEN FRONT" / …): a caps label + a right-aligned
      -- owned/total count over a full-width underline rule (matching the PetsPanel section headers).
      header = {
        create = function(list)
          local row = Frame:new{ parent = list:Content() }
          row.lbl = Label:new{
            parent = row, fontInfo = theme.fonts.caps, color = theme.colors.muted,
            justifyH = ui.justify.Left, wordWrap = false,
            position = { TopLeft = { row, ui.edge.TopLeft, 0, -6 } },
          }
          row.count = Label:new{
            parent = row, fontInfo = theme.fonts.caps, color = theme.colors.muted,
            justifyH = ui.justify.Right, wordWrap = false,
            position = { TopRight = { row, ui.edge.TopRight, 0, -6 } },
          }
          row.rule = Texture:new{
            parent = row, layer = ui.layer.Artwork, color = theme.colors.header,
            position = {
              BottomLeft  = { row, ui.edge.BottomLeft,  0, 0 },
              BottomRight = { row, ui.edge.BottomRight, 0, 0 },
              Height = 1,
            },
          }
          return row
        end,
        update = function(_, row, item)
          row.lbl:Text(item.title)
          row.count:Text(item.count)
          return HEADER_ROW_H
        end,
      },
      -- One tame: a beast icon + the tame's name + a sub-line, tinted by owned state — owned is the
      -- matched pet's family icon at full colour with a green name and an "as <your pet's name>"
      -- sub-line; missing is a dim generic tame icon with a muted name and the tame's zone/how-to note.
      tame = {
        create = function(list)
          local row = Frame:new{ parent = list:Content() }
          row.icon = Texture:new{
            parent = row, layer = ui.layer.Artwork, coords = { 0.08, 0.92, 0.08, 0.92 },
            position = { TopLeft = { row, ui.edge.TopLeft, 0, -1 }, Width = ICON_SIZE, Height = ICON_SIZE },
          }
          row.name = Label:new{
            parent = row, fontInfo = theme.fonts.body, justifyH = ui.justify.Left, wordWrap = false,
            position = { TopLeft = { row, ui.edge.TopLeft, ICON_SIZE + 6, -1 }, TopRight = { row, ui.edge.TopRight, 0, -1 } },
          }
          row.sub = Label:new{
            parent = row, fontInfo = theme.fonts.bodySmall, color = theme.colors.muted,
            justifyH = ui.justify.Left, wordWrap = false,
            position = { TopLeft = { row.name, ui.edge.BottomLeft, 0, -2 }, TopRight = { row, ui.edge.TopRight, 0, 0 } },
          }
          return row
        end,
        update = function(_, row, item)
          local t, c = item.tame, theme.colors
          row.icon:Texture((t.owned and t.icon) or MISSING_ICON)
          local lit = t.owned and 1 or 0.3
          row.icon:SetVertexColor(lit, lit, t.owned and 1 or 0.34, 1)
          row.name:Text(t.label):Color(t.owned and c.green or c.muted)
          row.sub:Text(t.owned and ("as " .. (t.petName or "?")) or (t.note or ""))
          return TAME_ROW_H
        end,
      },
    },
    position = {
      TopLeft     = { self, ui.edge.TopLeft,     PAD, -(TITLEBAR_H + PAD) },
      BottomRight = { self, ui.edge.BottomRight, -PAD, PAD },
    },
  }
  self:Hide()
end, {
  -- Docked to the (already clamped) pets panel — same rule as the Bars companions.
  clamped    = false,
  background = { 0.11372549019, 0.14117647058, 0.16470588235, 0.92 },
})
ns.ChallengeTamesPanel = ChallengeTamesPanel

-- Populate the checklist for `char` (a Hunter) and show it. The catalog (already in category order)
-- is grouped into per-category sections, each header carrying that category's owned/total — so the
-- panel reads like the Collected view's group progress. Shows for any Hunter even before a stable
-- visit (all missing then). A non-Hunter has nothing to match, so the Detail view never opens it here.
---@param char Character
function ChallengeTamesPanel:Set(char)
  self._char = char
  -- Bind the header grip to the main window once (it exists by the time the panel is shown).
  if ns.MainWindow and not self._dragBound then
    ns.MainWindow:BindDragHandle(self._dragStrip)
    self._dragBound = true
  end
  self.title:Text("Challenge Tames — " .. char.name)
  local items = {}
  local tames = ns.api:GetChallengeTames(char.name)
  if tames then
    local sections, order = {}, {}
    for _, t in ipairs(tames) do
      local s = sections[t.category]
      if not s then
        s = { owned = 0, total = 0, tames = {} }
        sections[t.category] = s
        order[#order + 1] = t.category
      end
      s.total = s.total + 1
      if t.owned then s.owned = s.owned + 1 end
      insert(s.tames, t)
    end
    for _, cat in ipairs(order) do
      local s = sections[cat]
      insert(items, { type = "header", title = cat:upper(), count = ("%d / %d"):format(s.owned, s.total) })
      for _, t in ipairs(s.tames) do insert(items, { type = "tame", tame = t }) end
    end
  end
  self:Width(W)
  self.list:SetItems(items)
  self:Show()
end

-- Whether the panel is currently shown (the Detail view keeps it in step with the pets panel).
---@return boolean
function ChallengeTamesPanel:IsOpen() return self._widget:IsShown() end

-- Re-render an already-open panel: re-point at `char` (the Detail subject changed) or, with no arg,
-- re-read the current subject (a live pet change — a tame just captured). A no-op when hidden.
---@param char Character?
function ChallengeTamesPanel:Refresh(char)
  char = char or self._char
  if char and self._widget:IsShown() then self:Set(char) end
end
