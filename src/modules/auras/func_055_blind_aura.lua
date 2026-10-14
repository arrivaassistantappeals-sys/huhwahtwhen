-- Func #055: Blind Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "BlindAura", type = "toggle", name = "Blind Aura",
    tooltip = "Blind everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(1)
                if not Settings.BlindAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            pcall(function()
                                local sg = Instance.new("ScreenGui")
                                sg.Name = "ResonanceBlind"
                                sg.ResetOnSpawn = false
                                local f = Instance.new("Frame", sg)
                                f.Size = UDim2.fromScale(1, 1)
                                f.BackgroundColor3 = Color3.new(0, 0, 0)
                                sg.Parent = p.PlayerGui
                                Debris:AddItem(sg, 2)
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}