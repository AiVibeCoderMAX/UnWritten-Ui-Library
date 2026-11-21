local import = ...

local Services = import("Core/Services")
local Theme = import("Core/Theme")
local Util = import("Core/Util")
local Router = import("Core/Router")
local Keybinds = import("Core/Keybinds")
local Binding = import("Core/Binding")
local Layer = import("Components/Layer")
local Notification = import("Components/Notification")

-- UnWrittenUI entry point. CreateWindow builds a window; Notify, Unload and the theme helpers work
-- without one too.
local Library = {
    Theme = Theme,
    Flags = {},
    Notification = Notification,
    Windows = {},
    _unloadListeners = {},
}
Library.__index = Library

Binding.Start()
Keybinds.Start()
Router.Capture = false
Keybinds.OnCaptureBlocked = function(capturing)
    Router.Capture = capturing
    Library.Capturing = capturing
end

-- executors keep globals in getgenv(); a plain game script falls back to _G
local function shared()
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then return env end
    end
    return _G
end
Library.Shared = shared()

-- every script run replaces the previous instance's guis so re-executing does not stack menus
do
    local previous = shared().UnWrittenUI_Instance
    if type(previous) == "table" and previous ~= Library then
        pcall(previous.Unload, previous)
    end
end

local unloadListeners = Library._unloadListeners

function Library:CreateWindow(def)
    def = def or {}
    local Window = import("Components/Window")
    local window = Window.new(self, def)
    table.insert(self.Windows, window)
    self.Window = window
    shared().UnWrittenUI_Instance = self
    return window
end

function Library:Notify(options)
    return Notification.Show(options)
end

function Library:GetFlag(flag)
    local element = self.Flags[flag]
    if not element then return nil end
    if element.Get then return element:Get() end
    return element.Value
end

function Library:SetFlag(flag, ...)
    local element = self.Flags[flag]
    if element and element.Set then return element:Set(...) end
end

function Library:IsCapturing()
    return Keybinds.Capturing ~= nil
end

function Library:AddIcons(map)
    Util.AddIcons(map or {})
end

function Library:SetTheme(name)
    return Theme.UsePalette(name)
end

function Library:SetAccent(color)
    if typeof(color) == "Color3" then Theme.Set({ Accent = color }) end
end

function Library:SetBackgroundBlur(on)
    local Acrylic = import("Components/Acrylic")
    Acrylic.Set(on)
end

function Library:Toggle()
    if self.Window then self.Window:Toggle() end
end

function Library:OnUnload(fn)
    table.insert(unloadListeners, fn)
end

function Library:Unload()
    if self._unloaded then return end
    self._unloaded = true
    for _, fn in table.clone(unloadListeners) do
        local ok, err = pcall(fn)
        if not ok then warn("[UnWrittenUI] unload: " .. tostring(err)) end
    end
    table.clear(unloadListeners)
    for _, window in table.clone(self.Windows) do pcall(function() window:Destroy() end) end
    table.clear(self.Windows)
    for _, gui in { Layer.Main, Layer.Overlay, Layer.Toast, Layer.Hud } do
        if gui then gui:Destroy() end
    end
    if shared().UnWrittenUI_Instance == self then
        shared().UnWrittenUI_Instance = nil
    end
end

Library.Destroy = Library.Unload

return Library
