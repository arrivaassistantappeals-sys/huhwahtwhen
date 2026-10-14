-- Func #160: Show FPS | button
local RunService = game:GetService("RunService")

return {
    id = "ShowFps", type = "button", name = "Show FPS",
    tooltip = "Show current FPS", tab = "Server",
    onClick = function(Settings, Utils)
        local dt = RunService.RenderStepped:Wait()
        Utils.notify("FPS", math.floor(1 / dt) .. " fps", Settings)
    end
}