local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Paragraph: a wrapped block of rich text with an optional title and icon
local Paragraph = Base.Class("Paragraph")

function Paragraph.new(container, def)
    local self = setmetatable({}, Paragraph)
    Base.Init(self, container, def)
    self.Content = def.Content or def.Text or ""
    return self
end

function Paragraph:SetContent(text)
    self.Content = text
    self.StateChanged:Fire("Content")
end
function Paragraph:Set(text) self:SetContent(text) end
function Paragraph:Get() return self.Content end
function Paragraph:Save() return nil end
function Paragraph:Load() end

function Paragraph:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Padding(row, 2, 4, 4, 4)
    local heading = self.Def.Title or self.Title
    local y = 0
    if heading and heading ~= "" and heading ~= self.Content then
        if self.Def.Icon then
            Util.Icon(self.Def.Icon, {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.fromOffset(0, 2),
                Color = "Accent",
                Parent = row,
            })
        end
        local title = Util.Label({
            Text = heading,
            TextSize = 13,
            Weight = Enum.FontWeight.SemiBold,
            Position = UDim2.fromOffset(self.Def.Icon and 20 or 0, 0),
            Size = UDim2.new(1, self.Def.Icon and -20 or 0, 0, 18),
            Parent = row,
        })
        y = 22
        mount:Give(self.StateChanged:Connect(function() title.Text = self.Def.Title or self.Title end))
    end
    local body = Util.Label({
        Text = self.Content,
        TextSize = 12,
        TextWrapped = true,
        RichText = true,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Color = "TextDim",
        Parent = row,
    })
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Content" then body.Text = self.Content end
    end))
    return row
end

return Paragraph
