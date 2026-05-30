# area_frelon.gd
extends Area2D

@export var est_modele_spawn: bool = true
@export var boost_volume_sfx_deplacement: float = 8.0

@onready var background = get_node_or_null("../background")
@onready var area_train = get_node_or_null("../train/AreaTrain")

# Ces deux sons dans background servent de MODÈLES.
# Chaque frelon clone va les dupliquer pour avoir ses propres sons.
@onready var sfx_deplacement_modele = background.get_node_or_null("SFX_FRELON") if background else null
@onready var sfx_deplacement_v2_modele = background.get_node_or_null("SFX_FRELON_V2") if background else null

var sfx_deplacement: AudioStreamPlayer2D = null
var sfx_deplacement_v2: AudioStreamPlayer2D = null

# Malgré le nom, SFX_DIE sert maintenant de son de hit / impact de clic.
@onready var sfx_hit = background.get_node_or_null("SFX_DIE") if background else null

# --- SYSTÈME DE VIE ---
@onready var barre_verte = $vie_frelon
@onready var barre_rouge = $vie_perdu_frelon

@export var pv_max: float = 8.0
@export var degats_tir_temporaire: float = 1.0

# Réglage effet Street Fighter
@export var delai_barre_rouge: float = 0.20
@export var duree_coulissement_barre_rouge: float = 0.20

# Sécurité contre les doubles appels de clic sur la même frame.
@export var delai_anti_double_hit_ms: int = 80
var dernier_hit_msec: int = -999999

var pv_actuels: float = 8.0
var barres_visibles = false
var tween_barre_rouge: Tween = null

# --- PARAMÈTRES DE POSITION ---
var train_x = 611.0
var train_y = 300.0

var zone_h_min = 120.0
var zone_h_max = 340.0
var spawn_gauche = -269.0
var spawn_droite = 2414.0

# --- AUDIO ---
@export var distance_max_son: float = 1700.0

# --- MOUVEMENT FRELon ---
@export var vitesse_deplacement_base: float = 520.0
@export var delai_changement_cible: float = 3.0

@export var distance_min_train_x: float = 430.0
@export var distance_max_train_x: float = 760.0

@export var hauteur_min_autour_train: float = -230.0
@export var hauteur_max_autour_train: float = -80.0

@export var chance_changer_cote: float = 0.35

var cible_deplacement = Vector2.ZERO
var temps_avant_changement_cible = 0.0
var cote_actuel = 1

# --- SORTIE À L'ARRÊT ---
var temps_train_arrete = 0.0
@export var delai_disparition_arret: float = 8.0
@export var vitesse_sortie_arret: float = 360.0

# --- ÉTATS ---
var est_mort = false
var est_sortie_arret = false


func _ready():
	if est_modele_spawn:
		initialiser_barres_vie()
		desactiver_modele_spawn()
		return
	
	preparer_sfx_locaux()
	
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	
	initialiser_barres_vie()
	reinitialiser_position()


func preparer_sfx_locaux():
	if sfx_deplacement == null:
		sfx_deplacement = creer_sfx_local(sfx_deplacement_modele, "SFX_FRELON_LOCAL")
	
	if sfx_deplacement_v2 == null:
		sfx_deplacement_v2 = creer_sfx_local(sfx_deplacement_v2_modele, "SFX_FRELON_V2_LOCAL")


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
	
	arreter_sfx_deplacement()


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
	
	temps_train_arrete = 0.0
	temps_avant_changement_cible = 0.0
	
	est_mort = false
	est_sortie_arret = false
	
	rotation = 0
	modulate.a = 1.0
	
	pv_actuels = pv_max
	barres_visibles = false
	dernier_hit_msec = -999999
	
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
	choisir_nouvelle_cible(true)
	
	demarrer_sfx_deplacement()
	
	$frelon.play("default")


func _process(delta):
	if est_mort:
		return
	
	if background:
		if background.vitesse <= 0.0 and not est_sortie_arret:
			temps_train_arrete += delta
			
			if temps_train_arrete >= delai_disparition_arret:
				demarrer_sortie_arret()
		elif background.vitesse > 0.0:
			temps_train_arrete = 0.0
	
	if est_sortie_arret:
		mettre_a_jour_sfx_deplacement()
		gerer_sortie_arret(delta)
		return
	
	if area_train:
		train_x = area_train.global_position.x
		train_y = area_train.global_position.y
	
	mettre_a_jour_sfx_deplacement()
	
	temps_avant_changement_cible -= delta
	
	if temps_avant_changement_cible <= 0.0:
		choisir_nouvelle_cible(false)
	
	if position.distance_to(cible_deplacement) < 25.0:
		choisir_nouvelle_cible(false)
	
	deplacer_vers_cible(delta)
	orienter_visuel(delta)


func demarrer_sfx_deplacement():
	if sfx_deplacement:
		sfx_deplacement.stop()
		sfx_deplacement.play()
	
	if sfx_deplacement_v2:
		sfx_deplacement_v2.stop()
		sfx_deplacement_v2.play()


func arreter_sfx_deplacement():
	if sfx_deplacement:
		sfx_deplacement.stop()
	
	if sfx_deplacement_v2:
		sfx_deplacement_v2.stop()


func mettre_a_jour_sfx_deplacement():
	if area_train:
		train_x = area_train.global_position.x
	
	var distance_au_train = abs(position.x - train_x)
	var intensite = 1.0 - clamp(distance_au_train / distance_max_son, 0.0, 1.0)
	var volume = linear_to_db(intensite) + boost_volume_sfx_deplacement
	
	if sfx_deplacement:
		if not sfx_deplacement.playing:
			sfx_deplacement.play()
		
		sfx_deplacement.volume_db = volume
	
	if sfx_deplacement_v2:
		if not sfx_deplacement_v2.playing:
			sfx_deplacement_v2.play()
		
		sfx_deplacement_v2.volume_db = volume


func choisir_nouvelle_cible(premiere_cible: bool = false):
	temps_avant_changement_cible = delai_changement_cible
	
	if area_train:
		train_x = area_train.global_position.x
		train_y = area_train.global_position.y
	
	if premiere_cible:
		pass
	else:
		if randf() < chance_changer_cote:
			cote_actuel *= -1
	
	var distance_x = randf_range(distance_min_train_x, distance_max_train_x)
	var cible_x = train_x + (distance_x * cote_actuel)
	
	var cible_y = train_y + randf_range(hauteur_min_autour_train, hauteur_max_autour_train)
	cible_y = clamp(cible_y, zone_h_min, zone_h_max)
	
	if randf() < 0.25:
		cible_y = randf_range(zone_h_min, zone_h_min + 45.0)
	
	cible_deplacement = Vector2(cible_x, cible_y)


func deplacer_vers_cible(delta):
	position = position.move_toward(cible_deplacement, vitesse_deplacement_base * delta)


func orienter_visuel(delta):
	$frelon.flip_h = position.x < train_x
	
	var direction = cible_deplacement - position
	
	if direction.length() > 1.0:
		var inclinaison_cible = clamp(direction.y / 260.0, -0.18, 0.18)
		$frelon.rotation = lerp_angle($frelon.rotation, inclinaison_cible, delta * 5.0)


func demarrer_sortie_arret():
	est_sortie_arret = true
	
	arreter_sfx_deplacement()
	
	if barre_verte:
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.visible = false
	
	if tween_barre_rouge:
		tween_barre_rouge.kill()
		tween_barre_rouge = null
	
	$frelon.play("default")
	configurer_visuel_vol()


func gerer_sortie_arret(delta):
	var direction_sortie = -1 if position.x < train_x else 1
	
	position.x += direction_sortie * vitesse_sortie_arret * delta
	modulate.a = move_toward(modulate.a, 0.0, delta * 0.30)
	
	if position.x < spawn_gauche - 250 or position.x > spawn_droite + 250 or modulate.a <= 0.02:
		queue_free()


func configurer_visuel_vol():
	$frelon.scale = Vector2(0.25, 0.25)
	$frelon.rotation = 0


# --- CLIC TEMPORAIRE ---
# Plus tard, le canon appellera directement recevoir_degats(degats_du_canon).
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		simuler_tir_canon_temporaire()


func simuler_tir_canon_temporaire():
	recevoir_degats(degats_tir_temporaire)


func recevoir_degats(degats: float):
	if est_mort or est_sortie_arret:
		return
	
	var maintenant: int = Time.get_ticks_msec()
	if maintenant - dernier_hit_msec < delai_anti_double_hit_ms:
		return
	
	dernier_hit_msec = maintenant
	
	if degats > 0.0:
		if sfx_hit:
			sfx_hit.stop()
			sfx_hit.play()
		
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
	tw_color.tween_property($frelon, "modulate", Color.RED, 0.05)
	tw_color.tween_property($frelon, "modulate", Color.WHITE, 0.05)


func mourir():
	if est_mort:
		return
	
	est_mort = true
	
	arreter_sfx_deplacement()
	
	if barre_verte:
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.visible = false
	
	if tween_barre_rouge:
		tween_barre_rouge.kill()
		tween_barre_rouge = null
	
	if background:
		background.frelon_tue()
		
		if background.has_method("gagner_piece"):
			background.gagner_piece(20)
		else:
			Global.gagner_piece(20)
			
			if background.has_method("mettre_a_jour_ui_pieces"):
				background.mettre_a_jour_ui_pieces(true)
			
			if background.sfx_piece:
				background.sfx_piece.play()
	
	lancer_animation_mort()


func lancer_animation_mort():
	$frelon.stop()
	
	var sens_choc = -1 if position.x < train_x else 1
	
	var tween = create_tween()
	
	tween.tween_property(
		self,
		"position",
		Vector2(position.x + (110.0 * sens_choc), position.y - 35.0),
		0.10
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(
		$frelon,
		"rotation",
		0.55 * -sens_choc,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(
		self,
		"position",
		Vector2(position.x + (150.0 * sens_choc), position.y + 35.0),
		0.22
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.parallel().tween_property(
		$frelon,
		"rotation",
		-0.35 * -sens_choc,
		0.22
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(
		self,
		"position:y",
		position.y + 650.0,
		0.85
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.parallel().tween_property(
		$frelon,
		"rotation",
		1.1 * -sens_choc,
		0.85
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.75)
	
	tween.tween_callback(fin_mort)


func fin_mort():
	queue_free()
