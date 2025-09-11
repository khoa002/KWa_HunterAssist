-- [KWa]HunterAssist - WoW 1.12
-- Unhappy alert (repeatable, OUT-OF-COMBAT only) + Feed Pet countdown + debug

local f = CreateFrame("Frame")

-- Saved config
local DEFAULT_SETTINGS = {
    general = {
        addonEnabled = true,
        debugLoggingEnabled = false,
    },
    pet = {
        alertSoundEnabled = true,
        unhappyAlertIntervalSeconds = 5, -- seconds between repeat alerts while Unhappy (1..60)
        feedBuffDurationSeconds = 20, -- default Feed Pet buff duration in seconds (3..120)
        feedBuffName = "Feed Pet Effect", -- pet buff name to match (if tooltip API available)
    },
    equipment = {
        lowAmmoThreshold = 200, -- ammo warning threshold
        lowAmmoSoundEnabled = true, -- play sound on low ammo alert
        merchantAlertEnabled = true, -- alert when visiting a merchant
    },
}

KWA_HunterAssist_Config =
    KWA_HunterAssist_Config or
    {
        general = {
            addonEnabled = DEFAULT_SETTINGS.general.addonEnabled,
            debugLoggingEnabled = DEFAULT_SETTINGS.general.debugLoggingEnabled,
        },
        pet = {
            alertSoundEnabled = DEFAULT_SETTINGS.pet.alertSoundEnabled,
            unhappyAlertIntervalSeconds = DEFAULT_SETTINGS.pet.unhappyAlertIntervalSeconds,
            feedBuffDurationSeconds = DEFAULT_SETTINGS.pet.feedBuffDurationSeconds,
            feedBuffName = DEFAULT_SETTINGS.pet.feedBuffName,
        },
        equipment = {
            lowAmmoThreshold = DEFAULT_SETTINGS.equipment.lowAmmoThreshold,
            lowAmmoSoundEnabled = DEFAULT_SETTINGS.equipment.lowAmmoSoundEnabled,
            merchantAlertEnabled = DEFAULT_SETTINGS.equipment.merchantAlertEnabled,
        },
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
configFrame:SetHeight(400)
configFrame:SetFrameStrata("DIALOG")
configFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 16, tile = true, tileSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
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
local COL_LABEL_X, COL_INPUT_X, COL_DEFAULT_X = 20, 160, 240

-- ======= General group =======
local generalGroup = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
generalGroup:SetPoint("TOPLEFT", COL_LABEL_X, -30)
generalGroup:SetText("General")

-- Addon enabled
local enabledLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enabledLabel:SetPoint("TOPLEFT", generalGroup, "BOTTOMLEFT", 0, -10)
enabledLabel:SetText("Addon enabled")
local enabledCheck = CreateFrame("CheckButton", "KWA_ConfigEnabled", configFrame, "UICheckButtonTemplate")
enabledCheck:SetPoint("LEFT", enabledLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
local enabledDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
enabledDefault:SetWidth(60)
enabledDefault:SetHeight(20)
enabledDefault:SetPoint("LEFT", enabledLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
enabledDefault:SetText("Default")
enabledDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.general.addonEnabled = DEFAULT_SETTINGS.general.addonEnabled
    enabledCheck:SetChecked(DEFAULT_SETTINGS.general.addonEnabled)
end)
enabledCheck:SetScript("OnClick", function()
    KWA_HunterAssist_Config.general.addonEnabled = this:GetChecked()
end)

-- Debug
local debugLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debugLabel:SetPoint("TOPLEFT", enabledLabel, "BOTTOMLEFT", 0, -10)
debugLabel:SetText("Enable debug")
local debugCheck = CreateFrame("CheckButton", "KWA_ConfigDebug", configFrame, "UICheckButtonTemplate")
debugCheck:SetPoint("LEFT", debugLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
local debugDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
debugDefault:SetWidth(60)
debugDefault:SetHeight(20)
debugDefault:SetPoint("LEFT", debugLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
debugDefault:SetText("Default")
debugDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.general.debugLoggingEnabled = DEFAULT_SETTINGS.general.debugLoggingEnabled
    debugCheck:SetChecked(DEFAULT_SETTINGS.general.debugLoggingEnabled)
end)
debugCheck:SetScript("OnClick", function()
    KWA_HunterAssist_Config.general.debugLoggingEnabled = this:GetChecked()
end)

-- ======= Pet Happiness group =======
local petGroup = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
petGroup:SetPoint("TOPLEFT", debugLabel, "BOTTOMLEFT", 0, -20)
petGroup:SetText("Pet Happiness")

-- Play sound
local soundLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soundLabel:SetPoint("TOPLEFT", petGroup, "BOTTOMLEFT", 0, -10)
soundLabel:SetText("Play sound")
local soundCheck = CreateFrame("CheckButton", "KWA_ConfigSound", configFrame, "UICheckButtonTemplate")
soundCheck:SetPoint("LEFT", soundLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
local soundDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
soundDefault:SetWidth(60)
soundDefault:SetHeight(20)
soundDefault:SetPoint("LEFT", soundLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
soundDefault:SetText("Default")
soundDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.pet.alertSoundEnabled = DEFAULT_SETTINGS.pet.alertSoundEnabled
    soundCheck:SetChecked(DEFAULT_SETTINGS.pet.alertSoundEnabled)
end)
soundCheck:SetScript("OnClick", function()
    KWA_HunterAssist_Config.pet.alertSoundEnabled = this:GetChecked()
end)

-- Alert interval
local intervalLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
intervalLabel:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -12)
intervalLabel:SetText("Alert interval (1-60):")
local intervalBox = CreateFrame("EditBox", "KWA_ConfigInterval", configFrame, "InputBoxTemplate")
intervalBox:SetWidth(40)
intervalBox:SetHeight(20)
intervalBox:SetPoint("LEFT", intervalLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
intervalBox:SetAutoFocus(false)
intervalBox:SetScript("OnEnterPressed", function()
    local v = tonumber(this:GetText())
    if v then
        KWA_HunterAssist_Config.pet.unhappyAlertIntervalSeconds = v
        alertTimer = 0
    end
    this:ClearFocus()
end)
local intervalDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
intervalDefault:SetWidth(60)
intervalDefault:SetHeight(20)
intervalDefault:SetPoint("LEFT", intervalLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
intervalDefault:SetText("Default")
intervalDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.pet.unhappyAlertIntervalSeconds = DEFAULT_SETTINGS.pet.unhappyAlertIntervalSeconds
    intervalBox:SetText(DEFAULT_SETTINGS.pet.unhappyAlertIntervalSeconds)
    alertTimer = 0
end)

-- Feed duration
local feedDurLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
feedDurLabel:SetPoint("TOPLEFT", intervalLabel, "BOTTOMLEFT", 0, -12)
feedDurLabel:SetText("Feed duration (3-120):")
local feedDurBox = CreateFrame("EditBox", "KWA_ConfigFeeddur", configFrame, "InputBoxTemplate")
feedDurBox:SetWidth(40)
feedDurBox:SetHeight(20)
feedDurBox:SetPoint("LEFT", feedDurLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
feedDurBox:SetAutoFocus(false)
feedDurBox:SetScript("OnEnterPressed", function()
    local v = tonumber(this:GetText())
    if v then
        KWA_HunterAssist_Config.pet.feedBuffDurationSeconds = v
        if feedActive then
            ShowFeedCountdown(v)
        end
    end
    this:ClearFocus()
end)
local feedDurDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
feedDurDefault:SetWidth(60)
feedDurDefault:SetHeight(20)
feedDurDefault:SetPoint("LEFT", feedDurLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
feedDurDefault:SetText("Default")
feedDurDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.pet.feedBuffDurationSeconds = DEFAULT_SETTINGS.pet.feedBuffDurationSeconds
    feedDurBox:SetText(DEFAULT_SETTINGS.pet.feedBuffDurationSeconds)
    if feedActive then
        ShowFeedCountdown(DEFAULT_SETTINGS.pet.feedBuffDurationSeconds)
    end
end)

-- Feed buff name
local feedNameLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
feedNameLabel:SetPoint("TOPLEFT", feedDurLabel, "BOTTOMLEFT", 0, -12)
feedNameLabel:SetText("Feed buff name:")
local feedNameBox = CreateFrame("EditBox", "KWA_ConfigFeedName", configFrame, "InputBoxTemplate")
feedNameBox:SetWidth(120)
feedNameBox:SetHeight(20)
feedNameBox:SetPoint("LEFT", feedNameLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
feedNameBox:SetAutoFocus(false)
feedNameBox:SetScript("OnEnterPressed", function()
    local txt = this:GetText()
    if txt and txt ~= "" then
        KWA_HunterAssist_Config.pet.feedBuffName = txt
    end
    this:ClearFocus()
end)
local feedNameDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
feedNameDefault:SetWidth(60)
feedNameDefault:SetHeight(20)
feedNameDefault:SetPoint("LEFT", feedNameLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
feedNameDefault:SetText("Default")
feedNameDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.pet.feedBuffName = DEFAULT_SETTINGS.pet.feedBuffName
    feedNameBox:SetText(DEFAULT_SETTINGS.pet.feedBuffName)
end)

-- ======= Equipment group =======
local equipGroup = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
equipGroup:SetPoint("TOPLEFT", feedNameLabel, "BOTTOMLEFT", 0, -20)
equipGroup:SetText("Equipment")

-- Ammo threshold
local ammoLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ammoLabel:SetPoint("TOPLEFT", equipGroup, "BOTTOMLEFT", 0, -10)
ammoLabel:SetText("Ammo threshold:")
local ammoBox = CreateFrame("EditBox", "KWA_ConfigAmmo", configFrame, "InputBoxTemplate")
ammoBox:SetWidth(40)
ammoBox:SetHeight(20)
ammoBox:SetPoint("LEFT", ammoLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
ammoBox:SetAutoFocus(false)
ammoBox:SetScript("OnEnterPressed", function()
    local v = tonumber(this:GetText())
    if v then
        KWA_HunterAssist_Config.equipment.lowAmmoThreshold = v
    end
    this:ClearFocus()
end)
local ammoDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
ammoDefault:SetWidth(60)
ammoDefault:SetHeight(20)
ammoDefault:SetPoint("LEFT", ammoLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
ammoDefault:SetText("Default")
ammoDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.equipment.lowAmmoThreshold = DEFAULT_SETTINGS.equipment.lowAmmoThreshold
    ammoBox:SetText(DEFAULT_SETTINGS.equipment.lowAmmoThreshold)
end)

-- Low ammo sound
local ammoSoundLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ammoSoundLabel:SetPoint("TOPLEFT", ammoLabel, "BOTTOMLEFT", 0, -10)
ammoSoundLabel:SetText("Sound on low ammo")
local ammoSoundCheck = CreateFrame("CheckButton", "KWA_ConfigAmmoSound", configFrame, "UICheckButtonTemplate")
ammoSoundCheck:SetPoint("LEFT", ammoSoundLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
local ammoSoundDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
ammoSoundDefault:SetWidth(60)
ammoSoundDefault:SetHeight(20)
ammoSoundDefault:SetPoint("LEFT", ammoSoundLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
ammoSoundDefault:SetText("Default")
ammoSoundDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.equipment.lowAmmoSoundEnabled = DEFAULT_SETTINGS.equipment.lowAmmoSoundEnabled
    ammoSoundCheck:SetChecked(DEFAULT_SETTINGS.equipment.lowAmmoSoundEnabled)
end)
ammoSoundCheck:SetScript("OnClick", function()
    KWA_HunterAssist_Config.equipment.lowAmmoSoundEnabled = this:GetChecked()
end)

-- Alert at merchant
local merchantLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
merchantLabel:SetPoint("TOPLEFT", ammoSoundLabel, "BOTTOMLEFT", 0, -10)
merchantLabel:SetText("Alert at merchant")
local merchantCheck = CreateFrame("CheckButton", "KWA_ConfigMerchant", configFrame, "UICheckButtonTemplate")
merchantCheck:SetPoint("LEFT", merchantLabel, "LEFT", COL_INPUT_X - COL_LABEL_X, 0)
local merchantDefault = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
merchantDefault:SetWidth(60)
merchantDefault:SetHeight(20)
merchantDefault:SetPoint("LEFT", merchantLabel, "LEFT", COL_DEFAULT_X - COL_LABEL_X, 0)
merchantDefault:SetText("Default")
merchantDefault:SetScript("OnClick", function()
    KWA_HunterAssist_Config.equipment.merchantAlertEnabled = DEFAULT_SETTINGS.equipment.merchantAlertEnabled
    merchantCheck:SetChecked(DEFAULT_SETTINGS.equipment.merchantAlertEnabled)
end)
merchantCheck:SetScript("OnClick", function()
    KWA_HunterAssist_Config.equipment.merchantAlertEnabled = this:GetChecked()
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
    enabledCheck:SetChecked(KWA_HunterAssist_Config.general.addonEnabled)
    soundCheck:SetChecked(KWA_HunterAssist_Config.pet.alertSoundEnabled)
    intervalBox:SetText(KWA_HunterAssist_Config.pet.unhappyAlertIntervalSeconds)
    feedDurBox:SetText(KWA_HunterAssist_Config.pet.feedBuffDurationSeconds)
    feedNameBox:SetText(KWA_HunterAssist_Config.pet.feedBuffName or "")
    ammoBox:SetText(KWA_HunterAssist_Config.equipment.lowAmmoThreshold)
    ammoSoundCheck:SetChecked(KWA_HunterAssist_Config.equipment.lowAmmoSoundEnabled)
    merchantCheck:SetChecked(KWA_HunterAssist_Config.equipment.merchantAlertEnabled)
    debugCheck:SetChecked(KWA_HunterAssist_Config.general.debugLoggingEnabled)
end)

-- ======= Helpers =======
local function IsHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

local function Debug(msg)
    if KWA_HunterAssist_Config.general.debugLoggingEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa][HA][DBG]|r " .. tostring(msg))
    end
end

local function SendAlert(msg, playSound)
    -- Only alert OUT OF COMBAT
    if inCombat then
        Debug("Suppressed alert (in combat): " .. msg)
        return
    end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 1.0, 0.1, 0.1, 1.0)
    end
    if KWA_HunterAssist_Config.pet.alertSoundEnabled and (playSound == nil or playSound) and PlaySoundFile then
        PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
    end
end

local function GetPetName()
    return UnitName("pet") or "Your pet"
end

local function AlertUnhappy()
    SendAlert(GetPetName() .. " is UNHAPPY!")
    alertTimer = 0
end

local function Clamp(v, min, max, default)
    local n = tonumber(v) or default
    if n < min then n = min end
    if n > max then n = max end
    return n
end

local function CurrentInterval()
    return Clamp(KWA_HunterAssist_Config.pet.unhappyAlertIntervalSeconds, 1, 60, DEFAULT_SETTINGS.pet.unhappyAlertIntervalSeconds)
end

local function CurrentFeedDur()
    return Clamp(KWA_HunterAssist_Config.pet.feedBuffDurationSeconds, 3, 120, DEFAULT_SETTINGS.pet.feedBuffDurationSeconds)
end

local function CurrentAmmoThreshold()
    return Clamp(KWA_HunterAssist_Config.equipment.lowAmmoThreshold, 0, 10000, DEFAULT_SETTINGS.equipment.lowAmmoThreshold)
end

local function PetHasFeedBuff()
    if GameTooltip and GameTooltip.SetUnitBuff and GameTooltipTextLeft1 then
        for i = 1, 16 do
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            local ok = GameTooltip:SetUnitBuff("pet", i)
            if not ok then
                GameTooltip:Hide()
                break
            end
            local name = GameTooltipTextLeft1:GetText()
            GameTooltip:Hide()
            if
            name and KWA_HunterAssist_Config.pet.feedBuffName and
                    string.lower(name) == string.lower(KWA_HunterAssist_Config.pet.feedBuffName)
            then
                return true
            end
        end
    end
    return feedPendingCast
end

local function MarkFeedPending(src)
    feedPendingCast = true
    Debug("Detected Feed Pet via " .. src)
end

-- ======= Core checks =======
local function CheckPet(force)
    if not KWA_HunterAssist_Config.general.addonEnabled then
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

    if UnitIsDead("pet") or PetHasFeedBuff() then
        unhappyActive = false
        alertTimer = 0
        pendingUnhappyAlert = false
        if UnitIsDead("pet") then
            lastHappiness = nil
            HideFeedCountdown()
        end
        return
    end

    local happiness = GetPetHappiness and GetPetHappiness()

    if happiness == 1 then
        -- Pet is unhappy
        if force or lastHappiness ~= 1 then
            if inCombat then
                -- Do NOT alert now; queue one for when we leave combat
                pendingUnhappyAlert = true
                Debug("Unhappy transition DURING combat -> queued for after combat.")
            else
                AlertUnhappy()
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
f:RegisterEvent("MERCHANT_SHOW")

local eventHandlers = {}

eventHandlers.PLAYER_LOGIN = function()
    KWA_HunterAssist_Config = KWA_HunterAssist_Config or {}
    for group, defaults in pairs(DEFAULT_SETTINGS) do
        KWA_HunterAssist_Config[group] = KWA_HunterAssist_Config[group] or {}
        for key, val in pairs(defaults) do
            if KWA_HunterAssist_Config[group][key] == nil then
                KWA_HunterAssist_Config[group][key] = val
            end
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
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r loaded. Use /kwa config to open the options.")
    Debug("PLAYER_LOGIN; inCombat=" .. tostring(inCombat))
end

local function ResetStates(evt)
    Debug(evt .. ": reset states")
    CheckPet(true)
    HideFeedCountdown()
    feedPendingCast = false
end

eventHandlers.PLAYER_ENTERING_WORLD = ResetStates
eventHandlers.UNIT_PET = ResetStates

eventHandlers.UNIT_HAPPINESS = function(_, unit)
    if unit == "pet" then
        Debug("UNIT_HAPPINESS for pet")
        CheckPet(false)
    end
end

eventHandlers.SPELLCAST_START = function(_, spell)
    Debug("SPELLCAST_START: " .. tostring(spell))
    if spell and string.lower(spell) == "feed pet" then
        MarkFeedPending("SPELLCAST_START")
    end
end

eventHandlers.UNIT_AURA = function(_, unit)
    if unit == "pet" then
        Debug("UNIT_AURA for pet. feedPendingCast=" .. tostring(feedPendingCast))
        if feedPendingCast and PetHasFeedBuff() then
            Debug("Feed buff detected -> start countdown")
            ShowFeedCountdown(CurrentFeedDur())
            feedPendingCast = false
            CheckPet(true)
        elseif feedActive and not PetHasFeedBuff() then
            Debug("Feed buff ended -> hide countdown")
            HideFeedCountdown()
            CheckPet(true)
        end
    end
end

eventHandlers.PLAYER_REGEN_DISABLED = function()
    -- Feeding already cancels on combat; leave unhappy timer paused automatically.
    inCombat = true
    Debug("PLAYER_REGEN_DISABLED -> inCombat=true")
end

eventHandlers.PLAYER_REGEN_ENABLED = function()
    inCombat = false
    Debug("PLAYER_REGEN_ENABLED -> inCombat=false")
    -- If we became unhappy during combat, fire the queued alert now.
    if pendingUnhappyAlert and KWA_HunterAssist_Config.general.addonEnabled and UnitExists("pet") then
        local happiness = GetPetHappiness and GetPetHappiness()
        if happiness == 1 then
            AlertUnhappy()
        end
    end
    pendingUnhappyAlert = false
    local threshold = CurrentAmmoThreshold()
    if threshold > 0 and IsHunter() and GetInventorySlotInfo and GetInventoryItemCount then
        local slot = GetInventorySlotInfo("AmmoSlot")
        if slot then
            local count = GetInventoryItemCount("player", slot) or 0
            Debug("Ammo count=" .. tostring(count))
            if count < threshold then
                SendAlert("Low ammo (" .. count .. ")!", KWA_HunterAssist_Config.equipment.lowAmmoSoundEnabled)
            else
                Debug("Ammo count above threshold")
            end
        end
    end
end

eventHandlers.MERCHANT_SHOW = function()
    Debug("MERCHANT_SHOW fired")
    if not KWA_HunterAssist_Config.general.addonEnabled or not KWA_HunterAssist_Config.equipment.merchantAlertEnabled then
        Debug("MERCHANT_SHOW: alerts disabled")
        return
    end
    local threshold = CurrentAmmoThreshold()
    if not (threshold > 0 and IsHunter() and GetMerchantNumItems and GetMerchantItemInfo) then
        Debug("MERCHANT_SHOW: preconditions not met (threshold=" .. tostring(threshold) .. ")")
        return
    end
    local sellsAmmo = false
    local numItems = GetMerchantNumItems()
    Debug("MERCHANT_SHOW: numItems=" .. tostring(numItems))
    for i = 1, numItems do
        local name = GetMerchantItemInfo(i)
        local link = GetMerchantItemLink and GetMerchantItemLink(i)
        local equipLoc
        if GetItemInfo then
            local item = link or name
            if item then
                local _, _, _, _, _, _, _, _, loc = GetItemInfo(item)
                equipLoc = loc
            end
        end
        Debug("MERCHANT_SHOW: item " .. i .. " name=" .. tostring(name) .. " equipLoc=" .. tostring(equipLoc))
        local nameLower = string.lower(name or "")
        if equipLoc == "INVTYPE_AMMO"
            or string.find(nameLower, "arrow", 1, true)
            or string.find(nameLower, "bullet", 1, true)
            or string.find(nameLower, "shot", 1, true)
            or string.find(nameLower, "shell", 1, true) then
            sellsAmmo = true
            break
        end
    end
    Debug("MERCHANT_SHOW: sellsAmmo=" .. tostring(sellsAmmo))
    if sellsAmmo and GetInventorySlotInfo and GetInventoryItemCount then
        local slot = GetInventorySlotInfo("AmmoSlot")
        if slot then
            local count = GetInventoryItemCount("player", slot) or 0
            Debug("MERCHANT_SHOW: ammo count=" .. tostring(count) .. ", threshold=" .. threshold)
            if count < threshold then
                SendAlert("Low ammo (" .. count .. ")!", KWA_HunterAssist_Config.equipment.lowAmmoSoundEnabled)
            else
                Debug("MERCHANT_SHOW: ammo not below threshold")
            end
        end
    end
end

f:SetScript("OnEvent", function()
    local handler = eventHandlers[event]
    if handler then
        handler(event, arg1)
    end
end)

-- ======= OnUpdate =======
f:SetScript(
        "OnUpdate",
        function()
            local elapsed = arg1 or 0

            -- Unhappy repeat (only OUT OF COMBAT)
            if KWA_HunterAssist_Config.general.addonEnabled and unhappyActive and not inCombat then
                alertTimer = alertTimer + elapsed
                if alertTimer >= CurrentInterval() then
                    AlertUnhappy()
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
            MarkFeedPending("CastSpell")
        end
    end
    return _Orig_CastSpell(spellId, bookTab)
end

local _Orig_CastSpellByName = CastSpellByName
CastSpellByName = function(spell, onSelf)
    if spell and string.find(string.lower(spell), "^feed pet") then
        MarkFeedPending("CastSpellByName")
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
            MarkFeedPending("UseAction slot " .. tostring(slot))
        end
    end
    return _Orig_UseAction(slot, checkCursor, onSelf)
end

-- ======= Slash: /kwa =======
SLASH_KWA1 = "/kwa"
SlashCmdList["KWA"] = function(msg)
    msg = tostring(msg or "")
    msg = string.lower((string.gsub(msg, "^%s*(.-)%s*$", "%1")))

    if msg == "config" then
        if configFrame:IsShown() then
            configFrame:Hide()
        else
            configFrame:Show()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r Welcome! Use /kwa config to open the configuration window.")
    end
end
