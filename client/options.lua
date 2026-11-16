PauseOptions = {}
local defaults = { pedCam = 1, vehCam = 1, radioOff = false, radio = 60, call = 60, click = 10, radar = true, hud = true, bigmap = false, hideHud = false, reticle = 'gta', brightness = 0, shadows = 'high', clean = false, lod = 1.0, lights = 'normal', budget = 'normal' }
local current = {}
local touched = {}
local pedView, vehicleView
local exposureReady, exposureOwned = nil, false

function PauseOptions.read(data)
    if type(data) ~= 'table' then return end
    for key, default in pairs(defaults) do
        local value = data[key]
        local valid = false
        if type(default) == 'boolean' then valid = type(value) == 'boolean'
        elseif key == 'pedCam' or key == 'vehCam' then valid = value == 0 or value == 1 or value == 2 or value == 4
        elseif key == 'radio' or key == 'call' or key == 'click' then valid = type(value) == 'number' and value >= 0 and value <= 100
        elseif key == 'reticle' then valid = value == 'gta' or value == 'dot' or value == 'cross' or value == 'none'
        elseif key == 'brightness' then valid = type(value) == 'number' and value >= -10 and value <= 10
        elseif key == 'shadows' then valid = value == 'high' or value == 'medium' or value == 'low' or value == 'off'
        elseif key == 'lod' then valid = value == 1.0 or value == 1.25 or value == 1.5
        elseif key == 'lights' or key == 'budget' then valid = value == 'normal' or value == 'reduced' end
        if valid then current[key], touched[key] = value, true end
    end
end
function PauseOptions.values()
    local result = {}
    for key, value in pairs(defaults) do result[key] = value end
    for key, value in pairs(current) do result[key] = value end
    if not touched.pedCam then result.pedCam = GetFollowPedCamViewMode() end
    if not touched.vehCam then result.vehCam = GetFollowVehicleCamViewMode() end
    return result
end
function PauseOptions.persisted() return current end
function PauseOptions.apply()
    if touched.brightness then
        if current.brightness == 0 then
            if exposureOwned then ClearExtraTimecycleModifier() exposureOwned = false end
        else
            if exposureReady == nil then
                exposureReady = false
                for i = 0, GetTimecycleVarCount() - 1 do
                    if GetTimecycleVarNameByIndex(i) == 'postfx_exposure' then exposureReady = true break end
                end
                if exposureReady then CreateTimecycleModifier('forge_pause_exposure') end
            end
            if exposureReady then
                local value = current.brightness * 0.04
                SetTimecycleModifierVar('forge_pause_exposure', 'postfx_exposure', value, value)
                SetExtraTimecycleModifier('forge_pause_exposure')
                SetExtraTimecycleModifierStrength(1.0)
                exposureOwned = true
            end
        end
    end
    if touched.pedCam then SetFollowPedCamViewMode(current.pedCam) end
    if touched.vehCam then SetFollowVehicleCamViewMode(current.vehCam) end
    if touched.radar then DisplayRadar(current.radar) end
    if touched.hud then DisplayHud(current.hud) end
    if touched.bigmap then SetBigmapActive(current.bigmap, false) end
    if touched.shadows then
        CascadeShadowsInitSession()
        if current.shadows == 'medium' then CascadeShadowsSetCascadeBoundsScale(0.8)
        elseif current.shadows == 'low' then CascadeShadowsSetCascadeBoundsScale(0.5) CascadeShadowsSetEntityTrackerScale(0.0)
        elseif current.shadows == 'off' then CascadeShadowsSetCascadeBoundsScale(0.0) CascadeShadowsSetEntityTrackerScale(0.0) end
        RopeDrawShadowEnabled(current.shadows == 'high' or current.shadows == 'medium')
    end
    if touched.lights then DisableVehicleDistantlights(current.lights == 'reduced') end
    if touched.budget then
        SetReducePedModelBudget(current.budget == 'reduced')
        SetReduceVehicleModelBudget(current.budget == 'reduced')
    end
    if GetResourceState('pma-voice') == 'started' then
        if touched.radio then exports['pma-voice']:setRadioVolume(current.radio) end
        if touched.call then exports['pma-voice']:setCallVolume(current.call) end
        if touched.click then
            pcall(function() exports['pma-voice']:setMicClickOnVolume(current.click) end)
            pcall(function() exports['pma-voice']:setMicClickOffVolume(math.floor(current.click / 3)) end)
        end
    end
end
function PauseOptions.pause()
    pedView, vehicleView = GetFollowPedCamViewMode(), GetFollowVehicleCamViewMode()
end
function PauseOptions.resume()
    if pedView then SetFollowPedCamViewMode(touched.pedCam and current.pedCam or pedView) end
    if vehicleView then SetFollowVehicleCamViewMode(touched.vehCam and current.vehCam or vehicleView) end
    pedView, vehicleView = nil, nil
end

local profiles = {
    audio = { {300, 'Volume dos efeitos'}, {306, 'Volume da música'}, {308, 'Diálogos'} },
    keys = { {754, 'Sensibilidade do mouse'}, {15, 'Inverter mouse'}, {758, 'Modo de mira'} },
    graphics = { {213, 'Brilho do perfil GTA'} },
    display = { {202, 'Área segura do GTA'}, {203, 'Legendas'} },
    camera = { {231, 'Campo de visão em primeira pessoa'} }
}
function PauseOptions.info()
    local info = { profiles = {}, keys = {}, voice = GetResourceState('pma-voice') == 'started' }
    for group, rows in pairs(profiles) do
        info.profiles[group] = {}
        for _, row in ipairs(rows) do info.profiles[group][#info.profiles[group] + 1] = { label = row[2], value = GetProfileSetting(row[1]) } end
    end
    if PauseProfile then info.profiles = PauseProfile.read() end
    for _, entry in ipairs({ {32, 'Avançar'}, {33, 'Recuar'}, {34, 'Esquerda'}, {35, 'Direita'}, {22, 'Pular'}, {21, 'Correr'}, {23, 'Entrar no veículo'}, {75, 'Sair do veículo'}, {0, 'Alternar câmera'} }) do
        local raw = GetControlInstructionalButton(0, entry[1], true)
        local label = raw:match('^t_(.+)') or ({ b_2000 = 'ESPAÇO', b_1000 = 'SHIFT' })[raw] or raw
        info.keys[#info.keys + 1] = { label = entry[2], value = label }
    end
    local x, y = GetActiveScreenResolution()
    info.resolution = ('%s × %s'):format(x, y)
    return info
end
CreateThread(function()
    while true do
        local aiming = current.reticle and current.reticle ~= 'gta'
        if current.hideHud or aiming then
            if current.hideHud then HideHudAndRadarThisFrame() end
            if aiming then
                HideHudComponentThisFrame(14)
                if current.reticle ~= 'none' and IsPlayerFreeAiming(PlayerId()) then
                    local ar = GetAspectRatio(false)
                    if current.reticle == 'dot' then DrawRect(0.5, 0.5, 0.0045 / ar, 0.0045, 255, 255, 255, 230)
                    else
                        DrawRect(0.5, 0.5, 0.015 / ar, 0.002, 255, 255, 255, 230)
                        DrawRect(0.5, 0.5, 0.002 / ar, 0.015, 255, 255, 255, 230)
                    end
                end
            end
            Wait(0)
        else Wait(300) end
    end
end)
CreateThread(function()
    while true do
        Wait(30000)
        if current.clean then
            local p = GetEntityCoords(PlayerPedId())
            RemoveDecalsInRange(p.x, p.y, p.z, 80.0)
        end
    end
end)
CreateThread(function()
    while true do
        if current.lod and current.lod > 1 then OverrideLodscaleThisFrame(current.lod) Wait(0) else Wait(500) end
    end
end)
CreateThread(function()
    while true do
        Wait(500)
        if touched.radioOff and current.radioOff and IsPedInAnyVehicle(PlayerPedId(), false) then
            SetVehRadioStation(GetVehiclePedIsIn(PlayerPedId(), false), 'OFF')
        end
    end
end)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'pma-voice' then PauseOptions.apply() end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if touched.lights then DisableVehicleDistantlights(false) end
    if touched.budget then SetReducePedModelBudget(false) SetReduceVehicleModelBudget(false) end
    if touched.shadows then CascadeShadowsInitSession() RopeDrawShadowEnabled(true) end
    if exposureOwned then ClearExtraTimecycleModifier() end
end)
