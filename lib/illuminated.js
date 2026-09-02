/* Study Hub — Illuminated design system: scroll reveal
   Reused across every page. Respects prefers-reduced-motion via CSS. */
(function(){
  "use strict";
  function init(){
    var els = document.querySelectorAll('.ilm-reveal');
    if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function(entries){
        entries.forEach(function(e){
          if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
        });
      }, { threshold: 0.15 });
      els.forEach(function(el){ io.observe(el); });
    } else {
      els.forEach(function(el){ el.classList.add('in'); });
    }
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
