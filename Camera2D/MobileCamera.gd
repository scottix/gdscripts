# File: MobileCamera.gd
# Version: v0.1.0
# Author: Scott E
# Email: Atherion@protonmail.com
# LICENSE: MIT
# Features:
# 	Touch and Mouse support
#	AutoDetect touch screen
#	Track target touch and center for multi
#	Track when you add or remove fingers
#	Set max and min zoom level
#	Set pan and zoom speed
# Todo:
#	Limit bounds
extends Camera2D

export(float) var max_zoom = 5
export(float) var min_zoom = 0.25
export(float) var zoom_speed = 1
export(float) var pan_speed = 1

var touchscreen : bool = false
var touches = {}
var touches_info_previous = {}
var touches_info_current = {}
var viewport_size = null
var enable_pan = false

func _ready():
	touchscreen = OS.has_touchscreen_ui_hint()
	viewport_size = get_viewport().size
	if get_viewport().is_size_override_enabled():
		viewport_size = get_viewport().get_size_override()
	print(viewport_size)
	
	reset_touch_info()
	touches_info_previous = touches_info_current.duplicate(true)
	pass
	
func reset_touch_info():
	touches_info_current = {
		"num_points":0,
		"target": null,
		"targetScreen": null,
		"targetCanvas": null,
		"centerScreen": null,
		"centerCanvas": null,
		"radius": null,
		"direction": null,
		"velocity": null
	}

func _unhandled_input(event):
	if touchscreen:
		# We track start, end, and drag of touches
		if event is InputEventScreenTouch && event.is_pressed() == true:
			touches[event.index] = event
		elif event is InputEventScreenTouch && event.is_pressed() == false:
			touches.erase(event.index)
		elif event is InputEventScreenDrag:
			touches[event.index] = event
		
		# Update info about our touches
		update_touches_info()
		
		# If we have velocity lets zoom
		if touches_info_current["velocity"] != null && touches_info_current["velocity"] != 0:
			var touch_speed = Vector2(abs(touches_info_current["velocity"]), abs(touches_info_current["velocity"]))
			zoom_to_point(touches_info_current["centerCanvas"], touches_info_current["direction"], touch_speed * zoom_speed)
		
		if touches_info_current["target"] == touches_info_previous["target"] \
		&& touches_info_current["targetScreen"] != null \
		&& touches_info_previous["targetScreen"] != null:
			# Get the relative diff of the screen
			position += (touches_info_previous["targetScreen"] - touches_info_current["targetScreen"]) * zoom * pan_speed
	else:
		# Mouse down movement for development
		if event is InputEventMouseButton && event.get_button_index() == BUTTON_LEFT && event.is_pressed() == true:
			enable_pan = true
		elif event is InputEventMouseButton && event.get_button_index() == BUTTON_LEFT && event.is_pressed() == false:
			enable_pan = false
		elif event is InputEventMouseButton && event.is_pressed() == false:
			var mouse_pos = get_global_mouse_position()
			if event.get_button_index() == BUTTON_WHEEL_DOWN:
				zoom_to_point(mouse_pos, 1, Vector2(0.1,0.1) * zoom_speed)
			elif event.get_button_index() == BUTTON_WHEEL_UP:
				zoom_to_point(mouse_pos, -1, Vector2(0.1,0.1) * zoom_speed)
	
		# Mouse motion and enable pan is on
		if event is InputEventMouseMotion and enable_pan == true:
			position -= event.get_relative() * zoom * pan_speed

func zoom_to_point(point, direction, speed):
	if point == null or direction == null:
		return

	var offset = (point - position) / zoom
	position += zoom * offset
	zoom += speed * direction
	zoom.x = clamp(zoom.x, min_zoom, max_zoom)
	zoom.y = clamp(zoom.y, min_zoom, max_zoom)
	position += zoom * -offset

func update_touches_info():
	# Set previous touch info
	touches_info_previous = touches_info_current.duplicate(true)
	
	# Reset if empty
	if touches.size() < 1:
		reset_touch_info()
		return null
	
	# Number of touches	
	touches_info_current["num_points"] = touches.size()
	
	# Loop to get the center and get the first target key
	var sum_touch = Vector2(0,0)
	var first_key = null
	for key in touches:
		if first_key == null:
			first_key = key
		sum_touch += touches[key].position
	touches_info_current["centerScreen"] = sum_touch / touches_info_current["num_points"]
	touches_info_current["centerCanvas"] = position + (touches_info_current["centerScreen"] * zoom)
	
	# Set the target touch 
	# tracking the target will allow us to switch touches and to target center as well
	if touches_info_current["num_points"] > 1:
		# We need to uniquely identify number of touches when you have more than 1 touch
		touches_info_current["target"] = "center" + str(touches_info_current["num_points"])
		touches_info_current["targetScreen"] = touches_info_current["centerScreen"]
		touches_info_current["targetCanvas"] = touches_info_current["centerCanvas"]
	else:
		touches_info_current["target"] = str(first_key)
		touches_info_current["targetScreen"] = touches[first_key].position
		touches_info_current["targetCanvas"] = position + (touches_info_current["targetScreen"] * zoom)
	
	if touches_info_current["targetCanvas"] == null \
	|| touches_info_current["target"] != touches_info_previous["target"] \
	|| touches_info_current["num_points"] < 2:
		touches_info_current["radius"] = null
		touches_info_current["direction"] = null
		touches_info_current["velocity"] = null
		
	elif touches_info_current["num_points"] > 1:
		# Will use first_key point as target radius
		# Because if we are tracking target as center then the radius won't change
		touches_info_current["radius"] = (touches[first_key].position - touches_info_current["centerScreen"]).length()
	
		# Now update the direction and velocity of a pinch
		if touches_info_previous["radius"] != null && touches_info_previous["radius"] != 0:
			var diff_radius = touches_info_current["radius"] - touches_info_previous["radius"]
			touches_info_current["direction"] = null
			touches_info_current["velocity"] = null
			if diff_radius > 0:
				touches_info_current["direction"] = -1
				touches_info_current["velocity"] = (touches_info_previous["radius"] - touches_info_current["radius"]) / touches_info_previous["radius"]
			elif diff_radius < 0:
				touches_info_current["direction"] = 1
				touches_info_current["velocity"] = (touches_info_previous["radius"] - touches_info_current["radius"]) / touches_info_previous["radius"]
