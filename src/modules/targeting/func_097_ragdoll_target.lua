-- Func #097: Ragdoll Target | button
local Players = game:GetService("Players")

return {
    id = "RagdollTarget", type = "button", name = "Ragdoll Target",
    tooltip = "Ragdoll the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        end
    end
}