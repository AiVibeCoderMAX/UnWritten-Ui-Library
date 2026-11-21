local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")

-- Range: two knobs on one track. Default = { lo, hi }, callback gets (lo, hi)
local RangeSlider = Base.Class("RangeSlider")

RangeSlider.DefaultValue = import("Elements/Slider").DefaultValue

function RangeSlider.new(container, def)
    def.Min = tonumber(def.Min) or 0
    def.Max = tonumber(def.Max) or 100
    if def.Max < def.Min then def.Min, def.Max = def.Max, def.Min end
    def.Step = tonumber(def.Step or def.Rounding)
    local default = def.Default or { def.Min, def.Max }
    local lo = RangeSlider.DefaultValue(def, default[1] or def.Min)
    local hi = RangeSlider.DefaultValue(def, default[2] or def.Max)
    lo, hi = math.min(lo, hi), math.max(lo, hi)
    local self = setmetatable({ Value = { lo, hi }, Low = lo, High = hi }, RangeSlider)
    self.Default = { lo, hi }
    Base.Init(self, container, def)
    self.Min, self.Max, self.Step = def.Min, def.Max, def.Step
    self.MinGap = def.MinGap or 0
    self.Suffix = def.Suffix or ""
    self.Prefix = def.Prefix or ""
    self.Format = def.Format
    return self
end

function RangeSlider:Display(value)
    value = value == nil and self.Value or value
    local function one(v)
        if self.Format then
            local ok, text = pcall(self.Format, v)
            if ok then return tostring(text) end
        end
        if self.Step and self.Step < 1 and self.Step > 0 then
            local decimals = math.max(0, -math.floor(math.log(self.Step, 10) + 0.5))
            return (string.format("%." .. decimals .. "f", v):gsub("0+$", ""):gsub("%.$", ""))
        end
        return tostring(math.floor(v + 0.5))
    end
    return self.Prefix .. one(value[1]) .. " – " .. one(value[2]) .. self.Suffix
end

function RangeSlider:Set(value, silent)
    if type(value) ~= "table" then return end
    local first = tonumber(value[1]) or 0
    local second = tonumber(value[2]) or 0
    local lo = math.max(math.min(first, second), 0)
    local hi = math.max(first, second)
    local min, max = tonumber(self.Min) or 0, tonumber(self.Max) or 100
    lo, hi = math.clamp(lo, min, max), math.clamp(hi, min, max)
    if self.Step and self.Step > 0 then
        lo = Util.Clean(Util.Round(lo, self.Step), self.Step)
        hi = Util.Clean(Util.Round(hi, self.Step), self.Step)
    end
    if self.MinGap > 0 then
        if hi - lo < self.MinGap then
            if self._editingHigh then
                lo = hi - self.MinGap
            else
                hi = lo + self.MinGap
            end
        end
        lo = math.max(lo, self.Min)
        hi = math.min(hi, self.Max)
    end
    self.Low, self.High = lo, hi
    self.Value = { lo, hi }
    self.Changed:Fire(self.Value)
    if not silent then
        Util.Safe(self.Def.Callback, lo, hi)
        self:_notifyListeners()
    end
    self.Window:_touch()
end

function RangeSlider:_notifyListeners()
    for _, fn in self._listeners do Util.Safe(fn, self.Low, self.High) end
end

function RangeSlider:_args()
    return self.Low, self.High
end

function RangeSlider:GetLow() return self.Low end
function RangeSlider:GetHigh() return self.High end

function RangeSlider:Reset()
    self:Set(self.Default)
end

function RangeSlider:Save()
    return { self.Low, self.High }
end

function RangeSlider:Load(value)
    if type(value) == "table" then self:Set(value, true) end
end

function RangeSlider:Render(parent, mount)
    local def = self.Def
    local row = Util.New("Frame", {
        Name = "Range",
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
    Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(1, -100, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = functions,
    })
    local valueLabel = Util.Label({
        Text = self:Display(),
        TextSize = 12,
        Weight = Enum.FontWeight.Medium,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 100, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        Color = "TextDim",
        Parent = functions,
    })

    local holder = Util.New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 34),
        Size = UDim2.new(1, -16, 0, 16),
        Parent = row,
    })
    local track = Util.New("Frame", {
        Position = UDim2.fromOffset(0, 5),
        Size = UDim2.new(1, 0, 0, 6),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.1 },
        Parent = holder,
    })
    Util.Corner(3, track)
    local fill = Util.New("Frame", {
        Size = UDim2.fromScale(0, 1),
        Theme = { BackgroundColor3 = "Accent" },
        Parent = track,
    })
    Util.Corner(3, fill)
    Util.Gradient(fill, "Accent", "AccentAlt", 0)

    local lowKnob = Util.New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 2,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    Util.Corner(7, lowKnob)
    Util.Stroke(lowKnob, "Background", nil, 2)
    local highKnob = Util.New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 2,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    Util.Corner(7, highKnob)
    Util.Stroke(highKnob, "Background", nil, 2)

    local function paint(animate)
        local span = self.Max - self.Min
        local a = span <= 0 and 0 or (self.Low - self.Min) / span
        local b = span <= 0 and 1 or (self.High - self.Min) / span
        a, b = math.clamp(a, 0, 1), math.clamp(b, 0, 1)
        local goal = { Position = UDim2.new(a, 0, 0.5, 0) }
        local goalHigh = { Position = UDim2.new(b, 0, 0.5, 0) }
        local fillGoal = { Position = UDim2.fromScale(a, 0), Size = UDim2.fromScale(b - a, 1) }
        if animate and Animation.Speed > 0 then
            Animation.Tween(lowKnob, "Hover", goal)
            Animation.Tween(highKnob, "Hover", goalHigh)
            Animation.Tween(fill, "Hover", fillGoal)
        else
            for key, value in goal do lowKnob[key] = value end
            for key, value in goalHigh do highKnob[key] = value end
            for key, value in fillGoal do fill[key] = value end
        end
        valueLabel.Text = self:Display()
    end
    paint(false)

    local function fromPoint(x)
        local width = track.AbsoluteSize.X
        if width <= 0 then return self.Value end
        local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        return self.Min + alpha * (self.Max - self.Min)
    end

    local dragging = nil
    local handle = Router.Attach(track, {
        Disabled = function() return self.Locked end,
        OnPress = function(_, point)
            local value = fromPoint(point.X)
            -- grab the nearer knob
            if math.abs(value - self.Low) <= math.abs(value - self.High) then
                dragging = "low"
                self._editingHigh = false
            else
                dragging = "high"
                self._editingHigh = true
            end
            local lo, hi = self.Low, self.High
            if dragging == "low" then lo = value else hi = value end
            self:Set({ lo, hi })
            paint(false)
            Animation.Tween(dragging == "low" and lowKnob or highKnob, "Press", { Size = UDim2.fromOffset(16, 16) })
        end,
        OnDrag = function(_, point)
            local value = fromPoint(point.X)
            local lo, hi = self.Low, self.High
            if dragging == "low" then lo = value else hi = value end
            self:Set({ lo, hi })
            paint(false)
        end,
        OnRelease = function()
            Animation.Tween(lowKnob, "Press", { Size = UDim2.fromOffset(14, 14) })
            Animation.Tween(highKnob, "Press", { Size = UDim2.fromOffset(14, 14) })
            dragging = nil
        end,
    })
    mount:Give(handle)
    mount:Give(self.Changed:Connect(function(value)
        if not dragging then paint(true) else valueLabel.Text = self:Display() end
    end))
    mount:Give(self.StateChanged:Connect(function() paint(false) end))
    return row
end

return RangeSlider
