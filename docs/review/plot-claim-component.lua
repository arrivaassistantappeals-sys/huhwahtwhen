-- Standalone plot-claim component. Does not load or modify the hub automatically.
-- Usage: local controller = install({Hub=Hub, Player=Player,
-- Workspace=Workspace, ReplicatedStorage=ReplicatedStorage,
-- selfRoot=selfRoot, status=function(message) ... end})
-- selfRoot must return the local root and character only when movement is safe.
-- controller:Claim("Plot3", true) claims an empty selected plot, visiting if needed.
return function(context)
    local Hub,Player=context.Hub,context.Player
    local world,storage=context.Workspace,context.ReplicatedStorage
    assert(Hub and Player and world and storage and context.selfRoot,"Missing plot-claim context")
    local report=context.status or function() end
    local current
    local controller={}
    local function finish(ticket)
        if current~=ticket then return end
        current=nil
        if Player.Character==ticket.character and ticket.root.Parent==ticket.character
            and context.selfRoot()==ticket.root
            and (ticket.root.Position-ticket.destination).Magnitude<10 then
            ticket.root.CFrame=ticket.original
            ticket.root.AssemblyLinearVelocity=Vector3.zero
        end
    end
    function controller:Cancel()
        if current then finish(current) end
    end
    function controller:Claim(plotName,onlyEmpty)
        if current then return false,"A plot claim is already running" end
        local root,character=context.selfRoot()
        if not root then return false,"Character is busy or not ready" end
        local plots=world:FindFirstChild("Plots")
        local plot=plots and plots:FindFirstChild(plotName)
        local sign=plot and plot:FindFirstChild("PlotSign")
        local owners=sign and sign:FindFirstChild("ThisPlotsOwners")
        local plus=sign and sign:FindFirstChild("Plus")
        local part=plus and plus:FindFirstChild("PlusGrabPart")
        local events=storage:FindFirstChild("GrabEvents")
        local remote=events and events:FindFirstChild("SetNetworkOwner")
        if not owners or not part or not part:IsA("BasePart") or not remote then return false,"Plot sign or ownership remote unavailable" end
        if onlyEmpty and #owners:GetChildren()>0 then return false,"Plot is occupied" end
        local distant=(root.Position-part.Position).Magnitude>30
        local destination=distant and part.Position+Vector3.new(0,3,6) or root.Position
        for _,value in ipairs({destination.X,destination.Y,destination.Z}) do
            if value~=value or math.abs(value)==math.huge then return false,"Invalid sign position" end
        end
        if destination.Y<=world.FallenPartsDestroyHeight+8 then return false,"Sign destination is below the safe map height" end
        local ticket={root=root,character=character,original=root.CFrame,destination=destination}
        current=ticket
        task.spawn(function()
            local ok,message=pcall(function()
                if current~=ticket then return end
                if distant then
                    root.CFrame=CFrame.new(destination)*root.CFrame.Rotation
                    root.AssemblyLinearVelocity=Vector3.zero
                    report("Visiting selected sign; will return afterward")
                    task.wait(0.15)
                end
                for _=1,10 do
                    if current~=ticket or not Hub.alive or Player.Character~=character
                        or context.selfRoot()~=root or not part.Parent or not owners.Parent
                        or (root.Position-destination).Magnitude>10 then return end
                    for _,owner in ipairs(owners:GetChildren()) do
                        if owner.Value==Player.Name or owner.Value==Player then report("Plot ownership confirmed");return end
                    end
                    if onlyEmpty and #owners:GetChildren()>0 then report("Another player claimed the plot");return end
                    if (root.Position-part.Position).Magnitude>30 then return end
                    local aim=Hub.safeLookAt(root.Position+Vector3.new(0,1.593,0),part.Position)
                    if aim then Hub.fire(remote,part,aim) end
                    task.wait(0.2)
                end
                report("No ownership confirmation yet; returned after bounded retries")
            end)
            finish(ticket)
            if not ok then report("Plot claim error: "..tostring(message)) end
        end)
        return true
    end
    Hub.connect(Player.CharacterRemoving,function() current=nil end)
    Hub.cleanup(function() controller:Cancel() end)
    return controller
end
