---@class LibNAddOn
local ns = select(2, ...)
local Settings = Settings

-- In-game changelog viewer. An addon that ships a `changelog.lua` data file — a
-- newest-first `ns.changelog = {{ version, notes }, ...}` list, appended at release
-- by release.sh from the same conventional-commit grouping used for the GitHub /
-- CurseForge release notes — calls `addOn:RegisterChangelog()` once to surface a
-- "Changelog" button in its Settings category. The button opens the notes in
-- LibNUI's shared CopyWindow (scrollable + copyable); an addon without LibNUI falls
-- back to printing to chat.

-- Join the entries into one display string: a "vX.Y.Z-rN" header per release
-- followed by its (markdown-ish) notes, a blank line between versions.
---@param entries { version: string, notes: string }[]
---@return string
local function format(entries)
  local out = {}
  for _, e in ipairs(entries) do
    out[#out + 1] = "v" .. e.version
    out[#out + 1] = (e.notes:gsub("^%s+", ""):gsub("%s+$", ""))
    out[#out + 1] = ""
  end
  return table.concat(out, "\n")
end

---@class AddOn
---@field changelog { version: string, notes: string }[]? release history, loaded from the addon's changelog.lua
---@field ShowChangelog fun(self) open the changelog viewer (CopyWindow, or chat without LibNUI)

---@class LibNAddOn
---@field registerChangelog fun(addOn: AddOn, addOnName: string, parentName: string?) add a "Changelog" button to the addon's settings category
function ns.registerChangelog(addOn, addOnName, parentName)
  function addOn:ShowChangelog()
    if not (self.changelog and #self.changelog > 0) then return end
    local text = format(self.changelog)
    local title = self._TITLE .. " Changelog"
    -- Prefer the addon's own bound UI lib; fall back to the global LibNUI table when
    -- present (so addons that don't declare X-NUI-UI still get the scroll window in a
    -- suite install), and to chat as a last resort.
    local ui = self.ui or LibNUI
    if ui and ui.ShowCopyWindow then
      ui.ShowCopyWindow(title, text)
    else
      self.Print(text)
    end
  end

  -- Defer to ADDON_LOADED: the changelog data file and any settings category are both
  -- in place by then. registerSettings keys categories by title, so this resolves the
  -- addon's OWN category (title == _TITLE) whether it's top-level (e.g. Warbandeer) or
  -- a subcategory under a shared parent (the ShadowsOfUI-* addons under "Shadows of
  -- UI"). An addon with no settings of its own still gets a home for the button: a
  -- subcategory under `parentName` when given, else a top-level category.
  addOn:registerEvent("ADDON_LOADED", function(self, name)
    if name ~= addOnName then return end
    if not (self.changelog and #self.changelog > 0) then return end
    -- Prefer the addon's own category. `settingsCategoriesByTitle` covers the
    -- declarative `ns:RegisterSettings` path; `self.settingsCategory` covers an addon
    -- that built its panel imperatively (a LibNUI SettingsFrame) and recorded the
    -- returned category there. Without the latter fallback the button couldn't find
    -- that category and would mint a duplicate subcategory under the shared parent.
    local byTitle = self.settingsCategoriesByTitle or {}
    local category = byTitle[self._TITLE] or self.settingsCategory
    if not category then
      category = parentName
        and Settings.RegisterVerticalLayoutSubcategory(ns.getSettingsParent(parentName), self._TITLE)
        or ns.getSettingsParent(self._TITLE)
    end
    -- tooltip (arg 4) is invoked as a function, so pass nil rather than a string;
    -- addSearchTags (arg 5) is a required non-nil boolean — false keeps this
    -- window-opening button out of settings search (per Blizzard's own convention).
    local init = CreateSettingsButtonInitializer("Changelog", "View", function()
      self:ShowChangelog()
    end, nil, false)
    Settings.RegisterInitializer(category, init)
  end)
end
