-- Func #050: Spin Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "SpinAura", type = "toggle", name = "Spin Aura",
    tooltip = "Spin everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.SpinAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local av = Instance.new("BodyAngularVelocity")
                            av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                            av.AngularVelocity = Vector3.new(0, (Settings.SpinRPM or 60) / 60 * math.pi * 2, 0)
                            av.Parent = hrp
                            Debris:AddItem(av, 2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}