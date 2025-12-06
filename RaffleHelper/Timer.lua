-- Simple countdown timer module for WoW Lua
-- Exposes global NozdorTimer with Start/Cancel

NozdorTimer = NozdorTimer or {}
NozdorTimer._frame = NozdorTimer._frame or CreateFrame("Frame")

function NozdorTimer:Start(durationSeconds, onTick, onEnd, opts)
    if self._active then self:Cancel() end
    self._active = true
    self._paused = false
    self._duration = tonumber(durationSeconds) or 0
    if self._duration <= 0 then
        print(string.format("[DEBUG][Timer.Start] invalid duration '%s', forcing to 30", tostring(durationSeconds)))
        self._duration = 30
    end
    self._total = self._duration
    self._startTime = GetTime()
    self._pausedTime = 0
    self._pauseStartTime = nil
    self._onTick = onTick
    self._onEnd = onEnd
    self._onStart = opts and opts.onStart or nil
    self._onHalf = opts and opts.onHalf or nil
    self._halfFired = false
    self._lastTick = self._duration

    if NozdorRaffleDebug then
        print(string.format("[DEBUG][Timer.Start] duration=%s total=%s startTime=%.3f", tostring(durationSeconds), tostring(self._total), tonumber(self._startTime)))
    end

    if self._onStart then pcall(self._onStart, self._total) end

    local function attachUpdate()
        self._frame:SetScript("OnUpdate", function()
            if not self._active then return end
            if self._paused then return end
            
            -- Defensive: ensure duration and startTime are sane
            if (not self._duration) or self._duration <= 0 then
                self._duration = self._total and self._total > 0 and self._total or 30
            end
            if (not self._startTime) or self._startTime <= 0 then
                self._startTime = GetTime()
            end

            local elapsed = GetTime() - self._startTime - self._pausedTime
            local remaining = math.max(0, self._duration - elapsed)
            local remainingInt = math.ceil(remaining)

            -- debug tick
            if remainingInt ~= self._lastTick and NozdorRaffleDebug then
                print(string.format("[DEBUG][Timer.Tick] elapsed=%.3f pausedTime=%.3f remaining=%.3f int=%d", tonumber(elapsed), tonumber(self._pausedTime), tonumber(remaining), tonumber(remainingInt)))
            end
            
            if remainingInt ~= self._lastTick and remainingInt >= 0 then
                self._lastTick = remainingInt
                if self._onTick then pcall(self._onTick, remainingInt) end
                
                if not self._halfFired and self._total > 0 and remainingInt <= math.floor(self._total / 2) then
                    self._halfFired = true
                    if self._onHalf then pcall(self._onHalf, remainingInt) end
                end
            end
            
            -- Prevent instant finish due to any stale state: require at least 0.2s elapsed
            if remaining <= 0 and elapsed > 0.2 then
                self._active = false
                self._frame:SetScript("OnUpdate", nil)
                if self._onEnd then pcall(self._onEnd) end
            end
        end)
    end

    self._attachUpdate = attachUpdate
    attachUpdate()
end

function NozdorTimer:Pause()
    if self._active and not self._paused then
        self._paused = true
        self._pauseStartTime = GetTime()
        if self._frame then self._frame:SetScript("OnUpdate", nil) end
    end
end

function NozdorTimer:Resume()
    if self._active and self._paused then
        self._paused = false
        if self._pauseStartTime then
            self._pausedTime = self._pausedTime + (GetTime() - self._pauseStartTime)
            if NozdorRaffleDebug then
                print(string.format("[DEBUG][Timer.Resume] addedPaused=%.3f totalPaused=%.3f", tonumber(GetTime() - self._pauseStartTime), tonumber(self._pausedTime)))
            end
            self._pauseStartTime = nil
        end
        if self._attachUpdate then self._attachUpdate() end
    end
end

function NozdorTimer:Cancel()
    self._active = false
    self._paused = false
    self._remaining = 0
    self._startTime = nil
    self._pausedTime = 0
    self._pauseStartTime = nil
    if self._frame then
        self._frame:SetScript("OnUpdate", nil)
    end
end

function NozdorTimer:IsActive()
    return self._active == true
end

function NozdorTimer:IsPaused()
    return self._paused == true
end

function NozdorTimer:GetRemaining()
    if not self._active then 
        return 0 
    end
    local now = GetTime()
    local refTime = (self._paused and self._pauseStartTime) and self._pauseStartTime or now
    local elapsed = refTime - (self._startTime or 0) - (self._pausedTime or 0)
    local remaining = (self._duration or 0) - elapsed
    local remainingInt = math.ceil(math.max(0, remaining))
    if NozdorRaffleDebug then
        print(string.format("[DEBUG][Timer] dur=%.3f start=%.3f now=%.3f pausedTime=%.3f paused=%s rem=%.3f (int=%d)", 
            tonumber(self._duration or 0), tonumber(self._startTime or 0), tonumber(now or 0), tonumber(self._pausedTime or 0), tostring(self._paused), tonumber(remaining or 0), tonumber(remainingInt)))
    end
    return remainingInt
end

function NozdorTimer:DebugState(prefix)
    if not NozdorRaffleDebug then return end
    prefix = prefix or "[DEBUG][Timer.State]"
    print(string.format("%s active=%s paused=%s duration=%.3f start=%.3f pausedTime=%.3f pauseStart=%.3f", 
        prefix, tostring(self._active), tostring(self._paused), tonumber(self._duration or 0), tonumber(self._startTime or 0), tonumber(self._pausedTime or 0), tonumber(self._pauseStartTime or 0)))
end
