/* glitch.js — shared toolkit: .glitch bursts, scramble decode, rate-limited flash. */
(function(){
"use strict";
var G = window.G4;
var SCRAM = "█▓▒░#@%&01/\\|<>";

/* burst: add .go for ms, restamp data-text ghost */
G.glitch = function(el, opts){
  if(!el || !el.classList) return;
  if(G.fxOff()) return;
  var ms = (opts&&opts.ms)||240;
  if(!el.hasAttribute("data-text")) el.setAttribute("data-text", el.textContent);
  el.classList.remove("go"); void el.offsetWidth; el.classList.add("go");
  clearTimeout(el._g4t); el._g4t = setTimeout(function(){ el.classList.remove("go"); }, ms);
};

/* scramble decode through block/noise glyphs */
G.scramble = function(el, target, ms){
  if(!el) return;
  target = String(target==null?el.textContent:target);
  if(G.fxOff()){ el.textContent = target; return; }
  ms = ms||500;
  var t0 = performance.now(), len = target.length;
  cancelAnimationFrame(el._g4s);
  function fr(now){
    var p = Math.min(1,(now-t0)/ms), out="";
    for(var i=0;i<len;i++){
      if(target[i]===" "){ out+=" "; continue; }
      out += (i/len < p) ? target[i] : SCRAM[(Math.random()*SCRAM.length)|0];
    }
    el.textContent = out;
    if(p<1) el._g4s = requestAnimationFrame(fr); else el.textContent = target;
  }
  el._g4s = requestAnimationFrame(fr);
};

/* full-screen inversion flash, hard-limited: max 1 per 400ms (≤3/sec) */
G._lastFlash = 0;
G.flash = function(){
  var now = performance.now();
  if(now - G._lastFlash < 400) return false;
  G._lastFlash = now;
  var f = document.getElementById("flash");
  if(!f || G.fxOff()) return false;
  f.style.transition="none"; f.style.opacity="1";
  requestAnimationFrame(function(){ requestAnimationFrame(function(){
    f.style.transition="opacity .12s"; f.style.opacity="0";
  });});
  return true;
};
})();
