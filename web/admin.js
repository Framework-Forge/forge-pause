'use strict';
(() => {
  const copy=value=>JSON.parse(JSON.stringify(value));
  const root=document.createElement('main');root.id='admin-view';root.hidden=true;
  root.innerHTML='<header class="admin-heading"><b class="admin-brand">F›</b><div><small>FORGE · CONTROLE ADMINISTRATIVO</small><h2>Administração do Pause</h2></div><div class="admin-heading-actions"><button id="admin-parent" hidden>Voltar ao Admin Forge</button><button id="admin-refresh">Atualizar</button><button id="admin-back">Voltar ao Pause</button></div></header><nav id="admin-tabs" role="tablist" aria-label="Administração"></nav><section id="admin-content"></section><div class="admin-message" role="status"><span id="admin-status">Carregando administração…</span><span class="admin-dirty" id="admin-dirty"></span></div>';
  $('shell').append(root);
  const css=document.createElement('link');css.rel='stylesheet';css.href='admin.css';document.head.append(css);
  const S={tab:'general',settings:null,base:null,defaults:null,models:{},points:{},colors:{},position:{x:0,y:0,z:0},
    settingsRevision:0,modelRevision:0,pointRevision:0,modelDraft:null,modelId:null,modelSearch:'',modelFilter:'active',modelPage:1,
    pointDraft:null,pointId:null,pointBase:null,pointSearch:'',dirty:false,busy:false,epoch:0,parent:false};
  const content=$('admin-content');let canvas,coordinateInputs={},previewTimer,dialogOpen=false,demo,previewRevision=0;
  const tabs={general:'Geral e mapa',theme:'Cores do layout',camera:'Câmera',models:'Ícones do catálogo',points:'Blips e zonas'};
  function status(message,error=false){$('admin-status').textContent=message;$('admin-status').parentElement.dataset.error=String(error);}
  function dirty(){return S.dirty||pointDirty()||modelDirty();}
  function pointDirty(){return !!S.pointDraft&&JSON.stringify(S.pointDraft)!==JSON.stringify(S.pointBase);}
  function modelDirty(){return !!S.modelDraft&&JSON.stringify(S.modelDraft)!==JSON.stringify(S.modelBase);}
  function indicator(){$('admin-dirty').textContent=dirty()?'● Alterações não publicadas':'';}
  function el(tag,value,className){const n=document.createElement(tag);if(value!==undefined)n.textContent=value;if(className)n.className=className;return n;}
  function button(label,fn,className){const b=el('button',label,className);b.type='button';b.addEventListener('click',async()=>{if(S.busy)return;await fn();});return b;}
  function actions(parent,...items){const n=el('div',undefined,'admin-actions');n.append(...items);parent.append(n);return n;}
  function invalidField(input,message){
    const label=input.getAttribute('aria-label')||'Valor';
    const validity=input.validity;
    if(!message){
      if(validity.valueMissing)message='preencha este campo.';
      else if(validity.badInput)message='informe um número válido.';
      else if(validity.rangeUnderflow||validity.rangeOverflow)message=`use um valor entre ${input.min} e ${input.max}.`;
      else if(validity.stepMismatch)message=input.step==='1'?'use um número inteiro.':`use incrementos de ${input.step}.`;
      else message='confira o valor informado.';
    }
    for(const details of input.closest('.admin-point-editor')?.querySelectorAll('details')||[])if(details.contains(input))details.open=true;
    input.setAttribute('aria-invalid','true');input.focus();input.scrollIntoView({block:'center'});
    status(`${label}: ${message}`,true);return false;
  }
  function validPanel(panel){
    const input=panel.querySelector('input:invalid, select:invalid');
    return input?invalidField(input):true;
  }
  function field(parent,label,value,options,change){
    const wrapper=el('label',undefined,'admin-field'+(options.full?' admin-full':''));wrapper.append(el('span',label));
    const input=document.createElement(options.choices?'select':'input');input.setAttribute('aria-label',label);
    if(options.choices){for(const[v,name]of options.choices){const o=el('option',name);o.value=v;input.append(o);}}
    else input.type=options.type||'text';
    if(input.type==='checkbox')input.checked=!!value;else input.value=value??'';
    for(const key of ['min','max','step','maxLength'])if(options[key]!==undefined)input[key]=options[key];
    input.required=options.required??input.type==='number';
    const read=()=>input.type==='checkbox'?input.checked:(input.type==='number'||input.type==='range'?Number(input.value):input.value);
    input.addEventListener(options.choices||input.type==='checkbox'?'change':'input',()=>{
      input.removeAttribute('aria-invalid');
      if(input.type==='number'&&(input.value===''||!input.checkValidity()))return;
      change(read());indicator();
    });
    wrapper.append(input);parent.append(wrapper);return input;
  }
  function slider(parent,label,value,min,max,step,change,continuous=false,decimalDisplay=false){
    const wrapper=el('label',undefined,'admin-field admin-full');wrapper.append(el('span',label));
    const row=el('div',undefined,'admin-slider'),range=document.createElement('input'),number=document.createElement('input');
    range.type='range';number.type='number';
    for(const n of [range,number]){Object.assign(n,{min,max,step:n===number&&continuous?'any':step,value});n.setAttribute('aria-label',label+(n===range?' (deslizar)':' (valor)'));}
    const formatted=v=>decimalDisplay&&Number.isInteger(Number(v))?Number(v).toFixed(1):String(v);
    if(decimalDisplay)number.value=formatted(value);
    number.required=true;
    for(const n of [range,number])n.addEventListener('input',()=>{
      range.removeAttribute('aria-invalid');number.removeAttribute('aria-invalid');
      if(n.value===''||!n.checkValidity())return;const v=Number(n.value);range.value=v;if(n===range)number.value=formatted(v);change(v);indicator();
    });
    number.addEventListener('change',()=>{if(number.value!==''&&number.checkValidity())number.value=formatted(number.value);});
    row.append(range,number);wrapper.append(row);parent.append(wrapper);
  }
  function card(title){const c=el('article',undefined,'admin-card');c.append(el('h3',title));return c;}
  function fields(parent){const n=el('div',undefined,'admin-fields');parent.append(n);return n;}
  function imageSource(model){return S.models[String(model)]?.image||'assets/blips/'+model+'.png';}
  function modelImage(model){const img=document.createElement('img');img.src=imageSource(model);img.alt='';img.addEventListener('error',()=>{img.style.opacity='.2';});return img;}
  function colorSwatch(color){const swatch=el('span',undefined,'admin-color-swatch');swatch.style.backgroundColor=color;swatch.setAttribute('aria-hidden','true');return swatch;}
  function colorField(parent,label,value,change){
    const wrapper=el('div',undefined,'admin-field admin-full');wrapper.append(el('span',label));
    let selected=Number(value);
    const trigger=button('',()=>{
      if(dialogOpen)return;dialogOpen=true;
      const d=el('dialog',undefined,'admin-dialog admin-picker');d.setAttribute('aria-label','Escolher '+label);
      d.append(el('h3','Escolher '+label));
      const toolbar=el('div',undefined,'admin-toolbar'),search=document.createElement('input');
      search.placeholder='Buscar por ID, nome ou código da cor';search.setAttribute('aria-label','Buscar cor');toolbar.append(search);d.append(toolbar);
      const grid=el('div',undefined,'admin-model-grid admin-color-grid'),count=el('p',undefined,'admin-note');d.append(grid,count);
      const end=()=>{d.close();d.remove();dialogOpen=false;trigger.focus({preventScroll:true});};
      const paint=()=>{
        grid.replaceChildren();
        const colors=Object.entries(S.colors).filter(([id,c])=>`${id} ${c.name} ${c.color}`.toLowerCase().includes(search.value.trim().toLowerCase())).sort((a,b)=>Number(a[0])-Number(b[0]));
        for(const[id,c]of colors){
          const b=button('',()=>{selected=Number(id);paintTrigger();end();change(selected);},'admin-model admin-color');
          b.append(colorSwatch(c.color),el('strong',c.name),el('small',`#${id} · ${c.color}`));
          b.setAttribute('aria-label',`#${id} · ${c.name}`);b.setAttribute('aria-pressed',String(Number(id)===selected));b.title=`ID: ${id}\nNome: ${c.name}\nCor: ${c.color}`;grid.append(b);
        }
        count.textContent=`${colors.length} cores disponíveis`;if(!colors.length)grid.append(el('p','Nenhuma cor encontrada.'));
      };
      search.addEventListener('input',paint);paint();actions(d,button('Cancelar escolha',end));
      d.addEventListener('cancel',e=>{e.preventDefault();end();});root.append(d);d.showModal();
    },'admin-color-trigger');
    function paintTrigger(){
      const c=S.colors[selected],text=el('span');text.append(el('strong',c?.name||'Cor GTA'),el('small',`#${selected}${c?' · '+c.color:''}`));
      trigger.replaceChildren(colorSwatch(c?.color||'transparent'),text,el('span','Escolher','admin-color-choose'));
    }
    trigger.setAttribute('aria-label',label);trigger.setAttribute('aria-haspopup','dialog');paintTrigger();wrapper.append(trigger);parent.append(wrapper);
  }
  function theme(value){for(const key of ['accent','background','panel','card','border','text','muted'])if(/^#[0-9a-f]{6}$/i.test(value[key]))document.documentElement.style.setProperty('--'+key,value[key]);}
  function confirmAction(title,message,accept='Descartar alterações'){
    if(dialogOpen)return Promise.resolve(false);
    dialogOpen=true;return new Promise(resolve=>{
      const d=el('dialog',undefined,'admin-dialog');d.append(el('h3',title),el('p',message));
      const end=value=>{d.close();d.remove();dialogOpen=false;resolve(value);};
      actions(d,button('Cancelar',()=>end(false)),button(accept,()=>end(true),'primary'));
      d.addEventListener('cancel',e=>{e.preventDefault();end(false);});root.append(d);d.showModal();
    });
  }
  async function demoSnapshot(){
    if(!demo){
      const catalog=await fetch('assets/blips.json').then(r=>r.json());
      const models={};for(const[id,v]of Object.entries(catalog.blips))models[id]={id,name:v[0],group:v[1],image:'assets/blips/'+id+'.png',disabled:false,original:true,edited:false};
      const settings={name:config.name,subtitle:'Cidade Forge',theme:{accent:'#FF7A1A',background:'#0A0A0C',panel:'#121214',card:'#18181C',border:'#1F1F24',text:'#FFFFFF',muted:'#8E8E9F'},map:{mode:config.map.mode==='3d'?'3d':'gta',image:'assets/map.webp',minDistance:60,initialDistance:500,maxDistance:30000,maxPan:3000},portrait:{enabled:true,distance:1.5,side:0,height:0,fov:40,transition:300}};
      demo={ok:true,settings:{ok:true,settings,revision:0},defaults:copy(settings),catalog:{models:{},revision:0,admin:true},points:{points:{},revision:0,admin:true,writable:true},models:Object.values(models),originalModels:copy(models),colors:{0:{name:'Branco',color:'#FFFFFF'},1:{name:'Vermelho',color:'#e03232'},2:{name:'Verde',color:'#71cb71'},4:{name:'Azul',color:'#5db6e5'},9:{name:'Amarelo',color:'#eec64e'}},position:{x:215,y:-810,z:30.7},parent:false};
    }
    return copy(demo);
  }
  async function api(name,data={}){
    if(!preview)return request(name,data);
    if(name==='adminSnapshot')return demoSnapshot();
    if(name==='adminPosition')return {ok:true,position:copy(S.position)};
    if(name==='adminAction'){
      await demoSnapshot();
      if(data.kind==='settings'){demo.settings.settings=copy(data.value);demo.settings.revision++;return {...copy(demo.settings),ok:true,message:'Prévia de navegador: ajustes guardados só nesta sessão.'};}
      if(data.kind==='point'){
        const id=data.id||'blip-'+Date.now();if(data.operation==='delete')delete demo.points.points[id];
        else if(data.operation==='toggle')demo.points.points[id].enabled=!demo.points.points[id].enabled;
        else demo.points.points[id]=copy(data.value);
        demo.points.revision++;return {...copy(demo.points),id,ok:true,message:'Prévia de navegador: ponto guardado só nesta sessão.'};
      }
      const id=String(data.id),m=demo.models.find(m=>m.id===id);
      if(data.operation==='save'){
        const value={...copy(data.value),id,original:!!m?.original,edited:true};if(m)Object.assign(m,value);else demo.models.push(value);
        demo.catalog.models[id]=copy(data.value);
      }else if(data.operation==='delete'){m.disabled=true;demo.catalog.models[id]={...copy(m),disabled:true};}
      else{if(m.original){delete demo.catalog.models[id];Object.assign(m,copy(demo.originalModels[id]));}else{m.disabled=false;demo.catalog.models[id]={...copy(m),disabled:false};}}
      demo.catalog.revision++;return {...copy(demo.catalog),ok:true,message:'Prévia de navegador: modelo atualizado só nesta sessão.'};
    }
    return {ok:true};
  }
  async function load(){
    const epoch=++S.epoch;status('Carregando configurações, catálogo e pontos…');
    const result=await api('adminSnapshot');if(epoch!==S.epoch||currentPage!=='admin')return;
    if(!result?.ok){status(result?.message||'Não foi possível abrir a administração.',true);content.replaceChildren(el('p','Acesso indisponível. Use Atualizar para tentar novamente.'));return;}
    S.settings=copy(result.settings.settings);S.base=copy(S.settings);S.defaults=copy(result.defaults);
    publishedSettings(S.base,result.settings.revision);
    S.settingsRevision=result.settings.revision;S.modelRevision=result.catalog.revision;S.pointRevision=result.points.revision;
    S.models=Object.fromEntries(result.models.map(model=>[model.id,model]));S.points=result.points.points;S.colors=result.colors||{};S.position=result.position;S.parent=result.parent;S.writable=result.points.writable!==false;
    S.pointDraft=S.modelDraft=null;S.pointBase=null;S.dirty=false;
    $('admin-parent').hidden=!S.parent;
    status(preview?'Prévia no navegador · nenhuma alteração é enviada ao servidor.':'Sincronizado · rascunhos aparecem só para você até publicar.');render();
  }
  function publishedSettings(value,revision){
    if(typeof config.settingsRevision==='number'&&revision<config.settingsRevision)return;
    applyConfig({...config,name:value.name,subtitle:value.subtitle,theme:copy(value.theme),map:copy(value.map),settingsRevision:revision});
  }
  async function save(kind,operation,id,value,revision){
    S.busy=true;root.querySelectorAll('button').forEach(b=>b.disabled=true);status('Salvando no servidor…');
    let result;try{result=await api('adminAction',{kind,operation,id,value,revision});}finally{S.busy=false;root.querySelectorAll('button').forEach(b=>b.disabled=false);}
    if(!result?.ok){status(result?.message||'Não foi possível salvar. Seu rascunho foi mantido.',true);return null;}
    status(result.message||'Salvo e publicado para todos.');return result;
  }
  async function reloadCatalog(){
    const r=await api('adminSnapshot');
    if(!r?.ok){status(r?.message||'Atualize o catálogo antes de continuar.',true);return;}
    S.models=Object.fromEntries(r.models.map(m=>[m.id,m]));S.modelRevision=r.catalog.revision;
    S.modelDraft=null;render();
  }
  async function leaveTab(next){
    if(next===S.tab)return;
    if(pointDirty()||modelDirty())if(!await confirmAction('Trocar de seção?','O rascunho de blip ou ícone ainda não foi publicado.'))return;
    previewRevision++;S.pointDraft=S.modelDraft=null;S.pointBase=null;clearTimeout(previewTimer);await api('adminPreview',{kind:S.tab==='camera'?'restore':'clear'});document.body.classList.remove('admin-camera-preview');S.tab=next;render();
  }
  function render(){
    if(!S.settings)return;
    if(canvas){canvas.observer.disconnect();canvas=null;}
    const nav=$('admin-tabs');nav.replaceChildren();
    for(const[id,title]of Object.entries(tabs)){const b=button(title,()=>leaveTab(id));b.setAttribute('role','tab');b.setAttribute('aria-selected',String(S.tab===id));nav.append(b);}
    content.classList.toggle('admin-blip-content',S.tab==='points');content.replaceChildren();
    if(S.tab==='points')renderPoints();else if(S.tab==='models')renderModels();else renderSettings();indicator();
  }
  function settingChange(){
    S.dirty=JSON.stringify(S.settings)!==JSON.stringify(S.base);theme(S.settings.theme);indicator();
    if(S.tab==='camera'&&document.body.classList.contains('admin-camera-preview')){
      clearTimeout(previewTimer);previewTimer=setTimeout(()=>{if(currentPage==='admin'&&S.tab==='camera')previewCamera();},220);
    }
  }
  async function previewCamera(){
    clearTimeout(previewTimer);
    const epoch=S.epoch,revision=++previewRevision;
    const r=await api('adminPreview',{kind:'settings',value:S.settings});
    if(epoch!==S.epoch||revision!==previewRevision||currentPage!=='admin'||S.tab!=='camera')return;
    document.body.classList.toggle('admin-camera-preview',!!r?.ok&&r.active!==false);
    status(r?.message||(r?.ok?'Câmera aplicada só para você.':r?.message||'Prévia indisponível.'),!r?.ok);
  }
  function renderSettings(){
    const columns=el('div',undefined,'admin-columns');content.append(columns);
    if(S.tab==='general'){
      const identity=card('Identidade do servidor'),f=fields(identity);
      field(f,'Nome do servidor',S.settings.name,{full:true,maxLength:100,required:true},v=>{S.settings.name=v;settingChange();});
      field(f,'Descrição',S.settings.subtitle,{full:true,maxLength:100,required:true},v=>{S.settings.subtitle=v;settingChange();});columns.append(identity);
      const map=card('Modelo e limites do mapa'),m=fields(map);
      field(m,'Modelo de mapa',S.settings.map.mode,{full:true,choices:[['gta','Mapa 2D'],['3d','Mapa 3D']]},v=>{S.settings.map.mode=v;settingChange();});
      for(const[key,title,min,max]of [['minDistance','Distância mínima',30,20000],['initialDistance','Distância inicial',60,20000],['maxDistance','Distância máxima',20000,50000],['maxPan','Limite de deslocamento',0,3000]])
        field(m,title,S.settings.map[key],{type:'number',min,max,step:'any'},v=>{S.settings.map[key]=v;settingChange();});
      map.append(el('p','O editor de blips usa sempre o mapa 2D para posicionar com precisão. O mapa dos jogadores mantém o modelo selecionado acima.'));columns.append(map);
    }else if(S.tab==='theme'){
      const c=card('Paleta do Pause'),f=fields(c);
      for(const[key,title]of Object.entries({accent:'Destaque',background:'Fundo',panel:'Painéis',card:'Cartões',border:'Bordas',text:'Textos',muted:'Textos secundários'}))field(f,title,S.settings.theme[key],{type:'color'},v=>{S.settings.theme[key]=v;settingChange();});
      c.append(el('p','As cores são pré-visualizadas nesta interface. Publicar aplica o tema para todos.'));columns.append(c);
      const sample=card('Prévia do layout');sample.append(el('p','Esta área usa as mesmas cores do Pause.'),button('Botão de destaque',()=>{},'primary'),el('p','Texto secundário e bordas acompanham os ajustes em tempo real.'));columns.append(sample);
    }else{
      const c=card('Câmera do personagem'),f=fields(c),p=S.settings.portrait;
      field(f,'Ativar câmera do personagem',p.enabled,{type:'checkbox',full:true},v=>{p.enabled=v;settingChange();});
      for(const[key,title,min,max,step]of [['distance','Distância',0,150,.1],['side','Deslocamento lateral',-150,150,.1],['height','Altura',-150,150,.1],['fov','Campo de visão',1,130,.1],['transition','Transição (ms)',0,2000,50]])slider(f,title,p[key],min,max,step,v=>{p[key]=v;settingChange();},true,key!=='transition');
      actions(c,button('Pré-visualizar câmera',previewCamera));columns.append(c);
      const help=card('Prévia segura');help.classList.add('admin-camera-stage');help.append(el('p','Distância de 0.0 a 150.0 m; lateral e altura de -150.0 a 150.0 m, relativos à cabeça. FOV de 1.0° a 130.0° (limite do GTA). Os controles aceitam casas decimais; valores como 4.0 e 10.0 também são enviados à câmera como float. Obstáculos podem limitar o movimento e geram aviso. A transição até 2.000 ms vale ao abrir o Pause; a prévia atualiza imediatamente.'));columns.append(help);
    }
    const footer=el('div',undefined,'admin-actions');content.append(footer);
    footer.append(button('Salvar configurações para todos',async()=>{
      clearTimeout(previewTimer);previewRevision++;
      if(validPanel(content)){const r=await save('settings','save',null,S.settings,S.settingsRevision);if(r){S.settings=copy(r.settings);S.base=copy(r.settings);S.settingsRevision=r.revision;S.dirty=false;publishedSettings(S.base,r.revision);theme(S.settings.theme);render();}}
    },'primary'),button('Restaurar padrão Forge',async()=>{
      if(await confirmAction('Restaurar o padrão?','Prepara todos os valores originais. É necessário salvar para publicar.','Preparar padrão')){S.settings=copy(S.defaults);settingChange();render();}
    }),button('Descartar ajustes locais',async()=>{
      if(S.dirty&&!await confirmAction('Descartar configurações?','As alterações ainda não publicadas serão perdidas.'))return;
      S.settings=copy(S.base);S.dirty=false;await api('adminPreview',{kind:'restore'});document.body.classList.remove('admin-camera-preview');theme(S.base.theme);render();
    }));
  }
  function modelGrid(parent,picking=false,select){
    let search=picking?'':S.modelSearch,pageIndex=picking?1:S.modelPage,filter=picking?'active':S.modelFilter;
    const toolbar=el('div',undefined,'admin-toolbar'),searchInput=document.createElement('input');searchInput.placeholder='Buscar por ID, nome ou categoria';searchInput.setAttribute('aria-label',picking?'Buscar ícone para blip':'Buscar catálogo');searchInput.value=search;
    toolbar.append(searchInput);parent.append(toolbar);
    let selector;
    if(!picking){selector=document.createElement('select');selector.setAttribute('aria-label','Filtrar modelos');for(const[v,t]of [['active','Ativos'],['changed','Personalizados'],['deleted','Ocultos'],['all','Todos']]){const o=el('option',t);o.value=v;selector.append(o);}selector.value=filter;toolbar.append(selector);}
    const grid=el('div',undefined,'admin-model-grid'),pagination=el('div',undefined,'admin-pagination');parent.append(grid,pagination);
    function paint(){
      const models=Object.values(S.models).filter(m=>(filter==='all'||filter==='active'&&!m.disabled||filter==='deleted'&&m.disabled||filter==='changed'&&m.edited&&!m.disabled)&&(`${m.id} ${m.name} ${m.group}`).toLowerCase().includes(search.toLowerCase())).sort((a,b)=>Number(a.id)-Number(b.id));
      const pages=Math.max(1,Math.ceil(models.length/48));pageIndex=Math.max(1,Math.min(pageIndex,pages));
      if(!picking){S.modelSearch=search;S.modelPage=pageIndex;S.modelFilter=filter;}
      grid.replaceChildren();
      for(const m of models.slice((pageIndex-1)*48,pageIndex*48)){
        const b=button('',()=>select(m),'admin-model'+(m.disabled?' disabled':''));
        b.append(modelImage(m.id),el('strong',m.name),el('small','#'+m.id+' · '+m.group));
        b.title=`ID: ${m.id}\nNome: ${m.name}\nCategoria: ${m.group}\nImagem: ${m.image}\n${m.original?'Original GTA':'Adicionado'}${m.edited?' · Personalizado':''}`;
        b.setAttribute('aria-label','#'+m.id+' · '+m.name);b.setAttribute('aria-pressed',String(picking?S.pointDraft?.model===m.id:S.modelId===m.id));grid.append(b);
      }
      if(!models.length)grid.append(el('p','Nenhum ícone encontrado.'));
      pagination.replaceChildren(button('Anterior',()=>{pageIndex--;paint();}),el('span',`${models.length} modelos · ${pageIndex}/${pages}`),button('Próxima',()=>{pageIndex++;paint();}));
      pagination.firstElementChild.disabled=pageIndex===1;pagination.lastElementChild.disabled=pageIndex===pages;
    }
    searchInput.addEventListener('input',()=>{search=searchInput.value;pageIndex=1;paint();});
    selector?.addEventListener('change',()=>{filter=selector.value;pageIndex=1;paint();});paint();
  }
  async function chooseModel(m){
    if(modelDirty()&&!await confirmAction('Trocar de modelo?','Descartar as alterações locais deste ícone?'))return;
    S.modelId=m.id;S.modelDraft={name:m.name,group:m.group,image:m.image,disabled:!!m.disabled};S.modelBase=copy(S.modelDraft);render();
  }
  function renderModels(){
    const toolbar=el('div',undefined,'admin-toolbar');toolbar.append(button('Adicionar modelo de ícone',async()=>{
      if(modelDirty()&&!await confirmAction('Criar modelo?','Descartar as alterações do modelo atual?'))return;
      S.modelId=null;S.modelDraft={name:'Novo ícone',group:'Outros',image:'assets/blips/1.png',disabled:false};S.modelBase=null;render();
    },'primary'),el('small','Passe o mouse para ver ID, categoria e imagem. Alterações de ícone são independentes dos pontos.'));content.append(toolbar);
    const layout=el('div',undefined,'admin-catalog-layout'),list=el('div');layout.append(list);modelGrid(list,false,chooseModel);
    const detail=card(S.modelDraft?'Editar modelo':'Detalhes do modelo');detail.classList.add('admin-model-detail');layout.append(detail);content.append(layout);
    if(!S.modelDraft){detail.append(el('p','Selecione um ícone para editar os dados ou substituir a imagem.'));return;}
    const d=S.modelDraft,id=S.modelId;
    const img=document.createElement('img');img.src=d.image;img.alt='Prévia do modelo';detail.append(img);
    const f=fields(detail);let newId;
    if(id===null){let n=966;while(S.models[n])n++;newId=n;field(f,'ID do novo modelo',n,{type:'number',min:0,max:65535,step:1,required:true},v=>{newId=v;});}
    for(const[key,label,max]of [['name','Nome do ícone',100],['group','Categoria do ícone',100],['image','Imagem (arquivo, HTTPS ou ID)',512]])field(f,label,d[key],{maxLength:max,required:true},v=>{d[key]=v;if(key==='image')img.src=S.models[v]?.image||v;indicator();});
    detail.append(el('p',id===null?'Novo modelo do catálogo. Não cria um ponto automaticamente.':`ID / código: ${id}`,'admin-metadata'));
    actions(detail,button('Salvar modelo',async()=>{
      if(!validPanel(detail))return;
      const key=id??newId;if(id===null&&S.models[key]){status('Este ID já existe. Selecione-o para editar.',true);return;}
      const value=copy(d);value.image=S.models[value.image]?.image||value.image;
      const r=await save('model','save',String(key),value,S.modelRevision);
      if(r){S.modelRevision=r.revision;S.models[String(key)]={...value,id:String(key),original:!!S.models[key]?.original,edited:true};S.modelId=String(key);S.modelDraft=copy(value);S.modelBase=copy(value);render();}
    },'primary'));
    if(id!==null)actions(detail,button('Duplicar como novo modelo',async()=>{
      if(modelDirty()&&!await confirmAction('Duplicar ícone?','Usar os dados publicados e descartar as alterações locais?'))return;
      S.modelDraft={name:S.models[id].name,group:S.models[id].group,image:S.models[id].image,disabled:false};S.modelBase=null;S.modelId=null;render();
    }),button(d.disabled?'Restaurar modelo':'Ocultar modelo',async()=>{
      if(!await confirmAction(d.disabled?'Restaurar ícone?':'Ocultar ícone?',d.disabled?'Restaura os dados originais se for um modelo GTA.':'Os pontos que usam este ícone serão ocultos, sem apagar os registros.',d.disabled?'Restaurar':'Ocultar'))return;
      const r=await save('model',d.disabled?'restore':'delete',id,null,S.modelRevision);
      if(r){S.modelDraft=null;await reloadCatalog();}
    },'admin-danger'),button('Restaurar original',async()=>{
      if(!await confirmAction('Restaurar modelo?','Remove as personalizações do ícone original.','Restaurar'))return;
      const r=await save('model','restore',id,null,S.modelRevision);if(r){S.modelDraft=null;await reloadCatalog();}
    }));
  }
  function newPoint(){return {name:'Novo local',group:'Outros',model:'1',nativeSprite:1,pos:copy(S.position),scale:.9,color:0,alpha:255,rotation:0,display:2,enabled:true,shortRange:true,flash:false,mapGround:true,mapOffset:.15,zone:{mode:'none',radius:50,width:100,height:100,rotation:0,color:1,alpha:80}};}
  function normalizeDraft(point){const p=copy(point);p.mapGround=p.mapGround!==false;p.mapOffset=p.mapOffset??.15;p.zone={mode:'none',radius:50,width:100,height:100,rotation:0,color:1,alpha:80,...p.zone};return p;}
  async function editPoint(id,duplicate=false){
    if(pointDirty()&&!await confirmAction('Trocar de blip?','O rascunho atual não foi publicado.'))return;
    S.pointId=duplicate?null:id;S.pointDraft=id?normalizeDraft(S.points[id]):newPoint();S.pointBase=id&&!duplicate?copy(S.pointDraft):null;render();canvas?.center(S.pointDraft.pos);queuePreview();
  }
  function queuePreview(){
    clearTimeout(previewTimer);const epoch=S.epoch;
    previewTimer=setTimeout(()=>{if(epoch===S.epoch&&currentPage==='admin'&&S.pointDraft)api('adminPreview',{kind:'point',value:S.pointDraft});},220);
  }
  function pointChanged(){indicator();canvas?.setState(S.points,S.pointDraft,S.models,S.colors,S.pointId);queuePreview();}
  function syncCoordinates(){for(const axis of ['x','y','z'])if(coordinateInputs[axis])coordinateInputs[axis].value=S.pointDraft.pos[axis];}
  function picker(){
    if(dialogOpen)return;dialogOpen=true;
    const d=el('dialog',undefined,'admin-dialog admin-picker');d.append(el('h3','Escolher ícone do catálogo'));
    const end=()=>{d.close();d.remove();dialogOpen=false;};
    modelGrid(d,true,m=>{const p=S.pointDraft;p.model=m.id;if(Number(m.id)<=965)p.nativeSprite=Number(m.id);if(p.name==='Novo local'){p.name=m.name;p.group=m.group;}end();render();pointChanged();});
    actions(d,button('Cancelar escolha',end));d.addEventListener('cancel',e=>{e.preventDefault();end();});root.append(d);d.showModal();
  }
  function renderPoints(){
    const studio=el('div',undefined,'admin-studio'),list=el('div',undefined,'admin-point-list'),editorShell=el('div',undefined,'admin-point-editor-shell'),editor=el('div',undefined,'admin-point-editor'),map=el('div',undefined,'admin-map-wrap');editorShell.append(editor);studio.append(list,editorShell,map);content.append(studio);
    const toolbar=el('div',undefined,'admin-toolbar');toolbar.append(button('+ Criar blip',()=>editPoint(null),'primary'));
    const search=document.createElement('input');search.value=S.pointSearch;search.placeholder='Buscar pontos';search.setAttribute('aria-label','Buscar pontos');toolbar.append(search);list.append(toolbar);
    const records=el('div');list.append(records);
    function paintList(){records.replaceChildren();const entries=Object.entries(S.points).filter(([id,p])=>(id+' '+p.name+' '+p.group).toLowerCase().includes(S.pointSearch.toLowerCase()));
      records.append(el('p',entries.length+' pontos registrados','admin-note'));
      for(const[id,p]of entries){const b=button('',()=>editPoint(id),'admin-point-row'),span=el('span');span.append(el('strong',p.name),el('small',id+(p.enabled?'':' · Desativado')));b.append(modelImage(p.model),span);b.setAttribute('aria-pressed',String(S.pointId===id));b.title=`${p.group}\nModelo #${p.model}\n${p.pos.x}, ${p.pos.y}, ${p.pos.z}`;records.append(b);}}
    search.addEventListener('input',()=>{S.pointSearch=search.value;paintList();});paintList();
    const c=document.createElement('canvas');map.append(c);canvas=new window.ForgeBlipCanvas(c,(x,y)=>{if(!S.pointDraft)return;S.pointDraft.pos.x=Number(x.toFixed(3));S.pointDraft.pos.y=Number(y.toFixed(3));syncCoordinates();pointChanged();},id=>editPoint(id));
    canvas.setState(S.points,S.pointDraft,S.models,S.colors,S.pointId);canvas.center(S.pointDraft?.pos||S.position);
    const tools=el('div',undefined,'admin-map-tools');tools.append(button('+',()=>canvas.zoomAt(1.3)),button('−',()=>canvas.zoomAt(1/1.3)),button('Centralizar blip',()=>canvas.center(S.pointDraft?.pos||S.position)));map.append(tools);
    const caption=el('div',undefined,'admin-map-caption');caption.append(el('strong','PRÉVIA EM TEMPO REAL'),el('div','Arraste o ícone ou clique para posicionar · Arraste o fundo para mover · Roda: zoom · Setas: ajuste fino · Shift: 1 metro'));map.append(caption);
    if(!S.pointDraft){editor.append(el('h3','Blips e zonas'),el('p','Escolha um ponto na lista ou no mapa para editar. Crie um novo para escolher um ícone e arrastá-lo até o local desejado.'),el('p','Os rascunhos são locais. Só Salvar e publicar altera o mapa de todos.','admin-note'));return;}
    const p=S.pointDraft;editor.append(el('h3',S.pointId?'Editar blip':'Novo blip'));
    const previewCard=el('div',undefined,'admin-model-preview'),label=el('span');label.append(el('strong',S.models[p.model]?.name||'Ícone'),el('small','Modelo #'+p.model));previewCard.append(modelImage(p.model),label,button('Escolher',picker));editor.append(previewCard);
    const f=fields(editor);coordinateInputs={};
    field(f,'Nome do ponto',p.name,{full:true,maxLength:100,required:true},v=>{p.name=v;pointChanged();});field(f,'Categoria',p.group,{full:true,maxLength:100,required:true},v=>{p.group=v;pointChanged();});
    for(const axis of ['x','y','z'])coordinateInputs[axis]=field(f,'Coordenada '+axis.toUpperCase(),p.pos[axis],{type:'number',min:axis==='z'?-2000:axis==='x'?-10000:-15000,max:axis==='z'?2000:axis==='x'?10000:15000,step:'any'},v=>{p.pos[axis]=v;pointChanged();});
    actions(editor,...[['Minha posição','player'],['Usar GPS','waypoint']].map(([label,mode])=>button(label,async()=>{const r=await api('adminPosition',{mode});if(r?.ok){Object.assign(p.pos,r.position);syncCoordinates();pointChanged();canvas.center(p.pos);if(r.message)status(r.message);}else status(r?.message||'Posição indisponível.',true);}))); 
    const appearance=el('details');appearance.open=true;appearance.append(el('summary','Aparência do blip'));editor.append(appearance);const a=fields(appearance);
    slider(a,'Tamanho do blip',p.scale,.1,10,.1,v=>{p.scale=v;pointChanged();},true);slider(a,'Opacidade do blip',p.alpha,0,255,1,v=>{p.alpha=v;pointChanged();});slider(a,'Rotação do blip',p.rotation,0,359,1,v=>{p.rotation=v;pointChanged();});
    colorField(a,'Cor GTA (minimapa)',p.color,v=>{p.color=v;pointChanged();});
    field(a,'Exibir em',p.display,{full:true,choices:[[2,'Mapa e minimapa'],[3,'Somente mapa'],[5,'Somente minimapa']]},v=>{p.display=Number(v);pointChanged();});
    field(a,'Sprite GTA no minimapa',p.nativeSprite,{type:'number',min:0,max:965,step:1,full:true},v=>{p.nativeSprite=v;pointChanged();});
    for(const[key,label]of [['enabled','Ponto ativado'],['shortRange','Curto alcance'],['flash','Piscar no radar']])field(a,label,p[key],{type:'checkbox',full:true},v=>{p[key]=v;pointChanged();});
    appearance.append(el('p','O mapa Forge usa a imagem do catálogo. A cor GTA e o sprite nativo são aplicados no radar, sem substituir texturas de outros recursos.','admin-note'));
    const ground=el('details');ground.open=true;ground.append(el('summary','Posição visual no mapa 3D'));editor.append(ground);const g=fields(ground);
    field(g,'Colar ao chão no mapa 3D',p.mapGround,{type:'checkbox',full:true},v=>{p.mapGround=v;pointChanged();});
    slider(g,'Ajuste de altura no mapa 3D (m)',p.mapOffset,-150,150,.05,v=>{p.mapOffset=v;pointChanged();},true,true);
    ground.append(el('p','Ativado: usa o chão do local, mesmo que o ponto tenha sido criado de um telhado. Desativado: usa a coordenada Z salva, útil para andares e helipontos. O ajuste altera apenas o mapa 3D, sem mover o blip no radar.','admin-note'));
    const zone=el('details');zone.open=true;zone.append(el('summary','Zona no mapa'));editor.append(zone);const z=fields(zone);
    field(z,'Formato da zona',p.zone.mode,{full:true,choices:[['none','Sem zona'],['radius','Círculo'],['area','Retângulo']]},v=>{p.zone.mode=v;render();pointChanged();});
    if(p.zone.mode!=='none'){
      if(p.zone.mode==='radius')slider(z,'Raio da zona (m)',p.zone.radius,1,2000,1,v=>{p.zone.radius=v;pointChanged();},true);
      else{slider(z,'Largura da zona (m)',p.zone.width,1,4000,1,v=>{p.zone.width=v;pointChanged();},true);slider(z,'Altura da zona (m)',p.zone.height,1,4000,1,v=>{p.zone.height=v;pointChanged();},true);}
      slider(z,'Rotação da zona',p.zone.rotation,0,359,1,v=>{p.zone.rotation=v;pointChanged();});slider(z,'Opacidade da zona',p.zone.alpha,0,255,1,v=>{p.zone.alpha=v;pointChanged();});
      colorField(z,'Cor da zona',p.zone.color,v=>{p.zone.color=v;pointChanged();});
    }
    zone.append(el('p','Área visual de mapa. Não cria regras de Safe Zone, colisão, dano ou despacho.','admin-note'));
    const footer=actions(editorShell,button('Salvar e publicar',async()=>{
      if(!validPanel(editor))return;
      for(const[key,label]of [['name','Nome do ponto'],['group','Categoria']])if(!p[key].trim()){invalidField(editor.querySelector(`[aria-label="${label}"]`),'preencha este campo.');return;}
      if(!S.writable){status('O arquivo de pontos está inválido. Nenhuma gravação foi feita.',true);return;}
      clearTimeout(previewTimer);const r=await save('point','save',S.pointId,p,S.pointRevision);
      if(r){S.points=r.points;S.pointRevision=r.revision;S.pointId=r.id;S.pointDraft=normalizeDraft(r.points[r.id]);S.pointBase=copy(S.pointDraft);render();}
    },'primary'),button('Descartar rascunho',async()=>{
      if(pointDirty()&&!await confirmAction('Descartar blip?','A versão publicada não será alterada.'))return;
      S.pointDraft=S.pointBase=null;clearTimeout(previewTimer);await api('adminPreview',{kind:'clear'});render();
    }));
    footer.classList.add('admin-point-footer');
    if(S.pointId)actions(editor,button('Duplicar',()=>editPoint(S.pointId,true)),button(S.points[S.pointId].enabled?'Desativar':'Ativar',async()=>{
      const r=await save('point','toggle',S.pointId,null,S.pointRevision);if(r){S.points=r.points;S.pointRevision=r.revision;S.pointDraft=normalizeDraft(r.points[S.pointId]);S.pointBase=copy(S.pointDraft);render();}
    }),button('Excluir blip',async()=>{
      if(!await confirmAction('Excluir '+p.name+'?','Remove somente este ponto e sua zona, sem apagar o ícone do catálogo.','Excluir ponto'))return;
      const r=await save('point','delete',S.pointId,null,S.pointRevision);if(r){S.points=r.points;S.pointRevision=r.revision;S.pointDraft=S.pointBase=null;render();}
    },'admin-danger'));
  }
  async function allowLeave(){
    if(dialogOpen||S.busy)return false;
    if(dirty()&&!await confirmAction('Sair da administração?','As alterações ainda não publicadas serão descartadas.'))return false;
    clearTimeout(previewTimer);++S.epoch;
    await api('adminEnd');document.body.classList.remove('admin-camera-preview');if(S.base)theme(preview?S.base.theme:config.theme);S.dirty=false;S.pointDraft=S.modelDraft=null;return true;
  }
  window.ForgeAdmin={allowLeave,forceClose(){clearTimeout(previewTimer);++S.epoch;S.pointDraft=S.modelDraft=null;S.dirty=false;root.hidden=true;root.querySelectorAll('dialog').forEach(d=>d.remove());dialogOpen=false;document.body.classList.remove('admin-camera-preview');if(S.base)theme(preview?S.base.theme:config.theme);}};
  $('admin-back').addEventListener('click',()=>page('home'));
  $('admin-refresh').addEventListener('click',async()=>{if(dirty()&&!await confirmAction('Atualizar administração?','Descartar rascunhos e carregar os dados publicados mais recentes?'))return;clearTimeout(previewTimer);previewRevision++;document.body.classList.remove('admin-camera-preview');await api('adminPreview',{kind:'restore'});load();});
  $('admin-parent').addEventListener('click',async()=>{if(dirty()&&!await confirmAction('Voltar ao Admin Forge?','Os rascunhos não publicados serão descartados.'))return;clearTimeout(previewTimer);const r=await api('adminEnd',{parent:true});if(r?.ok&&preview)page('home');});
  document.addEventListener('keydown',e=>{if(currentPage==='admin'&&(dialogOpen||['INPUT','SELECT','TEXTAREA'].includes(e.target.tagName))&&e.key!=='Escape')e.stopPropagation();},true);
  window.addEventListener('forge-admin-page',()=>{root.hidden=false;load();});
  window.addEventListener('message',e=>{
    if(currentPage!=='admin')return;
    if(e.data?.action==='portraitPreview'&&S.tab==='camera'&&document.body.classList.contains('admin-camera-preview')){document.body.classList.remove('admin-camera-preview');status(e.data.message||'Prévia da câmera encerrada.',true);}
    if(e.data?.action==='blipModels'&&e.data.revision>S.modelRevision)status('O catálogo foi atualizado. Use Atualizar antes de editar os modelos novamente.');
    if(e.data?.action==='mapWorld')status('Os pontos publicados foram atualizados. Use Atualizar para carregar a lista mais recente.');
  });
  if(currentPage==='admin'){root.hidden=false;load();}
})();
