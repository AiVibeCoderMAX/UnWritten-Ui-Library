local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- ProgressBar: animated fill; Set(value) with an optional tween
local ProgressBar = Base.Class("ProgressBar")

function ProgressBar.new(container, def)
    local self = setmetatable({ Value = def.Default or def.Value or 0 }, ProgressBar)
    self.Default = self.Value
    Base.Init(self, container, def)
    self.Max = def.Max or 100
    self.Suffix = def.Suffix or "%"
    self.Format = def.Format
    return self
end

function ProgressBar:Set(value, silent)
    value = math.clamp(tonumber(value) or 0, 0, self.Max)
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
end

function ProgressBar:SetMax(max)
    self.Max = math.max(tonumber(max) or 1, 0.0001)
    self.Changed:Fire(self.Value)
end

function ProgressBar:Get() return self.Value end
function ProgressBar:Save() return nil end
function ProgressBar:Load() end

function ProgressBar:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, 38),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 12,
        Size = UDim2.new(1, -60, 0, 16),
        Position = UDim2.fromOffset(2, 0),
        Color = "TextDim",
        Parent = row,
    })
    local valueLabel = Util.Label({
        Text = "",
        TextSize = 11,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -2, 0, 0),
        Size = UDim2.new(0, 60, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Right,
        Color = "TextMuted",
        Parent = row,
    })
    local track = Util.New("Frame", {
        Size = UDim2.new(1, -4, 0, 8),
        Position = UDim2.fromOffset(2, 22),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.1 },
        Parent = row,
    })
    Util.Corner(4, track)
    local fill = Util.New("Frame", {
        Size = UDim2.fromScale(0, 1),
        Theme = { BackgroundColor3 = typeof(self.Def.Color) == "Color3" and function() return self.Def.Color end or (self.Def.Color or "Accent") },
        Parent = track,
    })
    Util.Corner(4, fill)
    Util.Gradient(fill, "Accent", "AccentAlt", 0)
    local function display(value)
        if self.Format then
            local ok, text = pcall(self.Format, value, self.Max)
            if ok then return tostring(text) end
        end
        return math.floor(value / self.Max * 100 + 0.5) .. self.Suffix
    end
    local function paint(animate)
        local alpha = math.clamp(self.Value / self.Max, 0, 1)
        valueLabel.Text = display(self.Value)
        if animate and Theme.Current.AnimSpeed > 0 then
            Util.Tween(fill, 0.25, { Size = UDim2.fromScale(alpha, 1) })
        else
            fill.Size = UDim2.fromScale(alpha, 1)
        end
    end
    fill.Size = UDim2.fromScale(math.clamp(self.Value / self.Max, 0, 1), 1)
    paint(false)
    mount:Give(self.Changed:Connect(function() paint(true) end))
    return row
end

return ProgressBar
