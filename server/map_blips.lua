local resources,revision,pending={ },0,false
local function snapshot() return {resources=PauseSettings.copy(resources),revision=revision} end
local function notify()
    revision=revision+1
    if pending then return end
    pending=true
    CreateThread(function()
        Wait(100)
        pending=false
        TriggerClientEvent('forge-pause:map-blips:updated',-1,snapshot())
    end)
end
local function owner()
    local name=GetInvokingResource()
    return type(name)=='string' and name~=GetCurrentResourceName() and name or nil
end
local function save(id,data,update)
    local resource=owner()
    if not resource or not PauseMapBlips.id(id) then return false,'Recurso de origem ou ID inválido.' end
    if type(data)=='table' and data.blip~=nil then return false,'A associação blip=handle está disponível apenas no cliente.' end
    local entries=resources[resource] or {}
    if update and not entries[id] then return false,'Blip não registrado por este recurso.' end
    local point,reason=PauseMapBlips.normalize(data,update and entries[id] or nil)
    if not point then return false,reason end
    local model=PauseBlipCatalog.get(point.model)
    if not model or model.disabled then return false,'Modelo ausente ou desativado no catálogo do Pause.' end
    if not entries[id] then
        local own,total=0,0
        for _ in pairs(entries) do own=own+1 end
        for _,rows in pairs(resources) do for _ in pairs(rows) do total=total+1 end end
        if own>=PauseMapBlips.maxPerResource or total>=PauseMapBlips.maxPoints then return false,'Limite de blips externos atingido.' end
    end
    entries[id]=point;resources[resource]=entries;notify()
    return true
end
exports('RegisterMapBlip',function(id,data) return save(id,data,false) end)
exports('UpdateMapBlip',function(id,data) return save(id,data,true) end)
exports('RemoveMapBlip',function(id)
    local resource=owner()
    if not resource or not PauseMapBlips.id(id) or not resources[resource] or not resources[resource][id] then return false,'Blip não registrado por este recurso.' end
    resources[resource][id]=nil;if not next(resources[resource]) then resources[resource]=nil end
    notify();return true
end)
exports('ClearMapBlips',function()
    local resource=owner()
    if not resource then return false,'Recurso de origem inválido.' end
    resources[resource]=nil;notify();return true
end)
pr_lib.callback.register('forge-pause:map-blips:get',function()return snapshot()end)
AddEventHandler('onResourceStop',function(resource)
    if resources[resource] then resources[resource]=nil;notify() end
end)
