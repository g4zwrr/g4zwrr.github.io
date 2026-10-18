/* pages.js — per-page init, dispatched by body[data-page].
   Home: hero typewriter, ID card live data, routes hints, projects carousel +
   stats + lang bar + activity, stack bento filter, stat-img fallback, beat
   reactions (rate-limited micro-glitch ≤1/4s). Subpages: projects / project /
   stack / about / contact / 404. */
(function(){
"use strict";
var G = window.G4;
G.initPages = function(){
  var page = document.body.dataset.page;
  // shared: register visualizer canvases
  [["specEdge","edge"],["dockViz","dock"],["heroViz","hero"]].forEach(function(p){
    var c=document.getElementById(p[0]); if(c) G.viz.register(c,{kind:p[1]});
  });
  var sv = G.store.get("g4_audio",null);
  if(sv && sv.vizMode!=null) G.viz.setMode(sv.vizMode); // else keep viz.js default (SCOPE)
  heroType(); idCard(); beatReactions();
  if(page==="home") home();
  else if(page==="projects") projects();
  else if(page==="project") project();
  else if(page==="stack") stack();
  else if(page==="about") about();
};
function heroType(){
  var q = document.getElementById("typeq"); if(!q) return;
  var full = "“"+G.CONFIG.quote+"”";
  if(G.fxOff()){ q.textContent = full; return; }
  var i=0; (function t(){ if(i<=full.length){ q.textContent=full.slice(0,i); i++; setTimeout(t,28); } })();
  // random hero letter glitch ~4.2s while in view
  var h1 = document.getElementById("heroTitle");
  setInterval(function(){
    if(!h1||document.hidden||G.fxOff()) return;
    var r=h1.getBoundingClientRect(); if(r.bottom<0||r.top>innerHeight) return;
    G.glitch(h1,{ms:200});
  }, 4200);
}
function idCard(){
  var el = document.getElementById("idGithub"); if(!el) return;
  el.innerHTML = '<span class="skel" style="display:block;min-height:20px"></span>';
  G.github.user().then(function(u){
    return G.github.repos().then(function(r){
      el.textContent = r.length+" REPOS · "+u.followers+" FOLLOWERS · SINCE "+new Date(u.created_at).getFullYear();
    });
  }).catch(function(){ el.textContent = "OFFLINE — GITHUB UNREACHABLE"; });
  var lt = document.getElementById("idTime");
  if(lt) setInterval(function(){ lt.textContent=new Date().toLocaleTimeString([],{hour12:false}); },1000);
}
function beatReactions(){
  var lastMicro = 0;
  G.viz.onBeat(function(){
    // logo flicker, ghost pulse, VU flash — cheap, always
    var logo = document.querySelector(".logo b");
    if(logo && !G.fxOff()){ logo.style.opacity="0.4";
      setTimeout(function(){logo.style.opacity="";},60); }
    var ghost = document.querySelector(".ghost");
    if(ghost) ghost.style.transform="translate("+(Math.random()*8-4)+"px,"+(Math.random()*6-3)+"px)";
    // micro-glitch on random visible heading ≤ once per 4s
    var now = performance.now();
    if(now-lastMicro>4000 && !G.fxOff()){
      lastMicro = now;
      var hs = G.qa("main h2").filter(function(h){ var r=h.getBoundingClientRect();
        return r.top>0&&r.top<innerHeight; });
      if(hs.length) G.glitch(hs[(Math.random()*hs.length)|0],{ms:180});
    }
  });
}
/* ---------------- HOME ---------------- */
function home(){
  // routes live hints
  G.github.repos().then(function(r){
    var h=document.getElementById("hintRepos"); if(h) h.textContent=r.length+" REPOS";
  }).catch(function(){});
  // projects carousel + stats + langbar + activity
  var car = document.getElementById("projCar");
  function skel(el,n){ if(el) el.innerHTML = Array(n).join('<div class="cc skel" style="--cw:260px;min-height:150px"></div>'); }
  if(car){
    skel(car,5);
    G.github.repos().then(function(r){
      car.innerHTML = r.slice(0,12).map(function(x){
        return '<a class="cc card" style="--cw:260px" href="/project/?repo='+encodeURIComponent(x.name)+'">'+
          '<p class="card-t">'+G.esc(x.name)+'</p><p class="meta">'+G.esc(x.description||"no description")+'</p>'+
          '<p class="meta num">★ '+x.stargazers_count+' · '+(x.language||"—")+'</p></a>';
      }).join("");
      G.initCarousels();
      // stats row
      var s=document.getElementById("statRow");
      if(s){ var stars=r.reduce(function(a,b){return a+b.stargazers_count;},0),
          forks=r.reduce(function(a,b){return a+b.forks_count;},0);
        s.innerHTML = [["REPOS",r.length],["STARS",stars],["FORKS",forks],
          ["LAST PUSH", r[0]?G.timeAgo(r[0].pushed_at):"—"]].map(function(k){
          return '<div class="panel"><div class="lbl">'+k[0]+'</div><div class="tall num" style="font-size:34px;font-weight:800">'+k[1]+'</div></div>';
        }).join("");
        s.style.display="grid"; s.style.gridTemplateColumns="repeat(auto-fit,minmax(150px,1fr))"; s.style.gap="12px";
      }
      // language distribution bar
      var langs={}; r.forEach(function(x){ if(x.language) langs[x.language]=(langs[x.language]||0)+1; });
      var tot=Object.values(langs).reduce(function(a,b){return a+b;},0)||1;
      var lb=document.getElementById("langBar"), lg=document.getElementById("langLegend");
      if(lb) lb.innerHTML=Object.keys(langs).map(function(k){
        return '<i style="flex:'+langs[k]+'" title="'+G.esc(k)+'"></i>'; }).join("");
      if(lg) lg.innerHTML=Object.keys(langs).map(function(k){
        return '<span class="chip"><i class="dot"></i>'+G.esc(k)+' '+Math.round(langs[k]/tot*100)+'%</span>'; }).join(" ");
    }).catch(function(){
      if(car) car.innerHTML='<div class="panel">could not load repos — rate limited or offline <button class="btn" onclick="location.reload()">RETRY</button></div>';
    });
    G.github.events().then(function(ev){
      var f=document.getElementById("actFeed");
      if(!f) return;
      f.innerHTML = ev.slice(0,8).map(function(e){
        var repo=(e.repo&&e.repo.name||"").replace(G.CONFIG.ghUser+"/","");
        var what=e.type.replace("Event","").toUpperCase();
        return '<div class="meta" style="padding:6px 0;border-bottom:1px solid var(--b12)">'+G.esc(what)+' → '+G.esc(repo)+' · '+G.timeAgo(e.created_at)+'</div>';
      }).join("") || '<div class="meta">NO RECENT ACTIVITY</div>';
    }).catch(function(){});
  }
  // stack bento
  var bento=document.getElementById("bento");
  function paintBento(f){
    if(!bento) return;
    bento.innerHTML = G.CONFIG.stack.filter(function(s){ return !f||s.cat===f; }).map(function(s,i){
      return '<div class="card reveal in" style="transition-delay:'+(i*60)+'ms"><p class="card-t">'+G.esc(s.name)+
        '</p><p class="meta">'+s.cat+' · '+G.esc(s.role)+'</p></div>';
    }).join("");
  }
  if(bento){ paintBento(null);
    G.qa("[data-bento]").forEach(function(b){ b.onclick=function(){
      G.qa("[data-bento]").forEach(function(x){x.classList.remove("on");}); b.classList.add("on");
      paintBento(b.dataset.bento||null);
      if(bento.firstChild) G.glitch(bento.firstChild,{ms:180});
    };});
  }
  // stat images fallback → live tiles
  G.qa(".statImgs img").forEach(function(img){
    img.loading="lazy";
    img.onerror=function(){ var d=document.createElement("div"); d.className="panel tall";
      d.textContent="STATS OFFLINE — SEE LIVE COUNTERS ABOVE"; img.replaceWith(d); };
  });
}
/* ---------------- PROJECTS ---------------- */
function projects(){
  var grid=document.getElementById("pGrid"), q=document.getElementById("pSearch"),
      chips=document.getElementById("pLangs"), sort=document.getElementById("pSort"),
      view=document.getElementById("pView"), count=document.getElementById("pCount");
  var params=new URLSearchParams(location.search);
  q.value=params.get("q")||""; sort.value=params.get("sort")||"stars"; var lang=params.get("lang")||"";
  var all=[];
  grid.innerHTML='<div class="skel"></div><div class="skel"></div><div class="skel"></div>';
  G.github.repos().then(function(r){ all=r; buildLangs(r); paint(); }).catch(function(){
    grid.innerHTML='<div class="panel">could not load repos — rate limited or offline<br><br><button class="btn" onclick="location.reload()">RETRY</button></div>';
  });
  function buildLangs(r){ var set={}; r.forEach(function(x){ if(x.language) set[x.language]=1; });
    chips.innerHTML='<button class="chip'+(lang===""?" on":"")+'" data-l="">ALL</button>'+
      Object.keys(set).sort().map(function(l){
        return '<button class="chip'+(lang===l?" on":"")+'" data-l="'+G.esc(l)+'">'+G.esc(l)+'</button>'; }).join("");
    chips.querySelectorAll("button").forEach(function(b){ b.onclick=function(){ lang=b.dataset.l; sync(); paint(); }; });
  }
  function sync(){ var p=new URLSearchParams(); if(q.value)p.set("q",q.value);
    if(lang)p.set("lang",lang); if(sort.value!=="stars")p.set("sort",sort.value);
    history.replaceState(null,"","/projects/"+(p.toString()?"?"+p.toString():"")); }
  q.oninput=function(){ sync(); paint(); }; sort.onchange=function(){ sync(); paint(); };
  view.onclick=function(){ grid.classList.toggle("list");
    view.textContent = grid.classList.contains("list")?"GRID":"LIST"; };
  function paint(){
    var srt=sort.value, needle=q.value.toLowerCase();
    var list=all.filter(function(x){
      if(lang&&x.language!==lang) return false;
      if(needle){ var hay=(x.name+" "+(x.description||"")+" "+(x.topics||[]).join(" ")).toLowerCase();
        if(hay.indexOf(needle)<0) return false; }
      return true; });
    if(srt==="stars") list.sort(function(a,b){return b.stargazers_count-a.stargazers_count;});
    else if(srt==="updated") list.sort(function(a,b){return new Date(b.updated_at)-new Date(a.updated_at);});
    else list.sort(function(a,b){return a.name.localeCompare(b.name);});
    count.textContent="SHOWING "+list.length+"/"+all.length;
    if(!list.length){ grid.innerHTML='<div class="panel"><p class="tall" style="font-size:40px">NO SIGNAL — NO MATCHES</p><button class="btn" id="pReset">RESET FILTERS</button></div>';
      document.getElementById("pReset").onclick=function(){ q.value=""; lang=""; sort.value="stars"; sync(); buildLangs(all); paint(); }; return; }
    grid.innerHTML=list.map(function(x){
      return '<article class="card"><p class="card-t"><a href="/project/?repo='+encodeURIComponent(x.name)+'">'+G.esc(x.name)+'</a></p>'+
        '<p><span class="chip">'+G.esc(x.license?x.license.spdx_id:"no license")+'</span></p>'+
        '<p>'+G.esc(x.description||"no description")+'</p>'+
        '<p>'+(x.topics||[]).map(function(t){return '<span class="chip">'+G.esc(t)+'</span>';}).join(" ")+'</p>'+
        '<div class="readmeClip" data-rc="'+G.esc(x.name)+'"><span class="meta">README PREVIEW…</span></div>'+
        '<p class="meta num"><span class="dot"></span>'+G.esc(x.language||"—")+' · ★ '+x.stargazers_count+' · ⑂ '+x.forks_count+
        ' · ◆ '+x.open_issues_count+' · '+(x.size/1024).toFixed(1)+'MB · '+G.timeAgo(x.updated_at)+'</p>'+
        '<p><a class="chip" href="/project/?repo='+encodeURIComponent(x.name)+'">DETAIL →</a> '+
        '<a class="chip" href="'+x.html_url+'" target="_blank" rel="noopener">GITHUB ↗</a></p></article>';
    }).join("");
    // README previews, re-checked as images load
    grid.querySelectorAll("[data-rc]").forEach(function(box){
      G.github.readme(box.dataset.rc).then(function(md){
        var html = window.marked?marked.parse(md):G.esc(md).slice(0,400);
        box.innerHTML = G.github.sanitize(html);
        box.querySelectorAll("img").forEach(function(im){
          im.loading="lazy"; im.addEventListener("load",function(){ box.style.maxHeight="170px"; }); });
      }).catch(function(){ box.innerHTML='<span class="meta">NO README</span>'; });
    });
  }
}
/* ---------------- PROJECT DETAIL ---------------- */
function project(){
  var name=new URLSearchParams(location.search).get("repo")||"";
  var root=document.getElementById("projDetail");
  if(!name){ root.innerHTML='<div class="panel"><p class="tall" style="font-size:44px">REPO NOT FOUND</p><p><a class="btn" href="/projects/">← ALL PROJECTS</a></p></div>'; return; }
  root.innerHTML='<div class="skel"></div>';
  G.github.repos().then(function(r){
    var i=r.findIndex(function(x){return x.name===name;});
    if(i<0){ root.innerHTML='<div class="panel"><p class="tall" style="font-size:44px">REPO NOT FOUND</p><p><a class="btn" href="/projects/">← ALL PROJECTS</a></p></div>'; return; }
    var x=r[i], prev=r[i-1], next=r[i+1];
    root.innerHTML =
      '<p class="lbl">04 · PROJECT // FETCH</p><h1>'+G.esc(x.name)+'</h1>'+
      '<p>'+G.esc(x.description||"no description")+'</p>'+
      '<p>'+(x.topics||[]).map(function(t){return '<span class="chip">'+G.esc(t)+'</span>';}).join(" ")+'</p>'+
      '<p><a class="btn solid" href="'+x.html_url+'" target="_blank" rel="noopener">GITHUB ↗</a> '+
      (x.homepage?'<a class="btn" href="'+G.esc(x.homepage)+'" target="_blank" rel="noopener">HOMEPAGE ↗</a> ':"")+'</p>'+
      '<div class="grid12"><div style="grid-column:1/9"><div id="langBarD" class="langbar"></div>'+
      '<div id="toc" class="panel" style="margin-bottom:14px"><b class="tall">CONTENTS</b><div id="tocIn" class="meta">…</div></div>'+
      '<div id="rmd" class="readme"><div class="skel">README…</div></div></div>'+
      '<aside style="grid-column:9/13"><div class="panel" style="position:sticky;top:90px">'+
      '<p class="meta num">LANG '+(G.esc(x.language)||"—")+'<br>★ '+x.stargazers_count+' · ⑂ '+x.forks_count+' · ◆ '+x.open_issues_count+
      '<br>SIZE '+(x.size/1024).toFixed(1)+'MB<br>LICENSE '+G.esc(x.license?x.license.spdx_id:"no license")+
      '<br>CREATED '+new Date(x.created_at).toISOString().slice(0,10)+'<br>UPDATED '+G.timeAgo(x.updated_at)+
      '<br>BRANCH '+G.esc(x.default_branch)+'</p></div></aside></div>'+
      '<p style="margin-top:18px">'+(prev?'<a class="chip" href="/project/?repo='+encodeURIComponent(prev.name)+'">← '+G.esc(prev.name)+'</a> ':"")+
      '<a class="chip" href="/projects/">ALL</a> '+(next?'<a class="chip" href="/project/?repo='+encodeURIComponent(next.name)+'">'+G.esc(next.name)+' →</a>':"")+'</p>';
    G.github.langs(name).then(function(L){
      var tot=Object.values(L).reduce(function(a,b){return a+b;},0)||1;
      var bar=document.getElementById("langBarD");
      if(bar) bar.innerHTML=Object.keys(L).map(function(k){
        return '<i style="flex:'+L[k]+'" title="'+G.esc(k)+" "+Math.round(L[k]/tot*100)+'%"></i>'; }).join("");
    }).catch(function(){});
    G.github.readme(name).then(function(md){
      var html = window.marked?marked.parse(md):"<pre>"+G.esc(md)+"</pre>";
      var clean = G.github.sanitize(html);
      document.getElementById("rmd").innerHTML = clean;
      // auto TOC from headings
      var hs=G.qa("#rmd h1,#rmd h2,#rmd h3"), ti=document.getElementById("tocIn");
      if(ti) ti.innerHTML = hs.length?hs.map(function(h,j){
        h.id=h.id||"h"+j; return '<div><a href="#'+h.id+'">'+G.esc(h.textContent)+'</a></div>'; }).join(""):"NO HEADINGS";
    }).catch(function(){ document.getElementById("rmd").innerHTML="NO README AVAILABLE"; });
  }).catch(function(){ root.innerHTML='<div class="panel">could not load repos — rate limited or offline <button class="btn" onclick="location.reload()">RETRY</button></div>'; });
}
/* ---------------- STACK ---------------- */
function stack(){
  var grid=document.getElementById("stackGrid"); if(!grid) return;
  function paint(f){
    grid.innerHTML=G.CONFIG.stack.filter(function(s){return !f||s.cat===f;}).map(function(s){
      return '<div class="card"><p class="card-t">'+G.esc(s.name)+'</p><p class="meta">'+s.cat+' · '+G.esc(s.role)+'</p><p>'+G.esc(s.why)+'</p></div>';
    }).join("");
  }
  paint(null);
  G.qa("[data-stack]").forEach(function(b){ b.onclick=function(){
    G.qa("[data-stack]").forEach(function(x){x.classList.remove("on");}); b.classList.add("on");
    paint(b.dataset.stack||null); G.glitch(grid,{ms:180}); }; });
}
/* ---------------- ABOUT ---------------- */
function about(){
  var log=document.getElementById("ghLog"); if(!log) return;
  log.innerHTML='<div class="skel"></div>';
  Promise.all([G.github.user(),G.github.repos()]).then(function(p){
    var u=p[0], r=p[1];
    var first=r.slice().sort(function(a,b){return new Date(a.created_at)-new Date(b.created_at);})[0];
    var top=r.slice().sort(function(a,b){return b.stargazers_count-a.stargazers_count;})[0];
    log.innerHTML=[["ACCOUNT CREATED",new Date(u.created_at).toISOString().slice(0,10)],
      ["FIRST REPO",first?first.name+" · "+new Date(first.created_at).toISOString().slice(0,10):"—"],
      ["MOST STARRED",top?top.name+" · ★ "+top.stargazers_count:"—"],
      ["MOST RECENT PUSH",r[0]?r[0].name+" · "+G.timeAgo(r[0].pushed_at):"—"]]
      .map(function(k){return '<div class="panel"><div class="lbl">'+k[0]+'</div><div class="tall" style="font-size:30px">'+G.esc(k[1])+'</div></div>';}).join("");
  }).catch(function(){ log.innerHTML='<div class="panel">GITHUB LOG OFFLINE</div>'; });
}
})();
