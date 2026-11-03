local url = "https://anymanager.spcfy.eu/client/source"
local ok, source = pcall(function() return game:HttpGet(url) end)
if not ok or type(source) ~= "string" or #source < 1000 then
    warn("[Any] Không tải được source công khai từ Spaceify")
    return
end
local fn, err = (loadstring or load)(source)
if not fn then warn("[Any] " .. tostring(err)) return end
local success, runtimeError = pcall(fn)
if not success then warn("[Any] " .. tostring(runtimeError)) end
