---@class LibNUI_AddOn: AddOn
local ns = LibNAddOn(...)

---@class LibNUI
LibNUI = {}
ns.ui = LibNUI

---@class LibNUIDB
---@field version integer
---@field copyFontSize integer?  account-wide font size for the shared CopyWindow

---@class LibNUI_AddOn
---@field db LibNUIDB
---@field MigrateDB fun(self)
function ns:MigrateDB()
  local db = ns.db
  if db.version == 1 then return end
  db.version = 1
end

ns:registerCommand("version", "", function(self, msg)
  ns.Print("LibNUI version " .. ns:GetMetadata("Version"))
  local v,_,d,n = GetBuildInfo()
  ns.Print("WoW " .. v .. " (" .. d .. ") " .. n)
end, "print version")

ns:registerCommand("test", "", function(self, msg)
  C_AddOns.LoadAddOn("LibNUI_Test")
  if LibNUITest then LibNUITest.run(msg) end
end, "Show TableFrame test windows")
