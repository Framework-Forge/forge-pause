-- In this PR Bridge version, the native RegisterContext interface is pr_lib.menu.
local Menu = pr_lib.menu
local draft, revision, active = nil, nil, false
local showRoot
local parentMenu, parentResource

local function notify(message, kind)
    pr_lib.Notify({ title = 'Forge Pause · Administração', description = message, type = kind or 'inform' })
end
local function call(name, ...)
    local ok, result = pcall(pr_lib.callback.await, name, false, ...)
    if not ok or type(result) ~= 'table' then notify('Não foi possível comunicar com o servidor.', 'error') return end
    return result
end
local function context(id, title, options, parent)
    Menu.RegisterContext({ id = id, title = title, menu = parent, options = options,
        menuResource = id == 'forge_pause_admin' and parentResource or nil,
        onBack = id == 'forge_pause_admin' and function() active = false end or nil,
        onExit = function() active = false end })
    Menu.ShowContext(id)
end
local function edit(title, rows, apply, back)
    local input = Menu.InputDialog(title, rows)
    if input then apply(input) end
    back()
end
local function showMap()
    context('forge_pause_admin_map', 'Modelo de mapa', {
        { title = 'Mapa original do GTA', description = 'Mapa nativo com blips e GPS.', icon = 'map',
            onSelect = function() draft.map.mode = 'gta' showRoot() end },
        { title = 'Mapa 3D', description = 'Câmera sobre o mundo, com zoom e rotação.', icon = 'box',
            onSelect = function() draft.map.mode = '3d' showRoot() end },
        { title = 'Limites do mapa 3D', icon = 'sliders', onSelect = function()
            local keys = { 'minDistance', 'initialDistance', 'maxDistance' }
            local labels = { 'Distância mínima', 'Distância inicial', 'Distância máxima (20.000 a 50.000)' }
            local rows = {}
            for i, key in ipairs(keys) do rows[i] = { type = 'number', label = labels[i], default = draft.map[key], required = true, min = key=='maxDistance' and 20000 or 30, max = key=='maxDistance' and 50000 or 20000 } end
            edit('Limites do mapa 3D', rows, function(input) for i, key in ipairs(keys) do draft.map[key] = input[i] end end, showRoot)
        end }
    }, 'forge_pause_admin')
end
local function showColors()
    local keys = { 'accent', 'background', 'panel', 'card', 'border', 'text', 'muted' }
    local labels = { 'Destaque', 'Fundo', 'Painéis', 'Cards', 'Bordas', 'Texto principal', 'Texto secundário' }
    local rows = {}
    for i, key in ipairs(keys) do rows[i] = { type = 'color', label = labels[i], default = draft.theme[key], format = 'hex', required = true } end
    edit('Cores do pause', rows, function(input) for i, key in ipairs(keys) do draft.theme[key] = input[i] end end, showRoot)
end
local function showPortrait()
    local keys = { 'distance', 'side', 'height', 'fov', 'transition' }
    local rows = { { type = 'checkbox', label = 'Ativar câmera do personagem', checked = draft.portrait.enabled } }
    local labels = { 'Distância (0.6 a 4)', 'Deslocamento lateral (-2 a 2)', 'Altura (-1 a 1)', 'Campo de visão (20 a 80)', 'Transição em ms (0 a 2000)' }
    for i, key in ipairs(keys) do rows[i + 1] = { type = 'number', label = labels[i], default = draft.portrait[key], required = true, precision = 2, step = 0.05 } end
    edit('Câmera do personagem', rows, function(input)
        draft.portrait.enabled = input[1] == true
        for i, key in ipairs(keys) do draft.portrait[key] = input[i + 1] end
    end, showRoot)
end
showRoot = function()
    context('forge_pause_admin', 'Forge Pause · Administração', {
        { title = 'Modelo de mapa', description = ({ gta = 'GTA', image = 'Imagem', ['3d'] = '3D' })[draft.map.mode], icon = 'map', onSelect = showMap },
        { title = 'Modelos de ícones do mapa', description = 'Catálogo, prévias e IDs. Alterações salvas no próprio submenu.', icon = 'images',
            onSelect = function() PauseBlipAdmin.open('forge_pause_admin') end },
        { title = 'Blips criados no mapa', description = 'Criar pontos, escolher ícones, posicionar e gerenciar.', icon = 'geo-alt',
            onSelect = function() PauseWorldAdmin.open('forge_pause_admin') end },
        { title = 'Cores do layout', description = 'Destaque, superfícies, bordas e textos.', icon = 'palette-fill', onSelect = showColors },
        { title = 'Câmera do personagem', description = 'Enquadramento, distância e transição.', icon = 'camera', onSelect = showPortrait },
        { title = 'Identidade do servidor', description = draft.name, icon = 'pencil', onSelect = function()
            edit('Identidade do servidor', {
                { type = 'input', label = 'Nome', default = draft.name, required = true, max = 100 },
                { type = 'input', label = 'Descrição', default = draft.subtitle, required = true, max = 100 }
            }, function(input) draft.name, draft.subtitle = input[1], input[2] end, showRoot)
        end },
        { title = 'Restaurar padrão Forge', description = 'Prepara os valores de config.lua. Confirme em Salvar.', icon = 'arrow-counterclockwise', onSelect = function()
            draft = PauseSettings.copy(PauseSettings.defaults)
            showRoot()
        end },
        { title = 'Salvar e aplicar para todos', description = 'Grava no servidor e mantém após reiniciar.', icon = 'check', onSelect = function()
            local result = call('forge-pause:admin:save', draft, revision)
            if result and result.ok then
                draft, revision = result.settings, result.revision
                notify(result.message, 'success')
            elseif result then notify(result.message, 'error') end
            showRoot()
        end },
        { title = 'Fechar sem salvar', description = 'Descarta as alterações pendentes.', icon = 'x-lg', onSelect = function() active = false end }
    }, parentMenu)
end

local function openAdmin(menu, resource)
    if active then return end
    active = true
    local result = call('forge-pause:admin:get')
    if not result or not result.ok then
        active = false
        if result then notify(result.message, 'error') end
        return
    end
    TriggerEvent('forge-pause:admin:prepare')
    if IsNuiFocused() then active = false notify('Feche a outra interface antes de abrir o administrador.', 'error') return end
    parentMenu = type(menu) == 'string' and menu ~= '' and menu or nil
    parentResource = parentMenu and type(resource) == 'string' and resource ~= '' and resource or nil
    draft, revision = result.settings, result.revision
    showRoot()
end

AddEventHandler('forge-pause:client:openAdminMenu', function(menu, resource)
    local callerResource = resource or GetInvokingResource()
    CreateThread(function() openAdmin(menu, callerResource) end)
end)
AddEventHandler('forge-pause:admin:catalogExit', function() active = false end)

RegisterCommand(Config.Admin.command, function()
    openAdmin()
end, false)
