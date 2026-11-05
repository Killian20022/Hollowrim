# Son : mixage, reverb, pas par matériau, interface (lot « son », 2026-11-05)

## Bus (scripts/mixage.gd, créés par `Jeu.creer_bus`)
```
Musique ───────────────────────────┐   Amplify « ducking » (-9 dB pendant un dialogue ou un finisher)
Ambiance ─┐                        ├─► Master  (limiteur dur, plafond -0,5 dB)
Effets ───┴─► SousTerre (Reverb) ──┤
Interface ─────────────────────────┘   UI, menus, voix de dialogue : jamais de reverb
```
- Volumes d'Options : Général → Master, Musique → Musique, Effets → Effets ; Ambiance et Interface suivent « Effets ».
- Routage automatique (`Mixage.bus_de`, appliqué par l'autoload Lancement aux lecteurs restés sur Master) : nœud Musique → Musique ;
  générateurs (vent, feu) et fichiers `ambiance_*` → Ambiance ; fichiers `ui_*` → Interface ; le reste → Effets.
  Les sons de combat et de magie fixent déjà « Effets » eux-mêmes (inchangés).

## Reverb « Sous-terre » (scripts/zone_son.gd + Mixage.zone_vers)
`ZoneSon` (enfant du monde, 4 relevés/s) lit la salle du joueur ; la reverb du bus SousTerre n'est ALLUMÉE que dans une salle :
| Salle | Source | room | damp | wet | pré-délai |
|---|---|---|---|---|---|
| dehors | — | — | — | 0 (effet éteint) | — |
| grotte | `grotte_acces.dedans` | 0,90 | 0,45 | 0,34 | 45 ms |
| crypte | `tertre.dedans` | 0,62 | 0,30 | 0,28 | 25 ms |
| maison | `Interieur.dedans` (halle, maisons, forge) | 0,20 | 0,75 | 0,14 | 8 ms |
Transition : fondu du mélange wet sur 1,2 s (d'une salle à l'autre : extinction en 0,36 s, changement de taille, remontée).

## Pas par matériau (scripts/materiau_sol.gd)
`MateriauSol.en(monde, pos)` : crypte/grotte → pierre ; intérieur du village et quai → bois ; eau (groupe `eaux`) → eau ; rues pavées et
pont → pierre ; sinon `Sol.matiere_en` : neige/croûte/piétinée → neige, terre/aiguilles/mousse → terre, roche/glace → pierre.
Fichiers : `pas_terre_00-07`, `pas_pierre_00-04`, `pas_bois_00-04`, `pas_eau_00-03` (neige : `footstep_snow_*` d'origine), `saut_00-02`.
Marche/course : volume du matériau (+4 dB en courant) ; saut : `saut_*` ; atterrissage : le pas du matériau plus grave (hauteur 0,70-0,82) et plus fort selon la chute.
Régénération : `python3 -I outils/generer_sons_nuit.py <sources> assets/sons` (paquets CC0 listés dans assets/LICENCES.md).

## Sons d'interface (`Sons.interface`, bus Interface, joués même en pause)
`ui_niveau` (montée de niveau), `ui_quete_debut` (quête commencée, si elle a plusieurs étapes), `ui_quete_fin`, `ui_ramasse` (objet du sol),
`ui_potion` (potion/nourriture), `ui_menu_ouvre` / `ui_menu_ferme` (menu du personnage).

## Test
`godot --headless --path . --script res://outils/test_son.gd -- --nouvelle` : bus, routage, limiteur, volumes, reverb éteinte dehors / allumée
dans crypte, grotte, maison (tailles décroissantes, fondus), ducking, pas sur neige / pavé / plancher, atterrissage.
