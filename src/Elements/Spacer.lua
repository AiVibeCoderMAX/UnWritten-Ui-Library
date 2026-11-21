local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Spacer
local Spacer = Base.Class("Spacer")

function Spacer.new(container, def)
    local self = setmetatable({}, Spacer)
    Base.Init(self, container, def)
    return self
end
function Spacer:Save() return nil end
function Spacer:Load() end

function Spacer:Render(parent, mount)
    return Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, self.Def.Height or 8),
        BackgroundTransparency = 1,
        Parent = parent,
    })
end

return Spacer
