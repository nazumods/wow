---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local TitleFrame, Frame, Label, EditBox = ui.TitleFrame, ui.Frame, ui.Label, ui.EditBox
local FilterDropdown, VirtualList = ui.FilterDropdown, ui.VirtualList
-- The shared framed box (#770 step 6). This used to reach `ns.DressingRoom._k.selBox` — a peer
-- window depending on the room for chrome — which `chrome.lua` now owns for all three surfaces.
local selBox = ns.SelBox

-- The **outfit library window** (#662): filter and search the account-wide library (#655), which
-- the dressing room's outfit row can otherwise only offer as a flat 150px dropdown. Once a library
-- holds a few dozen looks across several characters, that dropdown stops being a way to FIND one.
--
-- **Two panes since #699.** The list finds a look; the right pane SHOWS it, on a model of the
-- window's own, with the verbs that act on the selected entry beside it. Before that this window
-- could only name a look, never render one — so "load" meant handing the entry to the dressing
-- room's model, the only preview surface that existed.
--
-- **It no longer touches the dressing room at all.** That hand-off was a workaround for the missing
-- preview, and it was actively wrong once the transmogrifier gained a `Library…` opener (#699):
-- opening this from the game's transmogrifier and having it fling the look onto our *separate*
-- dressing-room window would be baffling. To recompose a saved look in the look builder, the room's
-- own outfit dropdown already loads it. The two surfaces stopped reaching into each other.
--
-- Three files, split for size the way the dressing room is, all reopening this one class:
--   * this file — the window shell, the filter strip's widgets, and the footer
--   * controls/OutfitLibraryList.lua — the rows and the filtering that fills them
--   * controls/OutfitLibraryPreview.lua — the preview model and the verbs acting on a selection

local WINW   = 720
local PAD    = 8
local GAP    = 6
local STRIPH = 20     -- filter-strip control height (FilterDropdown's own row height)
local LISTH  = 340
local ROW_H  = 34     -- two lines: the look's name, then where it came from
local TITLEH = 30     -- titlebar, matching the height the room budgets for its own
-- The two columns. LEFTW is the filter strip's natural width — the four controls plus their gaps —
-- so widening the window gave the strip nothing it had to re-lay-out; all the new width went to the
-- preview. PAD + LEFTW + GAP + RIGHTW + PAD = WINW.
local LEFTW, RIGHTW = 444, 254
-- = LEFTW with the gaps. Armour is widest of the three because "Any armour" is its longest label
-- and it truncated to "Any arm…" at the old 96; search gives up the width, since its hint
-- ("Search name or character") is always longer than the box and truncates regardless.
local ARMORW, CLASSW, SEARCHW, CLEARW = 112, 120, 144, 50
local IMPORTW = 190   -- footer button, wide enough for its full caption

-- The armour type that constrains nobody. Doubles as the "no filter" key for both dropdowns, since
-- `ns.FilterOutfits` reads it as "no filter" at either end.
local ANY = "Any"
local ARMOR_TYPES = { "Cloth", "Leather", "Mail", "Plate" }

local HINT          = "Search name or character"
local EMPTY_LIBRARY = "Nothing saved yet. Compose a look and press Save."
local EMPTY_MATCH   = "No looks match these filters."

---Top-level window over the outfit library: a filter strip (armour type, class, free-text search,
---Clear) above a scrolling list of saved looks, beside a 3D preview of the selected one.
---@class OutfitLibraryWindow: TitleFrame
---@field _filter OutfitFilter  the live filter the strip writes and `_apply` reads
---@field _armorDrop FilterDropdown  armour-type selector (a fixed set — every type always offered)
---@field _classDrop FilterDropdown  class selector, rebuilt from `ns.LibraryFacets` on every Refresh
---@field _search EditBox  free-text search over the look's name and the saving character
---@field _hint Label  the muted placeholder shown while the search box is empty
---@field _list VirtualList  the saved-look rows
---@field _selected string?  the selected look's name — what the preview shows and the verbs act on
local OutfitLibraryWindow = Class(TitleFrame, function(self)
  self._filter = {}

  local strip = Frame:new{
    parent = self,
    position = { TopLeft = {self.titlebar, ui.edge.BottomLeft, PAD, -PAD},
                 Width = LEFTW, Height = STRIPH },
  }

  -- Armour first, and widest of the two dropdowns' purposes: it is the filter that actually groups
  -- a look across characters. A leather look is wanted on a rogue, a druid AND a demon hunter —
  -- those three share no class, so filtering by class would scatter exactly the set the user means.
  local armorOpts = { { key = ANY, label = "Any armour" } }
  for _, t in ipairs(ARMOR_TYPES) do armorOpts[#armorOpts + 1] = { key = t, label = t } end
  self._armorDrop = FilterDropdown:new{
    parent = strip, bordered = true, width = ARMORW, options = armorOpts, selected = ANY,
    position = { TopLeft = {0, 0} },
    onSelect = function(_, key)
      self._filter.armor = key ~= ANY and key or nil
      self:_apply()
    end,
  }

  -- Options come from the library itself (`Refresh`), so a class with nothing saved for it is never
  -- offered. Seeded with just "Any class" — the first Refresh fills the rest in.
  self._classDrop = FilterDropdown:new{
    parent = strip, bordered = true, width = CLASSW, menuWidth = 140,
    options = { { key = ANY, label = "Any class" } }, selected = ANY,
    position = { TopLeft = {ARMORW + GAP, 0} },
    onSelect = function(_, key)
      self._filter.class = key ~= ANY and key or nil
      self:_apply()
    end,
  }

  local box = Frame:new{
    parent = strip,
    position = { TopLeft = {ARMORW + GAP + CLASSW + GAP, 0}, Width = SEARCHW, Height = STRIPH },
  }
  selBox(box)
  self._search = EditBox:new{ parent = box, position = { TopLeft = {6, -1}, BottomRight = {-4, 1} } }
  -- Parented to the EditBox rather than its framing box, so the placeholder sits on exactly the
  -- left edge the typed text will land on — the same reason the share row's hint is.
  self._hint = Label:new{
    parent = self._search, color = "muted", wordWrap = false,
    position = { Left = {6, 0}, Right = {-4, 0} }, text = HINT,
  }
  self._search._widget:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
  self._search._widget:SetScript("OnEnterPressed", function(f) f:ClearFocus() end)
  -- Filters as you type. There is no "search" verb to commit — the list IS the result — so Enter
  -- only drops focus rather than doing something the typing hasn't already done.
  self._search._widget:SetScript("OnTextChanged", function()
    local text = self._search:Text() or ""
    self._filter.search = text
    self._hint:SetShown(text == "")
    self:_apply()
  end)

  self:_paneButton(strip, ARMORW + GAP + CLASSW + GAP + SEARCHW + GAP, CLEARW, "Clear",
    function() self:ClearFilters() end)

  self._list = VirtualList:new{
    parent = self, rowHeight = ROW_H, spacing = 1, emptyText = EMPTY_LIBRARY,
    createRow = function(list) return self:_makeRow(list) end,
    updateRow = function(_, row, item) return self:_fillRow(row, item) end,
    position = {
      TopLeft = {strip, ui.edge.BottomLeft, 0, -GAP},
      Width = LEFTW, Height = LISTH,
    },
  }

  -- The right column: the model and the verbs that act on the selection (OutfitLibraryPreview.lua).
  self:_buildPreview(strip)

  -- Footer, below the list: the one action that writes to the library without a selection (#663).
  local footer = Frame:new{
    parent = self,
    position = { TopLeft = {self._list, ui.edge.BottomLeft, 0, -GAP},
                 Width = LEFTW, Height = STRIPH },
  }
  self:_paneButton(footer, 0, IMPORTW, "Import this character's sets",
    function() self:ImportCharacterSets() end)

  -- Follow the STORE, not the caller that changed it (#727). The outfit row and `/collected outfit
  -- …` write the same library, and since #713 docks the two windows together they are routinely on
  -- screen at once — so a look deleted from the row used to sit here until this window was closed
  -- and reopened. `Refresh` already drops a selection whose entry vanished, and `_showPreview`
  -- disarms on the way past, so an armed Delete can't outlive the library it was armed against.
  ns.OnLibraryChanged(function() self:Refresh() end)

  self:Width(WINW)
  self:Height(TITLEH + PAD + STRIPH + GAP + LISTH + GAP + STRIPH + PAD)
end, {
  name = "WarbandeerCollectedOutfitLibrary",
  title = "Outfit Library",
  -- Explicit and opaque: a themed window's `window` token is alpha-0, so the surface would
  -- otherwise render through to whatever is behind it. Same value as the main window's.
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
  special = true,
  -- Sits above the dressing room (also "HIGH") via an explicit high level, NOT via a higher
  -- strata. It must stay BELOW "DIALOG" because `FilterDropdown` parents its drop menu to UIParent
  -- at "DIALOG": at the same strata the menu can't reliably float above this window's own rows and
  -- the list bled through it (the armour/class menus rendered behind the outfit rows). The main
  -- collection window works for the same reason — default strata + a high level, never "DIALOG".
  strata = "HIGH",
  level = 600,
  position = { Center = {} },
})
---@class Warbandeer_Collected
---@field OutfitLibraryWindow OutfitLibraryWindow
ns.OutfitLibraryWindow = OutfitLibraryWindow

-- The layout and copy the sibling files share. They reopen this class from their own files, so
-- these can't stay file-locals — the same reason the dressing room hands its chrome constants to
-- its siblings through `DressingRoom._k`. Keeping them in one table is also what keeps the column
-- arithmetic (PAD + LEFTW + GAP + RIGHTW + PAD = WINW) checkable in one place.
OutfitLibraryWindow._k = {
  LEFTW = LEFTW, RIGHTW = RIGHTW, GAP = GAP, PAD = PAD, STRIPH = STRIPH, LISTH = LISTH,
  ROW_H = ROW_H, ANY = ANY, EMPTY_LIBRARY = EMPTY_LIBRARY, EMPTY_MATCH = EMPTY_MATCH,
}

---One small labelled button: framed box, centred caption, click target. A method rather than a
---file-local so the sibling files (which reopen this class) build their buttons the same way
---instead of keeping copies. The caption AND the selection border are kept on the box so
---arm-then-confirm can swap the one and recolour the other, exactly as the room's `_rowButton`
---does — the border was being discarded here, which is why the pane's armed state carried one
---signal where the room's carried two (#716).
---@param parent Frame
---@param x number
---@param w number
---@param label string
---@param onClick fun()
---@return Frame  the box, carrying `label` (the caption) and `border` (the selection frame)
---@return table  the shared `{ box, border, label, text, disabled }` handle (#770 step 6)
function OutfitLibraryWindow:_paneButton(parent, x, w, label, onClick)
  return ns.RowButton{ parent = parent, x = x, w = w, label = label,
    onClick = onClick, height = STRIPH }
end

---Select a look: show it on the preview model and point the verbs at it. **This is the whole of
---what clicking a row does** — the window keeps its own model, so there is nothing to hand off and
---no reason to close.
---@param name string?  a library outfit name, or nil to clear the selection
---@return OutfitLibraryWindow
function OutfitLibraryWindow:Select(name)
  self._selected = name
  self._list:Refresh()            -- repaint the fills; `_fillRow` reads `_selected`
  self:_showPreview(name)
  return self
end

---Copy every transmog set saved on THIS character into the account-wide library (#663) — the
---inverse of the outfit row's `Push`, and the only route in for sets composed in Blizzard's own
---dressing room or by this addon before the library existed.
---
---Bulk rather than per-set: these sets are stranded per character, so the thing you actually want
---is "take everything off this alt", once per alt. `ns.ImportLibraryOutfit` makes that safe to
---re-run — nothing is ever replaced, an identical look is skipped, and a name collision suffixes —
---so there is no prompt to answer and no picker to build.
function OutfitLibraryWindow:ImportCharacterSets()
  local sets = ns.CustomSets()
  if #sets == 0 then
    ns.Print("This character has no saved transmog sets to import.")
    return
  end
  local saved, renamed, skipped, failed = 0, 0, 0, 0
  -- Batched, so the up-to-25 writes below announce themselves once rather than rebuilding this
  -- window and the outfit row — and re-dressing the preview model — after every single set (#727).
  ns.LibraryBatch(function()
    for _, set in ipairs(sets) do
      local list = ns.CustomSetOutfit(set.id)
      if list then
        local status = ns.ImportLibraryOutfit(set.name, list, ns.LocalOutfitMeta(list))
        -- "failed" needs its own arm: the old catch-all `else` counted a refused write as
        -- skipped, so a set that never landed still reported as already in the library (#767 L-6).
        if status == "saved" then saved = saved + 1
        elseif status == "renamed" then renamed = renamed + 1
        elseif status == "failed" then failed = failed + 1
        else skipped = skipped + 1 end
      end
    end
  end)
  -- Report every category that happened and none that didn't: a bare count would hide the two
  -- outcomes worth knowing about — a look that was renamed, and one that was already there.
  local bits = { ("Imported %d of %d set%s"):format(saved + renamed, #sets, #sets == 1 and "" or "s") }
  if renamed > 0 then bits[#bits + 1] = ("%d renamed — the name was already taken"):format(renamed) end
  if skipped > 0 then bits[#bits + 1] = ("%d already in your library"):format(skipped) end
  -- Say so out loud. A refused write used to be invisible: it was counted as skipped and the
  -- headline still claimed every set had been imported (#767 L-6).
  if failed > 0 then bits[#bits + 1] = ("%d couldn't be saved — check the set's name"):format(failed) end
  ns.Print(table.concat(bits, ". ") .. ".")
end

-- The one instance, created on first open and kept (its filters and dragged position persist for
-- the session), mirroring how the room and the main window are held.
local _library

---Open the library window, creating it on first use. Always refreshes: the library is edited from
---the outfit row while this is closed, so a stale list is the normal case rather than the odd one.
---Docks beneath the collection window when one is already on screen, and **floats free when none
---is** (#767 L-3). It used to resolve a host unconditionally, so opening the library from the
---game's transmogrifier — where nothing of ours is up — dragged a several-hundred-row collection
---window onto the screen and docked the library under it, both behind Blizzard's UI, when all the
---user asked for was the library.
---@class Warbandeer_Collected
---@field OpenOutfitLibrary fun(host: TitleFrame?)  host = the collection window to dock beneath; omitted uses one already on screen, else floats
ns.OpenOutfitLibrary = function(host)
  -- ShownDockHost, not ResolveDockHost: "no host" is a legitimate answer here, not a reason to open
  -- a window the user didn't ask for.
  host = host or ns.ShownDockHost()
  if not _library then
    _library = OutfitLibraryWindow:new{ parent = host or UIParent }
  end
  if host then
    ns.DockPanel(_library, "library", host)          -- (re)dock beneath the current host (#708)
  else
    ns.UndockPanel(_library, "library", ns.db.libraryPos)   -- free-floating, remembering its point
  end
  _library:Refresh()
  _library:Show()
end
