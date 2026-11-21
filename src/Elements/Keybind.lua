local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Binding = import("Core/Binding")
local Widgets = import("Components/Widgets")

-- Keybind: a standalone bind row. A click captures, right click picks Toggle / Hold / Always.
local Keybind = Base.Class("Keybind")

function Keybind.new(container, def)
    local self = setmetatable({ Value = false }, Keybind)
    Base.Init(self, container, def)
    self.Binding = Binding.new({
        Key = def.Default or def.Key,
        Mode = def.Mode or "Toggle",
        Modes = def.Modes or { "Toggle", "Hold", "Always" },
        Capture = def,
        Press = function(binding)
            if self.Locked then return end
            if binding.Mode == "Hold" then
                self.Value = true
                self.Changed:Fire(true)
                if def.Callback then Util.Safe(def.Callback, true) end
                if def.Pressed then Util.Safe(def.Pressed) end
            else
                if def.Callback then Util.Safe(def.Callback, true) end
                if def.Pressed then Util.Safe(def.Pressed) end
            end
        end,
        Release = function(binding)
            if binding.Mode == "Hold" then
                self.Value = false
                self.Changed:Fire(false)
                if def.Callback then Util.Safe(def.Callback, false) end
            end
        end,
    })
    self.Mode = self.Binding.Mode
    self.Binding.Changed:Connect(function() self.Mode = self.Binding.Mode end)
    self.Window:_trackBind(self)
    return self
end

function Keybind:GetKey()
    return self.Binding.Key
end

function Keybind:SetKey(key)
    self.Binding:SetKey(key)
end

function Keybind:SetMode(mode)
    self.Binding:SetMode(mode)
    self.Mode = self.Binding.Mode
end

function Keybind:IsDown()
    return self.Binding:IsDown()
end

function Keybind:Get()
    return self.Binding.Key
end

function Keybind:Set(key, silent)
    self.Binding:SetKey(key)
end

function Keybind:Reset()
    self.Binding:SetKey(self.Def.Default or self.Def.Key)
    self.Binding:SetMode(self.Def.Mode or "Toggle")
end

function Keybind:Save()
    return self.Binding:Save()
end

function Keybind:Load(value)
    if type(value) == "table" then
        self.Binding:Load(value)
    elseif type(value) == "string" then
        self.Binding:SetKey(value)
    end
end

function Keybind:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Keybind",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(1, -150, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local modeHolder = Util.New("Frame", {
        Size = UDim2.fromOffset(62, 20),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.2 },
        Parent = row,
    })
    Util.Corner(5, modeHolder)
    local modeLabel = Util.Label({
        Text = self.Binding.Mode,
        TextSize = 11,
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        Color = "TextDim",
        Parent = modeHolder,
    })
    local pill = Widgets.KeyPill(row, self.Window, self.Binding, { Tooltip = "Click to bind" })
    pill.Button.AnchorPoint = Vector2.new(1, 0.5)
    pill.Button.Position = UDim2.new(1, -68, 0.5, 0)
    Router.Attach(modeHolder, {
        OnClick = function()
            local modes = self.Binding.Modes
            local index = table.find(modes, self.Binding.Mode) or 0
            self.Binding:SetMode(modes[(index % #modes) + 1])
        end,
        Tooltip = "Toggle, Hold or Always",
    })
    mount:Give(function() pill:Destroy() end)
    mount:Give(self.Binding.Changed:Connect(function()
        modeLabel.Text = self.Binding.Mode
    end))
    return row
end

return Keybind
