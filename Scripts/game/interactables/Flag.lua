--dofile( "$CONTENT_DATA/Scripts/game/raft_quests.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/WindManager.lua" )

Flag = class()

function Flag.client_onCreate(self)
    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.effect:setOffsetPosition(sm.vec3.new(0, -0.28, 0))
    self.effect:setParameter("uuid", sm.uuid.new("4a971f7d-14e6-454d-bce8-0879243c4859"))
	self.effect:setParameter("color", sm.color.new(1,0,0))
	self.effect:setScale(sm.vec3.new(0.15, 0.15, 0.4))
    self.effect:start()
end

function Flag.client_onUpdate( self, dt )
    if not self.effect:isPlaying() then self.effect:start() end

    local center = getWindCenter()

    local direction = self.shape:transformPoint(center)
    direction.y = 0
    self.effect:setOffsetRotation(sm.vec3.getRotation(sm.vec3.new(0, 0, 1), -direction))
end