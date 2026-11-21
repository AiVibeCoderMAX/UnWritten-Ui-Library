local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Keybinds = import("Core/Keybinds")

-- Input: a text field on a titled row. Numeric mode formats and clamps the value.
-- options: Default, Placeholder, Numeric, Min, Max, Step, MaxLength, Finished (default on),
--          Validate(text) -> ok, message, Icon, Multiline, Height, ClearOnFocus
local Input = Base.Class("Input")

function Input.new(container, def)
    local self = setmetatable({}, Input)
    self.Value = def.Default
    if def.Numeric and self.Value == nil then self.Value = def.Min or 0 end
    self.Default = self.Value
    Base.Init(self, container, def)
    return self
end

function Input:_clean(text)
    text = tostring(text or "")
    local maxLength = tonumber(self.Def.MaxLength)
    if maxLength and maxLength >= 1 and #text > maxLength then
        text = text:sub(1, maxLength)
    end
    return text
end

function Input:_parse(text)
    if self.Def.Numeric then
        local number = tonumber((text:gsub("[^%d%.%-]", "")))
        if number == nil then return nil end
        if self.Def.Min and number < self.Def.Min then number = self.Def.Min end
        if self.Def.Max and number > self.Def.Max then number = self.Def.Max end
        if self.Def.Step and self.Def.Step > 0 then number = Util.Clean(Util.Round(number, self.Def.Step), self.Def.Step) end
        return number
    end
    return self:_clean(text)
end

function Input:Set(text, silent)
    local value = self:_parse(text)
    if value == nil or value == self.Value then return end
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
    self.Window:_touch()
end

function Input:Submit(text)
    self:Set(text)
    if self.Def.Finished ~= false then self:_notify() end
end

function Input:Save()
    return self.Value
end

function Input:Load(value)
    if value == nil then return end
    if self.Def.Numeric then
        self:Set(value, true)
    elseif type(value) == "string" then
        self:Set(value, true)
    end
end

function Input:Render(parent, mount)
    local def = self.Def
    local row = Util.New("Frame", {
        Name = "Input",
        Size = UDim2.new(1, -6, 0, def.Multiline and ((def.Height or 80) + 12) or 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    if not def.Multiline then
        Util.Label({
            Text = self.Title,
            TextSize = 13,
            Weight = Enum.FontWeight.Medium,
            Size = UDim2.new(0.44, -8, 1, 0),
            Position = UDim2.fromOffset(2, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
    end
    local hover = { on = false }
    local focused = { on = false }
    local holder = Util.New("Frame", {
        Size = def.Multiline and UDim2.new(1, -4, 0, def.Height or 80) or UDim2.new(1, -4, 1, 0),
        Position = def.Multiline and UDim2.fromOffset(0, 26) or UDim2.fromOffset(0, 0),
        Theme = {
            BackgroundColor3 = "Elevated",
            BackgroundTransparency = function(t)
                if focused.on then return math.max(0, t.ElevatedTransparency - 0.2) end
                return math.max(0.05, t.ElevatedTransparency)
            end,
        },
        Parent = row,
    })
    Util.Corner("ElementRadius", holder)
    Util.Stroke(holder, function(t) return focused.on and t.Accent or t.Stroke end, function(t)
        return focused.on and 0.15 or math.max(0, t.StrokeTransparency - 0.15)
    end)
    if def.Multiline then
        -- a title row above the box
        local label = Util.Label({
            Text = self.Title,
            TextSize = 13,
            Weight = Enum.FontWeight.Medium,
            Size = UDim2.new(1, -8, 0, 20),
            Position = UDim2.fromOffset(2, 2),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
        mount:Give(self.StateChanged:Connect(function() label.Text = self.Title end))
    end
    local x = 9
    if def.Icon then
        Util.Icon(def.Icon, {
            Size = UDim2.fromOffset(14, 14),
            AnchorPoint = Vector2.new(0, def.Multiline and 0 or 0.5),
            Position = def.Multiline and UDim2.fromOffset(9, 9) or UDim2.new(0, 9, 0.5, 0),
            Color = "TextMuted",
            Parent = holder,
        })
        x = 29
    end
    local box = Util.New("TextBox", {
        Size = def.Multiline and UDim2.new(1, -(x + 9), 1, -(def.Icon and 26 or 12)) or UDim2.new(1, -(x + 9), 1, 0),
        Position = def.Multiline and UDim2.fromOffset(x, def.Icon and 26 or 6) or UDim2.fromOffset(x, 0),
        Text = self.Value ~= nil and tostring(self.Value) or "",
        PlaceholderText = def.Placeholder or "",
        TextSize = 12,
        TextWrapped = def.Multiline == true,
        MultiLine = def.Multiline == true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = def.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        ClearTextOnFocus = def.ClearOnFocus == true,
        Theme = {
            TextColor3 = "Text",
            PlaceholderColor3 = "TextMuted",
            FontFace = Theme.Font(Enum.FontWeight.Regular),
        },
        Parent = holder,
    })
    if def.Multiline then
        box.TextTruncate = Enum.TextTruncate.None
    end
    Keybinds.SetTextBox(box)

    mount:Give(box.Focused:Connect(function()
        focused.on = true
        Theme.Refresh(holder, 0.15)
        -- game keys must not fire while typing
    end))
    mount:Give(box.FocusLost:Connect(function(enterPressed)
        focused.on = false
        Theme.Refresh(holder, 0.15)
        local raw = box.Text
        local parsed = self:_parse(raw)
        if def.Validate then
            local ok, message = def.Validate(raw)
            if not ok then
                box.Text = self.Value ~= nil and tostring(self.Value) or ""
                if message and message ~= "" then
                    self.Window:Notify({ Title = self.Title, Content = message, Type = "Warning" })
                end
                return
            end
        end
        if parsed ~= nil then
            self:Submit(parsed)
            box.Text = tostring(self.Value)
        else
            box.Text = self.Value ~= nil and tostring(self.Value) or ""
        end
    end))

    -- numeric: Up / Down arrows step, like a number field
    if def.Numeric then
        mount:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
            local filtered = box.Text:gsub("[^%d%.%-]", "")
            if filtered ~= box.Text then box.Text = filtered end
        end))
    end

    local clear = Util.New("ImageButton", {
        Name = "Clear",
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(1, def.Multiline and 0 or 0.5),
        Position = def.Multiline and UDim2.new(1, -9, 0, 9) or UDim2.new(1, -9, 0.5, 0),
        Image = Util.IconId("x"),
        ImageTransparency = 0.5,
        Visible = box.Text ~= "",
        Theme = { ImageColor3 = "TextMuted" },
        Parent = holder,
    })
    Router.Attach(clear, {
        OnClick = function()
            box.Text = ""
            if def.Numeric then self:Set(def.Min or 0) else self:Set("") end
        end,
    })
    mount:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
        clear.Visible = box.Text ~= ""
    end))

    mount:Give(Util.Hover(holder, function(on)
        hover.on = on
        Theme.Refresh(holder, 0.12)
    end))
    mount:Give(self.Changed:Connect(function(value)
        if not box:IsFocused() then box.Text = value ~= nil and tostring(value) or "" end
    end))
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Title" then
            for _, child in row:GetChildren() do
                if child:IsA("TextLabel") then child.Text = self.Title end
            end
        end
    end))
    return row
end

return Input
