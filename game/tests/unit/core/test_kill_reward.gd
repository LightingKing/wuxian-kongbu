extends "res://tests/test_case.gd"

const KillReward = preload("res://core/economy/kill_reward.gd")


func test_licker_curve_from_novel() -> void:
	# 爬行者基础价 100：普通人打它（威胁高于自己）给满额；队伍变强后递减
	assert_almost(KillReward.points_for_kill(100.0, 300.0, 120.0), 100.0, 0.0001, "生化危机一")
	assert_almost(KillReward.points_for_kill(100.0, 300.0, 600.0), 50.0, 0.0001, "生化危机二")
	assert_almost(KillReward.points_for_kill(100.0, 300.0, 1200.0), 25.0, 0.0001, "偷袭生化")


func test_trivial_kill_gives_nothing() -> void:
	# 威胁不到自身评价战力的 5%：像玩一样，不给分
	assert_almost(KillReward.points_for_kill(100.0, 40.0, 1000.0), 0.0)


func test_ratio_exactly_at_cutoff_still_counts() -> void:
	assert_almost(KillReward.points_for_kill(100.0, 50.0, 1000.0), 5.0)


func test_zombie_tenth_point_each() -> void:
	# 原著 L50：10 只丧尸 = 1 点（对普通人）
	assert_almost(KillReward.points_for_kill(0.1, 100.0, 100.0), 0.1)
