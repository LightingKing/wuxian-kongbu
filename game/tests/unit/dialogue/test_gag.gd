extends "res://tests/test_case.gd"
## 禁言词表：命中主神世界的那套词才算泄密，日常对话不该误伤。

const Gag = preload("res://core/dialogue/gag.gd")


func test_hits_zhushen_words() -> void:
	assert_eq(Gag.hit("主神给的任务是什么"), "主神")
	assert_eq(Gag.hit("我攒了不少积分"), "积分")
	assert_eq(Gag.hit("下一部恐怖片是什么"), "恐怖片")
	assert_eq(Gag.hit("这算支线吧"), "支线")


func test_plain_talk_is_safe() -> void:
	assert_eq(Gag.hit("你们先走，我断后"), "")
	assert_eq(Gag.hit("激光是从墙上打过来的"), "")
	assert_eq(Gag.hit(""), "")
	assert_false(Gag.is_leak("马修，门要关了"))


func test_is_leak_matches_hit() -> void:
	assert_true(Gag.is_leak("主神说过不能提这个"))
	assert_false(Gag.is_leak("快跑"))
