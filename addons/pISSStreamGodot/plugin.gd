@tool
extends EditorPlugin

var toolbar
var progress_bar
var status_label
var websocket: WebSocketPeer
var connection_state = "DISCONNECTED"
var debug_logging = false

const LIGHTSTREAMER_URL = "wss://push.lightstreamer.com/lightstreamer"
const WEBSOCKET_PROTOCOL = "TLCP-2.4.0.lightstreamer.com"

func log_debug(message: String) -> void:
	if debug_logging:
		print("pISS Stream Debug: ", message)

func _enter_tree():
	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size.x = 80

	var progress_container = PanelContainer.new()
	progress_container.custom_minimum_size = Vector2(80, 24)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(80, 24)
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false

	status_label = Label.new()
	status_label.text = "🚀🚽 0%"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	progress_container.add_child(progress_bar)
	progress_container.add_child(status_label)
	toolbar.add_child(progress_container)

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(1, 1, 0, 0.2)
	style_box.border_width_left = 0
	style_box.border_width_right = 0
	style_box.border_width_top = 0
	style_box.border_width_bottom = 0
	progress_bar.add_theme_stylebox_override("fill", style_box)

	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, toolbar)

	websocket = WebSocketPeer.new()
	connect_websocket()

	set_process(true)

func _exit_tree():
	if connection_state == "SUBSCRIBED":
		unsubscribe()
	if websocket:
		websocket.close()
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, toolbar)
	toolbar.free()
	set_process(false)

func connect_websocket():
	var handshake_headers = PackedStringArray([
		"User-Agent: Godot/pISSStream",
		"Sec-WebSocket-Protocol: %s" % WEBSOCKET_PROTOCOL
	])

	websocket.supported_protocols = PackedStringArray([WEBSOCKET_PROTOCOL])
	websocket.handshake_headers = handshake_headers

	var err = websocket.connect_to_url(LIGHTSTREAMER_URL)
	if err != OK:
		log_debug("Failed to connect WebSocket, error code: %s" % err)
		return
	log_debug("Initiating WebSocket connection to %s" % LIGHTSTREAMER_URL)
	connection_state = "CONNECTING"

func create_session():
	var session_msg = "create_session\r\nLS_adapter_set=ISSLIVE&LS_cid=GodotpISSStream%20v1.0&LS_send_sync=false&LS_cause=api\r\n"
	var err = websocket.send_text(session_msg)
	if err != OK:
		log_debug("Send error: %s" % err)
	else:
		log_debug("Sent message: %s" % session_msg.strip_edges())
	connection_state = "SESSION_CREATING"

func subscribe_to_data():
	var subscribe_msg = "control\r\nLS_reqId=1&LS_op=add&LS_subId=1&LS_mode=MERGE&LS_group=NODE3000005&LS_schema=TimeStamp%20Value%20Status.Class%20Status.Indicator%20Status.Color%20CalibratedData&LS_snapshot=true&LS_requested_max_frequency=unlimited&LS_ack=false\r\n"
	var err = websocket.send_text(subscribe_msg)
	if err != OK:
		log_debug("Send error: %s" % err)
	else:
		log_debug("Sent message: %s" % subscribe_msg.strip_edges())

func unsubscribe():
	var unsubscribe_msg = "control\r\nLS_reqId=2&LS_op=delete&LS_subId=1\r\n"
	var err = websocket.send_text(unsubscribe_msg)
	if err != OK:
		log_debug("Send error: %s" % err)
	else:
		log_debug("Sent message: %s" % unsubscribe_msg.strip_edges())

func handle_message(message: String):
	# Split message into lines and process each one
	var lines = message.split("\n", false)
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue

		log_debug("Processing line: %s" % line)

		if line.begins_with("WSOK"):
			if connection_state == "SESSION_CREATING":
				create_session()
			continue

		if line.begins_with("CONOK"):
			if connection_state == "SESSION_CREATING":
				subscribe_to_data()
				connection_state = "SUBSCRIBING"
			continue

		if line.begins_with("SUBOK"):
			if connection_state == "SUBSCRIBING":
				connection_state = "SUBSCRIBED"
				log_debug("Successfully subscribed to data stream")
			continue

		if line.begins_with("ERROR"):
			log_debug("Error received: %s" % line)
			continue

		if line.begins_with("U,1,"):
			var parts = line.split(",", false, 4)
			if parts.size() >= 4:
				var fields = parts[3].split("|")
				if fields.size() >= 2:
					var value = float(fields[1])
					log_debug("Updating progress bar with value: %s" % value)
					update_progress_bar(value)
			continue

		if line.begins_with("PROBE"):
			continue

		if line.begins_with("CONF,"):
			continue

func _process(_delta):
	if not websocket:
		return

	websocket.poll()

	var state = websocket.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			if connection_state == "DISCONNECTED":
				connection_state = "CONNECTING"
				log_debug("WebSocket state changed to CONNECTING")

		WebSocketPeer.STATE_OPEN:
			if connection_state == "CONNECTING":
				log_debug("WebSocket state changed to OPEN")
				websocket.send_text("wsok")
				connection_state = "SESSION_CREATING"
			while websocket.get_available_packet_count():
				var packet = websocket.get_packet()
				var message = packet.get_string_from_utf8()
				handle_message(message)

		WebSocketPeer.STATE_CLOSING:
			if connection_state != "CLOSING":
				connection_state = "CLOSING"
				log_debug("WebSocket state changed to CLOSING")

		WebSocketPeer.STATE_CLOSED:
			var code = websocket.get_close_code()
			var reason = websocket.get_close_reason()
			if connection_state != "DISCONNECTED":
				connection_state = "DISCONNECTED"
				log_debug("WebSocket closed with code: %s, reason: %s" % [code, reason])
				# Wait a bit before reconnecting
				await get_tree().create_timer(1.0).timeout
				connect_websocket()

func update_progress_bar(level: float):
	progress_bar.value = level
	status_label.text = "🚀🚽 %.0f%%" % level

	var style_box = progress_bar.get_theme_stylebox("fill")
	var yellow_intensity = level / 100.0
	style_box.bg_color = Color(1, 1, 0, 0.2 + (0.8 * yellow_intensity))
