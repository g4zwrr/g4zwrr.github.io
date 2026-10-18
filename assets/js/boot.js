/* boot.js — last script on every page. Reads body[data-page], boots all. */
(function(){
"use strict";
function bootAll(){
  try { G4.boot(document.body.dataset.page); } catch(e) { console.error('boot fail:', e); }
  try { G4.initNav(); } catch(e) { console.error('initNav fail:', e); }
  try { G4.audio.init(); } catch(e) { console.error('audio.init fail:', e); }
  try { G4.initSky(); } catch(e) { console.error('initSky fail:', e); }
  try { G4.initTransition(); } catch(e) { console.error('initTransition fail:', e); }
  try { G4.initFx(); } catch(e) { console.error('initFx fail:', e); }
  try { 
    if(G4.initGate) { G4.initGate(); } 
    else { console.error('initGate missing'); }
  } catch(e) { console.error('initGate fail:', e); }
  try { if(G4.initAscii && document.getElementById("ascii")) G4.initAscii(); } catch(e) { console.error('initAscii fail:', e); }
  try { G4.initCarousels(); } catch(e) { console.error('initCarousels fail:', e); }
  try { G4.initPages(); } catch(e) { console.error('initPages fail:', e); }
  var h = document.getElementById("heroSnd");
  if(h) h.onclick = function(){ var e=document.getElementById("bgm"); e.paused?G4.audio.play():G4.audio.pause(); };
  var c = document.getElementById("scrollcue");
  if(c) addEventListener("scroll", function(){ c.style.display = scrollY>40?"none":""; }, {passive:true});
  var t = document.getElementById("teleTime");
  setInterval(function(){
    if(t) t.textContent = new Date().toLocaleTimeString([], {hour12:false});
    var s = document.getElementById("teleScr");
    if(s){ var max = document.documentElement.scrollHeight-innerHeight||1;
      s.textContent = Math.round(scrollY/max*100)+"%"; }
  }, 500);
  window._bootListenerFired = true;
}
// If DOM already ready, run immediately; otherwise wait for DOMContentLoaded
if(document.readyState === "loading"){
  addEventListener("DOMContentLoaded", bootAll);
} else {
  bootAll();
}
// Fallback: if bootAll hasn't run after 100ms, force it
setTimeout(function(){
  if(!window._bootListenerFired){
    bootAll();
  }
}, 100);
})();