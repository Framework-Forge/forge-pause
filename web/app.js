'use strict';
const preview = typeof GetParentResourceName !== 'function';
const resource = preview ? 'forge-pause' : GetParentResourceName();
const $ = id => document.getElementById(id);
let config = {}, preferences = {}, game = {}, player = {}, currentPage = 'home';
const titles = { home: 'Visão geral', profile: 'Seu personagem', settings: 'Configurações', 'settings.interface': 'Interface', 'settings.audio': 'Áudio', 'settings.camera': 'Câmera', 'settings.graphics': 'Gráficos', 'settings.display': 'Tela', 'settings.keys': 'Teclas & mouse', rules: 'Ajuda & regras', map: 'Mapa da cidade' };
Object.assign(titles, { 'settings.controller': 'Controle', 'settings.presets': 'Predefinições', 'settings.game': 'Jogo', 'settings.voice': 'Voz & rádio', 'settings.hud': 'HUD & mira', 'settings.filters': 'Filtros' });
titles.admin='Administração do Forge Pause';
const symbols = { profile: '◈', map: '◎', settings: '⚙', rules: '≡' };
const descriptions = { profile: 'Sua identidade na cidade', map: 'Encontre seu próximo destino', settings: 'Ajuste sua experiência', rules: 'Tudo para viver sua história' };
document.querySelectorAll('nav [data-page]').forEach(button => {
  const name = button.dataset.page;
  button.innerHTML = '<span class="nav-icon" aria-hidden="true">' + symbols[name] + '</span><span><strong>' + titles[name].toUpperCase() + '</strong><small>' + descriptions[name] + '</small></span><b class="nav-arrow">↗</b>';
});
async function post(name, data = {}) {
  if (preview) return { ok: true, preferences: { ...preferences, ...data, options: { ...preferences.options, ...data.options } } };
  const response = await fetch('https://' + resource + '/' + name, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
  if (!response.ok) throw new Error('Falha na comunicação com o jogo.');
  return response.json();
}
function request(name, data) { return post(name, data).catch(() => { $('save-status').textContent = 'Não foi possível concluir a ação. Tente novamente.'; }); }
function text(tag, value, className) { const el = document.createElement(tag); el.textContent = value; if (className) el.className = className; return el; }
function action(label, description, target) {
  const button = document.createElement('button'); button.className = 'sub-action'; button.dataset.page = target;
  button.append(text('strong', label), text('small', description), text('b', '›'));
  button.addEventListener('click', () => page(target)); return button;
}
function readonly(label, value, note, metadata) {
  const row = document.createElement('article'); row.className = 'read-setting';
  if(metadata?.max){row.dataset.value=metadata.value;row.dataset.max=metadata.max;}
  const display=metadata?.max?Math.round(Number(metadata.value)/Number(metadata.max)*100)+'%':value==='Ativado'?'ON':value==='Desativado'?'OFF':String(value);
  row.append(text('strong', label), text('span',display,'read-value'), text('small', note || 'Perfil original do GTA · somente leitura'),text('b','↗','read-arrow'));
  $('submenu').append(row);
}
async function save(key, value, option) {
  const result = await request('preferences', option ? { options: { [key]: value } } : { [key]: value });
  if (result?.ok) { preferences = result.preferences; document.documentElement.style.setProperty('--scale', preferences.scale / 100); $('save-status').textContent = 'Preferências salvas.'; }
}
function control(key, label, kind, values, option = true, disabled = false) {
  const row = document.createElement('article'); row.className = 'stack-setting'; row.dataset.settingKey=key; row.tabIndex=0;
  row.append(text('strong', label));
  const defaults = {shadows:'high',clean:false,hideHud:false,reticle:'gta',click:10,brightness:0};
  let value = option ? (preferences.options?.[key] ?? defaults[key]) : preferences[key];
  const choices = kind === 'select' ? values : null;
  if (choices && !choices.some(([v])=>String(v)===String(value))) value=choices[0][0];
  const controls=document.createElement('div');controls.className='setting-controls';controls.setAttribute('role','group');controls.setAttribute('aria-label',label);
  const previous=text('button','‹','step-arrow');previous.type='button';previous.setAttribute('aria-label','Diminuir '+label);
  const next=text('button','›','step-arrow');next.type='button';next.setAttribute('aria-label','Aumentar '+label);
  previous.disabled=next.disabled=disabled;
  const output=text('button','','step-value');output.type='button';output.disabled=disabled;output.id=kind==='range'?key+'-value':key;
  output.setAttribute('aria-label',label);
  let input,bars;
  if(kind==='range'){
    input=document.createElement('input');input.type='range';[input.min,input.max,input.step]=values;input.value=value;input.id=key;input.disabled=disabled;input.setAttribute('aria-label',label);
    const track=document.createElement('div');track.className='segment-track';
    bars=document.createElement('div');bars.className='segment-bars';bars.setAttribute('aria-hidden','true');
    for(let i=0;i<20;i++)bars.append(document.createElement('i'));
    track.append(bars,input);controls.append(previous,track,output,next);
    output.tabIndex=-1;
  } else {
    if(kind==='checkbox'){output.setAttribute('role','switch');output.setAttribute('aria-checked',String(!!value));}
    controls.append(previous,output,next);
  }
  const suffix=key==='brightness'?'':'%';
  function display(){return choices?choices.find(([v])=>String(v)===String(value))?.[1]||String(value):kind==='checkbox'?(value?'ON':'OFF'):String(value)+suffix;}
  function paint(){
    output.textContent=display();output.dataset.value=String(value);
    if(kind==='checkbox')output.setAttribute('aria-checked',String(!!value));
    if(input){input.value=value;const fraction=(Number(value)-Number(input.min))/(Number(input.max)-Number(input.min));[...bars.children].forEach((bar,i)=>bar.classList.toggle('filled',i<Math.round(fraction*20)));}
    if(input){previous.disabled=disabled||Number(value)<=Number(input.min);next.disabled=disabled||Number(value)>=Number(input.max);}
  }
  function commit(newValue, persist=true){
    if(disabled)return;
    value=newValue;paint();
    row.dispatchEvent(new CustomEvent('settingchange',{bubbles:true}));
    if(persist)save(key,value,option);
  }
  function adjust(direction){
    if(disabled)return;
    if(choices){const index=choices.findIndex(([v])=>String(v)===String(value));commit(choices[(index+direction+choices.length)%choices.length][0]);}
    else if(kind==='checkbox')commit(direction>0);
    else commit(Number(Math.max(Number(input.min),Math.min(Number(input.max),Number(value)+direction*Number(input.step))).toFixed(4)));
  }
  previous.addEventListener('click',()=>adjust(-1));next.addEventListener('click',()=>adjust(1));
  output.addEventListener('click',()=>{if(kind==='checkbox')commit(!value);else if(choices)adjust(1);});
  if(input){
    input.addEventListener('input',()=>commit(Number(input.value),false));
    input.addEventListener('change',()=>commit(Number(input.value)));
  }
  row.addEventListener('keydown',e=>{
    if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();e.stopPropagation();adjust(e.key==='ArrowRight'?1:-1);}
    if(e.key==='Enter'&&e.target===row&&kind!=='range'){e.preventDefault();if(kind==='checkbox')commit(!value);else adjust(1);}
  });
  row._setting={kind,disabled,choices,display,get value(){return value;},set:commit,adjust};
  paint();row.append(controls);
  if(disabled)row.append(text('small','Indisponível: pma-voice não está iniciado.'));
  $('submenu').append(row);
}
function render() {
  const menu = $('submenu'); menu.replaceChildren();
  if(currentPage==='admin')return;
  const group = currentPage.split('.')[1];
  if (currentPage === 'settings') {
    for (const id of ['controller','keys','audio','camera','display','graphics','presets','game','voice','hud','filters','interface']) menu.append(action(titles['settings.'+id], 'Abrir ajustes', 'settings.'+id));
    return;
  }
  if (currentPage === 'settings') {
    for (const [id, desc] of Object.entries({ interface: 'Escala do menu', audio: 'Voz, rádio e perfil de áudio', camera: 'Visão a pé e em veículos', graphics: 'Filtros e distância de detalhes', display: 'HUD, radar e resolução', keys: 'Consulte os atalhos atuais' })) menu.append(action(titles['settings.' + id], desc, 'settings.' + id));
  } else if (currentPage === 'settings.interface') control('scale', 'Escala da interface', 'range', [80, 110, 5], false);
  else if (group === 'audio') {
    control('radio', 'Volume do rádio de voz', 'range', [0, 100, 1], true, !game.voice);
    control('call', 'Volume das chamadas', 'range', [0, 100, 1], true, !game.voice);
    control('radioOff', 'Desligar rádio dos veículos', 'checkbox');
  } else if (group === 'camera') {
    const views = [[0, 'Próxima'], [1, 'Média'], [2, 'Distante'], [4, 'Primeira pessoa']];
    control('pedCam', 'Câmera a pé', 'select', views); control('vehCam', 'Câmera do veículo', 'select', views);
  } else if (group === 'graphics') {
    control('filter', 'Filtro de imagem', 'select', config.filters.map(f => [f.value, f.label]), false);
    control('strength', 'Intensidade do filtro', 'range', [0, 100, 1], false);
    control('lod', 'Distância de detalhes', 'select', [[1, 'Normal'], [1.25, 'Ampliada'], [1.5, 'Máxima']]);
    control('lights', 'Luzes distantes de veículos', 'select', [['normal', 'Normal'], ['reduced', 'Reduzidas']]);
    control('budget', 'Orçamento de modelos', 'select', [['normal', 'Normal'], ['reduced', 'Reduzido']]);
    control('shadows', 'Sombras do cenário', 'select', [['high','Alta'],['medium','Média'],['low','Baixa'],['off','Desativadas']]);
    control('clean', 'Limpar marcas e vidros periodicamente', 'checkbox');
    control('brightness', 'Exposição da imagem · ajuste local', 'range', [-10,10,1]);
    readonly('Texturas, MSAA e qualidade gráfica', 'Gerenciados pelo GTA', 'O FiveM não disponibiliza escrita desses ajustes pela interface de scripts.');
  } else if (group === 'display') {
    control('radar', 'Exibir radar', 'checkbox'); control('hud', 'Exibir HUD do GTA', 'checkbox'); control('bigmap', 'Radar ampliado', 'checkbox');
    readonly('Resolução atual', game.resolution || '—', 'Resolução do jogo · somente leitura');
  } else if (group === 'voice') {
    control('radio', 'Volume do rádio de voz', 'range', [0,100,1], true, !game.voice);
    control('call', 'Volume das chamadas', 'range', [0,100,1], true, !game.voice);
    control('click', 'Volume dos cliques de rádio', 'range', [0,100,1], true, !game.voice);
  } else if (group === 'hud') {
    control('hideHud','Ocultar HUD e radar a cada quadro','checkbox');
    control('reticle','Modelo de mira','select',[['gta','Original'],['dot','Ponto'],['cross','Cruz'],['none','Sem mira']]);
  } else if (group === 'game') {
    control('pedCam','Visão a pé','select',[[0,'Próxima'],[1,'Média'],[2,'Distante'],[4,'Primeira pessoa']]);
    control('vehCam','Visão do veículo','select',[[0,'Próxima'],[1,'Média'],[2,'Distante'],[4,'Primeira pessoa']]);
    control('radioOff','Desligar rádio dos veículos','checkbox');
  } else if (group === 'filters') {
    control('filter','Filtro de imagem','select',config.filters.map(f=>[f.value,f.label]),false);
    control('strength','Intensidade do filtro','range',[0,100,1],false);
  } else if (group === 'presets') {
    for (const [label, options] of [['Original',{lod:1,lights:'normal',budget:'normal',shadows:'high',clean:false}],['Equilibrado',{lod:1,lights:'reduced',budget:'normal',shadows:'medium',clean:true}],['Desempenho',{lod:1,lights:'reduced',budget:'reduced',shadows:'low',clean:true}],['Detalhes ampliados',{lod:1.5,lights:'normal',budget:'normal',shadows:'high',clean:false}]]) {
      const row=document.createElement('article');row.className='preset-setting';row.tabIndex=0;row.dataset.settingKey='preset-'+label;
      row.append(text('strong',label));
      const apply=async()=>{const result=await request('preferences',{options});if(result?.ok){preferences=result.preferences;$('save-status').textContent='Predefinição aplicada: '+label;row.dispatchEvent(new CustomEvent('settingchange',{bubbles:true}));}};
      const controls=document.createElement('div');controls.className='setting-controls';
      for(const [caption,className] of [['‹','step-arrow'],['Aplicar','step-value'],['›','step-arrow']]){const button=text('button',caption,className);button.setAttribute('aria-label',caption==='Aplicar'?'Aplicar '+label:(caption==='‹'?'Diminuir ':'Aumentar ')+label);button.addEventListener('click',apply);controls.append(button);}
      row._preset={label,options,apply};row.append(controls);menu.append(row);
    }
  } else if (group === 'keys') {
    for (const row of game.keys || []) readonly(row.label, row.value, 'Atalho atual do GTA');
    menu.append(text('p', 'Os atalhos globais e a sensibilidade do mouse são protegidos pelo jogo. Esta interface consulta os valores atuais.', 'limit-note'));
  } else if (currentPage === 'rules') config.rules.forEach((rule, i) => menu.append(text('article', String(i + 1).padStart(2, '0') + '  ' + rule, 'rule')));
  else if (currentPage === 'profile') {
    readonly('Nome', player.name, 'Identidade do personagem'); readonly('Passaporte', '#' + player.id, 'ID no servidor'); readonly('Profissão', player.job, 'Informação da framework');
  }
  for (const row of game.profiles?.[group] || []) readonly(row.label, row.formatted ?? row.value,undefined,row);
  if (currentPage === 'map') menu.append(text('p', config.map.mode === '3d' ? 'Use as setas, o zoom e a rotação para explorar os arredores.' : config.map.mode === 'image' ? 'Visão da cidade definida pelo administrador.' : 'Mapa original do GTA.', 'limit-note'));
}
async function page(name) {
  if (!titles[name]) return;
  if(name==='admin'&&!config.admin)return;
  if(currentPage==='admin'&&name!=='admin'&&window.ForgeAdmin&&!await window.ForgeAdmin.allowLeave())return;
  currentPage = name;
  $('root-menu').hidden = name !== 'home'; $('stack').hidden = name === 'home';
  $('section-title').textContent = titles[name]; $('trail').textContent = name.includes('.') ? 'CONFIGURAÇÕES' : 'PLAYER HUB';
  $('map-view').hidden = name !== 'map';
  document.body.classList.toggle('map3d', name === 'map' && config.map.mode === '3d');
  document.body.classList.toggle('map-open', name === 'map');
  document.body.classList.toggle('settings-open', name.startsWith('settings'));
  document.body.classList.toggle('admin-open',name==='admin');
  if($('admin-view'))$('admin-view').hidden=name!=='admin';
  render(); const transition=request('page', { page: name });
  window.dispatchEvent(new CustomEvent('forge-settings-page'));
  const result=await transition;
  if(name!==currentPage)return;
  if(name==='map')window.dispatchEvent(new CustomEvent('forge-map-open',{detail:{mode:config.map.mode,world:result?.world}}));
  if(name==='admin')window.dispatchEvent(new CustomEvent('forge-admin-page'));
}
function back() { if (currentPage.includes('.')) page('settings'); else if (currentPage !== 'home') page('home'); else close(); }
function applyConfig(value) {
  config = value;
  if(config.map.mode === 'image') config = { ...config, map: { ...config.map, mode: 'gta' } };
  for (const key of ['accent', 'background', 'panel', 'card', 'border', 'text', 'muted']) if (/^#[0-9a-f]{6}$/i.test(config.theme?.[key])) document.documentElement.style.setProperty('--' + key, config.theme[key]);
  $('brand').textContent = config.name; $('admin-button').hidden = !config.admin;
  $('map-image').hidden = config.map.mode !== 'image'; $('camera-controls').hidden = config.map.mode !== '3d'; $('native-preview').hidden = true;
  if (config.map.mode === 'image') $('map-image').src = config.map.image;
  $('map-mode').textContent = { gta: 'MAPA ORIGINAL DO GTA', image: 'MAPA DA CIDADE', '3d': 'VISTA 3D · ARREDORES' }[config.map.mode];
}
function show(data) {
  player = data.player; game = data.game || {}; preferences = data.preferences;
  applyConfig(data.config);
  $('player-name').textContent = player.name || 'Cidadão'; $('player-id').textContent = '#' + player.id; $('player-job').textContent = player.job;
  const money = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }); $('cash').textContent = money.format(player.cash); $('bank').textContent = money.format(player.bank);
  $('links').replaceChildren(...config.links.flatMap(link => {
    let url; try { url = new URL(link.url); } catch { return []; } if (url.protocol !== 'https:') return [];
    const a = text('a', link.label + ' ↗'); a.href = url.href; a.target = '_blank'; a.rel = 'noopener noreferrer';
    a.addEventListener('click', e => { if (!preview && typeof window.invokeNative === 'function') { e.preventDefault(); window.invokeNative('openUrl', url.href); } }); return [a];
  }));
  document.documentElement.style.setProperty('--scale', preferences.scale / 100);
  document.body.hidden = false; $('save-status').textContent = ''; page(data.page||'home');
  requestAnimationFrame(fitBalances);
}
function fitBalances(){
  if(document.body.hidden)return;
  for(const id of ['cash','bank']){const el=$(id);el.style.fontSize='';let size=parseFloat(getComputedStyle(el).fontSize);while(el.scrollWidth>el.clientWidth&&size>8){size-=0.5;el.style.fontSize=size+'px';}}
}
new ResizeObserver(fitBalances).observe(document.querySelector('aside .stats'));
async function close() {
  if(currentPage==='admin'&&window.ForgeAdmin&&!await window.ForgeAdmin.allowLeave())return;
  const result = await request('close'); if (preview && result?.ok) document.body.hidden = true;
}
document.querySelectorAll('nav [data-page]').forEach(el => el.addEventListener('click', () => page(el.dataset.page)));
document.querySelectorAll('[data-close]').forEach(el => el.addEventListener('click', close));
document.querySelectorAll('[data-back],#back-button').forEach(el => el.addEventListener('click', back));
$('admin-button').addEventListener('click', () => page('admin'));
document.querySelectorAll('[data-move]').forEach(el => el.addEventListener('click', () => request('mapMove', JSON.parse(el.dataset.move))));
document.addEventListener('keydown', event => { if (event.key === 'Escape' && !document.body.hidden&&!document.querySelector('dialog[open]')) { event.preventDefault(); if(!event.repeat)back(); } });
window.addEventListener('message', event => {
  if (event.data?.action === 'open') show(event.data);
  if (event.data?.action === 'adminOpen') page('admin');
  if (event.data?.action === 'config' && !document.body.hidden) { applyConfig(event.data.config); if(currentPage!=='admin')page(currentPage); }
  if (event.data?.action === 'close') { window.ForgeAdmin?.forceClose();document.body.hidden = true; document.body.classList.remove('map3d', 'map-open', 'settings-open','admin-open'); }
});
if (preview) show({ config: { name: 'FORGE ROLEPLAY', theme: {}, map: { mode: 'image', image: 'assets/map.webp' }, admin: true, links: [], rules: ['Respeite os outros jogadores e a equipe.'], filters: [{ label: 'Original', value: 'none' }] }, preferences: { scale: 100, strength: 50, filter: 'none', options: { pedCam: 1, vehCam: 1, radio: 60, call: 60, radar: true, hud: true, lod: 1, lights: 'normal', budget: 'normal' } }, game: { voice: true, resolution: '1920 × 1080', keys: [{ label: 'Avançar', value: 'W' }], profiles: {} }, player: { name: 'Alex Morgan', id: 128, job: 'Cidadão', cash: 1250, bank: 42800 } });
