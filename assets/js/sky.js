/* sky.js — raw WebGL, no libs. Seeded PRNG (mulberry32) → identical stars
   every page. ~1150 stars (520 narrow) + galactic band, procedural rotating
   moon (phase persisted in sessionStorage), ~170 slanted rain discs, ≤4
   tapered-ribbon meteors. Scroll travel w/ framerate-independent lag, no
   overshoot. Context loss/restore, hidden-pause, OFF→static scatter. */
(function(){
"use strict";
var G = window.G4;
G.initSky = function(){
  var cv = document.getElementById("sky");
  if(!cv) return;
  if(G.fxOff()){ staticScatter(cv); return; }
  var gl = cv.getContext("webgl", {antialias:false, alpha:false});
  if(!gl){ staticScatter(cv); return; }
  var narrow = innerWidth < 760;
  var NST = narrow?520:1150, NRAIN = narrow?90:170;
  var rnd = G.mulberry32(1337); // fixed seed → same sky everywhere
  // --- stars: x,y in NDC-ish, z depth, band boost along diagonal ---
  var S = new Float32Array(NST*4);
  for(var i=0;i<NST;i++){
    var x=rnd()*2-1, y=rnd()*2-1;
    var band = Math.exp(-Math.pow((x*0.6+y-0.2)*2.2,2)); // diagonal galactic band
    S[i*4]=x; S[i*4+1]=y; S[i*4+2]=0.25+rnd()*0.75; S[i*4+3]=Math.min(1,0.25+rnd()*0.75+band*0.7);
  }
  var R = new Float32Array(NRAIN*3);
    for(var j=0;j<NRAIN;j++){ R[j*3]=rnd()*2-1; R[j*3+1]=rnd()*2-1; R[j*3+2]=0.4+rnd()*0.6; }

    var VS = "attribute vec2 p;attribute vec2 q;uniform float uT;uniform float uTrav;" +
      "varying float vA;void main(){float depth=0.4+0.6*q.x;" +
      "vec2 pos=p;pos.y+=uT*0.004*depth;pos.y+=uTrav*0.35*depth;" + // scroll travel
      "pos=fract(pos*0.5+0.5)*2.0-1.0;" +
      "gl_Position=vec4(pos,0.,1.);vA=q.y;gl_PointSize=(1.0+2.2*q.x)*(1.0-uTrav*0.2);}";
    var FS = "precision mediump float;varying float vA;uniform float uBeat;" +
      "void main(){vec2 d=gl_PointCoord-0.5;if(dot(d,d)>0.25)discard;" +
      "gl_FragColor=vec4(vec3(1.0),vA*(1.0+uBeat*0.6));}";
    function sh(t,s){ var h=gl.createShader(t); gl.shaderSource(h,s); gl.compileShader(h); return h; }
    var pr = gl.createProgram();
    gl.attachShader(pr, sh(gl.VERTEX_SHADER,VS)); gl.attachShader(pr, sh(gl.FRAGMENT_SHADER,FS));
    gl.linkProgram(pr); gl.useProgram(pr);
    var buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, S, gl.STATIC_DRAW);
    var lp = gl.getAttribLocation(pr,"p"), lq = gl.getAttribLocation(pr,"q");
    gl.enableVertexAttribArray(lp); gl.enableVertexAttribArray(lq);
    gl.vertexAttribPointer(lp,2,gl.FLOAT,false,16,0);
    gl.vertexAttribPointer(lq,2,gl.FLOAT,false,16,8);
    var uT=gl.getUniformLocation(pr,"uT"), uTrav=gl.getUniformLocation(pr,"uTrav"),
        uBeat=gl.getUniformLocation(pr,"uBeat");
    gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA, gl.ONE);

    // moon phase persists across pages
    var phase = Number(sessionStorage.getItem("g4_moon")||0);
    var meteors = [], nextMet = 2.6+Math.random()*4;
    var trav = 0, travGoal = 0, t = 0, last = performance.now();
    // REMOVED: rain layer - keeping only stars and moon/meteors
    // var rc = document.createElement("canvas"); rc.id="rainLayer";
    // rc.style.cssText="position:fixed;inset:0;z-index:1;pointer-events:none;opacity:.5";
    // document.body.appendChild(rc); rain = rc.getContext("2d");

  function size(){ var d=Math.min(2,devicePixelRatio||1);
    cv.width=innerWidth*d; cv.height=innerHeight*d;
    gl.viewport(0,0,cv.width,cv.height);
    rc.width=innerWidth; rc.height=innerHeight; }
  size(); addEventListener("resize", size);

  cv.addEventListener("webglcontextlost", function(e){ e.preventDefault(); cv._lost=true; });
  cv.addEventListener("webglcontextrestored", function(){ cv._lost=false; size(); });

  var FOLLOW = 0.98; // per-1/60s lag factor
  G.loop("sky", function(tt, dt){
      if(cv._lost || document.hidden) return;
      var k = 1-Math.pow(1-FOLLOW, dt*60); // framerate-independent, never overshoots
      var maxS = document.documentElement.scrollHeight - innerHeight || 1;
      travGoal = Math.min(1, scrollY/maxS) * 0.52; // TRAVEL 520 (normalized)
      trav += (travGoal-trav)*k;
      t += dt;
      phase += dt*0.03; // moon spin 0.03 rad/s
      sessionStorage.setItem("g4_moon", String(phase%6.283));
      gl.clearColor(0,0,0,1); gl.clear(gl.COLOR_BUFFER_BIT);
      gl.uniform1f(uT,t); gl.uniform1f(uTrav,trav); gl.uniform1f(uBeat,G.viz?G.viz.beat:0);
      gl.drawArrays(gl.POINTS,0,NST);
      drawMoon(trav); drawMeteors(dt);
    });

    var moon = document.createElement("canvas"); moon.width=moon.height=128;
    function drawMoon(trav){
      // procedural moon on 2D overlay (cheap, attached maria rotate with phase)
      // Draw directly to WebGL canvas via 2D context overlay
      var x = cv.getContext("2d");
      if(!x) return;
      var mx = cv.width*0.78, my = cv.height*0.2 - trav*120;
      x.save(); x.strokeStyle="#fff"; x.fillStyle="#000"; x.lineWidth=2;
      x.beginPath(); x.arc(mx,my,44,0,7); x.fill(); x.stroke();
      x.save(); x.beginPath(); x.arc(mx,my,44,0,7); x.clip();
      // terminator: dark half sweeping with phase
      var tx=Math.cos(phase)*44;
      x.fillStyle="rgba(0,0,0,0.85)"; x.fillRect(tx>0?mx:mx+tx,my-44,Math.abs(tx),88);
      // maria attached to model-space normals -> rotate with phase
      x.fillStyle="rgba(255,255,255,0.75)";
      for(var m=0;m<7;m++){ var a=phase+m*0.9, rr=10+((m*13)%22);
        x.beginPath(); x.arc(mx+Math.cos(a)*20, my+Math.sin(a)*20, 4+(m%3)*3, 0, 7); x.fill(); }
      x.restore(); x.restore();
    }
    function drawMeteors(dt){
      nextMet-=dt;
      if(nextMet<=0 && meteors.length<4){
        meteors.push({x:Math.random()*0.8+0.1,y:Math.random()*0.3,vx:-(0.5+Math.random()*0.4),vy:0.25,life:1});
        nextMet=2.6+Math.random()*7.4; // one at a time every 2.6-10s
      }
      var x = cv.getContext("2d");
      if(!x) return;
      meteors=meteors.filter(function(m){ return m.life>0; });
      meteors.forEach(function(m){
        m.x+=m.vx*dt; m.y+=m.vy*dt; m.life-=dt*0.7;
        x.save(); x.translate(m.x*cv.width,m.y*cv.height); x.rotate(Math.atan2(m.vy,m.vx));
        var g=x.createLinearGradient(0,0,-120,0); // tapered ribbon
        g.addColorStop(0,"rgba(255,255,255,"+(0.9*m.life)+")"); g.addColorStop(1,"transparent");
        x.fillStyle=g; x.beginPath(); x.moveTo(0,-2); x.lineTo(-120,-0.5); x.lineTo(-120,0.5); x.lineTo(0,2); x.fill();
        x.restore();
      });
    }
  function staticScatter(cv){ // FX OFF fallback
    var x=cv.getContext("2d"); function p(){ x.fillStyle="#000";x.fillRect(0,0,cv.width,cv.height);
      x.fillStyle="#fff"; var r=G.mulberry32(1337);
      for(var i=0;i<400;i++) x.fillRect(r()*cv.width,r()*cv.height,2,2); }
    function s(){ cv.width=innerWidth;cv.height=innerHeight;p(); }
    s(); addEventListener("resize",s);
  }
};
function staticScatter(cv){
  var x=cv.getContext("2d");
  cv.width=innerWidth; cv.height=innerHeight;
  x.fillStyle="#000"; x.fillRect(0,0,cv.width,cv.height); x.fillStyle="#fff";
  var r=G.mulberry32(1337);
  for(var i=0;i<400;i++) x.fillRect(r()*cv.width,r()*cv.height,2,2);
}
})();
