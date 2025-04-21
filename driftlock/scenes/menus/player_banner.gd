extends MarginContainer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if self.visible and NetworkManager.player_ping.has(self.name):
		$PlayerInformation/PingContainer/Ping.text = "%d ms" % NetworkManager.player_ping[self.name]
