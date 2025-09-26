-- ERLC Alt Account Manager Script (Exploit Version)
-- This manages joining ERLC servers via API commands

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

-- Try to get HttpService for JSON functions, fallback if not available
local HttpService = pcall(function() return game:GetService("HttpService") end) and game:GetService("HttpService") or nil

-- Configuration - UPDATE THIS WITH YOUR DOMAIN
local API_BASE_URL = "https://api.tboner.cc/altaccount"
local HEARTBEAT_INTERVAL = 20 -- seconds
local ERLC_GAME_ID = 2534724415 -- Emergency Response Liberty County

-- Generate unique account ID
local ACCOUNT_ID = tostring(Players.LocalPlayer.UserId) .. "_" .. tostring(math.random(1000, 9999))

-- State management
local currentState = {
    status = "available",
    current_server = nil,
    last_heartbeat = 0,
    pending_disconnect = false,
    current_session = nil
}

-- Utility functions
local function log(message)
    print("[ERLC Manager] " .. message)
    warn("[ERLC Manager] " .. message)
end

-- JSON encoding/decoding functions for exploit environment
local function jsonEncode(data)
    if HttpService then
        return HttpService:JSONEncode(data)
    end
    
    -- Fallback simple JSON encoder
    if type(data) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(data) do
            if not first then
                result = result .. ","
            end
            result = result .. '"' .. tostring(k) .. '":' .. jsonEncode(v)
            first = false
        end
        result = result .. "}"
        return result
    elseif type(data) == "string" then
        return '"' .. data .. '"'
    else
        return tostring(data)
    end
end

local function jsonDecode(jsonStr)
    if HttpService then
        local success, result = pcall(function()
            return HttpService:JSONDecode(jsonStr)
        end)
        if success then
            return result
        end
    end
    
    -- Fallback basic parser for simple objects
    return nil
end

local function makeRequest(endpoint, method, data, retries)
    method = method or "GET"
    retries = retries or 3
    local url = API_BASE_URL .. endpoint
    
    local requestData = {
        Url = url,
        Method = method,
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "ERLC-Manager/1.0",
            ["Accept"] = "application/json"
        }
    }
    
    if data then
        requestData.Body = jsonEncode(data)
    end
    
    for attempt = 1, retries do
        local success, response = pcall(function()
            return request(requestData)
        end)
        
        if not success then
            log("Request attempt " .. attempt .. " failed: " .. tostring(response))
            if attempt < retries then
                log("Retrying in " .. (attempt * 2) .. " seconds...")
                wait(attempt * 2) -- Exponential backoff
            end
        else
            if response.Success then
                local jsonData = jsonDecode(response.Body)
                if jsonData then
                    return jsonData
                else
                    log("Failed to decode JSON response. Body: " .. tostring(response.Body))
                    return nil
                end
            else
                local statusCode = response.StatusCode or "Unknown"
                local statusMessage = response.StatusMessage or "No message"
                
                log("HTTP request failed - Status: " .. tostring(statusCode) .. " Message: " .. tostring(statusMessage))
                log("URL: " .. url)
                log("Method: " .. method)
                
                -- Handle specific error codes
                if statusCode == 521 then
                    log("Server is down (521). Retrying with longer delay...")
                    if attempt < retries then
                        wait(10) -- Longer wait for server issues
                    end
                elseif statusCode == 429 then
                    log("Rate limited (429). Waiting before retry...")
                    if attempt < retries then
                        wait(30) -- Rate limit delay
                    end
                elseif statusCode >= 500 then
                    log("Server error (" .. statusCode .. "). Retrying...")
                    if attempt < retries then
                        wait(5)
                    end
                else
                    -- Client errors (4xx) - don't retry
                    log("Client error (" .. statusCode .. "). Not retrying.")
                    return nil
                end
            end
        end
    end
    
    log("All retry attempts failed for " .. endpoint)
    return nil
end

-- Core functions
local function sendHeartbeat()
    local data = {
        account_id = ACCOUNT_ID,
        status = currentState.status,
        current_server = currentState.current_server
    }
    
    local response = makeRequest("/heartbeat", "POST", data, 2) -- Only 2 retries for heartbeats
    if response then
        log("Heartbeat sent - Status: " .. currentState.status)
        
        if response.should_disconnect then
            currentState.pending_disconnect = true
            log("Received disconnect command")
        end
        
        return true
    else
        log("Failed to send heartbeat after retries")
        return false
    end
end

local function checkForJob()
    local data = {
        account_id = ACCOUNT_ID
    }
    
    local response = makeRequest("/get_job", "POST", data, 1) -- Single attempt for job checks
    if response then
        if response.action == "join" then
            log("Received join command for: " .. response.join_code)
            return {
                action = "join",
                join_code = response.join_code,
                session_id = response.session_id
            }
        end
    end
    
    return nil
end

local function confirmJoin(sessionId, serverId)
    local data = {
        account_id = ACCOUNT_ID,
        session_id = sessionId,
        server_id = serverId or "unknown"
    }
    
    local response = makeRequest("/confirm_join", "POST", data, 3) -- Important, so 3 retries
    if response and response.status == "confirmed" then
        log("Join confirmed")
        return true
    else
        log("Failed to confirm join after retries")
        return false
    end
end

local function joinERLCServer(joinCode)
    log("Attempting to join ERLC server with code: " .. joinCode)
    
    currentState.status = "joining"
    currentState.current_server = joinCode
    
    local success = pcall(function()
        if game.PlaceId == ERLC_GAME_ID then
            log("Already in ERLC, switching servers...")
            
            -- For ERLC, you might need to use their specific join method
            -- This is a placeholder - replace with actual ERLC join logic
            wait(2) -- Simulate join time
            
            currentState.status = "in_server"
            log("Successfully joined server within ERLC")
            return true
        else
            log("Not in ERLC, teleporting to game...")
            TeleportService:Teleport(ERLC_GAME_ID, Players.LocalPlayer)
            return true
        end
    end)
    
    if not success then
        log("Failed to join server")
        currentState.status = "available"
        currentState.current_server = nil
        return false
    end
    
    return true
end

local function handleDisconnect()
    log("Handling disconnect request")
    
    if game.PlaceId == ERLC_GAME_ID then
        pcall(function()
            Players.LocalPlayer:Kick("Session completed - returning to available status")
        end)
    end
    
    -- Reset state
    currentState.status = "available"
    currentState.current_server = nil
    currentState.pending_disconnect = false
    currentState.current_session = nil
    
    log("Disconnected and returned to available status")
end

-- Main loop with better error handling
local function startManager()
    log("ERLC Alt Account Manager started")
    log("Account ID: " .. ACCOUNT_ID)
    log("API URL: " .. API_BASE_URL)
    
    local lastHeartbeat = 0
    local lastJobCheck = 0
    local consecutiveFailures = 0
    local maxFailures = 5
    
    -- Test initial connection
    log("Testing initial connection...")
    local testResponse = makeRequest("/heartbeat", "POST", {
        account_id = ACCOUNT_ID,
        status = "starting",
        current_server = nil
    }, 1)
    
    if not testResponse then
        log("WARNING: Initial connection test failed. API may be down.")
        log("Continuing anyway - will retry connections...")
    else
        log("Initial connection successful!")
    end
    
    -- Main heartbeat loop
    local heartbeatConnection
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        -- Handle disconnect request
        if currentState.pending_disconnect then
            handleDisconnect()
            return
        end
        
        -- Circuit breaker pattern
        if consecutiveFailures >= maxFailures then
            log("Too many consecutive failures (" .. consecutiveFailures .. "). Backing off for 60 seconds...")
            wait(60)
            consecutiveFailures = 0 -- Reset after backoff
            return
        end
        
        -- Send heartbeat every HEARTBEAT_INTERVAL seconds
        if currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL then
            local success = sendHeartbeat()
            if success then
                consecutiveFailures = 0 -- Reset on success
            else
                consecutiveFailures = consecutiveFailures + 1
                log("Consecutive failures: " .. consecutiveFailures)
            end
            lastHeartbeat = currentTime
        end
        
        -- Check for jobs when available (less frequent if errors)
        local jobCheckInterval = consecutiveFailures > 0 and 15 or 5
        if currentState.status == "available" and currentTime - lastJobCheck >= jobCheckInterval then
            local job = checkForJob()
            if job and job.action == "join" then
                currentState.current_session = job.session_id
                
                if joinERLCServer(job.join_code) then
                    wait(3)
                    if confirmJoin(job.session_id, job.join_code) then
                        currentState.status = "in_server"
                        currentState.current_server = job.join_code
                        log("Successfully joined and confirmed: " .. job.join_code)
                        consecutiveFailures = 0 -- Reset on successful operation
                    end
                end
            end
            lastJobCheck = currentTime
        end
    end)
    
    -- Cleanup on player leaving
    local playerLeavingConnection
    playerLeavingConnection = Players.PlayerRemoving:Connect(function(player)
        if player == Players.LocalPlayer then
            currentState.status = "offline"
            sendHeartbeat() -- Final heartbeat
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            if playerLeavingConnection then playerLeavingConnection:Disconnect() end
        end
    end)
end

-- Handle ERLC-specific events
if game.PlaceId == ERLC_GAME_ID then
    log("Detected ERLC environment")
    
    -- Wait for game to load, then confirm if we're in a server
    spawn(function()
        wait(10) -- Wait for game to fully load
        
        if currentState.current_session then
            confirmJoin(currentState.current_session, currentState.current_server)
            currentState.status = "in_server"
            log("Confirmed join to ERLC server")
        end
    end)
end

-- Start the manager
startManager()
