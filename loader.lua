-- ERLC Alt Account Manager - GitHub Loader (Exploit Version)
-- Replace YOUR_USERNAME and YOUR_REPO with your actual GitHub details

-- Configuration - CHANGE THESE TO YOUR GITHUB DETAILS
local GITHUB_USERNAME = "TBoneIsntCool" -- Replace with your GitHub username
local REPO_NAME = "erlc-alt-script"     -- Replace with your repository name
local BRANCH = "main"                   -- Usually "main" or "master"

-- Construct the GitHub raw URL
local SCRIPT_URL = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/erlc-manager.lua",
    GITHUB_USERNAME,
    REPO_NAME,
    BRANCH
)

local function log(message)
    print("[ERLC Loader] " .. message)
    warn("[ERLC Loader] " .. message)
end

local function loadScript()
    log("Loading ERLC Manager from GitHub...")
    log("URL: " .. SCRIPT_URL)
    
    local success, response = pcall(function()
        return request({
            Url = SCRIPT_URL,
            Method = "GET"
        })
    end)
    
    if success and response.Success then
        log("Successfully downloaded script (" .. #response.Body .. " characters)")
        
        -- Execute the script
        local executeSuccess, executeError = pcall(function()
            loadstring(response.Body)()
        end)
        
        if executeSuccess then
            log("ERLC Manager loaded and started successfully!")
        else
            log("Error executing script: " .. tostring(executeError))
        end
    else
        log("Failed to download script from GitHub")
        if response then
            log("Status: " .. tostring(response.StatusCode))
            log("Error: " .. tostring(response.StatusMessage or "Unknown error"))
        end
    end
end

-- Load and run the script
loadScript()
