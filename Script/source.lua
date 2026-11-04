local Env = type(getgenv) == "function" and getgenv() or _G
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local User = Players.LocalPlayer
local Request = (syn and syn.request) or (http and http.request) or http_request or request
local WebhookUrl = ""
local WebhookPath = "AnyPremiumManagers/webhook.txt"
local SourceUrl = "https://raw.githubusercontent.com/SBeZ-Real/managerbeta/main/Script/source.lua"
local ProgressPath = "AnyPremiumManagers/order.json"
local function normalizeWebhook(value)
    local url = type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
    if #url > 256 then return nil end
    local id, token = url:match("^https://discord%.com/api/webhooks/(%d+)/([%w_%-]+)$")
    if not id or #id < 16 or #id > 22 or not token or #token < 30 then return nil end
    return url
end
local function validWebhook()
    return normalizeWebhook(WebhookUrl) ~= nil
end
if type(readfile) == "function" then
    local ok, value = pcall(readfile, WebhookPath)
    if ok then WebhookUrl = normalizeWebhook(value) or "" end
end
if Env.__ANY_RUNNING and Env.__ANY_JOB_ID == tostring(game.JobId) then
    if Env.__ANY_OPEN_SETUP then task.spawn(Env.__ANY_OPEN_SETUP) end
    return
end
if Env.__ANY_CLEANUP then pcall(Env.__ANY_CLEANUP) end
Env.__ANY_RUNNING = true
Env.__ANY_JOB_ID = tostring(game.JobId)
local TeleportService = game:GetService("TeleportService")
local InputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local State = { active = false, starting = false, loading = false, name = "", selected = { 0, 1, 0, 0 }, remaining = 0, duration = 0, elapsed = 0, lastSync = 0, lastHeartbeat = 0, orderId = nil, periodic = false, friend = false, interval = 1800, nextHop = 0, hops = {}, highPing = 0, stopped = false, paused = true, teleporting = false, connections = {}, lastError = "", lastErrorAt = 0, ping = 0, windowOpen = false, runId = nil, sequence = 0, reporting = false, placeId = tostring(game.PlaceId), lastProgress = 0 }
local settingsPath = "AnyPremiumManagers/settings.json"
local function persistSettings()
    if type(writefile) ~= "function" then return end
    pcall(function()
        if type(makefolder) == "function" then pcall(makefolder, "AnyPremiumManagers") end
        writefile(settingsPath, Http:JSONEncode({ selected = State.selected, periodic = State.periodic, friend = State.friend, interval = State.interval }))
    end)
end
if type(readfile) == "function" and type(isfile) == "function" then
    pcall(function()
        if not isfile(settingsPath) then return end
        local saved = Http:JSONDecode(readfile(settingsPath))
        if type(saved) ~= "table" then return end
        local maximum = { math.floor(9007199254740991 / 86400) - 1, 23, 59, 59 }
        if type(saved.selected) == "table" then
            for index = 1, 4 do
                local value = tonumber(saved.selected[index])
                if value and value == math.floor(value) and value >= 0 and value <= maximum[index] then State.selected[index] = value end
            end
        end
        State.periodic = saved.periodic == true
        State.friend = saved.friend == true
        if type(saved.interval) == "number" then State.interval = math.clamp(saved.interval, 300, 10800) end
    end)
end
local function saveProgress()
    if not State.active or type(writefile) ~= "function" then return end
    pcall(function()
        if type(makefolder) == "function" then pcall(makefolder, "AnyPremiumManagers") end
        writefile(ProgressPath, Http:JSONEncode({ userId = tostring(User.UserId), runId = State.runId, orderId = State.orderId, name = State.name, duration = State.duration, elapsed = State.elapsed, placeId = State.placeId, sequence = State.sequence, selected = State.selected, savedAt = DateTime.now().UnixTimestamp }))
    end)
end
local function clearProgress()
    if type(delfile) == "function" then pcall(function() delfile(ProgressPath) end)
    elseif type(writefile) == "function" then pcall(function() writefile(ProgressPath, "{}") end) end
end
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64(data)
    local out = {}
    for index = 1, #data, 3 do
        local a = string.byte(data, index)
        local b = string.byte(data, index + 1)
        local c = string.byte(data, index + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local i = math.floor(n / 262144) % 64
        local j = math.floor(n / 4096) % 64
        local k = math.floor(n / 64) % 64
        local l = n % 64
        out[#out + 1] = alphabet:sub(i + 1, i + 1) .. alphabet:sub(j + 1, j + 1) .. (b and alphabet:sub(k + 1, k + 1) or '=') .. (c and alphabet:sub(l + 1, l + 1) or '=')
    end
    return table.concat(out)
end
local lastRelay = -math.huge
local function reportDiscord(event)
    if not State.active or not validWebhook() or type(Request) ~= "function" then return false end
    if event == "heartbeat" and os.clock() - lastRelay < 30 then return false end
    if State.reporting and event ~= "done" then
        if os.clock() - (State.reportStartedAt or os.clock()) < 25 then return false end
        State.reporting = false
    end
    if event ~= "done" then
        State.reporting = true
        State.reportStartedAt = os.clock()
    end
    State.sequence += 1
    saveProgress()
    local sequence = State.sequence
    if event ~= "done" then State.reportStartedSequence = sequence end
    local payload = { event = event, userId = tostring(User.UserId), username = User.Name, orderId = State.orderId, orderName = State.name, placeId = State.placeId, currentPlaceId = tostring(game.PlaceId), jobId = tostring(game.JobId), durationSeconds = math.floor(State.duration), elapsedSeconds = math.floor(State.elapsed), ping = State.ping, sentAt = DateTime.now().UnixTimestamp, runId = State.runId, seq = sequence }
    local content = "ANY|" .. base64(Http:JSONEncode(payload))
    lastRelay = os.clock()
    task.spawn(function()
        local attempts = event == "done" and 3 or 2
        local delivered = false
        local lastCode = 0
        for index = 1, attempts do
            local ok, response = pcall(Request, { Url = WebhookUrl .. "?wait=true", Method = "POST", Timeout = 8, Headers = { ["Content-Type"] = "application/json" }, Body = Http:JSONEncode({ content = content, allowed_mentions = { parse = {} } }) })
            local code = ok and type(response) == "table" and tonumber(response.StatusCode or response.Status) or 0
            lastCode = code
            if code == 200 or code == 204 then
                delivered = true
                if event == "done" then State.doneReported = true end
                break
            end
            local delayTime = 2
            if code == 429 and type(response) == "table" then
                local parsed
                pcall(function() parsed = Http:JSONDecode(response.Body or "") end)
                delayTime = type(parsed) == "table" and math.clamp(tonumber(parsed.retry_after) or 2, 1, 10) or 2
            end
            if index < attempts then task.wait(delayTime) end
        end
        if not State.lastReportStatusSequence or sequence >= State.lastReportStatusSequence then
            State.lastReportStatusSequence = sequence
            State.reportError = not delivered
            State.lastResponseCode = lastCode
            if delivered then State.lastDeliveryAt = os.clock() end
        end
        if not delivered then warn("[Any] Webhook POST failed, HTTP " .. tostring(lastCode)) end
        if event ~= "done" and State.reportStartedSequence == sequence then State.reporting = false end
    end)
    return true
end
local function toast(message)
    if State.wind then
        pcall(function() State.wind:Notify({ Title = "Any - Premium Managers", Content = tostring(message), Duration = 5 }) end)
    else
        pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Any - Premium Managers", Text = tostring(message), Duration = 5 }) end)
    end
end

local function showWebhookPrompt(onSaved)
    if State.webhookPrompt and State.webhookPrompt.Parent then
        State.webhookPrompt.Enabled = true
        return
    end
    local ok, parent = pcall(function()
        return (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
    if not ok or not parent then toast("Không thể mở màn hình nhập webhook") return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "AnyPremiumWebhookSetup"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.Parent = parent
    State.webhookPrompt = gui
    local shade = Instance.new("Frame")
    shade.Size = UDim2.fromScale(1, 1)
    shade.BackgroundColor3 = Color3.fromRGB(5, 8, 18)
    shade.BackgroundTransparency = 0.24
    shade.BorderSizePixel = 0
    shade.Parent = gui
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(math.max(280, math.min(456, viewport.X - 24)), 246)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.BackgroundColor3 = Color3.fromRGB(18, 25, 42)
    panel.BorderSizePixel = 0
    panel.Parent = shade
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 13)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(71, 120, 219)
    stroke.Parent = panel
    local function label(value, y, height, size, color)
        local item = Instance.new("TextLabel")
        item.Position = UDim2.fromOffset(16, y)
        item.Size = UDim2.new(1, -32, 0, height)
        item.BackgroundTransparency = 1
        item.Text = value
        item.Font = Enum.Font.Gotham
        item.TextSize = size
        item.TextWrapped = true
        item.TextColor3 = color
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.Parent = panel
        return item
    end
    local title = label("ANY  /  KẾT NỐI DISCORD", 13, 32, 18, Color3.fromRGB(231, 241, 255))
    title.Font = Enum.Font.GothamBold
    label("Dán URL webhook kênh báo cáo. Script lưu vào workspace để lần chạy sau tự sử dụng.", 48, 51, 12, Color3.fromRGB(170, 188, 216))
    local input = Instance.new("TextBox")
    input.Position = UDim2.fromOffset(16, 105)
    input.Size = UDim2.new(1, -32, 0, 42)
    input.BackgroundColor3 = Color3.fromRGB(31, 43, 66)
    input.TextColor3 = Color3.fromRGB(245, 248, 255)
    input.PlaceholderColor3 = Color3.fromRGB(130, 153, 182)
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.TextSize = 12
    input.Font = Enum.Font.Code
    input.Text = ""
    input.PlaceholderText = "https://discord.com/api/webhooks/ID/TOKEN"
    input.ClearTextOnFocus = false
    input.Parent = panel
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = input
    local status = label("", 151, 27, 12, Color3.fromRGB(255, 133, 133))
    local save = Instance.new("TextButton")
    save.Position = UDim2.fromOffset(16, 188)
    save.Size = UDim2.new(1, -32, 0, 42)
    save.BackgroundColor3 = Color3.fromRGB(51, 108, 224)
    save.TextColor3 = Color3.fromRGB(255, 255, 255)
    save.Font = Enum.Font.GothamBold
    save.TextSize = 14
    save.Text = "LƯU WEBHOOK VÀ TIẾP TỤC"
    save.Parent = panel
    Instance.new("UICorner", save).CornerRadius = UDim.new(0, 8)
    save.MouseButton1Click:Connect(function()
        local url = normalizeWebhook(input.Text)
        if not url then status.Text = "URL webhook không đúng định dạng." return end
        WebhookUrl = url
        State.reportError = false
        local saved = false
        if type(writefile) == "function" then
            saved = pcall(function()
                if type(makefolder) == "function" then pcall(makefolder, "AnyPremiumManagers") end
                writefile(WebhookPath, url)
            end)
        end
        gui:Destroy()
        State.webhookPrompt = nil
        toast(saved and "Webhook đã lưu trên thiết bị" or "Executor không lưu được file, sẽ hỏi lại lần sau")
        if type(onSaved) == "function" then task.spawn(onSaved) end
    end)
end

local function formatTime(t)
    t = math.max(0, math.ceil(t))
    return string.format("%02d:%02d:%02d:%02d", math.floor(t / 86400), math.floor(t % 86400 / 3600), math.floor(t % 3600 / 60), t % 60)
end

local function chosenSeconds()
    return State.selected[1] * 86400 + State.selected[2] * 3600 + State.selected[3] * 60 + State.selected[4]
end

local function ping()
    local ok, result = pcall(function() return User:GetNetworkPing() * 1000 end)
    if ok and type(result) == "number" then return math.floor(result) end
    local ok2, value = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok2 and math.floor(tonumber(value) or 0) or 0
end

local openSetup
local hop

local function makeHud()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AnyPremiumHUD"
    gui.ResetOnSpawn = false
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(900, 600)
    local width = math.min(336, math.max(265, math.floor(viewport.X * 0.78)))
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(width, 134)
    frame.Position = UDim2.new(1, -width - 12, 0, 48)
    frame.BackgroundColor3 = Color3.fromRGB(15, 19, 30)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(56, 83, 149)
    stroke.Thickness = 1
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 34)
    top.BackgroundColor3 = Color3.fromRGB(27, 37, 59)
    top.BorderSizePixel = 0
    top.Parent = frame
    Instance.new("UICorner", top).CornerRadius = UDim.new(0, 12)
    local brand = Instance.new("TextLabel")
    brand.Position = UDim2.fromOffset(12, 0)
    brand.Size = UDim2.new(1, -126, 1, 0)
    brand.BackgroundTransparency = 1
    brand.Text = "ANY  /  PREMIUM"
    brand.TextColor3 = Color3.fromRGB(216, 231, 255)
    brand.Font = Enum.Font.GothamBold
    brand.TextSize = 12
    brand.TextXAlignment = Enum.TextXAlignment.Left
    brand.Parent = top
    local function control(text, x, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(30, 26)
        b.Position = UDim2.new(1, x, 0, 4)
        b.BackgroundColor3 = Color3.fromRGB(37, 53, 83)
        b.Text = text
        b.TextColor3 = Color3.fromRGB(231, 240, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 15
        b.Parent = top
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
        b.MouseButton1Click:Connect(callback)
        return b
    end
    control("☰", -102, function() if openSetup then task.spawn(openSetup) end end)
    control("↻", -68, function() if hop then task.spawn(function() hop("manual") end) end end)
    local compact = false
    local body = Instance.new("Frame")
    body.Position = UDim2.fromOffset(0, 34)
    body.Size = UDim2.new(1, 0, 1, -34)
    body.BackgroundTransparency = 1
    body.Parent = frame
    local shrink = control("−", -34, function()
        compact = not compact
        body.Visible = not compact
        frame.Size = UDim2.fromOffset(width, compact and 34 or 134)
    end)
    local name = Instance.new("TextLabel")
    name.Position = UDim2.fromOffset(12, 7)
    name.Size = UDim2.new(1, -24, 0, 22)
    name.BackgroundTransparency = 1
    name.TextColor3 = Color3.new(1, 1, 1)
    name.Font = Enum.Font.GothamBold
    name.TextSize = 13
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = body
    local time = Instance.new("TextLabel")
    time.Position = UDim2.fromOffset(10, 27)
    time.Size = UDim2.new(1, -20, 0, 35)
    time.BackgroundTransparency = 1
    time.TextColor3 = Color3.fromRGB(113, 174, 255)
    time.Font = Enum.Font.Code
    time.TextSize = 24
    time.Parent = body
    local status = Instance.new("TextLabel")
    status.Position = UDim2.fromOffset(12, 64)
    status.Size = UDim2.new(1, -24, 0, 16)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(152, 177, 203)
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = body
    local track = Instance.new("Frame")
    track.Position = UDim2.new(0, 12, 1, -10)
    track.Size = UDim2.new(1, -24, 0, 5)
    track.BackgroundColor3 = Color3.fromRGB(42, 51, 70)
    track.BorderSizePixel = 0
    track.Parent = body
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Color3.fromRGB(60, 137, 240)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local dragging, dragStart, origin = false, nil, nil
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            origin = frame.Position
        end
    end)
    table.insert(State.connections, InputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    table.insert(State.connections, InputService.InputChanged:Connect(function(input)
        if dragging and dragStart and origin and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
        end
    end))
    State.hud = { gui = gui, name = name, time = time, fill = fill, status = status }
end

local function makePicker()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AnyTimeWheel"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(392, 298)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
    local pickerScale = Instance.new("UIScale")
    pickerScale.Scale = math.min(1, (viewport.X - 24) / 392, (viewport.Y - 24) / 298)
    pickerScale.Parent = panel
    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(70, 124, 207)
    outline.Thickness = 1
    outline.Parent = panel
    panel.BackgroundColor3 = Color3.fromRGB(20, 26, 39)
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 13)
    local head = Instance.new("TextLabel")
    head.Size = UDim2.new(1, 0, 0, 50)
    head.BackgroundTransparency = 1
    head.TextColor3 = Color3.new(1, 1, 1)
    head.TextSize = 19
    head.Font = Enum.Font.GothamBold
    head.Text = "ANY  /  THIẾT LẬP THỜI GIAN"
    head.Parent = panel
    local maximum = { math.floor(9007199254740991 / 86400) - 1, 23, 59, 59 }
    local labels = { "NGÀY", "GIỜ", "PHÚT", "GIÂY" }
    local preview = Instance.new("TextLabel")
    preview.Position = UDim2.fromOffset(20, 212)
    preview.Size = UDim2.fromOffset(352, 30)
    preview.BackgroundTransparency = 1
    preview.TextColor3 = Color3.fromRGB(151, 197, 249)
    preview.TextSize = 15
    preview.Font = Enum.Font.Code
    preview.TextXAlignment = Enum.TextXAlignment.Left
    preview.Parent = panel
    local fields = {}
    local function updatePreview()
        preview.Text = "Tổng: " .. formatTime(chosenSeconds())
    end
    for index = 1, 4 do
        local x = 14 + (index - 1) * 94
        local column = Instance.new("Frame")
        column.Position = UDim2.fromOffset(x, 56)
        column.Size = UDim2.fromOffset(86, 145)
        column.BackgroundColor3 = Color3.fromRGB(27, 39, 62)
        column.Parent = panel
        Instance.new("UICorner", column).CornerRadius = UDim.new(0, 8)
        local caption = Instance.new("TextLabel")
        caption.Size = UDim2.fromOffset(86, 25)
        caption.BackgroundTransparency = 1
        caption.Text = labels[index]
        caption.TextColor3 = Color3.fromRGB(181, 193, 215)
        caption.TextSize = 12
        caption.Parent = column
        local value = Instance.new("TextBox")
        value.Position = UDim2.fromOffset(5, 52)
        value.Size = UDim2.fromOffset(76, 37)
        value.BackgroundColor3 = Color3.fromRGB(35, 52, 79)
        value.ClearTextOnFocus = false
        value.TextScaled = true
        value.TextXAlignment = Enum.TextXAlignment.Center
        Instance.new("UICorner", value).CornerRadius = UDim.new(0, 7)
        value.TextColor3 = Color3.new(1, 1, 1)
        value.Font = Enum.Font.GothamBold
        value.TextSize = 23
        value.Parent = column
        fields[index] = value
        local function update(delta)
            if index == 1 then
                State.selected[index] = math.min(maximum[index], math.max(0, State.selected[index] + delta))
            else
                State.selected[index] = (State.selected[index] + delta + maximum[index] + 1) % (maximum[index] + 1)
            end
            value.Text = index == 1 and tostring(State.selected[index]) or string.format("%02d", State.selected[index])
            updatePreview()
        end
        value.FocusLost:Connect(function()
            local text = tostring(value.Text)
            local parsed = text:match("^%d+$") and #text <= 16 and tonumber(text) or nil
            if parsed and parsed == math.floor(parsed) and parsed >= 0 and parsed <= maximum[index] then
                State.selected[index] = parsed
            else
                toast("Thời gian không hợp lệ: " .. labels[index])
            end
            update(0)
        end)
        local function arrow(text, y, delta)
            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(5, y)
            b.Size = UDim2.fromOffset(76, 24)
            b.Text = text
            b.TextSize = 17
            b.TextColor3 = Color3.fromRGB(153, 192, 255)
            b.BackgroundTransparency = 1
            b.Parent = column
            b.MouseButton1Click:Connect(function() update(delta) end)
        end
        arrow("▲", 25, 1)
        arrow("▼", 109, -1)
        column.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseWheel then update(input.Position.Z > 0 and 1 or -1) end
        end)
        update(0)
    end
    local done = Instance.new("TextButton")
    done.Position = UDim2.fromOffset(20, 251)
    done.Size = UDim2.fromOffset(352, 38)
    done.Text = "XÁC NHẬN THỜI GIAN"
    done.Font = Enum.Font.GothamBold
    done.TextColor3 = Color3.new(1, 1, 1)
    done.BackgroundColor3 = Color3.fromRGB(48, 97, 207)
    done.Parent = panel
    Instance.new("UICorner", done).CornerRadius = UDim.new(0, 9)
    done.MouseButton1Click:Connect(function()
        for index, field in ipairs(fields) do
            local raw = tostring(field.Text)
            local number = raw:match("^%d+$") and #raw <= 16 and tonumber(raw) or nil
            if not number or number ~= math.floor(number) or number < 0 or number > maximum[index] then
                toast("Giá trị không hợp lệ: " .. labels[index])
                return
            end
            State.selected[index] = number
        end
        if chosenSeconds() < 1 or chosenSeconds() > 9007199254740991 then toast("Thời gian không hợp lệ") return end
        gui.Enabled = false
        persistSettings()
        toast("Thời gian đã chọn: " .. formatTime(chosenSeconds()))
    end)
    State.picker = gui
end

local function getServer()
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    local ok, reply = pcall(Request, { Url = url, Method = "GET", Timeout = 10 })
    if not ok or type(reply) ~= "table" or tonumber(reply.StatusCode or reply.Status) ~= 200 then return nil end
    local parsed = nil
    pcall(function() parsed = Http:JSONDecode(reply.Body or "") end)
    if not parsed or type(parsed.data) ~= "table" then return nil end
    local candidates = {}
    for _, item in ipairs(parsed.data) do
        if item.id and item.id ~= game.JobId and (item.playing or 0) < (item.maxPlayers or 0) then
            table.insert(candidates, item.id)
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

hop = function(reason)
    if not State.active or State.stopped or State.teleporting then return false end
    local now = os.clock()
    local fresh = {}
    for _, at in ipairs(State.hops) do if now - at < 600 then table.insert(fresh, at) end end
    State.hops = fresh
    if #fresh >= 5 then toast("Giới hạn 5 lần hop mỗi 10 phút để tránh vòng lặp") return false end
    local server = getServer()
    if not server then toast("Không tìm được server mới") return false end
    table.insert(State.hops, now)
    reportDiscord("heartbeat")
    saveProgress()
    State.teleporting = true
    pcall(function()
        TeleportService:SetTeleportSetting("AnyPremiumOrder", { userId = tostring(User.UserId), runId = State.runId, orderId = State.orderId, name = State.name, duration = State.duration, elapsed = State.elapsed, placeId = State.placeId, sequence = State.sequence })
    end)
    toast("Đã lưu tiến trình; hop không tự chạy lại script")
    local ok, err = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, server, User) end)
    if not ok then State.teleporting = false toast("Teleport thất bại: " .. tostring(err)) return false end
    task.delay(25, function() State.teleporting = false end)
    return true
end

local function closeSetup()
    if not State.window then return true end
    State.closeToken = (State.closeToken or 0) + 1
    local token = State.closeToken
    local success = pcall(function() State.window:Close() end)
    if success then
        task.delay(1.2, function()
            if State.closeToken == token and State.windowOpen and State.window and not State.stopped then
                pcall(function() State.window:Destroy() end)
                State.window = nil
                State.windowOpen = false
            end
        end)
        return true
    end
    local destroyed = pcall(function() State.window:Destroy() end)
    if destroyed then
        State.window = nil
        State.windowOpen = false
        return true
    end
    toast("Không thể đóng cửa sổ thiết lập; vui lòng thu nhỏ thủ công")
    return false
end

local function beginOrder()
    if State.active or State.starting then toast("Đơn đang được xử lý") return end
    if not validWebhook() then showWebhookPrompt() return end
    if type(Request) ~= "function" then toast("Executor không hỗ trợ HTTP POST") return end
    local duration = chosenSeconds()
    if duration < 1 or duration > 9007199254740991 then toast("Thời gian không hợp lệ") return end
    local name = State.name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then toast("Hãy nhập tên đơn hàng") return end
    State.starting = true
    State.active = true
    State.name = name
    State.orderId = "LOCAL-" .. Http:GenerateGUID(false):gsub("%-", ""):sub(1, 12)
    State.runId = Http:GenerateGUID(false)
    State.sequence = 0
    State.duration = duration
    State.remaining = duration
    State.elapsed = 0
    State.placeId = tostring(game.PlaceId)
    State.lastSync = os.clock()
    State.lastHeartbeat = -math.huge
    State.nextHop = os.clock() + State.interval
    State.paused = false
    State.starting = false
    State.hud.gui.Enabled = true
    saveProgress()
    reportDiscord("start")
    closeSetup()
    toast("Đã bắt đầu theo dõi đơn")
end

openSetup = function()
    if State.stopped or State.loading then return end
    if State.window then
        State.closeToken = (State.closeToken or 0) + 1
        local ok = pcall(function() State.window:Open() end)
        if ok then State.windowOpen = true return end
        State.window = nil
    end
    State.loading = true
    toast("Đang tải WindUI để thiết lập")
    local started = os.clock()
    local cachePath = "AnyPremiumManagers/windui.lua"
    local ok, loaded = false, nil
    if type(readfile) == "function" and type(isfile) == "function" then
        ok, loaded = pcall(function()
            if not isfile(cachePath) then return nil end
            local code = readfile(cachePath)
            if type(code) ~= "string" or #code < 30000 or #code > 2500000 then return nil end
            return loadstring(code)()
        end)
    end
    if not ok or type(loaded) ~= "table" then
        local source
        local fetched, text = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/7b1d561/dist/main.lua") end)
        if fetched and type(text) == "string" and #text > 30000 then source = text end
        if source then
            ok, loaded = pcall(function() return loadstring(source)() end)
            if ok and type(loaded) == "table" and type(writefile) == "function" then
                pcall(function()
                    if type(makefolder) == "function" then pcall(makefolder, "AnyPremiumManagers") end
                    writefile(cachePath, source)
                end)
            end
        end
    end
    if not ok or type(loaded) ~= "table" then
        State.loading = false
        toast("WindUI không tải được; hãy kiểm tra mạng hoặc thử lại từ HUD")
        return
    end
    State.wind = loaded
    local built, errorText = pcall(function()
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
        local windowWidth = math.min(540, math.max(310, viewport.X - 24))
        local windowHeight = math.min(405, math.max(270, viewport.Y - 42))
        local Window = loaded:CreateWindow({ Title = "Any - Premium Managers", Author = "by anyne", Folder = "AnyPremiumManagers", Icon = "server", Theme = "Dark", Size = UDim2.fromOffset(windowWidth, windowHeight), MinSize = Vector2.new(310, 260), Resizable = true, HideSearchBar = true, ToggleKey = Enum.KeyCode.RightShift })
        State.window = Window
        pcall(function() Window:OnClose(function() State.windowOpen = false end) end)
        pcall(function() Window:OnOpen(function() State.windowOpen = true end) end)
        pcall(function() Window:OnDestroy(function() State.window = nil State.windowOpen = false end) end)
        local Config = Window:Tab({ Title = "Thiết lập", Icon = "sliders-horizontal" })
        local Options = Window:Tab({ Title = "Tự động", Icon = "refresh-cw" })
        local About = Window:Tab({ Title = "Trạng thái", Icon = "activity" })
        if not State.picker then makePicker() end
        Config:Input({ Title = "Tên đơn hàng", Placeholder = "Nhập tên đơn hàng", Callback = function(value) State.name = tostring(value or "") end })
        Config:Button({ Title = "Chọn thời gian", Desc = "Nhập số ngày tự do, chỉnh giờ · phút · giây", Callback = function() State.picker.Enabled = true end })
        Config:Button({ Title = "Đổi Webhook", Desc = "Đổi URL đã lưu trong workspace", Callback = function() showWebhookPrompt() end })
        Config:Button({ Title = "Bắt Đầu Treo", Icon = "play", Callback = beginOrder })
        About:Paragraph({ Title = "Tài khoản", Desc = "@" .. User.Name .. " · " .. tostring(User.UserId) })
        About:Paragraph({ Title = "Đồng bộ", Desc = "Gửi báo cáo Discord mỗi 30 giây, chỉ tính giờ trong đúng Place." })
        Options:Toggle({ Title = "Hop server định kỳ", Value = State.periodic, Callback = function(v) State.periodic = v persistSettings() end })
        Options:Slider({ Title = "Khoảng cách hop (phút)", Step = 1, Value = { Min = 5, Max = 180, Default = math.floor(State.interval / 60) }, Callback = function(v) State.interval = v * 60 State.nextHop = os.clock() + State.interval persistSettings() end })
        Options:Toggle({ Title = "Hop khi bạn bè tham gia", Value = State.friend, Callback = function(v) State.friend = v persistSettings() end })
        Options:Paragraph({ Title = "Chống ping cao", Desc = "Tự hop nếu ping ≥ 600ms liên tục. Giới hạn 5 lần mỗi 10 phút." })
        State.windowOpen = true
    end)
    State.loading = false
    if not built then toast("Lỗi khởi tạo WindUI: " .. tostring(errorText)) return end
    print("[Any] WindUI ready in " .. string.format("%.2f", os.clock() - started) .. "s")
end

makeHud()
Env.__ANY_OPEN_SETUP = function()
    if validWebhook() then openSetup() else showWebhookPrompt(openSetup) end
end
Env.__ANY_CLEANUP = function()
    State.stopped = true
    if State.hud then pcall(function() State.hud.gui:Destroy() end) end
    if State.webhookPrompt then pcall(function() State.webhookPrompt:Destroy() end) end
    if State.picker then pcall(function() State.picker:Destroy() end) end
    if State.window then pcall(function() State.window:Destroy() end) end
    for _, item in ipairs(State.connections) do pcall(function() item:Disconnect() end) end
    Env.__ANY_RUNNING = nil
    Env.__ANY_JOB_ID = nil
    Env.__ANY_OPEN_SETUP = nil
end
State.hud.gui.Enabled = false
local previous = nil
if type(isfile) == "function" and type(readfile) == "function" then
    pcall(function()
        if isfile(ProgressPath) then previous = Http:JSONDecode(readfile(ProgressPath)) end
    end)
end
if type(previous) ~= "table" then pcall(function() previous = TeleportService:GetTeleportSetting("AnyPremiumOrder") end) end
if type(previous) == "table" and previous.userId == tostring(User.UserId) and type(previous.runId) == "string" and type(previous.duration) == "number" and type(previous.elapsed) == "number" and previous.elapsed < previous.duration and previous.duration >= 1 and previous.duration <= 9007199254740991 then
    State.active = true
    State.name = tostring(previous.name or "Đơn đang treo"):sub(1, 80)
    State.orderId = tostring(previous.orderId or "")
    State.runId = previous.runId
    State.sequence = math.max(0, math.floor(tonumber(previous.sequence) or 0))
    State.placeId = tostring(previous.placeId or game.PlaceId)
    State.remaining = math.max(0, previous.duration - previous.elapsed)
    State.duration = previous.duration
    State.elapsed = previous.elapsed
    State.lastSync = os.clock()
    State.lastHeartbeat = -math.huge
    State.nextHop = os.clock() + State.interval
    State.paused = State.placeId ~= tostring(game.PlaceId)
    State.hud.gui.Enabled = validWebhook()
    if validWebhook() then
        reportDiscord("resume")
        toast(State.paused and "Đơn đang tạm dừng vì sai Place" or "Đã khôi phục đơn đang treo")
    end
else
    if validWebhook() then task.spawn(openSetup) end
end
if not validWebhook() then
    showWebhookPrompt(function()
        if State.active then
            State.hud.gui.Enabled = true
            reportDiscord("resume")
            toast(State.paused and "Đơn đang tạm dừng vì sai Place" or "Đã khôi phục đơn đang treo")
        else
            openSetup()
        end
    end)
end

local function updateHud()
    if not State.active then return end
    local inferred = State.paused and State.remaining or math.max(0, State.remaining - math.max(0, os.clock() - State.lastSync))
    State.hud.name.Text = State.name
    State.hud.time.Text = formatTime(inferred)
    State.hud.fill.Size = UDim2.fromScale(State.duration > 0 and math.clamp(1 - inferred / State.duration, 0, 1) or 0, 1)
    local reportStatus = State.reportError and (" · Webhook " .. tostring(State.lastResponseCode or 0)) or State.lastDeliveryAt and (" · Post " .. tostring(math.floor(os.clock() - State.lastDeliveryAt)) .. "s") or " · Chưa gửi"
    State.hud.status.Text = (State.teleporting and "Đang chuyển server" or State.paused and "Chờ đồng bộ" or "Đang treo") .. " · " .. tostring(State.ping or 0) .. "ms" .. reportStatus
end

table.insert(State.connections, TeleportService.TeleportInitFailed:Connect(function(player, result, message)
    if player == User and State.teleporting then
        State.teleporting = false
        toast("Hop thất bại: " .. tostring(message))
    end
end))

local lastFriends = 0
local lastPing = 0
local friendWarn = false
local function heartbeat()
    if not State.active or State.stopped then return end
    local now = os.clock()
    local elapsed = math.max(0, now - State.lastSync)
    State.lastSync = now
    State.paused = State.placeId ~= tostring(game.PlaceId) or State.teleporting
    State.ping = ping()
    if not State.paused then State.elapsed = math.min(State.duration, State.elapsed + math.min(elapsed, 5)) end
    State.remaining = math.max(0, State.duration - State.elapsed)
    if now - State.lastProgress >= 5 then
        State.lastProgress = now
        saveProgress()
    end
    if State.remaining <= 0 then
        State.paused = false
        State.hud.time.Text = formatTime(0)
        State.hud.fill.Size = UDim2.fromScale(1, 1)
        reportDiscord("done")
        State.active = false
        clearProgress()
        State.stopped = true
        Env.__ANY_RUNNING = nil
        toast("Đơn đã hoàn thành")
        task.spawn(function()
            local limit = os.clock() + 10
            while not State.doneReported and os.clock() < limit do task.wait(0.2) end
            task.wait(3)
            pcall(function() User:Kick("Đơn hàng đã hoàn thành") end)
            pcall(function() game:Shutdown() end)
        end)
        return
    end
    reportDiscord("heartbeat")
end

local connection
connection = game:GetService("RunService").Heartbeat:Connect(function()
    if State.stopped then if connection then connection:Disconnect() end return end
    if os.clock() - (State.lastHudUpdate or 0) < 0.2 then return end
    State.lastHudUpdate = os.clock()
    updateHud()
end)
table.insert(State.connections, connection)
table.insert(State.connections, Players.PlayerAdded:Connect(function(player)
    if State.active and State.friend and player ~= User then
        task.spawn(function()
            local ok, isFriend = pcall(function() return User:IsFriendsWith(player.UserId) end)
            if ok and isFriend and State.active and hop then hop("friend") end
        end)
    end
end))
task.spawn(function()
    while not State.stopped do
        if State.active then
            local now = os.clock()
            if now - State.lastHeartbeat >= 1 then
                State.lastHeartbeat = now
                heartbeat()
            end
            if State.active and not State.paused then
                if State.periodic and now >= State.nextHop then
                    State.nextHop = now + State.interval
                    hop("periodic")
                end
                if now - lastPing >= 15 then
                    lastPing = now
                    State.highPing = ping() >= 600 and State.highPing + 1 or 0
                    if State.highPing >= 2 then State.highPing = 0 hop("ping") end
                end
                if State.friend and now - lastFriends >= 35 then
                    lastFriends = now
                    local ok, friends = pcall(function()
                        if User.GetFriendsOnlineAsync then return User:GetFriendsOnlineAsync(200) end
                        return User:GetFriendsOnline(200)
                    end)
                    if not ok and User.GetFriendsOnline then
                        ok, friends = pcall(function() return User:GetFriendsOnline(200) end)
                    end
                    if ok and type(friends) == "table" then
                        for _, friend in pairs(friends) do
                            if tonumber(friend.PlaceId) == game.PlaceId and tostring(friend.GameId) == tostring(game.JobId) then
                                hop("friend")
                                break
                            end
                        end
                    elseif not friendWarn then
                        friendWarn = true
                        toast("Không đọc được danh sách friend trên executor này")
                    end
                end
            end
        end
        task.wait(1)
    end
end)
