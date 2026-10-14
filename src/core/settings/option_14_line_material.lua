return {
    id = "LineMaterial", type = "dropdown", name = "Line Material",
    section = "Grab", tab = "Combat",
    default = "Neon",
    options = {"Neon","Forcefield","Glass","Invisible"},
    multiple = false,
    tooltip = "Grab beam material",
    onChanged = function(opt, S) S.LineMaterial = opt[1] end
}