-- Func #145: Copy JobID | button
return {
    id = "CopyJobId", type = "button", name = "Copy JobID",
    tooltip = "Copy the server JobID", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            setclipboard(game.JobId)
            Utils.notify("Resonance", "JobID copied", Settings)
        end
    end
}