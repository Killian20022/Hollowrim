#!/usr/bin/env bash
# Lot 5b : sauvegardes monde + personnage, poignée de main versionnée, écran Multijoueur. Tout en Godot HEADLESS.
#   1. test_sauvegarde_multi.gd        un processus : fonctions pures, ancienne sauvegarde (v1) chargée dans le vrai monde, hôte, fichier personnage
#   2. test_sauvegarde_multi_reseau.gd deux processus x2 phases (« relance ») : hôte (faux monde) + invité (VRAI monde en mode invité)
#   3. test_ecran_multi.gd             l'écran Multijoueur par script (navigation clavier, adresse invalide, connexion ratée, salon)
# Usage : bash outils/test_sauvegarde_multi.sh [motif]   (GODOT=… ; PORT=<n> de la plage 25031-25049 ; GODOT_MAX>=2, 4 si d autres agents tournent ; JOURNAUX=<dossier>)
# Verdict lu dans les journaux (le code de sortie de la console Godot n'est pas fiable). Code de sortie du script = nombre d'échecs.
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -m "$ICI")"
PORT="${PORT:-25033}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${JOURNAUX:-/tmp/test_sauvegarde_multi}"; mkdir -p "$LOG"; rm -f "$LOG"/*.log
MOTIF="${1:-}"
export GODOT_MAX="${GODOT_MAX:-4}"
nko=0
verdict() {  # nom, condition (0 = ok)
	if [[ "$2" -eq 0 ]]; then echo "OK     $1"; else echo "ECHEC  $1"; nko=$((nko+1)); fi
}
godot() {  # journal, args…   (jamais --fixed-fps pour le réseau : les délais de connexion sont en temps réel)
	local j="$1"; shift
	GODOT_TIMEOUT="${DELAI:-420}" bash "$SLOT" "$G" --headless --path "$P" "$@" > "$j" 2>&1
}
pas_d_erreur() { ! grep -qaE "SCRIPT ERROR|Parse Error|Identifier not found" "$1"; }

if [[ -z "$MOTIF" || "solo" == *"$MOTIF"* ]]; then
	godot "$LOG/solo.log" --script res://outils/test_sauvegarde_multi.gd -- --port=$((PORT-2))
	grep -a "^ECHEC\|RESULTAT\|SCRIPT ERROR" "$LOG/solo.log"
	grep -qa "^RESULTAT : OK" "$LOG/solo.log" && pas_d_erreur "$LOG/solo.log"; verdict "solo : pur + ancienne sauvegarde + hôte + personnage" $?
fi

if [[ -z "$MOTIF" || "reseau" == *"$MOTIF"* ]]; then
	for phase in 1 2; do
		godot "$LOG/hote$phase.log" --script res://outils/test_sauvegarde_multi_reseau.gd -- --role=hote --phase=$phase --port=$PORT & H=$!
		for _ in $(seq 1 60); do grep -aq HOTE_PRET "$LOG/hote$phase.log" 2>/dev/null && break; sleep 1; done
		sleep 1
		godot "$LOG/invite$phase.log" --script res://outils/test_sauvegarde_multi_reseau.gd -- --role=invite --phase=$phase --port=$PORT & I=$!
		wait "$I"; wait "$H"
		for r in hote invite; do echo "--- $r phase $phase ---"; grep -a "TEST \|APPORT\|SCRIPT ERROR" "$LOG/$r$phase.log"; done
		ok=0
		for r in hote invite; do
			grep -qa "TEST_SAUVEGARDE_MULTI $r OK" "$LOG/$r$phase.log" && pas_d_erreur "$LOG/$r$phase.log" || ok=1
		done
		verdict "réseau phase $phase (hôte + invité)" $ok
	done
fi

if [[ -z "$MOTIF" || "ecran" == *"$MOTIF"* ]]; then
	godot "$LOG/ecran.log" --script res://outils/test_ecran_multi.gd -- --port=$((PORT+1))
	grep -a "^ECHEC\|RESULTAT\|SCRIPT ERROR" "$LOG/ecran.log"
	grep -qa "^RESULTAT : OK" "$LOG/ecran.log" && pas_d_erreur "$LOG/ecran.log"; verdict "écran Multijoueur (clavier, adresse invalide, salon)" $?
fi
echo "== $nko échec(s) (journaux : $LOG)"
exit $nko
