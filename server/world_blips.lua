local file='world-blips.json'
local points,nextId,revision,lastSave,saving={},1,0,{},false
local writable=true
local loaded,stored=pcall(pr_lib.loadJson,file,true)
if not loaded or (stored~=nil and (type(stored)~='table' or type(stored.points)~='table')) then
    writable=false
elseif stored then
    if type(stored.nextId)=='number' and stored.nextId%1==0 and stored.nextId>=1 and stored.nextId<=1000000000 then
        nextId=stored.nextId
    end
    local count=0
    for id,value in pairs(stored.points) do
        local valid=PauseWorldBlips.validate(value)
        count=count+1
        local number=tonumber(type(id)=='string' and id:match('%d+$') or '')
        if not PauseWorldBlips.id(id) or not number or number>1000000000 or not valid or count>PauseWorldBlips.maxPoints then writable=false break end
        points[id]=valid
        nextId=math.max(nextId,(tonumber(id:match('%d+$')) or 0)+1)
    end
end
if not writable then
    print('[forge-pause] world-blips.json inválido. Edição bloqueada para preservar o arquivo; verifique uma cópia de segurança.')
end
local function snapshot() return {points=PauseSettings.copy(points),revision=revision} end
local function modelAvailable(point)
    local model=PauseBlipCatalog.get(point.model)
    return model and not model.disabled
end
pr_lib.callback.register('forge-pause:points:get',function(source)
    local result=snapshot()
    result.admin=PauseAdmin.allowed(source)
    result.writable=writable
    return result
end)
pr_lib.callback.register('forge-pause:points:edit',function(source,operation,id,proposed,expectedRevision)
    local function failure(message) return {ok=false,message=message} end
    if not PauseAdmin.allowed(source) then return failure('Você não tem permissão para gerenciar blips.') end
    if not writable then return failure('O arquivo de pontos está inválido. Corrija-o antes de salvar para não perder dados.') end
    if saving then return failure('Os pontos estão sendo salvos. Tente novamente.') end
    if expectedRevision~=revision then return failure('Outro administrador alterou os pontos. A lista será atualizada; tente novamente.') end
    local changed=PauseSettings.copy(points)
    local candidateId=nextId
    if operation=='save' then
        local valid,reason=PauseWorldBlips.validate(proposed)
        if not valid then return failure(reason) end
        if not modelAvailable(valid) then return failure('O modelo escolhido não existe ou está oculto no catálogo.') end
        if id==nil then
            if candidateId>1000000000 then return failure('Limite de identificadores atingido.') end
            local count=0;for _ in pairs(changed) do count=count+1 end
            if count>=PauseWorldBlips.maxPoints then return failure('Limite de 500 pontos atingido.') end
            repeat id=('blip-%06d'):format(candidateId);candidateId=candidateId+1 until not changed[id]
        elseif not PauseWorldBlips.id(id) or not changed[id] then return failure('Ponto não encontrado.') end
        changed[id]=valid
    elseif operation=='delete' or operation=='toggle' then
        if not PauseWorldBlips.id(id) or not changed[id] then return failure('Ponto não encontrado.') end
        if operation=='delete' then changed[id]=nil
        else
            if not changed[id].enabled and not modelAvailable(changed[id]) then return failure('Restaure o modelo de ícone antes de ativar este ponto.') end
            changed[id].enabled=not changed[id].enabled
        end
    else return failure('Operação inválida.') end
    local now=GetGameTimer()
    if lastSave[source] and now-lastSave[source]<750 then return failure('Aguarde um instante antes de salvar novamente.') end
    lastSave[source],saving=now,true
    local ok,written=pcall(pr_lib.saveJson,file,{points=changed,nextId=candidateId})
    saving=false
    if not ok or not written then return failure('Falha ao salvar. Os pontos anteriores foram mantidos.') end
    points,nextId,revision=changed,candidateId,revision+1
    local result=snapshot()
    TriggerClientEvent('forge-pause:points:updated',-1,result)
    result.ok,result.id,result.message=true,id,'Blips salvos e atualizados para todos.'
    return result
end)
AddEventHandler('playerDropped',function() lastSave[source]=nil end)
