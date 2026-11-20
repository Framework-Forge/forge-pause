Config = {}
Config.VersionCheck = true

-- Configuração do administrador. Nenhuma cor ou modo de mapa é salvo pelo jogador.
Config.ServerName = 'FORGE ROLEPLAY'
Config.Subtitle = 'Sua história começa aqui.'
Config.Command = 'forgepause'
Config.Admin = { command = 'pauseadmin', ace = 'forge.pause.admin', inheritAce = 'forge-core.admin' }
Config.Portrait = {
    -- Metros: distance 0.0..150.0, side/height -150.0..150.0.
    -- FOV: 1.0..130.0 graus (limite do GTA); transition: 0..2000 ms.
    enabled = true,
    distance = 1.25,
    side = 0.35,
    height = 0.08,
    fov = 42.0,
    transition = 450
}
Config.Theme = {
    accent = '#FF7A1A', background = '#0A0A0C', panel = '#121214',
    card = '#18181C', border = '#1F1F24', text = '#FFFFFF', muted = '#8E8E9F'
}
Config.Map = {
    mode = 'gta', -- 'gta': mapa 2D interativo | '3d': câmera sobre o mundo
    image = 'assets/map.webp', -- arquivo local incluído em web/assets
    initialDistance = 350.0,
    minDistance = 80.0,
    maxDistance = 20000.0,
    maxPan = 1200.0 -- limita a câmera à região do personagem
}
Config.Links = {
    { label = 'Documentação Forge', url = 'https://framework-forge.github.io/site/' }
}
Config.Rules = {
    'Respeite os outros jogadores e a equipe.',
    'Mantenha o roleplay e siga as regras da cidade.',
    'Personalize este texto em config.lua com as regras do seu servidor.'
}
-- Os filtros são as únicas opções de visual aplicadas por este recurso.
-- Evite filtros que conflitem com recursos de drogas, clima ou cinematografia.
Config.Filters = {
    { label = 'Original', value = 'none' },
    { label = 'Cinema', value = 'cinema' },
    { label = 'Contraste', value = 'rply_contrast' },
    { label = 'Cores vivas', value = 'rply_saturation' },
    { label = 'Claro', value = 'rply_brightness' },
    { label = 'Vinheta', value = 'rply_vignette' }
}
