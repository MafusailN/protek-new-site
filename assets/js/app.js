/* ============================================================
   ПРОТЭК — интерфейс
   Данные приходят из assets/js/data.js (генерируется tools\build-data.ps1
   из реальной выгрузки pro-tek.pro): CITIES, MENU, PRODUCTS, CATEGORIES, PMAP
   ============================================================ */

/* ---------- интерфейсные иконки ---------- */
const ICONS = {
  search:  '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
  cart:    '<path d="M3 4h2l2.4 11.3a2 2 0 0 0 2 1.7h7.4a2 2 0 0 0 2-1.6L20.5 8H6"/><circle cx="10" cy="20" r="1.4"/><circle cx="17" cy="20" r="1.4"/>',
  heart:   '<path d="M12 20s-7-4.4-7-9.3A4.2 4.2 0 0 1 12 8a4.2 4.2 0 0 1 7 2.7C19 15.6 12 20 12 20z"/>',
  user:    '<circle cx="12" cy="8" r="4"/><path d="M4 20c1.2-4 4.3-6 8-6s6.8 2 8 6"/>',
  compare: '<path d="M5 20V8M12 20V4M19 20v-8"/>',
  phone:   '<path d="M5 3h4l2 5-2.5 1.5a12 12 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2.2 2A17 17 0 0 1 3 5.2 2 2 0 0 1 5 3z"/>',
  pin:     '<path d="M12 21s7-5.6 7-11a7 7 0 1 0-14 0c0 5.4 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>',
  chevron: '<path d="M9 5l7 7-7 7"/>',
  down:    '<path d="M5 9l7 7 7-7"/>',
  arrow:   '<path d="M4 12h15M13 6l6 6-6 6"/>',
  check:   '<path d="M4 12.5l5 5L20 6.5"/>',
  close:   '<path d="M6 6l12 12M18 6L6 18"/>',
  clock:   '<circle cx="12" cy="12" r="9"/><path d="M12 7v5.5l3.5 2"/>',
  truck:   '<path d="M3 7h11v9H3z"/><path d="M14 10h4l3 3v3h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="17.5" cy="18" r="2"/>',
  box:     '<path d="M12 3l8 4.2v9.6L12 21l-8-4.2V7.2z"/><path d="M4 7.2L12 11.5l8-4.3M12 11.5V21"/>',
  cert:    '<path d="M12 3l2.4 4.9 5.4.8-3.9 3.8.9 5.4-4.8-2.5-4.8 2.5.9-5.4L4.2 8.7l5.4-.8z"/>',
  headset: '<path d="M4 13v-1a8 8 0 0 1 16 0v1"/><rect x="2.5" y="13" width="4" height="6" rx="1.6"/><rect x="17.5" y="13" width="4" height="6" rx="1.6"/><path d="M19.5 19a3 3 0 0 1-3 3H13"/>',
  wallet:  '<rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10h18"/><circle cx="17" cy="14" r="1.3"/>',
  grid:    '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  filter:  '<path d="M3 5h18l-7 8v6l-4 2v-8z"/>',
  ruler:   '<rect x="2" y="8" width="20" height="8" rx="1.5"/><path d="M7 8v3M11 8v4M15 8v3M19 8v4"/>',
  cube:    '<path d="M12 3l8 4.2v9.6L12 21l-8-4.2V7.2z"/><path d="M4 7.2L12 11.5l8-4.3M12 11.5V21"/>',
  play:    '<circle cx="12" cy="12" r="9"/><path d="M10 8.5l6 3.5-6 3.5z"/>',
  wrench:  '<path d="M15.5 3.5a5 5 0 0 0-6.2 6.6L3 16.4 5.6 19l6.3-6.3a5 5 0 0 0 6.6-6.2l-3 3-2.3-2.3z"/>',
  blueprint: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 8h6M7 12h10M7 16h4"/>',
  network: '<rect x="3" y="14" width="18" height="6" rx="1.5"/><path d="M7 14v-3h10v3M12 11V4"/><circle cx="12" cy="17" r="1"/>',
  vk:      '<path d="M3 8h3c.5 4 2.5 6 4 6V8h3v4c1.5-.3 3-2 3.5-4H20c-.6 2.6-2 4.3-3.2 5 1.2.6 2.8 2.1 3.4 4h-3.3c-.5-1.5-1.9-2.7-3.4-3v3h-.6C7.5 17 4 13 3 8z"/>',
  tg:      '<path d="M21 5L3 11.5l5 1.8L18 8l-7.5 7.2.4 4.3 2.9-3.1 4.3 3.1z"/>',
  yt:      '<rect x="2" y="5" width="20" height="14" rx="4"/><path d="M10 9l6 3-6 3z"/>'
};
const icon = (n, cls = 'icon') => `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[n] || ICONS.box}</svg>`;

/* ---------- утилиты ---------- */
const money = n => Number(n).toLocaleString('ru-RU') + ' ₽';
const priceText = p => (p.p != null && p.p > 0) ? money(p.p) : (p.pt || 'Цена по запросу');
const hasPrice = p => p.p != null && p.p > 0;
const catIcon = url => url ? 'assets/img/cat/' + url.split('/').pop() : '';
const plural = (n, a, b, c) => { const m = n % 100, d = n % 10; return m > 10 && m < 20 ? c : d === 1 ? a : d > 1 && d < 5 ? b : c; };

/* наличие: p.s — массив 0/1 по CITIES */
const stockCount = p => (p.s || []).reduce((a, b) => a + b, 0);
const stockCities = p => CITIES.filter((c, i) => p.s && p.s[i]);

function stockHtml(p) {
  const n = stockCount(p);
  if (!n) return `<div class="stock out"><i></i>Под заказ</div>`;
  const list = stockCities(p);
  const shown = list.slice(0, 2).join(', ');
  const rest = list.length > 2 ? ` +${list.length - 2}` : '';
  return `<div class="stock" title="В наличии: ${list.join(', ')}"><i></i>В наличии: ${shown}${rest}</div>`;
}

/* ============================================================
   ХАРАКТЕРИСТИКИ
   На pro-tek.pro таблица параметров заполнена лишь у части товаров.
   Недостающее извлекаем из самого наименования — это разбор данных,
   которые уже есть в названии, а не догадка. Источник помечается,
   чтобы параметр можно было проверить.
   ============================================================ */
const SPEC_RULES = [
  [/(\d+(?:[.,]\d+)?)\s*Мп/i,                    'Разрешение',            m => m[1].replace(',', '.') + ' Мп'],
  [/(\d+)\s*-?\s*канальн/i,                      'Количество каналов',    m => m[1]],
  [/[\/\s](\d+(?:[.,]\d+)?)\s*mm[\/\s]/i,        'Фокусное расстояние',   m => m[1].replace(',', '.') + ' мм'],
  [/(\d+(?:[.,]\d+)?)\s*мм\b(?!\s*[хx])/i,       'Фокусное расстояние',   m => m[1].replace(',', '.') + ' мм'],
  [/\bIP\s?(\d{2})\b/,                           'Степень защиты',        m => 'IP' + m[1]],
  [/(\d+(?:[.,]\d+)?)\s*Т[Бб]\b/i,               'Объём накопителя',      m => m[1].replace(',', '.') + ' ТБ'],
  [/(\d+(?:[.,]\d+)?)\s*Г[Бб]\b/i,               'Объём накопителя',      m => m[1].replace(',', '.') + ' ГБ'],
  [/(\d+(?:[.,]\d+)?)\s*А[·*]?ч\b/i,             'Ёмкость',               m => m[1].replace(',', '.') + ' А·ч'],
  [/(\d+(?:[.,]\d+)?)\s*В\b(?!т)/,               'Напряжение',            m => m[1].replace(',', '.') + ' В'],
  [/(\d+(?:[.,]\d+)?)\s*Вт\b/i,                  'Мощность',              m => m[1].replace(',', '.') + ' Вт'],
  [/(\d+(?:[.,]\d+)?)\s*[АA]\b/,                 'Ток',                   m => m[1].replace(',', '.') + ' А'],
  [/(куполь\w*)/i,                               'Форм-фактор',           () => 'Купольная'],
  [/(цилиндрическ\w*)/i,                         'Форм-фактор',           () => 'Цилиндрическая'],
  [/(поворотн\w*|PTZ)/i,                         'Форм-фактор',           () => 'Поворотная'],
  [/(уличн\w*)/i,                                'Исполнение',            () => 'Уличное'],
  [/(внутренн\w*)/i,                             'Исполнение',            () => 'Внутреннее'],
  [/(антивандальн\w*)/i,                         'Исполнение',            () => 'Антивандальное'],
  [/\bIP-?камера\b/i,                            'Тип',                   () => 'IP'],
  [/\b(AHD|HD-?TVI|HD-?CVI|CVBS)\b/i,            'Тип сигнала',           m => m[1].toUpperCase()],
  [/\bPoE\b/i,                                   'PoE',                   () => 'Есть'],
  [/(\d+(?:[.,]\d+)?)\s*м\b(?!м|п)/,             'Длина',                 m => m[1].replace(',', '.') + ' м'],
  [/\b(\d+[хx]\d+(?:[.,]\d+)?)\b/,               'Размер / сечение',      m => m[1].replace('x', '×').replace('х', '×')],
  [/\b(бел\w+|чёрн\w+|черн\w+|сер\w+|красн\w+)\b/i, 'Цвет',               m => m[1].toLowerCase()]
];

function deriveSpecs(p) {
  const src = p.n || '';
  const out = [], used = new Set();
  for (const [re, label, fmt] of SPEC_RULES) {
    if (used.has(label)) continue;
    const m = src.match(re);
    if (m) { used.add(label); out.push([label, fmt(m), 'из наименования']); }
  }
  return out;
}

/* плашки товара — как они стоят на pro-tek.pro */
function tagsOf(p) {
  if (!p.tg || !p.tg.length) return '';
  return p.tg.map(t => `<span class="ptag ptag-${t.k}">${t.t}</span>`).join('');
}

/* полный набор: сначала данные из каталога, затем добранные из названия */
function allSpecsOf(p) {
  const site = (p.sp || []).map(s => [s[0], s[1], 'каталог Протэк']);
  const vend = (p.vsp || []).map(s => [s[0], s[1], 'сайт ' + p.b]);
  const out = site.slice();
  const have = new Set(out.map(s => s[0].toLowerCase()));
  for (const v of vend) { if (!have.has(v[0].toLowerCase())) { have.add(v[0].toLowerCase()); out.push(v); } }
  for (const d of deriveSpecs(p)) { if (!have.has(d[0].toLowerCase())) { have.add(d[0].toLowerCase()); out.push(d); } }
  return out;
}

/* Кадры товара. p.big и p.img — один и тот же снимок в разных размерах,
   поэтому берём только крупный; отдельными кадрами считаем лишь
   догруженные у производителя. */
function shotsOf(p) {
  const out = [];
  if (p.big) out.push(p.big);
  else if (p.img) out.push(p.img);
  (p.vimg || []).forEach(v => { if (!out.includes(v)) out.push(v); });
  return out;
}

/* ---------- состояние ---------- */
const store = {
  get cart() { try { return JSON.parse(localStorage.getItem('ptk_cart') || '{}'); } catch { return {}; } },
  set cart(v) { localStorage.setItem('ptk_cart', JSON.stringify(v)); },
  get fav() { try { return JSON.parse(localStorage.getItem('ptk_fav') || '[]'); } catch { return []; } },
  set fav(v) { localStorage.setItem('ptk_fav', JSON.stringify(v)); },
  get city() { return localStorage.getItem('ptk_city') || CITIES[0]; },
  set city(v) { localStorage.setItem('ptk_city', v); }
};

function toast(msg, ic = 'check') {
  let el = document.querySelector('.toast');
  if (!el) { el = document.createElement('div'); el.className = 'toast'; document.body.appendChild(el); }
  el.innerHTML = icon(ic, 'icon icon-sm') + '<span>' + msg + '</span>';
  el.classList.add('show');
  clearTimeout(el._t);
  el._t = setTimeout(() => el.classList.remove('show'), 2400);
}

/* ============================================================
   ШАПКА
   ============================================================ */
function renderHeader() {
  const host = document.getElementById('site-header');
  if (!host) return;

  const menuHtml = (typeof MENU !== 'undefined' ? MENU : [])
    .filter(m => m.url !== '/catalog/')
    .map(m => `<div class="tm-item">
        <a href="${pageFor(m.url)}">${m.name}</a>
        ${m.sub && m.sub.length ? `<div class="tm-drop">${m.sub.map(s => `<a href="${pageFor(s.url)}">${s.name}</a>`).join('')}</div>` : ''}
      </div>`).join('');

  host.innerHTML = `
  <div class="topbar">
    <div class="wrap">
      <button class="city" id="city-btn">${icon('pin', 'icon icon-sm')}<span id="city-name">${store.city}</span>${icon('down', 'icon icon-sm')}</button>
      <nav class="topmenu">${menuHtml}</nav>
      <span class="spacer"></span>
      <button id="theme-btn" class="tb-link">Тёмная тема</button>
      <a class="tb-phone" href="tel:+73833835014">+7 (383) 383-50-14</a>
    </div>
  </div>

  <header class="header">
    <div class="wrap header-main">
      <a href="index.html" class="logo"><img src="assets/img/logo.png" alt="ПРОТЭК" height="38"></a>
      <button class="btn-catalog" id="cat-btn"><span class="bars"><i></i><i></i><i></i></span><span>Каталог</span></button>
      <div class="search">
        <form class="search-box" id="search-form" autocomplete="off">
          ${icon('search')}
          <input type="text" id="search-input" placeholder="Поиск по каталогу: модель, бренд, артикул">
          <button class="search-go" type="submit">${icon('search', 'icon icon-sm')}<span>Найти</span></button>
        </form>
        <div class="suggest" id="suggest"></div>
      </div>
      <nav class="head-actions">
        <a class="hact" href="catalog.html?fav=1" id="fav-act">${icon('heart')}<span>Избранное</span><i class="badge hide"></i></a>
        <button class="hact" id="cart-btn">${icon('cart')}<span>Корзина</span><i class="badge hide"></i></button>
        <a class="hact" href="contacts.html">${icon('user')}<span>Кабинет</span></a>
      </nav>
    </div>
    <div class="mega" id="mega">
      <div class="wrap mega-inner">
        <div class="mega-list" id="mega-list"></div>
        <div class="mega-panel" id="mega-panel"></div>
      </div>
    </div>
  </header>
  <div class="scrim" id="scrim"></div>`;

  /* мега-меню каталога */
  const list = host.querySelector('#mega-list');
  const panel = host.querySelector('#mega-panel');
  list.innerHTML = CATEGORIES.map((c, i) => `
    <button data-i="${i}" class="${i === 0 ? 'active' : ''}">
      ${c.icon ? `<img class="cat-ic" src="${catIcon(c.icon)}" alt="" loading="lazy">` : icon('grid')}
      <span>${c.name}</span>${icon('chevron', 'icon icon-sm arr')}
    </button>`).join('');

  const isMobileMenu = () => window.matchMedia('(max-width: 860px)').matches;

  const paint = i => {
    const c = CATEGORIES[i];
    panel.innerHTML = `
      <button class="mega-back" type="button">${icon('chevron', 'icon icon-sm')} Все разделы</button>
      <div class="mega-head">
        <a href="catalog.html?cat=${c.id}"><h3>${c.name}</h3></a>
        <span class="muted">${c.sub.length} ${plural(c.sub.length, 'подраздел', 'подраздела', 'подразделов')}</span>
      </div>
      <div class="mega-cols">
        ${c.sub.map(s => `<a class="mega-sub" href="catalog.html?cat=${c.id}&sub=${s.id}">${s.name}</a>`).join('')}
      </div>
      <div class="mega-foot"><a class="btn btn-primary btn-sm" href="catalog.html?cat=${c.id}">Все товары раздела ${icon('arrow', 'icon icon-sm')}</a></div>`;
    list.querySelectorAll('button').forEach(b => b.classList.toggle('active', +b.dataset.i === i));
    const back = panel.querySelector('.mega-back');
    if (back) back.addEventListener('click', () => mega.classList.remove('drill'));
  };
  /* по умолчанию показываем первый раздел, у которого есть подразделы:
     иначе панель открывается пустой */
  const firstWithSub = CATEGORIES.findIndex(c => c.sub.length);
  paint(firstWithSub > -1 ? firstWithSub : 0);

  list.querySelectorAll('button').forEach(b => {
    b.addEventListener('mouseenter', () => { if (!isMobileMenu()) paint(+b.dataset.i); });
    b.addEventListener('click', () => {
      const i = +b.dataset.i;
      /* на телефоне первое касание раскрывает подразделы, а не уводит со страницы */
      if (isMobileMenu()) { paint(i); mega.classList.add('drill'); mega.scrollTop = 0; }
      else location.href = 'catalog.html?cat=' + CATEGORIES[i].id;
    });
  });

  const mega = host.querySelector('#mega'), scrim = host.querySelector('#scrim'), catBtn = host.querySelector('#cat-btn');
  const setMega = on => {
    mega.classList.toggle('open', on);
    if (!on) mega.classList.remove('drill');
    /* пока открыто меню на телефоне — страница под ним не прокручивается */
    document.body.classList.toggle('menu-open', on && isMobileMenu());
    scrim.classList.toggle('show', on);
    catBtn.classList.toggle('open', on);
  };
  const closeMega = () => setMega(false);

  /* открытие по наведению — с задержкой на закрытие, чтобы меню
     не захлопывалось, когда курсор идёт от кнопки к панели */
  let hoverTimer = null;
  const cancelClose = () => { if (hoverTimer) { clearTimeout(hoverTimer); hoverTimer = null; } };
  const scheduleClose = () => { cancelClose(); hoverTimer = setTimeout(closeMega, 220); };
  const hoverOpen = () => { cancelClose(); setMega(true); };

  [catBtn, mega].forEach(el => {
    el.addEventListener('mouseenter', hoverOpen);
    el.addEventListener('mouseleave', scheduleClose);
  });

  /* клик оставляем — он удобен на сенсорных экранах */
  catBtn.addEventListener('click', e => {
    e.stopPropagation();
    cancelClose();
    setMega(!mega.classList.contains('open'));
  });

  scrim.addEventListener('click', closeMega);
  scrim.addEventListener('mouseenter', scheduleClose);
  document.addEventListener('keydown', e => { if (e.key === 'Escape') { cancelClose(); closeMega(); } });

  /* тема */
  const themeBtn = host.querySelector('#theme-btn');
  const applyTheme = t => {
    document.documentElement.dataset.theme = t;
    localStorage.setItem('ptk_theme', t);
    themeBtn.textContent = t === 'dark' ? 'Светлая тема' : 'Тёмная тема';
  };
  applyTheme(localStorage.getItem('ptk_theme') || 'light');
  themeBtn.addEventListener('click', () => applyTheme(document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'));

  /* выбор города */
  host.querySelector('#city-btn').addEventListener('click', e => {
    e.stopPropagation();
    let m = document.getElementById('city-menu');
    if (m) { m.remove(); return; }
    m = document.createElement('div');
    m.id = 'city-menu'; m.className = 'city-menu';
    m.innerHTML = CITIES.map(c => `<button data-city="${c}" class="${c === store.city ? 'on' : ''}">${c}</button>`).join('');
    e.currentTarget.after(m);
    m.addEventListener('click', ev => {
      const b = ev.target.closest('[data-city]'); if (!b) return;
      store.city = b.dataset.city;
      document.getElementById('city-name').textContent = store.city;
      m.remove();
      toast('Город: ' + store.city + '. Наличие показано для складов компании.', 'pin');
      if (window.PAGE_REFRESH) window.PAGE_REFRESH();
    });
  });
  document.addEventListener('click', () => { const m = document.getElementById('city-menu'); if (m) m.remove(); });

  /* подсказка в поиске подстраивается под ширину: длинная строка
     на телефоне обрезается и выглядит как ошибка */
  const searchInput = host.querySelector('#search-input');
  const fitPlaceholder = () => {
    const w = window.innerWidth;
    searchInput.placeholder = w < 420 ? 'Поиск по каталогу'
      : w < 860 ? 'Модель, бренд или артикул'
      : 'Поиск по каталогу: модель, бренд, артикул';
  };
  fitPlaceholder();

  /* реальная высота шапки — от неё отсчитывается меню на телефоне */
  const headerEl = host.querySelector('.header');
  const syncHeaderHeight = () => document.documentElement.style
    .setProperty('--header-real', headerEl.offsetHeight + 'px');
  syncHeaderHeight();

  window.addEventListener('resize', () => { fitPlaceholder(); syncHeaderHeight(); });

  initSearch();
  host.querySelector('#cart-btn').addEventListener('click', () => openCart(true));
  syncBadges();
}

/* внутренние страницы, которых нет в макете, ведут на исходные разделы */
function pageFor(url) {
  if (!url) return '#';
  if (/^https?:\/\//i.test(url)) return url;          // внешние сервисы — как есть
  const map = {
    '/company/': 'company.html', '/delivery/': 'delivery.html', '/contacts/': 'contacts.html',
    '/support/': 'support.html', '/catalog/brends/': 'brands.html', '/catalog/': 'catalog.html'
  };
  return map[url] || ('https://pro-tek.pro' + url);   // остальные разделы — на действующий сайт
}
const isExternal = u => /^https?:\/\//i.test(pageFor(u));

/* ---------- поиск ---------- */
function initSearch() {
  const input = document.getElementById('search-input');
  const box = document.getElementById('suggest');
  const form = document.getElementById('search-form');
  if (!input) return;

  const render = q => {
    const s = q.trim().toLowerCase();
    if (s.length < 2) { box.classList.remove('show'); return; }
    const hits = PRODUCTS.filter(p => (p.n + ' ' + p.b).toLowerCase().includes(s)).slice(0, 8);
    const cats = [];
    CATEGORIES.forEach(c => {
      if (c.name.toLowerCase().includes(s)) cats.push({ name: c.name, url: `catalog.html?cat=${c.id}`, sub: 'раздел' });
      c.sub.forEach(x => { if (x.name.toLowerCase().includes(s) && cats.length < 4) cats.push({ name: x.name, url: `catalog.html?cat=${c.id}&sub=${x.id}`, sub: c.name }); });
    });
    if (!hits.length && !cats.slice(0, 4).length) {
      box.innerHTML = `<div class="suggest-empty">Ничего не найдено</div>`;
    } else {
      box.innerHTML =
        cats.slice(0, 4).map(c => `<a class="suggest-item" href="${c.url}">
            <span class="th">${icon('grid')}</span>
            <span><b>${c.name}</b><span>${c.sub}</span></span></a>`).join('') +
        hits.map(p => `<a class="suggest-item" href="product.html?id=${p.id}">
            <span class="th">${p.img ? `<img src="${p.img}" alt="" loading="lazy">` : icon('box')}</span>
            <span><b>${p.n}</b><span>${p.b}${stockCount(p) ? ' · в наличии' : ' · под заказ'}</span></span>
            <span class="pr">${hasPrice(p) ? money(p.p) : ''}</span></a>`).join('');
    }
    box.classList.add('show');
  };

  input.addEventListener('input', () => render(input.value));
  input.addEventListener('focus', () => render(input.value));
  form.addEventListener('submit', e => { e.preventDefault(); location.href = 'catalog.html?q=' + encodeURIComponent(input.value.trim()); });
  document.addEventListener('click', e => { if (!e.target.closest('.search')) box.classList.remove('show'); });
}

/* ============================================================
   КАРТОЧКА ТОВАРА В СПИСКЕ
   ============================================================ */
function productCard(p) {
  const fav = store.fav.includes(p.id);
  const inCart = store.cart[p.id];
  return `
  <article class="card" data-id="${p.id}">
    ${p.tg && p.tg.length ? `<div class="card-tags">${tagsOf(p)}</div>` : ''}
    <button class="card-fav ${fav ? 'on' : ''}" data-fav="${p.id}" aria-label="В избранное">${icon('heart', 'icon icon-sm')}</button>
    <a class="card-link" href="product.html?id=${p.id}">
      <div class="card-media">${p.img
        ? `<img src="${p.img}" alt="${p.n}" loading="lazy">`
        : `<span class="no-photo">${icon('box', 'icon ph')}<span>Фото уточняется</span></span>`}</div>
      <div class="card-brand">${p.b}</div>
      <h3 class="card-title">${p.n}</h3>
    </a>
    ${(() => {
      const sp = allSpecsOf(p).slice(0, 3);
      return sp.length ? `<dl class="card-specs">${sp.map(s =>
        `<div><dt>${s[0]}</dt><dd>${s[1]}</dd></div>`).join('')}</dl>` : '';
    })()}
    <div class="card-foot">
      ${stockHtml(p)}
      <div class="price ${hasPrice(p) ? '' : 'on-request'}"><b>${priceText(p)}</b></div>
      <div class="card-buy">${inCart
        ? `<div class="qty"><button data-dec="${p.id}">−</button><span data-q="${p.id}">${inCart}</span><button data-inc="${p.id}">+</button></div>
           <a class="btn btn-soft btn-sm" href="#" data-open-cart="1">В корзине</a>`
        : `<button class="btn btn-primary btn-sm btn-block" data-add="${p.id}">${icon('cart', 'icon icon-sm')} ${hasPrice(p) ? 'В корзину' : 'Запросить цену'}</button>`}
      </div>
    </div>
  </article>`;
}

/* ============================================================
   КОРЗИНА
   ============================================================ */
function ensureCartDom() {
  if (document.getElementById('drawer')) return;
  const d = document.createElement('div');
  d.innerHTML = `
    <div class="overlay" id="ov"></div>
    <aside class="drawer" id="drawer">
      <div class="drawer-head">${icon('cart')}<h3>Корзина</h3><button id="drawer-x">${icon('close')}</button></div>
      <div class="drawer-body" id="drawer-body"></div>
      <div class="drawer-foot" id="drawer-foot"></div>
    </aside>`;
  document.body.appendChild(d);
  document.getElementById('ov').addEventListener('click', () => openCart(false));
  document.getElementById('drawer-x').addEventListener('click', () => openCart(false));
}
function openCart(on) {
  ensureCartDom(); renderCart();
  document.getElementById('drawer').classList.toggle('open', on);
  document.getElementById('ov').classList.toggle('show', on);
}
function renderCart() {
  ensureCartDom();
  const cart = store.cart, ids = Object.keys(cart);
  const body = document.getElementById('drawer-body'), foot = document.getElementById('drawer-foot');
  if (!ids.length) {
    body.innerHTML = `<div class="empty-state">${icon('cart')}<p>Корзина пуста</p></div>`;
    foot.innerHTML = `<a class="btn btn-ghost btn-block" href="catalog.html">Перейти в каталог</a>`;
    return;
  }
  let total = 0, ask = 0;
  body.innerHTML = ids.map(id => {
    const p = PMAP[id]; if (!p) return '';
    if (hasPrice(p)) total += p.p * cart[id]; else ask++;
    return `<div class="ci">
      <span class="th">${p.img ? `<img src="${p.img}" alt="">` : icon('box')}</span>
      <div style="flex:1;min-width:0">
        <b>${p.n}</b>
        <div class="row">
          <div class="qty"><button data-dec="${id}">−</button><span data-q="${id}">${cart[id]}</span><button data-inc="${id}">+</button></div>
          <button class="rm" data-rm="${id}">${icon('close', 'icon icon-sm')}</button>
          <span class="pr">${hasPrice(p) ? money(p.p * cart[id]) : 'по запросу'}</span>
        </div>
      </div></div>`;
  }).join('');
  foot.innerHTML = `
    <div class="sum"><span class="muted">Позиций: ${ids.length}</span><b>${money(total)}</b></div>
    ${ask ? `<div class="muted" style="font-size:12.5px">${ask} ${plural(ask, 'позиция', 'позиции', 'позиций')} — цена по запросу, менеджер уточнит</div>` : ''}
    <button class="btn btn-accent btn-block btn-lg" id="checkout">Оформить заказ</button>`;
  foot.querySelector('#checkout').addEventListener('click', () => toast('Демо-версия: заказ принимает менеджер'));
}
function syncBadges() {
  const n = Object.values(store.cart).reduce((a, b) => a + b, 0);
  const cb = document.querySelector('#cart-btn .badge');
  if (cb) { cb.textContent = n || ''; cb.classList.toggle('hide', !n); }
  const fb = document.querySelector('#fav-act .badge'), f = store.fav.length;
  if (fb) { fb.textContent = f || ''; fb.classList.toggle('hide', !f); }
}
function setQty(id, n) {
  const cart = store.cart;
  if (n <= 0) delete cart[id]; else cart[id] = n;
  store.cart = cart;
  syncBadges(); renderCart();
  document.querySelectorAll(`.card[data-id="${id}"]`).forEach(el => { if (PMAP[id]) el.outerHTML = productCard(PMAP[id]); });
  document.querySelectorAll(`[data-q="${id}"]`).forEach(el => el.textContent = store.cart[id] || 0);
}

document.addEventListener('click', e => {
  const add = e.target.closest('[data-add]');
  if (add) { const id = add.dataset.add; setQty(id, (store.cart[id] || 0) + (+add.dataset.qty || 1)); toast('Добавлено в корзину'); return; }
  const inc = e.target.closest('[data-inc]'); if (inc) { setQty(inc.dataset.inc, (store.cart[inc.dataset.inc] || 0) + 1); return; }
  const dec = e.target.closest('[data-dec]'); if (dec) { setQty(dec.dataset.dec, (store.cart[dec.dataset.dec] || 0) - 1); return; }
  const rm = e.target.closest('[data-rm]'); if (rm) { setQty(rm.dataset.rm, 0); return; }
  const oc = e.target.closest('[data-open-cart]'); if (oc) { e.preventDefault(); openCart(true); return; }
  const fv = e.target.closest('[data-fav]');
  if (fv) {
    e.preventDefault();
    const id = fv.dataset.fav, list = store.fav, i = list.indexOf(id);
    if (i > -1) { list.splice(i, 1); toast('Убрано из избранного', 'heart'); } else { list.push(id); toast('Добавлено в избранное', 'heart'); }
    store.fav = list;
    document.querySelectorAll(`[data-fav="${id}"]`).forEach(b => b.classList.toggle('on', i === -1));
    syncBadges();
  }
});

/* ============================================================
   ПОДВАЛ
   ============================================================ */
function renderFooter() {
  const host = document.getElementById('site-footer');
  if (!host) return;
  host.className = 'footer';
  const menu = (typeof MENU !== 'undefined' ? MENU : []).filter(m => m.url !== '/catalog/');
  host.innerHTML = `
  <div class="wrap">
    <div class="footer-top">
      <div>
        <img class="footer-logo" src="assets/img/logo.png" alt="ПРОТЭК" height="36">
        <p class="about">Профессиональные технологии безопасности. Оптовые поставки систем видеонаблюдения, СКУД, охранно-пожарной сигнализации со складов в Сибири.</p>
        <div class="socials">
          <a href="https://vk.com/protek_nsk" target="_blank" rel="noopener" aria-label="ВКонтакте">${icon('vk')}</a>
          <a href="https://www.youtube.com/channel/UCq2yGIF7yi3wq6Yhojf3H9w" target="_blank" rel="noopener" aria-label="YouTube">${icon('yt')}</a>
        </div>
      </div>
      <div>
        <h4>Каталог</h4>
        ${CATEGORIES.slice(0, 7).map(c => `<a href="catalog.html?cat=${c.id}">${c.name}</a>`).join('')}
      </div>
      <div>
        <h4>Разделы</h4>
        ${menu.map(m => `<a href="${pageFor(m.url)}">${m.name}</a>`).join('')}
      </div>
      <div>
        <h4>Склады</h4>
        ${CITIES.map(c => `<span class="city-line">${icon('pin', 'icon icon-sm')} ${c}</span>`).join('')}
      </div>
      <div>
        <h4>Контакты</h4>
        <a class="contact-phone" href="tel:+73833835014">+7 (383) 383-50-14</a>
        <a href="mailto:zakaz@pro-tek.pro">zakaz@pro-tek.pro</a><a href="contacts.html">Все контакты и сотрудники</a>
      </div>
    </div>
    <div class="footer-bot">
      <span>© 2016–2026 ООО «ПРОТЭК». Концепт нового сайта, данные каталога взяты с pro-tek.pro.</span>
      <span class="spacer"></span>
      <a href="https://pro-tek.pro/" target="_blank" rel="noopener">Действующий сайт</a>
    </div>
  </div>`;
}

/* мягкое появление секций при прокрутке */
function initReveal() {
  if (!('IntersectionObserver' in window)) return;
  const targets = document.querySelectorAll(
    '.section-head, .usp, .cats, .grid-products, .services, .b2b, .brand-grid, .article, .spec-table, .deliv-grid');
  if (!targets.length) return;
  const io = new IntersectionObserver(entries => {
    entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.05 });
  targets.forEach(t => { t.classList.add('reveal'); io.observe(t); });

  /* страховка: что бы ни случилось с наблюдателем, контент не должен
     остаться невидимым — через 2 секунды показываем всё */
  setTimeout(() => document.querySelectorAll('.reveal:not(.in)').forEach(t => t.classList.add('in')), 2000);
}

document.addEventListener('DOMContentLoaded', () => {
  renderHeader();
  renderFooter();
  if (window.PAGE_INIT) window.PAGE_INIT();
  initReveal();
});
