-- Func #003: Freeze Grab | toggle
local Workspace = game:GetService("Workspace")
local State = { running = false }

return {
    id = "FreezeGrab", type = "toggle", name = "Freeze Grab",
    tooltip = "Lock the held object in place", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local gp = Workspace:FindFirstChild("GrabParts")
                if gp then
                    for _, obj in pairs(gp:GetDescendants()) do
                        if obj:IsA("BasePart") then obj.Anchored = true end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        local gp = Workspace:FindFirstChild("GrabParts")
        if gp then
            for _, obj in pairs(gp:GetDescendants()) do
                if obj:IsA("BasePart") then obj.Anchored = false end
            end
        end
    end
}