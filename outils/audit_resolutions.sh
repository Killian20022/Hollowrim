#!/usr/bin/env bash
# Audit graphique : captures + perf des 3 vues de outils/poses_audit_resolutions.txt à plusieurs résolutions internes.
#   bash outils/audit_resolutions.sh <dossier_sortie> [480x270 640x360 960x540]
# Un lancement Godot (fenêtre, vsync coupé) par résolution, via /tmp/godot_slot.sh s'il existe.
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; shift
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
RES=("$@"); [[ ${#RES[@]} -eq 0 ]] && RES=(480x270 640x360 960x540)
SLOT=(); [[ -f /tmp/godot_slot.sh ]] && SLOT=(bash /tmp/godot_slot.sh)
for r in "${RES[@]}"; do
	mkdir -p "$OUT/$r"
	"${SLOT[@]}" timeout 600 "$G" --path "$(wslpath -w "$ICI")" --disable-vsync --script res://outils/mesure_vues.gd -- \
		--captures="$(wslpath -w "$ICI/outils/poses_audit_resolutions.txt")" --sortie="$(wslpath -w "$OUT/$r")" \
		--nouvelle --paisible --res="$r" --attente=400 > "$OUT/$r/lot.log" 2>&1 || echo "échec $r"
	echo "== $r"; grep -E "^(VUE|CAPTURE|LOT)" "$OUT/$r/lot.log"
	grep -c "SCRIPT ERROR" "$OUT/$r/lot.log" | sed 's/^/erreurs de script : /'
done
