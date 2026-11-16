local session,previewSettings
local generation=0
local function call(name,...)
    local ok,result=pcall(pr_lib.callback.await,name,false,...)
    if not ok or type(result)~='table' then return {ok=false,message='Falha de comunicação com o servidor. Tente novamente.'} end
    return result
end
local function ready() return PauseMenu.isOpen() and PauseMenu.page()=='admin' and session~=nil end
local function restore()
    if previewSettings then Config.Portrait=PauseSettings.copy(previewSettings.portrait);previewSettings=nil end
    ForgePortrait.stop(true)
    PauseWorldRuntime.clearPreview()
end
AddEventHandler('forge-pause:admin:cleanup',function() generation=generation+1;restore();session=nil end)
AddEventHandler('forge-pause:admin:settingsApplied',function(value)
    if previewSettings then previewSettings={portrait=PauseSettings.copy(value.portrait)} end
end)
RegisterNUICallback('adminSnapshot',function(_,cb)
    if not PauseMenu.isOpen() or PauseMenu.page()~='admin' then cb({ok=false,message='Abra a administração pelo Pause.'}) return end
    local currentGeneration=generation
    local settings=call('forge-pause:admin:get')
    if not settings.ok then cb(settings) return end
    local catalog=call('forge-pause:blips:get')
    local points=call('forge-pause:points:get')
    if catalog.admin~=true or points.admin~=true then cb({ok=false,message='Não foi possível autorizar o catálogo e os pontos.'}) return end
    if currentGeneration~=generation or not PauseMenu.isOpen() or PauseMenu.page()~='admin' then cb({ok=false,message='Sessão encerrada.'}) return end
    if PauseMenu.applySettings then PauseMenu.applySettings(settings) end
    session=session or {}
    PauseBlipModels.receive(catalog);PauseWorldRuntime.receive(points)
    local p=GetEntityCoords(PlayerPedId())
    cb({ok=true,settings=settings,defaults=PauseSettings.copy(PauseSettings.defaults),catalog=catalog,points=points,
        models=PauseBlips.list(catalog.models),colors=pr_lib.fivem.blips.listColors(),position={x=p.x,y=p.y,z=p.z},
        world=ForgeMap.data(),parent=session.parent~=nil})
end)
RegisterNUICallback('adminAction',function(data,cb)
    if not ready() or type(data)~='table' then cb({ok=false,message='Sessão administrativa encerrada.'}) return end
    local result
    if data.kind=='settings' then
        result=call('forge-pause:admin:save',data.value,data.revision)
        if result.ok then previewSettings=nil;if PauseMenu.applySettings then PauseMenu.applySettings(result) end end
    elseif data.kind=='model' then
        result=call('forge-pause:blips:edit',data.operation,data.id,data.value,data.revision)
        if result.ok then PauseBlipModels.receive(result) end
    elseif data.kind=='point' then
        result=call('forge-pause:points:edit',data.operation,data.id,data.value,data.revision)
        if result.ok then PauseWorldRuntime.receive(result);PauseWorldRuntime.clearPreview() end
    else result={ok=false,message='Operação administrativa inválida.'} end
    cb(result)
end)
RegisterNUICallback('adminPreview',function(data,cb)
    if not ready() or type(data)~='table' then cb({ok=false}) return end
    if data.kind=='point' then
        local valid,reason=PauseWorldBlips.validate(data.value)
        if not valid then cb({ok=false,message=reason}) return end
        PauseWorldRuntime.preview(valid)
    elseif data.kind=='settings' then
        local valid,reason=PauseSettings.validate(data.value)
        if not valid then cb({ok=false,message=reason}) return end
        previewSettings=previewSettings or {portrait=PauseSettings.copy(Config.Portrait)}
        -- Camera drafts must not change the published map mode or other settings.
        Config.Portrait=PauseSettings.copy(valid.portrait)
        if not valid.portrait.enabled then
            ForgePortrait.stop(true);cb({ok=true,active=false,message='A câmera do personagem está desativada.'});return
        end
        local active,message=ForgePortrait.start(true)
        cb({ok=active==true,active=active==true,message=message});return
    elseif data.kind=='clear' then PauseWorldRuntime.clearPreview()
    elseif data.kind=='restore' then restore()
    else cb({ok=false}) return end
    cb({ok=true})
end)
RegisterNUICallback('adminPosition',function(data,cb)
    if not ready() or type(data)~='table' then cb({ok=false}) return end
    local pos=GetEntityCoords(PlayerPedId())
    if data.mode=='waypoint' then
        local h=GetFirstBlipInfoId(8)
        while DoesBlipExist(h) and PauseWorldRuntime.describe(h) do h=GetNextBlipInfoId(8) end
        if not DoesBlipExist(h) then cb({ok=false,message='Marque um destino no GPS primeiro.'}) return end
        local wp=GetBlipInfoIdCoord(h)
        cb({ok=true,position={x=wp.x,y=wp.y},message='X/Y do GPS aplicados. A altura Z foi mantida; confirme-a em interiores.'}) return
    end
    cb({ok=true,position={x=pos.x,y=pos.y,z=pos.z}})
end)
RegisterNUICallback('adminEnd',function(data,cb)
    local parent=session
    generation=generation+1;restore();session=nil
    cb({ok=true})
    if type(data)=='table' and data.parent==true and parent and parent.parent and type(parent.resource)=='string' then
        PauseMenu.close()
        TriggerEvent('pr_bridge:ui:context:openExternal',parent.resource,parent.parent,GetCurrentResourceName())
    end
end)
AddEventHandler('forge-pause:client:openAdminMenu',function(menu,resource)
    local caller=resource or GetInvokingResource()
    CreateThread(function()
        local result=call('forge-pause:admin:get')
        if not result.ok then pr_lib.Notify({title='Forge Pause',description=result.message,type='error'}) return end
        if not PauseMenu.isOpen() and IsNuiFocused() then pr_lib.menu.HideContext(false) end
        PauseMenu.setAdmin(true)
        session={parent=type(menu)=='string' and menu or nil,resource=caller}
        if PauseMenu.isOpen() then SendNUIMessage({action='adminOpen'}) else PauseMenu.open('admin') end
        if not PauseMenu.isOpen() then session=nil end
    end)
end)
RegisterCommand(Config.Admin.command,function() TriggerEvent('forge-pause:client:openAdminMenu') end,false)
