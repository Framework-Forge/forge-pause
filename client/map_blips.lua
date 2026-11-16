PauseMapAPI={}
local localResources,serverResources,boundHandles,revision={},{},{},-1
local function refresh()
    boundHandles={}
    for _,entries in pairs(localResources) do for _,entry in pairs(entries) do
        if entry.blip then boundHandles[entry.blip]=true end
    end end
    TriggerEvent('forge-pause:points:applied')
end
local function owner()
    local name=GetInvokingResource()
    return type(name)=='string' and name~=GetCurrentResourceName() and name or nil
end
local function save(id,data,update)
    local resource=owner()
    if not resource or not PauseMapBlips.id(id) then return false,'Recurso de origem ou ID inválido.' end
    local entries=localResources[resource] or {}
    local previous=entries[id]
    if update and not previous then return false,'Blip não registrado por este recurso.' end
    local point,reason=PauseMapBlips.normalize(data,update and previous.point or nil)
    if not point then return false,reason end
    local model=PauseBlips.model(point.model,PauseBlipModels.models)
    if not model or model.disabled then return false,'Modelo ausente ou desativado no catálogo do Pause.' end
    local blip=update and previous.blip or nil
    if data.blip~=nil then
        if data.blip==false then blip=nil
        elseif type(data.blip)~='number' or data.blip%1~=0 or not DoesBlipExist(data.blip) then return false,'Handle de blip inválido.'
        else blip=data.blip end
    end
    if not previous then
        local own,total=0,0
        for _ in pairs(entries) do own=own+1 end
        for _,rows in pairs(localResources) do for _ in pairs(rows) do total=total+1 end end
        if own>=PauseMapBlips.maxPerResource or total>=PauseMapBlips.maxPoints then return false,'Limite de blips externos atingido.' end
    end
    entries[id]={point=point,blip=blip};localResources[resource]=entries;refresh()
    return true
end
exports('RegisterMapBlip',function(id,data)return save(id,data,false)end)
exports('UpdateMapBlip',function(id,data)return save(id,data,true)end)
exports('RemoveMapBlip',function(id)
    local resource=owner()
    if not resource or not PauseMapBlips.id(id) or not localResources[resource] or not localResources[resource][id] then return false,'Blip não registrado por este recurso.' end
    localResources[resource][id]=nil;if not next(localResources[resource]) then localResources[resource]=nil end
    refresh();return true
end)
exports('ClearMapBlips',function()
    local resource=owner()
    if not resource then return false,'Recurso de origem inválido.' end
    localResources[resource]=nil;refresh();return true
end)
function PauseMapAPI.describe(handle)
    if boundHandles[handle] then return {exclude=true} end
end
function PauseMapAPI.mapPoints()
    local result={}
    local function append(scope,resource,id,point)
        local model=PauseBlips.model(point.model,PauseBlipModels.models)
        if not model or model.disabled or not point.enabled or point.display==5 then return end
        if point.alpha==0 and (point.zone.mode=='none' or point.zone.alpha==0) then return end
        result[#result+1]={x=point.pos.x,y=point.pos.y,z=point.pos.z,sprite=tonumber(point.model),
            name=point.name,group=point.group,color=point.color,alpha=point.alpha,scale=point.scale,
            rotation=point.rotation,flash=point.flash,mapGround=point.mapGround,mapOffset=point.mapOffset,
            zoneShape=PauseSettings.copy(point.zone),managedId='api:'..scope..':'..resource..':'..id,
            resource=resource,externalId=id}
    end
    for resource,entries in pairs(serverResources) do for id,point in pairs(entries) do append('server',resource,id,point) end end
    for resource,entries in pairs(localResources) do for id,entry in pairs(entries) do append('client',resource,id,entry.point) end end
    table.sort(result,function(a,b)return a.managedId<b.managedId end)
    return result
end
local function receive(snapshot)
    if type(snapshot)~='table' or type(snapshot.revision)~='number' or snapshot.revision<revision or type(snapshot.resources)~='table' then return false end
    local valid,total={},0
    for resource,entries in pairs(snapshot.resources) do
        if type(resource)~='string' or type(entries)~='table' then return false end
        valid[resource]={};local count=0
        for id,point in pairs(entries) do
            local normalized=PauseWorldBlips.validate(point);total=total+1;count=count+1
            if not PauseMapBlips.id(id) or not normalized or count>PauseMapBlips.maxPerResource or total>PauseMapBlips.maxPoints then return false end
            valid[resource][id]=normalized
        end
    end
    serverResources,revision=valid,snapshot.revision;refresh();return true
end
RegisterNetEvent('forge-pause:map-blips:updated',function(snapshot)if source==65535 then receive(snapshot)end end)
AddEventHandler('forge-pause:blips:applied',refresh)
AddEventHandler('onClientResourceStop',function(resource)
    if localResources[resource] then localResources[resource]=nil;refresh() end
end)
CreateThread(function()
    while revision<0 do
        local ok,snapshot=pcall(pr_lib.callback.await,'forge-pause:map-blips:get',false)
        if ok then receive(snapshot) end
        if revision<0 then Wait(5000) end
    end
end)
