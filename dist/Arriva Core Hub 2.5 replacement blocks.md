# Arriva Core Hub 2.5 focused replacements

Base commit: `38e568ab00e71bc32f646282a27e1042ac87fac0`. Apply these blocks to that version only. All line numbers below refer to the base script. Replace each entire range, excluding the next boundary. Do not apply them again to the updated full script.

Final active controller: `Toggles.AutoGucciBlobToggle.Callback = setGucci`, calling `tbl12.SetGucciAntiGrab`; train callbacks select `Train` and route through that toggle. `Hub.sourceGucci` exposes this controller. Visits require `Hub.gucciVerifiedRun.Confirmed`, a matching live character/humanoid and `HRP`. `record.Root` is the vehicle root. Gucci stays enabled during visits. Confirmation wait is bounded to 20 seconds; a timeout performs no interaction.

## Saving: flush helper

Original lines 247–256. Start at `function Hub.flushSettings()`. Stop immediately before `function Hub.installConfigLoading` (leave that boundary intact).

```lua
function Hub.flushSettings(explicit)
	if Hub.saveThread then
		pcall(Hub.nativeTask.cancel,Hub.saveThread)
		Hub.threads[Hub.saveThread]=nil
		Hub.saveThread=nil
	end
	if not Hub.ready then return false, "Settings are not ready yet" end
	if not Hub.storage then return false, "File storage is unavailable" end
	return Hub.persistSettings(explicit == true)
end
```

## Saving: manual :save command

Original lines 17211–17222. Start at `commands.save = function()`. Stop immediately before `local lastText, lastTime` (leave that boundary intact).

```lua
	commands.save = function()
		if type(Hub.flushSettings) ~= "function" then
			error("Settings saving unavailable.", 0)
		end

		local ok, reason = Hub.flushSettings(true)
		if not ok then
			error(tostring(reason or "Settings could not be saved."), 0)
		end

		message("Settings saved.", "success")
	end
```

## Anti Banana: suspension and cleanup

Original lines 13608–13631. Start at `-- The supplied Anti Banana intentionally`. Stop immediately before `defenseGroup:AddLabel("Anti Banana` (leave that boundary intact).

```lua
		-- The supplied Anti Banana intentionally breaks the local character's legs.
		local bananaHip,bananaHum,bananaSuspension
		local function releaseBananaGucci(record)
			if not record or bananaSuspension~=record then return end
			bananaSuspension=nil
			local toggle=Toggles.AutoGucciBlobToggle
			if Hub.alive and not flag11 and toggle and toggle.Value
				and Player.Character==record.char and record.hum.Parent==record.char
				and record.hum.Health>0 and not tbl8.GucciAntiGrab then
				tbl12.SetGucciAntiGrab(true)
			end
		end
		local function restoreBanana()
			local hum,hip,record=bananaHum,bananaHip,bananaSuspension
			bananaHip,bananaHum=nil,nil
			if hum and hum.Parent and hip~=nil then
				local ok,err=pcall(function() hum.HipHeight=hip end)
				if not ok then warn("[Anti Banana restore] "..tostring(err)) end
			end
			releaseBananaGucci(record)
		end
		add("SourceAntiBanana","Anti Banana (supplied leg method)","AntiBanana",0.03,function()
			local char,root,hum,alive=charAlive()
			if not alive then restoreBanana();return end
			local leg=char:FindFirstChild("Right Leg")
			if not leg or not tbl12.IsNetworkOwner(root) then return end
			if bananaHum~=hum then restoreBanana();bananaHum=hum;bananaHip=hum.HipHeight end
			local record
			local ok,err=xpcall(function()
				if tbl8.GucciAntiGrab then
					record={char=char,hum=hum};bananaSuspension=record
					tbl12.SetGucciAntiGrab(false);task.wait(0.25)
				end
				if not tbl8.AntiBanana or not Hub.alive or flag11 or Player.Character~=char
					or hum.Parent~=char or hum.Health<=0 or (record and bananaSuspension~=record) then return end
				hum.Sit=false;hum.HipHeight=2
				tbl12.BreakLimb(Player,"Legs")
				local deadline=os.clock()+0.75
				repeat
					if not tbl8.AntiBanana or not Hub.alive or Player.Character~=char or hum.Health<=0 or not leg.Parent then break end
					hum.HipHeight=2;task.wait()
				until os.clock()>=deadline
			end,debug.traceback)
			releaseBananaGucci(record)
			if not ok then error(err,0) end
		end,restoreBanana)
```

## Plot/slot: verified character root

Original lines 10038–10047. Start at `local function selfRoot()`. Stop immediately before `local function ownerIsSelf` (leave that boundary intact).

```lua
		local function gucciEnabled()
			local toggle=Toggles.AutoGucciBlobToggle
			return toggle and toggle.Value==true
		end
		local function selfRoot()
			local char=Player.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if gucciEnabled() then
				local controller,proof=Hub.sourceGucci,Hub.gucciVerifiedRun
				if not controller or not controller.state.GucciAntiGrab or not proof or not proof.Confirmed
					or proof.Char~=char or proof.Hum~=hum or proof.HRP~=root then return end
				root=proof.HRP
			end
			local held=Player:FindFirstChild("IsHeld")
			if not root or not hum or hum.Health<=0 or hum.SeatPart or root.Anchored
				or (held and held.Value) or Hub.safeZoneLoopActive or Hub.blobFlightActive or Hub.characterFlightActive then return end
			for _,run in pairs(Hub.targetLoopRuns or {}) do if run.enabled then return end end
			return root,char
		end
```

## Plot/slot: wait, visit, and return

Original lines 10060–10099. Start at `local function finish(ticket)`. Stop immediately before `local function request(part,root)` (leave that boundary intact).

```lua
		local function finish(ticket)
			if active~=ticket then return end
			active=nil
			if Hub.interactionVisitLock==ticket then Hub.interactionVisitLock=nil end
			local root,hum=ticket.root,ticket.hum
			-- Return even if Gucci lost confirmation during the interaction; never move a new character.
			if ticket.moved and Player.Character==ticket.char and root.Parent==ticket.char
				and hum.Parent==ticket.char and hum.Health>0 and not hum.SeatPart and not root.Anchored then
				local ok,err=pcall(function()
					root.CFrame=ticket.original
					root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
				end)
				if not ok then warn("[Plots & slots return] "..tostring(err)) end
			end
		end
		local function visit(kind,part,allowed,action)
			if active or Hub.interactionVisitLock then return false,"Another movement interaction is running." end
			local char=Player.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health<=0 then return false,"Waiting for a live character." end
			if not part or not part.Parent or not part:IsA("BasePart") then return false,"Interaction part has not loaded." end
			local ticket={kind=kind,root=root,char=char,hum=hum,original=root.CFrame,gucci=gucciEnabled()}
			active=ticket;Hub.interactionVisitLock=ticket
			status:SetText(kind..(ticket.gucci and ": waiting for verified Gucci confirmation." or ": preparing visit."))
			task.spawn(function()
				local function pending()
					return Hub.alive and active==ticket and allowed() and Player.Character==char
						and root.Parent==char and hum.Parent==char and hum.Health>0 and part.Parent
						and (not ticket.gucci or gucciEnabled())
				end
				local function valid()
					return pending() and selfRoot()==root and (root.Position-ticket.destination).Magnitude<12
				end
				local ok,err=pcall(function()
					local deadline=os.clock()+20
					while pending() and selfRoot()~=root do
						if not ticket.gucci then error("Character busy: leave seats/holds and stop flight, safe-zone or action loops.",0) end
						if os.clock()>=deadline then error("Gucci confirmation timed out; no interaction performed.",0) end
						task.wait(0.1)
					end
					if not pending() or selfRoot()~=root then return end
					local destination=(root.Position-part.Position).Magnitude>25 and part.Position+Vector3.new(0,3,6) or root.Position
					if kind=="House renewal" then destination=part.Position+Vector3.new(0,3,0) end
					for _,value in ipairs({destination.X,destination.Y,destination.Z}) do
						if value~=value or math.abs(value)==math.huge then error("Invalid interaction position.",0) end
					end
					if destination.Y<=Workspace.FallenPartsDestroyHeight+8 then error("Destination is below the safe map height.",0) end
					ticket.destination=destination;ticket.moved=true
					status:SetText(kind..": visiting; will return when finished.")
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
```

## Slot selection: permit pending Gucci setup

Original lines 10149–10149. Start at `local root=selfRoot();if not root then return false,"Character busy: stop flight/loops and leave seats first." end`. Stop immediately before `local slots=` (leave that boundary intact).

```lua
			-- Used only to rank machines; visit() waits for the verified Gucci HRP before moving.
			local char=Player.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			if not root then return false,"Waiting for a live character." end
```

## Saving behavior

`Hub.flushSettings(explicit)` forwards only `explicit == true`. `:save` passes `true`. The UI Save settings callback already passes `true` directly to `Hub.persistSettings` and is unchanged. `Player.OnTeleport` still calls `Hub.flushSettings()` without an explicit flag. Automatic saves, unload saves, and teleport saves preserve `Hub.configLoadFailed`; an intentional manual save can replace the unreadable config.

## Automated verification

The entire resulting script compiled with the Luau compiler in luau-web. Mocked Luau regression checks passed for failed-load save protection, explicit flag handling, Anti Banana cancellation, errors, user disabling Gucci, character replacement, and repeated cleanup. Visit checks passed for verified HRP gating, waiting for confirmation, successful interaction and return, timeout, interaction error and return, and cancellation before movement. Preservation assertions verified the complete spawner/controller and final callback regions are unchanged, including all seven seat/character event-handler pairs and the train/RunService code. Shutdown remains absent. `git diff --check` passed.

## Requires in-game verification

These checks do not prove Roblox replication, server acknowledgments, or physical behavior. Test Blobman and Train Gucci setup; invoke plot claim, house renewal, and slot spin while Gucci is starting and after confirmation; verify the request is accepted, you return, and Gucci stays enabled. Cancel Anti Banana during its 0.25-second pause and during limb handling, disable Gucci manually, and respawn during the pause. Verify cleanup resumes only for the same live character when the user still has Gucci enabled. With an unreadable config, confirm teleport/autosave leave the file intact and explicit Save settings / :save can deliberately replace it.
