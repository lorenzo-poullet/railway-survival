# background.gd
extends Node2D

@export var vitesse: float = 400.0
var vitesse_reelle: float = 0.0
@export var acceleration: float = 200.0
var ecart_parfait: float = 1144.0
var centre_x: float = 578.0
@export var position_arret_b3: float = 220.0

# --- RÉFÉRENCES ---
@onready var b1 = $b1
@onready var b2 = $b2
@onready var b3 = get_node_or_null("b3")
@onready var sprite_train = get_node("../train")
@onready var piece = get_node("../piece")
@onready var moustique_original = get_node_or_null("../AreaMoustique")
@onready var mouche_original = get_node_or_null("../AreaMouche")
@onready var frelon_original = get_node_or_null("../AreaFrelon")
@onready var spider_original = get_node_or_null("../AreaSpider")

@onready var label_debug = get_node_or_null("LabelDebugDev")
@onready var regulateur = get_node_or_null("Regulateur")

@onready var sfx_transition = $SFX_Transition
@onready var sfx_mouvement = $SFX_Mouvement
@onready var sfx_piece = $SFX_Piece
@onready var label_piece = $Regulateur/niveau_piece
@onready var sfx_xp = $SFX_XP
@onready var sfx_xp2 = $SFX_XP2

@onready var sfx_train_impact = $SFX_Train_impact
@onready var sfx_train_impact_fatal = $SFX_Train_impact_fatal
@onready var sfx_train_die = $SFX_Train_die

@onready var barre_verte = $SocleVie/vie_train
@onready var barre_rouge = $SocleVie/vie_perdu_train
@onready var xp_barre = $SocleVie/xp
@onready var label_nv = $SocleVie/xp/label_nv
@onready var overlay_lock = $Regulateur/OverlayLock

# --- PARAMÈTRES JEU ---
@export var gain_xp_vitesse : float = 2.0
@export var xp_par_moustique : float = 5.0
@export var xp_par_mouche : float = 2.0
@export var xp_par_frelon : float = 10.0
@export var xp_par_spider : float = 7.5
@export var distance_pour_une_piece : float = 1000.0

var accumulation_distance : float = 0.0

# XP passive : on accumule pour éviter d'afficher 0 à chaque frame.
var xp_popup_accumulee : float = 0.0
var seuil_popup_xp_passive : float = 1.0

var etat = "idle"
var est_mort : bool = false

# --- BIOME ---
var chrono_biome : float = 60.0
var transition_grotte_active : bool = false
var grotte_verrouillee : bool = false

var temps_depuis_spawn_moustique : float = 0.0
var temps_depuis_spawn_mouche : float = 0.0
var temps_depuis_spawn_frelon : float = 0.0
var temps_depuis_spawn_spider : float = 0.0

# --- TRANSITION ---
var rideau_noir : ColorRect
var sequence_tunnel_lancee : bool = false

# --- DEBUG ---
var debug_ratio_temps: float = 0.0
var debug_taux_chrono : float = 0.0
var debug_taux_vitesse : float = 0.0
var debug_frequence_finale : float = 0.0
var delai_spawn_actuel : float = 0.0

var delai_spawn_moustique_actuel : float = 0.0
var delai_spawn_mouche_actuel : float = 0.0
var delai_spawn_frelon_actuel : float = 0.0
var delai_spawn_spider_actuel : float = 0.0

var debug_palier_vitesse : String = "x1.0"
var debug_spawn_moustique_actif : bool = true
var debug_spawn_mouche_actif : bool = false
var debug_spawn_frelon_actif : bool = false
var debug_spawn_spider_actif : bool = false
var debug_etat_spawn : String = "Spawn actif"
var debug_label_visible : bool = true


func basculer_label_debug():
	debug_label_visible = not debug_label_visible
	
	if label_debug:
		label_debug.visible = debug_label_visible


func _ready():
	if label_debug:
		label_debug.add_theme_font_size_override("font_size", 9)

	vitesse_reelle = vitesse
	
	placer_decors_depart()
	preparer_modeles_mobs()
	
	if piece:
		piece.play("run")
	
	creer_systeme_transition_reutilisable()
	mettre_a_jour_ui_complete()


func preparer_modeles_mobs():
	preparer_modele_mob(moustique_original)
	preparer_modele_mob(mouche_original)
	preparer_modele_mob(frelon_original)
	preparer_modele_mob(spider_original)


func preparer_modele_mob(mob):
	if not mob:
		return
	
	mob.est_modele_spawn = true
	mob.visible = false
	mob.position = Vector2(-99999, -99999)
	mob.set_process(false)
	mob.set_physics_process(false)
	mob.set_process_input(false)
	mob.set_process_unhandled_input(false)
	
	if mob is Area2D:
		mob.monitoring = false
		mob.monitorable = false
		mob.input_pickable = false


func activer_clone_mob(clone):
	if not clone:
		return
	
	clone.est_modele_spawn = false
	clone.visible = true
	clone.set_process(true)
	clone.set_physics_process(true)
	clone.set_process_input(true)
	clone.set_process_unhandled_input(true)
	
	if clone is Area2D:
		clone.monitoring = true
		clone.monitorable = true
		clone.input_pickable = true


func placer_decors_depart():
	if Global.retour_de_grotte:
		if b3:
			b3.visible = true
			b3.scale.x = -1.0
			b3.position.x = centre_x
		
		b1.position.x = centre_x + ecart_parfait
		b2.position.x = centre_x + ecart_parfait * 2.0
		
		Global.retour_de_grotte = false
	else:
		b1.position.x = centre_x
		b2.position.x = centre_x + ecart_parfait
		
		if b3:
			b3.visible = false
			b3.scale.x = 1.0
			b3.position.x = centre_x + ecart_parfait * 2.0


func creer_systeme_transition_reutilisable():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	rideau_noir = ColorRect.new()
	rideau_noir.color = Color.BLACK
	rideau_noir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rideau_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rideau_noir.modulate.a = 0.0
	canvas_layer.add_child(rideau_noir)


func _process(delta):
	if est_mort:
		actualiser_label_debug()
		return
	
	gerer_vitesse(delta)
	gerer_chrono(delta)
	gerer_mouvement_decors(delta)
	gerer_tapis_roulant_surface()
	gerer_transition_grotte()
	gerer_spawn_mobs(delta)
	gerer_progression(delta)
	gerer_audio()
	actualiser_label_debug()


func obtenir_palier_vitesse() -> String:
	var vitesse_arrondie := int(round(vitesse))
	
	match vitesse_arrondie:
		0:
			return "x0"
		200:
			return "x0.5"
		400:
			return "x1.0"
		800:
			return "x1.5"
		1200:
			return "x2.0"
	
	return "inconnu"


func moustique_spawn_autorise() -> bool:
	var vitesse_arrondie := int(round(vitesse))
	
	match vitesse_arrondie:
		400:
			return true
		800:
			return true
	
	return false


func mouche_spawn_autorise() -> bool:
	var vitesse_arrondie := int(round(vitesse))
	
	match vitesse_arrondie:
		200:
			return true
		400:
			return true
	
	return false


func frelon_spawn_autorise() -> bool:
	var vitesse_arrondie := int(round(vitesse))
	
	match vitesse_arrondie:
		1200:
			return true
	
	return false


func spider_spawn_autorise() -> bool:
	var vitesse_arrondie := int(round(vitesse))
	
	match vitesse_arrondie:
		800:
			return true
		1200:
			return true
	
	return false


func obtenir_texte_spawn() -> String:
	var vitesse_arrondie := int(round(vitesse))
	
	match vitesse_arrondie:
		0:
			return "Mouches OFF | Moustiques OFF | Spider OFF | Frelons OFF"
		200:
			return "Mouches ON | Moustiques OFF | Spider OFF | Frelons OFF"
		400:
			return "Mouches ON | Moustiques ON | Spider OFF | Frelons OFF"
		800:
			return "Mouches OFF | Moustiques ON | Spider ON | Frelons OFF"
		1200:
			return "Mouches OFF | Moustiques OFF | Spider ON | Frelons ON"
	
	return "Spawn : vitesse inconnue"


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
	if vitesse_reelle > 0.1 and chrono_biome > 0.0 and not grotte_verrouillee and not sequence_tunnel_lancee:
		var facteur_vitesse = vitesse_reelle / 400.0
		chrono_biome -= facteur_vitesse * delta
		if chrono_biome <= 0.0:
			chrono_biome = 0.0


func gerer_mouvement_decors(delta):
	if grotte_verrouillee:
		return
	
	b1.position.x -= vitesse_reelle * delta
	b2.position.x -= vitesse_reelle * delta
	
	if b3 and b3.visible:
		b3.position.x -= vitesse_reelle * delta


func gerer_tapis_roulant_surface():
	if transition_grotte_active:
		return

	var limite_gauche: float = centre_x - ecart_parfait

	if b3 and b3.visible and b3.scale.x == -1.0 and b3.position.x <= limite_gauche:
		b3.visible = false
		b3.scale.x = 1.0

	if b1.position.x <= limite_gauche:
		b1.position.x += ecart_parfait * 2.0

	if b2.position.x <= limite_gauche:
		if chrono_biome <= 0.0 and not transition_grotte_active:
			b2.position.x = b1.position.x + ecart_parfait
			injecter_arche_entree(b2.position.x + ecart_parfait)
		else:
			b2.position.x = b1.position.x + ecart_parfait


func injecter_arche_entree(pos_x: float):
	transition_grotte_active = true
	
	if b3:
		b3.visible = true
		b3.scale.x = 1.0
		b3.position.x = pos_x


func gerer_transition_grotte():
	if not transition_grotte_active:
		return
	
	if not b3 or grotte_verrouillee:
		return
	
	var distance_restante: float = b3.position.x - position_arret_b3
	
	if distance_restante > 0.0:
		if distance_restante < 300.0:
			vitesse = clamp((distance_restante / 300.0) * 400.0, 20.0, 400.0)
	else:
		b3.position.x = position_arret_b3
		vitesse = 0.0
		vitesse_reelle = 0.0
		grotte_verrouillee = true
		lancer_sequence_entree_tunnel()


func gerer_spawn_mobs(delta):
	debug_palier_vitesse = obtenir_palier_vitesse()
	debug_spawn_moustique_actif = moustique_spawn_autorise()
	debug_spawn_mouche_actif = mouche_spawn_autorise()
	debug_spawn_frelon_actif = frelon_spawn_autorise()
	debug_spawn_spider_actif = spider_spawn_autorise()
	debug_etat_spawn = obtenir_texte_spawn()
	
	if vitesse_reelle <= 0.1:
		reset_debug_spawn()
		temps_depuis_spawn_moustique = 0.0
		temps_depuis_spawn_mouche = 0.0
		temps_depuis_spawn_frelon = 0.0
		temps_depuis_spawn_spider = 0.0
		return
	
	if chrono_biome <= 0.0:
		reset_debug_spawn()
		temps_depuis_spawn_moustique = 0.0
		temps_depuis_spawn_mouche = 0.0
		temps_depuis_spawn_frelon = 0.0
		temps_depuis_spawn_spider = 0.0
		return
	
	if sequence_tunnel_lancee:
		reset_debug_spawn()
		temps_depuis_spawn_moustique = 0.0
		temps_depuis_spawn_mouche = 0.0
		temps_depuis_spawn_frelon = 0.0
		temps_depuis_spawn_spider = 0.0
		return
	
	debug_ratio_temps = 1.0 - (chrono_biome / 60.0)
	debug_ratio_temps = clamp(debug_ratio_temps, 0.0, 1.0)
	
	var progression_douce: float = pow(debug_ratio_temps, 1.8)
	
	debug_taux_chrono = lerp(0.12, 0.34, progression_douce)
	debug_taux_vitesse = clamp(vitesse_reelle / 400.0, 0.0, 1.5)
	debug_frequence_finale = debug_taux_chrono * debug_taux_vitesse
	
	if debug_frequence_finale <= 0.01:
		return
	
	delai_spawn_actuel = 1.0 / debug_frequence_finale
	delai_spawn_actuel = max(1.8, delai_spawn_actuel)
	
	delai_spawn_mouche_actuel = delai_spawn_actuel * 1.25
	delai_spawn_moustique_actuel = delai_spawn_actuel
	delai_spawn_spider_actuel = delai_spawn_actuel * 1.45
	delai_spawn_frelon_actuel = delai_spawn_actuel * 1.60
	
	if debug_spawn_mouche_actif:
		temps_depuis_spawn_mouche += delta
		
		if temps_depuis_spawn_mouche >= delai_spawn_mouche_actuel:
			temps_depuis_spawn_mouche = 0.0
			cloner_mob(mouche_original)
	else:
		temps_depuis_spawn_mouche = 0.0
	
	if debug_spawn_moustique_actif:
		temps_depuis_spawn_moustique += delta
		
		if temps_depuis_spawn_moustique >= delai_spawn_moustique_actuel:
			temps_depuis_spawn_moustique = 0.0
			cloner_mob(moustique_original)
	else:
		temps_depuis_spawn_moustique = 0.0
	
	if debug_spawn_spider_actif:
		temps_depuis_spawn_spider += delta
		
		if temps_depuis_spawn_spider >= delai_spawn_spider_actuel:
			temps_depuis_spawn_spider = 0.0
			cloner_mob(spider_original)
	else:
		temps_depuis_spawn_spider = 0.0
	
	if debug_spawn_frelon_actif:
		temps_depuis_spawn_frelon += delta
		
		if temps_depuis_spawn_frelon >= delai_spawn_frelon_actuel:
			temps_depuis_spawn_frelon = 0.0
			cloner_mob(frelon_original)
	else:
		temps_depuis_spawn_frelon = 0.0


func reset_debug_spawn():
	debug_taux_vitesse = 0.0
	debug_frequence_finale = 0.0
	delai_spawn_actuel = 0.0
	delai_spawn_mouche_actuel = 0.0
	delai_spawn_moustique_actuel = 0.0
	delai_spawn_spider_actuel = 0.0
	delai_spawn_frelon_actuel = 0.0


func cloner_mob(mob_original):
	if est_mort or chrono_biome <= 0.0 or sequence_tunnel_lancee:
		return
	
	if not mob_original:
		return
	
	var clone = mob_original.duplicate()
	clone.est_modele_spawn = false
	clone.visible = false
	clone.position = Vector2(-99999, -99999)
	
	mob_original.get_parent().add_child(clone)
	activer_clone_mob(clone)
	clone.reinitialiser_position()


func gerer_progression(delta):
	if vitesse_reelle > 0.1 and not grotte_verrouillee and not sequence_tunnel_lancee:
		ajouter_xp((vitesse_reelle / 400.0) * gain_xp_vitesse * delta, false)
		
		accumulation_distance += vitesse_reelle * delta
		if accumulation_distance >= distance_pour_une_piece:
			gagner_piece(1)
			accumulation_distance = 0.0
		
		if sprite_train and not sprite_train.is_playing():
			sprite_train.play()
		if piece and not piece.is_playing():
			piece.play("run")
		
		if sprite_train:
			sprite_train.speed_scale = vitesse_reelle / 400.0
		if piece:
			piece.speed_scale = vitesse_reelle / 400.0
	else:
		if not sequence_tunnel_lancee:
			if sprite_train and sprite_train.is_playing():
				sprite_train.stop()
			if piece and piece.is_playing():
				piece.stop()


func lancer_sequence_entree_tunnel():
	if sequence_tunnel_lancee:
		return
	
	sequence_tunnel_lancee = true
	
	if sfx_mouvement:
		sfx_mouvement.stop()
	if sfx_transition:
		sfx_transition.play()
	
	if sprite_train:
		sprite_train.play()
		sprite_train.speed_scale = 0.8
	
	var tween = create_tween()
	
	if sprite_train:
		var cible_x_grotte = sprite_train.position.x + 450.0
		tween.tween_property(sprite_train, "position:x", cible_x_grotte, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.parallel().tween_property(rideau_noir, "modulate:a", 1.0, 1.5).set_delay(1.0)
	tween.tween_callback(finaliser_entree_grotte)


func finaliser_entree_grotte():
	nettoyer_mobs()
	
	if sprite_train:
		sprite_train.stop()
	if piece:
		piece.stop()
	
	get_tree().change_scene_to_file("res://grotte.tscn")


func nettoyer_mobs():
	var parent = null
	
	if moustique_original:
		parent = moustique_original.get_parent()
	elif mouche_original:
		parent = mouche_original.get_parent()
	elif frelon_original:
		parent = frelon_original.get_parent()
	elif spider_original:
		parent = spider_original.get_parent()
	
	if not parent:
		return
	
	for enfant in parent.get_children():
		if enfant == moustique_original or enfant == mouche_original or enfant == spider_original or enfant == frelon_original:
			continue
		
		if "AreaMoustique" in enfant.name or "AreaMouche" in enfant.name or "AreaFrelon" in enfant.name or "AreaSpider" in enfant.name:
			enfant.queue_free()
	
	preparer_modeles_mobs()


func ajouter_xp(montant: float, afficher_popup_immediat: bool = false):
	var ancien_pv := Global.pv_actuels
	var ancien_pourcentage_vie := Global.obtenir_pourcentage_vie()
	var niveaux_gagnes := Global.ajouter_xp(montant)
	
	if montant > 0.0:
		if afficher_popup_immediat:
			afficher_popup_xp(montant, true)
		else:
			xp_popup_accumulee += montant
			
			if xp_popup_accumulee >= seuil_popup_xp_passive:
				var xp_a_afficher: float = floor(xp_popup_accumulee)
				xp_popup_accumulee -= xp_a_afficher
				
				if xp_a_afficher > 0.0:
					afficher_popup_xp(xp_a_afficher, false)
	
	if niveaux_gagnes > 0:
		if sfx_xp:
			sfx_xp.play()
		if sfx_xp2:
			sfx_xp2.play()
		
		var nouveau_pourcentage_vie := Global.obtenir_pourcentage_vie()
		var gain_pv := Global.pv_actuels - ancien_pv
		
		if gain_pv > 0.0:
			afficher_popup_soin_train(gain_pv)
		
		if nouveau_pourcentage_vie != ancien_pourcentage_vie:
			mettre_a_jour_ui_vie(false)
	
	mettre_a_jour_ui_niveau()


func afficher_popup_xp(montant: float, important: bool = false):
	var position_popup: Vector2 = Vector2.ZERO
	
	if label_nv:
		position_popup = label_nv.global_position + Vector2(label_nv.size.x + -20.0, 2.0)
	elif xp_barre:
		position_popup = xp_barre.global_position + Vector2(58.0, 18.0)
	else:
		return
	
	if important and Damage.has_method("afficher_xp_importante"):
		Damage.afficher_xp_importante(montant, position_popup)
	else:
		Damage.afficher_xp(montant, position_popup)


func afficher_popup_piece(nombre: int):
	if not label_piece:
		return
	
	var position_popup: Vector2 = label_piece.global_position + Vector2(16.0, 8.0)
	
	if nombre >= 2 and Damage.has_method("afficher_piece_importante"):
		Damage.afficher_piece_importante(nombre, position_popup)
	else:
		Damage.afficher_piece(nombre, position_popup)


func afficher_popup_degats_train(montant: float):
	if not sprite_train:
		return
	
	Damage.afficher_degats(montant, sprite_train.global_position + Vector2(0.0, -70.0))


func afficher_popup_soin_train(montant: float):
	if not sprite_train:
		return
	
	Damage.afficher_soin(montant, sprite_train.global_position + Vector2(0.0, -95.0))


func monter_niveau():
	ajouter_xp(Global.xp_requise, true)


func mettre_a_jour_ui_complete():
	mettre_a_jour_ui_vie(true)
	mettre_a_jour_ui_niveau()
	mettre_a_jour_ui_pieces(false)


func mettre_a_jour_ui_vie(instant: bool = false):
	var pourcentage_vie := Global.obtenir_pourcentage_vie()
	
	if barre_verte:
		barre_verte.max_value = 100.0
	if barre_rouge:
		barre_rouge.max_value = 100.0
	
	if instant:
		if barre_verte:
			barre_verte.value = pourcentage_vie
		if barre_rouge:
			barre_rouge.value = pourcentage_vie
		return
	
	if barre_verte:
		var tv = create_tween()
		tv.tween_property(barre_verte, "value", pourcentage_vie, 0.25).set_trans(Tween.TRANS_SINE)
	
	if barre_rouge:
		var tr = create_tween()
		tr.tween_interval(0.25)
		tr.tween_property(barre_rouge, "value", pourcentage_vie, 0.35).set_trans(Tween.TRANS_SINE)


func mettre_a_jour_ui_niveau():
	if label_nv:
		label_nv.text = "Niv. " + str(Global.niveau_actuel)
	
	if xp_barre:
		xp_barre.step = 0.0
		xp_barre.max_value = Global.xp_requise
		xp_barre.value = Global.xp_actuelle
	
	if overlay_lock:
		overlay_lock.visible = Global.niveau_actuel < 5


func mettre_a_jour_ui_pieces(animer: bool = true):
	if label_piece:
		label_piece.text = str(Global.score_pieces)
		
		if animer:
			var tw = create_tween()
			tw.tween_property(label_piece, "scale", Vector2(1.5, 1.5), 0.05)
			tw.tween_property(label_piece, "scale", Vector2(1.0, 1.0), 0.05)


func moustique_tue():
	ajouter_xp(xp_par_moustique, true)


func mouche_tue():
	ajouter_xp(xp_par_mouche, true)


func frelon_tue():
	ajouter_xp(xp_par_frelon, true)


func spider_tue():
	ajouter_xp(xp_par_spider, true)


func ajuster_vitesse(nouvelle_vitesse):
	if Global.niveau_actuel >= 5:
		vitesse = nouvelle_vitesse
	else:
		print("Commande verrouillée : Niveau 5 requis")


func gagner_piece(nombre: int = 1):
	if nombre <= 0:
		return
	
	Global.gagner_piece(nombre)
	afficher_popup_piece(nombre)
	
	if sfx_piece:
		sfx_piece.play()
	
	mettre_a_jour_ui_pieces(true)


func subir_degats(montant):
	if est_mort:
		return
	
	if Global.pv_actuels - montant <= 0:
		if sfx_train_impact_fatal:
			sfx_train_impact_fatal.play()
	else:
		if sfx_train_impact:
			sfx_train_impact.play()
	
	afficher_popup_degats_train(montant)
	
	Global.subir_degats(montant)
	
	var pourcentage_vie := Global.obtenir_pourcentage_vie()
	
	if barre_verte:
		barre_verte.max_value = 100.0
		var tv = create_tween()
		tv.tween_property(barre_verte, "value", pourcentage_vie, 0.2)
	
	if barre_rouge:
		barre_rouge.max_value = 100.0
		var tr = create_tween()
		tr.tween_interval(0.5)
		tr.tween_property(barre_rouge, "value", pourcentage_vie, 0.4).set_trans(Tween.TRANS_SINE)
	
	if Global.pv_actuels <= 0.0:
		sequence_mort_fluide()


func sequence_mort_fluide():
	est_mort = true
	
	if sfx_train_die:
		sfx_train_die.play()
	
	vitesse = 0.0
	acceleration = 800.0
	
	if sfx_mouvement:
		sfx_mouvement.stop()
	
	await get_tree().create_timer(4.0).timeout
	
	if sfx_transition:
		sfx_transition.pitch_scale = 1.0
		sfx_transition.volume_db = 6.0
		sfx_transition.play()
	
	await get_tree().create_timer(3.0).timeout
	
	Global.reset_game_over()
	get_tree().change_scene_to_file("res://background/railway_survival.tscn")


func gerer_audio():
	if est_mort or sequence_tunnel_lancee:
		return
	
	match etat:
		"idle":
			if vitesse > 0:
				etat = "transition_demarrage"
				if sfx_transition:
					sfx_transition.play()
		
		"transition_demarrage":
			if vitesse_reelle >= vitesse:
				etat = "running"
				if sfx_mouvement:
					sfx_mouvement.play()
		
		"running":
			if vitesse_reelle > 0 and sfx_mouvement:
				sfx_mouvement.pitch_scale = vitesse_reelle / 400.0
			
			if vitesse <= 0:
				etat = "transition_arret"
				if sfx_mouvement:
					sfx_mouvement.stop()
				if sfx_transition:
					sfx_transition.play()
		
		"transition_arret":
			if vitesse_reelle <= 0:
				etat = "idle"


func actualiser_label_debug():
	if not label_debug:
		return
	
	label_debug.visible = debug_label_visible
	
	if not debug_label_visible:
		return
	
	label_debug.text = "debug fonctionnement visuel temporaire\n"
	label_debug.text += "-----------------------------------------\n"
	label_debug.text += "SCÈNE : SURFACE\n"
	label_debug.text += "Chrono Biome : " + str(snapped(chrono_biome, 0.1)) + " s\n"
	label_debug.text += "Vitesse Train : " + str(snapped(vitesse_reelle, 1.0)) + " px/s\n"
	label_debug.text += "Palier vitesse : " + debug_palier_vitesse + "\n"
	label_debug.text += "Spawn actif : " + debug_etat_spawn + "\n"
	label_debug.text += "\n"
	label_debug.text += "Ratio temps brut : " + str(snapped(debug_ratio_temps, 0.01)) + "\n"
	label_debug.text += "Taux chrono : " + str(snapped(debug_taux_chrono, 0.01)) + "\n"
	label_debug.text += "Taux vitesse : " + str(snapped(debug_taux_vitesse, 0.01)) + "\n"
	label_debug.text += "Fréquence finale : " + str(snapped(debug_frequence_finale, 0.01)) + "\n"
	
	if chrono_biome <= 0.0 or debug_frequence_finale <= 0.01:
		label_debug.text += "Délai Spawn Global : ARRÊTÉ\n"
	else:
		label_debug.text += "Délai Mouche : "
		if debug_spawn_mouche_actif:
			label_debug.text += "chaque " + str(snapped(delai_spawn_mouche_actuel, 0.1)) + " s\n"
		else:
			label_debug.text += "ARRÊTÉ\n"
		
		label_debug.text += "Délai Moustique : "
		if debug_spawn_moustique_actif:
			label_debug.text += "chaque " + str(snapped(delai_spawn_moustique_actuel, 0.1)) + " s\n"
		else:
			label_debug.text += "ARRÊTÉ\n"
		
		label_debug.text += "Délai Spider : "
		if debug_spawn_spider_actif:
			label_debug.text += "chaque " + str(snapped(delai_spawn_spider_actuel, 0.1)) + " s\n"
		else:
			label_debug.text += "ARRÊTÉ\n"
		
		label_debug.text += "Délai Frelon : "
		if debug_spawn_frelon_actif:
			label_debug.text += "chaque " + str(snapped(delai_spawn_frelon_actuel, 0.1)) + " s\n"
		else:
			label_debug.text += "ARRÊTÉ\n"
	
	label_debug.text += "\n"
	label_debug.text += "Niveau Global : " + str(Global.niveau_actuel) + "\n"
	label_debug.text += "XP Global : " + str(snapped(Global.xp_actuelle, 0.1)) + " / " + str(snapped(Global.xp_requise, 0.1)) + "\n"
	label_debug.text += "Pièces Global : " + str(Global.score_pieces) + "\n"
	label_debug.text += "PV Global : " + str(snapped(Global.pv_actuels, 0.1)) + " / " + str(snapped(Global.pv_max, 0.1)) + "\n"
	label_debug.text += "PV affichés : " + str(snapped(Global.obtenir_pourcentage_vie(), 0.1)) + " %\n"
	label_debug.text += "XP popup accumulée : " + str(snapped(xp_popup_accumulee, 0.1)) + "\n"
	label_debug.text += "Retour grotte : " + str(Global.retour_de_grotte) + "\n"
	
	label_debug.text += "\n"
	label_debug.text += "COMMANDES DEBUG\n"
	label_debug.text += "Entrée : gagner 1 niveau\n"
	label_debug.text += "Espace : infliger 15 dégâts au train\n"
	label_debug.text += "F1 : afficher / cacher ce label\n"
	label_debug.text += "F2 : reset cooldown régulateur\n"


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			basculer_label_debug()
		
		elif event.keycode == KEY_F2:
			if regulateur and regulateur.has_method("reset_cooldown_debug"):
				regulateur.reset_cooldown_debug()
		
		elif event.keycode == KEY_SPACE:
			subir_degats(15)
		
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			monter_niveau()
