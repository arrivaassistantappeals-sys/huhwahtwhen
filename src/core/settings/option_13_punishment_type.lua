return {
    id = "PunishmentType", type = "dropdown", name = "Punishment Type",
    section = "Grab", tab = "Combat",
    default = "Insta-Kill",
    options = {"Insta-Kill","Void Teleport","Ragdoll","Orbit","Burn"},
    multiple = false,
    tooltip = "Punishment when grabbed",
    onChanged = function(opt, S) S.PunishmentType = opt[1] end
}