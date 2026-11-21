local import = ...
local Services = import("Core/Services")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

-- one place for every pointer interaction: click, right click, double click, long press and dragging.
-- Works with mouse and touch, fires a click only when the pointer did not travel, and keeps a drag going
-- when the pointer leaves the element.
local Router = {
    Threshold = 5,       -- px a pointer may travel and still count as a click
    HoldTime = 0.5,      -- s a still press becomes a long press
    DoubleTime = 0.35,   -- s between two clicks that make a double click
    Capture = false,     -- a keybind is waiting for a key: pointer clicks do not activate the menu
    OpenPopups = {},     -- popups close when a press lands outside them
}

local UIS = Services.UserInputService

local POINTERS = {
    [Enum.UserInputType.MouseButton1] = true,
    [Enum.UserInputType.Touch] = true,
}
local RIGHT = {
    [Enum.UserInputType.MouseButton2] = true,
}
local MIDDLE = {
    [Enum.UserInputType.MouseButton3] = true,
}

-- closes the newest open popup when the click is outside all of them
local function closePopups(point)
    if #Router.OpenPopups == 0 then return end
    for index = #Router.OpenPopups, 1, -1 do
        local popup = Router.OpenPopups[index]
        if popup and popup.IsOpen and popup:IsOpen() then
            if not popup:ContainsPoint(point) then
                popup:Close()
                return
            end
            return
        end
        table.remove(Router.OpenPopups, index)
    end
end

function Router.RegisterPopup(popup)
    table.insert(Router.OpenPopups, popup)
end

function Router.UnregisterPopup(popup)
    local index = table.find(Router.OpenPopups, popup)
    if index then table.remove(Router.OpenPopups, index) end
end

-- a click landed anywhere on screen at point (used for popups and the keybind capture cancel)
function Router.Clicked(point)
    closePopups(point)
    import("Core/Keybinds").Clicked()
end

local function absolutePoint(gui)
    local position = gui.AbsolutePosition
    local size = gui.AbsoluteSize
    return Vector2.new(position.X + size.X / 2, position.Y + size.Y / 2)
end

-- opts: OnClick, OnRightClick, OnMiddleClick, OnPress, OnRelease, OnDoubleClick,
--       OnDrag(delta, total), OnDragStart, OnDragEnd, Disabled, Tooltip, Cursor, Hold = { Time, Callback }
function Router.Attach(gui, opts)
    opts = opts or {}
    local handle = { Enabled = true, Pressed = false, Destroyed = false }
    local pressedInput, startPos, lastPos, moved, held, holdThread = nil, nil, nil, false, false, nil
    local lastClick, lastClickPos = -10, nil

    local function disabled()
        if not handle.Enabled or Router.Capture then return true end
        local check = opts.Disabled
        if type(check) == "function" then
            local ok, result = pcall(check)
            return ok and result == true
        end
        return check == true
    end

    local function cancelHold()
        if holdThread then
            pcall(task.cancel, holdThread)
            holdThread = nil
        end
    end

    local function begin(input)
        if disabled() then return end
        local isLeft, isRight, isMiddle = POINTERS[input.UserInputType], RIGHT[input.UserInputType], MIDDLE[input.UserInputType]
        if not (isLeft or isRight or isMiddle) then return end
        if isRight then
            if opts.OnRightClick then
                opts.OnRightClick(Vector2.new(input.Position.X, input.Position.Y))
                Router.Clicked(Vector2.new(input.Position.X, input.Position.Y))
            end
            return
        end
        if isMiddle then
            if opts.OnMiddleClick then opts.OnMiddleClick(Vector2.new(input.Position.X, input.Position.Y)) end
            return
        end
        if not isLeft then return end
        pressedInput = input.UserInputType
        startPos = Vector2.new(input.Position.X, input.Position.Y)
        lastPos = startPos
        moved = false
        held = false
        handle.Pressed = true
        if opts.OnPress then opts.OnPress(input, startPos) end
        if opts.Hold then
            local holdTime = (opts.Hold.Time or Router.HoldTime)
            holdThread = task.delay(holdTime, function()
                holdThread = nil
                if not handle.Pressed or moved or handle.Destroyed then return end
                held = true
                if opts.Hold.Callback then opts.Hold.Callback(absolutePoint(gui)) end
            end)
        end
    end

    local function track(input)
        if not handle.Pressed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if not moved then
            local delta = point - startPos
            if delta.Magnitude < Router.Threshold then
                lastPos = point
                return
            end
            moved = true
            cancelHold()
            if opts.OnDragStart then pcall(opts.OnDragStart, startPos) end
        end
        if opts.OnDrag then
            local delta = point - lastPos
            lastPos = point
            local ok, err = pcall(opts.OnDrag, delta, point, startPos)
            if not ok then warn("[UnWrittenUI] drag: " .. tostring(err)) end
        else
            lastPos = point
        end
    end

    local function finish(input)
        if not handle.Pressed then return end
        if input.UserInputType ~= pressedInput then return end
        handle.Pressed = false
        cancelHold()
        pressedInput = nil
        if moved then
            if opts.OnDragEnd then pcall(opts.OnDragEnd, lastPos) end
            if opts.OnRelease then opts.OnRelease() end
            return
        end
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if held then
            held = false
            if opts.OnRelease then opts.OnRelease() end
            return
        end
        if opts.OnClick then
            local now = os.clock()
            local isDouble = opts.OnDoubleClick and lastClickPos and (now - lastClick) <= Router.DoubleTime
                and (point - lastClickPos).Magnitude <= 12
            lastClick, lastClickPos = now, point
            if isDouble then
                lastClick = -10
                local ok, err = pcall(opts.OnDoubleClick, point)
                if not ok then warn("[UnWrittenUI] double click: " .. tostring(err)) end
            else
                local ok, err = pcall(opts.OnClick, point, input)
                if not ok then warn("[UnWrittenUI] click: " .. tostring(err)) end
            end
        end
        Router.Clicked(point)
        if opts.OnRelease then opts.OnRelease() end
    end

    local beganConnection = gui.InputBegan:Connect(begin)
    local endedConnection = gui.InputEnded:Connect(finish)
    -- pointer may leave the element mid-drag: listen globally while a press is live
    local globalChanged = UIS.InputChanged:Connect(function(input)
        if handle.Pressed then track(input) end
    end)
    local globalEnded = UIS.InputEnded:Connect(function(input)
        if handle.Pressed then finish(input) end
    end)

    local hoverLeave
    if opts.Tooltip then
        local Tooltip = import("Components/Tooltip")
        local connection
        local enter = gui.MouseEnter:Connect(function()
            if disabled() then return end
            connection = Tooltip.Attach(gui, opts.Tooltip)
        end)
        hoverLeave = { enter, leave = gui.MouseLeave:Connect(function()
            if connection then connection:Disconnect() connection = nil end
            Tooltip.HideFor(gui)
        end) }
    end

    if opts.Cursor and gui:IsA("GuiObject") then
        gui.MouseEnter:Connect(function()
            if not disabled() then
                gui.MouseIcon = opts.Cursor
            end
        end)
    end

    function handle:SetEnabled(enabled)
        self.Enabled = enabled and true or false
        if not self.Enabled then handle.Pressed = false cancelHold() end
    end

    function handle:IsPressed()
        return handle.Pressed
    end

    function handle:Destroy()
        handle.Destroyed = true
        handle.Pressed = false
        cancelHold()
        beganConnection:Disconnect()
        endedConnection:Disconnect()
        globalChanged:Disconnect()
        globalEnded:Disconnect()
        if hoverLeave then
            hoverLeave.enter:Disconnect()
            hoverLeave.leave:Disconnect()
        end
    end

    return handle
end

-- press visual: dims the background of a button while the pointer is down
function Router.Feedback(gui, baseToken, pressedToken)
    local down = false
    local handle = Router.Attach(gui, {
        OnPress = function()
            down = true
            Util.Tween(gui, 0.08, { BackgroundTransparency = pressedToken or 0.15 })
        end,
        OnRelease = function()
            down = false
            local Theme = import("Core/Theme")
            local token = baseToken or "ElevatedTransparency"
            Util.Tween(gui, 0.18, { BackgroundTransparency = Theme.Current[token] or 0.1 })
        end,
    })
    return handle
end

return Router
