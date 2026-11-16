# Forge Pause

## Estilo das configurações

Linhas compactas e abas retangulares inspiradas na referência Pluto, com superfícies e cores Forge. Controles de faixa usam 20 segmentos; preservam arraste, clique e teclado do input range. O painel de detalhes acompanha o valor e mostra os segmentos correspondentes. Valores de perfil com escala disponível também recebem medidor de consulta.

Opções protegidas mostram **Alterar nas configurações do GTA** (também Enter na linha). O botão abre a aba Configurações nativa, sem executar comandos `profile_*`; escolha a categoria correspondente no GTA. Ao sair, o pause retorna à mesma aba Forge e consulta os valores atualizados. Só abre por ação explícita do jogador.

No menu principal, os cartões de saldo têm colunas com largura limitada e ajustam o tamanho do texto para valores altos, sem rolagem horizontal nem cortar o saldo.

Veículos com vidros quebrados próximos: antes do isolamento 3D, o cliente verifica veículos até 80 metros. Se detectar vidro lateral quebrado, mantém o bucket atual para evitar recriar o veículo ao retornar e reproduzir novamente o áudio de quebra. Não conserta, quebra nem silencia veículos. O clima local continua funcionando. Essa correção precisa ser validada no jogo com o caso relatado; testes simulados só verificam a decisão de preservar o bucket.

## Interações e alcance do mapa

O 3D permite deslocamento por toda a área de San Andreas, sem raio lateral centrado no personagem. O zoom máximo mínimo é 20.000 (configurável até 50.000); valores antigos menores são migrados. O botão direito gira horizontalmente e inclina verticalmente entre 20 e 89 graus. A distância usa passos proporcionais para navegar em grandes escalas.

Duplo clique no mesmo ícone marca/desmarca a rota, nos dois mapas. A seleção simples mostra detalhes no painel e um pop-up ancorado ao ícone. O cursor do 2D muda ao passar sobre um blip. O agrupamento por sprite pode ser desativado; grupos com vários locais têm setas para percorrer os endereços. A rolagem usa a cor de destaque do tema Forge e trilho transparente.

O marcador tenta obter o rosto do personagem com uma textura de ped headshot; na indisponibilidade mantém o marcador padrão. O handle é liberado ao fechar. Na saída do 3D, o foco de streaming e a solicitação de colisão voltam ao personagem antes da troca para a câmera normal. O som de vidro perto de veículos requer validação dentro do jogo; os testes locais não reproduzem áudio/física de veículos.

## Mapa em tela inteira e integração da cidade

O mapa agora ocupa a tela inteira, sem a moldura anterior e sem o painel de botões de movimento. Os controles são mouse/roda/botão direito. Há uma lista lateral de blips ordenada por distância, busca, filtros por categoria persistidos localmente, detalhes e ação para traçar rota. Ícones 2D e ícones projetados no mundo 3D podem ser selecionados. Os filtros controlam a NUI do pause, sem remover blips de outros recursos.

Nomes e categorias vêm do catálogo de sprites da referência, com nomes comuns traduzidos. A área é lida do jogo. Isso identifica o tipo de ícone, não necessariamente o nome personalizado atribuído por cada recurso; o GTA não fornece um getter genérico para todos esses nomes. Rotas viárias da NUI também são enviadas para desenhar no mundo 3D.

O pause usa `forge-hud:SuspendHud()` e `ResumeHud()` ao abrir/fechar, preservando a ocultação por outros recursos. O 3D usa `pr_lib.weather.ToggleSync` com o Renewed-Weathersync instalado para suspender apenas a sincronização local e limpar chuva/nuvens. **Automático**, padrão ao abrir o mapa, acompanha o horário atual do jogo por `pr_lib.weather.GetSnapshot`, inclusive mudanças de hora e congelamento do relógio. **Dia** e **Noite** são prévias locais às 13h e 0h: não alteram o horário do servidor. Voltar para Automático retoma o horário atual, e sair do mapa restaura a sincronização anterior. Se outro recurso já suspendeu o clima local, o Pause não assume esse controle. Não são alterados os exports globais de clima/horário. Nesta versão do Renewed não há export de clima por bucket; a integração é local ao jogador.

A pé, o servidor reserva um bucket vazio e sem população para a sessão 3D, guardando o bucket original (que pode ser diferente de zero). A saída, parada do recurso ou expiração da sessão restaura esse bucket, desde que outro recurso não tenha movido o jogador depois. Tokens evitam que a saída atrasada de uma sessão feche uma nova. Em veículos, preserva o bucket e o veículo para não separar passageiros; aplica somente a vista e o clima local. Testes adicionais: `environment-test.lua` e `instance-test.lua`. A aparência no jogo ainda requer validação real.

Ao encerrar o 3D, o Pause reativa a sincronização e reaplica explicitamente o horário, a velocidade do relógio/congelamento e o clima regional atuais obtidos pelo provider Renewed via PR Bridge. Isso não depende de `ToggleSync(true)` disparar novamente seus eventos quando o estado já era `true`. O servidor confirma o retorno do bucket e o cliente confere o estado uma segunda vez; respostas antigas não afetam um mapa reaberto. A iluminação escolhida no mapa nunca altera o relógio global do servidor.

## Mapas: dois modos

O administrador escolhe apenas **mapa 2D original** ou **3D**. Valores antigos `image` são migrados para `gta`. O mapa 2D carrega ícones de `web/assets/blips`, consulta sprites de 0 a 965 e usa `GetBlipInfoIdCoord`. Ícones sem asset usam um ponto como alternativa. A marcação por duplo clique define o waypoint do jogo e calcula uma rota viária na NUI com o grafo `roads.bin` fornecido na referência PLT. O traçado é uma rota calculada pelo recurso, não uma cópia exata do GPS nativo; pontos desconectados do grafo mostram rota indisponível. A rota usa a posição consultada ao abrir o mapa.

O 3D aplica um timecycle próprio para remover a neblina de altitude, aumenta LOD durante a visualização e restaura o filtro do jogador e o foco ao sair. Clima local e isolamento seguem a integração descrita acima. Não teleporta. Aparência e streaming precisam ser validados no FiveM. Testes adicionais: `roads-test.cjs` e `map-test.lua`.

## Configurações ampliadas (referência PLT)

A tela de configurações agora usa um workspace com 12 abas: Controle, Teclas/mouse, Áudio, Câmera, Tela, Gráficos, Predefinições, Jogo, Voz/rádio, HUD/mira, Filtros e Interface. A lista apresenta os controles e o painel lateral descreve o ajuste selecionado. As abas também aceitam setas, Home e End.

O catálogo de perfil reproduz as 51 opções consultadas pelo PLT: 13 de controle, 13 de teclado/mouse, 5 de áudio, 10 de câmera, 9 de tela e 1 de gráficos. Lê primeiro a variável ativa `profile_*`, usando `GetProfileSetting` como alternativa. Valores são atualizados enquanto a tela está aberta. Isso é paridade de consulta com o catálogo da base, não acesso de escrita aos ajustes protegidos.

Novos controles locais: sombras de cenário, limpeza periódica de marcas/vidros, exposição por timecycle extra, mira em ponto/cruz/original/oculta, ocultação de HUD/radar por quadro, volume de cliques do rádio (quando o export existe) e quatro predefinições de gráficos. Exposição local não altera o gamma salvo do GTA; pode disputar o canal de timecycle extra com outros efeitos. Sombras e orçamento de modelos são ajustes de script, não configuração da placa de vídeo. GPS original permanece consultável; não há controle falso para gravar o perfil GPS.

A captura do PLT enviada pelo usuário mostra a mensagem de que scripts não podem alterar certos perfis e o botão para editar no GTA. Esta implementação mantém a restrição visível e não abre o GTA automaticamente. Não substitui integralmente configurações de GPU, resolução, teclas, mouse ou áudio global do jogo. O vídeo remoto não pôde ser carregado pelo navegador de pesquisa; a implementação foi comparada aos arquivos locais e às capturas.

O layout abre com o cenário do jogo visível, navegação compacta à esquerda e câmera voltada ao rosto do personagem. `Config.Portrait` permite ajustar distância, deslocamento lateral, altura, campo de visão e duração da entrada. Em veículos ou com outra câmera de script ativa, preserva a câmera existente. Não força animação nem reposiciona o personagem. Ao entrar no mapa 3D, a câmera de retrato dá lugar à câmera do mapa; ao voltar, o retrato é recriado. Botões têm animações de destaque, movimento e ícones, respeitando a preferência de movimento reduzido do sistema.

As configurações usam navegação hierárquica no próprio canto esquerdo. As categorias substituem a navegação inicial; ESC e Voltar sobem um nível, e ESC na raiz fecha o pause. Informações e regras usam o mesmo espaço. O mapa encerra a câmera de retrato: no modo GTA, abre diretamente o mapa original, sem cartão intermediário; imagem e 3D usam a área principal do cenário.

Menu de pausa independente, com identidade visual baseada nos tokens e padrões do [Forge UI Kit](https://github.com/Framework-Forge/site/blob/main/src/index.css). Consome os dados do personagem exclusivamente por `pr_lib.framework`, carregado por `@pr_bridge/init.lua`. Não requer banco de dados.

## Instalação

1. Inicie o core e `pr_bridge` antes de `forge-pause`.
2. Desative qualquer outro recurso que intercepte ESC, incluindo o `plt_pausemenu` de referência.
3. Adicione `ensure forge-pause` à configuração do servidor após `ensure pr_bridge`.
4. Entre com um personagem e pressione ESC ou use `/forgepause`.

A pasta `[plt_pausemenu]` é referência e não é carregada pelo manifesto novo. Não use `ensure [plt_pausemenu]` junto com o Forge Pause. A configuração do servidor não foi alterada automaticamente.

## Configuração do administrador

Use **Administração** no próprio Pause ou `/pauseadmin`. Todas as configurações administrativas ficam na NUI do Forge Pause: **Geral e mapa**, **Cores do layout**, **Câmera**, **Ícones do catálogo** e **Blips e zonas**. O comando e a entrada pelo Forge Core abrem a mesma interface; os antigos menus de contexto administrativos não são mais carregados pelo manifest. As integrações de callback, persistência, permissões e catálogo de cores continuam usando o PR Bridge, sem modificá-lo.

Também pode ser aberto pela opção **Forge Pause** no painel principal da **Forge Core**. Nessa abertura, **Voltar ao Admin Forge** fecha a NUI e retorna ao contexto pai pelo mecanismo existente do PR Bridge. `/pauseadmin` continua independente. Outros recursos podem chamar `TriggerEvent('forge-pause:client:openAdminMenu', parentMenu, parentResource)`; a permissão continua sendo conferida pelo servidor em toda gravação.

As cores mudam imediatamente na interface local. A câmera tem prévia local, com área transparente para ver o personagem. **Salvar configurações para todos** publica os ajustes de layout/mapa/identidade/câmera. Sair com alterações pede confirmação; fechar sem publicar restaura o estado anterior. Se outro administrador publicar durante uma prévia local, a restauração preserva a configuração publicada mais recente.

Coordenadas e ajustes contínuos aceitam a precisão original dos valores, sem exigir arredondamento para salvar. A câmera aceita, por exemplo, altura `0.08`; salvamentos consecutivos continuam editando a versão atual. Campos realmente inválidos são destacados e identificados no aviso, mantendo os limites e as validações do servidor.

Distância aceita **0.0 a 150.0 m**, e deslocamento lateral/altura aceitam **-150.0 a 150.0 m**, preservando ambos os sentidos. Valores inteiros são exibidos com `.0` e convertidos em floats Lua antes das chamadas nativas, inclusive quando o JSON entrega `4`, `10` ou `150` como inteiro. O FOV aceita **1.0° a 130.0°**, limite real da câmera do GTA, e a transição permanece em **0 a 2.000 ms**. Valores que colocariam a câmera dentro da cabeça são rejeitados com aviso.

A prévia mantém a mesma câmera durante os ajustes e aplica distância/altura em metros em relação à cabeça, sem reiniciar a transição a cada alteração. A transição configurada é usada ao abrir o Pause; a prévia administrativa é imediata. O raycast existente do PR Bridge verifica paredes, veículos e objetos; se a distância precisar ser reduzida, o painel informa o valor efetivo sem modificar o solicitado. Se não houver espaço mínimo, a prévia é encerrada com aviso, em vez de posicionar a câmera dentro do personagem ou da parede. O painel de controles fica compacto à esquerda para liberar o enquadramento central. Aparência e colisões específicas de cada MLO ainda exigem verificação no FiveM.

Conceda acesso ao grupo administrativo no `server.cfg`:

```cfg
add_ace group.admin forge.pause.admin allow
```

O jogador deve pertencer ao grupo indicado. A permissão é verificada no servidor para abrir e salvar, e pode ser alterada em `Config.Admin.ace`. Administradores que já têm `forge-core.admin` também são aceitos por `Config.Admin.inheritAce`; defina esse campo como `false` se quiser exigir apenas a permissão específica. A regra foi adicionada ao `permissions.cfg` existente. O comando pode ser alterado em `Config.Admin.command`. Há também um botão Administração na raiz do pause para usuários autorizados. Não é necessário reiniciar para aplicar mudanças pelo menu.

Os valores salvos em `admin-settings.json` têm prioridade sobre `config.lua` e são sincronizados com todos os jogadores, inclusive ao entrarem. O arquivo é criado pelo servidor no primeiro salvamento e não é enviado como asset NUI. **Restaurar padrão Forge** prepara os valores de `config.lua`; confirme em Salvar para persistir. Regras, links e filtros continuam em `config.lua`.

Valores iniciais e opções de configuração:

- `Config.Theme`: cores de destaque, fundos, bordas e textos. Use cores hexadecimais de seis dígitos. Não existe seletor de cores para o jogador.
- `Config.Map.mode = 'gta'`: abre o mapa original, com blips e GPS do GTA.
- `Config.Map.mode = 'image'`: mostra `Config.Map.image`. Uma imagem da base fornecida foi copiada para `web/assets/map.webp`; substitua-a pela imagem da sua cidade quando necessário. A imagem é ilustrativa; o botão de GPS abre o mapa nativo.
- `Config.Map.mode = '3d'`: câmera orbital sobre os arredores do personagem, com deslocamento, zoom e rotação por botões. Limites em `Config.Map`.
- `Config.ServerName`, `Subtitle`, `Rules` e `Links`: identidade, regras e links HTTPS da cidade.
- `Config.Filters`: lista permitida de filtros visuais.

O jogador pode ajustar escala, filtro e intensidade. Essas preferências são salvas por computador em KVP do FiveM. Tema e modo de mapa sempre vêm da configuração do administrador.

## Catálogo administrativo de ícones

No painel administrativo, abra **Ícones do catálogo**. O catálogo original contém 927 modelos, com miniaturas, ID/código e dados no hover. O painel lateral permite editar ou duplicar o modelo selecionado. Há paginação, busca por ID/nome/categoria em todo o catálogo e filtros para ativos, personalizados e ocultos.

Ao clicar em um modelo, é possível editar nome/categoria, substituir a imagem, criar outro modelo usando a mesma imagem, excluir/ocultar e restaurar. O campo de imagem aceita:

- Um arquivo local: `assets/blips/meu-icone.png` (também JPG, JPEG e WEBP).
- Uma URL HTTPS direta para uma imagem.
- O ID de outro modelo do catálogo: por exemplo, `108` copia sua imagem atual.

Arquivos locais novos devem estar presentes em `web/assets/blips` e disponíveis no pacote do recurso carregado pelos clientes. URLs HTTPS e referências a imagens já disponíveis podem ser trocadas pelo menu sem reiniciar. O formulário não envia arquivos do computador ao servidor.

As personalizações são gravadas separadamente em `blip-models.json`, criado no primeiro salvamento pelo administrador, e sincronizadas para quem está conectado ou entrar depois. Cada confirmação no submenu salva o modelo imediatamente; o botão geral **Salvar e aplicar para todos** continua reservado às configurações de layout/mapa/câmera. **Fechar sem salvar** não desfaz modelos já confirmados. Permissões são verificadas no servidor, com controle de versão para evitar que um administrador sobrescreva uma edição mais recente de outro.

Excluir oculta aquele ID no mapa 2D/3D e na lista lateral do Forge Pause. Nenhum PNG original é apagado. O filtro **Excluídos** permite restaurar; para modelos originais, restaurar também remove as personalizações e recupera os dados do GTA.

O catálogo cadastra imagens, não coordenadas. Para criar pontos com esses modelos, use **Blips criados no mapa**, descrito abaixo. As substituições de imagem continuam restritas ao Forge Pause e não modificam sprites nativos de outros recursos.

## Criador administrativo de blips

No mesmo painel administrativo, abra **Blips e zonas → Criar blip**. A lista de pontos, os controles e o mapa ficam lado a lado. O ponto começa como rascunho na posição do administrador. É possível:

- Escolher o ícone no catálogo existente, com as mesmas imagens, metadados, busca e paginação. Modelos ocultos não podem ser selecionados.
- Informar nome e categoria próprios do ponto, sem renomear outros locais que usam o mesmo ícone.
- Usar a posição atual, um destino já marcado no GPS ou coordenadas exatas X/Y/Z. Ao usar GPS, o editor altera X/Y, mantém a altura Z anterior e avisa para confirmá-la manualmente, especialmente em interiores.
- Clicar no mapa ou arrastar o ícone para definir X/Y. Arrastar o fundo move a visualização, a roda ajusta zoom e as setas no mapa movem o blip em 0,1 metro (Shift: 1 metro). A altura Z não é adivinhada ao mover pelo mapa: ajuste-a para o andar/interior correto.
- Ajustar tamanho, opacidade e rotação com prévia imediata, além de cor GTA, curto alcance, piscar, ativação e exibição do ponto no mapa/minimapa.
- Em **Posição visual no mapa 3D**, usar **Colar ao chão** (padrão) e ajustar a altura visual de -150 a 150 m. O padrão é 0,15 m acima do terreno. Desativar o encaixe usa o Z salvo, para helipontos/andares; não altera as coordenadas do radar.
- Escolher a cor do blip e da zona em um catálogo visual, com amostra, nome, ID, código hexadecimal e busca. A paleta usa os dados existentes do PR Bridge; a escolha só é publicada ao salvar o ponto.
- Criar círculo por raio ou retângulo por largura/altura, com rotação, cor e opacidade independentes. A zona acompanha o blip em metros e é pré-visualizada no mapa em tempo real.
- Ver uma prévia nativa somente para o administrador enquanto edita, sem publicar ou salvar. O rascunho também permanece visível no mapa do editor quando o blip está desativado, transparente ou configurado só para o minimapa.
- Editar, duplicar como rascunho, marcar rota, ativar/desativar e excluir pontos existentes.

**Salvar e publicar** confirma imediatamente para todos os jogadores. Fechar ou descartar o rascunho não publica suas alterações. Excluir pede confirmação e remove apenas o ponto e sua zona, nunca a imagem do catálogo ou blips criados por outros recursos. As zonas são áreas visuais do mapa: não alteram dano, colisão, Safe Zones ou despacho. A zona publicada aparece no radar nativo e nos mapas 2D/3D do Pause, respeitando o modo de exibição do ponto.

Os pontos são salvos em **`world-blips.json`**, separado das imagens e das configurações de layout. O arquivo é criado no primeiro salvamento real. A sincronização atende jogadores conectados e novos jogadores; o mapa Forge aberto também é atualizado. Há verificação administrativa no servidor, limite de 500 pontos, validação das coordenadas, controle de versão contra edições concorrentes e preservação do estado anterior quando o salvamento falha. Arquivo inválido bloqueia novas gravações para evitar sobrescrever dados danificados.

Salvar pontos e zonas não publica configurações gerais nem altera o mapa 2D/3D escolhido. O painel sincroniza o modo publicado ao abrir e após salvar configurações gerais; a prévia de câmera altera somente o retrato local, sem aplicar seu rascunho de mapa ao jogo.

No mapa 2D/3D do Forge Pause, o ponto usa a imagem do modelo escolhido, inclusive modelos adicionais até o ID 65535. No radar/minimapa nativo, usa **Sprite GTA no minimapa nativo** (IDs 0 a 965). Ao escolher um modelo GTA, esse campo acompanha o ID; para um modelo adicional, escolha um sprite nativo equivalente em Aparência. Imagens personalizadas não substituem o atlas global do GTA. Isso preserva os ícones de outros recursos e dispensa os arquivos `minimap.gfx`/`minimap.ytd` do exemplo.

Ocultar um modelo do catálogo suspende os pontos vinculados a ele sem apagar os registros. Restaurar o modelo reativa os pontos que continuam habilitados. Parar o Forge Pause remove apenas seus próprios handles e prévias.

A pasta `[extracao]` foi consultada somente como referência do fluxo. Seu script, sua interface, seus comandos, suas permissões abertas e seu mecanismo de substituição de texturas não são carregados pelo manifest do Forge Pause.

## Blips de outros recursos (exports)

Use `RegisterMapBlip`, `UpdateMapBlip`, `RemoveMapBlip` e `ClearMapBlips` no cliente ou servidor. No cliente, os pontos aparecem apenas para aquele jogador; no servidor, são sincronizados com todos, inclusive novos jogadores. Os modelos e imagens vêm do mesmo catálogo administrativo.

Esses pontos são temporários, pertencem ao recurso que os registrou e não entram em `world-blips.json`. Parar o recurso de origem limpa seus pontos. A API não cria nem remove blips nativos: se o script já possui um, o export do cliente aceita `blip=handle` para evitar duplicidade no mapa Forge, sem tomar controle do radar. Confira exemplos completos, campos, limites e reinicialização em [MAP_BLIPS_API.md](MAP_BLIPS_API.md).

Os ícones do 3D agora usam altura do terreno, não uma altura herdada do administrador em cima de um prédio. Uma consulta em cache do heightmap atende locais distantes, e a superfície precisa é refinada quando a colisão carrega, sem mover o jogador nem deslocar o foco da câmera. Há limite de consultas por atualização; ao fechar o mapa, o trabalho e o cache são encerrados. Em mapas/interiores personalizados ou locais com vários andares, use o Z manual e o ajuste individual.

## Comportamento e limites

As categorias Interface, Áudio, Câmera, Gráficos, Tela e Teclas ficam na UI Forge. Controles funcionais: escala, filtro e intensidade, volumes de rádio/chamadas do pma-voice (quando iniciado), desligamento do rádio de veículos, visão a pé/veículo, distância de detalhes, luzes distantes, orçamento de modelos, HUD nativo, radar e radar ampliado. As alterações são locais e persistem em KVP.

Limite confirmado na base PLT (`client/profile.lua` e `client/keys.lua`): resolução, texturas/MSAA, volumes globais do GTA, sensibilidade e remapeamento das teclas originais não podem ser gravados por scripts. Seus valores disponíveis aparecem como consulta, sem controles que finjam alterá-los. Nenhuma opção de configuração encaminha ao menu nativo. Isso não equivale a substituir todos os ajustes internos do GTA. HUDs NUI externos continuam sob responsabilidade de seus próprios recursos.

O modo GTA agora é um mapa 2D interativo dentro da NUI Forge, usando o asset e a projeção de coordenadas da base PLT. Não abre o frontend nem as abas do GTA. Arraste para mover, use a roda para zoom e duplo clique para definir GPS; o ponto laranja representa o personagem e pontos claros representam blips ativos consultados ao abrir. Não é uma captura do radar nativo: ícones e rotas completos ainda não são reproduzidos. O modo imagem mantém a imagem administrativa como ilustração.

No modo 3D, arraste para mover, use a roda para zoom e arraste com o botão direito para girar. O foco de streaming acompanha a região observada e é restaurado ao sair. Os botões também continuam disponíveis. A renderização 3D vem da câmera do jogo atrás da NUI, como na base PLT; não é uma textura recortada dentro do painel.

O modo 3D usa o mundo real e mantém o streaming na região observada pela câmera. Não teleporta. O isolamento e o clima local seguem a seção de integração acima; regiões distantes podem aparecer com menos detalhes. A câmera é encerrada ao sair da aba, fechar o menu, morrer ou parar o recurso.

Os filtros de imagem usam o timecycle do jogo e podem disputar esse efeito com outros scripts. Se sua cidade já controla os filtros, mantenha apenas a opção `none` em `Config.Filters`. As fontes do UI Kit vêm do Google Fonts, com fontes locais de sistema como alternativa offline.

## Verificação

Há prévia no navegador ao abrir `web/index.html`; os dados de exemplo só aparecem fora do FiveM. Testes locais: `verify.cjs` (navegador), `admin-test.lua`, `options-test.lua` e `navigation-test.lua` (Lua com fronteiras FiveM simuladas). Antes de colocar em produção, valide no servidor: submenus e ESC, acesso de admin/usuário comum, mapa GTA direto e retorno, imagem/3D, controles de voz, câmeras, persistência, troca de personagem e parada do recurso.

O script de referência permanece intacto. Confirme a licença dos assets fornecidos antes de redistribuir a imagem copiada da base.
