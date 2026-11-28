class_name Tutorial
extends Node

# Runs the tutorial's script: what the merchant says and what it unlocks. Overworld adds one
# when it builds the tutorial (F3 on the title screen).
#
# Talking to the merchant in the start room gets WELCOME (Merchant says it); once it's moved
# on, the start room's lever-locked door opens. Walking into the first room has him speak up
# about the minimap, though he isn't there, and opening that room's chest has him explain
# the key. His remote lines wait for the player to finish walking through a doorway, so the
# box doesn't freeze them mid-step.
#
# The second room is the parry lesson, round a TutorialGoblin that can't hurt the player
# or be beaten out of turn; the room stays locked until it's dead. Walking in, he tells the
# player to attack it (GOBLIN). It blocks; he says to parry instead (NOT_LIKE_THAT), and once
# that's moved on it starts attacking. The moment its parry star shows, the game freezes
# with a Spotlight on the star and STRIKE_NOW; pressing attack (or moving the line on) lets
# the game go, and the goblin stays held in its parry window until it's parried. Then
# DAZED, and the player finishes it off.

const WELCOME: Array[String] = [
	"Welcome to Infinite Labyrinth. [insert story]",
	"I will guide you through some of the basics.",
]
const MINIMAP: Array[String] = [
	"Take a look at your minimap.",
	"You can see the starting and ending rooms in green. Chest rooms are highlighted in yellow.",
]
const KEY: Array[String] = [
	"Oh good, a key!",
	"Normally you'll need two of these to unlock the end door, but for now one will do.",
]
const GOBLIN := "A goblin! Quick, use %s to attack it!" # %s: the attack button
const NOT_LIKE_THAT: Array[String] = ["Not like that! Wait for the right moment then parry its attack!"]
const STRIKE_NOW: Array[String] = ["Strike now!"]
const DAZED: Array[String] = ["Quick, while he's dazed!"]

const MINIMAP_ROOM := 0 # Room id of the first tutorial room, which holds the chest
const PARRY_ROOM := 1 # Room id of the second, with the lesson goblin
const KEY_LINE_DELAY := 0.6 # Seconds after the chest opens, so the key is seen popping out
const ROOM_LINE_DELAY := 0.4 # Seconds after walking into a room, so it's faded in first

var _dialogue: DialogueBox
var _said := {} # Lines already said, so each is said once
# Lines waiting to be said, in order, once the player is free to hear them: each
# {"lines": Array[String], "wait": game seconds before they may start, "then": Callable}.
var _queue: Array[Dictionary] = []
var _then := Callable() # Called once the lines being said are moved on
var _spotlight: Spotlight
var _goblin: TutorialGoblin

# The name of the attack button on the device the player last used, for GOBLIN.
static func attack_button() -> String:
	if InputGlyphs.device() == InputGlyphs.Device.KEYBOARD:
		return Bindings.key_name(Bindings.key_for("melee_attack"))
	return Bindings.pad_label("melee_attack")

func _ready() -> void:
	# Runs while paused, to let an attack press end the frozen STRIKE_NOW moment.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = Merchant.SHOP_LAYER
	add_child(layer)
	_dialogue = DialogueBox.new()
	layer.add_child(_dialogue)
	_dialogue.finished.connect(_on_dialogue_finished)
	Game.room_entered.connect(_on_room_entered)

	var start := Game.room_by_id(Constants.START_ROOM)
	(start.get_node("Merchant") as Merchant).talked.connect(start.release_doors)
	var chest := Game.room_by_id(MINIMAP_ROOM).get_node_or_null("Chest")
	if chest != null:
		chest.opened.connect(_say_once.bind("key", KEY, KEY_LINE_DELAY))
	_goblin = Game.room_by_id(PARRY_ROOM).get_node_or_null("Goblin") as TutorialGoblin
	if _goblin != null:
		_goblin.guarded.connect(_say_once.bind("not like that", NOT_LIKE_THAT, 0.0, _goblin.start_attacking))
		_goblin.twinkled.connect(_freeze_on_star)
		_goblin.dazed.connect(_say_once.bind("dazed", DAZED))

func _process(delta: float) -> void:
	if get_tree().paused || _queue.is_empty():
		return
	var next: Dictionary = _queue[0]
	next["wait"] = float(next["wait"]) - delta
	var player := Game.player
	if float(next["wait"]) > 0.0 || _dialogue.visible || player == null || player.in_transition:
		return
	_queue.pop_front()
	_then = next["then"]
	_say_now(next["lines"])

# Pressing attack while frozen on the parry star lets the game go, and the same press swings.
func _input(event: InputEvent) -> void:
	if _spotlight != null && _dialogue.visible && event.is_action_pressed("melee_attack"):
		_dialogue.close()
		Game.player.queue_swing() # The press came while paused, so the player didn't see it

# True while the merchant has something to say or is saying it.
func is_speaking() -> bool:
	return _dialogue.visible || !_queue.is_empty()

# Queues `lines` to say once, `delay` game seconds from now, then calls `then` once they've
# been moved on. A line already said (by `id`) isn't said again.
func _say_once(id: String, lines: Array[String], delay := 0.0, then := Callable()) -> void:
	if _said.has(id):
		return
	_said[id] = true
	_queue.append({"lines": lines, "wait": delay, "then": then})

func _say_now(lines: Array[String]) -> void:
	Music.play_through_pause(true)
	_dialogue.say(Merchant.NAME, lines)

func _on_dialogue_finished() -> void:
	Music.play_through_pause(false)
	if _spotlight != null:
		_spotlight.hide_light()
		_spotlight = null
	var then := _then
	_then = Callable()
	if then.is_valid():
		then.call()

# The goblin's parry star has just shown: freeze there, light it up and say to strike.
func _freeze_on_star(at: Vector2) -> void:
	if _said.has("strike"):
		return
	_said["strike"] = true
	_spotlight = Spotlight.new()
	add_child(_spotlight)
	_spotlight.show_on(at)
	_say_now(STRIKE_NOW)

func _on_room_entered(id: int) -> void:
	if id == MINIMAP_ROOM:
		_say_once("minimap", MINIMAP, ROOM_LINE_DELAY)
	elif id == PARRY_ROOM && _goblin != null:
		var goblin_line: Array[String] = [GOBLIN % attack_button()]
		_say_once("goblin", goblin_line, ROOM_LINE_DELAY)
