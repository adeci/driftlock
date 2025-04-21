@tool
extends Node

enum Item {SPEEDUP, BOOST, JUMP}
enum Level {DEMO, BEACH, DUNGEON}

signal button_pressed(target: String)
signal item_collected(item: Item)
signal item_used()

func generateItem() -> Item:
	return Item.values().pick_random()
