# GEN_EAU : lot eau / ponts / quais / gué (généralisation Quaternius)

## Remplacé
- **Quai du moulin** (`scripts/eau_village.gd`, `_quai_kit`) : plancher en 9 dalles `q_planches_sol`, longerons, pieux, croisillons et chasse-roue en `q_poutre_ronde`. Même emprise que l'ancien (9 x 2,2 m, dessus à y 0), collision `_boite` inchangée, matériaux existants `planches` / `rondins`.
- Repli automatique si les props Quaternius manquent (`_quai_quaternius()`).

## Resté maison
- Pont, gué, moulin, berges, eau : inchangés (acceptable pour ce lot).

## Option de repli
- `-- --eau-ancienne` : ancien quai maison (planches + pieux du modèle).

## Captures
- `bash outils/captures_gen_eau.sh <dossier> [--eau-ancienne]` (poses : `outils/poses_gen_eau.txt`).

## Note
- Pas de `generate_tangents()` : les pièces Quaternius n'ont pas d'UV exploitables pour cela (erreur sinon).
