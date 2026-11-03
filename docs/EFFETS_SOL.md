# Monde réactif sur la neige (EffetsSol)

Code : `scripts/effets_sol.gd`, `scripts/glace_fondante.gd`, shader `shaders/ps1.gdshader` (fonction `effets_sol`).

- Masque monde N=320 texels (1/16 m, 20 m), torique, centré sur le joueur. RGBA flottant = instants de fin :
  R fonte, |G| durée (G<0 flaque), B empreinte, A brûlure (>0) / ombre (<0). Le GPU calcule l'effacement ; masque envoyé
  seulement après une écriture (<= 20/s) ; `effets_rect.w = 0` quand rien n'est vivant (coût nul).
- Pas, saut, atterrissage : appelés par `joueur.gd` ; ennemis/villageois proches : sondés toutes les 0,1 s (8 max).
- Sorts : `EffetsMagie` appelle `EffetsSol.sort_impact / sort_zone / sort_jet / sort_points`.
  Feu = neige fondue (30-60 s) + vapeur ; glace = blocs/pics (10 amas max) qui fondent, plus vite près du feu ;
  électricité = brûlure ; ténèbres = tache d'ombre (14 s).
- Seulement sur sol enneigé (`Sol.est_neige`) et dehors ; jamais sur l'eau.
- Tests : `outils/test_effets_sol.gd` (headless). Captures/film : `outils/captures_neige_sorts.gd` (fenêtre hors écran).
