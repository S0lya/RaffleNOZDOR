-- Модуль истории победителей
NozdorRaffleHistory = NozdorRaffleHistory or {}

local History = {}

function History:Add(winner, prize)
    table.insert(NozdorRaffleHistory, {
        winner = tostring(winner),
        timestamp = date("%d.%m.%Y %H:%M:%S"),
        confirmed = false,
        prize = prize,
    })
end

function History:MarkConfirmed(winner)
    if not NozdorRaffleHistory or #NozdorRaffleHistory == 0 then return end
    for i = #NozdorRaffleHistory, 1, -1 do
        local e = NozdorRaffleHistory[i]
        if e.winner == winner and e.confirmed == false then
            e.confirmed = true
            e.confirmedAt = date("%d.%m.%Y %H:%M:%S")
            return
        end
    end
end

function History:GetAll()
    return NozdorRaffleHistory
end

function History:Clear()
    for i = #NozdorRaffleHistory, 1, -1 do
        table.remove(NozdorRaffleHistory, i)
    end
end

function History:Trim(max)
    max = max or 100
    local n = #NozdorRaffleHistory
    if n > max then
        for i = 1, n - max do
            table.remove(NozdorRaffleHistory, 1)
        end
    end
end

NozdorHistory = History
