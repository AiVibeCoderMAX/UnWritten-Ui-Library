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
