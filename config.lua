local urls = {
    "https://raw.githubusercontent.com/SBeZ-Real/managerbeta/main/Script/source.lua",
    "https://anymanager.spcfy.eu/client/source"
}
local source
for _, url in ipairs(urls) do
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 400 then
        source = body
        break
    end
end
if not source then
    warn("[Any] Không tải được script")
    return
end
local compiler = loadstring or load
if type(compiler) ~= "function" then
    warn("[Any] Executor không hỗ trợ loadstring")
    return
end
local fn, err = compiler(source)
if not fn then
    warn("[Any] Lỗi cú pháp source: " .. tostring(err))
    return
end
local ok, runtimeError = pcall(fn)
if not ok then warn("[Any] " .. tostring(runtimeError)) end
