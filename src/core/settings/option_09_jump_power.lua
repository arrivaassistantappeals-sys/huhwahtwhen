return {
    id = "JumpPower", type = "slider", name = "JumpPower",
    section = "Movement", tab = "Movement",
    default = 50, range = {50, 500}, increment = 1, suffix = " studs",
    tooltip = "Jump power",
    onChanged = function(v, S)
        S.JumpPower = v
        local p = game:GetService("Players").LocalPlayer
        local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if h then h.JumpPower = v end
    end
}