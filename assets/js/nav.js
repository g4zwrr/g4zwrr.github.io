/* nav.js — header clock, FX toggle, mobile glitch menu, rails, telemetry,
   ticker, footer facts, contact rows, copy-email. */
(function(){
"use strict";
var G = window.G4;
G.initNav = function(){
  // FX toggle cycles FULL→LITE→OFF
  var fx = document.getElementById("fxBtn");
  if(fx){ fx.textContent = "FX "+G.fxMode;
    fx.onclick = function(){
      var nx = G.fxMode==="FULL"?"LITE":G.fxMode==="LITE"?"OFF":"FULL";
      G.setFx(nx); location.reload(); // clean re-init of sky/loops per mode
    };
  }
  var snd = document.getElementById("sndBtn");
  if(snd) snd.onclick = function(){
    var el = document.getElementById("bgm");
    if(!el) return;
    if(el.paused) G.audio.play(); else G.audio.pause();
  };
  // live clocks
  function clocks(){
    var s = new Date().toLocaleTimeString([], {hour12:false});
    ["clock","mTime"].forEach(function(id){ var e=document.getElementById(id); if(e) e.textContent=s; });
    var t0 = Number(sessionStorage.getItem("g4_sess")||Date.now());
    if(!sessionStorage.getItem("g4_sess")) sessionStorage.setItem("g4_sess",String(t0));
    var d = Math.floor((Date.now()-t0)/1000);
    var st = document.getElementById("teleSess");
    if(st) st.textContent = String(Math.floor(d/60)).padStart(2,"0")+":"+String(d%60).padStart(2,"0");
    var vp = document.getElementById("teleVp");
    if(vp) vp.textContent = innerWidth+"×"+innerHeight;
  }
  setInterval(clocks, 1000); clocks();
  // telemetry values tick w/ brief scramble (rate-limited by 2s interval)
  setInterval(function(){
    var a = document.getElementById("teleAu");
    if(a){ var v = Math.round(G.audio.level()*100)+"%";
      if(a.textContent!==v){ a.textContent=v; } }
  }, 2000);
  // mobile menu
  var hamb = document.getElementById("hamb"), mm = document.getElementById("mmenu");
  if(hamb&&mm){ hamb.onclick = function(){
      var open = mm.classList.toggle("open");
      hamb.setAttribute("aria-expanded", open);
      if(open) G.github.repos().then(function(r){
        var lr = document.getElementById("mLatest");
        if(lr&&r[0]) lr.textContent = "LATEST: "+r[0].name;
      }).catch(function(){});
    };
    mm.querySelectorAll("a").forEach(function(a){ a.addEventListener("click", function(){ mm.classList.remove("open"); }); });
  }
  // rail sections auto-build if empty
  var rail = document.getElementById("railL");
  if(rail && !rail.children.length){
    G.qa("main section[id]").forEach(function(s,i){
      var a=document.createElement("a"); a.href="#"+s.id;
      a.textContent="0"+(i+1); a.setAttribute("aria-label",s.id);
      a.onclick=function(e){ e.preventDefault();
        s.scrollIntoView({behavior:G.fxOff()?"auto":"smooth"}); };
      rail.appendChild(a);
    });
  }
  // nav hover glitch+scramble
  G.qa("#mainnav a").forEach(function(a){
    a.addEventListener("mouseenter", function(){
      G.glitch(a,{ms:180}); G.scramble(a, a.textContent, 260);
    });
  });
  // ticker content
  var tick = document.getElementById("tickerIn");
  function staticTick(){ if(tick&&!tick.dataset.live)
    tick.textContent = "G4ZWR · AKA GAZE · NOW: BUILDING IN LUAU · "+document.title+" · FX "+G.fxMode+" · ";
  }
  staticTick();
  G.github.user().then(function(u){
    return G.github.repos().then(function(r){
      var last = r[0]?G.timeAgo(r[0].pushed_at):"—";
      if(tick){ tick.dataset.live="1";
        tick.textContent = "G4ZWR · "+r.length+" REPOS · ★ TOTAL "+r.reduce(function(s,x){return s+x.stargazers_count;},0)+
          " · FOLLOWERS "+u.followers+" · LATEST PUSH "+last+" · NOW: BUILDING IN LUAU · "+document.title+" · ";
      }
      var st = document.getElementById("teleStars");
      if(st) st.textContent = r.reduce(function(s,x){return s+x.stargazers_count;},0);
      var lr = document.getElementById("mLatest");
      if(lr&&r[0]) lr.textContent = "LATEST: "+r[0].name;
      var lp = document.getElementById("footPush");
      if(lp&&r[0]) lp.textContent = "LAST PUSH "+G.timeAgo(r[0].pushed_at);
    });
  }).catch(function(){ /* static fallback stays */ });
  // footer year + replay intro
  G.qa(".yr").forEach(function(e){ e.textContent = new Date().getFullYear(); });
  var rp = document.getElementById("replayIntro");
  if(rp) rp.onclick = function(e){ e.preventDefault();
    try{ sessionStorage.removeItem("g4_entered"); }catch(_){} location.assign("/"); };
  // contact rows from config
  var rows = document.getElementById("contactRows"), fan = document.getElementById("fanCar");
  var list = G.CONFIG.contacts;
  function rowHTML(c){
    return '<a class="contactRow cc" style="--cw:190px" href="'+c.url+'" target="_blank" rel="noopener">'+
      (G.ICONS[c.id]||"")+'<span><b class="tall">'+G.esc(c.name)+'</b><br><span class="meta">'+G.esc(c.blurb)+'</span></span></a>';
  }
  if(rows) rows.innerHTML = list.map(function(c){
    return '<a class="contactRow" data-ch="'+c.id+'" href="'+c.url+'" target="_blank" rel="noopener">'+
      (G.ICONS[c.id]||"")+'<span><b class="tall">'+G.esc(c.name)+'</b><br><span class="meta">'+G.esc(c.blurb)+' · '+G.esc(c.url)+'</span></span></a>';
  }).join("");
  if(fan) fan.innerHTML = list.map(rowHTML).join("");
  // copy-email buttons
  G.qa("[data-copy]").forEach(function(b){
    b.onclick = function(){
      function done(){ G.scramble(b,"COPIED",400); G.glitch(b,{ms:200}); }
      if(navigator.clipboard) navigator.clipboard.writeText(G.CONFIG.email).then(done).catch(done);
      else done();
    };
  });
  // channel picker (contact page)
  var picks = G.qa("[data-pick]");
  picks.forEach(function(p){ p.onclick = function(){
    picks.forEach(function(x){x.classList.remove("on");}); p.classList.add("on");
    var want = p.dataset.pick;
    G.qa("#contactRows .contactRow").forEach(function(r){
      var hit = r.dataset.ch===want || (want==="work"&&(r.dataset.ch==="youtube"||r.dataset.ch==="roblox"))
        || (want==="updates"&&r.dataset.ch==="x");
      r.style.borderColor = hit?"#fff":"";
      r.style.background = hit?"rgba(255,255,255,.08)":"";
      if(hit) G.glitch(r,{ms:220});
    });
  };});
};
})();
