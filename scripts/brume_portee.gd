class_name BrumePortee
extends RefCounted
## Brume sous terre calée sur la portée de dessin (30 m, bord proche des maillages) : la brume exponentielle d'avant (densité 0,022-0,028)
## laissait 43 % (crypte) à 52 % (grotte) de la lumière des objets à 30 m, donc on les voyait apparaître / disparaître. Ici la brume en profondeur
## (même couleur, même allure jusqu'à ~15-20 m) atteint 100 % à la portée : la coupure se fait dans une surface déjà entièrement noyée, et le fond
## (BG_COLOR) prend la couleur de la brume, donc rien ne se détache. Ni le shader ps1 ni la palette ne changent.
const FIN := 31.0              # la brume est pleine un peu avant la coupure (30 m + marge de 3 m d'hystérésis côté moteur)

## `debut` : distance où la brume commence ; `courbe` : puissance de la rampe (smoothstep puis pow).
static func appliquer(env: Environment, debut: float, courbe: float) -> void:
	if OS.get_cmdline_user_args().has("--ancienne-brume"):    # comparaisons avant/apres (captures, mesures)
		return
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = debut
	env.fog_depth_end = FIN
	env.fog_depth_curve = courbe
	env.fog_density = 1.0
	env.fog_height_density = 0.0
	if env.background_mode == Environment.BG_COLOR:
		env.background_color = env.fog_light_color
