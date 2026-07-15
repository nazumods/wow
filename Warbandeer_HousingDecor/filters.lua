---@type Warbandeer_HousingDecor
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Texture, Label, Button, Frame, FilterDropdown, EditBox =
  ui.Texture, ui.Label, ui.Button, ui.Frame, ui.FilterDropdown, ui.EditBox
local GameTooltip = GameTooltip
local HousingDecorList = ns.List

-- The filter chrome for the decor list (Unowned + Wanted toggles, a hierarchical
-- Category ▾ dropdown, and a name search box), plus the filter setters they drive.
-- Re-opens the HousingDecorList class defined in list.lua.

-- ─── Filter setters ──────────────────────────────────────────────────────────

---Toggle "unowned only"; rebuilds the list.
---@return boolean
function HousingDecorList:ToggleUncollected()
  self._uncollected = not self._uncollected
  self:Render()
  return self._uncollected
end

---Toggle "wanted only"; rebuilds the list and syncs the toggle button highlight (so
---the header's wanted tally can drive the same filter).
---@return boolean
function HousingDecorList:ToggleWantedOnly()
  self._wantedOnly = not self._wantedOnly
  self:Render()
  if self._syncWantedBtn then self._syncWantedBtn() end
  return self._wantedOnly
end

---Set the name-substring filter (lowercased; "" clears it) and rebuild.
---@param text string?
function HousingDecorList:SetSearch(text)
  self._search = (text or ""):lower()
  self:Render()
end

-- Apply a Category-dropdown selection. Keys: "all", "c:<categoryID>" (a top-level
-- category), or "s:<subcategoryID>" (a subcategory) — the two filter fields stay
-- mutually exclusive (picking one clears the other), matching the flat menu.
---@param key string
function HousingDecorList:_applyCategoryKey(key)
  if key == "all" then
    self._category, self._subcategory = "all", "all"
  else
    local kind, id = key:match("^(%a):(%d+)$")
    id = tonumber(id)
    if kind == "c" then
      self._category, self._subcategory = id, "all"
    else
      self._category, self._subcategory = "all", id
    end
  end
  self:Render()
end

-- ─── Dropdown options ────────────────────────────────────────────────────────

---Hierarchical Category-dropdown options: "All decor", then each category present in
---the snapshot (sorted by name), each followed by its co-occurring subcategories
---(indented). One flat menu avoids a dependent second dropdown (FilterDropdown builds
---its menu once), while still offering both category and subcategory filtering.
---@return table[]  `{ key, label }` specs for `ui.FilterDropdown`
function HousingDecorList:CategoryOptions()
  -- Categories present, and per category the subcategories seen on the same entries.
  local catSubs, present = {}, {}
  for _, e in ipairs(ns._entries) do
    if e.categoryIDs then
      for _, c in ipairs(e.categoryIDs) do
        present[c] = true
        local subs = catSubs[c]
        if not subs then subs = {}; catSubs[c] = subs end
        if e.subcategoryIDs then
          for _, s in ipairs(e.subcategoryIDs) do subs[s] = true end
        end
      end
    end
  end

  local cats = {}
  for c in pairs(present) do cats[#cats + 1] = c end
  table.sort(cats, function(a, b) return (ns._categoryName[a] or "") < (ns._categoryName[b] or "") end)

  local opts = { { key = "all", label = "All decor" } }
  for _, c in ipairs(cats) do
    opts[#opts + 1] = { key = "c:" .. c, label = ns._categoryName[c] or ("Category " .. c) }
    local subs = {}
    for s in pairs(catSubs[c]) do subs[#subs + 1] = s end
    table.sort(subs, function(a, b) return (ns._subcategoryName[a] or "") < (ns._subcategoryName[b] or "") end)
    for _, s in ipairs(subs) do
      opts[#opts + 1] = { key = "s:" .. s, label = "   " .. (ns._subcategoryName[s] or ("Subcategory " .. s)) }
    end
  end
  return opts
end

-- ─── Filter strip ────────────────────────────────────────────────────────────

-- One framed toggle: a caption pill (`text`) or a square icon button (`atlas`), with a
-- recolorable border and an optional hover tooltip. Returns the border texture so the
-- click handler can flip its color on/off.
local function makeToggle(strip, theme, spec)
  local gold, divider = theme.colors.gold or theme.colors.header, theme.colors.divider
  local isIcon = spec.atlas ~= nil
  local b = Frame:new{ parent = strip,
    position = { TopLeft = { spec.x, 0 }, Width = spec.w, Height = spec.h } }
  local border = Texture:new{ parent = b, layer = ui.layer.Background,
    position = { All = true }, color = spec.active and gold or divider }
  Texture:new{ parent = b, layer = ui.layer.Border, color = { 0.05, 0.05, 0.06, 0.92 },
    position = { TopLeft = { 1, -1 }, BottomRight = { -1, 1 } } }
  local btn = Button:new{ parent = b, position = { All = true }, glow = false, OnClick = spec.onClick,
    OnEnter = spec.tip and function(s)
      GameTooltip:SetOwner(s._widget, "ANCHOR_BOTTOMRIGHT"); GameTooltip:SetText(spec.tip()); GameTooltip:Show()
    end or nil,
    OnLeave = spec.tip and function() GameTooltip:Hide() end or nil,
  }
  if isIcon then
    -- `tint = false` keeps the already-gold star at its native color.
    Texture:new{ parent = btn, layer = ui.layer.Artwork, atlas = spec.atlas,
      position = { TopLeft = { 2, -2 }, BottomRight = { -2, 2 } } }
  else
    local caps = theme.fonts.caps
    Label:new{ parent = btn, fontInfo = caps and { caps[1], 10 } or nil, justifyH = ui.justify.Center,
      position = { Left = { 6, 0 }, Right = { -6, 0 } }, text = spec.text }
  end
  return border
end

---Build the shared filter chrome as a strip wired to this list, so both hosts render the
---identical row above it. All changes route through Render → onFilterChanged, so the
---host counter updates automatically.
---@param parent table  frame to parent the strip to
---@return Frame strip
function HousingDecorList:BuildFilterStrip(parent)
  local theme = self:Theme()
  local gold, divider = theme.colors.gold or theme.colors.header, theme.colors.divider
  local BH = HousingDecorList.STRIP_H
  local PILL_W, IB, DW, SW, GAP = 84, BH, 150, 130, 6
  local strip = Frame:new{ parent = parent, position = { Height = BH } }
  local x = 0

  local uncBorder
  uncBorder = makeToggle(strip, theme, { x = x, w = PILL_W, h = BH, text = "UNOWNED", active = false,
    tip = function() return self._uncollected and "Unowned only -- click to show all decor"
                                              or  "Show only decor you don't own" end,
    onClick = function() uncBorder:Color(self:ToggleUncollected() and gold or divider) end })
  x = x + PILL_W + GAP

  local wantedBorder
  wantedBorder = makeToggle(strip, theme, { x = x, w = IB, h = BH, atlas = ns.WantedIcon, active = false,
    tip = function() return self._wantedOnly and "Wanted only -- click to show all decor"
                                             or  "Show only decor you've flagged wanted" end,
    onClick = function() self:ToggleWantedOnly() end })
  -- Keep the button border in sync when the header's wanted tally drives the toggle.
  self._syncWantedBtn = function() wantedBorder:Color(self._wantedOnly and gold or divider) end
  x = x + IB + GAP

  FilterDropdown:new{
    parent = strip, position = { TopLeft = { x, 0 } }, width = DW, menuWidth = 190,
    bordered = true, selected = "all", options = self:CategoryOptions(),
    onSelect = function(_, key) self:_applyCategoryKey(key) end,
  }
  x = x + DW + GAP

  -- Name search. InputBoxTemplate brings its own border; a small left inset lines its
  -- text up with the pills. Escape clears the filter and drops focus.
  local search = EditBox:new{ parent = strip,
    position = { TopLeft = { x + 6, -1 }, Width = SW - 6, Height = BH } }
  search:SetScript("OnTextChanged", function() self:SetSearch(search:Text()) end)
  search:SetScript("OnEscapePressed", function()
    search:Text(""); search._widget:ClearFocus(); self:SetSearch("")
  end)
  x = x + SW + GAP

  strip:Width(x)
  return strip
end
