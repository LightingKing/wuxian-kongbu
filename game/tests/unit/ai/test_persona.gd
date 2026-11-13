extends "res://tests/test_case.gd"

const Persona = preload("res://ai/persona.gd")


func test_from_data() -> void:
	var m := Persona.from_data("matthew")
	assert_eq(m.id, "matthew")
	assert_eq(m.name, "马修·艾迪森")
	assert_eq(m.role, "plot_npc")
	assert_eq(m.fallback_lines.size(), 3)
	assert_eq(Persona.from_data("zhushen").role, "zhushen")


func test_context_text() -> void:
	var m := Persona.from_data("matthew")
	m.remember("郑吒在车厢里救过他")
	var t: String = m.context_text()
	assert_true(t.begins_with("【你扮演】马修·艾迪森"))
	assert_true(t.contains("性格：冷静、多疑"))
	assert_true(t.contains("你知道但绝不会说出口的事：他并不知道蜂房里真正发生了什么，上头没告诉他全部实情"))
	assert_true(t.contains("- 郑吒在车厢里救过他"))


## 记忆不会无限增长：最早的两条合并成一条。
func test_memory_cap() -> void:
	var p := Persona.new()
	p.name = "测试"
	for i in 14:
		p.remember("事件%d" % i)
	assert_eq(p.memories.size(), 12)
	assert_true(p.memories[0].begins_with("更早的事："))
	assert_true(p.memories[0].contains("事件2"))
	assert_eq(p.memories[11], "事件13")
	p.remember("长".repeat(300))
	assert_true(p.memories[0].length() <= 120)


func test_round_trip() -> void:
	var m := Persona.from_data("matthew")
	m.remember("被威胁过")
	var copy := Persona.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_eq(copy.to_dict(), m.to_dict())
