#!/usr/bin/env bash
# Sons du démembrement (gore, étape 2) depuis les packs CC0 de references/sons_cc0/ (licences : assets/LICENCES.md).
# Retaillés (silence de tête coupé, 1,6 s max, fondu de fin), mono 44,1 kHz PCM 16 bits, crête normalisée à -3 dBFS.
#   bash outils/sons_gore/generer.sh [dossier des packs]
set -eu
SRC="${1:-/mnt/c/Users/lopezk19/Jeux/references/sons_cc0}"
DST="$(cd "$(dirname "$0")/../.." && pwd)/assets/sons/combat/gore"
mkdir -p "$DST"
fab() {  # fab <sortie sans extension> <source> [durée max]
	local out="$DST/$1.wav" src="$SRC/$2" d="${3:-1.6}"
	local pic
	pic=$(ffmpeg -hide_banner -nostats -i "$src" -af "silenceremove=start_periods=1:start_threshold=-45dB,atrim=0:$d,volumedetect" -f null - 2>&1 | sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB.*/\1/p')
	local gain
	gain=$(awk -v p="${pic:-0}" 'BEGIN{print -3 - p}')
	ffmpeg -hide_banner -loglevel error -y -i "$src" -af "silenceremove=start_periods=1:start_threshold=-45dB,atrim=0:$d,afade=t=out:st=$(awk -v d=$d 'BEGIN{print d-0.25}'):d=0.25,volume=${gain}dB" -ac 1 -ar 44100 -c:a pcm_s16le "$out"
	echo "$1 <- $2 (gain ${gain} dB)"
}
W="8-wet-squish-slurp-impacts/independent_nu_ljudbank-wet_squish_slurp_impacts.7z_x/impsplat"
F="fleshy-bone-breaksnap-sfx/wet_breaks.zip_x"
D="deep-bone-crackbreak-sfx/deep_breaks.zip_x"
B="75-cc0-breaking-falling-hit-sfx/sfx_breaking_and_falling.zip_x"
I="ice-breakingshattering/IceShatters_0.zip_x/IceShatters"
# lame qui tranche chair et os (membre coupé)
fab membre_tranche_01 "$F/Wet Break 1.wav" 1.0
fab membre_tranche_02 "$F/Wet Break 3.wav" 1.0
fab membre_tranche_03 "$F/Wet Break 5.wav" 1.0
fab membre_tranche_04 "$F/Wet Break 7.wav" 1.0
# giclée du moignon (jet qui part)
fab giclee_01 "$W/impactsplat01.mp3.flac" 1.2
fab giclee_02 "$W/impactsplat03.mp3.flac" 1.2
fab giclee_03 "$W/impactsplat05.mp3.flac" 1.2
fab giclee_04 "squish-sounds-effects/squishsplat_impact.mp3" 1.2
# chute du membre au sol
fab chute_membre_01 "$B/bfh1_falling_01.ogg" 1.0
fab chute_membre_02 "$B/bfh1_falling_02.ogg" 1.0
fab chute_membre_03 "$B/bfh1_falling_03.ogg" 1.0
fab chute_membre_04 "squish-sounds-effects/squish_03.mp3" 1.0
# os qui cassent (squelettes : membre arraché ; coupe nette d'un os)
fab os_brise_01 "$D/Deep Break 1.wav" 1.0
fab os_brise_02 "$D/Deep Break 3.wav" 1.0
fab os_brise_03 "$D/Deep Break 6.wav" 1.0
fab os_brise_04 "bones-2/bones-2.wav" 1.2
# membre gelé qui éclate
fab glace_eclate_01 "$I/LedasLuzta.ogg" 1.4
fab glace_eclate_02 "$I/LedasLuzta2.ogg" 1.4
fab glace_eclate_03 "$I/LedasLuzta4.ogg" 1.4
# corps carbonisé (crépitement)
fab carbonise_01 "catching-fire/flame_0.ogg" 1.6
# boyaux qui tombent (coupe en deux)
fab boyaux_01 "ripping-into-meat/rippingintomeat_0.mp3" 1.6
fab boyaux_02 "squish-sounds-effects/squish_05.mp3" 1.2
