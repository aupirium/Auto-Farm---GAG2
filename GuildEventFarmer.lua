--[[
  Tallest Guild — Grow a Garden 2 height hunt helper.

  READ FIRST
  - Still in development. Expect bugs.
  - Do NOT run this on an account with trees you care about.
    Grown plants below your target are shoveled. Old trees count
    as unqualified and WILL be deleted. Use an alt or an empty plot.

  Controls: RightShift = hide/show UI | X = shut down
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
do
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		local old = pg:FindFirstChild("GuildEventFarmer")
		if old then
			old:Destroy()
		end
		local oldEsp = pg:FindFirstChild("GEF_HeightESP")
		if oldEsp then
			oldEsp:Destroy()
		end
	end
end

local Gardens = workspace:WaitForChild("Gardens")
local Networking = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Networking"))
local SprinklerDataModule = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("SprinklerData"))

local SprinklerByName = {}
for _, data in pairs(SprinklerDataModule) do
	if type(data) == "table" and data.SprinklerName then
		SprinklerByName[data.SprinklerName] = data
	end
end

local CONFIG_FILE = "GuildEventFarmer.json"

local Settings = {
	PlantMode = "Batch", -- "Batch" | "Continuous"
	TargetHeight = 500,
	BatchClearCap = 30,
	StopWhenFound = true,
	DeleteAllPlants = false,
	Exempted = {}, -- SeedName -> true
	AutoSell = true,
	AutoSellInterval = 3,
	MaxPerBatch = 150,
	PlantSpacing = 1.35,
	SeedFilter = "", -- empty = auto pick equipped / first seed tool
	WebhookUrl = "",
	ShovelDelay = 0,
	InstantShovel = true,
	PlantDelay = 0.06,
	AutoSprinkler = true,
	SprinklerType = "Super Sprinkler",
	PlantInSprinklerRadiusOnly = true,
	ShowESP = true,
	ESPMaxDistance = 120,
	ESPTopCount = 8, -- only show the tallest N plants
	ESPMinFeet = 50, -- hide short junk under this
}

local State = {
	Running = false,
	Purging = false,
	Hidden = false,
	Status = "Idle",
	Keepers = {}, -- plant model Name -> true
	BatchId = 0,
	FoundKeeper = false,
	LastSell = 0,
	SprinklerZones = {}, -- { position = Vector3, radius = number }
	SprinklerPlacedAt = nil,
	LastSprinklerPos = nil,
	EspFolder = nil,
	EspLabels = {}, -- plant Name -> BillboardGui
	EspCache = {}, -- plant Name -> { ft, at }
	Stats = { planted = 0, shoveled = 0, claimed = 0, removed = 0, keepers = 0, sprinklers = 0, bestFt = 0, cycles = 0 },
	StartedAt = nil,
	Minimized = false,
	UI = nil, -- live widgets filled by buildUI
}

------------------------------------------------------------------------
-- Persistence
------------------------------------------------------------------------
local function canFile()
	return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

local function saveSettings()
	if not canFile() then
		return
	end
	pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode(Settings))
	end)
end

local function loadSettings()
	if not canFile() or not isfile(CONFIG_FILE) then
		return
	end
	pcall(function()
		local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
		if type(data) ~= "table" then
			return
		end
		for k, v in pairs(data) do
			if Settings[k] ~= nil then
				Settings[k] = v
			end
		end
	end)
end

loadSettings()
Settings.AutoSell = true
Settings.AutoSellInterval = 3
Settings.InstantShovel = true
Settings.ShovelDelay = 0
if not Settings.SprinklerType or Settings.SprinklerType == "" then
	Settings.SprinklerType = "Super Sprinkler"
end
saveSettings()

------------------------------------------------------------------------
-- Utils
------------------------------------------------------------------------
local function setStatus(msg)
	State.Status = msg
	local ui = State.UI
	if ui and ui.StatusLabel then
		ui.StatusLabel.Text = msg
	end
	if ui and ui.StatusDot then
		local running = State.Running or State.Purging
		ui.StatusDot.BackgroundColor3 = running and Color3.fromRGB(255, 186, 55) or Color3.fromRGB(90, 110, 95)
	end
end

local function countToolsByAttr(attrName, preferred)
	local total = 0
	local function scan(container)
		if not container then
			return
		end
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") then
				local a = t:GetAttribute(attrName)
				if a and (not preferred or preferred == "" or a == preferred) then
					total += tonumber(t:GetAttribute("Count")) or 1
				end
			end
		end
	end
	scan(LocalPlayer.Backpack)
	scan(LocalPlayer.Character)
	return total
end

local function formatElapsed(sec)
	sec = math.max(0, math.floor(sec or 0))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	return string.format("%d:%02d:%02d", h, m, s)
end

local function httpRequest(opts)
	local req = (syn and syn.request)
		or (http and http.request)
		or http_request
		or request
	if typeof(req) ~= "function" then
		return nil, "No executor HTTP function (request / http_request)"
	end
	local ok, res = pcall(req, opts)
	if not ok then
		return nil, tostring(res)
	end
	return res, nil
end

local function sendWebhook(title, description, color)
	local url = Settings.WebhookUrl
	if type(url) ~= "string" or url == "" or not url:find("discord.com/api/webhooks") then
		return false, "Paste a Discord webhook URL in Settings"
	end
	local body = HttpService:JSONEncode({
		embeds = { {
			title = title,
			description = description,
			color = color or 0x3D8B5F,
			timestamp = DateTime.now():ToIsoDate(),
			footer = { text = "Guild Event Farmer · " .. LocalPlayer.Name },
		} },
	})
	local res, err = httpRequest({
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = body,
	})
	if err then
		return false, err
	end
	local code = res and (res.StatusCode or res.StatusCode or res.status_code)
	if code and code >= 200 and code < 300 then
		return true, "OK"
	end
	return false, "HTTP " .. tostring(code) .. " " .. tostring(res and (res.Body or res.body) or "")
end

local function getPlot()
	local id = LocalPlayer:GetAttribute("PlotId")
	if not id then
		return nil
	end
	return Gardens:FindFirstChild("Plot" .. tostring(id))
end

local function getPlantsFolder()
	local plot = getPlot()
	return plot and plot:FindFirstChild("Plants")
end

local function getEquippedTool()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildWhichIsA("Tool")
end

local function findSeedTool(preferred)
	preferred = preferred or Settings.SeedFilter
	local locked = preferred and preferred ~= ""

	local function scan(container)
		if not container then
			return nil
		end
		if locked then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("SeedTool") == preferred then
					local count = t:GetAttribute("Count")
					if type(count) ~= "number" or count > 0 then
						return t
					end
				end
			end
			return nil -- never fall back to a different seed when one is picked
		end
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("SeedTool") then
				local count = t:GetAttribute("Count")
				if type(count) ~= "number" or count > 0 then
					return t
				end
			end
		end
		return nil
	end

	local eq = getEquippedTool()
	if eq and eq:GetAttribute("SeedTool") then
		local seed = eq:GetAttribute("SeedTool")
		local count = eq:GetAttribute("Count")
		local hasCount = type(count) ~= "number" or count > 0
		if hasCount and ((locked and seed == preferred) or not locked) then
			return eq
		end
	end
	return scan(LocalPlayer.Character) or scan(LocalPlayer.Backpack)
end

local function findShovel()
	local eq = getEquippedTool()
	if eq and eq:GetAttribute("Shovel") then
		return eq
	end
	for _, container in ipairs({ LocalPlayer.Character, LocalPlayer.Backpack }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("Shovel") then
					return t
				end
			end
		end
	end
	return nil
end

local function getSprinklerInfo(name)
	name = name or Settings.SprinklerType
	return SprinklerByName[name]
end

local function getSprinklerDataRadius(name)
	local info = getSprinklerInfo(name)
	return (info and info.Radius) or 55
end

-- Game sets indicator Size.X/Z = data.Radius, so that value is the DIAMETER.
-- Edge distance from center (the real plant radius) is half of that.
local function getEffectiveRadius(name)
	return getSprinklerDataRadius(name) * 0.5
end

local function findSprinklerTool(preferred)
	preferred = preferred or Settings.SprinklerType
	local function scan(container)
		if not container then
			return nil
		end
		if preferred and preferred ~= "" then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("Sprinkler") == preferred then
					return t
				end
			end
		end
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("Sprinkler") then
				return t
			end
		end
		return nil
	end
	local eq = getEquippedTool()
	if eq and eq:GetAttribute("Sprinkler") then
		if not preferred or preferred == "" or eq:GetAttribute("Sprinkler") == preferred then
			return eq
		end
	end
	return scan(LocalPlayer.Character) or scan(LocalPlayer.Backpack)
end

local function listSprinklerNames()
	local names = {}
	local seen = {}
	local function scan(container)
		if not container then
			return
		end
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") then
				local s = t:GetAttribute("Sprinkler")
				if s and not seen[s] then
					seen[s] = true
					table.insert(names, s)
				end
			end
		end
	end
	scan(LocalPlayer.Backpack)
	scan(LocalPlayer.Character)
	table.sort(names)
	return names
end

local function getPlotIdNumber()
	local id = LocalPlayer:GetAttribute("PlotId")
	return tonumber(id)
end

local function getSprinklersFolder()
	local plot = getPlot()
	return plot and plot:FindFirstChild("Sprinklers")
end

local function posXZ(pos)
	return Vector3.new(pos.X, 0, pos.Z)
end

local function inSprinklerRadius(pos, zones)
	zones = zones or State.SprinklerZones
	if not zones or #zones == 0 then
		return false
	end
	local p = posXZ(pos)
	for _, zone in ipairs(zones) do
		if (p - posXZ(zone.position)).Magnitude <= zone.radius then
			return true
		end
	end
	return false
end

local function countLiveSprinklers()
	local folder = getSprinklersFolder()
	if not folder then
		return 0
	end
	local n = 0
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") then
			n += 1
		end
	end
	return n
end

local function getSprinklerLifetime(name)
	local info = getSprinklerInfo(name)
	return (info and info.Lifetime) or 120
end

local function refreshSprinklerZonesFromPlot()
	local folder = getSprinklersFolder()
	local zones = {}
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") then
				local sprinklerName = model:GetAttribute("SprinklerName") or Settings.SprinklerType
				for knownName in pairs(SprinklerByName) do
					if model.Name:find(knownName, 1, true) then
						sprinklerName = knownName
						break
					end
				end
				local pos = model:GetPivot().Position
				if model.PrimaryPart then
					pos = model.PrimaryPart.Position
				end
				table.insert(zones, {
					position = pos,
					radius = getEffectiveRadius(sprinklerName),
					name = sprinklerName,
				})
			end
		end
	end
	-- Always sync — clear stale zones when sprinkler expired / removed
	State.SprinklerZones = zones
	if #zones == 0 then
		State.SprinklerPlacedAt = nil
	end
	return State.SprinklerZones
end

-- True only when a sprinkler model is actually on the plot (not a client timer guess).
local function hasLiveSprinkler()
	refreshSprinklerZonesFromPlot()
	return countLiveSprinklers() > 0 and State.SprinklerZones and #State.SprinklerZones > 0
end

local function isOnPlantArea(worldPos)
	local plot = getPlot()
	if not plot then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("PlantArea")
	local hit = workspace:Raycast(worldPos + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), params)
	if not hit then
		return false, nil
	end
	if not hit.Instance:IsDescendantOf(plot) then
		return false, nil
	end
	return true, hit.Position
end

local function getPlantAreaParts()
	local plot = getPlot()
	local areas = {}
	if not plot then
		return areas
	end
	for _, a in ipairs(CollectionService:GetTagged("PlantArea")) do
		if a:IsDescendantOf(plot) and a:IsA("BasePart") and a.Name:find("PlantAreaColumn") then
			table.insert(areas, a)
		end
	end
	if #areas == 0 then
		for _, a in ipairs(CollectionService:GetTagged("PlantArea")) do
			if a:IsDescendantOf(plot) and a:IsA("BasePart") and a.Size.X * a.Size.Z > 400 then
				table.insert(areas, a)
			end
		end
	end
	return areas
end

local function equipTool(tool)
	if not tool then
		return false
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	if tool.Parent == char then
		return true
	end
	hum:EquipTool(tool)
	local t0 = os.clock()
	while os.clock() - t0 < 1 do
		if getEquippedTool() == tool then
			return true
		end
		task.wait()
	end
	return getEquippedTool() == tool
end

local function listSeedNames()
	local names = {}
	local seen = {}
	local function scan(container)
		if not container then
			return
		end
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") then
				local s = t:GetAttribute("SeedTool")
				if s and not seen[s] then
					seen[s] = true
					table.insert(names, s)
				end
			end
		end
	end
	scan(LocalPlayer.Backpack)
	scan(LocalPlayer.Character)
	table.sort(names)
	return names
end

local function listPlantSpecies()
	local folder = getPlantsFolder()
	local seen = {}
	local names = {}
	if not folder then
		return names
	end
	for _, p in ipairs(folder:GetChildren()) do
		local s = p:GetAttribute("SeedName")
		if s and not seen[s] then
			seen[s] = true
			table.insert(names, s)
		end
	end
	table.sort(names)
	return names
end

-- How ft is read:
-- 1) Trees (Corn, etc.): server sets plant:GetAttribute("Height") in feet
-- 2) Bamboo / crops without Height: world bounding-box height (studs ≈ ft)
local function measureMeshFeet(plant)
	-- Prefer world AABB — GetExtentsSize can under-report stacked bamboo
	local size
	local ok = pcall(function()
		local _, s = plant:GetBoundingBox()
		size = s
	end)
	if ok and typeof(size) == "Vector3" and size.Y > 0 then
		return math.floor(size.Y + 0.5)
	end
	ok = pcall(function()
		size = plant:GetExtentsSize()
	end)
	if ok and typeof(size) == "Vector3" and size.Y > 0 then
		return math.floor(size.Y + 0.5)
	end
	-- Fallback: span of part world positions
	local minY, maxY = math.huge, -math.huge
	local any = false
	for _, d in ipairs(plant:GetDescendants()) do
		if d:IsA("BasePart") then
			any = true
			local y = d.Position.Y
			local half = d.Size.Y * 0.5
			if y - half < minY then
				minY = y - half
			end
			if y + half > maxY then
				maxY = y + half
			end
		end
	end
	if any and maxY > minY then
		return math.floor((maxY - minY) + 0.5)
	end
	return 0
end

local function getPlantFeet(plant, opts)
	opts = opts or {}
	if not plant then
		return 0, "none"
	end
	local attr = plant:GetAttribute("Height")
	if type(attr) == "number" and attr > 0 then
		return attr, "attr"
	end
	local now = os.clock()
	local cached = State.EspCache[plant.Name]
	-- Keeper checks must not trust a stale short reading
	local ttl = opts.fresh and 0 or 1.25
	if cached and (now - cached.at) < ttl and not opts.fresh then
		return cached.ft, "mesh"
	end
	local ft = measureMeshFeet(plant)
	State.EspCache[plant.Name] = { ft = ft, at = now }
	return ft, "mesh"
end

local function formatFeet(ft)
	if ft >= 1000 then
		return string.format("%.1fk ft", ft / 1000)
	end
	return string.format("%d ft", math.floor(ft + 0.5))
end

local function isKeeper(plant)
	if not plant then
		return false
	end
	if State.Keepers[plant.Name] then
		return true
	end
	local h = getPlantFeet(plant, { fresh = true })
	if type(h) == "number" and h >= Settings.TargetHeight then
		return true
	end
	local seed = plant:GetAttribute("SeedName")
	if seed and Settings.Exempted[seed] then
		return true
	end
	return false
end

local function markKeeper(plant, height)
	if not plant then
		return
	end
	if State.Keepers[plant.Name] then
		return
	end
	height = height or getPlantFeet(plant, { fresh = true })
	if type(height) ~= "number" or height < Settings.TargetHeight then
		-- Exempt-only keepers still get tracked, but don't inflate "tall" count
		local seed = plant:GetAttribute("SeedName")
		if not (seed and Settings.Exempted[seed]) then
			return
		end
	end
	State.Keepers[plant.Name] = true
	State.Stats.keepers += 1
	State.FoundKeeper = true
	local seed = plant:GetAttribute("SeedName") or "?"
	local msg = string.format(
		"**%s** hit **%s ft** (target %s)\nPlant: `%s`",
		seed,
		tostring(height),
		tostring(Settings.TargetHeight),
		plant.Name
	)
	setStatus(string.format("KEEPER: %s @ %s ft", seed, tostring(height)))
	task.spawn(function()
		sendWebhook("Keeper found", msg, 0xF0C24B)
	end)
end

-- Detect + register keepers from current plot (fixes bamboo with no Height attr)
local function scanAndMarkKeepers()
	local folder = getPlantsFolder()
	if not folder then
		return 0
	end
	local n = 0
	for _, plant in ipairs(folder:GetChildren()) do
		if plant:IsA("Model") then
			local h = getPlantFeet(plant, { fresh = true })
			if type(h) == "number" and h >= Settings.TargetHeight then
				if not State.Keepers[plant.Name] then
					markKeeper(plant, h)
					n += 1
				end
			end
		end
	end
	return n
end

local function plantIsGrowing(plant)
	return plant:GetAttribute("PlantGrowthReady") ~= true
end

local function ensureEspFolder()
	if State.EspFolder and State.EspFolder.Parent then
		return State.EspFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "GEF_HeightESP"
	folder.Parent = LocalPlayer:WaitForChild("PlayerGui")
	State.EspFolder = folder
	return folder
end

local function destroyPlantEsp(plantName)
	local gui = State.EspLabels[plantName]
	if gui then
		gui:Destroy()
		State.EspLabels[plantName] = nil
	end
end

local function clearAllEsp()
	for name in pairs(State.EspLabels) do
		destroyPlantEsp(name)
	end
	if State.EspFolder then
		State.EspFolder:ClearAllChildren()
	end
end

local function getEspAdornee(plant)
	local base = plant:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		return base
	end
	local pp = plant.PrimaryPart
	if pp then
		return pp
	end
	return plant:FindFirstChildWhichIsA("BasePart", true)
end

local function upsertPlantEsp(plant, ft)
	if not Settings.ShowESP then
		return
	end
	local adornee = getEspAdornee(plant)
	if not adornee then
		return
	end
	local folder = ensureEspFolder()
	local gui = State.EspLabels[plant.Name]
	if not gui or not gui.Parent then
		gui = Instance.new("BillboardGui")
		gui.Name = "HeightESP_" .. plant.Name
		gui.Size = UDim2.fromOffset(90, 28)
		gui.StudsOffset = Vector3.new(0, 4, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = Settings.ESPMaxDistance or 120
		gui.Parent = folder

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0.35
		label.Parent = gui

		State.EspLabels[plant.Name] = gui
	end

	gui.Adornee = adornee
	gui.MaxDistance = Settings.ESPMaxDistance or 120
	local label = gui:FindFirstChild("Label")
	if not label then
		return
	end

	ft = ft or getPlantFeet(plant)
	local seed = plant:GetAttribute("SeedName") or "?"
	local growing = plantIsGrowing(plant)
	local keeper = type(ft) == "number" and ft >= Settings.TargetHeight

	if growing then
		label.TextColor3 = Color3.fromRGB(255, 230, 120)
	elseif keeper then
		label.TextColor3 = Color3.fromRGB(90, 255, 140)
	else
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	-- Single line, no black box
	label.Text = string.format("%s  %s", seed, formatFeet(ft))
end

local function refreshHeightEsp()
	if not Settings.ShowESP then
		clearAllEsp()
		return
	end
	local folder = getPlantsFolder()
	if not folder then
		clearAllEsp()
		return
	end

	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local origin = root and root.Position
	local maxDist = Settings.ESPMaxDistance or 120
	local topCount = math.clamp(Settings.ESPTopCount or 8, 1, 20)
	local minFeet = Settings.ESPMinFeet or 50

	local candidates = {}
	for _, plant in ipairs(folder:GetChildren()) do
		if plant:IsA("Model") then
			local adornee = getEspAdornee(plant)
			if adornee then
				local dist = origin and (adornee.Position - origin).Magnitude or 0
				if not origin or dist <= maxDist then
					local ft = getPlantFeet(plant)
					if ft >= minFeet then
						table.insert(candidates, { plant = plant, ft = ft, dist = dist })
					end
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.ft ~= b.ft then
			return a.ft > b.ft
		end
		return a.dist < b.dist
	end)

	local seen = {}
	for i, entry in ipairs(candidates) do
		if i > topCount then
			break
		end
		seen[entry.plant.Name] = true
		upsertPlantEsp(entry.plant, entry.ft)
	end
	for name in pairs(State.EspLabels) do
		if not seen[name] then
			destroyPlantEsp(name)
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		pcall(refreshHeightEsp)
	end
end)

local function shouldHuntPlant(plant)
	if not plant or not plant.Parent then
		return false
	end
	if isKeeper(plant) then
		return false
	end
	if Settings.DeleteAllPlants then
		local seed = plant:GetAttribute("SeedName")
		if seed and Settings.Exempted[seed] then
			return false
		end
		return true
	end
	local filter = Settings.SeedFilter
	if filter ~= "" then
		return plant:GetAttribute("SeedName") == filter
	end
	return true
end

local function bumpRemoved()
	State.Stats.removed = (State.Stats.removed or 0) + 1
end

local function shouldRemovePlant(plant, opts)
	opts = opts or {}
	if not plant or not plant.Parent then
		return false
	end
	if plantIsGrowing(plant) then
		return false
	end
	local h = getPlantFeet(plant, { fresh = true })
	if type(h) == "number" and h >= Settings.TargetHeight then
		markKeeper(plant, h)
		return false
	end
	if isKeeper(plant) then
		return false
	end
	if opts.waveOnly and not opts.waveOnly[plant.Name] then
		return false
	end
	if opts.speciesOnly and plant:GetAttribute("SeedName") ~= opts.speciesOnly then
		return false
	end
	if not opts.force and not shouldHuntPlant(plant) then
		return false
	end
	-- Wave shorts: if it was in this plant wave and isn't a keeper, remove it
	if opts.waveOnly and opts.waveOnly[plant.Name] then
		return true
	end
	if (not h or h <= 0) and not opts.force and not Settings.DeleteAllPlants then
		local attrH = plant:GetAttribute("Height")
		if type(attrH) ~= "number" then
			local filter = Settings.SeedFilter
			if filter == "" and not Settings.DeleteAllPlants then
				return false
			end
		end
	end
	return true
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
local function shovelPlant(plant)
	if not plant or not plant.Parent then
		return false
	end
	local h = getPlantFeet(plant, { fresh = true })
	if type(h) == "number" and h >= Settings.TargetHeight then
		markKeeper(plant, h)
		return false
	end
	if isKeeper(plant) then
		return false
	end
	if plantIsGrowing(plant) then
		return false
	end
	local shovel = findShovel()
	if not shovel then
		setStatus("No shovel in backpack")
		return false
	end
	-- Equip once if needed (re-equipping every plant is slow)
	if shovel.Parent ~= LocalPlayer.Character then
		if not equipTool(shovel) then
			return false
		end
	end
	local shovelAttr = shovel:GetAttribute("Shovel")
	local name = plant.Name
	Networking.Shovel.UseShovel:Fire(name, "", shovelAttr, shovel)

	if Settings.InstantShovel then
		-- Server only accepts ~1 shovel at a time; wait until this one is gone
		local folder = getPlantsFolder()
		local t0 = os.clock()
		while os.clock() - t0 < 1.5 do
			if not folder or not folder:FindFirstChild(name) then
				break
			end
			task.wait(0.03)
		end
		local gap = tonumber(Settings.ShovelDelay) or 0
		if gap > 0 then
			task.wait(gap)
		end
	else
		task.wait(math.max(0.05, Settings.ShovelDelay or 0.12))
	end

	State.Stats.shoveled += 1
	bumpRemoved()
	return true
end

local function clearUnqualified(opts)
	opts = opts or {}
	local folder = getPlantsFolder()
	if not folder then
		return 0
	end
	scanAndMarkKeepers()
	local shovel = findShovel()
	if shovel and shovel.Parent ~= LocalPlayer.Character then
		equipTool(shovel)
	end
	local maxPasses = opts.passes or (opts.waveOnly and 6 or 3)
	local totalRemoved = 0
	for _pass = 1, maxPasses do
		if not State.Running and not State.Purging then
			break
		end
		local removed = 0
		for _, plant in ipairs(folder:GetChildren()) do
			if not State.Running and not State.Purging then
				break
			end
			if shouldRemovePlant(plant, opts) and shovelPlant(plant) then
				removed += 1
			end
		end
		totalRemoved += removed
		if removed == 0 then
			break
		end
		task.wait(0.12)
	end
	return totalRemoved
end

local function waitForWaveReady(trackedNames, timeout)
	timeout = timeout or 10
	local deadline = os.clock() + timeout
	while State.Running and os.clock() < deadline do
		local folder = getPlantsFolder()
		local growing = 0
		if folder then
			for name in pairs(trackedNames) do
				local p = folder:FindFirstChild(name)
				if p and plantIsGrowing(p) then
					growing += 1
				end
			end
		end
		if growing == 0 then
			return true
		end
		setStatus(string.format("Waiting for wave to finish growing… %d left", growing))
		task.wait(0.25)
	end
	return false
end

local function clearWaveShorts(trackedNames)
	if not trackedNames then
		return 0
	end
	local n = 0
	for _ in pairs(trackedNames) do
		n += 1
	end
	if n == 0 then
		return 0
	end
	waitForWaveReady(trackedNames, 12)
	scanAndMarkKeepers()
	return clearUnqualified({ waveOnly = trackedNames, passes = 8 })
end

local function collectPlant(plant)
	if not plant or not plant.Parent then
		return false
	end
	if plantIsGrowing(plant) then
		return false
	end
	-- Never harvest keepers (tall bamboo / exempt) — CollectFruit removes them
	local h = getPlantFeet(plant, { fresh = true })
	if type(h) == "number" and h >= Settings.TargetHeight then
		markKeeper(plant, h)
		return false
	end
	if isKeeper(plant) then
		return false
	end
	local seed = plant:GetAttribute("SeedName")
	if seed and Settings.Exempted[seed] then
		return false
	end
	local plantId = plant:GetAttribute("PlantId")
	if not plantId then
		return false
	end
	local fruits = plant:FindFirstChild("Fruits")
	if fruits then
		local any = false
		for _, fruit in ipairs(fruits:GetChildren()) do
			local fruitId = fruit:GetAttribute("FruitId")
			if fruitId then
				Networking.Garden.CollectFruit:Fire(plantId, fruitId)
				State.Stats.claimed += 1
				bumpRemoved()
				any = true
			end
		end
		if any then
			return true
		end
	end
	-- Bamboo / single-crop style: harvest the plant itself
	Networking.Garden.CollectFruit:Fire(plantId, "")
	State.Stats.claimed += 1
	bumpRemoved()
	return true
end

local function getPlantPositions()
	local folder = getPlantsFolder()
	local positions = {}
	if not folder then
		return positions
	end
	for _, p in ipairs(folder:GetChildren()) do
		local base = p:FindFirstChild("Base")
		local pos = base and base.Position or p:GetPivot().Position
		table.insert(positions, Vector3.new(pos.X, 0, pos.Z))
	end
	return positions
end

local function tooClose(pos, occupied, minDist)
	local p = Vector3.new(pos.X, 0, pos.Z)
	for _, o in ipairs(occupied) do
		if (p - o).Magnitude < minDist then
			return true
		end
	end
	return false
end

local function buildSprinklerPlacementSpots()
	local radius = getEffectiveRadius(Settings.SprinklerType)
	-- Slight overlap so circles cover the dirt
	local spacing = math.max(10, radius * 1.55)
	local areas = getPlantAreaParts()
	local spots = {}
	local occupied = {}
	local existingZones = {}

	local folder = getSprinklersFolder()
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") then
				local pos = model:GetPivot().Position
				if model.PrimaryPart then
					pos = model.PrimaryPart.Position
				end
				table.insert(occupied, posXZ(pos))
				table.insert(existingZones, {
					position = pos,
					radius = getEffectiveRadius(model:GetAttribute("SprinklerName") or Settings.SprinklerType),
				})
			end
		end
	end

	local function alreadyCovered(pos)
		local p = posXZ(pos)
		for _, zone in ipairs(existingZones) do
			if (p - posXZ(zone.position)).Magnitude < zone.radius * 0.7 then
				return true
			end
		end
		return false
	end

	for _, part in ipairs(areas) do
		local cf, size = part.CFrame, part.Size
		local halfX = math.max(0, size.X / 2 - 2)
		local halfZ = math.max(0, size.Z / 2 - 2)
		local candidates = { part.Position }
		for x = -halfX, halfX, spacing do
			for z = -halfZ, halfZ, spacing do
				table.insert(candidates, (cf * CFrame.new(x, size.Y / 2, z)).Position)
			end
		end
		for _, wp in ipairs(candidates) do
			if alreadyCovered(wp) then
				continue
			end
			if not tooClose(wp, occupied, 1.05) then
				table.insert(spots, wp)
				table.insert(occupied, posXZ(wp))
			end
		end
	end
	return spots
end

local function placeOneSprinkler()
	local plotId = getPlotIdNumber()
	if not getPlot() or not plotId then
		return 0, "no plot"
	end

	-- Never place on top of an existing sprinkler
	if hasLiveSprinkler() then
		State.SprinklerZones = { State.SprinklerZones[1] }
		return 0, "using existing"
	end

	local tool = findSprinklerTool(Settings.SprinklerType)
	if not tool then
		return 0, "no sprinkler tool"
	end
	if not equipTool(tool) then
		return 0, "equip failed"
	end

	local sprinklerName = tool:GetAttribute("Sprinkler")
	local radius = getEffectiveRadius(sprinklerName)
	local pos = State.LastSprinklerPos
	if not pos then
		local spots = buildSprinklerPlacementSpots()
		pos = spots[1]
	end
	if not pos then
		local areas = getPlantAreaParts()
		if areas[1] then
			pos = areas[1].Position
		end
	end
	if not pos then
		return 0, "no place spot"
	end

	local count = tool:GetAttribute("Count")
	if type(count) == "number" and count <= 0 then
		return 0, "no sprinkler tool"
	end

	-- Final re-check right before fire (race with server / other scripts)
	if hasLiveSprinkler() then
		State.SprinklerZones = { State.SprinklerZones[1] }
		return 0, "using existing"
	end

	Networking.Place.PlaceSprinkler:Fire(pos, sprinklerName, tool, plotId)
	State.Stats.sprinklers += 1
	State.LastSprinklerPos = pos
	State.SprinklerPlacedAt = os.clock()
	State.SprinklerZones = {
		{ position = pos, radius = radius, name = sprinklerName },
	}
	task.wait(0.4)
	refreshSprinklerZonesFromPlot()
	if not State.SprinklerZones or #State.SprinklerZones == 0 then
		State.SprinklerZones = {
			{ position = pos, radius = radius, name = sprinklerName },
		}
	else
		State.SprinklerZones = { State.SprinklerZones[1] }
		State.LastSprinklerPos = State.SprinklerZones[1].position
	end
	return 1, sprinklerName
end

-- Ensures exactly one live sprinkler. Never places if one already exists.
local function ensureSprinkler(_forceReplace)
	if not Settings.AutoSprinkler then
		refreshSprinklerZonesFromPlot()
		if hasLiveSprinkler() then
			State.SprinklerZones = { State.SprinklerZones[1] }
			return 0, "using existing"
		end
		return 0, "auto off"
	end

	if hasLiveSprinkler() then
		State.SprinklerZones = { State.SprinklerZones[1] }
		return 0, "using existing"
	end

	return placeOneSprinkler()
end

local function placeSprinklersForWave()
	return ensureSprinkler(false)
end

-- Blocks until a sprinkler is live (places one if AutoSprinkler), or fails.
local function requireSprinklerForPlanting()
	if hasLiveSprinkler() then
		State.SprinklerZones = { State.SprinklerZones[1] }
		return true, "using existing"
	end
	if not Settings.AutoSprinkler then
		return false, "no sprinkler on plot"
	end
	local _, err = ensureSprinkler(false)
	if hasLiveSprinkler() then
		return true, err or "ready"
	end
	return false, err or "no sprinkler"
end

local function buildPlantSpots(limit, spacingOverride)
	local occupied = getPlantPositions()
	local spacing = math.max(1.05, spacingOverride or Settings.PlantSpacing)
	local spots = {}
	local requireRadius = Settings.PlantInSprinklerRadiusOnly

	refreshSprinklerZonesFromPlot()
	local zones = State.SprinklerZones

	if requireRadius then
		if not zones or #zones == 0 then
			return {}
		end
		for _, zone in ipairs(zones) do
			local r = zone.radius * 0.98
			local origin = zone.position
			for x = -r, r, spacing do
				for z = -r, r, spacing do
					if x * x + z * z > r * r then
						continue
					end
					local probe = Vector3.new(origin.X + x, origin.Y, origin.Z + z)
					local ok, ground = isOnPlantArea(probe)
					if not ok then
						continue
					end
					local wp = ground or probe
					if tooClose(wp, occupied, 1.02) then
						continue
					end
					table.insert(spots, Vector3.new(wp.X, wp.Y + 0.05, wp.Z))
					table.insert(occupied, Vector3.new(wp.X, 0, wp.Z))
					if limit and #spots >= limit then
						return spots
					end
				end
			end
		end
		return spots
	end

	for _, part in ipairs(getPlantAreaParts()) do
		local cf, size = part.CFrame, part.Size
		local halfX = size.X / 2 - spacing * 0.5
		local halfZ = size.Z / 2 - spacing * 0.5
		for x = -halfX, halfX, spacing do
			for z = -halfZ, halfZ, spacing do
				local wp = (cf * CFrame.new(x, size.Y / 2, z)).Position
				if not tooClose(wp, occupied, 1.02) then
					table.insert(spots, wp + Vector3.new(0, 0.05, 0))
					table.insert(occupied, Vector3.new(wp.X, 0, wp.Z))
					if limit and #spots >= limit then
						return spots
					end
				end
			end
		end
	end
	return spots
end

local function plantWave(maxCount)
	-- Never plant without a live sprinkler when auto/circle planting is on
	if Settings.AutoSprinkler or Settings.PlantInSprinklerRadiusOnly then
		if not hasLiveSprinkler() then
			local ok, err = requireSprinklerForPlanting()
			if not ok or not hasLiveSprinkler() then
				return 0, err or "no sprinkler"
			end
		end
	end

	local tool = findSeedTool(Settings.SeedFilter)
	if not tool then
		return 0, "No seed tool"
	end
	if not equipTool(tool) then
		return 0, "Failed to equip seed"
	end
	local seedName = tool:GetAttribute("SeedTool")
	local target = math.max(1, maxCount or Settings.MaxPerBatch)

	-- Try normal spacing, then denser if we can't fill the wave
	local spots = buildPlantSpots(target, Settings.PlantSpacing)
	if #spots < target then
		spots = buildPlantSpots(target, 1.15)
	end
	if #spots < target then
		spots = buildPlantSpots(target, 1.08)
	end
	if #spots == 0 and Settings.PlantInSprinklerRadiusOnly then
		return 0, "No spots in sprinkler radius"
	end

	local planted = 0
	for _, pos in ipairs(spots) do
		if not State.Running then
			break
		end
		if planted >= target then
			break
		end
		-- Stop mid-wave if sprinkler despawned
		if (Settings.AutoSprinkler or Settings.PlantInSprinklerRadiusOnly) and not hasLiveSprinkler() then
			setStatus("Sprinkler gone — paused planting")
			break
		end
		tool = findSeedTool(Settings.SeedFilter)
		if not tool then
			break
		end
		if tool.Parent ~= LocalPlayer.Character then
			equipTool(tool)
		end
		local count = tool:GetAttribute("Count")
		if type(count) == "number" and count <= 0 then
			break
		end
		Networking.Plant.PlantSeed:Fire(pos, seedName, tool)
		planted += 1
		State.Stats.planted += 1
		if planted % 5 == 0 or planted == target or planted == #spots then
			setStatus(string.format("Planting wave… %d/%d", planted, target))
		end
		task.wait(Settings.PlantDelay)
	end
	if planted < target then
		setStatus(string.format("Wave capped by free spots: %d/%d", planted, target))
		task.wait(0.4)
	end
	return planted, seedName
end

local function countSet(set)
	local n = 0
	for _ in pairs(set) do
		n += 1
	end
	return n
end

local function snapshotNewPlants(beforeSet)
	local folder = getPlantsFolder()
	local tracked = {}
	if not folder then
		return tracked
	end
	for _, p in ipairs(folder:GetChildren()) do
		if not beforeSet[p.Name] then
			tracked[p.Name] = true
		end
	end
	return tracked
end

-- Wait until the planted seeds actually show up on the plot (replica lag)
local function waitForWavePlants(beforeSet, expected, timeout)
	expected = math.max(0, expected or 0)
	timeout = timeout or 12
	local deadline = os.clock() + timeout
	local tracked = snapshotNewPlants(beforeSet)
	local lastCount = countSet(tracked)
	local stableSince = os.clock()

	while State.Running and os.clock() < deadline do
		tracked = snapshotNewPlants(beforeSet)
		local n = countSet(tracked)
		setStatus(string.format("Waiting for plants to appear… %d/%d", n, expected))
		if expected > 0 and n >= expected then
			return tracked, n
		end
		if n > lastCount then
			lastCount = n
			stableSince = os.clock()
		elseif n > 0 and os.clock() - stableSince > 1.25 then
			-- Count stopped rising — wave likely fully synced
			return tracked, n
		end
		task.wait(0.2)
	end
	tracked = snapshotNewPlants(beforeSet)
	return tracked, countSet(tracked)
end

local function waitForBatchGrowth(trackedNames, clearCap)
	local folder = getPlantsFolder()
	if not folder then
		return
	end
	local deadline = os.clock() + clearCap
	local total = countSet(trackedNames)

	local function growthStats()
		local growing, ready, gone = 0, 0, 0
		for name in pairs(trackedNames) do
			local p = folder:FindFirstChild(name)
			if not p then
				gone += 1
			elseif plantIsGrowing(p) then
				growing += 1
			else
				ready += 1
				local h = getPlantFeet(p, { fresh = true })
				if type(h) == "number" and h >= Settings.TargetHeight then
					markKeeper(p, h)
				end
			end
		end
		return growing, ready, gone
	end

	local lastScan = 0
	while State.Running and os.clock() < deadline do
		-- Do NOT place a sprinkler during growth — that wastes lifetime.
		-- Next plant wave will place one if needed.

		local growing, ready, gone = growthStats()
		if os.clock() - lastScan > 1.5 then
			scanAndMarkKeepers()
			lastScan = os.clock()
		end
		local remaining = math.max(0, math.ceil(deadline - os.clock()))
		setStatus(string.format("Growing wave… ready %d · growing %d · %ds left", ready, growing, remaining))

		if growing == 0 then
			scanAndMarkKeepers()
			-- Entire wave finished growing — do NOT shovel yet (caller clears)
			return
		end
		if State.FoundKeeper and Settings.StopWhenFound then
			scanAndMarkKeepers()
			return
		end
		task.wait(0.25)
	end
	scanAndMarkKeepers()
	setStatus("Growth wait timed out — clearing shorts…")
end

local function plantNameSet()
	local folder = getPlantsFolder()
	local set = {}
	if not folder then
		return set
	end
	for _, p in ipairs(folder:GetChildren()) do
		set[p.Name] = true
	end
	return set
end

local function outOfSeeds()
	-- If a seed is selected in the dropdown, only that seed counts.
	-- Running out of it must stop the farm — never swap to another seed.
	local tool = findSeedTool(Settings.SeedFilter)
	if not tool then
		return true
	end
	local count = tool:GetAttribute("Count")
	if type(count) == "number" then
		return count <= 0
	end
	return false
end

local function selectedSeedLabel()
	local filter = Settings.SeedFilter
	if filter and filter ~= "" then
		return filter
	end
	local tool = findSeedTool("")
	return (tool and tool:GetAttribute("SeedTool")) or "seeds"
end

local function doAutoSell()
	if not Settings.AutoSell then
		return
	end
	local interval = math.max(1, tonumber(Settings.AutoSellInterval) or 3)
	if os.clock() - State.LastSell < interval then
		return
	end
	State.LastSell = os.clock()
	pcall(function()
		Networking.NPCS.SellAll:Fire()
	end)
end

-- Always sell on a timer (not only between waves)
task.spawn(function()
	while true do
		task.wait(0.25)
		if State.Running or Settings.AutoSell then
			-- Sell while farm is running; also allow sell-only if toggled on
			if State.Running and Settings.AutoSell then
				doAutoSell()
			end
		end
	end
end)

------------------------------------------------------------------------
-- Main loops
------------------------------------------------------------------------
local function finishAndStop(reason)
	setStatus(reason or "Stopping… clearing leftovers")
	clearUnqualified({ force = Settings.DeleteAllPlants })
	State.Running = false
	setStatus(reason or "Stopped")
end

local function runBatchLoop()
	setStatus("Batch mode started")
	while State.Running do
		if outOfSeeds() then
			finishAndStop("Out of " .. selectedSeedLabel() .. " — stopped")
			return
		end
		doAutoSell()

		if Settings.AutoSprinkler then
			setStatus("Checking sprinkler…")
			local ok, sErr = requireSprinklerForPlanting()
			if not ok then
				if sErr == "no sprinkler tool" then
					setStatus("No sprinklers — add some to backpack")
				else
					setStatus("Waiting for sprinkler before planting… (" .. tostring(sErr) .. ")")
				end
				task.wait(1.5)
				continue
			end
			if sErr == "using existing" then
				setStatus("Sprinkler active — planting wave…")
			else
				setStatus("Sprinkler ready — planting wave…")
			end
		elseif Settings.PlantInSprinklerRadiusOnly and not hasLiveSprinkler() then
			setStatus("No sprinkler on plot — place one or enable auto sprinkler")
			task.wait(1.5)
			continue
		end

		local target = Settings.MaxPerBatch
		local before = plantNameSet()
		setStatus(string.format("Planting wave… 0/%d", target))
		local planted, seedOrErr = plantWave(target)
		if planted == 0 then
			if seedOrErr == "No seed tool" or outOfSeeds() then
				finishAndStop("Out of " .. selectedSeedLabel() .. " — stopped")
				return
			end
			if seedOrErr == "no sprinkler" or seedOrErr == "no sprinkler tool" or seedOrErr == "no sprinkler on plot" then
				setStatus("Need a live sprinkler before planting…")
				task.wait(1.5)
				continue
			end
			setStatus("No free spots in circle — clearing shorts")
			clearUnqualified()
			if State.FoundKeeper and Settings.StopWhenFound then
				finishAndStop("Keeper found — stopped")
				return
			end
			task.wait(1)
			continue
		end

		setStatus(string.format("Planted %d/%d — syncing…", planted, target))
		local tracked, appeared = waitForWavePlants(before, planted, 15)
		if appeared == 0 then
			setStatus("Plants did not appear — retrying next wave")
			task.wait(1)
			continue
		end

		setStatus(string.format("Growing %d plants (max wait %ds)…", appeared, Settings.BatchClearCap))
		waitForBatchGrowth(tracked, Settings.BatchClearCap)

		setStatus(string.format("Wave grown — shoveling shorts (%d planted)…", appeared))
		local removed = clearWaveShorts(tracked)
		setStatus(string.format("Shoveled %d shorts from wave", removed))

		State.BatchId += 1
		State.Stats.cycles += 1

		if State.FoundKeeper and Settings.StopWhenFound then
			finishAndStop("Keeper found — cleared junk, stopped")
			return
		end
		-- Do not place sprinkler after harvest — wait until next plant wave
		task.wait(0.35)
	end
end

local function runContinuousLoop()
	setStatus("Continuous mode (claim crops — no shovel)")
	while State.Running do
		doAutoSell()

		-- Claim / harvest first (never touch keepers / tall bamboo)
		scanAndMarkKeepers()
		local folder = getPlantsFolder()
		if folder then
			for _, plant in ipairs(folder:GetChildren()) do
				if not State.Running then
					break
				end
				local seed = plant:GetAttribute("SeedName")
				local filter = Settings.SeedFilter
				if filter ~= "" and seed ~= filter then
					continue
				end
				if isKeeper(plant) then
					continue
				end
				if not plantIsGrowing(plant) then
					collectPlant(plant)
					task.wait(0.05)
				end
			end
		end

		-- Selected seed gone → claim leftovers of that seed, then stop (never swap seeds)
		if outOfSeeds() then
			setStatus("Out of " .. selectedSeedLabel() .. " — claiming leftovers…")
			local anyGrowing = false
			folder = getPlantsFolder()
			if folder then
				for _, plant in ipairs(folder:GetChildren()) do
					local filter = Settings.SeedFilter
					if filter ~= "" and plant:GetAttribute("SeedName") ~= filter then
						continue
					end
					if isKeeper(plant) then
						continue
					end
					if plantIsGrowing(plant) then
						anyGrowing = true
					else
						collectPlant(plant)
						task.wait(0.05)
					end
				end
			end
			if not anyGrowing then
				finishAndStop("Out of " .. selectedSeedLabel() .. " — stopped")
				return
			end
			task.wait(0.35)
			State.Stats.cycles += 1
			continue
		end

		-- Place / require sprinkler only right before planting
		if Settings.AutoSprinkler then
			if not hasLiveSprinkler() then
				setStatus("Placing sprinkler for planting…")
				local ok, err = requireSprinklerForPlanting()
				if not ok then
					setStatus("Waiting for sprinkler… (" .. tostring(err) .. ")")
					task.wait(1.25)
					continue
				end
			end
		elseif Settings.PlantInSprinklerRadiusOnly and not hasLiveSprinkler() then
			setStatus("No sprinkler on plot — can't plant yet")
			task.wait(1.25)
			continue
		end

		if (Settings.AutoSprinkler or Settings.PlantInSprinklerRadiusOnly) and not hasLiveSprinkler() then
			setStatus("Sprinkler missing — not planting")
			task.wait(0.5)
			continue
		end
		local planted = plantWave(Settings.MaxPerBatch)
		if planted > 0 then
			setStatus(string.format("Continuous — planted %d in radius…", planted))
		else
			if outOfSeeds() then
				finishAndStop("Out of " .. selectedSeedLabel() .. " — stopped")
				return
			end
			setStatus("Continuous — claiming…")
		end
		task.wait(0.2)
		State.Stats.cycles += 1
	end
end

local function startFarm()
	if State.Running then
		return
	end
	if not getPlot() then
		setStatus("No plot found")
		return
	end
	State.Running = true
	State.FoundKeeper = false
	State.StartedAt = os.clock()
	State.Stats = {
		planted = 0,
		shoveled = 0,
		claimed = 0,
		removed = 0,
		keepers = State.Stats.keepers or 0,
		sprinklers = 0,
		bestFt = State.Stats.bestFt or 0,
		cycles = 0,
	}
	scanAndMarkKeepers()
	setStatus("hunting…")
	task.spawn(function()
		if Settings.PlantMode == "Continuous" then
			runContinuousLoop()
		else
			runBatchLoop()
		end
		State.Running = false
		if State.UI and State.UI.refreshHuntBtn then
			State.UI.refreshHuntBtn()
		end
	end)
	if State.UI and State.UI.refreshHuntBtn then
		State.UI.refreshHuntBtn()
	end
end

local function stopFarm()
	State.Running = false
	setStatus("Stopped")
	if State.UI and State.UI.refreshHuntBtn then
		State.UI.refreshHuntBtn()
	end
end

local function purgeSpecies(species)
	if State.Purging then
		return
	end
	local purgeAll = not species or species == ""
	State.Purging = true
	task.spawn(function()
		setStatus(purgeAll and "PURGE all junk (keepers safe)…" or ("PURGE " .. species .. "…"))
		local folder = getPlantsFolder()
		local total = 0
		if folder then
			for _, p in ipairs(folder:GetChildren()) do
				local seed = p:GetAttribute("SeedName")
				local match = purgeAll or seed == species
				if match and not isKeeper(p) then
					total += 1
				end
			end
		end
		local done = 0
		while folder and State.Purging do
			local target = nil
			for _, p in ipairs(folder:GetChildren()) do
				local seed = p:GetAttribute("SeedName")
				local match = purgeAll or seed == species
				if match and not isKeeper(p) and not plantIsGrowing(p) then
					target = p
					break
				end
			end
			if not target then
				-- wait briefly for growers, or stop
				local stillGrowing = false
				for _, p in ipairs(folder:GetChildren()) do
					local seed = p:GetAttribute("SeedName")
					local match = purgeAll or seed == species
					if match and not isKeeper(p) and plantIsGrowing(p) then
						stillGrowing = true
						break
					end
				end
				if stillGrowing then
					setStatus("PURGE waiting for growers…")
					task.wait(0.5)
					continue
				end
				break
			end
			if shovelPlant(target) then
				done += 1
				setStatus(string.format("PURGE %d/%d (keepers kept)", done, total))
			else
				break
			end
		end
		State.Purging = false
		if purgeAll then
			setStatus(string.format("PURGE done — removed %d plants (super/keepers kept)", done))
		else
			setStatus(string.format("PURGE done — removed %d %s (keepers kept)", done, species))
		end
	end)
end

------------------------------------------------------------------------
-- Anti-AFK
------------------------------------------------------------------------
task.spawn(function()
	LocalPlayer.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
	while task.wait(45) do
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local Theme = {
	bg = Color3.fromRGB(16, 18, 17),
	surface = Color3.fromRGB(24, 27, 25),
	panel = Color3.fromRGB(26, 30, 28),
	card = Color3.fromRGB(32, 36, 34),
	cardSoft = Color3.fromRGB(40, 46, 42),
	elevated = Color3.fromRGB(38, 44, 40),
	stroke = Color3.fromRGB(70, 120, 85),
	strokeSoft = Color3.fromRGB(48, 58, 52),
	accent = Color3.fromRGB(110, 220, 130),
	accentDim = Color3.fromRGB(55, 140, 80),
	accentDeep = Color3.fromRGB(35, 90, 55),
	text = Color3.fromRGB(245, 248, 246),
	label = Color3.fromRGB(180, 195, 185),
	muted = Color3.fromRGB(120, 135, 125),
	warn = Color3.fromRGB(240, 190, 80),
	stop = Color3.fromRGB(200, 70, 70),
	start = Color3.fromRGB(60, 170, 95),
	input = Color3.fromRGB(18, 22, 20),
}

local ROOT_W, ROOT_H = 740, 480
local ROOT_H_MIN = 50
local PAD = 14
local GAP = 10
local R = 16
local R_SM = 10

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or R_SM)
	c.Parent = parent
	return c
end

local function pad(parent, t, b, l, r)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, t or 8)
	p.PaddingBottom = UDim.new(0, b or 8)
	p.PaddingLeft = UDim.new(0, l or 10)
	p.PaddingRight = UDim.new(0, r or 10)
	p.Parent = parent
	return p
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency ~= nil and transparency or 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function mkLabel(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = props.font or Enum.Font.Gotham
	l.TextSize = props.size or 12
	l.TextColor3 = props.color or Theme.text
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextYAlignment = props.valign or Enum.TextYAlignment.Center
	l.Text = props.text or ""
	l.TextTruncate = props.truncate or Enum.TextTruncate.None
	l.TextWrapped = props.wrap or false
	if props.sizeU then
		l.Size = props.sizeU
	end
	if props.pos then
		l.Position = props.pos
	end
	if props.anchor then
		l.AnchorPoint = props.anchor
	end
	l.ZIndex = props.z or 1
	l.Parent = parent
	return l
end

local function mkCard(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.bg or Theme.card
	f.BorderSizePixel = 0
	f.Size = props.size or UDim2.fromScale(1, 1)
	if props.pos then
		f.Position = props.pos
	end
	f.Parent = parent
	corner(f, props.r or R_SM)
	if props.stroke ~= false then
		stroke(f, props.strokeColor or Theme.strokeSoft, props.strokeThick or 1, props.strokeT or 0.4)
	end
	return f
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "GuildEventFarmer"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Root = Instance.new("Frame")
Root.Name = "Root"
Root.Size = UDim2.fromOffset(ROOT_W, ROOT_H)
Root.Position = UDim2.new(0, 16, 0.5, -ROOT_H / 2)
Root.BackgroundColor3 = Theme.bg
Root.BackgroundTransparency = 0.08
Root.BorderSizePixel = 0
Root.ClipsDescendants = true
Root.Parent = Gui
corner(Root, R)
stroke(Root, Theme.accent, 1.5, 0.35)

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 54)
Header.BackgroundTransparency = 1
Header.Active = true
Header.ZIndex = 2
Header.Parent = Root

local Title = mkLabel(Header, {
	text = "Tallest Guild",
	font = Enum.Font.GothamBold,
	size = 18,
	color = Theme.text,
	pos = UDim2.fromOffset(PAD, 10),
	sizeU = UDim2.new(1, -90, 0, 22),
	z = 3,
})
Title.Active = true

mkLabel(Header, {
	text = "Grow a Garden 2  ·  v1.2",
	font = Enum.Font.Gotham,
	size = 11,
	color = Theme.muted,
	pos = UDim2.fromOffset(PAD, 32),
	sizeU = UDim2.new(1, -90, 0, 14),
	z = 3,
})

local function headerBtn(text, xOff, fg)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, xOff, 0.5, 0)
	b.Size = UDim2.fromOffset(28, 28)
	b.BackgroundColor3 = Theme.card
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 15
	b.TextColor3 = fg or Theme.muted
	b.Text = text
	b.AutoButtonColor = false
	b.ZIndex = 3
	b.Parent = Header
	corner(b, 8)
	stroke(b, Theme.strokeSoft, 1, 0.35)
	local base = fg or Theme.muted
	b.MouseEnter:Connect(function()
		b.TextColor3 = Theme.text
		b.BackgroundColor3 = Theme.cardSoft
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3 = base
		b.BackgroundColor3 = Theme.card
	end)
	return b
end

local MinBtn = headerBtn("–", -(PAD + 32))
local CloseBtn = headerBtn("×", -PAD, Color3.fromRGB(210, 130, 130))

local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Position = UDim2.fromOffset(PAD, 54)
Body.Size = UDim2.new(1, -PAD * 2, 1, -(54 + 48 + PAD))
Body.BackgroundTransparency = 1
Body.ZIndex = 2
Body.Parent = Root

local Left = Instance.new("Frame")
Left.Size = UDim2.new(0.5, -GAP / 2, 1, 0)
Left.BackgroundTransparency = 1
Left.Parent = Body

local InvRow = Instance.new("Frame")
InvRow.Size = UDim2.new(1, 0, 0, 56)
InvRow.BackgroundTransparency = 1
InvRow.Parent = Left

local function invTile(xScale, name)
	local f = mkCard(InvRow, {
		pos = UDim2.new(xScale, xScale > 0 and GAP / 2 or 0, 0, 0),
		size = UDim2.new(0.5, -GAP / 2, 1, 0),
		strokeColor = Theme.stroke,
		strokeT = 0.55,
	})
	local value = mkLabel(f, {
		text = "0",
		font = Enum.Font.GothamBold,
		size = 18,
		color = Theme.text,
		align = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(12, 8),
		sizeU = UDim2.new(1, -20, 0, 22),
	})
	local caption = mkLabel(f, {
		text = name,
		font = Enum.Font.GothamMedium,
		size = 10,
		color = Theme.muted,
		align = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(12, 32),
		sizeU = UDim2.new(1, -20, 0, 14),
		truncate = Enum.TextTruncate.AtEnd,
	})
	return value, caption
end

local SeedCountLabel, SeedCountCaption = invTile(0, "SEEDS LEFT")
local SprinklerCountLabel, SprinklerCountCaption = invTile(0.5, "SPRINKLERS LEFT")

local StatusCard = mkCard(Left, {
	pos = UDim2.fromOffset(0, 56 + GAP),
	size = UDim2.new(1, 0, 0, 52),
	strokeColor = Theme.stroke,
	strokeT = 0.55,
})

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(7, 7)
StatusDot.Position = UDim2.fromOffset(12, 12)
StatusDot.BackgroundColor3 = Theme.muted
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusCard
corner(StatusDot, 4)

local StatusLabel = mkLabel(StatusCard, {
	text = "Idle",
	font = Enum.Font.Gotham,
	size = 12,
	color = Theme.label,
	pos = UDim2.fromOffset(26, 6),
	sizeU = UDim2.new(1, -36, 0, 18),
	truncate = Enum.TextTruncate.AtEnd,
})

local Progress = Instance.new("Frame")
Progress.Position = UDim2.fromOffset(12, 28)
Progress.Size = UDim2.new(1, -24, 0, 14)
Progress.BackgroundColor3 = Theme.input
Progress.BorderSizePixel = 0
Progress.Parent = StatusCard
corner(Progress, 7)

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.fromScale(0.12, 1)
ProgressFill.BackgroundColor3 = Theme.accent
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = Progress
corner(ProgressFill, 7)

local ProgressLabel = mkLabel(Progress, {
	text = "idle — 0 fired",
	font = Enum.Font.GothamBold,
	size = 10,
	color = Theme.text,
	align = Enum.TextXAlignment.Center,
	sizeU = UDim2.fromScale(1, 1),
	z = 2,
})

local PhaseLabel = mkLabel(Left, {
	text = "sprinkler: — | sell: — | phase: idle",
	font = Enum.Font.Gotham,
	size = 10,
	color = Theme.muted,
	pos = UDim2.fromOffset(2, 56 + GAP + 52 + 6),
	sizeU = UDim2.new(1, -4, 0, 14),
})

local statsTop = 56 + GAP + 52 + 6 + 14 + GAP
local StatsGrid = Instance.new("Frame")
StatsGrid.Position = UDim2.fromOffset(0, statsTop)
StatsGrid.Size = UDim2.new(1, 0, 1, -statsTop)
StatsGrid.BackgroundTransparency = 1
StatsGrid.Parent = Left

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize = UDim2.new(0.25, -GAP * 0.75, 0.5, -GAP * 0.75)
GridLayout.CellPadding = UDim2.fromOffset(GAP, GAP)
GridLayout.SortOrder = Enum.SortOrder.LayoutOrder
GridLayout.FillDirectionMaxCells = 4
GridLayout.Parent = StatsGrid

local StatValues = {}
local function addStat(order, key, caption, accent)
	local f = mkCard(StatsGrid, {
		strokeColor = Theme.stroke,
		strokeT = 0.55,
	})
	f.LayoutOrder = order
	local v = mkLabel(f, {
		text = "0",
		font = Enum.Font.GothamBold,
		size = 15,
		color = accent and Theme.accent or Theme.text,
		align = Enum.TextXAlignment.Center,
		pos = UDim2.fromOffset(4, 12),
		sizeU = UDim2.new(1, -8, 0, 20),
	})
	mkLabel(f, {
		text = caption,
		font = Enum.Font.GothamMedium,
		size = 9,
		color = Theme.muted,
		align = Enum.TextXAlignment.Center,
		pos = UDim2.fromOffset(4, 34),
		sizeU = UDim2.new(1, -8, 0, 12),
	})
	StatValues[key] = v
end

addStat(1, "best", "BEST HEIGHT", true)
addStat(2, "keepers", "KEEPERS", true)
addStat(3, "removed", "REMOVED", false)
addStat(4, "cycles", "CYCLES", false)
addStat(5, "elapsed", "ELAPSED", false)
addStat(6, "planted", "PLANTED", false)
addStat(7, "sprinklers", "SPRINKLERS", false)
addStat(8, "inPlot", "IN PLOT", false)

local Right = mkCard(Body, {
	pos = UDim2.new(0.5, GAP / 2, 0, 0),
	size = UDim2.new(0.5, -GAP / 2, 1, 0),
	bg = Theme.surface,
	strokeColor = Theme.stroke,
	strokeT = 0.5,
	r = R_SM,
})
Right.ClipsDescendants = true

local Scroll = Instance.new("ScrollingFrame")
Scroll.Position = UDim2.fromOffset(GAP, GAP)
Scroll.Size = UDim2.new(1, -GAP * 2, 1, -GAP * 2)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Theme.accentDim
Scroll.CanvasSize = UDim2.fromOffset(0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Right

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0, 8)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Scroll
pad(Scroll, 4, 8, 6, 6)

local function section(text, order)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 16)
	f.LayoutOrder = order
	f.Parent = Scroll
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(3, 12)
	bar.Position = UDim2.fromOffset(0, 2)
	bar.BackgroundColor3 = Theme.accent
	bar.BorderSizePixel = 0
	bar.Parent = f
	corner(bar, 2)
	mkLabel(f, {
		text = string.upper(text),
		font = Enum.Font.GothamBold,
		size = 11,
		color = Theme.label,
		pos = UDim2.fromOffset(10, 0),
		sizeU = UDim2.new(1, -10, 1, 0),
	})
	return f
end

local function rowFrame(order, height)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height or 30)
	f.LayoutOrder = order
	f.BorderSizePixel = 0
	f.Parent = Scroll
	return f
end

local function labelOn(parent, text)
	return mkLabel(parent, {
		text = text,
		font = Enum.Font.Gotham,
		size = 12,
		color = Theme.label,
		sizeU = UDim2.new(0.52, 0, 1, 0),
	})
end

local function makeToggle(order, text, get, set)
	local f = rowFrame(order, 32)
	labelOn(f, text)
	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, 0, 0.5, 0)
	btn.Size = UDim2.fromOffset(84, 26)
	btn.BackgroundColor3 = Theme.card
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 11
	btn.AutoButtonColor = false
	btn.Parent = f
	corner(btn, 8)
	local st = stroke(btn, Theme.strokeSoft, 1.2, 0.3)
	local function paint()
		local on = get()
		btn.Text = on and "On" or "Off"
		btn.TextColor3 = on and Theme.text or Theme.muted
		st.Color = on and Theme.accent or Theme.strokeSoft
		st.Transparency = on and 0.15 or 0.35
		btn.BackgroundColor3 = on and Theme.accentDeep or Theme.card
	end
	paint()
	btn.MouseButton1Click:Connect(function()
		set(not get())
		paint()
		saveSettings()
	end)
	return f, paint
end

local function makeNumber(order, text, get, set)
	local f = rowFrame(order, 30)
	labelOn(f, text)
	local box = Instance.new("TextBox")
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, 0, 0.5, 0)
	box.Size = UDim2.fromOffset(78, 26)
	box.BackgroundColor3 = Theme.input
	box.Font = Enum.Font.GothamMedium
	box.TextSize = 12
	box.TextColor3 = Theme.text
	box.ClearTextOnFocus = false
	box.Text = tostring(get())
	box.BorderSizePixel = 0
	box.Parent = f
	corner(box, 8)
	stroke(box, Theme.stroke, 1, 0.5)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			set(n)
			box.Text = tostring(get())
			saveSettings()
		else
			box.Text = tostring(get())
		end
	end)
	return f
end

local function makeDropdown(order, text, optionsFn, get, set, opts)
	opts = opts or {}
	local allowEmpty = opts.allowEmpty ~= false
	local emptyLabel = opts.emptyLabel or "(auto / any)"
	local f = rowFrame(order, 32)
	labelOn(f, text).Size = UDim2.new(0.40, 0, 1, 0)

	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -2, 0.5, 0)
	btn.Size = UDim2.fromOffset(175, 26)
	btn.BackgroundColor3 = Theme.card
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 11
	btn.TextColor3 = Theme.text
	btn.TextTruncate = Enum.TextTruncate.AtEnd
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Parent = f
	corner(btn, R_SM)
	stroke(btn, Theme.stroke, 1, 0.45)
	pad(btn, 0, 0, 8, 20)

	local arrow = mkLabel(btn, {
		text = "▾",
		font = Enum.Font.GothamBold,
		size = 11,
		color = Theme.muted,
		align = Enum.TextXAlignment.Center,
		anchor = Vector2.new(1, 0.5),
		pos = UDim2.new(1, 4, 0.5, 0),
		sizeU = UDim2.fromOffset(16, 16),
	})

	local menu
	local function refresh()
		local v = get()
		btn.Text = (v and v ~= "") and v or emptyLabel
	end
	refresh()

	local function closeMenu()
		if menu then
			menu:Destroy()
			menu = nil
		end
		if State.OpenDropdown == btn then
			State.OpenDropdown = nil
		end
	end

	local function openMenu()
		if State.OpenDropdown and State.OpenDropdown ~= btn then
			if State.CloseOpenDropdown then
				State.CloseOpenDropdown()
			end
		end
		if menu then
			closeMenu()
			return
		end

		local choices = {}
		if allowEmpty then
			table.insert(choices, { value = "", label = emptyLabel })
		end
		for _, o in ipairs(optionsFn() or {}) do
			table.insert(choices, { value = o, label = o })
		end
		if #choices == 0 then
			return
		end

		menu = Instance.new("Frame")
		menu.Name = "DropdownMenu"
		menu.BackgroundColor3 = Theme.panel
		menu.BorderSizePixel = 0
		menu.ZIndex = 50
		menu.Parent = Gui
		corner(menu, R_SM)
		stroke(menu, Theme.stroke, 1, 0.1)

		local abs = btn.AbsolutePosition
		local absSize = btn.AbsoluteSize
		local guiAbs = Gui.AbsolutePosition
		local height = math.min(180, 8 + #choices * 28)
		menu.Size = UDim2.fromOffset(math.max(175, absSize.X), height)
		menu.Position = UDim2.fromOffset(abs.X - guiAbs.X, abs.Y - guiAbs.Y + absSize.Y + 4)

		local scroll = Instance.new("ScrollingFrame")
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Size = UDim2.fromScale(1, 1)
		scroll.ScrollBarThickness = 3
		scroll.ScrollBarImageColor3 = Theme.accentDim
		scroll.CanvasSize = UDim2.fromOffset(0, #choices * 28)
		scroll.ZIndex = 51
		scroll.Parent = menu
		pad(scroll, 4, 4, 4, 4)

		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 2)
		list.Parent = scroll

		local cur = get() or ""
		for _, choice in ipairs(choices) do
			local item = Instance.new("TextButton")
			item.Size = UDim2.new(1, -8, 0, 26)
			item.BackgroundColor3 = (choice.value == cur) and Theme.accentDim or Theme.card
			item.BorderSizePixel = 0
			item.Font = Enum.Font.Gotham
			item.TextSize = 12
			item.TextColor3 = Theme.text
			item.TextXAlignment = Enum.TextXAlignment.Left
			item.Text = "  " .. choice.label
			item.ZIndex = 52
			item.AutoButtonColor = true
			item.Parent = scroll
			corner(item, R_SM)
			item.MouseButton1Click:Connect(function()
				set(choice.value)
				refresh()
				saveSettings()
				closeMenu()
			end)
		end

		State.OpenDropdown = btn
		State.CloseOpenDropdown = closeMenu

		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			task.defer(function()
				if not menu or not menu.Parent then
					if conn then
						conn:Disconnect()
					end
					return
				end
				local pos = input.Position
				local mpos, msize = menu.AbsolutePosition, menu.AbsoluteSize
				local bpos, bsize = btn.AbsolutePosition, btn.AbsoluteSize
				local inMenu = pos.X >= mpos.X and pos.X <= mpos.X + msize.X and pos.Y >= mpos.Y and pos.Y <= mpos.Y + msize.Y
				local inBtn = pos.X >= bpos.X and pos.X <= bpos.X + bsize.X and pos.Y >= bpos.Y and pos.Y <= bpos.Y + bsize.Y
				if not inMenu and not inBtn then
					closeMenu()
					if conn then
						conn:Disconnect()
					end
				end
			end)
		end)
	end

	btn.MouseButton1Click:Connect(openMenu)
	return f, refresh, closeMenu
end

local function makeButton(order, text, color, callback)
	local f = rowFrame(order, 32)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundColor3 = color
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = Theme.text
	btn.Text = text
	btn.BorderSizePixel = 0
	btn.Parent = f
	corner(btn, R_SM)
	btn.MouseButton1Click:Connect(callback)
	return f
end

local function makeTextInput(order, text, get, set, placeholder)
	local f = rowFrame(order, 52)
	mkLabel(f, {
		text = text,
		font = Enum.Font.Gotham,
		size = 11,
		color = Theme.label,
		sizeU = UDim2.new(1, 0, 0, 16),
	})
	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(0, 20)
	box.Size = UDim2.new(1, 0, 0, 26)
	box.BackgroundColor3 = Theme.input
	box.Font = Enum.Font.Gotham
	box.TextSize = 11
	box.TextColor3 = Theme.text
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = Theme.muted
	box.ClearTextOnFocus = false
	box.Text = get() or ""
	box.BorderSizePixel = 0
	box.Parent = f
	corner(box, R_SM)
	stroke(box, Theme.strokeSoft, 1, 0.35)
	box.FocusLost:Connect(function()
		set(box.Text)
		saveSettings()
	end)
	return f, box
end

-- Settings content
section("Mode", 1)
local _, refreshMode = makeDropdown(2, "Mode", function()
	return { "Trees (shovel)", "Crops (claim)" }
end, function()
	return Settings.PlantMode == "Continuous" and "Crops (claim)" or "Trees (shovel)"
end, function(v)
	Settings.PlantMode = (v == "Crops (claim)") and "Continuous" or "Batch"
end, { allowEmpty = false })

section("Planting", 3)
makeNumber(4, "Keep if taller (ft)", function()
	return Settings.TargetHeight
end, function(v)
	Settings.TargetHeight = math.max(1, math.floor(v))
end)
makeNumber(5, "Growth wait (sec)", function()
	return Settings.BatchClearCap
end, function(v)
	Settings.BatchClearCap = math.clamp(math.floor(v), 5, 600)
end)
makeNumber(6, "Seeds / wave", function()
	return Settings.MaxPerBatch
end, function(v)
	Settings.MaxPerBatch = math.clamp(math.floor(v), 1, 10000)
end)
makeNumber(7, "Plant delay (s)", function()
	return Settings.PlantDelay
end, function(v)
	Settings.PlantDelay = math.clamp(v, 0, 2)
end)
makeToggle(8, "Stop when tall found", function()
	return Settings.StopWhenFound
end, function(v)
	Settings.StopWhenFound = v
end)
makeToggle(9, "Shovel every type", function()
	return Settings.DeleteAllPlants
end, function(v)
	Settings.DeleteAllPlants = v
end)

section("Sell", 10)
makeToggle(11, "Auto sell", function()
	return Settings.AutoSell
end, function(v)
	Settings.AutoSell = v
end)
makeNumber(12, "Sell every (sec)", function()
	return Settings.AutoSellInterval
end, function(v)
	Settings.AutoSellInterval = math.max(1, math.floor(v))
end)

section("Sprinkler", 13)
makeToggle(14, "Place sprinkler first", function()
	return Settings.AutoSprinkler
end, function(v)
	Settings.AutoSprinkler = v
end)
makeToggle(15, "Only plant in circle", function()
	return Settings.PlantInSprinklerRadiusOnly
end, function(v)
	Settings.PlantInSprinklerRadiusOnly = v
end)
local _, refreshSprinkler = makeDropdown(16, "Sprinkler item", function()
	local names = listSprinklerNames()
	if #names == 0 then
		return { "Super Sprinkler", "Legendary Sprinkler", "Rare Sprinkler", "Uncommon Sprinkler", "Common Sprinkler" }
	end
	return names
end, function()
	return Settings.SprinklerType
end, function(v)
	Settings.SprinklerType = (v ~= "" and v) or "Super Sprinkler"
end, { allowEmpty = false })

local _, refreshSeed = makeDropdown(17, "Seed", listSeedNames, function()
	return Settings.SeedFilter
end, function(v)
	Settings.SeedFilter = v
end, { allowEmpty = true, emptyLabel = "(auto / any)" })

makeToggle(18, "Show height ESP", function()
	return Settings.ShowESP
end, function(v)
	Settings.ShowESP = v
	if not v then
		clearAllEsp()
	else
		refreshHeightEsp()
	end
	saveSettings()
end)

local function listExemptOptions()
	local species = listPlantSpecies()
	local seeds = listSeedNames()
	local pool, seen = {}, {}
	for _, s in ipairs(species) do
		seen[s] = true
		table.insert(pool, s)
	end
	for _, s in ipairs(seeds) do
		if not seen[s] then
			table.insert(pool, s)
		end
	end
	table.sort(pool)
	return pool
end

local _, refreshExempt = makeDropdown(19, "Exempt (never delete)", function()
	local labeled = {}
	for _, s in ipairs(listExemptOptions()) do
		table.insert(labeled, (Settings.Exempted[s] and "✓ " or "") .. s)
	end
	return labeled
end, function()
	local t = {}
	for k in pairs(Settings.Exempted) do
		table.insert(t, k)
	end
	table.sort(t)
	return #t > 0 and table.concat(t, ", ") or ""
end, function(v)
	local name = tostring(v or ""):gsub("^✓%s*", ""):gsub("^%s+", "")
	if name == "" then
		Settings.Exempted = {}
		return
	end
	if Settings.Exempted[name] then
		Settings.Exempted[name] = nil
	else
		Settings.Exempted[name] = true
	end
end, { allowEmpty = true, emptyLabel = "(none — pick to toggle)" })

section("Purge", 20)
local purgeSpeciesName = ""
local _, refreshPurge = makeDropdown(21, "Purge species", listPlantSpecies, function()
	return purgeSpeciesName
end, function(v)
	purgeSpeciesName = v
end, {
	allowEmpty = true,
	emptyLabel = "(auto / any = all junk)",
})
makeButton(22, "PURGE (keep tall / exempt)", Theme.stop, function()
	purgeSpecies(purgeSpeciesName)
end)

section("Webhook", 23)
local _, webhookBox = makeTextInput(24, "Discord webhook URL", function()
	return Settings.WebhookUrl
end, function(v)
	Settings.WebhookUrl = v
end, "https://discord.com/api/webhooks/...")
makeButton(25, "TEST WEBHOOK", Color3.fromRGB(48, 72, 96), function()
	setStatus("Testing webhook…")
	task.spawn(function()
		local ok, err = sendWebhook("Webhook test", "Tallest Guild is connected.", 0x4A90D9)
		setStatus(ok and "Webhook OK" or ("Webhook failed: " .. tostring(err)))
	end)
end)

-- Footer
local Footer = Instance.new("Frame")
Footer.AnchorPoint = Vector2.new(0, 1)
Footer.Position = UDim2.new(0, PAD, 1, -PAD)
Footer.Size = UDim2.new(1, -PAD * 2, 0, 40)
Footer.BackgroundTransparency = 1
Footer.Parent = Root

local HuntBtn = Instance.new("TextButton")
HuntBtn.Size = UDim2.fromScale(1, 1)
HuntBtn.BackgroundColor3 = Theme.start
HuntBtn.Font = Enum.Font.GothamBold
HuntBtn.TextSize = 14
HuntBtn.TextColor3 = Theme.text
HuntBtn.Text = "START HUNT"
HuntBtn.BorderSizePixel = 0
HuntBtn.AutoButtonColor = false
HuntBtn.Parent = Footer
corner(HuntBtn, R_SM)
stroke(HuntBtn, Theme.accent, 1, 0.45)

local Hint = mkLabel(Gui, {
	text = "↑  RightShift hide / show   ·   X shut down",
	font = Enum.Font.Gotham,
	size = 11,
	color = Color3.fromRGB(200, 210, 202),
	align = Enum.TextXAlignment.Center,
	sizeU = UDim2.fromOffset(ROOT_W, 16),
})
Hint.BackgroundTransparency = 1

local function syncHint()
	Hint.Position = UDim2.fromOffset(
		Root.AbsolutePosition.X - Gui.AbsolutePosition.X,
		Root.AbsolutePosition.Y - Gui.AbsolutePosition.Y + Root.AbsoluteSize.Y + 10
	)
	Hint.Visible = Root.Visible and not State.Minimized
end

local function refreshHuntBtn()
	if State.Running then
		HuntBtn.Text = "STOP HUNT"
		HuntBtn.BackgroundColor3 = Theme.stop
	else
		HuntBtn.Text = "START HUNT"
		HuntBtn.BackgroundColor3 = Theme.start
	end
end


State.UI = {
	StatusLabel = StatusLabel,
	StatusDot = StatusDot,
	refreshHuntBtn = refreshHuntBtn,
}

local function applyMinimized()
	if State.Minimized then
		Body.Visible = false
		Footer.Visible = false
		Root.Size = UDim2.fromOffset(ROOT_W, ROOT_H_MIN)
	else
		Body.Visible = true
		Footer.Visible = true
		Root.Size = UDim2.fromOffset(ROOT_W, ROOT_H)
	end
	syncHint()
end

HuntBtn.MouseButton1Click:Connect(function()
	if State.Running then
		stopFarm()
	else
		refreshSeed()
		refreshPurge()
		refreshExempt()
		refreshSprinkler()
		refreshMode()
		startFarm()
	end
	refreshHuntBtn()
end)

MinBtn.MouseButton1Click:Connect(function()
	State.Minimized = not State.Minimized
	applyMinimized()
end)

CloseBtn.MouseButton1Click:Connect(function()
	State.Running = false
	State.Purging = false
	clearAllEsp()
	setStatus("Shut down")
	Gui:Destroy()
end)

local function phaseName()
	local s = string.lower(State.Status or "")
	if not State.Running and not State.Purging then
		return "idle"
	end
	if s:find("sprinkler", 1, true) then
		return "sprinkler"
	end
	if s:find("plant", 1, true) then
		return "planting"
	end
	if s:find("grow", 1, true) then
		return "growing"
	end
	if s:find("shovel", 1, true) or s:find("clear", 1, true) then
		return "shoveling"
	end
	if s:find("claim", 1, true) then
		return "claiming"
	end
	if s:find("purge", 1, true) then
		return "purge"
	end
	if s:find("keeper", 1, true) then
		return "keeper"
	end
	return State.Running and "running" or "idle"
end

local function refreshDashboard()
	local seedName = Settings.SeedFilter
	if not seedName or seedName == "" then
		local tool = findSeedTool("")
		seedName = tool and tool:GetAttribute("SeedTool") or "SEED"
	end
	local seedLeft = countToolsByAttr("SeedTool", Settings.SeedFilter ~= "" and Settings.SeedFilter or nil)
	local sprLeft = countToolsByAttr("Sprinkler", Settings.SprinklerType)
	SeedCountLabel.Text = tostring(seedLeft)
	SeedCountCaption.Text = string.upper(tostring(seedName)) .. " LEFT"
	SprinklerCountLabel.Text = tostring(sprLeft)
	SprinklerCountCaption.Text = string.upper(tostring(Settings.SprinklerType or "SPRINKLER")) .. " LEFT"

	local folder = getPlantsFolder()
	local inPlot, best = 0, State.Stats.bestFt or 0
	if folder then
		for _, p in ipairs(folder:GetChildren()) do
			if p:IsA("Model") then
				inPlot += 1
				local ft = getPlantFeet(p)
				if ft > best then
					best = ft
				end
			end
		end
	end
	State.Stats.bestFt = math.max(State.Stats.bestFt or 0, best)

	local s = State.Stats
	StatValues.best.Text = tostring(math.floor(State.Stats.bestFt + 0.5))
	StatValues.keepers.Text = tostring(s.keepers)
	StatValues.removed.Text = tostring(s.removed or (s.shoveled + s.claimed))
	StatValues.cycles.Text = tostring(s.cycles)
	StatValues.planted.Text = tostring(s.planted)
	StatValues.sprinklers.Text = tostring(s.sprinklers)
	StatValues.inPlot.Text = tostring(inPlot)
	local elapsed = State.StartedAt and (os.clock() - State.StartedAt) or 0
	StatValues.elapsed.Text = formatElapsed(elapsed)

	local mode = Settings.PlantMode == "Continuous" and "continuous" or "batch"
	local fired = s.planted
	ProgressLabel.Text = string.format("%s — %d fired", mode, fired)
	ProgressFill.Size = UDim2.fromScale(State.Running and 1 or 0.12, 1)

	local sprLeftSec = 0
	if State.SprinklerPlacedAt then
		sprLeftSec = math.max(0, math.floor(getSprinklerLifetime(Settings.SprinklerType) - (os.clock() - State.SprinklerPlacedAt)))
	elseif countLiveSprinklers() > 0 then
		sprLeftSec = getSprinklerLifetime(Settings.SprinklerType)
	end
	local sellLeft = "—"
	if Settings.AutoSell then
		sellLeft = tostring(math.max(0, math.floor(Settings.AutoSellInterval - (os.clock() - (State.LastSell or 0)))))
	end
	PhaseLabel.Text = string.format("sprinkler: %ss | sell: %ss | phase: %s", sprLeftSec, sellLeft, phaseName())
end

task.spawn(function()
	while Gui.Parent do
		refreshDashboard()
		task.wait(0.35)
	end
end)

------------------------------------------------------------------------
-- Keybinds
------------------------------------------------------------------------
local function shutdown()
	State.Running = false
	State.Purging = false
	clearAllEsp()
	setStatus("Shut down")
	Gui:Destroy()
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		State.Hidden = not State.Hidden
		Root.Visible = not State.Hidden
		if State.CloseOpenDropdown then
			State.CloseOpenDropdown()
		end
	elseif input.KeyCode == Enum.KeyCode.X then
		shutdown()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if State.CloseOpenDropdown then
			State.CloseOpenDropdown()
		end
	end
end)

-- Drag from header / title
do
	local dragging, dragStart, startPos
	local function beginDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Root.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end
	Header.InputBegan:Connect(beginDrag)
	Title.InputBegan:Connect(beginDrag)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

setStatus("ready — plant inside the sprinkler circle")
refreshHuntBtn()
print("[TallestGuild] loaded | RightShift hide | X exit")
