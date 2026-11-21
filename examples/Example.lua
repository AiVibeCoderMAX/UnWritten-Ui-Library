--[[
    UnWrittenUI showcase
    --------------------
    Every feature in one script. Run it with an executor:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/AiVibeCoderMAX/UnWritten-Ui-Library/main/dist/UnWrittenUI.lua"))()
    or, while developing, build the harness and run that instead:
        npm run harness

    The window fills itself with demonstration modules. Everything you toggle, drag or pick is
    saved to disk, so re-running keeps your state.
]]

local UnWrittenUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/AiVibeCoderMAX/UnWritten-Ui-Library/main/dist/UnWrittenUI.lua"))()

-- optional: this library ships no icons, so map any icon names you use to your own assets once.
-- Unknown names fall back to a circle, so it always renders.
UnWrittenUI:AddIcons({
    -- custom = "rbxassetid://0000000000",
})

local Window = UnWrittenUI:CreateWindow({
    Title = "UnWritten",
    Subtitle = "v" .. UnWrittenUI.Version,
    Icon = "sparkles",
    Folder = "UnWrittenUI_Demo",
    Size = UDim2.fromOffset(780, 520),
    ToggleKey = "RightShift",
    User = true,
    AutoSave = true,
    AutoLoad = true,
    Settings = true,   -- the built-in Settings tab: themes, configs, keybinds, overlays
})

-- ============================================================================
-- Combat
-- ============================================================================
local Combat = Window:Tab({ Title = "Combat", Icon = "swords" })

local Aim = Combat:Module({
    Title = "Aim assist",
    Description = "Smoothly tracks the nearest target",
    Icon = "crosshair",
    Flag = "Aim",
    Keybind = { Key = "Q", Mode = "Toggle" },
})
Aim:Toggle({ Title = "Enabled", Flag = "AimEnabled", Default = false, Callback = function(on)
    print("aim assist", on)
end })
Aim:Slider({ Title = "Smoothing", Min = 0.05, Max = 1, Step = 0.05, Default = 0.35, Suffix = "x", Flag = "AimSmooth" })
Aim:Slider({ Title = "Field of view", Min = 10, Max = 360, Default = 120, Suffix = "°", Flag = "AimFov" })
Aim:Dropdown({ Title = "Hit part", Values = { "Head", "Torso", "Nearest" }, Default = "Head", Flag = "AimPart" })
Aim:Toggle({
    Title = "Team check",
    Description = "Skip teammates",
    Flag = "AimTeam",
    Default = true,
})
Aim:Keybind({ Title = "Toggle key", Default = "Q", Flag = "AimKey" })

local Visuals = Combat:Module({
    Title = "Visuals",
    Description = "Highlights, tracers and boxes",
    Icon = "eye",
    Flag = "Visuals",
})
Visuals:Toggle({ Title = "Boxes", Flag = "Boxes", Default = true })
Visuals:Toggle({ Title = "Tracers", Flag = "Tracers" })
Visuals:ColorPicker({ Title = "Colour", Default = Color3.fromRGB(120, 170, 255), Flag = "EspColor" })
Visuals:Slider({ Title = "Transparency", Min = 0, Max = 1, Step = 0.05, Default = 0.25, Flag = "EspAlpha" })
Visuals:Dropdown({
    Title = "Targets",
    Values = { "Players", "NPCs", "Dummies" },
    Multi = true,
    Default = { "Players" },
    Flag = "EspTargets",
})

local Melee = Combat:Module({ Title = "Melee", Description = "Swing automation", Icon = "sword" })
Melee:Toggle({ Title = "Auto swing", Flag = "AutoSwing" })
Melee:Slider({ Title = "Range", Min = 4, Max = 30, Default = 12, Suffix = " studs", Flag = "MeleeRange" })
Melee:Buttons({
    { Title = "Equip", Icon = "hand", Callback = function() print("equip") end },
    { Title = "Unequip", Icon = "x", Callback = function() print("unequip") end },
})

-- ============================================================================
-- Movement
-- ============================================================================
local Movement = Window:Tab({ Title = "Movement", Icon = "move", Columns = 2 })

local Speed = Movement:Module({ Title = "Speed", Icon = "gauge", Flag = "Speed" })
Speed:Slider({
    Title = "Walk speed",
    Min = 16, Max = 250, Default = 32, Flag = "WalkSpeed", Suffix = " ws",
    Callback = function(value)
        local character = game.Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.WalkSpeed = value end
    end,
})
Speed:Toggle({ Title = "Only while sprinting", Flag = "SpeedSprint" })
Speed:Segmented({ Title = "Mode", Values = { "Set", "Multiply", "Add" }, Default = "Set", Flag = "SpeedMode" })

local Fly = Movement:Module({ Title = "Fly", Icon = "plane", Flag = "Fly" })
Fly:Toggle({ Title = "Enabled", Flag = "FlyOn" })
Fly:Slider({ Title = "Speed", Min = 10, Max = 500, Default = 80, Flag = "FlySpeed" })
Fly:Slider({ Title = "Lift", Min = 0, Max = 100, Default = 30, Flag = "FlyLift" })
Fly:Keybind({ Title = "Hotkey", Default = "F", Mode = "Toggle", Flag = "FlyKey" })

local Jump = Movement:Module({ Title = "Jump", Icon = "arrow-up", Side = "Right" })
Jump:Slider({ Title = "Power", Min = 50, Max = 500, Default = 50, Flag = "JumpPower" })
Jump:Toggle({ Title = "Infinite jump", Flag = "InfJump" })
Jump:ProgressBar({ Title = "Cooldown", Value = 0 })

-- ============================================================================
-- Player
-- ============================================================================
local Player = Window:Tab({ Title = "Player", Icon = "user" })

local Character = Player:Module({ Title = "Character", Icon = "person-standing" })
Character:Slider({ Title = "Field of view", Min = 40, Max = 120, Default = 70, Flag = "Fov" })
Character:Slider({ Title = "Camera height", Min = -10, Max = 10, Default = 0, Flag = "CamHeight" })
Character:Dropdown({
    Title = "Body parts",
    Values = { "Head", "Torso", "Arms", "Legs", "Accessories" },
    Multi = true, Flag = "BodyParts",
})
Character:Button({ Title = "Respawn", Icon = "rotate-cw", Style = "Primary", Callback = function()
    local character = game.Players.LocalPlayer.Character
    if character then character:BreakJoints() end
end })

local Appearance = Player:Module({ Title = "Appearance", Icon = "palette", Side = "Right" })
Appearance:ColorPicker({ Title = "Skin tone", Default = Color3.fromRGB(235, 190, 160), Flag = "Skin" })
Appearance:Input({ Title = "Display name", Placeholder = "type a name", Flag = "DisplayName" })
Appearance:Range({ Title = "Height range", Min = 0.5, Max = 2, Step = 0.05, Default = { 0.9, 1.1 }, Flag = "Height" })

-- ============================================================================
-- Extra: groups, code, logs, images and sub-tabs
-- ============================================================================
local Extras = Window:Tab({ Title = "Extras", Icon = "box" })
local Section = Extras:SubTab({ Title = "Widgets", Icon = "layout-grid" })

local Kitchen = Section:Module({ Title = "Kitchen sink", Icon = "list" })
local Group = Kitchen:Group({ Title = "Advanced", Opened = true })
Group:Checkbox({ Title = "Verbose logging", Flag = "Verbose" })
Group:Checkbox({ Title = "Telemetry", Flag = "Telemetry" })
Group:Divider({ Text = "Output" })
local Log = Group:Log({ Title = "Events", Height = 110 })
Log:Add("loaded", Color3.fromRGB(120, 220, 160))
Log:Add("waiting for game", Color3.fromRGB(240, 200, 120))
Group:Code({
    Title = "Snippet",
    Code = [[
local player = game.Players.LocalPlayer
print("hello, " .. player.Name)
]],
})
Group:Label({ Text = "Plain label", Value = "with a value" })
Group:Paragraph({ Title = "Read me", Content = "Paragraphs support <b>bold</b>, <i>italics</i> and <font color='#7fb4ff'>colour</font>." })
Group:Image({ Image = "rbxassetid://0", Height = 64, Caption = "An image" })
Group:Spacer({ Height = 2 })

local SubTwo = Extras:SubTab({ Title = "Second Page", Icon = "layers" })
local Second = SubTwo:Module({ Title = "Another module", Icon = "star" })
Second:Toggle({ Title = "A toggle", Flag = "SecondToggle" })
Second:Slider({ Title = "A slider", Min = 0, Max = 10, Default = 4, Flag = "SecondSlider" })

-- ============================================================================
-- Floaters: panels, screen buttons, dialogs, notifications, context menus
-- ============================================================================
local Hud = Window:Panel({
    Title = "Overlay",
    Icon = "layout-dashboard",
    Size = Vector2.new(220, 190),
    Position = UDim2.fromOffset(24, 24),
})
Hud:Toggle({ Title = "Show FPS", Default = true, Flag = "HudFps" })
Hud:Slider({ Title = "Refresh", Min = 0.1, Max = 2, Step = 0.1, Default = 0.5, Flag = "HudRefresh" })
Hud:Label({ Text = "State", Value = "streaming" })

Window:ScreenButton({
    Title = "Aim",
    Icon = "crosshair",
    Color = Color3.fromRGB(120, 170, 255),
    Press = function()
        UnWrittenUI:Notify({ Title = "Screen button", Content = "pressed", Type = "Info" })
    end,
    Active = function() return UnWrittenUI:GetFlag("AimEnabled") end,
})

UnWrittenUI:Notify({
    Title = "UnWrittenUI",
    Content = "Loaded " .. #Window:Modules() .. " modules across " .. #Window.Tabs .. " tabs.",
    Type = "Success",
    Icon = "sparkles",
    Duration = 5,
})

Window:Dialog({
    Title = "Welcome",
    Content = "This is the example script. Toggle the menu with RightShift.",
    Icon = "hand",
    Buttons = {
        { Title = "Got it", Style = "Primary" },
        { Title = "Docs", Callback = function()
            setclipboard("https://github.com/AiVibeCoderMAX/UnWritten-Ui-Library")
        end },
    },
})

-- right-click any module title for its menu; this is the same API for your own menus
Window:Menu({
    { Title = "Toggle menu", Icon = "eye", Callback = function() Window:Toggle() end },
    { Title = "Re-center", Icon = "move", Callback = function() Window:Center() end },
    { Title = "Reset state", Icon = "rotate-ccw", Callback = function() Window:Reset() end },
})

-- ============================================================================
-- Flags: shared with your own code
-- ============================================================================
UnWrittenUI:OnUnload(function()
    print("UnWrittenUI unloaded")
end)

task.spawn(function()
    while task.wait(1) do
        local character = game.Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and UnWrittenUI:GetFlag("SpeedSprint") then
            humanoid.WalkSpeed = humanoid.WalkSpeed
        end
    end
end)
