#!/bin/bash
# planche.sh <famille> <dossier_avant> <dossier_apres> <sortie.png> [ref_tripo.png]
f=$1; A=$2; P=$3; S=$4; R=$5
FONT=/mnt/c/Windows/Fonts/arial.ttf
row() { # dossier etiquette sortie
  local d=$1 lab=$2 out=$3 in=() n=0
  for v in face tq profil dos buste buste_dos; do [ -f "$d/${f}_$v.png" ] && { in+=(-i "$d/${f}_$v.png"); n=$((n+1)); }; done
  ffmpeg -loglevel error -y "${in[@]}" -filter_complex "hstack=$n,drawtext=fontfile=$FONT:text='$lab':x=10:y=h-40:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.6" "$out"
}
row "$A" "AVANT - $f" /tmp/aff_prec/_ra.png
row "$P" "APRES - $f" /tmp/aff_prec/_rp.png
if [ -n "$R" ] && [ -f "$R" ]; then
  W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 /tmp/aff_prec/_ra.png)
  ffmpeg -loglevel error -y -i "$R" -vf "scale=-2:540,pad=$W:540:(ow-iw)/2:0:color=0x111114,drawtext=fontfile=$FONT:text='REFERENCE':x=10:y=h-40:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.6" /tmp/aff_prec/_rr.png
  ffmpeg -loglevel error -y -i /tmp/aff_prec/_rr.png -i /tmp/aff_prec/_ra.png -i /tmp/aff_prec/_rp.png -filter_complex vstack=3 "$S"
else
  ffmpeg -loglevel error -y -i /tmp/aff_prec/_ra.png -i /tmp/aff_prec/_rp.png -filter_complex vstack=2 "$S"
fi
echo "PLANCHE $S"
