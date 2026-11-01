local shared = type(getgenv) == "function" and getgenv() or _G
shared.ManagerConfig = type(shared.ManagerConfig) == "table" and shared.ManagerConfig or {}
local config = shared.ManagerConfig
config.ApiUrl = tostring(config.ApiUrl or ""):gsub("/+$", "")
if config.ApiUrl == "" or config.ApiUrl == "https://managerbeta-api.spcfy.eu" then
    config.ApiUrl = "https://anymanager.spcfy.eu"
end
config.LicenseKey = tostring(config.LicenseKey or "")
config.CloudName = config.CloudName or ""
config.AutoHopByTime = config.AutoHopByTime ~= false
config.HopIntervalMinutes = tonumber(config.HopIntervalMinutes) or 60
config.HopOnFriendJoin = config.HopOnFriendJoin == true
config.MaxPing = tonumber(config.MaxPing) or 300
if config.LicenseKey == "" or config.LicenseKey == "PASTE_KEY_FROM_GENKEY" then
    error("ManagerBeta: chua nhap LicenseKey")
end
if config.ApiUrl:sub(1, 8):lower() ~= "https://" then
    error("ManagerBeta: ApiUrl phai la HTTPS")
end
local url = "https://raw.githubusercontent.com/SBeZ-Real/managerbeta/main/managerbeta"
local ok, body = pcall(function()
    return game:HttpGet(url)
end)
if not ok or type(body) ~= "string" or body == "" then
    error("ManagerBeta: GitHub loader khong tai duoc: " .. tostring(body):sub(1, 160))
end
local compiler = loadstring or load
if type(compiler) ~= "function" then
    error("ManagerBeta: executor khong ho tro loadstring")
end
local script, compileError = compiler(body)
if not script then
    error("ManagerBeta: source GitHub khong bien dich duoc: " .. tostring(compileError))
end
return script()
