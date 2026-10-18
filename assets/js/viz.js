/* viz.js — one analyser, one pass per frame, many renderers.
   Computes log bins, peak-hold, bass/mid/treble, scope buffer, beat detect
   (bass > 1.4×moving avg, 180ms refractory) → emits beat. Never blank: idle
   synthetic spectrum when no audio. Geometry only, no text/katakana. */
(function(){
"use strict";
var G = window.G4;
var V = G.viz = { mode: 2, canvases: [], beat: 0 }; // 0 BARS · 1 MIRROR · 2 SCOPE (default) · 3 RADIAL
var N = 96, peaks = new Float32Array(N), holds = new Float32Array(N);
var bassAvg = 0.3, lastBeat = 0, idleT = 0;
var listeners = [];
V.onBeat = function(fn){ listeners.push(fn); };

V.register = function(canvas, opts){
  if(!canvas) return;
  V.canvases.push({c:canvas, kind:(opts&&opts.kind)||"dock", mode:(opts&&opts.mode)});
  sizeCanvas(canvas);
};
function sizeCanvas(c){
  var dpr = Math.min(2, devicePixelRatio||1), r = c.getBoundingClientRect();
  var w = Math.max(50, r.width||c.clientWidth||300), h = Math.max(20, r.height||64);
  c.width = w*dpr; c.height = h*dpr;
}
addEventListener("resize", function(){
  // ignore tiny changes (mobile URL-bar jitter)
  clearTimeout(V._rt); V._rt = setTimeout(function(){
    V.canvases.forEach(function(o){ sizeCanvas(o.c); }); }, 200);
});
V.setMode = function(m){ V.mode = m;
  V.canvases.forEach(function(o){ if(o.kind==="dock") o.mode = m; }); };

function analyze(){
  var A = G.audio, bins = new Float32Array(N), scope = null, e={bass:0,mid:0,tre:0};
  var live = A && A.ready && A.an;
  if(live){
    var raw = new Uint8Array(A.an.frequencyBinCount);
    A.an.getByteFrequencyData(raw);
    for(var i=0;i<N;i++){ // log-mapped bins
      var f = Math.pow(i/N, 1.7), idx = Math.floor(f*raw.length*0.72);
      bins[i] = raw[idx]/255;
    }
    var sb = new Uint8Array(A.an.fftSize); A.an.getByteTimeDomainData(sb); scope = sb;
    var nb=0,nm=0,nt=0;
    for(var j=0;j<N;j++){ if(j<N*0.25){e.bass+=bins[j];nb++;} else if(j<N*0.6){e.mid+=bins[j];nm++;} else {e.tre+=bins[j];nt++;} }
    e.bass/=nb; e.mid/=nm; e.tre/=nt;
  } else { // idle synthetic low-amplitude spectrum
    idleT += 0.016;
    for(var k=0;k<N;k++)
      bins[k] = 0.08 + 0.06*Math.sin(idleT*2+k*0.35) + 0.04*Math.sin(idleT*3.7+k*0.11);
    e = {bass:0.12, mid:0.1, tre:0.08};
  }
  // peak-hold with falling caps
  for(var p=0;p<N;p++){ holds[p] = Math.max(bins[p], holds[p]-0.012); peaks[p]=bins[p]; }
  // beat detect
  bassAvg = bassAvg*0.97 + e.bass*0.03;
  var now = performance.now();
  if(e.bass > bassAvg*1.4 + 0.08 && now-lastBeat > 180){
    lastBeat = now; V.beat = 1;
    listeners.forEach(function(f){ try{f();}catch(e2){} });
  } else V.beat = Math.max(0, V.beat-0.05);
  return {bins:bins, scope:scope, e:e};
}

function draw(o, d){
  var c=o.c, x=c.getContext("2d"), W=c.width, H=c.height;
  var mode = (o.mode!=null?o.mode:(o.kind==="edge"?1:V.mode));
  x.fillStyle="#000"; x.fillRect(0,0,W,H);
  x.fillStyle="#fff"; x.strokeStyle="#fff";
  var n = (o.kind==="edge")?96:64, bw = W/n;
  var i,v,h,px;
  if(mode===0){ // BARS + falling peak caps
    for(i=0;i<n;i++){ v=d.bins[(i*N/n)|0]; h=v*H;
      x.fillRect(i*bw+1, H-h, Math.max(1,bw-2), h);
      x.fillRect(i*bw+1, H-holds[(i*N/n)|0]*H-2, Math.max(1,bw-2), 2); }
  } else if(mode===1){ // MIRROR about center
    for(i=0;i<n;i++){ v=d.bins[(i*N/n)|0]; h=v*H*0.46;
      x.fillRect(i*bw+1, H/2-h, Math.max(1,bw-2), h);
      x.fillRect(i*bw+1, H/2, Math.max(1,bw-2), h); }
    x.fillRect(0,H/2-1,W,2);
  } else if(mode===2){ // SCOPE 1.5px + persistence + graticule
    x.fillStyle="rgba(0,0,0,0.35)"; x.fillRect(0,0,W,H);
    x.strokeStyle="rgba(255,255,255,0.25)"; x.lineWidth=1;
    for(px=0;px<4;px++){ x.beginPath(); x.moveTo(0,H*(px+1)/5); x.lineTo(W,H*(px+1)/5); x.stroke(); }
    x.strokeStyle="#fff"; x.lineWidth=Math.max(1.5,(W/300)*1.5); x.beginPath();
    if(d.scope){ for(i=0;i<d.scope.length;i+=4){
        var sx=i/d.scope.length*W, sy=H/2+((d.scope[i]-128)/128)*H*0.42;
        i===0?x.moveTo(sx,sy):x.lineTo(sx,sy); } }
    else { for(i=0;i<=W;i+=6){ var wy=H/2+Math.sin(i*0.05+idleT*3)*H*0.2;
        i===0?x.moveTo(i,wy):x.lineTo(i,wy); } }
    x.stroke();
  } else { // RADIAL ring
    var cx=W/2, cy=H/2, R=Math.min(W,H)*0.28, rot=(performance.now()/1000)*0.4;
    x.save(); x.translate(cx,cy); x.rotate(rot);
    for(i=0;i<n;i++){ v=d.bins[(i*N/n)|0];
      var a=i/n*Math.PI*2, l=4+v*Math.min(W,H)*0.3;
      x.save(); x.rotate(a); x.fillRect(R, -1, l, 2); x.restore(); }
    x.beginPath(); x.arc(0,0,R,0,7); x.stroke(); x.restore();
  }
  // header edge mask fade is CSS; dock gets peak flash on beat
  if(V.beat>0.6 && o.kind==="dock"){ x.fillStyle="rgba(255,255,255,0.25)"; x.fillRect(0,0,W,3); }
}

G.loop("viz", function(){
  if(G.fxOff() && V.canvases.length) { /* OFF: still paint one static-ish frame rarely */ }
  var d = analyze();
  for(var i=0;i<V.canvases.length;i++){
    var o=V.canvases[i];
    if(!o.c.isConnected) continue;
    if(o.kind!=="hero"){ var r=o.c.getBoundingClientRect();
      if(r.bottom<0||r.top>innerHeight) continue; }
    draw(o,d);
  }
  // mini VU + rate-limited beat reactions
  var vu = document.getElementById("vuMini");
  if(vu){ var x=vu.getContext("2d"); x.fillStyle="#000"; x.fillRect(0,0,34,14);
    x.fillStyle="#fff"; x.fillRect(0,14-14*G.audio.level(),34,14*G.audio.level()); }
  if(V.beat>0.9) V._react && V._react();
});
/* beat reactions wired by pages.js (rate-limited there): logo flicker, grain bump, ghost pulse */
})();
