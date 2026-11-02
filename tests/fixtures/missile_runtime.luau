local function resumeWorker()
    local worker=workers[#workers]
    local ok,err=coroutine.resume(worker)
    assert(ok,err)
end
local owned=false
local lastToy,lastPhysics
local spawned,exploded,ownerRequests=0,0,0
local distance=6
local slowReply=false
Hub.keybindGroups.missiles=group
Tabs.Explosions=Tabs.Misc
Hub.threads={}
Hub.nativeTask={cancel=function(worker) coroutine.close(worker) end}
task.spawn=function(callback)
    local worker=coroutine.create(callback)
    table.insert(workers,worker)
    return worker
end
Hub.lookAt=Hub.safeLookAt
Player.DistanceFromCharacter=function() return distance end
ownFolder=node(Player.Name.."SpawnedInToys")
named[ownFolder.Name]=ownFolder
ownFolder.children={};ownFolder.ChildAdded={}
local spawnRemote,ownerRemote,explodeRemote={},{},{}
local toyRemotes=node("MenuToys")
toyRemotes.FindFirstChild=function(_,key) if key=="SpawnToyRemoteFunction" then return spawnRemote end end
local grabRemotes=node("GrabEvents")
grabRemotes.FindFirstChild=function(_,key) if key=="SetNetworkOwner" then return ownerRemote end end
local bombRemotes=node("BombEvents")
bombRemotes.FindFirstChild=function(_,key) if key=="BombExplode" then return explodeRemote end end
ReplicatedStorage.FindFirstChild=function(_,key)
    if key=="MenuToys" then return toyRemotes elseif key=="GrabEvents" then return grabRemotes elseif key=="BombEvents" then return bombRemotes end
end
Hub.invoke=function(_,name)
    spawned+=1
    local hit=node("PartHitDetector",nil,"BasePart")
    local physics=node(name=="FireworkMissile" and "Hitbox" or "Body",nil,"BasePart")
    physics.AssemblyRootPart=physics
    local model=node(name,{hit,physics},"Model")
    model.DescendantAdded={};model.Parent=ownFolder;model.PrimaryPart=physics
    model.PivotTo=function(self,frame) self.lastPivot=frame end
    table.insert(ownFolder.children,model)
    lastToy,lastPhysics=model,physics
    emit(ownFolder.ChildAdded,model)
    if slowReply then coroutine.yield() end
    return model
end
Hub.fire=function(remote,data,position)
    if remote==explodeRemote then exploded+=1 elseif remote==ownerRemote then ownerRequests+=1 end
end
local CheckNetworkOwnerShipOnPart=function() return owned end

local oldDropdown=group.AddDropdown
function group:AddDropdown(id,info)
    local control=oldDropdown(self,id,info)
    function control:SetValues(values) self.Values=values end
    return control
end
local Options=controls
Hub.matchesKeybind=function(_,input,fallback) return input.KeyCode and input.KeyCode.Name==fallback end
UserInputService.InputEnded={};UserInputService.WindowFocusReleased={}
Players.PlayerAdded={}
Hub.queueRefresh=function(_,callback) callback() end
Hub.canHarm=function() return true end
named.SpawnLocation=node("SpawnLocation",nil,"BasePart")
local function step(seconds)
    advance(now+(seconds or 0.1))
    emit(RunService.Heartbeat,seconds or 0.1)
    for _,worker in ipairs(table.clone(workers)) do
        if coroutine.status(worker)~="dead" then local ok,err=coroutine.resume(worker);assert(ok,err) end
    end
end
local function runFor(seconds)
    local stopAt=now+seconds
    while now<stopAt do step() end
end
local function forceCount()
    local count=0
    for _,object in ipairs(created) do if (object.ClassName=="BodyVelocity" or object.ClassName=="BodyPosition") and not object.destroyed then count+=1 end end
    return count
end
