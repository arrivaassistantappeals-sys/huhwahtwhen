local now=0
local os={clock=function() return now end}
local workers={}
local task={spawn=function(callback)
    local worker=coroutine.create(callback);table.insert(workers,worker);return worker
end,wait=function() coroutine.yield() end}
local function step()
    now+=0.1
    for _,worker in ipairs(table.clone(workers)) do
        if coroutine.status(worker)~="dead" then local ok,err=coroutine.resume(worker);assert(ok,err) end
    end
end
local function runFor(seconds)
    local untilTime=now+seconds
    while now<untilTime do step() end
end
local Hub={alive=true,threads={},nativeTask={cancel=function(worker) coroutine.close(worker) end}}
local phases={}
Hub.reportGucciStatus=function(phase) table.insert(phases,phase) end
local function count(phase)
    local n=0;for _,value in ipairs(phases) do if value==phase then n+=1 end end;return n
end
local flag11=false
local tbl8={GucciAntiGrab=true}
local isHeld={Value=false}
local owned=true
local tbl12={IsNetworkOwner=function() return owned end}
local Player={}
local function record()
    local char={}
    local ragdoll={Value=false}
    local hum={Parent=char,Health=100,Sit=false,FindFirstChild=function(_,name) return name=="Ragdolled" and ragdoll or nil end}
    local vehicle={Parent={}}
    local weld={Enabled=false}
    local seat={Parent=vehicle,FindFirstChild=function(_,name) return name=="SeatWeld" and weld or nil end,
        IsDescendantOf=function(_,model) return model==vehicle end}
    local root={Parent=vehicle}
    local hrp={Parent=char}
    return {Char=char,Hum=hum,HRP=hrp,Vehicle=vehicle,Seat=seat,Root=root,BP={Parent=root},Type="CreatureBlobman",
        Ragdoll=false,testWeld=weld,testRagdoll=ragdoll}
end
local tbl16=record()
Player.Character=tbl16.Char
local valid=true
local function current() return valid and Player.Character==tbl16.Char end
