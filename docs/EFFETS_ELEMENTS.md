# Effet passif d'élément des lames

Branche `armes/effets_elements` (2026-11-19). Toute arme dont `DonneesArme.element_type` est posé montre en permanence un petit effet pixel le long de son **segment tranchant réel** (nœuds vides `garde` / `pointe` du modèle si `reperes_du_modele`, sinon `DonneesArme.garde` / `pointe`), de 8 % à 97 % du segment.

Code : `scripts/combat/effet_element_lame.gd` (`EffetElementLame`), shaders `shaders/lame_element*.gdshader*`.

## Par élément

| Élément | Couches (particules au repos / au renfort) |
|---|---|
| feu | braises jaune → orange → rouge qui montent et traînent derrière un coup (25/40) + pixels orange collés au fil qui s'allument et s'éteignent, plus réguliers (24/38) |
| glace | éclats de givre blanc-bleu fixés au fil qui scintillent (cycle 1,1 s) (25/40) + cristaux qui tombent (9/14) + vapeur froide pâle qui coule (10/16) |
| electricite | rafales d'étincelles à traînée d'un pixel, toutes les 0,2-0,75 s (20 par rafale) + grésillement bleu-violet du fil (19/30) + arcs en zigzag d'un pixel (lignes, 8 variantes pré-calculées) montrés 50-90 ms toutes les 0,25-0,9 s |
| tenebres | voile de fumée violette collé à la lame, lisible de nuit en 1re personne (9/14) + fumée qui monte en ondulant (turbulence) (16/26) + braises violettes (19/30) |

Renfort (×1,6 particules, rafales et arcs plus serrés) pendant la charge de l'attaque puissante et le coup lourd (lu sur `mains.gd` : `combat.etat`, `_charge`, `_lourd`).

Aucune arme du jeu ne porte l'électricité pour l'instant : l'effet est prêt (capturé avec une épée d'acier d'essai).

Réglage v2 (2026-11-19, retour « on peut monter d'un petit cran ») : +30-35 % de particules, lueur du fil plus marquée et plus régulière, fumée des ténèbres plus claire, rafales électriques plus fréquentes. Version d'avant : commit d5daac53.

## Où c'est visible

- **Joueur, 1re personne** : `mains._installer_arme` (sous `_modele_arme_d`).
- **Joueur, 3e personne** : `CorpsMainsTps._maj_arme_d` (sous la copie `ArmeTps`) ; visible seulement à la 3e personne (à la 1re, l'arme du corps ne projette que son ombre).
- **Coop** : les avatars distants sont des `joueur.gd` qui rejouent l'équipement reçu (`AvatarDistant.appliquer_equipement` → `EquipementMains.equiper` → `mains._installer_arme` → `CorpsMainsTps`) : l'élément vient des données de l'arme (identifiant répliqué), rien à envoyer en plus. Portée d'affichage 28 m sur les avatars.
- **PNJ / ennemis** : `ArmesEnnemis.poser` (aujourd'hui seul le jarl porte une arme à élément : la hache de Kolbeinn, glace). `ArmesEnnemis.donnees_arme(id)` lit `data/armes/<id>.tres` avant le catalogue.
- **Au sol, au râtelier, sur le corps d'un ennemi** : `ObjetMonde.visuel` (poses autres que `studio` : pas sur les icônes).

## Coût

- ~31 à 49 particules émises par arme au repos (62 % de l'allocation), 50 à 78 allouées par arme (renfort compris) ; GPUParticles3D, aucun script par particule.
- Matériaux partagés : un matériau de dessin par réglage, un matériau de process par couche et par longueur de lame (arrondie à 5 cm) ; créés au chargement (`PrechauffeCombat.caches` → `EffetElementLame.prechauffer`) et compilés dans la vitrine de préchauffage. Les émetteurs sont construits dans `_ready` (fil principal) : `poser` peut être appelé hors de l'arbre.
- **Aucune lumière dynamique** (limite de 8 lumières du rendu Mobile) : la « lueur » est faite de pixels additifs.
- Hors joueur : `visibility_range_end` = 28 m. Effet caché (mains cachées, vue) : émission coupée.

## Comparer / couper

`--sans-effet-element` (ligne de commande) ou `EffetElementLame.actif = false` avant d'équiper.

## Vérifier

- Test : `godot --headless --fixed-fps 60 --path . --script res://outils/test_effets_elements.gd -- --nouvelle`
- Captures (fenêtre hors écran, `godot_slot.sh`) : `--resolution 960x540 --fixed-fps 30 --script res://outils/captures_effets_elements.gd -- --nouvelle --sortie=<dossier> [--parties=images,film,planche]`
