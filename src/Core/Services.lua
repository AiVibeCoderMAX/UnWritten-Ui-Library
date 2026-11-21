local _ = ...

local cloneref = cloneref or function(instance) return instance end

local function service(name)
    local ok, result = pcall(function() return cloneref(game:GetService(name)) end)
    return ok and result or game:GetService(name)
end

return {
    Players = service("Players"),
    UserInputService = service("UserInputService"),
    RunService = service("RunService"),
    TweenService = service("TweenService"),
    HttpService = service("HttpService"),
    TextService = service("TextService"),
    CoreGui = service("CoreGui"),
    GuiService = service("GuiService"),
    Lighting = service("Lighting"),
    Stats = service("Stats"),
    ContextActionService = service("ContextActionService"),
    HapticService = service("HapticService"),
    StarterGui = service("StarterGui"),
}
