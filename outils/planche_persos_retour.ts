// Assemble les captures de outils/planche_persos_retour.gd en une planche comparative (640x360 par case, sans redimensionnement).
//   bun assembler.ts <sortie.png> "<Titre A>=<dossier A>=<h_jour>,<h_crep>" "<Titre B>=<dossier B>=<h_jour>,<h_crep>" ...
// Besoin de sharp (bun add sharp dans un dossier de travail hors du dépôt).
import sharp from "sharp";

const PERSOS: [string, string][] = [["chef", "Gunnhild (cheffe)"], ["forgeron", "Brodd (forgeron)"], ["garde", "Haldor (garde)"], ["chasseuse", "Ylva (chasseuse)"],
  ["volva", "Sigrún (völva)"], ["ancienne", "Grima (ancienne)"], ["bandit", "Bandit casqué"], ["joueur", "Joueur (3e pers.)"]];
const W = 640, H = 360, ETIQ = 170, TETE = 64, MARGE = 12;
const [sortie, ...groupes] = process.argv.slice(2);
const gs = groupes.map((g) => { const [titre, dir, h] = g.split("="); const [hj, hc] = h.split(","); return { titre, dir, hj, hc }; });
const cols = (g: typeof gs[0]) => [[g.hj, "2"], [g.hj, "4"], [g.hc, "2"], [g.hc, "4"]] as [string, string][];
const larg = ETIQ + gs.length * (4 * W) + (gs.length - 1) * MARGE;
const haut = TETE + PERSOS.length * H;
const txt = (s: string, w: number, h: number, taille: number, fond = "#111", coul = "#eee") =>
  Buffer.from(`<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg"><rect width="${w}" height="${h}" fill="${fond}"/>` +
    s.split("\n").map((l, i) => `<text x="8" y="${taille + 6 + i * (taille + 6)}" font-size="${taille}" fill="${coul}" font-family="sans-serif">${l}</text>`).join("") + `</svg>`);
const comp: sharp.OverlayOptions[] = [];
let x = ETIQ;
for (const g of gs) {
  comp.push({ input: txt(g.titre, 4 * W, 32, 22, "#222", "#ffd27a"), left: x, top: 0 });
  cols(g).forEach(([h, d], i) => comp.push({ input: txt(`${h.replace(".5", "h30")} h — ${d} m`, W, 32, 16, "#1a1a1a"), left: x + i * W, top: 32 }));
  PERSOS.forEach(([id], r) => cols(g).forEach(([h, d], i) => {
    comp.push({ input: `${g.dir}/${id}_${h.replace(".", "h")}_${d}m.png`, left: x + i * W, top: TETE + r * H });
  }));
  x += 4 * W + MARGE;
}
PERSOS.forEach(([, nom], r) => comp.push({ input: txt(nom.replace(" (", "\n("), ETIQ, H, 18), left: 0, top: TETE + r * H }));
await sharp({ create: { width: larg, height: haut, channels: 3, background: "#000" } }).composite(comp).png({ compressionLevel: 9 }).toFile(sortie);
console.log("PLANCHE", sortie, larg, "x", haut);
