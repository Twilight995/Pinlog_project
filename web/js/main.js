// ── NAV: frosted glass on scroll ──
const nav = document.getElementById('mainNav');
window.addEventListener('scroll', () => {
  nav.classList.toggle('scrolled', window.scrollY > 50);
}, { passive: true });

// ── HERO PARALLAX ──
const heroBg = document.getElementById('heroBg');
window.addEventListener('scroll', () => {
  const y = window.scrollY;
  if (y < window.innerHeight * 1.5)
    heroBg.style.transform = `translateY(${y * 0.25}px)`;
}, { passive: true });

// ── ROUTE PARALLAX ──
const routeBg  = document.getElementById('routeBg');
const routeSec = routeBg?.closest('section');
if (routeSec) {
  window.addEventListener('scroll', () => {
    const r = routeSec.getBoundingClientRect();
    if (r.top < window.innerHeight && r.bottom > 0)
      routeBg.style.transform = `translateY(${(-r.top / window.innerHeight) * 38}px) scale(1.08)`;
  }, { passive: true });
}

// ── SCROLL REVEAL ──
const io = new IntersectionObserver((entries) => {
  entries.forEach(e => {
    if (e.isIntersecting) { e.target.classList.add('visible'); io.unobserve(e.target); }
  });
}, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });
document.querySelectorAll('.reveal, .slide-from-left, .slide-from-right').forEach(el => io.observe(el));

// ── SCROLL PROGRESS BAR ──
const scrollProg = document.getElementById('scrollProgress');
if (scrollProg) {
  window.addEventListener('scroll', () => {
    const pct = window.scrollY / (document.body.scrollHeight - window.innerHeight);
    scrollProg.style.transform = `scaleX(${Math.min(pct, 1)})`;
  }, { passive: true });
}

// ── STICKY PHONE SHOWCASE ──
const sPhoneImg = document.getElementById('sPhoneImg');
const sSlides = document.querySelectorAll('.s-slide');
if (sPhoneImg && sSlides.length) {
  // 모든 이미지 미리 로드
  sSlides.forEach(sl => { const p = new Image(); p.src = sl.dataset.src; });

  let curIdx = -1;

  function switchPhone(src) {
    sPhoneImg.classList.add('exiting');
    const next = new Image();
    next.onload = () => {
      sPhoneImg.src = src;
      sPhoneImg.classList.remove('exiting');
    };
    next.onerror = () => {
      sPhoneImg.src = src;
      sPhoneImg.classList.remove('exiting');
    };
    next.src = src;
    // 안전망: 1.5s 안에 로드 안 되면 강제 전환
    setTimeout(() => {
      if (sPhoneImg.classList.contains('exiting')) {
        sPhoneImg.src = src;
        sPhoneImg.classList.remove('exiting');
      }
    }, 1500);
  }

  function updateShowcase() {
    const mid = window.innerHeight * 0.5;
    let best = 0, bestDist = Infinity;
    sSlides.forEach((sl, i) => {
      const r = sl.getBoundingClientRect();
      const dist = Math.abs((r.top + r.height / 2) - mid);
      if (dist < bestDist) { bestDist = dist; best = i; }
    });
    if (best === curIdx) return;
    curIdx = best;
    sSlides.forEach((sl, i) => sl.classList.toggle('s-active', i === best));
    switchPhone(sSlides[best].dataset.src);
  }

  window.addEventListener('scroll', updateShowcase, { passive: true });
  updateShowcase();
}

// ── HAMBURGER MENU ──
const hamburger  = document.getElementById('navHamburger');
const mobileMenu = document.getElementById('mobileMenu');
const mmLinks    = document.querySelectorAll('.mm-link');

function openMenu() {
  hamburger.classList.add('open');
  mobileMenu.classList.add('open');
  document.body.style.overflow = 'hidden';
}
function closeMenu() {
  hamburger.classList.remove('open');
  mobileMenu.classList.remove('open');
  document.body.style.overflow = '';
}

hamburger.addEventListener('click', () => {
  hamburger.classList.contains('open') ? closeMenu() : openMenu();
});
mmLinks.forEach(link => link.addEventListener('click', closeMenu));
mobileMenu.querySelector('.mm-bg').addEventListener('click', closeMenu);

// ── GALLERY DRAG SCROLL ──
const track = document.getElementById('galleryTrack');
let drag = false, sx = 0, sl = 0;
track.addEventListener('mousedown', e => { drag = true; sx = e.pageX - track.offsetLeft; sl = track.scrollLeft; });
window.addEventListener('mouseup', () => { drag = false; });
track.addEventListener('mousemove', e => {
  if (!drag) return;
  e.preventDefault();
  track.scrollLeft = sl - (e.pageX - track.offsetLeft - sx) * 1.5;
});
