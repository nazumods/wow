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
--
-- Pass `enforce = true` when the override must *stay* put for as long as it's active — e.g.
-- a value the user (or another addon) might change out from under you. The CVar is then
-- re-asserted whenever a `CVAR_UPDATE` shows it drifted from the forced value. Our own
-- writes are wrapped in a suppress flag, and the re-assert only fires when the live value
-- actually differs, so there's no feedback loop. Enforcement ends when the CVar is restored.

---Re-assert every enforced CVar that has drifted from its forced value.
---@param self AddOn
local function EnforceCVars(self)
  if self._cvarEnforceSuppress then return end   -- our own write echoing back
  for cvar, forced in pairs(self._cvarEnforce) do
    if GetCVar(cvar) ~= forced then
      self._cvarEnforceSuppress = true
      SetCVar(cvar, forced)
      self._cvarEnforceSuppress = false
    end
  end
end

---Set a CVar, backing up the user's original value (once) for a guaranteed logout restore.
---@param self AddOn
---@param cvar string
---@param value any  passed through to SetCVar (number or string)
---@param enforce boolean?  keep re-asserting the value while a CVAR_UPDATE shows it drifted
---@return AddOn self
local function SetTemporaryCVar(self, cvar, value, enforce)
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
  if enforce then
    -- Store the forced value as a string so it compares equal to GetCVar's return.
    self._cvarEnforce[cvar] = tostring(value)
    if not self._cvarEnforceArmed then
      self._cvarEnforceArmed = true
      self:registerEvent("CVAR_UPDATE", EnforceCVars)
    end
  end
  self._cvarEnforceSuppress = true   -- our own write shouldn't count as drift
  SetCVar(cvar, value)
  self._cvarEnforceSuppress = false
  return self
end

---Restore one overridden CVar to the user's original value and forget the backup.
---@param self AddOn
---@param cvar string
---@return AddOn self
local function RestoreCVar(self, cvar)
  local original = self._cvarBackup[cvar]
  if original == nil then return self end          -- not overridden by us
  self._cvarEnforce[cvar] = nil                    -- stop re-asserting it, if enforced
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
---@field _cvarEnforce table<string, string> forced value per CVar currently under enforce mode
---@field SetTemporaryCVar fun(self: AddOn, cvar: string, value: any, enforce: boolean?): AddOn set a CVar, backing up the original; auto-restored on logout; enforce re-asserts it on drift
---@field RestoreCVar fun(self: AddOn, cvar: string): AddOn restore one overridden CVar now (also stops enforcing it)
---@field RestoreCVars fun(self: AddOn): AddOn restore all overridden CVars now

---@class LibNAddOn
---@field linkCVarHelpers fun(addOn: AddOn) add the temporary-CVar helpers to an addon
function ns.linkCVarHelpers(addOn)
  addOn._cvarBackup = {}
  addOn._cvarEnforce = {}
  addOn.SetTemporaryCVar = SetTemporaryCVar
  addOn.RestoreCVar = RestoreCVar
  addOn.RestoreCVars = RestoreCVars
end
