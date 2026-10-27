class_name PresetsMagie
## Réglages des émetteurs de particules de la magie (lus par GestionMagie) : une entrée = un ParticleProcessMaterial
## partagé (cache). Unités : mètres, secondes. Palettes du référentiel (references/magie/referentiel_magie_1100.jpg) :
## feu rouge → orange → jaune → crème ; glace blancs → bleus ; électricité bleu-violet → blanc ; ténèbres violets → noir ;
## soin doré / vert doux ; protection bleu pâle.
##
## Clés : n (nombre), vie (s), expl (explosivité), alea (variation de vie), rampe (couleurs EN PALIERS du début à la fin,
## « #rrggbbaa » pour l'alpha ; un palier transparent est ajouté à la fin sauf garde_fin), taille (Vector2 m),
## courbe ("plat", "monte", "descend", "bosse"), vit (Vector2 m/s), dir, ecart (°), grav, amort, radial (accélération
## radiale), radiale_v (vitesse radiale), forme ("point", "sphere", "surface", "boite", "anneau", "disque"), r, ext, axe,
## add (additif ; sinon mélange alpha), cap (taille max en px), eclat, local (coordonnées locales), mesh ("quad" ou
## "eclat" = cristal de glace orienté par la vitesse, couleurs de `pal`).

const FEU := ["#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"]
const GLACE := ["#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8", "#1b2c5a"]
const ELEC := ["#f0f2ff", "#b4c0ff", "#7a7af0", "#4a3ad0", "#2a1a6a"]
const TEN := ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e", "#0c0614"]
const SOIN := ["#fff4c0", "#f0d070", "#b8d060", "#5f9a3a"]
const PROT := ["#eaf8ff", "#b8e0f0", "#7ab0d8", "#3a6a9a"]
const FUMEE := ["#00000000", "#2c2424b0", "#1d191990", "#0f0b0850"]
const TEN_FUMEE := ["#2a0e3ee6", "#1a0a28cc", "#0c061499"]
const BRUME_GLACE := ["#a8d8f860", "#5f9fe840", "#2f5fb820"]
const VAPEUR := ["#e8eef4b0", "#c8d2dc90", "#9aa6b660"]
const VIOLET := ["#d08aff", "#9a3ae0", "#5a1a8a"]
const BRAISE := ["#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"]
const OBSCUR := ["#ffb0e0", "#c040e0", "#6a1aa0", "#2a0e3e", "#0c0614"]

## Préfixe court des écoles dans les noms de réglages.
const COURT := {"feu": "feu", "glace": "glace", "electricite": "elec", "tenebres": "ten", "soin": "soin", "protection": "prot"}

const AVANT := Vector3(0, 0, -1)
const HAUT := Vector3.UP

static var R := {
	# ---------------------------------------------------------------- auras de la main (repère de la main, local)
	"feu_aura": {"n": 40, "vie": 0.5, "forme": "sphere", "r": 0.028, "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.03, 0.1), "grav": Vector3(0, 0.55, 0), "taille": Vector2(0.008, 0.015), "courbe": "descend", "rampe": FEU, "cap": 5.0, "eclat": 1.7, "local": true},
	"feu_aura_braise": {"n": 10, "vie": 0.9, "forme": "sphere", "r": 0.045, "dir": HAUT, "ecart": 60.0, "vit": Vector2(0.08, 0.22), "grav": Vector3(0, 0.15, 0), "taille": Vector2(0.003, 0.005), "rampe": BRAISE, "cap": 2.0, "local": true},
	"glace_aura": {"n": 22, "vie": 1.0, "forme": "sphere", "r": 0.045, "ecart": 180.0, "vit": Vector2(0.005, 0.03), "grav": Vector3(0, -0.04, 0), "taille": Vector2(0.008, 0.016), "courbe": "bosse", "rampe": ["#a8d8f8c0", "#5f9fe8a0", "#2f5fb860"], "eclat": 1.0, "cap": 6.0, "local": true},
	"glace_aura_cristal": {"n": 14, "vie": 0.7, "forme": "surface", "r": 0.05, "vit": Vector2(0.0, 0.02), "taille": Vector2(0.003, 0.006), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.8, "cap": 2.0, "local": true},
	"glace_double_orbite": {"n": 18, "vie": 1.2, "forme": "anneau", "r": 0.11, "axe": HAUT, "vit": Vector2(0.0, 0.02), "taille": Vector2(0.006, 0.01), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.8, "cap": 3.0, "local": true},
	"elec_aura": {"n": 16, "vie": 0.25, "forme": "sphere", "r": 0.03, "ecart": 180.0, "vit": Vector2(0.15, 0.4), "taille": Vector2(0.002, 0.004), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 2.0, "local": true},
	"ten_aura": {"n": 26, "vie": 1.1, "forme": "sphere", "r": 0.04, "ecart": 180.0, "vit": Vector2(0.01, 0.05), "radial": Vector2(-0.06, -0.02), "grav": Vector3(0, 0.06, 0), "taille": Vector2(0.01, 0.02), "courbe": "bosse", "rampe": TEN_FUMEE, "add": false, "cap": 7.0, "local": true},
	"ten_aura_lueur": {"n": 16, "vie": 0.6, "forme": "sphere", "r": 0.035, "ecart": 180.0, "vit": Vector2(0.02, 0.06), "grav": Vector3(0, 0.08, 0), "taille": Vector2(0.005, 0.01), "rampe": VIOLET, "eclat": 1.6, "cap": 4.0, "local": true},
	"soin_aura": {"n": 18, "vie": 1.2, "forme": "sphere", "r": 0.05, "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.02, 0.06), "grav": Vector3(0, 0.05, 0), "taille": Vector2(0.004, 0.008), "rampe": SOIN, "eclat": 1.5, "cap": 3.0, "local": true},
	"prot_aura": {"n": 20, "vie": 0.9, "forme": "anneau", "r": 0.07, "axe": Vector3(0, 0, 1), "vit": Vector2(0.0, 0.01), "taille": Vector2(0.004, 0.007), "rampe": PROT, "eclat": 1.5, "cap": 3.0, "local": true},
	# ---------------------------------------------------------------- jets canalisés (monde ; -Z = direction)
	"feu_jet": {"n": 150, "vie": 0.5, "dir": AVANT, "ecart": 9.0, "vit": Vector2(6.5, 9.0), "amort": Vector2(2.0, 4.0), "grav": Vector3(0, 1.2, 0), "taille": Vector2(0.08, 0.16), "courbe": "monte", "rampe": FEU, "cap": 12.0, "eclat": 1.6, "alea": 0.2},
	"feu_jet_braise": {"n": 30, "vie": 0.6, "dir": AVANT, "ecart": 14.0, "vit": Vector2(8.0, 11.0), "grav": Vector3(0, -3.0, 0), "taille": Vector2(0.012, 0.02), "rampe": ["#fff0a8", "#fcb53a", "#ec6a1f"], "cap": 3.0},
	"feu_jet_fumee": {"n": 24, "vie": 0.9, "dir": AVANT, "ecart": 12.0, "vit": Vector2(5.0, 7.0), "amort": Vector2(3.0, 5.0), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.15, 0.25), "courbe": "monte", "rampe": ["#00000000", "#00000000", "#2c2424aa", "#1d191988", "#0f0b0844"], "add": false, "cap": 12.0},
	"feu_lechage": {"n": 14, "vie": 0.45, "expl": 0.8, "forme": "sphere", "r": 0.15, "dir": HAUT, "ecart": 35.0, "vit": Vector2(0.8, 1.8), "grav": Vector3(0, 1.5, 0), "taille": Vector2(0.08, 0.15), "courbe": "bosse", "rampe": FEU, "cap": 12.0},
	"glace_jet": {"n": 130, "vie": 0.5, "dir": AVANT, "ecart": 9.0, "vit": Vector2(6.0, 8.0), "amort": Vector2(2.0, 4.0), "grav": Vector3(0, -0.3, 0), "taille": Vector2(0.04, 0.08), "courbe": "monte", "rampe": GLACE, "eclat": 1.2, "cap": 10.0},
	"glace_jet_cristal": {"n": 20, "vie": 0.5, "dir": AVANT, "ecart": 10.0, "vit": Vector2(8.0, 10.0), "taille": Vector2(0.03, 0.06), "mesh": "eclat", "pal": "glace"},
	"glace_jet_brume": {"n": 24, "vie": 0.9, "dir": AVANT, "ecart": 14.0, "vit": Vector2(4.0, 6.0), "amort": Vector2(3.0, 5.0), "taille": Vector2(0.18, 0.3), "courbe": "monte", "rampe": BRUME_GLACE, "add": false, "cap": 14.0},
	"glace_bouffee": {"n": 16, "vie": 0.5, "expl": 0.8, "forme": "sphere", "r": 0.15, "dir": HAUT, "ecart": 70.0, "vit": Vector2(0.5, 1.5), "taille": Vector2(0.06, 0.12), "courbe": "bosse", "rampe": GLACE, "cap": 10.0},
	"ten_drain_sombre": {"n": 40, "vie": 0.5, "forme": "sphere", "r": 0.12, "dir": AVANT, "ecart": 5.0, "vit": Vector2(5.0, 6.0), "taille": Vector2(0.03, 0.06), "rampe": TEN_FUMEE, "add": false, "cap": 6.0},
	"ten_drain_rouge": {"n": 40, "vie": 0.5, "forme": "sphere", "r": 0.1, "dir": AVANT, "ecart": 4.0, "vit": Vector2(5.0, 6.5), "taille": Vector2(0.015, 0.03), "rampe": ["#ff6a8a", "#c02040", "#9a3ae0", "#5a1a8a"], "eclat": 1.7, "cap": 4.0},
	"soin_jet": {"n": 60, "vie": 0.6, "dir": AVANT, "ecart": 6.0, "vit": Vector2(5.0, 6.0), "taille": Vector2(0.02, 0.04), "rampe": SOIN, "cap": 5.0},
	"prot_jet": {"n": 40, "vie": 0.5, "forme": "anneau", "r": 0.3, "axe": Vector3(0, 0, 1), "vit": Vector2(0.0, 0.1), "taille": Vector2(0.015, 0.025), "rampe": PROT, "cap": 3.0, "local": true},
	"elec_etincelles": {"n": 24, "vie": 0.4, "expl": 1.0, "dir": HAUT, "ecart": 80.0, "vit": Vector2(2.0, 5.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.008, 0.016), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 3.0},
	# ---------------------------------------------------------------- projectiles : cœur (local) et traînées (monde)
	"feu_boule_coeur": {"n": 26, "vie": 0.25, "forme": "sphere", "r": 0.1, "ecart": 180.0, "vit": Vector2(0.0, 0.3), "taille": Vector2(0.05, 0.09), "courbe": "descend", "rampe": ["#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "cap": 10.0, "local": true},
	"feu_trainee": {"n": 90, "vie": 0.45, "forme": "sphere", "r": 0.08, "ecart": 180.0, "vit": Vector2(0.1, 0.5), "grav": Vector3(0, 1.0, 0), "taille": Vector2(0.06, 0.12), "courbe": "descend", "rampe": FEU, "cap": 12.0, "alea": 0.3},
	"feu_trainee_fumee": {"n": 30, "vie": 1.0, "forme": "sphere", "r": 0.1, "ecart": 180.0, "vit": Vector2(0.1, 0.4), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.12, 0.22), "courbe": "monte", "rampe": FUMEE, "add": false, "cap": 12.0},
	"glace_trainee": {"n": 50, "vie": 0.4, "forme": "sphere", "r": 0.05, "ecart": 180.0, "vit": Vector2(0.0, 0.2), "taille": Vector2(0.012, 0.025), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8"], "eclat": 1.7, "cap": 3.0},
	"glace_trainee_brume": {"n": 20, "vie": 0.8, "forme": "sphere", "r": 0.08, "ecart": 180.0, "vit": Vector2(0.0, 0.15), "taille": Vector2(0.1, 0.18), "courbe": "monte", "rampe": ["#a8d8f850", "#5f9fe830"], "add": false, "cap": 12.0},
	"elec_trainee": {"n": 40, "vie": 0.25, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.3, 1.0), "taille": Vector2(0.006, 0.012), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 2.0},
	"ten_trainee": {"n": 50, "vie": 0.7, "forme": "sphere", "r": 0.07, "ecart": 180.0, "vit": Vector2(0.05, 0.3), "grav": Vector3(0, 0.2, 0), "taille": Vector2(0.06, 0.12), "courbe": "bosse", "rampe": TEN_FUMEE, "add": false, "cap": 10.0},
	"ten_trainee_lueur": {"n": 40, "vie": 0.4, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.1, 0.4), "taille": Vector2(0.015, 0.03), "rampe": VIOLET, "cap": 4.0},
	"ten_coeur": {"n": 20, "vie": 0.4, "forme": "surface", "r": 0.1, "radial": Vector2(-0.6, -0.3), "taille": Vector2(0.02, 0.04), "rampe": VIOLET, "cap": 6.0, "local": true},
	"soin_trainee": {"n": 40, "vie": 0.5, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.05, 0.3), "taille": Vector2(0.012, 0.025), "rampe": SOIN, "cap": 3.0},
	"prot_trainee": {"n": 40, "vie": 0.5, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.05, 0.3), "taille": Vector2(0.012, 0.025), "rampe": PROT, "cap": 3.0},
	# ---------------------------------------------------------------- impacts (ponctuels ; +Y = normale)
	"feu_impact": {"n": 60, "vie": 0.55, "expl": 0.95, "forme": "sphere", "r": 0.1, "dir": HAUT, "ecart": 70.0, "vit": Vector2(1.5, 4.0), "amort": Vector2(2.0, 3.0), "grav": Vector3(0, 1.5, 0), "taille": Vector2(0.08, 0.16), "courbe": "bosse", "rampe": FEU, "cap": 14.0},
	"feu_impact_braise": {"n": 36, "vie": 1.0, "expl": 1.0, "dir": HAUT, "ecart": 80.0, "vit": Vector2(3.0, 6.0), "grav": Vector3(0, -7.0, 0), "taille": Vector2(0.015, 0.025), "rampe": BRAISE, "cap": 3.0},
	"feu_impact_fumee": {"n": 14, "vie": 1.4, "expl": 0.8, "forme": "sphere", "r": 0.2, "dir": HAUT, "ecart": 60.0, "vit": Vector2(0.4, 1.2), "amort": Vector2(0.5, 1.0), "grav": Vector3(0, 0.7, 0), "taille": Vector2(0.25, 0.45), "courbe": "monte", "rampe": FUMEE, "add": false, "cap": 16.0},
	"glace_impact_eclats": {"n": 22, "vie": 1.0, "expl": 1.0, "dir": HAUT, "ecart": 70.0, "vit": Vector2(2.0, 5.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.06, 0.14), "mesh": "eclat", "pal": "glace"},
	"glace_impact": {"n": 30, "vie": 0.6, "expl": 0.95, "forme": "sphere", "r": 0.12, "dir": HAUT, "ecart": 80.0, "vit": Vector2(0.5, 2.2), "amort": Vector2(2.0, 3.0), "taille": Vector2(0.05, 0.1), "courbe": "bosse", "rampe": GLACE, "cap": 10.0},
	"glace_impact_brume": {"n": 10, "vie": 1.4, "expl": 0.8, "forme": "sphere", "r": 0.25, "dir": HAUT, "ecart": 90.0, "vit": Vector2(0.2, 0.6), "taille": Vector2(0.3, 0.5), "courbe": "monte", "rampe": BRUME_GLACE, "add": false, "cap": 16.0},
	"elec_impact": {"n": 50, "vie": 0.5, "expl": 1.0, "dir": HAUT, "ecart": 85.0, "vit": Vector2(3.0, 7.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.01, 0.02), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 3.0},
	"ten_impact": {"n": 50, "vie": 0.8, "expl": 0.9, "forme": "sphere", "r": 0.2, "dir": HAUT, "ecart": 40.0, "vit": Vector2(1.0, 3.0), "amort": Vector2(1.0, 2.0), "grav": Vector3(0, 1.0, 0), "taille": Vector2(0.06, 0.12), "courbe": "bosse", "rampe": ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e"], "cap": 12.0},
	"ten_impact_sombre": {"n": 30, "vie": 1.1, "expl": 0.85, "forme": "sphere", "r": 0.25, "dir": HAUT, "ecart": 50.0, "vit": Vector2(0.6, 2.0), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.12, 0.25), "courbe": "bosse", "rampe": TEN_FUMEE, "add": false, "cap": 14.0},
	"soin_impact": {"n": 40, "vie": 1.2, "expl": 0.7, "forme": "sphere", "r": 0.4, "dir": HAUT, "ecart": 20.0, "vit": Vector2(0.4, 1.2), "taille": Vector2(0.02, 0.04), "rampe": SOIN, "cap": 4.0},
	"prot_impact": {"n": 40, "vie": 0.8, "expl": 1.0, "forme": "anneau", "r": 0.5, "axe": HAUT, "radiale_v": Vector2(1.0, 2.0), "taille": Vector2(0.02, 0.03), "rampe": PROT, "cap": 4.0},
	# ---------------------------------------------------------------- zones (rayon réglé par zone)
	"feu_sol": {"n": 140, "vie": 0.8, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 15.0, "vit": Vector2(0.6, 1.6), "grav": Vector3(0, 1.2, 0), "taille": Vector2(0.1, 0.22), "courbe": "bosse", "rampe": FEU, "cap": 14.0},
	"feu_sol_braise": {"n": 40, "vie": 1.4, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 30.0, "vit": Vector2(1.0, 2.5), "grav": Vector3(0, 0.3, 0), "taille": Vector2(0.015, 0.025), "rampe": BRAISE, "cap": 3.0},
	"feu_explosion": {"n": 120, "vie": 0.7, "expl": 1.0, "forme": "sphere", "r": 0.4, "dir": HAUT, "ecart": 180.0, "vit": Vector2(3.0, 7.0), "amort": Vector2(4.0, 6.0), "grav": Vector3(0, 2.0, 0), "taille": Vector2(0.15, 0.3), "courbe": "bosse", "rampe": FEU, "cap": 16.0},
	"feu_explosion_fumee": {"n": 30, "vie": 1.8, "expl": 0.9, "forme": "sphere", "r": 0.6, "dir": HAUT, "ecart": 180.0, "vit": Vector2(1.0, 3.0), "amort": Vector2(2.0, 3.0), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.4, 0.7), "courbe": "monte", "rampe": FUMEE, "add": false, "cap": 16.0},
	"glace_nova_souffle": {"n": 80, "vie": 0.6, "expl": 1.0, "forme": "anneau", "r": 0.3, "axe": HAUT, "radiale_v": Vector2(5.0, 7.0), "taille": Vector2(0.08, 0.16), "courbe": "bosse", "rampe": GLACE, "cap": 12.0},
	"glace_nova_brume": {"n": 30, "vie": 2.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.05, 0.2), "taille": Vector2(0.3, 0.6), "courbe": "bosse", "rampe": ["#a8d8f850", "#5f9fe838", "#2f5fb820"], "add": false, "cap": 16.0},
	"glace_scintille": {"n": 30, "vie": 0.8, "forme": "disque", "r": 2.0, "dir": HAUT, "vit": Vector2(0.0, 0.1), "taille": Vector2(0.015, 0.025), "rampe": ["#e8f6ff", "#a8d8f8"], "eclat": 2.0, "cap": 3.0},
	"glace_eclats_zone": {"n": 30, "vie": 1.0, "expl": 1.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 50.0, "vit": Vector2(1.5, 4.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.06, 0.14), "mesh": "eclat", "pal": "glace"},
	"elec_sol": {"n": 50, "vie": 0.3, "forme": "anneau", "r": 2.0, "axe": HAUT, "ecart": 180.0, "vit": Vector2(0.2, 1.0), "taille": Vector2(0.01, 0.02), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 3.0},
	"ten_sol": {"n": 90, "vie": 1.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 20.0, "vit": Vector2(0.4, 1.4), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.08, 0.18), "courbe": "bosse", "rampe": ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e"], "cap": 14.0},
	"ten_sol_sombre": {"n": 40, "vie": 1.6, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 20.0, "vit": Vector2(0.2, 0.8), "grav": Vector3(0, 0.4, 0), "taille": Vector2(0.2, 0.4), "courbe": "bosse", "rampe": TEN_FUMEE, "add": false, "cap": 16.0},
	"ten_eruption": {"n": 70, "vie": 0.9, "expl": 1.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 25.0, "vit": Vector2(2.0, 5.0), "amort": Vector2(2.0, 3.0), "grav": Vector3(0, 0.5, 0), "taille": Vector2(0.1, 0.22), "courbe": "bosse", "rampe": ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e"], "cap": 14.0},
	"soin_sol": {"n": 60, "vie": 1.6, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 5.0, "vit": Vector2(0.4, 1.0), "taille": Vector2(0.02, 0.04), "rampe": SOIN, "cap": 4.0},
	"prot_sol": {"n": 60, "vie": 1.4, "forme": "anneau", "r": 2.0, "axe": HAUT, "dir": HAUT, "ecart": 3.0, "vit": Vector2(0.6, 1.4), "taille": Vector2(0.02, 0.035), "rampe": PROT, "cap": 4.0},
	# ---------------------------------------------------------------- statuts des cibles (boîte = corps de la cible)
	"brulure": {"n": 40, "vie": 0.55, "forme": "boite", "dir": HAUT, "ecart": 20.0, "vit": Vector2(0.3, 0.9), "grav": Vector3(0, 1.5, 0), "taille": Vector2(0.05, 0.11), "courbe": "bosse", "rampe": FEU, "cap": 12.0},
	"brulure_braise": {"n": 12, "vie": 1.0, "forme": "boite", "dir": HAUT, "ecart": 40.0, "vit": Vector2(0.5, 1.2), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.01, 0.02), "rampe": BRAISE, "cap": 3.0},
	"gel": {"n": 24, "vie": 1.0, "forme": "boite", "vit": Vector2(0.0, 0.1), "grav": Vector3(0, -0.2, 0), "taille": Vector2(0.012, 0.022), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.8, "cap": 3.0},
	"gel_brume": {"n": 10, "vie": 1.6, "forme": "boite", "vit": Vector2(0.0, 0.1), "grav": Vector3(0, -0.15, 0), "taille": Vector2(0.2, 0.35), "courbe": "bosse", "rampe": ["#a8d8f840", "#5f9fe830"], "add": false, "cap": 14.0},
	"choc": {"n": 20, "vie": 0.3, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.5, 2.0), "grav": Vector3(0, -6.0, 0), "taille": Vector2(0.008, 0.015), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 2.0},
	"corruption": {"n": 30, "vie": 1.2, "forme": "boite", "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.15, 0.5), "grav": Vector3(0, 0.25, 0), "taille": Vector2(0.08, 0.16), "courbe": "bosse", "rampe": TEN_FUMEE, "add": false, "cap": 12.0},
	"corruption_lueur": {"n": 20, "vie": 0.8, "forme": "boite", "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.2, 0.5), "taille": Vector2(0.02, 0.04), "rampe": VIOLET, "cap": 4.0},
	# ---------------------------------------------------------------- enchantements d'arme (boîte = lame)
	"enchant_feu": {"n": 60, "vie": 0.35, "forme": "boite", "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.1, 0.4), "grav": Vector3(0, 1.6, 0), "taille": Vector2(0.02, 0.045), "courbe": "descend", "rampe": FEU, "cap": 6.0, "eclat": 1.6},
	"enchant_feu_braise": {"n": 12, "vie": 0.6, "forme": "boite", "dir": HAUT, "ecart": 60.0, "vit": Vector2(0.2, 0.6), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.006, 0.01), "rampe": BRAISE, "cap": 2.0},
	"enchant_glace": {"n": 30, "vie": 0.9, "forme": "boite", "vit": Vector2(0.0, 0.05), "grav": Vector3(0, -0.15, 0), "taille": Vector2(0.008, 0.016), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.7, "cap": 3.0},
	"enchant_glace_brume": {"n": 12, "vie": 1.2, "forme": "boite", "vit": Vector2(0.0, 0.08), "grav": Vector3(0, -0.2, 0), "taille": Vector2(0.05, 0.09), "rampe": ["#a8d8f860", "#5f9fe840"], "add": false, "cap": 8.0},
	"enchant_elec": {"n": 16, "vie": 0.25, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.3, 1.0), "taille": Vector2(0.004, 0.008), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 2.0},
	"enchant_ten": {"n": 30, "vie": 0.9, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.02, 0.12), "grav": Vector3(0, 0.15, 0), "taille": Vector2(0.03, 0.06), "courbe": "bosse", "rampe": TEN_FUMEE, "add": false, "cap": 8.0},
	"enchant_ten_lueur": {"n": 20, "vie": 0.6, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.03, 0.1), "taille": Vector2(0.008, 0.016), "rampe": VIOLET, "cap": 3.0},
	# ---------------------------------------------------------------- réactions entre écoles
	"vapeur": {"n": 40, "vie": 1.8, "expl": 0.9, "forme": "sphere", "r": 0.4, "dir": HAUT, "ecart": 80.0, "vit": Vector2(0.6, 2.4), "amort": Vector2(1.0, 2.0), "grav": Vector3(0, 0.7, 0), "taille": Vector2(0.3, 0.6), "courbe": "monte", "rampe": VAPEUR, "add": false, "cap": 16.0},
	"vapeur_gouttes": {"n": 24, "vie": 0.7, "expl": 1.0, "forme": "sphere", "r": 0.3, "dir": HAUT, "ecart": 90.0, "vit": Vector2(1.5, 3.5), "grav": Vector3(0, -6.0, 0), "taille": Vector2(0.012, 0.02), "rampe": ["#f6f8ff", "#e8f6ff", "#fcb53a"], "cap": 2.0},
	"obscur_sol": {"n": 100, "vie": 0.8, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 15.0, "vit": Vector2(0.6, 1.6), "grav": Vector3(0, 1.2, 0), "taille": Vector2(0.1, 0.22), "courbe": "bosse", "rampe": OBSCUR, "cap": 14.0},
	"obscur_sombre": {"n": 40, "vie": 1.2, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 15.0, "vit": Vector2(0.5, 1.2), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.14, 0.26), "courbe": "bosse", "rampe": TEN_FUMEE, "add": false, "cap": 14.0},
	"violet_etincelles": {"n": 40, "vie": 0.5, "expl": 1.0, "dir": HAUT, "ecart": 85.0, "vit": Vector2(2.0, 6.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.01, 0.02), "rampe": ["#f0d0ff", "#d08aff", "#9a3ae0"], "eclat": 2.0, "cap": 3.0},
	"corrompu_scintille": {"n": 30, "vie": 0.9, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.2, 0.8), "taille": Vector2(0.015, 0.03), "rampe": ["#f0d0ff", "#b080ff", "#6a3ad0"], "eclat": 1.8, "cap": 3.0},
	"incendiaire_etincelles": {"n": 50, "vie": 0.6, "expl": 1.0, "dir": HAUT, "ecart": 85.0, "vit": Vector2(3.0, 7.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.01, 0.02), "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f"], "eclat": 2.0, "cap": 3.0},
}

## Nom d'un réglage pour une école : `PresetsMagie.de("electricite", "trainee")` → "elec_trainee".
static func de(ecole: String, role: String) -> String:
	return "%s_%s" % [COURT.get(ecole, "feu"), role]
