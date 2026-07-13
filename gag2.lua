local SCRIPT_URL = 'https://raw.githubusercontent.com/aupirium/Auto-Farm---GAG2/refs/heads/main/gag2.lua'

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local TeleportService = game:GetService('TeleportService')

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild('PlayerScripts')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Gardens = workspace:WaitForChild('Gardens')
local WeatherValues = ReplicatedStorage:WaitForChild('WeatherValues')

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
local GENV = getgenv()
local SCRIPT_CACHE_FILE = 'gg2_autofarm_cached.lua'
local SCRIPT_URL_FILE = 'gg2_script_url.txt'
local WEATHER_REJOIN_BOOT = GENV.GG2_WeatherRejoinBoot == true
GENV.GG2_WeatherRejoinBoot = nil

local Networking = require(ReplicatedStorage.SharedModules.Networking)
local SprinklerData = require(ReplicatedStorage.SharedModules.SprinklerData)

local GardenSync = require(PlayerScripts.Controllers.GardenSyncController)
local FruitVisualizer = require(PlayerScripts.Controllers.FruitVisualizerController)

local NumberUtils
pcall(function()
    NumberUtils = require(ReplicatedStorage.SharedModules.NumberUtils)
end)

local SUPER_SPRINKLER = 'Super Sprinkler'
local SUPER_CAN = 'Super Watering Can'
local WATERING_INTERVAL = 10

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
    LastSheckles = nil,
    NoclipConnection = nil,
    HarvestConnection = nil,
    WateringConnection = nil,
    WateringStop = false,
    SprinklerPlacePending = false,
    WeatherHiding = false,
    ReturnJobId = nil,
    ReturnPlaceId = nil,
    HideUntil = 0,
    HidingFromWeather = nil,
    WeatherMonitorStop = false,
    WeatherMonitorThread = nil,
}

local function abbreviate(n)
    if NumberUtils and NumberUtils.Abbreviate then
        return NumberUtils.Abbreviate(n) .. '¢'
    end
    return tostring(math.floor(n)) .. '¢'
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass('Humanoid')
end

local function setNoclip(enabled)
    if State.NoclipConnection then
        State.NoclipConnection:Disconnect()
        State.NoclipConnection = nil
    end

    if not enabled then
        return
    end

    State.NoclipConnection = RunService.Stepped:Connect(function()
        local char = getCharacter()
        if not char then
            return
        end

        for _, part in char:GetDescendants() do
            if part:IsA('BasePart') then
                part.CanCollide = false
            end
        end
    end)
end

local function getPlot()
    local plotId = LocalPlayer:GetAttribute('PlotId')
    if plotId then
        return Gardens:FindFirstChild('Plot' .. plotId)
    end
    return nil
end

local function getPlotIdNumber(plot)
    return tonumber(plot.Name:match('%d+'))
end

local function findTool(attribute, value)
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

local function equipTool(tool)
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

local function getPlacementPosition(savedPos)
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

local function getActiveSuperSprinkler()
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

local function placeSuperSprinkler()
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

local function useSuperWateringCan()
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

local function setAutoWateringLoop(enabled)
    State.WateringStop = true

    if State.WateringConnection then
        task.cancel(State.WateringConnection)
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
            task.wait(WATERING_INTERVAL)
        end
    end)
end

local function countHarvestedFruits()
    local count = 0
    for _, container in { LocalPlayer:FindFirstChild('Backpack'), getCharacter() } do
        if container then
            for _, child in container:GetChildren() do
                if child:IsA('Tool') and child:GetAttribute('HarvestedFruit') == true then
                    count += 1
                end
            end
        end
    end
    return count
end

local function getInventoryCapacity()
    local upgrades = tonumber(LocalPlayer:GetAttribute('BackpackSpaceUpgradesPurchased')) or 0
    local skillData = LocalPlayer:FindFirstChild('SkillData')
    local maxBackpack = skillData and skillData:FindFirstChild('MaxBackpack')
    local skillLevel = maxBackpack and tonumber(maxBackpack.Value) or 1
    return math.max(1, 5 + upgrades + math.max(0, skillLevel - 1))
end

local function isInventoryFull()
    return countHarvestedFruits() >= getInventoryCapacity()
end

local function getSheckles()
    local leaderstats = LocalPlayer:FindFirstChild('leaderstats')
    local sheckles = leaderstats and leaderstats:FindFirstChild('Sheckles')
    return sheckles and tonumber(sheckles.Value) or nil
end

local function recordEarnings(amount)
    if not amount or amount <= 0 then
        return
    end

    table.insert(State.EarningsWindow, { t = os.clock(), amount = amount })

    local now = os.clock()
    while #State.EarningsWindow > 0 and now - State.EarningsWindow[1].t > 60 do
        table.remove(State.EarningsWindow, 1)
    end
end

local function getEarningsPerMinute()
    local total = 0
    local now = os.clock()
    for _, entry in State.EarningsWindow do
        if now - entry.t <= 60 then
            total += entry.amount
        end
    end
    return total
end

local function tryAutoSell(force)
    if not force and os.clock() - State.LastSell < 2 then
        return
    end

    if not isInventoryFull() then
        return
    end

    local before = getSheckles()
    local result = Networking.NPCS.SellAll:Fire()
    State.LastSell = os.clock()

    if result and result.Success then
        local earned = tonumber(result.SellPrice) or 0
        if earned <= 0 and before and not force then
            task.wait(0.25)
            local after = getSheckles()
            if after and after > before then
                earned = after - before
            end
        end
        recordEarnings(earned)
    end
end

local function isFruitRipe(fruitData, fruitModel)
    if fruitModel then
        local age = fruitModel:GetAttribute('Age')
        local maxAge = fruitModel:GetAttribute('MaxAge')
        if typeof(age) == 'number' and typeof(maxAge) == 'number' then
            return age >= maxAge
        end
    end

    if fruitData then
        return (fruitData.Age or 0) >= (fruitData.MaxAge or 1)
    end

    return false
end

local function getFruitWeightKg(fruitModel)
    if not fruitModel then
        return nil
    end

    local weight = FruitVisualizer:CalculateFruitWeight(fruitModel)
    if not weight and FruitVisualizer.CalculatePlantWeight then
        weight = FruitVisualizer:CalculatePlantWeight(fruitModel)
    end

    return weight
end

local function findFruitModel(plantsFolder, plantId, fruitId)
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

local function shouldHarvestFruit(weightKg, maxKg)
    if not weightKg then
        return false
    end

    return weightKg <= maxKg
end

local function collectFruit(plantId, fruitId)
    Networking.Garden.CollectFruit:Fire(plantId, fruitId or '')
end

local function harvestFruits(maxKg)
    local plot = getPlot()
    local plantsFolder = plot and plot:FindFirstChild('Plants')
    if not plantsFolder then
        return
    end

    local maxKg = maxKg or 999
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
                            local weight = getFruitWeightKg(fruitModel)
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
                    local weight = getFruitWeightKg(plantModel)
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
                    local weight = getFruitWeightKg(fruitModel)
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
                local weight = getFruitWeightKg(plantModel)
                if shouldHarvestFruit(weight, maxKg) then
                    collectFruit(plantId, '')
                end
            end
        end
    end
end

local function setAutoHarvestLoop(enabled)
    if State.HarvestConnection then
        State.HarvestConnection:Disconnect()
        State.HarvestConnection = nil
    end

    if not enabled then
        return
    end

    State.HarvestConnection = RunService.Heartbeat:Connect(function()
        if Library.Unloaded or not (Toggles.AutoHarvest and Toggles.AutoHarvest.Value) then
            return
        end

        if Toggles.AutoSell and Toggles.AutoSell.Value and isInventoryFull() then
            tryAutoSell(true)
        end

        local maxKg = Options.MaxHarvestKg and Options.MaxHarvestKg.Value or 50
        harvestFruits(maxKg)
    end)
end

local WEATHER_STATE_FILE = 'gg2_weather_state.json'

local WeatherStatusLabel
local CurrentWeatherLabel

local function nowUnix()
    return DateTime.now().UnixTimestamp
end

local function normalizeWeatherEndTime(endTime)
    local now = nowUnix()
    local t = tonumber(endTime)

    if not t or t <= 0 then
        return now + 120
    end

    if t > 1e12 then
        t = math.floor(t / 1000)
    end

    if t <= now then
        return now + 30
    end

    return t
end

local function saveWeatherState()
    local data = {
        Hiding = State.WeatherHiding,
        ReturnJobId = State.ReturnJobId,
        ReturnPlaceId = State.ReturnPlaceId,
        HideUntil = State.HideUntil,
        HidingFromWeather = State.HidingFromWeather,
        ScriptUrl = GENV.GG2_ScriptUrl,
    }

    GENV.GG2_WeatherState = data

    pcall(function()
        if writefile then
            local HttpService = game:GetService('HttpService')
            writefile(WEATHER_STATE_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function loadWeatherState()
    local saved = GENV.GG2_WeatherState

    if not saved then
        pcall(function()
            if readfile and isfile and isfile(WEATHER_STATE_FILE) then
                local HttpService = game:GetService('HttpService')
                saved = HttpService:JSONDecode(readfile(WEATHER_STATE_FILE))
                GENV.GG2_WeatherState = saved
            end
        end)
    end

    if not saved then
        return
    end

    State.WeatherHiding = saved.Hiding == true
    State.ReturnJobId = saved.ReturnJobId
    State.ReturnPlaceId = saved.ReturnPlaceId
    State.HideUntil = saved.HideUntil or 0
    State.HidingFromWeather = saved.HidingFromWeather
end

local function getBlockedWeathers()
    local blocked = {}
    local selected = Options and Options.BlockedWeathers and Options.BlockedWeathers.Value

    if typeof(selected) == 'table' then
        for key, value in selected do
            if value == true and typeof(key) == 'string' then
                blocked[key] = true
            elseif typeof(value) == 'string' then
                blocked[value] = true
            end
        end
    elseif typeof(selected) == 'string' and selected ~= '' then
        blocked[selected] = true
    end

    return blocked
end

local function getActiveNightMoon()
    local activeWeather = workspace:GetAttribute('ActiveWeather')
    if activeWeather and NIGHT_MOON_GAME_NAMES[activeWeather] then
        local phaseEnd = workspace:GetAttribute('PhaseDuration')
        return activeWeather, normalizeWeatherEndTime(phaseEnd)
    end

    return nil
end

local function isNightMoonBlocked(gameName, blocked)
    local label = NIGHT_MOON_LABELS[gameName]
    if label and blocked[label] then
        return true
    end

    if gameName == 'Rainbow Moon' and (blocked.Rainbow or blocked['Rainbow Moon']) then
        return true
    end

    return blocked[gameName] == true
end

local function getActiveEventWeathers()
    local active = {}

    for _, weatherName in EVENT_WEATHERS do
        if WeatherValues:GetAttribute(weatherName .. '_Playing') == true then
            active[weatherName] = normalizeWeatherEndTime(WeatherValues:GetAttribute(weatherName .. '_EndTime'))
        end
    end

    return active
end

local function getCurrentWeatherText()
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

local function findBlockedWeather(blocked)
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

local function getWeatherDisplayName(gameName)
    return NIGHT_MOON_LABELS[gameName] or gameName
end

local WEATHER_SCRIPT_RELOAD = [==[
repeat task.wait() until game:IsLoaded()
task.wait(4)
repeat task.wait() until game.Players.LocalPlayer

local HttpService = game:GetService('HttpService')
local stateFile = 'gg2_weather_state.json'

local function loadSaved()
    local saved = getgenv().GG2_WeatherState
    if saved then
        return saved
    end

    pcall(function()
        if readfile and isfile and isfile(stateFile) then
            saved = HttpService:JSONDecode(readfile(stateFile))
            getgenv().GG2_WeatherState = saved
        end
    end)

    return saved
end

local function runAutofarm()
    local src = getgenv().GG2_AutoFarmSource

    if not src and readfile and isfile and isfile('gg2_autofarm_cached.lua') then
        src = readfile('gg2_autofarm_cached.lua')
    end

    if not src then
        local url = getgenv().GG2_ScriptUrl

        if (not url or url == '') and readfile and isfile and isfile('gg2_script_url.txt') then
            url = readfile('gg2_script_url.txt')
        end

        if (not url or url == '') then
            local saved = loadSaved()
            if saved and saved.ScriptUrl then
                url = saved.ScriptUrl
            end
        end

        if url and url ~= '' then
            local user, repo, branch, path = url:match('https://github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$')
            if user then
                url = string.format('https://raw.githubusercontent.com/%s/%s/%s/%s', user, repo, branch, path)
            end

            local ok, res = pcall(function()
                return game:HttpGet(url)
            end)
            if ok then
                src = res
            end
        end
    end

    if not src then
        return
    end

    getgenv().GG2_AutoFarmRunning = false
    getgenv().GG2_WeatherRejoinBoot = true
    loadstring(src)()
end

pcall(runAutofarm)
]==]

local WEATHER_REJOIN_BEFORE = [==[
repeat task.wait() until game:IsLoaded()

local HttpService = game:GetService('HttpService')
local TeleportService = game:GetService('TeleportService')
local Players = game:GetService('Players')
local stateFile = 'gg2_weather_state.json'

local function nowUnix()
    return DateTime.now().UnixTimestamp
end

local function loadSaved()
    local saved = getgenv().GG2_WeatherState
    if saved then
        return saved
    end

    pcall(function()
        if readfile and isfile and isfile(stateFile) then
            saved = HttpService:JSONDecode(readfile(stateFile))
            getgenv().GG2_WeatherState = saved
        end
    end)

    return saved
end

local function clearSaved()
    getgenv().GG2_WeatherState = nil
    pcall(function()
        if delfile and isfile and isfile(stateFile) then
            delfile(stateFile)
        end
    end)
end

local function tryJoinInstance(placeId, jobId, player)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
    end)

    if ok then
        return true
    end

    local options = Instance.new('TeleportOptions')
    options.ServerInstanceId = jobId

    ok = pcall(function()
        TeleportService:TeleportAsync(placeId, { player }, options)
    end)

    return ok
end

local saved = loadSaved()
if not saved or not saved.Hiding then
    return
end

while nowUnix() < (saved.HideUntil or 0) do
    task.wait(1)
end

task.wait(3)

local player = Players.LocalPlayer
local placeId = saved.ReturnPlaceId
local jobId = saved.ReturnJobId

if not placeId or not jobId then
    clearSaved()
    return
end

local queueFn = (syn and syn.queue_on_teleport) or queue_on_teleport
if queueFn then
    queueFn([===[
]==]

local WEATHER_REJOIN_AFTER = [==[
]===])
end

for _ = 1, 20 do
    if tryJoinInstance(placeId, jobId, player) then
        clearSaved()
        return
    end
    task.wait(6)
end

pcall(function()
    TeleportService:Teleport(placeId, player)
end)

clearSaved()
]==]

local function getWeatherRejoinScript()
    return WEATHER_REJOIN_BEFORE .. WEATHER_SCRIPT_RELOAD .. WEATHER_REJOIN_AFTER
end

local function queueScriptReload()
    local queue = (syn and syn.queue_on_teleport) or queue_on_teleport
    if not queue then
        return false
    end

    queue(WEATHER_SCRIPT_RELOAD)
    return true
end

local function queueWeatherRejoin()
    local queue = (syn and syn.queue_on_teleport) or queue_on_teleport
    if not queue then
        return false
    end

    queue(getWeatherRejoinScript())
    return true
end

local function normalizeScriptUrl(url)
    if not url or url == '' then
        return ''
    end

    url = url:gsub('^%s+', ''):gsub('%s+$', '')

    local user, repo, branch, path = url:match('https://github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$')
    if user then
        return string.format('https://raw.githubusercontent.com/%s/%s/%s/%s', user, repo, branch, path)
    end

    return url
end

local function getScriptUrl()
    local url

    if SCRIPT_URL ~= '' then
        url = SCRIPT_URL
    elseif GENV.GG2_ScriptUrl and GENV.GG2_ScriptUrl ~= '' then
        url = GENV.GG2_ScriptUrl
    else
        pcall(function()
            if readfile and isfile and isfile(SCRIPT_URL_FILE) then
                url = readfile(SCRIPT_URL_FILE)
            end
        end)
    end

    return normalizeScriptUrl(url or '')
end

local function cacheScriptForRejoin()
    pcall(function()
        local url = getScriptUrl()
        if url ~= '' then
            GENV.GG2_ScriptUrl = url
            if writefile then
                writefile(SCRIPT_URL_FILE, url)
            end

            local ok, source = pcall(function()
                return game:HttpGet(url)
            end)

            if ok and source and source ~= '' then
                GENV.GG2_AutoFarmSource = source
                if writefile then
                    writefile(SCRIPT_CACHE_FILE, source)
                end
                return
            end
        end

        if not writefile then
            return
        end

        local source = GENV.GG2_AutoFarmSource
        local paths = {
            GENV.GG2_ScriptPath,
            'grow_garden_autofarm.lua',
            'zone/grow_garden_autofarm.lua',
            'scripts/grow_garden_autofarm.lua',
        }

        if not source then
            for _, path in paths do
                if path and isfile and isfile(path) then
                    source = readfile(path)
                    break
                end
            end
        end

        if source then
            GENV.GG2_AutoFarmSource = source
            writefile(SCRIPT_CACHE_FILE, source)
        end
    end)
end

local function teleportHomeInstance(placeId, jobId, player)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
    end)

    if ok then
        return true
    end

    local options = Instance.new('TeleportOptions')
    options.ServerInstanceId = jobId

    ok = pcall(function()
        TeleportService:TeleportAsync(placeId, { player }, options)
    end)

    return ok
end

local function updateWeatherLabels()
    if CurrentWeatherLabel then
        CurrentWeatherLabel:SetText('Active Event: ' .. getCurrentWeatherText())
    end

    if not WeatherStatusLabel then
        return
    end

    if State.WeatherHiding then
        local remaining = math.max(0, State.HideUntil - nowUnix())
        WeatherStatusLabel:SetText(string.format('Weather: Hiding from %s (%ds)', State.HidingFromWeather or '?', remaining))
    elseif Toggles.WeatherDodge and Toggles.WeatherDodge.Value then
        WeatherStatusLabel:SetText('Weather: Watching')
    else
        WeatherStatusLabel:SetText('Weather: Disabled')
    end
end

local function tryRejoinHome()
    if not State.ReturnPlaceId or not State.ReturnJobId then
        State.WeatherHiding = false
        saveWeatherState()
        return
    end

    Library:Notify('Weather ended - rejoining your server')

    State.WeatherHiding = false
    State.HidingFromWeather = nil
    saveWeatherState()
    cacheScriptForRejoin()
    queueScriptReload()

    for _ = 1, 10 do
        if teleportHomeInstance(State.ReturnPlaceId, State.ReturnJobId, LocalPlayer) then
            break
        end
        task.wait(5)
    end

    pcall(function()
        TeleportService:Teleport(State.ReturnPlaceId, LocalPlayer)
    end)

    State.ReturnJobId = nil
    State.ReturnPlaceId = nil
    State.HideUntil = 0
    saveWeatherState()
end

local function leaveForWeather(weatherGameName, endTime)
    if State.WeatherHiding then
        return
    end

    State.WeatherHiding = true
    State.HidingFromWeather = getWeatherDisplayName(weatherGameName)
    State.ReturnPlaceId = game.PlaceId
    State.ReturnJobId = game.JobId
    State.HideUntil = normalizeWeatherEndTime(endTime)
    saveWeatherState()
    cacheScriptForRejoin()

    local remaining = math.max(30, State.HideUntil - nowUnix())
    local kickMessage = string.format('[AutoRejoin] %s detected - auto rejoining in %ds.', weatherGameName, remaining)

    if not queueWeatherRejoin() then
        State.WeatherHiding = false
        State.HidingFromWeather = nil
        State.ReturnJobId = nil
        State.ReturnPlaceId = nil
        State.HideUntil = 0
        saveWeatherState()
        Library:Notify('Weather dodge needs queue_on_teleport support')
        return
    end

    task.wait(0.5)

    local kicked = pcall(function()
        LocalPlayer:Kick(kickMessage)
    end)

    if not kicked then
        State.WeatherHiding = false
        State.HidingFromWeather = nil
        State.ReturnJobId = nil
        State.ReturnPlaceId = nil
        State.HideUntil = 0
        saveWeatherState()
        Library:Notify('Weather dodge failed - could not disconnect')
    end
end

local function setWeatherDodge(enabled)
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
                if nowUnix() >= State.HideUntil then
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

local function formatSavedPosition()
    if not State.SavedPosition then
        return 'Saved Position: Not set'
    end
    local p = State.SavedPosition
    return string.format('Saved Position: %.1f, %.1f, %.1f', p.X, p.Y, p.Z)
end

local Window = Library:CreateWindow({
    Title = 'Grow a Garden 2 - Auto Farm',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Main = Window:AddTab('Main'),
    Settings = Window:AddTab('Settings'),
}

local GearBox = Tabs.Main:AddLeftGroupbox('Auto Gear')
local StatsBox = Tabs.Main:AddLeftGroupbox('Stats')
local FarmBox = Tabs.Main:AddRightGroupbox('Auto Farm')
local WeatherBox = Tabs.Main:AddRightGroupbox('Weather Dodge')

local SavedPosLabel = GearBox:AddLabel('Saved Position: Not set', true)

GearBox:AddButton({
    Text = 'Save Current Position',
    Func = function()
        local root = getCharacter() and getCharacter():FindFirstChild('HumanoidRootPart')
        if root then
            State.SavedPosition = root.Position
            SavedPosLabel:SetText(formatSavedPosition())
            Library:Notify('Saved position for sprinkler & watering can')
        else
            Library:Notify('No character found')
        end
    end,
})

GearBox:AddToggle('Noclip', {
    Text = 'Noclip',
    Default = false,
    Tooltip = 'Walk through walls to reach your sprinkler spot easier',
    Callback = function(value)
        setNoclip(value)
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
    Tooltip = 'Uses 1 Super Watering Can at saved position every 10 seconds',
    Callback = function(value)
        setAutoWateringLoop(value)
    end,
})

FarmBox:AddToggle('AutoHarvest', {
    Text = 'Auto Harvest',
    Default = false,
    Callback = function(value)
        setAutoHarvestLoop(value)
    end,
})

FarmBox:AddSlider('MaxHarvestKg', {
    Text = 'Max Harvest KG',
    Default = 50,
    Min = 0.01,
    Max = 1000,
    Rounding = 2,
    Compact = false,
    Tooltip = 'Skips fruits heavier than this (in KG)',
})

FarmBox:AddToggle('AutoSell', {
    Text = 'Auto Sell When Full',
    Default = false,
})

WeatherBox:AddToggle('WeatherDodge', {
    Text = 'Enable Weather Dodge',
    Default = false,
    Tooltip = 'Kicks you when a selected event starts, then auto-rejoins your server when it ends',
    Callback = function(value)
        setWeatherDodge(value)
    end,
})

WeatherBox:AddDropdown('BlockedWeathers', {
    Text = 'Bad Events',
    Values = BLOCKABLE_WEATHERS,
    Multi = true,
    Default = {},
    Tooltip = 'Rainbow covers both the event and Rainbow Moon at night',
})

WeatherStatusLabel = WeatherBox:AddLabel('Weather: Disabled', true)
CurrentWeatherLabel = WeatherBox:AddLabel('Active Event: None', true)

local EarningsLabel = StatsBox:AddLabel('Earnings/min: 0¢', true)
local SprinklerLabel = StatsBox:AddLabel('Sprinkler: None', true)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder('GrowGarden2AutoFarm')
SaveManager:SetFolder('GrowGarden2AutoFarm')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
cacheScriptForRejoin()

loadWeatherState()

if State.WeatherHiding and State.ReturnJobId == game.JobId then
    if WEATHER_REJOIN_BOOT or nowUnix() >= State.HideUntil then
        State.WeatherHiding = false
        State.HidingFromWeather = nil
        State.ReturnJobId = nil
        State.ReturnPlaceId = nil
        State.HideUntil = 0
        saveWeatherState()
    end
end

task.defer(function()
    if Toggles.AutoHarvest and Toggles.AutoHarvest.Value then
        setAutoHarvestLoop(true)
    end
    if Toggles.AutoWateringCan and Toggles.AutoWateringCan.Value then
        setAutoWateringLoop(true)
    end
    if Toggles.WeatherDodge and Toggles.WeatherDodge.Value then
        setWeatherDodge(true)
    elseif State.WeatherHiding and nowUnix() < State.HideUntil then
        setWeatherDodge(true)
    elseif State.WeatherHiding and nowUnix() >= State.HideUntil then
        tryRejoinHome()
    end
    updateWeatherLabels()
end)

LocalPlayer.CharacterAdded:Connect(function()
    if Toggles.Noclip and Toggles.Noclip.Value then
        task.wait(0.1)
        setNoclip(true)
    end
end)

Library:OnUnload(function()
    Library.Unloaded = true
    setNoclip(false)
    setAutoHarvestLoop(false)
    setAutoWateringLoop(false)
    setWeatherDodge(false)
    GENV.GG2_AutoFarmRunning = false
end)

task.spawn(function()
    while not Library.Unloaded do
        local sheckles = getSheckles()
        if sheckles and State.LastSheckles and sheckles > State.LastSheckles then
            recordEarnings(sheckles - State.LastSheckles)
        end
        if sheckles then
            State.LastSheckles = sheckles
        end

        if Toggles.AutoSprinkler and Toggles.AutoSprinkler.Value then
            placeSuperSprinkler()
        end

        if Toggles.AutoSell and Toggles.AutoSell.Value then
            tryAutoSell()
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

if State.WeatherHiding and nowUnix() < State.HideUntil then
    queueWeatherRejoin()
end

GENV.GG2_AutoFarmRunning = true
