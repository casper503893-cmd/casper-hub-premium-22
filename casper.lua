--[[
  CASPER HUB PREMIUM — v13.1
  Fix del límite de 200 registros locales: la construcción se divide en
  buildTokens / buildShell / buildRuntime / buildTabs / boot, con un
  contexto compartido. Ninguna función se acerca al límite.

  La lógica de features es la misma de v13.0, sin cambios.
]]

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local HttpService         = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile  = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================================
-- KEYS
-- ============================================================
local ValidKeys = { ["CASPER-1234"] = true, ["VIP-0000"] = true, ["PREMIUM-2024"] = true }
local saveFile = "CasperHub_Key.txt"
local isKeyVerified = false
local function CheckSavedKey()
    if type(isfile) == "function" and isfile(saveFile) then
        local ok, savedKey = pcall(readfile, saveFile)
        if ok and ValidKeys[savedKey] then isKeyVerified = true end
    end
end
CheckSavedKey()

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    AutoFarm = false, FlySpeed = 600, FlyHeight = 230, AutoSkill = false,
    AutoEscape = false, EscapeCooldownX100 = 15, EscapeMinSize = 20, DebugEscape = false,
    AutoRefillBlade = false, AutoRefillThunder = false, AutoRefillWave = false,
    RefillCooldown = 5, RefillSpeed = 800, WaveSpeed = 1000,
    DamageMult = 10, HitCount = 5, AutoRetry = false, MassiveAttack = false,
    AutoCreateWave = false, AutoStartWave = false, AutoReady = false,
    AutoVoteSkip = false, AutoPlay = false, WaveMap = "Trost", WaveLevel = "Easy",
    RaidSelect = "Attack Titan", RaidLevel = "Hard", RaidModifiers = {},
    RaidJoinDelay = 10, AutoCreateRaid = false, AutoStartRaid = false,
    AutoSkipCutscene = false, AutoOpenChestFree = false, AutoOpenChestPremium = false,
    AutoFinishChest = false, AutoCannon = false,
    UITheme = "Dark", UIAccess = "Purpura", UINotify = true,
    Keybind = "RightShift", Favorites = {},
    CursorEnabled = false, CursorShape = "Punto", CursorColor = "#8A5CFF", CursorSize = 14, CursorOpacity = 20,
    AvatarVisible = true, AvatarTintColor = "#8A5CFF", AvatarTintStrength = 0, AvatarRingColor = "#8A5CFF",
    UIScale = 1, UIReducedMotion = false, UICollapsed = false, UIActiveTab = "Inicio",
    UIWinW = 880, UIWinH = 600, Hotkeys = {},
}
local isRefilling = false
local UIPosition = nil

local THEME = {
    bg = Color3.fromRGB(8, 8, 12), panel = Color3.fromRGB(16, 16, 24),
    item = Color3.fromRGB(24, 24, 36), text = Color3.fromRGB(255, 255, 255),
    subtext = Color3.fromRGB(130, 140, 170), accent = Color3.fromRGB(138, 92, 255),
}

local WIN_MIN_W, WIN_MIN_H, WIN_MAX_W, WIN_MAX_H = 660, 440, 1180, 860

-- ============================================================
-- RAID CONFIG
-- ============================================================
local RAID_CONFIG = {
    { name = "Attack Titan",   map = "Trost",       diffs = { "Hard", "Severe", "Aberrant" } },
    { name = "Armored Titan",  map = "Shiganshina", diffs = { "Hard", "Severe", "Aberrant" } },
    { name = "Female Titan",   map = "Stohess",     diffs = { "Hard", "Severe", "Aberrant" } },
    { name = "Colossal Titan", map = "Shiganshina", diffs = { "Aberrant" }, minimum = 3 },
}
local RAID_NAMES = {}
for i, r in ipairs(RAID_CONFIG) do RAID_NAMES[i] = r.name end
local RAID_DIFF_LABELS = { "Hard", "Severe", "Aberrant" }
local RAID_MODIFIER_OPTIONS = { "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial", "Boring", "Simple" }
local function RaidInfo(name) for _, r in ipairs(RAID_CONFIG) do if r.name == name then return r end end return RAID_CONFIG[1] end
local function RaidDifficulty()
    local info = RaidInfo(Config.RaidSelect)
    if table.find(info.diffs, Config.RaidLevel) then return Config.RaidLevel end
    return info.diffs[#info.diffs]
end

-- ============================================================
-- PERSISTENCIA
-- ============================================================
local SAVE_DIR = "SmoothHub"
local SettingsStore = {}
do
    local owner = player
    local ROOT, DIR = SAVE_DIR, SAVE_DIR .. "/" .. tostring(owner.UserId)
    local canSave = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    local canFolder = type(makefolder) == "function" and type(isfolder) == "function"
    local flushers = {}
    function SettingsStore.Path(fn) if canFolder then return DIR .. "/" .. fn .. ".json" end return ROOT .. "_" .. owner.UserId .. "_" .. fn .. ".json" end
    local function ensureFolder() if not canFolder then return end pcall(function() if not isfolder(ROOT) then makefolder(ROOT) end if not isfolder(DIR) then makefolder(DIR) end end) end
    local function clean(v, d)
        d = d or 0; local k = type(v)
        if k == "string" or k == "boolean" then return v end
        if k == "number" then if v ~= v or v == math.huge or v == -math.huge then return nil end return v end
        if k ~= "table" or d > 6 then return nil end
        local c, isArr = 0, true
        for kk in pairs(v) do c = c + 1 if type(kk) ~= "number" then isArr = false end end
        if isArr then for i = 1, c do if v[i] == nil then isArr = false break end end end
        local out = {}
        if isArr then for i = 1, c do local cc = clean(v[i], d + 1) if cc ~= nil then table.insert(out, cc) end end
        else for kk, vv in pairs(v) do local cc = clean(vv, d + 1) if cc ~= nil then out[tostring(kk)] = cc end end end
        return out
    end
    function SettingsStore.Load(fn) if not canSave then return {} end local ok, data = pcall(function() local p = SettingsStore.Path(fn) if not isfile(p) then return nil end return HttpService:JSONDecode(readfile(p)) end) if ok and type(data) == "table" then return data end return {} end
    function SettingsStore.Write(fn, data) if not canSave then return false end ensureFolder() return pcall(function() writefile(SettingsStore.Path(fn), HttpService:JSONEncode(data)) end) end
    function SettingsStore.StartAutoSave(fn, getData, interval)
        if flushers[fn] then return end
        local last = nil
        local function flush()
            local ok, snap = pcall(function() return clean(getData()) end)
            if not ok or type(snap) ~= "table" then return end
            local okS, sig = pcall(function() return HttpService:JSONEncode(snap) end)
            if not okS or sig == last then return end
            snap.SavedAt = os.time(); snap.Account = owner.Name
            if SettingsStore.Write(fn, snap) then
                last = sig
                if SettingsStore.OnSaved then pcall(SettingsStore.OnSaved, snap.SavedAt) end
            end
        end
        flushers[fn] = flush
        task.spawn(function() while true do task.wait(interval or 1.5) flush() end end)
    end
    function SettingsStore.Flush(fn) local f = flushers[fn] if f then pcall(f) end end
end

local ConfigStore = { DEFAULT_NAME = "Casper Hub | Default" }
do
    local PATH = SAVE_DIR .. "/AOTR_Configs_" .. player.UserId .. ".json"
    local data = { Autoload = nil, Active = nil, AutoSync = true, List = {} }
    local sigs = {}
    local defaultSnap = nil
    local canSave = type(writefile) == "function" and type(isfile) == "function"
    local canFolder = type(makefolder) == "function" and type(isfolder) == "function"
    local function Flush()
        if not canSave then return false end
        return pcall(function()
            if canFolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
            writefile(PATH, HttpService:JSONEncode(data))
        end)
    end
    local function CopyVal(v) if type(v) == "table" then local o = {} for _, i in ipairs(v) do if type(i) == "string" then o[#o + 1] = i end end return o end return v end
    function ConfigStore.Reload()
        data = { Autoload = nil, Active = nil, AutoSync = true, List = {} }
        sigs = {}
        if defaultSnap then data.List[ConfigStore.DEFAULT_NAME] = defaultSnap end
        if not canSave then return end
        local ok, d = pcall(function() if not isfile(PATH) then return nil end return HttpService:JSONDecode(readfile(PATH)) end)
        if ok and type(d) == "table" then
            if type(d.List) == "table" then for n, s in pairs(d.List) do if type(n) == "string" and type(s) == "table" and n ~= ConfigStore.DEFAULT_NAME then data.List[n] = s end end end
            if type(d.Autoload) == "string" and data.List[d.Autoload] then data.Autoload = d.Autoload end
            if type(d.Active) == "string" and data.List[d.Active] then data.Active = d.Active end
            if d.AutoSync == false then data.AutoSync = false end
        end
    end
    function ConfigStore.Names() local n = {} for k in pairs(data.List) do n[#n + 1] = k end table.sort(n, function(a, b) if a == ConfigStore.DEFAULT_NAME then return false end if b == ConfigStore.DEFAULT_NAME then return true end return a:lower() < b:lower() end) return n end
    function ConfigStore.IsDefault(n) return n == ConfigStore.DEFAULT_NAME end
    function ConfigStore.Exists(n) return data.List[n] ~= nil end
    function ConfigStore.Get(n) return data.List[n] end
    function ConfigStore.Autoload() return data.Autoload end
    function ConfigStore.Active() return data.Active end
    function ConfigStore.AutoloadSnapshot() return data.Autoload and data.List[data.Autoload] or nil end
    function ConfigStore.Snapshot()
        local s = { Cfg = {}, UI = {} }
        for k, v in pairs(Config) do s.Cfg[k] = CopyVal(v) end
        s.UI.Theme = Config.UITheme; s.UI.Accent = Config.UIAccess; s.UI.Keybind = Config.Keybind
        s.UI.Scale = Config.UIScale; s.UI.Collapsed = Config.UICollapsed; s.UI.Reduced = Config.UIReducedMotion
        return s
    end
    function ConfigStore.Put(n, s) if n == ConfigStore.DEFAULT_NAME then return false end data.List[n] = s sigs[n] = nil return Flush() end
    function ConfigStore.Delete(n) if n == ConfigStore.DEFAULT_NAME then return false end data.List[n] = nil sigs[n] = nil if data.Autoload == n then data.Autoload = nil end if data.Active == n then data.Active = nil end return Flush() end
    function ConfigStore.SetAutoload(n) if n ~= nil and not data.List[n] then return false end data.Autoload = n return Flush() end
    function ConfigStore.SetActive(n) if n ~= nil and not data.List[n] then return false end if data.Active == n then return true end data.Active = n return Flush() end
    function ConfigStore.SetAutoSync(v) data.AutoSync = v and true or false return Flush() end
    function ConfigStore.AutoSync() return data.AutoSync ~= false end
    function ConfigStore.SaveActive()
        local n = data.Active
        if not n or not data.List[n] then return false, nil end
        if n == ConfigStore.DEFAULT_NAME then return false, n end
        data.List[n] = ConfigStore.Snapshot(); sigs[n] = nil
        local ok = Flush()
        if ok then local okS, sig = pcall(function() return HttpService:JSONEncode(data.List[n]) end) if okS then sigs[n] = sig end end
        return ok, n
    end
    function ConfigStore.SyncActive()
        if data.AutoSync == false then return false end
        local n = data.Active
        if not n or not data.List[n] or n == ConfigStore.DEFAULT_NAME then return false end
        local snap = ConfigStore.Snapshot()
        local okS, sig = pcall(function() return HttpService:JSONEncode(snap) end)
        if not okS or sigs[n] == sig then return false end
        data.List[n] = snap
        if Flush() then sigs[n] = sig return true end
        return false
    end
    function ConfigStore.ApplyCfg(s)
        if type(s) ~= "table" or type(s.Cfg) ~= "table" then return end
        for k, v in pairs(s.Cfg) do
            if Config[k] ~= nil and type(Config[k]) == type(v) then
                if type(v) == "table" then local o = {} for i, it in ipairs(v) do o[i] = it end Config[k] = o
                else Config[k] = v end
            end
        end
        if type(s.UI) == "table" then
            if type(s.UI.Theme) == "string" then Config.UITheme = s.UI.Theme end
            if type(s.UI.Accent) == "string" then Config.UIAccess = s.UI.Accent end
            if type(s.UI.Keybind) == "string" then Config.Keybind = s.UI.Keybind end
            if type(s.UI.Scale) == "number" then Config.UIScale = s.UI.Scale end
            if type(s.UI.Collapsed) == "boolean" then Config.UICollapsed = s.UI.Collapsed end
            if type(s.UI.Reduced) == "boolean" then Config.UIReducedMotion = s.UI.Reduced end
        end
    end
    local function BuildDefault()
        local s = ConfigStore.Snapshot()
        defaultSnap = s; data.List[ConfigStore.DEFAULT_NAME] = s
    end
    BuildDefault(); ConfigStore.Reload()
end

local autoSnap = ConfigStore.AutoloadSnapshot()
if autoSnap then
    ConfigStore.ApplyCfg(autoSnap); ConfigStore.SetActive(ConfigStore.Autoload())
else
    local sd = SettingsStore.Load("AOTR")
    if type(sd) == "table" and type(sd.Cfg) == "table" then
        for k, v in pairs(sd.Cfg) do if Config[k] ~= nil and type(Config[k]) == type(v) then Config[k] = v end end
    end
end
SettingsStore.StartAutoSave("AOTR", function() return { Cfg = Config } end)
SettingsStore.OnSaved = function() pcall(ConfigStore.SyncActive) end

-- ============================================================
-- HELPERS GLOBALES
-- ============================================================
local function new(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    return obj
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end
local function tween(obj, time, props) TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end
local function getRoot() local c = player.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function Alive() return player and player.Parent ~= nil end

local IN_MENU = (game.PlaceId == 13379208636)
local LOBBY_PLACE_ID = 14916516914
local ON_LOBBY_PLACE = (game.PlaceId == LOBBY_PLACE_ID)
local function CanUseHere() return not IN_MENU and game.PlaceId ~= LOBBY_PLACE_ID end
local function ContextKind()
    if IN_MENU then return "menu" end
    if ON_LOBBY_PLACE then return "lobby" end
    local char = player.Character
    if char and char:FindFirstChildOfClass("Humanoid") then return "game" end
    return "other"
end

-- ============================================================
-- EVENT BUS / LOG
-- ============================================================
local EventBus = { events = {} }
function EventBus:On(event, fn)
    self.events[event] = self.events[event] or {}
    table.insert(self.events[event], fn)
    return function()
        local list = self.events[event]
        if not list then return end
        for i, f in ipairs(list) do if f == fn then table.remove(list, i) break end end
    end
end
function EventBus:Emit(event, ...)
    local list = self.events[event]
    if not list then return end
    for _, fn in ipairs(list) do task.spawn(fn, ...) end
end

local LogHistory = {}
local function pushLog(title, message)
    table.insert(LogHistory, 1, { title = title, message = message, time = os.time() })
    while #LogHistory > 30 do table.remove(LogHistory) end
    EventBus:Emit("LogAdded", LogHistory)
end

local CHANGELOG = {
    "13.1 · reparto de la construcción para no pasar el límite de 200 registros",
    "13.0 · dashboard, presets, hotkeys, cursor y figura, resize, escala de UI",
    "12.2 · textos visibles, sidebar sin solapes, contraste de toggle",
    "12.1 · sync de configs, tema reconstruible, favoritos, log, modal",
}

-- ============================================================
-- KEY GUI
-- ============================================================
if not isKeyVerified then
    local keyGui = new("ScreenGui", { Name = "KeySystem", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, Parent = playerGui })
    local kf = new("Frame", { Size = UDim2.fromOffset(360, 268), Position = UDim2.new(0.5, -180, 0.5, -134), BackgroundColor3 = THEME.bg, BorderSizePixel = 0, Parent = keyGui }, { corner(18), new("UIStroke", { Color = THEME.accent, Thickness = 1.5, Transparency = 0.3 }) })
    new("TextLabel", { Text = "CASPER HUB", Font = Enum.Font.GothamBlack, TextSize = 25, TextColor3 = THEME.text, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 34), Parent = kf })
    new("TextLabel", { Text = "PREMIUM · v13", Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = THEME.accent, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 0, 16), Parent = kf })
    new("TextLabel", { Text = "Introduce tu key de acceso", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.subtext, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 92), Size = UDim2.new(1, 0, 0, 18), Parent = kf })
    local tb = new("TextBox", { Text = "", PlaceholderText = "CASPER-XXXX", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.text, BackgroundColor3 = THEME.item, BorderSizePixel = 0, Position = UDim2.fromOffset(30, 124), Size = UDim2.new(1, -60, 0, 42), Parent = kf }, { corner(10), new("UIStroke", { Color = Color3.fromRGB(50, 50, 70), Thickness = 1, Transparency = 0.3 }) })
    local sl = new("TextLabel", { Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(255, 90, 90), BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 174), Size = UDim2.new(1, -60, 0, 20), Parent = kf })
    local btn = new("TextButton", { Text = "VERIFICAR", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = THEME.accent, BorderSizePixel = 0, Position = UDim2.fromOffset(30, 204), Size = UDim2.new(1, -60, 0, 42), AutoButtonColor = false, Parent = kf }, { corner(10) })
    btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundColor3 = Color3.fromRGB(160, 110, 255) }) end)
    btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundColor3 = THEME.accent }) end)
    btn.MouseButton1Click:Connect(function()
        local k = tb.Text
        if k == "" then sl.Text = "Introduce una key válida." return end
        if ValidKeys[k] then
            if type(writefile) == "function" then pcall(function() writefile(saveFile, k) end) end
            sl.TextColor3 = Color3.fromRGB(60, 220, 140); sl.Text = "✓ Acceso concedido"
            task.wait(0.8); keyGui:Destroy(); isKeyVerified = true
            if _G.CasperMainScript then _G.CasperMainScript() end
        else sl.Text = "✗ Key incorrecta" end
    end)
end

-- ============================================================
-- 1) TOKENS, HELPERS DE UI, ICONOS, TOOLTIP, CURSOR
-- ============================================================
local function buildTokens(S)
    local THEMES = {
        Dark = {
            bg0 = Color3.fromRGB(6, 6, 10), bg1 = Color3.fromRGB(11, 11, 18), bg2 = Color3.fromRGB(16, 16, 26),
            card = Color3.fromRGB(21, 21, 33), cardHi = Color3.fromRGB(28, 28, 44),
            stroke = Color3.fromRGB(38, 38, 58), strokeHi = Color3.fromRGB(56, 56, 84),
            text = Color3.fromRGB(245, 247, 255), sub = Color3.fromRGB(150, 158, 184), mute = Color3.fromRGB(90, 98, 124),
            track = Color3.fromRGB(30, 30, 46), ok = Color3.fromRGB(60, 220, 140), bad = Color3.fromRGB(240, 70, 100), warn = Color3.fromRGB(255, 190, 60),
        },
        Light = {
            bg0 = Color3.fromRGB(238, 240, 246), bg1 = Color3.fromRGB(246, 247, 251), bg2 = Color3.fromRGB(255, 255, 255),
            card = Color3.fromRGB(255, 255, 255), cardHi = Color3.fromRGB(238, 240, 248),
            stroke = Color3.fromRGB(216, 220, 232), strokeHi = Color3.fromRGB(196, 202, 218),
            text = Color3.fromRGB(18, 20, 30), sub = Color3.fromRGB(88, 96, 122), mute = Color3.fromRGB(140, 148, 172),
            track = Color3.fromRGB(224, 228, 240), ok = Color3.fromRGB(30, 180, 110), bad = Color3.fromRGB(220, 50, 80), warn = Color3.fromRGB(230, 150, 20),
        },
    }
    S.ACCENTS = {
        Purpura = Color3.fromRGB(138, 92, 255), Cian = Color3.fromRGB(0, 200, 240), Verde = Color3.fromRGB(40, 220, 130),
        Rojo = Color3.fromRGB(240, 70, 100), Naranja = Color3.fromRGB(255, 150, 50), Rosa = Color3.fromRGB(255, 70, 180),
    }
    S.ACCENT_NAMES = { "Purpura", "Cian", "Verde", "Rojo", "Naranja", "Rosa" }
    S.V = {}
    local t = THEMES[Config.UITheme] or THEMES.Dark
    for k, v in pairs(t) do S.V[k] = v end
    S.V.reduced = Config.UIReducedMotion == true
    THEME.accent = S.ACCENTS[Config.UIAccess] or S.ACCENTS.Purpura

    S.TYPO = {
        h1 = { font = Enum.Font.GothamBlack, size = 19 },
        h2 = { font = Enum.Font.GothamBold, size = 14 },
        body = { font = Enum.Font.GothamMedium, size = 12 },
        caption = { font = Enum.Font.GothamMedium, size = 10 },
        micro = { font = Enum.Font.GothamBold, size = 9 },
    }
    S.H = {}
    local H = S.H
    local V = S.V

    H.label = function(parent, typ, text, props)
        props = props or {}
        props.Text = text
        props.Font = S.TYPO[typ].font
        props.TextSize = S.TYPO[typ].size
        props.TextColor3 = props.TextColor3 or V.text
        props.BackgroundTransparency = props.BackgroundTransparency or 1
        props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
        local obj = new("TextLabel", props)
        if parent then obj.Parent = parent end
        return obj
    end
    H.stroke = function(parent, color, thick, transp)
        return new("UIStroke", { Color = color or V.stroke, Thickness = thick or 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
    end
    H.spring = function(obj, prop, target, dur)
        TweenService:Create(obj, TweenInfo.new(V.reduced and 0.01 or (dur or 0.35), Enum.EasingStyle.Back, Enum.EasingDirection.Out), { [prop] = target }):Play()
    end
    H.smooth = function(obj, dur, props)
        TweenService:Create(obj, TweenInfo.new(V.reduced and 0.01 or (dur or 0.25), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end
    H.hex = function(hex)
        hex = tostring(hex or ""):gsub("#", "")
        if #hex == 3 then hex = hex:gsub("(.)", "%1%1") end
        if #hex ~= 6 or hex:find("%X") then return nil end
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        if not (r and g and b) then return nil end
        return Color3.fromRGB(r, g, b)
    end
    H.toHex = function(c)
        return ("#%02X%02X%02X"):format(
            math.floor(math.clamp(c.R, 0, 1) * 255 + 0.5),
            math.floor(math.clamp(c.G, 0, 1) * 255 + 0.5),
            math.floor(math.clamp(c.B, 0, 1) * 255 + 0.5))
    end
    H.escapeRich = function(s)
        return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
    end

    S.accentObjects = {}
    H.bindAccent = function(inst, prop)
        table.insert(S.accentObjects, { inst, prop }); inst[prop] = THEME.accent
    end
    H.setAccent = function(name)
        local c = S.ACCENTS[name] or S.ACCENTS.Purpura
        THEME.accent = c
        for _, p in ipairs(S.accentObjects) do
            if p[1] and p[1].Parent then
                TweenService:Create(p[1], TweenInfo.new(V.reduced and 0.01 or 0.35), { [p[2]] = c }):Play()
            end
        end
    end

    H.icon = function(parent, kind, color, size)
        size = size or 16; color = color or V.sub
        local holder = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = (parent.ZIndex or 1) + 2, Parent = parent })
        local function bar(x, y, w, h, rot)
            return new("Frame", { Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = rot or 0, ZIndex = (holder.ZIndex or 1), Parent = holder }, { corner(math.min(w, h) / 2) })
        end
        local function hollow(r, th)
            local f = new("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, ZIndex = holder.ZIndex, Parent = holder }, { corner(r or 8) })
            new("UIStroke", { Color = color, Thickness = th or 2, Parent = f })
        end
        if kind == "home" then
            bar(2, 6, 12, 2, 0); bar(7, 1, 2, 6, 0); bar(3, 9, 10, 2, 0); bar(5, 12, 6, 2, 0)
        elseif kind == "farm" then
            bar(2, 2, 2, 12, 0); bar(7, 2, 2, 12, 0); bar(12, 2, 2, 12, 0)
        elseif kind == "wave" then
            bar(0, 8, 16, 2, 0); bar(2, 5, 12, 2, 0); bar(4, 2, 8, 2, 0)
        elseif kind == "raid" then
            bar(7, 0, 2, 16, 0); bar(0, 7, 16, 2, 0); bar(3, 3, 4, 4, 45); bar(9, 9, 4, 4, 45)
        elseif kind == "click" then
            bar(6, 2, 4, 6, 0); bar(6, 8, 4, 6, 0)
        elseif kind == "refill" then
            hollow(4, 2); bar(6, 6, 4, 4, 0)
        elseif kind == "escape" then
            bar(4, 0, 8, 2, 0); bar(2, 3, 2, 8, 0); bar(12, 3, 2, 8, 0); bar(4, 11, 8, 2, 0)
        elseif kind == "visual" then
            hollow(8, 2); bar(6, 6, 4, 4, 0)
        elseif kind == "config" then
            bar(2, 3, 12, 2, 0); bar(2, 7, 12, 2, 0); bar(2, 11, 12, 2, 0)
        elseif kind == "log" then
            bar(2, 3, 12, 2, 0); bar(2, 7, 10, 2, 0); bar(2, 11, 8, 2, 0)
        elseif kind == "diag" then
            bar(1, 9, 3, 6, 0); bar(6, 4, 3, 11, 0); bar(11, 7, 3, 8, 0)
        elseif kind == "settings" then
            hollow(8, 2); bar(7, 1, 2, 14, 0); bar(1, 7, 14, 2, 0)
        end
        return holder
    end

    H.ripple = function(button)
        button.ClipsDescendants = true
        button.MouseButton1Down:Connect(function()
            if V.reduced then return end
            local r = new("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = (button.ZIndex or 1) + 5, Parent = button }, { corner(5) })
            TweenService:Create(r, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(button.AbsoluteSize.X * 2, button.AbsoluteSize.X * 2), BackgroundTransparency = 1 }):Play()
            task.delay(0.6, function() r:Destroy() end)
        end)
    end

    local oldTip = playerGui:FindFirstChild("CasperTooltip")
    if oldTip then oldTip:Destroy() end
    S.ui.tooltipGui = new("ScreenGui", { Name = "CasperTooltip", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10000, Parent = playerGui })
    S.ui.tooltipFrame = new("Frame", { Size = UDim2.fromOffset(0, 24), BackgroundColor3 = V.cardHi, BorderSizePixel = 0, Visible = false, ZIndex = 9999, Parent = S.ui.tooltipGui }, { corner(6) })
    H.stroke(S.ui.tooltipFrame, V.strokeHi, 1, 0.3)
    S.ui.tooltipLabel = H.label(S.ui.tooltipFrame, "caption", "", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), TextColor3 = V.text })
    H.tip = function(obj, text)
        obj.MouseEnter:Connect(function()
            S.ui.tooltipLabel.Text = text
            S.ui.tooltipFrame.Size = UDim2.fromOffset(math.max(60, #text * 6 + 16), 24)
            S.ui.tooltipFrame.Position = UDim2.fromOffset(obj.AbsolutePosition.X + obj.AbsoluteSize.X / 2 - S.ui.tooltipFrame.Size.X.Offset / 2, obj.AbsolutePosition.Y - 30)
            S.ui.tooltipFrame.Visible = true
        end)
        obj.MouseLeave:Connect(function() S.ui.tooltipFrame.Visible = false end)
    end

    S.CURSOR_SHAPES = { "Punto", "Anillo", "Cruz", "Mira", "Cuadrado" }
    local oldCursor = playerGui:FindFirstChild("CasperCursor")
    if oldCursor then oldCursor:Destroy() end
    S.ui.cursorGui = new("ScreenGui", { Name = "CasperCursor", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10001, Parent = playerGui })
    S.ui.cursorFrame = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = S.ui.cursorGui })
    S.cursorParts = {}

    H.buildCursor = function()
        for _, p in ipairs(S.cursorParts) do p:Destroy() end
        S.cursorParts = {}
        local size = math.clamp(tonumber(Config.CursorSize) or 14, 8, 40)
        local color = H.hex(Config.CursorColor) or THEME.accent
        local transp = math.clamp((tonumber(Config.CursorOpacity) or 20) / 100, 0, 0.95)
        S.ui.cursorFrame.Size = UDim2.fromOffset(size, size)
        local function piece(x, y, w, h, radius)
            local f = new("Frame", { Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y), BackgroundColor3 = color, BackgroundTransparency = transp, BorderSizePixel = 0, ZIndex = 2, Parent = S.ui.cursorFrame }, { corner(radius or 0) })
            S.cursorParts[#S.cursorParts + 1] = f
        end
        local function ring(radius, thickness)
            local f = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = S.ui.cursorFrame }, { corner(radius) })
            new("UIStroke", { Color = color, Thickness = thickness, Transparency = transp, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
            S.cursorParts[#S.cursorParts + 1] = f
        end
        local shape = Config.CursorShape or "Punto"
        local mid = math.floor(size / 2)
        if shape == "Anillo" then ring(size / 2, 2)
        elseif shape == "Cuadrado" then piece(0, 0, size, size, 2)
        elseif shape == "Cruz" then
            piece(0, mid - 1, size, 2, 1); piece(mid - 1, 0, 2, size, 1)
        elseif shape == "Mira" then
            local tick = math.max(4, math.floor(size * 0.35))
            local gap = math.max(2, math.floor(size * 0.18))
            piece(mid - 1, 0, 2, tick, 1); piece(mid - 1, size - tick, 2, tick, 1)
            piece(0, mid - 1, tick, 2, 1); piece(size - tick, mid - 1, tick, 2, 1)
            piece(mid - gap, mid - gap, gap * 2, gap * 2, gap)
        else piece(0, 0, size, size, size / 2) end
    end

    H.applyCursor = function()
        local on = Config.CursorEnabled and true or false
        S.ui.cursorGui.Enabled = on
        if on then H.buildCursor() end
        pcall(function() UserInputService.MouseIconEnabled = not on end)
    end

    task.spawn(function()
        while S.ui.cursorGui.Parent do
            if Config.CursorEnabled then
                local p = UserInputService:GetMouseLocation()
                S.ui.cursorFrame.Position = UDim2.fromOffset(p.X, p.Y)
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

-- ============================================================
-- 2) SHELL: GUI, VENTANA, HEADER, SIDEBAR, CONTENIDO, AVISOS
-- ============================================================
local function buildShell(S)
    local H, V = S.H, S.V
    local ui = S.ui

    local oldGui = playerGui:FindFirstChild("CasperPremium")
    if oldGui then oldGui:Destroy() end
    local gui = new("ScreenGui", { Name = "CasperPremium", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 999, Parent = playerGui })
    ui.gui = gui

    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local winW = math.clamp(Config.UIWinW or 880, WIN_MIN_W, math.min(WIN_MAX_W, vp.X - 40))
    local winH = math.clamp(Config.UIWinH or 600, WIN_MIN_H, math.min(WIN_MAX_H, vp.Y - 40))

    local MiniFrame = new("Frame", { Name = "MiniFrame", Size = UDim2.fromOffset(72, 72), Position = UIPosition or UDim2.new(0, 24, 0.5, -36), BackgroundColor3 = V.card, BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 10, Parent = gui }, { corner(36) })
    ui.MiniFrame = MiniFrame
    ui.miniStroke = H.stroke(MiniFrame, THEME.accent, 2.5, 0)
    ui.miniMonogram = H.label(MiniFrame, "h2", (player.DisplayName or player.Name):sub(1, 1):upper(), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, TextColor3 = V.text, ZIndex = 11 })
    ui.miniMonogram.Visible = false
    ui.miniAvatar = new("ImageLabel", { Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), BackgroundTransparency = 1, Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150", ZIndex = 12, Parent = MiniFrame }, { corner(36) })
    ui.pulseRing = new("Frame", { Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9, Parent = MiniFrame }, { corner(36) })
    ui.pulseStroke = H.stroke(ui.pulseRing, THEME.accent, 2, 1); H.bindAccent(ui.pulseStroke, "Color")
    task.spawn(function()
        while ui.pulseRing.Parent do
            if not V.reduced then
                ui.pulseRing.Size = UDim2.fromOffset(72, 72); ui.pulseRing.Position = UDim2.fromOffset(0, 0); ui.pulseStroke.Transparency = 0.9
                H.smooth(ui.pulseRing, 1.2, { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(-12, -12) })
                H.smooth(ui.pulseStroke, 1.2, { Transparency = 1 })
            end
            task.wait(1.2)
        end
    end)

    local window = new("Frame", { Name = "Window", Size = UDim2.fromOffset(winW, winH), Position = UIPosition or UDim2.new(0.5, -winW / 2, 0.5, -winH / 2), BackgroundColor3 = V.bg1, BorderSizePixel = 0, ClipsDescendants = false, ZIndex = 5, Parent = gui }, { corner(18) })
    ui.window = window
    H.stroke(window, V.strokeHi, 1, 0.35)
    window.BackgroundTransparency = 1
    H.smooth(window, 0.35, { BackgroundTransparency = 0 })
    ui.uiScale = new("UIScale", { Scale = Config.UIScale or 1, Parent = window })

    local bgLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = V.bg1, BorderSizePixel = 0, ZIndex = 1, Parent = window }, { corner(18) })
    new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, V.bg1), ColorSequenceKeypoint.new(0.55, V.bg2), ColorSequenceKeypoint.new(1, V.bg0) }), Rotation = 135, Parent = bgLayer })
    local function orb(x, y, size, color, trans)
        local o = new("Frame", { Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(x, y), BackgroundColor3 = color, BackgroundTransparency = trans or 0.9, BorderSizePixel = 0, ZIndex = 1, Parent = window }, { corner(size / 2) })
        new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Rotation = 45, Parent = o })
    end
    orb(-110, -110, 300, THEME.accent, 0.94)
    orb(700, 430, 240, Color3.fromRGB(70, 34, 160), 0.95)

    local header = new("Frame", { Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = V.bg2, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 6, Parent = window }, { corner(18) })
    new("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), BackgroundColor3 = V.bg2, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 6, Parent = header })
    new("UIGradient", { Color = ColorSequence.new(V.bg2, V.bg1), Rotation = 90, Parent = header })
    H.stroke(header, V.strokeHi, 1, 0.5)
    local accLine = new("Frame", { Size = UDim2.new(0, 110, 0, 2), Position = UDim2.new(0, 26, 1, -2), BackgroundColor3 = THEME.accent, BorderSizePixel = 0, ZIndex = 7, Parent = header }, { corner(1) }); H.bindAccent(accLine, "BackgroundColor3")

    local logoHolder = new("Frame", { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(24, 14), BackgroundColor3 = V.card, BorderSizePixel = 0, ZIndex = 8, Parent = header }, { corner(19) })
    H.stroke(logoHolder, THEME.accent, 2, 0); H.bindAccent(logoHolder:FindFirstChildOfClass("UIStroke"), "Color")
    new("TextLabel", { Text = "C", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = logoHolder })

    local titleMain = new("TextLabel", { Text = "CASPER", Font = S.TYPO.h1.font, TextSize = 17, TextColor3 = V.text, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(74, 12), Size = UDim2.fromOffset(200, 20), ZIndex = 8, Parent = header })
    new("UIGradient", { Color = ColorSequence.new(V.text, Color3.fromRGB(200, 210, 240)), Parent = titleMain })
    H.label(header, "micro", "PREMIUM CONTROL", { Position = UDim2.fromOffset(74, 31), Size = UDim2.fromOffset(160, 13), TextColor3 = V.sub, ZIndex = 8 })

    ui.chipHolder = new("Frame", { Size = UDim2.fromOffset(104, 20), Position = UDim2.fromOffset(74, 44), BackgroundColor3 = V.cardHi, BorderSizePixel = 0, ZIndex = 8, Parent = header }, { corner(10) })
    ui.chipDot = new("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(8, 7), BackgroundColor3 = V.mute, BorderSizePixel = 0, ZIndex = 9, Parent = ui.chipHolder }, { corner(3) })
    ui.chipText = H.label(ui.chipHolder, "micro", "—", { Position = UDim2.fromOffset(19, 0), Size = UDim2.fromOffset(80, 20), TextColor3 = V.sub, ZIndex = 9 })

    local verBadge = new("Frame", { Size = UDim2.fromOffset(46, 18), Position = UDim2.fromOffset(186, 45), BackgroundColor3 = THEME.accent, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 8, Parent = header }, { corner(9) }); H.bindAccent(verBadge, "BackgroundColor3")
    H.label(verBadge, "micro", "v13.1", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.new(1, 1, 1), ZIndex = 9 })

    local profile = new("Frame", { Size = UDim2.fromOffset(184, 40), Position = UDim2.new(1, -318, 0.5, -20), BackgroundColor3 = V.card, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 8, Parent = header }, { corner(20) })
    H.stroke(profile, V.strokeHi, 1, 0.5)
    local avatar = new("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = V.cardHi, BorderSizePixel = 0, ZIndex = 9, Parent = profile }, { corner(15) })
    ui.avStroke = H.stroke(avatar, THEME.accent, 1.5, 0.1)
    ui.headerMonogram = H.label(avatar, "h2", (player.DisplayName or player.Name):sub(1, 1):upper(), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, TextColor3 = V.text, ZIndex = 11 })
    ui.headerMonogram.Visible = false
    ui.avImage = new("ImageLabel", { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150", ZIndex = 12, Parent = avatar }, { corner(15) })
    H.label(profile, "body", player.DisplayName or player.Name, { Position = UDim2.fromOffset(42, 4), Size = UDim2.fromOffset(134, 16), TextColor3 = V.text, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9 })
    local premiumLabel = H.label(profile, "micro", "● PREMIUM", { Position = UDim2.fromOffset(42, 21), Size = UDim2.fromOffset(134, 13), TextColor3 = THEME.accent, ZIndex = 9 })
    H.bindAccent(premiumLabel, "TextColor3")

    H.applyAvatarLook = function()
        local tint = H.hex(Config.AvatarTintColor) or Color3.new(1, 1, 1)
        local strength = math.clamp((tonumber(Config.AvatarTintStrength) or 0) / 100, 0, 1)
        local mixed = Color3.new(1, 1, 1):Lerp(tint, strength)
        local ring = H.hex(Config.AvatarRingColor) or THEME.accent
        local shown = Config.AvatarVisible ~= false
        for _, img in ipairs({ ui.miniAvatar, ui.avImage }) do
            img.ImageColor3 = mixed
            img.Visible = shown
        end
        ui.miniMonogram.Visible = not shown
        ui.headerMonogram.Visible = not shown
        ui.miniStroke.Color = ring
        ui.avStroke.Color = ring
    end
    H.applyAvatarLook()

    local function winBtn(text, xPos, hoverColor, tip)
        local b = new("TextButton", { Text = text, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = V.sub, BackgroundColor3 = V.card, BorderSizePixel = 0, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, xPos, 0.5, -15), AutoButtonColor = false, ZIndex = 9, Parent = header }, { corner(8) })
        H.stroke(b, V.strokeHi, 1, 0.5)
        b.MouseEnter:Connect(function() H.smooth(b, 0.15, { BackgroundColor3 = hoverColor, TextColor3 = Color3.new(1, 1, 1) }) end)
        b.MouseLeave:Connect(function() H.smooth(b, 0.15, { BackgroundColor3 = V.card, TextColor3 = V.sub }) end)
        if tip then H.tip(b, tip) end
        return b
    end
    ui.minimizeBtn = winBtn("–", -76, V.warn, "Minimizar")
    ui.closeBtn = winBtn("×", -38, V.bad, "Cerrar")

    H.clampPos = function(x, y)
        local c = Workspace.CurrentCamera
        local size = c and c.ViewportSize or vp
        local w, h = window.AbsoluteSize.X, window.AbsoluteSize.Y
        return UDim2.fromOffset(
            math.clamp(x, -w + 90, math.max(0, size.X - 90)),
            math.clamp(y, 0, math.max(0, size.Y - 40)))
    end
    H.rememberPos = function()
        UIPosition = window.Position
        local s = math.max(ui.uiScale.Scale, 0.1)
        Config.UIWinW = math.floor(window.AbsoluteSize.X / s + 0.5)
        Config.UIWinH = math.floor(window.AbsoluteSize.Y / s + 0.5)
    end

    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = window.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false; H.rememberPos() end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            window.Position = H.clampPos(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
        end
    end)

    local resizeHandle = new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -22, 1, -22), BackgroundTransparency = 1, ZIndex = 12, Parent = window })
    new("Frame", { Size = UDim2.fromOffset(9, 2), Position = UDim2.fromOffset(7, 13), Rotation = -45, BackgroundColor3 = V.strokeHi, BorderSizePixel = 0, Parent = resizeHandle }, { corner(1) })
    new("Frame", { Size = UDim2.fromOffset(5, 2), Position = UDim2.fromOffset(11, 8), Rotation = -45, BackgroundColor3 = V.strokeHi, BorderSizePixel = 0, Parent = resizeHandle }, { corner(1) })
    do
        local resizing, rStart, rSize
        resizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true; rStart = input.Position; rSize = window.Size
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then resizing = false; H.rememberPos() end end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not resizing then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - rStart
                local s = math.max(ui.uiScale.Scale, 0.1)
                window.Size = UDim2.fromOffset(
                    math.clamp(rSize.X.Offset + d.X, WIN_MIN_W * s, WIN_MAX_W * s),
                    math.clamp(rSize.Y.Offset + d.Y, WIN_MIN_H * s, WIN_MAX_H * s))
            end
        end)
    end

    local miniDrag, miniMoved, miniStart, miniPos0
    MiniFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            miniDrag = true; miniMoved = false; miniStart = input.Position; miniPos0 = MiniFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if miniDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - miniStart
            if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then miniMoved = true end
            MiniFrame.Position = UDim2.new(miniPos0.X.Scale, miniPos0.X.Offset + d.X, miniPos0.Y.Scale, miniPos0.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and miniDrag then
            miniDrag = false
            if not miniMoved then
                H.spring(MiniFrame, "Size", UDim2.fromOffset(80, 80), 0.2)
                task.delay(0.15, function()
                    H.smooth(MiniFrame, 0.2, { Size = UDim2.fromOffset(72, 72) })
                    local pos = MiniFrame.Position
                    MiniFrame.Visible = false; window.Visible = true; window.Position = pos; H.rememberPos()
                end)
            end
        end
    end)

    S.SIDEBAR_FULL, S.SIDEBAR_MINI = 218, 62
    local sidebar = new("Frame", { Size = UDim2.new(0, Config.UICollapsed and S.SIDEBAR_MINI or S.SIDEBAR_FULL, 1, -128), Position = UDim2.fromOffset(14, 74), BackgroundColor3 = V.bg2, BackgroundTransparency = 0.18, BorderSizePixel = 0, ZIndex = 7, Parent = window }, { corner(14) })
    ui.sidebar = sidebar
    H.stroke(sidebar, V.strokeHi, 1, 0.5)

    ui.searchBox = new("Frame", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = V.card, BorderSizePixel = 0, ZIndex = 8, Parent = sidebar }, { corner(9) })
    H.stroke(ui.searchBox, V.strokeHi, 1, 0.5)
    ui.searchInput = new("TextBox", { Text = "", PlaceholderText = "Buscar", Font = S.TYPO.body.font, TextSize = S.TYPO.body.size, TextColor3 = V.text, PlaceholderColor3 = V.mute, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -26, 1, 0), ZIndex = 9, Parent = ui.searchBox, ClearTextOnFocus = false })

    ui.tabsScroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -76), Position = UDim2.fromOffset(0, 52), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = V.cardHi, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 8, Parent = sidebar }, { new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }), new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }) })

    ui.collapseBtn = new("TextButton", { Text = "«", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = V.sub, BackgroundColor3 = V.card, BorderSizePixel = 0, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 1, -34), AutoButtonColor = false, ZIndex = 9, Parent = sidebar }, { corner(8) })
    H.stroke(ui.collapseBtn, V.strokeHi, 1, 0.5)
    ui.collapseBtn.MouseEnter:Connect(function() H.smooth(ui.collapseBtn, 0.15, { BackgroundColor3 = V.cardHi, TextColor3 = V.text }) end)
    ui.collapseBtn.MouseLeave:Connect(function() H.smooth(ui.collapseBtn, 0.15, { BackgroundColor3 = V.card, TextColor3 = V.sub }) end)

    local content = new("Frame", { Size = UDim2.new(1, 0, 1, -128), Position = UDim2.fromOffset(240, 74), BackgroundColor3 = V.bg2, BackgroundTransparency = 0.22, BorderSizePixel = 0, ZIndex = 7, Parent = window }, { corner(14) })
    ui.content = content
    H.stroke(content, V.strokeHi, 1, 0.5)

    ui.pageTitle = new("TextLabel", { Text = "", Font = S.TYPO.h1.font, TextSize = S.TYPO.h1.size, TextColor3 = V.text, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -180, 0, 24), ZIndex = 9, Parent = content })
    ui.pageSub = new("TextLabel", { Text = "", Font = S.TYPO.caption.font, TextSize = S.TYPO.caption.size, TextColor3 = V.mute, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 36), Size = UDim2.new(1, -180, 0, 13), ZIndex = 9, Parent = content })

    local toolbar = new("Frame", { Size = UDim2.fromOffset(110, 26), Position = UDim2.new(1, -124, 0, 14), BackgroundTransparency = 1, ZIndex = 9, Parent = content }, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }) })
    ui.resetBtn = new("TextButton", { Text = "Restablecer", Font = S.TYPO.caption.font, TextSize = S.TYPO.caption.size, TextColor3 = V.sub, BackgroundColor3 = V.card, BorderSizePixel = 0, Size = UDim2.fromOffset(84, 26), AutoButtonColor = false, ZIndex = 10, Parent = toolbar }, { corner(7) })
    H.stroke(ui.resetBtn, V.strokeHi, 1, 0.5)
    ui.resetBtn.MouseEnter:Connect(function() H.smooth(ui.resetBtn, 0.15, { BackgroundColor3 = V.cardHi, TextColor3 = V.text }) end)
    ui.resetBtn.MouseLeave:Connect(function() H.smooth(ui.resetBtn, 0.15, { BackgroundColor3 = V.card, TextColor3 = V.sub }) end)
    H.tip(ui.resetBtn, "Vuelve este tab a los valores por defecto")

    ui.pagesHolder = new("Frame", { Size = UDim2.new(1, -40, 1, -82), Position = UDim2.fromOffset(20, 60), BackgroundTransparency = 1, ZIndex = 8, Parent = content })

    local statusBar = new("Frame", { Size = UDim2.new(1, -28, 0, 34), Position = UDim2.new(0, 14, 1, -42), BackgroundColor3 = V.card, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 8, Parent = window }, { corner(10) })
    H.stroke(statusBar, V.strokeHi, 1, 0.5)
    ui.statusDot = new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(13, 13), BackgroundColor3 = V.ok, BorderSizePixel = 0, ZIndex = 9, Parent = statusBar }, { corner(4) })
    ui.statusText = H.label(statusBar, "micro", "Listo", { Position = UDim2.fromOffset(27, 0), Size = UDim2.fromOffset(190, 34), TextColor3 = V.sub, ZIndex = 9 })
    ui.activeFeatures = H.label(statusBar, "micro", "", { Position = UDim2.new(1, -520, 0, 0), Size = UDim2.fromOffset(360, 34), TextColor3 = THEME.accent, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9 })
    H.bindAccent(ui.activeFeatures, "TextColor3")

    ui.panicBtn = new("TextButton", { Text = "PÁNICO", Font = Enum.Font.GothamBlack, TextSize = 10, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = V.bad, BorderSizePixel = 0, Size = UDim2.fromOffset(74, 24), Position = UDim2.new(1, -88, 0.5, -12), AutoButtonColor = false, ZIndex = 10, Parent = statusBar }, { corner(8) })
    ui.panicBtn.MouseEnter:Connect(function() H.smooth(ui.panicBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 100, 130) }) end)
    ui.panicBtn.MouseLeave:Connect(function() H.smooth(ui.panicBtn, 0.15, { BackgroundColor3 = V.bad }) end)
    H.tip(ui.panicBtn, "Apaga todas las features")

    ui.notifyHolder = new("Frame", { Size = UDim2.new(0, 312, 1, -120), Position = UDim2.new(1, -328, 0, 78), BackgroundTransparency = 1, ZIndex = 100, Parent = gui }, { new("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder }) })
    S.notifyQueue, S.notifyActive = {}, {}

    local function spawnCard(title, message, duration)
        local card = new("Frame", { Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = V.card, BackgroundTransparency = 0.06, BorderSizePixel = 0, ZIndex = 101, Parent = ui.notifyHolder }, { corner(12) })
        H.stroke(card, V.strokeHi, 1, 0.3)
        local iconBg = new("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(10, 17), BackgroundColor3 = THEME.accent, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 102, Parent = card }, { corner(17) }); H.bindAccent(iconBg, "BackgroundColor3")
        H.label(iconBg, "h2", "●", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = THEME.accent, ZIndex = 103 })
        H.label(card, "h2", title, { Position = UDim2.fromOffset(54, 10), Size = UDim2.new(1, -80, 0, 16), TextColor3 = V.text, ZIndex = 102 })
        local countLbl = H.label(card, "micro", "", { Position = UDim2.new(1, -46, 0, 12), Size = UDim2.fromOffset(36, 14), TextColor3 = THEME.accent, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 102 })
        H.label(card, "body", message, { Position = UDim2.fromOffset(54, 28), Size = UDim2.new(1, -66, 0, 28), TextColor3 = V.sub, TextWrapped = true, ZIndex = 102 })
        local progBg = new("Frame", { Size = UDim2.new(1, -20, 0, 3), Position = UDim2.new(0, 10, 1, -8), BackgroundColor3 = V.track, BorderSizePixel = 0, ZIndex = 102, Parent = card }, { corner(2) })
        local progBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.accent, BorderSizePixel = 0, ZIndex = 103, Parent = progBg }, { corner(2) }); H.bindAccent(progBar, "BackgroundColor3")
        H.smooth(progBar, duration, { Size = UDim2.fromScale(0, 1) })
        card.Position = UDim2.new(1, 50, 0, 0); card.BackgroundTransparency = 1
        H.smooth(card, 0.28, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.06 })

        local entry = { card = card, count = 1 }
        function entry.close()
            if not card.Parent then return end
            H.smooth(card, 0.22, { Position = UDim2.new(1, 50, 0, 0), BackgroundTransparency = 1 })
            task.wait(0.24)
            card:Destroy()
            local idx = table.find(S.notifyActive, entry)
            if idx then table.remove(S.notifyActive, idx) end
            local nxt = table.remove(S.notifyQueue, 1)
            if nxt then task.spawn(function() S.notify(nxt[1], nxt[2], nxt[3]) end) end
        end
        function entry.bump()
            entry.count += 1
            countLbl.Text = "x" .. entry.count
            H.smooth(progBar, 0.05, { Size = UDim2.fromScale(1, 1) })
            H.smooth(progBar, duration, { Size = UDim2.fromScale(0, 1) })
        end
        table.insert(S.notifyActive, entry)
        task.delay(duration, function() if card.Parent then entry.close() end end)
    end

    S.notify = function(title, message, duration)
        pushLog(title, message)
        if Config.UINotify == false then return end
        duration = duration or 3
        for _, entry in ipairs(S.notifyActive) do
            if entry.card.Parent and entry.card:GetAttribute("Title") == title then entry.bump() return end
        end
        if #S.notifyActive >= 3 then
            S.notifyQueue[#S.notifyQueue + 1] = { title, message, duration }
            return
        end
        spawnCard(title, message, duration)
        S.notifyActive[#S.notifyActive].card:SetAttribute("Title", title)
    end

    local modalOverlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Visible = false, ZIndex = 200, Parent = gui })
    local modalBox = new("Frame", { Size = UDim2.fromOffset(330, 172), Position = UDim2.new(0.5, -165, 0.5, -86), BackgroundColor3 = V.bg2, BorderSizePixel = 0, ZIndex = 201, Parent = modalOverlay }, { corner(14) })
    H.stroke(modalBox, V.strokeHi, 1, 0.3)
    H.label(modalBox, "h2", "¿Confirmar acción?", { Position = UDim2.fromOffset(22, 24), Size = UDim2.new(1, -44, 0, 22), TextColor3 = V.text, ZIndex = 202 })
    local modalMsg = H.label(modalBox, "body", "", { Position = UDim2.fromOffset(22, 54), Size = UDim2.new(1, -44, 0, 44), TextColor3 = V.sub, TextWrapped = true, ZIndex = 202 })
    local modalConfirm = new("TextButton", { Text = "CONFIRMAR", Font = S.TYPO.h2.font, TextSize = S.TYPO.h2.size - 1, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = V.bad, BorderSizePixel = 0, Position = UDim2.new(0, 22, 1, -56), Size = UDim2.new(0.5, -28, 0, 38), AutoButtonColor = false, ZIndex = 202, Parent = modalBox }, { corner(9) })
    local modalCancel = new("TextButton", { Text = "CANCELAR", Font = S.TYPO.h2.font, TextSize = S.TYPO.h2.size - 1, TextColor3 = V.text, BackgroundColor3 = V.card, BorderSizePixel = 0, Position = UDim2.new(0.5, 6, 1, -56), Size = UDim2.new(0.5, -28, 0, 38), AutoButtonColor = false, ZIndex = 202, Parent = modalBox }, { corner(9) })
    local modalResolve = nil
    S.confirm = function(message, onConfirm)
        modalMsg.Text = message
        modalOverlay.Visible = true
        modalBox.Size = UDim2.fromOffset(0, 0); modalBox.BackgroundTransparency = 1
        H.spring(modalBox, "Size", UDim2.fromOffset(330, 172), 0.3)
        H.smooth(modalBox, 0.25, { BackgroundTransparency = 0 })
        modalResolve = onConfirm
    end
    local function closeModal()
        H.smooth(modalBox, 0.18, { BackgroundTransparency = 1 })
        task.wait(0.18); modalOverlay.Visible = false; modalResolve = nil
    end
    modalConfirm.MouseButton1Click:Connect(function()
        local fn = modalResolve; closeModal()
        if fn then task.spawn(fn) end
    end)
    modalCancel.MouseButton1Click:Connect(closeModal)
end

-- ============================================================
-- 3) RUNTIME DE FEATURES
-- ============================================================
local function buildRuntime(S)
    local H = S.H
    S.Farm = { Refilling = false, ReloadRejects = 0, ReloadSettleUntil = 0, BladesEmptyFor = 0, ActorSegments = nil, ActorReloads = nil, ActorActive = nil, SpearStuck = false, RecentlyRefilled = 0 }
    local Farm = S.Farm
    local RT = S.RT
    local VALID_KEYS = { W = true, A = true, S = true, D = true, L = true }
    local escapeState = { lastEscape = 0, lastScan = 0, lastKey = "" }

    local function findEscapeKey()
        local pg = player:FindFirstChild("PlayerGui"); if not pg then return nil end
        local camera = Workspace.CurrentCamera; if not camera then return nil end
        local vps = camera.ViewportSize; local bestKey, bestScore
        for _, g in ipairs(pg:GetDescendants()) do
            if g:IsA("TextLabel") and g.Visible and g.Text then
                local trimmed = g.Text:match("^%s*(.-)%s*$") or ""
                if #trimmed == 1 then
                    local up = string.upper(trimmed)
                    if VALID_KEYS[up] then
                        local abs = g.AbsoluteSize
                        if abs.X >= Config.EscapeMinSize and abs.Y >= Config.EscapeMinSize then
                            local pos = g.AbsolutePosition
                            local onScreen = pos.X > -50 and pos.Y > -50 and pos.X < vps.X + 50 and pos.Y < vps.Y + 50
                            local inScroll = false; local p = g.Parent
                            while p and p ~= pg do if p:IsA("ScrollingFrame") then inScroll = true break end p = p.Parent end
                            if onScreen and not inScroll then
                                local score = abs.X * abs.Y
                                local cx = math.abs(pos.X + abs.X / 2 - vps.X / 2)
                                local cy = math.abs(pos.Y + abs.Y / 2 - vps.Y / 2)
                                score = score - math.sqrt(cx * cx + cy * cy) * 50
                                if not bestScore or score > bestScore then bestKey, bestScore = up, score end
                            end
                        end
                    end
                end
            end
        end
        return bestKey
    end

    RT.pressKey = function(keyCode, hold)
        hold = hold or 0.06
        pcall(function() VirtualInputManager:SendKeyEvent(true, keyCode, false, game) end)
        task.wait(hold)
        pcall(function() VirtualInputManager:SendKeyEvent(false, keyCode, false, game) end)
    end

    RT.checkEscape = function()
        if not Config.AutoEscape then return end
        local cooldown = (Config.EscapeCooldownX100 or 15) / 100
        local now = os.clock()
        if now - escapeState.lastEscape < cooldown then return end
        if now - escapeState.lastScan < 0.1 then
            if escapeState.lastKey ~= "" then
                local kc = Enum.KeyCode[escapeState.lastKey]
                if kc then RT.pressKey(kc); escapeState.lastEscape = now end
            end
            return
        end
        escapeState.lastScan = now
        local key = findEscapeKey()
        escapeState.lastKey = key or ""
        if key then
            local kc = Enum.KeyCode[key]
            if kc then RT.pressKey(kc); escapeState.lastEscape = now end
        end
    end

    local function napeOf(titan)
        local hit = titan:FindFirstChild("Hitboxes")
        hit = hit and hit:FindFirstChild("Hit")
        return hit and hit:FindFirstChild("Nape")
    end

    local function getTitan()
        local titans = Workspace:FindFirstChild("Titans"); if not titans then return nil end
        local myRoot = getRoot(); if not myRoot then return nil end
        local closest, minDist = nil, math.huge
        for _, titan in ipairs(titans:GetChildren()) do
            if titan:IsA("Model") then
                local hum = titan:FindFirstChildOfClass("Humanoid")
                local nape = napeOf(titan)
                if hum and hum.Health > 0 and nape then
                    local dist = (nape.Position - myRoot.Position).Magnitude
                    if dist < minDist then minDist = dist; closest = titan end
                end
            end
        end
        return closest
    end

    local function napesAround(mainTitan, count)
        local mainNape = napeOf(mainTitan)
        if not mainNape then return {} end
        local titans = Workspace:FindFirstChild("Titans")
        if not titans then return { mainNape } end
        local others = {}
        for _, t in ipairs(titans:GetChildren()) do
            if t ~= mainTitan and t:IsA("Model") then
                local hum = t:FindFirstChildOfClass("Humanoid")
                local n = napeOf(t)
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

    local function attackTitan(titan, root)
        local post = ReplicatedStorage.Assets.Remotes.POST
        if not post then return end
        local nape = napeOf(titan)
        if not nape then return end
        if Config.MassiveAttack and root and (root.Position.Y - nape.Position.Y) > 50 then
            local list = napesAround(titan, Config.HitCount)
            pcall(function()
                post:FireServer("Attacks", "Slash", true)
                for _ = 1, (Config.DamageMult or 1) do
                    for _, part in ipairs(list) do
                        post:FireServer("Hitboxes", "Register", part, 143 + math.random() * 10, 0.26 + math.random() * 0.25)
                    end
                end
                post:FireServer("Attacks", "Slash", false)
            end)
        else
            pcall(function()
                post:FireServer("Attacks", "Slash", true)
                for _ = 1, (Config.DamageMult or 1) do
                    post:FireServer("Hitboxes", "Register", nape, 143 + math.random() * 10, 0.26 + math.random() * 0.25)
                end
                post:FireServer("Attacks", "Slash", false)
            end)
        end
    end

    local REFILL_PLACES = {
        [13379349730] = { "Unclimbable", "Props", "HQ" }, [14012874501] = { "Unclimbable", "Props", "HQ" },
        [13904207646] = { "Climbable", "_Walls", "Gate" }, [14638336319] = { "Unclimbable", "Camps", "Camp" },
        [15220308770] = { "Climbable", "Utgard" }, [17688739434] = { "Unclimbable", "World", "Buildings", "Hanger" },
        [15824912319] = { "Unclimbable", "Props", "HQ" }, [126678335159530] = { "Unclimbable", "Reloads" },
    }
    local stations = nil

    local function collect(container)
        local list, n = {}, 0
        for _, d in ipairs(container:GetDescendants()) do
            n += 1
            if n % 500 == 0 then task.wait() end
            if d.Name == "Refill" then list[#list + 1] = d end
        end
        return list
    end

    local function posOf(inst)
        local ok, pos = pcall(function()
            if inst:IsA("BasePart") then return inst.Position end
            if inst:IsA("Model") then return inst:GetPivot().Position end
            local part = inst:FindFirstChildWhichIsA("BasePart", true)
            return part and part.Position or nil
        end)
        return ok and pos or nil
    end

    local function nearestStation(root)
        local valid = stations and #stations > 0
        if valid then
            for _, st in ipairs(stations) do if not st.Parent then valid = false break end end
        end
        if not valid then
            stations = {}
            local uncl = Workspace:FindFirstChild("Unclimbable")
            local obj = uncl and uncl:FindFirstChild("Objective")
            local waveFolder = obj and obj:FindFirstChild("Waves")
            if waveFolder then stations = collect(waveFolder) end
            if #stations == 0 then
                local container = Workspace
                local path = REFILL_PLACES[game.PlaceId]
                if path then
                    local cur = Workspace
                    for _, name in ipairs(path) do cur = cur and cur:FindFirstChild(name) end
                    if cur then container = cur end
                end
                stations = collect(container)
                if #stations == 0 and container ~= Workspace then stations = collect(Workspace) end
            end
        end
        local best, bestDist = nil, math.huge
        for _, st in ipairs(stations) do
            local pos = posOf(st)
            if pos then
                local d = (pos - root.Position).Magnitude
                if d < bestDist then best, bestDist = st, d end
            end
        end
        return best
    end

    local function rig() local char = player.Character return char and char:FindFirstChild("Rig_" .. player.Name) end

    local function bladeParts()
        local r = rig()
        local list = {}
        for _, handName in ipairs({ "RightHand", "LeftHand" }) do
            local hand = r and r:FindFirstChild(handName)
            for _, d in ipairs(hand and hand:GetChildren() or {}) do
                if d.Name:match("^Blade_%d+$") then list[#list + 1] = d end
            end
        end
        return list
    end

    local function allBroken()
        local parts = bladeParts()
        if #parts == 0 then return false end
        for _, p in ipairs(parts) do if not p:GetAttribute("Broken") then return false end end
        return true
    end

    RT.bladesEmpty = function()
        if allBroken() then return true end
        local seg = Farm.ActorSegments and Farm.ActorSegments()
        if seg == nil then
            local raw = player:GetAttribute("SH_Segments")
            seg = raw and tonumber(raw) or nil
        end
        return seg ~= nil and seg <= 0
    end

    RT.spearsLeft = function()
        local char = player.Character
        local n = char and char:GetAttribute("Spears")
        if type(n) == "number" then return n end
        return nil
    end

    local function spareLeft()
        local actorReloads = Farm.ActorReloads and Farm.ActorReloads()
        if actorReloads ~= nil then return actorReloads end
        local r = rig()
        local torso = r and r:FindFirstChild("LowerTorso")
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

    local function needBladeRaw()
        if not RT.bladesEmpty() then return false end
        local sp = spareLeft()
        if sp == 0 then return true end
        if sp == nil then return (Farm.ReloadRejects or 0) >= 2 or (Farm.BladesEmptyFor or 0) >= 5 end
        return false
    end
    local function needBlade() return Config.AutoRefillBlade and needBladeRaw() end
    local function needThunderRaw()
        local n = RT.spearsLeft()
        if n ~= nil and n <= 0 then return true end
        return Farm.SpearStuck == true
    end
    local function needThunder() return Config.AutoRefillThunder and needThunderRaw() end
    RT.refillsLeft = function()
        local n = player:GetAttribute("Refills")
        if type(n) == "number" then return n end
        return nil
    end

    local function tweenToPos(root, targetPos, speed)
        if not root or not targetPos then return end
        pcall(function() player:RequestStreamAroundAsync(targetPos, 0.5) end)
        local dist = (targetPos - root.Position).Magnitude
        local t = math.clamp(dist / (speed or Config.RefillSpeed), 0.1, 6)
        local ok, tw = pcall(function()
            return TweenService:Create(root, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.new(targetPos) })
        end)
        if not ok or not tw then pcall(function() root.CFrame = CFrame.new(targetPos) end) return end
        local vel = RunService.Heartbeat:Connect(function() pcall(function() root.AssemblyLinearVelocity = Vector3.zero end) end)
        tw:Play()
        local t0 = os.clock()
        while os.clock() - t0 < t + 0.3 and tw.PlaybackState == Enum.PlaybackState.Playing and Alive() do task.wait() end
        pcall(function() tw:Cancel() end)
        vel:Disconnect()
    end

    local function promptOf(station)
        local p = station:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not p and station.Parent then p = station.Parent:FindFirstChildWhichIsA("ProximityPrompt", true) end
        return p
    end
    local function promptPos(prompt, station)
        local par = prompt and prompt.Parent
        if par and par:IsA("BasePart") then return par.Position end
        if par and par:IsA("Attachment") then return par.WorldPosition end
        return posOf(station)
    end
    local function pressPrompt(prompt)
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
    local function pressR(prompt)
        local hold = (prompt and prompt.HoldDuration or 0) + 0.2
        pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game) end)
        task.wait(hold)
        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
    end
    local function promptCount(prompt)
        if not prompt then return nil end
        local txt = tostring(prompt.ObjectText or "") .. " " .. tostring(prompt.ActionText or "")
        local n = txt:match("(%d+)%s*/%s*%d+")
        return n and tonumber(n) or nil
    end

    do
        local token = tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999))
        local lastBeat, lastBeatAt = nil, 0
        local function Get(name) return player:GetAttribute(name) end
        local function fresh()
            local beat = Get("SH_Beat")
            if beat == nil or Get("SH_ActorToken") ~= token then return false end
            if beat ~= lastBeat then lastBeat, lastBeatAt = beat, os.clock() end
            return os.clock() - lastBeatAt < 2
        end
        Farm.ActorActive   = function() return fresh() end
        Farm.ActorSegments = function() if fresh() then return tonumber(Get("SH_Segments")) end return nil end
        Farm.ActorReloads  = function() if fresh() then return tonumber(Get("SH_Reloads")) end return nil end

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
            local beat = 0
            while LP:GetAttribute("SH_ActorToken") == TOKEN do
                task.wait(0.2)
                local loadout = Host.Loadout
                local supply  = loadout and loadout.Supply
                beat = beat + 1
                LP:SetAttribute("SH_Segments", supply and tonumber(supply.Segments))
                LP:SetAttribute("SH_Reloads",  supply and tonumber(supply.Reloads))
                LP:SetAttribute("SH_Beat",     beat)
            end
        ]==]

        local function supported()
            return type(getactors) == "function" and type(run_on_actor) == "function" and type(filtergc) == "function"
        end
        local function inject()
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
            if not supported() then print("[Casper][Actor] Executor sin getactors") return end
            local wasLinked, lastTry = false, -999
            while S.ui.gui and S.ui.gui.Parent and Alive() do
                task.wait(0.5)
                if fresh() then
                    if not wasLinked then wasLinked = true print("[Casper][Actor] Conectado") end
                else
                    if wasLinked then wasLinked = false print("[Casper][Actor] Señal perdida") end
                    local char = player.Character
                    if char and os.clock() - lastTry >= 5 then lastTry = os.clock() inject() end
                end
            end
        end)

        task.spawn(function()
            while S.ui.gui and S.ui.gui.Parent and Alive() do
                task.wait(0.25)
                pcall(function()
                    player:SetAttribute("SH_AutoReload", (Config.AutoRefillBlade or Config.AutoRefillThunder) and CanUseHere() and true or false)
                end)
            end
            pcall(function()
                player:SetAttribute("SH_ActorToken", nil)
                player:SetAttribute("SH_AutoReload", false)
            end)
        end)
    end

    local REFILL_TRIES, CHECK_WAIT = 2, 3
    local function markRefilled()
        Farm.RecentlyRefilled = os.clock() + 10
        Farm.ReloadRejects = 0
        Farm.ReloadSettleUntil = os.clock() + 3
    end

    local function doRefill()
        local ok0, post = pcall(function() return ReplicatedStorage.Assets.Remotes:WaitForChild("POST", 5) end)
        if not ok0 or not post then return false end
        local before = RT.refillsLeft()
        local function done()
            if not (needBlade() or needThunder()) then return true end
            local now = RT.refillsLeft()
            return before ~= nil and now ~= nil and now < before
        end
        local function waitDone(sec)
            local t0 = os.clock()
            while os.clock() - t0 < sec do
                if done() then return true end
                if not Alive() then return false end
                task.wait(0.2)
            end
            return done()
        end
        for _ = 1, REFILL_TRIES do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not (root and hum and hum.Health > 0) then break end
            local station = nearestStation(root)
            if not station then break end
            pcall(function() post:FireServer("Attacks", "Reload", station) end)
            if waitDone(2.5) then Farm.Refilling = false markRefilled() return true end
            local prompt = promptOf(station)
            local back = root.CFrame
            local pos = promptPos(prompt, station)
            Farm.Refilling = true
            if pos then
                tweenToPos(root, pos + Vector3.new(0, 3, 0), Config.RefillSpeed)
                task.wait(0.3)
            end
            if prompt then pressPrompt(prompt) else pressR(nil) end
            task.wait(0.4)
            pcall(function() post:FireServer("Attacks", "Reload", station) end)
            local okWait = waitDone(CHECK_WAIT)
            local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if r and back then tweenToPos(r, back.Position, Config.RefillSpeed) end
            Farm.Refilling = false
            if okWait then markRefilled() return true end
            Farm.ReloadRejects = (Farm.ReloadRejects or 0) + 1
        end
        Farm.Refilling = false
        return false
    end

    local function waveFolder()
        local u = Workspace:FindFirstChild("Unclimbable")
        local o = u and u:FindFirstChild("Objective")
        return o and o:FindFirstChild("Waves")
    end
    local function waveNeed()
        if Config.AutoRefillThunder then return needThunderRaw() end
        return needBladeRaw()
    end

    local function doWaveRefill()
        local folder = waveFolder()
        if not folder then return false end
        local list = collect(folder)
        local okP, post = pcall(function() return ReplicatedStorage.Assets.Remotes:FindFirstChild("POST") end)
        if not okP then post = nil end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not (root and hum and hum.Health > 0) then return false end
        local station, bestD = nil, math.huge
        for _, st in ipairs(list) do
            local pos = st.Parent and posOf(st)
            if pos then
                local d = (pos - root.Position).Magnitude
                if d < bestD then station, bestD = st, d end
            end
        end
        if not station then return false end
        local before = RT.refillsLeft()
        local function done()
            if not waveNeed() then return true end
            local now = RT.refillsLeft()
            return before ~= nil and now ~= nil and now < before
        end
        if post then
            pcall(function() post:FireServer("Attacks", "Reload", station) end)
            local t0 = os.clock()
            while os.clock() - t0 < 2.5 do
                if done() then Farm.Refilling = false markRefilled() return true end
                if not Alive() then return false end
                task.wait(0.2)
            end
        end
        local prompt = promptOf(station)
        local pos = promptPos(prompt, station)
        if not pos then return false end
        local success = false
        for attempt = 1, 3 do
            char = player.Character
            hum = char and char:FindFirstChildOfClass("Humanoid")
            root = char and char:FindFirstChild("HumanoidRootPart")
            if not (root and hum and hum.Health > 0) then break end
            local back = root.CFrame
            Farm.Refilling = true
            tweenToPos(root, pos + Vector3.new(0, 3, 0), Config.WaveSpeed)
            task.wait(0.2)
            local countBefore = promptCount(prompt)
            if attempt == 1 then
                if prompt then pressPrompt(prompt) else pressR(nil) end
            elseif attempt == 2 then
                pressR(prompt)
            elseif post then
                pcall(function() post:FireServer("Attacks", "Reload", station) end)
            end
            local t1 = os.clock()
            while os.clock() - t1 < 5 and waveNeed() and Alive() do task.wait(0.2) end
            local still = waveNeed()
            local countAfter = promptCount(prompt)
            if still and countBefore ~= nil and countAfter ~= nil and countAfter < countBefore then
                task.wait(2)
                still = waveNeed()
            end
            local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if r and back then tweenToPos(r, back.Position, Config.WaveSpeed) end
            Farm.Refilling = false
            if not still then success = true break end
        end
        Farm.Refilling = false
        if success then markRefilled() end
        return success
    end

    RT.pressButtonByName = function(name, exact)
        local found = nil
        for _, g in ipairs(playerGui:GetDescendants()) do
            if (g:IsA("TextButton") or g:IsA("TextLabel")) and g.Visible then
                local text = string.upper(g.Text or "")
                local match = exact and (text == name) or text:find(name, 1, true)
                if match then
                    local btn = g
                    while btn and btn ~= playerGui and not btn:IsA("GuiButton") do btn = btn.Parent end
                    if btn and btn:IsA("GuiButton") then found = btn break end
                end
            end
        end
        if not found then return false end
        pcall(function() if type(firesignal) == "function" then firesignal(found.MouseButton1Click) end end)
        pcall(function() if type(firesignal) == "function" then firesignal(found.Activated) end end)
        pcall(function()
            local pos = found.AbsolutePosition + found.AbsoluteSize / 2
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
        end)
        return true
    end

    local missionBusy = false
    local raidRemote, createdRoom = nil, nil

    local function getLobbyRemote()
        local ok, remote = pcall(function()
            local assets = ReplicatedStorage:WaitForChild("Assets", 5)
            local remotes = assets and assets:WaitForChild("Remotes", 5)
            return remotes and remotes:WaitForChild("GET", 5)
        end)
        return ok and remote or nil
    end

    RT.raidInvoke = function(...)
        if not raidRemote or not raidRemote.Parent then raidRemote = getLobbyRemote() end
        if not raidRemote then return false, "remote not found" end
        local remote = raidRemote
        local args = table.pack(...)
        local finished, ok, result = false, false, nil
        task.spawn(function()
            ok, result = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
            finished = true
        end)
        local t0 = os.clock()
        while not finished and os.clock() - t0 < 8 do task.wait(0.1) end
        if not finished then return false, "timeout" end
        return ok, result
    end

    local function myRoomObject()
        local folder = ReplicatedStorage:FindFirstChild("Missions")
        if not folder then return nil end
        for _, room in ipairs(folder:GetChildren()) do
            local leader = room:FindFirstChild("Leader")
            if leader and leader:IsA("ValueBase") and leader.Value == player.Name then return room end
        end
        return nil
    end
    local function hasRoom()
        if createdRoom and createdRoom.Parent ~= nil then return true end
        return myRoomObject() ~= nil
    end
    local function roomDifficulty(room)
        if typeof(room) ~= "Instance" then return nil end
        local okV, value = pcall(function() return room.Value end)
        if okV and type(value) == "string" then return value end
        return nil
    end

    RT.leaveRoom = function(silent)
        if not ON_LOBBY_PLACE then return false end
        local ok, r = RT.raidInvoke("S_Missions", "Leave")
        if not silent then S.notify("Raid", ok and "Leave sent" or ("Leave failed: " .. tostring(r)), 2) end
        return ok
    end

    RT.createRaidOnce = function(oneShot)
        if not ON_LOBBY_PLACE then S.notify("Raid", "No estás en el lobby", 2) return false end
        if missionBusy then S.notify("Raid", "Ocupado, espera un momento", 2) return false end
        missionBusy = true
        local info = RaidInfo(Config.RaidSelect)
        local diff = RaidDifficulty()
        S.notify("Raid", "Saliendo de la sala anterior...", 1)
        RT.leaveRoom(true)
        task.wait(0.6)
        if not oneShot and not Config.AutoCreateRaid then missionBusy = false return false end
        S.notify("Raid", ("Creando %s (%s)..."):format(info.name, diff), 2)
        local args = { Difficulty = diff, Type = "Raids", Objective = info.name, Name = info.map }
        if info.minimum then args.Minimum = info.minimum end
        local ok, r = RT.raidInvoke("S_Missions", "Create", args)
        if not ok then S.notify("Raid", "Create failed: " .. tostring(r), 3) missionBusy = false return false end
        if r == nil or r == false then
            RT.leaveRoom(true)
            S.notify("Raid", "Create rechazado (bloqueado o sin sala)", 3)
            missionBusy = false
            return false
        end
        local got = roomDifficulty(r)
        if got ~= nil and got ~= diff then
            RT.leaveRoom(true)
            S.notify("Raid", ("%s (%s) está bloqueado"):format(info.name, diff), 3)
            missionBusy = false
            return false
        end
        createdRoom = (typeof(r) == "Instance") and r or createdRoom
        local picked = {}
        for _, name in ipairs(RAID_MODIFIER_OPTIONS) do
            if table.find(Config.RaidModifiers, name) then picked[#picked + 1] = name end
        end
        for i, name in ipairs(picked) do
            S.notify("Raid", ("Modifier %d/%d: %s"):format(i, #picked, name), 1)
            local okM, rM = RT.raidInvoke("S_Missions", "Modify", name)
            if not okM then S.notify("Raid", "Modify failed: " .. tostring(rM), 3) missionBusy = false return false end
            task.wait(0.17)
            if not oneShot and not Config.AutoCreateRaid then missionBusy = false return false end
        end
        S.notify("Raid", ("Sala creada: %s / %s"):format(info.name, diff), 3)
        missionBusy = false
        return true
    end

    RT.startRaid = function()
        if not ON_LOBBY_PLACE then S.notify("Raid", "No estás en el lobby", 2) return false end
        if missionBusy then return false end
        missionBusy = true
        S.notify("Raid", "Iniciando raid...", 1)
        local ok, r = RT.raidInvoke("S_Missions", "Start")
        local note = ""
        if ok and type(r) == "string" and r ~= "" then note = " (" .. r .. ")" end
        local info = RaidInfo(Config.RaidSelect)
        if ok and info.minimum then note = note .. " | necesita " .. info.minimum .. "+ jugadores" end
        S.notify("Raid", ok and ("Start enviado" .. note) or ("Start failed: " .. tostring(r)), 3)
        missionBusy = false
        return ok
    end

    -- ==================== LOOPS ====================
    RT.farmLoop = function()
        task.wait(3)
        while S.ui.gui and S.ui.gui.Parent do
            local dt = RunService.Heartbeat:Wait()
            if Config.AutoFarm and not isRefilling then
                local root = getRoot(); local titan = getTitan()
                if root and titan then
                    local nape = napeOf(titan)
                    if nape then
                        local targetPos = nape.Position + Vector3.new(0, Config.FlyHeight, 0)
                        if (targetPos - root.Position).Magnitude > 6 then
                            local dir = (targetPos - root.Position).Unit
                            root.CFrame = root.CFrame + dir * (Config.FlySpeed * dt)
                        else
                            attackTitan(titan, root)
                            task.wait(0.15)
                        end
                    end
                end
            end
        end
    end

    RT.clickLoop = function()
        task.wait(3)
        local lastPress = 0
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.3)
            if Config.AutoRetry and os.clock() - lastPress > 1 then
                local found = nil
                for _, g in ipairs(playerGui:GetDescendants()) do
                    if g:IsA("TextLabel") or g:IsA("TextButton") then
                        local text = string.upper(g.Text or "")
                        if (text:match("^REINTENTAR") or text:match("^RETRY")) and g.Visible
                            and g.AbsoluteSize.X > 0 and g.AbsoluteSize.Y > 0 then
                            found = g; break
                        end
                    end
                end
                if found then
                    lastPress = os.clock()
                    local btn = found
                    if found:IsA("TextLabel") then
                        local p = found.Parent
                        for _ = 1, 4 do
                            if not p or p == playerGui then break end
                            if p:IsA("GuiButton") then btn = p; break end
                            p = p.Parent
                        end
                    end
                    pcall(function()
                        if type(firesignal) == "function" and btn:IsA("GuiButton") then
                            firesignal(btn.Activated); firesignal(btn.MouseButton1Click)
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

    RT.skillLoop = function()
        task.wait(3)
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(1)
            if Config.AutoSkill then
                if isMobile then
                    pcall(function()
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                        task.wait(0.05)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                    end)
                else
                    for _, key in ipairs({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }) do
                        pcall(function()
                            VirtualInputManager:SendKeyEvent(true, key, false, game)
                            task.wait(0.05)
                            VirtualInputManager:SendKeyEvent(false, key, false, game)
                        end)
                    end
                end
            end
        end
    end

    RT.refillLoop = function()
        task.wait(3)
        local lastRefill, since = -999, nil
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.4)
            local ok, err = pcall(function()
                local isWaveMode = Config.AutoRefillWave and waveFolder() ~= nil
                local needs = needBlade() or needThunder()
                if isWaveMode then since = nil return end
                if not (CanUseHere() and needs) then
                    since = nil
                    if Farm.Refilling and not isRefilling then Farm.Refilling = false end
                    return
                end
                since = since or os.clock()
                if os.clock() - since < 1.0 then return end
                if os.clock() - lastRefill < Config.RefillCooldown then return end
                local left = RT.refillsLeft()
                if left ~= nil and left <= 0 then
                    lastRefill = os.clock() - Config.RefillCooldown + 30
                    since = nil
                    return
                end
                Farm.Refilling = true; isRefilling = true
                local okRefill = doRefill()
                Farm.Refilling = false; isRefilling = false
                lastRefill = os.clock() - (okRefill and 0 or (Config.RefillCooldown - 3))
                since = nil
            end)
            if not ok then
                Farm.Refilling = false; isRefilling = false
                lastRefill = os.clock() - Config.RefillCooldown + 3
                warn("[Casper][Refill] error:", err)
                task.wait(1)
            end
        end
    end

    RT.waveLoop = function()
        task.wait(3)
        local since, lastWave, failStreak = nil, -999, 0
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.4)
            local ok, err = pcall(function()
                if not (Config.AutoRefillWave and waveFolder()) then since = nil failStreak = 0 return end
                if not CanUseHere() then since = nil return end
                if not waveNeed() then since = nil failStreak = 0 return end
                since = since or os.clock()
                if os.clock() - since < 1.0 then return end
                if os.clock() - lastWave < 10 then return end
                Farm.Refilling = true; isRefilling = true
                local okW = doWaveRefill()
                Farm.Refilling = false; isRefilling = false
                if okW then
                    failStreak = 0; lastWave = os.clock(); since = nil
                else
                    failStreak += 1
                    if failStreak >= 3 then lastWave = os.clock() + 20 failStreak = 0
                    else lastWave = os.clock() - 7 end
                    since = os.clock() - 1.5
                end
            end)
            if not ok then
                Farm.Refilling = false; isRefilling = false
                lastWave = os.clock() - 7
                warn("[Casper][WaveRefill] error:", err)
                task.wait(1)
            end
        end
    end

    RT.watchLoop = function()
        local emptyStart, wasEmpty, lastSpears, stuck = nil, false, nil, 0
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.1)
            if not Alive() then break end
            local empty = RT.bladesEmpty() == true
            if empty then
                emptyStart = emptyStart or os.clock()
                Farm.BladesEmptyFor = os.clock() - emptyStart
            else
                emptyStart = nil; Farm.BladesEmptyFor = 0
            end
            if wasEmpty and not empty then
                Farm.ReloadSettleUntil = os.clock() + 3
                Farm.ReloadRejects = 0
            end
            wasEmpty = empty
            if os.clock() % 1 < 0.1 then
                local n = RT.spearsLeft()
                local recently = os.clock() < (Farm.RecentlyRefilled or 0)
                if n == nil then
                    Farm.SpearStuck = false; lastSpears = nil; stuck = 0
                elseif n <= 0 then
                    Farm.SpearStuck = true; lastSpears = n; stuck = 0
                else
                    if Config.AutoFarm and lastSpears == n and not recently then
                        stuck += 1
                        Farm.SpearStuck = stuck >= 8
                    else
                        stuck = 0; Farm.SpearStuck = false
                    end
                    lastSpears = n
                end
            end
        end
    end

    RT.skipLoop = function()
        local function findSkip()
            for _, d in ipairs(playerGui:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
                    local t = string.upper(d.Text or "")
                    if t:match("^SKIP") and #t <= 14 then
                        local btn = d
                        while btn and btn ~= playerGui and not btn:IsA("GuiButton") do btn = btn.Parent end
                        if btn and btn:IsA("GuiButton") then return btn end
                    end
                end
            end
            return nil
        end
        local skipped, lastPress, lastChar, spawnedAt = 0, 0, nil, 0
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.4)
            if not Config.AutoSkipCutscene or IN_MENU then
                lastChar = nil
            else
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not (hum and hum.Health > 0) then
                    lastChar = nil
                else
                    if char ~= lastChar then lastChar, spawnedAt = char, os.clock() end
                    if os.clock() - spawnedAt >= 2 then
                        local btn = findSkip()
                        if btn and os.clock() - lastPress >= 1.5 then
                            lastPress = os.clock()
                            pcall(function()
                                if type(firesignal) == "function" then
                                    firesignal(btn.MouseButton1Click); firesignal(btn.Activated)
                                end
                            end)
                            pcall(function()
                                local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
                            end)
                            RT.pressKey(Enum.KeyCode.E, 0.05)
                            skipped += 1
                            S.notify("Auto Skip", ("Saltado x%d"):format(skipped), 1)
                        end
                    end
                end
            end
        end
    end

    RT.chestLoop = function()
        local function findOpen()
            for _, d in ipairs(playerGui:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
                    local t = string.upper(d.Text or "")
                    if t == "OPEN" or t == "ABRIR" or t:match("^OPEN%s*%(%d+%)$") or t:match("^ABRIR%s*%(%d+%)$") then
                        local btn = d
                        while btn and btn ~= playerGui and not btn:IsA("GuiButton") do btn = btn.Parent end
                        if btn and btn:IsA("GuiButton") then
                            local path = btn:GetFullName():lower()
                            local kind = "unknown"
                            if path:find("premium") then kind = "premium" elseif path:find("free") then kind = "free" end
                            return btn, kind
                        end
                    end
                end
            end
            return nil, nil
        end
        local function findFinish()
            for _, d in ipairs(playerGui:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
                    local t = string.upper(d.Text or "")
                    if t:match("^FINISH") or t:match("^FINALIZAR") or t:match("^TERMINAR") then
                        local btn = d
                        while btn and btn ~= playerGui and not btn:IsA("GuiButton") do btn = btn.Parent end
                        if btn and btn:IsA("GuiButton") then return btn end
                    end
                end
            end
            return nil
        end
        local lastPress, screenSince, lastAction = 0, nil, 0
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.7)
            if not (Config.AutoOpenChestFree or Config.AutoOpenChestPremium) then
                screenSince = nil
            else
                local btn, kind = findOpen()
                local okKind = (kind == "free" and Config.AutoOpenChestFree)
                    or (kind == "premium" and Config.AutoOpenChestPremium)
                    or (kind == "unknown" and (Config.AutoOpenChestFree or Config.AutoOpenChestPremium))
                if btn and okKind and os.clock() - lastPress >= 5 then
                    lastPress = os.clock(); lastAction = os.clock()
                    S.notify("Chest", "Abriendo cofre " .. kind, 1)
                    pcall(function()
                        if type(firesignal) == "function" then firesignal(btn.MouseButton1Click); firesignal(btn.Activated) end
                    end)
                else
                    local fin = findFinish()
                    if fin then
                        screenSince = screenSince or os.clock()
                        if Config.AutoFinishChest and os.clock() - math.max(lastAction, screenSince) >= 4 then
                            lastAction = os.clock()
                            S.notify("Chest", "Finalizando...", 1)
                            pcall(function()
                                if type(firesignal) == "function" then firesignal(fin.MouseButton1Click); firesignal(fin.Activated) end
                            end)
                        end
                    else
                        screenSince = nil
                    end
                end
            end
        end
    end

    RT.cannonLoop = function()
        local function cannonModel()
            local climb = Workspace:FindFirstChild("Climbable")
            for _, d in ipairs(climb and climb:GetDescendants() or {}) do
                if d.Name == "Cannons" and not d:IsA("BasePart") then
                    local m = d:FindFirstChildWhichIsA("Model")
                    if m then return m end
                end
            end
            return nil
        end
        local function colossalAlive()
            local titans = Workspace:FindFirstChild("Titans")
            local ct = titans and titans:FindFirstChild("Colossal_Titan")
            local hum = ct and ct:FindFirstChildOfClass("Humanoid")
            return (ct and hum and hum.Health > 0) and ct or nil
        end
        local function napePos()
            local ct = colossalAlive()
            if not ct then return nil end
            local hb = ct:FindFirstChild("Hitboxes")
            local hit = hb and hb:FindFirstChild("Hit")
            local nape = hit and hit:FindFirstChild("Nape")
            if nape and nape:IsA("BasePart") then return nape.Position end
            local fake = ct:FindFirstChild("Fake")
            local head = fake and fake:FindFirstChild("Head")
            return head and head:IsA("BasePart") and head.Position or nil
        end
        local conn, mounted = nil, nil
        local function disconnect()
            if conn then pcall(function() conn:Disconnect() end) conn = nil end
        end
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.2)
            local want = Config.AutoCannon and CanUseHere() and colossalAlive() ~= nil
            if not want then
                if mounted or conn then
                    disconnect()
                    local c = mounted; mounted = nil
                    if c then pcall(RT.raidInvoke, "Cannon", "State", c, false, nil) end
                end
            else
                local cannon = cannonModel()
                local okP, post = pcall(function() return ReplicatedStorage.Assets.Remotes.POST end)
                if cannon and okP and post then
                    if not conn then
                        conn = post.OnClientEvent:Connect(function(a1, a2, cannonObj)
                            if a1 ~= "Skills" or a2 ~= "Impact" then return end
                            if not Config.AutoCannon then return end
                            local ref = cannonObj or Workspace:FindFirstChild("Cannon")
                            if not ref then return end
                            for _ = 1, 30 do
                                local pos = napePos()
                                if pos then pcall(function() post:FireServer("S_Skills", "Impact", ref, pos) end) end
                            end
                        end)
                    end
                    pcall(RT.raidInvoke, "Cannon", "State", cannon, true, nil)
                    mounted = cannon
                    task.wait(0.3)
                    for _ = 1, 3 do
                        local ok = RT.raidInvoke("Cannon", "Shoot", { BarrelWood = 40, Base = 0 })
                        if ok then break end
                        task.wait(0.1)
                    end
                    task.wait(1.8)
                else
                    task.wait(1)
                end
            end
        end
        disconnect()
    end

    RT.autoCreateLoop = function()
        task.wait(4)
        local readyAt = os.clock() + 4
        local fails, nextTry = 0, 0
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.5)
            local now = os.clock()
            if ON_LOBBY_PLACE and Config.AutoCreateRaid and not missionBusy and now >= readyAt then
                if now >= nextTry and not hasRoom() then
                    if RT.createRaidOnce(false) then
                        fails = 0; nextTry = os.clock() + 20
                    else
                        fails += 1; nextTry = os.clock() + 8
                        if fails >= 3 then
                            fails = 0; Config.AutoCreateRaid = false
                            S.notify("Raid", "Auto Create detenido (3 fallos)", 3)
                            EventBus:Emit("ConfigChanged", "AutoCreateRaid", false)
                        end
                    end
                end
            end
        end
    end

    RT.autoStartLoop = function()
        task.wait(4)
        local lastFire = nil
        while S.ui.gui and S.ui.gui.Parent do
            task.wait(0.5)
            if not ON_LOBBY_PLACE or not Config.AutoStartRaid or not hasRoom() then
                lastFire = nil
            else
                local now = os.clock()
                local delay = math.clamp(Config.RaidJoinDelay or 10, 5, 60)
                if not lastFire then lastFire = now end
                if lastFire + delay - now <= 0 then
                    RT.startRaid()
                    lastFire = os.clock()
                end
            end
        end
    end

    -- Pánico y presets
    local TOGGLE_KEYS = {
        "AutoFarm", "AutoSkill", "AutoEscape", "AutoRetry", "AutoRefillBlade", "AutoRefillThunder",
        "AutoRefillWave", "AutoCreateRaid", "AutoStartRaid", "AutoSkipCutscene", "AutoOpenChestFree",
        "AutoOpenChestPremium", "AutoFinishChest", "AutoCannon", "MassiveAttack", "AutoPlay", "AutoCreateWave",
    }
    local function setFlags(map)
        for _, key in ipairs(TOGGLE_KEYS) do
            local v = map[key] == true
            if Config[key] ~= v then
                Config[key] = v
                EventBus:Emit("ConfigChanged", key, v)
            end
        end
    end
    RT.panic = function()
        setFlags({})
        S.notify("Pánico", "Todas las features apagadas", 2)
    end
    S.PRESETS = {
        { name = "Farm AFK", tip = "Farm, skill y refill automático", flags = { AutoFarm = true, AutoSkill = true, AutoRefillBlade = true, AutoRefillThunder = true, AutoEscape = true } },
        { name = "Wave grind", tip = "Refill de oleada + farm", flags = { AutoRefillWave = true, AutoFarm = true, AutoSkill = true, AutoEscape = true } },
        { name = "Raid solo", tip = "Prepara raid con skips y cofres", flags = { AutoSkipCutscene = true, AutoCannon = true, AutoOpenChestFree = true, AutoFinishChest = true } },
        { name = "Limpio", tip = "Apaga todo", flags = {} },
    }
    RT.applyPreset = function(preset)
        RT.panic()
        setFlags(preset.flags)
        S.notify("Preset", preset.name .. " aplicado", 2)
    end
end

-- ============================================================
-- 4) TABS
-- ============================================================
local function buildTabs(S)
    local H, V, RT, ui = S.H, S.V, S.RT, S.ui
    local tabs, tabByName = {}, {}
    S.tabs, S.tabByName = tabs, tabByName
    local contextControls = S.contextControls
    local groupHeaders, groupOrder = {}, { Combate = 1, Utilidad = 2, Sistema = 3 }
    S.groupHeaders = groupHeaders

    local typedName, selectedName, listDropdown = "", nil, nil
    local currentOptions = { "---" }

    local function isFavorite(name) return table.find(Config.Favorites, name) ~= nil end

    local function ensureHeader(name)
        if groupHeaders[name] then return groupHeaders[name] end
        local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = (groupOrder[name] or 9) * 1000, ZIndex = 8, Parent = ui.tabsScroll })
        H.label(holder, "micro", string.upper(name), { Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 1, 0), TextColor3 = V.mute, ZIndex = 9 })
        groupHeaders[name] = holder
        return holder
    end

    S.sortTabs = function()
        local ordered = {}
        for _, t in ipairs(tabs) do ordered[#ordered + 1] = t end
        table.sort(ordered, function(a, b)
            local ga, gb = groupOrder[a.group] or 9, groupOrder[b.group] or 9
            if ga ~= gb then return ga < gb end
            local fa, fb = isFavorite(a.name), isFavorite(b.name)
            if fa ~= fb then return fa end
            return a.name:lower() < b.name:lower()
        end)
        local counters = {}
        for _, t in ipairs(ordered) do
            local g = t.group or "Sistema"
            counters[g] = (counters[g] or 0) + 1
            t.button.LayoutOrder = (groupOrder[g] or 9) * 1000 + counters[g]
        end
    end

    local function setHighlight(lbl, query, accentHex)
        local base = lbl:GetAttribute("BaseText")
        if base == nil then base = lbl.Text; lbl:SetAttribute("BaseText", base) end
        if query == "" then lbl.RichText = false; lbl.Text = base; return end
        local s, e = base:lower():find(query, 1, true)
        if not s then lbl.RichText = false; lbl.Text = base; return end
        lbl.RichText = true
        lbl.Text = H.escapeRich(base:sub(1, s - 1)) .. '<font color="' .. accentHex .. '">'
            .. H.escapeRich(base:sub(s, e)) .. "</font>" .. H.escapeRich(base:sub(e + 1))
    end

    S.applySearch = function(query)
        query = (query or ""):lower()
        local accentHex = H.toHex(THEME.accent)
        local anyInGroup = {}
        for _, t in ipairs(tabs) do
            local matchTab = (query == "") or t.name:lower():find(query, 1, true) ~= nil
            local visible = 0
            for _, child in ipairs(t.page:GetChildren()) do
                if child:IsA("GuiObject") then
                    if query == "" then
                        child.Visible = true
                        visible += 1
                    else
                        local hit = false
                        for _, d in ipairs(child:GetDescendants()) do
                            if d:IsA("TextLabel") then
                                if (d:GetAttribute("BaseText") or d.Text):lower():find(query, 1, true) then hit = true end
                                setHighlight(d, query, accentHex)
                            end
                        end
                        if child:IsA("TextLabel") then
                            if (child:GetAttribute("BaseText") or child.Text):lower():find(query, 1, true) then hit = true end
                            setHighlight(child, query, accentHex)
                        end
                        child.Visible = hit
                        if hit then visible += 1 end
                    end
                end
            end
            t.button.Visible = matchTab or visible > 0
            if t.button.Visible then anyInGroup[t.group] = true end
        end
        for name, holder in pairs(groupHeaders) do holder.Visible = anyInGroup[name] == true end
        if query ~= "" and S.activeTab and not S.activeTab.button.Visible then
            for _, t in ipairs(tabs) do if t.button.Visible then S.selectTab(t) break end end
        end
    end

    S.buildPage = function(tab)
        for _, child in ipairs(tab.page:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
        end
        tab.order = 0
        tab.keys = {}
        if tab.buildFunc then tab.buildFunc(tab.api) end
        S.refreshContext()
    end

    S.selectTab = function(tab)
        if S.activeTab == tab then return end
        local prev = S.activeTab
        if prev then
            prev.page.Visible = false
            H.smooth(prev.button, 0.18, { BackgroundColor3 = V.card, BackgroundTransparency = 0.35 })
            H.smooth(prev.label, 0.18, { TextColor3 = V.sub })
            H.smooth(prev.indicator, 0.18, { Size = UDim2.fromOffset(3, 0) })
            H.smooth(prev.badge, 0.18, { BackgroundTransparency = 1 })
            prev.badgeText.TextTransparency = 1
        end
        S.activeTab = tab
        tab.page.Visible = true
        tab.page.Position = UDim2.fromOffset(16, 0)
        H.smooth(tab.page, 0.28, { Position = UDim2.fromOffset(0, 0) })
        H.smooth(tab.button, 0.18, { BackgroundColor3 = THEME.accent, BackgroundTransparency = 0.78 })
        H.smooth(tab.label, 0.18, { TextColor3 = V.text })
        H.smooth(tab.indicator, 0.18, { Size = UDim2.fromOffset(3, 20) })
        ui.pageTitle.Text = tab.name
        ui.pageSub.Text = tab.subtitle or ""
        Config.UIActiveTab = tab.name
        if not tab.loaded then tab.loaded = true; S.buildPage(tab) end
        EventBus:Emit("TabChanged", tab.name)
    end

    S.addTab = function(name, group, iconKind, subtitle, buildFunc)
        ensureHeader(group)
        local button = new("TextButton", { Text = "", BackgroundColor3 = V.card, BackgroundTransparency = 0.35, Size = UDim2.new(1, 0, 0, 36), AutoButtonColor = false, LayoutOrder = #tabs + 1, ZIndex = 8, Parent = ui.tabsScroll }, { corner(9) })
        H.stroke(button, V.strokeHi, 1, 0.5)
        button.MouseEnter:Connect(function() if S.activeTab and S.activeTab.button ~= button then H.smooth(button, 0.15, { BackgroundColor3 = V.cardHi }) end end)
        button.MouseLeave:Connect(function() if S.activeTab and S.activeTab.button ~= button then H.smooth(button, 0.15, { BackgroundColor3 = V.card, BackgroundTransparency = 0.35 }) end end)
        H.ripple(button)

        local iconHolder = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(11, 10), BackgroundTransparency = 1, ZIndex = 9, Parent = button })
        H.icon(iconHolder, iconKind, V.sub, 16)

        local lbl = H.label(button, "body", name, { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -84, 1, 0), TextColor3 = V.sub, ZIndex = 9 })
        local indicator = new("Frame", { Size = UDim2.fromOffset(3, 0), Position = UDim2.new(0, 0, 0.5, -10), BackgroundColor3 = THEME.accent, BorderSizePixel = 0, ZIndex = 9, Parent = button }, { corner(2) }); H.bindAccent(indicator, "BackgroundColor3")

        local star = new("TextButton", { Text = isFavorite(name) and "★" or "☆", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = isFavorite(name) and THEME.accent or V.mute, BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 36), Position = UDim2.new(1, -48, 0, 0), AutoButtonColor = false, ZIndex = 10, Parent = button })
        star.MouseButton1Click:Connect(function()
            local idx = table.find(Config.Favorites, name)
            if idx then table.remove(Config.Favorites, idx) else table.insert(Config.Favorites, name) end
            star.Text = idx and "☆" or "★"
            star.TextColor3 = idx and V.mute or THEME.accent
            S.sortTabs()
        end)

        local badge = new("Frame", { Size = UDim2.fromOffset(20, 13), Position = UDim2.new(1, -25, 0.5, -6), BackgroundColor3 = V.ok, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9, Parent = button }, { corner(6) })
        local badgeText = H.label(badge, "micro", "ON", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = V.bg1, ZIndex = 10 })
        badgeText.TextTransparency = 1

        local page = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = V.cardHi, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false, ZIndex = 8, Parent = ui.pagesHolder }, { new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }), new("UIPadding", { PaddingBottom = UDim.new(0, 10) }) })

        local tab = { name = name, group = group, subtitle = subtitle, button = button, label = lbl, indicator = indicator, star = star, badge = badge, badgeText = badgeText, page = page, order = 0, keys = {}, loaded = false, buildFunc = buildFunc }
        tabByName[name] = tab

        local api = {}
        local function row(height, transparent)
            tab.order += 1
            local f = new("Frame", { Size = UDim2.new(1, 0, 0, height or 38), BackgroundColor3 = V.card, BackgroundTransparency = transparent and 1 or 0.18, BorderSizePixel = 0, LayoutOrder = tab.order, ZIndex = 9, Parent = page }, { corner(9) })
            if not transparent then H.stroke(f, V.strokeHi, 1, 0.45) end
            return f
        end
        local function rowLabel(parent, text, size)
            return H.label(parent, "body", text, { Position = UDim2.fromOffset(13, 0), Size = size or UDim2.new(1, -78, 0, 38), TextColor3 = V.text, ZIndex = 10 })
        end
        local function markKey(key) tab.keys[key] = true end
        local function regContext(obj, requires)
            if requires then contextControls[#contextControls + 1] = { obj = obj, requires = requires } end
        end

        function api.Section(text)
            tab.order += 1
            local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = tab.order, ZIndex = 9, Parent = page })
            local dot = new("Frame", { Size = UDim2.fromOffset(5, 5), Position = UDim2.new(0, 2, 0.5, -2), BackgroundColor3 = THEME.accent, BorderSizePixel = 0, ZIndex = 9, Parent = holder }, { corner(3) }); H.bindAccent(dot, "BackgroundColor3")
            H.label(holder, "micro", string.upper(text), { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 210, 1, 0), TextColor3 = V.mute, ZIndex = 10 })
            new("Frame", { Size = UDim2.new(1, -230, 0, 1), Position = UDim2.fromOffset(230, 0), BackgroundColor3 = V.strokeHi, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 9, Parent = holder })
        end

        function api.Toggle(text, key, callback, opts)
            if type(opts) == "string" then opts = { tip = opts } end
            opts = opts or {}
            markKey(key)
            local f = row(40); rowLabel(f, text)
            local state = Config[key] and true or false
            local btn = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -58, 0.5, -11), BackgroundColor3 = V.track, BorderSizePixel = 0, ZIndex = 10, Parent = f }, { corner(11) })
            H.stroke(btn, V.strokeHi, 1, 0.6)
            local knob = new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11, Parent = btn }, { corner(9) })
            H.stroke(knob, Color3.fromRGB(200, 200, 220), 1, 0.5)
            if opts.tip then H.tip(btn, opts.tip) end
            local function render(anim)
                local on = state
                if anim then
                    H.smooth(btn, 0.18, { BackgroundColor3 = on and THEME.accent or V.stroke })
                    H.smooth(knob, 0.18, { Position = on and UDim2.fromOffset(23, 2) or UDim2.fromOffset(2, 2) })
                else
                    btn.BackgroundColor3 = on and THEME.accent or V.stroke
                    knob.Position = on and UDim2.fromOffset(23, 2) or UDim2.fromOffset(2, 2)
                end
            end
            render(false)
            btn.MouseButton1Click:Connect(function()
                state = not state; Config[key] = state; render(true)
                if callback then task.spawn(callback, state) end
                EventBus:Emit("ConfigChanged", key, state)
            end)
            local unsub = EventBus:On("ConfigChanged", function(k, v)
                if k == key and v ~= state then state = v render(true) end
            end)
            regContext(btn, opts.requires)
            return {
                set = function(v) state = v and true or false; Config[key] = state; render(true); EventBus:Emit("ConfigChanged", key, state) end,
                get = function() return state end,
                destroy = function() if unsub then unsub() end end,
            }
        end

        function api.Slider(text, min, max, key, callback)
            markKey(key)
            local f = row(60)
            rowLabel(f, text, UDim2.new(1, -78, 0, 26))
            local current = tonumber(Config[key]) or min
            local valueLabel = new("TextLabel", { Text = tostring(current), Font = S.TYPO.micro.font, TextSize = S.TYPO.micro.size, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = THEME.accent, BackgroundTransparency = 0.15, Position = UDim2.new(1, -68, 0, 4), Size = UDim2.fromOffset(56, 20), ZIndex = 10, Parent = f }, { corner(6) }); H.bindAccent(valueLabel, "BackgroundColor3")
            local bar = new("Frame", { Size = UDim2.new(1, -26, 0, 6), Position = UDim2.new(0, 13, 0, 40), BackgroundColor3 = V.track, BorderSizePixel = 0, ZIndex = 10, Parent = f }, { corner(3) })
            local alpha0 = (current - min) / math.max(max - min, 0.001)
            local fill = new("Frame", { Size = UDim2.fromScale(alpha0, 1), BorderSizePixel = 0, ZIndex = 11, Parent = bar }, { corner(3) }); H.bindAccent(fill, "BackgroundColor3")
            local thumb = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(alpha0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 12, Parent = bar }, { corner(7) })
            local thumbStroke = H.stroke(thumb, THEME.accent, 2, 0); H.bindAccent(thumbStroke, "Color")
            local drag, lastCall = false, 0
            local function update(x, force)
                local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
                local value = math.floor(min + (max - min) * alpha + 0.5)
                fill.Size = UDim2.fromScale(alpha, 1)
                thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
                valueLabel.Text = tostring(value)
                Config[key] = value
                if force or os.clock() - lastCall > 0.05 then
                    lastCall = os.clock()
                    if callback then task.spawn(callback, value) end
                    EventBus:Emit("ConfigChanged", key, value)
                end
            end
            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    drag = true; update(input.Position.X, true)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and drag then
                    update(input.Position.X, true); drag = false
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input.Position.X) end
            end)
            local unsub = EventBus:On("ConfigChanged", function(k, v)
                if k ~= key or drag or type(v) ~= "number" then return end
                local a = math.clamp((v - min) / math.max(max - min, 0.001), 0, 1)
                fill.Size = UDim2.fromScale(a, 1); thumb.Position = UDim2.new(a, 0, 0.5, 0); valueLabel.Text = tostring(v)
            end)
            return {
                set = function(v)
                    v = math.clamp(tonumber(v) or min, min, max)
                    local a = math.clamp((v - min) / math.max(max - min, 0.001), 0, 1)
                    fill.Size = UDim2.fromScale(a, 1); thumb.Position = UDim2.new(a, 0, 0.5, 0); valueLabel.Text = tostring(v)
                    Config[key] = v; EventBus:Emit("ConfigChanged", key, v)
                end,
                get = function() return Config[key] end,
                destroy = function() if unsub then unsub() end end,
            }
        end

        function api.Button(text, callback, opts)
            if type(opts) == "boolean" then opts = { dangerous = opts } end
            opts = opts or {}
            local f = row(38, true)
            local b = new("TextButton", { Text = text, Font = S.TYPO.h2.font, TextSize = S.TYPO.h2.size - 1, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = opts.dangerous and V.bad or V.card, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), AutoButtonColor = false, ZIndex = 10, Parent = f }, { corner(9) })
            H.stroke(b, opts.dangerous and V.bad or THEME.accent, 1.2, opts.dangerous and 0.2 or 0.45)
            b.MouseEnter:Connect(function() H.smooth(b, 0.15, { BackgroundColor3 = opts.dangerous and Color3.fromRGB(255, 100, 130) or V.cardHi }) end)
            b.MouseLeave:Connect(function() H.smooth(b, 0.15, { BackgroundColor3 = opts.dangerous and V.bad or V.card }) end)
            if opts.tip then H.tip(b, opts.tip) end
            H.ripple(b)
            b.MouseButton1Click:Connect(function()
                if not b.Active then return end
                task.spawn(callback)
            end)
            regContext(b, opts.requires)
            return { set = function(t) b.Text = t end, get = function() return b end }
        end

        function api.Preset(text, tip, apply)
            local f = row(34, true)
            local b = new("TextButton", { Text = text, Font = S.TYPO.body.font, TextSize = S.TYPO.body.size, TextColor3 = V.text, BackgroundColor3 = V.card, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), AutoButtonColor = false, ZIndex = 10, Parent = f }, { corner(8) })
            H.stroke(b, V.strokeHi, 1, 0.4)
            b.MouseEnter:Connect(function() H.smooth(b, 0.15, { BackgroundColor3 = V.cardHi }) end)
            b.MouseLeave:Connect(function() H.smooth(b, 0.15, { BackgroundColor3 = V.card }) end)
            if tip then H.tip(b, tip) end
            b.MouseButton1Click:Connect(function() task.spawn(apply) end)
            return b
        end

        function api.Dropdown(text, options, key, callback)
            markKey(key)
            tab.order += 1
            local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = V.card, BackgroundTransparency = 0.18, BorderSizePixel = 0, LayoutOrder = tab.order, ZIndex = 9, Parent = page }, { corner(9), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
            H.stroke(holder, V.strokeHi, 1, 0.45)
            local headerBtn = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 10, Parent = holder })
            rowLabel(headerBtn, text, UDim2.new(1, -78, 0, 40))
            local current = Config[key] or options[1]
            local curLabel = new("TextLabel", { Text = tostring(current) .. "  ▾", Font = S.TYPO.caption.font, TextSize = S.TYPO.caption.size, TextColor3 = V.sub, TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1, Position = UDim2.new(1, -168, 0, 0), Size = UDim2.fromOffset(156, 40), ZIndex = 10, Parent = headerBtn })
            local list = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, LayoutOrder = 1, ZIndex = 11, Parent = holder }, { new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }), new("UIPadding", { PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }) })

            local function buildOptions(opts)
                for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                for i, opt in ipairs(opts) do
                    local ob = new("TextButton", { Text = opt, Font = S.TYPO.body.font, TextSize = S.TYPO.body.size, TextColor3 = V.text, BackgroundColor3 = V.bg1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 32), AutoButtonColor = false, LayoutOrder = i, ZIndex = 12, Parent = list }, { corner(6) })
                    ob.MouseEnter:Connect(function() H.smooth(ob, 0.1, { BackgroundColor3 = V.cardHi }) end)
                    ob.MouseLeave:Connect(function() H.smooth(ob, 0.1, { BackgroundColor3 = V.bg1 }) end)
                    ob.MouseButton1Click:Connect(function()
                        current = opt; Config[key] = opt; curLabel.Text = opt .. "  ▾"; list.Visible = false
                        if callback then task.spawn(callback, opt) end
                        EventBus:Emit("ConfigChanged", key, opt)
                    end)
                end
            end
            buildOptions(options)
            headerBtn.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
            local unsub = EventBus:On("ConfigChanged", function(k, v)
                if k == key and type(v) == "string" and v ~= current then current = v; curLabel.Text = v .. "  ▾" end
            end)
            return {
                set = function(v) current = v; Config[key] = v; curLabel.Text = tostring(v) .. "  ▾"; EventBus:Emit("ConfigChanged", key, v) end,
                get = function() return current end,
                refresh = function(newOpts) buildOptions(newOpts) end,
                destroy = function() if unsub then unsub() end end,
            }
        end

        function api.Checkbox(text, listName, value, callback)
            local f = row(34, true)
            local checked = table.find(Config[listName], value) ~= nil
            local box = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(13, 8), BackgroundColor3 = checked and THEME.accent or V.track, BorderSizePixel = 0, ZIndex = 10, Parent = f }, { corner(5) })
            H.stroke(box, V.strokeHi, 1, 0.5)
            local tick = H.label(box, "micro", "✓", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = V.bg1, ZIndex = 11 })
            tick.TextTransparency = checked and 0 or 1
            H.label(f, "body", text, { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -52, 1, 0), TextColor3 = V.text, ZIndex = 10 })
            box.MouseButton1Click:Connect(function()
                local idx = table.find(Config[listName], value)
                if idx then table.remove(Config[listName], idx) else table.insert(Config[listName], value) end
                checked = not checked
                H.smooth(box, 0.12, { BackgroundColor3 = checked and THEME.accent or V.track })
                tick.TextTransparency = checked and 0 or 1
                if callback then task.spawn(callback, checked) end
                EventBus:Emit("ConfigChanged", listName, Config[listName])
            end)
            return box
        end

        function api.Label(text, height)
            local f = row(height or 24, true)
            local l = H.label(f, "caption", text, { Position = UDim2.fromOffset(13, 0), Size = UDim2.new(1, -15, 1, 0), TextColor3 = V.sub, TextWrapped = true, TextYAlignment = height and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center, ZIndex = 10 })
            return { set = function(t) l.Text = t end }
        end

        function api.Stat(text)
            local f = row(26, true)
            H.label(f, "caption", text, { Position = UDim2.fromOffset(13, 0), Size = UDim2.new(1, -110, 1, 0), TextColor3 = V.sub, ZIndex = 10 })
            local value = H.label(f, "body", "—", { Position = UDim2.new(1, -100, 0, 0), Size = UDim2.fromOffset(88, 26), TextColor3 = V.text, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10 })
            return { set = function(v) value.Text = tostring(v) end, raw = value }
        end

        function api.TextBox(placeholder, key, callback)
            markKey(key)
            local f = row(40)
            local tb = new("TextBox", { Text = Config[key] or "", PlaceholderText = placeholder or "", Font = S.TYPO.body.font, TextSize = S.TYPO.body.size, TextColor3 = V.text, PlaceholderColor3 = V.mute, BackgroundColor3 = V.bg1, BorderSizePixel = 0, Position = UDim2.fromOffset(7, 6), Size = UDim2.new(1, -14, 0, 28), ZIndex = 10, Parent = f }, { corner(7) })
            local tbStroke = H.stroke(tb, V.strokeHi, 1, 0.3)
            tb.Focused:Connect(function() H.smooth(tbStroke, 0.15, { Color = THEME.accent, Transparency = 0 }) end)
            tb.FocusLost:Connect(function()
                H.smooth(tbStroke, 0.15, { Color = V.strokeHi, Transparency = 0.3 })
                Config[key] = tb.Text
                if callback then task.spawn(callback, tb.Text) end
                EventBus:Emit("ConfigChanged", key, tb.Text)
            end)
            return tb
        end

        function api.ColorPicker(text, key, callback)
            local PRESETS = { "#8A5CFF", "#00C8F0", "#28DC82", "#F04664", "#FF9632", "#FF46B4", "#FFFFFF", "#B0B8D0", "#FFD166", "#4ADE80", "#60A5FA", "#F472B6" }
            local f = row(84)
            rowLabel(f, text, UDim2.new(1, -108, 0, 22))
            local hexBox = new("TextBox", { Text = Config[key] or "#FFFFFF", Font = S.TYPO.micro.font, TextSize = S.TYPO.micro.size + 1, TextColor3 = V.text, BackgroundColor3 = V.bg1, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(1, -94, 0, 0), Size = UDim2.fromOffset(86, 22), ZIndex = 10, Parent = f }, { corner(6) })
            local hexStroke = H.stroke(hexBox, V.strokeHi, 1, 0.3)
            local grid = new("Frame", { Size = UDim2.new(1, -26, 0, 52), Position = UDim2.fromOffset(13, 26), BackgroundTransparency = 1, ZIndex = 9, Parent = f }, { new("UIGridLayout", { CellSize = UDim2.fromOffset(23, 23), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = 9 }) })
            local function apply(hex)
                local c = H.hex(hex)
                if not c then return false end
                Config[key] = H.toHex(c)
                hexBox.Text = Config[key]
                if callback then task.spawn(callback, Config[key]) end
                EventBus:Emit("ConfigChanged", key, Config[key])
                return true
            end
            for i, hex in ipairs(PRESETS) do
                local sw = new("TextButton", { Text = "", BackgroundColor3 = H.hex(hex), BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i, ZIndex = 10, Parent = grid }, { corner(5) })
                H.stroke(sw, V.strokeHi, 1, 0.5)
                sw.MouseButton1Click:Connect(function() apply(hex) end)
            end
            hexBox.Focused:Connect(function() H.smooth(hexStroke, 0.15, { Color = THEME.accent, Transparency = 0 }) end)
            hexBox.FocusLost:Connect(function()
                H.smooth(hexStroke, 0.15, { Color = V.strokeHi, Transparency = 0.3 })
                if not apply(hexBox.Text) then hexBox.Text = Config[key] or "#FFFFFF" end
            end)
            return { set = apply, get = function() return Config[key] end }
        end

        function api.Empty(text)
            local f = row(52, true)
            H.label(f, "caption", text, { Size = UDim2.fromScale(1, 1), TextColor3 = V.mute, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 10 })
            return f
        end

        tab.api = api
        button.MouseButton1Click:Connect(function() S.selectTab(tab) end)
        tabs[#tabs + 1] = tab
        S.sortTabs()
        return tab
    end

    -- Reset de tab
    ui.resetBtn.MouseButton1Click:Connect(function()
        local tab = S.activeTab
        if not tab then return end
        local defaults = ConfigStore.Get(ConfigStore.DEFAULT_NAME)
        if not defaults or not defaults.Cfg then return end
        local n = 0
        for key in pairs(tab.keys) do
            if defaults.Cfg[key] ~= nil and Config[key] ~= nil and type(Config[key]) == type(defaults.Cfg[key]) then
                Config[key] = defaults.Cfg[key]
                n += 1
            end
        end
        S.buildPage(tab)
        S.notify("Tab restablecido", tab.name .. " · " .. n .. " valores", 2)
    end)

    ui.searchInput:GetPropertyChangedSignal("Text"):Connect(function() S.applySearch(ui.searchInput.Text) end)

    ui.collapseBtn.MouseButton1Click:Connect(function()
        Config.UICollapsed = not Config.UICollapsed
        local w = Config.UICollapsed and S.SIDEBAR_MINI or S.SIDEBAR_FULL
        H.smooth(ui.sidebar, 0.22, { Size = UDim2.new(0, w, 1, -128) })
        H.smooth(ui.content, 0.22, { Position = UDim2.fromOffset(w + 22, 74) })
        H.smooth(ui.content, 0.22, { Size = UDim2.new(1, -w - 26, 1, -128) })
        ui.collapseBtn.Text = Config.UICollapsed and "»" or "«"
        ui.searchBox.Visible = not Config.UICollapsed
        ui.tabsScroll.Position = UDim2.fromOffset(0, Config.UICollapsed and 8 or 52)
        ui.tabsScroll.Size = UDim2.new(1, 0, 1, Config.UICollapsed and -44 or -76)
        for _, t in ipairs(tabs) do
            t.label.Visible = not Config.UICollapsed
            t.star.Visible = not Config.UICollapsed
            t.badge.Visible = not Config.UICollapsed
            t.iconHolder.Position = UDim2.fromOffset(Config.UICollapsed and 15 or 11, 10)
        end
        for _, h in pairs(groupHeaders) do h.Visible = not Config.UICollapsed end
    end)

    -- ==================== CONTENIDO DE TABS ====================
    S.addTab("Inicio", "Combate", "home", "Resumen y presets", function(api)
        api.Section("Sesión")
        local placeStat = api.Stat("Place")
        local ctxStat = api.Stat("Contexto")
        local upStat = api.Stat("Tiempo activo")
        local actorStat = api.Stat("Enlace actor")
        api.Section("Recursos")
        local refStat = api.Stat("Refills")
        local bladeStat = api.Stat("Blades")
        local spearStat = api.Stat("Spears")
        local titanStat = api.Stat("Titanes")
        api.Section("Presets")
        for _, p in ipairs(S.PRESETS) do
            api.Preset(p.name, p.tip, function() RT.applyPreset(p) end)
        end
        api.Section("Control")
        api.Button("Apagar todo (pánico)", function() RT.panic() end, { dangerous = true })
        S.dash = { place = placeStat, ctx = ctxStat, uptime = upStat, actor = actorStat, refills = refStat, blades = bladeStat, spears = spearStat, titans = titanStat }
    end)

    S.addTab("Farm", "Combate", "farm", "Automatización y combate", function(api)
        api.Section("Automatización")
        api.Toggle("Auto Farm", "AutoFarm", function(s) S.notify("Auto Farm", s and "Activado" or "Desactivado", 2) end, { requires = "game", tip = "Vuela al titán más cercano y ataca la nuca" })
        api.Toggle("Auto Skill", "AutoSkill", function(s) S.notify("Auto Skill", s and "Activado" or "Desactivado", 2) end, { requires = "game", tip = "Pulsa las skills 1-5 en bucle" })
        api.Section("Ajustes de vuelo")
        api.Slider("Velocidad", 100, 1500, "FlySpeed")
        api.Slider("Altura", 50, 500, "FlyHeight")
        api.Section("Combate")
        api.Toggle("Ataque Masivo Aéreo", "MassiveAttack", function(s) S.notify("Ataque Masivo", s and "Activado" or "Desactivado", 2) end, { requires = "game", tip = "Golpea varios titanes cercanos a la vez" })
        api.Slider("Daño Multiplicado", 1, 20, "DamageMult")
        api.Slider("Titanes por ataque", 1, 15, "HitCount")
    end)

    S.addTab("Wave", "Combate", "wave", "Refill en oleadas", function(api)
        api.Section("Refill en Wave")
        api.Toggle("Auto Refill Wave", "AutoRefillWave", function(s) S.notify("Refill Wave", s and "Activado" or "Desactivado", 2) end, { requires = "game", tip = "Repone en estaciones de oleada" })
        api.Slider("Velocidad Refill Wave", 100, 2000, "WaveSpeed")
        api.Section("Ajustes")
        api.Dropdown("Mapa", { "Trost", "Shiganshina", "Utgard" }, "WaveMap")
        api.Label("Se ejecuta junto a Auto Create Wave.")
    end)

    S.addTab("Raid", "Combate", "raid", "Modo raid y cofres", function(api)
        api.Section("Selección de Raid")
        api.Dropdown("Raid", RAID_NAMES, "RaidSelect", function(option)
            local info = RaidInfo(option)
            if not table.find(info.diffs, Config.RaidLevel) then
                Config.RaidLevel = info.diffs[#info.diffs]
                EventBus:Emit("ConfigChanged", "RaidLevel", Config.RaidLevel)
            end
            if difficultyDropdown then difficultyDropdown.refresh(info.diffs) end
            S.notify("Raid", "Raid: " .. option, 2)
        end)
        local difficultyDropdown
        difficultyDropdown = api.Dropdown("Dificultad", RaidInfo(Config.RaidSelect).diffs, "RaidLevel", function(option)
            if not table.find(RaidInfo(Config.RaidSelect).diffs, option) then
                S.notify("Raid", "Dificultad no disponible para " .. Config.RaidSelect, 2)
            end
        end)
        api.Section("Modifiers")
        local modsHolder = api.Label("", 0)
        for _, name in ipairs(RAID_MODIFIER_OPTIONS) do
            api.Checkbox(name, "RaidModifiers", name, function()
                local n = #Config.RaidModifiers
                modsHolder.set(n > 0 and ("Activos: " .. n) or "Sin modifiers")
            end)
        end
        api.Button("Borrar todos los modifiers", function()
            Config.RaidModifiers = {}
            S.buildPage(tabByName["Raid"])
            S.notify("Raid", "Modifiers borrados", 2)
        end)
        api.Section("Auto Raid")
        api.Toggle("Auto Create Raid", "AutoCreateRaid", function(s)
            if s then Config.AutoStartRaid = false; EventBus:Emit("ConfigChanged", "AutoStartRaid", false) end
            S.notify("Raid", "Auto Create: " .. (s and "ON" or "OFF"), 2)
        end, { requires = "lobby", tip = "Crea la raid seleccionada al entrar al lobby" })
        api.Toggle("Auto Start Raid", "AutoStartRaid", function(s)
            if s then Config.AutoCreateRaid = false; EventBus:Emit("ConfigChanged", "AutoCreateRaid", false) end
            S.notify("Raid", "Auto Start: " .. (s and "ON" or "OFF"), 2)
        end, { requires = "lobby", tip = "Inicia la sala tras el retardo" })
        api.Slider("Join Delay (s)", 5, 60, "RaidJoinDelay")
        api.Section("Acciones manuales")
        api.Button("Crear Raid ahora", function()
            if not ON_LOBBY_PLACE then S.notify("Raid", "Entra al lobby", 2) return end
            RT.createRaidOnce(true)
        end, { requires = "lobby" })
        api.Button("Iniciar Raid ahora", function()
            if not ON_LOBBY_PLACE then S.notify("Raid", "Entra al lobby", 2) return end
            RT.startRaid()
        end, { requires = "lobby" })
        api.Button("Salir de la sala", function()
            if not ON_LOBBY_PLACE then S.notify("Raid", "Entra al lobby", 2) return end
            RT.leaveRoom(false)
        end, { requires = "lobby" })
        api.Section("Extras de Raid")
        api.Toggle("Auto Skip Cutscene", "AutoSkipCutscene", function(s) S.notify("Auto Skip", s and "ON" or "OFF", 2) end, { tip = "Pulsa SKIP [E] al empezar" })
        api.Toggle("Auto Open Chest (Free)", "AutoOpenChestFree", function(s) S.notify("Chest Free", s and "ON" or "OFF", 2) end)
        api.Toggle("Auto Open Chest (Premium)", "AutoOpenChestPremium", function(s) S.notify("Chest Premium", s and "ON" or "OFF", 2) end)
        api.Toggle("Auto Finish Chest", "AutoFinishChest", function(s) S.notify("Chest Finish", s and "ON" or "OFF", 2) end)
        api.Toggle("Auto Cannon (Colossal)", "AutoCannon", function(s) S.notify("Cannon", s and "ON" or "OFF", 2) end, { requires = "game" })
        api.Section("Info")
        api.Label("Raid: " .. Config.RaidSelect .. " · " .. RaidDifficulty())
        api.Label("Modifiers: " .. (#Config.RaidModifiers > 0 and table.concat(Config.RaidModifiers, ", ") or "ninguno"))
    end)

    S.addTab("Auto Click", "Utilidad", "click", "Clicks automáticos", function(api)
        api.Section("Ajustes")
        api.Toggle("Auto Click", "AutoRetry", function(s) S.notify("Auto Click", s and "Activado" or "Desactivado", 2) end, { requires = "game", tip = "Pulsa REINTENTAR / RETRY solo" })
        api.Label("Busca botones de reintento en la interfaz del juego.")
    end)

    S.addTab("Refill", "Utilidad", "refill", "Relleno de equipo", function(api)
        api.Section("Relleno automático")
        api.Toggle("Auto Refill Blades", "AutoRefillBlade", function(s) S.notify("Refill Blades", s and "Activado" or "Desactivado", 2) end, { requires = "game" })
        api.Toggle("Auto Refill Thunder", "AutoRefillThunder", function(s) S.notify("Refill Thunder", s and "Activado" or "Desactivado", 2) end, { requires = "game" })
        api.Section("Ajustes")
        api.Slider("Cooldown refill", 1, 30, "RefillCooldown")
        api.Slider("Velocidad refill", 100, 2000, "RefillSpeed")
        api.Button("Refill manual (1 vez)", function()
            local assets = ReplicatedStorage:FindFirstChild("Assets")
            local remotes = assets and assets:FindFirstChild("Remotes")
            local post = remotes and remotes:FindFirstChild("POST")
            if post then
                pcall(function() post:FireServer("Attacks", "Reload") end)
                S.notify("Refill", "Ejecutado", 2)
            else
                S.notify("Refill", "POST no encontrado", 2)
            end
        end)
        api.Section("Diagnóstico")
        api.Button("Volcar estado del refill", function()
            local seg = S.Farm.ActorSegments and S.Farm.ActorSegments()
            local rel = S.Farm.ActorReloads and S.Farm.ActorReloads()
            S.notify("Refill Debug",
                "Seg: " .. tostring(seg) .. " · Rel: " .. tostring(rel) ..
                " · Refills: " .. tostring(RT.refillsLeft() or "?") ..
                " · Refilling: " .. tostring(S.Farm.Refilling) ..
                " · SpearStuck: " .. tostring(S.Farm.SpearStuck), 8)
        end)
    end)

    S.addTab("Escape", "Utilidad", "escape", "QTE WASD", function(api)
        api.Section("QTE")
        api.Toggle("Auto Escape (WASDL)", "AutoEscape", function(s) S.notify("Auto Escape", s and "Activado" or "Desactivado", 2) end, { requires = "game", tip = "Resuelve el QTE pulsando la tecla correcta" })
        api.Toggle("Debug escape", "DebugEscape", nil, { tip = "Escribe en consola la tecla detectada" })
        api.Section("Sensibilidad")
        api.Slider("Cooldown (x100)", 5, 50, "EscapeCooldownX100")
        api.Slider("Tamaño mínimo label", 10, 60, "EscapeMinSize")
    end)

    S.addTab("Visual", "Sistema", "visual", "Tema, cursor y figura", function(api)
        api.Section("Tema")
        api.Dropdown("Modo de color", { "Dark", "Light" }, "UITheme", function(option)
            S.notify("Tema", "Modo " .. option .. " (reconstruyendo)", 2)
            task.delay(0.2, function() S.rebuild() end)
        end)
        api.Dropdown("Acento", S.ACCENT_NAMES, "UIAccess", function(option)
            H.setAccent(option)
            S.notify("Acento", "Cambiado a " .. option, 2)
        end)
        api.Section("Ventana")
        api.Slider("Escala de UI (x100)", 70, 135, "UIScale", function(v) S.applyScale(v / 100) end)
        api.Toggle("Movimiento reducido", "UIReducedMotion", function(s) S.V.reduced = s end, { tip = "Quita animaciones y pulsos" })
        api.Button("Aplicar y reconstruir", function() S.rebuild() end)
        api.Section("Cursor")
        api.Toggle("Cursor personalizado", "CursorEnabled", function() H.applyCursor() end, { tip = "Reemplaza el cursor nativo" })
        api.Dropdown("Forma", S.CURSOR_SHAPES, "CursorShape", function() H.buildCursor() end)
        api.ColorPicker("Color del cursor", "CursorColor", function() H.buildCursor() end)
        api.Slider("Tamaño", 8, 40, "CursorSize", function() H.buildCursor() end)
        api.Slider("Opacidad", 0, 90, "CursorOpacity", function() H.buildCursor() end)
        api.Section("Figura")
        api.Toggle("Mostrar figura", "AvatarVisible", function() H.applyAvatarLook() end)
        api.ColorPicker("Tinte de la figura", "AvatarTintColor", function() H.applyAvatarLook() end)
        api.Slider("Intensidad del tinte", 0, 100, "AvatarTintStrength", function() H.applyAvatarLook() end)
        api.ColorPicker("Color del anillo", "AvatarRingColor", function() H.applyAvatarLook() end)
        api.Button("Anillo = acento", function()
            Config.AvatarRingColor = H.toHex(THEME.accent)
            H.applyAvatarLook()
        end)
    end)

    S.addTab("Log", "Sistema", "log", "Últimos eventos", function(api)
        api.Section("Historial")
        local holder = api.Label("", 240)
        local function render()
            if #LogHistory == 0 then holder.set("Sin eventos todavía.") return end
            local lines = {}
            for _, entry in ipairs(LogHistory) do
                lines[#lines + 1] = ("[%s] %s — %s"):format(os.date("%H:%M", entry.time), entry.title, entry.message)
            end
            holder.set(table.concat(lines, "\n"))
        end
        render()
        EventBus:On("LogAdded", render)
        api.Button("Copiar al portapapeles", function()
            local lines = {}
            for _, entry in ipairs(LogHistory) do
                lines[#lines + 1] = ("[%s] %s — %s"):format(os.date("%H:%M", entry.time), entry.title, entry.message)
            end
            if setclipboard then pcall(setclipboard, table.concat(lines, "\n")) S.notify("Log", "Copiado", 2)
            else S.notify("Log", "setclipboard no disponible", 2) end
        end)
        api.Button("Limpiar historial", function()
            for i = #LogHistory, 1, -1 do LogHistory[i] = nil end
            render()
        end, { dangerous = true })
        api.Section("Changelog")
        for _, line in ipairs(CHANGELOG) do api.Label(line) end
    end)

    S.addTab("Diagnóstico", "Sistema", "diag", "Estado técnico", function(api)
        api.Section("Entorno")
        local placeStat = api.Stat("PlaceId")
        local ctxStat = api.Stat("Contexto")
        local remoteStat = api.Stat("Remotes")
        local actorStat = api.Stat("Actor")
        local errStat = api.Stat("Último error")
        api.Section("Acciones")
        api.Button("Refrescar", function()
            placeStat.set(tostring(game.PlaceId))
            ctxStat.set(ContextKind())
            local assets = ReplicatedStorage:FindFirstChild("Assets")
            local remotes = assets and assets:FindFirstChild("Remotes")
            remoteStat.set(remotes and "OK" or "FALTAN")
            actorStat.set(S.Farm.ActorActive and (S.Farm.ActorActive() and "ENLAZADO" or "sin enlace") or "n/d")
            errStat.set(S.lastError or "ninguno")
        end)
        api.Button("Copiar informe", function()
            local text = table.concat({
                "place=" .. tostring(game.PlaceId),
                "ctx=" .. ContextKind(),
                "actor=" .. tostring(S.Farm.ActorActive and S.Farm.ActorActive()),
                "segments=" .. tostring(S.Farm.ActorSegments and S.Farm.ActorSegments()),
                "reloads=" .. tostring(S.Farm.ActorReloads and S.Farm.ActorReloads()),
                "refills=" .. tostring(RT.refillsLeft()),
                "error=" .. tostring(S.lastError),
            }, "\n")
            if setclipboard then pcall(setclipboard, text) S.notify("Diagnóstico", "Informe copiado", 2)
            else S.notify("Diagnóstico", "setclipboard no disponible", 2) end
        end)
        api.Label("Copia el informe antes de reportar un fallo.")
    end)

    S.addTab("Config", "Sistema", "config", "Perfiles guardados", function(api)
        api.Section("Configuración activa")
        local activeStat = api.Stat("Activa")
        local autoStat = api.Stat("Autoload")
        activeStat.set(ConfigStore.Active() or "none")
        autoStat.set(ConfigStore.Autoload() or "none")
        api.Toggle("Auto-sync a config activa", "_AutoSync", function(state)
            ConfigStore.SetAutoSync(state)
            S.notify("Auto-sync", state and "ON" or "OFF", 2)
        end)
        api.Section("Guardar config con nombre")
        api.TextBox("Nombre de la config", "_TypedName", function(text) typedName = text end)
        api.Button("Crear / Guardar con ese nombre", function()
            local name = tostring(typedName or ""):gsub('[%c/\\:*?"<>|]', ""):gsub("^%s+", ""):gsub("%s+$", "")
            if #name == 0 then S.notify("Config", "Escribe un nombre", 2) return end
            if #name > 40 then name = name:sub(1, 40) end
            if ConfigStore.IsDefault(name) then S.notify("Config", "No se puede sobrescribir la default", 2) return end
            if ConfigStore.Put(name, ConfigStore.Snapshot()) then
                ConfigStore.SetActive(name)
                activeStat.set(name)
                S.notify("Config", "Guardada: " .. name, 2)
                S.buildPage(tabByName["Config"])
            else
                S.notify("Config", "No se pudo guardar (executor sin archivos)", 2)
            end
        end)
        api.Section("Lista de configs")
        if #ConfigStore.Names() <= 1 then api.Empty("Todavía no hay configs guardadas.") end
        local opts = { "---" }
        for _, n in ipairs(ConfigStore.Names()) do opts[#opts + 1] = n end
        currentOptions = opts
        listDropdown = api.Dropdown("Config", currentOptions, "_SelectedConfig", function(option)
            if option ~= "---" then selectedName = option end
        end)
        api.Button("Cargar seleccionada", function()
            if not selectedName then S.notify("Config", "Selecciona una config", 2) return end
            local snap = ConfigStore.Get(selectedName)
            if not snap then S.notify("Config", "No existe", 2) return end
            ConfigStore.SetActive(selectedName)
            ConfigStore.ApplyCfg(snap)
            S.notify("Config", "Cargada: " .. selectedName, 2)
            task.delay(0.3, function() S.rebuild() end)
        end)
        api.Button("Guardar en la activa", function()
            local name = ConfigStore.Active()
            if not name then S.notify("Config", "No hay config activa", 2) return end
            if ConfigStore.IsDefault(name) then S.notify("Config", "La default es solo lectura", 2) return end
            local ok = ConfigStore.SaveActive()
            S.notify("Config", ok and ("Guardado en " .. name) or "No se pudo guardar", 2)
        end)
        api.Button("Set como autoload", function()
            if not selectedName then S.notify("Config", "Selecciona una config", 2) return end
            if ConfigStore.SetAutoload(selectedName) then autoStat.set(selectedName) S.notify("Config", "Autoload: " .. selectedName, 2)
            else S.notify("Config", "Error", 2) end
        end)
        api.Button("Reset autoload", function()
            ConfigStore.SetAutoload(nil)
            autoStat.set("none")
            S.notify("Config", "Autoload borrado", 2)
        end)
        api.Button("Eliminar seleccionada", function()
            if not selectedName then S.notify("Config", "Selecciona una config", 2) return end
            if ConfigStore.IsDefault(selectedName) then S.notify("Config", "La default no se puede borrar", 2) return end
            S.confirm("Se eliminará la config '" .. selectedName .. "'. ¿Continuar?", function()
                ConfigStore.Delete(selectedName)
                S.notify("Config", "Eliminada: " .. selectedName, 2)
                S.buildPage(tabByName["Config"])
            end)
        end, { dangerous = true })
        api.Button("Recargar lista desde disco", function()
            ConfigStore.Reload()
            S.notify("Config", "Lista recargada", 2)
            S.buildPage(tabByName["Config"])
        end)
    end)

    S.addTab("Ajustes", "Sistema", "settings", "General y hotkeys", function(api)
        api.Section("General")
        api.Toggle("Notificaciones", "UINotify", function(state) ui.notifyHolder.Visible = state end)
        api.Button("Probar notificación", function() S.notify("Notificación", "Así se ven los avisos.", 3) end)
        api.Button("Guardar config rápida (AOTR)", function()
            SettingsStore.Write("AOTR", { Cfg = Config, SavedAt = os.time(), Account = player.Name })
            S.notify("Config", "Guardada en SmoothHub/" .. player.UserId .. "/AOTR.json", 3)
        end)
        api.Label("Tecla de apertura: " .. Config.Keybind .. " (cámbiala en Visual)")
        api.Section("Hotkeys de feature")
        local HOT_OPTIONS = { "—", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "Z", "X", "C", "V", "B", "G", "H", "J", "K", "L", "N", "M" }
        local HOT_FEATURES = {
            { key = "AutoFarm", name = "Auto Farm" },
            { key = "AutoSkill", name = "Auto Skill" },
            { key = "AutoEscape", name = "Auto Escape" },
            { key = "AutoRefillBlade", name = "Blades" },
            { key = "AutoRefillThunder", name = "Thunder" },
            { key = "AutoRetry", name = "Auto Click" },
        }
        for _, f in ipairs(HOT_FEATURES) do
            api.Dropdown(f.name, HOT_OPTIONS, "_hk_" .. f.key, function(option)
                local value = option == "—" and "" or option
                if value ~= "" then
                    for k, v in pairs(Config.Hotkeys) do
                        if v == value and k ~= f.key then Config.Hotkeys[k] = "" end
                    end
                end
                Config.Hotkeys[f.key] = value
            end)
        end
        api.Button("Borrar todas las hotkeys", function()
            Config.Hotkeys = {}
            S.buildPage(tabByName["Ajustes"])
            S.notify("Hotkeys", "Borradas", 2)
        end)
        api.Section("Sesión")
        api.Button("Cerrar menú", function()
            S.confirm("Se cerrará la interfaz y se apagarán las features. ¿Continuar?", function()
                SettingsStore.Flush("AOTR")
                pcall(ConfigStore.SaveActive)
                RT.panic()
                H.rememberPos()
                pcall(function() UserInputService.MouseIconEnabled = true end)
                if ui.tooltipGui then ui.tooltipGui:Destroy() end
                if ui.cursorGui then ui.cursorGui:Destroy() end
                local g = ui.gui; S.ui.gui = nil
                if g then g:Destroy() end
            end)
        end, { dangerous = true })
    end)
end

-- ============================================================
-- 5) BOOT: TECLADO, TELEMETRÍA, LOOPS
-- ============================================================
local function boot(S)
    local H, RT, ui = S.H, S.RT, S.ui

    ui.minimizeBtn.MouseButton1Click:Connect(function()
        ui.MiniFrame.Position = UDim2.new(ui.window.Position.X.Scale, ui.window.Position.X.Offset + (ui.window.AbsoluteSize.X / 2) - 30, ui.window.Position.Y.Scale, ui.window.Position.Y.Offset + (ui.window.AbsoluteSize.Y / 2) - 30)
        ui.window.Visible = false; ui.MiniFrame.Visible = true
    end)

    ui.closeBtn.MouseButton1Click:Connect(function()
        SettingsStore.Flush("AOTR")
        pcall(ConfigStore.SaveActive)
        RT.panic()
        H.rememberPos()
        pcall(function() UserInputService.MouseIconEnabled = true end)
        ui.window.Visible = false; ui.MiniFrame.Visible = false
    end)

    ui.panicBtn.MouseButton1Click:Connect(function() RT.panic() end)

    UserInputService.InputBegan:Connect(function(input, processed)
        local focused = UserInputService:GetFocusedTextBox()
        local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
        if focused then
            if input.KeyCode == Enum.KeyCode.F and ctrl then
                pcall(function() focused:ReleaseFocus() end)
                if Config.UICollapsed then ui.collapseBtn:Activate() end
                ui.searchInput:CaptureFocus()
            end
            return
        end
        if processed then return end
        if input.KeyCode == (Enum.KeyCode[Config.Keybind] or Enum.KeyCode.RightShift) then
            if ui.window.Visible then
                ui.window.Visible = false; ui.MiniFrame.Visible = true
            else
                ui.window.Visible = true; ui.MiniFrame.Visible = false; H.rememberPos()
            end
            return
        end
        if input.KeyCode == Enum.KeyCode.F and ctrl then
            ui.searchInput:CaptureFocus()
            return
        end
        for feature, keyName in pairs(Config.Hotkeys) do
            if keyName ~= "" and input.KeyCode == Enum.KeyCode[keyName] and Config[feature] ~= nil then
                Config[feature] = not Config[feature]
                EventBus:Emit("ConfigChanged", feature, Config[feature])
                S.notify("Hotkey", feature .. ": " .. (Config[feature] and "ON" or "OFF"), 1.5)
                return
            end
        end
    end)

    -- Chip de contexto y refresco de estado
    local CTX = {
        game = { text = "EN PARTIDA", kind = "ok" },
        lobby = { text = "LOBBY", kind = "warn" },
        menu = { text = "MENÚ", kind = "mute" },
        other = { text = "OTRO PLACE", kind = "mute" },
    }
    local function refreshChip()
        local ctx = ContextKind()
        local style = CTX[ctx] or CTX.other
        ui.chipText.Text = style.text
        local c = style.kind == "ok" and S.V.ok or (style.kind == "warn" and S.V.warn or S.V.mute)
        ui.chipDot.BackgroundColor3 = c
        ui.chipText.TextColor3 = c
    end

    S.refreshContext = function()
        local ctx = ContextKind()
        local okGame = (ctx == "game" or ctx == "other")
        local okLobby = (ctx == "lobby")
        for i = #S.contextControls, 1, -1 do
            local entry = S.contextControls[i]
            if not entry.obj.Parent then
                table.remove(S.contextControls, i)
            else
                local enabled = true
                if entry.requires == "game" then enabled = okGame
                elseif entry.requires == "lobby" then enabled = okLobby end
                entry.obj.Active = enabled
                entry.obj.BackgroundTransparency = enabled and 0 or 0.6
                entry.obj.TextTransparency = enabled and 0 or 0.4
            end
        end
    end

    S.applyScale = function(value)
        local s = math.clamp(tonumber(value) or 1, 0.7, 1.35)
        Config.UIScale = s
        H.smooth(ui.uiScale, 0.15, { Scale = s })
        ui.window.Size = UDim2.fromOffset(
            math.clamp(ui.window.Size.X.Offset / math.max(ui.uiScale.Scale, 0.1) * s, WIN_MIN_W * s, WIN_MAX_W * s),
            math.clamp(ui.window.Size.Y.Offset / math.max(ui.uiScale.Scale, 0.1) * s, WIN_MIN_H * s, WIN_MAX_H * s))
        local cam = Workspace.CurrentCamera
        if cam and cam.ViewportSize.X < 700 then ui.window.Position = UDim2.fromOffset(10, 10) end
    end

    S.rebuild = function()
        SettingsStore.Flush("AOTR")
        pcall(ConfigStore.SaveActive)
        H.rememberPos()
        pcall(function() UserInputService.MouseIconEnabled = true end)
        if ui.cursorGui then ui.cursorGui:Destroy() end
        if ui.tooltipGui then ui.tooltipGui:Destroy() end
        local g = ui.gui; S.ui.gui = nil
        if g then g:Destroy() end
        task.wait(0.05)
        loadMainScript()
    end

    local function refreshStatus()
        local active = {}
        for _, key in ipairs({ "AutoFarm", "AutoSkill", "AutoRefillBlade", "AutoRefillThunder", "AutoRefillWave", "AutoEscape", "AutoRetry", "AutoCreateRaid", "AutoStartRaid", "AutoCannon" }) do
            if Config[key] then active[#active + 1] = key:gsub("Auto", "") end
        end
        if #active > 0 then
            ui.activeFeatures.Text = table.concat(active, " · ")
            ui.statusDot.BackgroundColor3 = S.V.ok
            ui.statusText.Text = #active .. " activos"
        else
            ui.activeFeatures.Text = ""
            ui.statusDot.BackgroundColor3 = S.V.mute
            ui.statusText.Text = "Sin features"
        end
        for _, t in ipairs(S.tabs) do
            local on = false
            if t.name == "Farm" then on = Config.AutoFarm or Config.AutoSkill
            elseif t.name == "Wave" then on = Config.AutoRefillWave
            elseif t.name == "Refill" then on = Config.AutoRefillBlade or Config.AutoRefillThunder
            elseif t.name == "Escape" then on = Config.AutoEscape
            elseif t.name == "Auto Click" then on = Config.AutoRetry
            elseif t.name == "Raid" then on = Config.AutoCreateRaid or Config.AutoStartRaid or Config.AutoCannon or Config.AutoSkipCutscene end
            t.badge.BackgroundTransparency = on and 0.15 or 1
            t.badgeText.TextTransparency = on and 0 or 1
        end
    end

    local startedAt = os.clock()
    task.spawn(function()
        while ui.gui and ui.gui.Parent do
            task.wait(0.5)
            refreshStatus()
            refreshChip()
            S.refreshContext()
            local d = S.dash
            if d and d.place and d.place.raw.Parent then
                d.place.set(tostring(game.PlaceId))
                d.ctx.set(ContextKind())
                local secs = math.floor(os.clock() - startedAt)
                d.uptime.set(("%02d:%02d"):format(math.floor(secs / 60), secs % 60))
                d.actor.set(S.Farm.ActorActive and (S.Farm.ActorActive() and "ENLAZADO" or "sin enlace") or "n/d")
                d.refills.set(tostring(RT.refillsLeft() or "?"))
                local seg = S.Farm.ActorSegments and S.Farm.ActorSegments()
                d.blades.set(RT.bladesEmpty() and "VACÍAS" or (seg and tostring(seg) or "OK"))
                d.spears.set(tostring(RT.spearsLeft() or "?"))
                local titans = Workspace:FindFirstChild("Titans")
                d.titans.set(titans and tostring(#titans:GetChildren()) or "0")
            end
        end
    end)

    task.spawn(function() while ui.gui and ui.gui.Parent do task.wait(0.05) RT.checkEscape() end end)
    for _, name in ipairs({ "farmLoop", "clickLoop", "skillLoop", "refillLoop", "waveLoop", "watchLoop", "skipLoop", "chestLoop", "cannonLoop", "autoCreateLoop", "autoStartLoop" }) do
        if RT[name] then task.spawn(RT[name]) end
    end
    task.spawn(function()
        while ui.gui and ui.gui.Parent do
            task.wait(2)
            if Config.AutoCreateWave and Config.AutoPlay and CanUseHere() then
                RT.pressButtonByName("WAVES"); task.wait(1)
                RT.pressButtonByName("CREATE"); task.wait(1)
                RT.pressButtonByName("START")
            end
        end
    end)
    task.spawn(function()
        while ui.gui and ui.gui.Parent do
            task.wait(0.5)
            if Config.AutoPlay and CanUseHere() then
                if Config.AutoReady then
                    RT.pressButtonByName("READY", true)
                    RT.pressButtonByName("ACCEPT", true)
                end
                if Config.AutoVoteSkip then
                    RT.pressButtonByName("VOTE SKIP")
                    RT.pressButtonByName("SKIP", true)
                end
            end
        end
    end)

    ui.gui.Destroying:Connect(function()
        pcall(function() ui.tooltipGui:Destroy() end)
        pcall(function() ui.cursorGui:Destroy() end)
    end)

    -- Estado inicial
    H.applyCursor()
    refreshChip()
    S.refreshContext()
    if Config.UICollapsed then
        ui.collapseBtn.Text = "»"
        ui.searchBox.Visible = false
        ui.tabsScroll.Position = UDim2.fromOffset(0, 8)
        ui.tabsScroll.Size = UDim2.new(1, 0, 1, -44)
        for _, t in ipairs(S.tabs) do
            t.label.Visible = false; t.star.Visible = false; t.badge.Visible = false
            t.iconHolder.Position = UDim2.fromOffset(15, 10)
        end
        for _, h in pairs(S.groupHeaders) do h.Visible = false end
    end
    local startTab = S.tabByName[Config.UIActiveTab] or S.tabByName["Inicio"] or S.tabs[1]
    if startTab then S.selectTab(startTab) end

    S.notify("CASPER HUB PREMIUM v13.1", "Interfaz lista · " .. Config.Keybind, 4)
    print("[CASPER HUB PREMIUM v13.1] Cargado con éxito.")
end

-- ============================================================
-- ENTRY
-- ============================================================
function loadMainScript()
    local S = { ui = {}, RT = {}, contextControls = {}, lastError = nil }
    buildTokens(S)
    buildShell(S)
    buildRuntime(S)
    buildTabs(S)
    boot(S)
    _G.CasperSession = S
end

if isKeyVerified then
    loadMainScript()
else
    _G.CasperMainScript = loadMainScript
end
