// Nothing X pour Mac — maquette V1 : transposition directe de l'app mobile (tuiles et sous-pages).

// ---------- Pages ----------
const PAGES = {
  home() {
    const d = dev();
    const has = (f) => d.feat.includes(f);
    const tiles = [
      has('personal') && `<button class="tile" ${act('go', 'personal')}><b>Son personnalisé</b><span>Désactivé</span><span class="foot">${I.personal}</span></button>`,
      has('eq') && `<button class="tile" ${act('go', 'eq')}><b>Égaliseur</b><span>${EQ[S.eq].label}</span><span class="foot">${I.eq}</span></button>`,
      has('controls') && `<button class="tile" ${act('go', 'controls')}><b>Commandes</b><span>Par défaut</span><span class="foot">${I.hand}</span></button>`,
      has('lowlat') && `<button class="tile" ${act('toggle', 'lowLat')} aria-pressed="${S.lowLat}"><b>Mode de faible latence</b><span>${S.lowLat ? 'Activé' : 'Désactivé'}</span><span class="foot tog ${S.lowLat ? 'on' : ''}"></span></button>`,
      has('dual') && `<button class="tile" ${act('go', 'dual')}><b>Double connexion</b><span>${S.dual ? 'Activée' : 'Désactivée'}</span><span class="foot">${I.layers}</span></button>`,
      has('settings') && `<button class="tile" ${act('go', 'settings')}><b>Paramètres du périphérique</b><span class="foot">${I.gear}</span></button>`,
      has('about') && `<button class="tile" ${act('go', 'about')}><b>À propos</b><span>${d.name}</span><span class="foot">${I.info}</span></button>`,
    ].filter(Boolean).join('');
    return `${has('anc') ? ancCard() : ''}
      ${has('spatial') ? `<section class="card"><div class="card-head"><h3>Audio spatial</h3><button class="more" ${act('modal', 'spatial')} aria-label="En savoir plus sur l'audio spatial">${I.more}</button></div>${modes(SPATIAL, S.spatial, 'spatial')}</section>` : ''}
      <div class="tiles">${tiles}</div>`;
  },

  offline() {
    const d = dev();
    return `<div class="offline"><h2 class="serif">${d.name} n'est pas connecté</h2>
      <p class="lede">Allumez l'appareil et gardez-le près de ce Mac, puis relancez la connexion.</p>
      <div class="off-actions"><button class="circ big" ${act('modal', 'forget')} aria-label="Oublier l'appareil">${I.unlink}</button><button class="pill red" ${act('reconnect')}>Reconnecter</button><button class="circ big" ${act('go', 'about')} aria-label="À propos">${I.info}</button></div></div>`;
  },

  empty() {
    return `<div class="offline"><h2 class="serif">Aucun appareil</h2><p class="lede">Mettez un appareil Nothing ou CMF en mode d'appairage pour l'ajouter à ce Mac.</p>
      <div class="off-actions"><button class="pill dark" ${act('add')}>Ajouter un appareil</button></div></div>`;
  },

  eq() {
    return page('Égaliseur', `<div class="eq-wrap">${eqSvg()}<div class="presets">${eqPresets()}</div></div>`, 'Personnalisez votre son ou sélectionnez un réglage prédéfini.');
  },

  personal() {
    return page("Vous êtes unique, et votre audition l'est aussi", `
      ${group([
        row({ icon: `<span class="bubble">${I.timer}</span>`, title: 'La calibration dure environ 3 minutes.', cls: 'tall' }),
        row({ icon: `<span class="bubble">${I.mute}</span>`, title: "En cas de doute sur un ton, choisissez le silence.", cls: 'tall' }),
        row({ icon: `<span class="bubble">${I.quiet}</span>`, title: 'Installez-vous dans un endroit calme.', cls: 'tall' }),
        row({ title: "Autorisez l'accès au microphone pour mesurer le niveau de bruit ambiant.", sub: '<b class="link">Accorder l\'autorisation</b>', cls: 'perm' }),
      ])}
      <div class="info-note">${I.info}<span>Pendant la détection, les fonctions telles que le réglage du volume et l'activation/la désactivation de la suppression du bruit sont indisponibles.</span></div>
      <button class="pill dark wide">Commencer la calibration</button>`,
    "Créez une expérience d'écoute pensée pour vous. Commençons à construire votre profil audio personnel.");
  },

  controls() {
    const c = S.ctl;
    return page('Commandes', `
      <h4 class="sect first">Bouton</h4>
      ${group([
        row({ icon: I.g1, title: 'Appuyez une fois', sub: c.single, right: chev, a: 'go', arg: 'ctl-single' }),
        row({ icon: I.gHold, title: 'Appuyez longuement', sub: c.hold, right: chev, a: 'go', arg: 'ctl-hold' }),
      ])}
      <h4 class="sect">Curseur d'énergie</h4>
      ${group([row({ icon: I.gSlider, title: 'Curseur', sub: c.slider, right: chev, a: 'go', arg: 'ctl-slider' })])}
      <h4 class="sect">Molette de défilement</h4>
      ${group([
        row({ icon: I.gHold, title: 'Appuyez longuement', sub: 'Contrôle du bruit', right: chev, a: 'go', arg: 'ctl-wheel' }),
        row({ icon: I.g1, title: 'Appuyez une fois', sub: 'Lecture/Pause<br>Répondre/Raccrocher les appels' }),
        row({ icon: I.g2, title: 'Appuyez deux fois', sub: "Avance rapide<br>Refuser l'appel entrant" }),
        row({ icon: I.g3, title: 'Appuyez trois fois', sub: 'Retour rapide' }),
        row({ icon: I.gScroll, title: 'Faire défiler', sub: 'Contrôle du volume' }),
      ])}`);
  },
  'ctl-single': () => page('Appuyez une fois', radioList('ctl.single', BUTTON_ACTIONS)),
  'ctl-hold': () => page('Appuyez longuement', radioList('ctl.hold', BUTTON_ACTIONS)),
  'ctl-slider': () => page('Curseur', radioList('ctl.slider', ['Réglage des basses', 'Réglage des aigus'])),
  'ctl-wheel': () => page('Appuyez longuement', group([
    row({ title: 'Contrôle du bruit', right: radio(true) }),
    ...['Mode transparence', 'Réduction du bruit', 'Désactiver'].map((o) => row({ title: o, right: check(S.ctl.wheel.includes(o)), a: 'wheel', arg: o, cls: 'sub' })),
  ]) + '<p class="note">Choisissez au moins deux modes entre lesquels alterner.</p>'),

  dual() {
    const n = S.dualList.filter((x) => x.on).length;
    return page('Double connexion', `
      ${group([row({ title: 'Double connexion', right: tog(S.dual), a: 'toggle', arg: 'dual' })])}
      ${S.dual ? `<h4 class="sect">Mes appareils (${n}/2)</h4>
      ${group(S.dualList.map((x, i) => row({ title: x.n, sub: x.s, right: check(x.on), a: x.lock ? null : 'dualdev', arg: i, cls: !x.on && n >= 2 ? 'dim' : '' })))}` : ''}`);
  },

  settings() {
    return page('Paramètres du périphérique', `
      ${group([row({ icon: I.film, title: 'Audio de haute qualité', right: `<span class="row-v">${S.codec}</span>${chev}`, a: 'go', arg: 'codec' })])}
      <p class="note">Le codec audio LDAC ne fonctionnera que si votre appareil prend également en charge ce codec.</p>
      ${group([row({ icon: I.power, title: 'Mode Veille', right: `<span class="row-v">${S.standby}</span>${chev}`, a: 'go', arg: 'standby' })])}
      <p class="note">Lorsqu'aucun contenu audio n'est lu, qu'aucun appel n'est en cours et que la fonction ANC est activée, le casque passe en mode ANC uniquement en veille. Choisissez la durée d'activation de cette fonction : le casque s'éteindra après ce délai.</p>
      ${group([row({ icon: I.pin, title: 'Trouver mes casques', right: chev, a: 'go', arg: 'find' })])}
      <div class="gap"></div>
      ${group([row({ icon: I.unlink, title: 'Oublier', a: 'modal', arg: 'forget', cls: 'danger' })])}`);
  },
  codec: () => page('Audio de haute qualité', group([
    row({ title: 'AAC', sub: 'Utilisé par ce Mac', right: radio(true) }),
    row({ title: 'LDAC', sub: 'Non pris en charge par macOS', right: radio(false), cls: 'dim' }),
  ]) + '<p class="note">macOS ne propose pas le codec LDAC en Bluetooth : la liaison avec ce Mac reste en AAC.</p>'),
  standby: () => page('Mode Veille', radioList('standby', ['10 minutes', '30 minutes', '1 heure', 'Jamais'])),
  find: () => page('Trouver mes casques', `<div class="find"><button class="pill dark">Faire sonner le casque</button></div>`, "Le casque émet un son fort. Retirez-le de vos oreilles avant de lancer la sonnerie."),

  about() {
    const d = dev();
    return page('À propos', `
      ${group([row({ icon: I.download, title: 'Mise à jour du firmware', sub: `À jour (${d.fw})`, right: chev, a: 'go', arg: 'firmware' })])}
      <h4 class="sect">Informations sur l'appareil</h4>
      ${group([
        row({ title: 'Modèle', right: `<span class="row-v">${d.name}</span>` }),
        row({ title: 'Couleur', sub: COLORS[d.id][d.color][0], right: `<span class="sws">${COLORS[d.id].map(([n, c], i) => `<button class="sw ${i === d.color ? 'on' : ''}" style="--c:${c}" ${act('color', i)} aria-label="${n}"></button>`).join('')}</span>` }),
        row({ title: 'N° de série', right: `<span class="row-v">${d.serial}</span>` }),
        row({ title: 'Adresse Bluetooth', right: `<span class="row-v">${d.mac}</span>` }),
        row({ title: 'Version micrologiciel', right: `<span class="row-v">${d.fw}</span>` }),
      ])}
      <h4 class="sect">Assistance</h4>
      ${group([
        row({ icon: I.chat, title: 'Envoyer un commentaire', right: chev }),
        row({ icon: I.help, title: "Articles d'aide", right: chev }),
        row({ icon: I.manual, title: 'Manuel du produit', right: chev }),
        row({ icon: I.shield, title: 'État de la garantie', right: chev }),
      ])}`);
  },

  firmware() {
    const d = dev(); const run = S.fw === 'run';
    return page('Mise à jour du firmware', `
      <section class="card fw">
        <img src="${img(d)}" alt="">
        <h3>${run ? 'Mise à jour en cours' : 'Firmware à jour'} (${d.fw})</h3>
        <p class="size">1,16 Mo</p>
        <div class="progress ${run ? 'run' : ''}"><i></i></div>
        <p class="state">${run ? 'Installation…' : 'Mise à jour réussie'}</p>
        <p class="body">Cette version apporte des améliorations et corrige des bugs :</p>
        <ol><li>Improved Bluetooth connection stability.</li><li>Improved Google Fast Pair reliability.</li><li>Optimised notification volume.</li><li>Enhanced audio performance.</li><li>Refined audio performance.</li></ol>
      </section>
      <div class="gap"></div>
      <button class="pill dark wide" ${act('fw')} ${run ? 'disabled' : ''}>${run ? 'Installation…' : 'Rechercher une mise à jour'}</button>`);
  },

  profile() {
    return page('Ma page', `
      <h4 class="sect first">Compte Nothing</h4>
      ${group([row({ icon: `<span class="bubble">${I.user}</span>`, title: 'Se connecter / Créer un compte', right: chev, cls: 'tall' })])}
      <h4 class="sect">Ce Mac</h4>
      ${group([
        row({ icon: I.mac, title: 'Afficher dans la barre des menus', right: tog(S.mac.menubar), a: 'toggle', arg: 'mac.menubar' }),
        row({ icon: I.headphone, title: "Carte d'appairage à la connexion", right: tog(S.mac.hud), a: 'toggle', arg: 'mac.hud' }),
        row({ icon: I.power, title: "Ouvrir à l'ouverture de session", right: tog(S.mac.login), a: 'toggle', arg: 'mac.login' }),
      ])}
      <h4 class="sect">Santé</h4>
      ${group([row({ icon: I.heart, title: 'Information sur la santé', right: chev })])}
      <h4 class="sect">Fonctionnalités</h4>
      ${group([row({ icon: I.wave, title: 'Actualités Essential', right: chev })])}
      <h4 class="sect">Général</h4>
      ${group([row({ icon: I.gear, title: 'Préférences', right: chev }), row({ icon: I.bell, title: 'Notifications', right: chev })])}`);
  },
};

// ---------- Rendu ----------
function stageImage() {
  const d = dev();
  const side = { 'ctl-single': 'button', 'ctl-hold': 'button', 'ctl-wheel': 'button-hold', 'ctl-slider': 'slider' }[S.route.at(-1)];
  return side && d.id === 'hp' ? [`assets/headphone-pro-${side}.png`, 'side'] : [img(d), img(d).includes('cmf-headphone-pro') ? 'tall' : ''];
}

let stageHtml = '';
function paintStage(html) {
  if (html === stageHtml) return;
  stageHtml = html; $('#stage').innerHTML = html;
}
function renderStage() {
  const d = dev();
  const rail = `<div class="rail">${S.devices.map((x) => `<button class="avatar ${x.id === S.dev ? 'sel' : ''} ${x.connected ? 'live' : ''}" ${act('dev', x.id)} aria-label="${x.name}"><img src="${img(x)}" alt=""></button>`).join('')}<button class="circ" ${act('add')} aria-label="Ajouter un appareil">${I.plus}</button></div>`;
  if (!d) { paintStage(`<h1 class="serif">Mes appareils</h1>${rail}<div class="hero"></div>`); return; }
  const [src, cls] = stageImage();
  let batt = '';
  if (d.connected) {
    batt = typeof d.battery === 'number'
      ? `<div class="batt-bar"><i style="width:${d.battery}%"></i></div>${d.battery}%`
      : `<div class="batt-multi">${Object.entries(d.battery).map(([k, v]) => `<div><div class="batt-bar"><i style="width:${v}%"></i></div>${v}%<small>${k}</small></div>`).join('')}</div>`;
  }
  paintStage(`<h1 class="serif">Mes appareils</h1>${rail}
    <div class="hero"><img class="${cls}" src="${src}" alt="${d.name}"></div>
    <div class="dev-name serif">${d.name}</div>
    <div class="batt">${batt}</div>
    <div class="stage-foot"><span class="st ${d.connected ? 'live' : ''}">${d.connected ? 'Connecté' : 'Déconnecté'}</span><span>${d.connected ? `${S.codec} · ${d.fw}` : ''}</span></div>`);
}

function renderPane(enter) {
  const d = dev(); const top = S.route.at(-1);
  const body = !d ? PAGES.empty() : !d.connected && top === 'home' ? PAGES.offline() : PAGES[top]();
  const pane = $('#pane');
  pane.innerHTML = `<div class="pane-top">${S.route.length > 1 ? `<button class="back" ${act('back')} aria-label="Retour">${I.back}</button>` : '<span></span>'}${top === 'home' ? `<button class="circ" ${act('go', 'profile')} aria-label="Ma page">${I.user}</button>` : ''}</div><div class="pane-in ${enter ? 'enter' : ''}">${body}</div>`;
  if (enter) pane.scrollTop = 0;
  if (top === 'eq' && d) { bindEq(); updateEq(); }
}

function renderOverlay() {
  const el = $('#overlay');
  if (!S.overlay) { el.innerHTML = ''; return; }
  const found = S.overlay === 'found';
  el.innerHTML = `<button class="back" ${act('closeOverlay')} aria-label="Retour" style="margin-left:-10px;width:44px;height:44px;display:grid;place-items:center">${I.back}</button>
    <h2 class="serif">${found ? 'Appareil détecté' : 'Analyse en cours…'}</h2>
    <p class="lede">${found ? 'Gardez le boîtier ouvert près de ce Mac pendant la connexion.' : "Veuillez vous assurer que votre appareil est en mode d'appairage."}</p>
    <div class="scan">${found
      ? `<div class="found"><img src="${img(EAR_A)}" alt=""><h3 class="serif">${EAR_A.name}</h3><p>Nothing · à proximité</p><button class="pill red" ${act('pair')}>Connecter</button></div>`
      : `<svg viewBox="0 0 330 330" aria-hidden="true"><line class="l1" x1="165" y1="20" x2="165" y2="150"/><line class="l1" x1="165" y1="180" x2="165" y2="310"/><line class="l2" x1="30" y1="165" x2="150" y2="165"/><line class="l2" x1="180" y1="165" x2="300" y2="165"/><line class="l3" x1="165" y1="50" x2="165" y2="152"/><line class="l3" x1="165" y1="178" x2="165" y2="280"/></svg>`}</div>
    <div class="ov-foot"><span style="width:56px"></span><p>Pas encore d'appareil ? <button ${act('closeOverlay')}>Ignorer l'analyse</button></p><button class="circ big" ${act('modal', 'guide')} aria-label="Guide de connexion">${I.info}</button></div>`;
}

function renderChrome() {
  const d = dev(); const live = d && d.connected;
  const mb = $('#mbItem');
  mb.style.display = S.mac.menubar ? '' : 'none';
  mb.className = `mb-item ${S.pop ? 'open' : ''} ${live ? '' : 'off'}`;
  mb.innerHTML = `${I.headphone}${live ? `<span>${pct(d)} %</span>` : ''}`;

  $('#popover').innerHTML = !S.pop ? '' : live
    ? `<div class="pop-head"><img src="${img(d)}" alt=""><div><b>${d.name}</b><small>Connecté · ${S.codec}</small></div><span class="pct">${pct(d)}%</span></div>
       ${d.feat.includes('anc') ? ancCard() : ''}<button class="pop-open" ${act('pop')}>Ouvrir Nothing X</button>`
    : `<div class="pop-head"><div><b>Nothing X</b><small>Aucun appareil connecté</small></div></div><button class="pop-open" ${act('pop')}>Ouvrir Nothing X</button>`;

  const h = S.hud;
  $('#hud').innerHTML = !h ? '' : h.type === 'new'
    ? `<div class="eyebrow">Nouvel appareil</div><img src="${img(EAR_A)}" alt=""><h3 class="serif">${EAR_A.name}</h3><p>Détecté à proximité de ce Mac.</p>
       <div class="btns"><button class="pill" ${act('hudClose')}>Plus tard</button><button class="pill dark" ${act('pair')}>Connecter</button></div>`
    : `<div class="eyebrow ok">Connecté</div><img src="${img(h.d)}" alt=""><h3 class="serif">${h.d.name}</h3><div class="pct">${pct(h.d)}%</div>`;

  const seg = (key, opts) => `<div class="seg">${opts.map(([v, l, on]) => `<button class="${on ? 'on' : ''}" ${act(key, v)}>${l}</button>`).join('')}</div>`;
  $('#mockbar').innerHTML = `<span>Maquette V1</span>
    ${seg('theme', [['auto', 'Auto', S.theme === 'auto'], ['light', 'Jour', S.theme === 'light'], ['dark', 'Nuit', S.theme === 'dark']])}
    ${d ? seg('conn', [['1', 'Connecté', d.connected], ['0', 'Déconnecté', !d.connected]]) : ''}
    <button ${act('hudNew')}>Simuler un nouvel appareil</button>
    <a href="v2.html">Voir la V2</a>`;
}

function render(enter = false) {
  renderStage(); renderPane(enter); renderOverlay(); renderModal(); renderChrome();
}

// ---------- Actions ----------
let hudTimer, scanTimer;
function showConnected(d) {
  if (!S.mac.hud) return;
  S.hud = { type: 'ok', d }; clearTimeout(hudTimer);
  hudTimer = setTimeout(() => { S.hud = null; renderChrome(); }, 3600);
}

const A = {
  go(p) { S.route.push(p); render(true); },
  back() { S.route.pop(); render(true); },
  dev(id) { S.dev = id; S.route = ['home']; render(true); },
  anc(m) { S.anc.mode = m; render(); },
  level(l) { S.anc.level = l; S.anc.mode = 'anc'; render(); },
  spatial(m) { S.spatial = m; render(); },
  color(i) { dev().color = +i; render(); },
  toggle(k) { set(k, !get(k)); if (k === 'mac.menubar') S.pop = false; render(); },
  set(arg) { const [k, v] = arg.split('|'); set(k, v); render(); },
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
  eq(p) { S.eq = p; updateEq(); },
  theme(t) { S.theme = t; applyTheme(); render(); },
  conn(v) {
    const d = dev(); const was = d.connected; d.connected = v === '1';
    if (!d.connected) S.route = ['home'];
    if (d.connected && !was) showConnected(d);
    render(true);
  },
  reconnect() { A.conn('1'); },
  add() { S.overlay = 'scan'; render(); clearTimeout(scanTimer); scanTimer = setTimeout(() => { if (S.overlay === 'scan' && !S.devices.some((d) => d.id === 'ear-a')) { S.overlay = 'found'; renderOverlay(); } }, 2600); },
  closeOverlay() { S.overlay = null; clearTimeout(scanTimer); render(); },
  pair() {
    if (!S.devices.some((d) => d.id === 'ear-a')) S.devices.push(structuredClone(EAR_A));
    S.dev = 'ear-a'; S.route = ['home']; S.overlay = null; S.hud = null;
    showConnected(dev()); render(true);
  },
  modal(m) { S.modal = m; renderModal(); },
  closeModal() { S.modal = null; renderModal(); },
  tab(t) { S.tab = t; renderModal(); },
  forget() {
    S.devices = S.devices.filter((d) => d.id !== S.dev);
    S.dev = S.devices[0]?.id; S.route = ['home']; S.modal = null; render(true);
  },
  fw() { S.fw = 'run'; render(); setTimeout(() => { S.fw = 'idle'; S.modal = 'fwdone'; render(); }, 2000); },
  pop() { S.pop = !S.pop; S.hud = null; renderChrome(); },
  hudNew() { clearTimeout(hudTimer); S.pop = false; S.hud = S.devices.some((d) => d.id === 'ear-a') ? { type: 'ok', d: dev() } : { type: 'new' }; renderChrome(); },
  hudClose() { S.hud = null; renderChrome(); },
};

document.addEventListener('click', (e) => {
  const b = e.target.closest('[data-act]');
  if (S.pop && !e.target.closest('#popover') && !e.target.closest('#mbItem')) { S.pop = false; renderChrome(); }
  if (e.target.id === 'modal') return A.closeModal();
  if (b && !b.disabled) A[b.dataset.act](b.dataset.arg);
});
document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  if (S.modal) A.closeModal(); else if (S.pop) A.pop(); else if (S.overlay) A.closeOverlay(); else if (S.route.length > 1) A.back();
});

// ---------- Thème, horloge, mise à l'échelle ----------
const dark = matchMedia('(prefers-color-scheme: dark)');
function applyTheme() {
  document.documentElement.dataset.theme = S.theme === 'auto' ? (dark.matches ? 'dark' : 'light') : S.theme;
}
dark.addEventListener('change', applyTheme);

function fit() {
  const s = Math.min(1, (innerWidth - 40) / 1060, (innerHeight - 28 - 76 - 36) / 744);
  $('#win').style.transform = `scale(${s})`;
}
addEventListener('resize', fit);

function clock() {
  $('#mbClock').textContent = new Intl.DateTimeFormat('fr-FR', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }).format(new Date());
}
setInterval(clock, 30000);

const params = new URLSearchParams(location.search);
if (params.get('theme')) S.theme = params.get('theme');
if (params.get('page')) S.route = ['home', ...params.get('page').split(',').filter((p) => p in PAGES)];
applyTheme(); clock(); fit(); render();
