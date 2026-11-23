#!/bin/bash
# Sons du RAYON NOIR (sort continu des ténèbres, scripts/magie/rayon_noir.gd) : synthèse ffmpeg (création propre, CC0).
#  - rayon_noir_boucle.wav (boucle de 4 s, nombres entiers de périodes) : grondement grave qui pulse lentement (0,5 Hz, comme
#    l'ondulation du rayon), souffle sombre et chuchotements (bruit passe-bande haché par une enveloppe lente) ;
#  - rayon_noir_allume.wav : départ (souffle aspiré qui monte puis coup sourd), joué une fois à l'allumage ;
#  - rayon_noir_eteint.wav : le rayon se dissipe (souffle qui retombe).
# Usage : bash outils/sons_magie/generer_rayon_noir.sh   (depuis la racine du projet)
set -e
D=assets/sons/magie
T=$(mktemp -d)
# grondement : fondamentale 41 Hz + harmoniques, battement lent (2 Hz → 4 s = 8 périodes ; pulsation 0,5 Hz = 2 périodes)
ffmpeg -v error -y -f lavfi -i "aevalsrc='(0.42*sin(2*PI*41*t)+0.22*sin(2*PI*61.5*t+0.6*sin(2*PI*0.5*t))+0.12*sin(2*PI*82*t)+0.05*sin(2*PI*164*t))*(0.72+0.28*sin(2*PI*0.5*t))':d=4:s=32000" $T/grave.wav
# souffle sombre (bruit brun filtré, respire à 0,5 Hz)
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=4:c=brown:a=0.9:s=3" -af "lowpass=f=420,highpass=f=60,volume='0.55+0.35*sin(2*PI*0.5*t+1.2)':eval=frame" -ar 32000 -ac 1 $T/souffle.wav
# chuchotements : bruit blanc passe-bande (1,8-4 kHz) haché par des « syllabes » (enveloppe 3,25 Hz et 4,75 Hz), très bas
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=4:c=white:a=0.8:s=17" -af "bandpass=f=2600:w=0.9,volume='0.10*pow(max(0,sin(2*PI*3.25*t)*sin(2*PI*0.75*t+0.4)),2)':eval=frame" -ar 32000 -ac 1 $T/chu1.wav
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=4:c=white:a=0.8:s=29" -af "bandpass=f=1900:w=0.8,volume='0.08*pow(max(0,sin(2*PI*4.75*t+1.0)*sin(2*PI*0.5*t+2.0)),2)':eval=frame" -ar 32000 -ac 1 $T/chu2.wav
ffmpeg -v error -y -i $T/grave.wav -i $T/souffle.wav -i $T/chu1.wav -i $T/chu2.wav -filter_complex "[0][1][2][3]amix=inputs=4:normalize=0,alimiter=limit=0.9:level=false,volume=0.5" -ar 32000 -ac 1 -c:a pcm_s16le $D/rayon_noir_boucle.wav
# allumage : souffle aspiré qui monte (0,22 s) puis coup sourd grave
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=0.3:c=pink:a=0.9:s=7" -af "bandpass=f=700:w=1.3,volume='min(1,t*5)':eval=frame,afreqshift=shift=250" -ar 44100 -ac 1 $T/monte.wav
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.95*sin(2*PI*(55-25*t)*t)*exp(-t*6)+0.25*sin(2*PI*330*t)*exp(-t*14)':d=0.9:s=44100" $T/coup.wav
ffmpeg -v error -y -i $T/coup.wav -af "adelay=200" $T/coup_d.wav
ffmpeg -v error -y -i $T/monte.wav -i $T/coup_d.wav -filter_complex "[0][1]amix=inputs=2:normalize=0,alimiter=limit=0.7:level=false,afade=t=out:st=0.85:d=0.25" -t 1.1 -ar 44100 -ac 1 -c:a pcm_s16le $D/rayon_noir_allume.wav
# extinction : souffle qui retombe et grave qui s'éteint
ffmpeg -v error -y -f lavfi -i "anoisesrc=d=0.8:c=brown:a=0.9:s=11" -af "lowpass=f=900,volume='exp(-t*4)':eval=frame" -ar 44100 -ac 1 $T/retombe.wav
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.6*sin(2*PI*(48-18*t)*t)*exp(-t*5)':d=0.8:s=44100" $T/grave_fin.wav
ffmpeg -v error -y -i $T/retombe.wav -i $T/grave_fin.wav -filter_complex "[0][1]amix=inputs=2:normalize=0,alimiter=limit=0.6:level=false,afade=t=out:st=0.55:d=0.25" -t 0.8 -ar 44100 -ac 1 -c:a pcm_s16le $D/rayon_noir_eteint.wav
rm -rf $T
echo "sons du rayon noir faits"
