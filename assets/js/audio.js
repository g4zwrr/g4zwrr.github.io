/* audio.js — chain: src→analyser→gain→lowpass→compressor→dest.
   Fade in 2.6s + filter 600→20k; fade last 5s; mute fade 0.9s; persist via
   sessionStorage across REAL page loads; tape-stop hooks for transition. */
(function(){
"use strict";
var G = window.G4;
var A = G.audio = {};
var el, ctx, src, an, gain, lp, comp, raf = 0;
var state = {t:0, muted:false, volume:0.8, playing:false, vizMode:2}; /* 2 = SCOPE */

A.state = state;
A.ready = false;

function saved(){ return G.store.get("g4_audio", null); }

A.init = function(){
  el = document.getElementById("bgm");
  if(!el) return;
  var s = saved();
  if(s){ state.muted=!!s.muted; state.volume=(s.volume==null?0.8:s.volume);
    state.vizMode = (s.vizMode==null? 2 : s.vizMode); // 2 = SCOPE, the default
    // restore currentTime + elapsed gap while we were "navigating"
    var gap = (Date.now()-(s.savedAt||Date.now()))/1000;
    el._resumeT = Math.max(0,(s.t||0) + (s.playing?Math.min(gap,30):0));
    el._autoplay = !!s.playing;
  }
  el.volume = 0; // we drive loudness through gain node
  el.loop = true;
  try{
    var AC = window.AudioContext||window.webkitAudioContext;
    ctx = new AC();
    src = ctx.createMediaElementSource(el);
    an = ctx.createAnalyser(); an.fftSize = 512; an.smoothingTimeConstant = 0.78;
    gain = ctx.createGain(); gain.gain.value = 0;
    lp = ctx.createBiquadFilter(); lp.type="lowpass"; lp.frequency.value = 600; lp.Q.value = 0.4;
    comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -6; comp.ratio.value = 20;
    src.connect(an); an.connect(gain); gain.connect(lp); lp.connect(comp); comp.connect(ctx.destination);
    A.ctx=ctx; A.an=an; A.ready=true;
  }catch(e){ A.ready=false; }
  A.bindDock();
  if(el._resumeT) { try{ el.currentTime = el._resumeT; }catch(e){} }
  applyVol(true);
  if(el._autoplay){ tryPlay(); } else { showTap(); }
  // fade out over last 5s of track (loop edge safety)
  el.addEventListener("timeupdate", function(){
    if(!el.duration) return;
    var left = el.duration - el.currentTime;
    if(left < 5 && !el._fadeTail){ el._fadeTail = true; fadeTo(0, 5.0); }
    else if(left > 6 && el._fadeTail){ el._fadeTail = false; if(!state.muted) fadeTo(state.volume, 1); }
  });
  addEventListener("pointerdown", function once(){
    if(ctx && ctx.state==="suspended") ctx.resume();
    if(state._wantPlay && el.paused) tryPlay();
  });
  // persist before REAL navigation
  addEventListener("pagehide", function(){
    G.store.set("g4_audio",{t:el.currentTime||0, muted:state.muted, volume:state.volume,
      playing:!el.paused, vizMode:state.vizMode, savedAt:Date.now()});
  });
};

function fadeTo(v, secs){
  if(!ctx || !gain) { el.volume = v; return; }
  var t = ctx.currentTime;
  gain.gain.cancelScheduledValues(t);
  gain.gain.setValueAtTime(gain.gain.value, t);
  gain.gain.linearRampToValueAtTime(Math.min(3,v), t+secs);
}
function openFilter(secs){
  if(!ctx||!lp) return; var t=ctx.currentTime;
  lp.frequency.cancelScheduledValues(t);
  lp.frequency.setValueAtTime(lp.frequency.value,t);
  lp.frequency.exponentialRampToValueAtTime(20000,t+secs);
}

function tryPlay(){
  if(!el) return Promise.resolve();
  if(ctx && ctx.state==="suspended") ctx.resume();
  return el.play().then(function(){
    state.playing = true; state._wantPlay = false; hideTap();
    el.volume = 1;
    fadeTo(state.muted?0:state.volume, 2.6); // 2.6s fade-in
    openFilter(2.6);                          // lowpass 600→20k
    syncDock();
  }).catch(function(){
    state._wantPlay = true; showTap(); // autoplay blocked → glitch pill
  });
}
A.play = tryPlay;
A.pause = function(){ if(el) el.pause(); state.playing=false; syncDock(); };

function applyVol(instant){
  var v = state.muted?0:state.volume;
  if(!ctx||!gain){ el.volume=v; return; }
  if(instant){ gain.gain.value=v; if(lp) lp.frequency.value=20000; }
  else fadeTo(v, 0.9); // mute fade 0.9s
}

function showTap(){ var b=document.getElementById("tapStart"); if(b) b.style.display="block"; }
function hideTap(){ var b=document.getElementById("tapStart"); if(b) b.style.display="none"; }

A.bindDock = function(){
  var pp=G.q("#dPlay"), mu=G.q("#dMute"), vo=G.q("#vol"), sk=G.q("#seek"),
      vm=G.q("#dViz"), tap=G.q("#tapStart");
  if(pp) pp.onclick=function(){ el.paused?tryPlay():A.pause(); };
  if(mu) mu.onclick=function(){ state.muted=!state.muted; applyVol(); syncDock(); };
  if(vo){ vo.value=state.volume; vo.oninput=function(){ state.volume=Number(vo.value); state.muted=false; applyVol(); syncDock(); }; }
  if(vm) vm.onclick=function(){ state.vizMode=((state.vizMode+1)%4); G.store.set("g4_audio",
    {t:el.currentTime,muted:state.muted,volume:state.volume,playing:!el.paused,vizMode:state.vizMode,savedAt:Date.now()});
    if(G.viz) G.viz.setMode(state.vizMode);
    G.glitch(vm,{ms:180}); syncDock(); };
  if(tap) tap.onclick=function(){ tryPlay(); };
  if(sk){ sk.addEventListener("click", function(e){
      if(!el.duration) return;
      var r=sk.getBoundingClientRect();
      el.currentTime = el.duration * Math.min(1,Math.max(0,(e.clientX-r.left)/r.width));
    });
    sk.addEventListener("mousemove", function(e){
      var tip=G.q("#seekTip"); if(!tip||!el.duration) return;
      var r=sk.getBoundingClientRect(), p=Math.min(1,Math.max(0,(e.clientX-r.left)/r.width));
      tip.style.left=(p*100)+"%"; tip.textContent=fmt(el.duration*p)+" / "+fmt(el.duration);
    });
  }
  function fmt(s){ s=Math.floor(s||0); return String(Math.floor(s/60)).padStart(2,"0")+":"+String(s%60).padStart(2,"0"); }
  setInterval(function(){ // time row + scrubber
    var t=G.q("#dTime"), f=G.q("#seekFill");
    if(el&&el.duration&&t) t.textContent=fmt(el.currentTime)+" / "+fmt(el.duration);
    if(el&&el.duration&&f) f.style.width=(el.currentTime/el.duration*100)+"%";
  }, 500);
  syncDock();
};
function syncDock(){
  var pp=G.q("#dPlay"), mu=G.q("#dMute"), vm=G.q("#dViz");
  var modes=["BARS","MIRROR","SCOPE","RADIAL"];
  if(pp) pp.textContent = (el&&!el.paused)?"❚❚":"▶";
  if(mu) mu.textContent = state.muted?"UNMUTE":"MUTE";
  if(vm) vm.textContent = "VIZ: "+modes[state.vizMode==null?2:state.vizMode];
}
/* tape-stop: OUT ramp rate 1→0.7 + filter close; IN ramp back + open. */
A.tapeOut = function(){ try{ if(el&&!el.paused){ el.playbackRate=0.7;
  if(lp) lp.frequency.setTargetAtTime(800, ctx.currentTime, 0.15); } }catch(e){} };
A.tapeIn = function(){ try{ if(el){ el.playbackRate=1;
  if(lp&&ctx) lp.frequency.setTargetAtTime(20000, ctx.currentTime, 0.3); } }catch(e){} };
A.level = function(){ // 0..1 for VU/telemetry (analyser or element fallback)
  if(A.ready&&an){ var b=new Uint8Array(an.frequencyBinCount); an.getByteFrequencyData(b);
    var s=0; for(var i=0;i<b.length;i++) s+=b[i]; return s/b.length/255; }
  return (el&&!el.paused)?0.4:0;
};
function fmt2(s){ s=Math.floor(s||0); return String(Math.floor(s/60)).padStart(2,"0")+":"+String(s%60).padStart(2,"0"); }
})();
