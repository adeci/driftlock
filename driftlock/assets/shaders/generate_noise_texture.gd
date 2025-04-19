@tool
extends EditorScript

func _run():
	# Create a noise texture
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	
	var img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	
	for x in range(256):
		for y in range(256):
			var noise_val = noise.get_noise_2d(x, y) * 0.5 + 0.5
			img.set_pixel(x, y, Color(noise_val, noise_val, noise_val, 1.0))
	
	var texture = ImageTexture.create_from_image(img)
	
	# Save the texture
	var save_path = "res://assets/textures/perlin_noise.tres"
	var err = ResourceSaver.save(texture, save_path)
	if err == OK:
		print("Noise texture saved to " + save_path)
	else:
		print("Failed to save noise texture!")
