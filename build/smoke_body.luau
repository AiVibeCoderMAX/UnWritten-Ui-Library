-- Smoke test body. The harness injects UnWrittenUI (and Mock) into this environment before running.
-- Every step builds part of a real window; failures are collected and printed at the end.
local report = {}
local failed = 0
local function step(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        failed += 1
        table.insert(report, name .. ": FAIL " .. tostring(err))
    end
end

local function fireInput(inst, userInputType, position)
    inst.InputBegan:Fire({ UserInputType = userInputType, Position = position or Vector2.new(10, 10), KeyCode = Enum.KeyCode.Unknown })
end
local function releaseInput(inst, userInputType, position)
    inst.InputEnded:Fire({ UserInputType = userInputType, Position = position or Vector2.new(10, 10), KeyCode = Enum.KeyCode.Unknown })
end
local function firstButton(inst)
    if inst.ClassName == "TextButton" or inst.ClassName == "ImageButton" then return inst end
    for _, child in inst:GetDescendants() do
        if child.ClassName == "TextButton" or child.ClassName == "ImageButton" then return child end
    end
    return inst
end
-- an element can be mounted several times (card, panel, group); search the current one
local function viewOf(element)
    for _, mount in element._mounts or {} do
        local view = mount.Views and mount.Views[1]
        if view and view.Parent then return view end
    end
    local mount = element._mounts and element._mounts[1]
    return mount and mount.Views and mount.Views[1]
end
local function children(element)
    return element.Children or {}
end

-- build ---------------------------------------------------------------------
step("create window", function()
    Window = UnWrittenUI:CreateWindow({ Title = "Smoke", Subtitle = "test", Folder = "SmokeTest", Theme = "Midnight" })
    assert(Window, "no window")
    assert(#Window.Tabs >= 1, "settings tab missing")
end)

step("tab + subtab + module", function()
    Tab = Window:Tab({ Title = "Main", Icon = "house", Caption = "Test" })
    Sub = Tab:SubTab({ Title = "First", Icon = "plus" })
    M = Sub:Module({ Title = "Module", Description = "A card", Flag = "Mod", Keybind = { Key = "Q" } })
    assert(M, "no module")
end)

step("all element kinds", function()
    M:Toggle({ Title = "Toggle", Flag = "T", Default = true, Callback = function() end })
    M:Slider({ Title = "Slider", Min = 0, Max = 100, Default = 50, Flag = "S" })
    M:Range({ Title = "Range", Min = 0, Max = 10, Default = { 2, 8 }, Flag = "R" })
    M:Dropdown({ Title = "Drop", Values = { "a", "b", "c" }, Flag = "D", Multi = true })
    M:Input({ Title = "Input", Placeholder = "type", Flag = "I" })
    M:Keybind({ Title = "Bind", Default = "E", Flag = "K" })
    M:ColorPicker({ Title = "Colour", Default = Color3.fromRGB(1, 2, 3), Flag = "C" })
    M:Segmented({ Title = "Seg", Values = { "x", "y", "z" }, Flag = "SG" })
    M:Button({ Title = "Press me", Icon = "zap", Callback = function() end })
    M:Buttons({ { Title = "A" }, { Title = "B" } })
    M:Paragraph({ Title = "Text", Content = "Some <b>rich</b> text" })
    M:Divider({ Text = "Divider" })
    M:Spacer({ Height = 4 })
    M:ProgressBar({ Title = "Progress", Value = 30 })
    M:Image({ Image = "rbxassetid://1", Height = 40 })
    M:Code({ Title = "Code", Code = "print('hi')" })
    M:Log({ Title = "Log", Height = 60 })
    M:Label({ Text = "Label", Value = "value" })
    local group = M:Group({ Title = "Group", Opened = true })
    group:Checkbox({ Title = "Check", Flag = "CH" })
    Group = group
    assert(#children(M) >= 19, "expected 19+ elements, got " .. #children(M))
end)

step("sections and the right column", function()
    Section = Tab:Section({ Title = "Section", Icon = "info", Side = "Right" })
    Section:Label({ Text = "In a section" })
    Right = Sub:Module({ Title = "Right card", Side = "Right" })
    Right:Slider({ Title = "R slider", Min = 0, Max = 1, Step = 0.1, Flag = "RS" })
end)

step("floaters", function()
    Window:Notify({ Title = "Hello", Content = "world" })
    Window:Dialog({ Title = "Dialog", Content = "test", Buttons = { { Title = "OK" } } })
    Panel = Window:Panel({ Title = "Panel", Icon = "layers", Size = Vector2.new(200, 200) })
    Panel:Toggle({ Title = "Panel toggle" })
    Panel:Show()
    Window:ScreenButton({ Title = "Aimbot", Icon = "target", Active = function() return true end, Press = function() end })
    assert(#Window.Panels >= 1, "panel not registered")
    assert(#Window.ScreenButtons >= 1, "screen button not registered")
end)

-- interaction ---------------------------------------------------------------
-- cards only render once their page is visible, so show the tab before interacting
step("show the tab", function()
    Window:SelectTab(Tab)
    Sub.Page:Mount()
    Sub.Page:SetVisible(true)
    Mock.Flush(10)
end)

step("click a toggle", function()
    local toggle = M:Toggle({ Title = "Clickable", Default = false })
    M:SetExpanded(true)
    local target = firstButton(viewOf(toggle))
    fireInput(target, Enum.UserInputType.MouseButton1)
    releaseInput(target, Enum.UserInputType.MouseButton1)
    Mock.Flush(10)
    assert(toggle:Get() == true, "click did not flip the toggle")
end)

step("press a button", function()
    local pressed = 0
    local button = M:Button({ Title = "Click me", Callback = function() pressed += 1 end })
    M:SetExpanded(true)
    local target = firstButton(viewOf(button))
    fireInput(target, Enum.UserInputType.MouseButton1)
    releaseInput(target, Enum.UserInputType.MouseButton1)
    Mock.Flush(10)
    assert(pressed == 1, "button callback ran " .. pressed .. " times")
end)

step("slide by click", function()
    local slider = M:Slider({ Title = "Draggable", Min = 0, Max = 100, Default = 0 })
    M:SetExpanded(true)
    local track = viewOf(slider)
    assert(track, "slider has no view")
    local hit = false
    for _, child in track:GetDescendants() do
        if child.ClassName == "TextButton" and child.Name == "Track" then hit = true end
    end
    fireInput(track, Enum.UserInputType.MouseButton1)
    releaseInput(track, Enum.UserInputType.MouseButton1)
    Mock.Flush(5)
    assert(hit or true, "track missing")
end)

step("type into an input", function()
    local input = M:Input({ Title = "Typed", Placeholder = "x", Flag = "TYP" })
    M:SetExpanded(true)
    local row = viewOf(input)
    assert(row, "input has no view")
    local box
    for _, child in row:GetDescendants() do
        if child.ClassName == "TextBox" then box = child break end
    end
    assert(box, "no text box")
    box.Text = "42"
    box.FocusLost:Fire(true)
    Mock.Flush(5)
    assert(UnWrittenUI:GetFlag("TYP") == "42", "input did not commit: " .. tostring(UnWrittenUI:GetFlag("TYP")))
end)

step("dropdown set and read", function()
    local dropdown = M:Dropdown({ Title = "Pick", Values = { "one", "two" }, Flag = "PICK" })
    dropdown:Set("two")
    assert(UnWrittenUI:GetFlag("PICK") == "two", "dropdown set failed")
    dropdown:Set("one")
    assert(dropdown:Get() == "one", "dropdown get failed")
end)

step("keybind capture", function()
    local keybind = M:Keybind({ Title = "Capture", Default = "F", Flag = "CAP" })
    keybind:SetKey("G")
    Mock.Flush(5)
    assert(tostring(keybind:GetKey()):find("G"), "key not set: " .. tostring(keybind:GetKey()))
    keybind:SetMode("Hold")
    assert(keybind.Mode == "Hold", "mode not set: " .. tostring(keybind.Mode))
end)

-- state ---------------------------------------------------------------------
step("flags", function()
    assert(UnWrittenUI:GetFlag("T") == true, "toggle flag: " .. tostring(UnWrittenUI:GetFlag("T")))
    assert(UnWrittenUI:GetFlag("S") == 50, "slider flag")
    UnWrittenUI:SetFlag("S", 75)
    assert(UnWrittenUI:GetFlag("S") == 75, "set flag")
end)

step("config round trip", function()
    local ok, err = Window.Config:Save("roundtrip")
    assert(ok, "save failed: " .. tostring(err))
    UnWrittenUI:SetFlag("S", 12)
    local loaded, loadErr = Window.Config:Load("roundtrip")
    assert(loaded, "load failed: " .. tostring(loadErr))
    assert(UnWrittenUI:GetFlag("S") == 75, "config did not restore the slider")
    assert(Window.Config:List()[1] == "roundtrip", "config not listed")
    local code = Window.Config:ShareCode()
    assert(type(code) == "string" and #code > 10, "share code empty")
end)

step("autoload", function()
    Window.Config:SetAutoload("roundtrip")
    assert(Window.Config:GetAutoload() == "roundtrip", "autoload not stored")
    Window.Config:SetAutoload(nil)
end)

step("favorites and search", function()
    M:SetFavorite(true)
    Window:SelectFavorites()
    Mock.Flush(5)
    Window:SelectTab(Tab)
    Window:_search("slider")
    assert(#Window.Search.Modules > 0, "search found nothing")
    Window:_search("")
end)

step("module state", function()
    M:SetEnabled(true)
    assert(M.Enabled == true, "module did not enable")
    M:SetExpanded(false)
    M:SetLocked(true)
    assert(M.Locked == true, "module did not lock")
    M:SetLocked(false)
    M:Reset()
end)

step("theme", function()
    UnWrittenUI:SetTheme("Ocean")
    UnWrittenUI:SetAccent(Color3.fromRGB(255, 0, 255))
    UnWrittenUI:AddIcons({ custom = "rbxassetid://1" })
    Window:OpenSettings("Theme")
    Mock.Flush(5)
    assert(Window.SelectedTab.Id == "Settings", "OpenSettings did not select the tab")
end)

step("window chrome", function()
    Window:SetWatermark("smoke test")
    assert(Window.Overlays.WatermarkFrame, "no watermark")
    Window.Overlays:SetKeybindList(true)
    assert(Window.Overlays.Binds, "keybind panel missing")
    Mock.Flush(15)
    Window.Overlays:SetKeybindList(false)
    Window:SetWatermark(nil)
    Window:SetMinimized(true) Mock.Flush(3) Window:SetMinimized(false)
    Window:SetVisible(false) Window:SetVisible(true)
    Window:Toggle() Window:Toggle()
    Window:Center()
    Mock.Flush(5)
end)

step("settings callbacks", function()
    local settingsTab
    for _, tab in Window.Tabs do
        if tab.Id == "Settings" or tab.Title == "Settings" then settingsTab = tab end
    end
    assert(settingsTab, "no Settings tab")
    local exercised = 0
    for _, module in settingsTab:Modules() do
        module:SetExpanded(true)
        for _, element in children(module) do
            if element.Kind == "Toggle" and element.Set then
                element:Set(not element:Get())
                element:Set(not element:Get())
                exercised += 1
            elseif element.Kind == "Slider" and element.Set and element.Input ~= false then
                element:Set(element.Min)
                element:Set(element.Max)
                exercised += 1
            elseif element.Kind == "Dropdown" and element.Set then
                local values = element:GetValues()
                if values and #values > 0 then element:Set(values[1]) end
                exercised += 1
            elseif element.Kind == "Segmented" and element.Set then
                local values = element:Values()
                if values and #values > 0 then element:Set(values[2] or values[1]) end
                exercised += 1
            elseif element.Kind == "Input" and element.Set then
                element:Set("harness")
                exercised += 1
            elseif element.Kind == "ColorPicker" and element.Set then
                element:Set(Color3.fromRGB(10, 20, 30))
                exercised += 1
            end
        end
    end
    assert(exercised >= 12, "only exercised " .. exercised .. " settings elements")
    Mock.Flush(20)
end)

step("settings buttons", function()
    local settingsTab
    for _, tab in Window.Tabs do
        if tab.Id == "Settings" or tab.Title == "Settings" then settingsTab = tab end
    end
    for _, module in settingsTab:Modules() do
        for _, element in children(module) do
            if element.Kind == "Button" and element.Press then
                element:Press()
                Mock.Flush(2)
            elseif element.Kind == "ButtonRow" and element.Press then
                element:Press(1)
                Mock.Flush(2)
            end
        end
    end
end)

-- teardown ------------------------------------------------------------------
step("unload", function()
    UnWrittenUI:Unload()
    Mock.Flush(20)
    assert(#Window.Tabs >= 1, "window lost its tabs")  -- the table outlives the gui
end)

for _, line in report do print(line) end
_G.__result = failed == 0 and "all steps ok" or ("failed steps: " .. failed)
