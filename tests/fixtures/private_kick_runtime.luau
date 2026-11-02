-- Extends feature_pack_runtime.luau for the isolated private kick test panel.
Tabs.Blob=Tabs.Misc
local originalReady=Hub.loopTargetReady
Hub.loopTargetReady=function(person,char) return originalReady(person,char or (person and person.Character)) end
local oldDropdown=group.AddDropdown
function group:AddDropdown(id,info)
    local control=oldDropdown(self,id,info)
    function control:SetValues(values) self.Values=values end
    return control
end
Players.PlayerAdded={}
Hub.queueRefresh=function(_,callback) callback() end
Hub.threads={}
Hub.nativeTask={cancel=function(worker) coroutine.close(worker) end}
task.spawn=function(callback)
    local worker=coroutine.create(callback);table.insert(workers,worker);return worker
end
local function step(seconds)
    advance(now+(seconds or 0.1))
    for _,worker in ipairs(table.clone(workers)) do
        if coroutine.status(worker)~="dead" then local ok,err=coroutine.resume(worker);assert(ok,err) end
    end
end
local function runFor(seconds)
    local stopAt=now+seconds
    while now<stopAt do step() end
end
local frameMeta={}
local function frame(position) return setmetatable({Position=position},frameMeta) end
frameMeta.__mul=function(a,b) return frame(a.Position+b.Position) end
frameMeta.__index=function(self,key) if key=="Rotation" then return frame(Vector3.zero) end end
CFrame.new=function(x,y,z)
    if type(x)=="table" then return frame(x) end
    return frame(Vector3.new(x or 0,y or 0,z or 0))
end
root.CFrame=CFrame.new(root.Position)
local targetRoot=a.Character.HumanoidRootPart
local targetHum=a.Character:FindFirstChildOfClass("Humanoid")
local targetCharacter=a.Character
targetHum.RequiresNeck=true;targetHum.Parent=targetCharacter
targetRoot.CFrame=CFrame.new(targetRoot.Position)
targetRoot.AssemblyLinearVelocity=Vector3.zero;targetRoot.AssemblyAngularVelocity=Vector3.zero
targetRoot.CanCollide=true
targetRoot.IsA=function(_,kind) return kind=="BasePart" end
local attachment={Name="RootAttachment",Parent=targetRoot}
local rootWeld={Name="WeldHRP",Parent=targetRoot,Enabled=true}
targetRoot.FindFirstChild=function(_,name) if name=="RootAttachment" then return attachment elseif name=="WeldHRP" then return rootWeld end end
local motor={Parent=targetCharacter,Enabled=true,IsA=function(_,kind) return kind=="Motor6D" end}
targetCharacter.GetDescendants=function() return {targetRoot,motor} end
targetCharacter.Parent=Workspace
local isFriend,blockFriend=true,false
Player.IsFriendsWithAsync=function()
    while blockFriend do task.wait() end
    return isFriend
end
game.PrivateServerId="private-test"
local ownership=true
local CheckNetworkOwnerShipOnPart=function() return ownership end
Hub.lookAt=Hub.safeLookAt
local ownerRemote,dropLine={name="owner"},{name="dropLine"}
local grabRemote,dropRemote,releaseRemote={name="grab"},{name="drop"},{name="release"}
local grabFolder=node("GrabEvents")
grabFolder.FindFirstChild=function(_,name) if name=="SetNetworkOwner" then return ownerRemote elseif name=="DestroyGrabLine" then return dropLine end end
ReplicatedStorage.FindFirstChild=function(_,name) if name=="GrabEvents" then return grabFolder end end
ownFolder=node(Player.Name.."SpawnedInToys");named[ownFolder.Name]=ownFolder
local hand=node("RightWeld");hand.Enabled=true
local orientation=node("RightAlignOrientation");orientation.Enabled=true
local detector=node("RightDetector",{hand,orientation})
local blobScript=node("BlobmanSeatAndOwnerScript")
blobScript.FindFirstChild=function(_,name)
    if name=="CreatureGrab" then return grabRemote elseif name=="CreatureDrop" then return dropRemote elseif name=="CreatureRelease" then return releaseRemote end
end
local seat=node("VehicleSeat",nil,"VehicleSeat")
local blob=node("CreatureBlobman",{blobScript,detector,seat},"Model");blob.Parent=ownFolder
local seated=true
Hub.getLoopBlobSeat=function() return seated and seat or nil end
local sent={}
Hub.fire=function(remote,...) table.insert(sent,{remote=remote,args={...}}) end
local function select(method)
    controls.PrivateKickTestTarget:SetValue("A")
    controls.PrivateKickTestMethod:SetValue(method or "Grab-Drop")
    controls.PrivateKickTestDuration:SetValue(1)
end
local function noForces()
    for _,object in ipairs(created) do
        if object.ClassName=="BodyPosition" or object.ClassName=="BodyGyro" then assert(object.destroyed,"force leaked") end
    end
end
local function restored()
    noForces()
    assert(targetHum.RequiresNeck and targetRoot.CanCollide and motor.Enabled and rootWeld.Enabled)
    assert(hand.Enabled and orientation.Enabled and attachment.Parent==targetRoot)
end
