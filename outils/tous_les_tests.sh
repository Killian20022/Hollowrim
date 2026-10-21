#!/usr/bin/env bash
# Enchaîne tous les outils/test_*.gd SANS FENÊTRE (--headless) et affiche un résumé OK/ÉCHEC + durée.
#   bash outils/tous_les_tests.sh [motif]      ex. bash outils/tous_les_tests.sh dragon   (seulement test_*dragon*)
#   Variables : GODOT (exécutable), TEMPS_MAX (secondes par test, défaut 240), AVEC_FENETRE=1 (ajoute les tests qui exigent
#   une fenêtre : test_biome comparer), JOURNAUX=<dossier> (défaut captures/tests : un .log par test).
# Verdict : code de sortie 0, aucune « SCRIPT ERROR » et aucun « ÉCHEC » (ni « ECHECS : n » avec n>0) dans la sortie.
# --fixed-fps 60 : la simulation tourne aussi vite que possible (au lieu du temps réel : test_degats_sanctuaire > 240 s → ~55 s).
# Tous les lancements portent des arguments (« -- … ») : le jeu écrit alors user://sauvegarde_test_<dossier>.json (un par worktree), jamais la vraie partie.
# Code de sortie du script : nombre de tests en échec.
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
LOGS="${JOURNAUX:-$ICI/captures/tests}"; mkdir -p "$LOGS"
MOTIF="${1:-}"
# nom_du_test|arguments après « -- » (toujours au moins un, voir plus haut)
TESTS=(
	"test_quetes|--nouvelle"
	"test_archer|--nouvelle"
	"test_patrouille|--nouvelle"
	"test_boss_phases|--nouvelle"
	"test_vegetation_biome|--nouvelle"
	"test_chemin_biome|--nouvelle --paisible"
	"test_collisions_biome|--nouvelle"
	"test_crypte|--nouvelle"
	"test_crypte_mort|--nouvelle"
	"test_squelette|--nouvelle"
	"test_squelette_traversees|--nouvelle"
	"test_grotte|--nouvelle"
	"test_grotte_acces|--nouvelle"
	"test_grotte_jeu|--nouvelle"
	"test_mecanismes|--nouvelle"
	"test_degats_sanctuaire|--nouvelle"
	"test_dragon|--nouvelle"
	"test_dragon_monde|--nouvelle"
	"test_marche_pnj|--nouvelle"
	"test_mort_ragdoll|--nouvelle"
	"test_ragdoll|--nouvelle"
	"test_musique|--nouvelle"
	"test_villageois|--nouvelle"
	"test_persos_base|--nouvelle"
	"test_guerrier|--nouvelle"
	"test_mage|--nouvelle"
	"test_chasseresse|--nouvelle"
	"test_gardien|--nouvelle"
	"test_interieurs|--nouvelle"
	"test_primitives|"
	"test_sauvegarde|ecrire;verifier"   # deux processus à la suite
)
# tests dont le résultat dépend du pas de physique : lancés en temps réel (test_ragdoll : OK aussi en --fixed-fps depuis la correction du signe des limites de charnière, 10/10 sous charge ; gardé en temps réel par prudence)
TEMPS_REEL="test_ragdoll test_mort_ragdoll"
nok=0; nko=0; RES=(); t_debut=$SECONDS
for t in "${TESTS[@]}"; do
	nom="${t%%|*}"; args="${t#*|}"
	[[ -n "$MOTIF" && "$nom" != *"$MOTIF"* ]] && continue
	d0=$SECONDS; sortie="$LOGS/$nom.log"; note=""
	RAPIDE="--fixed-fps 60"; REEL=0; [[ " $TEMPS_REEL " == *" $nom "* ]] && { RAPIDE=""; REEL=1; }
	for essai in 1 2; do
		: > "$sortie"; rc=0
		IFS=';' read -ra ETAPES <<< "$args"   # une étape = un lancement (test_sauvegarde en a deux)
		for etape in "${ETAPES[@]}"; do
			timeout "${TEMPS_MAX:-240}" "$G" --headless $RAPIDE --path "$P" --script "res://outils/$nom.gd" -- $etape >> "$sortie" 2>&1
			r=$?; [[ $r -ne 0 ]] && rc=$r
		done
		if [[ $rc -eq 0 ]] && ! grep -qE "SCRIPT ERROR|ÉCHEC|ECHEC([^S]|$)|ECHECS *: *[1-9]" "$sortie"; then ok=1; else ok=0; fi
		[[ $ok -eq 1 || $REEL -eq 0 ]] && break
		note=", 2e essai"  # test sensible à la charge de la machine : un seul nouvel essai
	done
	if [[ $ok -eq 1 ]]; then s="OK    "; nok=$((nok+1)); else s="ÉCHEC "; nko=$((nko+1)); fi
	RES+=("$s $nom ($((SECONDS-d0)) s$note)")
done
if [[ -n "${AVEC_FENETRE:-}" && ( -z "$MOTIF" || "test_biome" == *"$MOTIF"* ) ]]; then
	d0=$SECONDS; sortie="$LOGS/test_biome.log"
	timeout 300 "$G" --path "$P" --resolution 160x90 --script res://outils/test_biome.gd -- comparer captures/biome/ref_ancien_fenetre.sig --sans-zone --sans-cles > "$sortie" 2>&1
	if grep -q "^OK" "$sortie" && ! grep -qE "DIFF|ERREUR|SCRIPT ERROR" "$sortie"; then s="OK    "; nok=$((nok+1)); else s="ÉCHEC "; nko=$((nko+1)); fi
	RES+=("$s test_biome (fenêtre, $((SECONDS-d0)) s)")
fi
echo "== Résumé des tests sans fenêtre"
printf '%s\n' "${RES[@]}"
echo "== $nok OK, $nko ÉCHEC, durée totale $((SECONDS-t_debut)) s (journaux : $LOGS)"
exit $nko
