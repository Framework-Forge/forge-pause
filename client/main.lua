local opened, nativeMenu = false, false
local preferences = { scale = 100, filter = 'none', strength = 50 }
local filterOwned = false
local kvp = 'forge-pause:preferences:v1'
local settingsReady, settingsRevision = false, -1
local activePage = 'home'
local canAdmin = false
local suppressInputUntil = 0
local headshot
local nextSessionCheck = 0
local function releaseHeadshot()
    if headshot then UnregisterPedheadshot(headshot) headshot=nil end
end
local function uiPreferences()
    return { scale = preferences.scale, filter = preferences.filter, strength = preferences.strength, options = PauseOptions.values() }
end

local function uiConfig()
    return { name = Config.ServerName, subtitle = Config.Subtitle, theme = Config.Theme,
        map = Config.Map, links = Config.Links, rules = Config.Rules, filters = Config.Filters, admin = canAdmin,settingsRevision=settingsRevision,
        blipModels = PauseBlipModels and PauseBlipModels.models or {},
        blipColors = pr_lib.fivem and pr_lib.fivem.blips and pr_lib.fivem.blips.listColors() or {} }
end

local function validFilter(value)
    for _, filter in ipairs(Config.Filters) do
        if filter.value == value then return true end
    end
    return false
end

local function readPreferences(data)
    if type(data) ~= 'table' then return end
    preferences.scale = math.max(80, math.min(110, tonumber(data.scale) or preferences.scale))
    preferences.strength = math.max(0, math.min(100, tonumber(data.strength) or preferences.strength))
    if validFilter(data.filter) then preferences.filter = data.filter end
    PauseOptions.read(data.options)
    preferences.options = PauseOptions.persisted()
end

local function applyFilter()
    if preferences.filter == 'none' then
        if filterOwned then ClearTimecycleModifier() end
        filterOwned = false
    else
        SetTimecycleModifier(preferences.filter)
        SetTimecycleModifierStrength(preferences.strength / 100)
        filterOwned = true
    end
end
AddEventHandler('forge-pause:restoreFilter', applyFilter)

local function close()
    TriggerEvent('forge-pause:admin:cleanup')
    if opened then suppressInputUntil = GetGameTimer()+400 end
    if opened then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    opened = false
    releaseHeadshot()
    PauseEnvironment.hud(false)
    ForgePortrait.stop(true)
    ForgeMap.stop()
    PauseOptions.resume()
    SendNUIMessage({ action = 'close' })
end

local function open(returnPage)
    if GetGameTimer()<suppressInputUntil then return end
    if not settingsReady then return end
    if opened or nativeMenu or IsPauseMenuActive() or IsNuiFocused() or IsPlayerSwitchInProgress() or IsEntityDead(PlayerPedId()) then return end
    if not pr_lib.framework.IsPlayerLoaded() then return end
    nextSessionCheck = GetGameTimer() + 1000
    local player = pr_lib.framework.GetPlayer() or {}
    local job = pr_lib.framework.GetJobInfo() or {}
    opened = true
    PauseEnvironment.hud(true)
    activePage = type(returnPage)=='string' and returnPage or 'home'
    PauseOptions.pause()
    ForgePortrait.start()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', page=activePage, config = uiConfig(), preferences = uiPreferences(), game = PauseOptions.info(), player = {
        name = player.fullName or GetPlayerName(PlayerId()), id = GetPlayerServerId(PlayerId()),
        job = job.jobLabel or 'Cidadão', cash = pr_lib.framework.GetMoney('cash') or 0,
        bank = pr_lib.framework.GetMoney('bank') or 0
    } })
end

AddEventHandler('forge-pause:admin:prepare', close)
-- Session events close immediately. The bounded check also covers frameworks
-- that do not publish the common PR logout event, without a query every frame.
AddEventHandler('pr_bridge:client:OnPlayerUnloaded', close)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', close)
RegisterNetEvent('esx:onPlayerLogout', close)
PauseMenu={isOpen=function() return opened end,page=function() return activePage end,open=open,close=close,
    setAdmin=function(value) canAdmin=value==true end}
AddEventHandler('forge-pause:points:applied',function()
    if opened and activePage=='map' then SendNUIMessage({action='mapWorld',world=ForgeMap.data()}) end
end)
local function receiveSettings(snapshot)
    if type(snapshot) ~= 'table' or type(snapshot.revision) ~= 'number' or snapshot.revision < settingsRevision then return end
    local valid = PauseSettings.validate(snapshot.settings)
    if not valid then return end
    TriggerEvent('forge-pause:admin:settingsApplied',valid)
    local portraitPreview=opened and activePage=='admin' and ForgePortrait.isActive()
    if opened then ForgeMap.stop() end
    PauseSettings.apply(valid)
    if snapshot.admin ~= nil then canAdmin = snapshot.admin == true end
    settingsReady, settingsRevision = true, snapshot.revision
    if opened then
        if activePage~='map' and (activePage~='admin' or portraitPreview) then ForgePortrait.start(activePage=='admin') end
        SendNUIMessage({ action = 'config', config = uiConfig() })
    end
end
PauseMenu.applySettings=receiveSettings
RegisterNetEvent('forge-pause:settings:updated', receiveSettings)
CreateThread(function()
    while not settingsReady do
        local ok, snapshot = pcall(pr_lib.callback.await, 'forge-pause:settings', false)
        if ok then receiveSettings(snapshot) end
        if not settingsReady then Wait(5000) end
    end
end)

RegisterCommand(Config.Command, function() if opened then close() else open() end end, false)

RegisterNUICallback('close', function(_, cb) close() cb({ ok = true }) end)
RegisterNUICallback('nativeSettings',function(data,cb)
    if not opened or nativeMenu then cb({ok=false}) return end
    local categories={controller=true,keys=true,audio=true,camera=true,display=true,graphics=true}
    local group=type(data.page)=='string' and data.page:match('^settings%.(%w+)$')
    if not categories[group] then cb({ok=false}) return end
    local returnPage=data.page
    close();nativeMenu=true;cb({ok=true})
    CreateThread(function()
        Wait(50)
        ActivateFrontendMenu(joaat('FE_MENU_VERSION_SP_PAUSE'),false,6)
        local deadline=GetGameTimer()+3000
        while not IsPauseMenuActive() and GetGameTimer()<deadline do Wait(50) end
        while IsPauseMenuActive() do Wait(100) end
        nativeMenu=false
        Wait(450)
        open(returnPage)
    end)
end)
RegisterNUICallback('admin', function(_, cb)
    if not opened or not canAdmin then cb({ ok = false }) return end
    cb({ ok = true })
    SendNUIMessage({action='adminOpen'})
end)
RegisterNUICallback('preferences', function(data, cb)
    readPreferences(data)
    SetResourceKvp(kvp, json.encode(preferences))
    applyFilter()
    PauseOptions.apply()
    cb({ ok = true, preferences = uiPreferences() })
end)
RegisterNUICallback('gameInfo', function(_, cb)
    cb({ ok = opened, game = opened and PauseOptions.info() or nil })
end)
RegisterNUICallback('mapMove', function(data, cb)
    if opened then ForgeMap.move(data) end
    cb({ ok = true })
end)
RegisterNUICallback('mapLighting',function(data,cb)
    if not opened or activePage~='map' or Config.Map.mode~='3d' or type(data)~='table' then cb({ok=false}) return end
    local ok=PauseEnvironment.setLighting(data.mode)
    cb({ok=ok,mode=ok and data.mode or nil,message=not ok and 'A iluminação está sob controle de outro recurso ou a sincronização do clima está indisponível.' or nil})
end)
RegisterNUICallback('page', function(data, cb)
    if activePage=='map' and data.page~='map' then suppressInputUntil=GetGameTimer()+400 end
    activePage = data.page
    local world = opened and data.page == 'map' and ForgeMap.data() or nil
    if opened and data.page == 'map' then
        ForgePortrait.stop(true)
        if Config.Map.mode == '3d' then ForgeMap.start() else ForgeMap.stop() end
    elseif opened and data.page=='admin' then
        ForgeMap.stop();ForgePortrait.stop(true)
    else
        ForgeMap.stop()
        if opened then ForgePortrait.start() end
    end
    cb({ ok = true, world = world })
end)
RegisterNUICallback('waypoint', function(data, cb)
    if opened and activePage=='map' and data.clear==true then SetWaypointOff() cb({ok=true}) return end
    local x, y = tonumber(data.x), tonumber(data.y)
    if not opened or activePage ~= 'map' or not x or not y or x ~= x or y ~= y or math.abs(x) > 10000 or math.abs(y) > 15000 then cb({ ok = false }) return end
    SetNewWaypoint(x, y)
    cb({ ok = true })
end)
RegisterNUICallback('headshot', function(_,cb)
    if not opened then cb({ok=false}) return end
    releaseHeadshot()
    local handle=RegisterPedheadshotTransparent(PlayerPedId());headshot=handle
    local deadline=GetGameTimer()+2000
    while opened and headshot==handle and GetGameTimer()<deadline and (not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle)) do Wait(20) end
    if not opened or headshot~=handle or not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) then
        if headshot==handle then releaseHeadshot() end
        cb({ok=false}) return
    end
    cb({ok=true,url='https://nui-img/'..GetPedheadshotTxdString(handle)..'/'..GetPedheadshotTxdString(handle)})
end)
RegisterNUICallback('mapFly', function(data, cb)
    local x,y=tonumber(data.x),tonumber(data.y)
    if not opened or activePage~='map' or not x or not y or x~=x or y~=y or math.abs(x)>10000 or math.abs(y)>15000 then cb({ok=false}) return end
    ForgeMap.fly(x,y)
    cb({ok=true})
end)
RegisterNUICallback('mapRoute', function(data, cb)
    if not opened or activePage~='map' or type(data.points)~='table' or #data.points>301 then cb({ok=false}) return end
    local points={}
    for _,p in ipairs(data.points) do
        if type(p)~='table' or type(p.x)~='number' or type(p.y)~='number' or type(p.z)~='number' or p.x~=p.x or p.y~=p.y or p.z~=p.z or math.abs(p.x)>10000 or math.abs(p.y)>15000 or math.abs(p.z)>2000 then cb({ok=false}) return end
        points[#points+1]={x=p.x,y=p.y,z=p.z}
    end
    ForgeMap.route=points
    cb({ok=true})
end)

CreateThread(function()
    local raw = GetResourceKvpString(kvp)
    if raw then
        local ok, data = pcall(json.decode, raw)
        if ok then readPreferences(data) end
    end
    applyFilter()
    PauseOptions.apply()
    while true do
        Wait(0)
        if not nativeMenu then
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            if not opened and (IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 199)) then open() end
        end
        if opened or GetGameTimer()<suppressInputUntil then
            DisableAllControlActions(0)
            DisablePlayerFiring(PlayerId(),true)
        end
        if opened then
            if IsEntityDead(PlayerPedId()) then close()
            elseif GetGameTimer() >= nextSessionCheck then
                nextSessionCheck = GetGameTimer() + 1000
                if not pr_lib.framework.IsPlayerLoaded() then close() end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    close()
    if filterOwned then ClearTimecycleModifier() end
end)
