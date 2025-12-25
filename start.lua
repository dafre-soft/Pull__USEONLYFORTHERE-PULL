-- =============================================
-- Extended Chat System v2.0
-- Автоматическая установка: Положите в lua/autorun/
-- =============================================

if SERVER then
    AddCSLuaFile()
    return
end

-- Глобальная таблица системы чата
MessageChatService = MessageChatService or {
    Modules = {},
    Commands = {},
    Config = {
        Position = {x = ScrW() / 2 - 250, y = ScrH() - 300},
        Size = {w = 500, h = 200},
        InputHeight = 25,
        MaxMessages = 50,
        ChatKey = KEY_T,
        ConfigKey = KEY_F11,
        DefaultColor = Color(255, 255, 255),
        TimeFormat = "%H:%M:%S"
    },
    History = {},
    IsOpen = false,
    ConfigWindow = nil,
    ActiveModule = "all"
}

-- Основные утилиты
local function Base64Encode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
        return b:sub(c+1, c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function Base64Decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b:find(x)-1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- Основной UI чата
local chatPanel = nil
local chatInput = nil
local chatMessages = {}

function MessageChatService:CreateChatPanel()
    if IsValid(chatPanel) then chatPanel:Remove() end
    
    -- Основной фрейм чата
    chatPanel = vgui.Create("DFrame")
    chatPanel:SetSize(self.Config.Size.w, self.Config.Size.h)
    chatPanel:SetPos(self.Config.Position.x, self.Config.Position.y)
    chatPanel:SetTitle("")
    chatPanel:SetDraggable(true)
    chatPanel:ShowCloseButton(false)
    chatPanel:SetVisible(false)
    chatPanel.Paint = function(self, w, h)
        -- Фон с прозрачностью
        draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 200))
        -- Обводка
        surface.SetDrawColor(100, 100, 100, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end
    
    -- Поле для сообщений
    local messagePanel = vgui.Create("RichText", chatPanel)
    messagePanel:Dock(FILL)
    messagePanel:DockMargin(5, 5, 5, 5)
    messagePanel:SetVerticalScrollbarEnabled(true)
    messagePanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 200))
    end
    
    -- Поле ввода
    chatInput = vgui.Create("DTextEntry", chatPanel)
    chatInput:Dock(BOTTOM)
    chatInput:SetTall(self.Config.InputHeight)
    chatInput:DockMargin(5, 0, 5, 5)
    chatInput:SetPlaceholderText("Напишите сообщение...")
    chatInput.OnEnter = function(self)
        local text = self:GetValue()
        if text ~= "" then
            MessageChatService:SendMessage(text)
            self:SetText("")
            self:OnLoseFocus()
        end
    end
    chatInput.OnKeyCodePressed = function(self, key)
        if key == KEY_ESCAPE then
            MessageChatService:HideChat()
            gui.EnableScreenClicker(false)
        end
        if key == KEY_TAB then
            MessageChatService:CycleModules()
            return true
        end
    end
    
    -- Сохраняем ссылки
    self.ChatPanel = chatPanel
    self.MessagePanel = messagePanel
    self.ChatInput = chatInput
end

function MessageChatService:AddMessage(text, color)
    if not IsValid(self.MessagePanel) then return end
    
    color = color or self.Config.DefaultColor
    
    -- Добавляем время
    local timeText = os.date(self.Config.TimeFormat) .. " "
    self.MessagePanel:InsertColorChange(150, 150, 150, 255)
    self.MessagePanel:AppendText(timeText)
    
    -- Добавляем сообщение
    self.MessagePanel:InsertColorChange(color.r, color.g, color.b, color.a)
    self.MessagePanel:AppendText(text .. "\n")
    
    -- Прокручиваем вниз
    self.MessagePanel:GotoTextEnd()
    
    -- Сохраняем в историю
    table.insert(self.History, {
        time = os.time(),
        text = text,
        color = color
    })
    
    if #self.History > self.Config.MaxMessages then
        table.remove(self.History, 1)
    end
end

function MessageChatService:ShowChat()
    self.IsOpen = true
    if IsValid(self.ChatPanel) then
        self.ChatPanel:SetVisible(true)
        self.ChatPanel:MakePopup()
        self.ChatInput:RequestFocus()
    end
end

function MessageChatService:HideChat()
    self.IsOpen = false
    if IsValid(self.ChatPanel) then
        self.ChatPanel:SetVisible(false)
        gui.EnableScreenClicker(false)
    end
end

function MessageChatService:ToggleChat()
    if self.IsOpen then
        self:HideChat()
    else
        self:ShowChat()
    end
end

-- Система модулей
function MessageChatService:RegisterModule(name, module)
    self.Modules[name] = module
    if module.Initialize then
        module:Initialize(self)
    end
    self:AddMessage("Модуль '" .. name .. "' загружен", Color(0, 255, 0))
end

function MessageChatService:UnregisterModule(name)
    if self.Modules[name] and self.Modules[name].Shutdown then
        self.Modules[name]:Shutdown(self)
    end
    self.Modules[name] = nil
end

function MessageChatService:ProcessMessage(text)
    local processed = text
    local blocked = false
    
    for name, module in pairs(self.Modules) do
        if module.OnMessage then
            local result, shouldBlock = module:OnMessage(self, processed)
            if result then processed = result end
            if shouldBlock then blocked = true end
        end
    end
    
    return processed, blocked
end

-- Система команд
function MessageChatService:RegisterCommand(cmd, callback, description, module)
    self.Commands[cmd] = {
        callback = callback,
        description = description or "Без описания",
        module = module or "system"
    }
end

function MessageChatService:ExecuteCommand(cmd, args)
    if self.Commands[cmd] then
        return self.Commands[cmd].callback(self, args)
    end
    
    for _, module in pairs(self.Modules) do
        if module.OnCommand then
            local result = module:OnCommand(self, cmd, args)
            if result then return true end
        end
    end
    
    return false
end

-- Основная функция отправки сообщения
function MessageChatService:SendMessage(text)
    -- Проверка на команды
    if string.StartWith(text, "/") then
        local parts = string.Explode(" ", string.sub(text, 2))
        local cmd = table.remove(parts, 1)
        if self:ExecuteCommand(cmd, parts) then
            return
        end
    end
    
    -- Обработка через модули
    local processed, blocked = self:ProcessMessage(text)
    
    if blocked then
        self:AddMessage("Сообщение заблокировано", Color(255, 100, 100))
        return
    end
    
    -- Отправка на сервер
    if processed and processed ~= "" then
        LocalPlayer():ConCommand("say \"" .. processed .. "\"")
    end
end

-- Окно конфигурации
function MessageChatService:CreateConfigWindow()
    if IsValid(self.ConfigWindow) then
        self.ConfigWindow:Remove()
        return
    end
    
    local frame = vgui.Create("DFrame")
    frame:SetSize(600, 400)
    frame:SetTitle("Конфигурация чата")
    frame:Center()
    frame:MakePopup()
    
    local configText = vgui.Create("DTextEntry", frame)
    configText:Dock(FILL)
    configText:DockMargin(10, 40, 10, 10)
    configText:SetMultiline(true)
    configText:SetText(self:ExportConfig())
    
    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:Dock(BOTTOM)
    saveBtn:SetTall(30)
    saveBtn:DockMargin(10, 0, 10, 10)
    saveBtn:SetText("Сохранить конфиг")
    saveBtn.DoClick = function()
        self:ImportConfig(configText:GetText())
        frame:Close()
    end
    
    local loadBtn = vgui.Create("DButton", frame)
    loadBtn:Dock(BOTTOM)
    loadBtn:SetTall(30)
    loadBtn:DockMargin(10, 0, 10, 10)
    loadBtn:SetText("Загрузить из буфера")
    loadBtn.DoClick = function()
        SetClipboardText(self:ExportConfig())
        self:AddMessage("Конфиг скопирован в буфер", Color(0, 255, 0))
    end
    
    self.ConfigWindow = frame
end

function MessageChatService:ExportConfig()
    local config = {
        position = self.Config.Position,
        size = self.Config.Size,
        modules = {}
    }
    
    for name, module in pairs(self.Modules) do
        if module.ExportConfig then
            config.modules[name] = module:ExportConfig()
        end
    end
    
    local json = util.TableToJSON(config, true)
    return Base64Encode(json)
end

function MessageChatService:ImportConfig(b64)
    local success, json = pcall(Base64Decode, b64)
    if not success then
        self:AddMessage("Ошибка декодирования конфига", Color(255, 0, 0))
        return
    end
    
    local config = util.JSONToTable(json)
    if not config then
        self:AddMessage("Ошибка парсинга конфига", Color(255, 0, 0))
        return
    end
    
    self.Config.Position = config.position or self.Config.Position
    self.Config.Size = config.size or self.Config.Size
    
    for name, moduleConfig in pairs(config.modules or {}) do
        if self.Modules[name] and self.Modules[name].ImportConfig then
            self.Modules[name]:ImportConfig(moduleConfig)
        end
    end
    
    -- Обновляем позицию чата
    if IsValid(self.ChatPanel) then
        self.ChatPanel:SetPos(self.Config.Position.x, self.Config.Position.y)
        self.ChatPanel:SetSize(self.Config.Size.w, self.Config.Size.h)
    end
    
    self:AddMessage("Конфигурация загружена", Color(0, 255, 0))
end

-- Хук для внешнего использования
function MessageChatService:RegisterHook(hookName, callback)
    hook.Add(hookName, "MessageChatService_" .. hookName, callback)
end

function MessageChatService:CallHook(hookName, ...)
    return hook.Run(hookName, ...)
end

-- =============================================
-- Встроенные модули
-- =============================================

-- Модуль эмоций
local EmotesModule = {
    Name = "Emotes",
    Commands = {
        ["me"] = {
            pattern = "/me (.+)",
            callback = function(self, text)
                local ply = LocalPlayer()
                return Color(255, 200, 0), "* " .. ply:Nick() .. " " .. text
            end,
            desc = "Описание действия"
        },
        ["ooc"] = {
            pattern = "/ooc (.+)",
            callback = function(self, text)
                return Color(150, 150, 255), "[OOC] " .. text
            end,
            desc = "Внеигровой чат"
        },
        ["roll"] = {
            pattern = "/roll",
            callback = function(self)
                local roll = math.random(1, 100)
                return Color(200, 255, 200), "🎲 " .. LocalPlayer():Nick() .. " выкинул " .. roll
            end,
            desc = "Бросок кубика (1-100)"
        }
    }
}

function EmotesModule:Initialize(mcs)
    for cmd, data in pairs(self.Commands) do
        mcs:RegisterCommand(cmd, function(mcs, args)
            if data.callback then
                local color, text = data.callback(mcs, table.concat(args, " "))
                mcs:AddMessage(text, color)
            end
            return true
        end, data.desc, self.Name)
    end
end

function EmotesModule:OnMessage(mcs, text)
    for _, data in pairs(self.Commands) do
        if string.match(text, data.pattern) then
            return "", true -- Блокируем стандартное сообщение
        end
    end
end

-- Модуль админ-чата
local AdminModule = {
    Name = "Admin",
    Admins = {},
    Prefix = "@"
}

function AdminModule:Initialize(mcs)
    -- Определяем админов
    timer.Simple(1, function()
        for _, ply in pairs(player.GetAll()) do
            if ply:IsAdmin() then
                self.Admins[ply:SteamID()] = true
            end
        end
    end)
    
    mcs:RegisterCommand("admin", function(mcs, args)
        if not LocalPlayer():IsAdmin() then
            mcs:AddMessage("Нет доступа к админ-чату", Color(255, 100, 100))
            return true
        end
        
        local msg = table.concat(args, " ")
        net.Start("MessageChatService_AdminMsg")
            net.WriteString(msg)
        net.SendToServer()
        return true
    end, "Отправить сообщение админам", self.Name)
end

function AdminModule:OnMessage(mcs, text)
    if string.StartWith(text, self.Prefix) then
        local msg = string.sub(text, 2)
        mcs:ExecuteCommand("admin", {msg})
        return "", true
    end
end

-- Модуль форматирования
local FormatModule = {
    Name = "Format",
    Colors = {
        ["/red"] = Color(255, 100, 100),
        ["/green"] = Color(100, 255, 100),
        ["/blue"] = Color(100, 100, 255),
        ["/yellow"] = Color(255, 255, 100)
    }
}

function FormatModule:Initialize(mcs)
    for cmd, color in pairs(self.Colors) do
        mcs:RegisterCommand(string.sub(cmd, 2), function(mcs, args)
            mcs:AddMessage(table.concat(args, " "), color)
            return true
        end, "Цвет: " .. string.sub(cmd, 2), self.Name)
    end
end

-- Модуль уведомлений
local NotifyModule = {
    Name = "Notify",
    Sounds = {
        message = "buttons/button15.wav",
        error = "buttons/button8.wav",
        success = "buttons/button14.wav"
    }
}

function NotifyModule:Initialize(mcs)
    mcs:RegisterCommand("notify", function(mcs, args)
        local type = args[1] or "message"
        local text = table.concat(args, " ", 2)
        
        surface.PlaySound(self.Sounds[type] or self.Sounds.message)
        mcs:AddMessage("[Уведомление] " .. text, Color(255, 200, 100))
        return true
    end, "Уведомление: notify <type> <text>", self.Name)
end

-- =============================================
-- Сетевые сообщения
-- =============================================
if SERVER then
    util.AddNetworkString("MessageChatService_AdminMsg")
    
    net.Receive("MessageChatService_AdminMsg", function(len, ply)
        if not ply:IsAdmin() then return end
        
        local msg = net.ReadString()
        
        for _, admin in pairs(player.GetAll()) do
            if admin:IsAdmin() then
                admin:ChatPrint(Color(255, 50, 50), "[ADMIN] " .. ply:Name() .. ": " .. msg)
            end
        end
    end)
else
    -- Клиентская часть сетевых сообщений
    net.Receive("MessageChatService_AdminMsg", function()
        local sender = net.ReadEntity()
        local msg = net.ReadString()
        
        MessageChatService:AddMessage("[ADMIN] " .. sender:Name() .. ": " .. msg, Color(255, 50, 50))
    end)
end

-- =============================================
-- Инициализация
-- =============================================
local function InitializeChatSystem()
    -- Создаем UI
    MessageChatService:CreateChatPanel()
    
    -- Регистрируем модули
    MessageChatService:RegisterModule("emotes", EmotesModule)
    MessageChatService:RegisterModule("admin", AdminModule)
    MessageChatService:RegisterModule("format", FormatModule)
    MessageChatService:RegisterModule("notify", NotifyModule)
    
    -- Регистрируем системные команды
    MessageChatService:RegisterCommand("help", function(mcs, args)
        mcs:AddMessage("=== Доступные команды ===", Color(100, 255, 255))
        for cmd, data in pairs(mcs.Commands) do
            mcs:AddMessage("/" .. cmd .. " - " .. data.description, Color(200, 200, 255))
        end
        return true
    end, "Показать список команд")
    
    MessageChatService:RegisterCommand("clear", function(mcs, args)
        if IsValid(mcs.MessagePanel) then
            mcs.MessagePanel:SetText("")
            mcs.History = {}
        end
        return true
    end, "Очистить чат")
    
    MessageChatService:RegisterCommand("config", function(mcs, args)
        mcs:CreateConfigWindow()
        return true
    end, "Открыть конфигурацию")
    
    -- Хуки клавиш
    local keyCooldown = 0
    hook.Add("Think", "MessageChatService_KeyHandler", function()
        if keyCooldown > CurTime() then return end
        
        if input.IsKeyDown(MessageChatService.Config.ChatKey) then
            MessageChatService:ToggleChat()
            keyCooldown = CurTime() + 0.5
        end
        
        if input.IsKeyDown(MessageChatService.Config.ConfigKey) then
            MessageChatService:CreateConfigWindow()
            keyCooldown = CurTime() + 1
        end
    end)
    
    -- Перехват стандартного чата
    hook.Add("OnPlayerChat", "MessageChatService_Override", function(ply, text, teamChat)
        if ply == LocalPlayer() then
            -- Сообщения от локального игрока обрабатываются нашей системой
            return true
        end
        
        -- Показываем сообщения от других игроков
        local color = team.GetColor(ply:Team())
        MessageChatService:AddMessage(ply:Name() .. ": " .. text, color)
        
        -- Проигрываем звук
        if IsValid(MessageChatService.ChatPanel) and not MessageChatService.ChatPanel:IsVisible() then
            surface.PlaySound("buttons/button15.wav")
        end
        
        return true
    end)
    
    -- Сообщение о загрузке
    timer.Simple(1, function()
        MessageChatService:AddMessage("Расширенный чат загружен! Нажмите " .. 
            input.GetKeyName(MessageChatService.Config.ChatKey) .. 
            " для открытия чата", Color(100, 255, 100))
        MessageChatService:AddMessage("Нажмите " .. 
            input.GetKeyName(MessageChatService.Config.ConfigKey) .. 
            " для настройки", Color(100, 200, 255))
    end)
    
    -- Экспортируем глобально
    _G.MessageChatService = MessageChatService
    
    print("[MessageChatService] Система чата инициализирована!")
end

-- Запуск при загрузке клиента
hook.Add("InitPostEntity", "MessageChatService_Init", InitializeChatSystem)

-- Если игра уже загружена
if IsValid(LocalPlayer()) then
    InitializeChatSystem()
end
