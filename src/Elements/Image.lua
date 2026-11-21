local import = ...
local Base = import("Elements/Base")
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")

-- Image: a rounded picture row
local Image = Base.Class("Image")

function Image.new(container, def)
    local self = setmetatable({}, Image)
    Base.Init(self, container, def)
    return self
end
function Image:Save() return nil end
function Image:Load() end

function Image:Render(parent, mount)
    local def = self.Def
    local height = def.Height or 100
    local capacity = def.Caption and (height + 20) or height
    local holder = Util.New("Frame", {
        Size = UDim2.new(1, -6, 0, capacity),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local image = Util.New("ImageLabel", {
        Size = def.Caption and UDim2.new(1, 0, 0, height) or UDim2.fromScale(1, 1),
        Image = typeof(def.Image) == "number" and ("rbxassetid://" .. def.Image) or (def.Image or ""),
        ScaleType = def.ScaleType or Enum.ScaleType.Crop,
        Parent = holder,
    })
    Util.Corner(def.Radius or "ElementRadius", image)
    Util.Stroke(image, "Stroke", function(t) return 0.6 end)
    if def.AspectRatio then
        image.Size = UDim2.new(1, 0, 0, 0)
        image.SizeConstraint = Enum.SizeConstraint.RelativeXX
    end
    if def.Caption and def.Caption ~= "" then
        Util.Label({
            Text = def.Caption,
            TextSize = 11,
            Position = UDim2.fromOffset(2, height + 4),
            Size = UDim2.new(1, -4, 0, 14),
            Color = "TextMuted",
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = holder,
        })
    end
    return holder
end

return Image
