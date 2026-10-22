if type(getgenv) ~= "function" then
    warn("Executor không hỗ trợ getgenv()")
    return
end

local env = getgenv()
local config = env.ManagerConfig or {}
local apiBaseUrl = tostring(config.ApiBaseUrl or ""):gsub("/+$", "")
local sourceKey = tostring(config.SourceAccessKey or "")

if apiBaseUrl == "" or sourceKey == "" then
    warn("Thiếu ApiBaseUrl hoặc SourceAccessKey trong config local.")
    return
end

if type(loadstring) ~= "function" then
    warn("Executor không hỗ trợ loadstring()")
    return
end

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

if type(httpRequest) ~= "function" then
    warn("Executor không hỗ trợ request có Header Authorization.")
    return
end

local ok, response = pcall(function()
    return httpRequest({
        Url = apiBaseUrl .. "/client/source",
        Method = "GET",
        Headers = {
            ["Authorization"] = "Bearer " .. sourceKey
        }
    })
end)

if not ok or type(response) ~= "table" then
    warn("Không kết nối được API source: " .. tostring(response))
    return
end

local statusCode = tonumber(response.StatusCode or response.Status) or 0
local source = response.Body

if statusCode ~= 200 or type(source) ~= "string" or source == "" or source:match("^%s*404") or source:match("^%s*Not Found") then
    warn("Không tải được source riêng tư. HTTP: " .. tostring(statusCode))
    return
end

local scriptFunction, compileError = loadstring(source)

if type(scriptFunction) ~= "function" then
    warn("Lỗi biên dịch source: " .. tostring(compileError))
    return
end

local ran, runError = pcall(scriptFunction)

if not ran then
    warn("Lỗi khi chạy manager source: " .. tostring(runError))
end
