-- [KWa]HunterAssist - WoW 1.12
-- Unhappy alert (repeatable, OUT-OF-COMBAT only) + Feed Pet countdown + debug

local f = CreateFrame("Frame")

-- Saved config
local DEFAULTS = {
    enabled = true,
    sound = true,
    interval = 5, -- seconds between repeat alerts while Unhappy (1..60)
    feeddur = 20, -- default Feed Pet buff duration in seconds (3..120)
    feedname = "Feed Pet Effect", -- pet buff name to match (if tooltip API available)
    debug = false -- /kwa ha debug on|off
}

KWA_HunterAssist_Config = KWA_HunterAssist_Config or
        {
            enabled = DEFAULTS.enabled,
            sound = DEFAULTS.sound,
            interval = DEFAULTS.interval,
            feeddur = DEFAULTS.feeddur,
            feedname = DEFAULTS.feedname,
            debug = DEFAULTS.debug,
            configX = nil,
            configY = nil
        }

-- ======= State =======
local lastHappiness
local unhappyActive = false
local alertTimer = 0
local inCombat = false -- NEW: track combat state
local pendingUnhappyAlert = false -- NEW: queue alert if transition occurs during combat

local feedPendingCast = false
local feedActive = false
local feedTimeLeft = 0

-- ======= UI: feed countdown text (vanilla-safe) =======
local feedFrame = CreateFrame("Frame", nil, UIParent)
feedFrame:SetFrameStrata("HIGH")
feedFrame:SetWidth(320)
feedFrame:SetHeight(44)
feedFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)

local feedText = feedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
feedText:SetAllPoints(feedFrame)
feedText:SetJustifyH("CENTER")
feedText:SetJustifyV("MIDDLE")
if feedText.SetFont then
    feedText:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
end
feedText:SetText("")
feedFrame:Hide()

local function ShowFeedCountdown(sec)
    feedTimeLeft = sec
    feedActive = true
    feedFrame:Show()
end

local function HideFeedCountdown()
    feedActive = false
    feedTimeLeft = 0
    feedFrame:Hide()
end

-- ======= UI: config window =======
local configFrame = CreateFrame("Frame", "KWA_ConfigFrame", UIParent)
configFrame:SetWidth(320)
configFrame:SetHeight(300)
configFrame:SetFrameStrata("DIALOG")
configFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 16, tile = true, tileSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
configFrame:SetBackdropColor(0, 0, 0, 1)
configFrame:EnableMouse(true)
configFrame:SetMovable(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", function()
    this:StartMoving()
end)
configFrame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    KWA_HunterAssist_Config.configX = this:GetLeft()
    KWA_HunterAssist_Config.configY = this:GetTop()
end)
configFrame:Hide()

local cfgTitle = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cfgTitle:SetPoint("TOP", 0, -10)
cfgTitle:SetText("[KWa]HunterAssist")

local petGroup = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
petGroup:SetPoint("TOPLEFT", 20, -30)
petGroup:SetText("Pet Happiness")

-- Enabled checkbox
local enabledCheck = CreateFrame("CheckButton", "KWA_ConfigEnabled", configFrame, "UICheckButtonTemplate")
enabledCheck:SetPoint("TOPLEFT", petGroup, "BOTTOMLEFT", 0, -10)
getglobal(enabledCheck:GetName() .. "Text"):SetText("Addon enabled")
enabledCheck:SetScript("OnClick", function()
    KWA_HunterAssist_Config.enabled = this:GetChecked()
end)
local enabledDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
enabledDefault:SetWidth(60)
enabledDefault:SetHeight(20)
enabledDefault:SetPoint("LEFT", enabledCheck, "RIGHT", 120, 0)
enabledDefault:SetText("Default")
enabledDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.enabled = DEFAULTS.enabled
    enabledCheck:SetChecked(DEFAULTS.enabled)
end)

-- Sound checkbox
local soundCheck = CreateFrame("CheckButton", "KWA_ConfigSound", configFrame, "UICheckButtonTemplate")
soundCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 0, -10)
getglobal(soundCheck:GetName() .. "Text"):SetText("Play sound")
soundCheck:SetScript("OnClick", function()
    KWA_HunterAssist_Config.sound = this:GetChecked()
end)
local soundDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
soundDefault:SetWidth(60)
soundDefault:SetHeight(20)
soundDefault:SetPoint("LEFT", soundCheck, "RIGHT", 120, 0)
soundDefault:SetText("Default")
soundDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.sound = DEFAULTS.sound
    soundCheck:SetChecked(DEFAULTS.sound)
end)

-- Interval edit box
local intervalLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
intervalLabel:SetPoint("TOPLEFT", soundCheck, "BOTTOMLEFT", 0, -12)
intervalLabel:SetText("Alert interval (1-60):")
local intervalBox = CreateFrame("EditBox", "KWA_ConfigInterval", configFrame, "InputBoxTemplate")
intervalBox:SetWidth(40)
intervalBox:SetHeight(20)
intervalBox:SetPoint("LEFT", intervalLabel, "RIGHT", 10, 0)
intervalBox:SetAutoFocus(false)
intervalBox:SetScript("OnEnterPressed", function()
    local v = tonumber(this:GetText())
    if v then
        KWA_HunterAssist_Config.interval = v
        alertTimer = 0
    end
    this:ClearFocus()
end)
local intervalDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
intervalDefault:SetWidth(60)
intervalDefault:SetHeight(20)
intervalDefault:SetPoint("LEFT", intervalBox, "RIGHT", 10, 0)
intervalDefault:SetText("Default")
intervalDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.interval = DEFAULTS.interval
    intervalBox:SetText(DEFAULTS.interval)
    alertTimer = 0
end)

-- Feed duration
local feedDurLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
feedDurLabel:SetPoint("TOPLEFT", intervalLabel, "BOTTOMLEFT", 0, -12)
feedDurLabel:SetText("Feed duration (3-120):")
local feedDurBox = CreateFrame("EditBox", "KWA_ConfigFeeddur", configFrame, "InputBoxTemplate")
feedDurBox:SetWidth(40)
feedDurBox:SetHeight(20)
feedDurBox:SetPoint("LEFT", feedDurLabel, "RIGHT", 10, 0)
feedDurBox:SetAutoFocus(false)
feedDurBox:SetScript("OnEnterPressed", function()
    local v = tonumber(this:GetText())
    if v then
        KWA_HunterAssist_Config.feeddur = v
        if feedActive then
            ShowFeedCountdown(v)
        end
    end
    this:ClearFocus()
end)
local feedDurDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
feedDurDefault:SetWidth(60)
feedDurDefault:SetHeight(20)
feedDurDefault:SetPoint("LEFT", feedDurBox, "RIGHT", 10, 0)
feedDurDefault:SetText("Default")
feedDurDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.feeddur = DEFAULTS.feeddur
    feedDurBox:SetText(DEFAULTS.feeddur)
    if feedActive then
        ShowFeedCountdown(DEFAULTS.feeddur)
    end
end)

-- Feed buff name
local feedNameLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
feedNameLabel:SetPoint("TOPLEFT", feedDurLabel, "BOTTOMLEFT", 0, -12)
feedNameLabel:SetText("Feed buff name:")
local feedNameBox = CreateFrame("EditBox", "KWA_ConfigFeedName", configFrame, "InputBoxTemplate")
feedNameBox:SetWidth(120)
feedNameBox:SetHeight(20)
feedNameBox:SetPoint("LEFT", feedNameLabel, "RIGHT", 10, 0)
feedNameBox:SetAutoFocus(false)
feedNameBox:SetScript("OnEnterPressed", function()
    local txt = this:GetText()
    if txt and txt ~= "" then
        KWA_HunterAssist_Config.feedname = txt
    end
    this:ClearFocus()
end)
local feedNameDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
feedNameDefault:SetWidth(60)
feedNameDefault:SetHeight(20)
feedNameDefault:SetPoint("LEFT", feedNameBox, "RIGHT", 10, 0)
feedNameDefault:SetText("Default")
feedNameDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.feedname = DEFAULTS.feedname
    feedNameBox:SetText(DEFAULTS.feedname)
end)

local generalGroup = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
generalGroup:SetPoint("TOPLEFT", feedNameLabel, "BOTTOMLEFT", 0, -20)
generalGroup:SetText("General")

-- Debug checkbox
local debugCheck = CreateFrame("CheckButton", "KWA_ConfigDebug", configFrame, "UICheckButtonTemplate")
debugCheck:SetPoint("TOPLEFT", generalGroup, "BOTTOMLEFT", 0, -10)
getglobal(debugCheck:GetName() .. "Text"):SetText("Enable debug")
debugCheck:SetScript("OnClick", function()
    KWA_HunterAssist_Config.debug = this:GetChecked()
end)
local debugDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
debugDefault:SetWidth(60)
debugDefault:SetHeight(20)
debugDefault:SetPoint("LEFT", debugCheck, "RIGHT", 120, 0)
debugDefault:SetText("Default")
debugDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.debug = DEFAULTS.debug
    debugCheck:SetChecked(DEFAULTS.debug)
end)

-- Close button
local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
closeBtn:SetWidth(80)
closeBtn:SetHeight(22)
closeBtn:SetPoint("BOTTOM", 0, 10)
closeBtn:SetText("Close")
closeBtn:SetScript("OnClick", function()
    configFrame:Hide()
end)

configFrame:SetScript("OnShow", function()
    enabledCheck:SetChecked(KWA_HunterAssist_Config.enabled)
    soundCheck:SetChecked(KWA_HunterAssist_Config.sound)
    intervalBox:SetText(KWA_HunterAssist_Config.interval)
    feedDurBox:SetText(KWA_HunterAssist_Config.feeddur)
    feedNameBox:SetText(KWA_HunterAssist_Config.feedname or "")
    debugCheck:SetChecked(KWA_HunterAssist_Config.debug)
end)

-- ======= Helpers =======
local function IsHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

local function Debug(msg)
    if KWA_HunterAssist_Config.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa][HA][DBG]|r " .. tostring(msg))
    end
end

local function SendAlert(msg)
    -- Only alert OUT OF COMBAT
    if inCombat then
        Debug("Suppressed alert (in combat): " .. msg)
        return
    end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 1.0, 0.1, 0.1, 1.0)
    end
    if KWA_HunterAssist_Config.sound and PlaySoundFile then
        PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
    end
end

local function CurrentInterval()
    local iv = tonumber(KWA_HunterAssist_Config.interval) or 5
    if iv < 1 then
        iv = 1
    end
    if iv > 60 then
        iv = 60
    end
    return iv
end

local function CurrentFeedDur()
    local d = tonumber(KWA_HunterAssist_Config.feeddur) or 20
    if d < 3 then
        d = 3
    end
    if d > 120 then
        d = 120
    end
    return d
end

local function PetHasFeedBuff()
    if GameTooltip and GameTooltip.SetUnitBuff and GameTooltipTextLeft1 then
        for i = 1, 16 do
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            local ok = GameTooltip:SetUnitBuff("pet", i)
            if not ok then
                break
            end
            local name = GameTooltipTextLeft1:GetText()
            GameTooltip:Hide()
            if
            name and KWA_HunterAssist_Config.feedname and
                    string.lower(name) == string.lower(KWA_HunterAssist_Config.feedname)
            then
                return true
            end
        end
    end
    return feedPendingCast
end

-- ======= Core checks =======
local function CheckPet(force)
    if not KWA_HunterAssist_Config.enabled then
        return
    end
    if not IsHunter() then
        return
    end

    if not UnitExists("pet") then
        unhappyActive = false
        alertTimer = 0
        lastHappiness = nil
        pendingUnhappyAlert = false
        HideFeedCountdown()
        return
    end

    local happiness = GetPetHappiness and GetPetHappiness()
    local petName = UnitName("pet") or "Your pet"

    if happiness == 1 then
        -- Pet is unhappy
        if force or lastHappiness ~= 1 then
            if inCombat then
                -- Do NOT alert now; queue one for when we leave combat
                pendingUnhappyAlert = true
                Debug("Unhappy transition DURING combat -> queued for after combat.")
            else
                SendAlert(petName .. " is UNHAPPY!")
                alertTimer = 0
                pendingUnhappyAlert = false
                Debug("Unhappy transition -> immediate alert (out of combat).")
            end
        end
        unhappyActive = true
    else
        unhappyActive = false
        alertTimer = 0
        pendingUnhappyAlert = false
    end

    lastHappiness = happiness
end

-- ======= Events =======
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_PET")
f:RegisterEvent("UNIT_HAPPINESS")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("SPELLCAST_START")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript(
        "OnEvent",
        function()
            if event == "PLAYER_LOGIN" then
                KWA_HunterAssist_Config = KWA_HunterAssist_Config or {}
                for k, v in pairs(DEFAULTS) do
                    if KWA_HunterAssist_Config[k] == nil then
                        KWA_HunterAssist_Config[k] = v
                    end
                end
                if KWA_HunterAssist_Config.configX and KWA_HunterAssist_Config.configY then
                    configFrame:ClearAllPoints()
                    configFrame:SetPoint(
                            "TOPLEFT",
                            UIParent,
                            "BOTTOMLEFT",
                            KWA_HunterAssist_Config.configX,
                            KWA_HunterAssist_Config.configY
                    )
                else
                    configFrame:ClearAllPoints()
                    configFrame:SetPoint("CENTER", UIParent, "CENTER")
                end
                inCombat = UnitAffectingCombat("player") or false
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r loaded. /kwa ha help or /kwa config")
                Debug("PLAYER_LOGIN; inCombat=" .. tostring(inCombat))
            elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
                Debug(event .. ": reset states")
                CheckPet(true)
                HideFeedCountdown()
                feedPendingCast = false
            elseif event == "UNIT_HAPPINESS" and arg1 == "pet" then
                Debug("UNIT_HAPPINESS for pet")
                CheckPet(false)
            elseif event == "SPELLCAST_START" then
                local spell = arg1
                Debug("SPELLCAST_START: " .. tostring(spell))
                if spell and string.lower(spell) == "feed pet" then
                    feedPendingCast = true
                    Debug("Detected Feed Pet via SPELLCAST_START")
                end
            elseif event == "UNIT_AURA" and arg1 == "pet" then
                Debug("UNIT_AURA for pet. feedPendingCast=" .. tostring(feedPendingCast))
                if feedPendingCast and PetHasFeedBuff() then
                    Debug("Feed buff detected -> start countdown")
                    ShowFeedCountdown(CurrentFeedDur())
                    feedPendingCast = false
                elseif feedActive and not PetHasFeedBuff() then
                    Debug("Feed buff ended -> hide countdown")
                    HideFeedCountdown()
                end
            elseif event == "PLAYER_REGEN_DISABLED" then
                -- Feeding already cancels on combat; leave unhappy timer paused automatically.
                inCombat = true
                Debug("PLAYER_REGEN_DISABLED -> inCombat=true")
            elseif event == "PLAYER_REGEN_ENABLED" then
                inCombat = false
                Debug("PLAYER_REGEN_ENABLED -> inCombat=false")
                -- If we became unhappy during combat, fire the queued alert now.
                if pendingUnhappyAlert and KWA_HunterAssist_Config.enabled and UnitExists("pet") then
                    local happiness = GetPetHappiness and GetPetHappiness()
                    if happiness == 1 then
                        local petName = UnitName("pet") or "Your pet"
                        SendAlert(petName .. " is UNHAPPY!")
                        alertTimer = 0
                    end
                end
                pendingUnhappyAlert = false
            end
        end
)

-- ======= OnUpdate =======
f:SetScript(
        "OnUpdate",
        function()
            local elapsed = arg1 or 0

            -- Unhappy repeat (only OUT OF COMBAT)
            if KWA_HunterAssist_Config.enabled and unhappyActive and not inCombat then
                alertTimer = alertTimer + elapsed
                if alertTimer >= CurrentInterval() then
                    local petName = UnitName("pet") or "Your pet"
                    SendAlert(petName .. " is UNHAPPY!")
                    alertTimer = 0
                end
            end

            -- Feed countdown
            if feedActive then
                if not UnitExists("pet") or UnitAffectingCombat("pet") then
                    Debug("Pet gone or in combat -> hide countdown")
                    HideFeedCountdown()
                else
                    feedTimeLeft = feedTimeLeft - elapsed
                    if feedTimeLeft <= 0 then
                        Debug("Countdown finished")
                        HideFeedCountdown()
                    else
                        local secs = math.floor(feedTimeLeft * 10 + 0.5) / 10
                        feedText:SetText("|cff00ff00Feeding:|r " .. secs .. "s")
                    end
                end
            end
        end
)

-- ======= Hooks to detect Feed Pet from all cast paths =======
local _Orig_CastSpell = CastSpell
CastSpell = function(spellId, bookTab)
    if GetSpellName then
        local name = GetSpellName(spellId, bookTab)
        if name and string.lower(name) == "feed pet" then
            feedPendingCast = true
            Debug("Detected Feed Pet via CastSpell")
        end
    end
    return _Orig_CastSpell(spellId, bookTab)
end

local _Orig_CastSpellByName = CastSpellByName
CastSpellByName = function(spell, onSelf)
    if spell and string.find(string.lower(spell), "^feed pet") then
        feedPendingCast = true
        Debug("Detected Feed Pet via CastSpellByName")
    end
    return _Orig_CastSpellByName(spell, onSelf)
end

local _Orig_UseAction = UseAction
UseAction = function(slot, checkCursor, onSelf)
    if GameTooltip and GameTooltip.SetAction and GameTooltipTextLeft1 then
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip:SetAction(slot)
        local name = GameTooltipTextLeft1:GetText()
        GameTooltip:Hide()
        if name and string.lower(name) == "feed pet" then
            feedPendingCast = true
            Debug("Detected Feed Pet via UseAction slot " .. tostring(slot))
        end
    end
    return _Orig_UseAction(slot, checkCursor, onSelf)
end

-- ======= Slash: /kwa ha {options} =======
SLASH_KWA1 = "/kwa"
SlashCmdList["KWA"] = function(msg)
    msg = tostring(msg or "")
    msg = string.lower((string.gsub(msg, "^%s*(.-)%s*$", "%1")))

    local sp = string.find(msg, "%s")
    local cmd, rest
    if sp then
        cmd = string.sub(msg, 1, sp - 1)
        rest = string.sub(msg, sp + 1)
        rest = string.gsub(rest, "^%s*", "")
    else
        cmd, rest = msg, ""
    end

    if cmd == "config" then
        if configFrame:IsShown() then
            configFrame:Hide()
        else
            configFrame:Show()
        end
        return
    end

    if cmd ~= "ha" then
        return
    end

    if rest == "help" or rest == "" then
        DEFAULT_CHAT_FRAME:AddMessage(
                "|cff00ff00[KWa]HunterAssist:|r /kwa ha on|off | sound on|off | test | interval <1-60> | feeddur <3-120> | feedname <buff name> | debug on|off | reset"
        )
        DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffff00Notes:|r Unhappy alerts are OUT-OF-COMBAT only; if Unhappy during combat, one alert will fire when combat ends."
        )
    elseif rest == "on" then
        KWA_HunterAssist_Config.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r enabled.")
    elseif rest == "off" then
        KWA_HunterAssist_Config.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r disabled.")
    elseif rest == "sound on" then
        KWA_HunterAssist_Config.sound = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r sound enabled.")
    elseif rest == "sound off" then
        KWA_HunterAssist_Config.sound = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r sound disabled.")
    elseif string.sub(rest, 1, 8) == "interval" then
        local n = tonumber(string.gsub(string.sub(rest, 9), "^%s*", ""))
        if n then
            if n < 1 then
                n = 1
            end
            if n > 60 then
                n = 60
            end
            KWA_HunterAssist_Config.interval = n
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r unhappy repeat set to " .. n .. "s.")
            alertTimer = 0
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r usage: /kwa ha interval <1-60>")
        end
    elseif string.sub(rest, 1, 7) == "feeddur" then
        local n = tonumber(string.gsub(string.sub(rest, 8), "^%s*", ""))
        if n then
            if n < 3 then
                n = 3
            end
            if n > 120 then
                n = 120
            end
            KWA_HunterAssist_Config.feeddur = n
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r feed duration set to " .. n .. "s.")
            if feedActive then
                ShowFeedCountdown(n)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r usage: /kwa ha feeddur <3-120>")
        end
    elseif string.sub(rest, 1, 8) == "feedname" then
        local name = string.gsub(string.sub(rest, 9), "^%s*", "")
        if name and name ~= "" then
            KWA_HunterAssist_Config.feedname = name
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r feed buff name set to: " .. name)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r usage: /kwa ha feedname <buff name>")
        end
    elseif string.sub(rest, 1, 5) == "debug" then
        local flag = string.gsub(string.sub(rest, 6), "^%s*", "")
        if flag == "on" then
            KWA_HunterAssist_Config.debug = true
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r debug ON")
        elseif flag == "off" then
            KWA_HunterAssist_Config.debug = false
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r debug OFF")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r usage: /kwa ha debug on|off")
        end
    elseif rest == "reset" then
        for k, v in pairs(DEFAULTS) do
            KWA_HunterAssist_Config[k] = v
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r settings reset to defaults.")
        alertTimer = 0
        pendingUnhappyAlert = false
        HideFeedCountdown()
    elseif rest == "test" then
        local petName = UnitName("pet") or "Your pet"
        SendAlert("Test: " .. petName .. " is UNHAPPY!")
        ShowFeedCountdown(CurrentFeedDur())
    else
        DEFAULT_CHAT_FRAME:AddMessage(
                "|cff00ff00[KWa]HunterAssist:|r /kwa ha on|off | sound on|off | test | interval <1-60> | feeddur <3-120> | feedname <buff name> | debug on|off | reset"
        )
    end
end
