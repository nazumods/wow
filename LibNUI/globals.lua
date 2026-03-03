local ns = LibNAddOn(...)

ns.ui = {}
LibNUI = ns.ui

ns:registerCommand("version", nil, function(self, msg)
  ns.Print("LibNUI version " .. ns:GetMetadata("Version"))
  local v,_,d,n = GetBuildInfo()
  ns.Print("WoW " .. v .. " (" .. d .. ") " .. n)
end)

ns:registerCommand("test", nil, function(self, msg)
  C_AddOns.LoadAddOn("LibNUI_Test")
  if LibNUITest then LibNUITest.run(msg) end
end, "Show TableFrame test windows")
