local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")

-- screen guis. Main holds the window, Overlay holds popups/menus/tooltips (above the window),
-- Toast holds notifications, Hud holds on-screen buttons and watermarks
local Layer = {}

local function insert(parent)
    local gui = Instance.new("ScreenGui")
    gui.Name = "UnWrittenUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function() gui.Parent = parent end)
    if not ok then
        gui.Parent = Services.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or Services.Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    pcall(function() gui.DisplayOrder = 999 end)
    return gui
end

local function host()
    -- executors expose gethui(); a plain game script falls back to CoreGui / PlayerGui
    local get = rawget(getfenv(0), "gethui")
    if type(get) == "function" then
        local ok, result = pcall(get)
        if ok and result then return result end
    end
    if Services.CoreGui then return Services.CoreGui end
    return Services.Players.LocalPlayer:WaitForChild("PlayerGui")
end

Layer.Main = insert(host())
Layer.Overlay = insert(host())
Layer.Toast = insert(host())
Layer.Hud = insert(host())
Layer.Main.DisplayOrder = 999
Layer.Overlay.DisplayOrder = 1001
Layer.Toast.DisplayOrder = 1002
Layer.Hud.DisplayOrder = 1003

-- absolute point -> screen point inside a gui, and back
function Layer.ToScreen(point, parent)
    local gui = parent or Layer.Overlay
    local inset = Services.GuiService:GetGuiInset()
    return point - gui.AbsolutePosition - inset
end

function Layer.ScreenSize()
    local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    return size
end

-- keeps a popup inside the viewport
function Layer.Clamp(point, size, margin)
    local viewport = Layer.ScreenSize()
    margin = margin or 8
    local x = math.clamp(point.X, margin, math.max(margin, viewport.X - size.X - margin))
    local y = math.clamp(point.Y, margin, math.max(margin, viewport.Y - size.Y - margin))
    return Vector2.new(x, y)
end

-- place a popup under an anchor gui, or above it when there is no room below
function Layer.Place(anchor, size, preferRight)
    local viewport = Layer.ScreenSize()
    local position = anchor.AbsolutePosition
    local dimensions = anchor.AbsoluteSize
    local gap = 4
    local below = position.Y + dimensions.Y + gap
    local above = position.Y - size.Y - gap
    local y
    if below + size.Y <= viewport.Y - 8 or above < 8 then
        y = below
    else
        y = above
    end
    local x = preferRight and (position.X + dimensions.X - size.X) or position.X
    return Layer.Clamp(Vector2.new(x, y), size)
end

return Layer
