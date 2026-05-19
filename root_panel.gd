# =================================================================
# COMPILER REI: SOVEREIGN UNIFIED IOT MASTER ENGINE v5.0
# Target: Dynamic System Prompt Injection, Audio IO & Gemini 3.1 Lite
# =================================================================
extends Control

# --- UI INTERFACE NODES ---
@onready var status_indicator: ColorRect = $MainContainer/TopHeader/StatusIndicator
@onready var api_key_input: LineEdit = $MainContainer/TopHeader/ApiKeyLineEdit

@onready var ipadress_input: LineEdit = $MainContainer/HBoxContainer/ipadress_input



# Manual Control Matrix$MainContainer/LlmInterpreterConsole/CommandDeck/VoiceBtn
@onready var btn_r1: TextureButton =   $MainContainer/ManualControlPad/VBoxContainer/BtnRelay1 #$MainContainer/ManualControlPad/BtnRelay1
@onready var btn_r2: TextureButton =   $MainContainer/ManualControlPad/VBoxContainer2/BtnRelay2  #$MainContainer/ManualControlPad/BtnRelay2
@onready var btn_r3: TextureButton =   $MainContainer/ManualControlPad/VBoxContainer3/BtnRelay3   #$MainContainer/ManualControlPad/BtnRelay3
@onready var btn_r4: TextureButton =   $MainContainer/ManualControlPad/VBoxContainer4/BtnRelay4   # $MainContainer/ManualControlPad/BtnRelay4

# Multimodal Console Layout
@onready var console: RichTextLabel = $MainContainer/LlmInterpreterConsole/ConsoleOutput
@onready var chat_input: LineEdit = $MainContainer/LlmInterpreterConsole/CommandDeck/CommandLineEdit
@onready var txt_send_btn: Button = $MainContainer/LlmInterpreterConsole/CommandDeck/SendBtn
@onready var voice_btn: Button = $MainContainer/LlmInterpreterConsole/CommandDeck/VoiceBtn

# --- NETWORK & AUDIO DAEMONS ---
@onready var gemini_http_req: HTTPRequest = $NetworkServices/LlmRequest
@onready var sync_timer: Timer = $NetworkServices/SyncTimer

@onready var sync_timer2: Timer = $NetworkServices/Timer


const CONFIG_PATH = "user://cortex_hypervisor.cfg"

const ipstorage_path = "user://cortex_ipadress.cfg"

var FALLBACK_ESP_IP: String = "000.00.000.000"
var TARGET_ESP_IP = FALLBACK_ESP_IP # VERIFY ABSOLUTE STATIC IP

var active_api_key: String = ""
var relay_buttons = []
#: Array[]
# --- AUDIO CAPTURE REGISTERS ---
var record_effect: AudioEffectRecord
var record_bus_index: int = 0

# --- DYNAMIC HARDWARE STATE TRACKING DICTIONARY ---
# Intercepts reality to feed the System Instruction Prompt dynamically
var current_hardware_state: Dictionary = {
	"r1": false,
	"r2": false,
	"r3": false,
	"r4": false
}

# --- PRE-COMPILED VISUAL ASSETS (Android Render Enforcement) ---
var style_on: StyleBoxFlat
var style_off: StyleBoxFlat
var style_voice_active: StyleBoxFlat

# Add these scoped bindings to your root script node declarations
var udp_peer: PacketPeerUDP = PacketPeerUDP.new()
const BROADCAST_PORT: int = 4210
var is_scanning: bool = false

var discovery_attempts: int = 0
var max_discovery_attempts: int = 12# Allocate up to 2 seconds of total scan frames

var hidden_tap_coutn : int = 0
var last_tap_time : int = 0 


# --- CUSTOM NAME LABELS ---
@onready var label_r1: LineEdit =$MainContainer/ManualControlPad/VBoxContainer/LineEdit     # $MainContainer/ManualControlPad/LabelR1
@onready var label_r2: LineEdit = $MainContainer/ManualControlPad/VBoxContainer2/LineEdit     #$MainContainer/ManualControlPad/LabelR2
@onready var label_r3: LineEdit = $MainContainer/ManualControlPad/VBoxContainer3/LineEdit   # $MainContainer/ManualControlPad/LabelR3
@onready var label_r4: LineEdit =   $MainContainer/ManualControlPad/VBoxContainer4/LineEdit  #$MainContainer/ManualControlPad/LabelR4

# --- PRELOAD YOUR PIXEL ART TEXTURES ---
# (Change these paths to wherever you saved your PNGs)
var tex_switch_on = preload("res://assets/switch_on.png")
var tex_switch_off = preload("res://assets/switch_off.png")


const LABELS_CONFIG_PATH = "user://cortex_labels0.cfg"



# Stores the network map dynamically: {"MAIN_BEDROOM": "192.168.1.5", "KITCHEN": "192.168.1.6"}
var discovered_nodes: Dictionary = {}


@onready var room_selector: OptionButton = $MainContainer/TopHeader/roomselecter
const NETWORK_CONFIG_PATH = "user://cortex_network.cfg"

var last_active_room: String = ""


func _ready() -> void:
	relay_buttons = [btn_r1, btn_r2, btn_r3, btn_r4]
	_compile_mobile_styleboxes()
	
	# 1. Request Android Core Hardware Audio Mapping
	if OS.get_name() == "Android":
		OS.request_permission("RECORD_AUDIO")
		
	# 2. Assign Audio Bus Registers
	record_bus_index = AudioServer.get_bus_index("Record")
	record_effect = AudioServer.get_bus_effect(record_bus_index, 0) as AudioEffectRecord
	
	# 3. Explicit Programmatic Manual Button Override Logic
	for i in range(relay_buttons.size()):
		relay_buttons[i].toggle_mode = true
		if relay_buttons[i].toggled.is_connected(_on_manual_relay_toggled):
			relay_buttons[i].toggled.disconnect(_on_manual_relay_toggled)
		relay_buttons[i].toggled.connect(func(is_active: bool): _on_manual_relay_toggled(i + 1, is_active))
	
	# 4. Network Gateway Bindings
	gemini_http_req.request_completed.connect(_on_gemini_response)
	sync_timer.timeout.connect(_execute_background_status_poll)
	
	# 5. Interface Control Routing
	ipadress_input.text_submitted.connect(_on_ip_key_submitted)
	api_key_input.text_submitted.connect(_on_save_key_submitted)
	txt_send_btn.pressed.connect(_on_txt_command_submitted)
	voice_btn.button_down.connect(_on_voice_capture_started)
	voice_btn.button_up.connect(_on_voice_capture_terminated)
	
	_load_cached_credentials()
	console.append_text("[SYSTEM] Sovereign Gateway v5.0 Live. Dynamic mapping injection online.\n")
	_execute_background_status_poll()
	
	#_execute_network_discovery_sweep()
	_initialize_hybrid_discovery()
	
	 # Connect LineEdits so they save instantly when you type and hit enter
	label_r1.text_submitted.connect(func(t): _save_custom_names())
	label_r2.text_submitted.connect(func(t): _save_custom_names())
	label_r3.text_submitted.connect(func(t): _save_custom_names())
	label_r4.text_submitted.connect(func(t): _save_custom_names())
	
	# Connect LineEdits so they save if the user clicks away (loses focus)
	label_r1.focus_exited.connect(_save_custom_names)
	label_r2.focus_exited.connect(_save_custom_names)
	label_r3.focus_exited.connect(_save_custom_names)
	label_r4.focus_exited.connect(_save_custom_names)
	
	#_load_custom_names()
	
	room_selector.item_selected.connect(_on_room_selected)
	_load_network_map()



	# ... rest of your existing _ready() code ...

# =================================================================
# 1. VISUAL STYLE OVERRIDES (Android Layout Isolation)
# =================================================================
func _compile_mobile_styleboxes() -> void:
	style_on = StyleBoxFlat.new()
	style_on.bg_color = Color("#A27BFF")
	style_on.set_corner_radius_all(6)
	
	style_off = StyleBoxFlat.new()
	style_off.bg_color = Color("#1A1A1E")
	#style_off.icon = preload("res://Project (20260517075435).png")
	style_off.set_border_width_all(2)
	style_off.border_color = Color("#2A2A30")
	style_off.set_corner_radius_all(6)
	
	style_voice_active = StyleBoxFlat.new()
	style_voice_active.bg_color = Color("#FF0055")
	style_voice_active.set_corner_radius_all(6)

#func _apply_dynamic_button_styles() -> void:
	#for i in range(relay_buttons.size()):
		#var is_on: bool = current_hardware_state["r" + str(i+1)]
		#var target_box = style_on if is_on else style_off
		#var target_font_color = Color("#0A0A0C") if is_on else Color("#E0E0E5")
		#
		#relay_buttons[i].add_theme_stylebox_override("normal", target_box)
		#relay_buttons[i].add_theme_stylebox_override("pressed", target_box)
		#relay_buttons[i].add_theme_stylebox_override("hover", target_box)
		#relay_buttons[i].add_theme_color_override("font_color", target_font_color)
		#relay_buttons[i].add_theme_color_override("font_pressed_color", target_font_color)
		#relay_buttons[i].add_theme_color_override("font_hover_color", target_font_color)

# =================================================================
# 2. CONTINUOUS HARDWARE POLLING & STATE EXTRACTION
# =================================================================
func _execute_background_status_poll() -> void:
	# Stateless dynamic polling to guarantee TCP queue stability
	var worker = HTTPRequest.new()
	add_child(worker)
	worker.request_completed.connect(func(res, code, hdr, bdy):
		if code == 200:
			status_indicator.color = Color("#00FF66")
			var json = JSON.parse_string(bdy.get_string_from_utf8())
			if json:
				# Update local dictionary tracking state natively
				current_hardware_state["r1"] = json.get("r1", false)
				current_hardware_state["r2"] = json.get("r2", false)
				current_hardware_state["r3"] = json.get("r3", false)
				current_hardware_state["r4"] = json.get("r4", false)
				
				# Push mirror updates to UI buttons strictly without signal triggering
				btn_r1.set_pressed_no_signal(current_hardware_state["r1"])
				btn_r2.set_pressed_no_signal(current_hardware_state["r2"])
				btn_r3.set_pressed_no_signal(current_hardware_state["r3"])
				btn_r4.set_pressed_no_signal(current_hardware_state["r4"])
				_apply_dynamic_button_styles()
		else:
			status_indicator.color = Color("#FF0033")
		worker.queue_free()
	)
	worker.request("http://%s/status" % TARGET_ESP_IP)

# =================================================================
# 3. DYNAMIC SYSTEM INSTRUCTION PROMPT GENERATOR
# =================================================================
func _build_dynamic_system_context() -> String:
	# CRITICAL INTERPOLATION: Parse the dictionary directly into the instruction headers
	var base_context: String = "You actuate physical IoT relays. Output minified JSON strictly matching format: {\"actions\":[{\"pin\":<int>,\"state\":<0 or 1>}]}. Output zero conversational text.\n"
	base_context += "--- ACTIVE HARDWARE MAPPING REALITY ---\n"
	base_context += "Relay 1 (Pin 5)  [Desk Lamp]       -> Current State: " + ("ACTIVE (1)" if current_hardware_state["r1"] else "IDLE (0)") + "\n"
	base_context += "Relay 2 (Pin 4)  [Solder Station]  -> Current State: " + ("ACTIVE (1)" if current_hardware_state["r2"] else "IDLE (0)") + "\n"
	base_context += "Relay 3 (Pin 14) [Ceiling Fan]      -> Current State: " + ("ACTIVE (1)" if current_hardware_state["r3"] else "IDLE (0)") + "\n"
	base_context += "Relay 4 (Pin 12) [Aux SMPS]        -> Current State: " + ("ACTIVE (1)" if current_hardware_state["r4"] else "IDLE (0)") + "\n"
	base_context += "Evaluate natural intent against this exact physical state table before returning action arrays."
	return base_context

# =================================================================
# 4. MULTIMODAL AUDIO IO DAEMONS (Hold-to-Speak Engine)
# =================================================================
func _on_voice_capture_started() -> void:
	if active_api_key.is_empty():
		console.append_text("[ERR] Capture drop: Authentication parameters un-cached.\n")
		return
		
	voice_btn.add_theme_stylebox_override("normal", style_voice_active)
	voice_btn.text = "RECORDING..."
	console.append_text("[AUDIO] Initializing PCM sample collection array...\n")
	record_effect.set_recording_active(true)

func _on_voice_capture_terminated() -> void:
	record_effect.set_recording_active(false)
	voice_btn.remove_theme_stylebox_override("normal")
	voice_btn.text = "HOLD TO SPEAK"
	
	var recording: AudioStreamWAV = record_effect.get_recording()
	if not recording or recording.data.is_empty():
		console.append_text("[WARN] Audio buffer input threshold dropped.\n")
		return
		
	console.append_text("[AUDIO] WAV array captured. Executing Marshalls Base64 transformation...\n")
	var base64_audio_string: String = Marshalls.raw_to_base64(recording.data)
	_execute_multimodal_gemini_call(base64_audio_string)

# =================================================================
# 5. GEMINI 3.1 FLASH LITE COMPILATION INTERFACE
# =================================================================
func _on_txt_command_submitted() -> void:
	var prompt = chat_input.text.strip_edges()
	if prompt.is_empty(): return
	chat_input.clear()
	console.append_text("[USER] \"" + prompt + "\"\n")
	_execute_text_only_gemini_call(prompt)

func _execute_text_only_gemini_call(prompt: String) -> void:
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=" + active_api_key
	var body = JSON.stringify(_build_payload_wrapper([{"parts": [{"text": prompt}]}]))
	gemini_http_req.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

func _execute_multimodal_gemini_call(base64_audio: String) -> void:
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=" + active_api_key
	var content_payload = [{
		"parts": [
			{"inlineData": {"mimeType": "audio/wav", "data": base64_audio}},
			{"text": "Parse this spoken control command against the provided state table."}
		]
	}]
	var body = JSON.stringify(_build_payload_wrapper(content_payload))
	gemini_http_req.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

func _build_payload_wrapper(contents_array: Array) -> Dictionary:
	# Injecting the dynamically pre-compiled context string instantly
	var dynamic_context: String = _build_dynamic_system_context()
	return {
		"systemInstruction": {"parts": [{"text": dynamic_context}]},
		"contents": contents_array,
		"generationConfig": {
			"temperature": 0.0,
			"response_mime_type": "application/json"
		}
	}

func _on_gemini_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		console.append_text("[ERR_GEMINI] Remote exception status: " + str(response_code) + "\n")
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("candidates"):
		var raw_content = json["candidates"][0]["content"]["parts"][0]["text"]
		console.append_text("[INFERENCE] Extracted output string: " + raw_content.strip_edges() + "\n")
		_route_hardware_execution(raw_content)

# =================================================================
# 6. MANUAL OVERRIDE ROUTERS & DISPATCHERS
# =================================================================
func _route_hardware_execution(json_string: String) -> void:
	var data = JSON.parse_string(json_string)
	if data and data.has("actions"):
		for action in data["actions"]:
			var target_pin: int = action["pin"]
			var target_state: int = action["state"]
			# Dynamic execution worker completely prevents TCP interface stalls
			var worker = HTTPRequest.new()
			add_child(worker)
			worker.request_completed.connect(func(r,c,h,b): worker.queue_free())
			worker.request("http://%s/gate?pin=%d&state=%d" % [TARGET_ESP_IP, target_pin, target_state])
			


func _on_manual_relay_toggled(r_id: int, state: bool) -> void:
	# 1. THE OPTIMISTIC OVERRIDE: Instantly lie to the UI so it feels lightning fast
	current_hardware_state["r" + str(r_id)] = state
	_apply_dynamic_button_styles()

	# 2. THE ANTI-SPAM LOCK: Temporarily disable the Godot button
	var target_btn = relay_buttons[r_id - 1]
	target_btn.disabled = true
	sync_timer.stop()

	# 3. THE NETWORK WORKER: Dispatch the actual command to the ESP8266
	var worker = HTTPRequest.new()
	add_child(worker)
	worker.request_completed.connect(func(result, code, headers, body):
		# 4. THE UNLOCK: Re-enable the button the millisecond the ESP responds
		target_btn.disabled = false
		sync_timer.start(2.5)
		worker.queue_free()
	)
	
	# Fire the payload
	worker.request("http://%s/gate?pin=%d&state=%d" % [TARGET_ESP_IP, _map_id_to_gpio(r_id), 1 if state else 0])


#func _on_manual_relay_toggled(r_id: int, state: bool) -> void:
	#current_hardware_state["r"+str(r_id)]= state
	#_apply_dynamic_button_styles()
	#var target_btn = relay_buttons[r_id-1]
	#target_btn.disabled=true
	#var worker = HTTPRequest.new()
	#add_child(worker)
	#worker.request_completed.connect(func(r,c,h,b):  worker.queue_free())
	#worker.request("http://%s/gate?pin=%d&state=%d" % [TARGET_ESP_IP, _map_id_to_gpio(r_id), 1 if state else 0])

func _map_id_to_gpio(id: int) -> int:
	match id:
		1: return 5
		2: return 4
		3: return 14
		4: return 12
	return 5

# =================================================================
# 7. PERSISTENCE INGESTION HANDLERS
# =================================================================
func _load_cached_credentials() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		active_api_key = config.get_value("security", "api_key", "")
		api_key_input.text = active_api_key
		api_key_input.secret = true
	else:
		console.append_text("[WARN] Credentials un-cached. Awaiting runtime API key insertion.\n")
		
	var config2 = ConfigFile.new()
	if config2.load(ipstorage_path) == OK:
		FALLBACK_ESP_IP = config2.get_value("security", "api_key", "")
		ipadress_input.text = FALLBACK_ESP_IP
		#api_key_input.secret = true
	else:
		console.append_text("[WARN] Credentials un-cached. Awaiting fallback esp ip adress insertion.\n")
		

func _on_save_key_submitted(new_text: String) -> void:
	active_api_key = new_text.strip_edges()
	api_key_input.secret = true
	var config = ConfigFile.new()
	config.set_value("security", "api_key", active_api_key)
	config.save(CONFIG_PATH)


func _on_ip_key_submitted(new_text: String) -> void:
	
	active_api_key = new_text.strip_edges()
	#api_key_input.secret = true
	var config = ConfigFile.new()
	config.set_value("security", "api_key", active_api_key)
	config.save(ipstorage_path)
	
	

func _execute_network_discovery_sweep() -> void:
	console.append_text("[DISCOVERY] Broadcasting UDP probe across local subnet...\n")
	status_indicator.color = Color("#FFCC00") # Scanning / Unbound Amber
	
	udp_peer.set_broadcast_enabled(true)
	udp_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	
	var err = udp_peer.put_packet("CORTEX_WHOAMI".to_utf8_buffer())
	if err == OK:
		is_scanning = true
		# Temporarily hijack the SyncTimer to await incoming network handshakes
		#sync_timer2.timeout.disconnect(_execute_background_status_poll)
		if not sync_timer2.timeout.is_connected(_listen_for_udp_reply):
			sync_timer2.timeout.connect(_listen_for_udp_reply)
		sync_timer2.start(0.5) # Fast 500ms discovery evaluation loop

func _listen_for_udp_reply() -> void:
	if udp_peer.get_available_packet_count() > 0:
		var packet = udp_peer.get_packet().get_string_from_utf8()
		var sender_ip = udp_peer.get_packet_ip()
		
		if packet.begins_with("CORTEX_NODE_IP:"):
			is_scanning = false
			# Extract target string dynamically
			var extracted_ip = packet.split(":")[1].strip_edges()
			console.append_text("[DISCOVERY SUCCESS] Switchboard bound to Dynamic IP: " + extracted_ip + "\n")
			
			# Hijack internal pointer parameters permanently
			set("TARGET_ESP_IP", extracted_ip) # Dynamically overwrites constant context
			
			# Close un-shielded UDP loopback and restore primary HTTP polling daemons
			udp_peer.close()
			sync_timer2.stop()
			#sync_timer2.timeout.disconnect(_listen_for_udp_reply)
			#sync_timer2.timeout.connect(_execute_background_status_poll)
			sync_timer2.start(2.5) # Restore baseline status poll loop speed
			_execute_background_status_poll()





# =================================================================
# COMPILER REI: STATeless IOT HYPERVISOR v5.2 (OMNI-SWEEP PATCH)
# Target: Dynamic Multi-Adapter Sweep & Zero-Truncation Handshakes
# =================================================================

# =================================================================
# 1. NETWORK AUTO-DISCOVERY (Omnidirectional Local Sweep)
# =================================================================
func _initialize_hybrid_discovery() -> void:
	status_indicator.color = Color("#FFCC00")
	console.append_text("[NETWORK] Executing brute-force unicast sweep...\n")
	
	if udp_peer.bind(BROADCAST_PORT) != OK:
		console.append_text("[WARN] Discovery port desync detected.\n")
		
	var probes_fired: int = 0
	var base_subnet: String = ""
	
	# 1. Find the active hotspot subnet
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			if not ip.ends_with(".1"): # Ignore router IPs
				var octets = ip.split(".")
				if octets.size() == 4:
					base_subnet = "%s.%s.%s." % [octets[0], octets[1], octets[2]]
					break # Lock onto the first valid local network
					
	if base_subnet != "":
		console.append_text("[ROUTING] Carpet bombing subnet: " + base_subnet + "X\n")
		# 2. Fire a direct UDP packet to every possible device on the network
		for i in range(1, 255):
			var target_ip = base_subnet + str(i)
			udp_peer.set_dest_address(target_ip, BROADCAST_PORT)
			if udp_peer.put_packet("CORTEX_WHOAMI".to_utf8_buffer()) == OK:
				probes_fired += 1
				
	if probes_fired > 0:
		discovery_attempts = 0
		if sync_timer.timeout.is_connected(_execute_background_status_poll):
			sync_timer.timeout.disconnect(_execute_background_status_poll)
		if not sync_timer.timeout.is_connected(_poll_udp_listener):
			sync_timer.timeout.connect(_poll_udp_listener)
		sync_timer.start(0.5) 
	else:
		_execute_static_fallback()
		




func _poll_udp_listener() -> void:
	discovery_attempts += 1
	
	# Instant absolute buffer drain
	while udp_peer.get_available_packet_count() > 0:
		var packet = udp_peer.get_packet().get_string_from_utf8()
		
		# NEW PARSER: Intercepts CORTEX_NODE:ROOM_NAME|IP_ADDRESS
		if packet.begins_with("CORTEX_NODE:"):
			var payload = packet.split(":")[1].strip_edges() # Extracts "MAIN_BEDROOM|192.168.1.5"
			var parts = payload.split("|")
			
			if parts.size() == 2:
				var hardware_id = parts[0]
				var resolved_ip = parts[1]
				
				# Add it to the dynamic network dictionary if it's new
				if not discovered_nodes.has(hardware_id):
					discovered_nodes[hardware_id] = resolved_ip
					console.append_text("[DISCOVERY] Locked Node -> " + hardware_id + " at " + resolved_ip + "\n")
					_save_network_map()
				_refresh_ui_dropdown()
				
				# For this exact moment, bind the app to the first node it finds
				# (We will build the UI buttons to switch between dictionary IPs next)
				TARGET_ESP_IP = resolved_ip
				_on_ip_key_submitted(resolved_ip)
				_terminate_discovery_session()
				return # Matrix locked. Terminate the listener immediately.
			
	if discovery_attempts >= max_discovery_attempts:
		console.append_text("[WARN] Subnet sweep timeout. Hardware dropping UDP payloads.\n")
		_execute_static_fallback()






func _execute_static_fallback() -> void:
	console.append_text("[FALLBACK] Overriding core memory to validated target trace -> " + FALLBACK_ESP_IP + "\n")
	TARGET_ESP_IP = FALLBACK_ESP_IP
	_terminate_discovery_session()

func _terminate_discovery_session() -> void:
	udp_peer.close()
	sync_timer.stop()
	if sync_timer.timeout.is_connected(_poll_udp_listener):
		sync_timer.timeout.disconnect(_poll_udp_listener)
		
	sync_timer.timeout.connect(_execute_background_status_poll)
	sync_timer.start(2.5) # Restore primary production status polling loop speed
	_execute_background_status_poll()


func _on_button_pressed() -> void:
	var current_time = Time.get_ticks_msec()
	if current_time - last_tap_time < 500 :
		hidden_tap_coutn +=1
	else :
		hidden_tap_coutn =1
		
		
	last_tap_time = current_time
	if hidden_tap_coutn >= 5:
		$MainContainer/LlmInterpreterConsole/ConsoleOutput.visible = !$MainContainer/LlmInterpreterConsole/ConsoleOutput.visible
		#$MainContainer/HBoxContainer.visible != $MainContainer/HBoxContainer.visible
		hidden_tap_coutn=0 # Replace with function body.
	
	


# =================================================================
# VISUAL TEXTURE SWAPPING OVERRIDES
# =================================================================
func _apply_dynamic_button_styles() -> void:
	for i in range(relay_buttons.size()):
		var is_on: bool = current_hardware_state["r" + str(i+1)]
		
		# Dynamically inject the correct pixel art based on hardware state
		if is_on:
			
			relay_buttons[i].texture_normal = tex_switch_on
			relay_buttons[i].texture_pressed = tex_switch_on 
			relay_buttons[i].modulate = Color(1.0,1.0,1.0,1.0)# Keep it stable when tapped
		else:
			relay_buttons[i].texture_normal = tex_switch_off
			relay_buttons[i].texture_pressed = tex_switch_off
			relay_buttons[i].modulate = Color(0.5,0.5,0.5,1.0)

# =================================================================
# PERSISTENCE INGESTION FOR CUSTOM NAMES
# =================================================================

func _save_custom_names() -> void:
	if last_active_room == "": return # Safety check
	
	var config = ConfigFile.new()
	config.load(LABELS_CONFIG_PATH) # Load first to preserve other rooms!
	
	# Save the labels under the exact room name (e.g., [MAIN_BEDROOM])
	config.set_value(last_active_room, "r1", label_r1.text.strip_edges())
	config.set_value(last_active_room, "r2", label_r2.text.strip_edges())
	config.set_value(last_active_room, "r3", label_r3.text.strip_edges())
	config.set_value(last_active_room, "r4", label_r4.text.strip_edges())
	
	if config.save(LABELS_CONFIG_PATH) == OK:
		console.append_text("[SYSTEM] UI nomenclature etched to " + last_active_room + ".\n")
		
func _load_custom_names(room_id: String) -> void:
	if room_id == "": return
	
	var config = ConfigFile.new()
	if config.load(LABELS_CONFIG_PATH) == OK:
		print('yey')
		label_r1.text = config.get_value(room_id, "r1", "LIGHT")
		label_r2.text = config.get_value(room_id, "r2", "DESK LIGHT")
		label_r3.text = config.get_value(room_id, "r3", "FAN")
		label_r4.text = config.get_value(room_id, "r4", "PLUG")
	else:
		# Failsafe Defaults
		label_r1.text = "LIGHT"
		label_r2.text = "DESK LIGHT"
		label_r3.text = "FAN"
		label_r4.text = "PLUG"
  



func _save_network_map() -> void:
	var config = ConfigFile.new()
	config.set_value("network", "nodes", discovered_nodes)
	
	# CRITICAL: Save the currently selected room text so we don't forget it
	if room_selector.item_count > 0:
		config.set_value("network", "last_room", room_selector.get_item_text(room_selector.selected))
		
	config.save(NETWORK_CONFIG_PATH)

func _load_network_map() -> void:
	var config = ConfigFile.new()
	if config.load(NETWORK_CONFIG_PATH) == OK:
		discovered_nodes = config.get_value("network", "nodes", {})
		last_active_room = config.get_value("network", "last_room", "") # Pull the last room
		console.append_text("[SYSTEM] Network map and last active room recovered.\n")
		_refresh_ui_dropdown()
		
		
		
		
		
func _refresh_ui_dropdown() -> void:
	room_selector.clear()
	var current_index = 0
	var target_index = 0
	
	for room_name in discovered_nodes.keys():
		room_selector.add_item(room_name)
		# Find the index of the room we want to restore
		if room_name == last_active_room:
			target_index = current_index
		current_index += 1
		
	if discovered_nodes.size() > 0:
		# Force the UI to visually select the correct room
		room_selector.select(target_index)
		
		# Lock the network target
		var current_room = room_selector.get_item_text(target_index)
		TARGET_ESP_IP = discovered_nodes[current_room]
		
		# Force an immediate status poll so the buttons sync instantly
		_execute_background_status_poll()
		_load_custom_names(last_active_room)
		
		







func _on_room_selected(index: int) -> void:
	var selected_room = room_selector.get_item_text(index)
	TARGET_ESP_IP = discovered_nodes[selected_room]
	console.append_text("[ROUTING] Switched active interface to: " + selected_room + "\n")
	
	last_active_room=selected_room
	# Instantly fetch the hardware state of the newly selected room
	_execute_background_status_poll() 
	_save_network_map()
	_load_custom_names(last_active_room)
