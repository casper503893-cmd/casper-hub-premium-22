--[[
  CASPER HUB PREMIUM — v8.5 (REFILL PULIDO + ACTOR HOOK + WAVE FIX)
  PC (Xeno/Synapse/Delta/Wave) y Móvil. Fallback automático.
]]

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local GuiService          = game:GetService("GuiService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile  = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================================
-- SISTEMA DE KEYS LOCAL
-- ============================================================
local ValidKeys = {
    ["CASPER-1234"] = true,
    ["VIP-0000"] = true,
    ["PREMIUM-2024"] = true,
}

local saveFile = "CasperHub_Key.txt"
local isKeyVerified = false

local function CheckSavedKey()
    if isfile(saveFile) then
        local savedKey = readfile(saveFile)
        if ValidKeys[savedKey] then isKeyVerified = true end
    end
end
CheckSavedKey()

-- ============================================================
-- CONFIGURACIÓN
-- ============================================================
local Config = {
    AutoFarm = false, FlySpeed = 600, FlyHeight = 230,
    AutoSkill = false,
    AutoEscape = false, EscapeCooldown = 0.15, EscapeMinSize = 20, DebugEscape = false,
    AutoRefillBlade = false, AutoRefillThunder = false,
    AutoRefillWave = false,
    RefillCooldown = 5,
    RefillSpeed = 800, WaveSpeed = 1000,
    DamageMult = 10,
    HitCount   = 5,
    AutoRetry = false,
    MassiveAttack = false,
    AutoCreateWave = false,
    AutoStartWave = false,
    AutoReady = false,
    AutoVoteSkip = false,
    AutoPlay = false,
    WaveMap = "Trost",
    WaveLevel = "Easy",
}

local isRefilling = false

local THEME = {
    bg = Color3.fromRGB(8, 8, 12),
    panel = Color3.fromRGB(16, 16, 24),
    item = Color3.fromRGB(24, 24, 36),
    text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(130, 140, 170),
    accent = Color3.fromRGB(130, 50, 255)
}

-- ============================================================
-- HELPERS GLOBALES
-- ============================================================
local function new(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, child in ipairs(children or {}) do child.Parent = obj end
    return obj
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end
local function tween(obj, time, props) TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end
local function getRoot() local c = player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function Alive() return player and player.Parent ~= nil end

local IN_MENU = (game.PlaceId == 13379208636)
local LOBBY_PLACE_ID = 14916516914
local function CanUseHere() return not IN_MENU and game.PlaceId ~= LOBBY_PLACE_ID end

-- ============================================================
-- GUI DE LA KEY
-- ============================================================
if not isKeyVerified then
    local keyGui = new("ScreenGui", { Name = "KeySystem", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, Parent = playerGui })
    local keyFrame = new("Frame", {
        Size = UDim2.fromOffset(300, 220),
        Position = UDim2.new(0.5, -150, 0.5, -110),
        BackgroundColor3 = THEME.bg,
        BorderSizePixel = 0,
        Parent = keyGui
    }, { corner(14), new("UIStroke", { Color = THEME.accent, Thickness = 2 }) })

    new("TextLabel", { Text = "CASPER HUB PREMIUM", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = THEME.text, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 30), Parent = keyFrame })
    new("TextLabel", { Text = "Ingresa tu Key para continuar", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.subtext, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(1, 0, 0, 20), Parent = keyFrame })

    local textBox = new("TextBox", {
        Text = "", PlaceholderText = "CASPER-XXXX",
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.text,
        BackgroundColor3 = THEME.item, BorderSizePixel = 0,
        Position = UDim2.fromOffset(30, 90), Size = UDim2.new(1, -60, 0, 40),
        Parent = keyFrame
    }, { corner(8) })

    local statusLabel = new("TextLabel", { Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(255, 80, 80), BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 135), Size = UDim2.new(1, -60, 0, 20), Parent = keyFrame })

    local loginBtn = new("TextButton", {
        Text = "Verificar Key", Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = THEME.accent, BorderSizePixel = 0,
        Position = UDim2.fromOffset(30, 165), Size = UDim2.new(1, -60, 0, 40),
        Parent = keyFrame
    }, { corner(8) })

    loginBtn.MouseButton1Click:Connect(function()
        local inputKey = textBox.Text
        if inputKey == "" then statusLabel.Text = "Por favor, ingresa una key." return end
        if ValidKeys[inputKey] then
            if typeof(writefile) == "function" then pcall(function() writefile(saveFile, inputKey) end) end
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            statusLabel.Text = "¡Key activada con éxito!"
            task.wait(1)
            keyGui:Destroy()
            isKeyVerified = true
            if _G.CasperMainScript then _G.CasperMainScript() end
        else
            statusLabel.Text = "Key inválida o incorrecta."
        end
    end)
end

-- ============================================================
-- LÓGICA PRINCIPAL
-- ============================================================
local function loadMainScript()
    local ACCENTS = {
        Purpura = Color3.fromRGB(130, 50, 255),
        Cian = Color3.fromRGB(0, 240, 255),
        Verde = Color3.fromRGB(0, 255, 100),
        Rojo = Color3.fromRGB(255, 30, 60),
        Naranja = Color3.fromRGB(255, 140, 0),
        Rosa = Color3.fromRGB(255, 0, 150)
    }

    local accentObjects = {}
    local function bindAccent(inst, prop) table.insert(accentObjects, { inst, prop }); inst[prop] = THEME.accent end
    local function setAccent(color)
        THEME.accent = color
        for _, pair in ipairs(accentObjects) do
            if pair[1] and pair[1].Parent then
                pair[1][pair[2]] = color
                TweenService:Create(pair[1], TweenInfo.new(0.3), { [pair[2]] = color }):Play()
            end
        end
    end

    local gui = new("ScreenGui", { Name = "CasperPremium", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 999, Parent = playerGui })

    local MiniFrame = new("Frame", { Name = "MiniFrame", Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, -30, 0.5, -30), BackgroundColor3 = THEME.panel, BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 10, Parent = gui }, { corner(30), new("UIStroke", { Thickness = 3 }) })
    local miniStroke = MiniFrame:FindFirstChildOfClass("UIStroke"); bindAccent(miniStroke, "Color")
    new("ImageLabel", { Name = "MiniAvatar", Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150", ZIndex = 11, Parent = MiniFrame }, { corner(30) })

    local window = new("Frame", {
        Name = "Window",
        Size = UDim2.fromOffset(620, 420),
        Position = UDim2.new(0.5, -310, 0.5, -210),
        BackgroundColor3 = THEME.bg,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = gui
    }, { corner(14), new("UIStroke", { Color = Color3.fromRGB(40, 40, 60), Thickness = 1.5 }) })

    local IMAGE_IDS = { "rbxassetid://127316675255106", "rbxassetid://14025915547", "rbxassetid://1316045217", "rbxassetid://9302127707" }
    local currentImageIndex = 1
    local bgImage = nil
    local function LoadBackground()
        if bgImage then bgImage:Destroy() end
        if currentImageIndex > #IMAGE_IDS then return end
        bgImage = new("ImageLabel", { Name = "BackgroundImage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = IMAGE_IDS[currentImageIndex], ImageTransparency = 0, ScaleType = Enum.ScaleType.Stretch, ZIndex = 1, Parent = window }, { corner(14) })
        task.delay(1.5, function()
            if bgImage and not bgImage.IsLoaded then
                currentImageIndex = currentImageIndex + 1
                LoadBackground()
            end
        end)
    end
    LoadBackground()

    new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 5, 10), BackgroundTransparency = 0.75, ZIndex = 2, Parent = window }, { corner(14) })

    local topbar = new("Frame", { Size = UDim2.new(1, 0, 0, 55), BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 3, Parent = window }, { corner(14) })
    new("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 2, Parent = topbar })

    local dot = new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(20, 22), BorderSizePixel = 0, ZIndex = 4, Parent = topbar }, { corner(5) }); bindAccent(dot, "BackgroundColor3")
    new("TextLabel", { Text = "CASPER HUB PREMIUM", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = THEME.text, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -280, 1, 0), ZIndex = 4, Parent = topbar })

    local profileHolder = new("Frame", { Size = UDim2.fromOffset(180, 34), Position = UDim2.new(1, -270, 0.5, -17), BackgroundTransparency = 1, ZIndex = 3, Parent = topbar })
    local avatarFrame = new("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(0, 2), BackgroundColor3 = THEME.item, BorderSizePixel = 0, ZIndex = 4, Parent = profileHolder }, { corner(15) })
    local avatarStroke = new("UIStroke", { Thickness = 2, Parent = avatarFrame }); bindAccent(avatarStroke, "Color")
    new("ImageLabel", { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150", ZIndex = 5, Parent = avatarFrame }, { corner(15) })
    new("TextLabel", { Text = player.DisplayName or player.Name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -40, 0, 15), ZIndex = 4, Parent = profileHolder })
    new("TextLabel", { Text = "@" .. player.Name, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = THEME.subtext, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 15), Size = UDim2.new(1, -40, 0, 13), ZIndex = 4, Parent = profileHolder })

    local function topButton(text, xOffset, color)
        return new("TextButton", { Text = text, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1,1,1), BackgroundColor3 = color, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, xOffset, 0.5, -15), AutoButtonColor = false, ZIndex = 5, Parent = topbar }, { corner(8) })
    end
    local minimizeBtn = topButton("–", -80, THEME.item)
    local closeBtn    = topButton("X", -42, Color3.fromRGB(220, 30, 60))

    do
        local dragging, dragStart, startPos
        topbar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = window.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    do
        local dragging, moved = false, false
        local dragStart, startPos
        MiniFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; moved = false; dragStart = input.Position; startPos = MiniFrame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then moved = true end
                MiniFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    if not moved then
                        task.defer(function() local pos = MiniFrame.Position; MiniFrame.Visible = false; window.Visible = true; window.Position = pos end)
                    end
                end
            end
        end)
    end

    local sidebar = new("Frame", { Size = UDim2.new(0, 160, 1, -67), Position = UDim2.fromOffset(10, 65), BackgroundTransparency = 1, ZIndex = 2, Parent = window }, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), new("UIPadding", { PaddingTop = UDim.new(0, 4) }) })
    local content = new("Frame", { Size = UDim2.new(1, -186, 1, -67), Position = UDim2.fromOffset(176, 65), BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 2, Parent = window }, { corner(12), new("UIStroke", { Color = Color3.fromRGB(35, 35, 55), Transparency = 0.5 }), new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }) })

    local notifyHolder = new("Frame", { Size = UDim2.new(0, 260, 1, -20), Position = UDim2.new(1, -270, 0, 10), BackgroundTransparency = 1, ZIndex = 50, Parent = gui }, { new("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }) })
    local function notify(title, message, duration)
        local card = new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 51, Parent = notifyHolder }, { corner(10), new("UIStroke", { Color = Color3.fromRGB(35, 35, 55), Transparency = 0.5 }) })
        local bar = new("Frame", { Size = UDim2.new(0, 5, 1, -12), Position = UDim2.fromOffset(6, 6), BorderSizePixel = 0, ZIndex = 52, Parent = card }, { corner(3) }); bindAccent(bar, "BackgroundColor3")
        new("TextLabel", { Text = title, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = THEME.text, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 6), Size = UDim2.new(1, -24, 0, 20), ZIndex = 52, Parent = card })
        new("TextLabel", { Text = message, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.subtext, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 28), Size = UDim2.new(1, -24, 0, 26), ZIndex = 52, Parent = card })
        tween(card, 0.3, { BackgroundTransparency = 0.4 })
        task.delay(duration or 3, function() tween(card, 0.3, { BackgroundTransparency = 1 }); task.wait(0.3); card:Destroy() end)
    end

    local tabs = {}; local activeTab
    local function selectTab(tab)
        if activeTab then
            activeTab.page.Visible = false
            tween(activeTab.button, 0.2, { BackgroundColor3 = THEME.bg, BackgroundTransparency = 0.6, TextColor3 = THEME.subtext })
            tween(activeTab.indicator, 0.2, { Size = UDim2.fromOffset(0, 18) })
        end
        activeTab = tab
        tab.page.Visible = true
        tween(tab.button, 0.2, { BackgroundColor3 = THEME.item, BackgroundTransparency = 0.4, TextColor3 = THEME.text })
        tween(tab.indicator, 0.2, { Size = UDim2.fromOffset(4, 18) })
        if not tab.loaded then tab.loaded = true; tab.buildFunc(tab.api) end
    end

    local function addTab(name, icon, buildFunc)
        local button = new("TextButton", { Text = "", Font = Enum.Font.GothamMedium, BackgroundColor3 = THEME.bg, BackgroundTransparency = 0.6, Size = UDim2.new(1, 0, 0, 38), AutoButtonColor = false, LayoutOrder = #tabs + 1, ZIndex = 3, Parent = sidebar }, { corner(8) })
        local btnLabel = new("TextLabel", { Text = (icon or "") .. "  " .. name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.subtext, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -10, 1, 0), ZIndex = 4, Parent = button })
        local indicator = new("Frame", { Size = UDim2.fromOffset(0, 18), Position = UDim2.new(0, 0, 0.5, -9), BackgroundColor3 = THEME.accent, BorderSizePixel = 0, ZIndex = 4, Parent = button }, { corner(2) })
        bindAccent(indicator, "BackgroundColor3")

        local page = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.item, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false, ZIndex = 3, Parent = content }, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
        local tab = { button = button, btnLabel = btnLabel, indicator = indicator, page = page, order = 0, loaded = false, buildFunc = buildFunc }

        local api = {}
        local function row(height) tab.order += 1; return new("Frame", { Size = UDim2.new(1, 0, 0, height or 38), BackgroundColor3 = THEME.item, BackgroundTransparency = 0.4, BorderSizePixel = 0, LayoutOrder = tab.order, ZIndex = 3, Parent = page }, { corner(8) }) end
        local function label(parent, text, size) return new("TextLabel", { Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.text, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = size or UDim2.new(1, -80, 0, 38), ZIndex = 4, Parent = parent }) end

        function api.Section(text) tab.order += 1; new("TextLabel", { Text = string.upper(text), Font = Enum.Font.GothamBlack, TextSize = 10, TextColor3 = THEME.subtext, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = tab.order, ZIndex = 4, Parent = page }) end
        function api.Toggle(text, default, callback)
            local f = row(38); label(f, text)
            local state = default and true or false
            local track = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BackgroundColor3 = Color3.fromRGB(45, 45, 60), ZIndex = 4, Parent = f }, { corner(10) })
            local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1,1,1), ZIndex = 5, Parent = track }, { corner(8) })
            local function render() tween(track, 0.15, { BackgroundColor3 = state and THEME.accent or Color3.fromRGB(45, 45, 60) }); tween(knob, 0.15, { Position = state and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) }) end
            render()
            track.MouseButton1Click:Connect(function() state = not state; render(); task.spawn(callback, state) end)
        end
        function api.Slider(text, min, max, default, callback)
            local f = row(55); label(f, text, UDim2.new(1, -80, 0, 28))
            local valueLabel = new("TextLabel", { Text = tostring(default), Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = THEME.accent, TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1, Position = UDim2.new(1, -60, 0, 0), Size = UDim2.new(0, 50, 0, 28), ZIndex = 4, Parent = f })
            local track = new("Frame", { Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 14, 0, 38), BackgroundColor3 = Color3.fromRGB(45, 45, 60), BorderSizePixel = 0, ZIndex = 4, Parent = f }, { corner(3) })
            local fill = new("Frame", { Size = UDim2.fromScale((default - min) / (max - min), 1), BorderSizePixel = 0, ZIndex = 5, Parent = track }, { corner(3) }); bindAccent(fill, "BackgroundColor3")
            local dragging = false
            local function update(x) local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1); local value = math.floor(min + (max - min) * alpha + 0.5); fill.Size = UDim2.fromScale(alpha, 1); valueLabel.Text = tostring(value); task.spawn(callback, value) end
            track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; update(input.Position.X) end end)
            UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
            UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input.Position.X) end end)
        end
        function api.Button(text, callback)
            local f = row(38);
            local b = new("TextButton", { Text = text, Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.new(1,1,1), Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = f }, { corner(8) }); bindAccent(b, "BackgroundColor3")
            b.MouseButton1Click:Connect(function() task.spawn(callback) end)
        end
        function api.Dropdown(text, options, default, callback)
            tab.order += 1
            local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 38), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = THEME.item, BackgroundTransparency = 0.4, BorderSizePixel = 0, LayoutOrder = tab.order, ZIndex = 4, Parent = page }, { corner(8), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
            local header = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 5, Parent = holder }); label(header, text)
            local current = new("TextLabel", { Text = default .. "  ▾", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = THEME.subtext, TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1, Position = UDim2.new(1, -140, 0, 0), Size = UDim2.new(0, 128, 1, 0), ZIndex = 5, Parent = header })
            local list = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, LayoutOrder = 1, ZIndex = 6, Parent = holder }, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
            for i, option in ipairs(options) do
                local ob = new("TextButton", { Text = option, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.text, BackgroundColor3 = THEME.bg, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, ZIndex = 7, Parent = list })
                ob.MouseButton1Click:Connect(function() current.Text = option .. "  ▾"; list.Visible = false; task.spawn(callback, option) end)
            end
            header.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
        end
        function api.Label(text) local f = row(28); local l = label(f, text, UDim2.new(1, -16, 1, 0)); l.TextColor3 = THEME.subtext; l.TextSize = 11 end

        tab.api = api
        button.MouseButton1Click:Connect(function() selectTab(tab) end)
        table.insert(tabs, tab)
        if #tabs == 1 then selectTab(tab) end
        return tab
    end

    -- ============================================================
    -- AUTO ESCAPE
    -- ============================================================
    local VALID_KEYS = { W=true, A=true, S=true, D=true, L=true }
    local escapeState = { lastEscape = 0, escapeLastScan = 0, escapeLastKey = "", escapeDebugLast = 0 }
    local function findEscapeKey()
        local pg = player:FindFirstChild("PlayerGui"); if not pg then return nil end
        local cam = Workspace.CurrentCamera; if not cam then return nil end
        local vp = cam.ViewportSize; local bestKey, bestScore
        for _, g in ipairs(pg:GetDescendants()) do
            if g:IsA("TextLabel") and g.Visible and g.Text then
                local trimmed = g.Text:match("^%s*(.-)%s*$") or ""
                if #trimmed == 1 then
                    local up = string.upper(trimmed)
                    if VALID_KEYS[up] then
                        local abs = g.AbsoluteSize
                        if abs.X >= Config.EscapeMinSize and abs.Y >= Config.EscapeMinSize then
                            local pos = g.AbsolutePosition; local onScreen = pos.X > -50 and pos.Y > -50 and pos.X < vp.X + 50 and pos.Y < vp.Y + 50
                            local inScroll = false; local p = g.Parent
                            while p and p ~= pg do if p:IsA("ScrollingFrame") then inScroll = true; break end; p = p.Parent end
                            if onScreen and not inScroll then
                                local score = abs.X * abs.Y
                                local cx = math.abs(pos.X + abs.X/2 - vp.X/2); local cy = math.abs(pos.Y + abs.Y/2 - vp.Y/2)
                                score = score - math.sqrt(cx*cx + cy*cy) * 50
                                if not bestScore or score > bestScore then bestKey, bestScore = up, score end
                            end
                        end
                    end
                end
            end
        end
        return bestKey
    end
    local function pressEscapeKey(keyCode, hold) hold = hold or 0.06; pcall(function() VirtualInputManager:SendKeyEvent(true, keyCode, false, game) end); task.wait(hold); pcall(function() VirtualInputManager:SendKeyEvent(false, keyCode, false, game) end) end
    local function checkAndEscape()
        if not Config.AutoEscape then return end
        local now = os.clock(); if now - escapeState.lastEscape < Config.EscapeCooldown then return end
        if now - escapeState.escapeLastScan < 0.1 then
            if escapeState.escapeLastKey ~= "" then local kc = Enum.KeyCode[escapeState.escapeLastKey]; if kc then pressEscapeKey(kc); escapeState.lastEscape = now end end
            return
        end
        escapeState.escapeLastScan = now; local key = findEscapeKey(); escapeState.escapeLastKey = key or ""
        if key then local kc = Enum.KeyCode[key]; if kc then pressEscapeKey(kc); escapeState.lastEscape = now end end
    end
    task.spawn(function() while task.wait(0.05) do checkAndEscape() end end)

    -- ============================================================
    -- FARM / SKILL / AUTO RETRY
    -- ============================================================
    local function NapeOf(titan)
        local hit = titan:FindFirstChild("Hitboxes")
        hit = hit and hit:FindFirstChild("Hit")
        return hit and hit:FindFirstChild("Nape")
    end

    local function GetTitan()
        local titans = Workspace:FindFirstChild("Titans"); if not titans then return nil end
        local myRoot = getRoot(); if not myRoot then return nil end
        local closest, minDist = nil, math.huge
        for _, titan in ipairs(titans:GetChildren()) do
            if titan:IsA("Model") then
                local hum = titan:FindFirstChildOfClass("Humanoid")
                local nape = NapeOf(titan)
                if hum and hum.Health > 0 and nape then
                    local dist = (nape.Position - myRoot.Position).Magnitude
                    if dist < minDist then minDist = dist; closest = titan end
                end
            end
        end
        return closest
    end

    local function GetNapesAround(mainTitan, count)
        local mainNape = NapeOf(mainTitan)
        if not mainNape then return {} end
        local titans = Workspace:FindFirstChild("Titans")
        if not titans then return { mainNape } end
        local others = {}
        for _, t in ipairs(titans:GetChildren()) do
            if t ~= mainTitan and t:IsA("Model") then
                local hum = t:FindFirstChildOfClass("Humanoid")
                local n = NapeOf(t)
                if hum and hum.Health > 0 and n then
                    others[#others + 1] = { part = n, d = (n.Position - mainNape.Position).Magnitude }
                end
            end
        end
        table.sort(others, function(a, b) return a.d < b.d end)
        local list = { mainNape }
        for i = 1, math.min((count or 5) - 1, #others) do list[#list + 1] = others[i].part end
        return list
    end

    local function AttackTitan(titan, root)
        local post = ReplicatedStorage.Assets.Remotes.POST
        if not post then return end
        if Config.MassiveAttack and root and (root.Position.Y - titan.Hitboxes.Hit.Nape.Position.Y) > 50 then
            local napes = GetNapesAround(titan, Config.HitCount)
            pcall(function()
                post:FireServer("Attacks", "Slash", true)
                for r = 1, (Config.DamageMult or 1) do
                    for _, part in ipairs(napes) do
                        post:FireServer("Hitboxes", "Register", part, 143 + math.random()*10, 0.26 + math.random()*0.25)
                    end
                end
                post:FireServer("Attacks", "Slash", false)
            end)
        else
            local nape = titan.Hitboxes.Hit.Nape
            pcall(function()
                post:FireServer("Attacks", "Slash", true)
                for r = 1, (Config.DamageMult or 1) do
                    post:FireServer("Hitboxes", "Register", nape, 143 + math.random()*10, 0.26 + math.random()*0.25)
                end
                post:FireServer("Attacks", "Slash", false)
            end)
        end
    end

    task.spawn(function()
        task.wait(3)
        while task.wait() do
            if Config.AutoFarm and not isRefilling then
                local root = getRoot(); local titan = GetTitan()
                if root and titan then
                    local nape = titan.Hitboxes.Hit.Nape
                    local targetPos = nape.Position + Vector3.new(0, Config.FlyHeight, 0)
                    local dist = (targetPos - root.Position).Magnitude
                    if dist > 6 then
                        local dir = (targetPos - root.Position).Unit;
                        root.CFrame = root.CFrame + dir * (Config.FlySpeed * RunService.Heartbeat:Wait())
                    else
                        AttackTitan(titan, root);
                        task.wait(0.15)
                    end
                end
            end
        end
    end)

    task.spawn(function()
        task.wait(3)
        local lastPress = 0
        while task.wait(0.3) do
            if Config.AutoRetry then
                local now = os.clock()
                if now - lastPress > 1 then
                    local foundRetry = nil
                    for _, guiObj in ipairs(playerGui:GetDescendants()) do
                        if guiObj:IsA("TextLabel") or guiObj:IsA("TextButton") then
                            local text = string.upper(guiObj.Text or "")
                            if text:match("^REINTENTAR") or text:match("^RETRY") then
                                if guiObj.Visible and guiObj.AbsoluteSize.X > 0 and guiObj.AbsoluteSize.Y > 0 then
                                    foundRetry = guiObj
                                    break
                                end
                            end
                        end
                    end
                    if foundRetry then
                        lastPress = now
                        local btn = foundRetry
                        if foundRetry:IsA("TextLabel") then
                            local p = foundRetry.Parent
                            for _ = 1, 4 do
                                if not p or p == playerGui then break end
                                if p:IsA("GuiButton") then btn = p; break end
                                p = p.Parent
                            end
                        end
                        notify("Auto Click", "Reintentando...", 1)
                        pcall(function()
                            if type(firesignal) == "function" and btn:IsA("GuiButton") then
                                firesignal(btn.Activated)
                                firesignal(btn.MouseButton1Click)
                            end
                        end)
                        pcall(function()
                            if btn:IsA("GuiButton") then
                                local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
                            end
                        end)
                    end
                end
            end
        end
    end)

    task.spawn(function()
        task.wait(3)
        while task.wait(1) do
            if Config.AutoSkill then
                if isMobile then pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0); task.wait(0.05); VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
                else
                    local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
                    for _, key in ipairs(keys) do pcall(function() VirtualInputManager:SendKeyEvent(true, key, false, game); task.wait(0.05); VirtualInputManager:SendKeyEvent(false, key, false, game) end) end
                end
            end
        end
    end)

    -- ============================================================
    --  REFILL — VERSIÓN PULIDA
    -- ============================================================
    local REFILL_PLACES = {
        [13379349730] = { "Unclimbable", "Props", "HQ" }, [14012874501] = { "Unclimbable", "Props", "HQ" },
        [13904207646] = { "Climbable", "_Walls", "Gate" }, [14638336319] = { "Unclimbable", "Camps", "Camp" },
        [15220308770] = { "Climbable", "Utgard" }, [17688739434] = { "Unclimbable", "World", "Buildings", "Hanger" },
        [15824912319] = { "Unclimbable", "Props", "HQ" }, [126678335159530] = { "Unclimbable", "Reloads" },
    }

    local Farm = {
        Refilling = false,
        LastReload = nil,
        ReloadRejects = 0,
        ReloadSettleUntil = 0,
        BladesEmptyFor = 0,
        ActorSegments = nil,
        ActorReloads = nil,
        ActorActive = nil,
        SpearStuck = false,
        RecentlyRefilled = 0,  -- [FIX 1] timestamp del último refill exitoso
    }

    local stations = nil
    local function Collect(container)
        local list = {}
        local n = 0
        for _, d in ipairs(container:GetDescendants()) do
            n += 1
            if n % 500 == 0 then task.wait() end
            if d.Name == "Refill" then list[#list + 1] = d end
        end
        return list
    end
    local function PosOf(inst)
        local ok, pos = pcall(function()
            if inst:IsA("BasePart") then return inst.Position end
            if inst:IsA("Model") then return inst:GetPivot().Position end
            local part = inst:FindFirstChildWhichIsA("BasePart", true)
            return part and part.Position or nil
        end)
        return ok and pos or nil
    end

    local function NearestStation(root)
        local valid = stations and #stations > 0
        if valid then
            for _, st in ipairs(stations) do
                if not st.Parent then valid = false break end
            end
        end
        if not valid then
            stations = {}
            local uncl = Workspace:FindFirstChild("Unclimbable")
            local obj = uncl and uncl:FindFirstChild("Objective")
            local waveFolder = obj and obj:FindFirstChild("Waves")
            if waveFolder then stations = Collect(waveFolder) end
            if #stations == 0 then
                local container = Workspace
                local path = REFILL_PLACES[game.PlaceId]
                if path then
                    local cur = Workspace
                    for _, name in ipairs(path) do cur = cur and cur:FindFirstChild(name) end
                    if cur then container = cur end
                end
                stations = Collect(container)
                if #stations == 0 and container ~= Workspace then stations = Collect(Workspace) end
            end
        end
        local best, bestDist = nil, math.huge
        for _, st in ipairs(stations) do
            local pos = PosOf(st)
            if pos then
                local d = (pos - root.Position).Magnitude
                if d < bestDist then best, bestDist = st, d end
            end
        end
        return best
    end

    local function Rig() local char = player.Character; return char and char:FindFirstChild("Rig_" .. player.Name) end

    local function BladeParts()
        local rig = Rig()
        local list = {}
        for _, handName in ipairs({ "RightHand", "LeftHand" }) do
            local hand = rig and rig:FindFirstChild(handName)
            for _, d in ipairs(hand and hand:GetChildren() or {}) do
                if d.Name:match("^Blade_%d+$") then list[#list + 1] = d end
            end
        end
        return list
    end

    local function AllBroken()
        local parts = BladeParts()
        if #parts == 0 then return false end
        for _, p in ipairs(parts) do
            if not p:GetAttribute("Broken") then return false end
        end
        return true
    end

    local function BladesEmpty()
        if AllBroken() then return true end
        local seg = Farm.ActorSegments and Farm.ActorSegments()
        if seg == nil then
            local raw = player:GetAttribute("SH_Segments")
            seg = raw and tonumber(raw) or nil
        end
        return seg ~= nil and seg <= 0
    end

    local function SpearsLeft()
        local char = player.Character
        local n = char and char:GetAttribute("Spears")
        if type(n) == "number" then return n end
        return nil
    end

    local function SpareLeft()
        local actorReloads = Farm.ActorReloads and Farm.ActorReloads()
        if actorReloads ~= nil then return actorReloads end
        local rig = Rig()
        local torso = rig and rig:FindFirstChild("LowerTorso")
        if not torso then return nil end
        local total, left = 0, 0
        for _, d in ipairs(torso:GetChildren()) do
            if d.Name:match("^Left_%d+$") then
                total = total + 1
                if not d:GetAttribute("Used") then left = left + 1 end
            end
        end
        if total == 0 then return nil end
        return left
    end

    local function NeedBladeRaw()
        if not BladesEmpty() then return false end
        local sp = SpareLeft()
        if sp == 0 then return true end
        if sp == nil then
            return (Farm.ReloadRejects or 0) >= 2 or (Farm.BladesEmptyFor or 0) >= 5
        end
        return false
    end

    local function NeedBlade() return Config.AutoRefillBlade and NeedBladeRaw() end
    local function NeedThunderRaw()
        local n = SpearsLeft()
        if n ~= nil and n <= 0 then return true end
        return Farm.SpearStuck == true
    end
    local function NeedThunder() return Config.AutoRefillThunder and NeedThunderRaw() end
    local function RefillsLeft()
        local n = player:GetAttribute("Refills")
        if type(n) == "number" then return n end
        return nil
    end

    local function TweenToPos(root, targetPos, speed)
        if not root or not targetPos then return end
        pcall(function() player:RequestStreamAroundAsync(targetPos, 0.5) end)
        local dist = (targetPos - root.Position).Magnitude
        local t = math.clamp(dist / (speed or Config.RefillSpeed), 0.1, 6)
        local ok, tw = pcall(function()
            return TweenService:Create(root, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.new(targetPos) })
        end)
        if not ok or not tw then pcall(function() root.CFrame = CFrame.new(targetPos) end) return end
        local vel = RunService.Heartbeat:Connect(function()
            pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
        end)
        tw:Play()
        local t0 = os.clock()
        while os.clock() - t0 < t + 0.3 and tw.PlaybackState == Enum.PlaybackState.Playing and Alive() do task.wait() end
        pcall(function() tw:Cancel() end)
        vel:Disconnect()
    end

    local function PromptOf(station)
        local p = station:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not p and station.Parent then p = station.Parent:FindFirstChildWhichIsA("ProximityPrompt", true) end
        return p
    end
    local function PromptPos(prompt, station)
        local par = prompt and prompt.Parent
        if par and par:IsA("BasePart") then return par.Position end
        if par and par:IsA("Attachment") then return par.WorldPosition end
        return PosOf(station)
    end
    local function PressPrompt(prompt)
        if not prompt then return false end
        if type(fireproximityprompt) == "function" then
            if pcall(fireproximityprompt, prompt) then return true end
        end
        return pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.15)
            prompt:InputHoldEnd()
        end)
    end
    local function PressRKey(prompt)
        local hold = (prompt and prompt.HoldDuration or 0) + 0.2
        pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game) end)
        task.wait(hold)
        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
    end
    local function PromptCount(prompt)
        if not prompt then return nil end
        local txt = tostring(prompt.ObjectText or "") .. " " .. tostring(prompt.ActionText or "")
        local n = txt:match("(%d+)%s*/%s*%d+")
        return n and tonumber(n) or nil
    end

    -- ============================================================
    --  ACTOR HOOK
    -- ============================================================
    do
        local token = tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999))
        local lastBeat, lastBeatAt = nil, 0
        local function Get(name) return player:GetAttribute(name) end
        local function Fresh()
            local beat = Get("SH_Beat")
            if beat == nil or Get("SH_ActorToken") ~= token then return false end
            if beat ~= lastBeat then lastBeat, lastBeatAt = beat, os.clock() end
            return os.clock() - lastBeatAt < 2
        end

        Farm.ActorActive   = function() return Fresh() end
        Farm.ActorSegments = function() if Fresh() then return tonumber(Get("SH_Segments")) end return nil end
        Farm.ActorReloads  = function() if Fresh() then return tonumber(Get("SH_Reloads"))  end return nil end

        local CODE = [==[
            local TOKEN = "__TOKEN__"
            pcall(task.synchronize)
            repeat task.wait() until game:IsLoaded()
            local LP = game:GetService("Players").LocalPlayer
            local Host
            for _, c in ipairs(filtergc("table", { Keys = { "Modules", "Cache", "Invoked", "Services" } }, false)) do
                if type(c) == "table" and type(c.Modules) == "table" and type(c.Cache) == "table"
                    and c.Cache.Player == LP and type(c.Modules.ODMG) == "table" then
                    Host = c
                    break
                end
            end
            if not Host then return end
            local beat, lastDump = 0, nil
            while LP:GetAttribute("SH_ActorToken") == TOKEN do
                task.wait(0.2)
                local req = LP:GetAttribute("SH_DumpRequest")
                if req ~= nil and req ~= lastDump then lastDump = req end
                local loadout = Host.Loadout
                local supply  = loadout and loadout.Supply
                local seg     = supply and tonumber(supply.Segments)
                local rel     = supply and tonumber(supply.Reloads)
                beat = beat + 1
                LP:SetAttribute("SH_Segments", seg)
                LP:SetAttribute("SH_Reloads",  rel)
                LP:SetAttribute("SH_Beat",     beat)
            end
        ]==]

        local function Supported()
            return type(getactors) == "function"
                and type(run_on_actor) == "function"
                and type(filtergc) == "function"
        end

        local function Inject()
            local okA, actors = pcall(getactors)
            if not (okA and type(actors) == "table" and #actors > 0) then return false end
            token = tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999))
            player:SetAttribute("SH_ActorToken", token)
            for _, actor in ipairs(actors) do
                pcall(run_on_actor, actor, (CODE:gsub("__TOKEN__", function() return token end)))
            end
            return true
        end

        task.spawn(function()
            if not Supported() then
                print("[Casper][Actor] Ejecutor no soporta getactors -> fallback")
                return
            end
            local wasLinked, lastTry = false, -999
            while Alive() do
                task.wait(0.5)
                if Fresh() then
                    if not wasLinked then
                        wasLinked = true
                        print("[Casper][Actor] Conectado | Segments=" .. tostring(Get("SH_Segments"))
                            .. " Reloads=" .. tostring(Get("SH_Reloads")))
                    end
                else
                    if wasLinked then
                        wasLinked = false
                        print("[Casper][Actor] Señal perdida -> reconectando")
                    end
                    local char = player.Character
                    if char and os.clock() - lastTry >= 5 then
                        lastTry = os.clock()
                        Inject()
                    end
                end
            end
        end)

        task.spawn(function()
            while Alive() do
                task.wait(0.25)
                pcall(function()
                    player:SetAttribute("SH_AutoReload",
                        (Config.AutoRefillBlade or Config.AutoRefillThunder) and CanUseHere() and true or false)
                end)
            end
            pcall(function()
                player:SetAttribute("SH_ActorToken", nil)
                player:SetAttribute("SH_AutoReload", false)
            end)
        end)
    end

    -- ============================================================
    --  DoRefill (Normal) — 2 pasos + FIX 1
    -- ============================================================
    local REFILL_TRIES = 2
    local CHECK_WAIT = 3

    local function MarkRefilled()
        Farm.RecentlyRefilled = os.clock() + 10  -- [FIX 1] bloquear SpearStuck 10s
        Farm.ReloadRejects = 0
        Farm.ReloadSettleUntil = os.clock() + 3 -- [FIX 3] gracia 3s
    end

    local function DoRefill()
        local ok0, post = pcall(function()
            return ReplicatedStorage.Assets.Remotes:WaitForChild("POST", 5)
        end)
        if not ok0 or not post then return false end

        local refillsBefore = RefillsLeft()
        local function Done()
            if not (NeedBlade() or NeedThunder()) then return true end
            local now = RefillsLeft()
            return refillsBefore ~= nil and now ~= nil and now < refillsBefore
        end
        local function WaitDone(sec)
            local t0 = os.clock()
            while os.clock() - t0 < sec do
                if Done() then return true end
                if not Alive() then return false end
                task.wait(0.2)
            end
            return Done()
        end

        for attempt = 1, REFILL_TRIES do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not (root and hum and hum.Health > 0) then break end
            local station = NearestStation(root)
            if not station then break end

            -- Paso 1: remote directo
            pcall(function() post:FireServer("Attacks", "Reload", station) end)
            if WaitDone(2.5) then
                Farm.Refilling = false
                MarkRefilled()
                return true
            end

            -- Paso 2: viaje físico
            local prompt = PromptOf(station)
            local back = root.CFrame
            local pos = PromptPos(prompt, station)
            Farm.Refilling = true
            if pos then
                TweenToPos(root, pos + Vector3.new(0, 3, 0), Config.RefillSpeed)
                task.wait(0.3)
            end
            if prompt then PressPrompt(prompt) else PressRKey(nil) end
            task.wait(0.4)
            pcall(function() post:FireServer("Attacks", "Reload", station) end)
            local done = WaitDone(CHECK_WAIT)
            local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if r and back then TweenToPos(r, back.Position, Config.RefillSpeed) end
            Farm.Refilling = false

            if done then MarkRefilled() return true end
            Farm.ReloadRejects = (Farm.ReloadRejects or 0) + 1
        end
        Farm.Refilling = false
        return false
    end

    -- ============================================================
    --  DoWaveRefill — [FIX 2] con remote directo primero
    -- ============================================================
    local function WaveFolder()
        local u = Workspace:FindFirstChild("Unclimbable")
        local o = u and u:FindFirstChild("Objective")
        return o and o:FindFirstChild("Waves")
    end
    local function WaveNeed()
        if Config.AutoRefillThunder then return NeedThunderRaw() end
        return NeedBladeRaw()
    end

    local function DoWaveRefill()
        local folder = WaveFolder()
        if not folder then return false end
        local list = Collect(folder)
        local okP, post = pcall(function()
            return ReplicatedStorage.Assets.Remotes:FindFirstChild("POST")
        end)
        if not okP then post = nil end

        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not (root and hum and hum.Health > 0) then return false end

        local station, bestD = nil, math.huge
        for _, st in ipairs(list) do
            local pos = st.Parent and PosOf(st)
            if pos then
                local d = (pos - root.Position).Magnitude
                if d < bestD then station, bestD = st, d end
            end
        end
        if not station then return false end

        local refillsBefore = RefillsLeft()
        local function WaveDone()
            if not WaveNeed() then return true end
            local now = RefillsLeft()
            return refillsBefore ~= nil and now ~= nil and now < refillsBefore
        end

        -- [FIX 2] Paso 1: remote directo SIN mover (igual que DoRefill)
        if post then
            pcall(function() post:FireServer("Attacks", "Reload", station) end)
            local t0 = os.clock()
            while os.clock() - t0 < 2.5 do
                if WaveDone() then
                    Farm.Refilling = false
                    MarkRefilled()
                    return true
                end
                if not Alive() then return false end
                task.wait(0.2)
            end
        end

        -- Paso 2: viaje físico con variación de métodos
        local prompt = PromptOf(station)
        local pos = PromptPos(prompt, station)
        if not pos then return false end

        local success = false
        for attempt = 1, 3 do
            char = player.Character
            hum = char and char:FindFirstChildOfClass("Humanoid")
            root = char and char:FindFirstChild("HumanoidRootPart")
            if not (root and hum and hum.Health > 0) then break end

            local back = root.CFrame
            Farm.Refilling = true
            TweenToPos(root, pos + Vector3.new(0, 3, 0), Config.WaveSpeed)
            task.wait(0.2)

            local before = PromptCount(prompt)
            if attempt == 1 then
                if prompt then PressPrompt(prompt) else PressRKey(nil) end
            elseif attempt == 2 then
                PressRKey(prompt)
            elseif post then
                pcall(function() post:FireServer("Attacks", "Reload", station) end)
            end

            local t1 = os.clock()
            while os.clock() - t1 < 5 and WaveNeed() and Alive() do task.wait(0.2) end
            local still = WaveNeed()
            local after = PromptCount(prompt)
            if still and before ~= nil and after ~= nil and after < before then
                task.wait(2)
                still = WaveNeed()
            end

            local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if r and back then TweenToPos(r, back.Position, Config.WaveSpeed) end
            Farm.Refilling = false

            if not still then success = true; break end
        end
        Farm.Refilling = false
        if success then MarkRefilled() end
        return success
    end

    -- ============================================================
    --  Loop Normal Refill
    -- ============================================================
    task.spawn(function()
        task.wait(3)
        local lastRefill = -999
        local since = nil
        while task.wait(0.4) do
            local ok, err = pcall(function()
                local isWaveMode = Config.AutoRefillWave and WaveFolder() ~= nil
                local needs = NeedBlade() or NeedThunder()
                if isWaveMode then since = nil return end
                if not (CanUseHere() and needs) then
                    since = nil
                    if Farm.Refilling and not isRefilling then Farm.Refilling = false end
                    return
                end
                since = since or os.clock()
                if os.clock() - since < 1.0 then return end
                if os.clock() - lastRefill < Config.RefillCooldown then return end
                local left = RefillsLeft()
                if left ~= nil and left <= 0 then
                    lastRefill = os.clock() - Config.RefillCooldown + 30
                    since = nil
                    return
                end
                Farm.Refilling = true
                isRefilling = true
                local okRefill = DoRefill()
                Farm.Refilling = false
                isRefilling = false
                lastRefill = os.clock() - (okRefill and 0 or (Config.RefillCooldown - 3))
                since = nil
            end)
            if not ok then
                Farm.Refilling = false
                isRefilling = false
                lastRefill = os.clock() - Config.RefillCooldown + 3
                warn("[Casper][Refill] error:", err)
                task.wait(1)
            end
        end
    end)

    -- ============================================================
    --  Loop Wave Refill
    -- ============================================================
    task.spawn(function()
        task.wait(3)
        local since = nil
        local lastWave = -999
        local failStreak = 0
        local WAVE_COOLDOWN = 10
        while task.wait(0.4) do
            local ok, err = pcall(function()
                if not (Config.AutoRefillWave and WaveFolder()) then since = nil failStreak = 0 return end
                if not CanUseHere() then since = nil return end
                if not WaveNeed() then since = nil failStreak = 0 return end
                since = since or os.clock()
                if os.clock() - since < 1.0 then return end
                if os.clock() - lastWave < WAVE_COOLDOWN then return end
                Farm.Refilling = true
                isRefilling = true
                local okW = DoWaveRefill()
                Farm.Refilling = false
                isRefilling = false
                if okW then
                    failStreak = 0
                    lastWave = os.clock()
                    since = nil
                else
                    failStreak += 1
                    if failStreak >= 3 then
                        lastWave = os.clock() - WAVE_COOLDOWN + 30
                        failStreak = 0
                    else
                        lastWave = os.clock() - WAVE_COOLDOWN + 3
                    end
                    since = os.clock() - 1.5
                end
            end)
            if not ok then
                Farm.Refilling = false
                isRefilling = false
                lastWave = os.clock() - 10 + 3
                warn("[Casper][WaveRefill] error:", err)
                task.wait(1)
            end
        end
    end)

    -- ============================================================
    --  BladesEmptyFor [FIX 3] gracia 3s
    -- ============================================================
    task.spawn(function()
        local emptyStart = nil
        local wasEmpty = false
        while task.wait(0.1) do
            if not Alive() then break end
            local empty = BladesEmpty() == true
            if empty then
                emptyStart = emptyStart or os.clock()
                Farm.BladesEmptyFor = os.clock() - emptyStart
            else
                emptyStart = nil
                Farm.BladesEmptyFor = 0
            end
            if wasEmpty and not empty then
                Farm.ReloadSettleUntil = os.clock() + 3  -- [FIX 3] 3s en vez de 0.6s
                Farm.ReloadRejects = 0
            end
            wasEmpty = empty
        end
    end)

    -- ============================================================
    --  SpearStuck [FIX 1] sin falso positivo tras refill
    -- ============================================================
    task.spawn(function()
        local lastSpears = nil
        local stuckCount = 0
        while task.wait(1) do
            if not Alive() then break end
            local n = SpearsLeft()
            local recentlyRefilled = os.clock() < (Farm.RecentlyRefilled or 0)  -- [FIX 1]
            if n == nil then
                Farm.SpearStuck = false
                lastSpears = nil
                stuckCount = 0
            elseif n <= 0 then
                Farm.SpearStuck = true
                lastSpears = n
                stuckCount = 0
            else
                if Config.AutoFarm and lastSpears == n and not recentlyRefilled then
                    stuckCount += 1
                    Farm.SpearStuck = stuckCount >= 8
                else
                    stuckCount = 0
                    Farm.SpearStuck = false
                end
                lastSpears = n
            end
        end
    end)

    -- ============================================================
    -- AUTO WAVE
    -- ============================================================
    local function PressButtonByName(name, exact)
        local found = nil
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("TextLabel")) and gui.Visible then
                local text = gui.Text:upper()
                local match = exact and (text == name) or text:find(name, 1, true)
                if match then
                    local btn = gui
                    while btn and btn ~= playerGui and not btn:IsA("GuiButton") do btn = btn.Parent end
                    if btn and btn:IsA("GuiButton") then found = btn break end
                end
            end
        end
        if found then
            pcall(function() if type(firesignal) == "function" then firesignal(found.MouseButton1Click) end end)
            pcall(function() if type(firesignal) == "function" then firesignal(found.Activated) end end)
            local pos = found.AbsolutePosition + found.AbsoluteSize / 2
            pcall(function() VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0) end)
            task.wait(0.05)
            pcall(function() VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0) end)
            return true
        end
        return false
    end

    task.spawn(function()
        while task.wait(2) do
            if Config.AutoCreateWave and Config.AutoPlay then
                if not CanUseHere() then
                    PressButtonByName("WAVES")
                    task.wait(1)
                    PressButtonByName("CREATE")
                    task.wait(1)
                    PressButtonByName("START")
                end
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            if Config.AutoPlay and Config.AutoReady then
                PressButtonByName("READY", true)
                PressButtonByName("ACCEPT", true)
            end
            if Config.AutoPlay and Config.AutoVoteSkip then
                PressButtonByName("VOTE SKIP")
                PressButtonByName("SKIP", true)
            end
        end
    end)

    -- ============================================================
    -- TABS
    -- ============================================================
    addTab("Farm", "🎯", function(api)
        api.Section("Automatización")
        api.Toggle("Auto Farm", false, function(state) Config.AutoFarm = state; notify("Auto Farm", state and "Activado" or "Desactivado", 2) end)
        api.Toggle("Auto Skill", false, function(state) Config.AutoSkill = state; notify("Auto Skill", state and "Activado" or "Desactivado", 2) end)
        api.Section("Ajustes de vuelo")
        api.Slider("Velocidad", 100, 1500, 600, function(v) Config.FlySpeed = v end)
        api.Slider("Altura", 50, 500, 230, function(v) Config.FlyHeight = v end)
        api.Section("Combate")
        api.Toggle("Ataque Masivo Aéreo", false, function(state) Config.MassiveAttack = state; notify("Ataque Masivo", state and "Activado (x10)" or "Desactivado", 2) end)
        api.Slider("Daño Multiplicado", 1, 20, 10, function(v) Config.DamageMult = v end)
        api.Slider("Titanes por ataque", 1, 15, 5, function(v) Config.HitCount = v end)
    end)

    addTab("Wave", "🌊", function(api)
        api.Section("Auto Play (master)")
        api.Toggle("Auto Play", false, function(state) Config.AutoPlay = state; notify("Auto Play", state and "Activado" or "Desactivado", 2) end)
        api.Section("Wave Settings")
        api.Toggle("Auto Create Wave", false, function(state) Config.AutoCreateWave = state; notify("Auto Create Wave", state and "Activado" or "Desactivado", 2) end)
        api.Toggle("Auto Start Wave", false, function(state) Config.AutoStartWave = state; notify("Auto Start Wave", state and "Activado" or "Desactivado", 2) end)
        api.Toggle("Auto Ready", false, function(state) Config.AutoReady = state; notify("Auto Ready", state and "Activado" or "Desactivado", 2) end)
        api.Toggle("Auto Vote Skip", false, function(state) Config.AutoVoteSkip = state; notify("Auto Vote Skip", state and "Activado" or "Desactivado", 2) end)
        api.Section("Refill en Wave")
        api.Toggle("Auto Refill Wave", false, function(state) Config.AutoRefillWave = state; notify("Refill Wave", state and "Activado" or "Desactivado", 2) end)
        api.Slider("Velocidad Refill Wave", 100, 2000, 1000, function(v) Config.WaveSpeed = v end)
        api.Section("Ajustes")
        api.Dropdown("Mapa", { "Trost", "Shiganshina", "Utgard" }, Config.WaveMap, function(option) Config.WaveMap = option end)
    end)

    addTab("Auto Click", "🖱️", function(api)
        api.Section("Ajustes")
        api.Toggle("Auto Click", false, function(state) Config.AutoRetry = state; notify("Auto Click", state and "Activado" or "Desactivado", 2) end)
        api.Label("Hace clicks automáticamente para matar a titanes.")
    end)

    addTab("Refill", "⛽", function(api)
        api.Section("Relleno automático (Normal)")
        api.Toggle("Auto Refill Blades", false, function(state) Config.AutoRefillBlade = state; notify("Refill Blades", state and "Activado" or "Desactivado", 2) end)
        api.Toggle("Auto Refill Thunder", false, function(state) Config.AutoRefillThunder = state; notify("Refill Thunder", state and "Activado" or "Desactivado", 2) end)
        api.Section("Ajustes")
        api.Slider("Cooldown refill", 1, 30, 5, function(v) Config.RefillCooldown = v end)
        api.Slider("Velocidad refill", 100, 2000, 800, function(v) Config.RefillSpeed = v end)
        api.Button("Refill manual (1 vez)", function()
            local post = ReplicatedStorage.Assets.Remotes:FindFirstChild("POST")
            if post then pcall(function() post:FireServer("Attacks", "Reload") end); notify("Refill", "Ejecutado", 2) else notify("Refill", "Fallo", 2) end
        end)
        api.Section("Estado en vivo")
        api.Button("Debug Refill", function()
            local seg = Farm.ActorSegments and Farm.ActorSegments()
            local rel = Farm.ActorReloads and Farm.ActorReloads()
            local act = Farm.ActorActive and Farm.ActorActive() and "SÍ" or "no"
            local refills = RefillsLeft() or "?"
            notify("Refill Debug",
                "Actor: " .. act ..
                " | Seg: " .. tostring(seg) ..
                " | Rel: " .. tostring(rel) ..
                " | Refills: " .. tostring(refills) ..
                " | Refilling: " .. tostring(Farm.Refilling) ..
                " | SpearStuck: " .. tostring(Farm.SpearStuck), 8)
        end)
    end)

    addTab("Escape", "🛡️", function(api)
        api.Section("QTE")
        api.Toggle("Auto Escape (WASDL)", false, function(state) Config.AutoEscape = state; notify("Auto Escape", state and "Activado" or "Desactivado", 2) end)
        api.Toggle("Debug escape", false, function(state) Config.DebugEscape = state end)
        api.Section("Sensibilidad")
        api.Slider("Cooldown (x100)", 5, 50, 15, function(v) Config.EscapeCooldown = v / 100 end)
        api.Slider("Tamaño mínimo label", 10, 60, 20, function(v) Config.EscapeMinSize = v end)
    end)

    addTab("Visual", "🎨", function(api)
        api.Section("Interfaz")
        api.Dropdown("Color del tema", { "Purpura", "Cian", "Verde", "Rojo", "Naranja", "Rosa" }, "Purpura", function(option) setAccent(ACCENTS[option]); notify("Tema", "Cambiado a " .. option, 2) end)
    end)

    addTab("Ajustes", "⚙️", function(api)
        api.Section("General")
        api.Toggle("Notificaciones", true, function(state) notifyHolder.Visible = state end)
        api.Button("Probar notificación", function() notify("¡Funciona!", "Así se ven las notificaciones.", 3) end)
        api.Label("Tecla para abrir/cerrar: RightShift")
        api.Button("Cerrar menú", function() Config.AutoFarm = false; Config.AutoSkill = false; Config.AutoEscape = false; Config.AutoRetry = false; gui:Destroy() end)
    end)

    minimizeBtn.MouseButton1Click:Connect(function()
        MiniFrame.Position = UDim2.new(window.Position.X.Scale, window.Position.X.Offset + (window.AbsoluteSize.X / 2) - 30, window.Position.Y.Scale, window.Position.Y.Offset + (window.AbsoluteSize.Y / 2) - 30)
        window.Visible = false; MiniFrame.Visible = true
    end)

    closeBtn.MouseButton1Click:Connect(function()
        Config.AutoFarm = false; Config.AutoSkill = false; Config.AutoEscape = false; Config.AutoRetry = false
        window.Visible = false; MiniFrame.Visible = false
    end)

    task.spawn(function()
        while task.wait(0.1) do
            if not isMobile then
                local cam = workspace.CurrentCamera
                if window.Visible then
                    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
                    pcall(function() UserInputService.MouseIconEnabled = true end)
                    if cam and cam.CameraMode == Enum.CameraMode.LockFirstPerson then
                        pcall(function() cam.CameraMode = Enum.CameraMode.Classic end)
                    end
                end
            end
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift then
            if window.Visible then window.Visible = false; MiniFrame.Visible = true
            else window.Visible = true; MiniFrame.Visible = false end
        end
    end)

    notify("CASPER HUB PREMIUM v8.5", "Refill pulido + Wave fix + Actor Hook.", 4)
    print("[CASPER HUB PREMIUM v8.5] Cargado. Actor + Refill robusto activo.")
end

if isKeyVerified then
    loadMainScript()
else
    _G.CasperMainScript = loadMainScript
end
