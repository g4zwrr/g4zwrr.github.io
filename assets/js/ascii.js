/* ascii.js — real-time 3D → ASCII (a1k0n-style z-buffer).
   Surfaces are sampled densely with real per-point normals, rotated by A/B,
   perspective-projected and splatted into a per-cell z-buffer that is shaded
   with the ramp " .,-~:;=!*#$@". 5 shapes, switch every 3s (2.5s hold + 0.5s
   glitch in 3 phases: tear → noise+scanband → resolve).

   Sizing: the char grid is measured from the <pre>'s real font metrics, and
   the projection scale is FITTED so the shape fills the viewport. The char
   cell is ~1.9x taller than it is wide, so x is scaled by ch/cw to keep the
   shape round instead of squashed. CAMZ/FILL control distance and margin.

   Spec panel: name/index, samples/faces, equation, A/B deg, FPS, ramp, SVG
   countdown ring. Drag = inertia spin, click = next, arrows = nudge.
   Reduced motion: one static frame. */
(function(){
"use strict";
var G = window.G4;
var RAMP = " .,-~:;=!*#$@";
var TAU = Math.PI * 2;
var CAMZ = 3.6;   // camera distance in world units (smaller = stronger 3D)
var FILL = 0.88;  // most of the viewport the shape may occupy, over a rotation
var AMB  = 0.10;  // ambient floor so back faces still shade faintly
var LIGHT = (function(v){ var l=Math.hypot(v[0],v[1],v[2])||1;
  return [v[0]/l, v[1]/l, v[2]/l]; })([0.4,0.5,-0.8]);

/* ---------- sampling: flat [x,y,z,nx,ny,nz] per point ---------- */
function pack(list){
  var a = new Float32Array(list), rmax = 0, i, d;
  for(i=0;i<a.length;i+=6){ d = Math.hypot(a[i],a[i+1],a[i+2]); if(d>rmax) rmax = d; }
  return { pts:a, rmax:rmax, verts:a.length/6 };
}
function buildTorus(uN, vN, R, r){
  var L=[], i, j, u, v, cu, su, cv, sv, rr;
  for(i=0;i<uN;i++){
    u = i/uN*TAU; cu = Math.cos(u); su = Math.sin(u);
    for(j=0;j<vN;j++){
      v = j/vN*TAU; cv = Math.cos(v); sv = Math.sin(v); rr = R + r*cv;
      L.push(rr*cu, rr*su, r*sv, cv*cu, cv*su, sv);
    }
  }
  var o = pack(L); o.faces = uN*vN*2; return o;
}
function buildCube(n){
  var L=[], f, s, i, j, t, w, a1, a2, nn;
  for(f=0;f<3;f++) for(s=-1;s<=1;s+=2){
    a1 = (f+1)%3; a2 = (f+2)%3;
    nn = [0,0,0]; nn[f] = s;
    for(i=0;i<n;i++){ t = -1 + 2*(i+0.5)/n;
      for(j=0;j<n;j++){ w = -1 + 2*(j+0.5)/n;
        var p = [0,0,0]; p[f] = s; p[a1] = t; p[a2] = w;
        L.push(p[0],p[1],p[2], nn[0],nn[1],nn[2]);
      } }
  }
  var o = pack(L); o.faces = 6*2*n*n; return o;
}
function buildPyramid(n, bn){
  // |x| + |z| + 2y = 2 -> square base at y=0, apex (0,1,0). 4 side faces + base.
  var L=[], i, j, u, v, ww, ax, sgn, B1, B2, A=[0,1,0];
  for(ax=0;ax<2;ax++) for(sgn=-1;sgn<=1;sgn+=2){
    B1=[0,0,0]; B2=[0,0,0];
    B1[ax] = sgn; B1[1-ax] =  1;
    B2[ax] = sgn; B2[1-ax] = -1;
    var e1=[B1[0]-A[0], B1[1]-A[1], B1[2]-A[2]];
    var e2=[B2[0]-A[0], B2[1]-A[1], B2[2]-A[2]];
    var nx=e1[1]*e2[2]-e1[2]*e2[1], ny=e1[2]*e2[0]-e1[0]*e2[2], nz=e1[0]*e2[1]-e1[1]*e2[0];
    var l=Math.hypot(nx,ny,nz)||1; nx/=l; ny/=l; nz/=l;
    if(ny<0){ nx=-nx; ny=-ny; nz=-nz; }        // point outward (up-ish)
    for(i=0;i<=n;i++){ u = i/n;
      for(j=0;j<=n-i;j++){ v = j/n; ww = 1-u-v;
        L.push(u*A[0]+v*B1[0]+ww*B2[0], u*A[1]+v*B1[1]+ww*B2[1],
               u*A[2]+v*B1[2]+ww*B2[2], nx,ny,nz);
      } }
  }
  for(i=0;i<bn;i++){ var tx = -1 + 2*(i+0.5)/bn;
    for(j=0;j<bn;j++){ var tz = -1 + 2*(j+0.5)/bn;
      L.push(tx, 0, tz, 0,-1,0);
    } }
  var o = pack(L); o.faces = 4*2*n*n + 2*bn*bn; return o;
}
function buildTrefoil(uN, vN, rad){
  // (2,3) knot: 2 turns of the centre curve, 3 lobes, circular tube of `rad`
  var L=[], i, j, u, v, cu, su, cv, sv, rr;
  for(i=0;i<uN;i++){
    u = i/uN*Math.PI*4; cu = Math.cos(u); su = Math.sin(u);
    rr = 0.5 + 0.28*Math.cos(1.5*u);
    for(j=0;j<vN;j++){
      v = j/vN*TAU; cv = Math.cos(v); sv = Math.sin(v);
      L.push(rr*cu + rad*cv*cu, rr*su + rad*cv*su, 0.35*Math.sin(1.5*u) + rad*sv,
             cv*cu, cv*su, sv);
    }
  }
  var o = pack(L); o.faces = uN*vN*2; return o;
}
function buildOcta(n){
  // |x|+|y|+|z| = 1: 8 triangular faces, exact face normals (sx,sy,sz)/√3
  var L=[], sx, sy, sz, i, j, u, v, ww, inv=1/Math.sqrt(3);
  for(sx=-1;sx<=1;sx+=2) for(sy=-1;sy<=1;sy+=2) for(sz=-1;sz<=1;sz+=2){
    var V1=[sx,0,0], V2=[0,sy,0], V3=[0,0,sz];
    var nx=sx*inv, ny=sy*inv, nz=sz*inv;
    for(i=0;i<=n;i++){ u = i/n;
      for(j=0;j<=n-i;j++){ v = j/n; ww = 1-u-v;
        L.push(u*V1[0]+v*V2[0]+ww*V3[0], u*V1[1]+v*V2[1]+ww*V3[1],
               u*V1[2]+v*V2[2]+ww*V3[2], nx,ny,nz);
      } }
  }
  var o = pack(L); o.faces = 8*2*n*n; return o;
}
var SHAPES = [
  {name:"TORUS",      eq:"(R−√(x²+y²))²+z²=r²", make:function(){ return buildTorus(120,72,1,0.42); }},
  {name:"CUBE",       eq:"|x|=|y|=|z|=1",       make:function(){ return buildCube(40); }},
  {name:"PYRAMID",    eq:"|x|+|z|+2y=2",        make:function(){ return buildPyramid(56,28); }},
  {name:"TREFOIL",    eq:"((2+cos3u)cos2u,…)×r",make:function(){ return buildTrefoil(180,44,0.2); }},
  {name:"OCTAHEDRON", eq:"|x|+|y|+|z|=1",       make:function(){ return buildOcta(38); }}
];
SHAPES.forEach(function(s){ var g = s.make();
  s.pts = g.pts; s.rmax = g.rmax; s.verts = g.verts; s.faces = g.faces; });
/* (SPHERE removed by request — was a sample of Ø = 961 pts) */

G.initAscii = function(){
  var pre = document.getElementById("ascii"); if(!pre) return;
  var specName = document.getElementById("specName"), specIdx = document.getElementById("specIdx"),
      specEq   = document.getElementById("specEq"),   specAB  = document.getElementById("specAB"),
      specFps  = document.getElementById("specFps"),  specVf  = document.getElementById("specVf"),
      ring     = document.getElementById("specRingFg");

  /* ---------- grid: measured from real font metrics, refit on resize ---------- */
  var W = 64, H = 30, cw = 6.6, ch = 12.65, cx = 0, cy = 0;
  var zb = null, cell = null;
  function metrics(){
    var cs = getComputedStyle(pre);
    var fs = parseFloat(cs.fontSize) || 11;
    var lh = parseFloat(cs.lineHeight); if(!(lh > 0)) lh = fs*1.15;
    var c = document.createElement("canvas").getContext("2d");
    c.font = (cs.fontStyle||"normal")+" "+(cs.fontWeight||"400")+" "+fs+"px "+(cs.fontFamily||"monospace");
    var w = c.measureText("MMMMMMMMMM").width / 10;
    if(!(w > 1)) w = fs*0.6;
    return { cw:w, ch:lh,
      padX:(parseFloat(cs.paddingLeft)||0)+(parseFloat(cs.paddingRight)||0),
      padY:(parseFloat(cs.paddingTop)||0)+(parseFloat(cs.paddingBottom)||0) };
  }
  function fit(){
    var m = metrics();
    cw = m.cw; ch = m.ch;
    var availW = pre.clientWidth - m.padX, availH = pre.clientHeight - m.padY;
    if(availW > 40 && availH > 40){
      W = Math.max(24, Math.min(200, Math.floor(availW/cw)));
      H = Math.max(12, Math.min(96,  Math.floor(availH/ch)));
    }
    if(!zb || zb.length !== W*H){ zb = new Float32Array(W*H); cell = new Uint8Array(W*H); }
    cx = (W-1)/2; cy = (H-1)/2;
  }
  // pixels per world unit at unit depth, so the shape fills the viewport
  function scaleFor(rmax){
    var halfPx = Math.min(W*cw, H*ch) * 0.5 * FILL;
    var k = Math.sqrt(Math.max(0.01, CAMZ*CAMZ - rmax*rmax)) / rmax;
    return halfPx * k;
  }

  var shape = 0, A = 0.6, B = 0.4, vA = 0.02, vB = 0.013, tSwitch = 0;
  var last = performance.now(), fps = 30, frames = 0, fT = 0;
  var dragV = 0, dragU = 0;

  function render(sIdx, gl, gp, t){
    var sh = SHAPES[sIdx], pts = sh.pts, n = pts.length;
    zb.fill(-1e9); cell.fill(0);
    var ca = Math.cos(A), sa = Math.sin(A), cb = Math.cos(B), sb = Math.sin(B);
    var P = scaleFor(sh.rmax), kx = P/cw, ky = P/ch;
    var lx = LIGHT[0], ly = LIGHT[1], lz = LIGHT[2], kamb = 1 - AMB;
    var i, x, y, z, nx, ny, nz, y1, z1, x2, z2, zz, inv, col, row, sx, sy, idx;
    var oob, lum, n1y, n1z, n2x, n2z, ci;
    for(i=0;i<n;i+=6){
      x = pts[i]; y = pts[i+1]; z = pts[i+2];
      // rotate about X by A, then about Y by B (matches the original A/B axes)
      y1 = y*ca - z*sa;  z1 = y*sa + z*ca;
      x2 = x*cb - z1*sb; z2 = x*sb + z1*cb;
      zz = CAMZ + z2; if(zz < 0.25) continue;
      inv = 1/zz;
      col = cx + x2*kx*inv; row = cy - y1*ky*inv;
      if(col < 0 || col >= W || row < 0 || row >= H) continue;
      sx = (col + 0.5) | 0; if(sx < 0) sx = 0; else if(sx >= W) sx = W-1;
      sy = (row + 0.5) | 0; if(sy < 0) sy = 0; else if(sy >= H) sy = H-1;
      idx = sy*W + sx;
      oob = inv;                       // 1/z: bigger = nearer
      if(oob <= zb[idx]) continue;
      // shaded with the same rotation applied to the surface normal
      nx = pts[i+3]; ny = pts[i+4]; nz = pts[i+5];
      n1y = ny*ca - nz*sa;  n1z = ny*sa + nz*ca;
      n2x = nx*cb - n1z*sb; n2z = nx*sb + n1z*cb;
      lum = n2x*lx + n1y*ly + n2z*lz;
      if(lum < 0) lum = 0; else if(lum > 1) lum = 1;
      lum = AMB + kamb*lum;
      ci = (lum * (RAMP.length-1)) | 0; if(ci > RAMP.length-1) ci = RAMP.length-1;
      zb[idx] = oob; cell[idx] = ci;
    }
    var lines = [], off, rowS, y2, x2c;
    for(y2=0;y2<H;y2++){
      off = y2*W; rowS = "";
      for(x2c=0;x2c<W;x2c++) rowS += RAMP[cell[off+x2c]];
      if(gl){
        if(gp === 0){                            // tear + noise + reseat
          if(Math.random() < 0.5){
            var shf = (Math.random()*10-5)|0;
            rowS = rowS.slice(Math.abs(shf)).padEnd(W, " ");
            if(shf < 0) rowS = rowS.split("").reverse().join("");
            rowS = rowS.replace(/./g, function(c){ return Math.random()<0.25
              ? RAMP[(Math.random()*RAMP.length)|0] : c; });
          }
        } else if(gp === 1){                     // full noise + bright scan band
          rowS = rowS.replace(/./g, function(){ return RAMP[(Math.random()*RAMP.length)|0]; });
          if(Math.abs(y2/H - ((t*3)%1)) < 0.08) rowS = rowS.replace(/ /g, "@");
        } else {                                 // resolve: noise falls away
          rowS = rowS.replace(/./g, function(c){ return Math.random()<0.4 ? " " : c; });
        }
      }
      lines.push(rowS);
    }
    pre.textContent = lines.join("\n");
    if(gl && G.viz) G.viz.beat = Math.max(G.viz.beat, 0.5);
    if(G.viz) pre.style.transform = "scale("+(1 + G.viz.beat*0.01)+")";
  }

  function pad2(v){ return (v<10?"0":"")+v; }
  function paintSpec(){
    var s = SHAPES[shape];
    if(specName){ if(!G.fxOff()) G.scramble(specName, s.name, 300); else specName.textContent = s.name; }
    if(specIdx) specIdx.textContent = pad2(shape+1)+" / "+pad2(SHAPES.length);
    if(specEq) specEq.textContent = s.eq;
    if(specVf) specVf.textContent = s.verts+" VT · "+s.faces+" FC";
  }

  function frame(now){
    var dt = Math.min(0.1, (now-last)/1000); last = now;
    frames++; fT += dt; if(fT >= 0.5){ fps = Math.round(frames/fT); frames = 0; fT = 0; }
    A += vA + dragV; B += vB + dragU;
    dragV *= 0.94; dragU *= 0.94;
    tSwitch += dt;
    var glitching = false, gphase = -1;
    if(!G.reduced() && tSwitch > 2.5){
      glitching = true;
      var gt = tSwitch - 2.5;
      gphase = gt < 0.2 ? 0 : gt < 0.35 ? 1 : 2;
      if(tSwitch >= 3.0){ shape = (shape+1) % SHAPES.length; tSwitch = 0; paintSpec(); }
    }
    render(shape, glitching, gphase, now/1000);
    if(specAB) specAB.textContent = Math.round(A*57.3)%360+"° / "+Math.round(B*57.3)%360+"°";
    if(specFps) specFps.textContent = fps+" FPS";
    if(ring) ring.style.strokeDashoffset = String(2*Math.PI*26*(tSwitch/3));
  }

  fit();
  paintSpec();
  if(document.fonts && document.fonts.ready && document.fonts.ready.then){
    document.fonts.ready.then(function(){ fit(); });   // remeasure once webfonts land
  }
  var rT = 0;
  addEventListener("resize", function(){ clearTimeout(rT); rT = setTimeout(fit, 150); });

  // interactions: drag spin w/ inertia, click next, arrows nudge
  var down = null, moved = 0;
  pre.parentElement.style.cursor = "grab";
  pre.parentElement.addEventListener("pointerdown", function(e){ down = [e.clientX,e.clientY]; moved = 0; });
  addEventListener("pointermove", function(e){ if(!down) return;
    var dx = e.clientX-down[0], dy = e.clientY-down[1]; moved += Math.abs(dx)+Math.abs(dy);
    dragU = dx*0.0004; dragV = dy*0.0003; down = [e.clientX,e.clientY]; });
  addEventListener("pointerup", function(){ down = null; });
  pre.parentElement.addEventListener("click", function(){
    if(moved < 6){ shape = (shape+1) % SHAPES.length; tSwitch = 0; paintSpec(); } });
  pre.parentElement.tabIndex = 0;
  pre.parentElement.addEventListener("keydown", function(e){
    if(e.key === "ArrowRight"){ B += 0.2; } if(e.key === "ArrowLeft"){ B -= 0.2; }
    if(e.key === "ArrowUp"){ A -= 0.2; }    if(e.key === "ArrowDown"){ A += 0.2; } });

  if(G.reduced()){ render(0, false, -1, 0); return; }  // static torus, click switches
  G.loop("ascii", function(){ frame(performance.now()); }, {el:pre});
};
})();
