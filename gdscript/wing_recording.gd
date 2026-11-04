extends Node
class_name WingRecording

var c: WingConfig
var s: WingState
var vp: Viewport
var record_gif_path := "res://recording/gif/"
var record_screenshot_path := "res://recording/screenshot/"
var temp_gif_path := "res://recording/gif/.temp/"
var frames_captured := 0
var max_frames:int
var time_since_last_frame := 0.0
var current_record:int = 1
var current_screenshot:int = 1

func _init(state: WingState, config: WingConfig, viewport: Viewport) -> void:
	s = state
	c = config
	vp = viewport
	# GIF record setup
	max_frames = int(c.GIF_FPS * c.GIF_DURATION)
	var dir = DirAccess.open(record_gif_path)
	if not dir.dir_exists(".temp"):
		dir.make_dir(".temp")

func start_recording() -> void:
	s.is_recording_gif = true
	frames_captured = 0
	time_since_last_frame = 0.0
	print("Enregistrement des %d prochaines secondes..." % c.GIF_DURATION)

func recording_gif(delta):
	if not s.is_recording_gif:
		return
		
	time_since_last_frame += delta
	
	if time_since_last_frame >= (1.0 / c.GIF_FPS):
		time_since_last_frame = 0.0
		var img = capture_image()
		var path = temp_gif_path + ("frame_%03d.png" % frames_captured)
		img.save_png(path)
		frames_captured += 1
		
		if frames_captured >= max_frames:
			s.is_recording_gif = false
			print("Fin de capture. Création du GIF en cours...")
			
			# Conversion des chemins Godot en chemins absolus pour l'OS
			var input_path := ProjectSettings.globalize_path(path)
			var output_path := ProjectSettings.globalize_path(record_gif_path + "recording%02d.gif" % current_record)
			current_record += 1
			
			var args := [
				"-y", "-f", "image2", "-framerate", str(c.GIF_FPS),
				"-i", input_path,
				output_path
			]
			
			var output := []
			# Lance FFmpeg pour générer le GIF
			OS.execute(s.ffmpeg_path, args, output)
			print("GIF créé et sauvegardé dans : ", output_path)
			var dir := DirAccess.open(temp_gif_path)
			if dir:
				# Récupère tous les fichiers dans le dossier et les supprime un par un
				for file_name in dir.get_files():
					dir.remove(file_name)
			else:
				push_error("Impossible d'accéder au dossier frames pour le nettoyage.")

func screenshot():
	var img = capture_image()
	var path = record_screenshot_path + "screenshot%02d.png" % current_screenshot
	img.save_png(path)
	current_screenshot += 1
	print("Screenshot taken")
	
func capture_image():
	# Récupère l'image rendue à l'écran
	var img: Image = vp.get_texture().get_image()
	# Calcul des nouvelles dimensions (divisées par 3)
	var new_width := int(img.get_width() / 2.0)
	var new_height := int(img.get_height() / 2.0)
	# Redimensionnement avec un filtre bilinéaire pour lisser l'image
	img.resize(new_width, new_height, Image.INTERPOLATE_BILINEAR)
	return img
