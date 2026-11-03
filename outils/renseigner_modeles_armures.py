#!/usr/bin/env python3
"""Renseigne "modele_porte" / "modele_sol" dans data/objets/armures.json pour chaque pièce dont le glb existe
(assets/modeles/armures/porte/<id>.glb, sol/<id>.glb) — convention conception_rpg/CONVENTION_ARMURES_3D.md (agent X seul).
Édition ligne par ligne (une fiche par ligne : le reste du fichier n'est pas touché) ; relancer est sans effet si rien n'a changé.
  python3 outils/renseigner_modeles_armures.py [--aussi <autre_worktree> ...]
--aussi : cherche aussi les glb dans d'autres worktrees (ex. ../nordique_armures_lourdes de l'agent Y avant sa fusion) ; après la
fusion des deux branches, relancer SANS --aussi : seuls les glb réellement présents restent référencés."""
import os, re, sys, json

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(ICI)
FICHIER = os.path.join(RACINE, "data", "objets", "armures.json")
racines = [RACINE]
a = sys.argv[1:]
while a:
    if a[0] == "--aussi" and len(a) > 1:
        racines.append(os.path.abspath(a[1]))
        a = a[2:]
    else:
        a = a[1:]


def existe(rel):
    return any(os.path.exists(os.path.join(r, rel)) for r in racines)


lignes = open(FICHIER, encoding="utf-8").read().split("\n")
motif = re.compile(r'^(\s*)"([a-z0-9_]+)": (\{.*\})(,?)$')
n = 0
for i, l in enumerate(lignes):
    m = motif.match(l)
    if not m:
        continue
    ident = m.group(2)
    fiche = json.loads(m.group(3))
    if fiche.get("categorie") != "armure":
        continue
    if fiche.get("base") or fiche.get("emplacement") == "jambes":
        continue  # variantes « enchante » et jambières : modèles hérités de la base / des chausses (ne pas écraser)
    corps = m.group(3)
    corps = re.sub(r', "modele_(porte|sol)": "[^"]*"', "", corps)
    ajout = ""
    for cle, dossier in (("modele_porte", "porte"), ("modele_sol", "sol")):
        rel = "assets/modeles/armures/%s/%s.glb" % (dossier, ident)
        if existe(rel):
            ajout += ', "%s": "res://%s"' % (cle, rel)
    nouv = "%s\"%s\": %s%s" % (m.group(1), ident, corps[:-1] + ajout + "}", m.group(4))
    json.loads("{" + nouv.strip().rstrip(",") + "}")
    if nouv != l:
        lignes[i] = nouv
        n += 1
    print("%-28s %s" % (ident, "porte+sol" if "modele_sol" in ajout and "modele_porte" in ajout else ("porte" if "modele_porte" in ajout else "-")))
open(FICHIER, "w", encoding="utf-8").write("\n".join(lignes))
json.load(open(FICHIER, encoding="utf-8"))
print("%d fiche(s) modifiée(s)" % n)
