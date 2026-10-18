/* transition.js — g4zwr page transition. Real navigations only.
   OUT (~520ms): degauss pulse → scanline tear (feDisplacement 0→80 + horizontal jitter + 1 white flash)
   → canvas takeover: directional phosphor sweep + boot word scramble + branded terminal readout
   → CRT collapse: picture → horizontal line → phosphor dot → black, then navigate.
   IN (~650ms): head script pre-paints black cover; phosphor dot → line → open via clip-path,
   phosphor blocks dissolve (staggered), displacement 80→0, h1 per-letter glitch-in, header jitter,
   tape-stop audio ramps. Prefetch on hover/focus/touchstart. bfcache pageshow reset.
   Reduced/OFF: 150ms crossfade. LITE: blocks only, no displacement. */
(function() {
  "use strict";
  var G = window.G4;
  var ORDER = ["/", "/projects/", "/project/", "/stack/", "/about/", "/contact/"];
  var WORDS = {
    "/": "BOOT",
    "/projects/": "INDEXING REPOS",
    "/project/": "FETCHING BUILD",
    "/stack/": "LOADING TOOLBOX",
    "/about/": "DECRYPTING BIO",
    "/contact/": "OPENING CHANNELS"
  };
  var TERM_LINES = {
    "/": ["> INIT SEQUENCE", "> VERIFYING SIGNATURE", "> SIGNAL LOCK"],
    "/projects/": ["> SCANNING MANIFEST", "> RESOLVING DEPENDENCIES", "> REPOS INDEXED"],
    "/project/": ["> QUERYING REGISTRY", "> STREAMING ARTIFACTS", "> BUILD READY"],
    "/stack/": ["> ENUMERATING TOOLCHAIN", "> VALIDATING VERSIONS", "> DOSSIER LOADED"],
    "/about/": ["> ACCESSING ARCHIVE", "> DECRYPTING RECORDS", "> BIO SYNCED"],
    "/contact/": ["> HANDSHAKE INITIATED", "> VERIFYING ENDPOINTS", "> CHANNELS OPEN"]
  };

  function routeOf(p) {
    if (p.indexOf("/project") === 0 && p !== "/projects/") return "/project/";
    for (var i = 0; i < ORDER.length; i++) if (p === ORDER[i] || p === ORDER[i] + "index.html") return ORDER[i];
    return p;
  }

  G.initTransition = function() {
    // bfcache: reset overlay + filter state
    addEventListener("pageshow", function(e) {
      if (e.persisted) { resetOverlays(); try { G.audio.tapeIn(); } catch (_) {} }
    });
    // prefetch on hover/focus/touchstart
    ["mouseover", "focusin", "touchstart"].forEach(function(ev) {
      document.addEventListener(ev, function(e) {
        var a = e.target.closest && e.target.closest("a[href]");
        if (!a) return;
        var href = a.getAttribute("href");
        if (!shouldTake(href, a)) return;
        var u = new URL(href, location.href);
        if (!document.querySelector('link[rel="prefetch"][href="' + u.pathname + '"]')) {
          var l = document.createElement("link"); l.rel = "prefetch"; l.href = u.pathname; document.head.appendChild(l);
        }
      }, { passive: true });
    });
    // intercept same-origin clicks
    document.addEventListener("click", function(e) {
      var a = e.target.closest && e.target.closest("a[href]");
      if (!a) return;
      var href = a.getAttribute("href");
      if (!shouldTake(href, a)) return;
      if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return; // modified clicks
      e.preventDefault();
      go(new URL(href, location.href).pathname + new URL(href, location.href).search);
    });
    // IN sequence on every page
    playIn();
  };

  function shouldTake(href, a) {
    if (!href || href[0] === "#" || href.indexOf("mailto:") === 0 || href.indexOf("http") === 0 && new URL(href, location.href).origin !== location.origin) return false;
    if (a.target || a.hasAttribute("download")) return false;
    try {
      var u = new URL(href, location.href);
      if (u.origin !== location.origin) return false;
      if (u.pathname === location.pathname && u.search === location.search && u.hash) return false; // hash-only
      return true;
    } catch (e) { return false; }
  }

  function dirOf(from, to) {
    var a = ORDER.indexOf(routeOf(from)), b = ORDER.indexOf(routeOf(to.split("?")[0]));
    if (a < 0 || b < 0) return 1; return b >= a ? 1 : -1;
  }

  /* SVG displacement filter lives ONLY during transition (perf). */
  function ensureFilter() {
    var s = document.getElementById("g4disp");
    if (s) return s;
    var NS = "http://www.w3.org/2000/svg";
    s = document.createElementNS(NS, "svg");
    s.id = "g4disp"; s.setAttribute("width", "0"); s.setAttribute("height", "0");
    s.style.position = "absolute";
    s.innerHTML = '<filter id="g4f" x="-20%" y="-20%" width="140%" height="140%">' +
      '<feTurbulence id="g4turb" type="fractalNoise" baseFrequency="0.008" numOctaves="3" result="n"/>' +
      '<feDisplacementMap id="g4dispm" in="SourceGraphic" in2="n" scale="0" xChannelSelector="R" yChannelSelector="G"/></filter>';
    document.body.appendChild(s); return s;
  }
  function setDisp(scale, freq) {
    var t = document.getElementById("g4turb"), d = document.getElementById("g4dispm");
    if (t) t.setAttribute("baseFrequency", String(freq));
    if (d) d.setAttribute("scale", String(scale));
  }
  function resetOverlays() {
    document.documentElement.classList.remove("g4-in");
    var c = document.getElementById("fxTrans"); if (c) { c.style.display = "none"; }
    var b = document.getElementById("transBoot"); if (b) { b.style.display = "none"; }
    var w = document.getElementById("pagewrap"); if (w) { w.style.filter = ""; w.style.transform = ""; }
    var s = document.getElementById("g4disp"); if (s) s.remove();
    try { sessionStorage.removeItem("g4_trans"); } catch (e) {}
  }

  function go(href) {
    if (document.documentElement.classList.contains("g4-out")) return;
    var lite = G.fxLite(), off = G.fxOff();
    // FAKE TRANSITION: play visual effect but DON'T navigate
    // Audio continues playing normally (no tapeOut/tapeIn)
    if (off) { // 150ms crossfade through black
      document.body.style.transition = "opacity .15s"; document.body.style.opacity = "0";
      setTimeout(function() { document.body.style.opacity = "1"; }, 160); return;
    }
    document.documentElement.classList.add("g4-out");
    var to = href.split("?")[0];
    var word = WORDS[routeOf(to)] || "LOAD", dir = dirOf(location.pathname, href);
    // Store transition info for playIn
    try { sessionStorage.setItem("g4_trans", JSON.stringify({ to: href, dir: dir, word: word, fake: true })); } catch (e) {}
    var wrap = document.getElementById("pagewrap");
    var t0 = performance.now();
    if (!lite) { ensureFilter(); if (wrap) wrap.style.filter = "url(#g4f)"; }

    // Phase 0: Degauss pulse (0-80ms) — full-screen horizontal shudder + displacement spike
    var degauss = setInterval(function() {
      var e = performance.now() - t0;
      if (e > 80) { clearInterval(degauss); return; }
      if (wrap) wrap.style.transform = "translateX(" + ((Math.random() * 16 - 8) | 0) + "px) skewX(" + (Math.random() * 0.04 - 0.02) + "rad)";
      if (!lite) setDisp(80 * (e / 80), 0.008 + 0.12 * (e / 80));
    }, 10);
    setTimeout(function() { G.flash(); }, 20);

    // Phase 1: Scanline tear (80-180ms) — horizontal bands tear apart with displacement
    var tear = setInterval(function() {
      var e = performance.now() - t0;
      if (e > 180) { clearInterval(tear); return; }
      var p = (e - 80) / 100;
      if (wrap) wrap.style.transform = "translateX(" + ((Math.random() * 12 - 6) | 0) + "px)";
      if (!lite) setDisp(80 * (1 - p * 0.3), 0.008 + 0.08 * p);
    }, 12);

    // Phase 2: Phosphor sweep + boot word + terminal (180-420ms)
    setTimeout(function() { clearInterval(tear); blocks(dir, word, href, to); }, 185);

    // Phase 3: CRT collapse (420-520ms) → reset overlays, stay on page
    setTimeout(function() { collapse(dir, href); }, 425);
  }

  function blocks(dir, word, href, to) {
    var c = document.getElementById("fxTrans"), b = document.getElementById("transBoot");
    c.style.display = "block"; b.style.display = "flex";
    var ctx = c.getContext("2d"); c.width = innerWidth; c.height = innerHeight;
    b.querySelector(".bw").textContent = word;
    G.scramble(b.querySelector(".bw"), word, 240);

    var term = b.querySelector(".term"), fill = document.getElementById("transBarFill");
    var lines = TERM_LINES[routeOf(to)] || ["> NAVIGATING " + href, "> LOADING ASSETS ...", "> SIGNAL LOCK"];
    term.innerHTML = lines[0] + "<br>" + lines[1] + '<span id="pc">0%</span><br>';
    var t0 = performance.now(), DUR = 235;

    // Precompute scanline positions for deterministic sweep
    var scanlines = [];
    var count = 120;
    for (var i = 0; i < count; i++) {
      scanlines.push({
        y: (i / count) * c.height,
        thickness: 1 + (Math.random() * 3 | 0),
        offset: (Math.random() - 0.5) * 40,
        speed: 0.8 + Math.random() * 0.4,
        type: i % 4 // 0=scanline, 1=phosphor block, 2=glitch strip, 3=noise row
      });
    }

    (function fr() {
      var p = Math.min(1, (performance.now() - t0) / DUR);
      var eased = p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2; // easeInOutQuad

      ctx.fillStyle = "#000"; ctx.fillRect(0, 0, c.width, c.height);

      // Directional sweep coverage
      var sweep = eased;
      var sweepDir = dir > 0 ? 1 : -1;

      for (var i = 0; i < count; i++) {
        var sl = scanlines[i];
        var norm = i / count;
        var active = sweepDir > 0 ? norm < sweep * 1.15 : (1 - norm) < sweep * 1.15;
        if (!active) continue;

        var xoff = sl.offset * eased * sweepDir;
        var alpha = 1 - (1 - eased) * 0.3;

        switch (sl.type) {
          case 0: // Scanline — thin horizontal phosphor line
            ctx.fillStyle = "rgba(255,255,255," + (0.6 + 0.4 * Math.random()) + ")";
            ctx.fillRect(0, sl.y + xoff, c.width, sl.thickness);
            break;
          case 1: // Phosphor block — chunky rect with scanline texture
            ctx.fillStyle = Math.random() < 0.5 ? "#fff" : "#000";
            var bw = 60 + Math.random() * 200;
            var bx = (Math.random() * (c.width - bw)) + xoff;
            ctx.fillRect(bx, sl.y, bw, 8 + Math.random() * 24);
            // Internal scanlines
            ctx.fillStyle = "rgba(255,255,255,0.15)";
            for (var s = 0; s < 4; s++) {
              ctx.fillRect(bx, sl.y + 2 + s * 6, bw, 1);
            }
            break;
          case 2: // Glitch strip — displaced horizontal band
            ctx.fillStyle = "rgba(255,255,255," + (0.3 + 0.3 * Math.random()) + ")";
            var dx = (Math.random() * 120 - 60) * eased * sweepDir;
            ctx.fillRect(dx, sl.y, c.width, 2 + Math.random() * 4);
            break;
          case 3: // Noise row — sparse phosphor dots
            ctx.fillStyle = "#fff";
            for (var k = 0; k < 16; k++) {
              if (Math.random() < 0.4) ctx.fillRect(Math.random() * c.width, sl.y + Math.random() * 6, 2, 2);
            }
            break;
        }
      }

      // Progress bar + terminal percentage
      var pc = document.getElementById("pc"); if (pc) pc.textContent = Math.floor(eased * 100) + "%";
      if (fill) fill.style.width = (eased * 100) + "%";

      // Terminal line progression
      if (eased > 0.33 && !term.dataset.l1) { term.dataset.l1 = 1; term.innerHTML = lines[0] + "<br>" + lines[1] + Math.floor(eased * 100) + "%<br>"; }
      if (eased > 0.66 && !term.dataset.l2) { term.dataset.l2 = 1; term.innerHTML = lines[0] + "<br>" + lines[1] + "100%<br>" + lines[2]; }

      if (p < 1) requestAnimationFrame(fr);
      else { term.innerHTML = lines[0] + "<br>" + lines[1] + "100%<br>" + lines[2]; }
    })();
  }

  function collapse(dir, href) {
    var c = document.getElementById("fxTrans"), b = document.getElementById("transBoot");
    // CRT collapse: picture → horizontal line → phosphor dot → black
    var t0 = performance.now(), DUR = 180;
    (function fr() {
      var p = Math.min(1, (performance.now() - t0) / DUR);
      var eased = p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2;

      // Vertical collapse (picture → line)
      var scaleY = 1 - eased * 0.985;
      // Horizontal collapse (line → dot) starts at 60%
      var scaleX = 1 - Math.max(0, eased - 0.6) * 2.5 * 0.95;

      c.style.transform = "scaleX(" + scaleX + ") scaleY(" + scaleY + ")";
      c.style.transformOrigin = "center";
      c.style.filter = "brightness(" + (1 + (1 - eased) * 2) + ") contrast(" + (1 + (1 - eased) * 3) + ")";

      if (p < 1) requestAnimationFrame(fr);
      else { b.style.display = "none"; resetOverlays(); afterIn(true); }
    })();
  }

  function playIn() {
    var raw = null; try { raw = sessionStorage.getItem("g4_trans"); } catch (e) {}
    var info = null; try { info = raw ? JSON.parse(raw) : null; } catch (e) {}
    // Failsafe: never trap user behind cover
    setTimeout(resetOverlays, 1500);
    // Audio continues normally (no tapeIn for fake transitions)
    if (!info || info.fake) { resetOverlays(); afterIn(false); return; }
    if (G.fxOff()) { // crossfade only
      document.body.style.opacity = "0"; document.body.style.transition = "opacity .15s";
      requestAnimationFrame(function() { document.body.style.opacity = "1"; });
      resetOverlays(); afterIn(true); return;
    }
    var lite = G.fxLite();
    var c = document.getElementById("fxTrans");
    c.style.display = "block"; c.style.transform = "";
    var ctx = c.getContext("2d"); c.width = innerWidth; c.height = innerHeight;
    var wrap = document.getElementById("pagewrap");
    if (!lite) { ensureFilter(); if (wrap) wrap.style.filter = "url(#g4f)"; setDisp(80, 0.08); }

    // 1. Phosphor dot → line → open via clip-path inset + 1-frame brightness pop (degauss)
    var t0 = performance.now();
    document.body.style.clipPath = "inset(49.5% 49.5% 49.5% 49.5%)";
    document.body.style.filter = "brightness(4) contrast(2)";
    setTimeout(function() { document.body.style.filter = ""; }, 30);
    var OPEN = 320;

    // Precompute dissolve blocks for IN
    var dissolveBlocks = [];
    var dCount = 80;
    for (var i = 0; i < dCount; i++) {
      dissolveBlocks.push({
        x: Math.random() * c.width,
        y: Math.random() * c.height,
        w: 40 + Math.random() * 180,
        h: 6 + Math.random() * 32,
        delay: Math.random() * 0.6,
        color: Math.random() < 0.5 ? "#fff" : "#000"
      });
    }

    (function fr() {
      var p = Math.min(1, (performance.now() - t0) / OPEN);
      var eased = p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2;
      var m = 49.5 * (1 - eased);
      document.body.style.clipPath = "inset(" + m + "% " + m + "% " + m + "% " + m + "%)";

      // 2. Phosphor blocks dissolve in staggered random positions; displacement 80→0
      ctx.fillStyle = "#000"; ctx.clearRect(0, 0, c.width, c.height);
      for (var i = 0; i < dCount; i++) {
        var db = dissolveBlocks[i];
        if (eased < db.delay) continue; // not yet dissolved
        var localP = (eased - db.delay) / (1 - db.delay);
        if (localP > 1) continue; // fully dissolved
        ctx.fillStyle = db.color;
        ctx.globalAlpha = 1 - localP;
        ctx.fillRect(db.x, db.y, db.w, db.h);
        ctx.globalAlpha = 1;
      }

      if (!lite && wrap) setDisp(80 * (1 - eased), 0.08 * (1 - eased) + 0.004);

      if (p < 1) requestAnimationFrame(fr);
      else {
        document.body.style.clipPath = ""; c.style.display = "none";
        if (wrap) { wrap.style.filter = ""; wrap.style.transform = ""; }
        var s = document.getElementById("g4disp"); if (s) s.remove();
        resetOverlays(); afterIn(true);
      }
    })();
  }

  function afterIn(transitioned) {
    // 3. h1 + section headings per-letter glitch-in, header jitter, focus main
    var h1 = document.querySelector("main h1");
    if (h1 && transitioned) G.scramble(h1, h1.textContent, 450);
    var hud = document.getElementById("hud");
    if (hud && transitioned && !G.fxOff()) {
      hud.style.transform = "translateX(4px)";
      setTimeout(function() { hud.style.transform = "translateX(-3px)";
        setTimeout(function() { hud.style.transform = ""; }, 60); }, 60);
    }
    var main = document.querySelector("main");
    if (main) { main.setAttribute("tabindex", "-1"); main.focus({ preventScroll: true }); }
    var live = document.getElementById("ariaLive");
    if (live && h1) live.textContent = document.title;
  }
})();