---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local CleanFrame, VirtualList, IconListItem, Label, Frame, Texture =
  ui.CleanFrame, ui.VirtualList, ui.IconListItem, ui.Label, ui.Frame, ui.Texture
local theme = ns.theme
local insert = table.insert

-- A pet roster can be vast (a large Hunter stable holds hundreds), far too much to inline on the
-- Detail page — so the Detail "Pets" button toggles this companion panel instead. Modelled on the
-- Bars view's preview/apply companions: a CleanFrame parented to the DetailView (so it hides when
-- Detail is left or the window closes), anchored to the main window's right edge top-to-bottom (so
-- it spans the window's height and tracks its resizes), with an explicit opaque background (the
-- theme's `window` token is alpha 0, so a themed CleanFrame would render transparent — MainWindow
-- does the same). A titlebar strip matching the main window's (the shared `"titlebar"` token + the
-- `title` font, with a drag grip that moves the whole window) sits above one scrolling VirtualList:
-- for a Hunter, an "ACTIVE PETS" section (the Call Pet slots) then a "STABLE" section — each pet a
-- row with its family icon, name, family, level and spec, fed from WarbandeerApi:GetPets. The panel
-- is class-aware: for a Warlock (the other pet class, with no stable) it instead shows one "DEMONS"
-- section — a row per summoned demon with a per-species icon + `name • species` — fed from
-- WarbandeerApi:GetDemons (last-seen, filling in as the Warlock summons each demon). Section headers
-- are caps labels with a count (matching the GlyphBox headers).

local W          = 300  -- panel width
local PAD        = 8
local TITLEBAR_H = 30   -- matches the main window titlebar height
local HEADER_ROW_H = 24 -- an "ACTIVE PETS" / "STABLE" / "DEMONS" caps header row (text + underline rule)
local PET_ROW_H  = 32   -- one pet row (icon + name + level/spec sub-line)
local DEMON_ROW_H = 28  -- one demon row (icon + `name • species`; no sub-line, so tighter than a pet)
local WARLOCK    = 9    -- classId; the other pet class — its roster is summoned demons, not a stable

-- One pet as an IconListItem's content: family icon, name + muted family suffix, and a small
-- "Lv N · <spec>" sub-line (exotic families noted, since they're Beast Mastery only). The level
-- shown is the CHARACTER's level, not the pet's: Hunter pets scale to the hunter (an active pet is
-- always the hunter's level, a stabled one scales up when summoned), so the stored PetInfo.level is
-- a stale last-active value for pets not used recently — it varies and can even exceed the
-- character's level. The effective level of every pet is the character's, so that's what we show.
---@param p PetRecord
---@param level integer  the character's level (every pet's effective level)
---@return table
local function petData(p, level)
  return {
    icon = p.icon,
    title = p.name,
    kind = p.family,
    subtitle = ("Lv %d · %s%s"):format(level, p.spec, p.exotic and " · Exotic" or ""),
  }
end

-- Per-species demon icons, keyed by the locale-proof npcID captured in the pet GUID. The summon-spell
-- icon *paths* are long-stable (case-insensitive); a demon whose npcID isn't mapped — a Grimoire
-- appearance variant with a different id, or a future demon — falls back to a generic fel icon rather
-- than showing nothing. Confirmed in-game: Imp 416, Voidwalker 1860 (#503); the rest are the classic
-- base-summon npcIDs (verify against /wbc dump demons).
local DEMON_ICON = {
  [416]   = "Interface\\Icons\\spell_shadow_summonimp",        -- Imp
  [417]   = "Interface\\Icons\\spell_shadow_summonfelhunter",  -- Felhunter
  [1860]  = "Interface\\Icons\\spell_shadow_summonvoidwalker", -- Voidwalker
  [1863]  = "Interface\\Icons\\spell_shadow_summonsuccubus",   -- Sayaad (Succubus / Incubus)
  [17252] = "Interface\\Icons\\spell_shadow_summonfelguard",   -- Felguard (Demonology)
}
local DEMON_ICON_FALLBACK = "Interface\\Icons\\spell_shadow_metamorphosis"

-- One demon as an IconListItem's content: its per-species icon and a `name • species` title line (no
-- sub-line — a demon has no level/spec, unlike a Hunter pet).
---@param d DemonRecord
---@return table
local function demonData(d)
  return {
    icon  = (d.npcID and DEMON_ICON[d.npcID]) or DEMON_ICON_FALLBACK,
    title = d.name,
    kind  = d.species,
  }
end

---@class PetsPanel: CleanFrame
---@field titlebar Frame        title strip matching the main window's titlebar
---@field title Label
---@field list VirtualList
---@field _dragStrip Frame      invisible grip over the titlebar; drags the main window
---@field _dragBound boolean?   true once the strip has been wired to ns.MainWindow
---@field _char Character?
---@field _level integer?       the character's level — shown for every pet (pets scale to it)
local PetsPanel = Class(CleanFrame, function(self)
  -- Titlebar strip: same `"titlebar"` token + `title` font as the main window titlebar, so the two
  -- read as one piece (fixing the mismatched-colour header).
  self.titlebar = Frame:new{
    parent = self,
    background = "titlebar",
    position = { TopLeft = { self, ui.edge.TopLeft }, TopRight = { self, ui.edge.TopRight }, Height = TITLEBAR_H },
  }
  self.title = Label:new{
    parent = self.titlebar, fontInfo = theme.fonts.title, justifyH = ui.justify.Center,
    justifyV = ui.justify.Middle, wordWrap = false,
    position = { Left = { self.titlebar, ui.edge.Left, PAD, 0 }, Right = { self.titlebar, ui.edge.Right, -PAD, 0 } },
  }
  -- Invisible grip over the titlebar only (leaves the list below free for its own hover/scroll);
  -- wired to drag the whole main window in Set(), mirroring the Bars preview companion.
  self._dragStrip = Frame:new{
    parent = self,
    position = { TopLeft = { self, ui.edge.TopLeft }, TopRight = { self, ui.edge.TopRight }, Height = TITLEBAR_H },
  }
  self.list = VirtualList:new{
    parent    = self,
    scrollbar = true,
    padding   = PAD,
    spacing   = 3,
    emptyText = "No pets recorded — visit a stable master.",
    typeOf    = function(item) return item.type end,
    rowTypes  = {
      -- Section header ("ACTIVE PETS" / "STABLE"): a caps label + a right-aligned count over a
      -- full-width underline rule — the "demark" between sections, positioned BELOW the text (where
      -- SectionHeader's rule should sit but landed mid-text under the wrong font metrics).
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
          row.count:Text(tostring(item.count))
          return HEADER_ROW_H
        end,
      },
      -- One pet.
      pet = {
        create = function(list) return IconListItem:new{ parent = list:Content(), height = PET_ROW_H } end,
        update = function(_, row, item)
          row:Set(petData(item.pet, self._level))
          return PET_ROW_H
        end,
      },
      -- One demon (Warlock).
      demon = {
        create = function(list) return IconListItem:new{ parent = list:Content(), height = DEMON_ROW_H } end,
        update = function(_, row, item)
          row:Set(demonData(item.demon))
          return DEMON_ROW_H
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
  -- Anchored to the (already clamped) main window — same rule as the Bars companions.
  clamped    = false,
  background = { 0.11372549019, 0.14117647058, 0.16470588235, 0.92 },
})
ns.PetsPanel = PetsPanel

-- Populate the panel for `char` and show it (the panel already spans the window's height via its
-- top+bottom anchors, so no manual sizing). Class-aware: a Warlock shows a "DEMONS" section (last-seen
-- summoned demons), any other pet class (Hunter) shows "ACTIVE PETS" + "STABLE". An empty roster (a
-- Hunter with no stable visit, or a Warlock that hasn't summoned) falls through to the emptyText.
---@param char Character
function PetsPanel:Set(char)
  self._char = char
  self._level = (char.basic and char.basic.level) or 0  -- every pet's effective level (pets scale to it)
  -- Bind the header grip to the main window once (it always exists by the time the panel is shown —
  -- the window must be open for the Detail view to render the toggle button).
  if ns.MainWindow and not self._dragBound then
    ns.MainWindow:BindDragHandle(self._dragStrip)
    self._dragBound = true
  end
  local items = {}
  if char.classId == WARLOCK then
    self.title:Text("Demons — " .. char.name)
    self.list:EmptyText("No demons seen — summon your demons to record them.")
    local demons = ns.api:GetDemons(char.name)
    if demons then
      insert(items, { type = "header", title = "DEMONS", count = #demons.list })
      for _, d in ipairs(demons.list) do insert(items, { type = "demon", demon = d }) end
    end
  else
    self.title:Text("Pets — " .. char.name)
    self.list:EmptyText("No pets recorded — visit a stable master.")
    local pets = ns.api:GetPets(char.name)
    if pets then
      insert(items, { type = "header", title = "ACTIVE PETS", count = #pets.active })
      for _, p in ipairs(pets.active) do insert(items, { type = "pet", pet = p }) end
      insert(items, { type = "header", title = "STABLE", count = #pets.stable })
      for _, p in ipairs(pets.stable) do insert(items, { type = "pet", pet = p }) end
    end
  end
  self:Width(W)
  self.list:SetItems(items)
  self:Show()
end

-- Toggle from the Detail "Pets" button: hide if open, else populate + show for `char`.
---@param char Character
function PetsPanel:Toggle(char)
  if self._widget:IsShown() then self:Hide() else self:Set(char) end
end

-- Re-render while already open: re-point at `char` (the Detail subject changed) or, with no arg,
-- re-read the current subject (a live pet change — an active↔stable move or a rename). A no-op when
-- hidden, so nothing forces the panel open.
---@param char Character?
function PetsPanel:Refresh(char)
  char = char or self._char
  if char and self._widget:IsShown() then self:Set(char) end
end
