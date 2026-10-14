-- Func #047: Auto-Counter
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "AutoCounter", type = "toggle", name = "Auto-Counter",
    tooltip = "Fling back when someone tries to grab you",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.15)
                if not Settings.AutoCounter then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                if myHRP.Velocity.Magnitude > 80 then
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                            if hrp and (hrp.Position - myHRP.Position).Magnitude < 20 then
                                local bv = Instance.new("BodyVelocity")
                                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                bv.Velocity = Vector3.new(math.random(-500,500), Settings.FlingPower or 400, math.random(-500,500))
                                bv.Parent = hrp
                                Debris:AddItem(bv, 0.25)
                            end
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}