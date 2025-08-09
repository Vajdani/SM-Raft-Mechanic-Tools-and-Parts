dofile "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua"
dofile( "$SURVIVAL_DATA/Scripts/game/managers/BeaconManager.lua" )

Antenna = class()
Antenna.maxParentCount = 0
Antenna.maxChildCount = 0
Antenna.connectionInput = sm.interactable.connectionType.none
Antenna.connectionOutput = sm.interactable.connectionType.none

local UVSpeed = 5

function Antenna:server_onCreate()
	self.sv = {}
	self.sv.loaded = true
	self.sv.iconData = {
		iconIndex = 10,
		colorIndex = 3
	}

	if not g_raft_beaconManager then
		g_raft_beaconManager = BeaconManager()
		g_raft_beaconManager:sv_onCreate()
	end

	g_raft_beaconManager:sv_createBeacon( self.shape, self.sv.iconData )
end

function Antenna.server_onDestroy( self )
	if self.sv.loaded then
		if g_raft_beaconManager then
			g_raft_beaconManager:sv_destroyBeacon( self.shape )
		end
		self.sv.loaded = false
	end
end

function Antenna.server_onUnload( self )
	if self.sv.loaded then
		if g_raft_beaconManager then
			g_raft_beaconManager:sv_unloadBeacon( self.shape )
		end
		self.sv.loaded = false
	end
end

function Antenna.client_onCreate( self )
    self.cl = {}
	self.cl.iconData = {
		iconIndex = 10,
		colorIndex = 3
	}

	self.cl.loopingIndex = 0
	self.effect = sm.effect.createEffect( "Antenna - Activation", self.interactable )

	if self.cl.beaconIconGui then
		self.cl.beaconIconGui:close()
	end

	self.cl.beaconIconGui = sm.gui.createWorldIconGui( 44, 44, "$GAME_DATA/Gui/Layouts/Hud/Hud_BeaconIcon.layout", false )
	self.cl.beaconIconGui:setItemIcon( "Icon", "BeaconIconMap", "BeaconIconMap", tostring( self.cl.iconData.iconIndex ) )
	local beaconColor = BEACON_COLORS[self.cl.iconData.colorIndex]
	self.cl.beaconIconGui:setColor( "Icon", beaconColor )
	self.cl.beaconIconGui:setHost( self.shape )
	self.cl.beaconIconGui:setRequireLineOfSight( false )
	self.cl.beaconIconGui:setMaxRenderDistance(10000)
	self.cl.beaconIconGui:open()

	if g_raft_beaconManager == nil then
		assert( not sm.isHost )
		g_raft_beaconManager = BeaconManager()
	end
	g_raft_beaconManager:cl_onCreate()
end

function Antenna.client_onUpdate( self, dt )
	if self.cl.beaconIconGui then
		self.cl.beaconIconGui:setWorldPosition(self.shape.worldPosition)
	end

	self.cl.loopingIndex = self.cl.loopingIndex + dt * UVSpeed
	if self.cl.loopingIndex >= 4 then
		self.cl.loopingIndex = 0
	end
	self.interactable:setUvFrameIndex( math.floor( self.cl.loopingIndex ) )

	if self.cl.idleSound and not self.cl.idleSound:isPlaying() then
		self.cl.idleSound:start()
	end
end

function Antenna.client_onInteract( self, character, state )
	if state == true then
        self.network:sendToServer("sv_send_event")
	end
end

function Antenna:sv_send_event()
	self.network:sendToClients("cl_playEffect")
end

function Antenna.client_onDestroy(self)
	if self.cl.beaconIconGui then
		self.cl.beaconIconGui:close()
		self.cl.beaconIconGui:destroy()
	end
end

function Antenna.cl_playEffect(self)
    self.effect:start()
end