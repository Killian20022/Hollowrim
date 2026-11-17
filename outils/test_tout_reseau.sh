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
PORT_BASE="${PORT_BASE:-25100}"   # base des ports : chaque test prend 4 ports (base+4i+2 ...) ; plage par défaut 25101-25199
[[ -f /tmp/godot_slot.sh ]] || cp "$ICI/../godot_slot.sh" /tmp/godot_slot.sh 2>/dev/null
# nom|commande (exécutée depuis la racine du projet)
TESTS=(
	"banc_reseau|PORT=$((PORT_BASE+2)) GODOT_MAX=${GODOT_MAX:-4} bash outils/banc_reseau.sh"
	"test_coop_proto|PORT=$((PORT_BASE+6)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_coop_proto.sh"
	"test_rejoindre|PORT=$((PORT_BASE+10)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_rejoindre.sh"
	"test_lieux|PORT=$((PORT_BASE+14)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_lieux.sh"
	"test_monde_vivant|PORT=$((PORT_BASE+18)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_monde_vivant.sh"
	"test_integration2|PORT=$((PORT_BASE+22)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_integration2.sh"
	"test_pause_vote|PORT=$((PORT_BASE+26)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_pause_vote.sh"
	"test_combat_coop|PORT=$((PORT_BASE+30)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_combat_coop.sh"
	"test_projectiles|PORT=$((PORT_BASE+34)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_projectiles.sh"
	"test_cadavres|PORT=$((PORT_BASE+38)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_cadavres.sh"
	"test_avatars|PORT=$((PORT_BASE+42)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_avatars.sh"
	"test_integration4|PORT=$((PORT_BASE+46)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_integration4.sh"
	"test_economie_quetes|PORT=$((PORT_BASE+50)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_economie_quetes.sh"
	"test_sauvegarde_multi|PORT=$((PORT_BASE+54)) GODOT_MAX=${GODOT_MAX:-4} bash outils/test_sauvegarde_multi.sh"
	"test_villageois|SOLO --nouvelle"
	"test_menu_personnage|SOLO --nouvelle"
	"test_sommeil|SOLO --nouvelle --paisible"
	"test_crime_sommeil|SOLO --nouvelle --paisible"
	"test_combat_solo|timeout 120 $G --headless --path $P res://scenes/test_combat.tscn -- --sans-zone --sans-aide --quitter-apres=5"
)
cd "$ICI" || exit 1
nok=0; nko=0; RES=()
for t in "${TESTS[@]}"; do
	nom="${t%%|*}"; cmd="${t#*|}"
	[[ -n "$MOTIF" && "$nom" != *"$MOTIF"* ]] && continue
	d0=$SECONDS; sortie="$LOGS/$nom.log"
	if [[ "$cmd" == SOLO* ]]; then   # test solo (--script) : le code de sortie de Godot est trompeur (rc=5 avec RESULTAT OK) -> verdict d'après le journal
		timeout 300 "$G" --headless --fixed-fps 60 --path "$P" --script "res://outils/$nom.gd" -- ${cmd#SOLO } > "$sortie" 2>&1
		grep -qaE "^RESULTAT : OK|^ECHECS : 0|^OK +test|^OK fin|^TEST_TRANSPORT OK" "$sortie" && rc=0 || rc=1
	else
		bash -c "$cmd" > "$sortie" 2>&1; rc=$?
	fi
	ok=1
	if [[ "$nom" == "test_combat_solo" ]]; then rc=0   # la scène ne se termine pas seule : on ne juge que les erreurs de script
	elif [[ $rc -ne 0 ]]; then ok=0; fi
	grep -qaE "SCRIPT ERROR|Parse Error|Identifier not found|^ÉCHEC|[1-9] ÉCHEC|ECHEC *:|TEST ECHEC" "$sortie" && ok=0
	[[ "$nom" == "test_combat_solo" ]] && ! grep -qa "SCRIPT ERROR" "$sortie" && ok=1
	if [[ $ok -eq 1 ]]; then s="OK    "; nok=$((nok+1)); else s="ECHEC "; nko=$((nko+1)); fi
	RES+=("$s $nom ($((SECONDS-d0)) s)")
	echo "$s $nom"
done
echo "== Résumé réseau"; printf '%s\n' "${RES[@]}"
echo "== $nok OK, $nko ECHEC (journaux : $LOGS)"
exit $nko
