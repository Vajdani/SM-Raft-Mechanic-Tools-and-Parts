LanguageManager = class()

local fallbackLanguage = sm.json.open("$CONTENT_DATA/Gui/Language/English/tags.json")
local noTagFound = "nil"

function language_tag(name)
    local path = "$CONTENT_DATA/Gui/Language/"..sm.gui.getCurrentLanguage().."/tags.json"
    if not sm.json.fileExists(path) then return fallbackLanguage[name] or noTagFound end

    local tags = sm.json.open(path)
    if not tags then return fallbackLanguage[name] or noTagFound end

    local textInJson = tags[name]

    --try to find tag in the fallback language
    if textInJson == nil then
        textInJson = fallbackLanguage[name]
    end

    --return a fallback tag if its still nil somehow
    return textInJson or noTagFound
end