#!/bin/bash
/mnt/c/Users/lopezk19/Outils/blender/blender.exe -b --python 'C:\Users\lopezk19\Jeux\nordique_squelette-guerrier\sources_blender\scripts\squelette_guerrier.py' 2>&1 | grep -E "OS gardes|ATLAS|TRIANGLES|EXPORT|Error|Traceback|File " 
