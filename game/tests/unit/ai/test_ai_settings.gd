extends "res://tests/test_case.gd"

const AiSettings = preload("res://ai/ai_settings.gd")

const PATH := "user://test_ai_settings.json"


func before_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_defaults() -> void:
	var s := AiSettings.defaults()
	assert_eq(s["provider"], "anthropic")
	assert_eq(s["tiers"]["strong"]["model"], "claude-opus-5-5")
	assert_eq(s["tiers"]["fast"]["model"], "claude-haiku-5-5")
	assert_true(bool(s["tiers"]["strong"]["fallbacks"]))
	assert_false(bool(s["tiers"]["fast"]["fallbacks"]))


func test_missing_file_gives_defaults() -> void:
	assert_eq(AiSettings.load_settings(PATH), AiSettings.defaults())


## 文件里的值覆盖默认值，tiers 按档合并。
func test_save_and_merge() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"provider": "openai_compatible", "base_url": "https://gw.example/v1", "tiers": {"fast": {"model": "my-fast-model"}}}))
	f.close()
	var s := AiSettings.load_settings(PATH)
	assert_eq(s["provider"], "openai_compatible")
	assert_eq(s["tiers"]["fast"]["model"], "my-fast-model")
	assert_eq(s["tiers"]["fast"]["effort"], "low")
	assert_eq(s["tiers"]["strong"]["model"], "claude-opus-5-5")
	s["api_key"] = "k"
	assert_eq(AiSettings.save_settings(s, PATH), OK)
	assert_eq(AiSettings.load_settings(PATH), JSON.parse_string(JSON.stringify(s)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_bad_file_gives_defaults() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_eq(AiSettings.load_settings(PATH), AiSettings.defaults())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_is_configured() -> void:
	var saved := OS.get_environment("ANTHROPIC_API_KEY")
	OS.unset_environment("ANTHROPIC_API_KEY")
	var s := AiSettings.defaults()
	assert_false(AiSettings.is_configured(s))
	s["api_key"] = "sk-test"
	assert_true(AiSettings.is_configured(s))
	s["provider"] = "offline"
	assert_false(AiSettings.is_configured(s))
	var gw := {"provider": "openai_compatible", "base_url": "https://gw.example/v1", "api_key": ""}
	assert_true(AiSettings.is_configured(gw))
	gw["base_url"] = ""
	assert_false(AiSettings.is_configured(gw))
	if saved != "":
		OS.set_environment("ANTHROPIC_API_KEY", saved)


## anthropic 没填密钥时用环境变量。
func test_env_key() -> void:
	var saved := OS.get_environment("ANTHROPIC_API_KEY")
	OS.set_environment("ANTHROPIC_API_KEY", "sk-env")
	var s := AiSettings.defaults()
	assert_eq(AiSettings.api_key(s), "sk-env")
	assert_true(AiSettings.is_configured(s))
	s["api_key"] = "sk-file"
	assert_eq(AiSettings.api_key(s), "sk-file")
	if saved == "":
		OS.unset_environment("ANTHROPIC_API_KEY")
	else:
		OS.set_environment("ANTHROPIC_API_KEY", saved)
