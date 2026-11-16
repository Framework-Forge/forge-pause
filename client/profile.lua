-- GTA profile catalog matching the categories inspected in PLT client/profile.lua.
-- These settings have no writable script native. Never execute profile_* commands.
PauseProfile = {}
local tabs = {
 { id='controller', label='Controle', rows={
 {0,'Modo de mira','targetConfig',{'Assistida completa','Assistida parcial','Livre assistida','Livre'}},
 {2,'Vibração','vibration','bool'},{1,'Inverter visão','invertLook','bool'},
 {12,'Controles em terceira pessoa','controlConfig',{'Padrão','Alternativo','Canhoto','Canhoto alternativo'}},
 {20,'Controles em primeira pessoa','controlConfigFps',{'Padrão','Alternativo','Canhoto','Canhoto alternativo'}},
 {13,'Sensibilidade de mira · terceira pessoa','controllerSensitivity',14},{14,'Sensibilidade de visão · terceira pessoa','lookAroundSensitivity',14},
 {233,'Sensibilidade de mira · primeira pessoa','fpsAimSensitivity',14},{232,'Sensibilidade de visão · primeira pessoa','fpsLookSensitivity',14},
 {240,'Zona morta · terceira pessoa','aimDeadzone',14},{238,'Zona morta · primeira pessoa','fpsAimDeadzone',14},
 {241,'Aceleração · terceira pessoa','aimAcceleration',14},{239,'Aceleração · primeira pessoa','fpsAimAcceleration',14} } },
 { id='keys', label='Teclado / mouse', rows={
 {754,'Sensibilidade do mouse','mouseOnFootScale',14},{758,'Modo de mira','kbmToggleAim',{'Segurar','Alternar'}},
 {15,'Inverter mouse','invertMouse','bool'},{750,'Método de entrada','mouseType',{'Raw Input','DirectInput'}},
 {755,'Sensibilidade em carros','mouseDrivingScale',14},{756,'Sensibilidade em aviões','mousePlaneScale',14},
 {757,'Sensibilidade em helicópteros','mouseHeliScale',14},{760,'Sensibilidade em submarinos','mouseSubScale',14},
 {21,'Inverter mouse em voo','invertMouseFlying','bool'},{22,'Inverter mouse em submarinos','invertMouseSub','bool'},
 {23,'Centralizar mouse em carros','mouseAutocenterCar','bool'},{24,'Centralizar mouse em motos','mouseAutocenterBike','bool'},
 {25,'Centralizar mouse em aeronaves','mouseAutocenterPlane','bool'} } },
 { id='audio', label='Áudio', rows={
 {300,'Volume dos efeitos','sfxVolume',10},{306,'Volume da música','musicVolume',10},{308,'Diálogos','diagBoost',10},
 {318,'Silenciar ao perder foco','audioMuteOnFocusLoss','bool'},{317,'Busca automática de músicas','urAutoscan','bool'} } },
 { id='camera', label='Câmera', rows={
 {231,'Campo de visão em primeira pessoa','fpsFieldOfView',10},{220,'Altura da câmera do veículo','cameraHeight',{'Baixa','Alta'}},
 {230,'Câmeras independentes','fpsPersistantView','bool'},{234,'Ragdoll em primeira pessoa','fpsRagdoll','bool'},
 {235,'Rolamento em primeira pessoa','fpsCombatroll','bool'},{236,'Movimento da cabeça','fpsHeadbob','bool'},
 {237,'Terceira pessoa em cobertura','fpsThirdPersonCover','bool'},{242,'Nivelar câmera automaticamente','fpsAutoLevel','bool'},
 {243,'Câmera do capô','hoodCamera','bool'},{244,'Centralizar câmera do veículo','fpsVehAutoCenter','bool'} } },
 { id='display', label='Tela', rows={
 {204,'Radar do perfil','radarMode','bool'},{205,'HUD do perfil','displayHud','bool'},{207,'GPS do perfil','displayGps','bool'},
 {221,'Radar ampliado do perfil','bigRadar','bool'},{203,'Legendas','subtitles','bool'},{226,'Efeitos de eliminações','skfx','bool'},
 {227,'Unidades de medida','measurementSystem',{'Métrico','Imperial'}},{202,'Área segura','safezoneSize',10},{415,'Tamanho da mira do perfil','reticuleSize',10} } },
 { id='graphics', label='Gráficos', rows={{213,'Brilho do perfil','gamma',30}} }
}
function PauseProfile.read()
 local result = {}
 for _, tab in ipairs(tabs) do
  local rows = {}
  for _, row in ipairs(tab.rows) do
   local value = GetConvarInt('profile_' .. row[3], -999)
   if value == -999 then value = GetProfileSetting(row[1]) end
   local formatted = value
   if row[4] == 'bool' then formatted = value == 0 and 'Desativado' or 'Ativado'
   elseif type(row[4]) == 'table' then formatted = row[4][value + 1] or tostring(value) end
   rows[#rows+1] = { id=row[1], label=row[2], value=value, formatted=formatted, max=type(row[4])=='number' and row[4] or nil, kind=type(row[4])=='number' and 'slider' or 'value' }
  end
  result[tab.id] = rows
 end
 return result
end
