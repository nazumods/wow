---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local CleanOverlay = ns.CleanOverlay
local ApplyOverlay = ns.ApplyOverlay
local AddRefresher = ns.AddRefresher

local function db(key) return ns.db and ns.db[key] end

-- Paint (or clean) one Bagnon item button from its current item. Cleans first so a
-- disabled surface / indicator or a non-decor slot leaves nothing behind.
local function paint(button)
  CleanOverlay(button)
  local info = button.info
  if not (db("bagnon") and info and info.hyperlink) then return end
  local d = ns.DecorEntryFor(info.hyperlink)
  if d then ApplyOverlay(button, d) end
end

-- Bagnon / Bagnonium item buttons are the Wildpants `Item` class. The front-end
-- addon `<Include>`s BagBrother's shared source into its OWN namespace, so the class
-- lives on the front-end's global (`Bagnon.Item`, `Bagnonium.Item`) -- there is no
-- `_G.BagBrother`. `Item:Update` runs `UpdateSecondary` (a `nop` "backwards support"
-- extension point) at the end of every refresh with `self.info` populated, so we
-- chain it there. The bag buttons are a `ContainerItem` subclass whose own
-- `UpdateSecondary` Super-calls the base, so hooking the base reaches them. The class
-- method list is Mixin-copied onto each secure button at bind time, so we override
-- before the first button is bound -- ContinueOnAddOnLoaded fires at the front-end's
-- ADDON_LOADED, before its bag frames (and buttons) are first built. See
-- ShadowsOfUI-Ilvl/bagnon.lua for the full rationale.
local function hook(addon)
  if not (addon and addon.Item) then return end

  -- Every button we've painted, so a settings change can re-evaluate our per-indicator
  -- gates on what's already on screen: the refresher below re-paints the still-visible
  -- ones directly, a self-contained refresh that doesn't route through Bagnon's layout.
  local seen = {}

  local original = addon.Item.UpdateSecondary
  function addon.Item.UpdateSecondary(button)
    if original then original(button) end
    seen[button] = true
    paint(button)
  end

  -- A settings change re-paints every button we've overlaid that's currently visible
  -- (pooled/off-screen buttons are skipped; they re-paint via the hook when reshown).
  AddRefresher(function()
    for button in pairs(seen) do
      if button:IsVisible() then paint(button) end
    end
  end)
end

-- Hook every Wildpants front-end that's present (each carries its own class copy).
for _, name in ipairs({ "Bagnon", "Bagnonium" }) do
  EventUtil.ContinueOnAddOnLoaded(name, function() hook(_G[name]) end)
end
