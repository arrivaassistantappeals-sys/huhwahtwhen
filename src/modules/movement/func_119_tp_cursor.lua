-- Func #119: Teleport to Cursor | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "TpCursor", type = "button", name = "Teleport to Cursor",
    tooltip = "Teleport to cursor", tab = "Movement",
    onClick = function(Settings, Utils)
        local mouse = LocalPlayer:GetMouse()
        if mouse and mouse.Hit then
            Utils.teleportTo(mouse.Hit + Vector3.new(0, 3, 0))
        end
    end
}