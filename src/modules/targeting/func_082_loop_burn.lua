-- Func #082: Loop Burn | toggle
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopBurn", type = "toggle", name = "Loop Burn",
    tooltip = "Repeatedly set the target on fire", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and not hrp:FindFirstChild("ResonanceFire") then
                        local f = Instance.new("Fire")
                        f.Name = "ResonanceFire"
                        f.Parent = hrp
                        Debris:AddItem(f, 1)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}