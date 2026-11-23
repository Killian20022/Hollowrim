#!/bin/bash
# Sons de la FOUDRE v2 (claquements synchronisés avec les nouvelles formes des arcs, docs/MAGIE_FOUDRE_V2.md) :
# synthèse ffmpeg (création propre, CC0) : un claquement sec = clic large bande très court + crépitement (bruit blanc
# découpé en salves) passé à l'aigu, queue de grésillement de 60-110 ms.
# Usage : bash outils/sons_magie/generer_foudre.sh   (depuis la racine du projet)
set -e
D=assets/sons/magie
T=$(mktemp -d)
for i in 1 2 3; do
  dur=$(echo "0.09 0.12 0.15" | cut -d' ' -f$i)
  f=$(echo "2200 2600 1900" | cut -d' ' -f$i)
  ffmpeg -v error -y -f lavfi -i "anoisesrc=d=$dur:c=white:a=1.0:s=$((i*13))" -af "highpass=f=$f,volume='exp(-t*38)*(0.55+0.45*gt(sin(2*PI*(310+60*$i)*t),0.2))':eval=frame" -ar 44100 -ac 1 $T/crep$i.wav
  ffmpeg -v error -y -f lavfi -i "aevalsrc='0.9*exp(-t*900)*sin(2*PI*1700*t)+0.5*exp(-t*160)*sin(2*PI*(420-900*t)*t)':d=$dur:s=44100" $T/clic$i.wav
  ffmpeg -v error -y -i $T/crep$i.wav -i $T/clic$i.wav -filter_complex "[0][1]amix=inputs=2:normalize=0,alimiter=limit=0.6,afade=t=out:st=$(python3 -c "print($dur*0.6)"):d=$(python3 -c "print($dur*0.4)")" -ar 44100 -ac 1 -c:a pcm_s16le $D/foudre_claque_$i.wav
done
rm -rf $T
echo "sons de foudre faits"
