local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Label: title on the left, a small value on the right that can change live
-- options: Text, Value, Color (token), ValueColor, Size
local Label = Base.Class("Label")

function Label.new(container, def)
    local self = setmetatable({ Value = def.Value }, Label)
    self.Default = def.Value
    Base.Init(self, container, def)
    self.LabelText = def.Text or def.Title
    self.Title = self.LabelText
    self.ValueColor = def.ValueColor
    return self
end

function Label:Set(text)
    self.LabelText = tostring(text)
    self.StateChanged:Fire("Text")
end

function Label:SetValue(value)
    self.Value = value
    self.StateChanged:Fire("Value")
end

function Label:SetValueColor(color)
    self.ValueColor = color
    self.StateChanged:Fire("ValueColor")
end

function Label:Get() return self.Value end
function Label:Save() return nil end
function Label:Load() end

function Label:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, self.Def.Size or 28),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local title = Util.Label({
        Text = self.LabelText,
        TextSize = 13,
        Size = UDim2.new(1, -90, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        Color = self.Def.Color or "TextDim",
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local value = Util.Label({
        Text = self.Value ~= nil and tostring(self.Value) or "",
        TextSize = 12,
        Weight = Enum.FontWeight.Medium,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 86, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Theme = {
            TextColor3 = function(t)
                local color = self.ValueColor
                if typeof(color) == "Color3" then return color end
                return t[color or "Text"] or t.Text
            end,
        },
        Parent = row,
    })
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Text" then title.Text = self.LabelText
        elseif state == "Value" then value.Text = self.Value ~= nil and tostring(self.Value) or ""
        elseif state == "ValueColor" then
            value.TextColor3 = typeof(self.ValueColor) == "Color3" and self.ValueColor or (Theme.Current[self.ValueColor or "Text"] or Theme.Current.Text)
        end
    end))
    if self.Def.Tooltip then Router.Attach(title, { Tooltip = self.Def.Tooltip }) end
    return row
end

return Label
