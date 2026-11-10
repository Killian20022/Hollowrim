extends SceneTree
## Liste les clips de Humain.bibliotheque() (partagée par PnjNordique, Humain, Tripo) avec durée et boucle ; `-- <chemin.res>` : une autre bibliothèque.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var b: AnimationLibrary = load(args[0]) if not args.is_empty() else Humain.bibliotheque()
	var l := b.get_animation_list()
	for n in l:
		var a := b.get_animation(n)
		print("CLIP %s %.2f %s pistes=%d" % [n, a.length, "boucle" if a.loop_mode != Animation.LOOP_NONE else "", a.get_track_count()])
	print("TOTAL ", l.size())
	quit()
