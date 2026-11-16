local file = 'blip-models.json'
local models, revision, lastSave, saving = {}, 0, {}, false
local loaded, stored = pcall(pr_lib.loadJson, file, true)
if loaded and type(stored) == 'table' then
    local count = 0
    for key, value in pairs(stored) do
        local id, valid = PauseBlips.id(key), PauseBlips.validate(value)
        count = count + 1
        if count > PauseBlips.maxOverrides then break end
        if id and valid then models[id] = valid end
    end
elseif not loaded then
    print('[forge-pause] Não foi possível ler blip-models.json; usando o catálogo original.')
end

local allowed = PauseAdmin.allowed
local function snapshot()
    return {models = PauseSettings.copy(models), revision = revision}
end
PauseBlipCatalog = {get=function(id) return PauseBlips.model(id,models) end}
pr_lib.callback.register('forge-pause:blips:get', function(source)
    local result = snapshot()
    result.admin = allowed(source) == true
    return result
end)
pr_lib.callback.register('forge-pause:blips:edit', function(source, operation, key, proposed, expectedRevision)
    local function failure(message) return {ok = false, message = message} end
    if not allowed(source) then return failure('Você não tem permissão para editar o catálogo.') end
    if expectedRevision ~= revision then return failure('Outro administrador alterou o catálogo. A lista será atualizada; tente novamente.') end
    if saving then return failure('O catálogo está sendo salvo. Tente novamente.') end
    local id = PauseBlips.id(key)
    if not id then return failure('Use um ID inteiro entre 0 e 65535.') end
    local nextModels = PauseSettings.copy(models)
    if operation == 'save' then
        local valid, reason = PauseBlips.validate(proposed)
        if not valid then return failure(reason) end
        if valid.image:sub(1,7) == 'assets/' and not LoadResourceFile(GetCurrentResourceName(), 'web/' .. valid.image) then
            return failure('A imagem local não existe. Coloque o arquivo em web/assets/blips ou use uma URL HTTPS.')
        end
        nextModels[id] = valid
    elseif operation == 'delete' then
        local existing = PauseBlips.model(id, models)
        if not existing then return failure('Modelo não encontrado.') end
        nextModels[id] = {name=existing.name, group=existing.group, image=existing.image, disabled=true}
    elseif operation == 'restore' then
        if PauseBlips.base[id] then nextModels[id] = nil
        elseif nextModels[id] then nextModels[id].disabled = false
        else return failure('Modelo não encontrado.') end
    else return failure('Operação inválida.') end
    local count = 0
    for _ in pairs(nextModels) do count = count + 1 end
    if count > PauseBlips.maxOverrides then return failure('Limite de personalizações atingido.') end
    local now = GetGameTimer()
    if lastSave[source] and now - lastSave[source] < 750 then return failure('Aguarde um instante antes de salvar novamente.') end
    lastSave[source], saving = now, true
    local ok, written = pcall(pr_lib.saveJson, file, nextModels)
    saving = false
    if not ok or not written then return failure('Falha ao salvar. O catálogo anterior foi mantido.') end
    models, revision = nextModels, revision + 1
    local result = snapshot()
    TriggerClientEvent('forge-pause:blips:updated', -1, result)
    result.ok, result.message = true, 'Catálogo salvo e aplicado para todos.'
    return result
end)
AddEventHandler('playerDropped', function() lastSave[source] = nil end)
