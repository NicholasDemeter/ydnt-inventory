function parseCSV(text){
  const rows=[]; let row=[], field=''; let inQuotes=false; let i=0;
  while(i<text.length){
    const c=text[i];
    if(c==='\"'){
      if(inQuotes && text[i+1]==='\"'){ field+='\"'; i+=2; continue; }
      inQuotes=!inQuotes; i++; continue;
    }
    if(!inQuotes && (c===',')){ row.push(field); field=''; i++; continue; }
    if(!inQuotes && (c==='\n' || c==='\r')){
      if(c==='\r' && text[i+1]==='\n') i++;
      row.push(field); rows.push(row); row=[]; field=''; i++; continue;
    }
    field+=c; i++;
  }
  if(field.length>0 || row.length>0){ row.push(field); rows.push(row); }
  if(rows.length===0) return [];
  const headers = rows[0].map(h=>h.trim());
  return rows.slice(1).filter(r=>r.some(x=>String(x||'').trim().length)).map(r=>{
    const o={}; headers.forEach((h,idx)=>o[h]=r[idx]!==undefined?r[idx]:''); return o;
  });
}
function pick(v,...alts){for(const k of [v,...alts]){if(k!==undefined&&k!==null&&String(k).trim()!=='')return String(k).trim()}return''}
function enc(p){return encodeURI(p)}
function thumb(folder){return enc(`/${folder}/Photos/thumb.jpg`)}
async function readCSV(path){const r=await fetch(path); if(!r.ok) throw new Error('CSV '+r.status); const t=await r.text(); return parseCSV(t);}
function missingBadge(){const s=document.createElement('span'); s.className='badge'; s.textContent='asset missing'; return s;}
function card(row){
  const lot=pick(row.LOT,row.lot,row['Lot']);
  const folder=pick(row.FOLDER_NAME,row.folder_name,row.folderName,row['FOLDER NAME']);
  const name=pick(row.OFFICIAL_NAME,row.Name,row.name, lot||folder||'');
  const price=pick(row.PRICE,row.price,'');
  const a=document.createElement('a'); a.href=`detail.html?lot=${encodeURIComponent(lot)}`;
  const c=document.createElement('div'); c.className='card';
  const img=document.createElement('img'); img.className='thumb'; img.loading='lazy';
  let triedUpper=false; img.onerror=()=>{ if(!triedUpper){ triedUpper=true; img.src=img.src.replace(/thumb\.jpg$/,'thumb.JPG'); } else { img.replaceWith(missingBadge()); } };
  img.src=thumb(folder);
  const meta=document.createElement('div'); meta.className='meta';
  meta.innerHTML = `<div class="name">${name}</div><div class="sub">${lot}${price?` · ${price}`:''}</div>`;
  c.append(img,meta); a.append(c); return a;
}
function renderGrid(rows){
  const root=document.querySelector('.grid'); root.innerHTML='';
  const q=(new URLSearchParams(location.search).get('q')||'').toLowerCase();
  rows.filter(r=>{ if(!q) return true; const hay=[r.LOT,r.FOLDER_NAME,r.OFFICIAL_NAME,r.DESCRIPTION,r.CATEGORY].map(x=>String(x||'').toLowerCase()).join(' '); return hay.includes(q); })
      .forEach(r=>root.append(card(r)));
}
async function boot(){
  try{ const rows=await readCSV('data/products.csv'); window.__rows=rows; renderGrid(rows); const s=document.getElementById('search'); if(s) s.addEventListener('input',e=>{renderGrid(rows)}); hydrateHero(); }
  catch(e){ console.error(e); document.querySelector('.grid').innerHTML='<div class="badge">csv load failed</div>'; }
}
function heroCandidates(){ const base='/Carousel_HERO'; return ['1.jpg','2.jpg','3.jpg','1.JPG','2.JPG','3.JPG'].map(n=>base+'/'+n); }
function imgExists(src){return new Promise(res=>{ const i=new Image(); i.onload=()=>res(true); i.onerror=()=>res(false); i.src=src; });}
async function hydrateHero(){ const hero=document.querySelector('.hero'); if(!hero) return; const cand=heroCandidates(); const good=[]; for(const c of cand){ if(await imgExists(c)) good.push(c); } if(good.length===0){ hero.style.display='none'; return; } good.forEach((src,idx)=>{ const im=document.createElement('img'); im.src=src; if(idx===0) im.classList.add('active'); hero.append(im); }); const dots=document.createElement('div'); dots.className='dots'; hero.append(dots); good.forEach((_,i)=>{ const d=document.createElement('div'); d.className='dot'+(i===0?' active':''); dots.append(d); }); let cur=0; setInterval(()=>{ const imgs=[...hero.querySelectorAll('img')]; const ds=[...hero.querySelectorAll('.dot')]; imgs[cur].classList.remove('active'); ds[cur].classList.remove('active'); cur=(cur+1)%good.length; imgs[cur].classList.add('active'); ds[cur].classList.add('active'); },3500); }
document.addEventListener('DOMContentLoaded', boot);