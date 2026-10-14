-- Func #041: Fling Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

local State = { running = false }

return {
    id = "FlingAura", type = "toggle", name = "Fling Aura",
    tooltip = "Automatically fling everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                if not Settings.FlingAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bv.Velocity = Vector3.new(math.random(-500, 500), Settings.FlingPower or 400, math.random(-500, 500))
                            bv.Parent = hrp
                            Debris:AddItem(bv, 0.2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}