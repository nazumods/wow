---@class LibNAddOn
local ns = select(2, ...)

local GetCVar, SetCVar = GetCVar, SetCVar

-- Temporary console-variable overrides with a guaranteed restore.
--
-- An addon often flips a CVar for the duration of some state (CombatOutline forces
-- `OutlineEngineMode` on in combat). The danger is a stuck value: if the user logs out
-- or disables the addon while the override is live, the CVar — which the client persists
-- on logout — keeps the addon's value forever, with the addon no longer around to undo it.
--
-- `SetTemporaryCVar` records the user's original value the first time it touches a CVar
-- and arms a `PLAYER_LOGOUT` restore, so the original is always written back at logout
-- even if the addon never explicitly restores it. The addon can also restore sooner via
-- `RestoreCVar` (one) / `RestoreCVars` (all). The backup is taken once per CVar, so a
-- repeated set doesn't clobber the remembered original with our own value.

---Set a CVar, backing up the user's original value (once) for a guaranteed logout restore.
---@param self AddOn
---@param cvar string
---@param value any  passed through to SetCVar (number or string)
---@return AddOn self
local function SetTemporaryCVar(self, cvar, value)
  local backup = self._cvarBackup
  if backup[cvar] == nil then
    -- `false` marks "backed up, but the original was unset" (unknown CVar) so we can tell
    -- it apart from "not ours" (nil) and skip writing nil back.
    backup[cvar] = GetCVar(cvar) or false
    if not self._cvarRestoreArmed then
      self._cvarRestoreArmed = true
      self:registerEvent("PLAYER_LOGOUT", function(s) s:RestoreCVars() end)
    end
  end
  SetCVar(cvar, value)
  return self
end

---Restore one overridden CVar to the user's original value and forget the backup.
---@param self AddOn
---@param cvar string
---@return AddOn self
local function RestoreCVar(self, cvar)
  local original = self._cvarBackup[cvar]
  if original == nil then return self end          -- not overridden by us
  if original ~= false then SetCVar(cvar, original) end
  self._cvarBackup[cvar] = nil
  return self
end

---Restore every CVar this addon overrode (also runs automatically on logout).
---@param self AddOn
---@return AddOn self
local function RestoreCVars(self)
  for cvar in pairs(self._cvarBackup) do
    self:RestoreCVar(cvar)
  end
  return self
end

---@class AddOn
---@field _cvarBackup table<string, string|false> original CVar values, captured on first override
---@field SetTemporaryCVar fun(self: AddOn, cvar: string, value: any): AddOn set a CVar, backing up the original; auto-restored on logout
---@field RestoreCVar fun(self: AddOn, cvar: string): AddOn restore one overridden CVar now
---@field RestoreCVars fun(self: AddOn): AddOn restore all overridden CVars now

---@class LibNAddOn
---@field linkCVarHelpers fun(addOn: AddOn) add the temporary-CVar helpers to an addon
function ns.linkCVarHelpers(addOn)
  addOn._cvarBackup = {}
  addOn.SetTemporaryCVar = SetTemporaryCVar
  addOn.RestoreCVar = RestoreCVar
  addOn.RestoreCVars = RestoreCVars
end
