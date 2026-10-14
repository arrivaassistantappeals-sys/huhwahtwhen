-- Func #114: Teleport to Spawn | button
local Workspace = game:GetService("Workspace")

return {
    id = "TpSpawn", type = "button", name = "Teleport to Spawn",
    tooltip = "Teleport to spawn", tab = "Movement",
    onClick = function(Settings, Utils)
        local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
        if not sp then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("SpawnLocation") then sp = obj; break end
            end
        end
        if sp then Utils.teleportTo(sp.CFrame + Vector3.new(0, 5, 0)) end
    end
}