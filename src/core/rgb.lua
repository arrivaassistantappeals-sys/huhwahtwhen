-- ============================================================
-- Resonance v4.0 — core/rgb.lua
-- Global RGB mode (rainbow for UI/objects)
-- ============================================================

local RunService = game:GetService("RunService")

local RGB = {}
RGB.hue = 0
RGB.speed = 0.5
RGB.targets = {}
RGB.running = false
RGB.conn = nil

local function step(dt)
    if not RGB.running then return end
    RGB.hue = (RGB.hue + dt * RGB.speed) % 1
    local color = Color3.fromHSV(RGB.hue, 1, 1)
    for obj, props in pairs(RGB.targets) do
        if typeof(obj) == "Instance" and obj.Parent then
            for _, prop in ipairs(props) do
                pcall(function() obj[prop] = color end)
            end
        else
            RGB.targets[obj] = nil
        end
    end
end

function RGB.start()
    if RGB.running then return end
    RGB.running = true
    RGB.conn = RunService.RenderStepped:Connect(step)
end

function RGB.stop()
    if not RGB.running then return end
    RGB.running = false
    if RGB.conn then RGB.conn:Disconnect(); RGB.conn = nil end
end

function RGB.register(obj, ...)
    local props = {...}
    if #props == 0 then props = {"Color"} end
    RGB.targets[obj] = props
end

function RGB.unregister(obj)
    RGB.targets[obj] = nil
end

function RGB.clear()
    RGB.targets = {}
end

function RGB.getColor()
    return Color3.fromHSV(RGB.hue, 1, 1)
end

function RGB.bind(Settings)
    task.spawn(function()
        while true do
            task.wait(0.5)
            if Settings.RGBMode then
                if not RGB.running then RGB.start() end
            else
                if RGB.running then RGB.stop() end
            end
        end
    end)
end

return RGB