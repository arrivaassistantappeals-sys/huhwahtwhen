-- Paste once near the end of the hub, BEFORE its saved-settings load block.
-- Uses existing Hub/Library/Tabs/Player/Options/Toggles; not a standalone loader.
-- Physical protection only: this cannot prevent Roblox server/admin kicks.
do
(function()
    local Players=game:GetService("Players")
    local World=game:GetService("Workspace")
    local Storage=game:GetService("ReplicatedStorage")
    local Run=game:GetService("RunService")
    local me=Players.LocalPlayer
    local group=Tabs.Whitelist:AddRightGroupbox("Whitelist Assistance")
    local status=group:AddLabel("Assistance off. Uses your manually protected players and confirmed friends.")
    local summary=group:AddLabel("0 eligible players; 0 confirmed shuriken attachments.")
    local modes={grab=false,explosion=false,kick=false}
    local records={}
    local created={}
    local epoch=0
    local allowVisits=false
    local maskVisits=true
    local renderName="ArrivaWhitelistAssistVisit"
    local toyLimit=3
    local busy=false
    local spawnBusy=false
    local nextSpawn=0
    local ownVisit
    local disposed=false
    local function say(text) status:SetText(text) end
    local function enabled() return modes.grab or modes.explosion or modes.kick end
    local function trusted(person)
        if not person or person==me or person.Parent~=Players then return false end
        local manual=Hub.manualWhitelist or {}
        if manual[tostring(person.UserId)] or manual["name:"..person.Name:lower()] then return true end
        local friend=(Hub.friendCache or {})[person.UserId]
        return Hub.whitelistFriends and friend and friend.friend==true and not friend.failed
            and (friend.expires or 0)>os.clock() or false
    end
    local function character(person)
        local char=person.Character
        local root=char and (char:FindFirstChild("realHrp") or char:FindFirstChild("HumanoidRootPart"))
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local plot=person:FindFirstChild("InPlot")
        if not char or not root or not hum or hum.Health<=0 or (plot and plot.Value) then return end
        return char,root,hum
    end
    local function partOwner(part,char)
        local head=char and char:FindFirstChild("Head")
        local value=(head and head:FindFirstChild("PartOwner")) or part:FindFirstChild("PartOwner")
        return value and value.Value
    end
    local function owned(part,char,toy)
        local value=partOwner(part,char)
        if value==me.Name or value==me then return true end
        if toy and created[toy] and toy.Parent==World:FindFirstChild(me.Name.."SpawnedInToys") then
            local marker=toy:FindFirstChild("PartOwner",true)
            value=marker and marker.Value or value
        end
        return value==me.Name or value==me
    end
    local function ownFolder() return World:FindFirstChild(me.Name.."SpawnedInToys") end
    local function destroyToy(model)
        if not created[model] then return end
        local folder=ownFolder()
        if model.Parent and model.Parent==folder then
            local menu=Storage:FindFirstChild("MenuToys")
            local remote=menu and menu:FindFirstChild("DestroyToy")
            if remote then pcall(function() remote:FireServer(model) end) end
        end
        created[model]=nil
    end
    local function clearToy(record)
        if record.toy then destroyToy(record.toy);record.toy=nil end
        record.active=false;record.attachFailures=0;record.partsSince=nil
    end
    local function valid(record,ticket,kind)
        if disposed or not Hub.alive or epoch~=ticket or not modes[kind] or not trusted(record.player)
            or records[record.player.UserId]~=record then return false end
        local char,root=character(record.player)
        return char==record.char and root==record.root
    end
    local function readySelf()
        local char=me.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local held=me:FindFirstChild("IsHeld")
        if not root or not hum then return nil,"your character is still loading" end
        if hum.Health<=0 then return nil,"your character is dead; waiting for respawn" end
        if hum.SeatPart then return nil,"your character is seated (Gucci may be setting up)" end
        if root.Anchored then return nil,"your character root is anchored" end
        if held and held.Value then return nil,"your character is being held" end
        if Hub.safeZoneLoopActive then return nil,"safe-zone looping is active" end
        if Hub.characterFlightActive or Hub.blobFlightActive then return nil,"flight is active" end
        for _,run in pairs(Hub.targetLoopRuns or {}) do
            if run.enabled then return nil,"a player action loop is active" end
        end
        return root,char
    end
    local function finishVisit()
        local visit=ownVisit;ownVisit=nil
        if visit and visit.masked then
            Run:UnbindFromRenderStep(renderName)
            if visit.physics then visit.physics:Disconnect();Hub.connections[visit.physics]=nil end
        end
        if visit and me.Character==visit.char and readySelf()==visit.root
            and (visit.masked or (visit.root.Position-visit.destination).Magnitude<12) then
            visit.root.CFrame=visit.original;visit.root.AssemblyLinearVelocity=Vector3.zero
            if visit.head and visit.head.Parent==visit.char then visit.head.CFrame=visit.headFrame end
        end
        if visit and Hub.interactionVisitLock==visit then Hub.interactionVisitLock=nil end
    end
    local function acquire(part,record,ticket,kind,toy)
        if not valid(record,ticket,kind) then return false end
        if Hub.interactionVisitLock and Hub.interactionVisitLock~=ownVisit then say("Assistance waiting: another movement visit is running.");return false end
        local root,char=readySelf()
        if not root then say("Assistance waiting: your character is busy, held, seated or flying.");return false end
        if (root.Position-part.Position).Magnitude>30 then
            if not allowVisits then say("Distant assistance needs Allow brief assist visits enabled.");return false end
            local destination=part.Position+Vector3.new(0,3,6)
            if destination.Y<=World.FallenPartsDestroyHeight+8 then return false end
            ownVisit={root=root,char=char,original=root.CFrame,destination=destination}
            Hub.interactionVisitLock=ownVisit
            local visit=ownVisit
            visit.frame=CFrame.new(destination)*root.CFrame.Rotation
            visit.head=char:FindFirstChild("Head")
            visit.headFrame=visit.head and visit.head.CFrame
            if not visit.headFrame then visit.head=nil end
            visit.masked=maskVisits
            if visit.masked then
                local function live() return ownVisit==visit and Hub.alive and me.Character==char and root.Parent==char end
                -- Keep the local character at its saved display position before
                -- the camera renders, while the physics window uses the visit frame.
                Run:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value-1,function()
                    if not live() then return end
                    root.CFrame=visit.original
                    if visit.head and visit.head.Parent==char then visit.head.CFrame=visit.headFrame end
                end)
                visit.physics=Hub.connect(Run.Heartbeat,function()
                    if live() then root.CFrame=visit.frame end
                end)
            end
            root.CFrame=visit.frame
            root.AssemblyLinearVelocity=Vector3.zero
            task.wait(0.15)
        end
        local grab=Storage:FindFirstChild("GrabEvents")
        local remote=grab and grab:FindFirstChild("SetNetworkOwner")
        if not remote then return false end
        for _=1,4 do
            if not valid(record,ticket,kind) or not part.Parent or me.Character~=char or readySelf()~=root then return false end
            if ownVisit and not ownVisit.masked and (root.Position-ownVisit.destination).Magnitude>=12 then return false end
            if owned(part,not toy and record.char or nil,toy) then return true end
            -- Narrow defensive path: ONLY this current trusted player's root,
            -- or a sticky part inside this component's own newly spawned toy.
            local permitted=not toy and part==record.root
                or toy and created[toy] and toy.Parent==ownFolder() and part:IsDescendantOf(toy)
            local origin=ownVisit and ownVisit.masked and ownVisit.frame.Position or root.Position
            if not permitted or (origin-part.Position).Magnitude>30 then return false end
            if ownVisit and ownVisit.masked then root.CFrame=ownVisit.frame end
            local aim=Hub.safeLookAt(origin+Vector3.new(0,1.593,0),part.Position)
            if not aim then return false end
            if not toy then record.assistGrabRequested=true end
            remote:FireServer(part,aim)
            task.wait(0.15)
        end
        return valid(record,ticket,kind) and part.Parent and owned(part,not toy and record.char or nil,toy)
    end
    local function restorePosition(record,kind)
        if busy or record.restoring or os.clock()<(record.nextRestore or 0) or not record.saved then return end
        busy=true;record.restoring=true;record.nextRestore=os.clock()+2
        local ticket=epoch
        local destination=record.saved
        record.lockUntil=os.clock()+1
        task.spawn(function()
            local acquired=false
            local ok,err=pcall(function()
                acquired=acquire(record.root,record,ticket,kind)
                if not acquired then return end
                for _=1,3 do
                    if not valid(record,ticket,kind) or not owned(record.root,record.char) then return end
                    record.root.CFrame=destination
                    record.root.AssemblyLinearVelocity=Vector3.zero
                    record.root.AssemblyAngularVelocity=Vector3.zero
                    task.wait()
                end
                say("Restored @"..record.player.Name.." after "..kind.." signal.")
            end)
            -- Release only our own successful grab, including when toggled off.
            if record.assistGrabRequested and record.root.Parent and owned(record.root,record.char) then
                local events=Storage:FindFirstChild("GrabEvents")
                local remote=events and events:FindFirstChild("DestroyGrabLine")
                if remote then pcall(function() remote:FireServer(record.root) end) end
            end
            record.assistGrabRequested=nil
            finishVisit();busy=false;record.restoring=false;record.lockUntil=os.clock()+0.5
            if not ok then say("Assistance error: "..tostring(err):sub(1,140)) end
        end)
    end
    local function spawnShuriken(record)
        if spawnBusy then
            record.phase="Waiting for the current spawn request to finish."
            return
        end
        if busy then record.phase="Waiting for another assistance action to finish.";return end
        local root,reason=readySelf()
        if not root then record.phase="Waiting: "..reason..".";return end
        if os.clock()<nextSpawn then
            record.phase=string.format("Spawn cooldown: %.1fs remaining.",nextSpawn-os.clock())
            if record.spawnFailure then record.phase=record.phase.." Last attempt: "..record.spawnFailure end
            return
        end
        local count=0;for model in pairs(created) do if model.Parent then count+=1 else created[model]=nil end end
        if count>=toyLimit then record.phase="Shuriken limit reached; increase Maximum assistance shurikens.";return end
        local menu=Storage:FindFirstChild("MenuToys")
        local remote=menu and menu:FindFirstChild("SpawnToyRemoteFunction")
        local can=me:FindFirstChild("CanSpawnToy")
        if not remote then record.phase="MenuToys.SpawnToyRemoteFunction is missing.";return end
        if can and not can.Value then record.phase="Waiting for the game's CanSpawnToy permission.";return end
        local frame=root.CFrame*CFrame.new(0,4,0)
        local before={};local folder=ownFolder()
        if folder then for _,model in ipairs(folder:GetChildren()) do before[model]=true end end
        spawnBusy=true;nextSpawn=os.clock()+4
        record.phase="Spawn requested; waiting for returned toy or folder replication."
        record.spawnFailure=nil
        local ticket=epoch
        task.spawn(function()
            -- Finalize the busy flag even if model discovery fails after InvokeServer.
            local ok,err=pcall(function()
                local result=remote:InvokeServer("NinjaShuriken",frame,Vector3.new(0,97.69000244140625,0))
                local returnedModel=typeof(result)=="Instance" and result:IsA("Model")
                local deadline=os.clock()+2.5
                repeat
                    folder=ownFolder()
                    if returnedModel then
                        -- The returned Instance can arrive before its Parent replicates.
                        if folder and result.Parent==folder then break end
                    else
                        local candidates={}
                        for _,model in ipairs(folder and folder:GetChildren() or {}) do
                            if not before[model] and model:IsA("Model") and model.Name=="NinjaShuriken" then
                                table.insert(candidates,model)
                            end
                        end
                        if #candidates==1 then result=candidates[1];break end
                    end
                    if disposed or not Hub.alive or epoch~=ticket or os.clock()>=deadline then break end
                    task.wait(0.1)
                until false
                if folder and typeof(result)=="Instance" and result:IsA("Model") and result.Name=="NinjaShuriken" and result.Parent==folder and not before[result] then
                    created[result]=true
                    if valid(record,ticket,"kick") and not record.toy then
                        record.toy=result;record.partsSince=os.clock();record.phase="Toy spawned; waiting for sticky parts."
                    else destroyToy(result) end
                else
                    record.spawnFailure="no unique new NinjaShuriken identified in your toy folder."
                    record.phase="Spawn completed, but "..record.spawnFailure
                    say(record.phase);nextSpawn=os.clock()+8
                end
            end)
            spawnBusy=false
            if not ok then
                record.spawnFailure=tostring(err):sub(1,140)
                record.phase="Spawn/discovery failed: "..record.spawnFailure
                say(record.phase);nextSpawn=os.clock()+8
            end
        end)
    end
    local function maintainKick(record)
        if not modes.kick then clearToy(record);return end
        local hitbox=record.root:FindFirstChild("RagdollTouchedHitbox")
        if not hitbox then clearToy(record);record.phase="Waiting for current character hitbox.";return end
        local toy=record.toy
        if not toy or not toy.Parent then record.toy=nil;spawnShuriken(record);return end
        if not created[toy] or toy.Parent~=ownFolder() then record.toy=nil;return end
        local sticky=toy:FindFirstChild("StickyPart")
        local weld=sticky and sticky:FindFirstChild("StickyWeld")
        if not sticky or not weld then
            record.active=false
            record.partsSince=record.partsSince or os.clock()
            record.phase=not sticky and "Waiting for StickyPart replication." or "Waiting for StickyWeld replication."
            if os.clock()-record.partsSince>=3 then
                clearToy(record);nextSpawn=math.max(nextSpawn,os.clock()+4)
                record.phase="Sticky parts did not load; recycling managed toy."
            end
            return
        end
        record.partsSince=nil
        local attached=weld.Part1==hitbox and weld.Enabled~=false
        record.active=attached
        if attached then record.phase="Attached: current character weld confirmed.";return end
        local root,reason=readySelf()
        if not root then record.phase="Attachment waiting: "..reason..".";return end
        if busy then record.phase="Attachment waiting for another assistance action.";return end
        if os.clock()<(record.nextStick or 0) then return end
        record.nextStick=os.clock()+2;busy=true
        local ticket=epoch
        task.spawn(function()
            local requested=false
            local confirmed=false
            record.phase="Acquiring shuriken ownership."
            local ok,err=pcall(function()
                if not acquire(sticky,record,ticket,"kick",toy) then
                    if valid(record,ticket,"kick") then record.phase="Ownership not confirmed; check assistance status label for visit restrictions.";say("Whitelist anti-kick: waiting for verified ownership of the shuriken.") end
                    return
                end
                if not valid(record,ticket,"kick") then return end
                if not created[toy] or toy.Parent~=ownFolder() or not sticky:IsDescendantOf(toy) then return end
                local events=Storage:FindFirstChild("PlayerEvents")
                local remote=events and events:FindFirstChild("StickyPartEvent")
                if not remote then record.phase="PlayerEvents.StickyPartEvent missing.";return end
                if not hitbox:IsDescendantOf(record.char) then record.phase="Target hitbox changed; waiting for reconciliation.";return end
                -- Match the source: leave CanTouch/CanCollide alone before the
                -- request, and remove a replicated TouchInterest asynchronously.
                task.spawn(function()
                    local touch=sticky:WaitForChild("TouchInterest",2.5)
                    if touch and created[toy] and record.toy==toy and valid(record,ticket,"kick") then touch:Destroy() end
                end)
                record.phase="Ownership confirmed; waiting for server weld."
                -- Only our managed shuriken -> this trusted player's current hitbox.
                remote:FireServer(sticky,hitbox,CFrame.new(0,-0.3,0)*CFrame.Angles(math.pi/2,0,0))
                requested=true
                for _=1,8 do
                    if not valid(record,ticket,"kick") or record.toy~=toy or not toy.Parent or not weld.Parent then return end
                    if weld.Part1==hitbox and weld.Enabled~=false then confirmed=true;break end
                    task.wait(0.1)
                end
                if not confirmed and valid(record,ticket,"kick") and weld.Parent then confirmed=weld.Part1==hitbox and weld.Enabled~=false end
                record.active=confirmed
                if confirmed then
                    record.attachFailures=0
                    record.phase="Attached: current character weld confirmed."
                    say("Whitelist anti-kick: actual shuriken weld confirmed on @"..record.player.Name..".")
                end
            end)
            finishVisit();busy=false
            if requested and not confirmed and valid(record,ticket,"kick") then
                record.attachFailures=(record.attachFailures or 0)+1
                record.phase="Ownership confirmed; server weld not confirmed. Retrying."
                say("Whitelist anti-kick: ownership confirmed but server attachment not confirmed; retrying.")
                if record.attachFailures>=3 then
                    clearToy(record);nextSpawn=math.max(nextSpawn,os.clock()+4)
                    say("Whitelist anti-kick: repeated attachment failures; recycling only this helper's toy.")
                end
            end
            if not ok then record.phase="Attachment error: "..tostring(err):sub(1,140);say(record.phase) end
        end)
    end
    local function reconcile()
        for id,record in pairs(records) do
            local char,root=character(record.player)
            if not trusted(record.player) or char~=record.char or root~=record.root then clearToy(record);records[id]=nil end
        end
        if not enabled() then return end
        for _,person in ipairs(Players:GetPlayers()) do
            if trusted(person) then
                local char,root,hum=character(person)
                if char and not records[person.UserId] then records[person.UserId]={player=person,char=char,root=root,hum=hum,saved=root.CFrame} end
            end
        end
    end
    Hub.sampleWhitelistAssistance=function()
        if disposed or not Hub.alive then return end
        reconcile()
        local count,attachedCount=0,0
        for _,record in pairs(records) do
            count+=1
            local owner=partOwner(record.root,record.char)
            local held=owner and owner~="" and owner~=record.player.Name and owner~=record.player
            if modes.grab and held and not record.restoring and owner~=me.Name and owner~=me then
                restorePosition(record,"grab")
            elseif (modes.grab or modes.explosion) and not held and not record.restoring and os.clock()>=(record.lockUntil or 0) then
                record.saved=record.root.CFrame
            end
            maintainKick(record)
            if record.active then attachedCount+=1 end
        end
        summary:SetText(string.format("%d eligible players; %d confirmed shuriken attachments.",count,attachedCount))
        if count==0 and enabled() then say("No eligible protected players loaded outside plots. Pending friend checks are excluded.") end
    end
    Hub.connect(World.ChildAdded,function(part)
        if disposed or not modes.explosion or not part:IsA("BasePart") or part.Name~="Part" then return end
        for _,record in pairs(records) do
            if trusted(record.player) and (part.Position-record.root.Position).Magnitude<=20 then
                restorePosition(record,"explosion")
            end
        end
    end)
    local function changed(kind,on)
        modes[kind]=on;epoch+=1;finishVisit()
        if on then say("Assistance enabled; checking current protected players and ownership.") end
        if not modes.kick then for _,record in pairs(records) do clearToy(record) end end
        if not enabled() then for _,record in pairs(records) do clearToy(record) end;table.clear(records);say("Whitelist assistance off.") end
        Hub.requestSave()
    end
    group:AddToggle("WhitelistAssistGrab",{Text="Give whitelist anti-grab",Default=false,Callback=function(on) changed("grab",on) end})
    group:AddToggle("WhitelistAssistKick",{Text="Give whitelist physical anti-kick",Default=false,Callback=function(on) changed("kick",on) end})
    group:AddToggle("WhitelistAssistExplosion",{Text="Give whitelist anti-explosion",Default=false,Callback=function(on) changed("explosion",on) end})
    group:AddToggle("WhitelistAssistVisits",{Text="Allow brief assist visits for distant players",Default=false,Callback=function(on) allowVisits=on;if not on then epoch+=1;finishVisit() end end})
    group:AddToggle("WhitelistAssistMaskVisits",{Text="Mask assist visits locally",Default=true,Callback=function(on) maskVisits=on;epoch+=1;finishVisit() end})
    group:AddSlider("WhitelistAssistToyLimit",{Text="Maximum assistance shurikens",Default=3,Min=1,Max=10,Rounding=0,Callback=function(v) toyLimit=v end})
    group:AddLabel("Uses the existing whitelist. Skips dead/in-plot characters. Ownership and actual sticky welds must confirm; these are best-effort physical protections, not server-kick immunity.")
    group:AddButton({Text="Whitelist assistance status",Func=function()
        local tracked,active=0,0
        local details={}
        for _,record in pairs(records) do
            tracked+=1;if record.active then active+=1 end
            table.insert(details,"@"..record.player.Name..": "..(record.phase or "Waiting for assistance tick."))
        end
        table.sort(details)
        Library:Notify({Title="Whitelist assistance",Description=string.format("%d eligible players tracked; %d confirmed shuriken attachments. %s",tracked,active,allowVisits and "Distant visits enabled." or "Distant visits disabled.").."\n"..table.concat(details,"\n"),Time=10,Type="info"})
    end})
    local elapsed=0
    Hub.connect(Run.Heartbeat,function(dt) elapsed+=dt;if elapsed>=0.2 then elapsed=0;Hub.sampleWhitelistAssistance() end end)
    Hub.connect(Players.PlayerRemoving,function(person) local record=records[person.UserId];if record then clearToy(record);records[person.UserId]=nil end end)
    Hub.connect(me.CharacterRemoving,function()
        epoch+=1
        if ownVisit then
            if ownVisit.masked then Run:UnbindFromRenderStep(renderName);if ownVisit.physics then ownVisit.physics:Disconnect();Hub.connections[ownVisit.physics]=nil end end
            if Hub.interactionVisitLock==ownVisit then Hub.interactionVisitLock=nil end
        end
        ownVisit=nil
    end)
    Hub.cleanup(function()
        disposed=true;epoch+=1;finishVisit()
        for _,record in pairs(records) do clearToy(record) end
        for model in pairs(created) do destroyToy(model) end
        table.clear(records);Hub.sampleWhitelistAssistance=nil
    end)
end)()
end
