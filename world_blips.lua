-- World points are separate from the icon catalog and from layout settings.
PauseWorldBlips = {maxPoints=500}

function PauseWorldBlips.id(value)
    return type(value)=='string' and #value<=24 and value:match('^blip%-%d+$') and value or nil
end

function PauseWorldBlips.validate(value)
    if type(value)~='table' then return nil,'Ponto inválido.' end
    local result={}
    for _,field in ipairs({'name','group'}) do
        local text=value[field]
        if type(text)~='string' or #text<1 or #text>100 or text:find('%c') or not text:find('%S') then
            return nil,'Nome e categoria devem ter de 1 a 100 caracteres.'
        end
        result[field]=text
    end
    result.model=PauseBlips.id(value.model)
    if not result.model then return nil,'Modelo de ícone inválido.' end
    if type(value.pos)~='table' then return nil,'Informe a posição do blip.' end
    result.pos={}
    for _,axis in ipairs({'x','y','z'}) do
        local n=value.pos[axis]
        local limit=axis=='z' and 2000 or (axis=='x' and 10000 or 15000)
        if type(n)~='number' or n~=n or math.abs(n)>limit then return nil,'Coordenadas inválidas ou fora dos limites do mapa.' end
        result.pos[axis]=n
    end
    local ranges={nativeSprite={0,965,true},scale={0.1,10},color={0,85,true},alpha={0,255,true},rotation={0,359,true}}
    for field,range in pairs(ranges) do
        local n=value[field]
        if type(n)~='number' or n~=n or n<range[1] or n>range[2] or (range[3] and n%1~=0) then
            return nil,'Valor inválido para '..field..'.'
        end
        result[field]=n
    end
    if value.display~=2 and value.display~=3 and value.display~=5 then return nil,'Modo de exibição inválido.' end
    result.display=value.display
    for _,field in ipairs({'enabled','shortRange','flash'}) do
        if type(value[field])~='boolean' then return nil,'Opção inválida: '..field..'.' end
        result[field]=value[field]
    end
    -- Visual placement is independent of the saved world/radar coordinates.
    if value.mapGround~=nil and type(value.mapGround)~='boolean' then return nil,'Ajuste de chão do mapa 3D inválido.' end
    local offset=value.mapOffset==nil and 0.15 or value.mapOffset
    if type(offset)~='number' or offset~=offset or math.abs(offset)>150 then return nil,'A altura visual do mapa 3D deve estar entre -150 e 150 metros.' end
    result.mapGround=value.mapGround~=false
    result.mapOffset=offset+0.0
    local zone=value.zone or {mode='none'}
    if type(zone)~='table' or (zone.mode~='none' and zone.mode~='radius' and zone.mode~='area') then return nil,'Tipo de zona inválido.' end
    result.zone={mode=zone.mode}
    if zone.mode~='none' then
        for field,range in pairs({radius={1,2000},width={1,4000},height={1,4000},rotation={0,359},color={0,85},alpha={0,255}}) do
            local n=zone[field]
            local relevant=field~='radius' or zone.mode=='radius'
            if field=='width' or field=='height' then relevant=zone.mode=='area' end
            if relevant then
                if type(n)~='number' or n~=n or n<range[1] or n>range[2]
                    or ((field=='color' or field=='alpha' or field=='rotation') and n%1~=0) then return nil,'Dimensões, cor ou opacidade da zona inválidas.' end
                result.zone[field]=n
            end
        end
    end
    return result
end

function PauseWorldBlips.defaults(pos)
    return {name='Novo local',group='Outros',model='1',nativeSprite=1,
        pos={x=pos.x,y=pos.y,z=pos.z},scale=0.9,color=0,alpha=255,rotation=0,
        display=2,enabled=true,shortRange=true,flash=false,mapGround=true,mapOffset=0.15,zone={mode='none'}}
end
