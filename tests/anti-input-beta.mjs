import fs from 'node:fs';
import {LuauState} from 'luau-web';
const source=fs.readFileSync(new URL('../dist/Arriva Core Hub 2.5Beta.lua',import.meta.url),'utf8');
const block=source.slice(source.indexOf('\t\t-- Resonance hold/drop flow'),source.indexOf('\t\tsettings:AddDropdown("SourceInputToy"'));
const state=await LuauState.createAsync();state.loadstring(source,'beta',true);console.log('PASS full script compilation');
const test=`
local now=0
local os={clock=function() return now end}
local Player={Character={}}
local char=Player.Character
local hum={Health=100}
local toy={Parent=true,Name='FoodHamburger'}
local waits,spawns,destroys,cancels,calls=0,0,0,0,0
local stall=true
local task={spawn=function(fn) local co=coroutine.create(fn);assert(coroutine.resume(co));return co end}
local Hub={nativeTask={cancel=function(co) cancels+=1;coroutine.close(co) end},invoke=function() calls+=1;if stall then coroutine.yield() end end,new=function() return {Parent=true,Destroy=function(self) self.Parent=nil end} end}
local grabEventsFolder={FindFirstChild=function() return nil end}
local tbl8={AntiInputLag=true}
local tbl9={}
local tbl12={Char=function() return char,{},hum end,SpawnToy=function() spawns+=1;toy.Parent=true;return toy end,DestroyToy=function(t) destroys+=1;t.Parent=nil end}
local function charAlive() return char,{},hum,true end
local action,cleanup
local function bind(_,_,_,fn,stop) action=fn;cleanup=stop end
local CFrame={new=function() return {} end}
local Vector3={zero={}}
local hold={WaitForChild=function() waits+=1;return {} end,FindFirstChild=function() return nil end}
function toy:WaitForChild(name,timeout) assert(name=='HoldPart' and timeout==2);waits+=1;return hold end
function toy:GetDescendants() return {} end
function char:FindFirstChild() return nil end
${block}
action();assert(waits==3 and calls==2 and spawns==1,'wait for replicated hold and drop components')
action();assert(calls==2,'bound pending calls')
now=2.1;action();assert(calls==4 and cancels==2,'timed out calls are retried')
tbl8.AntiInputLag=false;cleanup();assert(cancels==4 and destroys==1,'disable cancels calls and destroys toy')
tbl8.AntiInputLag=true;stall=false;action();assert(calls==6 and spawns==2,'re-enable not blocked')
action();assert(calls==8,'completed calls repeat')
-- Disabling during replication must prevent any subsequent remote calls.
cleanup();local before=calls
function toy:WaitForChild() tbl8.AntiInputLag=false;return hold end
action();assert(calls==before,'no calls after disable during loading')
return true
`;
await state.loadstring(test,'input regression',true)();console.log('PASS replication waits, pending-call timeout, disable, re-enable, repeated calls, disable during loading');state.destroy();
