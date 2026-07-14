-- Grow a Garden 2 Auto Farm loader
-- Users run: loadstring(game:HttpGet('https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/loader.lua'))()

local GENV = getgenv()
GENV.GG2_AutoFarmRunning = nil
GENV.GG2_SkipRemoteUpdate = nil

local SCRIPT_URL = 'https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/grow_garden_autofarm.lua'
GENV.GG2_ScriptUrl = SCRIPT_URL

local function httpGet(url)
    local req = (syn and syn.request)
        or http_request
        or request
        or (fluxus and fluxus.request)

    if req then
        local ok, res = pcall(function()
            return req({
                Url = url,
                Method = 'GET',
            })
        end)
        if ok and res and res.Body and (not res.StatusCode or res.StatusCode == 200) then
            return res.Body
        end
    end

    return game:HttpGet(url)
end

local function stripBom(source)
    if type(source) ~= 'string' or source == '' then
        return source
    end

    while source:byte(1) == 0xEF and source:byte(2) == 0xBB and source:byte(3) == 0xBF do
        source = source:sub(4)
    end

    return source
end

if type(writefile) ~= 'function' then
    error('Grow a Garden 2 Auto Farm needs writefile support')
end

local ok, source = pcall(function()
    return httpGet(SCRIPT_URL .. '?t=' .. tostring(os.time()))
end)

if not ok or type(source) ~= 'string' or source == '' or source:find('404: Not Found', 1, true) then
    error('Failed to download script from GitHub')
end

source = stripBom(source)

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
