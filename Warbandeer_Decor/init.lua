---@class Warbandeer_Decor: AddOn
local ns = LibNAddOn(...)

---Migrate the saved DB to the current version (non-destructive; seeds missing keys).
function ns:MigrateDB()
  local db = self.db
  -- Account-wide "wanted" target flags, keyed by catalog recordID. This is the ONLY
  -- persisted collection state: the decor entry list itself is re-enumerated live from
  -- C_HousingCatalog every session (see scan.lua) rather than stored, so it can never
  -- drift from the game's real catalog.
  if not db.wanted then db.wanted = {} end        -- [recordID] = true  target list
  -- Last scan's account-wide tallies, kept only so the header can show a number the
  -- instant the window opens, before the session's first live scan finishes.
  if not db.collected then db.collected = 0 end
  if not db.total then db.total = 0 end
  -- Remembered window position (shape { point, relPoint, x, y }), written on drag-stop
  -- and restored on open so the window doesn't re-center after a /reload.
  if not db.windowPos then db.windowPos = {} end
  db.version = 1
end

-- This addon was renamed from Warbandeer_HousingDecor, and a GitHub-release install keeps
-- the old folder rather than replacing it. Both copies then declare the same SavedVariables,
-- register the same commands, and assign _G.WarbandeerHousingDecorApi -- last loaded wins.
-- A release note doesn't reach someone who upgrades without reading it, so say it in chat.
-- Self-limiting: it stops firing once the old folder is gone (and never fires if it's merely
-- present but disabled, which is harmless). PLAYER_LOGIN fires exactly once per session.
ns:registerEvent("PLAYER_LOGIN", function()
  if C_AddOns.IsAddOnLoaded("Warbandeer_HousingDecor") then
    ns.Print("An old |cffffd100Warbandeer_HousingDecor|r folder is still installed. " ..
             "Delete it from your AddOns folder -- this addon replaced it.")
  end
end)
