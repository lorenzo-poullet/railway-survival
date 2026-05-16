extends Node2D

@onready var decor = get_parent()
@onready var label = $niveau_regulateur

@onready var area_plus = $Vitesse/AreaVitesse
@onready var area_moins = $Frein/AreaFrein

var paliers_vitesse = [0, 200, 400, 800, 1200]
var paliers_noms = ["x0", "x0.50", "x1.00", "x1.50", "x2.00"]
var index_actuel = 2 

var clic_en_cours = false

# --- SÉCURITÉ ANTI-SPAM LOGIQUE ---
var temps_cooldown : float = 21.0 # 21 secondes de blocage total
var minuterie_cooldown : float = 0.0

func _ready():
	decor.vitesse = paliers_vitesse[index_actuel]

func _process(delta):
	# Diminution du verrou temporel
	if minuterie_cooldown > 0.0:
		minuterie_cooldown -= delta
		if minuterie_cooldown < 0.0:
			minuterie_cooldown = 0.0

	var souris_pressee = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Détection des clics uniquement si le régulateur n'est pas bloqué
	if souris_pressee and not clic_en_cours and minuterie_cooldown <= 0.0:
		
		if _souris_sur_area(area_plus):
			if index_actuel < paliers_vitesse.size() - 1:
				var cible = paliers_vitesse[index_actuel + 1]
				decor.ajuster_vitesse(cible)
				
				if decor.vitesse == cible:
					index_actuel += 1
					minuterie_cooldown = temps_cooldown # Déclenchement
			clic_en_cours = true
			
		elif _souris_sur_area(area_moins):
			if index_actuel > 0:
				var cible = paliers_vitesse[index_actuel - 1]
				decor.ajuster_vitesse(cible)
				
				if decor.vitesse == cible:
					index_actuel -= 1
					minuterie_cooldown = temps_cooldown # Déclenchement
			clic_en_cours = true
	
	if not souris_pressee:
		clic_en_cours = false

	# --- AFFICHAGE CONTEXTUEL DU TEXTE ---
	if minuterie_cooldown > 0.0:
		label.text = str(ceil(minuterie_cooldown)) + "s" # Affiche la valeur arrondie (ex: 21s, 20s...)
	else:
		label.text = paliers_noms[index_actuel] # Retour à la normale (ex: x1.00)

func _souris_sur_area(area):
	var mouse_pos = area.get_local_mouse_position()
	for shape_node in area.get_children():
		if shape_node is CollisionShape2D:
			var rect = shape_node.shape.get_rect()
			if rect.has_point(mouse_pos):
				return true
	return false
