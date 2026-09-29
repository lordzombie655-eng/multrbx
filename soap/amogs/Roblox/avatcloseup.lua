-- MULTRBX close-up (headshot) avatar render script
-- Called as: return start(userId, baseUrl)

function start(userId, baseUrl)
    userId = tostring(userId)
    baseUrl = tostring(baseUrl or "http://mulrbx.com")

    if string.sub(baseUrl, -1) == "/" then
        baseUrl = string.sub(baseUrl, 1, -2)
    end

    local ContentProvider = game:GetService("ContentProvider")
    ContentProvider:SetBaseUrl(baseUrl)

    pcall(function()
        game:GetService("ScriptContext").ScriptsDisabled = true
    end)

    local appearanceUrl = baseUrl .. "/Tools/FetchCharacterAppeareance.aspx?id=" .. userId

    local plr = game.Players:CreateLocalPlayer(0)
    plr.CharacterAppearance = appearanceUrl

    pcall(function()
        plr:LoadCharacter(false)
    end)

    wait(0.5)

    -- Closer crop for headshot-style
    local ThumbnailGenerator = game:GetService("ThumbnailGenerator")
    return ThumbnailGenerator:Click("PNG", 420, 420, true)
end
