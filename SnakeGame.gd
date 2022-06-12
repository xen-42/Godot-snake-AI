extends Node2D

export var auto_restart = true
export var allow_inputs = true
export var show_display = true

var dead = false

var game_size = Vector2(400, 400)

var cell_size = Vector2(16, 16)

var snake_head = Vector2()
var snake_direction = DIR.DOWN
var snake_tail = []
var snake_tail_direction = []

var food = Vector2()

enum DIR {LEFT, UP, RIGHT, DOWN}

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	reset()

func reset():
	var middle = int(game_size.x / 2 / cell_size.x)
	snake_head = Vector2(middle, middle) # Start in the middle, in tile coords
	snake_direction = DIR.DOWN
	snake_tail = [Vector2(middle-1,middle), Vector2(middle-2,middle)]
	snake_tail_direction = [DIR.RIGHT, DIR.RIGHT]
	dead = false
	spawn_food()

func _input(event):
	if not allow_inputs:
		return
	
	if Input.is_action_just_pressed("ui_down"):
		snake_direction = DIR.DOWN
	if Input.is_action_just_pressed("ui_up"):
		snake_direction = DIR.UP
	if Input.is_action_just_pressed("ui_left"):
		snake_direction = DIR.LEFT
	if Input.is_action_just_pressed("ui_right"):
		snake_direction = DIR.RIGHT

func move_snake():
	var old_pos = snake_head
	match(snake_direction):
		DIR.DOWN:
			snake_head.y += 1
		DIR.UP:
			snake_head.y -= 1
		DIR.LEFT:
			snake_head.x -= 1
		DIR.RIGHT:
			snake_head.x += 1
	
	# Now update the tail
	var old_dir = snake_direction
	for i in range(0, snake_tail.size()):
		old_pos = snake_tail[i]
		match(snake_tail_direction[i]):
			DIR.DOWN:
				snake_tail[i].y += 1
			DIR.UP:
				snake_tail[i].y -= 1
			DIR.LEFT:
				snake_tail[i].x -= 1
			DIR.RIGHT:
				snake_tail[i].x += 1
		var swap = old_dir
		old_dir = snake_tail_direction[i]
		snake_tail_direction[i] = swap
	
	# Check if its dead
	if snake_head.x < 0 or snake_head.x >= int(game_size.x / cell_size.x):
		on_death()
	if snake_head.y < 0 or snake_head.y >= int(game_size.y / cell_size.y):
		on_death()
	for t in snake_tail:
		if snake_head == t:
			on_death()
	
	# Check if its found food
	if snake_head == food:
		spawn_food()
		snake_tail.append(old_pos)
		snake_tail_direction.append(old_dir)

func on_death():
	if auto_restart:
		reset()
	else:
		dead = true

func spawn_food():
	var x = randi() % int(game_size.x / cell_size.x)
	var y = randi() % int(game_size.x / cell_size.x)
	
	food = Vector2(x, y)
	
	# Make sure its not colliding with something
	if food == snake_head:
		spawn_food()

func _draw():
	var snake_rect = Rect2(snake_head * cell_size, cell_size)
	draw_rect(snake_rect, Color.red, true)
	
	for tail_pos in snake_tail:
		var snake_tail_rect = Rect2(tail_pos * cell_size, cell_size)
		draw_rect(snake_tail_rect, Color.black, true)
	
	var food_rect = Rect2(food * cell_size, cell_size)
	draw_rect(food_rect, Color.green, true)
