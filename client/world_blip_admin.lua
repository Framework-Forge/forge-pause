PauseWorldAdmin={}
local Menu=pr_lib.menu
local points,revision,parent={},-1,'forge_pause_admin'
local draft,editingId,search,page=nil,nil,'',1
local showList,showPoint,showDraft
local function notify(message,kind)
    pr_lib.Notify({title='Forge Pause · Blips no mapa',description=message,type=kind or 'inform'})
end
local function context(id,title,options,back)
    Menu.RegisterContext({id=id,title=title,menu=back,options=options,
        onBack=function() PauseWorldRuntime.clearPreview() end,
        onExit=function() PauseWorldRuntime.clearPreview();TriggerEvent('forge-pause:admin:catalogExit') end})
    Menu.ShowContext(id)
end
local function image(point)
    local model=PauseBlips.model(point.model,PauseBlipModels.models)
    if not model then return end
    return model.image:sub(1,7)=='assets/' and ('https://cfx-nui-'..GetCurrentResourceName()..'/web/'..model.image) or model.image
end
local function metadata(id,point)
    return {{label='ID do ponto',value=id or 'Novo (ainda não salvo)'},{label='Modelo do catálogo',value=point.model},
        {label='Sprite no minimapa nativo',value=point.nativeSprite},{label='Categoria',value=point.group},
        {label='Coordenadas',value=('%.3f, %.3f, %.3f'):format(point.pos.x,point.pos.y,point.pos.z)},
        {label='Estado',value=point.enabled and 'Ativo' or 'Desativado'}}
end
local function refresh()
    local ok,result=pcall(pr_lib.callback.await,'forge-pause:points:get',false)
    if not ok or type(result)~='table' then notify('Não foi possível carregar os pontos do servidor.','error') return false end
    if result.admin~=true then notify('Você não tem permissão para gerenciar os blips.','error') return false end
    if type(result.points)~='table' or type(result.revision)~='number' then notify('Resposta de pontos inválida.','error') return false end
    points,revision=result.points,result.revision
    PauseWorldRuntime.receive(result)
    if result.writable==false then notify('O arquivo de pontos precisa ser corrigido antes de salvar alterações.','error') end
    return true
end
local function mutate(operation,id,value)
    local ok,result=pcall(pr_lib.callback.await,'forge-pause:points:edit',false,operation,id,value,revision)
    if not ok or type(result)~='table' then notify('Falha ao comunicar com o servidor.','error') return false end
    if not result.ok then notify(result.message,'error');refresh();return false end
    points,revision=result.points,result.revision
    PauseWorldRuntime.receive(result)
    notify(result.message,'success')
    return true,result.id
end
local function form(title,rows,apply)
    local values=Menu.InputDialog(title,rows)
    if values then
        local previous=PauseSettings.copy(draft)
        apply(values)
        local valid,reason=PauseWorldBlips.validate(draft)
        if valid then draft=valid else draft=previous;notify(reason,'error') end
    end
    showDraft()
end
local function positionMenu()
    context('forge_pause_point_position','Posição do blip',{
        {title='Usar minha posição atual',icon='geo-alt',onSelect=function()
            local pos=GetEntityCoords(PlayerPedId());draft.pos={x=pos.x,y=pos.y,z=pos.z};showDraft()
        end},
        {title='Usar ponto marcado no GPS',icon='pin-map',description='Usa X/Y do GPS. Confirme a altura Z ao criar pontos em interiores.',onSelect=function()
            local waypoint=GetFirstBlipInfoId(8)
            while DoesBlipExist(waypoint) and PauseWorldRuntime.describe(waypoint) do waypoint=GetNextBlipInfoId(8) end
            if not DoesBlipExist(waypoint) then notify('Marque um destino no GPS primeiro.','error');return positionMenu() end
            local pos=GetBlipInfoIdCoord(waypoint)
            local found,z=GetGroundZFor_3dCoord(pos.x,pos.y,1000.0,false)
            draft.pos={x=pos.x,y=pos.y,z=found and z or draft.pos.z}
            if not found then notify('Altura não carregada. A altura anterior foi mantida; ajuste Z manualmente.') end
            showDraft()
        end},
        {title='Informar coordenadas exatas (X/Y/Z)',icon='crosshair',onSelect=function()
            local rows={}
            for _,axis in ipairs({'x','y','z'}) do rows[#rows+1]={type='number',label=axis:upper(),default=draft.pos[axis],precision=3,step=0.01,required=true} end
            form('Coordenadas exatas',rows,function(v) draft.pos={x=v[1],y=v[2],z=v[3]} end)
        end},
    },'forge_pause_point_draft')
end
local function appearance()
    form('Aparência e exibição',{
        {type='number',label='Tamanho (0.1 a 10)',default=draft.scale,min=0.1,max=10,precision=2,step=0.1,required=true},
        {type='number',label='Cor no minimapa nativo (0 a 85)',default=draft.color,min=0,max=85,required=true},
        {type='number',label='Opacidade (0 a 255)',default=draft.alpha,min=0,max=255,required=true},
        {type='number',label='Rotação (0 a 359)',default=draft.rotation,min=0,max=359,required=true},
        {type='select',label='Onde mostrar',default=draft.display,required=true,options={
            {value=2,label='Mapa e minimapa'},{value=3,label='Somente mapa'},{value=5,label='Somente minimapa'}}},
        {type='checkbox',label='Curto alcance no minimapa',checked=draft.shortRange},
        {type='checkbox',label='Piscar',checked=draft.flash},
        {type='checkbox',label='Ponto ativado',checked=draft.enabled},
        {type='number',label='Sprite GTA no minimapa nativo (0 a 965)',default=draft.nativeSprite,min=0,max=965,required=true,
            description='Imagens do catálogo são exibidas no mapa Forge. O minimapa usa este sprite GTA, sem substituir texturas globais.'},
    },function(v)
        draft.scale,draft.color,draft.alpha,draft.rotation=v[1],v[2],v[3],v[4]
        draft.display,draft.shortRange,draft.flash,draft.enabled,draft.nativeSprite=tonumber(v[5]),v[6]==true,v[7]==true,v[8]==true,v[9]
    end)
end
showDraft=function()
    local valid,reason=PauseWorldBlips.validate(draft)
    if not valid then notify(reason,'error') end
    context('forge_pause_point_draft',editingId and 'Editar blip no mapa' or 'Criar blip no mapa',{
        {title=draft.name,description='Rascunho local. Só publica ao confirmar Salvar.',icon='geo-alt',image=image(draft),metadata=metadata(editingId,draft),readOnly=true},
        {title='Nome e categoria deste ponto',icon='pencil',onSelect=function()
            form('Nome do local',{{type='input',label='Nome',default=draft.name,max=100,required=true},
                {type='input',label='Categoria',default=draft.group,max=100,required=true}},function(v) draft.name,draft.group=v[1],v[2] end)
        end},
        {title='Escolher ícone do catálogo',description='Modelo #'..draft.model,icon='images',onSelect=function()
            PauseBlipAdmin.pick('forge_pause_point_draft',function(model)
                draft.model=model.id
                if tonumber(model.id)<=965 then draft.nativeSprite=tonumber(model.id) end
                if draft.name=='Novo local' then draft.name,draft.group=model.name,model.group end
                showDraft()
            end)
        end},
        {title='Posicionar blip',description=('X %.2f · Y %.2f · Z %.2f'):format(draft.pos.x,draft.pos.y,draft.pos.z),icon='pin-map',onSelect=positionMenu},
        {title='Aparência e exibição',description='Tamanho, cor, opacidade, rotação e piscar do blip nativo; escolha onde exibir o ponto.',icon='palette',onSelect=appearance},
        {title='Prévia local do blip nativo',description='Visível somente para você; não salva nem publica.',icon='eye',onSelect=function()
            if valid then PauseWorldRuntime.preview(valid);notify('Prévia criada somente para você.') end
            showDraft()
        end},
        {title='Salvar e publicar blip',icon='check',onSelect=function()
            local ok,id=mutate('save',editingId,draft)
            if ok then PauseWorldRuntime.clearPreview();draft=nil;showPoint(id) else showDraft() end
        end},
        {title='Descartar rascunho e voltar',icon='x-lg',onSelect=function()
            PauseWorldRuntime.clearPreview();draft=nil;showList()
        end},
    },'forge_pause_world_blips')
end
local function startDraft(point,id)
    PauseWorldRuntime.clearPreview()
    draft=point and PauseSettings.copy(point) or PauseWorldBlips.defaults(GetEntityCoords(PlayerPedId()))
    editingId=id
    showDraft()
end
showPoint=function(id)
    local point=points[id]
    if not point then return showList() end
    context('forge_pause_world_blip',point.name,{
        {title=point.name,icon='geo-alt',image=image(point),metadata=metadata(id,point),readOnly=true},
        {title='Editar ícone, posição e informações',icon='pencil',onSelect=function() startDraft(point,id) end},
        {title='Duplicar este ponto',icon='copy',onSelect=function() startDraft(point) end},
        {title='Traçar rota até este ponto',icon='signpost',onSelect=function() SetNewWaypoint(point.pos.x,point.pos.y);notify('Destino marcado no GPS.');showPoint(id) end},
        {title=point.enabled and 'Desativar ponto' or 'Ativar ponto',icon=point.enabled and 'eye-slash' or 'eye',onSelect=function() mutate('toggle',id);showPoint(id) end},
        {title='Excluir ponto do mapa',description='Remove somente este ponto; mantém o modelo do catálogo.',icon='trash',onSelect=function()
            local answer=Menu.AlertDialog({header='Excluir '..point.name..'?',content='Remover este ponto do mapa para todos os jogadores?',cancel=true,centered=true})
            if answer=='confirm' then mutate('delete',id) end
            showList()
        end},
    },'forge_pause_world_blips')
end
showList=function()
    PauseWorldRuntime.clearPreview()
    local ids={}
    for id,point in pairs(points) do
        if (id..' '..point.name..' '..point.group):lower():find(search:lower(),1,true) then ids[#ids+1]=id end
    end
    table.sort(ids)
    local pages=math.max(1,math.ceil(#ids/30));page=math.max(1,math.min(page,pages))
    local options={
        {title='Criar novo blip',description='Inicia na sua posição. Escolha ícone e coordenadas antes de publicar.',icon='plus-circle',onSelect=function() startDraft() end},
        {title='Buscar pontos',description=search~='' and search or 'Por nome, ID ou categoria.',icon='search',onSelect=function()
            local v=Menu.InputDialog('Buscar pontos',{{type='input',label='Nome, ID ou categoria',default=search,max=100}})
            if v then search,page=tostring(v[1] or ''),1 end
            showList()
        end},
        {title=('%d pontos · página %d de %d'):format(#ids,page,pages),description='Alterações confirmadas são salvas imediatamente.',icon='info-circle',readOnly=true},
    }
    for i=(page-1)*30+1,math.min(page*30,#ids) do
        local id=ids[i];local point=points[id]
        options[#options+1]={title=point.name..(point.enabled and '' or ' · Desativado'),description=id..' · '..point.group,
            image=image(point),metadata=metadata(id,point),icon='geo-alt',arrow=true,onSelect=function() showPoint(id) end}
    end
    if page>1 then options[#options+1]={title='Página anterior',icon='arrow-left',onSelect=function() page=page-1;showList() end} end
    if page<pages then options[#options+1]={title='Próxima página',icon='arrow-right',onSelect=function() page=page+1;showList() end} end
    options[#options+1]={title='Atualizar pontos',icon='arrow-clockwise',onSelect=function() if refresh() then showList() end end}
    context('forge_pause_world_blips','Blips criados no mapa',options,parent)
end
function PauseWorldAdmin.open(parentMenu)
    parent=parentMenu or 'forge_pause_admin'
    search,page='',1
    if refresh() then showList() else TriggerEvent('forge-pause:admin:catalogExit') end
end
AddEventHandler('forge-pause:admin:catalogExit',function() PauseWorldRuntime.clearPreview() end)
