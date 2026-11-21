local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Code: a syntax-ish preview block with a copy button; a click expands the whole text into a dialog,
-- and an Editable block can be edited there.
local Code = Base.Class("Code")

function Code.new(container, def)
    local self = setmetatable({}, Code)
    Base.Init(self, container, def)
    self.Code = def.Code or def.Text or ""
    self.Lines = def.Lines or 6
    self.Editable = def.Editable == true
    return self
end

function Code:Set(text)
    self.Code = tostring(text)
    self.StateChanged:Fire("Code")
end
function Code:Get() return self.Code end
function Code:Save() return nil end
function Code:Load() end

function Code:Open()
    local window = self.Window
    if not self.Editable then
        -- read only: the whole text in a dialog, no input
        window:Dialog({
            Title = self.Title,
            Icon = "code",
            Content = self.Code,
            Width = 460,
            Buttons = {
                { Title = "Copy", Style = "Secondary", Callback = function()
                    if setclipboard then pcall(setclipboard, self.Code) end
                    window:Notify({ Title = "Copied", Content = "Code copied", Type = "Success", Duration = 1.5 })
                end },
                { Title = "Close", Style = "Primary" },
            },
        })
        return
    end
    window:Dialog({
        Title = self.Title,
        Icon = "code",
        Width = 460,
        Input = { Default = self.Code, Multiline = true, Height = 220 },
        Buttons = {
            { Title = "Copy", Style = "Secondary", Callback = function()
                if setclipboard then pcall(setclipboard, self.Code) end
                window:Notify({ Title = "Copied", Content = "Code copied to the clipboard", Type = "Success", Duration = 2 })
            end },
            { Title = "Save", Style = "Primary", Callback = function(text, dialog)
                self.Code = text or self.Code
                if self.Def.OnSave then
                    local ok, message = self.Def.OnSave(self.Code)
                    if ok == false then
                        dialog:SetError(message or "Could not save")
                        return false
                    end
                end
                self.StateChanged:Fire("Code")
            end },
        },
    })
end

function Code:Render(parent, mount)
    local row = Util.New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local text = self.Code
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do table.insert(lines, line) end
    if #lines > self.Lines then
        local shown = {}
        for index = 1, self.Lines do table.insert(shown, lines[index]) end
        text = table.concat(shown, "\n") .. "\n…"
    end
    local holder = Util.New("TextButton", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = "",
        Theme = { BackgroundColor3 = "Background", BackgroundTransparency = 0.3 },
        Parent = row,
    })
    Util.Corner("ElementRadius", holder)
    Util.Stroke(holder, "Divider", function(t) return 0.6 end)
    Util.Padding(holder, 8, 10, 8, 10)
    local label = Util.Label({
        Text = self.Title,
        TextSize = 10,
        Weight = Enum.FontWeight.SemiBold,
        Size = UDim2.new(1, -30, 0, 14),
        Color = "TextMuted",
        Parent = holder,
    })
    local codeLabel = Util.Label({
        Text = text,
        TextSize = 11,
        TextWrapped = false,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.Y,
        Color = "Text",
        Theme = { TextColor3 = "Text", FontFace = Theme.Font(Enum.FontWeight.Regular) },
        Parent = holder,
    })
    local copy = Util.New("TextButton", {
        Size = UDim2.fromOffset(22, 22),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, -2),
        Text = "",
        BackgroundTransparency = 1,
        Parent = holder,
    })
    Util.Icon("copy", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Color = "TextMuted", Parent = copy })
    Router.Attach(copy, {
        OnClick = function()
            if setclipboard then pcall(setclipboard, self.Code) end
            self.Window:Notify({ Title = "Copied", Content = "Code copied", Type = "Success", Duration = 1.5 })
            if self.Def.OnCopy then pcall(self.Def.OnCopy) end
        end,
        Tooltip = "Copy",
    })
    Router.Attach(holder, {
        OnClick = function() self:Open() end,
        Tooltip = self.Editable and "Click to edit" or "Click to open",
    })
    mount:Give(self.StateChanged:Connect(function(state)
        if state == "Code" then
            local text = self.Code
            local lines = {}
            for line in (text .. "\n"):gmatch("(.-)\n") do table.insert(lines, line) end
            if #lines > self.Lines then
                local shown = {}
                for index = 1, self.Lines do table.insert(shown, lines[index]) end
                text = table.concat(shown, "\n") .. "\n…"
            end
            codeLabel.Text = text
        end
    end))
    return row
end

return Code
