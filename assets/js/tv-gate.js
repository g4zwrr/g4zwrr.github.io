/* tv-gate.js — broken 3D TV intro, home every visit.
   Real CSS 3D box (6 faces), pixel static canvas, tears, v-hold, crack SVG,
   power-cycle collapses. Enter → snap + violent static, accelerating dolly
   (cubic-bezier .7,0,.9,.4), 6–8 lagging ghost clones (mix-blend lighten) +
   blur ramp ~16px + speedlines, white-out flash → black, hero exits screen. */
(function(){
"use strict";
var G = window.G4;
G.initGate = function(){
  var gate = document.getElementById("gate");
  if(!gate) { console.error("Gate element not found"); return; }
  // Always show gate on every visit (no sessionStorage gating), even on other pages
  document.body.style.overflow = "hidden"; // scroll-lock until entry
  console.log("initGate: starting, gate found");
  document.title = "INITGATE START";

  // Run synchronously to avoid rAF issues
  console.log("initGate: calling buildStatic, idleHits, powerCycles");
  buildStatic(); idleHits(); powerCycles();
  console.log("initGate: calling attachHandlers");
  document.title = "INITGATE CALLING ATTACH";
  attachHandlers();
  document.title = "INITGATE DONE";

  function attachHandlers(){
    console.log("attachHandlers: called");
    var done = false;
    var tv = gate.querySelector(".tv");
    console.log("attachHandlers: tv element", tv);
    if(!tv) { console.error("TV element not found in gate"); return; }

    function enter(e){ // tv-gate.js enter - added this check
  // Check if this is the right enter function by checking if we're inside attachHandlers
  console.log("ENTER called, done =", done);
  if(done) return; done = true;
  console.log("ENTER: proceeding");
  document.title = "ENTER CALLED";
  // start audio synchronously inside gesture
  try{ G.audio.play(); }catch(e){}
  if(G.fxOff()){ // reduced: 300ms fade, no dolly
    gate.style.transition = "opacity .3s"; gate.style.opacity = "0";
    setTimeout(function(){ gate.hidden = true; finish(); }, 320); return;
  }
  zoomSequence();
}

    function finish(){
      document.body.style.overflow = ""; document.body.classList.add("entered");
      // Don't persist g4_entered so gate shows on every refresh
      var hero = document.querySelector(".hero");
      if(hero){ hero.style.transform = "scale(1.12)"; hero.style.filter = "blur(14px)"; hero.style.opacity = "0";
        hero.style.transition = "transform 1.2s, filter 1.2s, opacity 1.2s";
        requestAnimationFrame(function(){ requestAnimationFrame(function(){
          hero.style.transform = ""; hero.style.filter = ""; hero.style.opacity = "1";
          var h1 = hero.querySelector("h1");
          if(h1) G.scramble(h1, h1.textContent, 600);
        });});
      }
      // Show dock after gate finishes
      var dock = document.getElementById("dock");
      if(dock) dock.style.display = "flex";
    }

    function zoomSequence(){
      var scene = gate.querySelector(".tvscene"), speed = gate.querySelector(".speedlines");
      var tvtxt = gate.querySelector(".tvtxt");
      if(tvtxt) tvtxt.textContent = "NO SIGNAL";
      G.flash();
      if(tv) tv.style.transform = "rotateY(0deg) rotateX(0deg)";
      window._g4violent = true;
      setTimeout(function(){ // 250–1250ms accelerating dolly
        var scr = gate.querySelector(".screen");
        var r = scr.getBoundingClientRect();
        var need = Math.max(innerWidth / r.width, innerHeight / r.height) * 1.05;
        // 6–8 ghost clones lagging a few ms, falling opacity, lighten
        for(var i = 0; i < 7; i++){
          var cl = scene.cloneNode(true); cl.setAttribute("aria-hidden", "true");
          cl.style.cssText = "position:absolute;inset:0;pointer-events:none;mix-blend-mode:lighten;opacity:" + (0.5 - i * 0.06);
          gate.appendChild(cl);
          (function(c, k){ setTimeout(function(){
            c.style.transition = "transform 1s cubic-bezier(0.7,0,0.9,0.4), filter 1s";
            c.style.transform = "scale(" + (need * 0.97) + ")"; c.style.filter = "blur(" + (10 + k) + "px)";
            setTimeout(function(){ c.remove(); }, 1100);
          }, k * 28); })(cl, i);
        }
        scene.style.transition = "transform 1s cubic-bezier(0.7,0,0.9,0.4), filter 1s";
        scene.style.transform = "scale(" + need + ")";
        scene.style.filter = "blur(16px)";
        if(speed) speed.style.opacity = "0.6";
      }, 250);
      setTimeout(function(){ G.flash(); gate.style.background = "#fff"; }, 1250); // white-out
      setTimeout(function(){ gate.style.background = "#000"; gate.hidden = true; finish(); }, 1450);
    }

    // Make enter globally accessible for debugging
    window._g4Enter = enter;

    // Attach click handler directly on gate (capture phase + fallback delegation)
    gate.addEventListener("click", function(e) { 
      document.title = "CLICK HANDLER FIRED";
      // Call the global enter function
      window._g4Enter && window._g4Enter(e);
    }, { capture: true });
    gate.addEventListener("touchend", function(e) { 
      e.preventDefault(); 
      try { window._g4Enter && window._g4Enter(e); } catch(err) { console.error("Gate touch error:", err); }
    }, { capture: true, passive: false });
    gate.addEventListener("keydown", function(e){
      if(e.key === "Enter" || e.key === " " || e.key === "Escape"){ e.preventDefault(); enter(); }
    });

    // Fallback: event delegation on document in case gate is covered
    document.addEventListener("click", function(e){
      if(e.target.closest && e.target.closest("#gate")) { enter(); }
    }, { capture: true });

    // Ensure gate receives pointer events
    gate.style.pointerEvents = "auto";
    console.log("Gate handlers attached");
  }

  // pointer parallax lean ±14° desktop
  if(matchMedia("(pointer:fine)").matches){
    gate.addEventListener("pointermove", function(e){
      var r = gate.getBoundingClientRect();
      var dx = (e.clientX - r.left) / r.width - 0.5;
      var dy = (e.clientY - r.top) / r.height - 0.5;
      if(tv) tv.style.transform = "rotateY(" + (dx * 28) + "deg) rotateX(" + (-dy * 20) + "deg)";
    });
  }

  // --- broken screen: ~160×120 static upscaled, tears, vhold, pops ---
  function buildStatic(){
    var cv = document.getElementById("tvstatic"); if(!cv) return;
    cv.width = 160; cv.height = 120; var x = cv.getContext("2d");
    var tear = gate.querySelector(".tear"), vhold = gate.querySelector(".vhold"),
        txt = gate.querySelector(".tvtxt");
    var vy = 0;
    G.loop("tvstatic", function(){
      if(gate.hidden) return;
      var img = x.createImageData(160, 120), d = img.data, viol = window._g4violent ? 2.2 : 1;
      for(var i = 0; i < d.length; i += 4){ var v = (Math.random() * 255 * viol) | 0; if(v > 255) v = 255;
        d[i] = d[i+1] = d[i+2] = v; d[i+3] = 255; }
      x.putImageData(img, 0, 0);
      // tearing bands
      if(tear){ tear.style.top = (Math.random() * 100) + "%";
        tear.style.transform = "translateX(" + ((Math.random() * 30 - 15) | 0) + "px)"; }
      if(vhold){ vy = (vy + 2.4) % 130; vhold.style.top = vy + "px"; } // rolling vertical hold
      if(Math.random() < 0.03) cv.style.filter = "brightness(2)"; // brightness pops
      else cv.style.filter = "";
      if(Math.random() < 0.02) txt.textContent = Math.random() < 0.5 ? "NO SIGNAL" : "SIGNAL LOST";
      else if(!window._g4violent) txt.textContent = "TAP TO ENTER";
    }, {el: gate});
  }
  function idleHits(){ // every 2–5s: jolt + glitch burst
    (function hit(){
      setTimeout(function(){
        if(!gate.hidden && tv && !G.fxOff()){
          tv.style.translate = ((Math.random() * 10 - 5) | 0) + "px " + ((Math.random() * 8 - 4) | 0) + "px";
          G.glitch(gate.querySelector(".tvtxt"), {ms: 160});
          setTimeout(function(){ tv.style.translate = ""; }, 120);
        }
        hit();
      }, 2000 + Math.random() * 3000);
    })();
  }
  function powerCycles(){ // ~7s CRT collapse to line and back
    setInterval(function(){
      if(gate.hidden || G.fxOff()) return;
      var scr = gate.querySelector(".screen");
      scr.style.transition = "transform .18s"; scr.style.transform = "scaleY(0.02)";
      setTimeout(function(){ scr.style.transform = ""; }, 220);
    }, 7000);
  }
};
})();