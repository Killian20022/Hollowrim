#!/usr/bin/env bash
# Mesure CPU des scripts (opti cpu_scripts, 2026-11-20) : audit_mesure_lieu.gd --profil=groupes sur une liste de lieux,
# variantes A/B ENTRELACÉES (avant, après, avant, après…), un journal par lancement + résumé.
#   bash outils/mesure_cpu.sh <dossier> "<lieux>" "<heures>" <reps> "<variante1>" ["<variante2>" …]
#   variante = arguments utilisateur en plus (ex. "" pour l'état normal, "--sans-opti-tout" pour l'avant)
#   ex. bash outils/mesure_cpu.sh captures/perf/cpu "place combat" "21" 2 "--sans-opti-tout" ""
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
OUT="$1"; LIEUX="$2"; HEURES="$3"; REPS="$4"; shift 4
mkdir -p "$OUT"
DUREE="${DUREE:-15}"
PROFIL="${PROFIL:---profil=groupes}"
STAB="${STAB:-25}"
nb_godot() { powershell.exe -NoProfile -Command "(Get-Process | Where-Object { \$_.ProcessName -like 'Godot*' -and \$_.ProcessName -notlike '*console*' }).Count" 2>/dev/null | tr -d '\r'; }
pose_de() { case "$1" in temoin) echo "--pose=2.5,8.5,16,4";; place) echo "--pose=35,30,221,-8";; *) echo "";; esac; }
for rep in $(seq 1 "$REPS"); do
	for lieu in $LIEUX; do
		for h in $HEURES; do
			iv=0
			for var in "$@"; do
				iv=$((iv + 1))
				base="$OUT/${lieu}_${h}_v${iv}_${rep}"
				args=(--nouvelle --lieu="$lieu" --heure="$h" --duree="$DUREE" --stab="$STAB" $PROFIL); [[ "$lieu" != "combat" ]] && args+=(--paisible)
				p="$(pose_de "$lieu")"; [[ -n "$p" ]] && args+=("$p")
				[[ -n "$var" ]] && args+=($var)
				autres=$(nb_godot)
				GODOT_TIMEOUT=600 bash /tmp/godot_slot.sh "$G" --path "$P" --disable-vsync --script res://outils/audit_mesure_lieu.gd -- "${args[@]}" > "$base.log" 2>&1
				echo "$lieu $h v$iv($var) rep$rep autres=$autres | $(grep -E '^LIEU [a-z]+ heure=.*gpu_med' "$base.log" | grep -oE 'dt_med=[0-9.]+|dt_p99=[0-9.]+|>33=[0-9]+|appels=[0-9]+' | tr '\n' ' ') | $(grep -E '^LIEU scripts_process' "$base.log" | sed 's/^LIEU //') | $(grep -E '^LIEU temps_process' "$base.log" | sed 's/^LIEU //')" | tee -a "$OUT/resume.txt"
			done
		done
	done
done
