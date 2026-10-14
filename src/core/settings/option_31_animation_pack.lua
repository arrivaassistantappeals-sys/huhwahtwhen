return {
    id = "AnimPack", type = "dropdown", name = "Animation Pack",
    section = "Animations", tab = "Animations",
    default = "Default",
    options = {"Default","Cartoony","Ninja","Mage","Toy","Superhero","Pirate","Zombie","Robot","Rthro"},
    multiple = false,
    tooltip = "Character animation pack",
    onChanged = function(opt, S) S.AnimPack = opt[1] end
}