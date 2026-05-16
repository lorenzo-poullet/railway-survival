# Global.gd
# À mettre en Autoload avec le nom exact : Global
extends Node

var retour_de_grotte : bool = false

var pv_max : float = 100.0
var pv_actuels : float = 100.0

var score_pieces : int = 0

var niveau_actuel : int = 1
var xp_actuelle : float = 0.0
var xp_requise : float = 100.0

func reset_game_over():
	retour_de_grotte = false
	pv_actuels = pv_max
	score_pieces = 0
	niveau_actuel = 1
	xp_actuelle = 0.0
	xp_requise = 100.0

func ajouter_xp(montant: float) -> int:
	xp_actuelle += montant
	
	var niveaux_gagnes := 0
	
	while xp_actuelle >= xp_requise:
		xp_actuelle -= xp_requise
		niveau_actuel += 1
		xp_requise *= 1.2
		niveaux_gagnes += 1
	
	return niveaux_gagnes

func gagner_piece(nombre: int = 1):
	score_pieces += nombre

func subir_degats(montant: float):
	pv_actuels -= montant
	pv_actuels = clamp(pv_actuels, 0.0, pv_max)
