#!/bin/bash
# usage: g.sh args... (galerie_squelette)
G=/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe; P='C:\Users\lopezk19\Jeux\nordique_squelette-guerrier'
$G --path "$P" --script res://outils/galerie_squelette.gd -- "$@" 2>&1 | grep -iE "error|script" | head
