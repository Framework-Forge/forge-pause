local file = 'admin-settings.json'
local current = PauseSettings.copy(PauseSettings.defaults)
local revision, lastSave = 0, {}
local loaded, saved = pcall(pr_lib.loadJson, file, true)
if loaded and saved ~= nil then
    local valid, reason = PauseSettings.validate(saved)
    if valid then current = valid else print('[forge-pause] Configuração salva ignorada: ' .. reason) end
elseif not loaded then
    print('[forge-pause] Não foi possível ler admin-settings.json; usando config.lua.')
end
PauseSettings.apply(current)

local function aceAllowed(source, name)
    if type(name) ~= 'string' or name == '' then return false end
    local result = IsPlayerAceAllowed(source, name)
    return result == true or result == 1
end
PauseAdmin = {}
function PauseAdmin.allowed(source)
    return aceAllowed(source, Config.Admin.ace) or aceAllowed(source, Config.Admin.inheritAce)
end
local allowed = PauseAdmin.allowed
local function snapshot() return { settings = PauseSettings.copy(current), revision = revision } end

pr_lib.callback.register('forge-pause:settings', function(source)
    local result = snapshot()
    result.admin = allowed(source) == true
    return result
end)
pr_lib.callback.register('forge-pause:admin:get', function(source)
    if not allowed(source) then return { ok = false, message = 'Você não tem permissão para configurar o pause.' } end
    local result = snapshot()
    result.ok = true
    return result
end)
pr_lib.callback.register('forge-pause:admin:save', function(source, proposed, expectedRevision)
    if not allowed(source) then return { ok = false, message = 'Você não tem permissão para configurar o pause.' } end
    if expectedRevision ~= revision then return { ok = false, message = 'Outro administrador alterou as configurações. Reabra o menu.' } end
    local now = GetGameTimer()
    if lastSave[source] and now - lastSave[source] < 1000 then return { ok = false, message = 'Aguarde um segundo antes de salvar novamente.' } end
    lastSave[source] = now
    local valid, reason = PauseSettings.validate(proposed)
    if not valid then return { ok = false, message = reason } end
    if not LoadResourceFile(GetCurrentResourceName(), 'web/' .. valid.map.image) then return { ok = false, message = 'A imagem configurada não existe em web/assets.' } end
    local ok, written = pcall(pr_lib.saveJson, file, valid)
    if not ok or not written then return { ok = false, message = 'Falha ao salvar o arquivo. Nenhuma alteração foi aplicada.' } end
    current, revision = valid, revision + 1
    PauseSettings.apply(current)
    TriggerClientEvent('forge-pause:settings:updated', -1, snapshot())
    print(('[forge-pause] Configuração atualizada por %s (ID %s).'):format(GetPlayerName(source) or 'admin', source))
    local result = snapshot()
    result.ok, result.message = true, 'Configurações salvas e aplicadas para todos os jogadores.'
    return result
end)
AddEventHandler('playerDropped', function() lastSave[source] = nil end)
