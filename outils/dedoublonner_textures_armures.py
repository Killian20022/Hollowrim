#!/usr/bin/env python3
"""Dédoublonnage des textures d'armures pour l'export (perf/exe_leger, 2026-11-10).

Les glb de porte/, sol/ et chausses/ embarquent chacun leur atlas, que l'import Godot extrait à côté
(<glb>_<image>.png) : la même image existe en 2 à 8 copies (porte + sol, atlas partagés entre pièces d'un ensemble),
soit 125 copies et ~86 Mo bruts dans l'exe. AUCUN fichier d'art n'est touché :
  - pour chaque matériau dont la texture a une copie « canonique » ailleurs (même md5 ; porte/ d'abord, puis chausses/),
    l'import du glb reçoit un matériau externe (_subresources > materials > use_external) : un StandardMaterial3D minimal
    (même resource_name = nom du matériau Blender, albedo = la texture canonique) écrit dans materiaux_partages/.
    Le jeu ne lit QUE resource_name et albedo_texture (ArmureVisible._habiller_maillage remplace tout par le shader PS1) ;
  - les copies devenues inutiles sont écartées de l'export par exclude_filter (export_presets.cfg), vérifié par
    outils/verif_exclusions_export.gd.
Entrée : l'inventaire de outils/inventaire_materiaux_armures.gd (TSV). Réversible : remettre _subresources={} dans les
.import des glb et retirer les filtres.
    python3 -I outils/dedoublonner_textures_armures.py <inventaire.tsv> <racine du projet>
"""
import collections, hashlib, os, re, sys

inv, racine = sys.argv[1], sys.argv[2].rstrip('/')
PARTAGE = 'res://assets/modeles/armures/materiaux_partages'
lignes = [l.rstrip('\n').split('\t') for l in open(inv, encoding='utf-8') if l.strip()]
vrai = lambda p: os.path.join(racine, p[len('res://'):])

par_md5 = collections.defaultdict(set)
for glb, nom, tex, *_ in lignes:
    if tex:
        par_md5[hashlib.md5(open(vrai(tex), 'rb').read()).hexdigest()].add(tex)
canon = {}
for v in par_md5.values():
    c = sorted(v, key=lambda p: (0 if '/porte/' in p else 1 if '/chausses/' in p else 2, p))[0]
    for p in v:
        canon[p] = c

os.makedirs(vrai(PARTAGE), exist_ok=True)
sub = collections.defaultdict(dict)   # glb -> {nom matériau: chemin tres}
for glb, nom, tex, *_ in lignes:
    if not tex or canon[tex] == tex:
        continue
    c = canon[tex]
    sur = re.sub(r'[^A-Za-z0-9_]', '_', os.path.basename(c)[:-4] + '__' + nom)
    tres = f'{PARTAGE}/{sur}.tres'
    if not os.path.exists(vrai(tres)):
        with open(vrai(tres), 'w', encoding='utf-8', newline='\n') as f:
            f.write('[gd_resource type="StandardMaterial3D" load_steps=2 format=3]\n\n'
                    f'[ext_resource type="Texture2D" path="{c}" id="1_tex"]\n\n'
                    '[resource]\n'
                    f'resource_name = "{nom}"\n'
                    'albedo_texture = ExtResource("1_tex")\n')
    sub[glb][nom] = tres

for glb, mats in sorted(sub.items()):
    imp = vrai(glb) + '.import'
    t = open(imp, encoding='utf-8').read()
    corps = ',\n'.join(f'"{n}": {{\n"use_external/enabled": true,\n"use_external/fallback_path": "{p}",\n"use_external/path": "{p}"\n}}'
                       for n, p in sorted(mats.items()))
    nouveau = '_subresources={\n"materials": {\n' + corps + '\n}\n}'
    t2 = re.sub(r'^_subresources=\{.*?^\}$|^_subresources=\{\}$', lambda m: nouveau, t, count=1, flags=re.M | re.S)
    if t2 == t and nouveau not in t:
        sys.exit(f'_subresources introuvable : {imp}')
    open(imp, 'w', encoding='utf-8', newline='\n').write(t2)

ref = set(canon)
exclus = sorted(p for p in canon if canon[p] != p)
print(f'{len(par_md5)} textures uniques, {len(exclus)} copies remplacées, {len(sub)} glb réimportés, '
      f'{len(set(sub[g][n] for g in sub for n in sub[g]))} matériaux partagés')
with open(os.path.join(os.path.dirname(inv), 'copies_exclues.txt'), 'w') as f:
    f.write('\n'.join(exclus) + '\n')
