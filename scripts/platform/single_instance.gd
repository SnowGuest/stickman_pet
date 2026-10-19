class_name SingleInstance
extends RefCounted

const PORTS := [42871, 42872, 42873]

var _server: TCPServer
var port: int = -1


func acquire() -> bool:
	for candidate in PORTS:
		if _has_listener(candidate):
			return false
		var server := TCPServer.new()
		if server.listen(candidate, "127.0.0.1") == OK:
			_server = server
			port = candidate
			return true
		server.stop()
	return false


func _has_listener(candidate: int) -> bool:
	var client := StreamPeerTCP.new()
	if client.connect_to_host("127.0.0.1", candidate) != OK:
		return false
	for i in 12:
		client.poll()
		if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			client.disconnect_from_host()
			return true
		if client.get_status() == StreamPeerTCP.STATUS_ERROR:
			return false
		OS.delay_msec(20)
	return false


func release() -> void:
	if _server != null:
		_server.stop()
		_server = null
		port = -1
