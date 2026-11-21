local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")
local Signal = import("Core/Signal")

-- toasts stacked in a corner; a toast with an Id that is still on screen is updated in place and
-- its timer restarts. Hovering pauses the timer, buttons can keep it open.
local Notification = {
    Position = "BottomRight",
    Scale = 1,
    Max = 5,
    Active = {},
    Changed = Signal.new(),
}

local TYPES = {
    Info = { Icon = "info", Token = "Info" },
    Success = { Icon = "circle-check", Token = "Success" },
    Warning = { Icon = "triangle-alert", Token = "Warning" },
    Error = { Icon = "circle-x", Token = "Danger" },
}

local holder

function Notification.Setup(window)
    Notification.Window = window
end

function Notification.SetPosition(position)
    Notification.Position = position or "BottomRight"
    Notification.Relayout()
end

local function layer()
    if holder and holder.Parent then
        holder.Parent = Layer.Toast
        return holder
    end
    local frame = Util.New("Frame", {
        Name = "Notifications",
        Size = UDim2.fromOffset(320, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = Layer.Toast,
    })
    local list = Util.List(frame, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() end)
    holder = frame
    Notification.List = list
    Notification.Relayout()
    return holder
end

function Notification.Relayout()
    if not holder then return end
    local position = Notification.Position or "BottomRight"
    local margin = 16
    local anchorX = (position:find("Left")) and 0 or 1
    local anchorY = (position:find("Top")) and 0 or 1
    holder.AnchorPoint = Vector2.new(anchorX, anchorY)
    holder.Position = UDim2.new(anchorX, anchorX == 1 and -margin or margin, anchorY, anchorY == 1 and -margin or margin)
    local list = holder:FindFirstChildOfClass("UIListLayout")
    if list then
        list.VerticalAlignment = anchorY == 1 and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
        list.HorizontalAlignment = anchorX == 1 and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
    end
end

local function closeItem(item)
    if not item or item.Closed then return end
    item.Closed = true
    if item.Timeout then pcall(task.cancel, item.Timeout) end
    local index = table.find(Notification.Active, item)
    if index then table.remove(Notification.Active, index) end
    local speed = math.max(Animation.Speed, 1)
    Animation.Tween(item.Frame, "Press", { Position = item.Frame.Position + UDim2.fromOffset(item.AnchorX == 1 and 24 or -24, 0) })
    for _, child in item.Frame:GetDescendants() do
        if child:IsA("GuiObject") then
            Animation.Tween(child, "Fade", { BackgroundTransparency = 1 })
        end
        if child:IsA("TextLabel") or child:IsA("ImageLabel") or child:IsA("TextBox") then
            Animation.Tween(child, "Fade", { TextTransparency = 1, ImageTransparency = 1 })
        end
    end
    task.delay((Animation.Curve.Press.Time / speed) + 0.02, function()
        if item.Frame then item.Frame:Destroy() end
        Notification.Changed:Fire()
    end)
end

-- options: Title, Content, Type (Info / Success / Warning / Error), Icon, Color, Duration,
--          Id, Buttons = { { Title, Style, Callback, KeepOpen } }
function Notification.Show(options)
    options = options or {}
    options.Title = options.Title or "Notification"
    options.Type = TYPES[options.Type] and options.Type or "Info"
    options.Duration = (tonumber(options.Duration) or 4) * (Notification.Scale or 1)
    local parent = layer()
    local anchorX = (Notification.Position:find("Left")) and 0 or 1

    -- the same Id while the old toast is alive updates it
    local existing
    if options.Id ~= nil then
        for _, item in Notification.Active do
            if item.Id == options.Id then existing = item break end
        end
    end

    local item
    if existing then
        item = existing
        item.Title.Text = options.Title
        item.Content.Text = options.Content or ""
        item.Content.Visible = options.Content ~= nil and options.Content ~= ""
        item.Accent.BackgroundColor3 = options.Color or Theme.Current[TYPES[options.Type].Token] or Theme.Current.Accent
        item.Icon.ImageColor3 = item.Accent.BackgroundColor3
        Animation.Flash(item.Frame, "BackgroundTransparency", 0.02, Theme.Current.ElevatedTransparency, "Fade")
    else
        local typeInfo = TYPES[options.Type]
        local frame = Util.New("Frame", {
            Name = "Notification",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ClipsDescendants = true,
            Theme = {
                BackgroundColor3 = "Elevated",
                BackgroundTransparency = function(t) return math.max(0, t.ElevatedTransparency - 0.05) end,
            },
            Parent = parent,
        })
        Util.Corner("Radius", frame)
        Util.Stroke(frame, "Stroke", function(t) return math.max(0, t.StrokeTransparency - 0.2) end)
        local accent = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = options.Color or Theme.Current[typeInfo.Token],
            Parent = frame,
        })
        local scale = Util.New("UIScale", { Scale = Notification.Scale or 1, Parent = frame })
        local inner = Util.New("Frame", {
            Size = UDim2.new(1, -20, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.fromOffset(14, 12),
            BackgroundTransparency = 1,
            Parent = frame,
        })
        local icon = Util.Icon(options.Icon or typeInfo.Icon, {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(0, 1),
            ImageColor3 = options.Color or Theme.Current[typeInfo.Token],
            Parent = inner,
        })
        local title = Util.Label({
            Text = options.Title,
            TextSize = 13,
            Weight = Enum.FontWeight.SemiBold,
            Position = UDim2.fromOffset(24, 0),
            Size = UDim2.new(1, -56, 0, 17),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = inner,
        })
        local content = Util.Label({
            Text = options.Content or "",
            TextSize = 11,
            TextWrapped = true,
            Position = UDim2.fromOffset(24, 18),
            Size = UDim2.new(1, -56, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Color = "TextDim",
            Visible = options.Content ~= nil and options.Content ~= "",
            Parent = inner,
        })
        local closeButton = Util.New("TextButton", {
            Size = UDim2.fromOffset(20, 20),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 8),
            Text = "",
            BackgroundTransparency = 1,
            Parent = frame,
        })
        Util.Icon("x", { Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Color = "TextMuted", Parent = closeButton })
        item = {
            Frame = frame,
            Title = title,
            Content = content,
            Accent = accent,
            Icon = icon,
            Inner = inner,
            Id = options.Id,
            AnchorX = anchorX,
            Closed = false,
        }
        Router.Attach(closeButton, { OnClick = function() closeItem(item) end })
        -- starting position: offset toward the screen edge, then slide in
        frame.Position = UDim2.fromOffset(anchorX == 1 and 40 or -40, 0)
        Animation.Tween(frame, "Slide", { Position = UDim2.fromOffset(0, 0) })
        if scale then
            scale.Scale = 0.9
            Animation.Tween(scale, "Pop", { Scale = Notification.Scale or 1 })
        end
        table.insert(Notification.Active, item)
        -- buttons
        local buttons = options.Buttons
        if buttons and #buttons > 0 then
            local row = Util.New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -24, 0, 26),
                Position = UDim2.fromOffset(24, content.AbsoluteSize.Y + 22),
                Parent = inner,
            })
            Util.List(row, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
            for index, button in buttons do
                local hover = { on = false }
                local element = Util.New("TextButton", {
                    Text = "",
                    Size = UDim2.fromOffset(0, 24),
                    AutomaticSize = Enum.AutomaticSize.X,
                    LayoutOrder = index,
                    Theme = {
                        BackgroundColor3 = button.Style == "Danger" and "Danger" or "ElevatedHover",
                        BackgroundTransparency = function() return hover.on and 0.1 or 0.4 end,
                    },
                    Parent = row,
                })
                Util.Corner(6, element)
                Util.Padding(element, 0, 10, 0, 10)
                Util.Label({
                    Text = button.Title or "OK",
                    TextSize = 11,
                    Weight = Enum.FontWeight.Medium,
                    Size = UDim2.fromScale(0, 1),
                    AutomaticSize = Enum.AutomaticSize.X,
                    Color = button.Style == "Danger" and "OnAccent" or "Text",
                    Parent = element,
                })
                Util.Hover(element, function(on) hover.on = on Theme.Refresh(element, 0.1) end)
                Router.Attach(element, {
                    OnClick = function()
                        if button.Callback then Util.Defer(button.Callback) end
                        if not button.KeepOpen then closeItem(item) end
                    end,
                })
            end
        end
    end

    -- timer with pause on hover
    local remaining = options.Duration
    if item.Timeout then pcall(task.cancel, item.Timeout) end
    local function startTimer()
        if remaining and remaining > 0 then
            item.Timeout = task.delay(remaining, function()
                if not item.Closed then closeItem(item) end
            end)
        end
    end
    item.Remaining = remaining
    startTimer()
    Util.Hover(item.Frame, function(on)
        if on then
            if item.Timeout then pcall(task.cancel, item.Timeout) end
            item.Timeout = nil
        else
            startTimer()
        end
    end)

    -- never show more than Max: drop the oldest
    while #Notification.Active > (Notification.Max or 5) do
        closeItem(Notification.Active[1])
    end

    -- the notification's own handle
    local handle = { Current = item }
    function handle:Close()
        closeItem(item)
    end
    function handle:Update(newOptions)
        newOptions = table.clone(newOptions or {})
        newOptions.Id = item.Id
        Notification.Show(newOptions)
    end
    Notification.Changed:Fire()
    return handle
end

return Notification
