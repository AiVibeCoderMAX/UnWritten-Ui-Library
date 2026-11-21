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
