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
---@field registerChangelog fun(addOn: AddOn, addOnName: string, categoryName: string?) add a "Changelog" button to the addon's settings category
function ns.registerChangelog(addOn, addOnName, categoryName)
  function addOn:ShowChangelog()
    if not (self.changelog and #self.changelog > 0) then return end
    local text = format(self.changelog)
    local title = self._TITLE .. " Changelog"
    if self.ui and self.ui.ShowCopyWindow then
      self.ui.ShowCopyWindow(title, text)
    else
      self.Print(text)
    end
  end

  -- Defer to ADDON_LOADED: the changelog data file and the addon's settings
  -- category (created lazily by registerSettings) are both in place by then.
  addOn:registerEvent("ADDON_LOADED", function(self, name)
    if name ~= addOnName then return end
    if not (self.changelog and #self.changelog > 0) then return end
    local category = ns.getSettingsParent(categoryName or self._TITLE)
    -- tooltip (arg 4) is invoked as a function, so pass nil rather than a string;
    -- addSearchTags (arg 5) is a required non-nil boolean — false keeps this
    -- window-opening button out of settings search (per Blizzard's own convention).
    local init = CreateSettingsButtonInitializer("Changelog", "View", function()
      self:ShowChangelog()
    end, nil, false)
    Settings.RegisterInitializer(category, init)
  end)
end
