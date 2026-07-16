local GENV = getgenv()

if GENV.GG2_AutoFarmShutdown then
    pcall(GENV.GG2_AutoFarmShutdown)
    task.wait(0.05)
end

if GENV.GG2_FromAutoExec then
    GENV.GG2_AutoFarmRunning = nil
end

if identifyexecutor then
    local ok, executorName = pcall(function()
        return select(1, identifyexecutor())
    end)
    if ok and table.find({ 'Wave', 'Seliware', 'Volt' }, executorName) then
        GENV.setthreadidentity = nil
    end
end

if GENV.GG2_AutoFarmRunning then
    return
end

GENV.GG2_AutoFarmRunning = true

repeat task.wait() until game:IsLoaded()

local Players = game:GetService('Players')
if not Players.LocalPlayer then
    Players.PlayerAdded:Wait()
end
local LocalPlayer = Players.LocalPlayer

local GG2_REPO = 'aupirium/Auto-Farm---GAG2'
local AUTO_FARM_SCRIPT = 'gag2.lua'
local GG2_SCRIPT_PATH = 'GG2/gag2.lua'
local GG2_LOADER_SCRIPT = 'loader.lua'
local GG2_LOADER_PATH = 'GG2/loader.lua'
local GG2_AUTOEXEC_PATHS = {
    GG2_LOADER_SCRIPT,
    GG2_LOADER_PATH,
    'workspace/' .. GG2_LOADER_SCRIPT,
}
local GG2_COMMIT_FILE = 'GG2/commit.txt'
local GG2_AUTOEXEC_FILE = 'GG2/rejoin.lua'
local GG2_TARGET_PLANT_FILE = 'GG2/target_plant.txt'
local GG2_HARVEST_PLANTS_FILE = 'GG2/harvest_plants.txt'
local GG2_CONFIG_FOLDER = 'GrowGarden2AutoFarm'
local LEGACY_SCRIPT_PATHS = {
    'GG2/grow_garden_autofarm.lua',
    'grow_garden_autofarm.lua',
    'workspace/grow_garden_autofarm.lua',
    'scripts/grow_garden_autofarm.lua',
}

local function gg2RawUrl(scriptName, commit)
    return string.format('https://raw.githubusercontent.com/%s/%s/%s', GG2_REPO, commit or 'main', scriptName)
end

local function gg2RepoUrl()
    return 'https://github.com/' .. GG2_REPO
end

local function getScriptReadPaths()
    local paths = {
        GG2_SCRIPT_PATH,
        AUTO_FARM_SCRIPT,
        'workspace/' .. AUTO_FARM_SCRIPT,
        'scripts/' .. AUTO_FARM_SCRIPT,
    }

    for _, legacyPath in LEGACY_SCRIPT_PATHS do
        table.insert(paths, legacyPath)
    end

    return paths
end

local DEFAULT_REMOTE_SCRIPT_URL = gg2RawUrl(AUTO_FARM_SCRIPT, 'main')
local REMOTE_SCRIPT_URL = (type(GENV.GG2_ScriptUrl) == 'string' and GENV.GG2_ScriptUrl ~= '')
    and GENV.GG2_ScriptUrl
    or DEFAULT_REMOTE_SCRIPT_URL

if not GENV.GG2_SkipRemoteUpdate and not GENV.GG2_FromAutoExec and type(writefile) == 'function' and REMOTE_SCRIPT_URL ~= '' then
    local function stripBomEarly(source)
        if type(source) ~= 'string' or source == '' then
            return source
        end

        while source:byte(1) == 0xEF and source:byte(2) == 0xBB and source:byte(3) == 0xBF do
            source = source:sub(4)
        end

        return source
    end

    local function httpGetEarly(url)
        local ok, body = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok and body and body ~= '' and body ~= '404: Not Found' then
            return body
        end

        return nil
    end

    local function getCommitEarly()
        local commit = 'main'
        local ok, html = pcall(function()
            return game:HttpGet(gg2RepoUrl(), true)
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

    local commit = getCommitEarly()
    local remote = httpGetEarly(gg2RawUrl(AUTO_FARM_SCRIPT, commit))
    if not remote then
        remote = httpGetEarly(gg2RawUrl(AUTO_FARM_SCRIPT, 'main'))
    end

    if remote then
        remote = stripBomEarly(remote)
        local localSrc = nil

        for _, path in getScriptReadPaths() do
            local readOk, content = pcall(function()
                return readfile(path)
            end)
            if readOk and type(content) == 'string' and content ~= '' then
                localSrc = stripBomEarly(content)
                break
            end
        end

        pcall(function()
            if makefolder and (not isfolder or not isfolder('GG2')) then
                makefolder('GG2')
            end
            writefile(GG2_SCRIPT_PATH, remote)
            writefile(AUTO_FARM_SCRIPT, remote)
        end)

        if localSrc and localSrc ~= remote then
            GENV.GG2_SkipRemoteUpdate = true
            if GENV.GG2_AutoFarmShutdown then
                pcall(GENV.GG2_AutoFarmShutdown)
                task.wait(0.05)
            end
            GENV.GG2_AutoFarmRunning = false
            local func = loadstring(remote, AUTO_FARM_SCRIPT)
            if func then
                func()
                return
            end
            GENV.GG2_AutoFarmRunning = true
        end
    end
end

local SESSION_ID = (tonumber(GENV.GG2_SessionId) or 0) + 1
GENV.GG2_SessionId = SESSION_ID

function isActiveSession()
    return GENV.GG2_SessionId == SESSION_ID and Library and not Library.Unloaded
end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CollectionService = game:GetService('CollectionService')
local TeleportService = game:GetService('TeleportService')
local GuiService = game:GetService('GuiService')
local VirtualUser = game:GetService('VirtualUser')

local PlayerScripts = LocalPlayer:WaitForChild('PlayerScripts')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Gardens = workspace:WaitForChild('Gardens')
local WeatherValues = ReplicatedStorage:WaitForChild('WeatherValues')
local StockValues = ReplicatedStorage:WaitForChild('StockValues')
local Lighting = game:GetService('Lighting')
local SoundService = game:GetService('SoundService')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')

local EVENT_WEATHERS = {
    'Lightning',
    'Rainbow',
    'Snowfall',
    'Starfall',
    'Aurora',
    'Sunburst',
    'Eclipse',
}

local NIGHT_MOON_GAME_NAMES = {
    Goldmoon = true,
    ['Rainbow Moon'] = true,
    Bloodmoon = true,
    ['Mega Moon'] = true,
}

local NIGHT_MOON_LABELS = {
    Goldmoon = 'Gold',
    Bloodmoon = 'Blood',
    ['Mega Moon'] = 'Mega',
    ['Rainbow Moon'] = 'Rainbow',
}

local BLOCKABLE_WEATHERS = {
    'Lightning',
    'Rainbow',
    'Snowfall',
    'Starfall',
    'Aurora',
    'Sunburst',
    'Eclipse',
    'Gold',
    'Blood',
    'Mega',
}

local WEATHER_STATE_FILE = 'GG2_WeatherState.json'
local GG2_PLACE_ID = 97598239454123

isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

isfolder = isfolder or function(path)
    local ok, files = pcall(listfiles, path)
    return ok and type(files) == 'table'
end

makefolder = makefolder or function() end

function stripBom(source)
    if type(source) ~= 'string' or source == '' then
        return source
    end

    while source:byte(1) == 0xEF and source:byte(2) == 0xBB and source:byte(3) == 0xBF do
        source = source:sub(4)
    end

    if source:sub(1, 1) == '\239\187\191' then
        source = source:sub(4)
    end

    return source
end

function ensureGg2Folders()
    pcall(function()
        if not isfolder('GG2') then
            makefolder('GG2')
        end
    end)
end

function ensureCommitFile()
    if not writefile then
        return false
    end

    ensureGg2Folders()
    local commit = getRemoteCommit()
    return pcall(function()
        writefile(GG2_COMMIT_FILE, commit:gsub('%s+', ''))
    end)
end

function readCommitFile()
    if not readfile then
        return 'main'
    end

    local ok, raw = pcall(readfile, GG2_COMMIT_FILE)
    if ok and type(raw) == 'string' then
        local commit = raw:gsub('%s+', '')
        if commit ~= '' then
            return commit
        end
    end

    return 'main'
end

function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and body and body ~= '' and body ~= '404: Not Found' then
        return body
    end
    return nil
end

function getRemoteCommit()
    local commit = 'main'
    local ok, html = pcall(function()
        return game:HttpGet(gg2RepoUrl(), true)
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

function fetchRemoteScriptSource()
    local commit = getRemoteCommit()
    local urls = {
        gg2RawUrl(AUTO_FARM_SCRIPT, commit),
        gg2RawUrl(AUTO_FARM_SCRIPT, 'main'),
    }

    for _, url in urls do
        local ok, body = pcall(function()
            return httpGet(url)
        end)
        if ok and type(body) == 'string' and body ~= '' and body ~= '404: Not Found' then
            return stripBom(body)
        end
    end

    return nil
end

function writeScriptToWorkspace(source)
    if not writefile or type(source) ~= 'string' or source == '' then
        return false
    end

    ensureGg2Folders()
    local cleaned = stripBom(source)

    return pcall(function()
        writefile(GG2_SCRIPT_PATH, cleaned)
        writefile(AUTO_FARM_SCRIPT, cleaned)
    end)
end

function syncWorkspaceFromRemote()
    local remote = fetchRemoteScriptSource()
    if not remote then
        return false, 'fetch_failed'
    end

    local localSource = nil
    for _, path in getScriptReadPaths() do
        if isfile(path) then
            local ok, source = pcall(readfile, path)
            if ok and source and source ~= '' then
                localSource = stripBom(source)
                break
            end
        end
    end

    if localSource == remote then
        return true, 'latest'
    end

    if writeScriptToWorkspace(remote) then
        return true, 'updated'
    end

    return false, 'write_failed'
end

function persistAutoFarmScript()
    if not writefile then
        return false
    end

    ensureGg2Folders()

    for _, path in getScriptReadPaths() do
        if isfile(path) then
            local ok, source = pcall(readfile, path)
            if ok and source and source ~= '' then
                local cleaned = stripBom(source)
                pcall(function()
                    writefile(GG2_SCRIPT_PATH, cleaned)
                    writefile(AUTO_FARM_SCRIPT, cleaned)
                end)
                return true
            end
        end
    end

    return false
end

function persistLoaderScript()
    if not writefile then
        return false
    end

    ensureGg2Folders()

    for _, path in GG2_AUTOEXEC_PATHS do
        if isfile(path) then
            local ok, source = pcall(readfile, path)
            if ok and type(source) == 'string' and source ~= '' then
                local cleaned = stripBom(source)
                pcall(function()
                    writefile(GG2_LOADER_PATH, cleaned)
                    writefile(GG2_LOADER_SCRIPT, cleaned)
                end)
                return true
            end
        end
    end

    local remote = httpGet(gg2RawUrl(GG2_LOADER_SCRIPT, 'main'))
    if remote then
        remote = stripBom(remote)
        pcall(function()
            writefile(GG2_LOADER_PATH, remote)
            writefile(GG2_LOADER_SCRIPT, remote)
        end)
        return true
    end

    return false
end

function tryUpdateFromRemote()
    if GENV.GG2_SkipRemoteUpdate or GENV.GG2_FromAutoExec then
        return false, 'skipped'
    end

    return syncWorkspaceFromRemote()
end

function saveConfigBeforeTeleport()
    pcall(function()
        captureConfigTargetPlant()
        captureConfigHarvestPlants()

        if not SaveManager or not isfile then
            return
        end

        local autoloadPath = GG2_CONFIG_FOLDER .. '/settings/autoload.txt'
        if isfile(autoloadPath) then
            local name = readfile(autoloadPath):gsub('%s+', '')
            if name ~= '' then
                SaveManager:Save(name)
            end
        end
    end)
end

local HttpService
pcall(function()
    HttpService = game:GetService('HttpService')
end)

function encodeWeatherState(data)
    if HttpService then
        return HttpService:JSONEncode(data)
    end

    return string.format(
        '%s|%s|%s|%s|%s',
        tostring(data.Hiding),
        tostring(data.ReturnJobId or ''),
        tostring(data.ReturnPlaceId or ''),
        tostring(data.HideUntil or 0),
        tostring(data.HidingFromWeather or '')
    )
end

function decodeWeatherState(raw)
    if not raw or raw == '' then
        return nil
    end

    if HttpService then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if ok and typeof(decoded) == 'table' then
            return decoded
        end
    end

    local hiding, returnJobId, returnPlaceId, hideUntil, hidingFromWeather = raw:match('([^|]+)|([^|]*)|([^|]*)|([^|]*)|(.*)')
    if not hiding then
        return nil
    end

    return {
        Hiding = hiding == 'true',
        ReturnJobId = returnJobId ~= '' and returnJobId or nil,
        ReturnPlaceId = tonumber(returnPlaceId),
        HideUntil = tonumber(hideUntil) or 0,
        HidingFromWeather = hidingFromWeather ~= '' and hidingFromWeather or nil,
    }
end

function readWeatherStateFile()
    if not (readfile and isfile and isfile(WEATHER_STATE_FILE)) then
        return nil
    end

    local ok, raw = pcall(readfile, WEATHER_STATE_FILE)
    if not ok then
        return nil
    end

    return decodeWeatherState(raw)
end

function writeWeatherStateFile(data)
    if not writefile then
        return false
    end

    local ok = pcall(function()
        writefile(WEATHER_STATE_FILE, encodeWeatherState(data))
    end)

    return ok
end

function clearWeatherStateFile()
    if delfile and isfile and isfile(WEATHER_STATE_FILE) then
        pcall(delfile, WEATHER_STATE_FILE)
    end
end

local Networking = require(ReplicatedStorage.SharedModules.Networking)
local SprinklerData = require(ReplicatedStorage.SharedModules.SprinklerData)
local GearShopData = require(ReplicatedStorage.SharedModules.GearShopData)
local SeedData = require(ReplicatedStorage.SharedModules.SeedData)
local SellValueData = require(ReplicatedStorage.SharedModules.SellValueData)
local MutationData = require(ReplicatedStorage.SharedModules.MutationData)
local AuctioneerModule = require(ReplicatedStorage.SharedModules.Auctioneer)
local AuctioneerFlags = require(ReplicatedStorage.SharedModules.Flags.AuctioneerFlags)

local GardenSync = require(PlayerScripts.Controllers.GardenSyncController)
local FruitVisualizer = require(PlayerScripts.Controllers.FruitVisualizerController)

local HarvestedFruitHandleController
pcall(function()
    HarvestedFruitHandleController = require(PlayerScripts.Controllers.HarvestedFruitHandleController)
end)

local NumberUtils
pcall(function()
    NumberUtils = require(ReplicatedStorage.SharedModules.NumberUtils)
end)

local PlayerStateClient
local MailboxItemCatalog

function loadMailModules()
    if PlayerStateClient and MailboxItemCatalog then
        return true
    end

    local ok, err = pcall(function()
        PlayerStateClient = require(ReplicatedStorage.ClientModules.PlayerStateClient)
        MailboxItemCatalog = require(PlayerScripts.Controllers.MailboxController.MailboxItemCatalog)
    end)

    return ok, err
end

function getReplica()
    local ok = loadMailModules()
    if not ok then
        return nil
    end
    return PlayerStateClient:GetLocalReplica() or PlayerStateClient:WaitForLocalReplica(5)
end

local BUY_GEARS = {}
local BUY_SEEDS = {}
local BUY_PROPS = {}
local GearPrices = {}
local SeedPrices = {}

local function isShecklesGearEntry(entry)
    if entry.ItemType == 'PetTeleporter' then
        return false
    end

    if type(entry.Cost) ~= 'number' or entry.Cost <= 0 then
        return false
    end

    return true
end

for _, entry in GearShopData.Data do
    if isShecklesGearEntry(entry) then
        GearPrices[entry.ItemName] = entry.Cost
        table.insert(BUY_GEARS, entry.ItemName)
    end
end

for _, entry in SeedData do
    if entry.SeedName and entry.RestockShop ~= false then
        table.insert(BUY_SEEDS, entry.SeedName)
        SeedPrices[entry.SeedName] = entry.PurchasePrice
    end
end

pcall(function()
    local items = StockValues:WaitForChild('CrateShop'):WaitForChild('Items')
    for _, item in items:GetChildren() do
        table.insert(BUY_PROPS, item.Name)
    end
end)

table.sort(BUY_GEARS)
table.sort(BUY_SEEDS)
table.sort(BUY_PROPS)

local AUCTION_SEEDS = {}
local AUCTION_GEARS = {}
local AUCTION_SEED_PACKS = {}
local AUCTION_EGGS = {}

function appendUniqueName(list, seen, value)
    if type(value) ~= 'string' or value == '' or seen[value] then
        return
    end

    seen[value] = true
    table.insert(list, value)
end

function collectNamesFromDataTable(data, nameFields, list, seen)
    if type(data) ~= 'table' then
        return
    end

    local function readEntry(entry)
        if type(entry) == 'string' then
            appendUniqueName(list, seen, entry)
            return
        end

        if type(entry) ~= 'table' then
            return
        end

        for _, field in nameFields do
            appendUniqueName(list, seen, entry[field])
        end
    end

    if data[1] ~= nil then
        for _, entry in data do
            readEntry(entry)
        end
    end
end

function tryCollectAuctionNamesFromModule(moduleName, nameFields, list, seen)
    local sharedModules = ReplicatedStorage:FindFirstChild('SharedModules')
    local mod = sharedModules and sharedModules:FindFirstChild(moduleName)
    if not mod or not mod:IsA('ModuleScript') then
        return false
    end

    local ok, data = pcall(require, mod)
    if not ok or type(data) ~= 'table' then
        return false
    end

    local before = #list
    if type(data.Data) == 'table' then
        pcall(collectNamesFromDataTable, data.Data, nameFields, list, seen)
    end

    return #list > before
end

function buildAuctionItemLists()
    local seeds, seenSeeds = {}, {}
    for _, entry in SeedData do
        appendUniqueName(seeds, seenSeeds, entry.SeedName)
    end
    table.sort(seeds)

    local gears = {}
    for _, name in BUY_GEARS do
        table.insert(gears, name)
    end

    local seedPacks, seenPacks = {}, {}
    local eggs, seenEggs = {}, {}

    for _, moduleName in {
        'SeedPackData',
        'SeedPacksData',
        'PackData',
        'PacksData',
        'SeedPackShopData',
    } do
        pcall(tryCollectAuctionNamesFromModule, moduleName, {
            'PackName',
            'SeedPackName',
            'ItemName',
            'Name',
            'DisplayName',
        }, seedPacks, seenPacks)
    end

    for _, moduleName in {
        'EggData',
        'EggsData',
        'PetEggData',
        'PetEggsData',
        'EggShopData',
    } do
        pcall(tryCollectAuctionNamesFromModule, moduleName, {
            'EggName',
            'ItemName',
            'Name',
            'DisplayName',
        }, eggs, seenEggs)
    end

    pcall(function()
        local exclusiveShop = StockValues:FindFirstChild('ExclusiveShop')
        local items = exclusiveShop and exclusiveShop:FindFirstChild('Items')
        if not items then
            return
        end

        for _, item in items:GetChildren() do
            local lower = item.Name:lower()
            if string.find(lower, 'egg') then
                appendUniqueName(eggs, seenEggs, item.Name)
            elseif string.find(lower, 'seedpack') or string.find(lower, ' pack') or string.find(lower, 'pack ') then
                appendUniqueName(seedPacks, seenPacks, item.Name)
            end
        end
    end)

    table.sort(seedPacks)
    table.sort(eggs)

    return seeds, gears, seedPacks, eggs
end

local buildAuctionOk, buildSeeds, buildGears, buildPacks, buildEggs = pcall(buildAuctionItemLists)
if buildAuctionOk then
    AUCTION_SEEDS, AUCTION_GEARS, AUCTION_SEED_PACKS, AUCTION_EGGS = buildSeeds, buildGears, buildPacks, buildEggs
else
    AUCTION_SEEDS, AUCTION_GEARS, AUCTION_SEED_PACKS, AUCTION_EGGS = {}, {}, {}, {}
    local fallbackSeen = {}
    for _, entry in SeedData do
        appendUniqueName(AUCTION_SEEDS, fallbackSeen, entry.SeedName)
    end
    for _, name in BUY_GEARS do
        table.insert(AUCTION_GEARS, name)
    end
    table.sort(AUCTION_SEEDS)
end

local SUPER_SPRINKLER = 'Super Sprinkler'
local SUPER_CAN = 'Super Watering Can'

local sprinklerLifetime = 120
local sprinklerRadius = 55

for _, entry in SprinklerData do
    if entry.SprinklerName == SUPER_SPRINKLER then
        sprinklerLifetime = entry.Lifetime or sprinklerLifetime
        sprinklerRadius = entry.Radius or sprinklerRadius
        break
    end
end

local State = {
    LastSprinklerPlace = 0,
    LastWatering = 0,
    LastSell = 0,
    EarningsWindow = {},
    HarvestConnection = nil,
    HarvestThread = nil,
    WateringConnection = nil,
    WateringStop = false,
    WateringBusy = false,
    GearWalkBusy = false,
    ConfigTargetPlant = nil,
    ConfigHarvestPlants = nil,
    LastGearWalkAttempt = 0,
    SprinklerPlacePending = false,
    WeatherHiding = false,
    ReturnJobId = nil,
    ReturnPlaceId = nil,
    HideUntil = 0,
    HidingFromWeather = nil,
    PendingWalkBack = false,
    ReturnPosX = nil,
    ReturnPosY = nil,
    ReturnPosZ = nil,
    PendingWalkToSaved = false,
    StartupWalkDone = false,
    AutoExecTeleportConnection = nil,
    WeatherMonitorStop = false,
    WeatherMonitorThread = nil,
    WeatherErrorReconnectConnection = nil,
    WeatherLeavePending = false,
    WeatherReconnectPending = false,
    WeatherKickPending = false,
    WeatherReconnectAttempts = 0,
    LastWeatherReconnectAttempt = 0,
    LastKickReconnectAttempt = 0,
    LastWeatherLeaveAttempt = 0,
    AutoBuyThread = nil,
    AutoBuyTracker = {},
    AutoAuctionThread = nil,
    AutoHatchThread = nil,
    EggHatchPending = false,
    EggHatchTimes = {},
    AuctionLots = {},
    AuctionStock = {},
    AuctionPurchaseTimes = {},
    AuctionPurchaseCooldowns = {},
    AuctionLastSnapshot = 0,
    AuctionNetworkingReady = false,
    AuctionItemLists = {
        Seeds = AUCTION_SEEDS,
        Gears = AUCTION_GEARS,
        SeedPacks = AUCTION_SEED_PACKS,
        Eggs = AUCTION_EGGS,
    },
    MailAutoClaimStop = false,
    MailAutoClaimThread = nil,
    MailTotals = { Claimed = 0, Failed = 0 },
    OptimizerEnabled = false,
    OptimizerOriginal = nil,
    OptimizerApplyToken = 0,
    OptimizerWorldScanThread = nil,
    OptimizerWorldDescendantConnection = nil,
    OptimizerGardenChildConnection = nil,
    OptimizerPlotIdConnection = nil,
    OptimizerLightingOriginal = nil,
    OptimizerFpsUnlocked = false,
    OptimizerPendingApply = nil,
    OptimizerPartCache = {},
    OptimizerEnforceConnections = {},
    OptimizerMeshCache = {},
    HarvestWeightCache = setmetatable({}, { __mode = 'k' }),
    CameraBlackoutEnabled = false,
    CameraBlackoutOriginalType = nil,
    CameraBlackoutCharacterConnection = nil,
    ConfigLoading = false,
    AntiAfkConnection = nil,
    AutoSellThread = nil,
    LastHarvest = 0,
    GardenFruits = {},
    FruitLabelMap = {},
    LoadingDismissThread = nil,
    RemoteSyncStatus = nil,
}

function isLoadingScreenBlocking()
    return LocalPlayer:GetAttribute('LoadingScreenDone') ~= true
end

function tryDismissLoadingScreen()
    if LocalPlayer:GetAttribute('LoadingScreenDone') == true then
        return true
    end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new())
    end)

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    if type(keypress) == 'function' then
        pcall(keypress, 0x20)
        pcall(keypress, 0x0D)
    end

    if type(mouse1click) == 'function' then
        pcall(mouse1click)
    end

    if type(firesignal) == 'function' then
        pcall(function()
            firesignal(UserInputService.InputBegan, {
                UserInputType = Enum.UserInputType.Keyboard,
                KeyCode = Enum.KeyCode.Space,
            }, false)
        end)
        pcall(function()
            firesignal(UserInputService.InputBegan, {
                UserInputType = Enum.UserInputType.MouseButton1,
            }, false)
        end)
    end

    return LocalPlayer:GetAttribute('LoadingScreenDone') == true
end

function waitForLoadingScreenDismiss(timeout)
    timeout = timeout or 120
    local deadline = os.clock() + timeout

    while os.clock() < deadline and not Library.Unloaded do
        if LocalPlayer:GetAttribute('LoadingScreenDone') == true then
            return true
        end

        tryDismissLoadingScreen()
        task.wait(0.35)
    end

    return LocalPlayer:GetAttribute('LoadingScreenDone') == true
end

function startLoadingScreenAutoDismiss()
    if State.LoadingDismissThread then
        return
    end

    State.LoadingDismissThread = task.spawn(function()
        waitForLoadingScreenDismiss(180)
        State.LoadingDismissThread = nil
    end)
end

function isLocalPlayerDescendant(inst)
    local char = LocalPlayer.Character
    if not char or not inst then
        return false
    end

    return inst == char or inst:IsDescendantOf(char)
end

function optimizerSafeSet(obj, prop, value)
    pcall(function()
        obj[prop] = value
    end)
end

function isPlantInstance(inst)
    local current = inst
    while current and current ~= workspace do
        if current.Name == 'Plants' and current.Parent and current.Parent.Parent == Gardens then
            return true
        end
        current = current.Parent
    end
    return false
end

function isCharacterPart(part)
    local model = part.Parent
    while model do
        if model:IsA('Model') and model:FindFirstChildOfClass('Humanoid') then
            return true
        end
        model = model.Parent
    end
    return false
end

--[[
    Matched to the high-FPS reference clip (~160-195 FPS): empty dirt beds,
    night sky, other gardens gone, FPS unlocked past 60. Plant models are
    kept (stripped visually) so auto-harvest can still read ripe/weight
    attributes and fire CollectFruit remotes.
]]
local OPTIMIZER_DESTROY_CLASSES = {
    ParticleEmitter = true,
    Beam = true,
    Trail = true,
    Fire = true,
    Smoke = true,
    Sparkles = true,
    Highlight = true,
    PointLight = true,
    SpotLight = true,
    SurfaceLight = true,
    Decal = true,
    Texture = true,
}

local OPTIMIZER_SKY_ASSET = 'rbxassetid://136622198885324'
local OPTIMIZER_SKY_NAME = 'GG2OptimizerNightSky'

-- Workspace folders that are pure visual clutter (safe to wipe client-side).
local OPTIMIZER_WORLD_DELETE_NAMES = {
    NPCS = true,
    NPCs = true,
    Npcs = true,
    Effects = true,
    FX = true,
    VFX = true,
    Debris = true,
    Pets = true,
    Animals = true,
}

function watchOptimizerEnforcement(inst, prop, offValue, extra)
    local ok, signal = pcall(function()
        return inst:GetPropertyChangedSignal(prop)
    end)
    if not ok or not signal then
        return
    end

    local connection = signal:Connect(function()
        if not State.OptimizerEnabled then
            return
        end
        pcall(function()
            if inst[prop] ~= offValue then
                inst[prop] = offValue
            end
        end)
        if extra then
            pcall(extra)
        end
    end)

    State.OptimizerEnforceConnections[#State.OptimizerEnforceConnections + 1] = connection
end

function unlockOptimizerFps()
    -- Reference clip hits ~195 FPS - Roblox stays capped at 60 without this.
    pcall(function()
        if setfpscap then
            setfpscap(10000)
        end
    end)
    pcall(function()
        if syn and syn.set_fps_cap then
            syn.set_fps_cap(10000)
        end
    end)
    pcall(function()
        if set_fps_cap then
            set_fps_cap(10000)
        end
    end)
    pcall(function()
        if setfflag then
            setfflag('DFIntTaskSchedulerTargetFps', '10000')
        end
    end)
    State.OptimizerFpsUnlocked = true
end

function applyOptimizerLighting()
    if not State.OptimizerLightingOriginal then
        State.OptimizerLightingOriginal = {
            Brightness = Lighting.Brightness,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            ExposureCompensation = Lighting.ExposureCompensation,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            GlobalShadows = Lighting.GlobalShadows,
            ClockTime = Lighting.ClockTime,
            GeographicLatitude = Lighting.GeographicLatitude,
        }
    end

    for _, child in Lighting:GetChildren() do
        if child:IsA('Sky') or child:IsA('BloomEffect') or child:IsA('BlurEffect')
            or child:IsA('ColorCorrectionEffect') or child:IsA('SunRaysEffect')
            or child:IsA('DepthOfFieldEffect') or child:IsA('Atmosphere') then
            pcall(function()
                child:Destroy()
            end)
        end
    end

    local sky = Instance.new('Sky')
    sky.Name = OPTIMIZER_SKY_NAME
    sky.SkyboxBk = OPTIMIZER_SKY_ASSET
    sky.SkyboxDn = OPTIMIZER_SKY_ASSET
    sky.SkyboxFt = OPTIMIZER_SKY_ASSET
    sky.SkyboxLf = OPTIMIZER_SKY_ASSET
    sky.SkyboxRt = OPTIMIZER_SKY_ASSET
    sky.SkyboxUp = OPTIMIZER_SKY_ASSET
    sky.SunAngularSize = 0
    sky.MoonAngularSize = 0
    sky.Parent = Lighting

    Lighting.Brightness = 0
    Lighting.ExposureCompensation = -0.5
    Lighting.Ambient = Color3.fromRGB(80, 80, 95)
    Lighting.OutdoorAmbient = Color3.fromRGB(60, 60, 70)
    Lighting.FogEnd = 1e6
    Lighting.GlobalShadows = false
    Lighting.ClockTime = 0
    Lighting.GeographicLatitude = 41.75

    pcall(function()
        local renderSettings = settings():GetService('Rendering')
        if renderSettings then
            renderSettings.QualityLevel = Enum.QualityLevel.Level01
            if renderSettings.MeshPartDetailLevel ~= nil then
                renderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
            end
        end
    end)

    pcall(function()
        local ugs = UserSettings():GetService('UserGameSettings')
        if ugs then
            ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        end
    end)
end

function restoreOptimizerLighting()
    local sky = Lighting:FindFirstChild(OPTIMIZER_SKY_NAME)
    if sky then
        pcall(function()
            sky:Destroy()
        end)
    end

    local o = State.OptimizerLightingOriginal
    if o then
        for prop, val in o do
            pcall(function()
                Lighting[prop] = val
            end)
        end
    end
    State.OptimizerLightingOriginal = nil
end

function deleteOtherPlayersGardens()
    local ownPlot = getPlot()
    if not ownPlot then
        return false
    end

    for _, plot in Gardens:GetChildren() do
        if plot ~= ownPlot then
            pcall(function()
                plot:Destroy()
            end)
        end
    end

    return true
end

--[[
    Reference clip shows empty dirt beds. We used to :Destroy() plant models,
    but that kills auto-harvest: ripe/weight live on model attributes, and
    shouldHarvestFruit rejects nil weight. Instead keep the Model shells
    (attributes + hierarchy) and strip every visual descendant so nothing
    renders - harvest remotes still see PlantId/FruitId/IsRipe/Weight.
]]
function stripPlantVisualInstance(inst)
    if not inst or not inst.Parent then
        return
    end

    if State.OptimizerPartCache[inst] then
        return
    end

    local className = inst.ClassName
    if OPTIMIZER_DESTROY_CLASSES[className] or className == 'SpecialMesh' then
        State.OptimizerPartCache[inst] = true
        pcall(function()
            inst:Destroy()
        end)
        return
    end

    if inst:IsA('BasePart') then
        local cache = {
            Transparency = inst.Transparency,
            LocalTransparencyModifier = inst.LocalTransparencyModifier,
            CanCollide = inst.CanCollide,
            CastShadow = inst.CastShadow,
            Material = inst.Material,
        }

        inst.Transparency = 1
        inst.LocalTransparencyModifier = 1
        inst.CanCollide = false
        inst.CastShadow = false
        inst.Material = Enum.Material.SmoothPlastic

        if inst:IsA('MeshPart') then
            local meshOk, meshId = pcall(function()
                return inst.MeshId
            end)
            if meshOk then
                cache.MeshId = meshId
                pcall(function()
                    inst.MeshId = ''
                end)
            end
        end

        State.OptimizerPartCache[inst] = cache
        watchOptimizerEnforcement(inst, 'Transparency', 1)
        watchOptimizerEnforcement(inst, 'CanCollide', false)
        return
    end

    if className == 'ProximityPrompt' then
        State.OptimizerPartCache[inst] = { Enabled = inst.Enabled }
        inst.Enabled = false
        watchOptimizerEnforcement(inst, 'Enabled', false)
    end
end

function stripPlantVisuals(root)
    if not root or not root.Parent then
        return
    end

    stripPlantVisualInstance(root)
    for _, desc in root:GetDescendants() do
        stripPlantVisualInstance(desc)
    end
end

function clearOwnPlantModels()
    local ownPlot = getPlot()
    local plantsFolder = ownPlot and ownPlot:FindFirstChild('Plants')
    if not plantsFolder then
        return
    end

    for _, child in plantsFolder:GetChildren() do
        stripPlantVisuals(child)
    end
end

function deleteWorldClutter()
    for _, child in workspace:GetChildren() do
        if OPTIMIZER_WORLD_DELETE_NAMES[child.Name] then
            pcall(function()
                child:Destroy()
            end)
        end
    end

    -- Other players' characters still render otherwise.
    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                pcall(function()
                    char:Destroy()
                end)
            end
        end
    end
end

function isUnderOtherPlayersGarden(inst)
    local ownPlot = getPlot()
    if not ownPlot then
        return false
    end

    local current = inst
    while current and current ~= workspace do
        if current.Parent == Gardens then
            return current ~= ownPlot
        end
        current = current.Parent
    end

    return false
end

function optimizerHideInstance(inst)
    if not inst or not inst.Parent then
        return
    end

    if State.OptimizerPartCache[inst] then
        return
    end

    if isLocalPlayerDescendant(inst) then
        return
    end

    -- Other plots: wipe the whole plot, don't touch child-by-child.
    if isUnderOtherPlayersGarden(inst) then
        local plot = inst
        while plot and plot.Parent ~= Gardens do
            plot = plot.Parent
        end
        if plot and plot.Parent == Gardens and plot ~= getPlot() then
            pcall(function()
                plot:Destroy()
            end)
        end
        return
    end

    -- Own plants/fruits: strip this instance only (DescendantAdded already
    -- fires per child). Keep Model shells for harvest attributes.
    if isPlantInstance(inst) then
        stripPlantVisualInstance(inst)
        return
    end

    local className = inst.ClassName

    if OPTIMIZER_DESTROY_CLASSES[className] then
        pcall(function()
            inst:Destroy()
        end)
        return
    end

    if inst:IsA('BasePart') then
        if isCharacterPart(inst) and not isLocalPlayerDescendant(inst) then
            local model = inst
            while model and not (model:IsA('Model') and model:FindFirstChildOfClass('Humanoid')) do
                model = model.Parent
            end
            if model and model ~= LocalPlayer.Character then
                pcall(function()
                    model:Destroy()
                end)
            end
            return
        end

        local cache = {
            Material = inst.Material,
            CastShadow = inst.CastShadow,
        }
        inst.Material = Enum.Material.SmoothPlastic
        inst.CastShadow = false

        State.OptimizerPartCache[inst] = cache
    end
end

function scanOptimizerWorld(applyToken)
    deleteOtherPlayersGardens()
    clearOwnPlantModels()
    deleteWorldClutter()

    local descendants = workspace:GetDescendants()
    for i = 1, #descendants do
        if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
            return false
        end

        optimizerHideInstance(descendants[i])

        if i % 1500 == 0 then
            RunService.Heartbeat:Wait()
        end
    end

    return true
end

function cleanupOptimizerLegacyCosmetics()
    local character = LocalPlayer.Character
    if character then
        local rootPart = character:FindFirstChild('HumanoidRootPart')
        if rootPart then
            local glow = rootPart:FindFirstChild('ZLocalGlow')
            if glow then
                glow:Destroy()
            end
        end
    end

    local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
    if playerGui then
        local hud = playerGui:FindFirstChild('ZombieHUD')
        if hud then
            hud:Destroy()
        end
    end
end

function applyWorldOptimizer()
    unlockOptimizerFps()
    applyOptimizerLighting()

    local terrain = workspace:FindFirstChildOfClass('Terrain') or workspace.Terrain

    local terrainDecoration
    pcall(function()
        terrainDecoration = terrain and terrain.Decoration
    end)

    State.OptimizerOriginal = {
        TerrainDecoration = terrainDecoration,
        WaterWaveSize = terrain and terrain.WaterWaveSize,
        WaterWaveSpeed = terrain and terrain.WaterWaveSpeed,
        WaterReflectance = terrain and terrain.WaterReflectance,
    }

    if terrain then
        optimizerSafeSet(terrain, 'Decoration', false)
        optimizerSafeSet(terrain, 'WaterWaveSize', 0)
        optimizerSafeSet(terrain, 'WaterWaveSpeed', 0)
        optimizerSafeSet(terrain, 'WaterReflectance', 0)
    end
end

function stopOptimizerGardenWatchers()
    if State.OptimizerGardenChildConnection then
        State.OptimizerGardenChildConnection:Disconnect()
        State.OptimizerGardenChildConnection = nil
    end

    if State.OptimizerPlotIdConnection then
        State.OptimizerPlotIdConnection:Disconnect()
        State.OptimizerPlotIdConnection = nil
    end
end

function startWorldOptimizerMaintenance(applyToken)
    if State.OptimizerWorldScanThread then
        pcall(task.cancel, State.OptimizerWorldScanThread)
        State.OptimizerWorldScanThread = nil
    end

    if State.OptimizerWorldDescendantConnection then
        State.OptimizerWorldDescendantConnection:Disconnect()
        State.OptimizerWorldDescendantConnection = nil
    end

    stopOptimizerGardenWatchers()
    cleanupOptimizerLegacyCosmetics()

    State.OptimizerGardenChildConnection = Gardens.ChildAdded:Connect(function(plot)
        if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
            return
        end

        local ownPlot = getPlot()
        if ownPlot and plot ~= ownPlot then
            pcall(function()
                plot:Destroy()
            end)
        end
    end)

    State.OptimizerPlotIdConnection = LocalPlayer:GetAttributeChangedSignal('PlotId'):Connect(function()
        if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
            return
        end
        deleteOtherPlayersGardens()
        clearOwnPlantModels()
    end)

    -- Other players respawning / streaming back in.
    local playerConn = Players.PlayerAdded:Connect(function(player)
        if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
            return
        end
        player.CharacterAdded:Connect(function(char)
            if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
                return
            end
            if player ~= LocalPlayer then
                pcall(function()
                    char:Destroy()
                end)
            end
        end)
    end)
    State.OptimizerEnforceConnections[#State.OptimizerEnforceConnections + 1] = playerConn

    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer then
            local conn = player.CharacterAdded:Connect(function(char)
                if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
                    return
                end
                pcall(function()
                    char:Destroy()
                end)
            end)
            State.OptimizerEnforceConnections[#State.OptimizerEnforceConnections + 1] = conn
        end
    end

    State.OptimizerWorldDescendantConnection = workspace.DescendantAdded:Connect(function(desc)
        if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
            return
        end

        optimizerHideInstance(desc)
    end)

    State.OptimizerWorldScanThread = task.spawn(function()
        local deadline = os.clock() + 30
        while not getPlot() and os.clock() < deadline do
            if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
                return
            end
            task.wait(0.25)
        end

        if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
            return
        end

        scanOptimizerWorld(applyToken)

        if applyToken == State.OptimizerApplyToken and State.OptimizerEnabled then
            State.OptimizerWorldScanThread = nil
        end
    end)
end

function restoreWorldOptimizer()
    if State.OptimizerWorldDescendantConnection then
        State.OptimizerWorldDescendantConnection:Disconnect()
        State.OptimizerWorldDescendantConnection = nil
    end

    if State.OptimizerWorldScanThread then
        pcall(task.cancel, State.OptimizerWorldScanThread)
        State.OptimizerWorldScanThread = nil
    end

    stopOptimizerGardenWatchers()
    restoreOptimizerLighting()

    if State.OptimizerOriginal then
        local o = State.OptimizerOriginal

        pcall(function()
            local terrain = workspace:FindFirstChildOfClass('Terrain') or workspace.Terrain
            if terrain then
                if o.TerrainDecoration ~= nil then
                    terrain.Decoration = o.TerrainDecoration
                end
                if o.WaterWaveSize ~= nil then
                    terrain.WaterWaveSize = o.WaterWaveSize
                end
                if o.WaterWaveSpeed ~= nil then
                    terrain.WaterWaveSpeed = o.WaterWaveSpeed
                end
                if o.WaterReflectance ~= nil then
                    terrain.WaterReflectance = o.WaterReflectance
                end
            end
        end)
    end
end

function restoreOptimizer()
    restoreWorldOptimizer()

    for _, connection in State.OptimizerEnforceConnections do
        pcall(function()
            connection:Disconnect()
        end)
    end
    State.OptimizerEnforceConnections = {}

    for inst, props in State.OptimizerPartCache do
        if inst and inst.Parent and typeof(props) == 'table' then
            for prop, val in props do
                pcall(function()
                    inst[prop] = val
                end)
            end
        end
    end

    State.OptimizerEnabled = false
    State.OptimizerOriginal = nil
    State.OptimizerPartCache = {}
    State.OptimizerFpsUnlocked = false
end

function cancelOptimizerPendingApply()
    if State.OptimizerPendingApply then
        pcall(task.cancel, State.OptimizerPendingApply)
        State.OptimizerPendingApply = nil
    end
end

function scheduleOptimizerApply()
    cancelOptimizerPendingApply()

    State.OptimizerPendingApply = task.spawn(function()
        waitForLoadingScreenDismiss(180)

        if Library.Unloaded or not Toggles.Optimizer or not Toggles.Optimizer.Value then
            State.OptimizerPendingApply = nil
            return
        end

        State.OptimizerPendingApply = nil
        setOptimizer(true)
    end)
end

function setOptimizer(enabled)
    enabled = enabled == true

    if enabled and State.OptimizerEnabled then
        return
    end

    if not enabled and not State.OptimizerEnabled then
        return
    end

    State.OptimizerApplyToken += 1
    local applyToken = State.OptimizerApplyToken

    if not enabled then
        cancelOptimizerPendingApply()
        restoreOptimizer()
        return
    end

    State.OptimizerEnabled = true
    applyWorldOptimizer()
    startWorldOptimizerMaintenance(applyToken)
end

local CAMERA_BLACKOUT_OFFSET = 1000000000000

--[[
    Max-FPS "blackout" mode: yanks the camera far below the map (Scriptable,
    so nothing keeps snapping it back to the character every frame) and
    blanks every MeshId in the workspace so the client doesn't even have
    geometry to load/render. Nothing is visible on screen while this is on -
    it's meant for pure AFK farming, not for watching the game.
]]
function applyCameraBlackoutMeshes()
    local descendants = workspace:GetDescendants()
    for i = 1, #descendants do
        local inst = descendants[i]
        if inst:IsA('MeshPart') or inst:IsA('SpecialMesh') then
            local ok, meshId = pcall(function()
                return inst.MeshId
            end)
            if ok and meshId ~= '' and State.OptimizerMeshCache[inst] == nil then
                State.OptimizerMeshCache[inst] = meshId
                pcall(function()
                    inst.MeshId = ''
                end)
            end
        end

        if i % 1000 == 0 then
            RunService.Heartbeat:Wait()
        end
    end
end

function applyCameraBlackoutView()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    if not State.CameraBlackoutOriginalType then
        State.CameraBlackoutOriginalType = camera.CameraType
    end

    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = camera.CFrame + Vector3.new(0, -CAMERA_BLACKOUT_OFFSET, 0)
end

function restoreCameraBlackoutView()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    camera.CameraType = State.CameraBlackoutOriginalType or Enum.CameraType.Custom
    State.CameraBlackoutOriginalType = nil

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild('HumanoidRootPart')
    if root then
        pcall(function()
            camera.CFrame = CFrame.new(root.Position + Vector3.new(0, 8, 12), root.Position)
        end)
    end
end

function restoreCameraBlackoutMeshes()
    for inst, meshId in State.OptimizerMeshCache do
        if inst and inst.Parent then
            pcall(function()
                inst.MeshId = meshId
            end)
        end
    end
    State.OptimizerMeshCache = {}
end

function setCameraBlackout(enabled)
    enabled = enabled == true

    if enabled and State.CameraBlackoutEnabled then
        return
    end
    if not enabled and not State.CameraBlackoutEnabled then
        return
    end

    if not enabled then
        State.CameraBlackoutEnabled = false

        if State.CameraBlackoutCharacterConnection then
            State.CameraBlackoutCharacterConnection:Disconnect()
            State.CameraBlackoutCharacterConnection = nil
        end

        restoreCameraBlackoutView()
        restoreCameraBlackoutMeshes()
        return
    end

    State.CameraBlackoutEnabled = true
    applyCameraBlackoutMeshes()
    applyCameraBlackoutView()

    if State.CameraBlackoutCharacterConnection then
        State.CameraBlackoutCharacterConnection:Disconnect()
    end
    State.CameraBlackoutCharacterConnection = LocalPlayer.CharacterAdded:Connect(function()
        if not State.CameraBlackoutEnabled then
            return
        end
        task.defer(applyCameraBlackoutView)
    end)
end

function abbreviate(n)
    if NumberUtils and NumberUtils.Abbreviate then
        return NumberUtils.Abbreviate(n) .. '?'
    end
    return tostring(math.floor(n)) .. '?'
end

function resolveRecipientId(input)
    local trimmed = tostring(input or ''):gsub('^%s*(.-)%s*$', '%1')
    if trimmed == '' then
        return nil, 'Enter a username or UserId'
    end

    local asNumber = tonumber(trimmed)
    if asNumber then
        return asNumber
    end

    local ok, userId = pcall(function()
        return Networking.Mailbox.LookupPlayer:Fire(trimmed)
    end)
    if ok and typeof(userId) == 'number' and userId > 0 then
        return userId
    end

    local lower = trimmed:lower()
    for _, player in Players:GetPlayers() do
        if player.Name:lower() == lower or player.DisplayName:lower() == lower then
            return player.UserId
        end
    end

    return nil, 'Player not found'
end

function isGiftableEntry(category, key, value)
    if typeof(value) == 'number' then
        return value > 0
    end

    if typeof(value) == 'table' and value.Id ~= nil then
        if value.Equipped == true then
            return false
        end
        return true
    end

    return false
end

function getGiftableInventory()
    local ok = loadMailModules()
    if not ok then
        return {}
    end

    local replica = getReplica()
    if not replica then
        return {}
    end

    local inventory = replica.Data and replica.Data.Inventory
    if typeof(inventory) ~= 'table' then
        return {}
    end

    local items = {}
    local function displayCategoryName(name)
        if name == 'HarvestedFruits' then
            return 'Fruits'
        end
        if name == 'WateringCans' then
            return 'Cans'
        end
        return name
    end

    local categories = {}
    local seenCategory = {}

    local defaultCategories = MailboxItemCatalog and MailboxItemCatalog.Categories
    if typeof(defaultCategories) == 'table' then
        for _, c in ipairs(defaultCategories) do
            if typeof(c) == 'string' and not seenCategory[c] then
                seenCategory[c] = true
                table.insert(categories, c)
            end
        end
    end

    for categoryName in inventory do
        if typeof(categoryName) == 'string' and not seenCategory[categoryName] then
            seenCategory[categoryName] = true
            table.insert(categories, categoryName)
        end
    end

    table.sort(categories)

    for _, category in ipairs(categories) do
        local tab = inventory[category]
        if typeof(tab) == 'table' then
            for key, value in tab do
                if isGiftableEntry(category, key, value) then
                    local count = typeof(value) == 'number' and value or 1
                    table.insert(items, {
                        category = category,
                        key = tostring(key),
                        count = count,
                        label = string.format('%s / %s (%d)', displayCategoryName(category), tostring(key), count),
                    })
                end
            end
        end
    end

    pcall(function()
        local backpack = LocalPlayer:FindFirstChild('Backpack')
        local character = LocalPlayer.Character

        for _, container in { backpack, character } do
            if container then
                for _, tool in container:GetChildren() do
                    if tool:IsA('Tool') and tool:GetAttribute('HarvestedFruit') == true then
                        local id = tool:GetAttribute('Id')
                        local fruitName = tool:GetAttribute('FruitName') or tool:GetAttribute('Fruit') or tool.Name
                        local weight = tool:GetAttribute('Weight')
                        local label = fruitName
                        if typeof(weight) == 'number' then
                            label = string.format('%s (%.2fkg)', tostring(fruitName), weight)
                        end

                        table.insert(items, {
                            category = 'HarvestedFruits',
                            key = typeof(id) == 'string' and id or tool.Name,
                            count = 1,
                            label = string.format('%s / %s', displayCategoryName('HarvestedFruits'), label),
                        })
                    end
                end
            end
        end
    end)

    table.sort(items, function(a, b)
        if a.category == b.category then
            return a.key < b.key
        end
        return a.category < b.category
    end)

    return items
end

function getInbox()
    local ok2, inbox = pcall(function()
        return Networking.Mailbox.OpenInbox:Fire()
    end)

    if not ok2 or typeof(inbox) ~= 'table' then
        return nil, inbox
    end

    return inbox
end

function claimGift(giftId, maxRetries)
    maxRetries = tonumber(maxRetries) or 2

    for attempt = 1, maxRetries do
        local ok, success, errMsg = pcall(function()
            return Networking.Mailbox.Claim:Fire(giftId)
        end)

        if ok and success then
            return true
        end

        if attempt < maxRetries then
            task.wait(0.5)
        else
            return false, errMsg
        end
    end

    return false
end

function claimAllInbox(onProgress, claimDelay, maxRetries)
    local inbox, err = getInbox()
    if not inbox then
        return 0, err
    end

    local ids = {}
    for giftId in inbox do
        table.insert(ids, giftId)
    end
    table.sort(ids)

    local claimed = 0

    for i, giftId in ipairs(ids) do
        if State.MailAutoClaimStop then
            break
        end

        local entry = inbox[giftId]
        local fromName = typeof(entry) == 'table' and entry.FromName or 'Unknown'
        local ok = claimGift(giftId, maxRetries)

        if ok then
            claimed += 1
            State.MailTotals.Claimed += 1
        else
            State.MailTotals.Failed += 1
        end

        if onProgress then
            pcall(onProgress, i, #ids, fromName, ok)
        end

        task.wait(claimDelay or 0.35)
    end

    return claimed
end

function sendGiftBatch(recipientId, item, amount, note)
    if not item then
        return false, 'Select an item'
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then
        return false, 'Amount must be greater than 0'
    end
    if amount > (item.count or 0) then
        return false, string.format('You only have %d', item.count or 0)
    end

    local batch = {
        {
            Category = item.category,
            ItemKey = item.key,
            Count = amount,
        },
    }

    local ok, success, message = pcall(function()
        return Networking.Mailbox.SendBatch:Fire(recipientId, batch, note or '')
    end)

    if not ok then
        return false, tostring(success)
    end
    if not success then
        return false, (message ~= '' and message) or 'Send failed'
    end

    return true, (message ~= '' and message) or 'Gift sent'
end

function getCharacter()
    return LocalPlayer.Character
end

function walkToPosition(targetPos, timeout)
    local char = getCharacter() or LocalPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild('Humanoid', 10)
    local root = char:WaitForChild('HumanoidRootPart', 10)
    if not humanoid or not root then
        return false
    end

    timeout = timeout or 90
    local deadline = os.clock() + timeout

    while os.clock() < deadline do
        if (root.Position - targetPos).Magnitude <= 6 then
            return true
        end

        humanoid:MoveTo(targetPos)
        local finished = false
        local reached = false
        local conn = humanoid.MoveToFinished:Connect(function(success)
            finished = true
            reached = success
        end)

        local waitUntil = os.clock() + 4
        while os.clock() < waitUntil and not finished do
            if (root.Position - targetPos).Magnitude <= 6 then
                conn:Disconnect()
                return true
            end
            task.wait(0.1)
        end

        conn:Disconnect()

        if reached and (root.Position - targetPos).Magnitude <= 8 then
            return true
        end

        task.wait(0.15)
    end

    return (root.Position - targetPos).Magnitude <= 10
end

function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass('Humanoid')
end

function getPlot()
    local plotId = LocalPlayer:GetAttribute('PlotId')
    if plotId then
        return Gardens:FindFirstChild('Plot' .. plotId)
    end
    return nil
end

function getPlotIdNumber(plot)
    return tonumber(plot.Name:match('%d+'))
end

function findTool(attribute, value)
    for _, container in { LocalPlayer:FindFirstChild('Backpack'), getCharacter() } do
        if container then
            for _, child in container:GetChildren() do
                if child:IsA('Tool') and child:GetAttribute(attribute) == value then
                    return child
                end
            end
        end
    end
    return nil
end

function equipTool(tool)
    if not tool then
        return false
    end

    local humanoid = getHumanoid()
    if not humanoid then
        return false
    end

    if tool.Parent ~= getCharacter() then
        humanoid:EquipTool(tool)
        task.wait(0.15)
    end

    return getCharacter() and getCharacter():FindFirstChild(tool.Name) ~= nil
end

function getPlotPlantsFolder()
    local plot = getPlot()
    return plot and plot:FindFirstChild('Plants')
end

function getGardenPlantTypes()
    local types = {}
    local seen = {}

    local garden = GardenSync:GetGarden(LocalPlayer.UserId)
    if typeof(garden) ~= 'table' then
        return types
    end

    for _, plant in garden do
        local name = plant and plant.PlantName
        if type(name) == 'string' and name ~= '' and not seen[name] then
            seen[name] = true
            table.insert(types, name)
        end
    end

    table.sort(types)
    return types
end

function findPlantModelById(plantsFolder, plantId)
    if not plantsFolder or not plantId then
        return nil
    end

    plantId = tostring(plantId)

    for _, model in plantsFolder:GetChildren() do
        local attr = model:GetAttribute('PlantId')
        if attr and tostring(attr) == plantId then
            return model
        end
        if string.find(model.Name, plantId, 1, true) then
            return model
        end
    end

    return nil
end

function waitForGardenReady(timeout)
    timeout = timeout or 60
    local deadline = os.clock() + timeout

    while os.clock() < deadline do
        local plot = getPlot()
        local plants = plot and plot:FindFirstChild('Plants')
        local garden = GardenSync:GetGarden(LocalPlayer.UserId)

        if plants and typeof(garden) == 'table' and next(garden) ~= nil then
            return true
        end

        task.wait(0.25)
    end

    return false
end

function getPlantModelsByType(plantName)
    local models = {}
    if type(plantName) ~= 'string' or plantName == '' or plantName == 'None' then
        return models
    end

    local plantsFolder = getPlotPlantsFolder()
    if not plantsFolder then
        return models
    end

    local garden = GardenSync:GetGarden(LocalPlayer.UserId)
    if typeof(garden) ~= 'table' then
        return models
    end

    for plantId, plant in garden do
        if plant and plant.PlantName == plantName then
            local model = findPlantModelById(plantsFolder, plantId)
            if model then
                table.insert(models, model)
            end
        end
    end

    return models
end

function getClusterCenter(positions)
    if #positions == 0 then
        return nil
    end

    local sumX, sumY, sumZ = 0, 0, 0
    for _, pos in positions do
        sumX += pos.X
        sumY += pos.Y
        sumZ += pos.Z
    end

    local count = #positions
    return Vector3.new(sumX / count, sumY / count, sumZ / count)
end

function getSelectedTargetPlant()
    if State.ConfigTargetPlant and State.ConfigTargetPlant ~= 'None' then
        return State.ConfigTargetPlant
    end

    if not Options or not Options.TargetPlant then
        return nil
    end

    local plantName = Options.TargetPlant.Value
    if type(plantName) ~= 'string' or plantName == '' or plantName == 'None' then
        return nil
    end

    return plantName
end

function saveTargetPlantFile(plantName)
    if not writefile then
        return
    end

    ensureGg2Folders()
    pcall(function()
        writefile(GG2_TARGET_PLANT_FILE, plantName or '')
    end)
end

function readTargetPlantFromAutoloadConfig()
    if not readfile or not isfile or not HttpService then
        return nil
    end

    local autoloadPath = GG2_CONFIG_FOLDER .. '/settings/autoload.txt'
    if not isfile(autoloadPath) then
        return nil
    end

    local configName = readfile(autoloadPath):gsub('%s+', '')
    if configName == '' then
        return nil
    end

    local configPath = GG2_CONFIG_FOLDER .. '/settings/' .. configName .. '.json'
    if not isfile(configPath) then
        return nil
    end

    local ok, raw = pcall(readfile, configPath)
    if not ok or type(raw) ~= 'string' or raw == '' then
        return nil
    end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not decodeOk or type(data) ~= 'table' then
        return nil
    end

    for _, obj in data.objects or {} do
        if obj.idx == 'TargetPlant'
            and type(obj.value) == 'string'
            and obj.value ~= ''
            and obj.value ~= 'None' then
            return obj.value
        end
    end

    return nil
end

function loadConfigTargetPlant()
    local plantName = nil

    if isfile and readfile and isfile(GG2_TARGET_PLANT_FILE) then
        local ok, raw = pcall(readfile, GG2_TARGET_PLANT_FILE)
        if ok and type(raw) == 'string' then
            local trimmed = raw:gsub('^%s+', ''):gsub('%s+$', '')
            if trimmed ~= '' and trimmed ~= 'None' then
                plantName = trimmed
            end
        end
    end

    if not plantName then
        plantName = readTargetPlantFromAutoloadConfig()
    end

    if plantName then
        State.ConfigTargetPlant = plantName
        saveTargetPlantFile(plantName)
    end

    return plantName
end

function applyTargetPlantToDropdown(plantName)
    if not plantName or plantName == '' or plantName == 'None' then
        return false
    end

    if not Options or not Options.TargetPlant then
        State.ConfigTargetPlant = plantName
        return true
    end

    local values = { 'None' }
    local seen = { None = true }

    for _, name in getGardenPlantTypes() do
        if not seen[name] then
            seen[name] = true
            table.insert(values, name)
        end
    end

    if not seen[plantName] then
        table.insert(values, plantName)
    end

    Options.TargetPlant:SetValues(values)
    Options.TargetPlant:SetValue(plantName)
    State.ConfigTargetPlant = plantName
    return true
end

function syncTargetPlantFromSavedConfig()
    local plantName = loadConfigTargetPlant()
    if plantName then
        applyTargetPlantToDropdown(plantName)
    end
    return plantName
end

function captureConfigTargetPlant()
    if not Options or not Options.TargetPlant then
        return
    end

    local plantName = Options.TargetPlant.Value
    if type(plantName) == 'string' and plantName ~= '' and plantName ~= 'None' then
        State.ConfigTargetPlant = plantName
        saveTargetPlantFile(plantName)
    end
end

function getGearTargetPosition()
    local plantName = getSelectedTargetPlant()
    if plantName then
        local positions = {}
        for _, model in getPlantModelsByType(plantName) do
            table.insert(positions, model:GetPivot().Position)
        end

        local center = getClusterCenter(positions)
        if center then
            return center
        end
    end

    return nil
end

function refreshTargetPlantDropdown()
    if not Options or not Options.TargetPlant then
        return
    end

    if not State.ConfigTargetPlant or State.ConfigTargetPlant == 'None' then
        loadConfigTargetPlant()
    end

    local preferred = State.ConfigTargetPlant
    if not preferred or preferred == 'None' then
        local current = Options.TargetPlant.Value
        if type(current) == 'string' and current ~= '' and current ~= 'None' then
            preferred = current
        end
    end

    local values = { 'None' }
    local seen = { None = true }

    for _, plantName in getGardenPlantTypes() do
        if not seen[plantName] then
            seen[plantName] = true
            table.insert(values, plantName)
        end
    end

    if preferred and preferred ~= 'None' and not seen[preferred] then
        table.insert(values, preferred)
    end

    Options.TargetPlant:SetValues(values)

    if preferred and preferred ~= 'None' and preferred ~= '' then
        Options.TargetPlant:SetValue(preferred)
        State.ConfigTargetPlant = preferred
        saveTargetPlantFile(preferred)
    else
        Options.TargetPlant:SetValue('None')
    end
end

function saveHarvestPlantsFile(names)
    if not writefile then
        return
    end

    ensureGg2Folders()
    pcall(function()
        writefile(GG2_HARVEST_PLANTS_FILE, table.concat(names or {}, '\n'))
    end)
end

function loadConfigHarvestPlants()
    local names = nil

    if isfile and readfile and isfile(GG2_HARVEST_PLANTS_FILE) then
        local ok, raw = pcall(readfile, GG2_HARVEST_PLANTS_FILE)
        if ok and type(raw) == 'string' then
            names = {}
            for line in raw:gmatch('[^\r\n]+') do
                local trimmed = line:gsub('^%s+', ''):gsub('%s+$', '')
                if trimmed ~= '' then
                    table.insert(names, trimmed)
                end
            end
        end
    end

    if names then
        State.ConfigHarvestPlants = names
    end

    return names
end

-- Returns nil only when the dropdown isn't ready yet (don't block harvest
-- during startup). Otherwise returns the exact checked set - an empty table
-- means "nothing checked" and correctly means harvest nothing.
function getSelectedHarvestPlantsSet()
    local selected = Options and Options.HarvestPlantTypes and Options.HarvestPlantTypes.Value
    if typeof(selected) ~= 'table' then
        return nil
    end

    local set = {}
    for label, isSelected in selected do
        if isSelected == true then
            set[label] = true
        end
    end

    return set
end

function applyHarvestPlantsToDropdown(names)
    if not Options or not Options.HarvestPlantTypes then
        State.ConfigHarvestPlants = names
        return
    end

    local values = {}
    local seen = {}
    for _, name in getGardenPlantTypes() do
        if not seen[name] then
            seen[name] = true
            table.insert(values, name)
        end
    end

    local selection = {}
    for _, name in names or {} do
        if not seen[name] then
            seen[name] = true
            table.insert(values, name)
        end
        selection[name] = true
    end

    Options.HarvestPlantTypes:SetValues(values)
    Options.HarvestPlantTypes:SetValue(selection)
    State.ConfigHarvestPlants = names
end

function syncHarvestPlantsFromSavedConfig()
    local names = loadConfigHarvestPlants()
    if names then
        applyHarvestPlantsToDropdown(names)
    end
    return names
end

function captureConfigHarvestPlants()
    if not Options or not Options.HarvestPlantTypes then
        return
    end

    local selected = Options.HarvestPlantTypes.Value
    if typeof(selected) ~= 'table' then
        return
    end

    local names = {}
    for label, isSelected in selected do
        if isSelected == true then
            table.insert(names, label)
        end
    end

    table.sort(names)
    State.ConfigHarvestPlants = names
    saveHarvestPlantsFile(names)
end

function refreshHarvestPlantsDropdown()
    if not Options or not Options.HarvestPlantTypes then
        return
    end

    local everConfigured = State.ConfigHarvestPlants ~= nil
    if not everConfigured then
        loadConfigHarvestPlants()
        everConfigured = State.ConfigHarvestPlants ~= nil
    end

    local preferred = {}
    for _, name in State.ConfigHarvestPlants or {} do
        preferred[name] = true
    end

    if not everConfigured then
        -- Never configured before (fresh install): default to every known
        -- plant type so Auto Harvest works normally out of the box. Once the
        -- user unchecks everything, that empty state is respected as-is.
        for _, name in getGardenPlantTypes() do
            preferred[name] = true
        end
    end

    local values = {}
    local seen = {}
    for _, name in getGardenPlantTypes() do
        if not seen[name] then
            seen[name] = true
            table.insert(values, name)
        end
    end

    local selection = {}
    local names = {}
    for name in pairs(preferred) do
        if not seen[name] then
            seen[name] = true
            table.insert(values, name)
        end
        selection[name] = true
        table.insert(names, name)
    end

    table.sort(names)
    Options.HarvestPlantTypes:SetValues(values)
    Options.HarvestPlantTypes:SetValue(selection)
    State.ConfigHarvestPlants = names
end

function ensureAtGearTarget()
    local targetPos = getGearTargetPosition()
    if not targetPos then
        return false
    end

    if not Toggles.AutoWalkToPlant or not Toggles.AutoWalkToPlant.Value then
        return true
    end

    if State.GearWalkBusy then
        return false
    end

    local char = getCharacter()
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root then
        return false
    end

    local standoff = 12
    local walkTarget = getOutsideWalkTarget(targetPos, standoff) or targetPos
    local flatDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(walkTarget.X, 0, walkTarget.Z)).Magnitude
    if flatDist <= 12 then
        return true
    end

    State.GearWalkBusy = true
    State.LastGearWalkAttempt = os.clock()
    walkNearPosition(targetPos, standoff)
    State.GearWalkBusy = false
    return true
end

function getPlacementPosition(savedPos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { Gardens }

    local origin = Vector3.new(savedPos.X, savedPos.Y + 50, savedPos.Z)
    local result = workspace:Raycast(origin, Vector3.new(0, -200, 0), params)

    if result and CollectionService:HasTag(result.Instance, 'PlantArea') then
        return result.Position
    end

    local plot = getPlot()
    if plot then
        local plotY = plot:GetPivot().Position.Y
        return Vector3.new(savedPos.X, plotY + 2.35, savedPos.Z)
    end

    return Vector3.new(savedPos.X, savedPos.Y, savedPos.Z)
end

function getActiveSuperSprinkler()
    if State.SprinklerPlacePending then
        return true, 'pending', nil, sprinklerLifetime
    end

    local sprinklers = GardenSync:GetSprinklers(LocalPlayer.UserId)
    local now = os.time()

    for sprinklerId, data in sprinklers do
        if data and data.SprinklerName == SUPER_SPRINKLER then
            local placedAt = tonumber(data.PlacedAt) or 0
            local remaining = sprinklerLifetime - (now - placedAt)
            if remaining > 0 then
                return true, sprinklerId, data, remaining
            end
        end
    end

    return false
end

function placeSuperSprinkler()
    local targetPos = getGearTargetPosition()
    if not targetPos then
        return false
    end

    if os.clock() - State.LastSprinklerPlace < 5 then
        return false
    end

    local active = getActiveSuperSprinkler()
    if active then
        return false
    end

    if not ensureAtGearTarget() then
        return false
    end

    local tool = findTool('Sprinkler', SUPER_SPRINKLER)
    if not tool then
        return false
    end

    local plot = getPlot()
    if not plot then
        return false
    end

    local plotId = getPlotIdNumber(plot)
    if not plotId then
        return false
    end

    if not equipTool(tool) then
        return false
    end

    local position = getPlacementPosition(targetPos)
    Networking.Place.PlaceSprinkler:Fire(position, SUPER_SPRINKLER, tool, plotId)
    State.LastSprinklerPlace = os.clock()
    State.SprinklerPlacePending = true
    task.delay(5, function()
        State.SprinklerPlacePending = false
    end)
    return true
end

function getWateringInterval()
    local seconds = tonumber(Options.WateringCanInterval and Options.WateringCanInterval.Value) or 10
    return math.clamp(seconds, 1, 300)
end

function useSuperWateringCan()
    local targetPos = getGearTargetPosition()
    if not targetPos or State.WateringBusy then
        return false
    end

    if not ensureAtGearTarget() then
        return false
    end

    local tool = findTool('WateringCan', SUPER_CAN)
    if not tool then
        return false
    end

    State.WateringBusy = true
    State.LastWatering = os.clock()

    local humanoid = getHumanoid()
    if humanoid and tool.Parent ~= getCharacter() then
        humanoid:EquipTool(tool)
        task.wait(0.05)
    end

    local position = getPlacementPosition(targetPos)
    Networking.WateringCan.UseWateringCan:Fire(position - Vector3.new(0, 0.3, 0), SUPER_CAN, tool)

    State.WateringBusy = false
    return true
end

function setAutoWateringLoop(enabled)
    State.WateringStop = true

    if State.WateringConnection then
        pcall(task.cancel, State.WateringConnection)
        State.WateringConnection = nil
    end

    if not enabled then
        return
    end

    State.WateringStop = false
    State.WateringConnection = task.spawn(function()
        while not State.WateringStop and not Library.Unloaded do
            if Toggles.AutoWateringCan and Toggles.AutoWateringCan.Value then
                useSuperWateringCan()
            end
            task.wait(getWateringInterval())
        end
    end)
end

function isFruitTool(tool)
    if not tool or not tool:IsA('Tool') then
        return false
    end

    if tool:GetAttribute('HarvestedFruit') == true then
        return true
    end

    return typeof(tool:GetAttribute('FruitName')) == 'string' and tool:GetAttribute('FruitName') ~= ''
end

function countHarvestedFruits()
    local fruitCount = tonumber(LocalPlayer:GetAttribute('FruitCount'))
    if fruitCount then
        return fruitCount
    end

    local count = 0
    for _, container in { LocalPlayer:FindFirstChild('Backpack'), getCharacter() } do
        if container then
            for _, child in container:GetChildren() do
                if isFruitTool(child) then
                    count += 1
                end
            end
        end
    end
    return count
end

function getInventoryCapacity()
    local maxCapacity = tonumber(LocalPlayer:GetAttribute('MaxFruitCapacity'))
    if maxCapacity then
        return maxCapacity
    end

    local upgrades = tonumber(LocalPlayer:GetAttribute('BackpackSpaceUpgradesPurchased')) or 0
    local skillData = LocalPlayer:FindFirstChild('SkillData')
    local maxBackpack = skillData and skillData:FindFirstChild('MaxBackpack')
    local skillLevel = maxBackpack and tonumber(maxBackpack.Value) or 1
    return math.max(1, 5 + upgrades + math.max(0, skillLevel - 1))
end

function isInventoryFull()
    return countHarvestedFruits() >= getInventoryCapacity()
end

function normalizeWeightKg(weight)
    weight = tonumber(weight)
    if not weight then
        return nil
    end

    if weight > 5000 then
        weight = weight / 1000
    end

    return weight
end

function getMaxHarvestKg()
    local maxKg = tonumber(Options and Options.MaxHarvestKg and Options.MaxHarvestKg.Value) or 50
    return math.clamp(maxKg, 0.01, 1000)
end

function getHarvestedFruitTools()
    local tools = {}

    for _, container in { LocalPlayer:FindFirstChild('Backpack'), getCharacter() } do
        if container then
            for _, tool in container:GetChildren() do
                if isFruitTool(tool) then
                    table.insert(tools, tool)
                end
            end
        end
    end

    return tools
end

function getFruitToolId(tool)
    for _, attr in { 'Id', 'FruitId', 'ItemId', 'UUID' } do
        local value = tool:GetAttribute(attr)
        if typeof(value) == 'string' and value ~= '' then
            return value
        end
    end

    local stringValue = tool:FindFirstChild('Id')
    if stringValue and stringValue:IsA('StringValue') and stringValue.Value ~= '' then
        return stringValue.Value
    end

    return nil
end

function getToolWeightKg(tool)
    local weight = tool:GetAttribute('Weight')
        or tool:GetAttribute('WeightKg')
        or tool:GetAttribute('FruitWeight')

    if not weight then
        local numberValue = tool:FindFirstChild('Weight')
        if numberValue and numberValue:IsA('NumberValue') then
            weight = numberValue.Value
        end
    end

    return normalizeWeightKg(weight)
end

function sellResultSucceeded(result)
    if result == nil then
        return false
    end

    if typeof(result) == 'table' then
        if result.Success == false then
            return false
        end
        if (tonumber(result.SoldCount) or 0) > 0 then
            return true
        end
        return result.Success == true or result.SellPrice ~= nil or result.Price ~= nil
    end

    return typeof(result) == 'number' and result > 0
end

function getSellEarnings(result, before)
    local earned = 0
    if typeof(result) == 'table' then
        earned = tonumber(result.SellPrice) or tonumber(result.Price) or 0
    elseif typeof(result) == 'number' then
        earned = result
    end

    if earned <= 0 and before then
        task.wait(0.25)
        local after = getSheckles()
        if after and after > before then
            earned = after - before
        end
    end

    return earned
end

function restoreTempFavorites(tempFavorited)
    for _, entry in tempFavorited do
        pcall(function()
            Networking.Backpack.SetFruitFavorite:Fire(entry.id, false)
        end)
        if entry.tool and entry.tool.Parent then
            entry.tool:SetAttribute('IsFavorite', false)
        end
    end
end

function hasAnyInventoryFruit()
    local fruitCount = tonumber(LocalPlayer:GetAttribute('FruitCount'))
    if fruitCount and fruitCount > 0 then
        return true
    end

    return #getHarvestedFruitTools() > 0
end

function tryAutoSell()
    if os.clock() - State.LastSell < 0.85 then
        return
    end

    if not hasAnyInventoryFruit() then
        return
    end

    local maxKg = getMaxHarvestKg()
    local tools = getHarvestedFruitTools()
    local tempFavorited = {}

    for _, tool in tools do
        if tool:GetAttribute('IsFavorite') then
            continue
        end

        local weight = getToolWeightKg(tool)
        if not weight or weight < maxKg then
            continue
        end

        local id = getFruitToolId(tool)
        if not id then
            continue
        end

        pcall(function()
            Networking.Backpack.SetFruitFavorite:Fire(id, true)
        end)
        tool:SetAttribute('IsFavorite', true)
        table.insert(tempFavorited, { id = id, tool = tool })
    end

    if #tempFavorited > 0 then
        task.wait(0.35)
    end

    local before = getSheckles()
    local ok, result = pcall(function()
        return Networking.NPCS.SellAll:Fire()
    end)

    State.LastSell = os.clock()

    if #tempFavorited > 0 then
        task.wait(0.2)
    end
    restoreTempFavorites(tempFavorited)

    if not ok then
        return
    end

    local earned = getSellEarnings(result, before)
    if sellResultSucceeded(result) or earned > 0 then
        pcall(function()
            if HarvestedFruitHandleController and HarvestedFruitHandleController.DisconnectAllFruitTools then
                HarvestedFruitHandleController:DisconnectAllFruitTools()
            end
        end)

        if earned > 0 then
            recordEarnings(earned)
        end
    end
end

function getSheckles()
    local leaderstats = LocalPlayer:FindFirstChild('leaderstats')
    local sheckles = leaderstats and leaderstats:FindFirstChild('Sheckles')
    return sheckles and tonumber(sheckles.Value) or nil
end

function getMultiSelect(option)
    local selected = {}
    local value = Options and Options[option] and Options[option].Value

    if typeof(value) == 'table' then
        for key, itemValue in value do
            if itemValue == true and typeof(key) == 'string' then
                selected[key] = true
            elseif typeof(itemValue) == 'string' then
                selected[itemValue] = true
            end
        end
    elseif typeof(value) == 'string' and value ~= '' then
        selected[value] = true
    end

    return selected
end

function getShopStock(shopName, itemName)
    local shop = StockValues:FindFirstChild(shopName)
    local items = shop and shop:FindFirstChild('Items')
    local item = items and items:FindFirstChild(itemName)
    return item and item.Value or 0
end

function canAfford(cost)
    if not cost then
        return true
    end

    local sheckles = getSheckles()
    return sheckles ~= nil and sheckles >= cost
end

function getAutoBuyKey(shopName, itemName)
    return shopName .. ':' .. itemName
end

function getAutoBuyTracker(shopName, itemName)
    local key = getAutoBuyKey(shopName, itemName)
    local stock = getShopStock(shopName, itemName)
    local tracker = State.AutoBuyTracker[key]

    if not tracker then
        tracker = {
            exhausted = stock <= 0,
            lastStock = stock,
            pending = false,
            pendingAt = 0,
        }
        State.AutoBuyTracker[key] = tracker
        return tracker, stock
    end

    if stock > tracker.lastStock then
        tracker.exhausted = false
        tracker.pending = false
    end

    if stock <= 0 then
        tracker.exhausted = true
        tracker.pending = false
    end

    return tracker, stock
end

function tryPurchaseItem(shopName, itemName, price, purchaseFn)
    local tracker, stock = getAutoBuyTracker(shopName, itemName)

    if tracker.exhausted then
        tracker.lastStock = stock
        return
    end

    if stock <= 0 then
        tracker.exhausted = true
        tracker.lastStock = 0
        tracker.pending = false
        return
    end

    if tracker.pending then
        if stock < tracker.lastStock then
            tracker.pending = false
            tracker.lastStock = stock
        elseif os.clock() - tracker.pendingAt > 1.5 then
            tracker.pending = false
            tracker.exhausted = true
            tracker.lastStock = stock
        end

        if stock <= 0 then
            tracker.exhausted = true
            tracker.pending = false
            tracker.lastStock = 0
        end

        return
    end

    if not canAfford(price) then
        tracker.lastStock = stock
        return
    end

    tracker.pending = true
    tracker.pendingAt = os.clock()
    tracker.lastStock = stock
    purchaseFn()
end

function tryPurchaseGear(itemName)
    tryPurchaseItem('GearShop', itemName, GearPrices[itemName], function()
        Networking.GearShop.PurchaseGear:Fire(itemName)
    end)
end

function tryPurchaseSeed(itemName)
    tryPurchaseItem('SeedShop', itemName, SeedPrices[itemName], function()
        Networking.SeedShop.PurchaseSeed:Fire(itemName)
    end)
end

function tryPurchaseProp(itemName)
    tryPurchaseItem('CrateShop', itemName, nil, function()
        Networking.CrateShop.PurchaseCrate:Fire(itemName)
    end)
end

function runAutoBuy()
    for itemName in getMultiSelect('AutoBuyGears') do
        tryPurchaseGear(itemName)
    end

    for itemName in getMultiSelect('AutoBuySeeds') do
        tryPurchaseSeed(itemName)
    end

    for itemName in getMultiSelect('AutoBuyProps') do
        tryPurchaseProp(itemName)
    end
end

function setAutoBuyLoop(enabled)
    if State.AutoBuyThread then
        pcall(task.cancel, State.AutoBuyThread)
        State.AutoBuyThread = nil
    end

    if not enabled then
        State.AutoBuyTracker = {}
        return
    end

    State.AutoBuyTracker = {}

    State.AutoBuyThread = task.spawn(function()
        while not Library.Unloaded and Toggles.AutoBuy and Toggles.AutoBuy.Value do
            runAutoBuy()
            task.wait(2)
        end
        State.AutoBuyThread = nil
    end)
end

local AUCTION_GEAR_CATEGORIES = {
    gears = true,
    gear = true,
    wateringcans = true,
    wateringcan = true,
    cans = true,
    can = true,
    sprinklers = true,
    sprinkler = true,
    mushrooms = true,
    mushroom = true,
    gnomes = true,
    gnome = true,
    raccoons = true,
    raccoon = true,
    trowels = true,
    trowel = true,
    props = true,
    prop = true,
}

function normalizeAuctionCategory(category)
    if type(category) ~= 'string' then
        return nil
    end

    local normalized = category:lower():gsub('[%s_%-]', '')
    if normalized == 'seeds' or normalized == 'seed' then
        return 'Seeds'
    end
    if AUCTION_GEAR_CATEGORIES[normalized] then
        return 'Gears'
    end
    if normalized == 'seedpacks' or normalized == 'seedpack' or normalized == 'packs' or normalized == 'crates' or normalized == 'crate' then
        return 'SeedPacks'
    end
    if normalized == 'eggs' or normalized == 'egg' or normalized == 'pets' or normalized == 'pet' then
        return 'Eggs'
    end
    if normalized == 'harvestedfruits' or normalized == 'harvestedfruit' then
        return 'Fruits'
    end

    return nil
end

function normalizeAuctionItemName(name)
    if type(name) ~= 'string' then
        return ''
    end

    return name:gsub('^%s+', ''):gsub('%s+$', '')
end

function isAuctionNameSelected(selected, itemName)
    itemName = normalizeAuctionItemName(itemName)
    if itemName == '' then
        return false
    end

    if selected[itemName] == true then
        return true
    end

    local lower = itemName:lower()
    for name, enabled in selected do
        if enabled == true and type(name) == 'string' then
            local selectedLower = name:lower()
            if selectedLower == lower then
                return true
            end
            if string.find(lower, selectedLower, 1, true) or string.find(selectedLower, lower, 1, true) then
                return true
            end
        end
    end

    return false
end

function hasAuctionCategorySelection(optionKey)
    local selected = getMultiSelect(optionKey)
    return selected and next(selected) ~= nil
end

function getAuctionLotItemName(lot)
    return lot.item or lot.displayName or lot.name or lot.ItemName or ''
end

local AUCTION_OPTION_BY_CATEGORY = {
    Seeds = 'AuctionBuySeeds',
    Gears = 'AuctionBuyGears',
    SeedPacks = 'AuctionBuySeedPacks',
    Eggs = 'AuctionBuyEggs',
}

function mergeAuctionDropdownValues(category, names)
    local optionKey = AUCTION_OPTION_BY_CATEGORY[category]
    local baseList = State.AuctionItemLists and State.AuctionItemLists[category]
    if not optionKey or not baseList then
        return
    end

    local seen = {}
    local merged = {}
    for _, name in baseList do
        appendUniqueName(merged, seen, name)
    end
    for _, name in names or {} do
        appendUniqueName(merged, seen, name)
    end

    table.sort(merged)
    State.AuctionItemLists[category] = merged

    if Options and Options[optionKey] and Options[optionKey].SetValues then
        task.defer(function()
            if Library.Unloaded then
                return
            end

            local option = Options[optionKey]
            local values = State.AuctionItemLists[category]
            if option and option.SetValues and type(values) == 'table' then
                pcall(function()
                    option:SetValues(values)
                end)
            end
        end)
    end
end

function discoverAuctionItemsFromLots(lots)
    local discovered = {
        Seeds = {},
        Gears = {},
        SeedPacks = {},
        Eggs = {},
    }

    for _, lot in lots or {} do
        local category = normalizeAuctionCategory(lot.category)
        local itemName = getAuctionLotItemName(lot)
        if category and itemName ~= '' then
            table.insert(discovered[category], itemName)
        end
    end

    for category, names in discovered do
        if #names > 0 then
            mergeAuctionDropdownValues(category, names)
        end
    end
end

function hasAnyAuctionItemSelection()
    for _, optionKey in AUCTION_OPTION_BY_CATEGORY do
        if hasAuctionCategorySelection(optionKey) then
            return true
        end
    end

    return false
end

function getAuctionLotNameVariants(lot)
    local names = {}
    local seen = {}

    local function add(name)
        name = normalizeAuctionItemName(name)
        if name == '' then
            return
        end

        local lower = name:lower()
        if seen[lower] then
            return
        end

        seen[lower] = true
        table.insert(names, name)
    end

    add(lot.displayName)
    add(lot.item)
    add(lot.name)
    add(lot.ItemName)

    local ok, displayName = pcall(AuctioneerModule.DisplayName, lot)
    if ok then
        add(displayName)
    end

    if type(lot.category) == 'string' and type(lot.item) == 'string' then
        pcall(function()
            loadMailModules()
            if MailboxItemCatalog and MailboxItemCatalog.Resolve then
                add(MailboxItemCatalog.Resolve(lot.category, lot.item, {}))
            end
        end)
    end

    return names
end

function isAuctionLotSelected(lot)
    if lot.robuxPrice ~= nil then
        return false
    end

    if not hasAnyAuctionItemSelection() then
        return true
    end

    local variants = getAuctionLotNameVariants(lot)
    if #variants == 0 then
        return false
    end

    for _, optionKey in AUCTION_OPTION_BY_CATEGORY do
        if hasAuctionCategorySelection(optionKey) then
            local selected = getMultiSelect(optionKey)
            for _, name in variants do
                if isAuctionNameSelected(selected, name) then
                    return true
                end
            end
        end
    end

    return false
end

function refreshAuctionItemListsFromCatalog()
    loadMailModules()
    if not MailboxItemCatalog then
        return
    end

    local catalogItems = MailboxItemCatalog.Items
        or MailboxItemCatalog.DefaultItems
        or MailboxItemCatalog.AllItems

    if type(catalogItems) ~= 'table' then
        return
    end

    local discovered = {
        Seeds = {},
        Gears = {},
        SeedPacks = {},
        Eggs = {},
    }

    for category, items in catalogItems do
        local normalized = normalizeAuctionCategory(category)
        if not normalized or type(items) ~= 'table' then
            continue
        end

        if items[1] ~= nil then
            for _, itemName in items do
                if type(itemName) == 'string' and itemName ~= '' then
                    table.insert(discovered[normalized], itemName)
                end
            end
        else
            for itemName in items do
                if type(itemName) == 'string' and itemName ~= '' then
                    table.insert(discovered[normalized], itemName)
                end
            end
        end
    end

    for category, names in discovered do
        if #names > 0 then
            mergeAuctionDropdownValues(category, names)
        end
    end
end

function getAuctionServerNow()
    local ok, now = pcall(function()
        return workspace:GetServerTimeNow()
    end)

    return ok and now or os.time()
end

function isAuctionShopActive()
    local override = workspace:GetAttribute('AuctionStandOverride')
    if override == 'on' then
        return true
    end
    if override == 'off' then
        return false
    end

    return AuctioneerFlags.Enabled:Get() and AuctioneerFlags.OpenEnabled:Get()
end

function applyAuctionSnapshot(snapshot)
    if type(snapshot) ~= 'table' then
        return
    end

    local lots = {}
    local manifest = snapshot.manifest
    if type(manifest) == 'table' and type(manifest.lots) == 'table' then
        for _, lot in manifest.lots do
            if type(lot) == 'table' and type(lot.lotId) == 'string' then
                table.insert(lots, lot)
            end
        end
    end

    State.AuctionLots = lots
    discoverAuctionItemsFromLots(lots)

    if type(snapshot.stock) == 'table' then
        State.AuctionStock = snapshot.stock
    end

    State.AuctionLastSnapshot = os.clock()
end

function applyAuctionStockUpdate(update)
    if type(update) ~= 'table' then
        return
    end

    if type(update.stock) == 'table' then
        State.AuctionStock = update.stock
    end
end

function requestAuctionSnapshot()
    local ok, snapshot = pcall(function()
        return Networking.Auctioneer.RequestSnapshot:Fire()
    end)

    if ok and type(snapshot) == 'table' then
        applyAuctionSnapshot(snapshot)
        return true
    end

    return false
end

function setupAuctionNetworking()
    if State.AuctionNetworkingReady then
        return
    end

    State.AuctionNetworkingReady = true

    Networking.Auctioneer.Snapshot.OnClientEvent:Connect(function(snapshot)
        applyAuctionSnapshot(snapshot)
    end)

    Networking.Auctioneer.StockUpdate.OnClientEvent:Connect(function(update)
        applyAuctionStockUpdate(update)
    end)

    Networking.Auctioneer.PurchaseResult.OnClientEvent:Connect(function(lotId, success)
        if success then
            State.AuctionPurchaseTimes[lotId] = nil
            return
        end

        State.AuctionPurchaseTimes[lotId] = nil
        State.AuctionPurchaseCooldowns[lotId] = nil
    end)

    task.defer(function()
        requestAuctionSnapshot()
    end)
end

function getAuctionPriceLimit()
    if not Options or not Options.AuctionPrice then
        return 0
    end

    local raw = tostring(Options.AuctionPrice.Value or '0'):gsub(',', ''):gsub('%s+', '')
    return tonumber(raw) or 0
end

function getAuctionPriceMode()
    if not Options or not Options.AuctionPriceMode then
        return 'Below'
    end

    return Options.AuctionPriceMode.Value or 'Below'
end

function matchesAuctionPriceFilter(price)
    local limit = getAuctionPriceLimit()
    if limit <= 0 then
        return true
    end

    local mode = getAuctionPriceMode()
    if mode == 'Above' then
        return price >= limit
    end
    if mode == 'At' then
        return price == limit
    end

    return price <= limit
end

function canPurchaseAuctionLot(lotId)
    local debounce = AuctioneerFlags.PurchaseDebounceSeconds:Get()
    local lastPurchase = State.AuctionPurchaseTimes[lotId]
    if lastPurchase and debounce > 0 and os.clock() - lastPurchase < debounce then
        return false
    end

    local cooldownUntil = State.AuctionPurchaseCooldowns[lotId] or 0
    if os.clock() < cooldownUntil then
        return false
    end

    return true
end

function tryPurchaseAuctionLot(lot, stock)
    if not isAuctionLotSelected(lot) then
        return
    end

    local lotId = lot.lotId
    if not lotId or not canPurchaseAuctionLot(lotId) then
        return
    end

    local now = getAuctionServerNow()
    local stockCount = stock
    if type(stock) == 'table' then
        stockCount = stock[lotId]
    end

    if not AuctioneerModule.IsActive(lot, now, stockCount) then
        return
    end

    local price = AuctioneerModule.CurrentPrice(lot, now)
    if not price or price <= 0 then
        return
    end

    if not matchesAuctionPriceFilter(price) then
        return
    end

    if not canAfford(price) then
        return
    end

    State.AuctionPurchaseTimes[lotId] = os.clock()

    local cooldown = AuctioneerFlags.PurchaseCooldownSeconds:Get()
    if cooldown > 0 then
        State.AuctionPurchaseCooldowns[lotId] = os.clock() + cooldown
    end

    pcall(function()
        Networking.Auctioneer.PurchaseLot:Fire(lotId, price)
    end)
end

function runAutoAuction()
    if not isActiveSession() then
        return
    end

    if os.clock() - (State.AuctionLastSnapshot or 0) > 2 then
        requestAuctionSnapshot()
    end

    if #State.AuctionLots == 0 then
        return
    end

    local stock = State.AuctionStock or {}
    for _, lot in State.AuctionLots do
        tryPurchaseAuctionLot(lot, stock[lot.lotId])
    end
end

function setAutoAuctionLoop(enabled)
    if State.AutoAuctionThread then
        pcall(task.cancel, State.AutoAuctionThread)
        State.AutoAuctionThread = nil
    end

    if not enabled then
        return
    end

    setupAuctionNetworking()

    if not hasAnyAuctionItemSelection() and getAuctionPriceLimit() <= 0 and Library and Library.Notify then
        Library:Notify('Auto auction: set a price limit or select items to buy')
    end

    State.AutoAuctionThread = task.spawn(function()
        while isActiveSession() and Toggles.AutoBuyAuction and Toggles.AutoBuyAuction.Value do
            runAutoAuction()
            task.wait(0.35)
        end
        State.AutoAuctionThread = nil
    end)
end

function getEggHatchCooldownKey(key)
    return tostring(key)
end

function canTryEggHatch(key, cooldown)
    cooldown = cooldown or 3
    local last = State.EggHatchTimes[getEggHatchCooldownKey(key)]
    return not last or os.clock() - last >= cooldown
end

function markEggHatchAttempt(key)
    State.EggHatchTimes[getEggHatchCooldownKey(key)] = os.clock()
end

function findEggTools()
    local tools = {}
    local seen = {}

    local function scan(container)
        if not container then
            return
        end

        for _, item in container:GetChildren() do
            if item:IsA('Tool') and not seen[item] then
                local eggName = item:GetAttribute('Egg')
                if type(eggName) == 'string' and eggName ~= '' then
                    local uses = item:GetAttribute('Uses')
                    if uses == nil or tonumber(uses) == nil or tonumber(uses) > 0 then
                        seen[item] = true
                        table.insert(tools, item)
                    end
                end
            end
        end
    end

    scan(LocalPlayer.Backpack)
    scan(LocalPlayer.Character)

    return tools
end

function findOwnedDragonEggs()
    local eggs = {}

    for _, egg in CollectionService:GetTagged('DragonEggInstance') do
        if egg:IsA('Model') and egg:GetAttribute('DragonEggOwner') == LocalPlayer.UserId then
            table.insert(eggs, egg)
        end
    end

    return eggs
end

function triggerProximityPrompt(prompt)
    if not prompt or not prompt.Enabled then
        return false
    end

    if type(firesignal) == 'function' then
        local ok = pcall(function()
            firesignal(prompt.Triggered, LocalPlayer)
        end)
        if ok then
            return true
        end
    end

    local ok = pcall(function()
        prompt:InputHoldBegin()
    end)

    if not ok then
        return false
    end

    task.wait((prompt.HoldDuration or 0) + 0.05)
    pcall(function()
        prompt:InputHoldEnd()
    end)

    return true
end

function tryOpenEggById(eggId)
    if type(eggId) ~= 'string' or eggId == '' then
        return false
    end

    if not canTryEggHatch(eggId, 2.5) then
        return false
    end

    local ok, result = pcall(function()
        return Networking.Egg.OpenEgg:Fire(eggId)
    end)

    if ok and type(result) == 'table' and result.Success then
        markEggHatchAttempt(eggId)
        return true, result
    end

    return false, result
end

function tryHatchEggTool(tool)
    if not tool or not tool:IsA('Tool') then
        return false
    end

    local eggName = tool:GetAttribute('Egg')
    if type(eggName) ~= 'string' or eggName == '' then
        return false
    end

    if LocalPlayer:GetAttribute('LoadingScreenActive') then
        return false
    end

    if not canTryEggHatch(tool, 3) then
        return false
    end

    State.EggHatchPending = true
    local ok, result = tryOpenEggById(eggName)
    State.EggHatchPending = false

    if ok then
        markEggHatchAttempt(tool)
        return true, result
    end

    return false, result
end

function tryHatchDragonWorldEgg(eggModel)
    if not eggModel or not eggModel:IsA('Model') then
        return false
    end

    if eggModel:GetAttribute('DragonEggOwner') ~= LocalPlayer.UserId then
        return false
    end

    if LocalPlayer:GetAttribute('LoadingScreenActive') then
        return false
    end

    local eggKey = eggModel:GetFullName()
    if not canTryEggHatch(eggKey, 5) then
        return false
    end

    for _, descendant in eggModel:GetDescendants() do
        if descendant:IsA('ProximityPrompt') then
            if triggerProximityPrompt(descendant) then
                markEggHatchAttempt(eggKey)
                return true
            end
        end
    end

    local candidates = {
        eggModel:GetAttribute('Egg'),
        eggModel:GetAttribute('EggId'),
        eggModel:GetAttribute('EggName'),
        eggModel:GetAttribute('DragonEggId'),
        eggModel:GetAttribute('Id'),
    }

    for _, eggId in candidates do
        local ok, result = tryOpenEggById(eggId)
        if ok then
            markEggHatchAttempt(eggKey)
            return true, result
        end
    end

    return false
end

function runAutoHatch()
    if not isActiveSession() or State.EggHatchPending then
        return
    end

    for _, eggModel in findOwnedDragonEggs() do
        if tryHatchDragonWorldEgg(eggModel) then
            return
        end
    end

    for _, tool in findEggTools() do
        if tryHatchEggTool(tool) then
            return
        end
    end
end

function setAutoHatchLoop(enabled)
    if State.AutoHatchThread then
        pcall(task.cancel, State.AutoHatchThread)
        State.AutoHatchThread = nil
    end

    if not enabled then
        return
    end

    State.AutoHatchThread = task.spawn(function()
        while isActiveSession() and Toggles.AutoHatchEggs and Toggles.AutoHatchEggs.Value do
            runAutoHatch()
            task.wait(0.5)
        end
        State.AutoHatchThread = nil
    end)
end

function recordEarnings(amount)
    if not amount or amount <= 0 then
        return
    end

    table.insert(State.EarningsWindow, { t = os.clock(), amount = amount })

    local now = os.clock()
    while #State.EarningsWindow > 0 and now - State.EarningsWindow[1].t > 60 do
        table.remove(State.EarningsWindow, 1)
    end
end

function getEarningsPerMinute()
    local total = 0
    local now = os.clock()
    for _, entry in State.EarningsWindow do
        if now - entry.t <= 60 then
            total += entry.amount
        end
    end
    return total
end

function isFruitRipe(fruitData, fruitModel)
    if fruitModel then
        if fruitModel:GetAttribute('IsRipe') == true then
            return true
        end

        local age = fruitModel:GetAttribute('Age')
        local maxAge = fruitModel:GetAttribute('MaxAge')
        if typeof(age) == 'number' and typeof(maxAge) == 'number' then
            return age >= maxAge
        end
    end

    if fruitData then
        return (fruitData.Age or 0) >= (fruitData.MaxAge or 1)
    end

    return fruitModel ~= nil
end

--[[
    A ripe fruit that fails the maxKg filter (e.g. you're only keeping big
    ones) sits there getting re-checked every frame by the harvest loop -
    without this cache that means calling into the game's own
    FruitVisualizer:CalculateFruitWeight every single frame forever for
    every filtered-out fruit. Age only changes when the server actually
    updates the fruit, so it's a perfect cache-invalidation key.
]]
function getFruitWeightKg(fruitModel, fruitData)
    local age
    if fruitModel then
        age = fruitModel:GetAttribute('Age')
        local cached = State.HarvestWeightCache[fruitModel]
        if cached and cached.Age == age then
            return cached.Weight
        end
    end

    local weight

    if fruitModel then
        local ok, calculated = pcall(function()
            return FruitVisualizer:CalculateFruitWeight(fruitModel)
        end)
        if ok and calculated then
            weight = calculated
        end

        if not weight then
            pcall(function()
                if FruitVisualizer.CalculatePlantWeight then
                    weight = FruitVisualizer:CalculatePlantWeight(fruitModel)
                end
            end)
        end

        if not weight then
            weight = fruitModel:GetAttribute('Weight')
                or fruitModel:GetAttribute('WeightKg')
                or fruitModel:GetAttribute('FruitWeight')
        end
    end

    if not weight and fruitData then
        weight = fruitData.Weight or fruitData.FruitWeight or fruitData.Kg or fruitData.WeightKg
    end

    local result = normalizeWeightKg(weight)

    if fruitModel then
        State.HarvestWeightCache[fruitModel] = { Age = age, Weight = result }
    end

    return result
end

function getFruitToolIdSet()
    local ids = {}

    for _, tool in getHarvestedFruitTools() do
        local id = getFruitToolId(tool)
        if id then
            ids[id] = true
        end
    end

    return ids
end

function favoriteFruitTool(tool)
    if not tool or tool:GetAttribute('IsFavorite') then
        return false
    end

    local id = getFruitToolId(tool)
    if not id then
        return false
    end

    pcall(function()
        Networking.Backpack.SetFruitFavorite:Fire(id, true)
    end)
    tool:SetAttribute('IsFavorite', true)
    return true
end

function waitAndFavoriteNewFruit(beforeIds)
    for _ = 1, 25 do
        for _, tool in getHarvestedFruitTools() do
            local id = getFruitToolId(tool)
            if id and not beforeIds[id] then
                favoriteFruitTool(tool)
                beforeIds[id] = true
                return true
            end
        end
        task.wait(0.05)
    end

    return false
end

function getGardenFruitData(garden, plantId, fruitId)
    local plant = garden[plantId]
    if not plant then
        return nil
    end

    if fruitId and fruitId ~= '' then
        return plant.Fruits and plant.Fruits[fruitId]
    end

    return plant
end

function findFruitModel(plantsFolder, plantId, fruitId)
    if not plantsFolder then
        return nil
    end

    for _, plantModel in plantsFolder:GetChildren() do
        local fruitsFolder = plantModel:FindFirstChild('Fruits')
        if fruitsFolder then
            for _, fruitModel in fruitsFolder:GetChildren() do
                if fruitModel:GetAttribute('PlantId') == plantId and fruitModel:GetAttribute('FruitId') == fruitId then
                    return fruitModel
                end
            end
        elseif plantModel:GetAttribute('PlantId') == plantId then
            return plantModel
        end
    end

    for _, plantModel in plantsFolder:GetChildren() do
        if plantModel.Name:find(plantId, 1, true) then
            local fruitsFolder = plantModel:FindFirstChild('Fruits')
            if fruitsFolder and fruitId then
                for _, fruitModel in fruitsFolder:GetChildren() do
                    if fruitModel:GetAttribute('FruitId') == fruitId then
                        return fruitModel
                    end
                end
            else
                return plantModel
            end
        end
    end

    return nil
end

function shouldHarvestFruit(weightKg, maxKg)
    maxKg = tonumber(maxKg)
    if not maxKg then
        return false
    end

    if not weightKg then
        return false
    end

    return weightKg <= maxKg
end

function abbreviateNumber(n)
    n = tonumber(n) or 0
    if NumberUtils and NumberUtils.Abbreviate then
        return NumberUtils.Abbreviate(n)
    end
    return tostring(n)
end

function getFruitMutation(fruitModel, fruitData, plantData)
    if fruitModel then
        local mutation = fruitModel:GetAttribute('Mutation')
        if mutation and mutation ~= '' then
            return mutation
        end
    end

    if fruitData and fruitData.Mutation and fruitData.Mutation ~= '' then
        return fruitData.Mutation
    end

    if plantData and plantData.Mutation and plantData.Mutation ~= '' then
        return plantData.Mutation
    end

    if plantData and plantData.Variant and plantData.Variant ~= '' and plantData.Variant ~= 'Normal' then
        return plantData.Variant
    end

    return 'None'
end

function getFruitSellValue(fruitModel, fruitData, plantData)
    local core = (fruitModel and fruitModel:GetAttribute('CorePartName'))
        or (plantData and plantData.PlantName)
        or 'Unknown'
    local mutation = getFruitMutation(fruitModel, fruitData, plantData)
    local sizeMulti = (fruitModel and fruitModel:GetAttribute('SizeMulti'))
        or (fruitData and fruitData.SizeMultiplier)
        or 1
    local base = SellValueData[core] or 100
    local mult = mutation ~= 'None' and MutationData.ReturnPriceMultiplier(mutation) or 1
    return math.floor(base * (sizeMulti ^ 3) * mult)
end

local FruitsStatusLabel

function formatFruitLabel(fruit)
    local weightText = '?kg'
    if fruit.weightKg and fruit.weightKg > 0 then
        weightText = string.format('~%.2fkg', fruit.weightKg)
    end

    return string.format(
        '%s | %s | %s | $%s',
        fruit.plantName,
        fruit.mutation,
        weightText,
        abbreviateNumber(fruit.value)
    )
end

function scanGardenFruits()
    local results = {}
    local seen = {}
    local plot = getPlot()
    local plantsFolder = plot and plot:FindFirstChild('Plants')
    local garden = GardenSync:GetGarden(LocalPlayer.UserId) or {}

    if not plantsFolder then
        return results
    end

    local function addFruit(plantId, fruitId, fruitModel, plantData)
        if not plantId then
            return
        end

        local key = plantId .. '_' .. (fruitId or '')
        if seen[key] then
            return
        end

        local fruitData = fruitId and fruitId ~= '' and getGardenFruitData(garden, plantId, fruitId) or plantData
        if not isFruitRipe(fruitData, fruitModel) then
            return
        end

        seen[key] = true
        local plantName = (fruitModel and fruitModel:GetAttribute('CorePartName'))
            or (plantData and plantData.PlantName)
            or 'Plant'
        local mutation = getFruitMutation(fruitModel, fruitData, plantData)
        local weightKg = getFruitWeightKg(fruitModel, fruitData)
        local maxKg = getMaxHarvestKg()
        if weightKg and weightKg < maxKg then
            return
        end

        local value = getFruitSellValue(fruitModel, fruitData, plantData)

        table.insert(results, {
            key = key,
            plantId = plantId,
            fruitId = fruitId or '',
            plantName = plantName,
            mutation = mutation,
            weightKg = weightKg,
            value = value,
        })
    end

    for _, plantModel in plantsFolder:GetChildren() do
        local fruitsFolder = plantModel:FindFirstChild('Fruits')
        if fruitsFolder then
            for _, fruitModel in fruitsFolder:GetChildren() do
                local plantId = fruitModel:GetAttribute('PlantId') or plantModel:GetAttribute('PlantId')
                local fruitId = fruitModel:GetAttribute('FruitId') or fruitModel.Name
                if plantId then
                    addFruit(plantId, fruitId, fruitModel, garden[plantId])
                end
            end
        else
            local plantId = plantModel:GetAttribute('PlantId')
            if plantId then
                addFruit(plantId, '', plantModel, garden[plantId])
            end
        end
    end

    for plantId, plantData in garden do
        if plantData.Fruits then
            for fruitId, fruitData in plantData.Fruits do
                if not seen[plantId .. '_' .. fruitId] then
                    addFruit(plantId, fruitId, findFruitModel(plantsFolder, plantId, fruitId), plantData)
                end
            end
        elseif not seen[plantId .. '_'] then
            addFruit(plantId, '', findFruitModel(plantsFolder, plantId, ''), plantData)
        end
    end

    table.sort(results, function(a, b)
        local av = a.value or 0
        local bv = b.value or 0
        if av == bv then
            return (a.weightKg or 0) > (b.weightKg or 0)
        end
        return av > bv
    end)

    return results
end

function refreshFruitsList()
    State.GardenFruits = scanGardenFruits()
    State.FruitLabelMap = {}

    local labels = {}
    local keepSelected = {}
    local oldSelection = Options and Options.GardenFruitList and Options.GardenFruitList.Value

    for _, fruit in State.GardenFruits do
        local label = formatFruitLabel(fruit)
        local uniqueLabel = label
        local suffix = 2

        while State.FruitLabelMap[uniqueLabel] do
            uniqueLabel = label .. ' #' .. suffix
            suffix += 1
        end

        label = uniqueLabel
        fruit.label = label
        State.FruitLabelMap[label] = fruit
        table.insert(labels, label)

        if typeof(oldSelection) == 'table' and oldSelection[label] == true then
            keepSelected[label] = true
        end
    end

    local fruitCount = #labels
    local maxKg = getMaxHarvestKg()

    task.defer(function()
        if Options and Options.GardenFruitList then
            if fruitCount == 0 then
                Options.GardenFruitList:SetValues({ 'No fruits at or above Max KG' })
                Options.GardenFruitList:SetValue({})
            else
                Options.GardenFruitList:SetValues(labels)
                Options.GardenFruitList:SetValue(keepSelected)
            end
        end

        if FruitsStatusLabel then
            FruitsStatusLabel:SetText(string.format(
                '%d fruits at or above %.0fkg ? select from dropdown',
                fruitCount,
                maxKg
            ))
        end
    end)

    return fruitCount
end

function claimSelectedGardenFruits()
    local selected = Options and Options.GardenFruitList and Options.GardenFruitList.Value
    if typeof(selected) ~= 'table' then
        Library:Notify('Select fruits from the dropdown first')
        return
    end

    local claimed = 0

    for label, isSelected in selected do
        if isSelected == true then
            local fruit = State.FruitLabelMap[label]
            if fruit then
                local beforeIds = getFruitToolIdSet()
                Networking.Garden.CollectFruit:Fire(fruit.plantId, fruit.fruitId or '')
                waitAndFavoriteNewFruit(beforeIds)
                claimed += 1
                task.wait(0.1)
            end
        end
    end

    if claimed == 0 then
        Library:Notify('Select fruits from the dropdown first')
        return
    end

    Library:Notify(string.format('Claimed & favorited %d fruit(s)', claimed))
    task.wait(0.25)
    refreshFruitsList()
end

function hookFruitsTabAutoScan(fruitsTab)
    if not fruitsTab or fruitsTab._GG2ScanHooked then
        return
    end

    fruitsTab._GG2ScanHooked = true
    local showTab = fruitsTab.ShowTab

    function fruitsTab.ShowTab(...)
        showTab(...)
        task.defer(refreshFruitsList)
    end
end

function collectFruit(plantId, fruitId)
    Networking.Garden.CollectFruit:Fire(plantId, fruitId or '')
end

function isPlantTypeHarvestAllowed(allowedSet, garden, plantId)
    if not allowedSet then
        return true
    end

    local plant = garden and garden[plantId]
    local plantName = plant and plant.PlantName
    return type(plantName) == 'string' and allowedSet[plantName] == true
end

--[[
    Runs every frame (Auto Harvest is intentionally task.wait(0)), so this
    must do exactly ONE pass over the Plants folder. The old version called
    findFruitModel - itself a full linear rescan of every plant/fruit - up to
    twice per fruit in the synced garden table, on top of its own folder
    walk. For a garden with dozens of plants that's tens of thousands of
    redundant GetChildren/GetAttribute calls every single frame, which is
    what was actually tanking FPS (not the visual optimizer). Building a
    plantId_fruitId -> model index in one pass and reusing it everywhere
    turns that O(plants x fruits) rescan into O(plants + fruits).
]]
function harvestFruits(maxKg)
    local plot = getPlot()
    local plantsFolder = plot and plot:FindFirstChild('Plants')
    if not plantsFolder then
        return
    end

    maxKg = tonumber(maxKg) or 999
    local garden = GardenSync:GetGarden(LocalPlayer.UserId)
    local allowedSet = getSelectedHarvestPlantsSet()
    local seen = {}
    local modelIndex = {}

    for _, plantModel in plantsFolder:GetChildren() do
        local fruitsFolder = plantModel:FindFirstChild('Fruits')
        if fruitsFolder then
            for _, fruitModel in fruitsFolder:GetChildren() do
                local plantId = fruitModel:GetAttribute('PlantId')
                local fruitId = fruitModel:GetAttribute('FruitId')

                if plantId and fruitId then
                    modelIndex[plantId .. '_' .. fruitId] = fruitModel

                    if isFruitRipe(nil, fruitModel) and isPlantTypeHarvestAllowed(allowedSet, garden, plantId) then
                        local key = plantId .. '_' .. fruitId
                        if not seen[key] then
                            seen[key] = true
                            local fruitData = getGardenFruitData(garden, plantId, fruitId)
                            local weight = getFruitWeightKg(fruitModel, fruitData)
                            if shouldHarvestFruit(weight, maxKg) then
                                collectFruit(plantId, fruitId)
                            end
                        end
                    end
                end
            end
        else
            local plantId = plantModel:GetAttribute('PlantId')
            if plantId then
                modelIndex[plantId .. '_'] = plantModel

                if isFruitRipe(nil, plantModel) and isPlantTypeHarvestAllowed(allowedSet, garden, plantId) then
                    local key = plantId .. '_'
                    if not seen[key] then
                        seen[key] = true
                        local fruitData = getGardenFruitData(garden, plantId, '')
                        local weight = getFruitWeightKg(plantModel, fruitData)
                        if shouldHarvestFruit(weight, maxKg) then
                            collectFruit(plantId, '')
                        end
                    end
                end
            end
        end
    end

    for plantId, plant in garden do
        if not isPlantTypeHarvestAllowed(allowedSet, garden, plantId) then
            continue
        end

        if plant.Fruits then
            for fruitId, fruit in plant.Fruits do
                local key = plantId .. '_' .. fruitId
                if not seen[key] then
                    local fruitModel = modelIndex[key]
                    if isFruitRipe(fruit, fruitModel) then
                        seen[key] = true
                        local weight = getFruitWeightKg(fruitModel, fruit)
                        if shouldHarvestFruit(weight, maxKg) then
                            collectFruit(plantId, fruitId)
                        end
                    end
                end
            end
        else
            local key = plantId .. '_'
            if not seen[key] then
                local plantModel = modelIndex[key]
                if isFruitRipe(plant, plantModel) then
                    seen[key] = true
                    local weight = getFruitWeightKg(plantModel, plant)
                    if shouldHarvestFruit(weight, maxKg) then
                        collectFruit(plantId, '')
                    end
                end
            end
        end
    end
end

function setAntiAfk(enabled)
    if State.AntiAfkConnection then
        State.AntiAfkConnection:Disconnect()
        State.AntiAfkConnection = nil
    end

    if not enabled then
        return
    end

    State.AntiAfkConnection = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

function setAutoSellLoop(enabled)
    if State.AutoSellThread then
        pcall(task.cancel, State.AutoSellThread)
        State.AutoSellThread = nil
    end

    if not enabled then
        return
    end

    State.AutoSellThread = task.spawn(function()
        while not Library.Unloaded and Toggles.AutoSell and Toggles.AutoSell.Value do
            tryAutoSell()
            task.wait(1)
        end
        State.AutoSellThread = nil
    end)
end

function waitForHarvestReady(timeout)
    timeout = timeout or 90
    local deadline = os.clock() + timeout

    repeat
        task.wait()
    until game:IsLoaded()

    if isLoadingScreenBlocking() then
        waitForLoadingScreenDismiss(math.min(90, timeout))
    end

    while os.clock() < deadline do
        if not (Toggles.AutoHarvest and Toggles.AutoHarvest.Value) then
            return false
        end

        local char = LocalPlayer.Character
        if not char then
            char = LocalPlayer.CharacterAdded:Wait()
        end

        local root = char:FindFirstChild('HumanoidRootPart')
        local plotId = LocalPlayer:GetAttribute('PlotId')
        local plot = plotId and Gardens:FindFirstChild('Plot' .. plotId)
        local plants = plot and plot:FindFirstChild('Plants')

        if root and plants then
            local ok, garden = pcall(function()
                return GardenSync:GetGarden(LocalPlayer.UserId)
            end)
            if ok and garden then
                return true
            end
        end

        task.wait(0.25)
    end

    return false
end

function setAutoHarvestLoop(enabled)
    if State.HarvestConnection then
        State.HarvestConnection:Disconnect()
        State.HarvestConnection = nil
    end

    if State.HarvestThread then
        pcall(task.cancel, State.HarvestThread)
        State.HarvestThread = nil
    end

    if not enabled then
        return
    end

    State.HarvestThread = task.spawn(function()
        local ready = waitForHarvestReady(90)
        if not ready then
            if Library and Library.Notify then
                Library:Notify('Auto harvest waiting for garden to load...')
            end
            ready = waitForHarvestReady(60)
        end

        while not Library.Unloaded and Toggles.AutoHarvest and Toggles.AutoHarvest.Value do
            if not ready then
                ready = waitForHarvestReady(5)
            end

            if ready then
                local maxKg = getMaxHarvestKg()
                harvestFruits(maxKg)
            end

            task.wait(0)
        end
        State.HarvestThread = nil
    end)
end

local WeatherStatusLabel
local CurrentWeatherLabel

function getQueueOnTeleport()
    local genv = getgenv()
    return queueonteleport
        or queue_on_teleport
        or queueteleport
        or QueueOnTeleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
        or genv.queueonteleport
        or genv.queue_on_teleport
        or genv.queueteleport
        or genv.queueonteleport
        or genv.QueueOnTeleport
end

function getOutsideWalkTarget(basePos, standoff)
    standoff = standoff or 10
    if not basePos then
        return nil
    end

    local plot = getPlot()
    if plot then
        local plotPivot = plot:GetPivot().Position
        local fromCenter = Vector3.new(basePos.X - plotPivot.X, 0, basePos.Z - plotPivot.Z)
        if fromCenter.Magnitude > 0.5 then
            local outside = basePos + fromCenter.Unit * standoff
            return Vector3.new(outside.X, basePos.Y, outside.Z)
        end
    end

    local char = getCharacter()
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if root then
        local flatTo = Vector3.new(basePos.X - root.Position.X, 0, basePos.Z - root.Position.Z)
        local dist = flatTo.Magnitude
        if dist > 0.5 then
            local outside = basePos - flatTo.Unit * math.min(standoff, math.max(dist - 1, 1))
            return Vector3.new(outside.X, basePos.Y, outside.Z)
        end
    end

    return Vector3.new(basePos.X + standoff, basePos.Y, basePos.Z)
end

function getWeatherClock()
    local ok, now = pcall(function()
        return workspace:GetServerTimeNow()
    end)

    return ok and now or os.time()
end

function normalizeWeatherHideUntil(endTime)
    local now = getWeatherClock()
    local value = tonumber(endTime)

    if not value or value <= 0 then
        return now + 120
    end

    if value <= now then
        if value >= 30 and value <= 86400 then
            return now + value
        end

        return now + 120
    end

    if value - now < 30 then
        return now + 30
    end

    return value
end

function isWeatherHideTimerElapsed()
    return getWeatherClock() >= (State.HideUntil or 0)
end

function canRejoinHomeAfterWeather()
    if not State.WeatherHiding then
        return true
    end

    return isWeatherHideTimerElapsed()
end

function ensureWeatherHideUntilValid()
    if not State.WeatherHiding then
        return
    end

    local hideUntil = tonumber(State.HideUntil) or 0
    local now = getWeatherClock()

    if hideUntil > now then
        return
    end

    if hideUntil <= 0 then
        State.HideUntil = now + 120
        saveWeatherState()
    end
end

function saveWeatherState()
    local data = {
        Hiding = State.WeatherHiding,
        ReturnJobId = State.ReturnJobId,
        ReturnPlaceId = State.ReturnPlaceId,
        HideUntil = State.HideUntil,
        HidingFromWeather = State.HidingFromWeather,
        PendingWalkBack = State.PendingWalkBack == true,
        PendingWalkToSaved = State.PendingWalkToSaved == true,
        ReturnPosX = State.ReturnPosX,
        ReturnPosY = State.ReturnPosY,
        ReturnPosZ = State.ReturnPosZ,
    }

    GENV.GG2_WeatherState = data
    writeWeatherStateFile(data)
end

function loadWeatherState()
    local saved = GENV.GG2_WeatherState or readWeatherStateFile()
    if not saved then
        return
    end

    State.WeatherHiding = saved.Hiding == true
    State.ReturnJobId = saved.ReturnJobId
    State.ReturnPlaceId = saved.ReturnPlaceId
    State.HideUntil = saved.HideUntil or 0
    State.HidingFromWeather = saved.HidingFromWeather
    State.PendingWalkBack = saved.PendingWalkBack == true
    State.PendingWalkToSaved = saved.PendingWalkToSaved == true
    State.ReturnPosX = tonumber(saved.ReturnPosX)
    State.ReturnPosY = tonumber(saved.ReturnPosY)
    State.ReturnPosZ = tonumber(saved.ReturnPosZ)

    GENV.GG2_WeatherState = saved
    ensureWeatherHideUntilValid()
end

function clearRejoinTarget()
    State.ReturnJobId = nil
    State.ReturnPlaceId = nil
    State.HideUntil = 0
    State.WeatherHiding = false
    State.HidingFromWeather = nil
    saveWeatherState()
end

function clearWeatherState(options)
    options = options or {}

    State.WeatherHiding = false
    State.HidingFromWeather = nil

    if not options.keepWalkBack then
        State.ReturnJobId = nil
        State.ReturnPlaceId = nil
        State.HideUntil = 0
        State.PendingWalkBack = false
        State.PendingWalkToSaved = false
        State.ReturnPosX = nil
        State.ReturnPosY = nil
        State.ReturnPosZ = nil
        GENV.GG2_WeatherState = nil
        clearWeatherStateFile()
    else
        saveWeatherState()
    end
end

function saveAutoExecWalkState()
    State.PendingWalkToSaved = getGearTargetPosition() ~= nil
        or (State.ReturnPosX ~= nil and State.ReturnPosY ~= nil and State.ReturnPosZ ~= nil)
    saveWeatherState()
end

function saveWeatherReturnPosition()
    local root = getCharacter() and getCharacter():FindFirstChild('HumanoidRootPart')
    local pos = root and root.Position or getGearTargetPosition()

    if not pos then
        return false
    end

    State.ReturnPosX = pos.X
    State.ReturnPosY = pos.Y
    State.ReturnPosZ = pos.Z
    State.PendingWalkBack = true
    return true
end

function walkNearPosition(basePos, standoff)
    standoff = standoff or 10
    if not basePos then
        return false
    end

    local char = getCharacter()
    if not char then
        char = LocalPlayer.CharacterAdded:Wait()
    end

    local root = char:WaitForChild('HumanoidRootPart', 15)
    if not root then
        return false
    end

    local target = getOutsideWalkTarget(basePos, standoff)
    if not target then
        return false
    end

    local flatDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
    if flatDist <= 8 then
        return true
    end

    local walked = walkToPosition(target, 60)
    if not walked and root.Parent then
        pcall(function()
            root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
        end)
        walked = true
    end

    return walked
end

function doStartupWalk()
    if State.StartupWalkDone then
        return
    end
    State.StartupWalkDone = true

    task.spawn(function()
        waitForLoadingScreenDismiss(120)

        local char = getCharacter() or LocalPlayer.CharacterAdded:Wait()
        char:WaitForChild('HumanoidRootPart', 15)
        task.wait(0.5)

        waitForGardenReady(30)
        syncTargetPlantFromSavedConfig()
        refreshTargetPlantDropdown()
        syncHarvestPlantsFromSavedConfig()
        refreshHarvestPlantsDropdown()
        loadWeatherState()

        local basePos = getGearTargetPosition()
        if not basePos and State.PendingWalkBack and State.ReturnPosX and State.ReturnPosY and State.ReturnPosZ then
            basePos = Vector3.new(State.ReturnPosX, State.ReturnPosY, State.ReturnPosZ)
        end

        if not basePos then
            return
        end

        walkNearPosition(basePos, 10)

        if State.PendingWalkBack or State.PendingWalkToSaved then
            State.PendingWalkBack = false
            State.PendingWalkToSaved = false
            State.ReturnPosX = nil
            State.ReturnPosY = nil
            State.ReturnPosZ = nil
            GENV.GG2_FromAutoExec = nil
            if not State.WeatherHiding then
                clearWeatherState()
            end
        end
    end)
end

function getAutoExecQueueScript()
    return [[
repeat task.wait() until game:IsLoaded()
local Players = game:GetService('Players')
if not Players.LocalPlayer then
    Players.PlayerAdded:Wait()
end

getgenv().GG2_AutoFarmRunning = nil
getgenv().GG2_FromAutoExec = true
getgenv().GG2_SkipRemoteUpdate = true

local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

local loadFn = loadstring or load

local function runSource(source, label)
    if not loadFn or type(source) ~= 'string' or source == '' then
        return false
    end

    getgenv().GG2_AutoFarmRunning = nil
    getgenv().GG2_FromAutoExec = true
    getgenv().GG2_SkipRemoteUpdate = true

    local func, err = loadFn(source, label or 'gg2')
    if not func then
        return false
    end

    return pcall(func)
end

for _, path in { 'GG2/gag2.lua', 'gag2.lua', 'GG2/loader.lua', 'loader.lua' } do
    if isfile(path) then
        if runSource(readfile(path), path) then
            return
        end
    end
end

local commit = 'main'
if isfile('GG2/commit.txt') then
    commit = readfile('GG2/commit.txt'):gsub('%s+', '')
end
if commit == '' then
    commit = 'main'
end

local loaderUrl = 'https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/' .. commit .. '/loader.lua'
local ok, source = pcall(function()
    return game:HttpGet(loaderUrl, true)
end)
if ok and type(source) == 'string' and source ~= '' and source ~= '404: Not Found' then
    runSource(source, 'gg2-loader')
    return
end

local okMain, sourceMain = pcall(function()
    return game:HttpGet('https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/main/loader.lua', true)
end)
if okMain and type(sourceMain) == 'string' and sourceMain ~= '' and sourceMain ~= '404: Not Found' then
    runSource(sourceMain, 'gg2-loader-main')
end
]]
end

function persistAutoExecBootstrap()
    if not writefile then
        return false
    end

    ensureGg2Folders()
    local scriptBody = getAutoExecQueueScript()
    local paths = {
        GG2_AUTOEXEC_FILE,
        'rejoin.lua',
        'autoexec/rejoin.lua',
        'Autoexec/rejoin.lua',
        'autoexec/GG2.lua',
        'Autoexec/GG2.lua',
    }

    for _, path in paths do
        pcall(function()
            writefile(path, scriptBody)
        end)
    end

    return true
end

function queueTeleportScript()
    local queue = getQueueOnTeleport()
    if not queue then
        return false
    end

    ensureCommitFile()
    persistAutoFarmScript()
    persistLoaderScript()
    persistAutoExecBootstrap()

    return pcall(function()
        queue(getAutoExecQueueScript())
    end)
end

function setupAutoExecute()
    ensureGg2Folders()
    ensureCommitFile()
    persistAutoFarmScript()
    persistLoaderScript()
    persistAutoExecBootstrap()

    if not getQueueOnTeleport() then
        return false
    end

    queueTeleportScript()

    if State.AutoExecTeleportConnection then
        State.AutoExecTeleportConnection:Disconnect()
        State.AutoExecTeleportConnection = nil
    end

    State.AutoExecTeleportConnection = LocalPlayer.OnTeleport:Connect(function()
        saveAutoExecWalkState()
        saveConfigBeforeTeleport()
        queueTeleportScript()
    end)

    return true
end

function stopAutoExecute()
    if State.AutoExecTeleportConnection then
        State.AutoExecTeleportConnection:Disconnect()
        State.AutoExecTeleportConnection = nil
    end
end

function teleportToHomeServer(placeId, jobId)
    if not placeId then
        return false
    end

    if game.PlaceId == placeId and (not jobId or game.JobId == jobId) then
        return true
    end

    if not jobId then
        return teleportToAnyGameServer(placeId)
    end

    for attempt = 1, 25 do
        State.WeatherReconnectPending = true
        queueTeleportScript()

        if attempt == 1 then
            task.wait(3)
        end

        local failed = false
        local failConn = TeleportService.TeleportInitFailed:Connect(function(player)
            if player == LocalPlayer then
                failed = true
            end
        end)

        pcall(function()
            if attempt <= 2 then
                TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
            else
                TeleportService:Teleport(placeId, LocalPlayer)
            end
        end)

        for _ = 1, 16 do
            if failed then
                break
            end
            task.wait(0.5)
        end

        failConn:Disconnect()

        if not failed then
            task.delay(10, function()
                State.WeatherReconnectPending = false
            end)
            return true
        end

        task.wait(math.min(3 + attempt * 0.75, 15))
    end

    State.WeatherReconnectPending = false
    return false
end

function teleportToAnyGameServer(placeId)
    placeId = tonumber(placeId) or game.PlaceId

    State.WeatherReconnectPending = true
    queueTeleportScript()
    task.wait(2)

    local failed = false
    local failConn = TeleportService.TeleportInitFailed:Connect(function(player)
        if player == LocalPlayer then
            failed = true
        end
    end)

    pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)

    for _ = 1, 16 do
        if failed then
            break
        end
        task.wait(0.5)
    end

    failConn:Disconnect()

    if not failed then
        task.delay(10, function()
            State.WeatherReconnectPending = false
        end)
        return true
    end

    State.WeatherReconnectPending = false
    return false
end

function isWeatherKickError(errorMessage)
    if not errorMessage or errorMessage == '' then
        return false
    end

    if string.find(errorMessage, '[AutoRejoin]', 1, true) then
        return true
    end

    local saved = GENV.GG2_WeatherState or readWeatherStateFile()
    return saved and saved.Hiding == true
end

function handleWeatherKickReconnect(errorMessage)
    if not State.WeatherKickPending and not isWeatherKickError(errorMessage) then
        return false
    end

    if os.clock() - (State.LastKickReconnectAttempt or 0) < 2 then
        return false
    end

    State.LastKickReconnectAttempt = os.clock()
    State.WeatherKickPending = false
    State.WeatherLeavePending = false
    State.WeatherReconnectPending = false

    queueTeleportScript()

    if State.WeatherHiding and not isWeatherHideTimerElapsed() then
        return true
    end

    if canRejoinHomeAfterWeather() then
        task.defer(tryRejoinHome)
    end

    return true
end

function shouldHandleWeatherReconnectError()
    local saved = GENV.GG2_WeatherState or readWeatherStateFile()
    if not saved or saved.Hiding ~= true then
        return false
    end

    if getWeatherClock() < (saved.HideUntil or 0) then
        return false
    end

    return true
end

function handleWeatherReconnectError(errorMessage)
    if not errorMessage or errorMessage == '' then
        return
    end

    if State.WeatherHiding and not isWeatherHideTimerElapsed() then
        if isStillOnWeatherHomeServer() then
            retryLeaveIfStillHome()
        end
        return
    end

    if not State.WeatherHiding and not State.WeatherReconnectPending then
        return
    end

    State.WeatherReconnectAttempts = (State.WeatherReconnectAttempts or 0) + 1
    if State.WeatherReconnectAttempts > 8 then
        State.WeatherReconnectAttempts = 0
        if Library and Library.Notify then
            Library:Notify('Teleport failed - joining any server')
        end
        local saved = GENV.GG2_WeatherState or readWeatherStateFile()
        local placeId = tonumber(saved and saved.ReturnPlaceId) or game.PlaceId
        clearWeatherState({ keepWalkBack = true })
        teleportToAnyGameServer(placeId)
        return
    end

    if os.clock() - (State.LastWeatherReconnectAttempt or 0) < 2 then
        return
    end
    State.LastWeatherReconnectAttempt = os.clock()

    if Library and Library.Notify then
        Library:Notify(string.format('Reconnect failed, retrying home (%d/8)...', State.WeatherReconnectAttempts))
    end

    task.wait(2)

    local saved = GENV.GG2_WeatherState or readWeatherStateFile()
    if saved and saved.ReturnPlaceId and saved.ReturnJobId then
        queueTeleportScript()
        if teleportToHomeServer(saved.ReturnPlaceId, saved.ReturnJobId) then
            return
        end
    end
end

function setupWeatherErrorReconnect()
    if State.WeatherErrorReconnectConnection then
        return
    end

    State.WeatherErrorReconnectConnection = GuiService.ErrorMessageChanged:Connect(function(errorMessage)
        task.spawn(function()
            if handleWeatherKickReconnect(errorMessage) then
                return
            end

            if State.WeatherHiding and isWeatherHideTimerElapsed() then
                handleWeatherReconnectError(errorMessage)
            elseif State.WeatherReconnectPending and not State.WeatherHiding then
                handleWeatherReconnectError(errorMessage)
            end
        end)
    end)

    task.defer(function()
        local currentError = GuiService:GetErrorMessage()
        if currentError and currentError ~= '' then
            if handleWeatherKickReconnect(currentError) then
                return
            end
            if State.WeatherHiding and isWeatherHideTimerElapsed() then
                handleWeatherReconnectError(currentError)
            end
        end
    end)
end

function stopWeatherErrorReconnect()
    if State.WeatherErrorReconnectConnection then
        State.WeatherErrorReconnectConnection:Disconnect()
        State.WeatherErrorReconnectConnection = nil
    end
end

function startWeatherHideWait()
    if not State.WeatherHiding or isWeatherHideTimerElapsed() then
        return
    end

    task.spawn(function()
        while State.WeatherHiding and not isWeatherHideTimerElapsed() do
            task.wait(1)
            updateWeatherLabels()
        end

        if not State.ReturnPlaceId then
            return
        end

        if game.PlaceId == State.ReturnPlaceId and (not State.ReturnJobId or game.JobId == State.ReturnJobId) then
            State.WeatherHiding = false
            clearRejoinTarget()
            saveAutoExecWalkState()
            queueTeleportScript()
            State.StartupWalkDone = false
            doStartupWalk()
            return
        end

        if State.WeatherHiding then
            tryRejoinHome()
        end
    end)
end

function startWeatherRejoinWorker()
    if not State.WeatherHiding or not State.ReturnPlaceId then
        return
    end

    if game.PlaceId == State.ReturnPlaceId and (not State.ReturnJobId or game.JobId == State.ReturnJobId) then
        if isWeatherHideTimerElapsed() then
            tryRejoinHome()
        else
            startWeatherHideWait()
        end
        return
    end

    task.spawn(function()
        while State.WeatherHiding and not isWeatherHideTimerElapsed() do
            task.wait(1)
            updateWeatherLabels()
        end

        if not State.WeatherHiding or not State.ReturnPlaceId or not State.ReturnJobId then
            return
        end

        tryRejoinHome()
    end)
end

function getBlockedWeathers()
    return getMultiSelect('BlockedWeathers')
end

function getActiveNightMoon()
    local activeWeather = workspace:GetAttribute('ActiveWeather')
    if activeWeather and NIGHT_MOON_GAME_NAMES[activeWeather] then
        return activeWeather, workspace:GetAttribute('PhaseDuration')
    end

    return nil
end

function isNightMoonBlocked(gameName, blocked)
    local label = NIGHT_MOON_LABELS[gameName]
    if label and blocked[label] then
        return true
    end

    if gameName == 'Rainbow Moon' and blocked.Rainbow then
        return true
    end

    return blocked[gameName] == true
end

function getActiveEventWeathers()
    local active = {}

    for _, weatherName in EVENT_WEATHERS do
        if WeatherValues:GetAttribute(weatherName .. '_Playing') == true then
            active[weatherName] = WeatherValues:GetAttribute(weatherName .. '_EndTime')
        end
    end

    return active
end

function getCurrentWeatherText()
    local parts = {}
    local moonName = select(1, getActiveNightMoon())

    if moonName then
        table.insert(parts, NIGHT_MOON_LABELS[moonName] or moonName)
    end

    for weatherName in getActiveEventWeathers() do
        table.insert(parts, weatherName)
    end

    if #parts == 0 then
        return 'None'
    end

    return table.concat(parts, ', ')
end

function findBlockedWeather(blocked)
    local moonName, moonEnd = getActiveNightMoon()
    if moonName and isNightMoonBlocked(moonName, blocked) then
        return moonName, moonEnd
    end

    for weatherName, endTime in getActiveEventWeathers() do
        if blocked[weatherName] then
            return weatherName, endTime
        end
    end

    return nil
end

function getWeatherDisplayName(gameName)
    return NIGHT_MOON_LABELS[gameName] or gameName
end

function updateWeatherLabels()
    if CurrentWeatherLabel then
        CurrentWeatherLabel:SetText('Active Event: ' .. getCurrentWeatherText())
    end

    if not WeatherStatusLabel then
        return
    end

    if State.WeatherHiding then
        local remaining = math.max(0, State.HideUntil - getWeatherClock())
        WeatherStatusLabel:SetText(string.format('Weather: Hiding from %s (%ds)', State.HidingFromWeather or '?', remaining))
    elseif Toggles.WeatherDodge and Toggles.WeatherDodge.Value then
        WeatherStatusLabel:SetText('Weather: Watching')
    else
        WeatherStatusLabel:SetText('Weather: Disabled')
    end
end

function tryRejoinHome()
    if State.WeatherHiding and not isWeatherHideTimerElapsed() then
        return
    end

    if not State.ReturnPlaceId then
        clearWeatherState()
        return
    end

    if game.PlaceId == State.ReturnPlaceId and (not State.ReturnJobId or game.JobId == State.ReturnJobId) then
        State.WeatherHiding = false
        clearRejoinTarget()
        saveAutoExecWalkState()
        queueTeleportScript()
        State.StartupWalkDone = false
        doStartupWalk()
        return
    end

    if not State.ReturnJobId then
        clearWeatherState()
        return
    end

    Library:Notify('Weather ended - rejoining your server')

    local placeId = State.ReturnPlaceId
    local jobId = State.ReturnJobId
    State.WeatherHiding = false
    saveAutoExecWalkState()
    saveWeatherState()
    queueTeleportScript()

    if not teleportToHomeServer(placeId, jobId) then
        Library:Notify('Rejoin failed - joining any server')
        teleportToAnyGameServer(placeId)
    end
end

function isStillOnWeatherHomeServer()
    return State.ReturnPlaceId == game.PlaceId
        and State.ReturnJobId ~= nil
        and game.JobId == State.ReturnJobId
end

function teleportAwayFromHomeServer(maxAttempts)
    maxAttempts = maxAttempts or 10
    local placeId = game.PlaceId

    ensureCommitFile()
    queueTeleportScript()
    State.WeatherLeavePending = true

    for attempt = 1, maxAttempts do
        if not isStillOnWeatherHomeServer() then
            State.WeatherLeavePending = false
            return true
        end

        local failed = false
        local failConn = TeleportService.TeleportInitFailed:Connect(function(player)
            if player == LocalPlayer then
                failed = true
            end
        end)

        pcall(function()
            TeleportService:Teleport(placeId, LocalPlayer)
        end)

        for _ = 1, 20 do
            if failed then
                break
            end
            if not isStillOnWeatherHomeServer() then
                break
            end
            task.wait(0.5)
        end

        failConn:Disconnect()

        if not isStillOnWeatherHomeServer() then
            State.WeatherLeavePending = false
            return true
        end

        task.wait(math.min(attempt, 3))
    end

    State.WeatherLeavePending = false
    return not isStillOnWeatherHomeServer()
end

function forceLeaveServer()
    if not isStillOnWeatherHomeServer() then
        return true
    end

    local ok = teleportAwayFromHomeServer()
    if ok then
        return true
    end

    if Library and Library.Notify then
        Library:Notify('Weather dodge failed - could not leave server')
    end

    return false
end

function retryLeaveIfStillHome()
    if not State.WeatherHiding or not isStillOnWeatherHomeServer() then
        return
    end

    if isWeatherHideTimerElapsed() then
        tryRejoinHome()
        return
    end

    if os.clock() - (State.LastWeatherLeaveAttempt or 0) < 8 then
        return
    end
    State.LastWeatherLeaveAttempt = os.clock()

    local remaining = math.max(0, State.HideUntil - getWeatherClock())
    if Library and Library.Notify then
        Library:Notify(string.format(
            'Leaving for %s - auto rejoin in %ds',
            State.HidingFromWeather or 'Weather',
            math.max(remaining, 30)
        ))
    end

    forceLeaveServer()
end

function leaveForWeather(weatherGameName, endTime)
    if State.WeatherHiding then
        retryLeaveIfStillHome()
        return
    end

    State.WeatherHiding = true
    State.HidingFromWeather = getWeatherDisplayName(weatherGameName)
    State.ReturnPlaceId = game.PlaceId
    State.ReturnJobId = game.JobId
    State.HideUntil = normalizeWeatherHideUntil(endTime)
    saveWeatherReturnPosition()
    saveAutoExecWalkState()
    saveWeatherState()

    local remaining = math.max(30, State.HideUntil - getWeatherClock())

    saveWeatherState()

    if not writefile then
        clearWeatherState()
        Library:Notify('Weather dodge needs writefile support to save rejoin info')
        return
    end

    if Library and Library.Notify then
        Library:Notify(string.format(
            'Leaving for %s - auto rejoin in %ds',
            getWeatherDisplayName(weatherGameName),
            remaining
        ))
    end

    State.LastWeatherLeaveAttempt = os.clock()
    forceLeaveServer()
end

function setWeatherDodge(enabled)
    State.WeatherMonitorStop = not enabled

    if State.WeatherMonitorThread then
        task.cancel(State.WeatherMonitorThread)
        State.WeatherMonitorThread = nil
    end

    if not enabled then
        updateWeatherLabels()
        return
    end

    State.WeatherMonitorThread = task.spawn(function()
        while not State.WeatherMonitorStop and not Library.Unloaded do
            updateWeatherLabels()

            if State.WeatherHiding then
                if isStillOnWeatherHomeServer() then
                    retryLeaveIfStillHome()
                elseif isWeatherHideTimerElapsed() then
                    tryRejoinHome()
                end
            elseif Toggles.WeatherDodge and Toggles.WeatherDodge.Value then
                local blocked = getBlockedWeathers()
                local weatherName, endTime = findBlockedWeather(blocked)

                if weatherName then
                    leaveForWeather(weatherName, endTime)
                end
            end

            task.wait(0.5)
        end
    end)
end

local Window = Library:CreateWindow({
    Title = 'Grow a Garden 2 - Auto Farm',
    Center = true,
    AutoShow = true,
    Size = UDim2.fromOffset(620, 580),
    TabPadding = 8,
    MenuFadeTime = 0.2,
    ShowCustomCursor = false,
    UnlockMouseWhileOpen = true,
})

Library.ShowCustomCursor = false

task.spawn(function()
    while not Library.Unloaded do
        if not Library.Toggled then
            UserInputService.MouseIconEnabled = true
        end
        task.wait(0.25)
    end
end)

local Tabs = {
    Main = Window:AddTab('Main'),
    Fruits = Window:AddTab('Fruits'),
    Mail = Window:AddTab('Mail'),
    Settings = Window:AddTab('Settings'),
}

local GearBox = Tabs.Main:AddLeftGroupbox('Auto Gear')
local StatsBox = Tabs.Main:AddLeftGroupbox('Stats')
local WeatherBox = Tabs.Main:AddLeftGroupbox('Weather Dodge')
local FarmBox = Tabs.Main:AddRightGroupbox('Auto Farm')
local BuyBox = Tabs.Main:AddRightGroupbox('Auto Buy')
local AuctionBox = Tabs.Main:AddRightGroupbox('Auto Auction')

local MailClaimBox = Tabs.Mail:AddLeftGroupbox('Auto Claim')
local MailSendBox = Tabs.Mail:AddRightGroupbox('Send Gift')

local FruitsBox = Tabs.Fruits:AddLeftGroupbox('Fruits')
FruitsStatusLabel = FruitsBox:AddLabel('Auto-refreshes when you open this tab', true)
FruitsBox:AddDropdown('GardenFruitList', {
    Text = 'Fruits',
    Values = { 'Open tab to load fruits' },
    Multi = true,
    Default = {},
    Tooltip = 'Unharvested fruits at or above Max Harvest KG',
})
FruitsBox:AddButton({
    Text = 'Claim Selected',
    Func = function()
        task.spawn(claimSelectedGardenFruits)
    end,
})
hookFruitsTabAutoScan(Tabs.Fruits)

local OptimizerBox = Tabs.Settings:AddLeftGroupbox('Optimizer')
local MenuBox = Tabs.Settings:AddRightGroupbox('Menu')

GearBox:AddDropdown('TargetPlant', {
    Text = 'Target Plant',
    Values = { 'None' },
    Default = 'None',
    Tooltip = 'Centers sprinkler/watering on this plant type on your current plot',
    Callback = function(value)
        if type(value) == 'string' and value ~= '' and value ~= 'None' then
            State.ConfigTargetPlant = value
            saveTargetPlantFile(value)
        else
            State.ConfigTargetPlant = nil
            saveTargetPlantFile('')
        end
    end,
})

GearBox:AddButton({
    Text = 'Refresh Plant List',
    Func = function()
        refreshTargetPlantDropdown()
        Library:Notify('Plant list refreshed')
    end,
})

GearBox:AddToggle('AutoWalkToPlant', {
    Text = 'Walk To Target',
    Default = true,
    Tooltip = 'Walks to the plant cluster before using sprinkler or watering can',
})

GearBox:AddToggle('AutoSprinkler', {
    Text = 'Auto Super Sprinkler',
    Default = false,
    Tooltip = 'Keeps 1 Super Sprinkler at the target plant center (radius ' .. tostring(sprinklerRadius) .. ')',
})

GearBox:AddToggle('AutoWateringCan', {
    Text = 'Auto Super Watering Can',
    Default = false,
    Tooltip = 'Uses 1 Super Watering Can at the target plant center on the interval below',
    Callback = function(value)
        setAutoWateringLoop(value)
    end,
})

GearBox:AddInput('WateringCanInterval', {
    Text = 'Watering Can Interval (s)',
    Default = '10',
    Numeric = true,
    Finished = false,
    Tooltip = 'Seconds between each Super Watering Can use (1-300)',
})

FarmBox:AddToggle('AutoHarvest', {
    Text = 'Auto Harvest',
    Default = false,
    Callback = function(value)
        setAutoHarvestLoop(value)
    end,
})

FarmBox:AddDropdown('HarvestPlantTypes', {
    Text = 'Harvest Plant Types',
    Values = { 'Open tab to load plant types' },
    Multi = true,
    Default = {},
    Tooltip = 'Only checked plant types get auto-harvested. Defaults to every type; uncheck all to harvest nothing.',
    Callback = function()
        if State.ConfigLoading then
            return
        end

        captureConfigHarvestPlants()
    end,
})

FarmBox:AddButton({
    Text = 'Refresh Plant Types',
    Func = function()
        refreshHarvestPlantsDropdown()
        Library:Notify('Plant type list refreshed')
    end,
})

FarmBox:AddInput('MaxHarvestKg', {
    Text = 'Max Harvest KG',
    Default = '50',
    Numeric = true,
    Finished = false,
    Tooltip = 'Auto harvest/sell below this KG. Fruits tab shows fruits at or above this KG.',
})

if Options.MaxHarvestKg then
    Options.MaxHarvestKg:OnChanged(function()
        task.defer(refreshFruitsList)
    end)
end

FarmBox:AddToggle('AutoSell', {
    Text = 'Auto Sell',
    Default = false,
    Tooltip = 'Sells fruits below Max Harvest KG every 1s (uses SellAll, keeps heavy/favorite fruits)',
    Callback = function(value)
        setAutoSellLoop(value)
    end,
})

FarmBox:AddToggle('AutoHatchEggs', {
    Text = 'Auto Hatch Eggs',
    Default = false,
    Tooltip = 'Auto-hatches Black Dragon eggs in your garden and egg tools in your backpack',
    Callback = function(value)
        setAutoHatchLoop(value)
    end,
})

WeatherBox:AddToggle('WeatherDodge', {
    Text = 'Enable Weather Dodge',
    Default = false,
    Tooltip = 'Teleports you out when a selected event starts, then auto-rejoins your server when it ends.',
    Callback = function(value)
        setWeatherDodge(value)
    end,
})

WeatherBox:AddDropdown('BlockedWeathers', {
    Text = 'Bad Events',
    Values = BLOCKABLE_WEATHERS,
    Multi = true,
    Default = {},
    Tooltip = 'Events + night moons (Gold, Blood, Mega). Rainbow covers Rainbow event and Rainbow Moon.',
})

WeatherStatusLabel = WeatherBox:AddLabel('Weather: Disabled', true)
CurrentWeatherLabel = WeatherBox:AddLabel('Active Event: None', true)

BuyBox:AddToggle('AutoBuy', {
    Text = 'Enable Auto Buy',
    Default = false,
    Tooltip = 'Instantly buys selected items when they are in stock and you can afford them',
    Callback = function(value)
        setAutoBuyLoop(value)
    end,
})

BuyBox:AddDropdown('AutoBuyGears', {
    Text = 'Gears',
    Values = BUY_GEARS,
    Multi = true,
    Default = {},
})

BuyBox:AddDropdown('AutoBuySeeds', {
    Text = 'Seeds',
    Values = BUY_SEEDS,
    Multi = true,
    Default = {},
})

BuyBox:AddDropdown('AutoBuyProps', {
    Text = 'Props',
    Values = BUY_PROPS,
    Multi = true,
    Default = {},
})

AuctionBox:AddDropdown('AuctionBuySeeds', {
    Text = 'Select Seed',
    Values = #AUCTION_SEEDS > 0 and AUCTION_SEEDS or { 'No seeds found' },
    Multi = true,
    Default = {},
    Tooltip = 'Auction lots to auto-buy when they appear',
})

AuctionBox:AddDropdown('AuctionBuyGears', {
    Text = 'Select Gear',
    Values = #AUCTION_GEARS > 0 and AUCTION_GEARS or { 'No gears found' },
    Multi = true,
    Default = {},
})

AuctionBox:AddDropdown('AuctionBuySeedPacks', {
    Text = 'Select Seed Pack',
    Values = #AUCTION_SEED_PACKS > 0 and AUCTION_SEED_PACKS or { 'No seed packs found' },
    Multi = true,
    Default = {},
})

AuctionBox:AddDropdown('AuctionBuyEggs', {
    Text = 'Select Egg',
    Values = #AUCTION_EGGS > 0 and AUCTION_EGGS or { 'No eggs found' },
    Multi = true,
    Default = {},
})

AuctionBox:AddDropdown('AuctionPriceMode', {
    Text = 'Auction Price Mode',
    Values = { 'Below', 'Above', 'At' },
    Default = 'Below',
    Tooltip = 'Below = buy when price is at or under your limit. Above = at or over. At = exact price.',
})

AuctionBox:AddInput('AuctionPrice', {
    Text = 'Auction Price',
    Default = '0',
    Numeric = true,
    Tooltip = "Sheckles price filter. Leave at 0 to ignore price. With no items selected, buys any sheckle lot matching this filter.",
})

AuctionBox:AddToggle('AutoBuyAuction', {
    Text = 'Auto Buy Auction',
    Default = false,
    Tooltip = 'Buys auction lots with sheckles. Use price limit alone, or pick specific items in the dropdowns.',
    Callback = function(value)
        setAutoAuctionLoop(value)
    end,
})

local EarningsLabel = StatsBox:AddLabel('Earnings/min: 0?', true)
local SprinklerLabel = StatsBox:AddLabel('Sprinkler: None', true)

OptimizerBox:AddToggle('Optimizer', {
    Text = 'Enable Optimizer',
    Default = false,
    Tooltip = 'Matches the high-FPS optimizers (~160+): unlocks FPS past 60, night sky, lowest graphics, deletes other players\' gardens + characters/NPCs, and strips YOUR plant visuals (empty dirt beds) while keeping plant models so auto-harvest still works. Other gardens only come back after rejoin.',
    Callback = function(value)
        if State.ConfigLoading then
            return
        end

        if value then
            scheduleOptimizerApply()
        else
            setOptimizer(false)
        end
    end,
})

OptimizerBox:AddToggle('CameraBlackout', {
    Text = 'Camera Blackout (Max FPS)',
    Default = false,
    Tooltip = 'Extreme mode: yanks the camera 1,000,000,000,000 studs below the map and blanks every mesh ID so nothing renders at all. Screen goes blank - farming/UI still work, but you won\'t see the game. Turn off to restore your view.',
    Callback = function(value)
        if State.ConfigLoading then
            return
        end

        setCameraBlackout(value)
    end,
})

function shutdownScript()
    if Library.Unloaded then
        return
    end

    Library.Unloaded = true
    State.WateringStop = true
    State.WeatherMonitorStop = true
    State.MailAutoClaimStop = true

    cancelOptimizerPendingApply()
    pcall(setOptimizer, false)
    pcall(setCameraBlackout, false)
    pcall(setAutoHarvestLoop, false)
    pcall(setAutoWateringLoop, false)
    pcall(setAutoBuyLoop, false)
    pcall(setAutoAuctionLoop, false)
    pcall(setAutoHatchLoop, false)
    pcall(setAutoSellLoop, false)
    pcall(setWeatherDodge, false)
    pcall(stopWeatherErrorReconnect)
    pcall(stopMailAutoClaim)
    pcall(setAntiAfk, false)
    pcall(stopAutoExecute)

    if State.LoadingDismissThread then
        pcall(task.cancel, State.LoadingDismissThread)
        State.LoadingDismissThread = nil
    end

    pcall(function()
        Library:Unload()
    end)

    GENV.GG2_AutoFarmRunning = false
    GENV.GG2_Library = nil
end

GENV.GG2_AutoFarmShutdown = shutdownScript
GENV.GG2_Library = Library

MenuBox:AddToggle('AntiAfk', {
    Text = 'Anti AFK',
    Default = true,
    Tooltip = 'Prevents Roblox from kicking you for being idle.',
    Callback = function(value)
        setAntiAfk(value)
    end,
})

MenuBox:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'RightShift',
    NoUI = true,
    Text = 'Menu keybind',
})

Library.ToggleKeybind = Options.MenuKeybind

MenuBox:AddButton({
    Text = 'Unload Script',
    Func = function()
        shutdownScript()
        pcall(function()
            Library:Unload()
        end)
    end,
})

local MailClaimStatus = MailClaimBox:AddLabel('Claimed: 0 | Failed: 0 | Status: Idle', true)
local MailProgressLabel = MailClaimBox:AddLabel('Progress: -', true)

function updateMailClaimLabels(running)
    MailClaimStatus:SetText(string.format(
        'Claimed: %d | Failed: %d | Status: %s',
        State.MailTotals.Claimed or 0,
        State.MailTotals.Failed or 0,
        running and 'Running' or 'Idle'
    ))
end

function stopMailAutoClaim()
    State.MailAutoClaimStop = true
    if State.MailAutoClaimThread then
        pcall(task.cancel, State.MailAutoClaimThread)
        State.MailAutoClaimThread = nil
    end
    updateMailClaimLabels(false)
end

MailClaimBox:AddToggle('MailAutoClaim', {
    Text = 'Enable Auto Claim',
    Default = false,
    Tooltip = 'Auto claims mailbox gifts every 15 seconds',
    Callback = function(value)
        stopMailAutoClaim()

        if not value then
            return
        end

        State.MailAutoClaimStop = false
        updateMailClaimLabels(true)

        State.MailAutoClaimThread = task.spawn(function()
            while not State.MailAutoClaimStop and not Library.Unloaded do
                local claimed = claimAllInbox(function(i, total, fromName, ok)
                    MailProgressLabel:SetText(string.format('Progress: %d/%d (from %s) %s', i, total, tostring(fromName), ok and 'OK' or 'FAIL'))
                    updateMailClaimLabels(true)
                end, 0.35, 2)

                if claimed > 0 then
                    Library:Notify(string.format('Mail: claimed %d gift(s)', claimed))
                end

                local waited = 0
                while not State.MailAutoClaimStop and waited < 15 do
                    task.wait(1)
                    waited += 1
                end
            end
        end)
    end,
})

local RecipientBox = MailSendBox:AddInput('MailRecipient', {
    Default = '',
    Numeric = false,
    Finished = false,
    Text = 'Recipient (username or userId)',
    Tooltip = 'Enter a username, display name, or userId',
})

local AmountBox = MailSendBox:AddInput('MailAmount', {
    Default = '1',
    Numeric = true,
    Finished = false,
    Text = 'Amount (bypasses 20 cap)',
})

local NoteBox = MailSendBox:AddInput('MailNote', {
    Default = '',
    Numeric = false,
    Finished = false,
    Text = 'Note (optional)',
})

local MailSelectedLabel = MailSendBox:AddLabel('Selected: none', true)
local MailSendStatus = MailSendBox:AddLabel('Ready', true)

local MailInventoryItems = {}
local MailInventoryLabels = {}
local SelectedMailItem

function refreshMailInventory()
    MailInventoryItems = getGiftableInventory()
    MailInventoryLabels = {}
    SelectedMailItem = nil

    for _, item in ipairs(MailInventoryItems) do
        table.insert(MailInventoryLabels, item.label)
    end

    if Options and Options.MailInventory then
        Options.MailInventory.Values = MailInventoryLabels
        Options.MailInventory:SetValues(MailInventoryLabels)
        Options.MailInventory:SetValue(MailInventoryLabels[1] or '')
    end

    if #MailInventoryLabels == 0 then
        MailSelectedLabel:SetText('Selected: none (empty)')
    end

    local fruitCount = 0
    for _, item in ipairs(MailInventoryItems) do
        if item.category == 'HarvestedFruits' then
            fruitCount += 1
        end
    end
    MailSendStatus:SetText(string.format('Inventory loaded (%d items, %d fruits)', #MailInventoryItems, fruitCount))
end

MailSendBox:AddDropdown('MailInventory', {
    Text = 'Inventory item',
    Values = { },
    Default = '',
    Multi = false,
    Tooltip = 'Select an item to gift',
    Callback = function(value)
        SelectedMailItem = nil
        for _, item in ipairs(MailInventoryItems) do
            if item.label == value then
                SelectedMailItem = item
                break
            end
        end

        if SelectedMailItem then
            local displayCategory = SelectedMailItem.category
            if displayCategory == 'HarvestedFruits' then
                displayCategory = 'Fruits'
            elseif displayCategory == 'WateringCans' then
                displayCategory = 'Cans'
            end
            MailSelectedLabel:SetText(string.format('Selected: %s / %s (%d)', displayCategory, SelectedMailItem.key, SelectedMailItem.count))
        else
            MailSelectedLabel:SetText('Selected: none')
        end
    end,
})

MailSendBox:AddButton({
    Text = 'Refresh Inventory',
    Func = function()
        refreshMailInventory()
        MailSendStatus:SetText('Inventory refreshed')
    end,
})

MailSendBox:AddButton({
    Text = 'Send Gift',
    Func = function()
        MailSendStatus:SetText('Sending...')

        task.spawn(function()
            local recipientId, err = resolveRecipientId(RecipientBox.Value)
            if not recipientId then
                MailSendStatus:SetText('Error: ' .. tostring(err or 'Invalid recipient'))
                return
            end

            local ok, msg = sendGiftBatch(recipientId, SelectedMailItem, AmountBox.Value, NoteBox.Value)
            MailSendStatus:SetText((ok and 'OK: ' or 'Error: ') .. tostring(msg))

            if ok then
                refreshMailInventory()
            end
        end)
    end,
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder('GrowGarden2AutoFarm')
SaveManager:SetFolder('GrowGarden2AutoFarm')
SaveManager:BuildConfigSection(Tabs.Settings)

do
    local rawSave = SaveManager.Save
    function SaveManager:Save(name)
        captureConfigTargetPlant()
        captureConfigHarvestPlants()
        return rawSave(self, name)
    end

    local rawLoad = SaveManager.Load
    function SaveManager:Load(name)
        local ok, err = rawLoad(self, name)
        task.defer(function()
            task.wait(0.05)
            syncTargetPlantFromSavedConfig()
            refreshTargetPlantDropdown()
            syncHarvestPlantsFromSavedConfig()
            refreshHarvestPlantsDropdown()
        end)
        return ok, err
    end
end

ThemeManager:ApplyToTab(Tabs.Settings)

loadWeatherState()
setupWeatherErrorReconnect()
setupAuctionNetworking()

if State.WeatherHiding then
    if isWeatherHideTimerElapsed() then
        if isStillOnWeatherHomeServer() then
            task.defer(tryRejoinHome)
        else
            task.defer(tryRejoinHome)
            startWeatherRejoinWorker()
        end
    else
        if isStillOnWeatherHomeServer() then
            task.defer(function()
                retryLeaveIfStillHome()
            end)
        end
        startWeatherHideWait()
    end
elseif State.ReturnPlaceId and game.PlaceId == State.ReturnPlaceId then
    if not State.PendingWalkToSaved
        and not State.PendingWalkBack
        and not GENV.GG2_FromAutoExec then
        clearRejoinTarget()
    end
end

setupAutoExecute()
startLoadingScreenAutoDismiss()
persistAutoFarmScript()
persistLoaderScript()

if getQueueOnTeleport() and writefile then
    task.defer(function()
        if Library and Library.Notify then
            Library:Notify('Auto-exec queued. For menu rejoin: add GG2/rejoin.lua to Volt autoexec folder')
        end
    end)
end

task.spawn(function()
    local remoteOk, remoteStatus = tryUpdateFromRemote()
    State.RemoteSyncStatus = remoteStatus

    if remoteStatus == 'updated' and Library and Library.Notify then
        Library:Notify('Script updated from GitHub')
    end
end)

if not getQueueOnTeleport() then
    task.defer(function()
        if Library and Library.Notify then
            Library:Notify('Auto-exec needs queue_on_teleport (Potassium supports this)')
        end
    end)
elseif not isfile(GG2_SCRIPT_PATH) and not isfile(AUTO_FARM_SCRIPT) and not persistAutoFarmScript() then
    task.defer(function()
        if Library and Library.Notify then
            Library:Notify('Run loader.lua first so auto-exec can save the script to workspace')
        end
    end)
end

task.defer(function()
    State.ConfigLoading = true
    SaveManager:LoadAutoloadConfig()
    State.ConfigLoading = false
    syncTargetPlantFromSavedConfig()
    captureConfigTargetPlant()
    syncHarvestPlantsFromSavedConfig()
    if Options.MenuKeybind then
        Library.ToggleKeybind = Options.MenuKeybind
    end
    if Toggles.AntiAfk and Toggles.AntiAfk.Value then
        setAntiAfk(true)
    end

    if Toggles.Optimizer and Toggles.Optimizer.Value then
        scheduleOptimizerApply()
    end

    if Toggles.CameraBlackout and Toggles.CameraBlackout.Value then
        setCameraBlackout(true)
    end

    waitForGardenReady(45)
    refreshTargetPlantDropdown()
    refreshHarvestPlantsDropdown()
    doStartupWalk()

    if Toggles.AutoWateringCan and Toggles.AutoWateringCan.Value then
        setAutoWateringLoop(true)
    end
    if Toggles.AutoSell and Toggles.AutoSell.Value then
        setAutoSellLoop(true)
    end
    if Toggles.AutoBuy and Toggles.AutoBuy.Value then
        setAutoBuyLoop(true)
    end
    if Toggles.AutoBuyAuction and Toggles.AutoBuyAuction.Value then
        setAutoAuctionLoop(true)
    end
    if Toggles.AutoHatchEggs and Toggles.AutoHatchEggs.Value then
        setAutoHatchLoop(true)
    end

    task.defer(refreshAuctionItemListsFromCatalog)
    task.defer(requestAuctionSnapshot)
    if Toggles.WeatherDodge and Toggles.WeatherDodge.Value then
        setWeatherDodge(true)
    elseif State.WeatherHiding and not isWeatherHideTimerElapsed() then
        setWeatherDodge(true)
    elseif State.WeatherHiding and isWeatherHideTimerElapsed() then
        task.defer(tryRejoinHome)
    end

    task.wait(1.5)

    if Toggles.AutoHarvest and Toggles.AutoHarvest.Value then
        setAutoHarvestLoop(true)
    end

    task.wait(0.1)
    pcall(refreshMailInventory)
    updateWeatherLabels()
    queueTeleportScript()
end)

LocalPlayer:GetAttributeChangedSignal('PlotId'):Connect(function()
    task.defer(function()
        waitForGardenReady(20)
        syncTargetPlantFromSavedConfig()
        refreshTargetPlantDropdown()
        syncHarvestPlantsFromSavedConfig()
        refreshHarvestPlantsDropdown()
    end)
end)

Library:OnUnload(function()
    shutdownScript()
end)

task.spawn(function()
    while not Library.Unloaded do
        if Toggles.AutoSprinkler and Toggles.AutoSprinkler.Value then
            placeSuperSprinkler()
        end

        updateWeatherLabels()

        EarningsLabel:SetText('Earnings/min: ' .. abbreviate(getEarningsPerMinute()))

        local active, _, _, remaining = getActiveSuperSprinkler()
        if active then
            SprinklerLabel:SetText(string.format('Sprinkler: Active (%ds left)', math.floor(remaining)))
        else
            SprinklerLabel:SetText('Sprinkler: None')
        end

        task.wait(0.5)
    end
end)

Library:Notify('Grow a Garden 2 Auto Farm loaded! Pick a target plant in Gear.')
