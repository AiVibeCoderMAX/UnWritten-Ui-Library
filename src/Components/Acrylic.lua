local import = ...
local Services = import("Core/Services")
local Util = import("Core/Util")

-- background blur with a BlurEffect in Lighting; on a quality level that hides it, the window
-- simply turns transparent instead of failing
local Acrylic = {
    On = false,
    Strength = 14,
}

local blur
local saved = {}

function Acrylic.Set(on, strength)
    if strength then Acrylic.Strength = strength end
    Acrylic.On = on and true or false
    if Acrylic.On then
        if not blur or not blur.Parent then
            blur = Instance.new("BlurEffect")
            blur.Name = "UnWrittenUIBlur"
            blur.Size = Acrylic.Strength
            blur.Parent = Services.Lighting
        end
        if blur then
            blur.Size = Acrylic.Strength
            blur.Enabled = true
        end
    else
        if blur then
            pcall(function() blur:Destroy() end)
            blur = nil
        end
    end
    return Acrylic.On
end

function Acrylic.Destroy()
    Acrylic.Set(false)
end

return Acrylic
