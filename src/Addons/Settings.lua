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
