@tool
extends Node

enum Item {SPEEDUP, BOOST, JUMP}
enum Level {DEMO}

signal button_pressed(target: String)

func generateItem() -> Item:
	return Item.values().pick_random()
