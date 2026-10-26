#!/usr/bin/env bash
# Test des menus en vrai (fenêtre hors écran, via godot_slot.sh) : écran titre → Nouvelle partie → monde → menu pause
# (captures) → Sauvegarder (+ copie de secours) → Quitter, puis relance → Continuer → la partie chargée est celle sauvegardée,
# puis relance → sauvegarde locale corrompue → « Restaurer la copie de secours » → Continuer.
# Copies de secours : dossier TEMPORAIRE captures/test_secours/<horodatage> (--test-titre-secours), jamais un dossier du joueur.
#   bash outils/test_menus.sh [dossier_captures]            projet (éditeur Godot)
#   EXE=/mnt/c/.../Hollowrim.exe bash outils/test_menus.sh   jeu exporté (journal lu dans %APPDATA%\Hollowrim\logs\godot.log)
# Les lancements portent des arguments (--test-titre=…) : le jeu utilise la sauvegarde de TEST, jamais la vraie partie.
# Verdict : 0 si aucune « SCRIPT ERROR », sauvegarde écrite et Continuer OK.
set -u
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
SLOT="${SLOT:-/tmp/godot_slot.sh}"
SORTIE="${1:-$P\\captures\\menus}"
JOURNAL="$ICI/captures/test_menus.log"; mkdir -p "$ICI/captures"; : > "$JOURNAL"
SECOURS="$P\\captures\\test_secours\\$(date +%Y%m%d-%H%M%S)"
LOG_EXE="/mnt/c/Users/$USER/AppData/Roaming/Hollowrim/logs/godot.log"
ATTENTE="${ATTENTE:-6}"   # secondes en partie avant d'agir (au-delà de ~30 s, les fils de chargement en arrière-plan ont fini)
lancer() {   # $1 = étape
	local t0=$SECONDS rc
	local args=("--test-titre=$1" "--test-titre-sortie=$SORTIE" "--test-titre-secours=$SECOURS" "--test-titre-attente=$ATTENTE")
	if [[ -n "${EXE:-}" ]]; then
		# jeu exporté : sa sortie standard n'est pas toujours vidée à la fin → on lit aussi son journal
		GODOT_TIMEOUT=300 bash "$SLOT" "$EXE" -- "${args[@]}" >> "$JOURNAL" 2>&1; rc=$?
	else
		GODOT_TIMEOUT=300 bash "$SLOT" "$G" --path "$P" -- "${args[@]}" >> "$JOURNAL" 2>&1; rc=$?
	fi
	echo "code de sortie ($1) : $rc" >> "$JOURNAL"
	echo "étape ${1%%:*} : $((SECONDS - t0)) s" | tee -a "$JOURNAL"
}
lancer "captures:$SORTIE"   # écran titre, options, crédits
lancer nouvelle
lancer continuer
lancer restaurer
# « Retour au titre » : le processus se relance lui-même (détaché) ; le nouveau écrit test_relance.ok dans le dossier des données
OK_RELANCE="/mnt/c/Users/$USER/AppData/Roaming/Hollowrim/test_relance.ok"; rm -f "$OK_RELANCE"
lancer relance
for i in $(seq 1 60); do [[ -f "$OK_RELANCE" ]] && break; sleep 2; done
if [[ -f "$OK_RELANCE" ]]; then echo "TEST MENUS : relance OK (retour au titre)" >> "$JOURNAL"; rm -f "$OK_RELANCE"
else
	echo "TEST MENUS : relance ÉCHEC (pas de nouvel écran titre en 120 s)" >> "$JOURNAL"
	powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -like '*--test-titre=relance*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" > /dev/null 2>&1
fi
grep -E "TEST MENUS|SCRIPT ERROR|code de sortie|^étape" "$JOURNAL"
ko=0
grep -q "SCRIPT ERROR" "$JOURNAL" && ko=1
grep -q "TEST MENUS : sauvegarde écrite" "$JOURNAL" || ko=1
[[ $(grep -c "TEST MENUS : continuer OK" "$JOURNAL") -ge 2 ]] || ko=1
grep -q "TEST MENUS : copie de secours OK" "$JOURNAL" || ko=1
grep -q "TEST MENUS : restaurer OK" "$JOURNAL" || ko=1
grep -q "TEST MENUS : relance OK (retour" "$JOURNAL" || ko=1
grep -q "ÉCHEC" "$JOURNAL" && ko=1
[[ $ko = 0 ]] && echo "TEST MENUS : OK" || echo "TEST MENUS : ÉCHEC (journal : $JOURNAL)"
exit $ko
