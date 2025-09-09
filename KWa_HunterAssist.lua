-- [KWa]HunterAssist - WoW 1.12
-- Warn when Hunter pet is Unhappy. Repeats at a configurable interval.

local f = CreateFrame("Frame")

-- Saved config
KWA_HunterAssist_Config =
    KWA_HunterAssist_Config or
    {
        enabled = true,
        sound = true,
        interval = 5 -- seconds between repeat alerts while Unhappy
    }

local lastHappiness = nil
local unhappyActive = false
local alertTimer = 0

local function IsHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

local function SendAlert(msg)
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
        return
    end

    local happiness = GetPetHappiness and GetPetHappiness()
    local petName = UnitName("pet") or "Your pet"

    -- Immediate alert on transition into Unhappy, or on forced check
    if happiness == 1 then
        if force or lastHappiness ~= 1 then
            SendAlert(petName .. " is UNHAPPY!")
            alertTimer = 0
        end
        unhappyActive = true
    else
        unhappyActive = false
        alertTimer = 0
    end

    lastHappiness = happiness
end

-- Events
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_PET")
f:RegisterEvent("UNIT_HAPPINESS")

f:SetScript(
    "OnEvent",
    function()
        if event == "PLAYER_LOGIN" then
            -- Backfill defaults if upgrading
            KWA_HunterAssist_Config = KWA_HunterAssist_Config or {}
            if KWA_HunterAssist_Config.enabled == nil then
                KWA_HunterAssist_Config.enabled = true
            end
            if KWA_HunterAssist_Config.sound == nil then
                KWA_HunterAssist_Config.sound = true
            end
            if KWA_HunterAssist_Config.interval == nil then
                KWA_HunterAssist_Config.interval = 5
            end

            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r loaded. Use /kwa ha help for options.")
        elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
            CheckPet(true)
        elseif event == "UNIT_HAPPINESS" and arg1 == "pet" then
            CheckPet(false)
        end
    end
)

-- OnUpdate ticker (Lua 5.0 style: use global arg1 for elapsed)
f:SetScript(
    "OnUpdate",
    function()
        if not KWA_HunterAssist_Config.enabled then
            return
        end
        if not unhappyActive then
            return
        end
        local elapsed = arg1 or 0
        alertTimer = alertTimer + elapsed
        if alertTimer >= CurrentInterval() then
            local petName = UnitName("pet") or "Your pet"
            SendAlert(petName .. " is UNHAPPY!")
            alertTimer = 0
        end
    end
)

-- Slash command: /kwa ha {options}
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

    if cmd ~= "ha" then
        return
    end

    if rest == "help" or rest == "" then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00ff00[KWa]HunterAssist usage:|r /kwa ha on|off | test | sound on|off | interval <1-60>"
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
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r repeat interval set to " .. n .. "s.")
            alertTimer = 0 -- apply immediately
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[KWa]HunterAssist:|r usage: /kwa ha interval <1-60>")
        end
    elseif rest == "test" then
        local petName = UnitName("pet") or "Your pet"
        SendAlert("Test: " .. petName .. " is UNHAPPY!")
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00ff00[KWa]HunterAssist usage:|r /kwa ha on|off | test | sound on|off | interval <1-60>"
        )
    end
end
