local ADDON_NAME = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Looked up by name, not listed as frames: a frame that does not exist on a client is nil,
-- and a nil in a literal `ipairs` list ends the loop there, leaving every later frame shown.
local FRAME_NAMES = {
  "MainMenuBarBackpackButton",
  "BagBarExpandToggle",
  "CharacterBag0Slot",
  "CharacterBag1Slot",
  "CharacterBag2Slot",
  "CharacterBag3Slot",
  "CharacterReagentBag0Slot",
}

frame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    for _, name in ipairs(FRAME_NAMES) do
      local f = _G[name]
      if f then f:SetShown(false) end
    end
  end
end)
