-- Headless Roblox stand-in used to smoke-test UnWrittenUI outside the game.
-- A small virtual DOM: children, properties, events and a real layout pass for list layouts,
-- paddings, automatic sizes and scrolling canvases, so the library can run end to end.
-- Not shipped; lives in build/.
local M = { errors = {}, warnings = {} }

-- value types ---------------------------------------------------------------
local V2 = {}
V2.__index = V2
function V2.new(x, y)
    return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__add = function(a, b) return V2.new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return V2.new(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
    if type(b) == "number" then return V2.new(a.X * b, a.Y * b) end
    if type(a) == "number" then return V2.new(b.X * a, b.Y * a) end
    return V2.new(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
    if type(b) == "number" then return V2.new(a.X / b, a.Y / b) end
    return V2.new(a.X / b.X, a.Y / b.Y)
end
V2.__tostring = function(a) return string.format("%.2f, %.2f", a.X, a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
function V2.Magnitude(self) return math.sqrt(self.X * self.X + self.Y * self.Y) end

local Vector2 = setmetatable({
    new = V2.new,
    zero = V2.new(0, 0),
    one = V2.new(1, 1),
}, {})

local UDim = {}
UDim.__index = UDim
UDim.new = function(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDim) end
UDim.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end

local UDim2 = {}
UDim2.__index = UDim2
function UDim2.new(xs, xo, ys, yo)
    return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2)
end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
UDim2.__tostring = function(a) return "UDim2" end
UDim2.__add = function(a, b)
    return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim2.__sub = function(a, b)
    return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UDim.__tostring = function(a) return "UDim" end
UDim.__add = function(a, b) return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset) end
UDim.__sub = function(a, b) return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset) end

local Color3 = {}
Color3.__index = {}
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3) end
Color3.__index.ToHex = function(self)
    return string.format("%02x%02x%02x", math.round(self.R * 255), math.round(self.G * 255), math.round(self.B * 255))
end
Color3.__index.Lerp = function(self) return self end
Color3.__index.ToHSV = function(self)
    local max, min = math.max(self.R, self.G, self.B), math.min(self.R, self.G, self.B)
    local delta = max - min
    local h = 0
    if delta > 0 then
        if max == self.R then h = ((self.G - self.B) / delta) % 6
        elseif max == self.G then h = (self.B - self.R) / delta + 2
        else h = (self.R - self.G) / delta + 4 end
        h = h / 6
    end
    return h, (max > 0 and delta / max or 0), max
end
Color3.__tostring = function(self) return string.format("%.3f, %.3f, %.3f", self.R, self.G, self.B) end
local function rgb(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
Color3.fromRGB = function(r, g, b) return rgb(r, g, b) end
Color3.fromHSV = function(h, s, v)
    h = h or 0
    return rgb(math.floor(h * 255), math.floor((s or 0) * 255), math.floor((v or 0) * 255))
end
Color3.fromHex = function()
    return rgb(128, 128, 128)
end

-- typeof ---------------------------------------------------------------------
local ROOT = getfenv(0)
local baseTypeof = ROOT.typeof or type
local function typeof(value)
    if type(value) == "table" then
        local meta = getmetatable(value)
        if meta == V2 then return "Vector2" end
        if meta == UDim2 then return "UDim2" end
        if meta == UDim then return "UDim" end
        if meta == Color3 then return "Color3" end
        if rawget(value, "__instance") then return "Instance" end
        if meta and rawget(meta, "__enum") then return "EnumItem" end
    end
    return baseTypeof(value)
end

-- enums ---------------------------------------------------------------------
local EnumItemMeta = { __enum = true }
EnumItemMeta.__tostring = function(self) return "Enum." .. self.EnumType .. "." .. self.Name end
local function enumItem(kind, name, value)
    return setmetatable({ Name = name, Value = value or 0, EnumType = kind }, EnumItemMeta)
end
local EnumCache = {}
local Enum = setmetatable({}, {
    __index = function(_, kind)
        local cached = EnumCache[kind]
        if cached then return cached end
        local items, list = {}, {}
        local group = {}
        setmetatable(group, {
            __index = function(_, name)
                if name == "GetEnumItems" then return function() return list end end
                local item = items[name]
                if not item then
                    item = enumItem(kind, name, #list)
                    items[name] = item
                    table.insert(list, item)
                end
                return item
            end,
        })
        EnumCache[kind] = group
        return group
    end,
})

-- events --------------------------------------------------------------------
local Event = {}
Event.__index = Event
function Event.new(name)
    return setmetatable({ name = name, handlers = {} }, Event)
end
function Event:Connect(fn)
    local handlers = self.handlers
    local connection = { Connected = true, fn = fn }
    table.insert(handlers, connection)
    function connection:Disconnect()
        if not self.Connected then return end
        self.Connected = false
        local index = table.find(handlers, self)
        if index then table.remove(handlers, index) end
    end
    return connection
end
function Event:Once(fn)
    local connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        fn(...)
    end)
    return connection
end
function Event:Fire(...)
    for _, connection in table.clone(self.handlers) do
        if connection.Connected then
            local ok, err = pcall(connection.fn, ...)
            if not ok then
                table.insert(M.errors, debug.traceback(tostring(err), 2))
            end
        end
    end
end
Event.Wait = function() end

-- instances -----------------------------------------------------------------
local ClassMeta = {}
ClassMeta.__index = ClassMeta

local Classes = {}
local ROOT_INSTANCE = nil

local function classOf(inst)
    return Classes[rawget(inst.__instance, "ClassName")] or Classes.Frame
end

local specialGet = {
    AbsolutePosition = function(self, instance)
        local x, y = 0, 0
        local node = instance
        while node do
            local p = node.Position
            if p then
                x += p.X.Offset
                y += p.Y.Offset
            end
            node = node.Parent and node.Parent.__instance or nil
        end
        return V2.new(x, y)
    end,
    AbsoluteSize = function(self, instance)
        local size = instance.Size or UDim2.new(0, 100, 0, 100)
        local parentSize = instance.Parent and instance.Parent.AbsoluteSize or V2.new(1920, 1080)
        if instance.SizeConstraint == Enum.SizeConstraint.RelativeXX then
            local x = size.X.Scale * parentSize.X + size.X.Offset
            return V2.new(x, x)
        end
        return V2.new(size.X.Scale * parentSize.X + size.X.Offset, size.Y.Scale * parentSize.Y + size.Y.Offset)
    end,
    AbsoluteContentSize = function(self, instance)
        -- only meaningful for a UIListLayout: the summed size of the parent's children
        local parent = instance.Parent
        if not parent then return V2.new(0, 0) end
        local total = 0
        for _, child in parent.__instance.Children do
            local size = child.AbsoluteSize
            total += size.Y + (instance.Padding and instance.Padding.Offset or 0)
        end
        return V2.new(0, total)
    end,
    AbsoluteCanvasSize = function(self, instance)
        local canvas = instance.CanvasSize or UDim2.new(0, 0, 0, 0)
        local layout = nil
        for _, child in instance.__instance.Children do
            if child.ClassName == "UIListLayout" then layout = child break end
        end
        local content = layout and layout.AbsoluteContentSize or V2.new(0, 0)
        return V2.new(math.max(canvas.X.Offset, content.X), math.max(canvas.Y.Offset, content.Y))
    end,
    TextBounds = function(self, instance)
        local text = instance.Text or ""
        local size = instance.TextSize or 14
        return V2.new(#text * size * 0.55, size)
    end,
    Children = function(self, instance) return instance.__children end,
    Destroying = function(self, instance) return instance.__destroying end,
    AncestryChanged = function(self, instance)
        instance.__signals.AncestryChanged = instance.__signals.AncestryChanged or Event.new("AncestryChanged")
        return instance.__signals.AncestryChanged
    end,
    ChildAdded = function(self, instance) return instance.__childChanged end,
    ChildRemoved = function(self, instance) return instance.__childChanged end,
    Changed = function(self, instance)
        instance.__signals.Changed = instance.__signals.Changed or Event.new("Changed")
        return instance.__signals.Changed
    end,
    Parent = function(self, instance) return instance.__parent end,
    ClassName = function(self, instance) return instance.__class end,
    Name = function(self, instance) return instance.__name end,
}

local function findChild(instance, name)
    for _, child in instance.__children do
        if rawget(child, "__instance").__name == name then return child end
    end
    return nil
end

local function isClass(instance, className)
    local meta = getmetatable(instance)
    while meta do
        if rawget(meta, "__classname") == className then return true end
        meta = rawget(meta, "__base")
    end
    return false
end

-- property reads the mock never implements: warn once so typos and missing bindings surface
local IGNORED_PROPS = {
    __instance = true, ClassName = true, Name = true, Parent = true, Children = true,
}

local methods = {}

function methods.GetChildren(self)
    return table.clone(self.__instance.__children)
end
function methods.GetDescendants(self)
    local out = {}
    local function walk(inst)
        for _, child in inst.__instance.__children do
            table.insert(out, child)
            walk(child)
        end
    end
    walk(self)
    return out
end
function methods.FindFirstChild(self, name)
    return findChild(self.__instance, name)
end
function methods.FindFirstChildOfClass(self, className)
    for _, child in self.__instance.__children do
        if isClass(child, className) then return child end
    end
    return nil
end
function methods.FindFirstChildWhichIsA(self, className) return methods.FindFirstChildOfClass(self, className) end
function methods.WaitForChild(self, name) return findChild(self.__instance, name) end
function methods.IsA(self, className) return isClass(self, className) end
function methods.Destroy(self)
    local instance = self.__instance
    instance.__destroying:Fire()
    for _, child in table.clone(instance.__children) do child:Destroy() end
    local parent = instance.__parent
    if parent then
        local index = table.find(parent.__instance.__children, self)
        if index then table.remove(parent.__instance.__children, index) end
        instance.__parent = nil
        parent.__instance.__childChanged:Fire()
    end
end
function methods.GetPropertyChangedSignal(self, property)
    local event = Event.new(property)
    local map = self.__instance.__signals
    map[property] = map[property] or event
    return event
end
function methods.ClearAllChildren(self)
    for _, child in table.clone(self.__instance.__children) do child:Destroy() end
end
function methods.GetAttribute() return nil end
function methods.SetAttribute() end
function methods.GetFullName(self) return self.__instance.__name end
function methods.CaptureFocus(self) self.__instance.__props.__focused = true end
function methods.ReleaseFocus(self) self.__instance.__props.__focused = false end
function methods.IsFocused(self) return self.__instance.__props.__focused == true end
function methods.TweenPosition() end
function methods.TweenSize() end

local GuiDefaults = {
    Size = UDim2.new(0, 100, 0, 100),
    Position = UDim2.new(0, 0, 0, 0),
    AnchorPoint = V2.new(0, 0),
    BackgroundTransparency = 0,
    ImageTransparency = 0,
    TextTransparency = 0,
    Visible = true,
    Rotation = 0,
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 1,
    ZIndex = 1,
    LayoutOrder = 0,
    ClipsDescendants = false,
    Active = false,
    Text = "",
    TextSize = 14,
    TextWrapped = false,
    RichText = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextTruncate = Enum.TextTruncate.None,
    TextScaled = false,
    Font = Enum.Font.Gotham,
    FontFace = nil,
    Image = "rbxassetid://0",
    ImageColor3 = Color3.new(1, 1, 1),
    ScaleType = Enum.ScaleType.Stretch,
    SizeConstraint = Enum.SizeConstraint.RelativeXY,
    PlaceholderText = "",
    PlaceholderColor3 = Color3.new(0.5, 0.5, 0.5),
    ClearTextOnFocus = false,
    MultiLine = false,
    AutoButtonColor = true,
    ScrollBarThickness = 12,
    ScrollBarImageColor3 = Color3.new(1, 1, 1),
    ScrollBarImageTransparency = 0,
    CanvasSize = UDim2.new(),
    CanvasPosition = V2.new(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.None,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ScrollingEnabled = true,
    AutomaticSize = Enum.AutomaticSize.None,
    MouseIcon = "",
    Interactable = true,
    Selectable = true,
    TextStrokeTransparency = 1,
    TextStrokeColor3 = Color3.new(0, 0, 0),
}

-- properties that exist in Roblox but the mock never needs a default for
local EXTRA_PROPERTIES = {
    Parent = true, Name = true, Archivable = true, Enabled = true, ResetOnSpawn = true, IgnoreGuiInset = true,
    DisplayOrder = true, CornerRadius = true, Thickness = true, Color = true, Transparency = true, ApplyStrokeMode = true,
    Offset = true, Rotation = true, Scale = true, PaddingTop = true, PaddingBottom = true, PaddingLeft = true, PaddingRight = true,
    FillDirection = true, HorizontalAlignment = true, VerticalAlignment = true, SortOrder = true, Wraps = true,
    HorizontalFlex = true, VerticalFlex = true, AspectRatio = true, AspectType = true, DominantAxis = true,
    CellPadding = true, CellSize = true, FillDirectionMaxCells = true, MaxColumns = true, MaxRows = true,
    BlurSize = true, AspectRatio = true, LineHeight = true, MaxVisibleGraphemes = true, OpenTypeFeatures = true,
    TextDirection = true, TextEditable = true, TextInputType = true, TextStrokeColor3 = true,
    SelectionBoxColor3 = true, SelectionColor3 = true, CursorPosition = true, SelectionStart = true,
    IsFocused = true, PaddingTop = true, UICornerRadius = true, ClipsDescendants = true,
    PrimaryPart = true, FieldOfView = true, CFRame = true, IgnoreGuiInset = true,
    ZIndexBehavior = true, FontFace = true, TextColor3 = true, ImageColor3 = true, PlaceholderColor3 = true,
    TextXAlignment = true, TextYAlignment = true, TextTruncate = true, TextScaled = true, TextWrapped = true,
    RichText = true, TextSize = true, Font = true, AutomaticSize = true, AutomaticCanvasSize = true,
    CanvasSize = true, CanvasPosition = true, ScrollBarThickness = true, ScrollBarImageColor3 = true,
    ScrollBarImageTransparency = true, ScrollingDirection = true, ScrollingEnabled = true,
    BackgroundColor3 = true, BackgroundTransparency = true, BorderSizePixel = true, ClipsDescendants = true,
    SizeConstraint = true, Visible = true, Size = true, Position = true, AnchorPoint = true, LayoutOrder = true,
    ZIndex = true, Rotation = true, Image = true, ScaleType = true, SliceCenter = true, AutoButtonColor = true,
    Active = true, Selectable = true, Interactable = true, Modal = true, ClearTextOnFocus = true, MultiLine = true,
    PlaceholderText = true, MouseIcon = true, Text = true, AspectRatio = true, TextEditable = true,
}

local GuiEvents = {
    "MouseEnter", "MouseLeave", "MouseMoved", "InputBegan", "InputEnded", "InputChanged",
    "MouseButton1Click", "MouseButton2Click", "MouseButton1Down", "MouseButton1Up",
    "Focused", "FocusLost", "Activated", "SelectionGained", "SelectionLost", "TouchTap", "TouchLongPress",
}

local function installClass(name, defaults, events, base)
    local C = {}
    C.__classname = name
    C.__base = base or methods
    C.__defaults = defaults or {}
    C.__events = events or {}

    C.__index = function(self, key)
        local instance = rawget(self, "__instance")
        if not instance then return nil end
        if key == "__instance" then return instance end
        local special = specialGet[key]
        if special then return special(self, instance) end
        local prop = instance.__props[key]
        if prop ~= nil then return prop end
        local default = rawget(C, "__defaults")[key]
        if default ~= nil then return default end
        local event = instance.__events[key]
        if event then return event end
        local signal = instance.__signals[key]
        if signal then return signal end
        local child = findChild(instance, key)
        if child then return child end
        local method = rawget(C, key) or (rawget(C, "__base") and rawget(C, "__base")[key]) or methods[key]
        if method == nil and not IGNORED_PROPS[key] then
            M.missing = M.missing or {}
            if not M.missing[key] then
                M.missing[key] = true
                table.insert(M.warnings, "missing property " .. tostring(key) .. " on " .. tostring(instance.__class)
                    .. debug.traceback("", 2))
            end
        end
        return method
    end

    local known = {}
    C.__newindex = function(self, key, value)
        local instance = rawget(self, "__instance")
        if not known[key] then
            known[key] = true
            if rawget(C, "__defaults")[key] == nil and not EXTRA_PROPERTIES[key] then
                table.insert(M.warnings, "unknown property " .. tostring(key) .. " on " .. tostring(rawget(C, "__classname"))
                    .. debug.traceback("", 3))
            end
        end
        if key == "Parent" then
            local previous = instance.__parent
            if previous then
                local index = table.find(previous.__instance.__children, self)
                if index then table.remove(previous.__instance.__children, index) end
            end
            instance.__parent = value
            if value then
                table.insert(value.__instance.__children, self)
                value.__instance.__childChanged:Fire()
            end
            instance.__signals.AncestryChanged = instance.__signals.AncestryChanged or Event.new("AncestryChanged")
            instance.__signals.AncestryChanged:Fire()
            return
        end
        if key == "Name" then
            instance.__name = tostring(value)
            return
        end
        instance.__props[key] = value
        local signal = instance.__signals[key]
        if signal then signal:Fire() end
        local changed = instance.__signals.Changed
        if changed then changed:Fire(key) end
        storeChildChanged(instance)
        instance.__childChanged:Fire()
    end

    C.new = function()
        local instance = {
            __class = name,
            __name = name,
            __children = {},
            __parent = nil,
            __props = {},
            __events = {},
            __signals = {},
            __childChanged = Event.new("ChildChanged"),
            __destroying = Event.new("Destroying"),
        }
        for _, eventName in C.__events do
            instance.__events[eventName] = Event.new(eventName)
        end
        local object = { __instance = instance }
        instance.Object = object
        return setmetatable(object, C)
    end
    Classes[name] = C
    return C
end

-- tell the parent when a child that affects layout changed
function storeChildChanged(instance)
    if instance.__parent then
        instance.__parent.__instance.__childChanged:Fire()
    end
end

installClass("Instance", {})
for _, name in { "Frame", "ScrollingFrame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ViewportFrame" } do
    installClass(name, GuiDefaults, GuiEvents)
end
installClass("UICorner", { CornerRadius = UDim.new(0, 0) })
installClass("UIStroke", { Thickness = 1, Color = Color3.new(), Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
installClass("UIGradient", { Offset = V2.new(0, 0), Rotation = 0, Enabled = true })
installClass("UIScale", { Scale = 1 })
installClass("UIPadding", { PaddingTop = UDim.new(), PaddingBottom = UDim.new(), PaddingLeft = UDim.new(), PaddingRight = UDim.new() })
installClass("UIListLayout", {
    Padding = UDim.new(), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder, Wraps = false,
})
installClass("UIGridLayout", {})
installClass("UIAspectRatioConstraint", { AspectRatio = 1 })
installClass("ScreenGui", { DisplayOrder = 0, ResetOnSpawn = true, IgnoreGuiInset = false, Enabled = true })
installClass("BlurEffect", { Size = 0, Enabled = true })
installClass("Camera", { ViewportSize = V2.new(1920, 1080) })
installClass("Highlight", {})

-- scheduler ------------------------------------------------------------------
-- every spawned function is a coroutine, so task.wait yields like it does in game
local threads = {}   -- { thread, resumeAt, args }
local current = nil

local function resumeAt(at, thread)
    table.insert(threads, { thread = thread, resumeAt = at })
end

local function spawnThread(fn, ...)
    local thread = coroutine.create(fn)
    table.insert(threads, { thread = thread, resumeAt = M.time, args = { ... } })
    return thread
end

local function stepThread(entry)
    if coroutine.status(entry.thread) == "dead" then return end
    local ok, wait = coroutine.resume(entry.thread, unpack(entry.args or {}))
    entry.args = nil
    if not ok then
        table.insert(M.errors, debug.traceback(tostring(wait), 2))
        return
    end
    if coroutine.status(entry.thread) == "dead" then return end
    -- yielded: wait is the delay requested through task.wait
    entry.resumeAt = M.time + (type(wait) == "number" and wait or 0)
    table.insert(threads, entry)
end

local task = {}
task.spawn = function(fn, ...) return spawnThread(fn, ...) end
task.defer = function(fn, ...)
    local thread = spawnThread(fn, ...)
    return thread
end
task.delay = function(delayTime, fn, ...)
    local thread = coroutine.create(fn)
    table.insert(threads, { thread = thread, resumeAt = M.time + (delayTime or 0), args = { ... } })
    return thread
end
task.cancel = function(thread)
    for index = #threads, 1, -1 do
        if threads[index].thread == thread then table.remove(threads, index) end
    end
end
task.wait = function(delayTime)
    if coroutine.isyieldable() then
        coroutine.yield(delayTime or 0)
    else
        -- main thread: advance the clock instead of blocking the test
        M.time += delayTime or 0
    end
end
task.Step = function()
    local due = {}
    for index = #threads, 1, -1 do
        local entry = threads[index]
        if entry.resumeAt <= M.time then
            table.remove(threads, index)
            table.insert(due, 1, entry)
        end
    end
    for _, entry in due do stepThread(entry) end
    return #due
end

M.time = 0
M.task = task
function M.Step(dt)
    M.time += dt or 0.016
    task.Step()
end
function M.Frame()
    M.runService.Heartbeat:Fire(0.016)
    M.runService.RenderStepped:Fire(0.016)
    M.Step(0.016)
end
function M.Flush(frames)
    for _ = 1, frames or 60 do M.Frame() end
end

-- services ------------------------------------------------------------------

local Event2 = Event
local UserInputService = {
    TouchEnabled = false,
    MouseEnabled = true,
    KeyboardEnabled = true,
    GamepadEnabled = false,
    InputBegan = Event2.new("InputBegan"),
    InputChanged = Event2.new("InputChanged"),
    InputEnded = Event2.new("InputEnded"),
    GetLastInputType = function() return Enum.UserInputType.MouseMovement end,
    IsKeyDown = function() return false end,
    GetFocusedTextBox = function() return nil end,
    GetMouseLocation = function() return V2.new(960, 540) end,
}

local RunService = {
    Heartbeat = Event2.new("Heartbeat"),
    RenderStepped = Event2.new("RenderStepped"),
    Stepped = Event2.new("Stepped"),
    IsStudio = function() return false end,
}

local TweenService = {}
TweenService.Create = function(_, instance, info, goal)
    local tween = { Completed = Event2.new("Completed") }
    function tween:Play()
        for key, value in goal do
            pcall(function() instance[key] = value end)
        end
        task.defer(function() tween.Completed:Fire(Enum.PlaybackState.Completed) end)
    end
    function tween:Cancel() end
    function tween:Pause() end
    return tween
end

local GuiService = {
    GetGuiInset = function() return V2.new(0, 0), V2.new(0, 36) end,
    TopbarInset = V2.new(0, 36),
}

local TextService = { GetTextSize = function() return V2.new(100, 14) end }

local json
local function encode(value)
    local t = typeof(value)
    if t == "string" then return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"' end
    if t == "number" or t == "boolean" then return tostring(value) end
    if t == "Color3" then return string.format('{"R":%.4f,"G":%.4f,"B":%.4f}', value.R, value.G, value.B) end
    if type(value) == "table" then
        local parts = {}
        if #value > 0 then
            for _, item in value do table.insert(parts, encode(item)) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for key, item in value do
            if item ~= nil then
                table.insert(parts, '"' .. tostring(key) .. '":' .. encode(item))
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end
-- small recursive-descent json decoder so config round trips work
local function decode(text)
    local pos = 1
    local function skip()
        while true do
            local char = text:sub(pos, pos)
            if char == " " or char == "\n" or char == "\t" or char == "\r" then pos += 1 else break end
        end
    end
    local parseValue
    local function parseString()
        pos += 1
        local out = {}
        while true do
            local char = text:sub(pos, pos)
            if char == "" then error("unterminated string") end
            if char == '"' then pos += 1 break end
            if char == "\\" then
                local nextChar = text:sub(pos + 1, pos + 1)
                local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                table.insert(out, map[nextChar] or nextChar)
                pos += 2
            else
                table.insert(out, char)
                pos += 1
            end
        end
        return table.concat(out)
    end
    function parseValue()
        skip()
        local char = text:sub(pos, pos)
        if char == "{" then
            pos += 1
            local object = {}
            skip()
            if text:sub(pos, pos) == "}" then pos += 1 return object end
            while true do
                skip()
                local key = parseString()
                skip()
                pos += 1 -- :
                object[key] = parseValue()
                skip()
                local sep = text:sub(pos, pos)
                pos += 1
                if sep == "}" then return object end
            end
        elseif char == "[" then
            pos += 1
            local array = {}
            skip()
            if text:sub(pos, pos) == "]" then pos += 1 return array end
            while true do
                table.insert(array, parseValue())
                skip()
                local sep = text:sub(pos, pos)
                pos += 1
                if sep == "]" then return array end
            end
        elseif char == '"' then
            return parseString()
        elseif text:sub(pos, pos + 3) == "true" then pos += 4 return true
        elseif text:sub(pos, pos + 4) == "false" then pos += 5 return false
        elseif text:sub(pos, pos + 3) == "null" then pos += 4 return nil
        else
            local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
            if not number or number == "" then error("bad json at " .. pos) end
            pos += #number
            return tonumber(number)
        end
    end
    return parseValue()
end

local HttpService = {
    JSONEncode = function(_, value) return encode(value) end,
    JSONDecode = function(_, text) return decode(text) end,
    GenerateGUID = function() return "guid" end,
}

local Stats = { GetTotalMemoryUsageMb = function() return 512 end }

local Players = {}
local player = setmetatable({
    Name = "TestPlayer",
    DisplayName = "TestPlayer",
    UserId = 1234,
    GetNetworkPing = function() return 0.042 end,
}, { __index = methods })
Players.LocalPlayer = player
Players.GetPlayers = function() return { player } end

local Lighting = setmetatable({}, { __index = methods })
local CoreGui = setmetatable({}, { __index = methods })
for _, service in { Lighting, CoreGui } do
    service.__instance = {
        __class = "Instance", __name = "Service", __children = {}, __parent = nil,
        __props = {}, __events = {}, __signals = {}, __childChanged = Event2.new(), __destroying = Event2.new(),
    }
end

local Camera = Classes.Camera.new()
local Workspace = setmetatable({
    CurrentCamera = Camera,
    GetRealPhysicsFPS = function() return 60 end,
}, { __index = methods })
Workspace.__instance = {
    __class = "Instance", __name = "Workspace", __children = {}, __parent = nil,
    __props = { CurrentCamera = Camera }, __events = {}, __signals = {},
    __childChanged = Event2.new(), __destroying = Event2.new(),
}

local services = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    TweenService = TweenService,
    GuiService = GuiService,
    TextService = TextService,
    HttpService = HttpService,
    Stats = Stats,
    Lighting = Lighting,
    CoreGui = CoreGui,
    ContextActionService = {},
    HapticService = {},
    StarterGui = {},
}

local game = {
    HttpGet = function() return "-- mock" end,
    GetService = function(_, name) return services[name] or error("no service " .. name) end,
    Players = Players,
    Workspace = Workspace,
    Lighting = Lighting,
    CoreGui = CoreGui,
    HttpService = HttpService,
    UserInputService = UserInputService,
    RunService = RunService,
    TweenService = TweenService,
    GuiService = GuiService,
    TextService = TextService,
}

M.userInput = UserInputService
M.runService = RunService

-- globals --------------------------------------------------------------------
local files = {}
function M.install(env)
    env._G = env
    local base = {
        string = string, table = table, math = math, os = os, coroutine = coroutine, debug = debug, utf8 = utf8,
        type = type, typeof = typeof, setmetatable = setmetatable, getmetatable = getmetatable,
        rawget = rawget, rawset = rawset, rawequal = rawequal, select = select, pcall = pcall, xpcall = xpcall,
        error = error, assert = assert, next = next, pairs = pairs, ipairs = ipairs, tostring = tostring,
        tonumber = tonumber, loadstring = loadstring, unpack = unpack, print = print, getfenv = getfenv, setfenv = setfenv,
    }
    for key, value in base do env[key] = value end
    env.Enum = Enum
    env.Instance = { new = function(name)
        local C = Classes[name]
        if not C then error("no class " .. tostring(name)) end
        return C.new()
    end }
    env.UDim = setmetatable({ new = UDim.new }, { __call = function(_, s, o) return UDim.new(s, o) end })
    env.UDim2 = UDim2
    env.Vector2 = Vector2
    env.Color3 = setmetatable({
        new = Color3.new, fromRGB = rgb, fromHSV = Color3.fromHSV, fromHex = Color3.fromHex,
    }, { __index = Color3 })
    env.ColorSequence = { new = function(...) return { Keypoints = { ... } } end }
    env.ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
    env.NumberSequence = { new = function(...) return { Keypoints = { ... } } end }
    env.NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
    env.TweenInfo = { new = function(time, style, direction) return { Time = time, Style = style, Direction = direction } end }
    env.Font = {
        new = function(path, weight, style) return { Family = path, Weight = weight, Style = style } end,
        fromEnum = function(value) return { Enum = value } end,
    }
    env.game = game
    env.workspace = Workspace
    env.Workspace = Workspace
    env.task = task
    env.warn = function(...) table.insert(M.warnings, table.concat({ ... }, " ")) end
    env.setclipboard = function(text) M.clipboard = text end
    env.getclipboard = function() return M.clipboard end
    env.getgenv = function() return env end
    env.getfenv = function(fn) return getfenv(fn) end
    env.writefile = function(path, content) files[path] = content end
    env.readfile = function(path) return files[path] or error("no file " .. tostring(path)) end
    env.isfile = function(path) return files[path] ~= nil end
    env.isfolder = function() return true end
    env.makefolder = function() end
    env.delfile = function(path) files[path] = nil end
    env.listfiles = function(folder)
        local out = {}
        local prefix = folder:gsub("%p", "%%%0") .. "/"
        for path in files do
            if path:find("^" .. prefix) then table.insert(out, path) end
        end
        return out
    end
    env.files = files
    return env
end
function M.newEnv()
    return setmetatable(M.install({}), { __index = ROOT })
end

return M
