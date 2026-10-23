// Lot C7-PLAN : dessine le plan de masse du village v2 (vu de dessus, nord en haut = -Z) sur le relief réel.
//   1) godot --headless --path . --script res://outils/plan_village_relief.gd -- --sortie=res://captures/relief_c7_carte.txt
//   2) bun outils/plan_village_dessin.mjs captures/relief_c7_carte.txt <sortie.png>
// Coordonnées : mètres monde (x vers l'est, z vers le SUD). Toutes les valeurs sont celles de docs/PLAN_VILLAGE_V2.md.
import { chromium } from '/home/lopezk19/node_modules/playwright/index.mjs';

const [fichier = 'captures/relief_c7_carte.txt', sortie = 'docs/plan_village_v2.png'] = process.argv.slice(2);
const lignes = (await Bun.file(fichier).text()).trim().split('\n');
const grille = lignes.slice(1).map((l) => l.split(',').map(Number)); // grille[z+110][x+110]

// ---------------------------------------------------------------- cadre
const S = 7, X0 = -30, X1 = 110, Z0 = -42, Z1 = 98, OX = 20, OY = 64;
const W = 1640, Hh = OY + (Z1 - Z0) * S + 24;
const px = (x) => OX + (x - X0) * S, pz = (z) => OY + (z - Z0) * S;
const P = (p) => `${px(p[0]).toFixed(1)},${pz(p[1]).toFixed(1)}`;

// ---------------------------------------------------------------- données du plan (identiques au document)
const palissade = [[20, 34], [27.7, 25.2], [36, 15], [54, 14.3], [60, 14], [72, 24], [73.5, 36], [74, 48], [66, 56], [65, 61.5], [63, 68], [60, 91], [32, 91], [28, 68], [23, 67], [19.5, 61.5], [15, 52]];
const portes = [
  { p: [27.7, 25.2], n: 'PORTE SO (inchangée)' }, { p: [54, 14.3], n: 'porte N' }, { p: [73.5, 36], n: 'porte E' },
];
const grilles = [{ p: [65, 61.5], n: 'grille E' }, { p: [19.5, 61.5], n: 'grille O' }];
const riviere = [[90, 57], [86, 58], [80, 59], [74, 60], [68, 61], [60, 61.5], [50, 61.5], [44, 61.5], [34, 61], [26, 61], [22, 61], [17, 61], [12, 61]];
const larg_riv = [2.5, 3, 3, 3.5, 4, 4.5, 5, 5, 5, 5, 4, 4, 4];
const place = [[31, 28], [52, 27.5], [56, 33], [55, 45], [46, 48.5], [33, 46.5], [30, 38]];
const rues = [ // [points, largeur, type]
  [[[27.7, 25.2], [33, 30], [38, 32.5]], 4, 'pave'],          // rue principale porte SO → place
  [[[44, 48.5], [44, 57]], 3.6, 'pave'],                       // place → pont
  [[[53, 27.5], [54, 14.3]], 3.2, 'pave'],                     // place → porte N
  [[[55.5, 37], [73.5, 36]], 3.2, 'pave'],                     // place → porte E
  [[[33, 46.5], [30, 55], [26, 58]], 2.6, 'pave'],             // place → moulin à eau / quai
  [[[54, 14.3], [53, 4], [53, -8], [54, -18], [53, -26.5]], 3, 'terre'],   // vers la piste de la grotte
  [[[53, -26.5], [60, -27.5], [70, -26], [80, -27.3], [89, -27]], 4, 'piste'], // piste existante de la grotte (inchangée)
  [[[73.5, 36], [80, 35.5], [91, 32]], 2.6, 'terre'],         // vers les champs et le moulin à vent
  [[[80, 35.5], [82, 27]], 2.2, 'terre'],                      // ferme A
  [[[53, 4], [58, 4]], 2.2, 'terre'],                          // ferme B
  [[[5, 4.6], [27.7, 25.2]], 2.6, 'dalles'],                   // sentier feu → porte (inchangé, kit AbordsVillage)
];
const escaliers = [ // [x, z début, z fin, largeur, hauteur gagnée]
  [44, 67, 71, 3, 2.4], [44, 73, 77, 3, 2.8], [44, 79, 83, 3, 3.2],
];
const terrasses = [ // [x0, z0, x1, z1, h, nom]
  [39, 71, 50, 73, 6.0, 'T1 6,0 m'], [39, 77, 51, 79, 8.8, 'T2 8,8 m'], [37, 83, 55, 91, 12.0, 'T3 12,0 m'],
];
// bâtiments : [id, nom, cx, cz, w (x), d (z), rot°, genre]  genre : int (intérieur), fac (façade seule), spe (spécial)
const batis = [
  ['I1', 'Longue maison (halle, cheffe)', 44, 21, 14, 7, 0, 'int'],
  ['I2', 'Forge ouverte', 27, 36, 7, 6, 0, 'int'],
  ['I3', 'Maison de Grima', 28, 47.5, 5, 7, 0, 'int'],
  ['I4', 'Maison des chasseurs', 63, 29, 5.5, 8, 0, 'int'],
  ['I5', 'Maison de Sigrún', 60, 47, 8, 5.5, 0, 'int'],
  ['H1', 'maison', 35, 53, 7, 5, 0, 'fac'],
  ['H2', 'maison', 54, 55.5, 6, 4.5, 0, 'fac'],
  ['H3', 'maison (T1)', 35.5, 72, 6, 5, 0, 'fac'],
  ['H4', 'maison (T2)', 54, 77.5, 6, 5, 0, 'fac'],
  ['H5', 'maison (T3)', 32.5, 84, 6, 5, 0, 'fac'],
  ['H6', 'grenier', 60, 20.5, 7, 5, 30, 'fac'],
  ['M', 'Moulin à eau', 25.5, 55.5, 6, 6, 0, 'spe'],
  ['T', 'Tour-clocher', 45, 87.5, 5, 5, 0, 'spe'],
  ['FA', 'Ferme A', 83, 21.5, 9, 6, 0, 'fac'],
  ['GA', 'grange A', 89.5, 23, 5, 7, 0, 'fac'],
  ['FB', 'Ferme B', 61, 3.5, 8, 5, 0, 'fac'],
  ['GB', 'grange B', 67.5, 6, 5, 6, 0, 'fac'],
];
const champs = [
  [[77, 29], [90, 28], [90, 39.5], [77, 39.5]],
  [[76, 41.5], [86, 41.5], [86, 50], [76, 50]],
  [[57, -11], [70, -11], [70, -3], [57, -3]],
];
const pnj = [ // [nom, x, z, poste]
  ['Gunnhild (cheffe)', 44, 26, 'longue_maison'], ['Brodd (forgeron)', 25.2, 37.6, 'forge'],
  ['Ylva (chasseuse)', 66, 38.5, 'enclos'], ['Sigrún (völva)', 39.5, 42, 'place'],
  ['Haldor (garde)', 30.5, 28.4, 'porte'], ['Grima (doyenne)', 44.6, 39.6, 'puits'],
];
const promenade = [[44, 26], [39.5, 42], [44.6, 39.6], [30.5, 28.4], [66, 38.5], [44, 55], [34, 58], [27, 59.5]];
const vues = [ // [n°, x, z, dx, dz]
  [1, 19, 17.5, 0.74, 0.67], [2, 42, 29.5, 0, 1], [3, 41, 64.5, 0.2, 1], [4, 23, 64.5, 1, -0.05], [5, 35.5, 40.5, -0.9, -0.45], [6, 75, 40, 1, -0.12],
];

// ---------------------------------------------------------------- SVG
let s = '';
const txt = (x, y, t, o = {}) => { s += `<text x="${x}" y="${y}" font-size="${o.t || 12}" fill="${o.c || '#1b2230'}" font-weight="${o.g ? 700 : 400}" text-anchor="${o.a || 'start'}" ${o.h ? 'paint-order="stroke" stroke="#f4f1ea" stroke-width="3.2"' : ''} font-family="DejaVu Sans, Arial">${t}</text>`; };
const ligne = (pts, st) => { s += `<polyline points="${pts.map(P).join(' ')}" fill="none" ${st}/>`; };

// zone témoin interdite
s += `<rect x="${px(-58)}" y="${pz(-64)}" width="${(4 + 58) * S}" height="${(4 + 64) * S}" fill="url(#hach)" stroke="#a33" stroke-width="1.5" stroke-dasharray="6 4"/>`;
txt(px(-28), pz(-36), 'ZONE TÉMOIN (interdite)', { c: '#902a2a', g: 1, h: 1 });
// ancien village (repère)
s += `<circle cx="${px(44)}" cy="${pz(40)}" r="${22 * S}" fill="none" stroke="#b03030" stroke-width="1.6" stroke-dasharray="3 5"/>`;
// champs
for (const c of champs) s += `<polygon points="${c.map(P).join(' ')}" fill="url(#sillons)" stroke="#6b4a2a" stroke-width="2" stroke-dasharray="5 3"/>`;
// rues
for (const [pts, l, g] of rues) {
  const coul = { pave: '#8d877f', terre: '#9c7d5c', piste: '#a58f74', dalles: '#7f7a76' }[g];
  ligne(pts, `stroke="${coul}" stroke-width="${l * S}" stroke-linecap="round" stroke-linejoin="round" opacity="0.92"`);
  if (g === 'pave' || g === 'dalles') ligne(pts, `stroke="#5f5a55" stroke-width="${l * S}" stroke-dasharray="2 5" opacity="0.35"`);
}
s += `<polygon points="${place.map(P).join(' ')}" fill="#8d877f" stroke="#4d4843" stroke-width="2"/>`;
s += `<polygon points="${place.map(P).join(' ')}" fill="url(#paves)" opacity="0.6"/>`;
// terrasses + escaliers
for (const [a, b, c, d, h, n] of terrasses) {
  s += `<rect x="${px(a)}" y="${pz(b)}" width="${(c - a) * S}" height="${(d - b) * S}" fill="#97918a" stroke="#4d4843" stroke-width="1.5"/>`;
  if (n.startsWith('T3')) txt(px(48), pz(90.2), n, { t: 10, g: 1, h: 1 }); else txt(px(45.8), pz(b) + 11, n.slice(3), { t: 9.5, g: 1, h: 1 });
}
for (const [x, a, b, l] of escaliers) {
  s += `<rect x="${px(x - l / 2)}" y="${pz(a)}" width="${l * S}" height="${(b - a) * S}" fill="#b9b2a8" stroke="#3d3833" stroke-width="1.5"/>`;
  for (let z = a + 0.4; z < b; z += 0.4) s += `<line x1="${px(x - l / 2)}" y1="${pz(z)}" x2="${px(x + l / 2)}" y2="${pz(z)}" stroke="#3d3833" stroke-width="0.8"/>`;
}
// rivière
for (let i = 0; i < riviere.length - 1; i++) ligne([riviere[i], riviere[i + 1]], `stroke="#3c78b4" stroke-width="${((larg_riv[i] + larg_riv[i + 1]) / 2) * S}" stroke-linecap="round"`);
ligne(riviere, `stroke="#9cc6ea" stroke-width="1.6" stroke-dasharray="7 6"`);
s += `<path d="M${P([90.5, 54])} L${P([94, 55])} L${P([94.5, 60])} L${P([90.5, 60.5])} Z" fill="#6f6862" stroke="#2c2724" stroke-width="1.5"/>`;
txt(px(89), pz(64.5), 'SOURCE : cascade', { t: 11, g: 1, c: '#174e86', a: 'middle', h: 1 });
txt(px(89), pz(64.5) + 13, 'du rocher (15 → 12 m)', { t: 11, c: '#174e86', a: 'middle', h: 1 });
s += `<circle cx="${px(86.5)}" cy="${pz(58)}" r="${2.2 * S}" fill="#3c78b4" stroke="#174e86"/>`;
// gué
s += `<rect x="${px(77)}" y="${pz(57)}" width="${2.4 * S}" height="${4 * S}" fill="none" stroke="#6b5a45" stroke-width="2" stroke-dasharray="2 2"/>`;
txt(px(77) - 2, pz(56) - 2, 'gué', { t: 10, h: 1, a: 'end' });
// pont, quai, moulin à eau
s += `<rect x="${px(42.4)}" y="${pz(57)}" width="${3.2 * S}" height="${9 * S}" fill="#a8a196" stroke="#2f2b27" stroke-width="2.2"/>`;
s += `<path d="M${P([42.4, 59])} Q${P([41.2, 61.5])} ${P([42.4, 64])} M${P([45.6, 59])} Q${P([46.8, 61.5])} ${P([45.6, 64])}" fill="none" stroke="#2f2b27" stroke-width="1.6"/>`;
s += `<rect x="${px(29)}" y="${pz(57.2)}" width="${9 * S}" height="${2.2 * S}" fill="#8a5f38" stroke="#3a2715" stroke-width="1.5"/>`;
for (let x = 29.5; x < 38; x += 1.4) s += `<line x1="${px(x)}" y1="${pz(57.2)}" x2="${px(x)}" y2="${pz(59.4)}" stroke="#3a2715" stroke-width="0.8"/>`;
s += `<circle cx="${px(21.5)}" cy="${pz(61)}" r="${1.6 * S}" fill="#7a5530" stroke="#2a1a0c" stroke-width="2"/>`;
s += `<line x1="${px(20)}" y1="${pz(61)}" x2="${px(23)}" y2="${pz(61)}" stroke="#2a1a0c" stroke-width="1.5"/>`;
txt(px(18.5), pz(65.5), 'roue Ø3,2 + petite cascade 2,5 m', { t: 10, h: 1, a: 'end' });
// palissade
s += `<polygon points="${palissade.map(P).join(' ')}" fill="none" stroke="#4a2f17" stroke-width="5" stroke-linejoin="round"/>`;
s += `<polygon points="${palissade.map(P).join(' ')}" fill="none" stroke="#c9a173" stroke-width="2" stroke-dasharray="1.5 4"/>`;
for (const g of portes) {
  s += `<rect x="${px(g.p[0]) - 13}" y="${pz(g.p[1]) - 13}" width="26" height="26" fill="#f4f1ea" stroke="#4a2f17" stroke-width="2.5" rx="3"/>`;
  s += `<path d="M${px(g.p[0]) - 7},${pz(g.p[1]) + 6} v-9 a7,7 0 0 1 14,0 v9" fill="none" stroke="#4a2f17" stroke-width="2.2"/>`;
}
txt(px(27.7) - 18, pz(25.2) - 10, 'PORTE SO (inchangée)', { t: 11, g: 1, a: 'end', h: 1 });
txt(px(54) + 16, pz(14.3) - 10, 'porte N (grotte)', { t: 11, g: 1, h: 1 });
txt(px(73.5) + 16, pz(36) + 18, 'porte E (fermes)', { t: 11, g: 1, h: 1 });
for (const g of grilles) {
  s += `<rect x="${px(g.p[0]) - 6}" y="${pz(g.p[1]) - 18}" width="12" height="36" fill="url(#grille)" stroke="#2a1a0c" stroke-width="1.5"/>`;
}
txt(px(65) + 9, pz(61.5) + 30, 'grille d’eau', { t: 10, h: 1 });
txt(px(19.5) - 9, pz(61.5) - 22, 'grille d’eau', { t: 10, h: 1, a: 'end' });
// bâtiments
for (const [id, n, cx, cz, w, d, r, g] of batis) {
  const coul = { int: '#c0703a', fac: '#8e6c50', spe: '#6f7380' }[g];
  s += `<g transform="rotate(${r} ${px(cx)} ${pz(cz)})"><rect x="${px(cx - w / 2)}" y="${pz(cz - d / 2)}" width="${w * S}" height="${d * S}" fill="${coul}" stroke="#20160e" stroke-width="2"/>`;
  s += `<line x1="${px(cx - w / 2)}" y1="${pz(cz)}" x2="${px(cx + w / 2)}" y2="${pz(cz)}" stroke="#f0e6d8" stroke-width="1" opacity="${w >= d ? 0.7 : 0}"/>`;
  s += `<line x1="${px(cx)}" y1="${pz(cz - d / 2)}" x2="${px(cx)}" y2="${pz(cz + d / 2)}" stroke="#f0e6d8" stroke-width="1" opacity="${w < d ? 0.7 : 0}"/></g>`;
  txt(px(cx), pz(cz) + 4, id, { t: 12, g: 1, a: 'middle', c: '#fff' });
}
// moulin à vent
s += `<circle cx="${px(94)}" cy="${pz(31)}" r="${2.5 * S}" fill="#6f7380" stroke="#20160e" stroke-width="2"/>`;
s += `<g stroke="#3a2715" stroke-width="3"><line x1="${px(89.8)}" y1="${pz(26.8)}" x2="${px(98.2)}" y2="${pz(35.2)}"/><line x1="${px(98.2)}" y1="${pz(26.8)}" x2="${px(89.8)}" y2="${pz(35.2)}"/></g>`;
txt(px(94), pz(31) + 4, 'MV', { t: 11, g: 1, a: 'middle', c: '#fff' });
// mobilier
const rond = (x, z, r, f, st = '#20160e') => { s += `<circle cx="${px(x)}" cy="${pz(z)}" r="${r}" fill="${f}" stroke="${st}" stroke-width="1.5"/>`; };
rond(42, 38, 1.7 * S, '#7d7a78'); s += `<rect x="${px(40.2)}" y="${pz(36.2)}" width="${3.6 * S}" height="${3.6 * S}" fill="none" stroke="#5a3a1c" stroke-width="2"/>`;
txt(px(42), pz(38) + 4, 'P', { t: 11, g: 1, a: 'middle', c: '#fff' });
for (const [x, z, r] of [[51.5, 30.5, 0], [54, 36.5, 90], [52.5, 42.5, 0]]) {
  s += `<g transform="rotate(${r} ${px(x)} ${pz(z)})"><rect x="${px(x - 1.5)}" y="${pz(z - 1)}" width="${3 * S}" height="${2 * S}" fill="url(#auvent)" stroke="#20160e" stroke-width="1.5"/></g>`;
}
for (const [x, z] of [[38, 28.5], [50, 28.5], [36, 46], [48, 47.5], [25.3, 23.8], [44, 66.5]]) { // bannières
  s += `<path d="M${px(x)},${pz(z) - 9} l7,0 l0,13 l-3.5,-3 l-3.5,3 z" fill="#9a2424" stroke="#3a0d0d" stroke-width="1"/>`;
}
for (const [x, z] of [[36, 39], [40.6, 72], [40.6, 78]]) { rond(x, z, 5.5, '#ff8c2a', '#7a2c00'); } // braseros
for (const [x, z] of [[24.2, 21.2], [17.6, 15.2], [46, 70.4], [46, 76.4], [41, 82.5], [42, 56], [46, 56], [30, 30]]) { // lanternes
  s += `<rect x="${px(x) - 3.5}" y="${pz(z) - 3.5}" width="7" height="7" fill="#ffd060" stroke="#6a4200" stroke-width="1.5" transform="rotate(45 ${px(x)} ${pz(z)})"/>`;
}
s += `<rect x="${px(61)}" y="${pz(37.5)}" width="${6 * S}" height="${5 * S}" fill="none" stroke="#5a3a1c" stroke-width="2" stroke-dasharray="4 2"/>`;
txt(px(64), pz(44.4), 'enclos/séchoirs', { t: 10, a: 'middle', h: 1 });
// clôtures du chemin d'entrée (18 derniers mètres)
const u = [0.74, 0.67], nrm = [-0.67, 0.74];
for (const c of [-2.1, 2.1]) ligne([[27.7 - u[0] * 3 + nrm[0] * c, 25.2 - u[1] * 3 + nrm[1] * c], [27.7 - u[0] * 21 + nrm[0] * c, 25.2 - u[1] * 21 + nrm[1] * c]], 'stroke="#5a3a1c" stroke-width="2.4" stroke-dasharray="6 2"');
// PNJ
for (const [n, x, z] of pnj) { rond(x, z, 5, '#e23b3b', '#fff'); }
for (const p of promenade) s += `<circle cx="${px(p[0])}" cy="${pz(p[1])}" r="2.5" fill="none" stroke="#e23b3b" stroke-width="1.2"/>`;
// vues de la planche
for (const [n, x, z, dx, dz] of vues) {
  const a = Math.atan2(dz, dx), L = 34;
  s += `<path d="M${px(x)},${pz(z)} L${px(x) + Math.cos(a - 0.45) * L},${pz(z) + Math.sin(a - 0.45) * L} A${L},${L} 0 0 1 ${px(x) + Math.cos(a + 0.45) * L},${pz(z) + Math.sin(a + 0.45) * L} Z" fill="#1e5fd0" opacity="0.28"/>`;
  rond(x, z, 9, '#1e5fd0', '#fff'); txt(px(x), pz(z) + 4.5, String(n), { t: 12, g: 1, a: 'middle', c: '#fff' });
}
// repères existants
rond(0, 0, 7, '#ff7a1a'); txt(px(0) + 10, pz(0) + 4, 'feu de camp (départ)', { t: 11, g: 1, h: 1 });
s += `<path d="M${px(0) - 8},${pz(0) - 8} L${px(-22)},${pz(-22)}" stroke="#1b2230" stroke-width="2" marker-end="url(#fl)"/>`;
txt(px(-22) + 4, pz(-25) - 4, '→ cercle (-38,-34), tertre/crypte (-38,-48)', { t: 11, g: 1, h: 1 });
txt(px(-22) + 4, pz(-25) + 10, 'chemin témoin INCHANGÉ', { t: 10, h: 1 });
s += `<path d="M${px(91)},${pz(-31)} l9,4 l0,8 l-9,4 z" fill="#2c2724"/>`;
txt(px(89), pz(-33), 'GROTTE (92,-27) inchangée', { t: 11, g: 1, a: 'end', h: 1 });
txt(px(68), pz(-23), 'piste de la grotte (existante)', { t: 10, a: 'middle', h: 1 });
txt(px(-6), pz(55), 'LAC fermé (C5)', { t: 13, g: 1, c: '#123e6c', a: 'middle', h: 1 });
txt(px(-6), pz(55) + 15, 'niveau -0,8 m', { t: 11, c: '#123e6c', a: 'middle', h: 1 });
// mur invisible
s += `<line x1="${px(108)}" y1="${pz(Z0)}" x2="${px(108)}" y2="${pz(Z1)}" stroke="#d01010" stroke-width="2.5" stroke-dasharray="10 5"/>`;
txt(px(107), pz(Z1) - 8, 'mur invisible x = 108', { t: 11, g: 1, c: '#c01010', a: 'end', h: 1 });
// étiquettes de zones
txt(px(43), pz(33.5), 'PLACE', { t: 15, g: 1, a: 'middle', h: 1 });
txt(px(57), pz(64.8), 'RIVIÈRE (5 m)', { t: 11, g: 1, c: '#123e6c', a: 'middle', h: 1 });
txt(px(50.5), pz(62), 'PONT en arche', { t: 10, g: 1, h: 1 });
txt(px(33.5), pz(56.6), 'QUAI', { t: 10, g: 1, a: 'middle', h: 1 });
txt(px(45), pz(92.5) + 10, 'TOUR-CLOCHER (sommet ≈ 31 m)', { t: 11, g: 1, a: 'middle', h: 1 });
txt(px(58), pz(84), 'RUE EN PENTE', { t: 11, g: 1, h: 1 });
txt(px(58), pz(84) + 13, '3 volées d’escaliers', { t: 10, h: 1 });
txt(px(58), pz(84) + 26, 'T1–T3 : terrasses', { t: 10, h: 1 });
txt(px(83.5), pz(51) + 12, 'CHAMPS + clôtures', { t: 11, g: 1, a: 'middle', h: 1 });
txt(px(97.5), pz(31) - 2, 'moulin', { t: 10, g: 1, h: 1 }); txt(px(97.5), pz(31) + 10, 'à vent', { t: 10, g: 1, h: 1 }); txt(px(97.5), pz(31) + 22, 'butte 12 m', { t: 10, h: 1 });
txt(px(63.5), pz(-11) - 4, 'champ', { t: 10, a: 'middle', h: 1 });
// échelle + nord
s += `<rect x="${px(-26)}" y="${pz(92)}" width="${20 * S}" height="6" fill="#1b2230"/><rect x="${px(-26)}" y="${pz(92)}" width="${10 * S}" height="6" fill="#f4f1ea" stroke="#1b2230"/>`;
txt(px(-26), pz(92) - 4, '0', { t: 10, h: 1 }); txt(px(-16), pz(92) - 4, '10', { t: 10, a: 'middle', h: 1 }); txt(px(-6), pz(92) - 4, '20 m', { t: 10, a: 'middle', h: 1 });
s += `<path d="M${px(-22)},${pz(78)} l9,24 l-9,-6 l-9,6 z" fill="#1b2230"/>`; txt(px(-22), pz(78) - 4, 'N', { t: 15, g: 1, a: 'middle', h: 1 });
// cadre
s += `<rect x="${OX}" y="${OY}" width="${(X1 - X0) * S}" height="${(Z1 - Z0) * S}" fill="none" stroke="#1b2230" stroke-width="2"/>`;
for (let x = -20; x <= 100; x += 20) txt(px(x), OY - 4, String(x), { t: 10, a: 'middle', c: '#556' });
for (let z = -40; z <= 90; z += 20) txt(OX + 3, pz(z) + 4, String(z), { t: 10, c: '#556', h: 1 });

// ---------------------------------------------------------------- légende
const LX = OX + (X1 - X0) * S + 26;
let leg = '';
const lt = (y, t, o = {}) => { leg += `<text x="${LX + (o.d || 0)}" y="${y}" font-size="${o.t || 12}" fill="${o.c || '#1b2230'}" font-weight="${o.g ? 700 : 400}" font-family="DejaVu Sans, Arial">${t}</text>`; };
let y = OY + 6;
lt(y, 'Légende', { t: 16, g: 1 }); y += 22;
const items = [
  ['#c0703a', 'I1–I5 : les 5 intérieurs sans chargement (déplacés)'],
  ['#8e6c50', 'H1–H6, fermes, granges : façades seules (portes closes)'],
  ['#6f7380', 'M moulin à eau · T tour-clocher · MV moulin à vent'],
  ['#8d877f', 'pavés (rues, place) · dalles du sentier d’entrée'],
  ['#9c7d5c', 'chemins de terre / gravier'],
  ['#3c78b4', 'rivière (source → lac), largeur réelle'],
  ['#e23b3b', 'poste d’un PNJ (cercles vides : promenade)'],
  ['#1e5fd0', '1–6 : point de vue de la planche (même numéro)'],
];
for (const [c, t] of items) { leg += `<rect x="${LX}" y="${y - 10}" width="14" height="12" fill="${c}" stroke="#20160e"/>`; lt(y, t, { d: 20, t: 11.5 }); y += 18; }
leg += `<line x1="${LX}" y1="${y - 4}" x2="${LX + 14}" y2="${y - 4}" stroke="#4a2f17" stroke-width="5"/>`; lt(y, 'palissade prolongée (228 m, 3 portes, 2 grilles d’eau)', { d: 20, t: 11.5 }); y += 18;
leg += `<line x1="${LX}" y1="${y - 4}" x2="${LX + 14}" y2="${y - 4}" stroke="#b03030" stroke-width="1.6" stroke-dasharray="3 3"/>`; lt(y, 'palissade actuelle (cercle de 22 m) pour comparer', { d: 20, t: 11.5 }); y += 18;
lt(y, '◆ lanterne · ● brasero · drapeau : bannière · P : puits couvert', { t: 11.5 }); y += 26;

lt(y, 'Le village en chiffres', { t: 15, g: 1 }); y += 20;
for (const t of [
  'Enceinte : ≈ 3 300 m² (aujourd’hui 1 520 m², ×2,2)',
  'Bas-village : plateau plat à 3,6 m (comme aujourd’hui)',
  'Haute rue : 3 terrasses 6,0 / 8,8 / 12,0 m, escaliers',
  'Rivière : 77 m, 2,5 → 5 m de large, 15 m → lac (-0,8)',
  'Pont en arche : 9 × 3,2 m, ouverture 6 m',
  'Fermes + moulin à vent hors enceinte : ≈ 0,6 ha',
  'Tout reste à ≥ 12 m du mur invisible (108 m)',
]) { lt(y, '• ' + t, { t: 11.5 }); y += 17; }
y += 10;
lt(y, 'Relief (fond de carte)', { t: 15, g: 1 }); y += 18;
for (const t of [
  'Relief réel du jeu (ancien relief + grotte), 1 m ;',
  'courbes tous les 1 m, épaisses tous les 5 m.',
  'Cuvette : fond -6..+4 m, rebord 15..30 m.',
  'Le plateau du village est l’aplat gris clair à 3,6 m.',
]) { lt(y, t, { t: 11.5 }); y += 16; }
y += 10;
lt(y, 'Vue d’ensemble de la cuvette', { t: 15, g: 1 }); y += 8;
const IN = { x: LX, y, s: 1.45 };   // encart : -110..110 → 320 px
const ix = (x) => IN.x + (x + 110) * IN.s, iz = (z) => IN.y + (z + 110) * IN.s;
const INSET = IN;
leg += `<rect x="${ix(X0)}" y="${iz(Z0)}" width="${(X1 - X0) * IN.s}" height="${(Z1 - Z0) * IN.s}" fill="none" stroke="#1e5fd0" stroke-width="2"/>`;
leg += `<rect x="${ix(-108)}" y="${iz(-108)}" width="${216 * IN.s}" height="${216 * IN.s}" fill="none" stroke="#d01010" stroke-width="1.5" stroke-dasharray="5 3"/>`;
leg += `<polyline points="${riviere.map((p) => `${ix(p[0])},${iz(p[1])}`).join(' ')}" fill="none" stroke="#3c78b4" stroke-width="3"/>`;
leg += `<polyline points="${[[-95, -29], [-85, -19], [-75, -9], [-75, 1], [-71, 11], [-67, 21]].map((p) => `${ix(p[0])},${iz(p[1])}`).join(' ')}" fill="none" stroke="#3c78b4" stroke-width="2.4" stroke-dasharray="4 2"/>`;
leg += `<polygon points="${palissade.map((p) => `${ix(p[0])},${iz(p[1])}`).join(' ')}" fill="#c0703a" stroke="#4a2f17"/>`;
const ip = (x, z, c, t, a = 'start', dx = 5) => { leg += `<circle cx="${ix(x)}" cy="${iz(z)}" r="3.5" fill="${c}" stroke="#fff"/><text x="${ix(x) + (a === 'end' ? -dx : dx)}" y="${iz(z) + 4}" font-size="10" text-anchor="${a}" font-family="DejaVu Sans, Arial" paint-order="stroke" stroke="#f4f1ea" stroke-width="3">${t}</text>`; };
ip(0, 0, '#ff7a1a', 'feu'); ip(-38, -34, '#555', 'cercle'); ip(-38, -48, '#222', 'tertre', 'end'); ip(92, -27, '#222', 'grotte', 'end');
leg += `<text x="${ix(-100)}" y="${iz(-40)}" font-size="9.5" font-family="DejaVu Sans, Arial" fill="#123e6c">rivière C5</text>`;
leg += `<text x="${ix(-40)}" y="${iz(70)}" font-size="10" font-family="DejaVu Sans, Arial" fill="#123e6c" font-weight="700">lac</text>`;

{ let yy = iz(110) + 26; lt(yy, 'Postes des PNJ (points rouges)', { t: 15, g: 1 }); yy += 18;
  for (const [n, x, z, poste] of pnj) { lt(yy, `${n} : « ${poste} » (${x} ; ${z})`, { t: 11.5 }); yy += 16; } }
// ---------------------------------------------------------------- page
const html = `<!doctype html><html><body style="margin:0;background:#f4f1ea">
<canvas id="c" width="${W}" height="${Hh}" style="position:absolute;left:0;top:0"></canvas>
<svg width="${W}" height="${Hh}" style="position:absolute;left:0;top:0" xmlns="http://www.w3.org/2000/svg">
<defs>
<pattern id="hach" width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="10" stroke="#b03030" stroke-width="1.4" opacity="0.45"/></pattern>
<pattern id="sillons" width="7" height="7" patternUnits="userSpaceOnUse"><rect width="7" height="7" fill="#e9e4dc" opacity="0.75"/><line x1="0" y1="3.5" x2="7" y2="3.5" stroke="#7a5a3a" stroke-width="1.4"/></pattern>
<pattern id="paves" width="10" height="8" patternUnits="userSpaceOnUse"><rect x="0.5" y="0.5" width="5" height="3" fill="none" stroke="#5f5a55" stroke-width="0.8"/><rect x="4" y="4.5" width="5" height="3" fill="none" stroke="#5f5a55" stroke-width="0.8"/></pattern>
<pattern id="auvent" width="6" height="6" patternUnits="userSpaceOnUse"><rect width="3" height="6" fill="#c33c33"/><rect x="3" width="3" height="6" fill="#efe6d6"/></pattern>
<pattern id="grille" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="4" fill="#cfc4b4"/><line x1="0" y1="2" x2="4" y2="2" stroke="#3a2715" stroke-width="1.6"/></pattern>
<marker id="fl" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#1b2230"/></marker>
</defs>
<text x="${OX}" y="30" font-size="22" font-weight="700" font-family="DejaVu Sans, Arial" fill="#1b2230">Skarnholt v2 — plan de masse (lot C7-PLAN, à valider)</text>
<text x="${OX}" y="50" font-size="12.5" font-family="DejaVu Sans, Arial" fill="#3a4250">Vu de dessus, nord en haut (-Z), 1 carreau d’échelle = 10 m ; référence : references/village_v2_planche.png (vues 1 à 6 placées sur le plan)</text>
${s}${leg}</svg>
<script>
const G = ${JSON.stringify(grille)};
const S=${S},X0=${X0},Z0=${Z0},OX=${OX},OY=${OY},NX=${(X1 - X0) * S},NZ=${(Z1 - Z0) * S};
const h=(x,z)=>{x+=110;z+=110;const i=Math.max(0,Math.min(219,Math.floor(x))),j=Math.max(0,Math.min(219,Math.floor(z)));const fx=x-i,fz=z-j;
 return (G[j][i]*(1-fx)+G[j][i+1]*fx)*(1-fz)+(G[j+1][i]*(1-fx)+G[j+1][i+1]*fx)*fz;};
const lac=(x,z,v)=>x>-65&&x<19.5&&z>7&&z<85&&v<-0.8;
const ramp=[[-7,[92,108,126]],[-1,[146,156,170]],[3,[205,209,214]],[4,[214,217,221]],[10,[226,228,230]],[20,[242,242,240]],[32,[250,250,248]]];
const col=v=>{for(let k=0;k<ramp.length-1;k++){const[a,ca]=ramp[k],[b,cb]=ramp[k+1];if(v<=b){const t=Math.max(0,(v-a)/(b-a));return ca.map((c,i)=>c+(cb[i]-c)*t);}}return ramp[ramp.length-1][1];};
function relief(c,ox,oy,nx,nz,x0,z0,s){
 const im=c.createImageData(nx,nz);
 for(let py=0;py<nz;py++)for(let pxx=0;pxx<nx;pxx++){
  const x=x0+pxx/s,z=z0+py/s,v=h(x,z),gx=(h(x+0.5,z)-h(x-0.5,z)),gz=(h(x,z+0.5)-h(x,z-0.5));
  let sh=Math.max(0.55,Math.min(1.25,1+(gx*0.55+gz*0.55)*-0.35));
  let c3=col(v);
  if(lac(x,z,v)){c3=[86,128,172];sh=1;}
  let r=c3[0]*sh,g=c3[1]*sh,b=c3[2]*sh;
  const vr=h(x+1/s,z),vd=h(x,z+1/s);
  if(Math.floor(v)!==Math.floor(vr)||Math.floor(v)!==Math.floor(vd)){const cinq=Math.floor(v/5)!==Math.floor(vr/5)||Math.floor(v/5)!==Math.floor(vd/5);const k=cinq?0.62:0.84;r*=k;g*=k;b*=k;}
  const o=(py*nx+pxx)*4;im.data[o]=r;im.data[o+1]=g;im.data[o+2]=b;im.data[o+3]=255;}
 c.putImageData(im,ox,oy);}
const c=document.getElementById('c').getContext('2d');
relief(c,OX,OY,NX,NZ,X0,Z0,S);
relief(c,${Math.round(INSET.x)},${Math.round(INSET.y)},${Math.round(220 * INSET.s)},${Math.round(220 * INSET.s)},-110,-110,${INSET.s});
// cotes de hauteur sur les courbes de 5 m
c.font='bold 10px DejaVu Sans, Arial';c.fillStyle='#4a5160';
for(const [x,z] of [[96,40],[100,10],[60,84],[30,80],[84,64],[0,90],[-20,-10],[20,-30],[44,-20],[104,70],[70,-36]]){c.fillText(h(x,z).toFixed(0)+' m',OX+(x-X0)*S,OY+(z-Z0)*S);}
document.title='pret';
</script></body></html>`;

await Bun.write('/tmp/plan_village_v2.html', html);
const nav = await chromium.launch();
const page = await nav.newPage({ viewport: { width: W, height: Hh } });
await page.goto('file:///tmp/plan_village_v2.html', { waitUntil: 'load' });
await page.waitForFunction(() => document.title === 'pret');
await page.screenshot({ path: sortie });
await nav.close();
console.log('plan écrit :', sortie, W + 'x' + Hh);
