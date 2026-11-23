# Liquides réalistes (branche monde/liquides, 2026-11-23)

Demande : « pour le liquide à l'intérieur des tonneaux, il faut pas que ça puisse faire une flaque dans les airs. Comme tous les
liquides dans ce jeu d'ailleurs, que ce soit le sang ou autre, il faut qu'ils aient leur propre physique, une vraie logique comme si
c'était réel ! »

Base : `combat/sang_v3` + fusion de `monde/cassables_partout`. Moteur : `scripts/liquides.gd` (`class_name Liquides`, un nœud
« Liquides » par scène). Interrupteur : `-- --sans-liquides` (ancien comportement exact : `CasseObjets.Flaque`, gouttes du sang v3).

## Clients

| Client | Ce qui passe par Liquides | API |
|---|---|---|
| Sang v3 (`Sang`, `SangV3`, `GouttesSang`, `SangLame`) | toutes les gouttes (giclées, plaies, lame, saignement) suivent un rayon et touchent par `Liquides.impact` ; giclure au mur → vraie coulure ; `Sang.flaque` sur une pente → coulure | **inchangée** (test_liquides vérifie chaque signature) |
| `CasseObjets.verser_liquide` (tonneau, jarre) | `Liquides.verser_contenant` | inchangée (paramètres optionnels ajoutés en fin : sorte, litres, vitesse, taille) |
| `ObjetVivant.casser` | contenu d'après `Liquides.contenu(genre, oid, ident)` : tonneau (bière 60 %, hydromel 20 %, eau 10 %, vin 10 %, 28 L), jarre (eau, vin, huile, lait, saumure, 3 L), cruche (eau / lait / vide), bouteille d'hydromel 0,6 L, potions 0,25 L (leur couleur) ; tirage par l'identifiant (le même chez tous les joueurs) | — |
| `EffetsSol.empreinte_pas` (joueur) | `Liquides.pas` : semelle mouillée dans une flaque fraîche → 3 à 7 empreintes de plus en plus pâles (sang, liquides épais : 7) | — |

## Sortes (`Liquides.SORTES`)

couleur fraîche / sèche / en vol / halo neige, viscosité (eau = 1), épaisseur de flaque (mm), absorption, séchage, durée de vie, reflet.

| Sorte | Rendu | Visc. | Film | Absorption | Sèche / s'efface |
|---|---|---|---|---|---|
| sang humain, de draugr, de troll, d'araignée | opaque (palettes du sang v3), fonce et devient mat | 4 / 6 / 5 / 3 | 3-3,5 mm | faible | 45-60 s / 150 s |
| eau, saumure | teinte multipliée (le support assombri : mouillé) | 1 | 2 mm | totale | 22-30 s / 45-60 s (s'évapore, film mince d'abord) |
| bière | ambre multiplié | 1,2 | 2,2 mm | forte | 35 s / 75 s |
| hydromel | ambre foncé, collant | 3 | 3 mm | moyenne | 90 s / 140 s |
| vin | rouge violacé multiplié, laisse une tache rosée | 1,1 | 2 mm | forte | 40 s / 120 s |
| huile | dorée, brillante, ne sèche pas | 7 | 2,5 mm | faible | 400 s / 220 s |
| lait | opaque blanc cassé | 1,3 | 2 mm | forte | 40 s / 70 s |
| potions (soin, magie, vigueur) | opaque, sa couleur, légère lueur | 1,6 | 2,2 mm | moyenne | 50 s / 90 s |

Surfaces (`Liquides.SURFACES`, `Liquides.surface(rayon)`) : méta `surface_liquide` du corps s'il en a une, sinon neige (sol dehors,
`EffetsSol.est_neige`), props (bois ou fer), souterrain (y < -8 : pierre), intérieur (bois), dehors (terre au sol, pierre aux murs).
pierre / métal : flaque brillante, film normal ; bois : boit un peu, reflet ×0,6, sèche plus vite ; terre : boit l'eau et la bière
(film ×1,7, séchage ×0,4) bien plus que le sang (absorption du sang faible) ; neige : tache diffuse plus foncée, sans aucun reflet,
liseré dilué, flaque plus petite (film ×3).

## Physique

- **Gouttes** (`GouttesSang`, pool unique de 96) : gravité, vitesse initiale, un rayon entre deux positions (une image sur deux) ;
  sorte + volume (mL) par goutte. Une goutte ne s'arrête jamais en l'air : en fin de vie (2 s) ou quand le pool plein reprend sa
  place, sa trajectoire est résolue d'un coup jusqu'au contact (pas de 0,08 s puis 0,25 s, 16 s au plus), sinon elle est perdue dans
  le vide. Une goutte qui touche un personnage est bue par ses habits.
- **Impact** (`Liquides.impact`) : rasante → tache allongée dans le sens du vol, sinon ronde ; > 3,5 m/s : 1 à 3 éclaboussures
  secondaires (pas sur la neige) ; dessous d'une table / plafond : tache + le reste retombe ; mur, pente : tache + **coulure** si
  la goutte est assez grosse (seuil × viscosité) ; sol quasi horizontal (normale.y > 0,85) : rejoint la flaque qui est là, sinon
  flaque (≥ 20 mL) ou tache ; dans un lac / une rivière (`Eau.contient`) : dilué, rien ne reste.
- **Coulures** (`Liquides.coulure`, 16 à la fois) : le filet descend la ligne de plus grande pente (vitesse ∝ 1/viscosité), se dépose
  (mL par m : épais = court), suit le mur et ses coudes (nouveau segment), se détache en goutte au bord, finit en tache / flaque sur
  le plat, ou en perle quand il est épuisé.
- **Flaques** (`Liquides.Flaque`, 24) : rayon = √(volume / épaisseur / π) (un tonneau ≈ 1,7 m, une jarre ≈ 0,6 m) ; 16 directions
  sondées : chacune s'arrête au mur (rayon rasant) ou au bord (sondes descendantes, affinées) ; la maille (éventail à deux couronnes)
  épouse le relief et est coupée net au bord ; ce qui ne tient pas (capacité = aire × film) **s'égoutte par les bords** (gouttes qui
  retombent : étagère → sol) ; pente : la flaque glisse et s'allonge vers l'aval ; étalement en paliers nets (plus lent si visqueux) ;
  le centre glisse vers ce qui arrive ; deux flaques de même sorte qui se touchent n'en font qu'une.
- **Contenants** (`Liquides.verser_contenant`) : 40 % en gerbe (gouttes de toutes tailles, vitesse de l'objet comprise : un objet lancé
  qui se brise répand un liquide qui retombe en suivant sa course), puis un filet qui faiblit (vidange) 0,5 à 2,2 s.
- **Vie** : `SangV3.Vieillissement` (horloge du jeu, deux fois par seconde tant qu'il reste des traces), étendu d'une durée de vie par
  trace : séchage en 6 paliers (bords minces d'abord), effacement en 6 paliers par épaisseur. Jamais de fondu ni de tramage.
- **Rendu** : un shader (`Liquides.CODE`) : opaque (sangs, lait, potions : couleur, reflet mouillé, lueur des potions) ou multiplié
  (eau, bière, vin, huile : le support assombri et teinté, quelques texels d'éclat sur une surface dure) ; flaques à bord procédural
  (lobes, bruit, texels de 1,25 cm) ; filets procéduraux.

## Plafonds / perf

Gouttes 96, flaques 24, taches de liquide 48, coulures en mouvement 16, segments de coulure 32, sources 6, empreintes 12 ; traces de
sang : pool du sang v3 (64). Rien ne tourne au repos : `Liquides._process` (pas de 1/20 s) s'arrête dès qu'il n'y a plus ni source,
ni coulure, ni flaque qui s'étale ou s'égoutte ; GouttesSang sans `_process` sans goutte. Une flaque se reconstruit (≈ 150 rayons) au
plus toutes les 0,25 s et seulement si son rayon gagne 18 %.

## Coop

La casse passe déjà par l'évènement `objet_casse` (CasseObjets / ObjetsVivants) : chaque poste rejoue la casse, donc le versement, avec
le même contenu (tiré de l'identifiant). Gouttes, coulures et flaques sont cosmétiques et locales (positions exactes non synchronisées).

## Outils

- Test : `outils/test_liquides.gd` (dans `tous_les_tests.sh`).
- Film / planche / banc : `outils/film_liquides.gd -- --sortie=<dossier> [--planche] [--banc] [--sans-liquides]`.
