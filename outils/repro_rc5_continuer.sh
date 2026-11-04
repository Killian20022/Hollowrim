#!/usr/bin/env bash
# Boucle de reproduction du rc=5 intermittent de test_menus à l'étape « continuer » (chargement d'une sauvegarde, fenêtre hors écran).
# Écrit d'abord la sauvegarde de test (étape « nouvelle »), puis relance « continuer » N fois ; à chaque code de sortie non nul,
# copie la sortie du processus ET godot.log (backtrace du plantage) dans captures/rc5/echec_<n>.*.
#   bash outils/repro_rc5_continuer.sh [N=100] [ATTENTE=6]
set -u
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
SLOT="${SLOT:-/tmp/godot_slot.sh}"
N="${1:-100}"; ATTENTE="${2:-6}"
LOG="/mnt/c/Users/$USER/AppData/Roaming/Hollowrim/logs/godot.log"
OUT="$ICI/captures/rc5"; mkdir -p "$OUT"
SORTIE="$P\\captures\\rc5\\vues"
SECOURS="$P\\captures\\test_secours\\rc5"
lancer() {   # $1 = étape, $2 = fichier de sortie
	GODOT_TIMEOUT=300 bash "$SLOT" "$G" --path "$P" -- "--test-titre=$1" "--test-titre-sortie=$SORTIE" "--test-titre-secours=$SECOURS" "--test-titre-attente=$ATTENTE" > "$2" 2>&1
}
lancer nouvelle "$OUT/nouvelle.txt"; echo "nouvelle : rc=$?"
ko=0
for i in $(seq 1 "$N"); do
	lancer continuer "$OUT/dernier.txt"; rc=$?
	if [[ $rc -ne 0 ]] || ! grep -q "TEST MENUS : continuer OK" "$OUT/dernier.txt"; then
		ko=$((ko + 1)); cp "$OUT/dernier.txt" "$OUT/echec_$i.txt"; [[ -f "$LOG" ]] && cp "$LOG" "$OUT/echec_$i.godot.log"
		echo "essai $i : ECHEC rc=$rc"
	else
		echo "essai $i : ok"
	fi
done
echo "bilan : $ko échec(s) sur $N"
[[ $ko -eq 0 ]]
