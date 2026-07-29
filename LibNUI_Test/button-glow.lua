local Button   = LibNUI.Button
local window   = LibNUITest.window
local toggling = LibNUITest.toggling

-- Button hover glow (#703). Intensity is the kind of thing only a side-by-side look can settle,
-- so the cases sit stacked: hover each in turn and compare. `glowAlpha` exists because the only
-- lever before was `glow = false`, and a control with no hover response at all reads as disabled.
local CASES = {
  { label = "default (1)",   opts = {} },
  { label = "glowAlpha 0.9", opts = { glowAlpha = 0.9 } },
  { label = "glowAlpha 0.5", opts = { glowAlpha = 0.5 } },
  { label = "glow = false",  opts = { glow = false } },
}

local PAD, TITLE_H, BTN_W, BTN_H, ROW_H = 10, 38, 150, 26, 32

---@return TitleFrame
local function makeGlow()
  local f = window("Button Glow", BTN_W + PAD * 2 + 8, TITLE_H + #CASES * ROW_H + PAD)
  for i, case in ipairs(CASES) do
    local opts = {
      parent     = f,
      background = "backdrop",
      position   = { TopLeft = { PAD, -(TITLE_H + (i - 1) * ROW_H) }, Size = { BTN_W, BTN_H } },
    }
    for k, v in pairs(case.opts) do opts[k] = v end
    Button:new(opts):Text(case.label)
  end
  return f
end

table.insert(LibNUITest.tests, {
  key  = "buttonglow",
  name = "Button: hover glow",
  desc = "Hover to compare full, softened (glowAlpha) and suppressed glow side by side (#703)",
  run  = toggling(makeGlow),
})
