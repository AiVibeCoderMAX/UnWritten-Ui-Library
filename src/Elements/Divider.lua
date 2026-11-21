local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Divider: a line with optional centered text
local Divider = Base.Class("Divider")

function Divider.new(container, def)
    local self = setmetatable({}, Divider)
    Base.Init(self, container, def)
    self.Text = def.Text or (def.Title ~= "Divider" and def.Title) or nil
    return self
end
function Divider:Save() return nil end
function Divider:Load() end

function Divider:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, self.Text and 24 or 15),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local line = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Theme = { BackgroundColor3 = "Divider", BackgroundTransparency = 0.25 },
        Parent = row,
    })
    if self.Text then
        local label = Util.Label({
            Text = " " .. self.Text .. " ",
            TextSize = 10,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 0, 0, 16),
            AutomaticSize = Enum.AutomaticSize.X,
            TextXAlignment = Enum.TextXAlignment.Center,
            Color = "TextMuted",
            BackgroundTransparency = 0,
            Theme = { BackgroundColor3 = "Background" },
            Parent = row,
        })
        Util.Padding(label, 0, 2, 0, 2)
        label.ZIndex = 2
    end
    return row
end

return Divider
