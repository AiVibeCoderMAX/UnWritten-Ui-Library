-- UnWrittenUI v1.0.0 | MIT License | https://github.com/AiVibeCoderMAX/UnWritten-Ui-Library
-- generated from src/ by build/bundle.mjs, do not edit
local __modules, __cache = {}, {}
local function import(name)
    local cached = __cache[name]
    if cached == nil then
        local loader = __modules[name]
        if not loader then error("[UnWrittenUI] missing module " .. tostring(name), 2) end
        cached = loader(import)
        if cached == nil then cached = false end
        __cache[name] = cached
    end
    return cached
end

__modules["Addons/Settings"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Storage = import("Core/Storage")
local Config = import("Core/Config")
local Animation = import("Core/Animation")

-- the built-in Settings tab: theme editor, config manager, keybind list, overlay and behaviour
-- options. Built with the library's own elements so it always matches the current theme.
return function(window)
    local library = window.Library
    local tab = window:Tab({ Title = "Settings", Icon = "settings", Id = "Settings", Columns = 2 })
    local function notify(title, content, kind)
        library:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = 2.5 })
    end

    -- theme ---------------------------------------------------------------------
    local appearance = tab:Module({ Title = "Theme", Icon = "palette", Description = "Presets and colours", Toggle = false, Side = "Left", Opened = true })
    appearance:Dropdown({
        Title = "Preset",
        Values = Theme.Presets.Order,
        Default = Theme.Palette,
        Callback = function(name)
            library:SetTheme(name)
            window:SaveState()
        end,
    })
    for _, token in { "Accent", "Background", "BackgroundAlt", "Text" } do
        appearance:ColorPicker({
            Title = token .. " colour",
            Default = Theme.Current[token],
            Callback = function(color)
                Theme.Set({ [token] = color })
                window:SaveState()
            end,
        })
    end
    local style = tab:Module({ Title = "Style", Icon = "brush", Description = "Shape, fonts and motion", Toggle = false, Side = "Left", Opened = true })
    style:Slider({
        Title = "Corner radius",
        Min = 0, Max = 24, Default = Theme.Current.Radius, Suffix = " px",
        Callback = function(value)
            Theme.Set({ Radius = value, ElementRadius = math.max(2, value - 4) })
            window:SaveState()
        end,
    })
    style:Slider({
        Title = "Animation speed",
        Min = 0, Max = 3, Step = 0.1, Default = Theme.Current.AnimSpeed,
        Format = function(v) return v <= 0 and "off" or (v .. "x") end,
        Callback = function(value)
            Theme.Set({ AnimSpeed = value })
            Animation.Speed = value
            window:SaveState()
        end,
    })
    style:Dropdown({
        Title = "Font",
        Values = (function()
            local out = {}
            for _, pair in Theme.Fonts do table.insert(out, { Title = pair[2], Value = pair[1] }) end
            return out
        end)(),
        Default = Theme.Current.Font,
        Callback = function(value)
            Theme.Set({ Font = value })
            window:SaveState()
        end,
    })
    style:Dropdown({
        Title = "Notification position",
        Values = { "TopLeft", "TopRight", "BottomLeft", "BottomRight" },
        Default = window.Interface.NotifyPosition,
        Callback = function(value)
            window.Interface.NotifyPosition = value
            library.Notification.SetPosition(value)
            window:SaveState()
        end,
    })
    style:Dropdown({
        Title = "Card descriptions",
        Values = { { Title = "Show", Value = true }, { Title = "Hide", Value = false } },
        Default = window.Interface.Descriptions,
        Callback = function(value)
            window.Interface.Descriptions = value
            window:SaveState()
        end,
    })
    style:Slider({
        Title = "Menu scale",
        Min = 50, Max = 125, Step = 5, Default = math.round((window.Interface.Scale or 1) * 100), Suffix = "%",
        Callback = function(value)
            window.Interface.Scale = value / 100
            window:_applyFit()
        end,
    })
    style:Toggle({
        Title = "Auto expand modules",
        Description = "Fold settings out when a module is enabled",
        Default = window.Interface.AutoExpand,
        Callback = function(value)
            window.Interface.AutoExpand = value
            window:SaveState()
        end,
    })

    -- configs -------------------------------------------------------------------
    local configs = tab:Module({ Title = "Configs", Icon = "folder-open", Description = "Save, load and share", Toggle = false, Side = "Right", Opened = true })
    local listHolder = configs:Group({ Title = "Saved configs", Icon = "list", Opened = true })

    local function refreshList()
        -- group children are models with a view; unmount then drop them
        for _, child in table.clone(listHolder.Children) do
            if child._mounts then
                for _, mount in table.clone(child._mounts) do mount:Clean() end
            end
        end
        table.clear(listHolder.Children)
        local names = window.Config:List()
        if #names == 0 then
            listHolder:Label({ Text = "No configs saved yet.", Color = "TextMuted" })
            return
        end
        for _, name in names do
            listHolder:Button({
                Title = name .. (window.Config.Current == name and "  (loaded)" or ""),
                Icon = "file",
                Callback = function()
                    local ok, err = window.Config:Load(name)
                    if ok then
                        notify("Loaded", name, "Success")
                    else
                        notify("Could not load", err, "Error")
                    end
                end,
            })
        end
    end
    refreshList()

    configs:Input({
        Title = "New config",
        Placeholder = "Name",
        Callback = function(text)
            if text == "" then return end
            local ok, err = window.Config:Save(text)
            if ok then
                notify("Saved", err, "Success")
                refreshList()
            else
                notify("Could not save", err, "Error")
            end
        end,
    })
    configs:Buttons({
        { Title = "Save current", Icon = "save", Style = "Primary", Callback = function()
            local name = window.Config.Current or "default"
            local ok, err = window.Config:Save(name)
            notify(ok and "Saved" or "Error", err, ok and "Success" or "Error")
            refreshList()
        end },
        { Title = "Refresh list", Icon = "refresh-cw", Callback = refreshList },
    })
    configs:Toggle({
        Title = "Auto save",
        Description = "Write changes into the loaded config",
        Default = window.Config.AutoSave,
        Callback = function(value)
            window.Config.AutoSave = value
            window.Interface.AutoSave = value
            window:SaveState()
        end,
    })
    configs:Toggle({
        Title = "Autoload",
        Description = "Load " .. (window.Config:GetAutoload() or "no config") .. " on start",
        Default = window.Config:GetAutoload() ~= nil,
        Callback = function(value)
            window.Config:SetAutoload(value and (window.Config.Current or window.Config:List()[1]) or nil)
        end,
    })
    local shareBox
    configs:Button({
        Title = "Copy share code",
        Icon = "share-2",
        Callback = function()
            local code = window.Config:ShareCode()
            if not code then
                notify("Nothing to share", "Save a config first", "Warning")
                return
            end
            if setclipboard then pcall(setclipboard, code) end
            if shareBox then shareBox:SetContent(code) end
            notify("Copied", "Paste it where you want to share", "Success")
        end,
    })
    shareBox = configs:Paragraph({ Title = "Share", Content = "Saves a config to the clipboard as json." })
    configs:Input({
        Title = "Import config",
        Placeholder = "Paste json",
        Multiline = true,
        Height = 60,
        Callback = function(text)
            local ok, err = window.Config:Import(text)
            notify(ok and "Imported" or "Could not import", err or "Done", ok and "Success" or "Error")
            refreshList()
        end,
    })
    -- overlays -------------------------------------------------------------
    local overlays = tab:Module({ Title = "Overlays", Icon = "layers", Description = "Keybinds, watermark and alerts", Toggle = false, Side = "Right", Opened = true })
    overlays:Toggle({
        Title = "Keybind list",
        Description = "A panel with every bind in the window",
        Default = window.Interface.KeybindList == true,
        Callback = function(value)
            window.Overlays:SetKeybindList(value)
            window:SaveState()
            if value then notify("Keybinds", "Use the panel's grip to move it", "Info") end
        end,
    })
    overlays:Input({
        Title = "Watermark",
        Description = "Leave empty to hide it",
        Placeholder = "e.g. my script v1.2",
        Default = type(window.Interface.Watermark) == "string" and window.Interface.Watermark or "",
        Callback = function(text)
            text = text:match("^%s*(.-)%s*$")
            window:SetWatermark(text ~= "" and text or nil)
            window:SaveState()
        end,
    })
    overlays:Dropdown({
        Title = "Toggle alerts",
        Description = "A toast when the menu opens or closes",
        Values = { { Title = "Always", Value = "Always" }, { Title = "Keybind only", Value = "Keybind" }, { Title = "Never", Value = "Never" } },
        Default = window.Interface.ToggleAlerts or "Always",
        Callback = function(value)
            window.Interface.ToggleAlerts = value
            window:SaveState()
        end,
    })

    -- keybinds -------------------------------------------------------------
    local keybinds = tab:Module({ Title = "Keybinds", Icon = "keyboard", Description = "Rebind and repair", Toggle = false, Side = "Left", Opened = true })
    keybinds:Button({
        Title = "Menu key",
        Icon = "command",
        Callback = function()
            -- Capture flips the pill into listening mode; the bind fires Changed when a key lands
            window.MenuBinding:Capture()
            notify("Menu key", "Press any key, Escape cancels", "Info")
        end,
    })
    keybinds:Slider({
        Title = "Combo keys",
        Description = "How many keys a combo may hold",
        Min = 1, Max = 4, Step = 1, Input = false,
        Default = window.Interface.BindComboKeys or 3,
        Callback = function(value)
            window.Interface.BindComboKeys = value
            window:_applyBindOptions()
            window:SaveState()
        end,
    })
    keybinds:Dropdown({
        Title = "Click while capturing",
        Values = { { Title = "Keep the old key", Value = "Keep" }, { Title = "Clear the bind", Value = "Clear" } },
        Default = window.Interface.BindClickOutside or "Keep",
        Callback = function(value)
            window.Interface.BindClickOutside = value
            window:_applyBindOptions()
            window:SaveState()
        end,
    })
    keybinds:Dropdown({
        Title = "Escape while capturing",
        Values = { { Title = "Keep the old key", Value = "Keep" }, { Title = "Clear the bind", Value = "Clear" } },
        Default = window.Interface.BindEscape or "Keep",
        Callback = function(value)
            window.Interface.BindEscape = value
            window:_applyBindOptions()
            window:SaveState()
        end,
    })
    keybinds:Toggle({
        Title = "Mouse buttons",
        Description = "Allow side buttons as binds",
        Default = window.Interface.BindMouse ~= false,
        Callback = function(value)
            window.Interface.BindMouse = value
            window:_applyBindOptions()
            window:SaveState()
        end,
    })
    keybinds:Button({
        Title = "Clear every bind",
        Icon = "trash-2",
        Style = "Secondary",
        Confirm = true,
        Callback = function()
            for _, owner in table.clone(window._binds) do
                if owner.Binding and owner.Binding.SetKey then owner.Binding:SetKey(nil) end
            end
            window.MenuBinding:SetKey(nil)
            window.Overlays:RefreshBinds()
            notify("Cleared", "All binds removed", "Warning")
        end,
    })

    local profile = tab:Module({ Title = "Profile", Icon = "user", Description = "The card at the bottom left", Toggle = false, Side = "Right", Opened = true })
    profile:Toggle({
        Title = "Show profile card",
        Default = window.Interface.ShowUser ~= false,
        Callback = function(value)
            window.Interface.ShowUser = value
            window.UserFrame.Visible = value
            window:SaveState()
        end,
    })
    profile:Toggle({
        Title = "Hide name (streamer mode)",
        Default = window.Interface.HideUser == true,
        Callback = function(value)
            window.Interface.HideUser = value
            window:SetUser(window.Def.User)
            window:SaveState()
        end,
    })
    profile:Toggle({
        Title = "Hide avatar",
        Default = window.Interface.HideAvatar == true,
        Callback = function(value)
            window.Interface.HideAvatar = value
            window.Avatar.Visible = not value
            window:SaveState()
        end,
    })

    return tab
end
end

__modules["Components/Acrylic"] = function(...)
local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")

-- background blur with a BlurEffect in Lighting; on a quality level that hides it, the window
-- simply turns transparent instead of failing
local Acrylic = {
    On = false,
    Strength = 14,
}

local blur
local saved = {}

function Acrylic.Set(on, strength)
    if strength then Acrylic.Strength = strength end
    Acrylic.On = on and true or false
    if Acrylic.On then
        if not blur or not blur.Parent then
            blur = Instance.new("BlurEffect")
            blur.Name = "UnWrittenUIBlur"
            blur.Size = Acrylic.Strength
            blur.Parent = Services.Lighting
        end
        if blur then
            blur.Size = Acrylic.Strength
            blur.Enabled = true
        end
    else
        if blur then
            pcall(function() blur:Destroy() end)
            blur = nil
        end
    end
    return Acrylic.On
end

function Acrylic.Destroy()
    Acrylic.Set(false)
end

return Acrylic
end

__modules["Components/Container"] = function(...)
local import = ...
local Maid = import("Core/Maid")
local Util = import("Core/Util")

-- mixin for anything that holds elements (modules, sections, groups, panels, tabs): adds
-- Toggle / Slider / Dropdown / ... and the AddToggle style aliases, normalizes flags-first calls
local Container = {}
Container.Kinds = {
    Toggle = { "Toggle" },
    Checkbox = { "Toggle", { Style = "Checkbox" } },
    Button = { "Button" },
    Buttons = { "ButtonRow" },
    ButtonRow = { "ButtonRow" },
    Slider = { "Slider" },
    Range = { "RangeSlider" },
    RangeSlider = { "RangeSlider" },
    Dropdown = { "Dropdown" },
    Input = { "Input" },
    Textbox = { "Input" },
    TextBox = { "Input" },
    Keybind = { "Keybind" },
    ColorPicker = { "ColorPicker" },
    Colorpicker = { "ColorPicker" },
    Label = { "Label" },
    Paragraph = { "Paragraph" },
    Divider = { "Divider" },
    Separator = { "Divider" },
    Spacer = { "Spacer" },
    Space = { "Spacer" },
    ProgressBar = { "ProgressBar" },
    Progress = { "ProgressBar" },
    Segmented = { "Segmented" },
    Tabs = { "Segmented" },
    Group = { "Group" },
    Image = { "Image" },
    Code = { "Code" },
    Log = { "Log" },
    Section = { "Group" },
}

function Container.Setup(self)
    self.Children = {}
    self._views = {}
end

-- accepts (def), (flag, def) or (text) for labels and dividers
local function normalize(a, b)
    if type(a) == "string" then
        if type(b) == "table" then
            b.Flag = b.Flag or a
            return b
        end
        return { Title = a, Text = a }
    end
    return a or {}
end
Container.Normalize = normalize

function Container:_add(kind, a, b)
    local spec = Container.Kinds[kind]
    local def = normalize(a, b)
    if spec[2] then
        for key, value in spec[2] do
            if def[key] == nil then def[key] = value end
        end
    end
    local class = import("Elements/" .. spec[1])
    local element = class.new(self, def)
    table.insert(self.Children, element)
    for _, view in self._views do
        element:Mount(view.Frame, view.Maid, #self.Children)
    end
    if self.Window then self.Window:_emit("Element", element) end
    return element
end

for name in Container.Kinds do
    Container[name] = function(self, a, b) return self:_add(name, a, b) end
    Container["Add" .. name] = Container[name]
end

-- renders every child into frame and keeps it in sync with later additions
function Container:_mountChildren(frame, maid)
    local view = { Frame = frame, Maid = maid }
    for index, child in self.Children do
        child:Mount(frame, maid, index)
    end
    table.insert(self._views, view)
    maid:Give(function()
        local index = table.find(self._views, view)
        if index then table.remove(self._views, index) end
    end)
    return view
end

function Container:_matchesChildren(query)
    for _, child in self.Children do
        if child:Matches(query) then return true end
    end
    return false
end

function Container:_eachElement(fn)
    for _, child in self.Children do
        fn(child)
        if child._eachElement then child:_eachElement(fn) end
    end
end

-- every element with a flag in this container and its groups
function Container:Elements()
    local out = {}
    self:_eachElement(function(element)
        if element.Flag then table.insert(out, element) end
    end)
    return out
end

function Container:SetVisible(visible)
    self.Visible = visible and true or false
    self.StateChanged:Fire("Visible")
end

Container.Maid = Maid

function Container.Apply(target)
    for key, value in Container do
        if type(value) == "function" and key ~= "Apply" and key ~= "Setup" and key ~= "Normalize" then
            target[key] = value
        end
    end
    target.Kinds = Container.Kinds
end

return Container
end

__modules["Components/Dialog"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")

-- modal dialog: a dimmed backdrop, a card with an optional input and any number of buttons.
-- A callback that returns false keeps the dialog open.
local Dialog = {}

local function build(window, def)
    local overlay = Util.New("Frame", {
        Name = "Dialog",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 200,
        Parent = Layer.Overlay,
    })
    local card = Util.New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(def.Width or 320, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 201,
        Theme = {
            BackgroundColor3 = "Elevated",
            BackgroundTransparency = function(t) return math.max(0, t.ElevatedTransparency - 0.1) end,
        },
        Parent = overlay,
    })
    Util.Corner("Radius", card)
    Util.Stroke(card, "Stroke", function(t) return math.max(0, t.StrokeTransparency - 0.2) end)
    local scale = Util.New("UIScale", { Scale = 0.94, Parent = card })
    Util.Padding(card, 16, 16, 14, 16)

    local content = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 202,
        Parent = card,
    })
    local list = Util.List(content, 8)
    Animation.Tween(overlay, "Fade", { BackgroundTransparency = 0.35 })
    Animation.Tween(scale, "Pop", { Scale = 1 })

    local y = 0
    if def.Icon then
        Util.Icon(def.Icon, {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.fromOffset(0, 1),
            Color = "Accent",
            ZIndex = 203,
            Parent = content,
        })
    end
    Util.Label({
        Text = def.Title or "Dialog",
        TextSize = 15,
        Weight = Enum.FontWeight.Bold,
        Position = UDim2.fromOffset(def.Icon and 26 or 0, 0),
        Size = UDim2.new(1, def.Icon and -26 or 0, 0, 20),
        ZIndex = 203,
        Parent = content,
    })
    local info = Util.Label({
        Text = def.Content or "",
        TextSize = 12,
        TextWrapped = true,
        Position = UDim2.fromOffset(0, 26),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Color = "TextDim",
        Visible = def.Content ~= nil and def.Content ~= "",
        ZIndex = 203,
        Parent = content,
    })
    local inputBox = nil
    if def.Input then
        local holder = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, def.Input.Multiline and (def.Input.Height or 80) or 30),
            Position = UDim2.fromOffset(0, (def.Content and 26 + info.TextBounds.Y + 10 or 34)),
            Theme = { BackgroundColor3 = "Surface", BackgroundTransparency = 0.2 },
            ZIndex = 203,
            Parent = content,
        })
        Util.Corner("ElementRadius", holder)
        Util.Stroke(holder, "Stroke", function(t) return 0.6 end)
        inputBox = Util.New("TextBox", {
            Size = def.Input.Multiline and UDim2.new(1, -16, 0, def.Input.Height or 80) or UDim2.new(1, -16, 1, 0),
            Position = UDim2.fromOffset(8, def.Input.Multiline and 8 or 0),
            Text = def.Input.Default or "",
            PlaceholderText = def.Input.Placeholder or "",
            TextSize = 12,
            MultiLine = def.Input.Multiline == true,
            TextWrapped = def.Input.Multiline == true,
            TextYAlignment = def.Input.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
            Theme = { TextColor3 = "Text", PlaceholderColor3 = "TextMuted" },
            ZIndex = 204,
            Parent = holder,
        })
        task.defer(function()
            if inputBox.Parent then pcall(function() inputBox:CaptureFocus() end) end
        end)
    end
    local errorLabel = Util.Label({
        Text = "",
        TextSize = 11,
        Position = UDim2.fromOffset(0, (def.Content and 26 + info.TextBounds.Y + 10 or 34) + (def.Input and (def.Input.Height or 80) + (def.Input.Multiline and 12 or 36) or 0)),
        Size = UDim2.new(1, 0, 0, 14),
        Color = "Danger",
        Visible = false,
        ZIndex = 203,
        Parent = content,
    })

    local buttons = Util.New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.fromOffset(0, 12 + (y)),
        ZIndex = 203,
        Parent = card,
    })
    Util.List(buttons, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)

    local dialog = { IsOpen = true }

    local function close()
        if not dialog.IsOpen then return end
        dialog.IsOpen = false
        local speed = math.max(Animation.Speed, 1)
        Animation.Tween(overlay, "Fade", { BackgroundTransparency = 1 })
        Animation.Tween(scale, "Press", { Scale = 0.94 })
        task.delay((Animation.Curve.Press.Time / speed) + 0.02, function() overlay:Destroy() end)
    end
    dialog.Close = close

    function dialog:SetError(text)
        errorLabel.Text = text or ""
        errorLabel.Visible = text ~= nil and text ~= ""
    end

    local function pressStyle(style)
        if style == "Primary" then return "Accent", "OnAccent" end
        if style == "Danger" then return "Danger", "OnAccent" end
        if style == "Secondary" then return "ElevatedHover", "Text" end
        return "SurfaceHover", "TextDim"
    end

    for index, button in def.Buttons or { { Title = "OK", Style = "Primary" } } do
        local bg, fg = pressStyle(button.Style)
        local hover = { on = false }
        local element = Util.New("TextButton", {
            Text = "",
            Size = UDim2.fromOffset(0, 30),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = index,
            Theme = {
                BackgroundColor3 = bg,
                BackgroundTransparency = function()
                    if button.Style == "Primary" or button.Style == "Danger" then
                        return hover.on and 0 or 0.1
                    end
                    return hover.on and 0.2 or 0.45
                end,
            },
            ZIndex = 204,
            Parent = buttons,
        })
        Util.Corner("ElementRadius", element)
        Util.Padding(element, 0, 16, 0, 16)
        Util.Label({
            Text = button.Title or "OK",
            TextSize = 12,
            Weight = Enum.FontWeight.SemiBold,
            Size = UDim2.fromScale(0, 1),
            AutomaticSize = Enum.AutomaticSize.X,
            Color = fg,
            ZIndex = 204,
            Parent = element,
        })
        Util.Hover(element, function(on)
            hover.on = on
            Theme.Refresh(element, 0.12)
        end)
        Router.Attach(element, {
            OnClick = function()
                local value = inputBox and inputBox.Text or nil
                if button.Callback then
                    local ok, result = pcall(button.Callback, value, dialog)
                    if not ok then
                        warn("[UnWrittenUI] dialog: " .. tostring(result))
                    elseif result == false then
                        return
                    end
                end
                close()
            end,
        })
    end

    if inputBox then
        inputBox.FocusLost:Connect(function(enter)
            if enter then
                -- Enter presses the last button, the usual primary action
                local last = def.Buttons and def.Buttons[#def.Buttons]
                if last and last.Callback then
                    local ok, result = pcall(last.Callback, inputBox.Text, dialog)
                    if ok and result ~= false then close() end
                else
                    close()
                end
            end
        end)
    end
    local function escape(input, processed)
        if processed or not dialog.IsOpen then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            close()
        end
    end
    local connection = import("Core/Services").UserInputService.InputBegan:Connect(escape)
    dialog.Connection = connection
    -- destroy the key connection with the dialog
    overlay.Destroying:Connect(function() connection:Disconnect() end)
    overlay.AncestryChanged:Connect(function()
        if not overlay.Parent then connection:Disconnect() end
    end)
    return dialog
end

function Dialog.Show(window, def)
    return build(window, def or {})
end

return Dialog
end

__modules["Components/Layer"] = function(...)
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
end

__modules["Components/Module"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Signal = import("Core/Signal")
local Animation = import("Core/Animation")
local Router = import("Core/Router")
local Container = import("Components/Container")
local Widgets = import("Components/Widgets")
local Binding = import("Core/Binding")

-- module card: icon, title, description, key pill and switch in the header; the settings fold out
-- below with an animated height. Everything the card can do is also in its right-click menu.
local Module = {}
Module.__index = Module
Container.Apply(Module)

local HEADER = 46

function Module.new(parent, def, view)
    local self = setmetatable({}, Module)
    Container.Setup(self)
    local window = parent.Window
    self.Kind = "Module"
    self.Parent = parent
    self.Tab = parent.Tab or parent
    self.Window = window
    self.Module = self
    self.View = view
    self.Def = def
    self.Title = def.Title or def.Name or "Module"
    self.Description = def.Description or def.Desc
    self.Icon = def.Icon
    self.Flag = def.Flag
    self.Id = def.Id or def.Flag or ((parent.Id or "tab") .. "/" .. self.Title)
    self.Toggleable = def.Toggle ~= false
    self.Enabled = self.Toggleable and def.Default == true
    self.Default = self.Enabled
    self.Locked = def.Locked == true
    self.LockReason = def.LockedReason
    self.Visible = def.Visible ~= false
    self.NoSave = def.Flag == nil
    self.Changed = Signal.new()
    self.StateChanged = Signal.new()
    self._listeners = {}
    self.Favorite = window.State.Favorites[self.Id] == true
    local notify = window.State.Notify[self.Id]
    if notify == nil then notify = def.Notify == true end
    self.Notify = self.Toggleable and notify
    if def.Opened ~= nil then
        self.Expanded = def.Opened == true
    else
        self.Expanded = not self.Toggleable or (self.Enabled and window.Interface.AutoExpand)
    end

    if self.Toggleable and def.Keybind ~= false then
        local spec = type(def.Keybind) == "table" and def.Keybind or { Key = def.Keybind ~= true and def.Keybind or def.Key }
        self.Binding = Binding.new({
            Key = spec.Key or spec.Default,
            Mode = spec.Mode,
            Modes = spec.Modes or { "Toggle", "Hold" },
            Capture = spec,
            Press = function(binding)
                if self.Locked then return end
                if binding.Mode == "Hold" then
                    self:SetEnabled(true)
                else
                    self:SetEnabled(not self.Enabled)
                end
            end,
            Release = function(binding)
                if binding.Mode == "Hold" and not self.Locked then self:SetEnabled(false) end
            end,
        })
        window:_trackBind(self)
    end

    if self.Flag then
        window.Config:Register(self.Flag, self)
        window.Library.Flags[self.Flag] = self
    end

    if self.Toggleable and def.Color then
        local spec = table.clone(def.Color)
        spec.Title = spec.Title or (self.Title .. " colour")
        spec.Flag = spec.Flag or (self.Flag and (self.Flag .. "Color"))
        spec.NoRow = true
        self.Color = import("Elements/ColorPicker").new(self, spec)
    end
    return self
end

-- state ------------------------------------------------------------------------

function Module:SetEnabled(enabled, silent)
    if not self.Toggleable then return end
    enabled = enabled and true or false
    if enabled == self.Enabled then return end
    self.Enabled = enabled
    self.Changed:Fire(enabled)
    if not silent then
        Util.Safe(self.Def.Callback, enabled)
        for _, fn in self._listeners do Util.Safe(fn, enabled) end
        if self.Notify then self.Window:_toggleNote(self, enabled) end
    end
    if self.Window.Interface.AutoExpand and #self.Children > 0 and self._header then
        self:SetExpanded(enabled)
    end
    self.StateChanged:Fire("Enabled")
    self.Window:_touch(true)
    self.Window:_checkDependents(self)
end

function Module:ToggleEnabled()
    self:SetEnabled(not self.Enabled)
end

function Module:Get()
    return self.Enabled
end

function Module:Set(value, silent)
    self:SetEnabled(value, silent)
end

function Module:OnChanged(fn)
    table.insert(self._listeners, fn)
    return self
end

function Module:SetExpanded(expanded)
    expanded = expanded and true or false
    if expanded == self.Expanded then return end
    self.Expanded = expanded
    self.StateChanged:Fire("Expanded")
end

function Module:SetFavorite(favorite)
    self.Window:_setFavorite(self, favorite and true or false)
end

function Module:SetNotify(on)
    if self.Toggleable then self.Window:_setNotify(self, on and true or false) end
end

function Module:SetTitle(text)
    self.Title = text
    self.StateChanged:Fire("Title")
end

function Module:SetDescription(text)
    self.Description = text
    self.StateChanged:Fire("Description")
end

function Module:SetLocked(locked, reason)
    self.Locked = locked and true or false
    self.LockReason = reason or self.LockReason
    self.StateChanged:Fire("Locked")
end

function Module:SetVisible(visible)
    self.Visible = visible and true or false
    self.StateChanged:Fire("Visible")
end

function Module:Matches(query)
    local text = (self.Title .. " " .. (self.Description or "")):lower()
    return text:find(query, 1, true) ~= nil or self:_matchesChildren(query)
end

function Module:Reset()
    self:SetEnabled(self.Default)
    if self.Color then self.Color:Reset() end
    self:_eachElement(function(element)
        if element.Reset then pcall(element.Reset, element) end
    end)
end

function Module:BindInfo()
    return self.Title, self.Enabled
end

function Module:Save()
    return { Enabled = self.Enabled, Bind = self.Binding and self.Binding:Save() or nil }
end

function Module:Load(data)
    if type(data) == "boolean" then
        self:SetEnabled(data, true)
    elseif type(data) == "table" then
        if self.Binding and data.Bind then self.Binding:Load(data.Bind) end
        if data.Enabled ~= nil then self:SetEnabled(data.Enabled, true) end
    end
end

function Module:Destroy()
    for _, child in table.clone(self.Children) do child:Destroy() end
    if self.Color then self.Color:Destroy() end
    if self.Binding then self.Binding:Destroy() end
    if self.Flag and self.Window.Config then self.Window.Config:Unregister(self.Flag, self) end
    if self.Parent and self.Parent.Modules then
        local index = table.find(self.Parent.Modules, self)
        if index then table.remove(self.Parent.Modules, index) end
    end
    self.Changed:Destroy()
    self.StateChanged:Destroy()
    if self.Card then self.Card:Destroy() end
end

function Module:_showDescription()
    return self.Description ~= nil and self.Description ~= "" and self.Window.Interface.Descriptions ~= false
end

-- context menu ---------------------------------------------------------------

function Module:_menu(point)
    local window = self.Window
    local items = {}
    if self.Toggleable then
        table.insert(items, { Title = self.Enabled and "Disable" or "Enable", Icon = "power", Disabled = self.Locked, Callback = function() self:ToggleEnabled() end })
    end
    if self.Tab and self.Tab.FavoritesAllowed then
        table.insert(items, { Title = self.Favorite and "Remove favorite" or "Add to favorites", Icon = "star", Callback = function() self:SetFavorite(not self.Favorite) end })
    end
    if self.Toggleable then
        table.insert(items, { Title = self.Notify and "Mute on / off" or "Notify on / off", Icon = self.Notify and "bell-off" or "bell", Callback = function() self:SetNotify(not self.Notify) end })
    end
    if #self.Children > 0 then
        table.insert(items, { Title = self.Expanded and "Collapse" or "Expand", Icon = "chevrons-up-down", Callback = function() self:SetExpanded(not self.Expanded) end })
    end
    if self.Binding then
        table.insert(items, "-")
        table.insert(items, { Title = "Bind key", Icon = "keyboard", Hint = Util.KeyLabel(self.Binding.Key), Callback = function() self:_capture() end })
        for _, mode in self.Binding.Modes do
            table.insert(items, { Title = mode, Checked = self.Binding.Mode == mode, Callback = function() self.Binding:SetMode(mode) end })
        end
    end
    table.insert(items, "-")
    table.insert(items, { Title = self.Locked and "Unlock" or "Lock", Icon = self.Locked and "lock-open" or "lock", Callback = function() self:SetLocked(not self.Locked) end })
    table.insert(items, { Title = "Reset settings", Icon = "rotate-ccw", Danger = true, Callback = function() self:Reset() end })
    local Popup = import("Components/Popup")
    Popup.Menu(items, { Point = point, Width = 190 }):Show()
end

function Module:_capture()
    if self.Binding and not self.Locked then self.Binding:Capture() end
end

-- view -----------------------------------------------------------------------

function Module:Render(parent, maid, view)
    view = view or self.View
    local window = self.Window
    local card = Util.New("Frame", {
        Name = "Card",
        Size = UDim2.new(1, 0, 0, HEADER + 6),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local surface = Util.New("Frame", {
        Name = "Surface",
        Size = UDim2.new(1, 0, 0, HEADER),
        ClipsDescendants = true,
        Theme = {
            BackgroundColor3 = "Surface",
            BackgroundTransparency = function() return math.max(0, Theme.Current.SurfaceTransparency - 0.05) end,
        },
        Parent = card,
    })
    Util.Corner("Radius", surface)
    Util.Stroke(surface, function(t) return self.Enabled and t.Accent or t.Stroke end, function(t)
        return self.Enabled and 0.65 or math.max(0.1, t.StrokeTransparency - 0.1)
    end)

    local header = Util.New("TextButton", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER),
        Text = "",
        Theme = { BackgroundColor3 = "SurfaceHover", BackgroundTransparency = 1 },
        Parent = surface,
    })

    local x = 34
    local icon
    if self.Icon then
        icon = Util.Icon(self.Icon, {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(12, 15),
            Color = "TextDim",
            Parent = header,
        })
    end
    local titleX = self.Icon and 36 or 14
    local title = Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.SemiBold,
        Position = UDim2.fromOffset(titleX, self:_showDescription() and 8 or 0),
        Size = UDim2.new(1, -(titleX + 130), self:_showDescription() and 17 or 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })
    local description
    if self:_showDescription() then
        description = Util.Label({
            Text = self.Description,
            TextSize = 11,
            Position = UDim2.fromOffset(titleX, 24),
            Size = UDim2.new(1, -(titleX + 130), 0, 15),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Color = "TextMuted",
            Parent = header,
        })
    end

    -- right side: key pill, switch (or a chevron for sections)
    local pill
    local switch
    local paintTitle
    if self.Toggleable then
        switch = Widgets.Switch(surface)
        switch.Track.Position = UDim2.new(1, -12, 0, 14)
        switch:Set(self.Enabled, false)
        paintTitle = function()
            if self.Locked then
                title.TextColor3 = Theme.Current.TextMuted
            elseif self.Def.Risky then
                title.TextColor3 = Theme.Current.Danger
            else
                title.TextColor3 = Theme.Current.Text
            end
            if icon then icon.ImageColor3 = self.Enabled and Theme.Current.Accent or Theme.Current.TextDim end
        end
    else
        title.TextColor3 = Theme.Current.Text
        local chevron = Util.Icon("chevron-down", {
            Size = UDim2.fromOffset(14, 14),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0, 23),
            Color = "TextMuted",
            Parent = surface,
        })
        self._chevron = chevron
    end

    if self.Toggleable and self.Binding then
        pill = Widgets.KeyPill(surface, window, self.Binding, { Tooltip = "Click to bind, right click for Hold" })
        pill.Button.AnchorPoint = Vector2.new(1, 0)
        pill.Button.Position = UDim2.new(1, -52, 0, 13)
        local function place()
            local width = pill.Button.AbsoluteSize.X
            if width > 0 then
                pill.Button.Position = UDim2.new(1, -52, 0, 13)
            end
        end
        pill.Button:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
    end

    -- the settings fold: a clipped frame that grows to the content height
    local fold = Util.New("Frame", {
        Name = "Fold",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, HEADER),
        ClipsDescendants = true,
        BackgroundTransparency = 1,
        Parent = surface,
    })
    local foldInner = Util.New("Frame", {
        Size = UDim2.new(1, -20, 0, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Parent = fold,
    })
    local foldList = Util.List(foldInner, 4)
    local padding = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundTransparency = 1,
        LayoutOrder = 9999,
        Parent = foldInner,
    })

    local contentHeight = 0
    local function measure()
        contentHeight = foldList.AbsoluteContentSize.Y
    end
    contentHeight = 0
    foldList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        measure()
        if self.Expanded then
            surface.Size = UDim2.new(1, 0, 0, HEADER + contentHeight)
            card.Size = UDim2.new(1, 0, 0, HEADER + contentHeight + 6)
            fold.Size = UDim2.new(1, 0, 0, contentHeight)
        end
    end)

    local function applyExpanded(animate)
        measure()
        local target = self.Expanded and contentHeight or 0
        local time = animate and Animation.Curve.Fold or nil
        if self.Expanded then
            fold.Size = UDim2.new(1, 0, 0, contentHeight)
            if time then
                Animation.Tween(surface, time, { Size = UDim2.new(1, 0, 0, HEADER + target) })
                Animation.Tween(card, time, { Size = UDim2.new(1, 0, 0, HEADER + target + 6) })
            else
                surface.Size = UDim2.new(1, 0, 0, HEADER + target)
                card.Size = UDim2.new(1, 0, 0, HEADER + target + 6)
            end
        else
            if time then
                Animation.Tween(surface, time, { Size = UDim2.new(1, 0, 0, HEADER) })
                Animation.Tween(card, time, { Size = UDim2.new(1, 0, 0, HEADER) })
                task.delay((Animation.Curve.Fold.Time / math.max(Animation.Speed, 1)) + 0.02, function()
                    if surface.Parent and not self.Expanded then
                        fold.Size = UDim2.new(1, 0, 0, 0)
                        card.Size = UDim2.new(1, 0, 0, HEADER)
                    end
                end)
            else
                fold.Size = UDim2.new(1, 0, 0, 0)
                surface.Size = UDim2.new(1, 0, 0, HEADER)
                card.Size = UDim2.new(1, 0, 0, HEADER)
            end
        end
        if self._chevron then
            Animation.Tween(self._chevron, "Hover", { Rotation = self.Expanded and 180 or 0 })
        end
    end

    local function paint(animate)
        if switch then switch:Set(self.Enabled, animate ~= false) end
        if paintTitle then paintTitle() end
    end
    paint(false)
    task.defer(function() applyExpanded(false) end)

    self.Maid = self.Maid or nil
    local connects = {}
    table.insert(connects, self.Changed:Connect(function() paint(true) end))
    table.insert(connects, self.StateChanged:Connect(function(state)
        if state == "Expanded" then
            applyExpanded(true)
        elseif state == "Title" then
            title.Text = self.Title
        elseif state == "Description" then
            if description then description.Text = self.Description or "" end
        elseif state == "Locked" or state == "Enabled" then
            paint(true)
            Theme.Refresh(surface, 0.2)
        elseif state == "Visible" then
            card.Visible = self.Visible
        end
    end))

    -- header interactions
    local clickable = self.Toggleable and not self.Locked
    Router.Attach(header, {
        OnClick = function()
            if self.Locked then
                if self.LockReason then
                    window:Notify({ Title = self.Title, Content = self.LockReason, Type = "Warning" })
                end
                return
            end
            if self.Toggleable then
                self:SetEnabled(not self.Enabled)
            else
                self:SetExpanded(not self.Expanded)
            end
        end,
        OnRightClick = function(point) self:_menu(point) end,
        OnMiddleClick = function() self:_capture() end,
        Tooltip = self.Locked and self.LockReason or nil,
    })
    -- chevron: fold without toggling
    local chevronButton
    if self._chevron then
        chevronButton = Util.New("TextButton", {
            Size = UDim2.fromOffset(24, 24),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -6, 0, 11),
            Text = "",
            BackgroundTransparency = 1,
            Parent = header,
        })
        Router.Attach(chevronButton, {
            OnClick = function() self:SetExpanded(not self.Expanded) end,
            Tooltip = self.Expanded and "Collapse" or "Expand",
        })
    end

    -- mount the elements into the fold
    if self.Color then
        local colorHolder = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = 10000,
            Parent = foldInner,
        })
        Util.Label({
            Text = self.Color.Title,
            TextSize = 12,
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.fromOffset(2, 0),
            Color = "TextDim",
            Parent = colorHolder,
        })
        local swatch = Util.New("TextButton", {
            Size = UDim2.fromOffset(30, 18),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Text = "",
            BackgroundColor3 = self.Color:Get(),
            Theme = { BackgroundColor3 = function() return self.Color:Get() end },
            Parent = colorHolder,
        })
        Util.Corner(5, swatch)
        table.insert(connects, self.Color.Changed:Connect(function(color) swatch.BackgroundColor3 = color end))
    end
    local cardMaid = import("Core/Maid").new()
    cardMaid:Give(function()
        for _, connection in connects do pcall(function() connection:Disconnect() end) end
    end)
    for _, item in { card, surface } do cardMaid:Give(item) end
    -- a mirror card (Favorites, search) renders the source module's elements so both stay in
    -- sync: elements are models, so one model can be drawn in several cards at once
    if self.Source then
        Container._mountChildren(self.Source, foldInner, cardMaid)
    else
        Container._mountChildren(self, foldInner, cardMaid)
    end
    if not self.Card then self.Card = cardMaid end
    self.Views = self.Views or {}
    table.insert(self.Views, { Card = card, Maid = cardMaid })
    return card
end

return Module
end

__modules["Components/Notification"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")
local Signal = import("Core/Signal")

-- toasts stacked in a corner; a toast with an Id that is still on screen is updated in place and
-- its timer restarts. Hovering pauses the timer, buttons can keep it open.
local Notification = {
    Position = "BottomRight",
    Scale = 1,
    Max = 5,
    Active = {},
    Changed = Signal.new(),
}

local TYPES = {
    Info = { Icon = "info", Token = "Info" },
    Success = { Icon = "circle-check", Token = "Success" },
    Warning = { Icon = "triangle-alert", Token = "Warning" },
    Error = { Icon = "circle-x", Token = "Danger" },
}

local holder

function Notification.Setup(window)
    Notification.Window = window
end

function Notification.SetPosition(position)
    Notification.Position = position or "BottomRight"
    Notification.Relayout()
end

local function layer()
    if holder and holder.Parent then
        holder.Parent = Layer.Toast
        return holder
    end
    local frame = Util.New("Frame", {
        Name = "Notifications",
        Size = UDim2.fromOffset(320, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = Layer.Toast,
    })
    local list = Util.List(frame, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() end)
    holder = frame
    Notification.List = list
    Notification.Relayout()
    return holder
end

function Notification.Relayout()
    if not holder then return end
    local position = Notification.Position or "BottomRight"
    local margin = 16
    local anchorX = (position:find("Left")) and 0 or 1
    local anchorY = (position:find("Top")) and 0 or 1
    holder.AnchorPoint = Vector2.new(anchorX, anchorY)
    holder.Position = UDim2.new(anchorX, anchorX == 1 and -margin or margin, anchorY, anchorY == 1 and -margin or margin)
    local list = holder:FindFirstChildOfClass("UIListLayout")
    if list then
        list.VerticalAlignment = anchorY == 1 and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
        list.HorizontalAlignment = anchorX == 1 and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
    end
end

local function closeItem(item)
    if not item or item.Closed then return end
    item.Closed = true
    if item.Timeout then pcall(task.cancel, item.Timeout) end
    local index = table.find(Notification.Active, item)
    if index then table.remove(Notification.Active, index) end
    local speed = math.max(Animation.Speed, 1)
    Animation.Tween(item.Frame, "Press", { Position = item.Frame.Position + UDim2.fromOffset(item.AnchorX == 1 and 24 or -24, 0) })
    for _, child in item.Frame:GetDescendants() do
        if child:IsA("GuiObject") then
            Animation.Tween(child, "Fade", { BackgroundTransparency = 1 })
        end
        if child:IsA("TextLabel") or child:IsA("ImageLabel") or child:IsA("TextBox") then
            Animation.Tween(child, "Fade", { TextTransparency = 1, ImageTransparency = 1 })
        end
    end
    task.delay((Animation.Curve.Press.Time / speed) + 0.02, function()
        if item.Frame then item.Frame:Destroy() end
        Notification.Changed:Fire()
    end)
end

-- options: Title, Content, Type (Info / Success / Warning / Error), Icon, Color, Duration,
--          Id, Buttons = { { Title, Style, Callback, KeepOpen } }
function Notification.Show(options)
    options = options or {}
    options.Title = options.Title or "Notification"
    options.Type = TYPES[options.Type] and options.Type or "Info"
    options.Duration = (tonumber(options.Duration) or 4) * (Notification.Scale or 1)
    local parent = layer()
    local anchorX = (Notification.Position:find("Left")) and 0 or 1

    -- the same Id while the old toast is alive updates it
    local existing
    if options.Id ~= nil then
        for _, item in Notification.Active do
            if item.Id == options.Id then existing = item break end
        end
    end

    local item
    if existing then
        item = existing
        item.Title.Text = options.Title
        item.Content.Text = options.Content or ""
        item.Content.Visible = options.Content ~= nil and options.Content ~= ""
        item.Accent.BackgroundColor3 = options.Color or Theme.Current[TYPES[options.Type].Token] or Theme.Current.Accent
        item.Icon.ImageColor3 = item.Accent.BackgroundColor3
        Animation.Flash(item.Frame, "BackgroundTransparency", 0.02, Theme.Current.ElevatedTransparency, "Fade")
    else
        local typeInfo = TYPES[options.Type]
        local frame = Util.New("Frame", {
            Name = "Notification",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ClipsDescendants = true,
            Theme = {
                BackgroundColor3 = "Elevated",
                BackgroundTransparency = function(t) return math.max(0, t.ElevatedTransparency - 0.05) end,
            },
            Parent = parent,
        })
        Util.Corner("Radius", frame)
        Util.Stroke(frame, "Stroke", function(t) return math.max(0, t.StrokeTransparency - 0.2) end)
        local accent = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = options.Color or Theme.Current[typeInfo.Token],
            Parent = frame,
        })
        local scale = Util.New("UIScale", { Scale = Notification.Scale or 1, Parent = frame })
        local inner = Util.New("Frame", {
            Size = UDim2.new(1, -20, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.fromOffset(14, 12),
            BackgroundTransparency = 1,
            Parent = frame,
        })
        local icon = Util.Icon(options.Icon or typeInfo.Icon, {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(0, 1),
            ImageColor3 = options.Color or Theme.Current[typeInfo.Token],
            Parent = inner,
        })
        local title = Util.Label({
            Text = options.Title,
            TextSize = 13,
            Weight = Enum.FontWeight.SemiBold,
            Position = UDim2.fromOffset(24, 0),
            Size = UDim2.new(1, -56, 0, 17),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = inner,
        })
        local content = Util.Label({
            Text = options.Content or "",
            TextSize = 11,
            TextWrapped = true,
            Position = UDim2.fromOffset(24, 18),
            Size = UDim2.new(1, -56, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Color = "TextDim",
            Visible = options.Content ~= nil and options.Content ~= "",
            Parent = inner,
        })
        local closeButton = Util.New("TextButton", {
            Size = UDim2.fromOffset(20, 20),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 8),
            Text = "",
            BackgroundTransparency = 1,
            Parent = frame,
        })
        Util.Icon("x", { Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Color = "TextMuted", Parent = closeButton })
        item = {
            Frame = frame,
            Title = title,
            Content = content,
            Accent = accent,
            Icon = icon,
            Inner = inner,
            Id = options.Id,
            AnchorX = anchorX,
            Closed = false,
        }
        Router.Attach(closeButton, { OnClick = function() closeItem(item) end })
        -- starting position: offset toward the screen edge, then slide in
        frame.Position = UDim2.fromOffset(anchorX == 1 and 40 or -40, 0)
        Animation.Tween(frame, "Slide", { Position = UDim2.fromOffset(0, 0) })
        if scale then
            scale.Scale = 0.9
            Animation.Tween(scale, "Pop", { Scale = Notification.Scale or 1 })
        end
        table.insert(Notification.Active, item)
        -- buttons
        local buttons = options.Buttons
        if buttons and #buttons > 0 then
            local row = Util.New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -24, 0, 26),
                Position = UDim2.fromOffset(24, content.AbsoluteSize.Y + 22),
                Parent = inner,
            })
            Util.List(row, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
            for index, button in buttons do
                local hover = { on = false }
                local element = Util.New("TextButton", {
                    Text = "",
                    Size = UDim2.fromOffset(0, 24),
                    AutomaticSize = Enum.AutomaticSize.X,
                    LayoutOrder = index,
                    Theme = {
                        BackgroundColor3 = button.Style == "Danger" and "Danger" or "ElevatedHover",
                        BackgroundTransparency = function() return hover.on and 0.1 or 0.4 end,
                    },
                    Parent = row,
                })
                Util.Corner(6, element)
                Util.Padding(element, 0, 10, 0, 10)
                Util.Label({
                    Text = button.Title or "OK",
                    TextSize = 11,
                    Weight = Enum.FontWeight.Medium,
                    Size = UDim2.fromScale(0, 1),
                    AutomaticSize = Enum.AutomaticSize.X,
                    Color = button.Style == "Danger" and "OnAccent" or "Text",
                    Parent = element,
                })
                Util.Hover(element, function(on) hover.on = on Theme.Refresh(element, 0.1) end)
                Router.Attach(element, {
                    OnClick = function()
                        if button.Callback then Util.Defer(button.Callback) end
                        if not button.KeepOpen then closeItem(item) end
                    end,
                })
            end
        end
    end

    -- timer with pause on hover
    local remaining = options.Duration
    if item.Timeout then pcall(task.cancel, item.Timeout) end
    local function startTimer()
        if remaining and remaining > 0 then
            item.Timeout = task.delay(remaining, function()
                if not item.Closed then closeItem(item) end
            end)
        end
    end
    item.Remaining = remaining
    startTimer()
    Util.Hover(item.Frame, function(on)
        if on then
            if item.Timeout then pcall(task.cancel, item.Timeout) end
            item.Timeout = nil
        else
            startTimer()
        end
    end)

    -- never show more than Max: drop the oldest
    while #Notification.Active > (Notification.Max or 5) do
        closeItem(Notification.Active[1])
    end

    -- the notification's own handle
    local handle = { Current = item }
    function handle:Close()
        closeItem(item)
    end
    function handle:Update(newOptions)
        newOptions = table.clone(newOptions or {})
        newOptions.Id = item.Id
        Notification.Show(newOptions)
    end
    Notification.Changed:Fire()
    return handle
end

return Notification
end

__modules["Components/Overlays"] = function(...)
local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")
local Widgets = import("Components/Widgets")
local Maid = import("Core/Maid")

-- keybind list and watermark: small always-on overlays owned by the window
local Overlays = {}
Overlays.__index = Overlays

function Overlays.new(window)
    local self = setmetatable({
        Window = window,
        Maid = Maid.new(),
        Visible = true,
    }, Overlays)
    return self
end

-- keybind list: every bound key of the window, grouped, sorted, with a panel around it
function Overlays:SetKeybindList(on)
    self.KeybindListOn = on and true or false
    local window = self.Window
    if on then
        if not self.Binds then
            local panel = window:Panel({
                Title = "Keybinds",
                Icon = "keyboard",
                Id = "keybinds",
                Size = Vector2.new(230, 200),
                Hud = true,
                Closable = false,
                Collapsible = true,
                Resizable = false,
            })
            local holder = Util.New("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = panel.Body,
            })
            local list = Util.List(holder, 3)
            self.Binds = { Panel = panel, List = list, Holder = holder }
            self:RefreshBinds()
            panel:Show()
        else
            self.Binds.Panel:Show()
        end
    elseif self.Binds then
        self.Binds.Panel:Hide()
        self.Binds = nil
    end
    window.Interface.KeybindList = self.KeybindListOn
    window:SaveState()
end

function Overlays:RefreshBinds()
    local binds = self.Binds
    if not binds then return end
    for _, child in binds.Holder:GetChildren() do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    local rows = {}
    for _, owner in self.Window._binds do
        if owner.Binding and owner.Binding.Key then
            table.insert(rows, owner)
        end
    end
    if #rows == 0 then
        Util.Label({
            Text = "No binds yet.\nClick a key pill on a card.",
            TextSize = 11,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, 34),
            Color = "TextMuted",
            Parent = binds.Holder,
        })
        return
    end
    table.sort(rows, function(a, b)
        local ta = a.BindInfo and select(1, a:BindInfo()) or tostring(a.Title)
        local tb = b.BindInfo and select(1, b:BindInfo()) or tostring(b.Title)
        return tostring(ta):lower() < tostring(tb):lower()
    end)
    for index = #rows, 1, -1 do
        local item = rows[index]
        local key = item.Binding.Key
        local row = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            LayoutOrder = index,
            Parent = binds.Holder,
        })
        local title = item.BindInfo and select(1, item:BindInfo()) or item.Title
        Util.Label({
            Text = tostring(title),
            TextSize = 11,
            Size = UDim2.new(1, -80, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Color = item.Enabled and "Text" or "TextDim",
            Parent = row,
        })
        local mode = item.Binding.Mode
        Util.Label({
            Text = mode == "Always" and "" or mode,
            TextSize = 9,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -52, 0.5, 0),
            Size = UDim2.new(0, 34, 0, 12),
            TextXAlignment = Enum.TextXAlignment.Right,
            Color = mode == "Hold" and "Warning" or "TextMuted",
            Parent = row,
        })
        Util.Label({
            Text = Util.KeyLabel(key),
            TextSize = 10,
            Weight = Enum.FontWeight.Medium,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 48, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
            Color = item.Enabled and "Accent" or "TextMuted",
            Parent = row,
        })
    end
end

-- watermark: "Title · custom text · fps · ping · time"
function Overlays:SetWatermark(on)
    self.WatermarkOn = on and true or false
    if on and not self.WatermarkFrame then
        local frame = Util.New("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 12),
            Size = UDim2.new(0, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.X,
            Parent = Layer.Hud,
        })
        Util.List(frame, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
        local order = 0
        local function part(size, color, weight)
            order += 1
            return Util.Label({
                Text = "",
                TextSize = size,
                Weight = weight or Enum.FontWeight.Medium,
                Size = UDim2.fromScale(0, 1),
                AutomaticSize = Enum.AutomaticSize.X,
                LayoutOrder = order,
                Color = color or "Text",
                Theme = {
                    TextColor3 = color or "Text",
                    TextStrokeTransparency = 0.4,
                    TextStrokeColor3 = Color3.new(0, 0, 0),
                },
                Parent = frame,
            })
        end
        self.WatermarkFrame = frame
        self.WatermarkTitle = part(12, "Accent", Enum.FontWeight.Bold)
        self.WatermarkText = part(11, "TextDim")
        self.WatermarkFps = part(11, "TextMuted")
        self.WatermarkPing = part(11, "TextMuted")
        self.WatermarkTime = part(11, "TextMuted")
        self.WatermarkTitle.Text = self.Window.Def.Title or "UnWrittenUI"
        -- a real frame counter
        local count, acc = 0, 0
        self.WatermarkConnection = Services.RunService.RenderStepped:Connect(function(dt)
            count += 1
            acc += dt
            if acc >= 0.5 then
                self.WatermarkFps.Text = string.format("%d fps", math.floor(count / acc + 0.5))
                count, acc = 0, 0
            end
        end)
        self.WatermarkTimeConnection = Animation.Loop(0.5, function()
            self.WatermarkTime.Text = os.date("%H:%M:%S")
            local player = Services.Players.LocalPlayer
            if player and player.GetNetworkPing then
                self.WatermarkPing.Text = string.format("%d ms", math.floor(player:GetNetworkPing() * 1000 + 0.5))
            end
        end)
        self.Window.Maid:Give(self.WatermarkConnection)
        self.Window.Maid:Give(self.WatermarkTimeConnection)
    end
    if self.WatermarkFrame then
        self.WatermarkFrame.Visible = self.WatermarkOn
        if on then self:SetWatermarkText(self.Window.Interface.Watermark) end
    end
end

function Overlays:SetWatermarkText(text)
    if not self.WatermarkText then return end
    if type(text) == "string" and text ~= "" then
        self.WatermarkText.Text = "· " .. text
        self.WatermarkText.Visible = true
    else
        self.WatermarkText.Visible = false
    end
end

function Overlays:SetVisible(visible)
    if self.Binds then
        if visible then self.Binds.Panel:Show() else self.Binds.Panel:Hide() end
    end
end

function Overlays:Destroy()
    self.Maid:Clean()
end

return Overlays
end

__modules["Components/Page"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Animation = import("Core/Animation")
local Router = import("Core/Router")
local Container = import("Components/Container")
local Module = import("Components/Module")
local Maid = import("Core/Maid")
local Signal = import("Core/Signal")

-- a scrolling area with one or two independent columns of module cards. Cards can be dragged
-- between columns and repositioned; the order is stored per page id.
local Page = {}
Page.__index = Page
Container.Apply(Page)

function Page.new(window, def)
    local self = setmetatable({}, Page)
    Container.Setup(self)
    self.Kind = "Page"
    self.Window = window
    self.Def = def
    self.Id = def.Id or "page"
    self.Columns = {}
    self.Modules = {}
    self.Visible = false
    self.Changed = Signal.new()
    self.StateChanged = Signal.new()
    self.Maid = Maid.new()
    self.EmptyText = def.Empty or ""
    self:_build(def.Columns or 2)
    if def.Source then
        self._emptyText = def.Empty or ""
        self._empty.Text = self._emptyText
    end
    return self
end

function Page:_build(columns)
    local window = self.Window
    local surface = Util.New("Frame", {
        Name = "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.ParentFrame or window.Body,
    })
    self.Surface = surface
    Util.Padding(surface, 0, 12, 0, 12)
    local scroll = Util.New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.5,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(),
        Theme = { ScrollBarImageColor3 = "Stroke" },
        Parent = surface,
    })
    self.Scroll = scroll
    local list = Util.List(scroll, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
    self.List = list
    Util.AutoCanvas(scroll, list, true)

    for index = 1, columns do
        local column = Util.New("Frame", {
            Name = "Column" .. index,
            Size = UDim2.new(1 / columns, -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = index,
            Parent = scroll,
        })
        local columnList = Util.List(column, 8)
        self.Columns[index] = { Frame = column, List = columnList, Modules = {} }
    end
    self.ColumnCount = columns
    self._empty = Util.Label({
        Text = "",
        TextSize = 12,
        TextWrapped = true,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.4),
        Size = UDim2.fromOffset(300, 60),
        TextXAlignment = Enum.TextXAlignment.Center,
        Color = "TextMuted",
        Visible = false,
        Parent = surface,
    })
    self._emptyText = (self.Def.Empty or "")
    return self
end

-- adds a module card (or a section card) to a column
function Page:Module(def)
    local module = Module.new(self, def, self)
    table.insert(self.Modules, module)
    local side = def.Side == "Right" and self.ColumnCount > 1 and 2 or 1
    if def.Side == "Right" and self.ColumnCount == 1 then side = 1 end
    if def.Side == "Left" then side = 1 end
    local column = self.Columns[side]
    module.ColumnIndex = side
    table.insert(column.Modules, module)
    module.Order = #column.Modules
    if self.Visible and column.Frame.Parent then
        module:Render(column.Frame, self.Maid)
    end
    self:_restoreOrder()
    self.Window:_emit("Module", module)
    return module
end

-- rebuilds the card order inside each column from the saved layout
function Page:_restoreOrder()
    local layout = self.Window.State.Layout[self.Id]
    if type(layout) ~= "table" then return end
    for index, column in self.Columns do
        local order = layout[index]
        if type(order) == "table" then
            local wanted = {}
            for _, id in order do wanted[id] = (#wanted) + 1 end
            table.sort(column.Modules, function(a, b)
                local wa, wb = wanted[a.Id] or 999, wanted[b.Id] or 999
                if wa == wb then return (a.Order or 0) < (b.Order or 0) end
                return wa < wb
            end)
        end
    end
end

function Page:SaveOrder()
    local layout = {}
    for index, column in self.Columns do
        local ids = {}
        for _, module in column.Modules do
            table.insert(ids, module.Id)
            module.ColumnIndex = index
        end
        layout[index] = ids
    end
    self.Window.State.Layout[self.Id] = layout
    self.Window:SaveState()
end

function Page:FirstModule()
    for _, column in self.Columns do
        if #column.Modules > 0 then return column.Modules[1] end
    end
    return nil
end

-- (re)renders every card; the page is built hidden and drawn when first shown so hidden pages
-- never lay out
function Page:Mount(parent)
    if parent and parent ~= self.Surface.Parent then
        self.Surface.Parent = parent
    end
    if self._mounted then return end
    self._mounted = true
    for _, column in self.Columns do
        for _, module in column.Modules do
            module:Render(column.Frame, self.Maid)
        end
    end
end

function Page:SetVisible(visible)
    self.Visible = visible and true or false
    if self.Visible then self:Mount() end
    self.Surface.Visible = self.Visible
    if self.Visible then
        local scale = self.Surface:FindFirstChildOfClass("UIScale")
        if not scale then
            scale = Util.New("UIScale", { Scale = 1, Parent = self.Surface })
        end
        scale.Scale = 0.995
        Animation.Tween(scale, "Fade", { Scale = 1 })
    end
    self.StateChanged:Fire("Visible")
end

function Page:SetColumns(count)
    count = count == 1 and 1 or 2
    if count == self.ColumnCount then return end
    -- gather every card in its visual order, tear the columns down and rebuild them
    local ordered = {}
    for index, column in self.Columns do
        for _, module in column.Modules do table.insert(ordered, module) end
    end
    for _, column in self.Columns do column.Frame:Destroy() end
    self.Columns = {}
    self.ColumnCount = count
    for index = 1, count do
        local column = Util.New("Frame", {
            Name = "Column" .. index,
            Size = UDim2.new(1 / count, -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = index,
            Parent = self.Scroll,
        })
        local columnList = Util.List(column, 8)
        self.Columns[index] = { Frame = column, List = columnList, Modules = {} }
    end
    for _, module in ordered do
        module.Card = nil
        module.ColumnIndex = 1
        local column = self.Columns[1]
        table.insert(column.Modules, module)
        if self._mounted then module:Render(column.Frame, self.Maid) end
    end
    self:_restoreOrder()
end

-- drag and drop: called by the window while a card's grip is dragged
function Page:MoveToOther(module)
    if self.ColumnCount < 2 then return end
    local from = self.Columns[module.ColumnIndex or 1]
    local to = self.Columns[module.ColumnIndex == 1 and 2 or 1]
    if not from or not to then return end
    local index = table.find(from.Modules, module)
    if index then table.remove(from.Modules, index) end
    table.insert(to.Modules, module)
    module.ColumnIndex = module.ColumnIndex == 1 and 2 or 1
    if module.Card then module.Card:Destroy() end
    module.Card = nil
    module:Render(to.Frame, self.Maid)
    self:SaveOrder()
end

function Page:Reorder(module, targetIndex)
    local column = self.Columns[module.ColumnIndex or 1]
    if not column then return end
    local current = table.find(column.Modules, module)
    if not current or current == targetIndex then return end
    table.remove(column.Modules, current)
    table.insert(column.Modules, math.clamp(targetIndex, 1, #column.Modules + 1), module)
    for index, item in column.Modules do
        item.Order = index
        if item.Card then item.Card.Parent.LayoutOrder = index end
    end
    self:SaveOrder()
end

-- Favorites and search reuse this page as a mirror: they show clones of other pages' cards
function Page:Refresh(query)
    if self._refreshOwn then
        self._refreshOwn(query)
        return
    end
    if not self._mirror then return end
    -- tear mirrors down
    for _, module in table.clone(self.Modules) do
        module:Destroy()
    end
    self.Modules = {}
    for _, column in self.Columns do
        for _, module in column.Modules do
            if module.Card then pcall(function() module.Card:Clean() end) end
        end
        column.Modules = {}
    end
    local count = 0
    for _, entry in self._mirror(query) do
        count += 1
        local source = entry.Module
        local card = self:_mirrorCard(source, entry.Label, count)
        if card then
            local side = self.ColumnCount > 1 and (count % 2 == 1 and 1 or 2) or 1
            local column = self.Columns[side]
            table.insert(column.Modules, card)
            card.ColumnIndex = side
            -- mirrors are real modules: keep them in Modules so Elements() and cards are reachable
            card.Source = source
            card.Mirror = true
            table.insert(self.Modules, card)
        end
    end
    self._empty.Visible = count == 0
    self._empty.Text = self._emptyText
end

function Page:_mirrorCard(source, label, order)
    local Module = import("Components/Module")
    local card = Module.new(self, {
        Title = source.Title,
        Description = source.Description,
        Icon = source.Icon,
        Flag = nil,
        Default = source.Enabled,
        Toggle = source.Toggleable,
        Id = source.Id,
        Keybind = false,
        Side = source.ColumnIndex == 2 and "Right" or "Left",
    }, self)
    card.Source = source
    card.Mirror = true
    -- two-way sync
    local connection = source.Changed:Connect(function(enabled)
        if card.Enabled ~= enabled then card:SetEnabled(enabled, true) end
    end)
    card.Changed:Connect(function(enabled)
        if source.Enabled ~= enabled then source:SetEnabled(enabled, true) end
    end)
    self.Window.Maid:Give(connection)
    if label then
        card.Title = source.Title .. "  ·  " .. label
    end
    local target = self.Columns[self.ColumnCount > 1 and (((order or 1) % 2 == 1) and 1 or 2) or 1]
    card:Render(target.Frame, self.Maid)
    return card
end

function Page:SetEmpty(text)
    self._emptyText = text
    if self._empty then self._empty.Text = text end
end

function Page:Matches(query)
    for _, module in self.Modules do
        if module:Matches(query) then return true end
    end
    return false
end

return Page
end

__modules["Components/Panel"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Maid = import("Core/Maid")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Container = import("Components/Container")
local Layer = import("Components/Layer")
local Signal = import("Core/Signal")

-- a floating window that holds elements: draggable, collapsible, resizable, closable. Hud panels
-- stay visible while the menu is hidden and size themselves to their content.
local Panel = {}
Panel.__index = Panel
Container.Apply(Panel)

local HEADER = 36

function Panel.new(window, def)
    local self = setmetatable({}, Panel)
    Container.Setup(self)
    self.Kind = "Panel"
    self.Window = window
    self.Library = window.Library
    self.Def = def
    self.Id = def.Id or def.Title or "panel"
    self.Title = def.Title or "Panel"
    self.Hud = def.Hud == true
    self.Closable = def.Closable ~= false
    self.Collapsible = def.Collapsible ~= false
    self.Resizable = def.Resizable == true
    self.Maid = Maid.new()
    self.Changed = Signal.new()
    self.StateChanged = Signal.new()
    self.Closed = Signal.new()
    self.Visible = false
    self.Collapsed = false
    self.Scale = def.Scale or 1
    self.Transparency = def.Transparency
    self.Size = def.Size or Vector2.new(250, 300)
    local state = window.State.Panels and window.State.Panels[self.Id]
    if type(state) == "table" then
        if type(state.Position) == "table" then def.Position = Vector2.new(state.Position[1], state.Position[2]) end
        if type(state.Size) == "table" then self.Size = Vector2.new(state.Size[1], state.Size[2]) end
        self.Visible = state.Visible == true
    end
    if def.Visible ~= nil then self.Visible = def.Visible == true end
    self:_build()
    return self
end

function Panel:_build()
    local def = self.Def
    local frame = Util.New("Frame", {
        Name = "Panel",
        Size = UDim2.fromOffset(self.Size.X, self.Size.Y),
        Position = UDim2.fromOffset(200, 200),
        Visible = false,
        ClipsDescendants = true,
        Theme = {
            BackgroundColor3 = "Surface",
            BackgroundTransparency = function(t)
                if self.Transparency ~= nil then return self.Transparency end
                return math.max(0, t.SurfaceTransparency - 0.05)
            end,
        },
        Parent = self.Hud and Layer.Hud or Layer.Main,
    })
    Util.Corner("Radius", frame)
    Util.Stroke(frame)
    self.Frame = frame
    self.Maid:Give(frame)
    local scale = Util.New("UIScale", { Scale = self.Scale, Parent = frame })
    self.UIScale = scale

    local header = Util.New("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER),
        BackgroundTransparency = 1,
        Parent = frame,
    })
    Util.Icon(def.Icon or "layers", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(12, 11),
        Color = "Accent",
        Parent = header,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 12,
        Weight = Enum.FontWeight.SemiBold,
        Position = UDim2.fromOffset(34, 0),
        Size = UDim2.new(1, -100, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })
    local actions = Util.New("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = header,
    })
    Util.List(actions, 2, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    local order = 0
    local function headerButton(icon, tip, callback)
        order += 1
        local button = Util.New("TextButton", {
            Size = UDim2.fromOffset(22, 22),
            Text = "",
            LayoutOrder = order,
            BackgroundTransparency = 1,
            Parent = actions,
        })
        Util.Icon(icon, { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Color = "TextDim", Parent = button })
        Router.Attach(button, { OnClick = callback, Tooltip = tip })
        return button
    end
    if self.Collapsible then
        self.CollapseButton = headerButton("chevron-down", "Collapse", function() self:SetCollapsed(not self.Collapsed) end)
    end
    if self.Closable then
        headerButton("x", "Close", function() self:Close() end)
    end

    local body = Util.New("ScrollingFrame", {
        Name = "Body",
        Size = UDim2.new(1, -16, 1, -(HEADER + 8)),
        Position = UDim2.fromOffset(8, HEADER),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Theme = { ScrollBarImageColor3 = "Stroke" },
        Parent = frame,
    })
    self.Body = body
    local list = Util.List(body, 4)
    Util.AutoCanvas(body, list)
    self.BodyList = list

    -- drag by the header, resize from the corner
    local dragging, start, origin
    Router.Attach(header, {
        OnPress = function(_, point)
            dragging = true
            start = point
            origin = frame.Position
            frame.ZIndex = 10
        end,
        OnDrag = function(_, point)
            if not dragging then return end
            local delta = point - start
            frame.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X / self.Scale, origin.Y.Scale, origin.Y.Offset + delta.Y / self.Scale)
        end,
        OnRelease = function()
            dragging = false
            self:_saveState()
        end,
    })
    if self.Resizable then
        local grip = Util.New("Frame", {
            Size = UDim2.fromOffset(14, 14),
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -2, 1, -2),
            BackgroundTransparency = 1,
            Parent = frame,
        })
        local resizing, sizeStart, pointerStart
        Router.Attach(grip, {
            OnPress = function(_, point)
                resizing = true
                sizeStart = frame.AbsoluteSize / self.Scale
                pointerStart = point
            end,
            OnDrag = function(_, point)
                if not resizing then return end
                local delta = (point - pointerStart) / self.Scale
                frame.Size = UDim2.fromOffset(math.max(sizeStart.X + delta.X, 160), math.max(sizeStart.Y + delta.Y, HEADER + 40))
            end,
            OnRelease = function()
                resizing = false
                self:_saveState()
            end,
        })
    end

    -- content can size the panel: Hud panels follow it
    if self.Hud or def.AutoSize then
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if self.Collapsed then return end
            frame.Size = UDim2.fromOffset(self.Size.X, HEADER + list.AbsoluteContentSize.Y + 12)
        end)
    end
    Container._mountChildren(self, body, self.Maid)
    if self.Visible then self:Show() end
end

function Panel:_saveState()
    self.Window.State.Panels = self.Window.State.Panels or {}
    local frame = self.Frame
    self.Size = Vector2.new(frame.AbsoluteSize.X / self.Scale, frame.AbsoluteSize.Y / self.Scale)
    self.Window.State.Panels[self.Id] = {
        Position = { math.round(frame.Position.X.Offset), math.round(frame.Position.Y.Offset) },
        Size = { math.round(self.Size.X), math.round(self.Size.Y) },
        Visible = self.Visible,
    }
    self.Window:SaveState()
end

function Panel:Show()
    self.Visible = true
    if not self.Frame then return end
    self.Frame.Visible = true
    local scale = self.Frame:FindFirstChildOfClass("UIScale")
    if scale then
        scale.Scale = self.Scale * 0.94
        Animation.Tween(scale, "Pop", { Scale = self.Scale })
    end
    self:_saveState()
end

function Panel:Hide()
    self.Visible = false
    if self.Frame then self.Frame.Visible = false end
    self:_saveState()
end

function Panel:ToggleVisible()
    if self.Visible then self:Hide() else self:Show() end
end

function Panel:SetCollapsed(collapsed)
    self.Collapsed = collapsed and true or false
    if not self.Frame then return end
    local bodyList = self.BodyList
    local target = self.Collapsed and HEADER or (self.Hud and (HEADER + bodyList.AbsoluteContentSize.Y + 12) or self.Size.Y)
    Animation.Tween(self.Frame, "Fold", { Size = UDim2.fromOffset(self.Size.X, target) })
    if self.CollapseButton then
        local icon = self.CollapseButton:FindFirstChildOfClass("ImageLabel")
        if icon then Animation.Tween(icon, "Hover", { Rotation = self.Collapsed and 180 or 0 }) end
    end
end

function Panel:SetScale(scale)
    self.Scale = tonumber(scale) or 1
    if self.UIScale then Animation.Tween(self.UIScale, "Hover", { Scale = self.Scale }) end
end

function Panel:SetTransparency(value)
    self.Transparency = tonumber(value)
    Theme.Refresh(self.Frame, 0.15)
end

function Panel:SetTitle(text)
    self.Title = text
    for _, child in self.Frame:GetDescendants() do
        if child:IsA("TextLabel") and child.TextSize == 12 then child.Text = text break end
    end
end

function Panel:Close()
    self:Hide()
    if self.Def.OnClose then Util.Defer(self.Def.OnClose, self) end
    self.Closed:Fire()
end

function Panel:Destroy()
    if self.Frame then self.Frame:Destroy() end
    self.Maid:Clean()
    self.Changed:Destroy()
    self.StateChanged:Destroy()
end

return Panel
end

__modules["Components/Popup"] = function(...)
local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Animation = import("Core/Animation")
local Maid = import("Core/Maid")
local Router = import("Core/Router")
local Layer = import("Components/Layer")

-- a floating surface in the overlay layer. Contents are built by the caller into popup.Body.
-- opts: Width, MaxHeight, Point (absolute) or Anchor (gui), Align = "Left" | "Right", ClosesOnClick = true
local Popup = {}
Popup.__index = Popup

local Z = 50

function Popup.new(opts)
    local self = setmetatable({
        Options = opts or {},
        Maid = Maid.new(),
        Open = false,
        Width = opts and opts.Width or 200,
    }, Popup)
    return self
end

function Popup:_build()
    local options = self.Options
    local frame = Util.New("Frame", {
        Name = "Popup",
        Size = UDim2.fromOffset(self.Width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = Z + 3,
        ClipsDescendants = true,
        Theme = {
            BackgroundColor3 = "Elevated",
            BackgroundTransparency = function(t) return math.max(0, t.ElevatedTransparency - 0.05) end,
        },
        Parent = Layer.Overlay,
    })
    Util.Corner("ElementRadius", frame)
    local stroke = Util.Stroke(frame, "Stroke", function(t) return t.StrokeTransparency - 0.1 end)
    Util.New("UIScale", { Scale = 0.96, Parent = frame })
    local body = Util.New("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(6, 6),
        ClipsDescendants = true,
        ZIndex = Z + 4,
        Parent = frame,
    })
    self.Frame = frame
    self.Body = body
    self.Stroke = stroke
    self.BodyList = Util.List(body, 2)
    self.Maid:Give(frame)
    -- keep the popup sized to its content: a list layout reports content size as it changes
    self.Maid:Give(self.BodyList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if not self.Open then return end
        local maxHeight = options.MaxHeight or 260
        local height = math.min(self.BodyList.AbsoluteContentSize.Y + 12, maxHeight)
        frame.Size = UDim2.fromOffset(self.Width, math.max(height, 12))
        body.Size = UDim2.new(1, -12, 0, math.max(height - 12, 0))
    end))
    return self
end

function Popup:OnClickOutside(fn)
    self.ClickOutside = fn
    return self
end

function Popup:IsOpen()
    return self.Open
end

function Popup:ContainsPoint(point)
    if not self.Open or not self.Frame then return false end
    local position = self.Frame.AbsolutePosition
    local size = self.Frame.AbsoluteSize
    return point.X >= position.X and point.X <= position.X + size.X
        and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

function Popup:Show()
    if not self.Frame then self:_build() end
    self.Open = true
    local options = self.Options
    local origin
    if options.Point then
        origin = options.Point
    elseif options.Anchor then
        origin = Layer.Place(options.Anchor, Vector2.new(self.Width, options.MinHeight or 40), options.Align == "Right")
    else
        origin = Vector2.new(200, 200)
    end
    self.Frame.Position = UDim2.fromOffset(origin.X, origin.Y)
    self.Frame.Visible = true
    self.Frame.Size = UDim2.fromOffset(self.Width, 12)
    local scale = self.Frame:FindFirstChildOfClass("UIScale")
    if scale then
        scale.Scale = 0.96
        Animation.Tween(scale, "Pop", { Scale = 1 })
    end
    Router.RegisterPopup(self)
    if self.Frame:FindFirstChildOfClass("UIScale") == nil then
        Util.New("UIScale", { Scale = 1, Parent = self.Frame })
    end
    return self
end

function Popup:Close()
    if not self.Open then return end
    self.Open = false
    if self.Frame then self.Frame.Visible = false end
    Router.UnregisterPopup(self)
    if self.ClickOutside then self.ClickOutside() end
end

function Popup:Toggle()
    if self.Open then self:Close() else self:Show() end
end

function Popup:Clear()
    for _, child in self.Body:GetChildren() do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
            child:Destroy()
        end
    end
    return self
end

function Popup:Destroy()
    Router.UnregisterPopup(self)
    self.Maid:Clean()
    self.Open = false
end

-- menu items: { Title, Icon, Hint, Checked, Danger, Disabled, Callback } or "-" for a divider
function Popup.Menu(items, opts)
    local menu = Popup.new({ Width = opts.Width or 190, Point = opts.Point, Anchor = opts.Anchor, MaxHeight = opts.MaxHeight })
    menu:_build()
    local popup = menu
    local function closeSoon()
        popup:Close()
    end
    for _, item in items do
        if item == "-" then
            local divider = Util.New("Frame", {
                Size = UDim2.new(1, -8, 0, 1),
                Position = UDim2.fromOffset(4, 3),
                Theme = { BackgroundColor3 = "Divider" },
                Parent = menu.Body,
            })
        else
            local hover = { on = false }
            local row = Util.New("TextButton", {
                Size = UDim2.new(1, 0, 0, 28),
                Text = "",
                Theme = {
                    BackgroundColor3 = "ElevatedHover",
                    BackgroundTransparency = function()
                        if item.Disabled then return 1 end
                        return hover.on and 0.45 or 1
                    end,
                },
                Parent = menu.Body,
            })
            Util.Corner(6, row)
            if item.Icon then
                Util.Icon(item.Icon, {
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.fromOffset(9, 7),
                    Color = item.Danger and "Danger" or "TextDim",
                    Parent = row,
                })
            end
            local label = Util.Label({
                Text = item.Title,
                TextSize = 12,
                Position = UDim2.fromOffset(item.Icon and 31 or 10, 0),
                Size = UDim2.new(1, item.Icon and -75 or -54, 1, 0),
                Color = item.Danger and "Danger" or (item.Disabled and "TextMuted" or "Text"),
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
            if item.Checked then
                Util.Icon("check", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Color = "Accent", Parent = row })
            elseif item.Hint then
                Util.Label({
                    Text = item.Hint,
                    TextSize = 10,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.new(0, 60, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Color = "TextMuted",
                    Parent = row,
                })
            end
            Util.Hover(row, function(on)
                hover.on = on
                Theme.Refresh(row, 0.1)
            end)
            Router.Attach(row, {
                Disabled = item.Disabled == true,
                OnClick = function()
                    closeSoon()
                    if item.Callback then Util.Defer(item.Callback, item.Value) end
                end,
            })
        end
    end
    return menu
end

return Popup
end

__modules["Components/ScreenButton"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")

-- an on-screen pill for touch devices: stays while the menu is hidden, drags when the menu is open
local ScreenButton = {}
ScreenButton.__index = ScreenButton

function ScreenButton.new(window, def)
    local self = setmetatable({
        Window = window,
        Def = def,
        Id = def.Id or def.Title or "button",
        Scale = (window.Interface.ButtonScale or 100) / 100,
        Transparency = (window.Interface.ButtonTransparency or 0) / 100,
        _active = false,
        Visible = def.Visible ~= false,
        Pressing = false,
    }, ScreenButton)
    self:_build()
    return self
end

function ScreenButton:_build()
    local def = self.Def
    local hover = { on = false }
    local button = Util.New("TextButton", {
        Name = "ScreenButton",
        Size = UDim2.fromOffset(0, 30),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "",
        Visible = self.Visible,
        Theme = {
            -- def.Color is the resting tint; active() overrides it with the accent
            BackgroundColor3 = function(t)
                if self._active and def.Active then return t.Accent end
                return def.Color or "Elevated"
            end,
            BackgroundTransparency = function(t)
                return math.max(0, self.Transparency + (hover.on and -0.1 or 0.05))
            end,
        },
        Parent = Layer.Hud,
    })
    Util.Corner(15, button)
    Util.Stroke(button, "Stroke", function(t) return math.max(0, t.StrokeTransparency - 0.15) end)
    Util.Padding(button, 8, 12, 8, 12)
    Util.List(button, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    if def.Icon then
        Util.Icon(def.Icon, {
            Size = UDim2.fromOffset(14, 14),
            LayoutOrder = 1,
            Color = "TextDim",
            Parent = button,
        })
    end
    local label = Util.Label({
        Text = def.Title or "Button",
        TextSize = 12,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2,
        Parent = button,
    })
    local scale = Util.New("UIScale", { Scale = self.Scale, Parent = button })
    self.Button = button
    self.Label = label
    self.UIScale = scale
    -- remembered position or bottom center
    local saved = self.Window.State.Panels and self.Window.State.Panels["button:" .. self.Id]
    if type(saved) == "table" and type(saved.Position) == "table" then
        button.Position = UDim2.fromOffset(saved.Position[1], saved.Position[2])
    else
        button.AnchorPoint = Vector2.new(0.5, 1)
        button.Position = UDim2.new(0.5, 0, 1, -20)
    end

    Util.Hover(button, function(on)
        hover.on = on
        Theme.Refresh(button, 0.12)
    end)
    Router.Attach(button, {
        OnPress = function()
            self.Pressing = true
            Animation.Tween(scale, "Press", { Scale = self.Scale * 0.95 })
            if not self.Window.Visible and def.Press then Util.Defer(def.Press) end
        end,
        OnRelease = function()
            self.Pressing = false
            Animation.Tween(scale, "Press", { Scale = self.Scale })
        end,
        OnClick = function()
            if self.Window.Visible then return end
            if def.Press and not self.Pressing then Util.Defer(def.Press) end
            if def.Release then Util.Defer(def.Release) end
        end,
        OnDrag = function(_, point)
            if not self.Window.Visible then return end
            button.Position = UDim2.fromOffset(point.X - button.AbsoluteSize.X / 2, point.Y - button.AbsoluteSize.Y / 2)
        end,
        OnDragEnd = function()
            self.Window.State.Panels = self.Window.State.Panels or {}
            self.Window.State.Panels["button:" .. self.Id] = { Position = { math.round(button.Position.X.Offset), math.round(button.Position.Y.Offset) } }
            self.Window:SaveState()
        end,
    })
    -- active state is polled; the pill lights up while the callback says so
    self._poll = Animation.Loop(0.1, function()
        if not def.Active then return end
        local ok, value = pcall(def.Active)
        value = ok and value == true
        if value ~= self._active then
            self._active = value
            -- the Theme map is read live, so Refresh alone repaints the resting tint
            if not value then Theme.Refresh(button, 0.12) end
            local target = value and Theme.Current.Accent or (def.Color or Theme.Current.Elevated)
            Animation.Tween(button, "Toggle", { BackgroundColor3 = target })
        end
    end)
    return self
end

function ScreenButton:SetVisible(visible)
    self.Visible = visible and true or false
    self.Button.Visible = self.Visible
end

function ScreenButton:SetTitle(text)
    self.Label.Text = text
end

function ScreenButton:SetScale(scale)
    self.Scale = scale or 1
    Animation.Tween(self.UIScale, "Hover", { Scale = self.Scale })
end

function ScreenButton:SetTransparency(value)
    self.Transparency = value or 0
    Theme.Refresh(self.Button, 0.1)
end

function ScreenButton:Destroy()
    if self._poll then self._poll:Disconnect() end
    if self.Button then self.Button:Destroy() end
end

return ScreenButton
end

__modules["Components/Tab"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Page = import("Components/Page")
local Container = import("Components/Container")
local Maid = import("Core/Maid")
local Signal = import("Core/Signal")

-- a tab is a sidebar entry with one page, or a set of sub-tabs with a chip bar above their pages.
-- Sub-tabs of sub-tabs are not supported; each sub-tab is a full page with the card API.
local Tab = {}
Tab.__index = Tab
Container.Apply(Tab)

function Tab.new(window, def)
    local self = setmetatable({}, Tab)
    Container.Setup(self)
    self.Kind = "Tab"
    self.Window = window
    self.Def = def
    self.Title = def.Title or def.Name or "Tab"
    self.Icon = def.Icon
    self.Id = def.Id or ("tab:" .. self.Title)
    self.Draggable = def.Draggable ~= false
    self.Columns = def.Columns or 2
    self.SubTabs = {}
    self.Selected = nil
    self.Visible = def.Visible ~= false
    self.Children = {}
    self.Changed = Signal.new()
    self.StateChanged = Signal.new()
    self.Maid = Maid.new()
    self.Page = Page.new(window, { Id = self.Id .. "/main", Columns = self.Columns })
    self.Page.ParentFrame = nil
    self.Page.Tab = self
    self.FavoritesAllowed = def.Favorites ~= false
    return self
end

-- the page shown right now
function Tab:CurrentPage()
    if self.Selected then return self.Selected.Page end
    return self.Page
end

function Tab:SubTab(def)
    local sub = setmetatable({}, Tab)
    Container.Setup(sub)
    sub.Kind = "SubTab"
    sub.Window = self.Window
    sub.Def = def
    sub.Title = def.Title or def.Name or "Sub-tab"
    sub.Icon = def.Icon
    sub.Id = def.Id or (self.Id .. "/sub:" .. sub.Title)
    sub.Draggable = def.Draggable ~= false
    sub.Columns = def.Columns or self.Columns
    sub.Visible = def.Visible ~= false
    sub.SubTabs = {}
    sub.Selected = nil
    sub.ParentTab = self
    sub.Children = {}
    sub.Changed = Signal.new()
    sub.StateChanged = Signal.new()
    sub.Maid = Maid.new()
    sub.Page = Page.new(self.Window, { Id = sub.Id, Columns = sub.Columns })
    sub.Page.Tab = self
    sub.Page.SubTab = sub
    sub.FavoritesAllowed = self.FavoritesAllowed
    -- the first sub-tab is shown by default
    table.insert(self.SubTabs, sub)
    if #self.SubTabs == 1 then self.Selected = sub end
    self.Window:_buildChips(self)
    return sub
end

function Tab:Module(def)
    if not self.Selected and #self.SubTabs > 0 then self.Selected = self.SubTabs[1] end
    return self:CurrentPage():Module(def)
end

function Tab:Elements()
    local out = self.Page:Elements()
    for _, sub in self.SubTabs do
        local subElements = sub.Page:Elements()
        for _, element in subElements do table.insert(out, element) end
    end
    return out
end

-- every module of the tab, including sub-tabs
function Tab:Modules()
    local out = {}
    for _, module in self.Page.Modules do table.insert(out, module) end
    for _, sub in self.SubTabs do
        for _, module in sub.Page.Modules do table.insert(out, module) end
    end
    return out
end

function Tab:SelectSub(name)
    for _, sub in self.SubTabs do
        if sub == name or sub.Title == name or sub.Id == name then
            self.Selected = sub
            self.Window:_showTab(self)
            return sub
        end
    end
    return nil
end

function Tab:Select()
    self.Window:SelectTab(self)
end

function Tab:SetVisible(visible)
    self.Visible = visible and true or false
    self.Window:_refreshSidebar()
end

function Tab:Matches(query)
    if self.Page:Matches(query) then return true end
    for _, sub in self.SubTabs do
        if sub.Page:Matches(query) then return true end
    end
    return false
end

-- which of this tab's pages match the query, with the matching modules
function Tab:Search(query)
    local result = {}
    local function scan(page, label)
        local hits = {}
        for _, module in page.Modules do
            if module:Matches(query) then table.insert(hits, module) end
        end
        if #hits > 0 then table.insert(result, { Page = page, Label = label, Hits = hits }) end
    end
    scan(self.Page, self.Title)
    for _, sub in self.SubTabs do
        scan(sub.Page, self.Title .. " · " .. sub.Title)
    end
    return result
end

return Tab
end

__modules["Components/Tooltip"] = function(...)
local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")

-- a small label that follows the pointer (mouse) or sits above the element (touch / gamepad)
local Tooltip = {
    Enabled = true,
    Delay = 0.35,
    MaxWidth = 240,
}

local current = nil

local function surface()
    if current and current.Frame and current.Frame.Parent then return current end
    local frame = Util.New("Frame", {
        Name = "Tooltip",
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Visible = false,
        ZIndex = 120,
        Theme = { BackgroundColor3 = "BackgroundAlt", BackgroundTransparency = 0.02 },
        Parent = Layer.Overlay,
    })
    Util.Corner(6, frame)
    Util.Stroke(frame, function(t) return t.Accent end, function() return 0.55 end)
    local padding = Util.Padding(frame, 6, 9, 6, 9)
    local label = Util.Label({
        Text = "",
        TextSize = 12,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        TextWrapped = false,
        Parent = frame,
    })
    Util.New("UIScale", { Scale = 1, Parent = frame })
    current = { Frame = frame, Label = label, Padding = padding }
    return current
end

local function place(frame, point, anchor)
    local size = frame.AbsoluteSize
    local position
    if anchor then
        position = Vector2.new(anchor.AbsolutePosition.X + anchor.AbsoluteSize.X / 2 - size.X / 2, anchor.AbsolutePosition.Y - size.Y - 8)
        if position.Y < 4 then
            position = Vector2.new(anchor.AbsolutePosition.X + anchor.AbsoluteSize.X / 2 - size.X / 2, anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 8)
        end
    else
        position = point + Vector2.new(14, 18)
    end
    position = Layer.Clamp(position, size, 4)
    frame.Position = UDim2.fromOffset(position.X, position.Y)
end

local moveConnection
local lastPointer = Vector2.new(0, 0)

local function ensurePointerTracking()
    if moveConnection then return end
    moveConnection = Services.UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        lastPointer = Vector2.new(input.Position.X, input.Position.Y)
        if current and current.Frame.Visible and not current.Anchor then
            place(current.Frame, lastPointer)
        end
    end)
end

-- shows the tooltip for gui after a short delay; returns a connection that hides it
function Tooltip.Attach(gui, text, options)
    if not Tooltip.Enabled or text == nil or text == "" then return nil end
    options = options or {}
    ensurePointerTracking()
    local connection = { Connected = true }
    local pending = nil
    local hide
    local show = function()
        local context = surface()
        context.Label.Text = text
        context.Label.TextWrapped = true
        context.Label.TextXAlignment = Enum.TextXAlignment.Left
        context.Label.Size = UDim2.fromOffset(Tooltip.MaxWidth, 0)
        context.Label.AutomaticSize = Enum.AutomaticSize.Y
        context.Frame.Visible = true
        context.Anchor = options.Anchor and gui
        task.defer(function()
            if not context.Frame.Visible then return end
            if context.Anchor then
                context.Label.Size = UDim2.fromOffset(0, 0)
            else
                context.Label.Size = UDim2.fromOffset(math.min(Tooltip.MaxWidth, math.max(60, #text * 6.6)), 0)
            end
            place(context.Frame, lastPointer, context.Anchor)
            local scale = context.Frame:FindFirstChildOfClass("UIScale")
            if scale then
                scale.Scale = 0.94
                Animation.Tween(scale, "Fade", { Scale = 1 })
            end
        end)
    end
    local function cancel()
        if pending then
            pcall(task.cancel, pending)
            pending = nil
        end
        hide()
    end
    hide = function()
        if current then current.Frame.Visible = false end
    end
    local enter = gui.MouseEnter:Connect(function()
        if not Tooltip.Enabled then return end
        if pending then pcall(task.cancel, pending) end
        pending = task.delay(Tooltip.Delay, show)
    end)
    local leave = gui.MouseLeave:Connect(cancel)
    local endTouch = gui.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then cancel() end
    end)
    -- gamepad selection also shows it
    local selected = gui.SelectionGained and gui.SelectionGained:Connect(show)
    function connection:Disconnect()
        if not connection.Connected then return end
        connection.Connected = false
        if pending then pcall(task.cancel, pending) end
        enter:Disconnect()
        leave:Disconnect()
        endTouch:Disconnect()
        if selected then selected:Disconnect() end
        hide()
    end
    return connection
end

function Tooltip.HideFor(gui)
    if current then current.Frame.Visible = false end
end

return Tooltip
end

__modules["Components/Widgets"] = function(...)
local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Animation = import("Core/Animation")
local Router = import("Core/Router")

-- small controls reused by elements: switch, checkbox, key pill, radio dot
local Widgets = {}

-- iOS style switch, animated via TweenService on offsets
function Widgets.Switch(parent, opts)
    opts = opts or {}
    local width, height = 34, 18
    local switch = { On = false, Enabled = true }

    local track = Util.New("Frame", {
        Name = "Switch",
        Size = UDim2.fromOffset(width, height),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = {
            BackgroundColor3 = function(t)
                if switch.On then return t.Accent end
                return t.ElevatedHover
            end,
            BackgroundTransparency = function(t)
                if switch.On then return 0.05 end
                return math.max(0.1, t.ElevatedTransparency)
            end,
        },
        Parent = parent,
    })
    Util.Corner(height / 2, track)
    Util.Stroke(track, function(t) return switch.On and t.Accent or t.Stroke end, function(t)
        return switch.On and 0.3 or math.max(0, t.StrokeTransparency - 0.15)
    end)
    local knob = Util.New("Frame", {
        Size = UDim2.fromOffset(height - 6, height - 6),
        Position = UDim2.fromOffset(3, 3),
        Theme = { BackgroundColor3 = function(t) return switch.On and t.OnAccent or t.TextDim end },
        Parent = track,
    })
    Util.Corner((height - 6) / 2, knob)

    local function paint(on, animate)
        switch.On = on
        if not switch.Enabled then return end
        local goal = {
            Position = UDim2.fromOffset(on and (width - height + 3) or 3, 3),
            BackgroundColor3 = on and Theme.Current.OnAccent or Theme.Current.TextDim,
        }
        if animate and Animation.Speed > 0 then
            Animation.Tween(knob, "Toggle", goal)
            Animation.Tween(track, "Toggle", { BackgroundColor3 = on and Theme.Current.Accent or Theme.Current.ElevatedHover })
        else
            for key, value in goal do knob[key] = value end
            track.BackgroundColor3 = on and Theme.Current.Accent or Theme.Current.ElevatedHover
        end
        Theme.Refresh(track, 0)
        Theme.Refresh(knob, 0)
    end

    -- hover: a faint lift of the track
    Util.Hover(track, function(hovering)
        if not switch.Enabled then return end
        if Animation.Speed <= 0 then return end
        Animation.Tween(track, "Hover", {
            BackgroundTransparency = switch.On and (hovering and 0 or 0.05) or (hovering and 0.55 or 0.75),
        })
    end)

    function switch:Set(on, animate)
        paint(on and true or false, animate ~= false)
    end

    function switch:Get()
        return switch.On
    end

    function switch:SetEnabled(enabled)
        switch.Enabled = enabled and true or false
        if not switch.Enabled then
            Animation.Tween(track, "Fade", { BackgroundColor3 = Theme.Current.Elevated, BackgroundTransparency = 0.55 })
            Animation.Tween(knob, "Fade", { BackgroundColor3 = Theme.Current.TextMuted, BackgroundTransparency = 0.45 })
        else
            knob.BackgroundTransparency = 0
            local goal = {
                Position = UDim2.fromOffset(switch.On and (width - height + 3) or 3, 3),
                BackgroundColor3 = switch.On and Theme.Current.OnAccent or Theme.Current.TextDim,
            }
            Animation.Tween(knob, "Toggle", goal)
            Animation.Tween(track, "Toggle", { BackgroundColor3 = switch.On and Theme.Current.Accent or Theme.Current.ElevatedHover })
            track.BackgroundTransparency = switch.On and 0.05 or math.max(0.1, Theme.Current.ElevatedTransparency)
            -- rebind the theme map so later refreshes keep the right transparency
            Theme.Bind(track, {
                BackgroundTransparency = function(t)
                    if switch.On then return 0.05 end
                    return math.max(0.1, t.ElevatedTransparency)
                end,
            })
        end
    end

    switch.Track = track
    switch.Knob = knob
    return switch
end

-- square checkbox with a check icon
function Widgets.Checkbox(parent, opts)
    opts = opts or {}
    local checkbox = { On = false, Enabled = true }
    local box = Util.New("Frame", {
        Name = "Checkbox",
        Size = UDim2.fromOffset(18, 18),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = {
            BackgroundColor3 = function(t)
                return checkbox.On and t.Accent or t.Elevated
            end,
            BackgroundTransparency = function(t)
                return checkbox.On and 0.05 or math.max(0.1, t.ElevatedTransparency)
            end,
        },
        Parent = parent,
    })
    Util.Corner(5, box)
    local stroke = Util.Stroke(box, function(t) return checkbox.On and t.Accent or t.Stroke end, function(t)
        return checkbox.On and 0.2 or math.max(0, t.StrokeTransparency - 0.15)
    end)
    local tick = Util.Icon("check", {
        Size = UDim2.fromOffset(13, 13),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Theme = { ImageColor3 = function(t) return t.OnAccent end },
        ImageTransparency = 1,
        Parent = box,
    })
    Util.New("UIScale", { Scale = 0.6, Parent = tick })

    local function paint(on, animate)
        checkbox.On = on
        local scale = tick:FindFirstChildOfClass("UIScale")
        if animate then
            Animation.Tween(tick, "Fade", { ImageTransparency = on and 0 or 1 })
            if scale then Animation.Tween(scale, "Pop", { Scale = on and 1 or 0.6 }) end
            Theme.Refresh(box, 0.18)
            Theme.Refresh(stroke, 0.18)
        else
            tick.ImageTransparency = on and 0 or 1
            if scale then scale.Scale = on and 1 or 0.6 end
            Theme.Refresh(box, 0)
            Theme.Refresh(stroke, 0)
        end
    end

    function checkbox:Set(on, animate)
        paint(on and true or false, animate ~= false)
    end

    function checkbox:Get()
        return checkbox.On
    end

    checkbox.Box = box
    checkbox.Tick = tick
    return checkbox
end

-- key pill shown on cards and toggle rows. click captures, right click opens the mode menu.
function Widgets.KeyPill(parent, window, binding, opts)
    opts = opts or {}
    local pill = { Hover = false }
    local button = Util.New("TextButton", {
        Name = "KeyPill",
        Size = UDim2.fromOffset(0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "",
        Theme = {
            BackgroundColor3 = "ElevatedHover",
            BackgroundTransparency = function()
                if binding and binding.Capturing then return 0 end
                return pill.Hover and 0.4 or 0.7
            end,
        },
        Parent = parent,
    })
    Util.Corner(5, button)
    Util.Padding(button, 0, 7, 0, 7)
    local stroke = Util.Stroke(button, function(t)
        return binding and (binding.Capturing and t.Accent or t.Stroke) or t.Stroke
    end, function(t) return binding and binding.Capturing and 0.1 or 0.7 end)
    local label = Util.Label({
        Text = "",
        TextSize = 11,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        Theme = {
            TextColor3 = function(t)
                if binding and binding.Capturing then return t.Accent end
                return binding and binding.Key and t.Text or t.TextMuted
            end,
        },
        Parent = button,
    })
    -- a key picked mode is shown as a dot colour: hold = warning, always = success
    local modeDot = Util.New("Frame", {
        Name = "Mode",
        Size = UDim2.fromOffset(5, 5),
        Position = UDim2.fromOffset(-4, 8),
        Visible = false,
        Theme = {
            BackgroundColor3 = function(t)
                if not binding then return t.TextMuted end
                if binding.Mode == "Always" then return t.Success end
                if binding.Mode == "Hold" then return t.Warning end
                return t.Accent
            end,
        },
        Parent = button,
    })
    Util.Corner(3, modeDot)

    local function refresh()
        if not binding then
            button.Visible = false
            return
        end
        button.Visible = opts.Visible ~= false
        if binding.Capturing then
            label.Text = "…"
        elseif binding.Key then
            label.Text = Util.KeyLabel(binding.Key)
        else
            label.Text = "Bind"
        end
        modeDot.Visible = binding.Mode ~= "Toggle" and binding.Mode ~= "Hold" or (binding.Mode == "Hold")
        modeDot.Position = UDim2.fromOffset(-(label.AbsoluteSize.X) + (binding.Mode == "Hold" and 4 or 0), 8)
        Theme.Refresh(label, 0.1)
        Theme.Refresh(button, 0.1)
        Theme.Refresh(stroke, 0.1)
    end

    if binding then
        binding.Changed:Connect(refresh)
        pill._connections = {}
        table.insert(pill._connections, binding.Changed)
    end
    refresh()

    Util.Hover(button, function(hovering)
        pill.Hover = hovering
        Theme.Refresh(button, 0.12)
    end)

    Router.Attach(button, {
        OnClick = function()
            if binding then binding:Capture() end
        end,
        OnRightClick = function(point)
            if not binding then return end
            local window = window
            local modes = binding.Modes or { "Toggle", "Hold", "Always" }
            local items = {}
            for _, mode in modes do
                table.insert(items, {
                    Title = mode,
                    Checked = binding.Mode == mode,
                    Callback = function() binding:SetMode(mode) end,
                })
            end
            if binding.Key then
                table.insert(items, "-")
                table.insert(items, { Title = "Clear key", Icon = "eraser", Callback = function() binding:SetKey(nil) end })
            end
            local Popup = import("Components/Popup")
            Popup.Menu(items, { Point = point, Width = 130 }):Show()
        end,
        Tooltip = opts.Tooltip,
    })

    function pill:Destroy()
        button:Destroy()
    end

    pill.Button = button
    pill.Label = label
    pill.Refresh = refresh
    return pill
end

-- radio dot used by segmented controls
function Widgets.Dot(parent)
    local dot = Util.New("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Theme = { BackgroundColor3 = "Accent" },
        Parent = parent,
    })
    Util.Corner(3, dot)
    return dot
end

-- a one pixel line
function Widgets.Divider(parent, height)
    return Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, height or 1),
        Theme = { BackgroundColor3 = "Divider", BackgroundTransparency = 0.3 },
        Parent = parent,
    })
end

return Widgets
end

__modules["Components/Window"] = function(...)
local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Maid = import("Core/Maid")
local Router = import("Core/Router")
local Storage = import("Core/Storage")
local Config = import("Core/Config")
local Binding = import("Core/Binding")
local Keybinds = import("Core/Keybinds")
local Layer = import("Components/Layer")
local Popup = import("Components/Popup")
local Tooltip = import("Components/Tooltip")
local Dialog = import("Components/Dialog")
local Tab = import("Components/Tab")
local Animation = import("Core/Animation")
local Signal = import("Core/Signal")

local UIS = Services.UserInputService
local TOP = 50
local FOOTER = 46
local SLIDE = 14
local MIN_SIZE = Vector2.new(560, 380)

local INTERFACE = {
    Scale = 1,
    FitScreen = true,
    Compact = false,
    ToggleKey = "RightShift",
    KeybindList = false,
    Watermark = false,
    ShowUser = true,
    HideUser = false,
    HideAvatar = false,
    NotifyPosition = "BottomRight",
    NotifyDuration = 100,
    NotifyMax = 5,
    ToggleAlerts = "Always",
    BindClickOutside = "Keep",
    BindEscape = "Keep",
    BindMouse = true,
    BindComboKeys = 3,
    Tooltips = true,
    AutoSave = false,
    AutoExpand = true,
    Descriptions = true,
    AnimSpeed = 1,
}

local Window = {}
Window.__index = Window

function Window.new(library, def)
    def = def or {}
    local self = setmetatable({
        Library = library,
        Def = def,
        Maid = Maid.new(),
        Tabs = {},
        Panels = {},
        ScreenButtons = {},
        _binds = {},
        Visible = def.Visible ~= false,
    }, Window)
    self.Folder = def.Folder or (def.Title and def.Title:gsub("[^%w_%- ]", "")) or "UnWrittenUI"
    self.SidebarWidth = def.SidebarWidth or 164
    self.Config = Config.new(self.Folder)
    self.Changed = Signal.new()
    self:_loadState()
    self.Config.AutoSave = self.Interface.AutoSave == true
    self:_applyBindOptions()
    if self.State.Theme then
        Theme.Import(self.State.Theme)
    elseif def.Theme then
        Theme.UsePalette(def.Theme)
    end
    if def.ThemeOverrides then Theme.Set(def.ThemeOverrides) end
    if def.AnimSpeed then
        Theme.Set({ AnimSpeed = def.AnimSpeed })
        self.Interface.AnimSpeed = def.AnimSpeed
    end
    Animation.Speed = Theme.Current.AnimSpeed or 1
    local Notification = import("Components/Notification")
    Notification.Setup(self)
    self.Maid:Give(Theme.Changed:Connect(function() self:SaveState() end))
    self:_build()
    self.Favorites = import("Components/Page").new(self, {
        Id = "favorites",
        Columns = 2,
        Source = true,
        Empty = "No favorites yet.\nClick the star on a module's menu to pin it here.",
    })
    self.Favorites.Tab = { FavoritesAllowed = false, Title = "Favorites" }
    self.Favorites.ParentFrame = self.Body
    self.Search = import("Components/Page").new(self, { Id = "search", Columns = 1, Source = true })
    self.Search.Tab = { FavoritesAllowed = false, Title = "Search" }
    self.Search.ParentFrame = self.Body
    self.Favorites._mirror = function()
        local out = {}
        for _, tab in self.Tabs do
            for _, module in tab:Modules() do
                if module.Favorite then table.insert(out, { Module = module, Label = tab.Title }) end
            end
        end
        return out
    end
    self.Favorites._emptyText = "No favorites yet.\nStar a module from its right-click menu to pin it here."
    self.Search._mirror = function(query)
        local out = {}
        if not query or query == "" then return out end
        for _, tab in self.Tabs do
            for _, entry in tab:Search(query) do
                for _, module in entry.Hits do table.insert(out, { Module = module, Label = entry.Label }) end
            end
        end
        return out
    end

    self.MenuBinding = Binding.new({
        Key = def.ToggleKey and Binding.KeyName(def.ToggleKey) or "RightShift",
        Mode = "Toggle",
        Modes = { "Toggle" },
        Press = function() self:Toggle() end,
    })
    self._binds = self._binds or {}
    self.MenuBinding.Changed:Connect(function()
        self.Interface.ToggleKey = self.MenuBinding.Key or false
        self:SaveState()
    end)

    if def.Settings ~= false then
        import("Addons/Settings")(self)
    end
    if self.State.Tab == "favorites" then
        self:SelectFavorites()
    end
    if def.AutoLoad ~= false then
        task.defer(function() self:LoadAutoload() end)
    end
    if self.Visible then self:_slide(true) end
    return self
end

-- state ---------------------------------------------------------------------

function Window:_loadState()
    local state = Storage.ReadJSON(self.Folder .. "/ui.json")
    if type(state) ~= "table" then state = {} end
    state.Favorites = type(state.Favorites) == "table" and state.Favorites or {}
    state.Notify = type(state.Notify) == "table" and state.Notify or {}
    state.Layout = type(state.Layout) == "table" and state.Layout or {}
    state.Interface = type(state.Interface) == "table" and state.Interface or {}
    local defaults = table.clone(INTERFACE)
    if self.Def.ToggleKey then defaults.ToggleKey = Binding.KeyName(self.Def.ToggleKey) end
    if self.Def.ComboKeys then defaults.BindComboKeys = self.Def.ComboKeys end
    if self.Def.AutoSave ~= nil then defaults.AutoSave = self.Def.AutoSave == true end
    if self.Def.Descriptions ~= nil then defaults.Descriptions = self.Def.Descriptions ~= false end
    for key, value in defaults do
        if state.Interface[key] == nil then state.Interface[key] = value end
    end
    self.State = state
    self.Interface = state.Interface
end

function Window:SaveState()
    if self._saveQueued then return end
    self._saveQueued = true
    task.delay(0.5, function()
        self._saveQueued = false
        if self.Destroyed then return end
        self.State.Theme = Theme.Export()
        Storage.WriteJSON(self.Folder .. "/ui.json", self.State)
    end)
end

function Window:_touch(binds)
    self.Config:Touch()
    if self.Overlays and (binds or self.Interface.KeybindList) then self.Overlays:RefreshBinds() end
    if self.Changed then self.Changed:Fire() end
end

function Window:_emit(event, ...)
    if self.Changed then self.Changed:Fire(event, ...) end
end

function Window:_trackBind(owner)
    if owner.Def and owner.Def.Listed == false then return end
    table.insert(self._binds, owner)
end

function Window:_checkDependents(element)
    -- elements use DependsOn with their own signal connections; this hook lets modules react
end

function Window:GetScale()
    return self.Scale or 1
end

function Window:_applyBindOptions()
    local Binding = import("Core/Binding")
    local interface = self.Interface
    Binding.Options.ClickOutside = interface.BindClickOutside
    Binding.Options.Escape = interface.BindEscape
    Binding.Options.Mouse = interface.BindMouse ~= false
    Binding.Options.ComboKeys = tonumber(interface.BindComboKeys) or 3
    Tooltip.Enabled = interface.Tooltips ~= false
end

-- build ---------------------------------------------------------------------

local function iconButton(parent, icon, order, tip, callback)
    local hover = { Hover = false }
    local button = Util.New("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        LayoutOrder = order,
        Text = "",
        Theme = {
            BackgroundColor3 = "ElevatedHover",
            BackgroundTransparency = function() return hover.Hover and 0.3 or 1 end,
        },
        Parent = parent,
    })
    Util.Corner(6, button)
    local image = Util.Icon(icon, {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Theme = { ImageColor3 = function(t) return hover.Hover and t.Text or t.TextDim end },
        Parent = button,
    })
    Util.Hover(button, function(on)
        hover.Hover = on
        Theme.Refresh(button, 0.12)
        Theme.Refresh(image, 0.12)
    end)
    Router.Attach(button, { OnClick = callback, Tooltip = tip })
    return button, image
end

function Window:_build()
    local def = self.Def
    local size = def.Size or UDim2.fromOffset(780, 520)
    self.DefaultSize = size
    if type(self.Interface.Size) == "table" then
        size = UDim2.fromOffset(self.Interface.Size[1], self.Interface.Size[2])
    end
    self.MinSize = def.MinSize or MIN_SIZE

    local root = Util.New("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        Visible = self.Visible,
        ClipsDescendants = true,
        Active = true,
        Theme = {
            BackgroundColor3 = function(t) return t.Gradient and Color3.new(1, 1, 1) or t.Background end,
            BackgroundTransparency = function(t) return t.WindowTransparency end,
        },
        Parent = Layer.Main,
    })
    Util.Corner("Radius", root)
    Util.Stroke(root)
    Util.New("UIGradient", {
        Theme = {
            Rotation = "GradientRotation",
            Color = function(t)
                return ColorSequence.new({
                    ColorSequenceKeypoint.new(0, t.BackgroundAlt),
                    ColorSequenceKeypoint.new(0.55, t.Background),
                    ColorSequenceKeypoint.new(1, t.Background),
                })
            end,
        },
        Parent = root,
    })
    self.Root = root
    self.UIScale = Util.New("UIScale", { Parent = root })
    self.Maid:Give(root)
    if type(self.Interface.Position) == "table" then
        root.Position = UDim2.new(0.5, self.Interface.Position[1], 0.5, self.Interface.Position[2])
    end

    -- topbar -----------------------------------------------------------------
    local topbar = Util.New("Frame", { Name = "Topbar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TOP), Parent = root })
    self.Topbar = topbar
    local logo = Util.Icon(def.Icon or "sparkles", {
        Size = UDim2.fromOffset(22, 22),
        Position = UDim2.fromOffset(16, 14),
        Color = "Accent",
        Parent = topbar,
    })
    local heading = Util.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 8), Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, Parent = topbar })
    Util.List(heading, 6, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
    local title = Util.Label({
        Text = def.Title or "UnWrittenUI",
        TextSize = 15,
        Weight = Enum.FontWeight.Bold,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromScale(0, 1),
        LayoutOrder = 1,
        Theme = { TextColor3 = function(t) return t.AnimatedTitle and Color3.new(1, 1, 1) or t.Text end },
        Parent = heading,
    })
    self.TitleLabel = title
    local titleGradient = Util.New("UIGradient", {
        Theme = {
            Color = function(t)
                return ColorSequence.new({
                    ColorSequenceKeypoint.new(0, t.Accent),
                    ColorSequenceKeypoint.new(0.5, t.AccentAlt),
                    ColorSequenceKeypoint.new(1, t.Accent),
                })
            end,
        },
        Parent = title,
    })
    for index, tag in def.Tags or {} do
        tag = type(tag) == "string" and { Text = tag } or tag
        local chip = Util.New("Frame", {
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 16),
            LayoutOrder = 1 + index,
            BackgroundColor3 = tag.Color,
            BackgroundTransparency = tag.Color and 0.85 or nil,
            Theme = not tag.Color and { BackgroundColor3 = "Elevated" } or nil,
            Parent = heading,
        })
        Util.Corner(4, chip)
        Util.Padding(chip, 0, 6, 0, 6)
        Util.Label({
            Text = tag.Text or tag.Title or "",
            TextSize = 10,
            Weight = Enum.FontWeight.SemiBold,
            Color = "TextDim",
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromScale(0, 1),
            Parent = chip,
        })
    end
    self.SubtitleLabel = Util.Label({
        Text = def.Subtitle or def.SubTitle or "",
        TextSize = 11,
        Color = "TextMuted",
        Position = UDim2.fromOffset(48, 27),
        Size = UDim2.new(0, 260, 0, 14),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = topbar,
    })
    local titleStep = 0
    self.Maid:Give(Services.RunService.Heartbeat:Connect(function()
        if not (Theme.Current.AnimatedTitle and self.Visible) then return end
        local now = os.clock()
        if now - titleStep < 1 / 30 then return end
        titleStep = now
        titleGradient.Offset = Vector2.new(math.sin(now * 1.3) * 0.5, 0)
    end))

    local actions = Util.New("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 28),
        Parent = topbar,
    })
    Util.List(actions, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    self.Actions = actions

    -- search
    local searchFocused = false
    local search = Util.New("Frame", {
        Name = "Search",
        Size = UDim2.fromOffset(178, 28),
        LayoutOrder = 1,
        Visible = def.Search ~= false,
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = function(t) return math.max(0.1, t.ElevatedTransparency) end },
        Parent = actions,
    })
    Util.Corner(7, search)
    local searchStroke = Util.Stroke(search, function(t) return searchFocused and t.Accent or t.Stroke end, function(t)
        return searchFocused and 0.3 or t.StrokeTransparency + 0.1
    end)
    Util.Icon("search", { Size = UDim2.fromOffset(13, 13), Position = UDim2.new(0, 9, 0.5, -6), Color = "TextMuted", Parent = search })
    local searchBox = Util.New("TextBox", {
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.fromOffset(28, 0),
        PlaceholderText = "Search",
        TextSize = 12,
        Theme = { TextColor3 = "Text", PlaceholderColor3 = "TextMuted", FontFace = Theme.Font(Enum.FontWeight.Medium) },
        Parent = search,
    })
    self.SearchBox = searchBox
    searchBox.Focused:Connect(function() searchFocused = true; Keybinds.Block = true; Theme.Refresh(searchStroke, 0.15) end)
    searchBox.FocusLost:Connect(function() searchFocused = false; Keybinds.Block = false; Theme.Refresh(searchStroke, 0.15) end)
    local searchToken = 0
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchToken += 1
        local mine = searchToken
        task.delay(0.12, function()
            if mine == searchToken then self:_search(searchBox.Text) end
        end)
    end)
    if def.SearchShortcut ~= false then
        self.Maid:Give(UIS.InputBegan:Connect(function(input, processed)
            if processed or Keybinds.TextFocused() then return end
            if input.KeyCode == Enum.KeyCode.F and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
                searchBox:CaptureFocus()
                searchBox.Text = ""
            end
        end))
    end

    self.MinimizeButton = iconButton(actions, "minus", 3, "Minimize", function() self:SetMinimized(true) end)
    self.CloseButton = iconButton(actions, "x", 4, def.CloseAction == "Unload" and "Unload" or "Hide", function()
        local action = def.CloseAction or "Hide"
        if action == "Unload" then
            self.Library:Unload()
        elseif action == "Confirm" then
            self:Dialog({
                Title = "Unload the menu?",
                Content = "The script stops running and the UI is removed.",
                Icon = "triangle-alert",
                Buttons = {
                    { Title = "Cancel", Style = "Secondary" },
                    { Title = "Unload", Style = "Danger", Callback = function() self.Library:Unload() end },
                },
            })
        else
            self:SetVisible(false)
        end
    end)

    -- body: sidebar + content
    local body = Util.New("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, TOP),
        Size = UDim2.new(1, 0, 1, -(TOP)),
        Parent = root,
    })
    self.BodyFrame = body
    local sidebar = Util.New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, self.SidebarWidth, 1, 0),
        BackgroundTransparency = 1,
        Parent = body,
    })
    self.Sidebar = sidebar
    local sidebarLine = Util.New("Frame", {
        Size = UDim2.new(0, 1, 1, -20),
        Position = UDim2.fromOffset(self.SidebarWidth, 10),
        Theme = { BackgroundColor3 = "Divider", BackgroundTransparency = 0.5 },
        Parent = body,
    })
    local navScroll = Util.New("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -(FOOTER + 10)),
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = sidebar,
    })
    local navList = Util.List(navScroll, 2)
    Util.Padding(navScroll, 8, 8, 8, 8)
    Util.AutoCanvas(navScroll, navList)
    self.NavScroll = navScroll
    self.NavList = navList

    local content = Util.New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(self.SidebarWidth + 1, 0),
        Size = UDim2.new(1, -(self.SidebarWidth + 1), 1, 0),
        Parent = body,
    })
    self.Content = content
    local chips = Util.New("Frame", {
        Name = "Chips",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 0, 30),
        Position = UDim2.fromOffset(12, 6),
        Visible = false,
        Parent = content,
    })
    Util.List(chips, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    self.ChipBar = chips
    local pageArea = Util.New("Frame", {
        Name = "Pages",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = content,
    })
    self.Body = pageArea
    self.PageArea = pageArea

    -- profile card at the bottom of the sidebar
    local userDef = def.User
    self.UserFrame = Util.New("Frame", {
        Name = "User",
        Size = UDim2.new(1, -16, 0, FOOTER - 10),
        Position = UDim2.new(0, 8, 1, -(FOOTER - 4)),
        Visible = userDef ~= false and self.Interface.ShowUser ~= false,
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = function(t) return math.max(0.05, t.ElevatedTransparency) end },
        Parent = sidebar,
    })
    Util.Corner("ElementRadius", self.UserFrame)
    local user = type(userDef) == "table" and userDef or {}
    local avatar = Util.New("ImageLabel", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromOffset(7, 5),
        Image = user.Avatar and Util.IconId(user.Avatar) or Util.Avatar(Services.Players.LocalPlayer and Services.Players.LocalPlayer.UserId or 0) or "",
        BackgroundColor3 = Theme.Current.Accent,
        BackgroundTransparency = 0.6,
        Parent = self.UserFrame,
    })
    Util.Corner(13, avatar)
    self.Avatar = avatar
    self.UserName = Util.Label({
        Text = "…",
        TextSize = 12,
        Weight = Enum.FontWeight.SemiBold,
        Position = UDim2.fromOffset(40, 5),
        Size = UDim2.new(1, -46, 0, 15),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = self.UserFrame,
    })
    self.UserSub = Util.Label({
        Text = user.Subtitle or "",
        TextSize = 10,
        Position = UDim2.fromOffset(40, 19),
        Size = UDim2.new(1, -46, 0, 13),
        Color = "TextMuted",
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = self.UserFrame,
    })
    self:SetUser(userDef)
    Router.Attach(self.UserFrame, {
        OnClick = function()
            if user.Callback then Util.Defer(user.Callback) end
        end,
    })

    -- empty state: shown when the selected page has no cards
    self.ToggleKeyHint = Util.Label({
        Text = "Press " .. Util.KeyLabel(self.MenuBinding and self.MenuBinding.Key or "RightShift") .. " to hide",
        TextSize = 10,
        Position = UDim2.new(0, 8, 1, -14),
        Size = UDim2.new(1, -16, 0, 12),
        TextXAlignment = Enum.TextXAlignment.Center,
        Color = "TextMuted",
        Parent = sidebar,
    })

    self:_wireDragAndResize(root)
    self:_applyFit()
    if self:IsCompact() then
        self:_setCompactLayout(true)
    else
        self:_setCompactLayout(false)
    end
    self.Maid:Give(UIS.InputBegan:Connect(function(input, processed)
        if processed or Keybinds.TextFocused() then return end
        local key = self.MenuBinding and self.MenuBinding.Key
        if key and input.KeyCode.Name == key and not Keybinds.Capturing then
            self:Toggle()
        end
    end))
    self.Overlays = import("Components/Overlays").new(self)
    self.Overlays:SetWatermark(self.Interface.Watermark ~= false and self.Interface.Watermark ~= nil)
    if self.Overlays.WatermarkFrame then self.Overlays.WatermarkFrame.Visible = self.Interface.Watermark ~= false and self.Interface.Watermark ~= nil end
    self.Overlays:SetKeybindList(self.Interface.KeybindList == true)
    self.Library:OnUnload(function() self:Destroy() end)
end

function Window:_wireDragAndResize(root)
    -- drag by the empty topbar
    local dragging = false
    local start, origin
    Router.Attach(self.Topbar, {
        OnPress = function(_, point)
            if self.Def.Draggable == false then return end
            dragging = true
            start = point
            origin = root.Position
        end,
        OnDrag = function(_, point)
            if not dragging then return end
            local delta = point - start
            local scale = self.Scale or 1
            root.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X / scale, origin.Y.Scale, origin.Y.Offset + delta.Y / scale)
        end,
        OnRelease = function()
            dragging = false
            if root.Position then
                local center = root.AbsolutePosition + root.AbsoluteSize / 2
                local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
                self.Interface.Position = { math.round(center.X - viewport.X / 2), math.round(center.Y - viewport.Y / 2) }
                self:SaveState()
            end
        end,
    })
    -- resize grip in the bottom right corner
    local grip = Util.New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3),
        BackgroundTransparency = 1,
        Visible = self.Def.Resizable ~= false,
        Parent = root,
    })
    local gripIcon = Util.Icon("grip-vertical", {
        Size = UDim2.fromOffset(10, 10),
        Rotation = -45,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        ImageTransparency = 0.5,
        Color = "TextMuted",
        Parent = grip,
    })
    local resizing, sizeStart, pointerStart = false, nil, nil
    Router.Attach(grip, {
        OnPress = function(_, point)
            resizing = true
            sizeStart = root.AbsoluteSize / (self.Scale or 1)
            pointerStart = point
        end,
        OnDrag = function(_, point)
            if not resizing then return end
            local delta = (point - pointerStart) / (self.Scale or 1)
            local nextSize = Vector2.new(
                math.max(sizeStart.X + delta.X, self.MinSize.X),
                math.max(sizeStart.Y + delta.Y, self.MinSize.Y)
            )
            root.Size = UDim2.fromOffset(nextSize.X, nextSize.Y)
        end,
        OnRelease = function()
            resizing = false
            self.Interface.Size = { math.round(root.AbsoluteSize.X / (self.Scale or 1)), math.round(root.AbsoluteSize.Y / (self.Scale or 1)) }
            self:SaveState()
        end,
    })

    -- fit to the screen: 1080p is 1, smaller screens shrink, never below 0.55
    self.Maid:Give(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:_applyFit() end))
end

function Window:_applyFit()
    local interface = self.Interface
    local scale = 1
    if interface.FitScreen ~= false then
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        scale = math.min(viewport.Y / 1080, viewport.X / 1920)
        scale = math.clamp(scale, 0.55, 1.15)
    end
    scale *= tonumber(interface.Scale) or 1
    self.Scale = scale
    if self.UIScale then self.UIScale.Scale = scale end
    -- keep the window on screen
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    local size = self.Root.AbsoluteSize
    if size.X > viewport.X or size.Y > viewport.Y then
        self.Root.Size = UDim2.fromOffset(math.min(self.DefaultSize.X.Offset, viewport.X / scale - 20), math.min(self.DefaultSize.Y.Offset, viewport.Y / scale - 20))
    end
end

function Window:SetFitScreen(on)
    self.Interface.FitScreen = on and true or false
    self:_applyFit()
    self:SaveState()
end

function Window:SetScale(scale)
    self.Interface.Scale = tonumber(scale) or 1
    self:_applyFit()
    self:SaveState()
end

function Window:Center()
    self.Root.Position = UDim2.fromScale(0.5, 0.5)
    self.Interface.Position = nil
    self:SaveState()
end

function Window:SetSize(size)
    if typeof(size) == "Vector2" then size = UDim2.fromOffset(size.X, size.Y) end
    self.Root.Size = size
    self.Interface.Size = { size.X.Offset, size.Y.Offset }
    self:SaveState()
end

function Window:SetTitle(text)
    self.Def.Title = text
    if self.TitleLabel then self.TitleLabel.Text = text end
end

function Window:SetSubtitle(text)
    self.Def.Subtitle = text
    if self.SubtitleLabel then self.SubtitleLabel.Text = text or "" end
end

function Window:SetUser(def)
    local user = type(def) == "table" and def or {}
    self.UserFrame.Visible = def ~= false and self.Interface.ShowUser ~= false
    if def == false then return end
    local player = Services.Players.LocalPlayer
    self.UserName.Text = self.Interface.HideUser and "Hidden" or (user.Name or (player and (player.DisplayName or player.Name)) or "Player")
    self.UserSub.Text = user.Subtitle or "@" .. (player and player.Name or "player")
    if user.Avatar then
        self.Avatar.Image = Util.IconId(user.Avatar)
    elseif self.Interface.HideAvatar then
        self.Avatar.Image = ""
    end
end

function Window:SetWatermark(text)
    self.Interface.Watermark = text or false
    if self.Overlays then self.Overlays:SetWatermark(self.Interface.Watermark) end
    self:SaveState()
end

-- sidebar nav ---------------------------------------------------------------

function Window:_refreshSidebar()
    for _, button in self._navButtons or {} do button:Destroy() end
    self._navButtons = {}
    self._navState = {}   -- Instances cannot hold new fields, so per-button state lives here
    local order = 0
    local function navButton(title, icon, callback, options)
        options = options or {}
        order += 1
        local hover = { on = false }
        local selected = options.Selected or false
        local state = { selected = selected }
        local button = Util.New("TextButton", {
            Name = "Nav",
            Size = UDim2.new(1, 0, 0, 30),
            Text = "",
            LayoutOrder = options.Order or order,
            Visible = options.Visible ~= false,
            Theme = {
                BackgroundColor3 = function(t) return state.selected and t.Elevated or t.SurfaceHover end,
                BackgroundTransparency = function(t)
                    if state.selected then return 0.25 end
                    return hover.on and 0.6 or 1
                end,
            },
            Parent = self.NavScroll,
        })
        Util.Corner("ElementRadius", button)
        if icon then
            Util.Icon(icon, {
                Size = UDim2.fromOffset(15, 15),
                Position = UDim2.fromOffset(10, 8),
                Theme = { ImageColor3 = function(t) return state.selected and t.Accent or t.TextDim end },
                Parent = button,
            })
        end
        local label = Util.Label({
            Text = title,
            TextSize = 12,
            Weight = selected and Enum.FontWeight.SemiBold or Enum.FontWeight.Medium,
            Position = UDim2.fromOffset(icon and 33 or 12, 0),
            Size = UDim2.new(1, icon and -38 or -18, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Theme = { TextColor3 = function(t) return state.selected and t.Text or t.TextDim end },
            Parent = button,
        })
        if options.Badge then
            Util.Label({
                Text = options.Badge,
                TextSize = 10,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(22, 14),
                TextXAlignment = Enum.TextXAlignment.Right,
                Color = "TextMuted",
                Parent = button,
            })
        end
        Util.Hover(button, function(on)
            hover.on = on
            Theme.Refresh(button, 0.12)
        end)
        Router.Attach(button, { OnClick = callback })
        self._navState[button] = { title = title, SetSelected = function(on)
            state.selected = on
            label.TextColor3 = on and Theme.Current.Text or Theme.Current.TextDim
            Theme.Refresh(button, 0.15)
            Theme.Refresh(button:FindFirstChildOfClass("ImageLabel") or label, 0.15)
        end }
        table.insert(self._navButtons, button)
        return button
    end

    if self.Def.SidebarCaptions then
        for _, caption in self.Def.SidebarCaptions do navButton(caption, nil, function() end, { Visible = false }) end
    end
    local favoritesCount = 0
    for _, tab in self.Tabs do
        for _, module in tab:Modules() do
            if module.Favorite then favoritesCount += 1 end
        end
    end
    self._favoritesButton = navButton("Favorites", "star", function() self:SelectFavorites() end, {
        Order = -2,
        Badge = favoritesCount > 0 and tostring(favoritesCount) or nil,
    })
    for _, caption in self._captions or {} do
        local holder = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = caption.Order,
            Parent = self.NavScroll,
        })
        Util.Label({
            Text = caption.Text:upper(),
            TextSize = 9,
            Weight = Enum.FontWeight.Bold,
            Position = UDim2.fromOffset(10, 9),
            Size = UDim2.new(1, -10, 0, 12),
            Color = "TextMuted",
            Parent = holder,
        })
        table.insert(self._navButtons, holder)
    end
    for _, tab in self.Tabs do
        if tab.Sidebar ~= false then
            tab.Button = navButton(tab.Title, tab.Icon, function() self:SelectTab(tab) end, { Visible = tab.Visible })
            tab._navSelected = function(on)
                local nav = self._navState[tab.Button]
                if nav then nav.SetSelected(on) end
            end
        end
    end
    if self.SelectedTab then self:_refreshSelection() end
end

function Window:_refreshSelection()
    for _, tab in self.Tabs do
        if tab.Sidebar ~= false and tab._navSelected then tab._navSelected(tab == self.SelectedTab) end
    end
    if self._favoritesButton and self._navState[self._favoritesButton] then
        self._navState[self._favoritesButton].SetSelected(self.Mode == "favorites")
    end
end

-- tabs ---------------------------------------------------------------------

function Window:Tab(def)
    local tab = Tab.new(self, def)
    table.insert(self.Tabs, tab)
    if def.Caption then
        self:TabSection(def.Caption)
    end
    self:_refreshSidebar()
    if not self.SelectedTab then
        self:SelectTab(tab)
    end
    return tab
end

function Window:TabSection(text)
    self._captions = self._captions or {}
    table.insert(self._captions, { Text = tostring(text), Order = #self.Tabs + (#self._captions or 0) + 1 })
end

function Window:Divider()
    self:TabSection("")
end

function Window:SelectTab(target, focusModule)
    local tab = target
    if type(target) == "number" then tab = self.Tabs[target] end
    if type(target) == "string" then
        for _, candidate in self.Tabs do
            if candidate.Title == target or candidate.Id == target then tab = candidate break end
        end
    end
    if not tab then return end
    self.Mode = "tab"
    self.SelectedTab = tab
    self:_refreshSelection()
    if focusModule then
        focusModule:SetExpanded(true)
    end
    self:_showTab(tab)
end

-- jumps to the built-in settings tab, optionally expanding one of its modules by title
function Window:OpenSettings(moduleTitle)
    local tab
    for _, candidate in self.Tabs do
        if candidate.Id == "Settings" or candidate.Title == "Settings" then tab = candidate break end
    end
    if not tab then return nil end
    self:SelectTab(tab)
    self:SetVisible(true)
    if moduleTitle then
        for _, module in tab:Modules() do
            if module.Title == moduleTitle then
                module:SetExpanded(true)
                break
            end
        end
    end
    return tab
end

function Window:_showTab(tab)
    for _, candidate in self.Tabs do
        candidate.Page:SetVisible(false)
        for _, sub in candidate.SubTabs do sub.Page:SetVisible(false) end
    end
    self.Favorites:SetVisible(false)
    self.Search:SetVisible(false)
    local page = tab:CurrentPage()
    self:_layoutPages(tab)
    page:SetVisible(true)
    self.State.Tab = tab.Id
    if tab.Selected then self.State.SubTab = tab.Selected.Id else self.State.SubTab = nil end
    self:SaveState()
    self:_refreshSelection()
    self:_buildChips(tab)
end

function Window:_layoutPages(tab)
    local hasChips = tab and #tab.SubTabs > 0
    self.ChipBar.Visible = hasChips and true or false
    -- the first sub-tab is selected when the tab is built
    if hasChips and not tab.Selected then tab.Selected = tab.SubTabs[1] end
    for _, sub in self.Tabs do end
    if tab then
        tab.Page.Surface.Size = UDim2.new(1, 0, 1, hasChips and -36 or 0)
        tab.Page.Surface.Position = UDim2.fromOffset(0, hasChips and 36 or 0)
        for _, sub in tab.SubTabs do
            sub.Page.Surface.Size = UDim2.new(1, 0, 1, -36)
            sub.Page.Surface.Position = UDim2.fromOffset(0, 36)
        end
    end
    self.Favorites.Surface.Size = UDim2.fromScale(1, 1)
    self.Search.Surface.Size = UDim2.fromScale(1, 1)
end

function Window:_buildChips(tab)
    for _, child in self.ChipBar:GetChildren() do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    if not tab or #tab.SubTabs == 0 then return end
    for _, sub in tab.SubTabs do
        local state = { selected = sub == tab.Selected }
        local hover = { on = false }
        local chip = Util.New("TextButton", {
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = "",
            Theme = {
                BackgroundColor3 = function(t) return state.selected and t.Elevated or t.SurfaceHover end,
                BackgroundTransparency = function(t) return state.selected and 0.15 or (hover.on and 0.6 or 1) end,
            },
            Parent = self.ChipBar,
        })
        Util.Corner(7, chip)
        Util.Padding(chip, 0, 10, 0, 10)
        if sub.Icon then
            Util.Icon(sub.Icon, {
                Size = UDim2.fromOffset(12, 12),
                Position = UDim2.fromOffset(0, 7),
                Color = state.selected and "Accent" or "TextMuted",
                Parent = chip,
            })
        end
        local label = Util.Label({
            Text = sub.Title,
            TextSize = 12,
            Weight = state.selected and Enum.FontWeight.SemiBold or Enum.FontWeight.Medium,
            Size = UDim2.fromScale(0, 1),
            Position = UDim2.fromOffset(sub.Icon and 16 or 0, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Theme = { TextColor3 = function(t) return state.selected and t.Text or t.TextMuted end },
            Parent = chip,
        })
        if sub.Icon then Util.Padding(chip, 0, 10, 0, 26) end
        Util.Hover(chip, function(on)
            hover.on = on
            Theme.Refresh(chip, 0.1)
        end)
        Router.Attach(chip, {
            OnClick = function()
                if tab.Selected == sub then return end
                tab.Selected = sub
                for _, candidate in tab.SubTabs do candidate.Page:SetVisible(false) end
                self:_layoutPages(tab)
                sub.Page:SetVisible(true)
                self:_buildChips(tab)
                self.State.SubTab = sub.Id
                self:SaveState()
            end,
        })
    end
end

function Window:SelectFavorites()
    self.Mode = "favorites"
    for _, tab in self.Tabs do
        tab.Page:SetVisible(false)
        for _, sub in tab.SubTabs do sub.Page:SetVisible(false) end
    end
    self.Search:SetVisible(false)
    self.State.Tab = "favorites"
    self:SaveState()
    self.Favorites:SetVisible(true)
    self.Favorites:Refresh()
    self:_refreshSelection()
end

function Window:_search(query)
    query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then
        if self.Mode == "search" then
            if self.SelectedTab then self:_showTab(self.SelectedTab) else self:SelectFavorites() end
        end
        return
    end
    for _, tab in self.Tabs do
        tab.Page:SetVisible(false)
        for _, sub in tab.SubTabs do sub.Page:SetVisible(false) end
    end
    self.Favorites:SetVisible(false)
    self.Mode = "search"
    self.Search:SetVisible(true)
    self.Search:Refresh(query)
    self:_refreshSelection()
end

-- favorites ----------------------------------------------------------------

function Window:_setFavorite(module, favorite)
    if favorite then
        self.State.Favorites[module.Id] = true
    else
        self.State.Favorites[module.Id] = nil
    end
    module.Favorite = favorite
    self:SaveState()
    self:_refreshSidebar()
    if self.Mode == "favorites" then self.Favorites:Refresh() end
end

function Window:_setNotify(module, on)
    self.State.Notify[module.Id] = on and true or nil
    module.Notify = on
    self:SaveState()
end

function Window:_toggleNote(module, enabled)
    local mode = self.Interface.ToggleAlerts or "Always"
    if mode == "Off" then return end
    if mode == "Hidden" and self.Visible then return end
    self:Notify({
        Title = module.Title,
        Content = enabled and "Enabled" or "Disabled",
        Type = enabled and "Success" or "Info",
        Duration = 2,
    })
end

-- keys and visibility --------------------------------------------------------

function Window:SetVisible(visible)
    visible = visible and true or false
    if visible == self.Visible then return end
    self.Visible = visible
    self:_slide(visible)
    self.State.Visible = visible
    if self.Overlays then self.Overlays:SetVisible(visible) end
end

function Window:Toggle()
    self:SetVisible(not self.Visible)
end

function Window:_slide(show)
    local root = self.Root
    if show then
        root.Visible = true
        local position = root.Position
        if self.Interface.Position then
            root.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + SLIDE / (self.Scale or 1))
            Animation.Tween(root, "Slide", { Position = position })
        else
            root.Position = UDim2.new(0.5, 0, 0.5, SLIDE / (self.Scale or 1))
            Animation.Tween(root, "Slide", { Position = UDim2.fromScale(0.5, 0.5) })
        end
        local scale = self.Root:FindFirstChildOfClass("UIScale")
        if scale then
            scale.Scale = (self.Scale or 1) * 0.97
            Animation.Tween(scale, "Slide", { Scale = self.Scale or 1 })
        end
    else
        local position = root.Position
        Animation.Tween(root, "Fade", { Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset - SLIDE / (self.Scale or 1)) })
        local scale = self.Root:FindFirstChildOfClass("UIScale")
        if scale then Animation.Tween(scale, "Fade", { Scale = (self.Scale or 1) * 0.97 }) end
        task.delay((Animation.Curve.Fade.Time / math.max(Animation.Speed, 1)) + 0.02, function()
            if not self.Visible then
                root.Visible = false
                root.Position = self.Interface.Position and UDim2.new(0.5, self.Interface.Position[1], 0.5, self.Interface.Position[2]) or UDim2.fromScale(0.5, 0.5)
            end
        end)
    end
    if self.Overlays then self.Overlays:SetVisible(show) end
end

function Window:SetMinimized(minimized)
    if minimized then
        self.Root.Visible = false
        self.Library:Notify({
            Title = self.Def.Title or "UnWrittenUI",
            Content = "Minimized · press " .. Util.KeyLabel(self.MenuBinding.Key or "RightShift"),
            Duration = 3,
            Buttons = { { Title = "Restore", Callback = function() self:SetMinimized(false) end } },
        })
    else
        self.Root.Visible = true
        self:SetVisible(true)
    end
end

function Window:SetCompact(compact)
    self.Interface.Compact = compact and true or false
    self:_setCompactLayout(self.Interface.Compact)
    self:SaveState()
end

function Window:_setCompactLayout(compact)
    local width = compact and 60 or self.SidebarWidth
    self.Sidebar.Size = UDim2.new(0, width, 1, 0)
    self.Content.Position = UDim2.fromOffset(width + 1, 0)
    self.Content.Size = UDim2.new(1, -(width + 1), 1, 0)
    for _, button in self._navButtons or {} do
        for _, child in button:GetChildren() do
            if child:IsA("TextLabel") then child.Visible = not compact end
        end
    end
end

function Window:IsCompact()
    return self.Interface.Compact == true
end

function Window:Modules()
    local out = {}
    for _, tab in self.Tabs do
        for _, module in tab:Modules() do table.insert(out, module) end
    end
    return out
end

function Window:LoadAutoload()
    local ok = self.Config:LoadAutoload()
    return ok
end

-- dialogs, menus, notifications ---------------------------------------------

function Window:Dialog(def)
    return Dialog.Show(self, def)
end

function Window:Menu(items, opts)
    opts = opts or {}
    local menu = Popup.Menu(items, { Point = opts.Point, Anchor = opts.Anchor, Width = opts.Width or 190 })
    menu:Show()
    return menu
end

function Window:Notify(options)
    return self.Library:Notify(options)
end

function Window:Panel(def)
    local Panel = import("Components/Panel")
    local panel = Panel.new(self, def or {})
    table.insert(self.Panels, panel)
    return panel
end

function Window:ScreenButton(def)
    local ScreenButton = import("Components/ScreenButton")
    local button = ScreenButton.new(self, def or {})
    table.insert(self.ScreenButtons, button)
    return button
end

function Window:SetScreenButtonStyle(scale, transparency)
    for _, button in self.ScreenButtons do
        button:SetScale((scale or 100) / 100)
        button:SetTransparency((transparency or 0) / 100)
    end
    self.Interface.ButtonScale = scale or 100
    self.Interface.ButtonTransparency = transparency or 0
    self:SaveState()
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, panel in self.Panels do pcall(function() panel:Destroy() end) end
    for _, button in self.ScreenButtons do pcall(function() button:Destroy() end) end
    self.Maid:Clean()
    if self.MenuBinding then self.MenuBinding:Destroy() end
    self.Changed:Destroy()
end

return Window
end

__modules["Core/Animation"] = function(...)
local import = ...
local Signal = import("Core/Signal")

-- every animation curve the library uses; call Animation.Tween(inst, time, goal, "Style")
local Animation = {}

Animation.Style = {
    Linear = Enum.EasingStyle.Linear,
    Sine = Enum.EasingStyle.Sine,
    Quad = Enum.EasingStyle.Quad,
    Cubic = Enum.EasingStyle.Cubic,
    Quart = Enum.EasingStyle.Quart,
    Quint = Enum.EasingStyle.Quint,
    Expo = Enum.EasingStyle.Expo,
    Circ = Enum.EasingStyle.Circ,
    Back = Enum.EasingStyle.Back,
    Elastic = Enum.EasingStyle.Elastic,
    Bounce = Enum.EasingStyle.Bounce,
}

Animation.Direction = {
    In = Enum.EasingDirection.In,
    Out = Enum.EasingDirection.Out,
    InOut = Enum.EasingDirection.InOut,
}

-- curves used by the UI, so the feel stays consistent
Animation.Curve = {
    Hover = { Time = 0.14, Style = "Quad", Direction = "Out" },
    Press = { Time = 0.1, Style = "Quad", Direction = "Out" },
    Toggle = { Time = 0.22, Style = "Quint", Direction = "Out" },
    Fold = { Time = 0.28, Style = "Quint", Direction = "Out" },
    Slide = { Time = 0.34, Style = "Quint", Direction = "Out" },
    Pop = { Time = 0.24, Style = "Back", Direction = "Out" },
    Fade = { Time = 0.2, Style = "Sine", Direction = "Out" },
    Pulse = { Time = 0.5, Style = "Sine", Direction = "InOut" },
    Bounce = { Time = 0.4, Style = "Bounce", Direction = "Out" },
}

function Animation.Resolve(curve)
    if type(curve) == "string" then return Animation.Curve[curve] or Animation.Curve.Fade end
    return curve or Animation.Curve.Fade
end

-- speed < 0 means instant; the theme sets AnimSpeed (0 turns every animation off)
Animation.Speed = 1

function Animation.Tween(inst, curve, goal)
    if not inst or not inst.Parent then return nil end
    local spec = Animation.Resolve(curve)
    local speed = Animation.Speed
    if speed <= 0 or spec.Time <= 0 then
        for key, value in goal do
            pcall(function() inst[key] = value end)
        end
        return nil
    end
    local tween = import("Core/Services").TweenService:Create(
        inst,
        TweenInfo.new(spec.Time / speed, Animation.Style[spec.Style], Animation.Direction[spec.Direction]),
        goal
    )
    tween:Play()
    return tween
end

-- pops an instance in: scale from small + fade, used on every view that mounts
function Animation.PopIn(inst, curve, fromScale)
    if not inst then return end
    local scale = inst:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Parent = inst
        scale.Scale = 0.96
        task.defer(function()
            if scale.Parent then Animation.Tween(scale, curve or "Pop", { Scale = 1 }) end
        end)
    end
    return scale
end

-- a soft pulse on an instance's BackgroundTransparency or ImageTransparency
function Animation.Flash(inst, property, onValue, base, curve)
    if not inst or not inst.Parent then return end
    property = property or "BackgroundTransparency"
    Animation.Tween(inst, curve or { Time = 0.08, Style = "Quad", Direction = "Out" }, { [property] = onValue })
    task.delay(0.12, function()
        if inst.Parent then Animation.Tween(inst, curve or "Fade", { [property] = base }) end
    end)
end

-- calls fn every `interval` seconds on Heartbeat; returns a connection
function Animation.Loop(interval, fn)
    local acc = 0
    return import("Core/Services").RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc >= interval then
            acc = 0
            local ok, err = pcall(fn)
            if not ok then warn("[UnWrittenUI] loop: " .. tostring(err)) end
        end
    end)
end

-- generic spring-ish number animator for sliders and switches that need per-frame values
function Animation.NewRunner()
    local runner = { Speed = 12, Value = nil, Target = nil, Connection = nil, Changed = Signal.new() }
    function runner:Kick(target)
        self.Target = target
        if not self.Connection then
            self.Connection = import("Core/Services").RunService.Heartbeat:Connect(function(dt)
                local speed = Animation.Speed
                if speed <= 0 then
                    self.Value = self.Target
                else
                    self.Value += (self.Target - self.Value) * math.min(dt * self.Speed * speed, 1)
                end
                self.Changed:Fire(self.Value)
                if math.abs(self.Target - self.Value) < 0.001 then
                    self.Value = self.Target
                    self.Connection:Disconnect()
                    self.Connection = nil
                end
            end)
        end
    end
    return runner
end

return Animation
end

__modules["Core/Binding"] = function(...)
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
end

__modules["Core/Config"] = function(...)
local import = ...
local Storage = import("Core/Storage")
local Signal = import("Core/Signal")

-- flag registry + named config files under <Folder>/configs. Import / export also work with a plain
-- json string, so a setup can be shared between users.
local Config = {}
Config.__index = Config

local INVALID = '[\\/:%*%?"<>|]'

function Config.new(folder)
    local self = setmetatable({
        Folder = folder,
        Dir = folder .. "/configs",
        Flags = {},
        Current = nil,
        AutoSave = false,
        Changed = Signal.new(),
        Loaded = Signal.new(),
        _loading = false,
        _saveQueued = false,
        _pending = {},
    }, Config)
    Storage.Ensure(self.Dir)
    return self
end

function Config.ValidName(name)
    if type(name) ~= "string" then return false, "Enter a name." end
    name = name:match("^%s*(.-)%s*$")
    if name == "" then return false, "Enter a name." end
    if #name > 48 then return false, "Name is too long." end
    if name:find(INVALID) then return false, "Name contains invalid characters." end
    return true, name
end

function Config:Register(flag, element)
    if self.Flags[flag] and self.Flags[flag] ~= element then
        warn("[UnWrittenUI] duplicate flag '" .. flag .. "', the newer element wins")
    end
    self.Flags[flag] = element
    -- a config was loaded before this element existed: apply its value now
    local value = self._pending[flag]
    if value ~= nil then
        self._loading = true
        pcall(element.Load, element, value)
        self._loading = false
        self._pending[flag] = nil
    end
end

function Config:Unregister(flag, element)
    if self.Flags[flag] == element then self.Flags[flag] = nil end
end

function Config:Snapshot()
    local flags = {}
    for flag, element in self.Flags do
        if not element.NoSave then
            local ok, value = pcall(element.Save, element)
            if ok and value ~= nil then
                flags[flag] = value
            elseif not ok then
                warn("[UnWrittenUI] save " .. flag .. ": " .. tostring(value))
            end
        end
    end
    return { Version = 1, Flags = flags }
end

function Config:Apply(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.Flags) ~= "table" then return false, "Invalid config data." end
    self._loading = true
    self._pending = {}
    for flag, value in snapshot.Flags do
        local element = self.Flags[flag]
        if element and not element.NoSave then
            local ok, err = pcall(element.Load, element, value)
            if not ok then warn("[UnWrittenUI] load " .. flag .. ": " .. tostring(err)) end
        else
            -- elements are often added after the config loads; keep the value for them
            self._pending[flag] = value
        end
    end
    self._loading = false
    self.Loaded:Fire(snapshot)
    return true
end

function Config:Path(name)
    return self.Dir .. "/" .. name .. ".json"
end

function Config:List()
    return Storage.List(self.Dir, "json")
end

function Config:Exists(name)
    return Storage.Exists(self:Path(name))
end

function Config:Save(name)
    local ok, clean = Config.ValidName(name or self.Current)
    if not ok then return false, clean end
    if not Storage.Available then return false, "File access is not supported by this executor." end
    if not Storage.WriteJSON(self:Path(clean), self:Snapshot()) then return false, "Could not write the file." end
    self.Current = clean
    self.Changed:Fire()
    return true, clean
end

function Config:Load(name)
    local ok, clean = Config.ValidName(name)
    if not ok then return false, clean end
    local data = Storage.ReadJSON(self:Path(clean))
    if not data then return false, "Config not found." end
    local applied, err = self:Apply(data)
    if not applied then return false, err end
    self.Current = clean
    self.Changed:Fire("load")
    return true, clean
end

function Config:Delete(name)
    local ok, clean = Config.ValidName(name)
    if not ok then return false, clean end
    if not self:Exists(clean) then return false, "Config not found." end
    Storage.Delete(self:Path(clean))
    if self.Current == clean then self.Current = nil end
    if self:GetAutoload() == clean then self:SetAutoload(nil) end
    self.Changed:Fire()
    return true, clean
end

function Config:Rename(old, new)
    local okOld, from = Config.ValidName(old)
    if not okOld then return false, from end
    local okNew, to = Config.ValidName(new)
    if not okNew then return false, to end
    if from == to then return true, to end
    local content = Storage.Read(self:Path(from))
    if not content then return false, "Config not found." end
    if self:Exists(to) then return false, "A config with that name exists." end
    if not Storage.Write(self:Path(to), content) then return false, "Could not write the file." end
    Storage.Delete(self:Path(from))
    if self.Current == from then self.Current = to end
    if self:GetAutoload() == from then self:SetAutoload(to) end
    self.Changed:Fire()
    return true, to
end

function Config:GetAutoload()
    local name = Storage.Read(self.Dir .. "/autoload.txt")
    if name and name ~= "" and self:Exists(name) then return name end
    return nil
end

function Config:SetAutoload(name)
    if name then
        Storage.Write(self.Dir .. "/autoload.txt", name)
    else
        Storage.Delete(self.Dir .. "/autoload.txt")
    end
    self.Changed:Fire()
end

function Config:LoadAutoload()
    local name = self:GetAutoload()
    if name then return self:Load(name) end
    return false, "No autoload config."
end

-- json text of everything with a flag, ready to paste somewhere else
function Config:Export()
    return Storage.Encode(self:Snapshot())
end

function Config:Import(text)
    local data = type(text) == "string" and Storage.Decode(text)
    if not data then return false, "Not a valid config." end
    return self:Apply(data)
end

function Config:ExportConfig(name)
    local ok, clean = Config.ValidName(name)
    if not ok then return nil, clean end
    local data = Storage.ReadJSON(self:Path(clean))
    if not data then return nil, "Config not found." end
    return Storage.Encode(data)
end

-- the text a hub shows when a user shares a config; paste it into an import box
function Config:ShareCode(name)
    local json, err = self:ExportConfig(name or self.Current)
    if not json then return nil, err end
    return "-- UnWrittenUI config: " .. (name or self.Current or "shared") .. "\n" .. json
end

-- called by elements on every change; debounced save into the current config
function Config:Touch()
    if self._loading or not self.AutoSave or not self.Current or self._saveQueued then return end
    self._saveQueued = true
    task.delay(1, function()
        self._saveQueued = false
        if self.AutoSave and self.Current then self:Save(self.Current) end
    end)
end

return Config
end

__modules["Core/Icons"] = function(...)
-- lucide subset; regenerate with build/icons.mjs, extend at runtime with Library:AddIcons
return {
    ["activity"]                  = "rbxassetid://94212016861936",
    ["alarm-clock"]               = "rbxassetid://126259032907535",
    ["arrow-down"]                = "rbxassetid://98764963621439",
    ["arrow-left"]                = "rbxassetid://102531941843733",
    ["arrow-right"]               = "rbxassetid://113692007244654",
    ["arrow-up"]                  = "rbxassetid://89282378235317",
    ["arrow-up-down"]             = "rbxassetid://81019887641527",
    ["badge-check"]               = "rbxassetid://76078495178149",
    ["ban"]                       = "rbxassetid://90767043015246",
    ["bell"]                      = "rbxassetid://97392696311902",
    ["bell-off"]                  = "rbxassetid://78560046118930",
    ["bell-ring"]                 = "rbxassetid://94612128913941",
    ["blocks"]                    = "rbxassetid://72212693357737",
    ["bolt"]                      = "rbxassetid://102881251417484",
    ["book-open"]                 = "rbxassetid://129845326810392",
    ["box"]                       = "rbxassetid://101768155599700",
    ["braces"]                    = "rbxassetid://117761094704041",
    ["brush"]                     = "rbxassetid://127035535799640",
    ["bug"]                       = "rbxassetid://83626408925438",
    ["calendar"]                  = "rbxassetid://114792700814035",
    ["camera"]                    = "rbxassetid://79950339943067",
    ["check"]                     = "rbxassetid://93898873302694",
    ["check-check"]               = "rbxassetid://95183312173858",
    ["chevron-down"]              = "rbxassetid://134243273101015",
    ["chevron-left"]              = "rbxassetid://73780377692148",
    ["chevron-right"]             = "rbxassetid://92473583511724",
    ["chevron-up"]                = "rbxassetid://122444883127455",
    ["chevrons-up-down"]          = "rbxassetid://131833120209646",
    ["circle"]                    = "rbxassetid://130359823580534",
    ["circle-check"]              = "rbxassetid://85262178816537",
    ["circle-dot"]                = "rbxassetid://82947033619201",
    ["circle-plus"]               = "rbxassetid://113157136350384",
    ["circle-question-mark"]      = "rbxassetid://97516698664325",
    ["circle-x"]                  = "rbxassetid://76821953846248",
    ["clipboard-paste"]           = "rbxassetid://74382068849983",
    ["clock"]                     = "rbxassetid://121808839832144",
    ["code"]                      = "rbxassetid://107380207681249",
    ["columns-2"]                 = "rbxassetid://113004100221850",
    ["command"]                   = "rbxassetid://93648221906330",
    ["compass"]                   = "rbxassetid://115123411028382",
    ["copy"]                      = "rbxassetid://78979572434545",
    ["cpu"]                       = "rbxassetid://77549309870247",
    ["crosshair"]                 = "rbxassetid://134242818164054",
    ["database"]                  = "rbxassetid://126791525623846",
    ["download"]                  = "rbxassetid://134814648082393",
    ["ellipsis"]                  = "rbxassetid://140019550645825",
    ["eraser"]                    = "rbxassetid://133957773112410",
    ["eye"]                       = "rbxassetid://100033680381365",
    ["eye-off"]                   = "rbxassetid://135928786788378",
    ["file"]                      = "rbxassetid://74748492079329",
    ["file-code"]                 = "rbxassetid://130978036895504",
    ["flag"]                      = "rbxassetid://78183383236196",
    ["flame"]                     = "rbxassetid://98218034436456",
    ["folder"]                    = "rbxassetid://80846616596607",
    ["folder-open"]               = "rbxassetid://76018996254888",
    ["gauge"]                     = "rbxassetid://110273524101447",
    ["gift"]                      = "rbxassetid://109855212076373",
    ["grip-vertical"]             = "rbxassetid://137183678565296",
    ["hammer"]                    = "rbxassetid://83545120140895",
    ["hand"]                      = "rbxassetid://130703864968637",
    ["hard-drive"]                = "rbxassetid://88183305858463",
    ["heart"]                     = "rbxassetid://116559368303288",
    ["history"]                   = "rbxassetid://123980022019922",
    ["house"]                     = "rbxassetid://98755624629571",
    ["image"]                     = "rbxassetid://112751259236831",
    ["info"]                      = "rbxassetid://124560466474914",
    ["key"]                       = "rbxassetid://96510194465420",
    ["keyboard"]                  = "rbxassetid://121474456068237",
    ["laptop"]                    = "rbxassetid://111387063244975",
    ["layers"]                    = "rbxassetid://81973586053257",
    ["layout-grid"]               = "rbxassetid://81344910161871",
    ["layout-list"]               = "rbxassetid://87462136296578",
    ["layout-panel-left"]         = "rbxassetid://125092469751491",
    ["library"]                   = "rbxassetid://114334671982047",
    ["link"]                      = "rbxassetid://131607023382430",
    ["list"]                      = "rbxassetid://113179976918783",
    ["list-filter"]               = "rbxassetid://103321376129527",
    ["list-filter-plus"]          = "rbxassetid://96385120752336",
    ["loader"]                    = "rbxassetid://78408734580845",
    ["lock"]                      = "rbxassetid://134724289526879",
    ["lock-open"]                 = "rbxassetid://93597915325122",
    ["log-in"]                    = "rbxassetid://103768533135201",
    ["log-out"]                   = "rbxassetid://84895399304975",
    ["maximize"]                  = "rbxassetid://76045941763188",
    ["message-circle"]            = "rbxassetid://127255077587058",
    ["message-square"]            = "rbxassetid://83881670383280",
    ["mic"]                       = "rbxassetid://89640799126523",
    ["minimize"]                  = "rbxassetid://121304296213645",
    ["minus"]                     = "rbxassetid://118026365011536",
    ["monitor"]                   = "rbxassetid://72664649203050",
    ["moon"]                      = "rbxassetid://83380517901735",
    ["mouse"]                     = "rbxassetid://73096068864710",
    ["move"]                      = "rbxassetid://116138709011735",
    ["move-3d"]                   = "rbxassetid://103365982054003",
    ["music"]                     = "rbxassetid://113343203848535",
    ["navigation"]                = "rbxassetid://79308213542922",
    ["orbit"]                     = "rbxassetid://108926136860562",
    ["package"]                   = "rbxassetid://97261141732706",
    ["paintbrush"]                = "rbxassetid://125572663700289",
    ["palette"]                   = "rbxassetid://86350350950064",
    ["paperclip"]                 = "rbxassetid://92088291163453",
    ["pause"]                     = "rbxassetid://74873705394436",
    ["pencil"]                    = "rbxassetid://137986121120732",
    ["pin"]                       = "rbxassetid://120978111007514",
    ["play"]                      = "rbxassetid://135609604299893",
    ["plug"]                      = "rbxassetid://99782373064495",
    ["plus"]                      = "rbxassetid://111774323017047",
    ["power"]                     = "rbxassetid://96479131758775",
    ["radio"]                     = "rbxassetid://85611589536956",
    ["refresh-cw"]                = "rbxassetid://138133190015277",
    ["repeat"]                    = "rbxassetid://121886242955173",
    ["rotate-ccw"]                = "rbxassetid://110116685948665",
    ["rotate-cw"]                 = "rbxassetid://84183336178654",
    ["save"]                      = "rbxassetid://126116963775616",
    ["scan"]                      = "rbxassetid://123104789658180",
    ["scroll"]                    = "rbxassetid://74072101474951",
    ["search"]                    = "rbxassetid://121018724060431",
    ["send"]                      = "rbxassetid://127751956873796",
    ["settings"]                  = "rbxassetid://80758916183665",
    ["settings-2"]                = "rbxassetid://135684703553372",
    ["share"]                     = "rbxassetid://87340985053299",
    ["share-2"]                   = "rbxassetid://71210767962065",
    ["shield"]                    = "rbxassetid://110987169760162",
    ["shield-alert"]              = "rbxassetid://114995877719925",
    ["shield-check"]              = "rbxassetid://87354736164608",
    ["shuffle"]                   = "rbxassetid://132382786975101",
    ["signal"]                    = "rbxassetid://78424889355261",
    ["sliders-horizontal"]        = "rbxassetid://85538382643347",
    ["smartphone"]                = "rbxassetid://96623008834511",
    ["sparkles"]                  = "rbxassetid://138635884129147",
    ["square"]                    = "rbxassetid://86304921356806",
    ["square-arrow-out-up-right"] = "rbxassetid://91221896066807",
    ["square-check"]              = "rbxassetid://134682053539509",
    ["square-pen"]                = "rbxassetid://120239476110475",
    ["star"]                      = "rbxassetid://136141469398409",
    ["sun"]                       = "rbxassetid://110150589884127",
    ["swords"]                    = "rbxassetid://81872698913435",
    ["table"]                     = "rbxassetid://109109148250737",
    ["tag"]                       = "rbxassetid://129104970103940",
    ["tags"]                      = "rbxassetid://107179263080798",
    ["target"]                    = "rbxassetid://87563802520297",
    ["terminal"]                  = "rbxassetid://106783148545356",
    ["test-tube"]                 = "rbxassetid://98801015650164",
    ["thumbs-up"]                 = "rbxassetid://111137070767020",
    ["timer"]                     = "rbxassetid://85473888890506",
    ["toggle-left"]               = "rbxassetid://85887872573050",
    ["toggle-right"]              = "rbxassetid://90411952142550",
    ["trash-2"]                   = "rbxassetid://109843431391323",
    ["trending-up"]               = "rbxassetid://81819858538839",
    ["triangle-alert"]            = "rbxassetid://125920361880643",
    ["trophy"]                    = "rbxassetid://131545003268773",
    ["tv"]                        = "rbxassetid://135687724791776",
    ["type"]                      = "rbxassetid://133543553793564",
    ["undo-2"]                    = "rbxassetid://113885292059932",
    ["unplug"]                    = "rbxassetid://90171381619874",
    ["upload"]                    = "rbxassetid://138212042425501",
    ["user"]                      = "rbxassetid://81589895647169",
    ["user-check"]                = "rbxassetid://81775205032725",
    ["users"]                     = "rbxassetid://115398113982385",
    ["variable"]                  = "rbxassetid://104743088438151",
    ["volume"]                    = "rbxassetid://103236289817396",
    ["volume-2"]                  = "rbxassetid://89344380902620",
    ["volume-x"]                  = "rbxassetid://139252359189540",
    ["wand"]                      = "rbxassetid://114580617777835",
    ["wand-sparkles"]             = "rbxassetid://82546429942392",
    ["wifi"]                      = "rbxassetid://104669375183960",
    ["wind"]                      = "rbxassetid://114551690399915",
    ["wrench"]                    = "rbxassetid://112148279212860",
    ["x"]                         = "rbxassetid://110786993356448",
    ["zap"]                       = "rbxassetid://130551565616516",
    ["zoom-in"]                   = "rbxassetid://127956924984803",
    ["zoom-out"]                  = "rbxassetid://108334162607319",
}
end

__modules["Core/Keybinds"] = function(...)
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
end

__modules["Core/Maid"] = function(...)
local _ = ...

-- collects connections, instances, functions and objects; Clean releases them newest first
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(item)
    if item == nil then return item end
    table.insert(self._tasks, item)
    return item
end

local function release(item)
    local kind = typeof(item)
    if kind == "RBXScriptConnection" then
        item:Disconnect()
    elseif kind == "Instance" then
        item:Destroy()
    elseif kind == "function" then
        item()
    elseif kind == "thread" then
        pcall(task.cancel, item)
    elseif kind == "table" then
        if type(item.Disconnect) == "function" then
            item:Disconnect()
        elseif type(item.Clean) == "function" then
            item:Clean()
        elseif type(item.Destroy) == "function" then
            item:Destroy()
        end
    end
end

function Maid:Clean()
    local tasks = self._tasks
    self._tasks = {}
    for index = #tasks, 1, -1 do
        local ok, err = pcall(release, tasks[index])
        if not ok then warn("[UnWrittenUI] cleanup: " .. tostring(err)) end
    end
end

Maid.Destroy = Maid.Clean

return Maid
end

__modules["Core/Router"] = function(...)
local import = ...
local Services = import("Core/Services")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

-- one place for every pointer interaction: click, right click, double click, long press and dragging.
-- Works with mouse and touch, fires a click only when the pointer did not travel, and keeps a drag going
-- when the pointer leaves the element.
local Router = {
    Threshold = 5,       -- px a pointer may travel and still count as a click
    HoldTime = 0.5,      -- s a still press becomes a long press
    DoubleTime = 0.35,   -- s between two clicks that make a double click
    Capture = false,     -- a keybind is waiting for a key: pointer clicks do not activate the menu
    OpenPopups = {},     -- popups close when a press lands outside them
}

local UIS = Services.UserInputService

local POINTERS = {
    [Enum.UserInputType.MouseButton1] = true,
    [Enum.UserInputType.Touch] = true,
}
local RIGHT = {
    [Enum.UserInputType.MouseButton2] = true,
}
local MIDDLE = {
    [Enum.UserInputType.MouseButton3] = true,
}

-- closes the newest open popup when the click is outside all of them
local function closePopups(point)
    if #Router.OpenPopups == 0 then return end
    for index = #Router.OpenPopups, 1, -1 do
        local popup = Router.OpenPopups[index]
        if popup and popup.IsOpen and popup:IsOpen() then
            if not popup:ContainsPoint(point) then
                popup:Close()
                return
            end
            return
        end
        table.remove(Router.OpenPopups, index)
    end
end

function Router.RegisterPopup(popup)
    table.insert(Router.OpenPopups, popup)
end

function Router.UnregisterPopup(popup)
    local index = table.find(Router.OpenPopups, popup)
    if index then table.remove(Router.OpenPopups, index) end
end

-- a click landed anywhere on screen at point (used for popups and the keybind capture cancel)
function Router.Clicked(point)
    closePopups(point)
    import("Core/Keybinds").Clicked()
end

local function absolutePoint(gui)
    local position = gui.AbsolutePosition
    local size = gui.AbsoluteSize
    return Vector2.new(position.X + size.X / 2, position.Y + size.Y / 2)
end

-- opts: OnClick, OnRightClick, OnMiddleClick, OnPress, OnRelease, OnDoubleClick,
--       OnDrag(delta, total), OnDragStart, OnDragEnd, Disabled, Tooltip, Cursor, Hold = { Time, Callback }
function Router.Attach(gui, opts)
    opts = opts or {}
    local handle = { Enabled = true, Pressed = false, Destroyed = false }
    local pressedInput, startPos, lastPos, moved, held, holdThread = nil, nil, nil, false, false, nil
    local lastClick, lastClickPos = -10, nil

    local function disabled()
        if not handle.Enabled or Router.Capture then return true end
        local check = opts.Disabled
        if type(check) == "function" then
            local ok, result = pcall(check)
            return ok and result == true
        end
        return check == true
    end

    local function cancelHold()
        if holdThread then
            pcall(task.cancel, holdThread)
            holdThread = nil
        end
    end

    local function begin(input)
        if disabled() then return end
        local isLeft, isRight, isMiddle = POINTERS[input.UserInputType], RIGHT[input.UserInputType], MIDDLE[input.UserInputType]
        if not (isLeft or isRight or isMiddle) then return end
        if isRight then
            if opts.OnRightClick then
                opts.OnRightClick(Vector2.new(input.Position.X, input.Position.Y))
                Router.Clicked(Vector2.new(input.Position.X, input.Position.Y))
            end
            return
        end
        if isMiddle then
            if opts.OnMiddleClick then opts.OnMiddleClick(Vector2.new(input.Position.X, input.Position.Y)) end
            return
        end
        if not isLeft then return end
        pressedInput = input.UserInputType
        startPos = Vector2.new(input.Position.X, input.Position.Y)
        lastPos = startPos
        moved = false
        held = false
        handle.Pressed = true
        if opts.OnPress then opts.OnPress(input, startPos) end
        if opts.Hold then
            local holdTime = (opts.Hold.Time or Router.HoldTime)
            holdThread = task.delay(holdTime, function()
                holdThread = nil
                if not handle.Pressed or moved or handle.Destroyed then return end
                held = true
                if opts.Hold.Callback then opts.Hold.Callback(absolutePoint(gui)) end
            end)
        end
    end

    local function track(input)
        if not handle.Pressed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if not moved then
            local delta = point - startPos
            if delta.Magnitude < Router.Threshold then
                lastPos = point
                return
            end
            moved = true
            cancelHold()
            if opts.OnDragStart then pcall(opts.OnDragStart, startPos) end
        end
        if opts.OnDrag then
            local delta = point - lastPos
            lastPos = point
            local ok, err = pcall(opts.OnDrag, delta, point, startPos)
            if not ok then warn("[UnWrittenUI] drag: " .. tostring(err)) end
        else
            lastPos = point
        end
    end

    local function finish(input)
        if not handle.Pressed then return end
        if input.UserInputType ~= pressedInput then return end
        handle.Pressed = false
        cancelHold()
        pressedInput = nil
        if moved then
            if opts.OnDragEnd then pcall(opts.OnDragEnd, lastPos) end
            if opts.OnRelease then opts.OnRelease() end
            return
        end
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if held then
            held = false
            if opts.OnRelease then opts.OnRelease() end
            return
        end
        if opts.OnClick then
            local now = os.clock()
            local isDouble = opts.OnDoubleClick and lastClickPos and (now - lastClick) <= Router.DoubleTime
                and (point - lastClickPos).Magnitude <= 12
            lastClick, lastClickPos = now, point
            if isDouble then
                lastClick = -10
                local ok, err = pcall(opts.OnDoubleClick, point)
                if not ok then warn("[UnWrittenUI] double click: " .. tostring(err)) end
            else
                local ok, err = pcall(opts.OnClick, point, input)
                if not ok then warn("[UnWrittenUI] click: " .. tostring(err)) end
            end
        end
        Router.Clicked(point)
        if opts.OnRelease then opts.OnRelease() end
    end

    local beganConnection = gui.InputBegan:Connect(begin)
    local endedConnection = gui.InputEnded:Connect(finish)
    -- pointer may leave the element mid-drag: listen globally while a press is live
    local globalChanged = UIS.InputChanged:Connect(function(input)
        if handle.Pressed then track(input) end
    end)
    local globalEnded = UIS.InputEnded:Connect(function(input)
        if handle.Pressed then finish(input) end
    end)

    local hoverLeave
    if opts.Tooltip then
        local Tooltip = import("Components/Tooltip")
        local connection
        local enter = gui.MouseEnter:Connect(function()
            if disabled() then return end
            connection = Tooltip.Attach(gui, opts.Tooltip)
        end)
        hoverLeave = { enter, leave = gui.MouseLeave:Connect(function()
            if connection then connection:Disconnect() connection = nil end
            Tooltip.HideFor(gui)
        end) }
    end

    if opts.Cursor and gui:IsA("GuiObject") then
        gui.MouseEnter:Connect(function()
            if not disabled() then
                gui.MouseIcon = opts.Cursor
            end
        end)
    end

    function handle:SetEnabled(enabled)
        self.Enabled = enabled and true or false
        if not self.Enabled then handle.Pressed = false cancelHold() end
    end

    function handle:IsPressed()
        return handle.Pressed
    end

    function handle:Destroy()
        handle.Destroyed = true
        handle.Pressed = false
        cancelHold()
        beganConnection:Disconnect()
        endedConnection:Disconnect()
        globalChanged:Disconnect()
        globalEnded:Disconnect()
        if hoverLeave then
            hoverLeave.enter:Disconnect()
            hoverLeave.leave:Disconnect()
        end
    end

    return handle
end

-- press visual: dims the background of a button while the pointer is down
function Router.Feedback(gui, baseToken, pressedToken)
    local down = false
    local handle = Router.Attach(gui, {
        OnPress = function()
            down = true
            Util.Tween(gui, 0.08, { BackgroundTransparency = pressedToken or 0.15 })
        end,
        OnRelease = function()
            down = false
            local Theme = import("Core/Theme")
            local token = baseToken or "ElevatedTransparency"
            Util.Tween(gui, 0.18, { BackgroundTransparency = Theme.Current[token] or 0.1 })
        end,
    })
    return handle
end

return Router
end

__modules["Core/Services"] = function(...)
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
end

__modules["Core/Signal"] = function(...)
local _ = ...

-- synchronous signal; handlers run in connect order, errors are reported and do not stop the rest
local Signal = {}
Signal.__index = Signal

local function report(err)
    warn("[UnWrittenUI] signal handler: " .. tostring(err))
end

function Signal.new()
    return setmetatable({ _handlers = {}, _firing = 0 }, Signal)
end

function Signal:Connect(fn)
    local handler = { fn = fn, live = true }
    table.insert(self._handlers, handler)
    local handlers = self._handlers
    local connection = { Connected = true }
    function connection:Disconnect()
        if not handler.live then return end
        handler.live = false
        self.Connected = false
        if handlers._firing == nil or handlers._firing == 0 then
            local index = table.find(handlers, handler)
            if index then table.remove(handlers, index) end
        else
            -- removed on the next fire so iterating handlers stays safe
            handler.dead = true
        end
    end
    return connection
end

function Signal:Once(fn)
    local connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        fn(...)
    end)
    return connection
end

function Signal:Fire(...)
    local handlers = self._handlers
    for _, handler in handlers do
        if handler.live then
            local ok, err = pcall(handler.fn, ...)
            if not ok then report(err) end
        end
    end
    if self._firing > 0 then return end
    -- sweep dead handlers once the outermost fire is done
    for index = #handlers, 1, -1 do
        if handlers[index].dead then table.remove(handlers, index) end
    end
end

function Signal:DisconnectAll()
    for _, handler in self._handlers do handler.live = false end
    table.clear(self._handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
end

__modules["Core/Storage"] = function(...)
local import = ...
local Services = import("Core/Services")

-- executor file api; everything degrades to no-ops when it is missing
local Storage = {}

Storage.Available = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    and type(makefolder) == "function" and type(isfolder) == "function"

local writefile = writefile
local readfile = readfile
local isfile = isfile
local isfolder = isfolder
local makefolder = makefolder
local delfile = delfile
local listfiles = listfiles

function Storage.Ensure(path)
    if not Storage.Available then return false end
    if path == "" or path == nil then return true end
    local built = ""
    for part in tostring(path):gmatch("[^/]+") do
        built = built == "" and part or (built .. "/" .. part)
        if not isfolder(built) then pcall(makefolder, built) end
    end
    return true
end

function Storage.Read(path)
    if not Storage.Available then return nil end
    local ok, exists = pcall(isfile, path)
    if not ok or not exists then return nil end
    local read, content = pcall(readfile, path)
    if read and type(content) == "string" then return content end
    return nil
end

function Storage.Write(path, content)
    if not Storage.Available then return false end
    local folder = path:match("^(.*)/[^/]+$")
    if folder then Storage.Ensure(folder) end
    local ok, err = pcall(writefile, path, content)
    if not ok then warn("[UnWrittenUI] write " .. path .. ": " .. tostring(err)) end
    return ok
end

function Storage.Delete(path)
    if not Storage.Available or type(delfile) ~= "function" then return false end
    return (pcall(delfile, path))
end

function Storage.Exists(path)
    if not Storage.Available then return false end
    local ok, exists = pcall(isfile, path)
    return ok and exists
end

function Storage.IsFolder(path)
    if not Storage.Available then return false end
    local ok, exists = pcall(isfolder, path)
    return ok and exists
end

-- file names in folder with extension, without the extension
function Storage.List(folder, extension)
    if not Storage.Available or type(listfiles) ~= "function" then return {} end
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then return {} end
    local out = {}
    for _, file in files do
        local name = tostring(file):gsub("\\", "/"):match("([^/]+)%." .. (extension or "json") .. "$")
        if name then table.insert(out, name) end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

function Storage.Encode(data)
    local ok, content = pcall(function() return Services.HttpService:JSONEncode(data) end)
    return ok and content or nil
end

function Storage.Decode(content)
    if type(content) ~= "string" then return nil end
    local ok, data = pcall(function() return Services.HttpService:JSONDecode(content) end)
    return ok and data or nil
end

function Storage.ReadJSON(path)
    local content = Storage.Read(path)
    if not content then return nil end
    return Storage.Decode(content)
end

function Storage.WriteJSON(path, data)
    local content = Storage.Encode(data)
    if not content then
        warn("[UnWrittenUI] could not encode " .. tostring(path))
        return false
    end
    return Storage.Write(path, content)
end

-- reads a file with the executor's `readfile`, or HttpGet for a url
function Storage.Fetch(source)
    if type(source) == "string" and source:match("^https?://") then
        if type(game.HttpGet) == "function" then
            local ok, body = pcall(function() return game:HttpGet(source) end)
            return ok and body or nil
        end
        return nil
    end
    return Storage.Read(source)
end

return Storage
end

__modules["Core/Theme"] = function(...)
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
end

__modules["Core/Util"] = function(...)
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
end

__modules["Elements/Base"] = function(...)
local import = ...
local Signal = import("Core/Signal")
local Maid = import("Core/Maid")
local Util = import("Core/Util")

-- element model: holds the value; any number of views (a card, a panel, a group) render it and
-- all follow the same state
local Base = {}
Base.__index = Base

function Base.Class(kind)
    local class = setmetatable({ Kind = kind }, { __index = Base })
    class.__index = class
    return class
end

function Base.Init(self, container, def)
    def = def or {}
    self.Def = def
    self.Container = container
    self.Window = container.Window
    self.Module = container.Module or container
    self.View = container.View
    self.Title = def.Title or def.Name or def.Text or def.Placeholder or self.Kind
    self.Description = def.Description or def.Desc
    self.Tooltip = def.Tooltip
    self.Flag = def.Flag
    self.Changed = Signal.new()
    self.StateChanged = Signal.new()
    self.Locked = def.Locked == true
    self.LockReason = def.LockedReason or def.LockReason
    self.Visible = def.Visible ~= false
    self.NoSave = def.NoSave == true or def.Flag == nil
    self._listeners = {}
    self._mounts = {}
    if self.Flag and self.Window and self.Window.Config then
        self.Window.Config:Register(self.Flag, self)
        self.Window.Library.Flags[self.Flag] = self
    end
    return self
end

-- stores the value, repaints views, runs callbacks unless silent
function Base:_commit(value, silent)
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
    self.Window:_touch()
    self.Window:_checkDependents(self)
end

-- callback arguments; kinds with several values override this
function Base:_args()
    return self.Value
end

function Base:_notify()
    Util.Safe(self.Def.Callback, self:_args())
    for _, fn in self._listeners do Util.Safe(fn, self:_args()) end
end

function Base:Get()
    return self.Value
end

function Base:Set(value, silent)
    self:_commit(value, silent)
end

function Base:Reset()
    if self.Default ~= nil then
        local ok = pcall(self.Set, self, self.Default)
        if not ok then self:Set(self.Default) end
    end
end

function Base:OnChanged(fn)
    table.insert(self._listeners, fn)
    return self
end

function Base:SetTitle(text)
    self.Title = text
    self.StateChanged:Fire("Title")
end

function Base:SetDescription(text)
    self.Description = text
    self.StateChanged:Fire("Description")
end

function Base:SetLocked(locked, reason)
    self.Locked = locked and true or false
    self.LockReason = reason or self.LockReason
    self.StateChanged:Fire("Locked")
end

function Base:Lock(reason) self:SetLocked(true, reason) end
function Base:Unlock() self:SetLocked(false) end

function Base:SetVisible(visible)
    self.Visible = visible and true or false
    self.StateChanged:Fire("Visible")
end

-- keeps this element locked (or hidden) while predicate(source value) is false
function Base:DependsOn(source, predicate, mode)
    predicate = predicate or function(value)
        if type(value) == "boolean" then return value end
        if type(value) == "table" then return #value > 0 end
        return value ~= nil and value ~= false and value ~= ""
    end
    local function update()
        local ok, pass = pcall(predicate, source:Get())
        if not ok then pass = false end
        if mode == "Hide" then
            self:SetVisible(pass and true or false)
        else
            self:SetLocked(not pass, self.Def.LockedReason or ("Requires " .. tostring(source.Title)))
        end
    end
    source.Changed:Connect(update)
    source.StateChanged:Connect(function(state)
        if state then update() end
    end)
    update()
    return self
end

function Base:Matches(query)
    local text = (tostring(self.Title) .. " " .. tostring(self.Description or "")):lower()
    return text:find(query, 1, true) ~= nil
end

-- config save / load. Values are plain luau: booleans, numbers, strings, {r, g, b}, tables
function Base:Save()
    return self.Value
end

function Base:Load(value)
    if value == nil then return end
    local ok = pcall(self.Set, self, value)
    if not ok then pcall(self._commit, self, value, true) end
end

function Base:TrySet(...)
    if not self.Locked then return self:Set(...) end
end

-- called by containers for every view; Render is implemented per kind
function Base:Mount(parent, maid, order)
    local mount = Maid.new()
    maid:Give(mount)
    mount.Views = {}
    table.insert(self._mounts, mount)
    mount:Give(function()
        local index = table.find(self._mounts, mount)
        if index then table.remove(self._mounts, index) end
    end)
    local frame = self:Render(parent, mount)
    if frame then
        frame.LayoutOrder = order or 0
        frame.Visible = self.Visible and not self.Hidden
    end
    table.insert(mount.Views, frame)
    return frame
end

function Base:Destroy()
    for _, mount in table.clone(self._mounts) do mount:Clean() end
    if self.Flag and self.Window and self.Window.Config then
        self.Window.Config:Unregister(self.Flag, self)
        if self.Window.Library.Flags[self.Flag] == self then self.Window.Library.Flags[self.Flag] = nil end
    end
    if self.Binding then self.Binding:Destroy() end
    local children = self.Container.Children
    if children then
        local index = table.find(children, self)
        if index then table.remove(children, index) end
    end
    self.Changed:Destroy()
    self.StateChanged:Destroy()
end

-- A standard row used by most elements: title (+ description) on the left, control on the right.
-- Returns row, holder (the right side container), titleLabel
function Base.Row(kind, self, parent, opts)
    opts = opts or {}
    local Util = import("Core/Util")
    local Router = import("Core/Router")
    local Theme = import("Core/Theme")
    local row = Util.New("Frame", {
        Name = kind,
        Size = UDim2.new(1, -8, 0, opts.Height or 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Padding(row, 0, 4, 0, 4)
    local title = Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Position = UDim2.fromOffset(0, opts.Height and 6 or 0),
        Size = UDim2.new(1, -(opts.Reserve or 120), 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = row,
    })
    local description = nil
    if self.Description and self.Description ~= "" and opts.Description ~= false then
        title.Position = UDim2.fromOffset(0, 0)
        title.Size = UDim2.new(1, -(opts.Reserve or 120), 0, 17)
        row.Size = UDim2.new(1, -8, 0, 44)
        description = Util.Label({
            Text = self.Description,
            TextSize = 11,
            Position = UDim2.fromOffset(0, 18),
            Size = UDim2.new(1, -(opts.Reserve or 120), 0, 26),
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Color = "TextMuted",
            Parent = row,
        })
    end
    local holder = Util.New("Frame", {
        Name = "Holder",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(opts.Width or 60, opts.Height or 28),
        Parent = row,
    })
    if opts.Reserve then holder.Size = UDim2.fromOffset(opts.Reserve - 8, 28) end
    return row, holder, title, description
end

return Base
end

__modules["Elements/Button"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Widgets = import("Components/Widgets")
local Binding = import("Core/Binding")

-- Button: press, optional confirm, optional keybind. Styles: Default, Primary, Danger, Ghost.
local Button = Base.Class("Button")

function Button.new(container, def)
    local self = setmetatable({ Value = false }, Button)
    self.Default = false
    Base.Init(self, container, def)
    self.Style = def.Style or "Default"
    self.Confirm = def.Confirm
    if def.Keybind and def.Keybind ~= false then
        local spec = type(def.Keybind) == "table" and def.Keybind or { Key = def.Keybind ~= true and def.Keybind or def.Key }
        self.Binding = Binding.new({
            Key = spec.Key or spec.Default,
            Mode = "Always",
            Modes = { "Always" },
            Capture = spec,
            Press = function()
                if not self.Locked and self.Press then self:Press() end
            end,
        })
        self.Window:_trackBind(self)
    end
    return self
end

function Button:Press()
    if self.Locked then return end
    local function run()
        self.Changed:Fire(true)
        self.Window:_touch()
        Util.Safe(self.Def.Callback, self)
    end
    if self.Confirm then
        local message = type(self.Confirm) == "string" and self.Confirm or "Are you sure?"
        self.Window:Dialog({
            Title = self.Title,
            Content = message,
            Icon = "triangle-alert",
            Buttons = {
                { Title = "Cancel", Style = "Secondary" },
                { Title = "Confirm", Style = self.Style == "Danger" and "Danger" or "Primary", Callback = run },
            },
        })
        return
    end
    run()
end

function Button:Get() return nil end
function Button:Set() end
function Button:Save() return nil end
function Button:Load() end

function Button:SetButtonTitle(text)
    self:SetTitle(text)
end

function Button:Render(parent, mount)
    local def = self.Def
    local row = Util.New("Frame", {
        Name = "Button",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local hover = { on = false }

    local function colorFor(property)
        return function(t)
            local style = self.Style
            if property == "BackgroundColor3" then
                if style == "Primary" then return t.Accent end
                if style == "Danger" then return t.Danger end
                if style == "Ghost" then return t.SurfaceHover end
                return t.Elevated
            elseif property == "BackgroundTransparency" then
                if style == "Primary" then return hover.on and 0 or 0.05 end
                if style == "Danger" then return hover.on and 0 or 0.05 end
                if style == "Ghost" then return hover.on and 0.35 or 1 end
                return hover.on and math.max(0, t.ElevatedTransparency - 0.2) or math.max(0.05, t.ElevatedTransparency)
            end
        end
    end

    local button = Util.New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        Text = "",
        Theme = {
            BackgroundColor3 = colorFor("BackgroundColor3"),
            BackgroundTransparency = colorFor("BackgroundTransparency"),
        },
        Parent = row,
    })
    Util.Corner("ElementRadius", button)
    Util.Stroke(button, function(t)
        if self.Style == "Primary" then return t.Accent end
        if self.Style == "Danger" then return t.Danger end
        if self.Style == "Ghost" then return t.Divider end
        return t.Stroke
    end, function(t)
        if self.Style == "Primary" or self.Style == "Danger" then return 0.5 end
        return math.max(0, t.StrokeTransparency - 0.2)
    end)
    local scale = Util.New("UIScale", { Scale = 1, Parent = button })

    local icon = def.Icon and Util.Icon(def.Icon, {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -(#self.Title * 3.6), 0.5, 0),
        Theme = { ImageColor3 = function(t) return self.Style == "Primary" and t.OnAccent or (self.Style == "Danger" and t.OnAccent or t.TextDim) end },
        Parent = button,
    }) or nil

    local label = Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        Theme = {
            TextColor3 = function(t)
                if self.Style == "Primary" or self.Style == "Danger" then return t.OnAccent end
                if self.Style == "Ghost" then return t.TextDim end
                return t.Text
            end,
            FontFace = Theme.Font(Enum.FontWeight.Medium),
        },
        Parent = button,
    })
    if icon then
        button.Text = ""
        icon.Visible = false
        local placeIcon = function()
            local textWidth = label.TextBounds.X
            icon.Position = UDim2.new(0.5, -textWidth / 2 - 11, 0.5, 0)
            icon.Visible = true
        end
        task.defer(function() if icon.Parent then placeIcon() end end)
        mount:Give(label:GetPropertyChangedSignal("TextBounds"):Connect(function()
            if icon.Parent then placeIcon() end
        end))
    end

    local pill
    if self.Binding then
        pill = Widgets.KeyPill(button, self.Window, self.Binding, { Tooltip = "Click to bind a key" })
        pill.Button.AnchorPoint = Vector2.new(1, 0.5)
        pill.Button.Position = UDim2.new(1, -6, 0.5, 0)
        label.Size = UDim2.new(1, -60, 1, 0)
    end

    mount:Give(Util.Hover(button, function(on)
        hover.on = on
        Theme.Refresh(button, 0.12)
    end))
    Router.Attach(button, {
        Disabled = function() return self.Locked end,
        OnPress = function()
            Animation.Tween(scale, "Press", { Scale = 0.98 })
        end,
        OnRelease = function()
            Animation.Tween(scale, "Press", { Scale = 1 })
        end,
        OnClick = function()
            if self.Locked then
                if self.LockedReason then
                    self.Window:Notify({ Title = self.Title, Content = self.LockedReason, Type = "Warning" })
                end
                return
            end
            self:Press()
        end,
        Tooltip = def.Tooltip or (self.Locked and self.LockedReason) or nil,
    })
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Title" then label.Text = self.Title end
    end))
    return row
end

return Button
end

__modules["Elements/ButtonRow"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")

-- Buttons: a row of two or three side-by-side buttons: { { Title, Icon, Style, Confirm, Callback }, ... }
local ButtonRow = Base.Class("ButtonRow")

function ButtonRow.new(container, def)
    local self = setmetatable({}, ButtonRow)
    Base.Init(self, container, def)
    self.Buttons = def.Buttons or def.List or {}
    return self
end

function ButtonRow:Press(index)
    local def = self.Buttons[index]
    if not def then return end
    local function run()
        if def.Callback then Util.Safe(def.Callback) end
    end
    if def.Confirm then
        self.Window:Dialog({
            Title = def.Title or self.Title,
            Content = type(def.Confirm) == "string" and def.Confirm or "Are you sure?",
            Icon = "triangle-alert",
            Buttons = {
                { Title = "Cancel", Style = "Secondary" },
                { Title = "Confirm", Style = def.Style == "Danger" and "Danger" or "Primary", Callback = run },
            },
        })
    else
        run()
    end
end

function ButtonRow:SetButtonTitle(index, text)
    local def = self.Buttons[index]
    if def then
        def.Title = text
        self.StateChanged:Fire("Buttons")
    end
end

function ButtonRow:SetButtonLocked(index, locked)
    local def = self.Buttons[index]
    if def then
        def.Locked = locked
        self.StateChanged:Fire("Buttons")
    end
end

function ButtonRow:Save() return nil end
function ButtonRow:Load() end

function ButtonRow:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Buttons",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local layout = Util.List(row, 6, Enum.FillDirection.Horizontal)
    local width = 1 / math.max(#self.Buttons, 1)
    local function rebuild()
        for _, child in row:GetChildren() do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for index, def in self.Buttons do
            local hover = { on = false }
            local button = Util.New("TextButton", {
                Text = "",
                Size = UDim2.new(width, index < #self.Buttons and -4 or 0, 1, 0),
                LayoutOrder = index,
                Theme = {
                    BackgroundColor3 = def.Style == "Primary" and "Accent" or (def.Style == "Danger" and "Danger" or "Elevated"),
                    BackgroundTransparency = function(t)
                        if def.Style == "Primary" or def.Style == "Danger" then return hover.on and 0 or 0.1 end
                        return hover.on and math.max(0, t.ElevatedTransparency - 0.15) or math.max(0.05, t.ElevatedTransparency)
                    end,
                },
                Parent = row,
            })
            Util.Corner("ElementRadius", button)
            local scale = Util.New("UIScale", { Scale = 1, Parent = button })
            local label = Util.Label({
                Text = def.Title or "Button",
                TextSize = 12,
                Weight = Enum.FontWeight.Medium,
                Size = UDim2.fromScale(1, 1),
                TextXAlignment = Enum.TextXAlignment.Center,
                Theme = {
                    TextColor3 = function(t) return (def.Style == "Primary" or def.Style == "Danger") and t.OnAccent or t.Text end,
                },
                Parent = button,
            })
            if def.Icon then
                local icon = Util.Icon(def.Icon, {
                    Size = UDim2.fromOffset(13, 13),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, -(label.TextBounds.X / 2) - 10, 0.5, 0),
                    Theme = { ImageColor3 = function(t) return (def.Style == "Primary" or def.Style == "Danger") and t.OnAccent or t.TextDim end },
                    Parent = button,
                })
                label.Size = UDim2.fromScale(1, 1)
                label.Position = UDim2.fromOffset(7, 0)
            end
            Util.Hover(button, function(on)
                hover.on = on
                Theme.Refresh(button, 0.12)
            end)
            Router.Attach(button, {
                Disabled = function() return def.Locked == true end,
                OnPress = function() Animation.Tween(scale, "Press", { Scale = 0.97 }) end,
                OnRelease = function() Animation.Tween(scale, "Press", { Scale = 1 }) end,
                OnClick = function() self:Press(index) end,
            })
        end
    end
    rebuild()
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Buttons" then rebuild() end
    end))
    return row
end

return ButtonRow
end

__modules["Elements/Code"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Code: a syntax-ish preview block with a copy button; a click expands the whole text into a dialog,
-- and an Editable block can be edited there.
local Code = Base.Class("Code")

function Code.new(container, def)
    local self = setmetatable({}, Code)
    Base.Init(self, container, def)
    self.Code = def.Code or def.Text or ""
    self.Lines = def.Lines or 6
    self.Editable = def.Editable == true
    return self
end

function Code:Set(text)
    self.Code = tostring(text)
    self.StateChanged:Fire("Code")
end
function Code:Get() return self.Code end
function Code:Save() return nil end
function Code:Load() end

function Code:Open()
    local window = self.Window
    if not self.Editable then
        -- read only: the whole text in a dialog, no input
        window:Dialog({
            Title = self.Title,
            Icon = "code",
            Content = self.Code,
            Width = 460,
            Buttons = {
                { Title = "Copy", Style = "Secondary", Callback = function()
                    if setclipboard then pcall(setclipboard, self.Code) end
                    window:Notify({ Title = "Copied", Content = "Code copied", Type = "Success", Duration = 1.5 })
                end },
                { Title = "Close", Style = "Primary" },
            },
        })
        return
    end
    window:Dialog({
        Title = self.Title,
        Icon = "code",
        Width = 460,
        Input = { Default = self.Code, Multiline = true, Height = 220 },
        Buttons = {
            { Title = "Copy", Style = "Secondary", Callback = function()
                if setclipboard then pcall(setclipboard, self.Code) end
                window:Notify({ Title = "Copied", Content = "Code copied to the clipboard", Type = "Success", Duration = 2 })
            end },
            { Title = "Save", Style = "Primary", Callback = function(text, dialog)
                self.Code = text or self.Code
                if self.Def.OnSave then
                    local ok, message = self.Def.OnSave(self.Code)
                    if ok == false then
                        dialog:SetError(message or "Could not save")
                        return false
                    end
                end
                self.StateChanged:Fire("Code")
            end },
        },
    })
end

function Code:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local text = self.Code
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do table.insert(lines, line) end
    if #lines > self.Lines then
        local shown = {}
        for index = 1, self.Lines do table.insert(shown, lines[index]) end
        text = table.concat(shown, "\n") .. "\n…"
    end
    local holder = Util.New("TextButton", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = "",
        Theme = { BackgroundColor3 = "Background", BackgroundTransparency = 0.3 },
        Parent = row,
    })
    Util.Corner("ElementRadius", holder)
    Util.Stroke(holder, "Divider", function(t) return 0.6 end)
    Util.Padding(holder, 8, 10, 8, 10)
    local label = Util.Label({
        Text = self.Title,
        TextSize = 10,
        Weight = Enum.FontWeight.SemiBold,
        Size = UDim2.new(1, -30, 0, 14),
        Color = "TextMuted",
        Parent = holder,
    })
    local codeLabel = Util.Label({
        Text = text,
        TextSize = 11,
        TextWrapped = false,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.Y,
        Color = "Text",
        Theme = { TextColor3 = "Text", FontFace = Theme.Font(Enum.FontWeight.Regular) },
        Parent = holder,
    })
    local copy = Util.New("TextButton", {
        Size = UDim2.fromOffset(22, 22),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, -2),
        Text = "",
        BackgroundTransparency = 1,
        Parent = holder,
    })
    Util.Icon("copy", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Color = "TextMuted", Parent = copy })
    Router.Attach(copy, {
        OnClick = function()
            if setclipboard then pcall(setclipboard, self.Code) end
            self.Window:Notify({ Title = "Copied", Content = "Code copied", Type = "Success", Duration = 1.5 })
            if self.Def.OnCopy then pcall(self.Def.OnCopy) end
        end,
        Tooltip = "Copy",
    })
    Router.Attach(holder, {
        OnClick = function() self:Open() end,
        Tooltip = self.Editable and "Click to edit" or "Click to open",
    })
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Code" then
            local text = self.Code
            local lines = {}
            for line in (text .. "\n"):gmatch("(.-)\n") do table.insert(lines, line) end
            if #lines > self.Lines then
                local shown = {}
                for index = 1, self.Lines do table.insert(shown, lines[index]) end
                text = table.concat(shown, "\n") .. "\n…"
            end
            codeLabel.Text = text
        end
    end))
    return row
end

return Code
end

__modules["Elements/ColorPicker"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Binding = import("Core/Binding")

-- ColorPicker: a swatch that opens an HSV picker with a hue bar, saturation / value square,
-- alpha (optional), hex field and RGB / HSV readouts, plus rainbow cycling.
-- options: Default, Transparency (enables alpha), Rainbow, Alpha (alias), Quick = { colours }
local ColorPicker = Base.Class("ColorPicker")

local function toHex(color)
    local hex = color:ToHex()
    return "#" .. hex:upper()
end

function ColorPicker.new(container, def)
    local color = def.Default
    if typeof(color) ~= "Color3" then color = Color3.fromRGB(78, 132, 255) end
    local self = setmetatable({ Value = color }, ColorPicker)
    self.Alpha = def.Transparency == true or def.Alpha == true
    self.TransparencyDefault = def.TransparencyValue or 0
    self.Default = color
    self.DefaultAlpha = self.TransparencyDefault
    Base.Init(self, container, def)
    self.Rainbow = def.Rainbow == true
    self._h, self._s, self._v = color:ToHSV()
    self._alpha = self.TransparencyDefault
    self._rainbowConnection = nil
    if def.Rainbow then self:SetRainbow(true) end
    return self
end

function ColorPicker:_args()
    return self.Value, self.TransparencyDefault
end

function ColorPicker:Get()
    return self.Value
end

function ColorPicker:GetAlpha()
    return self.TransparencyDefault
end

function ColorPicker:Set(color, silent)
    if typeof(color) == "Color3" then
        self.Value = color
        self._h, self._s, self._v = color:ToHSV()
    elseif type(color) == "string" then
        local ok, parsed = pcall(Color3.fromHex, color)
        if not ok then return end
        self:Set(parsed, silent)
        return
    else
        return
    end
    self.Changed:Fire(self.Value, self.TransparencyDefault)
    if not silent then
        Util.Safe(self.Def.Callback, self.Value, self.TransparencyDefault)
        for _, fn in self._listeners do Util.Safe(fn, self.Value, self.TransparencyDefault) end
    end
    self.Window:_touch()
end

function ColorPicker:SetAlpha(alpha, silent)
    self.TransparencyDefault = math.clamp(alpha or 0, 0, 1)
    self.Changed:Fire(self.Value, self.TransparencyDefault)
    if not silent and self.Def.Callback then Util.Safe(self.Def.Callback, self.Value, self.TransparencyDefault) end
end

function ColorPicker:SetRainbow(on)
    self.Rainbow = on and true or false
    if self.Rainbow and not self._rainbowConnection then
        local hue = self._h
        self._rainbowConnection = Animation.Loop(1 / 30, function()
            hue = (hue + 0.006) % 1
            local color = Color3.fromHSV(hue, self._s, self._v)
            self.Value = color
            self._h = hue
            self.Changed:Fire(color, self.TransparencyDefault)
            if self.Def.Callback then Util.Safe(self.Def.Callback, color, self.TransparencyDefault) end
        end)
    elseif not self.Rainbow and self._rainbowConnection then
        self._rainbowConnection:Disconnect()
        self._rainbowConnection = nil
    end
    self.StateChanged:Fire("Rainbow")
end

function ColorPicker:Save()
    return {
        math.round(self.Value.R * 255),
        math.round(self.Value.G * 255),
        math.round(self.Value.B * 255),
        math.round((1 - self.TransparencyDefault) * 255) / 255,
    }
end

function ColorPicker:Load(value)
    if type(value) == "table" and #value >= 3 then
        self:Set(Color3.fromRGB(value[1], value[2], value[3]), true)
        if value[4] ~= nil then self.TransparencyDefault = 1 - value[4] end
    elseif type(value) == "string" then
        self:Set(value, true)
    elseif typeof(value) == "Color3" then
        self:Set(value, true)
    end
end

function ColorPicker:Reset()
    self:SetRainbow(false)
    self:Set(self.Default)
    self.TransparencyDefault = self.DefaultAlpha
    self.Changed:Fire(self.Value, self.TransparencyDefault)
end

-- the picker surface, opened under the swatch
function ColorPicker:_open(anchor)
    local Popup = import("Components/Popup")
    local menu = Popup.new({ Anchor = anchor, Align = "Right", Width = 236, MaxHeight = 400 })
    menu:_build()
    menu:Show()
    local body = menu.Body
    local padding = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = body,
    })

    -- saturation / value square ----------------------------------------------------
    local square = Util.New("Frame", {
        Size = UDim2.fromOffset(220, 130),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromHSV(self._h, 1, 1),
        Parent = padding,
    })
    Util.Corner("ElementRadius", square)
    local white = Util.New("Frame", {
        Size = UDim2.fromScale(1, 1),
        Theme = { BackgroundColor3 = function(t) return Color3.new(1, 1, 1) end },
        Parent = square,
    })
    Util.Corner("ElementRadius", white)
    Util.New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = white,
    })
    local black = Util.New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        Parent = square,
    })
    Util.Corner("ElementRadius", black)
    Util.New("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Parent = black,
    })
    local cursor = Util.New("Frame", {
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = square,
    })
    Util.Corner(6, cursor)
    Util.Stroke(cursor, function() return Color3.new(1, 1, 1) end, function() return 0 end, 2)
    local cursorInner = Util.New("Frame", {
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = cursor,
    })
    Util.Stroke(cursorInner, function() return Color3.new(0, 0, 0) end, function() return 0.4 end, 1)

    -- hue bar ----------------------------------------------------------------------
    local hueBar = Util.New("Frame", {
        Size = UDim2.fromOffset(220, 12),
        Position = UDim2.fromOffset(2, 140),
        Parent = padding,
    })
    Util.Corner(6, hueBar)
    Util.New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
            ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        }),
        Parent = hueBar,
    })
    local hueCursor = Util.New("Frame", {
        Size = UDim2.fromOffset(4, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(self._h, 0, 0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Parent = hueBar,
    })
    Util.Corner(2, hueCursor)
    Util.Stroke(hueCursor, function() return Color3.new(0, 0, 0) end, function() return 0.35 end)

    local alphaBar, alphaCursor
    if self.Alpha then
        alphaBar = Util.New("Frame", {
            Size = UDim2.fromOffset(220, 12),
            Position = UDim2.fromOffset(2, 158),
            Theme = { BackgroundColor3 = "ElevatedHover" },
            Parent = padding,
        })
        Util.Corner(6, alphaBar)
        local alphaFill = Util.New("Frame", {
            Size = UDim2.fromScale(1 - self.TransparencyDefault, 1),
            BackgroundColor3 = self.Value,
            Parent = alphaBar,
        })
        Util.Corner(6, alphaFill)
        local aGradient = Util.New("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = alphaFill,
        })
        alphaCursor = Util.New("Frame", {
            Size = UDim2.fromOffset(4, 18),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1 - self.TransparencyDefault, 0, 0.5, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            Parent = alphaBar,
        })
        Util.Corner(2, alphaCursor)
        Util.Stroke(alphaCursor, function() return Color3.new(0, 0, 0) end, function() return 0.35 end)
    end

    local function paint()
        local color = Color3.fromHSV(self._h, self._s, self._v)
        square.BackgroundColor3 = Color3.fromHSV(self._h, 1, 1)
        cursor.Position = UDim2.new(self._s, 0, 1 - self._v, 0)
        hueCursor.Position = UDim2.new(self._h, 0, 0.5, 0)
        if alphaCursor then alphaCursor.Position = UDim2.new(1 - self.TransparencyDefault, 0, 0.5, 0) end
        hexBox.Text = toHex(color)
        rgbLabel.Text = string.format("%d, %d, %d", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
        hsvLabel.Text = string.format("%d°, %d%%, %d%%", math.round(self._h * 360), math.round(self._s * 100), math.round(self._v * 100))
        preview.BackgroundColor3 = color
    end

    -- hex + readouts ----------------------------------------------------------------
    local preview = Util.New("Frame", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromOffset(2, self.Alpha and 180 or 160),
        BackgroundColor3 = self.Value,
        Parent = padding,
    })
    Util.Corner("ElementRadius", preview)
    Util.Stroke(preview, "Stroke", function() return 0.5 end)
    local hexHolder = Util.New("Frame", {
        Size = UDim2.fromOffset(104, 26),
        Position = UDim2.fromOffset(34, self.Alpha and 180 or 160),
        Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.3 },
        Parent = padding,
    })
    Util.Corner("ElementRadius", hexHolder)
    local hexBox = Util.New("TextBox", {
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.fromOffset(7, 0),
        Text = toHex(self.Value),
        TextSize = 12,
        Theme = { TextColor3 = "Text" },
        Parent = hexHolder,
    })
    local copy = Util.New("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromOffset(142, self.Alpha and 180 or 160),
        Text = "",
        Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.3 },
        Parent = padding,
    })
    Util.Corner("ElementRadius", copy)
    Util.Icon("copy", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = copy })
    Router.Attach(copy, {
        OnClick = function()
            if setclipboard then pcall(setclipboard, toHex(self.Value)) end
            self.Window:Notify({ Title = "Copied", Content = toHex(self.Value), Type = "Success", Duration = 1.5 })
        end,
        Tooltip = "Copy hex",
    })
    local rainbowToggle
    if not (self.Alpha) then
        rainbowToggle = Util.New("TextButton", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.fromOffset(172, 160),
            Text = "",
            Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.3 },
            Parent = padding,
        })
        Util.Corner("ElementRadius", rainbowToggle)
        local wand = Util.Icon("wand-sparkles", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Color = "TextDim", Parent = rainbowToggle })
        Router.Attach(rainbowToggle, {
            OnClick = function()
                self:SetRainbow(not self.Rainbow)
                wand.ImageColor3 = import("Core/Theme").Current[self.Rainbow and "Accent" or "TextDim"]
            end,
            Tooltip = "Cycle the hue",
        })
    end
    local rgbLabel = Util.Label({
        Text = "",
        TextSize = 10,
        Position = UDim2.fromOffset(2, self.Alpha and 212 or 192),
        Size = UDim2.new(0.5, 0, 0, 14),
        Color = "TextMuted",
        Parent = padding,
    })
    local hsvLabel = Util.Label({
        Text = "",
        TextSize = 10,
        Position = UDim2.fromOffset(100, self.Alpha and 212 or 192),
        Size = UDim2.new(0.5, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
        Color = "TextMuted",
        Parent = padding,
    })
    padding.Size = UDim2.new(1, 0, 0, self.Alpha and 232 or 212)

    -- input handlers ------------------------------------------------------------------
    local function applyColor(silent)
        local color = Color3.fromHSV(self._h, self._s, self._v)
        self.Value = color
        self.Changed:Fire(color, self.TransparencyDefault)
        if not silent then
            if self.Def.Callback then Util.Safe(self.Def.Callback, color, self.TransparencyDefault) end
        end
        self.Window:_touch()
    end

    local function trackSquare(handle, point)
        local position = square.AbsolutePosition
        local size = square.AbsoluteSize
        self._s = math.clamp((point.X - position.X) / math.max(size.X, 1), 0, 1)
        self._v = 1 - math.clamp((point.Y - position.Y) / math.max(size.Y, 1), 0, 1)
        paint()
        applyColor(false)
    end
    Router.Attach(square, {
        OnPress = function(_, point) trackSquare(nil, point) end,
        OnDrag = function(_, point) trackSquare(nil, point) end,
    })
    Router.Attach(hueBar, {
        OnPress = function(_, point)
            self._h = math.clamp((point.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
            paint()
            applyColor(false)
        end,
        OnDrag = function(_, point)
            self._h = math.clamp((point.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
            paint()
            applyColor(false)
        end,
    })
    if alphaBar then
        local function trackAlpha(point)
            local percent = math.clamp((point.X - alphaBar.AbsolutePosition.X) / math.max(alphaBar.AbsoluteSize.X, 1), 0, 1)
            self.TransparencyDefault = 1 - percent
            paint()
            self.Changed:Fire(self.Value, self.TransparencyDefault)
            if self.Def.Callback then Util.Safe(self.Def.Callback, self.Value, self.TransparencyDefault) end
        end
        Router.Attach(alphaBar, {
            OnPress = function(_, point) trackAlpha(point) end,
            OnDrag = function(_, point) trackAlpha(point) end,
        })
    end
    hexBox.FocusLost:Connect(function()
        local ok, color = pcall(Color3.fromHex, hexBox.Text)
        if ok then
            self:Set(color)
            self._h, self._s, self._v = color:ToHSV()
            paint()
        else
            hexBox.Text = toHex(self.Value)
        end
    end)
    paint()
    return menu
end

function ColorPicker:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "ColorPicker",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local swatchHolder = Util.New("TextButton", {
        Text = "",
        Size = UDim2.fromOffset(36, 22),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.2 },
        Parent = row,
    })
    Util.Corner("ElementRadius", swatchHolder)
    local swatch = Util.New("Frame", {
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = self.Value,
        Parent = swatchHolder,
    })
    Util.Corner("ElementRadius", swatch)
    if self.Alpha then swatch.BackgroundTransparency = self.TransparencyDefault end
    local hex = Util.Label({
        Text = "",
        TextSize = 10,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -44, 0.5, 0),
        Size = UDim2.fromOffset(56, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
        Color = "TextMuted",
        Parent = row,
    })
    local function refresh()
        swatch.BackgroundColor3 = self.Value
        swatch.BackgroundTransparency = self.Alpha and self.TransparencyDefault or 0
        hex.Text = toHex(self.Value)
    end
    refresh()
    mount:Give(self.Changed:Connect(refresh))
    Router.Attach(swatchHolder, {
        OnClick = function()
            if self.Locked then
                if self.LockedReason then self.Window:Notify({ Title = self.Title, Content = self.LockedReason, Type = "Warning" }) end
                return
            end
            self:_open(swatchHolder)
        end,
    })
    return row
end

return ColorPicker
end

__modules["Elements/Divider"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Divider: a line with optional centered text
local Divider = Base.Class("Divider")

function Divider.new(container, def)
    local self = setmetatable({}, Divider)
    Base.Init(self, container, def)
    self.Text = def.Text or (def.Title ~= "Divider" and def.Title) or nil
    return self
end
function Divider:Save() return nil end
function Divider:Load() end

function Divider:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, self.Text and 24 or 15),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local line = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Theme = { BackgroundColor3 = "Divider", BackgroundTransparency = 0.25 },
        Parent = row,
    })
    if self.Text then
        local label = Util.Label({
            Text = " " .. self.Text .. " ",
            TextSize = 10,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 0, 0, 16),
            AutomaticSize = Enum.AutomaticSize.X,
            TextXAlignment = Enum.TextXAlignment.Center,
            Color = "TextMuted",
            BackgroundTransparency = 0,
            Theme = { BackgroundColor3 = "Background" },
            Parent = row,
        })
        Util.Padding(label, 0, 2, 0, 2)
        label.ZIndex = 2
    end
    return row
end

return Divider
end

__modules["Elements/Dropdown"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Popup = import("Components/Popup")

-- Dropdown: single or multi select, searchable above 8 values, values may be strings or
-- { Title, Value, Description, Icon } tables.
-- options: Values, Default, Multi, Search, AllowNone, Placeholder, MaxVisible, Action = { Icon, Tooltip, Callback(value) }
local Dropdown = Base.Class("Dropdown")

local function normalizeValues(values)
    local out = {}
    for _, entry in values or {} do
        if type(entry) == "table" then
            table.insert(out, {
                Title = tostring(entry.Title or entry.Value or entry.Name or entry.Text),
                Value = entry.Value ~= nil and entry.Value or (entry.Title or entry.Name or entry.Text),
                Description = entry.Description or entry.Desc,
                Icon = entry.Icon,
            })
        else
            table.insert(out, { Title = tostring(entry), Value = entry })
        end
    end
    return out
end

local function same(a, b)
    if type(a) == "table" and type(b) == "table" then
        return table.concat(a, "\1") == table.concat(b, "\1")
    end
    return a == b
end

function Dropdown.new(container, def)
    local self = setmetatable({}, Dropdown)
    Base.Init(self, container, def)
    self.Multi = def.Multi == true
    self.AllowNone = def.AllowNone ~= false
    self.Options = normalizeValues(def.Values)
    self.Search = def.Search == nil and #self.Options > 8 or def.Search == true
    self.MaxVisible = def.MaxVisible or 8
    self.Placeholder = def.Placeholder or "Select…"
    self.Selected = nil
    self.Default = nil
    self:_seedDefault(def.Default)
    return self
end

function Dropdown:_find(value)
    for _, entry in self.Options do
        if entry.Value == value then return entry end
    end
    for _, entry in self.Options do
        if entry.Title == value then return entry end
    end
    return nil
end

function Dropdown:_seedDefault(default)
    if self.Multi then
        local out = {}
        if type(default) == "table" then
            for _, value in default do
                local entry = self:_find(value)
                if entry then table.insert(out, entry.Value) end
            end
        elseif default ~= nil then
            local entry = self:_find(default)
            if entry then table.insert(out, entry.Value) end
        end
        self.Selected = out
        self.Default = table.clone(out)
    else
        local entry = default ~= nil and self:_find(default) or nil
        self.Selected = entry and entry.Value or nil
        self.Default = self.Selected
    end
    self.Value = self.Selected
end

function Dropdown:_label()
    if self.Multi then
        local names = {}
        for _, value in self.Selected or {} do
            local entry = self:_find(value)
            local name = entry and entry.Title or tostring(value)
            if #names < 2 then table.insert(names, name) end
        end
        local count = #(self.Selected or {})
        if count == 0 then return self.Placeholder end
        local text = table.concat(names, ", ")
        if count > 2 then text = text .. " +" .. (count - 2) end
        return text
    end
    if self.Selected == nil then return self.Placeholder end
    local entry = self:_find(self.Selected)
    return entry and entry.Title or tostring(self.Selected)
end

function Dropdown:_commit(dropdown)
    if same(self.Selected, dropdown.Selected) then return end
    self.Selected = dropdown.Selected
    self.Value = self.Selected
    self.Changed:Fire(self.Selected)
    if self.Multi then
        Util.Safe(self.Def.Callback, table.clone(self.Selected))
        for _, fn in self._listeners do Util.Safe(fn, table.clone(self.Selected)) end
    else
        Util.Safe(self.Def.Callback, self.Selected)
        for _, fn in self._listeners do Util.Safe(fn, self.Selected) end
    end
    self.Window:_touch()
end

function Dropdown:Get()
    if self.Multi then return table.clone(self.Selected) end
    return self.Selected
end

function Dropdown:Set(value, silent)
    local target = { Selected = self.Multi and {} or nil }
    if self.Multi then
        if type(value) == "table" then
            for _, v in value do
                local entry = self:_find(v)
                if entry then table.insert(target.Selected, entry.Value) end
            end
        elseif value ~= nil then
            local entry = self:_find(value)
            if entry then table.insert(target.Selected, entry.Value) end
        end
    else
        if value ~= nil then
            local entry = self:_find(value)
            target.Selected = entry and entry.Value or value
        end
    end
    if silent then
        self.Selected = target.Selected
        self.Value = self.Selected
    else
        self:_commit(target)
    end
end

function Dropdown:Toggle(value)
    if not self.Multi then return self:Set(value) end
    local list = table.clone(self.Selected or {})
    local index = table.find(list, value)
    if index then table.remove(list, index) else table.insert(list, value) end
    self:Set(list)
end

function Dropdown:IsSelected(value)
    if self.Multi then return table.find(self.Selected or {}, value) ~= nil end
    return self.Selected == value
end

function Dropdown:GetValues()
    local out = {}
    for _, entry in self.Options do table.insert(out, entry.Value) end
    return out
end

function Dropdown:Refresh(values, keep)
    self.Options = normalizeValues(values)
    if keep == false then
        self:Set(self.Multi and {} or nil, true)
    else
        -- drop selections whose values are gone
        if self.Multi then
            local list = {}
            for _, value in self.Selected or {} do
                if self:_find(value) then table.insert(list, value) end
            end
            self.Selected = list
        elseif self.Selected ~= nil and not self:_find(self.Selected) then
            self.Selected = nil
        end
        self.Value = self.Selected
    end
    self.StateChanged:Fire("Values")
end

function Dropdown:Add(entry)
    table.insert(self.Options, normalizeValues({ entry })[1])
    self.StateChanged:Fire("Values")
end

function Dropdown:Remove(value)
    for index = #self.Options, 1, -1 do
        if self.Options[index].Value == value then table.remove(self.Options, index) end
    end
    self.StateChanged:Fire("Values")
end

function Dropdown:Save()
    if self.Multi then return table.clone(self.Selected or {}) end
    return self.Selected
end

function Dropdown:Load(value)
    if self.Multi then
        if type(value) == "table" then self:Set(value, true) end
    elseif value ~= nil then
        self:Set(value, true)
    end
end

-- opens the list; reused by every view
function Dropdown:_open(anchor)
    local menu = Popup.new({
        Anchor = anchor,
        Width = math.max(anchor.AbsoluteSize.X, 190),
        MaxHeight = 44 + math.min(math.max(#self.Options, 1), self.MaxVisible) * 30,
    })
    menu:_build()
    menu:Show()

    local listHolder = Util.New("ScrollingFrame", {
        Name = "List",
        Size = UDim2.new(1, 0, 0, math.min(#self.Options, self.MaxVisible) * 30),
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Theme = { ScrollBarImageColor3 = "Stroke" },
        Parent = menu.Body,
    })
    local list = Util.List(listHolder, 2)
    Util.AutoCanvas(listHolder, list)

    local searchBox = nil
    if self.Search then
        local field = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            LayoutOrder = -1,
            Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.3 },
            Parent = menu.Body,
        })
        Util.Corner(6, field)
        Util.Icon("search", { Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(8, 7), Color = "TextMuted", Parent = field })
        searchBox = Util.New("TextBox", {
            Size = UDim2.new(1, -26, 1, 0),
            Position = UDim2.fromOffset(24, 0),
            PlaceholderText = "Search",
            TextSize = 12,
            Theme = { TextColor3 = "Text", PlaceholderColor3 = "TextMuted" },
            Parent = field,
        })
    end

    local rows = {}
    local function build(query)
        for _, row in rows do row:Destroy() end
        rows = {}
        local order = 0
        for _, entry in self.Options do
            local haystack = (entry.Title .. " " .. (entry.Description or "")):lower()
            if not query or query == "" or haystack:find(query, 1, true) then
                order += 1
                local hover = { on = false }
                local selected = self:IsSelected(entry.Value)
                local row = Util.New("TextButton", {
                    Size = UDim2.new(1, 0, 0, entry.Description and 40 or 28),
                    Text = "",
                    LayoutOrder = order,
                    Theme = {
                        BackgroundColor3 = "ElevatedHover",
                        BackgroundTransparency = function() return hover.on and 0.35 or 1 end,
                    },
                    Parent = listHolder,
                })
                Util.Corner(6, row)
                local x = 10
                if entry.Icon then
                    Util.Icon(entry.Icon, { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(8, entry.Description and 13 or 7), Parent = row })
                    x = 28
                end
                Util.Label({
                    Text = entry.Title,
                    TextSize = 12,
                    Position = UDim2.fromOffset(x, entry.Description and 5 or 0),
                    Size = UDim2.new(1, -x - 26, 0, entry.Description and 18 or 28),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Theme = { TextColor3 = selected and "Accent" or "Text" },
                    Parent = row,
                })
                if entry.Description then
                    Util.Label({
                        Text = entry.Description,
                        TextSize = 10,
                        Position = UDim2.fromOffset(x, 21),
                        Size = UDim2.new(1, -x - 26, 0, 14),
                        Color = "TextMuted",
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = row,
                    })
                end
                if selected then
                    Util.Icon("check", {
                        Size = UDim2.fromOffset(12, 12),
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -10, 0.5, 0),
                        Color = "Accent",
                        Parent = row,
                    })
                end
                Util.Hover(row, function(on)
                    hover.on = on
                    Theme.Refresh(row, 0.1)
                end)
                Router.Attach(row, {
                    OnClick = function()
                        if self.Multi then
                            self:Toggle(entry.Value)
                            build(searchBox and searchBox.Text:lower() or nil)
                        else
                            self:Set(entry.Value)
                            menu:Close()
                        end
                    end,
                })
                table.insert(rows, row)
            end
        end
        if #rows == 0 then
            local empty = Util.Label({
                Text = "No results",
                TextSize = 12,
                Size = UDim2.new(1, 0, 0, 28),
                TextXAlignment = Enum.TextXAlignment.Center,
                Color = "TextMuted",
                Parent = listHolder,
            })
            table.insert(rows, empty)
            listHolder.Size = UDim2.new(1, 0, 0, 28)
        else
            listHolder.Size = UDim2.new(1, 0, 0, math.min(#rows, self.MaxVisible) * (self.Options[1] and self.Options[1].Description and 42 or 30))
        end
    end
    build(nil)
    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            build(searchBox.Text:lower())
        end)
        task.defer(function()
            if searchBox.Parent then pcall(function() searchBox:CaptureFocus() end) end
        end)
    end
    return menu
end

function Dropdown:Render(parent, mount)
    local def = self.Def
    local row = Util.New("Frame", {
        Name = "Dropdown",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local label = Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(0.44, -8, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local hover = { on = false }
    local fieldLeft = def.Action and 0.44 or 0.44
    local holderWidth = def.Action and -(0.44 + 34) or -0.44
    local button = Util.New("TextButton", {
        Text = "",
        Size = UDim2.new(1, holderWidth - 0, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        Theme = {
            BackgroundColor3 = "Elevated",
            BackgroundTransparency = function(t)
                return hover.on and math.max(0, t.ElevatedTransparency - 0.15) or math.max(0.05, t.ElevatedTransparency)
            end,
        },
        Parent = row,
    })
    Util.Corner("ElementRadius", button)
    Util.Stroke(button, function(t) return hover.on and t.Stroke or t.Stroke end, function(t)
        return hover.on and math.max(0, t.StrokeTransparency - 0.35) or math.max(0, t.StrokeTransparency - 0.15)
    end)
    local text = Util.Label({
        Text = self:_label(),
        TextSize = 12,
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(1, -(self.Multi and 46 or 28), 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Theme = {
            TextColor3 = function(t)
                if self.Multi then
                    if #(self.Selected or {}) == 0 then return t.TextMuted end
                elseif self.Selected == nil then
                    return t.TextMuted
                end
                return t.Text
            end,
        },
        Parent = button,
    })
    local chevron = Util.Icon("chevron-down", {
        Size = UDim2.fromOffset(13, 13),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Color = "TextMuted",
        Parent = button,
    })
    local badge
    if self.Multi then
        badge = Util.Label({
            Text = "0",
            TextSize = 10,
            Weight = Enum.FontWeight.SemiBold,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -26, 0.5, 0),
            Size = UDim2.fromOffset(18, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
            Color = "Accent",
            Parent = button,
        })
    end

    local function refresh()
        text.Text = self:_label()
        if badge then
            local count = #(self.Selected or {})
            badge.Text = tostring(count)
            badge.Visible = count > 0
            text.Size = UDim2.new(1, count > 0 and -46 or -28, 1, 0)
        end
    end
    refresh()

    local function open()
        if self.Locked then
            if self.LockedReason then
                self.Window:Notify({ Title = self.Title, Content = self.LockedReason, Type = "Warning" })
            end
            return
        end
        self:_open(button)
    end

    Router.Attach(button, {
        OnClick = open,
        OnPress = function() Animation.Tween(chevron, "Press", { Size = UDim2.fromOffset(11, 11) }) end,
        OnRelease = function() Animation.Tween(chevron, "Press", { Size = UDim2.fromOffset(13, 13) }) end,
        Tooltip = def.Tooltip or (self.Locked and self.LockedReason) or nil,
    })
    mount:Give(Util.Hover(button, function(on)
        hover.on = on
        Theme.Refresh(button, 0.12)
    end))
    mount:Give(self.Changed:Connect(refresh))
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Values" or state == "Title" then
            refresh()
            label.Text = self.Title
        end
    end))

    if def.Action then
        local actionButton = Util.New("TextButton", {
            Text = "",
            Size = UDim2.fromOffset(28, 28),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = function(t) return math.max(0.05, t.ElevatedTransparency) end },
            Parent = row,
        })
        Util.Corner("ElementRadius", actionButton)
        Util.Icon(def.Action.Icon or "refresh-cw", {
            Size = UDim2.fromOffset(13, 13),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Parent = actionButton,
        })
        Router.Attach(actionButton, {
            OnClick = function()
                if def.Action.Callback then Util.Defer(def.Action.Callback, self:Get()) end
            end,
            Tooltip = def.Action.Tooltip,
        })
    end
    return row
end

return Dropdown
end

__modules["Elements/Group"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Container = import("Components/Container")
local Signal = import("Core/Signal")

-- Group: a foldable list of elements inside a card. Shares the container API with modules,
-- so a group can hold a Toggle, a Slider or another Group.
local Group = Base.Class("Group")
Container.Apply(Group)

local HEADER = 30

function Group.new(container, def)
    local self = setmetatable({}, Group)
    Container.Setup(self)
    self.Kind = "Group"
    self.Container = container
    self.Window = container.Window
    self.Module = container.Module or container
    self.View = container.View
    self.Def = def
    self.Title = def.Title or def.Name or "Group"
    self.Icon = def.Icon
    self.Flag = nil
    self.NoSave = true
    self.Changed = Signal.new()
    self.StateChanged = Signal.new()
    self._listeners = {}
    self._mounts = {}
    self.Locked = false
    self.Visible = def.Visible ~= false
    self.Opened = def.Opened ~= false
    self._foldOpen = self.Opened
    return self
end

function Group:SetOpened(open)
    self.Opened = open and true or false
    self.StateChanged:Fire("Opened")
end

function Group:Get() return self.Opened end
function Group:Set(value) self:SetOpened(value) end
function Group:Save() return nil end
function Group:Load() end

function Group:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Group",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local surface = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Theme = {
            BackgroundColor3 = "SurfaceHover",
            BackgroundTransparency = function(t) return math.max(0.2, t.SurfaceTransparency + 0.25) end,
        },
        Parent = row,
    })
    Util.Corner("ElementRadius", surface)
    Util.Stroke(surface, "Divider", function(t) return 0.6 end)
    Util.Padding(surface, 0, 8, 6, 8)

    local header = Util.New("TextButton", {
        Size = UDim2.new(1, 0, 0, HEADER),
        Text = "",
        BackgroundTransparency = 1,
        Parent = surface,
    })
    if self.Icon then
        Util.Icon(self.Icon, { Size = UDim2.fromOffset(13, 13), Position = UDim2.fromOffset(0, 9), Color = "TextDim", Parent = header })
    end
    Util.Label({
        Text = self.Title,
        TextSize = 12,
        Weight = Enum.FontWeight.SemiBold,
        Position = UDim2.fromOffset(self.Icon and 20 or 0, 0),
        Size = UDim2.new(1, self.Icon and -46 or -26, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })
    local chevron = Util.Icon("chevron-down", {
        Size = UDim2.fromOffset(13, 13),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -2, 0.5, 0),
        Rotation = self.Opened and 180 or 0,
        Color = "TextMuted",
        Parent = header,
    })
    Router.Attach(header, { OnClick = function() self:SetOpened(not self.Opened) end })

    local fold = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = surface,
    })
    local inner = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = fold,
    })
    local list = Util.List(inner, 4)
    local contentHeight = 0
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        contentHeight = list.AbsoluteContentSize.Y
        if self._foldOpen then fold.Size = UDim2.new(1, 0, 0, contentHeight) end
    end)
    local function apply(animate)
        self._foldOpen = self.Opened
        Animation.Tween(chevron, "Hover", { Rotation = self.Opened and 180 or 0 })
        if animate then
            Animation.Tween(fold, "Fold", { Size = UDim2.new(1, 0, 0, self.Opened and contentHeight or 0) })
        else
            fold.Size = UDim2.new(1, 0, 0, self.Opened and contentHeight or 0)
        end
    end
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Opened" then apply(true) end
    end))
    Container._mountChildren(self, inner, mount)
    task.defer(function() apply(false) end)
    task.delay(0.1, function() apply(false) end)
    return row
end

return Group
end

__modules["Elements/Image"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Image: a rounded picture row
local Image = Base.Class("Image")

function Image.new(container, def)
    local self = setmetatable({}, Image)
    Base.Init(self, container, def)
    return self
end
function Image:Save() return nil end
function Image:Load() end

function Image:Render(parent, mount)
    local def = self.Def
    local height = def.Height or 100
    local capacity = def.Caption and (height + 20) or height
    local holder = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, capacity),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local image = Util.New("ImageLabel", {
        Size = def.Caption and UDim2.new(1, 0, 0, height) or UDim2.fromScale(1, 1),
        Image = typeof(def.Image) == "number" and ("rbxassetid://" .. def.Image) or (def.Image or ""),
        ScaleType = def.ScaleType or Enum.ScaleType.Crop,
        Parent = holder,
    })
    Util.Corner(def.Radius or "ElementRadius", image)
    Util.Stroke(image, "Stroke", function(t) return 0.6 end)
    if def.AspectRatio then
        image.Size = UDim2.new(1, 0, 0, 0)
        image.SizeConstraint = Enum.SizeConstraint.RelativeXX
    end
    if def.Caption and def.Caption ~= "" then
        Util.Label({
            Text = def.Caption,
            TextSize = 11,
            Position = UDim2.fromOffset(2, height + 4),
            Size = UDim2.new(1, -4, 0, 14),
            Color = "TextMuted",
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = holder,
        })
    end
    return holder
end

return Image
end

__modules["Elements/Input"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Keybinds = import("Core/Keybinds")

-- Input: a text field on a titled row. Numeric mode formats and clamps the value.
-- options: Default, Placeholder, Numeric, Min, Max, Step, MaxLength, Finished (default on),
--          Validate(text) -> ok, message, Icon, Multiline, Height, ClearOnFocus
local Input = Base.Class("Input")

function Input.new(container, def)
    local self = setmetatable({}, Input)
    self.Value = def.Default
    if def.Numeric and self.Value == nil then self.Value = def.Min or 0 end
    self.Default = self.Value
    Base.Init(self, container, def)
    return self
end

function Input:_clean(text)
    text = tostring(text or "")
    local maxLength = tonumber(self.Def.MaxLength)
    if maxLength and maxLength >= 1 and #text > maxLength then
        text = text:sub(1, maxLength)
    end
    return text
end

function Input:_parse(text)
    if self.Def.Numeric then
        local number = tonumber((text:gsub("[^%d%.%-]", "")))
        if number == nil then return nil end
        if self.Def.Min and number < self.Def.Min then number = self.Def.Min end
        if self.Def.Max and number > self.Def.Max then number = self.Def.Max end
        if self.Def.Step and self.Def.Step > 0 then number = Util.Clean(Util.Round(number, self.Def.Step), self.Def.Step) end
        return number
    end
    return self:_clean(text)
end

function Input:Set(text, silent)
    local value = self:_parse(text)
    if value == nil or value == self.Value then return end
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
    self.Window:_touch()
end

function Input:Submit(text)
    self:Set(text)
    if self.Def.Finished ~= false then self:_notify() end
end

function Input:Save()
    return self.Value
end

function Input:Load(value)
    if value == nil then return end
    if self.Def.Numeric then
        self:Set(value, true)
    elseif type(value) == "string" then
        self:Set(value, true)
    end
end

function Input:Render(parent, mount)
    local def = self.Def
    local row = Util.New("Frame", {
        Name = "Input",
        Size = UDim2.new(1, -6, 0, def.Multiline and ((def.Height or 80) + 12) or 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    if not def.Multiline then
        Util.Label({
            Text = self.Title,
            TextSize = 13,
            Weight = Enum.FontWeight.Medium,
            Size = UDim2.new(0.44, -8, 1, 0),
            Position = UDim2.fromOffset(2, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
    end
    local hover = { on = false }
    local focused = { on = false }
    local holder = Util.New("Frame", {
        Size = def.Multiline and UDim2.new(1, -4, 0, def.Height or 80) or UDim2.new(1, -4, 1, 0),
        Position = def.Multiline and UDim2.fromOffset(0, 26) or UDim2.fromOffset(0, 0),
        Theme = {
            BackgroundColor3 = "Elevated",
            BackgroundTransparency = function(t)
                if focused.on then return math.max(0, t.ElevatedTransparency - 0.2) end
                return math.max(0.05, t.ElevatedTransparency)
            end,
        },
        Parent = row,
    })
    Util.Corner("ElementRadius", holder)
    Util.Stroke(holder, function(t) return focused.on and t.Accent or t.Stroke end, function(t)
        return focused.on and 0.15 or math.max(0, t.StrokeTransparency - 0.15)
    end)
    if def.Multiline then
        -- a title row above the box
        local label = Util.Label({
            Text = self.Title,
            TextSize = 13,
            Weight = Enum.FontWeight.Medium,
            Size = UDim2.new(1, -8, 0, 20),
            Position = UDim2.fromOffset(2, 2),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
        mount:Give(self.StateChanged:Connect(function() label.Text = self.Title end))
    end
    local x = 9
    if def.Icon then
        Util.Icon(def.Icon, {
            Size = UDim2.fromOffset(14, 14),
            AnchorPoint = Vector2.new(0, def.Multiline and 0 or 0.5),
            Position = def.Multiline and UDim2.fromOffset(9, 9) or UDim2.new(0, 9, 0.5, 0),
            Color = "TextMuted",
            Parent = holder,
        })
        x = 29
    end
    local box = Util.New("TextBox", {
        Size = def.Multiline and UDim2.new(1, -(x + 9), 1, -(def.Icon and 26 or 12)) or UDim2.new(1, -(x + 9), 1, 0),
        Position = def.Multiline and UDim2.fromOffset(x, def.Icon and 26 or 6) or UDim2.fromOffset(x, 0),
        Text = self.Value ~= nil and tostring(self.Value) or "",
        PlaceholderText = def.Placeholder or "",
        TextSize = 12,
        TextWrapped = def.Multiline == true,
        MultiLine = def.Multiline == true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = def.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        ClearTextOnFocus = def.ClearOnFocus == true,
        Theme = {
            TextColor3 = "Text",
            PlaceholderColor3 = "TextMuted",
            FontFace = Theme.Font(Enum.FontWeight.Regular),
        },
        Parent = holder,
    })
    if def.Multiline then
        box.TextTruncate = Enum.TextTruncate.None
    end
    Keybinds.SetTextBox(box)

    mount:Give(box.Focused:Connect(function()
        focused.on = true
        Theme.Refresh(holder, 0.15)
        -- game keys must not fire while typing
    end))
    mount:Give(box.FocusLost:Connect(function(enterPressed)
        focused.on = false
        Theme.Refresh(holder, 0.15)
        local raw = box.Text
        local parsed = self:_parse(raw)
        if def.Validate then
            local ok, message = def.Validate(raw)
            if not ok then
                box.Text = self.Value ~= nil and tostring(self.Value) or ""
                if message and message ~= "" then
                    self.Window:Notify({ Title = self.Title, Content = message, Type = "Warning" })
                end
                return
            end
        end
        if parsed ~= nil then
            self:Submit(parsed)
            box.Text = tostring(self.Value)
        else
            box.Text = self.Value ~= nil and tostring(self.Value) or ""
        end
    end))

    -- numeric: Up / Down arrows step, like a number field
    if def.Numeric then
        mount:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
            local filtered = box.Text:gsub("[^%d%.%-]", "")
            if filtered ~= box.Text then box.Text = filtered end
        end))
    end

    local clear = Util.New("ImageButton", {
        Name = "Clear",
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(1, def.Multiline and 0 or 0.5),
        Position = def.Multiline and UDim2.new(1, -9, 0, 9) or UDim2.new(1, -9, 0.5, 0),
        Image = Util.IconId("x"),
        ImageTransparency = 0.5,
        Visible = box.Text ~= "",
        Theme = { ImageColor3 = "TextMuted" },
        Parent = holder,
    })
    Router.Attach(clear, {
        OnClick = function()
            box.Text = ""
            if def.Numeric then self:Set(def.Min or 0) else self:Set("") end
        end,
    })
    mount:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
        clear.Visible = box.Text ~= ""
    end))

    mount:Give(Util.Hover(holder, function(on)
        hover.on = on
        Theme.Refresh(holder, 0.12)
    end))
    mount:Give(self.Changed:Connect(function(value)
        if not box:IsFocused() then box.Text = value ~= nil and tostring(value) or "" end
    end))
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Title" then
            for _, child in row:GetChildren() do
                if child:IsA("TextLabel") then child.Text = self.Title end
            end
        end
    end))
    return row
end

return Input
end

__modules["Elements/Keybind"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Binding = import("Core/Binding")
local Widgets = import("Components/Widgets")

-- Keybind: a standalone bind row. A click captures, right click picks Toggle / Hold / Always.
local Keybind = Base.Class("Keybind")

function Keybind.new(container, def)
    local self = setmetatable({ Value = false }, Keybind)
    Base.Init(self, container, def)
    self.Binding = Binding.new({
        Key = def.Default or def.Key,
        Mode = def.Mode or "Toggle",
        Modes = def.Modes or { "Toggle", "Hold", "Always" },
        Capture = def,
        Press = function(binding)
            if self.Locked then return end
            if binding.Mode == "Hold" then
                self.Value = true
                self.Changed:Fire(true)
                if def.Callback then Util.Safe(def.Callback, true) end
                if def.Pressed then Util.Safe(def.Pressed) end
            else
                if def.Callback then Util.Safe(def.Callback, true) end
                if def.Pressed then Util.Safe(def.Pressed) end
            end
        end,
        Release = function(binding)
            if binding.Mode == "Hold" then
                self.Value = false
                self.Changed:Fire(false)
                if def.Callback then Util.Safe(def.Callback, false) end
            end
        end,
    })
    self.Mode = self.Binding.Mode
    self.Binding.Changed:Connect(function() self.Mode = self.Binding.Mode end)
    self.Window:_trackBind(self)
    return self
end

function Keybind:GetKey()
    return self.Binding.Key
end

function Keybind:SetKey(key)
    self.Binding:SetKey(key)
end

function Keybind:SetMode(mode)
    self.Binding:SetMode(mode)
    self.Mode = self.Binding.Mode
end

function Keybind:IsDown()
    return self.Binding:IsDown()
end

function Keybind:Get()
    return self.Binding.Key
end

function Keybind:Set(key, silent)
    self.Binding:SetKey(key)
end

function Keybind:Reset()
    self.Binding:SetKey(self.Def.Default or self.Def.Key)
    self.Binding:SetMode(self.Def.Mode or "Toggle")
end

function Keybind:Save()
    return self.Binding:Save()
end

function Keybind:Load(value)
    if type(value) == "table" then
        self.Binding:Load(value)
    elseif type(value) == "string" then
        self.Binding:SetKey(value)
    end
end

function Keybind:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Keybind",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(1, -150, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local modeHolder = Util.New("Frame", {
        Size = UDim2.fromOffset(62, 20),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.2 },
        Parent = row,
    })
    Util.Corner(5, modeHolder)
    local modeLabel = Util.Label({
        Text = self.Binding.Mode,
        TextSize = 11,
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        Color = "TextDim",
        Parent = modeHolder,
    })
    local pill = Widgets.KeyPill(row, self.Window, self.Binding, { Tooltip = "Click to bind" })
    pill.Button.AnchorPoint = Vector2.new(1, 0.5)
    pill.Button.Position = UDim2.new(1, -68, 0.5, 0)
    Router.Attach(modeHolder, {
        OnClick = function()
            local modes = self.Binding.Modes
            local index = table.find(modes, self.Binding.Mode) or 0
            self.Binding:SetMode(modes[(index % #modes) + 1])
        end,
        Tooltip = "Toggle, Hold or Always",
    })
    mount:Give(function() pill:Destroy() end)
    mount:Give(self.Binding.Changed:Connect(function()
        modeLabel.Text = self.Binding.Mode
    end))
    return row
end

return Keybind
end

__modules["Elements/Label"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Label: title on the left, a small value on the right that can change live
-- options: Text, Value, Color (token), ValueColor, Size
local Label = Base.Class("Label")

function Label.new(container, def)
    local self = setmetatable({ Value = def.Value }, Label)
    self.Default = def.Value
    Base.Init(self, container, def)
    self.LabelText = def.Text or def.Title
    self.Title = self.LabelText
    self.ValueColor = def.ValueColor
    return self
end

function Label:Set(text)
    self.LabelText = tostring(text)
    self.StateChanged:Fire("Text")
end

function Label:SetValue(value)
    self.Value = value
    self.StateChanged:Fire("Value")
end

function Label:SetValueColor(color)
    self.ValueColor = color
    self.StateChanged:Fire("ValueColor")
end

function Label:Get() return self.Value end
function Label:Save() return nil end
function Label:Load() end

function Label:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, self.Def.Size or 28),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local title = Util.Label({
        Text = self.LabelText,
        TextSize = 13,
        Size = UDim2.new(1, -90, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        Color = self.Def.Color or "TextDim",
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local value = Util.Label({
        Text = self.Value ~= nil and tostring(self.Value) or "",
        TextSize = 12,
        Weight = Enum.FontWeight.Medium,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 86, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Theme = {
            TextColor3 = function(t)
                local color = self.ValueColor
                if typeof(color) == "Color3" then return color end
                return t[color or "Text"] or t.Text
            end,
        },
        Parent = row,
    })
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Text" then title.Text = self.LabelText
        elseif state == "Value" then value.Text = self.Value ~= nil and tostring(self.Value) or ""
        elseif state == "ValueColor" then
            value.TextColor3 = typeof(self.ValueColor) == "Color3" and self.ValueColor or (Theme.Current[self.ValueColor or "Text"] or Theme.Current.Text)
        end
    end))
    if self.Def.Tooltip then Router.Attach(title, { Tooltip = self.Def.Tooltip }) end
    return row
end

return Label
end

__modules["Elements/Log"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")

-- Log: a scrolling list of timestamped lines inside a card
local Log = Base.Class("Log")

function Log.new(container, def)
    local self = setmetatable({ Lines = {} }, Log)
    Base.Init(self, container, def)
    self.MaxLines = def.MaxLines or 200
    self.Height = def.Height or 150
    self.Timestamps = def.Timestamps ~= false
    return self
end

function Log:Add(text, color)
    local line = { text = tostring(text), color = color }
    table.insert(self.Lines, line)
    if #self.Lines > self.MaxLines then table.remove(self.Lines, 1) end
    self.StateChanged:Fire("Add", line)
end

function Log:AddColored(text, colorToken)
    self:Add(text, colorToken)
end

function Log:Clear()
    self.Lines = {}
    self.StateChanged:Fire("Clear")
end

function Log:Set(lines)
    self.Lines = {}
    for _, line in lines do table.insert(self.Lines, { text = tostring(line) }) end
    self.StateChanged:Fire("Clear")
end

function Log:Save() return nil end
function Log:Load() end

function Log:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local holder = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, self.Height + 12),
        Theme = { BackgroundColor3 = "Background", BackgroundTransparency = 0.35 },
        Parent = row,
    })
    Util.Corner("ElementRadius", holder)
    Util.Stroke(holder, "Divider", function(t) return 0.6 end)
    local header = Util.Label({
        Text = self.Title,
        TextSize = 10,
        Weight = Enum.FontWeight.SemiBold,
        Position = UDim2.fromOffset(10, 5),
        Size = UDim2.new(1, -20, 0, 14),
        Color = "TextMuted",
        Parent = holder,
    })
    local scroll = Util.New("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -24),
        Position = UDim2.fromOffset(8, 20),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        Theme = { ScrollBarImageColor3 = "Stroke" },
        Parent = holder,
    })
    local list = Util.List(scroll, 1)
    local update = Util.AutoCanvas(scroll, list)
    local function addLine(line)
        local text = line.text
        if self.Timestamps then
            text = os.date("[%H:%M:%S] ") .. text
        end
        local label = Util.Label({
            Text = text,
            TextSize = 11,
            TextWrapped = true,
            Size = UDim2.new(1, -4, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Color = line.color,
            Parent = scroll,
        })
        label.TextColor3 = typeof(line.color) == "Color3" and line.color or Theme.Current[line.color or "TextDim"]
        update()
        task.defer(function()
            if scroll.Parent then
                local layout = scroll:FindFirstChildOfClass("UIListLayout")
                if layout then scroll.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y) end
            end
        end)
    end
    for _, line in self.Lines do addLine(line) end
    mount:Give(self.StateChanged:Connect(function(state, line)
        if state == "Add" then
            addLine(line)
        elseif state == "Clear" then
            for _, child in scroll:GetChildren() do
                if child:IsA("TextLabel") then child:Destroy() end
            end
            for _, item in self.Lines do addLine(item) end
        end
    end))
    scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() update() end)
    return row
end

return Log
end

__modules["Elements/Paragraph"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Paragraph: a wrapped block of rich text with an optional title and icon
local Paragraph = Base.Class("Paragraph")

function Paragraph.new(container, def)
    local self = setmetatable({}, Paragraph)
    Base.Init(self, container, def)
    self.Content = def.Content or def.Text or ""
    return self
end

function Paragraph:SetContent(text)
    self.Content = text
    self.StateChanged:Fire("Content")
end
function Paragraph:Set(text) self:SetContent(text) end
function Paragraph:Get() return self.Content end
function Paragraph:Save() return nil end
function Paragraph:Load() end

function Paragraph:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Padding(row, 2, 4, 4, 4)
    local heading = self.Def.Title or self.Title
    local y = 0
    if heading and heading ~= "" and heading ~= self.Content then
        if self.Def.Icon then
            Util.Icon(self.Def.Icon, {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.fromOffset(0, 2),
                Color = "Accent",
                Parent = row,
            })
        end
        local title = Util.Label({
            Text = heading,
            TextSize = 13,
            Weight = Enum.FontWeight.SemiBold,
            Position = UDim2.fromOffset(self.Def.Icon and 20 or 0, 0),
            Size = UDim2.new(1, self.Def.Icon and -20 or 0, 0, 18),
            Parent = row,
        })
        y = 22
        mount:Give(self.StateChanged:Connect(function() title.Text = self.Def.Title or self.Title end))
    end
    local body = Util.Label({
        Text = self.Content,
        TextSize = 12,
        TextWrapped = true,
        RichText = true,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Color = "TextDim",
        Parent = row,
    })
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Content" then body.Text = self.Content end
    end))
    return row
end

return Paragraph
end

__modules["Elements/ProgressBar"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- ProgressBar: animated fill; Set(value) with an optional tween
local ProgressBar = Base.Class("ProgressBar")

function ProgressBar.new(container, def)
    local self = setmetatable({ Value = def.Default or def.Value or 0 }, ProgressBar)
    self.Default = self.Value
    Base.Init(self, container, def)
    self.Max = def.Max or 100
    self.Suffix = def.Suffix or "%"
    self.Format = def.Format
    return self
end

function ProgressBar:Set(value, silent)
    value = math.clamp(tonumber(value) or 0, 0, self.Max)
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
end

function ProgressBar:SetMax(max)
    self.Max = math.max(tonumber(max) or 1, 0.0001)
    self.Changed:Fire(self.Value)
end

function ProgressBar:Get() return self.Value end
function ProgressBar:Save() return nil end
function ProgressBar:Load() end

function ProgressBar:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, 38),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 12,
        Size = UDim2.new(1, -60, 0, 16),
        Position = UDim2.fromOffset(2, 0),
        Color = "TextDim",
        Parent = row,
    })
    local valueLabel = Util.Label({
        Text = "",
        TextSize = 11,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -2, 0, 0),
        Size = UDim2.new(0, 60, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Right,
        Color = "TextMuted",
        Parent = row,
    })
    local track = Util.New("Frame", {
        Size = UDim2.new(1, -4, 0, 8),
        Position = UDim2.fromOffset(2, 22),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.1 },
        Parent = row,
    })
    Util.Corner(4, track)
    local fill = Util.New("Frame", {
        Size = UDim2.fromScale(0, 1),
        Theme = { BackgroundColor3 = typeof(self.Def.Color) == "Color3" and function() return self.Def.Color end or (self.Def.Color or "Accent") },
        Parent = track,
    })
    Util.Corner(4, fill)
    Util.Gradient(fill, "Accent", "AccentAlt", 0)
    local function display(value)
        if self.Format then
            local ok, text = pcall(self.Format, value, self.Max)
            if ok then return tostring(text) end
        end
        return math.floor(value / self.Max * 100 + 0.5) .. self.Suffix
    end
    local function paint(animate)
        local alpha = math.clamp(self.Value / self.Max, 0, 1)
        valueLabel.Text = display(self.Value)
        if animate and Theme.Current.AnimSpeed > 0 then
            Util.Tween(fill, 0.25, { Size = UDim2.fromScale(alpha, 1) })
        else
            fill.Size = UDim2.fromScale(alpha, 1)
        end
    end
    fill.Size = UDim2.fromScale(math.clamp(self.Value / self.Max, 0, 1), 1)
    paint(false)
    mount:Give(self.Changed:Connect(function() paint(true) end))
    return row
end

return ProgressBar
end

__modules["Elements/RangeSlider"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")

-- Range: two knobs on one track. Default = { lo, hi }, callback gets (lo, hi)
local RangeSlider = Base.Class("RangeSlider")

RangeSlider.DefaultValue = import("Elements/Slider").DefaultValue

function RangeSlider.new(container, def)
    def.Min = tonumber(def.Min) or 0
    def.Max = tonumber(def.Max) or 100
    if def.Max < def.Min then def.Min, def.Max = def.Max, def.Min end
    def.Step = tonumber(def.Step or def.Rounding)
    local default = def.Default or { def.Min, def.Max }
    local lo = RangeSlider.DefaultValue(def, default[1] or def.Min)
    local hi = RangeSlider.DefaultValue(def, default[2] or def.Max)
    lo, hi = math.min(lo, hi), math.max(lo, hi)
    local self = setmetatable({ Value = { lo, hi }, Low = lo, High = hi }, RangeSlider)
    self.Default = { lo, hi }
    Base.Init(self, container, def)
    self.Min, self.Max, self.Step = def.Min, def.Max, def.Step
    self.MinGap = def.MinGap or 0
    self.Suffix = def.Suffix or ""
    self.Prefix = def.Prefix or ""
    self.Format = def.Format
    return self
end

function RangeSlider:Display(value)
    value = value == nil and self.Value or value
    local function one(v)
        if self.Format then
            local ok, text = pcall(self.Format, v)
            if ok then return tostring(text) end
        end
        if self.Step and self.Step < 1 and self.Step > 0 then
            local decimals = math.max(0, -math.floor(math.log(self.Step, 10) + 0.5))
            return (string.format("%." .. decimals .. "f", v):gsub("0+$", ""):gsub("%.$", ""))
        end
        return tostring(math.floor(v + 0.5))
    end
    return self.Prefix .. one(value[1]) .. " – " .. one(value[2]) .. self.Suffix
end

function RangeSlider:Set(value, silent)
    if type(value) ~= "table" then return end
    local first = tonumber(value[1]) or 0
    local second = tonumber(value[2]) or 0
    local lo = math.max(math.min(first, second), 0)
    local hi = math.max(first, second)
    local min, max = tonumber(self.Min) or 0, tonumber(self.Max) or 100
    lo, hi = math.clamp(lo, min, max), math.clamp(hi, min, max)
    if self.Step and self.Step > 0 then
        lo = Util.Clean(Util.Round(lo, self.Step), self.Step)
        hi = Util.Clean(Util.Round(hi, self.Step), self.Step)
    end
    if self.MinGap > 0 then
        if hi - lo < self.MinGap then
            if self._editingHigh then
                lo = hi - self.MinGap
            else
                hi = lo + self.MinGap
            end
        end
        lo = math.max(lo, self.Min)
        hi = math.min(hi, self.Max)
    end
    self.Low, self.High = lo, hi
    self.Value = { lo, hi }
    self.Changed:Fire(self.Value)
    if not silent then
        Util.Safe(self.Def.Callback, lo, hi)
        self:_notifyListeners()
    end
    self.Window:_touch()
end

function RangeSlider:_notifyListeners()
    for _, fn in self._listeners do Util.Safe(fn, self.Low, self.High) end
end

function RangeSlider:_args()
    return self.Low, self.High
end

function RangeSlider:GetLow() return self.Low end
function RangeSlider:GetHigh() return self.High end

function RangeSlider:Reset()
    self:Set(self.Default)
end

function RangeSlider:Save()
    return { self.Low, self.High }
end

function RangeSlider:Load(value)
    if type(value) == "table" then self:Set(value, true) end
end

function RangeSlider:Render(parent, mount)
    local def = self.Def
    local row = Util.New("Frame", {
        Name = "Range",
        Size = UDim2.new(1, -6, 0, self.Description and 64 or 46),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local functions = Util.New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 20),
        Position = UDim2.fromOffset(8, 6),
        Parent = row,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(1, -100, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = functions,
    })
    local valueLabel = Util.Label({
        Text = self:Display(),
        TextSize = 12,
        Weight = Enum.FontWeight.Medium,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 100, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        Color = "TextDim",
        Parent = functions,
    })

    local holder = Util.New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 34),
        Size = UDim2.new(1, -16, 0, 16),
        Parent = row,
    })
    local track = Util.New("Frame", {
        Position = UDim2.fromOffset(0, 5),
        Size = UDim2.new(1, 0, 0, 6),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.1 },
        Parent = holder,
    })
    Util.Corner(3, track)
    local fill = Util.New("Frame", {
        Size = UDim2.fromScale(0, 1),
        Theme = { BackgroundColor3 = "Accent" },
        Parent = track,
    })
    Util.Corner(3, fill)
    Util.Gradient(fill, "Accent", "AccentAlt", 0)

    local lowKnob = Util.New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 2,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    Util.Corner(7, lowKnob)
    Util.Stroke(lowKnob, "Background", nil, 2)
    local highKnob = Util.New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 2,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    Util.Corner(7, highKnob)
    Util.Stroke(highKnob, "Background", nil, 2)

    local function paint(animate)
        local span = self.Max - self.Min
        local a = span <= 0 and 0 or (self.Low - self.Min) / span
        local b = span <= 0 and 1 or (self.High - self.Min) / span
        a, b = math.clamp(a, 0, 1), math.clamp(b, 0, 1)
        local goal = { Position = UDim2.new(a, 0, 0.5, 0) }
        local goalHigh = { Position = UDim2.new(b, 0, 0.5, 0) }
        local fillGoal = { Position = UDim2.fromScale(a, 0), Size = UDim2.fromScale(b - a, 1) }
        if animate and Animation.Speed > 0 then
            Animation.Tween(lowKnob, "Hover", goal)
            Animation.Tween(highKnob, "Hover", goalHigh)
            Animation.Tween(fill, "Hover", fillGoal)
        else
            for key, value in goal do lowKnob[key] = value end
            for key, value in goalHigh do highKnob[key] = value end
            for key, value in fillGoal do fill[key] = value end
        end
        valueLabel.Text = self:Display()
    end
    paint(false)

    local function fromPoint(x)
        local width = track.AbsoluteSize.X
        if width <= 0 then return self.Value end
        local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        return self.Min + alpha * (self.Max - self.Min)
    end

    local dragging = nil
    local handle = Router.Attach(track, {
        Disabled = function() return self.Locked end,
        OnPress = function(_, point)
            local value = fromPoint(point.X)
            -- grab the nearer knob
            if math.abs(value - self.Low) <= math.abs(value - self.High) then
                dragging = "low"
                self._editingHigh = false
            else
                dragging = "high"
                self._editingHigh = true
            end
            local lo, hi = self.Low, self.High
            if dragging == "low" then lo = value else hi = value end
            self:Set({ lo, hi })
            paint(false)
            Animation.Tween(dragging == "low" and lowKnob or highKnob, "Press", { Size = UDim2.fromOffset(16, 16) })
        end,
        OnDrag = function(_, point)
            local value = fromPoint(point.X)
            local lo, hi = self.Low, self.High
            if dragging == "low" then lo = value else hi = value end
            self:Set({ lo, hi })
            paint(false)
        end,
        OnRelease = function()
            Animation.Tween(lowKnob, "Press", { Size = UDim2.fromOffset(14, 14) })
            Animation.Tween(highKnob, "Press", { Size = UDim2.fromOffset(14, 14) })
            dragging = nil
        end,
    })
    mount:Give(handle)
    mount:Give(self.Changed:Connect(function(value)
        if not dragging then paint(true) else valueLabel.Text = self:Display() end
    end))
    mount:Give(self.StateChanged:Connect(function() paint(false) end))
    return row
end

return RangeSlider
end

__modules["Elements/Segmented"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")

-- Segmented: a row of small tabs with a sliding highlight, or a stack when Values has many entries
local Segmented = Base.Class("Segmented")

function Segmented.new(container, def)
    local values = def.Values or {}
    local default = def.Default
    if default == nil then default = type(values[1]) == "table" and values[1].Value or values[1] end
    local self = setmetatable({ Value = default }, Segmented)
    self.Default = default
    Base.Init(self, container, def)
    self.Values = values
    return self
end

function Segmented:_index(value)
    for index, entry in self.Values do
        local v = type(entry) == "table" and (entry.Value ~= nil and entry.Value or entry.Title) or entry
        if v == value then return index end
    end
    return nil
end

function Segmented:Get() return self.Value end

function Segmented:Set(value, silent)
    local index = self:_index(value)
    if not index then return end
    if value == self.Value then return end
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
    self.Window:_touch()
end

function Segmented:Save() return self.Value end
function Segmented:Load(value) if value ~= nil then self:Set(value, true) end end

function Segmented:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Segmented",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(0.4, -6, 1, 0),
        Position = UDim2.fromOffset(2, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local width = self.Def.Width or (self.Def.Full and 1 or 0.6)
    local holder = Util.New("Frame", {
        Size = UDim2.new(width, width == 0.6 and -2 or -8, 1, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = function(t) return math.max(0.05, t.ElevatedTransparency) end },
        Parent = row,
    })
    Util.Corner("ElementRadius", holder)
    local highlight = Util.New("Frame", {
        Size = UDim2.fromScale(1 / math.max(#self.Values, 1), 1),
        Theme = { BackgroundColor3 = "SurfaceHover" },
        Parent = holder,
    })
    Util.Corner("ElementRadius", highlight)
    Util.Stroke(highlight, "Divider", function(t) return 0.5 end)
    local buttons = {}
    local function indexOf(value)
        for index, entry in self.Values do
            local v = type(entry) == "table" and (entry.Value ~= nil and entry.Value or entry.Title) or entry
            if v == value then return index end
        end
        return 1
    end
    local function paint(animate)
        local index = indexOf(self.Value)
        local goal = { Position = UDim2.fromScale((index - 1) / math.max(#self.Values, 1), 0) }
        if animate then
            Animation.Tween(highlight, "Toggle", goal)
        else
            for key, value in goal do highlight[key] = value end
        end
        for i, button in buttons do
            button.Label.TextColor3 = i == index and Theme.Current.Text or Theme.Current.TextMuted
        end
    end
    for index, entry in self.Values do
        local title = type(entry) == "table" and (entry.Title or tostring(entry.Value)) or tostring(entry)
        local value = type(entry) == "table" and (entry.Value ~= nil and entry.Value or entry.Title) or entry
        local button = Util.New("TextButton", {
            Size = UDim2.fromScale(1 / #self.Values, 1),
            Position = UDim2.fromScale((index - 1) / #self.Values, 0),
            Text = "",
            BackgroundTransparency = 1,
            Parent = holder,
        })
        local label = Util.Label({
            Text = title,
            TextSize = 11,
            Weight = Enum.FontWeight.Medium,
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = button,
        })
        buttons[index] = { Button = button, Label = label, Value = value }
        Router.Attach(button, {
            OnClick = function()
                if self.Locked then return end
                self:Set(value)
            end,
        })
    end
    paint(false)
    mount:Give(self.Changed:Connect(function() paint(true) end))
    return row
end

return Segmented
end

__modules["Elements/Slider"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")

-- Slider: a track, a fill, a draggable knob, an editable value on the right, optional - / + buttons.
-- Range mode uses RangeSlider (a separate file) which reuses this layout.
local Slider = Base.Class("Slider")

-- options: Min, Max, Default, Step, Format(v), Prefix, Suffix, Input (value box, default true),
--          Buttons (- / +, default false), Icons = { From, To }, ShowRange, Live (default true)
function Slider.new(container, def)
    def.Min = tonumber(def.Min) or 0
    def.Max = tonumber(def.Max) or 100
    if def.Max < def.Min then def.Min, def.Max = def.Max, def.Min end
    def.Step = tonumber(def.Step or def.Rounding)
    if def.Step and def.Step > 0 then
        def.Step = math.abs(def.Step)
        def.Default = def.Default or def.Min
    end
    local default = def.Default
    if default == nil then default = def.Min end
    default = Slider.DefaultValue(def, default)
    local self = setmetatable({ Value = default }, Slider)
    self.Default = default
    Base.Init(self, container, def)
    self.Min = def.Min
    self.Max = def.Max
    self.Step = def.Step
    self.Suffix = def.Suffix or ""
    self.Prefix = def.Prefix or ""
    self.Live = def.Live ~= false
    self.Input = def.Input ~= false
    self.Format = def.Format
    return self
end

local computeDefault
computeDefault = function(def, value)
    value = tonumber(value) or def.Min
    value = math.clamp(value, def.Min, def.Max)
    if def.Step and def.Step > 0 then value = Util.Round(value, def.Step) end
    return value
end

function Slider:Display(value)
    value = value == nil and self.Value or value
    if self.Format then
        local ok, text = pcall(self.Format, value)
        if ok then return tostring(self.Prefix) .. tostring(text) .. tostring(self.Suffix) end
    end
    local step = self.Step
    local text
    if step and step < 1 and step > 0 then
        local decimals = math.max(0, -math.floor(math.log(step, 10) + 0.5))
        text = string.format("%." .. decimals .. "f", value)
        text = text:gsub("0+$", ""):gsub("%.$", "")
    else
        text = tostring(math.floor(value + 0.5))
    end
    return self.Prefix .. text .. self.Suffix
end

function Slider:Set(value, silent)
    value = tonumber(value)
    if value == nil then return end
    value = math.clamp(value, self.Min, self.Max)
    if self.Step and self.Step > 0 then value = Util.Clean(Util.Round(value, self.Step), self.Step) end
    value = math.clamp(value, self.Min, self.Max)
    if value == self.Value then
        if not silent and self.Def.Live then return end
    end
    self.Value = value
    self.Changed:Fire(value)
    if not silent then self:_notify() end
    self.Window:_touch()
end

function Slider:SetMin(min)
    self.Min = tonumber(min) or self.Min
    self.Def.Min = self.Min
    if self.Value < self.Min then self:Set(self.Min) end
    self.StateChanged:Fire("Min")
end

function Slider:SetMax(max)
    self.Max = tonumber(max) or self.Max
    self.Def.Max = self.Max
    if self.Value > self.Max then self:Set(self.Max) end
    self.StateChanged:Fire("Max")
end

function Slider:Reset()
    self:Set(self.Default)
end

function Slider:Save()
    return self.Value
end

function Slider:Load(value)
    if type(value) == "number" then self:Set(value, true) end
end

function Slider:Render(parent, mount)
    local def = self.Def
    local row = Util.New("Frame", {
        Name = "Slider",
        Size = UDim2.new(1, -6, 0, self.Description and 64 or 46),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local functions = Util.New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 20),
        Position = UDim2.fromOffset(8, 6),
        Parent = row,
    })
    local title = Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Size = UDim2.new(1, -90, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Theme = {
            TextColor3 = function(t) return self.Locked and t.TextMuted or t.Text end,
            FontFace = Theme.Font(Enum.FontWeight.Medium),
        },
        Parent = functions,
    })
    local tooltip = def.Tooltip or (self.Locked and self.LockedReason) or nil
    if tooltip then
        local info = Util.Icon("circle-question-mark", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.fromOffset(title.TextBounds.X + 6, 4),
            Color = "TextMuted",
            Parent = functions,
        })
        Router.Attach(info, { Tooltip = tooltip })
    end
    local right = Util.New("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = functions,
    })
    Util.List(right, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local order = 0
    local function nextOrder() order += 1 return order end

    local valueBox
    if def.Input ~= false then
        valueBox = Util.New("TextBox", {
            Text = self:Display(),
            TextSize = 12,
            Size = UDim2.fromOffset(46, 20),
            TextXAlignment = Enum.TextXAlignment.Right,
            ClearTextOnFocus = false,
            LayoutOrder = nextOrder(),
            Theme = { TextColor3 = "TextDim", FontFace = Theme.Font(Enum.FontWeight.Medium) },
            Parent = right,
        })
        mount:Give(valueBox.FocusLost:Connect(function()
            local number = tonumber((valueBox.Text:gsub("[^%d%.%-]", "")))
            if number then self:Set(number) end
            valueBox.Text = self:Display()
        end))
        mount:Give(valueBox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                valueBox.CursorPosition = #valueBox.Text + 1
            end
        end))
    end

    if def.Buttons then
        local function stepper(icon, delta)
            local button = Util.New("TextButton", {
                Size = UDim2.fromOffset(18, 18),
                Text = "",
                LayoutOrder = nextOrder(),
                Theme = { BackgroundColor3 = "ElevatedHover", BackgroundTransparency = 0.2 },
                Parent = right,
            })
            Util.Corner(4, button)
            Util.Icon(icon, {
                Size = UDim2.fromOffset(10, 10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Parent = button,
            })
            Router.Attach(button, {
                OnClick = function()
                    local step = self.Step or ((self.Max - self.Min) / 100)
                    self:Set(self.Value + step * delta)
                end,
            })
            return button
        end
        stepper("minus", -1)
        stepper("plus", 1)
    end

    -- track ---------------------------------------------------------------------
    local trackY = 34
    local trackHolder = Util.New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, trackY),
        Size = UDim2.new(1, -16, 0, 16),
        Parent = row,
    })
    local leftIcon = def.Icons and def.Icons.From or def.IconFrom
    local rightIcon = def.Icons and def.Icons.To or def.IconTo
    local leftPad, rightPad = 0, 0
    if leftIcon then
        Util.Icon(leftIcon, {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.new(0, 0, 0.5, -6),
            Parent = trackHolder,
        })
        leftPad = 18
    end
    if rightIcon then
        Util.Icon(rightIcon, {
            Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Parent = trackHolder,
        })
        rightPad = 18
    end
    local track = Util.New("Frame", {
        Name = "Track",
        Position = UDim2.fromOffset(leftPad, 5),
        Size = UDim2.new(1, -(leftPad + rightPad), 0, 6),
        Theme = { BackgroundColor3 = "Elevated", BackgroundTransparency = 0.1 },
        Parent = trackHolder,
    })
    Util.Corner(3, track)
    local fill = Util.New("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        Theme = { BackgroundColor3 = "Accent" },
        Parent = track,
    })
    Util.Corner(3, fill)
    Util.Gradient(fill, "Accent", "AccentAlt", 0)
    local knob = Util.New("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 2,
        Theme = { BackgroundColor3 = "Text" },
        Parent = track,
    })
    Util.Corner(7, knob)
    Util.Stroke(knob, "Background", nil, 2)
    local knobScale = Util.New("UIScale", { Scale = 1, Parent = knob })

    local dragging = { on = false }

    local function paint(value, animate)
        local span = self.Max - self.Min
        local alpha = span <= 0 and 0 or (value - self.Min) / span
        alpha = math.clamp(alpha, 0, 1)
        if animate and Animation.Speed > 0 then
            Animation.Tween(fill, "Hover", { Size = UDim2.fromScale(alpha, 1) })
            Animation.Tween(knob, "Hover", { Position = UDim2.new(alpha, 0, 0.5, 0) })
        else
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        end
        if valueBox and not valueBox:IsFocused() then valueBox.Text = self:Display(value) end
    end

    paint(self.Value, false)

    local function fromPoint(x)
        local width = track.AbsoluteSize.X
        if width <= 0 then return self.Value end
        local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        return self.Min + alpha * (self.Max - self.Min)
    end

    local handle
    handle = Router.Attach(track, {
        Disabled = function() return self.Locked end,
        OnPress = function(_, point)
            dragging.on = true
            Animation.Tween(knobScale, "Press", { Scale = 1.25 })
            self:Set(fromPoint(point.X))
        end,
        OnDrag = function(_, point)
            local value = fromPoint(point.X)
            if self.Live then
                self:Set(value)
                paint(value, false)
            else
                paint(value, false)
                self._pendingValue = value
            end
        end,
        OnRelease = function()
            dragging.on = false
            Animation.Tween(knobScale, "Press", { Scale = 1 })
            if self._pendingValue then
                self:Set(self._pendingValue)
                self._pendingValue = nil
            end
        end,
        OnClick = function(point)
            self:Set(fromPoint(point.X))
        end,
    })
    mount:Give(handle)
    mount:Give(Util.Hover(track, function(on)
        if dragging.on then return end
        Animation.Tween(knobScale, "Hover", { Scale = on and 1.18 or 1 })
    end))

    mount:Give(self.Changed:Connect(function(value)
        if dragging.on then return end
        paint(value, true)
    end))
    if valueBox then
        mount:Give(self.StateChanged:Connect(function() paint(self.Value, false) end))
    end
    mount:Give(row)

    self._paint = paint
    return row
end

Slider.DefaultValue = computeDefault

return Slider
end

__modules["Elements/Spacer"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Spacer
local Spacer = Base.Class("Spacer")

function Spacer.new(container, def)
    local self = setmetatable({}, Spacer)
    Base.Init(self, container, def)
    return self
end
function Spacer:Save() return nil end
function Spacer:Load() end

function Spacer:Render(parent, mount)
    return Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, self.Def.Height or 8),
        BackgroundTransparency = 1,
        Parent = parent,
    })
end

return Spacer
end

__modules["Elements/Toggle"] = function(...)
local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Widgets = import("Components/Widgets")
local Binding = import("Core/Binding")

-- Toggle / Checkbox: a switch or a square checkbox, with an optional key pill, an optional value
-- field and an optional colour swatch in the same row.
local Toggle = Base.Class("Toggle")

function Toggle.new(container, def)
    local self = setmetatable({}, Toggle)
    self.Value = def.Default == true
    self.Default = self.Value
    self.Style = def.Style or "Switch"
    Base.Init(self, container, def)

    if def.Keybind and def.Keybind ~= false then
        local spec = type(def.Keybind) == "table" and def.Keybind or { Key = def.Keybind ~= true and def.Keybind or def.Key }
        self.Binding = Binding.new({
            Key = spec.Key or spec.Default,
            Mode = spec.Mode or "Toggle",
            Modes = spec.Modes or { "Toggle", "Hold" },
            Capture = spec,
            Press = function(binding)
                if self.Locked then return end
                if binding.Mode == "Hold" then
                    self:Set(true)
                else
                    self:Set(not self.Value)
                end
            end,
            Release = function(binding)
                if binding.Mode == "Hold" and not self.Locked then self:Set(false) end
            end,
        })
        self.Window:_trackBind(self)
    end

    if def.Field then
        local spec = table.clone(def.Field)
        spec.Title = spec.Title or (self.Title .. " value")
        spec.Flag = spec.Flag or (self.Flag and (self.Flag .. "Value"))
        spec.Width = spec.Width or 70
        self.Field = import("Elements/Input").new(container, spec)
    end
    if def.Color then
        local spec = table.clone(def.Color)
        spec.Title = spec.Title or (self.Title .. " colour")
        spec.Flag = spec.Flag or (self.Flag and (self.Flag .. "Color"))
        self.Color = import("Elements/ColorPicker").new(container, spec)
    end

    -- in-row value editing: a compact box rendered by the row itself
    self.InlineField = def.Field ~= nil
    return self
end

function Toggle:Get()
    return self.Value
end

-- the optional value box is rendered inside the row and reads from its Input element
function Toggle:SetFieldText(text)
    if self._fieldBox and not self._fieldBox:IsFocused() then self._fieldBox.Text = text end
end

function Toggle:Set(value, silent)
    value = value and true or false
    if value == self.Value then return end
    self:_commit(value, silent)
end

function Toggle:ToggleEnabled()
    self:Set(not self.Value)
end

function Toggle:BindInfo()
    return self.Title, self.Value
end

function Toggle:Save()
    return self.Value
end

function Toggle:Load(value)
    if type(value) == "boolean" then self:Set(value) end
end

function Toggle:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Toggle",
        Size = UDim2.new(1, -6, 0, 30),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local reserve = 8
    if self.Binding then reserve += 46 end
    if self.Field then reserve += 58 end
    if self.Color then reserve += 34 end
    local hover = { on = false }

    local clickable = Util.New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        Text = "",
        Theme = {
            BackgroundColor3 = "SurfaceHover",
            BackgroundTransparency = function()
                return hover.on and 0.55 or 1
            end,
        },
        Parent = row,
    })
    Util.Corner("ElementRadius", clickable)
    mount:Give(clickable)

    local title = Util.Label({
        Text = self.Title,
        TextSize = 13,
        Weight = Enum.FontWeight.Medium,
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -(reserve + 8), 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = clickable,
    })
    local description
    if self.Description and self.Description ~= "" then
        row.Size = UDim2.new(1, -6, 0, 44)
        title.Size = UDim2.new(1, -(reserve + 8), 0, 18)
        title.Position = UDim2.fromOffset(8, 7)
        description = Util.Label({
            Text = self.Description,
            TextSize = 11,
            Position = UDim2.fromOffset(8, 24),
            Size = UDim2.new(1, -(reserve + 8), 0, 14),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Color = "TextMuted",
            Parent = clickable,
        })
    end

    -- the control side is laid out right to left with absolute anchors so the row can hold
    -- a field, a colour swatch, a key pill and the switch in any combination
    local control
    local function controlPosition(offset)
        if self.Style == "Checkbox" then
            control.Box.Position = UDim2.new(1, offset, 0.5, 0)
        else
            control.Track.Position = UDim2.new(1, offset, 0.5, 0)
        end
    end
    if self.Style == "Checkbox" then
        control = Widgets.Checkbox(clickable)
        control.Box.AnchorPoint = Vector2.new(1, 0.5)
        controlPosition(-6)
    else
        control = Widgets.Switch(clickable)
        control.Track.AnchorPoint = Vector2.new(1, 0.5)
        controlPosition(-6)
    end
    control:Set(self.Value, false)

    -- a key pill grows to the left of the switch; the switch slides left to make room
    local pill = nil
    local function placePill()
        if not pill then return end
        local width = pill.Button.AbsoluteSize.X
        if width <= 0 then return end
        local right = -6 - (self.Style == "Checkbox" and 18 or 34) - 8
        pill.Button.Position = UDim2.new(1, right, 0.5, 0)
        controlPosition(-6 - (self.Style == "Checkbox" and 18 or 34) - width - 10)
    end

    if self.Binding then
        pill = Widgets.KeyPill(clickable, self.Window, self.Binding, { Tooltip = "Click to bind a key, right click for Hold / Always" })
        pill.Button.AnchorPoint = Vector2.new(1, 0.5)
        mount:Give(function() pill:Destroy() end)
        mount:Give(self.Binding.Changed:Connect(placePill))
        mount:Give(pill.Button:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePill))
        task.defer(placePill)
        task.delay(0.1, placePill)
    end

    local function paintState()
        control:Set(self.Value, true)
        if self.Def.Field and self.Field then self:SetFieldText(tostring(self.Field:Get())) end
        if self.Locked then
            title.TextColor3 = Theme.Current.TextMuted
        elseif self.Def.Risky then
            title.TextColor3 = Theme.Current.Danger
        else
            title.TextColor3 = Theme.Current.Text
        end
    end

    paintState()
    mount:Give(self.Changed:Connect(paintState))
    mount:Give(self.StateChanged:Connect(paintState))

    local handle
    handle = Router.Attach(clickable, {
        OnClick = function()
            if self.Locked then
                if self.LockReason then self.Window:Notify({ Title = self.Title, Content = self.LockReason, Type = "Warning" }) end
                return
            end
            self:Set(not self.Value)
        end,
        Disabled = function() return false end,
        Tooltip = self.Tooltip or (self.Locked and self.LockedReason) or nil,
    })
    mount:Give(handle)

    -- hovering the row lifts it so a list of toggles is easy to scan
    mount:Give(Util.Hover(clickable, function(on)
        hover.on = on
        Theme.Refresh(clickable, 0.12)
    end))
    mount:Give(clickable)

    self.Views = self.Views or {}
    return row
end

return Toggle
end

__modules["Themes/Presets"] = function(...)
local _ = ...

-- palettes only hold colours; style tokens (radius, font, transparency, ...) live in Core/Theme
local rgb = Color3.fromRGB

local function palette(p)
    return {
        Accent = p.Accent,
        AccentAlt = p.AccentAlt,
        Background = p.Background,
        BackgroundAlt = p.BackgroundAlt,
        Surface = p.Surface,
        SurfaceHover = p.SurfaceHover,
        Elevated = p.Elevated,
        ElevatedHover = p.ElevatedHover,
        Stroke = p.Stroke,
        Divider = p.Divider,
        Text = p.Text or rgb(232, 233, 240),
        TextDim = p.TextDim or rgb(152, 154, 168),
        TextMuted = p.TextMuted or rgb(98, 100, 114),
        OnAccent = p.OnAccent or rgb(255, 255, 255),
        Success = p.Success or rgb(74, 200, 122),
        Warning = p.Warning or rgb(244, 182, 62),
        Danger = p.Danger or rgb(236, 88, 88),
        Info = p.Info or rgb(88, 166, 255),
    }
end

return {
    Order = { "Sapphire", "Obsidian", "Midnight", "Ocean", "Emerald", "Amber", "Crimson", "Rose", "Paper", "Violet" },

    Sapphire = palette({
        Accent = rgb(78, 132, 255), AccentAlt = rgb(140, 205, 255),
        Background = rgb(6, 6, 9), BackgroundAlt = rgb(36, 38, 46),
        Surface = rgb(12, 12, 16), SurfaceHover = rgb(20, 20, 26),
        Elevated = rgb(24, 25, 32), ElevatedHover = rgb(33, 34, 43),
        Stroke = rgb(88, 92, 110), Divider = rgb(52, 54, 66),
    }),

    Obsidian = palette({
        Accent = rgb(222, 222, 228), AccentAlt = rgb(120, 120, 130),
        Background = rgb(5, 5, 6), BackgroundAlt = rgb(48, 48, 52),
        Surface = rgb(11, 11, 12), SurfaceHover = rgb(20, 20, 22),
        Elevated = rgb(24, 24, 27), ElevatedHover = rgb(34, 34, 38),
        Stroke = rgb(92, 92, 100), Divider = rgb(55, 55, 60),
        OnAccent = rgb(12, 12, 14),
    }),

    Midnight = palette({
        Accent = rgb(146, 112, 255), AccentAlt = rgb(206, 172, 255),
        Background = rgb(8, 7, 14), BackgroundAlt = rgb(34, 26, 58),
        Surface = rgb(14, 12, 24), SurfaceHover = rgb(22, 19, 36),
        Elevated = rgb(27, 23, 44), ElevatedHover = rgb(37, 32, 58),
        Stroke = rgb(96, 84, 140), Divider = rgb(55, 48, 84),
        Text = rgb(236, 232, 248), TextDim = rgb(160, 152, 186), TextMuted = rgb(104, 97, 132),
    }),

    Ocean = palette({
        Accent = rgb(38, 192, 232), AccentAlt = rgb(132, 232, 255),
        Background = rgb(4, 8, 11), BackgroundAlt = rgb(16, 36, 48),
        Surface = rgb(9, 14, 18), SurfaceHover = rgb(14, 22, 28),
        Elevated = rgb(18, 28, 36), ElevatedHover = rgb(26, 40, 50),
        Stroke = rgb(64, 104, 120), Divider = rgb(38, 62, 72),
        OnAccent = rgb(4, 14, 18),
    }),

    Emerald = palette({
        Accent = rgb(46, 204, 133), AccentAlt = rgb(120, 240, 186),
        Background = rgb(5, 9, 8), BackgroundAlt = rgb(18, 42, 34),
        Surface = rgb(10, 15, 13), SurfaceHover = rgb(16, 24, 20),
        Elevated = rgb(20, 32, 27), ElevatedHover = rgb(28, 44, 37),
        Stroke = rgb(64, 112, 92), Divider = rgb(38, 66, 54),
        OnAccent = rgb(4, 20, 13),
    }),

    Amber = palette({
        Accent = rgb(245, 176, 46), AccentAlt = rgb(255, 214, 132),
        Background = rgb(9, 7, 4), BackgroundAlt = rgb(48, 37, 18),
        Surface = rgb(15, 13, 9), SurfaceHover = rgb(24, 20, 13),
        Elevated = rgb(32, 27, 18), ElevatedHover = rgb(44, 37, 24),
        Stroke = rgb(116, 96, 56), Divider = rgb(66, 55, 34),
        OnAccent = rgb(20, 13, 2),
    }),

    Crimson = palette({
        Accent = rgb(236, 88, 88), AccentAlt = rgb(255, 150, 150),
        Background = rgb(9, 4, 5), BackgroundAlt = rgb(52, 20, 22),
        Surface = rgb(15, 9, 10), SurfaceHover = rgb(25, 14, 16),
        Elevated = rgb(34, 20, 22), ElevatedHover = rgb(46, 27, 30),
        Stroke = rgb(122, 62, 64), Divider = rgb(70, 38, 40),
    }),

    Rose = palette({
        Accent = rgb(247, 132, 178), AccentAlt = rgb(255, 190, 216),
        Background = rgb(10, 6, 8), BackgroundAlt = rgb(48, 26, 36),
        Surface = rgb(16, 10, 13), SurfaceHover = rgb(26, 16, 21),
        Elevated = rgb(35, 22, 28), ElevatedHover = rgb(47, 30, 38),
        Stroke = rgb(118, 74, 90), Divider = rgb(68, 44, 53),
        OnAccent = rgb(24, 6, 13),
    }),

    Paper = palette({
        Accent = rgb(64, 110, 240), AccentAlt = rgb(120, 160, 255),
        Background = rgb(238, 239, 244), BackgroundAlt = rgb(210, 216, 232),
        Surface = rgb(248, 249, 252), SurfaceHover = rgb(236, 238, 245),
        Elevated = rgb(229, 232, 240), ElevatedHover = rgb(220, 224, 235),
        Stroke = rgb(160, 166, 184), Divider = rgb(206, 210, 222),
        Text = rgb(28, 30, 38), TextDim = rgb(94, 98, 112), TextMuted = rgb(138, 142, 158),
        OnAccent = rgb(255, 255, 255),
    }),

    Violet = palette({
        Accent = rgb(186, 104, 255), AccentAlt = rgb(228, 160, 255),
        Background = rgb(7, 5, 12), BackgroundAlt = rgb(40, 22, 62),
        Surface = rgb(13, 10, 20), SurfaceHover = rgb(21, 16, 31),
        Elevated = rgb(30, 22, 44), ElevatedHover = rgb(40, 30, 58),
        Stroke = rgb(104, 74, 142), Divider = rgb(60, 44, 82),
    }),
}
end

__modules["init"] = function(...)
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
end

local Library = import("init")
Library.Version = "1.0.0"
return Library
