extends SceneTree

## 测试入口占位。
##
## 目前还没有正式的测试套件；后续接入 GUT 或 gdUnit4 时，
## 在这里遍历 res://tests/test_*.gd 并返回失败数。
func _initialize() -> void:
	print("[tests] no test suites yet (placeholder)")
	quit(0)
