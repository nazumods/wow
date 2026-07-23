---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local TitleFrame, Frame, Label, EditBox = ui.TitleFrame, ui.Frame, ui.Label, ui.EditBox
local Button, FilterDropdown, VirtualList = ui.Button, ui.FilterDropdown, ui.VirtualList
-- The room's own framed-box helper, rather than a copy that would drift from the row this window
-- opens from. `_k` is the addon's shared control-chrome table; the other controls/ files read it
-- the same way (they reopen DressingRoom, this is a peer window).
local selBox = ns.DressingRoom._k.selBox

-- The **outfit library window** (#662): filter and search the account-wide library (#655), which
-- the dressing room's outfit row can otherwise only offer as a flat 150px dropdown. Once a library
-- holds a few dozen looks across several characters, that dropdown stops being a way to FIND one.
--
-- **Why a window and not another control row.** The outfit row is full at 568 of GRIDW's 572px with
-- six controls, and the room already carries four control rows under a 640px model — a fifth would
-- sit inert most of the time. A window also answers the question #663 (importing a character's
-- existing transmog sets) is blocked on: library management has a home now, so an import belongs
-- inside it rather than behind a second door.
--
-- **It costs the outfit row no width at all.** The opener is a trailing sentinel entry in the
-- dropdown itself, beside the "+ New Look" one already there — see `MANAGE` in
-- controls/DressingRoomOutfits.lua.
--
-- This window READS the library and loads from it. Save, Rename, Delete and Push stay on the outfit
-- row, where the look being composed lives — one verb per home rather than two doors to each. The
-- filtering itself is pure and lives in outfitlibrary.lua (`ns.FilterOutfits` / `ns.LibraryFacets`)
-- where it is unit-tested; this file is only widgets.

local WINW   = 460
local PAD    = 8
local GAP    = 6
local STRIPH = 20     -- filter-strip control height (FilterDropdown's own row height)
local LISTH  = 340
local ROW_H  = 34     -- two lines: the look's name, then where it came from
local TITLEH = 30     -- titlebar, matching the height the room budgets for its own
local ARMORW, CLASSW, SEARCHW, CLEARW = 96, 120, 160, 50   -- = WINW - 2*PAD with the gaps

-- The armour type that constrains nobody. Doubles as the "no filter" key for both dropdowns, since
-- `ns.FilterOutfits` reads it as "no filter" at either end.
local ANY = "Any"
local ARMOR_TYPES = { "Cloth", "Leather", "Mail", "Plate" }

local HINT           = "Search name or character"
local EMPTY_LIBRARY  = "Nothing saved yet. Compose a look and press Save."
local EMPTY_MATCH    = "No looks match these filters."
-- Shown for an entry saved before #655 recorded provenance. Named rather than left blank so the
-- row reads as "we don't know" instead of as a rendering bug — these entries deliberately survive
-- every filter (see the note in outfitlibrary.lua).
local NO_PROVENANCE  = "no provenance recorded"

---One small labelled button in the filter strip. The row buttons on the dressing room's own
---control rows are a DressingRoom method (`_rowButton`) and can't be reached from a peer class, so
---this is the same idiom — framed box, centred caption, click target — at strip height.
---@param parent Frame
---@param x number
---@param w number
---@param label string
---@param onClick fun()
---@return Frame
local function stripButton(parent, x, w, label, onClick)
  local box = Frame:new{ parent = parent, position = { TopLeft = {x, 0}, Width = w, Height = STRIPH } }
  selBox(box)
  Label:new{ parent = box, justifyH = ui.justify.Center, wordWrap = false,
    position = { Left = {2, 0}, Right = {-2, 0} }, text = label }
  Button:new{ parent = box, position = { All = true }, glow = false, OnClick = onClick }
  return box
end

---Top-level window over the outfit library: a filter strip (armour type, class, free-text search,
---Clear) above a scrolling list of saved looks with their provenance. Clicking a look loads it.
---@class OutfitLibraryWindow: TitleFrame
---@field _filter OutfitFilter  the live filter the strip writes and `_apply` reads
---@field _armorDrop FilterDropdown  armour-type selector (a fixed set — every type always offered)
---@field _classDrop FilterDropdown  class selector, rebuilt from `ns.LibraryFacets` on every Refresh
---@field _search EditBox  free-text search over the look's name and the saving character
---@field _hint Label  the muted placeholder shown while the search box is empty
---@field _list VirtualList  the saved-look rows
local OutfitLibraryWindow = Class(TitleFrame, function(self)
  self._filter = {}

  local strip = Frame:new{
    parent = self,
    position = { TopLeft = {self.titlebar, ui.edge.BottomLeft, PAD, -PAD},
                 Width = WINW - 2 * PAD, Height = STRIPH },
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

  stripButton(strip, ARMORW + GAP + CLASSW + GAP + SEARCHW + GAP, CLEARW, "Clear",
    function() self:ClearFilters() end)

  self._list = VirtualList:new{
    parent = self, rowHeight = ROW_H, spacing = 1, emptyText = EMPTY_LIBRARY,
    createRow = function(list) return self:_makeRow(list) end,
    updateRow = function(_, row, item) return self:_fillRow(row, item) end,
    position = {
      TopLeft = {strip, ui.edge.BottomLeft, 0, -GAP},
      Width = WINW - 2 * PAD, Height = LISTH,
    },
  }

  self:Width(WINW)
  self:Height(TITLEH + PAD + STRIPH + GAP + LISTH + PAD)
end, {
  name = "WarbandeerCollectedOutfitLibrary",
  title = "Outfit Library",
  -- Explicit and opaque: a themed window's `window` token is alpha-0, so the surface would
  -- otherwise render through to whatever is behind it. Same value as the main window's.
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
  special = true,
  -- Above the dressing room ("HIGH"), which is what opens this and what it sits in front of.
  strata = "DIALOG",
  position = { Center = {} },
})
---@class Warbandeer_Collected
---@field OutfitLibraryWindow OutfitLibraryWindow
ns.OutfitLibraryWindow = OutfitLibraryWindow

-- One pooled row: the look's name (class-coloured), its provenance beneath in muted text, and a
-- hover fill. No persistent selection border — the window's job is finding a look, and a border
-- tracking "the loaded one" would go stale the moment the outfit row's dropdown loaded another.
---@param list VirtualList
---@return Frame
function OutfitLibraryWindow:_makeRow(list)
  local row = Frame:new{ parent = list:Content(), background = {1, 1, 1, 0},
    position = { Height = ROW_H } }
  local w = WINW - 2 * PAD - 16
  row.name   = Label:new{ parent = row, justifyH = ui.justify.Left, wordWrap = false,
    position = { TopLeft = {8, -5}, Width = w } }
  row.origin = Label:new{ parent = row, justifyH = ui.justify.Left, wordWrap = false, color = "muted",
    position = { TopLeft = {8, -20}, Width = w } }
  row._widget:EnableMouse(true)
  row._widget:SetScript("OnEnter", function() row.background:Color(1, 1, 1, 0.12) end)
  row._widget:SetScript("OnLeave", function() row.background:Color(1, 1, 1, 0) end)
  row._widget:SetScript("OnMouseUp", function() self:Load(row._name) end)
  return row
end

-- Re-point a pooled row at `{ outfit = <LibraryOutfit> }`. The name is coloured by `class` — WHO
-- saved it — keeping the one meaning that tint already has on the outfit row's dropdown, while the
-- class FILTER keys on `forClass`, what the look is for. The two answer different questions, so
-- the row spells `forClass` out in words rather than letting the colour try to carry both.
---@param row Frame
---@param item table
---@return number
function OutfitLibraryWindow:_fillRow(row, item)
  local o = item.outfit
  row._name = o.name
  row.name:Text(ns.ClassColored(o.name, o.class))
  local origin = ns.OutfitOrigin(o)
  local forClass = o.forClass and ns.ClassLabel(o.forClass)
  if forClass then
    forClass = ("a %s look"):format(forClass)
    origin = origin ~= "" and (origin .. "   ·   " .. forClass) or forClass
  end
  row.origin:Text(origin ~= "" and origin or NO_PROVENANCE)
  row.background:Color(1, 1, 1, 0)
  return ROW_H
end

---Rebuild the class dropdown from what the library actually holds, then re-filter. Called on every
---open, since the library changes from the outfit row while this window is closed.
---@return OutfitLibraryWindow
function OutfitLibraryWindow:Refresh()
  local opts, valid = { { key = ANY, label = "Any class" } }, false
  for _, classFile in ipairs(ns.LibraryFacets(ns.LibraryOutfits())) do
    opts[#opts + 1] = { key = classFile, label = ns.ClassColored(ns.ClassLabel(classFile), classFile) }
    if classFile == self._filter.class then valid = true end
  end
  -- Deleting the last WARRIOR look retires that option. Drop the filter with it, or the list would
  -- stay filtered by something no longer in the dropdown and so impossible to clear from there.
  if not valid then self._filter.class = nil end
  self._classDrop:SetOptions(opts, self._filter.class or ANY)
  self:_apply()
  return self
end

-- Re-run the filter and repopulate. The title carries the count, which is the cheapest honest
-- feedback that a filter is doing something — and the only place there is room for it.
function OutfitLibraryWindow:_apply()
  local all = ns.LibraryOutfits()
  local shown = ns.FilterOutfits(all, self._filter)
  local items = {}
  for i, o in ipairs(shown) do items[i] = { outfit = o } end
  self._list:EmptyText(#all == 0 and EMPTY_LIBRARY or EMPTY_MATCH)
  self._list:SetItems(items)
  self:Title(#shown == #all and ("Outfit Library — %d"):format(#all)
    or ("Outfit Library — %d of %d"):format(#shown, #all))
end

---Drop every filter and show the whole library again.
---@return OutfitLibraryWindow
function OutfitLibraryWindow:ClearFilters()
  self._filter = {}
  self._armorDrop:Select(ANY)
  self._classDrop:Select(ANY)
  self._search:Text("")           -- fires OnTextChanged only when it wasn't already empty…
  self._hint:Show()
  self:_apply()                   -- …so re-apply unconditionally rather than relying on it
  return self
end

---Load a saved look onto the model and close. The room is where a look is worn, so this is a
---hand-off rather than a second preview surface; the outfit row is re-pointed at what was loaded
---so the two never disagree about which look is on screen.
---@param name string  a library outfit name
function OutfitLibraryWindow:Load(name)
  local room = ns.OpenDressingRoom()
  if not room then
    ns.Print("Open a set's Preview first — a look loads onto the model there.")
    return
  end
  room:LoadOutfit(name)
  room:RefreshOutfits()
  self:Hide()
end

-- The one instance, created on first open and kept (its filters and dragged position persist for
-- the session), mirroring how the room and the main window are held.
local _library

---Open the library window, creating it on first use. Always refreshes: the library is edited from
---the outfit row while this is closed, so a stale list is the normal case rather than the odd one.
---@class Warbandeer_Collected
---@field OpenOutfitLibrary fun()
ns.OpenOutfitLibrary = function()
  if not _library then
    _library = OutfitLibraryWindow:new{}
    _library:RememberPosition(ns.db.libraryPos)   -- restore + persist the user's dragged position
  end
  _library:Refresh()
  _library:Show()
end
