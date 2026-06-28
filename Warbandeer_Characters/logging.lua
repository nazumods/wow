---@type Warbandeer_Characters
local ns = select(2, ...)

-- Opt-in combat logging (default off).  While LoggingCombat is on the client writes
-- COMBAT_LOG events to Logs/WoWCombatLog.txt — a plain-text log meant for offline
-- parsing.  The client never persists the toggle across sessions, so we re-apply the
-- stored preference each login.  Advanced Combat Logging (the CVar) adds the
-- positional / item-level / health fields that make the log worth parsing; we flip it
-- on only while our toggle is active, via SetTemporaryCVar so the user's own client
-- setting is restored at logout and never left stuck if the addon is disabled.
local function apply(enabled)
  if enabled then
    ns:SetTemporaryCVar("advancedCombatLogging", "1")
  else
    ns:RestoreCVar("advancedCombatLogging")
  end
  LoggingCombat(enabled)
end

ns:RegisterSettings{
  {
    -- Nest under the shared "Warbandeer" group (same parent Warbandeer_Alias uses).
    parent = "Warbandeer",
    title = "Logging",
    fields = {
      {
        name = "Combat Logging",
        typ = "checkbox",
        default = false,
        -- Ensure-and-persist the backing table: MigrateDB seeds it at v28, but a DB
        -- already current yet missing `settings` would hand Settings a nil table.
        table = function(db)
          db.settings = db.settings or {}
          return db.settings
        end,
        key = "combatLogging",
        label = "Enable Combat Log",
        tooltip = "Write combat events to Logs\\WoWCombatLog.txt for offline parsing.\n"
          .. "Re-applied each login; also enables Advanced Combat Logging while active.",
        callback = function(_, value) apply(value) end,
      },
    },
  },
}

-- Re-apply once per session (combat logging starts off every login).  Only ever
-- enables — a manual /combatlog the user started for another tool is left alone when
-- our toggle is off.
ns:registerEvent("PLAYER_LOGIN", function()
  if ns.db.settings and ns.db.settings.combatLogging then apply(true) end
end)
