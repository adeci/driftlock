extends Control

var worlds = "res://scenes/worlds/"
var levels = []
var host_selected_id = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Main.visible = true
	$Host.visible = false
	$Join.visible = false
	$Lobbies.visible = false
	
	var dir = DirAccess.open(worlds)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.contains(".tscn"):
				levels.append(file_name)
			file_name = dir.get_next()
	
	var popup_level = $Main/LevelSelect.get_popup()
	for level in levels:
				popup_level.add_item(level)
	popup_level.id_pressed.connect(
		func(id):
			self.visible = false
			var level = load(worlds+levels[id]).instantiate()
			self.get_parent().add_child(level)
			self.get_parent().single()
	)
	
	var popup_multiplayer = $Main/Multiplayer.get_popup()
	popup_multiplayer.id_pressed.connect(
		func(id):
			$Main.visible = false
			if id:
				$Join.visible = true
			else:
				$Host.visible = true
	)
	
	var level_list = $Host/LevelSelect
	for i in range(levels.size()):
		level_list.add_item(levels[i], i)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_host_back_pressed() -> void:
	$Host.visible = false
	$Join.visible = false
	$Main.visible = true


func _on_host_pressed() -> void:
	self.visible = false
	var level = load(worlds+levels[host_selected_id]).instantiate()
	self.get_parent().add_child(level)
	self.get_parent().host()

func _on_join_pressed() -> void:
	$Main.visible = false
	$Join.visible = false
	if not $Join/ServerIP.text == "":
		self.get_parent().ADDRESS = $Join/ServerIP.text
	$Lobbies.visible = true
	self.get_parent().join()


func _on_host_level_select_item_selected(index: int) -> void:
	host_selected_id = index
