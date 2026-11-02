local warnings={}
local function warn(message) table.insert(warnings,tostring(message)) end
-- Deterministic client/file mocks; tests execute the bundle's actual settings code.
local now=0
local os={clock=function() return now end,date=function() return "12:00:00" end}
local jobs,cancelled={},{}
local task={}
local function schedule(at,callback)
    local thread=coroutine.create(callback)
    table.insert(jobs,{at=at,thread=thread})
    return thread
end
function task.defer(callback) return schedule(now,callback) end
function task.spawn(callback) return schedule(now,callback) end
function task.delay(seconds,callback) return schedule(now+seconds,callback) end
function task.wait(seconds) return coroutine.yield(seconds or 0.001) end
local function advance(target)
    for _=1,20000 do
        table.sort(jobs,function(a,b) return a.at<b.at end)
        local job=jobs[1]
        if not job or job.at>target then now=target;return end
        table.remove(jobs,1);now=job.at
        if not cancelled[job.thread] then
            local ok,delay=coroutine.resume(job.thread);assert(ok,delay)
            if coroutine.status(job.thread)~="dead" then
                table.insert(jobs,{at=now+math.max(delay or 0,0.001),thread=job.thread})
            end
        end
    end
    error("Scheduler did not settle")
end
local Hub={alive=true,ready=false,storage=true,threads={},manualWhitelist={},whitelistFriends=false}
Hub.nativeTask={cancel=function(thread) cancelled[thread]=true end}
local function clone(value)
    if type(value)~="table" then return value end
    local result={};for key,item in pairs(value) do result[key]=clone(item) end;return result
end
local documents={}
local http={}
function http:JSONEncode(value)
    local token=Hub.canonical(value)
    documents[token]=clone(value)
    return token
end
function http:JSONDecode(token)
    assert(documents[token],"Invalid JSON")
    return clone(documents[token])
end
local game={GetService=function(_,name) assert(name=="HttpService");return http end}
local files,folders,writes={},{},0
local failWrite=false
local function isfile(path) return files[path]~=nil end
local function readfile(path) assert(files[path],"Missing file");return files[path] end
local function writefile(path,content)
    assert(not failWrite,"Disk write failed")
    files[path]=content;writes+=1
end
local function isfolder(path) return folders[path]==true end
local function makefolder(path) folders[path]=true end
local Library={controls={},Options={},Toggles={}}
local SaveManager={ignored={},folder="ArrivaCoreHub/RayfieldConfigs"}
Hub.library=Library;Hub.saveManager=SaveManager
local Group={}
function Group:ensureSection() end
local tab={}
local function handle(info,value,key)
    local object={CurrentValue=value,CurrentKeybind=key}
    function object:Set(nextValue)
        assert(not self.fail,"UI rejected value")
        self.CurrentValue=nextValue
        if key then self.CurrentKeybind=nextValue end
        info.Callback(nextValue)
    end
    function object:Refresh(values) self.Options=values end
    return object
end
function tab:CreateToggle(info) return handle(info,info.CurrentValue) end
function tab:CreateSlider(info) return handle(info,info.CurrentValue) end
function tab:CreateDropdown(info) return handle(info,info.CurrentOption) end
function tab:CreateInput(info) return handle(info,info.CurrentValue) end
function tab:CreateKeybind(info) return handle(info,nil,info.CurrentKeybind) end
function tab:CreateButton(info) return info end
function tab:CreateLabel(text) return {Set=function() end} end
local group=setmetatable({tab=tab},{__index=Group})
local manualOn=false
Hub.setManualAntiLag=function(on) manualOn=on end
local function newControls()
    Library.controls={};Library.Options={};Library.Toggles={}
    group:AddToggle("AntiLagToggle",{Default=false,Callback=function(on) Hub.setManualAntiLag(on) end})
    group:AddSlider("StartupFeatureDelay",{Default=3,Min=0,Max=10,Callback=function() end})
    group:AddSlider("Speed",{Default=10,Min=1,Max=100,Callback=function() end})
    group:AddDropdown("Mode",{Values={"A","B"},Default=1,Callback=function() end})
    group:AddInput("Asset",{Default="",Callback=function() end})
    group:AddKeyPicker("Key",{Default="J",Callback=function() error("Restoring a key must not execute its action") end})
end
