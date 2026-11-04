    local spawnBusy=false
    local spawnInvocation
    local nextSpawnAttempt=0
    local replicatedSpawns={}
    local function spawnStatus(text) Hub.sourceSpawnStatus=text end
    local function replicated(invocation)
        local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
        if not folder then return end
        local result=invocation.result
        if typeof(result)=="Instance" and result:IsA("Model") and result.Name==invocation.name
            and result.Parent==folder and not invocation.before[result] then return result end
        local candidate,count=nil,0
        for _,model in ipairs(folder:GetChildren()) do
            if not invocation.before[model] and model:IsA("Model") and model.Name==invocation.name then candidate=model;count+=1 end
        end
        if count==1 then return candidate end
    end
    local function releaseReplicated(invocation)
        -- A unique new model confirms this request produced a toy, even if
        -- the RemoteFunction response itself is delayed indefinitely.
        if spawnInvocation==invocation then spawnInvocation=nil end
        local worker=invocation.worker
        local native=Hub.nativeTask or task
        if worker and worker~=coroutine.running() and coroutine.status(worker)~="dead" and type(native.cancel)=="function" then
            pcall(native.cancel,worker)
            if Hub.threads then Hub.threads[worker]=nil end
        end
        nextSpawnAttempt=math.max(nextSpawnAttempt,os.clock()+0.5)
    end
    local function sourceSpawnImpl(name,frame,timeout)
        local char,root,hum=tbl12.Char()
        if flag11 or not root or not hum or hum.Health<=0 then spawnStatus("Waiting for a living character.");return end
        local menu=ReplicatedStorage:FindFirstChild("MenuToys")
        local remote=menu and menu:FindFirstChild("SpawnToyRemoteFunction")
        if not remote then spawnStatus("MenuToys.SpawnToyRemoteFunction is missing.");return end
        local allowed=Player:FindFirstChild("CanSpawnToy")
        if allowed and not allowed.Value then spawnStatus("The game's CanSpawnToy flag is false.");return end
        frame=frame or root.CFrame*CFrame.new(0,5,0)
        local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
        local before={};if folder then for _,model in ipairs(folder:GetChildren()) do before[model]=true end end
        local invocation={started=os.clock(),name=name,before=before,char=char}
        spawnInvocation=invocation
        spawnStatus("Requested "..name.."; waiting for replication.")
        invocation.worker=task.spawn(function()
            invocation.ok,invocation.result=pcall(function()
                return Hub.invoke(remote,name,frame,Vector3.new(0,97.69000244140625,0))
            end)
            invocation.done=true
            if spawnInvocation==invocation then spawnInvocation=nil end
        end)
        -- Bound model discovery, independently of InvokeServer returning.
        local deadline=os.clock()+math.clamp(tonumber(timeout) or 2,1,5)
        repeat
            if flag11 or not Hub.alive or Player.Character~=char then spawnStatus("Spawn cancelled after character/unload change.");return end
            local result=replicated(invocation)
            if result then
                spawned[result]=true;releaseReplicated(invocation)
                spawnStatus(name.." replicated.");return result
            end
            if invocation.done and not invocation.ok then spawnStatus("Spawn request failed: "..tostring(invocation.result):sub(1,140));return end
            task.wait()
        until os.clock()>=deadline
        spawnStatus(invocation.done and "Spawn returned, but no unique new toy replicated." or "Server spawn response still pending; further defense spawns wait to avoid duplicate requests.")
    end
    tbl12.SpawnToy=function(...)
        if spawnBusy then return nil end
        if spawnInvocation then
            local invocation=spawnInvocation
            local toy=replicated(invocation)
            if toy then
                releaseReplicated(invocation)
                if Player.Character==invocation.char then
                    spawned[toy]=true
                    replicatedSpawns[invocation.name]={toy=toy,char=invocation.char}
                end
            end
        end
        local ready=replicatedSpawns[(...)]
        if ready then
            replicatedSpawns[(...)]=nil
            if Player.Character==ready.char and ready.toy.Parent==Workspace:FindFirstChild(Player.Name.."SpawnedInToys") then
                spawnStatus((...).." recovered from delayed replication.");return ready.toy
            end
        end
        if spawnInvocation then
            spawnStatus(string.format("Waiting for pending %s server response (%.1fs).",spawnInvocation.name,os.clock()-spawnInvocation.started))
            return nil
        end
        if os.clock()<nextSpawnAttempt then return nil end
        spawnBusy=true
        local args=table.pack(...)
        local ok,result=xpcall(function() return sourceSpawnImpl(table.unpack(args,1,args.n)) end,debug.traceback)
        spawnBusy=false
        if not result or not ok then nextSpawnAttempt=os.clock()+0.5 end
        if not ok then spawnStatus("Spawn helper error: "..tostring(result):sub(1,140));warn("[Source defense spawn] "..tostring(result));return nil end
        return result
    end
