# API de pontos do mapa Forge Pause

Os quatro exports estão disponíveis no **cliente e no servidor**. Requer `forge-pause` iniciado. Eles usam o catálogo de ícones do painel administrativo e atualizam o mapa 2D/3D e sua lista de locais, inclusive enquanto o mapa está aberto.

| Export | Uso | Retorno |
| --- | --- | --- |
| `RegisterMapBlip(id, dados)` | Registra ou substitui um ponto do recurso chamador. | `true` ou `false, motivo` |
| `UpdateMapBlip(id, alterações)` | Atualiza apenas os campos informados de um ponto já registrado. | `true` ou `false, motivo` |
| `RemoveMapBlip(id)` | Remove um ponto do recurso chamador. | `true` ou `false, motivo` |
| `ClearMapBlips()` | Remove todos os pontos do recurso chamador naquele lado (cliente/servidor). | `true` ou `false, motivo` |

IDs são strings de 1 a 64 caracteres: letras, números, `_`, `-`, `.`, `:` (começando por letra, número, `_` ou `-`). Dois recursos podem usar o mesmo ID sem conflito. Um recurso não altera os registros de outro.

## Exemplo no servidor: aparece para todos

No `fxmanifest.lua` do recurso de origem:

```lua
dependency 'forge-pause'
```

No `server.lua` desse recurso:

```lua
local function registerLocations()
    local ok, reason = exports['forge-pause']:RegisterMapBlip('delegacia', {
        name = 'Delegacia Central',
        group = 'Serviços',
        model = 60, -- ID do catálogo; também aceita sprite = 60
        coords = vector3(441.2, -981.9, 30.7),
        scale = 0.9,
        mapGround = true,
        mapOffset = 0.15,
    })
    if not ok then print(('Blip da delegacia: %s'):format(reason)) end
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == 'forge-pause' then
        -- O Pause registra seus exports no primeiro tick do recurso.
        SetTimeout(250, registerLocations)
    end
end)

-- Em uma ação posterior:
-- exports['forge-pause']:UpdateMapBlip('delegacia', {name = 'Plantão policial'})
-- exports['forge-pause']:UpdateMapBlip('delegacia', {enabled = false})
-- exports['forge-pause']:RemoveMapBlip('delegacia')
-- exports['forge-pause']:ClearMapBlips()
```

A origem registra novamente seus pontos quando o próprio recurso ou o Pause reinicia. O servidor envia o estado atual para novos jogadores; não é necessário um loop de publicação. Os exports não gravam arquivos.

## Exemplo no cliente: ponto privado ou blip nativo existente

Use cliente **ou** servidor para cada ponto. Registrar o mesmo local nos dois lados cria dois registros intencionais. Se o recurso já tem um blip nativo, associe-o no cliente para o Forge não importar uma segunda cópia:

```lua
local nativeBlip = AddBlipForCoord(441.2, -981.9, 30.7)
SetBlipSprite(nativeBlip, 60)

local ok, reason = exports['forge-pause']:RegisterMapBlip('delegacia', {
    name = 'Delegacia Central',
    group = 'Serviços',
    model = 60,
    coords = vector3(441.2, -981.9, 30.7),
    blip = nativeBlip, -- opcional, somente cliente
})
if not ok then print(reason) end

-- Atualize explicitamente quando o ponto mudar; não precisa chamar a cada frame.
-- exports['forge-pause']:UpdateMapBlip('delegacia', {
--     coords = vector3(450.0, -980.0, 30.0),
-- })
```

O handle continua pertencendo ao recurso chamador. O Pause nunca chama `RemoveBlip` nele. Para desfazer só a associação, use `UpdateMapBlip(id, {blip=false})`; remover o registro também encerra a associação, e o blip nativo volta à importação automática normal do Pause. O script original ainda é responsável por remover seu próprio blip do jogo. Se não houver blip nativo, omita `blip`: o ponto aparecerá apenas no mapa Forge, sem criar outro ícone no radar.

## Campos

- `coords` ou `pos`: `vector3`, `vector4` ou `{x=..., y=..., z=...}`. Obrigatório no registro. Atualizações podem informar só um eixo; os demais são preservados.
- `model` ou `sprite`: ID numérico ou string do catálogo (0 a 65535); padrão `1`. O modelo precisa existir e estar ativo ao registrar/atualizar. As imagens personalizadas do catálogo são respeitadas.
- `name`, `group`: nome e categoria, de 1 a 100 caracteres. Padrões: `Novo local` e `Outros`.
- `scale`: 0.1 a 10; padrão 0.9. `alpha`: 0 a 255; padrão 255. `rotation`: inteiro de 0 a 359; padrão 0.
- `enabled`: padrão `true`. `display`: `2` (mapa e minimapa), `3` (mapa), `5` (minimapa). Como a API não cria radar nativo, `5` apenas exclui o ponto do mapa Forge.
- `mapGround`: padrão `true`, encaixa no terreno do 3D. `mapOffset`: -150 a 150 metros, padrão `0.15`. Com `mapGround=false`, aplica o deslocamento ao Z informado. Não muda as coordenadas originais, o radar ou o 2D.
- `color`: ID de cor GTA (0 a 85); as imagens do catálogo mantêm suas próprias cores. `nativeSprite`, `shortRange` e `flash` são aceitos pelo esquema comum, mas não configuram um handle externo.
- `zone`: área **visual**, sem regras de Safe Zone, colisão, dano ou despacho. Exemplo abaixo.
- `blip`: handle nativo válido, opcional e exclusivo do cliente. Evita importar esse mesmo handle duas vezes; não acompanha suas coordenadas automaticamente. Atualize `coords` quando necessário.

```lua
exports['forge-pause']:UpdateMapBlip('delegacia', {
    zone = {mode = 'radius', radius = 80.0, color = 3, alpha = 90, rotation = 0},
})
-- Retângulo: {mode='area', width=100.0, height=60.0, color=3, alpha=90, rotation=45}
-- Remover área: {zone={mode='none'}}
```

Limites: 128 pontos por recurso e 500 registros externos no servidor; no cliente, os registros locais têm os mesmos limites, separados dos recebidos do servidor. Os blips administrativos continuam com sua própria lista e seu limite de 500. O catálogo pode ocultar um modelo sem apagar os registros; restaurá-lo volta a mostrar os pontos habilitados. Alterações do servidor são agrupadas em intervalos de 100 ms para evitar uma mensagem por registro em lotes.

Ao parar o recurso de origem, seus registros são removidos automaticamente. Ao parar o Pause, todos os registros temporários se perdem e precisam ser registrados novamente. Não há evento de rede para clientes publicarem pontos globais: a escrita global ocorre exclusivamente pelos exports de servidor.

## Altura no mapa 3D

O heightmap fornece uma altura inicial para regiões distantes. Ao carregar a colisão, o mapa refina a superfície com consultas limitadas e em cache, sem mover o jogador nem roubar o foco de streaming. Se nenhuma altura válida estiver disponível, aguarda em vez de desenhar na antiga altura de um telhado; o local continua disponível na lista. Mapas personalizados, túneis e andares podem exigir `mapGround=false` e Z explícito.

Referências oficiais: [consulta de chão e sua limitação de streaming](https://github.com/citizenfx/natives/blob/master/MISC/GetGroundZFor_3dCoord.md), [heightmap do GTA](https://github.com/citizenfx/natives/blob/master/PATHFIND/GetHeightmapBottomZForPosition.md) e [exports Lua](https://docs.fivem.net/docs/scripting-manual/runtimes/lua/).
