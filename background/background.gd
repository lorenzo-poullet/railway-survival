extends Node2D

@export var vitesse: float = 400.0        
var vitesse_reelle: float = 0.0           
@export var acceleration: float = 200.0   
var ecart_parfait: float = 1144.0

# --- RÉFÉRENCES ---
@onready var b1 = $b1
@onready var b2 = $b2
@onready var sprite_train = get_node("../train")
@onready var piece = get_node("../piece")

@onready var sfx_transition = $SFX_Transition
@onready var sfx_mouvement = $SFX_Mouvement
@onready var sfx_piece = $SFX_Piece 
@onready var label_piece = $Regulateur/niveau_piece

# Logique des pièces
var score_pieces : int = 0
var accumulation_distance : float = 0.0
@export var distance_pour_une_piece : float = 1000.0 

var etat = "idle"

func _ready():
	vitesse_reelle = vitesse
	# On active le Loop pour que la rotation soit fluide
	if piece:
		piece.play("run")

func _process(delta):
	# --- INTERPOLATION DE LA VITESSE ---
	if vitesse_reelle < vitesse:
		vitesse_reelle += acceleration * delta
		if vitesse_reelle >= vitesse:
			vitesse_reelle = vitesse
	elif vitesse_reelle > vitesse:
		vitesse_reelle -= acceleration * delta
		if vitesse_reelle <= vitesse:
			vitesse_reelle = vitesse
	
	# --- MOUVEMENT DU DÉCOR ---
	b1.position.x -= vitesse_reelle * delta
	b2.position.x -= vitesse_reelle * delta
	
	if b1.position.x <= 578 - ecart_parfait:
		b1.position.x += ecart_parfait * 2
	if b2.position.x <= 1722 - (ecart_parfait * 2):
		b2.position.x += ecart_parfait * 2

	# --- AUDIO ET LOGIQUE ---
	gerer_audio()
	
	if vitesse_reelle > 0.1:
		# 1. Gestion du score (Distance parcourue)
		accumulation_distance += vitesse_reelle * delta
		if accumulation_distance >= distance_pour_une_piece:
			gagner_piece()
			accumulation_distance = 0.0
			
		# 2. Gestion des animations (Train et Pièce)
		if not sprite_train.is_playing(): sprite_train.play()
		if not piece.is_playing(): piece.play("run")
		
		# Les deux suivent la vitesse réelle du train
		sprite_train.speed_scale = vitesse_reelle / 400.0
		piece.speed_scale = vitesse_reelle / 400.0
	else:
		# Arrêt fluide quand le train ne bouge plus
		if sprite_train.is_playing(): sprite_train.stop()
		if piece.is_playing(): piece.stop()

func gagner_piece():
	score_pieces += 1
	
	# Mise à jour du texte
	if label_piece != null:
		label_piece.text = str(score_pieces)
		
		# Effet de punch (grossissement du chiffre)
		var tween = create_tween()
		tween.tween_property(label_piece, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(label_piece, "scale", Vector2(1.0, 1.0), 0.1)
		
	# Son du gain
	if sfx_piece:
		sfx_piece.play()

func gerer_audio():
	match etat:
		"idle":
			if vitesse > 0:
				etat = "transition_demarrage"
				sfx_transition.play()
		"transition_demarrage":
			if vitesse_reelle >= vitesse:
				etat = "running"
				sfx_mouvement.play()
		"running":
			if vitesse_reelle > 0:
				sfx_mouvement.pitch_scale = vitesse_reelle / 400.0
			if vitesse <= 0:
				etat = "transition_arret"
				sfx_mouvement.stop()
				sfx_transition.play()
		"transition_arret":
			if vitesse_reelle <= 0:
				etat = "idle"
