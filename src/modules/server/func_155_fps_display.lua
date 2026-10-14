-- Func #155: FPS Display | toggle
local RunService = game:GetService("RunService")

local State = { running = false }

local function loop()
    while State.running do
        local dt = RunService.RenderStepped:Wait()
        task.wait(1)
        print("[Resonance] FPS: " .. math.floor(1 / dt))
    end
end

return {
    id = "FpsDisplay", type = "toggle", name = "FPS Display",
    tooltip = "Print FPS to the console", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end
}