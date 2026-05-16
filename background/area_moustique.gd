extends Area2D

@onready var background = get_node_or_null("../background")
@onready var area_train = get_node_or_null("../train/AreaTrain")

@onready var sfx_vol = background.get_node_or_null("SFX_MOUSTIQUE") if background else null
@onready var sfx_attaque = background.get_node_or_null("SFX_MOUSTIQUE_ATTAQUE") if background and background.has_node("SFX_MOUSTIQUE_ATTAQUE") else (background.get_node_or_null("SFX_MOUSTIQUE_ATTA") if background else null)
@onready var sfx_mort = background.get_node_or_null("SFX_MOUSTIQUE_DIE") if background else null

# Paramètres de base (Valeurs par défaut)
var train_x = 611.0
var zone_h_min = 227.0
var zone_h_max = 335.0
var largeur_securite = 180.0 

var vitesse_approche_base = 280.0
var vitesse_pique_base = 750.0 
var vitesse_zigzag_base = 3.5
var amplitude_x = 60.0 

# Variables de contrôle
var temps = 0.0
var temps_cote = 0.0
var phase_approche = true
var cote_actuel = 1 
var spawn_gauche = -269.0
var spawn_droite = 2414.0

var temps_depuis_attaque = 0.0
var point_attaque_cible = Vector2.ZERO
var a_rate_cible = false 

var est_mort = false
var a_inflige_degat = false  
var distance_max_soudure = 1500.0 

func _ready():
	temps = randf() * 10.0
	input_event.connect(_on_input_event)
	area_entered.connect(_on_area_entered)
	$moustique.animation_finished.connect(_on_animation_finished)
	reinitialiser_position()

func reinitialiser_position():
	cote_actuel = 1 if randf() > 0.5 else -1
	position.x = spawn_droite if cote_actuel == 1 else spawn_gauche
	position.y = randf_range(zone_h_min, zone_h_max)
	
	phase_approche = true
	temps_cote = 0.0
	temps_depuis_attaque = randf_range(0.0, 2.0) 
	est_mort = false
	a_inflige_degat = false
	a_rate_cible = false
	rotation = 0
	modulate.a = 1.0
	
	configurer_visuel_vol()
	
	if sfx_vol:
		sfx_vol.play()
	$moustique.play("default")

func _process(delta):
	if est_mort: return

	# --- MISE À ÉCHELLE DE LA VITESSE DU MOUSTIQUE ---
	# Plus le train va vite, plus le moustique est nerveux !
	var modificateur_vitesse = 1.0
	if background:
		modificateur_vitesse = max(0.6, background.vitesse_reelle / 400.0)

	var v_approche = vitesse_approche_base * modificateur_vitesse
	var v_pique = vitesse_pique_base * modificateur_vitesse
	var v_zigzag = vitesse_zigzag_base * modificateur_vitesse

	temps += delta * modificateur_vitesse
	temps_cote += delta

	if area_train:
		train_x = area_train.global_position.x

	if sfx_vol and sfx_vol.playing:
		var distance_au_train = abs(position.x - train_x)
		var intensite = 1.0 - clamp(distance_au_train / distance_max_soudure, 0.0, 1.0)
		sfx_vol.volume_db = linear_to_db(intensite)

	# --- COMPORTEMENT SI EN ATTAQUE ---
	if $moustique.animation == "attaque":
		$moustique.flip_h = position.x >= train_x 
		
		if not a_inflige_degat and not a_rate_cible:
			if $moustique.frame >= 2:
				$moustique.pause()
				$moustique.frame = 2
		
		if not a_inflige_degat and not a_rate_cible:
			global_position = global_position.move_toward(point_attaque_cible, v_pique * delta)
			
			if global_position.distance_to(point_attaque_cible) < 15.0:
				a_rate_cible = true
				$moustique.play() 
		return 

	# --- COMPORTEMENT DE VOL NORMAL ---
	$moustique.flip_h = position.x < train_x

	if phase_approche:
		var destination_x = train_x + (largeur_securite * cote_actuel)
		var direction = 1 if position.x < destination_x else -1
		position.x += direction * v_approche * delta
		
		var milieu_y = (zone_h_min + zone_h_max) / 2
		position.y = lerp(position.y, milieu_y + sin(temps * 2) * 20, delta * 2)
		
		if abs(position.x - destination_x) < 15.0:
			phase_approche = false
			temps_depuis_attaque = 5.0 
	else:
		var pivot_x = train_x + (largeur_securite * cote_actuel)
		var zigzag_x = pivot_x + sin(temps * v_zigzag) * amplitude_x
		var milieu_y = (zone_h_min + zone_h_max) / 2
		var range_y = (zone_h_max - zone_h_min) / 2
		var zigzag_y = milieu_y + cos(temps * v_zigzag * 0.7) * range_y
		
		position.x = lerp(position.x, zigzag_x, delta * 3.0)
		position.y = lerp(position.y, zigzag_y, delta * 3.0)

		temps_depuis_attaque += delta
		if temps_depuis_attaque >= 7.0:
			lancer_attaque()

		if temps_cote >= 10.0:
			cote_actuel *= -1
			temps_cote = 0.0
			phase_approche = true 

func configurer_visuel_vol():
	$moustique.scale = Vector2(0.2, 0.2)

func configurer_visuel_attaque():
	$moustique.scale = Vector2(0.6, 0.6)

func lancer_attaque():
	if est_mort or $moustique.animation == "attaque": return
	
	a_inflige_degat = false 
	a_rate_cible = false
	temps_depuis_attaque = 0.0 
	
	if area_train:
		var centre_train_x = area_train.global_position.x
		var décalage_bord_x = 0.0
		
		var shape_owner = area_train.get_child(0)
		if shape_owner and shape_owner is CollisionShape2D and shape_owner.shape is RectangleShape2D:
			décalage_bord_x = (shape_owner.shape.size.x / 2.0) * shape_owner.global_scale.x
		else:
			décalage_bord_x = 75.0 
			
		var cible_x = 0.0
		if global_position.x > centre_train_x:
			cible_x = centre_train_x + décalage_bord_x
		else:
			cible_x = centre_train_x - décalage_bord_x
			
		var dispersion_y = randf_range(-65.0, 65.0) 
		point_attaque_cible = Vector2(cible_x, area_train.global_position.y + dispersion_y)
	else:
		point_attaque_cible = Vector2(train_x, randf_range(zone_h_min, zone_h_max))
	
	configurer_visuel_attaque()
	$moustique.play("attaque")
	if sfx_attaque: sfx_attaque.play()

func _on_animation_finished():
	if $moustique.animation == "attaque" and not est_mort:
		configurer_visuel_vol()
		$moustique.play("default")

func _on_area_entered(area):
	if est_mort: return
	if area.name == "AreaTrain" and $moustique.animation == "attaque" and not a_inflige_degat:
		a_inflige_degat = true
		global_position.x = point_attaque_cible.x
		$moustique.play() 
		infliger_degat_train()

func infliger_degat_train():
	if background and background.has_method("subir_degats"):
		background.subir_degats(10) 

# --- GESTION DU CLIC / TIR DU CANON (SÉCURISÉ ANTI MULTI-KILL) ---
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Consomme l'input pour empêcher les autres moustiques en dessous de le capter !
		get_viewport().set_input_as_handled()
		mourir()

func mourir():
	if est_mort: return
	est_mort = true
	$moustique.stop()
	configurer_visuel_vol()

	if sfx_vol: sfx_vol.stop()
	if sfx_mort: sfx_mort.play()

	if background:
		# On donne l'XP au joueur via ta fonction
		background.moustique_tue()
		
		# Au lieu de modifier la variable à la main, on appelle ta fonction 
		# qui gère le bruitage et l'animation de scale du texte !
		if background.has_method("gagner_piece"):
			# On l'appelle plusieurs fois si tu veux donner plus de pièces par moustique (ex: 5 fois)
			for i in range(5):
				background.gagner_piece()
	
	var tween = create_tween()
	var sens_choc = -1 if position.x < train_x else 1
	var force_recul = 80.0
	var hauteur_bond = 60.0
	var rotation_finale = PI * -sens_choc 

	tween.tween_property(self, "position", 
		Vector2(position.x + (force_recul * sens_choc), position.y - hauteur_bond), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation", rotation_finale, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "position:y", position.y + 400, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	
	tween.tween_callback(fin_mort)

func fin_mort():
	reinitialiser_position()
