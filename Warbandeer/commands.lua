local _, ns = ...

ns:registerCommand("", nil, function(self)
  self:Open()
end, "Open the main interface")

for _, v in pairs(ns.views) do
  ns:registerCommand(v.name, nil, function(self)
    self:view(v.name)
  end, "Show the "..v.name.." view")
end
