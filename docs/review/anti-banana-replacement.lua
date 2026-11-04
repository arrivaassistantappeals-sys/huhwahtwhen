-- The supplied Anti Banana intentionally breaks the local character's legs.
local bananaHip,bananaHum
local function restoreBanana()
    if bananaHum and bananaHum.Parent and bananaHip~=nil then bananaHum.HipHeight=bananaHip end
    bananaHip,bananaHum=nil,nil
end
add("SourceAntiBanana","Anti Banana","AntiBanana",0.03,function()
    local char,root,hum,alive=charAlive()
    if not alive then restoreBanana();return end
    local leg=char:FindFirstChild("Right Leg")
    if not leg or not tbl12.IsNetworkOwner(root) then return end
    if bananaHum~=hum then restoreBanana();bananaHum=hum;bananaHip=hum.HipHeight end
    local gucciWasOn=tbl8.GucciAntiGrab
    local ok,err=pcall(function()
        if gucciWasOn then tbl12.SetGucciAntiGrab(false);task.wait(0.25) end
    if not tbl8.AntiBanana or Player.Character~=char then return end
    hum.Sit=false;hum.HipHeight=2
    tbl12.BreakLimb(Player,"Legs")
    local deadline=os.clock()+0.75
    repeat
        if not tbl8.AntiBanana or not Hub.alive or Player.Character~=char or hum.Health<=0 or not leg.Parent then break end
        hum.HipHeight=2;task.wait()
    until os.clock()>=deadline
    end)
    local control=Toggles.AutoGucciBlobToggle
    if gucciWasOn and control and control.Value and not flag11 and Hub.alive and Player.Character==char then
        tbl12.SetGucciAntiGrab(true)
    end
    if not ok then error(err,0) end
end,restoreBanana)
defenseGroup:AddLabel("Anti Banana uses the source's leg-breaking method, respawn restores missing limbs.")

