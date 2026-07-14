-- Grow a Garden 2 Auto Farm loader
-- Users run: loadstring(game:HttpGet('https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/main/loader.lua'))()

local GENV = getgenv()
GENV.GG2_AutoFarmRunning = nil
GENV.GG2_SkipRemoteUpdate = nil

local SCRIPT_URLS = {
    'https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/main/gag2.lua',
    'https://cdn.jsdelivr.net/gh/aupirium/Auto-Farm---GAG2@main/gag2.lua',
}
GENV.GG2_ScriptUrl = SCRIPT_URLS[1]

local HttpService = game:GetService('HttpService')

local function stripBom(source)
    if type(source) ~= 'string' or source == '' then
        return source
    end

    while source:byte(1) == 0xEF and source:byte(2) == 0xBB and source:byte(3) == 0xBF do
        source = source:sub(4)
    end

    return source
end

local function isBadBody(body)
    return type(body) ~= 'string'
        or body == ''
        or body:find('404: Not Found', 1, true)
        or body:find('404 Not Found', 1, true)
end

local function tryRequest(url)
    local req = (syn and syn.request)
        or http_request
        or request
        or (fluxus and fluxus.request)

    if not req then
        return nil
    end

    local ok, res = pcall(function()
        return req({
            Url = url,
            Method = 'GET',
        })
    end)

    if not ok or not res then
        return nil
    end

    local body = res.Body or res.body
    local code = res.StatusCode or res.Status or res.status

    if isBadBody(body) or (code and code ~= 200) then
        return nil
    end

    return body
end

local function tryHttpService(url)
    local ok, body = pcall(function()
        return HttpService:GetAsync(url, true)
    end)

    if ok and not isBadBody(body) then
        return body
    end

    return nil
end

local function tryHttpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)

    if ok and not isBadBody(body) then
        return body
    end

    return nil
end

local function downloadScript()
    local lastErr = 'no response'

    for _, baseUrl in SCRIPT_URLS do
        local urls = { baseUrl, baseUrl .. '?t=' .. tostring(os.time()) }

        for _, url in urls do
            local body = tryRequest(url)
                or tryHttpService(url)
                or tryHttpGet(url)

            if body then
                return stripBom(body)
            end
        end

        lastErr = 'failed: ' .. baseUrl
    end

    for _, path in { 'grow_garden_autofarm.lua', 'GG2/grow_garden_autofarm.lua' } do
        local ok, cached = pcall(function()
            return readfile(path)
        end)
        if ok and type(cached) == 'string' and cached ~= '' then
            return stripBom(cached), 'cached'
        end
    end

    return nil, lastErr
end

if type(writefile) ~= 'function' then
    error('Grow a Garden 2 Auto Farm needs writefile support')
end

local source, downloadInfo = downloadScript()
if not source then
    error('Failed to download script from GitHub (' .. tostring(downloadInfo) .. ')')
end

pcall(function()
    if makefolder and (not isfolder or not isfolder('GG2')) then
        makefolder('GG2')
    end
    writefile('GG2/grow_garden_autofarm.lua', source)
    writefile('grow_garden_autofarm.lua', source)
end)

GENV.GG2_SkipRemoteUpdate = true

local func, err = loadstring(source, 'grow_garden_autofarm.lua')
if not func then
    error('Failed to load script: ' .. tostring(err))
end

func()
