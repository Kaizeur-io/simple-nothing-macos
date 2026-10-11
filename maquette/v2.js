// Nothing X pour Mac — maquette V2 : disposition pensée pour macOS.
// Onglets permanents à la place des tuiles, menus déroulants à la place des sous-pages,
// barre des menus enrichie. S'appuie sur shared.js.

Object.assign(S, { sec: 'listen', menu: null, view: null, ringing: false, personal: 'off' });
Object.assign(I, { updown: ic('<path d="M8 10l4-4 4 4M8 14l4 4 4-4"/>') });

const W = 920, H = 620;
let scale = 1;

const SECTIONS = [['listen', 'Écoute'], ['controls', 'Commandes'], ['link', 'Connexion'], ['device', 'Appareil']];
const sectionsFor = (d) => SECTIONS.filter(([id]) => id !== 'controls' || d.feat.includes('controls'));
const ANC2 = [['anc', 'Réduction', 'anc'], ['transp', 'Transparence', 'transp'], ['off', 'Désactivé', 'ancoff']];
const SP2 = [['concert', 'Concert', 'concert'], ['theatre', 'Théâtre', 'theatre'], ['off', 'Désactivé', 'spoff']];
const SP_SUB = { concert: 'Mode concert', theatre: 'Mode théâtre', off: 'Désactivé' };
const WHEEL = [['Mode transparence', 'Transparence', 'transp'], ['Réduction du bruit', 'Réduction du bruit', 'anc'], ['Désactiver', 'Désactivé', 'off']];
const PERSONAL = { off: 'Désactivé', run: 'Calibration en cours…', on: 'Activé' };

// En V2 le Headphone Pro est montré en vue 3/4 haute définition dans ses trois couleurs.
const HP_VIEWS = ['dark-grey', 'light-grey', 'light-green'];
const hero = (d) => (d.id === 'hp' ? `${P}cmf-headphone-pro-${HP_VIEWS[d.color]}.png` : img(d));

const popup = (key, options) => `<button class="popup" ${act('menu', key)} data-options="${options.join('|')}" aria-haspopup="menu">${get(key)}${I.updown}</button>`;
const ancSub = () => (S.anc.mode === 'anc' ? `Activée · ${LEVELS[S.anc.level]}` : S.anc.mode === 'transp' ? 'Mode transparence' : 'Désactivée');
const eqSub = () => (S.eq === 'custom' ? 'Personnalisé · déplacez les trois points' : EQ[S.eq].label);
const levels = () => `<div class="levels ${S.anc.mode === 'anc' ? '' : 'idle'}">${Object.entries(LEVELS).map(([id, l]) => `<button class="lvl ${S.anc.level === id ? 'on' : ''}" ${act('level', id)}><i></i>${l}</button>`).join('')}</div>`;

// ---------- Onglets ----------
const TABS = {
  listen(d) {
    const has = (f) => d.feat.includes(f);
    return `<div class="duo ${has('spatial') ? '' : 'solo'}">
        <section class="card"><div class="card-head"><div><h3>Réduction du bruit</h3><p>${ancSub()}</p></div></div>${modes(ANC2, S.anc.mode, 'anc')}${levels()}</section>
        ${has('spatial') ? `<section class="card"><div class="card-head"><div><h3>Audio spatial</h3><p>${SP_SUB[S.spatial]}</p></div><button class="more" ${act('modal', 'spatial')} aria-label="À propos de l'audio spatial">${I.info}</button></div>${modes(SP2, S.spatial, 'spatial')}</section>` : ''}
      </div>
      <section class="card eqcard">${eqSvg()}<div><div class="card-head"><div><h3>Égaliseur</h3><p id="eqsub">${eqSub()}</p></div></div><div class="presets">${eqPresets()}</div></div></section>
      <div class="duo even ${has('personal') ? '' : 'solo'}">
        ${has('personal') ? `<button class="card line" ${act('modal', 'personal')}><span class="row-ic">${I.personal}</span><span class="row-main"><span class="row-t">Son personnalisé</span><span class="row-s">${PERSONAL[S.personal]}</span></span>${chev}</button>` : ''}
        <button class="card line" ${act('toggle', 'lowLat')} aria-pressed="${S.lowLat}"><span class="row-ic">${I.timer}</span><span class="row-main"><span class="row-t">Mode de faible latence</span><span class="row-s">${S.lowLat ? 'Activé' : 'Désactivé'}</span></span>${tog(S.lowLat)}</button>
      </div>`;
  },

  controls() {
    const view = (v, html) => html.replace('class="row ', `data-view="${v}" class="row `);
    const gesture = (icon, title, sub) => `<div class="g" data-view="button-hold">${icon}<div><b>${title}</b><small>${sub}</small></div></div>`;
    return `<p class="hint">Survolez une commande pour la repérer sur le casque.</p>
      <h4 class="sect first">Bouton</h4>
      ${group([
        view('button', row({ icon: I.g1, title: 'Appuyez une fois', right: popup('ctl.single', BUTTON_ACTIONS) })),
        view('button', row({ icon: I.gHold, title: 'Appuyez longuement', right: popup('ctl.hold', BUTTON_ACTIONS) })),
      ])}
      <h4 class="sect">Curseur d'énergie</h4>
      ${group([view('slider', row({ icon: I.gSlider, title: 'Curseur', right: popup('ctl.slider', ['Réglage des basses', 'Réglage des aigus']) }))])}
      <h4 class="sect">Molette de défilement</h4>
      <div class="group">
        ${view('button-hold', row({ icon: I.gHold, title: 'Appuyez longuement', sub: 'Alterne entre les modes choisis', right: `<span class="chips">${WHEEL.map(([id, l]) => `<button class="chip ${S.ctl.wheel.includes(id) ? 'on' : ''}" ${act('wheel', id)} aria-pressed="${S.ctl.wheel.includes(id)}">${l}</button>`).join('')}</span>` }))}
        <div class="gest">
          ${gesture(I.g1, 'Appuyez une fois', 'Lecture/Pause · Répondre/Raccrocher')}
          ${gesture(I.g2, 'Appuyez deux fois', "Avance rapide · Refuser l'appel")}
          ${gesture(I.g3, 'Appuyez trois fois', 'Retour rapide')}
          ${gesture(I.gScroll, 'Faire défiler', 'Volume')}
        </div>
      </div>`;
  },

  link() {
    const n = S.dualList.filter((x) => x.on).length;
    return `<h4 class="sect first">Double connexion</h4>
      ${group([row({ icon: I.layers, title: 'Double connexion', sub: 'Reste relié à deux appareils à la fois', right: tog(S.dual), a: 'toggle', arg: 'dual' })])}
      ${S.dual ? `<h4 class="sect">Appareils reliés (${n}/2)</h4>
      ${group(S.dualList.map((x, i) => row({ title: x.n, sub: x.s, right: check(x.on), a: x.lock ? null : 'dualdev', arg: i, cls: !x.on && n >= 2 ? 'dim' : '' })))}` : ''}
      <h4 class="sect">Qualité audio</h4>
      ${group([row({ icon: I.film, title: 'Codec', sub: 'LDAC indisponible : macOS ne le propose pas en Bluetooth', right: `<span class="row-v">${S.codec}</span>` })])}`;
  },

  device(d) {
    const run = S.fw === 'run';
    return `<h4 class="sect first">Informations</h4>
      ${group([
        row({ title: 'Modèle', right: `<span class="row-v">${d.name}</span>` }),
        row({ title: 'Couleur', right: `<span class="sws">${COLORS[d.id].map(([n, c], i) => `<button class="sw ${i === d.color ? 'on' : ''}" style="--c:${c}" ${act('color', i)} aria-label="${n}"></button>`).join('')}</span>` }),
        row({ title: 'N° de série', right: `<span class="row-v">${d.serial}</span>` }),
        row({ title: 'Adresse Bluetooth', right: `<span class="row-v">${d.mac}</span>` }),
        row({ title: 'Firmware', sub: run ? 'Recherche en cours…' : `À jour (${d.fw})`, right: `<button class="btn" ${act('fw')} ${run ? 'disabled' : ''}>Rechercher une mise à jour</button>` }),
      ])}
      <h4 class="sect">Réglages</h4>
      ${group([
        row({ icon: I.power, title: 'Mode veille', sub: "S'éteint après ce délai sans lecture ni appel", right: popup('standby', ['10 minutes', '30 minutes', '1 heure', 'Jamais']) }),
        row({ icon: I.pin, title: 'Trouver mon casque', sub: 'Émet un son fort : retirez-le de vos oreilles', right: `<button class="btn" ${act('ring')}>${S.ringing ? 'Arrêter' : 'Faire sonner'}</button>` }),
      ])}
      <div class="gap"></div>
      ${group([row({ icon: I.unlink, title: 'Oublier cet appareil', a: 'modal', arg: 'forget', cls: 'danger' })])}`;
  },
};

function offline(d) {
  return `<div class="offline"><h2 class="serif">${d.name} n'est pas connecté</h2>
    <p class="lede">Allumez l'appareil et gardez-le près de ce Mac, puis relancez la connexion.</p>
    <div class="off-actions"><button class="pill red" ${act('reconnect')}>Reconnecter</button><button class="circ big" ${act('modal', 'forget')} aria-label="Oublier l'appareil">${I.unlink}</button></div></div>`;
}
const empty = () => `<div class="offline"><h2 class="serif">Aucun appareil</h2><p class="lede">Mettez un appareil Nothing ou CMF en mode d'appairage pour l'ajouter à ce Mac.</p>
  <div class="off-actions"><button class="pill dark" ${act('add')}>Ajouter un appareil</button></div></div>`;

// ---------- Fenêtres modales propres à la V2 ----------
const SCAN_SVG = '<svg viewBox="0 0 330 330" aria-hidden="true"><line class="l1" x1="165" y1="20" x2="165" y2="150"/><line class="l1" x1="165" y1="180" x2="165" y2="310"/><line class="l2" x1="30" y1="165" x2="150" y2="165"/><line class="l2" x1="180" y1="165" x2="300" y2="165"/><line class="l3" x1="165" y1="50" x2="165" y2="152"/><line class="l3" x1="165" y1="178" x2="165" y2="280"/></svg>';
Object.assign(MODALS, {
  scan: () => `<div class="dialog wide"><h2 class="serif">Analyse en cours…</h2><p>Mettez votre appareil en mode d'appairage et gardez-le près de ce Mac.</p>
    <div class="scan">${SCAN_SVG}</div>
    <div class="foot"><button class="pill" ${act('modal', 'guide')}>Guide de connexion</button><button class="pill" ${act('closeModal')}>Annuler</button></div></div>`,
  found: () => `<div class="dialog wide"><h2 class="serif">Appareil détecté</h2><p>Gardez le boîtier ouvert près de ce Mac pendant la connexion.</p>
    <div class="scan"><div class="found"><img src="${img(EAR_A)}" alt=""><h3 class="serif">${EAR_A.name}</h3></div></div>
    <div class="foot"><button class="pill" ${act('closeModal')}>Plus tard</button><button class="pill red" ${act('pair')}>Connecter</button></div></div>`,
  personal: () => (S.personal === 'on'
    ? `<div class="dialog wide"><h2 class="serif">Son personnalisé</h2><p>Votre profil audio est appliqué à ce casque. Vous pouvez le désactiver ou refaire la calibration à tout moment.</p>
      <div class="foot"><button class="pill" ${act('personalOff')}>Désactiver</button><button class="pill dark" ${act('calibrate')}>Recalibrer</button></div></div>`
    : `<div class="dialog wide"><h2 class="serif">Vous êtes unique, et votre audition l'est aussi</h2>
      <p>Créez une expérience d'écoute pensée pour vous. La calibration construit votre profil audio personnel.</p>
      ${group([
        row({ icon: I.timer, title: 'La calibration dure environ 3 minutes.' }),
        row({ icon: I.mute, title: 'En cas de doute sur un ton, choisissez le silence.' }),
        row({ icon: I.quiet, title: 'Installez-vous dans un endroit calme.' }),
      ])}
      ${S.personal === 'run' ? '<div class="progress run"><i></i></div>' : '<p class="note">Pendant la détection, le réglage du volume et la réduction du bruit sont indisponibles.</p>'}
      <div class="foot"><button class="pill" ${act('closeModal')}>Annuler</button><button class="pill dark" ${act('calibrate')} ${S.personal === 'run' ? 'disabled' : ''}>${S.personal === 'run' ? 'Calibration en cours…' : 'Commencer la calibration'}</button></div></div>`),
  settings: () => `<div class="dialog wide"><h2 class="serif">Réglages</h2>
    <h4 class="sect">Apparence</h4>
    ${group([row({ title: 'Thème', right: `<span class="seg2">${[['auto', 'Automatique'], ['light', 'Jour'], ['dark', 'Nuit']].map(([v, l]) => `<button class="${S.theme === v ? 'on' : ''}" ${act('theme', v)}>${l}</button>`).join('')}</span>` })])}
    <h4 class="sect">Ce Mac</h4>
    ${group([
      row({ title: 'Afficher dans la barre des menus', right: tog(S.mac.menubar), a: 'toggle', arg: 'mac.menubar' }),
      row({ title: "Carte d'appairage à la connexion", right: tog(S.mac.hud), a: 'toggle', arg: 'mac.hud' }),
      row({ title: "Ouvrir à l'ouverture de session", right: tog(S.mac.login), a: 'toggle', arg: 'mac.login' }),
      row({ title: 'Changer de mode de réduction du bruit', sub: 'Raccourci actif dans toutes les apps', right: '<span><kbd>⌃</kbd><kbd>⌥</kbd><kbd>A</kbd></span>' }),
    ])}
    <div class="foot"><button class="pill dark" ${act('closeModal')}>OK</button></div></div>`,
});

// ---------- Rendu ----------
function heroView() {
  const d = dev();
  return S.sec === 'controls' && S.view && d.id === 'hp' ? [`assets/headphone-pro-${S.view}.png`, 'side'] : [hero(d), ''];
}
function paintHero() {
  const el = $('#heroimg'); if (!el) return;
  const [src, cls] = heroView();
  if (el.getAttribute('src') !== src) { el.src = src; el.className = cls; stageHtml = ''; }
}

let stageHtml = '';
function paintStage(html) {
  if (html === stageHtml) return;
  stageHtml = html; $('#stage').innerHTML = html;
}
function renderStage() {
  const d = dev();
  const rail = `<div class="rail">${S.devices.map((x) => `<button class="avatar ${x.id === S.dev ? 'sel' : ''} ${x.connected ? 'live' : ''}" ${act('dev', x.id)} aria-label="${x.name}"><img src="${hero(x)}" alt=""></button>`).join('')}<button class="circ" ${act('add')} aria-label="Ajouter un appareil">${I.plus}</button></div>`;
  if (!d) { paintStage(`${rail}<div class="hero"></div>`); return; }
  const [src, cls] = heroView();
  let batt = '';
  if (d.connected) {
    batt = typeof d.battery === 'number'
      ? `<div class="batt-bar"><i style="width:${d.battery}%"></i></div>${d.battery}%`
      : `<div class="batt-multi">${Object.entries(d.battery).map(([k, v]) => `<div><div class="batt-bar"><i style="width:${v}%"></i></div>${v}%<small>${k}</small></div>`).join('')}</div>`;
  }
  paintStage(`${rail}
    <div class="hero"><img id="heroimg" class="${cls}" src="${src}" alt="${d.name}"></div>
    <div class="dev-name serif">${d.name}</div>
    <div class="batt">${batt}</div>
    <div class="stage-foot"><span class="st ${d.connected ? 'live' : ''}">${d.connected ? 'Connecté' : 'Déconnecté'}</span><span>${d.connected ? `${S.codec} · ${d.fw}` : ''}</span></div>`);
}

function renderMain(enter) {
  const d = dev(); const live = d && d.connected;
  const secs = d ? sectionsFor(d) : SECTIONS;
  if (d && !secs.some(([id]) => id === S.sec)) S.sec = 'listen';
  $('#toolbar').innerHTML = `<nav class="tabs2" aria-label="Sections">${secs.map(([id, l], i) => `<button class="${live && S.sec === id ? 'on' : ''}" ${act('sec', id)} ${live ? '' : 'disabled'} title="⌘${i + 1}">${l}</button>`).join('')}</nav>
    <button class="tool" ${act('modal', 'settings')} aria-label="Réglages" title="Réglages  ⌘,">${I.gear}</button>`;
  const c = $('#content');
  c.innerHTML = !d ? empty() : !live ? offline(d) : TABS[S.sec](d);
  c.classList.toggle('enter', !!enter);
  if (enter) c.scrollTop = 0;
  if (live && S.sec === 'listen') { bindEq(); updateEq(); }
}

function renderMenu() {
  const m = S.menu;
  $('#menu').innerHTML = !m ? '' : m.options.map((o) => `<button class="${get(m.key) === o ? 'on' : ''}" ${act('pick', o)} role="menuitemradio">${I.check}${o}</button>`).join('');
  if (m) {
    Object.assign($('#menu').style, { right: `${m.right}px`, top: `${m.top}px` });
    ($('#menu .on') || $('#menu button')).focus();
  }
}

function renderChrome() {
  const d = dev(); const live = d && d.connected;
  const mb = $('#mbItem');
  mb.style.display = S.mac.menubar ? '' : 'none';
  mb.className = `mb-item ${S.pop ? 'open' : ''} ${live ? '' : 'off'}`;
  mb.innerHTML = `${I.headphone}${live ? `<span>${pct(d)} %</span>` : ''}`;

  const pop = $('#popover');
  pop.className = 'pop2';
  pop.innerHTML = !S.pop ? '' : live
    ? `<div class="pop-head"><img src="${hero(d)}" alt=""><div><b>${d.name}</b><small>Connecté · ${S.codec}</small></div><span class="pct">${pct(d)}%</span></div>
       <section class="card"><h3>Réduction du bruit</h3>${modes(ANC2, S.anc.mode, 'anc')}${levels()}</section>
       ${d.feat.includes('spatial') ? `<section class="card inline"><h3>Audio spatial</h3><span class="seg2">${SP2.map(([id, l]) => `<button class="${S.spatial === id ? 'on' : ''}" ${act('spatial', id)}>${l}</button>`).join('')}</span></section>` : ''}
       <section class="card stack"><h3>Égaliseur</h3><div class="chips">${Object.entries(EQ).filter(([id]) => id !== 'custom' || S.eq === 'custom').map(([id, p]) => `<button class="chip ${S.eq === id ? 'on' : ''}" ${act('eq', id)}>${p.label}</button>`).join('')}</div></section>
       <button class="pop-open" ${act('pop')}>Ouvrir Nothing X</button>
       <p class="pop-hint"><kbd>⌃</kbd><kbd>⌥</kbd><kbd>A</kbd><span>changer de mode sans ouvrir ce panneau</span></p>`
    : `<div class="pop-head"><div><b>Nothing X</b><small>Aucun appareil connecté</small></div></div><button class="pop-open" ${act('pop')}>Ouvrir Nothing X</button>`;

  const h = S.hud;
  $('#hud').innerHTML = !h ? '' : h.type === 'new'
    ? `<div class="eyebrow">Nouvel appareil</div><img src="${img(EAR_A)}" alt=""><h3 class="serif">${EAR_A.name}</h3><p>Détecté à proximité de ce Mac.</p>
       <div class="btns"><button class="pill" ${act('hudClose')}>Plus tard</button><button class="pill dark" ${act('pair')}>Connecter</button></div>`
    : h.type === 'mode'
      ? `<span class="mode-dot">${I[h.icon]}</span><div><small>${dev().name}</small><b>${h.label}</b></div>`
      : `<div class="eyebrow ok">Connecté</div><img src="${hero(h.d)}" alt=""><h3 class="serif">${h.d.name}</h3><div class="pct">${pct(h.d)}%</div>`;
  $('#hud').className = h && h.type === 'mode' ? 'toast' : '';

  const seg = (key, opts) => `<div class="seg">${opts.map(([v, l, on]) => `<button class="${on ? 'on' : ''}" ${act(key, v)}>${l}</button>`).join('')}</div>`;
  $('#mockbar').innerHTML = `<span>Maquette V2</span>
    ${seg('theme', [['auto', 'Auto', S.theme === 'auto'], ['light', 'Jour', S.theme === 'light'], ['dark', 'Nuit', S.theme === 'dark']])}
    ${d ? seg('conn', [['1', 'Connecté', d.connected], ['0', 'Déconnecté', !d.connected]]) : ''}
    <button ${act('hudNew')}>Simuler un nouvel appareil</button>
    <a href="index.html">Voir la V1</a>`;
}

function render(enter = false) {
  renderStage(); renderMain(enter); renderMenu(); renderModal(); renderChrome();
}

// ---------- Actions ----------
let hudTimer, scanTimer, ringTimer;
function showConnected(d) {
  if (!S.mac.hud) return;
  S.hud = { type: 'ok', d }; clearTimeout(hudTimer);
  hudTimer = setTimeout(() => { S.hud = null; renderChrome(); }, 3600);
}

const A = {
  sec(id) { S.sec = id; S.view = null; S.menu = null; render(true); },
  dev(id) { S.dev = id; S.view = null; render(true); },
  anc(m) { S.anc.mode = m; render(); },
  level(l) { S.anc.level = l; S.anc.mode = 'anc'; render(); },
  spatial(m) { S.spatial = m; render(); },
  color(i) { dev().color = +i; render(); },
  toggle(k) { set(k, !get(k)); if (k === 'mac.menubar') S.pop = false; render(); },
  wheel(o) {
    const w = S.ctl.wheel; const i = w.indexOf(o);
    if (i < 0) w.push(o); else if (w.length > 2) w.splice(i, 1);
    render();
  },
  dualdev(i) {
    const x = S.dualList[i]; const n = S.dualList.filter((y) => y.on).length;
    if (x.on) x.on = false; else if (n < 2) x.on = true;
    render();
  },
  eq(p) {
    S.eq = p; updateEq(); renderChrome();
    const sub = $('#eqsub'); if (sub) sub.textContent = eqSub();
  },
  menu(key, el) {
    if (S.menu && S.menu.key === key) { S.menu = null; return renderMenu(); }
    const r = el.getBoundingClientRect(); const w = $('#win').getBoundingClientRect();
    S.menu = { key, options: el.dataset.options.split('|'), right: (w.right - r.right) / scale, top: (r.bottom - w.top) / scale + 6 };
    renderMenu();
  },
  pick(o) { const { key } = S.menu; set(key, o); S.menu = null; render(); $(`.popup[data-arg="${key}"]`)?.focus(); },
  calibrate() {
    S.personal = 'run'; renderModal();
    setTimeout(() => { if (S.personal !== 'run') return; S.personal = 'on'; S.modal = null; render(); }, 2600);
  },
  personalOff() { S.personal = 'off'; S.modal = null; render(); },
  // Raccourci global : passe au mode suivant parmi ceux choisis pour la molette.
  cycle() {
    const order = WHEEL.filter(([id]) => S.ctl.wheel.includes(id));
    const next = order[(order.findIndex(([, , m]) => m === S.anc.mode) + 1) % order.length];
    S.anc.mode = next[2];
    S.hud = { type: 'mode', label: next[0] === 'Désactiver' ? 'Réduction du bruit désactivée' : next[0], icon: ANC2.find(([m]) => m === next[2])[2] };
    clearTimeout(hudTimer); hudTimer = setTimeout(() => { S.hud = null; renderChrome(); }, 1800);
    render();
  },
  ring() {
    S.ringing = !S.ringing; clearTimeout(ringTimer);
    if (S.ringing) ringTimer = setTimeout(() => { S.ringing = false; render(); }, 4000);
    render();
  },
  theme(t) { S.theme = t; applyTheme(); render(); },
  conn(v) {
    const d = dev(); const was = d.connected; d.connected = v === '1';
    if (d.connected && !was) showConnected(d);
    render(true);
  },
  reconnect() { A.conn('1'); },
  add() {
    S.modal = 'scan'; renderModal(); clearTimeout(scanTimer);
    scanTimer = setTimeout(() => { if (S.modal === 'scan' && !S.devices.some((d) => d.id === 'ear-a')) { S.modal = 'found'; renderModal(); } }, 2600);
  },
  pair() {
    if (!S.devices.some((d) => d.id === 'ear-a')) S.devices.push(structuredClone(EAR_A));
    S.dev = 'ear-a'; S.sec = 'listen'; S.modal = null; S.hud = null;
    showConnected(dev()); render(true);
  },
  modal(m) { S.modal = m; S.menu = null; renderMenu(); renderModal(); },
  closeModal() { S.modal = null; clearTimeout(scanTimer); if (S.personal === 'run') S.personal = 'off'; render(); },
  tab(t) { S.tab = t; renderModal(); },
  forget() {
    S.devices = S.devices.filter((d) => d.id !== S.dev);
    S.dev = S.devices[0]?.id; S.sec = 'listen'; S.modal = null; render(true);
  },
  fw() { S.fw = 'run'; render(); setTimeout(() => { S.fw = 'idle'; S.modal = 'fwdone'; render(); }, 2000); },
  pop() { S.pop = !S.pop; S.hud = null; renderChrome(); },
  hudNew() { clearTimeout(hudTimer); S.pop = false; S.hud = S.devices.some((d) => d.id === 'ear-a') ? { type: 'ok', d: dev() } : { type: 'new' }; renderChrome(); },
  hudClose() { S.hud = null; renderChrome(); },
};

document.addEventListener('click', (e) => {
  const b = e.target.closest('[data-act]');
  if (S.pop && !e.target.closest('#popover') && !e.target.closest('#mbItem')) { S.pop = false; renderChrome(); }
  if (S.menu && !e.target.closest('#menu') && !e.target.closest('.popup')) { S.menu = null; renderMenu(); }
  if (e.target.id === 'modal') return A.closeModal();
  if (b && !b.disabled) A[b.dataset.act](b.dataset.arg, b);
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    if (S.menu) { const { key } = S.menu; S.menu = null; renderMenu(); $(`.popup[data-arg="${key}"]`)?.focus(); } else if (S.modal) A.closeModal(); else if (S.pop) A.pop();
    return;
  }
  if (S.menu && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) {
    e.preventDefault();
    const items = [...document.querySelectorAll('#menu button')];
    const i = items.indexOf(document.activeElement) + (e.key === 'ArrowDown' ? 1 : -1);
    return items[(i + items.length) % items.length].focus();
  }
  const d = dev(); if (!d || !d.connected) return;
  if (e.ctrlKey && e.altKey && e.code === 'KeyA') { e.preventDefault(); return A.cycle(); }
  if (!(e.metaKey || e.altKey) || e.ctrlKey) return;
  if (e.key === ',') { e.preventDefault(); return A.modal('settings'); }
  const s = /^Digit[1-9]$/.test(e.code) && sectionsFor(d)[+e.code[5] - 1];
  if (s) { e.preventDefault(); A.sec(s[0]); }
});

// Survoler une commande montre où elle se trouve sur le casque.
const content = $('#content');
content.addEventListener('mouseover', (e) => {
  const v = e.target.closest('[data-view]')?.dataset.view ?? null;
  if (v !== S.view) { S.view = v; paintHero(); }
});
content.addEventListener('mouseleave', () => { if (S.view) { S.view = null; paintHero(); } });

// ---------- Thème, horloge, mise à l'échelle ----------
const dark = matchMedia('(prefers-color-scheme: dark)');
function applyTheme() {
  document.documentElement.dataset.theme = S.theme === 'auto' ? (dark.matches ? 'dark' : 'light') : S.theme;
}
dark.addEventListener('change', applyTheme);

function fit() {
  scale = Math.min(1, (innerWidth - 40) / W, (innerHeight - 28 - 76 - 36) / H);
  $('#win').style.transform = `scale(${scale})`;
}
addEventListener('resize', fit);

function clock() {
  $('#mbClock').textContent = new Intl.DateTimeFormat('fr-FR', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }).format(new Date());
}
setInterval(clock, 30000);

const params = new URLSearchParams(location.search);
if (params.get('theme')) S.theme = params.get('theme');
if (params.get('sec') in TABS) S.sec = params.get('sec');
applyTheme(); clock(); fit(); render();
