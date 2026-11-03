"""Met à 0 l'alpha de la couleur de sommet (COLOR_0) de tous les glb d'armures posées au sol (assets/modeles/armures/sol/*.glb).

Pourquoi : le shader ps1 pose la neige du monde sur les faces tournées vers le haut quand l'alpha de la couleur de sommet est >= 0,5 ;
une armure posée à plat serait coiffée de blocs blancs / noirs. Alpha 0 = « déjà neigé » : rien n'est posé (tex_neige = tex_base).
Idempotent, sans Blender :  python3 -I sources_blender/armures/sol_sans_neige.py [dossier]
(Les glb sans COLOR_0 sont couverts par neige_tient = 0 dans ArmureVisible.materiau.)
"""
import glob, json, struct, sys

def corriger(chemin):
    b = bytearray(open(chemin, "rb").read())
    lj = struct.unpack("<I", b[12:16])[0]
    j = json.loads(bytes(b[20:20 + lj]))
    deb_bin = 20 + lj + 8          # en-tête du chunk BIN : 8 octets
    taille = {5121: 1, 5123: 2, 5126: 4}
    n = 0
    vus = set()
    for m in j["meshes"]:
        for p in m["primitives"]:
            ia = p["attributes"].get("COLOR_0")
            if ia is None or ia in vus:
                continue
            vus.add(ia)
            a = j["accessors"][ia]
            assert a["type"] == "VEC4" and "sparse" not in a, chemin
            ct = a["componentType"]
            t = taille[ct]
            bv = j["bufferViews"][a["bufferView"]]
            pas = bv.get("byteStride", 4 * t)
            base = deb_bin + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
            for i in range(a["count"]):
                o = base + i * pas + 3 * t
                if ct == 5126:
                    b[o:o + 4] = struct.pack("<f", 0.0)
                else:
                    b[o:o + t] = bytes(t)
                n += 1
    if n:
        open(chemin, "wb").write(b)
    return n

if __name__ == "__main__":
    dossier = sys.argv[1] if len(sys.argv) > 1 else "assets/modeles/armures/sol"
    for f in sorted(glob.glob(dossier + "/*.glb")):
        print(f.split("/")[-1], corriger(f))
