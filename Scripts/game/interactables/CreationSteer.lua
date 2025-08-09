Steer = class()
Steer.maxChildCount = -1
Steer.maxParentCount = 2
Steer.connectionInput = sm.interactable.connectionType.power + sm.interactable.connectionType.logic
Steer.connectionOutput = sm.interactable.connectionType.logic
Steer.colorNormal = sm.color.new("#00ff33")
Steer.colorHighlight = sm.color.new("#00ff00")

dofile "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua"
dofile "$CONTENT_DATA/Scripts/game/raft_items.lua"

local modes = {
    language_tag("CreationRotator_Ver_Hor"),
    language_tag("CreationRotator_Ver"),
    language_tag("CreationRotator_Hor"),
    language_tag("CreationRotator_Roll")
}

local controlModes = {
    language_tag("CreationRotator_Input_mouse"),
    language_tag("CreationRotator_Input_wasd")
}

local massDivider = 15

local maxForceMult = 25

function Steer:server_onCreate()
    self.sv = {}
    self.sv.data = self.storage:load()

    if self.sv.data == nil then
        self.sv.data = {
            count = 1,
            controlMethodCount = 1,
            slider = 1
        }
    end

    if self.sv.data.controlMethodCount == nil then self.sv.data.controlMethodCount = 1 end

    self.network:sendToClients("cl_updateData", self.sv.data)
    self:sv_updateState( { active = false, power = 0, index = 1  } )
end

function Steer:client_onCreate()
    self.cl = {
        data = {},
        gui = sm.gui.createEngineGui()
    }

    self.cl.gui:setText( "Name", language_tag("CreationRotator_Title") )
	self.cl.gui:setText( "Interaction", language_tag("CreationRotator_Force") )
	self.cl.gui:setSliderCallback( "Setting", "cl_onSliderChange" )
	self.cl.gui:setIconImage( "Icon", obj_creationSteer )
end

function Steer:cl_refreshGUI()
    self.cl.gui:setSliderData( "Setting", maxForceMult + 1, self.cl.data.slider )
    self.cl.gui:setText( "SubTitle", language_tag("CreationRotator_Mult").. tostring( self.cl.data.slider ) )
end

function Steer:cl_onSliderChange( sliderName, sliderPos )
    self.cl.data.slider = sliderPos
    self:cl_refreshGUI()
    self.network:sendToServer("sv_onSliderChange", sliderPos)
end

function Steer:sv_onSliderChange( sliderPos )
    self.sv.data.slider = sliderPos
    self:sv_save()
end

function Steer:server_onFixedUpdate( dt )
     if not self.sv or not self.sv.data then return end

    local logicParent = self.interactable:getParents( sm.interactable.connectionType.logic )[1]
    local seatParent = self.interactable:getParents( sm.interactable.connectionType.power )[1]
    if not seatParent or logicParent and not logicParent:isActive() then
        if self.interactable:isActive() then
            self:sv_updateState( { active = false, power = 0, index = 1  } )
        end

        return
    end

    local seatedChar = seatParent:getSeatCharacter()
    if not seatedChar then
        if self.interactable:isActive() then
            self:sv_updateState( { active = false, power = 0, index = 1  } )
        end

        return
    end

    local forceDir = sm.vec3.zero()
    local parentShape = seatParent:getShape()
    local parentRight = parentShape:getRight()
    local parentAt = parentShape:getAt()
    local parentDir = parentRight:cross(parentAt) --a seat's getAt is upwards, I want a forward direction
    if controlModes[self.sv.data.controlMethodCount] == controlModes[1] then
        local charDir = seatedChar:getDirection()
        forceDir = parentDir:cross(charDir)
    else
        local forward = seatParent:getSteeringPower()
        local steer = seatParent:getSteeringAngle()
        forceDir = (parentRight * forward) + (parentAt * -steer)
    end

    --self.network:sendToClients("cl_visualise", { charDir, parentDir, forceDir })

    local bodyToRotate = parentShape:getBody()
    local creationMass = 0
    for v, k in pairs(self.shape:getBody():getCreationShapes()) do
        creationMass = creationMass + k:getBody():getMass()
    end

    local selectedMode = modes[self.sv.data.count]
    if selectedMode == modes[2] then
        forceDir.z = 0
    elseif selectedMode == modes[3] then
        forceDir.y = 0
        forceDir.x = 0
    elseif selectedMode == modes[4] then
        forceDir.y = 0
        forceDir.z = 0
        forceDir = parentDir * seatParent:getSteeringAngle()
    end

    sm.physics.applyTorque( bodyToRotate, forceDir * (creationMass / massDivider) * dt * self.sv.data.slider, true )
    if not self.interactable:isActive() then
        self:sv_updateState( { active = true, power = 1, index = 7 } )
    end
end

function Steer:cl_updateData( data )
    self.cl.data = data
end

function Steer.client_getAvailableParentConnectionCount( self, connectionType )
	if bit.band( connectionType, sm.interactable.connectionType.logic ) ~= 0 then
		return 1 - #self.interactable:getParents( sm.interactable.connectionType.logic )
	end
	if bit.band( connectionType, sm.interactable.connectionType.power ) ~= 0 then
		return 1 - #self.interactable:getParents( sm.interactable.connectionType.power )
	end
	return 0
end

function Steer:cl_visualise( dir )
    for v, k in pairs(dir) do
        sm.particle.createParticle( "paint_smoke", self.shape:getWorldPosition() + k, sm.quat.identity(), sm.color.new(v/10, v/10, v/10) )
    end
end

function Steer:sv_updateState( args )
    self.interactable:setActive( args.active )
    self.interactable:setPower( args.power )

    self.network:sendToClients("cl_uvUpdate", args.index)
end

function Steer:sv_save()
    self.storage:save( self.sv.data )
    self.network:sendToClients("cl_updateData", self.sv.data)
end

function Steer:cl_uvUpdate( index )
    self.interactable:setUvFrameIndex( index )
end

function Steer:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
	sm.gui.setInteractionText( o1..language_tag("CreationRotator_CurrentMode")..modes[self.cl.data.count]..language_tag("CreationRotator_CurrentInput")..controlModes[self.cl.data.controlMethodCount]..o2 )
    sm.gui.setInteractionText(
        sm.gui.getKeyBinding( "Use", true )..language_tag("Switch_mode"),
        sm.gui.getKeyBinding( "Tinker", true )..language_tag("CreationRotator_SwitchInput"),
        sm.gui.getKeyBinding( "Crawl", true ).." + "..sm.gui.getKeyBinding( "Use", true )..language_tag("CreationRotator_AdjustForce")
    )

    return true
end

function Steer:client_onInteract( char, lookAt )
    if lookAt then
        if char:isCrouching() then
            self:cl_refreshGUI()
            self.cl.gui:open()
        else
            self.network:sendToServer("sv_changeCount", "add")
            sm.audio.play("PaintTool - ColorPick")
        end
    end
end

function Steer:client_onTinker( char, lookAt )
    if lookAt then
        --self.network:sendToServer("sv_changeCount", "subtract")
        self.network:sendToServer("sv_changeControlMode")
        sm.audio.play("PaintTool - ColorPick")
    end
end

function Steer:sv_changeControlMode()
    self.sv.data.controlMethodCount = self.sv.data.controlMethodCount < #controlModes and self.sv.data.controlMethodCount + 1 or 1
    self:sv_save()
end

function Steer:sv_changeCount( type )
    if type == "add" then
        self.sv.data.count = self.sv.data.count < #modes and self.sv.data.count + 1 or 1
    else
        self.sv.data.count = self.sv.data.count > 1 and self.sv.data.count - 1 or #modes
    end

    self:sv_save()
end