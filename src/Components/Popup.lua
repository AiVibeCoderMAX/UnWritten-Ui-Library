local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Animation = import("Core/Animation")
local Maid = import("Core/Maid")
local Router = import("Core/Router")
local Layer = import("Components/Layer")

-- a floating surface in the overlay layer. Contents are built by the caller into popup.Body.
-- opts: Width, MaxHeight, Point (absolute) or Anchor (gui), Align = "Left" | "Right", ClosesOnClick = true
local Popup = {}
Popup.__index = Popup

local Z = 50

function Popup.new(opts)
    local self = setmetatable({
        Options = opts or {},
        Maid = Maid.new(),
        Open = false,
        Width = opts and opts.Width or 200,
    }, Popup)
    return self
end

function Popup:_build()
    local options = self.Options
    local frame = Util.New("Frame", {
        Name = "Popup",
        Size = UDim2.fromOffset(self.Width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = Z + 3,
        ClipsDescendants = true,
        Theme = {
            BackgroundColor3 = "Elevated",
            BackgroundTransparency = function(t) return math.max(0, t.ElevatedTransparency - 0.05) end,
        },
        Parent = Layer.Overlay,
    })
    Util.Corner("ElementRadius", frame)
    local stroke = Util.Stroke(frame, "Stroke", function(t) return t.StrokeTransparency - 0.1 end)
    Util.New("UIScale", { Scale = 0.96, Parent = frame })
    local body = Util.New("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(6, 6),
        ClipsDescendants = true,
        ZIndex = Z + 4,
        Parent = frame,
    })
    self.Frame = frame
    self.Body = body
    self.Stroke = stroke
    self.BodyList = Util.List(body, 2)
    self.Maid:Give(frame)
    -- keep the popup sized to its content: a list layout reports content size as it changes
    self.Maid:Give(self.BodyList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if not self.Open then return end
        local maxHeight = options.MaxHeight or 260
        local height = math.min(self.BodyList.AbsoluteContentSize.Y + 12, maxHeight)
        frame.Size = UDim2.fromOffset(self.Width, math.max(height, 12))
        body.Size = UDim2.new(1, -12, 0, math.max(height - 12, 0))
    end))
    return self
end

function Popup:OnClickOutside(fn)
    self.ClickOutside = fn
    return self
end

function Popup:IsOpen()
    return self.Open
end

function Popup:ContainsPoint(point)
    if not self.Open or not self.Frame then return false end
    local position = self.Frame.AbsolutePosition
    local size = self.Frame.AbsoluteSize
    return point.X >= position.X and point.X <= position.X + size.X
        and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

function Popup:Show()
    if not self.Frame then self:_build() end
    self.Open = true
    local options = self.Options
    local origin
    if options.Point then
        origin = options.Point
    elseif options.Anchor then
        origin = Layer.Place(options.Anchor, Vector2.new(self.Width, options.MinHeight or 40), options.Align == "Right")
    else
        origin = Vector2.new(200, 200)
    end
    self.Frame.Position = UDim2.fromOffset(origin.X, origin.Y)
    self.Frame.Visible = true
    self.Frame.Size = UDim2.fromOffset(self.Width, 12)
    local scale = self.Frame:FindFirstChildOfClass("UIScale")
    if scale then
        scale.Scale = 0.96
        Animation.Tween(scale, "Pop", { Scale = 1 })
    end
    Router.RegisterPopup(self)
    if self.Frame:FindFirstChildOfClass("UIScale") == nil then
        Util.New("UIScale", { Scale = 1, Parent = self.Frame })
    end
    return self
end

function Popup:Close()
    if not self.Open then return end
    self.Open = false
    if self.Frame then self.Frame.Visible = false end
    Router.UnregisterPopup(self)
    if self.ClickOutside then self.ClickOutside() end
end

function Popup:Toggle()
    if self.Open then self:Close() else self:Show() end
end

function Popup:Clear()
    for _, child in self.Body:GetChildren() do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
            child:Destroy()
        end
    end
    return self
end

function Popup:Destroy()
    Router.UnregisterPopup(self)
    self.Maid:Clean()
    self.Open = false
end

-- menu items: { Title, Icon, Hint, Checked, Danger, Disabled, Callback } or "-" for a divider
function Popup.Menu(items, opts)
    local menu = Popup.new({ Width = opts.Width or 190, Point = opts.Point, Anchor = opts.Anchor, MaxHeight = opts.MaxHeight })
    menu:_build()
    local popup = menu
    local function closeSoon()
        popup:Close()
    end
    for _, item in items do
        if item == "-" then
            local divider = Util.New("Frame", {
                Size = UDim2.new(1, -8, 0, 1),
                Position = UDim2.fromOffset(4, 3),
                Theme = { BackgroundColor3 = "Divider" },
                Parent = menu.Body,
            })
        else
            local hover = { on = false }
            local row = Util.New("TextButton", {
                Size = UDim2.new(1, 0, 0, 28),
                Text = "",
                Theme = {
                    BackgroundColor3 = "ElevatedHover",
                    BackgroundTransparency = function()
                        if item.Disabled then return 1 end
                        return hover.on and 0.45 or 1
                    end,
                },
                Parent = menu.Body,
            })
            Util.Corner(6, row)
            if item.Icon then
                Util.Icon(item.Icon, {
                    Size = UDim2.fromOffset(14, 14),
                    Position = UDim2.fromOffset(9, 7),
                    Color = item.Danger and "Danger" or "TextDim",
                    Parent = row,
                })
            end
            local label = Util.Label({
                Text = item.Title,
                TextSize = 12,
                Position = UDim2.fromOffset(item.Icon and 31 or 10, 0),
                Size = UDim2.new(1, item.Icon and -75 or -54, 1, 0),
                Color = item.Danger and "Danger" or (item.Disabled and "TextMuted" or "Text"),
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
            if item.Checked then
                Util.Icon("check", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Color = "Accent", Parent = row })
            elseif item.Hint then
                Util.Label({
                    Text = item.Hint,
                    TextSize = 10,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.new(0, 60, 0, 14),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Color = "TextMuted",
                    Parent = row,
                })
            end
            Util.Hover(row, function(on)
                hover.on = on
                Theme.Refresh(row, 0.1)
            end)
            Router.Attach(row, {
                Disabled = item.Disabled == true,
                OnClick = function()
                    closeSoon()
                    if item.Callback then Util.Defer(item.Callback, item.Value) end
                end,
            })
        end
    end
    return menu
end

return Popup
