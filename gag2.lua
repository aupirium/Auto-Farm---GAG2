-- Grow a Garden 2 - Auto Farm (LinoriaLib)
-- Auto Super Sprinkler / Watering Can at saved position, auto harvest, auto sell, earnings/min

local GENV = getgenv()

if GENV.GG2_AutoFarmShutdown then
    pcall(GENV.GG2_AutoFarmShutdown)
    task.wait(0.05)
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

local DEFAULT_REMOTE_SCRIPT_URL = 'https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/main/gag2.lua'
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
            return game:HttpGet('https://github.com/aupirium/Auto-Farm---GAG2', true)
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
    local remote = httpGetEarly('https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/' .. commit .. '/gag2.lua')
    if not remote then
        remote = httpGetEarly('https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/main/gag2.lua')
    end

    if remote then
        remote = stripBomEarly(remote)
        local localSrc = nil

        for _, path in { 'GG2/grow_garden_autofarm.lua', 'grow_garden_autofarm.lua' } do
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
            writefile('GG2/grow_garden_autofarm.lua', remote)
            writefile('grow_garden_autofarm.lua', remote)
        end)

        if localSrc and localSrc ~= remote then
            GENV.GG2_SkipRemoteUpdate = true
            if GENV.GG2_AutoFarmShutdown then
                pcall(GENV.GG2_AutoFarmShutdown)
                task.wait(0.05)
            end
            GENV.GG2_AutoFarmRunning = false
            local func = loadstring(remote, 'grow_garden_autofarm.lua')
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
local AUTO_FARM_SCRIPT = 'grow_garden_autofarm.lua'
local GG2_SCRIPT_PATH = 'GG2/grow_garden_autofarm.lua'
local GG2_COMMIT_FILE = 'GG2/commit.txt'
local GG2_PLACE_ID = 97598239454123
local GG2_REPO = 'aupirium/Auto-Farm---GAG2'

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
        writefile(GG2_COMMIT_FILE, commit)
    end)
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
        return game:HttpGet('https://github.com/aupirium/Auto-Farm---GAG2', true)
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
        'https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/' .. commit .. '/gag2.lua',
        'https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/main/gag2.lua',
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
    for _, path in { GG2_SCRIPT_PATH, AUTO_FARM_SCRIPT } do
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

    for _, path in {
        AUTO_FARM_SCRIPT,
        GG2_SCRIPT_PATH,
        'workspace/' .. AUTO_FARM_SCRIPT,
        'scripts/' .. AUTO_FARM_SCRIPT,
    } do
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

function tryUpdateFromRemote()
    if GENV.GG2_SkipRemoteUpdate or GENV.GG2_FromAutoExec then
        return false, 'skipped'
    end

    return syncWorkspaceFromRemote()
end

function saveConfigBeforeTeleport()
    pcall(function()
        if not SaveManager or not isfile then
            return
        end

        local autoloadPath = 'GrowGarden2AutoFarm/settings/autoload.txt'
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

-- Mail / gifts
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

for _, entry in SprinklerData do
    if entry.SprinklerName == SUPER_SPRINKLER then
        sprinklerLifetime = entry.Lifetime or sprinklerLifetime
        break
    end
end

local State = {
    SavedPosition = nil,
    LastSprinklerPlace = 0,
    LastWatering = 0,
    LastSell = 0,
    EarningsWindow = {},
    NoclipConnection = nil,
    NoclipPlantState = {},
    NoclipPlantConnection = nil,
    HarvestConnection = nil,
    HarvestThread = nil,
    WateringConnection = nil,
    WateringStop = false,
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
    WeatherReconnectPending = false,
    WeatherKickPending = false,
    WeatherReconnectAttempts = 0,
    LastWeatherReconnectAttempt = 0,
    LastKickReconnectAttempt = 0,
    LastWeatherLeaveAttempt = 0,
    AutoBuyThread = nil,
    AutoBuyTracker = {},
    AutoAuctionThread = nil,
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
    OptimizerChanged = nil,
    OptimizerApplyToken = 0,
    OptimizerScanThread = nil,
    OptimizerBoostConnection = nil,
    OptimizerElitePartCache = {},
    OptimizerEliteBoostCache = {},
    OptimizerEliteEffectCache = {},
    AntiAfkConnection = nil,
    AutoSellThread = nil,
    LastHarvest = 0,
    NoclipPlantApplyToken = 0,
    PlantEffectMaintainConnection = nil,
    PlantEmitterClearConnection = nil,
    PlantEmitterCache = {},
    PlantEmitterCacheAt = 0,
    PlantWatchConnections = {},
    GardensWatchConnection = nil,
    FruitsFolderConnections = {},
    PlantChildConnections = {},
    NoclipCharConnection = nil,
    GardenFruits = {},
    FruitLabelMap = {},
    OptimizerPlantRecordCache = {},
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

function killPlantEmitter(emitter)
    emitter.Enabled = false
    emitter.Rate = 0
    pcall(function()
        emitter.Lifetime = NumberRange.new(0, 0)
    end)
    pcall(function()
        emitter:Clear()
    end)
    pcall(function()
        emitter.Transparency = NumberSequence.new(1)
    end)
end

function rehidePlantInstance(inst)
    if inst:IsA('BasePart') then
        if inst.Transparency < 1 or inst.LocalTransparencyModifier < 1 or inst.CanCollide then
            inst.CanCollide = false
            inst.Transparency = 1
            inst.LocalTransparencyModifier = 1
        end
    elseif inst:IsA('Decal') or inst:IsA('Texture') then
        if inst.Transparency < 1 then
            inst.Transparency = 1
        end
    elseif inst:IsA('BillboardGui') or inst:IsA('SurfaceGui') or inst:IsA('Highlight')
        or inst:IsA('SelectionBox') or inst:IsA('ProximityPrompt') then
        if inst.Enabled then
            inst.Enabled = false
        end
    elseif inst:IsA('ParticleEmitter') then
        killPlantEmitter(inst)
    elseif inst:IsA('Trail') or inst:IsA('Beam') or inst:IsA('Fire') or inst:IsA('Smoke')
        or inst:IsA('Sparkles') then
        if inst.Enabled then
            inst.Enabled = false
        end
    elseif inst:IsA('PointLight') or inst:IsA('SpotLight') or inst:IsA('Light') then
        if inst.Enabled then
            inst.Enabled = false
        end
    end
end

function getWatchedPlantsFolders()
    local folders = {}

    if State.OptimizerEnabled then
        for _, plot in Gardens:GetChildren() do
            local plants = plot:FindFirstChild('Plants')
            if plants then
                table.insert(folders, plants)
            end
        end
    elseif Toggles.Noclip and Toggles.Noclip.Value then
        local plotId = LocalPlayer:GetAttribute('PlotId')
        if plotId then
            local plot = Gardens:FindFirstChild('Plot' .. plotId)
            local plants = plot and plot:FindFirstChild('Plants')
            if plants then
                table.insert(folders, plants)
            end
        end
    end

    return folders
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

function refreshPlantEmitterCache()
    local cache = {}

    for _, plants in getWatchedPlantsFolders() do
        for _, desc in plants:GetDescendants() do
            if desc:IsA('ParticleEmitter') then
                table.insert(cache, desc)
            end
        end
    end

    State.PlantEmitterCache = cache
    State.PlantEmitterCacheAt = os.clock()
end

function trackPlantEmitter(emitter)
    if not emitter:IsA('ParticleEmitter') then
        return
    end

    for _, cached in State.PlantEmitterCache do
        if cached == emitter then
            return
        end
    end

    table.insert(State.PlantEmitterCache, emitter)
    killPlantEmitter(emitter)
end

function clearCachedPlantEmitters()
    for _, emitter in State.PlantEmitterCache do
        if emitter and emitter.Parent then
            killPlantEmitter(emitter)
        end
    end
end

function suppressPlantVisual(inst, savedState, record)
    local props = savedState[inst]

    if inst:IsA('ParticleEmitter') then
        if not props then
            props = {
                Enabled = inst.Enabled,
                Rate = inst.Rate,
                Lifetime = inst.Lifetime,
            }
            savedState[inst] = props
            if record then
                record(inst, props)
            end
        end
        killPlantEmitter(inst)
    elseif inst:IsA('Trail') or inst:IsA('Beam') then
        if not props then
            props = { Enabled = inst.Enabled }
            savedState[inst] = props
            if record then
                record(inst, props)
            end
        end
        inst.Enabled = false
    elseif inst:IsA('Fire') or inst:IsA('Smoke') or inst:IsA('Sparkles') or inst:IsA('Light') then
        if not props then
            props = { Enabled = inst.Enabled }
            savedState[inst] = props
            if record then
                record(inst, props)
            end
        end
        inst.Enabled = false
    elseif inst:IsA('Decal') or inst:IsA('Texture') then
        if not props then
            props = { Transparency = inst.Transparency }
            savedState[inst] = props
            if record then
                record(inst, props)
            end
        end
        inst.Transparency = 1
    elseif inst:IsA('BillboardGui') or inst:IsA('SurfaceGui') or inst:IsA('Highlight')
        or inst:IsA('SelectionBox') or inst:IsA('ProximityPrompt') then
        if not props then
            props = { Enabled = inst.Enabled }
            savedState[inst] = props
            if record then
                record(inst, props)
            end
        end
        inst.Enabled = false
    elseif inst:IsA('PointLight') or inst:IsA('SpotLight') then
        if not props then
            props = { Enabled = inst.Enabled }
            savedState[inst] = props
            if record then
                record(inst, props)
            end
        end
        inst.Enabled = false
    elseif inst:IsA('BasePart') then
        if not props then
            props = {
                CanCollide = inst.CanCollide,
                LocalTransparencyModifier = inst.LocalTransparencyModifier,
                Transparency = inst.Transparency,
                CastShadow = inst.CastShadow,
                Material = inst.Material,
                Reflectance = inst.Reflectance,
            }
            savedState[inst] = props
            if record then
                record(inst, props)
            end
        end
        inst.CanCollide = false
        inst.LocalTransparencyModifier = 1
        inst.Transparency = 1
        inst.CastShadow = false
        if State.OptimizerEnabled then
            inst.Material = Enum.Material.SmoothPlastic
            inst.Reflectance = 0
        end
    end
end

function stopPlantEffectMaintain()
    if State.PlantEffectMaintainConnection then
        State.PlantEffectMaintainConnection:Disconnect()
        State.PlantEffectMaintainConnection = nil
    end

    if State.PlantEmitterClearConnection then
        State.PlantEmitterClearConnection:Disconnect()
        State.PlantEmitterClearConnection = nil
    end

    stopPlantWatchers()
    stopFruitsFolderWatchers()

    State.PlantEmitterCache = {}
    State.PlantEmitterCacheAt = 0
end

function shouldMaintainPlantEffects()
    if Library.Unloaded then
        return false
    end

    if State.OptimizerEnabled then
        return true
    end

    return Toggles.Noclip and Toggles.Noclip.Value == true
end

function forceSuppressPlantEffect(inst)
    if inst:IsA('ParticleEmitter') then
        killPlantEmitter(inst)
    elseif inst:IsA('Trail') or inst:IsA('Beam') or inst:IsA('Fire') or inst:IsA('Smoke')
        or inst:IsA('Sparkles') or inst:IsA('Light') then
        inst.Enabled = false
    end
end

function stopFruitsFolderWatchers()
    for _, connection in State.FruitsFolderConnections do
        connection:Disconnect()
    end
    State.FruitsFolderConnections = {}

    for _, connection in State.PlantChildConnections do
        connection:Disconnect()
    end
    State.PlantChildConnections = {}
end

function stopPlantWatchers()
    for _, connection in State.PlantWatchConnections do
        connection:Disconnect()
    end
    State.PlantWatchConnections = {}

    if State.GardensWatchConnection then
        State.GardensWatchConnection:Disconnect()
        State.GardensWatchConnection = nil
    end
end

function hideWatchedPlantInstance(desc)
    if State.OptimizerEnabled and isPlantInstance(desc) then
        suppressPlantVisual(desc, State.OptimizerPlantRecordCache, State.OptimizerChanged and function(inst, props)
            table.insert(State.OptimizerChanged, { inst = inst, props = props })
        end or nil)
        trackPlantEmitter(desc)
    end

    if Toggles.Noclip and Toggles.Noclip.Value then
        local plotId = LocalPlayer:GetAttribute('PlotId')
        local plot = plotId and Gardens:FindFirstChild('Plot' .. plotId)
        local plants = plot and plot:FindFirstChild('Plants')
        if plants and desc:IsDescendantOf(plants) then
            suppressPlantVisual(desc, State.NoclipPlantState)
            trackPlantEmitter(desc)
        end
    end
end

function hideWatchedPlantTree(root)
    if typeof(root) ~= 'Instance' then
        return
    end

    hideWatchedPlantInstance(root)
    for _, desc in root:GetDescendants() do
        hideWatchedPlantInstance(desc)
    end
end

function onPlantDescendantAdded(desc)
    task.defer(function()
        hideWatchedPlantInstance(desc)
    end)
end

function ensureFruitsFolderWatchers()
    if not shouldMaintainPlantEffects() then
        stopFruitsFolderWatchers()
        return
    end

    for _, plants in getWatchedPlantsFolders() do
        if not State.PlantChildConnections[plants] then
            State.PlantChildConnections[plants] = plants.ChildAdded:Connect(function(plantModel)
                task.defer(function()
                    hideWatchedPlantTree(plantModel)
                    ensureFruitsFolderWatchers()
                end)
            end)
        end

        for _, plantModel in plants:GetChildren() do
            local fruitsFolder = plantModel:FindFirstChild('Fruits')
            if fruitsFolder and not State.FruitsFolderConnections[fruitsFolder] then
                State.FruitsFolderConnections[fruitsFolder] = fruitsFolder.ChildAdded:Connect(function(fruitModel)
                    task.defer(function()
                        hideWatchedPlantTree(fruitModel)
                    end)
                end)
            end
        end
    end
end

function ensurePlantWatchers()
    if not shouldMaintainPlantEffects() then
        stopPlantWatchers()
        return
    end

    for _, plants in getWatchedPlantsFolders() do
        if not State.PlantWatchConnections[plants] then
            State.PlantWatchConnections[plants] = plants.DescendantAdded:Connect(onPlantDescendantAdded)
        end
    end

    if not State.GardensWatchConnection then
        State.GardensWatchConnection = Gardens.ChildAdded:Connect(function(child)
            if child:FindFirstChild('Plants') then
                task.defer(ensurePlantWatchers)
            end
        end)
    end
end

function clearCachedPlantEmittersBatch(batchSize)
    local cache = State.PlantEmitterCache
    local count = #cache
    if count == 0 then
        return
    end

    batchSize = batchSize or 12
    local startIndex = State.PlantEmitterClearIndex or 1

    for i = 1, math.min(batchSize, count) do
        local index = ((startIndex + i - 2) % count) + 1
        local emitter = cache[index]
        if emitter and emitter.Parent then
            killPlantEmitter(emitter)
        end
    end

    State.PlantEmitterClearIndex = (startIndex + batchSize - 1) % count + 1
end

function updatePlantEffectMaintain()
    if not shouldMaintainPlantEffects() then
        stopPlantEffectMaintain()
        return
    end

    if not State.PlantEffectMaintainConnection then
        local lastEmitterClear = 0

        State.PlantEffectMaintainConnection = RunService.Heartbeat:Connect(function()
            if not shouldMaintainPlantEffects() then
                stopPlantEffectMaintain()
                return
            end

            local now = os.clock()
            if now - lastEmitterClear >= 3 then
                lastEmitterClear = now
                clearCachedPlantEmittersBatch(12)
            end
        end)
    end

    ensurePlantWatchers()
    ensureFruitsFolderWatchers()
end

function scanOptimizerPlants(applyToken)
    local queue = {}

    for _, plot in Gardens:GetChildren() do
        local plants = plot:FindFirstChild('Plants')
        if plants then
            for _, plantModel in plants:GetChildren() do
                table.insert(queue, plantModel)
            end
        end
    end

    local index = 1
    while index <= #queue do
        if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
            return
        end

        for _ = 1, 5 do
            local plantModel = queue[index]
            if not plantModel then
                break
            end

            hideWatchedPlantTree(plantModel)
            index += 1
        end

        task.wait(0.02)
    end
end

function eliteOptimizeInstance(inst)
    if not State.OptimizerEnabled then
        return
    end

    if inst:IsA('BasePart') and not inst:IsA('MeshPart') then
        if not State.OptimizerElitePartCache[inst] then
            State.OptimizerElitePartCache[inst] = {
                Material = inst.Material,
            }
        end
        inst.Material = Enum.Material.SmoothPlastic
    elseif inst:IsA('Texture') or inst:IsA('Decal') then
        if not State.OptimizerElitePartCache[inst] then
            State.OptimizerElitePartCache[inst] = {
                Transparency = inst.Transparency,
            }
        end
        inst.Transparency = 1
    end
end

function eliteBoostInstance(inst)
    if not State.OptimizerEnabled then
        return
    end

    if inst:IsA('ParticleEmitter') or inst:IsA('Trail') or inst:IsA('Explosion') then
        if not State.OptimizerEliteBoostCache[inst] then
            State.OptimizerEliteBoostCache[inst] = inst.Enabled
        end
        inst.Enabled = false
    end
end

function eliteScanWorldGraphics()
    local descendants = workspace:GetDescendants()

    for index, desc in descendants do
        if not State.OptimizerEnabled then
            return
        end

        eliteOptimizeInstance(desc)

        if index % 500 == 0 then
            task.wait()
        end
    end
end

function eliteScanWorldBoost()
    local descendants = workspace:GetDescendants()

    for index, desc in descendants do
        if not State.OptimizerEnabled or not _G.ExtremeBoost then
            return
        end

        eliteBoostInstance(desc)

        if index % 500 == 0 then
            task.wait()
        end
    end
end

function applyEliteOptimizer()
    local terrainDecoration
    pcall(function()
        terrainDecoration = workspace.Terrain.Decoration
    end)

    local renderQuality
    local physicsThrottle
    local fpsCap

    pcall(function()
        renderQuality = settings().Rendering.QualityLevel
    end)
    pcall(function()
        physicsThrottle = settings().Physics.PhysicsEnvironmentalThrottle
    end)
    pcall(function()
        fpsCap = getfpscap and getfpscap() or 60
    end)

    State.OptimizerOriginal = {
        Brightness = Lighting.Brightness,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        TerrainDecoration = terrainDecoration,
        RenderQuality = renderQuality,
        PhysicsThrottle = physicsThrottle,
        FpsCap = fpsCap,
    }

    pcall(function()
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Always
    end)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9000000000
    Lighting.Brightness = 2

    for _, child in Lighting:GetChildren() do
        if child:IsA('PostEffect') or child:IsA('BloomEffect') or child:IsA('BlurEffect')
            or child:IsA('DepthOfFieldEffect') or child:IsA('SunRaysEffect') then
            if State.OptimizerEliteEffectCache[child] == nil then
                State.OptimizerEliteEffectCache[child] = child.Enabled
            end
            child.Enabled = false
        end
    end

    pcall(function()
        sethiddenproperty(workspace.Terrain, 'Decoration', false)
    end)

    pcall(function()
        if setfpscap then
            setfpscap(9999)
        end
    end)

    _G.ExtremeBoost = true

    if State.OptimizerBoostConnection then
        State.OptimizerBoostConnection:Disconnect()
        State.OptimizerBoostConnection = nil
    end

    State.OptimizerBoostConnection = workspace.DescendantAdded:Connect(function(desc)
        if State.OptimizerEnabled then
            eliteOptimizeInstance(desc)
            if _G.ExtremeBoost then
                eliteBoostInstance(desc)
            end
        end
    end)

    task.spawn(eliteScanWorldGraphics)
    task.spawn(eliteScanWorldBoost)
end

function restoreEliteOptimizer()
    if State.OptimizerBoostConnection then
        State.OptimizerBoostConnection:Disconnect()
        State.OptimizerBoostConnection = nil
    end

    _G.ExtremeBoost = false

    if State.OptimizerOriginal then
        local o = State.OptimizerOriginal

        pcall(function()
            Lighting.Brightness = o.Brightness
            Lighting.GlobalShadows = o.GlobalShadows
            Lighting.FogEnd = o.FogEnd
        end)

        pcall(function()
            if o.PhysicsThrottle then
                settings().Physics.PhysicsEnvironmentalThrottle = o.PhysicsThrottle
            end
        end)

        pcall(function()
            if o.RenderQuality then
                settings().Rendering.QualityLevel = o.RenderQuality
            end
        end)

        pcall(function()
            if o.TerrainDecoration ~= nil then
                sethiddenproperty(workspace.Terrain, 'Decoration', o.TerrainDecoration)
            else
                workspace.Terrain.Decoration = true
            end
        end)

        pcall(function()
            if setfpscap then
                setfpscap(o.FpsCap or 60)
            end
        end)
    end

    for inst, enabled in State.OptimizerEliteEffectCache do
        if inst and inst.Parent then
            pcall(function()
                inst.Enabled = enabled
            end)
        end
    end

    for inst, props in State.OptimizerElitePartCache do
        if inst and inst.Parent then
            for prop, val in props do
                pcall(function()
                    inst[prop] = val
                end)
            end
        end
    end

    for inst, enabled in State.OptimizerEliteBoostCache do
        if inst and inst.Parent then
            pcall(function()
                inst.Enabled = enabled
            end)
        end
    end

    State.OptimizerElitePartCache = {}
    State.OptimizerEliteBoostCache = {}
    State.OptimizerEliteEffectCache = {}
end

function restoreOptimizer()
    if State.OptimizerScanThread then
        pcall(task.cancel, State.OptimizerScanThread)
        State.OptimizerScanThread = nil
    end

    stopPlantEffectMaintain()

    if State.OptimizerChanged then
        for _, entry in ipairs(State.OptimizerChanged) do
            local inst = entry.inst
            if inst and inst.Parent then
                for prop, val in entry.props do
                    pcall(function()
                        inst[prop] = val
                    end)
                end
            end
        end
    end

    for inst, props in State.OptimizerPlantRecordCache do
        if inst and inst.Parent then
            for prop, val in props do
                pcall(function()
                    inst[prop] = val
                end)
            end
        end
    end

    restoreEliteOptimizer()

    State.OptimizerEnabled = false
    State.OptimizerOriginal = nil
    State.OptimizerChanged = nil
    State.OptimizerPlantRecordCache = {}
end

function setOptimizer(enabled)
    enabled = enabled == true

    State.OptimizerApplyToken += 1
    local applyToken = State.OptimizerApplyToken

    if not enabled then
        restoreOptimizer()
        return
    end

    local startingFresh = not State.OptimizerEnabled
    State.OptimizerEnabled = true
    State.OptimizerPlantRecordCache = {}

    if startingFresh then
        State.OptimizerChanged = {}
        State.OptimizerElitePartCache = {}
        State.OptimizerEliteBoostCache = {}
        State.OptimizerEliteEffectCache = {}
        applyEliteOptimizer()
    end

    updatePlantEffectMaintain()

    if State.OptimizerScanThread then
        pcall(task.cancel, State.OptimizerScanThread)
        State.OptimizerScanThread = nil
    end

    State.OptimizerScanThread = task.spawn(function()
        scanOptimizerPlants(applyToken)
        if applyToken ~= State.OptimizerApplyToken or not State.OptimizerEnabled then
            return
        end

        ensurePlantWatchers()
        ensureFruitsFolderWatchers()
        refreshPlantEmitterCache()
        State.OptimizerScanThread = nil
    end)
end

function abbreviate(n)
    if NumberUtils and NumberUtils.Abbreviate then
        return NumberUtils.Abbreviate(n) .. '¢'
    end
    return tostring(math.floor(n)) .. '¢'
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
    -- Many categories are stored as number counts.
    if typeof(value) == 'number' then
        return value > 0
    end

    -- Some categories (fruits, pets, possibly eggs/other uniques) are stored as tables with an Id.
    if typeof(value) == 'table' and value.Id ~= nil then
        -- Pets/uniques should not send equipped ones.
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

    -- If the game adds new giftable categories (e.g. eggs), include them even if the catalog list is out of date.
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

    -- Harvested fruits are often only present as Tools (not in replica inventory).
    -- Mailbox expects ItemKey = fruit Tool's Id attribute (string UUID).
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

function hidePlantVisual(inst)
    suppressPlantVisual(inst, State.NoclipPlantState)
    trackPlantEmitter(inst)
end

function restorePlantNoclip()
    if State.NoclipPlantConnection then
        State.NoclipPlantConnection:Disconnect()
        State.NoclipPlantConnection = nil
    end

    for inst, props in State.NoclipPlantState do
        if inst and inst.Parent then
            for prop, val in props do
                pcall(function()
                    inst[prop] = val
                end)
            end
        end
    end

    State.NoclipPlantState = {}
    updatePlantEffectMaintain()
end

function applyPlantNoclip(enabled)
    State.NoclipPlantApplyToken += 1
    local applyToken = State.NoclipPlantApplyToken

    restorePlantNoclip()

    if not enabled then
        return
    end

    task.spawn(function()
        local plantsFolder
        local deadline = os.clock() + 30

        while not plantsFolder and os.clock() < deadline do
            if applyToken ~= State.NoclipPlantApplyToken then
                return
            end

            local plot = getPlot()
            plantsFolder = plot and plot:FindFirstChild('Plants')
            if not plantsFolder then
                task.wait(0.25)
            end
        end

        if not plantsFolder or applyToken ~= State.NoclipPlantApplyToken then
            return
        end

        for _, plantModel in plantsFolder:GetChildren() do
            if applyToken ~= State.NoclipPlantApplyToken then
                return
            end

            hideWatchedPlantTree(plantModel)
            task.wait(0.06)
        end

        updatePlantEffectMaintain()
    end)
end

function setCharacterNoclip(char)
    if not char then
        return
    end

    for _, part in char:GetDescendants() do
        if part:IsA('BasePart') then
            part.CanCollide = false
        end
    end
end

function bindNoclipCharacter(char)
    if State.NoclipCharConnection then
        State.NoclipCharConnection:Disconnect()
        State.NoclipCharConnection = nil
    end

    if not char then
        return
    end

    setCharacterNoclip(char)
    State.NoclipCharConnection = char.DescendantAdded:Connect(function(desc)
        if desc:IsA('BasePart') then
            desc.CanCollide = false
        end
    end)
end

function setNoclip(enabled)
    if State.NoclipConnection then
        State.NoclipConnection:Disconnect()
        State.NoclipConnection = nil
    end

    if State.NoclipCharConnection then
        State.NoclipCharConnection:Disconnect()
        State.NoclipCharConnection = nil
    end

    applyPlantNoclip(enabled)
    updatePlantEffectMaintain()

    if not enabled then
        return
    end

    bindNoclipCharacter(getCharacter())
    State.NoclipConnection = LocalPlayer.CharacterAdded:Connect(bindNoclipCharacter)
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

function getPlacementPosition(savedPos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { Gardens }

    local origin = Vector3.new(savedPos.X, savedPos.Y + 50, savedPos.Z)
    local result = workspace:Raycast(origin, Vector3.new(0, -200, 0), params)

    if result and CollectionService:HasTag(result.Instance, 'PlantArea') then
        return result.Position
    end

    return Vector3.new(savedPos.X, 142.602, savedPos.Z)
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
    if not State.SavedPosition then
        return false
    end

    if os.clock() - State.LastSprinklerPlace < 5 then
        return false
    end

    local active = getActiveSuperSprinkler()
    if active then
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

    local position = getPlacementPosition(State.SavedPosition)
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
    if not State.SavedPosition or State.WateringBusy then
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

    local position = getPlacementPosition(State.SavedPosition)
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
    -- Crate shop (props). Prices aren't exposed consistently; rely on server to reject if unaffordable.
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

function normalizeAuctionCategory(category)
    if type(category) ~= 'string' then
        return nil
    end

    local normalized = category:lower():gsub('[%s_%-]', '')
    if normalized == 'seeds' or normalized == 'seed' then
        return 'Seeds'
    end
    if normalized == 'gears' or normalized == 'gear' then
        return 'Gears'
    end
    if normalized == 'seedpacks' or normalized == 'seedpack' or normalized == 'packs' or normalized == 'crates' or normalized == 'crate' then
        return 'SeedPacks'
    end
    if normalized == 'eggs' or normalized == 'egg' then
        return 'Eggs'
    end
    if normalized == 'wateringcans' or normalized == 'wateringcan' or normalized == 'sprinklers' or normalized == 'sprinkler' then
        return 'Gears'
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
        if enabled == true and type(name) == 'string' and name:lower() == lower then
            return true
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

function isAuctionLotSelected(lot)
    local category = normalizeAuctionCategory(lot.category)
    local itemName = getAuctionLotItemName(lot)
    if not category or itemName == '' then
        return false
    end

    local optionKey = AUCTION_OPTION_BY_CATEGORY[category]
    if not optionKey then
        return false
    end

    local selected = getMultiSelect(optionKey)
    if not hasAuctionCategorySelection(optionKey) then
        return false
    end

    if isAuctionNameSelected(selected, itemName) then
        return true
    end

    if lot.displayName and isAuctionNameSelected(selected, lot.displayName) then
        return true
    end

    local ok, displayName = pcall(AuctioneerModule.DisplayName, lot)
    if ok and displayName and isAuctionNameSelected(selected, displayName) then
        return true
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

    task.defer(function()
        requestAuctionSnapshot()
    end)
end

function getAuctionPriceLimit()
    if not Options or not Options.AuctionPrice then
        return 0
    end

    return tonumber(Options.AuctionPrice.Value) or 0
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
    if lot.robuxPrice ~= nil then
        return
    end

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

    local hasAnySelection = false
    for _, optionKey in AUCTION_OPTION_BY_CATEGORY do
        if hasAuctionCategorySelection(optionKey) then
            hasAnySelection = true
            break
        end
    end

    if not hasAnySelection and Library and Library.Notify then
        Library:Notify('Auto auction: select seeds/gears/packs/eggs to buy first')
    end

    State.AutoAuctionThread = task.spawn(function()
        while isActiveSession() and Toggles.AutoBuyAuction and Toggles.AutoBuyAuction.Value do
            runAutoAuction()
            task.wait(0.5)
        end
        State.AutoAuctionThread = nil
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

function getFruitWeightKg(fruitModel, fruitData)
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

    return normalizeWeightKg(weight)
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
                '%d fruits at or above %.0fkg — select from dropdown',
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

function harvestFruits(maxKg)
    local plot = getPlot()
    local plantsFolder = plot and plot:FindFirstChild('Plants')
    if not plantsFolder then
        return
    end

    local maxKg = tonumber(maxKg) or 999
    local garden = GardenSync:GetGarden(LocalPlayer.UserId)
    local seen = {}

    for _, plantModel in plantsFolder:GetChildren() do
        local fruitsFolder = plantModel:FindFirstChild('Fruits')
        if fruitsFolder then
            for _, fruitModel in fruitsFolder:GetChildren() do
                if isFruitRipe(nil, fruitModel) then
                    local plantId = fruitModel:GetAttribute('PlantId')
                    local fruitId = fruitModel:GetAttribute('FruitId')

                    if plantId and fruitId then
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
            if plantId and isFruitRipe(nil, plantModel) then
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

    for plantId, plant in garden do
        if plant.Fruits then
            for fruitId, fruit in plant.Fruits do
                local key = plantId .. '_' .. fruitId
                if not seen[key] and isFruitRipe(fruit, findFruitModel(plantsFolder, plantId, fruitId)) then
                    seen[key] = true
                    local fruitModel = findFruitModel(plantsFolder, plantId, fruitId)
                    local weight = getFruitWeightKg(fruitModel, fruit)
                    if shouldHarvestFruit(weight, maxKg) then
                        collectFruit(plantId, fruitId)
                    end
                end
            end
        else
            local key = plantId .. '_'
            if not seen[key] and isFruitRipe(plant, findFruitModel(plantsFolder, plantId, '')) then
                seen[key] = true
                local plantModel = findFruitModel(plantsFolder, plantId, '')
                local weight = getFruitWeightKg(plantModel, plant)
                if shouldHarvestFruit(weight, maxKg) then
                    collectFruit(plantId, '')
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
    return queue_on_teleport
        or queueteleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
        or (getgenv().queue_on_teleport)
        or (getgenv().queueteleport)
        or (getgenv().queueonteleport)
end

function getOutsideWalkTarget(basePos, standoff)
    standoff = standoff or 10
    if not basePos then
        return nil
    end

    local char = getCharacter()
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if root then
        local flatTo = Vector3.new(basePos.X - root.Position.X, 0, basePos.Z - root.Position.Z)
        local dist = flatTo.Magnitude
        if dist > standoff + 2 then
            local flatPos = root.Position + flatTo.Unit * (dist - standoff)
            return Vector3.new(flatPos.X, basePos.Y, flatPos.Z)
        end
    end

    local plot = getPlot()
    if plot then
        local plotPivot = plot:GetPivot().Position
        local fromCenter = Vector3.new(basePos.X - plotPivot.X, 0, basePos.Z - plotPivot.Z)
        if fromCenter.Magnitude > 0.5 then
            local edge = plotPivot + fromCenter.Unit * (fromCenter.Magnitude + standoff)
            return Vector3.new(edge.X, basePos.Y, edge.Z)
        end
    end

    return Vector3.new(basePos.X + standoff, basePos.Y, basePos.Z)
end

function saveWeatherState()
    local savedPos = State.SavedPosition
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
        SavedPosX = savedPos and savedPos.X,
        SavedPosY = savedPos and savedPos.Y,
        SavedPosZ = savedPos and savedPos.Z,
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

    local sx = tonumber(saved.SavedPosX)
    local sy = tonumber(saved.SavedPosY)
    local sz = tonumber(saved.SavedPosZ)
    if sx and sy and sz and not State.SavedPosition then
        State.SavedPosition = Vector3.new(sx, sy, sz)
    end

    GENV.GG2_WeatherState = saved
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
    State.PendingWalkToSaved = State.SavedPosition ~= nil
        or (State.ReturnPosX ~= nil and State.ReturnPosY ~= nil and State.ReturnPosZ ~= nil)
    saveWeatherState()
end

function saveWeatherReturnPosition()
    local root = getCharacter() and getCharacter():FindFirstChild('HumanoidRootPart')
    local pos = root and root.Position or State.SavedPosition

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

        loadPositionFromConfig()
        if not State.SavedPosition then
            loadWeatherState()
        end

        local basePos = State.SavedPosition
        if State.PendingWalkBack and State.ReturnPosX and State.ReturnPosY and State.ReturnPosZ then
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
            clearWeatherState()
        end
    end)
end

function getAutoExecQueueScript()
    return [[
getgenv().GG2_AutoFarmRunning = nil
getgenv().GG2_FromAutoExec = true
getgenv().GG2_SkipRemoteUpdate = true
loadstring(game:HttpGet('https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/'..readfile('GG2/commit.txt')..'/loader.lua', true))()
]]
end

function queueTeleportScript()
    local queue = getQueueOnTeleport()
    if not queue then
        return false
    end

    ensureCommitFile()

    return pcall(function()
        queue(getAutoExecQueueScript())
    end)
end

function setupAutoExecute()
    ensureGg2Folders()
    ensureCommitFile()

    if not getQueueOnTeleport() then
        return
    end

    queueTeleportScript()

    if State.AutoExecTeleportConnection then
        return
    end

    local teleportedOnce = false
    State.AutoExecTeleportConnection = LocalPlayer.OnTeleport:Connect(function()
        if teleportedOnce then
            return
        end
        teleportedOnce = true

        saveAutoExecWalkState()
        saveConfigBeforeTeleport()
        queueTeleportScript()
    end)
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

    if game.PlaceId == placeId then
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

    queueTeleportScript()

    task.wait(0.25)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)

    return true
end

function shouldHandleWeatherReconnectError()
    local saved = GENV.GG2_WeatherState or readWeatherStateFile()
    if not saved or saved.Hiding ~= true then
        return false
    end

    if os.time() < (saved.HideUntil or 0) then
        return false
    end

    return true
end

function handleWeatherReconnectError(errorMessage)
    if not errorMessage or errorMessage == '' then
        return
    end

    if not shouldHandleWeatherReconnectError() and not State.WeatherReconnectPending then
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

            if State.WeatherReconnectPending or shouldHandleWeatherReconnectError() then
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
            handleWeatherReconnectError(currentError)
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
    if not State.WeatherHiding or os.time() >= State.HideUntil then
        return
    end

    task.spawn(function()
        while State.WeatherHiding and os.time() < State.HideUntil do
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
        if os.time() >= State.HideUntil then
            tryRejoinHome()
        else
            startWeatherHideWait()
        end
        return
    end

    task.spawn(function()
        while State.WeatherHiding and os.time() < State.HideUntil do
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
        local phaseEnd = workspace:GetAttribute('PhaseDuration')
        local endTime = typeof(phaseEnd) == 'number' and phaseEnd or (os.time() + 120)
        return activeWeather, endTime
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
            active[weatherName] = WeatherValues:GetAttribute(weatherName .. '_EndTime') or 0
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
        local remaining = math.max(0, State.HideUntil - os.time())
        WeatherStatusLabel:SetText(string.format('Weather: Hiding from %s (%ds)', State.HidingFromWeather or '?', remaining))
    elseif Toggles.WeatherDodge and Toggles.WeatherDodge.Value then
        WeatherStatusLabel:SetText('Weather: Watching')
    else
        WeatherStatusLabel:SetText('Weather: Disabled')
    end
end

function tryRejoinHome()
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

function forceLeaveServer(kickMessage)
    ensureCommitFile()
    queueTeleportScript()
    State.WeatherKickPending = true
    State.WeatherReconnectPending = true

    task.wait(0.35)

    local failed = false
    local failConn = TeleportService.TeleportInitFailed:Connect(function(player)
        if player == LocalPlayer then
            failed = true
        end
    end)

    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)

    for _ = 1, 6 do
        if failed or not isStillOnWeatherHomeServer() then
            break
        end
        task.wait(0.5)
    end

    failConn:Disconnect()

    if not isStillOnWeatherHomeServer() then
        State.WeatherReconnectPending = false
        return true
    end

    local kicked = pcall(function()
        LocalPlayer:Kick(kickMessage)
    end)

    if not kicked then
        State.WeatherReconnectPending = false
        State.WeatherKickPending = false
        if Library and Library.Notify then
            Library:Notify('Weather dodge failed - could not leave server')
        end
        return false
    end

    return true
end

function retryLeaveIfStillHome()
    if not State.WeatherHiding or not isStillOnWeatherHomeServer() then
        return
    end

    if os.clock() - (State.LastWeatherLeaveAttempt or 0) < 8 then
        return
    end
    State.LastWeatherLeaveAttempt = os.clock()

    local remaining = math.max(0, State.HideUntil - os.time())
    local kickMessage = string.format(
        '[AutoRejoin] %s detected - auto rejoining in %ds.',
        State.HidingFromWeather or 'Weather',
        math.max(remaining, 30)
    )

    forceLeaveServer(kickMessage)
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
    State.HideUntil = math.max(tonumber(endTime) or 0, os.time() + 30)
    saveWeatherReturnPosition()
    saveAutoExecWalkState()
    saveWeatherState()

    local remaining = math.max(30, State.HideUntil - os.time())
    local kickMessage = string.format('[AutoRejoin] %s detected - auto rejoining in %ds.', weatherGameName, remaining)

    saveWeatherState()

    if not writefile then
        clearWeatherState()
        State.WeatherKickPending = false
        Library:Notify('Weather dodge needs writefile support to rejoin after kick')
        return
    end

    State.LastWeatherLeaveAttempt = os.clock()
    forceLeaveServer(kickMessage)
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
                end

                if os.time() >= State.HideUntil then
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

function savePositionToConfig(pos)
    if not pos or not Options.SavedPosX then
        return
    end

    Options.SavedPosX:SetValue(string.format('%.3f', pos.X))
    Options.SavedPosY:SetValue(string.format('%.3f', pos.Y))
    Options.SavedPosZ:SetValue(string.format('%.3f', pos.Z))
end

function loadPositionFromConfig()
    if not Options.SavedPosX then
        return
    end

    local x = tonumber(Options.SavedPosX.Value)
    local y = tonumber(Options.SavedPosY.Value)
    local z = tonumber(Options.SavedPosZ.Value)

    if x and y and z then
        State.SavedPosition = Vector3.new(x, y, z)
    end
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

GearBox:AddButton({
    Text = 'Save Current Position',
    Func = function()
        local root = getCharacter() and getCharacter():FindFirstChild('HumanoidRootPart')
        if root then
            State.SavedPosition = root.Position
            savePositionToConfig(State.SavedPosition)
            Library:Notify('Saved position for sprinkler & watering can')
        else
            Library:Notify('No character found')
        end
    end,
})

GearBox:AddInput('SavedPosX', {
    Text = 'SavedPosX',
    Default = '',
    Visible = false,
})

GearBox:AddInput('SavedPosY', {
    Text = 'SavedPosY',
    Default = '',
    Visible = false,
})

GearBox:AddInput('SavedPosZ', {
    Text = 'SavedPosZ',
    Default = '',
    Visible = false,
})

for _, optionName in { 'SavedPosX', 'SavedPosY', 'SavedPosZ' } do
    if Options[optionName] then
        Options[optionName]:OnChanged(function()
            loadPositionFromConfig()
        end)
    end
end

GearBox:AddToggle('Noclip', {
    Text = 'Noclip',
    Default = false,
    Tooltip = 'Walk through walls and makes your plot plants invisible + non-collidable',
    Callback = function(value)
        task.defer(function()
            setNoclip(value)
        end)
    end,
})

GearBox:AddToggle('AutoSprinkler', {
    Text = 'Auto Super Sprinkler',
    Default = false,
    Tooltip = 'Keeps 1 Super Sprinkler active at your saved position',
})

GearBox:AddToggle('AutoWateringCan', {
    Text = 'Auto Super Watering Can',
    Default = false,
    Tooltip = 'Uses 1 Super Watering Can at saved position on the interval below',
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

WeatherBox:AddToggle('WeatherDodge', {
    Text = 'Enable Weather Dodge',
    Default = false,
    Tooltip = 'Kicks you when a selected event starts. Click Leave, then the script auto-runs and rejoins your server when the event ends.',
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
    Tooltip = "If you don't want to use this, just input '0'. Price filter in sheckles.",
})

AuctionBox:AddToggle('AutoBuyAuction', {
    Text = 'Auto Buy Auction',
    Default = false,
    Tooltip = 'Auto-buys auction lots with sheckles when stock is available and price matches your filter',
    Callback = function(value)
        setAutoAuctionLoop(value)
    end,
})

local EarningsLabel = StatsBox:AddLabel('Earnings/min: 0Â¢', true)
local SprinklerLabel = StatsBox:AddLabel('Sprinkler: None', true)

OptimizerBox:AddToggle('Optimizer', {
    Text = 'Enable Optimizer',
    Default = false,
    Tooltip = 'Elite optimizer: Anti LAG + FPS unlock + FPS booster, and hides all garden plants.',
    Callback = function(value)
        task.defer(function()
            setOptimizer(value)
        end)
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

    pcall(stopPlantEffectMaintain)
    pcall(setNoclip, false)
    pcall(setOptimizer, false)
    pcall(setAutoHarvestLoop, false)
    pcall(setAutoWateringLoop, false)
    pcall(setAutoBuyLoop, false)
    pcall(setAutoAuctionLoop, false)
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

-- Mail UI (Linoria)
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
ThemeManager:ApplyToTab(Tabs.Settings)

loadWeatherState()
setupWeatherErrorReconnect()

if State.WeatherHiding then
    if os.time() < State.HideUntil then
        if isStillOnWeatherHomeServer() then
            task.defer(function()
                retryLeaveIfStillHome()
            end)
        end
        startWeatherHideWait()
    elseif game.PlaceId ~= State.ReturnPlaceId or (State.ReturnJobId and game.JobId ~= State.ReturnJobId) then
        startWeatherRejoinWorker()
    else
        tryRejoinHome()
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

if getQueueOnTeleport() and writefile then
    task.defer(function()
        if Library and Library.Notify then
            Library:Notify('Auto-exec queued (queue_on_teleport + GitHub loader)')
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
    SaveManager:LoadAutoloadConfig()
    if Options.MenuKeybind then
        Library.ToggleKeybind = Options.MenuKeybind
    end
    if Toggles.AntiAfk and Toggles.AntiAfk.Value then
        setAntiAfk(true)
    end
    task.wait(0.25)
    loadPositionFromConfig()
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

    task.defer(refreshAuctionItemListsFromCatalog)
    task.defer(requestAuctionSnapshot)
    if Toggles.WeatherDodge and Toggles.WeatherDodge.Value then
        setWeatherDodge(true)
    elseif State.WeatherHiding and os.time() < State.HideUntil then
        setWeatherDodge(true)
    elseif State.WeatherHiding and os.time() >= State.HideUntil then
        tryRejoinHome()
    end

    task.wait(1.5)

    if Toggles.AutoHarvest and Toggles.AutoHarvest.Value then
        setAutoHarvestLoop(true)
    end

    if Toggles.Noclip and Toggles.Noclip.Value then
        task.spawn(function()
            setNoclip(true)
        end)
    end

    task.wait(1)

    if Toggles.Optimizer and Toggles.Optimizer.Value then
        task.spawn(function()
            setOptimizer(true)
        end)
    end

    task.wait(0.1)
    pcall(refreshMailInventory)
    updateWeatherLabels()
end)

LocalPlayer.CharacterAdded:Connect(function()
    if Toggles.Noclip and Toggles.Noclip.Value then
        task.wait(0.1)
        setNoclip(true)
    end
end)

LocalPlayer:GetAttributeChangedSignal('PlotId'):Connect(function()
    if Toggles.Noclip and Toggles.Noclip.Value then
        task.defer(function()
            setNoclip(true)
        end)
    end
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

Library:Notify('Grow a Garden 2 Auto Farm loaded! Save your position first.')
