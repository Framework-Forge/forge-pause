PauseWorldRuntime={points={},revision=-1}
local handles,byHandle,zoneHandles={},{},{}
local preview,previewZone
local function remove(handle)
    if handle and DoesBlipExist(handle) then RemoveBlip(handle) end
    if handle then byHandle[handle]=nil;zoneHandles[handle]=nil end
end
local function createZone(point)
    local zone=point.zone
    if not zone or zone.mode=='none' then return end
    local p=point.pos
    local h
    if zone.mode=='radius' then h=AddBlipForRadius(p.x+0.0,p.y+0.0,p.z+0.0,zone.radius+0.0)
    else h=AddBlipForArea(p.x+0.0,p.y+0.0,p.z+0.0,zone.width+0.0,zone.height+0.0) end
    if not h or h==0 then return end
    SetBlipColour(h,zone.color);SetBlipAlpha(h,zone.alpha)
    SetBlipRotation(h,zone.rotation);SetBlipDisplay(h,point.display)
    SetBlipAsShortRange(h,point.shortRange)
    zoneHandles[h]=true
    return h
end
local function create(point,name)
    local h=AddBlipForCoord(point.pos.x+0.0,point.pos.y+0.0,point.pos.z+0.0)
    if not h or h==0 then return end
    SetBlipSprite(h,point.nativeSprite)
    SetBlipDisplay(h,point.display)
    SetBlipScale(h,point.scale+0.0)
    SetBlipColour(h,point.color)
    SetBlipAlpha(h,point.alpha)
    SetBlipAsShortRange(h,point.shortRange)
    SetBlipFlashes(h,point.flash)
    SetBlipRotation(h,point.rotation)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name or point.name)
    EndTextCommandSetBlipName(h)
    return h
end
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function refresh()
    for id,entry in pairs(handles) do
        local point=PauseWorldRuntime.points[id]
        local model=point and PauseBlips.model(point.model,PauseBlipModels.models)
        if not point or not point.enabled or not model or model.disabled or not DoesBlipExist(entry.handle) or not same(point,entry.point) then
            remove(entry.handle);remove(entry.zone);handles[id]=nil
        end
    end
    for id,point in pairs(PauseWorldRuntime.points) do
        local model=PauseBlips.model(point.model,PauseBlipModels.models)
        if point.enabled and model and not model.disabled and not handles[id] then
            local handle=create(point)
            if handle then
                handles[id]={handle=handle,zone=createZone(point),point=PauseSettings.copy(point)}
                byHandle[handle]=id
            end
        end
    end
    TriggerEvent('forge-pause:points:applied')
end
function PauseWorldRuntime.receive(snapshot)
    if type(snapshot)~='table' or type(snapshot.points)~='table' or type(snapshot.revision)~='number'
        or snapshot.revision<PauseWorldRuntime.revision then return false end
    local validPoints,count={},0
    for id,point in pairs(snapshot.points) do
        local valid=PauseWorldBlips.validate(point)
        count=count+1
        if not PauseWorldBlips.id(id) or not valid or count>PauseWorldBlips.maxPoints then return false end
        validPoints[id]=valid
    end
    PauseWorldRuntime.points,PauseWorldRuntime.revision=validPoints,snapshot.revision
    refresh()
    return true
end
function PauseWorldRuntime.describe(handle)
    if (preview and handle==preview) or zoneHandles[handle] then return {exclude=true} end
    local id=byHandle[handle]
    local point=id and PauseWorldRuntime.points[id]
    if point then
        return {sprite=tonumber(point.model),name=point.name,group=point.group,managedId=id,exclude=point.display==5}
    end
end
function PauseWorldRuntime.mapPoints()
    local ids,result={},{}
    for id in pairs(handles) do ids[#ids+1]=id end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local point=PauseWorldRuntime.points[id]
        if point and point.display~=5 and (point.alpha>0 or (point.zone and point.zone.mode~='none' and point.zone.alpha>0)) then
            result[#result+1]={x=point.pos.x,y=point.pos.y,z=point.pos.z,sprite=tonumber(point.model),color=point.color,
                name=point.name,group=point.group,managedId=id,scale=point.scale,alpha=point.alpha,rotation=point.rotation,
                flash=point.flash,mapGround=point.mapGround,mapOffset=point.mapOffset,zoneShape=PauseSettings.copy(point.zone)}
        end
    end
    return result
end
function PauseWorldRuntime.clearPreview() remove(preview);remove(previewZone);preview,previewZone=nil,nil end
function PauseWorldRuntime.preview(point)
    PauseWorldRuntime.clearPreview()
    local valid=PauseWorldBlips.validate(point)
    if valid then preview=create(valid,'[Prévia] '..valid.name);previewZone=createZone(valid) end
end
RegisterNetEvent('forge-pause:points:updated',PauseWorldRuntime.receive)
AddEventHandler('forge-pause:blips:applied',refresh)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    PauseWorldRuntime.clearPreview()
    for _,entry in pairs(handles) do remove(entry.handle);remove(entry.zone) end
    handles,byHandle,zoneHandles={},{},{}
end)
CreateThread(function()
    while PauseWorldRuntime.revision<0 do
        local ok,snapshot=pcall(pr_lib.callback.await,'forge-pause:points:get',false)
        if ok then PauseWorldRuntime.receive(snapshot) end
        if PauseWorldRuntime.revision<0 then Wait(5000) end
    end
end)
