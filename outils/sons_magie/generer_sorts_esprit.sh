#!/bin/bash
# Sons des SORTS DE L'ESPRIT (Répulsion, Lévitation d'ennemi, Attraction) : synthèse ffmpeg (création propre, CC0), même
# famille que la télékinésie (outils/sons_magie/generer_telekinesie.sh) + sons CC0 de protection retaillés (assets/LICENCES.md).
# Usage : bash outils/sons_magie/generer_sorts_esprit.sh   (depuis la racine du projet)
set -e
D=assets/sons/magie
T=$(mktemp -d)
# onde de choc (Répulsion) : coup sourd grave + souffle d'air qui part (bruit passe-bande descendant) + départ de protection grave
for i in 1 2; do
  ffmpeg -v error -y -f lavfi -i "aevalsrc='0.95*sin(2*PI*(58-26*t)*t)*exp(-t*9)':d=0.6:s=44100" $T/coup$i.wav
  ffmpeg -v error -y -f lavfi -i "anoisesrc=d=0.8:c=white:a=0.9:s=$((i+11))" -af "bandpass=f=$([ $i = 1 ] && echo 900 || echo 1100):w=1.6,volume='min(1,t*40)*exp(-t*4.5)':eval=frame,lowpass=f=3500" -ar 44100 -ac 1 $T/air$i.wav
  ffmpeg -v error -y -i $D/protection_lancer_$i.wav -af "asetrate=44100*0.6,aresample=44100,volume=0.5,lowpass=f=2400" -ar 44100 -ac 1 $T/prot$i.wav
  ffmpeg -v error -y -i $T/coup$i.wav -i $T/air$i.wav -i $T/prot$i.wav -filter_complex "[0][1][2]amix=inputs=3:normalize=0,alimiter=limit=0.75,afade=t=out:st=0.6:d=0.25" -t 0.9 -ar 44100 -ac 1 -c:a pcm_s16le $D/esprit_onde_$i.wav
done
# vortex (Attraction, boucle de 2 s, nombres entiers de périodes) : souffle tournant (bruit filtré modulé à 2 Hz), bourdonnement grave
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=2:c=pink:a=0.5:s=5" -af "bandpass=f=700:w=1.4,volume='0.55+0.45*sin(2*PI*2*t)':eval=frame" -ar 32000 -ac 1 $T/tour.wav
ffmpeg -v error -y -f lavfi -i "aevalsrc='(0.3*sin(2*PI*82*t)+0.18*sin(2*PI*123*t+sin(2*PI*2*t))+0.08*sin(2*PI*246*t))*(0.8+0.2*sin(2*PI*4*t))':d=2:s=32000" $T/grave.wav
ffmpeg -v error -y -i $T/tour.wav -i $T/grave.wav -filter_complex "[0][1]amix=inputs=2:normalize=0,volume=0.7" -ar 32000 -ac 1 -c:a pcm_s16le $D/esprit_vortex.wav
# relâchement du vortex : implosion (souffle aspiré qui monte) puis claquement et coup grave
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=0.35:c=pink:a=0.8:s=9" -af "bandpass=f=1200:w=1.2,volume='min(1,t*3)':eval=frame,afreqshift=shift=400" -ar 44100 -ac 1 $T/aspire.wav
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.95*sin(2*PI*(64-30*t)*t)*exp(-t*7)+0.3*sin(2*PI*520*t)*exp(-t*16)':d=0.8:s=44100" $T/claque.wav
ffmpeg -v error -y -i $T/claque.wav -af "adelay=330" $T/claque_d.wav
ffmpeg -v error -y -i $T/aspire.wav -i $T/claque_d.wav -filter_complex "[0][1]amix=inputs=2:normalize=0,alimiter=limit=0.75,afade=t=out:st=0.9:d=0.25" -t 1.15 -ar 44100 -ac 1 -c:a pcm_s16le $D/esprit_vortex_fin.wav
# emprise (Lévitation d'ennemi) : saisie plus grave et plus longue (bruit qui monte, coup sourd, scintillement descendant)
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=1.0:c=pink:a=0.9:s=21" -af "bandpass=f=600:w=1.2,volume='min(1,t*3)*max(0,1-t/1.0)':eval=frame,afreqshift=shift=200" -ar 44100 -ac 1 $T/monte.wav
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.9*sin(2*PI*(52-20*t)*t)*exp(-t*8)':d=0.6:s=44100" $T/sourd.wav
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.22*(sin(2*PI*520*t*(1-0.25*t))+0.6*sin(2*PI*780*t*(1-0.25*t)))*min(1,t*6)*exp(-t*2.6)':d=1.0:s=44100" $T/brille.wav
ffmpeg -v error -y -i $T/monte.wav -i $T/sourd.wav -i $T/brille.wav -filter_complex "[0][1][2]amix=inputs=3:normalize=0,alimiter=limit=0.7,afade=t=out:st=0.8:d=0.2" -ar 44100 -ac 1 -c:a pcm_s16le $D/esprit_emprise.wav
rm -rf $T
echo "sons des sorts de l'esprit faits"
