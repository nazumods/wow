---@type Warbandeer
local ns = select(2, ...)
local GetItemName = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

ns:registerCommand("", nil, function(self)
  self:Open()
end, "Open the main interface")

for _, v in pairs(ns.views) do
  ns:registerCommand(v.name, nil, function(self)
    self:view(v.name)
  end, "Show the "..v.name.." view")
end

-- Manage the per-item accepted wrong-enchants the Detail view's right-click toggle writes
-- (WarbandeerDB.ignoredEnchants, key "<itemID>:<enchantID>"). Since an accepted mismatch is
-- silent in the UI, these give a way to see and reset them.
ns:registerCommand("enchants", "", function(self)
  local store = self.db.ignoredEnchants or {}
  local lines = {}
  for key in pairs(store) do
    local itemID = tonumber(key:match("^(%d+):"))
    local name = itemID and GetItemName and GetItemName(itemID)
    lines[#lines + 1] = (" - %s |cff808080(%s)|r"):format(name or ("item " .. (itemID or "?")), key)
  end
  if #lines == 0 then
    self.Print("No accepted wrong-enchants. Right-click a \"Wrong enchant\" row in Detail to accept one.")
    return
  end
  table.sort(lines)
  self.Print(("Accepted wrong-enchants (%d) — /wb enchants clear to reset:"):format(#lines))
  for _, l in ipairs(lines) do print(l) end
end, "List accepted wrong-enchants")

ns:registerCommand("enchants", "clear", function(self)
  local store = self.db.ignoredEnchants or {}
  local n = 0
  for key in pairs(store) do store[key] = nil; n = n + 1 end
  self.Print(("Cleared %d accepted wrong-enchant%s."):format(n, n == 1 and "" or "s"))
  -- Re-render the open Detail view so any previously-accepted notes reappear.
  local view = ns.MainWindow and ns.MainWindow:ShownView()
  if view and view.name == "detail" then view:OnBeforeShow(); ns.MainWindow:Fit() end
end, "Clear all accepted wrong-enchants")

-- Dev toggle (/wb debug on|off; bare /wb debug prints status): overlay 1px vertical guides at
-- each Summary column boundary so column autosize/reflow alignment can be checked in-game.
-- Persisted in db.settings.debug (default off); toggling rebuilds the Summary view (via
-- ns.RefreshSummaryColumns) so it takes effect immediately.
local function setDebug(self, on)
  self.db.settings.debug = on
  self.Print("Summary column guides " .. (on and "on" or "off") .. ".")
  ns.RefreshSummaryColumns()
end

ns:registerCommand("debug", "on", function(self) setDebug(self, true) end, "Show Summary column-boundary guides (dev)")
ns:registerCommand("debug", "off", function(self) setDebug(self, false) end, "Hide Summary column-boundary guides (dev)")
ns:registerCommand("debug", "", function(self)
  self.Print("Summary column guides are " .. (self.db.settings.debug and "on" or "off") .. ". Use /wb debug on|off.")
end, "Column-guide debug status (dev)")
