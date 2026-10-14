-- Func #101: Infinite Jump | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "InfiniteJump", type = "toggle", name = "Infinite Jump",
    tooltip = "Jump in midair", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceInfJumpConn = UserInputService.JumpRequest:Connect(function()
            if not Settings.InfiniteJump then return end
            local hum = Utils.getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end,
    onDisable = function()
        if _G.ResonanceInfJumpConn then
            _G.ResonanceInfJumpConn:Disconnect()
            _G.ResonanceInfJumpConn = nil
        end
    end
}