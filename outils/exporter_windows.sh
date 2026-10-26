#!/usr/bin/env bash
# Build Windows de Hollowrim : export headless du preset « Windows Desktop » puis zip prêt à publier.
#   bash outils/exporter_windows.sh
# Résultat : dist/Hollowrim-<version>-windows.zip contenant Hollowrim.exe (pck embarqué ; Hollowrim.pck s'il existe),
# LISEZMOI.txt, CREDITS.txt (licences des ressources, depuis assets/LICENCES.md). dist/ est ignoré par git.
# Nom et version : lus dans project.godot (application/config/name, application/config/version) et recopiés dans
# les métadonnées du preset (product_name, file_version, product_version) avant l'export.
# Variables : GODOT (exécutable), SLOT (limiteur de Godot simultanés, défaut /tmp/godot_slot.sh s'il existe).
set -euo pipefail
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
SLOT="${SLOT:-/tmp/godot_slot.sh}"
NOM="$(sed -n 's/^config\/name="\(.*\)"/\1/p' "$ICI/project.godot")"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ICI/project.godot")"
[[ -n "$NOM" && -n "$VERSION" ]] || { echo "nom ou version introuvable dans project.godot" >&2; exit 1; }
V4="$VERSION.0"
# métadonnées du .exe alignées sur project.godot
sed -i -e "s/^application\/product_name=.*/application\/product_name=\"$NOM\"/" \
	-e "s/^application\/file_version=.*/application\/file_version=\"$V4\"/" \
	-e "s/^application\/product_version=.*/application\/product_version=\"$V4\"/" \
	-e "s/^export_path=.*/export_path=\"dist\/$NOM.exe\"/" "$ICI/export_presets.cfg"

DIST="$ICI/dist"; BUILD="$DIST/build"
rm -rf "$BUILD"; mkdir -p "$BUILD"
lancer() { if [[ -f "$SLOT" ]]; then GODOT_TIMEOUT=900 bash "$SLOT" "$G" "$@"; else timeout 900 "$G" "$@"; fi; }
t0=$SECONDS
lancer --headless --path "$P" --import > "$DIST/import.log" 2>&1 || true
lancer --headless --path "$P" --export-release "Windows Desktop" "$(wslpath -w "$BUILD")\\$NOM.exe" > "$DIST/export.log" 2>&1 || true
if [[ ! -s "$BUILD/$NOM.exe" ]]; then
	echo "EXPORT ÉCHOUÉ (journal : $DIST/export.log)" >&2; tail -20 "$DIST/export.log" >&2; exit 1
fi
grep -E "ERROR|SCRIPT ERROR" "$DIST/export.log" | head -20 || true
echo "export : $((SECONDS - t0)) s"

# LISEZMOI.txt (CRLF : lisible dans le Bloc-notes)
cat > "$BUILD/LISEZMOI.txt" <<EOF
$NOM - démo $VERSION (Windows)
==============================

Action-RPG nordique en vue subjective au rendu rétro (style PS1). Démo : un village enneigé,
sa forêt, un tumulus et sa crypte. Version de test : des bugs sont possibles.

LANCER
- Décompresser le dossier où vous voulez, puis double-cliquer sur $NOM.exe.
- Windows SmartScreen peut avertir (jeu non signé) : « Informations complémentaires » puis « Exécuter quand même ».

TOUCHES (clavier AZERTY ; manette : menus seulement)
- ZQSD ou flèches : se déplacer      - Souris : regarder
- Maj : courir                        - Espace : sauter
- Clic gauche : frapper (maintenir : coup puissant)
- Clic droit : parer                  - E : parler, ouvrir, ramasser
- Tab : inventaire et quêtes          - T : torche
- V : vue 1re / 3e personne           - F5 / F9 : sauvegarder / charger
- F11 ou Alt+Entrée : plein écran     - Échap : menu pause (Options, Sauvegarder, Quitter)

CONFIGURATION
- Minimale (estimation) : Windows 10/11 64 bits, carte graphique intégrée récente
  (type Intel Iris Xe), 8 Go de mémoire, ~1 Go d'espace disque.
- Pilote graphique compatible Vulkan ; à défaut le jeu bascule seul en OpenGL.

SAUVEGARDES
- Dossier : %APPDATA%\\$NOM\\  (taper %APPDATA%\\$NOM dans la barre de l'Explorateur)
  sauvegarde.json = la partie, options.cfg = les réglages.
- Copie de secours (facultative) : Options > Copie de secours > Choisir... puis un dossier,
  par exemple « G:\\Mon Drive\\$NOM » (Google Drive) ou un dossier OneDrive.
  À chaque sauvegarde, une copie datée y est écrite (les 10 dernières sont gardées).
  Si la sauvegarde locale est perdue ou abîmée, l'écran titre propose « Restaurer la copie de secours ».

CRÉDITS
Voir CREDITS.txt.
EOF
{
	echo "$NOM $VERSION - crédits"
	echo
	echo "Conception, programmation, modèles du joueur : lopezk19 (avec l'aide de Claude, Anthropic)."
	echo "Moteur : Godot Engine 4.7 (godotengine.org), licence MIT - (c) 2014-présent Godot Engine contributors, (c) 2007-2014 Juan Linietsky, Ariel Manzur."
	echo "Police : Kenney Pixel (kenney.nl), CC0 1.0 ; variante « Kenney Pixel Nordique » (accents ajoutés pour le jeu)."
	echo
	sed -e 's/^#\+ *//' -e 's/\*\*//g' "$ICI/assets/LICENCES.md"
} > "$BUILD/CREDITS.txt"
sed -i 's/$/\r/' "$BUILD/LISEZMOI.txt" "$BUILD/CREDITS.txt"

ZIP="$DIST/$NOM-$VERSION-windows.zip"
rm -f "$ZIP"
FICHIERS=("$NOM.exe" LISEZMOI.txt CREDITS.txt)
[[ -f "$BUILD/$NOM.pck" ]] && FICHIERS+=("$NOM.pck")
(cd "$BUILD" && python3 -I -c '
import sys, zipfile
nom, *fichiers = sys.argv[1:]
racine = sys.argv[2].rsplit(".", 1)[0]  # dossier dans le zip = nom du jeu
with zipfile.ZipFile(nom, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in fichiers:
        z.write(f, racine + "/" + f)
' "$ZIP" "${FICHIERS[@]}")
ls -l "$BUILD"
echo "ZIP : $ZIP ($(du -h "$ZIP" | cut -f1))"
