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
