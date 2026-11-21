local import = ...
local Services = import("Core/Services")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

-- one keybind: a key (or a combo such as "LeftControl+L"), a mode and the press / release behaviour.
-- Capture listens globally until a key is pressed; combos grow while a modifier is held.
local Binding = {}
Binding.__index = Binding
Binding._all = {}

local UIS = Services.UserInputService

Binding.Options = {
    ClickOutside = "Keep",   -- a click while capturing keeps the old key or clears it
    Escape = "Keep",
    Mouse = true,            -- right / middle mouse buttons can be bound
    ComboKeys = 3,           -- keys per bind, 1 turns combos off
}

local MOUSE = { MouseButton2 = true, MouseButton3 = true }
local MODIFIERS = {
    LeftShift = true, RightShift = true, LeftControl = true, RightControl = true, LeftAlt = true, RightAlt = true,
}
local MODIFIER_ORDER = {
    LeftControl = 1, RightControl = 2, LeftShift = 3, RightShift = 4, LeftAlt = 5, RightAlt = 6,
}

Binding.Modifiers = MODIFIERS

-- "LeftControl+L" as {"LeftControl", "L"}; a single key is a one entry list
function Binding.Split(key)
    if not key then return {} end
    local out = {}
    for part in tostring(key):gmatch("[^+]+") do table.insert(out, part) end
    return out
end

function Binding.Join(keys)
    return table.concat(keys, "+")
end

-- a sortable, display-able name for any bind value
function Binding.KeyName(key)
    if key == nil then return nil end
    if type(key) == "string" then return key end
    if typeof(key) == "EnumItem" then return key.Name end
    return tostring(key)
end

local function fire(binding, pressed)
    local mode = binding.Mode
    if mode == "Hold" then
        binding.Held = pressed
        if pressed then
            if binding.Press then Util.Defer(binding.Press, binding) end
            binding.StateChanged:Fire(true)
        else
            if binding.Release then Util.Defer(binding.Release, binding) end
            binding.StateChanged:Fire(false)
        end
    elseif pressed then
        if binding.Press then Util.Defer(binding.Press, binding) end
        if mode == "Toggle" then
            binding.On = not binding.On
            if binding.SetState then binding.SetState(binding.On) end
            binding.StateChanged:Fire(binding.On)
        else
            binding.StateChanged:Fire(true)
        end
    end
end

-- def: Key, Mode, Modes, Press(binding), Release(binding), SetState, Listed, Capture options
function Binding.new(def)
    local self = setmetatable({
        Key = nil,
        Mode = def and def.Mode or "Toggle",
        Modes = (def and def.Modes) or { "Toggle", "Hold" },
        Press = def and def.Press,
        Release = def and def.Release,
        SetState = def and def.SetState,
        Def = def or {},
        Capturing = false,
        On = false,
        Held = false,
        Changed = Signal.new(),
        StateChanged = Signal.new(),
    }, Binding)
    self.Key = Binding.KeyName(def and (def.Key or def.Default))
    if self.Key ~= "" then
        -- normalize a key string / enum into the stored name
        self.Key = Binding.KeyName(self.Key)
    end
    if self.Key == "" then self.Key = nil end
    table.insert(Binding._all, self)
    return self
end

function Binding:SetKey(key, silent)
    self.Key = Binding.KeyName(key)
    if self.Key == "" then self.Key = nil end
    self.Changed:Fire(self.Key)
    import("Core/Keybinds").Refresh()
end

function Binding:SetMode(mode)
    if mode ~= "Toggle" and mode ~= "Hold" and mode ~= "Always" then return end
    self.Mode = mode
    self.Changed:Fire(self.Key)
    import("Core/Keybinds").Refresh()
end

function Binding:Capture()
    local Keybinds = import("Core/Keybinds")
    Keybinds.Capture(self)
end

function Binding:IsDown()
    if not self.Key then return false end
    local keys = Binding.Split(self.Key)
    for _, name in keys do
        local code = Util.KeyCode(name)
        if code then
            local ok, down = pcall(function() return UIS:IsKeyDown(code) end)
            if ok and down then return true end
        end
    end
    return false
end

function Binding:Save()
    return { Key = self.Key, Mode = self.Mode }
end

function Binding:Load(data)
    if type(data) ~= "table" then return end
    if data.Key ~= nil then self:SetKey(data.Key) end
    if data.Mode then self:SetMode(data.Mode) end
end

function Binding:Destroy()
    local index = table.find(Binding._all, self)
    if index then table.remove(Binding._all, index) end
    self.Changed:Destroy()
    self.StateChanged:Destroy()
end

-- fires every binding that matches the pressed key. The most specific match wins: a combo such as
-- LCtrl + L does not also fire a plain L.
local function keyDown(input, gameProcessed)
    local Keybinds = import("Core/Keybinds")
    if Keybinds.Capturing then
        Keybinds.Handle(input)
        return
    end
    if gameProcessed then return end
    if Keybinds.TextFocused() then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard and input.UserInputType ~= Enum.UserInputType.MouseButton then return end
    local name = input.KeyCode.Name
    if name == "Unknown" then return end
    local held = Keybinds.HeldModifiers()
    local best, bestScore = {}, -1
    for _, binding in Binding._all do
        if binding.Key and not binding.Capturing then
            local keys = Binding.Split(binding.Key)
            local last = keys[#keys]
            if last == name then
                local modifiers = {}
                for index = 1, #keys - 1 do modifiers[keys[index]] = true end
                local ok = true
                for modifier in modifiers do
                    if not held[modifier] then ok = false break end
                end
                if ok then
                    -- every modifier in the bind must be held and no other needed one may be added
                    local score = #keys
                    if score > bestScore then
                        best = { binding }
                        bestScore = score
                    elseif score == bestScore then
                        table.insert(best, binding)
                    end
                end
            end
        end
    end
    for _, binding in best do fire(binding, true) end
end

local function keyUp(input)
    if import("Core/Keybinds").Capturing then return end
    local name = input.KeyCode.Name
    for _, binding in Binding._all do
        if binding.Mode == "Hold" and binding.Held and binding.Key then
            local keys = Binding.Split(binding.Key)
            if keys[#keys] == name then fire(binding, false) end
        end
    end
end

-- held modifiers, both physical and logical (UIS reports either side depending on the platform)
function Binding.HeldModifiers()
    local held = {}
    for _, name in { "LeftShift", "RightShift", "LeftControl", "RightControl", "LeftAlt", "RightAlt" } do
        local ok, down = pcall(function() return UIS:IsKeyDown(Enum.KeyCode[name]) end)
        if ok and down then held[name] = true end
    end
    return held
end

function Binding.Start()
    UIS.InputBegan:Connect(keyDown)
    UIS.InputEnded:Connect(keyUp)
end

return Binding
