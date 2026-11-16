// Projection from the supplied PLT map: 4096x6144, 2.2m/px, origin 1884/3821.
(() => {
  const css=document.createElement('link');css.rel='stylesheet';css.href='map-layout.css';document.head.append(css);
  const stage = document.getElementById('map-stage');
  const view=document.getElementById('map-view');
  const tools=document.createElement('div');tools.id='map-tools';tools.innerHTML='<button id="map-exit">← Voltar</button><strong>MAPA DA CIDADE</strong><button id="map-recenter">Minha posição</button>';
  const lighting=document.createElement('div');lighting.id='map-lighting';lighting.hidden=true;lighting.setAttribute('role','group');lighting.setAttribute('aria-label','Iluminação do mapa 3D');
  const lightingLabel=document.createElement('span');lightingLabel.textContent='Visualização';lighting.append(lightingLabel);
  const lightingStatus=document.createElement('span');lightingStatus.id='map-lighting-status';lightingStatus.setAttribute('role','status');
  let lightingBusy=false,lightingEpoch=0;
  function selectLighting(value){lighting.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===value)));}
  for(const[value,label]of [['auto','Automático'],['day','Dia'],['night','Noite']]){
    const b=document.createElement('button');b.textContent=label;b.dataset.mode=value;b.title=value==='auto'?'Acompanha o horário atual do jogo':'Prévia local · não altera o horário do servidor';
    b.addEventListener('click',async()=>{
      if(lightingBusy)return;const epoch=lightingEpoch;lightingBusy=true;lighting.querySelectorAll('button').forEach(button=>button.disabled=true);
      try{const result=await request('mapLighting',{mode:value});if(epoch===lightingEpoch&&currentPage==='map'&&mode==='3d'){if(result?.ok){selectLighting(value);lightingStatus.textContent='';}else lightingStatus.textContent=result?.message||'Não foi possível alterar a visualização.';}}
      finally{if(epoch===lightingEpoch){lightingBusy=false;lighting.querySelectorAll('button').forEach(button=>button.disabled=false);}}
    });lighting.append(b);
  }
  selectLighting('auto');lighting.append(lightingStatus);tools.append(lighting);
  const panel=document.createElement('section');panel.id='places-panel';panel.innerHTML='<h2>Locais da cidade</h2><input id="place-search" type="search" placeholder="Buscar local ou tipo…" aria-label="Buscar locais"><div id="place-filters"></div><div id="places-list"></div><article id="place-details"></article>';
  const hints=document.createElement('div');hints.id='map-hints';hints.textContent='Arraste: mover · Roda: zoom · Botão direito: girar · Clique no ícone: informações · ESC: voltar';
  const projections=document.createElement('div');projections.id='map-projections';stage.append(projections);view.append(tools,panel,hints);
  const routeOverlay=document.createElementNS('http://www.w3.org/2000/svg','svg');routeOverlay.id='map-route-overlay';routeOverlay.setAttribute('aria-hidden','true');stage.append(routeOverlay);
  const zoneOverlay=document.createElementNS('http://www.w3.org/2000/svg','svg');zoneOverlay.id='map-zone-overlay';zoneOverlay.setAttribute('aria-hidden','true');stage.append(zoneOverlay);
  Object.assign(zoneOverlay.style,{position:'absolute',inset:'0',width:'100%',height:'100%',pointerEvents:'none'});
  const playerMarker=document.createElement('div');playerMarker.id='map-player-marker';playerMarker.hidden=true;playerMarker.textContent='▲';playerMarker.setAttribute('aria-label','Sua posição');playerMarker.title='Sua posição';stage.append(playerMarker);
  const popup=document.createElement('article');popup.id='map-blip-popup';popup.hidden=true;stage.append(popup);
  const groupToggle=document.createElement('label');groupToggle.id='group-blips';groupToggle.innerHTML='<input type="checkbox" checked> Agrupar por tipo';panel.insertBefore(groupToggle,document.getElementById('places-list'));
  let grouped=true,groupIndex=new Map(),headshotImage;
  groupToggle.querySelector('input').addEventListener('change',e=>{grouped=e.target.checked;listPlaces();});
  document.getElementById('map-exit').addEventListener('click',back);
  const canvas = document.createElement('canvas'); canvas.id = 'interactive-map'; canvas.hidden = true;
  canvas.setAttribute('aria-label', 'Mapa interativo: arraste para mover, use a roda para zoom e clique duas vezes para marcar o GPS.');
  stage.append(canvas);
  const ctx = canvas.getContext('2d'), image = new Image(); image.src = 'assets/map.webp';
  let mode, world = { x: 0, y: 0, blips: [] }, scale = 0.3, cx = 1884, cy = 3821, drag, pending = {}, timer, waypoint;
  let route = [], routeLength = 0;
  let selected=null,catalog={},modelOverrides={},hiddenTypes=new Set(),hits=[],moved=false,startPointer;
  try{hiddenTypes=new Set(JSON.parse(localStorage.getItem('forge-pause:map-hidden')||'[]'));}catch{}
  const known={52:['Loja','Lojas'],361:['Posto de combustível','Postos'],60:['Polícia','Serviços'],61:['Hospital','Serviços'],357:['Garagem','Transporte'],50:['Oficina','Serviços'],73:['Loja de roupas','Lojas'],71:['Barbearia','Lojas'],110:['Ammu-Nation','Lojas'],108:['Banco','Serviços']};
  const groups={Services:'Serviços',Commerces:'Lojas',Shops:'Lojas',Transport:'Transporte',Emplois:'Trabalhos',Jobs:'Trabalhos',Autres:'Outros'};
  function describe(b){const info=known[b.sprite]||catalog[b.sprite]||['Local · ícone '+b.sprite,'Outros'],custom=modelOverrides[String(b.sprite)];const group=b.group||custom?.group||info[1];return {name:b.name||custom?.name||info[0],group:groups[group]||group};}
  function imageFor(sprite){return modelOverrides[String(sprite)]?.image||('assets/blips/'+sprite+'.png');}
  function visible(b){return modelOverrides[String(b.sprite)]?.disabled!==true&&!hiddenTypes.has(describe(b).group);}
  function decorateProjection(button,b){
    const source=imageFor(b.sprite),img=button.querySelector('img');
    if(img&&img.getAttribute('src')!==source)img.src=source;
    button.setAttribute('aria-label',describe(b).name);button.title=describe(b).name+' · ID '+b.sprite;
    if(img){img.style.width=(22*(b.scale??1))+'px';img.style.height=(22*(b.scale??1))+'px';img.style.opacity=String((b.alpha??255)/255);img.style.transform='rotate('+(b.rotation||0)+'deg)';}
  }
  function applyModels(value){
    modelOverrides=value&&typeof value==='object'?value:{};
    icons.clear();
    listPlaces();
    if(selected!==null)selectBlip(selected,false);else draw();
    projections.querySelectorAll('button').forEach(button=>{
      const b=world.blips[Number(button.dataset.id)-1];
      if(!b||!visible(b))button.remove();else decorateProjection(button,b);
    });
  }
  function clearSelection(){
    selected=null;popup.hidden=true;popup.replaceChildren();
    document.getElementById('place-details').replaceChildren();
    document.querySelectorAll('.place-row.selected').forEach(row=>row.classList.remove('selected'));
  }
  fetch('assets/blips.json').then(r=>r.json()).then(data=>{catalog=data.blips||{};listPlaces();draw();}).catch(()=>{});
  function listPlaces(){
    if(selected!==null&&(!world.blips[selected]||!visible(world.blips[selected])))clearSelection();
    const filters=document.getElementById('place-filters');filters.replaceChildren();
    const categories=[...new Set((world.blips||[]).map(b=>describe(b).group))].sort();
    for(const category of categories){const button=document.createElement('button');button.textContent=category;button.classList.toggle('off',hiddenTypes.has(category));button.setAttribute('aria-pressed',String(!hiddenTypes.has(category)));button.addEventListener('click',()=>{if(hiddenTypes.has(category))hiddenTypes.delete(category);else hiddenTypes.add(category);try{localStorage.setItem('forge-pause:map-hidden',JSON.stringify([...hiddenTypes]));}catch{}listPlaces();draw();});filters.append(button);}
    const search=document.getElementById('place-search').value.toLocaleLowerCase('pt-BR');
    const list=document.getElementById('places-list');list.replaceChildren();
    let rows=(world.blips||[]).map((b,i)=>({b,i,d:Math.hypot(b.x-world.x,b.y-world.y)})).filter(({b})=>visible(b)&&(describe(b).name+' '+describe(b).group+' '+(b.zone||'')).toLocaleLowerCase('pt-BR').includes(search)).sort((a,b)=>a.d-b.d);
    if(grouped){const groups=new Map();for(const row of rows){const key=row.b.managedId?row.b.sprite+':'+row.b.name+':'+row.b.group:row.b.sprite;if(!groups.has(key))groups.set(key,[]);groups.get(key).push(row);}rows=[...groups.entries()].map(([key,items])=>{const index=(groupIndex.get(key)||0)%items.length;return {...items[index],items,index,key};});}
    rows.forEach(({b,i,d,items,index,key})=>{
      const button=document.createElement('button');button.className='place-row';button.classList.toggle('selected',selected===i);button.dataset.blipId=i;
      const img=document.createElement('img');img.src=imageFor(b.sprite);img.alt='';img.onerror=()=>{img.hidden=true;};button.title=describe(b).name+' · ID '+b.sprite;
      const content=document.createElement('span'),title=document.createElement('strong'),small=document.createElement('small');title.textContent=describe(b).name;small.textContent=[b.zone,describe(b).group,(d/1000).toFixed(2)+' km'].filter(Boolean).join(' · ');content.append(title,small);button.append(img,content);button.addEventListener('click',()=>selectBlip(i,true));button.addEventListener('dblclick',()=>toggleWaypoint(b));
      const wrapper=document.createElement('div');wrapper.className='place-group';wrapper.append(button);
      if(items&&items.length>1){const arrows=document.createElement('div');arrows.className='group-arrows';for(const delta of [-1,1]){const arrow=document.createElement('button');arrow.textContent=delta<0?'‹':'›';arrow.setAttribute('aria-label',delta<0?'Local anterior':'Próximo local');arrow.addEventListener('click',()=>{const next=(index+delta+items.length)%items.length;groupIndex.set(key,next);listPlaces();selectBlip(items[next].i,true);});arrows.append(arrow);}const counter=document.createElement('small');counter.textContent=(index+1)+' / '+items.length;arrows.append(counter);wrapper.append(arrows);}list.append(wrapper);
    });
  }
  function selectBlip(i,center){
    const b=world.blips[i];if(!b)return;selected=i;
    const detail=document.getElementById('place-details');detail.replaceChildren();const title=document.createElement('h3'),info=document.createElement('p'),button=document.createElement('button');title.textContent=describe(b).name;info.textContent=[describe(b).group,b.zone,'Ícone '+b.sprite,'X '+Math.round(b.x)+' / Y '+Math.round(b.y)].filter(Boolean).join(' · ');button.textContent='Traçar rota até aqui';button.addEventListener('click',()=>setWaypoint(b));detail.append(title,info,button);
    popup.replaceChildren(title.cloneNode(true),info.cloneNode(true));const hint=document.createElement('small');hint.textContent='Duplo clique no ícone: marcar/desmarcar rota';popup.append(hint);popup.hidden=false;
    if(center){if(mode==='gta'){const p=point(b.x,b.y);cx=p.x;cy=p.y;}else request('mapFly',{x:b.x,y:b.y});}
    document.querySelectorAll('.place-row').forEach(row=>row.classList.toggle('selected',Number(row.dataset.blipId)===i));draw();
  }
  async function toggleWaypoint(p){if(waypoint&&Math.hypot(waypoint.x-p.x,waypoint.y-p.y)<3){const result=await request('waypoint',{clear:true});if(result?.ok){waypoint=null;calculateRoute();}}else await setWaypoint(p);}
  async function setWaypoint(p){const result=await request('waypoint',{x:p.x,y:p.y});if(result?.ok){waypoint={x:p.x,y:p.y};calculateRoute();}}
  document.getElementById('place-search').addEventListener('input',listPlaces);
  document.getElementById('map-recenter').addEventListener('click',()=>{if(mode==='gta'){const p=point(world.x,world.y);cx=p.x;cy=p.y;draw();}else request('mapFly',{x:world.x,y:world.y});});
  const icons = new Map();
  function icon(sprite) {
    const source=imageFor(sprite);
    if (!icons.has(source)) {
      const img = new Image(); img.onload = draw; img.src = source; icons.set(source, img);
    }
    return icons.get(source);
  }
  function calculateRoute() {
    route = []; routeLength = 0;
    if (waypoint && window.ForgeRoads?.ready) {
      const result = window.ForgeRoads.find(world.x, world.y, waypoint.x, waypoint.y);
      if (result) { route = window.ForgeRoads.points(result); routeLength = result.len; }
    }
    if(mode==='3d')request('mapRoute',{points:route.filter((_,i)=>i%Math.max(1,Math.ceil(route.length/300))===0)});
    draw();
  }
  window.addEventListener('forge-roads-ready',calculateRoute);
  const point = (x, y) => ({ x: 1884 + x / 2.2, y: 3821 - y / 2.2 });
  function draw() {
    if (canvas.hidden || !image.complete || !image.naturalWidth) return;
    const bounds = stage.getBoundingClientRect(); canvas.width = Math.round(bounds.width); canvas.height = Math.round(bounds.height);
    canvas.dataset.routePoints = String(route.length);
    canvas.dataset.blips = String(world.blips?.length || 0);
    hits=[];
    ctx.fillStyle = '#18242b'; ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.save(); ctx.translate(canvas.width / 2, canvas.height / 2); ctx.scale(scale, scale); ctx.translate(-cx, -cy); ctx.drawImage(image, 0, 0, 4096, 6144);
    function dot(x, y, color, radius) { const p = point(x, y); ctx.fillStyle = color; ctx.beginPath(); ctx.arc(p.x, p.y, radius / scale, 0, Math.PI * 2); ctx.fill(); }
    for(const b of world.blips||[]){
      const z=b.zoneShape;if(!visible(b)||!z||z.mode==='none')continue;
      const p=point(b.x,b.y);ctx.save();ctx.translate(p.x,p.y);ctx.rotate(-(z.rotation||0)*Math.PI/180);ctx.beginPath();
      if(z.mode==='radius')ctx.arc(0,0,z.radius/2.2,0,Math.PI*2);else ctx.rect(-z.width/4.4,-z.height/4.4,z.width/2.2,z.height/2.2);
      ctx.fillStyle=config.blipColors?.[z.color]?.color||'#FF7A1A';ctx.globalAlpha=z.alpha/255;ctx.fill();ctx.restore();
    }
    if (route.length) {
      ctx.strokeStyle = '#b68aff'; ctx.lineWidth = 4 / scale; ctx.lineJoin = 'round'; ctx.beginPath();
      route.forEach((v,i) => { const p=point(v.x,v.y); if(i)ctx.lineTo(p.x,p.y);else ctx.moveTo(p.x,p.y); }); ctx.stroke();
    }
    for (const [id,b] of (world.blips || []).entries()) {
      if(!visible(b)||(b.alpha??255)===0)continue;
      const img=icon(b.sprite), p=point(b.x,b.y), size=22*(b.scale??1)/scale;
      hits.push({id,x:canvas.width/2+(p.x-cx)*scale,y:canvas.height/2+(p.y-cy)*scale});
      if(img.complete&&img.naturalWidth){ctx.save();ctx.globalAlpha=(b.alpha??255)/255;ctx.translate(p.x,p.y);ctx.rotate((b.rotation||0)*Math.PI/180);ctx.drawImage(img,-size/2,-size/2,size,size);ctx.restore();}
      else dot(b.x,b.y,'#d8dce5',4);
    }
    dot(world.x, world.y, '#FF7A1A', 7);
    if(headshotImage?.complete&&headshotImage.naturalWidth){const p=point(world.x,world.y);ctx.save();ctx.beginPath();ctx.arc(p.x,p.y,17/scale,0,Math.PI*2);ctx.clip();ctx.drawImage(headshotImage,p.x-17/scale,p.y-17/scale,34/scale,34/scale);ctx.restore();}
    if (waypoint) dot(waypoint.x, waypoint.y, '#b68aff', 7);
    ctx.restore();
    if(selected!==null){const b=world.blips[selected],p=b&&point(b.x,b.y);if(p){popup.style.left=Math.min(canvas.width-260,Math.max(12,canvas.width/2+(p.x-cx)*scale+18))+'px';popup.style.top=Math.min(canvas.height-120,Math.max(12,canvas.height/2+(p.y-cy)*scale-90))+'px';}}
    hints.textContent='Arraste: mover · Roda: zoom · Clique no ícone: informações · Duplo clique: GPS · ESC: voltar'+(waypoint?(route.length?' · Rota: '+(routeLength/1000).toFixed(2)+' km':' · Rota indisponível para este ponto'):'');
  }
  function move(data) {
    for (const [key, value] of Object.entries(data)) pending[key] = (pending[key] || 0) + value;
    if (!timer) timer = setTimeout(() => { request('mapMove', pending); pending = {}; timer = null; }, 40);
  }
  window.addEventListener('forge-map-open', e => {
    mode = e.detail.mode; world = e.detail.world || world; modelOverrides=config.blipModels||modelOverrides;canvas.hidden = mode !== 'gta';projections.hidden=mode!=='3d';routeOverlay.hidden=mode!=='3d';playerMarker.hidden=true;routeOverlay.replaceChildren();selected=null;document.getElementById('place-details').replaceChildren();listPlaces();
    lightingEpoch++;lightingBusy=false;lighting.hidden=mode!=='3d';lighting.querySelectorAll('button').forEach(button=>button.disabled=false);selectLighting('auto');lightingStatus.textContent='';
    projections.replaceChildren();zoneOverlay.replaceChildren();zoneOverlay.hidden=mode!=='3d';
    popup.hidden=true;
    request('headshot').then(result=>{if(result?.ok&&result.url){const img=new Image();img.onload=()=>{headshotImage=img;playerMarker.replaceChildren(img.cloneNode());draw();};img.src=result.url;}});
    waypoint = world.waypoint || null;
    document.getElementById('map-mode').textContent = mode === 'gta' ? 'MAPA 2D · LOCAIS DO JOGO · GPS' : mode === '3d' ? 'VISTA 3D · ARRASTE PARA EXPLORAR · RODA PARA ZOOM' : 'IMAGEM DA CIDADE';
    const p = point(world.x, world.y); cx = p.x; cy = p.y; scale = Math.max(stage.clientWidth / 4096, stage.clientHeight / 6144) * 2;
    calculateRoute();
  });
  image.onload = draw; new ResizeObserver(draw).observe(stage);
  stage.addEventListener('pointerdown', e => { if (e.target.closest('button') || !['gta', '3d'].includes(mode)) return; moved=false;startPointer={x:e.clientX,y:e.clientY};drag = { x: e.clientX, y: e.clientY }; stage.setPointerCapture(e.pointerId); });
  stage.addEventListener('pointermove', e => {
    if (!drag) return;
    if(startPointer&&Math.hypot(e.clientX-startPointer.x,e.clientY-startPointer.y)>5)moved=true;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y; drag = { x: e.clientX, y: e.clientY };
    if (mode === 'gta') { cx -= dx / scale; cy -= dy / scale; draw(); }
    else move(e.buttons === 2 ? { rotate: -dx * 0.25,tilt:dy*0.2 } : { x: -dx / stage.clientHeight * 8, y: dy / stage.clientHeight * 8 });
  });
  const release = () => { drag = null; }; stage.addEventListener('pointerup', release); stage.addEventListener('pointercancel', release);
  stage.addEventListener('contextmenu', e => e.preventDefault());
  function hitAt(e){const rect=canvas.getBoundingClientRect(),x=e.clientX-rect.left,y=e.clientY-rect.top;return hits.filter(p=>Math.hypot(p.x-x,p.y-y)<16).sort((a,b)=>Math.hypot(a.x-x,a.y-y)-Math.hypot(b.x-x,b.y-y))[0];}
  stage.addEventListener('pointermove',e=>{if(mode==='gta'&&!drag)canvas.style.cursor=hitAt(e)?'pointer':'grab';});
  stage.addEventListener('click',e=>{
    if(moved||e.target.closest('button'))return;
    if(mode==='gta'){const hit=hitAt(e);if(hit){selectBlip(hit.id,false);return;}}
    clearSelection();
  });
  window.addEventListener('message',e=>{
    if(e.data?.action==='mapWorld'){
      if(e.data.world&&Array.isArray(e.data.world.blips)){
        world=e.data.world;clearSelection();projections.replaceChildren();zoneOverlay.replaceChildren();listPlaces();calculateRoute();
      }
      return;
    }
    if(e.data?.action==='blipModels'){
      config.blipModels=e.data.models||{};applyModels(config.blipModels);return;
    }
    if(e.data?.action!=='mapProjection'||mode!=='3d'||currentPage!=='map')return;
    const activeIds=new Set();
    const rect=stage.getBoundingClientRect();
    const screen=p=>({x:p.x*window.innerWidth-rect.left,y:p.y*window.innerHeight-rect.top});
    zoneOverlay.replaceChildren();zoneOverlay.setAttribute('viewBox','0 0 '+rect.width+' '+rect.height);
    for(const zone of e.data.zones||[]){
      const b=world.blips[zone.id-1];if(!b||!visible(b))continue;
      const polygon=document.createElementNS('http://www.w3.org/2000/svg','polygon');
      polygon.setAttribute('points',zone.points.map(p=>{const pos=screen(p);return pos.x+','+pos.y;}).join(' '));
      polygon.setAttribute('fill',config.blipColors?.[zone.color]?.color||'#FF7A1A');polygon.setAttribute('fill-opacity',String(zone.alpha/255));zoneOverlay.append(polygon);
    }
    for(const p of e.data.points||[]){
      const b=world.blips[p.id-1];if(!b||!visible(b)||(b.alpha??255)===0)continue;
      activeIds.add(String(p.id));const pos=screen(p);let button=projections.querySelector('[data-id="'+p.id+'"]');
      if(!button){button=document.createElement('button');button.dataset.id=p.id;button.className='projected-blip';const img=document.createElement('img');img.alt='';button.append(img);button.addEventListener('click',()=>selectBlip(p.id-1,false));button.addEventListener('dblclick',()=>toggleWaypoint(b));projections.append(button);}
      decorateProjection(button,b);
      button.style.left=pos.x+'px';button.style.top=pos.y+'px';if(selected===p.id-1){popup.style.left=Math.max(12,Math.min(rect.width-260,pos.x+18))+'px';popup.style.top=Math.max(12,Math.min(rect.height-120,pos.y-90))+'px';}
    }
    projections.querySelectorAll('button').forEach(b=>{if(!activeIds.has(b.dataset.id))b.remove();});
    routeOverlay.replaceChildren();routeOverlay.setAttribute('viewBox','0 0 '+rect.width+' '+rect.height);
    let d='',previous;
    for(const p of e.data.route||[]){
      if(!p||!Number.isFinite(p.x)||!Number.isFinite(p.y)||Math.abs(p.x)>4||Math.abs(p.y)>4){previous=null;continue;}
      const pos=screen(p);
      // Break at clipped/remote points instead of spanning the screen with stray lines.
      const adjacent=previous&&Math.hypot(pos.x-previous.x,pos.y-previous.y)<Math.max(rect.width,rect.height)*0.2;
      d+=(adjacent?' L ':' M ')+pos.x+' '+pos.y;previous=pos;
    }
    const path=document.createElementNS('http://www.w3.org/2000/svg','path');path.setAttribute('d',d);routeOverlay.append(path);
    const p=e.data.player;
    playerMarker.hidden=!p||!Number.isFinite(p.x)||!Number.isFinite(p.y)||p.x<0||p.x>1||p.y<0||p.y>1;
    if(!playerMarker.hidden){const pos=screen(p);playerMarker.style.left=pos.x+'px';playerMarker.style.top=pos.y+'px';}
  });
  stage.addEventListener('wheel', e => { if (!['gta', '3d'].includes(mode)) return; e.preventDefault(); if (mode === 'gta') { scale = Math.max(0.08, Math.min(4, scale * (e.deltaY < 0 ? 1.15 : 1 / 1.15))); draw(); } else move({ zoom: e.deltaY < 0 ? -1 : 1 }); }, { passive: false });
  stage.addEventListener('dblclick', async e => {
    if (mode !== 'gta' || e.target.closest('button')) return;
    const hit=hitAt(e);if(hit){selectBlip(hit.id,false);await toggleWaypoint(world.blips[hit.id]);return;}
    const b = canvas.getBoundingClientRect(); const px = cx + (e.clientX - b.left - b.width / 2) / scale, py = cy + (e.clientY - b.top - b.height / 2) / scale;
    const p = { x: (px - 1884) * 2.2, y: (3821 - py) * 2.2 };
    const result = await request('waypoint', p); if (result?.ok) { waypoint = p; calculateRoute(); }
  });
})();
