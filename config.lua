if type(getgenv) ~= "function" then
    warn("Executor không hỗ trợ getgenv()")
    return
end

local env = getgenv()

env.ManagerConfig = {
    AutoHopByTime = true,
    HopInterval = "1h 30m",
    HopOnFriendJoin = true,
    SummaryUpdateInterval = "3m",
    DatabaseUrl = ""
}

env.ManagerSourceUrl = "https://raw.githubusercontent.com/SBeZ-Real/managerbeta/main/managerbeta"

if type(loadstring) ~= "function" then
    warn("Executor không hỗ trợ loadstring()")
    return
end

local ok, source = pcall(function()
    return game:HttpGet(env.ManagerSourceUrl)
end)

if not ok then
    warn("Không tải được source: " .. tostring(source))
    return
end

if type(source) ~= "string" or source == "" or source:match("^%s*404") or source:match("^%s*Not Found") then
    warn("URL source không hợp lệ hoặc không có quyền truy cập")
    return
end

local scriptFunction, compileError = loadstring(source)

if type(scriptFunction) ~= "function" then
    warn("Lỗi biên dịch source: " .. tostring(compileError))
    return
end

scriptFunction()
