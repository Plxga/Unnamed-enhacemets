--[[
  RIVALS — Unnamed Enhancements v2 (Stable)
  ============================================================
  - UI más limpia
  - Más estable (menos crashes)
  - Silent aim / FOV mejorados
  - ESP optimizado

  loadstring(game:HttpGet("https://raw.githubusercontent.com/betsabetmatus-bit/RivalsMP/main/Rivals_Unnamed_LOADSTRING.luau"))()

  Teclas: RightControl / Insert = abrir-cerrar menú
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local TextService       = game:GetService("TextService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

-- Compat
local protectgui  = protectgui or (syn and syn.protect_gui) or function() end
local gethui      = gethui or function() return CoreGui end
local newcclosure = newcclosure or function(f) return f end
local getrawmetatable = getrawmetatable or (debug and debug.getmetatable) or function() end
local setreadonly = setreadonly or function() end
local getnamecallmethod = getnamecallmethod or function() return "" end
local getgc = getgc or function() return {} end
local Drawing_new = (Drawing and Drawing.new) or nil

if not getgenv then getgenv = function() return _G end end
if getgenv().UE_LOADED then
    pcall(function() if getgenv().Library then getgenv().Library:Unload() end end)
end

getgenv().Toggles = {}
getgenv().Options = {}
local Toggles = getgenv().Toggles
local Options = getgenv().Options

-- =========================================================
-- STATE
-- =========================================================
local State = {
    drawings = {},
    esp = {},
    targetPos = nil,
    fighter = nil,
    remotes = nil,
    menuOpen = true,
    rayParams = RaycastParams.new(),
}
State.rayParams.FilterType = Enum.RaycastFilterType.Exclude
if LocalPlayer.Character then
    State.rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
end
LocalPlayer.CharacterAdded:Connect(function(c)
    State.rayParams.FilterDescendantsInstances = { c }
end)

local function alive(plr)
    local c = plr and plr.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    return h and r and h.Health > 0
end

local function root(plr)
    return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
end

local function head(plr)
    return plr.Character and plr.Character:FindFirstChild("Head")
end

local function hum(plr)
    return plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
end

-- =========================================================
-- LIBRARY (UI limpia)
-- =========================================================
local Library = {
    Accent = Color3.fromRGB(90, 140, 255),
    Bg = Color3.fromRGB(16, 16, 20),
    Panel = Color3.fromRGB(24, 24, 30),
    Text = Color3.fromRGB(230, 230, 235),
    Dim = Color3.fromRGB(140, 140, 150),
    Outline = Color3.fromRGB(40, 40, 48),
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    Signals = {},
    UnloadCbs = {},
}

local SG = Instance.new("ScreenGui")
protectgui(SG)
SG.Name = "UE_Rivals_v2"
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.ResetOnSpawn = false
SG.Parent = gethui()
Library.SG = SG

function Library:Create(cls, props)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    return o
end

function Library:Signal(s)
    table.insert(self.Signals, s)
    return s
end

function Library:Notify(msg, t)
    t = t or 3
    local f = self:Create("Frame", {
        Parent = SG,
        BackgroundColor3 = self.Panel,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 36),
        Position = UDim2.new(0.5, 0, 0, 50),
        AnchorPoint = Vector2.new(0.5, 0),
        ZIndex = 200,
    })
    self:Create("UICorner", { Parent = f, CornerRadius = UDim.new(0, 8) })
    self:Create("UIStroke", { Parent = f, Color = self.Accent, Thickness = 1.2 })
    local lbl = self:Create("TextLabel", {
        Parent = f,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        Font = self.Font,
        TextSize = 13,
        TextColor3 = self.Text,
        Text = tostring(msg),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })
    local w = TextService:GetTextSize(tostring(msg), 13, self.Font, Vector2.new(800, 36)).X + 28
    TweenService:Create(f, TweenInfo.new(0.2), { Size = UDim2.fromOffset(w, 36) }):Play()
    task.delay(t, function()
        TweenService:Create(f, TweenInfo.new(0.2), { Size = UDim2.fromOffset(0, 36) }):Play()
        task.wait(0.22)
        f:Destroy()
    end)
end

function Library:Unload()
    for _, s in ipairs(self.Signals) do pcall(function() s:Disconnect() end) end
    for _, cb in ipairs(self.UnloadCbs) do pcall(cb) end
    for plr, data in pairs(State.esp) do
        for _, d in pairs(data) do
            pcall(function()
                if typeof(d) == "Instance" then d:Destroy()
                elseif d.Remove then d:Remove() end
            end)
        end
    end
    State.esp = {}
    if State.drawings.fov and State.drawings.fov.Remove then pcall(function() State.drawings.fov:Remove() end) end
    SG:Destroy()
    getgenv().UE_LOADED = nil
    getgenv().Library = nil
    getgenv().Toggles = nil
    getgenv().Options = nil
end

function Library:Toggle()
    State.menuOpen = not State.menuOpen
    if self.Main then self.Main.Visible = State.menuOpen end
end

-- ---------- Window ----------
function Library:CreateWindow(title)
    local main = self:Create("Frame", {
        Parent = SG,
        Name = "Main",
        BackgroundColor3 = self.Bg,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, -300, 0.5, -210),
        Size = UDim2.fromOffset(600, 420),
        Active = true,
        Draggable = true,
        ZIndex = 10,
    })
    self:Create("UICorner", { Parent = main, CornerRadius = UDim.new(0, 10) })
    self:Create("UIStroke", { Parent = main, Color = self.Outline, Thickness = 1 })
    self.Main = main

    -- Title bar
    local bar = self:Create("Frame", {
        Parent = main,
        BackgroundColor3 = self.Panel,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
        ZIndex = 11,
    })
    self:Create("UICorner", { Parent = bar, CornerRadius = UDim.new(0, 10) })
    self:Create("Frame", {
        Parent = bar,
        BackgroundColor3 = self.Panel,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -12),
        Size = UDim2.new(1, 0, 0, 12),
        ZIndex = 11,
    })

    self:Create("TextLabel", {
        Parent = bar,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -60, 1, 0),
        Font = self.FontBold,
        TextSize = 15,
        TextColor3 = self.Text,
        Text = title or "Unnamed",
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    })

    local close = self:Create("TextButton", {
        Parent = bar,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -40, 0, 0),
        Size = UDim2.fromOffset(40, 38),
        Font = self.FontBold,
        TextSize = 18,
        TextColor3 = self.Dim,
        Text = "✕",
        ZIndex = 12,
    })
    close.MouseButton1Click:Connect(function() self:Toggle() end)

    -- Accent line
    self:Create("Frame", {
        Parent = main,
        BackgroundColor3 = self.Accent,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 38),
        Size = UDim2.new(1, 0, 0, 2),
        ZIndex = 12,
    })

    -- Tabs
    local tabBar = self:Create("Frame", {
        Parent = main,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 48),
        Size = UDim2.new(1, -24, 0, 30),
        ZIndex = 11,
    })
    self:Create("UIListLayout", {
        Parent = tabBar,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local content = self:Create("Frame", {
        Parent = main,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 84),
        Size = UDim2.new(1, -24, 1, -96),
        ZIndex = 11,
    })

    local win = { Tabs = {}, TabBar = tabBar, Content = content, Main = main }
    return win
end

function Library:AddTab(win, name)
    local btn = self:Create("TextButton", {
        Parent = win.TabBar,
        BackgroundColor3 = self.Panel,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(96, 28),
        Font = self.Font,
        TextSize = 12,
        TextColor3 = self.Dim,
        Text = name,
        AutoButtonColor = false,
        ZIndex = 12,
    })
    self:Create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 6) })

    local page = self:Create("Frame", {
        Parent = win.Content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
        ZIndex = 11,
    })

    local left = self:Create("ScrollingFrame", {
        Parent = page,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -6, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = self.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 11,
    })
    self:Create("UIListLayout", { Parent = left, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    self:Create("UIPadding", { Parent = left, PaddingBottom = UDim.new(0, 8) })

    local right = self:Create("ScrollingFrame", {
        Parent = page,
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 6, 0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = self.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 11,
    })
    self:Create("UIListLayout", { Parent = right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    self:Create("UIPadding", { Parent = right, PaddingBottom = UDim.new(0, 8) })

    local tab = { Btn = btn, Page = page, Left = left, Right = right }

    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(win.Tabs) do
            t.Page.Visible = false
            t.Btn.BackgroundColor3 = Library.Panel
            t.Btn.TextColor3 = Library.Dim
        end
        page.Visible = true
        btn.BackgroundColor3 = Library.Accent
        btn.TextColor3 = Color3.new(1, 1, 1)
    end)

    table.insert(win.Tabs, tab)
    if #win.Tabs == 1 then
        page.Visible = true
        btn.BackgroundColor3 = Library.Accent
        btn.TextColor3 = Color3.new(1, 1, 1)
    end
    return tab
end

function Library:Groupbox(parent, title)
    local f = self:Create("Frame", {
        Parent = parent,
        BackgroundColor3 = self.Panel,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -2, 0, 30),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 12,
    })
    self:Create("UICorner", { Parent = f, CornerRadius = UDim.new(0, 8) })
    self:Create("UIStroke", { Parent = f, Color = self.Outline, Thickness = 1 })
    self:Create("UIListLayout", {
        Parent = f,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })
    self:Create("UIPadding", {
        Parent = f,
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    })
    self:Create("TextLabel", {
        Parent = f,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = self.FontBold,
        TextSize = 12,
        TextColor3 = self.Accent,
        Text = title,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 0,
        ZIndex = 13,
    })
    return f
end

-- Toggle
function Library:Toggle(parent, idx, text, default)
    local holder = self:Create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        LayoutOrder = 10,
        ZIndex = 13,
    })
    local box = self:Create("Frame", {
        Parent = holder,
        BackgroundColor3 = default and self.Accent or self.Bg,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, -8),
        Size = UDim2.fromOffset(16, 16),
        ZIndex = 14,
    })
    self:Create("UICorner", { Parent = box, CornerRadius = UDim.new(0, 4) })
    self:Create("UIStroke", { Parent = box, Color = self.Outline, Thickness = 1 })

    self:Create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = self.Font,
        TextSize = 13,
        TextColor3 = self.Text,
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    })

    local t = { Value = default == true, _cbs = {} }
    function t:Set(v)
        self.Value = not not v
        box.BackgroundColor3 = self.Value and Library.Accent or Library.Bg
        Toggles[idx] = self
        for _, cb in ipairs(self._cbs) do pcall(cb, self.Value) end
    end
    function t:OnChanged(cb)
        table.insert(self._cbs, cb)
        pcall(cb, self.Value)
        return self
    end

    local click = self:Create("TextButton", {
        Parent = holder,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        ZIndex = 15,
    })
    click.MouseButton1Click:Connect(function() t:Set(not t.Value) end)
    t:Set(default == true)
    Toggles[idx] = t
    return t
end

-- Slider
function Library:Slider(parent, idx, text, min, max, default, suffix, decimals)
    suffix = suffix or ""
    decimals = decimals or 0
    local holder = self:Create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 40),
        LayoutOrder = 10,
        ZIndex = 13,
    })
    local lbl = self:Create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = self.Font,
        TextSize = 12,
        TextColor3 = self.Text,
        Text = text .. ": " .. tostring(default) .. suffix,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    })
    local bg = self:Create("Frame", {
        Parent = holder,
        BackgroundColor3 = self.Bg,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 10),
        ZIndex = 14,
    })
    self:Create("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 5) })
    local fill = self:Create("Frame", {
        Parent = bg,
        BackgroundColor3 = self.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(math.clamp((default - min) / math.max(max - min, 0.001), 0, 1), 0, 1, 0),
        ZIndex = 15,
    })
    self:Create("UICorner", { Parent = fill, CornerRadius = UDim.new(0, 5) })

    local s = { Value = default, _cbs = {} }
    local function rnd(v)
        if decimals <= 0 then return math.floor(v + 0.5) end
        local m = 10 ^ decimals
        return math.floor(v * m + 0.5) / m
    end
    function s:Set(v)
        v = math.clamp(rnd(v), min, max)
        self.Value = v
        fill.Size = UDim2.new((v - min) / math.max(max - min, 0.001), 0, 1, 0)
        lbl.Text = text .. ": " .. tostring(v) .. suffix
        Options[idx] = self
        for _, cb in ipairs(self._cbs) do pcall(cb, v) end
    end
    function s:OnChanged(cb)
        table.insert(self._cbs, cb)
        pcall(cb, self.Value)
        return self
    end

    local drag = false
    bg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end
    end)
    self:Signal(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end))
    self:Signal(UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local r = (i.Position.X - bg.AbsolutePosition.X) / math.max(bg.AbsoluteSize.X, 1)
            s:Set(min + r * (max - min))
        end
    end))
    s:Set(default)
    Options[idx] = s
    return s
end

-- Dropdown
function Library:Dropdown(parent, idx, text, values, default)
    local holder = self:Create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 44),
        LayoutOrder = 10,
        ZIndex = 13,
    })
    self:Create("TextLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = self.Font,
        TextSize = 12,
        TextColor3 = self.Text,
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    })
    local box = self:Create("TextButton", {
        Parent = holder,
        BackgroundColor3 = self.Bg,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 20),
        Size = UDim2.new(1, 0, 0, 22),
        Font = self.Font,
        TextSize = 12,
        TextColor3 = self.Text,
        Text = "  " .. tostring(default),
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        ZIndex = 14,
    })
    self:Create("UICorner", { Parent = box, CornerRadius = UDim.new(0, 5) })
    self:Create("UIStroke", { Parent = box, Color = self.Outline, Thickness = 1 })

    local d = { Value = default, Values = values, _cbs = {} }
    local i = 1
    for n, v in ipairs(values) do if v == default then i = n break end end
    function d:Set(v)
        self.Value = v
        box.Text = "  " .. tostring(v)
        Options[idx] = self
        for _, cb in ipairs(self._cbs) do pcall(cb, v) end
    end
    function d:OnChanged(cb)
        table.insert(self._cbs, cb)
        pcall(cb, self.Value)
        return self
    end
    box.MouseButton1Click:Connect(function()
        i = i % #values + 1
        d:Set(values[i])
    end)
    d:Set(default)
    Options[idx] = d
    return d
end

function Library:Button(parent, text, cb)
    local b = self:Create("TextButton", {
        Parent = parent,
        BackgroundColor3 = self.Bg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 28),
        Font = self.Font,
        TextSize = 13,
        TextColor3 = self.Text,
        Text = text,
        AutoButtonColor = false,
        LayoutOrder = 10,
        ZIndex = 14,
    })
    self:Create("UICorner", { Parent = b, CornerRadius = UDim.new(0, 6) })
    self:Create("UIStroke", { Parent = b, Color = self.Outline, Thickness = 1 })
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end

-- =========================================================
-- BUILD UI
-- =========================================================
local Win = Library:CreateWindow("Unnamed Enhancements")
local Combat  = Library:AddTab(Win, "Combat")
local Visuals = Library:AddTab(Win, "Visuals")
local World   = Library:AddTab(Win, "World")
local Settings= Library:AddTab(Win, "Settings")

-- Combat Left
local gAim = Library:Groupbox(Combat.Left, "Aim / Silent")
Library:Toggle(gAim, "aim_enabled", "Enabled", false)
Library:Toggle(gAim, "aim_visible", "Visible only", true)
Library:Toggle(gAim, "aim_team_check", "Team check", true)
Library:Slider(gAim, "aim_fov", "FOV", 20, 500, 120, " px", 0)
Library:Slider(gAim, "aim_hitchance", "Hit chance", 1, 100, 100, "%", 0)
Library:Toggle(gAim, "aim_show_fov", "Show FOV", true)
Library:Dropdown(gAim, "aim_part", "Aim part", { "Head", "HumanoidRootPart", "UpperTorso" }, "Head")

local gExp = Library:Groupbox(Combat.Left, "Exploits")
Library:Toggle(gExp, "no_spread", "No spread", true)
Library:Toggle(gExp, "full_auto", "Full auto", false)

-- Combat Right
local gTrig = Library:Groupbox(Combat.Right, "Triggerbot")
Library:Toggle(gTrig, "trigger_enabled", "Enabled", false)
Library:Dropdown(gTrig, "trigger_mode", "Mode", { "always", "scoped only" }, "always")

local gAA = Library:Groupbox(Combat.Right, "Anti Aim")
Library:Toggle(gAA, "aa_enabled", "Enabled", false)
Library:Slider(gAA, "aa_yaw", "Yaw", -180, 180, 0, "°", 0)

-- Visuals
local gEsp = Library:Groupbox(Visuals.Left, "ESP")
Library:Toggle(gEsp, "esp_master", "Master", true)
Library:Toggle(gEsp, "esp_name", "Name", true)
Library:Toggle(gEsp, "esp_dist", "Distance", true)
Library:Toggle(gEsp, "esp_box", "Box", true)
Library:Toggle(gEsp, "esp_hp", "Health bar", true)
Library:Toggle(gEsp, "esp_tracer", "Tracer", false)
Library:Toggle(gEsp, "esp_chams", "Chams", false)
Library:Toggle(gEsp, "esp_team", "Show team", false)
Library:Slider(gEsp, "esp_maxdist", "Max distance", 50, 1500, 600, " m", 0)

local gVis = Library:Groupbox(Visuals.Right, "Colors")
Library:Toggle(gVis, "esp_enemy_col_t", "Enemy color indicator", true)
Library:Toggle(gVis, "esp_team_col_t", "Team color indicator", true)

-- World
local gBloom = Library:Groupbox(World.Left, "Bloom")
Library:Toggle(gBloom, "bloom", "Enable", false)
Library:Slider(gBloom, "bloom_i", "Intensity", 0, 2, 0.4, "", 2)
Library:Slider(gBloom, "bloom_s", "Size", 0, 50, 20, "", 0)

local gCC = Library:Groupbox(World.Left, "Color Correction")
Library:Toggle(gCC, "cc", "Enable", false)
Library:Slider(gCC, "cc_sat", "Saturation", -1, 1, 0, "", 2)
Library:Slider(gCC, "cc_con", "Contrast", -1, 1, 0, "", 2)

local gAtmo = Library:Groupbox(World.Right, "Atmosphere")
Library:Toggle(gAtmo, "atmo", "Enable", false)
Library:Slider(gAtmo, "atmo_d", "Density", 0, 1, 0.25, "", 2)

local gSun = Library:Groupbox(World.Right, "Sun Rays")
Library:Toggle(gSun, "sun", "Enable", false)
Library:Slider(gSun, "sun_i", "Intensity", 0, 1, 0.2, "", 2)

-- Settings
local gMenu = Library:Groupbox(Settings.Left, "Menu")
Library:Button(gMenu, "Unload", function() Library:Unload() end)
Library:Button(gMenu, "Accent Blue", function()
    Library.Accent = Color3.fromRGB(90, 140, 255)
end)
Library:Button(gMenu, "Accent Red", function()
    Library.Accent = Color3.fromRGB(255, 70, 70)
end)
Library:Button(gMenu, "Accent Green", function()
    Library.Accent = Color3.fromRGB(60, 200, 100)
end)

local gCam = Library:Groupbox(Settings.Right, "Camera")
Library:Toggle(gCam, "fov_changer", "FOV changer", false)
Library:Slider(gCam, "fov_val", "FOV", 40, 120, 70, "", 0)

-- =========================================================
-- WORLD FX
-- =========================================================
local BloomFX = Instance.new("BloomEffect")
BloomFX.Parent = Lighting
BloomFX.Enabled = false
local CCFX = Instance.new("ColorCorrectionEffect")
CCFX.Parent = Lighting
CCFX.Enabled = false
local AtmoFX = Instance.new("Atmosphere")
local SunFX = Instance.new("SunRaysEffect")
SunFX.Parent = Lighting
SunFX.Enabled = false

local function refreshFX()
    pcall(function()
        if Toggles.bloom and Toggles.bloom.Value then
            BloomFX.Enabled = true
            BloomFX.Intensity = Options.bloom_i and Options.bloom_i.Value or 0.4
            BloomFX.Size = Options.bloom_s and Options.bloom_s.Value or 20
        else BloomFX.Enabled = false end

        if Toggles.cc and Toggles.cc.Value then
            CCFX.Enabled = true
            CCFX.Saturation = Options.cc_sat and Options.cc_sat.Value or 0
            CCFX.Contrast = Options.cc_con and Options.cc_con.Value or 0
        else CCFX.Enabled = false end

        if Toggles.atmo and Toggles.atmo.Value then
            AtmoFX.Parent = Lighting
            AtmoFX.Density = Options.atmo_d and Options.atmo_d.Value or 0.25
        else AtmoFX.Parent = nil end

        if Toggles.sun and Toggles.sun.Value then
            SunFX.Enabled = true
            SunFX.Intensity = Options.sun_i and Options.sun_i.Value or 0.2
        else SunFX.Enabled = false end
    end)
end

for _, n in ipairs({ "bloom", "cc", "atmo", "sun" }) do
    if Toggles[n] then Toggles[n]:OnChanged(refreshFX) end
end
for _, n in ipairs({ "bloom_i", "bloom_s", "cc_sat", "cc_con", "atmo_d", "sun_i" }) do
    if Options[n] then Options[n]:OnChanged(refreshFX) end
end

local baseFOV = Camera.FieldOfView
Library:Signal(RunService.RenderStepped:Connect(function()
    if Toggles.fov_changer and Toggles.fov_changer.Value then
        Camera.FieldOfView = Options.fov_val and Options.fov_val.Value or 70
    end
end))
if Toggles.fov_changer then
    Toggles.fov_changer:OnChanged(function(v)
        if not v then Camera.FieldOfView = baseFOV end
    end)
end

-- =========================================================
-- HOOKS (safe)
-- =========================================================
task.spawn(function()
    pcall(function()
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" and rawget(v, "ClientFighter") and rawget(v, "IsLocalPlayer") then
                State.fighter = v
                break
            end
        end
    end)
end)

State.remotes = ReplicatedStorage:FindFirstChild("Remotes")

pcall(function()
    local mt = getrawmetatable(game)
    if not mt or not mt.__namecall then return end
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }
        if method == "FireServer" and typeof(self) == "Instance" and State.remotes then
            local okDesc = pcall(function() return self:IsDescendantOf(State.remotes) end)
            if okDesc and self:IsDescendantOf(State.remotes) then
                local n = self.Name
                if n == "ReplicateFromServer" or n == "Shoot" or n == "Fire" or n == "WeaponShoot" then
                    if Toggles.no_spread and Toggles.no_spread.Value then
                        for _, a in ipairs(args) do
                            if type(a) == "table" then
                                pcall(function()
                                    if a._ProjectileEffect then
                                        a._ProjectileEffect.Spread = Vector3.zero
                                        a._ProjectileEffect.SpreadAngle = 0
                                    end
                                    if a.Spread then a.Spread = Vector3.zero end
                                    if a.SpreadAngle then a.SpreadAngle = 0 end
                                end)
                            end
                        end
                    end
                    if Toggles.aim_enabled and Toggles.aim_enabled.Value and State.targetPos then
                        local origin = Camera.CFrame.Position
                        local dir = (State.targetPos - origin)
                        if dir.Magnitude > 0.1 then
                            dir = dir.Unit
                            for _, a in ipairs(args) do
                                if type(a) == "table" then
                                    pcall(function()
                                        if a.Direction then a.Direction = dir end
                                        if a.Origin then a.Origin = origin end
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end)

-- =========================================================
-- FOV CIRCLE
-- =========================================================
local fovCircle
if Drawing_new then
    fovCircle = Drawing_new("Circle")
    fovCircle.Visible = false
    fovCircle.Thickness = 1.5
    fovCircle.Filled = false
    fovCircle.NumSides = 48
    fovCircle.Radius = 120
    fovCircle.Color = Color3.fromRGB(90, 140, 255)
    fovCircle.Transparency = 0.9
    State.drawings.fov = fovCircle
end

-- =========================================================
-- ESP (throttled, safe)
-- =========================================================
local function clearEsp(plr)
    local d = State.esp[plr]
    if not d then return end
    for _, o in pairs(d) do
        pcall(function()
            if typeof(o) == "Instance" then o:Destroy()
            elseif o.Remove then o:Remove() end
        end)
    end
    State.esp[plr] = nil
    if plr.Character then
        local hl = plr.Character:FindFirstChild("UE_Chams")
        if hl then pcall(function() hl:Destroy() end) end
    end
end

local function makeEsp(plr)
    if State.esp[plr] then return State.esp[plr] end
    if not Drawing_new then
        State.esp[plr] = {}
        return State.esp[plr]
    end
    local d = {}
    d.name = Drawing_new("Text")
    d.name.Center = true
    d.name.Outline = true
    d.name.Size = 13
    d.name.Font = 2
    d.name.Visible = false

    d.dist = Drawing_new("Text")
    d.dist.Center = true
    d.dist.Outline = true
    d.dist.Size = 11
    d.dist.Font = 2
    d.dist.Visible = false

    d.box = Drawing_new("Square")
    d.box.Thickness = 1
    d.box.Filled = false
    d.box.Visible = false

    d.hpBg = Drawing_new("Square")
    d.hpBg.Filled = true
    d.hpBg.Color = Color3.new(0, 0, 0)
    d.hpBg.Visible = false

    d.hp = Drawing_new("Square")
    d.hp.Filled = true
    d.hp.Visible = false

    d.tracer = Drawing_new("Line")
    d.tracer.Thickness = 1
    d.tracer.Visible = false

    State.esp[plr] = d
    return d
end

local function isEnemy(plr)
    if not (Toggles.aim_team_check and Toggles.aim_team_check.Value) then return true end
    if not LocalPlayer.Team or not plr.Team then return true end
    return LocalPlayer.Team ~= plr.Team
end

local function updateEsp()
    local master = Toggles.esp_master and Toggles.esp_master.Value
    local maxD = Options.esp_maxdist and Options.esp_maxdist.Value or 600
    local showTeam = Toggles.esp_team and Toggles.esp_team.Value
    local center = Camera.ViewportSize / 2

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then clearEsp(plr) continue end

        local enemy = isEnemy(plr)
        if not enemy and not showTeam then clearEsp(plr) continue end
        if not master or not alive(plr) then clearEsp(plr) continue end

        local r = root(plr)
        local h = hum(plr)
        if not r or not h then clearEsp(plr) continue end

        local worldPos = r.Position
        local sp, onScreen = Camera:WorldToViewportPoint(worldPos)
        local dist = (worldPos - Camera.CFrame.Position).Magnitude
        if dist > maxD or not onScreen then clearEsp(plr) continue end

        local data = makeEsp(plr)
        local color = enemy and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 160, 255)

        local hd = head(plr)
        local headY = hd and select(1, Camera:WorldToViewportPoint(hd.Position + Vector3.new(0, 0.4, 0))).Y or (sp.Y - 30)
        local footY = select(1, Camera:WorldToViewportPoint(worldPos - Vector3.new(0, 2.8, 0))).Y
        local height = math.abs(headY - footY)
        local width = height * 0.5
        local x = sp.X - width / 2
        local y = headY

        if data.name then
            if Toggles.esp_name and Toggles.esp_name.Value then
                data.name.Text = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name
                data.name.Position = Vector2.new(sp.X, y - 15)
                data.name.Color = color
                data.name.Visible = true
            else data.name.Visible = false end
        end

        if data.dist then
            if Toggles.esp_dist and Toggles.esp_dist.Value then
                data.dist.Text = math.floor(dist) .. "m"
                data.dist.Position = Vector2.new(sp.X, footY + 2)
                data.dist.Color = Color3.fromRGB(220, 220, 220)
                data.dist.Visible = true
            else data.dist.Visible = false end
        end

        if data.box then
            if Toggles.esp_box and Toggles.esp_box.Value then
                data.box.Size = Vector2.new(width, height)
                data.box.Position = Vector2.new(x, y)
                data.box.Color = color
                data.box.Visible = true
            else data.box.Visible = false end
        end

        if data.hp and data.hpBg then
            if Toggles.esp_hp and Toggles.esp_hp.Value then
                local pct = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
                local bh = height * pct
                data.hpBg.Size = Vector2.new(3, height)
                data.hpBg.Position = Vector2.new(x - 6, y)
                data.hpBg.Visible = true
                data.hp.Size = Vector2.new(3, bh)
                data.hp.Position = Vector2.new(x - 6, y + (height - bh))
                data.hp.Color = Color3.fromRGB(255 * (1 - pct), 220 * pct, 40)
                data.hp.Visible = true
            else
                data.hp.Visible = false
                data.hpBg.Visible = false
            end
        end

        if data.tracer then
            if Toggles.esp_tracer and Toggles.esp_tracer.Value then
                data.tracer.From = Vector2.new(center.X, Camera.ViewportSize.Y)
                data.tracer.To = Vector2.new(sp.X, footY)
                data.tracer.Color = color
                data.tracer.Visible = true
            else data.tracer.Visible = false end
        end

        -- Chams
        if Toggles.esp_chams and Toggles.esp_chams.Value and plr.Character then
            local hl = plr.Character:FindFirstChild("UE_Chams")
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name = "UE_Chams"
                hl.FillTransparency = 0.6
                hl.OutlineTransparency = 0.3
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = plr.Character
            end
            hl.FillColor = color
            hl.OutlineColor = color
            hl.Enabled = true
        elseif plr.Character then
            local hl = plr.Character:FindFirstChild("UE_Chams")
            if hl then hl:Destroy() end
        end
    end

    for plr in pairs(State.esp) do
        if not plr.Parent then clearEsp(plr) end
    end
end

Players.PlayerRemoving:Connect(clearEsp)

-- =========================================================
-- MAIN LOOP (aim + fov + esp) — throttled ESP
-- =========================================================
local espTick = 0
Library:Signal(RunService.RenderStepped:Connect(function(dt)
    local center = Camera.ViewportSize / 2
    local fov = Options.aim_fov and Options.aim_fov.Value or 120

    -- FOV circle
    if fovCircle then
        fovCircle.Position = center
        fovCircle.Radius = fov
        fovCircle.Visible = (Toggles.aim_show_fov and Toggles.aim_show_fov.Value)
            and (Toggles.aim_enabled and Toggles.aim_enabled.Value)
        fovCircle.Color = Library.Accent
    end

    -- ESP every ~3 frames
    espTick = espTick + 1
    if espTick >= 3 then
        espTick = 0
        pcall(updateEsp)
    end

    -- Aim targeting
    if not (Toggles.aim_enabled and Toggles.aim_enabled.Value) then
        State.targetPos = nil
        return
    end

    local partName = Options.aim_part and Options.aim_part.Value or "Head"
    local visOnly = Toggles.aim_visible and Toggles.aim_visible.Value
    local closest, closestD = nil, fov

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not alive(plr) then continue end
        if not isEnemy(plr) then continue end

        local part = plr.Character:FindFirstChild(partName) or root(plr)
        if not part then continue end

        if visOnly then
            local dir = part.Position - Camera.CFrame.Position
            local ray = workspace:Raycast(Camera.CFrame.Position, dir.Unit * dir.Magnitude, State.rayParams)
            if ray and ray.Instance and not ray.Instance:IsDescendantOf(plr.Character) then
                continue
            end
        end

        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < closestD then
            closestD = d
            closest = part
        end
    end

    if closest then
        local chance = Options.aim_hitchance and Options.aim_hitchance.Value or 100
        if math.random(1, 100) <= chance then
            State.targetPos = closest.Position
        else
            State.targetPos = nil
        end
    else
        State.targetPos = nil
    end
end))

-- =========================================================
-- TRIGGERBOT
-- =========================================================
local trigConn
if Toggles.trigger_enabled then
    Toggles.trigger_enabled:OnChanged(function(on)
        if trigConn then trigConn:Disconnect() trigConn = nil end
        if not on then return end
        trigConn = RunService.Heartbeat:Connect(function()
            local f = State.fighter
            if not f then return end
            local ok, eq = pcall(function() return f.EquippedItem end)
            if not ok or not eq then return end

            local mode = Options.trigger_mode and Options.trigger_mode.Value or "always"
            if mode == "scoped only" then
                local ok2, aiming = pcall(function() return f.IsAiming end)
                if not ok2 or not aiming then return end
            end

            local t = Mouse.Target
            if not t then return end
            local model = t:FindFirstAncestorOfClass("Model")
            if not model then return end
            local h = model:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then return end
            local p = Players:GetPlayerFromCharacter(model)
            if not p or p == LocalPlayer then return end
            if not isEnemy(p) then return end

            pcall(function() if eq.shoot then eq:shoot() end end)
        end)
        Library:Signal(trigConn)
    end)
end

if Toggles.full_auto then
    Toggles.full_auto:OnChanged(function(on)
        pcall(function()
            local f = State.fighter
            if not f or not f.EquippedItem then return end
            local w = f.EquippedItem
            if w.Info and w.Info.Type == "Gun" and on then
                w.Info.FireMode = "Auto"
            end
        end)
    end)
end

-- =========================================================
-- KEYBIND
-- =========================================================
Library:Signal(UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightControl or inp.KeyCode == Enum.KeyCode.Insert then
        Library:Toggle()
    end
end))

-- =========================================================
Library:Notify("Loaded — RightCtrl / Insert to toggle", 4)
print("[UE] v2 loaded")
getgenv().UE_LOADED = true
getgenv().Library = Library
