# Contrôle : le glb v2 garde le squelette, la peau et les clips du v1 À L'OCTET PRÈS (python3 verifier_glb.py v1.glb v2.glb).
import json, struct, sys

def lire(c):
    b = open(c, "rb").read()
    l0 = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + l0]); o = 20 + l0
    return j, b[o + 8:o + 8 + struct.unpack("<I", b[o:o + 4])[0]]

def octets(j, binr, i):
    a = j["accessors"][i]; bv = j["bufferViews"][a["bufferView"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return binr[o:o + bv["byteLength"]], {k: v for k, v in a.items() if k != "bufferView"}

j1, b1 = lire(sys.argv[1]); j2, b2 = lire(sys.argv[2])
err = []
n1 = len(j1["nodes"])
for i in range(n1):
    a, b = dict(j1["nodes"][i]), dict(j2["nodes"][i])
    if "mesh" in a:
        a.pop("mesh"); b.pop("mesh"); a.pop("name"); b.pop("name")
    if a.get("children") != b.get("children"):
        b["children"] = [c for c in b.get("children", []) if c < n1] or b.get("children")
    if a != b:
        err.append("noeud %d %s" % (i, a.get("name")))
s1, s2 = j1["skins"][0], j2["skins"][0]
if s1["joints"] != s2["joints"] or octets(j1, b1, s1["inverseBindMatrices"]) != octets(j2, b2, s2["inverseBindMatrices"]):
    err.append("peau")
if [a["name"] for a in j1["animations"]] != [a["name"] for a in j2["animations"]]:
    err.append("noms de clips")
for a1, a2 in zip(j1["animations"], j2["animations"]):
    if a1["channels"] != a2["channels"]:
        err.append("canaux " + a1["name"])
    for s_1, s_2 in zip(a1["samplers"], a2["samplers"]):
        for k in ("input", "output"):
            if octets(j1, b1, s_1[k]) != octets(j2, b2, s_2[k]):
                err.append("clés %s" % a1["name"])
extra = [n["name"] for n in j2["nodes"][n1:]]
print("GLB_IDENTIQUE" if not err else "GLB_DIFFERENT " + ", ".join(err[:10]), "| os:", len(s2["joints"]), "| clips:", [a["name"] for a in j2["animations"]], "| noeuds ajoutés:", extra)
sys.exit(1 if err else 0)
