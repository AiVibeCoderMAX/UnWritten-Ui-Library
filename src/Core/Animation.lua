local import = ...
local Signal = import("Core/Signal")

-- every animation curve the library uses; call Animation.Tween(inst, time, goal, "Style")
local Animation = {}

Animation.Style = {
    Linear = Enum.EasingStyle.Linear,
    Sine = Enum.EasingStyle.Sine,
    Quad = Enum.EasingStyle.Quad,
    Cubic = Enum.EasingStyle.Cubic,
    Quart = Enum.EasingStyle.Quart,
    Quint = Enum.EasingStyle.Quint,
    Expo = Enum.EasingStyle.Expo,
    Circ = Enum.EasingStyle.Circ,
    Back = Enum.EasingStyle.Back,
    Elastic = Enum.EasingStyle.Elastic,
    Bounce = Enum.EasingStyle.Bounce,
}

Animation.Direction = {
    In = Enum.EasingDirection.In,
    Out = Enum.EasingDirection.Out,
    InOut = Enum.EasingDirection.InOut,
}

-- curves used by the UI, so the feel stays consistent
Animation.Curve = {
    Hover = { Time = 0.14, Style = "Quad", Direction = "Out" },
    Press = { Time = 0.1, Style = "Quad", Direction = "Out" },
    Toggle = { Time = 0.22, Style = "Quint", Direction = "Out" },
    Fold = { Time = 0.28, Style = "Quint", Direction = "Out" },
    Slide = { Time = 0.34, Style = "Quint", Direction = "Out" },
    Pop = { Time = 0.24, Style = "Back", Direction = "Out" },
    Fade = { Time = 0.2, Style = "Sine", Direction = "Out" },
    Pulse = { Time = 0.5, Style = "Sine", Direction = "InOut" },
    Bounce = { Time = 0.4, Style = "Bounce", Direction = "Out" },
}

function Animation.Resolve(curve)
    if type(curve) == "string" then return Animation.Curve[curve] or Animation.Curve.Fade end
    return curve or Animation.Curve.Fade
end

-- speed < 0 means instant; the theme sets AnimSpeed (0 turns every animation off)
Animation.Speed = 1

function Animation.Tween(inst, curve, goal)
    if not inst or not inst.Parent then return nil end
    local spec = Animation.Resolve(curve)
    local speed = Animation.Speed
    if speed <= 0 or spec.Time <= 0 then
        for key, value in goal do
            pcall(function() inst[key] = value end)
        end
        return nil
    end
    local tween = import("Core/Services").TweenService:Create(
        inst,
        TweenInfo.new(spec.Time / speed, Animation.Style[spec.Style], Animation.Direction[spec.Direction]),
        goal
    )
    tween:Play()
    return tween
end

-- pops an instance in: scale from small + fade, used on every view that mounts
function Animation.PopIn(inst, curve, fromScale)
    if not inst then return end
    local scale = inst:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Parent = inst
        scale.Scale = 0.96
        task.defer(function()
            if scale.Parent then Animation.Tween(scale, curve or "Pop", { Scale = 1 }) end
        end)
    end
    return scale
end

-- a soft pulse on an instance's BackgroundTransparency or ImageTransparency
function Animation.Flash(inst, property, onValue, base, curve)
    if not inst or not inst.Parent then return end
    property = property or "BackgroundTransparency"
    Animation.Tween(inst, curve or { Time = 0.08, Style = "Quad", Direction = "Out" }, { [property] = onValue })
    task.delay(0.12, function()
        if inst.Parent then Animation.Tween(inst, curve or "Fade", { [property] = base }) end
    end)
end

-- calls fn every `interval` seconds on Heartbeat; returns a connection
function Animation.Loop(interval, fn)
    local acc = 0
    return import("Core/Services").RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc >= interval then
            acc = 0
            local ok, err = pcall(fn)
            if not ok then warn("[UnWrittenUI] loop: " .. tostring(err)) end
        end
    end)
end

-- generic spring-ish number animator for sliders and switches that need per-frame values
function Animation.NewRunner()
    local runner = { Speed = 12, Value = nil, Target = nil, Connection = nil, Changed = Signal.new() }
    function runner:Kick(target)
        self.Target = target
        if not self.Connection then
            self.Connection = import("Core/Services").RunService.Heartbeat:Connect(function(dt)
                local speed = Animation.Speed
                if speed <= 0 then
                    self.Value = self.Target
                else
                    self.Value += (self.Target - self.Value) * math.min(dt * self.Speed * speed, 1)
                end
                self.Changed:Fire(self.Value)
                if math.abs(self.Target - self.Value) < 0.001 then
                    self.Value = self.Target
                    self.Connection:Disconnect()
                    self.Connection = nil
                end
            end)
        end
    end
    return runner
end

return Animation
