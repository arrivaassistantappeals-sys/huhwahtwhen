-- Func #181: Music Play | button
local Debris = game:GetService("Debris")

return {
    id = "MusicPlay", type = "button", name = "Music Play",
    tooltip = "Play music on the server", tab = "Trolling",
    onClick = function(Settings, Utils)
        local s = Instance.new("Sound", workspace)
        s.SoundId = "rbxassetid://1837879082"
        s.Volume = 3
        s:Play()
        Debris:AddItem(s, 30)
    end
}