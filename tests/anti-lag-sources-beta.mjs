import fs from 'node:fs';
import {LuauState} from 'luau-web';
const source=fs.readFileSync(new URL('../dist/Arriva Core Hub 2.5Beta.lua',import.meta.url),'utf8');
const chunk=(a,b)=>source.slice(source.indexOf(a),source.indexOf(b,source.indexOf(a)));
const coordinator=chunk('\t-- Automatic local mitigation;','\tAutoLagGroup:AddToggle("AutoLineAntiLag"');
const low=chunk('\t\t-- Low-FPS mitigation is a temporary source,','\n\t\t-- Supplied anti-invisibility');
const state=await LuauState.createAsync();
state.loadstring(source,'full beta',true);
console.log('PASS: full beta compiles');
const code=`
local time=0
local os={clock=function() return time end}
local function signal()
 local listeners={}
 return {Connect=function(_,fn) local c={live=true};function c:Disconnect() self.live=false end;table.insert(listeners,{fn=fn,c=c});return c end,
 Fire=function(_,...) for _,v in ipairs(listeners) do if v.c.live then v.fn(...) end end end}
end
local state={on=false}
local enables,restores,saves=0,0,0
local function enable() state.on=true;enables+=1 end
local function restore() state.on=false;restores+=1 end
local Hub={alive=true,cleanup=function() end,requestSave=function() saves+=1 end,connect=function(event,fn) return event:Connect(fn) end}
local Workspace={DescendantAdded=signal()}
local RunService={Heartbeat=signal()}
local originalRunService=RunService
local task={defer=function(fn) fn() end}
local isOwnBeam=function() return false end
local notify=function() end
local fn18=function() end
local controls={}
local defenseGroup={AddToggle=function(_,id,info) controls[id]=info.Callback end}
local settings={AddSlider=function(_,id,info) controls[id]=info.Callback end}
${coordinator}
${low}
local function tick(t,dt) time=t;RunService.Heartbeat:Fire(dt) end
controls.SourceLowFpsAntiLag(true)
tick(3,1);assert(not state.on,'single slow frame does not activate')
tick(4,1);assert(not state.on)
tick(5,1);assert(state.on and enables==1,'sustained low FPS activates')
local priorSaves=saves
tick(6,1);assert(enables==1 and saves==priorSaves,'automatic activation does not save/manual-toggle')
tick(7,0.01);tick(14,0.01);assert(state.on,'recovery grace period')
tick(15,0.01);assert(not state.on,'recovery releases automatic source')
Hub.setManualAntiLag(true);Hub.setAutoAntiLag('lowFps',true);Hub.setAutoAntiLag('lowFps',false)
assert(state.on,'manual preference survives automatic recovery')
Hub.setManualAntiLag(false);assert(not state.on)
Hub.setAutoAntiLag('other',true);Hub.setAutoAntiLag('lowFps',true);controls.SourceLowFpsAntiLag(false)
assert(state.on,'disabling low FPS leaves other automatic source active')
Hub.setAutoAntiLag('other',false);assert(not state.on)
startAuto()
local beam={Parent={},IsA=function() return true end}
for _=1,40 do Workspace.DescendantAdded:Fire(beam) end
assert(state.on,'line burst activates independent source')
Hub.setAutoAntiLag('lowFps',true);stopAuto();assert(state.on,'line disable does not clear low FPS')
Hub.setAutoAntiLag('lowFps',false);assert(not state.on)
return 'PASS: sustained FPS trigger, timed recovery, manual preservation, source overlap, line-source independence, no activation saves'
`;
console.log(await state.loadstring(code,'anti lag sources',true)());
state.destroy();
