# Réseau — lot 3 (pause, menus, sommeil en coop, « à terre »)

## API
- `PauseCoop` (`scripts/reseau/pause_coop.gd`, statique) : `demander_pause(source)`, `liberer(source)`, `en_pause(arbre)`, `occupe()`, `coop()`, `R()`.
  Solo : identique à `get_tree().paused = true/false`. Coop : le monde ne s'arrête jamais ; `joueur.en_dialogue` = true (contrôles gelés, vulnérable) tant qu'une fenêtre est ouverte.
  Toute lecture « un menu est-il ouvert ? » = `PauseCoop.en_pause(get_tree())`. Les 8 fenêtres (menu pause, personnage, coffre, butin, marchand, forge, crochetage, sommeil) l'utilisent.
- `PauseCoop.R()` : l'autoload `Reseau` par son chemin. **Dans les scripts partagés (chargés par les tests `--script`), ne pas écrire `Reseau.` : l'identifiant n'existe pas à la compilation.**
- `VoteCoop` (`scripts/reseau/vote_coop.gd`, nœud) : `proposer(type, donnees, timeout)`, `repondre(oui, raison)`, `verifier()`, signaux `ouvert` / `clos`, `verificateur`. Hôte = arbitre ; unanimité, refus, délai (15 s), refus si touché. Touches O / N.
- `Sommeil` : en coop, valider la fenêtre Dormir/Attendre lance un vote « sommeil » ; accepté, chaque machine fait son fondu et ses jauges, l'hôte avance l'heure (évènement `sommeil_heure`) et le monde (PNJ, faune, marchands).
- `ATerre` (`scripts/reseau/a_terre.gd`, enfant du joueur local) : 0 PV en coop avec un allié debout -> `joueur.a_terre` 30 s ; allié à < 2,5 m maintenant E 3 s -> relevé à 30 % de PV ; délai écoulé ou plus aucun allié debout -> mort habituelle (`deces`). Évènements `a_terre_etat`, `a_terre_releve`.
- `Effets` : jamais d'échelle de temps en coop (`PauseCoop.coop()`).

## Test
`bash outils/test_pause_vote.sh` (2 Godot headless, `GODOT_MAX=2`) : menus sans pause, vote unanime / refusé / délai / annulé si touché, à terre -> relevé, délai, sans allié, solo.
