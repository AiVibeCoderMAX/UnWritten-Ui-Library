local import = ...
local Signal = import("Core/Signal")
local Services = import("Core/Services")
local Animation = import("Core/Animation")
local Presets = import("Themes/Presets")

-- tokens: colour palette (from a preset) + style values on top, bindable to instances
local Theme = {
    Presets = Presets,
    Changed = Signal.new(),
    Palette = "Sapphire",
    Current = {},
}

Theme.PaletteKeys = {
    "Accent", "AccentAlt", "Background", "BackgroundAlt", "Surface", "SurfaceHover", "Elevated", "ElevatedHover",
    "Stroke", "Divider", "Text", "TextDim", "TextMuted", "OnAccent", "Success", "Warning", "Danger", "Info",
}

Theme.StyleDefaults = {
    WindowTransparency = 0.04,
    SurfaceTransparency = 0.25,
    ElevatedTransparency = 0.1,
    StrokeTransparency = 0.6,
    Radius = 12,
    ElementRadius = 8,
    Font = "Ubuntu",
    AnimSpeed = 1,
    Gradient = true,
    GradientRotation = 45,
    AnimatedTitle = true,
}

Theme.Fonts = {
    { "Ubuntu", "Ubuntu" },
    { "Montserrat", "Montserrat" },
    { "BuilderSans", "Builder Sans" },
    { "Nunito", "Nunito" },
    { "Roboto", "Roboto" },
    { "SourceSansPro", "Source Sans" },
    { "Arimo", "Arimo" },
    { "JosefinSans", "Josefin Sans" },
    { "TitilliumWeb", "Titillium" },
    { "Oswald", "Oswald" },
    { "Jura", "Jura" },
    { "Zekton", "Zekton" },
    { "Michroma", "Michroma" },
    { "Merriweather", "Merriweather" },
    { "FredokaOne", "Fredoka" },
    { "RobotoMono", "Roboto Mono" },
}

-- strong keys: roblox recycles instance wrappers, so a weak table would lose live bindings;
-- unparented (destroyed) instances are dropped by Apply and Sweep
local registry = {}
local pending = false

local function value(token, current)
    if type(token) ~= "function" then return current[token] end
    local ok, result = pcall(token, current)
    return ok and result or nil
end

Theme.Resolve = value

local function set(inst, prop, v)
    inst[prop] = v
end

-- runs for every bound instance on a theme change: no closure per property
local function paint(inst, map)
    local current = Theme.Current
    for prop, token in map do
        local v = value(token, current)
        if v ~= nil then pcall(set, inst, prop, v) end
    end
end

-- map: property -> token name or function(current) -> value
function Theme.Bind(inst, map)
    local bound = registry[inst]
    if not bound then
        bound = {}
        registry[inst] = bound
    end
    for prop, token in map do bound[prop] = token end
    paint(inst, map)
    return inst
end

function Theme.Unbind(inst, prop)
    local bound = registry[inst]
    if bound then
        if prop then bound[prop] = nil else registry[inst] = nil end
    end
end

-- re-resolves an instance after its state changed; tweens when time > 0
function Theme.Refresh(inst, time)
    local bound = registry[inst]
    if not bound then return end
    local speed = Animation.Speed
    if not time or time <= 0 or speed <= 0 then
        paint(inst, bound)
        return
    end
    local goal = {}
    local current = Theme.Current
    for prop, token in bound do
        local v = value(token, current)
        if v ~= nil then
            local kind = typeof(v)
            if kind == "Color3" or kind == "number" or kind == "UDim" or kind == "UDim2" or kind == "Vector2" then
                goal[prop] = v
            else
                pcall(set, inst, prop, v)
            end
        end
    end
    Services.TweenService:Create(inst, TweenInfo.new(time / speed, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal):Play()
end

function Theme.Apply()
    for inst, map in registry do
        if inst.Parent == nil then
            registry[inst] = nil
        else
            paint(inst, map)
        end
    end
end

-- binds a property to a function of the token table even when the instance has no other binding,
-- so Refresh keeps working after the map is gone
function Theme.Watch(inst, map)
    return Theme.Bind(inst, map)
end

function Theme.Sweep()
    for inst in registry do
        if inst.Parent == nil then registry[inst] = nil end
    end
end

local function schedule()
    if pending then return end
    pending = true
    task.defer(function()
        pending = false
        Theme.Apply()
    end)
end

function Theme.Set(patch)
    for key, v in patch do Theme.Current[key] = v end
    if patch.AnimSpeed ~= nil then Animation.Speed = tonumber(patch.AnimSpeed) or 1 end
    schedule()
    Theme.Changed:Fire(patch)
end

function Theme.Get(key)
    return Theme.Current[key]
end

function Theme.UsePalette(name)
    local palette = Presets[name]
    if type(palette) ~= "table" or name == "Order" then return false end
    Theme.Palette = name
    Theme.Set(table.clone(palette))
    return true
end

-- one Font per family, weight and style: every label repaints its font on a theme change
local fonts = {}

function Theme.Font(weight, style)
    weight = weight or Enum.FontWeight.Regular
    style = style or Enum.FontStyle.Normal
    return function(current)
        local family = tostring(current.Font or "Ubuntu")
        local byWeight = fonts[family]
        if not byWeight then
            byWeight = {}
            fonts[family] = byWeight
        end
        local byStyle = byWeight[weight]
        if not byStyle then
            byStyle = {}
            byWeight[weight] = byStyle
        end
        local font = byStyle[style]
        if not font then
            local ok, result = pcall(function()
                return Font.new("rbxasset://fonts/families/" .. family .. ".json", weight, style)
            end)
            if not ok then
                result = Font.fromEnum(Enum.Font.Gotham)
            end
            byStyle[style] = result
            font = result
        end
        return font
    end
end

-- json-safe copy: colours as hex
function Theme.Export()
    local out = { Palette = Theme.Palette, Tokens = {} }
    for key, v in Theme.Current do
        if key:sub(1, 1) ~= "_" then
            out.Tokens[key] = typeof(v) == "Color3" and ("#" .. v:ToHex()) or v
        end
    end
    return out
end

function Theme.Import(data)
    if type(data) ~= "table" or type(data.Tokens) ~= "table" then return false end
    local patch = {}
    for key, v in data.Tokens do
        local current = Theme.Current[key]
        if typeof(current) == "Color3" and type(v) == "string" then
            local ok, color = pcall(Color3.fromHex, v)
            if ok then patch[key] = color end
        elseif current == nil or type(current) == type(v) then
            patch[key] = v
        end
    end
    if type(data.Palette) == "string" then Theme.Palette = data.Palette end
    Theme.Set(patch)
    return true
end

do
    for key, v in Presets.Sapphire do Theme.Current[key] = v end
    for key, v in Theme.StyleDefaults do Theme.Current[key] = v end
    Animation.Speed = Theme.Current.AnimSpeed
    -- keep the registry from growing while scripts build many windows
    task.spawn(function()
        while true do
            task.wait(30)
            Theme.Sweep()
        end
    end)
end

return Theme
