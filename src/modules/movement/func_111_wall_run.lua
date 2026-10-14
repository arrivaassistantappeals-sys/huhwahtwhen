-- Func #111: Wall Run | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "WallRun", type = "toggle", name = "Wall Run",
    tooltip = "Wall running", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial == Enum.Material.Air then
                    hum.WalkSpeed = 80
                elseif hum.FloorMaterial ~= Enum.Material.Air then
                    hum.WalkSpeed = Settings.WalkSpeed or 16
                end
            end
        end)
    end,
    onDisable = function(Settings, Utils)
        State.running = false
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}