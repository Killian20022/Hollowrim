#!/usr/bin/env bash
# Revue visuelle du biome en une commande : captures jour/nuit de toutes les poses, planches
# AVANT | APRÈS, mesure GPU, invariance hors zone et tests clés, puis un résumé.
#
#   bash outils/revue_visuelle.sh <etiquette> [poses...]
#     <etiquette> : nom de l'itération (ex. iter1) → captures/biome/revue/<etiquette>/
#     [poses...]  : sous-ensemble de outils/poses_biome.txt (défaut : toutes)
#   Variables : AVANT_DIR (dossier du projet de référence, défaut ../nordique_lot0ref, refait seulement
#   si ses captures manquent), SANS_TESTS=1 (images + perf seulement), SANS_PERF=1.
#
# Une seule fenêtre Godot à la fois : ne pas lancer pendant qu'un autre Godot tourne (mesures faussées).
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
WIN() { wslpath -w "$1"; }
ETQ="${1:?étiquette requise (ex. iter1)}"; shift
AVANT_DIR="${AVANT_DIR:-$ICI/../nordique_lot0ref}"
REVUE="$ICI/captures/biome/revue"
SORTIE="$REVUE/$ETQ"
REF_AVANT="$REVUE/avant"
mkdir -p "$SORTIE" "$REF_AVANT"
touch "$ICI/captures/biome/.gdignore"
RESUME="$SORTIE/resume.txt"
: > "$RESUME"
log() { echo "$*" | tee -a "$RESUME"; }

if tasklist.exe 2>/dev/null | grep -qi godot; then
	log "ATTENTION : un autre Godot tourne, les mesures de performance seront faussées."
fi

declare -A POSE
ORDRE=()
while read -r nom coords; do
	[[ -z "${nom:-}" || "$nom" == \#* ]] && continue
	POSE[$nom]="$coords"; ORDRE+=("$nom")
done < "$ICI/outils/poses_biome.txt"
[[ $# -gt 0 ]] && ORDRE=("$@")

lot() { # dossier_projet dossier_sortie prefixe poses... : UN lancement de Godot pour toutes les vues (--captures)
	local proj="$1" sortie="$2" pref="$3"; shift 3
	local f="$sortie/${pref}_poses.txt"; : > "$f"
	for p in "$@"; do for ph in jour nuit; do
		echo "${pref}_${p}_${ph} monde ${POSE[$p]} $([[ $ph == jour ]] && echo heure=12)" >> "$f"
	done; done
	timeout $((120 + 24 * $#)) "$G" --path "$(WIN "$proj")" -- --captures="$(WIN "$f")" --sortie="$(WIN "$sortie")" \
		--paisible --sans-particules --attente=200 > "$sortie/${pref}.log" 2>&1 \
		|| log "  échec du lot $pref ($(basename "$proj"))"
	grep -E "^LOT" "$sortie/${pref}.log" | sed 's/^/  /' | tee -a "$RESUME"
}
capture() { # (repli, ancien lancement unitaire) dossier_projet fichier_png pose phase
	local h=""; [[ "$4" == jour ]] && h="--heure=12"
	timeout 150 "$G" --path "$(WIN "$1")" -- $h --capture="$(WIN "$2")" --pose="${POSE[$3]}" \
		--paisible --sans-particules --attente=200 > "$2.log" 2>&1 \
		|| log "  échec capture $3 $4 ($(basename "$1"))"
}

log "== Revue $ETQ ($(date '+%F %T')) — $(git -C "$ICI" log --oneline -1)"
log "-- Captures (${#ORDRE[@]} poses × jour/nuit, un seul lancement)"
lot "$ICI" "$SORTIE" apres "${ORDRE[@]}"
MANQUE=()
for p in "${ORDRE[@]}"; do for ph in jour nuit; do
	[[ ! -f "$REF_AVANT/avant_${p}_${ph}.png" ]] && MANQUE+=("$p")
done; done
if [[ ${#MANQUE[@]} -gt 0 && -d "$AVANT_DIR" ]]; then
	MQ=($(printf '%s\n' "${MANQUE[@]}" | sort -u))
	if grep -q "_lot_captures" "$AVANT_DIR/scripts/monde.gd" 2>/dev/null; then
		lot "$AVANT_DIR" "$REF_AVANT" avant "${MQ[@]}"
	else  # projet de référence ancien : pas de mode --captures
		for p in "${MQ[@]}"; do for ph in jour nuit; do capture "$AVANT_DIR" "$REF_AVANT/avant_${p}_${ph}.png" "$p" "$ph"; done; done
	fi
fi
for p in "${ORDRE[@]}"; do for ph in jour nuit; do cp -f "$REF_AVANT/avant_${p}_${ph}.png" "$SORTIE/" 2>/dev/null; done; done

log "-- Planches"
RECAP=$(IFS=,; echo "${ORDRE[*]:0:6}")
timeout 200 "$G" --headless --path "$(WIN "$ICI")" --script outils/planche.gd -- \
	"$(WIN "$SORTIE")" "$RECAP" > "$SORTIE/planches.log" 2>&1
log "  $(ls "$SORTIE"/planche_*.png 2>/dev/null | wc -l) planches dans captures/biome/revue/$ETQ/"

if [[ -z "${SANS_PERF:-}" ]]; then
	log "-- Performance (feu, nuit)"
	timeout 120 "$G" --path "$(WIN "$ICI")" --disable-vsync --script outils/mesure_perf.gd -- \
		--nouvelle --paisible --pose=2.5,8.5,16,4 2>&1 | grep -iE "gpu|draw|primitive|fps" | tee -a "$RESUME"
	grep -h "Sol : carte" "$SORTIE"/apres.log 2>/dev/null | head -1 | sed 's/^/  /' | tee -a "$RESUME"
fi

if [[ -z "${SANS_TESTS:-}" ]]; then
	log "-- Invariance hors zone (avec fenêtre)"
	# --sans-cles (lot 2) : compare le placement seul ; les modèles d'arbres ont changé partout.
	timeout 300 "$G" --path "$(WIN "$ICI")" --resolution 160x90 --script outils/test_biome.gd -- \
		comparer captures/biome/ref_ancien_fenetre.sig --sans-zone --sans-cles 2>&1 | grep -E "^OK|DIFF|ERREUR" | tee -a "$RESUME"
	log "-- Tests"
	for t in "test_quetes.gd -- --nouvelle" "test_vegetation_biome.gd" "test_chemin_biome.gd -- --paisible" "test_collisions_biome.gd"; do
		set -- $t; f=$1; shift
		r=$(timeout 300 "$G" --headless --path "$(WIN "$ICI")" --script "outils/$f" "$@" 2>&1 \
			| grep -E "TEST .*:|TOUT OK|ECHECS|conforme|ÉCHEC|SCRIPT ERROR" | tail -1)
		log "  $f : ${r:-pas de verdict}"
	done
fi
log "== Fin. Regarder : captures/biome/revue/$ETQ/planche_recap_jour.png et planche_recap_nuit.png"
