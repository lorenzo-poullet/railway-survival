# area_mouche.gd
extends Area2D

@export var est_modele_spawn: bool = true

@onready var background = get_node_or_null("../background")
@onready var area_train = get_node_or_null("../train/AreaTrain")

# Ces deux sons dans background servent de MODÈLES.
# Chaque mouche clone va les dupliquer pour avoir ses propres sons.
@onready var sfx_deplacement_modele = background.get_node_or_null("SFX_MOUCHE") if background else null
@onready var sfx_attaque_modele = background.get_node_or_null("SFX_MOUCHE_ATTACK") if background else null

var sfx_deplacement: AudioStreamPlayer2D = null
var sfx_attaque: AudioStreamPlayer2D = null

@onready var sfx_mort = background.get_node_or_null("SFX_DIE") if background else null

# --- SYSTÈME DE VIE ---
@onready var barre_verte = $vie_mouche
@onready var barre_rouge = $vie_perdu_mouche

@export var pv_max: float = 4.0
@export var degats_tir_temporaire: float = 1.0

@export var delai_barre_rouge: float = 0.20
@export var duree_coulissement_barre_rouge: float = 0.20

# Sécurité contre les doubles appels de clic sur la même frame.
@export var delai_anti_double_hit_ms: int = 80
var dernier_hit_msec: int = -999999

var pv_actuels: float = 4.0
var barres_visibles = false
var tween_barre_rouge: Tween = null

# --- PARAMÈTRES DE POSITION ---
var train_x = 611.0

var zone_h_min = 227.0
var zone_h_max = 335.0

# Trois zones principales de circulation.
@export var zone_x_gauche: float = 188.0
@export var zone_x_haut: float = 482.0
@export var zone_x_droite: float = 793.0

var spawn_gauche = -269.0
var spawn_droite = 2414.0

# --- AUDIO ---
@export var distance_max_son: float = 1500.0

# --- MOUVEMENT ---
var vitesse_approche_base = 145.0
var vitesse_zigzag_base = 1.8

# Mouvement local autour des zones gauche/droite.
var amplitude_x_laterale = 45.0

# Mouvement dans la zone du haut.
# Réduit par rapport à 300 pour éviter qu'elle parte trop loin à gauche/droite.
var amplitude_x_haut = 160.0

# Ralentit seulement l'oscillation horizontale en haut.
# Ça évite l'effet où la mouche paraît beaucoup plus rapide au centre.
var multiplicateur_vitesse_x_haut = 0.45

var amplitude_y = 28.0

@export var vitesse_debut_depassement: float = 400.0
@export var vitesse_fin_depassement: float = 800.0
@export var force_glissement_depassement: float = 0.70

# --- ATTAQUE MOUCHE ---
@export var delai_attaque_min: float = 8.0
@export var delai_attaque_max: float = 10.0

# Une fois le délai terminé, la mouche a le droit d'attaquer,
# mais elle ne lance pas forcément l'attaque dès la première trajectoire valide.
@export var chance_attaque_si_trajectoire_ok: float = 0.35
@export var delai_trajectoire_valide_min: float = 0.25
@export var delai_trajectoire_valide_max: float = 1.10
@export var delai_reverification_apres_refus_min: float = 0.5
@export var delai_reverification_apres_refus_max: float = 1.2

@export var rotation_attaque_degres: float = 26.0
@export var vitesse_rotation_attaque: float = 55.0
@export var temps_attente_avant_chute: float = 1.0

@export var vitesse_chute_attaque: float = 620.0
@export var vitesse_remontee_attaque: float = 360.0
@export var degats_attaque_train: float = 6.0

# La trajectoire verticale de CollisionMouche doit chevaucher CollisionTrain.
# Je ne touche pas à cette valeur.
@export var chevauchement_minimum_x: float = 8.0

# La mouche doit rentrer légèrement dans CollisionTrain.
@export var profondeur_contact_train: float = 8.0

var temps_avant_attaque: float = 0.0
var temps_avant_reverification_attaque: float = 0.0

var trajectoire_valide_active: bool = false
var temps_avant_decision_trajectoire: float = 0.0

var est_en_attaque: bool = false
var phase_attaque: String = "aucune"

var timer_attente_chute: float = 0.0
var position_retour_attaque = Vector2.ZERO
var cible_chute_attaque = Vector2.ZERO

var a_inflige_degat = false
var flip_attaque: bool = false
var changement_zone_apres_attaque: bool = false

var temps = 0.0
var temps_cote = 0.0
var phase_approche = true

const ZONE_GAUCHE := "gauche"
const ZONE_HAUT := "haut"
const ZONE_DROITE := "droite"

var zone_actuelle: String = ZONE_DROITE
var zone_cible: String = ZONE_DROITE

# Sert à alterner gauche -> haut -> droite -> haut -> gauche.
var derniere_zone_laterale: String = ZONE_DROITE

var est_mort = false
var est_depasse = false


func _ready():
	if est_modele_spawn:
		initialiser_barres_vie()
		desactiver_modele_spawn()
		return
	
	preparer_sfx_locaux()
	
	temps = randf() * 10.0
	
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	
	initialiser_barres_vie()
	reinitialiser_position()


func preparer_sfx_locaux():
	if sfx_deplacement == null:
		sfx_deplacement = creer_sfx_local(sfx_deplacement_modele, "SFX_MOUCHE_LOCAL")
	
	if sfx_attaque == null:
		sfx_attaque = creer_sfx_local(sfx_attaque_modele, "SFX_MOUCHE_ATTACK_LOCAL")


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
	
	if sfx_deplacement:
		sfx_deplacement.stop()
	
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
	
	if randf() > 0.5:
		zone_actuelle = ZONE_DROITE
		zone_cible = ZONE_DROITE
		derniere_zone_laterale = ZONE_DROITE
		position.x = spawn_droite
	else:
		zone_actuelle = ZONE_GAUCHE
		zone_cible = ZONE_GAUCHE
		derniere_zone_laterale = ZONE_GAUCHE
		position.x = spawn_gauche
	
	position.y = randf_range(zone_h_min, zone_h_max)
	
	phase_approche = true
	temps_cote = 0.0
	
	est_mort = false
	est_depasse = false
	est_en_attaque = false
	phase_attaque = "aucune"
	a_inflige_degat = false
	changement_zone_apres_attaque = false
	timer_attente_chute = 0.0
	
	trajectoire_valide_active = false
	temps_avant_decision_trajectoire = 0.0
	
	rotation = 0
	modulate.a = 1.0
	
	temps_avant_attaque = randf_range(delai_attaque_min, delai_attaque_max)
	temps_avant_reverification_attaque = 0.0
	
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
	appliquer_flip_selon_zone_actuelle()
	
	if sfx_deplacement:
		sfx_deplacement.stop()
		sfx_deplacement.play()
	
	$mouche.play("default")


func _process(delta):
	if est_mort:
		return
	
	var facteur_depassement = obtenir_facteur_depassement()
	
	if facteur_depassement >= 1.0 and not est_depasse:
		demarrer_depassement()
	
	if est_depasse:
		gerer_depassement(delta)
		return
	
	if est_en_attaque:
		mettre_a_jour_sfx_deplacement()
		gerer_attaque(delta)
		return
	
	var v_approche = lerp(vitesse_approche_base, vitesse_approche_base * 0.35, facteur_depassement)
	var v_zigzag = lerp(vitesse_zigzag_base, vitesse_zigzag_base * 0.55, facteur_depassement)
	var amplitude_y_actuelle = lerp(amplitude_y, amplitude_y * 0.75, facteur_depassement)
	
	temps += delta
	temps_cote += delta
	
	if area_train:
		train_x = area_train.global_position.x
	
	mettre_a_jour_sfx_deplacement()
	appliquer_flip_selon_zone_actuelle()
	
	if phase_approche:
		var destination_x = obtenir_x_zone(zone_cible)
		var direction = 1 if position.x < destination_x else -1
		
		position.x += direction * v_approche * delta
		
		var milieu_y = (zone_h_min + zone_h_max) / 2.0
		position.y = lerp(
			position.y,
			milieu_y + sin(temps * 1.4) * amplitude_y_actuelle,
			delta * 1.8
		)
		
		gerer_declenchement_attaque(delta)
		
		if est_en_attaque:
			appliquer_glissement_progressif(delta, facteur_depassement)
			return
		
		if abs(position.x - destination_x) < 20.0:
			terminer_arrivee_zone()
	else:
		gerer_circulation_zone(delta, v_zigzag, amplitude_y_actuelle)
		
		gerer_declenchement_attaque(delta)
		
		if est_en_attaque:
			appliquer_glissement_progressif(delta, facteur_depassement)
			return
		
		if temps_cote >= 12.0:
			demarrer_changement_zone()
			appliquer_glissement_progressif(delta, facteur_depassement)
			return
	
	appliquer_glissement_progressif(delta, facteur_depassement)


func mettre_a_jour_sfx_deplacement():
	if not sfx_deplacement:
		return
	
	if not sfx_deplacement.playing:
		sfx_deplacement.play()
	
	if area_train:
		train_x = area_train.global_position.x
	
	var distance_au_train = abs(position.x - train_x)
	var intensite = 1.0 - clamp(distance_au_train / distance_max_son, 0.0, 1.0)
	sfx_deplacement.volume_db = linear_to_db(intensite)


func gerer_circulation_zone(delta, v_zigzag, amplitude_y_actuelle):
	var pivot_x = obtenir_x_zone(zone_actuelle)
	var amplitude_x_actuelle = amplitude_x_laterale
	var vitesse_x = v_zigzag
	
	if zone_actuelle == ZONE_HAUT:
		amplitude_x_actuelle = amplitude_x_haut
		vitesse_x = v_zigzag * multiplicateur_vitesse_x_haut
	
	var zigzag_x = pivot_x + sin(temps * vitesse_x) * amplitude_x_actuelle
	
	if zone_actuelle == ZONE_HAUT:
		zigzag_x = clamp(zigzag_x, zone_x_gauche, zone_x_droite)
	
	var milieu_y = (zone_h_min + zone_h_max) / 2.0
	var zigzag_y = milieu_y + cos(temps * v_zigzag * 0.55) * amplitude_y_actuelle
	
	position.x = lerp(position.x, zigzag_x, delta * 2.0)
	position.y = lerp(position.y, zigzag_y, delta * 2.0)


func obtenir_x_zone(zone: String) -> float:
	match zone:
		ZONE_GAUCHE:
			return zone_x_gauche
		ZONE_HAUT:
			return zone_x_haut
		ZONE_DROITE:
			return zone_x_droite
	
	return zone_x_haut


func appliquer_flip_selon_zone_actuelle():
	if zone_actuelle == ZONE_GAUCHE:
		$mouche.flip_h = true
	elif zone_actuelle == ZONE_DROITE:
		$mouche.flip_h = false
	else:
		# Dans la zone du haut, elle s'oriente selon sa position autour du centre.
		$mouche.flip_h = global_position.x < zone_x_haut


func demarrer_changement_zone():
	# On ne flip PAS ici.
	# On change seulement la destination.
	if zone_actuelle == ZONE_GAUCHE:
		derniere_zone_laterale = ZONE_GAUCHE
		zone_cible = ZONE_HAUT
	elif zone_actuelle == ZONE_DROITE:
		derniere_zone_laterale = ZONE_DROITE
		zone_cible = ZONE_HAUT
	elif zone_actuelle == ZONE_HAUT:
		if derniere_zone_laterale == ZONE_GAUCHE:
			zone_cible = ZONE_DROITE
		else:
			zone_cible = ZONE_GAUCHE
	
	phase_approche = true
	temps_cote = 0.0


func terminer_arrivee_zone():
	zone_actuelle = zone_cible
	
	if zone_actuelle == ZONE_GAUCHE or zone_actuelle == ZONE_DROITE:
		derniere_zone_laterale = zone_actuelle
	
	phase_approche = false
	temps_cote = 0.0
	appliquer_flip_selon_zone_actuelle()


func gerer_declenchement_attaque(delta):
	if est_mort or est_depasse or est_en_attaque:
		return
	
	if temps_avant_attaque > 0.0:
		temps_avant_attaque -= delta
		
		if temps_avant_attaque < 0.0:
			temps_avant_attaque = 0.0
		
		return
	
	if temps_avant_reverification_attaque > 0.0:
		temps_avant_reverification_attaque -= delta
		
		if temps_avant_reverification_attaque < 0.0:
			temps_avant_reverification_attaque = 0.0
		
		return
	
	var trajectoire_ok = peut_lancer_attaque()
	
	if not trajectoire_ok:
		trajectoire_valide_active = false
		temps_avant_decision_trajectoire = 0.0
		return
	
	if not trajectoire_valide_active:
		trajectoire_valide_active = true
		temps_avant_decision_trajectoire = randf_range(
			delai_trajectoire_valide_min,
			delai_trajectoire_valide_max
		)
		return
	
	temps_avant_decision_trajectoire -= delta
	
	if temps_avant_decision_trajectoire > 0.0:
		return
	
	if randf() <= chance_attaque_si_trajectoire_ok:
		lancer_attaque()
	else:
		trajectoire_valide_active = false
		temps_avant_decision_trajectoire = 0.0
		temps_avant_reverification_attaque = randf_range(
			delai_reverification_apres_refus_min,
			delai_reverification_apres_refus_max
		)


func peut_lancer_attaque() -> bool:
	if not est_dans_zone_haut_attaque():
		return false
	
	var rect_train = obtenir_rect_collision_train()
	var rect_mouche = obtenir_rect_collision_mouche()
	
	if rect_train.size.x <= 0.0 or rect_train.size.y <= 0.0:
		return false
	
	if rect_mouche.size.x <= 0.0 or rect_mouche.size.y <= 0.0:
		return false
	
	var bas_mouche = rect_mouche.position.y + rect_mouche.size.y
	
	if bas_mouche >= rect_train.position.y:
		return false
	
	var overlap_x = calculer_chevauchement_x(rect_mouche, rect_train)
	
	if overlap_x < chevauchement_minimum_x:
		return false
	
	return true


func est_dans_zone_haut_attaque() -> bool:
	if global_position.x < zone_x_gauche:
		return false
	
	if global_position.x > zone_x_droite:
		return false
	
	return true


func lancer_attaque():
	if est_mort or est_depasse or est_en_attaque:
		return
	
	var rect_train = obtenir_rect_collision_train()
	var rect_mouche = obtenir_rect_collision_mouche()
	
	if rect_train.size.x <= 0.0 or rect_train.size.y <= 0.0:
		return
	
	if rect_mouche.size.x <= 0.0 or rect_mouche.size.y <= 0.0:
		return
	
	est_en_attaque = true
	phase_attaque = "rotation"
	a_inflige_degat = false
	changement_zone_apres_attaque = false
	
	trajectoire_valide_active = false
	temps_avant_decision_trajectoire = 0.0
	temps_avant_reverification_attaque = 0.0
	
	flip_attaque = $mouche.flip_h
	$mouche.flip_h = flip_attaque
	
	position_retour_attaque = global_position
	
	var bas_mouche_actuel = rect_mouche.position.y + rect_mouche.size.y
	var offset_bas_mouche = bas_mouche_actuel - global_position.y
	
	var y_contact = rect_train.position.y + profondeur_contact_train
	var centre_y_contact = y_contact - offset_bas_mouche
	
	cible_chute_attaque = Vector2(global_position.x, centre_y_contact)
	timer_attente_chute = temps_attente_avant_chute


func gerer_attaque(delta):
	temps += delta
	temps_cote += delta
	
	if area_train:
		train_x = area_train.global_position.x
	
	if temps_cote >= 12.0:
		changement_zone_apres_attaque = true
	
	$mouche.flip_h = flip_attaque
	
	match phase_attaque:
		"rotation":
			var rotation_cible = obtenir_rotation_attaque_cible()
			
			$mouche.rotation_degrees = move_toward(
				$mouche.rotation_degrees,
				rotation_cible,
				vitesse_rotation_attaque * delta
			)
			
			if abs($mouche.rotation_degrees - rotation_cible) <= 0.5:
				$mouche.rotation_degrees = rotation_cible
				phase_attaque = "attente"
				
				# Le son commence ici, pendant la vraie charge visible.
				# On cap l'attente pour éviter que le son soit fini avant la chute.
				timer_attente_chute = min(temps_attente_avant_chute, 1.00)
				
				if sfx_attaque:
					sfx_attaque.stop()
					sfx_attaque.play()
		
		"attente":
			$mouche.flip_h = flip_attaque
			
			timer_attente_chute -= delta
			
			if timer_attente_chute <= 0.0:
				phase_attaque = "chute"
		
		"chute":
			$mouche.flip_h = flip_attaque
			
			global_position = global_position.move_toward(
				cible_chute_attaque,
				vitesse_chute_attaque * delta
			)
			
			if collisions_mouche_train_se_touchent():
				infliger_degat_train()
				phase_attaque = "remontee"
				return
			
			if global_position.distance_to(cible_chute_attaque) <= 4.0:
				phase_attaque = "remontee"
		
		"remontee":
			$mouche.flip_h = flip_attaque
			
			global_position = global_position.move_toward(
				position_retour_attaque,
				vitesse_remontee_attaque * delta
			)
			
			if global_position.distance_to(position_retour_attaque) <= 6.0:
				terminer_attaque()


func obtenir_rotation_attaque_cible() -> float:
	if flip_attaque:
		return -rotation_attaque_degres
	
	return rotation_attaque_degres


func terminer_attaque():
	est_en_attaque = false
	phase_attaque = "aucune"
	a_inflige_degat = false
	
	temps_avant_attaque = randf_range(delai_attaque_min, delai_attaque_max)
	temps_avant_reverification_attaque = 0.0
	trajectoire_valide_active = false
	temps_avant_decision_trajectoire = 0.0
	
	var tween_rotation = create_tween()
	tween_rotation.tween_property(
		$mouche,
		"rotation_degrees",
		0.0,
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if changement_zone_apres_attaque or temps_cote >= 12.0:
		demarrer_changement_zone()
		appliquer_flip_selon_zone_actuelle()
		return
	
	phase_approche = false
	appliquer_flip_selon_zone_actuelle()


func infliger_degat_train():
	if a_inflige_degat:
		return
	
	a_inflige_degat = true
	
	if background and background.has_method("subir_degats"):
		background.subir_degats(degats_attaque_train)


func collisions_mouche_train_se_touchent() -> bool:
	var rect_train = obtenir_rect_collision_train()
	var rect_mouche = obtenir_rect_collision_mouche()
	
	if rect_train.size.x <= 0.0 or rect_train.size.y <= 0.0:
		return false
	
	if rect_mouche.size.x <= 0.0 or rect_mouche.size.y <= 0.0:
		return false
	
	return rect_train.intersects(rect_mouche)


func calculer_chevauchement_x(rect_a: Rect2, rect_b: Rect2) -> float:
	var gauche = max(rect_a.position.x, rect_b.position.x)
	var droite = min(rect_a.position.x + rect_a.size.x, rect_b.position.x + rect_b.size.x)
	
	return max(0.0, droite - gauche)


func obtenir_rect_collision_train() -> Rect2:
	var collision_train = obtenir_collision_train()
	
	if collision_train and collision_train.shape is RectangleShape2D:
		var scale_abs = Vector2(abs(collision_train.global_scale.x), abs(collision_train.global_scale.y))
		var size = collision_train.shape.size * scale_abs
		var pos = collision_train.global_position - (size * 0.5)
		return Rect2(pos, size)
	
	return Rect2(Vector2.ZERO, Vector2.ZERO)


func obtenir_collision_train():
	if not area_train:
		return null
	
	var collision_train = area_train.get_node_or_null("CollisionTrain")
	
	if collision_train and collision_train is CollisionShape2D:
		return collision_train
	
	for enfant in area_train.get_children():
		if enfant is CollisionShape2D:
			return enfant
	
	return null


func obtenir_rect_collision_mouche() -> Rect2:
	var collision_mouche = obtenir_collision_mouche()
	
	if collision_mouche and collision_mouche.shape is RectangleShape2D:
		var scale_abs = Vector2(abs(collision_mouche.global_scale.x), abs(collision_mouche.global_scale.y))
		var size = collision_mouche.shape.size * scale_abs
		var pos = collision_mouche.global_position - (size * 0.5)
		return Rect2(pos, size)
	
	return Rect2(Vector2.ZERO, Vector2.ZERO)


func obtenir_collision_mouche():
	var collision_mouche = get_node_or_null("CollisionMouche")
	
	if collision_mouche and collision_mouche is CollisionShape2D:
		return collision_mouche
	
	for enfant in get_children():
		if enfant is CollisionShape2D:
			return enfant
	
	return null


func obtenir_facteur_depassement() -> float:
	if not background:
		return 0.0
	
	var plage = vitesse_fin_depassement - vitesse_debut_depassement
	
	if plage <= 0.0:
		return 0.0
	
	var facteur = (background.vitesse_reelle - vitesse_debut_depassement) / plage
	
	return clamp(facteur, 0.0, 1.0)


func appliquer_glissement_progressif(delta, facteur_depassement):
	if facteur_depassement <= 0.0:
		return
	
	var vitesse_train = 400.0
	
	if background:
		vitesse_train = background.vitesse_reelle
	
	var glissement = vitesse_train * force_glissement_depassement * facteur_depassement
	
	position.x -= glissement * delta
	
	if facteur_depassement > 0.65:
		modulate.a = move_toward(modulate.a, 0.65, delta * 0.12)
	
	if position.x < spawn_gauche - 250:
		queue_free()


func demarrer_depassement():
	est_depasse = true
	phase_approche = false
	est_en_attaque = false
	phase_attaque = "aucune"
	
	if sfx_deplacement:
		sfx_deplacement.stop()
	
	if sfx_attaque:
		sfx_attaque.stop()
	
	if barre_verte:
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.visible = false
	
	if tween_barre_rouge:
		tween_barre_rouge.kill()
		tween_barre_rouge = null
	
	$mouche.play("default")
	$mouche.scale = Vector2(0.15, 0.15)
	
	var tw = create_tween()
	tw.tween_property($mouche, "rotation", -PI / 8, 0.35)


func gerer_depassement(delta):
	if background:
		position.x -= (background.vitesse_reelle * 0.75) * delta
	else:
		position.x -= 600.0 * delta
	
	modulate.a = move_toward(modulate.a, 0.0, delta * 0.25)
	
	if position.x < spawn_gauche - 250 or modulate.a <= 0.02:
		queue_free()


func configurer_visuel_vol():
	$mouche.scale = Vector2(0.15, 0.15)
	$mouche.rotation = 0
	$mouche.rotation_degrees = 0.0


func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		simuler_tir_canon_temporaire()


func simuler_tir_canon_temporaire():
	recevoir_degats(degats_tir_temporaire)


func recevoir_degats(degats: float):
	if est_mort or est_depasse:
		return
	
	var maintenant: int = Time.get_ticks_msec()
	if maintenant - dernier_hit_msec < delai_anti_double_hit_ms:
		return
	
	dernier_hit_msec = maintenant
	
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
	tw_color.tween_property($mouche, "modulate", Color.RED, 0.05)
	tw_color.tween_property($mouche, "modulate", Color.WHITE, 0.05)


func mourir():
	if est_mort:
		return
	
	est_mort = true
	est_en_attaque = false
	phase_attaque = "aucune"
	
	$mouche.stop()
	configurer_visuel_vol()
	
	if barre_verte:
		barre_verte.visible = false
	
	if barre_rouge:
		barre_rouge.visible = false
	
	if tween_barre_rouge:
		tween_barre_rouge.kill()
		tween_barre_rouge = null
	
	if sfx_deplacement:
		sfx_deplacement.stop()
	
	if sfx_attaque:
		sfx_attaque.stop()
	
	if background:
		background.mouche_tue()
		
		if background.has_method("gagner_piece"):
			background.gagner_piece(5)
		else:
			Global.gagner_piece(5)
			
			if background.has_method("mettre_a_jour_ui_pieces"):
				background.mettre_a_jour_ui_pieces(true)
			
			if background.sfx_piece:
				background.sfx_piece.play()
	
	var tween = create_tween()
	var sens_choc = -1 if position.x < train_x else 1
	
	tween.tween_property(
		self,
		"position",
		Vector2(position.x + (60.0 * sens_choc), position.y - 35.0),
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property($mouche, "rotation", PI * 3.0 * -sens_choc, 0.45)
	
	tween.tween_property(self, "position:y", position.y + 500.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.7)
	
	tween.tween_callback(fin_mort)


func fin_mort():
	queue_free()
