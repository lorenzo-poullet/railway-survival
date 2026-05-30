# area_moustique.gd
extends Area2D

@export var est_modele_spawn: bool = true

@onready var background = get_node_or_null("../background")
@onready var area_train = get_node_or_null("../train/AreaTrain")

# Ces deux sons dans background servent maintenant de MODÈLES.
# Chaque moustique clone va les dupliquer pour avoir ses propres sons.
@onready var sfx_vol_modele = background.get_node_or_null("SFX_MOUSTIQUE") if background else null
@onready var sfx_attaque_modele = background.get_node_or_null("SFX_MOUSTIQUE_ATTAQUE") if background and background.has_node("SFX_MOUSTIQUE_ATTAQUE") else (background.get_node_or_null("SFX_MOUSTIQUE_ATTA") if background else null)

var sfx_vol: AudioStreamPlayer2D = null
var sfx_attaque: AudioStreamPlayer2D = null

@onready var sfx_mort = background.get_node_or_null("SFX_DIE") if background else null

# --- SYSTÈME DE VIE ---
@onready var barre_verte = $vie_moustique
@onready var barre_rouge = $vie_perdu_moustique

@export var pv_max: float = 2.0
@export var degats_tir_temporaire: float = 1.0

# Réglage effet Street Fighter
@export var delai_barre_rouge: float = 0.20
@export var duree_coulissement_barre_rouge: float = 0.20

var pv_actuels: float = 2.0
var barres_visibles = false
var tween_barre_rouge: Tween = null

# --- PARAMÈTRES DE POSITION ---
var train_x = 611.0
var zone_h_min = 227.0
var zone_h_max = 335.0
var largeur_securite = 180.0 

var spawn_gauche = -269.0
var spawn_droite = 2414.0

# --- MOUVEMENT NORMAL ---
var vitesse_approche_base = 280.0
var vitesse_pique_base = 750.0 
var vitesse_zigzag_base = 3.5
var amplitude_x = 60.0 

# --- DÉPASSEMENT PROGRESSIF À x2 ---
# Important :
# Le spawn du moustique est coupé dans background.gd quand la vitesse cible est x2.
# Ici on gère seulement les moustiques déjà présents à l'écran.
#
# À x1.5 : ils restent normaux.
# Quand le joueur demande x2 : ils commencent à perdre du terrain pendant que vitesse_reelle monte.
# À x2 complet : ils sont dépassés et disparaissent.
@export var vitesse_debut_depassement: float = 800.0
@export var vitesse_fin_depassement: float = 1200.0
@export var force_glissement_depassement: float = 0.85

# --- SORTIE À L'ARRÊT ---
var temps_train_arrete = 0.0
@export var delai_disparition_arret: float = 8.0
@export var vitesse_sortie_arret: float = 260.0

# --- VARIABLES DE CONTRÔLE ---
var temps = 0.0
var temps_cote = 0.0
var phase_approche = true
var cote_actuel = 1 

var temps_depuis_attaque = 0.0
var point_attaque_cible = Vector2.ZERO
var a_rate_cible = false 

var est_mort = false
var est_depasse = false
var est_sortie_arret = false
var a_inflige_degat = false  
var distance_max_soudure = 1500.0 


func _ready():
	if est_modele_spawn:
		initialiser_barres_vie()
		desactiver_modele_spawn()
		return
	
	preparer_sfx_locaux()
	
	temps = randf() * 10.0
	
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	
	if $moustique and not $moustique.animation_finished.is_connected(_on_animation_finished):
		$moustique.animation_finished.connect(_on_animation_finished)
	
	initialiser_barres_vie()
	reinitialiser_position()


func preparer_sfx_locaux():
	if sfx_vol == null:
		sfx_vol = creer_sfx_local(sfx_vol_modele, "SFX_MOUSTIQUE_LOCAL")
	
	if sfx_attaque == null:
		sfx_attaque = creer_sfx_local(sfx_attaque_modele, "SFX_MOUSTIQUE_ATTAQUE_LOCAL")


func creer_sfx_local(modele: Node, nom_local: String) -> AudioStreamPlayer2D:
	if not modele:
		return null
	
	if not (modele is AudioStreamPlayer2D):
		push_warning(nom_local + " impossible : le modèle n'est pas un AudioStreamPlayer2D.")
		return null
	
	var player: AudioStreamPlayer2D = modele.duplicate() as AudioStreamPlayer2D
	player.name = nom_local
	player.autoplay = false
	player.position = Vector2.ZERO
	
	add_child(player)
	player.stop()
	
	return player


func desactiver_modele_spawn():
	visible = false
	position = Vector2(-99999, -99999)
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	monitoring = false
	monitorable = false
	input_pickable = false
	
	if sfx_vol:
		sfx_vol.stop()
	
	if sfx_attaque:
		sfx_attaque.stop()


func initialiser_barres_vie():
	pv_actuels = pv_max
	
	if barre_verte:
		barre_verte.max_value = pv_max
		barre_verte.value = pv_max
		barre_verte.step = 0.0
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.max_value = pv_max
		barre_rouge.value = pv_max
		barre_rouge.step = 0.0
		barre_rouge.visible = false


func reinitialiser_position():
	preparer_sfx_locaux()
	
	cote_actuel = 1 if randf() > 0.5 else -1
	
	position.x = spawn_droite if cote_actuel == 1 else spawn_gauche
	position.y = randf_range(zone_h_min, zone_h_max)
	
	phase_approche = true
	temps_cote = 0.0
	temps_depuis_attaque = randf_range(0.0, 2.0) 
	temps_train_arrete = 0.0
	
	est_mort = false
	est_depasse = false
	est_sortie_arret = false
	
	a_inflige_degat = false
	a_rate_cible = false
	
	rotation = 0
	modulate.a = 1.0
	
	pv_actuels = pv_max
	barres_visibles = false
	
	if tween_barre_rouge:
		tween_barre_rouge.kill()
		tween_barre_rouge = null
	
	if barre_verte:
		barre_verte.max_value = pv_max
		barre_verte.value = pv_max
		barre_verte.step = 0.0
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.max_value = pv_max
		barre_rouge.value = pv_max
		barre_rouge.step = 0.0
		barre_rouge.visible = false
	
	configurer_visuel_vol()
	
	if sfx_vol:
		sfx_vol.stop()
		sfx_vol.play()
	
	$moustique.play("default")


func _process(delta):
	if est_mort:
		return
	
	var facteur_depassement = obtenir_facteur_depassement()
	
	if facteur_depassement >= 1.0 and not est_depasse:
		demarrer_depassement()
	
	if background:
		if background.vitesse <= 0.0 and not est_depasse and not est_sortie_arret:
			temps_train_arrete += delta
			
			if temps_train_arrete >= delai_disparition_arret:
				demarrer_sortie_arret()
		elif background.vitesse > 0.0:
			temps_train_arrete = 0.0
	
	if est_depasse:
		gerer_depassement(delta)
		return
	
	if est_sortie_arret:
		gerer_sortie_arret(delta)
		return

	# Le moustique ne dépend plus de la vitesse du train pour son comportement.
	# Sa nervosité reste stable.
	var v_approche = vitesse_approche_base
	var v_pique = vitesse_pique_base
	var v_zigzag = vitesse_zigzag_base

	temps += delta
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
		
		appliquer_glissement_progressif(delta, facteur_depassement)
		return 

	# --- COMPORTEMENT DE VOL NORMAL ---
	$moustique.flip_h = position.x < train_x

	if phase_approche:
		var destination_x = train_x + (largeur_securite * cote_actuel)
		var direction = 1 if position.x < destination_x else -1
		
		position.x += direction * v_approche * delta
		
		var milieu_y = (zone_h_min + zone_h_max) / 2.0
		position.y = lerp(
			position.y,
			milieu_y + sin(temps * 2.0) * 20.0,
			delta * 2.0
		)
		
		if abs(position.x - destination_x) < 15.0:
			phase_approche = false
			temps_depuis_attaque = 5.0 
	else:
		var pivot_x = train_x + (largeur_securite * cote_actuel)
		var zigzag_x = pivot_x + sin(temps * v_zigzag) * amplitude_x
		var milieu_y = (zone_h_min + zone_h_max) / 2.0
		var range_y = (zone_h_max - zone_h_min) / 2.0
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
	
	appliquer_glissement_progressif(delta, facteur_depassement)


func obtenir_facteur_depassement() -> float:
	if not background:
		return 0.0
	
	# Très important :
	# Le moustique ne doit pas être dépassé à x1.5.
	# Il commence à être dépassé uniquement quand la vitesse demandée est x2.
	if background.vitesse < 1200.0:
		return 0.0
	
	var plage = vitesse_fin_depassement - vitesse_debut_depassement
	if plage <= 0.0:
		return 0.0
	
	var facteur = (background.vitesse_reelle - vitesse_debut_depassement) / plage
	return clamp(facteur, 0.0, 1.0)


func appliquer_glissement_progressif(delta, facteur_depassement):
	if facteur_depassement <= 0.0:
		return
	
	var vitesse_train = 1200.0
	
	if background:
		vitesse_train = background.vitesse_reelle
	
	var glissement = vitesse_train * force_glissement_depassement * facteur_depassement
	
	# Plus le train approche de x2, plus le moustique perd du terrain.
	position.x -= glissement * delta
	
	if facteur_depassement > 0.5:
		modulate.a = move_toward(modulate.a, 0.75, delta * 0.15)
	
	if position.x < spawn_gauche - 250:
		queue_free()


func demarrer_depassement():
	est_depasse = true
	phase_approche = false
	a_rate_cible = true
	a_inflige_degat = false
	
	if sfx_vol:
		sfx_vol.stop()
	
	if sfx_attaque:
		sfx_attaque.stop()
	
	if barre_verte:
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.visible = false
	
	if tween_barre_rouge:
		tween_barre_rouge.kill()
		tween_barre_rouge = null
	
	$moustique.play("default")
	$moustique.scale = Vector2(0.2, 0.2)
	
	var tw = create_tween()
	tw.tween_property($moustique, "rotation", -PI / 4, 0.4)


func gerer_depassement(delta):
	if background:
		position.x -= (background.vitesse_reelle * 0.8) * delta
	else:
		position.x -= 800.0 * delta
	
	modulate.a = move_toward(modulate.a, 0.0, delta * 0.35)
	
	if position.x < spawn_gauche - 250 or modulate.a <= 0.02:
		queue_free()


func demarrer_sortie_arret():
	est_sortie_arret = true
	phase_approche = false
	a_rate_cible = true
	a_inflige_degat = false
	
	if sfx_vol:
		sfx_vol.stop()
	
	if sfx_attaque:
		sfx_attaque.stop()
	
	if barre_verte:
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.visible = false
	
	if tween_barre_rouge:
		tween_barre_rouge.kill()
		tween_barre_rouge = null
	
	$moustique.play("default")
	$moustique.scale = Vector2(0.2, 0.2)


func gerer_sortie_arret(delta):
	var direction_sortie = -1 if position.x < train_x else 1
	
	position.x += direction_sortie * vitesse_sortie_arret * delta
	modulate.a = move_toward(modulate.a, 0.0, delta * 0.35)
	
	if position.x < spawn_gauche - 250 or position.x > spawn_droite + 250 or modulate.a <= 0.02:
		queue_free()


func configurer_visuel_vol():
	$moustique.scale = Vector2(0.2, 0.2)
	$moustique.rotation = 0


func configurer_visuel_attaque():
	$moustique.scale = Vector2(0.6, 0.6)
	$moustique.rotation = 0


func lancer_attaque():
	if est_mort or est_depasse or est_sortie_arret or $moustique.animation == "attaque":
		return
	
	a_inflige_degat = false 
	a_rate_cible = false
	temps_depuis_attaque = 0.0 
	
	if area_train:
		var centre_train_x = area_train.global_position.x
		var decalage_bord_x = 0.0
		
		var shape_owner = area_train.get_child(0)
		
		if shape_owner and shape_owner is CollisionShape2D and shape_owner.shape is RectangleShape2D:
			decalage_bord_x = (shape_owner.shape.size.x / 2.0) * shape_owner.global_scale.x
		else:
			decalage_bord_x = 75.0 
			
		var cible_x = 0.0
		
		if global_position.x > centre_train_x:
			cible_x = centre_train_x + decalage_bord_x
		else:
			cible_x = centre_train_x - decalage_bord_x
			
		var dispersion_y = randf_range(-65.0, 65.0) 
		point_attaque_cible = Vector2(cible_x, area_train.global_position.y + dispersion_y)
	else:
		point_attaque_cible = Vector2(train_x, randf_range(zone_h_min, zone_h_max))
	
	configurer_visuel_attaque()
	$moustique.play("attaque")
	
	if sfx_attaque:
		sfx_attaque.stop()
		sfx_attaque.play()


func _on_animation_finished():
	if $moustique.animation == "attaque" and not est_mort and not est_depasse and not est_sortie_arret:
		configurer_visuel_vol()
		$moustique.play("default")


func _on_area_entered(area):
	if est_mort or est_depasse or est_sortie_arret:
		return
	
	if area.name == "AreaTrain" and $moustique.animation == "attaque" and not a_inflige_degat:
		a_inflige_degat = true
		global_position.x = point_attaque_cible.x
		$moustique.play() 
		infliger_degat_train()


func infliger_degat_train():
	if background and background.has_method("subir_degats"):
		background.subir_degats(10) 


# --- CLIC TEMPORAIRE ---
# Plus tard, le canon appellera directement recevoir_degats(degats_du_canon).
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		simuler_tir_canon_temporaire()


func simuler_tir_canon_temporaire():
	recevoir_degats(degats_tir_temporaire)


func recevoir_degats(degats: float):
	if est_mort or est_depasse or est_sortie_arret:
		return
	
	if degats > 0.0:
		if sfx_mort:
			sfx_mort.stop()
			sfx_mort.play()
		
		Damage.afficher_degats(degats, global_position + Vector2(0.0, -35.0))
	
	pv_actuels -= degats
	pv_actuels = clamp(pv_actuels, 0.0, pv_max)
	
	afficher_barres_si_necessaire()
	mettre_a_jour_barres_vie()
	jouer_feedback_degats()
	
	if pv_actuels <= 0.0:
		mourir()


func afficher_barres_si_necessaire():
	if barres_visibles:
		return
	
	barres_visibles = true
	
	if barre_verte:
		barre_verte.visible = true
	
	if barre_rouge:
		barre_rouge.visible = true


func mettre_a_jour_barres_vie():
	if barre_verte:
		barre_verte.value = pv_actuels
	
	if barre_rouge:
		if tween_barre_rouge:
			tween_barre_rouge.kill()
		
		tween_barre_rouge = create_tween()
		tween_barre_rouge.tween_interval(delai_barre_rouge)
		tween_barre_rouge.tween_property(
			barre_rouge,
			"value",
			pv_actuels,
			duree_coulissement_barre_rouge
		).set_trans(Tween.TRANS_LINEAR)


func jouer_feedback_degats():
	var tw_color = create_tween()
	tw_color.tween_property($moustique, "modulate", Color.RED, 0.05)
	tw_color.tween_property($moustique, "modulate", Color.WHITE, 0.05)


func mourir():
	if est_mort:
		return
	
	est_mort = true
	$moustique.stop()
	configurer_visuel_vol()

	if barre_verte:
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.visible = false

	if tween_barre_rouge:
		tween_barre_rouge.kill()
		tween_barre_rouge = null

	if sfx_vol:
		sfx_vol.stop()
	
	if sfx_attaque:
		sfx_attaque.stop()
	
	if background:
		background.moustique_tue()
		
		if background.has_method("gagner_piece"):
			background.gagner_piece(10)
		else:
			Global.gagner_piece(10)
			
			if background.has_method("mettre_a_jour_ui_pieces"):
				background.mettre_a_jour_ui_pieces(true)
			
			if background.sfx_piece:
				background.sfx_piece.play()
	
	var tween = create_tween()
	var sens_choc = -1 if position.x < train_x else 1
	var force_recul = 80.0
	var hauteur_bond = 60.0
	var rotation_finale = PI * -sens_choc 

	tween.tween_property(
		self,
		"position",
		Vector2(position.x + (force_recul * sens_choc), position.y - hauteur_bond),
		0.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(
		self,
		"rotation",
		rotation_finale,
		0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(
		self,
		"position:y",
		position.y + 400,
		0.8
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(fin_mort)


func fin_mort():
	queue_free()
