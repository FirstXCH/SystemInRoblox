-- Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris") 
local TweenService = game:GetService("TweenService")

-- Modules
local DashMechanic = require(ReplicatedStorage:WaitForChild("DashMechanic"))

-- Player References
local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local hrp = character:WaitForChild("HumanoidRootPart")

-- Assets References
-- Retrieve VFX prototype from ReplicatedStorage for cloning
local vfxPrototype = ReplicatedStorage:WaitForChild("DashVFXPart") 

-- =========================================================================
-- [CONFIG] Animation IDs & Sound Settings
-- =========================================================================
local ANIM_IDS = {
	Front = { "rbxassetid://84491878384466", "rbxassetid://95880161405435" },
	Back  = "rbxassetid://124947404554495",
	Left  = "rbxassetid://88693470039038",
	Right = "rbxassetid://90208193158043",
}

local DASH_SOUND_ID = "rbxassetid://104492907784363" 
local SOUND_VOLUME = 1.5 
local SOUND_PITCH = 1.1 

-- Setup Sound Object
local dashSound = Instance.new("Sound")
dashSound.Name = "DashSFX"
dashSound.SoundId = DASH_SOUND_ID
dashSound.Volume = SOUND_VOLUME
dashSound.PlaybackSpeed = SOUND_PITCH
dashSound.Parent = hrp
-- =========================================================================

local COOLDOWN = 0.25 
local lastDashTime = 0
local loadedAnims = {} 

-- 1. Preload Animations
-- Loads all animations into the animator at startup to prevent playback delay.
local function PreloadAnimations()
	for direction, idOrTable in pairs(ANIM_IDS) do
		if type(idOrTable) == "table" then
			for _, id in ipairs(idOrTable) do
				local animObj = Instance.new("Animation")
				animObj.AnimationId = id
				local key = direction .. "_" .. id
				pcall(function() loadedAnims[key] = animator:LoadAnimation(animObj) end)
			end
		else
			local animObj = Instance.new("Animation")
			animObj.AnimationId = idOrTable
			local key = direction .. "_" .. idOrTable
			pcall(function() loadedAnims[key] = animator:LoadAnimation(animObj) end)
		end
	end
end
task.spawn(PreloadAnimations)

-- 2. Play Animation Function
-- Selects and plays the appropriate animation based on direction.
-- Supports random selection if multiple IDs are provided (e.g., Front dash variants).
local function PlayDashAnim(directionName)
	local data = ANIM_IDS[directionName]
	if not data then return end

	local selectedID
	if type(data) == "table" then
		selectedID = data[math.random(1, #data)]
	else
		selectedID = data
	end

	local key = directionName .. "_" .. selectedID
	local track = loadedAnims[key]

	-- Fallback load if not preloaded
	if not track then
		local animObj = Instance.new("Animation")
		animObj.AnimationId = selectedID
		track = animator:LoadAnimation(animObj)
		loadedAnims[key] = track
	end

	if track then
		track.Priority = Enum.AnimationPriority.Action -- Ensure dash overrides walking anims
		track:Play(0) -- Instant transition (0 fade time)
	end
end

-- 3. Play VFX Function
-- Clones the VFX model, orientates it towards the dash direction, and handles cleanup.
local function PlayDashVFX(moveDirection)
	if not vfxPrototype then return end

	-- Clone VFX
	local vfxClone = vfxPrototype:Clone()
	vfxClone.Parent = workspace

	-- Calculate Position & Rotation
	-- Places VFX at feet level and rotates it to face the movement direction
	local footPosition = hrp.Position - Vector3.new(0, 3, 0)
	local effectCFrame = CFrame.lookAt(footPosition, footPosition + moveDirection) * CFrame.Angles(math.rad(90), 0, 0)

	if vfxClone:IsA("Model") then
		vfxClone:PivotTo(effectCFrame)
	else
		vfxClone.CFrame = effectCFrame
	end

	-- Trigger Particle Emission
	for _, child in ipairs(vfxClone:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			child:Emit(5) 
		end
	end

	-- Fade Out Effect (Tween Transparency)
	local fadeDuration = 0.5 
	local tweenInfo = TweenInfo.new(fadeDuration, Enum.EasingStyle.Linear)
	local goal = {Transparency = 1} 

	for _, child in ipairs(vfxClone:GetDescendants()) do
		if child:IsA("BasePart") or child:IsA("Decal") or child:IsA("MeshPart") then
			local tween = TweenService:Create(child, tweenInfo, goal)
			tween:Play()
		end
	end

	-- Cleanup
	Debris:AddItem(vfxClone, 2) 
end


-- 4. Input Handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Q then

		-- Cooldown Check
		local currentTime = tick()
		if currentTime - lastDashTime < COOLDOWN then return end
		lastDashTime = currentTime

		-- Calculate Movement Direction relative to Camera
		local moveDir = Vector3.new(0,0,0)
		local camCF = workspace.CurrentCamera.CFrame
		local dashName = "Front"

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then 
			moveDir = moveDir + camCF.LookVector 
			dashName = "Front" 
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then 
			moveDir = moveDir - camCF.LookVector 
			dashName = "Back" 
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then 
			moveDir = moveDir - camCF.RightVector 
			dashName = "Left" 
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then 
			moveDir = moveDir + camCF.RightVector 
			dashName = "Right" 
		end

		if moveDir.Magnitude == 0 then
			moveDir = hrp.CFrame.LookVector -- Default to forward if no input
			dashName = "Front"
		else
			-- Normalize direction and remove Y component (prevent flying)
			moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
		end

		-- Execute Dash Actions
		dashSound:Play() 
		PlayDashVFX(moveDir) -- Pass direction for directional VFX
		PlayDashAnim(dashName)
		DashMechanic.Start(character, moveDir)
	end
end)