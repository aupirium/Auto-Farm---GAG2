local GENV = getgenv()
local queuedAutoExec = GENV.GG2_FromAutoExec == true
local bootKey = tostring(game.JobId) .. '@' .. tostring(game.PlaceId)
local bootNow = os.clock()

if queuedAutoExec then
    if GENV.GG2_BootKey == bootKey and (GENV.GG2_AutoFarmRunning or GENV.GG2_Library) then
        return
    end
    if GENV.GG2_BootKey == bootKey
        and type(GENV.GG2_LastBootAt) == 'number'
        and (bootNow - GENV.GG2_LastBootAt) < 12 then
        return
    end
end

if identifyexecutor then
    local ok, executorName = pcall(function()
        return select(1, identifyexecutor())
    end)
    if ok and table.find({ 'Wave', 'Seliware', 'Volt' }, executorName) then
        GENV.setthreadidentity = nil
    end
end

if GENV.GG2_AutoFarmShutdown and not (queuedAutoExec and GENV.GG2_AutoFarmRunning and GENV.GG2_BootKey == bootKey) then
    pcall(GENV.GG2_AutoFarmShutdown)
    task.wait(0.05)
end

if not queuedAutoExec then
    GENV.GG2_SkipRemoteUpdate = nil
    GENV.GG2_FromAutoExec = nil
end

GENV.GG2_BootKey = bootKey
GENV.GG2_LastBootAt = bootNow

local REPO = 'aupirium/Auto-Farm---GAG2'
local SCRIPT_FILE = 'gag2.lua'
local SCRIPT_PATH = 'GG2/gag2.lua'
local COMMIT_FILE = 'GG2/commit.txt'
local LEGACY_SCRIPT_PATHS = {
    'grow_garden_autofarm.lua',
    'GG2/grow_garden_autofarm.lua',
}

local function gg2RawUrl(scriptName, commit)
    return string.format('https://raw.githubusercontent.com/%s/%s/%s', REPO, commit or 'main', scriptName)
end

local function getScriptReadPaths()
    local paths = { SCRIPT_FILE, SCRIPT_PATH }
    for _, legacyPath in LEGACY_SCRIPT_PATHS do
        table.insert(paths, legacyPath)
    end
    return paths
end

local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
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

local function getCommit()
    local commit = 'main'

    local ok, html = pcall(function()
        return game:HttpGet('https://github.com/' .. REPO, true)
    end)

    if ok and type(html) == 'string' then
        local idx = html:find('currentOid')
        if idx then
            local hash = html:sub(idx + 13, idx + 52)
            if hash and #hash == 40 then
                commit = hash
            end
        end
    end

    return commit
end

local function downloadScript(commit)
    local url = gg2RawUrl(SCRIPT_FILE, commit)

    local ok, source = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not ok or type(source) ~= 'string' or source == '' or source == '404: Not Found' then
        return nil, url
    end

    return stripBom(source), url
end

if type(writefile) ~= 'function' and not queuedAutoExec then
    error('Grow a Garden 2 Auto Farm needs writefile support')
end

if makefolder and type(writefile) == 'function' and (not isfolder or not isfolder('GG2')) then
    makefolder('GG2')
end

local commit = getCommit()
local oldCommit = isfile(COMMIT_FILE) and readfile(COMMIT_FILE):gsub('%s+', '') or ''
commit = commit:gsub('%s+', '')
if type(writefile) == 'function' and oldCommit ~= commit then
    pcall(function()
        writefile(COMMIT_FILE, commit)
    end)
end

GENV.GG2_ScriptUrl = gg2RawUrl(SCRIPT_FILE, commit)

local source, triedUrl = downloadScript(commit)
if not source and commit ~= 'main' then
    source, triedUrl = downloadScript('main')
end

if not source then
    for _, path in getScriptReadPaths() do
        if isfile(path) then
            local ok, cached = pcall(readfile, path)
            if ok and type(cached) == 'string' and cached ~= '' then
                source = stripBom(cached)
                break
            end
        end
    end
end

if not source then
    error('Failed to download script from GitHub (' .. tostring(triedUrl) .. ')')
end

if type(writefile) == 'function' then
    writefile(SCRIPT_PATH, source)
    writefile(SCRIPT_FILE, source)
end

GENV.GG2_SkipRemoteUpdate = true
if queuedAutoExec then
    GENV.GG2_FromAutoExec = true
end

local func, err = (loadstring or load)(source, SCRIPT_FILE)
if syn and syn.loadstring and not func then
    func, err = syn.loadstring(source, SCRIPT_FILE)
end
if not func then
    error('Failed to load script: ' .. tostring(err))
end

func()
