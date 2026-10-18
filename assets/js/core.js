/* core.js — G4 namespace, config, utils, FX mode, master rAF loop.
   Plain script (no modules) so file:// works. Must load FIRST (deferred). */
(function(){
"use strict";
window.G4 = window.G4 || {};
var G = window.G4;

/* ---------- editable config (top, easy to swap) ---------- */
G.BASE = ""; // subpath hosting, e.g. "/g4zwr.github.io"
G.CONFIG = {
  handle: "g4zwr", aka: "gaze", ghUser: "g4zwr",
  excluded: ["g4zwr", "g4zwr.github.io"],
  quote: "yes i see the bug too, im trying to fix it rn",
  tagline: "Gamedev",
  audio: "/assets/audio/teto-lairac.mp3",
  email: "g4zwr@duck.com",
  contacts: [
    {id:"roblox", name:"Roblox", url:"https://www.roblox.com/users/10841765037", blurb:"Add me in-game or see what I'm building."},
    {id:"youtube", name:"YouTube", url:"https://www.youtube.com/@g4zwr", blurb:"Devlogs and clips."},
    {id:"tiktok", name:"TikTok", url:"https://www.tiktok.com/@g4zwr", blurb:"Short clips and behind-the-scenes."},
    {id:"discord", name:"Discord", url:"https://discord.com/users/1296500534739734530", blurb:"Game dev talk, playtesting, dev servers."},
    {id:"reddit", name:"Reddit", url:"https://www.reddit.com/user/g4zwr", blurb:"Posting progress, lurking dev communities."},
    {id:"x", name:"X", url:"https://x.com/g4zwr_", blurb:"Updates and random thoughts."},
    {id:"email", name:"Email", url:"mailto:g4zwr@duck.com", blurb:"Longer-form or business inquiries."}
  ],
  stack: [
    {name:"Luau", role:"Roblox scripting", cat:"LANG", why:"Lua with types, and that's most of why it sticks. It catches my own mistakes before a playtest does, and since the client and the server run the same language, I write a system once instead of twice. Rename something at 3am and the editor tells me exactly what I broke. It runs on every device Roblox runs on, so porting isn't a thing I think about."},
    {name:"Python", role:"tools & scripts", cat:"LANG", why:"The glue. Scraping GitHub, batch-processing assets, one-off data transforms — it's the only language where I can write a 40-line script in 3 minutes that saves me 3 hours of manual work. Plus the ecosystem means someone's already solved whatever weird format I'm dealing with."},
    {name:"HTML5", role:"web", cat:"LANG", why:"No build step, no bundler drama, no framework churn. I write HTML/CSS/JS and it runs everywhere — browser, WebView, Electron, mobile wrapper. This site is vanilla. The portfolio loads in 200ms on mobile because there's nothing to compile. I'd rather debug my own CSS than debug a webpack config."},
    {name:"Roblox Studio", role:"game dev", cat:"TOOL", why:"It's the whole pipeline in one window — modeling, scripting, debugging, playtesting, publishing. The Luau type checker catches bugs live while I type. Team Create means I can pair-program with a friend in real time without git conflicts. And when something breaks in production, I can hot-patch it in 30 seconds."},
    {name:"Prisma 3D", role:"3D modeling", cat:"TOOL", why:"Runs on my phone. That's the killer feature. I can block out a character on the bus, refine it on my laptop, export GLB, drop it into Studio. No Blender learning curve, no 5GB install. The subdivision + symmetry workflow is fast enough for game-ready low-poly without retopology headaches."},
    {name:"APKTool M", role:"mobile dev", cat:"TOOL", why:"Decompile, tweak, recompile, sign — all on the phone itself. I use it to inspect how other games handle permissions, manifest tweaks, or resource packing. No ADB, no Android Studio, no 10GB SDK. Just: open APK → edit smali/XML → build → install. Terrifying power in a 5MB app."},
    {name:"FL Studio Mobile", role:"music production", cat:"TOOL", why:"Same project file as desktop FL. I start a beat on my phone during a commute, airdrop it to the PC, finish the mix there. The piano roll, mixer, and automation work identically. Most mobile DAWs are toys — this one's a real session that happens to fit in my pocket."},
    {name:"ibis Paint X", role:"digital art", cat:"TOOL", why:"Layer clipping masks, perspective rulers, stroke stabilization, and it records timelapses automatically. The brush engine handles 4000px canvases at 60fps on a midrange phone. I've done client commissions entirely on this. The UI is cluttered but the shortcuts are muscle memory now."},
    {name:"Alight Motion", role:"animation", cat:"TOOL", why:"After Effects logic — keyframes, easing graphs, expressions, vector layers — but on Android. I make UI motion prototypes, lyric videos, transition effects for games. Export to Lottie JSON or MP4. It's the only mobile app where I can do 'position.wiggle(3,15)' and it just works."},
    {name:"Windows", role:"daily driver", cat:"ENV", why:"Roblox Studio runs natively. FL Studio runs natively. My drawing tablet drivers just work. OBS, Discord, VS Code, browser dev tools — zero friction. I've tried daily-driving Linux; the 10% of time spent fixing audio routing or GPU passthrough isn't worth the ideological win."},
    {name:"Arch Linux", role:"secondary", cat:"ENV", why:"My build server, headless render box, and 'I need a real terminal right now' machine. Pacman + AUR means every dev tool is one command away. I run CI, host preview deploys, and compile Luau type definitions here. It breaks sometimes — that's the point, I learn how the OS actually works when it does."}
  ],
  currently: [
    {t:"ROBLOX / LUAU", d:"Roblox dev building systems in Luau.", glyph:"▣"},
    {t:"MUSIC / FL STUDIO", d:"Producing music on PC and mobile with FL Studio.", glyph:"♪"},
    {t:"ART 2D & 3D", d:"Drawing and animating in 2D and 3D.", glyph:"◈"}
  ]
};
// Inline 24x24 monochrome brand icons (fill:currentColor). Original minimal glyphs.
G.ICONS = {
  roblox:'<svg viewBox="0 0 24 24"><path fill="currentColor" d="M21.5 5.5a4 4 0 0 0-4-4h-11a4 4 0 0 0-4 4v13a4 4 0 0 0 4 4h11a4 4 0 0 0 4-4v-13zm-3.3 2.9H8.5a1.3 1.3 0 0 1-1.3-1.3V6.2a1.3 1.3 0 0 1 1.3-1.3h9.5a1.3 1.3 0 0 1 1.3 1.3v2.2a1.3 1.3 0 0 1-1.3 1.3zm-7 0h5.7v5.7H11.2V8.4zm-1.6 3.8a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm7.3-3.8a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z"/></svg>',
  youtube:'<svg viewBox="0 0 24 24"><path d="M23 7.2s-.2-1.6-.9-2.3c-.9-.9-1.9-.9-2.4-1C16.6 3.5 12 3.5 12 3.5s-4.6 0-7.7.4c-.5.1-1.5.1-2.4 1-.7.7-.9 2.3-.9 2.3S.8 9.1.8 11v1.8c0 1.9.2 3.8.2 3.8s.2 1.6.9 2.3c.9.9 2 .9 2.6 1 1.9.2 7.5.4 7.5.4s4.6 0 7.7-.4c.5-.1 1.5-.1 2.4-1 .7-.7.9-2.3.9-2.3s.2-1.9.2-3.8V11c0-1.9-.2-3.8-.2-3.8zM9.8 15.1V8.4l6.2 3.4-6.2 3.3z"/></svg>',
  tiktok:'<svg viewBox="0 0 24 24"><path d="M16.6 3c.4 2.2 1.9 3.7 4.4 3.8v3c-1.6 0-3-.5-4.4-1.4v6.6c0 3.9-2.7 6.5-6.3 6.5-3.4 0-6-2.6-6-6 0-3.5 2.8-6.1 6.4-6 0 0 .3 0 .6 0v3.2c-.2-.1-.5-.1-.8-.1-1.7 0-2.9 1.2-2.9 2.9 0 1.6 1.2 2.8 2.8 2.8 1.7 0 2.9-1.3 2.9-3.2V3h3.3z"/></svg>',
  discord:'<svg viewBox="0 0 24 24"><path d="M20.3 4.4A19.8 19.8 0 0 0 15.4 3l-.6 1.2c-1.4-.3-2.7-.3-4 0L10.2 3a19.7 19.7 0 0 0-4.9 1.5C2.2 9.1 1.4 13.6 1.8 18c2 1.5 4 2.4 5.9 3l.7-1.2c-1.1-.4-2.1-1-3-1.6l.7-.5c3.4 1.6 7.1 1.6 10.5 0l.7.5c-.9.6-1.9 1.2-3 1.6l.7 1.2c1.9-.6 3.9-1.5 5.9-3 .5-5.4-.7-9.6-3.6-13.6zM8.7 15.1c-1 0-1.8-.9-1.8-2s.8-2 1.8-2 1.8.9 1.8 2-.8 2-1.8 2zm6.6 0c-1 0-1.8-.9-1.8-2s.8-2 1.8-2 1.8.9 1.8 2-.8 2-1.8 2z"/></svg>',
  reddit:'<svg viewBox="0 0 24 24"><path d="M22 12.1c0-1.2-1-2.1-2.1-2.1-.6 0-1.1.2-1.5.6-1.4-1-3.3-1.6-5.4-1.7l1-4.5 3.1.7c.2-.9 1-1.5 2-1.5 1.1 0 2 .9 2 2s-.9 2-2 2c-.8 0-1.5-.5-1.8-1.2l-2.7-.6-.8 3.7c-2.2.1-4.2.7-5.7 1.7-.4-.4-.9-.6-1.5-.6-1.2 0-2.1.9-2.1 2.1 0 .8.5 1.5 1.1 1.9-.1.3-.1.5-.1.8 0 3.2 3.7 5.8 8.3 5.8s8.3-2.6 8.3-5.8c0-.3 0-.5-.1-.8.6-.3 1-1 1-1.8zM8.5 13.1c0-.8.7-1.5 1.5-1.5s1.5.7 1.5 1.5-.7 1.5-1.5 1.5-1.5-.6-1.5-1.5zm7 4.1c-.8.8-2.4 1.2-3.5 1.2s-2.7-.4-3.5-1.2c-.2-.2-.2-.5 0-.7.2-.2.5-.2.7 0 .6.6 1.9.9 2.8.9s2.2-.3 2.8-.9c.2-.2.5-.2.7 0 .2.2.2.5 0 .7zm-.5-2.6c-.8 0-1.5-.7-1.5-1.5s.7-1.5 1.5-1.5 1.5.7 1.5 1.5-.7 1.5-1.5 1.5z"/></svg>',
  x:'<svg viewBox="0 0 24 24"><path d="M18.9 2H22l-6.8 7.8L23.3 22h-6.3l-4.9-6.4L6.5 22H3.4l7.3-8.3L1 2h6.5l4.4 5.9L18.9 2zm-1.1 18h1.7L7.6 3.9H5.7L17.8 20z"/></svg>',
  email:'<svg viewBox="0 0 24 24"><path d="M2 5h20v14H2V5zm2 2v.4l8 5 8-5V7H4zm16 3.6-8 5-8-5V17h16v-6.4z"/></svg>'
};

/* ---------- utils ---------- */
G.esc = function(s){ return String(s==null?"":s).replace(/[&<>"']/g, function(c){
  return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]; }); };
G.q = function(s,r){ return (r||document).querySelector(s); };
G.qa = function(s,r){ return Array.prototype.slice.call((r||document).querySelectorAll(s)); };
G.mulberry32 = function(seed){ var a=seed>>>0; return function(){
  a|=0; a=a+0x6D2B79F5|0; var t=Math.imul(a^a>>>15,1|a);
  t=t+Math.imul(t^t>>>7,61|t)^t; return ((t^t>>>14)>>>0)/4294967296; }; };
G.timeAgo = function(iso){ var s=(Date.now()-new Date(iso).getTime())/1000;
  if(s<60) return "just now"; var m=s/60; if(m<60) return Math.floor(m)+"m ago";
  var h=m/60; if(h<24) return Math.floor(h)+"h ago"; var d=h/24;
  if(d<30) return Math.floor(d)+"d ago"; var mo=d/30;
  if(mo<12) return Math.floor(mo)+"mo ago"; return Math.floor(mo/12)+"y ago"; };
G.store = {
  get:function(k,d){ try{ var v=sessionStorage.getItem(k); return v==null?d:JSON.parse(v); }catch(e){ return d; } },
  set:function(k,v){ try{ sessionStorage.setItem(k,JSON.stringify(v)); }catch(e){} },
  lget:function(k,d){ try{ var v=localStorage.getItem(k); return v==null?d:JSON.parse(v); }catch(e){ return d; } },
  lset:function(k,v){ try{ localStorage.setItem(k,JSON.stringify(v)); }catch(e){} }
};
G.reduced = function(){ return window.matchMedia &&
  window.matchMedia("(prefers-reduced-motion: reduce)").matches; };

/* ---------- FX mode: FULL / LITE / OFF, persisted ---------- */
G.fxMode = G.store.lget("g4_fx", "FULL");
G.setFx = function(m){ G.fxMode=m; G.store.lset("g4_fx",m);
  document.documentElement.setAttribute("data-fx", m.toLowerCase());
  var b=G.q("#fxBtn"); if(b) b.textContent="FX "+m;
  var t=G.q("#teleFx"); if(t) t.textContent=m; };
G.fxOff = function(){ return G.fxMode==="OFF" || G.reduced(); };
G.fxLite = function(){ return G.fxMode==="LITE" || G.reduced(); };

/* ---------- master rAF loop: registered tasks, in-view + hidden gating ---------- */
G._tasks = [];
G.loop = function(name, fn, opts){ G._tasks.push({name:name, fn:fn, el:(opts&&opts.el)||null}); };
G._lastT = 0;
(function tick(t){
  requestAnimationFrame(tick);
  if(document.hidden) return;
  var dt = Math.min(0.05, (t - (G._lastT||t))/1000 || 0.016); G._lastT = t;
  for(var i=0;i<G._tasks.length;i++){ var tk=G._tasks[i];
    try{
      if(tk.el && tk.el.isConnected){
        var r=tk.el.getBoundingClientRect();
        if(r.bottom<-80||r.top>innerHeight+80) continue; // in-view gate
      }
      tk.fn(t/1000, dt);
    }catch(e){}
  }
})(0);

G.boot = function(page){ document.documentElement.setAttribute("data-fx",(G.fxMode||"FULL").toLowerCase()); };
})();
