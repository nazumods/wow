---@class MouselookToggle: AddOn
local ns = LibNAddOn(...)

-- Label for the Options -> Keybindings -> Shadows of UI section (Bindings.xml).
BINDING_NAME_MOUSELOOKTOGGLE_TOGGLE = "Toggle mouselook"

function ns:MigrateDB()
    local db = ns.db
    if db.reticleHeight == nil then db.reticleHeight = 50 end
    if db.showHeld == nil then db.showHeld = true end
    db.version = 1
end

-- While the toggle is on, CursorFreelookCentering snaps the (hidden) cursor -- and
-- with it, @cursor macro targeting -- to a fixed screen position instead of leaving
-- it frozen wherever it happened to be; CursorCenteredYPos picks the height of that
-- position (fraction of screen height from the bottom). Both are set only for
-- toggled mouselook and restored after, so held right-click freelook keeps the
-- stock frozen-cursor behavior.
local CENTERING_CVAR = "CursorFreelookCentering"
local HEIGHT_CVAR = "CursorCenteredYPos"

local toggled = false -- current mouselook was started by our keybind (centering CVars are live)

local function lock()
    MouselookStart()
    toggled = true
    -- The centering CVar must be off at the moment mouselook starts: since 10.2 the
    -- camera jolts by the cursor-to-center vector otherwise (WoWUIBugs #504), which
    -- is also why it can't just stay set permanently. Arm it a frame late instead.
    ns:after(0, function()
        if not (toggled and IsMouselooking()) then return end
        ns:SetTemporaryCVar(HEIGHT_CVAR, ns.db.reticleHeight / 100)
        ns:SetTemporaryCVar(CENTERING_CVAR, 1)
    end)
end

local function unlock()
    toggled = false
    ns:RestoreCVars()
end

-- Called by the MOUSELOOKTOGGLE_TOGGLE binding on key press. Right-click also
-- cancels toggled mouselook (handled in the reticle OnUpdate).
function MouselookToggle_Toggle()
    -- Stopping mouselook while a mouse button is held leaves the character
    -- auto-running, so ignore the keybind mid-click.
    if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then return end
    if IsMouselooking() then
        MouselookStop()
        unlock()
    else
        lock()
    end
end

-- Crosshair reticle shown while mouselook is active, as a stand-in for the hardware
-- cursor the client hides. It tracks GetCursorPosition -- where @cursor macros
-- target -- which is the centered position while toggled and the frozen pre-look
-- position during held right-click freelook. The container frame stays shown
-- always -- a hidden frame's OnUpdate never fires, so it could never notice
-- mouselook starting again to re-show itself; the OnUpdate toggles the texture.
local SHOW_DELAY = 0.3 -- seconds of held mouselook before the reticle starts fading in
local FADE_TIME = 0.2 -- fade-in duration, so the reticle never pops

local reticle = CreateFrame("Frame", nil, UIParent)
reticle:SetSize(48, 48)

local crosshair = reticle:CreateTexture(nil, "OVERLAY")
crosshair:SetAllPoints()
crosshair:SetAtlas("crosshair_unablecrosshairs_48", false)
crosshair:Hide()

local lookStartedAt ---@type number? GetTime() when mouselook was first seen active
local rightWasDown = false -- RightButton state last frame, for edge-detecting a click

reticle:SetScript("OnUpdate", function()
    if not IsMouselooking() then
        lookStartedAt = nil
        rightWasDown = false
        crosshair:Hide()
        if toggled then unlock() end -- mouselook ended some other way while toggled
        return
    end
    lookStartedAt = lookStartedAt or GetTime()

    -- Right-click cancels toggled mouselook. Since #335 set CursorFreelookCentering
    -- live for the toggle, the client's native right-click-cancel no longer fires, so
    -- detect the release edge ourselves and stop. Cancel on the up-edge (not while
    -- held, and not with LeftButton also down) so MouselookStop() can't leave the
    -- character auto-running.
    if toggled then
        local rightDown = IsMouseButtonDown("RightButton")
        if rightWasDown and not rightDown and not IsMouseButtonDown("LeftButton") then
            MouselookStop()
            unlock()
            crosshair:Hide()
            rightWasDown = false
            return
        end
        rightWasDown = rightDown
    else
        rightWasDown = false
    end

    -- Toggled mouselook shows the reticle immediately; held (right-click) freelook
    -- is debounced so quick camera flicks don't flash it, and can be turned off.
    local delay = 0
    if not toggled then
        if not (ns.db and ns.db.showHeld) then
            crosshair:Hide()
            return
        end
        delay = SHOW_DELAY
    end

    local visibleFor = GetTime() - lookStartedAt - delay
    if visibleFor < 0 then
        crosshair:Hide()
        return
    end
    crosshair:SetAlpha(math.min(visibleFor / FADE_TIME, 1))
    crosshair:Show()

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    reticle:ClearAllPoints()
    reticle:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end)

ns:RegisterSettings{
    { title = ns._TITLE, parent = "Shadows of UI", fields = {
        { typ = "slider", key = "reticleHeight", table = function(db) return db end,
            label = "Reticle height (% of screen)", min = 10, max = 90, step = 1, default = 50,
            tooltip = "Screen height the cursor (and reticle) is centered at while the"
                .. " toggle is on: 50 is dead center, higher is further up.",
            callback = function(_, v)
                if toggled then ns:SetTemporaryCVar(HEIGHT_CVAR, v / 100) end
            end },
        { typ = "checkbox", key = "showHeld", table = function(db) return db end,
            label = "Show reticle during held mouselook", default = true,
            tooltip = "Also fade the reticle in (after a short delay) when mouselook"
                .. " comes from outside the toggle, e.g. holding right-click." },
    } },
}
