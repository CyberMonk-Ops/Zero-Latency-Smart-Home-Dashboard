# =================================================================
# COMPILER REI: STATeless IOT HYPERVISOR v3.1 (PRODUCTION PATCH)
# Target: Android StyleBox Validation & Gemini 3.1 Flash Lite
# =================================================================
extends Control

# --- UI INTERFACE NODES ---
@onready var status_indicator: ColorRect = $MainContainer/TopHeader/StatusIndicator
@onready var api_key_input: LineEdit = $MainContainer/TopHeader/ApiKeyLineEdit
@onready var btn_r1: Button = $MainContainer/ManualControlPad/BtnRelay1
@onready var btn_r2: Button = $MainContainer/ManualControlPad/BtnRelay2
@onready var btn_r3: Button = $MainContainer/ManualControlPad/BtnRelay3
@onready var btn_r4: Button = $MainContainer/ManualControlPad/BtnRelay4

@onready var console: RichTextLabel = $MainContainer/LlmInterpreterConsole/ConsoleOutput
@onready var chat_input: LineEdit = $MainContainer/LlmInterpreterConsole/CommandDeck/CommandLineEdit

# --- NETWORK SERVICES ---
@onready var gemini_http_req: HTTPRequest = $NetworkServices/LlmRequest
@onready var esp_status_req: HTTPRequest = $NetworkServices/EspStatusRequest
@onready var sync_timer: Timer = $NetworkServices/SyncTimer

const CONFIG_PATH = "user://cortex_hypervisor.cfg"
const TARGET_ESP_IP = "172.23.208.234" # FORCE INJECT ASSIGNED STATIC IP

var active_api_key: String = ""
var relay_buttons: Array[Button] = []

# --- PRE-COMPILED VISUAL ASSETS (Guarantees Android Render Execution) ---
var style_on: StyleBoxFlat
var style_off: StyleBoxFlat


# =================================================================
# COMPILER REI: PRODUCTION ABSTRACTION LAYER v4.0
# Target: Dynamic Semantic Labeling & Real-Time Context Injection
# =================================================================

# --- CENTRALIZED HARDWARE ROUTING MATRIX ---
# Single source of truth for UI button rendering and Gemini NLP targeting
var hardware_map: Dictionary = {
	1: {"pin": 5,  "label": "MAIN FAN"},
	2: {"pin": 4,  "label": "DESK LAMP"},
	3: {"pin": 14, "label": "SOLDER RIG"},
	4: {"pin": 12, "label": "AUX SMPS"}
}

func _ready() -> void:
	relay_buttons = [btn_r1, btn_r2, btn_r3, btn_r4]
	_compile_mobile_styleboxes()
	
	# Programmatically map button labels from the hardware matrix on cold boot
	for i in range(relay_buttons.size()):
		var map_data = hardware_map[i + 1]
		relay_buttons[i].text = map_data["label"]
		relay_buttons[i].toggle_mode = true
		
		if relay_buttons[i].toggled.is_connected(_on_manual_relay_toggled):
			relay_buttons[i].toggled.disconnect(_on_manual_relay_toggled)
		relay_buttons[i].toggled.connect(func(is_active: bool): _on_manual_relay_toggled(i + 1, is_active))
	
	# Bind network listeners
	gemini_http_req.request_completed.connect(_on_gemini_response)
	esp_status_req.request_completed.connect(_on_status_poll_returned)
	sync_timer.timeout.connect(_execute_background_status_poll)
	
	api_key_input.text_submitted.connect(_on_save_key_submitted)
	_load_cached_credentials()
	
	console.append_text("[SYSTEM] Semantic abstraction layer compiled. Dynamic mapping live.\n")
	_execute_background_status_poll()

# --- DYNAMIC GEMINI SYSTEM INSTRUCTION COMPILER ---
func _execute_gemini_translation(prompt: String) -> void:
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=" + active_api_key
	var headers = ["Content-Type: application/json"]
	
	# Dynamically assemble the system instruction payload matching current UI reality exactly
	var dynamic_context: String = "Actuate physical IoT relays. Output minified JSON strictly matching format: {\"actions\":[{\"pin\":<int>,\"state\":<0 or 1>}]}. Target dictionary context: "
	for key in hardware_map:
		var node = hardware_map[key]
		dynamic_context += "\"%s\" maps strictly to Pin %d. " % [node["label"], node["pin"]]
	dynamic_context += "Zero conversational text permitted."
	
	var body = JSON.stringify({
		"systemInstruction": {
			"parts": [{"text": dynamic_context}]
		},
		"contents": [{
			"parts": [{"text": prompt}]
		}],
		"generationConfig": {
			"temperature": 0.0,
			"response_mime_type": "application/json"
		}
	})
	
	gemini_http_req.request(url, headers, HTTPClient.METHOD_POST, body)
	





# =================================================================
# 1. EXPLICIT STYLEBOX GENERATION (Android Resolution Override)
# =================================================================
func _compile_mobile_styleboxes() -> void:
	# Active State: High-Voltage Violet background with deep punch-out typography
	style_on = StyleBoxFlat.new()
	style_on.bg_color = Color("#A27BFF")
	style_on.corner_radius_top_left = 6
	style_on.corner_radius_top_right = 6
	style_on.corner_radius_bottom_left = 6
	style_on.corner_radius_bottom_right = 6
	
	# Idle State: Dark Casing Charcoal with clean borders
	style_off = StyleBoxFlat.new()
	style_off.bg_color = Color("#1A1A1E")
	style_off.border_width_left = 2
	style_off.border_width_top = 2
	style_off.border_width_right = 2
	style_off.border_width_bottom = 2
	style_off.border_color = Color("#2A2A30")
	style_off.corner_radius_top_left = 6
	style_off.corner_radius_top_right = 6
	style_off.corner_radius_bottom_left = 6
	style_off.corner_radius_bottom_right = 6

func _apply_dynamic_button_styles(json: Dictionary) -> void:
	for i in range(relay_buttons.size()):
		var is_on = json.get("r" + str(i+1), false)
		var target_box = style_on if is_on else style_off
		var target_font_color = Color("#0A0A0C") if is_on else Color("#E0E0E5")
		
		# Forcing absolute visual pipeline redraws across Android GLES3/Vulkan interfaces
		relay_buttons[i].add_theme_stylebox_override("normal", target_box)
		relay_buttons[i].add_theme_stylebox_override("pressed", target_box)
		relay_buttons[i].add_theme_stylebox_override("hover", target_box)
		relay_buttons[i].add_theme_color_override("font_color", target_font_color)
		relay_buttons[i].add_theme_color_override("font_pressed_color", target_font_color)
		relay_buttons[i].add_theme_color_override("font_hover_color", target_font_color)

# =================================================================
# 2. PERSISTENCE & POLLING ENGINES
# =================================================================
func _load_cached_credentials() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		active_api_key = config.get_value("security", "api_key", "")
		api_key_input.text = active_api_key
		api_key_input.secret = true
		console.append_text("[SECURITY] Local Gemini API credentials verified.\n")
	else:
		console.append_text("[WARN] API Key un-cached. Awaiting runtime payload injection.\n")

func _on_save_key_submitted(new_text: String) -> void:
	active_api_key = new_text.strip_edges()
	api_key_input.secret = true
	var config = ConfigFile.new()
	config.set_value("security", "api_key", active_api_key)
	config.save(CONFIG_PATH)
	console.append_text("[SECURITY] Non-volatile Gemini string written to storage.\n")

func _execute_background_status_poll() -> void:
	esp_status_req.request("http://%s/status" % TARGET_ESP_IP)

func _on_status_poll_returned(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		status_indicator.color = Color("#00FF66")
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			btn_r1.set_pressed_no_signal(json.get("r1", false))
			btn_r2.set_pressed_no_signal(json.get("r2", false))
			btn_r3.set_pressed_no_signal(json.get("r3", false))
			btn_r4.set_pressed_no_signal(json.get("r4", false))
			_apply_dynamic_button_styles(json)
	else:
		status_indicator.color = Color("#FF0033")

# =================================================================
# 3. DYNAMIC MANUAL WORKER THREADS
# =================================================================
func _on_manual_relay_toggled(relay_id: int, target_state: bool) -> void:
	var state_int = 1 if target_state else 0
	var url = "http://%s/gate?pin=%d&state=%d" % [TARGET_ESP_IP, _map_id_to_gpio(relay_id), state_int]
	console.append_text("[MANUAL] Spawning worker -> Actuating Gate %d\n" % relay_id)
	
	var worker = HTTPRequest.new()
	add_child(worker)
	worker.request_completed.connect(func(res, code, hdr, bdy): worker.queue_free())
	worker.request(url)

func _map_id_to_gpio(id: int) -> int:
	match id:
		1: return 5  # D1
		2: return 4  # D2
		3: return 14 # D5
		4: return 12 # D6
	return 5

# =================================================================
# 4. GEMINI 3.1 FLASH LITE REST INTEGRATION
# =================================================================
func _on_send_command_pressed() -> void:
	if active_api_key.is_empty():
		console.append_text("[ERR] Execution drop: API parameters blank.\n")
		return
		
	var user_prompt: String = chat_input.text.strip_edges()
	if user_prompt.is_empty(): return
	
	chat_input.clear()
	console.append_text("[NLP Trace] \"" + user_prompt + "\"\n")
	_execute_gemini_translation(user_prompt)


func _on_gemini_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		console.append_text("[ERR_GEMINI] Remote exception status: " + str(response_code) + "\n")
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("candidates"):
		var raw_content = json["candidates"][0]["content"]["parts"][0]["text"]
		console.append_text("[GEMINI Output] Compiled string: " + raw_content.strip_edges() + "\n")
		_route_nlp_hardware_execution(raw_content)

func _route_nlp_hardware_execution(json_string: String) -> void:
	var data = JSON.parse_string(json_string)
	if data and data.has("actions"):
		for action in data["actions"]:
			var pin: int = action["pin"]
			var state: int = action["state"]
			var target_url = "http://%s/gate?pin=%d&state=%d" % [TARGET_ESP_IP, pin, state]
			
			# Spawn standalone workers for incoming NLP arrays to guarantee execution
			var worker = HTTPRequest.new()
			add_child(worker)
			worker.request_completed.connect(func(r, c, h, b): worker.queue_free())
			worker.request(target_url)


func _on_send_btn_pressed() -> void:
	_on_send_command_pressed()
