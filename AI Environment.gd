extends Node2D

onready var AI = $AI
onready var snake_game = $SnakeGame

var scores = []
var eps_history = []
var n_games = 500
var i = 0

var last_observation
var last_action
var score = 0
var length = 0
var last_position = Vector2()
var done = true

var tick_length = 1/10.0
var ticks = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set up the vision around the snake
	last_observation = get_observation()

func get_observation():
	var x = snake_game.snake_head.x
	var y = snake_game.snake_head.y

	var min_x = x - 3
	var max_x = x + 3
	var min_y = y - 3
	var max_y = y + 3

	var x_bound = snake_game.game_size.x / snake_game.cell_size.x
	var y_bound = snake_game.game_size.y / snake_game.cell_size.y

	var tiles = []
	tiles.resize(7)
	for i in range(0, 7):
		tiles[i] = []
		tiles[i].resize(7)
		for j in range(0, 7):
			tiles[i][j] = -1

	# Set everything to 0s unless out of bounds
	for i in range(min_x, max_x+1):
		for j in range(min_y,max_y+1):
			if i >= 0 and i < x_bound and j >= 0 and j < y_bound:
				tiles[i-min_x][j-min_y] = 0
			else:
				tiles[i-min_x][j-min_y] = 1
	
	for i in range(0, 7):
		if tiles[i].has(-1):
			print("BAD")

	# Block off tail tiles
	for t in snake_game.snake_tail:
		if t.x >= min_x and t.x < max_x and t.y >= min_y and t.y < max_y:
			tiles[t.x - min_x][t.y - min_y] = 1
	
	# Remove the player space
	var observation = []
	for i in range(0,7):
		for j in range(0,7):
			if i != 4 or j != 4:
				observation.append(tiles[i][j])
	# Now add in the direction to the food
	observation.append(1 if snake_game.snake_head.y > snake_game.food.y else 0)
	observation.append(1 if snake_game.snake_head.y < snake_game.food.y else 0)
	observation.append(1 if snake_game.snake_head.x > snake_game.food.x else 0)
	observation.append(1 if snake_game.snake_head.x < snake_game.food.x else 0)
	observation.append(1 if snake_game.snake_direction == 0 else 0)
	observation.append(1 if snake_game.snake_direction == 1 else 0)
	observation.append(1 if snake_game.snake_direction == 2 else 0)
	observation.append(1 if snake_game.snake_direction == 3 else 0)
	
	return observation

func average(arr):
	var sum = 0
	for a in arr:
		sum += a
	return sum / arr.size()

# Called every frame. 'delta' is the elapsed time since the previous frame.
var _tick_timer = 0
func _process(delta):
	if done:
		var avg_score = 0
		
		# Track stuff
		if i != 0:
			scores.append(score)
			eps_history.append(AI.get_epsilon())
			avg_score = average(scores.slice(scores.size() - 100, scores.size(), 1, false))
			print("Epsiode ", i, " score %.2f " % score, " average score ", avg_score,
				" epsilon ", AI.get_epsilon())
		
		# Reset
		score = 0
		done = false
		snake_game.reset()
		last_observation = get_observation()
		last_action = snake_game.snake_direction
		length = 0
		last_position = snake_game.snake_head
		
		# Show every 100 games
		snake_game.show_display = (i % 50 == 0) or (avg_score > 200)
		
		i += 1
		return
	
	if snake_game.show_display:
		_tick_timer += delta
		if _tick_timer > tick_length:
			_tick_timer -= tick_length
			move_snake(true)
			ticks+=1
	else:
		move_snake(false)
		ticks+=1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func move_snake(update):
	var action = AI.get_action(last_observation)
	
	var old_direction = snake_game.snake_direction
	var new_direction = posmod(int(snake_game.snake_direction) + action - 1, 4)
	snake_game.snake_direction = new_direction
	snake_game.move_snake()
	if update:
		snake_game.update()
	
	var observation = get_observation()
	
	done = snake_game.dead
	
	# Have to calculate reward
	var reward = 0
	if done: # We died
		reward = -100
	# Did we just eat the food
	elif length != snake_game.snake_tail.size():
		reward = 10
		length = snake_game.snake_tail.size()
	else:
		# Compare direction to food location
		var old_dist_to_food = manhattan_dist(last_position,
			snake_game.food) 
		var new_dist_to_food = manhattan_dist(snake_game.snake_head,
			snake_game.food)
		if new_dist_to_food - old_dist_to_food < 0:
			# Closer
			reward = 0.1
		elif new_dist_to_food - old_dist_to_food > 0:
			# Farther
			reward = -0.1
	last_position = snake_game.snake_head
	score += reward
	
	# We use the last_action since the new action we proposed has not happened yet
	AI.store_transition(last_observation, action, reward, observation, done)
	AI.learn()
	last_observation = observation

func manhattan_dist(a, b):
	return abs(a.x - b.x) + abs(a.y - b.y)

func _on_AI_Environment_tree_exiting():
	var file = File.new()
	
	# Get an available file name
	var file_number = 0
	var path = "res://data/data.csv"
	while file.file_exists(path):
		file_number += 1
		path = "res://data/data%d.csv" % file_number
	
	# Compile the data
	var text = ""
	for i in range(0, scores.size()):
		var variables = [
			i, scores[i], eps_history[i]
		]
		text += "%d, %f, %f\n" % variables
	
	# Save to file
	file.open(path, file.WRITE)
	assert(file.is_open())
	file.store_string(text)
	file.close()
