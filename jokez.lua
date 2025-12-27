-- auto_reload_map.lua
-- Автоматически перезагружает карту каждые 10 секунд, пока не остановят командой !stoprel

if SERVER then
    local shouldReload = true
    local reloadTimerName = "AutoReloadMapTimer"
    
    -- Функция перезагрузки карты
    local function ReloadCurrentMap()
        if not shouldReload then return end
        
        local currentMap = game.GetMap()
        print("[AutoReload] Перезагружаем карту: " .. currentMap)
        
        -- Уведомление в чат перед перезагрузкой
        for _, ply in ipairs(player.GetAll()) do
            ply:PrintMessage(HUD_PRINTTALK, "[Система] Автоперезагрузка карты через 3 секунды...")
        end
        
        -- Задержка перед перезагрузкой
        timer.Simple(3, function()
            if shouldReload then
                RunConsoleCommand("changelevel", currentMap)
            end
        end)
    end
    
    -- Запуск автоматической перезагрузки
    hook.Add("InitPostEntity", "StartAutoReload", function()
        print("[AutoReload] Система автоперезагрузки запущена")
        print("[AutoReload] Для остановки введите !stoprel в чат")
        
        -- Запускаем таймер с интервалом 10 секунд
        timer.Create(reloadTimerName, 10, 0, ReloadCurrentMap)
        
        -- Первая перезагрузка через 10 секунд после старта
        timer.Simple(10, ReloadCurrentMap)
    end)
    
    -- Обработка чат-команд
    hook.Add("PlayerSay", "AutoReloadChatCommands", function(ply, text)
        local cmd = string.lower(text)
        
        -- Команда остановки
        if cmd == "!stoprel" or cmd == "/stoprel" then
            if ply:IsAdmin() then
                shouldReload = false
                timer.Remove(reloadTimerName)
                
                -- Уведомление всем игрокам
                for _, target in ipairs(player.GetAll()) do
                    target:PrintMessage(HUD_PRINTTALK, "[Система] Автоперезагрузка остановлена администратором " .. ply:Nick())
                end
                print("[AutoReload] Автоперезагрузка остановлена администратором " .. ply:Nick())
            else
                ply:PrintMessage(HUD_PRINTTALK, "[Система] Требуются права администратора!")
            end
            return ""
        end
        
        -- Команда возобновления
        if cmd == "!startrel" or cmd == "/startrel" then
            if ply:IsAdmin() then
                shouldReload = true
                if not timer.Exists(reloadTimerName) then
                    timer.Create(reloadTimerName, 10, 0, ReloadCurrentMap)
                end
                
                -- Уведомление всем игрокам
                for _, target in ipairs(player.GetAll()) do
                    target:PrintMessage(HUD_PRINTTALK, "[Система] Автоперезагрузка возобновлена администратором " .. ply:Nick())
                end
                print("[AutoReload] Автоперезагрузка возобновлена администратором " .. ply:Nick())
                
                -- Сразу запускаем перезагрузку
                ReloadCurrentMap()
            else
                ply:PrintMessage(HUD_PRINTTALK, "[Система] Требуются права администратора!")
            end
            return ""
        end
        
        -- Команда статуса
        if cmd == "!relstatus" or cmd == "/relstatus" then
            local status = shouldReload and "АКТИВНА" or "ОСТАНОВЛЕНА"
            local nextReload = timer.Exists(reloadTimerName) and "Следующая перезагрузка через " .. math.Round(timer.TimeLeft(reloadTimerName) or 0) .. " сек" or "ТАЙМЕР ОСТАНОВЛЕН"
            ply:PrintMessage(HUD_PRINTTALK, "[Система] Автоперезагрузка: " .. status)
            ply:PrintMessage(HUD_PRINTTALK, "[Система] " .. nextReload)
            return ""
        end
    end)
    
    -- Остановка таймера при смене карты (на всякий случай)
    hook.Add("PostGamemodeLoaded", "CleanupAutoReload", function()
        timer.Remove(reloadTimerName)
        shouldReload = true
    end)
end
