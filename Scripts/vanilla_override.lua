local ToolItems = {
	["e3bcf8fa-68d7-49a8-b17b-c1e864d53b69"] = sm.uuid.new("108fb249-868e-427d-acba-bd8e80d8ef30"), --Fishing Rod
    ["b5ade3b0-be48-4a61-a8c2-13a4cedf1343"] = sm.uuid.new("d0840a29-80d9-4081-be36-aa04518fc674"), --Pulling Hook
    ["1daebe24-4e16-422c-b5e7-c3f45f9296d8"] = sm.uuid.new("c190da26-1f1b-4590-935c-d8cc17a24bbd"), --Axe
    ["c883b283-ea7a-4bba-af0d-5c13fd73051d"] = sm.uuid.new("2e5e8950-3a82-42b5-8f4e-36a446bf5f06"), --Pivkaxe
    ["0db1ecd5-503d-4dd3-807e-869c243a7c08"] = sm.uuid.new("4967b981-d88f-4b9f-9a6a-d0c052b54e45"), --Spear
    ["e34387d3-fa29-4831-89b8-c94417b6fce6"] = sm.uuid.new("64e437f7-73fd-44e3-90db-650ef61adacc"), --Harpoon
    ["bb641a4f-e391-441c-bc6d-0ae21a069477"] = sm.uuid.new("e1227b41-f78a-4e33-a498-47d2a21b1066"), --Wood Hammer
	["f3aeb880-f103-43c8-947b-d0525eaeb505"] = sm.uuid.new("77ff422b-0cfb-4f56-8e1a-5aa33aa28042") 	--Spyglass
}

local oldGetToolProxyItem = GetToolProxyItem
function getToolProxyItemHook( toolUuid )
	local item = oldGetToolProxyItem( toolUuid )
	if not item then
		item = ToolItems[tostring( toolUuid )]
	end

	return item
end
GetToolProxyItem = getToolProxyItemHook

if _GetToolProxyItem then
	local oldGetToolProxyItem2 = _GetToolProxyItem
	function getToolProxyItemHook2( toolUuid )
		local item = oldGetToolProxyItem2( toolUuid )
		if not item then
			item = ToolItems[tostring( toolUuid )]
		end

		return item
	end
	_GetToolProxyItem = getToolProxyItemHook2
end