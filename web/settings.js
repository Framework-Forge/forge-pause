(() => {
  const style = document.createElement('link'); style.rel = 'stylesheet'; style.href = 'settings.css'; document.head.append(style);
  const workspace = document.createElement('section'); workspace.id = 'settings-workspace'; workspace.hidden = true;
  const header = document.createElement('header'); header.innerHTML = '<button type="button" id="settings-back">← Voltar</button><span>FORGE / CONFIGURAÇÕES</span><small>VALORES DO JOGO & PREFERÊNCIAS LOCAIS</small>';
  const tabs = document.createElement('div'); tabs.className = 'settings-tabs'; tabs.setAttribute('role','tablist');
  const columns = document.createElement('div'); columns.className = 'settings-columns';
  const list = document.createElement('div'); list.className = 'settings-list';
  const details = document.createElement('article'); details.className = 'settings-details'; details.setAttribute('aria-live','polite');
  let selectedKey='',selectedPage='';
  columns.append(list,details); workspace.append(header,tabs,columns); document.getElementById('shell').append(workspace);
  const ids = ['controller','keys','audio','camera','display','graphics','presets','game','voice','hud','filters','interface'];
  for (const id of ids) {
    const button = text('button',titles['settings.'+id]); button.dataset.page = 'settings.'+id; button.setAttribute('role','tab');
    button.addEventListener('click',()=>page('settings.'+id)); tabs.append(button);
  }
  header.querySelector('button').addEventListener('click',back);
  tabs.addEventListener('keydown',e=>{
    if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;
    e.preventDefault();const buttons=[...tabs.querySelectorAll('button')];let i=buttons.indexOf(document.activeElement);
    i=e.key==='Home'?0:e.key==='End'?buttons.length-1:(i+(e.key==='ArrowRight'?1:-1)+buttons.length)%buttons.length;
    buttons[i].focus();buttons[i].click();
  });
  function select(row) {
    selectedKey=row.dataset.settingKey||row.querySelector('strong')?.textContent||'';selectedPage=currentPage;
    list.querySelectorAll('.selected-setting').forEach(el=>el.classList.remove('selected-setting')); row.classList.add('selected-setting');
    details.replaceChildren();
    const label = row.querySelector('strong')?.textContent || row.textContent;
    details.append(text('small',titles[currentPage] || 'CONFIGURAÇÕES','eyebrow'),text('h2',label));
    if(row.classList.contains('read-setting')) {
      details.append(text('strong',row.querySelector('span')?.textContent || '—','detail-value'));
      details.append(text('p','Configuração original do jogo. Para alterar este valor, abra as configurações do GTA. Ao voltar, o valor será atualizado nesta tela.'));
      const meter=row.querySelector('.segment-bars');if(meter)details.append(meter.cloneNode(true));
      const edit=text('button','Alterar nas configurações do GTA','gta-settings-action');
      edit.addEventListener('click',()=>request('nativeSettings',{page:currentPage}));details.append(edit);
      details.append(text('span','O GTA abrirá na aba Configurações. Selecione a categoria correspondente.','setting-badge'));
    } else if(row._preset){
      const preset=row._preset;
      details.append(text('strong','Aplicar','detail-value'),text('p','Aplique esta combinação de ajustes visuais.'));
      const descriptions={lod:'Distância de detalhes',lights:'Luzes distantes',budget:'Orçamento de modelos',shadows:'Sombras',clean:'Limpeza de marcas'};
      const values={normal:'Normal',reduced:'Reduzido',high:'Alta',medium:'Média',low:'Baixa',off:'OFF',true:'ON',false:'OFF'};
      const summary=document.createElement('ul');summary.className='preset-summary';
      for(const [key,value] of Object.entries(preset.options))summary.append(text('li','✓ '+descriptions[key]+': '+(values[value]??(key==='lod'?value+'×':value))));
      const apply=text('button','Aplicar esta predefinição','gta-settings-action');apply.addEventListener('click',preset.apply);details.append(summary,apply);
    } else {
      const setting=row._setting;
      const value=setting?.display();
      if(value!==undefined)details.append(text('strong',String(value),'detail-value'));
      const meter=row.querySelector('.segment-bars');if(meter)details.append(meter.cloneNode(true));
      details.append(text('p',setting?.disabled?'Esta integração não está disponível no momento.':'Use as setas laterais ou ← → no teclado para ajustar. As preferências são salvas neste computador.'));
      if(setting?.choices){const choices=document.createElement('div');choices.className='setting-choices';for(const [value,label] of setting.choices){const button=text('button',label);button.classList.toggle('active',String(value)===String(setting.value));button.disabled=setting.disabled;button.addEventListener('click',()=>setting.set(value));choices.append(button);}details.append(choices);}
      details.append(text('span',setting?.disabled?'INTEGRAÇÃO INDISPONÍVEL':'AJUSTE DO FORGE PAUSE','setting-badge'));
    }
  }
  function layout() {
    const active=currentPage.startsWith('settings'); workspace.hidden=!active;
    const submenu=$('submenu');
    if(!active){$('stack').append(submenu);return;}
    list.append(submenu);
    tabs.querySelectorAll('button').forEach(button=>{const selected=button.dataset.page===currentPage;button.classList.toggle('active',selected);button.setAttribute('aria-selected',String(selected));});
    const rows=[...submenu.children];
    for(const row of rows){
      if(row.dataset.max){const meter=document.createElement('div');meter.className='segment-bars read-meter';meter.setAttribute('aria-hidden','true');const fraction=Math.max(0,Math.min(1,Number(row.dataset.value)/Number(row.dataset.max)));for(let i=0;i<20;i++){const bar=document.createElement('i');bar.classList.toggle('filled',i<Math.round(fraction*20));meter.append(bar);}row.insertBefore(meter,row.querySelector('span'));}
      row.addEventListener('focusin',()=>select(row));row.addEventListener('pointerenter',()=>select(row));row.addEventListener('click',()=>select(row));row.addEventListener('input',()=>select(row));row.addEventListener('settingchange',()=>select(row));if(row.classList.contains('read-setting')){row.tabIndex=0;row.setAttribute('aria-label',row.textContent);row.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();request('nativeSettings',{page:currentPage});}});}
    }
    const previous=selectedPage===currentPage&&rows.find(row=>(row.dataset.settingKey||row.querySelector('strong')?.textContent||'')===selectedKey);
    if(previous||rows[0])select(previous||rows[0]);else details.replaceChildren(text('p','Escolha uma categoria acima.'));
  }
  window.addEventListener('forge-settings-page',layout);
  list.addEventListener('keydown',e=>{
    if(!['ArrowUp','ArrowDown'].includes(e.key))return;
    const rows=[...$('submenu').children].filter(row=>row.matches('.stack-setting,.read-setting,.preset-setting,.sub-action'));
    const current=e.target.closest('.stack-setting,.read-setting,.preset-setting,.sub-action');const index=rows.indexOf(current);
    if(index<0||!rows.length)return;e.preventDefault();const next=rows[(index+(e.key==='ArrowDown'?1:-1)+rows.length)%rows.length];next.focus();select(next);next.scrollIntoView({block:'nearest'});
  });
  let refreshing=false;
  setInterval(async()=>{
    if(document.body.hidden||!currentPage.startsWith('settings')||preview||refreshing)return;
    refreshing=true;
    try {const result=await request('gameInfo');if(result?.ok&&result.game){game=result.game;const focused=document.activeElement;if(!list.contains(focused)&&!details.contains(focused)&&!list.matches(':hover')&&!details.matches(':hover')){render();layout();}}}finally{refreshing=false;}
  },2500);
  layout();
})();
