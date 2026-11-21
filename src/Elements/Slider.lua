local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")

-- Slider: a track, a fill, a draggable knob, an editable value on the right, optional - / + buttons.
-- Range mode uses RangeSlider (a separate file) which reuses this layout.
local Slider = Base.Class("Slider")

-- options: Min, Max, Default, Step, Format(v), Prefix, Suffix, Input (value box, default true),
--          Buttons (- / +, default false), Icons = { From, To }, ShowRange, Live (default true)
function Slider.new(container, def)
    def.Min = tonumber(def.Min) or 0
    def.Max = tonumber(def.Max) or 100
    if def.Max < def.Min then def.Min, def.Max = def.Max, def.Min end
    def.Step = tonumber(def.Step or def.Rounding)
    if def.Step and def.Step > 0 then
        def.Step = math.abs(def.Step)
        def.Default = def.Default or def.Min
    end
    local default = def.Default
    if default == nil then default = def.Min end
    default = Slider.DefaultValue(def, default)
    local self = setmetatable({ Value = default }, Slider)
    self.Default = default
    Base.Init(self, container, def)
    self.Min = def.Min
    self.Max = def.Max
    self.Step = def.Step
    self.Suffix = def.Suffix or ""
    self.Prefix = def.Prefix or ""
    self.Live = def.Live ~= false
    self.Input = def.Input ~= false
    self.Format = def.Format
    return self
end

local computeDefault
computeDefault = function(def, value)
    value = tonumber(value) or def.Min
    value = math.clamp(value, def.Min, def.Max)
    if def.Step and def.Step > 0 then value = Util.Round(value, def.Step) end
    return value
end

function Slider:Display(value)
    value = value == nil and self.Value or value
    if self.Format then
        local ok, text = pcall(self.Format, value)
        if ok then return tostring(self.Prefix) .. tostring(text) .. tostring(self.Suffix) end
    end
    local step = self.Step
    local text
    if step and step < 1 and step > 0 then
        local decimals = math.max(0, -math.floor(math.log(step, 10) + 0.5))
        text = string.format("%." .. decimals .. "f", value)
        text = text:gsub("0+$", ""):gsub("%.$", "")
    else
        text = tostring(math.floor(value + 0.5))
    end
    return self.Prefix .. text .. self.Suffix
end

function Slider:Set(value, silent)
    value = tonumber(value)
    if value == nil then return end
    value = math.clamp(value, self.Min, self.Max)
    if self.Step and self.Step > 0 then value = Util.Clean(Util.Round(value, self.Step), self.Step) end
    value = math.clamp(value, self.Min, self.Max)
    if value == self.Value then
        if not silent and self.Def.Live then return end
    end
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
    self.Window:_touch()
end

function Slider:SetMin(min)
    self.Min = tonumber(min) or self.Min
    self.Def.Min = self.Min
    if self.Value < self.Min then self:Set(self.Min) end
    self.StateChanged:Fire("Min")
end

function Slider:SetMax(max)
    self.Max = tonumber(max) or self.Max
    self.Def.Max = self.Max
    if self.Value > self.Max then self:Set(self.Max) end
    self.StateChanged:Fire("Max")
end

function Slider:Reset()
    self:Set(self.Default)
end

function Slider:Save()
    return self.Value
end

function Slider:Load(value)
    if type(value) == "number" then self:Set(value, true) end
end

function Slider:Render(parent, mount)
    local def = self.Def
    local row = Util.New("Frame", {
        Name = "Slider",
        Size = UDim2.new(1, -6, 0, self.Description and 64 or 46),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local functions = Util.New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 20),
        Position = UDim2.fromOffset(8, 6),
        Parent = row,
    })
    local title = Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(1, -90, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Theme = {
            TextColor3 = function(t) return self.Locked and t.TextMuted or t.Text end,
            FontFace = Theme.Font(Enum.FontWeight.Medium),
        },
        Parent = functions,
    })
    local tooltip = def.Tooltip or (self.Locked and self.LockedReason) or nil
    if tooltip then
        local info = Util.Icon("circle-question-mark", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.fromOffset(title.TextBounds.X + 6, 4),
            Color = "TextMuted",
            Parent = functions,
        })
        Router.Attach(info, { Tooltip = tooltip })
    end
    local right = Util.New("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = functions,
    })
    Util.List(right, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local order = 0
    local function nextOrder() order += 1 return order end

    local valueBox
    if def.Input ~= false then
        valueBox = Util.New("TextBox", {
            Text = self:Display(),
            TextSize = 12,
            Size = UDim2.fromOffset(46, 20),
            TextXAlignment = Enum.TextXAlignment.Right,
            ClearTextOnFocus = false,
            LayoutOrder = nextOrder(),
            Theme = { TextColor3 = "TextDim", FontFace = Theme.Font(Enum.FontWeight.Medium) },
            Parent = right,
        })
        mount:Give(valueBox.FocusLost:Connect(function()
            local number = tonumber((valueBox.Text:gsub("[^%d%.%-]", "")))
            if number then self:Set(number) end
            valueBox.Text = self:Display()
        end))
        mount:Give(valueBox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                valueBox.CursorPosition = #valueBox.Text + 1
            end
        end))
    end

    if def.Buttons then
        local function stepper(icon, delta)
            local button = Util.New("TextButton", {
                Size = UDim2.fromOffset(18, 18),
                Text = "",
                LayoutOrder = nextOrder(),
                Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.2 },
                Parent = right,
            })
            Util.Corner(4, button)
            Util.Icon(icon, {
                Size = UDim2.fromOffset(10, 10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Parent = button,
            })
            Router.Attach(button, {
                OnClick = function()
                    local step = self.Step or ((self.Max - self.Min) / 100)
                    self:Set(self.Value + step * delta)
                end,
            })
            return button
        end
        stepper("minus", -1)
        stepper("plus", 1)
    end

    -- track ---------------------------------------------------------------------
    local trackY = 34
    local trackHolder = Util.New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, trackY),
        Size = UDim2.new(1, -16, 0, 16),
        Parent = row,
    })
    local leftIcon = def.Icons and def.Icons.From or def.IconFrom
    local rightIcon = def.Icons and def.Icons.To or def.IconTo
    local leftPad, rightPad = 0, 0
    if leftIcon then
        Util.Icon(leftIcon, {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.new(0, 0, 0.5, -6),
            Parent = trackHolder,
        })
        leftPad = 18
    end
    if rightIcon then
        Util.Icon(rightIcon, {
            Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Parent = trackHolder,
        })
        rightPad = 18
    end
    local track = Util.New("Frame", {
        Name = "Track",
        Position = UDim2.fromOffset(leftPad, 5),
        Size = UDim2.new(1, -(leftPad + rightPad), 0, 6),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.1 },
        Parent = trackHolder,
    })
    Util.Corner(3, track)
    local fill = Util.New("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        Theme = { BackgroundColor3 = "Accent" },
        Parent = track,
    })
    Util.Corner(3, fill)
    Util.Gradient(fill, "Accent", "AccentAlt", 0)
    local knob = Util.New("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 2,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    Util.Corner(7, knob)
    Util.Stroke(knob, "Background", nil, 2)
    local knobScale = Util.New("UIScale", { Scale = 1, Parent = knob })

    local dragging = { on = false }

    local function paint(value, animate)
        local span = self.Max - self.Min
        local alpha = span <= 0 and 0 or (value - self.Min) / span
        alpha = math.clamp(alpha, 0, 1)
        if animate and Animation.Speed > 0 then
            Animation.Tween(fill, "Hover", { Size = UDim2.fromScale(alpha, 1) })
            Animation.Tween(knob, "Hover", { Position = UDim2.new(alpha, 0, 0.5, 0) })
        else
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        end
        if valueBox and not valueBox:IsFocused() then valueBox.Text = self:Display(value) end
    end

    paint(self.Value, false)

    local function fromPoint(x)
        local width = track.AbsoluteSize.X
        if width <= 0 then return self.Value end
        local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        return self.Min + alpha * (self.Max - self.Min)
    end

    local handle
    handle = Router.Attach(track, {
        Disabled = function() return self.Locked end,
        OnPress = function(_, point)
            dragging.on = true
            Animation.Tween(knobScale, "Press", { Scale = 1.25 })
            self:Set(fromPoint(point.X))
        end,
        OnDrag = function(_, point)
            local value = fromPoint(point.X)
            if self.Live then
                self:Set(value)
                paint(value, false)
            else
                paint(value, false)
                self._pendingValue = value
            end
        end,
        OnRelease = function()
            dragging.on = false
            Animation.Tween(knobScale, "Press", { Scale = 1 })
            if self._pendingValue then
                self:Set(self._pendingValue)
                self._pendingValue = nil
            end
        end,
        OnClick = function(point)
            self:Set(fromPoint(point.X))
        end,
    })
    mount:Give(handle)
    mount:Give(Util.Hover(track, function(on)
        if dragging.on then return end
        Animation.Tween(knobScale, "Hover", { Scale = on and 1.18 or 1 })
    end))

    mount:Give(self.Changed:Connect(function(value)
        if dragging.on then return end
        paint(value, true)
    end))
    if valueBox then
        mount:Give(self.StateChanged:Connect(function() paint(self.Value, false) end))
    end
    mount:Give(row)

    self._paint = paint
    return row
end

Slider.DefaultValue = computeDefault

return Slider
