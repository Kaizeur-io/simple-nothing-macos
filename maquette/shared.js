// Nothing X pour Mac — socle commun aux deux maquettes : icônes, données produit, état simulé, briques d'interface.
// Aucune liaison Bluetooth réelle.

const $ = (s) => document.querySelector(s);
const ic = (d) => `<svg class="ic" viewBox="0 0 24 24" aria-hidden="true">${d}</svg>`;
const DOTS = 'stroke-dasharray="0.01 2.6" stroke-width="1.9"';

const I = {
  back: ic('<path d="M20 12H4.5M10.5 6l-6 6 6 6"/>'),
  close: ic('<path d="M6 6l12 12M18 6L6 18"/>'),
  plus: ic('<path d="M12 5v14M5 12h14"/>'),
  check: ic('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  user: ic('<circle cx="12" cy="8.3" r="3"/><rect x="6.5" y="14.3" width="11" height="4.6" rx="2.3"/>'),
  chev: ic('<path d="M9 5.5l6.5 6.5L9 18.5" stroke-dasharray="0.01 2.3" stroke-width="1.9"/>'),
  more: ic('<circle class="f" cx="5.5" cy="12" r="1.5"/><circle class="f" cx="12" cy="12" r="1.5"/><circle class="f" cx="18.5" cy="12" r="1.5"/>'),
  anc: ic('<path d="M8 17.6a7.2 7.2 0 1 1 8 0"/><circle class="f" cx="12" cy="11.6" r="1.5"/>'),
  transp: ic('<path d="M8 17.6a7.2 7.2 0 1 1 8 0" stroke-dasharray="0.01 3.05" stroke-width="2"/><circle class="f" cx="12" cy="11.6" r="1.5"/>'),
  ancoff: ic('<path d="M6.3 15.8a7.2 7.2 0 0 1 2-10M11.2 4.6a7.2 7.2 0 0 1 6.6 11.2"/><path d="M6 5.5l12.5 13.5"/>'),
  concert: ic(`<path d="M9 9.8h6M9 14.2h6"/><path d="M5.6 8.2a6 6 0 0 0 0 7.6M18.4 8.2a6 6 0 0 1 0 7.6" ${DOTS}/>`),
  theatre: ic(`<path d="M7.5 15.8h9M9.5 12.4h5"/><path d="M5 10.4a8 8 0 0 1 14 0" ${DOTS}/>`),
  spoff: ic('<circle class="f" cx="12" cy="12" r="3.3"/><path d="M6.4 8a6.5 6.5 0 0 0 0 8M17.6 8a6.5 6.5 0 0 1 0 8"/>'),
  personal: ic(`<path d="M12 4.5v15"/><path d="M8.5 7.6v9M15.5 7.6v9M5 10.6v3M19 10.6v3" ${DOTS}/>`),
  eq: ic(`<path d="M9.5 9v7M13 6v12"/><path d="M6 12.4v3M16.5 9.4v5.4M20 8v1" ${DOTS}/>`),
  hand: ic(`<path d="M10.2 12.5V7.3a1.5 1.5 0 0 1 3 0v4.2l3.9.9a2 2 0 0 1 1.5 2.3l-.7 4.3h-6.2l-3.6-4.6a1.3 1.3 0 0 1 2-1.6"/><path d="M6.2 9.6a5.6 5.6 0 0 1 3-5.6" ${DOTS}/>`),
  layers: ic('<path d="M12 5.2l8 3.9-8 3.9-8-3.9z"/><path d="M4 13.3l8 3.9 8-3.9"/>'),
  gear: ic('<circle cx="12" cy="12" r="2.6"/><circle cx="12" cy="12" r="6.2"/><circle cx="12" cy="12" r="8.3" stroke-dasharray="2.2 3" stroke-width="2.6" stroke-linecap="butt"/>'),
  info: ic('<circle cx="12" cy="12" r="8"/><path d="M12 11.2v5"/><circle class="f" cx="12" cy="7.9" r="1"/>'),
  download: ic('<rect x="4.5" y="4.5" width="15" height="15" rx="3.5"/><path d="M12 8.3v6.4M9.3 12.2l2.7 2.7 2.7-2.7"/>'),
  power: ic('<path d="M12 4v7.5"/><path d="M7.6 7.2a7 7 0 1 0 8.8 0"/>'),
  pin: ic('<path d="M12 20.2s6.2-5.4 6.2-10.2a6.2 6.2 0 0 0-12.4 0c0 4.8 6.2 10.2 6.2 10.2z"/><circle cx="12" cy="10" r="2.1"/>'),
  unlink: ic('<path d="M5.5 18.5l13-13"/><rect x="4.5" y="4.5" width="6.2" height="6.2" rx="2.6"/><rect x="13.3" y="13.3" width="6.2" height="6.2" rx="2.6"/>'),
  film: ic('<rect x="3.8" y="5.8" width="16.4" height="12.4" rx="2.6"/><path d="M7.4 8.8v6.4M16.6 8.8v6.4" stroke-dasharray="0.01 2.1" stroke-width="1.9"/><path d="M11 12h2"/>'),
  chat: ic(`<path d="M5 6.5h14a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1-1.5 1.5H10l-4 3v-3H5A1.5 1.5 0 0 1 3.5 15V8A1.5 1.5 0 0 1 5 6.5z"/><path d="M7.6 11.5h9" ${DOTS}/>`),
  help: ic('<rect x="6.5" y="5" width="11" height="14" rx="2.5"/><path d="M12 11.5v4M3.8 7.5v9M20.2 7.5v9"/><circle class="f" cx="12" cy="8.6" r=".9"/>'),
  manual: ic('<rect x="4" y="5" width="16" height="13.5" rx="2.5"/><path d="M4 9.2h16M7.5 12.8h4M7.5 15.5h3"/><circle cx="15.8" cy="14.2" r="1.6"/>'),
  shield: ic('<path d="M12 4l7 2.6v5.2c0 4.2-3 7-7 8.4-4-1.4-7-4.2-7-8.4V6.6z"/><path d="M9.2 12.2l2 2 3.6-3.8"/>'),
  heart: ic('<path d="M12 18.8l-6.3-6a3.9 3.9 0 0 1 5.5-5.5l.8.8.8-.8a3.9 3.9 0 0 1 5.5 5.5z"/>'),
  bell: ic('<path d="M6.5 16.5v-5.3a5.5 5.5 0 0 1 11 0v5.3zM4.8 16.5h14.4M10.3 19.5h3.4"/>'),
  wave: ic('<path d="M12 5v14M8.8 6.5v11M15.2 6.5v11M5.6 9v6M18.4 9v6"/>'),
  timer: ic('<circle cx="12" cy="13" r="6.5"/><path d="M12 9.8V13l2 1.4M9.8 4h4.4"/>'),
  mute: ic('<path d="M4.5 10h2.8L11 7v10l-3.7-3H4.5z"/><path d="M15 10l4 4M19 10l-4 4"/>'),
  quiet: ic('<circle cx="12" cy="12" r="7.5"/><path d="M9 10l1.6 1M15 10l-1.6 1M9.5 15.2c1.6-1.2 3.4-1.2 5 0"/>'),
  mac: ic('<rect x="5.5" y="6" width="13" height="9" rx="1.6"/><path d="M3.5 18h17"/>'),
  headphone: ic('<path d="M5 15v-3a7 7 0 0 1 14 0v3"/><rect x="3.8" y="13" width="3.6" height="6.4" rx="1.6"/><rect x="16.6" y="13" width="3.6" height="6.4" rx="1.6"/>'),
  g1: ic('<circle class="f" cx="12" cy="12" r="1.7"/>'),
  gHold: ic('<circle class="f" cx="5.5" cy="12" r="1.7"/><path d="M10 12h10"/>'),
  g2: ic('<circle class="f" cx="9.5" cy="13.5" r="1.6"/><circle class="f" cx="14.5" cy="10" r="1.6"/>'),
  g3: ic('<circle class="f" cx="7.5" cy="15.5" r="1.6"/><circle class="f" cx="12" cy="12" r="1.6"/><circle class="f" cx="16.5" cy="8.5" r="1.6"/>'),
  gScroll: ic('<path d="M5 13.5l3.5-2M19 13.5l-3.5-2"/><circle class="f" cx="12" cy="11" r="1.5"/>'),
  gSlider: ic('<path d="M5 12h14M12 5.5v3M12 15.5v3"/>'),
};

// Visuels par couleur. Ceux de `assets/products/` viennent du dossier récupéré sur le site (haute définition) ;
// la vue de face du Headphone Pro gris foncé est celle de l'app mobile.
const P = 'assets/products/';
const COLORS = {
  hp: [['Gris foncé', '#2D2F36', 'assets/headphone-pro.png'], ['Gris clair', '#D5D6D4', `${P}cmf-headphone-pro-light-grey.png`], ['Vert clair', '#A8D2C6', `${P}cmf-headphone-pro-light-green.png`]],
  'ear-a': [['Blanc', '#F4F4F4', `${P}ear-a-white.png`], ['Noir', '#1D1D1D', `${P}ear-a-black.png`], ['Jaune', '#F3CF1D', `${P}ear-a-yellow.png`]],
};
const img = (d) => COLORS[d.id][d.color][2];

const EAR_A = {
  id: 'ear-a', name: 'Ear (a)', color: 0, connected: true,
  battery: { G: 82, D: 78, 'Boîtier': 64 },
  feat: ['anc', 'eq', 'lowlat', 'dual', 'settings', 'about'], serial: '—', mac: '—', fw: '—',
};

const S = {
  theme: 'auto', route: ['home'], modal: null, overlay: null, pop: false, hud: null, tab: 'nothing',
  dev: 'hp',
  devices: [{
    id: 'hp', name: 'CMF Headphone Pro', short: 'Headphone Pro', color: 0, connected: true, battery: 45,
    feat: ['anc', 'spatial', 'personal', 'eq', 'controls', 'lowlat', 'dual', 'settings', 'about'],
    serial: 'CI0000000000000000', mac: '00:00:00:00:00:00', fw: '1.0.1.49',
  }],
  anc: { mode: 'anc', level: 'haut' }, spatial: 'concert',
  eq: 'pop', custom: { mid: 0, bass: 0, treble: 0 },
  lowLat: false, dual: true, fw: 'idle',
  dualList: [
    { n: 'MacBook Pro', s: 'Actuellement', on: true, lock: true },
    { n: 'Xiaomi 15T Pro', on: true }, { n: 'Xiaomi Pad 5', on: false }, { n: 'Freebox Player POP', on: false },
  ],
  ctl: { single: 'Assistant vocal', hold: 'Aucune action', slider: 'Réglage des basses', wheel: ['Mode transparence', 'Réduction du bruit'] },
  codec: 'AAC', standby: '30 minutes',
  mac: { menubar: true, login: true, hud: true },
};

const dev = () => S.devices.find((d) => d.id === S.dev);
const pct = (d) => (typeof d.battery === 'number' ? d.battery : Math.min(...Object.values(d.battery)));
const LEVELS = { bas: 'Bas', moyen: 'Moyen', haut: 'Haut', adaptatif: 'Adaptatif' };
const ANC_MODES = [['anc', 'Réduction du bruit', 'anc'], ['transp', 'Mode transparence', 'transp'], ['off', 'Désactiver', 'ancoff']];
const SPATIAL = [['concert', 'Mode concert', 'concert'], ['theatre', 'Mode théâtre', 'theatre'], ['off', 'Désactiver', 'spoff']];
const BUTTON_ACTIONS = ['Assistant vocal', 'Contrôle du bruit', 'Audio spatial', 'Micro activé/coupé', 'Aucune action'];

const EQ = {
  pop: { label: 'Pop', v: { mid: 4, bass: 1, treble: 1 } },
  rock: { label: 'Rock', v: { mid: -1, bass: 4, treble: 3 } },
  electro: { label: 'Électronique', v: { mid: -3, bass: 5, treble: 4 } },
  voice: { label: 'Améliorer les voix', v: { mid: 5, bass: -3, treble: -1 } },
  classic: { label: 'Classique', v: { mid: 1, bass: -1, treble: 4 } },
  custom: { label: 'Personnalisé' },
};
const AX = { mid: { x: 0, y: -1, label: 'Médiums' }, bass: { x: -0.866, y: 0.5, label: 'Graves' }, treble: { x: 0.866, y: 0.5, label: 'Aigus' } };
const CX = 160, CY = 170;
const lobeDist = (v) => 42 + v * 6;
const eqValues = () => (S.eq === 'custom' ? S.custom : EQ[S.eq].v);

const CATALOG = {
  nothing: [['ear-open', 'Ear (open)'], ['ear', 'Ear'], ['ear-a', 'Ear (a)'], ['ear-1', 'Ear (1)'], ['ear-2', 'Ear (2)'], ['ear-stick', 'Ear (stick)'], ['headphone-1', 'Headphone (1)'], ['headphone-1-pro', 'Headphone (1) Pro'], ['ear-3', 'Ear (3)'], ['headphone-a', 'Headphone (a)'], ['ear-3a', 'Ear (3a)']],
  cmf: [['buds-pro-2', 'Buds Pro 2'], ['buds', 'Buds'], ['neckband-pro', 'Neckband Pro'], ['buds-pro', 'Buds Pro'], ['buds-2', 'Buds 2'], ['buds-2a', 'Buds 2a'], ['buds-2-plus', 'Buds 2 Plus'], ['watch-pro', 'Watch Pro'], ['watch-pro-2', 'Watch Pro 2'], ['watch-3-pro', 'Watch 3 Pro'], ['cmf-headphone-pro', 'Headphone Pro'], ['buds-neo', 'CMF Buds Neo'], ['clip-pro', 'Clip Pro']],
};

// ---------- Briques ----------
const chev = `<span class="chev">${I.chev}</span>`;
const tog = (on) => `<span class="tog ${on ? 'on' : ''}"></span>`;
const check = (on) => `<span class="check ${on ? 'on' : ''}">${I.check}</span>`;
const radio = (on) => `<span class="radio ${on ? 'on' : ''}"></span>`;
const act = (a, arg) => (a ? `data-act="${a}"${arg !== undefined ? ` data-arg="${arg}"` : ''}` : '');

function row({ icon, title, sub, right = '', a, arg, cls = '' }) {
  const tag = a ? 'button' : 'div';
  return `<${tag} class="row ${cls}" ${act(a, arg)}>${icon ? `<span class="row-ic">${icon}</span>` : ''}<span class="row-main"><span class="row-t">${title}</span>${sub ? `<span class="row-s">${sub}</span>` : ''}</span>${right}</${tag}>`;
}
const group = (rows) => `<div class="group">${rows.join('')}</div>`;
const page = (title, body, lede) => `<div class="page"><h2 class="serif">${title}</h2>${lede ? `<p class="lede">${lede}</p>` : ''}${body}</div>`;
const radioList = (key, options) => group(options.map((o) => row({ title: o, right: radio(get(key) === o), a: 'set', arg: `${key}|${o}` })));

function get(path) { return path.split('.').reduce((o, k) => o[k], S); }
function set(path, value) {
  const keys = path.split('.'); const last = keys.pop();
  keys.reduce((o, k) => o[k], S)[last] = value;
}

function modes(list, current, action) {
  return `<div class="modes">${list.map(([id, label, icon]) => `<button class="mode ${current === id ? 'on' : ''}" ${act(action, id)}><span class="mode-dot">${I[icon]}</span>${label}</button>`).join('')}</div>`;
}
function ancCard() {
  const a = S.anc;
  const sub = a.mode === 'anc' ? `Activée · ${LEVELS[a.level]}` : a.mode === 'transp' ? 'Mode transparence' : 'Désactivée';
  return `<section class="card"><div class="card-head"><div><h3>Réduction du bruit</h3><p>${sub}</p></div></div>
    ${modes(ANC_MODES, a.mode, 'anc')}
    <div class="levels ${a.mode === 'anc' ? '' : 'idle'}">${Object.entries(LEVELS).map(([id, l]) => `<button class="lvl ${a.level === id ? 'on' : ''}" ${act('level', id)}><i></i>${l}</button>`).join('')}</div>
  </section>`;
}

// ---------- Égaliseur ----------
function eqSvg() {
  const dots = Object.values(AX).map((a) => [38, 74, 110].map((r) => `<circle class="axis-dot" cx="${CX + a.x * r}" cy="${CY + a.y * r}" r="2.2"/>`).join('')).join('');
  const lobes = Object.keys(AX).map((k) => `<circle class="lobe" data-lobe="${k}" cx="${CX}" cy="${CY}" r="36"/>`).join('');
  const handles = Object.keys(AX).map((k) => `<circle class="handle" data-axis="${k}" cx="${CX}" cy="${CY}" r="9" stroke="transparent" stroke-width="18"/>`).join('');
  return `<svg id="eqsvg" viewBox="0 0 320 320" role="img" aria-label="Courbe d'égalisation : médiums, graves, aigus">
        <defs><filter id="goo" x="-20%" y="-20%" width="140%" height="140%" color-interpolation-filters="sRGB">
          <feGaussianBlur in="SourceGraphic" stdDeviation="9" result="b"/>
          <feColorMatrix in="b" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 22 -9" result="shape"/>
          <feComponentTransfer in="shape" result="inv"><feFuncA type="table" tableValues="1 0"/></feComponentTransfer>
          <feGaussianBlur in="inv" stdDeviation="5" result="invb"/>
          <feOffset in="invb" dy="2" result="invo"/>
          <feFlood style="flood-color:var(--blob-shadow)" result="col"/>
          <feComposite in="col" in2="invo" operator="in" result="sh"/>
          <feComposite in="sh" in2="shape" operator="in" result="inner"/>
          <feMerge><feMergeNode in="shape"/><feMergeNode in="inner"/></feMerge>
        </filter></defs>
        <circle class="disc" cx="160" cy="160" r="156"/>
        <g filter="url(#goo)"><circle class="lobe" cx="${CX}" cy="${CY}" r="46"/>${lobes}</g>
        ${dots}<circle class="core" cx="${CX}" cy="${CY}" r="9"/>
        <text data-label="mid" x="160" y="30"></text>
        <text data-label="bass" transform="translate(44 236) rotate(60)"></text>
        <text data-label="treble" transform="translate(276 236) rotate(-60)"></text>
        ${handles}
      </svg>`;
}
const eqPresets = () => Object.entries(EQ).map(([id, p]) => `<button class="preset" data-preset="${id}" ${act('eq', id)}>${p.label}</button>`).join('');

function updateEq() {
  const svg = $('#eqsvg'); if (!svg) return;
  const v = eqValues(); const custom = S.eq === 'custom';
  svg.classList.toggle('custom', custom);
  for (const k of Object.keys(AX)) {
    const a = AX[k]; const dist = lobeDist(v[k]);
    svg.querySelector(`[data-lobe="${k}"]`).style.transform = `translate(${a.x * dist}px, ${a.y * dist}px)`;
    svg.querySelector(`[data-axis="${k}"]`).style.transform = `translate(${a.x * (dist + 34)}px, ${a.y * (dist + 34)}px)`;
    svg.querySelector(`[data-label="${k}"]`).textContent = custom ? `${a.label} ${v[k] > 0 ? '+' : ''}${v[k]}` : a.label;
  }
  document.querySelectorAll('.preset').forEach((b) => b.classList.toggle('on', b.dataset.preset === S.eq));
}
function bindEq() {
  const svg = $('#eqsvg');
  svg.querySelectorAll('.handle').forEach((h) => {
    h.addEventListener('pointerdown', (e) => {
      h.setPointerCapture(e.pointerId); svg.classList.add('drag');
      const k = h.dataset.axis; const a = AX[k];
      const move = (ev) => {
        const p = new DOMPoint(ev.clientX, ev.clientY).matrixTransform(svg.getScreenCTM().inverse());
        const along = (p.x - CX) * a.x + (p.y - CY) * a.y;
        S.custom[k] = Math.max(-6, Math.min(6, Math.round((along - 34 - 42) / 6)));
        updateEq();
      };
      const up = () => { svg.classList.remove('drag'); h.removeEventListener('pointermove', move); h.removeEventListener('pointerup', up); };
      h.addEventListener('pointermove', move); h.addEventListener('pointerup', up);
    });
  });
}

// ---------- Fenêtres modales communes ----------
const MODALS = {
  spatial: () => `<div class="dialog"><h3>Plongez dans l'audio spatial</h3><p>Une expérience d'écoute immersive qui vous plonge dans votre musique, votre film ou votre jeu.</p>
    <svg class="art" viewBox="0 0 300 190" fill="none" stroke="currentColor" stroke-width="1.1" aria-hidden="true">
      <circle cx="150" cy="100" r="36" fill="var(--text)" stroke="none"/><path d="M166 66l14 -4 -2 15z" fill="var(--text)" stroke="none"/>
      <ellipse cx="46" cy="100" rx="6" ry="44"/><ellipse cx="32" cy="100" rx="4" ry="26"/><ellipse cx="22" cy="100" rx="2.5" ry="14"/>
      <g transform="rotate(32 236 40)"><ellipse cx="236" cy="48" rx="44" ry="7"/><ellipse cx="236" cy="36" rx="26" ry="5"/><ellipse cx="236" cy="27" rx="14" ry="3"/></g>
      <g transform="rotate(-32 236 160)"><ellipse cx="236" cy="152" rx="44" ry="7"/><ellipse cx="236" cy="164" rx="26" ry="5"/><ellipse cx="236" cy="173" rx="14" ry="3"/></g>
    </svg>
    <button class="pill wide" ${act('closeModal')}>OK</button></div>`,
  forget: () => `<div class="dialog"><h3>Oublier ${dev().name} ?</h3><p>L'appareil sera retiré de Nothing X sur ce Mac. Vous pourrez l'ajouter de nouveau en le mettant en mode d'appairage.</p>
    <div class="btns"><button class="pill" ${act('closeModal')}>Annuler</button><button class="pill red" ${act('forget')}>Oublier</button></div></div>`,
  fwdone: () => `<div class="dialog"><h3>Mise à jour terminée</h3><p>Votre ${dev().short || dev().name} a bien été mis à jour vers la version du firmware ${dev().fw}</p><button class="pill dark wide" ${act('closeModal')}>Confirmer</button></div>`,
  guide: () => `<div class="dialog guide"><div class="guide-head"><h3>Guide de connexion</h3><button ${act('closeModal')} aria-label="Fermer">${I.close}</button></div>
    <div class="tabs"><button class="tab ${S.tab === 'nothing' ? 'on' : ''}" ${act('tab', 'nothing')}>Nothing</button><button class="tab ${S.tab === 'cmf' ? 'on' : ''}" ${act('tab', 'cmf')}>CMF</button></div>
    <div class="catalog">${CATALOG[S.tab].map(([f, n]) => `<div class="prod"><img src="assets/cat-${f}.png" alt="">${n}</div>`).join('')}</div></div>`,
};
function renderModal() { $('#modal').innerHTML = S.modal ? MODALS[S.modal]() : ''; }

