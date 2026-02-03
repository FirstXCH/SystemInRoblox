local DashMechanic = {}

-- Services
local TweenService = game:GetService("TweenService")

-- Configuration Constants
local DASH_SPEED = 130        -- Initial burst velocity
local END_SPEED = 16          -- Target velocity at end (matches WalkSpeed for smooth transition)
local DURATION = 0.4          -- Total duration of the dash

-- State Tracking
-- Stores active dash instances per character to handle interruptions/spamming
local activeDashes = {} 

--[[
    Initiates the dash mechanics for a given character.
    Handles physics creation, smooth deceleration, and cleanup of previous dashes.
]]
function DashMechanic.Start(character, moveDirection)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- 1. Interrupt Existing Dash
	if activeDashes[character] then
		local oldData = activeDashes[character]
		if oldData.tween then oldData.tween:Cancel() end
		if oldData.lv then oldData.lv:Destroy() end
		if oldData.att then oldData.att:Destroy() end
		if oldData.cleanupTask then task.cancel(oldData.cleanupTask) end
		activeDashes[character] = nil
	end

	-- 2. Setup Physics
	local att = Instance.new("Attachment")
	att.Name = "DashAtt"
	att.Parent = hrp

	local lv = Instance.new("LinearVelocity")
	lv.Name = "DashForce"
	lv.Attachment0 = att
	lv.MaxForce = 100000

	-- [[ FIX: ADD DOWNWARD FORCE ]] --
	-- Instead of just moveDirection * Speed, we modify the Y axis.
	-- Setting Y to -60 forces the character into the ground, simulating "Grip" or heavy friction.
	local dashVelocity = moveDirection * DASH_SPEED
	lv.VectorVelocity = Vector3.new(dashVelocity.X, 0.2, dashVelocity.Z) 

	lv.Parent = hrp

	-- 3. Deceleration Tween
	local tweenInfo = TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- [[ FIX: MAINTAIN DOWNWARD FORCE IN TWEEN ]] --
	-- When slowing down, keep pushing down (-60) so they don't float at the end.
	local endVelocity = moveDirection * END_SPEED
	local goal = { VectorVelocity = Vector3.new(endVelocity.X, -1.15, endVelocity.Z) }

	local tween = TweenService:Create(lv, tweenInfo, goal)
	tween:Play()

	-- 4. Cleanup
	local cleanupTask
	cleanupTask = task.delay(DURATION, function()
		if lv then lv:Destroy() end
		if att then att:Destroy() end
		if activeDashes[character] and activeDashes[character].cleanupTask == cleanupTask then
			activeDashes[character] = nil
		end
	end)

	activeDashes[character] = {
		lv = lv,
		att = att,
		tween = tween,
		cleanupTask = cleanupTask
	}
end

return DashMechanic