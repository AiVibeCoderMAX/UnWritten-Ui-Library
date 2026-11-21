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
