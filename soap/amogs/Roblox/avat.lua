-- MULTRBX full-body avatar render script (runs inside RCCService)
-- Called as: return start(userId, baseUrl)

function start(userId, baseUrl)
    userId = tostring(userId)
    baseUrl = tostring(baseUrl or "http://mulrbx.com")

    -- Ensure trailing slash is not required; ContentProvider needs the site root
    if string.sub(baseUrl, -1) == "/" then
        baseUrl = string.sub(baseUrl, 1, -2)
    end

    local ContentProvider = game:GetService("ContentProvider")
    ContentProvider:SetBaseUrl(baseUrl)

    pcall(function()
        game:GetService("ScriptContext").ScriptsDisabled = true
    end)

    -- Appearance URL must return semicolon-separated asset URLs (BodyColors + clothing + gear)
    local appearanceUrl = baseUrl .. "/Tools/FetchCharacterAppeareance.aspx?id=" .. userId

    local plr = game.Players:CreateLocalPlayer(0)
    plr.CharacterAppearance = appearanceUrl

    local ok, err = pcall(function()
        plr:LoadCharacter(false)
    end)
    if not ok then
        -- Fallback: still try to thumbnail whatever is there
        warn("LoadCharacter failed: " .. tostring(err))
    end

    -- Give a moment for assets to resolve if needed
    wait(0.5)

    local ThumbnailGenerator = game:GetService("ThumbnailGenerator")
    -- PNG, width, height, hide sky
    return ThumbnailGenerator:Click("PNG", 768, 768, true)
end
