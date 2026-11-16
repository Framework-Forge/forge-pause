PauseBlipAdmin = {}
local Menu = pr_lib.menu
local models, revision, parent = {}, -1, 'forge_pause_admin'
local query, filter, page = '', 'active', 1
local pageSize = 40
local showList, showModel
local picking

local function notify(message, kind)
    pr_lib.Notify({title='Forge Pause · Ícones', description=message, type=kind or 'inform'})
end
local function context(id, title, options, back)
    Menu.RegisterContext({id=id, title=title, menu=back, options=options,
        searchPlaceholder='Buscar nesta página (use Buscar catálogo para pesquisar todos)',
        onBack=function() if id=='forge_pause_admin_blips' then picking=nil end end,
        onExit=function() picking=nil TriggerEvent('forge-pause:admin:catalogExit') end})
    Menu.ShowContext(id)
end
local function imageUrl(image)
    if image:sub(1,7) == 'assets/' then return 'https://cfx-nui-' .. GetCurrentResourceName() .. '/web/' .. image end
    return image
end
local function metadata(model)
    return {
        {label='ID / código do modelo', value=model.id},
        {label='Categoria', value=model.group},
        {label='Origem', value=model.original and (model.edited and 'GTA personalizado' or 'Original GTA') or 'Modelo adicionado'},
        {label='Estado', value=model.disabled and 'Excluído/oculto' or 'Visível'},
        {label='Imagem', value=model.image},
        {label='Uso', value=tonumber(model.id) > 965 and 'Escolha este modelo em Blips criados no mapa; configure um sprite GTA para o minimapa nativo' or 'Ícone disponível para pontos no mapa e aparência deste sprite no Forge Pause'},
    }
end
local function refresh()
    local ok, snapshot, reason = pcall(pr_lib.callback.await, 'forge-pause:blips:get', false)
    local failure
    if not ok or type(snapshot) ~= 'table' then
        failure = 'Não foi possível comunicar com o servidor para abrir o catálogo. Tente novamente.'
        print(('[forge-pause] Falha ao abrir o catálogo: %s'):format(tostring(ok and (reason or 'resposta ausente') or snapshot)))
    elseif snapshot.admin == false then
        failure = 'Você não tem permissão para editar o catálogo de ícones.'
    elseif snapshot.admin ~= true or type(snapshot.models) ~= 'table' or type(snapshot.revision) ~= 'number' then
        failure = 'O catálogo recebeu uma resposta inválida do servidor. Reabra o menu.'
        print('[forge-pause] Resposta inválida de forge-pause:blips:get.')
    end
    if failure then
        notify(failure, 'error')
        TriggerEvent('forge-pause:admin:catalogExit')
        return false
    end
    models, revision = snapshot.models or {}, snapshot.revision
    PauseBlipModels.receive(snapshot)
    return true
end
local function mutate(operation, id, value)
    local ok, result = pcall(pr_lib.callback.await, 'forge-pause:blips:edit', false, operation, id, value, revision)
    if ok and type(result) == 'table' and result.ok then
        models, revision = result.models, result.revision
        PauseBlipModels.receive(result)
        notify(result.message, 'success')
        return true
    end
    notify(ok and type(result) == 'table' and result.message or 'Falha ao comunicar com o servidor.', 'error')
    refresh()
    return false
end
local function nextId()
    local id = 966
    while id <= PauseBlips.maxId and PauseBlips.model(id, models) do id = id + 1 end
    return math.min(id, PauseBlips.maxId)
end
local function editModel(existing, duplicate)
    local adding = not existing or duplicate
    local original = existing or {name='Novo ícone', group='Outros', image='assets/blips/1.png'}
    local rows = {}
    if adding then
        rows[#rows+1] = {type='number', label='ID do modelo', default=nextId(), min=0, max=PauseBlips.maxId, required=true,
            description='Cadastra um ícone, não um ponto. Depois escolha-o em Blips criados no mapa. IDs acima de 965 usam um sprite GTA separado no minimapa nativo.'}
    end
    rows[#rows+1] = {type='input', label='Nome', default=original.name, required=true, max=100}
    rows[#rows+1] = {type='input', label='Categoria', default=original.group, required=true, max=100}
    rows[#rows+1] = {type='input', label='Imagem (arquivo, URL HTTPS ou ID de outro modelo)', default=original.image, required=true, max=512,
        description='Ex.: assets/blips/108.png, https://seusite/icone.png ou 108. Para arquivo novo, coloque a imagem na pasta do recurso.'}
    local result = Menu.InputDialog(adding and 'Adicionar modelo de ícone' or ('Editar modelo #' .. existing.id), rows)
    if not result then return showList() end
    local offset, id = adding and 1 or 0, existing and existing.id
    if adding then
        id = PauseBlips.id(result[1])
        if not id then notify('ID inválido.', 'error') return showList() end
        if PauseBlips.model(id, models) then notify('Este ID já existe. Use Editar para substituí-lo.', 'error') return showList() end
    end
    local image = tostring(result[offset+3] or '')
    if image:match('^%d+$') then
        local reference = PauseBlips.model(image, models)
        if not reference then notify('O ID da imagem de referência não existe.', 'error') return showList() end
        image = reference.image
    end
    mutate('save', id, {name=result[offset+1], group=result[offset+2], image=image, disabled=false})
    showList()
end

showModel = function(id)
    local model = PauseBlips.model(id, models)
    if not model then return showList() end
    local options = {
        {title=model.name, description='ID ' .. id .. ' · ' .. model.group, icon='image', image=imageUrl(model.image), metadata=metadata(model), readOnly=true},
        {title='Editar nome, categoria ou substituir imagem', icon='pencil', onSelect=function() editModel(model) end},
        {title='Adicionar novo modelo usando esta imagem', icon='plus-circle', onSelect=function() editModel(model, true) end},
        {title=model.disabled and 'Reativar / restaurar modelo' or 'Excluir modelo do catálogo',
            description='Não apaga o PNG original nem altera blips de outros recursos.', icon=model.disabled and 'arrow-counterclockwise' or 'trash',
            onSelect=function()
                if model.disabled then mutate('restore', id) return showList() end
                local confirm = Menu.AlertDialog({header='Excluir modelo #' .. id,
                    content='Ocultar este modelo no mapa e na lista do Forge Pause para todos? Você poderá restaurá-lo no filtro Excluídos. O arquivo original não será apagado.', centered=true, cancel=true})
                if confirm == 'confirm' then mutate('delete', id) end
                showList()
            end},
    }
    if model.original and model.edited and not model.disabled then
        options[#options+1] = {title='Restaurar imagem e dados originais do GTA', icon='arrow-counterclockwise',
            onSelect=function() mutate('restore', id) showList() end}
    end
    context('forge_pause_admin_blip', 'Modelo #' .. id, options, 'forge_pause_admin_blips')
end

showList = function()
    local filtered = {}
    for _, model in ipairs(PauseBlips.list(models)) do
        local include = filter == 'all' or (filter == 'active' and not model.disabled)
            or (filter == 'changed' and model.edited and not model.disabled) or (filter == 'deleted' and model.disabled)
        if picking and model.disabled then include=false end
        local haystack = (model.id .. ' ' .. model.name .. ' ' .. model.group):lower()
        if include and haystack:find(query:lower(), 1, true) then filtered[#filtered+1] = model end
    end
    local pages = math.max(1, math.ceil(#filtered/pageSize))
    page = math.max(1, math.min(page, pages))
    local options = {
        {title='Buscar catálogo completo', description=query ~= '' and query or 'Pesquise por ID, nome ou categoria em todas as páginas.', icon='search', onSelect=function()
            local result = Menu.InputDialog('Buscar todos os modelos', {{type='input',label='ID, nome ou categoria (vazio limpa)',default=query,max=100}})
            if result then query, page = tostring(result[1] or ''), 1 end
            showList()
        end},
        {title='Filtro: ' .. ({active='Ativos',changed='Personalizados',deleted='Excluídos',all='Todos'})[filter], icon='funnel', onSelect=function()
            local result = Menu.InputDialog('Filtrar modelos', {{type='select',label='Mostrar',default=filter,required=true,options={
                {value='active',label='Ativos'}, {value='changed',label='Personalizados'}, {value='deleted',label='Excluídos'}, {value='all',label='Todos'}}}})
            if result and ({active=true,changed=true,deleted=true,all=true})[result[1]] then filter, page = result[1], 1 end
            showList()
        end},
        {title=('%d modelos · página %d de %d'):format(#filtered,page,pages), description='Passe o mouse para ver a imagem, o código e a origem. Clique para gerenciar.', icon='info-circle', readOnly=true},
    }
    if not picking then table.insert(options,1,{title='Adicionar modelo de ícone',icon='plus-circle',onSelect=function() editModel() end}) end
    for index=(page-1)*pageSize+1, math.min(page*pageSize,#filtered) do
        local model = filtered[index]
        options[#options+1] = {title='#' .. model.id .. ' · ' .. model.name, description=model.group .. (model.disabled and ' · Excluído' or ''),
            icon='image', image=imageUrl(model.image), metadata=metadata(model), arrow=true,
            onSelect=function()
                if picking then local callback=picking;picking=nil;return callback(model) end
                showModel(model.id)
            end}
    end
    if page > 1 then options[#options+1] = {title='Página anterior', icon='arrow-left', onSelect=function() page=page-1 showList() end} end
    if page < pages then options[#options+1] = {title='Próxima página', icon='arrow-right', onSelect=function() page=page+1 showList() end} end
    options[#options+1] = {title='Atualizar catálogo', icon='arrow-clockwise', onSelect=function() if refresh() then showList() end end}
    context('forge_pause_admin_blips', picking and 'Escolher ícone do blip' or 'Modelos de ícones do mapa', options, parent)
end

function PauseBlipAdmin.open(parentMenu)
    picking=nil
    parent = parentMenu or 'forge_pause_admin'
    query, filter, page = '', 'active', 1
    if refresh() then showList() end
end

function PauseBlipAdmin.pick(parentMenu,callback)
    parent=parentMenu
    picking=callback
    query,filter,page='','active',1
    if refresh() then showList() else picking=nil end
end
