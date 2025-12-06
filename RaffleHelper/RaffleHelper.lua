local function NozdorRaffle_SetFrameBackdrop()
    if NozdorRaffleFrame and NozdorRaffleFrame.SetBackdrop then
        NozdorRaffleFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        NozdorRaffleFrame:SetBackdropColor(0, 0, 0, 0.85)
    end
end

local function Nozdor_Utf8Truncate(s, maxChars)
    if not s then return "" end
    maxChars = maxChars or 14
    local bytes = {string.byte(s, 1, #s)}
    local out = {}
    local i, chars = 1, 0
    while i <= #bytes do
        local b = bytes[i]
        local len
        if b < 0x80 then
            len = 1
        elseif b >= 0xC2 and b <= 0xDF then
            len = 2
        elseif b >= 0xE0 and b <= 0xEF then
            len = 3
        elseif b >= 0xF0 and b <= 0xF4 then
            len = 4
        else
            len = 1
        end
        chars = chars + 1
        local chunk = string.sub(s, i, i + len - 1)
        table.insert(out, chunk)
        i = i + len
        if chars >= maxChars then break end
    end
    if i > #s then
        return s
    else
        local keep = math.max(1, maxChars - 3)
        if #out > keep then
            out = {table.concat(out, "", 1, keep)}
        end
        return table.concat(out, "") .. "..."
    end
end

local function Nozdor_ItemNameFromLink(link)
    if not link or type(link) ~= "string" then return nil end
    local name = link:match("%|h%[(.-)%]%|h")
    if name and name ~= "" then return name end
    return GetItemInfo(link)
end

hooksecurefunc("ShowUIPanel", function(frame)
    if frame == NozdorRaffleFrame then
        NozdorRaffle_SetFrameBackdrop()
    end
end)
-- Инициализация аддона
local _loadFrame = CreateFrame("Frame")

-- Saved settings DB
NozdorRaffleDB = NozdorRaffleDB or {
    keyword = "+",
    timer = 30,
    confirmLimit = 60,
    keepParticipants = false,
    autoReroll = false,
    hoverFade = false,
}

NozdorRaffleDebug = false
local function DebugPrint(msg)
    if NozdorRaffleDebug then print(msg) end
end
_loadFrame:RegisterEvent("ADDON_LOADED")
_loadFrame:SetScript("OnEvent", function(_, evt, name)
    if evt == "ADDON_LOADED" and name == "RaffleHelper" then
        NozdorRaffleDB.keyword = NozdorRaffleDB.keyword or "+"
        NozdorRaffleDB.timer = NozdorRaffleDB.timer or 30
        NozdorRaffleDB.confirmLimit = NozdorRaffleDB.confirmLimit or 60
        NozdorRaffleDB.keepParticipants = not not NozdorRaffleDB.keepParticipants
        NozdorRaffleDB.autoReroll = not not NozdorRaffleDB.autoReroll
        NozdorRaffleDB.hoverFade = not not NozdorRaffleDB.hoverFade

        NozdorRaffle.keyword = NozdorRaffleDB.keyword
        NozdorRaffle.timer = NozdorRaffleDB.timer

        print("[NozdorRaffle] Аддон загружен.")
        print("Команда /rafui для открытия окна.")
        print("Команда /rafclearhistory для очистки истории.")
        if NozdorRaffleFrame then
            NozdorRaffle_SetFrameBackdrop()
            if NozdorRaffleKeywordBox then NozdorRaffleKeywordBox:SetText(NozdorRaffleDB.keyword or "") end
            if NozdorRaffleDurationBox then NozdorRaffleDurationBox:SetText(tostring(NozdorRaffleDB.timer or 30)) end
            if NozdorRaffleConfirmTimeBox then NozdorRaffleConfirmTimeBox:SetText(tostring(NozdorRaffleDB.confirmLimit or 60)) end
            if NozdorRaffleKeepParticipantsBox then NozdorRaffleKeepParticipantsBox:SetChecked(NozdorRaffleDB.keepParticipants or false) end
            if NozdorRaffleAutoRerollBox then NozdorRaffleAutoRerollBox:SetChecked(NozdorRaffleDB.autoReroll or false) end
            if NozdorRaffleHoverFadeBox then NozdorRaffleHoverFadeBox:SetChecked(NozdorRaffleDB.hoverFade or false) end
        end
    end
end)


-- Для WoW 3.3.5a: безопасно устанавливаем фон только если фрейм существует
function NozdorRaffle_OnFrameLoad(self)
    if self and self.SetBackdrop then
        self:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        self:SetBackdropColor(0, 0, 0, 0.85)
    end
    if self.SetFrameStrata then self:SetFrameStrata("DIALOG") end
    if self.SetToplevel then self:SetToplevel(true) end
    if self.SetFrameLevel and self:GetFrameLevel() < 100 then self:SetFrameLevel(100) end

    if not NozdorRaffleTitleFS then
        local fs = self:CreateFontString("NozdorRaffleTitleFS", "ARTWORK", "GameFontNormalLarge")
        fs:SetPoint("TOP", self, "TOP", 0, -12)
        fs:SetText("Розыгрыши Nozdor")
    end

    if not NozdorRaffleTopLeftTimer then
        local timer = self:CreateFontString("NozdorRaffleTopLeftTimer", "ARTWORK", "GameFontNormal")
        timer:SetPoint("TOPLEFT", self, "TOPLEFT", 16, -12)
        timer:SetText("")
        timer:SetTextColor(1, 0.82, 0, 1)
    end

    if not NozdorRaffleKeywordLabel then
        local label = self:CreateFontString("NozdorRaffleKeywordLabel", "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", self, "TOPLEFT", 16, -40)
        label:SetText("Ключевое слово:")
    end

    if not NozdorRaffleKeywordBox then
        local edit = CreateFrame("EditBox", "NozdorRaffleKeywordBox", self, "InputBoxTemplate")
        edit:SetSize(120, 20)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(64)
        edit:SetPoint("LEFT", NozdorRaffleKeywordLabel, "RIGHT", 8, 0)
        edit:SetText(NozdorRaffleDB.keyword or "")
        local function saveKeyword(e)
            local v = e:GetText() or ""
            if v == "" then
                v = "+"
                e:SetText(v)
            end
            NozdorRaffleDB.keyword = v
            NozdorRaffle.keyword = v
        end
        edit:SetScript("OnEnterPressed", function(e) e:ClearFocus(); saveKeyword(e) end)
        edit:SetScript("OnEditFocusLost", saveKeyword)
    end

        if not NozdorRaffleDelayLabel then
            local dlabel2 = self:CreateFontString("NozdorRaffleDelayLabel", "ARTWORK", "GameFontNormal")
            dlabel2:SetPoint("LEFT", NozdorRaffleKeywordBox, "RIGHT", 24, 0)
            dlabel2:SetText("Задержка стрима:")
        end
        if not NozdorRaffleDelayBox then
            local dbox2 = CreateFrame("EditBox", "NozdorRaffleDelayBox", self, "InputBoxTemplate")
            dbox2:SetSize(60, 20)
            dbox2:SetAutoFocus(false)
            dbox2:SetMaxLetters(4)
            dbox2:SetNumeric(false)
            dbox2:SetPoint("LEFT", NozdorRaffleDelayLabel, "RIGHT", 8, 0)
            dbox2:SetText("0")
            dbox2:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
        end

        if not NozdorRaffleStartButton then
            local btn = CreateFrame("Button", "NozdorRaffleStartButton", self, "UIPanelButtonTemplate")
            btn:SetSize(100, 22)
            btn:SetPoint("TOPLEFT", NozdorRaffleKeywordLabel, "BOTTOMLEFT", 0, -8)
            btn:SetText("Старт")
            if btn.SetFrameStrata then btn:SetFrameStrata("DIALOG") end
            btn:Show()
            btn:SetScript("OnClick", function()
                DebugPrint("[DEBUG] Клик по кнопке Старт")
                if NozdorLog then NozdorLog("UI_Click_Start") end
                NozdorRaffle_StartRaffleUI()
            end)
        end

        if not NozdorRaffleStopButton then
            local sbtn = CreateFrame("Button", "NozdorRaffleStopButton", self, "UIPanelButtonTemplate")
            sbtn:SetSize(80, 22)
            sbtn:SetPoint("LEFT", NozdorRaffleStartButton, "RIGHT", 8, 0)
            sbtn:SetText("Стоп")
            if sbtn.SetFrameStrata then sbtn:SetFrameStrata("DIALOG") end
            sbtn:Show()
            sbtn:SetScript("OnClick", function()
                DebugPrint("[DEBUG] Клик по кнопке Стоп")
                if NozdorLog then NozdorLog("UI_Click_Stop") end
                NozdorRaffle_StopRaffleUI()
            end)
        end

        if not NozdorRaffleCancelButton then
            local cbtn = CreateFrame("Button", "NozdorRaffleCancelButton", self, "UIPanelButtonTemplate")
            cbtn:SetSize(80, 22)
            cbtn:SetPoint("LEFT", NozdorRaffleStopButton, "RIGHT", 8, 0)
            cbtn:SetText("Отмена")
            if cbtn.SetFrameStrata then cbtn:SetFrameStrata("DIALOG") end
            cbtn:Show()
            cbtn:SetScript("OnClick", function()
                if NozdorLog then NozdorLog("UI_Click_Cancel") end
                if NozdorRaffle.isActive then NozdorRaffle:CancelRaffle() end
            end)
            cbtn:Disable()
        end

        if not NozdorRaffleRerollButton then
            local rbtn = CreateFrame("Button", "NozdorRaffleRerollButton", self, "UIPanelButtonTemplate")
            rbtn:SetSize(80, 22)
            rbtn:SetPoint("LEFT", NozdorRaffleCancelButton, "RIGHT", 8, 0)
            rbtn:SetText("Реролл")
            if rbtn.SetFrameStrata then rbtn:SetFrameStrata("DIALOG") end
            rbtn:Show()
            rbtn:SetScript("OnClick", function()
                if NozdorLog then NozdorLog("UI_Click_Reroll") end
                NozdorRaffle_Reroll()
            end)
        end

        if not NozdorRaffleFinishButton then
            local fbtn = CreateFrame("Button", "NozdorRaffleFinishButton", self, "UIPanelButtonTemplate")
            fbtn:SetSize(90, 22)
            fbtn:SetPoint("LEFT", NozdorRaffleRerollButton, "RIGHT", 8, 0)
            fbtn:SetText("Завершить")
            if fbtn.SetFrameStrata then fbtn:SetFrameStrata("DIALOG") end
            fbtn:Show()
            fbtn:SetScript("OnClick", function()
                if NozdorLog then NozdorLog("UI_Click_Finish") end
                if NozdorRaffle.isActive then
                    NozdorRaffle:EndRaffle()
                else
                    print("[NozdorRaffle] Розыгрыш неактивен")
                end
            end)
            fbtn:Disable()
        end

        if not NozdorRafflePrizeLabel then
            local prizeLabel = self:CreateFontString("NozdorRafflePrizeLabel", "ARTWORK", "GameFontNormal")
            prizeLabel:SetPoint("TOPLEFT", NozdorRaffleKeywordLabel, "BOTTOMLEFT", 0, -40)
            prizeLabel:SetText("Приз: не выбран")
            prizeLabel:SetTextColor(0.8, 0.8, 0.8)
        end
        if not NozdorRaffleSelectPrizeButton then
            local prizeBtn = CreateFrame("Button", "NozdorRaffleSelectPrizeButton", self, "UIPanelButtonTemplate")
            prizeBtn:SetSize(120, 22)
            prizeBtn:SetPoint("LEFT", NozdorRafflePrizeLabel, "RIGHT", 8, 0)
            prizeBtn:SetText("Выбрать приз")
            if prizeBtn.SetFrameStrata then prizeBtn:SetFrameStrata("DIALOG") end
            prizeBtn:SetScript("OnClick", function()
                NozdorRaffle_ShowPrizeSelector()
            end)
        end

        if not NozdorRafflePrizeInputLabel then
            local pil = self:CreateFontString("NozdorRafflePrizeInputLabel", "ARTWORK", "GameFontNormal")
            pil:SetPoint("LEFT", NozdorRaffleSelectPrizeButton, "RIGHT", 12, 0)
            pil:SetText("Ручной приз:")
        end
        if not NozdorRafflePrizeInputBox then
            local pib = CreateFrame("EditBox", "NozdorRafflePrizeInputBox", self, "InputBoxTemplate")
            pib:SetSize(120, 20)
            pib:SetAutoFocus(false)
            pib:SetMaxLetters(256)
            pib:SetPoint("LEFT", NozdorRafflePrizeInputLabel, "RIGHT", 8, 0)
            pib:SetText("")
            pib:SetScript("OnEnterPressed", function(e)
                e:ClearFocus()
                local txt = e:GetText()
                if txt and txt ~= "" then
                    NozdorRaffle.manualPrize = txt
                else
                    NozdorRaffle.manualPrize = nil
                end
            end)
        end

        if not NozdorRaffleDurationLabel then
            local dlabel = self:CreateFontString("NozdorRaffleDurationLabel", "ARTWORK", "GameFontNormal")
            dlabel:SetPoint("TOPLEFT", NozdorRafflePrizeLabel, "BOTTOMLEFT", 0, -12)
            dlabel:SetText("Таймер (сек):")
        end
        if not NozdorRaffleDurationBox then
            local dbox = CreateFrame("EditBox", "NozdorRaffleDurationBox", self, "InputBoxTemplate")
            dbox:SetSize(80, 20)
            dbox:SetAutoFocus(false)
            dbox:SetMaxLetters(4)
            dbox:SetNumeric(false)
            dbox:SetPoint("LEFT", NozdorRaffleDurationLabel, "RIGHT", 8, 0)
            dbox:SetText(tostring(NozdorRaffleDB.timer or 30))
            local function saveTimer(e)
                local n = tonumber(e:GetText())
                if n and n > 0 then
                    NozdorRaffleDB.timer = n
                    NozdorRaffle.timer = n
                end
            end
            dbox:SetScript("OnEnterPressed", function(e) e:ClearFocus(); saveTimer(e) end)
            dbox:SetScript("OnEditFocusLost", saveTimer)
            dbox:SetScript("OnTextChanged", function(e) saveTimer(e) end)
        end

        if not NozdorRaffleParticipantsLabel then
            local plabel = self:CreateFontString("NozdorRaffleParticipantsLabel", "ARTWORK", "GameFontNormal")
            plabel:SetPoint("TOPLEFT", NozdorRaffleDurationLabel, "BOTTOMLEFT", 0, -12)
            plabel:SetText("Участники:")
            if not NozdorRaffleKeepParticipantsBox then
                local cb = CreateFrame("CheckButton", "NozdorRaffleKeepParticipantsBox", self, "UICheckButtonTemplate")
                cb:SetPoint("LEFT", plabel, "RIGHT", 12, 0)
                cb.text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
                cb.text:SetText("Сохранять")
                cb:SetChecked(NozdorRaffleDB.keepParticipants or false)
                cb:SetScript("OnClick", function(self)
                    NozdorRaffleDB.keepParticipants = self:GetChecked() and true or false
                end)
            end
        end

        local container = NozdorRaffleParticipantsFrame
        if not container then
            container = CreateFrame("Frame", "NozdorRaffleParticipantsFrame", self)
            container:SetSize(220, 470)
            container:SetPoint("TOPLEFT", NozdorRaffleParticipantsLabel, "BOTTOMLEFT", 0, -8)
                if container.SetFrameStrata then container:SetFrameStrata("DIALOG") end
            local bg = container:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(container)
            bg:SetTexture(0.1, 0.1, 0.1, 0.5)
            
            local scrollFrame = CreateFrame("ScrollFrame", "NozdorRaffleScrollFrame", container, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 5, -5)
            scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 5)
            
            local scrollChild = CreateFrame("Frame", nil, scrollFrame)
            scrollChild:SetSize(180, 1)
            scrollFrame:SetScrollChild(scrollChild)
            
            container.scrollFrame = scrollFrame
            container.scrollChild = scrollChild
            container.labels = {}

            for i = 1, 300 do
                local fs = container.scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                fs:SetPoint("TOPLEFT", container.scrollChild, "TOPLEFT", 4, -4 - (i-1)*15)
                fs:SetText("")
                fs:Hide()
                table.insert(container.labels, fs)
            end

            -- Кнопка истории
            if not NozdorRaffleHistoryButton then
                local hbtn = CreateFrame("Button", "NozdorRaffleHistoryButton", self, "UIPanelButtonTemplate")
                hbtn:SetSize(100, 24)
                if NozdorRaffleClearButton then
                    hbtn:SetPoint("RIGHT", NozdorRaffleClearButton, "LEFT", -4, 0)
                else
                    hbtn:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 12, 12)
                end
                hbtn:SetText("История")
                if hbtn.SetFrameStrata then hbtn:SetFrameStrata("DIALOG") end
                hbtn:SetScript("OnClick", function()
                    NozdorRaffle_ShowHistory()
                end)
            end
        end

        if not NozdorRaffleClearButton then
            local c = CreateFrame("Button", "NozdorRaffleClearButton", self, "UIPanelButtonTemplate")
            c:SetSize(100, 24)
            c:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, 12)
            c:SetText("Очистить")
             if c.SetFrameStrata then c:SetFrameStrata("DIALOG") end
            c:SetScript("OnClick", function()
                NozdorRaffle_ClearAll()
            end)
            if NozdorRaffleHistoryButton then
                NozdorRaffleHistoryButton:ClearAllPoints()
                NozdorRaffleHistoryButton:SetPoint("RIGHT", c, "LEFT", -4, 0)
            end
        end

        -- Панель подтверждения
        if not NozdorRaffleConfirmPanel then
            local panel = CreateFrame("Frame", "NozdorRaffleConfirmPanel", self)
            panel:SetSize(220, 150)
            panel:SetPoint("TOPLEFT", NozdorRaffleParticipantsFrame, "TOPRIGHT", 12, 0)
                if panel.SetFrameStrata then panel:SetFrameStrata("DIALOG") end
            local bg2 = panel:CreateTexture(nil, "BACKGROUND")
            bg2:SetAllPoints(panel)
            bg2:SetTexture(0.1, 0.1, 0.1, 0.4)

            if not NozdorRaffleAutoRerollBox then
                local ar = CreateFrame("CheckButton", "NozdorRaffleAutoRerollBox", self, "UICheckButtonTemplate")
                ar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 6)
                ar.text = ar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                ar.text:SetPoint("LEFT", ar, "RIGHT", 4, 0)
                ar.text:SetText("Авто-реролл")
                ar:SetChecked(NozdorRaffleDB.autoReroll or false)
                ar:SetScript("OnClick", function(self)
                    NozdorRaffleDB.autoReroll = self:GetChecked() and true or false
                end)
            end

            local title = panel:CreateFontString("NozdorRaffleConfirmTitle", "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
            title:SetText("Подтверждение")

            local wl = panel:CreateFontString("NozdorRaffleWinnerLabel", "ARTWORK", "GameFontNormal")
            wl:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
            wl:SetText("Победитель: -")

            local sl = panel:CreateFontString("NozdorRaffleStatusLabel", "ARTWORK", "GameFontNormal")
            sl:SetPoint("TOPLEFT", wl, "BOTTOMLEFT", 0, -8)
            sl:SetText("Статус: ожидаем")

            local tl = panel:CreateFontString("NozdorRaffleConfirmTimerLabel", "ARTWORK", "GameFontNormal")
            tl:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 0, -8)
            tl:SetText("Осталось: -")

            local pl = panel:CreateFontString("NozdorRaffleConfirmPrizeLabel", "ARTWORK", "GameFontNormal")
            pl:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, -8)
            pl:SetText("Приз: -")
            pl:SetTextColor(1, 0.82, 0)

            local ctLabel = panel:CreateFontString("NozdorRaffleConfirmInputLabel", "ARTWORK", "GameFontNormal")
            ctLabel:SetPoint("TOPLEFT", pl, "BOTTOMLEFT", 0, -10)
            ctLabel:SetText("Лимит (сек):")
            local ctBox = CreateFrame("EditBox", "NozdorRaffleConfirmTimeBox", panel, "InputBoxTemplate")
            ctBox:SetSize(60, 20)
            ctBox:SetAutoFocus(false)
            ctBox:SetMaxLetters(4)
            ctBox:SetNumeric(false)
            ctBox:SetPoint("LEFT", ctLabel, "RIGHT", 6, 0)
            ctBox:SetText(tostring(NozdorRaffleDB.confirmLimit or 60))
            local function saveConfirm(e)
                local n = tonumber(e:GetText())
                if n and n > 0 then
                    NozdorRaffleDB.confirmLimit = n
                end
            end
            ctBox:SetScript("OnEnterPressed", function(e) e:ClearFocus(); saveConfirm(e) end)
            ctBox:SetScript("OnEditFocusLost", saveConfirm)
            ctBox:SetScript("OnTextChanged", function(e) saveConfirm(e) end)
        end

        -- Панель последних победителей под подтверждением
        if not NozdorRaffleWinnersPanel then
            local wpanel = CreateFrame("Frame", "NozdorRaffleWinnersPanel", self)
            wpanel:SetSize(220, 290) -- увеличена дополнительно на 30
            wpanel:SetPoint("TOPLEFT", NozdorRaffleConfirmPanel, "BOTTOMLEFT", 0, -12)
                if wpanel.SetFrameStrata then wpanel:SetFrameStrata("DIALOG") end
            local bg3 = wpanel:CreateTexture(nil, "BACKGROUND")
            bg3:SetAllPoints(wpanel)
            bg3:SetTexture(0.08, 0.08, 0.08, 0.35)

            local wtitle = wpanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            wtitle:SetPoint("TOPLEFT", wpanel, "TOPLEFT", 8, -8)
            wtitle:SetText("Последние победители")

            local wscroll = CreateFrame("ScrollFrame", "NozdorRaffleWinnersScroll", wpanel, "UIPanelScrollFrameTemplate")
            wscroll:SetPoint("TOPLEFT", wpanel, "TOPLEFT", 5, -28)
            wscroll:SetPoint("BOTTOMRIGHT", wpanel, "BOTTOMRIGHT", -28, 5)

            local wchild = CreateFrame("Frame", nil, wscroll)
            wchild:SetSize(180, 1)
            wscroll:SetScrollChild(wchild)

            wpanel.scrollFrame = wscroll
            wpanel.scrollChild = wchild
            wpanel.labels = {}
            for i = 1, 100 do
                local btn = CreateFrame("Button", nil, wchild)
                btn:SetPoint("TOPLEFT", wchild, "TOPLEFT", 6, -6 - (i-1)*18)
                btn:SetSize(170, 18)
                btn:Hide()
                local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                fs:SetPoint("LEFT", btn, "LEFT", 0, 0)
                fs:SetJustifyH("LEFT")
                fs:SetText("")
                btn.text = fs
                btn:SetScript("OnEnter", function(self)
                    if not self._timestamp then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self._timestamp, 1, 1, 1)
                    local prizeLine = self._prize and tostring(self._prize) or "-"
                    GameTooltip:AddLine(prizeLine, 0.9, 0.9, 0.9)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                wpanel.labels[i] = btn
            end
        end

        if not NozdorRaffleCloseBtn then
            local close = CreateFrame("Button", "NozdorRaffleCloseBtn", self, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", self, "TOPRIGHT", -6, -6)
            close:SetSize(24, 24)
            close:SetFrameStrata("DIALOG")
            close:Show()
            if not close:GetNormalTexture() then
                close:SetNormalTexture("Interface/Buttons/UI-Panel-CloseButton-Up")
                close:SetPushedTexture("Interface/Buttons/UI-Panel-CloseButton-Down")
                close:SetHighlightTexture("Interface/Buttons/UI-Panel-CloseButton-Highlight")
            end
            close:SetScript("OnClick", function() self:Hide() end)
        end

        -- Галочка: делать окно полупрозрачным, пока курсор не наведён
        if not NozdorRaffleHoverFadeBox then
            local cb = CreateFrame("CheckButton", "NozdorRaffleHoverFadeBox", self, "UICheckButtonTemplate")
            cb:SetPoint("RIGHT", NozdorRaffleCloseBtn, "LEFT", -6, 0)
            cb:SetChecked(NozdorRaffleDB and NozdorRaffleDB.hoverFade or false)
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
                GameTooltip:SetText("Полупрозрачное окно при отсутствии курсора", 1, 1, 1)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- Обновитель, который проверяет курсор раз в кадр и применяет нужную альфу
            local function ensureHoverUpdater(frame)
                if not frame._hoverFadeUpdater then
                    -- Привязываем апдейтер к нашему фрейму, чтобы он не перекрывал клики
                    frame._hoverFadeUpdater = CreateFrame("Frame", nil, frame)
                    if frame._hoverFadeUpdater.EnableMouse then frame._hoverFadeUpdater:EnableMouse(false) end
                    if frame._hoverFadeUpdater.SetFrameStrata then frame._hoverFadeUpdater:SetFrameStrata("LOW") end
                end
                local duration = 0.2
                frame._hoverFadeUpdater:SetScript("OnUpdate", function(_, dt)
                    if not NozdorRaffleHoverFadeBox or not NozdorRaffleHoverFadeBox:GetChecked() then
                        frame:SetAlpha(1)
                        return
                    end
                    local over = frame:IsMouseOver() or (MouseIsOver and MouseIsOver(frame))
                    local target = over and 1 or 0.35
                    local current = frame:GetAlpha() or 1
                    if math.abs(target - current) < 0.01 then
                        frame:SetAlpha(target)
                        return
                    end
                    local step = (dt or 0) / duration
                    if step > 1 then step = 1 end
                    local nextAlpha = current + (target - current) * step
                    frame:SetAlpha(nextAlpha)
                end)
            end

            cb:SetScript("OnClick", function(self)
                NozdorRaffleDB.hoverFade = self:GetChecked() and true or false
                ensureHoverUpdater(self:GetParent())
            end)

            -- Активировать обновитель сразу
            ensureHoverUpdater(self)
        end

        if self.SetClampedToScreen then self:SetClampedToScreen(true) end
    end

function NozdorRaffle_ShowHistory()
    if not NozdorHistory then
        print("[NozdorRaffle] Модуль истории не загружен.")
        return
    end
    local history = NozdorHistory:GetAll()
    if not history or #history == 0 then
        print("[NozdorRaffle] История победителей пуста.")
        return
    end
    for i, entry in ipairs(history) do
        local timestamp = entry.timestamp or entry.time or "дата неизвестна"
        print(string.format("%d. %s - %s", i, entry.winner or "неизвестно", timestamp))
    end
end

function NozdorRaffle_StartRaffleUI()
    DebugPrint("[DEBUG] StartRaffleUI вызван. isActive=" .. tostring(NozdorRaffle.isActive) .. ", isPaused=" .. tostring(NozdorRaffle.isPaused))
    if NozdorLog then NozdorLog("StartRaffleUI", {active=NozdorRaffle.isActive, paused=NozdorRaffle.isPaused}) end
    
    local keyword = NozdorRaffleKeywordBox and NozdorRaffleKeywordBox:GetText() or ""
    local durationText = NozdorRaffleDurationBox and NozdorRaffleDurationBox:GetText() or ""
    local delayText = NozdorRaffleDelayBox and NozdorRaffleDelayBox:GetText() or "0"
    local duration = tonumber(durationText)
    local delay = tonumber(delayText) or 0
    DebugPrint(string.format("[DEBUG] Введён таймер: '%s' -> %s", tostring(durationText), tostring(duration)))
    if NozdorLog then NozdorLog("Input_Duration", {raw=durationText, parsed=duration}) end
    if not duration or duration <= 0 then duration = NozdorRaffle.timer or 30 end
    DebugPrint(string.format("[DEBUG] Итоговая длительность: %s", tostring(duration)))
    if NozdorLog then NozdorLog("Duration_Final", duration) end
    if NozdorLog then NozdorLog("Input_Delay", {raw=delayText, parsed=delay}) end
    
    if not NozdorRaffle.isActive then
        DebugPrint("[DEBUG] Запуск нового розыгрыша")
        if NozdorLog then NozdorLog("Raffle_Start", {keyword=keyword, duration=duration, delay=delay}) end

        if NozdorRaffleConfirmTicker then
            NozdorRaffleConfirmTicker:SetScript("OnUpdate", nil)
        end
        NozdorRaffle.awaitConfirm = nil
        if NozdorRaffleWinnerLabel then NozdorRaffleWinnerLabel:SetText("Победитель: -") end
        if NozdorRaffleStatusLabel then NozdorRaffleStatusLabel:SetText("Статус: ожидаем") end
        if NozdorRaffleConfirmTimerLabel then NozdorRaffleConfirmTimerLabel:SetText("Осталось: -") end
        if delay and delay > 0 then
            print(string.format("[NozdorRaffle] Старт через %d сек...", delay))
            local remain = delay
            local waitFrame = CreateFrame("Frame")
            waitFrame:SetScript("OnUpdate", function(_, elapsed)
                remain = remain - (elapsed or 0)
                if remain <= 0 then
                    waitFrame:SetScript("OnUpdate", nil)
                    NozdorRaffle:StartRaffle(keyword, duration)
                    NozdorRaffle_UpdateParticipantsUI()
                end
            end)
        else
            NozdorRaffle:StartRaffle(keyword, duration)
            NozdorRaffle_UpdateParticipantsUI()
        end
        if NozdorRaffleStopButton then NozdorRaffleStopButton:Enable() end
        if NozdorRaffleCancelButton then NozdorRaffleCancelButton:Enable() end
        if NozdorRaffleFinishButton then NozdorRaffleFinishButton:Enable() end
        if NozdorRaffleStartButton then NozdorRaffleStartButton:Disable() end
    elseif NozdorRaffle.isPaused then
        DebugPrint("[DEBUG] Продолжение с паузы")
        if NozdorLog then NozdorLog("Raffle_Resume_Pressed") end
        NozdorRaffle.isPaused = false
        if NozdorTimer then
            local rem = NozdorTimer:GetRemaining()
            NozdorTimer:Resume()
            DebugPrint("[DEBUG] Resume() вызван, remaining=" .. rem)
            if NozdorLog then NozdorLog("Timer_Resume", {remaining_before=rem}) end
        end
        if NozdorRaffleStopButton then NozdorRaffleStopButton:Enable() end
        if NozdorRaffleStartButton then NozdorRaffleStartButton:Disable() end
        if NozdorRaffleFinishButton then NozdorRaffleFinishButton:Enable() end
        print("[NozdorRaffle] Таймер продолжен с " .. (NozdorTimer and NozdorTimer:GetRemaining() or 0) .. " сек.")
        if NozdorLog then NozdorLog("Timer_Resume_After", {remaining=NozdorTimer and NozdorTimer:GetRemaining() or 0}) end
    else
        print("[NozdorRaffle] Розыгрыш уже запущен!")
    end
end

function NozdorRaffle_StopRaffleUI()
    DebugPrint("[DEBUG] StopRaffleUI вызван. isActive=" .. tostring(NozdorRaffle.isActive) .. ", isPaused=" .. tostring(NozdorRaffle.isPaused))
    if NozdorLog then NozdorLog("StopRaffleUI", {active=NozdorRaffle.isActive, paused=NozdorRaffle.isPaused}) end
    if not NozdorRaffle.isActive then
        DebugPrint("[DEBUG] Розыгрыш не активен, выход")
        if NozdorLog then NozdorLog("StopRaffleUI_Inactive") end
        return
    end
    if NozdorRaffle.isPaused then
        DebugPrint("[DEBUG] Уже на паузе, выход")
        if NozdorLog then NozdorLog("StopRaffleUI_AlreadyPaused") end
        return
    end
    
    if NozdorTimer and NozdorTimer.DebugState then NozdorTimer:DebugState("[DEBUG][BeforePause]") end
    if NozdorLog and NozdorTimer and NozdorTimer.DebugState then NozdorLog("Timer_State_BeforePause") end

    NozdorRaffle.isPaused = true
    if NozdorTimer then
        NozdorTimer:Pause()
        local remAfter = NozdorTimer.GetRemaining and NozdorTimer:GetRemaining() or -1
        DebugPrint("[DEBUG] Pause() вызван; remaining после паузы=" .. tostring(remAfter))
        if NozdorLog then NozdorLog("Timer_Paused", {remaining=remAfter}) end
    end
    
    if NozdorRaffleStartButton then
        NozdorRaffleStartButton:Enable()
        DebugPrint("[DEBUG] Кнопка Старт активирована")
        if NozdorLog then NozdorLog("UI_Enable_Start") end
    end
    if NozdorRaffleStopButton then
        NozdorRaffleStopButton:Disable()
        DebugPrint("[DEBUG] Кнопка Стоп деактивирована")
        if NozdorLog then NozdorLog("UI_Disable_Stop") end
    end
    
    print("[NozdorRaffle] Таймер поставлен на паузу. Нажмите Старт для продолжения.")
    if NozdorLog then NozdorLog("Info_Paused") end
end

function NozdorRaffle_UpdateParticipantsUI()
    if not NozdorRaffleParticipantsFrame then 
        DebugPrint("[DEBUG] NozdorRaffleParticipantsFrame не существует!")
        return 
    end
    
    if not NozdorRaffleParticipantsFrame.labels then
        DebugPrint("[DEBUG] Labels не найдены!")
        return
    end
    
    DebugPrint("[DEBUG] Обновление списка, участников: " .. #NozdorRaffle.participants)
    if NozdorRaffleParticipantsLabel then
        NozdorRaffleParticipantsLabel:SetText("Участники: " .. tostring(#NozdorRaffle.participants))
    end
    
    -- Определяем последнего победителя из истории
    local lastWinner = nil
    local histSource = NozdorRaffleHistory or NozdorRaffle.history
    if histSource and type(histSource) == "table" and #histSource > 0 then
        lastWinner = histSource[#histSource].winner
    end
    
    -- Сначала скрываем все строки
    for i = 1, #NozdorRaffleParticipantsFrame.labels do
        NozdorRaffleParticipantsFrame.labels[i]:SetText("")
        NozdorRaffleParticipantsFrame.labels[i]:Hide()
    end
    
    -- Показываем строки с участниками
    local maxVisible = 0
    for i, name in ipairs(NozdorRaffle.participants) do
        if i <= #NozdorRaffleParticipantsFrame.labels then
            local label = NozdorRaffleParticipantsFrame.labels[i]
            label:SetText(i .. ". " .. name)
            -- Раскраска: последний победитель зелёным, остальные белым
            if label.SetTextColor then
                if lastWinner and name == lastWinner then
                    label:SetTextColor(0, 1, 0)
                else
                    label:SetTextColor(1, 1, 1)
                end
            end
            label:Show()
            maxVisible = i
            DebugPrint("[DEBUG] Показана строка " .. i .. ": " .. name)
        end
    end
    
    -- Обновляем высоту scrollChild для корректной работы скролла
    if NozdorRaffleParticipantsFrame.scrollChild and maxVisible > 0 then
        local contentHeight = maxVisible * 15 + 10
        NozdorRaffleParticipantsFrame.scrollChild:SetHeight(contentHeight)
    end
    
    DebugPrint("[DEBUG] UI обновлён успешно")
end

-- Функция сканирования инвентаря
local function NozdorRaffle_ScanInventory()
    local items = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
                if link then
                    table.insert(items, {link = link, count = count or 1, bag = bag, slot = slot})
                end
            end
        end
    end
    return items
end

-- Показать окно выбора приза
function NozdorRaffle_ShowPrizeSelector()
    if NozdorRafflePrizeSelectorFrame then
        NozdorRafflePrizeSelectorFrame:Show()
        NozdorRaffle_UpdatePrizeList()
        return
    end

    local frame = CreateFrame("Frame", "NozdorRafflePrizeSelectorFrame", UIParent)
    frame:SetSize(300, 400)
    frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetToplevel(true)
    frame:SetFrameLevel(200)
    
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
    end

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText("Выбор приза")

    local scrollFrame = CreateFrame("ScrollFrame", "NozdorRafflePrizeScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 40)
    if scrollFrame.SetFrameStrata then scrollFrame:SetFrameStrata("TOOLTIP") end
    if scrollFrame.SetFrameLevel then scrollFrame:SetFrameLevel(201) end

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(250, 1)
    scrollFrame:SetScrollChild(scrollChild)
    if scrollChild.SetFrameStrata then scrollChild:SetFrameStrata("TOOLTIP") end
    if scrollChild.SetFrameLevel then scrollChild:SetFrameLevel(202) end

    frame.scrollFrame = scrollFrame
    frame.scrollChild = scrollChild
    frame.buttons = {}

    for i = 1, 100 do
        local btn = CreateFrame("Button", nil, scrollChild)
        btn:SetSize(240, 24)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4 - (i-1)*26)
        btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
        btn:Hide()
        if btn.SetFrameStrata then btn:SetFrameStrata("TOOLTIP") end
        if btn.SetFrameLevel then btn:SetFrameLevel(203) end
        
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", btn, "LEFT", 0, 0)
        btn.icon = icon
        
        local text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        text:SetJustifyH("LEFT")
        text:SetWidth(200)
        btn.text = text
        
        frame.buttons[i] = btn
    end

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    if closeBtn.SetFrameStrata then closeBtn:SetFrameStrata("TOOLTIP") end
    if closeBtn.SetFrameLevel then closeBtn:SetFrameLevel(205) end

    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(120, 24)
    clearBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    clearBtn:SetText("Убрать приз")
    clearBtn:SetScript("OnClick", function()
        NozdorRaffle.selectedPrize = nil
        if NozdorRafflePrizeLabel then
            NozdorRafflePrizeLabel:SetText("Приз: не выбран")
            NozdorRafflePrizeLabel:SetTextColor(0.8, 0.8, 0.8)
        end
        frame:Hide()
        print("[NozdorRaffle] Приз удалён.")
    end)
    if clearBtn.SetFrameStrata then clearBtn:SetFrameStrata("TOOLTIP") end
    if clearBtn.SetFrameLevel then clearBtn:SetFrameLevel(205) end

    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:Show()
    NozdorRaffle_UpdatePrizeList()
end

function NozdorRaffle_UpdatePrizeList()
    local frame = NozdorRafflePrizeSelectorFrame
    if not frame or not frame.buttons then return end

    local items = NozdorRaffle_ScanInventory()
    
    for i = 1, #frame.buttons do
        local btn = frame.buttons[i]
        if items[i] then
            local item = items[i]
            local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(item.link)
            
            btn.text:SetText((name or item.link) .. (item.count > 1 and (" x" .. item.count) or ""))
            btn.icon:SetTexture(texture or "Interface/Icons/INV_Misc_QuestionMark")
            btn:SetScript("OnClick", function()
                NozdorRaffle.selectedPrize = item.link
                if NozdorRafflePrizeLabel then
                    local shown = Nozdor_Utf8Truncate(name or "предмет", 14)
                    NozdorRafflePrizeLabel:SetText("Приз: " .. shown)
                    NozdorRafflePrizeLabel:SetTextColor(0, 1, 0.3)
                end
                frame:Hide()
                print("[NozdorRaffle] Выбран приз: " .. item.link)
            end)
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(item.link)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:Show()
        else
            btn:Hide()
        end
    end

    if frame.scrollChild then
        local contentHeight = math.max(100, #items * 26 + 10)
        frame.scrollChild:SetHeight(contentHeight)
    end
end

SLASH_NOZDORRAFFLE1 = "/raf"
SlashCmdList["NOZDORRAFFLE"] = function(msg)
    if msg and msg:lower():find("show") then
        NozdorRaffleFrame:Show()
        return
    end
    if not NozdorRaffle.isActive then
        local keyword = msg and msg:match("%S+") or nil
        NozdorRaffle:StartRaffle(keyword)
    else
        print("[NozdorRaffle] Розыгрыш уже запущен!")
    end
end

-- Безопасное создание/показ UI-фрейма
local function NozdorRaffle_ShowUI()
    if not NozdorRaffleFrame then
        local f = CreateFrame("Frame", "NozdorRaffleFrame", UIParent)
        f:SetSize(500, 650)
        f:SetPoint("CENTER")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        NozdorRaffle_OnFrameLoad(f)
        if UISpecialFrames then
            local exists = false
            for i=1,#UISpecialFrames do if UISpecialFrames[i] == "NozdorRaffleFrame" then exists = true; break end end
            if not exists then table.insert(UISpecialFrames, "NozdorRaffleFrame") end
        end
    end
    local function FadeIn(frame, duration)
        duration = duration or 0.25
        frame:SetAlpha(0)
        frame:Show()
        local elapsed = 0
        local updater = frame._fadeUpdater or CreateFrame("Frame")
        frame._fadeUpdater = updater
        updater:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + (dt or 0)
            local a = math.min(1, elapsed / duration)
            frame:SetAlpha(a)
            if a >= 1 then
                updater:SetScript("OnUpdate", nil)
            end
        end)
    end
    FadeIn(NozdorRaffleFrame, 0.25)
    NozdorRaffle_SetFrameBackdrop()
    if NozdorRaffle_UpdateWinnersPanel then NozdorRaffle_UpdateWinnersPanel() end
end

-- Основная команда для открытия UI: /rafui
SLASH_NOZDORRAFFLEUI1 = "/rafui"
SlashCmdList["NOZDORRAFFLEUI"] = function()
    if NozdorRaffleFrame and NozdorRaffleFrame:IsShown() then
        local function FadeOut(frame, duration, onDone)
            duration = duration or 0.2
            local elapsed = 0
            local updater = frame._fadeUpdater or CreateFrame("Frame")
            frame._fadeUpdater = updater
            updater:SetScript("OnUpdate", function(_, dt)
                elapsed = elapsed + (dt or 0)
                local a = math.max(0, 1 - (elapsed / duration))
                frame:SetAlpha(a)
                if a <= 0 then
                    updater:SetScript("OnUpdate", nil)
                    frame:Hide()
                    frame:SetAlpha(1)
                    if onDone then onDone() end
                end
            end)
        end
        FadeOut(NozdorRaffleFrame, 0.2)
    else
        NozdorRaffle_ShowUI()
    end
end

NozdorRaffle = {}
NozdorRaffle.participants = {}
NozdorRaffle.isActive = false

-- Резервная команда для показа
SLASH_NOZDORRAFFLESHOW1 = "/rafshow"
SlashCmdList["NOZDORRAFFLESHOW"] = function()
    NozdorRaffle_ShowUI()
end
NozdorRaffle.isPaused = false
NozdorRaffle.keyword = "+"
NozdorRaffle.timer = 30
NozdorRaffle.history = {}

local frame = CreateFrame("Frame")

-- Команда для управления режимом дебага: /rafdebug on|off
SLASH_NOZDORDEBUG1 = "/rafdebug"
SlashCmdList["NOZDORDEBUG"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "on" or msg == "1" or msg == "true" then
        NozdorRaffleDebug = true
        print("[NozdorRaffle] Дебаг включён.")
    elseif msg == "off" or msg == "0" or msg == "false" then
        NozdorRaffleDebug = false
        print("[NozdorRaffle] Дебаг выключён.")
    else
        print("[NozdorRaffle] Использование: /rafdebug on|off")
        print("Текущее состояние: " .. (NozdorRaffleDebug and "on" or "off"))
    end
end

-- Команда для очистки истории выигрышей: /rafclearhistory
SLASH_NOZDORRAFFLECHISTORY1 = "/rafclearhistory"
SlashCmdList["NOZDORRAFFLECHISTORY"] = function()
    if NozdorHistory and NozdorHistory.Clear then
        NozdorHistory:Clear()
    end
    if NozdorRaffle then
        NozdorRaffle.history = {}
    end
    if NozdorRaffleHistory then
        NozdorRaffleHistory = {}
    end
    if NozdorRaffle_UpdateWinnersPanel then
        NozdorRaffle_UpdateWinnersPanel()
    end
    print("[NozdorRaffle] История выигрышей очищена.")
end

function NozdorRaffle:StartRaffle(keyword, duration)
    if keyword and keyword ~= "" then
        self.keyword = keyword
    end
    if duration and tonumber(duration) and tonumber(duration) > 0 then
        self.timer = tonumber(duration)
    end
    -- Если включено сохранение, не очищаем участников, но удаляем последнего победителя
    local keep = NozdorRaffleKeepParticipantsBox and NozdorRaffleKeepParticipantsBox:GetChecked()
    if keep then
        -- Удаляем последнего победителя из списка, если он есть
        local lastWinner = nil
        if NozdorRaffleHistory and type(NozdorRaffleHistory) == "table" and #NozdorRaffleHistory > 0 then
            lastWinner = NozdorRaffleHistory[#NozdorRaffleHistory].winner
        elseif NozdorRaffle.history and #NozdorRaffle.history > 0 then
            lastWinner = NozdorRaffle.history[#NozdorRaffle.history].winner
        end
        if lastWinner then
            for i = #self.participants, 1, -1 do
                if self.participants[i] == lastWinner then table.remove(self.participants, i) end
            end
        end
    else
        self.participants = {}
    end
    self.isActive = true
    self.isPaused = false
    print("[NozdorRaffle] Розыгрыш начат! Напишите '" .. self.keyword .. "' в чат для участия. Время: " .. self.timer .. " сек.")
    if NozdorRaffleFrame then
        NozdorRaffleFrame:Show()
        -- Очищаем список участников
        NozdorRaffle_UpdateParticipantsUI()
    end
    -- Запускаем модуль таймера для обратного отсчёта
    if NozdorTimer then
        -- Отрисуем начальные значения
        if NozdorRaffleTopLeftTimer then
            NozdorRaffleTopLeftTimer:SetText("До конца: " .. self.timer .. "с")
        end

        NozdorTimer:Start(self.timer,
            function(remaining)
                if NozdorRaffleTopLeftTimer then
                    NozdorRaffleTopLeftTimer:SetText("До конца: " .. remaining .. "с")
                end
            end,
            function()
                if NozdorRaffleTopLeftTimer then
                    NozdorRaffleTopLeftTimer:SetText("")
                end
                NozdorRaffle:EndRaffle()
            end,
            {
                onStart = function(total)
                    -- можно добавить сообщение/лог
                end,
                onHalf = function(remaining)
                    -- половина времени — при желании можно уведомить
                end
            }
        )
    else
        -- Если модуль таймера недоступен, сразу завершаем по истечении времени через простой OnUpdate
        local remain = self.timer
        local tmpFrame = CreateFrame("Frame")
        tmpFrame:SetScript("OnUpdate", function(_, elapsed)
            remain = remain - (elapsed or 0)
            if remain <= 0 then
                tmpFrame:SetScript("OnUpdate", nil)
                NozdorRaffle:EndRaffle()
            else
                local r = math.ceil(remain)
                if NozdorRaffleTopLeftTimer then NozdorRaffleTopLeftTimer:SetText("До конца: " .. r .. "с") end
            end
        end)
    end
end

function NozdorRaffle:EndRaffle()
    self.isActive = false
    self.isPaused = false
    if NozdorTimer and NozdorTimer:IsActive() then
        NozdorTimer:Cancel()
    end
    if NozdorRaffleTopLeftTimer then
        NozdorRaffleTopLeftTimer:SetText("")
    end
    if NozdorRaffleStopButton then NozdorRaffleStopButton:Disable() end
    if NozdorRaffleCancelButton then NozdorRaffleCancelButton:Disable() end
    if NozdorRaffleFinishButton then NozdorRaffleFinishButton:Disable() end
    if NozdorRaffleStartButton then NozdorRaffleStartButton:Enable() end
    if #self.participants == 0 then
        print("[NozdorRaffle] Нет участников.")
        return
    end
    local winner = self.participants[math.random(1, #self.participants)]
    print("[NozdorRaffle] Победитель: " .. winner)
    
    -- Отправляем единое сообщение с выбранным предметом и/или ручным призом и/или голдой
    local parts = {}
    if NozdorRaffle.selectedPrize then table.insert(parts, NozdorRaffle.selectedPrize) end
    if NozdorRaffle.manualPrize and NozdorRaffle.manualPrize ~= "" then table.insert(parts, NozdorRaffle.manualPrize) end
    if NozdorRaffle.goldAmount and NozdorRaffle.goldAmount > 0 then table.insert(parts, tostring(NozdorRaffle.goldAmount) .. " золота") end
    if #parts > 0 then
        SendChatMessage("Поздравляем! Вы выиграли: " .. table.concat(parts, "; "), "WHISPER", nil, winner)
    else
        SendChatMessage("Поздравляем! Вы победили в розыгрыше!", "WHISPER", nil, winner)
    end
    
    -- Сформировать человекочитаемый приз для истории
    local prizeTextHist = nil
    if NozdorRaffle.goldAmount and NozdorRaffle.goldAmount > 0 then
        prizeTextHist = string.format("Голда: %d", NozdorRaffle.goldAmount)
    end
    if NozdorRaffle.selectedPrize then
        local name = Nozdor_ItemNameFromLink(NozdorRaffle.selectedPrize) or "предмет"
        prizeTextHist = prizeTextHist and (prizeTextHist .. ", " .. name) or name
    end
    if NozdorRaffle.manualPrize and NozdorRaffle.manualPrize ~= "" then
        prizeTextHist = prizeTextHist and (prizeTextHist .. ", " .. NozdorRaffle.manualPrize) or NozdorRaffle.manualPrize
    end

    if NozdorHistory and NozdorHistory.Add then
        NozdorHistory:Add(winner, prizeTextHist)
    else
        self.history = self.history or {}
        table.insert(self.history, {winner = winner, time = date(), prize = prizeTextHist, confirmed = false})
    end
    if NozdorLog then NozdorLog("Winner", winner) end

    NozdorRaffle_UpdateWinnersPanel()

    -- Запускаем этап подтверждения
    local timeout = tonumber(NozdorRaffleConfirmTimeBox and NozdorRaffleConfirmTimeBox:GetText() or "60") or 60
    NozdorRaffle.awaitConfirm = {
        winner = winner,
        confirmed = false,
        timeout = timeout,
        remain = timeout,
    }
    if NozdorRaffleWinnerLabel then NozdorRaffleWinnerLabel:SetText("Победитель: " .. winner) end
    if NozdorRaffleStatusLabel then 
        NozdorRaffleStatusLabel:SetText("Статус: ожидаем")
        if NozdorRaffleStatusLabel.SetTextColor then NozdorRaffleStatusLabel:SetTextColor(1, 0.82, 0) end -- жёлтый
    end
    if NozdorRaffleConfirmTimerLabel then NozdorRaffleConfirmTimerLabel:SetText("Осталось: " .. timeout .. "с") end
    if NozdorRaffleConfirmPrizeLabel then
        local prizeText = nil
        if NozdorRaffle.goldAmount and NozdorRaffle.goldAmount > 0 then
            prizeText = string.format("Голда: %d", NozdorRaffle.goldAmount)
        end
        if NozdorRaffle.selectedPrize then
            local name = GetItemInfo(NozdorRaffle.selectedPrize)
            prizeText = prizeText and (prizeText .. ", " .. (name or "предмет")) or (name or "предмет")
        end
        if NozdorRaffle.manualPrize and NozdorRaffle.manualPrize ~= "" then
            prizeText = prizeText and (prizeText .. ", " .. NozdorRaffle.manualPrize) or NozdorRaffle.manualPrize
        end
        local displayPrize = prizeText and Nozdor_Utf8Truncate(prizeText, 28) or "-"
        NozdorRaffleConfirmPrizeLabel:SetText("Приз: " .. displayPrize)
    end

    if not NozdorRaffleConfirmTicker then
        NozdorRaffleConfirmTicker = CreateFrame("Frame")
    end
    NozdorRaffleConfirmTicker:SetScript("OnUpdate", function(_, elapsed)
        local st = NozdorRaffle.awaitConfirm
        if not st or st.confirmed then
            NozdorRaffleConfirmTicker:SetScript("OnUpdate", nil)
            return
        end
        st.remain = st.remain - (elapsed or 0)
        local r = math.ceil(st.remain)
        if NozdorRaffleConfirmTimerLabel then NozdorRaffleConfirmTimerLabel:SetText("Осталось: " .. r .. "с") end
        if st.remain <= 0 then
            NozdorRaffleConfirmTicker:SetScript("OnUpdate", nil)
            if NozdorRaffleStatusLabel then 
                NozdorRaffleStatusLabel:SetText("Статус: не подтвердил")
                if NozdorRaffleStatusLabel.SetTextColor then NozdorRaffleStatusLabel:SetTextColor(1, 0, 0) end -- красный
            end
            print("[NozdorRaffle] Победитель не подтвердил вовремя.")
            if NozdorLog then NozdorLog("Winner_Confirm_Timeout", st.winner) end
            -- Если включен авто-реролл, запускаем реролл
            if NozdorRaffleAutoRerollBox and NozdorRaffleAutoRerollBox:GetChecked() then
                NozdorRaffle_Reroll()
            end
        end
    end)
end

-- Реролл: удаляем последнего победителя из истории и выбираем нового из оставшихся
function NozdorRaffle_Reroll()
    if not NozdorRaffle.participants or #NozdorRaffle.participants == 0 then
        print("[NozdorRaffle] Нет участников для реролла.")
        return
    end

    local lastWinner = nil
    if NozdorRaffleHistory and type(NozdorRaffleHistory) == "table" and #NozdorRaffleHistory > 0 then
        lastWinner = NozdorRaffleHistory[#NozdorRaffleHistory].winner
        table.remove(NozdorRaffleHistory, #NozdorRaffleHistory)
    elseif NozdorRaffle.history and #NozdorRaffle.history > 0 then
        lastWinner = NozdorRaffle.history[#NozdorRaffle.history].winner
        table.remove(NozdorRaffle.history, #NozdorRaffle.history)
    end

    -- Удаляем предыдущего победителя из списка участников для визуального обновления
    if lastWinner then
        for i = #NozdorRaffle.participants, 1, -1 do
            if NozdorRaffle.participants[i] == lastWinner then
                table.remove(NozdorRaffle.participants, i)
            end
        end
        NozdorRaffle_UpdateParticipantsUI()
    end

    local pool = {}
    for _, name in ipairs(NozdorRaffle.participants) do
        if name ~= lastWinner then table.insert(pool, name) end
    end

    if #pool == 0 then
        print("[NozdorRaffle] Остались только предыдущий победитель — реролл невозможен.")
        return
    end

    local winner = pool[math.random(1, #pool)]
    print("[NozdorRaffle] Новый победитель: " .. winner)
    
    -- Отправляем единое сообщение с выбранным предметом и/или ручным призом и/или голдой
    local parts = {}
    if NozdorRaffle.selectedPrize then table.insert(parts, NozdorRaffle.selectedPrize) end
    if NozdorRaffle.manualPrize and NozdorRaffle.manualPrize ~= "" then table.insert(parts, NozdorRaffle.manualPrize) end
    if NozdorRaffle.goldAmount and NozdorRaffle.goldAmount > 0 then table.insert(parts, tostring(NozdorRaffle.goldAmount) .. " золота") end
    if #parts > 0 then
        SendChatMessage("Реролл! Вы выиграли: " .. table.concat(parts, "; "), "WHISPER", nil, winner)
    else
        SendChatMessage("Реролл! Новый победитель!", "WHISPER", nil, winner)
    end

    -- Сформировать человекочитаемый приз для истории
    local prizeTextHist = nil
    if NozdorRaffle.goldAmount and NozdorRaffle.goldAmount > 0 then
        prizeTextHist = string.format("Голда: %d", NozdorRaffle.goldAmount)
    end
    if NozdorRaffle.selectedPrize then
        local name = Nozdor_ItemNameFromLink(NozdorRaffle.selectedPrize) or "предмет"
        prizeTextHist = prizeTextHist and (prizeTextHist .. ", " .. name) or name
    end
    if NozdorRaffle.manualPrize and NozdorRaffle.manualPrize ~= "" then
        prizeTextHist = prizeTextHist and (prizeTextHist .. ", " .. NozdorRaffle.manualPrize) or NozdorRaffle.manualPrize
    end

    if NozdorHistory and NozdorHistory.Add then
        NozdorHistory:Add(winner, prizeTextHist)
    else
        NozdorRaffle.history = NozdorRaffle.history or {}
        table.insert(NozdorRaffle.history, {winner = winner, time = date(), prize = prizeTextHist, confirmed = false})
    end

    if NozdorLog then NozdorLog("Reroll_Winner", winner) end

    -- Обновляем панель подтверждения и перезапускаем отсчёт
    local timeout = tonumber(NozdorRaffleConfirmTimeBox and NozdorRaffleConfirmTimeBox:GetText() or "60") or 60
    NozdorRaffle.awaitConfirm = {
        winner = winner,
        confirmed = false,
        timeout = timeout,
        remain = timeout,
    }
    if NozdorRaffleWinnerLabel then NozdorRaffleWinnerLabel:SetText("Победитель: " .. winner) end
    if NozdorRaffleStatusLabel then NozdorRaffleStatusLabel:SetText("Статус: ожидаем") end
    if NozdorRaffleConfirmTimerLabel then NozdorRaffleConfirmTimerLabel:SetText("Осталось: " .. timeout .. "с") end
    if NozdorRaffleConfirmPrizeLabel then
        local prizeText = nil
        if NozdorRaffle.goldAmount and NozdorRaffle.goldAmount > 0 then
            prizeText = string.format("Голда: %d", NozdorRaffle.goldAmount)
        end
        if NozdorRaffle.selectedPrize then
            local name = GetItemInfo(NozdorRaffle.selectedPrize)
            prizeText = prizeText and (prizeText .. ", " .. (name or "предмет")) or (name or "предмет")
        end
        if NozdorRaffle.manualPrize and NozdorRaffle.manualPrize ~= "" then
            prizeText = prizeText and (prizeText .. ", " .. NozdorRaffle.manualPrize) or NozdorRaffle.manualPrize
        end
        local displayPrize = prizeText and Nozdor_Utf8Truncate(prizeText, 40) or "-"
        NozdorRaffleConfirmPrizeLabel:SetText("Приз: " .. displayPrize)
    end

    if not NozdorRaffleConfirmTicker then
        NozdorRaffleConfirmTicker = CreateFrame("Frame")
    end
    NozdorRaffleConfirmTicker:SetScript("OnUpdate", function(_, elapsed)
        local st = NozdorRaffle.awaitConfirm
        if not st or st.confirmed then
            NozdorRaffleConfirmTicker:SetScript("OnUpdate", nil)
            return
        end
        st.remain = st.remain - (elapsed or 0)
        local r = math.ceil(st.remain)
        if NozdorRaffleConfirmTimerLabel then NozdorRaffleConfirmTimerLabel:SetText("Осталось: " .. r .. "с") end
        if st.remain <= 0 then
            NozdorRaffleConfirmTicker:SetScript("OnUpdate", nil)
            if NozdorRaffleStatusLabel then NozdorRaffleStatusLabel:SetText("Статус: не подтвердил") end
            print("[NozdorRaffle] Победитель не подтвердил вовремя.")
            if NozdorLog then NozdorLog("Winner_Confirm_Timeout", st.winner) end
        end
    end)

    NozdorRaffle_UpdateWinnersPanel()
end

-- Обновление панели последних победителей
function NozdorRaffle_UpdateWinnersPanel()
    if not NozdorRaffleWinnersPanel or not NozdorRaffleWinnersPanel.labels then return end
    local src = NozdorRaffleHistory or {}
    local total = #src
    local maxLabels = #NozdorRaffleWinnersPanel.labels

    -- Заполняем по убыванию: последний, затем предыдущие
    local maxVisible = 0
    for i = 1, maxLabels do
        local label = NozdorRaffleWinnersPanel.labels[i]
        if label then
            local idx = total - (i-1)
            local entry = src[idx]
            if entry then
                local confirmed = entry.confirmed and true or false
                local statusText = confirmed and "подтвердил" or "не подтвердил"
                label.text:SetText(string.format("%s — %s", entry.winner or "?", statusText))
                if label.text.SetTextColor then
                    if confirmed then
                        label.text:SetTextColor(0, 1, 0) -- зелёный
                    else
                        label.text:SetTextColor(1, 0, 0) -- красный
                    end
                end
                label._timestamp = entry.timestamp or entry.time or ""
                label._prize = entry.prize
                label:Show()
                maxVisible = i
            else
                label.text:SetText("")
                if label.text.SetTextColor then label.text:SetTextColor(1, 1, 1) end
                label._timestamp = nil
                label._prize = nil
                label:Hide()
            end
        end
    end
    -- Обновить высоту контента для скролла
    if NozdorRaffleWinnersPanel.scrollChild and maxVisible > 0 then
        local contentHeight = maxVisible * 18 + 10
        NozdorRaffleWinnersPanel.scrollChild:SetHeight(contentHeight)
    end
end

function NozdorRaffle:CancelRaffle()
    self.isActive = false
    self.isPaused = false
    if NozdorTimer and NozdorTimer:IsActive() then
        NozdorTimer:Cancel()
    end
    if NozdorRaffleTopLeftTimer then
        NozdorRaffleTopLeftTimer:SetText("")
    end
    if NozdorRaffleStopButton then NozdorRaffleStopButton:Disable() end
    if NozdorRaffleCancelButton then NozdorRaffleCancelButton:Disable() end
    if NozdorRaffleStartButton then NozdorRaffleStartButton:Enable() end
    print("[NozdorRaffle] Розыгрыш отменён.")
end

-- Полная очистка состояния (сохранить содержимое всех полей ввода)
function NozdorRaffle_ClearAll()
    -- Остановить активные таймеры
    if NozdorTimer and NozdorTimer:IsActive() then
        NozdorTimer:Cancel()
    end
    if NozdorRaffleConfirmTicker then
        NozdorRaffleConfirmTicker:SetScript("OnUpdate", nil)
    end

    -- Сброс статусов
    NozdorRaffle.isActive = false
    NozdorRaffle.isPaused = false
    NozdorRaffle.awaitConfirm = nil

    -- Очистить участников
    NozdorRaffle.participants = {}
    NozdorRaffle_UpdateParticipantsUI()

    -- Сбросить текстовые метки (но не трогать поля ввода)
    if NozdorRaffleTopLeftTimer then NozdorRaffleTopLeftTimer:SetText("") end
    if NozdorRaffleStatusLabel then NozdorRaffleStatusLabel:SetText("Статус: ожидаем") end
    if NozdorRaffleWinnerLabel then NozdorRaffleWinnerLabel:SetText("Победитель: -") end
    if NozdorRaffleConfirmTimerLabel then NozdorRaffleConfirmTimerLabel:SetText("Осталось: -") end

    -- Кнопки в исходное состояние
    if NozdorRaffleStopButton then NozdorRaffleStopButton:Disable() end
    if NozdorRaffleCancelButton then NozdorRaffleCancelButton:Disable() end
    if NozdorRaffleFinishButton then NozdorRaffleFinishButton:Disable() end
    if NozdorRaffleStartButton then NozdorRaffleStartButton:Enable() end

    print("[NozdorRaffle] Очищено. Поля ввода сохранены.")
    if NozdorLog then NozdorLog("UI_Clear") end
end

-- Собираем только из личных сообщений (ЛС/WHISPER)
frame:RegisterEvent("CHAT_MSG_WHISPER")

local function listContains(list, value)
    for i=1,#list do if list[i] == value then return true end end
    return false
end
local function trimLower(s)
    if not s then return "" end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end
frame:SetScript("OnEvent", function(_, event, msg, sender)
    if event ~= "CHAT_MSG_WHISPER" then return end
    
    DebugPrint("[DEBUG] Получено ЛС от " .. tostring(sender) .. ": " .. tostring(msg))
    
    -- Если идёт этап подтверждения победителя — принимаем любое сообщение от победителя
    if NozdorRaffle.awaitConfirm and NozdorRaffle.awaitConfirm.winner then
        if sender == NozdorRaffle.awaitConfirm.winner then
            NozdorRaffle.awaitConfirm.confirmed = true
            if NozdorRaffleStatusLabel then 
                NozdorRaffleStatusLabel:SetText("Статус: подтвердил") 
                if NozdorRaffleStatusLabel.SetTextColor then NozdorRaffleStatusLabel:SetTextColor(0, 1, 0) end -- зелёный
            end
            print("[NozdorRaffle] Победитель подтвердил получение награды: " .. sender)
            if NozdorLog then NozdorLog("Winner_Confirmed", sender) end
            if NozdorHistory and NozdorHistory.MarkConfirmed then
                NozdorHistory:MarkConfirmed(sender)
                NozdorRaffle_UpdateWinnersPanel()
            end
            return
        end
    end

    if not NozdorRaffle.isActive then 
        DebugPrint("[DEBUG] Розыгрыш неактивен")
        return 
    end
    
    local m = trimLower(msg)
    local k = trimLower(NozdorRaffle.keyword)
    
    DebugPrint("[DEBUG] Сравниваю: '" .. m .. "' с '" .. k .. "'")
    
    if k ~= "" and (m == k or m:find(k, 1, true)) then
        if not listContains(NozdorRaffle.participants, sender) then
            table.insert(NozdorRaffle.participants, sender)
            print("[NozdorRaffle] " .. sender .. " добавлен в список участников.")
            DebugPrint("[DEBUG] Всего участников: " .. #NozdorRaffle.participants)
            
            -- Обновляем UI независимо от видимости
            NozdorRaffle_UpdateParticipantsUI()
        else
            DebugPrint("[DEBUG] " .. sender .. " уже в списке")
        end
    else
        DebugPrint("[DEBUG] Ключевое слово не совпадает")
    end
end)

SLASH_NOZDORRAFFLE1 = "/raf"
SlashCmdList["NOZDORRAFFLE"] = function(msg)
    if not NozdorRaffle.isActive then
        local keyword = msg and msg:match("%S+") or nil
        NozdorRaffle:StartRaffle(keyword)
    else
        print("[NozdorRaffle] Розыгрыш уже запущен!")
    end
end
