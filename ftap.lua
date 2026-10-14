-- Fling Things and People: Super Throw + Mega Fling + Fly + Anti-Grab
-- Anti-Grab v4: Owner StringValue, no workspace scan, no lag.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInput  = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local Debris     = game:GetService("Debris")
local LP         = Players.LocalPlayer

-- ===================== LOGGER =====================
local Log = {
    lines = {}, maxLines = 800,
    _write = function(self, level, msg)
        local line = string.format("[%s][%s] %s",
            os.date("%H:%M:%S"), level, msg)
        table.insert(self.lines, line)
        if #self.lines > self.maxLines then table.remove(self.lines, 1) end
        print(line)
    end,
}
function Log:info(m)  self:_write("INFO",  m) end
function Log:warn(m)  self:_write("WARN",  m) end
function Log:error(m) self:_write("ERROR", m) end
function Log:dump()   return table.concat(self.lines, "\n") end

Log:info("FTAP Trainer booting")

-- ===================== RAYFIELD =====================
local Rayfield
local ok, err = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok or not Rayfield then
    warn("[FTAP] Rayfield load failed: " .. tostring(err))
    return
end

local Window = Rayfield:CreateWindow({
    Name = "FTAP Trainer",
    LoadingTitle = "FTAP Trainer",
    LoadingSubtitle = "by xemreo",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "FTAP_Trainer",
        FileName = "config",
    },
    KeySystem = false,
})

-- ===================== STATE =====================
local state = {
    superThrow   = false,
    strength     = 245,

    moveSpeed    = false,
    walkSpeed    = 60,

    verticalBoost  = false,
    verticalFactor = 0.5,

    megaFling    = false,
    megaDistance = 100000,

    fly        = false,
    flySpeed   = 60,
    flyKey     = Enum.KeyCode.F,

    antiGrab   = false,
    sniffGrab  = false,
}

-- ===================== HELPERS =====================
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

function findGrabbedPart(model)
    local grabPart = model:FindFirstChild("GrabPart")
    if grabPart then
        local wc = grabPart:FindFirstChild("WeldConstraint")
        if wc and wc:IsA("WeldConstraint") then
            local target = wc.Part1
            if target and not isServicePart(target) then
                return target, "WeldConstraint.Part1"
            end
            local alt = wc.Part0
            if alt and alt ~= grabPart and not isServicePart(alt) then
                return alt, "WeldConstraint.Part0-nonservice"
            end
            Log:warn("grab target rejected: " ..
                tostring(target and target:GetFullName() or "nil"))
            return nil, "rejected"
        end
    end
    for _, c in ipairs(model:GetDescendants()) do
        if c:IsA("BasePart") and not isServicePart(c) then
            return c, "descendant-nonservice"
        end
    end
    return nil, "not-found"
end

local function megaVelocity(distance)
    local g = Workspace.Gravity
    if g <= 0 then g = 196.2 end
    local speed = math.sqrt(distance * g)
    if speed > 1e7 then speed = 1e7 end
    return Workspace.CurrentCamera.CFrame.LookVector * speed, speed
end

function boostPart(part)
    if not part or not part:IsA("BasePart") then
        Log:warn("boostPart: invalid part"); return
    end
    local full = part:GetFullName()
    if full:find("GrabParts") or full:find("GrabPart$")
       or full:find("Workspace%.Map") or full:find("BaseGround")
       or full:find("Grass") or full:find("Floor")
       or full:find("Workspace%.Terrain") then
        Log:warn("boostPart: refusing service/map part " .. full); return
    end
    if part.Anchored then
        Log:warn("boostPart: refusing anchored part " .. full); return
    end

    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local dist = (part.Position - hrp.Position).Magnitude
        if dist < 5 then
            Log:warn(string.format(
                "boostPart: part too close (%.1f studs), skipping", dist))
            return
        end
    end

    local camDir = Workspace.CurrentCamera.CFrame.LookVector
    local target, speed
    if state.megaFling then
        target, speed = megaVelocity(state.megaDistance)
        Log:info(string.format("MEGA velocity %.0f studs/s (target ~%d studs)",
            speed, state.megaDistance))
    else
        target = camDir * state.strength
        speed  = target.Magnitude
        Log:info(string.format("normal velocity %.0f", speed))
    end

    if state.verticalBoost then
        local up = Vector3.new(0, speed * state.verticalFactor, 0)
        target = target + up
        Log:info(string.format("vertical boost +%.0f up (factor %.2f)",
            up.Y, state.verticalFactor))
    end

    for _, c in ipairs(part:GetChildren()) do
        if c:IsA("WeldConstraint") or c:IsA("Weld")
           or c:IsA("AlignPosition") or c:IsA("AlignOrientation")
           or c:IsA("RopeConstraint") then
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
    bv.Parent   = part
    Debris:AddItem(bv, state.megaFling and 15 or 2)
    pcall(function() part:SetNetworkOwner(LP) end)
    Log:info("BodyVelocity attached (" .. (state.megaFling and "15s" or "2s") .. ")")
end

-- ===================== GRAB HOOK =====================
Workspace.ChildAdded:Connect(function(model)
    if not model:IsA("Model") then return end
    if not model.Name:lower():find("grab") then return end

    Log:info("grab model spawned: " .. model.Name)
    local part, how = findGrabbedPart(model)
    if not part then
        Log:warn("no valid grab target inside " .. model.Name)
        for _, c in ipairs(model:GetDescendants()) do
            Log:info("  inside: " .. c.ClassName .. " / " .. c.Name)
        end
        return
    end
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

-- ===================== FLY =====================
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
    flyGyro.P = 1e5
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
        if UserInput:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInput:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInput:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInput:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInput:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UserInput:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
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
    if state.fly then task.wait(1.0); startFly() end
end)

-- ===================== MOVE SPEED =====================
RunService.Heartbeat:Connect(function()
    if not state.moveSpeed then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed ~= state.walkSpeed then
        hum.WalkSpeed = state.walkSpeed
    end
end)

local function setMoveSpeed(enabled)
    state.moveSpeed = enabled
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and not enabled then hum.WalkSpeed = 16 end
    Log:info("moveSpeed = " .. tostring(enabled) ..
        (enabled and (" (" .. state.walkSpeed .. ")") or ""))
end

-- ===================== ANTI-GRAB v4 =====================
local antiGrabConns = {}

local function grabOwnerName(inst)
    local ownerVal = inst:FindFirstChild("Owner")
    if ownerVal and ownerVal:IsA("StringValue") then
        return ownerVal.Value
    end
    return nil
end

local function isMyGrabParts(inst)
    if inst.Name ~= "GrabParts" then return false end
    local owner = grabOwnerName(inst)
    if owner == LP.Name
       or owner == tostring(LP.UserId)
       or owner == LP.DisplayName then
        return true
    end
    return false
end

local function killIfMine(inst)
    if not state.antiGrab then return end
    if not isMyGrabParts(inst) then return end
    local owner = grabOwnerName(inst)
    inst:Destroy()
    Log:info("antiGrab: blocked own GrabParts (owner=" ..
        tostring(owner) .. ")")
end

function enableAntiGrab()
    for _, inst in ipairs(Workspace:GetChildren()) do
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

    Log:info("antiGrab armed (v4, Owner StringValue)")
end

function disableAntiGrab()
    for _, c in ipairs(antiGrabConns) do c:Disconnect() end
    antiGrabConns = {}
    Log:info("antiGrab disarmed")
end

LP.CharacterAdded:Connect(function()
    if state.antiGrab then task.wait(0.5); enableAntiGrab() end
end)

-- ===================== SNIFFER =====================
local sniffConns = {}

local function describe(inst, depth)
    local pad = string.rep("  ", depth or 0)
    Log:info(pad .. inst.ClassName .. " / " .. inst.Name
        .. " | Parent=" .. (inst.Parent and inst.Parent:GetFullName() or "nil"))
    for _, attr in ipairs(inst:GetAttributes()) do
        Log:info(pad .. "  attr: " .. attr .. " = " .. tostring(inst:GetAttribute(attr)))
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
        for _, d in ipairs(child:GetDescendants()) do describe(d, 1) end
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
    for _, c in ipairs(sniffConns) do c:Disconnect() end
    sniffConns = {}
    Log:info("=== sniffer disarmed ===")
end

-- ===================== UI =====================
local MainTab = Window:CreateTab("Main")

MainTab:CreateSection("Throw - Velocity")
MainTab:CreateToggle({
    Name = "Throw Velocity",
    CurrentValue = false, Flag = "SuperThrow",
    Callback = function(v) state.superThrow = v; Log:info("superThrow = " .. tostring(v)) end,
})
MainTab:CreateSlider({
    Name = "Throw Strength",
    Range = {100, 2000}, Increment = 10, Suffix = "studs/s",
    CurrentValue = 245, Flag = "Strength",
    Callback = function(v) state.strength = v; Log:info("strength = " .. v) end,
})
MainTab:CreateToggle({
    Name = "Mega Fling (~100k)",
    CurrentValue = false, Flag = "MegaFling",
    Callback = function(v) state.megaFling = v; Log:info("megaFling = " .. tostring(v)) end,
})
MainTab:CreateSlider({
    Name = "Mega Distance",
    Range = {10000, 500000}, Increment = 5000, Suffix = "studs",
    CurrentValue = 100000, Flag = "MegaDistance",
    Callback = function(v) state.megaDistance = v; Log:info("megaDistance = " .. v) end,
})

MainTab:CreateSection("Vertical Boost")
MainTab:CreateToggle({
    Name = "Vertical Boost",
    CurrentValue = false, Flag = "VerticalBoost",
    Callback = function(v) state.verticalBoost = v; Log:info("verticalBoost = " .. tostring(v)) end,
})
MainTab:CreateSlider({
    Name = "Vertical Factor",
    Range = {10, 200}, Increment = 5, Suffix = "%",
    CurrentValue = 50, Flag = "VerticalFactor",
    Callback = function(v) state.verticalFactor = v / 100; Log:info("verticalFactor = " .. state.verticalFactor) end,
})

MainTab:CreateSection("Move Speed")
MainTab:CreateToggle({
    Name = "Move Speed",
    CurrentValue = false, Flag = "MoveSpeed",
    Callback = function(v) setMoveSpeed(v) end,
})
MainTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200}, Increment = 2, Suffix = "studs/s",
    CurrentValue = 60, Flag = "WalkSpeed",
    Callback = function(v) state.walkSpeed = v; Log:info("walkSpeed = " .. v) end,
})

MainTab:CreateSection("Fly")
MainTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false, Flag = "Fly",
    Callback = function(v)
        state.fly = v; Log:info("fly = " .. tostring(v))
        if not v then stopFly() end
    end,
})
MainTab:CreateSlider({
    Name = "Fly Speed",
    Range = {20, 300}, Increment = 5, Suffix = "studs/s",
    CurrentValue = 60, Flag = "FlySpeed",
    Callback = function(v) state.flySpeed = v; Log:info("flySpeed = " .. v) end,
})
MainTab:CreateKeybind({
    Name = "Fly Toggle Key",
    CurrentKeybind = "F", HoldToInteract = false, Flag = "FlyKey",
    Callback = function(key)
        local ok2, ek = pcall(function() return Enum.KeyCode[key] end)
        if ok2 and ek then state.flyKey = ek; Log:info("flyKey = " .. key) end
    end,
})

MainTab:CreateSection("Anti-Grab (self-lock)")
MainTab:CreateToggle({
    Name = "Anti-Grab",
    CurrentValue = false, Flag = "AntiGrab",
    Callback = function(v)
        state.antiGrab = v; Log:info("antiGrab = " .. tostring(v))
        if v then enableAntiGrab() else disableAntiGrab() end
    end,
})
MainTab:CreateToggle({
    Name = "Sniff grab (debug)",
    CurrentValue = false, Flag = "SniffGrab",
    Callback = function(v)
        state.sniffGrab = v
        Log:info("sniffGrab = " .. tostring(v))
        if v then startSniff() else stopSniff() end
    end,
})

-- LOG TAB
local LogTab = Window:CreateTab("Log")
LogTab:CreateSection("Console")

local logBox = LogTab:CreateParagraph({
    Title = "Last events",
    Content = "log will appear here",
})

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
        elseif writefile then writefile("ftap_log.txt", text); how = "ftap_log.txt"
        end
        if how then Log:info("log copied via " .. how)
        else Log:warn("clipboard unavailable") end
    end,
})
LogTab:CreateButton({
    Name = "Clear log",
    Callback = function()
        Log.lines = {}
        refreshLogParagraph()
        print("[FTAP] log cleared")
    end,
})

-- CONFIG TAB
local ConfigTab = Window:CreateTab("Config")
ConfigTab:CreateSection("Settings")
ConfigTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Rayfield:Destroy() end,
})

Log:info("FTAP Trainer ready")