local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")

-- Log: a scrolling list of timestamped lines inside a card
local Log = Base.Class("Log")

function Log.new(container, def)
    local self = setmetatable({ Lines = {} }, Log)
    Base.Init(self, container, def)
    self.MaxLines = def.MaxLines or 200
    self.Height = def.Height or 150
    self.Timestamps = def.Timestamps ~= false
    return self
end

function Log:Add(text, color)
    local line = { text = tostring(text), color = color }
    table.insert(self.Lines, line)
    if #self.Lines > self.MaxLines then table.remove(self.Lines, 1) end
    self.StateChanged:Fire("Add", line)
end

function Log:AddColored(text, colorToken)
    self:Add(text, colorToken)
end

function Log:Clear()
    self.Lines = {}
    self.StateChanged:Fire("Clear")
end

function Log:Set(lines)
    self.Lines = {}
    for _, line in lines do table.insert(self.Lines, { text = tostring(line) }) end
    self.StateChanged:Fire("Clear")
end

function Log:Save() return nil end
function Log:Load() end

function Log:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local holder = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, self.Height + 12),
        Theme = { BackgroundColor3 = "Background", BackgroundTransparency = 0.35 },
        Parent = row,
    })
    Util.Corner("ElementRadius", holder)
    Util.Stroke(holder, "Divider", function(t) return 0.6 end)
    local header = Util.Label({
        Text = self.Title,
        TextSize = 10,
        Weight = Enum.FontWeight.SemiBold,
        Position = UDim2.fromOffset(10, 5),
        Size = UDim2.new(1, -20, 0, 14),
        Color = "TextMuted",
        Parent = holder,
    })
    local scroll = Util.New("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -24),
        Position = UDim2.fromOffset(8, 20),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        Theme = { ScrollBarImageColor3 = "Stroke" },
        Parent = holder,
    })
    local list = Util.List(scroll, 1)
    local update = Util.AutoCanvas(scroll, list)
    local function addLine(line)
        local text = line.text
        if self.Timestamps then
            text = os.date("[%H:%M:%S] ") .. text
        end
        local label = Util.Label({
            Text = text,
            TextSize = 11,
            TextWrapped = true,
            Size = UDim2.new(1, -4, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Color = line.color,
            Parent = scroll,
        })
        label.TextColor3 = typeof(line.color) == "Color3" and line.color or Theme.Current[line.color or "TextDim"]
        update()
        task.defer(function()
            if scroll.Parent then
                local layout = scroll:FindFirstChildOfClass("UIListLayout")
                if layout then scroll.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y) end
            end
        end)
    end
    for _, line in self.Lines do addLine(line) end
    mount:Give(self.StateChanged:Connect(function(state, line)
        if state == "Add" then
            addLine(line)
        elseif state == "Clear" then
            for _, child in scroll:GetChildren() do
                if child:IsA("TextLabel") then child:Destroy() end
            end
            for _, item in self.Lines do addLine(item) end
        end
    end))
    scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() update() end)
    return row
end

return Log
