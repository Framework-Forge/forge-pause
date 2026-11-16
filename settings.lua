PauseSettings = {}
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
PauseSettings.copy = copy
PauseSettings.defaults = {
    theme = copy(Config.Theme), map = copy(Config.Map), portrait = copy(Config.Portrait),
    name = Config.ServerName, subtitle = Config.Subtitle
}

-- Server and client use the same strict schema; extra fields never reach Config.
function PauseSettings.validate(value)
    if type(value) ~= 'table' then return nil, 'Configuração inválida.' end
    local result = {}
    for _, field in ipairs({ 'name', 'subtitle' }) do
        if type(value[field]) ~= 'string' or #value[field] < 1 or #value[field] > 100 or value[field]:find('%c') then
            return nil, 'Nome e descrição devem ter entre 1 e 100 caracteres.'
        end
        result[field] = value[field]
    end
    if type(value.theme) ~= 'table' or type(value.map) ~= 'table' or type(value.portrait) ~= 'table' then return nil, 'Configuração incompleta.' end
    result.theme = {}
    for key in pairs(PauseSettings.defaults.theme) do
        local color = value.theme[key]
        if type(color) ~= 'string' or not color:match('^#%x%x%x%x%x%x$') then return nil, 'Use cores no formato #FF7A1A.' end
        result.theme[key] = color:upper()
    end
    local mode = value.map.mode
    if mode == 'image' then mode = 'gta' end -- migrate saved legacy setting
    if mode ~= 'gta' and mode ~= 'image' and mode ~= '3d' then return nil, 'Modelo de mapa inválido.' end
    local image = value.map.image
    if type(image) ~= 'string' or #image > 120 or not image:match('^assets/[%w_%-%.]+$') or image:find('..', 1, true) then return nil, 'A imagem deve ser um arquivo diretamente dentro de web/assets.' end
    local extension = image:match('%.(%w+)$')
    if extension ~= 'png' and extension ~= 'webp' and extension ~= 'jpg' and extension ~= 'jpeg' then return nil, 'Use uma imagem PNG, JPG ou WEBP.' end
    result.map = { mode = mode, image = image }
    local function number(group, key, low, high)
        local n = value[group][key]
        if type(n) ~= 'number' or n ~= n or n < low or n > high then return false end
        result[group][key] = n
        return true
    end
    for key, range in pairs({ initialDistance = {60, 20000}, minDistance = {30, 20000}, maxDistance = {60, 50000}, maxPan = {0, 3000} }) do
        if not number('map', key, range[1], range[2]) then return nil, 'Limites de mapa inválidos.' end
    end
    result.map.maxDistance=math.max(20000,result.map.maxDistance)
    if result.map.minDistance > result.map.initialDistance or result.map.initialDistance > result.map.maxDistance then return nil, 'Use distância mínima ≤ inicial ≤ máxima.' end
    if type(value.portrait.enabled) ~= 'boolean' then return nil, 'Estado da câmera inválido.' end
    result.portrait = { enabled = value.portrait.enabled }
    for key, range in pairs({ distance = {0.0, 150.0}, side = {-150.0, 150.0}, height = {-150.0, 150.0}, fov = {1.0, 130.0}, transition = {0, 2000} }) do
        if not number('portrait', key, range[1], range[2]) then return nil, 'Ajustes da câmera inválidos.' end
        if key~='transition' then result.portrait[key]=result.portrait[key]+0.0 end
    end
    return result
end

function PauseSettings.apply(value)
    Config.Theme, Config.Map, Config.Portrait = copy(value.theme), copy(value.map), copy(value.portrait)
    Config.ServerName, Config.Subtitle = value.name, value.subtitle
end
