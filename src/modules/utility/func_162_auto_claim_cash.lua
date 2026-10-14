-- Func #162: Auto Claim Cash | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, claimed = 0 }

return {
    id = "AutoClaimCash", type = "toggle", name = "Auto Claim Cash",
    tooltip = "Automatically collect cash", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        local name = obj.Name:lower()
                        if name:find("cash") or name:find("money") or name:find("coin") then
                            pcall(function()
                                if firetouchinterest then
                                    firetouchinterest(hrp, obj, 0)
                                    firetouchinterest(hrp, obj, 1)
                                end
                                State.claimed = State.claimed + 1
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { claimed = State.claimed } end
}