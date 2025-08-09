dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua"

Binoculars = class()

local minZoom = 2
local maxZoom = 10

local renderables = { "$CONTENT_DATA/Characters/Char_Tools/Char_binocular/char_binocular_preview.rend" }
local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend", "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_tp_animlist.rend", "$CONTENT_DATA/Characters/Char_Tools/Char_binocular/char_male_tp_binocular.rend" }
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_fp_animlist.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend", "$CONTENT_DATA/Characters/Char_Tools/Char_binocular/char_male_fp_binocular.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function Binoculars.client_onCreate( self )
	self.aiming = false

	if self.tool:isLocal() then
		self.camTransitionProgress = 0
		self.zoomFactor = minZoom
		self.vignette = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Overlays/BinocularsOverlay.layout", false,
			{
				isHud = true,
				isInteractive = false,
				needsCursor = false,
				hidesHotbar = true,
				isOverlapped = true
			}
		)
	end
end



function Binoculars.client_onRefresh( self )
	self:loadAnimations()
end

function Binoculars.loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			aim = { "binocular_zoom", { crouch = "spudgun_crouch_aim" } },
			idle = { "fertilizer_idle" },
			pickup = { "fertilizer_pickup", { nextAnimation = "idle" } },
			putdown = { "fertilizer_putdown" }
		}
	)
	local movementAnimations = {
		idle = "fertilizer_idle",
		idleRelaxed = "fertilizer_idle_relaxed",

		runFwd = "fertilizer_run_fwd",
		runBwd = "fertilizer_run_bwd",
		sprint = "fertilizer_sprint",

		jump = "fertilizer_jump",
		jumpUp = "fertilizer_jump_up",
		jumpDown = "fertilizer_jump_down",

		land = "fertilizer_jump_land",
		landFwd = "fertilizer_jump_land_fwd",
		landBwd = "fertilizer_jump_land_bwd",

		crouchIdle = "fertilizer_crouch_idle",
		crouchFwd = "fertilizer_crouch_fwd",
		crouchBwd = "fertilizer_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "binocular_pickup", { nextAnimation = "idle" } },
				unequip = { "binocular_putdown" },

				idle = { "binocular_idle", { looping = true } },

				aimInto = { "binocular_aim_into", { nextAnimation = "aimIdle" } },
				aimExit = { "binocular_aim_exit", { nextAnimation = "idle", blendNext = 0 } },
				aimIdle = { "binocular_aim_idle", { looping = true} },

				sprintInto = { "binocular_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintExit = { "binocular_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "binocular_sprint_idle", { looping = true } },
			}
		)
	end

	self.normalFireMode = {
		fireCooldown = 0.20,
		spreadCooldown = 0.18,
		spreadIncrement = 2.6,
		spreadMinAngle = .25,
		spreadMaxAngle = 8,
		fireVelocity = 130.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 0.20,
		spreadCooldown = 0.18,
		spreadIncrement = 1.3,
		spreadMinAngle = 0,
		spreadMaxAngle = 8,
		fireVelocity =  130.0,

		minDispersionStanding = 0.01,
		minDispersionCrouching = 0.01,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.fireCooldownTimer = 0.0
	self.spreadCooldownTimer = 0.0

	self.movementDispersion = 0.0

	self.sprintCooldownTimer = 0.0
	self.sprintCooldown = 0.3

	self.aimBlendSpeed = 3.0
	self.blendTime = 0.2

	self.jointWeight = 0.0
	self.spineWeight = 0.0
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )

end

function Binoculars.client_onUpdate( self, dt )
	-- First person animation
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()

	if self.tool:isLocal() then
		local camdir = sm.localPlayer.getPlayer().character:getDirection()
		local campos = sm.localPlayer.getPlayer().character.worldPosition + sm.vec3.new(0,0,0.575)
		local camrot = sm.camera.getDefaultRotation()
		local fovRightNow = sm.camera.getFov()

		if self.defaultFov ~= nil then
			self.camTransitionProgress = sm.util.clamp(self.camTransitionProgress + dt * 5, 0, 1)
			local currentZoom = self.defaultFov / self.zoomFactor

			if sm.camera.getCameraState() == sm.camera.state.cutsceneFP then
				sm.camera.setPosition(campos)
				sm.camera.setRotation(camrot)
				--sm.camera.setDirection(sm.vec3.lerp(sm.camera.getDirection(), camdir, dt / (self.zoomFactor / maxZoom)))
				sm.camera.setDirection(camdir)
			end

			if self.aiming then
				self.tool:updateCamera( 2.8, 110.0, sm.vec3.new( 0.65, 0.0, 0.05 ), self.aimWeight )
				self.tool:updateFpCamera( self.defaultFov, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, 0.12 )
				sm.camera.setCameraState(sm.camera.state.cutsceneFP)

				sm.camera.setFov(sm.util.lerp(fovRightNow, currentZoom, self.camTransitionProgress))
			elseif not self.aiming and fovRightNow ~= self.defaultFov then
				self.tool:updateFpCamera( self.defaultFov, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, 1)
				sm.camera.setFov(sm.util.lerp(fovRightNow, self.defaultFov, self.camTransitionProgress))

				if self.camTransitionProgress >= 1 then
					sm.camera.setCameraState(sm.camera.state.default)
				end
			end
		end

		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end

			if self.aiming and not isAnyOf( self.fpAnimations.currentAnimation, { "aimInto", "aimIdle" } ) then
				swapFpAnimation( self.fpAnimations, "aimExit", "aimInto", 0.0 )
			end
			if not self.aiming and isAnyOf( self.fpAnimations.currentAnimation, { "aimInto", "aimIdle" } ) then
				swapFpAnimation( self.fpAnimations, "aimInto", "aimExit", 0.0 )
			end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	-- Timers
	self.fireCooldownTimer = math.max( self.fireCooldownTimer - dt, 0.0 )
	self.spreadCooldownTimer = math.max( self.spreadCooldownTimer - dt, 0.0 )
	self.sprintCooldownTimer = math.max( self.sprintCooldownTimer - dt, 0.0 )


	if self.tool:isLocal() then
		self.tool:setDispersionFraction(0)

		if self.aiming then
			if self.tool:isInFirstPersonView() then
				self.tool:setCrossHairAlpha( 1.0 )
			else
				self.tool:setCrossHairAlpha( 1.0 )
			end
			self.tool:setInteractionTextSuppressed( true )
		else
			self.tool:setCrossHairAlpha( 1.0 )
			self.tool:setInteractionTextSuppressed( false )
		end
	end

	-- Sprint block
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0
	self.tool:setBlockSprint( blockSprint )

	local playerDir = self.tool:getDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )
	local linareAngle = playerDir:dot( sm.vec3.new( 0, 0, 1 ) )

	local linareAngleDown = clamp( -linareAngle, 0.0, 1.0 )

	local down = clamp( -angle, 0.0, 1.0 )
	local fwd = ( 1.0 - math.abs( angle ) )
	local up = clamp( angle, 0.0, 1.0 )

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

	local totalWeight = 0.0
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if name == "pickup" then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end

	-- Third Person joint lock
	local relativeMoveDirection = self.tool:getRelativeMoveDirection()
	if ( ( ( isAnyOf( self.tpAnimations.currentAnimation, { "aimInto", "aim" } ) and ( relativeMoveDirection:length() > 0 or isCrouching) ) or ( self.aiming and ( relativeMoveDirection:length() > 0 or isCrouching) ) ) and not isSprinting ) then
		self.jointWeight = math.min( self.jointWeight + ( 10.0 * dt ), 1.0 )
	else
		self.jointWeight = math.max( self.jointWeight - ( 6.0 * dt ), 0.0 )
	end

	if ( not isSprinting ) then
		self.spineWeight = math.min( self.spineWeight + ( 10.0 * dt ), 1.0 )
	else
		self.spineWeight = math.max( self.spineWeight - ( 10.0 * dt ), 0.0 )
	end

	local finalAngle = ( 0.5 + angle * 0.5 )
	self.tool:updateAnimation( "spudgun_spine_bend", finalAngle, self.spineWeight )

	local totalOffsetZ = lerp( -22.0, -26.0, crouchWeight )
	local totalOffsetY = lerp( 6.0, 12.0, crouchWeight )
	local crouchTotalOffsetX = clamp( ( angle * 60.0 ) -15.0, -60.0, 40.0 )
	local normalTotalOffsetX = clamp( ( angle * 50.0 ), -45.0, 50.0 )
	local totalOffsetX = lerp( normalTotalOffsetX, crouchTotalOffsetX , crouchWeight )

	local finalJointWeight = ( self.jointWeight )


	self.tool:updateJoint( "jnt_hips", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.35 * finalJointWeight * ( normalWeight ) )

	local crouchSpineWeight = ( 0.35 / 3 ) * crouchWeight

	self.tool:updateJoint( "jnt_spine1", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight )  * finalJointWeight )
	self.tool:updateJoint( "jnt_spine2", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_spine3", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.45 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_head", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.3 * finalJointWeight )


end

function Binoculars.client_onEquip( self, animate )

	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	self.aiming = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
		self.defaultFov = sm.camera.getFov()
		self.vignette:setText("ZoomFactorDisplay", language_tag("BinocularsZoomFactor") .."#df7f00" .. self.zoomFactor .. "x")
	end

	self.tool:setTpRenderables( currentRenderablesTp )

	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )

	if self.tool:isLocal() then
		-- Sets Binoculars renderable, change this to change the mesh
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function Binoculars.client_onUnequip( self, animate )

	self.wantEquipped = false
	self.equipped = false
	self.aiming = false
	if sm.exists( self.tool ) then
		if animate then
			sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
		end
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() then
			self.vignette:close()
			sm.camera.setCameraState(sm.camera.state.default)
			sm.camera.setFov(self.defaultFov)

			self.tool:setMovementSlowDown( false )
			self.tool:setBlockSprint( false )
			self.tool:setCrossHairAlpha( 1.0 )
			self.tool:setInteractionTextSuppressed( false )
			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
			end
		end
	end
end

function Binoculars.sv_n_onZoom( self, aiming )
	self.network:sendToClients( "cl_n_onZoom", aiming )
end

function Binoculars.cl_n_onZoom( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onZoom( aiming )
	end
end

function Binoculars.onZoom( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function Binoculars.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	self.camTransitionProgress = 0
	if state == sm.tool.interactState.start and not self.aiming then
		sm.gui.startFadeToBlack( 0.45, 0.60 )
		self.aiming = true
		self.vignette:open()
		self:onZoom(self.aiming)
		self.network:sendToServer("sv_n_onZoom", self.aiming)
	elseif self.aiming and (state == sm.tool.interactState.stop or state == sm.tool.interactState.null) then
		sm.gui.startFadeToBlack( 0.15, 0.25 )
		self.aiming = false
		self.vignette:close()
		self:onZoom(self.aiming)
		self.network:sendToServer("sv_n_onZoom", self.aiming)
	end
end

function Binoculars.cl_onSecondaryUse( self, state )
	if self.tool:getOwner().character == nil or not self.aiming  or state ~= sm.tool.interactState.start then
		return
	end

	self.zoomFactor = self.zoomFactor == maxZoom and minZoom or self.zoomFactor + 1
	self.camTransitionProgress = 0
	local zoomText = language_tag("BinocularsZoomFactor") .."#df7f00" .. self.zoomFactor .. "x"
	self.vignette:setText("ZoomFactorDisplay", zoomText)
	--sm.gui.displayAlertText(zoomText,5)
end

function Binoculars.client_onEquippedUpdate( self, primaryState, secondaryState )
	if primaryState ~= self.prevPrimaryState then
		self:cl_onPrimaryUse( primaryState )
		self.prevPrimaryState = primaryState
	end

	if secondaryState ~= self.prevSecondaryState then
		self:cl_onSecondaryUse( secondaryState )
		self.prevSecondaryState = secondaryState
	end

	return true, true
end
