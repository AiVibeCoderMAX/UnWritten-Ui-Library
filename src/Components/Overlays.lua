local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Layer = import("Components/Layer")
local Widgets = import("Components/Widgets")
local Maid = import("Core/Maid")

-- keybind list and watermark: small always-on overlays owned by the window
local Overlays = {}
Overlays.__index = Overlays

function Overlays.new(window)
    local self = setmetatable({
        Window = window,
        Maid = Maid.new(),
        Visible = true,
    }, Overlays)
    return self
end

-- keybind list: every bound key of the window, grouped, sorted, with a panel around it
function Overlays:SetKeybindList(on)
    self.KeybindListOn = on and true or false
    local window = self.Window
    if on then
        if not self.Binds then
            local panel = window:Panel({
                Title = "Keybinds",
                Icon = "keyboard",
                Id = "keybinds",
                Size = Vector2.new(230, 200),
                Hud = true,
                Closable = false,
                Collapsible = true,
                Resizable = false,
            })
            local holder = Util.New("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = panel.Body,
            })
            local list = Util.List(holder, 3)
            self.Binds = { Panel = panel, List = list, Holder = holder }
            self:RefreshBinds()
            panel:Show()
        else
            self.Binds.Panel:Show()
        end
    elseif self.Binds then
        self.Binds.Panel:Hide()
        self.Binds = nil
    end
    window.Interface.KeybindList = self.KeybindListOn
    window:SaveState()
end

function Overlays:RefreshBinds()
    local binds = self.Binds
    if not binds then return end
    for _, child in binds.Holder:GetChildren() do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    local rows = {}
    for _, owner in self.Window._binds do
        if owner.Binding and owner.Binding.Key then
            table.insert(rows, owner)
        end
    end
    if #rows == 0 then
        Util.Label({
            Text = "No binds yet.\nClick a key pill on a card.",
            TextSize = 11,
            TextWrapped = true,
            Size = UDim2.new(1, 0, 0, 34),
            Color = "TextMuted",
            Parent = binds.Holder,
        })
        return
    end
    table.sort(rows, function(a, b)
        local ta = a.BindInfo and select(1, a:BindInfo()) or tostring(a.Title)
        local tb = b.BindInfo and select(1, b:BindInfo()) or tostring(b.Title)
        return tostring(ta):lower() < tostring(tb):lower()
    end)
    for index = #rows, 1, -1 do
        local item = rows[index]
        local key = item.Binding.Key
        local row = Util.New("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            LayoutOrder = index,
            Parent = binds.Holder,
        })
        local title = item.BindInfo and select(1, item:BindInfo()) or item.Title
        Util.Label({
            Text = tostring(title),
            TextSize = 11,
            Size = UDim2.new(1, -80, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Color = item.Enabled and "Text" or "TextDim",
            Parent = row,
        })
        local mode = item.Binding.Mode
        Util.Label({
            Text = mode == "Always" and "" or mode,
            TextSize = 9,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -52, 0.5, 0),
            Size = UDim2.new(0, 34, 0, 12),
            TextXAlignment = Enum.TextXAlignment.Right,
            Color = mode == "Hold" and "Warning" or "TextMuted",
            Parent = row,
        })
        Util.Label({
            Text = Util.KeyLabel(key),
            TextSize = 10,
            Weight = Enum.FontWeight.Medium,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 48, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
            Color = item.Enabled and "Accent" or "TextMuted",
            Parent = row,
        })
    end
end

-- watermark: "Title · custom text · fps · ping · time"
function Overlays:SetWatermark(on)
    self.WatermarkOn = on and true or false
    if on and not self.WatermarkFrame then
        local frame = Util.New("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 12),
            Size = UDim2.new(0, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.X,
            Parent = Layer.Hud,
        })
        Util.List(frame, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
        local order = 0
        local function part(size, color, weight)
            order += 1
            return Util.Label({
                Text = "",
                TextSize = size,
                Weight = weight or Enum.FontWeight.Medium,
                Size = UDim2.fromScale(0, 1),
                AutomaticSize = Enum.AutomaticSize.X,
                LayoutOrder = order,
                Color = color or "Text",
                Theme = {
                    TextColor3 = color or "Text",
                    TextStrokeTransparency = 0.4,
                    TextStrokeColor3 = Color3.new(0, 0, 0),
                },
                Parent = frame,
            })
        end
        self.WatermarkFrame = frame
        self.WatermarkTitle = part(12, "Accent", Enum.FontWeight.Bold)
        self.WatermarkText = part(11, "TextDim")
        self.WatermarkFps = part(11, "TextMuted")
        self.WatermarkPing = part(11, "TextMuted")
        self.WatermarkTime = part(11, "TextMuted")
        self.WatermarkTitle.Text = self.Window.Def.Title or "UnWrittenUI"
        -- a real frame counter
        local count, acc = 0, 0
        self.WatermarkConnection = Services.RunService.RenderStepped:Connect(function(dt)
            count += 1
            acc += dt
            if acc >= 0.5 then
                self.WatermarkFps.Text = string.format("%d fps", math.floor(count / acc + 0.5))
                count, acc = 0, 0
            end
        end)
        self.WatermarkTimeConnection = Animation.Loop(0.5, function()
            self.WatermarkTime.Text = os.date("%H:%M:%S")
            local player = Services.Players.LocalPlayer
            if player and player.GetNetworkPing then
                self.WatermarkPing.Text = string.format("%d ms", math.floor(player:GetNetworkPing() * 1000 + 0.5))
            end
        end)
        self.Window.Maid:Give(self.WatermarkConnection)
        self.Window.Maid:Give(self.WatermarkTimeConnection)
    end
    if self.WatermarkFrame then
        self.WatermarkFrame.Visible = self.WatermarkOn
        if on then self:SetWatermarkText(self.Window.Interface.Watermark) end
    end
end

function Overlays:SetWatermarkText(text)
    if not self.WatermarkText then return end
    if type(text) == "string" and text ~= "" then
        self.WatermarkText.Text = "· " .. text
        self.WatermarkText.Visible = true
    else
        self.WatermarkText.Visible = false
    end
end

function Overlays:SetVisible(visible)
    if self.Binds then
        if visible then self.Binds.Panel:Show() else self.Binds.Panel:Hide() end
    end
end

function Overlays:Destroy()
    self.Maid:Clean()
end

return Overlays
