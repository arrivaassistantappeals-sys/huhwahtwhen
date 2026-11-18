-- Meowixa local graphics for Obsidian.
-- From a LocalScript, call require(path.To.Meowixa)(Obsidian).
-- Pass your existing Obsidian visual tab as the second argument to reuse it.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

return function(Obsidian, visualTab)
	assert(RunService:IsClient(), "Meowixa graphics must be mounted on the client")
	if not visualTab then
		local window = Obsidian:CreateWindow({ Title = "Meowixa", Footer = "Local graphics" })
		visualTab = window:AddTab("Visual", "image")
	end

	local options = Obsidian.Options
	local shaderGroup = visualTab:AddLeftGroupbox("Shaders")
	local particleGroup = visualTab:AddLeftGroupbox("Particles")
	local cloudGroup = visualTab:AddLeftGroupbox("Clouds")
	local skyGroup = visualTab:AddRightGroupbox("Skybox")
	local sunGroup = visualTab:AddRightGroupbox("Sun & Stars")
	local waterGroup = visualTab:AddRightGroupbox("Water Appearance")
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local active = true
	local connections = {}

	local function connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end

	local function createEffect(className)
		local effect = Instance.new(className)
		effect.Parent = Lighting
		return effect
	end

	local function notify(title, message)
		Obsidian:Notify({ Title = title, Description = message, Time = 4 })
	end

	local shaderEffects, sky, clouds
	local shadersEnabled, skyboxEnabled, waterEnabled = false, false, false
	local saturation, brightness, bloom = 0.15, 0, 0.3
	local contrast, tint = 0.05, Color3.new(1, 1, 1)
	local bloomSize, bloomThreshold = 24, 1.5
	local sunRaysEnabled, raysIntensity, raysSpread = false, 0.05, 0.8
	local depthOfFieldEnabled, focusDistance, focusRadius, nearBlur, farBlur = false, 40, 35, 0.05, 0.15
	local fallbackSkyImage = "rbxassetid://159454299"
	local skyboxFaces = {}
	local stars, celestial, sunSize, moonSize = 3000, true, 21, 11
	local sunImage, moonImage = "", ""
	local rotation = { 0, 0, 0 }
	local water = { WaterWaveSize = 0.15, WaterWaveSpeed = 10, WaterTransparency = 0.3, WaterReflectance = 0.5 }
	local originalWaterSettings
	local originalSkyParents = {}
	local function destroyInstance(instance)
		if instance then
			instance:Destroy()
		end
	end
	local function parseAssetId(value)
		local text = tostring(value or ""):match("^%s*(.-)%s*$")
		if text == "" then
			return ""
		end
		local id = text:match("^(%d+)$")
			or text:match("^rbxassetid://(%d+)$")
			or text:match("[?&]id=(%d+)")
			or text:match("roblox.com/store/asset/(%d+)")
			or text:match("roblox.com/library/(%d+)")
		if id and tonumber(id) > 0 then
			return "rbxassetid://" .. id
		end
	end
	local function parseHexColor(value)
		local hex = tostring(value or ""):gsub("#", "")
		if hex:match("^%x%x%x%x%x%x$") then
			return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
		end
	end
	local function clearShader()
		if shaderEffects then
			for _, effect in pairs(shaderEffects) do
				destroyInstance(effect)
			end
			shaderEffects = nil
		end
	end
	local function updateShader()
		if not shadersEnabled then
			clearShader()
			return
		end
		if shaderEffects and (not shaderEffects.colorCorrection.Parent or not shaderEffects.bloomEffect.Parent) then
			clearShader()
		end
		if not shaderEffects then
			shaderEffects = {}
			for key, class in pairs({
				colorCorrection = "ColorCorrectionEffect",
				bloomEffect = "BloomEffect",
				sunRays = "SunRaysEffect",
				depthOfField = "DepthOfFieldEffect",
			}) do
				shaderEffects[key] = createEffect(class)
				shaderEffects[key].Name = "ArrivaLocal_" .. key
			end
		end
		shaderEffects.colorCorrection.Saturation = saturation
		shaderEffects.colorCorrection.Brightness = brightness
		shaderEffects.colorCorrection.Contrast = contrast
		shaderEffects.colorCorrection.TintColor = tint
		shaderEffects.bloomEffect.Intensity = bloom
		shaderEffects.bloomEffect.Size = bloomSize
		shaderEffects.bloomEffect.Threshold = bloomThreshold
		shaderEffects.sunRays.Enabled = sunRaysEnabled
		shaderEffects.sunRays.Intensity = raysIntensity
		shaderEffects.sunRays.Spread = raysSpread
		shaderEffects.depthOfField.Enabled = depthOfFieldEnabled
		shaderEffects.depthOfField.FocusDistance = focusDistance
		shaderEffects.depthOfField.InFocusRadius = focusRadius
		shaderEffects.depthOfField.NearIntensity = nearBlur
		shaderEffects.depthOfField.FarIntensity = farBlur
	end

	shaderGroup:AddToggle("PrivateShader", {
		Text = "Local shaders",
		Default = false,
		Callback = function(on)
			shadersEnabled = on
			updateShader()
		end,
	})
	local function slider(target, id, label, default, min, max, rounding, callback)
		target:AddSlider(
			id,
			{ Text = label, Default = default, Min = min, Max = max, Rounding = rounding, Callback = callback }
		)
	end
	slider(shaderGroup, "PrivateSaturation", "Saturation", 0.15, -1, 1, 2, function(value)
		saturation = value
		updateShader()
	end)
	slider(shaderGroup, "PrivateBrightness", "Brightness", 0, -0.3, 0.3, 2, function(value)
		brightness = value
		updateShader()
	end)
	slider(shaderGroup, "PrivateBloom", "Bloom intensity", 0.3, 0, 2, 2, function(value)
		bloom = value
		updateShader()
	end)
	slider(shaderGroup, "PrettyContrast", "Contrast", 0.05, -1, 1, 2, function(value)
		contrast = value
		updateShader()
	end)
	shaderGroup:AddInput("PrettyShaderTint", {
		Text = "Tint HEX",
		Default = "FFFFFF",
		Finished = true,
		Callback = function(value)
			local colorValue = parseHexColor(value)
			if colorValue then
				tint = colorValue
				updateShader()
			else
				notify("Shader warning", "Use a six-digit HEX color.", 4, "warning")
			end
		end,
	})
	slider(shaderGroup, "PrettyBloomSize", "Bloom size", 24, 0, 56, 0, function(value)
		bloomSize = value
		updateShader()
	end)
	slider(shaderGroup, "PrettyBloomThreshold", "Bloom threshold", 1.5, 0, 4, 2, function(value)
		bloomThreshold = value
		updateShader()
	end)
	shaderGroup:AddToggle("PrettySunRays", {
		Text = "Sun rays",
		Default = false,
		Callback = function(on)
			sunRaysEnabled = on
			updateShader()
		end,
	})
	slider(shaderGroup, "PrettyRaysIntensity", "Sun ray intensity", 0.05, 0, 0.3, 2, function(value)
		raysIntensity = value
		updateShader()
	end)
	slider(shaderGroup, "PrettyRaysSpread", "Sun ray spread", 0.8, 0, 1, 2, function(value)
		raysSpread = value
		updateShader()
	end)
	shaderGroup:AddToggle("PrettyDepthOfField", {
		Text = "Depth of field",
		Default = false,
		Callback = function(on)
			depthOfFieldEnabled = on
			updateShader()
		end,
	})
	slider(shaderGroup, "PrettyFocusDistance", "Focus distance", 40, 0, 500, 0, function(value)
		focusDistance = value
		updateShader()
	end)
	slider(shaderGroup, "PrettyFocusRadius", "In-focus radius", 35, 0, 200, 0, function(value)
		focusRadius = value
		updateShader()
	end)
	slider(shaderGroup, "PrettyNearBlur", "Near blur", 0.05, 0, 0.5, 2, function(value)
		nearBlur = value
		updateShader()
	end)
	slider(shaderGroup, "PrettyFarBlur", "Far blur", 0.15, 0, 0.5, 2, function(value)
		farBlur = value
		updateShader()
	end)
	shaderGroup:AddDropdown("PrettyShaderPreset", {
		Text = "Apply shader preset",
		Values = { "Custom", "Soft", "Cinematic", "Warm Sunset", "Cool Night" },
		Default = 1,
		Callback = function(name)
			local presets = {
				Soft = { 0.08, 0.02, 0.03, 0.2, "FFF8F0" },
				Cinematic = { 0.12, 0, 0.18, 0.35, "FFFFFF" },
				["Warm Sunset"] = { 0.2, 0.03, 0.1, 0.45, "FFE4CB" },
				["Cool Night"] = { -0.1, -0.04, 0.12, 0.2, "D6E5FF" },
			}
			local preset = presets[name]
			if not preset then
				return
			end
			for i, id in ipairs({
				"PrivateSaturation",
				"PrivateBrightness",
				"PrettyContrast",
				"PrivateBloom",
				"PrettyShaderTint",
			}) do
				options[id]:SetValue(preset[i])
			end
			options.PrettyShaderPreset:SetValue("Custom")
		end,
	})
	shaderGroup:AddLabel("Enable Local shaders to apply these effects. Sun rays and depth of field are optional.")
	local particleSettings = {
		Enabled = false,
		BoxSize = 500,
		Texture = "rbxassetid://242109931",
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0,
		ParticleSize = 1,
		Count = 2500,
		SpeedMin = 0.5,
		SpeedMax = 2,
		LifeTime = 10,
	}

	local particleTextures = {
		["Circles"] = "rbxassetid://242109931",
		["Snowflakes"] = "rbxassetid://14443362047",
		["Paws"] = "rbxassetid://11382080197",
		["Moons"] = "rbxassetid://8498174594",
		["Lights"] = "rbxassetid://252246910",
	}
	local customParticleTexture

	-- invisible anchored box that follows the camera
	local particleHolder = Instance.new("Part")
	particleHolder.Name = "ParticleHolder"
	particleHolder.Transparency = 1
	particleHolder.CanCollide = false
	particleHolder.CanQuery = false
	particleHolder.CanTouch = false
	particleHolder.Anchored = true
	particleHolder.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.LightEmission = 0
	emitter.LightInfluence = 0
	emitter.ZOffset = 0
	emitter.Parent = particleHolder

	local function updateParticles(key)
		local all = not key
		if all or key == "BoxSize" then
			particleHolder.Size = Vector3.one * particleSettings.BoxSize
		end
		if all or key == "Texture" then
			emitter.Texture = particleSettings.Texture
		end
		if all or key == "Count" then
			emitter.Rate = particleSettings.Count
		end
		if all or key == "LifeTime" then
			emitter.Lifetime = NumberRange.new(particleSettings.LifeTime)
		end
		if all or key == "SpeedMin" or key == "SpeedMax" then
			emitter.Speed = NumberRange.new(
				math.min(particleSettings.SpeedMin, particleSettings.SpeedMax),
				particleSettings.SpeedMax
			)
		end
		if all or key == "Color" then
			emitter.Color = ColorSequence.new(particleSettings.Color)
		end
		if all or key == "ParticleSize" then
			local s = particleSettings.ParticleSize
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.1, s),
				NumberSequenceKeypoint.new(0.9, s),
				NumberSequenceKeypoint.new(1, 0),
			})
		end
		if all or key == "Transparency" then
			emitter.Transparency = NumberSequence.new(particleSettings.Transparency)
		end
	end

	local function setParticle(key, value)
		particleSettings[key] = value
		if particleSettings.Enabled then
			updateParticles(key)
		end
	end

	local cameraFollowConnection
	local function setParticlesEnabled(on)
		particleSettings.Enabled = on
		if cameraFollowConnection then
			cameraFollowConnection:Disconnect()
			cameraFollowConnection = nil
		end

		if on then
			updateParticles()
			local cam = workspace.CurrentCamera
			if cam then
				particleHolder.CFrame = cam.CFrame
			end
			cameraFollowConnection = RunService.RenderStepped:Connect(function()
				local colorValue = workspace.CurrentCamera
				if colorValue then
					particleHolder.CFrame = colorValue.CFrame
				end
			end)
			emitter.Enabled = true
		else
			emitter.Enabled = false
			emitter:Clear()
		end
	end

	-- UI
	particleGroup:AddToggle("ParticlesToggle", {
		Text = "Particles",
		Default = false,
		Callback = function(on)
			setParticlesEnabled(on)
		end,
	})

	particleGroup:AddInput("ParticlesColor", {
		Text = "Particle HEX",
		Default = "FFFFFF",
		Finished = true,
		Callback = function(value)
			local colorValue = parseHexColor(value)
			if colorValue then
				setParticle("Color", colorValue)
			else
				notify("Particle warning", "Use a six-digit HEX color.")
			end
		end,
	})

	local textureDropdown = particleGroup:AddDropdown("ParticlesTexture", {
		Values = { "Circles", "Snowflakes", "Paws", "Moons", "Lights", "Custom" },
		Default = "Circles",
		Multi = false,
		Text = "Particle texture",
		Callback = function(choice)
			if choice == "Custom" then
				setParticle("Texture", customParticleTexture or particleTextures.Circles)
			elseif particleTextures[choice] then
				setParticle("Texture", particleTextures[choice])
			end
		end,
	})

	particleGroup:AddInput("ParticlesCustomTexture", {
		Text = "Custom image ID",
		Default = "",
		Placeholder = "rbxassetid or number",
		ClearTextOnFocus = false,
		Finished = true,
		Callback = function(text)
			local id = tostring(text or ""):match("%d+")
			customParticleTexture = id and ("rbxassetid://" .. id) or nil
			if textureDropdown and textureDropdown.Value == "Custom" then
				setParticle("Texture", customParticleTexture or particleTextures.Circles)
			end
		end,
	})

	particleGroup:AddSlider("ParticlesDensity", {
		Text = "Density",
		Default = 2500,
		Min = 100,
		Max = 5000,
		Rounding = 0,
		Compact = true,
		Callback = function(value)
			setParticle("Count", value)
		end,
	})
	particleGroup:AddSlider("ParticlesSize", {
		Text = "Size",
		Default = 1,
		Min = 0.1,
		Max = 5,
		Rounding = 1,
		Compact = true,
		Callback = function(value)
			setParticle("ParticleSize", value)
		end,
	})
	particleGroup:AddSlider("ParticlesSpeed", {
		Text = "Max speed",
		Default = 2,
		Min = 0,
		Max = 10,
		Rounding = 1,
		Compact = true,
		Callback = function(value)
			setParticle("SpeedMax", value)
		end,
	})
	particleGroup:AddSlider("ParticlesBox", {
		Text = "Box size",
		Default = 500,
		Min = 50,
		Max = 2000,
		Rounding = 0,
		Compact = true,
		Callback = function(value)
			setParticle("BoxSize", value)
		end,
	})
	local function updateSky()
		if skyboxEnabled then
			for _, child in ipairs(Lighting:GetChildren()) do
				if child:IsA("Sky") and child ~= sky then
					originalSkyParents[child] = Lighting
					child.Parent = nil
				end
			end
			if not sky or sky.Parent ~= Lighting then
				destroyInstance(sky)
				sky = Instance.new("Sky")
				sky.Name = "ArrivaLocalSky"
				sky.Parent = Lighting
			end
			for _, property in ipairs({ "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }) do
				sky[property] = skyboxFaces[property] or fallbackSkyImage
			end
			sky.StarCount = stars
			sky.CelestialBodiesShown = celestial
			sky.SunAngularSize = sunSize
			sky.MoonAngularSize = moonSize
			sky.SunTextureId = sunImage ~= "" and sunImage or "rbxasset://sky/sun.jpg"
			sky.MoonTextureId = moonImage ~= "" and moonImage or "rbxasset://sky/moon.jpg"
			pcall(function()
				sky.SkyboxOrientation = Vector3.new(rotation[1], rotation[2], rotation[3])
			end)
		else
			destroyInstance(sky)
			sky = nil
			for child, parent in pairs(originalSkyParents) do
				pcall(function()
					if child.Parent == nil then
						child.Parent = parent
					end
				end)
				originalSkyParents[child] = nil
			end
		end
	end
	local function imageInput(target, id, label, default, set)
		target:AddInput(id, {
			Text = label,
			Default = default,
			Finished = true,
			Callback = function(value)
				local resolved = parseAssetId(value)
				if resolved ~= nil then
					set(resolved)
					updateSky()
				else
					notify("Sky image warning", "Use a Roblox image ID or asset link.", 4, "warning")
				end
			end,
		})
	end
	skyGroup:AddToggle("PrivateSkyEnabled", {
		Text = "Custom skybox and stars",
		Default = false,
		Callback = function(on)
			skyboxEnabled = on
			updateSky()
		end,
	})
	imageInput(skyGroup, "PrivateSkyImage", "Fallback image for all faces", "159454299", function(value)
		if value ~= "" then
			fallbackSkyImage = value
		end
	end)
	for _, entry in ipairs({
		{ "Up", "Up / top" },
		{ "Dn", "Down / bottom" },
		{ "Lf", "Left" },
		{ "Rt", "Right" },
		{ "Ft", "Forward / front" },
		{ "Bk", "Backward / back" },
	}) do
		local property = "Skybox" .. entry[1]
		imageInput(skyGroup, "Pretty" .. property, entry[2] .. " image ID", "", function(value)
			skyboxFaces[property] = value ~= "" and value or nil
		end)
	end
	skyGroup:AddLabel("Blank faces use the fallback image. Use six matching images for a seamless skybox.")
	for i, label in ipairs({ "Sky pitch", "Sky yaw", "Sky roll" }) do
		local index = i
		slider(skyGroup, "PrettySkyRotation" .. i, label, 0, -180, 180, 0, function(value)
			rotation[index] = value
			updateSky()
		end)
	end
	sunGroup:AddToggle("PrettyCelestialBodies", {
		Text = "Show sun, moon and stars",
		Default = true,
		Callback = function(on)
			celestial = on
			updateSky()
		end,
	})
	slider(sunGroup, "PrettyStarCount", "Star count (visible at night)", 3000, 0, 10000, 0, function(value)
		stars = value
		updateSky()
	end)
	slider(sunGroup, "PrettySunSize", "Sun size", 21, 0, 60, 1, function(value)
		sunSize = value
		updateSky()
	end)
	slider(sunGroup, "PrettyMoonSize", "Moon size", 11, 0, 60, 1, function(value)
		moonSize = value
		updateSky()
	end)
	imageInput(sunGroup, "PrettySunImage", "Sun image ID", "", function(value)
		sunImage = value
	end)
	imageInput(sunGroup, "PrettyMoonImage", "Moon image ID", "", function(value)
		moonImage = value
	end)
	local latitudeOverrideEnabled, latitude, originalLatitude = false, 41.733, nil
	local function updateLatitude()
		if latitudeOverrideEnabled then
			if originalLatitude == nil then
				originalLatitude = Lighting.GeographicLatitude
			end
			Lighting.GeographicLatitude = latitude
		elseif originalLatitude ~= nil then
			Lighting.GeographicLatitude = originalLatitude
			originalLatitude = nil
		end
	end
	sunGroup:AddToggle("PrettyLatitudeOverride", {
		Text = "Override sun latitude",
		Default = false,
		Callback = function(on)
			latitudeOverrideEnabled = on
			updateLatitude()
		end,
	})
	slider(sunGroup, "PrettySunLatitude", "Sun latitude", 41.733, 0, 360, 1, function(value)
		latitude = value
		updateLatitude()
	end)

	local waterObjects = {}
	local hideOverlay = true
	local waterEpoch = 0
	local function waterRoot()
		local map = Workspace:FindFirstChild("Map")
		local objects = map and map:FindFirstChild("AlwaysHereTweenedObjects")
		local ocean = objects and objects:FindFirstChild("Ocean")
		local object = ocean and ocean:FindFirstChild("Object")
		return object and object:FindFirstChild("ObjectModel")
	end
	local function restoreWaterObjects()
		for object, record in pairs(waterObjects) do
			for key, value in pairs(record) do
				pcall(function()
					object[key] = value
				end)
			end
			waterObjects[object] = nil
		end
	end
	local function setWater(object, key, value)
		waterObjects[object] = waterObjects[object] or {}
		if waterObjects[object][key] == nil then
			waterObjects[object][key] = object[key]
		end
		object[key] = value
	end
	local function inspectWater(object)
		if not waterEnabled or not object.Parent then
			return
		end
		local root = waterRoot()
		if not root then
			return
		end
		local ancestor = object
		while ancestor and ancestor ~= root do
			ancestor = ancestor.Parent
		end
		if not ancestor then
			return
		end
		if object:IsA("BasePart") and object.Transparency < 1 then
			setWater(object, "Transparency", water.WaterTransparency)
		elseif object:IsA("Decal") or object:IsA("Texture") then
			setWater(object, "Transparency", hideOverlay and 1 or water.WaterTransparency)
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
			setWater(object, "ImageTransparency", hideOverlay and 1 or water.WaterTransparency)
		elseif hideOverlay and object:IsA("SurfaceAppearance") then
			setWater(object, "Parent", nil)
		elseif hideOverlay and object:IsA("SpecialMesh") then
			setWater(object, "TextureId", "")
		end
		if hideOverlay and object:IsA("MeshPart") then
			setWater(object, "TextureID", "")
		end
	end
	local function updateWater()
		waterEpoch += 1
		restoreWaterObjects()
		if waterEnabled then
			if terrain then
				if not originalWaterSettings then
					originalWaterSettings = {}
					for property in pairs(water) do
						originalWaterSettings[property] = terrain[property]
					end
				end
				for property, value in pairs(water) do
					terrain[property] = value
				end
			end
			local root = waterRoot()
			if root then
				for _, object in ipairs(root:GetDescendants()) do
					inspectWater(object)
				end
			end
		elseif originalWaterSettings then
			for property, value in pairs(originalWaterSettings) do
				terrain[property] = value
			end
			originalWaterSettings = nil
		end
	end
	waterGroup:AddToggle("PrivateWaterEnabled", {
		Text = "Custom water appearance",
		Default = false,
		Callback = function(on)
			waterEnabled = on
			updateWater()
		end,
	})
	for _, option in ipairs({
		{ "Wave size", "WaterWaveSize", 0, 1, 2 },
		{ "Wave speed", "WaterWaveSpeed", 0, 100, 0 },
		{ "Water transparency", "WaterTransparency", 0, 1, 2 },
		{ "Water reflectance", "WaterReflectance", 0, 1, 2 },
	}) do
		local property = option[2]
		slider(
			waterGroup,
			"Private" .. property,
			option[1],
			water[property],
			option[3],
			option[4],
			option[5],
			function(value)
				water[property] = value
				updateWater()
			end
		)
	end
	waterGroup:AddToggle("PrettyHideWaterOverlay", {
		Text = "Hide water decals and textures",
		Default = true,
		Callback = function(on)
			hideOverlay = on
			updateWater()
		end,
	})
	waterGroup:AddLabel("Enable Custom water appearance. Transparency affects Terrain and the map's ocean surface.")
	connect(Workspace.DescendantAdded, function(object)
		if waterEnabled then
			local ticket = waterEpoch
			task.defer(function()
				if active and waterEnabled and waterEpoch == ticket then
					inspectWater(object)
				end
			end)
		end
	end)
	local cover, density = 0.5, 0.5
	local cloudsEnabled = false
	local ownsClouds = false
	local originalCloudSettings
	local cloudConnections = {}
	local applyingCloud = false
	local function releaseCloud()
		for _, connection in ipairs(cloudConnections) do
			connection:Disconnect()
		end
		table.clear(cloudConnections)
		local previous = clouds
		clouds = nil
		if ownsClouds then
			destroyInstance(previous)
		elseif previous and originalCloudSettings then
			for key, value in pairs(originalCloudSettings) do
				pcall(function()
					previous[key] = value
				end)
			end
		end
		ownsClouds = false
		originalCloudSettings = nil
	end
	local function updateClouds()
		if not cloudsEnabled then
			releaseCloud()
			return
		end
		terrain = Workspace:FindFirstChildOfClass("Terrain")
		if not terrain then
			return
		end
		if clouds and clouds.Parent ~= terrain then
			releaseCloud()
		end
		if not clouds then
			clouds = terrain:FindFirstChildOfClass("Clouds")
			if clouds then
				originalCloudSettings = { Cover = clouds.Cover, Density = clouds.Density, Enabled = clouds.Enabled }
			else
				clouds = Instance.new("Clouds")
				clouds.Name = "ArrivaLocalClouds"
				ownsClouds = true
				clouds.Parent = terrain
			end
			for _, property in ipairs({ "Enabled", "Cover", "Density" }) do
				table.insert(
					cloudConnections,
					connect(clouds:GetPropertyChangedSignal(property), function()
						if applyingCloud or not cloudsEnabled or not clouds then
							return
						end
						local desired = property == "Enabled" and true or property == "Cover" and cover or density
						if clouds[property] ~= desired then
							if originalCloudSettings then
								originalCloudSettings[property] = clouds[property]
							end
							applyingCloud = true
							clouds[property] = desired
							applyingCloud = false
						end
					end)
				)
			end
		end
		applyingCloud = true
		clouds.Enabled = true
		clouds.Cover = cover
		clouds.Density = density
		applyingCloud = false
	end
	cloudGroup:AddToggle("PrivateClouds", {
		Text = "Local clouds",
		Default = false,
		Callback = function(on)
			cloudsEnabled = on
			updateClouds()
		end,
	})
	cloudGroup:AddSlider("PrivateCloudCover", {
		Text = "Cloud cover",
		Default = 0.5,
		Min = 0,
		Max = 1,
		Rounding = 2,
		Callback = function(value)
			cover = value
			updateClouds()
		end,
	})
	cloudGroup:AddSlider("PrivateCloudDensity", {
		Text = "Cloud density",
		Default = 0.5,
		Min = 0,
		Max = 1,
		Rounding = 2,
		Callback = function(value)
			density = value
			updateClouds()
		end,
	})
	if terrain then
		connect(terrain.ChildAdded, function(child)
			if cloudsEnabled and child:IsA("Clouds") and child ~= clouds then
				if ownsClouds then
					releaseCloud()
				end
				updateClouds()
			end
		end)
		connect(terrain.ChildRemoved, function(child)
			if cloudsEnabled and child == clouds then
				task.defer(function()
					if active and cloudsEnabled then
						updateClouds()
					end
				end)
			end
		end)
	end
	connect(Lighting.ChildAdded, function(child)
		if skyboxEnabled and child:IsA("Sky") and child ~= sky then
			originalSkyParents[child] = Lighting
			child.Parent = nil
		end
	end)

	local function destroy()
		if not active then
			return
		end
		active = false
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		clearShader()
		skyboxEnabled = false
		updateSky()
		waterEnabled = false
		updateWater()
		cloudsEnabled = false
		releaseCloud()
		latitudeOverrideEnabled = false
		updateLatitude()
		setParticlesEnabled(false)
		particleHolder:Destroy()
	end

	Obsidian:OnUnload(destroy)
end
