GameHook = class()

local gameHooked = false
local oldHud = sm.gui.createSurvivalHudGui
function hudHook()
    if not gameHooked then
        dofile("$CONTENT_fed51d61-bc85-420d-82af-b645f2a23145/Scripts/vanilla_override.lua")
        gameHooked = true
    end

	return oldHud()
end
sm.gui.createSurvivalHudGui = hudHook

local oldBind = sm.game.bindChatCommand
function bindHook(command, params, callback, help)
    if not gameHooked then
        dofile("$CONTENT_fed51d61-bc85-420d-82af-b645f2a23145/Scripts/vanilla_override.lua")
        gameHooked = true
    end

	return oldBind(command, params, callback, help)
end
sm.game.bindChatCommand = bindHook