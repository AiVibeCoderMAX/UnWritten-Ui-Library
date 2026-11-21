local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")

-- global key handling: listens for the menu key, hides keys from text boxes, and runs the
-- "press a key" capture used by every keybind pill and the keybind element.
local Keybinds = {
    Capturing = nil,          -- the Binding waiting for a key
    OnCaptureBlocked = nil,   -- fun() while a capture is live; buttons ignore clicks then
    Changed = import("Core/Signal").new(),
}

local UIS = Services.UserInputService
local GuiService = Services.GuiService
local TextBox = nil

-- the menu key connection lives here so one library instance owns it
Keybinds.MenuKey = "RightShift"
local menuCallback = nil

function Keybinds.SetMenuKey(callback)
    menuCallback = callback
end

-- a text box has focus: game keys belong to typing, not to binds
function Keybinds.TextFocused()
    local ok, focused = pcall(function() return UIS:GetFocusedTextBox() end)
    if ok and focused then return true end
    if TextBox and TextBox.Parent and TextBox:IsFocused() then return true end
    return false
end

function Keybinds.SetTextBox(box)
    TextBox = box
end

function Keybinds.HeldModifiers()
    return import("Core/Binding").HeldModifiers()
end

local pointerDown = false

function Keybinds.Start()
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pointerDown = true
        end
        if Keybinds.Capturing then
            local binding = Keybinds.Capturing
            local name = input.KeyCode.Name
            if input.UserInputType == Enum.UserInputType.Keyboard and name ~= "Unknown" then
                Keybinds.HandleKey(binding, name)
            elseif input.UserInputType == Enum.UserInputType.MouseButton then
                Keybinds.HandleKey(binding, name)
            end
            return
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pointerDown = false
        end
        -- a modifier on its own completes the bind when released
        if Keybinds.Capturing and input.UserInputType == Enum.UserInputType.Keyboard then
            Keybinds.HandleRelease(Keybinds.Capturing, input.KeyCode.Name)
        end
    end)
end

-- the key name a capture should store, or nil when the key is not allowed
function Keybinds.Allowed(binding, name)
    local options = binding.Def.Capture or binding.Def or {}
    local mouse = options.AllowMouse
    if mouse == nil then mouse = import("Core/Binding").Options.Mouse end
    local isMouse = name:match("^MouseButton")
    if isMouse and not mouse then return nil, "Mouse buttons are turned off" end
    local blacklist = options.Blacklist
    if blacklist then
        for _, key in blacklist do
            local code = Util.KeyCode(key)
            if (code and code.Name == name) or key == name then return nil end
        end
    end
    return name
end

function Keybinds.HandleKey(binding, name)
    if name == "Escape" then
        local options = binding.Def.Capture or {}
        local mode = options.Escape or import("Core/Binding").Options.Escape
        Keybinds.StopCapture()
        if mode == "Clear" then binding:SetKey(nil) end
        return
    end
    local allowed = Keybinds.Allowed(binding, name)
    if not allowed then return end
    local isModifier = import("Core/Binding").Modifiers[name]
    if isModifier then
        -- a modifier alone completes the bind when released; holding it starts a combo
        local comboKeys = (binding.Def.Capture and binding.Def.Capture.ComboKeys) or import("Core/Binding").Options.ComboKeys
        if comboKeys <= 1 then
            Keybinds.StopCapture()
            binding:SetKey(name)
            return
        end
        binding._modifier = name
        return
    end
    local keys = {}
    local modifier = binding._modifier
    if modifier then table.insert(keys, modifier) end
    table.insert(keys, name)
    binding._modifier = nil
    Keybinds.StopCapture()
    binding:SetKey(table.concat(keys, "+"))
end

-- a modifier on its own: releasing it without another key completes the bind with the modifier
function Keybinds.HandleRelease(binding, name)
    if not Keybinds.Capturing or Keybinds.Capturing ~= binding then return end
    if binding._modifier == name then
        binding._modifier = nil
        Keybinds.StopCapture()
        binding:SetKey(name)
    end
end

function Keybinds.Capture(binding)
    if Keybinds.Capturing == binding then
        Keybinds.StopCapture()
        return
    end
    if Keybinds.Capturing then Keybinds.StopCapture() end
    Keybinds.Capturing = binding
    binding.Capturing = true
    binding._modifier = nil
    binding.Changed:Fire(binding.Key)
    if Keybinds.OnCaptureBlocked then Keybinds.OnCaptureBlocked(true) end
end

function Keybinds.StopCapture()
    local binding = Keybinds.Capturing
    if not binding then return end
    Keybinds.Capturing = nil
    binding.Capturing = false
    binding._modifier = nil
    binding.Changed:Fire(binding.Key)
    if Keybinds.OnCaptureBlocked then Keybinds.OnCaptureBlocked(false) end
end

function Keybinds.Refresh()
    Keybinds.Changed:Fire()
end

-- clicks and Escape while capturing, called by Router when a press ends
function Keybinds.Clicked()
    local binding = Keybinds.Capturing
    if not binding then return end
    local options = binding.Def.Capture or {}
    local mode = options.ClickOutside or import("Core/Binding").Options.ClickOutside
    Keybinds.StopCapture()
    if mode == "Clear" then binding:SetKey(nil) end
end

return Keybinds
