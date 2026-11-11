# Économie de Hollowrim — audit et équilibrage (branche `gameplay/economie`, 2026-11-11)

Fichiers : `scripts/marchand.gd`, `scripts/rpg/formation.gd` (nouveau), `scripts/rpg/services_pnj.gd` (une ligne),
`data/marchands.json`, `data/villageois.json` (Bersi), `data/vie/planning.json`, `data/batiments.json` (lit de Bersi), `scripts/pnj_nordique.gd` (une variante de teinte),
`outils/test_economie.gd`, `outils/captures_receleur.gd`. Voir aussi docs/BUTIN.md §9 (marchands) et docs/RPG.md.

## 1. Audit chiffré (avant)

Repères : une journée de jeu dure 40 min réelles, donc **1 h de jeu ≈ 1,5 jour de jeu**. Les prix suivent
`achat = ceil(valeur × achat × (1 − faveur))` et `rachat = floor(valeur × vente × (1 + faveur))` ; la faveur (bijoux et armures à
effet « prix », disposition du marchand ±15 %, remise de rang de faction) est bornée à −0,5..0,6.

### Marchands (avant)

| | Brodd (forge) | Grima (remèdes) |
|---|---|---|
| bourse par période | 600 | 300 |
| réassort | 2 jours (80 min réelles) | 2 jours |
| achat / rachat | 110 % / 40 % | 115 % / 40 % |
| valeur moyenne de l'étal | ~1 040 pièces (armes, armures, minerais) | ~1 130 pièces (6 tomes, potions, vivres) |
| exemples | minerai de fer 12 → 14 / 4 ; épée d'or 180 → 198 / 72 | potion de soin 30 → 35 / 12 ; tome Boule de feu 120 → 138 |

Le stock et la bourse limités, le réassort tous les 2 jours et les prix selon la réputation existaient déjà (lots L8, E et
disposition) : ils restent tels quels.

### Ce que gagne le joueur (ordre de grandeur, par heure de jeu type « une sortie en donjon »)

| source | pièces |
|---|---|
| or des corps (draugr 4-14, bandit 6-22, mage 10-25) : ~12 corps | ~150 |
| coffres (crypte 8-30, riche 30-70, boss 80-160, bandits 10-40) : ~4 | ~150 |
| urnes, caisses, sacs (0-15) | ~30 |
| revente du butin (armures palier 2-3 : fer 40-120, acier 75-300 ; bijoux 15-85 ; armes) à 40 % | 600-1 000 de valeur, **plafonnée par les bourses : 900 par 2 jours ≈ 675 / h** |
| quêtes (12 quêtes : 650 pièces en tout, une fois) | ~100 en moyenne sur les premières heures |
| **total** | **≈ 1 000 pièces / h** |

### Où part l'or (avant)

| dépense | coût | fréquence |
|---|---|---|
| maison des Frostmark (Gunnar) | 1 500 | une fois |
| arbre oublié chez Sigrún | 500 | rare, facultatif |
| forge +1 / +2 / +3 (Brodd) | 30 + 20 % / 60 + 40 % / 120 + 75 % de la valeur, + minerais (épée d'or : 66 + 132 + 255 = 453) | par pièce d'équipement |
| tomes de sorts (Grima) | 138 à 483 | ~8 tomes en tout |
| potions, vivres | 4 à 87 | courant, mais le butin en donne déjà |

### Ce qui était trop facile ou inutile

1. **Argent infini par achat-revente** : avec une faveur forte (anneau du marchand 0,1 + bottes de Fafnir 0,15 + pièces d'or 0,02-0,05 +
   disposition 0,15 + remise de rang), achat = 1,1 × 0,4 = **0,44 × valeur** et rachat = 0,4 × 1,6 = **0,64 × valeur** : acheter une
   épée d'or 80 et la revendre 115 au même comptoir rapportait 35 pièces à chaque aller-retour, jusqu'à vider la bourse, tous les 2 jours.
2. **Voler n'avait aucun coût économique** : un objet volé (étal de Brodd, coffre fouillé, décor possédé) se revendait au même prix
   qu'un objet gagné, chez Brodd lui-même. Seule la prime, si un témoin voyait le vol, freinait. Voler l'étal de Brodd puis lui revendre
   ses propres pièces était un revenu sûr la nuit.
3. **Plus aucun puits d'or passé ~4 h de jeu** : maison achetée, équipement forgé +3, tomes lus, l'or s'empile (≈ 1 000 / h) sans usage.
   Rien ne coûte de façon récurrente et utile.
4. Pas de marchandage ni de compétence d'éloquence (choix de conception : la faveur passe par les bijoux, la réputation et les factions).

## 2. Équilibrage (après)

### Marge minimale (anti-arbitrage)

`Marchand.MARGE_MIN = 0,75` : le rachat ne dépasse jamais 75 % du prix d'achat du même objet chez le même marchand, quelle que soit
la faveur. Sans effet aux faveurs courantes (jusqu'à ~0,3 : rachat ≤ 52 % de la valeur pour un achat à 77 %), il ne mord qu'aux faveurs
extrêmes. Exemple à faveur 0,5 : épée d'or achat 99, rachat **74** (au lieu de 108). Racheter ce qu'on vient d'acheter fait
toujours perdre au moins 25 %.

### Objets volés

- Deux marques, lues ensemble (la plus forte) : `Conteneur.voles` du sac (`noter_vol`, posée par ObjetsVivants quand on prend un
  objet possédé) et `Crime.voles` (`signaler_vol` : étals, coffres fouillés de la démo de crime…), bornées au nombre dans le sac.
- **Brodd et Grima refusent la part volée d'une pile** : onglet Vendre, la part honnête reste vendable, la part volée est listée à part,
  en bas, grisée, « (volé) », avec le refus du marchand (« Objet volé : Brodd refuse. » / « Objet volé : Grima refuse. »).
- **Un objet acheté n'est jamais compté volé** (la marque est bornée à ce que le sac contenait avant l'achat).
- Seul le receleur rachète le volé, à 25 % de la valeur (au lieu de 40 %) et avec une petite bourse : 350 pièces tous les 3 jours (~230 par 2 jours). Le vol
  rapporte donc 2,5 fois moins que le butin honnête et reste un appoint, pas une rente.

### Receleur : Bersi Main-Grise

- **Où** : sur le quai, sous l'auvent du moulin, au bord de l'eau (31 ; 56,5), au sud-ouest du village, dans l'enceinte mais hors des
  rues et des rondes de la garde. Toujours à son poste, jour et nuit (profil « veilleur » de `data/vie/planning.json`).
  Le lit libre du moulin à eau est désormais le sien (`data/batiments.json`), pour le contrat « un lit par civil » du sommeil.
- **Corps** : archétype nordique existant (guerrier de PnjNordique, comme les paysans, sans casque ni arme, avec sa cape), variante
  de teinte `hab_receleur` (étoffes ternies presque noires, poil et barbe gris). Aucun nouveau modèle 3D.
- **Commerce** (« Ballots de Bersi ») : rachète tout (sauf les objets de quête) à 25 %, objets volés compris, et leur ôte la marque
  (il écoule d'abord les volés). Bourse 350, réassort tous les 3 jours. Vend à 130 % : crochets, potions, vivres, petits bijoux,
  dague, flèches, cuir léger.
- **Dialogue** (data/villageois.json) : interpellations discrètes, répliques de colporteur sans scrupules ; « [T] Commercer », leçon
  de Furtivité.

### Puits d'or : leçons des maîtres (`Formation`, réutilise Competences et le dialogue à choix)

| maître | compétence | plafond |
|---|---|---|
| Brodd le Large | Une main | 50 |
| Haldor Quatre-Yeux | Parade | 50 |
| Ylva Frostmark | Athlétisme | 50 |
| Sigrún la Voyante | Restauration | 50 |
| Bersi Main-Grise | Furtivité | 50 |

- Une leçon = **+1 niveau exactement** (sans perk ni bonus de repos), prix **40 + 6 × niveau actuel** (niveau 15 : 130 ; 30 : 220 ;
  49 : 334). Au plus **3 leçons par maître tous les 2 jours** de jeu (horloge des marchands). Le maître répond par une réplique
  (réussite, plafond atteint, fatigue, bourse trop légère).
- Monter une compétence de 15 à 50 par les leçons seules coûte **8 120 pièces** ; les 5 maîtres : ~40 000. Au plus 15 leçons par
  2 jours (~2 500 à 4 000 pièces) : plus que ce que rapporte une heure de jeu, donc un vrai arbitrage entre leçons, forge et maison,
  et un usage à l'or en fin de partie. Le plafond de 50 garde l'essentiel de la progression à la pratique.
- Sauvegarde : `Marchand.exporter()` → clé `"formations"` (leçons de la période par maître) ; remis à zéro avec les marchands.

### Après, en résumé

| | avant | après |
|---|---|---|
| achat-revente à faveur maximale | +45 % par aller-retour | −25 % au moins |
| objet volé chez Brodd / Grima | 40 % de la valeur | refusé |
| objet volé chez le receleur | — | 25 % de la valeur, bourse 350 / 3 jours |
| or utile passé 4 h de jeu | ~0 (tout acheté) | leçons : jusqu'à ~40 000 pièces, 15 leçons / 2 jours |
| revenu honnête | ≈ 1 000 / h | inchangé |

Non fait, volontairement : chambre à l'auberge (le lit « auberge » existe dans Sommeil mais l'auberge n'en a pas, il faudrait
toucher aux intérieurs), réparation (pas d'usure dans le jeu).

## 3. API

- `Marchand.est_receleur(id)`, `Marchand.voles_de(inv, oid)`, `Marchand.vendables(id, inv, oid)`,
  `Marchand.refus_vente(id, oid, quetes, inv)` (refus « volé » chez un honnête), `Marchand.MARGE_MIN`.
- `Formation.options(id_pnj, joueur, avis)`, `prix(prog, id)`, `restantes(id)`, `refus(prog, inv, id)`, `prendre_lecon(prog, inv, id)`,
  `exporter() / importer(d) / reinitialiser()`.
- Tests : `outils/test_economie.gd` (dans `outils/tous_les_tests.sh`), plus test_marchands, test_crime, test_stockage, test_disposition.
- Captures : `outils/captures_receleur.gd` (fenêtre hors écran ; `--plan`, `--sondes=x;z|…` pour choisir un coin).
