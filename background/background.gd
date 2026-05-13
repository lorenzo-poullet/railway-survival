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
@onready var sfx_xp = $SFX_XP
@onready var sfx_xp2 = $SFX_XP2

# --- RÉFÉRENCES VIE ET XP ---
@onready var barre_verte = $SocleVie/vie_train
@onready var barre_rouge = $SocleVie/vie_perdu_train

@onready var xp_barre = $SocleVie/xp # TextureProgressBar
@onready var label_nv = $SocleVie/xp/label_nv # Enfant de la barre XP
@onready var overlay_lock = $Regulateur/OverlayLock

# --- VARIABLES DE JEU ---
var pv_max : float = 100.0
var pv_actuels : float = 100.0

var niveau_actuel : int = 1
var xp_actuelle : float = 0.0
var xp_requise : float = 100.0 
@export var gain_xp_vitesse : float = 8.0 # Vitesse du "tapis roulant" XP
@export var xp_par_moustique : float = 20.0

var score_pieces : int = 0
var accumulation_distance : float = 0.0
@export var distance_pour_une_piece : float = 1000.0 

var etat = "idle"

func _ready():
	vitesse_reelle = vitesse
	if piece: piece.play("run")
	
	# Initialisation Vie
	if barre_verte and barre_rouge:
		barre_verte.max_value = pv_max
		barre_rouge.max_value = pv_max
		barre_verte.value = pv_actuels
		barre_rouge.value = pv_actuels
	
	# Initialisation XP (Step à 0 pour la fluidité totale)
	if xp_barre:
		xp_barre.step = 0.0 
		xp_barre.max_value = xp_requise
		xp_barre.value = xp_actuelle
	
	mettre_a_jour_ui_niveau()

func _process(delta):
	# --- INTERPOLATION VITESSE ---
	if vitesse_reelle < vitesse:
		vitesse_reelle += acceleration * delta
		if vitesse_reelle >= vitesse: vitesse_reelle = vitesse
	elif vitesse_reelle > vitesse:
		vitesse_reelle -= acceleration * delta
		if vitesse_reelle <= vitesse: vitesse_reelle = vitesse
	
	# --- MOUVEMENT DÉCOR ---
	b1.position.x -= vitesse_reelle * delta
	b2.position.x -= vitesse_reelle * delta
	if b1.position.x <= 578 - ecart_parfait: b1.position.x += ecart_parfait * 2
	if b2.position.x <= 1722 - (ecart_parfait * 2): b2.position.x += ecart_parfait * 2

	# --- LOGIQUE XP ET PIÈCES ---
	gerer_audio()
	
	if vitesse_reelle > 0.1:
		# Gain XP Passif (Effet tapis roulant fluide avec delta)
		ajouter_xp((vitesse_reelle / 400.0) * gain_xp_vitesse * delta)
		
		accumulation_distance += vitesse_reelle * delta
		if accumulation_distance >= distance_pour_une_piece:
			gagner_piece()
			accumulation_distance = 0.0
			
		if not sprite_train.is_playing(): sprite_train.play()
		if not piece.is_playing(): piece.play("run")
		sprite_train.speed_scale = vitesse_reelle / 400.0
		piece.speed_scale = vitesse_reelle / 400.0
	else:
		if sprite_train.is_playing(): sprite_train.stop()
		if piece.is_playing(): piece.stop()

# --- SYSTÈME DE NIVEAU ---

func ajouter_xp(montant):
	xp_actuelle += montant
	if xp_actuelle >= xp_requise:
		monter_niveau()
	if xp_barre:
		xp_barre.value = xp_actuelle

func monter_niveau():
	if sfx_xp: sfx_xp.play()
	if sfx_xp2: sfx_xp2.play()
	niveau_actuel += 1
	xp_actuelle = max(0, xp_actuelle - xp_requise) # On garde le surplus
	xp_requise = xp_requise * 1.2
	mettre_a_jour_ui_niveau()

func mettre_a_jour_ui_niveau():
	if label_nv: label_nv.text = "Niv. " + str(niveau_actuel)
	if xp_barre:
		xp_barre.max_value = xp_requise
		xp_barre.value = xp_actuelle
	# Affichage/Masquage de l'overlay noir
	if overlay_lock:
		overlay_lock.visible = (niveau_actuel < 5)

func moustique_tue():
	ajouter_xp(xp_par_moustique)

# --- COMMANDES (BLOCAGE NIVEAU 5) ---

# Appelle ces fonctions depuis tes sprites Vitesse/Frein
func ajuster_vitesse(nouvelle_vitesse):
	if niveau_actuel >= 5:
		vitesse = nouvelle_vitesse
	else:
		print("Commande verrouillée : Niveau 5 requis")

# --- AUTRES FONCTIONS ---

func gagner_piece():
	score_pieces += 1
	if sfx_piece: sfx_piece.play()
	if label_piece != null:
		label_piece.text = str(score_pieces)
		var tw = create_tween()
		tw.tween_property(label_piece, "scale", Vector2(1.5, 1.5), 0.05)
		tw.tween_property(label_piece, "scale", Vector2(1.0, 1.0), 0.05)

# --- AJOUTER CETTE VARIABLE EN HAUT ---
var est_mort : bool = false

# --- MODIFICATION DE SUBIR_DEGATS ---
func subir_degats(montant):
	if est_mort: return # Empêche de mourir plusieurs fois pendant le freinage
	
	pv_actuels -= montant
	pv_actuels = clamp(pv_actuels, 0, pv_max)
	
	# Animation des barres de vie
	var tv = create_tween()
	tv.tween_property(barre_verte, "value", pv_actuels, 0.2)
	var tr = create_tween()
	tr.tween_interval(0.5) 
	tr.tween_property(barre_rouge, "value", pv_actuels, 0.4).set_trans(Tween.TRANS_SINE)
	
	if pv_actuels <= 0:
		sequence_mort_fluide()

# --- LA NOUVELLE SÉQUENCE DE RESET ---
func sequence_mort_fluide():
	est_mort = true
	print("Début du freinage d'urgence...")
	
	# 1. On force le freinage brutal via la vitesse cible
	vitesse = 0.0
	acceleration = 800.0 # On augmente l'accélération pour que le freinage soit sec
	
	# 2. On attend 2 secondes (pendant que le train finit de s'arrêter et que les sons jouent)
	# On utilise un Timer via le code pour ne pas bloquer le jeu
	await get_tree().create_timer(3.0).timeout
	
	# 3. On recharge carrément le niveau (Reset complet)
	get_tree().reload_current_scene()

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
			if vitesse_reelle > 0: sfx_mouvement.pitch_scale = vitesse_reelle / 400.0
			if vitesse <= 0:
				etat = "transition_arret"
				sfx_mouvement.stop()
				sfx_transition.play()
		"transition_arret":
			if vitesse_reelle <= 0: etat = "idle"
				
func _input(event):
	if event is InputEventKey and event.pressed:
		# 1. ESPACE -> SEULEMENT LES DÉGÂTS
		if event.keycode == KEY_SPACE:
			subir_degats(15)
			
		# 2. ENTRÉE -> SEULEMENT LE NIVEAU
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			monter_niveau()
			
