local EditBox  = LibNUI.EditBox
local Frame    = LibNUI.Frame
local Label    = LibNUI.Label
local Texture  = LibNUI.Texture
local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- The EditBox placeholder, in the three states that matter: empty (prompt showing), typed-in
-- (prompt gone), and cleared again (prompt back). The third box proves the prompt tracks a
-- PROGRAMMATIC `Text()` call too, not just typing — the hand-rolled copies this replaced only ever
-- updated from the consumer's own OnTextChanged, so setting text in code left the prompt showing
-- over it.
--
-- The second box also supplies its own OnTextChanged: the widget wraps a caller-supplied handler
-- rather than taking the script, so both must run.
---@return TitleFrame
local function makeEditBox()
  local f = window("EditBox placeholder", 320, 240)

  local function boxed(y, opts)
    local box = Frame:new{ parent = f, position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 12, y}, Width = 220, Height = 22 } }
    Texture:new{ parent = box, layer = LibNUI.layer.Background, position = { All = true }, color = {0.05, 0.05, 0.06, 0.9} }
    opts.parent = box
    opts.position = { TopLeft = {6, -2}, BottomRight = {-4, 2} }
    return EditBox:new(opts)
  end

  boxed(-14, { placeholder = "Search outfits…" })

  local echo = Label:new{
    parent = f, position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 12, -108} },
    text = "typed: (nothing yet)",
  }
  boxed(-50, {
    placeholder = "Type here — prompt should vanish",
    OnTextChanged = function(self) echo:Text("typed: " .. (self:Text() or "")) end,
  })

  local third = boxed(-86, { placeholder = "Set/cleared in code" })
  local filled = false
  LibNUI.Button:new{
    parent = f, position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 240, -86}, Width = 60, Height = 22 },
    OnClick = function()
      filled = not filled
      third:Text(filled and "set in code" or "")
    end,
  }
  Label:new{
    parent = f, position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 240, -86} },
    text = "Toggle",
  }

  Label:new{
    parent = f, position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 12, -134} },
    text = "Toggle sets/clears box 3 in code — prompt must follow",
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "editbox",
  name = "EditBox placeholder",
  desc = "Placeholder prompt across typing, a caller's own OnTextChanged, and programmatic Text()",
  run  = toggling(makeEditBox),
})
