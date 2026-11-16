local sessions, lastEnter = {}, {}
local function restore(src)
    local session = sessions[src]
    if not session then return end
    sessions[src] = nil
    -- Never undo a bucket change performed by another resource after our entry.
    if GetPlayerRoutingBucket(src) == session.bucket then SetPlayerRoutingBucket(src, session.original) end
    TriggerClientEvent('forge-pause:map:restored',src,session.token)
end
pr_lib.callback.register('forge-pause:map:enter', function(src, token, preserveScene)
    if type(token)~='string' or #token>64 or Config.Map.mode~='3d' then return {ok=false} end
    if sessions[src] then sessions[src].token=token sessions[src].expires=GetGameTimer()+15000 return { ok=true, isolated=true } end
    -- Skipping isolation grants no bucket access: the player stays exactly where they are.
    -- Re-instancing nearby damaged vehicles can replay replicated glass-break audio.
    if preserveScene==true then return {ok=true,isolated=false} end
    local now=GetGameTimer()
    if lastEnter[src] and now-lastEnter[src]<1000 then return {ok=false} end
    lastEnter[src]=now
    local ped=GetPlayerPed(src)
    if ped==0 or GetEntityHealth(ped)<=0 then return {ok=false} end
    -- Do not move occupied vehicles or strand their passengers in another instance.
    if GetVehiclePedIsIn(ped,false)~=0 then return {ok=true,isolated=false} end
    local bucket=700000+src
    local occupied={}
    for _,id in ipairs(GetPlayers()) do occupied[GetPlayerRoutingBucket(tonumber(id))]=true end
    while occupied[bucket] do bucket=bucket+65536 end
    local original=GetPlayerRoutingBucket(src)
    sessions[src]={original=original,bucket=bucket,expires=now+15000,token=token}
    SetRoutingBucketPopulationEnabled(bucket,false)
    SetRoutingBucketEntityLockdownMode(bucket,'strict')
    SetPlayerRoutingBucket(src,bucket)
    return {ok=true,isolated=true}
end)
RegisterNetEvent('forge-pause:map:leave', function(token) if sessions[source] and sessions[source].token==token then restore(source) end end)
RegisterNetEvent('forge-pause:map:heartbeat', function(token)
    local session=sessions[source]
    if session and session.token==token then session.expires=GetGameTimer()+15000 end
end)
CreateThread(function()
    while true do
        Wait(5000)
        for src,session in pairs(sessions) do if GetGameTimer()>session.expires then restore(src) end end
    end
end)
AddEventHandler('playerDropped',function() sessions[source]=nil lastEnter[source]=nil end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    local players={};for src in pairs(sessions) do players[#players+1]=src end
    for _,src in ipairs(players) do restore(src) end
end)
