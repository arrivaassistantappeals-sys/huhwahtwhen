return {
    id = "LoopDelay", type = "slider", name = "Loop Delay",
    section = "Performance", tab = "Main",
    default = 100, range = {10, 1000}, increment = 10, suffix = " ms",
    tooltip = "Delay between loops",
    onChanged = function(v, S) S.LoopDelay = v end
}