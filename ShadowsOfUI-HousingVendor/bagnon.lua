---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local CleanOverlay = ns.CleanOverlay
local ApplyOverlay = ns.ApplyOverlay
local AddRefresher = ns.AddRefresher

local function db(key) return ns.db and ns.db[key] end

-- Bagnon / Bagnonium item buttons are the Wildpants `Item` class. The front-end
-- addon `<Include>`s BagBrother's shared source into its OWN namespace, so the
-- class lives on the front-end's global (`Bagnon.Item`, `Bagnonium.Item`) -- there
-- is no `_G.BagBrother`. `Item:Update` runs `UpdateSecondary` (a `nop` "backwards
-- support" extension point) at the end of every refresh with `self.info`
-- (itemID / hyperlink / quality) populated, so we chain it there. The bag buttons
-- are a `ContainerItem` subclass whose own `UpdateSecondary` Super-calls the base,
-- so hooking the base reaches them. See ShadowsOfUI-Ilvl/bagnon.lua for the full
-- rationale (the class method list is Mixin-copied onto each secure button at bind
-- time, so we must override before the first button is bound -- ContinueOnAddOnLoaded
-- fires at the front-end's ADDON_LOADED, before its bag frames are first built).
local function hook(addon)
  if not (addon and addon.Item) then return end

  local original = addon.Item.UpdateSecondary
  function addon.Item.UpdateSecondary(button)
    if original then original(button) end
    CleanOverlay(button)
    local info = button.info
    if not (db("bagnon") and info and info.hyperlink) then return end
    local d = ns.DecorEntryFor(info.hyperlink)
    if d then ApplyOverlay(button, d) end
  end

  -- A settings change re-lays-out every shown frame, re-running our hook.
  AddRefresher(function()
    if addon.Frames then addon.Frames:Update() end
  end)
end

-- Hook every Wildpants front-end that's present (each carries its own class copy).
for _, name in ipairs({ "Bagnon", "Bagnonium" }) do
  EventUtil.ContinueOnAddOnLoaded(name, function() hook(_G[name]) end)
end
