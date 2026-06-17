---@class CombatOutline: AddOn
local ns = LibNAddOn(...)

-- Force the engine outline on in combat, restoring the user's setting when it ends.
-- SetTemporaryCVar (LibNAddOn) backs up the original and guarantees a restore on logout
-- too, so logging out mid-combat can't leave OutlineEngineMode stuck on.
function ns:PLAYER_REGEN_DISABLED()
  self:SetTemporaryCVar("OutlineEngineMode", 1)
end
ns:registerEvent("PLAYER_REGEN_DISABLED")

function ns:PLAYER_REGEN_ENABLED()
  self:RestoreCVar("OutlineEngineMode")
end
ns:registerEvent("PLAYER_REGEN_ENABLED")
