-- plot/slot utilities: coordinated self-only visits, requests and confirmation.
do
(function()
    local group=Tabs.Misc:AddLeftGroupbox("Plots & Slots")
    local slotOn,houseOn,claimOn=false,false,false
    local selectedPlot="Plot3"
    local nextSlot,nextHouse,nextClaim=0,0,0
    local active
    local slotAttempts=setmetatable({},{__mode="k"})
    local status=group:AddLabel("Plots & slots: idle. Distant interactions visit and return automatically.")
    local function selfRoot()
        local char=Player.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local held=Player:FindFirstChild("IsHeld")
        if not root or not hum or hum.Health<=0 or hum.SeatPart or root.Anchored
            or (held and held.Value) or Hub.safeZoneLoopActive or Hub.blobFlightActive or Hub.characterFlightActive then return end
        for _,run in pairs(Hub.targetLoopRuns or {}) do if run.enabled then return end end
        return root,char
    end
    local function ownerIsSelf(owner) return owner.Value==Player.Name or owner.Value==Player end
    local function plotInfo(plot)
        local sign=plot and plot:FindFirstChild("PlotSign")
        local front=sign and (sign:FindFirstChild("Sign") or sign)
        local plus=front and front:FindFirstChild("Plus")
        return sign,sign and sign:FindFirstChild("ThisPlotsOwners"),plus and plus:FindFirstChild("PlusGrabPart")
    end
    local function claimed(owners,part)
        for _,owner in ipairs(owners and owners:GetChildren() or {}) do if ownerIsSelf(owner) then return true end end
        local marker=part and part:FindFirstChild("AnchoredPartGrab")
        return marker and ownerIsSelf(marker) or false
    end
    local function finish(ticket)
        if active~=ticket then return end
        active=nil
        if Player.Character==ticket.char and ticket.root.Parent==ticket.char and selfRoot()==ticket.root
            and (ticket.root.Position-ticket.destination).Magnitude<12 then
            ticket.root.CFrame=ticket.original
            ticket.root.AssemblyLinearVelocity=Vector3.zero;ticket.root.AssemblyAngularVelocity=Vector3.zero
        end
    end
    local function visit(kind,part,allowed,action)
        if active then return false,"Another plot/slot interaction is running." end
        local root,char=selfRoot()
        if not root then return false,"Character busy: leave seats/holds and stop flight, safe-zone or action loops." end
        if not part or not part.Parent or not part:IsA("BasePart") then return false,"Interaction part has not loaded." end
        local destination=(root.Position-part.Position).Magnitude>25 and part.Position+Vector3.new(0,3,6) or root.Position
        if kind=="House renewal" then destination=part.Position+Vector3.new(0,3,0) end
        for _,value in ipairs({destination.X,destination.Y,destination.Z}) do
            if value~=value or math.abs(value)==math.huge then return false,"Invalid interaction position." end
        end
        if destination.Y<=Workspace.FallenPartsDestroyHeight+8 then return false,"Destination is below the safe map height." end
        local ticket={kind=kind,root=root,char=char,original=root.CFrame,destination=destination}
        active=ticket;status:SetText(kind..": visiting; will return when finished.")
        task.spawn(function()
            local function valid()
                return Hub.alive and active==ticket and allowed() and Player.Character==char
                    and selfRoot()==root and part.Parent and (root.Position-destination).Magnitude<12
            end
            local ok,err=pcall(function()
                if active~=ticket or not Hub.alive or not allowed() or selfRoot()~=root then return end
                root.CFrame=CFrame.new(destination)*root.CFrame.Rotation
                root.AssemblyLinearVelocity=Vector3.zero
                task.wait(0.2)
                if valid() then action(root,valid) end
            end)
            if active==ticket then finish(ticket) end
            if not ok then status:SetText(kind..": "..tostring(err):sub(1,160));warn("[Plots & slots] "..tostring(err)) end
        end)
        return true
    end
    local function request(part,root)
        local events=ReplicatedStorage:FindFirstChild("GrabEvents")
        local remote=events and events:FindFirstChild("SetNetworkOwner")
        if not remote then return false end
        local aim=Hub.safeLookAt(root.Position+Vector3.new(0,1.593,0),part.Position)
        if not aim then return false end
        Hub.fire(remote,part,aim)
        return true
    end
    local function claim(automatic)
        local plots=Workspace:FindFirstChild("Plots")
        local plot=plots and plots:FindFirstChild(selectedPlot)
        local _,owners,part=plotInfo(plot)
        if not owners or not part then return false,"Waiting for PlotSign.Sign.Plus.PlusGrabPart and plot owners to load." end
        if claimed(owners,part) then status:SetText("Plot: selected plot is already yours.");return true end
        if automatic and #owners:GetChildren()>0 then status:SetText("Plot: selected plot is occupied; waiting.");return false end
        return visit("Plot claim",part,function() return not automatic or claimOn end,function(root,valid)
            for _=1,12 do
                if not valid() then return end
                if claimed(owners,part) then status:SetText("Plot: ownership confirmed; returning.");return end
                if automatic and #owners:GetChildren()>0 then status:SetText("Plot: another player claimed it; returning.");return end
                if not request(part,root) then status:SetText("Plot: ownership remote unavailable; returning.");return end
                task.wait(0.2)
            end
            status:SetText(claimed(owners,part) and "Plot: ownership confirmed; returning." or "Plot: request sent but not confirmed; returned. Auto-claim will retry.")
        end)
    end
    local function timerOf(slot)
        local screen=slot:FindFirstChild("Screen")
        local gui=screen and screen:FindFirstChild("SlotGui")
        local frame=gui and gui:FindFirstChild("TimeLeftFrame")
        return frame and frame:FindFirstChild("TimeText")
    end
    local function slotState(slot,slots)
        local timer=timerOf(slot)
        if not timer then
            for _,other in ipairs(slots:GetChildren()) do local shared=timerOf(other);if shared then timer=shared;break end end
        end
        if timer then
            local text=tostring(timer.Text):gsub("%s","")
            if not text:match("^%d+:%d%d$") and not text:match("^%d+$") then return nil,timer end
            return text=="0:00" or text=="00:00" or text=="0",timer
        end
        local holder=slot:FindFirstChild("SlotHandle")
        local light=holder and holder:FindFirstChild("LightBall")
        if light then return light.Material==Enum.Material.Neon end
    end
    local function spin(automatic)
        if active then return false,"Another plot/slot interaction is running." end
        local root=selfRoot();if not root then return false,"Character busy: stop flight/loops and leave seats first." end
        local slots=Workspace:FindFirstChild("Slots");if not slots then return false,"Slot machines have not loaded." end
        local best,distance
        for _,slot in ipairs(slots:GetChildren()) do
            local holder=slot:FindFirstChild("SlotHandle")
            local handle=holder and holder:FindFirstChild("Handle")
            if slotState(slot,slots)==true and handle and handle:IsA("BasePart") and os.clock()-(slotAttempts[slot] or -math.huge)>=6 then
                local range=(root.Position-handle.Position).Magnitude
                if not distance or range<distance then best={slot=slot,handle=handle};distance=range end
            end
        end
        if not best then return false,"No ready slot machine yet; waiting for cooldown/loading." end
        slotAttempts[best.slot]=os.clock()
        return visit("Slot spin",best.handle,function() return not automatic or slotOn end,function(ownRoot,valid)
            for _=1,10 do
                if not valid() then return end
                local ready=best.slot.Parent and slotState(best.slot,slots)
                if ready==false then status:SetText("Slots: timer changed; spin accepted. Returning.");return end
                if not request(best.handle,ownRoot) then status:SetText("Slots: ownership remote unavailable; returning.");return end
                task.wait(0.2)
            end
            local ready=best.slot.Parent and slotState(best.slot,slots)
            status:SetText(ready==false and "Slots: timer changed; spin accepted. Returning." or "Slots: request not confirmed. Returned; will try another available machine.")
        end)
    end
    local function renewHouse()
        local plots=Workspace:FindFirstChild("Plots")
        for _,plot in ipairs(plots and plots:GetChildren() or {}) do
            local sign,owners=plotInfo(plot)
            for _,owner in ipairs(owners and owners:GetChildren() or {}) do
                local timer=owner:FindFirstChild("TimeRemainingNum")
                if ownerIsSelf(owner) and timer and type(timer.Value)=="number" and timer.Value<20 then
                    local house=plot:FindFirstChild("House") or (sign and sign:FindFirstChild("House"))
                    local destination=house and (house:IsA("BasePart") and house or house:FindFirstChildWhichIsA("BasePart",true))
                    destination=destination or plot:FindFirstChild("PlotArea")
                    if not destination then return false,"Owned house destination has not loaded." end
                    local original=timer.Value
                    return visit("House renewal",destination,function() return houseOn end,function(_,valid)
                        for _=1,40 do
                            if not valid() or not timer.Parent then return end
                            if timer.Value>=80 and timer.Value>original then status:SetText("House: time renewal confirmed; returning.");return end
                            task.wait(0.2)
                        end
                        status:SetText("House: renewal not confirmed; returned. Will retry.")
                    end)
                end
            end
        end
        return false
    end
    local function cancel(kind)
        if active and active.kind==kind then finish(active);status:SetText(kind..": cancelled.") end
    end
    group:AddDropdown("ToolPlot",{Text="Plot",Values={"Plot1","Plot2","Plot3","Plot4","Plot5"},Default=3,Callback=function(value) selectedPlot=value;cancel("Plot claim") end})
    group:AddButton({Text="Claim selected plot",Func=function() local ok,reason=claim(false);if not ok and reason then status:SetText(reason);notify("Plot",reason,5,"warning") end end})
    group:AddToggle("PackAutoClaimPlot",{Text="Auto-claim selected empty plot",Default=false,Callback=function(on) claimOn=on;nextClaim=0;if not on then cancel("Plot claim") end end})
    group:AddButton({Text="Spin an available slot now",Func=function() local ok,reason=spin(false);if not ok and reason then status:SetText(reason);notify("Slots",reason,5,"warning") end end})
    group:AddToggle("ToolAutoSpin",{Text="Auto slot spin (visit and return)",Default=false,Callback=function(on) slotOn=on;nextSlot=0;if not on then cancel("Slot spin") end end})
    group:AddToggle("ToolAutoSaveHouse",{Text="Auto renew owned house time",Default=false,Callback=function(on) houseOn=on;nextHouse=0;if not on then cancel("House renewal") end end})
    group:AddButton({Text="Cancel plot / slot visit",Func=function() if active then finish(active);status:SetText("Visit cancelled.") end end})
    group:AddLabel("No need to walk nearby. Visits require a loaded destination and a free character; seated/held/flying characters and action loops are left alone.")
    function Hub.sampleToolAutomation()
        if active then return end
        local now=os.clock()
        -- Renew an expiring owned house before trying to acquire another plot.
        if houseOn and now>=nextHouse then nextHouse=now+5;local ok,reason=renewHouse();if ok then return elseif reason then status:SetText(reason) end end
        if claimOn and now>=nextClaim then nextClaim=now+5;local ok,reason=claim(true);if active then return elseif not ok and reason then status:SetText(reason) end end
        if slotOn and now>=nextSlot then nextSlot=now+3;local ok,reason=spin(true);if not ok and reason then status:SetText(reason) end end
    end
    local elapsed=0
    Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed>=0.5 then elapsed=0;Hub.sampleToolAutomation() end end)
    Hub.connect(Player.CharacterRemoving,function() active=nil end)
    Hub.cleanup(function() slotOn=false;houseOn=false;claimOn=false;if active then finish(active) end;Hub.sampleToolAutomation=nil end)
end)();

(function()
    TargetGroup:AddButton({Text="Stop all action loops",Func=function()
        local ids={}
        for id in pairs(Toggles) do
            local key=tostring(id):lower()
            if (key:find("loop",1,true) and id~="AutoReseatBlobLoops") or key:find("aura",1,true)
                or id=="ToolAutoSpin" or id=="ToolAutoSaveHouse" or id=="PackCharacterFlight"
                or id=="PackAimAssist" or id=="PackAutoClaimPlot" then table.insert(ids,id) end
        end
        for _,id in ipairs(ids) do
            local toggle=Toggles[id]
            if toggle.Value then pcall(function() toggle:SetValue(false) end) end
        end
        for _,run in pairs(Hub.targetLoopRuns or {}) do run.enabled=false end
        if Hub.stopBlobFlight then Hub.stopBlobFlight() end
        notify("Loops","Action loops stopped. Protections remain enabled.",4)
    end})
end)()
end
