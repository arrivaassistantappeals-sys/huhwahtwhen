-- Func #116: Teleport Forward | button
local Workspace = game:GetService("Workspace")
local Camera    = Workspace.CurrentCamera

return {
    id = "TpForward", type = "button", name = "Teleport Forward",
    tooltip = "Teleport forward 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Camera.CFrame.LookVector * 50) end
    end
}