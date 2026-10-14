-- Func #046: Attraction Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "AttractionAura", type = "toggle", name = "Attraction Aura",
    tooltip = "Attract all items to you",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                if not Settings.AttractionAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local owner = Players:GetPlayerFromCharacter(obj.Parent)
                        if not owner then
                            pcall(function()
                                obj.CFrame = myHRP.CFrame + Vector3.new(math.random(-3,3), 3, math.random(-3,3))
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}