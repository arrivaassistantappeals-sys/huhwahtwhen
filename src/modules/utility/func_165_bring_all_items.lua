-- Func #165: Bring All Items | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BringAllItems", type = "button", name = "Bring All Items",
    tooltip = "Bring all items to yourself", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored then
                local owner = Players:GetPlayerFromCharacter(obj.Parent)
                if not owner then
                    pcall(function()
                        obj.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), 2, math.random(-3,3))
                        count = count + 1
                    end)
                end
            end
        end
        Utils.notify("Resonance", "Collected: " .. count, Settings)
    end
}