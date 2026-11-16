PauseEnvironment = {}
local held, weatherHeld, previousSync = false, false, true
local lighting = 'auto'
local savedClock
local lifecycle,syncEnabled=0,true
local function rememberClock(hour,minute,timeScale)
    savedClock={hour=hour,minute=minute,timeScale=timeScale,timer=GetGameTimer()}
end
local function fallbackClock()
    if not savedClock then return end
    local scale=savedClock.timeScale
    local total=savedClock.hour*60+savedClock.minute+math.max(0,GetGameTimer()-savedClock.timer)/scale
    return math.floor(total/60)%24,math.floor(total)%60,scale
end
local function worldClock()
    local weather = pr_lib.weather
    if weather and weather.GetSnapshot then
        local ok, available, snapshot = pcall(weather.GetSnapshot)
        if ok and available and type(snapshot)=='table' and type(snapshot.currentTime)=='table' then
            local hour,minute=tonumber(snapshot.currentTime.hour),tonumber(snapshot.currentTime.minute)
            if hour and minute and hour>=0 and hour<24 and minute>=0 and minute<60 then
                return hour,minute,snapshot.freezeTime and 99999999 or tonumber(snapshot.timeScale) or 2000
            end
        end
    end
end
local function restoreWorld()
    local weather=pr_lib.weather
    local hour,minute,scale=worldClock()
    if not hour then hour,minute,scale=fallbackClock() end
    if hour then
        NetworkOverrideClockMillisecondsPerGameMinute(math.max(1,math.floor(scale)))
        NetworkOverrideClockTime(math.floor(hour),math.floor(minute),0)
    end
    if weather and weather.GetRegionalWeather then
        local ok,available,region=pcall(weather.GetRegionalWeather)
        if ok and available and type(region)=='table' and type(region.weather)=='string' then
            SetWeatherTypeNowPersist(region.weather)
        end
    end
end
function PauseEnvironment.resync(ticket)
    if ticket~=lifecycle or weatherHeld or syncEnabled==false then return false end
    restoreWorld()
    return true
end
function PauseEnvironment.hud(hide)
    if hide == held then return end
    if GetResourceState('forge-hud') == 'started' then
        local ok = pcall(function()
            if hide then exports['forge-hud']:SuspendHud() else exports['forge-hud']:ResumeHud() end
        end)
        if ok then held = hide end
    elseif not hide then held = false end
end
function PauseEnvironment.start()
    if weatherHeld then return end
    lifecycle=lifecycle+1
    lighting = 'auto'
    local weather = pr_lib.weather
    if not weather or not weather.ToggleSync or GetResourceState('Renewed-Weathersync') ~= 'started' then return end
    -- Renewed's private cache cannot be read from another resource. Observe its
    -- existing public change event instead of assuming that private key is shared.
    previousSync = syncEnabled
    -- Another scene already owns local weather; leave its time and effects alone.
    if not previousSync then return end
    local hour,minute,scale=worldClock()
    rememberClock(hour or GetClockHours(),minute or GetClockMinutes(),scale or (GetMillisecondsPerGameMinute and GetMillisecondsPerGameMinute()) or 2000)
    local ok, available, accepted = pcall(weather.ToggleSync, false)
    weatherHeld = ok and available == true and accepted == true
    PauseEnvironment.tick()
end
function PauseEnvironment.tick()
    if not weatherHeld then return end
    SetWeatherTypeNowPersist('EXTRASUNNY')
    SetOverrideWeather('EXTRASUNNY')
    SetRainLevel(0.0)
    SetCloudsAlpha(0.0)
    if lighting=='auto' then
        local hour,minute,timeScale=worldClock()
        if hour then rememberClock(hour,minute,timeScale) else hour,minute,timeScale=fallbackClock() end
        if hour then
            NetworkOverrideClockMillisecondsPerGameMinute(timeScale)
            NetworkOverrideClockTime(hour,minute,0)
        end
    else
        NetworkOverrideClockMillisecondsPerGameMinute(99999999)
        NetworkOverrideClockTime(lighting=='day' and 13 or 0,0,0)
    end
end
function PauseEnvironment.setLighting(value)
    if value~='auto' and value~='day' and value~='night' then return false end
    if not weatherHeld then return false end
    lighting=value
    PauseEnvironment.tick()
    return true
end
function PauseEnvironment.stop()
    if not weatherHeld then return end
    lifecycle=lifecycle+1
    local ticket=lifecycle
    weatherHeld = false
    lighting = 'auto'
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetRainLevel(-1.0)
    SetCloudsAlpha(1.0)
    if GetResourceState('Renewed-Weathersync') == 'started' then
        pcall(pr_lib.weather.ToggleSync, previousSync)
    end
    -- ToggleSync(true) is intentionally idempotent in Renewed. Reapply the live
    -- snapshot even if a bucket transition has already enabled synchronization.
    restoreWorld()
    savedClock=nil
    return ticket
end
if pr_lib.weather and pr_lib.weather.OnChange then
    pr_lib.weather.OnChange(function(key,value) if key=='syncWeather' then syncEnabled=value==true end end)
end
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'forge-hud' and held then held = false PauseEnvironment.hud(true) end
end)
