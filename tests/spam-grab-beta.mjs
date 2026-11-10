import fs from 'node:fs';import {LuauState} from 'luau-web';
const source=fs.readFileSync(new URL('../dist/Arriva Core Hub 2.5Beta.lua',import.meta.url),'utf8');
const block=source.slice(source.indexOf('TargetGroup:AddToggle("LoopKickToggle",'),source.indexOf('-- Loop Kill selected players'));
const state=await LuauState.createAsync();state.loadstring(source,'full beta',true);
await state.loadstring(`
local clock=0
local function tick() return clock end
local vm={__mul=function(a,b) return setmetatable({value=a.value+b.value},getmetatable(a)) end}
local function cf(n) return setmetatable({value=n},vm) end
local CFrame={new=function(_,n) return cf(n or 0) end}
local Vector3={zero={}}
local myRoot={Parent=true,CFrame=cf(10)}
local myChar={FindFirstChild=function() return myRoot end};myRoot.Parent=myChar
local Player={Character=myChar}
local tHum={Health=100,PlatformStand=false,Sit=false}
local tRoot={Parent=true,CFrame=cf(100),Position={},ReceiveAge=1,Anchored=false}
local tChar={FindFirstChild=function(_,name) return name=='Humanoid' and tHum or tRoot end};tHum.Parent=tChar
local target={Character=tChar};local SelectedPlayer=target
local selected=target
local remotes={SetNetworkOwner={},CreateGrabLine={},DestroyGrabLine={}}
local events={WaitForChild=function(_,n) return remotes[n] end,FindFirstChild=function(_,n) return remotes[n] end}
local ReplicatedStorage={WaitForChild=function() return events end,FindFirstChild=function() return events end}
local heartbeat={Wait=function() coroutine.yield() end}
local game={GetService=function() return {Heartbeat=heartbeat} end}
local callback,thread,run
local TargetGroup={AddToggle=function(_,_,info) callback=info.Callback end}
local releases=0
local Hub={canHarm=function() return true end,canAffect=function() return true end,teleportFrame=function(root) return root.CFrame end,teleportPart=function(root,frame) root.CFrame=frame end,fire=function(remote) if remote==remotes.DestroyGrabLine then releases+=1 end end,nextLoopTarget=function() return selected end}
Hub.beginTargetLoop=function(_,on)
 if run then for _,fn in ipairs(run.cleanups) do fn() end;run.enabled=false;if thread and coroutine.status(thread)~='dead' then coroutine.close(thread) end end
 local current={enabled=on,cleanups={}};run=current
 return function() return current.enabled end,function() return run==current end,function(fn) table.insert(current.cleanups,fn) end,function(co) thread=co end
end
local task={spawn=function(fn) local co=coroutine.create(fn);assert(coroutine.resume(co));return co end,wait=function() coroutine.yield() end}
local function step(t) clock=t;local ok,err=coroutine.resume(thread);assert(ok,tostring(err)) end
${block}
callback(true)
step(1);step(2);assert(myRoot.CFrame.value==100,'timer alone must not drag')
tRoot.ReceiveAge=0;step(2.1);step(2.2);assert(myRoot.CFrame.value==10 and tRoot.CFrame.value==27,'local signal allows drag phase')
tRoot.ReceiveAge=1;step(2.3);assert(myRoot.CFrame.value==27,'ownership loss returns to acquisition')
selected=nil;step(2.4);assert(not tHum.PlatformStand and not tHum.Sit and releases>0,'deselection restores target and releases line')
selected=target;step(2.5);assert(tHum.PlatformStand,'new attempt changes target state')
callback(false);assert(not tHum.PlatformStand and not tHum.Sit and myRoot.CFrame.value==10,'disable restores target and local position')
callback(true);local replacementHum={Health=100,PlatformStand=false,Sit=true};local replacementChar={FindFirstChild=function(_,n) return n=='Humanoid' and replacementHum or tRoot end};replacementHum.Parent=replacementChar
target.Character=replacementChar;step(3);assert(not tHum.PlatformStand,'target respawn releases old humanoid')
callback(false);assert(not replacementHum.PlatformStand and replacementHum.Sit,'preserve original true Sit')
return true
`,'spam grab lifecycle',true)();console.log('PASS full compilation and Spam Grab timer, ownership-loss, deselection, disable, respawn and state restoration checks');state.destroy();
