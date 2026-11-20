#!/bin/bash
# Planche récapitulative : les 11 bêtes v2 en 3/4 (jour en haut, nuit en bas), 480x270 chacune, grille 4x3 (+ la v1 du loup pour repère)
T=/mnt/c/Users/lopezk19/Jeux/rendus/animaux_v2/tmp; O=/mnt/c/Users/lopezk19/Jeux/rendus/animaux_v2
S=${1:-_r4}
N=(loup husky renard cerf biche cheval cheval_blanc ane vache taureau araignee)
for e in jour nuit; do
  in=(); for n in "${N[@]}"; do in+=(-i "$T/$n$S/ap_${e}_trois_quarts.png"); done
  in+=(-i "$T/loup$S/av_${e}_trois_quarts.png")
  ffmpeg -loglevel error -y "${in[@]}" -filter_complex "xstack=inputs=12:layout=0_0|w0_0|w0+w1_0|w0+w1+w2_0|0_h0|w0_h0|w0+w1_h0|w0+w1+w2_h0|0_h0+h4|w0_h0+h4|w0+w1_h0+h4|w0+w1+w2_h0+h4" "$T/recap_$e.png"
done
ffmpeg -loglevel error -y -i "$T/recap_jour.png" -i "$T/recap_nuit.png" -filter_complex vstack "$O/recap_11_especes$S.png"
echo "$O/recap_11_especes$S.png"
