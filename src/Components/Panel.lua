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
