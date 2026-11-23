#!/bin/bash
# Sons de la TÉLÉKINÉSIE (école « esprit ») : synthèse ffmpeg (création propre, CC0) + sons CC0 de protection retaillés
# (protection_lancer_*, Electricity Game Sound Pack, CC0 : assets/LICENCES.md).
# Usage : bash outils/sons_magie/generer_telekinesie.sh   (depuis la racine du projet)
set -e
D=assets/sons/magie
T=$(mktemp -d)
# saisie : souffle qui monte (bruit filtré balayé vers l'aigu), coup sourd, scintillement
for i in 1 2; do
  f0=$([ $i = 1 ] && echo 700 || echo 820)
  ffmpeg -v error -y -f lavfi -i "anoisesrc=d=0.75:c=pink:a=0.9:s=$i" -af "bandpass=f=900:w=1.2,volume='min(1,t*5)*max(0,1-t/0.75)':eval=frame,afreqshift=shift=300" -ar 44100 -ac 1 $T/souffle$i.wav
  ffmpeg -v error -y -f lavfi -i "aevalsrc='0.9*sin(2*PI*(70-30*t)*t)*exp(-t*14)':d=0.4:s=44100" $T/coup$i.wav
  ffmpeg -v error -y -f lavfi -i "aevalsrc='0.25*(sin(2*PI*${f0}*t*(1+0.6*t))+0.6*sin(2*PI*${f0}*1.5*t*(1+0.6*t)))*min(1,t*8)*exp(-t*3.2)':d=0.75:s=44100" $T/brille$i.wav
  ffmpeg -v error -y -i $T/souffle$i.wav -i $T/coup$i.wav -i $T/brille$i.wav -filter_complex "[0][1][2]amix=inputs=3:normalize=0,alimiter=limit=0.7,afade=t=out:st=0.6:d=0.15" -ar 44100 -ac 1 -c:a pcm_s16le $D/esprit_saisie_$i.wav
done
# lancer : coup d'air rapide (bruit passe-bande qui descend) + départ de protection grave
for i in 1 2; do
  ffmpeg -v error -y -f lavfi -i "anoisesrc=d=0.5:c=white:a=0.8:s=$((i+7))" -af "bandpass=f=1400:w=1.5,volume='min(1,t*30)*exp(-t*7)':eval=frame,lowpass=f=4000" -ar 44100 -ac 1 $T/air$i.wav
  ffmpeg -v error -y -i $D/protection_lancer_$i.wav -af "asetrate=44100*0.72,aresample=44100,volume=0.55,lowpass=f=3000" -ar 44100 -ac 1 $T/prot$i.wav
  ffmpeg -v error -y -i $T/air$i.wav -i $T/prot$i.wav -filter_complex "[0][1]amix=inputs=2:normalize=0,alimiter=limit=0.7,afade=t=out:st=0.4:d=0.2" -t 0.65 -ar 44100 -ac 1 -c:a pcm_s16le $D/esprit_lancer_$i.wav
done
# tenue (boucle de 2 s, nombres entiers de périodes) : bourdonnement doux, battement lent, souffle d'air léger
ffmpeg -v error -y -f lavfi -i "aevalsrc='(0.35*sin(2*PI*110*t)+0.22*sin(2*PI*165*t)+0.12*sin(2*PI*330*t+sin(2*PI*1*t)))*(0.75+0.25*sin(2*PI*3*t))':d=2:s=32000" $T/hum.wav
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=2:c=pink:a=0.12:s=3" -af "bandpass=f=2500:w=1" -ar 32000 $T/air.wav
ffmpeg -v error -y -i $T/hum.wav -i $T/air.wav -filter_complex "[0][1]amix=inputs=2:normalize=0,volume=0.6" -ar 32000 -ac 1 -c:a pcm_s16le $D/esprit_tenue.wav
rm -rf $T
echo "sons de télékinésie faits"
