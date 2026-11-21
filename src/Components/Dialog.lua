local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")

-- modal dialog: a dimmed backdrop, a card with an optional input and any number of buttons.
-- A callback that returns false keeps the dialog open.
local Dialog = {}

local function build(window, def)
    local overlay = Util.New("Frame", {
        Name = "Dialog",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 200,
        Parent = Layer.Overlay,
    })
    local card = Util.New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(def.Width or 320, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 201,
        Theme = {
            BackgroundColor3 = "Elevated",
            BackgroundTransparency = function(t) return math.max(0, t.ElevatedTransparency - 0.1) end,
        },
        Parent = overlay,
    })
    Util.Corner("Radius", card)
    Util.Stroke(card, "Stroke", function(t) return math.max(0, t.StrokeTransparency - 0.2) end)
    local scale = Util.New("UIScale", { Scale = 0.94, Parent = card })
    Util.Padding(card, 16, 16, 14, 16)

    local content = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 202,
        Parent = card,
    })
    local list = Util.List(content, 8)
    Animation.Tween(overlay, "Fade", { BackgroundTransparency = 0.35 })
    Animation.Tween(scale, "Pop", { Scale = 1 })

    local y = 0
    if def.Icon then
        Util.Icon(def.Icon, {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.fromOffset(0, 1),
            Color = "Accent",
            ZIndex = 203,
            Parent = content,
        })
    end
    Util.Label({
        Text = def.Title or "Dialog",
        TextSize = 15,
        Weight = Enum.FontWeight.Bold,
        Position = UDim2.fromOffset(def.Icon and 26 or 0, 0),
        Size = UDim2.new(1, def.Icon and -26 or 0, 0, 20),
        ZIndex = 203,
        Parent = content,
    })
    local info = Util.Label({
        Text = def.Content or "",
        TextSize = 12,
        TextWrapped = true,
        Position = UDim2.fromOffset(0, 26),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Color = "TextDim",
        Visible = def.Content ~= nil and def.Content ~= "",
        ZIndex = 203,
        Parent = content,
    })
    local inputBox = nil
    if def.Input then
        local holder = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, def.Input.Multiline and (def.Input.Height or 80) or 30),
            Position = UDim2.fromOffset(0, (def.Content and 26 + info.TextBounds.Y + 10 or 34)),
            Theme = { BackgroundColor3 = "Surface", BackgroundTransparency = 0.2 },
            ZIndex = 203,
            Parent = content,
        })
        Util.Corner("ElementRadius", holder)
        Util.Stroke(holder, "Stroke", function(t) return 0.6 end)
        inputBox = Util.New("TextBox", {
            Size = def.Input.Multiline and UDim2.new(1, -16, 0, def.Input.Height or 80) or UDim2.new(1, -16, 1, 0),
            Position = UDim2.fromOffset(8, def.Input.Multiline and 8 or 0),
            Text = def.Input.Default or "",
            PlaceholderText = def.Input.Placeholder or "",
            TextSize = 12,
            MultiLine = def.Input.Multiline == true,
            TextWrapped = def.Input.Multiline == true,
            TextYAlignment = def.Input.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
            Theme = { TextColor3 = "Text", PlaceholderColor3 = "TextMuted" },
            ZIndex = 204,
            Parent = holder,
        })
        task.defer(function()
            if inputBox.Parent then pcall(function() inputBox:CaptureFocus() end) end
        end)
    end
    local errorLabel = Util.Label({
        Text = "",
        TextSize = 11,
        Position = UDim2.fromOffset(0, (def.Content and 26 + info.TextBounds.Y + 10 or 34) + (def.Input and (def.Input.Height or 80) + (def.Input.Multiline and 12 or 36) or 0)),
        Size = UDim2.new(1, 0, 0, 14),
        Color = "Danger",
        Visible = false,
        ZIndex = 203,
        Parent = content,
    })

    local buttons = Util.New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.fromOffset(0, 12 + (y)),
        ZIndex = 203,
        Parent = card,
    })
    Util.List(buttons, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)

    local dialog = { IsOpen = true }

    local function close()
        if not dialog.IsOpen then return end
        dialog.IsOpen = false
        local speed = math.max(Animation.Speed, 1)
        Animation.Tween(overlay, "Fade", { BackgroundTransparency = 1 })
        Animation.Tween(scale, "Press", { Scale = 0.94 })
        task.delay((Animation.Curve.Press.Time / speed) + 0.02, function() overlay:Destroy() end)
    end
    dialog.Close = close

    function dialog:SetError(text)
        errorLabel.Text = text or ""
        errorLabel.Visible = text ~= nil and text ~= ""
    end

    local function pressStyle(style)
        if style == "Primary" then return "Accent", "OnAccent" end
        if style == "Danger" then return "Danger", "OnAccent" end
        if style == "Secondary" then return "ElevatedHover", "Text" end
        return "SurfaceHover", "TextDim"
    end

    for index, button in def.Buttons or { { Title = "OK", Style = "Primary" } } do
        local bg, fg = pressStyle(button.Style)
        local hover = { on = false }
        local element = Util.New("TextButton", {
            Text = "",
            Size = UDim2.fromOffset(0, 30),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = index,
            Theme = {
                BackgroundColor3 = bg,
                BackgroundTransparency = function()
                    if button.Style == "Primary" or button.Style == "Danger" then
                        return hover.on and 0 or 0.1
                    end
                    return hover.on and 0.2 or 0.45
                end,
            },
            ZIndex = 204,
            Parent = buttons,
        })
        Util.Corner("ElementRadius", element)
        Util.Padding(element, 0, 16, 0, 16)
        Util.Label({
            Text = button.Title or "OK",
            TextSize = 12,
            Weight = Enum.FontWeight.SemiBold,
            Size = UDim2.fromScale(0, 1),
            AutomaticSize = Enum.AutomaticSize.X,
            Color = fg,
            ZIndex = 204,
            Parent = element,
        })
        Util.Hover(element, function(on)
            hover.on = on
            Theme.Refresh(element, 0.12)
        end)
        Router.Attach(element, {
            OnClick = function()
                local value = inputBox and inputBox.Text or nil
                if button.Callback then
                    local ok, result = pcall(button.Callback, value, dialog)
                    if not ok then
                        warn("[UnWrittenUI] dialog: " .. tostring(result))
                    elseif result == false then
                        return
                    end
                end
                close()
            end,
        })
    end

    if inputBox then
        inputBox.FocusLost:Connect(function(enter)
            if enter then
                -- Enter presses the last button, the usual primary action
                local last = def.Buttons and def.Buttons[#def.Buttons]
                if last and last.Callback then
                    local ok, result = pcall(last.Callback, inputBox.Text, dialog)
                    if ok and result ~= false then close() end
                else
                    close()
                end
            end
        end)
    end
    local function escape(input, processed)
        if processed or not dialog.IsOpen then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            close()
        end
    end
    local connection = import("Core/Services").UserInputService.InputBegan:Connect(escape)
    dialog.Connection = connection
    -- destroy the key connection with the dialog
    overlay.Destroying:Connect(function() connection:Disconnect() end)
    overlay.AncestryChanged:Connect(function()
        if not overlay.Parent then connection:Disconnect() end
    end)
    return dialog
end

function Dialog.Show(window, def)
    return build(window, def or {})
end

return Dialog
