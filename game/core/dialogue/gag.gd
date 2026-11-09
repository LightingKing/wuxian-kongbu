extends RefCounted
## 禁言（设计规格 5.3）：当着剧情人物说出主神的信息，每句扣分（原著 −10/句）。
## 这里只判"这句话算不算泄密"，扣分与在场判定交给 expedition.leak()。
## 词表刻意短：主神世界的那套词一旦出口就露馅，日常对话不该误伤。

const WORDS: Array[String] = [
	"主神", "轮回", "积分", "奖励点", "支线", "兑换", "恐怖片", "剧情人物", "基因锁",
]


## 这句话里有不能当着剧情人物说的词吗？返回命中的那个词；没有返回空串。
static func hit(text: String) -> String:
	for w: String in WORDS:
		if text.contains(w):
			return w
	return ""


## 命中的词在句子里吗（给界面写提示用）。
static func is_leak(text: String) -> bool:
	return hit(text) != ""
