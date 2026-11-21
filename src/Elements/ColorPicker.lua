local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Binding = import("Core/Binding")

-- ColorPicker: a swatch that opens an HSV picker with a hue bar, saturation / value square,
-- alpha (optional), hex field and RGB / HSV readouts, plus rainbow cycling.
-- options: Default, Transparency (enables alpha), Rainbow, Alpha (alias), Quick = { colours }
local ColorPicker = Base.Class("ColorPicker")

local function toHex(color)
    local hex = color:ToHex()
    return "#" .. hex:upper()
end

function ColorPicker.new(container, def)
    local color = def.Default
    if typeof(color) ~= "Color3" then color = Color3.fromRGB(78, 132, 255) end
    local self = setmetatable({ Value = color }, ColorPicker)
    self.Alpha = def.Transparency == true or def.Alpha == true
    self.TransparencyDefault = def.TransparencyValue or 0
    self.Default = color
    self.DefaultAlpha = self.TransparencyDefault
    Base.Init(self, container, def)
    self.Rainbow = def.Rainbow == true
    self._h, self._s, self._v = color:ToHSV()
    self._alpha = self.TransparencyDefault
    self._rainbowConnection = nil
    if def.Rainbow then self:SetRainbow(true) end
    return self
end

function ColorPicker:_args()
    return self.Value, self.TransparencyDefault
end

function ColorPicker:Get()
    return self.Value
end

function ColorPicker:GetAlpha()
    return self.TransparencyDefault
end

function ColorPicker:Set(color, silent)
    if typeof(color) == "Color3" then
        self.Value = color
        self._h, self._s, self._v = color:ToHSV()
    elseif type(color) == "string" then
        local ok, parsed = pcall(Color3.fromHex, color)
        if not ok then return end
        self:Set(parsed, silent)
        return
    else
        return
    end
    self.Changed:Fire(self.Value, self.TransparencyDefault)
    if not silent then
        Util.Safe(self.Def.Callback, self.Value, self.TransparencyDefault)
        for _, fn in self._listeners do Util.Safe(fn, self.Value, self.TransparencyDefault) end
    end
    self.Window:_touch()
end

function ColorPicker:SetAlpha(alpha, silent)
    self.TransparencyDefault = math.clamp(alpha or 0, 0, 1)
    self.Changed:Fire(self.Value, self.TransparencyDefault)
    if not silent and self.Def.Callback then Util.Safe(self.Def.Callback, self.Value, self.TransparencyDefault) end
end

function ColorPicker:SetRainbow(on)
    self.Rainbow = on and true or false
    if self.Rainbow and not self._rainbowConnection then
        local hue = self._h
        self._rainbowConnection = Animation.Loop(1 / 30, function()
            hue = (hue + 0.006) % 1
            local color = Color3.fromHSV(hue, self._s, self._v)
            self.Value = color
            self._h = hue
            self.Changed:Fire(color, self.TransparencyDefault)
            if self.Def.Callback then Util.Safe(self.Def.Callback, color, self.TransparencyDefault) end
        end)
    elseif not self.Rainbow and self._rainbowConnection then
        self._rainbowConnection:Disconnect()
        self._rainbowConnection = nil
    end
    self.StateChanged:Fire("Rainbow")
end

function ColorPicker:Save()
    return {
        math.round(self.Value.R * 255),
        math.round(self.Value.G * 255),
        math.round(self.Value.B * 255),
        math.round((1 - self.TransparencyDefault) * 255) / 255,
    }
end

function ColorPicker:Load(value)
    if type(value) == "table" and #value >= 3 then
        self:Set(Color3.fromRGB(value[1], value[2], value[3]), true)
        if value[4] ~= nil then self.TransparencyDefault = 1 - value[4] end
    elseif type(value) == "string" then
        self:Set(value, true)
    elseif typeof(value) == "Color3" then
        self:Set(value, true)
    end
end

function ColorPicker:Reset()
    self:SetRainbow(false)
    self:Set(self.Default)
    self.TransparencyDefault = self.DefaultAlpha
    self.Changed:Fire(self.Value, self.TransparencyDefault)
end

-- the picker surface, opened under the swatch
function ColorPicker:_open(anchor)
    local Popup = import("Components/Popup")
    local menu = Popup.new({ Anchor = anchor, Align = "Right", Width = 236, MaxHeight = 400 })
    menu:_build()
    menu:Show()
    local body = menu.Body
    local padding = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = body,
    })

    -- saturation / value square ----------------------------------------------------
    local square = Util.New("Frame", {
        Size = UDim2.fromOffset(220, 130),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromHSV(self._h, 1, 1),
        Parent = padding,
    })
    Util.Corner("ElementRadius", square)
    local white = Util.New("Frame", {
        Size = UDim2.fromScale(1, 1),
        Theme = { BackgroundColor3 = function(t) return Color3.new(1, 1, 1) end },
        Parent = square,
    })
    Util.Corner("ElementRadius", white)
    Util.New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = white,
    })
    local black = Util.New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        Parent = square,
    })
    Util.Corner("ElementRadius", black)
    Util.New("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Parent = black,
    })
    local cursor = Util.New("Frame", {
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = square,
    })
    Util.Corner(6, cursor)
    Util.Stroke(cursor, function() return Color3.new(1, 1, 1) end, function() return 0 end, 2)
    local cursorInner = Util.New("Frame", {
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = cursor,
    })
    Util.Stroke(cursorInner, function() return Color3.new(0, 0, 0) end, function() return 0.4 end, 1)

    -- hue bar ----------------------------------------------------------------------
    local hueBar = Util.New("Frame", {
        Size = UDim2.fromOffset(220, 12),
        Position = UDim2.fromOffset(2, 140),
        Parent = padding,
    })
    Util.Corner(6, hueBar)
    Util.New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
            ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        }),
        Parent = hueBar,
    })
    local hueCursor = Util.New("Frame", {
        Size = UDim2.fromOffset(4, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(self._h, 0, 0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Parent = hueBar,
    })
    Util.Corner(2, hueCursor)
    Util.Stroke(hueCursor, function() return Color3.new(0, 0, 0) end, function() return 0.35 end)

    local alphaBar, alphaCursor
    if self.Alpha then
        alphaBar = Util.New("Frame", {
            Size = UDim2.fromOffset(220, 12),
            Position = UDim2.fromOffset(2, 158),
            Theme = { BackgroundColor3 = "ElevatedHover" },
            Parent = padding,
        })
        Util.Corner(6, alphaBar)
        local alphaFill = Util.New("Frame", {
            Size = UDim2.fromScale(1 - self.TransparencyDefault, 1),
            BackgroundColor3 = self.Value,
            Parent = alphaBar,
        })
        Util.Corner(6, alphaFill)
        local aGradient = Util.New("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = alphaFill,
        })
        alphaCursor = Util.New("Frame", {
            Size = UDim2.fromOffset(4, 18),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1 - self.TransparencyDefault, 0, 0.5, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            Parent = alphaBar,
        })
        Util.Corner(2, alphaCursor)
        Util.Stroke(alphaCursor, function() return Color3.new(0, 0, 0) end, function() return 0.35 end)
    end

    local function paint()
        local color = Color3.fromHSV(self._h, self._s, self._v)
        square.BackgroundColor3 = Color3.fromHSV(self._h, 1, 1)
        cursor.Position = UDim2.new(self._s, 0, 1 - self._v, 0)
        hueCursor.Position = UDim2.new(self._h, 0, 0.5, 0)
        if alphaCursor then alphaCursor.Position = UDim2.new(1 - self.TransparencyDefault, 0, 0.5, 0) end
        hexBox.Text = toHex(color)
        rgbLabel.Text = string.format("%d, %d, %d", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
        hsvLabel.Text = string.format("%d°, %d%%, %d%%", math.round(self._h * 360), math.round(self._s * 100), math.round(self._v * 100))
        preview.BackgroundColor3 = color
    end

    -- hex + readouts ----------------------------------------------------------------
    local preview = Util.New("Frame", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromOffset(2, self.Alpha and 180 or 160),
        BackgroundColor3 = self.Value,
        Parent = padding,
    })
    Util.Corner("ElementRadius", preview)
    Util.Stroke(preview, "Stroke", function() return 0.5 end)
    local hexHolder = Util.New("Frame", {
        Size = UDim2.fromOffset(104, 26),
        Position = UDim2.fromOffset(34, self.Alpha and 180 or 160),
        Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.3 },
        Parent = padding,
    })
    Util.Corner("ElementRadius", hexHolder)
    local hexBox = Util.New("TextBox", {
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.fromOffset(7, 0),
        Text = toHex(self.Value),
        TextSize = 12,
        Theme = { TextColor3 = "Text" },
        Parent = hexHolder,
    })
    local copy = Util.New("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromOffset(142, self.Alpha and 180 or 160),
        Text = "",
        Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.3 },
        Parent = padding,
    })
    Util.Corner("ElementRadius", copy)
    Util.Icon("copy", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = copy })
    Router.Attach(copy, {
        OnClick = function()
            if setclipboard then pcall(setclipboard, toHex(self.Value)) end
            self.Window:Notify({ Title = "Copied", Content = toHex(self.Value), Type = "Success", Duration = 1.5 })
        end,
        Tooltip = "Copy hex",
    })
    local rainbowToggle
    if not (self.Alpha) then
        rainbowToggle = Util.New("TextButton", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.fromOffset(172, 160),
            Text = "",
            Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.3 },
            Parent = padding,
        })
        Util.Corner("ElementRadius", rainbowToggle)
        local wand = Util.Icon("wand-sparkles", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Color = "TextDim", Parent = rainbowToggle })
        Router.Attach(rainbowToggle, {
            OnClick = function()
                self:SetRainbow(not self.Rainbow)
                wand.ImageColor3 = import("Core/Theme").Current[self.Rainbow and "Accent" or "TextDim"]
            end,
            Tooltip = "Cycle the hue",
        })
    end
    local rgbLabel = Util.Label({
        Text = "",
        TextSize = 10,
        Position = UDim2.fromOffset(2, self.Alpha and 212 or 192),
        Size = UDim2.new(0.5, 0, 0, 14),
        Color = "TextMuted",
        Parent = padding,
    })
    local hsvLabel = Util.Label({
        Text = "",
        TextSize = 10,
        Position = UDim2.fromOffset(100, self.Alpha and 212 or 192),
        Size = UDim2.new(0.5, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
        Color = "TextMuted",
        Parent = padding,
    })
    padding.Size = UDim2.new(1, 0, 0, self.Alpha and 232 or 212)

    -- input handlers ------------------------------------------------------------------
    local function applyColor(silent)
        local color = Color3.fromHSV(self._h, self._s, self._v)
        self.Value = color
        self.Changed:Fire(color, self.TransparencyDefault)
        if not silent then
            if self.Def.Callback then Util.Safe(self.Def.Callback, color, self.TransparencyDefault) end
        end
        self.Window:_touch()
    end

    local function trackSquare(handle, point)
        local position = square.AbsolutePosition
        local size = square.AbsoluteSize
        self._s = math.clamp((point.X - position.X) / math.max(size.X, 1), 0, 1)
        self._v = 1 - math.clamp((point.Y - position.Y) / math.max(size.Y, 1), 0, 1)
        paint()
        applyColor(false)
    end
    Router.Attach(square, {
        OnPress = function(_, point) trackSquare(nil, point) end,
        OnDrag = function(_, point) trackSquare(nil, point) end,
    })
    Router.Attach(hueBar, {
        OnPress = function(_, point)
            self._h = math.clamp((point.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
            paint()
            applyColor(false)
        end,
        OnDrag = function(_, point)
            self._h = math.clamp((point.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
            paint()
            applyColor(false)
        end,
    })
    if alphaBar then
        local function trackAlpha(point)
            local percent = math.clamp((point.X - alphaBar.AbsolutePosition.X) / math.max(alphaBar.AbsoluteSize.X, 1), 0, 1)
            self.TransparencyDefault = 1 - percent
            paint()
            self.Changed:Fire(self.Value, self.TransparencyDefault)
            if self.Def.Callback then Util.Safe(self.Def.Callback, self.Value, self.TransparencyDefault) end
        end
        Router.Attach(alphaBar, {
            OnPress = function(_, point) trackAlpha(point) end,
            OnDrag = function(_, point) trackAlpha(point) end,
        })
    end
    hexBox.FocusLost:Connect(function()
        local ok, color = pcall(Color3.fromHex, hexBox.Text)
        if ok then
            self:Set(color)
            self._h, self._s, self._v = color:ToHSV()
            paint()
        else
            hexBox.Text = toHex(self.Value)
        end
    end)
    paint()
    return menu
end

function ColorPicker:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "ColorPicker",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local swatchHolder = Util.New("TextButton", {
        Text = "",
        Size = UDim2.fromOffset(36, 22),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.2 },
        Parent = row,
    })
    Util.Corner("ElementRadius", swatchHolder)
    local swatch = Util.New("Frame", {
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = self.Value,
        Parent = swatchHolder,
    })
    Util.Corner("ElementRadius", swatch)
    if self.Alpha then swatch.BackgroundTransparency = self.TransparencyDefault end
    local hex = Util.Label({
        Text = "",
        TextSize = 10,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -44, 0.5, 0),
        Size = UDim2.fromOffset(56, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
        Color = "TextMuted",
        Parent = row,
    })
    local function refresh()
        swatch.BackgroundColor3 = self.Value
        swatch.BackgroundTransparency = self.Alpha and self.TransparencyDefault or 0
        hex.Text = toHex(self.Value)
    end
    refresh()
    mount:Give(self.Changed:Connect(refresh))
    Router.Attach(swatchHolder, {
        OnClick = function()
            if self.Locked then
                if self.LockedReason then self.Window:Notify({ Title = self.Title, Content = self.LockedReason, Type = "Warning" }) end
                return
            end
            self:_open(swatchHolder)
        end,
    })
    return row
end

return ColorPicker
