# Finishers v2 (branche combat/finishers_v2, 2026-11-03)

Retour utilisateur : « les finishers doivent être plus FLUIDES, plus PROPRES, et suivre VRAIMENT les mouvements 3D que j'ai
téléchargés ». Méthode retenue = celle des coups v5/v6 : captures Mixamo / Quaternius UAL2 RECIBLÉES (pas de poses écrites à la
main : « poignet qui se casse »). Les anciens clips à clés écrites à la main sont gardés sous `<clip>_main` (comparaison avant / après).

## 1. Inventaire AVANT (e5c50e8f)

| Finisher (`Finishers.CATALOGUE`) | Contexte | Bras FPS (`bras_finishers.tres`) | Corps 3e personne | Victime |
|---|---|---|---|---|
| plantee | de face, étourdi / après parade / presque mort | `fin_plantee` : poses clés écrites | Sword_Attack (ancien coup) | 6 clés de pose additives (`PoseFinisher`) puis ragdoll « effondre » |
| dos | dans le dos (> 120°) | `fin_plantee` (même clip) | idem | clés de pose, ragdoll « effondre » |
| pommeau | après parade, rotation de face | `fin_pommeau` : poses écrites | idem | clés de pose |
| decapitation | de côté ou de face | `fin_decapitation` : poses écrites | idem | clés de pose minimales, ragdoll + `Decapitation` |
| plonge | à terre (« sol ») | `fin_plonge` : poses écrites | idem | clés de pose (spasmes) sur le cadavre au sol, ragdoll « cloue » |
| (troll, mannequin) | hors gabarit | `finisher_taille` / `finisher_sol` (GestesDefense) | idem | mort courte |

## 2. Captures choisies (APRÈS)

| Finisher | Bras FPS (clip) | Capture source | Corps TPS (`CorpsCoupsTps.CLIPS`) | Victime (clip `Fin_*`, `animations_finishers.res`) |
|---|---|---|---|---|
| plantee | `fin_plantee` | Mixamo `Stabbing.fbx` (images 2 -> 14 estoc, 14 -> 26 tenue plantée, 26 -> 50 retrait) | même capture, `marq` calé sur les marqueurs du clip FPS | `Fin_Agonie` = `zombie_pack/zombie agonizing.fbx` (courbé sur la lame, mains au ventre), ragdoll à « mort » |
| dos | `fin_plantee` | idem | idem | `Fin_ArriereGS` = `great_sword_pack/two handed sword death (2).fbx` (cambré, tête rejetée, tombe à genoux), ragdoll à « mort » |
| decapitation | `fin_decapitation` | Quaternius UAL2 `Sword_Regular_Combo` 3e coup (celui du coup v6 « taille », validé), armé ralenti | idem | ragdoll + décapitation au contact (le corps ne peut pas rester debout sans tête) |
| plonge | `fin_plonge` | Mixamo `Standing Melee Attack Downward.fbx` (l'épée monte 2 -> 19, s'abat 21 -> 27, reste enfoncée, retrait 27 -> 40) | idem | cadavre au sol : `PoseFinisher` conservé (spasmes), aucune capture de victime au sol dans les packs |
| pommeau | `fin_pommeau` (ancien, écrit à la main) | aucune capture de coup de pommeau dans les packs téléchargés | ancien | `PoseFinisher` ; RETIRÉ de la rotation (reste forçable : `Finishers.force`) ; « après parade » joue maintenant `plantee` |

Candidates examinées (planches de squelette, vue de côté) puis écartées : `sword and shield death` (chute en arrière : se prête à un
recul, pas à une lame plantée), `two handed sword death` (assis puis chute arrière : variante gardée dans la bibliothèque
`Fin_PlieGS` pour essais), `Falling Back Death` (projeté en arrière : coup lourd, pas un finisher), `sword and shield impact` (`Fin_ChocSS`, choc bref).

## 3. Chaîne technique

1. `sources_blender/scripts/extraire_mixamo_finishers.py` (Blender, fbx hors dépôt) -> `sources_blender/mixamo/finishers_mixamo.json`
   (rotations monde par os, repère Godot, même format que le zombie pack).
2. `godot --headless --script res://outils/zombie_retarget.gd -- --source=res://sources_blender/mixamo/finishers_mixamo.json
   --sortie=res://assets/modeles/humains/animations_finishers.res` : report sur le squelette Quaternius des draugrs / humains / squelettes.
   `Humain.bibliotheque()` fusionne ces clips (`Fin_*`) dans la bibliothèque de chaque humanoïde.
3. `sources_blender/scripts/gestes_finishers.py` (Blender, `bras_fps.blend`) : `fin_plantee`, `fin_decapitation`, `fin_plonge` par
   `creer_action_mixamo` (directions du bras, main anatomique, poignet verrouillé comme les coups v6, fondu depuis / vers la garde) ->
   `assets/animations/bras_finishers.tres`.
4. Corps TPS : entrées `fin_*` dans `CorpsCoupsTps.CLIPS` (`marq` : noms des marqueurs du clip FPS auxquels les images de la capture
   sont calées, tenue plantée comprise) : le corps rejoue la même capture, au même instant que les bras.
5. Victime : `Finishers.CATALOGUE[...]["victime"] = {clip, carte}` ; `SequenceFinisher._reaction` démarre le clip au contact (fondu
   0,12 s depuis l'attente) puis asservit sa vitesse de lecture sur la carte [instant du finisher, temps dans la capture] ; à « mort »
   le ragdoll repart de la pose courante (pas de saut). Sans le clip (autre squelette), repli sur `PoseFinisher`.
6. Gore inchangé (entrée de lame, jet pulsé, flaque, retrait, décapitation, démembrement selon l'option), toujours calé sur les marqueurs du clip
   (`contact`, `plante`, `retrait`, `mort`). Caméra : tassement 0,7 -> 0,45 et secousse du retrait 0,35 -> 0,2 (les options Secousses / Balancement de
   `CameraCorps` s'appliquent comme avant).

## 4. Avant / après

`outils/captures_finishers_v2.gd -- --film --vue=fps|tps|cote [--ancien] [--finishers=...]` : `--ancien` rejoue les clips `_main` et
les clés de pose (comparaison dans le même build). Vidéos : `Desktop\\Skyrim captures\\finishers_v2\\`.
