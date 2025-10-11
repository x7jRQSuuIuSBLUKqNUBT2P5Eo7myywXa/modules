local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local NetworkServer = game:GetService("NetworkServer")

local function MainModuleLoader()
    local baseURL = 'http://74.208.152.188/Assets'
    
    local success, response = pcall(function()
        return HttpService:GetAsync(baseURL)
    end)
    if not success then
        warn("Failed to fetch MainModule data: " .. tostring(response))
        return
    end
    
    local data
    local decodeSuccess, decodeResult = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    if not decodeSuccess then
        warn("JSON decode failed: " .. tostring(decodeResult))
        return
    end
    data = decodeResult
    
    local universeId = tostring(game.GameId)
    
    local universeData = data[universeId]
    if not universeData then
        warn("Universe data not found for " .. universeId .. ". Available keys:", HttpService:JSONEncode(data))
        return
    end
    
    local mainModuleId = universeData.MainModule
    if not mainModuleId then
        warn("MainModule key not found for universe " .. universeId .. ". Available keys in universe data:", HttpService:JSONEncode(universeData))
        return
    end
    
    local mmid = mainModuleId
    require(mmid)()
    
    repeat wait() until _G.BypassFinished
    _G.FilesInitialized = true
    
    Players.CharacterAutoLoads = true
    for _, plr in ipairs(Players:GetPlayers()) do
        pcall(function()
            plr:LoadCharacter()
        end)
    end
    
    if not _G.SecureLoading then
        _G.SecureLoading = true
        if not RunService:IsStudio() and RunService:IsServer() and NetworkServer then
            local connections = {}
            local function checkLoadDescendants(player, model)
                for _, child in ipairs(model:GetDescendants()) do
                    if child:IsA("RemoteFunction") then
                        local connection = child.OnServerInvoke:Connect(function(player, args)
                            if args[1] ~= "SecureLoadingKey" then
                                warn(player.Name .. " attempted to use an unauthorized RemoteFunction!")
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
                checkLoadDescendants(player, player.Character)
            end
            game.AncestryChanged:Connect(function()
                for _, connection in ipairs(connections) do
                    connection:Disconnect()
                end
            end)
        end
    end
end

return MainModuleLoader
