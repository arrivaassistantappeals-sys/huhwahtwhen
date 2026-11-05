-- Arriva Core Hub 2.5.
-- Packet/Line Lag flooders removed. Gameplay features retain their original scope.
local Hub = {alive = true, connections = {}, threads = {}, cleanups = {}, ready = false}
Hub.env = (getgenv and getgenv()) or shared or _G
if type(Hub.env.ArrivaCoreStarting)=="number" and os.clock()-Hub.env.ArrivaCoreStarting>=0 and os.clock()-Hub.env.ArrivaCoreStarting<8 then
	warn("[Arriva] A startup is already running, wait before executing again.");return
end
Hub.env.ArrivaCoreStarting=os.clock()
Hub.startupBegan=os.clock()
if Hub.env.ArrivaCoreMaintenance then
	pcall(Hub.env.ArrivaCoreMaintenance)
end
Hub.instances = setmetatable({}, {__mode = "k"})
Hub.assetTargets = setmetatable({}, {__mode = "k"})
function Hub.new(class, parent)
	local instance = Instance.new(class)
	Hub.instances[instance] = true
	if parent then Hub.assetTargets[instance] = parent end
	if parent then instance.Parent = parent end
	return instance
end
Hub.propertyBackup = {}
function Hub.backup(instance, properties)
	local saved = Hub.propertyBackup[instance]
	if not saved then saved = {}; Hub.propertyBackup[instance] = saved end
	for _, property in ipairs(properties) do
		if saved[property] == nil then saved[property] = instance[property] end
	end
end
function Hub.restore(instance)
	local saved = Hub.propertyBackup[instance]
	if not saved then return end
	for property, value in pairs(saved) do pcall(function() instance[property] = value end) end
	Hub.propertyBackup[instance] = nil
end
Hub.nativeTask = task
local task = setmetatable({}, {__index = Hub.nativeTask})
function Hub.schedule(method, delay, callback, ...)
	if not Hub.alive then return nil end
	local args = table.pack(...)
	local thread = coroutine.create(function()
		local ok, err = xpcall(function() callback(table.unpack(args, 1, args.n)) end, debug.traceback)
		Hub.threads[coroutine.running()] = nil
		if not ok and Hub.alive then Hub.lastWorkerError=tostring(err);warn("[Arriva] " .. tostring(err)) end
	end)
	Hub.threads[thread] = true
	if method == "delay" then Hub.nativeTask.delay(delay, thread)
	else Hub.nativeTask[method](thread) end
	return thread
end
function task.spawn(callback, ...) return Hub.schedule("spawn", nil, callback, ...) end
function task.defer(callback, ...) return Hub.schedule("defer", nil, callback, ...) end
function task.delay(delay, callback, ...) return Hub.schedule("delay", delay, callback, ...) end
function Hub.connect(signal, callback)
	local connection = signal:Connect(function(...)
		if not Hub.alive then return end
		local args = table.pack(...)
		local thread = coroutine.running()
		Hub.threads[thread] = true
		local ok, err = xpcall(function() callback(table.unpack(args, 1, args.n)) end, debug.traceback)
		Hub.threads[thread] = nil
		if not ok and Hub.alive then Hub.lastCallbackError=tostring(err);warn("[Arriva callback] " .. tostring(err)) end
	end)
	Hub.connections[connection] = true
	return connection
end
function Hub.cleanup(callback) table.insert(Hub.cleanups, callback) end
-- Coalesce repeated roster UI changes without delaying protective decisions.
Hub.pendingRefreshes={}
function Hub.queueRefresh(key,callback)
	if Hub.pendingRefreshes[key] then return end
	Hub.pendingRefreshes[key]=true
	task.delay(0.15,function()
		Hub.pendingRefreshes[key]=nil
		if Hub.alive then callback() end
	end)
end
Hub.cleanup(function() table.clear(Hub.pendingRefreshes) end)
-- Enumerate incrementally so initial protection scans do not build one giant array.
function Hub.scanDescendants(root,visit,valid)
	return task.spawn(function()
		local queue={root};local first,last=1,1
		while first<=last and Hub.alive and valid() do
			local deadline=os.clock()+0.001
			local count=0
			repeat
				local object=queue[first];queue[first]=nil;first+=1
				if object and (object==root or object.Parent) then
					if object~=root then visit(object) end
					for _,child in ipairs(object:GetChildren()) do last+=1;queue[last]=child end
				end
				count+=1
			until first>last or count>=128 or os.clock()>=deadline or not valid()
			if first<=last then task.wait() end
		end
	end)
end

function Hub.stop()
	if not Hub.alive then return end
	if Hub.ready and Hub.storage and Hub.saveManager then
		local ok, err = pcall(Hub.persistSettings)
		if not ok then warn("[Arriva cleanup save] " .. tostring(err)) end
	end
	Hub.alive = false
	for connection in pairs(Hub.connections) do pcall(function() connection:Disconnect() end) end
	for thread in pairs(Hub.threads) do
		if thread ~= coroutine.running() then pcall(Hub.nativeTask.cancel, thread) end
	end
	for i = #Hub.cleanups, 1, -1 do pcall(Hub.cleanups[i]) end
	for instance in pairs(Hub.propertyBackup) do Hub.restore(instance) end
	for instance in pairs(Hub.instances) do pcall(function() instance:Destroy() end) end
	_G.AntiInputLag = false; _G.ShurikenAntiKick = false
	table.clear(Hub.connections); table.clear(Hub.threads)
	if Hub.env.ArrivaCoreMaintenance == Hub.unload then
		Hub.env.ArrivaCoreMaintenance = nil
		Hub.env.ArrivaCoreStarting = nil
	end
end
-- Track setup for diagnostics. Only Anti Banana leg removal delays Gucci.
Hub.protectionStartupJobs={}
function Hub.applyControl(control,value,invoke)
	local finish=Hub.beginProtectionChange and Hub.beginProtectionChange(control)
	local ok,err=invoke(control.Callback,value)
	if finish then finish() end
	return ok,err
end
-- Restore passive settings first; Gucci requests are independent of unrelated setup.
function Hub.queueSavedCallbacks(records,invoke)
	Hub.restoreEpoch=(Hub.restoreEpoch or 0)+1
	local ticket=Hub.restoreEpoch
	local delayed,gucci={},{}
	local immediate={AntiLagToggle=true,SourceAntiKickHighlight=true,SourceAntiKickRainbowFill=true,SourceAntiKickRainbowOutline=true}
	local progress={total=#records,started=0,completed=0,failed=0,skipped=0,done=#records==0,errors={}}
	Hub.restoreProgress=progress
	local function run(record)
		if not Hub.alive or ticket~=Hub.restoreEpoch then return end
		local control=record.control
		if control.revision~=record.revision then progress.skipped+=1
		else
			progress.started+=1;Hub.lastRestoreControl=control.Id or "saved control"
			local ok,err=Hub.applyControl(control,record.value,invoke)
			if ok==false then progress.failed+=1;progress.errors[control.Id or "saved control"]=tostring(err) end
		end
		progress.completed+=1;progress.done=progress.completed==progress.total
	end
	for _,record in ipairs(records) do
		local id=record.control.Id
		if id=="AutoGucciBlobToggle" or id=="AutoGucciTrainToggle" then table.insert(gucci,record)
		elseif record.control.Type=="Toggle" and record.value==true and not immediate[id] then table.insert(delayed,record)
		else task.defer(function() run(record) end) end
	end
	table.sort(gucci,function(a,b) return a.control.Id<b.control.Id end)
	-- Passive settings are already deferred above. Gucci can request startup independently;
	-- its own guard waits only for Anti Banana's actual leg-removal pass.
	for _,record in ipairs(gucci) do task.defer(function() run(record) end) end
	task.spawn(function()
		if #delayed>0 then
			local setting=Hub.library and Hub.library.Options.StartupFeatureDelay
			task.wait(math.clamp(tonumber(setting and setting.Value) or 3,0,10))
			for _,record in ipairs(delayed) do
				if not Hub.alive or ticket~=Hub.restoreEpoch then return end
				task.spawn(function() run(record) end);task.wait(0.1)
			end
		end

	end)
end

-- Notification preferences and history are shared by all notification entry points.
Hub.noticePreferences={enabled=true,events={},templates={}}
Hub.noticeHistory={}
function Hub.formatEventText(template,values)
	return (tostring(template):sub(1,512):gsub("%%([%a]+)%%",function(key)
		local value=values[key]
		return value~=nil and tostring(value) or ("%"..key.."%")
	end))
end
function Hub.profileName(value)
	value=tostring(value or ""):match("^%s*(.-)%s*$")
	if #value<1 or #value>40 or not value:match("^[%w _%-]+$") then
		return nil,"Use 1–40 letters, numbers, spaces, underscores or hyphens."
	end
	if value:lower()=="autosave" then return nil,"AutoSave is reserved for your automatic settings." end
	return value
end
-- Shared event classification keeps event visuals and sounds consistent.
function Hub.notificationEvent(info)
	local explicit=tostring(info.Type or info.Kind or ""):lower()
	local events={join=true,leave=true,respawn=true,blackhole=true,kick=true}
	if events[explicit] then return explicit end
	if explicit~="" and explicit~="info" then return nil end
	local title=tostring(info.Title or ""):lower()
	local content=tostring(info.Description or info.Content or ""):lower()
	if (title=="player kicked" or title=="player kicked preview")
		and (content:find("blackhole",1,true) or content:find("black hole",1,true)) then return "blackhole" end
	if title=="player kicked" or title=="player kicked preview" then return "kick" end
	if title=="player joined" or title=="player rejoined" or title=="selected player returned"
		or title:match("^target returned!") then return "join" end
	if title=="player left" or title=="selected player left" then return "leave" end
	if title=="character respawned" or title=="player respawned" or title=="target respawned"
		or title=="selected player respawned" then return "respawn" end
end

function Hub.fetch(url)
	local ok, value = pcall(function()
		local fn, err = loadstring(game:HttpGet(url))
		assert(fn, err)
		return fn()
	end)
	assert(ok, "[Arriva dependency] " .. url .. ": " .. tostring(value))
	return value
end
-- SETTINGS PERSISTENCE CORE
function Hub.canonical(value)
	local kind = type(value)
	if kind == "table" then
		local entries = {}
		for key, item in pairs(value) do
			table.insert(entries, Hub.canonical(key) .. Hub.canonical(item))
		end
		table.sort(entries)
		return "T" .. table.concat(entries, "|") .. ";"
	end
	local text = tostring(value)
	return kind:sub(1, 1) .. #text .. ":" .. text
end
function Hub.captureSettings()
	if not Hub.saveManager then return nil, "Save manager is unavailable" end
	local ok, content, success, err = pcall(function() return Hub.saveManager:SaveJSON("AutoSave") end)
	if not ok then return nil, tostring(content) end
	if not success then return nil, tostring(err) end
	local decoded, data = pcall(function() return game:GetService("HttpService"):JSONDecode(content) end)
	if not decoded then return nil, tostring(data) end
	data.timestamp = nil -- A clock change is not a settings change.
	if type(data.objects) == "table" then
		table.sort(data.objects, function(a, b)
			return tostring(a.tabIdx or "") .. ":" .. tostring(a.idx) < tostring(b.tabIdx or "") .. ":" .. tostring(b.idx)
		end)
	end
	return Hub.canonical(data)
end
function Hub.persistSettings(explicit)
	if Hub.configLoading then
		return false,"Settings are still loading. Wait for loading to finish, then try again."
	end
	if explicit then Hub.configLoadFailed=false end
	if Hub.configLoadFailed then
		Hub.lastSaveError="Autosave paused to protect an unreadable settings file. Use Save settings to replace it deliberately."
		return false,Hub.lastSaveError
	end
	if not Hub.storage or not Hub.saveManager then
		Hub.lastSaveError = "File storage is unavailable"
		return false, Hub.lastSaveError
	end
	local ok, success, err = pcall(function() return Hub.saveManager:Save("AutoSave") end)
	if not ok or not success then
		Hub.lastSaveError = tostring(ok and err or success)
		return false, Hub.lastSaveError
	end
	Hub.lastSaveError = nil
	Hub.lastSaveAt = os.date("%H:%M:%S")
	Hub.lastSettings = Hub.captureSettings()
	return true
end
function Hub.pollSettings()
	if not Hub.ready or not Hub.storage then return end
	local fingerprint, err = Hub.captureSettings()
	if not fingerprint then
		if Hub.lastSnapshotError ~= err then warn("[Arriva settings] " .. tostring(err)) end
		Hub.lastSnapshotError = err
		return
	end
	Hub.lastSnapshotError = nil
	if fingerprint ~= Hub.lastSettings then
		Hub.requestSave()
	end
end
function Hub.requestSave()
	if not Hub.ready or not Hub.storage or Hub.configLoading or Hub.configLoadFailed then return end
	if Hub.saveThread then pcall(Hub.nativeTask.cancel, Hub.saveThread); Hub.threads[Hub.saveThread] = nil end
	Hub.saveThread = task.delay(0.25, function()
		Hub.saveThread = nil
		local ok, err = Hub.persistSettings()
		if not ok then warn("[Arriva autosave] " .. tostring(err)) end
	end)
end
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
function Hub.installConfigLoading(saveManager)
	local original = saveManager.LoadJSON
	saveManager:SetLoadingOrder(false)
	saveManager.LoadJSON = function(self, content)
		local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(content) end)
		if not ok or type(data) ~= "table" or type(data.objects) ~= "table" then
			return original(self, content)
		end
		local function rank(option)
			if option.idx == "ThemeManager_ThemeList" then return 0 end
			if option.idx == "ThemeManager_CustomThemeList" then return 1 end
			if option.type == "Dropdown" then return 10 end
			if option.type == "Slider" or option.type == "Input" or option.type == "KeyPicker" then return 20 end
			if option.type == "ColorPicker" then return 30 end
			if option.idx == "WhitelistFriends" then return 35 end
			if option.type == "Toggle" then return 40 end
			return 25
		end
		table.sort(data.objects, function(a, b)
			local ar, br = rank(a), rank(b)
			if ar ~= br then return ar < br end
			return tostring(a.idx) < tostring(b.idx)
		end)
		local encoded, result = pcall(function() return game:GetService("HttpService"):JSONEncode(data) end)
		if not encoded then return false, tostring(result) end
		return original(self, result)
	end
end
-- END SETTINGS PERSISTENCE CORE

--=====================================================
-- ARRIVA CORE HUB – OWNER COMMAND CORE (ALWAYS FIRST)
--=====================================================

--// Services
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local workspaceService = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Workspace = workspace

--// Player
local LocalPlayer = Players.LocalPlayer

-- BEGIN SHARED TELEPORT MASK
-- Script-owned teleport writes go through here; ordinary movement and Z stay native.
do
	local state
	local enabled=true
	Hub.teleportMaskCancelers={}
	function Hub.teleportMaskEnabled() return enabled end
	function Hub.cancelNativeTeleportMasks() for _,cancel in pairs(Hub.teleportMaskCancelers) do pcall(cancel) end end
	local renderName="ArrivaSharedTeleportMask"
	local function current(record)
		return record and LocalPlayer.Character==record.char and record.root.Parent==record.char
			and record.head.Parent==record.char and record.hum.Parent==record.char and record.hum.Health>0
	end
	function Hub.clearTeleportMask(commit)
		local old=state;state=nil;Hub.teleportMaskState=nil
		RunService:UnbindFromRenderStep(renderName)
		if old and old.physics then old.physics:Disconnect();Hub.connections[old.physics]=nil end
		if current(old) then
			local frame=commit and old.destination or old.visualRoot
			old.root.CFrame=frame;old.head.CFrame=frame*old.headOffset
		end
	end
	function Hub.teleportFrame(part)
		if state and current(state) and part==state.root then return state.destination end
		return part.CFrame
	end
	function Hub.teleportPart(part,frame)
		if not part then return end
		local char=LocalPlayer.Character
		local root=char and (char:FindFirstChild("realHrp") or char:FindFirstChild("HumanoidRootPart"))
		local head=char and char:FindFirstChild("Head")
		local hum=char and char:FindFirstChildOfClass("Humanoid")
		if not enabled or part~=root or not head or not hum or hum.Health<=0 then part.CFrame=frame;return end
		if state and not current(state) then Hub.clearTeleportMask(false) end
		if state and (frame.Position-state.origin.Position).Magnitude<0.05 then Hub.clearTeleportMask(false);part.CFrame=frame;return end
		if not state and (frame.Position-root.Position).Magnitude<0.05 then part.CFrame=frame;return end
		if not state then
			local record={char=char,root=root,head=head,hum=hum,origin=root.CFrame,visualRoot=root.CFrame,
				visualHead=head.CFrame,headOffset=root.CFrame:ToObjectSpace(head.CFrame),destination=frame}
			state=record;Hub.teleportMaskState=record
			RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value-1,function()
				if state~=record then return end
				if not current(record) then Hub.clearTeleportMask(false);return end
				if Hub.gucciAcquiring==record.char then return end
				record.root.CFrame=record.visualRoot;record.head.CFrame=record.visualHead
			end)
			record.physics=Hub.connect(RunService.Heartbeat,function()
				if state~=record then return end
				if not current(record) then Hub.clearTeleportMask(false);return end
				if Hub.gucciAcquiring==record.char then return end
				-- Preserve ordinary walking while separating it from explicit teleports.
				if not record.pendingWrite and (record.root.Position-record.visualRoot.Position).Magnitude<10 then
					local delta=record.visualRoot:ToObjectSpace(record.root.CFrame)
					record.destination=record.destination*delta
					record.visualRoot=record.root.CFrame;record.visualHead=record.head.CFrame
				end
				record.pendingWrite=false
				-- Same heartbeat/render split as Resonance's ownership helper.
				record.root.CFrame=record.destination;record.head.CFrame=record.destination*record.headOffset
			end)
		end
		state.destination=frame;state.pendingWrite=true
		part.CFrame=frame
	end
	function Hub.teleportModel(model,frame)
		if model~=LocalPlayer.Character then model:PivotTo(frame);return end
		local root=model:FindFirstChild("realHrp") or model:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local destination=frame*model:GetPivot():ToObjectSpace(root.CFrame)
		Hub.teleportPart(root,destination);model:PivotTo(frame)
	end
	function Hub.setTeleportMaskEnabled(on) enabled=on==true;if not enabled then Hub.clearTeleportMask(true) end end
	Hub.connect(LocalPlayer.CharacterRemoving,function() Hub.clearTeleportMask(false) end)
	Hub.cleanup(function() Hub.clearTeleportMask(false);Hub.teleportPart=nil;Hub.teleportModel=nil;Hub.teleportFrame=nil end)
end
-- END SHARED TELEPORT MASK

local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
Hub.characterGeneration = 0
Hub.connect(LocalPlayer.CharacterRemoving, function(oldCharacter)
	Hub.characterGeneration += 1
	if character == oldCharacter then character = nil end
end)
Hub.connect(LocalPlayer.CharacterAdded, function(newCharacter)
	Hub.characterGeneration += 1
	character = newCharacter
end)

-- SAFETY WHITELIST CORE (separate from the hub access whitelist)
Hub.manualWhitelist = {}
Hub.friendCache = {}
Hub.friendChecks = {}
Hub.characterOwners = setmetatable({}, {__mode = "k"})
Hub.playerNames = {}
Hub.ownershipBindings = {}
function Hub.trackPlayerOwnership(player)
	if Hub.ownershipBindings[player] then return end
	Hub.playerNames[player.Name]=player
	if player.Character then Hub.characterOwners[player.Character]=player end
	local previous=player.Character
	Hub.ownershipBindings[player]=Hub.connect(player.CharacterAdded,function(char)
		if previous then Hub.characterOwners[previous]=nil end
		previous=char;Hub.characterOwners[char]=player
	end)
end
for _, player in ipairs(Players:GetPlayers()) do Hub.trackPlayerOwnership(player) end
Hub.whitelistFriends = true
Hub.safetyPath = "ArrivaCoreHub/SafetyWhitelist.json"
function Hub.readSafety()
	if not isfile or not readfile then return end
	if not isfile(Hub.safetyPath) then
		-- Migrate the old username labels before SaveManager can reject renamed dropdown values.
		local legacy = "ArrivaCoreHub/Configs/settings/AutoSave.json"
		if not isfile(legacy) then return end
		local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(legacy)) end)
		if ok and type(data) == "table" and type(data.objects) == "table" then
			for _, option in ipairs(data.objects) do
				if option.idx == "MultiWhitelist" and type(option.value) == "table" then
					for label, selected in pairs(option.value) do
						if selected and type(label) == "string" then
							local id = label:match("%[(%d+)%]$")
							local name = label:match("%(@?([^()]*)%)$")
							local player = name and Players:FindFirstChild(name)
							if not id and player then id = tostring(player.UserId) end
							if id then Hub.manualWhitelist[id] = label
							elseif name then Hub.manualWhitelist["name:" .. name:lower()] = label end
						end
					end
				end
			end
		end
		return
	end
	local ok, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(Hub.safetyPath))
	end)
	if ok and type(data) == "table" and type(data.manual) == "table" then
		Hub.manualWhitelist = {}
		for id, label in pairs(data.manual) do
			if type(id) == "string" and type(label) == "string" then Hub.manualWhitelist[id] = label end
		end
	elseif not ok then warn("[Arriva whitelist] Could not read saved whitelist: " .. tostring(data)) end
end
Hub.readSafety()
function Hub.saveSafety()
	if not writefile or not makefolder or not isfolder then return end
	local ok, err = pcall(function()
		if not isfolder("ArrivaCoreHub") then makefolder("ArrivaCoreHub") end
		writefile(Hub.safetyPath, game:GetService("HttpService"):JSONEncode({manual = Hub.manualWhitelist}))
	end)
	if not ok then warn("[Arriva whitelist] Could not save whitelist: " .. tostring(err)) end
end
function Hub.queueSafetySave()
	if Hub.safetySaveThread then pcall(Hub.nativeTask.cancel, Hub.safetySaveThread); Hub.threads[Hub.safetySaveThread] = nil end
	Hub.safetySaveThread = task.delay(0.5, function() Hub.safetySaveThread = nil; Hub.saveSafety() end)
end
function Hub.checkFriend(player)
	if not player or player == LocalPlayer or Hub.friendChecks[player.UserId] then return end
	local userId = player.UserId
	Hub.friendChecks[userId] = true
	task.spawn(function()
		local ok, result = pcall(function() return LocalPlayer:IsFriendsWithAsync(userId) end)
		if player.Parent~=Players then Hub.friendChecks[userId]=nil;return end
		Hub.friendCache[userId] = {friend = ok and result == true, failed = not ok, expires = os.clock() + (ok and 60 or 15)}
		Hub.friendChecks[userId] = nil
		if Hub.reconcileProtection then Hub.reconcileProtection() end
		if not ok then warn("[Arriva whitelist] Friend lookup failed; target stays protected: " .. tostring(result)) end
	end)
end
function Hub.isProtected(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	if player == LocalPlayer then return true end
	if Hub.manualWhitelist[tostring(player.UserId)] or Hub.manualWhitelist["name:" .. player.Name:lower()] then return true end
	if not Hub.whitelistFriends then return false end
	local state = Hub.friendCache[player.UserId]
	if not state or state.expires <= os.clock() then
		Hub.checkFriend(player)
		state = Hub.friendCache[player.UserId]
	end
	-- Do not guess that someone is a nonfriend during a pending or failed lookup.
	if Hub.friendChecks[player.UserId] or not state or state.failed then return true end
	return state.friend
end
function Hub.canHarm(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player ~= LocalPlayer and player.Parent ~= nil and not Hub.isProtected(player)
end
function Hub.playerOf(instance, seen)
	if typeof(instance) ~= "Instance" then return nil end
	seen = seen or {}
	if seen[instance] then return nil end
	seen[instance] = true
	if instance:IsA("Player") then return instance end
	local current = instance
	while current do
		if current.Name == "GrabParts" and current:IsA("Model") then
			local grab = current:FindFirstChild("GrabPart")
			local weld = grab and grab:FindFirstChild("WeldConstraint")
			if weld and weld.Part1 and not weld.Part1:IsDescendantOf(current) then
				local attachedPlayer = Hub.playerOf(weld.Part1, seen)
				if attachedPlayer then return attachedPlayer end
			end
		end
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current) or Hub.characterOwners[current]
			if player then return player end
		end
		if current.Parent == Workspace then
			local name = current.Name:match("^(.-)SpawnedInToys$")
			if name then return Players:FindFirstChild(name) or Hub.playerNames[name] end
		end
		current = current.Parent
	end
	-- GrabParts is outside the character, but its weld identifies the affected player.
	local grab = instance.Name == "GrabParts" and instance:FindFirstChild("GrabPart")
	local weld = grab and grab:FindFirstChild("WeldConstraint")
	if weld and weld.Part1 and not weld.Part1:IsDescendantOf(instance) then return Hub.playerOf(weld.Part1, seen) end
	return nil
end
function Hub.finiteVector(value)
	return typeof(value)=="Vector3" and value.X==value.X and value.Y==value.Y and value.Z==value.Z
		and math.abs(value.X)<math.huge and math.abs(value.Y)<math.huge and math.abs(value.Z)<math.huge
end
function Hub.safeLookAt(startPosition,targetPosition,fallbackDirection)
	if not Hub.finiteVector(startPosition) or not Hub.finiteVector(targetPosition) then return nil end
	local direction=targetPosition-startPosition
	local length=direction.Magnitude
	if length==math.huge then return nil end
	if length<0.000001 then
		direction=Hub.finiteVector(fallbackDirection) and fallbackDirection or Vector3.new(0,0,-1)
		length=direction.Magnitude
		if length<0.000001 or length==math.huge then direction=Vector3.new(0,0,-1);length=1 end
	end
	direction=direction/length
	local up=math.abs(direction.Y)>0.999 and Vector3.new(1,0,0) or Vector3.new(0,1,0)
	return CFrame.lookAlong(startPosition,direction,up)
end
Hub.SafeLookAt=Hub.safeLookAt


-- Keep the existing game-facing basis for ordinary directions. Only replace
-- degenerate inputs; do not rewrite caller-supplied remote CFrames globally.
function Hub.lookAt(startPosition,targetPosition)
	if not Hub.finiteVector(startPosition) or not Hub.finiteVector(targetPosition) then return nil end
	local delta=targetPosition-startPosition
	if delta.Magnitude<0.000001 then return Hub.safeLookAt(startPosition,targetPosition) end
	local direction=delta.Unit
	local right=direction:Cross(Vector3.new(0,1,0))
	if right.Magnitude<0.000001 then return Hub.safeLookAt(startPosition,targetPosition) end
	return CFrame.fromMatrix(startPosition,right,right:Cross(direction))
end
Hub.LookAt=Hub.lookAt
function Hub.canAffect(instance, seen)
	seen = seen or {}
	if typeof(instance) == "Instance" then
		if seen[instance] then return true end
		seen[instance] = true
	end
	-- A drop remote can receive only a weld in our toy; inspect its attached character too.
	if typeof(instance) == "Instance" and (instance:IsA("Weld") or instance:IsA("WeldConstraint")) then
		if instance.Part0 and not Hub.canAffect(instance.Part0, seen) then return false end
		if instance.Part1 and not Hub.canAffect(instance.Part1, seen) then return false end
	end
	local owner = Hub.playerOf(instance)
	return not owner or owner == LocalPlayer or Hub.canHarm(owner)
end
function Hub.reconcileProtection()
	for asset, target in pairs(Hub.assetTargets) do
		if asset:IsA("BodyMover") or asset:IsA("BodyVelocity") or asset:IsA("BodyAngularVelocity") or asset:IsA("BodyGyro") then
			if not Hub.canAffect(target) then pcall(function() asset:Destroy() end) end
		end
	end
	for instance in pairs(Hub.propertyBackup) do
		if not Hub.canAffect(instance) then Hub.restore(instance) end
	end
end
-- Only the setup/acquisition window owns character movement; other toggles stay enabled.
function Hub.gucciCharacterBusy(char)
	return char~=nil and LocalPlayer.Character==char and (Hub.gucciSetupCharacter==char or Hub.gucciAcquiring==char)
end
function Hub.isGucciReserved(instance)
	local run=Hub.gucciVehicleRun
	local vehicle=run and run.Char==LocalPlayer.Character and run.Vehicle or nil
	return instance~=nil and vehicle~=nil and vehicle.Parent~=nil and (instance==vehicle or instance:IsDescendantOf(vehicle))
end

function Hub.remoteAllowed(remote, ...)
	if not remote or not Hub.canAffect(remote) then return false end
	for index = 1, select("#", ...) do
		if not Hub.canAffect((select(index, ...))) then return false end
	end
	return true
end
function Hub.fire(remote, ...)
	if Hub.remoteAllowed(remote, ...) then remote:FireServer(...) end
end
function Hub.invoke(remote, ...)
	if Hub.remoteAllowed(remote, ...) then return remote:InvokeServer(...) end
	return nil
end
Hub.cleanup(function() if Hub.safetySaveThread then Hub.saveSafety() end end)
Hub.connect(Players.PlayerAdded, function(player)
	Hub.trackPlayerOwnership(player)
	if Hub.whitelistFriends then Hub.checkFriend(player) end
	if Hub.refreshWhitelistUI then Hub.queueRefresh("whitelist",Hub.refreshWhitelistUI) end
end)
Hub.connect(Players.PlayerRemoving,function(player)
	local connection=Hub.ownershipBindings[player]
	if connection then connection:Disconnect();Hub.connections[connection]=nil;Hub.ownershipBindings[player]=nil end
	if Hub.playerNames[player.Name]==player then Hub.playerNames[player.Name]=nil end
	if player.Character then Hub.characterOwners[player.Character]=nil end
	Hub.friendCache[player.UserId]=nil
	if Hub.refreshWhitelistUI then Hub.queueRefresh("whitelist",Hub.refreshWhitelistUI) end
end)
-- END SAFETY WHITELIST CORE

--// Owner
local HUB_OWNER_ID = 1325117607

--// Whitelist
local WHITELIST = {
	[1325117607] = "arrivabus415",
	[115211703] = "00FSwedish",
	[9225934804] = "imagine2v1_L",
}

--// Whitelist check
if WHITELIST[LocalPlayer.UserId] == nil then
	LocalPlayer:Kick("Nah not today bruh. find ur own shit to use.")
	return
end

--// Debounce for sysMsg to prevent spam
local lastMessages = {}
local DEBOUNCE_TIME = 0.5

local function sysMsg(text)
	-- Check if this exact message was sent recently
	local now = tick()
	if lastMessages[text] and (now - lastMessages[text]) < DEBOUNCE_TIME then
		return -- Ignore duplicate
	end
	lastMessages[text] = now

	pcall(function()
		local chatVersion = TextChatService.ChatVersion

		if chatVersion == Enum.ChatVersion.TextChatService then
			local channels = TextChatService:FindFirstChild("TextChannels")
			if channels then
				local generalChannel = channels:FindFirstChild("RBXGeneral")
				if generalChannel and generalChannel:IsA("TextChannel") then
					generalChannel:SendAsync(text)
				end
			end
		end
	end)
end

--// Get all whitelisted players currently in-game
--// Get all players currently in-game
local function getAllPlayers()
	return Players:GetPlayers()
end

--// Enhanced player finder
local function findTarget(targetStr)
	if not targetStr then return nil end

	targetStr = targetStr:lower():gsub("^@", "")

	-- "me" = LocalPlayer
	if targetStr == "me" then
		return {LocalPlayer}
	end

	-- "all" = all players
	if targetStr == "all" then
		return getAllPlayers()
	end

	-- Partial match (username or display name)
	local matches = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Name:lower():find(targetStr, 1, true) or plr.DisplayName:lower():find(targetStr, 1, true) then
			table.insert(matches, plr)
		end
	end

	return #matches > 0 and matches or nil
end

--// Actions
local function bringSelfToOwner()
	local owner = Players:GetPlayerByUserId(HUB_OWNER_ID)
	if not owner or not owner.Character then return end

	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local ownerRoot = owner.Character:FindFirstChild("HumanoidRootPart")

	if myRoot and ownerRoot then
		Hub.teleportPart(myRoot, ownerRoot.CFrame * CFrame.new(0, 5, 0))
		sysMsg("Brought to hub owner")
	end
end

local function revealSelf()
	sysMsg("I'm using Arriva Core Hub 2.5!")
end

local function killSelf()
	local char = LocalPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
			sysMsg("You were killed by hub owner")
		end
	end
end

local function kickSelf()
	sysMsg("You were removed by hub owner")
	task.wait(0.5)
	LocalPlayer:Kick("Removed by hub owner")
end

--// Command handler
local function processCommand(speaker, text)
	-- Remote control is opt-in; the hub owner cannot control this client by default.
	if Hub.env.ArrivaAllowOwnerCommands ~= true then return end
	if speaker.UserId ~= HUB_OWNER_ID then return end

	-- Only process messages that start with "!" to prevent loops
	if type(text)~="string" then return end
	text=text:match("^%s*(.-)%s*$")
	if not text:match("^[!:]") then
		return
	end

	local args = {}
	for word in text:gmatch("%S+") do table.insert(args,word) end
	local cmd = args[1] and args[1]:lower():gsub("^:","!")

	if cmd == "!bring" then
		local targetStr = args[2]
		local targets = findTarget(targetStr)

		if targets then
			for _, target in ipairs(targets) do
				if target == LocalPlayer then
					bringSelfToOwner()
					break
				end
			end
		end

	elseif cmd == "!reveal" then
		local targetStr = args[2]
		local targets = findTarget(targetStr)

		if targets then
			for _, target in ipairs(targets) do
				if target == LocalPlayer then
					revealSelf()
					break
				end
			end
		end

	elseif cmd == "!kill" then
		local targetStr = args[2]
		local targets = findTarget(targetStr)

		if targets then
			for _, target in ipairs(targets) do
				if target == LocalPlayer then
					killSelf()
					break
				end
			end
		end

	elseif cmd == "!kick" then
		local targetStr = args[2]
		local targets = findTarget(targetStr)

		if targets then
			for _, target in ipairs(targets) do
				if target == LocalPlayer then
					kickSelf()
					break
				end
			end
		end

	elseif cmd == "!announce" then
		local msg = table.concat(args, " ", 2)
		if msg ~= "" then
			sysMsg("[Hub Owner] " .. msg)
		end
	end
end

-- Owner commands: subscribe without replacing the game's chat formatting callback.
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	Hub.connect(TextChatService.MessageReceived, function(message)
		local speaker = message.TextSource and Players:GetPlayerByUserId(message.TextSource.UserId)
		if speaker then processCommand(speaker, message.Text) end
	end)
else
	local function hookPlayer(plr)
		Hub.connect(plr.Chatted, function(msg) processCommand(plr, msg) end)
	end
	for _, player in ipairs(Players:GetPlayers()) do hookPlayer(player) end
	Hub.connect(Players.PlayerAdded, hookPlayer)
end

print("Arriva Core Hub owner command core loaded")
--=====================================================

-- Main script continues
-- Infinite Yield is available from a manual button below; not auto-loaded.

local Library, SaveManager, ThemeManager
do
	-- Rayfield presentation adapter. Gameplay callbacks remain in the supplied hub.
--[=[
Third-party icon notices (MIT / ISC)
# MIT License

Copyright (c) 2023 Latte Softworks <https://latte.to>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

# Lucide License (ISC)

Lucide Icons (this package's icon sources) are licensed under ISC License. You can view it online directly at <https://lucide.dev/license>.

## ISC License

Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part of Feather (MIT). All other copyright (c) for Lucide are held by Lucide Contributors 2022.

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

]=]
	-- Arriva's custom sidebar presentation. No gameplay or remote operations.
	local function createArrivaSidebar()
		local UI = {Theme = {ToolDark = true}, tabs = {}, keybinds = {}, visible = true}
		local player = game:GetService("Players").LocalPlayer
		local playerService=game:GetService("Players")
		local knownNames={}
		local function rememberPlayer(person)
			local now=os.clock()
			knownNames[string.lower(person.Name)]={name=person.Name,time=now}
			if type(person.DisplayName)=="string" and #person.DisplayName>=3 then
				knownNames[string.lower(person.DisplayName)]={name=person.DisplayName,time=now}
			end
		end
		for _,person in ipairs(playerService:GetPlayers()) do rememberPlayer(person) end
		Hub.connect(playerService.PlayerAdded,rememberPlayer)
		Hub.connect(playerService.PlayerRemoving,rememberPlayer)
		local input = game:GetService("UserInputService")
		local colors = {background = Color3.fromRGB(25,25,25), sidebar = Color3.fromRGB(31,31,31),
			card = Color3.fromRGB(33,33,33), line = Color3.fromRGB(58,58,58),
			text = Color3.fromRGB(237,237,237), muted = Color3.fromRGB(153,153,153),
			blue = Color3.fromRGB(55,104,146), blueLine = Color3.fromRGB(69,137,191)}
		colors.noticeText = Color3.fromRGB(220,224,232)
		-- Lucide image-sprite metadata from SiriusSoftwareLtd/Rayfield icons.lua,
		-- commit 3ef72398fb4c8ba6fd1801e98704991d3cc9cbc2; Lucide icons: ISC license.
		-- Only the assets used here are retained; no icon-library script is fetched.
		local iconAssets = {
			bot={16898612819,869,98}, boxes={16898612819,196,771}, compass={16898613044,514,967},
			heart={16898613509,661,771},
			eye={16898613353,771,563},keyboard={16898613509,453,820},
			terminal={16898613869,820,257},["volume-2"]={16898613869,771,808},
			palette={16898613613,453,918},history={16898613509,869,98},bell={16898612819,820,257},
			activity={16898612629,514,771},["user-round-check"]={16898613869,869,404},
			["door-open"]={16898613044,967,759},["log-out"]={16898613509,820,955},
			["triangle-alert"]={16898613869,967,0},["circle-alert"]={16898612819,918,808},
			["rotate-ccw"]={16898613699,967,355},orbit={16898613613,967,612},info={16898613509,612,869},
			shield={16898613777,869,0}, crosshair={16898613044,453,869}, sparkles={16898613777,918,49},
			hand={16898613509,563,820}, user={16898613869,661,869}, box={16898612819,771,196},
			settings={16898613777,771,257}, search={16898613699,918,857}, check={16898612819,710,869},
			["chevron-down"]={16898612819,196,918}, ["chevron-up"]={16898612819,710,918},
			["chevron-right"]={16898612819,869,759}, minus={16898613613,771,196},
			x={16898613869,869,906}, ["arrow-down-right"]={16898612629,820,661}
		}
		local function make(class, parent, properties)
			local object = Hub.new(class, parent)
			for property, value in pairs(properties or {}) do object[property] = value end
			return object
		end
		local function round(object, radius) make("UICorner", object, {CornerRadius = UDim.new(0,radius or 8)}) end
		local function icon(parent, name, properties)
			local asset = iconAssets[name] or iconAssets.box
			local image = make("ImageLabel",parent,{BackgroundTransparency=1, Image="rbxassetid://" .. asset[1],
				ImageRectSize=Vector2.new(48,48),ImageRectOffset=Vector2.new(asset[2],asset[3]),
				Size=UDim2.fromOffset(20,20),ImageColor3=colors.muted})
			for property,value in pairs(properties or {}) do image[property]=value end
			return image
		end
		local function stroke(object, color, thickness)
			return make("UIStroke", object, {Color = color or colors.line, Thickness = thickness or 1.2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
		end
		local function text(parent, content, properties)
			local object = make("TextLabel", parent, {BackgroundTransparency = 1, Text = tostring(content),
				Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = colors.text,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
			for property, value in pairs(properties or {}) do object[property] = value end
			return object
		end
		local function button(parent, content, properties)
			local object = make("TextButton", parent, {Text = content or "", Font = Enum.Font.GothamBold,
				TextSize = 15, TextColor3 = colors.text, BackgroundTransparency = 1,
				AutoButtonColor = false})
			for property, value in pairs(properties or {}) do object[property] = value end
			return object
		end
		local function emit(callback, value)
			if UI.destroyed or not callback then return end
			local ok, err = pcall(callback, value)
			if not ok then warn("[Arriva menu] " .. tostring(err)) end
		end
		local function padding(parent, amount)
			make("UIPadding", parent, {PaddingLeft=UDim.new(0,amount), PaddingRight=UDim.new(0,amount),
				PaddingTop=UDim.new(0,amount), PaddingBottom=UDim.new(0,amount)})
		end
		local function activate(tab)
			UI.active = tab
			for _, item in ipairs(UI.tabs) do
				item.page.Visible = item == tab
				item.navLabel.TextColor3 = item == tab and colors.text or colors.muted
				item.navLabel.Font = item == tab and Enum.Font.GothamBold or Enum.Font.Gotham
				item.icon.ImageColor3 = item == tab and colors.text or colors.muted
				item.marker.Visible = item == tab
			end
		end
		local function filter()
			local query = UI.search.Text:lower()
			local first
			for _, tab in ipairs(UI.tabs) do
				local any = false
				local sectionMatches = {}
				for _, entry in ipairs(tab.entries) do
					if not entry.section then
						local match = not entry.hidden and (query == "" or (tab.name .. " " .. (entry.group or "") .. " " .. entry.name):lower():find(query,1,true) ~= nil)
						entry.frame.Visible = match and (query~="" or not (tab.collapsedSections and tab.collapsedSections[entry.group]))
						if match then any = true; sectionMatches[entry.group or ""] = true end
					end
				end
				for _, entry in ipairs(tab.entries) do
					if entry.section then
						entry.frame.Visible = query == "" or sectionMatches[entry.name] == true
						if entry.collapsible then
							local collapsed=query=="" and tab.collapsedSections[entry.name]
							entry.frame.Text=(collapsed and "+  " or "−  ")..entry.name
						end
					end
				end
				tab.nav.Visible = query == "" or any
				if tab.nav.Visible and not first then first = tab end
			end
			if UI.active and not UI.active.nav.Visible and first then activate(first) end
		end
		local function registerEntry(tab, frame, name, section)
			local entry = {frame=frame, name=tostring(name), group=tab.section, section=section}
			if not section then entry.controlId=tab.pendingControlId;tab.pendingControlId=nil end
			table.insert(tab.entries, entry)
			if UI.search.Text ~= "" then filter() end
		end
		local function card(tab, name, height)
			local row = button(tab.page, "", {Name = tostring(name), Size=UDim2.new(1,0,0,height or 48),
				BackgroundTransparency=0, BackgroundColor3=colors.card, ClipsDescendants=true})
			round(row,8); stroke(row)
			local title = text(row, name, {Position=UDim2.fromOffset(16,0), Size=UDim2.new(1,-80,0,48),
				Font=Enum.Font.GothamBold, TextSize=15})
			registerEntry(tab,row,name,false)
			return row,title
		end
		local Tab = {}
		function Tab:Show() UI.search.Text="";activate(self);UI:SetVisibility(true) end
		-- BEGIN NAVIGATION METHODS
		function Tab:SetSectionCollapsed(name,collapsed)
			self.collapsedSections=self.collapsedSections or {}
			self.collapsedSections[name]=collapsed==true
			filter()
		end
		function Tab:MoveEntriesTo(target,selectGroup)
			local remaining={}
			for _,entry in ipairs(self.entries) do
				local group=not entry.section and selectGroup(entry)
				if group then
					entry.group=group
					entry.frame.Parent=target.page
					table.insert(target.entries,entry)
				else table.insert(remaining,entry) end
			end
			self.entries=remaining
		end
		-- END NAVIGATION METHODS

		-- Presentation only: preserve control instances, callbacks and saved IDs.
		function Tab:Organize(layout)
			local buckets, order, seen = {}, {}, {}
			for _, title in ipairs(layout.sections) do
				buckets[title]={};table.insert(order,title);seen[title]=true
			end
			local controls={}
			for _, entry in ipairs(self.entries) do
				if entry.section then
					entry.frame:Destroy()
				else
					local title=(layout.controls or {})[entry.controlId] or (layout.names or {})[entry.name]
					if not title and entry.controlId then
						for _,rule in ipairs(layout.prefixes or {}) do
							if entry.controlId:sub(1,#rule[1])==rule[1] then title=rule[2];break end
						end
					end
					title=title or (layout.rename or {})[entry.group] or entry.group or "Other"
					if not seen[title] then
						seen[title]=true;buckets[title]={};table.insert(order,title)
					end
					entry.group=title
					table.insert(buckets[title],entry)
					table.insert(controls,entry)
				end
			end
			self.entries=controls
			local position=0
			for _, title in ipairs(order) do
				local entries=buckets[title]
				if #entries>0 then
					self:CreateSection(title)
					local heading=self.entries[#self.entries]
					if layout.collapsible then
						self.collapsedSections=self.collapsedSections or {}
						if self.collapsedSections[title]==nil then self.collapsedSections[title]=title~=layout.openSection end
						heading.collapsible=true
						local hit=button(heading.frame,"",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
						Hub.connect(hit.Activated,function() self:SetSectionCollapsed(title,not self.collapsedSections[title]) end)
					end
					position+=1;heading.frame.LayoutOrder=position
					local ranks={}
					for index,id in ipairs((layout.order or {})[title] or {}) do ranks[id]=index end
					for index,entry in ipairs(entries) do entry.menuIndex=index end
					table.sort(entries,function(a,b)
						local ar,br=ranks[a.controlId] or 10000,ranks[b.controlId] or 10000
						if ar~=br then return ar<br end
						return a.menuIndex<b.menuIndex
					end)
					for _,entry in ipairs(entries) do
						position+=1;entry.frame.LayoutOrder=position
					end
				end
			end
			self.section=nil
			filter()
		end
		function Tab:CreateSection(name)
			self.section = tostring(name)
			local heading = text(self.page,name,{Size=UDim2.new(1,0,0,40), TextColor3=colors.text,
				TextSize=15,Font=Enum.Font.GothamBold,TextYAlignment=Enum.TextYAlignment.Bottom})
			registerEntry(self,heading,name,true)
			return {Set=function(_, value) heading.Text=tostring(value) end}
		end
		function Tab:CreateLabel(value)
			local label = text(self.page,value,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
				TextColor3=colors.text,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,
				TextYAlignment=Enum.TextYAlignment.Top,TextSize=14,LineHeight=1.2})
			make("UIPadding",label,{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,2)})
			make("UISizeConstraint",label,{MinSize=Vector2.new(0,30)})
			registerEntry(self,label,value,false)
			return {Set=function(_, content) label.Text=tostring(content) end}
		end
		function Tab:CreateButton(info)
			local row = card(self,info.Name)
			icon(row,"chevron-right",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-15,0.5,0)})
			Hub.connect(row.Activated,function() emit(info.Callback) end)
			return {Set=function(_, value) row.Name=tostring(value) end}
		end
		function Tab:CreateToggle(info)
			local row = card(self,info.Name)
			local box = make("Frame",row,{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,0),
				Size=UDim2.fromOffset(30,30),BackgroundColor3=colors.line})
			round(box,7);stroke(box,colors.sidebar,2)
			local check = icon(box,"check",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ImageColor3=colors.text})
			local handle = {CurrentValue=info.CurrentValue == true}
			function handle:Set(value)
				self.CurrentValue = value == true
				check.Visible = self.CurrentValue
				emit(info.Callback,self.CurrentValue)
			end
			check.Visible = handle.CurrentValue
			Hub.connect(row.Activated,function() handle:Set(not handle.CurrentValue) end)
			return handle
		end
		function Tab:CreateSlider(info)
			local row = card(self,info.Name,80)
			local track = make("Frame",row,{Position=UDim2.fromOffset(15,40),Size=UDim2.new(1,-30,0,32),
				BackgroundColor3=colors.sidebar,ClipsDescendants=true,Active=true})
			round(track,7);stroke(track,colors.blueLine)
			local fill = make("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=colors.blue,BorderSizePixel=0,Active=true})
			round(fill,7)
			local field = make("TextBox",track,{BackgroundTransparency=1,Position=UDim2.fromOffset(12,0),
				Size=UDim2.new(0,80,1,0),TextXAlignment=Enum.TextXAlignment.Left,TextColor3=colors.text,
				TextSize=15,Font=Enum.Font.GothamBold,ClearTextOnFocus=false})
			local handle = {CurrentValue=info.CurrentValue}
			local increment = info.Increment or 1
			local decimals = math.clamp(math.ceil(-math.log(increment)/math.log(10)-0.00001),0,4)
			local function render(value)
				fill.Size=UDim2.fromScale((value-info.Range[1])/math.max(info.Range[2]-info.Range[1],0.00001),1)
				field.Text=string.format("%." .. string.format("%d",decimals) .. "f",value)
			end
			function handle:Set(value)
				self.CurrentValue=math.clamp(tonumber(value) or self.CurrentValue,info.Range[1],info.Range[2])
				render(self.CurrentValue);emit(info.Callback,self.CurrentValue)
			end
			render(handle.CurrentValue)
			Hub.connect(field.FocusLost,function() handle:Set(tonumber(field.Text) or handle.CurrentValue) end)
			local function fromPointer(position)
				local alpha=math.clamp((position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
				local raw=info.Range[1]+(info.Range[2]-info.Range[1])*alpha
				local value=math.clamp(info.Range[1]+math.floor((raw-info.Range[1])/increment+0.5)*increment,info.Range[1],info.Range[2])
				if value~=handle.CurrentValue then handle:Set(value) end
			end
			Hub.connect(track.InputBegan,function(event)
				if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
					UI.pointerAction=fromPointer;fromPointer(event.Position)
				end
			end)
			-- Edit the value directly or drag on the remaining bar area.
			Hub.connect(fill.InputBegan,function(event)
				if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
					UI.pointerAction=fromPointer;fromPointer(event.Position)
				end
			end)
			return handle
		end
		function Tab:CreateDropdown(info)
			local row,title = card(self,info.Name)
			title.Size=UDim2.new(0.52,-16,0,48)
			local selected = text(row,"None",{Position=UDim2.new(0.52,0,0,0),Size=UDim2.new(0.48,-45,0,48),
				TextXAlignment=Enum.TextXAlignment.Right,TextColor3=colors.muted,TextSize=14})
			local arrow = icon(row,"chevron-down",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(1,-34,0,24)})
			local list = make("ScrollingFrame",row,{Position=UDim2.fromOffset(8,48),Size=UDim2.new(1,-16,0,0),
				BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),
				AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false})
			make("UIListLayout",list,{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder})
			local handle = {Options=info.Options,CurrentOption=table.clone(info.CurrentOption or {}),open=false,connections={},row=row,list=list}
			local optionButtons={}
			local function collapse()
				handle.open=false;row.Size=UDim2.new(1,0,0,48);list.Visible=false;arrow.Rotation=0
			end
			local function render()
				selected.Text=#handle.CurrentOption==0 and "None" or (#handle.CurrentOption==1 and handle.CurrentOption[1] or (#handle.CurrentOption .. " selected"))
				for name,option in pairs(optionButtons) do
					local checked=table.find(handle.CurrentOption,name)~=nil
					option.Text=(checked and " •  " or "    ") .. name
					option.TextColor3=checked and colors.text or colors.muted
				end
			end
			function handle:Set(value)
				if type(value)=="string" then value={value} end
				self.CurrentOption={}
				for _,name in ipairs(value or {}) do if table.find(self.Options,name) then table.insert(self.CurrentOption,name) end end
				render();emit(info.Callback,table.clone(self.CurrentOption))
			end
			function handle:Refresh(values)
				local savedScroll=list.CanvasPosition
				local unchanged=self.built and #values==#self.Options
				if unchanged then for index,value in ipairs(values) do if value~=self.Options[index] then unchanged=false;break end end end
				if unchanged then render();return end
				self.optionConnections=self.optionConnections or {}
				local wanted={};for _,name in ipairs(values) do wanted[name]=true end
				for name,option in pairs(optionButtons) do
					if not wanted[name] then
						local c=self.optionConnections[name]
						if c then c:Disconnect();Hub.connections[c]=nil end
						self.optionConnections[name]=nil;optionButtons[name]=nil;option:Destroy()
					end
				end
				self.Options=table.clone(values);self.built=true
				if not self.clearButton then
					self.clearButton=button(list,"    Clear selection",{Size=UDim2.new(1,-4,0,30),TextColor3=colors.muted,TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,LayoutOrder=0})
					table.insert(self.connections,Hub.connect(self.clearButton.Activated,function() self:Set({});collapse() end))
				end
				for index,name in ipairs(self.Options) do
					local option=optionButtons[name]
					if not option then
						option=button(list,"    "..name,{Size=UDim2.new(1,-4,0,30),TextXAlignment=Enum.TextXAlignment.Left,TextSize=14})
						optionButtons[name]=option
						self.optionConnections[name]=Hub.connect(option.Activated,function()
							if info.MultipleOptions then
								local choices=table.clone(self.CurrentOption);local i=table.find(choices,name)
								if i then table.remove(choices,i) else table.insert(choices,name) end
								self:Set(choices)
							else self:Set({name});collapse() end
						end)
					end
					option.LayoutOrder=index
				end
				if self.open then
					local height=math.min((#self.Options+1)*33,180)
					list.Size=UDim2.new(1,-16,0,height);row.Size=UDim2.new(1,0,0,60+height)
				else collapse() end
				if savedScroll then list.CanvasPosition=savedScroll end
				render()
			end
			handle:Refresh(handle.Options)
			Hub.connect(row.Activated,function()
				if handle.open then collapse();return end
				handle.open=true
				local height=math.min((#handle.Options+1)*33,180)
				list.Size=UDim2.new(1,-16,0,height);list.Visible=true
				row.Size=UDim2.new(1,0,0,60+height);arrow.Rotation=180
			end)
			return handle
		end
		function Tab:CreateInput(info)
			local row = card(self,info.Name,80)
			local field=make("TextBox",row,{Position=UDim2.fromOffset(15,40),Size=UDim2.new(1,-30,0,32),
				BackgroundColor3=colors.sidebar,TextColor3=colors.text,PlaceholderColor3=colors.muted,
				Font=Enum.Font.Gotham,TextSize=15,Text=info.CurrentValue or "",PlaceholderText=info.PlaceholderText or "Enter text",
				ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left})
			round(field,7);stroke(field);padding(field,8)
			local handle={CurrentValue=field.Text}
			function handle:Set(value) self.CurrentValue=tostring(value or "");field.Text=self.CurrentValue;emit(info.Callback,self.CurrentValue) end
			Hub.connect(field.FocusLost,function() handle:Set(field.Text) end)
			if tostring(info.Name):find("HEX",1,true) then
				field.Size=UDim2.new(1,-76,0,32)
				local swatch=button(row,"",{Position=UDim2.new(1,-48,0,40),Size=UDim2.fromOffset(32,32)})
				round(swatch,7);stroke(swatch)
				local panel=make("Frame",row,{BackgroundTransparency=1,Position=UDim2.fromOffset(15,88),
					Size=UDim2.new(1,-30,0,150),Visible=false})
				local sv=make("Frame",panel,{Size=UDim2.new(1,-32,1,0),Active=true,BorderSizePixel=0})
				local white=make("Frame",sv,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0})
				make("UIGradient",white,{Transparency=NumberSequence.new(0,1)})
				local black=make("Frame",sv,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0})
				make("UIGradient",black,{Rotation=90,Transparency=NumberSequence.new(1,0)})
				local marker=make("Frame",sv,{AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(8,8),BackgroundTransparency=1,ZIndex=4})
				round(marker,8);stroke(marker,Color3.new(1,1,1),2)
				local hue=make("Frame",panel,{Position=UDim2.new(1,-20,0,0),Size=UDim2.new(0,20,1,0),BackgroundColor3=Color3.new(1,1,1),Active=true,BorderSizePixel=0})
				local keys={}
				for i=0,6 do table.insert(keys,ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1))) end
				make("UIGradient",hue,{Rotation=90,Color=ColorSequence.new(keys)})
				local h,s,v=0,0,1
				local function render()
					swatch.BackgroundColor3=Color3.fromHSV(h,s,v)
					sv.BackgroundColor3=Color3.fromHSV(h,1,1)
					marker.Position=UDim2.fromScale(s,1-v)
				end
				local originalSet=handle.Set
				function handle:Set(value)
					local code=tostring(value):gsub("#","")
					if code:match("^%x%x%x%x%x%x$") then
						h,s,v=Color3.fromRGB(tonumber(code:sub(1,2),16),tonumber(code:sub(3,4),16),tonumber(code:sub(5,6),16)):ToHSV()
						render()
					end
					originalSet(self,value)
				end
				local function commit()
					render()
					local c=Color3.fromHSV(h,s,v)
					local code=string.format("#%02X%02X%02X",math.floor(c.R*255+0.5),math.floor(c.G*255+0.5),math.floor(c.B*255+0.5))
					originalSet(handle,code)
				end
				local function drag(target,fn)
					Hub.connect(target.InputBegan,function(event)
						if event.UserInputType~=Enum.UserInputType.MouseButton1 and event.UserInputType~=Enum.UserInputType.Touch then return end
						UI.pointerAction=function(point)
							local size=target.AbsoluteSize
							if size.X<=0 or size.Y<=0 then return end
							fn(math.clamp((point.X-target.AbsolutePosition.X)/size.X,0,1),math.clamp((point.Y-target.AbsolutePosition.Y)/size.Y,0,1))
							commit()
						end
						UI.pointerAction(event.Position)
					end)
				end
				drag(sv,function(x,y) s=x;v=1-y end)
				-- The overlays receive clicks too.
				drag(white,function(x,y) s=x;v=1-y end)
				drag(black,function(x,y) s=x;v=1-y end)
				drag(hue,function(_,y) h=y end)
				Hub.connect(swatch.Activated,function()
					panel.Visible=not panel.Visible
					row.Size=UDim2.new(1,0,0,panel.Visible and 252 or 80)
				end)
				local code=field.Text:gsub("#","")
				if code:match("^%x%x%x%x%x%x$") then
					h,s,v=Color3.fromRGB(tonumber(code:sub(1,2),16),tonumber(code:sub(3,4),16),tonumber(code:sub(5,6),16)):ToHSV()
				end
				render()
			end

			return handle
		end
		function Tab:CreateKeybind(info)
			local row = card(self,info.Name)
			local key=text(row,info.CurrentKeybind,{Position=UDim2.new(1,-120,0,0),Size=UDim2.fromOffset(100,48),TextXAlignment=Enum.TextXAlignment.Right,TextColor3=colors.muted})
			local handle={CurrentKeybind=info.CurrentKeybind,info=info,label=key}
			function handle:Set(value)
				self.CurrentKeybind=tostring(value);key.Text=self.CurrentKeybind
				if info.CallOnChange then emit(info.Callback,self.CurrentKeybind) end
			end
			Hub.connect(row.Activated,function() if UI.capture then UI.capture.label.Text=UI.capture.CurrentKeybind end;UI.capture=handle;Hub.keybindCaptureActive=true;key.Text="Press a key..." end)
			table.insert(UI.keybinds,handle)
			return handle
		end
		function UI:SetMetricsPreference(key,value)
			self[key]=value
			if not self.metricsGui then return end
			self.metricsGui.Enabled=self.metricsShown~=false
			local position=self.metricsPosition or "Top Right"
			local x=position:find("Left",1,true) and 0 or position:find("Center",1,true) and 0.5 or 1
			local y=position:find("Bottom",1,true) and 1 or 0
			self.metricsFrame.AnchorPoint=Vector2.new(x,y)
			self.metricsFrame.Position=UDim2.new(x,x==0 and 12 or x==1 and -12 or 0,y,y==0 and 12 or -12)
			self.metricsScale.Scale=self.metricsSize or 1
		end
		Hub.setMetricsPreference=function(key,value) UI:SetMetricsPreference(key,value) end

		function UI:CreateWindow(info)
			local gui=make("ScreenGui",nil,{Name="ArrivaSidebarHub",ResetOnSpawn=false,IgnoreGuiInset=true,
				ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=100})
			local ok=pcall(function() gui.Parent=gethui and gethui() or game:GetService("CoreGui") end)
			if not ok then gui.Parent=player:WaitForChild("PlayerGui") end
			self.gui=gui
			local root=make("Frame",gui,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
				Size=UDim2.fromOffset(920,540),BackgroundColor3=colors.background,ClipsDescendants=true})
			round(root,14)
			local scale=make("UIScale",root,{Scale=1})
			local outline=stroke(root,Color3.new(1,1,1),1.5)
			self.outline=outline
			outline.Enabled=self.rainbow~=false
			local keys={}
			for i=0,6 do table.insert(keys,ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1))) end
			local gradient=make("UIGradient",outline,{Color=ColorSequence.new(keys)})
			self.glowGradient=gradient
			self.defaultGlowColor=gradient.Color
			local header=make("Frame",root,{Size=UDim2.new(1,0,0,66),BackgroundTransparency=1,Active=true})
			make("ImageLabel",header,{Name="ArrivaLogo",BackgroundTransparency=1,
				Image="rbxassetid://90461919222617",ScaleType=Enum.ScaleType.Fit,
				Position=UDim2.fromOffset(20,11),Size=UDim2.fromOffset(44,44)})
			local title=text(header,"ARRIVA CORE HUB 2.5",{Position=UDim2.fromOffset(78,8),Size=UDim2.new(1,-218,0,28),TextSize=22})
			local titleFont=Font.fromEnum(Enum.Font.Ubuntu)
			title.FontFace=Font.new(titleFont.Family,Enum.FontWeight.Bold,Enum.FontStyle.Italic)
			local metrics=text(header,"FPS: -- |  Ping: --",{Name="ClientMetrics",
				Position=UDim2.fromOffset(80,37),Size=UDim2.new(1,-220,0,18),TextSize=12,TextColor3=colors.muted})
			self.metricsGui=make("ScreenGui",gui.Parent,{Name="ArrivaFloatingMetrics",ResetOnSpawn=false,
				IgnoreGuiInset=false,DisplayOrder=101,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
			self.metricsFrame=make("Frame",self.metricsGui,{Name="PerformanceWidget",Size=UDim2.fromOffset(226,46),
				BackgroundColor3=colors.card,BorderSizePixel=0})
			round(self.metricsFrame,12);stroke(self.metricsFrame,colors.blueLine,1.3)
			self.metricsScale=make("UIScale",self.metricsFrame,{Scale=1})
			icon(self.metricsFrame,"activity",{Position=UDim2.fromOffset(12,13),ImageColor3=colors.blueLine})
			self.widgetFPS=text(self.metricsFrame,"FPS --",{Position=UDim2.fromOffset(42,0),Size=UDim2.fromOffset(68,46),Font=Enum.Font.GothamBold,TextSize=14})
			make("Frame",self.metricsFrame,{Position=UDim2.fromOffset(113,12),Size=UDim2.fromOffset(1,22),BackgroundColor3=colors.line,BorderSizePixel=0})
			self.widgetPing=text(self.metricsFrame,"-- ms",{Position=UDim2.fromOffset(126,0),Size=UDim2.fromOffset(88,46),TextSize=14})
			self:SetMetricsPreference("metricsShown",true)

			local frames,seconds=0,0
			local metricsConnection=RunService.RenderStepped:Connect(function(dt)
				if self.destroyed or (not self.visible and self.metricsShown==false) then frames=0;seconds=0;return end
				frames+=1;seconds+=dt
				if seconds<0.5 then return end
				local fps=math.floor(frames/seconds+0.5)
				local ok,ping=pcall(function() return player:GetNetworkPing()*1000 end)
				local value="--"
				if ok and type(ping)=="number" and ping==ping and ping>=0 and ping<math.huge then
					value=string.format("%.0f ms",ping)
				end
				metrics.Text=string.format("FPS: %d  |  Ping: %s",fps,value)
				self.widgetFPS.Text=string.format("FPS %d",fps)
				self.widgetPing.Text=value=="--" and "-- ms" or value
				frames,seconds=0,0
			end)
			Hub.connections[metricsConnection]=true
			self.metricsConnection=metricsConnection
			make("Frame",root,{Position=UDim2.fromOffset(0,65),Size=UDim2.new(1,0,0,1),BackgroundColor3=colors.line,BorderSizePixel=0})
			local minimize=button(header,"",{Name="Minimize",Position=UDim2.new(1,-122,0,13),Size=UDim2.fromOffset(44,40)})
			local close=button(header,"",{Name="Close",Position=UDim2.new(1,-74,0,13),Size=UDim2.fromOffset(44,40)})
			round(minimize,9);round(close,9);stroke(minimize);stroke(close)
			icon(minimize,"minus",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ImageColor3=colors.text})
			icon(close,"x",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),ImageColor3=colors.text})
			local body=make("Frame",root,{Position=UDim2.fromOffset(0,66),Size=UDim2.new(1,0,1,-66),BackgroundTransparency=1})
			local sidebar=make("Frame",body,{Size=UDim2.new(0,232,1,0),BackgroundColor3=colors.sidebar,BorderSizePixel=0})
			-- Match the outer bottom-left curve; leave the internal seams square.
			round(sidebar,14)
			make("Frame",sidebar,{Name="SidebarTopFill",Size=UDim2.new(1,0,0,14),
				BackgroundColor3=colors.sidebar,BorderSizePixel=0})
			make("Frame",sidebar,{Name="SidebarInnerFill",Position=UDim2.new(1,-14,0,0),Size=UDim2.new(0,14,1,0),
				BackgroundColor3=colors.sidebar,BorderSizePixel=0})
			make("Frame",sidebar,{Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0),BackgroundColor3=colors.line,BorderSizePixel=0})
			self.search=make("TextBox",sidebar,{Position=UDim2.fromOffset(14,14),Size=UDim2.new(1,-28,0,42),
				BackgroundColor3=Color3.fromRGB(161,161,161),TextColor3=Color3.fromRGB(34,34,34),PlaceholderColor3=Color3.fromRGB(111,111,111),
				PlaceholderText="Search...",Text="",ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=15,TextXAlignment=Enum.TextXAlignment.Left})
			round(self.search,14);padding(self.search,12)
			icon(sidebar,"search",{Position=UDim2.fromOffset(27,25),ImageColor3=Color3.fromRGB(91,91,91)})
			for _,child in ipairs(self.search:GetChildren()) do
				if child:IsA("UIPadding") then child.PaddingLeft=UDim.new(0,40) end
			end
			self.nav=make("ScrollingFrame",sidebar,{Position=UDim2.fromOffset(14,72),Size=UDim2.new(1,-23,1,-148),
				BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageTransparency=0,ScrollingEnabled=true,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
			make("UIListLayout",self.nav,{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder})
			local profile=make("Frame",sidebar,{Position=UDim2.new(0,0,1,-64),Size=UDim2.new(1,0,0,64),BackgroundTransparency=1})
			make("Frame",profile,{Size=UDim2.new(1,0,0,1),BackgroundColor3=colors.line,BorderSizePixel=0})
			local avatar=make("ImageLabel",profile,{Position=UDim2.fromOffset(14,10),Size=UDim2.fromOffset(44,44),BackgroundColor3=colors.card,
				Image="rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=100&h=100"})
			round(avatar,24);stroke(avatar)
			text(profile,player.DisplayName or player.Name,{Position=UDim2.fromOffset(68,0),Size=UDim2.new(1,-78,1,0),Font=Enum.Font.GothamBold,TextSize=15})
			self.content=make("Frame",body,{Position=UDim2.fromOffset(246,12),Size=UDim2.new(1,-260,1,-24),BackgroundTransparency=1})
			local grip=button(root,"",{Name="Resize",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-9,1,-7),Size=UDim2.fromOffset(22,22),ZIndex=20})
			icon(grip,"arrow-down-right",{Size=UDim2.fromScale(1,1),ZIndex=21})
			local width,height=920,540
			local minimized=false
			local function fit()
				local camera=Workspace.CurrentCamera
				if camera then
					local value=math.clamp(math.min(self.userScale or 1,(camera.ViewportSize.X-24)/width,(camera.ViewportSize.Y-24)/height),0.35,1.3)
					if scale.Scale~=value then scale.Scale=value end
				end
			end
			self.fitWindow=fit
			local viewportConnection
			local function watchViewport()
				if viewportConnection then viewportConnection:Disconnect();Hub.connections[viewportConnection]=nil end
				local camera=Workspace.CurrentCamera
				if camera and camera.GetPropertyChangedSignal then
					viewportConnection=Hub.connect(camera:GetPropertyChangedSignal("ViewportSize"),fit)
				end
				fit()
			end
			if Workspace.GetPropertyChangedSignal then Hub.connect(Workspace:GetPropertyChangedSignal("CurrentCamera"),watchViewport) end
			watchViewport()
			local elapsed=0
			Hub.connect(RunService.Heartbeat,function(dt)
				if not self.visible or self.rainbow==false or minimized then return end
				elapsed+=dt
				if elapsed>=0.1 then
					if self.rainbow~=false then gradient.Rotation=(gradient.Rotation+elapsed*(self.rainbowSpeed or 14))%360 end
					elapsed=0
				end
			end)
			Hub.connect(self.search:GetPropertyChangedSignal("Text"),filter)
			Hub.connect(minimize.Activated,function()
				minimized=not minimized;body.Visible=not minimized;grip.Visible=not minimized
				root.Size=UDim2.fromOffset(width,minimized and 66 or height)
			end)
			Hub.connect(close.Activated,function() if self.onClose then self.onClose() else self:Destroy() end end)
			Hub.connect(header.InputBegan,function(event)
				if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
					local start,position=event.Position,Hub.teleportFrame(root).Position
					self.pointerAction=function(point)
						local delta=(point-start)/scale.Scale
						root.Position=UDim2.new(position.X.Scale,position.X.Offset+delta.X,position.Y.Scale,position.Y.Offset+delta.Y)
					end
				end
			end)
			Hub.connect(grip.InputBegan,function(event)
				if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
					local start,startWidth,startHeight=event.Position,width,height
					self.pointerAction=function(point)
						local delta=(point-start)/scale.Scale
						width=math.clamp(startWidth+delta.X,640,1400);height=math.clamp(startHeight+delta.Y,380,900)
						root.Size=UDim2.fromOffset(width,height);fit()
					end
				end
			end)
			Hub.connect(input.InputChanged,function(event)
				if self.pointerAction and (event.UserInputType==Enum.UserInputType.MouseMovement or event.UserInputType==Enum.UserInputType.Touch) then self.pointerAction(event.Position) end
			end)
			Hub.connect(input.InputEnded,function(event)
				if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then self.pointerAction=nil end
			end)
			Hub.connect(input.InputBegan,function(event,processed)
				if self.capture then
					if event.KeyCode==Enum.KeyCode.Unknown then return end
					local capture=self.capture;self.capture=nil;Hub.keybindCaptureActive=false;Hub.keybindCaptureBlockUntil=os.clock()+0.15
					if event.KeyCode==Enum.KeyCode.Escape then capture.label.Text=capture.CurrentKeybind else capture:Set(event.KeyCode.Name) end
					return
				end
				if processed or input:GetFocusedTextBox() or os.clock()<(Hub.keybindCaptureBlockUntil or 0) then return end
				local matched=false
				for _,handle in ipairs(self.keybinds) do
					if event.KeyCode.Name==handle.CurrentKeybind then matched=true;emit(handle.info.Callback) end
				end
				if not matched and event.KeyCode==Enum.KeyCode.RightShift then self:SetVisibility(not self.visible) end
			end)
			local window={}
			function window:CreateTab(name,iconName)
				local page=make("ScrollingFrame",UI.content,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
					BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=colors.line,CanvasSize=UDim2.new(),
					AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false})
				make("UIPadding",page,{PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,14),
					PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,12)})
				make("UIListLayout",page,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
				local nav=button(UI.nav,"",{Size=UDim2.new(1,-6,0,39)})
				local navLabel=text(nav,name,{Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-44,1,0),TextSize=15,TextColor3=colors.muted})
				local navIcon=icon(nav,iconName=="align-vertical-space-around" and "sparkles" or iconName,{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,2,0.5,0),Size=UDim2.fromOffset(22,22)})
				local marker=make("Frame",nav,{Position=UDim2.new(1,-1,0,5),Size=UDim2.new(0,3,1,-10),BackgroundColor3=colors.text,BorderSizePixel=0,Visible=false})
				round(marker,2)
				local tab=setmetatable({name=name,page=page,nav=nav,navLabel=navLabel,icon=navIcon,marker=marker,entries={}}, {__index=Tab})
				table.insert(UI.tabs,tab)
				Hub.connect(nav.Activated,function() activate(tab) end)
				if not UI.active then activate(tab) end
				return tab
			end
			function window.ModifyTheme() end -- The tool design intentionally keeps one palette.
			function window:SetCloseCallback(callback) UI.onClose=callback end
			return window
		end
		function UI:SetVisibility(visible) self.visible=visible==true;Hub.menuVisible=self.visible;if self.gui then self.gui.Enabled=self.visible end;if Hub.menuMouse then Hub.menuMouse(self.visible) end end
		function UI:IsVisible() return self.visible end
		function UI:RefreshAccentGlow()
			if not self.glowGradient or not self.outline then return end
			self.outline.Enabled=self.rainbow~=false
			self.outline.Color=Color3.new(1,1,1)
			if not self.activeTheme or self.activeTheme=="Default" then
				self.glowGradient.Color=self.defaultGlowColor
			else
				local accent=colors.blueLine
				self.glowGradient.Color=ColorSequence.new({
					ColorSequenceKeypoint.new(0,accent:Lerp(colors.background,0.3)),
					ColorSequenceKeypoint.new(0.5,accent:Lerp(Color3.new(1,1,1),0.15)),
					ColorSequenceKeypoint.new(1,accent:Lerp(colors.background,0.3)),
				})
			end
		end
		function UI:SetRainbowEnabled(value)
			self.rainbow=value==true
			self:RefreshAccentGlow()
		end
		function UI:SetBorderThickness(value)
			if self.outline then self.outline.Thickness=math.clamp(value,1,4) end
		end
		function UI:SetBorderSpeed(value) self.rainbowSpeed=math.clamp(value,1,90) end
		function UI:SetUserScale(value)
			self.userScale=math.clamp(value/100,0.7,1.3)
			if self.fitWindow then self.fitWindow() end
		end
		function UI:Destroy() if self.destroyed then return end;self.destroyed=true;self.pointerAction=nil;if self.gui then self.gui:Destroy() end;if self.noticeGui then self.noticeGui:Destroy();self.noticeGui=nil end;if self.metricsConnection then self.metricsConnection:Disconnect();Hub.connections[self.metricsConnection]=nil end;if self.metricsGui then self.metricsGui:Destroy();self.metricsGui=nil end end
		-- BEGIN NOTICE STYLE
		function UI:RefreshNoticeStyle(frame)
			if not frame.Parent then return end
			local kind=frame:GetAttribute("NoticeKind") or "info"
			local defaults={info=Color3.fromRGB(106,177,255),warning=Color3.fromRGB(255,202,105),success=Color3.fromRGB(111,224,160),danger=Color3.fromRGB(255,115,125),join=Color3.fromRGB(190,140,255),leave=Color3.fromRGB(190,140,255),respawn=Color3.fromRGB(190,140,255),blackhole=Color3.fromRGB(234,112,255),kick=Color3.fromRGB(255,115,125)}
			local accent=self["noticeColor_"..kind] or defaults[kind] or defaults.info
			local background=self.noticeBackground or colors.card
			frame.BackgroundColor3=background:Lerp(accent,self.noticeBackgroundTint or 0.14)
			frame.BackgroundTransparency=self.noticeBackgroundTransparency or 0
			local newHex=string.format("#%02X%02X%02X",math.floor(accent.R*255+0.5),math.floor(accent.G*255+0.5),math.floor(accent.B*255+0.5))
			local oldHex=frame:GetAttribute("NoticeAccentHex")
			for _,object in ipairs(frame:GetDescendants()) do
				if object:IsA("UIStroke") then object.Color=accent;object.Thickness=self.noticeBorderThickness or 1.2
				elseif object:IsA("UICorner") then object.CornerRadius=UDim.new(0,self.noticeCornerRadius or 10)
				elseif object.Name=="NotificationHeading" then object.TextColor3=accent
				elseif object.Name=="NotificationIcon" then object.ImageColor3=accent
				elseif object.Name=="NotificationProgress" then object.BackgroundColor3=accent
				elseif object.Name=="NotificationBody" then
					object.TextColor3=self.noticeBodyColor or colors.noticeText
					if oldHex and oldHex~=newHex then object.Text=object.Text:gsub(oldHex,newHex) end
				end
			end
			frame:SetAttribute("NoticeAccentHex",newHex)
		end
		-- END NOTICE STYLE

		function UI:SetNoticePreference(key,value)
			self[key]=value
			if key=="noticeLimit" and self.notices then
				while #self.notices>value do table.remove(self.notices,1):Destroy() end
			end
			if self.noticeLayout then
				local position=self.noticePosition or "Bottom Right"
				self.noticeLayout.HorizontalAlignment=position:find("Left",1,true) and Enum.HorizontalAlignment.Left
					or position:find("Center",1,true) and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Right
				self.noticeLayout.VerticalAlignment=position:find("Top",1,true) and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
			end
			for _,frame in ipairs(self.notices or {}) do
				local scale=frame:FindFirstChild("NotificationScale")
				if scale then scale.Scale=self.noticeScale or 1 end
				self:RefreshNoticeStyle(frame)
			end
		end
		Hub.setNoticePreference=function(key,value) UI:SetNoticePreference(key,value) end
		function UI:Notify(info)
			if not self.gui or self.destroyed then return end
			-- Independent from menu visibility; still removed on hub unload.
			if not self.noticeGui then
				self.noticeGui=make("ScreenGui",self.gui.Parent,{Name="ArrivaNotifications",
					ResetOnSpawn=false,IgnoreGuiInset=true,Enabled=true,
					DisplayOrder=self.gui.DisplayOrder+1,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
			end
			self.noticeCount=(self.noticeCount or 0)+1
			self.notices=self.notices or {}
			if not self.noticeStack then
				self.noticeStack=make("Frame",self.noticeGui,{BackgroundTransparency=1,
					AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-18,1,-18),
					Size=UDim2.new(1,-36,1,-36)})
				self.noticeLayout=make("UIListLayout",self.noticeStack,{Padding=UDim.new(0,10),
					SortOrder=Enum.SortOrder.LayoutOrder,
					VerticalAlignment=Enum.VerticalAlignment.Bottom,
					HorizontalAlignment=Enum.HorizontalAlignment.Right})
			end
			for index=#self.notices,1,-1 do
				if not self.notices[index].Parent then table.remove(self.notices,index) end
			end
			self:SetNoticePreference("noticePosition",self.noticePosition or "Bottom Right")
			while #self.notices>=(self.noticeLimit or 3) do table.remove(self.notices,1):Destroy() end
			local frame=make("Frame",self.noticeStack,{LayoutOrder=self.noticeCount,
				Size=UDim2.new(0.92,0,0,112),BackgroundColor3=colors.card})
			make("UIScale",frame,{Name="NotificationScale",Scale=self.noticeScale or 1})
			make("UISizeConstraint",frame,{MaxSize=Vector2.new(400,1000)})
			round(frame,10);stroke(frame,colors.line,1.2)
			local title = tostring(info.Title or "Arriva"):sub(1,180):gsub(";",",")
			local content = tostring(info.Content or ""):sub(1,2048):gsub(";",",")
			local category = string.lower(title .. " " .. content)
			local accent = Color3.fromRGB(106,177,255)
			local iconName = "settings"
			local negative = {"error","failed","failure","respawn","blackhole","black hole","kicked","disconnected","lost"}
			local bad = false
			for _,word in ipairs(negative) do
				if category:find(word,1,true) then bad=true;break end
			end
			if bad then accent=Color3.fromRGB(255,115,125);iconName="shield"
			elseif category:find("warning",1,true) then accent=Color3.fromRGB(255,202,105);iconName="shield"
			elseif category:find("success",1,true) or category:find("restored",1,true) or category:find("saved",1,true) then
				accent=Color3.fromRGB(111,224,160);iconName="check"
			end
			-- Event-specific symbols; classification uses the message for legacy calls too.
			if category:find("joined",1,true) then
				iconName="door-open";accent=Color3.fromRGB(111,224,160)
			elseif category:find("kicked",1,true) then
				iconName="triangle-alert";accent=Color3.fromRGB(255,115,125)
			elseif category:find("left",1,true) or category:find("disconnected",1,true) then
				iconName="log-out";accent=Color3.fromRGB(255,115,125)
			elseif category:find("black hole",1,true) or category:find("blackhole",1,true) then
				iconName="orbit"
			elseif category:find("respawn",1,true) then iconName="rotate-ccw"
			elseif category:find("warning",1,true) then iconName="triangle-alert"
			elseif category:find("error",1,true) or category:find("fail",1,true) then iconName="circle-alert"
			elseif iconName=="settings" then iconName="info" end
			if category:find("[protected]",1,true) then accent=Color3.fromRGB(111,224,160) end
			local eventKind=Hub.notificationEvent(info)
			local noticeKind=eventKind or (Hub.notificationKind and Hub.notificationKind(info)) or (bad and "danger" or "info")
			local eventIcons={join="door-open",leave="log-out",respawn="rotate-ccw",blackhole="orbit",kick="triangle-alert"}
			if eventKind then iconName=eventIcons[eventKind] end
			frame:SetAttribute("NoticeKind",noticeKind)
			frame:SetAttribute("PurpleRosterNotice",eventKind=="join" or eventKind=="leave" or eventKind=="respawn")
			local headerRow=make("Frame",frame,{BackgroundTransparency=1,
				Position=UDim2.fromOffset(16,12),Size=UDim2.new(1,-32,0,24)})
			icon(headerRow,iconName,{Name="NotificationIcon",AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),
				Size=UDim2.fromOffset(20,20),ImageColor3=accent})
			local heading=text(headerRow,title,{Name="NotificationHeading",Position=UDim2.fromOffset(30,0),Size=UDim2.new(1,-30,1,0),
				Font=Enum.Font.GothamBold,TextSize=15,TextColor3=accent,TextWrapped=true,LineHeight=1.2,
				TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.None})
			local function escape(value)
				return (value:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
			end
			-- Keep recent departures available to every notification, not just leave alerts.
			for _,person in ipairs(playerService:GetPlayers()) do rememberPlayer(person) end
			local candidates={}
			for key,entry in pairs(knownNames) do
				if os.clock()-entry.time>300 then knownNames[key]=nil
				else table.insert(candidates,key) end
			end
			table.sort(candidates,function(a,b) return #a>#b end)
			local hex=string.format("#%02X%02X%02X",math.floor(accent.R*255+0.5),math.floor(accent.G*255+0.5),math.floor(accent.B*255+0.5))
			local lower=string.lower(content)
			local pieces={}
			local cursor=1
			while cursor<=#content do
				local bestStart,bestEnd
				for _,name in ipairs(candidates) do
					local search=cursor
					while search<=#content do
						local first,last=lower:find(name,search,true)
						if not first then break end
						local before=first>1 and lower:sub(first-1,first-1) or ""
						local after=lower:sub(last+1,last+1)
						if not before:match("[%w_]") and not after:match("[%w_]") then
							if not bestStart or first<bestStart or (first==bestStart and last>bestEnd) then
								bestStart,bestEnd=first,last
							end
							break
						end
						search=last+1
					end
				end
				if not bestStart then table.insert(pieces,escape(content:sub(cursor)));break end
				table.insert(pieces,escape(content:sub(cursor,bestStart-1)))
				table.insert(pieces,'<font color="' .. hex .. '">' .. escape(content:sub(bestStart,bestEnd)) .. '</font>')
				cursor=bestEnd+1
			end
			local readable=table.concat(pieces)
			readable=readable:gsub("%[Protected%]",'<font color="#6FE0A0">[Protected]</font>')
			frame:SetAttribute("NoticeAccentHex",hex)
			local body=text(frame,readable,{Name="NotificationBody",Position=UDim2.fromOffset(16,44),Size=UDim2.new(1,-32,0,24),
				RichText=true,TextWrapped=true,TextSize=15,LineHeight=1.15,TextColor3=Color3.fromRGB(245,245,245),
				TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=Enum.TextTruncate.None})
			body.Visible=content~=""
			do
				-- Every notification shares the same entrance and lifetime indicator.
				local lifetime=(info.Duration or 5)*(self.noticeDuration or 1)
				local progress=make("Frame",frame,{Name="NotificationProgress",BorderSizePixel=0,
					AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,10,1,-5),Size=UDim2.new(1,-20,0,3),BackgroundColor3=accent})
				round(progress,2)
				local scale=frame:FindFirstChild("NotificationScale")
				local targetScale=self.noticeScale or 1
				local tweenService=game:GetService("TweenService")
				scale.Scale=targetScale*0.9
				local entrance=tweenService:Create(scale,TweenInfo.new(0.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=targetScale})
				local countdown=tweenService:Create(progress,TweenInfo.new(lifetime,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,0,3)})
				local cleanup
				cleanup=frame.Destroying:Connect(function() entrance:Cancel();countdown:Cancel();cleanup:Disconnect() end)
				entrance:Play();countdown:Play()
			end
			self:RefreshNoticeStyle(frame)
			local function fitNotice()
				if not frame.Parent then return end
				local function measuredHeight(value,label,font,lineHeight)
					local width=label.AbsoluteSize.X/(self.noticeScale or 1)
					if width<=1 then return label.TextBounds.Y end
					local ok,bounds=pcall(function()
						return game:GetService("TextService"):GetTextSize(value,15,font,Vector2.new(width,10000))
					end)
					if ok and bounds and type(bounds.Y)=="number" then return math.ceil(bounds.Y*(lineHeight or 1)) end
					return label.TextBounds.Y
				end
				local headerHeight=math.max(24,measuredHeight(title,heading,Enum.Font.GothamBold,1.2))
				headerRow.Size=UDim2.new(1,-32,0,headerHeight)
				heading.Size=UDim2.new(1,-30,1,0)
				local top=12+headerHeight+10
				local height=content~="" and math.max(24,measuredHeight(content,body,Enum.Font.Gotham,1.15)) or 0
				body.Position=UDim2.fromOffset(16,top)
				body.Size=UDim2.new(1,-32,0,height)
				frame.Size=UDim2.new(0.92,0,0,math.max(58,top+height+14))
			end
			local headerSizing=heading:GetPropertyChangedSignal("TextBounds"):Connect(fitNotice)
			local widthSizing=heading:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitNotice)
			frame.Destroying:Connect(function() headerSizing:Disconnect();widthSizing:Disconnect() end)
			local sizing=body:GetPropertyChangedSignal("TextBounds"):Connect(fitNotice)
			frame.Destroying:Connect(function() sizing:Disconnect() end)
			task.defer(fitNotice)
			table.insert(self.notices,frame)
			task.delay((info.Duration or 5)*(self.noticeDuration or 1),function()
				local index=table.find(self.notices,frame)
				if index then table.remove(self.notices,index) end
				if frame.Parent then frame:Destroy() end
			end)
		end
		local custom={background="191919",accent="4589BF",text="EDEDED"}
		local function hex(value)
			value=tostring(value):gsub("#","")
			if not value:match("^%x%x%x%x%x%x$") then return nil end
			return Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16))
		end
		local palettes = {
			Rose={ {29,19,24},{39,25,32},{48,31,39},{88,57,70},{255,239,246},{209,177,192},{147,66,100},{240,133,175},{245,223,233} },
			Ocean={ {13,25,30},{18,33,40},{24,42,50},{47,77,88},{233,249,255},{165,195,205},{36,112,135},{86,204,225},{215,240,247} },
			Amber={ {28,24,17},{36,31,22},{45,38,26},{82,68,44},{255,247,228},{204,188,155},{139,103,37},{237,184,74},{245,232,207} },
			["Default"]={ {25,25,25},{31,31,31},{33,33,33},{58,58,58},{237,237,237},{170,170,176},{55,104,146},{69,137,191},{220,224,232} },
			Midnight={ {16,21,34},{21,28,44},{28,37,55},{59,75,99},{241,245,255},{177,190,211},{55,95,165},{112,163,255},{223,233,251} },
			Violet={ {23,18,32},{31,25,43},{40,32,55},{75,59,96},{246,239,255},{192,177,208},{104,70,150},{181,137,244},{236,224,250} },
			Forest={ {16,25,22},{22,34,29},{29,43,36},{53,78,65},{237,250,241},{173,198,181},{43,106,76},{109,205,151},{219,241,225} },
		}
		Hub.creativeUIPalette=colors
		function UI:SetTheme(name)
			if name=="Tool Dark" then name="Default" end
			local palette=palettes[name]
			if name=="Custom" then
				local bg,accent,fg=hex(custom.background),hex(custom.accent),hex(custom.text)
				local function rgb(c) return {math.floor(c.R*255+0.5),math.floor(c.G*255+0.5),math.floor(c.B*255+0.5)} end
				local white=Color3.new(1,1,1)
				palette={rgb(bg),rgb(bg:Lerp(white,0.035)),rgb(bg:Lerp(white,0.065)),rgb(bg:Lerp(white,0.2)),
					rgb(fg),rgb(fg:Lerp(bg,0.3)),rgb(accent:Lerp(bg,0.3)),rgb(accent),rgb(fg)}
			end
			if not palette then return end
			self.activeTheme=name
			local keys={"background","sidebar","card","line","text","muted","blue","blueLine","noticeText"}
			local mapping={}
			for index,key in ipairs(keys) do
				local nextColor=Color3.fromRGB(table.unpack(palette[index]))
				table.insert(mapping,{old=colors[key],new=nextColor})
				colors[key]=nextColor
			end
			-- Only traverse UI when the theme changes, never every frame.
			for _,gui in ipairs({self.gui,self.metricsGui,self.noticeGui,Hub.touchActionsGui}) do
				for _,object in ipairs(gui:GetDescendants()) do
					local properties={}
					if object:IsA("GuiObject") then table.insert(properties,"BackgroundColor3") end
					if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then table.insert(properties,"TextColor3") end
					if object:IsA("ImageLabel") or object:IsA("ImageButton") then table.insert(properties,"ImageColor3") end
					if object:IsA("UIStroke") then table.insert(properties,"Color") end
					if object:IsA("ScrollingFrame") then table.insert(properties,"ScrollBarImageColor3") end
					for _,property in ipairs(properties) do
						local current=object[property]
						for _,entry in ipairs(mapping) do
							if current==entry.old then object[property]=entry.new;break end
						end
					end
				end
			end
		end
		Hub.setSidebarTheme=function(name) UI:SetTheme(name);UI:RefreshAccentGlow();for _,frame in ipairs(UI.notices or {}) do UI:RefreshNoticeStyle(frame) end end
		Hub.setCustomThemeColor=function(key,value)
			if custom[key]==nil or not hex(value) then return false end
			custom[key]=tostring(value):gsub("#","")
			if UI.activeTheme=="Custom" then UI:SetTheme("Custom");UI:RefreshAccentGlow() end
			return true
		end
		return UI
	end

	local Rayfield = createArrivaSidebar()
	Library = {Options = {}, Toggles = {}, callbacks = {}, controls = {}}
	SaveManager = {ignored = {}, folder = "ArrivaCoreHub/RayfieldConfigs"}
	ThemeManager = {}
	local http = game:GetService("HttpService")

	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, item in pairs(value) do result[key] = copy(item) end
		return result
	end
	local function notifyError(err) Hub.lastUIError=tostring(err);warn("[Arriva Rayfield] " .. tostring(err)) end
	local function invoke(callback, value)
		if not callback then return true end
		local ok,err=pcall(callback,value)
		if not ok then notifyError(err) end
		return ok,err
	end
	function Library:Notify(info)
		local prefs=Hub.noticePreferences
		local event=Hub.notificationEvent(info)
		if not prefs.enabled or (event and prefs.events[event]==false) then return end
		info=table.clone(info)
		if event and info.PlayerName then
			info.Description=Hub.formatEventText(prefs.templates[event] or "%message%",{
				player=info.PlayerName,kickedPlayer=info.PlayerName,leftPlayer=info.PlayerName,
				rejoinedPlayer=info.PlayerName,event=event,message=info.Description or info.Content or ""})
		end
		if not info.HistoryReplay then
			table.insert(Hub.noticeHistory,{Title=tostring(info.Title or "Arriva"):sub(1,180),
				Description=tostring(info.Description or info.Content or ""):sub(1,2048),
				Type=event or info.Type or info.Kind,Time=info.Time or info.Duration or 5,at=os.date("%H:%M:%S")})
			if #Hub.noticeHistory>50 then table.remove(Hub.noticeHistory,1) end
		end
		if Hub.playNotificationSound then pcall(Hub.playNotificationSound,info) end
		Rayfield:Notify({Type = info.Type or info.Kind, Title = info.Title or "Arriva", Content = info.Description or info.Content or "",
			Duration = info.Time or info.Duration or 5})
	end
	function Library:OnUnload(callback) table.insert(self.callbacks, callback) end
	function Library:Unload()
		if self.unloaded then return end
		self.unloaded = true
		for index = #self.callbacks, 1, -1 do pcall(self.callbacks[index]) end
		Rayfield:Destroy()
	end
	local Group = {}
	function Group:ensureSection()
		if self.tab.section ~= self.title then self.tab:CreateSection(self.title); self.sectionCreated = true end
	end
	local function register(id, kind, info, tab)
		tab.pendingControlId=id
		assert(not Library.controls[id], "Duplicate UI ID: " .. id)
		local control = {Id = id, Text = info.Text or tostring(id), Type = kind, Tab = tab, Value = info.Default, Multi = info.Multi or false, Callback = info.Callback,
			Values = info.Values or {}, NoUI = info.NoUI, Mode = "Toggle"}
		Library.controls[id] = control
		if kind == "Toggle" then Library.Toggles[id] = control else Library.Options[id] = control end
		function control:commit(value)
			self.Value = copy(value)
			self.revision=(self.revision or 0)+1
			if Hub.configLoading then
				local pending=Hub.configCallbacks
				if pending then
					local record=pending.byControl[self]
					if not record then
						record={control=self}
						pending.byControl[self]=record
						table.insert(pending.ordered,record)
					end
					record.value=copy(self.Value)
					record.revision=self.revision
				end
			else
				Hub.applyControl(self,self.Value,invoke)
			end
			Hub.requestSave()
		end
		function control:SetValue(value)
			local normalized = self:normalize(value)
			self.busy = true
			local ok, err = pcall(function() self.handle:Set(self:toRayfield(normalized)) end)
			self.busy = false
			if not ok then notifyError(err); return false,tostring(err) end
			self:commit(normalized)
			return true
		end
		function control:normalize(value) return value end
		function control:toRayfield(value) return value end
		return control
	end
	local function receive(control, value)
		if not control.busy then control.initialized = true; control:commit(control:normalize(value)) end
	end
	function Group:AddToggle(id, info)
		self:ensureSection()
		local control = register(id, "Toggle", info, self.tab)
		control.Value = info.Default == true
		function control:normalize(value) return value == true end
		control.handle = self.tab:CreateToggle({Name = info.Text or id, CurrentValue = control.Value,
			Callback = function(value) receive(control, value) end})
		if not control.initialized then control:commit(control.Value) end
		return control
	end
	function Group:AddSlider(id, info)
		self:ensureSection()
		local control = register(id, "Slider", info, self.tab)
		function control:normalize(value) return math.clamp(tonumber(value) or info.Default, info.Min, info.Max) end
		control.handle = self.tab:CreateSlider({Name = info.Text or id, Range = {info.Min, info.Max},
			Increment = 10 ^ -(info.Rounding or 0), CurrentValue = info.Default,
			Callback = function(value) receive(control, value) end})
		if not control.initialized then control:commit(control.Value) end
		return control
	end
	function Group:AddDropdown(id, info)
		self:ensureSection()
		local control = register(id, "Dropdown", info, self.tab)
		function control:normalize(value)
			if id=="SidebarTheme" and value=="Tool Dark" then value="Default" end
			if not self.Multi then
				if type(value) == "table" then value = value[1] end
				if type(value) == "number" then value = self.Values[value] end
				return table.find(self.Values, value) and value or nil
			end
			local result = {}
			if type(value) == "table" then
				for key, item in pairs(value) do
					local label = type(key) == "number" and item or (item and key or nil)
					if label and table.find(self.Values, label) then result[label] = true end
				end
			elseif value and table.find(self.Values, value) then result[value] = true end
			return result
		end
		function control:toRayfield(value)
			if not self.Multi then return value and {value} or {} end
			local selected = {}
			for _, label in ipairs(self.Values) do if value[label] then table.insert(selected, label) end end
			return selected
		end
		function control:SetValues(values)
			self.Values = copy(values)
			local value = self:normalize(self.Value)
			self.busy = true
			local ok, err = pcall(function()
				self.handle:Refresh(self.Values)
				self.handle:Set(self:toRayfield(value))
			end)
			self.busy = false
			if not ok then notifyError(err) end
			if Hub.canonical(value)~=Hub.canonical(self.Value) then self:commit(value) end
		end
		control.Value = control:normalize(info.Default)
		control.handle = self.tab:CreateDropdown({Name = info.Text or id, Options = copy(control.Values),
			CurrentOption = control:toRayfield(control.Value), MultipleOptions = control.Multi,
			Callback = function(value) receive(control, value) end})
		if not control.initialized then control:commit(control.Value) end
		return control
	end
	function Group:AddInput(id, info)
		self:ensureSection()
		local control = register(id, "Input", info, self.tab)
		control.Value = info.Default or ""
		function control:normalize(value) return tostring(value or "") end
		control.handle = self.tab:CreateInput({Name = info.Text or id, CurrentValue = control.Value,
			PlaceholderText = info.Placeholder or "Enter text", RemoveTextAfterFocusLost = false,
			Callback = function(value) receive(control, value) end})
		if not control.initialized then control:commit(control.Value) end
		return control
	end
	function Group:AddKeyPicker(id, info)
		if self.ensureSection then self:ensureSection() end
		local control = register(id, "KeyPicker", info, self.tab)
		control.Callback = nil -- Settings changes must not execute the bound action.
		function control:normalize(value)
			if type(value) == "table" then value = value[1] end
			return tostring(value or info.Default)
		end
		control.Value = info.Default
		function control:GetState() return self.Toggled == true end
		control.handle = self.tab:CreateKeybind({Name = info.Text or id, CurrentKeybind = info.Default,
			HoldToInteract = false, CallOnChange = true,
			Callback = function(value)
				if type(value) == "string" then
					if not control.busy then control:commit(value) end
				elseif Library.ToggleKeybind == control then
					local opening = not Rayfield:IsVisible()
					Rayfield:SetVisibility(opening)

					local sound = Hub.menuToggleSound
					if not sound then
						sound = Hub.new("Sound", game:GetService("SoundService"))
						Hub.menuToggleSound = sound

						Hub.cleanup(function()
							Hub.menuToggleSound = nil
							Hub.instances[sound] = nil
							Hub.assetTargets[sound] = nil
							sound:Destroy()
						end)
					end

					local key = Library.ToggleKeybind
					local keyName = key and tostring(key.Value) or "M"

					if opening then
						Library:Notify({
							Title = "Menu Open",
							Description = "Welcome back!",
							Time = 4,
							Type = "info",
						})
					else
						Library:Notify({
							Title = "Menu Closed",
							Description = "Press "..keyName.." to open the menu again.",
							Time = 4,
							Type = "info",
						})
					end

					sound:Stop()
					sound.SoundId = opening
						and "rbxassetid://115593451988265" -- Open
						or "rbxassetid://108295046133967" -- Close
					sound.Volume = 0.4
					sound.TimePosition = 0
					pcall(function() sound:Play() end)
				else invoke(info.Callback, value) end
			end})
		return control
	end
	function Group:AddButton(info, callback)
		self:ensureSection()
		if type(info) == "string" then info = {Text = info, Func = callback} end
		return self.tab:CreateButton({Name = info.Text or "Button", Callback = function() invoke(info.Func) end})
	end
	function Group:AddLabel(text)
		self:ensureSection()
		local handle = self.tab:CreateLabel(tostring(text))
		local label = {tab = self.tab}
		function label:SetText(value) handle:Set(tostring(value)) end
		label.AddKeyPicker = Group.AddKeyPicker
		return label
	end
	function Library:CreateWindow(info)
		local native = Rayfield:CreateWindow({Name = info.Title, LoadingTitle = "Arriva Core Hub",
			LoadingSubtitle = "Rayfield edition", Theme = "Default", ToggleUIKeybind = Enum.KeyCode.M,
			ConfigurationSaving = {Enabled = false}, Discord = {Enabled = false}, KeySystem = false})
		native:SetCloseCallback(function() Library:Unload() end)
		Library.window = native
		local window = {}
		function window:AddTab(name, icon)
			local nativeTab = native:CreateTab(name, icon)
			local tab = {native = nativeTab}
			function tab:AddLeftGroupbox(title)
				return setmetatable({tab = nativeTab, title = title}, {__index = Group})
			end
			tab.AddRightGroupbox = tab.AddLeftGroupbox
			return tab
		end
		return window
	end

	-- Keep the hub's existing save schema and loading order. Use a separate folder.
	function SaveManager:SetLibrary(value) self.library = value end
	function SaveManager:SetFolder(value)
		self.folder = "ArrivaCoreHub/RayfieldConfigs"
		self.legacyFolder = value .. "/settings"
	end
	function SaveManager:SetIgnoreIndexes(indexes) for _, id in ipairs(indexes) do self.ignored[id] = true end end
	function SaveManager:SetLoadingOrder(value) self.loadingOrder = value end
	function SaveManager:SaveJSON()
		local data = {version=2,objects={},safety={
			whitelistFriends=Hub.whitelistFriends,
			manualWhitelist=copy(Hub.manualWhitelist or {}),
		}}
		for id, control in pairs(Library.controls) do
			if not self.ignored[id] then
				if control.Type == "KeyPicker" and control.handle.CurrentKeybind then
					control.Value = control.handle.CurrentKeybind
				end
				local record = {idx = id, type = control.Type, value = copy(control.Value)}
				if control.Type == "KeyPicker" then record.key = control.Value; record.mode = control.Mode end
				table.insert(data.objects, record)
			end
		end
		local ok, result = pcall(function() return http:JSONEncode(data) end)
		if ok then return result, true end
		return nil, false, tostring(result)
	end
	function SaveManager:Save(name)
		local encoded,ok,err=self:SaveJSON()
		if not ok then return false,err end
		local file=self.folder .. "/" .. name .. ".json"
		local success,reason=pcall(function()
			if not isfolder("ArrivaCoreHub") then makefolder("ArrivaCoreHub") end
			if not isfolder(self.folder) then makefolder(self.folder) end
			if isfile(file) then
				local old=readfile(file)
				local valid,data=pcall(function() return http:JSONDecode(old) end)
				if valid and type(data)=="table" and type(data.objects)=="table" then
					writefile(file .. ".bak",old)
				end
			end
			writefile(file,encoded)
			if readfile(file)~=encoded then error("Settings write could not be verified") end
		end)
		if not success then return false,tostring(reason) end
		return true
	end
	function SaveManager:ResolveControlID(id)
		if Library.controls[id] then return id end
		-- Older imported controls used a nine-letter prefix; keep values for surviving controls.
		if type(id)~="string" or id:sub(1,1)~="R" or not id:sub(1,9):match("^%a%a%a%a%a%a%a%a%a$") then return id end
		local suffix=id:sub(10)
		local aliases={BlackholeAura="PlayerAttractionAura",BlackholeStrength="PlayerAttractionStrength",
			TornadoAura="PlayerTornadoAura",TornadoSpeed="PlayerTornadoSpeed"}
		local mapped=aliases[suffix] or ("Tool"..suffix)
		if Library.controls[mapped] then return mapped end
		return id
	end
	function SaveManager:LoadJSON(content)
		if type(content)~="string" then return false,"Configuration content is not text" end
		content=content:gsub("^\239\187\191",""):gsub("%z+$","")
		local ok,data=pcall(function() return http:JSONDecode(content) end)
		if not ok or type(data)~="table" or type(data.objects)~="table" then
			return false,"Configuration JSON could not be read: " .. tostring(data)
		end
		if type(data.safety)=="table" and type(data.safety.manualWhitelist)=="table" then
			Hub.manualWhitelist=copy(data.safety.manualWhitelist)
			if type(data.safety.whitelistFriends)=="boolean" then Hub.whitelistFriends=data.safety.whitelistFriends end
			Hub.loadedSafety=true
		end
		local errors={}
		local legacyDetailed=false
		for _,record in ipairs(data.objects) do if type(record)=="table" and record.idx=="DetailedESPEnabled" and record.value==true then legacyDetailed=true end end
		for _,record in ipairs(data.objects) do
			if type(record)=="table" then
				local id=self:ResolveControlID(record.idx)
				local control=Library.controls[id]
				if control and not self.ignored[id] then
					local value=record.value
					if control.Type=="KeyPicker" then value=record.key or record.value end
					local called,applied,reason=pcall(function() return control:SetValue(value) end)
					if not called or applied==false then
						table.insert(errors,tostring(record.idx) .. ": " .. tostring(called and reason or applied))
					end
				end
			end
		end
		if legacyDetailed and Library.controls.NicknameESP then Library.controls.NicknameESP:SetValue(true) end
		if Hub.refreshWhitelistUI then pcall(Hub.refreshWhitelistUI) end
		if #errors>0 then return false,"Some settings could not load: " .. table.concat(errors,"; ") end
		return true
	end
	function SaveManager:Load(name)
		if Hub.configLoading then return false,"A settings load is already in progress" end
		if Hub.saveThread then pcall(Hub.nativeTask.cancel,Hub.saveThread);Hub.threads[Hub.saveThread]=nil;Hub.saveThread=nil end
		local candidates={self.folder .. "/" .. name .. ".json",self.folder .. "/" .. name .. ".json.bak",
			(self.legacyFolder or "ArrivaCoreHub/Configs/settings") .. "/" .. name .. ".json"}
		local found=false
		local failures={}
		for _,file in ipairs(candidates) do
			local existsOk,exists=pcall(isfile,file)
			if not existsOk then
				Hub.configLoadFailed=true;Hub.lastLoadError=tostring(exists)
				return false,Hub.lastLoadError
			end
			if exists then
				found=true
				local readOk,content=pcall(readfile,file)
				if readOk then
					Hub.configCallbacks={ordered={},byControl={}}
					Hub.configLoading=true
					local called,loaded,reason=pcall(function() return self:LoadJSON(content) end)
					Hub.configLoading=false
					local pending=Hub.configCallbacks
					Hub.configCallbacks=nil
					if called and loaded then
						Hub.configLoadFailed=false;Hub.lastLoadError=nil
						Hub.configLoaded=true;Hub.lastLoadPath=file
						Hub.lastSettings=Hub.captureSettings()
						-- Starting a saved feature must never hold the settings loader open.
						Hub.queueSavedCallbacks(pending.ordered,invoke)
						return true
					end
					table.insert(failures,file .. ": " .. tostring(called and reason or loaded))
				else table.insert(failures,file .. ": " .. tostring(content)) end
			end
		end
		Hub.configLoading=false
		Hub.configLoadFailed=found
		Hub.lastLoadError=found and table.concat(failures," | ") or nil
		return false,Hub.lastLoadError or "No saved configuration"
	end
	function SaveManager:BuildConfigSection(tab)
		local group = tab:AddLeftGroupbox("Saved settings")
		group:AddButton({Text="Save settings",Func=function()
			-- This explicit action can replace a file after an unsuccessful load.
			local ok,err=Hub.persistSettings(true)
			Library:Notify({Title=ok and "Settings saved" or "Save error",Description=ok and "Your current settings were saved and verified." or tostring(err),Time=6})
		end})
		group:AddButton({Text = "Load settings", Func = function()
			local ok, err = self:Load("AutoSave")
			if not ok then warn("[Arriva config load] " .. tostring(err)) end
			Library:Notify({Title = ok and "Settings loaded" or "Load error", Description = ok and "Your saved settings were restored." or tostring(err),Time=10})
		end})
	end
	function ThemeManager:SetLibrary(value) self.library = value end
	function ThemeManager:SetFolder(value) self.folder = value end
	function ThemeManager:ApplyToTab(tab)
		local group = tab:AddRightGroupbox("Appearance")
		group:AddToggle("SidebarRainbowBorder", {Text = "Accent glow", Default = true,
			Callback = function(on) Rayfield:SetRainbowEnabled(on) end})
		group:AddSlider("SidebarBorderThickness",{Text="Accent glow thickness",Default=1.5,Min=1,Max=4,Rounding=1,
			Callback=function(value) Rayfield:SetBorderThickness(value) end})
		group:AddSlider("SidebarBorderSpeed",{Text="Accent glow speed",Default=14,Min=1,Max=90,Rounding=0,
			Callback=function(value) Rayfield:SetBorderSpeed(value) end})
		group:AddSlider("SidebarUIScale",{Text="UI scale (%)",Default=100,Min=70,Max=130,Rounding=0,
			Callback=function(value) Rayfield:SetUserScale(value) end})
	end

end

Hub.library = Library
Hub.connect(RunService.Heartbeat, function()
	-- Snapshot SaveManager's complete supported schema, including keybinds, themes and UI state.
	if not Hub.ready then return end
	local now = os.clock()
	if now < (Hub.nextSettingsCheck or 0) then return end
	Hub.nextSettingsCheck = now + 2
	for connection in pairs(Hub.connections) do if not connection.Connected then Hub.connections[connection] = nil end end
	Hub.pollSettings()
end)

Hub.unload = function() Library:Unload() end
Hub.env.ArrivaCoreMaintenance = Hub.unload
Library:OnUnload(Hub.stop)
Hub.saveManager = SaveManager
local Options = Library.Options
local Toggles = Library.Toggles
Library.ForceCheckbox = false

local Window = Library:CreateWindow({
	Title = "Arriva Core Hub — Sidebar",
	Footer = "Made by Arriva",
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local Tabs = {
	Player = Window:AddTab("Player", "user"),
	Defense = Window:AddTab("Protections", "shield"),
	Target = Window:AddTab("Loop Players", "crosshair"),
	AntiLag = Window:AddTab("Performance", "activity"),
	Blob = Window:AddTab("Blobman", "bot"),
	Aura = Window:AddTab("Player Auras", "sparkles"),
	Grab = Window:AddTab("Grab options", "hand"),
	Fun = Window:AddTab("Objects & Toys", "boxes"),
	Visual = Window:AddTab("Visuals", "eye"),
	Misc = Window:AddTab("World & Travel", "compass"),
	Whitelist = Window:AddTab("Protected Players", "user-round-check"),
	Explosions = Window:AddTab("Missiles & Explosions", "orbit"),
	KeyBinds = Window:AddTab("KeyBinds", "keyboard"),
	Commands = Window:AddTab("Commands", "terminal"),
	Sound = Window:AddTab("Sound", "volume-2"),
	Notifications = Window:AddTab("Notifications", "bell"),
	Customization = Window:AddTab("Appearance", "palette"),
	["UI Settings"] = Window:AddTab("Settings", "settings"),
}

-- Central shortcut settings. Existing option IDs remain compatible with saved settings.
Hub.keybindDefinitions = {
	{id="BlitzTriggerBombsKey",label="Trigger Bombs (hold)",default="F"},
	{id = "MenuKeybind", label = "Toggle menu", default = "M"},
	{id = "BlobSeatKey", label = "Sit in your Blobman", default = "B"},
	{id = "BlobFlyKey", label = "Toggle Blob Fly", default = "R"},
	{id = "ClickTeleportKey", label = "Click teleport", default = "Z"},
	{id = "FreeMouseKey", label = "Toggle free mouse", default = "F"},
	{id = "AnchorObjectKey", label = "Anchor held object", default = "G"},
	{id = "CreativeQuickSpawnKey", label = "Quick-spawn selected toy", default = "P"},
	{id = "ExplodeBombKey", label = "Explode Bomb", default = "J"},
	{id = "ExplodeFireworkKey", label = "Explode Firework", default = "N"},
	{id = "EmergencyUnloadKey", label = "Unload hub", default = "End"},
}
function Hub.matchesKeybind(id, input, fallback)
	if Hub.keybindCaptureActive or os.clock() < (Hub.keybindCaptureBlockUntil or 0) then return false end
	local option = Options[id]
	local value = option and option.Value or fallback
	return input and input.KeyCode and input.KeyCode.Name == value
end
function Hub.keybindConflictReport()
	local used, conflicts = {}, {}
	for _, definition in ipairs(Hub.keybindDefinitions) do
		local option = Options[definition.id]
		local key = option and option.Value or definition.default
		if key and key ~= "None" and key ~= "Unknown" then
			if used[key] then table.insert(conflicts, key .. ": " .. used[key] .. " / " .. definition.label)
			else used[key] = definition.label end
		end
	end
	return conflicts
end
Hub.keybindGroups = {
	actions = Tabs.KeyBinds:AddLeftGroupbox("Action shortcuts"),
	interface = Tabs.KeyBinds:AddRightGroupbox("Menu & emergency"),
	missiles = Tabs.KeyBinds:AddRightGroupbox("Missile throw"),
}
for _, definition in ipairs(Hub.keybindDefinitions) do
	if definition.id == "BlobSeatKey" or definition.id == "BlobFlyKey" or definition.id == "ClickTeleportKey" or definition.id == "FreeMouseKey" then
		Hub.keybindGroups.actions:AddLabel(definition.label):AddKeyPicker(definition.id,
			{Default = definition.default, Text = definition.label})
	elseif definition.id == "EmergencyUnloadKey" then
		Hub.keybindGroups.interface:AddLabel(definition.label):AddKeyPicker(definition.id,
			{Default = definition.default, Text = definition.label})
	end
end
Hub.keybindGroups.interface:AddButton({Text = "Check shortcut conflicts", Func = function()
	local conflicts = Hub.keybindConflictReport()
	Library:Notify({Title = "KeyBinds", Description = #conflicts == 0 and "No duplicate hub shortcuts." or table.concat(conflicts, "\n"), Time = 6})
end})
Hub.keybindGroups.interface:AddButton({Text = "Reset hub shortcuts", Func = function()
	for _, definition in ipairs(Hub.keybindDefinitions) do
		local option = Options[definition.id]
		if option then option:SetValue(definition.default) end
	end
end})
-- End central shortcut settings.

--// Core Variables
local Player = LocalPlayer -- Consistent naming
local Camera = Workspace.CurrentCamera
local CE = ReplicatedStorage:WaitForChild("CharacterEvents", 10)
local grabEventsFolder = ReplicatedStorage:WaitForChild("GrabEvents", 10)
if not CE or not grabEventsFolder then
	Library:Notify({Title = "Unsupported game", Description = "CharacterEvents / GrabEvents did not load within 10 seconds.", Time = 8})
	Library:Unload()
	return
end
local BeingHeld = Player:FindFirstChild("IsHeld")
local StruggleEvent = CE:FindFirstChild("Struggle")
local characterEventsFolder = CE
local createGrabLineEvent = grabEventsFolder:FindFirstChild("CreateGrabLine")
local destroyGrabLineEvent = grabEventsFolder:FindFirstChild("DestroyGrabLine")
local setNetworkOwnerEvent = grabEventsFolder:FindFirstChild("SetNetworkOwner")
local extendGrabLineRemoteEvent = grabEventsFolder:FindFirstChild("ExtendGrabLine")
local ragdollRemoteEvent = CE:FindFirstChild("RagdollRemote")
local playerScriptsFolder = Player:WaitForChild("PlayerScripts", 10)
-- Anti Lag resolves and watches CharacterAndBeamMove when enabled; no cached startup tool.
local spawnedInToysFolder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
Hub.connect(Workspace.ChildAdded, function(child)
	if child.Name == Player.Name .. "SpawnedInToys" then spawnedInToysFolder = child end
end)
Hub.cameraOriginal = {mode = Player.CameraMode, min = Player.CameraMinZoomDistance, max = Player.CameraMaxZoomDistance}
Hub.cameraFOV = setmetatable({}, {__mode = "k"})
Hub.connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	Camera = Workspace.CurrentCamera
	if Camera and Options.FOVSlider then
		Hub.cameraFOV[Camera] = Camera.FieldOfView
		Camera.FieldOfView = Options.FOVSlider.Value
	end
end)
Hub.cleanup(function()
	Player.CameraMaxZoomDistance = math.max(Player.CameraMaxZoomDistance, Hub.cameraOriginal.max)
	Player.CameraMinZoomDistance = Hub.cameraOriginal.min
	Player.CameraMaxZoomDistance = Hub.cameraOriginal.max
	Player.CameraMode = Hub.cameraOriginal.mode
	for cam, value in pairs(Hub.cameraFOV) do pcall(function() cam.FieldOfView = value end) end
end)

-- Helper Functions
local function notify(title, content, duration, kind, playerName)
	-- Legacy calls use notify(message, seconds).
	if type(content) == "number" and duration == nil then
		duration, content = content, ""
	end
	Library:Notify({
		PlayerName = playerName,
		Type = kind,
		Title = title or "Notification",
		Description = content or "",
		Time = duration or 5,
	})
end

local function sendHubLoadedMessage()
	local message = "Arriva Core Hub 2.5 Loaded..."
	local sent = false
	pcall(function()
		local chatVersion = TextChatService.ChatVersion
		if chatVersion == Enum.ChatVersion.TextChatService then
			local channels = TextChatService:FindFirstChild("TextChannels")
			if channels then
				local generalChannel = channels:FindFirstChild("RBXGeneral")
				if generalChannel and generalChannel:IsA("TextChannel") then
					generalChannel:SendAsync(message)
					sent = true
				end
			end
		end
	end)

	if not sent then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = message;
				Color = Color3.fromRGB(255, 170, 0);
				Font = Enum.Font.SourceSansBold;
				FontSize = Enum.FontSize.Size18;
			})
		end)
	end
end

-- Paint suppression owns its backups and never restores unrelated Hub properties.
local deleteAllPaintParts,restorePaintParts,watchNewPaintParts,disconnectWatchers,setTouchQuery=(function()
	local active=false
	local scanEpoch=0
	local saved,guards,connections={},{},{}
	local worldListeners={}
	local characterSaved={}
	local function disconnect(connection)
		connection:Disconnect();Hub.connections[connection]=nil
	end
	local function restore(object,properties)
		if not object.Parent then return end
		for key,value in pairs(properties) do pcall(function() object[key]=value end) end
	end
	local function underPaint(object)
		local current=object
		while current and current~=Workspace do
			if current:IsA("BasePart") and current.Name=="PaintPlayerPart" then return true end
			current=current.Parent
		end
		return false
	end
	local function suppress(object)
		if not active or not underPaint(object) then return end
		local properties
		if object:IsA("BasePart") then properties={Transparency=1,CanTouch=false,CanQuery=false,CanCollide=false}
		elseif object:IsA("Decal") or object:IsA("Texture") then properties={Transparency=1}
		elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
			or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles") then properties={Enabled=false}
		end
		if not properties then return end
		if not saved[object] then saved[object]={};connections[object]={} end
		for key,value in pairs(properties) do
			if saved[object][key]==nil then
				saved[object][key]=object[key]
				table.insert(connections[object],Hub.connect(object:GetPropertyChangedSignal(key),function()
					if active and not guards[object] and underPaint(object) and object[key]~=value then
						guards[object]=true;object[key]=value;guards[object]=nil
					end
				end))
			end
			guards[object]=true;object[key]=value;guards[object]=nil
		end
	end
	local function characterPart(object)
		local char=Player.Character
		if not active or not char or not object:IsA("BasePart") or not object:IsDescendantOf(char) then return end
		if not characterSaved[object] then characterSaved[object]={CanTouch=object.CanTouch,CanQuery=object.CanQuery} end
		object.CanTouch=false;object.CanQuery=false
	end
	local function forget(object)
		local list=connections[object]
		if list then for _,connection in ipairs(list) do disconnect(connection) end end
		connections[object]=nil
		if saved[object] then restore(object,saved[object]);saved[object]=nil end
		if characterSaved[object] then restore(object,characterSaved[object]);characterSaved[object]=nil end
	end
	local function restoreAll()
		active=false;scanEpoch+=1
		local objects={}
		for object in pairs(saved) do table.insert(objects,object) end
		for _,object in ipairs(objects) do forget(object) end
		for object,properties in pairs(characterSaved) do restore(object,properties) end
		table.clear(characterSaved)
	end
	local function scan()
		active=true;scanEpoch+=1;local ticket=scanEpoch
		Hub.scanDescendants(Workspace,suppress,function() return active and scanEpoch==ticket end)
	end
	local function disconnectAll()
		active=false
		for _,connection in ipairs(worldListeners) do disconnect(connection) end
		table.clear(worldListeners)
		restoreAll()
	end
	local function watch()
		for _,connection in ipairs(worldListeners) do disconnect(connection) end
		table.clear(worldListeners)
		active=true
		table.insert(worldListeners,Hub.connect(Workspace.DescendantAdded,function(object)
			suppress(object);characterPart(object)
			if object:IsA("BasePart") and object.Name=="PaintPlayerPart" then
				for _,child in ipairs(object:GetDescendants()) do suppress(child) end
			end
		end))
		table.insert(worldListeners,Hub.connect(Workspace.DescendantRemoving,function(object)
			if not saved[object] and not characterSaved[object] then return end
			task.defer(function()
				if not object:IsDescendantOf(Workspace) or not underPaint(object) then forget(object) end
			end)
		end))
	end
	local function touchQuery(state)
		if state then
			for object,properties in pairs(characterSaved) do restore(object,properties) end
			table.clear(characterSaved)
		else
			local char=Player.Character
			if char then for _,object in ipairs(char:GetDescendants()) do characterPart(object) end end
		end
	end
	return scan,restoreAll,watch,disconnectAll,touchQuery
end)()


-- Anti-Gucci Systems
Hub.gucciAutoDelete=true
Hub.gucciCleanupGeneration=0
local antiGucciConnection
local safePosition
local restoreFrames = 0

local function spawnBlobman()
	local args = {[1] = "CreatureBlobman", [2] = CFrame.new(0, 5000000, 0), [3] = Vector3.new(0, 60, 0)}
	pcall(function() Hub.invoke(ReplicatedStorage.MenuToys.SpawnToyRemoteFunction, unpack(args)) end)
	local folder = Workspace:WaitForChild(Player.Name.."SpawnedInToys", 5)
	if folder and folder:FindFirstChild("CreatureBlobman") then
		local blob = folder.CreatureBlobman
		if blob:FindFirstChild("Head") then blob.Head.CFrame = CFrame.new(0, 50000, 0) blob.Head.Anchored = true end
		notify("Success", "Blobman Spawned!", 3)
	end
end

local function startAntiGucci()
	local previous=Hub.gucciRun
	if previous and previous.busy and previous.character==Player.Character
		and previous.generation==Hub.blobGeneration then return end
	Hub.blobGeneration = (Hub.blobGeneration or 0) + 1
	local generation = Hub.blobGeneration
	local run={busy=true,character=Player.Character,generation=generation}
	-- Experimental pacing, not verification that the server accepted a state change.
	local lastPingSample=-math.huge
	local smoothedPing
	local function pacing()
		local now=os.clock()
		if now-lastPingSample>=1 then
			lastPingSample=now
			local ok,ping=pcall(function() return Player:GetNetworkPing() end)
			if ok and type(ping)=="number" and ping==ping and ping>=0 and ping<math.huge then
				smoothedPing=smoothedPing and smoothedPing*0.65+ping*0.35 or ping
			elseif not smoothedPing then smoothedPing=0.1 end
			run.pingMs=smoothedPing*1000
		end
		-- Preserve the existing low-ping path. Bound extra waits to avoid
		-- turning one activation into an indefinitely long operation.
		local extra=math.clamp((smoothedPing or 0.1)-0.05,0,0.15)
		run.phaseDelay=extra
		return extra
	end
	Hub.gucciRun=run
	Hub.gucciStage="Preparing"
	if Hub.updateGucciStatus then Hub.updateGucciStatus() end
	task.spawn(function()
		local ok,err=xpcall(function()
			if Hub.blobJump then Hub.blobJump:Disconnect(); Hub.blobJump = nil end
			if antiGucciConnection then antiGucciConnection:Disconnect(); antiGucciConnection = nil end
			local char = Player.Character
			if not char then return end
			local hum = char:WaitForChild("Humanoid", 5)
			local root = char:WaitForChild("HumanoidRootPart", 5)
			local function valid()
				return Hub.alive and generation == Hub.blobGeneration
					and Player.Character == char and char.Parent ~= nil
					and hum ~= nil and hum.Parent ~= nil and hum.Health > 0
					and root ~= nil and root.Parent ~= nil
			end
			if not valid() then return end
			-- Capture once before spawning or moving; jumps must not overwrite this.
			local returnCFrame = Hub.teleportFrame(root)
			local function findBlob()
				local folder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
				return folder and folder:FindFirstChild("CreatureBlobman")
			end
			local blob = findBlob()
			if not blob then
				spawnBlobman()
				local deadline = os.clock() + 8
				repeat
					if not valid() then return end
					blob = findBlob()
					if blob then break end
					task.wait(0.1)
				until os.clock() >= deadline
			end
			if not blob then notify("Anti Gucci", "Blobman did not appear.", 4); return end
			local seat
			local deadline = os.clock() + 5
			repeat
				if not valid() or not blob.Parent then return end
				seat = blob:FindFirstChildWhichIsA("VehicleSeat", true)
					or blob:FindFirstChildWhichIsA("Seat", true)
				if seat then break end
				task.wait(0.1)
			until os.clock() >= deadline
			if not seat then notify("Anti Gucci", "Blobman seat not found.", 4); return end
			if not valid() then return end
			-- Spawn replication may finish after spawnBlobman returns.
			local head = blob:FindFirstChild("Head")
			local headDeadline=os.clock()+5
			while valid() and blob.Parent and not head and os.clock()<headDeadline do
				task.wait(0.1)
				head=blob:FindFirstChild("Head")
			end
			if not valid() or not blob.Parent then return end
			if not (head and head:IsA("BasePart")) then
				notify("Anti Gucci", "Blobman head is not ready; try again.", 4)
				return
			end
			task.wait(0.2)
			if not valid() or not head.Parent then return end
			head.Anchored = true
			task.wait(0.2)
			if not valid() or not seat:IsDescendantOf(Workspace) then return end
			Hub.teleportPart(root, seat.CFrame + Vector3.new(0, 2, 0))
			Hub.gucciStage="Activating"
			if Hub.updateGucciStatus then Hub.updateGucciStatus() end
			task.wait(0.25)
			local completedCycles=0
			for _ = 1, 50 do
				local phaseDelay=pacing()
				if not valid() or not seat:IsDescendantOf(Workspace) then break end
				local ok, err = pcall(function()
					seat:Sit(hum)
					if ragdollRemoteEvent then Hub.fire(ragdollRemoteEvent, root, 0.1) end
					if phaseDelay>0 then task.wait(phaseDelay) end
					if not valid() or not seat:IsDescendantOf(Workspace) then return end
					hum.Sit = false
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
					if not valid() then return end
					hum.Jump = true
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end)
				if not ok then warn("[Arriva Anti Gucci] " .. tostring(err)); break end
				if not valid() or not seat:IsDescendantOf(Workspace) then break end
				completedCycles+=1
				task.wait(phaseDelay>0 and phaseDelay or nil)
			end
			if not valid() or completedCycles~=50 then return end
			run.cyclesFinishedAt=os.clock()
			if Hub.gucciAutoDelete then
				run.cleanupPending=true
				local cleanupTicket=Hub.gucciCleanupGeneration
				task.delay(2,function()
					if not Hub.gucciAutoDelete or cleanupTicket~=Hub.gucciCleanupGeneration then return end
					if not valid() or Hub.gucciRun~=run then return end
					local ownFolder=Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
					-- Remove only the exact owned toy used in this activation.
					if not ownFolder or blob.Parent~=ownFolder then
						run.cleanupPending=false
						return
					end
					local menu=ReplicatedStorage:FindFirstChild("MenuToys")
					local destroy=menu and menu:FindFirstChild("DestroyToy")
					if not destroy then
						run.cleanupPending=false
						notify("Gucci cleanup warning","Toy removal is unavailable. Your Blobman was left in place.",5)
						return
					end
					run.intentionalRemoval=true
					local removed,reason=pcall(function() Hub.fire(destroy,blob) end)
					if not removed then
						run.intentionalRemoval=false;run.cleanupPending=false
						notify("Gucci cleanup warning",tostring(reason),5)
						return
					end
					local deadline=os.clock()+3
					while valid() and blob.Parent==ownFolder and os.clock()<deadline do task.wait(0.1) end
					if not valid() or Hub.gucciRun~=run then return end
					run.cleanupPending=false
					run.removedIntentionally=blob.Parent~=ownFolder
					if not run.removedIntentionally then
						run.intentionalRemoval=false
						notify("Gucci cleanup warning","The toy removal was not confirmed. No extra activation was started.",5)
					elseif Hub.gucciStage=="Sequence finished - unverified" then
						Hub.gucciStage="Blobman removed - unverified"
						if Hub.updateGucciStatus then Hub.updateGucciStatus() end
					end
				end)
			end
			Hub.gucciStage="Releasing"
			if Hub.updateGucciStatus then Hub.updateGucciStatus() end
			-- Finish before returning, rather than racing a separate return task.
			if valid() then
				hum.Sit = false
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				task.wait(0.5)
				-- Sit=false is only a request: wait for the actual seat joint to release.
				local function attached()
					if hum.SeatPart == seat or seat.Occupant == hum then return true end
					for _, joint in ipairs(seat:GetChildren()) do
						if joint:IsA("Weld") or joint:IsA("WeldConstraint") or joint:IsA("Motor6D") then
							local a, b = joint.Part0, joint.Part1
							if (a and a:IsDescendantOf(char)) or (b and b:IsDescendantOf(char)) then
								return true
							end
						end
					end
					return false
				end
				local nextNotice=os.clock()+5
				while valid() and seat:IsDescendantOf(Workspace) and attached() do
					hum.Sit=false
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
					hum.Jump=true
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
					if os.clock()>=nextNotice then
						notify("Anti Gucci", "Still waiting for the seat to release; retrying. Disable Anti Gucci to cancel.", 4)
						nextNotice=os.clock()+15
					end
					task.wait(0.25)
				end
				if valid() then
					Hub.teleportPart(root, returnCFrame)
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
					run.ready=true
				end
			end
		end,debug.traceback)
		run.busy=false
		if Hub.gucciRun==run and generation==Hub.blobGeneration then
			Hub.gucciStage=not ok and "Error" or run.ready and (run.removedIntentionally and "Blobman removed - unverified" or "Sequence finished - unverified") or "Not ready"
			if Hub.updateGucciStatus then Hub.updateGucciStatus() end
			if not ok then warn("[Arriva Gucci] " .. tostring(err)) end
		end
	end)
end

local function stopAntiGucci()
	Hub.gucciStage="Disabled"
	if Hub.updateGucciStatus then Hub.updateGucciStatus() end
	Hub.blobGeneration = (Hub.blobGeneration or 0) + 1
	if Hub.blobJump then Hub.blobJump:Disconnect(); Hub.blobJump = nil end
	if antiGucciConnection then
		antiGucciConnection:Disconnect()
		antiGucciConnection = nil
	end
	local blobFolder = Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
	if blobFolder and blobFolder:FindFirstChild("CreatureBlobman") then
		blobFolder.CreatureBlobman:Destroy()
	end
end

-- Anti-Gucci Train System
local antiGucciConnectionTrain
local safePositionTrain
local restoreFramesTrain = 0

local function startAntiGucciTrain()
	Hub.trainGeneration = (Hub.trainGeneration or 0) + 1
	local generation = Hub.trainGeneration
	if Hub.trainJump then Hub.trainJump:Disconnect(); Hub.trainJump = nil end
	if antiGucciConnectionTrain then antiGucciConnectionTrain:Disconnect(); antiGucciConnectionTrain = nil end
	local char = Player.Character
	if not char then return end
	local hum = char:WaitForChild("Humanoid", 5)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	local function valid()
		return Hub.alive and generation == Hub.trainGeneration
			and Player.Character == char and char.Parent ~= nil
			and hum ~= nil and hum.Parent ~= nil and hum.Health > 0
			and root ~= nil and root.Parent ~= nil
	end
	if not valid() then return end
	local returnCFrame = Hub.teleportFrame(root)
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("AlwaysHereTweenedObjects")
	local train = folder and folder:FindFirstChild("Train")
	local object = train and train:FindFirstChild("Object")
	local model = object and object:FindFirstChild("ObjectModel")
	local seat = model and model:FindFirstChild("Seat")
	if not (seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat"))) then
		seat = train and (train:FindFirstChildWhichIsA("VehicleSeat", true)
			or train:FindFirstChildWhichIsA("Seat", true))
	end
	if not seat then notify("De-Sync", "Train seat not found.", 4); return end
	Hub.teleportPart(root, seat.CFrame + Vector3.new(0, 2, 0))
	task.spawn(function()
		for _ = 1, 30 do
			if not valid() or not seat:IsDescendantOf(Workspace) then break end
			local ok, err = pcall(function()
				seat:Sit(hum)
				if ragdollRemoteEvent then Hub.fire(ragdollRemoteEvent, root, 0.1) end
				if not valid() then return end
				hum.Sit = false
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				if not valid() then return end
				hum.Jump = true
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end)
			if not ok then warn("[Arriva Train] " .. tostring(err)); break end
			task.wait()
		end
		if valid() then
			hum.Sit = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			task.wait(0.5)
			if valid() then
				Hub.teleportPart(root, returnCFrame)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end)
end

local function stopAntiGucciTrain()
	Hub.trainGeneration = (Hub.trainGeneration or 0) + 1
	if Hub.trainJump then Hub.trainJump:Disconnect(); Hub.trainJump = nil end
	if antiGucciConnectionTrain then
		antiGucciConnectionTrain:Disconnect()
		antiGucciConnectionTrain = nil
	end
end

Hub.connect(Player.CharacterRemoving, function()
	Hub.gucciRespawnReadyAt=math.huge
	Hub.gucciStage=Toggles.AutoGucciBlobToggle and Toggles.AutoGucciBlobToggle.Value and "Waiting for respawn" or "Disabled"
	if Hub.updateGucciStatus then Hub.updateGucciStatus() end
	Hub.blobGeneration = (Hub.blobGeneration or 0) + 1
	Hub.trainGeneration = (Hub.trainGeneration or 0) + 1
	if antiGucciConnection then antiGucciConnection:Disconnect(); antiGucciConnection = nil end
	if antiGucciConnectionTrain then antiGucciConnectionTrain:Disconnect(); antiGucciConnectionTrain = nil end
	if Hub.blobJump then Hub.blobJump:Disconnect(); Hub.blobJump = nil end
	if Hub.trainJump then Hub.trainJump:Disconnect(); Hub.trainJump = nil end
end)
Hub.connect(Player.CharacterAdded, function(char)
	-- CharacterAdded may fire before either required part has replicated.
	-- Keep retrying this character; a later reset cancels this waiter.
	local readySince
	while Hub.alive and Player.Character == char do
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if char.Parent and root and root.Parent == char
			and hum and hum.Parent == char and hum.Health > 0 then
			readySince = readySince or os.clock()
			Hub.gucciRespawnReadyAt = readySince + 1.5
			if os.clock() >= Hub.gucciRespawnReadyAt then
				if Hub.resumeGucciAfterProtection then Hub.resumeGucciAfterProtection();return end
				if Toggles.AutoGucciBlobToggle and Toggles.AutoGucciBlobToggle.Value then
					if Hub.reportGucciStatus then Hub.reportGucciStatus("Starting") end
					task.spawn(startAntiGucci)
				end
				if Toggles.AutoGucciTrainToggle and Toggles.AutoGucciTrainToggle.Value then
					task.spawn(startAntiGucciTrain)
				end
				return
			end
		else
			readySince = nil
			Hub.gucciRespawnReadyAt = math.huge
		end
		task.wait(0.2)
	end
end)

-- Local health alerts. These do not attribute remote abuse or kick players.
do
	local group=Tabs.AntiLag:AddRightGroupbox("Connection & Client Health")
	local pingOn,framesOn=false,false
	local disconnectOn=false
	local disconnectLimit,disconnectSeconds=1500,10
	local disconnectBad,disconnectSent=0,false
	local pingLimit,fpsLimit,holdSeconds=350,20,3
	local connection
	local elapsed,frames,worstFrame=0,0,0
	local pingState={bad=0,active=false,last=-math.huge}
	local fpsState={bad=0,active=false,last=-math.huge}
	local unavailable=false
	local function reset(state)
		state.bad=0;state.active=false;state.last=-math.huge
	end
	local function observe(state,bad,recovered,seconds,title,message)
		if bad then
			state.bad+=seconds
			if state.bad>=holdSeconds then
				state.active=true
				if os.clock()-state.last>=30 then
					state.last=os.clock()
					notify(title,message,6)
				end
			end
		elseif recovered then
			state.bad=0
			if state.active then
				state.active=false
				notify("Health restored",title .. " has cleared.",4)
			end
		else
			state.bad=0
		end
	end
	local function updateConnection()
		if connection then connection:Disconnect();connection=nil end
		elapsed,frames,worstFrame=0,0,0
		reset(pingState);reset(fpsState);unavailable=false
		disconnectBad,disconnectSent=0,false
		if not pingOn and not framesOn and not disconnectOn then return end
		connection=Hub.connect(RunService.Heartbeat,function(dt)
			elapsed+=dt;frames+=1;worstFrame=math.max(worstFrame,dt)
			if elapsed<1 then return end
			local seconds=elapsed
			if pingOn or disconnectOn then
				local ok,ping=pcall(function() return Player:GetNetworkPing()*1000 end)
				if ok and type(ping)=="number" and ping==ping and ping>=0 and ping<math.huge then
					unavailable=false
					if pingOn then
						observe(pingState,ping>pingLimit,ping<pingLimit*0.8,
							math.min(seconds,1.5),"Connection warning",
							string.format("Your network ping is %.0f ms (limit %.0f ms). ",ping,pingLimit))
					end
					if disconnectOn and ping>disconnectLimit then
						-- A long stalled frame does not prove ping was high throughout it.
						disconnectBad+=math.min(seconds,1.5)
						if disconnectBad>=disconnectSeconds and not disconnectSent then
							disconnectSent=true
							local kicked,reason=pcall(function()
								Player:Kick(string.format("Connection protection: ping stayed above %.0f ms for %d seconds.",disconnectLimit,disconnectSeconds))
							end)
							if not kicked then notify("Connection error","Could not disconnect: " .. tostring(reason),6) end
						end
					else disconnectBad=0;disconnectSent=false end
				else
					disconnectBad=0
					if not unavailable then
						unavailable=true;reset(pingState)
						notify("Connection warning","Ping measurement is unavailable on this client. Automatic disconnect cannot act on missing measurements.",5)
					end
				end
			end
			if framesOn then
				local fps=frames/seconds
				observe(fpsState,fps<fpsLimit,fps>fpsLimit+5,
					math.min(seconds,1.5),"Client performance warning",
					string.format("Heartbeat rate averaged %.0f/s; longest frame %.0f ms. Local performance issue detected.",fps,worstFrame*1000))
			end
			elapsed,frames,worstFrame=0,0,0
		end)
	end
	group:AddToggle("HealthPingAlerts",{Text="High ping alerts",Default=false,
		Callback=function(on) pingOn=on;updateConnection() end})
	group:AddSlider("HealthPingLimit",{Text="Ping threshold (ms)",Default=350,Min=100,Max=3000,Rounding=0,
		Callback=function(value) pingLimit=value;reset(pingState) end})
	group:AddToggle("HealthFrameAlerts",{Text="Low client performance alerts",Default=false,
		Callback=function(on) framesOn=on;updateConnection() end})
	group:AddSlider("HealthFrameLimit",{Text="Heartbeat rate threshold",Default=20,Min=5,Max=60,Rounding=0,
		Callback=function(value) fpsLimit=value;reset(fpsState) end})
	group:AddSlider("HealthSustainSeconds",{Text="Sustained spike duration (seconds)",Default=3,Min=1,Max=15,Rounding=0,
		Callback=function(value) holdSeconds=value;reset(pingState);reset(fpsState) end})
	group:AddToggle("HealthDisconnectOnPing",{Text="Disconnect me on sustained high ping",Default=false,
		Callback=function(on) disconnectOn=on;updateConnection() end})
	group:AddSlider("HealthDisconnectPingLimit",{Text="Disconnect ping threshold (ms)",Default=1500,Min=250,Max=10000,Rounding=0,
		Callback=function(value) disconnectLimit=value;disconnectBad=0;disconnectSent=false end})
	group:AddSlider("HealthDisconnectDelay",{Text="Disconnect after high ping (seconds)",Default=10,Min=3,Max=60,Rounding=0,
		Callback=function(value) disconnectSeconds=value;disconnectBad=0;disconnectSent=false end})
	Hub.cleanup(function() if connection then connection:Disconnect();connection=nil end end)
end

-- Defense Tab
local DefenseGroup = Tabs.Defense:AddLeftGroupbox("Defense Main")
local DefenseExtra = Tabs.Defense:AddRightGroupbox("Extra Defense")

-- Anti Grab: react to actual held-state changes, with bounded local freezing.
do
	local enabled, recoverMovement = false, false
	local featureConnections, characterConnections = {}, {}
	local heldConnection, frozenCharacter, freezeConnection
	local savedAnchors = {}
	local generation, bindGeneration = 0, 0
	local frozenAt, nextAttempt = 0, 0
	local heldValue
	local freezeUsed = false
	local releasedCharacter, releasedUntil

	local function disconnect(list)
		for _, connection in ipairs(list) do connection:Disconnect(); Hub.connections[connection] = nil end
		table.clear(list)
	end
	local function listen(list, signal, callback)
		local connection = Hub.connect(signal, callback)
		table.insert(list, connection)
		return connection
	end
	local function release()
		generation += 1
		if freezeConnection then freezeConnection:Disconnect(); Hub.connections[freezeConnection] = nil; freezeConnection = nil end
		for part, anchored in pairs(savedAnchors) do
			pcall(function() if part.Parent then part.Anchored = anchored end end)
		end
		table.clear(savedAnchors)
		frozenCharacter = nil
	end
	Hub.releaseGrabProtection = release

	local function recover(char)
		if not recoverMovement or not enabled then return end
		local ticket = generation
		task.delay(0.2, function()
			if not enabled or not recoverMovement or generation ~= ticket or Player.Character ~= char
				or (heldValue and heldValue.Value) or Hub.safeZoneLoopActive or Hub.gucciCharacterBusy(char) then return end
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local ragdolled = hum and hum:FindFirstChild("Ragdolled")
			if not hum or hum.Health <= 0 or hum.SeatPart or (ragdolled and ragdolled.Value) then return end
			if hum.PlatformStand then
				hum.PlatformStand = false
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end

	local function detect()
		if not enabled or os.clock() < nextAttempt then return end
		local char = Player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then return end
		-- Keep deliberate seating and the safe-zone controller independent.
		if hum.SeatPart or Hub.safeZoneLoopActive or Hub.gucciCharacterBusy(char) then return end
		nextAttempt = os.clock() + 0.25
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- Resolve optional remotes at use time; map loading can replace them.
		local events = ReplicatedStorage:FindFirstChild("CharacterEvents")
		local struggle = events and events:FindFirstChild("Struggle")
		local ragdoll = events and events:FindFirstChild("RagdollRemote")
		local correction = ReplicatedStorage:FindFirstChild("GameCorrectionEvents")
		local stop = correction and correction:FindFirstChild("StopAllVelocity")
		for _, request in ipairs({{struggle}, {ragdoll, root, 0}, {stop}}) do
			if request[1] then pcall(function() Hub.fire(table.unpack(request)) end) end
		end
		if freezeUsed then return end
		freezeUsed = true
		release()
		frozenCharacter, frozenAt = char, os.clock()
		local cframe = Hub.teleportFrame(root)
		for _, part in ipairs(char:GetChildren()) do
			if part:IsA("BasePart") then savedAnchors[part] = part.Anchored; part.Anchored = true end
		end
		freezeConnection = Hub.connect(RunService.Heartbeat, function()
			if not enabled or Player.Character ~= char or not root.Parent or hum.Health <= 0
				or hum.SeatPart or Hub.safeZoneLoopActive or Hub.gucciCharacterBusy(char) or os.clock() - frozenAt >= 2 then release(); return end
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			Hub.teleportPart(root, cframe)
		end)
	end

	local function bindCharacter(char)
		bindGeneration += 1
		local ticket = bindGeneration
		disconnect(characterConnections)
		freezeUsed = false
		releasedCharacter, releasedUntil = nil, nil
		nextAttempt = 0
		release()
		if not enabled or not char then return end
		local observedOwners = {}
		local function inspect(object)
			if not enabled or ticket ~= bindGeneration or Player.Character ~= char then return end
			if object.Name == "PartOwner" and object:IsA("StringValue")
				and object.Parent == char:FindFirstChild("Head") and not observedOwners[object] then
				observedOwners[object] = true
				local function changed()
					if enabled and ticket == bindGeneration and object.Parent and object.Value ~= "" and object.Value ~= Player.Name then detect() end
				end
				listen(characterConnections, object:GetPropertyChangedSignal("Value"), changed)
				changed()
			elseif (object.Name == "HumanoidRootPart" or object:IsA("Humanoid")) and heldValue and heldValue.Value then detect() end
		end
		listen(characterConnections, char.DescendantAdded, inspect)
		for _, object in ipairs(char:GetDescendants()) do inspect(object) end
		if heldValue and heldValue.Value then detect() end
	end

	local function bindHeld(value)
		if heldConnection then heldConnection:Disconnect(); Hub.connections[heldConnection] = nil; heldConnection = nil end
		heldValue = value and value:IsA("BoolValue") and value or nil
		if not enabled or not heldValue then return end
		local previous = heldValue.Value
		heldConnection = Hub.connect(heldValue:GetPropertyChangedSignal("Value"), function()
			if not enabled then return end
			local held = heldValue.Value
			if held then
				releasedCharacter, releasedUntil = nil, nil
				if not previous then freezeUsed = false; generation += 1 end
				detect()
			else
				freezeUsed = false
				release()
				if previous then
					-- A throw can replicate just after IsHeld becomes false.
					releasedCharacter, releasedUntil = Player.Character, os.clock() + 0.3
					recover(Player.Character)
				end
			end
			previous = held
		end)
		if previous then detect() end
	end

	DefenseGroup:AddToggle("AntiGrabObsidian", {Text = "Anti Grab", Default = false, Callback = function(on)
		enabled = on
		nextAttempt = 0
		disconnect(featureConnections)
		bindCharacter(nil)
		bindHeld(nil)
		if not on then return end
		listen(featureConnections, RunService.Heartbeat, function()
			if heldValue and heldValue.Value then detect() end
			if releasedCharacter then
				local char = releasedCharacter
				local root = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if os.clock() >= releasedUntil or Player.Character ~= char or not root or not root.Parent
					or not hum or hum.Health <= 0 or hum.SeatPart or Hub.safeZoneLoopActive then
					releasedCharacter, releasedUntil = nil, nil
				else
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end)
		listen(featureConnections, Player.CharacterAdded, bindCharacter)
		listen(featureConnections, Player.CharacterRemoving, function() bindCharacter(nil) end)
		listen(featureConnections, Player.ChildAdded, function(child) if child.Name == "IsHeld" then bindHeld(child) end end)
		listen(featureConnections, Player.ChildRemoved, function(child) if child == heldValue then bindHeld(nil); release() end end)
		bindCharacter(Player.Character)
		bindHeld(Player:FindFirstChild("IsHeld"))
	end})
	DefenseGroup:AddToggle("RecoverMovementAfterGrab", {Text = "Recover movement after Anti Grab releases", Default = false,
		Callback = function(on) recoverMovement = on end})
	DefenseGroup:AddButton({Text = "Release local grab freeze", Func = function() freezeUsed = true; releasedCharacter, releasedUntil = nil, nil; release() end})
	Hub.cleanup(function()
		enabled, recoverMovement = false, false
		disconnect(featureConnections)
		bindCharacter(nil)
		bindHeld(nil)
		release()
		Hub.releaseGrabProtection = nil
	end)
end

Hub.blobParts = {}
local function anti(Descendant)
	for _, name in ipairs({"LeftDetector", "RightDetector"}) do
		local detector = Descendant:FindFirstChild(name)
		if detector then
			if detector:IsA("BasePart") then
				Hub.blobParts[detector] = true
				Hub.backup(detector, {"CanTouch", "CanCollide"})
				detector.CanTouch = false; detector.CanCollide = false
			end
			for _, constraint in ipairs(detector:GetDescendants()) do
				if constraint:IsA("Constraint") then
					Hub.blobParts[constraint] = true
					Hub.backup(constraint, {"Enabled"})
					constraint.Enabled = false
				end
			end
		end
	end
end

local antiBlob1T=false
local antiBlobWatcher
local function antiBlob1F()
	antiBlob1T=true
	Hub.blobScanEpoch=(Hub.blobScanEpoch or 0)+1;local ticket=Hub.blobScanEpoch

	if antiBlob1T then


		if antiBlobWatcher then antiBlobWatcher:Disconnect();Hub.connections[antiBlobWatcher]=nil end
		antiBlobWatcher=Hub.connect(workspace.DescendantAdded,function(object)
			if not antiBlob1T then return end
			if object.Name~="CreatureBlobman" and object.Name~="LeftDetector" and object.Name~="RightDetector" and not object:IsA("Constraint") then return end
			local model=object
			while model and model~=Workspace and model.Name~="CreatureBlobman" do model=model.Parent end
			if not model or model==Workspace or model.Parent==Workspace:FindFirstChild(Player.Name.."SpawnedInToys") then return end
			anti(model)
		end)
		Hub.scanDescendants(Workspace,function(object)
			if object.Name=="CreatureBlobman" and object.Parent~=Workspace:FindFirstChild(Player.Name.."SpawnedInToys") then anti(object) end
		end,function() return antiBlob1T and Hub.blobScanEpoch==ticket end)
	end
end

DefenseGroup:AddToggle("AntiBlobmanToggle", {
	Text="Anti Blobman",
	Default=false,
	Callback=function(on)
		Hub.requestSave()
		if on then antiBlob1F()
		else
			antiBlob1T = false
			if antiBlobWatcher then antiBlobWatcher:Disconnect(); antiBlobWatcher = nil end
			for obj in pairs(Hub.blobParts or {}) do Hub.restore(obj) end
			Hub.blobParts = {}
		end
	end
})

-- Legacy explosion protection.
local antiExplodeT=false
local antiExplodeConnection
local function antiExplodeF()
	antiExplodeT = true
	if antiExplodeConnection then antiExplodeConnection:Disconnect() end
	antiExplodeConnection = Hub.connect(workspace.ChildAdded, function(model)
		if not antiExplodeT or not model:IsA("BasePart") or model.Name ~= "Part" then return end
		local char = Player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or (model.Position - Hub.teleportFrame(hrp).Position).Magnitude > 20 then return end
		local original = hrp.Anchored
		hrp.Anchored = true
		task.delay(0.15, function() if hrp.Parent then hrp.Anchored = original end end)
		Hub.explosionAnchor = {hrp, original}
	end)
end
Hub.cleanup(function()
	if Hub.explosionAnchor then Hub.explosionAnchor[1].Anchored = Hub.explosionAnchor[2] end
end)

DefenseGroup:AddToggle("AntiExplosionToggle", {
	Text="Anti Explosion", 
	Default=false,
	Callback=function(on)
		Hub.requestSave()
		if on then antiExplodeF() else antiExplodeT=false; if antiExplodeConnection then antiExplodeConnection:Disconnect(); antiExplodeConnection=nil end end
	end
})
-- End explosion protection

-- Extinguisher visuals stay hidden locally for the hub session.
do
	local records={}
	local function belongs(object)
		local part=object
		while part and part~=Workspace do
			if part.Name=="ExtinguishPart" and part:IsA("BasePart") then
				local area=part.Parent
				local hole=area and area.Parent
				local map=hole and hole.Parent
				if area and (area.Name=="PoisonSmallHole" or area.Name=="PoisonBigHole")
					and hole and hole.Name=="Hole" and map and map.Name=="Map" and map.Parent==Workspace then return true end
			end
			part=part.Parent
		end
		return false
	end
	local function hide(object)
		if records[object] or not belongs(object) then return end
		local property,value
		if object:IsA("BasePart") then property,value="LocalTransparencyModifier",1
		elseif object:IsA("Decal") or object:IsA("Texture") then property,value="Transparency",1
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then property,value="ImageTransparency",1
		elseif object:IsA("SurfaceGui") or object:IsA("BillboardGui") then property,value="Enabled",false end
		if not property then return end
		local record={property=property,original=object[property]}
		records[object]=record
		object[property]=value
		record.connection=Hub.connect(object:GetPropertyChangedSignal(property),function()
			if Hub.alive and object.Parent and object[property]~=value then object[property]=value end
		end)
	end
	local function inspect(object)
		hide(object)
		if object.Name=="Map" or object.Name=="Hole" or object.Name=="PoisonSmallHole"
			or object.Name=="PoisonBigHole" or object.Name=="ExtinguishPart" then
			for _,child in ipairs(object:GetDescendants()) do hide(child) end
		end
	end
	Hub.connect(Workspace.DescendantAdded,inspect)
	Hub.connect(Workspace.DescendantRemoving,function(object)
		local record=records[object]
		if not record then return end
		record.connection:Disconnect();Hub.connections[record.connection]=nil
		pcall(function() object[record.property]=record.original end)
		records[object]=nil
	end)
	local map=Workspace:FindFirstChild("Map")
	if map then inspect(map) end
	Hub.cleanup(function()
		for object,record in pairs(records) do
			record.connection:Disconnect();Hub.connections[record.connection]=nil
			pcall(function() object[record.property]=record.original end)
		end
		table.clear(records)
	end)
end
-- End extinguisher visual suppression

do
	-- Anti Burn: local extinguisher visibility restoration.
	local antiBurnEnabled = false
	local burnThreadToken = 0

	local function getExtinguisher()
		local map = workspace:FindFirstChild("Map")
		local hole = map and map:FindFirstChild("Hole")
		local poison = hole and hole:FindFirstChild("PoisonBigHole")
		local part = poison and poison:FindFirstChild("ExtinguishPart")

		return part and part:IsA("BasePart") and part or nil
	end

	local function hookBurn(char)
		burnThreadToken += 1
		local token = burnThreadToken

		task.spawn(function()
			while antiBurnEnabled
				and char.Parent
				and token == burnThreadToken do

				local hum = char:FindFirstChildOfClass("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart")
				local firePart = root and root:FindFirstChild("FirePlayerPart")
				local debounce =
					hum and hum:FindFirstChild("FireDebounce")
					or firePart and firePart:FindFirstChild("FireDebounce")

				local extinguisher = getExtinguisher()

				if debounce and debounce.Value and firePart and extinguisher then
					Hub.burnOriginal = Hub.burnOriginal or {
						part = extinguisher,
						cf = extinguisher.CFrame,
					}

					extinguisher.CFrame = firePart.CFrame

					if firetouchinterest then
						pcall(firetouchinterest, firePart, extinguisher, 0)
						task.wait(0.05)
						pcall(firetouchinterest, firePart, extinguisher, 1)
					end
				end

				task.wait(0.2)
			end
		end)
	end

	local function restoreBurn()
		burnThreadToken += 1

		if Hub.burnOriginal then
			pcall(function()
				Hub.burnOriginal.part.CFrame = Hub.burnOriginal.cf
			end)
			Hub.burnOriginal = nil
		end

	end

	Hub.cleanup(restoreBurn)

	Hub.connect(Player.CharacterAdded, function(char)
		if antiBurnEnabled then
			hookBurn(char)
		end
	end)

	DefenseGroup:AddToggle("AntiBurnToggle", {
		Text = "Anti Burn",
		Default = false,

		Callback = function(on)
			antiBurnEnabled = on
			Hub.requestSave()

			if on then
				local extinguisher = getExtinguisher()

				if not extinguisher then
					notify("Anti Burn", "Extinguisher not found in this map.", 5)
				end

				if Player.Character then
					hookBurn(Player.Character)
				end
			else
				restoreBurn()
			end
		end,
	})

end

-- Ground-validated recovery points shared by Anti Void and motion protection.
function Hub.validSelfRecoveryGround(saved, char)
	if not saved or saved.character ~= char or Player.Character ~= char then return false end
	local part = saved.part
	return part and part.Parent and part:IsDescendantOf(Workspace) and part.Anchored and part.CanCollide
		and not Hub.playerOf(part) and part.CFrame == saved.groundCFrame
		and (part.Position - saved.groundPosition).Magnitude < 1
end
function Hub.captureSelfRecoveryGround(char, root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local hit = Workspace:Raycast(Hub.teleportFrame(root).Position, Vector3.new(0, -8, 0), params)
	if hit and hit.Normal.Y >= 0.6 and hit.Instance:IsA("BasePart") and hit.Instance.Anchored
		and hit.Instance.CanCollide and not Hub.playerOf(hit.Instance) then
		return {character = char, part = hit.Instance, groundPosition = hit.Instance.Position, groundCFrame = hit.Instance.CFrame, cframe = Hub.teleportFrame(root)}
	end
end

do
	local enabled, connection = false, nil
	local saved, character
	local lastSample, lastRecovery = -math.huge, -math.huge
	local recoveries = 0
	local status = DefenseGroup:AddLabel("Anti Void returns you to safety below the configured height.")
	local function finiteVector(value)
		for _, number in ipairs({value.X, value.Y, value.Z}) do
			if number ~= number or math.abs(number) == math.huge then return false end
		end
		return true
	end
	local function current()
		local char = Player.Character
		if character ~= char then character = char; saved = nil end
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local held = Player:FindFirstChild("IsHeld")
		if not root or not hum or hum.Health <= 0 or hum.SeatPart or root.Anchored
			or (held and held.Value) or Hub.safeZoneLoopActive then return nil end
		return char, root
	end
	local function record()
		local char, root = current()
		if not root or not finiteVector(Hub.teleportFrame(root).Position) or not finiteVector(root.AssemblyLinearVelocity)
			or not finiteVector(root.AssemblyAngularVelocity) or root.AssemblyLinearVelocity.Magnitude > 50
			or root.AssemblyAngularVelocity.Magnitude > 20 then return false end
		local candidate = Hub.captureSelfRecoveryGround(char, root)
		if not candidate then return false end
		saved = candidate
		status:SetText("Safe ground recorded for this character.")
		return true
	end
	local function recover()
		local char, root = current()
		if not root or os.clock() - lastRecovery < 1 or not Hub.validSelfRecoveryGround(saved, char) then return false end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		Hub.teleportPart(root, saved.cframe)
		lastRecovery = os.clock()
		recoveries += 1
		status:SetText(string.format("Returned to safe ground %d time(s).", recoveries))
		return true
	end
	local function sample()
		if not enabled then return end
		local char, root = current()
		if not root then return end
		if saved and not Hub.validSelfRecoveryGround(saved, char) then saved = nil end
		local threshold = math.max(-50, Workspace.FallenPartsDestroyHeight + 25)
		if not finiteVector(Hub.teleportFrame(root).Position) or Hub.teleportFrame(root).Position.Y < threshold then
			if not recover() and not saved then status:SetText("No valid safe ground recorded; cannot recover yet.") end
			return
		end
		if os.clock() - lastSample >= 0.2 then
			lastSample = os.clock()
			if Hub.teleportFrame(root).Position.Y > threshold + 5 then record() end
		end
	end
	Hub.sampleVoidProtection = sample
	DefenseGroup:AddToggle("AntiVoidToggle", {Text = "Anti Void", Default = false, Callback = function(on)
		enabled = on
		if connection then connection:Disconnect(); Hub.connections[connection] = nil; connection = nil end
		saved, character = nil, Player.Character
		lastSample = -math.huge
		if on then
			status:SetText("Anti Void: waiting for grounded, stable movement.")
			sample()
			connection = Hub.connect(RunService.Heartbeat, sample)
		else status:SetText("Anti Void returns you to safety below the configured height.") end
	end})
	DefenseGroup:AddButton({Text = "Record safe ground here", Func = function()
		if not record() then notify("Recovery", "Stand still on solid anchored ground outside seats and grabs first.", 5) end
	end})
	DefenseGroup:AddButton({Text = "Return to last safe ground", Func = function()
		if not recover() then notify("Recovery", "No valid recovery point, or recovery is paused by seating, a grab or the safe-zone loop.", 5) end
	end})
	Hub.connect(Player.CharacterRemoving, function() saved = nil; character = nil end)
	Hub.cleanup(function()
		enabled = false; saved = nil
		if connection then connection:Disconnect(); Hub.connections[connection] = nil; connection = nil end
		Hub.sampleVoidProtection = nil
	end)
end

-- Optional self-only recovery. No target, ownership or grab remotes.
do
	(function()
		local group=DefenseGroup
		local enabled=false
		local linearLimit,angularLimit=350,100
		local lastCharacter,lastGround,lastSample,lastAction=nil,nil,0,-math.huge
		local recoveries=0
		local function finite(value)
			return type(value)=="number" and value==value and math.abs(value)<math.huge
		end
		local function vectorOK(value) return finite(value.X) and finite(value.Y) and finite(value.Z) end
		local function sample()
			if not enabled then return end
			local char=Player.Character
			if char~=lastCharacter then lastCharacter=char;lastGround=nil end
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			local held=Player:FindFirstChild("IsHeld")
			if not root or not hum or hum.Health<=0 or hum.SeatPart or root.Anchored
				or (held and held.Value) or Hub.safeZoneLoopActive or Hub.gucciCharacterBusy(char) then return end
			local velocity,rotation=root.AssemblyLinearVelocity,root.AssemblyAngularVelocity
			local unsafe=not vectorOK(Hub.teleportFrame(root).Position) or not vectorOK(velocity) or not vectorOK(rotation)
				or velocity.Magnitude>linearLimit or rotation.Magnitude>angularLimit
			local now=os.clock()
			if unsafe then
				root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
				if Hub.validSelfRecoveryGround(lastGround,char) and now-lastAction>=1 then
					Hub.teleportPart(root, lastGround.cframe);lastAction=now;recoveries+=1
				end
				return
			end
			if now-lastSample<0.25 or not vectorOK(Hub.teleportFrame(root).Position) then return end
			lastSample=now
			if Hub.teleportFrame(root).Position.Y<=Workspace.FallenPartsDestroyHeight+12 then return end
			local candidate=velocity.Magnitude<=50 and rotation.Magnitude<=20 and Hub.captureSelfRecoveryGround(char,root)
			if candidate then lastGround=candidate end
		end
		Hub.sampleMotionProtection=sample
		group:AddToggle("LocalMotionProtection",{Text="Extreme velocity recovery",Default=false,Callback=function(on)
			enabled=on;lastCharacter=nil;lastGround=nil;lastSample=0
		end})
		group:AddSlider("LocalMotionLinearLimit",{Text="Recovery speed limit",Default=350,Min=100,Max=2000,Rounding=0,Callback=function(value) linearLimit=value end})
		group:AddSlider("LocalMotionAngularLimit",{Text="Recovery spin limit",Default=100,Min=20,Max=500,Rounding=0,Callback=function(value) angularLimit=value end})
		local conn
		conn=Hub.connect(RunService.Heartbeat,function() sample() end)
		group:AddButton("Motion recovery status",function() notify("Motion protection",string.format("Ground recovery used %d times this session.",recoveries),4) end)
		Hub.cleanup(function() enabled=false;lastGround=nil;Hub.sampleMotionProtection=nil end)
	end)()
end

do
	(function()
		local enabled=false
		local conn
		local function disconnect() if conn then conn:Disconnect();Hub.connections[conn]=nil;conn=nil end end
		local function bind(char)
			disconnect()
			if not enabled or not char then return end
			local function release(active,seat)
				if not enabled or not active or Player.Character~=char then return end
				-- Preserve only the active current-character Gucci seat (all supported vehicles).
				local run=Hub.gucciSeatRun
				if run and run.Char==char and run.Seat==seat then return end
				-- Preserve the hub's deliberate Blobman seating sequence.
				local cursor=seat
				while cursor and cursor~=Workspace do
					if cursor.Name=="CreatureBlobman" and cursor.Parent==Workspace:FindFirstChild(Player.Name.."SpawnedInToys") then return end
					cursor=cursor.Parent
				end
				local hum=char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health>0 then hum.Jump=true end
			end
			local hum=char:FindFirstChildOfClass("Humanoid")
			if hum then conn=Hub.connect(hum.Seated,release);release(hum.SeatPart~=nil,hum.SeatPart) end
		end
		DefenseGroup:AddToggle("LocalUnwantedSeatProtection",{Text="Jump out of unwanted seats",Default=false,Callback=function(on) enabled=on;bind(Player.Character) end})
		Hub.connect(Player.CharacterAdded,function(char)
			task.defer(function()
				if not enabled then return end
				char:WaitForChild("Humanoid",5)
				if Hub.alive and Player.Character==char then bind(char) end
			end)
		end)
		Hub.cleanup(function() enabled=false;disconnect() end)
	end)()
end

do
	(function()
		local enabled=false
		local history={};local rosterEvent="none";local rosterTime=-math.huge
		local group=Tabs.AntiLag:AddRightGroupbox("Frame Spike Diagnostics")
		local function roster(kind,person) rosterEvent=kind.." "..person.Name;rosterTime=os.clock() end
		Hub.connect(Players.PlayerAdded,function(person) roster("join",person) end)
		Hub.connect(Players.PlayerRemoving,function(person) roster("leave",person) end)
		local connection
		group:AddToggle("FrameSpikeDiagnostics",{Text="Record frame spikes",Default=false,Callback=function(on)
			enabled=on
			if connection then connection:Disconnect();Hub.connections[connection]=nil;connection=nil end
			if on then connection=Hub.connect(RunService.Heartbeat,function(dt)
					if dt<0.1 then return end
					table.insert(history,{ms=math.floor(dt*1000+0.5),near=os.clock()-rosterTime<3 and rosterEvent or "no recent roster change"})
					if #history>12 then table.remove(history,1) end
				end) end
		end})
		group:AddButton("Show frame spike report",function()
			local lines={};for _,entry in ipairs(history) do table.insert(lines,string.format("%d ms, %s",entry.ms,entry.near)) end
			print("[Arriva frame spikes]\n"..(#lines>0 and table.concat(lines,"\n") or "No frame spikes recorded."))
			notify("Frame diagnostics",string.format("%d recent spikes recorded. Details printed to F9. Timing correlation does not identify the cause.",#history),5)
		end)
		Hub.cleanup(function() table.clear(history) end)
	end)()
end

-- Anti-Sticky: disable the local touch detector, restoring its original state.
do
	(function()
		local enabled=false
		local saved,listeners,folders={},{},{}
		local status=DefenseGroup:AddLabel("Anti Sticky removes unwanted sticky connections.")
		local function connect(event,callback)
			local connection=Hub.connect(event,callback)
			table.insert(listeners,connection)
		end
		local function inspect(object)
			if not enabled or not object:IsA("LocalScript") or object.Name~="StickyPartsTouchDetection" then return end
			if saved[object]~=nil then return end
			saved[object]=object.Disabled
			object.Disabled=true
			connect(object:GetPropertyChangedSignal("Disabled"),function()
				if enabled and object.Parent and not object.Disabled then object.Disabled=true end
			end)
			status:SetText("StickyPartsTouchDetection disabled locally. This also affects your own sticky toys.")
		end
		local function watchFolder(folder)
			if not enabled or folder.Name~="PlayerScripts" or folders[folder] then return end
			folders[folder]=true
			connect(folder.DescendantAdded,inspect)
			for _,object in ipairs(folder:GetDescendants()) do inspect(object) end
		end
		local function stop()
			enabled=false
			for _,connection in ipairs(listeners) do connection:Disconnect();Hub.connections[connection]=nil end
			table.clear(listeners);table.clear(folders)
			for object,disabled in pairs(saved) do
				pcall(function() if object.Parent then object.Disabled=disabled end end)
			end
			table.clear(saved)
			status:SetText("Anti Sticky removes unwanted sticky connections.")
		end
		DefenseGroup:AddToggle("AntiStickyToggle",{Text="Anti Sticky",Default=false,Callback=function(on)
			stop();enabled=on;Hub.requestSave()
			if not on then return end
			status:SetText("Waiting for PlayerScripts.StickyPartsTouchDetection...")
			connect(Player.ChildAdded,watchFolder)
			local folder=Player:FindFirstChild("PlayerScripts")
			if folder then watchFolder(folder) end
		end})
		Hub.cleanup(stop)
	end)()
end


local function isFromLocalPlayer(inst)
	return Player.Character and inst:IsDescendantOf(Player.Character)
end

do
	-- Anti Lag: continuously disable the actual line script and prune foreign beams locally.
	local state = {on = false, generation = 0, scripts = {}, scriptConnections = {}, listeners = {}, removed = 0}
	Hub.antiLag = state
	local function listen(signal, callback)
		-- Avoid the general callback wrapper on the potentially flooded Workspace signal.
		local connection = signal:Connect(callback)
		state.listeners[connection] = true
		Hub.connections[connection] = true
		return connection
	end
	local function isOwnBeam(obj)
		local char = Player.Character
		if char and obj:IsDescendantOf(char) then return true end
		local toys = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
		if toys and obj:IsDescendantOf(toys) then return true end
		local current = obj.Parent
		while current and current ~= Workspace do
			if current.Name == "GrabParts" and current.Parent == Workspace then return true end
			current = current.Parent
		end
		return false
	end
	local function pruneBeam(obj)
		if not state.on or not obj:IsA("Beam") or not obj.Parent or isOwnBeam(obj) then return end
		local ok = pcall(function() obj:Destroy() end)
		if ok then state.removed += 1 end
	end
	local function enforceScript(script)
		if not state.on or not script:IsA("LocalScript") or script.Name ~= "CharacterAndBeamMove" then return end
		if state.scripts[script] == nil then
			state.scripts[script] = script.Disabled
			local disabledConnection = listen(script:GetPropertyChangedSignal("Disabled"), function()
				if state.on and script.Parent and not script.Disabled then script.Disabled = true end
			end)
			local destroyingConnection = listen(script.Destroying, function()
				state.scripts[script] = nil
				for _, connection in ipairs(state.scriptConnections[script] or {}) do
					connection:Disconnect(); state.listeners[connection] = nil; Hub.connections[connection] = nil
				end
				state.scriptConnections[script] = nil
			end)
			state.scriptConnections[script] = {disabledConnection, destroyingConnection}
		end
		if not script.Disabled then script.Disabled = true end
	end
	local function scanScripts(container)
		if not container or not state.on then return end
		for _, obj in ipairs(container:GetDescendants()) do enforceScript(obj) end
	end
	local function restore()
		state.on = false
		state.generation += 1
		for connection in pairs(state.listeners) do
			connection:Disconnect()
			Hub.connections[connection] = nil
		end
		table.clear(state.listeners)
		for script, disabled in pairs(state.scripts) do
			pcall(function() if script.Parent then script.Disabled = disabled end end)
		end
		table.clear(state.scripts)
		table.clear(state.scriptConnections)
		state.characterConnection = nil
	end
	local function hookCharacter(char)
		if state.characterConnection then
			state.characterConnection:Disconnect()
			state.listeners[state.characterConnection] = nil
			Hub.connections[state.characterConnection] = nil
		end
		scanScripts(char)
		state.characterConnection = listen(char.DescendantAdded, enforceScript)
	end
	local function enable()
		restore()
		state.on = true
		local generation = state.generation
		-- Attach watchers before scanning, so late scripts and beams are not missed.
		listen(Player.DescendantAdded, function(obj)
			enforceScript(obj)
			if obj:IsA("PlayerScripts") then scanScripts(obj) end
		end)
		listen(Player.CharacterAdded, hookCharacter)
		listen(Workspace.DescendantAdded, pruneBeam)
		scanScripts(Player:FindFirstChildOfClass("PlayerScripts"))
		if Player.Character then hookCharacter(Player.Character) end
		task.spawn(function()
			for index, obj in ipairs(Workspace:GetDescendants()) do
				if not state.on or generation ~= state.generation then return end
				pruneBeam(obj)
				if index % 200 == 0 then task.wait() end
			end
		end)
	end
	Hub.cleanup(restore)
	local AutoLagGroup = Tabs.AntiLag:AddLeftGroupbox("Automatic Line Protection")
	-- Automatic local mitigation; manual Anti Lag always takes priority.
	local autoOn,manualOn,autoActive=false,false,false
	local threshold,windowSeconds,quietSeconds=40,1,8
	local count,windowStart,lastLine=0,0,-math.huge
	local burstConnection,quietConnection
	local pending=false
	local autoEpoch=0
	local function applyAntiLag()
		local wanted=manualOn or autoActive
		if wanted and not state.on then enable()
		elseif not wanted and state.on then restore() end
	end
	local function stopAuto()
		autoEpoch+=1
		autoOn=false
		if burstConnection then burstConnection:Disconnect();burstConnection=nil end
		if quietConnection then quietConnection:Disconnect();quietConnection=nil end
		count=0;autoActive=false;pending=false
		applyAntiLag()
	end
	local function startAuto()
		stopAuto()
		autoOn=true;windowStart=os.clock();lastLine=-math.huge
		local watchEpoch=autoEpoch
		-- Direct, non-yielding filtered listener: no per-object tasks or repeated map scans.
		burstConnection=Workspace.DescendantAdded:Connect(function(obj)
			if not Hub.alive or not autoOn or not obj:IsA("Beam") or not obj.Parent or isOwnBeam(obj) then return end
			local now=os.clock()
			lastLine=now
			if now-windowStart>=windowSeconds then windowStart=now;count=0 end
			count+=1
			if count>=threshold and not autoActive and not pending then
				pending=true
				task.defer(function()
					if watchEpoch~=autoEpoch then return end
					pending=false
					if not Hub.alive or not autoOn or autoActive then return end
					autoActive=true
					applyAntiLag()
					notify("Auto Anti Lag", "Line burst detected, local Anti Lag enabled temporarily.",5)
				end)
			end
		end)
		local elapsed=0
		quietConnection=RunService.Heartbeat:Connect(function(dt)
			elapsed+=dt
			if elapsed<0.25 then return end
			elapsed=0
			if autoActive and os.clock()-lastLine>=quietSeconds then
				autoActive=false;count=0
				applyAntiLag()
				notify("Auto Anti Lag",manualOn and "Line burst settled, manual Anti Lag remains enabled."
					or "Line burst settled, previous Anti Lag setting restored.",4)
			end
		end)
	end
	-- Preserve the saved manual toggle; automatic activation never changes its value.
	Hub.setManualAntiLag=function(on) manualOn=on;applyAntiLag() end
	AutoLagGroup:AddToggle("AutoLineAntiLag",{Text="Auto Anti Lag (line bursts)",Default=false,
		Callback=function(on) if on then startAuto() else stopAuto() end end})
	AutoLagGroup:AddSlider("AutoLineThreshold",{Text="Foreign beam spawns per window",Default=40,Min=5,Max=500,Rounding=0,
		Callback=function(value) threshold=value;count=0;windowStart=os.clock() end})
	AutoLagGroup:AddSlider("AutoLineWindow",{Text="Detection window (seconds)",Default=1,Min=1,Max=5,Rounding=0,
		Callback=function(value) windowSeconds=value;count=0;windowStart=os.clock() end})
	AutoLagGroup:AddSlider("AutoLineQuiet",{Text="Restore after quiet period (seconds)",Default=8,Min=3,Max=60,Rounding=0,
		Callback=function(value) quietSeconds=value end})
	Hub.cleanup(function()
		-- Disconnect first; normal Anti Lag cleanup restores the line script.
		autoOn=false
		if burstConnection then burstConnection:Disconnect();burstConnection=nil end
		if quietConnection then quietConnection:Disconnect();quietConnection=nil end
		Hub.setManualAntiLag=nil
	end)

	DefenseGroup:AddToggle("AntiLagToggle", {
		Text = "Force Anti Lag", Default = false,
		Callback = function(on)
			Hub.setManualAntiLag(on)
			Hub.requestSave()
		end,
	})
	AutoLagGroup:AddButton({Text = "Anti Lag status", Func = function()
		local scripts, disabled = 0, 0
		for script in pairs(state.scripts) do
			if script.Parent then scripts += 1; if script.Disabled then disabled += 1 end end
		end
		local message = string.format("%s | Line scripts disabled: %d/%d | Foreign beams removed: %d",
			state.on and "On" or "Off", disabled, scripts, state.removed)
		if state.on and scripts == 0 then message ..= " | CharacterAndBeamMove not found yet, watching for it." end
		notify("Anti Lag", message, 8)
	end})
end

-- WARNING MONITOR BEGIN: notification only; no character or enforcement changes.
do
	local gui, observed, connections = nil, {}, {}
	local count, lastAlert, alive = 0, -math.huge, false
	local function visible(label)
		if label.TextTransparency >= 1 then return false end
		local current = label
		while current and current ~= gui do
			if current:IsA("GuiObject") and not current.Visible then return false end
			if current:IsA("LayerCollector") and not current.Enabled then return false end
			current = current.Parent
		end
		return current == gui
	end

	local function evaluate(label)
		local state = observed[label]
		if not alive or not state then return end
		local message = string.lower(label.Text):gsub("%s+", " ")
		local matches = message:find("the game thinks you may be flying", 1, true)
			and message:find("put you on the ground", 1, true)
		local active = matches ~= nil and visible(label)
		if active and not state.active and os.clock() - lastAlert >= 1 then
			lastAlert = os.clock()
			count += 1
			local notice = "Anti-flight warning observed (" .. count .. " this session)."
			warn("[Warning Monitor] " .. notice .. " This is not the server's strike count.")
			notify("Movement warning", notice, 8)
			local char = Player.Character
			local hum = char and char:FindFirstChild("Humanoid")

			if hum and hum.Health > 0 then
				hum.Health = 0
			end
		end
		state.active = active
	end

	local function observe(label)
		if observed[label] or not (label:IsA("TextLabel") or label:IsA("TextBox") or label:IsA("TextButton")) then return end
		local state = { active = false, connections = {} }
		observed[label] = state
		local function listen(signal, callback)
			table.insert(state.connections, signal:Connect(callback))
		end
		listen(label:GetPropertyChangedSignal("Text"), function() evaluate(label) end)
		listen(label:GetPropertyChangedSignal("TextTransparency"), function() evaluate(label) end)
		-- Watch ancestor visibility because games often reuse the same warning label.
		local function bindAncestors()
			for _, connection in ipairs(state.ancestors or {}) do connection:Disconnect() end
			state.ancestors = {}
			local current = label
			while current and current ~= gui do
				local property = current:IsA("GuiObject") and "Visible"
					or current:IsA("LayerCollector") and "Enabled"
				if property then
					table.insert(state.ancestors, current:GetPropertyChangedSignal(property):Connect(function() evaluate(label) end))
				end
				current = current.Parent
			end
			evaluate(label)
		end
		listen(label.AncestryChanged, bindAncestors)
		listen(label.Destroying, function()
			for _, connection in ipairs(state.connections) do connection:Disconnect() end
			for _, connection in ipairs(state.ancestors or {}) do connection:Disconnect() end
			observed[label] = nil
		end)
		bindAncestors()
	end


	local function stop()
		alive = false
		for _, connection in ipairs(connections) do connection:Disconnect() end
		for _, state in pairs(observed) do
			for _, connection in ipairs(state.connections) do connection:Disconnect() end
			for _, connection in ipairs(state.ancestors or {}) do connection:Disconnect() end
		end
		table.clear(connections)
		table.clear(observed)
	end
	local function start()
		if alive then return end
		gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not gui then notify("Movement warning", "PlayerGui is unavailable, enable the monitor again when loaded.", 8); return end
		alive = true
		table.insert(connections, gui.DescendantAdded:Connect(observe))
		for _, descendant in ipairs(gui:GetDescendants()) do observe(descendant) end
	end
	Hub.cleanup(stop)
	DefenseGroup:AddToggle("MovementWarningMonitor", {
		Text = "Movement warning monitor", Default = false,
		Callback = function(on)
			if on then start() else stop() end
			Hub.requestSave()
		end,
	})
	DefenseGroup:AddButton({Text = "Movement warning count", Func = function()
		notify("Movement warning", tostring(count) .. " observed this session | " .. (alive and "Monitoring" or "Off"), 8)
	end})
	DefenseGroup:AddButton({Text = "Clear observed warning count", Func = function()
		count = 0
		notify("Movement warning", "Local display counter cleared.", 6)
	end})
end
-- WARNING MONITOR END

-- Extra Defense Toggles
DefenseExtra:AddToggle("PaintDeleteToggle", {
	Text = "Anti Paint",
	Default = false,
	Callback = function(state)
		if state then
			deleteAllPaintParts()
			watchNewPaintParts()
			setTouchQuery(false)
		else
			restorePaintParts()
			disconnectWatchers()
			setTouchQuery(true)
		end
	end
})

-- Auto Gucci System (Blobman): one monitor and one activation at a time.
do
	local enabled=false
	local monitorGeneration=0
	local status=DefenseExtra:AddLabel("Gucci status: off.")
	Hub.updateGucciStatus=function() status:SetText("Gucci: " .. (Hub.gucciStage or "Disabled")) end
	DefenseExtra:AddToggle("GucciAutoDeleteBlob",{
		Text="Auto-delete Blobman after Gucci",Default=true,
		Callback=function(on)
			Hub.gucciAutoDelete=on
			Hub.gucciCleanupGeneration=(Hub.gucciCleanupGeneration or 0)+1
			local run=Hub.gucciRun
			if not on and run and not run.intentionalRemoval then run.cleanupPending=false end
		end,
	})
	DefenseExtra:AddToggle("AutoGucciBlobToggle",{
		Text="[GUCCI] Anti Grab",Default=false,
		Callback=function(on)
			enabled=on
			monitorGeneration+=1
			local ticket=monitorGeneration
			if not on then stopAntiGucci();return end
			startAntiGucci()
			task.spawn(function()
				local nextRetry=os.clock()+8
				while enabled and Hub.alive and ticket==monitorGeneration do
					task.wait(0.5)
					if not enabled or not Hub.alive or ticket~=monitorGeneration then return end
					local char=Player.Character
					local hum=char and char:FindFirstChildOfClass("Humanoid")
					local root=char and char:FindFirstChild("HumanoidRootPart")
					local folder=Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
					local blob=folder and folder:FindFirstChild("CreatureBlobman")
					local run=Hub.gucciRun
					local busy=run and run.busy and run.generation==Hub.blobGeneration
					local intentional=run and run.generation==Hub.blobGeneration
						and (run.cleanupPending or run.intentionalRemoval or run.removedIntentionally)
					if char and hum and root and hum.Health>0 and not busy and not intentional and os.clock()>=nextRetry
						and os.clock()>=(Hub.gucciRespawnReadyAt or 0)
						and (not blob or Hub.gucciStage=="Not ready" or Hub.gucciStage=="Error") then
						nextRetry=os.clock()+8
						startAntiGucci()
					end
				end
			end)
		end,
	})
	Hub.cleanup(function()
		enabled=false;monitorGeneration+=1
		Hub.blobGeneration=(Hub.blobGeneration or 0)+1
		Hub.updateGucciStatus=nil
	end)
end

-- Gucci remains unverified: transient local attachment changes are not proof of release.
-- De-Sync System (Train)
local autoGucciActiveTrain = false
local autoGucciActiveTrainMonitorGeneration = 0
DefenseExtra:AddToggle("AutoGucciTrainToggle", {
	Text = "De-Sync",
	Default = false,
	Callback = function(Value)
		autoGucciActiveTrain = Value
		autoGucciActiveTrainMonitorGeneration += 1
		local monitorTicket = autoGucciActiveTrainMonitorGeneration

		if Value then
			startAntiGucciTrain()
			notify("system", "De-Sync active (monitoring)", 3)

			task.spawn(function()
				while autoGucciActiveTrain and Hub.alive and monitorTicket == autoGucciActiveTrainMonitorGeneration do
					local trainFolder = (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("AlwaysHereTweenedObjects"))
					local trainExists = trainFolder and trainFolder:FindFirstChild("Train")

					if not trainExists then
						stopAntiGucciTrain()
						notify("System", "Train lost", 3)

						local retries = 0
						repeat
							task.wait(0.2)
							retries = retries + 1
							trainFolder = (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("AlwaysHereTweenedObjects"))
						until (trainFolder and trainFolder:FindFirstChild("Train")) or retries > 25 or not autoGucciActiveTrain or monitorTicket ~= autoGucciActiveTrainMonitorGeneration

						if autoGucciActiveTrain and monitorTicket == autoGucciActiveTrainMonitorGeneration and trainFolder and trainFolder:FindFirstChild("Train") then
							startAntiGucciTrain()
							notify("System", "Train restored.", 3)
						end
					end
					task.wait(0.5)
				end
			end)
		else
			autoGucciActiveTrain = false
			stopAntiGucciTrain()
			notify("System", "De-Sync disabled.", 3)
		end
	end
})

-- Anti-Input Lag
local inputLagMonitorGeneration = 0
DefenseExtra:AddToggle("AntiInputLag", {
	Text = "Anti Network Ownership / Input Lag",
	Default = false,
	Callback = function(Value)
		inputLagMonitorGeneration += 1
		local monitorTicket = inputLagMonitorGeneration
		if Value then
			_G.AntiInputLag = true

			task.spawn(function()
				local plr = Player
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then return end

				local ToyName = "FoodHamburger"
				local Workspace = game:GetService("Workspace")
				local SpawnRemote = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction

				local spawnPending, nextSpawn = false, 0
				while _G.AntiInputLag and Hub.alive and monitorTicket == inputLagMonitorGeneration do
					task.wait(0.5)
					if not _G.AntiInputLag or monitorTicket ~= inputLagMonitorGeneration then break end
					char = plr.Character
					hrp = char and char:FindFirstChild("HumanoidRootPart")
					if not hrp then continue end
					local toysFolder = Workspace:FindFirstChild(plr.Name.."SpawnedInToys")
					local burger = toysFolder and toysFolder:FindFirstChild(ToyName)

					if not burger then
						if spawnPending or os.clock() < nextSpawn then continue end
						local canSpawn = plr:FindFirstChild("CanSpawnToy")
						if canSpawn and not canSpawn.Value then continue end
						spawnPending, nextSpawn = true, os.clock() + 8
						task.spawn(function()
							pcall(function()
								local spawnCF = Hub.teleportFrame(hrp) * CFrame.new(0, 5, 0)
								Hub.invoke(SpawnRemote, ToyName, spawnCF, Vector3.new(0,0,0))
							end)
							spawnPending = false
						end)

						local startWait = tick()
						repeat
							task.wait(0.1)
							toysFolder = Workspace:FindFirstChild(plr.Name.."SpawnedInToys")
							burger = toysFolder and toysFolder:FindFirstChild(ToyName)
						until burger or tick() - startWait > 1 or not _G.AntiInputLag or monitorTicket ~= inputLagMonitorGeneration
					end

					if not _G.AntiInputLag or monitorTicket ~= inputLagMonitorGeneration then break end
					if burger and burger.Parent then
						local holdPart = burger:FindFirstChild("HoldPart")
						if holdPart then
							local holdingPlayer = holdPart:FindFirstChild("HoldingPlayer") and holdPart.HoldingPlayer.Value

							if holdingPlayer and holdingPlayer ~= plr then
								pcall(function()
									Hub.invoke(holdPart.DropItemRemoteFunction, burger, Hub.teleportFrame(hrp) * CFrame.new(0, 2000, 0), Vector3.new(0,0,0))
								end)
								if Hub.canAffect(burger) then burger:Destroy() end
							else
								pcall(function()
									Hub.invoke(holdPart.HoldItemRemoteFunction, burger, char)
								end)
								task.wait()

								pcall(function()
									Hub.invoke(holdPart.DropItemRemoteFunction, burger, Hub.teleportFrame(hrp) * CFrame.new(0, 2000, 0), Vector3.new(0,0,0))
								end)
								task.wait()
							end
						end
					end
				end
			end)
		else
			_G.AntiInputLag = false
		end
	end
})



-- Anti-Kick System
do
	local enabled, generation = false, 0
	local managedToy, managedCharacter
	local spawnJob, spawnPending = nil, false
	local nextSpawn, nextStick, nextError = 0, 0, 0
	local savedVisuals = {}
	local createdHighlights = {}

	local function report(message)
		warn("[Shuriken] " .. tostring(message))
		if os.clock() >= nextError then
			nextError = os.clock() + 10
			pcall(notify, "Anti Kick", tostring(message), 6)
		end
	end

	local function toyFolder()
		local plotItems = workspace:FindFirstChild("PlotItems")
		local inPlots = plotItems and plotItems:FindFirstChild("PlayersInPlots")
		if inPlots and inPlots:FindFirstChild(Player.Name) then
			local plots = workspace:FindFirstChild("Plots")
			if not plots then return nil end
			for _, plot in ipairs(plots:GetChildren()) do
				local sign = plot:FindFirstChild("PlotSign")
				local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
				if owners then
					for _, owner in ipairs(owners:GetChildren()) do
						if owner:IsA("StringValue") and owner.Value == Player.Name then
							return plotItems:FindFirstChild(plot.Name)
						end
					end
				end
			end
			return nil -- Wait until the owned plot folder is ready.
		end
		return workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
	end

	local function findToy()
		local folder = toyFolder()
		return folder and (folder:FindFirstChild("AntiKick")
			or folder:FindFirstChild("NinjaShuriken"))
	end

	local function restoreVisuals()
		for part, saved in pairs(savedVisuals) do
			pcall(function()
				part.CanTouch, part.CanCollide, part.CanQuery = saved.touch, saved.collide, saved.query
				part.Transparency = saved.transparency
			end)
		end
		table.clear(savedVisuals)
		for highlight in pairs(createdHighlights) do
			pcall(function() highlight:Destroy() end)
			if Hub.instances then Hub.instances[highlight] = nil end
		end
		table.clear(createdHighlights)
	end

	local function clearToy()
		restoreVisuals()
		local old = managedToy
		managedToy, managedCharacter = nil, nil
		if not old or not old.Parent then return end
		local menu = ReplicatedStorage:FindFirstChild("MenuToys")
		local destroy = menu and menu:FindFirstChild("DestroyToy")
		if destroy then
			local ok, err = pcall(function() Hub.fire(destroy, old) end)
			if not ok then report(err) end
		end
	end

	local function cancelSpawn()
		if spawnJob then
			local scheduler = Hub.nativeTask or task
			pcall(scheduler.cancel, spawnJob)
			if Hub.threads then Hub.threads[spawnJob] = nil end
		end
		spawnJob, spawnPending = nil, false
	end

	local function decorateToy(toy)
		for _, part in ipairs(toy:GetChildren()) do
			if part:IsA("BasePart") then
				if not savedVisuals[part] then
					savedVisuals[part] = {
						touch = part.CanTouch, collide = part.CanCollide,
						query = part.CanQuery, transparency = part.Transparency,
					}
				end
				local visible = part.Name == "Pyramid" or part.Name == "Main"
				part.Transparency = visible and 0 or 1
				if visible and not part:FindFirstChildOfClass("Highlight") then
					local highlight = Hub.new("Highlight", part)
					highlight.Adornee = part
					highlight.FillColor = part.Name == "Pyramid"
						and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
					createdHighlights[highlight] = true
				end
			end
		end
	end

	local function styleToy(toy)
		decorateToy(toy)
		for _, part in ipairs(toy:GetChildren()) do
			if part:IsA("BasePart") then
				if not savedVisuals[part] then
					savedVisuals[part] = {
						touch = part.CanTouch, collide = part.CanCollide,
						query = part.CanQuery, transparency = part.Transparency,
					}
				end
				part.CanTouch, part.CanCollide, part.CanQuery = false, false, false
				part.Transparency = (part.Name == "Main" or part.Name == "Pyramid") and 0 or 1
			end
		end
	end

	local function step(ticket)
		local char = Player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if managedCharacter and (char ~= managedCharacter or not hum or hum.Health <= 0) then
			cancelSpawn()
			clearToy()
			nextSpawn, nextStick = 0, 0
		end
		if not hum or hum.Health <= 0 or not root then return end

		local toy = managedToy
		if toy and not toy.Parent then restoreVisuals(); managedToy = nil; toy = nil end
		if not toy then
			toy = findToy()
			if toy then
				managedToy, managedCharacter = toy, char
			elseif not spawnPending and os.clock() >= nextSpawn then
				local menu = ReplicatedStorage:FindFirstChild("MenuToys")
				local remote = menu and menu:FindFirstChild("SpawnToyRemoteFunction")
				local canSpawn = Player:FindFirstChild("CanSpawnToy")
				if not remote or not canSpawn or not canSpawn.Value then return end
				-- Do not spawn while standing in a plot whose ownership is unresolved.
				local items = workspace:FindFirstChild("PlotItems")
				local inPlots = items and items:FindFirstChild("PlayersInPlots")
				if inPlots and inPlots:FindFirstChild(Player.Name) and not toyFolder() then return end
				managedCharacter = char
				spawnPending, nextSpawn = true, os.clock() + 8
				spawnJob = task.spawn(function()
					local ok, err = pcall(function()
						Hub.invoke(remote, "NinjaShuriken", Hub.teleportFrame(root) * CFrame.new(0, 12, 20), Vector3.zero)
					end)
					if ticket ~= generation then return end
					spawnPending, spawnJob = false, nil
					if not ok then
						if tostring(err):find("OwnedToys",1,true) then
							nextSpawn=os.clock()+60
							warn("[Shuriken] Server toy data error: " .. tostring(err))
							report("The game could not read your owned-toy data. Spawn retries paused for 60 seconds. Try the normal toy menu, or rejoin if it also fails.")
						else report("Spawn failed: " .. tostring(err)) end
					end
				end)
				return
			else
				if spawnPending and os.clock() >= nextSpawn then
					cancelSpawn()
					nextSpawn = os.clock() + 2
					report("Spawn request timed out; checking for a late toy before retrying.")
				end
				return
			end
		end

		decorateToy(toy)
		local sticky = toy:FindFirstChild("StickyPart")
		local firePart = root:FindFirstChild("FirePlayerPart")
		if not sticky or not sticky:IsA("BasePart") or not firePart or not firePart:IsA("BasePart") then return end
		local weld = sticky:FindFirstChild("StickyWeld")
		local attached = weld and (weld:IsA("JointInstance") or weld:IsA("WeldConstraint"))
			and (weld.Part0 == firePart or weld.Part1 == firePart)
		if attached then styleToy(toy); return end
		if os.clock() < nextStick then return end
		nextStick = os.clock() + 1

		local grab = ReplicatedStorage:FindFirstChild("GrabEvents")
		local events = ReplicatedStorage:FindFirstChild("PlayerEvents")
		local ownerRemote = grab and grab:FindFirstChild("SetNetworkOwner")
		local stickyRemote = events and events:FindFirstChild("StickyPartEvent")
		if not stickyRemote then report("StickyPartEvent is missing."); return end
		local sound = toy:FindFirstChild("SoundPart")
		local owner = sound and sound:FindFirstChild("PartOwner")
		if sound and sound:IsA("BasePart") and ownerRemote and (not owner or owner.Value ~= Player.Name) then
			Hub.fire(ownerRemote, sound, sound.CFrame)
		end
		if not enabled or ticket ~= generation or Player.Character ~= char or hum.Health <= 0 then return end
		Hub.fire(stickyRemote, sticky, firePart, CFrame.Angles(0, math.rad(90), math.rad(90)))
		-- Wait for the actual weld before disabling the toy's touch properties.
	end

	local function stop()
		enabled = false
		generation += 1
		_G.ShurikenAntiKick = false
		cancelSpawn()
		clearToy()
	end
	Hub.cleanup(stop)

	DefenseExtra:AddToggle("ShurikenAntiKick", {
		Text = "Anti Kick", Default = false,
		Callback = function(on)
			stop()
			enabled, _G.ShurikenAntiKick = on, on
			Hub.requestSave()
			if not on then return end
			local ticket = generation
			nextSpawn, nextStick = 0, 0
			task.spawn(function()
				while enabled and Hub.alive and ticket == generation do
					local ok, err = pcall(step, ticket)
					if not ok then report(err) end
					task.wait(0.2)
				end
			end)
		end,
	})
end



do
	-- Loop TP: one worker, current-character lookup, reversible PlatformStand.
	local tpActive = false
	local tpGeneration = 0
	local affectedHumanoids = {}
	local function restoreTP()
		for humanoid, original in pairs(affectedHumanoids) do
			pcall(function() humanoid.PlatformStand = original end)
		end
		table.clear(affectedHumanoids)
	end
	Hub.cleanup(restoreTP)
	DefenseExtra:AddToggle("LoopTP", {Text = "Loop TP", Default = false,
		Callback = function(on)
			tpActive = on
			tpGeneration += 1
			local generation = tpGeneration
			restoreTP()
			if on then task.spawn(function()
					while tpActive and generation == tpGeneration do
						local current = Player.Character
						local root = current and current:FindFirstChild("HumanoidRootPart")
						local hum = current and current:FindFirstChildOfClass("Humanoid")
						if root and hum and hum.Health > 0 then
							if affectedHumanoids[hum] == nil then affectedHumanoids[hum] = hum.PlatformStand end
							hum.PlatformStand = true
							Hub.teleportPart(root, CFrame.new(math.random(-500, 500), math.random(30, 480), math.random(-500, 500)))
						end
						task.wait(0.03)
					end
				end) end
			Hub.requestSave()
		end})
	Hub.connect(Player.CharacterRemoving, restoreTP)
end

local function getPlayerList()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= Player then
			table.insert(list, plr.DisplayName .. " (" .. plr.Name .. ")")
		end
	end
	return list
end

local function getPlayerFromSelection(selection)
	if type(selection) ~= "string" then return nil end
	local username = selection:match("%(([^()]*)%)$")
	if username then
		return Players:FindFirstChild(username)
	end
	return nil
end

-- Auto Attacker
local AutoAttacker = false
local AttackMode = "Kill"
local attackerFlingStrength = 100
local headConnection
DefenseExtra:AddToggle("AutoAttacker", {
	Text = "Auto Attacker",
	Default = false,
	Callback = function(Value)
		AutoAttacker = Value
		if Value and Hub.scanAttacker then Hub.scanAttacker() end
	end
})

local Modes = {"Kill", "Fling",}

DefenseExtra:AddDropdown("AttackerMode", {
	Values = Modes,
	Default = 1,
	Multi = false,
	Text = "AttackMode",
	Callback = function(Value)
		AttackMode = Value
	end,
})

DefenseExtra:AddSlider("AutoAttackerFlingStrength", {
	Text = "Auto Attacker fling strength",
	Default = 100, Min = 25, Max = 2000, Rounding = 0,
	Callback = function(value) attackerFlingStrength = value end,
})

function CheckNetworkOwnerShipOnPlayer(potentialPlayer, condition)
	if typeof(potentialPlayer) == "Instance" and (potentialPlayer:IsA("Player") and potentialPlayer.Character) and (potentialPlayer.Character:FindFirstChild("Head") and (potentialPlayer.Character.Head:FindFirstChild("PartOwner") and potentialPlayer.Character.Head.PartOwner.Value == Player.Name)) then
		return not condition and true or potentialPlayer.Character.Head.PartOwner
	end
end

lookAt = Hub.lookAt

function SNOWshipPermanentPlayer(otherPlayer, callbackFunction)
	if not Hub.canHarm(otherPlayer) then return false end
	if Player.Character and (Player.Character:FindFirstChild("HumanoidRootPart") and (typeof(otherPlayer) == "Instance" and (otherPlayer:IsA("Player") and otherPlayer.Character)) and (otherPlayer.Character:FindFirstChild("HumanoidRootPart") and otherPlayer.Character.HumanoidRootPart:FindFirstChild("FirePlayerPart"))) then
		local firePlayerPart = otherPlayer.Character.HumanoidRootPart.FirePlayerPart
		local distanceFromFirePlayerPart = Player:DistanceFromCharacter(firePlayerPart.Position)
		if type(callbackFunction) == "function" then
			callbackFunction()
		end
		if distanceFromFirePlayerPart <= 30 then
			Hub.fire(setNetworkOwnerEvent, firePlayerPart, lookAt(Player.Character.HumanoidRootPart.Position, firePlayerPart.Position))
			return true
		end
	end
end

function SNOWshipPlayer(otherPlayer, callbackFunction)
	if not Hub.canHarm(otherPlayer) then return false end
	if Player.Character and (Player.Character:FindFirstChild("HumanoidRootPart") and (typeof(otherPlayer) == "Instance" and (otherPlayer:IsA("Player") and otherPlayer.Character)) and otherPlayer.Character:FindFirstChild("HumanoidRootPart")) then
		local otherPlayerHumanoidRootPart = otherPlayer.Character.HumanoidRootPart
		local distanceFromOtherPlayer = Player:DistanceFromCharacter(otherPlayerHumanoidRootPart.Position)
		if CheckNetworkOwnerShipOnPlayer(otherPlayer) then
			if type(callbackFunction) == "function" then
				callbackFunction()
			end
			return true
		end
		if distanceFromOtherPlayer <= 30 then
			Hub.fire(setNetworkOwnerEvent, otherPlayerHumanoidRootPart, lookAt(Player.Character.HumanoidRootPart.Position, otherPlayerHumanoidRootPart.Position))
		end
	end
end

function SNOWship(targetPart)
	if not Hub.canAffect(targetPart) then return false end
	if targetPart and typeof(targetPart) == "Instance" then
		if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
		local distanceFromCharacter = (Hub.teleportFrame(Player.Character.HumanoidRootPart).Position-targetPart.Position).Magnitude
		if Player.Character and (Player.Character:FindFirstChild("HumanoidRootPart") and distanceFromCharacter <= 30) then
			Hub.fire(setNetworkOwnerEvent, targetPart, lookAt(Hub.teleportFrame(Player.Character.HumanoidRootPart).Position, targetPart.Position))
		end
	end
end

function CreateSkyVelocity(skyObject)
	if not Hub.canAffect(skyObject) then return end
	if not skyObject or not skyObject.Parent then return end
	if not skyObject:FindFirstChild("SkyVelocity") then
		local skyVelocityBodyVelocity = Hub.new("BodyVelocity", skyObject)
		skyVelocityBodyVelocity.Name = "SkyVelocity"
		skyVelocityBodyVelocity.Velocity = Vector3.new(0, 100000000000000, 0)
		skyVelocityBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		Hub.assetTargets[skyVelocityBodyVelocity]=skyObject
		return skyVelocityBodyVelocity,true
	end
	return skyObject:FindFirstChild("SkyVelocity"),false
end

local heldObjectName = nil
Hub.attackerBindings = {}
Hub.attackerBusy = {}
Hub.attackerBindingEpoch=0
function Hub.clearAttackerBindings()
	Hub.attackerBindingEpoch+=1
	for _,connection in ipairs(Hub.attackerBindings) do connection:Disconnect();Hub.connections[connection]=nil end
	table.clear(Hub.attackerBindings)
	Hub.attackerBusy={}
	Hub.scanAttacker=nil
	headConnection=nil
end
local function hookAttackerCharacter(boundCharacter)
	if not Hub.alive or Player.Character~=boundCharacter then return end
	Hub.clearAttackerBindings()
	local generation=Hub.attackerBindingEpoch
	local seenOwners={}
	local function isCurrent()
		local hum = boundCharacter:FindFirstChildOfClass("Humanoid")
		return Hub.alive and AutoAttacker and boundCharacter == Player.Character
			and generation == Hub.attackerBindingEpoch and hum and hum.Health > 0
	end
	local function handleOwner(hitPart)
		if not isCurrent() or not hitPart:IsDescendantOf(boundCharacter) then return end
		if not hitPart:IsA("StringValue") and not hitPart:IsA("ObjectValue") then return end
		if hitPart.Name == "PartOwner" then
			local value = hitPart.Value
			heldObjectName = typeof(value) == "Instance" and value.Name or tostring(value)
			if AutoAttacker then
				local otherPlayer = Players:FindFirstChild(heldObjectName)
				local otherHumanoid = nil
				local otherHumanoidRootPart = nil
				if otherPlayer and otherPlayer.Character then
					local otherCharacter = otherPlayer.Character
					if otherCharacter then
						otherHumanoid = otherCharacter:FindFirstChildOfClass("Humanoid")
						otherHumanoidRootPart = otherCharacter:FindFirstChild("HumanoidRootPart")
					end
				end

				-- Check if it's not yourself and not authorized (add isAuthorized if you have it)
				if Hub.canHarm(otherPlayer) and otherHumanoid and otherHumanoidRootPart then
					local busy = Hub.attackerBusy
					if busy[otherPlayer] then return end
					busy[otherPlayer] = true
					local ok, actionError = xpcall(function()
						-- Death mode counter action
						local counterAction
						local humanoidInstance = otherHumanoid

						if isCurrent() and Hub.canHarm(otherPlayer) and humanoidInstance and humanoidInstance.Parent and otherHumanoidRootPart.Parent then

							if AttackMode == "Kill" then
								counterAction = function()
									CreateSkyVelocity(otherHumanoidRootPart)
									for _ = 0, 30 do
										humanoidInstance.BreakJointsOnDeath = false
										humanoidInstance:ChangeState(Enum.HumanoidStateType.Dead)
										humanoidInstance.Jump = true
										humanoidInstance.Sit = true
									end
									task.wait()
									Hub.fire(ReplicatedStorage.GrabEvents.DestroyGrabLine, otherHumanoidRootPart)
								end
							elseif AttackMode == "Fling" then
								counterAction = function()
									local lookAtCFrame = lookAt(LocalPlayer.Character.HumanoidRootPart.Position, otherHumanoidRootPart.Position)
									local bodyVelocity = Instance.new("BodyVelocity", otherPlayer.Character.HumanoidRootPart)
									bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
									bodyVelocity.Velocity = Vector3.new(lookAtCFrame.lookVector.X, 0.5, lookAtCFrame.lookVector.Z) * attackerFlingStrength
									wait()
									bodyVelocity:Destroy()
									destroyGrabLineEvent:FireServer(otherHumanoidRootPart)
								end
							end
						end


						if type(counterAction) ~= "function" then error("Unknown Auto Attacker mode: " .. tostring(AttackMode)) end
						local completed = false
						-- Execute SNOWship loop
						for _ = 1, 50 do
							if not isCurrent() or not Hub.canHarm(otherPlayer) or otherPlayer.Character ~= otherHumanoid.Parent then break end
							if SNOWshipPlayer(otherPlayer, counterAction) then
								completed = true
								break
							end
							task.wait()
						end
						if not completed and isCurrent() then warn("[Arriva Auto Attacker] Action was not reached for " .. otherPlayer.Name .. ", ownership/range checks did not complete.") end
					end, debug.traceback)
					busy[otherPlayer] = nil
					if not ok then warn("[Arriva Auto Attacker] " .. tostring(actionError)) end
				end
			end
		end
	end
	local function watchOwner(instance)
		if instance.Name ~= "PartOwner" or seenOwners[instance] then return end
		if not instance:IsA("StringValue") and not instance:IsA("ObjectValue") then return end
		seenOwners[instance]=true
		table.insert(Hub.attackerBindings, Hub.connect(instance:GetPropertyChangedSignal("Value"), function()
			task.spawn(function() handleOwner(instance) end)
		end))
		task.spawn(function() handleOwner(instance) end)
	end
	headConnection = Hub.connect(boundCharacter.DescendantAdded, function(instance)
		watchOwner(instance)
		if instance:IsA("Humanoid") or instance.Name == "HumanoidRootPart" then
			task.defer(function() if Hub.scanAttacker then Hub.scanAttacker() end end)
		end
	end)
	table.insert(Hub.attackerBindings, headConnection)
	Hub.scanAttacker = function()
		if not isCurrent() then return end
		for _, instance in ipairs(boundCharacter:GetDescendants()) do
			if instance.Name == "PartOwner" then task.spawn(function() handleOwner(instance) end) end
		end
	end
	for _, instance in ipairs(boundCharacter:GetDescendants()) do watchOwner(instance) end
end
if Player.Character then hookAttackerCharacter(Player.Character) end
Hub.connect(Player.CharacterRemoving,Hub.clearAttackerBindings)
Hub.connect(Player.CharacterAdded,function(char)
	task.defer(function()
		if Hub.alive and Player.Character==char then hookAttackerCharacter(char) end
	end)
end)
Hub.cleanup(Hub.clearAttackerBindings)

-- Player Tab
local PlayerView = Tabs.Player:AddLeftGroupbox("View & Movement")
local PlayerESP = Tabs.Visual:AddLeftGroupbox("Player ESP")
local PlayerPerf = Tabs.Player:AddRightGroupbox("Performance")

do
	-- Third Person: restore the actual original camera mode.
	local function enableThirdPerson()
		Player.CameraMode = Enum.CameraMode.Classic
		Player.CameraMaxZoomDistance = math.max(Hub.cameraOriginal.max, 128)
		Player.CameraMinZoomDistance = 0.5
	end
	local function disableThirdPerson()
		Player.CameraMaxZoomDistance = math.max(Player.CameraMaxZoomDistance, Hub.cameraOriginal.max)
		Player.CameraMinZoomDistance = Hub.cameraOriginal.min
		Player.CameraMaxZoomDistance = Hub.cameraOriginal.max
		Player.CameraMode = Hub.cameraOriginal.mode
	end

	PlayerView:AddToggle("ThirdPersonToggle", {
		Text = "3rd Person View",
		Default = false,
		Callback = function(Value)
			if Value then enableThirdPerson() else disableThirdPerson() end
		end
	})

end

-- Spin Character
local spinningConnection
local spinSpeed = 5
PlayerView:AddToggle("SpinToggle", {
	Text = "Spin Character",
	Default = false,
	Callback = function(Value)
		if Value then
			spinningConnection = Hub.connect(RunService.Heartbeat, function(dt)
				local character = Player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(spinSpeed * dt * 60), 0) end
			end)
		else
			if spinningConnection then spinningConnection:Disconnect() spinningConnection = nil end
		end
	end
})

PlayerView:AddSlider("SpinSpeed", {
	Text = "Spin Speed",
	Default = 5,
	Min = 1,
	Max = 50,
	Rounding = 0,
	Callback = function(Value) spinSpeed = Value end
})



-- Infinite Jump
local infJump = false
PlayerView:AddToggle("infJumpToggle", {
	Text = "Infinite Jump",
	Default = false,
	Callback = function(Value) infJump = Value end
})

-- Speed/Jump Modifiers
local SpeedConnection
local SpeedModConnection
local WalkSpeed = 16
local JumpPower = 50
local speedModifierEnabled = false
local jumpModifierEnabled = false
local speedMultiplier = 1

PlayerView:AddToggle("SpeedModifierToggle", {
	Text = "Enable Speed Modifier",
	Default = false,
	Callback = function(Value)
		speedModifierEnabled = Value
		if Value then
			SpeedModConnection = Hub.connect(RunService.Heartbeat, function(dt)
				local character = Player.Character
				if character then
					local root = character:FindFirstChild("HumanoidRootPart")
					local hum = character:FindFirstChildOfClass("Humanoid")
					if root and hum then
						root.CFrame = root.CFrame + hum.MoveDirection * speedMultiplier * math.min(dt, 0.1) * 60
					end
				end
			end)
		else
			if SpeedModConnection then SpeedModConnection:Disconnect() SpeedModConnection = nil end
		end
	end
})

PlayerView:AddToggle("JumpModifierToggle", {
	Text = "Enable Jump Modifier",
	Default = false,
	Callback = function(Value)
		jumpModifierEnabled = Value
		local character = Player.Character
		if character then
			local hum = character:FindFirstChild("Humanoid")
			if hum then
				if Value then
					Hub.backup(hum, {"JumpPower", "UseJumpPower"})
					hum.UseJumpPower = true
					hum.JumpPower = JumpPower
				else
					Hub.restore(hum)
				end
			end
		end
	end
})

PlayerView:AddSlider("SpeedValue", {
	Text = "Walk speed",
	Default = 1,
	Min = 0.1,
	Max = 10,
	Rounding = 1,
	Callback = function(Value)
		speedMultiplier = Value
	end
})

PlayerView:AddSlider("JumpValue", {
	Text = "Jump Power",
	Default = 50,
	Min = 50,
	Max = 500,
	Rounding = 0,
	Callback = function(Value)
		JumpPower = Value
		if jumpModifierEnabled then
			local character = Player.Character
			if character then
				local hum = character:FindFirstChild("Humanoid")
				if hum then
					Hub.backup(hum, {"JumpPower", "UseJumpPower"})
					hum.UseJumpPower = true
					hum.JumpPower = Value
				end
			end
		end
	end
})

Hub.connect(Player.CharacterAdded, function(char)
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum or Player.Character ~= char then return end
	if jumpModifierEnabled then
		Hub.backup(hum, {"JumpPower", "UseJumpPower"})
		hum.UseJumpPower = true
		hum.JumpPower = JumpPower
	end
end)

Hub.connect(UserInputService.JumpRequest, function()
	if infJump and not Hub.blobFlightActive then
		local character = Player.Character
		if character and character:FindFirstChildOfClass("Humanoid") then
			character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

-- ESP System
local espEnabled = false
local espBoxes = {}
local targetNames = {"partesp", "playercharacterlocationdetector"}
local function IsTarget(obj)
	if not obj:IsA("BasePart") then return false end
	for _, name in ipairs(targetNames) do if string.lower(obj.Name) == string.lower(name) then return true end end
	return false
end

local function AddBoxESP(obj)
	if espBoxes[obj] then return end
	local box = Hub.new("BoxHandleAdornment")
	box.Adornee = obj
	box.AlwaysOnTop = true
	box.ZIndex = 5
	box.Color3 = Color3.fromRGB(255, 255, 255)
	box.Transparency = 0.5
	box.Size = obj.Size
	box.Parent = game.CoreGui
	espBoxes[obj] = box
	Hub.connect(obj.AncestryChanged, function(_, parent)
		if not parent and espBoxes[obj] then espBoxes[obj]:Destroy() espBoxes[obj] = nil end
	end)
end

local function RemoveAllBoxes()
	for obj, box in pairs(espBoxes) do if box then box:Destroy() end end
	espBoxes = {}
end

local function Scan()
	for _, obj in ipairs(workspace:GetDescendants()) do if espEnabled and IsTarget(obj) then AddBoxESP(obj) end end
end

Hub.connect(workspace.DescendantAdded, function(obj) if espEnabled and IsTarget(obj) then AddBoxESP(obj) end end)

PlayerESP:AddToggle("BoxESPWhite", {
	Text = "PCLD View",
	Default = false,
	Callback = function(Value)
		espEnabled = Value
		if espEnabled then Scan() else RemoveAllBoxes() end
	end
})

-- Main player ESP, including appearance controls.
do
	(function()
		local group=PlayerESP
		local enabled,through,alpha,color=false,true,0.8,Color3.new(1,1,1)
		local showHP,showUsername,showDisplayName,boldText=true,true,true,true
		-- tool Visual/ESP: independently configurable fill and outline.
		local outlineColor,outlineAlpha=Color3.new(1,1,1),0.2
		local showPlate,showIcon,showHighlight=true,true,true
		local fontFamily,textSize,yOffset,maxDistance="GothamSSm",16,3,1200
		local textColor,strokeColor,strokeAlpha=Color3.new(1,1,1),Color3.new(0,0,0),0
		local rainbowFill,rainbowOutline,rainbowText=false,false,false
		local entries={};local elapsed=0
		local function clear(p) local e=entries[p];if e then e.gui:Destroy();e.highlight:Destroy();entries[p]=nil end end
		local function update()
			for p,e in pairs(entries) do if not enabled or p.Parent~=Players or p.Character~=e.character then clear(p) end end
			if not enabled then return end
			for _,p in ipairs(Players:GetPlayers()) do if p~=Player then
					local char=p.Character;local head=char and char:FindFirstChild("Head")
					local hum=char and char:FindFirstChildOfClass("Humanoid")
					if head and hum and hum.Health>0 then
						local e=entries[p]
						if not e then
							local gui=Hub.new("BillboardGui",head);gui.Name="NameESP";gui.Adornee=head
							gui.Size=UDim2.fromOffset(180,58);gui.StudsOffset=Vector3.new(0,3,0);gui.MaxDistance=1200
							local avatar=Hub.new("ImageLabel",gui);avatar.Size=UDim2.fromOffset(32,32);avatar.BackgroundTransparency=1
							avatar.Image=string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150",p.UserId)
							local text=Hub.new("TextLabel",gui);text.Position=UDim2.fromOffset(36,0);text.Size=UDim2.new(1,-36,1,0)
							text.BackgroundTransparency=1;text.TextSize=16;text.TextWrapped=true
							text.Font=Enum.Font.GothamBold;text.TextStrokeColor3=Color3.new(0,0,0);text.TextStrokeTransparency=0
							local highlight=Hub.new("Highlight",char);highlight.Adornee=char
							e={gui=gui,text=text,avatar=avatar,highlight=highlight,character=char};entries[p]=e
						end
						local hue=Color3.fromHSV((os.clock()*0.15)%1,1,1)
						e.gui.AlwaysOnTop=through;e.gui.MaxDistance=maxDistance
						e.gui.StudsOffset=Vector3.new(0,yOffset,0)
						e.gui.Size=UDim2.fromOffset(220,math.max(58,textSize*3+10))
						e.avatar.Visible=showPlate and showIcon
						e.text.Position=UDim2.fromOffset(showIcon and 36 or 0,0)
						e.text.Size=UDim2.new(1,showIcon and -36 or 0,1,0)
						e.text.TextSize=textSize
						e.text.TextColor3=rainbowText and hue or textColor
						e.text.TextStrokeColor3=strokeColor;e.text.TextStrokeTransparency=strokeAlpha
						e.highlight.FillColor=rainbowFill and hue or color
						e.highlight.OutlineColor=rainbowOutline and hue or outlineColor
						local ownRoot=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
						e.highlight.Enabled=showHighlight and ownRoot~=nil and (head.Position-Hub.teleportFrame(ownRoot).Position).Magnitude<=maxDistance
						e.highlight.FillTransparency=alpha;e.highlight.OutlineTransparency=outlineAlpha
						e.highlight.DepthMode=through and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
						local name=""
						if showDisplayName then name=p.DisplayName end
						if showUsername then name=showDisplayName and (name .. " (@" .. p.Name .. ")") or ("@" .. p.Name) end
						local lines={}
						if name~="" then table.insert(lines,name) end
						if showHP then table.insert(lines,string.format("HP %.0f",hum.Health)) end
						e.text.Text=table.concat(lines,"\n")
						e.text.Visible=showPlate and #lines>0
						local ok=pcall(function()
							e.text.FontFace=Font.new("rbxasset://fonts/families/"..fontFamily..".json",boldText and Enum.FontWeight.Bold or Enum.FontWeight.Regular,Enum.FontStyle.Normal)
						end)
						if not ok then e.text.Font=boldText and Enum.Font.GothamBold or Enum.Font.Gotham end
					else clear(p) end
				end end
		end
		group:AddToggle("NicknameESP",{Text="ESP",Default=false,Callback=function(on) enabled=on;update() end})
		group:AddToggle("DetailedESPShowHP",{Text="Show HP",Default=true,Callback=function(on) showHP=on;update() end})
		group:AddToggle("DetailedESPShowUsername",{Text="Show username",Default=true,Callback=function(on) showUsername=on;update() end})
		group:AddToggle("DetailedESPShowDisplayName",{Text="Show display name",Default=true,Callback=function(on) showDisplayName=on;update() end})
		group:AddToggle("DetailedESPBoldText",{Text="Bold text",Default=true,Callback=function(on) boldText=on;update() end})
		group:AddToggle("DetailedESPThroughWalls",{Text="Visible through walls",Default=true,Callback=function(on) through=on;update() end})
		group:AddSlider("DetailedESPTransparency",{Text="Fill transparency",Default=80,Min=0,Max=100,Rounding=0,Callback=function(value) alpha=value/100;update() end})
		group:AddInput("DetailedESPColor",{Text="Fill color hex",Default="FFFFFF",Finished=true,Callback=function(value)
			local hex=tostring(value):gsub("#","");if #hex==6 and hex:match("^%x+$") then
				color=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16));update()
			end
		end})
		group:AddSlider("DetailedESPOutlineTransparency",{Text="Outline transparency",Default=20,Min=0,Max=100,Rounding=0,
			Callback=function(value) outlineAlpha=value/100;update() end})
		group:AddInput("DetailedESPOutlineColor",{Text="Outline color hex",Default="FFFFFF",Finished=true,Callback=function(value)
			local hex=tostring(value):gsub("#","")
			if #hex==6 and hex:match("^%x+$") then
				outlineColor=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16));update()
			end
		end})
		group:AddToggle("PackESPHighlight",{Text="Character highlight",Default=true,Callback=function(on) showHighlight=on;update() end})
		group:AddToggle("PackESPNameplate",{Text="Nameplate",Default=true,Callback=function(on) showPlate=on;update() end})
		group:AddToggle("PackESPAvatar",{Text="Avatar icon",Default=true,Callback=function(on) showIcon=on;update() end})
		group:AddDropdown("PackESPFont",{Text="Name font",Values={"GothamSSm","Arial","SourceSansPro","RobotoMono"},Default=1,Callback=function(value) fontFamily=value;update() end})
		group:AddSlider("PackESPTextSize",{Text="Name size",Default=16,Min=8,Max=32,Rounding=0,Callback=function(value) textSize=value;update() end})
		group:AddSlider("PackESPNameOffset",{Text="Name height",Default=3,Min=0,Max=8,Rounding=1,Callback=function(value) yOffset=value;update() end})
		group:AddSlider("PackESPMaxDistance",{Text="ESP distance",Default=1200,Min=50,Max=5000,Rounding=0,Callback=function(value) maxDistance=value;update() end})
		group:AddSlider("PackESPTextOutline",{Text="Name outline transparency",Default=0,Min=0,Max=100,Rounding=0,Callback=function(value) strokeAlpha=value/100;update() end})
		local function parse(value)
			local hex=tostring(value):gsub("#","")
			if #hex==6 and hex:match("^%x+$") then return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)) end
		end
		group:AddInput("PackESPTextColor",{Text="Name color hex",Default="FFFFFF",Finished=true,Callback=function(value) textColor=parse(value) or textColor;update() end})
		group:AddInput("PackESPStrokeColor",{Text="Name outline hex",Default="000000",Finished=true,Callback=function(value) strokeColor=parse(value) or strokeColor;update() end})
		group:AddToggle("PackESPRainbowFill",{Text="Rainbow fill",Default=false,Callback=function(on) rainbowFill=on;update() end})
		group:AddToggle("PackESPRainbowOutline",{Text="Rainbow outline",Default=false,Callback=function(on) rainbowOutline=on;update() end})
		group:AddToggle("PackESPRainbowText",{Text="Rainbow name",Default=false,Callback=function(on) rainbowText=on;update() end})
		Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed>=((rainbowFill or rainbowOutline or rainbowText) and 0.1 or 0.5) then elapsed=0;update() end end)
		Hub.connect(Players.PlayerRemoving,clear)
		Hub.cleanup(function() enabled=false;for p in pairs(entries) do clear(p) end end)
	end)()
end

-- Performance
local oldProperties = {}
PlayerPerf:AddButton({
	Text = "Improve FPS",
	Func = function()
		local Lighting = game:GetService("Lighting")
		for _, v in pairs(Workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				if not oldProperties[v] then oldProperties[v] = {Material = v.Material, Reflectance = v.Reflectance, CastShadow = v.CastShadow} end
				v.Material = Enum.Material.Plastic v.Reflectance = 0 v.CastShadow = false
			elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
				if not oldProperties[v] then oldProperties[v] = {Enabled = v.Enabled} end
				v.Enabled = false
			end
		end
		for _, plr in pairs(Players:GetPlayers()) do
			if plr.Character then
				for _, part in pairs(plr.Character:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
						if not oldProperties[part] then oldProperties[part] = {Material = part.Material, Reflectance = part.Reflectance, CastShadow = part.CastShadow} end
						part.Material = Enum.Material.Plastic part.Reflectance = 0 part.CastShadow = false
					end
				end
			end
		end
		if not oldProperties["Lighting"] then oldProperties["Lighting"] = {GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd, Brightness = Lighting.Brightness} end
		Lighting.GlobalShadows = false Lighting.FogEnd = 100000 Lighting.Brightness = 2
	end
})

PlayerPerf:AddButton({
	Text = "Restore FPS",
	Func = function()
		local Lighting = game:GetService("Lighting")
		for obj, props in pairs(oldProperties) do
			if typeof(obj) == "Instance" and obj.Parent then
				for prop, value in pairs(props) do obj[prop] = value end
			elseif obj == "Lighting" then
				for prop, value in pairs(props) do Lighting[prop] = value end
			end
		end
		oldProperties = {}
	end
})

-- Self Noclip
local noclipEnabled = false
local noclipConn
local charConn
local savedCollision = {}
local noclipParts = {}
local noclipTrackedCharacter
local noclipDescendantConnection

local function applyNoclip(character)
	if character ~= noclipTrackedCharacter then
		if noclipDescendantConnection then noclipDescendantConnection:Disconnect() end
		table.clear(noclipParts)
		noclipTrackedCharacter = character
		local function track(part)
			if part:IsA("BasePart") then noclipParts[part] = true end
		end
		noclipDescendantConnection = Hub.connect(character.DescendantAdded, track)
		for _, part in ipairs(character:GetDescendants()) do track(part) end
	end
	for part in pairs(noclipParts) do
		if not part:IsDescendantOf(character) then
			if savedCollision[part] ~= nil then
				pcall(function() part.CanCollide = savedCollision[part] end)
				savedCollision[part] = nil
			end
			noclipParts[part] = nil
		else
			if savedCollision[part] == nil then savedCollision[part] = part.CanCollide end
			if part.CanCollide then part.CanCollide = false end
		end
	end
end

local function restoreCollision()
	for part, state in pairs(savedCollision) do
		if part and part.Parent then
			part.CanCollide = state
		end
	end
	table.clear(savedCollision)
end

local function startNoclip()
	if noclipConn then return end

	noclipConn = Hub.connect(RunService.Stepped, function()
		if not noclipEnabled then return end
		local char = Player.Character
		if char then
			applyNoclip(char)
		end
	end)

	charConn = Hub.connect(Player.CharacterAdded, function()
		task.wait(0.2)
		if noclipEnabled then
			restoreCollision()
		end
	end)
end

local function stopNoclip()
	if noclipDescendantConnection then noclipDescendantConnection:Disconnect(); noclipDescendantConnection = nil end
	noclipTrackedCharacter = nil
	table.clear(noclipParts)
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
	if charConn then
		charConn:Disconnect()
		charConn = nil
	end
	restoreCollision()
end

PlayerView:AddToggle("SelfNoclipToggle", {
	Text = "Noclip",
	Default = false,
	Callback = function(on)
		Hub.requestSave()
		noclipEnabled = on
		if on then
			startNoclip()
		else
			stopNoclip()
		end
	end
})

-- Target Tab
local TargetGroup = Tabs.Target:AddLeftGroupbox("Target Interaction")
local BlobGroup = Tabs.Blob:AddLeftGroupbox("Controls")
local WhitelistGroup = Tabs.Whitelist:AddLeftGroupbox("Protected Players")
local TargetNotificationGroup = Tabs.Notifications:AddLeftGroupbox("Target Alerts")

local SelectedPlayer = nil -- Primary selection for one-shot actions.
Hub.selectedTargets = {}
Hub.targetIdentities = {}
Hub.targetCursors = {}
-- A stopped worker must not resume when the same toggle is enabled again.
Hub.targetLoopRuns = {}
local function cleanupActionRun(run)
	if not run or run.cleaned then return end
	run.cleaned=true;run.enabled=false
	for _,callback in ipairs(run.cleanups or {}) do local ok,message=pcall(callback);if not ok then warn("[Loop cleanup] "..tostring(message)) end end
	if run.worker and run.worker~=coroutine.running() and coroutine.status(run.worker)~="dead" then pcall(Hub.nativeTask.cancel,run.worker);Hub.threads[run.worker]=nil end
end
function Hub.beginTargetLoop(key, enabled)
	local previous=Hub.targetLoopRuns[key]
	if previous then cleanupActionRun(previous) end
	local run=enabled and {enabled=true,cleanups={}} or previous or {enabled=false,cleanups={}}
	Hub.targetLoopRuns[key]=run
	if Hub.loopNotice then
		local control=Toggles[key] or Options[key];local label=control and control.Text or "Selected loop"
		Hub.loopNotice("loops",enabled and "Loop enabled" or "Loop disabled",label,key..tostring(enabled))
	end
	return function() return Hub.alive and run.enabled and Hub.targetLoopRuns[key]==run end,
		function() return Hub.targetLoopRuns[key]==run end,
		function(callback) if run.cleaned then pcall(callback) else table.insert(run.cleanups,callback) end end,
		function(thread) run.worker=thread end
end
Hub.connect(RunService.Heartbeat,function()
	for key,run in pairs(Hub.targetLoopRuns) do
		if not run.enabled or (run.worker and coroutine.status(run.worker)=="dead") then
			cleanupActionRun(run)
			if run.worker and Toggles[key] and Toggles[key].Value then Toggles[key]:SetValue(false) end
		end
	end
end)
Hub.connect(Player.CharacterRemoving,function()
	for key,run in pairs(Hub.targetLoopRuns) do if run.enabled and (#run.cleanups>0 or run.worker) then
		cleanupActionRun(run);if Toggles[key] and Toggles[key].Value then Toggles[key]:SetValue(false) end
	end end
end)
Hub.cleanup(function() for _,run in pairs(Hub.targetLoopRuns) do cleanupActionRun(run) end end)
function Hub.loopTargetReady(player, character)
	if not player or player.Parent ~= Players or not Hub.canHarm(player) then return false end
	local char = player.Character
	if not char or (character and char ~= character) or not char:IsDescendantOf(Workspace) then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local inPlot = player:FindFirstChild("InPlot")
	return char:FindFirstChild("HumanoidRootPart") ~= nil and hum ~= nil and hum.Health > 0
		and not (inPlot and inPlot.Value)
end
function Hub.getBlobSeat()
	local char = Player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.Health > 0 and hum.SeatPart
	local blob = seat and seat.Parent
	if blob and blob.Name == "CreatureBlobman" and blob:IsDescendantOf(Workspace) then return seat end
	return nil
end
function Hub.getLoopBlobSeat()
	local seat = Hub.getBlobSeat()
	local folder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
	return seat and folder and seat.Parent.Parent == folder and seat or nil
end
function Hub.isSelectedTarget(player)
	return player ~= nil and Hub.selectedTargets[player.UserId] == player
end
function Hub.hasTrackedTargets()
	return next(Hub.targetIdentities) ~= nil
end
function Hub.reconcileTargetIdentities(excluded)
	local online = {}
	SelectedPlayer = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local identity = Hub.targetIdentities[player.UserId]
		if identity and player ~= Player and player ~= excluded and player.Parent == Players then
			identity.name = player.Name
			identity.label = (player.DisplayName or player.Name) .. " (" .. player.Name .. ")"
			online[player.UserId] = player
			SelectedPlayer = SelectedPlayer or player
		end
	end
	Hub.selectedTargets = online
end
function Hub.setSelectedTargets(selection)
	if Hub.refreshingTargetSelector then return end
	local identities = {}
	if type(selection) == "string" then selection = {selection} end
	for key, value in pairs(type(selection) == "table" and selection or {}) do
		local label = type(key) == "number" and value or (value and key or nil)
		local player = type(label) == "string" and getPlayerFromSelection(label) or nil
		if player and player ~= Player then
			identities[player.UserId] = {name = player.Name, label = label}
		elseif type(label) == "string" then
			for id, identity in pairs(Hub.targetIdentities) do
				if identity.label == label or identity.label .. " [offline]" == label then identities[id] = identity; break end
			end
		end
	end
	Hub.targetIdentities = identities
	Hub.reconcileTargetIdentities()
	if Hub.refreshTargetSelector then Hub.refreshTargetSelector() end
end
function Hub.targetSelectionState()
	local values, selected = {}, {}
	local online, offline = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Player and player.Parent == Players then
			local label = (player.DisplayName or player.Name) .. " (" .. player.Name .. ")"
			table.insert(values, label)
			if Hub.selectedTargets[player.UserId] == player then selected[label] = true; online += 1 end
		end
	end
	for id, identity in pairs(Hub.targetIdentities) do
		if not Hub.selectedTargets[id] then
			local label = identity.label .. " [offline]"
			table.insert(values, label); selected[label] = true; offline += 1
		end
	end
	table.sort(values)
	return values, selected, online, offline
end
function Hub.nextLoopTarget(key, dwell)
	local candidates = {}
	for _, player in pairs(Hub.selectedTargets) do
		if Hub.loopTargetReady(player) then
			table.insert(candidates, player)
		end
	end
	table.sort(candidates, function(a, b) return a.UserId < b.UserId end)
	local cursor = Hub.targetCursors[key]
	if cursor and dwell and os.clock() < cursor.untilTime then
		for _, player in ipairs(candidates) do
			if player.UserId == cursor.id then return player end
		end
	end
	local target = candidates[1]
	if cursor then
		for _, player in ipairs(candidates) do
			if player.UserId > cursor.id then target = player; break end
		end
	end
	if target then Hub.targetCursors[key] = {id = target.UserId, untilTime = os.clock() + (dwell or 0)} end
	return target
end
local kickLoopEnabled = false
local loopKillEnabled = false
local loopKillEnabledAll = false



local function autoblob(active)
	active = active or function() return Hub.alive end
	if not active() then return false end
	if Hub.getLoopBlobSeat() then return true end
	if Hub.blobAcquireBusy then return false end
	Hub.blobAcquireBusy = true
	local ok, result = xpcall(function()
		local char = Player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local held = Player:FindFirstChild("IsHeld")
		if not root or not hum or hum.Health <= 0 or root.Anchored or (held and held.Value) or Hub.safeZoneLoopActive then return false end
		local function current()
			local currentHeld = Player:FindFirstChild("IsHeld")
			return Hub.alive and active() and Player.Character == char and root.Parent == char and hum.Health > 0
				and not root.Anchored and not (currentHeld and currentHeld.Value) and not Hub.safeZoneLoopActive
		end
		local deadline = os.clock() + 2
		repeat
			if not current() then return false end
			local folder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
			local blob = folder and folder:FindFirstChild("CreatureBlobman")
			if blob then
				local seat = blob:FindFirstChild("VehicleSeat")
				if seat then
					if seat.Occupant and seat.Occupant ~= hum then return false end
					if hum.SeatPart and hum.SeatPart ~= seat then
						hum.Sit = false
						hum:ChangeState(Enum.HumanoidStateType.Jumping)
						task.wait(0.1)
						if not current() then return false end
					end
					if not current() or seat.Parent ~= blob or blob.Parent ~= folder then return false end
					if not hum.SeatPart then
						Hub.teleportPart(root, seat.CFrame + Vector3.new(0, 1, 0))
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
						seat:Sit(hum)
					end
					if hum.SeatPart == seat then
						Hub.preferredBlob = blob
						return true
					end
				end
			elseif not Hub.blobSpawnPending and os.clock() >= (Hub.nextBlobSpawn or 0) then
				local menu = ReplicatedStorage:FindFirstChild("MenuToys")
				local spawn = menu and menu:FindFirstChild("SpawnToyRemoteFunction")
				if not spawn then return false end
				Hub.blobSpawnPending = true
				Hub.nextBlobSpawn = os.clock() + 10
				task.spawn(function()
					if current() then pcall(function() Hub.invoke(spawn, "CreatureBlobman", Hub.teleportFrame(root), Vector3.zero) end) end
					Hub.blobSpawnPending = false
				end)
			end
			task.wait(0.15)
		until os.clock() >= deadline
		return false
	end, debug.traceback)
	Hub.blobAcquireBusy = false
	if not ok and Hub.loopNotice then Hub.loopNotice("warnings", "Blobman acquisition failed", tostring(result), "acquireError") end
	return ok and result == true
end

-- Managed Blobman seating, idle stabilization and categorized loop notifications.
do
	Hub.loopNoticePrefs = {targets = true, ready = false, seats = true, warnings = true, loops = false, sounds = false}
	Hub.loopNoticeTimes = {}
	function Hub.loopNotice(kind, title, message, key, playerName)
		if not Hub.alive or not Hub.loopNoticePrefs[kind] then return end
		local token = kind .. ":" .. (key or title)
		local now = os.clock()
		if now < (Hub.loopNoticeTimes[token] or -math.huge) then return end
		Hub.loopNoticeTimes[token] = now + (kind == "warnings" and 15 or 3)
		Library:Notify({Title = title, Description = message, PlayerName = playerName, Type = kind == "warnings" and "warning" or kind == "ready" and "success" or "info", Time = kind == "warnings" and 6 or 4})
		if Hub.loopNoticePrefs.sounds and not Hub.playNotificationSound then
			local sound = Hub.new("Sound", Workspace)
			sound.SoundId = "rbxassetid://4590662766"
			sound.Volume = 0.4
			sound:Play()
			Debris:AddItem(sound, 3)
		end
	end
	local notices = Tabs.Notifications:AddRightGroupbox("Loop & Blobman Alerts")
	for _, entry in ipairs({
		{"LoopNotifyTargets", "Selected players leave, return or respawn", "targets"},
		{"LoopNotifyReady", "Selected player ready for loops", "ready"},
		{"LoopNotifySeats", "Blobman seat lost and recovered", "seats"},
		{"LoopNotifyWarnings", "Blobman retry warnings", "warnings"},
		{"LoopNotifyState", "Loop enabled and disabled", "loops"},
		{"LoopNotifySounds", "Play sounds for loop alerts", "sounds"},
		}) do
		local key = entry[3]
		notices:AddToggle(entry[1], {Text = entry[2], Default = Hub.loopNoticePrefs[key],
			Callback = function(on) Hub.loopNoticePrefs[key] = on end})
	end
	notices:AddButton({Text = "Preview loop notification", Func = function()
		Library:Notify({Title = "Blobman seat recovered", Description = "Preview: your enabled loops can continue.", Time = 4})
	end})
	Hub.autoReseatBlob = true
	Hub.blobReseatInterval = 3
	Hub.heavyBlobEnabled = false
	function Hub.blobLoopRequired()
		for _, key in ipairs({"LoopKickToggle2", "DualHandLoopKick"}) do
			local run = Hub.targetLoopRuns[key]
			if run and run.enabled then return true end
		end
		return false
	end
	local hold, attachment, heldRoot, holdPosition, lastSeat
	local nextAttempt, elapsed = 0, 0
	local hadSeat, waiting = false, false
	local status = BlobGroup:AddLabel("Blobman loops are idle.")
	local function clearHeavy()
		for _, object in pairs({hold, attachment}) do
			Hub.instances[object] = nil
			Hub.assetTargets[object] = nil
			object:Destroy()
		end
		hold, attachment, heldRoot, holdPosition, lastSeat = nil, nil, nil, nil, nil
	end
	function Hub.updateHeavyBlobman()
		local char = Player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local seat = Hub.getBlobSeat()
		if not Hub.heavyBlobEnabled or not seat or not root or not hum or hum.Health <= 0
			or Hub.blobFlightActive or Hub.characterFlightActive or (Hub.isBlobFlightActive and Hub.isBlobFlightActive()) then clearHeavy(); return end
		if heldRoot ~= root or lastSeat ~= seat or not hold or not hold.Parent then
			clearHeavy()
			heldRoot, lastSeat, holdPosition = root, seat, Hub.teleportFrame(root).Position
			attachment = Hub.new("Attachment", root)
			attachment.Name = "ArrivaHeavyBlobAttachment"
			hold = Hub.new("AlignPosition", root)
			hold.Name = "ArrivaHeavyBlobHold"
			hold.Mode = Enum.PositionAlignmentMode.OneAttachment
			hold.Attachment0 = attachment
			hold.ApplyAtCenterOfMass = true
			hold.MaxForce = 500000
			hold.MaxVelocity = 50
			hold.Responsiveness = 40
		end
		local moving = hum.MoveDirection.Magnitude > 0.05
		-- Deliberate hub teleports establish a new idle position.
		if moving or (Hub.teleportFrame(root).Position - holdPosition).Magnitude > 8 then holdPosition = Hub.teleportFrame(root).Position end
		hold.Enabled = not moving
		hold.Position = holdPosition
	end
	function Hub.sampleBlobController()
		if not Hub.alive then return end
		Hub.updateHeavyBlobman()
		local required = Hub.blobLoopRequired()
		local seat = Hub.getLoopBlobSeat()
		if not required then hadSeat, waiting = false, false; status:SetText("Blobman loops are idle."); return end
		if seat then
			if waiting then Hub.loopNotice("seats", "Blobman seat recovered", "Enabled Blobman loops can continue.", "seatRestored") end
			hadSeat, waiting = true, false
			status:SetText("Your Blobman seat is ready.")
			return
		end
		if hadSeat then Hub.loopNotice("seats", "Blobman seat lost", "Blobman loops are paused while seating is restored.", "seatLost") end
		hadSeat, waiting = false, true
		status:SetText(Hub.autoReseatBlob and "Waiting for Blobman seating; automatic retries enabled." or "Waiting for Blobman seating; auto reseat is off.")
		if not Hub.autoReseatBlob or Hub.blobAcquireBusy or os.clock() < nextAttempt then return end
		local char = Player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local held = Player:FindFirstChild("IsHeld")
		if not hum or hum.Health <= 0 or (held and held.Value) or Hub.safeZoneLoopActive then return end
		nextAttempt = os.clock() + Hub.blobReseatInterval
		task.spawn(function()
			local function active()
				return Hub.alive and Hub.autoReseatBlob and Hub.blobLoopRequired() and Player.Character == char
			end
			local seated = autoblob(active)
			if active() and not seated then
				Hub.loopNotice("warnings", "Still waiting for Blobman", "Reseating will retry. The toy may be loading, occupied or unavailable.", "seatRetry")
			end
		end)
	end
	BlobGroup:AddToggle("HeavyBlobman", {Text = "Heavy Blobman (idle hold)", Default = false,
		Callback = function(on) Hub.heavyBlobEnabled = on; if not on then clearHeavy() end end})
	BlobGroup:AddToggle("AutoReseatBlobLoops", {Text = "Auto reseat for Blobman loops", Default = true,
		Callback = function(on) Hub.autoReseatBlob = on; nextAttempt = 0 end})
	BlobGroup:AddSlider("BlobReseatInterval", {Text = "Reseat retry interval (seconds)", Default = 3, Min = 3, Max = 10, Rounding = 0,
		Callback = function(value) Hub.blobReseatInterval = value end})
	BlobGroup:AddButton({Text = "Stop Blobman loops", Func = function()
		for _, key in ipairs({"LoopKickToggle2", "DualHandLoopKick"}) do if Toggles[key] then Toggles[key]:SetValue(false) end end
	end})
	local connection = Hub.connect(RunService.Heartbeat, function(dt)
		elapsed += dt
		if elapsed >= 0.2 then elapsed = 0; Hub.sampleBlobController() end
	end)
	Hub.connect(Player.CharacterRemoving, function() clearHeavy(); hadSeat = false; waiting = true; nextAttempt = 0 end)
	Hub.cleanup(function()
		Hub.autoReseatBlob, Hub.heavyBlobEnabled = false, false
		connection:Disconnect(); Hub.connections[connection] = nil
		clearHeavy()
		Hub.sampleBlobController, Hub.updateHeavyBlobman = nil, nil
	end)
end

TargetGroup:AddDropdown("KickPlayerDropdown", {
	Values = getPlayerList(),
	Default = {},
	Multi = true,
	Text = "Select players",
	Callback = function(Value)
		Hub.setSelectedTargets(Value)
	end,
})


TargetGroup:AddButton({Text = "Refresh player list", Func = function()
	if Hub.refreshTargetSelector then Hub.refreshTargetSelector() end
end})

-- Target identity lifecycle: retain explicit selections across same-server departures.
do
	Hub.rememberLoopTargets = true
	local roster = {}
	local stateLabel = TargetGroup:AddLabel("No selected players.")
	function Hub.refreshTargetSelector()
		if not Options.KickPlayerDropdown then return end
		local values, selected, online, offline = Hub.targetSelectionState()
		Hub.refreshingTargetSelector = true
		local ok, err = pcall(function()
			Options.KickPlayerDropdown:SetValues(values)
			Options.KickPlayerDropdown:SetValue(selected)
		end)
		Hub.refreshingTargetSelector = false
		stateLabel:SetText(string.format("Tracked: %d online, %d offline. Loops wait for eligible characters.", online, offline))
		if not ok then warn("[Arriva target selector] " .. tostring(err)) end
	end
	local function refresh()
		Hub.queueRefresh("mainPlayerSelector", Hub.refreshTargetSelector)
	end
	local function watchCharacter(person, char)
		if not Hub.targetIdentities[person.UserId] then return end
		task.spawn(function()
			local deadline = os.clock() + 5
			while Hub.alive and person.Character == char and person.Parent == Players and Hub.targetIdentities[person.UserId] do
				if Hub.loopTargetReady(person, char) then
					Hub.loopNotice("ready", "Selected player ready", person.Name .. " has an eligible character; enabled loops can continue.", "ready" .. person.UserId)
					return
				end
				if os.clock() >= deadline then return end
				task.wait(0.25)
			end
		end)
	end
	local function watch(person)
		if person == Player or roster[person] then return end
		local entry = {seen = person.Character ~= nil}
		roster[person] = entry
		entry.connection = Hub.connect(person.CharacterAdded, function(char)
			if entry.seen and Hub.targetIdentities[person.UserId] then
				Hub.loopNotice("targets", "Selected player respawned", person.Name .. " respawned. Waiting for their character to become eligible.", "respawn" .. person.UserId,person.Name)
			end
			entry.seen = true
			Hub.reconcileTargetIdentities()
			watchCharacter(person, char)
			refresh()
		end)
		if person.Character then watchCharacter(person, person.Character) end
	end
	for _, person in ipairs(Players:GetPlayers()) do watch(person) end
	Hub.connect(Players.PlayerAdded, function(person)
		local remembered = Hub.targetIdentities[person.UserId] ~= nil
		Hub.reconcileTargetIdentities()
		watch(person)
		if remembered then Hub.loopNotice("targets", "Selected player returned", person.Name .. " rejoined this server; their selection is restored.", "return" .. person.UserId,person.Name) end
		refresh()
	end)
	Hub.connect(Players.PlayerRemoving, function(person)
		local remembered = Hub.targetIdentities[person.UserId] ~= nil
		local entry = roster[person]
		roster[person] = nil
		if entry then entry.connection:Disconnect(); Hub.connections[entry.connection] = nil end
		if remembered and not Hub.rememberLoopTargets then Hub.targetIdentities[person.UserId] = nil end
		Hub.reconcileTargetIdentities(person)
		if remembered then Hub.loopNotice("targets", "Selected player left", person.Name .. (Hub.rememberLoopTargets and " left. Selection retained for a return to this server." or " left. Their selection was removed."), "left" .. person.UserId,person.Name) end
		refresh()
	end)
	TargetGroup:AddToggle("RememberLoopTargets", {Text = "Remember selected players who leave", Default = true, Callback = function(on)
		Hub.rememberLoopTargets = on
		if not on then
			for id in pairs(Hub.targetIdentities) do if not Hub.selectedTargets[id] then Hub.targetIdentities[id] = nil end end
			refresh()
		end
	end})
	TargetGroup:AddButton({Text = "Clear tracked players", Func = function()
		Hub.targetIdentities = {}
		Hub.selectedTargets = {}
		Hub.targetCursors = {}
		SelectedPlayer = nil
		Hub.refreshTargetSelector()
	end})
	Hub.refreshTargetSelector()
	Hub.cleanup(function()
		for _, entry in pairs(roster) do entry.connection:Disconnect(); Hub.connections[entry.connection] = nil end
		table.clear(roster)
	end)
end
-- End target identity lifecycle.

TargetGroup:AddToggle("LoopKickToggle", {
	Text = "Kick (spam grab)",
	Default = false,
	Callback = function(on)
		local running, ownsRun, onCleanup, bindWorker = Hub.beginTargetLoop("LoopKickToggle", on)
		kickLoopEnabled = on

		local target = SelectedPlayer

		if not on then
			kickLoopEnabled = false
			return
		end

		local bound=Player.Character;local returnRoot=bound and bound:FindFirstChild("HumanoidRootPart");local saved=returnRoot and Hub.teleportFrame(returnRoot)
		onCleanup(function() if Player.Character==bound and returnRoot and returnRoot.Parent==bound and saved then Hub.teleportPart(returnRoot,saved);returnRoot.AssemblyLinearVelocity=Vector3.zero end end)
		local worker=task.spawn(function()
			local RS = ReplicatedStorage
			local RunService = game:GetService("RunService")
			local GE = RS:WaitForChild("GrabEvents")

			local myChar = Player.Character
			local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
			if not myRoot then return end

			local savedPos = Hub.teleportFrame(myRoot)
			local dragging = false
			local grabStartTime = 0

			while running() do
				local nextTarget = Hub.nextLoopTarget("spamGrab", 1)
				if nextTarget ~= target then dragging = false; grabStartTime = 0 end
				target = nextTarget
				if not target then task.wait(0.2); continue end

				local tChar = Hub.canHarm(target) and target.Character or nil
				local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
				local tHum = tChar and tChar:FindFirstChild("Humanoid")

				myChar = Player.Character
				myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

				if tRoot and tHum and tHum.Health > 0 and myRoot then

					if Hub.canAffect(tRoot) then tRoot.AssemblyLinearVelocity = Vector3.zero end
					if Hub.canAffect(tRoot) then tRoot.AssemblyAngularVelocity = Vector3.zero end
					if Hub.canAffect(tRoot) then tRoot.Velocity = Vector3.zero end

					if not dragging then
						if Hub.canAffect(tRoot) then Hub.teleportPart(myRoot, tRoot.CFrame) end
						myRoot.Velocity = Vector3.zero

						pcall(function()
							if Hub.canAffect(tHum) then tHum.PlatformStand = true end
							if Hub.canAffect(tHum) then tHum.Sit = true end
							Hub.fire(GE.SetNetworkOwner, tRoot, Hub.teleportFrame(myRoot))
							Hub.fire(GE.CreateGrabLine, tRoot, Vector3.zero, tRoot.Position, false)
						end)

						if grabStartTime == 0 then grabStartTime = tick() end
						if tick() - grabStartTime > 0.5 then
							dragging = true
							grabStartTime = 0
						end
					else
						Hub.teleportPart(myRoot, savedPos)
						myRoot.Velocity = Vector3.zero

						local lockPos = savedPos * CFrame.new(0, 17, 0)

						if Hub.canAffect(tRoot) then tRoot.CFrame = lockPos end
						if Hub.canAffect(tRoot) then tRoot.Velocity = Vector3.zero end
						if Hub.canAffect(tRoot) then tRoot.RotVelocity = Vector3.zero end

						if Hub.canAffect(tHum) then tHum.PlatformStand = true end
						if Hub.canAffect(tHum) then tHum.Sit = false end

						pcall(function()
							Hub.fire(GE.SetNetworkOwner, tRoot, lockPos)
							Hub.fire(GE.CreateGrabLine, tRoot, Vector3.zero, tRoot.Position, false)
							Hub.fire(GE.DestroyGrabLine, tRoot)
						end)
					end
				else
					dragging = false
					grabStartTime = 0
					if myRoot then
						Hub.teleportPart(myRoot, savedPos)
						myRoot.Velocity = Vector3.zero
					end
				end

				RunService.Heartbeat:Wait()
			end

			if not ownsRun() then return end
			if myRoot then
				Hub.teleportPart(myRoot, savedPos)
				myRoot.Velocity = Vector3.zero
			end
		end)
		bindWorker(worker)
	end
})



-- Loop Kill selected players
-- Shared lifecycle for selected/all kill modes: bounded attempts and immediate cleanup.
do
	local activeRun
	local forces={}
	local function clearForce(force)
		forces[force]=nil;Hub.instances[force]=nil;Hub.assetTargets[force]=nil
		pcall(function() force:Destroy() end)
	end
	local forceElapsed=0
	Hub.connect(RunService.Heartbeat,function(dt)
		forceElapsed+=dt;if forceElapsed<0.1 then return end;forceElapsed=0
		for force,record in pairs(forces) do
			if not force.Parent or not record.run.enabled or record.target.Character~=record.char
				or record.hum.Health<=0 or not Hub.canAffect(record.root) or os.clock()>=record.expires then clearForce(force) end
		end
	end)
	local function cleanupAttempt(run)
		if not run or not run.attempt then return end
		local attempt = run.attempt
		run.attempt = nil
		for part, original in pairs(attempt.collisions) do
			pcall(function()
				if part.Parent then
					if noclipEnabled then part.CanCollide = false else part.CanCollide = original end
				end
			end)
		end
		if Player.Character == attempt.character and attempt.root.Parent == attempt.character then
			attempt.root.CFrame = attempt.position
			attempt.root.AssemblyLinearVelocity = Vector3.zero
			attempt.root.AssemblyAngularVelocity = Vector3.zero
		end
	end
	local function stopRun(run)
		if not run then return end
		run.enabled = false
		for force,record in pairs(forces) do if record.run==run then clearForce(force) end end
		cleanupAttempt(run)
	end
	local function nextAll(run)
		local candidates = {}
		for _, target in ipairs(Players:GetPlayers()) do
			if Hub.loopTargetReady(target) then table.insert(candidates, target) end
		end
		table.sort(candidates, function(a, b) return a.UserId < b.UserId end)
		local nextTarget = candidates[1]
		for _, target in ipairs(candidates) do
			if target.UserId > run.cursor then nextTarget = target; break end
		end
		if nextTarget then run.cursor = nextTarget.UserId end
		return nextTarget
	end
	local function start(key, on, all)
		local running = Hub.beginTargetLoop(key, on)
		Hub.requestSave()
		if key == "LoopKillToggle" then loopKillEnabled = on else loopKillEnabledAll = on end
		if not on then
			if activeRun and activeRun.key == key then stopRun(activeRun); activeRun = nil end
			return
		end
		if activeRun then
			local previous = activeRun
			stopRun(previous)
			activeRun = nil
			if previous.key ~= key and Toggles[previous.key] then Toggles[previous.key]:SetValue(false) end
		end
		local run = {key = key, enabled = true, cursor = 0}
		activeRun = run
		local function live() return run.enabled and activeRun == run and running() end
		task.spawn(function()
			while live() do
				local target = all and nextAll(run) or Hub.nextLoopTarget("loopKill")
				local char = Player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local targetChar = target and target.Character
				local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
				local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
				local targetHead=targetChar and targetChar:FindFirstChild("Head")
				local function valid()
					return live() and Player.Character == char and root and root.Parent == char
						and hum and hum.Health > 0 and not Hub.blobFlightActive and not Hub.safeZoneLoopActive
						and targetRoot and targetRoot.Parent == targetChar and Hub.loopTargetReady(target, targetChar)
						and (all or (targetHead and targetHead.Parent==targetChar and Hub.isSelectedTarget(target)))
				end
				if not valid() then task.wait(0.2); continue end
				local attempt = {character = char, root = root, position = Hub.teleportFrame(root), collisions = {}}
				run.attempt = attempt
				local ok, err = xpcall(function()
					local deadline = os.clock() + 2
					for _ = 0, 50 do
						if not valid() or os.clock() >= deadline then break end
						for _, part in ipairs(char:GetDescendants()) do
							if part:IsA("BasePart") then
								if attempt.collisions[part] == nil then attempt.collisions[part] = part.CanCollide end
								part.CanCollide = false
							end
						end
						SNOWship(targetRoot)
						if not valid() then break end
						if (CheckNetworkOwnerShipOnPlayer and CheckNetworkOwnerShipOnPlayer(target))
							or targetRoot.AssemblyLinearVelocity.Magnitude > 500 then
							if not valid() then break end
							local events = ReplicatedStorage:FindFirstChild("GrabEvents")
							local drop = events and events:FindFirstChild("DestroyGrabLine")
							if drop then Hub.fire(drop, targetRoot) end
							if valid() then
								local force,created=CreateSkyVelocity(targetRoot)
								if created then forces[force]={run=run,target=target,char=targetChar,root=targetRoot,hum=targetHum,expires=os.clock()+2} end
							end
							break
						end
						RunService.Heartbeat:Wait()
						if not valid() then break end
						local offset=targetRoot.Position.Y<=-12 and Vector3.new(0,5,-15) or Vector3.new(0,-10,-10)
						Hub.teleportPart(root,CFrame.new(targetRoot.Position+offset))
						root.AssemblyLinearVelocity=Vector3.zero
						if Hub.canAffect(targetHum) then
							targetHum.BreakJointsOnDeath=false
							targetHum:ChangeState(Enum.HumanoidStateType.Dead)
							targetHum.Jump, targetHum.Sit = true, false
						end
					end
				end, debug.traceback)
				cleanupAttempt(run)
				if not ok and live() then
					Hub.lastKillLoopError = tostring(err)
					warn("[Arriva kill loop] " .. tostring(err))
				end
				if live() then task.wait(0.2) end
			end
			cleanupAttempt(run)
		end)
	end
	TargetGroup:AddToggle("LoopKillToggle", {Text = "Loop kill", Default = false,
		Callback = function(on) start("LoopKillToggle", on, false) end})
	-- Loop Kill All
	TargetGroup:AddToggle("LoopKillToggleAll", {Text = "Loop kill All", Default = false,
		Callback = function(on) start("LoopKillToggleAll", on, true) end})
	Hub.cleanup(function() stopRun(activeRun);activeRun=nil;for force in pairs(forces) do clearForce(force) end end)
end
-- End kill loop lifecycle

local grabBlobLoopEnabled = false
TargetGroup:AddToggle("LoopKickToggle2", {
	Text = "Loop Kick (grab + blob)",
	Default = false,
	Callback = function(on)
		local running, ownsRun, onCleanup, bindWorker = Hub.beginTargetLoop("LoopKickToggle2", on)
		grabBlobLoopEnabled = on
		Hub.requestSave()

		if not on then return end
		local changed={}
		local blobReturn
		onCleanup(function()
			if blobReturn and blobReturn.root.Parent then blobReturn.root.CFrame=blobReturn.frame;blobReturn.root.AssemblyLinearVelocity=Vector3.zero end
			for hum,saved in pairs(changed) do
				if hum.Parent==saved.char and hum.Health>0 then hum.PlatformStand=saved.platform;hum.Sit=saved.sit end
			end
		end)
		autoblob(running)
		if not running() then return end

		local worker=task.spawn(function()
			while running() do
				local seat = Hub.getLoopBlobSeat()
				if not seat then task.wait(0.2); continue end
				local target = Hub.nextLoopTarget("grabBlob", 1)
				if not target then task.wait(0.2); continue end
				local RS = ReplicatedStorage
				local GE = RS:WaitForChild("GrabEvents")
				local RunService = game:GetService("RunService")

				local blob = seat.Parent
				local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
				local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")

				local CG = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
				local CD = scriptObj and scriptObj:FindFirstChild("CreatureDrop")

				local R_Det = blob:FindFirstChild("RightDetector")
				local R_Weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld"))
				if not running() then return end
				if not blobRoot or not CG or not CD or not R_Det or not R_Weld then
					Hub.loopNotice("warnings", "Blobman parts not ready", "The enabled loop will retry after the toy finishes loading.", "blobParts")
					task.wait(0.5)
					continue
				end

				local SavedPos = blobRoot.CFrame
				blobReturn={root=blobRoot,frame=SavedPos}

				local tChar = Hub.canHarm(target) and target.Character or nil
				local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")

				if tRoot and blobRoot then
					local bringStart = tick()
					while running() and tick() - bringStart < 0.35 do
						if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, tChar) or Hub.getLoopBlobSeat() ~= seat or not blobRoot.Parent then break end

						if Hub.canAffect(tRoot) then blobRoot.CFrame = tRoot.CFrame end
						blobRoot.Velocity = Vector3.zero

						pcall(function()
							if CG and R_Det then Hub.fire(CG, R_Det, tRoot, R_Weld) end
							Hub.fire(GE.CreateGrabLine, tRoot, Vector3.zero, tRoot.Position, false)
							Hub.fire(GE.SetNetworkOwner, tRoot, blobRoot.CFrame)
						end)
						RunService.Heartbeat:Wait()
					end

					if not ownsRun() then return end
					if blobRoot.Parent and Hub.getLoopBlobSeat() == seat then
						blobRoot.CFrame = SavedPos
						blobRoot.Velocity = Vector3.zero
					end
					task.wait(0.05)
				end

				local packetTimer = 0

				while running() do
					if Hub.getLoopBlobSeat() ~= seat or not blobRoot.Parent then break end
					target = Hub.nextLoopTarget("grabBlob", 1)
					if not target then task.wait(0.2); continue end

					local tChar = Hub.canHarm(target) and target.Character or nil
					local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
					local tHum = tChar and tChar:FindFirstChild("Humanoid")

					if tRoot and tHum and tHum.Health > 0 and blobRoot then

						blobRoot.CFrame = SavedPos
						blobRoot.Velocity = Vector3.zero

						local lockPos = SavedPos * CFrame.new(0, 23, 0)

						if Hub.canAffect(tRoot) then tRoot.CFrame = lockPos end
						if Hub.canAffect(tRoot) then tRoot.Velocity = Vector3.zero end
						if Hub.canAffect(tRoot) then tRoot.RotVelocity = Vector3.zero end

						if tick() - packetTimer > 0.05 then
							packetTimer = tick()
							pcall(function()
								if Hub.canAffect(tHum) then
									if not changed[tHum] then changed[tHum]={char=tChar,platform=tHum.PlatformStand,sit=tHum.Sit} end
									tHum.PlatformStand = true
								end
								if Hub.canAffect(tHum) then tHum.Sit = true end

								Hub.fire(GE.SetNetworkOwner, tRoot, lockPos)

								if R_Det then
									local weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
									if weld then Hub.fire(CD, weld) end
								end
								Hub.fire(GE.DestroyGrabLine, tRoot)

								if R_Det then Hub.fire(CG, R_Det, tRoot, R_Weld) end
								Hub.fire(GE.CreateGrabLine, tRoot, Vector3.zero, tRoot.Position, false)
							end)
						end
					else
						blobRoot.CFrame = SavedPos
						blobRoot.Velocity = Vector3.zero
					end

					if not running() then break end
					RunService.Heartbeat:Wait()
				end

				if not ownsRun() then return end
				if blobRoot and blobRoot.Parent and Hub.getLoopBlobSeat() == seat then
					blobRoot.CFrame = SavedPos
					blobRoot.Velocity = Vector3.zero
				end
			end
		end)
		bindWorker(worker)
	end
})



local loopKickDualActive = false
TargetGroup:AddToggle("DualHandLoopKick", {
	Text = "Loop Kick",
	Default = false,
	Callback = function(on)
		local running, ownsRun, onCleanup, bindWorker = Hub.beginTargetLoop("DualHandLoopKick", on)
		Hub.requestSave()
		loopKickDualActive = on
		if on then
			local bp
			local boundChar=Player.Character
			local boundRoot=boundChar and boundChar:FindFirstChild("HumanoidRootPart")
			local saved=boundRoot and Hub.teleportFrame(boundRoot)
			local function clearBP()
				if bp then Hub.instances[bp]=nil;Hub.assetTargets[bp]=nil;bp:Destroy();bp=nil end
			end
			onCleanup(function()
				clearBP()
				if Player.Character==boundChar and boundRoot and boundRoot.Parent==boundChar and saved then Hub.teleportPart(boundRoot,saved);boundRoot.AssemblyLinearVelocity=Vector3.zero end
			end)
			if not Hub.nextLoopTarget("dualKick") then
				notify("Error", "Select target first", 3)
				Toggles.DualHandLoopKick:SetValue(false)
				return
			end
			autoblob(running)
			if not running() then return end
			local worker=task.spawn(function()
				local lastTargetCharDual = nil

				while running() do
					local target = Hub.nextLoopTarget("dualKick", 1)
					if not target then
						clearBP()
						lastTargetCharDual = nil
						task.wait(0.2); continue
					end
					local char = Player.Character
					local hum = char and char:FindFirstChild("Humanoid")
					local seat = Hub.getBlobSeat()

					if not seat or not target or not target.Parent then
						clearBP()
						lastTargetCharDual = nil
						task.wait(0.5)
						continue
					end

					local seatParent = seat.Parent
					local grab = seatParent:FindFirstChild("BlobmanSeatAndOwnerScript") and seatParent.BlobmanSeatAndOwnerScript:FindFirstChild("CreatureGrab")
					local drop = seatParent:FindFirstChild("BlobmanSeatAndOwnerScript") and seatParent.BlobmanSeatAndOwnerScript:FindFirstChild("CreatureDrop")

					if not grab or not drop then task.wait(0.5) continue end

					local leftDet = seatParent:FindFirstChild("LeftDetector")
					local rightDet = seatParent:FindFirstChild("RightDetector")
					local leftWeld = leftDet and leftDet:FindFirstChild("LeftWeld")
					local rightWeld = rightDet and rightDet:FindFirstChild("RightWeld")
					if not leftDet or not rightDet or not leftWeld or not rightWeld then
						task.wait(0.2); continue
					end

					local hrp = char:FindFirstChild("HumanoidRootPart")

					local targetChar = Hub.canHarm(target) and target.Character or nil
					local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
					local targetHum = targetChar and targetChar:FindFirstChild("Humanoid")

					if targetHRP and targetHum and targetHum.Health > 0 then
						repeat -- Abandon only this target's handshake if it changes during a yield.
							if targetChar ~= lastTargetCharDual then
								lastTargetCharDual = targetChar
								clearBP()
								if hrp then Hub.teleportPart(hrp, targetHRP.CFrame * CFrame.new(0, 25, 0)) end
								task.wait(0.2)
								if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
								Hub.fire(grab, leftDet, targetHRP, leftWeld)
								task.wait(0.3)
								if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
								Hub.fire(drop, leftWeld, targetHRP)
								task.wait(0.1)
								if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
								bp = Hub.new("BodyPosition")
								bp.Position = Vector3.new(0, 999999, 0)
								bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
								bp.Parent = targetHRP
								Hub.assetTargets[bp]=targetHRP
								Hub.fire(grab, leftDet, targetHRP, leftWeld)
								task.wait(0.2)
								if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
								Hub.fire(drop, leftWeld, targetHRP)
							end

							Hub.fire(grab, leftDet, targetHRP, leftWeld)
							task.wait()
							if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
							Hub.fire(drop, leftWeld, targetHRP)
							task.wait()
							if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
							Hub.fire(grab, rightDet, targetHRP, rightWeld)
							task.wait()
							if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
							Hub.fire(drop, rightWeld, targetHRP)
							task.wait()
							if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
							Hub.fire(grab, leftDet, targetHRP, leftWeld)
							Hub.fire(grab, rightDet, targetHRP, rightWeld)
							task.wait()
							if not running() or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target, targetChar) or Hub.getBlobSeat() ~= seat then break end
							Hub.fire(drop, leftWeld, targetHRP)
							Hub.fire(drop, rightWeld, targetHRP)
							task.wait()
						until true
					else
						task.wait(0.1)
					end
				end
				clearBP()
			end)
			bindWorker(worker)
		else
			loopKickDualActive = false
		end
	end
})



-- Player Fling: preserve exact collision state and bind every resource to its run.
TargetGroup:AddToggle("PlayerFlingBtn",{Text="Fling",Default=false,Callback=function(on)
	local running,_,onCleanup,bindWorker=Hub.beginTargetLoop("PlayerFlingBtn",on);Hub.requestSave()
	if not on then return end
	local char=Player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health<=0 then Toggles.PlayerFlingBtn:SetValue(false);return end
	local saved=Hub.teleportFrame(root);local collisions={};local force
	local function release()
		if force then Hub.instances[force]=nil;Hub.assetTargets[force]=nil;force:Destroy();force=nil end
		for part,value in pairs(collisions) do if part.Parent then if noclipEnabled then part.CanCollide=false else part.CanCollide=value end end;collisions[part]=nil end
		if Player.Character==char and root.Parent==char then Hub.teleportPart(root,saved);root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
	end
	onCleanup(release)
	local worker=task.spawn(function()
		local ok,message=xpcall(function()
			while running() and Player.Character==char and root.Parent==char and hum.Health>0 do
				local target=Hub.nextLoopTarget("fling");local targetChar=target and target.Character
				local targetRoot=targetChar and targetChar:FindFirstChild("HumanoidRootPart")
				if not targetRoot or not Hub.isSelectedTarget(target) or not Hub.loopTargetReady(target,targetChar) then release();task.wait(0.2);continue end
				if not force then
					force=Hub.new("BodyAngularVelocity",root);force.Name="MaestroSpin";force.MaxTorque=Vector3.new(math.huge,math.huge,math.huge)
					force.AngularVelocity=Vector3.new(0,10000,0);force.P=10000
				end
				Hub.assetTargets[force]=targetRoot
				for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then if collisions[part]==nil then collisions[part]=part.CanCollide end;part.CanCollide=false end end
				Hub.teleportPart(root,targetRoot.CFrame);root.AssemblyLinearVelocity=Vector3.zero
				RunService.Heartbeat:Wait()
			end
		end,debug.traceback)
		release();if not ok then warn("[Fling loop] "..tostring(message)) end
	end)
	bindWorker(worker)
end})

-- Blobman Controls
_G.AutoSitBlobZ = true
BlobGroup:AddToggle("AutoSitZ", {
	Text = "Auto Sit Blobman [B]",
	Default = true,
	Callback = function(Value)
		_G.AutoSitBlobZ = Value
	end
})

Hub.connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and Hub.matchesKeybind("BlobSeatKey", input, "B") and _G.AutoSitBlobZ then
		task.spawn(function() autoblob() end)
	end
end)

-- Blob Fly System
do
	local activeRoot, activeCharacter, activeSeat, velocity, gyro
	local speed = 50
	local status = BlobGroup:AddLabel("Blob Fly: sit in a Blobman, then press R.")
	local function discard(object)
		if not object then return end
		Hub.instances[object], Hub.assetTargets[object] = nil, nil
		pcall(function() object:Destroy() end)
	end
	local function stop()
		discard(velocity); discard(gyro)
		velocity, gyro, activeRoot, activeCharacter, activeSeat = nil, nil, nil, nil, nil
		Hub.blobFlightActive = false
		status:SetText("Blob Fly off. Sit in a Blobman and use your flight shortcut to start.")
	end
	Hub.stopBlobFlight = stop
	local function seatedRoot()
		local char = Player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		local blob = seat and seat.Parent
		if not hum or hum.Health <= 0 or not seat or seat.Occupant ~= hum
			or not blob or blob.Name ~= "CreatureBlobman" then return end
		-- Vehicle-fly applies force to the rider's root, joined to the vehicle by its seat weld.
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not root.Parent or root.Anchored then return end
		return root, char, seat
	end
	function Hub.setBlobFlight(on)
		if not on then stop(); return true end
		local root, char, seat = seatedRoot()
		if not root then
			stop(); status:SetText("Sit in a live, unanchored Blobman before starting flight."); return false
		end
		stop()
		activeRoot, activeCharacter, activeSeat = root, char, seat
		velocity = Hub.new("BodyVelocity", root)
		velocity.Name = "BlobFlyVelocity"
		velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		velocity.P = 1250
		velocity.Velocity = Vector3.zero
		gyro = Hub.new("BodyGyro", root)
		gyro.Name = "BlobFlyGyro"
		gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
		gyro.P, gyro.D = 9e4, 500
		gyro.CFrame = Hub.teleportFrame(root)
		Hub.blobFlightActive = true
		if Hub.updateHeavyBlobman then Hub.updateHeavyBlobman() end
		status:SetText("Vehicle Fly: W follows your view (look up/down to climb/dive), S reverses, A/D strafe, E/Q rise/descend. Release keys to hover.")
		return true
	end
	local function finite(vector)
		return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z
			and math.abs(vector.X) < math.huge and math.abs(vector.Y) < math.huge and math.abs(vector.Z) < math.huge
	end
	function Hub.updateBlobFlight()
		if not Hub.blobFlightActive then return end
		local root, char, seat = seatedRoot()
		if root ~= activeRoot or char ~= activeCharacter or seat ~= activeSeat or not velocity.Parent or not gyro.Parent then stop(); return end
		local camera = Workspace.CurrentCamera
		if not camera or not finite(camera.CFrame.LookVector) or not finite(camera.CFrame.RightVector) or not finite(camera.CFrame.UpVector) then
			velocity.Velocity = Vector3.zero; return
		end
		local look, right = camera.CFrame.LookVector, camera.CFrame.RightVector
		local move = Vector3.zero
		if not UserInputService:GetFocusedTextBox() and not Hub.keybindCaptureActive then
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
			if UserInputService:IsKeyDown(Enum.KeyCode.E) then move += camera.CFrame.UpVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= camera.CFrame.UpVector end
		end
		if move.Magnitude > 1 then move = move.Unit end
		-- Immediate camera-relative travel and full camera orientation, like vehiclefly.
		velocity.Velocity = move * speed
		gyro.CFrame = camera.CFrame
	end
	Hub.connect(UserInputService.InputBegan, function(input, processed)
		if not processed and not UserInputService:GetFocusedTextBox() and Hub.matchesKeybind("BlobFlyKey", input, "R") then
			Hub.setBlobFlight(not Hub.blobFlightActive)
		end
	end)
	Hub.connect(RunService.PreSimulation or RunService.Heartbeat, Hub.updateBlobFlight)
	Hub.connect(Player.CharacterRemoving, stop)
	BlobGroup:AddSlider("BlobFlySpeed", {Text = "Blob Fly speed", Default = 50, Min = 10, Max = 150, Rounding = 0,
		Callback = function(value) speed = value end})
	BlobGroup:AddButton({Text = "Start Blob Fly", Func = function() Hub.setBlobFlight(true) end})
	BlobGroup:AddButton({Text = "Stop Blob Fly", Func = stop})
	Hub.cleanup(function()
		stop()
		Hub.stopBlobFlight, Hub.setBlobFlight, Hub.updateBlobFlight = nil, nil, nil
	end)
end
-- End Blob Fly System

-- Destroy Target Gucci
local DestroyTargetGucciActive = false
TargetGroup:AddToggle("DestroyTargetGucci", {
	Text = "Destroy Gucci (sit)",
	Default = false,
	Callback = function(Value)
		local running, ownsRun = Hub.beginTargetLoop("DestroyTargetGucci", Value)
		DestroyTargetGucciActive = Value

		if Value then
			if not SelectedPlayer then
				notify("Error", "Select a target", 3)
				Toggles.DestroyTargetGucci:SetValue(false)
				return
			end

			local char = Player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then return end

			local SafeSpot = Hub.teleportFrame(root)
			local RunService = game:GetService("RunService")

			local folderName = SelectedPlayer.Name .. "SpawnedInToys"
			notify("System", "Awaiting folder " .. folderName, 3)

			task.spawn(function()
				while running() do
					local target = Hub.nextLoopTarget("destroyGucci")
					if not target then task.wait(0.2); continue end
					local folderName = target.Name .. "SpawnedInToys"

					local toysFolder = workspace:FindFirstChild(folderName)

					if not toysFolder then
						task.wait(1)
					else
						local foundBlob = false

						for _, obj in ipairs(toysFolder:GetChildren()) do
							if not running() or not Hub.canAffect(toysFolder) then break end

							if obj.Name == "CreatureBlobman" then
								foundBlob = true
								local seat = obj:FindFirstChild("VehicleSeat") or obj:FindFirstChildWhichIsA("VehicleSeat", true)

								if seat and Hub.canAffect(seat) then
									local myChar = Player.Character
									local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
									local myHum = myChar and myChar:FindFirstChild("Humanoid")

									if myRoot and myHum then
										if myHum.SeatPart ~= seat then
											notify("Target", "Reset", 1)

											local magnetConnection
											magnetConnection = Hub.connect(RunService.Stepped, function()
												if myRoot and seat and Hub.canAffect(seat) then
													Hub.teleportPart(myRoot, seat.CFrame)
													myRoot.Velocity = Vector3.zero
													if obj.PrimaryPart then
														obj.PrimaryPart.Velocity = Vector3.zero
														obj.PrimaryPart.RotVelocity = Vector3.zero
													end
												end
											end)

											local sitStart = tick()
											while tick() - sitStart < 1 do
												if not running() or not Hub.canAffect(toysFolder) then break end
												if myHum.SeatPart == seat then break end

												if Hub.canAffect(seat) then seat:Sit(myHum) end
												task.wait()
											end

											if magnetConnection then magnetConnection:Disconnect() end

											if myHum.SeatPart == seat then
												task.wait(0.3)
												myHum.Sit = false
												myHum.Jump = true

												task.wait(0.05)
												Hub.teleportPart(myRoot, SafeSpot)
												myRoot.Velocity = Vector3.zero

												notify("Success", "Removal complete", 1)
												task.wait(0.5)
											else
												Hub.teleportPart(myRoot, SafeSpot)
											end
										end
									end
								end
							end
						end
					end
					task.wait(1)
				end
			end)
		else
			DestroyTargetGucciActive = false
			notify("System", "Gucci disabled", 2)
		end
	end
})

-- Target Buttons
TargetGroup:AddButton({
	Text = "bring (blob)",
	Func = function()
		if not Hub.canHarm(SelectedPlayer) then return end

		if not autoblob() then
			notify("Bring", "Could not sit in a ready Blobman; try again after it loads", 3)
			return
		end
		local seat = Hub.getBlobSeat()
		if not seat then return end

		local blob = seat.Parent
		local blobRoot = blob:FindFirstChild("HumanoidRootPart")
		local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
		if not blobRoot or not scriptObj then return end

		local CG = scriptObj:FindFirstChild("CreatureGrab")
		local CD = scriptObj:FindFirstChild("CreatureDrop")
		local R_Det = blob:FindFirstChild("RightDetector")
		local R_Weld = R_Det and R_Det:FindFirstChild("RightWeld")

		local tChar = Hub.canHarm(SelectedPlayer) and SelectedPlayer.Character or nil
		local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
		if not tRoot then return end

		local home = blobRoot.CFrame
		if Hub.canAffect(tRoot) then blobRoot.CFrame = tRoot.CFrame end
		blobRoot.Velocity = Vector3.new()
		blobRoot.RotVelocity = Vector3.new()
		task.wait(0.3)

		pcall(function()
			Hub.fire(CG, R_Det, tRoot, R_Weld)
		end)

		task.wait(0.5)
		blobRoot.CFrame = home
		blobRoot.Velocity = Vector3.new()
		blobRoot.RotVelocity = Vector3.new()
		task.wait(0.05)

		for i = 1, 12 do
			if Hub.canAffect(tRoot) then tRoot.CFrame = home * CFrame.new(0,3,0) end
			if Hub.canAffect(tRoot) then tRoot.Velocity = Vector3.new() end
			if Hub.canAffect(tRoot) then tRoot.RotVelocity = Vector3.new() end
			task.wait(0.03)
		end

		for i = 1, 8 do
			local weld = R_Det:FindFirstChild("RightWeld")
			if weld then
				pcall(function()
					Hub.fire(CD, weld)
				end)
			end
			task.wait(0.03)
		end
	end
})

function GetPlayerCFrame()
	local playerCharacterCFrame = GetPlayerCharacter()
	if playerCharacterCFrame then
		return playerCharacterCFrame.HumanoidRootPart.CFrame
	end
end
freezecampart = Instance.new("Part", workspaceService)
freezecampart.Anchored = true
freezecampart.CanCollide = false
freezecampart.Transparency = 1
freezecampart.CanQuery = false
freezecampart.Size = Vector3.new()

function FreezeCam(freezeCamCFrame)
	freezecampart.CFrame = freezeCamCFrame
	workspace.CurrentCamera.CameraType = Enum.CameraType.Follow
	workspace.CurrentCamera.CameraSubject = freezecampart
end
function unFreezeCam()
	workspace.CurrentCamera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

function CreateBringBody(targetPart,destination)
	if not targetPart or not targetPart.Parent or not Hub.canAffect(targetPart) then return end
	local force=Hub.new("BodyPosition",targetPart);force.Name="ArrivaBringBody"
	force.Position=destination.Position;force.MaxForce=Vector3.new(math.huge,math.huge,math.huge);force.D=5000;force.P=1500000
	Hub.assetTargets[force]=targetPart
	task.delay(0.35,function()
		Hub.instances[force]=nil;Hub.assetTargets[force]=nil;force:Destroy()
		local events=ReplicatedStorage:FindFirstChild("GrabEvents");local drop=events and events:FindFirstChild("DestroyGrabLine")
		if drop and targetPart.Parent then Hub.fire(drop,targetPart) end
	end)
	return force
end

function TeleportPlayer(cframeOffset,teleportPriority)
	local requested=teleportPriority==nil and 0 or teleportPriority
	local active=_G.TP_Priority==nil and 0 or _G.TP_Priority
	if requested~=active or _G.TeleportingToNetworkOwnership or typeof(cframeOffset)~="CFrame" then return false end
	local char=GetPlayerCharacter()
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health<=0 or Hub.gucciCharacterBusy(char) then return false end
	Hub.teleportPart(root, Hub.teleportFrame(root).Rotation+cframeOffset.Position)
	local run=Hub.gucciSeatRun
	if not (run and run.Char==char and run.Seat==hum.SeatPart) and (not hum.SeatPart or not hum.SeatPart.Parent or hum.SeatPart.Parent.Name~="CreatureBlobman") then hum.Sit=false end
	return true
end


function CheckPlayerVelocity(player)
	if typeof(player)~="Instance" or not player:IsA("Player") then return math.huge end
	local char=player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	return root and root.AssemblyLinearVelocity.Magnitude or math.huge
end
function CheckPlayer(player)
	if not Hub.canHarm(player) then return false end
	local char=player.Character
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	return char~=nil and char:IsDescendantOf(workspaceService) and char:FindFirstChild("HumanoidRootPart")~=nil
		and hum~=nil and hum.Health>0
end
function CheckPlayerBring(player)
	if not CheckPlayer(player) then return false end
	local inPlot=player:FindFirstChild("InPlot")
	return not (inPlot and inPlot.Value==true) and CheckPlayerVelocity(player)<20
end
function CheckNetworkOwnerShipOnPart(potentialPart, condition)
	if typeof(potentialPart) == "Instance" and (potentialPart:FindFirstChild("PartOwner") and potentialPart.PartOwner.Value == LocalPlayer.Name) then
		return not condition and true or potentialPart.PartOwner
	end
end
function SNOWshipOnce(part)
	local char=LocalPlayer.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
	if not root or not part or not part.Parent or not Hub.canAffect(part) then return false end
	if CheckNetworkOwnerShipOnPart(part) then return true end
	local origin=Hub.teleportFrame(root).Position
	if (origin-part.Position).Magnitude<=30 then
		local aim=Hub.lookAt(origin+Vector3.new(0,1.593,0),part.Position)
		if aim then Hub.fire(setNetworkOwnerEvent,part,aim) end
	end
	return false
end

-- Bring All: Resonance-style confirmed ownership, three-frame pivot and release.
local BringAll=false
TargetGroup:AddToggle("BringAllGrab",{Text="Bring All",Default=false,Callback=function(on)
	local running,_,onCleanup,bindWorker=Hub.beginTargetLoop("BringAllGrab",on);BringAll=on;Hub.requestSave()
	if not on then return end
	local char=Player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
	if not root then Toggles.BringAllGrab:SetValue(false);return end
	local saved=Hub.teleportFrame(root)
	local function restore() if Player.Character==char and root.Parent==char then Hub.teleportPart(root,saved);root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end end
	onCleanup(restore)
	local worker=task.spawn(function()
		while running() and Player.Character==char do
			for _,target in ipairs(Players:GetPlayers()) do
				if not running() or Player.Character~=char then break end
				if CheckPlayerBring(target) then
					local targetChar=target.Character;local targetRoot=targetChar:FindFirstChild("HumanoidRootPart")
					local function valid() return running() and Player.Character==char and target.Character==targetChar and targetRoot.Parent==targetChar and CheckPlayer(target) end
					local ok,message=xpcall(function()
						for _=1,51 do
							if not valid() then break end
							SNOWshipOnce(targetRoot)
							if CheckNetworkOwnerShipOnPlayer(target) then
								for _=1,3 do
									if not valid() then break end
									targetChar:PivotTo(saved*CFrame.new(0,0,-5)*targetRoot.CFrame:Inverse()*targetChar:GetPivot())
									for _,part in ipairs(targetChar:GetDescendants()) do if part:IsA("BasePart") then part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero end end
									RunService.Heartbeat:Wait()
								end
								local events=ReplicatedStorage:FindFirstChild("GrabEvents");local drop=events and events:FindFirstChild("DestroyGrabLine")
								if drop and targetRoot.Parent then Hub.fire(drop,targetRoot) end
								break
							end
							local offset=targetRoot.Position.Y<=-12 and Vector3.new(0,5,-15) or Vector3.new(0,-10,-10)
							Hub.teleportPart(root,CFrame.new(targetRoot.Position+offset));RunService.Heartbeat:Wait()
						end
					end,debug.traceback)
					restore();if not ok then warn("[Bring All] "..tostring(message)) end
				end
			end
			if running() then task.wait(0.2) end
		end
		restore()
	end)
	bindWorker(worker)
end})

-- Loop Bring: rotate selected players and bring them to the current local anchor.
TargetGroup:AddToggle("LoopBringSelected",{Text="Bring selected",Default=false,Callback=function(on)
	local running,_,onCleanup,bindWorker=Hub.beginTargetLoop("LoopBringSelected",on);Hub.requestSave()
	if not on then return end
	local char=Player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
	if not root then Toggles.LoopBringSelected:SetValue(false);return end
	local saved=Hub.teleportFrame(root)
	local requestedRoot
	local function restore()
		if requestedRoot then
			local events=ReplicatedStorage:FindFirstChild("GrabEvents");local drop=events and events:FindFirstChild("DestroyGrabLine")
			if drop and requestedRoot.Parent then pcall(Hub.fire,drop,requestedRoot) end
			requestedRoot=nil
		end
		if Player.Character==char and root.Parent==char then Hub.teleportPart(root,saved);root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end end
	onCleanup(restore)
	local worker=task.spawn(function()
		while running() and Player.Character==char do
			saved=Hub.teleportFrame(root)
			local selected=Hub.nextLoopTarget("loopBring")
			for _,target in ipairs(selected and {selected} or {}) do
				if not running() or Player.Character~=char then break end
				if CheckPlayerBring(target) then
					local targetChar=target.Character;local targetRoot=targetChar:FindFirstChild("HumanoidRootPart")
					local function valid() return running() and Player.Character==char and target.Character==targetChar and targetRoot.Parent==targetChar and CheckPlayer(target) and Hub.isSelectedTarget(target) end
					local ok,message=xpcall(function()
						for _=1,51 do
							if not valid() then break end
							requestedRoot=targetRoot;SNOWshipOnce(targetRoot)
							if CheckNetworkOwnerShipOnPlayer(target) then
								for _=1,3 do
									if not valid() then break end
									targetChar:PivotTo(saved*CFrame.new(0,0,-5)*targetRoot.CFrame:Inverse()*targetChar:GetPivot())
									for _,part in ipairs(targetChar:GetDescendants()) do if part:IsA("BasePart") then part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero end end
									RunService.Heartbeat:Wait()
								end
								local events=ReplicatedStorage:FindFirstChild("GrabEvents");local drop=events and events:FindFirstChild("DestroyGrabLine")
								if drop and targetRoot.Parent then Hub.fire(drop,targetRoot) end
								break
							end
							local offset=targetRoot.Position.Y<=-12 and Vector3.new(0,5,-15) or Vector3.new(0,-10,-10)
							Hub.teleportPart(root,CFrame.new(targetRoot.Position+offset));RunService.Heartbeat:Wait()
						end
					end,debug.traceback)
					restore();if not ok then warn("[Loop Bring] "..tostring(message)) end
				end
			end
			if running() then task.wait(0.2) end
		end
		restore()
	end)
	bindWorker(worker)
end})

do
	(function()
		TargetGroup:AddButton({Text="Bring (grab)",Func=function()
			if BringAll or Hub.singleBringBusy then notify("Bring","Stop Bring All or wait for the current bring to finish.",4);return end
			if Hub.safeZoneLoopActive then notify("Bring","Turn off Loop go to safe zone before bringing a player.",4);return end
			local target=SelectedPlayer
			if not CheckPlayerBring(target) then notify("Bring","Selected player is protected, in a plot, moving too quickly or not ready.",5);return end
			local myChar=Player.Character
			local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
			local myHum=myChar and myChar:FindFirstChildOfClass("Humanoid")
			local targetChar=target.Character
			local root=targetChar:FindFirstChild("HumanoidRootPart")
			local hum=targetChar:FindFirstChildOfClass("Humanoid")
			local ragdolled=hum and hum:FindFirstChild("Ragdolled")
			if not myRoot or not myHum or myHum.Health<=0 or not root or not ragdolled then notify("Bring","Character parts or Ragdolled value are not ready.",4);return end
			Hub.singleBringBusy=true
			task.spawn(function()
				local saved=Hub.teleportFrame(myRoot)
				local camera=Workspace.CurrentCamera
				local cameraState=camera and {kind=camera.CameraType,subject=camera.CameraSubject,cf=camera.CFrame}
				local success=false
				local function current()
					return Hub.alive and not BringAll and not Hub.safeZoneLoopActive and Player.Character==myChar and myRoot.Parent==myChar and myHum.Health>0
						and target.Character==targetChar and root.Parent==targetChar and hum.Parent==targetChar and hum.Health>0 and Hub.canHarm(target)
				end
				local ok,err=xpcall(function()
					if camera then FreezeCam(CFrame.lookAt(camera.CFrame.Position+Vector3.new(-15,15,0),saved.Position)) end
					for _=1,51 do
						if not current() then break end
						local plot=target:FindFirstChild("InPlot")
						if plot and plot.Value then break end
						SNOWshipOnce(root)
						if CheckNetworkOwnerShipOnPlayer(target) then
							if not ragdolled.Value and target:DistanceFromCharacter(saved.Position)>10 then Hub.teleportPart(root, saved) end
							CreateBringBody(root,saved)
							success=true;break
						end
						task.wait()
						if not current() then break end
						TeleportPlayer(CFrame.new(Hub.teleportFrame(root).Position+Vector3.new(0,Hub.teleportFrame(root).Position.Y<=-12 and 5 or -10,Hub.teleportFrame(root).Position.Y<=-12 and -15 or -10)))
					end
				end,debug.traceback)
				if Player.Character==myChar and myRoot.Parent==myChar and myHum.Health>0 and not Hub.safeZoneLoopActive then
					pcall(function() Hub.teleportPart(myRoot, saved);myRoot.AssemblyLinearVelocity=Vector3.zero;myRoot.AssemblyAngularVelocity=Vector3.zero end)
				end
				if camera and cameraState and Workspace.CurrentCamera==camera then pcall(function()
						camera.CameraType=cameraState.kind;camera.CameraSubject=cameraState.subject;camera.CFrame=cameraState.cf
					end) end
				Hub.singleBringBusy=false
				if not ok then warn("[Arriva Bring selected] " .. tostring(err));notify("Bring","Bring stopped after an error, your position was restored where possible.",5)
				elseif success then notify("Bring",target.Name .. " brought to your starting position.",4)
				else notify("Bring","Target changed or ownership was not confirmed before retries ended.",5) end
			end)
		end})
	end)()
end

-- Anti Anti-Kick
local antiAntiKickActive = false
TargetGroup:AddToggle("DestroyAntiKickToggle", {
	Text = "Grab Anti Kick",
	Default = false,
	Callback = function(Value)
		local running, ownsRun, _, bindWorker = Hub.beginTargetLoop("DestroyAntiKickToggle", Value)
		antiAntiKickActive = Value

		if Value then
			local worker=task.spawn(function()
				local function ownerRemote() local events=ReplicatedStorage:FindFirstChild("GrabEvents");return events and events:FindFirstChild("SetNetworkOwner") end

				local function invis_touch(part, cf)
					local event=ownerRemote();if running() and event and part.Parent then Hub.fire(event,part,cf) end
				end

				local function CheckAndYeet(toy)
					if not running() or not Hub.canAffect(toy) then return end
					local part = toy:FindFirstChild("SoundPart")
					if part then
						invis_touch(part, part.CFrame)
						if Hub.canAffect(part) and part:FindFirstChild("PartOwner") and part.PartOwner.Value == Player.Name then
							if Hub.canAffect(part) then Hub.teleportPart(part, CFrame.new(0, 1000, 0)) end
						end
					end
				end

				while running() do
					local target = Hub.nextLoopTarget("antiKick")
					if not target then task.wait(0.2); continue end
					if Hub.canHarm(target) then
						local spawned = workspace:FindFirstChild(target.Name.."SpawnedInToys")
						if spawned then
							if spawned:FindFirstChild("NinjaKunai") then
								CheckAndYeet(spawned.NinjaKunai)
							end
							if spawned:FindFirstChild("NinjaKatana") then
								CheckAndYeet(spawned.NinjaKatana)
							end
							if spawned:FindFirstChild("ToolCleaver") then
								CheckAndYeet(spawned.ToolCleaver)
							end
							if spawned:FindFirstChild("ToolPickaxe") then
								CheckAndYeet(spawned.ToolPickaxe)
							end
							if spawned:FindFirstChild("NinjaShuriken") then
								CheckAndYeet(spawned.NinjaShuriken)
							end
							if spawned:FindFirstChild("AntiKick") then
								CheckAndYeet(spawned.AntiKick)
							end
						end
					end
					task.wait(0.1)
				end
			end)
			bindWorker(worker)
		else
			antiAntiKickActive = false
		end
	end
})

-- Anti Anti Input Lag: only holdables attached to the current selected character.
TargetGroup:AddToggle("AntiAntiInputLag",{Text="Anti Anti Input Lag",Default=false,Callback=function(on)
	local running,_,onCleanup,bindWorker=Hub.beginTargetLoop("AntiAntiInputLag",on);Hub.requestSave()
	if not on then return end
	local char=Player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
	if not root then Toggles.AntiAntiInputLag:SetValue(false);return end
	local pending
	onCleanup(function() if pending and pending~=coroutine.running() and coroutine.status(pending)~="dead" then pcall(Hub.nativeTask.cancel,pending);Hub.threads[pending]=nil end end)
	local worker=task.spawn(function()
		while running() and Player.Character==char and root.Parent==char do
			local target=Hub.nextLoopTarget("antiInputItem");local targetChar=target and target.Character
			if not targetChar or not Hub.loopTargetReady(target,targetChar) then task.wait(0.2);continue end
			local seen={};local own=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			for _,name in ipairs({"Left Arm","Right Arm","LeftHand","RightHand"}) do
				local arm=targetChar:FindFirstChild(name)
				if arm then for _,part in ipairs(arm:GetConnectedParts(true)) do
					if not running() or target.Character~=targetChar or not Hub.loopTargetReady(target,targetChar) then break end
					local model=part.Parent
					if part.Name=="HoldPart" and model and not seen[model] and not (own and part:IsDescendantOf(own)) and Hub.canAffect(model) then
						seen[model]=true
						local hold=part:FindFirstChild("HoldItemRemoteFunction");local drop=part:FindFirstChild("DropItemRemoteFunction")
						if hold and drop then
							local done=false
							pending=task.spawn(function()
								if not running() or target.Character~=targetChar or not Hub.isSelectedTarget(target) or not Hub.canAffect(model) then done=true;return end
								pcall(Hub.invoke,hold,model,char)
								if running() and Player.Character==char and target.Character==targetChar and Hub.isSelectedTarget(target) and Hub.loopTargetReady(target,targetChar) and Hub.canAffect(model) then pcall(Hub.invoke,drop,model,CFrame.new(Hub.teleportFrame(root).Position+Vector3.new(0,-2000,0)),Vector3.zero) end
								done=true
							end)
							local deadline=os.clock()+0.75
							repeat task.wait() until done or not running() or os.clock()>=deadline
							if not done and coroutine.status(pending)~="dead" then pcall(Hub.nativeTask.cancel,pending);Hub.threads[pending]=nil end
							pending=nil
						end
					end
				end end
			end
			if running() then task.wait(0.1) end
		end
	end)
	bindWorker(worker)
end})

-- Whitelist System: selected players are protected, never automatically targeted.
do
	local refreshing = false
	local function labelFor(player)
		return player.DisplayName .. " (@" .. player.Name .. ") [" .. player.UserId .. "]"
	end
	local function valuesAndSelected()
		local values, selected, seen = {}, {}, {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= Player then
				local id = tostring(player.UserId)
				local label = labelFor(player)
				table.insert(values, label); seen[id] = true
				if Hub.manualWhitelist[id] or Hub.manualWhitelist["name:" .. player.Name:lower()] then
					Hub.manualWhitelist["name:" .. player.Name:lower()] = nil
					Hub.manualWhitelist[id] = label
					selected[label] = true
				end
			end
		end
		for id, label in pairs(Hub.manualWhitelist) do
			if not seen[id] then table.insert(values, label); selected[label] = true end
		end
		table.sort(values)
		return values, selected
	end
	local values, initial = valuesAndSelected()
	refreshing = true
	WhitelistGroup:AddDropdown("MultiWhitelist", {
		Values = values, Default = {}, Multi = true, Text = "Whitelist people (protected)",
		Callback = function(selection)
			if refreshing then return end
			local manual = {}
			for label, chosen in pairs(selection) do
				if chosen then
					local id = label:match("%[(%d+)%]$")
					local name = label:match("%(@?(.-)%)")
					local player = name and Players:FindFirstChild(name)
					if not id and player then id = tostring(player.UserId) end
					if id then manual[id] = label
					elseif name then manual["name:" .. name:lower()] = label end
				end
			end
			Hub.manualWhitelist = manual
			Hub.reconcileProtection()
			Hub.queueSafetySave()
			Hub.requestSave()
		end,
	})
	Hub.refreshWhitelistUI = function()
		local values, selected = valuesAndSelected()
		refreshing = true
		Options.MultiWhitelist:SetValues(values)
		Options.MultiWhitelist:SetValue(selected)
		refreshing = false
	end
	Hub.refreshWhitelistUI()
	WhitelistGroup:AddToggle("WhitelistFriends", {
		Text = "Whitelist friends", Default = true,
		Callback = function(on)
			Hub.whitelistFriends = on
			table.clear(Hub.friendCache)
			Hub.reconcileProtection()
			if on then for _, player in ipairs(Players:GetPlayers()) do Hub.checkFriend(player) end end
			Hub.requestSave()
		end,
	})
	WhitelistGroup:AddButton({Text = "Refresh list / friend checks", Func = function()
		table.clear(Hub.friendCache)
		Hub.refreshWhitelistUI()
		if Hub.whitelistFriends then for _, player in ipairs(Players:GetPlayers()) do Hub.checkFriend(player) end end
	end})
end

-- Joined Notify
local notifyActive = false
local notifyConnection = nil
TargetNotificationGroup:AddToggle("JoinedNotifyBtn", {
	Text = "Target Joined Notify",
	Default = false,
	Callback = function(on)
		Hub.requestSave()
		notifyActive = on

		if on then
			notify("Radar", "Tracking targets. Waiting for targets that have returned / re-entered…", 3)

			if notifyConnection then notifyConnection:Disconnect() end

			notifyConnection = Hub.connect(Players.PlayerAdded, function(newPlayer)
				if not notifyActive then return end

				local detected = false
				local reason = ""

				if Hub.isProtected(newPlayer) then detected = true; reason = "[Protected]" end

				if not detected and Hub.isSelectedTarget(newPlayer) then
					detected = true
					reason = "[Main Target]"
				end

				if detected then
					notify("Target Returned!",newPlayer.Name.." returned. "..reason,8,"join",newPlayer.Name)
					if Hub.isSelectedTarget(newPlayer) and Hub.canHarm(newPlayer) then SelectedPlayer = SelectedPlayer or newPlayer end
					-- Join sound follows the event sound controls and notification master switch.
				end
			end)
		else
			if notifyConnection then notifyConnection:Disconnect() notifyConnection = nil end
			notify("Radar", "Tracking Disabled", 2)
		end
	end
})

local respawnNotifyActive = false
local respawnConnections = {}
Hub.connect(Players.PlayerRemoving,function(player)
	local c=respawnConnections[player]
	if c then c:Disconnect();Hub.connections[c]=nil;respawnConnections[player]=nil end
end)

local function isTrackedPlayer(player)
	if Hub.isProtected(player) then return true, "[Protected]" end
	if Hub.isSelectedTarget(player) then return true, "[Main Target]" end
	return false, nil
end

local function trackRespawn(player)
	if respawnConnections[player] then return end

	respawnConnections[player] = Hub.connect(player.CharacterAdded, function()
		if not respawnNotifyActive then return end

		local tracked, reason = isTrackedPlayer(player)
		if not tracked then return end

		notify("Target respawned", player.Name .. " has respawned. " .. reason, 8,"respawn",player.Name)
		if Hub.isSelectedTarget(player) and Hub.canHarm(player) then SelectedPlayer = SelectedPlayer or player end

		-- Respawn sound follows the event sound controls and notification master switch.
	end)
end

TargetNotificationGroup:AddToggle("RespawnNotifyBtn", {
	Text = "Target Respawn Notify",
	Default = false,
	Callback = function(on)
		Hub.requestSave()
		respawnNotifyActive = on

		if on then
			notify("Radar", "Tracking target respawns…", 3)

			-- Hook all current players
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= Player then
					trackRespawn(plr)
				end
			end

			-- Hook new players too
			if respawnConnections["_PlayerAdded"] then respawnConnections["_PlayerAdded"]:Disconnect();Hub.connections[respawnConnections["_PlayerAdded"]]=nil end
			respawnConnections["_PlayerAdded"] = Hub.connect(Players.PlayerAdded, function(plr)
				trackRespawn(plr)
			end)
		else
			-- Cleanup
			for _, conn in pairs(respawnConnections) do
				pcall(function()
					conn:Disconnect()
				end)
			end
			respawnConnections = {}
			notify("Radar", "Respawn tracking disabled", 2)
		end
	end
})

-- Player aura controls and local proximity feedback.
do
	local group = Tabs.Aura:AddLeftGroupbox("Player Auras")
	Hub.playerAuraControls=group
	Hub.auraSettings = {range = 50, selectedOnly = false, alertCooldown = 10, flingStrength = 100}

	function Hub.auraTargetInRange(target, myChar, targetChar)
		if Player.Character ~= myChar or not myChar then return false end
		local root = myChar:FindFirstChild("HumanoidRootPart")
		local hum = myChar:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then return false end
		if not Hub.loopTargetReady(target, targetChar) then return false end
		if Hub.auraSettings.selectedOnly and not Hub.isSelectedTarget(target) then return false end
		local otherRoot = target.Character:FindFirstChild("HumanoidRootPart")
		return (Hub.teleportFrame(root).Position - otherRoot.Position).Magnitude <= Hub.auraSettings.range
	end

	function Hub.getAuraTargets(myChar)
		local targets, distances = {}, {}
		for _, target in ipairs(Players:GetPlayers()) do
			if Hub.auraTargetInRange(target, myChar) then
				table.insert(targets, target)
				distances[target] = (myChar.HumanoidRootPart.Position - target.Character.HumanoidRootPart.Position).Magnitude
			end
		end
		table.sort(targets, function(a, b)
			if distances[a] == distances[b] then return a.UserId < b.UserId end
			return distances[a] < distances[b]
		end)
		return targets
	end

	function Hub.collectAuraEntries(targets, previous, cooldowns, now)
		local entering, inside = {}, {}
		for _, target in ipairs(targets) do
			local id = target.UserId
			inside[id] = true
			if not previous[id] and (not cooldowns[id] or now >= cooldowns[id]) then
				table.insert(entering, target)
				cooldowns[id] = now + Hub.auraSettings.alertCooldown
			end
		end
		return entering, inside
	end

	local function runAura(id, enabled, effect)
		local running = Hub.beginTargetLoop(id, enabled)
		if not enabled then return end
		task.spawn(function()
			while running() do
				local myChar = Player.Character
				for _, target in ipairs(Hub.getAuraTargets(myChar)) do
					if not running() then break end
					local targetChar = target.Character
					for _ = 1, 50 do
						if not running() or not Hub.auraTargetInRange(target, myChar, targetChar) then break end
						if SNOWshipPlayer(target, function()
								if running() and Hub.auraTargetInRange(target, myChar, targetChar) then
									effect(target, myChar, targetChar, running)
								end
							end) then break end
						task.wait()
					end
					task.wait(0.1)
				end
				task.wait(0.5)
			end
		end)
	end

	group:AddToggle("Deathaura", {Text = "Death Aura", Default = false, Callback = function(on)
		runAura("Deathaura", on, function(target, myChar, targetChar, running)
			local root = targetChar:FindFirstChild("HumanoidRootPart")
			local hum = targetChar:FindFirstChildOfClass("Humanoid")
			CreateSkyVelocity(root)
			for _ = 0, 20 do
				if not running() or not Hub.auraTargetInRange(target, myChar, targetChar) then break end
				if Hub.canAffect(hum) then
					hum.BreakJointsOnDeath = false
					hum:ChangeState(Enum.HumanoidStateType.Dead)
					hum.Jump = true
					hum.Sit = true
				end
			end
			task.wait()
			if running() and Hub.auraTargetInRange(target, myChar, targetChar) then Hub.fire(destroyGrabLineEvent, root) end
		end)
	end})

	group:AddToggle("FlingAura", {Text = "Fling Aura", Default = false, Callback = function(on)
		runAura("FlingAura", on, function(target, myChar, targetChar, running)
			local root = targetChar:FindFirstChild("HumanoidRootPart")
			local direction = lookAt(myChar.HumanoidRootPart.Position, Hub.teleportFrame(root).Position).LookVector
			local velocity = Hub.new("BodyVelocity", root)
			velocity.Name = "ArrivaAuraVelocity"
			velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			velocity.Velocity = Vector3.new(direction.X, 0.5, direction.Z) * Hub.auraSettings.flingStrength
			Debris:AddItem(velocity, 0.2)
			task.wait()
			velocity:Destroy()
			Hub.instances[velocity] = nil
			Hub.assetTargets[velocity] = nil
			if running() and Hub.auraTargetInRange(target, myChar, targetChar) then Hub.fire(destroyGrabLineEvent, root) end
		end)
	end})

	group:AddButton({Text = "Stop player auras", Func = function()
		for _, id in ipairs({"Deathaura", "FlingAura"}) do if Toggles[id] then Toggles[id]:SetValue(false) end end
		if Hub.stopPlayerPhysicsAuras then Hub.stopPlayerPhysicsAuras() end
	end})
	group:AddSlider("PlayerAuraFlingStrength",{Text="Fling aura strength",Default=100,Min=25,Max=1000,Rounding=0,Callback=function(value) Hub.auraSettings.flingStrength=value end})
	group:AddSlider("PlayerAuraRange", {Text = "Player aura range (studs)", Default = 50, Min = 5, Max = 50, Rounding = 0,
		Callback = function(value) Hub.auraSettings.range = value end})
	group:AddToggle("PlayerAuraSelectedOnly", {Text = "Only selected Loop Players", Default = false,
		Callback = function(on) Hub.auraSettings.selectedOnly = on end})

	local feedback = Tabs.Aura:AddRightGroupbox("Range & Alerts")
	local status = feedback:AddLabel("Range preview and proximity alerts are off.")
	local preview, alerts = false, false
	local connection, marker
	local ringObjects = {}
	local inside, cooldowns = {}, {}
	local elapsed = 0

	local function clearRing()
		for _, object in ipairs(ringObjects) do
			Hub.instances[object] = nil
			Hub.assetTargets[object] = nil
			object:Destroy()
		end
		table.clear(ringObjects)
		marker = nil
	end

	local function makeRing()
		if marker then return end
		marker = Hub.new("Part")
		marker.Name = "ArrivaAuraRangePreview"
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.Transparency = 1
		marker.Size = Vector3.new(0.1, 0.1, 0.1)
		table.insert(ringObjects, marker)
		local points = {}
		for i = 1, 32 do
			local point = Hub.new("Attachment", marker)
			table.insert(points, point)
			table.insert(ringObjects, point)
		end
		for i = 1, 32 do
			local beam = Hub.new("Beam", marker)
			beam.Attachment0 = points[i]
			beam.Attachment1 = points[i % 32 + 1]
			beam.Width0 = 0.12
			beam.Width1 = 0.12
			beam.FaceCamera = true
			beam.Color = ColorSequence.new(Color3.fromRGB(105, 185, 255))
			beam.Transparency = NumberSequence.new(0.2)
			table.insert(ringObjects, beam)
		end
		marker.Parent = Workspace
	end

	local function update()
		local char = Player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then
			clearRing()
			inside = {}
			status:SetText("Waiting for your character.")
			return
		end
		if preview then
			makeRing()
			marker.CFrame = CFrame.new(Hub.teleportFrame(root).Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0))
			for i = 1, 32 do
				local angle = (i - 1) * math.pi * 2 / 32
				ringObjects[i + 1].Position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Hub.auraSettings.range
			end
		else clearRing() end
		local targets = Hub.getAuraTargets(char)
		status:SetText(string.format("%d eligible players within %d studs%s.", #targets, Hub.auraSettings.range,
			Hub.auraSettings.selectedOnly and " (selected only)" or ""))
		if alerts then
			local entering
			entering, inside = Hub.collectAuraEntries(targets, inside, cooldowns, os.clock())
			if #entering > 0 then
				local names = {}
				for i = 1, math.min(#entering, 3) do table.insert(names, entering[i].Name) end
				local suffix = #entering > 3 and string.format(" +%d more", #entering - 3) or ""
				Library:Notify({Title = "Players entered aura range", Description = table.concat(names, ", ") .. suffix, Time = 4})
			end
		end
	end

	local function refreshFeedback()
		if connection then connection:Disconnect(); Hub.connections[connection] = nil; connection = nil end
		elapsed = 0
		if not preview then clearRing() end
		if not preview and not alerts then
			inside = {}
			status:SetText("Range preview and proximity alerts are off.")
			return
		end
		update()
		connection = Hub.connect(RunService.Heartbeat, function(dt)
			elapsed += dt
			if elapsed >= 0.1 then elapsed = 0; update() end
		end)
	end

	feedback:AddToggle("PlayerAuraRangePreview", {Text = "Show player aura range", Default = false,
		Callback = function(on) preview = on; refreshFeedback() end})
	feedback:AddToggle("PlayerAuraProximityAlerts", {Text = "Proximity alerts", Default = false,
		Callback = function(on) alerts = on; inside = {}; refreshFeedback() end})
	feedback:AddSlider("PlayerAuraAlertCooldown", {Text = "Re-entry alert cooldown (seconds)", Default = 10, Min = 5, Max = 60, Rounding = 0,
		Callback = function(value) Hub.auraSettings.alertCooldown = value end})
	Hub.connect(Players.PlayerRemoving, function(player) inside[player.UserId] = nil; cooldowns[player.UserId] = nil end)
	Hub.connect(Player.CharacterRemoving, function() clearRing(); inside = {} end)
	Hub.cleanup(function()
		preview, alerts = false, false
		if connection then connection:Disconnect(); Hub.connections[connection] = nil; connection = nil end
		clearRing()
	end)
end

-- Shared aura ownership gate. Never move an unconfirmed assembly locally.
do
	local requests=setmetatable({}, {__mode="k"})
	local window,budget=0,0
	function Hub.auraOwned(part)
		if not part or not part.Parent then return false end
		local root=part.AssemblyRootPart or part
		if root.Anchored then return false end
		local ok,owned=pcall(function()
			if type(isnetworkowner)=="function" then return isnetworkowner(root) end
			-- Same simulation-ownership signal used by the original controllers.
			return root.ReceiveAge==0
		end)
		return ok and owned==true
	end
	function Hub.acquireAuraPart(part,root)
		if not part or not part.Parent or part.Anchored or not Hub.canAffect(part) then return false end
		if Hub.auraOwned(part) then return true end
		local now=os.clock()
		if now-window>=1 then window,budget=now,0 end
		if root and root.Parent==Player.Character and (part.Position-Hub.teleportFrame(root).Position).Magnitude<=30
			and now>=(requests[part] or 0) and budget<6 and setNetworkOwnerEvent then
			requests[part]=now+2;budget+=1
			local origin=Hub.teleportFrame(root).Position+Vector3.new(0,1.593,0)
			if (origin-part.Position).Magnitude>0.01 then
				Hub.fire(setNetworkOwnerEvent,part,CFrame.lookAt(origin,part.Position))
			end
		end
		return false
	end
end

-- Player attraction and tornado forces.
do
	(function()
		local group=Tabs.Aura:AddLeftGroupbox("Attraction & Tornado")
		local flags={};local entries={};local owners={}
		local pullSpeed,tornadoSpeed=100,5
		local elapsed=0
		local function remove(part)
			local entry=entries[part];if not entry then return end
			entries[part]=nil;owners[part]=nil
			Hub.instances[entry.force],Hub.assetTargets[entry.force]=nil,nil
			entry.force:Destroy()
		end
		local function clear() for part in pairs(entries) do remove(part) end;table.clear(owners) end
		function Hub.samplePlayerPhysicsAuras()
			if not flags.tornado and not flags.attraction then clear();return end
			local char=Player.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health<=0 then clear();return end
			local targets={};local valid={}
			for _,target in ipairs(Players:GetPlayers()) do
				if Hub.auraTargetInRange(target,char,target.Character) then
					table.insert(targets,target);valid[target.Character:FindFirstChild("HumanoidRootPart")]=true
				end
			end
			for part in pairs(entries) do if not valid[part] then remove(part) end end
			local now=os.clock()
			for _,target in ipairs(targets) do
				local part=target.Character:FindFirstChild("HumanoidRootPart")
				if Hub.acquireAuraPart(part,root) then
					local entry=entries[part]
					if entry and not entry.force.Parent then remove(part);entry=nil end
					if not entry then
						local force=Hub.new("BodyVelocity",part);force.Name="ArrivaPlayerAura"
						force.MaxForce=Vector3.new(1e7,1e7,1e7)
						entry={force=force};entries[part]=entry;Hub.assetTargets[force]=part
					end
					local delta
					if flags.tornado then
						local angle=now*tornadoSpeed+(target.UserId%32)*math.pi/16
						delta=(Hub.teleportFrame(root).Position+Vector3.new(math.cos(angle)*15,10,math.sin(angle)*15)-part.Position)*4
						if delta.Magnitude>100 then delta=delta.Unit*100 end
					else
						delta=Hub.teleportFrame(root).Position-part.Position
						delta=delta.Magnitude>0.01 and delta.Unit*math.min(pullSpeed,delta.Magnitude*4) or Vector3.zero
					end
					entry.force.Velocity=delta
				elseif entries[part] then remove(part) end
			end
		end
		local function toggle(id,label,key)
			group:AddToggle(id,{Text=label,Default=false,Callback=function(on) flags[key]=on;clear() end})
		end
		toggle("PlayerAttractionAura","Attraction Aura","attraction")
		toggle("PlayerTornadoAura","Tornado Aura","tornado")
		group:AddSlider("PlayerAttractionStrength",{Text="Attraction speed",Default=100,Min=10,Max=500,Rounding=0,Callback=function(value) pullSpeed=value end})
		group:AddSlider("PlayerTornadoSpeed",{Text="Tornado speed",Default=5,Min=1,Max=10,Rounding=1,Callback=function(value) tornadoSpeed=value end})
		Hub.stopPlayerPhysicsAuras=function()
			flags={};clear()
			for _,id in ipairs({"PlayerAttractionAura","PlayerTornadoAura"}) do
				if Toggles[id] and Toggles[id].Value then Toggles[id]:SetValue(false) end
			end
		end
		local heartbeat=Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed>=0.2 then elapsed=0;Hub.samplePlayerPhysicsAuras() end end)
		Hub.connect(Player.CharacterRemoving,clear)
		Hub.cleanup(function()
			heartbeat:Disconnect();Hub.connections[heartbeat]=nil;flags={};clear()
			Hub.samplePlayerPhysicsAuras,Hub.stopPlayerPhysicsAuras=nil,nil
		end)
	end)()
end
-- End player physics auras

-- Grab Tab
local GrabGroup = Tabs.Grab:AddLeftGroupbox("Throw & Distance")
local GrabOptions = Tabs.Grab:AddLeftGroupbox("Grab Modes")

_G.strength = 750
local strengthConnection

GrabGroup:AddSlider("ThrowPowerSlider", {
	Text = "Power",
	Default = 750,
	Min = 1,
	Max = 20000,
	Rounding = 0,
	Callback = function(value)
		_G.strength = value
	end
})

GrabGroup:AddToggle("ThrowStrengthToggle", {
	Text = "Strength",
	Default = false,
	Callback = function(enabled)
		if enabled then
			strengthConnection = Hub.connect(workspace.ChildAdded, function(model)
				if model.Name == "GrabParts" then
					local grab = model:WaitForChild("GrabPart", 2)
					local weld = grab and grab:WaitForChild("WeldConstraint", 2)
					if not weld or not model.Parent then return end
					local partToImpulse = weld.Part1
					if partToImpulse and Hub.canAffect(partToImpulse) then
						local velocityObj = Hub.new("BodyVelocity", partToImpulse)
						velocityObj.MaxForce = Vector3.zero
						Hub.connect(model:GetPropertyChangedSignal("Parent"), function()
							if not model.Parent then
								if Hub.canAffect(partToImpulse) and UserInputService:GetLastInputType() == Enum.UserInputType.MouseButton2 then
									velocityObj.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
									velocityObj.Velocity = workspace.CurrentCamera.CFrame.LookVector * _G.strength
									game:GetService("Debris"):AddItem(velocityObj, 1)
								else
									velocityObj:Destroy()
								end
							end
						end)
					end
				end
			end)
		elseif strengthConnection then
			strengthConnection:Disconnect()
		end
	end
})

-- Noclip Grab
local noclipGrabEnabled = false
local noclipConnection

local function startNoclipGrab()
	if noclipConnection then return end

	noclipConnection = Hub.connect(workspace.ChildAdded, function(v)
		if not noclipGrabEnabled then return end
		if not (v:IsA("Model") and v.Name == "GrabParts") then return end

		task.spawn(function()
			task.wait(0.05)

			local grabPart = v:FindFirstChild("GrabPart")
			local weld = grabPart and grabPart:FindFirstChild("WeldConstraint")
			local targetChar = weld and weld.Part1 and weld.Part1.Parent

			if not (grabPart and targetChar and targetChar:IsA("Model")) or not Hub.canAffect(targetChar) then
				return
			end

			local parts = {}
			local originalCollision = {}

			for _, d in ipairs(targetChar:GetDescendants()) do
				if d:IsA("BasePart") and not d.Anchored then
					table.insert(parts, d)
					originalCollision[d] = d.CanCollide
					Hub.backup(d, {"CanCollide"})
				end
			end

			while noclipGrabEnabled and Hub.canAffect(targetChar) and grabPart.Parent do
				for _, part in ipairs(parts) do
					if part and part.Parent and not part.Anchored then
						if Hub.canAffect(part) then part.CanCollide = false end
					end
				end
				task.wait(0.2)
			end

			for part, state in pairs(originalCollision) do
				if part and part.Parent then
					if Hub.canAffect(part) then part.CanCollide = state end
					Hub.propertyBackup[part] = nil
				end
			end
		end)
	end)
end

local function stopNoclipGrab()
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
end

GrabOptions:AddToggle("NoclipGrabToggle", {
	Text = "Noclip Grab",
	Default = false,
	Callback = function(on)
		Hub.requestSave()
		noclipGrabEnabled = on
		if on then
			startNoclipGrab()
		else
			stopNoclipGrab()
		end
	end
})

-- Additional grab modes.
do
	(function()
		local group=GrabOptions
		local flags={};local current,character,origin,spin
		local perspectiveSpeed=50
		local function restore()
			if spin then Hub.instances[spin],Hub.assetTargets[spin]=nil,nil;spin:Destroy();spin=nil end
			if origin and Player.Character==character and not Hub.blobFlightActive and not Hub.safeZoneLoopActive then
				local root=character and character:FindFirstChild("HumanoidRootPart")
				if root then Hub.teleportPart(root, origin) end
			end
			origin,character,current=nil,nil,nil
		end
		local function held()
			local model=Workspace:FindFirstChild("GrabParts")
			local grab=model and model:FindFirstChild("GrabPart",true)
			local weld=grab and grab:FindFirstChildWhichIsA("WeldConstraint")
			local part=weld and weld.Part1
			if not part or not part:IsA("BasePart") or not part.Parent or not Hub.canAffect(part)
				or (Player.Character and part:IsDescendantOf(Player.Character)) then return end
			return part,model
		end
		function Hub.sampleToolGrabTypes(dt)
			local any=false;for _,on in pairs(flags) do if on then any=true end end
			if not any then if current then restore() end;return end
			local part,model=held()
			if part~=current or Player.Character~=character then restore();current=part;character=Player.Character end
			if not part or not character then return end
			if flags.crazy and not part.Anchored then
				if not spin or not spin.Parent then
					spin=Hub.new("BodyAngularVelocity",part);spin.Name="ArrivaCrazyGrab";spin.MaxTorque=Vector3.new(1e8,1e8,1e8)
				end
				spin.AngularVelocity=Vector3.new(0,1000,0)
			elseif spin then spin:Destroy();Hub.instances[spin],Hub.assetTargets[spin]=nil,nil;spin=nil end
			if flags.perspective and not Hub.blobFlightActive and not Hub.safeZoneLoopActive then
				if UserInputService:GetFocusedTextBox() or Hub.keybindCaptureActive then return end
				local root=character:FindFirstChild("HumanoidRootPart")
				local hum=character:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health>0 and not hum.SeatPart and not root.Anchored then
					origin=origin or Hub.teleportFrame(root)
					local seconds=type(dt)=="number" and math.clamp(dt,0,0.1) or 0
					local position=Hub.teleportFrame(root).Position+hum.MoveDirection*perspectiveSpeed*seconds
					local facing=Hub.safeLookAt(position,part.Position,Hub.teleportFrame(root).LookVector)
					if facing then Hub.teleportPart(root, facing) end
				end
			end
		end
		local function toggle(id,label,key)
			group:AddToggle(id,{Text=label,Default=false,Callback=function(on)
				restore();flags[key]=on
				if key=="crazy" and on and Toggles.ToolSpinGrab then Toggles.ToolSpinGrab:SetValue(false) end
			end})
		end


		toggle("ToolCrazyGrab","Crazy Grab","crazy")

		toggle("ToolPerspectiveGrab","Perspective Grab","perspective")

		group:AddButton({Text="Release held object",Func=function()
			local part=held()
			if part and destroyGrabLineEvent then Hub.fire(destroyGrabLineEvent,part) end
		end})
		group:AddSlider("ToolPerspectiveSpeed",{Text="Perspective movement speed",Default=50,Min=5,Max=150,Rounding=0,Callback=function(value) perspectiveSpeed=value end})
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt)
			elapsed+=dt;if elapsed>=0.1 then local seconds=elapsed;elapsed=0;Hub.sampleToolGrabTypes(seconds) end
		end)
		Hub.connect(Player.CharacterRemoving,restore)
		Hub.cleanup(function()
			for key in pairs(flags) do flags[key]=false end
			restore();Hub.sampleToolGrabTypes=nil
		end)
	end)()
end
-- End  additional grab types

-- grab ports: invisible and spinning held objects, with release restoration.
do
	(function()
		local invisible,spin=false,false
		local speed=12
		local current,rotator
		local saved={}
		local function restore()
			if rotator then Hub.instances[rotator],Hub.assetTargets[rotator]=nil,nil;rotator:Destroy();rotator=nil end
			for part,value in pairs(saved) do pcall(function() if part.Parent then part.LocalTransparencyModifier=value end end) end
			table.clear(saved);current=nil
		end
		local function canModify(part)
			if not part or not part:IsA("BasePart") or not Hub.canAffect(part) then return false end
			local owner=Hub.playerOf(part)
			return not (owner and owner.Character and part:IsDescendantOf(owner.Character))
		end
		local function heldPart()
			local model=Workspace:FindFirstChild("GrabParts")
			local grab=model and model:FindFirstChild("GrabPart",true)
			local weld=grab and grab:FindFirstChildWhichIsA("WeldConstraint")
			if not weld then return end
			for _,part in pairs({weld.Part1,weld.Part0}) do
				if part and canModify(part) and not part:IsDescendantOf(model) then return part end
			end
		end
		function Hub.sampleToolGrab()
			if not invisible and not spin then if current then restore() end;return end
			local part=heldPart()
			if part~=current then restore();current=part end
			if not part or not part.Parent then return end
			local parts=part:GetConnectedParts(true);table.insert(parts,part)
			for _,member in ipairs(parts) do if not canModify(member) then restore();return end end
			if invisible then
				local present={}
				for _,member in ipairs(parts) do present[member]=true end
				for member,value in pairs(saved) do
					if not present[member] then
						pcall(function() if member.Parent then member.LocalTransparencyModifier=value end end)
						saved[member]=nil
					end
				end
				for _,member in ipairs(parts) do
					if canModify(member) then
						if saved[member]==nil then saved[member]=member.LocalTransparencyModifier end
						member.LocalTransparencyModifier=1
					end
				end
			elseif next(saved) then
				for member,value in pairs(saved) do pcall(function() if member.Parent then member.LocalTransparencyModifier=value end end) end
				table.clear(saved)
			end
			if rotator and not rotator.Parent then
				Hub.instances[rotator],Hub.assetTargets[rotator]=nil,nil;rotator=nil
			end
			if spin and not part.Anchored then
				if not rotator then
					rotator=Hub.new("BodyAngularVelocity",part);rotator.Name="ArrivaToolSpin"
					rotator.MaxTorque=Vector3.new(1e7,1e7,1e7)
				end
				rotator.AngularVelocity=Vector3.new(0,speed,0)
			elseif rotator then rotator:Destroy();Hub.instances[rotator],Hub.assetTargets[rotator]=nil,nil;rotator=nil end
		end
		GrabOptions:AddToggle("ToolInvisibleGrab",{Text="Invisible Grab (local)",Default=false,Callback=function(on) invisible=on;Hub.sampleToolGrab() end})
		GrabOptions:AddToggle("ToolSpinGrab",{Text="Spin Grab",Default=false,Callback=function(on) if on and Toggles.ToolCrazyGrab then Toggles.ToolCrazyGrab:SetValue(false) end;spin=on;Hub.sampleToolGrab() end})
		GrabOptions:AddSlider("ToolSpinGrabSpeed",{Text="Grab spin (radians/sec)",Default=12,Min=1,Max=60,Rounding=0,Callback=function(value) speed=value end})
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed>=0.1 then elapsed=0;Hub.sampleToolGrab() end end)
		Hub.connect(Player.CharacterRemoving,restore)
		Hub.cleanup(function() invisible,spin=false,false;restore();Hub.sampleToolGrab=nil end)
	end)()
end
-- End  grab ports

-- line presentation: local colors and invisibility without destroying grab beams.
do
	(function()
		local group=Tabs.Grab:AddRightGroupbox("Line Appearance")
		local hidden,rainbow,colored=false,false,false
		local tint=Color3.fromRGB(255,0,0)
		local saved={}
		local function restore(beam)
			local record=saved[beam];if not record then return end;saved[beam]=nil
			pcall(function() if beam.Parent then beam.Color=record.color;beam.Transparency=record.transparency end end)
		end
		local function refresh()
			local model=Workspace:FindFirstChild("GrabParts")
			for beam in pairs(saved) do
				if not model or not beam:IsDescendantOf(model) or (not hidden and not rainbow and not colored) then restore(beam) end
			end
			if not model or (not hidden and not rainbow and not colored) then return end
			for _,beam in ipairs(model:GetDescendants()) do
				if beam:IsA("Beam") then
					if not saved[beam] then saved[beam]={color=beam.Color,transparency=beam.Transparency} end
					beam.Transparency=hidden and NumberSequence.new(1) or saved[beam].transparency
					if rainbow then beam.Color=ColorSequence.new(Color3.fromHSV((os.clock()*0.15)%1,1,1))
					elseif colored then beam.Color=ColorSequence.new(tint)
					else beam.Color=saved[beam].color end
				end
			end
		end
		group:AddToggle("ToolInvisibleLine",{Text="Invisible line (local)",Default=false,Callback=function(on) hidden=on;refresh() end})
		group:AddToggle("ToolLineTint",{Text="Custom line color (local)",Default=false,Callback=function(on) if on and Toggles.PackGradientLine then Toggles.PackGradientLine:SetValue(false) end;colored=on;refresh() end})
		group:AddToggle("ToolRainbowLine",{Text="RGB line (local)",Default=false,Callback=function(on) if on and Toggles.PackGradientLine then Toggles.PackGradientLine:SetValue(false) end;rainbow=on;refresh() end})
		group:AddInput("ToolLineColor",{Text="Line color hex",Default="FF0000",Finished=true,Callback=function(value)
			local hex=tostring(value):gsub("#","")
			if #hex==6 and hex:match("^%x+$") then
				tint=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16));refresh()
			end
		end})
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt)
			if hidden or rainbow or colored or next(saved) then elapsed+=dt;if elapsed>=0.1 then elapsed=0;refresh() end end
		end)
		Hub.cleanup(function() hidden,rainbow,colored=false,false,false;for beam in pairs(saved) do restore(beam) end end)
	end)()
end
-- End  line presentation

-- Massless Grab: preserve the grabbed orientation relative to the character.
do
	local enabled=false
	local listeners={}
	local tracked={}
	local function restore(entry)
		for object,properties in pairs(entry.saved) do
			for property,value in pairs(properties) do pcall(function() object[property]=value end) end
		end
		table.clear(entry.saved)
	end
	local function set(entry,object,values)
		local saved=entry.saved[object]
		if not saved then saved={};entry.saved[object]=saved end
		for property,value in pairs(values) do
			if saved[property]==nil then saved[property]=object[property] end
			object[property]=value
		end
	end
	local function canStabilizePart(part)
		if not part or not part:IsA("BasePart") or not Hub.canAffect(part) then return false end
		local character=Player.Character
		if character and part:IsDescendantOf(character) then return false end
		return true
	end
	local function target(model)
		local grab=model:FindFirstChild("GrabPart",true)
		local weld=grab and grab:FindFirstChildWhichIsA("WeldConstraint")
		if weld then
			for _,part in pairs({weld.Part1,weld.Part0}) do
				if part and not part:IsDescendantOf(model) and canStabilizePart(part) then return part end
			end
		end
	end
	local function configure(model,entry)
		local part=target(model)
		local drag=model:FindFirstChild("DragPart1",true) or model:FindFirstChild("DragPart",true)
		local orientation=drag and drag:FindFirstChildWhichIsA("AlignOrientation")
		local position=drag and drag:FindFirstChildWhichIsA("AlignPosition")
		if not part or not orientation or not position then return false end
		if entry.part~=part or entry.orientation~=orientation or entry.position~=position then
			restore(entry)
			entry.part,entry.orientation,entry.position=part,orientation,position
			local character=Player.Character
			local root=character and character:FindFirstChild("HumanoidRootPart")
			entry.tool=root
			entry.rotationOffset=root and Hub.teleportFrame(root).Rotation:ToObjectSpace(part.CFrame.Rotation) or nil
		end
		-- The orientation target is handled below, independently of positional movement.
		set(entry,orientation,{Enabled=false})
		set(entry,position,{MaxForce=1e9,Responsiveness=200})
		return true
	end
	local function track(model)
		if enabled and model:IsA("Model") and model.Name=="GrabParts" and not tracked[model] then
			tracked[model]={saved={},elapsed=0}
			configure(model,tracked[model])
		end
	end
	local function stop()
		enabled=false
		for _,connection in ipairs(listeners) do connection:Disconnect();Hub.connections[connection]=nil end
		table.clear(listeners)
		for _,entry in pairs(tracked) do restore(entry) end
		table.clear(tracked)
	end
	local function start()
		stop();enabled=true
		table.insert(listeners,Hub.connect(workspace.ChildAdded,track))
		for _,model in ipairs(workspace:GetChildren()) do track(model) end
		table.insert(listeners,Hub.connect(RunService.Heartbeat,function(dt)
			for model,entry in pairs(tracked) do
				if not model.Parent or not Hub.canAffect(model) then
					restore(entry);tracked[model]=nil
				else
					entry.elapsed+=dt
					if entry.elapsed>=0.1 then
						entry.elapsed=0
						if not configure(model,entry) then
							restore(entry);entry.part=nil;entry.orientation=nil;entry.position=nil
						end
					end
					local part=entry.part
					if part and part.Parent and not part.Anchored and canStabilizePart(part) then
						local root=entry.tool
						local character=Player.Character
						if root and root.Parent==character and entry.rotationOffset then
							-- Preserve the grabbed face relative to the player, not to the world.
							local rotation=Hub.teleportFrame(root).Rotation*entry.rotationOffset
							Hub.teleportPart(part, CFrame.new(part.Position)*rotation)
						end
						part.AssemblyAngularVelocity=Vector3.zero
					end
				end
			end
		end))
	end
	GrabOptions:AddToggle("MasslessGrabToggle",{Text="Massless Grab",Default=false,
		Callback=function(on) if on then start() else stop() end;Hub.requestSave() end})
	Hub.cleanup(stop)
end

function IsMobile()
	if LocalPlayer.PlayerGui:FindFirstChild("ContextActionGui") then
		return true
	end
end

function GetPlayerCharacter()
	if LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")) then
		return LocalPlayer.Character
	end
end

do
	local IncreaseLineExtend = 5
	local LastSet = 5
	local pcDistance = 11
	local extendEnabled = false
	local extendconnection
	local extendGeneration = 0
	local extendActive = {}
	local function restoreExtend(model)
		local state = extendActive[model]
		if not state then return end
		pcall(function() state.original.Enabled = state.enabled end)
		pcall(function() state.clone:Destroy() end)
		extendActive[model] = nil
	end
	Hub.cleanup(function() for model in pairs(extendActive) do restoreExtend(model) end end)
	Hub.connect(UserInputService.InputChanged, function(input)
		if not extendEnabled or UserInputService:GetFocusedTextBox() then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			pcDistance = math.clamp(pcDistance + input.Position.Z * IncreaseLineExtend, 11, 1000)
		end
	end)
	local function extendGrab(model)
		if not extendEnabled or model.Name ~= "GrabParts" or not model:IsA("Model") then return end
		task.spawn(function()
			local generation = extendGeneration
			local drag = model:WaitForChild("DragPart", 2)
			local align = drag and drag:FindFirstChildOfClass("AlignPosition")
			if not Hub.canAffect(model) or not drag or not align or not extendEnabled or generation ~= extendGeneration or not model.Parent then return end
			local clone = drag:Clone()
			local cloneAlign = clone:FindFirstChildOfClass("AlignPosition")
			local attachment = clone:FindFirstChild("DragAttach")
			if not cloneAlign or not attachment then clone:Destroy(); return end
			clone.Name = "DragPart1"
			cloneAlign.Attachment1 = attachment
			cloneAlign.Enabled = true
			local orientation = clone:FindFirstChildOfClass("AlignOrientation")
			if orientation then orientation.Enabled = false end
			extendActive[model] = {original = align, enabled = align.Enabled, clone = clone}
			align.Enabled = false
			clone.Parent = model
			local cam = workspace.CurrentCamera
			if cam then pcDistance = math.clamp((clone.Position - cam.CFrame.Position).Magnitude, 11, 1000) end
			while extendEnabled and Hub.canAffect(model) and generation == extendGeneration and model.Parent and clone.Parent do
				cam = workspace.CurrentCamera
				if cam then clone.Position = cam.CFrame.Position + cam.CFrame.LookVector * pcDistance end
				RunService.Heartbeat:Wait()
			end
			restoreExtend(model)
		end)
	end
	GrabGroup:AddToggle("ExtendToggle", {Text = "Further Extend", Default = false,
		Callback = function(on)
			extendEnabled = on
			extendGeneration += 1
			if extendconnection then extendconnection:Disconnect(); extendconnection = nil end
			for model in pairs(extendActive) do restoreExtend(model) end
			if on then
				IncreaseLineExtend = LastSet
				extendconnection = Hub.connect(workspace.ChildAdded, extendGrab)
				local existing = workspace:FindFirstChild("GrabParts")
				if existing then extendGrab(existing) end
			end
			Hub.requestSave()
		end})
	GrabGroup:AddSlider("extendvalue", {Text = "Extend Amount", Default = 5, Min = 1, Max = 100, Rounding = 0,
		Callback = function(value) LastSet = value; IncreaseLineExtend = value; Hub.requestSave() end})

end

-- Kill Grab: Blitz Death_Grab ownership gate/state/release, with cancellable hub workers.
local killGrabEnabled=false
local grabConnection
local killGrabWorkers={}
local killGrabEpoch=0
local function stopKillGrabWorkers()
	killGrabEpoch+=1
	for model,record in pairs(killGrabWorkers) do
		killGrabWorkers[model]=nil
		if record.thread and record.thread~=coroutine.running() and coroutine.status(record.thread)~="dead" then pcall(Hub.nativeTask.cancel,record.thread);Hub.threads[record.thread]=nil end
	end
end
local function processKillGrab(model)
	if not killGrabEnabled or not model:IsA("Model") or model.Name~="GrabParts" or model:GetAttribute("Fake") or killGrabWorkers[model] then return end
	local record={epoch=killGrabEpoch,char=Player.Character};killGrabWorkers[model]=record
	record.thread=task.defer(function()
		local function live()
			local ownHum=record.char and record.char:FindFirstChildOfClass("Humanoid")
			return ownHum and ownHum.Health>0 and Hub.alive and killGrabEnabled and record.epoch==killGrabEpoch and killGrabWorkers[model]==record
				and model.Parent==Workspace and Player.Character==record.char
		end
		local ok,message=xpcall(function()
			local grab=model:WaitForChild("GrabPart",0.5)
			local weld=grab and grab:WaitForChild("WeldConstraint",0.5)
			if not live() or not weld or not weld.Part1 then return end
			local grabbed=weld.Part1
			local targetChar=grabbed.Parent
			while targetChar and targetChar~=Workspace and not targetChar:FindFirstChildOfClass("Humanoid") do targetChar=targetChar.Parent end
			local target=targetChar and Players:GetPlayerFromCharacter(targetChar)
			local hum=targetChar and targetChar:FindFirstChildOfClass("Humanoid")
			if not target or target==Player or not hum or not Hub.canAffect(targetChar) then return end
			while live() and target.Character==targetChar and grab.Parent==model and weld.Parent==grab
				and weld.Part1==grabbed and grabbed:IsDescendantOf(targetChar) and hum.Parent==targetChar and hum.Health>0 and Hub.canAffect(targetChar) do
				if CheckNetworkOwnerShipOnPlayer(target) then
					hum.BreakJointsOnDeath=false
					hum:ChangeState(Enum.HumanoidStateType.Dead)
					hum.Jump=true;hum.Sit=false
					if hum:GetStateEnabled(Enum.HumanoidStateType.Dead) then
						local events=ReplicatedStorage:FindFirstChild("GrabEvents")
						local drop=events and events:FindFirstChild("DestroyGrabLine")
						if drop then Hub.fire(drop,grabbed) end
					end
				end
				RunService.Heartbeat:Wait()
			end
		end,debug.traceback)
		if killGrabWorkers[model]==record then killGrabWorkers[model]=nil end
		if not ok then warn("[Kill Grab] "..tostring(message)) end
	end)
end
local function startKillGrab()
	if not grabConnection then grabConnection=Hub.connect(Workspace.ChildAdded,processKillGrab) end
	for _,model in ipairs(Workspace:GetChildren()) do if model.Name=="GrabParts" then processKillGrab(model) end end
end
local function stopKillGrab()
	stopKillGrabWorkers()
	if grabConnection then grabConnection:Disconnect();Hub.connections[grabConnection]=nil;grabConnection=nil end
end
GrabOptions:AddToggle("KillGrabToggle",{Text="Kill Grab",Default=false,Callback=function(on)
	Hub.requestSave();killGrabEnabled=on
	if on then startKillGrab() else stopKillGrab() end
end})
Hub.connect(Player.CharacterRemoving,stopKillGrabWorkers)
Hub.cleanup(function() killGrabEnabled=false;stopKillGrab() end)
-- End Blitz Kill Grab

-- Misc Tab
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Miscellaneous")
Hub.playerListOriginal = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
Hub.cleanup(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, Hub.playerListOriginal) end)
local mouse = Player:GetMouse()
local tpToolConn

-- Bounded, cancellable toy actions. A toy counter is not a replication barrier.
do
	(function()
		local shortcuts=Hub.keybindGroups.missiles
		local menuGroup=Tabs.Explosions:AddRightGroupbox("Missile Throw Status")
		local aimGroup=Tabs.Explosions:AddRightGroupbox("Launch Settings")
		local status=menuGroup:AddLabel("Ready.")
		local enabled,generation=true,0
		local active=nil
		local flights={}
		local retryModels={}
		local loopOn,loopCount,nextLoop=false,0,0
		local toyName,action,aim="BombMissile","Throw","Camera"
		local interval,maxCycles,speed,lifetime=1,10,500,3
		local claims=Hub.missileLaunchClaims or {};Hub.missileLaunchClaims=claims
		local reserved={};Hub.missileReservedModels=reserved
		Hub.isMissileReserved=function(instance)
			local cursor=instance
			while cursor and cursor~=Workspace do if reserved[cursor] then return true end;cursor=cursor.Parent end
			return false
		end
		local function disconnect(c) if c then c:Disconnect();Hub.connections[c]=nil end end
		local function releaseFlight(op)
			if op.force then
				Hub.instances[op.force]=nil;Hub.assetTargets[op.force]=nil
				pcall(function() op.force:Destroy() end);op.force=nil
			end
			disconnect(op.partsConnection);op.partsConnection=nil
			for part in pairs(op.claimed) do if claims[part]==op then claims[part]=nil end end
			if op.toy and reserved[op.toy]==op then reserved[op.toy]=nil end
			flights[op]=nil
		end
		local function cancelWorker(worker)
			if worker and coroutine.status(worker)~="dead" and worker~=coroutine.running() then
				pcall(Hub.nativeTask.cancel,worker);Hub.threads[worker]=nil
			end
		end
		local function finish(op)
			disconnect(op.listener);op.listener=nil
			cancelWorker(op.spawnWorker);op.spawnWorker=nil
			if active==op then active=nil end
			nextLoop=os.clock()+interval
		end
		local function cancel(reason)
			generation+=1
			local op=active;active=nil
			if op then
				disconnect(op.listener)
				cancelWorker(op.worker)
				cancelWorker(op.spawnWorker)
				releaseFlight(op)
				if op.mode=="Cache" and op.toy then Hub.missileKeptModels=Hub.missileKeptModels or {};Hub.missileKeptModels[op.toy]=true end
			end
			local list={};for flight in pairs(flights) do table.insert(list,flight) end
			for _,flight in ipairs(list) do releaseFlight(flight) end
			status:SetText(reason or "Missile actions stopped.")
		end
		local function stop(reason)
			loopOn=false
			local toggle=Toggles.MissileLoopEnabled
			if toggle and toggle.Value then toggle:SetValue(false) end
			cancel(reason)
		end
		local function current(op)
			return Hub.alive and enabled and active==op and generation==op.ticket
				and Player.Character==op.character and op.humanoid.Health>0
		end
		local function fail(op,reason)
			if active~=op then return end
			Hub.lastMissileError=tostring(reason):sub(1,240)
			if op.mode=="Cache" and op.toy and op.toy.Parent==Workspace:FindFirstChild(Player.Name.."SpawnedInToys") then
				retryModels[op.name]=op.toy
				Hub.missileKeptModels=Hub.missileKeptModels or {};Hub.missileKeptModels[op.toy]=true
			end
			cancelWorker(op.worker)
			releaseFlight(op)
			finish(op)
			status:SetText("Missile action will retry: "..Hub.lastMissileError)
		end
		local function reserve(op,model)
			if op.toy==model then return end
			if op.toy then releaseFlight(op) end
			op.toy=model;reserved[model]=op
			local function mark(part)
				if part:IsA("BasePart") then
					local root=part.AssemblyRootPart or part
					if not claims[root] or claims[root]==op then claims[root]=op;op.claimed[root]=true end
				end
			end
			for _,part in ipairs(model:GetDescendants()) do mark(part) end
			op.partsConnection=Hub.connect(model.DescendantAdded,mark)
		end
		local function available(name)
			local node=Player:FindFirstChildOfClass("PlayerGui")
			for _,key in ipairs({"MenuGui","Menu","TabContents","Toys","Contents"}) do node=node and node:FindFirstChild(key) end
			if node and not node:FindFirstChild(name) then return false,"You do not own "..name.."." end
			local can=Player:FindFirstChild("CanSpawnToy")
			if can and can.Value==false then return false,"Toy spawning is unavailable right now." end
			local used,cap=Player:FindFirstChild("UsedToyPoints"),Player:FindFirstChild("ToysLimitCap")
			if used and cap and tonumber(used.Value) and tonumber(cap.Value) and used.Value+10>cap.Value then
				return false,"Not enough toy points. Free some space before restarting the loop."
			end
			return true
		end
		local definitions={
			BombMissile={hit="PartHitDetector",physics="Body"},FireworkMissile={hit="PartHitDetector",physics="Hitbox"},
			BombDarkMatter={hit="PartHitDetector",physics="Pyramid"},BombBalloon={hit="Balloon",physics="Balloon"},
			PresentBig={hit="Box",physics="Box"},PresentSmall={hit="Box",physics="Box"},DiceSmall={hit="SoundPart",physics="SoundPart"},
		}
		local function start(name,mode,onPrepared)
			if not Hub.alive or not enabled or Hub.keybindCaptureActive or UserInputService:GetFocusedTextBox() then return false end
			if active then status:SetText("Waiting for the current toy, no extra spawn queued.");return false end
			if not definitions[name] or (mode~="Cache" and name~="BombMissile" and name~="FireworkMissile") then return false end
			local char=Player.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			local camera=Workspace.CurrentCamera
			if not root or not hum or hum.Health<=0 or not camera then status:SetText("Wait for your character and camera.");return false end
			local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			local reuse=mode=="Cache" and retryModels[name] or nil
			if reuse and (reuse.Parent~=folder or reserved[reuse]) then retryModels[name]=nil;reuse=nil end
			if not reuse then
				local allowed,reason=available(name)
				if not allowed then Hub.lastMissileError=reason;status:SetText(reason);return false end
			end
			local toys=ReplicatedStorage:FindFirstChild("MenuToys")
			local spawn=toys and toys:FindFirstChild("SpawnToyRemoteFunction")
			local grabs=ReplicatedStorage:FindFirstChild("GrabEvents")
			local owner=grabs and grabs:FindFirstChild("SetNetworkOwner")
			local events=ReplicatedStorage:FindFirstChild("BombEvents")
			local explode=events and events:FindFirstChild("BombExplode")
			if not folder or not spawn or not owner or (mode=="Explode" and not explode) then Hub.lastMissileError="Toy remotes or your toy folder are not ready.";status:SetText(Hub.lastMissileError);return false end
			local direction=camera.CFrame.LookVector
			if aim=="Mouse" then
				local delta=mouse.Hit.Position-Hub.teleportFrame(root).Position
				if delta.Magnitude>0.001 then direction=delta.Unit end
			end
			local spawnPosition=Hub.teleportFrame(root).Position+direction*6+Vector3.new(0,1,0)
			local spawnFrame=Hub.safeLookAt(spawnPosition,spawnPosition+direction) or Hub.teleportFrame(root)
			local op={ticket=generation,character=char,humanoid=hum,claimed={},before={},deadline=os.clock()+(mode=="Cache" and 12 or 6),name=name,mode=mode,phase="Parts"}
			active=op
			for _,model in ipairs(folder:GetChildren()) do op.before[model]=true end
			if reuse then reserve(op,reuse);retryModels[name]=nil end
			local function capture(model)
				if not current(op) or op.before[model] or model.Parent~=folder or model.Name~=name or not model:IsA("Model") then return end
				if not op.toy then reserve(op,model) end
			end
			op.listener=Hub.connect(folder.ChildAdded,capture)
			status:SetText("Spawning "..name.."...")
			-- Replication can arrive before InvokeServer returns. Prepare that model immediately.
			if not reuse then op.spawnWorker=task.spawn(function()
					local ok,result=pcall(function() return Hub.invoke(spawn,name,spawnFrame,Vector3.zero) end)
					if not current(op) then return end
					if not ok then
						Hub.lastMissileError=tostring(result):sub(1,240)
						if not op.toy then fail(op,"Missile spawn failed: "..Hub.lastMissileError) end
						return
					end
					if not op.toy and typeof(result)=="Instance" and result:IsA("Model") and result.Parent==folder
						and result.Name==name and not op.before[result] then reserve(op,result) end
				end) end
			op.worker=task.spawn(function()
				local ok,err=xpcall(function()
					local hit,body
					repeat
						if not current(op) then return end
						if not op.toy then for _,model in ipairs(folder:GetChildren()) do capture(model) end end
						if op.toy and op.toy.Parent~=folder then error("The spawned toy disappeared before launch.") end
						if op.toy then
							hit=op.toy:FindFirstChild(definitions[name].hit,true)
							body=op.toy:FindFirstChild(definitions[name].physics,true)
						end
						if hit and hit:IsA("BasePart") and not hit.Anchored and (body and body:IsA("BasePart") and not body.Anchored) then break end
						task.wait()
					until os.clock()>=op.deadline
					if not current(op) then return end
					if not hit or not hit:IsA("BasePart") or hit.Anchored or (not body or not body:IsA("BasePart") or body.Anchored) then error("Toy parts did not become ready within six seconds.") end
					disconnect(op.listener);op.listener=nil
					local facing=Hub.lookAt(hit.Position,hit.Position+direction) or hit.CFrame
					Hub.fire(owner,hit,facing)
					-- Claim the actual physics part before applying forces or requesting an explosion.
					local physics=body
					op.phase="Ownership"
					-- Ownership can arrive late: keep the same toy and retry instead of cancelling the cache.
					op.deadline=math.huge
					local attempts,nextRequest,nextNotice=0,0,0
					while current(op) do
						if not op.toy or op.toy.Parent~=folder or not physics.Parent or not hit.Parent then
							error("The spawned toy disappeared before ownership was confirmed.")
						end
						local check=CheckNetworkOwnerShipOnPart
						local checked,confirmed=false,false
						if type(check)=="function" then checked,confirmed=pcall(check,physics) end
						if checked and confirmed then break end
						local now=os.clock()
						if now>=nextRequest then
							attempts+=1
							nextRequest=now+math.min(2,0.5*2^math.min(attempts-1,2))
							if Player:DistanceFromCharacter(physics.Position)<=30 then
								Hub.fire(owner,physics,Hub.lookAt(Hub.teleportFrame(root).Position,physics.Position) or physics.CFrame)
							end
						end
						if now>=nextNotice then
							nextNotice=now+4
							local detail=Player:DistanceFromCharacter(physics.Position)>30 and "move within 30 studs" or "waiting for confirmation"
							status:SetText("Retrying "..name.." ownership, "..detail..". Cancel missile actions to stop.")
						end
						task.wait(0.1)
					end
					if not current(op) then return end
					Hub.lastMissileError=nil
					op.phase="Ready"
					if mode=="Cache" then
						local primary=op.toy.PrimaryPart or physics
						local force=Hub.new(name=="DiceSmall" and "BodyPosition" or "BodyVelocity",primary);op.force=force
						force.MaxForce=Vector3.new(math.huge,math.huge,math.huge)
						if name=="DiceSmall" then force.Position=Vector3.new(1000,400,10000);force.D=200;force.P=50000
						else force.Velocity=Vector3.zero;force.Name="Stable" end
						op.toy:PivotTo(CFrame.new(math.random(-1000,1000),10000,math.random(-1000,1000)))
						flights[op]=math.huge
						if onPrepared then onPrepared({model=op.toy,hit=hit,position=primary,force=force,release=function() releaseFlight(op) end}) end
					elseif mode=="Throw" then
						local assembly=physics.AssemblyRootPart or physics
						claims[assembly]=op;op.claimed[assembly]=true
						local force=Hub.new("BodyVelocity",physics);op.force=force
						force.MaxForce=Vector3.new(math.huge,math.huge,math.huge)
						force.Velocity=direction*speed
						physics.AssemblyAngularVelocity=Vector3.zero
						physics.AssemblyLinearVelocity=direction*speed
						flights[op]=os.clock()+lifetime
						status:SetText(string.format("Launched %s at %d studs/sec.",name,speed))
					else
						Hub.fire(explode,{Radius=17.5,TimeLength=2,Hitbox=hit,ExplodesByFire=false,
							MaxForcePerStudSquared=225,Model=op.toy,ImpactSpeed=100,ExplodesByPointy=false,
							DestroysModel=true,PositionPart=body},body.Position)
						flights[op]=os.clock()+2
						status:SetText("Requested "..name.." explosion.")
					end
					loopCount+=1;finish(op)
				end,debug.traceback)
				if not ok and current(op) then fail(op,err) end
			end)
			return true
		end
		Hub.throwMissile=function(value) if type(value)=="string" then return false end;return start("BombMissile","Throw") end
		Hub.explodeMissile=function(name) return start(name,"Explode") end
		Hub.prepareExplosive=function(name,callback) return start(name,"Cache",callback) end
		Hub.missileHasRetry=function(name)
			local model=retryModels[name]
			return model~=nil and model.Parent==Workspace:FindFirstChild(Player.Name.."SpawnedInToys") and not reserved[model]
		end
		Hub.missileWorkBusy=function() return active~=nil end
		Hub.cancelMissileWork=stop
		shortcuts:AddLabel("Explode Bomb"):AddKeyPicker("ExplodeBombKey",{Default="J",Text="Explode Bomb",Callback=function(value) if type(value)~="string" then Hub.explodeMissile("BombMissile") end end})
		shortcuts:AddLabel("Explode Firework"):AddKeyPicker("ExplodeFireworkKey",{Default="N",Text="Explode Firework",Callback=function(value) if type(value)~="string" then Hub.explodeMissile("FireworkMissile") end end})
		shortcuts:AddToggle("MissileThrowEnabled",{Text="Enable missile actions",Default=true,Callback=function(on)
			enabled=on
			if not on then
				if Hub.stopBlitzExplosions then Hub.stopBlitzExplosions("Missile actions disabled.") else stop("Missile actions disabled.") end
			end
		end})
		shortcuts:AddButton({Text="Throw Bomb",Func=Hub.throwMissile})
		shortcuts:AddButton({Text="Explode Bomb",Func=function() Hub.explodeMissile("BombMissile") end})
		shortcuts:AddButton({Text="Explode Firework",Func=function() Hub.explodeMissile("FireworkMissile") end})
		shortcuts:AddButton({Text="Cancel missile actions",Func=function()
			if Hub.stopBlitzExplosions then Hub.stopBlitzExplosions("Missile actions stopped.") else stop("Missile actions stopped.") end
		end})
		aimGroup:AddDropdown("MissileAimMode",{Text="Throw direction",Values={"Camera","Mouse"},Default=1,Callback=function(value) aim=value end})
		aimGroup:AddSlider("MissileLaunchSpeed",{Text="Launch speed",Default=500,Min=100,Max=500,Rounding=0,Callback=function(value) speed=value end})
		aimGroup:AddSlider("MissileForceLifetime",{Text="Launch force lifetime (seconds)",Default=3,Min=0.5,Max=10,Rounding=1,Callback=function(value) lifetime=value end})
		aimGroup:AddLabel("Uses your own newly spawned missile or firework. Throw starts after its physics part is ready and network ownership is confirmed. Ownership retries keep the same toy without pausing the cache. Other temporary failures retry with backoff. Cancel, disable or respawn stops the action.")
		Hub.connect(RunService.Heartbeat,function()
			local now=os.clock()
			if active and not current(active) then stop("Character became unavailable, missile actions stopped.")
			elseif active and now>=active.deadline then fail(active,"Spawn/replication timed out.") end
			local expired={};for op,deadline in pairs(flights) do if now>=deadline or not op.toy or not op.toy.Parent then table.insert(expired,op) end end
			for _,op in ipairs(expired) do releaseFlight(op) end
			if loopOn and not active and now>=nextLoop then
				if loopCount>=maxCycles then stop("Loop finished its selected action count.") else start(toyName,action) end
			end
		end)
		Hub.connect(Player.CharacterRemoving,function() stop("Character changed, missile actions stopped.") end)
		Hub.cleanup(function() enabled=false;loopOn=false;cancel();Hub.throwMissile=nil;Hub.explodeMissile=nil;Hub.missileReservedModels=nil;Hub.isMissileReserved=nil;Hub.prepareExplosive=nil;Hub.missileWorkBusy=nil;Hub.missileHasRetry=nil;Hub.cancelMissileWork=nil end)
	end)()
end

-- Blitz-style preloaded explosives, integrated with the hub's own-toy reservations.
do
	(function()
		local group=Tabs.Explosions:AddLeftGroupbox("Explosions Spam")
		local help=Tabs.Explosions:AddRightGroupbox("FAQ about Explosions Spam")
		local types={Firework="FireworkMissile",Missile="BombMissile",Void="BombDarkMatter",Ballon="BombBalloon",["Small Present"]="PresentSmall",["Big Present"]="PresentBig"}
		local enabled,held,predict=false,false,false
		local kind,trigger,targetMode="Firework","Automatic","Spawn"
		local amount,delay=1,0
		local selected=nil
		local cache,queue,retired={},{},{}
		local aimEntry,pending=nil,nil
		local epoch,nextSpawn,nextFire,lastAim=0,0,0,0
		local retryDelay,retryReason=0.5,nil
		local retained={}
		local status=group:AddLabel("Off.")
		local picker
		local stopping=false
		local nextStatus=0
		local function own(entry)
			local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			return entry and entry.model and entry.model.Parent==folder
				and entry.hit and entry.hit.Parent and entry.position and entry.position.Parent
				and Hub.isMissileReserved and Hub.isMissileReserved(entry.model)
		end
		local function dispose(entry,deleteToy)
			if not entry or entry.disposed then return end
			entry.disposed=true;retired[entry]=nil
			if not deleteToy and entry.model then retained[entry.model]=true end
			local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			local model=entry.model
			entry.release()
			if deleteToy and model and model.Parent==folder then
				local menu=ReplicatedStorage:FindFirstChild("MenuToys")
				local remote=menu and menu:FindFirstChild("DestroyToy")
				if remote then Hub.fire(remote,model) end
			end
		end
		local function clearCache()
			for _,entry in ipairs(cache) do dispose(entry) end
			for _,entry in ipairs(queue) do dispose(entry) end
			local old={};for entry in pairs(retired) do table.insert(old,entry) end;for _,entry in ipairs(old) do dispose(entry) end
			table.clear(cache);table.clear(queue)
			dispose(aimEntry);aimEntry=nil
		end
		local function stop(reason)
			if stopping then return end;stopping=true
			enabled=false;held=false;epoch+=1;pending=nil;retryDelay=0.5;retryReason=nil
			clearCache()
			if Hub.cancelMissileWork then Hub.cancelMissileWork(reason or "Explosion cache stopped.") end
			local toggle=Toggles.BlitzExplodeEnabled
			if toggle and toggle.Value then toggle:SetValue(false) end
			status:SetText(reason or "Off, launch forces released. Your toys were kept.")
			stopping=false
		end
		local function refresh()
			local names={};for _,p in ipairs(Players:GetPlayers()) do if p~=Player then table.insert(names,p.Name) end end
			table.sort(names);picker:SetValues(names)
		end
		local function wantsAim() return targetMode=="Mouse" or (targetMode=="Player" and predict) end
		local function target()
			if targetMode=="Spawn" then
				local spawn=Workspace:FindFirstChild("SpawnLocation",true)
				if spawn and spawn:IsA("BasePart") then return spawn,Vector3.new(math.random(-10,10),math.random(-10,10),math.random(-10,10)) end
			elseif targetMode=="Player" then
				local p=selected
				local char=p and p.Character
				local hum=char and char:FindFirstChildOfClass("Humanoid")
				local root=char and char:FindFirstChild("HumanoidRootPart")
				local plot=p and p:FindFirstChild("InPlot")
				if not p or not Hub.canHarm(p) or (plot and plot.Value) or not hum or hum.Health<=0 or not root then return nil end
				if predict then
					if own(aimEntry) then return aimEntry.position,Hub.teleportFrame(root).Position+root.AssemblyLinearVelocity/1.93 end
				else return root,Hub.teleportFrame(root).Position end
			elseif own(aimEntry) then
				local char=Player.Character
				local camPart=char and char:FindFirstChild("CamPart")
				local camera=Workspace.CurrentCamera
				local cf=camPart and camPart.CFrame or (camera and camera.CFrame)
				if not cf then return nil end
				local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
				local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
				params.FilterDescendantsInstances=folder and {char,folder} or {char}
				params.IgnoreWater=true
				local hit=Workspace:Raycast(cf.Position,cf.LookVector*5000,params)
				return aimEntry.position,hit and hit.Position or (cf.Position+cf.LookVector*5000)
			end
			return nil
		end
		local function readyToFire()
			return targetMode=="Mouse" and held or (targetMode~="Mouse" and (trigger=="Automatic" or held))
		end
		local function spawnBudget()
			local can=Player:FindFirstChild("CanSpawnToy")
			if can and not can.Value then return false end
			local used,cap=Player:FindFirstChild("UsedToyPoints"),Player:FindFirstChild("ToysLimitCap")
			return not used or not cap or used.Value+10<=cap.Value
		end
		local function canPrepare(name)
			return (Hub.missileHasRetry and Hub.missileHasRetry(name)) or spawnBudget()
		end
		local function retry(reason)
			pending=nil
			retryReason=tostring(reason)
			nextSpawn=os.clock()+retryDelay
			status:SetText(string.format("Retrying cache in %.1fs: %s. Ready explosives remain usable.",retryDelay,retryReason))
			retryDelay=math.min(8,retryDelay*2)
		end
		local function prepare(name,isAim)
			local ticket=epoch
			Hub.lastMissileError=nil
			local request={aim=isAim,time=os.clock()}
			pending=request
			local accepted=Hub.prepareExplosive(name,function(entry)
				if not enabled or ticket~=epoch or pending~=request then dispose(entry);return end
				pending=nil;nextSpawn=os.clock();retryDelay=0.5;retryReason=nil
				Hub.lastMissileError=nil
				if isAim then aimEntry=entry else table.insert(cache,entry) end
				status:SetText(string.format("%d/%d %s cached, %s trigger, %s target.",#cache,amount,kind,trigger,targetMode))
			end)
			if not accepted and pending==request then retry(Hub.lastMissileError or "cannot prepare toy yet; check missile actions, ownership and toy points") end
		end
		local function step()
			if not enabled then return end
			local char=Player.Character
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health<=0 then stop("Character unavailable, explosion cache stopped.");return end
			local now=os.clock()
			-- A surviving explosive still consumes toy points. Reuse it instead of
			-- releasing it into an unusable retained pool after the first effect.
			local cooling=0
			for entry,readyAt in pairs(retired) do
				if not own(entry) then dispose(entry)
				elseif now>=readyAt then retired[entry]=nil;table.insert(cache,entry)
				else cooling+=1 end
			end
			for model in pairs(retained) do if not model.Parent then retained[model]=nil end end
			for i=#cache,1,-1 do if not own(cache[i]) then dispose(cache[i]);table.remove(cache,i) end end
			if aimEntry and not own(aimEntry) then dispose(aimEntry);aimEntry=nil end
			if aimEntry and now-lastAim>=0.05 and aimEntry.force then
				lastAim=now
				aimEntry.force.Position=Vector3.new(math.floor(now/0.05)%2==0 and 1000 or -1000,400,10000)
			end
			if pending and not Hub.missileWorkBusy() then retry(Hub.lastMissileError or "toy preparation failed or was cancelled") end
			if wantsAim() and not aimEntry then
				if not pending and canPrepare("DiceSmall") and now>=nextSpawn and not Hub.missileWorkBusy() then prepare("DiceSmall",true) end
				return
			end
			-- Amount is a cache capacity, not a barrier: fire whatever is ready.
			if #queue==0 and #cache>0 and readyToFire() and target() then
				if trigger=="Key" or targetMode=="Mouse" then table.insert(queue,table.remove(cache,1))
				else queue=cache;cache={} end
			end
			if #queue>0 and now>=nextFire and readyToFire() then
				local positionPart,position=target()
				if positionPart then
					local events=ReplicatedStorage:FindFirstChild("BombEvents")
					local remote=events and events:FindFirstChild("BombExplode")
					if not remote then nextFire=now+1;status:SetText("Waiting for BombExplode; retrying automatically.");return end
					local count=delay>0 and 1 or #queue
					local failed=false
					for _=1,count do
						local entry=table.remove(queue,1)
						if own(entry) then
							-- Preserve Blitz's minimal Hitbox/PositionPart protocol.
							local sent,err=pcall(function() Hub.fire(remote,{Hitbox=entry.hit,PositionPart=positionPart},position) end)
							if not sent then
								table.insert(queue,1,entry);failed=true
								status:SetText("Explosion request failed; retrying automatically: "..tostring(err):sub(1,140))
								break
							end
							retired[entry]=now+2;cooling+=1
						else entry.release() end
					end
					nextFire=now+(failed and math.max(0.5,delay) or delay)
				end
			end
			if not pending and #cache+#queue+cooling<amount and now>=nextSpawn and not Hub.missileWorkBusy() and canPrepare(types[kind]) then prepare(types[kind],false) end
			if now>=nextStatus and not pending then
				nextStatus=now+0.5
				local detail
				if retryReason and now<nextSpawn then detail=string.format("retrying preparation in %.1fs",nextSpawn-now)
				elseif not readyToFire() then detail="waiting for held Trigger Bombs"
				elseif not target() then detail=targetMode=="Player" and "waiting for an eligible selected player outside a plot" or "waiting for a valid target surface/reference"
				elseif cooling>0 then detail="cooldown, surviving toys will return to the cache"
				elseif #cache+#queue==0 and not spawnBudget() then detail="toy limit/cooldown reached, no live cached explosive available"
				else detail="active" end
				status:SetText(string.format("%d ready, %d queued, %d cooling, %s.",#cache,#queue,cooling,detail))
			end
		end
		group:AddToggle("BlitzExplodeEnabled",{Text="Explode",Default=false,Callback=function(on)
			if stopping then return end
			if not on then stop();return end
			if Toggles.MissileLoopEnabled and Toggles.MissileLoopEnabled.Value then Toggles.MissileLoopEnabled:SetValue(false) end
			enabled=true;held=false;epoch+=1;nextSpawn=0;nextFire=0;retryDelay=0.5;retryReason=nil
			status:SetText("Filling explosive cache...")
		end})
		group:AddDropdown("BlitzExplosionType",{Text="Explosion Type",Values={"Firework","Missile","Void","Ballon","Small Present","Big Present"},Default=1,Callback=function(value)
			if kind~=value then
				local wasEnabled=enabled
				epoch+=1;pending=nil;held=false;clearCache()
				if Hub.cancelMissileWork then Hub.cancelMissileWork("Explosive type changed, toys kept.") end
				kind=value;nextSpawn=0;nextFire=0;retryDelay=0.5;retryReason=nil
				enabled=wasEnabled
				status:SetText(wasEnabled and "Type changed, refilling cache. Previous toys kept." or "Ready.")
			end
		end})
		group:AddLabel("Trigger Bombs (hold)"):AddKeyPicker("BlitzTriggerBombsKey",{Default="F",Text="Trigger Bombs",Callback=function() end})
		group:AddDropdown("BlitzTriggerMode",{Text="Trigger Mode",Values={"Key","Automatic"},Default=2,Callback=function(value) trigger=value;held=false end})
		group:AddSlider("BlitzExplosionDelay",{Text="Delay (Automatic Trigger Mode)",Default=0,Min=0,Max=0.5,Rounding=3,Callback=function(value) delay=value end})
		group:AddSlider("BlitzExplosionAmount",{Text="Cache capacity",Default=1,Min=1,Max=20,Rounding=0,Callback=function(value) amount=value end})
		group:AddDropdown("BlitzExplosionTarget",{Text="Target",Values={"Spawn","Player","Mouse"},Default=1,Callback=function(value) targetMode=value;held=false end})
		picker=group:AddDropdown("BlitzExplosionPlayer",{Text="Select Player",Values={},Callback=function(value) selected=type(value)=="string" and Players:FindFirstChild(value) or nil end})
		group:AddToggle("BlitzPredictPlayer",{Text="Predict Player Movement",Default=false,Callback=function(on) predict=on end})
		group:AddButton({Text="Refresh player list",Func=refresh})
		group:AddButton({Text="Stop, keep toys",Func=function() stop() end})
		group:AddButton({Text="Retry cache",Func=function()
			if not enabled then status:SetText("Enable Explode first. Your previous toys were kept.");return end
			if pending and Hub.missileWorkBusy() then status:SetText("The current toy is already retrying automatically.");return end
			pending=nil;nextSpawn=os.clock();retryDelay=0.5;retryReason=nil;status:SetText("Retry requested. Preparing one toy at a time.")
		end})
		group:AddButton({Text="Delete this tool's cached toys",Func=function()
			local models={};for model in pairs(retained) do models[model]=true end
			for model in pairs(Hub.missileKeptModels or {}) do models[model]=true end
			for _,entry in ipairs(cache) do models[entry.model]=true end
			for _,entry in ipairs(queue) do models[entry.model]=true end
			for entry in pairs(retired) do models[entry.model]=true end
			if aimEntry then models[aimEntry.model]=true end
			stop("Explicit cache deletion requested.")
			local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			local toys=ReplicatedStorage:FindFirstChild("MenuToys");local remote=toys and toys:FindFirstChild("DestroyToy")
			if remote then for model in pairs(models) do if model.Parent==folder then Hub.fire(remote,model) end;retained[model]=nil;if Hub.missileKeptModels then Hub.missileKeptModels[model]=nil end end end
		end})
		help:AddLabel("Mouse targeting uses Press/Hold Trigger Bombs, even in Automatic mode, matching Blitz. Player targeting needs Target = Player and a selected unprotected player outside a plot.")
		help:AddLabel("The cache is created from your own toys and parked at height 10000 after ownership is confirmed. Prediction and mouse aiming use an owned DiceSmall as Blitz's replicated aim reference. This tool does not buy toys.")
		help:AddLabel("Ready explosives fire immediately, even while another toy is being prepared. Cache capacity sets the number of reusable explosives to keep, without requiring a full cache. Spawning remains serialized and respects server cooldowns and toy limits. Ownership retries reuse the same toy; temporary preparation failures retry automatically with backoff. Stop and unload keep toys.")
		Hub.connect(UserInputService.InputBegan,function(input,processed)
			if processed or not enabled or UserInputService:GetFocusedTextBox() or Hub.keybindCaptureActive then return end
			if Hub.matchesKeybind("BlitzTriggerBombsKey",input,"F") then held=true end
		end)
		Hub.connect(UserInputService.InputEnded,function(input)
			local option=Options.BlitzTriggerBombsKey
			if input.KeyCode and input.KeyCode.Name==(option and option.Value or "F") then held=false end
		end)
		Hub.connect(UserInputService.WindowFocusReleased,function() held=false end)
		Hub.connect(Players.PlayerAdded,function() Hub.queueRefresh("blitzExplosions",refresh) end)
		Hub.connect(Players.PlayerRemoving,function(person) if person==selected then selected=nil end;Hub.queueRefresh("blitzExplosions",refresh) end)
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed<0.05 then return end;elapsed=0;step() end)
		Hub.connect(Player.CharacterRemoving,function() stop("Respawn, explosion cache cleared.") end)
		Hub.stopBlitzExplosions=stop
		Hub.cleanup(function() stop();Hub.stopBlitzExplosions=nil end)
		refresh()
	end)()
end

-- End missile throw.

-- Click TP requires a finite, solid surface hit, never Mouse.Hit's sky fallback.
Hub.clickTeleport=function()
	Hub.cancelNativeTeleportMasks()
	Hub.clearTeleportMask(false)
	if Hub.safeZoneLoopActive then return end
	local char=Player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health<=0 then return end
	local ray=mouse.UnitRay
	local filter=RaycastParams.new()
	filter.FilterType=Enum.RaycastFilterType.Exclude
	filter.FilterDescendantsInstances={char}
	filter.RespectCanCollide=true
	filter.IgnoreWater=true
	local hit=Workspace:Raycast(ray.Origin,ray.Direction*512,filter)
	if not hit then return end
	local position=hit.Position
	for _,value in ipairs({position.X,position.Y,position.Z}) do
		if value~=value or math.abs(value)==math.huge then return end
	end
	if (position-root.Position).Magnitude>512 or position.Y<=Workspace.FallenPartsDestroyHeight+8 then return end
	-- Any real collidable surface is valid, including walls and ceilings.
	-- Offset toward the exposed side of the hit so the character stays outside it.
	local clearance=math.max(3,hum.HipHeight+root.Size.Y/2+0.5)
	local destination=CFrame.new(position+hit.Normal*clearance)*root.CFrame.Rotation
	if Hub.smoothTeleport and Hub.smoothTeleport(root,destination) then return end
	root.CFrame=destination
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
end
MiscGroup:AddToggle("TPToggle",{Text="Click TP (Z)",Default=false,Callback=function(on)
	if tpToolConn then tpToolConn:Disconnect();Hub.connections[tpToolConn]=nil;tpToolConn=nil end
	if on then tpToolConn=Hub.connect(UserInputService.InputBegan,function(input,processed)
			if not processed and Hub.matchesKeybind("ClickTeleportKey", input, "Z") and not UserInputService:GetFocusedTextBox() then Hub.clickTeleport() end
		end) end
end})


MiscGroup:AddToggle("PlayerList", {
	Text = "Playerlist Visible",
	Default = false,
	Callback = function(Value)
		if Value then
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,true)
		else
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
		end
	end
})


local enabled = false
local freeMouseGui
local mouseOriginal
local function setFreeMouse(on)
	if on == enabled then return end
	enabled = on
	if on then
		mouseOriginal = {UserInputService.MouseBehavior, UserInputService.MouseIconEnabled}
		freeMouseGui = Hub.new("ScreenGui")
		freeMouseGui.Name = "ArrivaCoreMouseUnlock"
		freeMouseGui.ResetOnSpawn = false
		local button = Hub.new("TextButton")
		button.BackgroundTransparency = 1
		button.Size = UDim2.fromOffset(1, 1)
		button.Text = ""
		button.Modal = true
		button.Parent = freeMouseGui
		freeMouseGui.Parent = Player:FindFirstChildOfClass("PlayerGui")
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		if freeMouseGui then freeMouseGui:Destroy(); freeMouseGui = nil end
		if mouseOriginal then
			UserInputService.MouseBehavior = mouseOriginal[1]
			UserInputService.MouseIconEnabled = mouseOriginal[2]
			mouseOriginal = nil
		end
	end
end
Hub.menuMouse = setFreeMouse
setFreeMouse(Hub.menuVisible ~= false)
Hub.cleanup(function() Hub.menuMouse = nil; setFreeMouse(false) end)
Hub.connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if Hub.matchesKeybind("FreeMouseKey", input, "F") then setFreeMouse(not enabled) end
end)

-- Water Walk
local waterParts = {}
task.spawn(function()
	if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("AlwaysHereTweenedObjects") then
		local ocean = workspace.Map.AlwaysHereTweenedObjects:FindFirstChild("Ocean")
		local object = ocean and ocean:FindFirstChild("Object")
		local oceanModel = object and object:FindFirstChild("ObjectModel")
		if not oceanModel then return end
		for _, v in pairs(oceanModel:GetChildren()) do
			if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("BasePart") or v:IsA("MeshPart") then
				table.insert(waterParts, {part = v, originalCollide = v.CanCollide})
			end
		end
	end
end)

MiscGroup:AddToggle("WaterWalkToggle", {
	Text = "water walk",
	Default = false,
	Callback = function(on)
		Hub.requestSave()
		for _, item in pairs(waterParts) do
			if item.part then item.part.CanCollide = on and true or item.originalCollide end
		end
	end
})

-- Non-swimmable water: original character-state feature, reversible on off/respawn.
do
	local enabled=false;local humanoid,saved,connection
	local function restore()
		if connection then connection:Disconnect();Hub.connections[connection]=nil;connection=nil end
		if humanoid and humanoid.Parent and saved~=nil then humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,saved) end
		humanoid,saved=nil,nil
	end
	local function apply(char)
		restore();if not enabled or char~=Player.Character then return end
		local hum=char:FindFirstChildOfClass("Humanoid");if not hum then return end
		humanoid=hum;saved=hum:GetStateEnabled(Enum.HumanoidStateType.Swimming)
		local function freefall()
			if enabled and humanoid==hum and hum:GetState()==Enum.HumanoidStateType.Swimming then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
		end
		connection=Hub.connect(hum.StateChanged,freefall)
		hum:SetStateEnabled(Enum.HumanoidStateType.Swimming,false);freefall()
	end
	MiscGroup:AddToggle("NonSwimmableWater",{Text="Non-Swimmable Water",Default=false,Callback=function(on)
		enabled=on;if on and Player.Character then apply(Player.Character) else restore() end;Hub.requestSave()
	end})
	Hub.connect(Player.CharacterRemoving,restore)
	Hub.connect(Player.CharacterAdded,function(char) task.spawn(function()
		local hum=char:WaitForChild("Humanoid",5);if hum and Hub.alive and enabled and Player.Character==char then apply(char) end
	end) end)
	Hub.cleanup(function() enabled=false;restore() end)
end

-- Triggerbot System
local Triggerbot = {
	Enabled = false,
	Connection = nil,
	canGrab = true,
	maxDistance = 20,
	preGrabDelay = 0.00001,
	postGrabDelay = 0.05,
	lastTarget = nil,
	lastHitTime = 0,
	targetMemoryDuration = 0.1,
	checkThrottle = 0.008,
	lastCheck = 0
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

task.spawn(function()
	local success, result = pcall(function() return Hub.invoke(ReplicatedStorage.GamepassEvents.CheckForGamepass, 20837132) end)
	if success and result then Triggerbot.maxDistance = 29.3 end
end)

if ReplicatedStorage:FindFirstChild("GamepassEvents") and ReplicatedStorage.GamepassEvents:FindFirstChild("FurtherReachBoughtNotifier") then
	Hub.connect(ReplicatedStorage.GamepassEvents.FurtherReachBoughtNotifier.OnClientEvent, function() Triggerbot.maxDistance = 29.3 end)
end

function Triggerbot:GetTarget()
	local c = Player.Character
	if not c or not c:FindFirstChild("HumanoidRootPart") then return end
	if Workspace:FindFirstChild("GrabParts") then return end

	local origin, dir = Camera.CFrame.Position, Camera.CFrame.LookVector
	rayParams.FilterDescendantsInstances = { c, Workspace.Terrain }

	local result = Workspace:Raycast(origin, dir * 1000, rayParams)
	if not result then
		local dirs = { dir, (dir + Vector3.new(0, 0.075, 0)).Unit, (dir - Vector3.new(0, 0.075, 0)).Unit }
		for _, d in ipairs(dirs) do
			result = Workspace:Raycast(origin, d * 1000, rayParams)
			if result then break end
		end
	end

	if not result then return end
	local hit = result.Instance
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model or not model:FindFirstChildOfClass("Humanoid") or model == c or not Hub.canAffect(model) then return end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum.Health <= 0 then return end

	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local dist = (c.HumanoidRootPart.Position - Hub.teleportFrame(root).Position).Magnitude
	if dist > self.maxDistance then return end

	return model
end

function Triggerbot:OnHeartbeat()
	if not self.Enabled or not self.canGrab then return end
	if UserInputService:GetFocusedTextBox() then return end

	if tick() - self.lastCheck < self.checkThrottle then return end
	self.lastCheck = tick()

	local t = self:GetTarget()
	if t then
		self.lastTarget = t
		self.lastHitTime = tick()
	elseif self.lastTarget and tick() - self.lastHitTime > self.targetMemoryDuration then
		self.lastTarget = nil
	end

	local c = Player.Character
	local root = self.lastTarget and self.lastTarget:FindFirstChild("HumanoidRootPart")

	if not (self.lastTarget and c and c:FindFirstChild("HumanoidRootPart") and root) then return end

	if (c.HumanoidRootPart.Position - Hub.teleportFrame(root).Position).Magnitude > self.maxDistance then
		self.lastTarget = nil
		return
	end

	if self.lastTarget and Hub.canAffect(self.lastTarget) then
		self.canGrab = false
		task.spawn(function()
			task.wait(self.preGrabDelay)
			if self.Enabled and self.lastTarget and Hub.canAffect(self.lastTarget) then pcall(mouse1press) end
			local t0 = tick()
			repeat
				task.wait(0.02)
			until not Workspace:FindFirstChild("GrabParts") or tick() - t0 > 1.6
			task.wait(self.postGrabDelay)
			self.canGrab = true
			self.lastTarget = nil
		end)
	end
end

-- Network flooders intentionally excluded from this maintenance revision.

-- Auto Reset
local autoResetEnabled = false
DefenseGroup:AddToggle("AutoResetToggle", {
	Text = "Auto Reset",
	Default = false,
	Callback = function(on)
		Hub.requestSave()
		autoResetEnabled = on

		if not on then
			autoResetEnabled = false
			return
		end

		task.spawn(function()
			local plr = Player
			while autoResetEnabled do
				local char = plr.Character
				local hum = char and char:FindFirstChild("Humanoid")

				if hum and hum.Health > 0 then
					hum.Health = 0
				end

				task.wait(0.5)
			end
		end)
	end
})

-- Triggerbot Toggle
MiscGroup:AddToggle("TriggerbotToggle", {
	Text = "Trigger Bot",
	Default = Triggerbot.Enabled,
	Callback = function(value)
		Hub.requestSave()
		Triggerbot.Enabled = value
		if Triggerbot.Enabled and not Triggerbot.Connection then
			Triggerbot.Connection = Hub.connect(RunService.Heartbeat, function() Triggerbot:OnHeartbeat() end)
		elseif not Triggerbot.Enabled and Triggerbot.Connection then
			Triggerbot.Connection:Disconnect()
			Triggerbot.Connection = nil
		end
	end
})

-- FOV Slider
PlayerView:AddSlider("FOVSlider", {
	Text = "FOV",
	Default = 90,
	Min = 1,
	Max = 120,
	Rounding = 0,
	Suffix = "°",
	Callback = function(value)
		local cam = workspace.CurrentCamera
		if cam then
			if Hub.cameraFOV[cam] == nil then Hub.cameraFOV[cam] = cam.FieldOfView end
			cam.FieldOfView = value
		end
		Hub.requestSave()
	end
})

do
	-- Black Hole Detection
	local variants = {
		"BlackHole",
		"Black_Hole",
		"Blackhole",
		"Black-Hole",
		"BHole",
		"BH",
		"VoidHole",
		"Void",
		"VoidSphere",
		"DarkHole",
		"DarkSphere",
		"DarkOrb",
		"GravityHole",
		"GravityOrb",
		"SpaceHole",
		"SpaceOrb",
		"Singularity",
		"SingularityOrb",
		"EventHorizon",
		"BlackSphere",
		"Anomaly",
		"AnomalyHole",
		"SupermassiveHole",
		"QuantumHole"
	}

	local function isBlackHole(obj)
		local name = obj.Name:lower()
		for _, v in ipairs(variants) do
			if name:find(v:lower(), 1, true) then
				return true
			end
		end
		return false
	end

	local function getBHPosition(obj)
		if obj:IsA("BasePart") then
			return obj.Position
		end
		local part = obj:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
		return nil
	end

	-- Correlate a real departure with proximity to a recently detected hole.
	local recentHoles={}
	local lastPositions={}
	local function rememberHole(obj)
		if not isBlackHole(obj) then return end
		local position=getBHPosition(obj)
		if not position then return end
		table.insert(recentHoles,{position=position,time=os.clock(),object=obj})
		if #recentHoles>20 then table.remove(recentHoles,1) end
	end
	Hub.connect(workspace.ChildAdded,function(obj)
		task.delay(0.1,function() if Hub.alive and obj.Parent then rememberHole(obj) end end)
	end)
	for _,obj in ipairs(workspace:GetChildren()) do rememberHole(obj) end
	local nextSample=0
	Hub.connect(RunService.Heartbeat,function()
		local now=os.clock()
		if now<nextSample then return end
		nextSample=now+0.25
		for _,person in ipairs(Players:GetPlayers()) do
			local char=person.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			if root then lastPositions[person]={position=Hub.teleportFrame(root).Position,time=now} end
		end
		for index=#recentHoles,1,-1 do
			if now-recentHoles[index].time>6 then table.remove(recentHoles,index) end
		end
	end)
	Hub.connect(Players.PlayerRemoving,function(person)
		local cached=lastPositions[person]
		lastPositions[person]=nil
		local char=person.Character
		local root=char and char:FindFirstChild("HumanoidRootPart")
		local position=root and Hub.teleportFrame(root).Position or (cached and os.clock()-cached.time<2 and cached.position)
		if not position then return end
		for _,hole in ipairs(recentHoles) do
			if os.clock()-hole.time<=6 then
				local holePosition=hole.object.Parent and getBHPosition(hole.object) or hole.position
				if holePosition and (position-holePosition).Magnitude<=100 then
					if Hub.blackholeNoticeEnabled~=false then
						notify("Blackhole detected",person.Name .. " left near a blackhole.",6,"blackhole",person.Name)
					end
					return
				end
			end
		end
	end)
	Hub.cleanup(function() table.clear(lastPositions);table.clear(recentHoles) end)
end

-- Anchor Object
Hub.anchorHeldObject = function(value)
	if type(value)=="string" then return end -- Rebinding is not an activation.
	local original = workspace:FindFirstChild("GrabParts")
	if not original then return end

	local grabPart = original:FindFirstChild("GrabPart", true)
	if not grabPart or not grabPart:IsA("BasePart") then return end

	local heldPart
	for _,joint in ipairs(original:GetDescendants()) do
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
			for _,part in pairs({joint.Part1,joint.Part0}) do
				if part and part:IsA("BasePart") and not part:IsDescendantOf(original) then
					heldPart=part;break
				end
			end
		end
		if heldPart then break end
	end
	if not heldPart then
		local beam=original:FindFirstChildWhichIsA("Beam",true)
		local attachment=beam and beam.Attachment1
		local part=attachment and attachment.Parent
		if part and part:IsA("BasePart") and not part:IsDescendantOf(original) then heldPart=part end
	end
	if not heldPart then notify("Anchor Object","Grab an object first, its attachment was not found.",4);return end
	local targetModel=heldPart:FindFirstAncestorOfClass("Model")
	if not targetModel then targetModel=heldPart end
	local ancestor=heldPart.Parent
	while ancestor and ancestor~=workspace do
		if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
			notify("Anchor Object","This bind only supports objects, not characters.",4);return
		end
		ancestor=ancestor.Parent
	end
	if not targetModel or not Hub.canAffect(targetModel) then return end

	if not targetModel.Parent then
		local found = false
		local connection
		connection = Hub.connect(targetModel.AncestryChanged, function(_, parent)
			if parent then
				found = true
				connection:Disconnect()
			end
		end)

		local startTime = tick()
		while not found and tick() - startTime < 2 do
			task.wait(0.1)
		end

		if not found then return end
	end

	local existing = targetModel:FindFirstChild("CleanedGrabParts")
	if existing then
		local existingHighlight = targetModel:FindFirstChild("AnchorHighlight")
		if existingHighlight then
			existingHighlight:Destroy()
		end
		existing:Destroy()
		return
	end

	local ok,clone = pcall(function() return original:Clone() end)
	if not ok or not clone then notify("Anchor Object","The current grab could not be copied.",4);return end
	Hub.instances[clone]=true
	clone.Name = "CleanedGrabParts"

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = 1
			desc.CanCollide = false

			local beam = desc:FindFirstChild("GrabBeam")
			if beam then beam:Destroy() end

			for _, sName in ipairs({"AttachSound1", "AttachSound", "BeamSound", "BeamSound1"}) do
				local sound = desc:FindFirstChild(sName)
				if sound then sound:Destroy() end
			end
		end
	end

	clone.Parent = targetModel

	local hl = Hub.new("Highlight")
	hl.Name = "AnchorHighlight"
	hl.FillColor = Color3.fromRGB(0, 85, 255)
	hl.FillTransparency = 0.4
	hl.OutlineColor = Color3.fromRGB(0, 170, 255)
	hl.OutlineTransparency = 0.7
	hl.Adornee = targetModel
	hl.Parent = targetModel
	if Hub.styleAnchorHighlight then Hub.styleAnchorHighlight(hl) end

	local destroyConnection
	destroyConnection=Hub.connect(clone.Destroying,function()
		if hl.Parent then hl:Destroy() end
		if destroyConnection then destroyConnection:Disconnect();Hub.connections[destroyConnection]=nil end
	end)

end
Hub.keybindGroups.actions:AddLabel("Anchor held object"):AddKeyPicker("AnchorObjectKey", {Default="G",Text="Anchor Object",NoUI=false,Callback=Hub.anchorHeldObject})



-- Local cosmetic effects: no remotes, physics changes or character reparenting.
do
	local group = Tabs.Visual:AddRightGroupbox("Visual Effects")
	local outlineOn, lightOn = false, false
	local outline, light, childConnection
	local currentCharacter
	local disposed = false

	local function clearEffects()
		if outline then outline:Destroy(); outline = nil end
		if light then light:Destroy(); light = nil end
	end

	local function refresh()
		clearEffects()
		local char = currentCharacter
		if disposed or not char or not char.Parent then return end
		if outlineOn then
			outline = Instance.new("Highlight")
			outline.Name = "ArrivaLocalAura"
			outline.Adornee = char
			outline.DepthMode = Enum.HighlightDepthMode.Occluded
			outline.FillColor = Color3.fromRGB(130, 90, 255)
			outline.OutlineColor = Color3.fromRGB(210, 190, 255)
			outline.FillTransparency = 0.85
			outline.OutlineTransparency = 0.15
			outline.Parent = char
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		if lightOn and root then
			light = Instance.new("PointLight")
			light.Name = "ArrivaLocalGlow"
			light.Color = Color3.fromRGB(150, 110, 255)
			light.Brightness = 1
			light.Range = 12
			light.Shadows = false
			light.Parent = root
		end
	end

	local function bind(char)
		if childConnection then childConnection:Disconnect(); childConnection = nil end
		clearEffects()
		currentCharacter = char
		if disposed or not char then return end
		childConnection = char.ChildAdded:Connect(function(child)
			if child.Name == "HumanoidRootPart" then refresh() end
		end)
		refresh()
	end

	group:AddToggle("LocalOutlineAura", {
		Text = "Self Outline Aura", Default = false,
		Callback = function(on) outlineOn = on; refresh(); Hub.requestSave() end,
	})
	group:AddToggle("LocalGlowAura", {
		Text = "Self Glow Aura", Default = false,
		Callback = function(on) lightOn = on; refresh(); Hub.requestSave() end,
	})
	Hub.connect(Player.CharacterAdded, bind)
	Hub.connect(Player.CharacterRemoving, function(char)
		if char == currentCharacter then bind(nil) end
	end)
	Hub.cleanup(function()
		disposed = true
		bind(nil)
	end)
	bind(Player.Character)
end

-- Camera-only spectator, adapted from the supplied code’s View feature.
do
	local group = Tabs.Player:AddRightGroupbox("Spectator Camera")
	local selected, enabled, stopped = nil, false, false
	local originalCamera, originalSubject
	local characterConnection, childConnection
	local dropdown
	local function disconnectTarget()
		if characterConnection then characterConnection:Disconnect(); characterConnection = nil end
		if childConnection then childConnection:Disconnect(); childConnection = nil end
	end
	local function restore()
		if originalCamera then
			local subject = originalSubject
			if not subject or not subject.Parent then
				subject = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
			end
			if subject then pcall(function() originalCamera.CameraSubject = subject end) end
		end
		originalCamera, originalSubject = nil, nil
	end
	local function update(char)
		if childConnection then childConnection:Disconnect(); childConnection = nil end
		if stopped or not enabled or not char then return end
		local function apply()
			local camera = workspace.CurrentCamera
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if camera and humanoid then
				if camera ~= originalCamera then
					restore()
					originalCamera, originalSubject = camera, camera.CameraSubject
				end
				camera.CameraSubject = humanoid
			end
		end
		childConnection = char.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then apply() end
		end)
		apply()
	end
	local function bind()
		disconnectTarget()
		if stopped or not enabled or not selected then restore(); return end
		characterConnection = selected.CharacterAdded:Connect(update)
		update(selected.Character)
	end
	local function names()
		local values = {}
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			if player ~= Player then table.insert(values, player.Name) end
		end
		table.sort(values)
		return values
	end
	dropdown = group:AddDropdown("LocalSpectatorPlayer", {
		Text = "View Player", Values = names(), AllowNull = true,
		Callback = function(name)
			restore()
			selected = type(name) == "string" and game:GetService("Players"):FindFirstChild(name) or nil
			bind()
		end,
	})
	group:AddToggle("LocalSpectatorEnabled", {
		Text = "Spectate (camera only)", Default = false,
		Callback = function(on) enabled = on; bind() end,
	})
	local players = game:GetService("Players")
	Hub.connect(players.PlayerAdded,function() Hub.queueRefresh("spectator",function() dropdown:SetValues(names()) end) end)
	Hub.connect(players.PlayerRemoving, function(leaving)
		local values = names()
		local index = table.find(values, leaving.Name)
		if index then table.remove(values, index) end
		if leaving == selected then selected = nil; bind(); dropdown:SetValue(nil) end
		Hub.queueRefresh("spectator",function() dropdown:SetValues(names()) end)
	end)
	Hub.connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		if enabled and selected then update(selected.Character) end
	end)
	Hub.cleanup(function() stopped = true; disconnectTarget(); restore() end)
end

-- Shared readiness for manual self-movement and nearby ownership actions.
function Hub.freeCharacterForTools(allowedLoop)
	if not Hub.alive then return nil,"The hub is unloaded." end
	local char=Player.Character
	local root,hum
	if Toggles.AutoGucciBlobToggle and Toggles.AutoGucciBlobToggle.Value then
		local proof=Hub.gucciVerifiedRun
		local controller=Hub.sourceGucci
		if not controller or not controller.state.GucciAntiGrab or not proof or not proof.Confirmed or proof.Char~=char then return nil,"Wait for Gucci confirmation." end
		root,hum=proof.HRP,proof.Hum
	else
		root=char and char:FindFirstChild("HumanoidRootPart")
		hum=char and char:FindFirstChildOfClass("Humanoid")
	end
	local held=Player:FindFirstChild("IsHeld")
	if not root or root.Parent~=char or not hum or hum.Parent~=char or hum.Health<=0 or hum.SeatPart or root.Anchored
		or (held and held.Value) or Hub.interactionVisitLock or Hub.safeZoneLoopActive or Hub.characterFlightActive or Hub.blobFlightActive then
		return nil,"Your character is busy, held, seated or not ready."
	end
	for key,run in pairs(Hub.targetLoopRuns or {}) do if run.enabled and not (allowedLoop=="LoopOwnToyRecovery" and key==allowedLoop) then return nil,"Stop player action loops first." end end
	return root,char,hum
end

-- Creative shapes use real toys from your folder, after ownership confirmation.
do
	(function()
		local shapes=Tabs.Fun:AddLeftGroupbox("Creative Object Aura")
		local settings=Tabs.Fun:AddRightGroupbox("Shape Settings")
		local enabled=false
		local mode,shape="My spawned toys","Heart"
		local count,radius,height,distance,speed=24,8,5,12,20
		local entries={}
		local connection,decorationFolder
		local epoch,phase,elapsed,nextScan=0,0,0,0
		local status=shapes:AddLabel("Aura is off.")
		local centerMode,placedCenter="Follow me",nil
		local formationPlayer
		local lastFormationMessage
		local formationPicker
		local function formationTargetRoot(ownRoot)
			local person=formationPlayer
			local char=person and person.Parent==Players and person.Character
			local leader=char and (char:FindFirstChild("realHrp") or char:FindFirstChild("HumanoidRootPart"))
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not leader or leader.Parent~=char or not hum or hum.Health<=0 then return nil,"Waiting for the selected player's character." end
			if not Hub.finiteVector(leader.Position) or (leader.Position-Hub.teleportFrame(ownRoot).Position).Magnitude>100 then return nil,"Selected player is too far away; formation paused." end
			return leader
		end
		local function refreshFormationPlayers()
			local names={}
			for _,person in ipairs(Players:GetPlayers()) do if person~=Player then table.insert(names,person.Name) end end
			table.sort(names);formationPicker:SetValues(names)
		end
		local function aimedCenter()
			local char=Player.Character
			local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances=decorationFolder and {char,decorationFolder} or {char}
			params.IgnoreWater=true
			local ray=mouse.UnitRay;local hit=Workspace:Raycast(ray.Origin,ray.Direction*200,params)
			if not hit then return nil end
			local root=char and char:FindFirstChild("HumanoidRootPart")
			if not root or (hit.Position-Hub.teleportFrame(root).Position).Magnitude>100 then return nil end
			return CFrame.new(hit.Position+Vector3.new(0,height,0))*Hub.teleportFrame(root).Rotation
		end
		settings:AddDropdown("CreativeAuraCenter",{Text="Formation center",Values={"Follow me","Follow mouse","Click to place","Follow selected player"},Default=1,
			Callback=function(value) centerMode=value;placedCenter=nil;lastFormationMessage=nil;if enabled then status:SetText("Formation center: "..value) end end})
		formationPicker=settings:AddDropdown("CreativeAuraFollowPlayer",{Text="Formation player",Values={},Callback=function(value)
			formationPlayer=type(value)=="string" and Players:FindFirstChild(value) or nil
		end})
		settings:AddButton({Text="Refresh formation players",Func=refreshFormationPlayers})
		refreshFormationPlayers()
		Hub.connect(Players.PlayerAdded,function() Hub.queueRefresh("formationPlayers",refreshFormationPlayers) end)
		Hub.connect(Players.PlayerRemoving,function(person)
			if person==formationPlayer then formationPlayer=nil end
			Hub.queueRefresh("formationPlayers",refreshFormationPlayers)
		end)
		Hub.connect(UserInputService.InputBegan,function(input,processed)
			if enabled and centerMode=="Click to place" and not processed and not UserInputService:GetFocusedTextBox()
				and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
				placedCenter=aimedCenter() or placedCenter
			end
		end)
		local spawnBatch,cancelSpawn

		local function point(name,index,total,rotation)
			local fraction=(index-1)/math.max(total,1)
			local angle=fraction*math.pi*2+rotation
			if name=="Heart" then
				return Vector3.new(16*math.sin(angle)^3/18,
					(13*math.cos(angle)-5*math.cos(2*angle)-2*math.cos(3*angle)-math.cos(4*angle))/18,0)
			elseif name=="Figure Eight" then
				return Vector3.new(math.sin(angle),math.sin(2*angle)*0.5,0)
			elseif name=="Tornado" then
				local width=0.2+fraction*0.8
				return Vector3.new(math.cos(angle*3)*width,(fraction-0.5)*2,math.sin(angle*3)*width)
			elseif name=="Blackhole" then
				local width=0.15+fraction*0.85
				return Vector3.new(math.cos(angle*3)*width,math.sin(angle*3)*width,0)
			elseif name=="Star" then
				local width=index%2==0 and 0.45 or 1
				return Vector3.new(math.cos(angle)*width,math.sin(angle)*width,0)
			elseif name=="Wings" then
				local side=index%2==0 and 1 or -1
				local span=math.floor((index-1)/2)/math.max(math.ceil(total/2)-1,1)
				return Vector3.new(side*(0.1+span*0.9),math.sin(span*math.pi)*0.5,0.15+span*0.4)
			elseif name=="Cape" then
				local column=(index-1)%4
				local row=math.floor((index-1)/4)
				return Vector3.new(column/3-0.5,-row/math.max(math.ceil(total/4)-1,1),0.25+math.sin(rotation+row)*0.08)
			elseif name=="67" then
				local points={{-1.75,1.65},{-0.65,1.65},{-1.75,0.55},{-1.75,-0.55},{-0.65,-0.55},{-1.75,-1.65},{-0.65,-1.65},
					{0.5,1.65},{1.6,1.65},{2.7,1.65},{2.15,0.55},{1.6,-0.55},{1.05,-1.65}}
				local point=points[(index-1)%#points+1]
				return Vector3.new((point[1]-0.475)/2.225,point[2]/2.225,0)
			elseif name=="Helix" then
				return Vector3.new(math.cos(angle),(fraction-0.5)*2,math.sin(angle))
			end
			return Vector3.new(math.cos(angle),math.sin(angle),0)
		end
		Hub.creativeShapePoint=point

		local function release(entry)
			if entry.decoration then
				pcall(function() entry.part:Destroy() end)
				return
			end
			for _,object in ipairs(entry.controllers or {}) do pcall(function() object:Destroy() end) end
			for part,value in pairs(entry.collisions or {}) do
				pcall(function() if part.Parent then part.CanCollide=value end end)
			end
			pcall(function()
				if entry.part.Parent and not entry.part.Anchored then
					entry.part.AssemblyLinearVelocity=Vector3.zero
					entry.part.AssemblyAngularVelocity=Vector3.zero
				end
			end)
		end
		local function stopWorker()
			if cancelSpawn then cancelSpawn() end
			epoch+=1
			if connection then connection:Disconnect();Hub.connections[connection]=nil;connection=nil end
			for _,entry in ipairs(entries) do release(entry) end
			table.clear(entries)
			if decorationFolder then decorationFolder:Destroy();decorationFolder=nil end
			elapsed,nextScan=0,0
		end
		local function characterRoot()
			local char=Player.Character
			return char and char:FindFirstChild("HumanoidRootPart")
		end
		local function safeAssembly(part,folder)
			if Hub.isGucciReserved(part) then return nil end
			if Hub.isMissileReserved and Hub.isMissileReserved(part) then return nil end
			if part and ((Hub.toyBuildClaims and Hub.toyBuildClaims[part.AssemblyRootPart or part]) or (Hub.missileLaunchClaims and Hub.missileLaunchClaims[part.AssemblyRootPart or part])) then return nil end
			if not part.Parent or part.Anchored or not part:IsDescendantOf(folder) then return nil end
			local owner=part:FindFirstChild("PartOwner")
			if owner and (owner:IsA("StringValue") or owner:IsA("ObjectValue")) then
				local value=owner.Value
				if value~=nil and value~="" and value~=Player.Name and value~=Player then return nil end
			end
			local parts=part:GetConnectedParts(true)
			table.insert(parts,part)
			for _,item in ipairs(parts) do
				if not item:IsDescendantOf(folder) or item.Anchored or item:IsA("Seat") or item:IsA("VehicleSeat") then return nil end
				local current=item.Parent
				while current and current~=folder do
					if current:IsA("Model") and (current:FindFirstChildOfClass("Humanoid")
						or current:FindFirstChildWhichIsA("Seat",true) or current:FindFirstChildWhichIsA("VehicleSeat",true)) then return nil end
					current=current.Parent
				end
			end
			return parts
		end
		local function addToy(part,parts)
			local collisions={}
			for _,item in ipairs(parts) do collisions[item]=item.CanCollide;item.CanCollide=false end
			local attachment=Hub.new("Attachment",part)
			attachment.Name="ArrivaCreativeAttachment"
			local position=Hub.new("AlignPosition",part)
			position.Name="ArrivaCreativePosition"
			position.Mode=Enum.PositionAlignmentMode.OneAttachment
			position.Attachment0=attachment
			position.Position=part.Position
			position.ApplyAtCenterOfMass=true
			position.MaxForce=math.clamp(part.AssemblyMass*5000,2500,100000)
			position.MaxVelocity=40
			position.Responsiveness=40
			local orientation=Hub.new("AlignOrientation",part)
			orientation.Name="ArrivaCreativeOrientation"
			orientation.Mode=Enum.OrientationAlignmentMode.OneAttachment
			orientation.Attachment0=attachment
			orientation.CFrame=part.CFrame.Rotation
			orientation.MaxTorque=100000
			orientation.Responsiveness=30
			table.insert(entries,{part=part,controllers={position,orientation,attachment},
				position=position,orientation=orientation,collisions=collisions})
		end
		local function refreshToys(root)
			local folder=Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
			local used={}
			for index=#entries,1,-1 do
				local entry=entries[index]
				if not folder or not safeAssembly(entry.part,folder) or not Hub.auraOwned(entry.part) then
					release(entry);table.remove(entries,index)
				else used[entry.part]=true end
			end
			if folder and #entries<count then
				for _,item in ipairs(folder:GetDescendants()) do
					if item:IsA("BasePart") then
						local part=item.AssemblyRootPart or item
						if not used[part] and (part.Position-Hub.teleportFrame(root).Position).Magnitude<=80 then
							used[part]=true
							local parts=safeAssembly(part,folder)
							if parts and Hub.acquireAuraPart(part,root) then addToy(part,parts) end
						end
					end
					if #entries>=count then break end
				end
			end
			status:SetText(string.format("Using %d of your toy assemblies, up to %d. Unconfirmed objects remain untouched.",#entries,count))
		end
		local function start(skipSpawn)
			stopWorker()
			if not enabled then status:SetText("Aura is off.");return end
			phase=0
			connection=Hub.connect(RunService.Heartbeat,function(dt)
				elapsed+=dt
				if elapsed<1/30 then return end
				local delta=elapsed;elapsed=0
				local root=characterRoot()
				if not root then return end
				phase=(phase+math.rad(speed)*math.min(delta,0.1))%(math.pi*2)
				local center=Hub.teleportFrame(root)*CFrame.new(0,height,-distance)
				if centerMode=="Follow selected player" then
					local leader,reason=formationTargetRoot(root)
					if not leader then
						for _,entry in ipairs(entries) do
							if entry.decoration then entry.part.Transparency=1
							else entry.position.Enabled=false;entry.orientation.Enabled=false end
						end
						if lastFormationMessage~=reason then status:SetText(reason);lastFormationMessage=reason end;return
					end
					if lastFormationMessage then status:SetText("Following @"..formationPlayer.Name);lastFormationMessage=nil end
					center=leader.CFrame*CFrame.new(0,height,-distance)
				elseif centerMode=="Follow mouse" then center=aimedCenter() or center
				elseif centerMode=="Click to place" then center=placedCenter or center end
				if mode=="My spawned toys" and os.clock()>=nextScan then
					nextScan=os.clock()+2;refreshToys(root)
				end
				for index=#entries,1,-1 do
					local entry=entries[index]
					if not entry.part.Parent or not Hub.auraOwned(entry.part) then release(entry);table.remove(entries,index)
					else
						local goal=center:PointToWorldSpace(point(shape,index,#entries,phase)*radius)
						if entry.decoration then
							entry.part.CFrame=CFrame.new(goal)
							entry.part.Transparency=0
						else
							entry.position.Enabled=true;entry.orientation.Enabled=true
							entry.position.Position=goal
							entry.part.AssemblyAngularVelocity=Vector3.zero
						end
					end
				end
			end)
			if not skipSpawn and mode=="My spawned toys" and spawnBatch then task.defer(function() spawnBatch(true) end) end
		end
		shapes:AddToggle("CreativeAuraEnabled",{Text="Creative Object Aura",Default=false,
			Callback=function(on) enabled=on;start() end})
		shapes:AddDropdown("CreativeAuraSource",{Text="Objects to use",Values={"My spawned toys"},Default=1,
			Callback=function(value) mode="My spawned toys";start() end})
		settings:AddDropdown("CreativeAuraShape",{Text="Shape",Values={"Heart","Ring","Helix","Figure Eight","Tornado","Blackhole","Star","Wings","Cape","67"},Default=1,
			Callback=function(value) shape=value end})
		settings:AddSlider("CreativeAuraCount",{Text="Maximum objects",Default=24,Min=8,Max=40,Rounding=0,
			Callback=function(value) count=value;start() end})
		settings:AddSlider("CreativeAuraRadius",{Text="Shape size",Default=8,Min=3,Max=20,Rounding=0,Callback=function(value) radius=value end})
		settings:AddSlider("CreativeAuraHeight",{Text="Height",Default=5,Min=0,Max=20,Rounding=0,Callback=function(value) height=value end})
		settings:AddSlider("CreativeAuraDistance",{Text="Distance in front",Default=12,Min=6,Max=40,Rounding=0,Callback=function(value) distance=value end})
		settings:AddSlider("CreativeAuraSpeed",{Text="Animation speed",Default=20,Min=0,Max=90,Rounding=0,Callback=function(value) speed=value end})
		-- Bounded, opt-in spawning of decorative toys through the normal menu remote.
		local toyGroup=Tabs.Fun:AddLeftGroupbox("Shape Toy Picker")
		local catalog={
			{id="BallMagicLight",name="Light Ball",points=10},
			{id="MineralCrystalPink",name="Crystal",points=10},
			{id="ToyAnimalDuck",name="Rubber Duck",points=10},
			{id="ToyAnimalBear",name="Stuffed Bear",points=10},
			{id="ToyAnimalFrog",name="Toy Frog",points=10},
			{id="ToyAnimalTiger",name="Stuffed Tiger",points=10},
			{id="ToyAnimalUnicorn",name="Stuffed Unicorn",points=10},
			{id="DiceSmall",name="Small Die",points=5},
			{id="DiceBig",name="Big Die",points=5},
			{id="BallBasketball",name="Basketball",points=10},
			{id="MineralDiamond",name="Diamond",points=5},
			{id="MineralIngotGold",name="Gold Ingot",points=5},
			{id="Snowflake",name="Snowflake",points=10},
			{id="TetracubeI",name="Tetracube I",points=5},
			{id="TetracubeO",name="Tetracube O",points=5},
			{id="TetracubeT",name="Tetracube T",points=5}
		}
		local selected=catalog[1]
		local amount,autoSpawn=8,false
		local busy,cancelled=false,false
		cancelSpawn=function() cancelled=true end
		local spawnedHere={}
		local spawnStatus=toyGroup:AddLabel("Ready, choose a toy you already own.")
		local budget=toyGroup:AddLabel("Toy points are checked before every spawn.")
		local function updateBudget()
			local used=Player:FindFirstChild("UsedToyPoints")
			local cap=Player:FindFirstChild("ToysLimitCap")
			if used and cap and typeof(used.Value)=="number" and typeof(cap.Value)=="number" then
				budget:SetText(string.format("Toy points: %d / %d, selected toy costs %d.",used.Value,cap.Value,selected.points))
				return math.max(0,cap.Value-used.Value)
			end
			budget:SetText("Toy-point information unavailable, spawning is paused.")
			return nil
		end
		local function toyFolder() return Workspace:FindFirstChild(Player.Name .. "SpawnedInToys") end
		spawnBatch=function(automatic,requestedAmount)
			if busy or not Hub.alive then return end
			if automatic and (not autoSpawn or not enabled or mode~="My spawned toys") then return end
			local choice=selected
			local wanted=requestedAmount or amount
			if automatic then
				local existing=0
				local folder=toyFolder()
				if folder then for _,toy in ipairs(folder:GetChildren()) do
						if toy.Name==choice.id then existing+=1 end
					end end
				wanted=math.min(amount,math.max(0,count-existing))
			end
			if wanted==0 then spawnStatus:SetText("Enough matching toys already exist.");return end
			local menu=ReplicatedStorage:FindFirstChild("MenuToys")
			local remote=menu and menu:FindFirstChild("SpawnToyRemoteFunction")
			if not remote or not remote:IsA("RemoteFunction") then spawnStatus:SetText("Toy spawning is unavailable in this server.");return end
			busy=true;cancelled=false
			task.spawn(function()
				local made=0
				local ok,err=pcall(function()
					for index=1,wanted do
						if cancelled or not Hub.alive then break end
						local root=characterRoot()
						local char=Player.Character
						local hum=char and char:FindFirstChildOfClass("Humanoid")
						if not root or not hum or hum.Health<=0 then spawnStatus:SetText("Stopped, your character is unavailable.");return end
						local remaining=updateBudget()
						if not remaining or remaining<choice.points then spawnStatus:SetText("Stopped, not enough toy points available.");return end
						local before={}
						local folder=toyFolder()
						if folder then for _,toy in ipairs(folder:GetChildren()) do before[toy]=true end end
						spawnStatus:SetText(string.format("Spawning %s, %d / %d. Stop cancels remaining requests.",choice.name,index,wanted))
						-- Only one request can be in flight, even if the server is slow.
						remote:InvokeServer(choice.id,Hub.teleportFrame(root)*CFrame.new((index%4)*2,0,-10-math.floor((index-1)/4)*2),Vector3.zero)
						local found
						local deadline=os.clock()+5
						repeat
							folder=toyFolder()
							if folder then for _,toy in ipairs(folder:GetChildren()) do
									if toy.Name==choice.id and not before[toy] then found=toy;break end
								end end
							if found or cancelled or not Hub.alive or Player.Character~=char then break end
							task.wait(0.1)
						until os.clock()>=deadline
						if found then spawnedHere[found]=true;made+=1 end
						if cancelled or not Hub.alive then break end
						if Player.Character~=char then spawnStatus:SetText("Stopped after respawn.");return end
						if not found then spawnStatus:SetText("Toy did not appear, check that you own it and can spawn here.");return end
						task.wait(0.75)
					end
					if Hub.alive then spawnStatus:SetText(string.format("%s, spawned %d toy(s).",cancelled and "Stopped" or "Finished",made)) end
				end)
				busy=false
				if Hub.alive then
					updateBudget()
					if not ok then spawnStatus:SetText("Spawning stopped after an error.");warn("Creative toy spawning:",err) end
				end
			end)
		end
		local labels,byLabel={},{}
		for _,toy in ipairs(catalog) do
			local label=string.format("%s (%d points)",toy.name,toy.points)
			table.insert(labels,label);byLabel[label]=toy
		end
		table.insert(labels,"Pallet (5 points)");byLabel["Pallet (5 points)"]={id="PalletLightBrown",name="Pallet",points=5}
		local picker=toyGroup:AddDropdown("CreativeToySelection",{Text="Decorative toy",Values=labels,Default=1,
			Callback=function(value) if byLabel[value] then selected=byLabel[value];updateBudget() end end})
		toyGroup:AddInput("CreativeToySearch",{Text="Search toys",Default="",Finished=false,
			Callback=function(query)
				local filtered={}
				query=string.lower(tostring(query or ""))
				for _,label in ipairs(labels) do if string.find(string.lower(label),query,1,true) then table.insert(filtered,label) end end
				picker:SetValues(filtered)
			end})
		toyGroup:AddSlider("CreativeToyBatchSize",{Text="Toys per batch",Default=8,Min=1,Max=12,Rounding=0,
			Callback=function(value) amount=math.clamp(math.floor(value),1,12) end})
		toyGroup:AddToggle("CreativeToyAutoSpawn",{Text="Spawn missing toys when aura starts",Default=false,
			Callback=function(value) autoSpawn=value end})
		toyGroup:AddButton({Text="Spawn selected toys",Func=function() spawnBatch(false) end})
		Hub.quickSpawnCreativeToy=function() spawnBatch(false,1) end
		local quickEnabled=false
		toyGroup:AddToggle("CreativeQuickSpawn",{Text="Quick spawn selected toy",Default=false,Callback=function(on) quickEnabled=on end})
		Hub.keybindGroups.actions:AddLabel("Quick-spawn selected toy"):AddKeyPicker("CreativeQuickSpawnKey",{Default="P",NoUI=true,Text="Quick-spawn key"})
		Hub.connect(UserInputService.InputBegan,function(input,processed)
			local key=Options.CreativeQuickSpawnKey
			if not processed and quickEnabled and key and Hub.matchesKeybind("CreativeQuickSpawnKey", input, "P") and not UserInputService:GetFocusedTextBox() then spawnBatch(false,1) end
		end)
		toyGroup:AddButton({Text="Stop spawning",Func=function() cancelled=true;spawnStatus:SetText(busy and "Stopping after the current request returns." or "No spawn batch running.") end})
		toyGroup:AddButton({Text="Remove toys spawned by this tool",Func=function()
			cancelled=true
			if busy then spawnStatus:SetText("Wait for the current batch to stop, then remove its toys.");return end
			local menu=ReplicatedStorage:FindFirstChild("MenuToys")
			local remote=menu and menu:FindFirstChild("DestroyToy")
			if not remote or not remote:IsA("RemoteEvent") then spawnStatus:SetText("Toy removal is unavailable.");return end
			busy=true
			task.spawn(function()
				local ok,err=pcall(function()
					stopWorker()
					for toy in pairs(spawnedHere) do
						if not Hub.alive then break end
						local folder=toyFolder()
						if folder and toy.Parent==folder then remote:FireServer(toy);task.wait(0.25) end
						spawnedHere[toy]=nil
					end
					if Hub.alive and enabled then start(true) end
				end)
				busy=false
				if not ok then warn("Creative toy cleanup:",err) end
			end)
		end})
		Hub.connect(Player.CharacterRemoving,function() cancelled=true end)
		Hub.cleanup(function() cancelled=true;autoSpawn=false end)
		for _,name in ipairs({"UsedToyPoints","ToysLimitCap"}) do
			local value=Player:FindFirstChild(name)
			if value then Hub.connect(value.Changed,updateBudget) end
		end
		updateBudget()

		Hub.connect(Player.CharacterRemoving,stopWorker)
		Hub.connect(Player.CharacterAdded,function(char)
			local ticket=epoch
			task.spawn(function()
				local root=char:WaitForChild("HumanoidRootPart",5)
				if root and enabled and Hub.alive and epoch==ticket and Player.Character==char then start() end
			end)
		end)
		Hub.cleanup(function() enabled=false;stopWorker();Hub.creativeShapePoint=nil end)
	end)()
end

-- Nearby object attraction: move only assemblies with observed local ownership.
do
	(function()
		local group=Tabs.Fun:AddRightGroupbox("Object Attraction")
		local enabled=false
		local range,pullSpeed,limit=35,1200,80
		local entries={}
		Hub.objectAttractionParts=entries
		local connection
		local elapsed,scanElapsed=0,0
		local status=group:AddLabel("Attraction is off.")
		local query=OverlapParams.new()
		query.FilterType=Enum.RaycastFilterType.Exclude
		query.MaxParts=512

		local function characterPart(part)
			local parent=part.Parent
			while parent and parent~=Workspace do
				if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then return true end
				parent=parent.Parent
			end
			return false
		end
		local function eligible(part)
			if Hub.isGucciReserved(part) then return false end
			if part and ((Hub.isMissileReserved and Hub.isMissileReserved(part)) or (Hub.toyBuildClaims and Hub.toyBuildClaims[part.AssemblyRootPart or part]) or (Hub.missileLaunchClaims and Hub.missileLaunchClaims[part.AssemblyRootPart or part])) then return false end
			if not part or not part.Parent or not part:IsDescendantOf(Workspace) or part.Anchored or not Hub.canAffect(part) then return false end
			if part:IsA("Seat") or part:IsA("VehicleSeat") or characterPart(part) then return false end
			-- Avoid competing with the separate creative shape controller.
			if part:FindFirstChild("ArrivaCreativeAttachment") then return false end
			for _,other in ipairs(part:GetConnectedParts(true)) do
				if not Hub.canAffect(other) or other.Anchored or other:IsA("Seat") or other:IsA("VehicleSeat") or characterPart(other) then return false end
			end
			return true
		end
		local function release(part)
			local entry=entries[part]
			if not entry then return end
			entries[part]=nil
			for _,object in ipairs(entry) do
				Hub.instances[object]=nil
				Hub.assetTargets[object]=nil
				pcall(function() object:Destroy() end)
			end
			for member,saved in pairs(entry.physics) do
				pcall(function()
					if member.Parent then member.CanCollide=saved.collide;member.Massless=saved.massless end
				end)
			end
		end
		local function stop()
			if connection then connection:Disconnect();Hub.connections[connection]=nil;connection=nil end
			local parts={}
			for part in pairs(entries) do table.insert(parts,part) end
			for _,part in ipairs(parts) do release(part) end
			elapsed,scanElapsed=0,0
		end
		local function add(part)
			local force=Hub.new("BodyVelocity",part)
			force.Name="ArrivaObjectAttraction";force.MaxForce=Vector3.new(1e7,1e7,1e7);force.Velocity=Vector3.zero
			Hub.assetTargets[force]=part
			entries[part]={force,force=force,physics={}}
		end
		local function scan(root)
			local active,pending=0,0
			for part in pairs(entries) do
				if not eligible(part) or not Hub.auraOwned(part) or (part.Position-Hub.teleportFrame(root).Position).Magnitude>range+5 then release(part)
				else active+=1 end
			end
			query.FilterDescendantsInstances=Player.Character and {Player.Character} or {}
			if active<limit then
				local seen={}
				for _,item in ipairs(Workspace:GetPartBoundsInRadius(Hub.teleportFrame(root).Position,range,query)) do
					local part=item.AssemblyRootPart or item
					if not seen[part] and not entries[part] then
						seen[part]=true
						if (part.Position-Hub.teleportFrame(root).Position).Magnitude<=range and eligible(part) then
							if Hub.acquireAuraPart(part,root) then add(part);active+=1 else pending+=1 end
							if active>=limit then break end
						end
					end
				end
			end
			status:SetText(string.format("Controlling %d objects; %d awaiting ownership. Range %d studs.",active,pending,range))
		end
		local function start()
			stop()
			if not enabled then status:SetText("Attraction is off.");return end
			scanElapsed=0.5
			connection=Hub.connect(RunService.Heartbeat,function(dt)
				elapsed+=dt;scanElapsed+=dt
				if elapsed<1/30 then return end
				local deltaTime=math.min(elapsed,0.1)
				elapsed=0
				local char=Player.Character
				local hum=char and char:FindFirstChildOfClass("Humanoid")
				local root=char and char:FindFirstChild("HumanoidRootPart")
				if not root or not hum or hum.Health<=0 then stop();status:SetText("Waiting for your character.");return end
				if scanElapsed>=0.5 then scanElapsed=0;scan(root) end
				-- Gather around the character rather than targeting their body.
				for part,entry in pairs(entries) do
					if not eligible(part) or not Hub.auraOwned(part) then release(part)
					else
						local delta=part.Position-Hub.teleportFrame(root).Position
						local horizontal=Vector3.new(delta.X,0,delta.Z)
						local direction=horizontal.Magnitude>0.01 and horizontal.Unit or Hub.teleportFrame(root).LookVector
						local goal=Hub.teleportFrame(root).Position+direction*6+Vector3.new(0,1,0)
						local offset=goal-part.Position
						entry.force.Velocity=offset.Magnitude>0.05 and offset.Unit*math.min(pullSpeed,offset.Magnitude*6) or Vector3.zero
					end
				end
			end)
		end
		group:AddToggle("ObjectAttractionEnabled",{Text="Object Attraction Aura",Default=false,
			Callback=function(value) enabled=value;start() end})
		group:AddSlider("ObjectAttractionRange",{Text="Attraction range",Default=35,Min=10,Max=120,Rounding=0,
			Callback=function(value) range=value;scanElapsed=0.5 end})
		group:AddSlider("ObjectAttractionDirectSpeed",{Text="Attraction speed (studs/sec)",Default=1200,Min=100,Max=3000,Rounding=0,
			Callback=function(value) pullSpeed=value end})
		group:AddSlider("ObjectAttractionLimit",{Text="Maximum objects",Default=80,Min=10,Max=150,Rounding=0,
			Callback=function(value) limit=value;if enabled then start() end end})
		Hub.connect(Player.CharacterRemoving,stop)
		Hub.connect(Player.CharacterAdded,function(char)
			task.spawn(function()
				local root=char:WaitForChild("HumanoidRootPart",5)
				if root and enabled and Hub.alive and Player.Character==char then start() end
			end)
		end)
		Hub.cleanup(function() enabled=false;stop();Hub.objectAttractionParts=nil end)
	end)()
end

-- Notification-only inspection of server-to-client RemoteEvent arguments.
do
	(function()
		local group=Tabs.AntiLag:AddRightGroupbox("Incoming Payload Monitor")
		local enabled=false
		local threshold,cooldown=256*1024,8
		local generation,nextAlert=0,0
		local listeners,watched={},{}
		local remoteCount=0
		local lastReport
		local received,largest=0,0
		local captureNext=false
		local discovering=false
		local status=group:AddLabel("Incoming payload monitor is off.")
		local function resolvePlayer(value)
			if typeof(value)~="Instance" then return nil end
			local ok,player=pcall(function()
				if not value:IsA("Player") then return nil end
				-- Resolve to the service's current Player, avoiding reliance on
				-- equality of executor-wrapped instance tools.
				return Players:GetPlayerByUserId(value.UserId)
			end)
			return ok and player or nil
		end

		-- Counts observed string and buffer bytes, not compressed packets or transport overhead.
		-- The budget bounds table traversal, cycles are never followed twice.
		local function inspect(args)
			local bytes,budget=0,128
			local seen={}
			local sender,ambiguous
			local function visit(value,depth)
				if budget<=0 then return end
				budget-=1
				local kind=typeof(value)
				if kind=="string" then bytes+=#value
				elseif kind=="buffer" then bytes+=buffer.len(value)
				elseif kind=="Instance" then
					local player=resolvePlayer(value)
					if player then
						if sender and sender.UserId~=player.UserId then ambiguous=true else sender=player end
					end
				elseif kind=="table" and depth<4 and not seen[value] then
					seen[value]=true
					for key,item in pairs(value) do
						if budget<=0 then break end
						visit(key,depth+1);visit(item,depth+1)
					end
				end
			end
			for index=1,args.n do
				if budget<=0 then break end
				visit(args[index],0)
			end
			return bytes,not ambiguous and sender or nil,budget<=0
		end
		local function safePath(instance)
			local ok,path=pcall(function() return instance:GetFullName() end)
			return ok and path:sub(1,180) or instance.ClassName
		end
		local function diagnostic(remote,args,bytes,sender,truncated)
			local lines={"[Arriva payload diagnostic]", "Remote: " .. safePath(remote),
				string.format("Observed string/buffer bytes: %d%s",bytes,truncated and " (inspection limit reached)" or ""),
				"Sender: " .. (sender and sender.Name or "N/A")}
			-- Remote location can identify a character's remote without identifying
			-- who originally caused the server to fire it.
			local ancestor=remote.Parent
			while ancestor and ancestor~=game do
				if ancestor:IsA("Model") then
					local owner=Players:GetPlayerFromCharacter(ancestor)
					if owner then table.insert(lines,"Remote belongs to character: " .. owner.Name);break end
				end
				ancestor=ancestor.Parent
			end
			for index=1,math.min(args.n,12) do
				local value=args[index]
				local kind=typeof(value)
				local detail=kind
				if kind=="string" then
					detail=string.format("string, %d bytes",#value)
					if #value<=32 then detail..=", " .. string.format("%q",value:gsub("%c","?")) end
				elseif kind=="Instance" then detail=value.ClassName .. ", " .. safePath(value)
				elseif kind=="buffer" then detail=string.format("buffer, %d bytes",buffer.len(value))
				end
				table.insert(lines,string.format("Arg %d: %s",index,detail))
			end
			if args.n>12 then table.insert(lines,"Additional arguments omitted.") end
			return table.concat(lines,"\n")
		end
		local function stop()
			generation+=1
			for connection in pairs(listeners) do
				connection:Disconnect();Hub.connections[connection]=nil
			end
			table.clear(listeners);table.clear(watched)
			remoteCount=0;nextAlert=0;received=0;largest=0;captureNext=false;discovering=false
		end
		local function track(event,callback)
			local connection=Hub.connect(event,callback)
			listeners[connection]=true
			return connection
		end
		local function watch(remote)
			if watched[remote] or remoteCount>=2048 or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then return end
			local accessible,event=pcall(function() return remote.OnClientEvent end)
			if not accessible then return end
			local ok,incoming=pcall(track,event,function(...)
				if not enabled then return end
				received+=1
				if not captureNext and os.clock()<nextAlert then return end
				local args=table.pack(...)
				local bytes,sender,truncated=inspect(args)
				-- ExtendGrabLine supplies the sender as its first server-provided argument.
				-- Other Player values are not used as a fallback sender.
				sender=nil
				if remote.Name=="ExtendGrabLine" and remote.Parent==grabEventsFolder then
					sender=resolvePlayer(args[1])
				end
				largest=math.max(largest,bytes)
				if captureNext then
					captureNext=false
					lastReport=diagnostic(remote,args,bytes,sender,truncated)
					print(lastReport)
					notify("Payload monitor","Captured one incoming event, details are in the F9 console.",5)
				end
				if bytes<threshold then return end
				if Hub.reportIncomingSignalPayload then Hub.reportIncomingSignalPayload(bytes,remote.Name,sender) end
				if os.clock()<nextAlert then return end
				nextAlert=os.clock()+cooldown
				lastReport=diagnostic(remote,args,bytes,sender,truncated)
				print(lastReport)
				local name=remote.Name:sub(1,80)
				local amount=string.format("%s%.2f MiB of string/buffer data",truncated and "at least " or "",bytes/1048576)
				local message=(sender and sender.Name or "N/A")..", "..amount..", remote: "..name.."."
				notify("Large incoming payload",message,6)
				status:SetText(string.format("Watching %d remotes, last alert %.2f MiB of string/buffer data.",remoteCount,bytes/1048576))
			end)
			if not ok then return end
			watched[remote]=true;remoteCount+=1
			local destroying
			destroying=track(remote.Destroying,function()
				if watched[remote] then watched[remote]=nil;remoteCount-=1 end
				incoming:Disconnect();Hub.connections[incoming]=nil
				listeners[incoming]=nil
				destroying:Disconnect();Hub.connections[destroying]=nil
				listeners[destroying]=nil
			end)
		end
		local function start()
			stop()
			if not enabled then status:SetText("Incoming payload monitor is off.");return end
			local ticket=generation
			-- Listen first so new remotes aren't missed during initial discovery.
			track(game.DescendantAdded,watch)
			discovering=true
			status:SetText("Discovering incoming remotes...")
			local uiElapsed=0
			track(RunService.Heartbeat,function(dt)
				uiElapsed+=dt
				if uiElapsed<1 then return end
				uiElapsed=0
				status:SetText(string.format("%s%d remotes, %d events received, largest inspected %.1f KiB.",
					discovering and "Scanning, " or "Watching ",remoteCount,received,largest/1024))
			end)
			task.spawn(function()
				local queue={}
				local head,tail=1,0
				tail=1;queue[tail]=game
				while head<=tail and enabled and Hub.alive and generation==ticket do
					local deadline=os.clock()+0.001
					local processed=0
					repeat
						local item=queue[head];queue[head]=nil;head+=1
						if item and (item==game or item.Parent) then
							watch(item)
							-- Some engine services cannot be enumerated by a client.
							local ok,children=pcall(function() return item:GetChildren() end)
							if ok then for _,child in ipairs(children) do tail+=1;queue[tail]=child end end
						end
						processed+=1
					until head>tail or processed>=128 or os.clock()>=deadline
					RunService.Heartbeat:Wait()
				end
				if enabled and Hub.alive and generation==ticket then
					discovering=false
					status:SetText(string.format("Watching %d remotes, %d events received.",remoteCount,received))
				end
			end)
		end
		group:AddToggle("IncomingPayloadMonitor",{Text="Large incoming payload alerts",Default=false,
			Callback=function(value) enabled=value;start() end})
		group:AddSlider("IncomingPayloadThreshold",{Text="String/buffer alert threshold (KiB)",Default=256,Min=1,Max=4096,Rounding=0,
			Callback=function(value) threshold=value*1024 end})
		group:AddSlider("IncomingPayloadCooldown",{Text="Alert cooldown (seconds)",Default=8,Min=2,Max=60,Rounding=0,
			Callback=function(value) cooldown=value end})
		group:AddButton({Text="Print last payload diagnostic",Func=function()
			if lastReport then print(lastReport)
			else notify("Payload monitor","No oversized incoming payload has been recorded this session.",5) end
		end})
		group:AddButton({Text="Capture next incoming event",Func=function()
			if not enabled then notify("Payload monitor","Enable the monitor first.",4);return end
			captureNext=true
			notify("Payload monitor","Waiting for one incoming RemoteEvent, even below the alert threshold.",5)
		end})
		Hub.cleanup(function() enabled=false;stop() end)
	end)()
end

-- A saved destination is explicit, it does not grant server-side safe-zone status.
do
	(function()
		local group=Tabs.Defense:AddRightGroupbox("Safe Zone")
		local destination=Vector3.new(606,124,-101)
		local spawnEnabled,loopEnabled=false,false
		local loopConnection
		local epoch=0
		local status=group:AddLabel("Safe zone: 606, 124, -101. Use my current position to change it.")
		local function setDestination(text)
			local x,y,z=tostring(text or ""):match("^%s*([%+%-%.%deE]+)%s*,%s*([%+%-%.%deE]+)%s*,%s*([%+%-%.%deE]+)%s*$")
			x,y,z=tonumber(x),tonumber(y),tonumber(z)
			if not x or not y or not z or x~=x or y~=y or z~=z or math.abs(x)>1000000 or math.abs(y)>1000000 or math.abs(z)>1000000 then
				destination=nil;status:SetText("Set a safe zone using your current position or enter X, Y, Z.");return
			end
			if y<=Workspace.FallenPartsDestroyHeight+8 then destination=nil;status:SetText("Safe zone rejected, destination is below the map.");return end
			destination=Vector3.new(x,y,z)
			status:SetText(string.format("Saved safe zone: %.1f, %.1f, %.1f",x,y,z))
		end
		local function go(char)
			if not destination or char~=Player.Character then return false end
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health<=0 then return false end
			Hub.teleportPart(root, CFrame.new(destination)*Hub.teleportFrame(root).Rotation)
			root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
			return true
		end
		group:AddInput("SafeZoneCoordinates",{Text="Saved destination (X, Y, Z)",Default="606, 124, -101",Finished=true,Callback=setDestination})
		group:AddButton({Text="Use my current position",Func=function()
			local char=Player.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			if not root then return end
			local p=Hub.teleportFrame(root).Position
			Options.SafeZoneCoordinates:SetValue(string.format("%.3f, %.3f, %.3f",p.X,p.Y,p.Z))
			Hub.requestSave()
		end})
		group:AddButton({Text="Go to safe zone now",Func=function()
			if not go(Player.Character) then notify("Safe zone","Set a destination and wait for your character to be ready.",4) end
		end})
		group:AddToggle("SpawnAtSafeZone",{Text="Spawn at safe zone",Default=false,Callback=function(on) spawnEnabled=on;epoch+=1;Hub.requestSave() end})
		group:AddToggle("LoopSafeZone",{Text="Loop go to safe zone (10/sec)",Default=false,Callback=function(on)
			loopEnabled=on;Hub.safeZoneLoopActive=on
			if loopConnection then loopConnection:Disconnect();Hub.connections[loopConnection]=nil;loopConnection=nil end
			Hub.requestSave()
			if not on then return end
			local elapsed=0
			loopConnection=Hub.connect(RunService.Heartbeat,function(dt)
				elapsed+=dt
				if elapsed<0.1 then return end
				elapsed=0 -- No burst of catch-up teleports after a lag spike.
				go(Player.Character)
			end)
			if not destination then notify("Safe zone","Choose Use my current position before the loop can move you.",5) end
		end})
		Hub.connect(Player.CharacterAdded,function(char)
			epoch+=1;local ticket=epoch
			if not spawnEnabled then return end
			task.spawn(function()
				local deadline=os.clock()+8
				repeat
					if not Hub.alive or not spawnEnabled or epoch~=ticket or Player.Character~=char then return end
					if go(char) then return end
					task.wait(0.1)
				until os.clock()>=deadline
			end)
		end)
		Hub.connect(Player.CharacterRemoving,function() epoch+=1 end)
		Hub.cleanup(function()
			spawnEnabled=false;loopEnabled=false;epoch+=1;Hub.safeZoneLoopActive=nil
			if loopConnection then loopConnection:Disconnect();Hub.connections[loopConnection]=nil;loopConnection=nil end
		end)
	end)()
end


-- utility ports: reversible local presentation and named-toy audio filters.
do
	(function()
		local group=Tabs.Visual:AddRightGroupbox("Lighting")
		local lighting=game:GetService("Lighting")
		local owned={}
		local gravityOn,gravityValue,timeOn,timeValue,syncTime=false,196.2,false,14,false
		local function restore(key)
			local records=owned[key];owned[key]=nil
			for _,record in ipairs(records or {}) do
				pcall(function()
					if record.object[record.property]==record.applied then record.object[record.property]=record.original end
				end)
			end
		end
		local function set(key,object,property,value)
			owned[key]=owned[key] or {}
			local record
			for _,entry in ipairs(owned[key]) do if entry.object==object and entry.property==property then record=entry;break end end
			if not record then record={object=object,property=property,original=object[property]};table.insert(owned[key],record) end
			object[property]=value;record.applied=value
		end
		PlayerView:AddToggle("ToolGravity",{Text="Custom gravity",Default=false,Callback=function(on)
			gravityOn=on;if on then set("gravity",Workspace,"Gravity",gravityValue) else restore("gravity") end
		end})
		PlayerView:AddSlider("ToolGravityValue",{Text="Gravity",Default=196.2,Min=0,Max=400,Rounding=1,Callback=function(value)
			gravityValue=value;if gravityOn then set("gravity",Workspace,"Gravity",value) end
		end})
		group:AddToggle("ToolFullBright",{Text="Full Bright",Default=false,Callback=function(on)
			if on then
				set("bright",lighting,"Brightness",2)
				set("bright",lighting,"Ambient",Color3.fromRGB(128,128,128))
				set("bright",lighting,"OutdoorAmbient",Color3.fromRGB(128,128,128))
			else restore("bright") end
		end})
		group:AddToggle("ToolTimeOverride",{Text="Override sun position (time of day)",Default=false,Callback=function(on)
			timeOn=on
			if on then set("time",lighting,"ClockTime",timeValue)
			else
				syncTime=false
				if Toggles.ToolSyncTime and Toggles.ToolSyncTime.Value then Toggles.ToolSyncTime:SetValue(false) end
				restore("time")
			end
		end})
		group:AddSlider("ToolTimeOfDay",{Text="Sun position / time of day",Default=14,Min=0,Max=24,Rounding=1,Callback=function(value)
			timeValue=value;if timeOn and not syncTime then set("time",lighting,"ClockTime",value) end
		end})
		group:AddToggle("ToolSyncTime",{Text="Sync override to UTC",Default=false,Callback=function(on)
			syncTime=on
			if on then
				if Toggles.ToolTimeOverride then Toggles.ToolTimeOverride:SetValue(true) end
			elseif timeOn then set("time",lighting,"ClockTime",timeValue) end
		end})
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt)
			elapsed+=dt;if elapsed<1 then return end;elapsed=0
			if timeOn and syncTime then
				local utc=os.date("!*t")
				set("time",lighting,"ClockTime",utc.hour+utc.min/60+utc.sec/3600)
			end
		end)
		PlayerView:AddToggle("ToolFirstPerson",{Text="First person",Default=false,Callback=function(on)
			if on then set("camera",Player,"CameraMode",Enum.CameraMode.LockFirstPerson) else restore("camera") end
		end})
		Hub.cleanup(function() gravityOn,timeOn,syncTime=false,false,false;for key in pairs(owned) do restore(key) end end)
	end)();
	(function()
		local group=Tabs.Sound:AddRightGroupbox("Toy Audio")
		local boombox,jukebox=false,false
		local saved={};local watcher;local epoch=0
		local function matches(sound)
			if not sound:IsA("Sound") then return false end
			local parent=sound.Parent
			while parent and parent~=Workspace do
				if boombox and parent.Name=="Boombox" then return true end
				if jukebox and (parent.Name=="Jukebox" or parent.Name=="JukeboxOrange" or parent.Name=="JukeboxBlue") then return true end
				parent=parent.Parent
			end
			return false
		end
		local function restore(sound)
			local record=saved[sound];if not record then return end
			saved[sound]=nil
			record.connection:Disconnect();Hub.connections[record.connection]=nil
			pcall(function() if sound.Parent and sound.Volume==0 then sound.Volume=record.volume end end)
		end
		local function inspect(sound)
			if not matches(sound) then return end
			if not saved[sound] then
				local record={volume=sound.Volume};saved[sound]=record
				record.connection=Hub.connect(sound:GetPropertyChangedSignal("Volume"),function()
					if saved[sound]==record and matches(sound) and sound.Volume~=0 then sound.Volume=0 end
				end)
			end
			sound.Volume=0
		end
		local function refresh()
			epoch+=1;local ticket=epoch
			if watcher then watcher:Disconnect();Hub.connections[watcher]=nil;watcher=nil end
			for sound in pairs(saved) do if not matches(sound) then restore(sound) end end
			if boombox or jukebox then
				watcher=Hub.connect(Workspace.DescendantAdded,inspect)
				Hub.scanDescendants(Workspace,inspect,function() return epoch==ticket and (boombox or jukebox) end)
			end
		end
		group:AddToggle("ToolMuteBoombox",{Text="Mute boomboxes",Default=false,Callback=function(on) boombox=on;refresh() end})
		group:AddToggle("ToolMuteJukebox",{Text="Mute jukeboxes",Default=false,Callback=function(on) jukebox=on;refresh() end})
		Hub.cleanup(function() boombox,jukebox=false,false;epoch+=1;for sound in pairs(saved) do restore(sound) end end)
	end)()
end
-- End  utility ports

-- Plot-barrier snowball sequence.
do
	(function()
		local group=Tabs.Player:AddRightGroupbox("Plot Barriers")
		local busy=false
		local HOption={breakBarriers=false}
		local activeConnection
		local saved={}
		local function restore()
			for part,old in pairs(saved) do pcall(function() if part.Parent then part.CanCollide=old end end) end
			table.clear(saved)
		end
		local function cancel()
			HOption.breakBarriers=false
			if activeConnection then activeConnection:Disconnect();Hub.connections[activeConnection]=nil;activeConnection=nil end
		end
		function Hub.breakPlotBarriers()
			if busy or not Hub.alive then return false end
			local LocalPlayer=Player
			local SpawnedInToys=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			local menu=ReplicatedStorage:FindFirstChild("MenuToys")
			local SpawnToyRF=menu and menu:FindFirstChild("SpawnToyRemoteFunction")
			if not SpawnedInToys or not SpawnToyRF or not Workspace:FindFirstChild("Plots") then
				notify("Plot barriers","Toys, plots or spawn remote are not ready.",3);return false
			end
			local function getRoot()
				local char=LocalPlayer.Character
				return char and char:FindFirstChild("HumanoidRootPart")
			end
			local OrionLib={MakeNotification=function(_,info) notify(info.Name,info.Content,info.Time) end}
			-- BEGIN supplied barrier spawn helper
			local function spawnToy(name, cframe)
				if not LocalPlayer.Character then return nil end
				local root = getRoot()
				if not root then return nil end
				local cf = cframe or (Hub.teleportFrame(root) * CFrame.new(0, 5, 0))
				SpawnToyRF:InvokeServer(name, cf, Vector3.zero)
				task.wait(0.3)
				for _, v in pairs(SpawnedInToys:GetChildren()) do
					if v.Name == name then
						return v
					end
				end
				return nil
			end
			-- END supplied barrier spawn helper
			busy=true
			task.spawn(function()
				local ok,err=xpcall(function()
					-- BEGIN supplied barrier action
					HOption.breakBarriers = true
					local pos = Vector3.new(263.4, -4.79, 466.8)
					local spawnPos = CFrame.new(263.5, -4.5, 486.9)
					local conn
					conn = Workspace.ChildAdded:Connect(function(child)
						if HOption.breakBarriers and child.Name == "Part" and (child.Position - pos).Magnitude <= 2 then
							HOption.breakBarriers = false
							conn:Disconnect()
							for _, plot in pairs(Workspace.Plots:GetChildren()) do
								local barrier = plot:FindFirstChild("Barrier")
								if barrier then
									for _, part in pairs(barrier:GetChildren()) do
										if part:IsA("BasePart") then
											if saved[part]==nil then saved[part]=part.CanCollide end
											part.CanCollide = false
										end
									end
								end
							end
							OrionLib:MakeNotification({Name = "Success", Content = "Barriers destroyed!", Time = 3})
						end
					end)
					activeConnection=conn
					Hub.connections[conn]=true
					for i = 1, 10 do
						if not HOption.breakBarriers then break end
						spawnToy("BallSnowball", spawnPos)
						task.wait(1)
					end
					if HOption.breakBarriers then
						HOption.breakBarriers = false
						conn:Disconnect()
						OrionLib:MakeNotification({Name = "Failed", Content = "Could not destroy barriers", Time = 3})
					end
					-- END supplied barrier action
				end,debug.traceback)
				cancel();busy=false
				if not ok and Hub.alive then notify("Plot barriers",tostring(err),4) end
			end)
			return true
		end
		group:AddButton({Text="Break House Barriers",Func=Hub.breakPlotBarriers})
		group:AddButton({Text="Restore plot barriers",Func=function() cancel();restore() end})
		Hub.cleanup(function() cancel();restore();Hub.breakPlotBarriers=nil end)
	end)()
end
-- End plot-barrier sequence

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
		local function gucciEnabled()
			local toggle=Toggles.AutoGucciBlobToggle
			return toggle and toggle.Value==true
		end
		local function selfRoot()
			local char=Player.Character
			local root,hum
			if gucciEnabled() then
				local controller,proof=Hub.sourceGucci,Hub.gucciVerifiedRun
				if not char or not controller or not controller.state.GucciAntiGrab or not proof or not proof.Confirmed
					or proof.Char~=char or not proof.Hum or proof.Hum.Parent~=char
					or not proof.HRP or proof.HRP.Parent~=char or not proof.HRP:IsA("BasePart") then return end
				root,hum=proof.HRP,proof.Hum
			else
				root=char and char:FindFirstChild("HumanoidRootPart")
				hum=char and char:FindFirstChildOfClass("Humanoid")
			end
			local held=Player:FindFirstChild("IsHeld")
			if not root or not hum or hum.Health<=0 or hum.SeatPart or root.Anchored
				or (held and held.Value) or Hub.safeZoneLoopActive or Hub.blobFlightActive or Hub.characterFlightActive then return end
			for _,run in pairs(Hub.targetLoopRuns or {}) do if run.enabled then return end end
			return root,char,hum
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
			if Hub.interactionVisitLock==ticket then Hub.interactionVisitLock=nil end
			local root,hum=ticket.root,ticket.hum
			-- Return even if Gucci lost confirmation during the interaction; never move a new character.
			if ticket.moved and Player.Character==ticket.char and root.Parent==ticket.char
				and hum.Parent==ticket.char and hum.Health>0 and not hum.SeatPart and not root.Anchored then
				local ok,err=pcall(function()
					Hub.teleportPart(root, ticket.original)
					root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
				end)
				if not ok then warn("[Plots & slots return] "..tostring(err)) end
			end
		end
		Hub.teleportMaskCancelers.PlotsSlots=function() if active then finish(active) end end
		local function visit(kind,part,allowed,action)
			if active or Hub.interactionVisitLock then return false,"Another movement interaction is running." end
			local char=Player.Character
			local root
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not char or not hum or hum.Health<=0 then return false,"Waiting for a live character." end
			if not part or not part.Parent or not part:IsA("BasePart") then return false,"Interaction part has not loaded." end
			local ticket={kind=kind,char=char,gucci=gucciEnabled()}
			active=ticket;Hub.interactionVisitLock=ticket
			status:SetText(kind..(ticket.gucci and ": waiting for verified Gucci confirmation." or ": preparing visit."))
			task.spawn(function()
				local function pending()
					return Hub.alive and active==ticket and allowed() and Player.Character==char
						and hum.Parent==char and hum.Health>0 and part.Parent
						and (not ticket.gucci or gucciEnabled())
				end
				local function valid()
					return pending() and selfRoot()==root and (Hub.teleportFrame(root).Position-ticket.destination).Magnitude<12
				end
				local ok,err=pcall(function()
					local deadline=os.clock()+20
					while pending() do
						local readyRoot,readyChar,readyHum=selfRoot()
						if readyRoot and readyChar==char then root,hum=readyRoot,readyHum;break end
						if not ticket.gucci then error("Character busy: leave seats/holds and stop flight, safe-zone or action loops.",0) end
						if os.clock()>=deadline then error("Gucci confirmation timed out; no interaction performed.",0) end
						task.wait(0.1)
					end
					if not root or not pending() or selfRoot()~=root then return end
					-- Capture the confirmed live root and its return position only after readiness succeeds.
					ticket.root,ticket.hum,ticket.original=root,hum,Hub.teleportFrame(root)
					local destination=(Hub.teleportFrame(root).Position-part.Position).Magnitude>25 and part.Position+Vector3.new(0,3,6) or Hub.teleportFrame(root).Position
					if kind=="House renewal" then destination=part.Position+Vector3.new(0,3,0) end
					for _,value in ipairs({destination.X,destination.Y,destination.Z}) do
						if value~=value or math.abs(value)==math.huge then error("Invalid interaction position.",0) end
					end
					if destination.Y<=Workspace.FallenPartsDestroyHeight+8 then error("Destination is below the safe map height.",0) end
					ticket.destination=destination;ticket.moved=true
					status:SetText(kind..": visiting; will return when finished.")
					Hub.teleportPart(root, CFrame.new(destination)*Hub.teleportFrame(root).Rotation)
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
			local aim=Hub.safeLookAt(Hub.teleportFrame(root).Position+Vector3.new(0,1.593,0),part.Position)
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
		local winnings=group:AddLabel("Slot winnings: no spin result yet.")
		local resultGeneration=0
		local function slotCoinAmount(slot)
			local screen=slot:FindFirstChild("Screen")
			local gui=screen and screen:FindFirstChild("SlotGui")
			local frame=gui and gui:FindFirstChild("CoinsFrame")
			local label=frame and frame:FindFirstChild("CoinAmount")
			if not label or not (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then return end
			local text=tostring(label.Text):gsub("<[^>]->","")
			-- Read the complete displayed award, including thousands separators.
			local digits=text:match("([%d][%d,]*)%s*[Cc][Oo][Ii][Nn][Ss]?[%s!%.]*$")
				or text:match("([%d][%d,]*)[%s!]*$")
			local amount=digits and tonumber((digits:gsub(",","")))
			if amount and amount>=0 and amount<math.huge then return amount,text end
			return nil,text
		end
		local function watchSlotWinnings(slot)
			resultGeneration+=1;local ticket=resultGeneration
			winnings:SetText("Slot winnings: waiting for the result…")
			task.spawn(function()
				local started=os.clock();local changedAt=started;local previous
				while Hub.alive and ticket==resultGeneration and slot.Parent and os.clock()-started<6 do
					local amount,text=slotCoinAmount(slot)
					if text~=previous then previous=text;changedAt=os.clock() end
					-- Match the original's result delay, allowing animated text to settle.
					if amount and os.clock()-started>=1 and os.clock()-changedAt>=0.35 then
						local message="You won "..string.format("%.0f",amount).." coins!"
						winnings:SetText("Slot winnings: "..message)
						notify("Slot winnings",message,6,"success")
						return
					end
					task.wait(0.1)
				end
				if Hub.alive and ticket==resultGeneration then winnings:SetText("Slot winnings: result display unavailable.") end
			end)
		end
		local function spin(automatic)
			if active or Hub.interactionVisitLock then return false,"Another movement interaction is running." end
			-- Rank machines without selecting a visit root before Gucci confirmation.
			local char=Player.Character
			if not char then return false,"Waiting for a live character." end
			local position=char:GetPivot().Position
			local slots=Workspace:FindFirstChild("Slots");if not slots then return false,"Slot machines have not loaded." end
			local best,distance
			for _,slot in ipairs(slots:GetChildren()) do
				local holder=slot:FindFirstChild("SlotHandle")
				local handle=holder and holder:FindFirstChild("Handle")
				if slotState(slot,slots)==true and handle and handle:IsA("BasePart") and os.clock()-(slotAttempts[slot] or -math.huge)>=6 then
					local range=(position-handle.Position).Magnitude
					if not distance or range<distance then best={slot=slot,handle=handle};distance=range end
				end
			end
			if not best then return false,"No ready slot machine yet; waiting for cooldown/loading." end
			slotAttempts[best.slot]=os.clock()
			return visit("Slot spin",best.handle,function() return not automatic or slotOn end,function(ownRoot,valid)
				local requested=false
				local function accepted()
					if requested then
						status:SetText("Slots: spin accepted. Returning while the result loads.")
						watchSlotWinnings(best.slot)
					else status:SetText("Slots: machine became busy before our request. Returning.") end
				end
				for _=1,10 do
					if not valid() then return end
					local ready=best.slot.Parent and slotState(best.slot,slots)
					if ready==false then accepted();return end
					if not request(best.handle,ownRoot) then status:SetText("Slots: ownership remote unavailable; returning.");return end
					requested=true
					task.wait(0.2)
				end
				local ready=best.slot.Parent and slotState(best.slot,slots)
				if ready==false then accepted() else status:SetText("Slots: request not confirmed. Returned; will try another available machine.") end
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
		Hub.connect(Player.CharacterRemoving,function() if active and Hub.interactionVisitLock==active then Hub.interactionVisitLock=nil end;active=nil end)
		Hub.cleanup(function() resultGeneration+=1;slotOn=false;houseOn=false;claimOn=false;if active then finish(active) end;Hub.sampleToolAutomation=nil end)
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
-- Local presentation tools inspired by the supplied code’s Perspective settings.
do
	(function()
		local group=Tabs.Visual:AddRightGroupbox("Camera Effects")
		local preset,strength="Off",50
		local gui,effect,overlay
		local disposed=false
		local function clear()
			if overlay then Hub.instances[overlay]=nil;Hub.assetTargets[overlay]=nil end
			if gui then Hub.instances[gui]=nil;Hub.assetTargets[gui]=nil;gui:Destroy() end
			if effect then Hub.instances[effect]=nil;Hub.assetTargets[effect]=nil;effect:Destroy() end
			gui,effect,overlay=nil,nil,nil
		end
		local function apply()
			if disposed or preset=="Off" then clear();return end
			local playerGui=Player:FindFirstChildOfClass("PlayerGui")
			if not playerGui then return end
			if not gui or not gui.Parent or not effect or not effect.Parent then
				clear()
				gui=Hub.new("ScreenGui",playerGui)
				gui.Name="ArrivaCameraEffects";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=-10
				overlay=Hub.new("ImageLabel",gui)
				overlay.Size=UDim2.fromScale(1,1);overlay.BackgroundTransparency=1;overlay.BorderSizePixel=0
				overlay.Active=false;overlay.ImageColor3=Color3.new(0,0,0)
				effect=Hub.new("ColorCorrectionEffect",game:GetService("Lighting"))
			end
			overlay.Image=preset=="Old TV" and "rbxassetid://8586979842" or "rbxassetid://5945121255"
			overlay.ImageTransparency=1-strength/100*0.6
			effect.Name="ArrivaCameraColor";effect.Saturation=-(preset=="Old TV" and 0.3 or 0.6)*strength/100
		end
		group:AddDropdown("LocalCameraEffect",{Text="Camera effect",Values={"Off","Vignette","Old TV"},Default=1,
			Callback=function(value) preset=value;apply() end})
		group:AddSlider("LocalCameraEffectStrength",{Text="Effect strength (%)",Default=50,Min=0,Max=100,Rounding=0,
			Callback=function(value) strength=value;apply() end})
		Hub.connect(Player.ChildAdded,function(child) if child:IsA("PlayerGui") then apply() end end)
		Hub.cleanup(function() disposed=true;clear() end)
	end)()
end


-- BEGIN PRIVATE SAFE FEATURE ADAPTER
-- Independently adapted local features. No external loader or remote calls.
do
	(function()
		local lighting=game:GetService("Lighting")
		local visual=Tabs.Visual:AddRightGroupbox("Local appearance extras")
		local defense=Tabs.Defense:AddRightGroupbox("Local hazard filters")
		local states={}
		local snapshots={}
		local watches={}
		local disposed=false
		local scanning=false
		local epoch=0
		local color=Color3.fromRGB(120,190,255)
		local crossSize,particleRate,particleSize=18,12,0.3
		local crossGui,crossLabel,crossImage,hat,attachment,emitter
		local crossAsset=""
		local particleTexture="rbxasset://textures/particles/sparkles_main.dds"
		local particleSpeed=2
		local function forget(instance)
			for _,connection in ipairs(watches[instance] or {}) do connection:Disconnect();Hub.connections[connection]=nil end
			watches[instance]=nil
		end
		local function restore(instance)
			forget(instance)
			local saved=snapshots[instance]
			snapshots[instance]=nil
			if saved then for property,value in pairs(saved) do pcall(function() instance[property]=value end) end end
		end
		local function override(instance,property,value)
			local saved=snapshots[instance]
			if not saved then saved={};snapshots[instance]=saved end
			if saved[property]==nil then saved[property]=instance[property] end
			if instance[property]~=value then instance[property]=value end
			watches[instance]=watches[instance] or {}
			local list=watches[instance]
			list.keys=list.keys or {}
			if not list.keys[property] then
				list.keys[property]=true
				table.insert(list,Hub.connect(instance:GetPropertyChangedSignal(property),function()
					if snapshots[instance] and not disposed and instance[property]~=value then instance[property]=value end
				end))
			end
		end
		local function isPoison(part)
			if not part:IsA("BasePart") or (part.Name~="PoisonHurtPart" and part.Name~="PaintPlayerPart") then return false end
			local parent=part.Parent
			return parent and (parent.Name=="PoisonBigHole" or parent.Name=="PoisonSmallHole")
		end
		local function apply(instance)
			if disposed or not instance.Parent then return end
			if instance:IsA("Sound") then
				local parent=instance.Parent
				local ambient=false
				local ancestor=parent
				while ancestor and ancestor~=Workspace do if ancestor.Name=="MapNoises" then ambient=true;break end;ancestor=ancestor.Parent end
				if (states.ambience and ambient) or (states.screams and instance.Name=="Scream" and parent and parent.Name=="HumanoidRootPart")
					or (states.soundwaves and instance.Name=="SineWave") or (states.rhythm and instance.Name:lower():match("^sound[1-8]$"))
					or (states.instruments and parent and parent.Name=="MusicPart")
					or (states.explosions and parent and parent:IsA("BasePart") and parent.Name=="Part" and parent.Parent==Workspace) then override(instance,"Volume",0) end
			end
			if states.poison and isPoison(instance) then override(instance,"CanTouch",false) end
			if states.blur and instance:IsA("BlurEffect") then override(instance,"Enabled",false) end
			if states.particles and (instance:IsA("ParticleEmitter") or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles")) and instance~=emitter then
				override(instance,"Enabled",false)
			end
			if states.trails and instance:IsA("Trail") then override(instance,"Enabled",false) end
			if states.decals and (instance:IsA("Decal") or instance:IsA("Texture")) then override(instance,"Transparency",1) end
			if states.material and instance:IsA("BasePart") and not instance:IsDescendantOf(Player.Character or lighting) and instance~=hat then
				override(instance,"Material",Enum.Material.SmoothPlastic)
			end
			if states.character and Player.Character and instance:IsDescendantOf(Player.Character) and instance:IsA("BasePart") then
				override(instance,"Material",Enum.Material.ForceField)
			end
		end
		local function rescan()
			epoch+=1
			local current=epoch
			for instance in pairs(snapshots) do restore(instance) end
			local roots={Workspace,lighting}
			if not next(states) then return end
			task.spawn(function()
				scanning=true
				for _,root in ipairs(roots) do
					local objects=root:GetDescendants()
					for i,instance in ipairs(objects) do
						if disposed or current~=epoch then return end
						apply(instance)
						if i%150==0 then task.wait() end
					end
				end
				scanning=false
			end)
		end
		local function setState(key,on)
			states[key]=on and true or nil
			rescan();Hub.requestSave()
		end
		local function toggle(group,id,text,key)
			group:AddToggle(id,{Text=text,Default=false,Callback=function(on) setState(key,on) end})
		end
		toggle(defense,"PrivatePoisonTouch","Ignore poison touch locally","poison")
		defense:AddLabel("Local touch filtering cannot block server-enforced damage.")
		toggle(visual,"PrivateDisableBlur","Disable blur effects","blur")
		toggle(visual,"PrivateHideParticles","Hide world particles, fire and smoke","particles")
		toggle(visual,"PrivateHideTrails","Hide trails","trails")
		toggle(visual,"PrivateHideDecals","Hide world decals and textures","decals")
		toggle(visual,"PrivateSimpleMaterials","Simple world materials","material")
		toggle(visual,"PrivateForcefieldCharacter","Forcefield character appearance","character")
		local audio=Tabs.Sound:AddRightGroupbox("Game Sound Filters")
		toggle(audio,"PrivateMuteAmbience","Mute ambience","ambience")
		toggle(audio,"PrivateMuteScreams","Mute screams","screams")
		toggle(audio,"PrivateMuteSoundwaves","Mute soundwaves","soundwaves")
		toggle(audio,"PrivateMuteRhythm","Mute rhythm makers","rhythm")
		toggle(audio,"PrivateMuteInstruments","Mute instruments","instruments")
		toggle(audio,"PackMuteExplosions","Mute explosions","explosions")
		local shadowOriginal
		visual:AddToggle("PrivateNoShadows",{Text="Disable global shadows",Default=false,Callback=function(on)
			if on then
				if shadowOriginal==nil then shadowOriginal=lighting.GlobalShadows end
				lighting.GlobalShadows=false
			elseif shadowOriginal~=nil then lighting.GlobalShadows=shadowOriginal;shadowOriginal=nil end
			Hub.requestSave()
		end})
		local function destroy(instance)
			if instance then Hub.instances[instance]=nil;Hub.assetTargets[instance]=nil;instance:Destroy() end
		end
		local function cosmetics()
			destroy(hat);destroy(attachment);hat,attachment,emitter=nil,nil,nil
			local char=Player.Character
			local head=char and char:FindFirstChild("Head")
			local root=char and char:FindFirstChild("HumanoidRootPart")
			if states.hat and head then
				hat=Hub.new("Part",Workspace.CurrentCamera)
				hat.Name="ArrivaLocalConeHat";hat.Size=Vector3.new(3,0.7,3)
				hat.Anchored=true;hat.CanCollide=false;hat.CanTouch=false;hat.CanQuery=false;hat.CastShadow=false
				hat.Color=color;hat.Material=Enum.Material.Neon;hat.Transparency=0.35
				local mesh=Hub.new("SpecialMesh",hat);mesh.MeshType=Enum.MeshType.FileMesh;mesh.MeshId="rbxassetid://1778999"
				mesh.Scale=Vector3.new(3,0.7,3)
			end
			if states.cosmeticParticles and root then
				attachment=Hub.new("Attachment",root);attachment.Name="ArrivaLocalParticles"
				emitter=Hub.new("ParticleEmitter",attachment)
				emitter.Texture=particleTexture
				emitter.Rate=particleRate;emitter.Lifetime=NumberRange.new(1,2);emitter.Speed=NumberRange.new(0,particleSpeed)
				emitter.Size=NumberSequence.new(particleSize);emitter.Color=ColorSequence.new(color)
				emitter.LightEmission=0.6;emitter.SpreadAngle=Vector2.new(180,180)
			end
		end
		visual:AddToggle("PrivateConeHat",{Text="Local cone hat",Default=false,Callback=function(on) states.hat=on and true or nil;cosmetics();Hub.requestSave() end})
		visual:AddToggle("PrivateCharacterParticles",{Text="Local character particles",Default=false,Callback=function(on) states.cosmeticParticles=on and true or nil;cosmetics();Hub.requestSave() end})
		visual:AddSlider("PrivateParticleRate",{Text="Particle rate",Default=12,Min=1,Max=50,Rounding=0,Callback=function(value) particleRate=value;if emitter then emitter.Rate=value end;Hub.requestSave() end})
		visual:AddSlider("PrivateParticleSize",{Text="Particle size",Default=0.3,Min=0.1,Max=2,Rounding=1,Callback=function(value) particleSize=value;if emitter then emitter.Size=NumberSequence.new(value) end;Hub.requestSave() end})
		local function crosshair()
			if not states.crosshair then destroy(crossGui);crossGui,crossLabel,crossImage=nil,nil,nil;return end
			local parent=Player:FindFirstChildOfClass("PlayerGui")
			if not parent then return end
			if not crossGui or not crossGui.Parent then
				crossGui=Hub.new("ScreenGui",parent);crossGui.Name="ArrivaLocalCrosshair";crossGui.ResetOnSpawn=false;crossGui.IgnoreGuiInset=true
				crossLabel=Hub.new("TextLabel",crossGui);crossLabel.BackgroundTransparency=1;crossLabel.AnchorPoint=Vector2.new(0.5,0.5)
				crossLabel.Font=Enum.Font.GothamBold;crossLabel.Text="+";crossLabel.TextStrokeTransparency=0.4;crossLabel.Active=false
				crossImage=Hub.new("ImageLabel",crossLabel);crossImage.BackgroundTransparency=1;crossImage.Size=UDim2.fromScale(1,1);crossImage.Active=false
			end
			crossLabel.Size=UDim2.fromOffset(crossSize*2,crossSize*2);crossLabel.TextSize=crossSize;crossLabel.TextColor3=color
			crossLabel.Text=crossAsset=="" and "+" or ""
			crossImage.Image=crossAsset;crossImage.ImageColor3=color;crossImage.Visible=crossAsset~=""
		end
		visual:AddToggle("PrivateCrosshair",{Text="Custom crosshair",Default=false,Callback=function(on) states.crosshair=on and true or nil;crosshair();Hub.requestSave() end})
		visual:AddSlider("PrivateCrosshairSize",{Text="Crosshair size",Default=18,Min=8,Max=128,Rounding=0,Callback=function(value) crossSize=value;crosshair();Hub.requestSave() end})
		local function asset(value)
			local text=tostring(value):match("^%s*(.-)%s*$")
			if text=="" then return "" end
			local id=text:match("^(%d+)$") or text:match("^rbxassetid://(%d+)$") or text:match("[?&]id=(%d+)") or text:match("roblox.com/library/(%d+)")
			if id then return "rbxassetid://"..id end
		end
		visual:AddInput("PackCrosshairImage",{Text="Crosshair image ID",Default="",Finished=true,Callback=function(value)
			local resolved=asset(value);if resolved then crossAsset=resolved;crosshair() end
		end})
		visual:AddInput("PackParticleTexture",{Text="Particle texture ID",Default="",Finished=true,Callback=function(value)
			local resolved=asset(value);if resolved and resolved~="" then particleTexture=resolved;if emitter then emitter.Texture=resolved end end
		end})
		visual:AddSlider("PackParticleMaxSpeed",{Text="Particle max speed",Default=2,Min=0,Max=30,Rounding=1,Callback=function(value) particleSpeed=value;if emitter then emitter.Speed=NumberRange.new(0,value) end end})
		visual:AddDropdown("PrivateCosmeticColor",{Text="Cosmetic colour",Values={"Blue","White","Pink","Green","Orange","Purple"},Default=1,Callback=function(value)
			local palette={Blue=Color3.fromRGB(120,190,255),White=Color3.fromRGB(255,255,255),Pink=Color3.fromRGB(255,120,190),Green=Color3.fromRGB(120,255,160),Orange=Color3.fromRGB(255,170,80),Purple=Color3.fromRGB(190,120,255)}
			color=palette[value] or color;if hat then hat.Color=color end;if emitter then emitter.Color=ColorSequence.new(color) end;crosshair();Hub.requestSave()
		end})
		Hub.connect(Workspace.DescendantAdded,function(instance) if next(states) then task.defer(function() apply(instance) end) end end)
		Hub.connect(lighting.DescendantAdded,function(instance) if next(states) then apply(instance) end end)
		Hub.connect(Workspace.DescendantRemoving,function(instance) if snapshots[instance] then restore(instance) end end)
		Hub.connect(Player.CharacterAdded,function(char)
			task.spawn(function()
				char:WaitForChild("HumanoidRootPart",5)
				if disposed or Player.Character~=char then return end
				cosmetics();rescan()
			end)
		end)
		Hub.connect(Player.ChildAdded,function(child) if child:IsA("PlayerGui") then crosshair() end end)
		Hub.connect(RunService.RenderStepped,function()
			if hat then
				local head=Player.Character and Player.Character:FindFirstChild("Head")
				if head then hat.CFrame=head.CFrame*CFrame.new(0,1,0);hat.LocalTransparencyModifier=head.LocalTransparencyModifier end
			end
			if crossLabel then local point=UserInputService:GetMouseLocation();crossLabel.Position=UDim2.fromOffset(point.X,point.Y) end
		end)
		local diagnostics=Tabs.AntiLag:AddRightGroupbox("Runtime diagnostics")
		diagnostics:AddButton({Text="Show runtime status",Func=function()
			local connections,threads,instances=0,0,0
			for _ in pairs(Hub.connections) do connections+=1 end
			for _ in pairs(Hub.threads) do threads+=1 end
			for _ in pairs(Hub.instances) do instances+=1 end
			notify("Runtime status",string.format("%d tracked connections, %d tasks, %d local instances",connections,threads,instances),6)
		end})
		diagnostics:AddButton({Text="Show latest callback error",Func=function()
			notify("Runtime diagnostics",tostring(Hub.lastCallbackError or Hub.lastWorkerError or "No callback errors recorded this session."),8)
		end})
		Hub.cleanup(function()
			disposed=true;epoch+=1
			for instance in pairs(snapshots) do restore(instance) end
			if shadowOriginal~=nil then lighting.GlobalShadows=shadowOriginal end
			destroy(hat);destroy(attachment);destroy(crossGui)
		end)
	end)()
end
-- END PRIVATE SAFE FEATURE ADAPTER

-- BEGIN LOCAL ENVIRONMENT OPTIONS
do
	(function()
		local lighting=game:GetService("Lighting")
		local terrain=Workspace:FindFirstChildOfClass("Terrain")
		local group=Tabs.Visual:AddRightGroupbox("Local environment")
		local skyGroup=Tabs.Visual:AddRightGroupbox("Skybox Faces")
		local sunGroup=Tabs.Visual:AddRightGroupbox("Sun & Stars")
		local shaderGroup=Tabs.Visual:AddRightGroupbox("Shaders")
		local waterGroup=Tabs.Visual:AddRightGroupbox("Water Appearance")
		local shader,sky,clouds
		local shaderOn,skyOn,waterOn=false,false,false
		local saturation,exposure,bloom=0.15,0,0.3
		local contrast,tint=0.05,Color3.new(1,1,1)
		local bloomSize,bloomThreshold=24,1.5
		local raysOn,raysIntensity,raysSpread=false,0.05,0.8
		local dofOn,focusDistance,focusRadius,nearBlur,farBlur=false,40,35,0.05,0.15
		local image="rbxassetid://159454299"
		local faces={}
		local stars,celestial,sunSize,moonSize=3000,true,21,11
		local sunImage,moonImage="",""
		local rotation={0,0,0}
		local water={WaterWaveSize=0.15,WaterWaveSpeed=10,WaterTransparency=0.3,WaterReflectance=0.5}
		local savedWater
		local oldSkies={}
		local function remove(instance) if instance then Hub.instances[instance]=nil;Hub.assetTargets[instance]=nil;instance:Destroy() end end
		local function asset(value)
			local text=tostring(value or ""):match("^%s*(.-)%s*$")
			if text=="" then return "" end
			local id=text:match("^(%d+)$") or text:match("^rbxassetid://(%d+)$") or text:match("[?&]id=(%d+)") or text:match("roblox.com/store/asset/(%d+)") or text:match("roblox.com/library/(%d+)")
			if id and tonumber(id)>0 then return "rbxassetid://"..id end
		end
		local function color(value)
			local hex=tostring(value or ""):gsub("#","")
			if hex:match("^%x%x%x%x%x%x$") then return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)) end
		end
		local function clearShader()
			if shader then for _,effect in pairs(shader) do remove(effect) end;shader=nil end
		end
		local function updateShader()
			if not shaderOn then clearShader();return end
			if shader and (not shader.correction.Parent or not shader.glow.Parent) then clearShader() end
			if not shader then
				shader={}
				for key,class in pairs({correction="ColorCorrectionEffect",glow="BloomEffect",rays="SunRaysEffect",dof="DepthOfFieldEffect"}) do
					shader[key]=Hub.new(class,lighting);shader[key].Name="ArrivaLocal_"..key
				end
			end
			shader.correction.Saturation=saturation;shader.correction.Brightness=exposure
			shader.correction.Contrast=contrast;shader.correction.TintColor=tint
			shader.glow.Intensity=bloom;shader.glow.Size=bloomSize;shader.glow.Threshold=bloomThreshold
			shader.rays.Enabled=raysOn;shader.rays.Intensity=raysIntensity;shader.rays.Spread=raysSpread
			shader.dof.Enabled=dofOn;shader.dof.FocusDistance=focusDistance;shader.dof.InFocusRadius=focusRadius
			shader.dof.NearIntensity=nearBlur;shader.dof.FarIntensity=farBlur
		end
		local applyShader=updateShader
		shaderGroup:AddToggle("PrivateShader",{Text="Local shaders",Default=false,Callback=function(on) shaderOn=on;applyShader() end})
		local function slider(target,id,label,default,min,max,rounding,callback)
			target:AddSlider(id,{Text=label,Default=default,Min=min,Max=max,Rounding=rounding,Callback=callback})
		end
		slider(shaderGroup,"PrivateSaturation","Saturation",0.15,-1,1,2,function(v) saturation=v;applyShader() end)
		slider(shaderGroup,"PrivateBrightness","Brightness",0,-0.3,0.3,2,function(v) exposure=v;applyShader() end)
		slider(shaderGroup,"PrivateBloom","Bloom intensity",0.3,0,2,2,function(v) bloom=v;applyShader() end)
		slider(shaderGroup,"PrettyContrast","Contrast",0.05,-1,1,2,function(v) contrast=v;applyShader() end)
		shaderGroup:AddInput("PrettyShaderTint",{Text="Tint HEX",Default="FFFFFF",Finished=true,Callback=function(v) local c=color(v);if c then tint=c;applyShader() else notify("Shader warning","Use a six-digit HEX color.",4,"warning") end end})
		slider(shaderGroup,"PrettyBloomSize","Bloom size",24,0,56,0,function(v) bloomSize=v;applyShader() end)
		slider(shaderGroup,"PrettyBloomThreshold","Bloom threshold",1.5,0,4,2,function(v) bloomThreshold=v;applyShader() end)
		shaderGroup:AddToggle("PrettySunRays",{Text="Sun rays",Default=false,Callback=function(on) raysOn=on;applyShader() end})
		slider(shaderGroup,"PrettyRaysIntensity","Sun ray intensity",0.05,0,0.3,2,function(v) raysIntensity=v;applyShader() end)
		slider(shaderGroup,"PrettyRaysSpread","Sun ray spread",0.8,0,1,2,function(v) raysSpread=v;applyShader() end)
		shaderGroup:AddToggle("PrettyDepthOfField",{Text="Depth of field",Default=false,Callback=function(on) dofOn=on;applyShader() end})
		slider(shaderGroup,"PrettyFocusDistance","Focus distance",40,0,500,0,function(v) focusDistance=v;applyShader() end)
		slider(shaderGroup,"PrettyFocusRadius","In-focus radius",35,0,200,0,function(v) focusRadius=v;applyShader() end)
		slider(shaderGroup,"PrettyNearBlur","Near blur",0.05,0,0.5,2,function(v) nearBlur=v;applyShader() end)
		slider(shaderGroup,"PrettyFarBlur","Far blur",0.15,0,0.5,2,function(v) farBlur=v;applyShader() end)
		shaderGroup:AddDropdown("PrettyShaderPreset",{Text="Apply shader preset",Values={"Custom","Soft","Cinematic","Warm Sunset","Cool Night"},Default=1,Callback=function(name)
			local presets={Soft={0.08,0.02,0.03,0.2,"FFF8F0"},Cinematic={0.12,0,0.18,0.35,"FFFFFF"},["Warm Sunset"]={0.2,0.03,0.1,0.45,"FFE4CB"},["Cool Night"]={-0.1,-0.04,0.12,0.2,"D6E5FF"}}
			local p=presets[name];if not p then return end
			for i,id in ipairs({"PrivateSaturation","PrivateBrightness","PrettyContrast","PrivateBloom","PrettyShaderTint"}) do Options[id]:SetValue(p[i]) end
			Options.PrettyShaderPreset:SetValue("Custom")
		end})
		shaderGroup:AddLabel("Enable Local shaders to apply these effects. Sun rays and depth of field are optional.")
		local function updateSky()
			if skyOn then
				for _,child in ipairs(lighting:GetChildren()) do if child:IsA("Sky") and child~=sky then oldSkies[child]=lighting;child.Parent=nil end end
				if not sky or sky.Parent~=lighting then remove(sky);sky=Hub.new("Sky");sky.Name="ArrivaLocalSky";sky.Parent=lighting end
				for _,property in ipairs({"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}) do sky[property]=faces[property] or image end
				sky.StarCount=stars;sky.CelestialBodiesShown=celestial;sky.SunAngularSize=sunSize;sky.MoonAngularSize=moonSize
				sky.SunTextureId=sunImage~="" and sunImage or "rbxasset://sky/sun.jpg"
				sky.MoonTextureId=moonImage~="" and moonImage or "rbxasset://sky/moon.jpg"
				pcall(function() sky.SkyboxOrientation=Vector3.new(rotation[1],rotation[2],rotation[3]) end)
			else
				remove(sky);sky=nil
				for child,parent in pairs(oldSkies) do pcall(function() if child.Parent==nil then child.Parent=parent end end);oldSkies[child]=nil end
			end
		end
		local function imageInput(target,id,label,default,set)
			target:AddInput(id,{Text=label,Default=default,Finished=true,Callback=function(v)
				local resolved=asset(v)
				if resolved~=nil then set(resolved);updateSky()
				else notify("Sky image warning","Use a Roblox image ID or asset link.",4,"warning") end
			end})
		end
		skyGroup:AddToggle("PrivateSkyEnabled",{Text="Custom skybox and stars",Default=false,Callback=function(on) skyOn=on;updateSky() end})
		imageInput(skyGroup,"PrivateSkyImage","Fallback image for all faces","159454299",function(v) if v~="" then image=v end end)
		for _,entry in ipairs({{"Up","Up / top"},{"Dn","Down / bottom"},{"Lf","Left"},{"Rt","Right"},{"Ft","Forward / front"},{"Bk","Backward / back"}}) do
			local property="Skybox"..entry[1]
			imageInput(skyGroup,"Pretty"..property,entry[2].." image ID","",function(v) faces[property]=v~="" and v or nil end)
		end
		skyGroup:AddLabel("Blank faces use the fallback image. Use six matching images for a seamless skybox.")
		for i,label in ipairs({"Sky pitch","Sky yaw","Sky roll"}) do local index=i;slider(skyGroup,"PrettySkyRotation"..i,label,0,-180,180,0,function(v) rotation[index]=v;updateSky() end) end
		sunGroup:AddToggle("PrettyCelestialBodies",{Text="Show sun, moon and stars",Default=true,Callback=function(on) celestial=on;updateSky() end})
		slider(sunGroup,"PrettyStarCount","Star count (visible at night)",3000,0,10000,0,function(v) stars=v;updateSky() end)
		slider(sunGroup,"PrettySunSize","Sun size",21,0,60,1,function(v) sunSize=v;updateSky() end)
		slider(sunGroup,"PrettyMoonSize","Moon size",11,0,60,1,function(v) moonSize=v;updateSky() end)
		imageInput(sunGroup,"PrettySunImage","Sun image ID","",function(v) sunImage=v end)
		imageInput(sunGroup,"PrettyMoonImage","Moon image ID","",function(v) moonImage=v end)
		local latitudeOn,latitude,savedLatitude=false,41.733,nil
		local function updateLatitude()
			if latitudeOn then if savedLatitude==nil then savedLatitude=lighting.GeographicLatitude end;lighting.GeographicLatitude=latitude
			elseif savedLatitude~=nil then lighting.GeographicLatitude=savedLatitude;savedLatitude=nil end
		end
		sunGroup:AddToggle("PrettyLatitudeOverride",{Text="Override sun latitude",Default=false,Callback=function(on) latitudeOn=on;updateLatitude() end})
		slider(sunGroup,"PrettySunLatitude","Sun latitude",41.733,0,360,1,function(v) latitude=v;updateLatitude() end)
		-- BEGIN TERRAIN REALISTIC WATER
		-- Resonance replaces the flat ocean surfaces with Terrain water at a -4 offset.
		do
			local enabled,offset=false,-4
			local revision=0
			local worker
			local regions,surfaces={},{}
			local status=waterGroup:AddLabel("Realistic water: off.")
			local function oceanModel()
				local map=Workspace:FindFirstChild("Map")
				local objects=map and map:FindFirstChild("AlwaysHereTweenedObjects")
				local ocean=objects and objects:FindFirstChild("Ocean")
				local object=ocean and ocean:FindFirstChild("Object")
				return object and object:FindFirstChild("ObjectModel")
			end
			local function restore()
				for part,saved in pairs(surfaces) do
					if saved.connection then saved.connection:Disconnect();Hub.connections[saved.connection]=nil end
					if part.Parent then part.Transparency=saved.transparency end
					surfaces[part]=nil
				end
				for i=#regions,1,-1 do
					local record=regions[i]
					terrain:PasteRegion(record.copy,record.corner,true)
					record.copy:Destroy();regions[i]=nil
				end
			end
			local function build(ticket)
				local model=oceanModel();if not terrain or not model then error("Ocean surface has not loaded.",0) end
				local count=0
				for _,part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") and part.Transparency<1 then
						local shift=Vector3.new(0,offset,0)
						local region=Region3.new(part.Position-part.Size/2+shift,part.Position+part.Size/2+shift):ExpandToGrid(4)
						local low=region.CFrame.Position-region.Size/2;local high=region.CFrame.Position+region.Size/2
						for x=low.X,high.X-1,128 do for y=low.Y,high.Y-1,128 do for z=low.Z,high.Z-1,128 do
							if revision~=ticket or not enabled or not Hub.alive then return end
							count+=1
							local upper=Vector3.new(math.min(x+128,high.X),math.min(y+128,high.Y),math.min(z+128,high.Z))
							if math.min(x/4,y/4,z/4)<-32768 or math.max(upper.X/4-1,upper.Y/4-1,upper.Z/4-1)>32767 then error("Ocean extends outside Terrain backup bounds.",0) end
							local corner=Vector3int16.new(x/4,y/4,z/4)
							local cellEnd=Vector3int16.new(upper.X/4-1,upper.Y/4-1,upper.Z/4-1)
							local copy=terrain:CopyRegion(Region3int16.new(corner,cellEnd))
							table.insert(regions,{copy=copy,corner=corner})
							terrain:FillRegion(Region3.new(Vector3.new(x,y,z),upper),4,Enum.Material.Water)
							if count%8==0 then task.wait() end
						end end end
						if not surfaces[part] then
							local saved={transparency=part.Transparency};surfaces[part]=saved
							saved.connection=Hub.connect(part:GetPropertyChangedSignal("Transparency"),function()
								if enabled and surfaces[part] and part.Transparency~=1 then part.Transparency=1 end
							end)
						end
						part.Transparency=1
					end
				end
				status:SetText("Realistic water: Terrain water active ("..#regions.." regions).")
			end
			local function request()
				revision+=1
				if worker then return end
				worker=task.defer(function()
					repeat
						local ticket=revision
						restore()
						if enabled then
							status:SetText("Realistic water: converting ocean surfaces.")
							local ok,message=pcall(build,ticket)
							if not ok then restore();status:SetText("Realistic water: "..tostring(message));break end
						else status:SetText("Realistic water: off.") end
					until ticket==revision or not Hub.alive
					worker=nil
				end)
			end
			waterGroup:AddToggle("SourceRealisticWater",{Text="Realistic Water",Default=false,Callback=function(on) enabled=on;request();Hub.requestSave() end})
			waterGroup:AddSlider("SourceRealisticWaterOffset",{Text="Water height offset",Default=-4,Min=-20,Max=20,Rounding=1,Callback=function(value) offset=value;if enabled then request() end;Hub.requestSave() end})
			Hub.connect(Workspace.DescendantAdded,function(part)
				local model=enabled and oceanModel()
				if model and part:IsA("BasePart") and part:IsDescendantOf(model) then request() end
			end)
			Hub.cleanup(function()
				enabled=false;revision+=1
				if worker then pcall(Hub.nativeTask.cancel,worker);worker=nil end
				restore()
			end)
		end
		-- END TERRAIN REALISTIC WATER
		local waterObjects={}
		local hideOverlay=true
		local waterEpoch=0
		local function waterRoot()
			local map=Workspace:FindFirstChild("Map")
			local objects=map and map:FindFirstChild("AlwaysHereTweenedObjects")
			local ocean=objects and objects:FindFirstChild("Ocean")
			local object=ocean and ocean:FindFirstChild("Object")
			return object and object:FindFirstChild("ObjectModel")
		end
		local function restoreWaterObjects()
			for object,record in pairs(waterObjects) do
				for key,value in pairs(record) do pcall(function() object[key]=value end) end
				waterObjects[object]=nil
			end
		end
		local function setWater(object,key,value)
			waterObjects[object]=waterObjects[object] or {}
			if waterObjects[object][key]==nil then waterObjects[object][key]=object[key] end
			object[key]=value
		end
		local function inspectWater(object)
			if not waterOn or not object.Parent then return end
			local root=waterRoot();if not root then return end
			local ancestor=object
			while ancestor and ancestor~=root do ancestor=ancestor.Parent end
			if not ancestor then return end
			if object:IsA("BasePart") and object.Transparency<1 then setWater(object,"Transparency",water.WaterTransparency)
			elseif object:IsA("Decal") or object:IsA("Texture") then setWater(object,"Transparency",hideOverlay and 1 or water.WaterTransparency)
			elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then setWater(object,"ImageTransparency",hideOverlay and 1 or water.WaterTransparency)
			elseif hideOverlay and object:IsA("SurfaceAppearance") then setWater(object,"Parent",nil)
			elseif hideOverlay and object:IsA("SpecialMesh") then setWater(object,"TextureId","") end
			if hideOverlay and object:IsA("MeshPart") then setWater(object,"TextureID","") end
		end
		local function updateWater()
			waterEpoch+=1;local ticket=waterEpoch
			restoreWaterObjects()
			if waterOn then
				if terrain then
					if not savedWater then savedWater={};for property in pairs(water) do savedWater[property]=terrain[property] end end
					for property,value in pairs(water) do terrain[property]=value end
				end
				local root=waterRoot();if root then Hub.scanDescendants(root,inspectWater,function() return waterOn and waterEpoch==ticket end) end
			elseif savedWater then for property,value in pairs(savedWater) do terrain[property]=value end;savedWater=nil end
		end
		waterGroup:AddToggle("PrivateWaterEnabled",{Text="Custom water appearance",Default=false,Callback=function(on) waterOn=on;updateWater() end})
		for _,option in ipairs({{"Wave size","WaterWaveSize",0,1,2},{"Wave speed","WaterWaveSpeed",0,100,0},{"Water transparency","WaterTransparency",0,1,2},{"Water reflectance","WaterReflectance",0,1,2}}) do
			local property=option[2]
			slider(waterGroup,"Private"..property,option[1],water[property],option[3],option[4],option[5],function(v) water[property]=v;updateWater() end)
		end
		waterGroup:AddToggle("PrettyHideWaterOverlay",{Text="Hide water decals and textures",Default=true,Callback=function(on) hideOverlay=on;updateWater() end})
		waterGroup:AddLabel("Enable Custom water appearance. Transparency affects Terrain and the map's ocean surface.")
		Hub.connect(Workspace.DescendantAdded,function(object)
			if waterOn then local ticket=waterEpoch;task.defer(function() if Hub.alive and waterOn and waterEpoch==ticket then inspectWater(object) end end) end
		end)
		local cover,density=0.5,0.5
		local cloudsOn=false
		local ownedCloud=false
		local savedCloud
		local cloudConnections={}
		local applyingCloud=false
		local function releaseCloud()
			for _,connection in ipairs(cloudConnections) do connection:Disconnect();Hub.connections[connection]=nil end
			table.clear(cloudConnections)
			local previous=clouds
			clouds=nil
			if ownedCloud then remove(previous)
			elseif previous and savedCloud then
				for key,value in pairs(savedCloud) do pcall(function() previous[key]=value end) end
			end
			ownedCloud=false;savedCloud=nil
		end
		local function updateClouds()
			if not cloudsOn then releaseCloud();return end
			terrain=Workspace:FindFirstChildOfClass("Terrain")
			if not terrain then return end
			if clouds and clouds.Parent~=terrain then releaseCloud() end
			if not clouds then
				clouds=terrain:FindFirstChildOfClass("Clouds")
				if clouds then
					savedCloud={Cover=clouds.Cover,Density=clouds.Density,Enabled=clouds.Enabled}
				else
					clouds=Hub.new("Clouds");clouds.Name="ArrivaLocalClouds";ownedCloud=true
					clouds.Parent=terrain
				end
				for _,property in ipairs({"Enabled","Cover","Density"}) do
					table.insert(cloudConnections,Hub.connect(clouds:GetPropertyChangedSignal(property),function()
						if applyingCloud or not cloudsOn or not clouds then return end
						local desired=property=="Enabled" and true or property=="Cover" and cover or density
						if clouds[property]~=desired then
							if savedCloud then savedCloud[property]=clouds[property] end
							applyingCloud=true;clouds[property]=desired;applyingCloud=false
						end
					end))
				end
			end
			applyingCloud=true
			clouds.Enabled=true;clouds.Cover=cover;clouds.Density=density
			applyingCloud=false
		end
		group:AddToggle("PrivateClouds",{Text="Local clouds",Default=false,Callback=function(on)
			cloudsOn=on;updateClouds();Hub.requestSave()
		end})
		group:AddSlider("PrivateCloudCover",{Text="Cloud cover",Default=0.5,Min=0,Max=1,Rounding=2,Callback=function(v) cover=v;updateClouds();Hub.requestSave() end})
		group:AddSlider("PrivateCloudDensity",{Text="Cloud density",Default=0.5,Min=0,Max=1,Rounding=2,Callback=function(v) density=v;updateClouds();Hub.requestSave() end})
		if terrain then
			Hub.connect(terrain.ChildAdded,function(child)
				if cloudsOn and child:IsA("Clouds") and child~=clouds then
					if ownedCloud then releaseCloud() end
					updateClouds()
				end
			end)
			Hub.connect(terrain.ChildRemoved,function(child)
				if cloudsOn and child==clouds then task.defer(function() if Hub.alive and cloudsOn then updateClouds() end end) end
			end)
		end
		Hub.connect(lighting.ChildAdded,function(child) if skyOn and child:IsA("Sky") and child~=sky then oldSkies[child]=lighting;child.Parent=nil end end)
		Hub.cleanup(function() clearShader();skyOn=false;updateSky();waterOn=false;updateWater();cloudsOn=false;releaseCloud();latitudeOn=false;updateLatitude() end)
	end)()
end
-- END LOCAL ENVIRONMENT OPTIONS

-- BEGIN LOCAL CAMERA OPTIONS
do
	(function()
		local group=Tabs.Visual:AddRightGroupbox("Camera and cursor")
		local third,limbs,cursor=false,false,false
		local zoom,transparency,cursorSize=128,0.3,24
		local cursorImage="rbxassetid://9943168532"
		local originalCamera
		local savedLimbs={}
		local gui,image
		local oldMouseIcon
		local function camera()
			if third then
				if not originalCamera then originalCamera={Player.CameraMode,Player.CameraMinZoomDistance,Player.CameraMaxZoomDistance} end
				Player.CameraMode=Enum.CameraMode.Classic;Player.CameraMaxZoomDistance=zoom;Player.CameraMinZoomDistance=0.5
			elseif originalCamera then
				Player.CameraMode=originalCamera[1];Player.CameraMaxZoomDistance=originalCamera[3];Player.CameraMinZoomDistance=originalCamera[2];originalCamera=nil
			end
		end
		group:AddToggle("PrivateThirdPerson",{Text="Third person camera",Default=false,Callback=function(on) third=on;camera();Hub.requestSave() end})
		group:AddSlider("PrivateMaxZoom",{Text="Maximum camera zoom",Default=128,Min=10,Max=512,Rounding=0,Callback=function(v) zoom=v;camera();Hub.requestSave() end})
		local function restoreLimbs()
			for part,value in pairs(savedLimbs) do pcall(function() part.LocalTransparencyModifier=value end);savedLimbs[part]=nil end
		end
		group:AddToggle("PrivateVisibleLimbs",{Text="Show limbs in first person",Default=false,Callback=function(on) limbs=on;if not on then restoreLimbs() end;Hub.requestSave() end})
		group:AddSlider("PrivateLimbTransparency",{Text="First person limb transparency",Default=0.3,Min=0,Max=1,Rounding=2,Callback=function(v) transparency=v;Hub.requestSave() end})
		local function clearCursor()
			if gui then Hub.instances[gui]=nil;Hub.assetTargets[gui]=nil;gui:Destroy();gui,image=nil,nil end
			if oldMouseIcon~=nil then UserInputService.MouseIconEnabled=oldMouseIcon;oldMouseIcon=nil end
		end
		local function updateCursor()
			if not cursor then clearCursor();return end
			local playerGui=Player:FindFirstChildOfClass("PlayerGui");if not playerGui then return end
			if not gui or not gui.Parent then
				clearCursor();oldMouseIcon=UserInputService.MouseIconEnabled
				gui=Hub.new("ScreenGui",playerGui);gui.Name="ArrivaLocalCursor";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=1000
				image=Hub.new("ImageLabel",gui);image.BackgroundTransparency=1;image.AnchorPoint=Vector2.new(0.5,0.5);image.Active=false
			end
			image.Image=cursorImage;image.Size=UDim2.fromOffset(cursorSize,cursorSize);UserInputService.MouseIconEnabled=false
		end
		group:AddToggle("PrivateCustomCursor",{Text="Custom cursor",Default=false,Callback=function(on) cursor=on;updateCursor();Hub.requestSave() end})
		group:AddInput("PrivateCursorImage",{Text="Cursor image asset ID",Default="9943168532",Finished=true,Callback=function(v)
			local id=tostring(v):match("^%s*(%d+)%s*$") or tostring(v):match("^rbxassetid://(%d+)$")
			if id then cursorImage="rbxassetid://"..id;updateCursor();Hub.requestSave() end
		end})
		group:AddSlider("PrivateCursorSize",{Text="Cursor size",Default=24,Min=8,Max=64,Rounding=0,Callback=function(v) cursorSize=v;updateCursor();Hub.requestSave() end})
		Hub.connect(RunService.RenderStepped,function()
			if image then local point=UserInputService:GetMouseLocation();image.Position=UDim2.fromOffset(point.X,point.Y) end
			if not limbs then return end
			local char=Player.Character;local cam=Workspace.CurrentCamera
			if not char or not cam then return end
			local first=(cam.CFrame.Position-cam.Focus.Position).Magnitude<=1.5
			for _,part in ipairs(char:GetChildren()) do
				if part:IsA("BasePart") and part.Name~="Head" and part.Name~="HumanoidRootPart" and part.Name~="Torso" and part.Name~="UpperTorso" and part.Name~="LowerTorso" then
					if savedLimbs[part]==nil then savedLimbs[part]=part.LocalTransparencyModifier end
					part.LocalTransparencyModifier=first and transparency or 0
				end
			end
		end)
		Hub.connect(Player.CharacterAdded,function() restoreLimbs() end)
		Hub.connect(Player.ChildAdded,function(child) if child:IsA("PlayerGui") then updateCursor() end end)
		Hub.cleanup(function() third=false;camera();restoreLimbs();clearCursor() end)
	end)()
end
-- END LOCAL CAMERA OPTIONS

-- BEGIN LOCAL ANIMATION OPTIONS
do
	(function()
		local group=Tabs.Player:AddRightGroupbox("Character animations")
		local animations={Struggle = "rbxassetid://7047322890",
			Faint = "rbxassetid://181526230",
			["Floor Faint"] = "rbxassetid://181525546",
			Levitate = "rbxassetid://313762630",
			Spinner = "rbxassetid://188632011",
			["Spin Dance"] = "rbxassetid://429730430",
			["Spin Dance 2"] = "rbxassetid://186934910",
			["Float Sit"] = "rbxassetid://179224234",
			Scared = "rbxassetid://180612465",
			["Floating Head"] = "rbxassetid://121572214",
			Crouch = "rbxassetid://182724289",
			["Moving Dance"] = "rbxassetid://429703734",
			["Bow Down"] = "rbxassetid://204292303",
			["Sword Slam"] = "rbxassetid://204295235",
			Insane = "rbxassetid://33796059",
			["Mega Insane"] = "rbxassetid://184574340",
			["Sword Slice"] = "rbxassetid://35978879",
			["Loop Head"] = "rbxassetid://35154961",
			["Floor Crawl"] = "rbxassetid://282574440",
			["Dino Walk"] = "rbxassetid://204328711",
			["Weird Back"] = "rbxassetid://215384594",
			["Moon Dance"] = "rbxassetid://45834924",
			["Full Punch"] = "rbxassetid://204062532",
			["Full Swing"] = "rbxassetid://218504594",
			["Arm Turbine"] = "rbxassetid://259438880",
			["Barrel Roll"] = "rbxassetid://136801964",
			["Arm Detach"] = "rbxassetid://33169583",
			["Insane Arms"] = "rbxassetid://27432691",
		}
		-- Classic R6 dance families and their Animate-script variants.
		-- Source: https://devforum.roblox.com/t/r6-to-r15-animation-list-from-roblox/4079574
		local r6Dances={
			-- Additional legacy R6 presets: https://github.com/KRNL2/r6animationgui/blob/main/fe
			["Happy Dance"]="rbxassetid://248335946",
			["Moon Dance 2"]="rbxassetid://27789359",
			["R6 Dance 1"]="rbxassetid://182435998",
			["R6 Dance 1 (Alt 1)"]="rbxassetid://182491037",
			["R6 Dance 1 (Alt 2)"]="rbxassetid://182491065",
			["R6 Dance 2"]="rbxassetid://182436842",
			["R6 Dance 2 (Alt 1)"]="rbxassetid://182491248",
			["R6 Dance 2 (Alt 2)"]="rbxassetid://182491277",
			["R6 Dance 3"]="rbxassetid://182436935",
			["R6 Dance 3 (Alt 1)"]="rbxassetid://182491368",
			["R6 Dance 3 (Alt 2)"]="rbxassetid://182491423",
		}
		for name,id in pairs(r6Dances) do animations[name]=id end
		local names={};for name in pairs(animations) do table.insert(names,name) end;table.sort(names)
		local selected=names[1]
		local speed,enabled=1,false
		local track,asset
		local function stop()
			if track then pcall(function() track:Stop(0.15);track:Destroy() end);track=nil end
			if asset then Hub.instances[asset]=nil;Hub.assetTargets[asset]=nil;asset:Destroy();asset=nil end
		end
		local function play()
			stop();if not enabled then return end
			local character=Player.Character
			local humanoid=character and character:FindFirstChildOfClass("Humanoid")
			local animator=humanoid and humanoid:FindFirstChildOfClass("Animator")
			if not animator or humanoid.Health<=0 then return end
			if r6Dances[selected] and humanoid.RigType~=Enum.HumanoidRigType.R6 then
				notify("R6 character required","Select an R6 character to play this dance.",5)
				return
			end
			local ok,message=pcall(function()
				asset=Hub.new("Animation");asset.AnimationId=animations[selected]
				track=animator:LoadAnimation(asset);track.Looped=true
				if r6Dances[selected] then track.Priority=Enum.AnimationPriority.Action end
				track:Play(0.15);track:AdjustSpeed(speed)
			end)
			if not ok then stop();notify("Animation unavailable","This animation could not be loaded for your character.",5);warn(tostring(message)) end
		end
		group:AddDropdown("PrivateAnimationPreset",{Text="Animation",Values=names,Default=1,Callback=function(value) if animations[value] then selected=value;play();Hub.requestSave() end end})
		group:AddSlider("PrivateAnimationSpeed",{Text="Animation speed",Default=1,Min=0,Max=5,Rounding=2,Callback=function(value) speed=value;if track then track:AdjustSpeed(speed) end;Hub.requestSave() end})
		group:AddToggle("PrivateAnimationEnabled",{Text="Play selected animation",Default=false,Callback=function(on) enabled=on;play();Hub.requestSave() end})
		group:AddLabel("Animation availability depends on your rig and asset permissions.")
		Hub.connect(Player.CharacterRemoving,stop)
		Hub.connect(Player.CharacterAdded,function(char)
			task.spawn(function()
				local humanoid=char:WaitForChild("Humanoid",5)
				if humanoid then humanoid:WaitForChild("Animator",5) end
				if Hub.alive and Player.Character==char then play() end
			end)
		end)
		Hub.cleanup(function() enabled=false;stop() end)
	end)()
end
-- END LOCAL ANIMATION OPTIONS

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
			if method=="FindFirstChild" then
				return function(_,name)
					local map=Workspace:FindFirstChild("Map")
					local folder=(map and map:FindFirstChild("AlwaysHereTweenedObjects"))
						or Workspace:FindFirstChild("AlwaysHereTweenedObjects")
					local current=folder and folder:FindFirstChild("Train")
					return current and current:FindFirstChild(name)
				end
			end
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
		tbl12.Teleport=function(part,frame) if part and part.Parent then Hub.teleportPart(part, frame);part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero;return true end end
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
		local function sourceSpawnImpl(name,frame,timeout)
			local char,root,hum=tbl12.Char()
			if flag11 or not root or not hum or hum.Health<=0 then return end
			local menu=ReplicatedStorage:FindFirstChild("MenuToys")
			local remote=menu and menu:FindFirstChild("SpawnToyRemoteFunction")
			if not remote then return end
			local allowed=Player:FindFirstChild("CanSpawnToy");if allowed and not allowed.Value then return end
			-- Resonance supplies a position above/in front of the character when omitted.
			-- Explicit Gucci spawn frames retain their existing game-facing values.
			frame=frame or CFrame.new(root.Position+Vector3.new(0,15,20))
			local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			local before={};if folder then for _,model in ipairs(folder:GetChildren()) do before[model]=true end end
			local duration=math.clamp(tonumber(timeout) or 2,0.25,5)
			local deadline=os.clock()+duration
			local done,result,invokeError=false,nil,nil
			local request=task.spawn(function()
				local ok,value=pcall(Hub.invoke,remote,name,frame,Vector3.new(0,97.69000244140625,0))
				if ok then result=value else invokeError=value end;done=true
			end)
			local function cancelRequest()
				if coroutine.status(request)~="dead" then pcall(Hub.nativeTask.cancel,request);Hub.threads[request]=nil end
			end
			-- Also bounds the request when its caller is cancelled before reaching cleanup.
			task.delay(duration,cancelRequest)
			local found
			repeat
				if flag11 or Player.Character~=char then break end
				folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
				if folder then
					if typeof(result)=="Instance" and result:IsA("Model") and result.Parent==folder and not before[result] then found=result end
					if not found then for _,model in ipairs(folder:GetChildren()) do
						if not before[model] and model:IsA("Model") and model.Name==name then found=model;break end
					end end
				end
				if found or (done and invokeError) then break end
				task.wait()
			until os.clock()>=deadline
			cancelRequest()
			if invokeError then warn("[Source defense spawn] "..tostring(invokeError)) end
			if found and Player.Character==char and not flag11 then spawned[found]=true;return found end
		end
		tbl12.SpawnToy=function(...)
			if spawnBusy and spawnBusy.char==Player.Character and coroutine.status(spawnBusy.owner)~="dead" then return nil end
			local token={char=Player.Character,owner=coroutine.running()};spawnBusy=token
			local args=table.pack(...)
			local ok,result=xpcall(function() return sourceSpawnImpl(table.unpack(args,1,args.n)) end,debug.traceback)
			if spawnBusy==token then spawnBusy=false end
			if not ok then warn("[Source defense spawn] "..tostring(result));return nil end
			return result
		end
		tbl12.SNO=function(part)
			if flag11 or not part or not part.Parent or not setNetworkOwnerEvent then return false end
			local char,root,hum=tbl12.Char()
			if not root or not hum or hum.Health<=0 then return false end
			local saved=Hub.teleportFrame(root)
			local moved=(Hub.teleportFrame(root).Position-part.Position).Magnitude>=30
			if moved then Hub.teleportPart(root, part.CFrame);task.wait() end
			local basis=Hub.lookAt(Hub.teleportFrame(root).Position,part.Position)
			if basis then Hub.fire(setNetworkOwnerEvent,part,basis) end
			local deadline=os.clock()+0.75
			repeat
				if flag11 or Player.Character~=char or not part.Parent then break end
				if tbl12.IsNetworkOwner(part) then break end
				task.wait()
			until os.clock()>=deadline
			if moved and root.Parent and Player.Character==char then Hub.teleportPart(root, saved);root.AssemblyLinearVelocity=Vector3.zero end
			return part.Parent and tbl12.IsNetworkOwner(part) or false
		end
		tbl12.Grab=function(part)
			local _,root,hum=tbl12.Char()
			if not part or not part.Parent or not root or not hum or hum.Health<=0 then return end
			local from=(Hub.teleportFrame(root)*CFrame.new(0,1.593,0)).Position
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
		-- Gucci's original ownership contract: PartOwner, grab offset and heartbeat retries.
		-- Isolated from the shared helper so other tools retain their existing behavior.
		local gucciOwnershipCleanup
		tbl12.GucciSNO=function(part)
			local char,root,hum=tbl12.Char()
			local head=char and char:FindFirstChild("Head")
			if flag11 or not part or not part.Parent or not root or not hum or hum.Health<=0 or not head or not Hub.canAffect(part) then return false end
			local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
			if not folder or not part:IsDescendantOf(folder) then return false end
			local function owned()
				if not part.Parent then return false end
				local owner=part:FindFirstChild("PartOwner")
				if not owner and part.Parent then owner=part.Parent:FindFirstChild("PartOwner",true) end
				return owner and owner.Value==Player.Name or false
			end
			if owned() then return true end
			if gucciOwnershipCleanup then return false end
			local moved=(root.Position-part.Position).Magnitude>=31
			local visibleRoot,visibleHead=root.CFrame,head.CFrame
			local serverFrame=visibleRoot
			local heartbeat,bound,restored
			local function restore()
				if restored then return end;restored=true
				if bound then originalRunService:UnbindFromRenderStep("ArrivaGucciOwnership");bound=false end
				if heartbeat then heartbeat:Disconnect();Hub.connections[heartbeat]=nil;heartbeat=nil end
				if moved and Player.Character==char and root.Parent==char and head.Parent==char then root.CFrame=visibleRoot;head.CFrame=visibleHead end
				gucciOwnershipCleanup=nil
				if Hub.gucciAcquiring==char then Hub.gucciAcquiring=nil end
			end
			gucciOwnershipCleanup=restore
			Hub.gucciAcquiring=char
			local ok,message=xpcall(function()
				if moved then
					originalRunService:BindToRenderStep("ArrivaGucciOwnership",Enum.RenderPriority.Camera.Value-1,function()
						if Player.Character==char and root.Parent==char and head.Parent==char then root.CFrame=visibleRoot;head.CFrame=visibleHead end
					end);bound=true
					heartbeat=Hub.connect(originalRunService.Heartbeat,function()
						if Player.Character==char and root.Parent==char and head.Parent==char then
							visibleRoot,visibleHead=root.CFrame,head.CFrame;root.CFrame=serverFrame;head.CFrame=serverFrame
						end
					end)
				end
				local deadline=os.clock()+0.65
				while gucciOwnershipCleanup==restore and Hub.alive and not flag11 and tbl8.GucciAntiGrab and Player.Character==char and root.Parent==char
					and part.Parent and hum.Health>0 and not owned() and os.clock()<deadline do
					local predicted=part.CFrame+part.AssemblyLinearVelocity*math.clamp(Player:GetNetworkPing(),0,0.35)
					if moved then serverFrame=predicted-Vector3.new(0,22,0) end
					originalRunService.Heartbeat:Wait()
					if not Hub.alive or flag11 or not tbl8.GucciAntiGrab or Player.Character~=char or not part.Parent or hum.Health<=0 then break end
					local origin=((moved and serverFrame or root.CFrame)*CFrame.new(0,1.593,0)).Position
					local basis=(predicted.Position-origin).Magnitude>0.000001 and CFrame.new(origin,predicted.Position) or Hub.safeLookAt(origin,predicted.Position)
					if basis then Hub.fire(setNetworkOwnerEvent,part,basis) end
				end
			end,debug.traceback)
			restore()
			if not ok then warn("[Gucci ownership] "..tostring(message));return false end
			local acquired=Player.Character==char and part.Parent and owned() or false
			if not acquired and Hub.reportGucciStatus and tbl8.GucciAntiGrab and Player.Character==char then
				Hub.gucciVerificationReason="Game did not confirm the toy's PartOwner during acquisition."
				Hub.reportGucciStatus("Retrying","Gucci is retrying ownership acquisition; waiting for the game's PartOwner confirmation.")
			end
			return acquired
		end
				Hub.teleportMaskCancelers=Hub.teleportMaskCancelers or {}
		Hub.teleportMaskCancelers.GucciOwnership=function() if gucciOwnershipCleanup then gucciOwnershipCleanup() end end
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
			if not arg or not Hub.canHarm(arg) then return false end
			local gucciAntiGrab = tbl8.GucciAntiGrab

			if not gucciAntiGrab then
				gucciAntiGrab = not (v24 and v24.Health > 0 and v23 and (v28 or v29 or (v27 and v27.SeatPart)))
			end

			if gucciAntiGrab then
				return false
			end

			local function fn21(arg2)
				if not Hub.alive or Player.Character~=v22 or not Hub.canHarm(arg) or not (arg2 and arg2.Parent) or not Hub.canAffect(arg2) or obj2[arg2] then
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

			-- Recursive seats cover Blobman, TractorGreen, SantaSleigh and toy trains.
			-- The shared map train is considered only through the target's SeatPart above.
			local seen={}
			for _,folder in pairs({toys=v28,plot=v29}) do
				for _,seat in ipairs(folder:GetDescendants()) do
					if (seat:IsA("VehicleSeat") or seat:IsA("Seat")) and not seen[seat] then
						seen[seat]=true;fn21(seat)
					end
				end
			end
		end

		do
			local tbl16 = nil
			local flag12 = nil
			local gucciThread

			-- GUCCI CONFIRMATION BEGIN
			local function clearGucciConfirmation(record,announce)
				if not record then return end
				local wasActive=record.Confirmed
				if wasActive then
					local hum=record.Hum;local rag=hum and hum:FindFirstChild("Ragdolled")
					local reason=Player.Character~=record.Char and "Character changed."
						or (not record.Vehicle or not record.Vehicle.Parent) and "Gucci vehicle disappeared."
						or (not record.Seat or not record.Seat.Parent) and "Gucci seat disappeared."
						or (not hum or not hum.Parent or hum.Health<=0) and "Character died or humanoid disappeared."
						or isHeld.Value and "Character was held."
						or (rag and rag.Value) and "Character became ragdolled."
						or (record.Seat.Occupant and record.Seat.Occupant~=hum) and "Another humanoid occupied the Gucci seat."
						or (hum.SeatPart and hum.SeatPart~=record.Seat) and "Character entered another seat."
						or "Original controller validity changed or Gucci was stopped."
					Hub.gucciLastInterruption=reason
					-- A disturbed active toy can retain stale seat/controller state. Rebuild it once.
					record.RebuildRequired=record.Type~="Train"
				end
				record.Confirmed=false
				if Hub.gucciVerifiedRun==record then Hub.gucciVerifiedRun=nil end
				if Hub.gucciSeatRun==record then Hub.gucciSeatRun=nil end
				if Hub.gucciSetupCharacter==record.Char then Hub.gucciSetupCharacter=nil end
				if announce and wasActive and Hub.alive and tbl8.GucciAntiGrab and Hub.reportGucciStatus then Hub.reportGucciStatus("Retrying","Gucci interrupted: "..tostring(Hub.gucciLastInterruption)) end
			end
			local function publishGucciCompletion(record,isValid,weldObserved)
				if not weldObserved or not isValid() or Player.Character~=record.Char then return end
				if record.Type~="Train" and (not record.BP or record.BP.Parent~=record.Root) then return end
				record.Confirmed=true
				if Hub.gucciSetupCharacter==record.Char then Hub.gucciSetupCharacter=nil end
				Hub.gucciVerifiedRun=record;Hub.gucciVerificationReason=nil
				if Hub.gucciStage~="Active" and Hub.reportGucciStatus then Hub.reportGucciStatus("Active") end
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

				if Hub.gucciVehicleRun==tbl16 then Hub.gucciVehicleRun=nil end
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
				local v23 = nil
				local v24, v25, v26, gucciType, ragdolled, object, v27, seat

				while tbl8.GucciAntiGrab do
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

						if tbl16 and (tbl16.RebuildRequired or tbl16.Type ~= gucciType or not tbl16.Vehicle.Parent or not tbl16.Seat.Parent or tbl16.Char ~= v24) then
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
												Hub.gucciSeatRun=v27;Hub.gucciVehicleRun=v27;Hub.gucciSetupCharacter=v24
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

													table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child.Name == "SeatWeld" then
															child.Enabled = false
															child:Destroy()
															flag14 = true
														end
													end))

													table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child:IsA("LocalScript") and child.Name:lower():find("control") then
															child.Enabled = false
															child:Destroy()
														end
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

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.GucciSNO(root)
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
																		publishGucciCompletion(v27,fn25,flag14)
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
												Hub.gucciSeatRun=v27;Hub.gucciVehicleRun=v27;Hub.gucciSetupCharacter=v24
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

													table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child.Name == "SeatWeld" then
															child.Enabled = false
															child:Destroy()
															flag14 = true
														end
													end))

													table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child:IsA("LocalScript") and child.Name:lower():find("control") then
															child.Enabled = false
															child:Destroy()
														end
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

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.GucciSNO(root)
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
																		publishGucciCompletion(v27,fn25,flag14)
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
												Hub.gucciSeatRun=v27;Hub.gucciVehicleRun=v27;Hub.gucciSetupCharacter=v24
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

													table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child.Name == "SeatWeld" then
															child.Enabled = false
															child:Destroy()
															flag14 = true
														end
													end))

													table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child:IsA("LocalScript") and child.Name:lower():find("control") then
															child.Enabled = false
															child:Destroy()
														end
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

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.GucciSNO(root)
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
																		publishGucciCompletion(v27,fn25,flag14)
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
												Hub.gucciSeatRun=v27;Hub.gucciVehicleRun=v27;Hub.gucciSetupCharacter=v24
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

													table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child.Name == "SeatWeld" then
															child.Enabled = false
															child:Destroy()
															flag14 = true
														end
													end))

													table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child:IsA("LocalScript") and child.Name:lower():find("control") then
															child.Enabled = false
															child:Destroy()
														end
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

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.GucciSNO(root)
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
																		publishGucciCompletion(v27,fn25,flag14)
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
												Hub.gucciSeatRun=v27;Hub.gucciVehicleRun=v27;Hub.gucciSetupCharacter=v24
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

													table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child.Name == "SeatWeld" then
															child.Enabled = false
															child:Destroy()
															flag14 = true
														end
													end))

													table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child:IsA("LocalScript") and child.Name:lower():find("control") then
															child.Enabled = false
															child:Destroy()
														end
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

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.GucciSNO(root)
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
																		publishGucciCompletion(v27,fn25,flag14)
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
												Hub.gucciSeatRun=v27;Hub.gucciVehicleRun=v27;Hub.gucciSetupCharacter=v24
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

													table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child.Name == "SeatWeld" then
															child.Enabled = false
															child:Destroy()
															flag14 = true
														end
													end))

													table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
														if tbl16 == v27 and child:IsA("LocalScript") and child.Name:lower():find("control") then
															child.Enabled = false
															child:Destroy()
														end
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

															if now4 < n36 then
																tbl12.Teleport(v25, cFrame2)
															end

															flag17 = gucciType ~= "Train" and root
															parent2 = flag17 and root.Parent

															if parent2 then
																v28 = root:IsDescendantOf(workspace.PlotItems)
																parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.GucciSNO(root)
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
																		publishGucciCompletion(v27,fn25,flag14)
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
							Hub.gucciSeatRun=v27;Hub.gucciVehicleRun=v27;Hub.gucciSetupCharacter=v24
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

								table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
									if tbl16 == v27 and child.Name == "SeatWeld" then
										child.Enabled = false
										child:Destroy()
										flag14 = true
									end
								end))

								table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
									if tbl16 == v27 and child:IsA("LocalScript") and child.Name:lower():find("control") then
										child.Enabled = false
										child:Destroy()
									end
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

										if now4 < n36 then
											tbl12.Teleport(v25, cFrame2)
										end

										flag17 = gucciType ~= "Train" and root
										parent2 = flag17 and root.Parent

										if parent2 then
											v28 = root:IsDescendantOf(workspace.PlotItems)
											parent2 = v28 or tbl12.IsNetworkOwner(root) or tbl12.GucciSNO(root)
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
													publishGucciCompletion(v27,fn25,flag14)
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
												publishGucciCompletion(v27,fn25,flag14)
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
									publishGucciCompletion(v27,fn25,flag14)
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
									publishGucciCompletion(v27,fn25,flag14)
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
									publishGucciCompletion(v27,fn25,flag14)
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
									publishGucciCompletion(v27,fn25,flag14)
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
									publishGucciCompletion(v27,fn25,flag14)
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
									publishGucciCompletion(v27,fn25,flag14)
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

			tbl12.ResetGucciCharacter=function()
				if gucciOwnershipCleanup then gucciOwnershipCleanup() end
				tbl8.GucciAntiGrab=false
				Hub.gucciSetupCharacter=nil;Hub.gucciAcquiring=nil
				local thread=gucciThread;gucciThread=nil;flag12=nil
				if thread and thread~=coroutine.running() then pcall(Hub.nativeTask.cancel,thread);Hub.threads[thread]=nil end
				local record=tbl16
				Hub.gucciVerificationReason=nil
				local ok,err=pcall(fn23)
				if not ok then
					if record then
						clearGucciConfirmation(record,false)
						for _,connection in ipairs(record.Connections or {}) do pcall(function() connection:Disconnect() end) end
						if record.BP then pcall(function() record.BP:Destroy() end) end
					end
					tbl16=nil;warn("[Gucci respawn cleanup] "..tostring(err))
				end
			end
			tbl12.GucciWorkerRunning=function() return flag12==true end
			tbl12.SetGucciAntiGrab = function(arg)
				tbl8.GucciAntiGrab = arg and not flag11
				if not tbl8.GucciAntiGrab then
					Hub.gucciSetupCharacter=nil
					if gucciOwnershipCleanup then gucciOwnershipCleanup() end
					local ok,err=pcall(fn23)
					if not ok then warn("[Gucci pause cleanup] "..tostring(err)) end
					return
				end

				if flag12 then
					return
				end
				flag12 = true

				local launchedCharacter=Player.Character
				gucciThread=task.defer(function()
					local ok, result = pcall(fn24)
					if gucciThread~=coroutine.running() then return end
					local stillRequested=tbl8.GucciAntiGrab
					local cleaned,cleanupError=pcall(fn23)
					if not cleaned then warn("[Gucci worker cleanup] "..tostring(cleanupError)) end
					flag12=nil;gucciThread=nil
					if not cleaned then ok=false;result=cleanupError end
					if Player.Character~=launchedCharacter then return end

					if not ok and stillRequested then
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
		local workerThreads={}
		local function stopWorker(key)
			tbl8[key]=false;workers[key]=nil
			local thread=workerThreads[key];workerThreads[key]=nil
			if thread and thread~=coroutine.running() then pcall(Hub.nativeTask.cancel,thread);Hub.threads[thread]=nil end
			Hub.protectionStartupJobs[key]=nil
			if stopActions[key] then local ok,err=pcall(stopActions[key]);if not ok then warn("[Protection cleanup] "..tostring(err)) end end
		end
		local function runWorker(key,interval,action,cleanup)
			stopActions[key]=cleanup
			return function(on)
				Hub.requestSave()
				if not on then stopWorker(key);return end
				tbl8[key]=true
				if workers[key] then return end
				local token={};workers[key]=token;Hub.protectionStartupJobs[key]=token
				workerThreads[key]=task.defer(function()
					local appliedCharacter
					local ok,message=xpcall(function()
						while Hub.alive and not flag11 and tbl8[key] and workers[key]==token do
							local currentCharacter=Player.Character
							if key=="AntiBanana" or appliedCharacter~=currentCharacter then Hub.protectionStartupJobs[key]=token end
							action()
							if workers[key]~=token then return end
							appliedCharacter=currentCharacter
							if Hub.protectionStartupJobs[key]==token then Hub.protectionStartupJobs[key]=nil end
							task.wait(type(interval)=="function" and interval() or interval)
						end
					end,debug.traceback)
					if workers[key]~=token then return end
					workers[key]=nil;workerThreads[key]=nil
					if Hub.protectionStartupJobs[key]==token then Hub.protectionStartupJobs[key]=nil end
					if cleanup then pcall(cleanup) end
					if not ok then
						tbl8[key]=false;local control=workerControls[key]
						if control and control.Value then control:SetValue(false) end
						warn("[Source defense "..key.."] "..tostring(message));notify("Defense error",key.." stopped; check the console.",5)
					end
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
						Hub.teleportPart(v25, cFrame2)
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
		local bananaHip,bananaHum,bananaSuspension
		local function releaseBananaGucci(record)
			if not record or bananaSuspension~=record then return end
			bananaSuspension=nil
			local toggle=Toggles.AutoGucciBlobToggle
			if Hub.alive and not flag11 and toggle and toggle.Value
				and Player.Character==record.char and record.hum.Parent==record.char
				and record.hum.Health>0 and not tbl8.GucciAntiGrab then
				if Hub.resumeGucciAfterProtection then Hub.resumeGucciAfterProtection()
				else tbl12.SetGucciAntiGrab(true) end
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
		add("SourceAntiBanana","Anti Banana","AntiBanana",0.03,function()
			local char,root,hum,alive=charAlive()
			if not alive then restoreBanana();return end
			local leg=char:FindFirstChild("Right Leg") or char:FindFirstChild("Left Leg")
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
		defenseGroup:AddLabel("Anti Banana breaks character legs; respawn restores missing limbs.")

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
		defenseGroup:AddToggle("SourceLowFpsAntiLag",{Text="Auto Anti Lag (low FPS)",Default=false,Callback=function(on) lowFps=on;Hub.requestSave() end})
		settings:AddSlider("SourceLowFpsThreshold",{Text="Auto Anti Lag FPS threshold",Default=3,Min=1,Max=20,Rounding=0,Callback=function(value) fpsThreshold=value;Hub.requestSave() end})

		-- Supplied anti-invisibility is included by the adjoining module.
		-- Supplied correction-event auto reset, independent from the old periodic reset option.
		tbl8.AutoLeave=true;tbl9.KickFlags=0
		local lastFlag=0
		local corrections=ReplicatedStorage:FindFirstChild("GameCorrectionEvents")
		local correctionRemote=corrections and corrections:FindFirstChild("GameCorrectionsNotify")
		if correctionRemote then Hub.connect(correctionRemote.OnClientEvent,function(reason)
				if reason~="Flying" or Hub.gucciCharacterBusy(Player.Character) then return end
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
			if not alive or Hub.gucciCharacterBusy(char) then return end
			if loopCharacter~=char then loopCharacter=char;loopSaved=root.CFrame end
			Hub.teleportModel(char,CFrame.new(math.random(-1000,1000),-7.35,math.random(-1000,1000)))
		end,function()
			local char,root=tbl12.Char()
			if root and char==loopCharacter and loopSaved then Hub.teleportModel(char,loopSaved);root.AssemblyLinearVelocity=Vector3.zero end
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
		local sourceRespawnEpoch=0
		Hub.connect(Player.CharacterRemoving,function()
			sourceRespawnEpoch+=1
			for key in pairs(workers) do stopWorker(key) end
			Hub.protectionStartupJobs.SourceRespawn=nil
			tbl7.States["Anti Grab"]=false
			restoreCollision();restoreProperties();restoreBlob();clearInput();restoreBanana()
		end)
		Hub.connect(Player.CharacterAdded,function(char)
			sourceRespawnEpoch+=1;local ticket=sourceRespawnEpoch;local token={char=char}
			Hub.protectionStartupJobs.SourceRespawn=token
			task.spawn(function()
				while Hub.alive and not flag11 and sourceRespawnEpoch==ticket and Player.Character==char do
					local c,r,h=tbl12.Char()
					if c==char and r and h and h.Health>0 and r.Parent==char and h.Parent==char then
						for _,control in pairs(workerControls) do
							if control.Value and control.Callback then Hub.applyControl(control,true,function(fn,value) return pcall(fn,value) end) end
						end
						break
					end
					task.wait(0.1)
				end
				if Hub.protectionStartupJobs.SourceRespawn==token then Hub.protectionStartupJobs.SourceRespawn=nil end
			end)
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
		local touchStatus=DefenseExtra:AddLabel("Touch protection: off.")
		local function refreshTouchProtection()
			for part in pairs(touchRecords) do
				if not part.Parent or not touchMatch(part) then restoreTouch(part) end
			end
			if touchModes.paint or touchModes.poison then
				-- Same immediate named-part query as Resonance. No cancelled incremental scan.
				local ok,parts=pcall(function() return Workspace:QueryDescendants("BasePart#PaintPlayerPart") end)
				if ok then
					for _,part in ipairs(parts) do inspectTouch(part) end
					if touchModes.poison then
						local poisonOK,poisonParts=pcall(function() return Workspace:QueryDescendants("BasePart#PoisonHurtPart") end)
						if poisonOK then for _,part in ipairs(poisonParts) do inspectTouch(part) end
						else for _,part in ipairs(Workspace:GetDescendants()) do inspectTouch(part) end end
					end
				else
					for _,part in ipairs(Workspace:GetDescendants()) do inspectTouch(part) end
				end
			end
			local count=0;for _ in pairs(touchRecords) do count+=1 end
			touchStatus:SetText((touchModes.paint or touchModes.poison) and ("Touch protection: "..count.." effect parts blocked.") or "Touch protection: off.")
		end
		local function setTouchMode(key,on)
			touchModes[key]=on;touchEpoch+=1
			-- Switching either mode must rescan the other mode's still-active coverage.
			refreshTouchProtection();Hub.requestSave()
		end
		if Toggles.PaintDeleteToggle then Toggles.PaintDeleteToggle.Callback=function(on) setTouchMode("paint",on) end end
		if Toggles.PrivatePoisonTouch then Toggles.PrivatePoisonTouch.Callback=function(on) setTouchMode("poison",on) end end
		DefenseExtra:AddButton("Refresh touch protection",refreshTouchProtection)
		Hub.connect(Workspace.DescendantAdded,function(part) if touchModes.paint or touchModes.poison then inspectTouch(part) end end)
		Hub.connect(Workspace.DescendantRemoving,function(part) if touchRecords[part] then restoreTouch(part) end end)
		local touchElapsed=0
		Hub.connect(originalRunService.Heartbeat,function(dt)
			if not touchModes.paint and not touchModes.poison then touchElapsed=0;return end
			touchElapsed+=dt;if touchElapsed<1 then return end;touchElapsed=0
			-- Reconcile streaming, late names, reparenting, and changes made by other toggles.
			refreshTouchProtection()
		end)

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
			local char,root,hum,alive=charAlive()
			if not alive or Hub.gucciCharacterBusy(char) then return end
			if root.Position.Y>=10000 or root.Position.Y<=-500 then tbl12.Teleport(root,CFrame.new(0,15,0)) end
		end)

		-- Nearby explosion parts briefly anchor the local root, clear momentum, then release it.
		if Toggles.AntiExplosionToggle then Toggles.AntiExplosionToggle.Callback=function(on) tbl8.AntiExplosion=on;Hub.requestSave() end end
		local explosionAnchors={}
		Hub.connect(Workspace.ChildAdded,function(part)
			if not tbl8.AntiExplosion or part.Name~="Part" or not part:IsA("BasePart") then return end
			local char,root,hum,alive=charAlive()
			if not alive or Hub.gucciCharacterBusy(char) or (part.Position-root.Position).Magnitude>20 then return end
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
		local antiKickWanted=false
		local antiKickToken,antiKickThread
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
				local setupToken=antiKickToken
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
						local inPlot=localPlayer:FindFirstChild("InPlot")
						local ownedPlot=localPlayer:FindFirstChild("InOwnedPlot")
						if inPlot and inPlot.Value then
							Hub.antiKickStage="Waiting for an eligible plot"
							if Hub.protectionStartupJobs.AntiKick==setupToken then Hub.protectionStartupJobs.AntiKick=nil end
							while true do
								task.wait()
								if antiKickToken~=setupToken or not tbl8.AntiKick then return end
								if not (not inPlot.Parent or not inPlot.Value or (ownedPlot and ownedPlot.Value)) then
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
					if Hub.protectionStartupJobs.AntiKick==setupToken then Hub.protectionStartupJobs.AntiKick=nil end
					local currentRoot=select(2,tbl12.Char())
					local currentHitbox=currentRoot and currentRoot:FindFirstChild("RagdollTouchedHitbox")
					local sticky=v18 and v18.Parent and v18:FindFirstChild("StickyPart")
					local attached=sticky and sticky:FindFirstChild("StickyWeld")
					Hub.antiKickStage=currentHitbox and attached and attached.Part1==currentHitbox and attached.Enabled~=false and "Active" or "Waiting for shuriken attachment"
				end
			end
			antiKickStart=sourceAntiKickWorker
		end
		local function stopAntiKickWorker()
			antiKickToken=nil;tbl8.AntiKick=false;trackingEpoch+=1
			local thread=antiKickThread;antiKickThread=nil;antiKickRunning=false
			if thread and thread~=coroutine.running() then pcall(Hub.nativeTask.cancel,thread);Hub.threads[thread]=nil end
			Hub.protectionStartupJobs.AntiKick=nil
			local ok,err=pcall(clearKick);if not ok then warn("[Anti Kick cleanup] "..tostring(err)) end
		end
		local function setAntiKick(on)
			antiKickWanted=on==true;Hub.requestSave()
			if not antiKickWanted then stopAntiKickWorker();Hub.antiKickStage="Disabled";return end
			local char=Player.Character
			if antiKickRunning and antiKickToken and antiKickToken.char==char then return end
			if antiKickRunning then stopAntiKickWorker() end
			local token={char=char};antiKickToken=token;antiKickRunning=true
			Hub.protectionStartupJobs.AntiKick=token;Hub.antiKickStage="Waiting for character"
			antiKickThread=task.defer(function()
				local function current() return Hub.alive and not flag11 and antiKickWanted and antiKickToken==token and Player.Character==char end
				while current() do
					local c,r,h=tbl12.Char()
					if c==char and r and h and h.Parent==char and h.Health>0 and r:FindFirstChild("RagdollTouchedHitbox") then break end
					task.wait(0.1)
				end
				while current() do
					stickyEvents=ReplicatedStorage:FindFirstChild("PlayerEvents")
					stickyRemote=stickyEvents and stickyEvents:FindFirstChild("StickyPartEvent")
					if stickyRemote then
						tbl8.AntiKick=true;trackingEpoch+=1;local ticket=trackingEpoch
						Hub.scanDescendants(Workspace,trackPCLD,function() return current() and tbl8.AntiKick and trackingEpoch==ticket end)
						Hub.antiKickStage="Starting"
						local ok,message=xpcall(antiKickStart,debug.traceback)
						if not current() then return end
						tbl8.AntiKick=false;pcall(clearKick)
						if Hub.protectionStartupJobs.AntiKick==token then Hub.protectionStartupJobs.AntiKick=nil end
						Hub.antiKickStage="Retrying";Hub.lastAntiKickError=not ok and tostring(message) or "Worker ended; restarting."
						if not ok then warn("[Source Anti Kick] "..tostring(message)) end
					else
						Hub.antiKickStage="Waiting for StickyPartEvent"
						if Hub.protectionStartupJobs.AntiKick==token then Hub.protectionStartupJobs.AntiKick=nil end
					end
					task.wait(1)
				end
				if antiKickToken==token then
					antiKickToken=nil;antiKickThread=nil;antiKickRunning=false
					if Hub.protectionStartupJobs.AntiKick==token then Hub.protectionStartupJobs.AntiKick=nil end
				end
			end)
		end
		Hub.connect(Player.CharacterRemoving,function()
			stopAntiKickWorker();Hub.antiKickStage=antiKickWanted and "Waiting for respawn" or "Disabled"
		end)
		Hub.connect(Player.CharacterAdded,function()
			if antiKickWanted and Toggles.ShurikenAntiKick and Toggles.ShurikenAntiKick.Value then setAntiKick(true) end
		end)
		if Toggles.ShurikenAntiKick then Toggles.ShurikenAntiKick.Callback=setAntiKick end
		settings:AddToggle("SourceAntiKickHighlight",{Text="Anti Kick, highlight shuriken",Default=false,Callback=function(on) tbl7.AntiKickSettings.Highlight=on;if updateAntiKickAppearance then updateAntiKickAppearance() end;Hub.requestSave() end})
		for _,info in ipairs({{"SourceAntiKickFillAlpha","Anti Kick, fill transparency","HighlightFT",0.5},{"SourceAntiKickOutlineAlpha","Anti Kick, outline transparency","HighlightOT",0},{"SourceAntiKickToyAlpha","Anti Kick, shuriken transparency","Transparency",0.9}}) do
			local property=info[3]
			settings:AddSlider(info[1],{Text=info[2],Default=info[4],Min=0,Max=1,Rounding=2,Callback=function(value) tbl7.AntiKickSettings[property]=value;if updateAntiKickAppearance then updateAntiKickAppearance() end;Hub.requestSave() end})
		end
		Hub.cleanup(function() antiKickWanted=false;stopAntiKickWorker();Hub.antiKickStage=nil;highlight:Destroy() end)

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

		-- Original train/burger interaction, with bounded waits and unconditional cleanup.
		do
			local busy=false
			local group=Tabs.Misc:AddRightGroupbox("Train")
			local status=group:AddLabel("Train removal is idle.")
			group:AddButton("Destroy Train",function()
				if busy then return end
				if tbl8.GucciAntiGrab or (Toggles.AutoGucciBlobToggle and Toggles.AutoGucciBlobToggle.Value) then
					notify("Train","Disable Gucci before using Destroy Train.",5);return
				end
				busy=true
				task.spawn(function()
					local char,root,hum=tbl12.Char()
					local saved=root and root.CFrame
					local oldHeight=Workspace.FallenPartsDestroyHeight
					local burger,seat
					local workers={}
					local function current()
						return Hub.alive and not flag11 and Player.Character==char and root and root.Parent==char and hum and hum.Health>0
							and not tbl8.GucciAntiGrab and not (Toggles.AutoGucciBlobToggle and Toggles.AutoGucciBlobToggle.Value)
					end
					local function waitFor(check,seconds)
						local deadline=os.clock()+seconds
						repeat if not current() then error("Character changed or Gucci enabled.") end
							if check() then return end;task.wait()
						until os.clock()>=deadline
						error("Train interaction timed out.")
					end
					local function invoke(remote,...)
						local args=table.pack(...);local done,success,message=false
						local worker=task.spawn(function() success,message=pcall(Hub.invoke,remote,table.unpack(args,1,args.n));done=true end)
						table.insert(workers,worker);waitFor(function() return done end,2)
						if not success then error(tostring(message)) end
					end
					local ok,message=xpcall(function()
						if not current() then error("Character not ready.") end
						local object=train:FindFirstChild("Object")
						local model=object and object:FindFirstChild("ObjectModel")
						seat=model and (model:FindFirstChildWhichIsA("Seat",true) or model:FindFirstChildWhichIsA("VehicleSeat",true))
						if not seat or not Hub.canAffect(seat) then error("Train seat is unavailable.") end
						if seat.Occupant and seat.Occupant~=hum then error("Train is occupied.") end
						local arm=char:FindFirstChild("Left Arm")
						local grip=arm and arm:FindFirstChild("LeftGripAttachment")
						if not grip then error("Left grip attachment is unavailable.") end
						status:SetText("Waiting for train seat.");hum.Sit=false;seat:Sit(hum)
						waitFor(function() return seat.Parent and seat.Occupant==hum end,1.5)
						burger=tbl12.SpawnToy("FoodHamburger")
						local hold=burger and burger:WaitForChild("HoldPart",1)
						local holdRemote=hold and hold:WaitForChild("HoldItemRemoteFunction",0.45)
						local dropRemote=hold and hold:WaitForChild("DropItemRemoteFunction",0.45)
						local constraint=hold and hold:WaitForChild("RigidConstraint",0.45)
						if not burger then error("Hamburger did not spawn; server may be busy or spawning is unavailable.") end
						if not holdRemote or not dropRemote or not constraint then error("Hamburger hold/drop components did not replicate in time.") end
						-- Like Resonance, hold requests must be retried until the grip confirms.
						local nextHold=0
						waitFor(function()
							if constraint.Parent and constraint.Attachment1==grip then return true end
							if os.clock()>=nextHold then
								nextHold=os.clock()+0.15
								local worker=task.spawn(function() pcall(Hub.invoke,holdRemote,burger,char) end)
								table.insert(workers,worker)
							end
							return false
						end,1)
						invoke(dropRemote,burger,CFrame.new(0,-150,0),Vector3.zero)
						task.wait(0.5);if not current() or seat.Occupant~=hum then error("Train seat was lost.") end
						Workspace.FallenPartsDestroyHeight=-100
						tbl12.Teleport(root,CFrame.new(0,-250,0));task.wait(0.5)
						if not current() then error("Character changed.") end
						hum.Sit=false;task.wait(0.25)
						status:SetText("Train removal interaction completed; checking server result.")
					end,debug.traceback)
					for _,worker in ipairs(workers) do if coroutine.status(worker)~="dead" then pcall(Hub.nativeTask.cancel,worker) end end
					Workspace.FallenPartsDestroyHeight=oldHeight
					if Player.Character==char and root and root.Parent==char and hum and hum.Health>0 then
						if hum.SeatPart==seat then hum.Sit=false end
						if saved and not tbl8.GucciAntiGrab and not (Toggles.AutoGucciBlobToggle and Toggles.AutoGucciBlobToggle.Value) then tbl12.Teleport(root,saved) end
					end
					pcall(tbl12.DestroyToy,burger);busy=false
					if not ok then status:SetText("Train removal stopped; position restored.");notify("Train",tostring(message):match("^[^\n]+") or "Interaction failed.",5) end
				end)
			end)
		end

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
					if saved and root and root.Parent then Hub.teleportPart(root, saved);root.AssemblyLinearVelocity=Vector3.zero end
				end)
			end end
		Hub.sourceGucci={remove=tbl12.RemoveGucci,set=tbl12.SetGucciAntiGrab,state=tbl8,settings=tbl9,helpers=tbl12}
		DefenseExtra:AddToggle("SourceRagdollOnRemoveGucci",{Text="Ragdoll target during Remove Gucci",Default=false,Callback=function(on) tbl8.RagdollInRG=on;Hub.requestSave() end})
		local status=DefenseExtra:AddLabel("Gucci: off")
		-- GUCCI NOTIFICATION STATES BEGIN
		local previousStatus=Hub.updateGucciStatus
		local lastPhase
		local notices={}
		local messages={
			Starting="Gucci starting; preparing the seat/weld controller.",
			["Waiting for leg removal"]="Anti Banana is removing legs. Gucci starts once that finishes.",
			Retrying="Gucci retrying; waiting for seat/weld confirmation.",
			Verifying="Gucci is completing the original setup sequence.",
			Active="Gucci active. Original setup completed.",
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
			local cooldown=(phase=="Active" or phase=="Retrying") and 30 or 2
			if repeated then return end
			if now-(notices[phase] or -math.huge)<cooldown then return end
			notices[phase]=now
			notify("Gucci",message or messages[phase] or ("Gucci: "..phase),4,
				phase=="Active" and "success" or phase=="Error" and "danger" or phase=="Retrying" and "warning" or "info")
		end
		Hub.updateGucciStatus=function()
			if tbl8.GucciAntiGrab then Hub.reportGucciStatus(Hub.gucciStage or "Starting") end
		end
		-- GUCCI NOTIFICATION STATES END
		-- Gucci depends only on the current character's Anti Banana leg-removal pass.
		local gucciDesired,gucciStartPending=false,false
		local gucciStartWorker
		local function legRemovalPending()
			local toggle=Toggles.SourceAntiBanana
			if not toggle or not toggle.Value then return false end
			local char=Player.Character
			return char and (char:FindFirstChild("Right Leg")~=nil or char:FindFirstChild("Left Leg")~=nil
				or Hub.protectionStartupJobs.AntiBanana~=nil or (bananaSuspension and bananaSuspension.char==char)) or false
		end
		local function pauseGucci()
			if tbl8.GucciAntiGrab then tbl12.SetGucciAntiGrab(false) end
		end
		local function requestGucciStart(reason)
			if not gucciDesired or flag11 or not Hub.alive then return end
			gucciStartPending=true
			Hub.gucciWaitingReason=legRemovalPending() and "Waiting for Anti Banana leg removal to finish." or (reason or "Waiting for the current character.")
			if Hub.reportGucciStatus then Hub.reportGucciStatus(legRemovalPending() and "Waiting for leg removal" or "Starting",Hub.gucciWaitingReason) end
			if gucciStartWorker then return end
			gucciStartWorker=task.defer(function()
				while Hub.alive and not flag11 and gucciDesired and gucciStartPending do
					local char,root,hum=tbl12.Char()
					local held=Player:FindFirstChild("IsHeld")
					local legs=legRemovalPending()
					local previous=tbl12.GucciWorkerRunning()
					local ready=not Hub.configLoading and not legs and not previous
						and char and root and hum and hum.Health>0 and root.Parent==char and hum.Parent==char and not (held and held.Value)
					if ready then
						gucciStartPending=false;Hub.gucciWaitingReason=nil
						if Hub.stopBlobFlight then Hub.stopBlobFlight() end
						Hub.reportGucciStatus("Starting");tbl12.SetGucciAntiGrab(true)
						break
					end
					Hub.gucciWaitingReason=legs and "Waiting for Anti Banana leg removal to finish."
						or previous and "Previous Gucci worker is still exiting."
						or "Waiting for the current character to be ready."
					task.wait(0.1)
				end
				gucciStartWorker=nil
			end)
		end
		local function setGucci(on)
			gucciDesired=on==true and not flag11
			if gucciDesired then
				if not tbl8.GucciAntiGrab or gucciStartPending then requestGucciStart() end
			else
				gucciStartPending=false;Hub.gucciWaitingReason=nil
				pauseGucci();Hub.reportGucciStatus("Disabled")
			end
			Hub.requestSave()
		end
		Hub.resumeGucciAfterProtection=function()
			local toggle=Toggles.AutoGucciBlobToggle
			if gucciDesired and toggle and toggle.Value and (not tbl8.GucciAntiGrab or gucciStartPending) then requestGucciStart() end
		end
		Hub.beginProtectionChange=function(control)
			-- Anti-kick and unrelated settings must never stop or gate Gucci.
			if control.Id~="SourceAntiBanana" then return end
			if gucciDesired and legRemovalPending() then pauseGucci();requestGucciStart() end
			return function() if gucciDesired and not tbl8.GucciAntiGrab then requestGucciStart() end end
		end
		Hub.connect(Player.CharacterRemoving,function()
			local thread=gucciStartWorker;gucciStartWorker=nil
			if thread and thread~=coroutine.running() then pcall(Hub.nativeTask.cancel,thread);Hub.threads[thread]=nil end
			gucciStartPending=false;tbl12.ResetGucciCharacter()
			Hub.gucciWaitingReason=gucciDesired and "Waiting for respawn." or nil
		end)
		Hub.connect(Player.CharacterAdded,function()
			if gucciDesired then pauseGucci();requestGucciStart() end
		end)
		Hub.cleanup(function()
			gucciDesired=false;gucciStartPending=false
			Hub.beginProtectionChange=nil;Hub.resumeGucciAfterProtection=nil;Hub.gucciWaitingReason=nil
		end)
		-- Replace the old callbacks, not a second competing controller.
		Toggles.AutoGucciBlobToggle.Callback=setGucci
		startAntiGucci=function() if Toggles.AutoGucciBlobToggle.Value then setGucci(true) end end
		stopAntiGucci=function() setGucci(false) end
		if Toggles.AutoGucciTrainToggle then
			Toggles.AutoGucciTrainToggle.Callback=function(on)
				if on then pauseGucci();tbl9.GucciType="Train";Toggles.AutoGucciBlobToggle:SetValue(true)
				elseif tbl9.GucciType=="Train" then Toggles.AutoGucciBlobToggle:SetValue(false) end
			end
			startAntiGucciTrain=function() if Toggles.AutoGucciTrainToggle.Value then pauseGucci();tbl9.GucciType="Train";setGucci(true) end end
			stopAntiGucciTrain=function() if tbl9.GucciType=="Train" then setGucci(false) end end
		end
		DefenseExtra:AddDropdown("SourceGucciVehicle",{Text="Gucci vehicle",Values={"CreatureBlobman","TractorGreen","SantaSleigh","Train"},Default=1,Callback=function(value)
			if tbl9.GucciType~=value then pauseGucci();tbl9.GucciType=value;if gucciDesired then requestGucciStart() end end
			Hub.requestSave()
		end})
		DefenseExtra:AddButton({Text="Stop Gucci and remove its toy",Func=function() Toggles.AutoGucciBlobToggle:SetValue(false) end})
		Hub.cleanup(function()
			flag11=true;tbl12.SetGucciAntiGrab(false)
			for model in pairs(spawned) do tbl12.DestroyToy(model) end
			for _,connection in pairs(runtimeConnections) do connection:Disconnect() end
			for connection in pairs(sourceConnections) do connection:Disconnect() end
			Hub.sourceDefense=nil
			Hub.sourceGucci=nil
			Hub.reportGucciStatus=nil;Hub.gucciVerifiedRun=nil;Hub.gucciVerificationReason=nil
			Hub.gucciSeatRun=nil;Hub.gucciVehicleRun=nil;Hub.gucciSetupCharacter=nil;Hub.gucciAcquiring=nil
		end)
	end)()
end

-- Source Anti Invis behavior: repair foreign root mass and disabled seat welds locally.
do
	(function()
		local enabled=false
		local savedMass,savedWeld={},{}
		local elapsed=0
		local function restore()
			for part,value in pairs(savedMass) do pcall(function() if part.Parent then part.Massless=value end end);savedMass[part]=nil end
			for weld,value in pairs(savedWeld) do pcall(function() if weld.Parent then weld.Enabled=value end end);savedWeld[weld]=nil end
		end
		DefenseGroup:AddToggle("SourceAntiInvis",{Text="Anti Invis",Default=false,Callback=function(on) enabled=on;if not on then restore() end;Hub.requestSave() end})
		Hub.connect(RunService.Heartbeat,function(dt)
			if not enabled then return end
			elapsed+=dt;if elapsed<0.1 then return end;elapsed=0
			for _,other in ipairs(Players:GetPlayers()) do if other~=Player then
					local char=other.Character
					local root=char and char:FindFirstChild("HumanoidRootPart")
					local hum=char and char:FindFirstChildOfClass("Humanoid")
					if root then if savedMass[root]==nil then savedMass[root]=root.Massless end;root.Massless=false end
					local seat=hum and hum.Sit and hum.SeatPart
					local weld=seat and seat:FindFirstChild("SeatWeld")
					if weld and not weld.Enabled and not Hub.isGucciReserved(seat) then if savedWeld[weld]==nil then savedWeld[weld]=weld.Enabled end;weld.Enabled=true end
				end end
			for part in pairs(savedMass) do if not part.Parent then savedMass[part]=nil end end
			for weld in pairs(savedWeld) do if not weld.Parent then savedWeld[weld]=nil end end
		end)
		Hub.cleanup(function() enabled=false;restore() end)
	end)()
end

-- Feature pack: standalone flight and local humanoid controls.
do
	(function()
		local group=Tabs.Player:AddLeftGroupbox("Flight")
		local enabled=false
		local speed=50
		local flight
		local function stop()
			if not flight then Hub.characterFlightActive=false;return end
			local old=flight;flight=nil;Hub.characterFlightActive=false
			for _,object in ipairs({old.velocity,old.gyro}) do
				Hub.instances[object],Hub.assetTargets[object]=nil,nil;object:Destroy()
			end
			pcall(function()
				if old.hum.Parent then
					old.hum.PlatformStand=old.platform
					old.hum.AutoRotate=old.rotate
				end
			end)
		end
		local function update()
			if not enabled then stop();return end
			local char=Player.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health<=0 or hum.SeatPart or root.Anchored or Hub.safeZoneLoopActive or Hub.gucciCharacterBusy(char) then stop();return end
			if flight and (flight.char~=char or flight.root~=root or not flight.velocity.Parent or not flight.gyro.Parent) then stop() end
			if not flight then
				if Hub.stopBlobFlight then Hub.stopBlobFlight() end
				flight={char=char,root=root,hum=hum,platform=hum.PlatformStand,rotate=hum.AutoRotate}
				flight.velocity=Hub.new("BodyVelocity",root);flight.velocity.Name="ArrivaFlightVelocity"
				flight.velocity.MaxForce=Vector3.new(9e9,9e9,9e9);flight.velocity.Velocity=Vector3.zero
				flight.gyro=Hub.new("BodyGyro",root);flight.gyro.Name="ArrivaFlightGyro"
				flight.gyro.MaxTorque=Vector3.new(9e9,9e9,9e9);flight.gyro.P=90000;flight.gyro.CFrame=Hub.teleportFrame(root)
				hum.PlatformStand=true;hum.AutoRotate=false;Hub.characterFlightActive=true
			end
			local camera=Workspace.CurrentCamera
			if not camera then flight.velocity.Velocity=Vector3.zero;return end
			local move=Vector3.zero
			if not UserInputService:GetFocusedTextBox() and not Hub.keybindCaptureActive then
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then move+=camera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then move-=camera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then move-=camera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then move+=camera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.E) then move+=camera.CFrame.UpVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move-=camera.CFrame.UpVector end
			end
			if move.Magnitude>1 then move=move.Unit end
			flight.velocity.Velocity=move*speed;flight.gyro.CFrame=camera.CFrame
		end
		Hub.sampleCharacterFlight=update
		group:AddToggle("PackCharacterFlight",{Text="Flight",Default=false,Callback=function(on) enabled=on;if not on then stop() end end})
		group:AddSlider("PackCharacterFlightSpeed",{Text="Flight speed",Default=50,Min=5,Max=1000,Rounding=0,Callback=function(value) speed=value end})
		Hub.keybindGroups.actions:AddLabel("Flight"):AddKeyPicker("PackFlightKey",{Default="H",Text="Flight",Callback=function()
			if not UserInputService:GetFocusedTextBox() then Toggles.PackCharacterFlight:SetValue(not enabled) end
		end})
		table.insert(Hub.keybindDefinitions,{id="PackFlightKey",label="Flight",default="H"})
		Hub.connect(RunService.PreSimulation or RunService.Heartbeat,update)
		Hub.connect(Player.CharacterRemoving,stop)
		Hub.cleanup(function() enabled=false;stop();Hub.sampleCharacterFlight=nil end)
	end)();
	(function()
		local group=Tabs.Visual:AddRightGroupbox("Water Controls")
		local swimOn=false
		local states={}
		local function restoreSwim()
			for hum,value in pairs(states) do pcall(function() if hum.Parent then hum:SetStateEnabled(Enum.HumanoidStateType.Swimming,value) end end) end
			table.clear(states)
		end
		local function sample()
			if not swimOn then return end
			local char=Player.Character
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health<=0 then return end
			if states[hum]==nil then states[hum]=hum:GetStateEnabled(Enum.HumanoidStateType.Swimming) end
			hum:SetStateEnabled(Enum.HumanoidStateType.Swimming,false)
			if not hum.SeatPart and hum:GetState()==Enum.HumanoidStateType.Swimming then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
		end
		Hub.sampleNoSwim=sample
		group:AddToggle("PackNoSwimming",{Text="Non-swimmable water",Default=false,Callback=function(on) swimOn=on;if on then sample() else restoreSwim() end end})
		Hub.connect(RunService.Heartbeat,sample)
		Hub.connect(Player.CharacterRemoving,restoreSwim)
		Hub.cleanup(function() swimOn=false;restoreSwim();Hub.sampleNoSwim=nil end)
	end)()
end
-- End player feature pack

-- Feature pack: line textures, gradient colors and held-object information.
do
	(function()
		local group=Tabs.Grab:AddRightGroupbox("Line Texture & Gradient")
		local textures={Laser="rbxassetid://8922958725",Chain="rbxassetid://81358145120405",["Chain 2"]="rbxassetid://132910145874066",
			["Chain 3"]="rbxassetid://128466395060514",["Chain 4"]="rbxassetid://73368670987191",Pulse="rbxassetid://82163767314193",
			Rope="rbxassetid://78999022056924",Dots="rbxassetid://9169659357",Bubbles="rbxassetid://1249690853",Spring="rbxassetid://18837732116",
			Gamepass="rbxassetid://8933355899",["Non-Gamepass"]="rbxassetid://8933346550"}
		local names={};for name in pairs(textures) do table.insert(names,name) end;table.sort(names)
		local textured,gradient,share=false,false,false
		local choice=names[1]
		local defaults={"FF0000","FFA500","FFFF00","00FF00","00FFFF","0000FF","AA00FF","FFFFFF","FFFFFF"}
		local colors={}
		for index,hex in ipairs(defaults) do colors[index]=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)) end
		local saved={};local lastSent=-math.huge
		local function restore(beam)
			local record=saved[beam];if not record then return end;saved[beam]=nil
			pcall(function() if beam.Parent then
					if record.textureOwned then beam.Texture=record.texture end
					if record.colorOwned then beam.Color=record.color end
				end end)
		end
		local function sequence()
			local keys={};for index,color in ipairs(colors) do keys[index]=ColorSequenceKeypoint.new((index-1)/8,color) end
			return ColorSequence.new(keys)
		end
		function Hub.sampleLineStyles()
			local model=Workspace:FindFirstChild("GrabParts")
			for beam in pairs(saved) do
				if not model or not beam:IsDescendantOf(model) or (not textured and not gradient) then restore(beam) end
			end
			if not textured and not gradient then return end
			local color=gradient and sequence() or nil
			for _,beam in ipairs(model and model:GetDescendants() or {}) do
				if beam:IsA("Beam") then
					if not saved[beam] then saved[beam]={} end
					local record=saved[beam]
					if textured then
						if not record.textureOwned then record.texture=beam.Texture;record.textureOwned=true end
						beam.Texture=textures[choice]
					elseif record.textureOwned then beam.Texture=record.texture;record.textureOwned=false end
					if gradient then
						if not record.colorOwned then record.color=beam.Color;record.colorOwned=true end
						beam.Color=color
					elseif record.colorOwned then beam.Color=record.color;record.colorOwned=false end
				end
			end
			if share and gradient and os.clock()-lastSent>=0.5 then
				local events=ReplicatedStorage:FindFirstChild("DataEvents")
				local remote=events and events:FindFirstChild("UpdateLineColorsEvent")
				if remote then lastSent=os.clock();Hub.fire(remote,color,table.unpack(colors)) end
			end
		end
		group:AddDropdown("PackLineTexture",{Text="Line texture",Values=names,Default=1,Callback=function(value) choice=value end})
		group:AddToggle("PackCustomLine",{Text="Custom line texture",Default=false,Callback=function(on) textured=on;Hub.sampleLineStyles() end})
		group:AddToggle("PackGradientLine",{Text="Gradient line",Default=false,Callback=function(on)
			gradient=on
			if on then
				for _,id in ipairs({"ToolLineTint","ToolRainbowLine"}) do if Toggles[id] then Toggles[id]:SetValue(false) end end
			end
			Hub.sampleLineStyles()
		end})
		group:AddToggle("PackShareLineGradient",{Text="Share gradient with server",Default=false,Callback=function(on) share=on end})
		for index=1,9 do
			local position=index
			group:AddInput("PackLineColor"..index,{Text=index==9 and "End color hex" or "Gradient color "..index,Default=defaults[index],Finished=true,Callback=function(value)
				local hex=tostring(value):gsub("#","")
				if #hex==6 and hex:match("^%x+$") then colors[position]=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)) end
			end})
		end
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed>=0.1 then elapsed=0;Hub.sampleLineStyles() end end)
		Hub.cleanup(function() textured,gradient,share=false,false,false;for beam in pairs(saved) do restore(beam) end;Hub.sampleLineStyles=nil end)
	end)();
	(function()
		local group=Tabs.Grab:AddRightGroupbox("Held Object")
		local enabled=false
		local label=group:AddLabel("Object information off.")
		function Hub.sampleHeldInformation()
			if not enabled then return end
			local model=Workspace:FindFirstChild("GrabParts")
			local grab=model and model:FindFirstChild("GrabPart",true)
			local weld=grab and grab:FindFirstChildWhichIsA("WeldConstraint")
			local part=weld and weld.Part1
			if not part or not part:IsA("BasePart") or not part.Parent then label:SetText("Nothing held.");return end
			local root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
			local owner=Hub.playerOf(part)
			label:SetText(string.format("%s | %.1f studs | mass %.1f | %s | %s",part.Name,root and (Hub.teleportFrame(root).Position-part.Position).Magnitude or 0,
				part.AssemblyMass,part.Anchored and "anchored" or "free",owner and owner.Name or "unassigned"))
		end
		group:AddToggle("PackHeldInformation",{Text="Grabbed object information",Default=false,Callback=function(on) enabled=on;if on then Hub.sampleHeldInformation() else label:SetText("Object information off.") end end})
		group:AddButton({Text="Copy held-object path",Func=function()
			local model=Workspace:FindFirstChild("GrabParts")
			local grab=model and model:FindFirstChild("GrabPart",true)
			local weld=grab and grab:FindFirstChildWhichIsA("WeldConstraint")
			local part=weld and weld.Part1
			if part and setclipboard then setclipboard(part:GetFullName()) end
		end})
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed>=0.25 then elapsed=0;Hub.sampleHeldInformation() end end)
		Hub.cleanup(function() enabled=false;Hub.sampleHeldInformation=nil end)
	end)()
end
-- End line and object feature pack

-- Feature pack: sticky and blackhole overlays.
do
	(function()
		local group=Tabs.Visual:AddRightGroupbox("World ESP")
		local enabled={sticky=false,blackhole=false}
		local entries={};local watcher;local epoch=0
		local distance,labels,through=1200,true,true
		local tint=Color3.fromRGB(120,180,255)
		local fill,outline=0.8,0.2
		local function clear(object)
			local entry=entries[object];if not entry then return end;entries[object]=nil
			for _,visual in ipairs({entry.highlight,entry.gui}) do Hub.instances[visual],Hub.assetTargets[visual]=nil,nil;visual:Destroy() end
		end
		local function kind(object)
			if not object:IsA("BasePart") then return end
			if object.Name=="StickyPart" then return "sticky" end
			if object.Name=="BlackHoleKick" or object.Name=="StayedBH" then return "blackhole" end
			if object.Name~="Hole" then return end
			local parent=object.Parent
			while parent and parent~=Workspace do
				if parent.Name=="BlackHoleKick" or parent.Name=="StayedBH" then return "blackhole" end
				parent=parent.Parent
			end
		end
		local function inspect(object)
			local name=kind(object)
			if not name or not enabled[name] or entries[object] then return end
			local highlight=Hub.new("Highlight",object);highlight.Adornee=object
			local gui=Hub.new("BillboardGui",object);gui.Adornee=object;gui.Size=UDim2.fromOffset(180,28);gui.StudsOffset=Vector3.new(0,2,0)
			local text=Hub.new("TextLabel",gui);text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
			text.TextSize=14;text.Font=Enum.Font.GothamBold;text.TextColor3=Color3.new(1,1,1);text.TextStrokeTransparency=0
			text.Text=name=="sticky" and "Sticky" or "Blackhole"
			entries[object]={highlight=highlight,gui=gui,kind=name}
		end
		function Hub.sampleWorldESP()
			local root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
			for object,entry in pairs(entries) do
				if not object.Parent or not enabled[entry.kind] then clear(object)
				else
					local near=root and (object.Position-Hub.teleportFrame(root).Position).Magnitude<=distance
					entry.highlight.Enabled=near and true or false
					entry.highlight.FillColor=tint;entry.highlight.OutlineColor=tint
					entry.highlight.FillTransparency=fill;entry.highlight.OutlineTransparency=outline
					entry.highlight.DepthMode=through and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
					entry.gui.Enabled=near and labels and true or false;entry.gui.AlwaysOnTop=through;entry.gui.MaxDistance=distance
				end
			end
		end
		local function refresh()
			epoch+=1;local ticket=epoch
			if watcher then watcher:Disconnect();Hub.connections[watcher]=nil;watcher=nil end
			Hub.sampleWorldESP()
			if enabled.sticky or enabled.blackhole then
				watcher=Hub.connect(Workspace.DescendantAdded,inspect)
				Hub.scanDescendants(Workspace,inspect,function() return epoch==ticket and (enabled.sticky or enabled.blackhole) end)
			end
		end
		group:AddToggle("PackStickyESP",{Text="Sticky ESP",Default=false,Callback=function(on) enabled.sticky=on;refresh() end})
		group:AddToggle("PackBlackholeESP",{Text="Blackhole ESP",Default=false,Callback=function(on) enabled.blackhole=on;refresh() end})
		group:AddToggle("PackWorldESPNames",{Text="World ESP labels",Default=true,Callback=function(on) labels=on end})
		group:AddToggle("PackWorldESPThrough",{Text="World ESP through walls",Default=true,Callback=function(on) through=on end})
		group:AddSlider("PackWorldESPDistance",{Text="World ESP distance",Default=1200,Min=50,Max=5000,Rounding=0,Callback=function(value) distance=value end})
		group:AddSlider("PackWorldESPFill",{Text="World fill transparency",Default=80,Min=0,Max=100,Rounding=0,Callback=function(value) fill=value/100 end})
		group:AddSlider("PackWorldESPOutline",{Text="World outline transparency",Default=20,Min=0,Max=100,Rounding=0,Callback=function(value) outline=value/100 end})
		group:AddInput("PackWorldESPColor",{Text="World ESP color hex",Default="78B4FF",Finished=true,Callback=function(value)
			local hex=tostring(value):gsub("#","")
			if #hex==6 and hex:match("^%x+$") then tint=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)) end
		end})
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed>=0.25 then elapsed=0;Hub.sampleWorldESP() end end)
		Hub.cleanup(function() enabled={};epoch+=1;for object in pairs(entries) do clear(object) end;Hub.sampleWorldESP=nil end)
	end)()
end
-- End world overlay feature pack

-- Feature pack: reversible tools for the active own-toy group.
do
	(function()
		local group=Tabs.Fun:AddRightGroupbox("Group Appearance")
		local noclip,highlight=false,false
		local saved,visuals={},{}
		local function restore(part)
			local old=saved[part];if old==nil then return end;saved[part]=nil
			pcall(function() if part.Parent then part.CanCollide=old end end)
		end
		local function clear(model)
			local visual=visuals[model];if not visual then return end;visuals[model]=nil
			Hub.instances[visual],Hub.assetTargets[visual]=nil,nil;visual:Destroy()
		end
		function Hub.sampleGroupAppearance()
			local wanted,models={},{}
			if (noclip or highlight) and Hub.getOwnToySelection then
				local _,members=Hub.getOwnToySelection()
				local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
				for model in pairs(members or {}) do
					if model.Parent==folder and model:IsA("Model") and not model:FindFirstChildOfClass("Humanoid") then
						models[model]=true
						for _,part in ipairs(model:GetDescendants()) do
							if part:IsA("BasePart") and not part:IsA("Seat") and not part:IsA("VehicleSeat") then
								local safe=true
								for _,connected in ipairs(part:GetConnectedParts(true)) do if not connected:IsDescendantOf(model) then safe=false;break end end
								if safe then wanted[part]=true end
							end
						end
					end
				end
			end
			for part in pairs(saved) do if not noclip or not wanted[part] then restore(part) end end
			for model in pairs(visuals) do if not highlight or not models[model] then clear(model) end end
			if noclip then for part in pairs(wanted) do if saved[part]==nil then saved[part]=part.CanCollide end;part.CanCollide=false end end
			if highlight then for model in pairs(models) do if not visuals[model] then
						local visual=Hub.new("Highlight",model);visual.Adornee=model;visual.FillTransparency=0.8
						visual.OutlineColor=Color3.fromRGB(100,200,255);visuals[model]=visual
					end end end
		end
		group:AddToggle("PackGroupNoclip",{Text="Noclip named group",Default=false,Callback=function(on) noclip=on;Hub.sampleGroupAppearance() end})
		group:AddToggle("PackGroupHighlight",{Text="Highlight named group",Default=false,Callback=function(on) highlight=on;Hub.sampleGroupAppearance() end})
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt) elapsed+=dt;if elapsed>=0.25 then elapsed=0;Hub.sampleGroupAppearance() end end)
		Hub.cleanup(function() noclip,highlight=false,false;for part in pairs(saved) do restore(part) end;for model in pairs(visuals) do clear(model) end;Hub.sampleGroupAppearance=nil end)
	end)()
end
-- End own-group feature pack



-- Feature pack: visible camera aim assistance, without a global remote hook.
do
	(function()
		local group=Tabs.Target:AddRightGroupbox("Aim Assist")
		local enabled,always,selectedOnly,visibleOnly,showCircle=false,false,false,true,false
		local partName,radius,smoothing="Head",150,12
		local gui,circle
		local function clearCircle()
			if gui then Hub.instances[gui]=nil;gui:Destroy();gui,circle=nil,nil end
		end
		local function canTarget(target,character)
			return Hub.loopTargetReady(target,character) and (not selectedOnly or Hub.isSelectedTarget(target))
		end
		function Hub.findAimTarget(camera,mousePosition)
			local best,bestDistance=nil,radius
			local localChar=Player.Character
			local params
			if visibleOnly then
				params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances=localChar and {localChar} or {};params.IgnoreWater=true
			end
			for _,target in ipairs(Players:GetPlayers()) do
				local char=target.Character
				local part=char and char:FindFirstChild(partName)
				if part and canTarget(target,char) then
					local screen,onScreen=camera:WorldToViewportPoint(part.Position)
					if onScreen and screen.Z>0 then
						local distance=(Vector2.new(screen.X,screen.Y)-mousePosition).Magnitude
						if distance<bestDistance then
							local hit=params and Workspace:Raycast(camera.CFrame.Position,part.Position-camera.CFrame.Position,params)
							if not hit or hit.Instance:IsDescendantOf(char) then best,bestDistance=part,distance end
						end
					end
				end
			end
			return best
		end
		local function draw(mousePosition)
			if not enabled or not showCircle then clearCircle();return end
			if not gui then
				local playerGui=Player:FindFirstChildOfClass("PlayerGui");if not playerGui then return end
				gui=Hub.new("ScreenGui",playerGui);gui.Name="ArrivaAimRadius";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false
				circle=Hub.new("Frame",gui);circle.BackgroundTransparency=1;circle.AnchorPoint=Vector2.new(0.5,0.5)
				local corner=Hub.new("UICorner",circle);corner.CornerRadius=UDim.new(1,0)
				local stroke=Hub.new("UIStroke",circle);stroke.Color=Color3.fromRGB(140,200,255);stroke.Thickness=1
			end
			circle.Position=UDim2.fromOffset(mousePosition.X,mousePosition.Y);circle.Size=UDim2.fromOffset(radius*2,radius*2)
		end
		group:AddToggle("PackAimAssist",{Text="Aim assist",Default=false,Callback=function(on) enabled=on;if not on then clearCircle() end end})
		group:AddToggle("PackAimAlways",{Text="Always aim",Default=false,Callback=function(on) always=on end})
		group:AddToggle("PackAimSelected",{Text="Aim at selected players only",Default=false,Callback=function(on) selectedOnly=on end})
		group:AddToggle("PackAimVisible",{Text="Visible targets only",Default=true,Callback=function(on) visibleOnly=on end})
		group:AddToggle("PackAimCircle",{Text="Aim FOV circle",Default=false,Callback=function(on) showCircle=on;if not on then clearCircle() end end})
		group:AddDropdown("PackAimPart",{Text="Aim part",Values={"Head","HumanoidRootPart","UpperTorso","Torso"},Default=1,Callback=function(value) partName=value end})
		group:AddSlider("PackAimRadius",{Text="Aim FOV radius",Default=150,Min=20,Max=600,Rounding=0,Callback=function(value) radius=value end})
		group:AddSlider("PackAimSmoothing",{Text="Aim responsiveness",Default=12,Min=1,Max=50,Rounding=0,Callback=function(value) smoothing=value end})
		Hub.connect(RunService.RenderStepped,function(dt)
			if not enabled then return end
			local camera=Workspace.CurrentCamera
			if not camera then return end
			local mousePosition=UserInputService:GetMouseLocation()
			local inset=game:GetService("GuiService"):GetGuiInset()
			local viewportMouse=mousePosition-inset
			draw(mousePosition)
			if UserInputService:GetFocusedTextBox() or Hub.keybindCaptureActive
				or (not always and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then return end
			local target=Hub.findAimTarget(camera,viewportMouse)
			if not target then return end
			local facing=Hub.safeLookAt(camera.CFrame.Position,target.Position,camera.CFrame.LookVector)
			if facing then camera.CFrame=camera.CFrame:Lerp(facing,1-math.exp(-smoothing*math.clamp(dt,0,0.1))) end
		end)
		Hub.cleanup(function() enabled=false;clearCircle();Hub.findAimTarget=nil end)
	end)()
end
-- End aim feature pack

-- Feature pack: reversible local part editing and smooth click teleport.
do
	(function()
		local group=Tabs.Misc:AddLeftGroupbox("Part Tools")
		local selecting,showHighlight=false,true
		local selected,highlight
		local saved={}
		local status=group:AddLabel("No part selected.")
		local function allowed(part)
			if not part or not part:IsA("BasePart") or not part.Parent or not Hub.canAffect(part) then return false end
			for _,player in ipairs(Players:GetPlayers()) do if player.Character and part:IsDescendantOf(player.Character) then return false end end
			return true
		end
		local function clearHighlight()
			if highlight then Hub.instances[highlight],Hub.assetTargets[highlight]=nil,nil;highlight:Destroy();highlight=nil end
		end
		function Hub.selectWorldPart(part)
			if not allowed(part) then status:SetText("Choose a world part, not a character.");return false end
			clearHighlight();selected=part;selecting=false
			status:SetText(part:GetFullName())
			if showHighlight then highlight=Hub.new("Highlight",part);highlight.Adornee=part;highlight.FillTransparency=0.85 end
			return true
		end
		local function restore(part)
			local values=saved[part];if not values then return end;saved[part]=nil
			pcall(function() if part.Parent then for key,value in pairs(values) do part[key]=value end end end)
		end
		local function modify(hide)
			if not allowed(selected) then return end
			if not saved[selected] then saved[selected]={CanCollide=selected.CanCollide,CanTouch=selected.CanTouch,CanQuery=selected.CanQuery,LocalTransparencyModifier=selected.LocalTransparencyModifier} end
			selected.CanCollide=false
			if hide then selected.CanTouch=false;selected.CanQuery=false;selected.LocalTransparencyModifier=1 end
		end
		group:AddButton({Text="Select world part (next click)",Func=function() selecting=true;status:SetText("Click a world part.") end})
		group:AddToggle("PackPartHighlight",{Text="Highlight selected part",Default=true,Callback=function(on) showHighlight=on;if not on then clearHighlight() elseif allowed(selected) then Hub.selectWorldPart(selected) end end})
		group:AddButton({Text="Decollide selected part (local)",Func=function() modify(false) end})
		group:AddButton({Text="Hide selected part (local)",Func=function() modify(true) end})
		group:AddButton({Text="Restore selected part",Func=function() if selected then restore(selected) end end})
		group:AddButton({Text="Restore all edited parts",Func=function() for part in pairs(saved) do restore(part) end end})
		group:AddButton({Text="Copy selected part path",Func=function() if allowed(selected) and setclipboard then setclipboard(selected:GetFullName()) end end})
		Hub.connect(UserInputService.InputBegan,function(input,processed)
			if selecting and not processed and input.UserInputType==Enum.UserInputType.MouseButton1 and not UserInputService:GetFocusedTextBox() then Hub.selectWorldPart(Player:GetMouse().Target) end
		end)
		Hub.cleanup(function() selecting=false;clearHighlight();for part in pairs(saved) do restore(part) end;Hub.selectWorldPart=nil end)
	end)();
	(function()
		local group=Tabs.Misc:AddLeftGroupbox("Travel Settings")
		local tweenService=game:GetService("TweenService")
		local enabled,duration=false,0.3
		local current
		local function cancel()
			local old=current;current=nil
			if not old then return end
			old.connection:Disconnect();Hub.connections[old.connection]=nil
			old.tween:Cancel()
		end
		function Hub.smoothTeleport(root,destination)
			cancel()
			if not enabled then return false end
			local char=Player.Character
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not char or root.Parent~=char or not hum or hum.SeatPart or Hub.blobFlightActive or Hub.characterFlightActive then return false end
			local entry={root=root,char=char}
			entry.tween=tweenService:Create(root,TweenInfo.new(duration,Enum.EasingStyle.Linear),{CFrame=destination})
			current=entry
			entry.connection=Hub.connect(entry.tween.Completed,function()
				if current~=entry then return end
				current=nil;entry.connection:Disconnect();Hub.connections[entry.connection]=nil
				if Player.Character==char and root.Parent==char then root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
			end)
			entry.tween:Play()
			return true
		end
		group:AddToggle("PackSmoothClickTP",{Text="Smooth click teleport",Default=false,Callback=function(on) enabled=on;if not on then cancel() end end})
		group:AddSlider("PackSmoothClickDuration",{Text="Teleport duration",Default=0.3,Min=0.1,Max=2,Rounding=1,Callback=function(value) duration=value end})
		group:AddButton({Text="Cancel smooth teleport",Func=cancel})
		Hub.connect(Player.CharacterRemoving,cancel)
		Hub.connect(RunService.Heartbeat,function() if current and (Player.Character~=current.char or Hub.safeZoneLoopActive) then cancel() end end)
		Hub.cleanup(function() enabled=false;cancel();Hub.smoothTeleport=nil end)
	end)()
end
-- End part and travel feature pack

-- Feature pack: local blackhole image and audio customization.
do
	(function()
		local group=Tabs.Visual:AddRightGroupbox("Blackhole Appearance")
		local audio=Tabs.Sound:AddRightGroupbox("Blackhole Audio")
		local imageOn,soundOn=false,false
		local imageAsset,soundAsset="",""
		local tint=Color3.new(1,1,1)
		local saved={};local watchers={};local epoch=0;local disposed=false
		local function asset(value)
			local text=tostring(value or ""):match("^%s*(.-)%s*$")
			if text=="" then return "" end
			local id=text:match("^(%d+)$") or text:match("^rbxassetid://(%d+)$")
				or text:match("[?&]id=(%d+)") or text:match("roblox.com/library/(%d+)")
				or text:match("roblox.com/store/asset/(%d+)") or text:match("roblox.com/catalog/(%d+)")
			return id and tonumber(id)>0 and "rbxassetid://"..id or nil
		end
		local function inHole(object)
			local parent=object
			while parent and parent~=Workspace do
				if parent.Name=="BlackHoleKick" or parent.Name=="StayedBH" then return true end
				parent=parent.Parent
			end
			return false
		end
		local function write(object,key,value)
			if object[key]==value then return end
			local playing=key=="SoundId" and object.IsPlaying
			if playing then object:Stop() end
			object[key]=value
			if playing then object:Play() end
		end
		local function restore(object)
			local record=saved[object];if not record then return end;saved[object]=nil
			for key,entry in pairs(record) do
				if entry.connection then entry.connection:Disconnect();Hub.connections[entry.connection]=nil end
				pcall(function() if object.Parent and object[key]==entry.applied then write(object,key,entry.original) end end)
			end
		end
		local function set(object,key,value)
			saved[object]=saved[object] or {}
			local entry=saved[object][key]
			if not entry then
				entry={original=object[key]};saved[object][key]=entry
				if type(object.GetPropertyChangedSignal)=="function" then
					entry.connection=Hub.connect(object:GetPropertyChangedSignal(key),function()
						if disposed or not saved[object] then return end
						if not inHole(object) then restore(object);return end
						if object[key]~=entry.applied then write(object,key,entry.applied) end
					end)
				end
			end
			entry.applied=value
			write(object,key,value)
		end
		local function inspect(object)
			if disposed or not object.Parent or not inHole(object) then return end
			if imageOn and imageAsset~="" then
				if (object:IsA("ImageLabel") or object:IsA("ImageButton")) and object.Name=="Large" then
					set(object,"Image",imageAsset);set(object,"ImageColor3",tint)
					set(object,"Visible",true);set(object,"ImageTransparency",0)
				elseif (object:IsA("ImageLabel") or object:IsA("ImageButton")) and object.Name=="Small" then
					set(object,"Visible",false)
				elseif object:IsA("BasePart") and object.Name=="Hole" then set(object,"Transparency",1) end
			end
			if soundOn and soundAsset~="" and object:IsA("Sound") then set(object,"SoundId",soundAsset) end
		end
		local function inspectTree(object)
			inspect(object)
			if object.Name=="BlackHoleKick" or object.Name=="StayedBH" then
				for _,child in ipairs(object:GetDescendants()) do inspect(child) end
			end
		end
		local function refresh()
			epoch+=1;local ticket=epoch
			for _,watcher in ipairs(watchers) do watcher:Disconnect();Hub.connections[watcher]=nil end
			table.clear(watchers)
			for object in pairs(saved) do restore(object) end
			if disposed or not (imageOn or soundOn) then return end
			table.insert(watchers,Hub.connect(Workspace.DescendantAdded,function(object)
				-- DescendantAdded can fire before the game has set its image, name or sound ID.
				task.defer(function() if not disposed and epoch==ticket then inspectTree(object) end end)
			end))
			table.insert(watchers,Hub.connect(Workspace.DescendantRemoving,function(object) restore(object) end))
			Hub.scanDescendants(Workspace,inspect,function() return not disposed and epoch==ticket and (imageOn or soundOn) end)
		end
		local function input(value,kind)
			local parsed=asset(value)
			if parsed==nil then
				notify("Blackhole asset warning","Use a Roblox image/audio asset ID or asset link. Web image and MP3 links are not Roblox asset IDs.",5,"warning");return
			end
			if kind=="image" then imageAsset=parsed else soundAsset=parsed end
			refresh()
		end
		group:AddInput("PackBlackholeImage",{Text="Blackhole image ID",Default="",Finished=true,Callback=function(value) input(value,"image") end})
		group:AddToggle("PackBlackholeImageOn",{Text="Custom blackhole image",Default=false,Callback=function(on) imageOn=on;refresh() end})
		group:AddInput("PackBlackholeTint",{Text="Blackhole image color hex",Default="FFFFFF",Finished=true,Callback=function(value)
			local hex=tostring(value):gsub("#","")
			if hex:match("^%x%x%x%x%x%x$") then tint=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16));refresh()
			else notify("Blackhole color warning","Use a six-digit HEX color.",4,"warning") end
		end})
		audio:AddInput("PackBlackholeSound",{Text="Blackhole sound ID",Default="",Finished=true,Callback=function(value) input(value,"sound") end})
		audio:AddToggle("PackBlackholeSoundOn",{Text="Custom blackhole sound",Default=false,Callback=function(on) soundOn=on;refresh() end})
		group:AddLabel("Applies when a blackhole exists. Use an image asset, not a decal or model ID.")
		audio:AddLabel("Audio must be permitted in this experience; muted game audio can hide playback.")
		Hub.cleanup(function() disposed=true;imageOn=false;soundOn=false;refresh() end)
	end)()
end
-- End blackhole cosmetic feature pack


-- UI Settings
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
do
	local group=Tabs.Commands:AddRightGroupbox("Owner commands")
	group:AddLabel("Allow the hub owner to bring, reveal, kill or kick this client, and announce messages. Off by default.")
	group:AddToggle("AllowHubOwnerCommands",{Text="Allow owner commands",Default=Hub.env.ArrivaAllowOwnerCommands==true,
		Callback=function(on) Hub.env.ArrivaAllowOwnerCommands=on==true;Hub.requestSave() end})
	group:AddLabel("Owner chat: !bring / !reveal / !kill / !kick <player|all|me>; !announce <text>. Legacy : prefix also works.")
end

do
	local widget=Tabs.Customization:AddRightGroupbox("On-screen FPS & Ping")
	widget:AddToggle("FloatingMetricsVisible",{Text="Show FPS and ping widget",Default=true,
		Callback=function(on) Hub.setMetricsPreference("metricsShown",on) end})
	widget:AddDropdown("FloatingMetricsPosition",{Text="Widget position",Default=1,
		Values={"Top Right","Top Left","Top Center","Bottom Right","Bottom Left","Bottom Center"},
		Callback=function(position) Hub.setMetricsPreference("metricsPosition",position) end})
	widget:AddSlider("FloatingMetricsSize",{Text="Widget size (%)",Default=100,Min=80,Max=140,Rounding=0,
		Callback=function(value) Hub.setMetricsPreference("metricsSize",value/100) end})
end
local ThemeGroup = Tabs.Customization:AddLeftGroupbox("Hub Theme")
do
	local group=Tabs.Misc:AddRightGroupbox("Teleport display")
	group:AddToggle("MaskAllTeleportMovement",{Text="Mask teleports (except Z)",Default=true,Callback=function(on) Hub.setTeleportMaskEnabled(on);Hub.requestSave() end})
	group:AddButton("Show actual position",function() Hub.clearTeleportMask(true) end)
	group:AddLabel("Your server position still changes. Z always clears the mask and moves visibly.")
end

-- Optional creative tools. No ownership requests or changes to other players' toys.
do
	(function()
		local manager=Tabs.Fun:AddRightGroupbox("My Toy Manager and Groups")
		local list,selected={},nil
		local groups,groupName={},"My group"
		local status=manager:AddLabel("Refresh to list your toys.")
		local function folder() return Workspace:FindFirstChild(Player.Name.."SpawnedInToys") end
		local function own(model)
			local f=folder()
			return f and model and model.Parent==f and model:IsA("Model") and not Hub.isGucciReserved(model)
		end
		local function movable(model)
			if not own(model) or model:FindFirstChildOfClass("Humanoid") then return false end
			for _,p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then
					if (Hub.isMissileReserved and Hub.isMissileReserved(p)) or (Hub.toyBuildClaims and Hub.toyBuildClaims[p.AssemblyRootPart or p]) or (Hub.missileLaunchClaims and Hub.missileLaunchClaims[p.AssemblyRootPart or p]) then return false end
					if p.Anchored or p:IsA("Seat") or p:IsA("VehicleSeat") then return false end
					for _,q in ipairs(p:GetConnectedParts(true)) do
						if not q:IsDescendantOf(model) then return false end
					end
				end
			end
			return model:FindFirstChildWhichIsA("BasePart",true)~=nil
		end
		Hub.isOwnCreativeToy=own
		local function root() return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") end
		local function report(text) status:SetText(text) end
		local picker
		Hub.getOwnToySelection=function() return selected, table.clone(groups[groupName] or {}), groupName end
		local function refresh()
			list={};local labels={};local f=folder()
			if f then for _,model in ipairs(f:GetChildren()) do
					if own(model) and #labels<100 then
						local label=string.format("%03d | %s",#labels+1,model.Name)
						list[label]=model;table.insert(labels,label)
					end
				end end
			table.sort(labels);picker:SetValues(labels)
			selected=nil
			report(string.format("%d toys listed. Select one before using an action.",#labels))
		end
		picker=manager:AddDropdown("OwnToySelection",{Text="Your toys",Values={},Callback=function(value) selected=list[value] end})
		manager:AddButton("Refresh toy list",refresh)
		manager:AddButton("Locate selected toy",function()
			local r=root();if not r or not own(selected) then return end
			report(string.format("%s is %.0f studs away.",selected.Name,(selected:GetPivot().Position-r.Position).Magnitude))
			local h=Hub.new("Highlight",selected);h.Adornee=selected
			task.delay(3,function() if h.Parent then h:Destroy() end end)
		end)
		local function move(models)
			local r=root();if not r then return end
			local valid={}
			for model in pairs(models) do if movable(model) and #valid<40 then table.insert(valid,model) end end
			if #valid==0 then report("No movable own toys selected. Anchored, seated or connected toys are skipped.");return end
			local origin=valid[1]:GetPivot();local goal=r.CFrame*CFrame.new(0,2,-10)
			for _,model in ipairs(valid) do
				model:PivotTo(goal*origin:ToObjectSpace(model:GetPivot()))
				for _,p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then
						p.AssemblyLinearVelocity=Vector3.zero;p.AssemblyAngularVelocity=Vector3.zero
					end end
			end
			report(string.format("Moved %d own toys. Server ownership can limit replication.",#valid))
		end
		manager:AddButton("Bring selected toy in front",function() if selected then move({[selected]=true}) end end)
		local confirm=false
		manager:AddToggle("OwnToyDeleteConfirm",{Text="Allow delete buttons",Default=false,Callback=function(on) confirm=on end})
		local function delete(models)
			if not confirm then report("Enable Allow delete buttons first.");return end
			local menu=ReplicatedStorage:FindFirstChild("MenuToys")
			local remote=menu and menu:FindFirstChild("DestroyToy")
			if not remote then report("Toy delete is unavailable.");return end
			local count=0
			for model in pairs(models) do if own(model) and count<40 then remote:FireServer(model);count+=1 end end
			report(string.format("Requested deletion of %d own toys.",count))
		end
		manager:AddButton("Delete selected toy",function() if selected then delete({[selected]=true}) end end)
		manager:AddInput("OwnToyGroupName",{Text="Group name",Default="My group",Finished=true,Callback=function(value)
			groupName=string.sub(tostring(value),1,48);if groupName=="" then groupName="My group" end
		end})
		manager:AddButton("Add selected toy to named group",function()
			if not own(selected) then return end
			groups[groupName]=groups[groupName] or {};groups[groupName][selected]=true;report("Added to "..groupName..".")
		end)
		manager:AddButton("Add all movable own toys to named group",function()
			local f=folder();if not f then return end
			local set={};local count=0
			for _,model in ipairs(f:GetChildren()) do if count<40 and movable(model) then set[model]=true;count+=1 end end
			groups[groupName]=set;report(string.format("%s contains %d toys.",groupName,count))
		end)
		manager:AddButton("Move named group in front",function() move(groups[groupName] or {}) end)
		manager:AddButton("Release named group",function() groups[groupName]=nil;report("Group cleared. Your toys are unchanged.") end)
		manager:AddButton("Delete named group toys",function() delete(groups[groupName] or {}) end)
		Hub.cleanup(function() table.clear(groups);table.clear(list);Hub.getOwnToySelection=nil end)
	end)()
end

-- Named own-toy builds, adapted from the supplied code’s Compile Parts workflow.
do
	(function()
		local group = Tabs.Fun:AddLeftGroupbox("Own Toy Builder & Recovery")
		local status = group:AddLabel("Select a header and toy group.")
		local session, connection
		local recoveryBusy=false
		local releaseHeader, autoRecover = false, true
		local elapsed = 0
		Hub.toyBuildClaims = {}

		local function foreignOwner(part)
			local owner = part:FindFirstChild("PartOwner")
			if owner and (owner:IsA("StringValue") or owner:IsA("ObjectValue")) then
				return owner.Value ~= nil and owner.Value ~= "" and owner.Value ~= Player.Name and owner.Value ~= Player
			end
			return false
		end
		function Hub.inspectOwnBuildToy(model,allowOwnershipRecovery)
			if Hub.isGucciReserved and Hub.isGucciReserved(model) then return nil,"Gucci is using this toy" end
			local folder = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
			if not folder or not model or model.Parent ~= folder or not model:IsA("Model")
				or model:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(model) then return nil, "unsupported toy" end
			local roots, seen = {}, {}
			local parts = 0
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("Humanoid") then return nil, "unsupported toy rig" end
				if part:IsA("BodyMover") or part:IsA("AlignPosition") or part:IsA("AlignOrientation")
					or part:IsA("LinearVelocity") or part:IsA("AngularVelocity") or part:IsA("VectorForce") or part:IsA("Torque") then
					if not session or not session.controllers[part] then return nil, "another movement controller is using this toy" end
				end
				if part:IsA("BasePart") then
					parts += 1
					if parts > 256 or part.Anchored or part:IsA("Seat") or part:IsA("VehicleSeat") then return nil, "anchored, seated or oversized toy" end
					if part:FindFirstChild("ArrivaCreativeAttachment") then return nil, "creative aura is using this toy" end
					local root = part.AssemblyRootPart or part
					if not root:IsDescendantOf(model) then return nil, "external assembly" end
					if (Hub.isMissileReserved and Hub.isMissileReserved(root)) or (Hub.missileLaunchClaims and Hub.missileLaunchClaims[root]) then return nil,"missile controller is using this toy" end
					if Hub.objectAttractionParts and Hub.objectAttractionParts[root] then return nil, "attraction aura is using this toy" end
					if not allowOwnershipRecovery and (foreignOwner(part) or root.ReceiveAge~=0) then return nil, "ownership" end
					if not seen[root] then seen[root] = true; table.insert(roots, root) end
				end
			end
			if #roots == 0 then return nil, "no movable parts" end
			for _, root in ipairs(roots) do
				for _, member in ipairs(root:GetConnectedParts(true)) do
					if not member:IsDescendantOf(model) or member.Anchored or member:IsA("Seat") or member:IsA("VehicleSeat") then return nil, "external or seated assembly" end
				end
			end
			return roots, nil, parts
		end

		local function destroy(object)
			Hub.instances[object] = nil
			Hub.assetTargets[object] = nil
			pcall(function() object:Destroy() end)
		end
		local function stop(message)
			if connection then connection:Disconnect(); Hub.connections[connection] = nil; connection = nil end
			if session then
				for _, entry in ipairs(session.entries) do
					if Hub.toyBuildClaims[entry.root] == session then Hub.toyBuildClaims[entry.root] = nil end
					for _, object in ipairs(entry.objects) do destroy(object) end
				end
				if session.highlight then destroy(session.highlight) end
			end
			session, elapsed = nil, 0
			status:SetText(message or "Build released. Temporary controllers were removed.")
		end
		local function enabledControllers(on)
			for _, entry in ipairs(session.entries) do entry.position.Enabled = on; entry.orientation.Enabled = on end
		end
		local function compile()
			if recoveryBusy then status:SetText("Wait for ownership recovery to finish.");return end
			local selected, models, name = Hub.getOwnToySelection()
			if not selected or not models[selected] then status:SetText("Add the selected header toy to the current named group first."); return end
			local headerRoots, reason = Hub.inspectOwnBuildToy(selected)
			if not headerRoots then status:SetText("Header is unavailable: " .. reason); return end
			local candidates, count, totalParts, physicalParts = {}, 0, 0, 0
			for model in pairs(models) do
				local roots, _, partCount = Hub.inspectOwnBuildToy(model)
				if roots then
					count += 1
					totalParts += #roots
					physicalParts += partCount
					table.insert(candidates, {model = model, roots = roots})
				end
			end
			if count < 2 then status:SetText("A build needs at least two eligible toys in the named group."); return end
			if count > 16 or totalParts > 32 or physicalParts > 256 then status:SetText("Build limit: 16 toys, 32 assemblies and 256 parts."); return end
			stop()
			local header = selected.PrimaryPart and (selected.PrimaryPart.AssemblyRootPart or selected.PrimaryPart) or headerRoots[1]
			if not table.find(headerRoots, header) then header = headerRoots[1] end
			session = {entries = {}, controllers = {}, models = candidates, header = header, anchor = header.CFrame,
				name = name, paused = false, resume = false, recoveringUntil = 0}
			local ok, err = pcall(function()
				for _, candidate in ipairs(candidates) do
					for _, root in ipairs(candidate.roots) do
						local entry = {root = root, offset = header.CFrame:ToObjectSpace(Hub.teleportFrame(root)), objects = {}}
						table.insert(session.entries, entry)
						Hub.toyBuildClaims[root] = session
						local attachment = Hub.new("Attachment", root)
						attachment.Name = "ArrivaOwnBuildAttachment"
						table.insert(entry.objects, attachment)
						local position = Hub.new("AlignPosition", root)
						session.controllers[position] = true
						table.insert(entry.objects, position)
						position.Name = "ArrivaOwnBuildPosition"
						position.Mode = Enum.PositionAlignmentMode.OneAttachment
						position.Attachment0 = attachment
						position.ApplyAtCenterOfMass = true
						position.MaxForce = 100000
						position.MaxVelocity = 40
						position.Responsiveness = 35
						position.Position = Hub.teleportFrame(root).Position
						local orientation = Hub.new("AlignOrientation", root)
						session.controllers[orientation] = true
						table.insert(entry.objects, orientation)
						orientation.Name = "ArrivaOwnBuildOrientation"
						orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
						orientation.Attachment0 = attachment
						orientation.MaxTorque = 100000
						orientation.Responsiveness = 35
						orientation.CFrame = Hub.teleportFrame(root).Rotation
						entry.position, entry.orientation = position, orientation
					end
				end
				local highlight = Hub.new("Highlight", selected)
				session.highlight = highlight
				highlight.Name = "ArrivaOwnBuildHeader"
				highlight.Adornee = selected
				highlight.FillTransparency = 0.9
				highlight.OutlineTransparency = 0
				highlight.OutlineColor = Color3.fromRGB(90, 230, 140)
			end)
			if not ok then stop("Could not create build controllers: " .. tostring(err)); return end
			status:SetText(string.format("Compiled %s: %d toys / %d assemblies. The selected toy is the header.", name, count, totalParts))
			connection = Hub.connect(RunService.Heartbeat, function(dt)
				elapsed += dt
				if elapsed >= 0.05 then elapsed = 0; Hub.sampleOwnToyBuild() end
			end)
		end
		function Hub.sampleOwnToyBuild()
			if not session or recoveryBusy then return end
			local ownershipLost = false
			local physicalParts = 0
			for _, candidate in ipairs(session.models) do
				local roots, reason, partCount = Hub.inspectOwnBuildToy(candidate.model)
				if not roots then
					if reason == "ownership" then ownershipLost = true
					else stop("Build stopped: " .. reason .. "."); return end
				else
					physicalParts += partCount
					if physicalParts > 256 or #roots ~= #candidate.roots then stop("Build stopped: the assembly structure or part budget changed."); return end
					for _, root in ipairs(roots) do
						if Hub.toyBuildClaims[root] ~= session or not table.find(candidate.roots, root) then stop("Build stopped: an assembly changed. Compile the group again."); return end
					end
				end
			end
			if ownershipLost then
				session.paused = true
				enabledControllers(false)
				session.highlight.OutlineColor = Color3.fromRGB(255, 170, 70)
				status:SetText("Build paused: another owner is recorded. Re-grab your toys to recover ownership.")
				return
			end
			if session.paused then
				if not autoRecover and not session.resume then status:SetText("Ownership is available. Use Resume paused build."); return end
				session.paused, session.resume = false, false
				session.recoveringUntil = os.clock() + 1
				session.highlight.OutlineColor = Color3.fromRGB(90, 230, 140)
				status:SetText("Ownership returned: recovering the stored build formation.")
			end
			local recovering = os.clock() < session.recoveringUntil
			if releaseHeader and not recovering then session.anchor = session.header.CFrame end
			for _, entry in ipairs(session.entries) do
				if not entry.root.Parent then stop("Build stopped: a root part disappeared."); return end
				local goal = session.anchor * entry.offset
				entry.position.Position = goal.Position
				entry.orientation.CFrame = goal.Rotation
				local active = entry.root ~= session.header or not releaseHeader or recovering
				entry.position.Enabled, entry.orientation.Enabled = active, active
			end
		end
		local ownershipStatus=group:AddLabel("Ownership status: select a toy or named group.")
		local recoveryGeneration,recoveryFinish,nextRecovery=0,nil,0
		local function recoveryModels()
			local selected,models=Hub.getOwnToySelection()
			if not models or next(models)==nil then models=selected and {[selected]=true} or {} end
			return models
		end
		local function locallyOwned(root)
			return root.Parent and not root.Anchored and (root.AssemblyRootPart or root).ReceiveAge==0 and not foreignOwner(root)
		end
		local function inspectOwnership()
			local owned,missing,skipped=0,0,0
			for model in pairs(recoveryModels()) do
				local roots=Hub.inspectOwnBuildToy(model,true)
				if not roots then skipped+=1
				else for _,root in ipairs(roots) do if locallyOwned(root) then owned+=1 else missing+=1 end end end
			end
			ownershipStatus:SetText(string.format("Ownership: %d local assemblies, %d unconfirmed, %d ineligible toys.",owned,missing,skipped))
		end
		local function cancelRecovery()
			local wasBusy=recoveryBusy
			recoveryGeneration+=1;recoveryBusy=false
			if recoveryFinish then local finish=recoveryFinish;recoveryFinish=nil;finish() end
			if wasBusy and session then session.resume=true;Hub.sampleOwnToyBuild() end
		end
		local function recoverOwnership(allowedLoop,active)
			if allowedLoop~="LoopOwnToyRecovery" then allowedLoop=nil;active=nil end
			if recoveryBusy or os.clock()<nextRecovery then ownershipStatus:SetText("Recovery is running or cooling down.");return end
			local ownRoot,char,hum=Hub.freeCharacterForTools(allowedLoop)
			if not ownRoot then ownershipStatus:SetText(tostring(char));return end
			local grab=ReplicatedStorage:FindFirstChild("GrabEvents")
			local remote=grab and grab:FindFirstChild("SetNetworkOwner")
			if not remote then ownershipStatus:SetText("Ownership remote unavailable.");return end
			local targets,seen={},{}
			for model in pairs(recoveryModels()) do
				local roots=Hub.inspectOwnBuildToy(model,true)
				for _,root in ipairs(roots or {}) do
					if not seen[root] and not locallyOwned(root) and (Hub.teleportFrame(root).Position-Hub.teleportFrame(ownRoot).Position).Magnitude<=30 and #targets<12 then
						seen[root]=true;table.insert(targets,{root=root,model=model})
					end
				end
			end
			if #targets==0 then inspectOwnership();status:SetText("No missing nearby ownership to recover. Move within 30 studs of your toys.");return end
			recoveryGeneration+=1;local ticket=recoveryGeneration
			recoveryBusy=true;nextRecovery=os.clock()+3
			local finish=Hub.beginProtectionChange and Hub.beginProtectionChange({Id="OwnBuildRecovery",Text="Own toy ownership recovery",Type="Toggle",Tab=Tabs.Defense.native})
			recoveryFinish=finish
			local build=session
			if build then build.paused=true;enabledControllers(false) end
			local function valid(model)
				local held=Player:FindFirstChild("IsHeld")
				for key,run in pairs(Hub.targetLoopRuns or {}) do if run.enabled and key~=allowedLoop then return false end end
				return (not active or active()) and (not model or recoveryModels()[model]) and Hub.alive and ticket==recoveryGeneration and Player.Character==char and ownRoot.Parent==char
					and hum.Parent==char and hum.Health>0 and not hum.SeatPart and not ownRoot.Anchored
					and not (held and held.Value) and not Hub.interactionVisitLock and not Hub.safeZoneLoopActive
					and not Hub.characterFlightActive and not Hub.blobFlightActive
			end
			task.spawn(function()
				local confirmed=0
				local ok,err=xpcall(function()
					task.wait(0.2)
					for _,entry in ipairs(targets) do
						if not valid() then return end
						local roots=Hub.inspectOwnBuildToy(entry.model,true)
						local root=entry.root
						if valid(entry.model) and roots and table.find(roots,root) and (Hub.teleportFrame(root).Position-Hub.teleportFrame(ownRoot).Position).Magnitude<=30 then
							for _=1,2 do
								if not valid(entry.model) or not root.Parent or (Hub.teleportFrame(root).Position-Hub.teleportFrame(ownRoot).Position).Magnitude>30 then break end
								if locallyOwned(root) then break end
								local aim=Hub.safeLookAt(Hub.teleportFrame(ownRoot).Position+Vector3.new(0,1.593,0),Hub.teleportFrame(root).Position)
								if not aim then break end
								Hub.fire(remote,root,aim);task.wait(0.25)
							end
							if locallyOwned(root) then confirmed+=1 end
						end
					end
				end,debug.traceback)
				if finish then finish() end
				if recoveryFinish==finish then recoveryFinish=nil end
				if ticket~=recoveryGeneration then return end
				recoveryBusy=false
				if build and session==build then session.resume=true;Hub.sampleOwnToyBuild() end
				inspectOwnership()
				status:SetText(ok and string.format("Ownership recovery: %d / %d assemblies confirmed.",confirmed,#targets) or ("Recovery stopped: "..tostring(err):sub(1,180)))
			end)
		end
		group:AddButton({Text="Check selected group ownership",Func=inspectOwnership})
		group:AddButton({Text="Recover nearby own-toy ownership",Func=recoverOwnership})
		group:AddButton({Text="Cancel ownership recovery",Func=function() cancelRecovery();ownershipStatus:SetText("Ownership recovery cancelled.") end})
		group:AddLabel("Recovery checks your selected group (or selected toy), up to 12 nearby assemblies. No teleporting; rigs, seats and external connections are skipped.")
		Hub.recoverOwnToyOwnership=recoverOwnership
		Hub.cancelOwnToyRecovery=cancelRecovery
		Hub.connect(Player.CharacterRemoving,cancelRecovery)
		Hub.cleanup(function() cancelRecovery();Hub.recoverOwnToyOwnership=nil;Hub.cancelOwnToyRecovery=nil end)
		group:AddButton({Text = "Compile current named group", Func = compile})
		group:AddToggle("OwnToyBuildReleaseHeader", {Text = "Release header for dragging", Default = false,
			Callback = function(on) releaseHeader = on end})
		group:AddToggle("OwnToyBuildAutoRecover", {Text = "Recover build when ownership returns", Default = true,
			Callback = function(on) autoRecover = on end})
		group:AddButton({Text = "Resume paused build", Func = function() if session then session.resume = true; Hub.sampleOwnToyBuild() end end})
		group:AddButton({Text = "Disassemble current build", Func = function() stop() end})
		Hub.connect(Player.CharacterRemoving, function() stop("Build released for character respawn.") end)
		Hub.cleanup(function() stop(); Hub.sampleOwnToyBuild = nil; Hub.inspectOwnBuildToy = nil end)
	end)()
end

-- Local visual decoy formations inspired by the supplied code’s Decoy Follow feature.
do
	(function()
		local group = Tabs.Fun:AddRightGroupbox("Local Decoy Formation")
		local enabled, connection = false, nil
		local count, spacing, radius, orbitSpeed = 3, 5, 12, 0.5
		local mode = "Follow row"
		local folder, sourceCharacter, pivotOffset
		local clones = {}
		local elapsed, phase = 0, 0
		local nextBuild = 0
		local status = group:AddLabel("Local decoys are off.")

		function Hub.decoyFormationOffset(shape, index, total, gap, ringRadius, rotation)
			if shape == "Orbit" then
				local angle = (index - 1) * math.pi * 2 / math.max(total, 1) + rotation
				return Vector3.new(math.cos(angle) * ringRadius, 0, math.sin(angle) * ringRadius)
			elseif shape == "Wedge" then
				local row = math.ceil(index / 2)
				return Vector3.new((index % 2 == 1 and -1 or 1) * row * gap, 0, row * gap)
			end
			return Vector3.new((index - (total + 1) / 2) * gap, 0, gap)
		end
		local function clear()
			for _, clone in ipairs(clones) do
				Hub.instances[clone] = nil
				clone:Destroy()
			end
			table.clear(clones)
			if folder then Hub.instances[folder] = nil; folder:Destroy(); folder = nil end
			sourceCharacter, pivotOffset = nil, nil
		end
		local function build(char, root)
			clear()
			if os.clock() < nextBuild then return false end
			nextBuild = os.clock() + 2
			local originalArchivable = char.Archivable
			char.Archivable = true
			local ok, template = pcall(function() return char:Clone() end)
			char.Archivable = originalArchivable
			if not ok or not template then status:SetText("Could not clone this avatar. The live character is unchanged."); return false end
			local descendants = template:GetDescendants()
			if #descendants > 512 then template:Destroy(); status:SetText("Avatar is too complex for local decoys (512 descendant limit)."); return false end
			local parts = 0
			-- Sanitize before parenting any clone into the world.
			for _, object in ipairs(descendants) do
				if object:IsA("LuaSourceContainer") or object:IsA("Tool") or object:IsA("Sound")
					or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
					or object:IsA("BodyMover") or object:IsA("Constraint") or object:IsA("Highlight") or object:IsA("Animator")
					or object:IsA("ForceField") then object:Destroy()
				elseif object:IsA("BasePart") then
					parts += 1
					object.Anchored = true
					object.CanCollide = false
					object.CanTouch = false
					object.CanQuery = false
					object.Massless = true
					object.Transparency = math.max(object.Transparency, 0.5)
				elseif object:IsA("Humanoid") then
					object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					object.AutoRotate = false
				end
			end
			if parts == 0 or parts > 128 then template:Destroy(); status:SetText("Local decoys require an avatar with 1–128 parts."); return false end
			template.Archivable = true
			folder = Hub.new("Folder", Workspace)
			folder.Name = "ArrivaLocalDecoyFormation"
			local cloneOK, cloneError = pcall(function()
				for index = 1, count do
					local clone = template:Clone()
					clone.Name = "ArrivaVisualDecoy" .. index
					Hub.instances[clone] = true
					table.insert(clones, clone)
					local outline = Instance.new("Highlight")
					outline.Adornee = clone
					outline.FillTransparency = 0.9
					outline.OutlineTransparency = 0.35
					outline.OutlineColor = Color3.fromRGB(130, 185, 255)
					outline.Parent = clone
					clone.Parent = folder
				end
			end)
			template:Destroy()
			if not cloneOK then clear(); status:SetText("Could not create local decoys: " .. tostring(cloneError)); return false end
			sourceCharacter = char
			pivotOffset = Hub.teleportFrame(root):ToObjectSpace(char:GetPivot())
			status:SetText(string.format("%d local visual decoys: %s.", #clones, mode))
			return true
		end
		function Hub.sampleLocalDecoys(delta)
			if not enabled then return end
			local char = Player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health <= 0 or not char:IsDescendantOf(Workspace) then
				clear()
				status:SetText("Waiting for your character.")
				return
			end
			if sourceCharacter ~= char then if not build(char, root) then return end end
			phase = (phase + math.min(delta or 0.05, 0.1) * orbitSpeed) % (math.pi * 2)
			for index, clone in ipairs(clones) do
				local offset = Hub.decoyFormationOffset(mode, index, #clones, spacing, radius, phase)
				clone:PivotTo(Hub.teleportFrame(root) * CFrame.new(offset) * pivotOffset)
			end
		end
		local function start()
			if connection then connection:Disconnect(); Hub.connections[connection] = nil; connection = nil end
			clear()
			elapsed, phase, nextBuild = 0, 0, 0
			if not enabled then status:SetText("Local decoys are off."); return end
			connection = Hub.connect(RunService.Heartbeat, function(dt)
				elapsed += dt
				if elapsed >= 0.05 then local delta = elapsed; elapsed = 0; Hub.sampleLocalDecoys(delta) end
			end)
		end
		group:AddToggle("LocalDecoyFormationEnabled", {Text = "Local visual decoys", Default = false,
			Callback = function(on) enabled = on; start() end})
		group:AddDropdown("LocalDecoyFormationMode", {Text = "Formation", Values = {"Follow row", "Wedge", "Orbit"}, Default = 1,
			Callback = function(value) mode = value; if enabled then status:SetText(string.format("%d local visual decoys: %s.", #clones, mode)) end end})
		group:AddSlider("LocalDecoyFormationCount", {Text = "Decoy count", Default = 3, Min = 1, Max = 6, Rounding = 0,
			Callback = function(value) count = value; if enabled then start() end end})
		group:AddSlider("LocalDecoyFormationSpacing", {Text = "Row / wedge spacing", Default = 5, Min = 2, Max = 15, Rounding = 0,
			Callback = function(value) spacing = value end})
		group:AddSlider("LocalDecoyFormationRadius", {Text = "Orbit radius", Default = 12, Min = 4, Max = 25, Rounding = 0,
			Callback = function(value) radius = value end})
		group:AddSlider("LocalDecoyFormationSpeed", {Text = "Orbit speed", Default = 0.5, Min = 0, Max = 2, Rounding = 1,
			Callback = function(value) orbitSpeed = value end})
		group:AddButton({Text = "Rebuild local decoys", Func = function() if enabled then start() end end})
		Hub.connect(Player.CharacterRemoving, function() clear(); nextBuild = 0 end)
		Hub.cleanup(function()
			enabled = false
			if connection then connection:Disconnect(); Hub.connections[connection] = nil; connection = nil end
			clear()
			Hub.sampleLocalDecoys, Hub.decoyFormationOffset = nil, nil
		end)
	end)()
end

do
	(function()
		local group=Tabs.Misc:AddLeftGroupbox("Travel")
		local locations={Spawn=Vector3.new(4,-7,-3),["Safe Zone"]=Vector3.new(606,124,-101),
			["Farm House"]=Vector3.new(-234,83,-324),["Blue Safe House"]=Vector3.new(538,96,-372),
			["Big Cave"]=Vector3.new(17,-7,539),["Train Cave"]=Vector3.new(500,62,-307),
			["Mine Cave"]=Vector3.new(-254,-7,518),["Witch Safe House"]=Vector3.new(296,-4,494),
			["Red Safe House"]=Vector3.new(-516,-6,-162)}
		local destination="Safe Zone";local custom="606, 124, -101"
		local names={};for name in pairs(locations) do table.insert(names,name) end;table.sort(names)
		group:AddDropdown("MapDestination",{Text="Location",Values=names,Default=table.find(names,destination),Callback=function(value) destination=value end})
		local function teleport(position)
			if Hub.safeZoneLoopActive then notify("Teleport","Turn off the safe-zone loop first.",4);return end
			local char=Player.Character;local r=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not r or not hum or hum.Health<=0 then return end
			if position.Y<=Workspace.FallenPartsDestroyHeight+8 then return end
			r.CFrame=CFrame.new(position)*r.CFrame.Rotation;r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero
		end
		group:AddButton("Go to selected location",function() if locations[destination] then teleport(locations[destination]) end end)
		group:AddInput("MapCustomCoordinates",{Text="Custom X, Y, Z",Default=custom,Finished=true,Callback=function(value) custom=value end})
		group:AddButton("Go to custom coordinates",function()
			local nums={};for n in tostring(custom):gmatch("[^,%s]+") do table.insert(nums,tonumber(n) or false) end
			if #nums~=3 then return end
			for _,n in ipairs(nums) do if not n or n~=n or math.abs(n)>100000 then return end end
			teleport(Vector3.new(nums[1],nums[2],nums[3]))
		end)
		group:AddButton("Save current position as custom",function()
			local r=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
			if r then Options.MapCustomCoordinates:SetValue(string.format("%.2f, %.2f, %.2f",r.Position.X,r.Position.Y,r.Position.Z)) end
		end)
	end)()
end

do
	(function()
		local group=Tabs.Player:AddRightGroupbox("Follow Player Position")
		local target,enabled,side,distance,height=nil,false,"Behind",8,0
		local picker;local elapsed=0
		local function refresh()
			local names={};for _,p in ipairs(Players:GetPlayers()) do if p~=Player then table.insert(names,p.Name) end end
			table.sort(names);picker:SetValues(names)
		end
		picker=group:AddDropdown("SelfFollowPlayer",{Text="Follow player",Values={},Callback=function(value) target=type(value)=="string" and Players:FindFirstChild(value) or nil end})
		group:AddButton("Refresh follow players",refresh)
		refresh()
		group:AddDropdown("SelfFollowSide",{Text="Position",Values={"Behind","Left","Right","Front"},Default=1,Callback=function(value) side=value end})
		group:AddSlider("SelfFollowDistance",{Text="Distance",Default=8,Min=3,Max=40,Rounding=0,Callback=function(value) distance=value end})
		group:AddSlider("SelfFollowHeight",{Text="Height offset",Default=0,Min=0,Max=20,Rounding=0,Callback=function(value) height=value end})
		group:AddToggle("SelfFollowEnabled",{Text="Follow selected player",Default=false,Callback=function(on) enabled=on end})
		Hub.connect(Players.PlayerAdded,function() Hub.queueRefresh("follow",refresh) end);Hub.connect(Players.PlayerRemoving,function(p) if p==target then target=nil end;Hub.queueRefresh("follow",refresh) end)
		Hub.connect(RunService.Heartbeat,function(dt)
			if not enabled or Hub.safeZoneLoopActive then return end
			elapsed+=dt;if elapsed<0.1 then return end;elapsed=0
			local char=Player.Character;local r=char and char:FindFirstChild("HumanoidRootPart")
			local h=char and char:FindFirstChildOfClass("Humanoid")
			local other=target and target.Character;local t=other and other:FindFirstChild("HumanoidRootPart")
			local th=other and other:FindFirstChildOfClass("Humanoid")
			if not r or not h or h.Health<=0 or h.SeatPart or not t or not th or th.Health<=0 then return end
			local offset=side=="Left" and Vector3.new(-distance,height,0) or side=="Right" and Vector3.new(distance,height,0)
				or side=="Front" and Vector3.new(0,height,-distance) or Vector3.new(0,height,distance)
			local goal=t.CFrame*CFrame.new(offset)
			if goal.Position.Y>Workspace.FallenPartsDestroyHeight+8 then r.CFrame=goal;r.AssemblyLinearVelocity=Vector3.zero end
		end)
	end)()
end

do
	(function()
		local group=Tabs.Customization:AddRightGroupbox("Anchor Appearance")
		local fill,outline=Color3.fromRGB(0,85,255),Color3.fromRGB(0,170,255)
		local fillAlpha,lineAlpha,labels=0.4,0.7,false
		local active={}
		local function style(h)
			if not h.Parent then active[h]=nil;return end
			h.FillColor=fill;h.OutlineColor=outline;h.FillTransparency=fillAlpha;h.OutlineTransparency=lineAlpha
			local old=h:FindFirstChild("ArrivaAnchorLabel")
			if labels and not old then
				local part=h.Parent:IsA("BasePart") and h.Parent or h.Parent:FindFirstChildWhichIsA("BasePart",true)
				if part then
					local gui=Hub.new("BillboardGui",h);gui.Name="ArrivaAnchorLabel";gui.Adornee=part
					gui.Size=UDim2.fromOffset(140,26);gui.StudsOffset=Vector3.new(0,3,0);gui.AlwaysOnTop=true
					local text=Hub.new("TextLabel",gui);text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
					text.Text="Anchored object";text.TextColor3=outline;text.TextSize=14
				end
			elseif old and not labels then old:Destroy() end
			if old then local text=old:FindFirstChildOfClass("TextLabel");if text then text.TextColor3=outline end end
		end
		Hub.styleAnchorHighlight=function(h) active[h]=true;style(h) end
		local function refresh() for h in pairs(active) do style(h) end end
		local function color(value)
			local hex=tostring(value):gsub("#","")
			if #hex~=6 or not hex:match("^%x+$") then return nil end
			return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
		end
		group:AddInput("AnchorFillHex",{Text="Fill hex",Default="0055FF",Finished=true,Callback=function(value) fill=color(value) or fill;refresh() end})
		group:AddInput("AnchorOutlineHex",{Text="Outline hex",Default="00AAFF",Finished=true,Callback=function(value) outline=color(value) or outline;refresh() end})
		group:AddSlider("AnchorFillOpacity",{Text="Fill transparency",Default=40,Min=0,Max=100,Rounding=0,Callback=function(value) fillAlpha=value/100;refresh() end})
		group:AddSlider("AnchorLineOpacity",{Text="Outline transparency",Default=70,Min=0,Max=100,Rounding=0,Callback=function(value) lineAlpha=value/100;refresh() end})
		group:AddToggle("AnchorLabels",{Text="Anchor labels",Default=false,Callback=function(on) labels=on;refresh() end})
		Hub.cleanup(function() table.clear(active);Hub.styleAnchorHighlight=nil end)
	end)()
end


do
	(function()
		local group=Tabs.Customization:AddRightGroupbox("Touch Action Buttons")
		local gui=Hub.new("ScreenGui",Player:WaitForChild("PlayerGui"));gui.Name="ArrivaTouchActions";gui.ResetOnSpawn=false;gui.Enabled=false
		Hub.touchActionsGui=gui
		local palette=Hub.creativeUIPalette or {sidebar=Color3.fromRGB(31,31,31),card=Color3.fromRGB(33,33,33),text=Color3.fromRGB(237,237,237)}
		local panel=Hub.new("Frame",gui);panel.Size=UDim2.fromOffset(224,164);panel.BackgroundColor3=palette.sidebar
		local corner=Hub.new("UICorner",panel);corner.CornerRadius=UDim.new(0,12)
		local position="Bottom right"
		local function place()
			panel.AnchorPoint=Vector2.new(position:find("right") and 1 or 0,position:find("Bottom") and 1 or 0)
			panel.Position=UDim2.new(panel.AnchorPoint.X,panel.AnchorPoint.X==1 and -16 or 16,panel.AnchorPoint.Y,panel.AnchorPoint.Y==1 and -90 or 80)
		end
		local function button(text,y,action)
			local b=Hub.new("TextButton",panel);b.Position=UDim2.fromOffset(8,y);b.Size=UDim2.fromOffset(208,44)
			b.BackgroundColor3=palette.card;b.TextColor3=palette.text;b.TextSize=14;b.Text=text;b.TextWrapped=true;b.TextScaled=true
			local padding=Hub.new("UIPadding",b);padding.PaddingLeft=UDim.new(0,10);padding.PaddingRight=UDim.new(0,10);padding.PaddingTop=UDim.new(0,4);padding.PaddingBottom=UDim.new(0,4)
			local size=Hub.new("UITextSizeConstraint",b);size.MinTextSize=10;size.MaxTextSize=14
			local c=Hub.new("UICorner",b);c.CornerRadius=UDim.new(0,8)
			Hub.connect(b.Activated,function() if Hub.alive and not UserInputService:GetFocusedTextBox() then action() end end)
		end
		button("TP to aimed surface",8,function() if Hub.clickTeleport then Hub.clickTeleport() end end)
		button("Anchor held object",60,function() if Hub.anchorHeldObject then Hub.anchorHeldObject(false) end end)
		button("Spawn selected toy",112,function() if Hub.quickSpawnCreativeToy then Hub.quickSpawnCreativeToy() end end)
		group:AddToggle("TouchActionsEnabled",{Text="Show action buttons",Default=false,Callback=function(on) gui.Enabled=on end})
		group:AddDropdown("TouchActionsPosition",{Text="Action button corner",Values={"Bottom right","Bottom left","Top right","Top left"},Default=1,Callback=function(value) position=value;place() end})
		place()
	end)()
end

ThemeGroup:AddDropdown("SidebarTheme", {
	Text="Hub theme", Values={"Default","Midnight","Violet","Forest","Rose","Ocean","Amber","Custom"}, Default=1,
	Callback=function(name)
		if Hub.setSidebarTheme then Hub.setSidebarTheme(name) end
		Hub.requestSave()
	end,
})
do
	local appearance=Tabs.Customization:AddRightGroupbox("Custom Theme Colors")
	local function field(id,label,key,value)
		appearance:AddInput(id,{Text=label,Default=value,Finished=true,
			Callback=function(color)
				if Hub.setCustomThemeColor and not Hub.setCustomThemeColor(key,color) then
					Library:Notify({Title="Theme warning",Description="Use a six-digit HEX color, e.g. #4589BF.",Time=4})
				end
			end})
	end
	field("CustomThemeBackground","Background HEX","background","#191919")
	field("CustomThemeAccent","Accent HEX","accent","#4589BF")
	field("CustomThemeText","Text HEX","text","#EDEDED")
	local notices=Tabs.Notifications:AddRightGroupbox("Position & Appearance")
	notices:AddDropdown("NotificationPosition",{Text="Notification position",Default=1,
		Values={"Bottom Right","Bottom Left","Bottom Center","Top Right","Top Left","Top Center"},
		Callback=function(value) Hub.setNoticePreference("noticePosition",value) end})
	notices:AddSlider("NotificationScale",{Text="Notification size (%)",Default=100,Min=80,Max=130,Rounding=0,
		Callback=function(value) Hub.setNoticePreference("noticeScale",value/100) end})
	notices:AddSlider("NotificationLimit",{Text="Maximum visible notifications",Default=3,Min=1,Max=25,Rounding=0,
		Callback=function(value) Hub.setNoticePreference("noticeLimit",value) end})
	notices:AddSlider("NotificationDuration",{Text="Notification duration multiplier",Default=1,Min=0.5,Max=2,Rounding=1,
		Callback=function(value) Hub.setNoticePreference("noticeDuration",value) end})
	notices:AddButton({Text="Preview notification",Func=function()
		Library:Notify({Title="Notification preview",Description="Your notification position, size and theme preview.",Time=5})
	end})
end
do
	local events=Tabs.Notifications:AddLeftGroupbox("Player Events")
	local preferences={joins=true,leaves=true,respawns=true,self=true}
	local roster={}
	local function toggle(id,title,key)
		events:AddToggle(id,{Text=title,Default=true,Callback=function(on) preferences[key]=on end})
	end
	toggle("NotifyPlayerJoins","Player joined","joins")
	toggle("NotifyPlayerLeaves","Player left","leaves")
	toggle("NotifyPlayerRespawns","Player respawned","respawns")
	toggle("NotifyMyCharacter","My death and respawn","self")
	events:AddToggle("NotifyBlackholeAlerts",{Text="Blackhole alerts",Default=true,Callback=function(on) Hub.blackholeNoticeEnabled=on end})
	local function disconnect(connection)
		if connection then connection:Disconnect();Hub.connections[connection]=nil end
	end
	local function track(person)
		if roster[person] then return end
		local entry={seen=person.Character~=nil,last=-math.huge}
		roster[person]=entry
		local function watchDeath(char)
			disconnect(entry.death);entry.death=nil
			if person~=Player or not char then return end
			local hum=char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5)
			if not Hub.alive or roster[person]~=entry or person.Character~=char or not hum then return end
			entry.death=Hub.connect(hum.Died,function()
				if preferences.self then notify("Character warning","Your character died. Waiting for respawn.",4) end
			end)
		end
		entry.character=Hub.connect(person.CharacterAdded,function(char)
			local respawn=entry.seen
			entry.seen=true
			if respawn and os.clock()-entry.last>=8 then
				entry.last=os.clock()
				if person==Player then
					if preferences.self then notify("Character respawned","Your character has respawned.",4,"respawn",Player.Name) end
				elseif preferences.respawns then
					-- Let the existing targeted respawn alert handle tracked players.
					local duplicate=respawnNotifyActive and isTrackedPlayer(person)
					if not duplicate then notify("Player respawned",person.Name .. " has respawned.",4,"respawn",person.Name) end
				end
			end
			watchDeath(char)
		end)
		if person==Player and person.Character then
			task.spawn(function() watchDeath(person.Character) end)
		end
	end
	for _,person in ipairs(Players:GetPlayers()) do track(person) end
	Hub.connect(Players.PlayerAdded,function(person)
		track(person)
		if preferences.joins then notify("Player joined",person.Name .. " joined the server.",4,"join",person.Name) end
	end)
	Hub.connect(Players.PlayerRemoving,function(person)
		local entry=roster[person]
		roster[person]=nil
		if entry then disconnect(entry.character);disconnect(entry.death) end
		if preferences.leaves then notify("Player left",person.Name .. " left the server.",4,"leave",person.Name) end
	end)
	Hub.cleanup(function()
		for _,entry in pairs(roster) do disconnect(entry.character);disconnect(entry.death) end
		table.clear(roster)
	end)
end

MenuGroup:AddButton("Unload", function() Library:Unload() end)
Hub.connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if Hub.matchesKeybind("EmergencyUnloadKey", input, "End") then Library:Unload() end
end)
MenuGroup:AddButton({Text = "Diagnostics", Func = function()
	local listeners, workers = 0, 0
	for connection in pairs(Hub.connections) do if connection.Connected then listeners += 1 end end
	for thread in pairs(Hub.threads) do if coroutine.status(thread) ~= "dead" then workers += 1 end end
	notify("Diagnostics", string.format("%d listeners / %d active workers. Config storage: %s. Touch API: %s.",
		listeners, workers, Hub.storage and "available" or "unavailable", firetouchinterest and "available" or "unavailable"), 8)
end})
Hub.keybindGroups.interface:AddLabel("Toggle menu"):AddKeyPicker("MenuKeybind", { Default = "M", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind

-- BEGIN CAMERA CLIP FADE
do
	(function()
		local group=Tabs.Visual:AddRightGroupbox("Camera clipping")
		local enabled=false
		local originalMode
		local faded={}
		local beforeName="ArrivaCameraClipRestore"
		local afterName="ArrivaCameraClipFade"
		local function restore()
			for part,value in pairs(faded) do
				pcall(function() part.LocalTransparencyModifier=value end)
				faded[part]=nil
			end
		end
		local function setMode(value)
			local ok=pcall(function() Player.DevCameraOcclusionMode=value end)
			if not ok and type(sethiddenproperty)=="function" then
				ok=pcall(sethiddenproperty,Player,"DevCameraOcclusionMode",value)
			end
			return ok and Player.DevCameraOcclusionMode==value
		end
		local function stop()
			enabled=false
			RunService:UnbindFromRenderStep(beforeName)
			RunService:UnbindFromRenderStep(afterName)
			restore()
			if originalMode~=nil then setMode(originalMode);originalMode=nil end
		end
		local function fade(part)
			if not part:IsA("BasePart") or not part.Parent then return end
			local char=Player.Character
			if char and part:IsDescendantOf(char) then return end
			if faded[part]~=nil then return end
			faded[part]=part.LocalTransparencyModifier
			-- Effective transparency = 1 - (1 - Transparency) * (1 - modifier).
			-- Already more-transparent surfaces stay at their original transparency.
			local base=part.Transparency
			part.LocalTransparencyModifier=base<0.6 and (0.6-base)/(1-base) or 0
		end
		local function update()
			if not enabled or not Hub.alive then return end
			local cam=Workspace.CurrentCamera
			if not cam then return end
			local char=Player.Character
			local ignore=char and {char} or {}
			local ok,parts=pcall(function() return cam:GetPartsObscuringTarget({cam.Focus.Position},ignore) end)
			if ok then for _,part in ipairs(parts) do fade(part) end end
			-- Also catch walls containing the camera itself, including after a teleport.
			local overlap=OverlapParams.new()
			overlap.FilterType=Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances=ignore
			local found,inside=pcall(function() return Workspace:GetPartBoundsInBox(cam.CFrame,Vector3.new(0.5,0.5,0.5),overlap) end)
			if found then for _,part in ipairs(inside) do fade(part) end end
		end
		group:AddToggle("CameraClipFade",{Text="Camera noclip + surface fade",Default=false,Callback=function(on)
			stop()
			if not on then return end
			originalMode=Player.DevCameraOcclusionMode
			if not setMode(Enum.DevCameraOcclusionMode.Invisicam) then
				stop()
				notify("Camera warning","Camera occlusion mode could not be changed in this environment.",5,"warning")
				if Toggles.CameraClipFade then Toggles.CameraClipFade:SetValue(false) end
				return
			end
			enabled=true
			-- Restore before Roblox updates occlusion; apply our exact fade afterward.
			RunService:BindToRenderStep(beforeName,Enum.RenderPriority.Camera.Value-1,restore)
			RunService:BindToRenderStep(afterName,Enum.RenderPriority.Camera.Value+1,update)
		end})
		group:AddLabel("Obstructing surfaces fade to 0.6 transparency locally and restore when clear.")
		Hub.connect(Player.CharacterRemoving,restore)
		Hub.cleanup(stop)
	end)()
end
-- END CAMERA CLIP FADE

-- BEGIN NOTIFICATION SOUND LIBRARY
do
	(function()
		local group=Tabs.Sound:AddRightGroupbox("Notification Sounds")
		local presets={
			Pop="rbxassetid://124815381429574",
			["Bubble Pop"]="rbxassetid://106994752352532",
			Steam="rbxassetid://18317665126",
			Loaded="rbxassetid://71450094482101",
			Classic="rbxassetid://97643101798871",
		}
		local kinds={"info","warning","success","danger","join","leave","respawn","blackhole","kick"}
		local defaults={info="Pop",warning="Steam",success="Loaded",danger="Classic",
			join="Bubble Pop",leave="Pop",respawn="Loaded",blackhole="Classic",kick="Steam"}
		local labels={info="Info",warning="Warning",success="Success",danger="Danger",
			join="Join / rejoin",leave="Leave",respawn="Respawn",blackhole="Blackhole",kick="Player kicked"}
		local settings={}
		local voices={}
		local last={}
		local enabled=true
		local function asset(value)
			value=tostring(value or ""):match("^%s*(.-)%s*$")
			local id=value:match("^(%d+)$") or value:match("^rbxassetid://(%d+)$")
			if not id and value:match("^https?://") then id=value:match("[?&]id=(%d+)") or value:match("/library/(%d+)") or value:match("/store/asset/(%d+)") end
			if id and tonumber(id) and tonumber(id)>0 then return "rbxassetid://"..id end
		end
		local function classify(info)
			local explicit=tostring(info.Type or info.Kind or ""):lower()
			if explicit=="error" then explicit="danger" end
			local event=Hub.notificationEvent(info)
			if event then return event end
			if settings[explicit] then return explicit end
			local text=(tostring(info.Title or "").." "..tostring(info.Description or info.Content or "")):lower()
			for _,word in ipairs({"error","failed","failure","died","danger","respawn","blackhole","black hole","kicked","disconnected","lost"}) do if text:find(word,1,true) then return "danger" end end
			for _,word in ipairs({"warning","retry","retrying","unavailable","could not","couldn't","not confirmed","not active","waiting"}) do if text:find(word,1,true) then return "warning" end end
			for _,word in ipairs({"success","complete","loaded","saved","restored","ready","active","joined","[protected]"}) do if text:find(word,1,true) then return "success" end end
			return "info"
		end
		Hub.notificationKind=classify
		Hub.playNotificationSound=function(info,preview)
			if not Hub.alive or (not preview and not enabled) then return end
			local kind=classify(info)
			local config=settings[kind]
			local id=config.preset=="Custom" and config.custom or presets[config.preset]
			if not id or config.volume<=0 then return end
			local now=os.clock()
			if not preview and now-(last[kind] or -math.huge)<0.7 then return end
			last[kind]=now
			local voice=voices[kind]
			if not voice or not voice.Parent then voice=Hub.new("Sound",game:GetService("SoundService"));voices[kind]=voice end
			voice:Stop();voice.SoundId=id;voice.Volume=config.volume;voice.TimePosition=0
			pcall(function() voice:Play() end)
		end
		group:AddToggle("NotificationSoundsEnabled",{Text="Notification sounds",Default=true,Callback=function(on)
			enabled=on
			if not on then for _,voice in pairs(voices) do voice:Stop() end end
		end})
		for _,kind in ipairs(kinds) do
			local key=kind:sub(1,1):upper()..kind:sub(2)
			local label=labels[kind]
			local config={preset=defaults[kind],volume=0.4}
			settings[kind]=config
			group:AddDropdown("Notice"..key.."Sound",{Text=label.." sound",Values={"Off","Pop","Bubble Pop","Steam","Loaded","Classic","Custom"},Default=defaults[kind],Callback=function(value) config.preset=value end})
			group:AddInput("Notice"..key.."Asset",{Text=label.." custom sound ID",Default="",Finished=true,Callback=function(value)
				local id=asset(value)
				if tostring(value or ""):match("^%s*$") then config.custom=nil
				elseif id then config.custom=id
				else notify("Sound warning","Use a numeric sound ID, rbxassetid:// ID, or Roblox asset link.",4,"warning") end
			end})
			group:AddSlider("Notice"..key.."Volume",{Text=label.." volume",Default=0.4,Min=0,Max=2,Rounding=2,Callback=function(value) config.volume=value end})
			group:AddButton({Text="Preview "..kind.." sound",Func=function() Hub.playNotificationSound({Type=kind},true) end})
			if kind=="join" or kind=="leave" or kind=="respawn" or kind=="blackhole" or kind=="kick" then
				group:AddButton({Text="Preview "..kind.." alert",Func=function()
					notify(label.." preview","This is your "..label:lower().." notification style and sound.",5,kind)
				end})
			end
		end
		group:AddLabel("Custom sounds need Roblox permission in this experience. Off mutes a category.")
		Hub.cleanup(function()
			Hub.playNotificationSound=nil;Hub.notificationKind=nil
			for _,voice in pairs(voices) do
				voice:Stop();Hub.instances[voice]=nil;Hub.assetTargets[voice]=nil;voice:Destroy()
			end
		end)
	end)()
end
-- END NOTIFICATION SOUND LIBRARY

do
	(function()
		local group=Tabs.Notifications:AddRightGroupbox("Notification theme")
		local function color(id,label,key,default)
			group:AddInput(id,{Text=label,Default=default,Finished=true,Callback=function(value)
				local hex=tostring(value or ""):gsub("#","")
				if not hex:match("^%x%x%x%x%x%x$") then
					notify("Theme warning","Enter a six-digit HEX color, for example #6AB1FF.",4,"warning");return
				end
				Hub.setNoticePreference(key,Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)))
			end})
		end
		color("NoticeInfoColor","Info HEX","noticeColor_info","#6AB1FF")
		color("NoticeWarningColor","Warning HEX","noticeColor_warning","#FFCA69")
		color("NoticeSuccessColor","Success HEX","noticeColor_success","#6FE0A0")
		color("NoticeDangerColor","Danger HEX","noticeColor_danger","#FF737D")
		color("NoticeJoinColor","Join / rejoin HEX","noticeColor_join","#BE8CFF")
		color("NoticeLeaveColor","Leave HEX","noticeColor_leave","#BE8CFF")
		color("NoticeRespawnColor","Respawn HEX","noticeColor_respawn","#BE8CFF")
		color("NoticeBlackholeColor","Blackhole HEX","noticeColor_blackhole","#EA70FF")
		color("NoticeKickColor","Player kicked HEX","noticeColor_kick","#FF737D")
		color("NoticeBackgroundColor","Background base HEX","noticeBackground","#212121")
		color("NoticeBodyColor","Message text HEX","noticeBodyColor","#DCE0E8")
		group:AddSlider("NoticeBackgroundTransparency",{Text="Background transparency (1 = hidden)",Default=0,Min=0,Max=1,Rounding=2,Callback=function(value) Hub.setNoticePreference("noticeBackgroundTransparency",value) end})
		group:AddSlider("NoticeBackgroundTint",{Text="Background color tint (%)",Default=14,Min=0,Max=100,Rounding=0,Callback=function(value) Hub.setNoticePreference("noticeBackgroundTint",value/100) end})
		group:AddSlider("NoticeBorderThickness",{Text="Border thickness",Default=1.2,Min=0,Max=4,Rounding=1,Callback=function(value) Hub.setNoticePreference("noticeBorderThickness",value) end})
		group:AddSlider("NoticeCornerRadius",{Text="Corner radius",Default=10,Min=0,Max=24,Rounding=0,Callback=function(value) Hub.setNoticePreference("noticeCornerRadius",value) end})
		for _,kind in ipairs({"info","warning","success","danger"}) do
			group:AddButton({Text="Preview "..kind.." notification",Func=function()
				notify(kind:sub(1,1):upper()..kind:sub(2).." preview","Preview of your notification colors, border and sound.",5,kind)
			end})
		end
	end)()
end


-- BEGIN CHEATER SIGNAL MONITOR
do
	(function()
		local group=Tabs.Misc:AddLeftGroupbox("Cheaters")
		local records,announced,labels={},{},{}
		local monitor,alerts=true,true
		local selected,rebuilding,dropdown
		local renderedList
		local status=group:AddLabel("Waiting for player observations.")
		local detail=group:AddLabel("Select a player to see the observed setup.")
		local beamOn,movementOn=true,true
		local beamLimit,speedLimit=40,160
		local bursts,movement={},{}
		local incident=group:AddLabel("Network observations: no large payload recorded.")
		Hub.reportIncomingSignalPayload=function(bytes,remote,sender)
			if not monitor then return end
			incident:SetText(string.format("Large incoming payload: %.2f MiB on %s. Sender: %s.",bytes/1048576,tostring(remote),sender and sender.Name or "N/A"))

		end
		local function beamObserved(object)
			if not monitor or not beamOn or not object:IsA("Beam") then return end
			local ancestor=object.Parent
			local owner
			while ancestor and ancestor~=Workspace do
				if ancestor:IsA("Model") then
					local ok,person=pcall(function() return Players:GetPlayerFromCharacter(ancestor) end)
					if ok and person then owner=person;break end
				end
				ancestor=ancestor.Parent
			end
			-- An attachment endpoint identifies a target, not the creator: never use it here.
			if not owner or owner==Player then return end
			local now=os.clock();local bucket=bursts[owner.UserId]
			if not bucket or bucket.char~=owner.Character then bucket={start=now,count=0,char=owner.Character};bursts[owner.UserId]=bucket end
			if now-bucket.start>2 then bucket.start=now;bucket.count=0 end
			bucket.count=math.min(bucket.count+1,100000)
			if bucket.count>=beamLimit then bucket.untilTime=now+6 end
		end
		Hub.connect(Workspace.DescendantAdded,beamObserved)
		local function extraSignals(person,char,root,hum,reasons)
			local now=os.clock();local id=person.UserId
			local bucket=bursts[id]
			if beamOn and bucket and bucket.char==char and (bucket.untilTime or 0)>now then
				table.insert(reasons,"Beam burst in character hierarchy (sender unverified)")
			end
			if not movementOn then movement[id]=nil;return end
			local history=movement[id]
			if not history or history.char~=char then history={char=char,born=now,hits=0};movement[id]=history end
			local ragdoll=hum:FindFirstChild("Ragdolled")
			local held=person:FindFirstChild("IsHeld")
			local owner=root:FindFirstChild("PartOwner")
			local foreign=owner and owner.Value and owner.Value~="" and owner.Value~=person.Name and owner.Value~=person
			local velocity=root.AssemblyLinearVelocity
			local excluded=hum.SeatPart or hum.PlatformStand or root.Anchored or (ragdoll and ragdoll.Value) or (held and held.Value) or foreign or (velocity and velocity.Magnitude>250)
			local position=Hub.teleportFrame(root).Position
			if not position then return end
			if excluded or now-history.born<5 then history.hits=0;history.untilTime=nil
			elseif history.position and history.time then
				local dt=now-history.time
				if dt>=0.1 and dt<=1.5 then
					local speed=(position-history.position).Magnitude/dt
					if speed==speed and speed>speedLimit then
						history.hits=now-(history.hitTime or -math.huge)<=6 and history.hits+1 or 1
						history.hitTime=now
						if history.hits>=3 then history.untilTime=now+6 end
					elseif now-(history.hitTime or -math.huge)>6 then history.hits=0 end
				end
			end
			history.position=position;history.time=now
			if not excluded and (history.untilTime or 0)>now then table.insert(reasons,"Repeated movement anomaly (affected player; cause unverified)") end
		end
		group:AddToggle("CheaterBeamSignals",{Text="Observe character beam bursts",Default=true,Callback=function(on) beamOn=on;if not on then table.clear(bursts) end end})
		group:AddSlider("CheaterBeamThreshold",{Text="Beam creations per 2 seconds",Default=40,Min=10,Max=200,Rounding=0,Callback=function(v) beamLimit=v end})
		group:AddToggle("CheaterMovementSignals",{Text="Observe repeated movement anomalies",Default=true,Callback=function(on) movementOn=on;if not on then table.clear(movement) end end})
		group:AddSlider("CheaterMovementThreshold",{Text="Movement observation threshold (studs/sec)",Default=160,Min=80,Max=500,Rounding=0,Callback=function(v) speedLimit=v end})
		group:AddButton({Text="Enable incoming payload monitor",Func=function()
			if Toggles.IncomingPayloadMonitor then Toggles.IncomingPayloadMonitor:SetValue(true) end
		end})
		group:AddLabel("Packet/payload incidents need Incoming Payload Monitor enabled under Performance. ExtendGrabLine alerts show the server-provided sender, or N/A when unavailable.")
		Hub.connect(Players.PlayerRemoving,function(person) bursts[person.UserId]=nil;movement[person.UserId]=nil end)
		Hub.cleanup(function() Hub.reportIncomingSignalPayload=nil;table.clear(bursts);table.clear(movement) end)
		local function signals(person)
			if person==Player or person.Parent~=Players then return end
			local char=person.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health<=0 then return end
			local reasons={}
			local seat=hum.SeatPart
			if seat and seat.Parent then
				local weld=seat:FindFirstChild("SeatWeld")
				if not weld or not weld.Enabled then table.insert(reasons,"Gucci-like seat/weld setup") end
			end
			for _,part in pairs({root,root:FindFirstChild("RagdollTouchedHitbox"),root:FindFirstChild("FirePlayerPart")}) do
				if part and part.Parent then
					local ok,connected=pcall(function() return part:GetConnectedParts() end)
					if ok then
						for _,other in ipairs(connected) do
							if other.Name=="StickyPart" then table.insert(reasons,"StickyPart attached to character");break end
						end
						if reasons[#reasons]=="StickyPart attached to character" then break end
					end
				end
			end
			extraSignals(person,char,root,hum,reasons)
			return char,table.concat(reasons,"; "),#reasons
		end
		local function describe()
			local record=selected and records[selected]
			detail:SetText(record and ("@"..record.player.Name..": "..record.reason.." | Evidence: "..(record.families>1 and "multiple signals" or "single signal, low confidence")..(record.confirmed and " (repeated observation)" or " (checking)")) or "Select a player to see the observed setup.")
		end
		local function render()
			local values={};labels={};local selectedLabel
			local detected,pending=0,0
			for id,record in pairs(records) do
				local label="@"..record.player.Name.." — "..(record.confirmed and (record.families>1 and "Multiple signals: " or "Low confidence: ") or "Checking: ")..record.reason
				labels[label]=id;table.insert(values,label)
				if id==selected then selectedLabel=label end
				if record.confirmed then detected+=1 else pending+=1 end
			end
			table.sort(values)
			local signature=table.concat(values,"\n")
			if signature~=renderedList then
				renderedList=signature
				rebuilding=true;dropdown:SetValues(values)
				if selectedLabel then dropdown:SetValue(selectedLabel) end
				rebuilding=false
			end
			status:SetText(string.format("%d repeated observations, %d checking. Monitor %s.",detected,pending,monitor and "on" or "paused"))
			describe()
		end
		local function observe(person)
			local id=person.UserId
			local ok,char,reason,families=pcall(signals,person)
			if not ok then return end -- A streamed/removed character is not evidence.
			if not char or reason=="" then records[id]=nil;return end
			local now=os.clock();local record=records[id]
			local wasConfirmed=record and record.confirmed
			if not record or record.char~=char or record.reason~=reason then
				wasConfirmed=false
				record={player=person,char=char,reason=reason,seen=now,confirmed=false,families=families};records[id]=record
			elseif now-record.seen>=0.5 then record.confirmed=true end
			if record.confirmed and not wasConfirmed and alerts and now-(announced[id] or -math.huge)>=60 then
				announced[id]=now
				notify("Player signal detected","@"..person.Name..": "..reason..". This is an observed setup, not proof of cheating.",6,"warning")
			end
		end
		dropdown=group:AddDropdown("CheaterSignalPlayers",{Text="Observed players",Values={},Callback=function(value)
			if rebuilding then return end;selected=labels[value];describe()
		end})
		group:AddToggle("CheaterSignalMonitor",{Text="Monitor player signals",Default=true,Callback=function(on) monitor=on end})
		group:AddToggle("CheaterSignalAlerts",{Text="Notify on repeated signals",Default=true,Callback=function(on) alerts=on end})
		Hub.cheaterSignals=records
		Hub.scanCheaterSignals=function()
			for _,person in ipairs(Players:GetPlayers()) do observe(person) end
			render()
		end
		group:AddButton({Text="Find cheaters / refresh signals",Func=Hub.scanCheaterSignals})
		group:AddLabel("Gucci/sticky connections are heuristics. Someone else may have applied them. No automatic targeting or reporting.")
		local elapsed,cursor=0,1
		Hub.connect(RunService.Heartbeat,function(dt)
			if not monitor then return end
			elapsed+=dt;if elapsed<0.25 then return end;elapsed=0
			local roster=Players:GetPlayers()
			if cursor>#roster then cursor=1 end
			for _=1,4 do
				local person=roster[cursor];if not person then break end
				observe(person);cursor+=1
			end
			render()
		end)
		Hub.connect(Players.PlayerRemoving,function(person) records[person.UserId]=nil;announced[person.UserId]=nil;render() end)
		Hub.cleanup(function() monitor=false;Hub.cheaterSignals=nil;Hub.scanCheaterSignals=nil;table.clear(records);table.clear(announced) end)
	end)()
end

-- END CHEATER SIGNAL MONITOR

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
		-- Appearance applies only to shurikens created by this assistance controller.
		local appearanceGroup=Tabs.Whitelist:AddRightGroupbox("Whitelist Shuriken Appearance")
		local appearance={enabled=false,fill=Color3.fromRGB(255,0,0),outline=Color3.fromRGB(255,255,255),
			fillAlpha=0.5,outlineAlpha=0,rainbowFill=false,rainbowOutline=false}
		local visuals={}
		local function clearShurikenVisual(model)
			local visual=visuals[model]
			if not visual then return end
			visuals[model]=nil
			if visual.highlight then
				Hub.instances[visual.highlight]=nil;Hub.assetTargets[visual.highlight]=nil
				visual.highlight:Destroy()
			end
			for part,transparency in pairs(visual.parts) do
				if part.Parent then pcall(function() part.Transparency=transparency end) end
			end
		end
		local function updateShurikenVisuals()
			local show=appearance.enabled or appearance.rainbowFill or appearance.rainbowOutline
			local seen={}
			local rainbow=Color3.fromHSV(os.clock()%5/5,1,1)
			for _,record in pairs(records) do
				local model=record.toy
				if show and modes.kick and trusted(record.player) and model and created[model] and model.Parent==ownFolder() then
					seen[model]=true
					local visual=visuals[model]
					if not visual then visual={parts={}};visuals[model]=visual end
					local highlight=visual.highlight
					if not highlight or highlight.Parent~=model then
						if highlight then Hub.instances[highlight]=nil;Hub.assetTargets[highlight]=nil;highlight:Destroy() end
						highlight=Hub.new("Highlight",model);highlight.Name="ArrivaWhitelistShurikenHighlight";visual.highlight=highlight
					end
					highlight.Adornee=model;highlight.Enabled=true;highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
					highlight.FillColor=appearance.rainbowFill and rainbow or appearance.fill
					highlight.OutlineColor=appearance.rainbowOutline and rainbow or appearance.outline
					highlight.FillTransparency=appearance.fillAlpha;highlight.OutlineTransparency=appearance.outlineAlpha
					for _,part in ipairs(model:GetDescendants()) do
						if part:IsA("BasePart") and (part:IsA("MeshPart") or part.Name=="Part") then
							if visual.parts[part]==nil then visual.parts[part]=part.Transparency end
							part.Transparency=0
						end
					end
				end
			end
			for model in pairs(visuals) do if not seen[model] then clearShurikenVisual(model) end end
		end
		local function appearanceChanged() updateShurikenVisuals();Hub.requestSave() end
		appearanceGroup:AddToggle("WhitelistShurikenHighlight",{Text="Highlight whitelist shurikens",Default=false,Callback=function(on) appearance.enabled=on;appearanceChanged() end})
		local function colorInput(id,label,key,default)
			appearanceGroup:AddInput(id,{Text=label,Default=default,Finished=true,Callback=function(value)
				local hex=tostring(value or ""):gsub("^#","")
				if not hex:match("^%x%x%x%x%x%x$") then notify("Color warning","Enter a six-digit HEX color.",4,"warning");return end
				appearance[key]=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16));appearanceChanged()
			end})
		end
		colorInput("WhitelistShurikenFillColor","Fill color HEX","fill","FF0000")
		colorInput("WhitelistShurikenOutlineColor","Outline color HEX","outline","FFFFFF")
		appearanceGroup:AddSlider("WhitelistShurikenFillAlpha",{Text="Fill transparency",Default=0.5,Min=0,Max=1,Rounding=2,Callback=function(value) appearance.fillAlpha=value;appearanceChanged() end})
		appearanceGroup:AddSlider("WhitelistShurikenOutlineAlpha",{Text="Outline transparency",Default=0,Min=0,Max=1,Rounding=2,Callback=function(value) appearance.outlineAlpha=value;appearanceChanged() end})
		appearanceGroup:AddToggle("WhitelistShurikenRainbowFill",{Text="Rainbow fill",Default=false,Callback=function(on) appearance.rainbowFill=on;appearanceChanged() end})
		appearanceGroup:AddToggle("WhitelistShurikenRainbowOutline",{Text="Rainbow outline",Default=false,Callback=function(on) appearance.rainbowOutline=on;appearanceChanged() end})
		local function destroyToy(model)
			clearShurikenVisual(model)
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
			if not root or not hum or hum.Health<=0 or hum.SeatPart or root.Anchored or (held and held.Value)
				or Hub.safeZoneLoopActive or Hub.characterFlightActive or Hub.blobFlightActive then return end
			for _,run in pairs(Hub.targetLoopRuns or {}) do if run.enabled then return end end
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
				if visit.sharedMasked then Hub.teleportPart(visit.root,visit.original) else visit.root.CFrame=visit.original end;visit.root.AssemblyLinearVelocity=Vector3.zero
				if visit.head and visit.head.Parent==visit.char then visit.head.CFrame=visit.headFrame end
			end
			if visit and Hub.interactionVisitLock==visit then Hub.interactionVisitLock=nil end
		end
		Hub.teleportMaskCancelers.WhitelistAssist=function() epoch+=1;finishVisit() end
		local function acquire(part,record,ticket,kind,toy)
			if not valid(record,ticket,kind) then return false end
			if Hub.interactionVisitLock and Hub.interactionVisitLock~=ownVisit then say("Assistance waiting: another movement visit is running.");return false end
			local root,char=readySelf()
			if not root then say("Assistance waiting: your character is busy, held, seated or flying.");return false end
			if (Hub.teleportFrame(root).Position-part.Position).Magnitude>30 then
				if not allowVisits then say("Distant assistance needs Allow brief assist visits enabled.");return false end
				local destination=part.Position+Vector3.new(0,3,6)
				if destination.Y<=World.FallenPartsDestroyHeight+8 then return false end
				ownVisit={root=root,char=char,original=Hub.teleportFrame(root),destination=destination}
				Hub.interactionVisitLock=ownVisit
				local visit=ownVisit
				visit.frame=CFrame.new(destination)*root.CFrame.Rotation
				visit.head=char:FindFirstChild("Head")
				visit.headFrame=visit.head and visit.head.CFrame
				if not visit.headFrame then visit.head=nil end
				visit.sharedMasked=Hub.teleportMaskEnabled()
				visit.masked=maskVisits or visit.sharedMasked
				if visit.sharedMasked then Hub.teleportPart(root,visit.frame) end
				if visit.masked and not visit.sharedMasked then
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
				if ownVisit and not ownVisit.masked and (Hub.teleportFrame(root).Position-ownVisit.destination).Magnitude>=12 then return false end
				if owned(part,not toy and record.char or nil,toy) then return true end
				-- Narrow defensive path: ONLY this current trusted player's root,
				-- or a sticky part inside this component's own newly spawned toy.
				local permitted=not toy and part==record.root
					or toy and created[toy] and toy.Parent==ownFolder() and part:IsDescendantOf(toy)
				local origin=ownVisit and ownVisit.masked and ownVisit.frame.Position or Hub.teleportFrame(root).Position
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
			if spawnBusy or busy or os.clock()<nextSpawn or not readySelf() then
				record.phase=record.phase or "Waiting for spawn cooldown or free character."
				return
			end
			local count=0;for model in pairs(created) do if model.Parent then count+=1 else created[model]=nil end end
			if count>=toyLimit then say("Whitelist anti-kick toy limit reached.");return end
			local menu=Storage:FindFirstChild("MenuToys")
			local remote=menu and menu:FindFirstChild("SpawnToyRemoteFunction")
			local can=me:FindFirstChild("CanSpawnToy")
			if not remote or (can and not can.Value) then return end
			local root=readySelf();local frame=Hub.teleportFrame(root)*CFrame.new(0,4,0)
			local before={};local folder=ownFolder()
			if folder then for _,model in ipairs(folder:GetChildren()) do before[model]=true end end
			spawnBusy=true;nextSpawn=os.clock()+4
			record.phase="Spawn requested; waiting for returned toy or folder replication."
			local ticket=epoch
			task.spawn(function()
				local result
				local ok,err=pcall(function() result=remote:InvokeServer("NinjaShuriken",frame,Vector3.new(0,97.69000244140625,0)) end)
				folder=ownFolder()
				if ok and (typeof(result)~="Instance" or not result:IsA("Model")) then
					local deadline=os.clock()+1.5
					repeat
						folder=ownFolder()
						local candidates={}
						for _,model in ipairs(folder and folder:GetChildren() or {}) do
							if not before[model] and model:IsA("Model") and model.Name=="NinjaShuriken" then
								-- Identify the newly added model, not its current
								-- physics position or still-replicating descendants.
								table.insert(candidates,model)
							end
						end
						if #candidates==1 then result=candidates[1];break end
						if os.clock()>=deadline then break end
						task.wait(0.1)
					until false
				end
				if ok and folder and typeof(result)=="Instance" and result:IsA("Model") and result.Name=="NinjaShuriken" and result.Parent==folder and not before[result] then
					created[result]=true
					if valid(record,ticket,"kick") and not record.toy then
						record.toy=result;record.partsSince=os.clock();record.phase="Toy spawned; waiting for sticky parts."
					else destroyToy(result) end
				elseif ok then
					-- Never adopt pre-existing toys or ambiguous simultaneous spawns.
					record.phase="Spawn completed, but no unique new NinjaShuriken was identified in your toy folder."
					say(record.phase)
					nextSpawn=os.clock()+8
				else record.phase="Spawn request failed: "..tostring(err):sub(1,120);say(record.phase);nextSpawn=os.clock()+8 end
				spawnBusy=false
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
			if busy or os.clock()<(record.nextStick or 0) then return end
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
					if char and not records[person.UserId] then records[person.UserId]={player=person,char=char,root=root,hum=hum,saved=Hub.teleportFrame(root)} end
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
		local elapsed,visualElapsed=0,0
		Hub.connect(Run.Heartbeat,function(dt)
			elapsed+=dt;visualElapsed+=dt
			if elapsed>=0.2 then elapsed=0;Hub.sampleWhitelistAssistance() end
			if visualElapsed>=0.05 then visualElapsed=0;updateShurikenVisuals() end
		end)
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
			for model in pairs(visuals) do clearShurikenVisual(model) end
			table.clear(records);Hub.sampleWhitelistAssistance=nil
		end)
	end)()
end

-- BEGIN SESSION AND PERSONALIZATION TOOLS
-- Register these controls before settings load; gameplay controllers are unchanged.
do
	(function()
		local group=Tabs.Notifications:AddLeftGroupbox("Event messages")
		local prefs=Hub.noticePreferences
		group:AddToggle("NotificationMaster",{Text="Enable notifications",Default=true,Callback=function(on) prefs.enabled=on end})
		group:AddLabel("Message placeholders: %player%, %event%, %message%. Blank restores the original message.")
		for _,entry in ipairs({{"join","Join / rejoin"},{"leave","Leave"},{"respawn","Respawn"},{"blackhole","Blackhole"},{"kick","Player kicked"}}) do
			local kind,label=entry[1],entry[2]
			group:AddToggle("EventNotice_"..kind,{Text=label.." alerts",Default=true,Callback=function(on) prefs.events[kind]=on end})
			group:AddInput("EventMessage_"..kind,{Text=label.." message",Default="%message%",Finished=true,Callback=function(value)
				local text=tostring(value or ""):sub(1,512)
				prefs.templates[kind]=text:match("^%s*$") and "%message%" or text
			end})
		end
		local history=Tabs.Notifications:AddRightGroupbox("Notification history")
		local entries={};local selected
		local detail=history:AddLabel("The most recent 50 notifications are kept for this session.")
		local picker
		local function refresh()
			local names={};entries={};selected=nil
			for index=#Hub.noticeHistory,1,-1 do
				local entry=Hub.noticeHistory[index]
				local label=string.format("%02d | %s | %s",index,entry.at,entry.Title:sub(1,90))
				entries[label]=entry;table.insert(names,label)
			end
			picker:SetValues(names);picker:SetValue(nil)
			detail:SetText("History: "..#names.." notifications. Select an entry.")
		end
		picker=history:AddDropdown("NotificationHistoryEntry",{Text="Recent notifications",Values={},Callback=function(value)
			selected=entries[value]
			detail:SetText(selected and (selected.Title..": "..selected.Description) or "Select an entry.")
		end})
		SaveManager.ignored.NotificationHistoryEntry=true
		history:AddButton({Text="Refresh history",Func=refresh})
		history:AddButton({Text="Replay selected alert",Func=function()
			if not selected then return end
			local info=table.clone(selected);info.HistoryReplay=true;Library:Notify(info)
		end})
		history:AddButton({Text="Copy notification history",Func=function()
			if not setclipboard then notify("Clipboard unavailable","Your environment does not support clipboard access.",4,"warning");return end
			local lines={}
			for _,entry in ipairs(Hub.noticeHistory) do table.insert(lines,entry.at.." | "..entry.Title.." | "..entry.Description) end
			setclipboard(table.concat(lines,"\n"))
		end})
		history:AddButton({Text="Clear history",Func=function() table.clear(Hub.noticeHistory);refresh() end})
		Hub.cleanup(function() table.clear(Hub.noticeHistory) end)
	end)();

	(function()
		local group=Tabs["UI Settings"]:AddRightGroupbox("Config profiles")
		local name,selected="",""
		local status=group:AddLabel("Save named profiles alongside your automatic settings.")
		local picker
		local function refresh()
			local names={}
			if type(listfiles)=="function" and Hub.storage and SaveManager.folder then
				local ok,files=pcall(listfiles,SaveManager.folder)
				if ok then
					for _,file in ipairs(files) do
						local candidate=tostring(file):gsub("\\","/"):match("([^/]+)%.json$")
						if candidate and Hub.profileName(candidate) then table.insert(names,candidate) end
					end
				end
			end
			table.sort(names);picker:SetValues(names)
			if not table.find(names,selected) then selected="";picker:SetValue(nil) end
		end
		local function run(action)
			if not Hub.ready or not Hub.storage then status:SetText("File storage is unavailable or settings are still loading.");return end
			local ok,err=pcall(action)
			if not ok then status:SetText(tostring(err));notify("Profile warning",tostring(err),6,"warning") end
		end
		group:AddInput("ProfileName",{Text="Profile name",Default="",Finished=true,Callback=function(value) name=tostring(value or "") end})
		picker=group:AddDropdown("ProfileSelection",{Text="Saved profiles",Values={},Callback=function(value) selected=value or "" end})
		SaveManager.ignored.ProfileName=true;SaveManager.ignored.ProfileSelection=true
		group:AddButton({Text="Refresh profiles",Func=refresh})
		group:AddButton({Text="Save named profile",Func=function() run(function()
			local valid,err=Hub.profileName(name);assert(valid,err)
			local ok,reason=SaveManager:Save(valid);assert(ok,reason)
			refresh();status:SetText("Saved and verified: "..valid)
		end) end})
		group:AddButton({Text="Load selected profile",Func=function() run(function()
			local valid,err=Hub.profileName(selected);assert(valid,err)
			local ok,reason=SaveManager:Load(valid);assert(ok,reason)
			status:SetText("Loaded: "..valid..". Enabled features may still be starting.")
		end) end})
		group:AddButton({Text="Delete selected profile",Func=function() run(function()
			assert(type(delfile)=="function","Deleting files is unavailable.")
			local valid,err=Hub.profileName(selected);assert(valid,err)
			local path=SaveManager.folder.."/"..valid..".json"
			if isfile(path) then delfile(path) end
			if isfile(path..".bak") then delfile(path..".bak") end
			refresh();status:SetText("Deleted: "..valid)
		end) end})
		group:AddButton({Text="Copy current settings JSON",Func=function()
			if not setclipboard then status:SetText("Clipboard access is unavailable.");return end
			local json,ok,err=SaveManager:SaveJSON()
			if not ok then status:SetText(tostring(err));return end
			setclipboard(json);status:SetText("Settings copied, including your whitelist.")
		end})
		group:AddLabel("Save named profile overwrites that name. AutoSave is reserved; failed-load protection stays in place.")
	end)();

	(function()
		local group=Tabs.Misc:AddRightGroupbox("Session tools")
		local teleporting=false
		local function copy(value)
			if setclipboard then setclipboard(value) else notify("Clipboard unavailable","Clipboard access is unavailable.",4,"warning") end
		end
		group:AddLabel("Place: "..tostring(game.PlaceId).." | Server: "..(game.JobId~="" and game.JobId or "Studio"))
		group:AddButton({Text="Copy server ID",Func=function() copy(game.JobId) end})
		group:AddButton({Text="Copy server join link",Func=function()
			copy("https://www.roblox.com/games/start?placeId="..game.PlaceId.."&gameInstanceId="..game.JobId)
		end})
		group:AddButton({Text="Rejoin this server",Func=function()
			if teleporting then return end
			if game.JobId=="" then notify("Rejoin unavailable","This session has no live server ID.",4,"warning");return end
			local saved,reason=Hub.flushSettings(false)
			if not saved then notify("Rejoin paused",tostring(reason),6,"warning");return end
			teleporting=true
			local ok,err=pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,Player) end)
			if not ok then teleporting=false;notify("Rejoin failed",tostring(err),6,"warning") end
		end})
		Hub.connect(game:GetService("TeleportService").TeleportInitFailed,function(person,_,message)
			if person==Player and teleporting then teleporting=false;notify("Rejoin failed",tostring(message),6,"warning") end
		end)
		group:AddButton({Text="Unlock mouse",Func=function() if Hub.menuMouse then Hub.menuMouse(true) end end})
		group:AddButton({Text="Restore mouse control",Func=function() if Hub.menuMouse then Hub.menuMouse(false) end end})
	end)();

	(function()
		local group=Tabs.Player:AddRightGroupbox("Spawn bookmark")
		local saved,autoReturn,generation=nil,false,0
		local status=group:AddLabel("No spawn bookmark saved. Bookmarks last for this session.")
		local function readyRoot(char)
			if not Hub.alive or Player.Character~=char or Hub.interactionVisitLock or Hub.safeZoneLoopActive
				or Hub.blobFlightActive or Hub.characterFlightActive then return end
			for _,run in pairs(Hub.targetLoopRuns or {}) do if run.enabled then return end end
			local root,hum
			if Toggles.AutoGucciBlobToggle and Toggles.AutoGucciBlobToggle.Value then
				local proof=Hub.gucciVerifiedRun
				if not proof or not proof.Confirmed or proof.Char~=char then return end
				root,hum=proof.HRP,proof.Hum
			else
				root=char and char:FindFirstChild("HumanoidRootPart")
				hum=char and char:FindFirstChildOfClass("Humanoid")
			end
			local held=Player:FindFirstChild("IsHeld")
			if root and root.Parent==char and hum and hum.Parent==char and hum.Health>0
				and not hum.SeatPart and not root.Anchored and not (held and held.Value) then return root end
		end
		local function restore(char)
			local root=readyRoot(char)
			if not saved or not root then return false end
			if not Hub.finiteVector(saved.Position) or saved.Position.Y<=Workspace.FallenPartsDestroyHeight+8 then return false end
			Hub.teleportPart(root, saved);root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
			status:SetText("Returned to your spawn bookmark.");return true
		end
		group:AddButton({Text="Save current spawn location",Func=function()
			local root=readyRoot(Player.Character)
			if not root or not Hub.finiteVector(Hub.teleportFrame(root).Position) then status:SetText("Wait for a free, live character and confirmed Gucci if enabled.");return end
			saved=Hub.teleportFrame(root);status:SetText(string.format("Spawn bookmark saved at %.0f, %.0f, %.0f.",Hub.teleportFrame(root).Position.X,Hub.teleportFrame(root).Position.Y,Hub.teleportFrame(root).Position.Z))
		end})
		group:AddButton({Text="Return to spawn bookmark",Func=function()
			if not restore(Player.Character) then status:SetText("No valid bookmark, or your character is busy.") end
		end})
		group:AddToggle("ReturnToSpawnBookmark",{Text="Return here after respawning",Default=false,Callback=function(on) autoReturn=on;generation+=1 end})
		group:AddButton({Text="Clear spawn bookmark",Func=function() saved=nil;generation+=1;status:SetText("Spawn bookmark cleared.") end})
		Hub.connect(Player.CharacterAdded,function(char)
			generation+=1;local ticket=generation
			if not autoReturn or not saved then return end
			task.spawn(function()
				local deadline=os.clock()+20
				while Hub.alive and autoReturn and saved and generation==ticket and Player.Character==char and os.clock()<deadline do
					if restore(char) then return end
					task.wait(0.2)
				end
			end)
		end)
		Hub.cleanup(function() autoReturn=false;generation+=1;saved=nil end)
	end)();

	(function()
		local group=Tabs.Customization:AddRightGroupbox("Session overlay")
		local keys=Tabs.KeyBinds:AddRightGroupbox("Keybind display")
		local watermarkOn,keysOn,assignedOnly=false,false,true
		local gui,watermark,keyText
		local started=os.clock()
		local function create()
			if gui then return end
			gui=Hub.new("ScreenGui",Player:WaitForChild("PlayerGui"));gui.Name="ArrivaSessionOverlay";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true
			local function label(name,position,size)
				local item=Hub.new("TextLabel",gui);item.Name=name;item.Position=position;item.Size=size
				item.BackgroundColor3=Color3.fromRGB(29,21,40);item.BackgroundTransparency=0.15
				item.TextColor3=Color3.fromRGB(220,195,255);item.Font=Enum.Font.Gotham;item.TextSize=13
				item.TextXAlignment=Enum.TextXAlignment.Left;item.TextYAlignment=Enum.TextYAlignment.Top;item.TextWrapped=true;item.RichText=false
				local padding=Hub.new("UIPadding",item);padding.PaddingLeft=UDim.new(0,10);padding.PaddingTop=UDim.new(0,8)
				local corner=Hub.new("UICorner",item);corner.CornerRadius=UDim.new(0,8)
				item.Visible=false;return item
			end
			watermark=label("Watermark",UDim2.new(0,12,0,48),UDim2.fromOffset(340,34))
			keyText=label("Keybinds",UDim2.new(0,12,0,90),UDim2.fromOffset(280,280))
		end
		local function visibility()
			if watermarkOn or keysOn then create() end
			if watermark then watermark.Visible=watermarkOn;keyText.Visible=keysOn end
		end
		group:AddToggle("SessionWatermark",{Text="Show session watermark",Default=false,Callback=function(on) watermarkOn=on;visibility() end})
		keys:AddToggle("KeybindOverlay",{Text="Show keybind list",Default=false,Callback=function(on) keysOn=on;visibility() end})
		keys:AddToggle("KeybindAssignedOnly",{Text="Only show assigned keys",Default=true,Callback=function(on) assignedOnly=on end})
		keys:AddButton({Text="Check keybind conflicts",Func=function()
			local conflicts=Hub.keybindConflictReport()
			notify("Keybind check",#conflicts>0 and table.concat(conflicts,"\n") or "No shared shortcuts found.",8,#conflicts>0 and "warning" or "success")
		end})
		local elapsed,frames=0,0
		Hub.connect(RunService.Heartbeat,function(dt)
			if not watermarkOn and not keysOn then return end
			elapsed+=dt;frames+=1;if elapsed<1 then return end
			local fps=math.floor(frames/elapsed+0.5);elapsed=0;frames=0
			if watermarkOn then
				local ping="N/A"
				pcall(function() ping=game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString() end)
				local minutes=math.floor((os.clock()-started)/60)
				watermark.Text=string.format("ARRIVA 2.5  |  %d FPS  |  %s  |  %dm",fps,ping,minutes)
			end
			if keysOn then
				local lines={"KEYBINDS"}
				for _,definition in ipairs(Hub.keybindDefinitions) do
					local option=Options[definition.id];local key=tostring(option and option.Value or definition.default or "None")
					if not assignedOnly or (key~="None" and key~="Unknown" and key~="") then table.insert(lines,key.."  —  "..definition.label) end
				end
				keyText.Text=table.concat(lines,"\n");keyText.Size=UDim2.fromOffset(280,math.max(42,#lines*18+18))
			end
		end)
		Hub.cleanup(function() watermarkOn=false;keysOn=false;if gui then gui:Destroy();gui=nil end end)
	end)();
end
-- END SESSION AND PERSONALIZATION TOOLS

-- NPC camera and own-NPC steering; no teleport-follow loop or ownership requests.
do
	(function()
		local group=Tabs.Player:AddRightGroupbox("NPC Camera & Control")
		local travel=Tabs.Misc:AddRightGroupbox("Camera Travel")
		local status=group:AddLabel("Select an NPC. Camera viewing works independently of Gucci.")
		local selection,view,drive,picker
		local choices={};local scanEpoch=0
		local speed,exitTeleport=16,false
		local keys={};local bindings={};local stick=Vector2.zero
		local actions=game:GetService("ContextActionService")
		local stopView,stopDrive
		local function eligible(model,ownOnly)
			if not model or not model.Parent or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then return end
			local ancestor=model
			while ancestor and ancestor~=Workspace do
				if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then return end
				ancestor=ancestor.Parent
			end
			local hum=model:FindFirstChildOfClass("Humanoid")
			local root=model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			if not hum or hum.Health<=0 or not root or not root:IsA("BasePart") or not root:IsDescendantOf(model) then return end
			if ownOnly then
				local folder=Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
				local assembly=root.AssemblyRootPart or root
				if model.Parent~=folder or not assembly:IsDescendantOf(model) or root.Anchored or assembly.Anchored or assembly.ReceiveAge~=0 or hum.SeatPart then return end
				local owner=root:FindFirstChild("PartOwner")
				if owner and owner.Value and owner.Value~="" and owner.Value~=Player.Name and owner.Value~=Player then return end
				for _,part in ipairs(root:GetConnectedParts(true)) do if not part:IsDescendantOf(model) or part:IsA("Seat") or part:IsA("VehicleSeat") then return end end
			end
			return hum,root
		end
		function Hub.teleportBelowCamera(frame)
			local root,char,hum=Hub.freeCharacterForTools()
			if not root then return false,char end
			local camera=Workspace.CurrentCamera;frame=frame or (camera and camera.CFrame)
			if not frame or not Hub.finiteVector(frame.Position) then return false,"Camera position is unavailable." end
			if (frame.Position-Hub.teleportFrame(root).Position).Magnitude>512 then return false,"Camera is more than 512 studs away." end
			local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances=selection and {char,selection} or {char};params.IgnoreWater=true;params.RespectCanCollide=true
			local hit=Workspace:Raycast(frame.Position+Vector3.new(0,4,0),Vector3.new(0,-204,0),params)
			if not hit or not ((hit.Instance:IsA("BasePart") and hit.Instance.Anchored) or hit.Instance:IsA("Terrain")) or hit.Normal.Y<0.6 then return false,"No stable ground below the camera." end
			local destination=hit.Position+Vector3.new(0,math.max(3,hum.HipHeight+root.Size.Y/2+0.5),0)
			if not Hub.finiteVector(destination) or destination.Y<=Workspace.FallenPartsDestroyHeight+8 then return false,"Destination is outside the safe map height." end
			if (destination-Hub.teleportFrame(root).Position).Magnitude>512 then return false,"Ground destination is more than 512 studs away." end
			local facing=Vector3.new(frame.LookVector.X,0,frame.LookVector.Z)
			local goal=Hub.safeLookAt(destination,destination+facing,Hub.teleportFrame(root).LookVector)
			if not goal then return false,"Camera direction is unavailable." end
			Hub.teleportPart(root, goal);root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
			return true
		end
		stopDrive=function()
			local old=drive;drive=nil;keys={};stick=Vector2.zero
			for _,name in ipairs(bindings) do actions:UnbindAction(name) end;table.clear(bindings)
			if old and old.hum.Parent then
				pcall(function() old.hum:Move(Vector3.zero,false);if old.hum.WalkSpeed==old.appliedSpeed then old.hum.WalkSpeed=old.walkSpeed end end)
			end
		end
		stopView=function(allowTravel)
			stopDrive();local old=view;view=nil
			local camera=Workspace.CurrentCamera
			local departure=camera and camera.CFrame
			if old and old.camera.Parent and old.camera.CameraSubject==old.hum then
				local fallback=Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
				pcall(function()
					old.camera.CameraSubject=old.subject and old.subject.Parent and old.subject or fallback
					old.camera.CameraType=old.kind
				end)
			end
			if old and allowTravel and exitTeleport and departure then
				local ok,reason=Hub.teleportBelowCamera(departure)
				status:SetText(ok and "Returned near the camera." or ("Camera return skipped: "..tostring(reason)))
			end
		end
		local function startView()
			stopView(false)
			local hum=eligible(selection,false);local camera=Workspace.CurrentCamera
			if not hum or not camera then status:SetText("Select a live NPC first.");return false end
			if Toggles.LocalSpectatorEnabled and Toggles.LocalSpectatorEnabled.Value then Toggles.LocalSpectatorEnabled:SetValue(false) end
			view={model=selection,hum=hum,camera=camera,subject=camera.CameraSubject,kind=camera.CameraType}
			camera.CameraType=Enum.CameraType.Custom;camera.CameraSubject=hum
			status:SetText("Viewing "..selection.Name..". Your character has not moved.");return true
		end
		local function stopAll(allowTravel)
			stopView(allowTravel==true)
			if Toggles.NPCDrive and Toggles.NPCDrive.Value then Toggles.NPCDrive:SetValue(false) end
			if Toggles.NPCView and Toggles.NPCView.Value then Toggles.NPCView:SetValue(false) end
		end
		local function refreshChoices()
			local names={};for name,model in pairs(choices) do if eligible(model,false) then table.insert(names,name) else choices[name]=nil end end
			table.sort(names);picker:SetValues(names)
		end
		local function scan()
			scanEpoch+=1;local ticket=scanEpoch
			choices={}
			if selection and eligible(selection,false) then choices[selection:GetFullName()]=selection end
			refreshChoices();local count=0
			Hub.scanDescendants(Workspace,function(object)
				if object:IsA("Humanoid") and eligible(object.Parent,false) and count<80 then
					local model=object.Parent;choices[model:GetFullName()]=model;count+=1
					Hub.queueRefresh("npcChoices",refreshChoices)
				end
			end,function() return Hub.alive and scanEpoch==ticket and count<80 end)
		end
		picker=group:AddDropdown("NPCSelection",{Text="NPC",Values={},Callback=function(value)
			stopAll();selection=choices[value]
		end})
		SaveManager.ignored.NPCSelection=true
		group:AddButton({Text="Refresh NPC list",Func=scan})
		group:AddToggle("NPCView",{Text="View selected NPC",Default=false,Callback=function(on)
			if on then if not startView() and Toggles.NPCView then Toggles.NPCView:SetValue(false) end
			else
				stopView(true)
				if Toggles.NPCDrive and Toggles.NPCDrive.Value then Toggles.NPCDrive:SetValue(false) end
			end
		end})
		group:AddToggle("NPCDrive",{Text="Steer my selected NPC",Default=false,Callback=function(on)
			stopDrive();if not on then return end
			local hum,root=eligible(selection,true)
			if hum and root and (not view or view.model~=selection) and Toggles.NPCView then Toggles.NPCView:SetValue(true) end
			if not hum or not root or not view then
				status:SetText("Steering requires a live NPC in your own toy folder with confirmed local ownership.")
				if Toggles.NPCDrive then Toggles.NPCDrive:SetValue(false) end;return
			end
			drive={model=selection,hum=hum,root=root,walkSpeed=hum.WalkSpeed,appliedSpeed=speed};hum.WalkSpeed=speed
			local definitions={{"Forward","W",Enum.KeyCode.W,Enum.KeyCode.Up},{"Back","S",Enum.KeyCode.S,Enum.KeyCode.Down},
				{"Left","A",Enum.KeyCode.A,Enum.KeyCode.Left},{"Right","D",Enum.KeyCode.D,Enum.KeyCode.Right},{"Jump","Jump",Enum.KeyCode.Space,Enum.KeyCode.ButtonA}}
			for i,entry in ipairs(definitions) do
				local direction=entry[1];local name="ArrivaNPC"..direction;table.insert(bindings,name)
				actions:BindActionAtPriority(name,function(_,state)
					if UserInputService:GetFocusedTextBox() then keys={};return Enum.ContextActionResult.Pass end
					keys[direction]=state==Enum.UserInputState.Begin or state==Enum.UserInputState.Change
					if direction=="Jump" and keys[direction] and drive then drive.hum.Jump=true end
					return Enum.ContextActionResult.Sink
				end,true,Enum.ContextActionPriority.High.Value+1,entry[3],entry[4])
				actions:SetTitle(name,entry[2]);actions:SetPosition(name,UDim2.new(1,-70-((i-1)%3)*60,1,-150-math.floor((i-1)/3)*60))
			end
			local name="ArrivaNPCStick";table.insert(bindings,name)
			actions:BindActionAtPriority(name,function(_,state,input)
				if UserInputService:GetFocusedTextBox() then stick=Vector2.zero;return Enum.ContextActionResult.Pass end
				stick=state==Enum.UserInputState.End and Vector2.zero or Vector2.new(input.Position.X,input.Position.Y)
				if stick.X*stick.X+stick.Y*stick.Y<0.0225 then stick=Vector2.zero end
				return Enum.ContextActionResult.Sink
			end,false,Enum.ContextActionPriority.High.Value+1,Enum.KeyCode.Thumbstick1)
			status:SetText("Steering "..selection.Name..": WASD / arrows / gamepad; Space to jump. Touch buttons are available.")
		end})
		group:AddSlider("NPCDriveSpeed",{Text="NPC walking speed",Default=16,Min=4,Max=40,Rounding=0,Callback=function(value)
			speed=value;if drive then drive.appliedSpeed=value;drive.hum.WalkSpeed=value end
		end})
		group:AddButton({Text="Return to my character",Func=function() stopAll(true);if not exitTeleport then status:SetText("Returned to your character.") end end})
		travel:AddToggle("NPCExitTeleport",{Text="Move below NPC camera when exiting",Default=false,Callback=function(on) exitTeleport=on end})
		travel:AddButton({Text="Move to ground below camera",Func=function()
			local camera=Workspace.CurrentCamera;local frame=camera and camera.CFrame
			local ok,reason=Hub.teleportBelowCamera(frame)
			if ok then stopAll();notify("Camera travel","Moved to the ground below your camera.",5,"success")
			else notify("Camera travel",tostring(reason),5,"warning") end
		end})
		travel:AddLabel("Requires stable ground within 512 studs, a free character and confirmed Gucci when enabled.")
		Hub.connect(RunService.RenderStepped,function()
			if not view then return end
			if not eligible(view.model,false) or Workspace.CurrentCamera~=view.camera or view.camera.CameraSubject~=view.hum then stopAll();return end
			if drive then
				local hum,root=eligible(drive.model,true)
				if hum~=drive.hum or root~=drive.root then stopAll();status:SetText("NPC steering stopped: character or ownership changed.");return end
				if UserInputService:GetFocusedTextBox() then keys={};stick=Vector2.zero;hum:Move(Vector3.zero,false);return end
				local x=(keys.Right and 1 or 0)-(keys.Left and 1 or 0)+stick.X
				local z=(keys.Back and 1 or 0)-(keys.Forward and 1 or 0)-stick.Y
				local frame=view.camera.CFrame
				local direction=frame.RightVector*x-frame.LookVector*z;direction=Vector3.new(direction.X,0,direction.Z)
				if direction.Magnitude>1 then direction=direction.Unit end
				hum:Move(direction,false)
			end
		end)
		Hub.stopNPCCamera=stopAll
		Hub.connect(Player.CharacterRemoving,stopAll)
		Hub.connect(UserInputService.WindowFocusReleased,function() keys={};stick=Vector2.zero end)
		Hub.cleanup(function() scanEpoch+=1;stopView(false);Hub.stopNPCCamera=nil;Hub.teleportBelowCamera=nil end)
	end)()
end

-- Register every saved control before loading settings.
MenuGroup:AddSlider("StartupFeatureDelay",{Text="Saved-feature startup delay (seconds)",Default=3,Min=0,Max=10,Rounding=1,Callback=function() end})
-- Session customization does not require executor file-storage support.
ThemeManager:ApplyToTab(Tabs.Customization)
Hub.storage = type(isfile)=="function" and type(readfile)=="function" and type(writefile)=="function" and type(isfolder)=="function" and type(makefolder)=="function"
if Hub.storage then
	local ok, err = pcall(function()
		ThemeManager:SetLibrary(Library)
		SaveManager:SetLibrary(Library)
		SaveManager:SetIgnoreIndexes({"MultiWhitelist","CheaterSignalPlayers"})
		Hub.installConfigLoading(SaveManager)
		ThemeManager:SetFolder("ArrivaCoreHub")
		SaveManager:SetFolder("ArrivaCoreHub/Configs")
		SaveManager:BuildConfigSection(Tabs["UI Settings"])
		local success,loadError=SaveManager:Load("AutoSave")
		if success then notify("Config","Your saved settings were loaded.")
		elseif loadError~="No saved configuration" then
			notify("Config warning","Settings could not load. Autosave is paused to protect the existing file. " .. tostring(loadError),10)
		end
	end)
	if not ok then Hub.storage = false; notify("Config", tostring(err)) end
else
	notify("Config", "File storage unavailable. Settings work for this session.")
end
-- External teleports also flush the current values before the client leaves.
if Player.OnTeleport then
	Hub.connect(Player.OnTeleport,function(state)
		if state~=Enum.TeleportState.Started then return end
		local ok,err=Hub.flushSettings()
		if not ok then warn("[Arriva teleport save] "..tostring(err)) end
	end)
end
-- The control values are loaded; enabled callbacks may still be starting.
task.defer(function()
	if not Hub.loadedSafety then Hub.readSafety() end
	if Hub.refreshWhitelistUI then Hub.refreshWhitelistUI() end
	Hub.lastSettings=Hub.captureSettings()
	Hub.ready = true
	Hub.env.ArrivaCoreStarting=nil
	Hub.startupSeconds=os.clock()-Hub.startupBegan
	if not Hub.configLoaded and not Hub.configLoadFailed then Hub.requestSave() end
end)
MenuGroup:AddButton({Text="Startup diagnostics",Func=function()
	local listeners,workers=0,0
	for connection in pairs(Hub.connections) do if connection.Connected then listeners+=1 end end
	for thread in pairs(Hub.threads) do if coroutine.status(thread)~="dead" then workers+=1 end end
	local progress=Hub.restoreProgress
	local message=string.format("UI startup %.2fs, %d listeners, %d tracked workers.",Hub.startupSeconds or 0,listeners,workers)
	if progress then message..=string.format(" Saved callbacks completed: %d/%d, %d failed, %d superseded%s.",progress.completed,progress.total,progress.failed,progress.skipped,progress.done and " (finished)" or " (starting)") end
	if Hub.lastRestoreControl then message..=" Last restored: "..Hub.lastRestoreControl.."." end
	if Hub.lastUIError then message..=" Last callback error: "..Hub.lastUIError:sub(1,180) end
	if Hub.lastCallbackError then message..=" Last event error: "..Hub.lastCallbackError:sub(1,180) end
	if Hub.lastWorkerError then message..=" Last worker error: "..Hub.lastWorkerError:sub(1,180) end
	print("[Arriva startup] "..message);notify("Startup diagnostics",message,10)
end})
MenuGroup:AddButton({Text = "Save status", Func = function()
	local message = "Storage: " .. (Hub.storage and "available" or "unavailable")
		.. " | Last successful save: " .. (Hub.lastSaveAt or "none this session")
	if Hub.lastLoadPath then message ..= " | Loaded: " .. Hub.lastLoadPath end
	if Hub.configLoadFailed then message ..= " | Autosave paused: load failed" end
	if Hub.lastLoadError then message ..= " | Load error: " .. Hub.lastLoadError;warn("[Arriva config load] " .. Hub.lastLoadError) end
	if Hub.lastSaveError then message ..= " | Save error: " .. Hub.lastSaveError end
	if Hub.lastSnapshotError then message ..= " | Snapshot error: " .. Hub.lastSnapshotError end
	notify("Config", message, 8)
end})
MenuGroup:AddButton({Text = "Load Infinite Yield (external)", Func = function()
	task.spawn(function() Hub.fetch("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source") end)
end})
Hub.cleanup(function()
	-- Explicit restoration, since remaining tasks are canceled on unload.
	if Hub.releaseGrabProtection then Hub.releaseGrabProtection() end
	stopNoclip()
	RemoveAllBoxes()
	disconnectWatchers()
	restorePaintParts()
	if Hub.stopBlobFlight then Hub.stopBlobFlight() end
	for _, item in ipairs(waterParts) do
		pcall(function() item.part.CanCollide = item.originalCollide end)
	end
	for obj, props in pairs(oldProperties) do
		pcall(function()
			local instance = obj == "Lighting" and game:GetService("Lighting") or obj
			for prop, value in pairs(props) do instance[prop] = value end
		end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local esp = root and root:FindFirstChild("NameESP")
		if esp then esp:Destroy() end
	end
end)

Hub.connect(Player.CharacterAdded, function(char)
	char:WaitForChild("HumanoidRootPart", 5)
	if not Hub.alive or Player.Character ~= char then return end
	if not Hub.sourceDefense and Toggles.PaintDeleteToggle and Toggles.PaintDeleteToggle.Value then setTouchQuery(false) end
end)

-- Autosave is scheduled after setting changes; no permanent polling loop.




-- Loop own-toy recovery reuses the bounded, nearby-only recovery transaction.
TargetGroup:AddToggle("LoopOwnToyRecovery",{Text="Own toy ownership recovery",Default=false,Callback=function(on)
	local running,_,onCleanup,bindWorker=Hub.beginTargetLoop("LoopOwnToyRecovery",on);Hub.requestSave()
	if not on then return end
	onCleanup(function() if Hub.cancelOwnToyRecovery then Hub.cancelOwnToyRecovery() end end)
	local worker=task.spawn(function()
		while running() do
			if Hub.recoverOwnToyOwnership then Hub.recoverOwnToyOwnership("LoopOwnToyRecovery",running) end
			local deadline=os.clock()+3
			repeat task.wait(0.1) until not running() or os.clock()>=deadline
		end
	end)
	bindWorker(worker)
end})

-- BEGIN LOOP SELECTOR UI
-- Existing callbacks/IDs remain the action implementations and saved enabled state.
do
	(function()
		local choices={
			{"Kill","LoopKillToggle"}, {"Kill all","LoopKillToggleAll"},
			{"Kick (spam grab)","LoopKickToggle"}, {"Blob kick (grab + blob)","LoopKickToggle2"},
			{"Blob kick (dual hand)","DualHandLoopKick"}, {"Fling","PlayerFlingBtn"},
			{"Remove Gucci","DestroyTargetGucci"}, {"Bring selected","LoopBringSelected"}, {"Bring all","BringAllGrab"},
			{"Own toy ownership recovery","LoopOwnToyRecovery"},
			{"Grab Anti Kick","DestroyAntiKickToggle"}, {"Anti Anti Input Lag","AntiAntiInputLag"},
		}
		local names,byName,hidden={},{},{}
		for _,choice in ipairs(choices) do
			if Toggles[choice[2]] then table.insert(names,choice[1]);byName[choice[1]]=choice[2];hidden[choice[2]]=true end
		end
		local selected=names[1]
		local syncing=false
		local picker,master
		local group=Tabs.Target:AddLeftGroupbox("Loop Controls")
		local function restoring() return Hub.configLoading or (Hub.restoreProgress and not Hub.restoreProgress.done) end
		local function stopOthers(keep)
			for _,choice in ipairs(choices) do
				local control=Toggles[choice[2]]
				if control and control.Value and choice[2]~=keep then control:SetValue(false) end
			end
		end
		local function reflect(on)
			if not master or master.Value==on then return end
			syncing=true;master:SetValue(on);syncing=false
		end
		local function apply()
			local id=byName[selected];stopOthers(id)
			local control=id and Toggles[id]
			if control and not control.Value then control:SetValue(true) end
			reflect(control~=nil and control.Value==true)
		end
		picker=group:AddDropdown("TargetLoopType",{Text="Loop type",Values=names,Default=1,Callback=function(value)
			if not byName[value] then return end
			selected=value
			if not syncing and not restoring() and master and master.Value then apply() end
		end})
		-- Enabled state continues to be saved through the legacy backend IDs.
		SaveManager.ignored.TargetLoopEnabled=true
		master=group:AddToggle("TargetLoopEnabled",{Text="Enable loop",Default=false,Callback=function(on)
			if syncing then return end
			if on then apply() else stopOthers(nil) end
		end})
		if Tabs.Target.native then
			for _,entry in ipairs(Tabs.Target.native.entries) do
				if hidden[entry.controlId] then entry.hidden=true;entry.frame.Visible=false end
			end
		end
		-- Reflect commands, emergency stops, target rejection and older saved configs.
		local elapsed=0
		Hub.connect(RunService.Heartbeat,function(dt)
			elapsed+=dt;if elapsed<0.1 or restoring() then return end;elapsed=0
			local active
			for _,choice in ipairs(choices) do
				local control=Toggles[choice[2]]
				if control and control.Value then
					if not active or choice[1]==selected then active=choice end
				end
			end
			if active then
				stopOthers(active[2])
				if selected~=active[1] then syncing=true;picker:SetValue(active[1]);syncing=false end
				reflect(true)
			else reflect(false) end
		end)
	end)()
end
-- END LOOP SELECTOR UI

-- Keep sidebar order fixed; arrange existing rows by purpose after construction.
do
	-- Move existing rows; keep the original handles, callbacks, and saved IDs.
	if Tabs.Sound.native and Tabs.Defense.native then
		for _,key in ipairs({"Visual","Misc","Notifications"}) do
			Tabs[key].native:MoveEntriesTo(Tabs.Sound.native,function(entry)
				if entry.controlId=="LoopNotifySounds" then return "Loop Alert Sounds" end
				if entry.controlId=="PackBlackholeSound" or entry.controlId=="PackBlackholeSoundOn" then return "Blackhole Audio" end
			end)
		end
		Tabs.Defense.native:MoveEntriesTo(Tabs.AntiLag.native,function(entry)
			if entry.controlId=="AntiLagToggle" then return "Manual Line Protection" end
			if entry.controlId=="SourceLowFpsAntiLag" or entry.controlId=="SourceLowFpsThreshold" then return "Low FPS Protection" end
		end)
	end
	local layouts = {
		Player={sections={"Movement","Spawn bookmark","NPC Camera & Control","Flight","Camera","Spectator Camera","Follow Player Position","Character animations","Plot Barriers","Performance"},
			rename={["View & Movement"]="Movement"},
			controls={ThirdPersonToggle="Camera",ToolFirstPerson="Camera",FOVSlider="Camera"},
			order={Movement={"SpeedModifierToggle","SpeedValue","JumpModifierToggle","JumpValue","infJumpToggle","SelfNoclipToggle","ToolGravity","ToolGravityValue","SpinToggle","SpinSpeed"}}},
		Defense={sections={"Protection Toggles","Grab & Seat Settings","Gucci Settings","Anti Kick","Anti Kick Appearance","Recovery Settings","World Hazard Notes","Input Settings","Collision Settings","Safe Zone","Movement Warnings","Advanced & Countermeasures"},

			rename={["Defense Main"]="Grab & Seat Settings",["Extra Defense"]="Advanced & Countermeasures",["Local hazard filters"]="World Hazard Notes"},
			controls={
				PrivatePoisonTouch="Protection Toggles",
				AntiGrabObsidian="Protection Toggles",RecoverMovementAfterGrab="Protection Toggles",AntiBlobmanToggle="Protection Toggles",LocalUnwantedSeatProtection="Protection Toggles",AntiStickyToggle="Protection Toggles",
				AutoGucciBlobToggle="Protection Toggles",AutoGucciTrainToggle="Protection Toggles",GucciAutoDeleteBlob="Gucci Settings",SourceGucciVehicle="Gucci Settings",SourceRagdollOnRemoveGucci="Gucci Settings",
				ShurikenAntiKick="Protection Toggles",SourceBreakPCLD="Protection Toggles",
				AntiVoidToggle="Protection Toggles",SourceDisableVoid="Protection Toggles",LocalMotionProtection="Protection Toggles",LocalMotionLinearLimit="Recovery Settings",LocalMotionAngularLimit="Recovery Settings",LoopTP="Protection Toggles",
				AntiExplosionToggle="Protection Toggles",AntiBurnToggle="Protection Toggles",PaintDeleteToggle="Protection Toggles",SourceAntiBanana="Protection Toggles",SourceAntiSnowball="Protection Toggles",
				AntiInputLag="Protection Toggles",SourceInputToy="Input Settings",SourceInputDelay="Input Settings",SourceInputTransparency="Input Settings",
				SourceAntiObjectFling="Protection Toggles",SourceNoclipBarrier="Protection Toggles",SourceAntiInvis="Protection Toggles",
				MovementWarningMonitor="Movement Warnings",AutoResetToggle="Protection Toggles",SourceCorrectionLeave="Movement Warnings",
			},
			prefixes={{"SourceAntiKick","Anti Kick Appearance"}},
			names={
				["Release local grab freeze"]="Grab & Seat Settings",
				["Anti Sticky removes unwanted sticky connections."]="Grab & Seat Settings",
				["Last person who grabbed you: nobody"]="Grab & Seat Settings",
				["Gucci status: off."]="Gucci Settings",
				["Gucci: off"]="Gucci Settings",
				["Stop Gucci and remove its toy"]="Gucci Settings",
				["Anti Void returns you to safety below the configured height."]="Recovery Settings",
				["Record safe ground here"]="Recovery Settings",["Return to last safe ground"]="Recovery Settings",["Motion recovery status"]="Recovery Settings",
				["Anti Banana breaks character legs; respawn restores missing limbs."]="World Hazard Notes",
				["Movement warning count"]="Movement Warnings",["Clear observed warning count"]="Movement Warnings",
			},
			order={
				["Protection Toggles"]={"AntiGrabObsidian","RecoverMovementAfterGrab","AutoGucciBlobToggle","AutoGucciTrainToggle","AntiBlobmanToggle","ShurikenAntiKick","SourceBreakPCLD","AntiStickyToggle","LocalUnwantedSeatProtection","AntiExplosionToggle","AntiBurnToggle","PaintDeleteToggle","PrivatePoisonTouch","AntiVoidToggle","SourceDisableVoid","LocalMotionProtection","SourceAntiObjectFling","AntiInputLag","SourceAntiBanana","SourceAntiSnowball","SourceNoclipBarrier","SourceAntiInvis","LoopTP","AutoResetToggle"},
				["Grab & Seat Settings"]={"AntiGrabObsidian","RecoverMovementAfterGrab","AntiBlobmanToggle","LocalUnwantedSeatProtection","AntiStickyToggle"},
				["Gucci Settings"]={"AutoGucciBlobToggle","SourceGucciVehicle","GucciAutoDeleteBlob","AutoGucciTrainToggle","SourceRagdollOnRemoveGucci"},
				["Recovery Settings"]={"AntiVoidToggle","SourceDisableVoid","LocalMotionProtection","LocalMotionLinearLimit","LocalMotionAngularLimit","LoopTP"},
			}},
		Target={sections={"Target Interaction","Loop Controls","Aim Assist"},controls={TargetLoopType="Loop Controls",TargetLoopEnabled="Loop Controls"}},
		AntiLag={sections={"Manual Line Protection","Automatic Line Protection","Low FPS Protection","Connection & Client Health","Incoming Payload Monitor","Frame Spike Diagnostics","Runtime diagnostics"}},
		Blob={sections={"Controls","Seating","Flight"},
			controls={AutoReseatBlobLoops="Seating",BlobReseatInterval="Seating",AutoSitZ="Seating",BlobFlySpeed="Flight"}},
		Aura={sections={"Player Auras","Attraction & Tornado","Range & Alerts"}},
		Grab={sections={"Throw & Distance","Grab Modes","Held Object","Line Appearance"},
			rename={["Line Texture & Gradient"]="Line Appearance"}},
		Fun={sections={"My Toys & Groups","Own Toy Builder & Recovery","Creative Object Aura","Shape Toy Picker","Shape Settings","Object Attraction","Group Appearance","Local Decoy Formation"},
			rename={["My Toy Manager and Groups"]="My Toys & Groups"}},
		Visual={sections={"Skybox Faces","Sun & Stars","Shaders","Water Appearance","Local environment","Player ESP","World ESP","Camera and cursor","Camera clipping","Camera Effects","Lighting","Water Controls","Visual Effects","Local appearance extras","Blackhole Appearance"},controls={ToolTimeOverride="Sun & Stars",ToolTimeOfDay="Sun & Stars",ToolSyncTime="Sun & Stars"}},
		Misc={sections={"Cheaters","Travel","Travel Settings","World Utilities","Plots & Slots","Part Tools","Session tools","Camera Travel"},
			rename={Miscellaneous="World Utilities"},controls={TPToggle="Travel",WaterWalkToggle="Travel"}},
		Whitelist={sections={"Protected Players","Whitelist Assistance","Whitelist Shuriken Appearance"}},
		Explosions={sections={"Launch Settings","Missile Throw Status","Explosions Spam","FAQ about Explosions Spam"}},
		KeyBinds={sections={"Menu & emergency","Action shortcuts","Missile throw","Keybind display"}},
		Sound={sections={"Game Sound Filters","Toy Audio","Notification Sounds","Info Notifications","Warning Notifications","Success Notifications","Danger Notifications","Join Notifications","Leave Notifications","Respawn Notifications","Blackhole Notifications","Kick Notifications","Loop Alert Sounds","Blackhole Audio"},
			prefixes={{"NoticeInfo","Info Notifications"},{"NoticeWarning","Warning Notifications"},{"NoticeSuccess","Success Notifications"},{"NoticeDanger","Danger Notifications"},{"NoticeJoin","Join Notifications"},{"NoticeLeave","Leave Notifications"},{"NoticeRespawn","Respawn Notifications"},{"NoticeBlackhole","Blackhole Notifications"},{"NoticeKick","Kick Notifications"}},
			names={["Preview info sound"]="Info Notifications",["Preview warning sound"]="Warning Notifications",["Preview success sound"]="Success Notifications",["Preview danger sound"]="Danger Notifications",
				["Preview join sound"]="Join Notifications",["Preview join alert"]="Join Notifications",
				["Preview leave sound"]="Leave Notifications",["Preview leave alert"]="Leave Notifications",
				["Preview respawn sound"]="Respawn Notifications",["Preview respawn alert"]="Respawn Notifications",
				["Preview blackhole sound"]="Blackhole Notifications",["Preview blackhole alert"]="Blackhole Notifications",
				["Preview kick sound"]="Kick Notifications",["Preview kick alert"]="Kick Notifications"}},
		Notifications={sections={"Player Events","Target Alerts","Loop & Blobman Alerts","Notification theme","Event messages","Notification history","Position & Appearance"}},
		Customization={sections={"Hub Theme","Appearance","Custom Theme Colors","On-screen FPS & Ping","Anchor Appearance","Touch Action Buttons","Session overlay"}},
		["UI Settings"]={sections={"Menu","Saved settings","Config profiles"}},
	}
	for key,layout in pairs(layouts) do
		local tab=Tabs[key]
		if tab and tab.native then tab.native:Organize(layout) end
	end
end


(function()
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	local commandOutput
	local commandLog={}
	local function message(text,kind)
		table.insert(commandLog,(kind=="warning" and "Warning: " or "")..tostring(text))
		if #commandLog>10 then table.remove(commandLog,1) end
		if commandOutput then commandOutput:SetText(table.concat(commandLog,"\n\n")) end
	end

	local function trim(text)
		return tostring(text or ""):match("^%s*(.-)%s*$")
	end

	local function control(id)
		return Toggles[id] or Options[id]
	end

	local function set(id, value)
		local option = control(id)
		if not option or type(option.SetValue) ~= "function" then
			error("Control unavailable: "..id, 0)
		end
		option:SetValue(value)
		return option
	end

	local function resolve(query)
		query = trim(query)
		if query == "" then
			return nil, "Type a display name or username."
		end

		if query:sub(1, 1) == '"' and query:sub(-1) == '"' then
			query = query:sub(2, -2)
		end

		local usernameOnly = query:sub(1, 1) == "@"
		query = (usernameOnly and query:sub(2) or query):lower()

		if query == "" then
			return nil, "Type a name after @."
		end

		local rules = usernameOnly
			and {{"Name", true}, {"Name", false}}
			or {
				{"DisplayName", true},
				{"DisplayName", false},
				{"Name", true},
				{"Name", false},
			}

		for _, rule in ipairs(rules) do
			local matches = {}

			for _, person in ipairs(Players:GetPlayers()) do
				if person ~= player then
					local name = tostring(person[rule[1]] or person.Name):lower()
					local matched = (rule[2] and name == query)
						or (not rule[2] and name:find(query, 1, true))

					if matched then
						table.insert(matches, person)
					end
				end
			end

			if #matches == 1 then
				return matches[1]
			elseif #matches > 1 then
				table.sort(matches, function(a, b)
					return a.Name:lower() < b.Name:lower()
				end)

				local names = {}
				for i = 1, math.min(#matches, 5) do
					names[i] = "@"..matches[i].Name
				end

				return nil, "Multiple matches: "..table.concat(names, ", ")
					..". Type more, or use @username."
			end
		end

		return nil, "No other player matched that name."
	end

	local function target(query)
		local person, reason = resolve(query)
		if not person then error(reason, 0) end
		return person
	end

	local function selection(person, mode)
		local option = Options.KickPlayerDropdown
		if not option then error("Player selector unavailable.", 0) end

		if Hub.refreshTargetSelector then
			Hub.refreshTargetSelector()
		end

		local label
		for _, value in ipairs(option.Values or {}) do
			if value:match("%(([^()]*)%)$") == person.Name then
				label = value
				break
			end
		end

		if not label then
			error("Player selector is still loading. Try again.", 0)
		end

		local values = {}
		if mode ~= "select" then
			for key, value in pairs(
				type(option.Value) == "table" and option.Value or {}
				) do
				if type(key) == "number" then
					values[value] = true
				elseif value then
					values[key] = true
				end
			end
		end

		if mode == "remove" then
			values[label] = nil
		else
			values[label] = true
		end

		option:SetValue(values)

		message(
			(mode == "remove" and "Removed @" or "Selected @")
				..person.Name..". Action toggles were not enabled.",
			"success"
		)
	end

	local function booleanArgument(argument, current)
		argument = trim(argument):lower()
		if argument == "" then return not current end
		if argument == "on" then return true end
		if argument == "off" then return false end
		error("Use on/off, or leave it blank to toggle.", 0)
	end

	local function canMove()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local held = player:FindFirstChild("IsHeld")

		if not root or not hum or hum.Health <= 0 then
			error("Your character is not ready.", 0)
		end

		if hum.SeatPart or root.Anchored
			or (held and held.Value) or Hub.safeZoneLoopActive then
			error("Leave your seat or hold, and stop safe-zone looping first.", 0)
		end

		for _, run in pairs(Hub.targetLoopRuns or {}) do
			if run.enabled then
				error("Stop your action loops before moving with a command.", 0)
			end
		end

		return root, hum
	end

	local commands = {}

	commands.protect = function(argument)
		local person=target(argument)
		local id=tostring(person.UserId)
		Hub.manualWhitelist[id]=person.DisplayName.." (@"..person.Name..") ["..id.."]"
		Hub.manualWhitelist["name:"..person.Name:lower()]=nil
		-- Apply protection synchronously, before UI refreshes or disk saves.
		Hub.reconcileProtection()
		if Hub.refreshWhitelistUI then Hub.refreshWhitelistUI() end
		Hub.queueSafetySave();Hub.requestSave()
		message("Protected @"..person.Name..". Added to your whitelist.","success")
	end

	commands.select = function(argument)
		selection(target(argument), "select")
	end

	commands.add = function(argument)
		selection(target(argument), "add")
	end

	commands.remove = function(argument)
		selection(target(argument), "remove")
	end

	commands.clear = function()
		set("KickPlayerDropdown", {})
		message("Player selection cleared. Action toggles are unchanged.", "success")
	end

	commands.fly = function(argument)
		local option = control("PackCharacterFlight")
		if not option then error("Player flight unavailable.", 0) end

		local on = booleanArgument(argument, option.Value)
		if on then canMove() end

		set("PackCharacterFlight", on)
		message(
			on and "Player flight enabled." or "Player flight disabled.",
			"success"
		)
	end

	commands.unfly = function()
		commands.fly("off")
	end

	commands.flyspeed = function(argument)
		local speed = tonumber(trim(argument))
		if not speed or speed ~= speed or speed < 5 or speed > 1000 then
			error("Usage: !flyspeed 5–1000", 0)
		end

		set("PackCharacterFlightSpeed", speed)
		message(
			"Flight speed set to "..tostring(speed)
				..". This does not turn flight on.",
			"success"
		)
	end

	commands.to = function(argument)
		local person = target(argument)
		local root = canMove()

		if Hub.characterFlightActive or Hub.blobFlightActive then
			error("Stop player/vehicle flight before teleporting.", 0)
		end

		local character = person.Character
		local other = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")

		if not other or not hum or hum.Health <= 0 then
			error("That player's character is not ready.", 0)
		end

		local forward = Vector3.new(
			other.CFrame.LookVector.X, 0, other.CFrame.LookVector.Z
		)
		forward = forward.Magnitude > 0.001
			and forward.Unit or Vector3.new(0, 0, -1)

		local position = other.Position + forward * 4

		for _, value in ipairs({position.X, position.Y, position.Z}) do
			if value ~= value or math.abs(value) == math.huge then
				error("Invalid target position.", 0)
			end
		end

		if position.Y <= workspace.FallenPartsDestroyHeight + 8 then
			error("Destination is below the safe map height.", 0)
		end

		Hub.teleportPart(root, CFrame.lookAt(
			position,
			Vector3.new(other.Position.X, position.Y, other.Position.Z)
		))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		message("Teleported four studs in front of @"..person.Name..".", "success")
	end

	commands.view = function(argument)
		local person = target(argument)
		local option = Options.LocalSpectatorPlayer
		if not option then error("Spectator control unavailable.", 0) end

		local names = {}
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then table.insert(names, other.Name) end
		end

		table.sort(names)
		option:SetValues(names)
		option:SetValue(person.Name)
		set("LocalSpectatorEnabled", true)

		message("Viewing @"..person.Name.." (camera only).", "success")
	end

	commands.unview = function()
		set("LocalSpectatorEnabled", false)
		message("Spectator camera disabled.", "success")
	end

	commands.menu = function(argument)
		local visible = Hub.menuVisible ~= false
		local wanted = booleanArgument(argument, visible)
		if wanted == visible then return end

		-- Reuse your existing menu toggle, including its sound/notification.
		local picker = Library.ToggleKeybind
		local callback = picker and picker.handle
			and picker.handle.info and picker.handle.info.Callback

		if type(callback) ~= "function" then
			error("Menu callback unavailable in this version.", 0)
		end

		callback(false)
	end

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

	local commandCatalog={
		{"cmds","!cmds","Open this commands panel."},
		{"help","!help","Open this commands panel."},
		{"protect","!protect name","Immediately add a player to the whitelist. Use @username for exact username matching."},
		{"unprotect","!unprotect name","Remove a manual whitelist entry. Friend protection can still apply."},
		{"whitelist","!whitelist","List manually protected players."},
		{"gucci","!gucci on / off / restart","Start Gucci after leg removal, disable it, or request a clean restart."},
		{"status","!status","Show Gucci, protection setup, config restore and active-loop status."},
		{"protection","!protection name on / off","Change a protection by its control ID or matching label."},
		{"protections","!protections","List enabled protection toggles and their IDs."},
		{"stop","!stop","Stop action loops, NPC control, recovery and flight; keep protection choices."},
		{"select","!select name","Replace the player selection."},
		{"add","!add name","Add a selected player."},
		{"remove","!remove name","Remove a selected player."},
		{"clear","!clear","Clear the player selection."},
		{"to","!to name","Teleport near a player when your character is free."},
		{"fly","!fly on / off","Toggle character flight."},
		{"unfly","!unfly","Disable character flight."},
		{"flyspeed","!flyspeed 5–1000","Set character flight speed."},
		{"view","!view name","Spectate a player."},
		{"unview","!unview","Restore your camera."},
		{"menu","!menu on / off","Show or hide the hub menu."},
		{"save","!save","Explicitly save settings."},
		{"load","!load","Load AutoSave. Gucci waits only for Anti Banana leg removal."},
		{"camhere","!camhere","Move to stable ground below the camera."},
		{"npcreturn","!npcreturn","Exit NPC viewing and steering."},
		{"recoverbuild","!recoverbuild","Recover missing nearby ownership for your selected own-toy group."},
	}
	local function openCommands()
		if Tabs.Commands.native and Tabs.Commands.native.Show then Tabs.Commands.native:Show() end
	end
	commands.cmds=openCommands
	commands.help=openCommands
	commands.unprotect=function(argument)
		local person=target(argument)
		Hub.manualWhitelist[tostring(person.UserId)]=nil
		Hub.manualWhitelist["name:"..person.Name:lower()]=nil
		if Hub.refreshWhitelistUI then Hub.refreshWhitelistUI() end
		Hub.queueSafetySave();Hub.requestSave()
		message("Removed @"..person.Name.." from the manual whitelist."..(Hub.isProtected(person) and " Friend protection still applies." or ""),"success")
	end
	commands.whitelist=function()
		local names={};for _,label in pairs(Hub.manualWhitelist) do table.insert(names,tostring(label)) end
		table.sort(names);message(#names>0 and table.concat(names,"\n") or "Your manual whitelist is empty.")
	end
	commands.gucci=function(argument)
		local wanted=trim(argument):lower()
		if wanted=="restart" then set("AutoGucciBlobToggle",false);set("AutoGucciBlobToggle",true)
		else set("AutoGucciBlobToggle",booleanArgument(argument,control("AutoGucciBlobToggle").Value)) end
		message("Gucci: "..tostring(Hub.gucciStage or "off")..". "..(Hub.gucciWaitingReason or ""))
	end
	commands.status=function()
		local progress=Hub.restoreProgress;local pending,loops=0,0
		for _ in pairs(Hub.protectionStartupJobs) do pending+=1 end
		for _,run in pairs(Hub.targetLoopRuns or {}) do if run.enabled then loops+=1 end end
		message(string.format("Gucci: %s\nProtection setup jobs: %d | Active action loops: %d\nSettings restore: %s | Storage: %s%s",
			tostring(Hub.gucciStage or "off")..(Hub.gucciLastInterruption and " | Last interruption: "..Hub.gucciLastInterruption or ""),pending,loops,progress and (progress.completed.."/"..progress.total) or "none",
			Hub.storage and "available" or "unavailable",(Hub.gucciWaitingReason and ("\n"..Hub.gucciWaitingReason) or "")
				..(Hub.gucciVerificationReason and ("\nVerification: "..Hub.gucciVerificationReason) or "")
				.."\nAnti Kick: "..tostring(Hub.antiKickStage or "Disabled")
				..(Hub.lastAntiKickError and ("\nLast Anti Kick error: "..Hub.lastAntiKickError) or "")))
	end
	commands.protections=function()
		local lines={}
		for id,c in pairs(Library.controls) do
			if c.Tab==Tabs.Defense.native and c.Type=="Toggle" and c.Value then table.insert(lines,c.Text.." ["..id.."]") end
		end
		table.sort(lines);message(#lines>0 and table.concat(lines,"\n") or "No protection toggles enabled.")
	end
	commands.protection=function(argument)
		local query,state=trim(argument):match("^(.-)%s+(%S+)$")
		if not query or (state:lower()~="on" and state:lower()~="off") then error("Usage: !protection name on/off",0) end
		local matches={};query=trim(query):lower()
		for id,c in pairs(Library.controls) do
			if c.Tab==Tabs.Defense.native and c.Type=="Toggle" then
				if id:lower()==query or c.Text:lower()==query then matches={c};break end
				if c.Text:lower():find(query,1,true) then table.insert(matches,c) end
			end
		end
		if #matches~=1 then error(#matches==0 and "No protection matched. Use !protections for enabled IDs." or "Several protections matched; use the exact control ID.",0) end
		local chosen=matches[1];chosen:SetValue(state:lower()=="on")
		message(chosen.Text..": "..state:lower()..".","success")
	end
	commands.stop=function()
		for id,run in pairs(Hub.targetLoopRuns or {}) do
			if run.enabled and Toggles[id] then Toggles[id]:SetValue(false) end
		end
		for _,id in ipairs({"PackCharacterFlight","SelfFollowEnabled"}) do if Toggles[id] and Toggles[id].Value then Toggles[id]:SetValue(false) end end
		if Hub.stopBlobFlight then Hub.stopBlobFlight() end
		if Hub.stopNPCCamera then Hub.stopNPCCamera() end
		if Hub.cancelOwnToyRecovery then Hub.cancelOwnToyRecovery() end
		message("Action loops, NPC control, recovery, follow and flight stopped. Protection choices kept.","success")
	end
	commands.load=function()
		if not Hub.ready or not Hub.storage then error("Settings storage is unavailable or startup is incomplete.",0) end
		local ok,reason=SaveManager:Load("AutoSave");if not ok then error(tostring(reason),0) end
		message("Settings loaded. Gucci waits only for Anti Banana leg removal.","success")
	end
	commands.camhere=function()
		local ok,reason=Hub.teleportBelowCamera()
		if not ok then error(tostring(reason),0) end
		if Hub.stopNPCCamera then Hub.stopNPCCamera() end
		message("Moved to stable ground below the camera.","success")
	end
	commands.npcreturn=function()
		if Hub.stopNPCCamera then Hub.stopNPCCamera(true) end
		message("Returned to your character.","success")
	end
	commands.recoverbuild=function()
		if Hub.recoverOwnToyOwnership then Hub.recoverOwnToyOwnership() end
		message("See Own Toy Builder & Recovery for ownership status.")
	end
	local commandGroup=Tabs.Commands:AddLeftGroupbox("Command browser")
	local runGroup=Tabs.Commands:AddRightGroupbox("Run a command")
	local description=commandGroup:AddLabel("Use ! in chat, or run commands here. Player matching accepts display names and @usernames.")
	commandOutput=runGroup:AddLabel("Command output appears here.")
	local picker,commandInput
	local lookup={}
	for _,id in ipairs({"CommandSearch","CommandPicker","CommandLine"}) do SaveManager.ignored[id]=true end
	local function filterCommands(query)
		query=tostring(query or ""):lower();local names={};lookup={}
		for _,entry in ipairs(commandCatalog) do
			if (entry[2].." "..entry[3]):lower():find(query,1,true) then table.insert(names,entry[2]);lookup[entry[2]]=entry end
		end
		if picker then picker:SetValues(names) end
		return names
	end
	commandGroup:AddInput("CommandSearch",{Text="Search commands",Default="",Finished=false,Callback=filterCommands})
	picker=commandGroup:AddDropdown("CommandPicker",{Text="Command",Values=filterCommands(""),Callback=function(value)
		local entry=lookup[value]
		if entry then description:SetText(entry[2].." — "..entry[3]);if commandInput then commandInput:SetValue(entry[2]) end end
	end})
	local line=""
	commandInput=runGroup:AddInput("CommandLine",{Text="Command text",Default="",Placeholder="!protect @username",Finished=true,Callback=function(value) line=tostring(value or "") end})
	local function execute(text)
		local name,argument=tostring(text):match("^%s*!(%S+)%s*(.-)%s*$")
		if not name then message("Start commands with !. Open !cmds for examples.","warning");return end
		local callback=commands[name:lower()]
		if not callback then message("Unknown command: !"..name..". Use !cmds.","warning");return end
		local ok,reason=pcall(callback,argument)
		if not ok then message(tostring(reason),"warning") end
	end
	runGroup:AddButton({Text="Run command",Func=function() execute(line) end})
	runGroup:AddButton({Text="Show status",Func=commands.status})
	runGroup:AddButton({Text="Clear command output",Func=function() table.clear(commandLog);commandOutput:SetText("Command output appears here.") end})
	Hub.openCommands=openCommands
	Hub.executeCommand=execute
	Hub.cleanup(function() Hub.openCommands=nil;Hub.executeCommand=nil end)

	local lastText, lastTime

	if Hub.chatCommandConnection then
		Hub.chatCommandConnection:Disconnect()
		Hub.connections[Hub.chatCommandConnection] = nil
	end

	local connection = Hub.connect(player.Chatted, function(text)
		if not Hub.alive then return end

		if not tostring(text):match("^%s*!") then return end

		local now = os.clock()
		if text == lastText and lastTime and now - lastTime < 0.25 then
			return
		end

		lastText, lastTime = text, now

		execute(text)
	end)

	Hub.chatCommandConnection = connection

	Hub.cleanup(function()
		connection:Disconnect()
		Hub.connections[connection] = nil
		if Hub.chatCommandConnection == connection then
			Hub.chatCommandConnection = nil
		end
	end)
end)()

-- Send loaded message

notify("Arriva Core Hub 2.5", "Controls ready. Gucci waits only for leg removal when Anti Banana is enabled.", 5)