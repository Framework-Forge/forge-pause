-- Shared catalog schema. Original assets are immutable; edits are overlays.
PauseBlips = { base = {}, maxId = 65535, maxOverrides = 2048 }
local known = {
    [52] = {'Loja','Lojas'}, [361] = {'Posto de combustível','Postos'},
    [60] = {'Polícia','Serviços'}, [61] = {'Hospital','Serviços'}, [357] = {'Garagem','Transporte'},
    [50] = {'Oficina','Serviços'}, [73] = {'Loja de roupas','Lojas'}, [71] = {'Barbearia','Lojas'},
    [110] = {'Ammu-Nation','Lojas'}, [108] = {'Banco','Serviços'},
}

function PauseBlips.id(value)
    if type(value) ~= 'number' and type(value) ~= 'string' then return end
    local n = tonumber(value)
    if not n or n ~= n or n < 0 or n > PauseBlips.maxId or n % 1 ~= 0 then return end
    return ('%.0f'):format(n)
end

function PauseBlips.image(value)
    if type(value) ~= 'string' or #value > 512 or value:find('[%c%s\\]') then return end
    if value:match('^assets/blips/[%w_%.%-]+$') and not value:find('..', 1, true) then
        local ext = value:match('%.(%w+)$')
        if ext == 'png' or ext == 'webp' or ext == 'jpg' or ext == 'jpeg' then return value end
    end
    local host = value:match('^https://([^/%?#]+)')
    if host and host:match('^[%w%.:%-]+$') and host:find('%w') then return value end
end

function PauseBlips.validate(value)
    if type(value) ~= 'table' then return nil, 'Modelo inválido.' end
    local result = {}
    for _, field in ipairs({'name','group'}) do
        local text = value[field]
        if type(text) ~= 'string' or #text < 1 or #text > 100 or text:find('%c') or not text:find('%S') then
            return nil, 'Nome e categoria devem ter de 1 a 100 caracteres.'
        end
        result[field] = text
    end
    result.image = PauseBlips.image(value.image)
    if not result.image then return nil, 'Use assets/blips/arquivo.png (PNG/JPG/WEBP) ou uma URL HTTPS válida.' end
    if value.disabled ~= nil and type(value.disabled) ~= 'boolean' then return nil, 'Estado do modelo inválido.' end
    result.disabled = value.disabled == true
    return result
end

local raw = LoadResourceFile(GetCurrentResourceName(), 'web/assets/blips.json')
local ok, catalog = pcall(json.decode, raw or '')
if ok and type(catalog) == 'table' then
    for key, info in pairs(catalog.blips or {}) do
        local id = PauseBlips.id(key)
        if id and type(info) == 'table' then
            local names = known[tonumber(id)] or info
            PauseBlips.base[id] = {name = names[1], group = names[2], image = 'assets/blips/' .. id .. '.png', disabled = false}
        end
    end
end

function PauseBlips.model(id, overrides)
    id = PauseBlips.id(id)
    if not id then return end
    local original, edited = PauseBlips.base[id], (overrides or {})[id]
    if not original and not edited then return end
    local result = PauseSettings.copy(edited or original)
    result.id, result.original, result.edited = id, original ~= nil, edited ~= nil
    return result
end

function PauseBlips.list(overrides)
    local ids, rows = {}, {}
    for id in pairs(PauseBlips.base) do ids[id] = true end
    for id in pairs(overrides or {}) do ids[id] = true end
    for id in pairs(ids) do rows[#rows + 1] = PauseBlips.model(id, overrides) end
    table.sort(rows, function(a,b) return tonumber(a.id) < tonumber(b.id) end)
    return rows
end
