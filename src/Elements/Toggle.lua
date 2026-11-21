local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Widgets = import("Components/Widgets")
local Binding = import("Core/Binding")

-- Toggle / Checkbox: a switch or a square checkbox, with an optional key pill, an optional value
-- field and an optional colour swatch in the same row.
local Toggle = Base.Class("Toggle")

function Toggle.new(container, def)
    local self = setmetatable({}, Toggle)
    self.Value = def.Default == true
    self.Default = self.Value
    self.Style = def.Style or "Switch"
    Base.Init(self, container, def)

    if def.Keybind and def.Keybind ~= false then
        local spec = type(def.Keybind) == "table" and def.Keybind or { Key = def.Keybind ~= true and def.Keybind or def.Key }
        self.Binding = Binding.new({
            Key = spec.Key or spec.Default,
            Mode = spec.Mode or "Toggle",
            Modes = spec.Modes or { "Toggle", "Hold" },
            Capture = spec,
            Press = function(binding)
                if self.Locked then return end
                if binding.Mode == "Hold" then
                    self:Set(true)
                else
                    self:Set(not self.Value)
                end
            end,
            Release = function(binding)
                if binding.Mode == "Hold" and not self.Locked then self:Set(false) end
            end,
        })
        self.Window:_trackBind(self)
    end

    if def.Field then
        local spec = table.clone(def.Field)
        spec.Title = spec.Title or (self.Title .. " value")
        spec.Flag = spec.Flag or (self.Flag and (self.Flag .. "Value"))
        spec.Width = spec.Width or 70
        self.Field = import("Elements/Input").new(container, spec)
    end
    if def.Color then
        local spec = table.clone(def.Color)
        spec.Title = spec.Title or (self.Title .. " colour")
        spec.Flag = spec.Flag or (self.Flag and (self.Flag .. "Color"))
        self.Color = import("Elements/ColorPicker").new(container, spec)
    end

    -- in-row value editing: a compact box rendered by the row itself
    self.InlineField = def.Field ~= nil
    return self
end

function Toggle:Get()
    return self.Value
end

-- the optional value box is rendered inside the row and reads from its Input element
function Toggle:SetFieldText(text)
    if self._fieldBox and not self._fieldBox:IsFocused() then self._fieldBox.Text = text end
end

function Toggle:Set(value, silent)
    value = value and true or false
    if value == self.Value then return end
    self:_commit(value, silent)
end

function Toggle:ToggleEnabled()
    self:Set(not self.Value)
end

function Toggle:BindInfo()
    return self.Title, self.Value
end

function Toggle:Save()
    return self.Value
end

function Toggle:Load(value)
    if type(value) == "boolean" then self:Set(value) end
end

function Toggle:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Toggle",
        Size = UDim2.new(1, -6, 0, 30),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local reserve = 8
    if self.Binding then reserve += 46 end
    if self.Field then reserve += 58 end
    if self.Color then reserve += 34 end
    local hover = { on = false }

    local clickable = Util.New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        Text = "",
        Theme = {
            BackgroundColor3 = "SurfaceHover",
            BackgroundTransparency = function()
                return hover.on and 0.55 or 1
            end,
        },
        Parent = row,
    })
    Util.Corner("ElementRadius", clickable)
    mount:Give(clickable)

    local title = Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -(reserve + 8), 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = clickable,
    })
    local description
    if self.Description and self.Description ~= "" then
        row.Size = UDim2.new(1, -6, 0, 44)
        title.Size = UDim2.new(1, -(reserve + 8), 0, 18)
        title.Position = UDim2.fromOffset(8, 7)
        description = Util.Label({
            Text = self.Description,
            TextSize = 11,
            Position = UDim2.fromOffset(8, 24),
            Size = UDim2.new(1, -(reserve + 8), 0, 14),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Color = "TextMuted",
            Parent = clickable,
        })
    end

    -- the control side is laid out right to left with absolute anchors so the row can hold
    -- a field, a colour swatch, a key pill and the switch in any combination
    local control
    local function controlPosition(offset)
        if self.Style == "Checkbox" then
            control.Box.Position = UDim2.new(1, offset, 0.5, 0)
        else
            control.Track.Position = UDim2.new(1, offset, 0.5, 0)
        end
    end
    if self.Style == "Checkbox" then
        control = Widgets.Checkbox(clickable)
        control.Box.AnchorPoint = Vector2.new(1, 0.5)
        controlPosition(-6)
    else
        control = Widgets.Switch(clickable)
        control.Track.AnchorPoint = Vector2.new(1, 0.5)
        controlPosition(-6)
    end
    control:Set(self.Value, false)

    -- a key pill grows to the left of the switch; the switch slides left to make room
    local pill = nil
    local function placePill()
        if not pill then return end
        local width = pill.Button.AbsoluteSize.X
        if width <= 0 then return end
        local right = -6 - (self.Style == "Checkbox" and 18 or 34) - 8
        pill.Button.Position = UDim2.new(1, right, 0.5, 0)
        controlPosition(-6 - (self.Style == "Checkbox" and 18 or 34) - width - 10)
    end

    if self.Binding then
        pill = Widgets.KeyPill(clickable, self.Window, self.Binding, { Tooltip = "Click to bind a key, right click for Hold / Always" })
        pill.Button.AnchorPoint = Vector2.new(1, 0.5)
        mount:Give(function() pill:Destroy() end)
        mount:Give(self.Binding.Changed:Connect(placePill))
        mount:Give(pill.Button:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePill))
        task.defer(placePill)
        task.delay(0.1, placePill)
    end

    local function paintState()
        control:Set(self.Value, true)
        if self.Def.Field and self.Field then self:SetFieldText(tostring(self.Field:Get())) end
        if self.Locked then
            title.TextColor3 = Theme.Current.TextMuted
        elseif self.Def.Risky then
            title.TextColor3 = Theme.Current.Danger
        else
            title.TextColor3 = Theme.Current.Text
        end
    end

    paintState()
    mount:Give(self.Changed:Connect(paintState))
    mount:Give(self.StateChanged:Connect(paintState))

    local handle
    handle = Router.Attach(clickable, {
        OnClick = function()
            if self.Locked then
                if self.LockReason then self.Window:Notify({ Title = self.Title, Content = self.LockReason, Type = "Warning" }) end
                return
            end
            self:Set(not self.Value)
        end,
        Disabled = function() return false end,
        Tooltip = self.Tooltip or (self.Locked and self.LockedReason) or nil,
    })
    mount:Give(handle)

    -- hovering the row lifts it so a list of toggles is easy to scan
    mount:Give(Util.Hover(clickable, function(on)
        hover.on = on
        Theme.Refresh(clickable, 0.12)
    end))
    mount:Give(clickable)

    self.Views = self.Views or {}
    return row
end

return Toggle
