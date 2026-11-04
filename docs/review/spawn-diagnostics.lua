-- Paste before: -- Register every saved control before loading settings.
MenuGroup:AddButton({Text="Spawn diagnostics",Func=function()
    local lines={}
    local function value(name)
        local object=Player:FindFirstChild(name)
        return object and tostring(object.Value) or "unavailable"
    end
    local menu=ReplicatedStorage:FindFirstChild("MenuToys")
    local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
    local source=Hub.sourceGucci
    local proof=Hub.gucciVerifiedRun
    table.insert(lines,"Spawn remote: "..tostring(menu and menu:FindFirstChild("SpawnToyRemoteFunction")~=nil or false))
    table.insert(lines,"CanSpawnToy: "..value("CanSpawnToy"))
    table.insert(lines,"Toy points: "..value("UsedToyPoints").." / "..value("ToysLimitCap"))
    table.insert(lines,"Own toy folder: "..(folder and tostring(#folder:GetChildren()).." models" or "missing"))
    table.insert(lines,"Gucci controller enabled: "..tostring(source and source.state.GucciAntiGrab or false))
    table.insert(lines,"Gucci verified for current character: "..tostring(proof and proof.Confirmed and proof.Char==Player.Character or false))
    table.insert(lines,"Defense spawn: "..(Hub.sourceSpawnStatus or "no attempt recorded"))
    if Hub.lastWorkerError then table.insert(lines,"Worker error: "..Hub.lastWorkerError:sub(1,180)) end
    if Hub.lastCallbackError then table.insert(lines,"Callback error: "..Hub.lastCallbackError:sub(1,180)) end
    local text=table.concat(lines,"\n")
    print("[Arriva spawn diagnostics]\n"..text)
    notify("Spawn diagnostics",text,12)
end})
