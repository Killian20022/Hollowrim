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
	"test_filet|--nouvelle"
	"test_quetes|--nouvelle"
	"test_archer|--nouvelle"
	"test_patrouille|--nouvelle"
	"test_boss_phases|--nouvelle"
	"test_vegetation_biome|--nouvelle"
	"test_chemin_biome|--nouvelle --paisible"
	"test_collisions_biome|--nouvelle"
	"test_palissade|--nouvelle"
	"test_escaliers_village|--nouvelle --paisible"
	"test_accessibilite_village|--nouvelle --paisible"   # aucune poche fermée autour du village (piège du moulin, 2026-10-26)
	"test_crypte|--nouvelle"
	"test_crypte_mort|--nouvelle"
	"test_crypte_combat|--nouvelle"   # combats enchaînés dans la crypte : sons WAV, caches d'effets, arrêt sur image bref, cadavres (bug « ça rame quand je frappe »)
	"test_secousse_boss|--nouvelle"
	"test_squelette|--nouvelle"
	"test_squelette_traversees|--nouvelle"
	"test_grotte|--nouvelle"
	"test_entree_crypte|--nouvelle"
	"test_gel_exterieur|--nouvelle"
	"test_grotte_acces|--nouvelle"
	"test_grotte_jeu|--nouvelle"
	"test_salle_active|--nouvelle"
	"test_cycle_midi|--nouvelle"
	"test_mecanismes|--nouvelle"
	"test_degats_sanctuaire|--nouvelle"
	"test_dragon|--nouvelle"
	"test_dragon_monde|--nouvelle"
	"test_marche_pnj|--nouvelle"
	"test_mort_ragdoll|--nouvelle"
	"test_ragdoll|--nouvelle"
	"test_musique|--nouvelle"
	"test_villageois|--nouvelle"
	"test_pnj_village|--nouvelle"
	"test_gardes_village|--nouvelle --paisible"
	"test_persos_base|--nouvelle"
	"test_guerrier|--nouvelle"
	"test_mage|--nouvelle"
	"test_chasseresse|--nouvelle"
	"test_chasseresse_homme|--nouvelle"
	"test_gardien|--nouvelle"
	"test_troll|--nouvelle"
	"test_draugr|--nouvelle"
	"test_ennemis_nordiques|--nouvelle"
	"test_degats|--nouvelle --test"   # dégâts, posture, finishers, décapitation, plafonds du sang (combat/degats_gore)
	"test_troll_ia|--nouvelle --test"   # IA du troll de givre (ennemis/troll_mage)
	"test_mage_ia|--nouvelle --test"    # IA du mage nordique (ennemis/troll_mage)
	"test_persos_tous|--persos-tous"
	"test_interieurs|--nouvelle"
	"test_primitives|"
	"test_epees_longues|--nouvelle"   # 5 épées longues : nœuds prise/garde/pointe, repère, échelle, matériaux
	"test_combat_epee|--nouvelle"   # combat à l'épée : tracé de lame identique à 30/60/144 i/s, mur, draugr, garde, endurance (scenes/test_combat.tscn)
	"test_camera_corps|--nouvelle"   # caméra « corps » et mouvements passifs : mêmes courbes à 30/60/144 i/s, amplitudes subtiles, main gauche déphasée, options Balancement / Tête / Secousses, chute réelle de 2 m
	"test_deux_mains|--nouvelle"   # deux mains (épée + torche / sort / bouclier, deux sorts, deux mains ; deux épées refusées) et profils des 5 épées
	"test_collisions_lame|--nouvelle"   # collisions de la lame dans la zone de test (ZoneCollisions) : murs fins, coin, porte, serrés, poteau, 20/30/60/144 i/s
	"test_magie|--nouvelle"   # magie et deux mains : compatibilité, mana, 12 sorts + soin + protection, double, réactions, interruption, épée + magie, enchantement, sauvegarde (docs/MAGIE.md)
	"test_effets_magie|--nouvelle"   # visuels de la magie (EffetsMagie / GestionMagie) : contrat, plafonds, retour au pool (docs/MAGIE_EFFETS.md)
	"test_hud_combat|--nouvelle"   # HUD de combat : vie/mana/endurance, mains, recharges, double, statuts, raccourcis, icônes
	"test_inventaire_mains|--nouvelle"   # écran d'inventaire (I) : équiper G / D, refus expliqués, deux mains, raccourcis 1-0 assignés, sauvegarde
	"test_defense|--nouvelle"   # défense phase 3 : garde orientée, garde brisée, anti-spam, parade parfaite (vrai draugr), contre, finisher joueur
	"test_finishers|--nouvelle"   # finishers alignés : épée plantée (lame DANS le torse), pommeau, décapitation, dos, plongé ; choix selon le contexte
	"test_menu_titre|--nouvelle"   # menu principal : Continuer grisé sans sauvegarde valide, parcours au clavier, mise en page
	"test_sortie|--nouvelle"   # sortie Hollowrim : migration, copie de secours, options (dossiers temporaires)
	"test_sauvegarde|ecrire;verifier"   # deux processus à la suite
)
# tests dont le résultat dépend du pas de physique : lancés en temps réel (test_ragdoll : OK aussi en --fixed-fps depuis la correction du signe des limites de charnière, 10/10 sous charge ; gardé en temps réel par prudence)
TEMPS_REEL="test_ragdoll test_mort_ragdoll"
nok=0; nko=0; RES=(); t_debut=$SECONDS
for t in "${TESTS[@]}"; do
	nom="${t%%|*}"; args="${t#*|}"
	[[ -n "$MOTIF" && "$nom" != *"$MOTIF"* ]] && continue
	d0=$SECONDS; sortie="$LOGS/$nom.log"; note=""
	DELAI="${TEMPS_MAX:-240}"; [[ "$nom" == "test_degats_sanctuaire" && -z "${TEMPS_MAX:-}" ]] && DELAI=600   # ~245 s seul, davantage sur machine chargee
	RAPIDE="--fixed-fps 60"; REEL=0; [[ " $TEMPS_REEL " == *" $nom "* ]] && { RAPIDE=""; REEL=1; }
	for essai in 1 2; do
		: > "$sortie"; rc=0
		IFS=';' read -ra ETAPES <<< "$args"   # une étape = un lancement (test_sauvegarde en a deux)
		for etape in "${ETAPES[@]}"; do
			timeout "$DELAI" "$G" --headless $RAPIDE --path "$P" --script "res://outils/$nom.gd" -- $etape >> "$sortie" 2>&1
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
if [[ -n "${AVEC_FENETRE:-}" && ( -z "$MOTIF" || "test_menus" == *"$MOTIF"* ) ]]; then
	d0=$SECONDS   # titre → nouvelle partie → pause → sauvegarde (+ copie de secours) → continuer → restaurer (4 lancements à fenêtre)
	if bash "$ICI/outils/test_menus.sh" > "$LOGS/test_menus.log" 2>&1; then s="OK    "; nok=$((nok+1)); else s="ÉCHEC "; nko=$((nko+1)); fi
	RES+=("$s test_menus (fenêtre, $((SECONDS-d0)) s)")
fi
echo "== Résumé des tests sans fenêtre"
printf '%s\n' "${RES[@]}"
echo "== $nok OK, $nko ÉCHEC, durée totale $((SECONDS-t_debut)) s (journaux : $LOGS)"
exit $nko
