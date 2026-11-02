local shared = type(getgenv) == "function" and getgenv() or _G
shared.ManagerConfig = type(shared.ManagerConfig) == "table" and shared.ManagerConfig or {}
local config = shared.ManagerConfig
if not config.ApiUrl or config.ApiUrl == "" or config.ApiUrl == "https://managerbeta-api.spcfy.eu" then
    config.ApiUrl = "https://anymanager.spcfy.eu"
end
config.CloudName = config.CloudName or ""
config.AutoHopByTime = config.AutoHopByTime ~= false
config.HopIntervalMinutes = tonumber(config.HopIntervalMinutes) or 60
config.HopOnFriendJoin = config.HopOnFriendJoin == true
config.MaxPing = tonumber(config.MaxPing) or 300
local source = game:HttpGet("https://raw.githubusercontent.com/SBeZ-Real/managerbeta/main/managerbeta")
if type(source) ~= "string" or source == "" then error("ManagerBeta: GitHub Lua unavailable") end
local compiler = loadstring or load
if type(compiler) ~= "function" then error("Executor does not support loadstring") end
local chunk, err = compiler(source)
if not chunk then error(err) end
return chunk()
