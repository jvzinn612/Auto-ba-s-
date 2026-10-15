--[[
    ═══════════════════════════════════════════════════════════
      AUTO FARM - COLETA AUTOMÁTICA DE BAÚS
      Versão 1.0.0 | UI Premium
      Tema: Dark + Azul Neon + Roxo
      Uso permitido apenas em ambientes/jogos autorizados.
    ═══════════════════════════════════════════════════════════
]]

--============================================================
-- SERVIÇOS
--============================================================
local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local ProximityPromptSvc = game:GetService("ProximityPromptService")
local RunService         = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

--============================================================
-- TEMA E ESTADO GLOBAL
--============================================================
local Theme = {
    Bg          = Color3.fromRGB(14, 14, 20),
    Surface     = Color3.fromRGB(22, 22, 32),
    Surface2    = Color3.fromRGB(30, 30, 44),
    Accent      = Color3.fromRGB(0, 170, 255),
    Accent2     = Color3.fromRGB(150, 80, 255),
    Text        = Color3.fromRGB(240, 240, 255),
    TextDim     = Color3.fromRGB(150, 150, 180),
    Success     = Color3.fromRGB(60, 220, 130),
    Danger      = Color3.fromRGB(255, 70, 90),
    Warning     = Color3.fromRGB(255, 180, 60),
}

local State = {
    AutoChest           = false,
    ChestsCollected     = 0,
    SessionStart        = os.clock(),
    AnimationsEnabled   = true,
    NotificationsEnabled= true,
    CollectRange        = 40,
}

--============================================================
-- HELPERS DE CRIAÇÃO
--============================================================
local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, c in ipairs(children or {}) do
        c.Parent = inst
    end
    return inst
end

local function corner(r)
    return create("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

local function stroke(color, thickness, transparency)
    return create("UIStroke", {
        Color = color or Theme.Accent,
        Thickness = thickness or 1,
        Transparency = transparency or 0.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function gradient(c1, c2, rotation)
    return create("UIGradient", {
        Color = ColorSequence.new(c1, c2),
        Rotation = rotation or 0,
    })
end

local function tween(obj, time, props, style, dir)
    if not State.AnimationsEnabled then
        for k, v in pairs(props) do obj[k] = v end
        return
    end
    local t = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

--============================================================
-- NOTIFICAÇÕES
--============================================================
local notifHolder

local function buildNotifHolder(parent)
    notifHolder = create("Frame", {
        Name = "Notifications",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 320, 1, -40),
        Position = UDim2.new(1, -340, 0, 20),
        Parent = parent,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Top,
        }),
    })
end

local function notify(text, color)
    if not State.NotificationsEnabled or not notifHolder then return end
    color = color or Theme.Accent

    local frame = create("Frame", {
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.05,
        Size = UDim2.new(1, 0, 0, 52),
        Position = UDim2.new(1, 60, 0, 0),
        Parent = notifHolder,
    }, {
        corner(10),
        stroke(color, 1, 0.4),
        gradient(Theme.Surface, Theme.Surface2, 90),
    })

    local bar = create("Frame", {
        BackgroundColor3 = color,
        Size = UDim2.new(0, 4, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        Parent = frame,
    }, { corner(3) })

    create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 16, 0, 0),
        Parent = frame,
    })

    tween(frame, 0.35, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)

    task.delay(3, function()
        local out = tween(frame, 0.3, {
            Position = UDim2.new(1, 60, 0, 0),
            BackgroundTransparency = 1,
        })
        if out then out.Completed:Wait() end
        frame:Destroy()
    end)
end

--============================================================
-- LÓGICA DE AUTO FARM (API OFICIAL)
--============================================================
local collectedPrompts = {}

local function isChestPrompt(prompt)
    -- Considera qualquer ProximityPrompt válido como baú.
    -- Ajuste o filtro conforme o jogo (ex: checar nome do parent).
    return prompt and prompt.Enabled and prompt.Parent
        and prompt.Parent:IsA("BasePart")
end

local function firePrompt(prompt)
    if collectedPrompts[prompt] then return end
    collectedPrompts[prompt] = true

    task.spawn(function()
        local ok, err = pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration or 0.1)
            prompt:InputHoldEnd()
        end)

        if ok then
            State.ChestsCollected += 1
            if UI and UI.Refresh then UI.Refresh() end
            notify("Baú coletado!  Total: " .. State.ChestsCollected, Theme.Success)
        else
            warn("[AutoFarm] Falha ao coletar prompt: " .. tostring(err))
            collectedPrompts[prompt] = nil
        end
    end)
end

-- Dispara ao entrar no alcance do prompt
ProximityPromptSvc.PromptShown:Connect(function(prompt)
    if not State.AutoChest then return end
    if not isChestPrompt(prompt) then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local part = prompt.Parent
    local dist = (part.Position - root.Position).Magnitude
    if dist <= State.CollectRange then
        firePrompt(prompt)
    end
end)

-- Fallback: varredura periódica para prompts já em alcance
task.spawn(function()
    while true do
        task.wait(0.75)
        if State.AutoChest then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and isChestPrompt(obj) then
                        local ok, dist = pcall(function()
                            return (obj.Parent.Position - root.Position).Magnitude
                        end)
                        if ok and dist <= State.CollectRange then
                            firePrompt(obj)
                        end
                    end
                end
            end
        end
    end
end)

--============================================================
-- CONSTRUÇÃO DA UI
--============================================================
local UI = { Refresh = function() end }

local screenGui = create("ScreenGui", {
    Name = "AutoFarmUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    Parent = PlayerGui,
})

-- ---------- JANELA PRINCIPAL ----------
local main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 620, 0, 430),
    BackgroundColor3 = Theme.Bg,
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    Parent = screenGui,
}, {
    corner(16),
    stroke(Theme.Accent, 1, 0.55),
    gradient(Theme.Bg, Theme.Surface, 115),
})

-- Sombra (simulada com frame atrás)
local shadow = create("Frame", {
    ZIndex = -1,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 6, 0.5, 10),
    Size = UDim2.new(1, 12, 1, 12),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.6,
    BorderSizePixel = 0,
    Parent = main,
}, { corner(20) })

buildNotifHolder(screenGui)

-- ---------- CABEÇALHO ----------
local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundTransparency = 1,
    Parent = main,
})

create("TextLabel", {
    BackgroundTransparency = 1,
    Text = "AUTO FARM",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 22, 0, 16),
    Size = UDim2.new(0, 200, 0, 24),
    Parent = header,
})

local accentDot = create("Frame", {
    BackgroundColor3 = Theme.Accent2,
    Size = UDim2.new(0, 8, 0, 8),
    Position = UDim2.new(0, 160, 0, 24),
    Parent = header,
}, { corner(4), gradient(Theme.Accent, Theme.Accent2, 45) })

-- Botões da janela (minimizar / fechar)
local function windowBtn(txt, xOff, color)
    local b = create("TextButton", {
        Text = txt,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.TextDim,
        BackgroundColor3 = Theme.Surface2,
        AutoButtonColor = false,
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, xOff, 0, 13),
        Parent = header,
    }, { corner(8) })

    b.MouseEnter:Connect(function()
        tween(b, 0.15, { BackgroundColor3 = color, TextColor3 = Theme.Text })
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.15, { BackgroundColor3 = Theme.Surface2, TextColor3 = Theme.TextDim })
    end)
    return b
end

local btnClose = windowBtn("✕", -38, Theme.Danger)
local btnMin   = windowBtn("–", -72, Theme.Warning)

-- ---------- ABAS ----------
local tabsBar = create("Frame", {
    Size = UDim2.new(1, -44, 0, 34),
    Position = UDim2.new(0, 22, 0, 60),
    BackgroundTransparency = 1,
    Parent = main,
}, {
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

local contentArea = create("Frame", {
    Size = UDim2.new(1, -44, 1, -166),
    Position = UDim2.new(0, 22, 0, 106),
    BackgroundColor3 = Theme.Surface,
    BackgroundTransparency = 0.25,
    Parent = main,
}, {
    corner(12),
    stroke(Theme.Accent, 1, 0.85),
})

local pages = {}
local tabButtons = {}
local activeTab

local function makeTab(name, order)
    local btn = create("TextButton", {
        Text = name,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = Theme.TextDim,
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.4,
        AutoButtonColor = false,
        Size = UDim2.new(0, 120, 1, 0),
        LayoutOrder = order,
        Parent = tabsBar,
    }, { corner(8) })

    local page = create("ScrollingFrame", {
        Size = UDim2.new(1, -24, 1, -24),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 1, 0),
        Visible = false,
        Parent = contentArea,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, 12),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    pages[name] = page
    tabButtons[name] = btn

    btn.MouseEnter:Connect(function()
        if activeTab ~= name then
            tween(btn, 0.15, { BackgroundTransparency = 0.15, TextColor3 = Theme.Text })
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= name then
            tween(btn, 0.15, { BackgroundTransparency = 0.4, TextColor3 = Theme.TextDim })
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if activeTab == name then return end
        for n, p in pairs(pages) do
            p.Visible = (n == name)
            local t = tabButtons[n]
            tween(t, 0.2, { BackgroundTransparency = 0.4, TextColor3 = Theme.TextDim })
        end
        activeTab = name
        tween(btn, 0.2, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
    end)

    return page
end

--============================================================
-- COMPONENTES REUTILIZÁVEIS
--============================================================
local function sectionTitle(text, order)
    return create("TextLabel", {
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.TextDim,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = order or 1,
    })
end

local function makeButton(text, order, accent)
    accent = accent or Theme.Accent
    local btn = create("TextButton", {
        Text = text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.Surface2,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 44),
        LayoutOrder = order or 1,
    }, {
        corner(10),
        stroke(accent, 1, 0.6),
    })

    btn.MouseEnter:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = Theme.Surface2:Lerp(accent, 0.15) })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = btn:GetAttribute("Active") and accent or Theme.Surface2 })
    end)
    return btn
end

--============================================================
-- ABA PRINCIPAL
--============================================================
local pageMain = makeTab("Principal", 1)

sectionTitle("CONTROLES", 1).Parent = pageMain

-- Botão Auto Baús
local btnAuto = makeButton("Ativar Auto Baús", 2, Theme.Accent)
btnAuto.Parent = pageMain

-- Status + contador
local statusCard = create("Frame", {
    Size = UDim2.new(1, 0, 0, 90),
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.35,
    LayoutOrder = 3,
    Parent = pageMain,
}, { corner(10), stroke(Theme.Accent2, 1, 0.75) })

local statusDot = create("Frame", {
    BackgroundColor3 = Theme.Danger,
    Size = UDim2.new(0, 10, 0, 10),
    Position = UDim2.new(0, 16, 0, 22),
    Parent = statusCard,
}, { corner(5) })

local lblStatus = create("TextLabel", {
    Text = "Desativado",
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 34, 0, 14),
    Size = UDim2.new(0.6, 0, 0, 24),
    Parent = statusCard,
})

local lblCount = create("TextLabel", {
    Text = "Baús: 0",
    Font = Enum.Font.GothamMedium,
    TextSize = 13,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 16, 0, 50),
    Size = UDim2.new(1, -32, 0, 20),
    Parent = statusCard,
})

-- Botão Parar Farm
local btnStop = makeButton("Parar Farm", 4, Theme.Danger)
btnStop.Parent = pageMain

-- Função de refresh
UI.Refresh = function()
    lblCount.Text = "Baús: " .. State.ChestsCollected
    lblStatus.Text = State.AutoChest and "Ativo" or "Desativado"
    statusDot.BackgroundColor3 = State.AutoChest and Theme.Success or Theme.Danger
    btnAuto.Text = State.AutoChest and "Desativar Auto Baús" or "Ativar Auto Baús"
    btnAuto:SetAttribute("Active", State.AutoChest)
    tween(btnAuto, 0.25, {
        BackgroundColor3 = State.AutoChest and Theme.Accent or Theme.Surface2
    })

    if UI.UpdateStats then UI.UpdateStats() end
end

btnAuto.MouseButton1Click:Connect(function()
    State.AutoChest = not State.AutoChest
    if State.AutoChest then
        State.SessionStart = State.SessionStart or os.clock()
        notify("Auto Baús ativado", Theme.Success)
    else
        notify("Auto Baús desativado", Theme.Warning)
    end
    UI.Refresh()
end)

btnStop.MouseButton1Click:Connect(function()
    if not State.AutoChest then
        notify("O farm já está parado", Theme.TextDim)
        return
    end
    State.AutoChest = false
    collectedPrompts = {}
    notify("Farm interrompido", Theme.Danger)
    UI.Refresh()
end)

--============================================================
-- ABA ESTATÍSTICAS
--============================================================
local pageStats = makeTab("Estatísticas", 2)
sectionTitle("RESUMO DA SESSÃO", 1).Parent = pageStats

local lblStatChests = create("TextLabel", {
    Text = "Baús coletados: 0",
    Font = Enum.Font.GothamSemibold,
    TextSize = 15,
    TextColor3 = Theme.Text,
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.35,
    TextXAlignment = Enum.TextXAlignment.Left,
    Size = UDim2.new(1, 0, 0, 42),
    LayoutOrder = 2,
    Parent = pageStats,
}, { corner(10) })
lblStatChests.Text = "   Baús coletados: 0"

local lblStatTime = create("TextLabel", {
    Text = "   Tempo ativo: 00:00:00",
    Font = Enum.Font.GothamSemibold,
    TextSize = 15,
    TextColor3 = Theme.Text,
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.35,
    TextXAlignment = Enum.TextXAlignment.Left,
    Size = UDim2.new(1, 0, 0, 42),
    LayoutOrder = 3,
    Parent = pageStats,
}, { corner(10) })

local lblStatRate = create("TextLabel", {
    Text = "   Baús por minuto: 0.0",
    Font = Enum.Font.GothamSemibold,
    TextSize = 15,
    TextColor3 = Theme.Text,
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.35,
    TextXAlignment = Enum.TextXAlignment.Left,
    Size = UDim2.new(1, 0, 0, 42),
    LayoutOrder = 4,
    Parent = pageStats,
}, { corner(10) })

local function formatTime(sec)
    sec = math.floor(sec)
    return string.format("%02d:%02d:%02d", math.floor(sec/3600), math.floor(sec%3600/60), sec%60)
end

UI.UpdateStats = function()
    local elapsed = os.clock() - State.SessionStart
    lblStatChests.Text = "   Baús coletados: " .. State.ChestsCollected
    lblStatTime.Text   = "   Tempo ativo: " .. formatTime(elapsed)
    local mins = math.max(elapsed / 60, 1/60)
    lblStatRate.Text   = string.format("   Baús por minuto: %.1f", State.ChestsCollected / mins)
end

RunService.Heartbeat:Connect(function()
    if tick() % 0.5 < 0.02 then
        UI.UpdateStats()
    end
end)

--============================================================
-- ABA CONFIGURAÇÕES
--============================================================
local pageCfg = makeTab("Configurações", 3)
sectionTitle("PREFERÊNCIAS", 1).Parent = pageCfg

local function makeToggle(text, order, getter, setter)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0.35,
        LayoutOrder = order,
        Parent = pageCfg,
    }, { corner(10), stroke(Theme.Accent2, 1, 0.85) })

    create("TextLabel", {
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0.7, 0, 1, 0),
        Parent = row,
    })

    local switch = create("Frame", {
        BackgroundColor3 = getter() and Theme.Success or Theme.Danger,
        Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -60, 0.5, -11),
        Parent = row,
    }, { corner(11) })

    local knob = create("Frame", {
        BackgroundColor3 = Theme.Text,
        Size = UDim2.new(0, 16, 0, 16),
        Position = getter() and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        Parent = switch,
    }, { corner(8) })

    local btn = create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = switch,
    })

    btn.MouseButton1Click:Connect(function()
        local newVal = not getter()
        setter(newVal)
        tween(switch, 0.2, { BackgroundColor3 = newVal and Theme.Success or Theme.Danger })
        tween(knob, 0.2, {
            Position = newVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        })
    end)
end

makeToggle("Animações suaves", 2,
    function() return State.AnimationsEnabled end,
    function(v) State.AnimationsEnabled = v end)

makeToggle("Notificações", 3,
    function() return State.NotificationsEnabled end,
    function(v) State.NotificationsEnabled = v end)

-- Slider de alcance
local rangeRow = create("Frame", {
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.35,
    LayoutOrder = 4,
    Parent = pageCfg,
}, { corner(10), stroke(Theme.Accent, 1, 0.85) })

create("TextLabel", {
    Text = "Alcance de coleta",
    Font = Enum.Font.GothamMedium,
    TextSize = 14,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 16, 0, 8),
    Size = UDim2.new(0.6, 0, 0, 20),
    Parent = rangeRow,
})

local lblRange = create("TextLabel", {
    Text = tostring(State.CollectRange) .. " studs",
    Font = Enum.Font.GothamSemibold,
    TextSize = 13,
    TextColor3 = Theme.Accent,
    BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -120, 0, 8),
    Size = UDim2.new(0, 104, 0, 20),
    Parent = rangeRow,
})

local sliderBg = create("Frame", {
    BackgroundColor3 = Theme.Bg,
    Size = UDim2.new(1, -32, 0, 6),
    Position = UDim2.new(0, 16, 1, -18),
    Parent = rangeRow,
}, { corner(3) })

local sliderFill = create("Frame", {
    BackgroundColor3 = Theme.Accent,
    Size = UDim2.new((State.CollectRange - 5) / 95, 0, 1, 0),
    Parent = sliderBg,
}, { corner(3), gradient(Theme.Accent, Theme.Accent2, 0) })

local sliderHit = create("TextButton", {
    Text = "",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 3, 0),
    Position = UDim2.new(0, 0, -1, 0),
    Parent = sliderBg,
})

local dragging = false
local function updateSlider(x)
    local rel = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
    State.CollectRange = math.floor(5 + rel * 95)
    sliderFill.Size = UDim2.new(rel, 0, 1, 0)
    lblRange.Text = State.CollectRange .. " studs"
end

sliderHit.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
       or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        updateSlider(i.Position.X)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
       or i.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(i.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
       or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--============================================================
-- ABA SOBRE
--============================================================
local pageAbout = makeTab("Sobre", 4)
sectionTitle("INFORMAÇÕES", 1).Parent = pageAbout

create("TextLabel", {
    Text = "Auto Farm Premium",
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 30),
    LayoutOrder = 2,
    Parent = pageAbout,
})

create("TextLabel", {
    Text = "Versão 1.0.0\n\nScript de coleta automática de baús por proximidade.\nUtiliza a API oficial ProximityPromptService.\nUso permitido apenas em ambientes autorizados.",
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Size = UDim2.new(1, 0, 0, 140),
    LayoutOrder = 3,
    Parent = pageAbout,
})

--============================================================
-- DRAG DA JANELA
--============================================================
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--============================================================
-- MINIMIZAR / FECHAR
--============================================================
local minimized = false
btnMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    local targetSize = minimized and UDim2.new(0, 240, 0, 54) or UDim2.new(0, 620, 0, 430)
    tween(main, 0.3, { Size = targetSize }, Enum.EasingStyle.Quint)
    contentArea.Visible = not minimized
    tabsBar.Visible = not minimized
    btnMin.Text = minimized and "+" or "–"
end)

btnClose.MouseButton1Click:Connect(function()
    tween(main, 0.25, {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
    }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    task.wait(0.3)
    screenGui:Destroy()
end)

--============================================================
-- ANIMAÇÃO DE ENTRADA
--============================================================
main.Size = UDim2.new(0, 0, 0, 0)
tween(main, 0.45, { Size = UDim2.new(0, 620, 0, 430) }, Enum.EasingStyle.Back)

-- Ativa primeira aba
tabButtons["Principal"].MouseButton1Click:Fire? nil
for n, p in pairs(pages) do p.Visible = (n == "Principal") end
activeTab = "Principal"
tween(tabButtons["Principal"], 0.2, { BackgroundTransparency = 0, TextColor3 = Theme.Text })

UI.Refresh()
UI.UpdateStats()
notify("Auto Farm Premium carregado", Theme.Accent2)

return UI
