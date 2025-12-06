-- Простой логгер для сохранения событий аддона в SavedVariables
NozdorRaffleLogs = NozdorRaffleLogs or {}

local function timestamp()
    return date("%Y-%m-%d %H:%M:%S")
end

function NozdorLog(event, data)
    local entry = {
        t = timestamp(),
        e = tostring(event),
        d = data,
    }
    table.insert(NozdorRaffleLogs, entry)
    -- Дублируем в чат только если дебаг включён
    if NozdorRaffleDebug then
        local msg = string.format("[LOG] %s | %s | %s", entry.t, entry.e, tostring(data))
        print(msg)
    end
end

-- Утилита: ограничить размер лога (например, до 500 записей)
function NozdorLog_Trim(max)
    max = max or 500
    local n = #NozdorRaffleLogs
    if n > max then
        for i = 1, n - max do
            table.remove(NozdorRaffleLogs, 1)
        end
    end
end
