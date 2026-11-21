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
