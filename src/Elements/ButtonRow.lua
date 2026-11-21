local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")

-- Buttons: a row of two or three side-by-side buttons: { { Title, Icon, Style, Confirm, Callback }, ... }
local ButtonRow = Base.Class("ButtonRow")

function ButtonRow.new(container, def)
    local self = setmetatable({}, ButtonRow)
    Base.Init(self, container, def)
    self.Buttons = def.Buttons or def.List or {}
    return self
end

function ButtonRow:Press(index)
    local def = self.Buttons[index]
    if not def then return end
    local function run()
        if def.Callback then Util.Safe(def.Callback) end
    end
    if def.Confirm then
        self.Window:Dialog({
            Title = def.Title or self.Title,
            Content = type(def.Confirm) == "string" and def.Confirm or "Are you sure?",
            Icon = "triangle-alert",
            Buttons = {
                { Title = "Cancel", Style = "Secondary" },
                { Title = "Confirm", Style = def.Style == "Danger" and "Danger" or "Primary", Callback = run },
            },
        })
    else
        run()
    end
end

function ButtonRow:SetButtonTitle(index, text)
    local def = self.Buttons[index]
    if def then
        def.Title = text
        self.StateChanged:Fire("Buttons")
    end
end

function ButtonRow:SetButtonLocked(index, locked)
    local def = self.Buttons[index]
    if def then
        def.Locked = locked
        self.StateChanged:Fire("Buttons")
    end
end

function ButtonRow:Save() return nil end
function ButtonRow:Load() end

function ButtonRow:Render(parent, mount)
    local row = Util.New("Frame", {
        Name = "Buttons",
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local layout = Util.List(row, 6, Enum.FillDirection.Horizontal)
    local width = 1 / math.max(#self.Buttons, 1)
    local function rebuild()
        for _, child in row:GetChildren() do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for index, def in self.Buttons do
            local hover = { on = false }
            local button = Util.New("TextButton", {
                Text = "",
                Size = UDim2.new(width, index < #self.Buttons and -4 or 0, 1, 0),
                LayoutOrder = index,
                Theme = {
                    BackgroundColor3 = def.Style == "Primary" and "Accent" or (def.Style == "Danger" and "Danger" or "Elevated"),
                    BackgroundTransparency = function(t)
                        if def.Style == "Primary" or def.Style == "Danger" then return hover.on and 0 or 0.1 end
                        return hover.on and math.max(0, t.ElevatedTransparency - 0.15) or math.max(0.05, t.ElevatedTransparency)
                    end,
                },
                Parent = row,
            })
            Util.Corner("ElementRadius", button)
            local scale = Util.New("UIScale", { Scale = 1, Parent = button })
            local label = Util.Label({
                Text = def.Title or "Button",
                TextSize = 12,
                Weight = Enum.FontWeight.Medium,
                Size = UDim2.fromScale(1, 1),
                TextXAlignment = Enum.TextXAlignment.Center,
                Theme = {
                    TextColor3 = function(t) return (def.Style == "Primary" or def.Style == "Danger") and t.OnAccent or t.Text end,
                },
                Parent = button,
            })
            if def.Icon then
                local icon = Util.Icon(def.Icon, {
                    Size = UDim2.fromOffset(13, 13),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, -(label.TextBounds.X / 2) - 10, 0.5, 0),
                    Theme = { ImageColor3 = function(t) return (def.Style == "Primary" or def.Style == "Danger") and t.OnAccent or t.TextDim end },
                    Parent = button,
                })
                label.Size = UDim2.fromScale(1, 1)
                label.Position = UDim2.fromOffset(7, 0)
            end
            Util.Hover(button, function(on)
                hover.on = on
                Theme.Refresh(button, 0.12)
            end)
            Router.Attach(button, {
                Disabled = function() return def.Locked == true end,
                OnPress = function() Animation.Tween(scale, "Press", { Scale = 0.97 }) end,
                OnRelease = function() Animation.Tween(scale, "Press", { Scale = 1 }) end,
                OnClick = function() self:Press(index) end,
            })
        end
    end
    rebuild()
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Buttons" then rebuild() end
    end))
    return row
end

return ButtonRow
