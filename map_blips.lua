-- Transient integration schema: no export writes administrator data.
PauseMapBlips={maxPoints=500,maxPerResource=128}
function PauseMapBlips.id(id)
    return type(id)=='string' and #id>=1 and #id<=64 and id:match('^[%w_%-][%w_%.:%-]*$') and id or nil
end
function PauseMapBlips.normalize(data,previous)
    if type(data)~='table' then return nil,'Informe os dados do blip em uma tabela.' end
    local point=previous and PauseSettings.copy(previous) or PauseWorldBlips.defaults({x=0,y=0,z=0})
    local pos=data.coords or data.pos
    if not previous and pos==nil then return nil,'Informe coords ou pos com x, y e z.' end
    if pos~=nil then
        local kind=type(pos)
        if kind~='table' and kind~='vector3' and kind~='vector4' then return nil,'Coordenadas inválidas.' end
        for _,axis in ipairs({'x','y','z'}) do
            if pos[axis]~=nil then point.pos[axis]=pos[axis]
            elseif not previous then return nil,'Informe x, y e z.' end
        end
    end
    if data.model~=nil or data.sprite~=nil then
        point.model=data.model~=nil and data.model or data.sprite
        local id=PauseBlips.id(point.model)
        if id and tonumber(id)<=965 and data.nativeSprite==nil then point.nativeSprite=tonumber(id) end
    end
    for _,field in ipairs({'name','group','nativeSprite','scale','color','alpha','rotation','display','enabled','shortRange','flash','mapGround','mapOffset'}) do
        if data[field]~=nil then point[field]=data[field] end
    end
    if data.zone~=nil then
        if type(data.zone)~='table' then return nil,'Zona inválida.' end
        for _,field in ipairs({'mode','radius','width','height','rotation','color','alpha'}) do
            if data.zone[field]~=nil then point.zone[field]=data.zone[field] end
        end
    end
    return PauseWorldBlips.validate(point)
end
