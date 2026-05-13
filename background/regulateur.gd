extends Node2D

@onready var decor = get_parent()
@onready var label = $niveau_regulateur

@onready var area_plus = $Vitesse/AreaVitesse
@onready var area_moins = $Frein/AreaFrein

# Tes paliers de vitesse avec x0 bien défini
var paliers_vitesse = [0, 200, 400, 800, 1200]
var paliers_noms = ["x0", "x0.50", "x1.00", "x1.50", "x2.00"]
var index_actuel = 2 # On commence toujours à 400 (x1.00)

var clic_en_cours = false

func _ready():
	# On synchronise le décor au lancement
	decor.vitesse = paliers_vitesse[index_actuel]

# --- DANS REGULATEUR.GD ---

func _process(_delta):
	var souris_pressee = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	if souris_pressee and not clic_en_cours:
		if _souris_sur_area(area_plus):
			if index_actuel < paliers_vitesse.size() - 1:
				# --- CHANGEMENT ICI ---
				var cible = paliers_vitesse[index_actuel + 1]
				decor.ajuster_vitesse(cible)
				
				# On ne met à jour l'index et le label QUE si le décor a accepté la vitesse
				if decor.vitesse == cible:
					index_actuel += 1
				# ----------------------
			clic_en_cours = true
			
		elif _souris_sur_area(area_moins):
			if index_actuel > 0:
				# --- CHANGEMENT ICI ---
				var cible = paliers_vitesse[index_actuel - 1]
				decor.ajuster_vitesse(cible)
				
				if decor.vitesse == cible:
					index_actuel -= 1
				# ----------------------
			clic_en_cours = true
	
	if not souris_pressee:
		clic_en_cours = false

	# --- AFFICHAGE ---
	# On affiche "x0", "x0.50", etc. selon l'index
	label.text = paliers_noms[index_actuel]

func _souris_sur_area(area):
	var mouse_pos = area.get_local_mouse_position()
	for shape_node in area.get_children():
		if shape_node is CollisionShape2D:
			var rect = shape_node.shape.get_rect()
			if rect.has_point(mouse_pos):
				return true
	return false
