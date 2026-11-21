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
