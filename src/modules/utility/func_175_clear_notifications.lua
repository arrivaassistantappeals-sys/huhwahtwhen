-- Func #175: Clear Notifications | button
local StarterGui = game:GetService("StarterGui")

return {
    id = "ClearNotifications", type = "button", name = "Clear Notifications",
    tooltip = "Clear notifications", tab = "Utility",
    onClick = function(Settings, Utils)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "",
                Text = "",
                Duration = 0
            })
        end)
    end
}