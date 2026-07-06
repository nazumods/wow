local ADDON_NAME = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    for _, f in ipairs({
      MainMenuBarBackpackButton,
      BagBarExpandToggle,
      CharacterBag0Slot,
      CharacterBag1Slot,
      CharacterBag2Slot,
      CharacterBag3Slot,
      CharacterReagentBag0Slot,
    }) do
      f:SetShown(false)
    end
  end
end)
