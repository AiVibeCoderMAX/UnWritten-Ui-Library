local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")

-- a small label that follows the pointer (mouse) or sits above the element (touch / gamepad)
local Tooltip = {
    Enabled = true,
    Delay = 0.35,
    MaxWidth = 240,
}

local current = nil

local function surface()
    if current and current.Frame and current.Frame.Parent then return current end
    local frame = Util.New("Frame", {
        Name = "Tooltip",
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Visible = false,
        ZIndex = 120,
        Theme = { BackgroundColor3 = "BackgroundAlt", BackgroundTransparency = 0.02 },
        Parent = Layer.Overlay,
    })
    Util.Corner(6, frame)
    Util.Stroke(frame, function(t) return t.Accent end, function() return 0.55 end)
    local padding = Util.Padding(frame, 6, 9, 6, 9)
    local label = Util.Label({
        Text = "",
        TextSize = 12,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        TextWrapped = false,
        Parent = frame,
    })
    Util.New("UIScale", { Scale = 1, Parent = frame })
    current = { Frame = frame, Label = label, Padding = padding }
    return current
end

local function place(frame, point, anchor)
    local size = frame.AbsoluteSize
    local position
    if anchor then
        position = Vector2.new(anchor.AbsolutePosition.X + anchor.AbsoluteSize.X / 2 - size.X / 2, anchor.AbsolutePosition.Y - size.Y - 8)
        if position.Y < 4 then
            position = Vector2.new(anchor.AbsolutePosition.X + anchor.AbsoluteSize.X / 2 - size.X / 2, anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 8)
        end
    else
        position = point + Vector2.new(14, 18)
    end
    position = Layer.Clamp(position, size, 4)
    frame.Position = UDim2.fromOffset(position.X, position.Y)
end

local moveConnection
local lastPointer = Vector2.new(0, 0)

local function ensurePointerTracking()
    if moveConnection then return end
    moveConnection = Services.UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        lastPointer = Vector2.new(input.Position.X, input.Position.Y)
        if current and current.Frame.Visible and not current.Anchor then
            place(current.Frame, lastPointer)
        end
    end)
end

-- shows the tooltip for gui after a short delay; returns a connection that hides it
function Tooltip.Attach(gui, text, options)
    if not Tooltip.Enabled or text == nil or text == "" then return nil end
    options = options or {}
    ensurePointerTracking()
    local connection = { Connected = true }
    local pending = nil
    local hide
    local show = function()
        local context = surface()
        context.Label.Text = text
        context.Label.TextWrapped = true
        context.Label.TextXAlignment = Enum.TextXAlignment.Left
        context.Label.Size = UDim2.fromOffset(Tooltip.MaxWidth, 0)
        context.Label.AutomaticSize = Enum.AutomaticSize.Y
        context.Frame.Visible = true
        context.Anchor = options.Anchor and gui
        task.defer(function()
            if not context.Frame.Visible then return end
            if context.Anchor then
                context.Label.Size = UDim2.fromOffset(0, 0)
            else
                context.Label.Size = UDim2.fromOffset(math.min(Tooltip.MaxWidth, math.max(60, #text * 6.6)), 0)
            end
            place(context.Frame, lastPointer, context.Anchor)
            local scale = context.Frame:FindFirstChildOfClass("UIScale")
            if scale then
                scale.Scale = 0.94
                Animation.Tween(scale, "Fade", { Scale = 1 })
            end
        end)
    end
    local function cancel()
        if pending then
            pcall(task.cancel, pending)
            pending = nil
        end
        hide()
    end
    hide = function()
        if current then current.Frame.Visible = false end
    end
    local enter = gui.MouseEnter:Connect(function()
        if not Tooltip.Enabled then return end
        if pending then pcall(task.cancel, pending) end
        pending = task.delay(Tooltip.Delay, show)
    end)
    local leave = gui.MouseLeave:Connect(cancel)
    local endTouch = gui.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then cancel() end
    end)
    -- gamepad selection also shows it
    local selected = gui.SelectionGained and gui.SelectionGained:Connect(show)
    function connection:Disconnect()
        if not connection.Connected then return end
        connection.Connected = false
        if pending then pcall(task.cancel, pending) end
        enter:Disconnect()
        leave:Disconnect()
        endTouch:Disconnect()
        if selected then selected:Disconnect() end
        hide()
    end
    return connection
end

function Tooltip.HideFor(gui)
    if current then current.Frame.Visible = false end
end

return Tooltip
