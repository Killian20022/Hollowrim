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
## add (additif : étincelles, braises, reflets ; sinon pixels opaques de la palette en mélange alpha), cap (taille max en px), eclat, local (coordonnées locales), mesh ("quad" ou
## "eclat" = cristal de glace orienté par la vitesse, couleurs de `pal`), turb (influence min/max de la turbulence GPU),
## turb_echelle, turb_force.

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
	"feu_aura": {"n": 150, "vie": 0.38, "forme": "sphere", "r": 0.055, "dir": HAUT, "ecart": 22.0, "vit": Vector2(0.04, 0.14), "grav": Vector3(0, 0.7, 0), "taille": Vector2(0.024, 0.05), "courbe": "descend", "rampe": ["#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"], "cap": 14.0, "eclat": 1.7, "local": true, "turb": Vector2(0.05, 0.15), "turb_echelle": 6.0},
	"feu_aura_braise": {"add": true, "n": 30, "vie": 1.0, "forme": "sphere", "r": 0.08, "dir": HAUT, "ecart": 60.0, "vit": Vector2(0.1, 0.35), "grav": Vector3(0, 0.25, 0), "taille": Vector2(0.004, 0.008), "rampe": BRAISE, "cap": 3.0, "local": true, "turb": Vector2(0.1, 0.3), "turb_echelle": 4.0},
	"glace_aura": {"n": 70, "vie": 1.0, "forme": "sphere", "r": 0.08, "dir": HAUT, "ecart": 60.0, "vit": Vector2(0.02, 0.1), "grav": Vector3(0, 0.12, 0), "taille": Vector2(0.02, 0.045), "courbe": "bosse", "rampe": ["#e8f6ffd0", "#a8d8f8c0", "#5f9fe8a0", "#2f5fb860"], "eclat": 1.2, "cap": 12.0, "local": true, "turb": Vector2(0.05, 0.12), "turb_echelle": 5.0},
	"glace_aura_cristal": {"add": true, "n": 40, "vie": 0.7, "forme": "surface", "r": 0.09, "vit": Vector2(0.0, 0.05), "taille": Vector2(0.006, 0.012), "rampe": ["#ffffff", "#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.9, "cap": 3.0, "local": true},
	"glace_double_orbite": {"add": true, "n": 18, "vie": 1.2, "forme": "anneau", "r": 0.11, "axe": HAUT, "vit": Vector2(0.0, 0.02), "taille": Vector2(0.006, 0.01), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.8, "cap": 3.0, "local": true},
	"elec_aura": {"add": true, "n": 60, "vie": 0.25, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.3, 0.8), "taille": Vector2(0.005, 0.009), "rampe": ["#ffffff", "#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 3.0, "local": true},
	"ten_aura": {"n": 90, "vie": 1.0, "forme": "sphere", "r": 0.1, "ecart": 180.0, "vit": Vector2(0.02, 0.06), "radial": Vector2(-0.35, -0.15), "grav": Vector3(0, 0.12, 0), "taille": Vector2(0.025, 0.055), "courbe": "bosse", "rampe": TEN_FUMEE, "eclat": 1.0, "cap": 12.0, "local": true, "turb": Vector2(0.05, 0.12), "turb_echelle": 5.0},
	"ten_aura_lueur": {"add": true, "n": 50, "vie": 0.7, "forme": "sphere", "r": 0.08, "dir": HAUT, "ecart": 70.0, "vit": Vector2(0.04, 0.14), "grav": Vector3(0, 0.25, 0), "taille": Vector2(0.01, 0.022), "rampe": VIOLET, "eclat": 1.7, "cap": 6.0, "local": true, "turb": Vector2(0.08, 0.2), "turb_echelle": 5.0},
	"soin_aura": {"add": true, "n": 50, "vie": 1.2, "forme": "sphere", "r": 0.08, "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.04, 0.12), "grav": Vector3(0, 0.08, 0), "taille": Vector2(0.008, 0.016), "rampe": SOIN, "eclat": 1.6, "cap": 4.0, "local": true},
	"prot_aura": {"add": true, "n": 44, "vie": 0.9, "forme": "anneau", "r": 0.11, "axe": Vector3(0, 0, 1), "vit": Vector2(0.0, 0.01), "taille": Vector2(0.008, 0.014), "rampe": PROT, "eclat": 1.6, "cap": 4.0, "local": true},
	# ---------------------------------------------------------------- jets canalisés (monde ; -Z = direction)
	"feu_jet": {"n": 380, "vie": 0.5, "dir": AVANT, "ecart": 9.0, "vit": Vector2(7.0, 9.0), "amort": Vector2(0.5, 1.5), "grav": Vector3(0, 0.3, 0), "taille": Vector2(0.16, 0.34), "courbe": "monte", "rampe": ["#fff0a8", "#fcb53a", "#fcb53a", "#ec6a1f", "#b3341f"], "cap": 13.0, "eclat": 1.6, "alea": 0.2},
	"feu_jet_braise": {"add": true, "n": 70, "vie": 0.8, "dir": AVANT, "ecart": 18.0, "vit": Vector2(6.0, 11.0), "grav": Vector3(0, -1.0, 0), "taille": Vector2(0.012, 0.022), "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f"], "cap": 3.0},
	"feu_jet_fumee": {"n": 30, "vie": 1.0, "dir": AVANT, "ecart": 14.0, "vit": Vector2(5.0, 7.0), "amort": Vector2(3.0, 5.0), "grav": Vector3(0, 1.0, 0), "taille": Vector2(0.2, 0.35), "courbe": "monte", "rampe": ["#00000000", "#00000000", "#2c2424aa", "#1d191988", "#0f0b0844"], "eclat": 1.0, "cap": 16.0},
	"feu_lechage": {"n": 30, "vie": 0.5, "expl": 0.8, "forme": "sphere", "r": 0.25, "dir": HAUT, "ecart": 40.0, "vit": Vector2(1.0, 2.4), "grav": Vector3(0, 2.0, 0), "taille": Vector2(0.14, 0.28), "courbe": "bosse", "rampe": FEU, "eclat": 1.4, "cap": 18.0},
	"glace_jet": {"add": true, "n": 160, "vie": 0.5, "dir": AVANT, "ecart": 9.0, "vit": Vector2(6.0, 8.5), "amort": Vector2(0.5, 1.5), "taille": Vector2(0.012, 0.03), "rampe": ["#ffffff", "#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.7, "cap": 4.0},
	"glace_jet_cristal": {"n": 50, "vie": 0.6, "dir": AVANT, "ecart": 9.0, "vit": Vector2(8.0, 10.0), "taille": Vector2(0.1, 0.22), "mesh": "eclat", "pal": "glace"},
	"glace_jet_brume": {"n": 30, "vie": 1.0, "dir": AVANT, "ecart": 14.0, "vit": Vector2(4.0, 6.0), "amort": Vector2(3.0, 5.0), "taille": Vector2(0.25, 0.4), "courbe": "monte", "rampe": BRUME_GLACE, "eclat": 1.0, "cap": 16.0},
	"glace_bouffee": {"n": 24, "vie": 0.6, "expl": 0.8, "forme": "sphere", "r": 0.2, "dir": HAUT, "ecart": 70.0, "vit": Vector2(0.6, 1.8), "taille": Vector2(0.1, 0.2), "courbe": "bosse", "rampe": GLACE, "eclat": 1.35, "cap": 14.0},
	"ten_drain_sombre": {"n": 90, "vie": 0.6, "forme": "sphere", "r": 0.18, "dir": AVANT, "ecart": 6.0, "vit": Vector2(5.0, 6.5), "taille": Vector2(0.12, 0.26), "courbe": "bosse", "rampe": ["#9a3ae0e0", "#5a1a8ae0", "#2a0e3ed0", "#0c0614a0"], "eclat": 1.0, "cap": 16.0},
	"ten_drain_rouge": {"add": true, "n": 60, "vie": 0.5, "forme": "sphere", "r": 0.14, "dir": AVANT, "ecart": 5.0, "vit": Vector2(5.0, 6.5), "taille": Vector2(0.02, 0.045), "rampe": ["#f0d0ff", "#d08aff", "#9a3ae0", "#c02060"], "eclat": 1.8, "cap": 6.0},
	"soin_jet": {"add": true, "n": 60, "vie": 0.6, "dir": AVANT, "ecart": 6.0, "vit": Vector2(5.0, 6.0), "taille": Vector2(0.02, 0.04), "rampe": SOIN, "cap": 5.0},
	"prot_jet": {"add": true, "n": 40, "vie": 0.5, "forme": "anneau", "r": 0.3, "axe": Vector3(0, 0, 1), "vit": Vector2(0.0, 0.1), "taille": Vector2(0.015, 0.025), "rampe": PROT, "cap": 3.0, "local": true},
	"elec_etincelles": {"add": true, "n": 24, "vie": 0.4, "expl": 1.0, "dir": HAUT, "ecart": 80.0, "vit": Vector2(2.0, 5.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.008, 0.016), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 3.0},
	# ---------------------------------------------------------------- projectiles : cœur (local) et traînées (monde)
	"feu_boule_coeur": {"n": 60, "vie": 0.25, "forme": "sphere", "r": 0.16, "ecart": 180.0, "vit": Vector2(0.0, 0.4), "taille": Vector2(0.09, 0.18), "courbe": "descend", "rampe": ["#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "eclat": 1.4, "cap": 18.0, "local": true, "turb": Vector2(0.1, 0.2), "turb_echelle": 4.0},
	"feu_trainee": {"n": 170, "vie": 0.5, "forme": "sphere", "r": 0.14, "ecart": 180.0, "vit": Vector2(0.1, 0.6), "grav": Vector3(0, 1.2, 0), "taille": Vector2(0.1, 0.22), "courbe": "descend", "rampe": FEU, "eclat": 1.4, "cap": 18.0, "alea": 0.3, "turb": Vector2(0.05, 0.15), "turb_echelle": 2.0},
	"feu_trainee_fumee": {"n": 36, "vie": 1.0, "forme": "sphere", "r": 0.14, "ecart": 180.0, "vit": Vector2(0.1, 0.4), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.18, 0.3), "courbe": "monte", "rampe": FUMEE, "eclat": 1.0, "cap": 16.0},
	"glace_trainee": {"add": true, "n": 70, "vie": 0.45, "forme": "sphere", "r": 0.08, "ecart": 180.0, "vit": Vector2(0.0, 0.25), "taille": Vector2(0.02, 0.045), "rampe": ["#ffffff", "#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8"], "eclat": 1.8, "cap": 4.0},
	"glace_trainee_brume": {"n": 30, "vie": 0.8, "forme": "sphere", "r": 0.12, "ecart": 180.0, "vit": Vector2(0.0, 0.15), "taille": Vector2(0.14, 0.26), "courbe": "monte", "rampe": ["#a8d8f870", "#5f9fe850", "#2f5fb830"], "eclat": 1.0, "cap": 14.0},
	"elec_trainee": {"add": true, "n": 40, "vie": 0.25, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.3, 1.0), "taille": Vector2(0.006, 0.012), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 2.0},
	"ten_trainee": {"n": 80, "vie": 0.7, "forme": "sphere", "r": 0.1, "ecart": 180.0, "vit": Vector2(0.05, 0.35), "grav": Vector3(0, 0.25, 0), "taille": Vector2(0.09, 0.18), "courbe": "bosse", "rampe": TEN_FUMEE, "eclat": 1.0, "cap": 14.0, "turb": Vector2(0.05, 0.15), "turb_echelle": 2.0},
	"ten_trainee_lueur": {"add": true, "n": 50, "vie": 0.45, "forme": "sphere", "r": 0.08, "ecart": 180.0, "vit": Vector2(0.1, 0.5), "taille": Vector2(0.02, 0.04), "rampe": VIOLET, "eclat": 1.8, "cap": 6.0},
	"ten_coeur": {"add": true, "n": 36, "vie": 0.4, "forme": "surface", "r": 0.16, "radial": Vector2(-0.9, -0.5), "taille": Vector2(0.03, 0.06), "rampe": VIOLET, "cap": 10.0, "local": true},
	"soin_trainee": {"add": true, "n": 40, "vie": 0.5, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.05, 0.3), "taille": Vector2(0.012, 0.025), "rampe": SOIN, "cap": 3.0},
	"prot_trainee": {"add": true, "n": 40, "vie": 0.5, "forme": "sphere", "r": 0.06, "ecart": 180.0, "vit": Vector2(0.05, 0.3), "taille": Vector2(0.012, 0.025), "rampe": PROT, "cap": 3.0},
	# ---------------------------------------------------------------- impacts (ponctuels ; +Y = normale)
	"feu_impact": {"n": 130, "vie": 0.6, "expl": 0.95, "forme": "sphere", "r": 0.15, "dir": HAUT, "ecart": 80.0, "vit": Vector2(2.0, 5.0), "amort": Vector2(2.5, 3.5), "grav": Vector3(0, 1.8, 0), "taille": Vector2(0.15, 0.32), "courbe": "bosse", "rampe": FEU, "eclat": 1.45, "cap": 20.0, "turb": Vector2(0.05, 0.15), "turb_echelle": 2.0},
	"feu_impact_braise": {"add": true, "n": 90, "vie": 1.2, "expl": 1.0, "dir": HAUT, "ecart": 85.0, "vit": Vector2(3.5, 9.0), "grav": Vector3(0, -7.0, 0), "taille": Vector2(0.015, 0.03), "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "cap": 4.0},
	"feu_impact_fumee": {"n": 20, "vie": 1.6, "expl": 0.8, "forme": "sphere", "r": 0.3, "dir": HAUT, "ecart": 60.0, "vit": Vector2(0.4, 1.4), "amort": Vector2(0.5, 1.0), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.35, 0.6), "courbe": "monte", "rampe": FUMEE, "eclat": 1.0, "cap": 18.0},
	"glace_impact_eclats": {"n": 40, "vie": 1.1, "expl": 1.0, "dir": HAUT, "ecart": 75.0, "vit": Vector2(2.5, 6.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.08, 0.2), "mesh": "eclat", "pal": "glace"},
	"glace_impact": {"n": 50, "vie": 0.6, "expl": 0.95, "forme": "sphere", "r": 0.16, "dir": HAUT, "ecart": 80.0, "vit": Vector2(0.8, 2.8), "amort": Vector2(2.0, 3.0), "taille": Vector2(0.08, 0.18), "courbe": "bosse", "rampe": GLACE, "eclat": 1.35, "cap": 14.0},
	"glace_impact_brume": {"n": 10, "vie": 1.4, "expl": 0.8, "forme": "sphere", "r": 0.25, "dir": HAUT, "ecart": 90.0, "vit": Vector2(0.2, 0.6), "taille": Vector2(0.3, 0.5), "courbe": "monte", "rampe": BRUME_GLACE, "eclat": 1.0, "cap": 12.0},
	"elec_impact": {"add": true, "n": 80, "vie": 0.5, "expl": 1.0, "dir": HAUT, "ecart": 85.0, "vit": Vector2(3.0, 8.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.012, 0.024), "rampe": ["#ffffff", "#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 4.0},
	"ten_impact": {"n": 80, "vie": 0.8, "expl": 0.9, "forme": "sphere", "r": 0.25, "dir": HAUT, "ecart": 50.0, "vit": Vector2(1.2, 3.5), "amort": Vector2(1.0, 2.0), "grav": Vector3(0, 1.0, 0), "taille": Vector2(0.09, 0.18), "courbe": "bosse", "rampe": ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e"], "eclat": 1.4, "cap": 14.0},
	"ten_impact_sombre": {"n": 40, "vie": 1.2, "expl": 0.85, "forme": "sphere", "r": 0.3, "dir": HAUT, "ecart": 60.0, "vit": Vector2(0.8, 2.4), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.18, 0.34), "courbe": "bosse", "rampe": TEN_FUMEE, "eclat": 1.0, "cap": 16.0},
	"soin_impact": {"add": true, "n": 40, "vie": 1.2, "expl": 0.7, "forme": "sphere", "r": 0.4, "dir": HAUT, "ecart": 20.0, "vit": Vector2(0.4, 1.2), "taille": Vector2(0.02, 0.04), "rampe": SOIN, "cap": 4.0},
	"prot_impact": {"add": true, "n": 40, "vie": 0.8, "expl": 1.0, "forme": "anneau", "r": 0.5, "axe": HAUT, "radiale_v": Vector2(1.0, 2.0), "taille": Vector2(0.02, 0.03), "rampe": PROT, "cap": 4.0},
	# ---------------------------------------------------------------- zones (rayon réglé par zone)
	"feu_sol": {"n": 140, "vie": 0.8, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 15.0, "vit": Vector2(0.6, 1.6), "grav": Vector3(0, 1.2, 0), "taille": Vector2(0.1, 0.22), "courbe": "bosse", "rampe": FEU, "eclat": 1.35, "cap": 10.0},
	"feu_sol_braise": {"add": true, "n": 40, "vie": 1.4, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 30.0, "vit": Vector2(1.0, 2.5), "grav": Vector3(0, 0.3, 0), "taille": Vector2(0.015, 0.025), "rampe": BRAISE, "cap": 3.0},
	"feu_explosion": {"n": 120, "vie": 0.7, "expl": 1.0, "forme": "sphere", "r": 0.4, "dir": HAUT, "ecart": 180.0, "vit": Vector2(3.0, 7.0), "amort": Vector2(4.0, 6.0), "grav": Vector3(0, 2.0, 0), "taille": Vector2(0.15, 0.3), "courbe": "bosse", "rampe": FEU, "eclat": 1.35, "cap": 12.0},
	"feu_explosion_fumee": {"n": 30, "vie": 1.8, "expl": 0.9, "forme": "sphere", "r": 0.6, "dir": HAUT, "ecart": 180.0, "vit": Vector2(1.0, 3.0), "amort": Vector2(2.0, 3.0), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.4, 0.7), "courbe": "monte", "rampe": FUMEE, "eclat": 1.0, "cap": 12.0},
	"glace_nova_souffle": {"n": 80, "vie": 0.6, "expl": 1.0, "forme": "anneau", "r": 0.3, "axe": HAUT, "radiale_v": Vector2(5.0, 7.0), "taille": Vector2(0.08, 0.16), "courbe": "bosse", "rampe": GLACE, "eclat": 1.35, "cap": 9.0},
	"glace_nova_brume": {"n": 30, "vie": 2.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.05, 0.2), "taille": Vector2(0.3, 0.6), "courbe": "bosse", "rampe": ["#a8d8f850", "#5f9fe838", "#2f5fb820"], "eclat": 1.0, "cap": 12.0},
	"glace_scintille": {"add": true, "n": 30, "vie": 0.8, "forme": "disque", "r": 2.0, "dir": HAUT, "vit": Vector2(0.0, 0.1), "taille": Vector2(0.015, 0.025), "rampe": ["#e8f6ff", "#a8d8f8"], "eclat": 2.0, "cap": 3.0},
	"glace_eclats_zone": {"n": 30, "vie": 1.0, "expl": 1.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 50.0, "vit": Vector2(1.5, 4.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.06, 0.14), "mesh": "eclat", "pal": "glace"},
	"elec_sol": {"add": true, "n": 50, "vie": 0.3, "forme": "anneau", "r": 2.0, "axe": HAUT, "ecart": 180.0, "vit": Vector2(0.2, 1.0), "taille": Vector2(0.01, 0.02), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 3.0},
	"ten_sol": {"n": 90, "vie": 1.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 20.0, "vit": Vector2(0.4, 1.4), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.08, 0.18), "courbe": "bosse", "rampe": ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e"], "eclat": 1.35, "cap": 10.0},
	"ten_sol_sombre": {"n": 40, "vie": 1.6, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 20.0, "vit": Vector2(0.2, 0.8), "grav": Vector3(0, 0.4, 0), "taille": Vector2(0.2, 0.4), "courbe": "bosse", "rampe": TEN_FUMEE, "eclat": 1.0, "cap": 12.0},
	"ten_eruption": {"n": 70, "vie": 0.9, "expl": 1.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 25.0, "vit": Vector2(2.0, 5.0), "amort": Vector2(2.0, 3.0), "grav": Vector3(0, 0.5, 0), "taille": Vector2(0.1, 0.22), "courbe": "bosse", "rampe": ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e"], "eclat": 1.35, "cap": 10.0},
	"soin_sol": {"add": true, "n": 60, "vie": 1.6, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 5.0, "vit": Vector2(0.4, 1.0), "taille": Vector2(0.02, 0.04), "rampe": SOIN, "cap": 4.0},
	"prot_sol": {"add": true, "n": 60, "vie": 1.4, "forme": "anneau", "r": 2.0, "axe": HAUT, "dir": HAUT, "ecart": 3.0, "vit": Vector2(0.6, 1.4), "taille": Vector2(0.02, 0.035), "rampe": PROT, "cap": 4.0},
	# ---------------------------------------------------------------- statuts des cibles (boîte = corps de la cible)
	"brulure": {"n": 40, "vie": 0.55, "forme": "boite", "dir": HAUT, "ecart": 20.0, "vit": Vector2(0.3, 0.9), "grav": Vector3(0, 1.5, 0), "taille": Vector2(0.05, 0.11), "courbe": "bosse", "rampe": FEU, "eclat": 1.35, "cap": 9.0},
	"brulure_braise": {"add": true, "n": 12, "vie": 1.0, "forme": "boite", "dir": HAUT, "ecart": 40.0, "vit": Vector2(0.5, 1.2), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.01, 0.02), "rampe": BRAISE, "cap": 3.0},
	"gel": {"add": true, "n": 24, "vie": 1.0, "forme": "boite", "vit": Vector2(0.0, 0.1), "grav": Vector3(0, -0.2, 0), "taille": Vector2(0.012, 0.022), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.8, "cap": 3.0},
	"gel_brume": {"n": 10, "vie": 1.6, "forme": "boite", "vit": Vector2(0.0, 0.1), "grav": Vector3(0, -0.15, 0), "taille": Vector2(0.2, 0.35), "courbe": "bosse", "rampe": ["#a8d8f840", "#5f9fe830"], "eclat": 1.0, "cap": 10.0},
	"choc": {"add": true, "n": 20, "vie": 0.3, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.5, 2.0), "grav": Vector3(0, -6.0, 0), "taille": Vector2(0.008, 0.015), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 2.0},
	"corruption": {"n": 50, "vie": 1.2, "forme": "boite", "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.2, 0.6), "grav": Vector3(0, 0.3, 0), "taille": Vector2(0.1, 0.22), "courbe": "bosse", "rampe": TEN_FUMEE, "eclat": 1.0, "cap": 14.0, "turb": Vector2(0.05, 0.12), "turb_echelle": 2.0},
	"corruption_lueur": {"add": true, "n": 36, "vie": 0.8, "forme": "boite", "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.2, 0.6), "taille": Vector2(0.025, 0.05), "rampe": ["#f0d0ff", "#d08aff", "#9a3ae0", "#5a1a8a"], "eclat": 1.9, "cap": 6.0},
	# ---------------------------------------------------------------- enchantements d'arme (boîte = lame)
	"enchant_feu": {"n": 60, "vie": 0.35, "forme": "boite", "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.1, 0.4), "grav": Vector3(0, 1.6, 0), "taille": Vector2(0.02, 0.045), "courbe": "descend", "rampe": FEU, "cap": 6.0, "eclat": 1.6},
	"enchant_feu_braise": {"add": true, "n": 12, "vie": 0.6, "forme": "boite", "dir": HAUT, "ecart": 60.0, "vit": Vector2(0.2, 0.6), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.006, 0.01), "rampe": BRAISE, "cap": 2.0},
	"enchant_glace": {"add": true, "n": 30, "vie": 0.9, "forme": "boite", "vit": Vector2(0.0, 0.05), "grav": Vector3(0, -0.15, 0), "taille": Vector2(0.008, 0.016), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.7, "cap": 3.0},
	"enchant_glace_brume": {"n": 12, "vie": 1.2, "forme": "boite", "vit": Vector2(0.0, 0.08), "grav": Vector3(0, -0.2, 0), "taille": Vector2(0.05, 0.09), "rampe": ["#a8d8f860", "#5f9fe840"], "eclat": 1.0, "cap": 8.0},
	"enchant_elec": {"add": true, "n": 16, "vie": 0.25, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.3, 1.0), "taille": Vector2(0.004, 0.008), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 2.0},
	"enchant_ten": {"n": 30, "vie": 0.9, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.02, 0.12), "grav": Vector3(0, 0.15, 0), "taille": Vector2(0.03, 0.06), "courbe": "bosse", "rampe": TEN_FUMEE, "eclat": 1.0, "cap": 8.0},
	"enchant_ten_lueur": {"add": true, "n": 20, "vie": 0.6, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.03, 0.1), "taille": Vector2(0.008, 0.016), "rampe": VIOLET, "cap": 3.0},
	# ---------------------------------------------------------------- réactions entre écoles
	"vapeur": {"n": 60, "vie": 2.0, "expl": 0.9, "forme": "sphere", "r": 0.6, "dir": HAUT, "ecart": 80.0, "vit": Vector2(0.8, 2.8), "amort": Vector2(1.0, 2.0), "grav": Vector3(0, 0.9, 0), "taille": Vector2(0.45, 0.9), "courbe": "monte", "rampe": VAPEUR, "eclat": 1.1, "cap": 15.0},
	"vapeur_gouttes": {"add": true, "n": 24, "vie": 0.7, "expl": 1.0, "forme": "sphere", "r": 0.3, "dir": HAUT, "ecart": 90.0, "vit": Vector2(1.5, 3.5), "grav": Vector3(0, -6.0, 0), "taille": Vector2(0.012, 0.02), "rampe": ["#f6f8ff", "#e8f6ff", "#fcb53a"], "cap": 2.0},
	"obscur_sol": {"n": 100, "vie": 0.8, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 15.0, "vit": Vector2(0.6, 1.6), "grav": Vector3(0, 1.2, 0), "taille": Vector2(0.1, 0.22), "courbe": "bosse", "rampe": OBSCUR, "eclat": 1.35, "cap": 10.0},
	"obscur_sombre": {"n": 40, "vie": 1.2, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 15.0, "vit": Vector2(0.5, 1.2), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.14, 0.26), "courbe": "bosse", "rampe": TEN_FUMEE, "eclat": 1.0, "cap": 10.0},
	"violet_etincelles": {"add": true, "n": 40, "vie": 0.5, "expl": 1.0, "dir": HAUT, "ecart": 85.0, "vit": Vector2(2.0, 6.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.01, 0.02), "rampe": ["#f0d0ff", "#d08aff", "#9a3ae0"], "eclat": 2.0, "cap": 3.0},
	"corrompu_scintille": {"add": true, "n": 30, "vie": 0.9, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.2, 0.8), "taille": Vector2(0.015, 0.03), "rampe": ["#f0d0ff", "#b080ff", "#6a3ad0"], "eclat": 1.8, "cap": 3.0},
	"incendiaire_etincelles": {"add": true, "n": 50, "vie": 0.6, "expl": 1.0, "dir": HAUT, "ecart": 85.0, "vit": Vector2(3.0, 7.0), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.01, 0.02), "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f"], "eclat": 2.0, "cap": 3.0},
	"glace_trainee_eclats": {"n": 16, "vie": 0.5, "forme": "sphere", "r": 0.12, "ecart": 180.0, "vit": Vector2(0.2, 0.7), "grav": Vector3(0, -2.0, 0), "taille": Vector2(0.04, 0.09), "mesh": "eclat", "pal": "glace"},
	# ---------------------------------------------------------------- passe « spectaculaire » (couches, gerbes, paumes)
	"feu_aura_coeur": {"add": true, "n": 40, "vie": 0.25, "forme": "sphere", "r": 0.035, "dir": HAUT, "ecart": 40.0, "vit": Vector2(0.02, 0.1), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.02, 0.04), "courbe": "descend", "rampe": ["#fffbe8", "#fff0a8", "#fcb53a"], "cap": 10.0, "eclat": 1.6, "local": true},
	"glace_aura_eclats": {"n": 8, "vie": 0.9, "forme": "sphere", "r": 0.07, "dir": HAUT, "ecart": 50.0, "vit": Vector2(0.05, 0.15), "taille": Vector2(0.03, 0.06), "mesh": "eclat", "pal": "glace", "local": true},
	"elec_aura_lueur": {"add": true, "n": 24, "vie": 0.12, "forme": "sphere", "r": 0.03, "ecart": 180.0, "vit": Vector2(0.0, 0.05), "taille": Vector2(0.03, 0.06), "rampe": ["#f0f2ff", "#b4c0ff", "#4a3ad0"], "eclat": 1.4, "cap": 12.0, "local": true},
	"feu_jet_coeur": {"add": true, "n": 220, "vie": 0.5, "dir": AVANT, "ecart": 3.5, "vit": Vector2(8.0, 9.5), "taille": Vector2(0.07, 0.15), "courbe": "monte", "rampe": ["#fffbe8", "#fff0a8", "#fff0a8", "#fcb53a"], "cap": 9.0, "eclat": 1.5, "alea": 0.15},
	"feu_jet_bord": {"n": 150, "vie": 0.6, "dir": AVANT, "ecart": 12.0, "vit": Vector2(6.0, 8.0), "amort": Vector2(1.0, 2.0), "grav": Vector3(0, 0.5, 0), "taille": Vector2(0.2, 0.42), "courbe": "monte", "rampe": ["#ec6a1f", "#b3341f", "#b3341f", "#5a1a1c"], "cap": 14.0, "eclat": 1.35, "alea": 0.25},
	"feu_paume": {"add": true, "n": 50, "vie": 0.12, "forme": "sphere", "r": 0.015, "dir": AVANT, "ecart": 30.0, "vit": Vector2(0.05, 0.2), "taille": Vector2(0.03, 0.06), "courbe": "monte", "rampe": ["#fffbe8", "#fff0a8", "#fcb53a"], "cap": 12.0, "eclat": 1.5},
	"feu_gerbe": {"n": 160, "vie": 0.6, "forme": "boite", "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.6, 1.8), "grav": Vector3(0, 2.4, 0), "taille": Vector2(0.14, 0.3), "courbe": "bosse", "rampe": ["#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"], "eclat": 1.45, "cap": 14.0, "turb": Vector2(0.06, 0.16), "turb_echelle": 2.0, "turb_force": 2.0},
	"feu_gerbe_braise": {"add": true, "n": 40, "vie": 1.0, "forme": "boite", "dir": HAUT, "ecart": 60.0, "vit": Vector2(1.0, 3.0), "grav": Vector3(0, 0.4, 0), "taille": Vector2(0.012, 0.022), "rampe": BRAISE, "cap": 3.0, "turb": Vector2(0.2, 0.5), "turb_echelle": 2.0},
	"glace_jet_corps": {"n": 180, "vie": 0.55, "dir": AVANT, "ecart": 10.0, "vit": Vector2(6.0, 8.0), "amort": Vector2(0.5, 1.5), "taille": Vector2(0.12, 0.28), "courbe": "monte", "rampe": ["#e8f6ffd0", "#a8d8f8c0", "#5f9fe8a0", "#2f5fb880", "#1b2c5a50"], "eclat": 1.3, "cap": 13.0},
	"glace_paume": {"add": true, "n": 40, "vie": 0.12, "forme": "sphere", "r": 0.015, "dir": AVANT, "ecart": 30.0, "vit": Vector2(0.05, 0.2), "taille": Vector2(0.025, 0.05), "courbe": "monte", "rampe": ["#ffffff", "#e8f6ff", "#a8d8f8"], "cap": 10.0, "eclat": 1.5},
	"glace_gerbe": {"n": 60, "vie": 1.0, "forme": "boite", "vit": Vector2(0.05, 0.3), "grav": Vector3(0, 0.2, 0), "taille": Vector2(0.12, 0.26), "courbe": "bosse", "rampe": ["#e8f6ffb0", "#a8d8f8a0", "#5f9fe880", "#2f5fb850"], "eclat": 1.2, "cap": 16.0, "turb": Vector2(0.05, 0.12), "turb_echelle": 2.0},
	"glace_gerbe_cristal": {"n": 14, "vie": 0.8, "forme": "boite", "dir": HAUT, "ecart": 70.0, "vit": Vector2(0.8, 2.0), "grav": Vector3(0, -3.0, 0), "taille": Vector2(0.06, 0.14), "mesh": "eclat", "pal": "glace"},
	"elec_gerbe": {"add": true, "n": 50, "vie": 0.3, "forme": "boite", "ecart": 180.0, "vit": Vector2(0.8, 2.5), "grav": Vector3(0, -6.0, 0), "taille": Vector2(0.01, 0.02), "rampe": ["#ffffff", "#f0f2ff", "#b4c0ff", "#7a7af0"], "eclat": 2.0, "cap": 3.0},
	"elec_paume": {"add": true, "n": 40, "vie": 0.22, "expl": 0.3, "forme": "sphere", "r": 0.03, "ecart": 180.0, "vit": Vector2(0.8, 2.5), "grav": Vector3(0, -4.0, 0), "taille": Vector2(0.006, 0.012), "rampe": ["#ffffff", "#f0f2ff", "#b4c0ff"], "eclat": 2.0, "cap": 3.0},
	"ten_drain_eclats": {"n": 20, "vie": 0.6, "forme": "sphere", "r": 0.2, "dir": AVANT, "ecart": 8.0, "vit": Vector2(5.0, 7.0), "taille": Vector2(0.05, 0.1), "mesh": "eclat", "pal": "tenebres"},
	"ten_gerbe": {"n": 70, "vie": 1.0, "forme": "boite", "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.2, 0.8), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.12, 0.26), "courbe": "bosse", "rampe": TEN_FUMEE, "eclat": 1.0, "cap": 16.0, "turb": Vector2(0.05, 0.12), "turb_echelle": 2.0},
	"ten_gerbe_lueur": {"add": true, "n": 40, "vie": 0.7, "forme": "boite", "dir": HAUT, "ecart": 40.0, "vit": Vector2(0.3, 1.0), "taille": Vector2(0.02, 0.04), "rampe": ["#f0d0ff", "#d08aff", "#9a3ae0"], "eclat": 1.8, "cap": 6.0},
	"feu_trainee_braise": {"add": true, "n": 40, "vie": 0.8, "forme": "sphere", "r": 0.12, "ecart": 180.0, "vit": Vector2(0.3, 1.2), "grav": Vector3(0, -1.5, 0), "taille": Vector2(0.01, 0.018), "rampe": BRAISE, "cap": 3.0},
	"glace_impact_poudre": {"add": true, "n": 60, "vie": 0.9, "expl": 1.0, "forme": "sphere", "r": 0.15, "dir": HAUT, "ecart": 90.0, "vit": Vector2(1.0, 4.0), "amort": Vector2(2.0, 4.0), "grav": Vector3(0, -1.0, 0), "taille": Vector2(0.012, 0.025), "rampe": ["#ffffff", "#e8f6ff", "#a8d8f8"], "eclat": 1.9, "cap": 3.0},
	"ten_impact_eclats": {"n": 24, "vie": 0.9, "expl": 1.0, "dir": HAUT, "ecart": 80.0, "vit": Vector2(2.0, 5.0), "grav": Vector3(0, -5.0, 0), "taille": Vector2(0.06, 0.13), "mesh": "eclat", "pal": "tenebres"},
	"corruption_eclats": {"n": 12, "vie": 1.4, "forme": "boite", "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.1, 0.4), "grav": Vector3(0, 0.2, 0), "taille": Vector2(0.05, 0.1), "mesh": "eclat", "pal": "corrompu"},
}

# ====================================================================== couche fine (détail des sorts Moyen / Élevé)
## Réglages FINS (GestionMagie.fin_actif, voir docs/MAGIE_EFFETS.md) : chaque réglage de R devient plus petit (« t »,
## multiplie `taille`) et plus nombreux (« n », multiplie `n`) ; « sur » remplace des clés ; « avec » ajoute des couches
## compagnes (réglages R_FIN, fondus dans R) qui suivent l'émetteur : étincelles, flammèches, poudre de givre, cristaux,
## crépitements, poussière aspirée… Sans entrée : n × 2,6 et taille × 0,5 (cristaux : × 1,8 et × 0,7 ; étincelles déjà
## fines : × 2,2 et × 0,6). Les compagnons (« *_fin_* ») sont réglés directement en tailles fines.
const BLANC_FEU := ["#ffffff", "#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"]
const BLANC_GLACE := ["#ffffff", "#f4fbff", "#e8f6ff", "#a8d8f8", "#5f9fe8"]
const BLANC_ELEC := ["#ffffff", "#f0f2ff", "#d0d8ff", "#b4c0ff", "#7a7af0", "#4a3ad0"]
const VIOLET_VIF := ["#ffe8ff", "#f0d0ff", "#d08aff", "#b060f0", "#9a3ae0", "#5a1a8a"]
const TEN_ASPIRE := ["#0c0614f0", "#1a0a28f0", "#2a0e3ee0", "#5a1a8ad0", "#9a3ae0c0"]

const FIN := {
	# feu
	"feu_aura": {"etire": 2, "avec": ["feu_fin_flammeche", "feu_fin_etincelle"]},
	"feu_aura_coeur": {"etire": 2, "sur": {"eclat": 2.2}},
	"feu_jet": {"etire": 2.0, "n": 1.2, "t": 0.22, "avec": ["feu_fin_jet_etincelles", "feu_fin_jet_flammeches"]},
	"feu_jet_coeur": {"etire": 2.0, "n": 1.0, "t": 0.22, "sur": {"eclat": 2.2, "rampe": ["#ffffff", "#fffbe8", "#fff0a8", "#fff0a8", "#fcb53a"]}},
	"feu_jet_bord": {"etire": 1.5, "n": 1.2, "t": 0.22},
	"feu_paume": {"n": 0.7, "t": 0.45, "sur": {"eclat": 2.4}, "avec": ["feu_fin_paume_etincelles"]},
	"feu_gerbe": {"etire": 2, "n": 0.8, "t": 0.16, "avec": ["feu_fin_gerbe_langues", "feu_fin_gerbe_etincelles"]},
	"feu_lechage": {"etire": 2, "n": 1.4, "t": 0.15, "avec": ["feu_fin_eclats_braise"]},
	"feu_impact": {"etire": 1.5, "avec": ["feu_fin_eclats_braise", "feu_fin_flash"]},
	"feu_explosion": {"etire": 1.5, "avec": ["feu_fin_eclats_braise", "feu_fin_explosion_langues"]},
	"feu_trainee": {"etire": 1.5, "n": 2.6, "t": 0.22, "avec": ["feu_fin_trainee_etincelles"]},
	"feu_boule_coeur": {"n": 2.0, "t": 0.22, "sur": {"eclat": 2.0}, "avec": ["feu_fin_boule_volutes"]},
	"feu_sol": {"etire": 2, "avec": ["feu_fin_sol_langues"]},
	"brulure": {"etire": 2, "avec": ["feu_fin_brulure_langues"]},
	"enchant_feu": {"avec": ["feu_fin_enchant"]},
	# glace
	"glace_aura": {"avec": ["glace_fin_poudre", "glace_fin_givre"]},
	"glace_aura_cristal": {"n": 2.2, "t": 0.5},
	"glace_jet": {"etire": 3, "n": 2.2, "t": 0.5, "avec": ["glace_fin_jet_poudre"]},
	"glace_jet_corps": {"etire": 2, "n": 1.2, "t": 0.25, "avec": ["glace_fin_jet_cristaux"]},
	"glace_paume": {"sur": {"eclat": 2.2}, "avec": ["glace_fin_paume_poudre"]},
	"glace_gerbe": {"avec": ["glace_fin_gerbe_poudre"]},
	"glace_impact": {"avec": ["glace_fin_impact_poudre", "glace_fin_impact_cristaux"]},
	"glace_trainee": {"avec": ["glace_fin_trainee_poudre"]},
	"glace_nova_souffle": {"avec": ["glace_fin_nova_poudre"]},
	"glace_bouffee": {"avec": ["glace_fin_impact_poudre"]},
	"gel": {"avec": ["glace_fin_gel_givre"]},
	"enchant_glace": {"avec": ["glace_fin_enchant"]},
	# électricité (les arcs eux-mêmes : GestionMagie.foudre, plus de niveaux en couche fine)
	"elec_aura": {"etire": 3, "n": 2.2, "avec": ["elec_fin_etincelles", "elec_fin_lueur"]},
	"elec_paume": {"etire": 4, "n": 0.6, "avec": ["elec_fin_paume"]},
	"elec_gerbe": {"etire": 4, "n": 2.2, "avec": ["elec_fin_crepite"]},
	"elec_impact": {"etire": 5, "n": 2.2, "avec": ["elec_fin_crepite"]},
	"elec_etincelles": {"etire": 5, "n": 3.0},
	"elec_trainee": {"etire": 3, "n": 2.2, "avec": ["elec_fin_trainee"]},
	"elec_sol": {"n": 2.2, "avec": ["elec_fin_sol"]},
	"choc": {"etire": 4, "n": 2.2, "avec": ["elec_fin_choc"]},
	"enchant_elec": {"n": 3.0},
	# ténèbres
	"ten_aura": {"etire": 1.5, "avec": ["ten_fin_aspire", "ten_fin_eclats"]},
	"ten_aura_lueur": {"sur": {"eclat": 2.0}},
	"ten_drain_sombre": {"etire": 2.5, "n": 1.2, "t": 0.25, "avec": ["ten_fin_drain_poussiere"]},
	"ten_drain_rouge": {"etire": 3, "avec": ["ten_fin_drain_lueur"]},
	"ten_trainee": {"avec": ["ten_fin_trainee_volutes"]},
	"ten_coeur": {"avec": ["ten_fin_coeur_aspire"]},
	"ten_impact": {"avec": ["ten_fin_impact_debris", "ten_fin_eclats"]},
	"ten_gerbe": {"avec": ["ten_fin_gerbe_filaments"]},
	"ten_sol": {"avec": ["ten_fin_sol_filaments"]},
	"ten_eruption": {"avec": ["ten_fin_impact_debris"]},
	"corruption": {"avec": ["ten_fin_corruption_volutes"]},
	"enchant_ten": {"avec": ["ten_fin_enchant"]},
	"feu_jet_braise": {"etire": 5},
	"feu_impact_braise": {"etire": 5},
	"glace_impact_poudre": {"etire": 3},
	"feu_gerbe_braise": {"etire": 3},
	"feu_trainee_braise": {"etire": 4},
	"incendiaire_etincelles": {"etire": 5},
	"violet_etincelles": {"etire": 5},
}

const R_FIN := {
	# ---- feu : flammèches (petites langues claires), étincelles d'un pixel, braises qui retombent
	"feu_fin_flammeche": {"etire": 3, "add": true, "n": 96, "vie": 0.3, "forme": "sphere", "r": 0.045, "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.06, 0.2), "grav": Vector3(0, 0.9, 0), "taille": Vector2(0.004, 0.009), "courbe": "descend", "rampe": BLANC_FEU, "eclat": 1.8, "cap": 4.0, "local": true, "turb": Vector2(0.08, 0.2), "turb_echelle": 8.0},
	"feu_fin_etincelle": {"etire": 4, "add": true, "n": 30, "vie": 0.9, "forme": "sphere", "r": 0.07, "dir": HAUT, "ecart": 50.0, "vit": Vector2(0.15, 0.45), "grav": Vector3(0, 0.3, 0), "taille": Vector2(0.002, 0.004), "rampe": ["#ffffff", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "eclat": 2.0, "cap": 2.0, "local": true, "turb": Vector2(0.15, 0.4), "turb_echelle": 5.0},
	"feu_fin_jet_etincelles": {"etire": 5, "add": true, "n": 120, "vie": 0.5, "dir": AVANT, "ecart": 9.0, "vit": Vector2(6.0, 10.0), "amort": Vector2(0.5, 1.5), "grav": Vector3(0, -0.6, 0), "taille": Vector2(0.006, 0.014), "rampe": ["#ffffff", "#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "eclat": 2.0, "cap": 3.0, "alea": 0.3},
	"feu_fin_jet_flammeches": {"etire": 3, "n": 156, "vie": 0.5, "dir": AVANT, "ecart": 11.0, "vit": Vector2(6.5, 9.0), "amort": Vector2(0.8, 1.8), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.02, 0.06), "courbe": "bosse", "rampe": ["#fff0a8", "#fcb53a", "#ec6a1f", "#ec6a1f", "#b3341f", "#5a1a1c"], "eclat": 1.6, "cap": 7.0, "alea": 0.25},
	# jet de flammes continu (couche fine) : le corps est le flux procédural (magie_flux) ; ici, seulement le détail
	# fin qui s'en échappe. Langues : petites flammes claires étirées qui filent sur les bords du cône. Escarbilles
	# (« libre » : vie propre, elles dépassent la cible) : freinées, elles tourbillonnent et montent ; retombée : braises
	# plus lourdes qui retombent vers le sol.
	"feu_fin_jet_langues": {"etire": 4, "add": true, "n": 150, "vie": 0.45, "dir": AVANT, "ecart": 10.0, "vit": Vector2(6.0, 8.5), "amort": Vector2(0.6, 1.6), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.008, 0.02), "courbe": "bosse", "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "eclat": 1.7, "cap": 4.0, "alea": 0.3},
	"feu_fin_jet_escarbilles": {"libre": true, "etire": 4, "add": true, "n": 170, "vie": 1.0, "dir": AVANT, "ecart": 16.0, "vit": Vector2(3.0, 9.0), "amort": Vector2(3.0, 6.0), "grav": Vector3(0, 0.7, 0), "taille": Vector2(0.003, 0.007), "rampe": ["#ffffff", "#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "eclat": 2.1, "cap": 1.2, "alea": 0.5, "turb": Vector2(0.15, 0.45), "turb_echelle": 1.5, "turb_force": 3.0},
	"feu_fin_jet_retombee": {"libre": true, "etire": 4, "add": true, "n": 50, "vie": 1.1, "dir": AVANT, "ecart": 13.0, "vit": Vector2(4.0, 7.5), "amort": Vector2(0.8, 1.5), "grav": Vector3(0, -4.5, 0), "taille": Vector2(0.004, 0.009), "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "eclat": 2.0, "cap": 1.5, "alea": 0.4},
	"feu_fin_paume_etincelles": {"etire": 4, "add": true, "n": 36, "vie": 0.25, "forme": "sphere", "r": 0.02, "dir": AVANT, "ecart": 60.0, "vit": Vector2(0.4, 1.4), "taille": Vector2(0.003, 0.006), "rampe": ["#ffffff", "#fffbe8", "#fff0a8", "#fcb53a"], "eclat": 2.2, "cap": 2.0},
	"feu_fin_gerbe_langues": {"etire": 3, "n": 156, "vie": 0.5, "dir": HAUT, "ecart": 18.0, "vit": Vector2(0.8, 2.2), "grav": Vector3(0, 2.8, 0), "taille": Vector2(0.02, 0.05), "courbe": "descend", "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"], "eclat": 1.6, "cap": 6.0, "turb": Vector2(0.08, 0.2), "turb_echelle": 3.0, "turb_force": 2.0},
	"feu_fin_gerbe_etincelles": {"etire": 4, "add": true, "n": 42, "vie": 0.6, "dir": HAUT, "ecart": 45.0, "vit": Vector2(0.8, 2.2), "grav": Vector3(0, 0.6, 0), "taille": Vector2(0.004, 0.008), "rampe": ["#ffffff", "#fff0a8", "#fcb53a", "#ec6a1f"], "eclat": 2.0, "cap": 2.0, "turb": Vector2(0.2, 0.5), "turb_echelle": 2.0},
	"feu_fin_eclats_braise": {"etire": 5, "add": true, "n": 84, "vie": 0.7, "expl": 1.0, "forme": "sphere", "r": 0.1, "dir": HAUT, "ecart": 80.0, "vit": Vector2(2.0, 7.0), "amort": Vector2(1.0, 2.0), "grav": Vector3(0, -6.0, 0), "taille": Vector2(0.006, 0.014), "rampe": ["#ffffff", "#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "eclat": 2.0, "cap": 3.0},
	"feu_fin_flash": {"add": true, "n": 54, "vie": 0.18, "expl": 1.0, "forme": "sphere", "r": 0.18, "ecart": 180.0, "vit": Vector2(0.2, 1.2), "taille": Vector2(0.03, 0.06), "courbe": "descend", "rampe": ["#ffffff", "#fffbe8", "#fff0a8"], "eclat": 2.4, "cap": 8.0},
	"feu_fin_explosion_langues": {"etire": 2.5, "n": 192, "vie": 0.8, "expl": 1.0, "forme": "sphere", "r": 0.5, "dir": HAUT, "ecart": 180.0, "vit": Vector2(2.0, 6.0), "amort": Vector2(3.0, 5.0), "grav": Vector3(0, 2.4, 0), "taille": Vector2(0.03, 0.08), "courbe": "bosse", "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"], "eclat": 1.6, "cap": 7.0, "turb": Vector2(0.05, 0.15), "turb_echelle": 2.0},
	"feu_fin_trainee_etincelles": {"etire": 4, "add": true, "n": 72, "vie": 0.6, "forme": "sphere", "r": 0.12, "ecart": 180.0, "vit": Vector2(0.3, 1.5), "grav": Vector3(0, -1.2, 0), "taille": Vector2(0.004, 0.009), "rampe": ["#ffffff", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "eclat": 2.0, "cap": 2.0},
	"feu_fin_boule_volutes": {"add": true, "n": 84, "vie": 0.3, "forme": "surface", "r": 0.17, "ecart": 180.0, "vit": Vector2(0.1, 0.5), "taille": Vector2(0.01, 0.025), "courbe": "descend", "rampe": BLANC_FEU, "eclat": 1.9, "cap": 4.0, "local": true, "turb": Vector2(0.2, 0.4), "turb_echelle": 6.0},
	"feu_fin_sol_langues": {"etire": 3, "n": 180, "vie": 0.7, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 12.0, "vit": Vector2(0.8, 2.0), "grav": Vector3(0, 1.6, 0), "taille": Vector2(0.02, 0.05), "courbe": "descend", "rampe": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"], "eclat": 1.6, "cap": 6.0, "turb": Vector2(0.05, 0.15), "turb_echelle": 2.0},
	"feu_fin_brulure_langues": {"etire": 3, "n": 66, "vie": 0.45, "dir": HAUT, "ecart": 15.0, "vit": Vector2(0.4, 1.2), "grav": Vector3(0, 2.0, 0), "taille": Vector2(0.015, 0.035), "courbe": "descend", "rampe": ["#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"], "eclat": 1.5, "cap": 5.0, "turb": Vector2(0.08, 0.2), "turb_echelle": 3.0},
	"feu_fin_enchant": {"etire": 3, "add": true, "n": 48, "vie": 0.3, "dir": HAUT, "ecart": 30.0, "vit": Vector2(0.1, 0.5), "grav": Vector3(0, 1.8, 0), "taille": Vector2(0.003, 0.007), "rampe": BLANC_FEU, "eclat": 2.0, "cap": 2.0},
	# ---- glace : poudre scintillante d'un pixel, flocons de givre, petits cristaux
	"glace_fin_poudre": {"add": true, "n": 84, "vie": 0.8, "forme": "sphere", "r": 0.1, "dir": HAUT, "ecart": 180.0, "vit": Vector2(0.01, 0.06), "grav": Vector3(0, 0.05, 0), "taille": Vector2(0.002, 0.005), "rampe": ["#ffffff", "#f4fbff", "#e8f6ff", "#a8d8f8", "#ffffff", "#5f9fe8"], "eclat": 2.2, "cap": 2.0, "local": true, "turb": Vector2(0.05, 0.12), "turb_echelle": 6.0},
	"glace_fin_givre": {"n": 54, "vie": 1.0, "forme": "sphere", "r": 0.085, "dir": HAUT, "ecart": 90.0, "vit": Vector2(0.01, 0.05), "grav": Vector3(0, -0.04, 0), "taille": Vector2(0.006, 0.014), "courbe": "bosse", "rampe": ["#f4fbffe0", "#e8f6ffd0", "#a8d8f8c0", "#5f9fe8a0", "#2f5fb880"], "eclat": 1.3, "cap": 3.0, "local": true},
	"glace_fin_jet_poudre": {"etire": 4, "add": true, "n": 216, "vie": 0.55, "dir": AVANT, "ecart": 13.0, "vit": Vector2(5.5, 9.0), "amort": Vector2(0.5, 1.5), "taille": Vector2(0.004, 0.01), "rampe": ["#ffffff", "#f4fbff", "#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8"], "eclat": 2.0, "cap": 2.0, "alea": 0.3},
	"glace_fin_jet_cristaux": {"n": 42, "vie": 0.6, "dir": AVANT, "ecart": 12.0, "vit": Vector2(6.0, 9.5), "taille": Vector2(0.03, 0.08), "mesh": "eclat", "pal": "glace"},
	"glace_fin_paume_poudre": {"etire": 3, "add": true, "n": 36, "vie": 0.3, "forme": "sphere", "r": 0.03, "ecart": 180.0, "vit": Vector2(0.1, 0.6), "taille": Vector2(0.003, 0.006), "rampe": BLANC_GLACE, "eclat": 2.2, "cap": 2.0},
	"glace_fin_gerbe_poudre": {"add": true, "n": 90, "vie": 0.9, "vit": Vector2(0.05, 0.4), "grav": Vector3(0, -0.3, 0), "taille": Vector2(0.003, 0.007), "rampe": BLANC_GLACE, "eclat": 2.0, "cap": 2.0},
	"glace_fin_impact_poudre": {"etire": 3, "add": true, "n": 108, "vie": 1.0, "expl": 1.0, "forme": "sphere", "r": 0.12, "dir": HAUT, "ecart": 90.0, "vit": Vector2(0.8, 5.0), "amort": Vector2(2.0, 4.0), "grav": Vector3(0, -1.2, 0), "taille": Vector2(0.003, 0.008), "rampe": ["#ffffff", "#f4fbff", "#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 2.1, "cap": 2.0},
	"glace_fin_impact_cristaux": {"n": 30, "vie": 1.0, "expl": 1.0, "dir": HAUT, "ecart": 80.0, "vit": Vector2(2.0, 6.5), "grav": Vector3(0, -9.0, 0), "taille": Vector2(0.025, 0.07), "mesh": "eclat", "pal": "glace"},
	"glace_fin_trainee_poudre": {"add": true, "n": 84, "vie": 0.6, "forme": "sphere", "r": 0.09, "ecart": 180.0, "vit": Vector2(0.05, 0.4), "grav": Vector3(0, -0.4, 0), "taille": Vector2(0.003, 0.007), "rampe": BLANC_GLACE, "eclat": 2.0, "cap": 2.0},
	"glace_fin_nova_poudre": {"etire": 4, "add": true, "n": 156, "vie": 0.8, "expl": 1.0, "forme": "anneau", "r": 0.3, "axe": HAUT, "radiale_v": Vector2(4.0, 7.5), "grav": Vector3(0, 0.3, 0), "taille": Vector2(0.004, 0.01), "rampe": BLANC_GLACE, "eclat": 2.0, "cap": 2.0},
	"glace_fin_gel_givre": {"n": 36, "vie": 1.4, "vit": Vector2(0.0, 0.06), "grav": Vector3(0, -0.12, 0), "taille": Vector2(0.006, 0.014), "rampe": ["#f4fbffd0", "#e8f6ffc0", "#a8d8f8a0", "#5f9fe880"], "eclat": 1.3, "cap": 3.0},
	"glace_fin_enchant": {"add": true, "n": 42, "vie": 0.9, "vit": Vector2(0.0, 0.05), "grav": Vector3(0, -0.1, 0), "taille": Vector2(0.002, 0.005), "rampe": BLANC_GLACE, "eclat": 2.1, "cap": 2.0},
	# ---- électricité : crépitement d'étincelles d'un pixel, lueur bleue
	"elec_fin_etincelles": {"etire": 3, "add": true, "n": 72, "vie": 0.18, "forme": "sphere", "r": 0.05, "ecart": 180.0, "vit": Vector2(0.6, 1.8), "taille": Vector2(0.002, 0.005), "rampe": BLANC_ELEC, "eclat": 2.2, "cap": 2.0, "local": true},
	"elec_fin_lueur": {"add": true, "n": 36, "vie": 0.1, "forme": "sphere", "r": 0.04, "ecart": 180.0, "vit": Vector2(0.0, 0.08), "taille": Vector2(0.01, 0.025), "rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0", "#4a3ad0"], "eclat": 1.5, "cap": 5.0, "local": true},
	"elec_fin_paume": {"etire": 4, "add": true, "n": 66, "vie": 0.2, "expl": 0.4, "forme": "sphere", "r": 0.03, "ecart": 180.0, "vit": Vector2(1.0, 3.5), "grav": Vector3(0, -5.0, 0), "taille": Vector2(0.002, 0.005), "rampe": BLANC_ELEC, "eclat": 2.2, "cap": 2.0},
	"elec_fin_crepite": {"etire": 5, "add": true, "n": 78, "vie": 0.25, "ecart": 180.0, "vit": Vector2(1.0, 4.0), "grav": Vector3(0, -7.0, 0), "taille": Vector2(0.003, 0.007), "rampe": BLANC_ELEC, "eclat": 2.2, "cap": 2.0},
	"elec_fin_trainee": {"etire": 3, "add": true, "n": 54, "vie": 0.2, "forme": "sphere", "r": 0.07, "ecart": 180.0, "vit": Vector2(0.5, 1.8), "taille": Vector2(0.002, 0.005), "rampe": BLANC_ELEC, "eclat": 2.2, "cap": 2.0},
	"elec_fin_sol": {"etire": 3, "add": true, "n": 84, "vie": 0.25, "forme": "anneau", "r": 2.0, "axe": HAUT, "ecart": 180.0, "vit": Vector2(0.3, 1.5), "taille": Vector2(0.003, 0.007), "rampe": BLANC_ELEC, "eclat": 2.2, "cap": 2.0},
	"elec_fin_choc": {"etire": 4, "add": true, "n": 42, "vie": 0.22, "ecart": 180.0, "vit": Vector2(0.6, 2.4), "grav": Vector3(0, -5.0, 0), "taille": Vector2(0.002, 0.005), "rampe": BLANC_ELEC, "eclat": 2.2, "cap": 2.0},
	# ---- ténèbres : poussière noire aspirée en spirale, éclats violets, volutes et filaments
	"ten_fin_aspire": {"etire": 3, "n": 132, "vie": 0.7, "forme": "surface", "r": 0.16, "ecart": 180.0, "vit": Vector2(0.0, 0.02), "radial": Vector2(-0.9, -0.5), "taille": Vector2(0.004, 0.01), "courbe": "descend", "rampe": TEN_ASPIRE, "eclat": 1.2, "cap": 3.0, "local": true, "turb": Vector2(0.08, 0.2), "turb_echelle": 6.0},
	"ten_fin_eclats": {"add": true, "n": 54, "vie": 0.6, "forme": "sphere", "r": 0.09, "ecart": 180.0, "vit": Vector2(0.05, 0.3), "grav": Vector3(0, 0.15, 0), "taille": Vector2(0.002, 0.006), "rampe": VIOLET_VIF, "eclat": 2.0, "cap": 2.0, "turb": Vector2(0.1, 0.3), "turb_echelle": 5.0},
	"ten_fin_drain_poussiere": {"etire": 3, "n": 180, "vie": 0.6, "forme": "sphere", "r": 0.22, "dir": AVANT, "ecart": 8.0, "vit": Vector2(5.0, 7.0), "taille": Vector2(0.008, 0.024), "courbe": "bosse", "rampe": ["#5a1a8ae0", "#2a0e3ee0", "#1a0a28e0", "#0c0614d0"], "eclat": 1.1, "cap": 4.0},
	"ten_fin_drain_lueur": {"etire": 4, "add": true, "n": 96, "vie": 0.5, "forme": "sphere", "r": 0.16, "dir": AVANT, "ecart": 6.0, "vit": Vector2(5.0, 7.0), "taille": Vector2(0.003, 0.008), "rampe": VIOLET_VIF, "eclat": 2.1, "cap": 2.0},
	"ten_fin_trainee_volutes": {"etire": 2, "n": 96, "vie": 0.7, "forme": "sphere", "r": 0.12, "ecart": 180.0, "vit": Vector2(0.05, 0.4), "grav": Vector3(0, 0.2, 0), "taille": Vector2(0.01, 0.03), "courbe": "bosse", "rampe": ["#5a1a8ae0", "#2a0e3ee0", "#0c0614c0"], "eclat": 1.1, "cap": 4.0, "turb": Vector2(0.08, 0.2), "turb_echelle": 3.0},
	"ten_fin_coeur_aspire": {"etire": 3, "n": 72, "vie": 0.35, "forme": "surface", "r": 0.24, "radial": Vector2(-1.6, -1.0), "taille": Vector2(0.004, 0.01), "rampe": TEN_ASPIRE, "eclat": 1.2, "cap": 3.0, "local": true},
	"ten_fin_impact_debris": {"n": 72, "vie": 1.0, "expl": 1.0, "forme": "sphere", "r": 0.2, "dir": HAUT, "ecart": 70.0, "vit": Vector2(1.5, 5.0), "amort": Vector2(1.0, 2.0), "grav": Vector3(0, -4.0, 0), "taille": Vector2(0.01, 0.03), "rampe": ["#0c0614", "#1a0a28", "#2a0e3e", "#0c0614"], "eclat": 1.0, "cap": 4.0},
	"ten_fin_gerbe_filaments": {"etire": 3, "n": 120, "vie": 0.9, "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.3, 1.0), "grav": Vector3(0, 0.7, 0), "taille": Vector2(0.008, 0.02), "courbe": "bosse", "rampe": ["#9a3ae0d0", "#5a1a8ae0", "#2a0e3ee0", "#0c0614c0"], "eclat": 1.2, "cap": 3.0, "turb": Vector2(0.1, 0.25), "turb_echelle": 3.0, "turb_force": 1.5},
	"ten_fin_sol_filaments": {"etire": 3, "n": 144, "vie": 1.0, "forme": "disque", "r": 2.0, "dir": HAUT, "ecart": 15.0, "vit": Vector2(0.5, 1.6), "grav": Vector3(0, 0.8, 0), "taille": Vector2(0.008, 0.022), "courbe": "bosse", "rampe": ["#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e", "#0c0614"], "eclat": 1.4, "cap": 3.0, "turb": Vector2(0.08, 0.2), "turb_echelle": 2.0},
	"ten_fin_corruption_volutes": {"etire": 2, "n": 66, "vie": 1.1, "dir": HAUT, "ecart": 25.0, "vit": Vector2(0.15, 0.5), "grav": Vector3(0, 0.3, 0), "taille": Vector2(0.008, 0.02), "courbe": "bosse", "rampe": ["#9a3ae0c0", "#5a1a8ad0", "#2a0e3ed0", "#0c0614b0"], "eclat": 1.2, "cap": 3.0, "turb": Vector2(0.08, 0.2), "turb_echelle": 3.0},
	"ten_fin_enchant": {"add": true, "n": 36, "vie": 0.6, "ecart": 180.0, "vit": Vector2(0.03, 0.12), "taille": Vector2(0.002, 0.005), "rampe": VIOLET_VIF, "eclat": 2.0, "cap": 2.0},
}

static var _fin_cache := {}

## Réglage fin d'un réglage de R : {"n": multiplicateur, "t": multiplicateur de taille, "sur": {…}, "avec": [...]}.
static func fin(nom: String) -> Dictionary:
	if _fin_cache.has(nom):
		return _fin_cache[nom]
	var d: Dictionary = R.get(nom, {})
	var f := {"n": 2.0, "t": 0.45}
	if R_FIN.has(nom):
		f = {"n": 1.0, "t": 1.0}
	elif String(d.get("mesh", "quad")) == "eclat":
		f = {"n": 1.4, "t": 0.7}
	elif d.has("taille") and (d.taille as Vector2).y <= 0.025:
		f = {"n": 1.6, "t": 0.6}
	f.merge(FIN.get(nom, {}), true)
	_fin_cache[nom] = f
	return f

static func _static_init() -> void:
	R.merge(R_FIN)

## Nom d'un réglage pour une école : `PresetsMagie.de("electricite", "trainee")` → "elec_trainee".
static func de(ecole: String, role: String) -> String:
	return "%s_%s" % [COURT.get(ecole, "feu"), role]
