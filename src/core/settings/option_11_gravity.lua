return {
    id = "Gravity", type = "slider", name = "Gravity",
    section = "Physics", tab = "Movement",
    default = 196.2, range = {0, 500}, increment = 10, suffix = "",
    tooltip = "World gravity",
    onChanged = function(v, S)
        S.Gravity = v
        game:GetService("Workspace").Gravity = v
    end
}