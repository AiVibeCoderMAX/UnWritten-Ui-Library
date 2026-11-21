local import = ...
local Services = import("Core/Services")
local Theme = import("Core/Theme")
local Icons = import("Core/Icons")

local Util = {}

local DEFAULTS = {
    Frame = { BorderSizePixel = 0 },
    ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y },
    TextLabel = { BorderSizePixel = 0, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left },
    TextButton = { BorderSizePixel = 0, AutoButtonColor = false, Text = "" },
    TextBox = { BorderSizePixel = 0, BackgroundTransparency = 1, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left },
    ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
    ImageButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false },
}

-- props.Theme binds properties to tokens; props.Parent is set last
function Util.New(class, props, children)
    local inst = Instance.new(class)
    local defaults = DEFAULTS[class]
    if defaults then
        for key, v in defaults do inst[key] = v end
    end
    local theme, parent
    if props then
        for key, v in props do
            if key == "Theme" then
                theme = v
            elseif key == "Parent" then
                parent = v
            else
                inst[key] = v
            end
        end
    end
    if children then
        for _, child in children do child.Parent = inst end
    end
    if theme then Theme.Bind(inst, theme) end
    if parent then inst.Parent = parent end
    return inst
end

function Util.Tween(inst, time, goal, style, direction)
    local speed = Theme.Current.AnimSpeed or 1
    if speed <= 0 or not inst or not inst.Parent then
        if inst then
            for key, v in goal do pcall(function() inst[key] = v end) end
        end
        return nil
    end
    local tween = Services.TweenService:Create(inst, TweenInfo.new(time / speed, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal)
    tween:Play()
    return tween
end

-- radius: number or token name holding a number
function Util.Corner(radius, parent)
    local corner = Util.New("UICorner", { Parent = parent })
    if type(radius) == "string" then
        Theme.Bind(corner, { CornerRadius = function(t) return UDim.new(0, t[radius] or 6) end })
    elseif typeof(radius) == "UDim" then
        corner.CornerRadius = radius
    elseif type(radius) == "number" then
        corner.CornerRadius = UDim.new(0, radius)
    end
    return corner
end

function Util.Stroke(parent, colorToken, transparencyToken, thickness)
    return Util.New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Thickness = thickness or 1,
        Theme = {
            Color = colorToken or "Stroke",
            Transparency = transparencyToken or "StrokeTransparency",
        },
        Parent = parent,
    })
end

function Util.Gradient(parent, colorA, colorB, rotation)
    return Util.New("UIGradient", {
        Theme = {
            Rotation = rotation or "GradientRotation",
            Color = function(t)
                return ColorSequence.new({ ColorSequenceKeypoint.new(0, t[colorA or "Accent"]), ColorSequenceKeypoint.new(1, t[colorB or "AccentAlt"]) })
            end,
        },
        Parent = parent,
    })
end

function Util.Padding(parent, top, right, bottom, left)
    return Util.New("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        PaddingLeft = UDim.new(0, left or right or top or 0),
        Parent = parent,
    })
end

function Util.List(parent, padding, direction, horizontal, vertical)
    return Util.New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        FillDirection = direction or Enum.FillDirection.Vertical,
        HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
        VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

-- themed text; Color/Weight/Size are shortcuts
function Util.Label(props)
    local color = props.Color or "Text"
    local weight = props.Weight or Enum.FontWeight.Regular
    props.Color, props.Weight = nil, nil
    props.TextSize = props.TextSize or 13
    local theme = props.Theme or {}
    theme.TextColor3 = theme.TextColor3 or color
    theme.FontFace = theme.FontFace or Theme.Font(weight)
    props.Theme = theme
    return Util.New("TextLabel", props)
end

Util.Icons = Icons

function Util.IconId(icon)
    if icon == nil or icon == "" then return nil end
    if type(icon) == "number" then return "rbxassetid://" .. icon end
    if icon:find("^%a[%w+.-]*://") then return icon end
    if icon:match("^%d+$") then return "rbxassetid://" .. icon end
    local found = Icons[icon] or Icons[icon:lower():gsub("_", "-")]
    if not found then
        found = Util.ExtraIcons and Util.ExtraIcons[icon]
    end
    return found or Icons["circle"]
end

Util.ExtraIcons = {}

function Util.AddIcons(map)
    for name, id in map do
        Util.ExtraIcons[name] = Util.IconId(id) or id
    end
end

function Util.Icon(icon, props)
    props = props or {}
    local color = props.Color or "TextDim"
    props.Color = nil
    props.Image = Util.IconId(icon) or ""
    props.ScaleType = props.ScaleType or Enum.ScaleType.Fit
    local theme = props.Theme or {}
    theme.ImageColor3 = theme.ImageColor3 or color
    props.Theme = theme
    return Util.New("ImageLabel", props)
end

-- product of every UIScale above gui (absolute sizes are scaled, offsets are not)
function Util.ScaleOf(gui)
    local scale = 1
    local node = gui
    while node and not node:IsA("LayerCollector") do
        local uiScale = node:FindFirstChildOfClass("UIScale")
        if uiScale then scale *= uiScale.Scale end
        node = node.Parent
    end
    return scale
end

-- sizes a ScrollingFrame's canvas from its list layout; AutomaticCanvasSize misreads UIScale and
-- frames that were filled while hidden
function Util.AutoCanvas(frame, layout, horizontal)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.None
    local padding = frame:FindFirstChildOfClass("UIPadding")
    local function update()
        if not frame.Parent then return end
        local scale = Util.ScaleOf(frame)
        local content = layout.AbsoluteContentSize / math.max(scale, 0.01)
        if horizontal then
            local extra = padding and (padding.PaddingLeft.Offset + padding.PaddingRight.Offset) or 0
            frame.CanvasSize = UDim2.fromOffset(math.ceil(content.X + extra), 0)
        else
            local extra = padding and (padding.PaddingTop.Offset + padding.PaddingBottom.Offset) or 0
            frame.CanvasSize = UDim2.fromOffset(0, math.ceil(content.Y + extra))
        end
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
    update()
    return update
end

function Util.Touch()
    local UIS = Services.UserInputService
    if UIS.TouchEnabled and not UIS.MouseEnabled then return true end
    return UIS:GetLastInputType() == Enum.UserInputType.Touch
end

-- fn(hovering) on enter and leave; a lifted touch counts as leaving, MouseLeave often never fires on touch
function Util.Hover(gui, fn)
    local hovering = false
    local function set(on)
        if hovering == on then return end
        hovering = on
        fn(on)
    end
    local enter = gui.MouseEnter:Connect(function() set(true) end)
    local leave = gui.MouseLeave:Connect(function() set(false) end)
    local lift = gui.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then set(false) end
    end)
    return {
        Disconnect = function()
            enter:Disconnect()
            leave:Disconnect()
            lift:Disconnect()
        end,
    }
end

-- touch only: holding still on gui for `time` s calls fn(point); returns the connection and consumed(),
-- which a click handler calls to skip the click that ends a long press
function Util.LongPress(gui, fn, time)
    time = time or 0.45
    local pressed, startX, startY, pressedAt = false, 0, 0, 0
    local consumed = false
    local begin = gui.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        pressed, consumed = true, false
        startX, startY, pressedAt = input.Position.X, input.Position.Y, os.clock()
    end)
    local changed = gui.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch or not pressed then return end
        local dx, dy = input.Position.X - startX, input.Position.Y - startY
        if dx * dx + dy * dy > 64 then pressed = false end
    end)
    local ended = gui.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        local held = os.clock() - pressedAt
        if pressed and held >= time then
            consumed = true
            fn(Vector2.new(input.Position.X, input.Position.Y))
        end
        pressed = false
    end)
    return {
        Disconnect = function()
            begin:Disconnect()
            changed:Disconnect()
            ended:Disconnect()
        end,
    }, function()
        if consumed then
            consumed = false
            return true
        end
        return false
    end
end

-- calls fn(value) with a safe wrapper; errors land in the output as the script's own
function Util.Safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[UnWrittenUI] callback: " .. tostring(err)) end
end

-- runs fn in its own thread when the callback yields, and inline otherwise: game code inside a
-- callback can yield or change the thread's identity without breaking the menu
function Util.Defer(fn, ...)
    if type(fn) ~= "function" then return end
    if not coroutine.isyieldable() then
        local ok, err = pcall(fn, ...)
        if not ok then warn("[UnWrittenUI] callback: " .. tostring(err)) end
        return
    end
    task.defer(fn, ...)
end

function Util.Round(value, step)
    if not step or step <= 0 then return value end
    return math.floor(value / step + 0.5) * step
end

-- fixes float noise from dividing by a step (0.1 results in 0.30000000000000004)
function Util.Clean(value, step)
    if not step or step <= 0 then return value end
    local decimals = math.max(0, -math.floor((math.log(step, 10) or 0) + 0.5))
    local mult = 10 ^ math.min(decimals, 6)
    return math.floor(value * mult + 0.5) / mult
end

function Util.FormatNumber(value, decimals)
    if decimals then
        return string.format("%." .. decimals .. "f", value)
    end
    return tostring(value)
end

function Util.KeyLabel(key)
    if not key or key == "" then return "" end
    key = tostring(key)
    local names = {
        LeftControl = "LCtrl", RightControl = "RCtrl", LeftShift = "LShift", RightShift = "RShift",
        LeftAlt = "LAlt", RightAlt = "RAlt", MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
        Backspace = "Bksp", Return = "Enter", Escape = "Esc", CapsLock = "Caps", ButtonX = "⑂",
    }
    local parts = {}
    for part in key:gmatch("[^+]+") do
        table.insert(parts, names[part] or part)
    end
    return table.concat(parts, " + ")
end

function Util.IsModifier(key)
    return key == "LeftShift" or key == "RightShift" or key == "LeftControl" or key == "RightControl"
        or key == "LeftAlt" or key == "RightAlt"
end

-- "LeftControl+L" -> {"LeftControl", "L"}
function Util.SplitCombo(key)
    local out = {}
    if not key then return out end
    for part in tostring(key):gmatch("[^+]+") do table.insert(out, part) end
    return out
end

-- one key code for a string, a number or an Enum
function Util.KeyCode(key)
    if key == nil then return nil end
    if typeof(key) == "EnumItem" then return key end
    if type(key) == "number" then return Enum.KeyCode[key] end
    if type(key) == "string" then
        local direct = Enum.KeyCode[key]
        if direct then return direct end
        for _, item in Enum.KeyCode:GetEnumItems() do
            if item.Name:lower() == key:lower() then return item end
        end
    end
    return nil
end

-- crops the thumbnail address of a user id; executors can draw it without a network call
function Util.Avatar(userId)
    if type(userId) ~= "number" then return nil end
    return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(userId)
end

return Util
