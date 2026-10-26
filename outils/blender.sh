#!/bin/bash
# Rejoue le modèle Blender du squelette nordique de CE dépôt (worktree courant, plus de chemin figé).
SCRIPT="$(wslpath -w "$(cd "$(dirname "$0")/.." && pwd)/sources_blender/scripts/squelette_nordique.py")"
/mnt/c/Users/lopezk19/Outils/blender/blender.exe -b --python "$SCRIPT" -- "$@" 2>&1 | grep -E "OS gardes|ATLAS|TRI|EXPORT|Error|Traceback|File "
