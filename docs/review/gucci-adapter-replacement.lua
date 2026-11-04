-- Private adapter for the supplied Gucci state machine.
do
	(function()
		local localPlayer=Player
		local originalRunService=RunService
		local sourceConnections={}
		local RunService=setmetatable({},{__index=function(_,key)
			local event=originalRunService[key]
			if key=="Heartbeat" or key=="RenderStepped" or key=="Stepped" then
				return setmetatable({Connect=function(_,callback)
					local character=Player.Character
					local native,connection
					local function disconnect()
						if native then native:Disconnect();Hub.connections[native]=nil end
						if connection then sourceConnections[connection]=nil end
					end
					native=Hub.connect(event,function(...)
						if not Hub.alive or Player.Character~=character then disconnect();return end
						callback(...)
					end)
					connection=setmetatable({Disconnect=disconnect},{__index=function(_,property) return native[property] end})
					sourceConnections[connection]=true;return connection
				end,Wait=function() return event:Wait() end},{__index=event})
			end
			return event
		end})
		local Instance=setmetatable({new=function(class,parent) return Hub.new(class,parent) end},{__index=Instance})
		local flag11=false
		local tbl7={ToyAuraReserved={}}
		local tbl8={GucciAntiGrab=false}
		local tbl9={GucciType="CreatureBlobman",RagdollInRG=false}
		local tbl11={}
		local tbl12={}
		local toggles={GucciAntiGrab={SetValue=function(_,v) if Toggles.AutoGucciBlobToggle then Toggles.AutoGucciBlobToggle:SetValue(v) end end}}
		local train=setmetatable({},{__index=function(_,method)
			if method=="FindFirstChild" then return function(_,name)
					local map=Workspace:FindFirstChild("Map")
					local folder=(map and map:FindFirstChild("AlwaysHereTweenedObjects")) or Workspace:FindFirstChild("AlwaysHereTweenedObjects")
					local current=folder and folder:FindFirstChild("Train")
					return current and current:FindFirstChild(name)
				end end
		end})
		local isHeld=setmetatable({},{__index=function(_,key)
			if key=="Value" then local state=Player:FindFirstChild("IsHeld");return state and state.Value or false end
		end})
		local function fn18(message,title) notify(title or "Gucci",message,5) end
		local function fn20(duration) return task.wait(duration) end
		tbl11.RagdollRemote={FireServer=function(_,...) if ragdollRemoteEvent then Hub.fire(ragdollRemoteEvent,...) end end}
		tbl12.Char=function(who)
			who=who or Player
			local char=who.Character
			return char,char and (char:FindFirstChild("realHrp") or char:FindFirstChild("HumanoidRootPart")),char and char:FindFirstChildOfClass("Humanoid")
		end
		tbl12.Teleport=function(part,frame) if part and part.Parent then part.CFrame=frame;part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero;return true end end
		tbl12.IsNetworkOwner=function(part)
			if not part or not part:IsA("BasePart") then return false end
			local root=part.AssemblyRootPart or part
			return not root.Anchored and root.ReceiveAge==0
		end
		tbl12.FindNicePart=function(model)
			if not model then return end
			local fallback
			for _,part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") and part.CanQuery and not part.Anchored and part.Name~="Button" then
					fallback=fallback or part
					if (part.AssemblyRootPart or part)==part then return part end
				end
			end
			return fallback
		end
		local spawned={}
		tbl12.DestroyToy=function(model)
			if not model or not model.Parent then return end
			local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			if not folder or model.Parent~=folder or not spawned[model] then return end
			local menu=ReplicatedStorage:FindFirstChild("MenuToys")
			local remote=menu and menu:FindFirstChild("DestroyToy")
			if remote then Hub.fire(remote,model) end
			spawned[model]=nil
		end
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
		tbl12.SNO=function(part)
			if flag11 or not part or not part.Parent or not setNetworkOwnerEvent then return false end
			local char,root,hum=tbl12.Char()
			if not root or not hum or hum.Health<=0 then return false end
			local saved=root.CFrame
			local moved=(root.Position-part.Position).Magnitude>=30
			if moved then root.CFrame=part.CFrame;task.wait() end
			local basis=Hub.lookAt(root.Position,part.Position)
			if basis then Hub.fire(setNetworkOwnerEvent,part,basis) end
			local deadline=os.clock()+0.75
			repeat
				if flag11 or Player.Character~=char or not part.Parent then break end
				if tbl12.IsNetworkOwner(part) then break end
				task.wait()
			until os.clock()>=deadline
			if moved and root.Parent and Player.Character==char then root.CFrame=saved;root.AssemblyLinearVelocity=Vector3.zero end
			return part.Parent and tbl12.IsNetworkOwner(part) or false
		end
		tbl12.Grab=function(part)
			local _,root,hum=tbl12.Char()
			if not part or not part.Parent or not root or not hum or hum.Health<=0 then return end
			local from=(root.CFrame*CFrame.new(0,1.593,0)).Position
			local basis=Hub.lookAt(from,part.Position)
			if basis then Hub.fire(setNetworkOwnerEvent,part,basis) end
		end
		tbl12.RNO=function(part) if part and part.Parent then Hub.fire(destroyGrabLineEvent,part) end end
		tbl12.Ragdoll=function(char)
			if char~=Player.Character then return false end
			local root=char:FindFirstChild("HumanoidRootPart")
			if root then tbl11.RagdollRemote:FireServer(root,0.35);return true end
			return false
		end
		local obj=setmetatable({},{__mode="k"})
		local obj2=setmetatable({},{__mode="k"})
		local runtimeConnections={}
		tbl12.SetRuntimeConnection=function(key,event,on,callback)
			if runtimeConnections[key] then runtimeConnections[key]:Disconnect();runtimeConnections[key]=nil end
			if on and event then runtimeConnections[key]=Hub.connect(event,callback) end
		end
		tbl12.GetInventory=function(who)
			local folder=Workspace:FindFirstChild(who.Name.."SpawnedInToys")
			local plots=Workspace:FindFirstChild("Plots")
			local items=Workspace:FindFirstChild("PlotItems")
			local plotFolder
			if plots and items then for _,plot in ipairs(plots:GetChildren()) do
					local sign=plot:FindFirstChild("PlotSign");local owners=sign and sign:FindFirstChild("ThisPlotsOwners")
					if owners then for _,owner in ipairs(owners:GetChildren()) do if owner:IsA("StringValue") and owner.Value==who.Name then plotFolder=items:FindFirstChild(plot.Name) end end end
				end end
			return folder,plotFolder
		end
		tbl12.RemoveGucci = function(arg)
			local v22, v23, v24 = tbl12.Char()
			local v25, v26, v27 = tbl12.Char(arg)
			local v28, v29 = tbl12.GetInventory(arg)
			local gucciAntiGrab = tbl8.GucciAntiGrab

			if not gucciAntiGrab then
				gucciAntiGrab = not (v24 and v24.Health > 0 and v23 and v28)
			end

			if gucciAntiGrab then
				return false
			end

			local function fn21(arg2)
				if not (arg2 and arg2.Parent) or obj2[arg2] then
					return
				end

				if obj[arg2] then
					return
				end

				if (arg2:IsA("VehicleSeat") or arg2:IsA("Seat")) and not arg2.Occupant then
					obj2[arg2] = true

					if tbl8.RagdollInRG and v26 then
						tbl12.SNO(v26, 1.5)
					end

					if v24.Sit then
						v24.Sit = false
						task.wait(0.1)
					end

					local now3 = tick()
					local flag12 = false
					local flag13 = false

					tbl12.SetRuntimeConnection(arg2, v22.ChildAdded, true, function(arg3)
						if arg3:IsA("LocalScript") and arg3.Name:lower():find("control") then
							arg3.Enabled = false
							arg3:Destroy()
							flag13 = true
						end
					end)

					local connection = arg2.ChildAdded:Connect(function(child)
						if child.Name == "SeatWeld" then
							child.Enabled = false
							child:Destroy()
							flag12 = true
						end
					end)

					while true do
						arg2:Sit(v24)
						fn20()
						if not (flag12 or tick() - now3 > 0.5 or not arg2.Parent or v24.Health <= 0 or flag11) then
							continue
						end
						break
					end

					v24.Sit = false

					if flag12 then
						local now4 = tick()

						while not flag13 and not flag11 and v22.Parent and v24.Health > 0 and tick() - now4 < 0.5 do
							task.wait()
						end
					end

					tbl12.SetRuntimeConnection(arg2, nil, false)
					obj2[arg2] = nil

					if not flag12 then
						v24.Sit = true
						task.wait(0.05)
						v24.Sit = false
						return connection:Disconnect()
					end

					obj[arg2] = true
					connection:Disconnect()

					connection = arg2.ChildAdded:Connect(function(child)
						local v30
						v30, v30 = tbl12.Char()

						if child.Name == "SeatWeld" and child.Part1 ~= v30 then
							obj[arg2] = nil
							connection:Disconnect()
						end
					end)
				end
			end

			local seatPart = v27 and v27.SeatPart
			if seatPart and not v27.Sit then
				obj[seatPart] = nil
				return fn21(seatPart)
			end

			for _, v30 in v28:GetChildren() do
				if v30:IsA("Model") then
					local vehicleSeat = v30:FindFirstChildWhichIsA("VehicleSeat") or v30:FindFirstChildWhichIsA("Seat")

					if vehicleSeat then
						fn21(vehicleSeat)
					end
				end
			end

			if v29 then
				for _, v30 in v29:GetChildren() do
					if v30:IsA("Model") then
						local vehicleSeat = v30:FindFirstChildWhichIsA("VehicleSeat") or v30:FindFirstChildWhichIsA("Seat")

						if vehicleSeat then
							fn21(vehicleSeat)
						end
					end
				end
			end
		end
		do
			local tbl16 = nil
			local flag12 = nil

			-- GUCCI CONFIRMATION BEGIN
			local function clearGucciConfirmation(record,announce)
				if not record then return end
				record.ConfirmEpoch=(record.ConfirmEpoch or 0)+1
				record.Confirmed=false
				if Hub.gucciVerifiedRun==record then Hub.gucciVerifiedRun=nil end
				local worker=record.ConfirmWorker;record.ConfirmWorker=nil
				if worker and coroutine.status(worker)~="dead" and worker~=coroutine.running() then
					pcall(Hub.nativeTask.cancel,worker);Hub.threads[worker]=nil
				end
				if announce and Hub.alive and not flag11 and tbl8.GucciAntiGrab and tbl16==record
					and Hub.reportGucciStatus then Hub.reportGucciStatus("Retrying") end
			end
			local function beginGucciConfirmation(record,isValid,weldObserved)
				clearGucciConfirmation(record,false)
				if not weldObserved then return end
				local ticket=record.ConfirmEpoch
				if Hub.reportGucciStatus then Hub.reportGucciStatus("Verifying") end
				record.ConfirmWorker=task.spawn(function()
					local stableSince
					while Hub.alive and not flag11 and tbl8.GucciAntiGrab and tbl16==record
						and record.ConfirmEpoch==ticket do
						local checked,valid=pcall(isValid)
						if not checked or not valid then clearGucciConfirmation(record,true);return end
						local hum,hrp=record.Hum,record.HRP
						local seat,vehicle=record.Seat,record.Vehicle
						local ragdolled=hum and hum:FindFirstChild("Ragdolled")
						local weld=seat and seat:FindFirstChild("SeatWeld")
						local ready=Player.Character==record.Char and hum and hum.Parent==record.Char
							and hum.Health>0 and hrp and hrp.Parent==record.Char
							and vehicle and vehicle.Parent and seat and seat.Parent and seat:IsDescendantOf(vehicle)
							and not hum.Sit and hum.SeatPart==nil and not record.Ragdoll
							and ragdolled and not ragdolled.Value and not isHeld.Value
							and (not seat.Occupant or seat.Occupant==hum)
							and (not weld or not weld.Enabled)
						if ready and record.Type~="Train" then
							local root=record.Root
							local ok,owned=false,false
							if root and root.Parent and type(tbl12.IsNetworkOwner)=="function" then ok,owned=pcall(tbl12.IsNetworkOwner,root) end
							ready=ok and owned and record.BP and record.BP.Parent==root
						end
						if ready then
							stableSince=stableSince or os.clock()
							if not record.Confirmed and os.clock()-stableSince>=1 then
								record.Confirmed=true
								Hub.gucciVerifiedRun=record
								if Hub.reportGucciStatus then Hub.reportGucciStatus("Active") end
							end
						else
							stableSince=nil
							if record.Confirmed then
								record.Confirmed=false
								if Hub.gucciVerifiedRun==record then Hub.gucciVerifiedRun=nil end
								if Hub.reportGucciStatus then Hub.reportGucciStatus("Retrying") end
							end
						end
						task.wait(0.1)
					end
					clearGucciConfirmation(record,false)
				end)
			end
			-- GUCCI CONFIRMATION END

			local function fn21(arg)
				if not arg.Parent or arg.Health <= 0 then
					return
				end
				arg.Sit = true
				task.wait(0.05)

				if arg.Parent then
					arg.Sit = false
				end

				task.wait(0.05)
			end

			local function fn22()
				clearGucciConfirmation(tbl16,true)
				if not tbl16 then
					return
				end

				for _, v23 in tbl16.Connections, nil, nil do
					v23:Disconnect()
				end

				table.clear(tbl16.Connections)

				if tbl16.BP then
					tbl16.BP:Destroy()
					tbl16.BP = nil
				end

				local hum = tbl16.Hum
				local hrp = tbl16.HRP

				if hum and hum.Parent then
					hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, tbl16.Jumping)

					if hum.SeatPart == tbl16.Seat or not hum.SeatPart then
						hum.Sit = false
					end
				end

				if tbl16.Ragdoll and hrp and hrp.Parent then
					tbl11.RagdollRemote:FireServer(hrp, 0.15)
				end

				local v23 = tbl16
				local v24 = tbl16
				tbl16.Hum = nil
				v23.HRP = nil
				v24.Ragdoll = nil
			end

			local function fn23()
				if not tbl16 then
					return
				end
				fn22()

				if tbl16.InvConn then
					tbl16.InvConn:Disconnect()
				end

				local vehicle = tbl16.Vehicle
				local seat = tbl16.Seat

				if vehicle then
					tbl7.ToyAuraReserved[vehicle] = tbl16.Reserved

					if tbl16.Type == "Train" then
						if seat and seat.Parent then
							seat.Transparency = tbl16.Transparency
							seat.CanCollide = tbl16.CanCollide
						end
					else
						tbl12.DestroyToy(vehicle)
					end
				end

				tbl16 = nil
			end

			local function fn24()
				local character = localPlayer.Character
				local n36 = 0
				local attempts=0
				local v23 = nil
				local v24, v25, v26, gucciType, ragdolled, object, v27, seat

				while tbl8.GucciAntiGrab do
					attempts+=1
					if attempts>1 and Hub.reportGucciStatus then Hub.reportGucciStatus("Retrying") end
					local exitTo = nil
					local vehicle, root, flag13, fn25, flag14, now3, cFrame2, n37, connection, flag15, flag16, now4, flag17, parent2, v28, bodyPosition, random, parent3, seatPart, flag18, occupant, playerFromCharacter

					while true do
						task.wait()
						v24, v25, v26 = tbl12.Char()
						gucciType = tbl9.GucciType

						if v24 ~= character then
							character = v24
							n36 = os.clock() + 1
						end

						if tbl16 and (tbl16.Type ~= gucciType or not tbl16.Vehicle.Parent or not tbl16.Seat.Parent or tbl16.Char ~= v24) then
							fn23()
						end

						if tbl8.GucciAntiGrab then
							ragdolled = v26 and v26:FindFirstChild("Ragdolled")

							if not (v25 and v26 and v26.Health > 0 and ragdolled) or isHeld.Value or ragdolled.Value then
								exitTo = 1
								break
							elseif not tbl16 then
								local seat2, v29, v30, flag19, flag20, parent4, parent5, fn26

								if gucciType == "Train" then
									object = train:FindFirstChild("Object")
									object = object and object:FindFirstChild("ObjectModel")
									seat2 = object and object:FindFirstChildWhichIsA("Seat")

									if not seat2 then
										exitTo = 25
										break
									else
										v29 = tbl7.ToyAuraReserved[object]
										v30 = nil
										flag19 = not tbl8.GucciAntiGrab or tbl9.GucciType ~= gucciType or localPlayer.Character ~= v24

										if flag19 then
											flag20 = flag19
										else
											parent4 = object and object.Parent
											parent5 = parent4 and seat2 and seat2.Parent
											flag20 = not parent5
										end

										if flag20 then
											exitTo = 26
											break
										else
											tbl16 = {
												Vehicle = object,
												Seat = seat2,
												Root = v30,
												Char = v24,
												Type = gucciType,
												Reserved = v29,
												Connections = {},
												Transparency = seat2.Transparency,
												CanCollide = seat2.CanCollide,
											}

											tbl7.ToyAuraReserved[object] = true
											v23 = nil

											if gucciType == "Train" then
												v27 = tbl16
												vehicle = v27.Vehicle
												seat = v27.Seat
												root = v27.Root
												flag13 = seat.Occupant and seat.Occupant ~= v26

												if flag13 then
													exitTo = 32
													break
												else
													fn25 = function()
														local flag21 = tbl16 == v27 and tbl8.GucciAntiGrab and tbl9.GucciType == gucciType and localPlayer.Character == v24 and vehicle.Parent and seat.Parent and v25.Parent and v26.Parent and v26.Health > 0 and not isHeld.Value and not ragdolled.Value

														if flag21 then
															flag21 = not (seat.Occupant and seat.Occupant ~= v26)
														end

														return flag21
													end

													v27.Hum = v26
													v27.HRP = v25
													v27.Jumping = v26:GetStateEnabled(Enum.HumanoidStateType.Jumping)
													seat.Transparency = 1
													seat.CanCollide = false
													v26.Sit = false
													flag14 = false

													-- Replace BOTH orphaned task.defer blocks with this COMPLETE pair.
-- Paste inside each Gucci setup variant, between flag14 = false and now3 = os.clock().
table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or child.Name ~= "SeatWeld" then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == seat then
            child.Enabled = false
            child:Destroy()
            flag14 = true
        end
    end)
end))

table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or not child:IsA("LocalScript")
        or not child.Name:lower():find("control") then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == v24 then
            child.Enabled = false
            child:Destroy()
        end
    end)
end))


													now3 = os.clock()
													cFrame2 = v25.CFrame
													n37 = nil
													v27.Ragdoll = true
													connection = nil

													connection = RunService.Heartbeat:Connect(function()
														if not fn25() then
															connection:Disconnect()
														elseif n37 and os.clock() >= n37 then
															v27.Ragdoll = false
															tbl11.RagdollRemote:FireServer(v25, 0.15)
															connection:Disconnect()
														else
															tbl11.RagdollRemote:FireServer(v25, 0)
														end
													end)

													table.insert(v27.Connections, connection)
													tbl11.RagdollRemote:FireServer(v25, 0)
													task.wait()

													if not fn25() then
														exitTo = 33
														break
													else
														seat:Sit(v26)

														while true do
															task.wait()

															if not fn25() then
																break
															else
																flag15 = flag14 or os.clock() - now3 > 0.75
																if not flag15 then
																	continue
																end
																break
															end
														end

														flag16 = not fn25() or not flag14

														if flag16 then
															exitTo = 34
															break
														else
															v26.Sit = false
															now4 = os.clock()
															n37 = now4 + 0.15
															beginGucciConfirmation(v27,fn25,flag14)

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.SNO(root)
															end

															if parent2 then
																if not fn25() then
																	exitTo = 36
																	break
																else
																	bodyPosition = Instance.new("BodyPosition")
																	bodyPosition.Name = "GucciBP"
																	bodyPosition.D = 200
																	bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
																	random = math.random
																	bodyPosition.Position = Vector3.new(math.random(-100000, 100000), 100000, random(-100000, 100000))
																	v27.BP = bodyPosition
																	vehicle.Name = "GucciRSC"
																	bodyPosition.Parent = root
																	v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

																	while fn25() do
																		task.wait()
																	end

																	parent3 = v26.Parent
																	seatPart = parent3 and v26.Health > 0 and v26.SeatPart
																	flag18 = seatPart and v26.SeatPart ~= seat

																	if flag18 then
																		fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
																	end

																	if tbl16 == v27 then
																		occupant = seat.Occupant
																		playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

																		if playerFromCharacter then
																			fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
																		end

																		fn22()

																		if playerFromCharacter then
																			fn23()
																		end
																	end

																	fn21(v26)
																	if tbl8.GucciAntiGrab then
																		continue
																	end
																end
															else
																exitTo = 35
																break
															end
														end
													end
												end
											else
												fn26 = function(descendant)
													if descendant:IsA("BasePart") then
														descendant.Transparency = 1
														descendant.CanCollide = false
													elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
														descendant.Transparency = 1
													elseif descendant.Name == "ItemSpawnSound" then
														descendant:Destroy()
													end
												end

												for _, v31 in object:GetDescendants() do
													fn26(v31)
												end

												tbl16.InvConn = object.DescendantAdded:Connect(fn26)
												v23 = nil
												v27 = tbl16
												vehicle = v27.Vehicle
												seat = v27.Seat
												root = v27.Root
												flag13 = seat.Occupant and seat.Occupant ~= v26

												if flag13 then
													exitTo = 27
													break
												else
													fn25 = function()
														local flag21 = tbl16 == v27 and tbl8.GucciAntiGrab and tbl9.GucciType == gucciType and localPlayer.Character == v24 and vehicle.Parent and seat.Parent and v25.Parent and v26.Parent and v26.Health > 0 and not isHeld.Value and not ragdolled.Value

														if flag21 then
															flag21 = not (seat.Occupant and seat.Occupant ~= v26)
														end

														return flag21
													end

													v27.Hum = v26
													v27.HRP = v25
													v27.Jumping = v26:GetStateEnabled(Enum.HumanoidStateType.Jumping)
													seat.Transparency = 1
													seat.CanCollide = false
													v26.Sit = false
													flag14 = false

													-- Replace BOTH orphaned task.defer blocks with this COMPLETE pair.
-- Paste inside each Gucci setup variant, between flag14 = false and now3 = os.clock().
table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or child.Name ~= "SeatWeld" then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == seat then
            child.Enabled = false
            child:Destroy()
            flag14 = true
        end
    end)
end))

table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or not child:IsA("LocalScript")
        or not child.Name:lower():find("control") then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == v24 then
            child.Enabled = false
            child:Destroy()
        end
    end)
end))


													now3 = os.clock()
													cFrame2 = v25.CFrame
													n37 = nil
													v27.Ragdoll = true
													connection = nil

													connection = RunService.Heartbeat:Connect(function()
														if not fn25() then
															connection:Disconnect()
														elseif n37 and os.clock() >= n37 then
															v27.Ragdoll = false
															tbl11.RagdollRemote:FireServer(v25, 0.15)
															connection:Disconnect()
														else
															tbl11.RagdollRemote:FireServer(v25, 0)
														end
													end)

													table.insert(v27.Connections, connection)
													tbl11.RagdollRemote:FireServer(v25, 0)
													task.wait()

													if not fn25() then
														exitTo = 28
														break
													else
														seat:Sit(v26)

														while true do
															task.wait()

															if not fn25() then
																break
															else
																flag15 = flag14 or os.clock() - now3 > 0.75
																if not flag15 then
																	continue
																end
																break
															end
														end

														flag16 = not fn25() or not flag14

														if flag16 then
															exitTo = 29
															break
														else
															v26.Sit = false
															now4 = os.clock()
															n37 = now4 + 0.15
															beginGucciConfirmation(v27,fn25,flag14)

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.SNO(root)
															end

															if parent2 then
																if not fn25() then
																	exitTo = 31
																	break
																else
																	bodyPosition = Instance.new("BodyPosition")
																	bodyPosition.Name = "GucciBP"
																	bodyPosition.D = 200
																	bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
																	random = math.random
																	bodyPosition.Position = Vector3.new(math.random(-100000, 100000), 100000, random(-100000, 100000))
																	v27.BP = bodyPosition
																	vehicle.Name = "GucciRSC"
																	bodyPosition.Parent = root
																	v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

																	while fn25() do
																		task.wait()
																	end

																	parent3 = v26.Parent
																	seatPart = parent3 and v26.Health > 0 and v26.SeatPart
																	flag18 = seatPart and v26.SeatPart ~= seat

																	if flag18 then
																		fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
																	end

																	if tbl16 == v27 then
																		occupant = seat.Occupant
																		playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

																		if playerFromCharacter then
																			fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
																		end

																		fn22()

																		if playerFromCharacter then
																			fn23()
																		end
																	end

																	fn21(v26)
																	if tbl8.GucciAntiGrab then
																		continue
																	end
																end
															else
																exitTo = 30
																break
															end
														end
													end
												end
											end
										end
									end
								else
									object = tbl12.SpawnToy(gucciType, CFrame.new(100000, 500000, 0), 2, true)
									seat2 = object and object:WaitForChild("VehicleSeat", 1.25)
									v29 = nil

									if seat2 then
										v30 = tbl12.FindNicePart(object)
										v29 = nil
										flag19 = not tbl8.GucciAntiGrab or tbl9.GucciType ~= gucciType or localPlayer.Character ~= v24

										if flag19 then
											flag20 = flag19
										else
											parent4 = object and object.Parent
											parent5 = parent4 and seat2 and seat2.Parent
											flag20 = not parent5
										end

										if flag20 then
											exitTo = 14
											break
										else
											tbl16 = {
												Vehicle = object,
												Seat = seat2,
												Root = v30,
												Char = v24,
												Type = gucciType,
												Reserved = v29,
												Connections = {},
												Transparency = seat2.Transparency,
												CanCollide = seat2.CanCollide,
											}

											tbl7.ToyAuraReserved[object] = true
											v23 = nil

											if gucciType == "Train" then
												v27 = tbl16
												vehicle = v27.Vehicle
												seat = v27.Seat
												root = v27.Root
												flag13 = seat.Occupant and seat.Occupant ~= v26

												if flag13 then
													exitTo = 20
													break
												else
													fn25 = function()
														local flag21 = tbl16 == v27 and tbl8.GucciAntiGrab and tbl9.GucciType == gucciType and localPlayer.Character == v24 and vehicle.Parent and seat.Parent and v25.Parent and v26.Parent and v26.Health > 0 and not isHeld.Value and not ragdolled.Value

														if flag21 then
															flag21 = not (seat.Occupant and seat.Occupant ~= v26)
														end

														return flag21
													end

													v27.Hum = v26
													v27.HRP = v25
													v27.Jumping = v26:GetStateEnabled(Enum.HumanoidStateType.Jumping)
													seat.Transparency = 1
													seat.CanCollide = false
													v26.Sit = false
													flag14 = false

													-- Replace BOTH orphaned task.defer blocks with this COMPLETE pair.
-- Paste inside each Gucci setup variant, between flag14 = false and now3 = os.clock().
table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or child.Name ~= "SeatWeld" then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == seat then
            child.Enabled = false
            child:Destroy()
            flag14 = true
        end
    end)
end))

table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or not child:IsA("LocalScript")
        or not child.Name:lower():find("control") then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == v24 then
            child.Enabled = false
            child:Destroy()
        end
    end)
end))


													now3 = os.clock()
													cFrame2 = v25.CFrame
													n37 = nil
													v27.Ragdoll = true
													connection = nil

													connection = RunService.Heartbeat:Connect(function()
														if not fn25() then
															connection:Disconnect()
														elseif n37 and os.clock() >= n37 then
															v27.Ragdoll = false
															tbl11.RagdollRemote:FireServer(v25, 0.15)
															connection:Disconnect()
														else
															tbl11.RagdollRemote:FireServer(v25, 0)
														end
													end)

													table.insert(v27.Connections, connection)
													tbl11.RagdollRemote:FireServer(v25, 0)
													task.wait()

													if not fn25() then
														exitTo = 21
														break
													else
														seat:Sit(v26)

														while true do
															task.wait()

															if not fn25() then
																break
															else
																flag15 = flag14 or os.clock() - now3 > 0.75
																if not flag15 then
																	continue
																end
																break
															end
														end

														flag16 = not fn25() or not flag14

														if flag16 then
															exitTo = 22
															break
														else
															v26.Sit = false
															now4 = os.clock()
															n37 = now4 + 0.15
															beginGucciConfirmation(v27,fn25,flag14)

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.SNO(root)
															end

															if parent2 then
																if not fn25() then
																	exitTo = 24
																	break
																else
																	bodyPosition = Instance.new("BodyPosition")
																	bodyPosition.Name = "GucciBP"
																	bodyPosition.D = 200
																	bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
																	random = math.random
																	bodyPosition.Position = Vector3.new(math.random(-100000, 100000), 100000, random(-100000, 100000))
																	v27.BP = bodyPosition
																	vehicle.Name = "GucciRSC"
																	bodyPosition.Parent = root
																	v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

																	while fn25() do
																		task.wait()
																	end

																	parent3 = v26.Parent
																	seatPart = parent3 and v26.Health > 0 and v26.SeatPart
																	flag18 = seatPart and v26.SeatPart ~= seat

																	if flag18 then
																		fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
																	end

																	if tbl16 == v27 then
																		occupant = seat.Occupant
																		playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

																		if playerFromCharacter then
																			fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
																		end

																		fn22()

																		if playerFromCharacter then
																			fn23()
																		end
																	end

																	fn21(v26)
																	if tbl8.GucciAntiGrab then
																		continue
																	end
																end
															else
																exitTo = 23
																break
															end
														end
													end
												end
											else
												fn26 = function(arg)
													if arg:IsA("BasePart") then
														arg.Transparency = 1
														arg.CanCollide = false
													elseif arg:IsA("Decal") or arg:IsA("Texture") then
														arg.Transparency = 1
													elseif arg.Name == "ItemSpawnSound" then
														arg:Destroy()
													end
												end

												for _, v31 in object:GetDescendants() do
													fn26(v31)
												end

												tbl16.InvConn = object.DescendantAdded:Connect(fn26)
												v23 = nil
												v27 = tbl16
												vehicle = v27.Vehicle
												seat = v27.Seat
												root = v27.Root
												flag13 = seat.Occupant and seat.Occupant ~= v26

												if flag13 then
													exitTo = 15
													break
												else
													fn25 = function()
														local flag21 = tbl16 == v27 and tbl8.GucciAntiGrab and tbl9.GucciType == gucciType and localPlayer.Character == v24 and vehicle.Parent and seat.Parent and v25.Parent and v26.Parent and v26.Health > 0 and not isHeld.Value and not ragdolled.Value

														if flag21 then
															flag21 = not (seat.Occupant and seat.Occupant ~= v26)
														end

														return flag21
													end

													v27.Hum = v26
													v27.HRP = v25
													v27.Jumping = v26:GetStateEnabled(Enum.HumanoidStateType.Jumping)
													seat.Transparency = 1
													seat.CanCollide = false
													v26.Sit = false
													flag14 = false

													-- Replace BOTH orphaned task.defer blocks with this COMPLETE pair.
-- Paste inside each Gucci setup variant, between flag14 = false and now3 = os.clock().
table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or child.Name ~= "SeatWeld" then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == seat then
            child.Enabled = false
            child:Destroy()
            flag14 = true
        end
    end)
end))

table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or not child:IsA("LocalScript")
        or not child.Name:lower():find("control") then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == v24 then
            child.Enabled = false
            child:Destroy()
        end
    end)
end))


													now3 = os.clock()
													cFrame2 = v25.CFrame
													n37 = nil
													v27.Ragdoll = true
													connection = nil

													connection = RunService.Heartbeat:Connect(function()
														if not fn25() then
															connection:Disconnect()
														elseif n37 and os.clock() >= n37 then
															v27.Ragdoll = false
															tbl11.RagdollRemote:FireServer(v25, 0.15)
															connection:Disconnect()
														else
															tbl11.RagdollRemote:FireServer(v25, 0)
														end
													end)

													table.insert(v27.Connections, connection)
													tbl11.RagdollRemote:FireServer(v25, 0)
													task.wait()

													if not fn25() then
														exitTo = 16
														break
													else
														seat:Sit(v26)

														while true do
															task.wait()

															if not fn25() then
																break
															else
																flag15 = flag14 or os.clock() - now3 > 0.75
																if not flag15 then
																	continue
																end
																break
															end
														end

														flag16 = not fn25() or not flag14

														if flag16 then
															exitTo = 17
															break
														else
															v26.Sit = false
															now4 = os.clock()
															n37 = now4 + 0.15
															beginGucciConfirmation(v27,fn25,flag14)

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.SNO(root)
															end

															if parent2 then
																if not fn25() then
																	exitTo = 19
																	break
																else
																	bodyPosition = Instance.new("BodyPosition")
																	bodyPosition.Name = "GucciBP"
																	bodyPosition.D = 200
																	bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
																	random = math.random
																	bodyPosition.Position = Vector3.new(math.random(-100000, 100000), 100000, random(-100000, 100000))
																	v27.BP = bodyPosition
																	vehicle.Name = "GucciRSC"
																	bodyPosition.Parent = root
																	v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

																	while fn25() do
																		task.wait()
																	end

																	parent3 = v26.Parent
																	seatPart = parent3 and v26.Health > 0 and v26.SeatPart
																	flag18 = seatPart and v26.SeatPart ~= seat

																	if flag18 then
																		fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
																	end

																	if tbl16 == v27 then
																		occupant = seat.Occupant
																		playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

																		if playerFromCharacter then
																			fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
																		end

																		fn22()

																		if playerFromCharacter then
																			fn23()
																		end
																	end

																	fn21(v26)
																	if tbl8.GucciAntiGrab then
																		continue
																	end
																end
															else
																exitTo = 18
																break
															end
														end
													end
												end
											end
										end
									else
										v30 = seat2
										flag19 = not tbl8.GucciAntiGrab or tbl9.GucciType ~= gucciType or localPlayer.Character ~= v24

										if flag19 then
											flag20 = flag19
										else
											parent4 = object and object.Parent
											parent5 = parent4 and seat2 and seat2.Parent
											flag20 = not parent5
										end

										if flag20 then
											exitTo = 3
											break
										else
											tbl16 = {
												Vehicle = object,
												Seat = seat2,
												Root = v30,
												Char = v24,
												Type = gucciType,
												Reserved = v29,
												Connections = {},
												Transparency = seat2.Transparency,
												CanCollide = seat2.CanCollide,
											}

											tbl7.ToyAuraReserved[object] = true
											v23 = nil

											if gucciType == "Train" then
												v27 = tbl16
												vehicle = v27.Vehicle
												seat = v27.Seat
												root = v27.Root
												flag13 = seat.Occupant and seat.Occupant ~= v26

												if flag13 then
													exitTo = 9
													break
												else
													fn25 = function()
														local flag21 = tbl16 == v27 and tbl8.GucciAntiGrab and tbl9.GucciType == gucciType and localPlayer.Character == v24 and vehicle.Parent and seat.Parent and v25.Parent and v26.Parent and v26.Health > 0 and not isHeld.Value and not ragdolled.Value

														if flag21 then
															flag21 = not (seat.Occupant and seat.Occupant ~= v26)
														end

														return flag21
													end

													v27.Hum = v26
													v27.HRP = v25
													v27.Jumping = v26:GetStateEnabled(Enum.HumanoidStateType.Jumping)
													seat.Transparency = 1
													seat.CanCollide = false
													v26.Sit = false
													flag14 = false

													-- Replace BOTH orphaned task.defer blocks with this COMPLETE pair.
-- Paste inside each Gucci setup variant, between flag14 = false and now3 = os.clock().
table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or child.Name ~= "SeatWeld" then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == seat then
            child.Enabled = false
            child:Destroy()
            flag14 = true
        end
    end)
end))

table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or not child:IsA("LocalScript")
        or not child.Name:lower():find("control") then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == v24 then
            child.Enabled = false
            child:Destroy()
        end
    end)
end))


													now3 = os.clock()
													cFrame2 = v25.CFrame
													n37 = nil
													v27.Ragdoll = true
													connection = nil

													connection = RunService.Heartbeat:Connect(function()
														if not fn25() then
															connection:Disconnect()
														elseif n37 and os.clock() >= n37 then
															v27.Ragdoll = false
															tbl11.RagdollRemote:FireServer(v25, 0.15)
															connection:Disconnect()
														else
															tbl11.RagdollRemote:FireServer(v25, 0)
														end
													end)

													table.insert(v27.Connections, connection)
													tbl11.RagdollRemote:FireServer(v25, 0)
													task.wait()

													if not fn25() then
														exitTo = 10
														break
													else
														seat:Sit(v26)

														while true do
															task.wait()

															if not fn25() then
																break
															else
																flag15 = flag14 or os.clock() - now3 > 0.75
																if not flag15 then
																	continue
																end
																break
															end
														end

														flag16 = not fn25() or not flag14

														if flag16 then
															exitTo = 11
															break
														else
															v26.Sit = false
															now4 = os.clock()
															n37 = now4 + 0.15
															beginGucciConfirmation(v27,fn25,flag14)

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.SNO(root)
															end

															if parent2 then
																if not fn25() then
																	exitTo = 13
																	break
																else
																	bodyPosition = Instance.new("BodyPosition")
																	bodyPosition.Name = "GucciBP"
																	bodyPosition.D = 200
																	bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
																	random = math.random
																	bodyPosition.Position = Vector3.new(math.random(-100000, 100000), 100000, random(-100000, 100000))
																	v27.BP = bodyPosition
																	vehicle.Name = "GucciRSC"
																	bodyPosition.Parent = root
																	v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

																	while fn25() do
																		task.wait()
																	end

																	parent3 = v26.Parent
																	seatPart = parent3 and v26.Health > 0 and v26.SeatPart
																	flag18 = seatPart and v26.SeatPart ~= seat

																	if flag18 then
																		fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
																	end

																	if tbl16 == v27 then
																		occupant = seat.Occupant
																		playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

																		if playerFromCharacter then
																			fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
																		end

																		fn22()

																		if playerFromCharacter then
																			fn23()
																		end
																	end

																	fn21(v26)
																	if tbl8.GucciAntiGrab then
																		continue
																	end
																end
															else
																exitTo = 12
																break
															end
														end
													end
												end
											else
												fn26 = function(arg)
													if arg:IsA("BasePart") then
														arg.Transparency = 1
														arg.CanCollide = false
													elseif arg:IsA("Decal") or arg:IsA("Texture") then
														arg.Transparency = 1
													elseif arg.Name == "ItemSpawnSound" then
														arg:Destroy()
													end
												end

												for _, v31 in object:GetDescendants() do
													fn26(v31)
												end

												tbl16.InvConn = object.DescendantAdded:Connect(fn26)
												v23 = nil
												v27 = tbl16
												vehicle = v27.Vehicle
												seat = v27.Seat
												root = v27.Root
												flag13 = seat.Occupant and seat.Occupant ~= v26

												if flag13 then
													exitTo = 4
													break
												else
													fn25 = function()
														local flag21 = tbl16 == v27 and tbl8.GucciAntiGrab and tbl9.GucciType == gucciType and localPlayer.Character == v24 and vehicle.Parent and seat.Parent and v25.Parent and v26.Parent and v26.Health > 0 and not isHeld.Value and not ragdolled.Value

														if flag21 then
															flag21 = not (seat.Occupant and seat.Occupant ~= v26)
														end

														return flag21
													end

													v27.Hum = v26
													v27.HRP = v25
													v27.Jumping = v26:GetStateEnabled(Enum.HumanoidStateType.Jumping)
													seat.Transparency = 1
													seat.CanCollide = false
													v26.Sit = false
													flag14 = false

													-- Replace BOTH orphaned task.defer blocks with this COMPLETE pair.
-- Paste inside each Gucci setup variant, between flag14 = false and now3 = os.clock().
table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or child.Name ~= "SeatWeld" then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == seat then
            child.Enabled = false
            child:Destroy()
            flag14 = true
        end
    end)
end))

table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or not child:IsA("LocalScript")
        or not child.Name:lower():find("control") then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == v24 then
            child.Enabled = false
            child:Destroy()
        end
    end)
end))


													now3 = os.clock()
													cFrame2 = v25.CFrame
													n37 = nil
													v27.Ragdoll = true
													connection = nil

													connection = RunService.Heartbeat:Connect(function()
														if not fn25() then
															connection:Disconnect()
														elseif n37 and os.clock() >= n37 then
															v27.Ragdoll = false
															tbl11.RagdollRemote:FireServer(v25, 0.15)
															connection:Disconnect()
														else
															tbl11.RagdollRemote:FireServer(v25, 0)
														end
													end)

													table.insert(v27.Connections, connection)
													tbl11.RagdollRemote:FireServer(v25, 0)
													task.wait()

													if not fn25() then
														exitTo = 5
														break
													else
														seat:Sit(v26)

														while true do
															task.wait()

															if not fn25() then
																break
															else
																flag15 = flag14 or os.clock() - now3 > 0.75
																if not flag15 then
																	continue
																end
																break
															end
														end

														flag16 = not fn25() or not flag14

														if flag16 then
															exitTo = 6
															break
														else
															v26.Sit = false
															now4 = os.clock()
															n37 = now4 + 0.15
															beginGucciConfirmation(v27,fn25,flag14)

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.SNO(root)
															end

															if parent2 then
																if not fn25() then
																	exitTo = 8
																	break
																else
																	bodyPosition = Instance.new("BodyPosition")
																	bodyPosition.Name = "GucciBP"
																	bodyPosition.D = 200
																	bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
																	random = math.random
																	bodyPosition.Position = Vector3.new(math.random(-100000, 100000), 100000, random(-100000, 100000))
																	v27.BP = bodyPosition
																	vehicle.Name = "GucciRSC"
																	bodyPosition.Parent = root
																	v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

																	while fn25() do
																		task.wait()
																	end

																	parent3 = v26.Parent
																	seatPart = parent3 and v26.Health > 0 and v26.SeatPart
																	flag18 = seatPart and v26.SeatPart ~= seat

																	if flag18 then
																		fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
																	end

																	if tbl16 == v27 then
																		occupant = seat.Occupant
																		playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

																		if playerFromCharacter then
																			fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
																		end

																		fn22()

																		if playerFromCharacter then
																			fn23()
																		end
																	end

																	fn21(v26)
																	if tbl8.GucciAntiGrab then
																		continue
																	end
																end
															else
																exitTo = 7
																break
															end
														end
													end
												end
											end
										end
									end
								end
							else
								exitTo = 2
								break
							end
						end

						break
					end

					if exitTo == 1 then
						continue
					else
						local flag19, flag20

						if exitTo == 2 then
							v27 = tbl16
							vehicle = v27.Vehicle
							seat = v27.Seat
							root = v27.Root
							flag13 = seat.Occupant and seat.Occupant ~= v26

							if flag13 then
								fn23()
							else
								fn25 = function()
									local flag21 = tbl16 == v27 and tbl8.GucciAntiGrab and tbl9.GucciType == gucciType and localPlayer.Character == v24 and vehicle.Parent and seat.Parent and v25.Parent and v26.Parent and v26.Health > 0 and not isHeld.Value and not ragdolled.Value

									if flag21 then
										flag21 = not (seat.Occupant and seat.Occupant ~= v26)
									end

									return flag21
								end

								v27.Hum = v26
								v27.HRP = v25
								v27.Jumping = v26:GetStateEnabled(Enum.HumanoidStateType.Jumping)
								seat.Transparency = 1
								seat.CanCollide = false
								v26.Sit = false
								flag14 = false

								-- Replace BOTH orphaned task.defer blocks with this COMPLETE pair.
-- Paste inside each Gucci setup variant, between flag14 = false and now3 = os.clock().
table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or child.Name ~= "SeatWeld" then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == seat then
            child.Enabled = false
            child:Destroy()
            flag14 = true
        end
    end)
end))

table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or not child:IsA("LocalScript")
        or not child.Name:lower():find("control") then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == v24 then
            child.Enabled = false
            child:Destroy()
        end
    end)
end))


								now3 = os.clock()
								cFrame2 = v25.CFrame
								n37 = nil
								v27.Ragdoll = true
								connection = nil

								connection = RunService.Heartbeat:Connect(function()
									if not fn25() then
										connection:Disconnect()
									elseif n37 and os.clock() >= n37 then
										v27.Ragdoll = false
										tbl11.RagdollRemote:FireServer(v25, 0.15)
										connection:Disconnect()
									else
										tbl11.RagdollRemote:FireServer(v25, 0)
									end
								end)

								table.insert(v27.Connections, connection)
								tbl11.RagdollRemote:FireServer(v25, 0)
								task.wait()

								if not fn25() then
									if tbl16 == v27 then
										fn22()
									end

									fn21(v26)
								else
									seat:Sit(v26)

									while true do
										task.wait()

										if not fn25() then
											break
										else
											flag15 = flag14 or os.clock() - now3 > 0.75
											if not flag15 then
												continue
											end
											break
										end
									end

									flag16 = not fn25() or not flag14

									if flag16 then
										flag19 = v26.Sit and seat.Occupant == v26
										flag20 = not flag19

										if tbl16 == v27 then
											fn23()
										end

										if flag20 then
											fn21(v26)
										end
									else
										v26.Sit = false
										now4 = os.clock()
										n37 = now4 + 0.15
										beginGucciConfirmation(v27,fn25,flag14)

										if now4 < n36 then
											tbl12.Teleport(v25, cFrame2)
										end

										flag17 = gucciType ~= "Train" and root
										parent2 = flag17 and root.Parent

										if parent2 then
											v28 = root:IsDescendantOf(workspace.PlotItems)
											parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.SNO(root)
										end

										if parent2 then
											if not fn25() then
												if tbl16 == v27 then
													fn23()
												end

												fn21(v26)
											else
												bodyPosition = Instance.new("BodyPosition")
												bodyPosition.Name = "GucciBP"
												bodyPosition.D = 200
												bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
												random = math.random
												bodyPosition.Position = Vector3.new(math.random(-100000, 100000), 100000, random(-100000, 100000))
												v27.BP = bodyPosition
												vehicle.Name = "GucciRSC"
												bodyPosition.Parent = root
												v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

												while fn25() do
													task.wait()
												end

												parent3 = v26.Parent
												seatPart = parent3 and v26.Health > 0 and v26.SeatPart
												flag18 = seatPart and v26.SeatPart ~= seat

												if flag18 then
													fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
												end

												if tbl16 == v27 then
													occupant = seat.Occupant
													playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

													if playerFromCharacter then
														fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
													end

													fn22()

													if playerFromCharacter then
														fn23()
													end
												end

												fn21(v26)
											end
										else
											v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

											while fn25() do
												task.wait()
											end

											parent3 = v26.Parent
											seatPart = parent3 and v26.Health > 0 and v26.SeatPart
											flag18 = seatPart and v26.SeatPart ~= seat

											if flag18 then
												fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
											end

											if tbl16 == v27 then
												occupant = seat.Occupant
												playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

												if playerFromCharacter then
													fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
												end

												fn22()

												if playerFromCharacter then
													fn23()
												end
											end

											fn21(v26)
										end
									end
								end
							end

							continue
						else
							local flag21

							if exitTo == 3 then
								flag21 = object and gucciType ~= "Train"

								if flag21 then
									tbl7.ToyAuraReserved[object] = nil
									tbl12.DestroyToy(object)
								end

								continue
							elseif exitTo == 4 then
								fn23()
								continue
							elseif exitTo == 5 then
								if tbl16 == v27 then
									fn22()
								end

								fn21(v26)
								continue
							elseif exitTo == 6 then
								flag19 = v26.Sit and seat.Occupant == v26
								flag20 = not flag19

								if tbl16 == v27 then
									fn23()
								end

								if flag20 then
									fn21(v26)
								end

								continue
							elseif exitTo == 7 then
								v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

								while fn25() do
									task.wait()
								end

								parent3 = v26.Parent
								seatPart = parent3 and v26.Health > 0 and v26.SeatPart
								flag18 = seatPart and v26.SeatPart ~= seat

								if flag18 then
									fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
								end

								if tbl16 == v27 then
									occupant = seat.Occupant
									playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

									if playerFromCharacter then
										fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
									end

									fn22()

									if playerFromCharacter then
										fn23()
									end
								end

								fn21(v26)
								continue
							elseif exitTo == 8 then
								if tbl16 == v27 then
									fn23()
								end

								fn21(v26)
								continue
							elseif exitTo == 9 then
								fn23()
								continue
							elseif exitTo == 10 then
								if tbl16 == v27 then
									fn22()
								end

								fn21(v26)
								continue
							elseif exitTo == 11 then
								flag19 = v26.Sit and seat.Occupant == v26
								flag20 = not flag19

								if tbl16 == v27 then
									fn23()
								end

								if flag20 then
									fn21(v26)
								end

								continue
							elseif exitTo == 12 then
								v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

								while fn25() do
									task.wait()
								end

								parent3 = v26.Parent
								seatPart = parent3 and v26.Health > 0 and v26.SeatPart
								flag18 = seatPart and v26.SeatPart ~= seat

								if flag18 then
									fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
								end

								if tbl16 == v27 then
									occupant = seat.Occupant
									playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

									if playerFromCharacter then
										fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
									end

									fn22()

									if playerFromCharacter then
										fn23()
									end
								end

								fn21(v26)
								continue
							elseif exitTo == 13 then
								if tbl16 == v27 then
									fn23()
								end

								fn21(v26)
								continue
							elseif exitTo == 14 then
								flag21 = object and gucciType ~= "Train"

								if flag21 then
									tbl7.ToyAuraReserved[object] = nil
									tbl12.DestroyToy(object)
								end

								continue
							elseif exitTo == 15 then
								fn23()
								continue
							elseif exitTo == 16 then
								if tbl16 == v27 then
									fn22()
								end

								fn21(v26)
								continue
							elseif exitTo == 17 then
								flag19 = v26.Sit and seat.Occupant == v26
								flag20 = not flag19

								if tbl16 == v27 then
									fn23()
								end

								if flag20 then
									fn21(v26)
								end

								continue
							elseif exitTo == 18 then
								v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

								while fn25() do
									task.wait()
								end

								parent3 = v26.Parent
								seatPart = parent3 and v26.Health > 0 and v26.SeatPart
								flag18 = seatPart and v26.SeatPart ~= seat

								if flag18 then
									fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
								end

								if tbl16 == v27 then
									occupant = seat.Occupant
									playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

									if playerFromCharacter then
										fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
									end

									fn22()

									if playerFromCharacter then
										fn23()
									end
								end

								fn21(v26)
								continue
							elseif exitTo == 19 then
								if tbl16 == v27 then
									fn23()
								end

								fn21(v26)
								continue
							elseif exitTo == 20 then
								fn23()
								continue
							elseif exitTo == 21 then
								if tbl16 == v27 then
									fn22()
								end

								fn21(v26)
								continue
							elseif exitTo == 22 then
								flag19 = v26.Sit and seat.Occupant == v26
								flag20 = not flag19

								if tbl16 == v27 then
									fn23()
								end

								if flag20 then
									fn21(v26)
								end

								continue
							elseif exitTo == 23 then
								v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

								while fn25() do
									task.wait()
								end

								parent3 = v26.Parent
								seatPart = parent3 and v26.Health > 0 and v26.SeatPart
								flag18 = seatPart and v26.SeatPart ~= seat

								if flag18 then
									fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
								end

								if tbl16 == v27 then
									occupant = seat.Occupant
									playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

									if playerFromCharacter then
										fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
									end

									fn22()

									if playerFromCharacter then
										fn23()
									end
								end

								fn21(v26)
								continue
							elseif exitTo == 24 then
								if tbl16 == v27 then
									fn23()
								end

								fn21(v26)
								continue
							elseif exitTo == 25 then
								if v23 ~= gucciType then
									local v29 = fn18
									local str5

									if object then
										str5 = "Train doesn't have seats!"
									else
										str5 = "Train doesn't exist!"
									end

									v29(str5)
									v23 = gucciType
								end

								continue
							elseif exitTo == 26 then
								flag21 = object and gucciType ~= "Train"

								if flag21 then
									tbl7.ToyAuraReserved[object] = nil
									tbl12.DestroyToy(object)
								end

								continue
							elseif exitTo == 27 then
								fn23()
								continue
							elseif exitTo == 28 then
								if tbl16 == v27 then
									fn22()
								end

								fn21(v26)
								continue
							elseif exitTo == 29 then
								flag19 = v26.Sit and seat.Occupant == v26
								flag20 = not flag19

								if tbl16 == v27 then
									fn23()
								end

								if flag20 then
									fn21(v26)
								end

								continue
							elseif exitTo == 30 then
								v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

								while fn25() do
									task.wait()
								end

								parent3 = v26.Parent
								seatPart = parent3 and v26.Health > 0 and v26.SeatPart
								flag18 = seatPart and v26.SeatPart ~= seat

								if flag18 then
									fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
								end

								if tbl16 == v27 then
									occupant = seat.Occupant
									playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

									if playerFromCharacter then
										fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
									end

									fn22()

									if playerFromCharacter then
										fn23()
									end
								end

								fn21(v26)
								continue
							elseif exitTo == 31 then
								if tbl16 == v27 then
									fn23()
								end

								fn21(v26)
								continue
							elseif exitTo == 32 then
								fn23()
								continue
							elseif exitTo == 33 then
								if tbl16 == v27 then
									fn22()
								end

								fn21(v26)
								continue
							elseif exitTo == 34 then
								flag19 = v26.Sit and seat.Occupant == v26
								flag20 = not flag19

								if tbl16 == v27 then
									fn23()
								end

								if flag20 then
									fn21(v26)
								end

								continue
							elseif exitTo == 35 then
								v26:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

								while fn25() do
									task.wait()
								end

								parent3 = v26.Parent
								seatPart = parent3 and v26.Health > 0 and v26.SeatPart
								flag18 = seatPart and v26.SeatPart ~= seat

								if flag18 then
									fn18("You can't sit on other Vehicles while in Gucci!", "Invincibility")
								end

								if tbl16 == v27 then
									occupant = seat.Occupant
									playerFromCharacter = occupant and occupant ~= v26 and Players:GetPlayerFromCharacter(occupant.Parent)

									if playerFromCharacter then
										fn18(playerFromCharacter.DisplayName .. " sat on your gucci!")
									end

									fn22()

									if playerFromCharacter then
										fn23()
									end
								end

								fn21(v26)
								continue
							elseif exitTo == 36 then
								if tbl16 == v27 then
									fn23()
								end

								fn21(v26)
								continue
							end
						end
					end

					break
				end
			end

			tbl12.SetGucciAntiGrab = function(arg)
				tbl8.GucciAntiGrab = arg and not flag11
				if not tbl8.GucciAntiGrab then
					fn23()
					return
				end

				if flag12 then
					return
				end
				flag12 = true

				task.spawn(function()
					local ok, result = pcall(fn24)
					fn23()
					flag12 = nil

					if not ok then
						warn("[GUCCI Anti Grab] " .. tostring(result))
						if Hub.reportGucciStatus then Hub.reportGucciStatus("Error","Gucci controller error: "..tostring(result):sub(1,160)) end

						if not flag11 then
							toggles.GucciAntiGrab:SetValue(false)
						end
					end
				end)
			end
		end
		-- Additional supplied defense behaviors, sharing the supplied Gucci helpers.
		local defenseGroup=DefenseGroup
		local settings=DefenseExtra
		local workers={}
		local workerControls={}
		local stopActions={}
		local ownedProperties={}
		local function remember(instance,property)
			local record=ownedProperties[instance]
			if not record then record={};ownedProperties[instance]=record end
			if record[property]==nil then record[property]=instance[property] end
		end
		local function restoreProperties()
			for instance,record in pairs(ownedProperties) do
				for property,value in pairs(record) do pcall(function() instance[property]=value end) end
				ownedProperties[instance]=nil
			end
		end
		local function charAlive()
			local char,root,hum=tbl12.Char()
			return char,root,hum,root and hum and hum.Health>0
		end
		local function stopWorker(key)
			tbl8[key]=false
			if stopActions[key] then stopActions[key]() end
		end
		local function runWorker(key,interval,action,cleanup)
			stopActions[key]=cleanup
			return function(on)
				tbl8[key]=on
				Hub.requestSave()
				if not on then if cleanup then cleanup() end;return end
				if workers[key] then return end
				workers[key]=true
				task.spawn(function()
					local ok,message=xpcall(function()
						while Hub.alive and not flag11 and tbl8[key] do
							action()
							task.wait(type(interval)=="function" and interval() or interval)
						end
					end,debug.traceback)
					workers[key]=nil
					if cleanup then cleanup() end
					if not ok then tbl8[key]=false;local control=workerControls[key];if control and control.Value then control:SetValue(false) end;warn("[Source defense "..key.."] "..tostring(message));notify("Defense error",key.." stopped, check the console for details.",5) end
				end)
			end
		end
		local function bind(id,key,interval,action,cleanup)
			workerControls[key]=Toggles[id]
			local callback=runWorker(key,interval,action,cleanup)
			if Toggles[id] then Toggles[id].Callback=callback end
			return callback
		end
		local function add(id,text,key,interval,action,cleanup)
			defenseGroup:AddToggle(id,{Text=text,Default=false,Callback=runWorker(key,interval,action,cleanup)})
			workerControls[key]=Toggles[id]
		end
		-- Pure helper functions and the supplied default anti-grab function are inserted verbatim.
		tbl12.ResetVelocity = function(arg)
			if not arg or not arg:IsA("BasePart") then
				return false
			end

			if arg.AssemblyAngularVelocity ~= Vector3.zero then
				arg.AssemblyAngularVelocity = Vector3.zero
			end

			if arg.AssemblyLinearVelocity ~= Vector3.zero then
				arg.AssemblyLinearVelocity = Vector3.zero
			end

			return true
		end
		tbl12.RepositionLimbs = function(arg, arg2)
			local humanoidRootPart = arg:FindFirstChild("HumanoidRootPart")
			local torso = arg:FindFirstChild("Torso")
			if not humanoidRootPart or not torso then
				return
			end
			local neck = torso:FindFirstChild("Neck")
			if neck and neck.Enabled then
				return
			end
			local lookVector = humanoidRootPart.CFrame.LookVector
			local vector = Vector3.new(lookVector.X, 0, lookVector.Z)
			if vector.Magnitude < 0.001 then
				return
			end
			local cframe = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + vector.Unit)

			for k, v24 in pairs(tbl7.LimbOffsetsRL) do
				local v25 = arg:FindFirstChild(k)

				if v25 and v25:IsA("BasePart") then
					local cFrame2 = cframe * v24

					if v25.CFrame ~= cFrame2 then
						v25.CFrame = cFrame2
					end

					if arg2 then
						tbl12.ResetVelocity(v25)
					end
				end
			end
		end
		tbl12.ToggleCollisions = function(arg, canCollide, arg2, arg3)
			if canCollide == nil then
				canCollide = false
			end

			local lightPhysicalProperties

			if arg3 then
				lightPhysicalProperties = tbl12.LightPhysicalProperties
			else
				lightPhysicalProperties = nil
			end

			for _, child in pairs(arg:GetChildren()) do
				if child:IsA("BasePart") then
					local flag12

					if canCollide then
						flag12 = child.Name == "Torso" or child.Name == "Head"
					else
						flag12 = canCollide
					end

					if flag12 then
						if child.CanCollide ~= canCollide then
							child.CanCollide = canCollide
						end
					elseif not canCollide then
						if child.CanCollide ~= canCollide then
							child.CanCollide = canCollide
						end

						if not arg2 then
							local ragdollLimbPart = child:FindFirstChild("RagdollLimbPart")

							if ragdollLimbPart and ragdollLimbPart.CanCollide then
								ragdollLimbPart.CanCollide = false
							end
						end
					end

					if child.Name ~= "HumanoidRootPart" and child.CustomPhysicalProperties ~= lightPhysicalProperties then
						child.CustomPhysicalProperties = lightPhysicalProperties
					end
				end
			end
		end
		tbl12.ExtraEscape = function()
			local v22, v23, v24 = tbl12.Char()
			if not v23 or not v24 or v24.Health == 0 or tbl7.States.Escaping or localPlayer.InPlot.Value then
				return
			end
			tbl7.States.Escaping = true
			local TractorGreen = tbl12.SpawnToy("TractorGreen", workspace.Waypoints.TudorHouse.CFrame)
			if not TractorGreen then
				tbl7.States.Escaping = false
				return
			end
			local vehicleSeat = TractorGreen:WaitForChild("VehicleSeat", 1)
			if not vehicleSeat then
				tbl7.States.Escaping = false
				return tbl12.DestroyToy(TractorGreen)
			end
			local now3 = tick()
			local flag12 = false
			v24.Sit = false
			vehicleSeat:Sit(v24)

			local connection = vehicleSeat.ChildAdded:Connect(function(child)
				if child.Name == "SeatWeld" then
					child.Enabled = false
					flag12 = true
					child:Destroy()
				end
			end)

			while true do
				fn20()
				if not (flag12 or tick() - now3 > 0.7) then
					continue
				end
				break
			end

			connection:Disconnect()
			v24.Sit = false
			tbl7.States.Escaping = false
			return tbl12.DestroyToy(TractorGreen)
		end
		tbl12.BreakLimb = function(arg, arg2)
			local flag12 = arg == localPlayer
			if flag12 and tbl8.GucciAntiGrab then
				return fn18("Can't break limbs while in Gucci!")
			end
			local v24, v25, v26 = tbl12.Char(arg)
			local ragdolled = v26 and v26:FindFirstChild("Ragdolled")
			if not (v25 and v26 and v26.Health ~= 0 and ragdolled) then
				return
			end
			local children = v24:GetChildren()
			local flag13 = false

			for _, child in ipairs(children) do
				if child:IsA("BasePart") then
					if child.Name:find("Arm") and (arg2 == "Arms" or arg2 == "All") or child.Name:find("Leg") and (arg2 == "Legs" or arg2 == "All") then
						flag13 = true
						break
					end
				end
			end

			if not flag13 then
				return
			end

			if flag12 then
				tbl11.RagdollRemote:FireServer(v25, 0.35)
				local now3 = tick()

				while true do
					task.wait()
					if not (ragdolled.Value or tick() - now3 > 0.5) then
						continue
					end
					break
				end
			elseif not (tbl12.SNO(v25) and tbl12.Ragdoll(v24)) then
				return
			end

			if not ragdolled.Value then
				return
			end
			local cFrame2 = v25.CFrame

			for _, child in ipairs(children) do
				if child:IsA("BasePart") then
					if child.Name:find("Arm") and (arg2 == "Arms" or arg2 == "All") then
						tbl12.Teleport(child, CFrame.new(0, -100000, 0))
					elseif child.Name:find("Leg") and (arg2 == "Legs" or arg2 == "All") then
						tbl12.Teleport(child, CFrame.new(0, -100000, 0))
					end
				end
			end

			task.wait(0.15)
			if not v25.Parent then
				return
			end

			if flag12 then
				tbl12.Grab(v25)
				task.wait()

				for _, v27 in children, nil, nil do
					if v27.Parent then
						tbl12.ResetVelocity(v27)
					end
				end

				tbl11.RagdollRemote:FireServer(v25, 0)
			else
				workspace.FallenPartsDestroyHeight = -10000
				tbl12.Teleport(v25, CFrame.new(0, -11000, 0))
				task.wait()
				local v27 = workspace
				local fallenPartsDestroyHeight2

				if tbl8.DestroyVoid then
					fallenPartsDestroyHeight2 = (0/0)
				else
					fallenPartsDestroyHeight2 = -100
				end

				v27.FallenPartsDestroyHeight = fallenPartsDestroyHeight2

				if v25.Parent then
					tbl12.Teleport(v25, cFrame2)

					for _, v28 in children, nil, nil do
						if v28.Parent then
							tbl12.ResetVelocity(v28)
						end
					end

					RunService.Heartbeat:Wait()

					for _, v28 in children, nil, nil do
						if v28.Parent then
							tbl12.ResetVelocity(v28)
						end
					end

					if v25.Parent then
						tbl12.RNO(v25)
					end
				end
			end
		end
		local originalBreakLimb=tbl12.BreakLimb
		tbl12.BreakLimb=function(who,which) if who~=Player then return false end;return originalBreakLimb(who,which) end
		local originalCollision=tbl12.ToggleCollisions
		local collisionSaved={}
		tbl12.ToggleCollisions=function(char,...)
			for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then
					if not collisionSaved[part] then collisionSaved[part]={part.CanCollide,part.CustomPhysicalProperties} end
				end end
			return originalCollision(char,...)
		end
		local function restoreCollision()
			for part,record in pairs(collisionSaved) do
				pcall(function() part.CanCollide=record[1];part.CustomPhysicalProperties=record[2] end)
				collisionSaved[part]=nil
			end
		end
		tbl12.LightPhysicalProperties=PhysicalProperties.new(0.01,0.01,0.01,0.01,0.01)
		tbl7.States={}
		tbl7.LimbOffsetsRL={Head=CFrame.new(0,1.5,0),["Left Arm"]=CFrame.new(-1.5,0,0),["Right Arm"]=CFrame.new(1.5,0,0),["Left Leg"]=CFrame.new(-0.5,-2,0),["Right Leg"]=CFrame.new(0.5,-2,0),Torso=CFrame.new()}
		-- Anti Grab keeps its lifecycle-aware Defense callback. Do not replace it
		-- here: imported render loops bypass held-flag replacement and respawn cleanup.

		-- RootAttachment replacement and root mass repair, as used by the supplied Anti Blobman.
		local removedAttachment,attachmentRoot,replacement
		local function restoreBlob()
			if replacement then replacement:Destroy();replacement=nil end
			if removedAttachment and attachmentRoot and attachmentRoot.Parent then removedAttachment.Parent=attachmentRoot end
			removedAttachment,attachmentRoot=nil,nil
		end
		bind("AntiBlobmanToggle","AntiBlobman",0.05,function()
			local char,root,hum,alive=charAlive()
			if not alive then restoreBlob();return end
			if attachmentRoot and attachmentRoot~=root then restoreBlob() end
			if not removedAttachment then
				local attachment=root:FindFirstChild("RootAttachment")
				if attachment and attachment:IsA("Attachment") then
					removedAttachment,attachmentRoot=attachment,root
					attachment.Parent=ReplicatedStorage
					replacement=Hub.new("BoolValue",root);replacement.Name="RootAttachment"
				end
			end
			remember(root,"Massless");root.Massless=false
		end,restoreBlob)

		-- Hold/drop based anti-network-ownership. At most one outstanding call per remote.
		local inputToy,dropPending,holdPending
		local earlyOriginal,earlyReplacement
		local function restoreEarly()
			if earlyReplacement then earlyReplacement:Destroy();earlyReplacement=nil end
			if earlyOriginal and earlyOriginal.Parent==nil then earlyOriginal.Parent=grabEventsFolder end
			earlyOriginal=nil
		end
		local function disableEarly()
			if earlyReplacement and earlyReplacement.Parent then return end
			local current=grabEventsFolder:FindFirstChild("EndGrabEarly")
			if current and current~=earlyReplacement then earlyOriginal=current;current.Parent=nil end
			earlyReplacement=Hub.new("RemoteEvent",grabEventsFolder);earlyReplacement.Name="EndGrabEarly"
		end
		local function clearInput()
			if inputToy then tbl12.DestroyToy(inputToy);inputToy=nil end
			restoreEarly()
		end
		tbl9.AntiInputType="FoodHamburger";tbl9.InputLgDelay=0.05;tbl9.AILTransparency=1
		bind("AntiInputLag","AntiInputLag",function() return math.max(0.05,tbl9.InputLgDelay) end,function()
			local char,root,hum,alive=charAlive()
			if not alive then clearInput();return end
			disableEarly()
			if inputToy and (not inputToy.Parent or inputToy.Name~=tbl9.AntiInputType) then tbl12.DestroyToy(inputToy);inputToy=nil end
			if not inputToy then inputToy=tbl12.SpawnToy(tbl9.AntiInputType,CFrame.new(0,1e20,0),2,true) end
			if not tbl8.AntiInputLag then clearInput();return end
			if not inputToy then return end
			local toy=inputToy
			local holdPart=toy:FindFirstChild("HoldPart")
			local holdRemote=holdPart and holdPart:FindFirstChild("HoldItemRemoteFunction")
			local dropRemote=holdPart and holdPart:FindFirstChild("DropItemRemoteFunction")
			if not holdRemote or not dropRemote then tbl12.DestroyToy(toy);inputToy=nil;return end
			local constraint=holdPart:FindFirstChild("RigidConstraint")
			local link=constraint and constraint.Attachment1
			local left=char:FindFirstChild("Left Arm");local right=char:FindFirstChild("Right Arm")
			if link and link~=(left and left:FindFirstChild("LeftGripAttachment")) and link~=(right and right:FindFirstChild("RightGripAttachment")) then
				tbl12.DestroyToy(toy);inputToy=nil;return
			end
			for _,part in ipairs(toy:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=false;if part:IsA("MeshPart") or part.Name=="Part" then part.Transparency=tbl9.AILTransparency end end end
			if not dropPending then dropPending=true;task.spawn(function() pcall(function() if toy.Parent and tbl8.AntiInputLag then Hub.invoke(dropRemote,toy,CFrame.new(0,1e20,0),Vector3.zero) end end);dropPending=false end) end
			if not holdPending then holdPending=true;task.spawn(function() pcall(function() if toy.Parent and tbl8.AntiInputLag and Player.Character==char then Hub.invoke(holdRemote,toy,char) end end);holdPending=false end) end
		end,clearInput)
		settings:AddDropdown("SourceInputToy",{Text="Anti Input, interactable toy",Values={"FoodHamburger","InstrumentDrumBongos","InstrumentBrassTrumpet","InstrumentBrassBugle","InstrumentVoiceMicrophone","InstrumentWoodwindOcarina","InstrumentGuitarUkulele","InstrumentGuitarLyre","InstrumentGuitarBanjo","InstrumentGuitarAcoustic","CupMugBrown","CupMugWhite","FoodBanana","FoodBread","FoodBroccoli","FoodCakePink","FoodCoconut","FoodDippyEgg","FoodDonut","FoodFrenchFries","FoodHotdog","FoodMayonnaise","FoodMeatStick","FoodMushroomPoison","FoodPizzaCheese","FoodPizzaPepperoni","FoodSodaCan","PoopPile","PoopPileSparkle"},Default=1,Callback=function(value) tbl9.AntiInputType=value;Hub.requestSave() end})
		settings:AddSlider("SourceInputDelay",{Text="Anti Input, hold/drop delay",Default=0.05,Min=0.05,Max=0.3,Rounding=2,Callback=function(value) tbl9.InputLgDelay=value;Hub.requestSave() end})
		settings:AddSlider("SourceInputTransparency",{Text="Anti Input, item transparency",Default=1,Min=0,Max=1,Rounding=2,Callback=function(value) tbl9.AILTransparency=value;Hub.requestSave() end})

		-- The supplied Anti Banana intentionally breaks the local character's legs.
		local bananaHip,bananaHum
		local function restoreBanana()
			if bananaHum and bananaHum.Parent and bananaHip~=nil then bananaHum.HipHeight=bananaHip end
			bananaHip,bananaHum=nil,nil
		end
		add("SourceAntiBanana","Anti Banana","AntiBanana",0.03,function()
			local char,root,hum,alive=charAlive()
			if not alive then restoreBanana();return end
			local leg=char:FindFirstChild("Right Leg")
			if not leg or not tbl12.IsNetworkOwner(root) then return end
			if bananaHum~=hum then restoreBanana();bananaHum=hum;bananaHip=hum.HipHeight end
			local gucciWasOn=tbl8.GucciAntiGrab
			local ok,err=pcall(function()
				if gucciWasOn then tbl12.SetGucciAntiGrab(false);task.wait(0.25) end
				if not tbl8.AntiBanana or Player.Character~=char then return end
				hum.Sit=false;hum.HipHeight=2
				tbl12.BreakLimb(Player,"Legs")
				local deadline=os.clock()+0.75
				repeat
					if not tbl8.AntiBanana or not Hub.alive or Player.Character~=char or hum.Health<=0 or not leg.Parent then break end
					hum.HipHeight=2;task.wait()
				until os.clock()>=deadline
			end)
			local control=Toggles.AutoGucciBlobToggle
			if gucciWasOn and control and control.Value and not flag11 and Hub.alive and Player.Character==char then
				tbl12.SetGucciAntiGrab(true)
			end
			if not ok then error(err,0) end
		end,restoreBanana)
		defenseGroup:AddLabel("Anti Banana uses the source's leg-breaking method, respawn restores missing limbs.")

		add("SourceAntiSnowball","Anti Snowball","AntiSnowball",0.03,function()
			if tbl8.GucciAntiGrab then return end
			local char,root,hum,alive=charAlive()
			if not alive then return end
			if tbl8.AntiBanana and char:FindFirstChild("Right Leg") then return end
			local weld=root:FindFirstChild("WeldHRP")
			if not weld then return end
			remember(hum,"AutoRotate")
			tbl11.RagdollRemote:FireServer(root,0.5)
			if not hum.SeatPart then hum.Sit=false end
			hum.AutoRotate=true
			if weld.Enabled then
				game:GetService("ContextActionService"):UnbindAction("JumpRemover")
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,true)
				tbl12.RepositionLimbs(char)
				tbl12.ToggleCollisions(char,false,false,true)
			end
		end,restoreCollision)


		add("SourceBreakPCLD","[Break PCLD] Anti Kick (two resets)","AntiKick2",0.2,function()
			local char,root,hum,alive=charAlive()
			if not hum or (alive and hum:GetAttribute("BrokenPCLD")) then return end
			for _=1,2 do
				if not tbl8.AntiKick2 or flag11 then return end
				local original=Player.Character
				repeat
					if not tbl8.AntiKick2 or flag11 then return end
					local _,_,current=tbl12.Char()
					if current and current.Health>0 then current.Health=0;current:ChangeState(Enum.HumanoidStateType.Dead) end
					task.wait()
				until Player.Character~=original
				local nextChar=Player.Character
				if not nextChar then
					repeat task.wait() until not tbl8.AntiKick2 or flag11 or Player.Character
					nextChar=Player.Character
				end
				if not nextChar then return end
				nextChar:WaitForChild("Humanoid",5)
			end
			local _,_,current=tbl12.Char()
			if current and tbl8.AntiKick2 then current:SetAttribute("BrokenPCLD",true) end
		end)

		-- Supplied low-FPS auto anti-lag supplements the existing line-burst detector.
		local lowFps=false
		local fpsThreshold=3
		local lowFpsStarted=os.clock()
		Hub.connect(originalRunService.Heartbeat,function(dt)
			if lowFps and os.clock()-lowFpsStarted>=2.5 and dt>0 and math.floor(1/dt)<fpsThreshold then
				local toggle=Toggles.AntiLagToggle
				if toggle and not toggle.Value then toggle:SetValue(true);fn18("Anti Lag enabled, FPS below threshold.","Auto Anti Lag") end
			end
		end)
		defenseGroup:AddToggle("SourceLowFpsAntiLag",{Text="Auto Anti Lag",Default=false,Callback=function(on) lowFps=on;Hub.requestSave() end})
		settings:AddSlider("SourceLowFpsThreshold",{Text="Auto Anti Lag FPS threshold",Default=3,Min=1,Max=20,Rounding=0,Callback=function(value) fpsThreshold=value;Hub.requestSave() end})

		-- Supplied anti-invisibility is included by the adjoining module.
		-- Supplied correction-event auto reset, independent from the old periodic reset option.
		tbl8.AutoLeave=true;tbl9.KickFlags=0
		local lastFlag=0
		local corrections=ReplicatedStorage:FindFirstChild("GameCorrectionEvents")
		local correctionRemote=corrections and corrections:FindFirstChild("GameCorrectionsNotify")
		if correctionRemote then Hub.connect(correctionRemote.OnClientEvent,function(reason)
				if reason~="Flying" then return end
				local now=os.clock()
				if now-lastFlag>1 then lastFlag=now;tbl9.KickFlags=1 else tbl9.KickFlags+=1 end
				if not tbl8.AutoReset then return end
				if tbl9.KickFlags>=4 and tbl8.AutoLeave then Player:Kick("Arriva Core Hub, Auto Reset, avoided repeated movement flags");return end
				local _,_,hum=tbl12.Char()
				if hum then hum:ChangeState(Enum.HumanoidStateType.Running);hum:ChangeState(Enum.HumanoidStateType.Dead) end
			end) end
		if Toggles.AutoResetToggle then Toggles.AutoResetToggle.Callback=function(on) tbl8.AutoReset=on;Hub.requestSave() end end
		settings:AddToggle("SourceCorrectionLeave",{Text="Auto leave after four rapid correction flags",Default=true,Callback=function(on) tbl8.AutoLeave=on;Hub.requestSave() end})

		local loopSaved,loopCharacter
		bind("LoopTP","LoopTP",0.04,function()
			local char,root,hum,alive=charAlive()
			if not alive then return end
			if loopCharacter~=char then loopCharacter=char;loopSaved=root.CFrame end
			char:PivotTo(CFrame.new(math.random(-1000,1000),-7.35,math.random(-1000,1000)))
		end,function()
			local char,root=tbl12.Char()
			if root and char==loopCharacter and loopSaved then char:PivotTo(loopSaved);root.AssemblyLinearVelocity=Vector3.zero end
			loopSaved,loopCharacter=nil,nil
		end)
		local originalVoid
		defenseGroup:AddToggle("SourceDisableVoid",{Text="Disable Void",Default=false,Callback=function(on)
			tbl8.DestroyVoid=on
			if on then if originalVoid==nil then originalVoid=Workspace.FallenPartsDestroyHeight end;Workspace.FallenPartsDestroyHeight=0/0
			elseif originalVoid~=nil then Workspace.FallenPartsDestroyHeight=originalVoid;originalVoid=nil end
			Hub.requestSave()
		end})
		Hub.cleanup(function()
			for key in pairs(workers) do stopWorker(key) end
			restoreCollision();restoreProperties();restoreBlob();clearInput();restoreBanana()
			if originalVoid~=nil then Workspace.FallenPartsDestroyHeight=originalVoid end
		end)
		Hub.connect(Player.CharacterRemoving,function()
			tbl7.States["Anti Grab"]=false
			restoreCollision();restoreProperties();restoreBlob();clearInput();restoreBanana()
		end)
		Hub.sourceDefense={state=tbl8,settings=tbl9,workers=workers,stop=stopWorker}

		-- Remaining environmental defenses use the supplied mechanisms with hub cleanup.
		local touchRecords={}
		local touchModes={paint=false,poison=false}
		local function touchMatch(part)
			if not part:IsA("BasePart") then return false end
			if touchModes.paint and part.Name=="PaintPlayerPart" then return true end
			local parent=part.Parent
			return touchModes.poison and parent and (parent.Name=="PoisonBigHole" or parent.Name=="PoisonSmallHole") and (part.Name=="PaintPlayerPart" or part.Name=="PoisonHurtPart")
		end
		local function restoreTouch(part)
			local saved=touchRecords[part];if not saved then return end
			touchRecords[part]=nil;saved.connection:Disconnect()
			if part.Parent then part.CanTouch=saved.value end
		end
		local function inspectTouch(part)
			if not touchMatch(part) then if touchRecords[part] then restoreTouch(part) end;return end
			if not touchRecords[part] then
				local saved={value=part.CanTouch};touchRecords[part]=saved
				saved.connection=Hub.connect(part:GetPropertyChangedSignal("CanTouch"),function() if touchRecords[part] and touchMatch(part) and part.CanTouch then part.CanTouch=false end end)
			end
			part.CanTouch=false
		end
		local touchEpoch=0
		local function setTouchMode(key,on)
			touchModes[key]=on;touchEpoch+=1;local ticket=touchEpoch
			for part in pairs(touchRecords) do if not touchMatch(part) then restoreTouch(part) end end
			if on then Hub.scanDescendants(Workspace,inspectTouch,function() return ticket==touchEpoch and (touchModes.paint or touchModes.poison) end) end
			Hub.requestSave()
		end
		if Toggles.PaintDeleteToggle then Toggles.PaintDeleteToggle.Callback=function(on) setTouchMode("paint",on) end end
		if Toggles.PrivatePoisonTouch then Toggles.PrivatePoisonTouch.Callback=function(on) setTouchMode("poison",on) end end
		Hub.connect(Workspace.DescendantAdded,function(part) if touchModes.paint or touchModes.poison then inspectTouch(part) end end)
		Hub.connect(Workspace.DescendantRemoving,function(part) if touchRecords[part] then restoreTouch(part) end end)

		bind("AntiStickyToggle","AntiSticky",0.1,function()
			local char=Player.Character;if not char then return end
			local own=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			local plots=Workspace:FindFirstChild("PlotItems")
			local inOwnPlot=Player:FindFirstChild("InOwnedPlot")
			local seen={}
			for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then
					for _,connected in ipairs(part:GetConnectedParts()) do
						if connected.Name=="StickyPart" and not seen[connected] and not (own and connected:IsDescendantOf(own))
							and not (plots and connected:IsDescendantOf(plots) and not (inOwnPlot and inOwnPlot.Value)) then
							seen[connected]=true
							for _,child in ipairs(connected:GetChildren()) do if child:IsA("TouchTransmitter") or child:IsA("TouchInterest") then child:Destroy() end end
							local model=connected.Parent
							local grabPart=model and tbl12.FindNicePart(model)
							if grabPart then tbl12.Grab(grabPart) end
						end
					end
				end end
		end)

		-- Source anti-void thresholds and origin recovery; keep the separate safe-zone controls.
		bind("AntiVoidToggle","AntiVoid",0.03,function()
			local _,root,hum,alive=charAlive()
			if not alive then return end
			if root.Position.Y>=10000 or root.Position.Y<=-500 then tbl12.Teleport(root,CFrame.new(0,15,0)) end
		end)

		-- Nearby explosion parts briefly anchor the local root, clear momentum, then release it.
		if Toggles.AntiExplosionToggle then Toggles.AntiExplosionToggle.Callback=function(on) tbl8.AntiExplosion=on;Hub.requestSave() end end
		local explosionAnchors={}
		Hub.connect(Workspace.ChildAdded,function(part)
			if not tbl8.AntiExplosion or part.Name~="Part" or not part:IsA("BasePart") then return end
			local char,root,hum,alive=charAlive()
			if not alive or (part.Position-root.Position).Magnitude>20 then return end
			local record=explosionAnchors[root]
			if not record then record={original=root.Anchored,untilTime=0};explosionAnchors[root]=record end
			record.untilTime=os.clock()+0.02;root.Anchored=true
			task.spawn(function()
				repeat task.wait() until not Hub.alive or not tbl8.AntiExplosion or not root.Parent or os.clock()>=record.untilTime
				if explosionAnchors[root]~=record then return end
				explosionAnchors[root]=nil
				if root.Parent then
					if Player.Character==char then
						if not hum.SeatPart then hum.Sit=false end
						for _,child in ipairs(char:GetDescendants()) do if child:IsA("BasePart") and child.Name=="RagdollLimbPart" then child.CanCollide=false end end
						tbl12.ResetVelocity(root)
					end
					root.Anchored=record.original
				end
			end)
		end)

		-- Anti Burn: suppress the screen effect independently of extinguisher availability.
		local extinguisher,extinguishFrame
		local suppressedFire,fireOverlays={},{}
		local function restoreExtinguisher()
			if extinguisher and extinguisher.Parent and extinguishFrame then
				pcall(function() extinguisher.CFrame=extinguishFrame end)
			end
			extinguisher,extinguishFrame=nil,nil
		end
		local function currentBurn()
			local char,root,hum,alive=charAlive()
			return char,root,alive,root and root:FindFirstChild("FireParticleEmitter")
		end
		local function restoreBurn()
			restoreExtinguisher()
			local _,_,alive,fire=currentBurn()
			for overlay,record in pairs(fireOverlays) do
				pcall(function()
					if overlay.Parent then
						-- Never resurrect an overlay captured during a fire that has ended.
						overlay.Visible=alive and fire~=nil and Player.Character==record.character and record.visible or false
					end
				end)
				fireOverlays[overlay]=nil
			end
			for emitter,value in pairs(suppressedFire) do
				pcall(function() if emitter.Parent then emitter.Enabled=value end end)
				suppressedFire[emitter]=nil
			end
		end
		bind("AntiBurnToggle","AntiBurn",0.03,function()
			local char,root,alive,fire=currentBurn()
			local playerGui=Player:FindFirstChildOfClass("PlayerGui")
			local screen=playerGui and playerGui:FindFirstChild("ScreenOverlayGui")
			local overlay=screen and screen:FindFirstChild("FireFade")
			if overlay and overlay:IsA("GuiObject") then
				if not fireOverlays[overlay] then fireOverlays[overlay]={visible=overlay.Visible,character=char} end
				overlay.Visible=false
			end
			-- Destroyed/replaced GUI instances must not accumulate across respawns.
			for old in pairs(fireOverlays) do if not old.Parent then fireOverlays[old]=nil end end
			for old in pairs(suppressedFire) do if not old.Parent then suppressedFire[old]=nil end end
			if not alive or not fire then restoreExtinguisher();return end
			if suppressedFire[fire]==nil then suppressedFire[fire]=fire.Enabled end
			fire.Enabled=false
			if not extinguisher or not extinguisher.Parent then
				local map=Workspace:FindFirstChild("Map")
				local hole=map and map:FindFirstChild("Hole")
				for _,name in ipairs({"PoisonSmallHole","PoisonBigHole"}) do
					local area=hole and hole:FindFirstChild(name)
					local part=area and area:FindFirstChild("ExtinguishPart")
					if part and part:IsA("BasePart") then extinguisher=part;extinguishFrame=part.CFrame;break end
				end
			end
			if extinguisher then extinguisher.CFrame=root.CFrame end
		end,restoreBurn)

		-- Source manual Anti Lag also disables the sticky-touch script. Preserve original enabled values.
		local lagScripts={}
		local function updateLagScripts(on)
			local scripts=Player:FindFirstChild("PlayerScripts")
			if on and scripts then
				-- CharacterAndBeamMove is already owned/restored by the core Anti Lag watcher.
				for _,name in ipairs({"StickyPartsTouchDetection"}) do
					local script=scripts:FindFirstChild(name)
					if script and script:IsA("LocalScript") then if lagScripts[script]==nil then lagScripts[script]=script.Enabled end;script.Enabled=false end
				end
			elseif not on then for script,value in pairs(lagScripts) do pcall(function() if script.Parent then script.Enabled=value end end);lagScripts[script]=nil end end
		end
		local oldAntiLag=Toggles.AntiLagToggle and Toggles.AntiLagToggle.Callback
		if oldAntiLag then Toggles.AntiLagToggle.Callback=function(on) oldAntiLag(on);updateLagScripts(on) end end
		Hub.connect(Player.DescendantAdded,function(child)
			if Toggles.AntiLagToggle and Toggles.AntiLagToggle.Value and (child.Name=="CharacterAndBeamMove" or child.Name=="StickyPartsTouchDetection") then updateLagScripts(true) end
		end)
		Hub.cleanup(function()
			touchEpoch+=1;touchModes.paint,touchModes.poison=false,false
			for part in pairs(touchRecords) do restoreTouch(part) end
			for root,record in pairs(explosionAnchors) do pcall(function() if root.Parent then root.Anchored=record.original end end) end
			restoreBurn();updateLagScripts(false)
		end)

		-- Supplied PCLD assignment tracking and shuriken anti-kick.
		local updateAntiKickAppearance
		local v18
		local antiKickRunning=false
		local antiKickStart
		local trackingEpoch=0
		local trackerElapsed=0
		tbl7.PCLD={};tbl7.PCLDParts={};tbl7.PlayerList={}
		tbl7.PCLDTracker={PartStates={},Players={},Positions={},Confirmations=3,MaxDistance=6,MinMargin=0.75}
		tbl7.AntiKickSettings={Highlight=false,HighlightFill=Color3.new(1,0,0),HighlightOutl=Color3.new(1,1,1),HighlightFT=0.5,HighlightOT=0,Transparency=0.9}
		tbl7.CharacterHighlightAffects={}
		tbl9.AKType="Shuriken"
		local highlight=Hub.new("Highlight");highlight.Enabled=false
		tbl12.IsWaitingPCLD = function(arg)
			return arg and arg.Position == Vector3.zero
		end
		tbl12.ClearPCLDAssignment = function(arg, arg2)
			if not arg2 then
				return
			end
			local player = arg2 and arg2.Player

			if player and tbl7.PCLD[player] == arg then
				tbl7.PCLD[player] = nil
			end

			table.clear(arg2)
			arg2.Hits = 0

			if arg and arg.Parent then
				arg:SetAttribute("CurrentlyAssignedTo", nil)
			end

			if tbl8.PCLDESP and tbl12.UpdatePCLDESP then
				tbl12.UpdatePCLDESP(arg)
			end
		end
		tbl12.UpdatePCLDAssignments = function()
			local pcldTracker = tbl7.PCLDTracker
			local players = pcldTracker.Players
			local positions = pcldTracker.Positions
			table.clear(players)
			table.clear(positions)
			local flag12 = false

			for k in tbl7.PCLDParts, nil, nil do
				local v23 = pcldTracker.PartStates[k]
				local flag13 = k.Parent and k.Name == "PlayerCharacterLocationDetector" and not tbl12.IsWaitingPCLD(k)

				if flag13 then
					flag13 = not v23 or not v23.Player or v23.Player.Parent ~= Players
				end

				if flag13 then
					flag12 = true
					break
				end
			end

			if flag12 then
				for _, v23 in ipairs(tbl7.PlayerList) do
					local v24, v25, v26 = tbl12.Char(v23)

					if v25 and v26 and v26.Health > 0 then
						players[#players + 1] = v23
						positions[#positions + 1] = v25.Position
					end
				end
			end

			for k in tbl7.PCLDParts, nil, nil do
				if not k.Parent or k.Name ~= "PlayerCharacterLocationDetector" then
					local v23 = pcldTracker.PartStates[k]

					if v23 then
						tbl12.ClearPCLDAssignment(k, v23)
					end

					pcldTracker.PartStates[k] = nil
					tbl7.PCLDParts[k] = nil
				else
					local tbl18 = pcldTracker.PartStates[k]

					if not tbl18 then
						tbl18 = { Hits = 0 }
						pcldTracker.PartStates[k] = tbl18
					end

					if tbl12.IsWaitingPCLD(k) then
						if tbl18.Player or tbl18.Candidate or tbl18.Hits ~= 0 or k:GetAttribute("CurrentlyAssignedTo") ~= nil then
							tbl12.ClearPCLDAssignment(k, tbl18)
						end
					else
						if tbl8.PCLDESP and tbl12.CreatePCLDESP then
							tbl12.CreatePCLDESP(k)
						end

						local position, huge, huge2, v23, n36, v24, v25, v26, flag13, pcldesp, updatePCLDESP

						if tbl18.Player then
							if tbl18.Player.Parent == Players then
								tbl7.PCLD[tbl18.Player] = k

								if tbl8.PCLDESP and tbl12.UpdatePCLDESP then
									tbl12.UpdatePCLDESP(k)
								end
							else
								tbl12.ClearPCLDAssignment(k, tbl18)
								position = k.Position
								huge = math.huge
								huge2 = math.huge
								v23 = nil

								for i, player in ipairs(players) do
									n36 = position - positions[i]
									v24 = n36:Dot(n36)

									if v24 < huge then
										huge2 = huge
										v23 = player
										huge = v24
									elseif v24 < huge2 then
										huge2 = v24
									end
								end

								v25 = math.sqrt(huge)
								v26 = math.sqrt(huge2)
								flag13 = v23 and not tbl7.PCLD[v23] and v25 <= pcldTracker.MaxDistance and v26 - v25 >= pcldTracker.MinMargin

								if flag13 then
									if tbl18.Candidate == v23 then
										tbl18.Hits = tbl18.Hits + 1
									else
										tbl18.Candidate = v23
										tbl18.Hits = 1
									end

									if tbl18.Hits >= pcldTracker.Confirmations then
										tbl18.Player = v23
										tbl18.Candidate = nil
										tbl18.Hits = 0
										tbl7.PCLD[v23] = k
										k:SetAttribute("CurrentlyAssignedTo", v23.Name)
										pcldesp = tbl8.PCLDESP
										updatePCLDESP = pcldesp and tbl12.UpdatePCLDESP

										if updatePCLDESP then
											tbl12.UpdatePCLDESP(k)
										end
									end
								else
									tbl18.Candidate = nil
									tbl18.Hits = 0
								end
							end
						else
							position = k.Position
							huge = math.huge
							huge2 = math.huge
							v23 = nil

							for i, player in ipairs(players) do
								n36 = position - positions[i]
								v24 = n36:Dot(n36)

								if v24 < huge then
									huge2 = huge
									v23 = player
									huge = v24
								elseif v24 < huge2 then
									huge2 = v24
								end
							end

							v25 = math.sqrt(huge)
							v26 = math.sqrt(huge2)
							flag13 = v23 and not tbl7.PCLD[v23] and v25 <= pcldTracker.MaxDistance and v26 - v25 >= pcldTracker.MinMargin

							if flag13 then
								if tbl18.Candidate == v23 then
									tbl18.Hits = tbl18.Hits + 1
								else
									tbl18.Candidate = v23
									tbl18.Hits = 1
								end

								if tbl18.Hits >= pcldTracker.Confirmations then
									tbl18.Player = v23
									tbl18.Candidate = nil
									tbl18.Hits = 0
									tbl7.PCLD[v23] = k
									k:SetAttribute("CurrentlyAssignedTo", v23.Name)
									pcldesp = tbl8.PCLDESP
									updatePCLDESP = pcldesp and tbl12.UpdatePCLDESP

									if updatePCLDESP then
										tbl12.UpdatePCLDESP(k)
									end
								end
							else
								tbl18.Candidate = nil
								tbl18.Hits = 0
							end
						end
					end
				end
			end
		end
		tbl12.DetectPCLD = function(arg)
			return tbl7.PCLD[arg]
		end
		local function trackPCLD(part)
			if tbl8.AntiKick and part:IsA("BasePart") and part.Name=="PlayerCharacterLocationDetector" then tbl7.PCLDParts[part]=true end
		end
		Hub.connect(Workspace.DescendantAdded,trackPCLD)
		Hub.connect(Workspace.DescendantRemoving,function(part)
			if tbl7.PCLDParts[part] then
				local state=tbl7.PCLDTracker.PartStates[part]
				if state then tbl12.ClearPCLDAssignment(part,state) end
				tbl7.PCLDParts[part]=nil;tbl7.PCLDTracker.PartStates[part]=nil
			end
		end)
		Hub.connect(originalRunService.Heartbeat,function(dt)
			if not tbl8.AntiKick then return end
			trackerElapsed+=dt;if trackerElapsed<0.1 then return end;trackerElapsed=0
			tbl7.PlayerList=Players:GetPlayers();tbl12.UpdatePCLDAssignments()
		end)
		local stickyEvents=ReplicatedStorage:FindFirstChild("PlayerEvents")
		local stickyRemote=stickyEvents and stickyEvents:FindFirstChild("StickyPartEvent")
		tbl11.StickyPartEvent={FireServer=function(_,...) if stickyRemote then Hub.fire(stickyRemote,...) end end}
		tbl12.WaitForRuntimeToggle=function(key)
			while not flag11 and Hub.alive and not tbl8[key] do task.wait(0.2) end
			return not flag11 and Hub.alive and tbl8[key]
		end
		local function clearKick()
			if v18 then tbl12.DestroyToy(v18);v18=nil end
			for part,state in pairs(tbl7.PCLDTracker.PartStates) do tbl12.ClearPCLDAssignment(part,state) end
			table.clear(tbl7.PCLDParts);table.clear(tbl7.PCLDTracker.PartStates);table.clear(tbl7.PCLD)
		end
		do
			local function fn21()
				local n36 = os.clock() + 0.35

				repeat
					local v22 = tbl12.DetectPCLD(localPlayer)
					if v22 and v22.Parent and not tbl12.IsWaitingPCLD(v22) then
						return v22
					end
					task.wait(0.05)
				until flag11 or not tbl8.AntiKick or os.clock() >= n36
			end

			local function fn22(arg)
				local NinjaShuriken = tbl12.SpawnToy("NinjaShuriken", arg.CFrame + Vector3.new(0, 15, 0), 3, true)
				local stickyPart = NinjaShuriken and NinjaShuriken:WaitForChild("StickyPart", 1.5)
				local stickyWeld = stickyPart and stickyPart:WaitForChild("StickyWeld", 1.5)
				if stickyPart and stickyWeld and tbl12.SNO(stickyPart) then
					return NinjaShuriken, stickyPart, stickyWeld
				end
				tbl12.DestroyToy(NinjaShuriken)
			end

			local function sourceAntiKickWorker()
				while task.wait(0.03) do
					if flag11 then
						return
					end

					if not tbl8.AntiKick then
						if v18 then
							tbl12.DestroyToy(v18)
							v18 = nil
						end

						if not tbl12.WaitForRuntimeToggle("AntiKick") then
							return
						end
					end

					local antiKickSettings = tbl7.AntiKickSettings
					local v22, v23, v24 = tbl12.Char()
					local ragdollTouchedHitbox = v23 and v23:FindFirstChild("RagdollTouchedHitbox")

					if v23 and v24 and ragdollTouchedHitbox and v24.Health > 0 then
						if localPlayer.InPlot.Value then
							while true do
								task.wait()
								if not (not localPlayer.InPlot.Value or localPlayer.InOwnedPlot.Value) then
									continue
								end
								break
							end
						end

						if tbl9.AKType == "Shuriken" then
							local parent2, shurHighlight, highlight2, antiKick, forcefieldChar, transparency, isMeshPart

							if not (v18 and v18.Name == "ShurikenRSC" and v18:FindFirstChild("StickyPart") and v18.StickyPart:FindFirstChild("StickyWeld") and v18.StickyPart.StickyWeld.Part1 == ragdollTouchedHitbox) then
								local stickyPart = nil
								local stickyWeld, now3, flag12, flag13

								if not v18 or not v18.Parent then
									tbl12.DestroyToy(v18)
									v18 = nil
									local v25 = fn21()
									stickyWeld = nil

									if v25 then
										local v26
										v26, stickyPart, stickyWeld = fn22(v25)
										v18 = v26
									end

									if not v18 then
										local v26
										v26, stickyPart, stickyWeld = fn22(v23)
										v18 = v26

										if v18 then
											v18.Name = "ShurikenRSC"

											task.spawn(function()
												local touchInterest = stickyPart:WaitForChild("TouchInterest", 2.5)

												if touchInterest then
													touchInterest:Destroy()
												end
											end)

											tbl11.StickyPartEvent:FireServer(stickyPart, ragdollTouchedHitbox, CFrame.new(0, -0.3, 0) * CFrame.Angles(1.5707963267948966, 0, 0))
											now3 = tick()

											while true do
												fn20()
												flag12 = stickyWeld.Part1 == ragdollTouchedHitbox or not stickyWeld.Parent or not ragdollTouchedHitbox.Parent or not v24.Parent
												flag13 = flag12 or v24.Health == 0 or tick() - now3 > 0.5
												if not flag13 then
													continue
												end
												break
											end

											parent2 = v18 and v18.Parent

											if parent2 then
												if not tbl8.AntiKick then
													tbl12.DestroyToy(v18)
													v18 = nil
												else
													if updateAntiKickAppearance then updateAntiKickAppearance() end
												end
											end
										end
									elseif v18 then
										v18.Name = "ShurikenRSC"

										task.spawn(function()
											local touchInterest = stickyPart:WaitForChild("TouchInterest", 2.5)

											if touchInterest then
												touchInterest:Destroy()
											end
										end)

										tbl11.StickyPartEvent:FireServer(stickyPart, ragdollTouchedHitbox, CFrame.new(0, -0.3, 0) * CFrame.Angles(1.5707963267948966, 0, 0))
										now3 = tick()

										while true do
											fn20()
											flag12 = stickyWeld.Part1 == ragdollTouchedHitbox or not stickyWeld.Parent or not ragdollTouchedHitbox.Parent or not v24.Parent
											flag13 = flag12 or v24.Health == 0 or tick() - now3 > 0.5
											if not flag13 then
												continue
											end
											break
										end

										parent2 = v18 and v18.Parent

										if parent2 then
											if not tbl8.AntiKick then
												tbl12.DestroyToy(v18)
												v18 = nil
											else
												if updateAntiKickAppearance then updateAntiKickAppearance() end
											end
										end
									end
								else
									stickyPart = v18:WaitForChild("StickyPart", 1.5)
									stickyWeld = stickyPart and stickyPart:WaitForChild("StickyWeld", 1.5)

									if not (stickyPart and stickyWeld) or not tbl12.SNO(stickyPart) then
										tbl12.DestroyToy(v18)
										v18 = nil
									elseif v18 then
										v18.Name = "ShurikenRSC"

										task.spawn(function()
											local touchInterest = stickyPart:WaitForChild("TouchInterest", 2.5)

											if touchInterest then
												touchInterest:Destroy()
											end
										end)

										tbl11.StickyPartEvent:FireServer(stickyPart, ragdollTouchedHitbox, CFrame.new(0, -0.3, 0) * CFrame.Angles(1.5707963267948966, 0, 0))
										now3 = tick()

										while true do
											fn20()
											flag12 = stickyWeld.Part1 == ragdollTouchedHitbox or not stickyWeld.Parent or not ragdollTouchedHitbox.Parent or not v24.Parent
											flag13 = flag12 or v24.Health == 0 or tick() - now3 > 0.5
											if not flag13 then
												continue
											end
											break
										end

										parent2 = v18 and v18.Parent

										if parent2 then
											if not tbl8.AntiKick then
												tbl12.DestroyToy(v18)
												v18 = nil
											else
												if updateAntiKickAppearance then updateAntiKickAppearance() end
											end
										end
									end
								end
							else
								parent2 = v18 and v18.Parent

								if parent2 then
									if not tbl8.AntiKick then
										tbl12.DestroyToy(v18)
										v18 = nil
									else
										if updateAntiKickAppearance then updateAntiKickAppearance() end
									end
								end
							end
						end
					end
				end
			end
			antiKickStart=sourceAntiKickWorker
		end
		local function setAntiKick(on)
			tbl8.AntiKick=on;trackingEpoch+=1;local ticket=trackingEpoch
			Hub.requestSave()
			if not on then clearKick();return end
			if not stickyRemote then tbl8.AntiKick=false;fn18("StickyPartEvent is unavailable.","Anti Kick");return end
			Hub.scanDescendants(Workspace,trackPCLD,function() return tbl8.AntiKick and trackingEpoch==ticket end)
			if antiKickRunning then return end
			antiKickRunning=true
			task.spawn(function()
				local ok,message=xpcall(antiKickStart,debug.traceback)
				antiKickRunning=false
				clearKick()
				if not ok then tbl8.AntiKick=false;warn("[Source Anti Kick] "..tostring(message)) end
			end)
		end
		if Toggles.ShurikenAntiKick then Toggles.ShurikenAntiKick.Callback=setAntiKick end
		settings:AddToggle("SourceAntiKickHighlight",{Text="Anti Kick, highlight shuriken",Default=false,Callback=function(on) tbl7.AntiKickSettings.Highlight=on;if updateAntiKickAppearance then updateAntiKickAppearance() end;Hub.requestSave() end})
		for _,info in ipairs({{"SourceAntiKickFillAlpha","Anti Kick, fill transparency","HighlightFT",0.5},{"SourceAntiKickOutlineAlpha","Anti Kick, outline transparency","HighlightOT",0},{"SourceAntiKickToyAlpha","Anti Kick, shuriken transparency","Transparency",0.9}}) do
			local property=info[3]
			settings:AddSlider(info[1],{Text=info[2],Default=info[4],Min=0,Max=1,Rounding=2,Callback=function(value) tbl7.AntiKickSettings[property]=value;if updateAntiKickAppearance then updateAntiKickAppearance() end;Hub.requestSave() end})
		end
		Hub.cleanup(function() tbl8.AntiKick=false;trackingEpoch+=1;clearKick();highlight:Destroy() end)

		-- ANTI KICK APPEARANCE BEGIN
		local rainbowFill,rainbowOutline=false,false
		local baseFill,baseOutline=tbl7.AntiKickSettings.HighlightFill,tbl7.AntiKickSettings.HighlightOutl
		local appearance={}
		updateAntiKickAppearance=function()
			local config=tbl7.AntiKickSettings
			if rainbowFill or rainbowOutline then
				local color=Color3.fromHSV(os.clock()%5/5,1,1)
				if rainbowFill then config.HighlightFill=color end
				if rainbowOutline then config.HighlightOutl=color end
			end
			local model=tbl8.AntiKick and v18 and v18.Parent and v18 or nil
			if appearance.model~=model then
				if appearance.highlight and appearance.highlight.Parent then appearance.highlight.Enabled=false end
				appearance.model=model;appearance.highlight=nil
			end
			if not model then return end
			local shur=appearance.highlight
			if not shur or shur.Parent~=model then
				shur=model:FindFirstChild("ShurHighlight")
				if not shur or not shur:IsA("Highlight") then
					shur=Hub.new("Highlight",model);shur.Name="ShurHighlight"
				end
				appearance.highlight=shur
			end
			local show=config.Highlight or rainbowFill or rainbowOutline
			shur.Adornee=model
			shur.Enabled=show
			shur.FillColor=config.HighlightFill;shur.OutlineColor=config.HighlightOutl
			shur.FillTransparency=config.HighlightFT;shur.OutlineTransparency=config.HighlightOT
			local opaque=show or (tbl8.ForcefieldChar and tbl7.CharacterHighlightAffects["Anti Kick"])
			local transparency=opaque and 0 or config.Transparency
			for _,part in ipairs(model:GetChildren()) do
				if part:IsA("BasePart") then
					if tbl12.ApplyCharacterHighlightPart then tbl12.ApplyCharacterHighlightPart(part,"Anti Kick") end
					if part:IsA("MeshPart") or part.Name=="Part" then part.Transparency=transparency end
					part.CanCollide=false;part.CanQuery=false
				end
			end
		end
		local function parseHex(value)
			local hex=tostring(value):gsub("^#","")
			if not hex:match("^%x%x%x%x%x%x$") then return end
			return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
		end
		settings:AddInput("SourceAntiKickFillColor",{Text="Anti Kick fill colour, hex",Default="FF0000",Finished=true,Callback=function(value)
			local color=parseHex(value)
			if color then baseFill=color;if not rainbowFill then tbl7.AntiKickSettings.HighlightFill=color end;updateAntiKickAppearance();Hub.requestSave() end
		end})
		settings:AddInput("SourceAntiKickOutlineColor",{Text="Anti Kick outline colour, hex",Default="FFFFFF",Finished=true,Callback=function(value)
			local color=parseHex(value)
			if color then baseOutline=color;if not rainbowOutline then tbl7.AntiKickSettings.HighlightOutl=color end;updateAntiKickAppearance();Hub.requestSave() end
		end})
		settings:AddToggle("SourceAntiKickRainbowFill",{Text="Anti Kick rainbow fill",Default=false,Callback=function(on)
			rainbowFill=on;if not on then tbl7.AntiKickSettings.HighlightFill=baseFill end
			updateAntiKickAppearance();Hub.requestSave()
		end})
		settings:AddToggle("SourceAntiKickRainbowOutline",{Text="Anti Kick rainbow outline",Default=false,Callback=function(on)
			rainbowOutline=on;if not on then tbl7.AntiKickSettings.HighlightOutl=baseOutline end
			updateAntiKickAppearance();Hub.requestSave()
		end})
		local appearanceElapsed=0
		Hub.connect(originalRunService.Heartbeat,function(dt)
			appearanceElapsed+=dt
			if appearanceElapsed<0.05 then return end
			appearanceElapsed=0
			if updateAntiKickAppearance then updateAntiKickAppearance() end
		end)
		Hub.cleanup(function()
			if appearance.highlight and appearance.highlight.Parent then appearance.highlight.Enabled=false end
			appearance.model=nil;appearance.highlight=nil;updateAntiKickAppearance=nil
		end)
		-- ANTI KICK APPEARANCE END

		-- Other local defensive utilities from the supplied protection section.
		local collisionGroups={}
		local function restoreGroups()
			for part,value in pairs(collisionGroups) do pcall(function() if part.Parent then part.CollisionGroup=value end end);collisionGroups[part]=nil end
		end
		add("SourceAntiObjectFling","Anti-Fling, objects noclip","AntiObjectFling",0.1,function()
			local char=Player.Character;if not char then return end
			for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then
					if collisionGroups[part]==nil then collisionGroups[part]=part.CollisionGroup end
					part.CollisionGroup="PlotPlayers"
				end end
		end,restoreGroups)
		local barrierStates={}
		local barrierOn=false
		local function restoreBarriers()
			for part,value in pairs(barrierStates) do pcall(function() if part.Parent then part.CanCollide=value end end);barrierStates[part]=nil end
		end
		local function inspectBarrier(part)
			if not barrierOn or not part:IsA("BasePart") or part.Name~="PlotBarrier" then return end
			local plots=Workspace:FindFirstChild("Plots")
			if plots and part:IsDescendantOf(plots) then if barrierStates[part]==nil then barrierStates[part]=part.CanCollide end;part.CanCollide=false end
		end
		defenseGroup:AddToggle("SourceNoclipBarrier",{Text="Noclip plot barriers locally",Default=false,Callback=function(on)
			barrierOn=on
			if on then Hub.scanDescendants(Workspace,inspectBarrier,function() return barrierOn end) else restoreBarriers() end
			Hub.requestSave()
		end})
		Hub.connect(Workspace.DescendantAdded,inspectBarrier)
		local grabbedLabel=defenseGroup:AddLabel("Last person who grabbed you: nobody")
		local function ownerChanged(value)
			if value.Name~="PartOwner" or not (value:IsA("ObjectValue") or value:IsA("StringValue")) then return end
			local owner=value.Value
			local name=typeof(owner)=="Instance" and owner.Name or tostring(owner)
			if name~="" and name~=Player.Name then grabbedLabel:SetText("Last person who grabbed you: "..name) end
		end
		local ownerListeners={}
		local function bindOwners(char)
			for _,connection in ipairs(ownerListeners) do connection:Disconnect() end;table.clear(ownerListeners)
			if not char then return end
			local function observe(value)
				if value.Name=="PartOwner" and (value:IsA("ObjectValue") or value:IsA("StringValue")) then
					table.insert(ownerListeners,Hub.connect(value.Changed,function() ownerChanged(value) end));ownerChanged(value)
				end
			end
			table.insert(ownerListeners,Hub.connect(char.DescendantAdded,observe))
			for _,value in ipairs(char:GetDescendants()) do observe(value) end
		end
		bindOwners(Player.Character)
		Hub.connect(Player.CharacterAdded,bindOwners)
		Hub.cleanup(function() barrierOn=false;restoreGroups();restoreBarriers();for _,connection in ipairs(ownerListeners) do connection:Disconnect() end end)

		-- Supplied far-coordinate StickyWeld lag filter. Detached welds are restored locally.
		local lagWelds={}
		local weldLagOn=false
		local function ordinary(part)
			if not part or not part:IsA("BasePart") then return false end
			local p=part.Position
			return math.abs(math.abs(p.X)-2147483648)>1e9 and math.abs(math.abs(p.Z)-2147483648)>1e9
		end
		local function clearLagWeld(weld,restore)
			local record=lagWelds[weld];if not record then return end
			lagWelds[weld]=nil
			for _,connection in ipairs(record.connections) do connection:Disconnect() end
			if restore and not weld.Parent and record.parent and record.parent.Parent then pcall(function() weld.Parent=record.parent end) end
		end
		local function inspectLagWeld(weld)
			if not weldLagOn or weld.Name~="StickyWeld" or not weld:IsA("WeldConstraint") or lagWelds[weld] then return end
			local record={parent=weld.Parent,connections={}};lagWelds[weld]=record
			local function update()
				if not weldLagOn or lagWelds[weld]~=record then return end
				if weld.Part0 and weld.Part1 and not (ordinary(weld.Part0) and ordinary(weld.Part1)) then
					if weld.Parent then record.parent=weld.Parent;weld.Parent=nil end
				elseif not weld.Parent and record.parent and record.parent.Parent then weld.Parent=record.parent end
			end
			for _,property in ipairs({"Enabled","Part0","Part1"}) do table.insert(record.connections,Hub.connect(weld:GetPropertyChangedSignal(property),update)) end
			table.insert(record.connections,Hub.connect(weld.Destroying,function() clearLagWeld(weld,false) end))
			update()
		end
		local weldEpoch=0
		local function setWeldLag(on)
			weldLagOn=on;weldEpoch+=1;local ticket=weldEpoch
			if on then Hub.scanDescendants(Workspace,inspectLagWeld,function() return weldLagOn and weldEpoch==ticket end)
			else local list={};for weld in pairs(lagWelds) do table.insert(list,weld) end;for _,weld in ipairs(list) do clearLagWeld(weld,true) end end
		end
		local lagCallback=Toggles.AntiLagToggle and Toggles.AntiLagToggle.Callback
		if lagCallback then Toggles.AntiLagToggle.Callback=function(on) lagCallback(on);setWeldLag(on) end end
		Hub.connect(Workspace.DescendantAdded,inspectLagWeld)
		Hub.cleanup(function() setWeldLag(false) end)

		local remover=Toggles.DestroyTargetGucci
		if remover then remover.Callback=function(on)
				local running,ownsRun=Hub.beginTargetLoop("DestroyTargetGucci",on)
				Hub.requestSave()
				if not on or not ownsRun then return end
				task.spawn(function()
					local _,root=tbl12.Char();local saved=root and root.CFrame
					while running() and not flag11 do
						local target=Hub.nextLoopTarget("destroyGucci")
						if target and Hub.canHarm(target) then
							local ok,message=pcall(tbl12.RemoveGucci,target)
							if not ok then warn("[Source Remove Gucci] "..tostring(message)) end
						end
						task.wait(0.2)
					end
					if saved and root and root.Parent then root.CFrame=saved;root.AssemblyLinearVelocity=Vector3.zero end
				end)
			end end
		Hub.sourceGucci={remove=tbl12.RemoveGucci,set=tbl12.SetGucciAntiGrab,state=tbl8,settings=tbl9,helpers=tbl12}
		DefenseExtra:AddToggle("SourceRagdollOnRemoveGucci",{Text="Ragdoll target during Remove Gucci",Default=false,Callback=function(on) tbl8.RagdollInRG=on;Hub.requestSave() end})
		local status=DefenseExtra:AddLabel("Gucci: supplied seat/weld controller, off")
		-- GUCCI NOTIFICATION STATES BEGIN
		local previousStatus=Hub.updateGucciStatus
		local lastPhase
		local notices={}
		local messages={
			Starting="Gucci starting; preparing the seat/weld controller.",
			Retrying="Gucci retrying; waiting for seat/weld confirmation.",
			Verifying="Gucci is verifying seat release, ownership and controller stability.",
			Active="Gucci active. Setup complete; seat release and controller checks are stable.",
			["Waiting for respawn"]="Gucci is waiting for your character to respawn.",
			Disabled="Gucci disabled.",
			Error="Gucci stopped because its controller encountered an error.",
		}
		Hub.reportGucciStatus=function(phase,message)
			if not Hub.alive then return end
			local proof=Hub.gucciVerifiedRun
			if phase=="Active" and (not tbl8.GucciAntiGrab or not proof or not proof.Confirmed or proof.Char~=Player.Character) then
				phase="Verifying";message=nil
			end
			if phase~="Active" then Hub.gucciVerifiedRun=nil end
			Hub.gucciStage=phase
			status:SetText("Gucci: "..phase)
			if previousStatus then previousStatus() end
			local now=os.clock()
			local repeated=lastPhase==phase
			lastPhase=phase
			-- Retry reminders are useful, but never emit a toast every controller frame.
			local cooldown=phase=="Retrying" and 10 or 2
			if repeated and phase~="Retrying" then return end
			if now-(notices[phase] or -math.huge)<cooldown then return end
			notices[phase]=now
			notify("Gucci",message or messages[phase] or ("Gucci: "..phase),4,
				phase=="Active" and "success" or phase=="Error" and "danger" or phase=="Retrying" and "warning" or "info")
		end
		Hub.updateGucciStatus=function()
			if tbl8.GucciAntiGrab then Hub.reportGucciStatus(Hub.gucciStage or "Starting") end
		end
		-- GUCCI NOTIFICATION STATES END
		local function setGucci(on)
			if on and Hub.stopBlobFlight then Hub.stopBlobFlight() end
			local wasEnabled=tbl8.GucciAntiGrab==true
			if on and not wasEnabled then Hub.reportGucciStatus("Starting") end
			tbl12.SetGucciAntiGrab(on)
			if not on and wasEnabled then Hub.reportGucciStatus("Disabled") end
			Hub.requestSave()
		end
		-- Replace the old callbacks, not a second competing controller.
		Toggles.AutoGucciBlobToggle.Callback=setGucci
		startAntiGucci=function() if Toggles.AutoGucciBlobToggle.Value then setGucci(true) end end
		stopAntiGucci=function() setGucci(false) end
		if Toggles.AutoGucciTrainToggle then
			Toggles.AutoGucciTrainToggle.Callback=function(on)
				if on then tbl9.GucciType="Train";Toggles.AutoGucciBlobToggle:SetValue(true)
				elseif tbl9.GucciType=="Train" then Toggles.AutoGucciBlobToggle:SetValue(false) end
			end
			startAntiGucciTrain=function() if Toggles.AutoGucciTrainToggle.Value then tbl9.GucciType="Train";setGucci(true) end end
			stopAntiGucciTrain=function() if tbl9.GucciType=="Train" then setGucci(false) end end
		end
		DefenseExtra:AddDropdown("SourceGucciVehicle",{Text="Gucci vehicle",Values={"CreatureBlobman","TractorGreen","SantaSleigh","Train"},Default=1,Callback=function(value) tbl9.GucciType=value;Hub.requestSave() end})
		DefenseExtra:AddButton({Text="Stop supplied Gucci and clean its toy",Func=function() Toggles.AutoGucciBlobToggle:SetValue(false) end})
		Hub.cleanup(function()
			flag11=true;tbl12.SetGucciAntiGrab(false)
			for model in pairs(spawned) do tbl12.DestroyToy(model) end
			for _,connection in pairs(runtimeConnections) do connection:Disconnect() end
			for connection in pairs(sourceConnections) do connection:Disconnect() end
			Hub.sourceDefense=nil
			Hub.sourceGucci=nil
			Hub.reportGucciStatus=nil;Hub.gucciVerifiedRun=nil
		end)
	end)()
end

