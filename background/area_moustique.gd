extends Area2D

@onready var background = get_node("../background")

# 1. Paramètres de position et zones
var train_x = 611.0
var zone_h_min = 227.0
var zone_h_max = 335.0
var largeur_securite = 180.0 

# 2. Paramètres de vol
var vitesse_approche = 280.0
var vitesse_zigzag = 3.5
var amplitude_x = 60.0 

# 3. Variables de contrôle
var temps = 0.0
var temps_cote = 0.0
var phase_approche = true
var cote_actuel = 1 
var spawn_gauche = -269.0
var spawn_droite = 2414.0

# Variable pour la fluidité
var cible_fluide = Vector2.ZERO

func _ready():
	temps = randf() * 10.0
	input_event.connect(_on_input_event)
	reinitialiser_position()

func reinitialiser_position():
	cote_actuel = 1 if randf() > 0.5 else -1
	position.x = spawn_droite if cote_actuel == 1 else spawn_gauche
	position.y = randf_range(zone_h_min, zone_h_max)
	
	phase_approche = true
	temps_cote = 0.0
	cible_fluide = position # Initialise la cible sur la position de départ

func _process(delta):
	temps += delta
	temps_cote += delta
	
	$moustique.flip_h = position.x < train_x

	if phase_approche:
		# L'approche reste directe pour arriver vite
		var destination_x = train_x + (largeur_securite * cote_actuel)
		var direction = 1 if position.x < destination_x else -1
		position.x += direction * vitesse_approche * delta
		
		# On lisse aussi la hauteur pendant l'approche
		var milieu_y = (zone_h_min + zone_h_max) / 2
		position.y = lerp(position.y, milieu_y + sin(temps * 2) * 20, delta * 2)
		
		if abs(position.x - destination_x) < 15.0:
			phase_approche = false
	else:
		# LOGIQUE DE HARCÈLEMENT AVEC TRANSITION FLUIDE
		var pivot_x = train_x + (largeur_securite * cote_actuel)
		
		# On calcule la position théorique du zigzag
		var zigzag_x = pivot_x + sin(temps * vitesse_zigzag) * amplitude_x
		var milieu_y = (zone_h_min + zone_h_max) / 2
		var range_y = (zone_h_max - zone_h_min) / 2
		var zigzag_y = milieu_y + cos(temps * vitesse_zigzag * 0.7) * range_y
		
		# AU LIEU DE "position = ...", ON UTILISE LERP
		# delta * 3.0 permet de rejoindre la trajectoire de façon organique
		position.x = lerp(position.x, zigzag_x, delta * 3.0)
		position.y = lerp(position.y, zigzag_y, delta * 3.0)

		# CHANGEMENT DE CÔTÉ
		if temps_cote >= 10.0:
			cote_actuel *= -1
			temps_cote = 0.0
			phase_approche = true 

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mourir()

# On ajoute une variable en haut du script pour savoir s'il est mort
var est_mort = false

func mourir():
	if est_mort: return
	
	est_mort = true
	$moustique.stop()

	# --- AJOUT DU SCORE (5 PIÈCES D'UN COUP) ---
	if background:
		background.score_pieces += 5 # Ajoute 5 au score
		if background.label_piece:
			background.label_piece.text = str(background.score_pieces) # Met à jour le texte
			# Petit effet de scale sur le label (optionnel, repris de ton background.gd)
			var tw = create_tween()
			tw.tween_property(background.label_piece, "scale", Vector2(1.5, 1.5), 0.1)
			tw.tween_property(background.label_piece, "scale", Vector2(1.0, 1.0), 0.1)
		if background.sfx_piece:
			background.sfx_piece.play() # Joue le son une seule fois
	# ------------------------------------------
	
	var tween = create_tween()
	
	# 1. CALCUL DE LA DIRECTION DU CHOC (Recul en arrière)
	var sens_choc = -1 if position.x < train_x else 1
	var force_recul = 80.0
	var hauteur_bond = 60.0
	
	# 2. CALCUL DE LA ROTATION (Toujours vers l'arrière)
	var rotation_finale = PI * -sens_choc 

	# 3. L'ANIMATION D'IMPACT (Bond en diagonale arrière + Rotation)
	tween.tween_property(self, "position", 
		Vector2(position.x + (force_recul * sens_choc), position.y - hauteur_bond), 
		0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(self, "rotation", rotation_finale, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 4. LA CHUTE FINALE
	tween.tween_property(self, "position:y", position.y + 400, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	
	tween.tween_callback(fin_mort)

func fin_mort():
	# Reset complet pour le prochain moustique
	rotation = 0
	modulate.a = 1.0
	reinitialiser_position()
	est_mort = false
	$moustique.play()
