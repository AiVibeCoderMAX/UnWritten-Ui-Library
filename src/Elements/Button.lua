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
