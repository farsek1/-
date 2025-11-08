-- Полный фикс: FARM GOLD + Delete Old Boards + AutoWalk (Tween) + AutoStop + Auto-restart
-- Заменяет/дополняет оригинал, безопасные проверки, резервный UI

local url = "https://raw.githubusercontent.com/makarloxezz-cpu/goldffram/main/main.lua" -- исправлено

local orig = ""
pcall(function()
    orig = game:HttpGet(url)
end)

if not orig or orig == "" or (type(orig)=="string" and orig:find("<!DOCTYPE html>")) then
    warn("❌ Не удалось загрузить оригинальный скрипт с GitHub — используется локальный код.")
    orig = ""
end

-- "Глобализация" переменных из оригинального скрипта для фикса
orig = orig:gsub("local%s+Library%s*=", "Library =")
orig = orig:gsub("local%s+Window%s*=", "Window =")
orig = orig:gsub("local%s+Tabs%s*=", "Tabs =")
orig = orig:gsub("local%s+swingtool_local%s*=", "swingtool_local =")

local appended = [[
-- =======================
-- Добавленный фикс-код
-- =======================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local plr = Players.LocalPlayer
local char = plr and (plr.Character or plr.CharacterAdded:Wait())
local root = char and char:WaitForChild("HumanoidRootPart")
local hum = char and char:WaitForChild("Humanoid")

-- Пакеты (если есть)
local packets
pcall(function()
    local rs = game:GetService("ReplicatedStorage")
    if rs and rs:FindFirstChild("Modules") then
        local mod = rs.Modules:FindFirstChild("Packets")
        if mod then
            packets = require(mod)
        end
    end
end)

-- ====== Утилиты очистки (Delete Old Boards) ======
local function DeleteOldBoardsDeep()
    pcall(function()
        -- удаляем по именам и по вхождению в имя
        for _, name in ipairs({"Old Boards", "Board", "WalkerSpheres", "RedSticks", "SigmaPart", "SigmaPart2", "SigmaPart3", "SigmaPart4", "SigmaPart5"}) do
            -- попытка в workspace и workspace.Resources
            local candidate = workspace:FindFirstChild(name)
            if candidate then
                candidate:Destroy()
            end
            if workspace:FindFirstChild("Resources") then
                local c2 = workspace.Resources:FindFirstChild(name)
                if c2 then c2:Destroy() end
            end
        end

        -- удаляем все объекты, содержащие "Board" в имени (с учётом разных регистров)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj and obj.Name and tostring(obj.Name):lower():find("board") then
                if obj and obj.Parent then
                    pcall(function() obj:Destroy() end)
                end
            end
        end

        -- удаляем объекты по MeshId (как раньше)
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("MeshPart") and obj.MeshId and tostring(obj.MeshId):find("4823036") then
                    obj:Destroy()
                elseif obj:IsA("Part") then
                    for _, m in ipairs(obj:GetChildren()) do
                        if m and m:IsA("SpecialMesh") and m.MeshId and tostring(m.MeshId):find("4823036") then
                            obj:Destroy()
                            break
                        end
                    end
                end
            end)
        end
    end)
end

-- Запускаем периодическую очистку Old Boards (безопасно)
local OldBoardsCleaner = nil
OldBoardsCleaner = task.spawn(function()
    while task.wait(2) do
        pcall(DeleteOldBoardsDeep)
    end
end)

-- ====== Визуальные части (SigmaParts) ======
local function CreateSigmaParts(parent)
    local partsData = {
        {name="SigmaPart", shape="Wedge", pos=Vector3.new(-122,-28,-193), size=Vector3.new(4,30,25), ori=Vector3.new(0,180,0)},
        {name="SigmaPart2", shape="Wedge", pos=Vector3.new(-202,5,-616), size=Vector3.new(4,30,25), ori=Vector3.new(0,200,0)},
        {name="SigmaPart3", pos=Vector3.new(-214,18,-627), size=Vector3.new(12,1,12)},
        {name="SigmaPart4", shape="Wedge", pos=Vector3.new(-44,-104,-392), size=Vector3.new(6,20,17)},
        {name="SigmaPart5", pos=Vector3.new(-45,-94,-374), size=Vector3.new(13,1,13)},
    }
    pcall(function()
        for _, info in ipairs(partsData) do
            local part = (info.shape == "Wedge") and Instance.new("WedgePart") or Instance.new("Part")
            part.Name = info.name
            part.Size = info.size
            part.Position = info.pos
            part.Anchored = true
            part.CanCollide = true
            part.Material = Enum.Material.Neon
            part.Color = Color3.new(1, 0, 0)
            part.Transparency = 0.3
            part.Reflectance = 0.05
            if info.ori then pcall(function() part.Orientation = info.ori end) end
            part.Parent = parent
        end
    end)
end

-- ====== Загрузка TweensCFG1.json и визуализация точек ======
local function LoadTweensConfig()
    local raw = nil
    local success, result = pcall(function()
        if readfile then
            return readfile("TweensCFG1.json")
        end
    end)
    if not success or not result then
        return nil, "no file"
    end
    raw = result
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or not data or not data.position then
        return nil, "bad json"
    end
    -- создаём папку с точками
    local folder = workspace:FindFirstChild("WalkerSpheres")
    if folder then folder:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "WalkerSpheres"
    folder.Parent = workspace
    local out = {}
    for i, p in ipairs(data.position) do
        local vec = Vector3.new(p.X or p.x or 0, p.Y or p.y or 0, p.Z or p.z or 0)
        table.insert(out, vec)
        local dot = Instance.new("Part")
        dot.Size = Vector3.new(1.5,1.5,1.5)
        dot.Position = vec
        dot.Shape = Enum.PartType.Ball
        dot.Anchored = true
        dot.CanCollide = false
        dot.Material = Enum.Material.Neon
        dot.Color = Color3.fromRGB(0,255,0)
        dot.Transparency = 0.25
        dot.Name = "WalkerDot_"..i
        dot.Parent = folder
    end
    return out, nil
end

-- ====== AutoWalk (Tween-based) ======
local AutoWalk = {
    enabled = false,
    walking = false,
    waypoints = {},
    currentIndex = 1,
    tweenConnection = nil,
    positionCheckConnection = nil,
    lastRootPosition = nil,
    deviationThreshold = 6, -- если отклонение > 6 studs — перезапуск к ближайшей точке
    tweenInfo = TweenInfo.new(1.0, Enum.EasingStyle.Linear), -- базовое info (время поменяется динамически в зависимости от distance)
}

local function findClosestWaypointIndex(pos, points)
    if not pos or not points or #points == 0 then return 1 end
    local bestI, bestD = 1, math.huge
    for i, v in ipairs(points) do
        local d = (v - pos).Magnitude
        if d < bestD then
            bestD, bestI = d, i
        end
    end
    return bestI
end

local function stopCurrentTween()
    if AutoWalk.tweenConnection then
        pcall(function()
            AutoWalk.tweenConnection:Disconnect()
        end)
        AutoWalk.tweenConnection = nil
    end
    if AutoWalk.positionCheckConnection then
        pcall(function()
            AutoWalk.positionCheckConnection:Disconnect()
        end)
        AutoWalk.positionCheckConnection = nil
    end
end

local function performTweenTo(point, onComplete)
    if not root or not point then
        if onComplete then pcall(onComplete) end
        return
    end
    -- рассчитываем время по расстоянию и скорости (пример: 16 studs/s базовая)
    local dist = (root.Position - point).Magnitude
    local speed = 30 -- бажаемая скорость (можно менять)
    local ttime = math.clamp(dist / speed, 0.15, 5)
    local info = TweenInfo.new(ttime, Enum.EasingStyle.Linear)
    local goal = {}
    goal.CFrame = CFrame.new(point.X, point.Y + 2, point.Z) * CFrame.Angles(0, 0, 0) -- чуть выше, чтобы не застревать
    local tween = TweenService:Create(root, info, goal)
    local finished = false
    tween:Play()
    -- Отслеживание завершения
    local con
    con = tween.Completed:Connect(function(status)
        finished = true
        pcall(function() con:Disconnect() end)
        if onComplete then pcall(onComplete) end
    end)
    -- позиционная проверка (каждые 0.25s) — проверяем отклонение или если root умирает
    AutoWalk.positionCheckConnection = RunService.Heartbeat:Connect(function(dt)
        if not root or not root.Parent then
            if not finished then
                pcall(function() tween:Cancel() end)
                pcall(function() con:Disconnect() end)
                if onComplete then pcall(onComplete) end
            end
            return
        end
        local curPos = root.Position
        local distToTarget = (curPos - point).Magnitude
        -- если ушли далеко от траектории (например подбросило, телепорт и т.д.)
        if distToTarget > AutoWalk.deviationThreshold then
            pcall(function() tween:Cancel() end)
            pcall(function() con:Disconnect() end)
            if onComplete then pcall(onComplete) end
            return
        end
    end)
    AutoWalk.tweenConnection = con
end

local function AutoWalk_Next()
    if not AutoWalk.enabled then return end
    if #AutoWalk.waypoints == 0 then
        AutoWalk.walking = false
        return
    end

    AutoWalk.walking = true
    -- защита от выхода за диапазон
    if AutoWalk.currentIndex < 1 then AutoWalk.currentIndex = 1 end
    if AutoWalk.currentIndex > #AutoWalk.waypoints then
        -- достигли конца — автостоп или можно зациклить; сейчас автостоп
        AutoWalk.walking = false
        AutoWalk.enabled = false
        return
    end

    local target = AutoWalk.waypoints[AutoWalk.currentIndex]
    performTweenTo(target, function()
        -- по завершении: увеличиваем индекс и идём следующую
        if AutoWalk.enabled then
            AutoWalk.currentIndex = AutoWalk.currentIndex + 1
            -- если ещё есть — следующая
            if AutoWalk.currentIndex <= #AutoWalk.waypoints then
                -- небольшая задержка
                task.wait(0.08)
                AutoWalk_Next()
            else
                -- завершение трассы
                AutoWalk.walking = false
                AutoWalk.enabled = false
            end
        else
            AutoWalk.walking = false
        end
    end)
end

local function StartAutoWalk()
    if AutoWalk.enabled then return end
    -- загрузить waypoints если пустые
    if not AutoWalk.waypoints or #AutoWalk.waypoints == 0 then
        local pts, err = LoadTweensConfig()
        if not pts then
            warn("AutoWalk: failed to load waypoints: "..tostring(err))
            return
        end
        AutoWalk.waypoints = pts
    end
    -- если мы далеко от первой точки — найти ближайшую
    AutoWalk.enabled = true
    AutoWalk.currentIndex = findClosestWaypointIndex(root and root.Position or Vector3.new(0,0,0), AutoWalk.waypoints)
    AutoWalk_Next()
end

local function StopAutoWalk()
    AutoWalk.enabled = false
    AutoWalk.walking = false
    stopCurrentTween()
end

-- Автоматическое восстановление: если root далеко от текущ точки и автоход включен — пересчитать ближайшую и продолжить
local AutoWalkRecoveryConn = nil
AutoWalkRecoveryConn = RunService.Heartbeat:Connect(function()
    if AutoWalk.enabled and AutoWalk.walking and root and AutoWalk.waypoints and #AutoWalk.waypoints>0 then
        local curTarget = AutoWalk.waypoints[AutoWalk.currentIndex]
        if curTarget then
            local d = (root.Position - curTarget).Magnitude
            if d > (AutoWalk.deviationThreshold * 2) then -- сильно отклонились
                -- остановить текущий tween и пересчитать ближайшую точку
                stopCurrentTween()
                AutoWalk.currentIndex = findClosestWaypointIndex(root.Position, AutoWalk.waypoints)
                task.defer(AutoWalk_Next)
            end
        end
    end
end)

-- ====== AutoFarm Gold (упрощённо, использует существующую логику) ======
local AutoFarm = {
    enabled = false,
    running = false,
    loopTask = nil,
}

local function SafeSwing(eids)
    -- swingtool_local должна быть доступна (глобально) из 'orig' скрипта
    if type(swingtool_local) == "function" then
        pcall(swingtool_local, eids)
    end
end

local function StartAutoFarm()
    if AutoFarm.enabled then return end
    AutoFarm.enabled = true
    AutoFarm.running = true
    AutoFarm.loopTask = task.spawn(function()
        while AutoFarm.enabled do
            -- базовая логика - ищем ближайшие Gold Node модели и бьем
            local range = (autofarmgoldrange and autofarmgoldrange.Value) or 30
            local cooldown = (autofarmgoldcooldown and autofarmgoldcooldown.Value) or 0.12
            local targets = {}
            for _, obj in ipairs(workspace:GetChildren()) do
                pcall(function()
                    if obj:IsA("Model") then
                        local name = obj.Name or ""
                        local eid = obj:GetAttribute and obj:GetAttribute("EntityID") or nil
                        if (name == "Gold Node" or tostring(name):lower():find("gold")) and eid then
                            local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                            if primaryPart and root then
                                local dist = (primaryPart.Position - root.Position).Magnitude
                                if dist <= range then
                                    table.insert(targets, {eid = eid, dist = dist})
                                end
                            end
                        end
                    end
                end)
            end
            if #targets > 0 then
                table.sort(targets, function(a,b) return a.dist < b.dist end)
                local eidsToSwing = {}
                for i = 1, math.min(6, #targets) do table.insert(eidsToSwing, targets[i].eid) end
                pcall(SafeSwing, eidsToSwing)
            end

            -- попытки поднять предметы (packets)
            if packets and packets.Pickup and packets.Pickup.send then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    pcall(function()
                        if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                            local name = obj.Name or ""
                            local eid = obj:GetAttribute and obj:GetAttribute("EntityID")
                            if eid and (tostring(name):lower():find("gold") or tostring(name):lower():find("coin")) and root then
                                local dist = (obj.Position - root.Position).Magnitude
                                if dist <= ((autofarmgoldrange and autofarmgoldrange.Value) or 30) then
                                    pcall(packets.Pickup.send, eid)
                                end
                            end
                        end
                    end)
                end
            end

            task.wait(cooldown)
        end
        AutoFarm.running = false
    end)
end

local function StopAutoFarm()
    AutoFarm.enabled = false
    -- loopTask завершится сам, т.к. AutoFarm.enabled станет false
end

-- ====== UI: резервный Window/Tabs + вкладка FARM GOLD с большим заголовком ======
if not Window then
    warn("⚠️ Window не найден — создаём временное окно.")
    Window = {
        AddTab = function(self, data)
            -- возвращаем таблицу с нужными методами
            local t = {}
            function t:CreateButton(opts) return (function() end) end
            function t:CreateToggle(name, opts)
                local s = { Value = opts and opts.Default or false }
                return s
            end
            function t:CreateSlider(name, opts)
                local s = { Value = opts and opts.Default or 0 }
                return s
            end
            function t:CreateLabel(text) return nil end
            return t
        end
    }
end

if not Tabs then Tabs = {} end
if not Tabs.Farming then
    Tabs.Farming = Window:AddTab({ Title = "FARM GOLD", Icon = "sprout" })
end

local farmingTab = Tabs.Farming

-- Большой заголовок: создадим заметную кнопку/лейбл
-- (тут мы используем обычные пробелы, а не ' ' из оригинала, во избежание ошибок)
if farmingTab.CreateLabel then
    pcall(function() farmingTab:CreateLabel("===  ★  FARM GOLD  ★  ===") end)
else
    pcall(function() farmingTab:CreateButton({ Title = "===  ★  FARM GOLD  ★  ===", Callback = function() end }) end)
end

-- Кнопки управления
farmingTab:CreateButton({
    Title = "Delete Old Boards (Deep)",
    Callback = function()
        pcall(DeleteOldBoardsDeep)
    end
})

farmingTab:CreateButton({
    Title = "Load Tween Config (TweensCFG1.json)",
    Callback = function()
        local pts, err = LoadTweensConfig()
        if pts then
            AutoWalk.waypoints = pts
            -- создаём визуалки (если нужно)
            local redsticks = workspace:FindFirstChild("RedSticks")
            if redsticks then redsticks:Destroy() end
            local folder = Instance.new("Folder")
            folder.Name = "RedSticks"
            folder.Parent = workspace
            CreateSigmaParts(folder)
            -- нотификейшн если есть StarterGui
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "FARM GOLD",
                    Text = "Tweens config loaded: "..tostring(#pts).." points",
                    Duration = 3
                })
            end)
        else
            warn("LoadTweensConfig failed: "..tostring(err))
        end
    end
})

farmingTab:CreateButton({
    Title = "Start Auto Walk",
    Callback = function() StartAutoWalk() end
})

farmingTab:CreateButton({
    Title = "Stop Auto Walk",
    Callback = "function() StopAutoWalk() end"
})

farmingTab:CreateButton({
    Title = "Start Auto Farm",
    Callback = function() StartAutoFarm() end
})

farmingTab:CreateButton({
    Title = "Stop Auto Farm",
    Callback = function() StopAutoFarm() end
})

-- Toggles and sliders (store references globally so AutoFarm can use)
autofarmgoldtoggle = farmingTab:CreateToggle("autofarmgoldtoggle", { Title = "Enable Auto Farm Gold", Default = false })
autofarmgoldrange = farmingTab:CreateSlider("autofarmgoldrange", { Title = "Range", Min = 5, Max = 200, Rounding = 1, Default = 30 })
autofarmgoldcooldown = farmingTab:CreateSlider("autofarmgoldcooldown", { Title = "Swing Delay (s)", Min = 0.01, Max = 1.5, Rounding = 2, Default = 0.12 })

-- Автоматическая реакция на переключение autofarmgoldtoggle (если библиотека поддерживает callback на toggle)
-- Если toggle — это таблица с Value, мы можем следить за ней через цикл (легковесно)
task.spawn(function()
    while task.wait(0.5) do
        if autofarmgoldtoggle and autofarmgoldtoggle.Value ~= nil then
            if autofarmgoldtoggle.Value and not AutoFarm.enabled then
                StartAutoFarm()
            elseif (not autofarmgoldtoggle.Value) and AutoFarm.enabled then
                StopAutoFarm()
            end
        end
    end
end)

-- ====== Cleanup on unload (опционально) ======
local function CleanupAll()
    StopAutoWalk()
    StopAutoFarm()
    
    -- Правильная остановка фонового потока
    if OldBoardsCleaner then
        pcall(task.cancel, OldBoardsCleaner)
        OldBoardsCleaner = nil
    end
    
    if AutoWalkRecoveryConn then
        pcall(function() AutoWalkRecoveryConn:Disconnect() end)
        AutoWalkRecoveryConn = nil
    end
end

-- Если скрипт выгружается, запускаем Cleanup (самопроверка)
game:BindToClose(function()
    pcall(CleanupAll)
end)

print("✅ FARM GOLD fix loaded: AutoWalk (Tween), AutoStop, DeleteOldBoards, UI ready.")
]]

local merged = (orig or "") .. appended
local fn, err = loadstring(merged)
if not fn then
    warn("⚠️ Ошибка компиляции объединённого скрипта: " .. tostring(err))
else
    pcall(fn)
end
