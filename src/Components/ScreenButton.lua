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
