local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")

-- Segmented: a row of small tabs with a sliding highlight, or a stack when Values has many entries
local Segmented = Base.Class("Segmented")

function Segmented.new(container, def)
    local values = def.Values or {}
    local default = def.Default
    if default == nil then default = type(values[1]) == "table" and values[1].Value or values[1] end
    local self = setmetatable({ Value = default }, Segmented)
    self.Default = default
    Base.Init(self, container, def)
    self.Values = values
    return self
end

function Segmented:_index(value)
    for index, entry in self.Values do
        local v = type(entry) == "table" and (entry.Value ~= nil and entry.Value or entry.Title) or entry
        if v == value then return index end
    end
    return nil
end

function Segmented:Get() return self.Value end

function Segmented:Set(value, silent)
    local index = self:_index(value)
    if not index then return end
    if value == self.Value then return end
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
    self.Window:_touch()
end

function Segmented:Save() return self.Value end
function Segmented:Load(value) if value ~= nil then self:Set(value, true) end end

function Segmented:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Segmented",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(0.4, -6, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local width = self.Def.Width or (self.Def.Full and 1 or 0.6)
    local holder = Util.New("Frame", {
        Size = UDim2.new(width, width == 0.6 and -2 or -8, 1, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = function(t) return math.max(0.05, t.ElevatedTransparency) end },
        Parent = row,
    })
    Util.Corner("ElementRadius", holder)
    local highlight = Util.New("Frame", {
        Size = UDim2.fromScale(1 / math.max(#self.Values, 1), 1),
        Theme = { BackgroundColor3 = "SurfaceHover" },
        Parent = holder,
    })
    Util.Corner("ElementRadius", highlight)
    Util.Stroke(highlight, "Divider", function(t) return 0.5 end)
    local buttons = {}
    local function indexOf(value)
        for index, entry in self.Values do
            local v = type(entry) == "table" and (entry.Value ~= nil and entry.Value or entry.Title) or entry
            if v == value then return index end
        end
        return 1
    end
    local function paint(animate)
        local index = indexOf(self.Value)
        local goal = { Position = UDim2.fromScale((index - 1) / math.max(#self.Values, 1), 0) }
        if animate then
            Animation.Tween(highlight, "Toggle", goal)
        else
            for key, value in goal do highlight[key] = value end
        end
        for i, button in buttons do
            button.Label.TextColor3 = i == index and Theme.Current.Text or Theme.Current.TextMuted
        end
    end
    for index, entry in self.Values do
        local title = type(entry) == "table" and (entry.Title or tostring(entry.Value)) or tostring(entry)
        local value = type(entry) == "table" and (entry.Value ~= nil and entry.Value or entry.Title) or entry
        local button = Util.New("TextButton", {
            Size = UDim2.fromScale(1 / #self.Values, 1),
            Position = UDim2.fromScale((index - 1) / #self.Values, 0),
            Text = "",
            BackgroundTransparency = 1,
            Parent = holder,
        })
        local label = Util.Label({
            Text = title,
            TextSize = 11,
            Weight = Enum.FontWeight.Medium,
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = button,
        })
        buttons[index] = { Button = button, Label = label, Value = value }
        Router.Attach(button, {
            OnClick = function()
                if self.Locked then return end
                self:Set(value)
            end,
        })
    end
    paint(false)
    mount:Give(self.Changed:Connect(function() paint(true) end))
    return row
end

return Segmented
