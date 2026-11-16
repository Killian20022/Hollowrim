#!/usr/bin/env bash
# Enchaîne tous les tests réseau (et les tests solo sensibles au réseau) EN SÉQUENCE, headless, ports distincts ; tableau OK/ECHEC.
#   bash outils/test_tout_reseau.sh [motif]     (GODOT=… ; JOURNAUX=<dossier> ; code de sortie = nombre d'échecs)
# Verdict lu dans les journaux (le code de sortie de la console Godot n'est pas fiable) : le script du test doit réussir
# ET aucune « SCRIPT ERROR » / « Parse Error » / « Identifier not found » ne doit apparaître dans sa sortie.
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
LOGS="${JOURNAUX:-/tmp/tout_reseau}"; mkdir -p "$LOGS"
MOTIF="${1:-}"
[[ -f /tmp/godot_slot.sh ]] || cp "$ICI/../godot_slot.sh" /tmp/godot_slot.sh 2>/dev/null
# nom|commande (exécutée depuis la racine du projet)
TESTS=(
	"banc_reseau|PORT=24601 bash outils/banc_reseau.sh"
	"test_coop_proto|PORT=24602 bash outils/test_coop_proto.sh"
	"test_rejoindre|PORT=24603 bash outils/test_rejoindre.sh"
	"test_lieux|PORT=24604 bash outils/test_lieux.sh"
	"test_monde_vivant|PORT=24605 bash outils/test_monde_vivant.sh"
	"test_integration2|PORT=24606 bash outils/test_integration2.sh"
	"test_pause_vote|PORT=24607 bash outils/test_pause_vote.sh"
	"test_villageois|bash outils/tous_les_tests.sh test_villageois"
	"test_menu_personnage|bash outils/tous_les_tests.sh test_menu_personnage"
	"test_sommeil|bash outils/tous_les_tests.sh test_sommeil"
	"test_crime_sommeil|bash outils/tous_les_tests.sh test_crime_sommeil"
	"test_combat_solo|timeout 120 $G --headless --path $P res://scenes/test_combat.tscn -- --sans-zone --sans-aide --quitter-apres=5"
)
cd "$ICI" || exit 1
nok=0; nko=0; RES=()
for t in "${TESTS[@]}"; do
	nom="${t%%|*}"; cmd="${t#*|}"
	[[ -n "$MOTIF" && "$nom" != *"$MOTIF"* ]] && continue
	d0=$SECONDS; sortie="$LOGS/$nom.log"
	JOURNAUX="$LOGS/solo" bash -c "$cmd" > "$sortie" 2>&1; rc=$?
	ok=1
	if [[ "$nom" == "test_combat_solo" ]]; then rc=0   # la scène ne se termine pas seule : on ne juge que les erreurs de script
	elif [[ $rc -ne 0 ]]; then ok=0; fi
	grep -qaE "SCRIPT ERROR|Parse Error|Identifier not found|ÉCHEC|ECHEC *:|TEST ECHEC" "$sortie" && ok=0
	[[ "$nom" == "test_combat_solo" ]] && ! grep -qa "SCRIPT ERROR" "$sortie" && ok=1
	if [[ $ok -eq 1 ]]; then s="OK    "; nok=$((nok+1)); else s="ECHEC "; nko=$((nko+1)); fi
	RES+=("$s $nom ($((SECONDS-d0)) s)")
	echo "$s $nom"
done
echo "== Résumé réseau"; printf '%s\n' "${RES[@]}"
echo "== $nok OK, $nko ECHEC (journaux : $LOGS)"
exit $nko
