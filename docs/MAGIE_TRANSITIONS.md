# Magie : transition repos → lancer → fin, et double magie fusionnée

Retour de jeu : l'effet au repos (flamme runique, écoles, halo de runes) est validé ; au lancer, la main doit SE TRANSFORMER en
sort (pas de coupure), et deux mêmes sorts doivent donner UNE combinaison propre. Code : `scripts/magie/transition_sort.gd`.

## API (une `TransitionSort` par main)

`mains.magie.transition("gauche" | "droite")`, mise à jour chaque image par `MainSort._maj_transition`. Distribuée à :
`RunesOrbite.transition` (donc `NoyauEcole.runes.transition`) et `GestionMagie.transitions_aura[id_paume]` (aura, origine des jets).

| Champ | Sens |
|---|---|
| `canal` 0..1 | jet en cours : monte en 0,2 s, retombe en 0,3 s (jamais de saut) |
| `depart_p` 0..1 | départ d'un sort lancé (0,3 s) ; 1 = repos |
| `t_canal` | secondes depuis le début du jet (pour allonger un effet avec lui) |
| `fin_p` 0..1 | fin d'un jet (0,3 s) ; 1 = repos |
| `charge` 0..1 | charge lissée |
| `phase` | REPOS / CHARGE / DEPART / CANALISE / FIN ; `forme` = "jet" ou "lance" |
| `direction`, `longueur` | visée (monde) et distance au point visé, pendant jet / départ |
| `source` | origine d'un jet / projectile : paume + `decalage`, remontée de 12 cm au cœur de la boule tenue |
| `fusion` 0..1, `point`, `decalage` | double magie : milieu des paumes, et déplacement à ajouter à la position de la main |
| `puissance` | 1 seul, 1,45 en double fusionné (épaisseur, éclat, longueur) |
| `meneuse`, `anneau_commun` | la main qui lance ; vrai quand les deux mains sont fusionnées (UN seul anneau) |

Signaux : `charge_debutee`, `canalise_debutee`, `depart_lance(forme)`, `fini`.
Utilitaires : `TransitionSort.lisse(x)`, `TransitionSort.anneau_phase(k, n, cote)` (runes des deux mains intercalées).

## Brancher une école (glace, électricité, ténèbres)

1. **Runes de la main** : ajouter une entrée dans `RunesOrbite.MODE_JET` (modèle : "feu"). `jet` = hélice + cercles le long du jet,
   `depart` = traînée au lancer puis retour en orbite. Sans entrée, l'école garde l'orbite au repos (comportement d'avant).
2. **Noyau / aura** : lire `runes.transition` (NoyauEcole) pour rétrécir ou étirer le noyau pendant `canal`, gonfler à `depart_p`.
3. **Effet de lancer** : partir de `EffetsMagie.pos_origine(paume)` (= paume + `source`) et non de `paume.global_position` ;
   utiliser `puissance` pour l'épaisseur du jet fusionné. `LanceurSorts.lancer(..., decalage)` et `canaliser` le font déjà (`GestionMagie` aussi pour toutes les sources de jet).
4. **Double** : si `transition.double`, un seul effet de lancer part du point de fusion (la suiveuse n'en lance pas) ; ne pas
   dessiner deux cercles ou deux jets, utiliser `anneau_commun` et `puissance`.

## Feu (référence)

- Jet de flammes : la boule de la main se résorbe en foyer en 0,2 s (plus de marche), ses runes quittent l'orbite et glissent en
  hélice autour du jet (rotation, évasement du cône, estompées au bout), 5 cercles runiques avancent au rythme du jet ; fin : retour
  en orbite sur 0,3 s.
- Boule de feu : la boule gonfle, les runes filent le long du tir en traînée, puis reviennent orbiter en grossissant.
- Double feu : les deux flammes et leurs runes glissent vers le milieu des paumes (avec la charge), la suiveuse se fond dans la
  flamme de la meneuse, le jet / le projectile part du point de fusion, un seul anneau runique (runes intercalées), un seul jeu de cercles.
