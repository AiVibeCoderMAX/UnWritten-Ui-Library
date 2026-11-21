local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Animation = import("Core/Animation")
local Router = import("Core/Router")

-- small controls reused by elements: switch, checkbox, key pill, radio dot
local Widgets = {}

-- iOS style switch, animated via TweenService on offsets
function Widgets.Switch(parent, opts)
    opts = opts or {}
    local width, height = 34, 18
    local switch = { On = false, Enabled = true }

    local track = Util.New("Frame", {
        Name = "Switch",
        Size = UDim2.fromOffset(width, height),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = {
            BackgroundColor3 = function(t)
                if switch.On then return t.Accent end
                return t.ElevatedHover
            end,
            BackgroundTransparency = function(t)
                if switch.On then return 0.05 end
                return math.max(0.1, t.ElevatedTransparency)
            end,
        },
        Parent = parent,
    })
    Util.Corner(height / 2, track)
    Util.Stroke(track, function(t) return switch.On and t.Accent or t.Stroke end, function(t)
        return switch.On and 0.3 or math.max(0, t.StrokeTransparency - 0.15)
    end)
    local knob = Util.New("Frame", {
        Size = UDim2.fromOffset(height - 6, height - 6),
        Position = UDim2.fromOffset(3, 3),
        Theme = { BackgroundColor3 = function(t) return switch.On and t.OnAccent or t.TextDim end },
        Parent = track,
    })
    Util.Corner((height - 6) / 2, knob)

    local function paint(on, animate)
        switch.On = on
        if not switch.Enabled then return end
        local goal = {
            Position = UDim2.fromOffset(on and (width - height + 3) or 3, 3),
            BackgroundColor3 = on and Theme.Current.OnAccent or Theme.Current.TextDim,
        }
        if animate and Animation.Speed > 0 then
            Animation.Tween(knob, "Toggle", goal)
            Animation.Tween(track, "Toggle", { BackgroundColor3 = on and Theme.Current.Accent or Theme.Current.ElevatedHover })
        else
            for key, value in goal do knob[key] = value end
            track.BackgroundColor3 = on and Theme.Current.Accent or Theme.Current.ElevatedHover
        end
        Theme.Refresh(track, 0)
        Theme.Refresh(knob, 0)
    end

    -- hover: a faint lift of the track
    Util.Hover(track, function(hovering)
        if not switch.Enabled then return end
        if Animation.Speed <= 0 then return end
        Animation.Tween(track, "Hover", {
            BackgroundTransparency = switch.On and (hovering and 0 or 0.05) or (hovering and 0.55 or 0.75),
        })
    end)

    function switch:Set(on, animate)
        paint(on and true or false, animate ~= false)
    end

    function switch:Get()
        return switch.On
    end

    function switch:SetEnabled(enabled)
        switch.Enabled = enabled and true or false
        if not switch.Enabled then
            Animation.Tween(track, "Fade", { BackgroundColor3 = Theme.Current.Elevated, BackgroundTransparency = 0.55 })
            Animation.Tween(knob, "Fade", { BackgroundColor3 = Theme.Current.TextMuted, BackgroundTransparency = 0.45 })
        else
            knob.BackgroundTransparency = 0
            local goal = {
                Position = UDim2.fromOffset(switch.On and (width - height + 3) or 3, 3),
                BackgroundColor3 = switch.On and Theme.Current.OnAccent or Theme.Current.TextDim,
            }
            Animation.Tween(knob, "Toggle", goal)
            Animation.Tween(track, "Toggle", { BackgroundColor3 = switch.On and Theme.Current.Accent or Theme.Current.ElevatedHover })
            track.BackgroundTransparency = switch.On and 0.05 or math.max(0.1, Theme.Current.ElevatedTransparency)
            -- rebind the theme map so later refreshes keep the right transparency
            Theme.Bind(track, {
                BackgroundTransparency = function(t)
                    if switch.On then return 0.05 end
                    return math.max(0.1, t.ElevatedTransparency)
                end,
            })
        end
    end

    switch.Track = track
    switch.Knob = knob
    return switch
end

-- square checkbox with a check icon
function Widgets.Checkbox(parent, opts)
    opts = opts or {}
    local checkbox = { On = false, Enabled = true }
    local box = Util.New("Frame", {
        Name = "Checkbox",
        Size = UDim2.fromOffset(18, 18),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = {
            BackgroundColor3 = function(t)
                return checkbox.On and t.Accent or t.Elevated
            end,
            BackgroundTransparency = function(t)
                return checkbox.On and 0.05 or math.max(0.1, t.ElevatedTransparency)
            end,
        },
        Parent = parent,
    })
    Util.Corner(5, box)
    local stroke = Util.Stroke(box, function(t) return checkbox.On and t.Accent or t.Stroke end, function(t)
        return checkbox.On and 0.2 or math.max(0, t.StrokeTransparency - 0.15)
    end)
    local tick = Util.Icon("check", {
        Size = UDim2.fromOffset(13, 13),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Theme = { ImageColor3 = function(t) return t.OnAccent end },
        ImageTransparency = 1,
        Parent = box,
    })
    Util.New("UIScale", { Scale = 0.6, Parent = tick })

    local function paint(on, animate)
        checkbox.On = on
        local scale = tick:FindFirstChildOfClass("UIScale")
        if animate then
            Animation.Tween(tick, "Fade", { ImageTransparency = on and 0 or 1 })
            if scale then Animation.Tween(scale, "Pop", { Scale = on and 1 or 0.6 }) end
            Theme.Refresh(box, 0.18)
            Theme.Refresh(stroke, 0.18)
        else
            tick.ImageTransparency = on and 0 or 1
            if scale then scale.Scale = on and 1 or 0.6 end
            Theme.Refresh(box, 0)
            Theme.Refresh(stroke, 0)
        end
    end

    function checkbox:Set(on, animate)
        paint(on and true or false, animate ~= false)
    end

    function checkbox:Get()
        return checkbox.On
    end

    checkbox.Box = box
    checkbox.Tick = tick
    return checkbox
end

-- key pill shown on cards and toggle rows. click captures, right click opens the mode menu.
function Widgets.KeyPill(parent, window, binding, opts)
    opts = opts or {}
    local pill = { Hover = false }
    local button = Util.New("TextButton", {
        Name = "KeyPill",
        Size = UDim2.fromOffset(0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "",
        Theme = {
            BackgroundColor3 = "ElevatedHover",
            BackgroundTransparency = function()
                if binding and binding.Capturing then return 0 end
                return pill.Hover and 0.4 or 0.7
            end,
        },
        Parent = parent,
    })
    Util.Corner(5, button)
    Util.Padding(button, 0, 7, 0, 7)
    local stroke = Util.Stroke(button, function(t)
        return binding and (binding.Capturing and t.Accent or t.Stroke) or t.Stroke
    end, function(t) return binding and binding.Capturing and 0.1 or 0.7 end)
    local label = Util.Label({
        Text = "",
        TextSize = 11,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        Theme = {
            TextColor3 = function(t)
                if binding and binding.Capturing then return t.Accent end
                return binding and binding.Key and t.Text or t.TextMuted
            end,
        },
        Parent = button,
    })
    -- a key picked mode is shown as a dot colour: hold = warning, always = success
    local modeDot = Util.New("Frame", {
        Name = "Mode",
        Size = UDim2.fromOffset(5, 5),
        Position = UDim2.fromOffset(-4, 8),
        Visible = false,
        Theme = {
            BackgroundColor3 = function(t)
                if not binding then return t.TextMuted end
                if binding.Mode == "Always" then return t.Success end
                if binding.Mode == "Hold" then return t.Warning end
                return t.Accent
            end,
        },
        Parent = button,
    })
    Util.Corner(3, modeDot)

    local function refresh()
        if not binding then
            button.Visible = false
            return
        end
        button.Visible = opts.Visible ~= false
        if binding.Capturing then
            label.Text = "…"
        elseif binding.Key then
            label.Text = Util.KeyLabel(binding.Key)
        else
            label.Text = "Bind"
        end
        modeDot.Visible = binding.Mode ~= "Toggle" and binding.Mode ~= "Hold" or (binding.Mode == "Hold")
        modeDot.Position = UDim2.fromOffset(-(label.AbsoluteSize.X) + (binding.Mode == "Hold" and 4 or 0), 8)
        Theme.Refresh(label, 0.1)
        Theme.Refresh(button, 0.1)
        Theme.Refresh(stroke, 0.1)
    end

    if binding then
        binding.Changed:Connect(refresh)
        pill._connections = {}
        table.insert(pill._connections, binding.Changed)
    end
    refresh()

    Util.Hover(button, function(hovering)
        pill.Hover = hovering
        Theme.Refresh(button, 0.12)
    end)

    Router.Attach(button, {
        OnClick = function()
            if binding then binding:Capture() end
        end,
        OnRightClick = function(point)
            if not binding then return end
            local window = window
            local modes = binding.Modes or { "Toggle", "Hold", "Always" }
            local items = {}
            for _, mode in modes do
                table.insert(items, {
                    Title = mode,
                    Checked = binding.Mode == mode,
                    Callback = function() binding:SetMode(mode) end,
                })
            end
            if binding.Key then
                table.insert(items, "-")
                table.insert(items, { Title = "Clear key", Icon = "eraser", Callback = function() binding:SetKey(nil) end })
            end
            local Popup = import("Components/Popup")
            Popup.Menu(items, { Point = point, Width = 130 }):Show()
        end,
        Tooltip = opts.Tooltip,
    })

    function pill:Destroy()
        button:Destroy()
    end

    pill.Button = button
    pill.Label = label
    pill.Refresh = refresh
    return pill
end

-- radio dot used by segmented controls
function Widgets.Dot(parent)
    local dot = Util.New("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Theme = { BackgroundColor3 = "Accent" },
        Parent = parent,
    })
    Util.Corner(3, dot)
    return dot
end

-- a one pixel line
function Widgets.Divider(parent, height)
    return Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, height or 1),
        Theme = { BackgroundColor3 = "Divider", BackgroundTransparency = 0.3 },
        Parent = parent,
    })
end

return Widgets
