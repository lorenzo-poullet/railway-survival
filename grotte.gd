# grotte.gd
extends Node2D

@export var vitesse: float = 400.0
var vitesse_reelle: float = 0.0
@export var acceleration: float = 200.0

var ecart_parfait: float = 1144.0
var centre_x: float = 578.0

# Plus petit = retour surface plus tard.
# Si c'est encore trop tôt, mets -420.
@export var position_sortie_g1: float = -140.0

# --- DÉCOR ---
@onready var g1: Node2D = $g1
@onready var g2: Node2D = $g2
@onready var g2_bis: Node2D = $g2_bis

# --- TRAIN ---
@onready var sprite_train = get_node_or_null("train")

# --- DEBUG ---
@onready var label_debug = get_node_or_null("LabelDebugDev")

# --- SFX ---
@onready var sfx_transition = get_node_or_null("SFX_Transition")
@onready var sfx_mouvement = get_node_or_null("SFX_Mouvement")

# --- ÉTAT ---
var chrono_grotte: float = 25.0
var transition_sortie_active: bool = false
var sortie_injectee: bool = false
var retour_lance: bool = false

var fondu_entree_en_cours: bool = true
var rideau_transition: ColorRect
var etat_audio: String = "running"

# On sauvegarde les scales exacts de l'inspecteur.
var g1_scale_depart: Vector2
var g2_scale_depart: Vector2
var g2_bis_scale_depart: Vector2

var debug_label_visible : bool = true

func basculer_label_debug():
	debug_label_visible = not debug_label_visible
	
	if label_debug:
		label_debug.visible = debug_label_visible
		
func _ready():
	if label_debug:
		label_debug.add_theme_font_size_override("font_size", 10)
		label_debug.visible = true
		label_debug.z_index = 999

	# Sauvegarde des réglages VISUELS exacts de l'inspecteur.
	g1_scale_depart = g1.scale
	g2_scale_depart = g2.scale
	g2_bis_scale_depart = g2_bis.scale

	# Le train roule déjà.
	vitesse_reelle = vitesse

	# IMPORTANT :
	# On ne force PAS les positions.
	# On ne force PAS les scales de g2/g2_bis.
	# On respecte l'inspecteur.

	# g1 commence en version entrée normale avec son scale exact d'origine.
	g1.scale = Vector2(abs(g1_scale_depart.x), g1_scale_depart.y)
	g1.visible = true

	g2.scale = g2_scale_depart
	g2_bis.scale = g2_bis_scale_depart
	g2.visible = true
	g2_bis.visible = true

	if sprite_train:
		sprite_train.play()
		sprite_train.speed_scale = vitesse_reelle / 400.0

	creer_rideau_transition()

	# SFX_Transition uniquement au début de l'entrée de grotte.
	if sfx_transition:
		sfx_transition.play()

	if sfx_mouvement:
		sfx_mouvement.play()
		sfx_mouvement.pitch_scale = vitesse_reelle / 400.0

	var tw = create_tween()
	tw.tween_property(rideau_transition, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		fondu_entree_en_cours = false
	)

func creer_rideau_transition():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)

	rideau_transition = ColorRect.new()
	rideau_transition.color = Color.BLACK
	rideau_transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rideau_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rideau_transition.modulate.a = 1.0
	canvas_layer.add_child(rideau_transition)

func _process(delta):
	if retour_lance:
		return

	gerer_audio()
	gerer_animation_train()
	actualiser_label_debug()

	# Le décor ne bouge pas pendant le noir.
	# Le train, lui, reste animé.
	if fondu_entree_en_cours:
		return

	gerer_vitesse(delta)
	gerer_chrono(delta)
	gerer_mouvement_decors(delta)
	gerer_boucle_grotte()

func gerer_vitesse(delta):
	if vitesse_reelle < vitesse:
		vitesse_reelle += acceleration * delta
		if vitesse_reelle >= vitesse:
			vitesse_reelle = vitesse
	elif vitesse_reelle > vitesse:
		vitesse_reelle -= acceleration * delta
		if vitesse_reelle <= vitesse:
			vitesse_reelle = vitesse

func gerer_chrono(delta):
	if chrono_grotte > 0.0:
		chrono_grotte -= delta
		if chrono_grotte <= 0.0:
			chrono_grotte = 0.0
			transition_sortie_active = true

func gerer_mouvement_decors(delta):
	if g1.visible:
		g1.position.x -= vitesse_reelle * delta

	g2.position.x -= vitesse_reelle * delta
	g2_bis.position.x -= vitesse_reelle * delta

func gerer_boucle_grotte():
	var limite_gauche: float = centre_x - ecart_parfait

	# L'entrée normale sort définitivement.
	if g1.visible and not sortie_injectee:
		if g1.position.x <= limite_gauche:
			g1.visible = false

	# Boucle stricte comme b1 / b2.
	if not sortie_injectee:
		if g2.position.x <= limite_gauche:
			g2.position.x += ecart_parfait * 2.0

			if transition_sortie_active:
				injecter_sortie_g1(g2.position.x + ecart_parfait)
				return

		if g2_bis.position.x <= limite_gauche:
			g2_bis.position.x += ecart_parfait * 2.0

			if transition_sortie_active:
				injecter_sortie_g1(g2_bis.position.x + ecart_parfait)
				return

	# Sortie g1 flip H.
	if sortie_injectee and g1.visible:
		if g1.position.x <= position_sortie_g1:
			g1.position.x = position_sortie_g1
			lancer_retour_surface()

func injecter_sortie_g1(pos_x: float):
	sortie_injectee = true

	g1.visible = true

	# Flip H propre :
	# on inverse seulement le signe du scale X,
	# mais on garde la taille exacte de l'inspecteur.
	g1.scale = Vector2(-abs(g1_scale_depart.x), g1_scale_depart.y)

	g1.position.x = pos_x

	# Pas de SFX_Transition ici.
	# Pas de stop de SFX_Mouvement ici.
	etat_audio = "running"

func gerer_animation_train():
	if not sprite_train:
		return

	if vitesse_reelle > 0.1:
		if not sprite_train.is_playing():
			sprite_train.play()
		sprite_train.speed_scale = vitesse_reelle / 400.0
	else:
		sprite_train.speed_scale = 0.0

func gerer_audio():
	if sfx_mouvement and vitesse_reelle > 0.1:
		if not sfx_mouvement.playing:
			sfx_mouvement.play()
		sfx_mouvement.pitch_scale = vitesse_reelle / 400.0

func lancer_retour_surface():
	if retour_lance:
		return

	retour_lance = true
	set_process(false)

	if sfx_mouvement:
		sfx_mouvement.stop()

	var tween = create_tween()
	tween.tween_property(rideau_transition, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func():
		Global.retour_de_grotte = true
		get_tree().change_scene_to_file("res://background/railway_survival.tscn")
	)

func actualiser_label_debug():
	if not label_debug:
		return
	
	label_debug.visible = debug_label_visible
	
	if not debug_label_visible:
		return
	
	label_debug.text = "debug fonctionnement visuel temporaire\n"
	label_debug.text += "-----------------------------------------\n"
	label_debug.text += "ZONE : GROTTE / CHARGEMENT\n"
	label_debug.text += "Temps : " + str(snapped(chrono_grotte, 0.1)) + " s\n"
	label_debug.text += "Fondu entrée : " + str(fondu_entree_en_cours) + "\n"
	label_debug.text += "Sortie active : " + str(transition_sortie_active) + "\n"
	label_debug.text += "Sortie injectée : " + str(sortie_injectee) + "\n"
	label_debug.text += "Audio : " + etat_audio + "\n"
	label_debug.text += "Vitesse : " + str(snapped(vitesse_reelle, 1.0)) + "\n"
	label_debug.text += "g1 x : " + str(snapped(g1.position.x, 1.0)) + "\n"
	label_debug.text += "g2 x : " + str(snapped(g2.position.x, 1.0)) + "\n"
	label_debug.text += "g2_bis x : " + str(snapped(g2_bis.position.x, 1.0)) + "\n"
	
	label_debug.text += "\n"
	label_debug.text += "COMMANDES DEBUG\n"
	label_debug.text += "F1 : afficher / cacher ce label\n"
	label_debug.text += "Entrée : niveau +1 uniquement en surface\n"
	label_debug.text += "Espace : dégâts train uniquement en surface\n"
	label_debug.text += "F2 : reset cooldown régulateur uniquement en surface\n"
		
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			basculer_label_debug()
