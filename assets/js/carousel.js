/* carousel.js — full-bleed scroll-snap strip. scroll→--t/--s tilt
   (rotate s×−5°, sink t×10px, scale 1.12−t×.24, opacity 1−t×.6). Infinite
   loop w/ 4+ items: clone 5 sets, start middle, silent hop by set-widths
   (transitions off during hop, deferred till touch end). Drag 5px threshold,
   click suppression, snap-back, arrows, tabindex, focus ring. */
(function(){
"use strict";
var G = window.G4;
G.initCarousels = function(){
  G.qa(".car").forEach(setup);
};
function setup(track){
  var cards = Array.prototype.slice.call(track.children);
  if(cards.length>=4){ // infinite loop: clone into 5 sets
    var html = track.innerHTML;
    track.innerHTML = html+html+html+html+html;
    cards = Array.prototype.slice.call(track.children);
    requestAnimationFrame(function(){
      track.scrollLeft = setWidth(track); // start in middle set
    });
  }
  function setWidth(t){ var kids=t.children; if(kids.length<5) return 0;
    var w=0; for(var i=0;i<kids.length/5;i++) w+=kids[i].offsetWidth+18; return w*2; }
  var dragging=false, sx=0, sl=0, moved=0, hopping=false;
  track.setAttribute("tabindex","0");
  function paint(){
    var r=track.getBoundingClientRect(), cx=r.left+r.width/2;
    var best=null, bd=1e9;
    cards.forEach(function(c){
      var cr=c.getBoundingClientRect(), cc=cr.left+cr.width/2;
      var dist=Math.abs(cc-cx)/(r.width/2), t=Math.min(1,dist), s=Math.max(-1,Math.min(1,(cc-cx)/(r.width/2)));
      c.style.setProperty("--t",t.toFixed(3)); c.style.setProperty("--s",s.toFixed(3));
      if(!G.fxOff()){ /* tilt kept via CSS vars; OFF keeps scale/opacity cue */ }
      c.classList.toggle("active", false);
      if(Math.abs(cc-cx)<bd){bd=Math.abs(cc-cx);best=c;}
    });
    if(best) best.classList.add("active");
  }
  track.addEventListener("scroll", function(){
    paint();
    // silent hop near edges by whole set-widths
    if(cards.length>=20 && !dragging){
      var sw=setWidth(track)/2;
      if(track.scrollLeft < sw*0.4){ hop(track.scrollLeft+sw); }
      else if(track.scrollLeft > sw*3.4){ hop(track.scrollLeft-sw); }
    }
  }, {passive:true});
  function hop(to){ // transitions off during hop
    hopping=true; track.style.scrollBehavior="auto";
    var kids=Array.prototype.slice.call(track.children);
    kids.forEach(function(c){ c.style.transition="none"; });
    track.scrollLeft=to; paint();
    requestAnimationFrame(function(){ kids.forEach(function(c){ c.style.transition=""; }); hopping=false; });
  }
  track.addEventListener("pointerdown", function(e){
    dragging=true; moved=0; sx=e.clientX; sl=track.scrollLeft;
    track.setPointerCapture && track.setPointerCapture(e.pointerId);
  });
  track.addEventListener("pointermove", function(e){
    if(!dragging) return;
    var dx=e.clientX-sx; moved=Math.max(moved,Math.abs(dx));
    if(Math.abs(dx)>5) track.scrollLeft=sl-dx;
  });
  function endDrag(e){
    if(!dragging) return; dragging=false;
    if(moved>5){ // click suppression after drag + snap back to active
      e.preventDefault(); e.stopPropagation();
      var act=track.querySelector(".cc.active");
      if(act) act.scrollIntoView({inline:"center",block:"nearest",behavior:"smooth"});
    }
  }
  track.addEventListener("pointerup", endDrag, true);
  track.addEventListener("pointercancel", function(){ dragging=false; });
  track.addEventListener("click", function(e){
    if(moved>5){ e.preventDefault(); e.stopPropagation(); moved=0; return; }
    var card=e.target.closest && e.target.closest(".cc");
    if(!card) return;
    if(!card.classList.contains("active")){ e.preventDefault();
      card.scrollIntoView({inline:"center",block:"nearest",behavior:"smooth"}); }
    // active repo card: let real <a href> navigate (transition intercepts)
  }, true);
  track.addEventListener("keydown", function(e){
    if(e.key==="ArrowRight") track.scrollBy({left:280,behavior:"smooth"});
    if(e.key==="ArrowLeft") track.scrollBy({left:-280,behavior:"smooth"});
  });
  paint(); setTimeout(paint,300);
}
})();
