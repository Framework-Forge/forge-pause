// Local map projection is shared with the Pause map (2.2 metres per image pixel).
(() => {
  class BlipCanvas {
    constructor(canvas,onMove,onSelect){
      this.canvas=canvas;this.ctx=canvas.getContext('2d');this.onMove=onMove;this.onSelect=onSelect;
      this.cx=1884;this.cy=3821;this.zoom=.45;this.points={};this.models={};this.colors={};this.icons=new Map();
      this.map=new Image();this.map.onload=()=>this.draw();this.map.src='assets/map.webp';
      this.observer=new ResizeObserver(()=>this.draw());this.observer.observe(canvas);
      canvas.tabIndex=0;canvas.setAttribute('aria-label','Mapa do editor. Arraste o ícone, clique para posicionar, roda para zoom. Setas movem o blip; Shift aumenta o passo.');
      canvas.addEventListener('pointerdown',e=>{
        if(e.button!==0&&e.button!==2)return;
        const p=this.pointer(e),hit=this.hit(p);this.drag={start:p,last:p,moved:false,marker:!!this.draft&&hit==='draft',button:e.button};
        canvas.setPointerCapture(e.pointerId);e.preventDefault();
      });
      canvas.addEventListener('pointermove',e=>{
        const p=this.pointer(e);
        if(!this.drag){canvas.style.cursor=this.hit(p)?'pointer':'grab';return;}
        if(Math.hypot(p.x-this.drag.start.x,p.y-this.drag.start.y)>3)this.drag.moved=true;
        if(this.drag.marker&&this.drag.button===0)this.moveAt(p);
        else{this.cx-=(p.x-this.drag.last.x)/this.zoom;this.cy-=(p.y-this.drag.last.y)/this.zoom;this.draw();}
        this.drag.last=p;
      });
      canvas.addEventListener('pointerup',e=>{
        const drag=this.drag;this.drag=null;if(!drag)return;
        if(!drag.moved&&drag.button===0){const p=this.pointer(e),hit=this.hit(p);if(hit&&hit!=='draft')this.onSelect?.(hit);else if(this.draft)this.moveAt(p);}
      });
      canvas.addEventListener('pointercancel',()=>{this.drag=null;});
      canvas.addEventListener('contextmenu',e=>e.preventDefault());
      canvas.addEventListener('wheel',e=>{e.preventDefault();this.zoomAt(e.deltaY<0?1.18:1/1.18,this.pointer(e));},{passive:false});
      canvas.addEventListener('keydown',e=>{
        if(!this.draft||!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))return;
        e.preventDefault();e.stopPropagation();const n=e.shiftKey?1:.1,p=this.draft.pos;
        this.onMove(this.limit(p.x+(e.key==='ArrowLeft'?-n:e.key==='ArrowRight'?n:0),10000),this.limit(p.y+(e.key==='ArrowDown'?-n:e.key==='ArrowUp'?n:0),15000));
      });
    }
    limit(n,max){return Math.max(-max,Math.min(max,n));}
    pointer(e){const r=this.canvas.getBoundingClientRect();return{x:e.clientX-r.left,y:e.clientY-r.top};}
    toScreen(p){return{x:(1884+p.x/2.2-this.cx)*this.zoom+this.width/2,y:(3821-p.y/2.2-this.cy)*this.zoom+this.height/2};}
    fromScreen(p){return{x:(this.cx+(p.x-this.width/2)/this.zoom-1884)*2.2,y:(3821-this.cy-(p.y-this.height/2)/this.zoom)*2.2};}
    moveAt(p){const w=this.fromScreen(p);this.onMove(this.limit(w.x,10000),this.limit(w.y,15000));}
    zoomAt(factor,p={x:this.width/2,y:this.height/2}){
      const before=this.fromScreen(p);this.zoom=Math.max(.06,Math.min(6,this.zoom*factor));
      this.cx=1884+before.x/2.2-(p.x-this.width/2)/this.zoom;this.cy=3821-before.y/2.2-(p.y-this.height/2)/this.zoom;this.draw();
    }
    center(p){this.cx=1884+p.x/2.2;this.cy=3821-p.y/2.2;this.draw();}
    setState(points,draft,models,colors,editingId){Object.assign(this,{points,draft,models,colors,editingId:draft?editingId:null});this.draw();}
    image(point){
      const model=this.models[String(point.model)],src=model?.image||'assets/blips/'+point.model+'.png';
      if(!this.icons.has(src)){const img=new Image();img.onload=()=>this.draw();img.src=src;this.icons.set(src,img);}
      return this.icons.get(src);
    }
    zone(point){
      const z=point.zone;if(!z||z.mode==='none')return;
      const c=this.ctx,p=this.toScreen(point.pos),unit=this.zoom/2.2;
      c.save();c.translate(p.x,p.y);c.rotate(-(z.rotation||0)*Math.PI/180);c.beginPath();
      if(z.mode==='radius')c.arc(0,0,z.radius*unit,0,Math.PI*2);else c.rect(-z.width*unit/2,-z.height*unit/2,z.width*unit,z.height*unit);
      c.fillStyle=this.colors[z.color]?.color||'#FF7A1A';c.strokeStyle=c.fillStyle;c.globalAlpha=z.alpha/255;c.fill();c.globalAlpha=Math.min(1,z.alpha/255+.25);c.lineWidth=1.5;c.stroke();c.restore();
    }
    marker(point,id,selected){
      const c=this.ctx,p=this.toScreen(point.pos),size=26*point.scale,img=this.image(point);
      c.save();c.translate(p.x,p.y);c.rotate(point.rotation*Math.PI/180);c.globalAlpha=point.alpha/255*(point.enabled?1:.35);
      if(img.complete&&img.naturalWidth)c.drawImage(img,-size/2,-size/2,size,size);
      else{c.fillStyle=this.colors[point.color]?.color||'#fff';c.beginPath();c.arc(0,0,size/3,0,Math.PI*2);c.fill();}
      c.restore();
      if(selected){c.save();c.strokeStyle='#FF7A1A';c.lineWidth=2;c.setLineDash([4,3]);c.beginPath();c.arc(p.x,p.y,Math.max(18,size/2+5),0,Math.PI*2);c.stroke();c.restore();}
      this.hits.push({id,x:p.x,y:p.y,radius:Math.max(15,size/2)});
      if(selected){c.font='12px Inter, sans-serif';c.textAlign='center';c.fillStyle='#fff';c.shadowColor='#000';c.shadowBlur=5;c.fillText(point.name||'Rascunho',p.x,p.y-Math.max(24,size/2+12));c.shadowBlur=0;}
    }
    hit(p){return(this.hits||[]).slice().reverse().find(h=>Math.hypot(p.x-h.x,p.y-h.y)<h.radius)?.id;}
    draw(){
      const r=this.canvas.getBoundingClientRect();if(!r.width||!r.height)return;
      this.width=r.width;this.height=r.height;const dpr=Math.min(window.devicePixelRatio||1,2);
      this.canvas.width=Math.round(r.width*dpr);this.canvas.height=Math.round(r.height*dpr);
      const c=this.ctx;c.setTransform(dpr,0,0,dpr,0,0);c.fillStyle='#183143';c.fillRect(0,0,r.width,r.height);
      if(this.map.complete&&this.map.naturalWidth)c.drawImage(this.map,r.width/2-this.cx*this.zoom,r.height/2-this.cy*this.zoom,4096*this.zoom,6144*this.zoom);
      this.hits=[];
      for(const[id,p]of Object.entries(this.points||{}))if(id!==this.editingId&&p.enabled)this.zone(p);
      if(this.draft)this.zone(this.draft);
      for(const[id,p]of Object.entries(this.points||{}))if(id!==this.editingId&&p.enabled)this.marker(p,id,false);
      if(this.draft)this.marker(this.draft,'draft',true);
      c.font='11px Inter, sans-serif';c.fillStyle='#fff';c.textAlign='left';c.fillText('100 m',20,r.height-23);c.fillRect(20,r.height-17,100/2.2*this.zoom,2);
    }
  }
  window.ForgeBlipCanvas=BlipCanvas;
})();
