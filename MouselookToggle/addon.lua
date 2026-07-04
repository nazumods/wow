-- Label for the Options -> Keybindings -> Shadows of UI section (Bindings.xml).
BINDING_NAME_MOUSELOOKTOGGLE_TOGGLE = "Toggle mouselook"

-- Called by the MOUSELOOKTOGGLE_TOGGLE binding on key press.
function MouselookToggle_Toggle()
    if IsMouselooking() then
        MouselookStop()
    else
        MouselookStart()
    end
end
