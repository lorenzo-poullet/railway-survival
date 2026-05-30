# damage.gd
# À mettre en Autoload avec le nom exact : Damage
extends Node2D

var canvas_layer: CanvasLayer = null

# --- COULEURS ---
var couleur_degats := Color(1.0, 0.18, 0.12, 1.0)
var couleur_soin := Color(0.25, 1.0, 0.35, 1.0)
var couleur_xp := Color(0.25, 0.55, 1.0, 1.0)
var couleur_piece := Color(1.0, 0.86, 0.15, 1.0)

var couleur_ombre := Color(0.0, 0.0, 0.0, 0.75)

# --- STYLE DIRECT : dégâts / soin ---
var taille_texte_direct: int = 28
var duree_direct: float = 0.65
var montee_direct: float = 42.0
var grossissement_direct: float = 1.45

# --- STYLE FUMÉE : XP / pièces passives ---
var taille_texte_tick: int = 14
var duree_tick: float = 2.25
var montee_tick: float = 28.0
var derive_tick_x: float = 7.0
var ondulation_tick_x: float = 5.5
var vitesse_ondulation_tick: float = 1.15

# --- STYLE IMPORTANT : gain venant d'un mob, pas d'un passif ---
var taille_texte_important: int = 18
var duree_important: float = 2.25
var montee_important: float = 34.0
var derive_important_x: float = 8.0
var ondulation_important_x: float = 6.0
var vitesse_ondulation_important: float = 1.10

# Décalage random pour éviter que les chiffres soient tous pile au même endroit.
var dispersion_x_direct: float = 20.0
var dispersion_y_direct: float = 8.0

var dispersion_x_tick: float = 7.0
var dispersion_y_tick: float = 5.0


class SmokePopup:
	extends Label
	
	var temps: float = 0.0
	var duree: float = 1.0
	
	var position_depart: Vector2 = Vector2.ZERO
	var montee: float = 30.0
	var derive_x: float = 8.0
	var ondulation_x: float = 4.0
	var vitesse_ondulation: float = 1.0
	
	var phase: float = 0.0
	var sens: float = 1.0
	
	var scale_depart: Vector2 = Vector2(1.0, 1.0)
	var scale_fin: Vector2 = Vector2(0.70, 0.70)
	
	
	func demarrer(
		p_position_depart: Vector2,
		p_duree: float,
		p_montee: float,
		p_derive_x: float,
		p_ondulation_x: float,
		p_vitesse_ondulation: float,
		p_scale_depart: Vector2,
		p_scale_fin: Vector2
	):
		position_depart = p_position_depart
		duree = p_duree
		montee = p_montee
		derive_x = p_derive_x
		ondulation_x = p_ondulation_x
		vitesse_ondulation = p_vitesse_ondulation
		scale_depart = p_scale_depart
		scale_fin = p_scale_fin
		
		phase = randf_range(0.0, TAU)
		
		sens = 1.0
		if randf() < 0.5:
			sens = -1.0
		
		position = position_depart
		modulate.a = 0.0
		scale = scale_depart
		set_process(true)
	
	
	func _process(delta):
		temps += delta
		
		var t: float = 0.0
		if duree > 0.0:
			t = clamp(temps / duree, 0.0, 1.0)
		
		# Montée douce, mais assez haute pour qu'on voie l'effet.
		var t_montee: float = 1.0 - pow(1.0 - t, 1.45)
		
		# Ondulation plus visible au début/milieu, mais qui reste naturelle.
		# Elle ne tombe pas à 0 trop vite, sinon on ne la voit pas.
		var force_ondulation: float = lerp(ondulation_x, ondulation_x * 0.35, t)
		var mouvement_fumee_x: float = sin((t * TAU * vitesse_ondulation) + phase) * force_ondulation
		
		# Dérive lente dans un sens, pour éviter l'effet "aller-retour mécanique".
		var mouvement_derive_x: float = sens * derive_x * t
		
		position = position_depart + Vector2(
			mouvement_derive_x + mouvement_fumee_x,
			-montee * t_montee
		)
		
		# Rétrécissement progressif pendant toute la durée.
		scale = scale_depart.lerp(scale_fin, t)
		
		# Apparition courte, puis disparition progressive pendant le rétrécissement.
		# On ne garde pas le texte opaque trop longtemps, mais on ne le tue pas brutalement.
		if t < 0.10:
			modulate.a = lerp(0.0, 1.0, t / 0.10)
		else:
			var fade_t: float = (t - 0.10) / 0.90
			modulate.a = lerp(1.0, 0.0, clamp(fade_t, 0.0, 1.0))
		
		if temps >= duree:
			queue_free()


func _ready():
	preparer_canvas_layer()


func preparer_canvas_layer():
	if canvas_layer:
		return
	
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 200
	add_child(canvas_layer)


# ============================================================
# API SIMPLE À UTILISER DANS LE RESTE DU JEU
# ============================================================

func afficher_degats(valeur, position_monde: Vector2):
	afficher_popup_direct(valeur, position_monde, couleur_degats)


func afficher_soin(valeur, position_monde: Vector2):
	afficher_popup_direct(valeur, position_monde, couleur_soin)


func afficher_xp(valeur, position_monde: Vector2):
	afficher_popup_fumee(
		valeur,
		position_monde,
		couleur_xp,
		taille_texte_tick,
		duree_tick,
		montee_tick,
		derive_tick_x,
		ondulation_tick_x,
		vitesse_ondulation_tick,
		Vector2(1.02, 1.02),
		Vector2(0.68, 0.68)
	)


func afficher_xp_importante(valeur, position_monde: Vector2):
	afficher_popup_fumee(
		valeur,
		position_monde,
		couleur_xp,
		taille_texte_important,
		duree_important,
		montee_important,
		derive_important_x,
		ondulation_important_x,
		vitesse_ondulation_important,
		Vector2(1.35, 1.35),
		Vector2(0.72, 0.72)
	)


func afficher_piece(valeur, position_monde: Vector2):
	afficher_popup_fumee(
		valeur,
		position_monde,
		couleur_piece,
		taille_texte_tick,
		duree_tick,
		montee_tick,
		derive_tick_x,
		ondulation_tick_x,
		vitesse_ondulation_tick,
		Vector2(1.02, 1.02),
		Vector2(0.68, 0.68)
	)


func afficher_piece_importante(valeur, position_monde: Vector2):
	afficher_popup_fumee(
		valeur,
		position_monde,
		couleur_piece,
		taille_texte_important,
		duree_important,
		montee_important,
		derive_important_x,
		ondulation_important_x,
		vitesse_ondulation_important,
		Vector2(1.35, 1.35),
		Vector2(0.72, 0.72)
	)


# ============================================================
# EFFET DIRECT : dégâts / soin
# Gros impact rapide, style MOBA.
# ============================================================

func afficher_popup_direct(valeur, position_monde: Vector2, couleur: Color):
	preparer_canvas_layer()
	
	var label: Label = creer_label(valeur, taille_texte_direct, couleur)
	canvas_layer.add_child(label)
	
	var position_ecran: Vector2 = convertir_position_monde_en_ecran(position_monde)
	
	position_ecran += Vector2(
		randf_range(-dispersion_x_direct, dispersion_x_direct),
		randf_range(-dispersion_y_direct, dispersion_y_direct)
	)
	
	label.position = position_ecran - label.pivot_offset
	label.modulate.a = 0.0
	label.scale = Vector2(0.55, 0.55)
	
	var position_finale: Vector2 = label.position + Vector2(
		randf_range(-12.0, 12.0),
		-montee_direct
	)
	
	var tween: Tween = create_tween()
	
	tween.tween_property(label, "modulate:a", 1.0, 0.05)
	tween.parallel().tween_property(label, "scale", Vector2(grossissement_direct, grossissement_direct), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(label, "position", position_finale, duree_direct).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duree_direct).set_delay(0.18)
	
	tween.tween_callback(label.queue_free)


# ============================================================
# EFFET FUMÉE : XP / pièces
# ============================================================

func afficher_popup_fumee(
	valeur,
	position_monde: Vector2,
	couleur: Color,
	taille: int,
	duree: float,
	montee: float,
	derive_x: float,
	ondulation_x: float,
	vitesse_ondulation: float,
	scale_depart: Vector2,
	scale_fin: Vector2
):
	preparer_canvas_layer()
	
	var label: SmokePopup = SmokePopup.new()
	
	label.text = convertir_valeur_en_texte(valeur)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	label.add_theme_font_size_override("font_size", taille)
	label.add_theme_color_override("font_color", couleur)
	label.add_theme_color_override("font_shadow_color", couleur_ombre)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	label.size = Vector2(120.0, 50.0)
	label.pivot_offset = label.size * 0.5
	
	canvas_layer.add_child(label)
	
	var position_ecran: Vector2 = convertir_position_monde_en_ecran(position_monde)
	
	position_ecran += Vector2(
		randf_range(-dispersion_x_tick, dispersion_x_tick),
		randf_range(-dispersion_y_tick, dispersion_y_tick)
	)
	
	var position_depart: Vector2 = position_ecran - label.pivot_offset
	
	label.demarrer(
		position_depart,
		duree,
		montee,
		derive_x,
		ondulation_x,
		vitesse_ondulation,
		scale_depart,
		scale_fin
	)


# ============================================================
# OUTILS INTERNES
# ============================================================

func creer_label(valeur, taille: int, couleur: Color) -> Label:
	var label: Label = Label.new()
	
	label.text = convertir_valeur_en_texte(valeur)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	label.add_theme_font_size_override("font_size", taille)
	label.add_theme_color_override("font_color", couleur)
	label.add_theme_color_override("font_shadow_color", couleur_ombre)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	label.size = Vector2(120.0, 50.0)
	label.pivot_offset = label.size * 0.5
	
	return label


func convertir_valeur_en_texte(valeur) -> String:
	var nombre: float = float(valeur)
	nombre = abs(nombre)
	
	if nombre < 0.05:
		return "0"
	
	if is_equal_approx(nombre, round(nombre)):
		return str(int(round(nombre)))
	
	return str(snapped(nombre, 0.1))


func convertir_position_monde_en_ecran(position_monde: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	
	if not viewport:
		return position_monde
	
	var transform_canvas: Transform2D = viewport.get_canvas_transform()
	return transform_canvas * position_monde


# ============================================================
# FUTUR, PAS UTILISÉ POUR L’INSTANT
# ============================================================
# Quand tu auras de vrais effets passifs :
#
# - poison
# - brûlure
# - réparation passive
# - régénération lente
#
# Tu pourras simplement réutiliser afficher_xp / afficher_piece
# ou ajouter afficher_tick_degats / afficher_tick_soin plus tard.
