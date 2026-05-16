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

@onready var label_debug = get_node_or_null("LabelDebugDev")

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
@export var gain_xp_vitesse : float = 8.0
@export var xp_par_moustique : float = 20.0
@export var distance_pour_une_piece : float = 1000.0

var accumulation_distance : float = 0.0

var etat = "idle"
var est_mort : bool = false

# --- BIOME ---
var chrono_biome : float = 60.0
var transition_grotte_active : bool = false
var grotte_verrouillee : bool = false
var temps_depuis_spawn_moustique : float = 0.0

# --- TRANSITION ---
var rideau_noir : ColorRect
var sequence_tunnel_lancee : bool = false

# --- DEBUG ---
var debug_ratio_temps: float = 0.0
var debug_taux_chrono : float = 0.0
var debug_taux_vitesse : float = 0.0
var debug_frequence_finale : float = 0.0
var delai_spawn_actuel : float = 0.0

func _ready():
	if label_debug:
		label_debug.add_theme_font_size_override("font_size", 12)

	vitesse_reelle = vitesse
	
	placer_decors_depart()
	
	if piece:
		piece.play("run")
	
	creer_systeme_transition_reutilisable()
	mettre_a_jour_ui_complete()

func placer_decors_depart():
	if Global.retour_de_grotte:
		# Retour depuis la grotte : b3 devient l'arche de sortie, inversée.
		if b3:
			b3.visible = true
			b3.scale.x = -1.0
			b3.position.x = centre_x
		
		b1.position.x = centre_x + ecart_parfait
		b2.position.x = centre_x + ecart_parfait * 2.0
		
		Global.retour_de_grotte = false
	else:
		# Départ normal.
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
	gerer_spawn_moustiques(delta)
	gerer_progression(delta)
	gerer_audio()
	actualiser_label_debug()

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

	# Retour depuis la grotte :
	# b3 est en Flip H au début de la surface, puis disparaît après être sorti.
	if b3 and b3.visible and b3.scale.x == -1.0 and b3.position.x <= limite_gauche:
		b3.visible = false
		b3.scale.x = 1.0

	# b1 boucle toujours normalement.
	# Même si le chrono est à 0, b1 ne doit JAMAIS déclencher b3.
	if b1.position.x <= limite_gauche:
		b1.position.x += ecart_parfait * 2.0

	# b2 est le seul bloc autorisé à déclencher b3.
	if b2.position.x <= limite_gauche:
		if chrono_biome <= 0.0 and not transition_grotte_active:
			# On recycle d'abord b2 derrière b1.
			b2.position.x = b1.position.x + ecart_parfait

			# Puis on place b3 derrière b2.
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

func gerer_spawn_moustiques(delta):
	if not moustique_original:
		return
	
	if vitesse_reelle <= 0.1:
		debug_taux_vitesse = 0.0
		debug_frequence_finale = 0.0
		return
	
	if chrono_biome <= 0.0:
		debug_frequence_finale = 0.0
		return
	
	if sequence_tunnel_lancee:
		debug_frequence_finale = 0.0
		return
	
	temps_depuis_spawn_moustique += delta
	
	# 0.0 au début du biome, 1.0 proche de la fin.
	debug_ratio_temps = 1.0 - (chrono_biome / 60.0)
	debug_ratio_temps = clamp(debug_ratio_temps, 0.0, 1.0)
	
	# IMPORTANT :
	# pow(..., 1.8) fait monter la pression plus lentement au début/milieu,
	# puis plus fortement seulement vers la fin.
	var progression_douce: float = pow(debug_ratio_temps, 1.8)
	
	# Taux lié au chrono.
	# Ancien système doux : 0.12 -> 0.34.
	# Tu peux augmenter 0.34 vers 0.40 si c'est trop calme.
	debug_taux_chrono = lerp(0.12, 0.34, progression_douce)
	
	# Taux lié à la vitesse.
	# Si le train ralentit, ça baisse.
	# Si le train s'arrête, c'est 0.
	debug_taux_vitesse = clamp(vitesse_reelle / 400.0, 0.0, 1.5)
	
	# Combo des deux systèmes.
	debug_frequence_finale = debug_taux_chrono * debug_taux_vitesse
	
	if debug_frequence_finale <= 0.01:
		return
	
	delai_spawn_actuel = 1.0 / debug_frequence_finale
	
	# Minimum entre deux apparitions.
	# 1.8 = plus respirable.
	# 1.4 = plus nerveux.
	# 1.1 = trop violent pour ton cas.
	delai_spawn_actuel = max(1.8, delai_spawn_actuel)
	
	if temps_depuis_spawn_moustique >= delai_spawn_actuel:
		temps_depuis_spawn_moustique = 0.0
		cloner_moustique()

func gerer_progression(delta):
	if vitesse_reelle > 0.1 and not grotte_verrouillee and not sequence_tunnel_lancee:
		ajouter_xp((vitesse_reelle / 400.0) * gain_xp_vitesse * delta)
		
		accumulation_distance += vitesse_reelle * delta
		if accumulation_distance >= distance_pour_une_piece:
			gagner_piece()
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
	nettoyer_moustiques()
	
	if sprite_train:
		sprite_train.stop()
	if piece:
		piece.stop()
	
	get_tree().change_scene_to_file("res://grotte.tscn")

func nettoyer_moustiques():
	if not moustique_original:
		return
	
	var parent = moustique_original.get_parent()
	if not parent:
		return
	
	for enfant in parent.get_children():
		if "AreaMoustique" in enfant.name and enfant != moustique_original:
			enfant.queue_free()
	
	moustique_original.visible = false
	moustique_original.position = Vector2(-9999, -9999)

func cloner_moustique():
	if est_mort or chrono_biome <= 0.0 or sequence_tunnel_lancee:
		return
	
	var clone = moustique_original.duplicate()
	moustique_original.get_parent().add_child(clone)
	clone.reinitialiser_position()

func ajouter_xp(montant: float):
	var niveaux_gagnes := Global.ajouter_xp(montant)
	
	if niveaux_gagnes > 0:
		if sfx_xp:
			sfx_xp.play()
		if sfx_xp2:
			sfx_xp2.play()
	
	mettre_a_jour_ui_niveau()

func monter_niveau():
	ajouter_xp(Global.xp_requise)

func mettre_a_jour_ui_complete():
	mettre_a_jour_ui_vie(true)
	mettre_a_jour_ui_niveau()
	mettre_a_jour_ui_pieces(false)

func mettre_a_jour_ui_vie(instant: bool = false):
	if barre_verte:
		barre_verte.max_value = Global.pv_max
	if barre_rouge:
		barre_rouge.max_value = Global.pv_max
	
	if instant:
		if barre_verte:
			barre_verte.value = Global.pv_actuels
		if barre_rouge:
			barre_rouge.value = Global.pv_actuels

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
	ajouter_xp(xp_par_moustique)

func ajuster_vitesse(nouvelle_vitesse):
	if Global.niveau_actuel >= 5:
		vitesse = nouvelle_vitesse
	else:
		print("Commande verrouillée : Niveau 5 requis")

func gagner_piece():
	Global.gagner_piece(1)
	
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
	
	Global.subir_degats(montant)
	
	if barre_verte:
		var tv = create_tween()
		tv.tween_property(barre_verte, "value", Global.pv_actuels, 0.2)
	
	if barre_rouge:
		var tr = create_tween()
		tr.tween_interval(0.5)
		tr.tween_property(barre_rouge, "value", Global.pv_actuels, 0.4).set_trans(Tween.TRANS_SINE)
	
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
	if label_debug:
		label_debug.text = "debug fonctionnement visuel temporaire\n"
		label_debug.text += "-----------------------------------------\n"
		label_debug.text += "SCÈNE : SURFACE\n"
		label_debug.text += "Chrono Biome : " + str(snapped(chrono_biome, 0.1)) + " s\n"
		label_debug.text += "Vitesse Train : " + str(snapped(vitesse_reelle, 1.0)) + " px/s\n"
		label_debug.text += "\n"
		label_debug.text += "Ratio temps brut : " + str(snapped(debug_ratio_temps, 0.01)) + "\n"
		label_debug.text += "Taux chrono : " + str(snapped(debug_taux_chrono, 0.01)) + "\n"
		label_debug.text += "Taux vitesse : " + str(snapped(debug_taux_vitesse, 0.01)) + "\n"
		label_debug.text += "Fréquence finale : " + str(snapped(debug_frequence_finale, 0.01)) + "\n"
		
		if chrono_biome <= 0.0 or debug_frequence_finale <= 0.01:
			label_debug.text += "Délai Spawn Actuel : ARRÊTÉ\n"
		else:
			label_debug.text += "Délai Spawn Actuel : chaque " + str(snapped(delai_spawn_actuel, 0.1)) + " s\n"
		
		label_debug.text += "\n"
		label_debug.text += "Niveau Global : " + str(Global.niveau_actuel) + "\n"
		label_debug.text += "XP Global : " + str(snapped(Global.xp_actuelle, 0.1)) + " / " + str(snapped(Global.xp_requise, 0.1)) + "\n"
		label_debug.text += "Pièces Global : " + str(Global.score_pieces) + "\n"
		label_debug.text += "PV Global : " + str(Global.pv_actuels) + "\n"
		label_debug.text += "Retour grotte : " + str(Global.retour_de_grotte) + "\n"

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			subir_degats(15)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			monter_niveau()
