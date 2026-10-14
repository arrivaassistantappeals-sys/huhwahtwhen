-- Func #164: Item Magnet | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ItemMagnet", type = "toggle", name = "Item Magnet",
    tooltip = "Attract all items", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local owner = Players:GetPlayerFromCharacter(obj.Parent)
                        if not owner then
                            pcall(function()
                                obj.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), 3, math.random(-3,3))
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}