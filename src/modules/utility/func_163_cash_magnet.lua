-- Func #163: Cash Magnet | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "CashMagnet", type = "toggle", name = "Cash Magnet",
    tooltip = "Attract cash to you", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local name = obj.Name:lower()
                        if name:find("cash") or name:find("money") or name:find("coin") then
                            pcall(function() obj.CFrame = hrp.CFrame end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}