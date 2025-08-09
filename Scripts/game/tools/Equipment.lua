Equipment = class()
dofile "$CONTENT_DATA/Scripts/game/raft_items.lua"

function Equipment:client_onCreate()
    self.cl = {}
    self.cl.player = self.tool:getOwner()
    self.cl.char = self.cl.player.character
    self.cl.addedRend = false
end

function Equipment:client_onFixedUpdate()
    if not sm.exists(self.cl.char) then
        self.cl.char = self.cl.player.character
    end

    local inv = sm.game.getLimitedInventory() and self.cl.player:getInventory() or self.cl.player:getHotbar()
    local canSpend = inv:canSpend( self.uuid, 1 )
    if canSpend and not self.cl.addedRend then
        self.cl.char:addRenderable( self.renderable )
        self.cl.addedRend = true
    elseif not canSpend and self.cl.addedRend then
        self.cl.char:removeRenderable( self.renderable )
        self.cl.addedRend = false
    end
end

Tank = class( Equipment )
Tank.renderable = "$CONTENT_DATA/Characters/Char_Player/OxygenTank/OxygenTank.rend"
Tank.uuid = obj_oxygen_tank

Fins = class( Equipment )
Fins.renderable = "$CONTENT_DATA/Characters/Char_Player/Fins/obj_fins.rend"
Fins.uuid = obj_fins

--damn you BasePlayer.lua
--[[function Fins:server_onCreate()
    self.sv = {}
    self.sv.player = self.tool:getOwner()
    self.sv.char = self.sv.player.character
end

function Fins:server_onFixedUpdate()
    if not sm.exists(self.sv.char) then
        self.sv.char = self.sv.player.character
    end

    print(self.sv.char.movementSpeedFraction)
    if not self.sv.player:getHotbar():canSpend( self.uuid, 1 ) then
        self.sv.char.movementSpeedFraction = 1
        return
    end

    self.sv.char.movementSpeedFraction = (self.sv.char:isSwimming() or self.sv.char:isDiving()) and 1.5 or 1
end]]