/* github.js — G4.github data layer: cache 10min, escape, README sanitizer. */
(function(){
"use strict";
var G = window.G4;
var U = "https://api.github.com";
var TTL = 10*60*1000;

function cacheGet(k){ var c = G.store.get(k, null);
  if(!c) return null; if(Date.now()-c.t > TTL) return {stale:c.d}; return {fresh:c.d}; }
function cacheSet(k,d){ G.store.set(k,{t:Date.now(), d:d}); }

function req(url){
  return fetch(url, {headers:{"Accept":"application/vnd.github+json"}}).then(function(r){
    if(r.status===403) throw new Error("rate limited or offline");
    if(!r.ok) throw new Error("http "+r.status);
    return r.json();
  });
}

G.github = {
  user: function(){
    var c = cacheGet("g4rr_user");
    if(c && c.fresh) return Promise.resolve(c.fresh);
    return req(U+"/users/"+G.CONFIG.ghUser).then(function(d){
      cacheSet("g4rr_user",d); return d;
    }).catch(function(e){ if(c&&c.stale) return c.stale; throw e; });
  },
  repos: function(){
    var c = cacheGet("g4rr_repos");
    if(c && c.fresh) return Promise.resolve(c.fresh);
    return req(U+"/users/"+G.CONFIG.ghUser+"/repos?per_page=100&sort=updated").then(function(d){
      var list = d.filter(function(r){ return G.CONFIG.excluded.indexOf(r.name)<0; });
      list.sort(function(a,b){ return (b.stargazers_count-a.stargazers_count) ||
        (new Date(b.updated_at)-new Date(a.updated_at)); });
      cacheSet("g4rr_repos",list); return list;
    }).catch(function(e){ if(c&&c.stale) return c.stale; throw e; });
  },
  events: function(){
    var c = cacheGet("g4rr_events");
    if(c && c.fresh) return Promise.resolve(c.fresh);
    return req(U+"/users/"+G.CONFIG.ghUser+"/events/public?per_page=20").then(function(d){
      cacheSet("g4rr_events",d); return d;
    }).catch(function(e){ if(c&&c.stale) return c.stale; throw e; });
  },
  readme: function(repo){
    var c = cacheGet("g4rr_readme_"+repo);
    if(c && c.fresh) return Promise.resolve(c.fresh);
    return req(U+"/repos/"+G.CONFIG.ghUser+"/"+repo+"/readme").then(function(d){
      return fetch(d.download_url).then(function(r){ return r.text(); });
    }).then(function(t){ cacheSet("g4rr_readme_"+repo,t); return t; })
    .catch(function(e){ if(c&&c.stale) return c.stale; throw e; });
  },
  langs: function(repo){
    var c = cacheGet("g4rr_lang_"+repo);
    if(c && c.fresh) return Promise.resolve(c.fresh);
    return req(U+"/repos/"+G.CONFIG.ghUser+"/"+repo+"/languages").then(function(d){
      cacheSet("g4rr_lang_"+repo,d); return d;
    }).catch(function(e){ if(c&&c.stale) return c.stale; throw e; });
  },
  /* README sanitizer: strip dangerous tags, on* attrs, javascript: URLs, srcset;
     force links to target=_blank rel=noopener nofollow. */
  sanitize: function(html){
    var t = document.createElement("template"); t.innerHTML = html;
    var bad = "script,style,iframe,object,embed,form,link,meta,base";
    t.content.querySelectorAll(bad).forEach(function(n){ n.remove(); });
    t.content.querySelectorAll("*").forEach(function(n){
      Array.prototype.slice.call(n.attributes).forEach(function(a){
        var k = a.name.toLowerCase(), v = String(a.value||"");
        if(k.indexOf("on")===0) n.removeAttribute(a.name);
        else if((k==="href"||k==="src"||k==="xlink:href") && /^\s*javascript:/i.test(v)) n.removeAttribute(a.name);
        else if(k==="srcset") n.removeAttribute(a.name);
      });
      if(n.tagName==="A"){ n.setAttribute("target","_blank"); n.setAttribute("rel","noopener nofollow"); }
    });
    return t.innerHTML;
  }
};
})();
