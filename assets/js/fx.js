/* fx.js — scroll progress, back-to-top, directional reveals, marquee hover. */
(function(){
"use strict";
var G = window.G4;
var lastY = 0, seed = 7;
function srand(){ seed = (seed*16807)%2147483647; return seed/2147483647; }

G.initFx = function(){
  var bar = document.getElementById("progress"),
      top = document.getElementById("toTop"),
      fbr = document.getElementById("fBR");
  function onScroll(){
    var y = scrollY, h = document.documentElement.scrollHeight - innerHeight;
    var p = h>0 ? y/h*100 : 0;
    if(bar) bar.style.width = p+"%";
    if(top) top.style.display = (y > innerHeight*0.6) ? "block":"none";
    if(fbr) fbr.textContent = "SCROLL "+String(Math.round(p)).padStart(3,"0")+"%";
    var dir = y >= lastY ? 1 : -1; lastY = y;
    document.body.dataset.sdir = dir;
    // left rail scroll-spy
    var secs = G.qa("section[id], div.hero[id]");
    var cur = null;
    secs.forEach(function(s){ if(s.getBoundingClientRect().top < innerHeight*0.4) cur = s.id; });
    G.qa("#railL a").forEach(function(a){
      a.classList.toggle("on", a.getAttribute("href")==="#"+cur); });
    if(top) top.classList.toggle("on", y>10);
  }
  addEventListener("scroll", onScroll, {passive:true}); onScroll();
  if(top) top.addEventListener("click", function(){ scrollTo({top:0, behavior: G.fxOff()?"auto":"smooth"}); });

  // Directional reveals: wide elements follow scroll dir, narrow alternate via seed.
  var io = new IntersectionObserver(function(es){
    es.forEach(function(e){
      var el = e.target;
      if(e.isIntersecting && e.intersectionRatio >= 0.12){
        if(!el.classList.contains("in")){
          var wide = el.offsetWidth > innerHeight*0.7;
          var d = wide ? (Number(document.body.dataset.sdir)||1) : (srand()>0.5?1:-1);
          el.style.transitionDelay = Math.min(8*90, (Number(el.dataset.stagger)||0)*90)+"ms";
          el.style.setProperty("--rd", d);
          el.style.transform = "";
          el.classList.add("in");
          if(/^H[12]$/.test(el.tagName)) G.glitch(el,{ms:200});
          setTimeout(function(){ el.classList.add("settled"); }, 1100);
        }
      } else if(!e.isIntersecting &&
          (e.boundingClientRect.top > innerHeight || e.boundingClientRect.bottom < 0)){
        // teardown only after FULLY leaving viewport so it replays both ways
        el.classList.remove("in","settled"); el.style.transitionDelay="";
      }
    });
  }, {threshold:0.15, rootMargin:"0px 0px -6% 0px"});
  G.qa(".reveal").forEach(function(el,i){ el.dataset.stagger = (i%8); io.observe(el); });

  // marquee hover glitch
  G.qa(".marq").forEach(function(m){
    m.addEventListener("mouseenter", function(){ G.glitch(m,{ms:200}); });
  });
};
})();
