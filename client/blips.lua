PauseBlipModels = {models = {}, revision = -1}

function PauseBlipModels.receive(snapshot)
    if type(snapshot) ~= 'table' or type(snapshot.models) ~= 'table'
        or type(snapshot.revision) ~= 'number' or snapshot.revision < PauseBlipModels.revision then return false end
    PauseBlipModels.models = snapshot.models
    PauseBlipModels.revision = snapshot.revision
    SendNUIMessage({action = 'blipModels', models = snapshot.models, revision = snapshot.revision})
    TriggerEvent('forge-pause:blips:applied')
    return true
end
RegisterNetEvent('forge-pause:blips:updated', PauseBlipModels.receive)
CreateThread(function()
    while PauseBlipModels.revision < 0 do
        local ok, snapshot = pcall(pr_lib.callback.await, 'forge-pause:blips:get', false)
        if ok then PauseBlipModels.receive(snapshot) end
        if PauseBlipModels.revision < 0 then Wait(5000) end
    end
end)
