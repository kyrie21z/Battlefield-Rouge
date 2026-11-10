class_name LoreEntries
extends RefCounted
## Authored fiction. Only project() may supply copy to the reading UI.
## Realm indices follow BoonData.Sin / RunDirector.REALMS (0..3).

const REALMS := ["怠惰", "恐惧", "愤怒", "悲伤"]
const COLORS := [Color("cfad79"), Color("b5a0da"), Color("d88d87"), Color("87b6ca")]
const DIARIES := [
	{
		"title": "答辩前夜：无休止的修改",
		"body": "凌晨两点，文件名后面又多了一个“最终版”。我把同一条曲线的颜色改回昨天的样子，仿佛只要图例足够整齐，明天就不会有人发现我解释不了的地方。\n\n水杯在键盘旁边凉了。我想合上电脑，却先在心里演练了一遍别人还在努力的样子。屏幕暗下去时，我看见自己的脸；我动了动鼠标，让它重新亮起来。\n\n皇冠说，再检查一页，我们就更有把握了。我知道他想陪我走过明天。他曾陪我写出第一份完整的报告。于是我又向后翻了一页。\n\n窗外没有人催我。只有光标还在闪，像一只不肯合上的眼睛。"
	},
	{
		"title": "深渊视线：教授们的提问",
		"body": "投影里的字都认得，连页码都背过。教授问起那个假设的依据时，我听见杯盖碰到杯沿的一声轻响。此后每一秒都变得很长。\n\n我在脑中翻找练习过的开头，越用力，纸页越像被风吹散。台下有人低头记笔记。我不知道他写了什么，却已经替他写完了对我的判词。\n\n皇冠轻声提醒我：抬头，别让他们看见你退缩。他的声音替我撑住了站姿。我把手藏到讲台后面，仍旧找不到下一句话。\n\n那道问题悬在光里。我最怕的究竟是答不上来，还是答不上来之后，他们就再也看不见我做过的那些事？"
	},
	{
		"title": "无声爆发：不能说出口的愤怒",
		"body": "“你应该早点想清楚。”这句话落下时，我想起那些被推翻又重做的夜晚。想说我问过，想说那次邮件没有回音，也想承认有些地方确实是我没有做好。\n\n最后我只说了“好的”。指甲压进掌心，纸角被我捻得发软。我把一整段话咽下去，喉咙里却留下了它的形状。\n\n皇冠劝我先把事情做好。他怕我一时冲动，让辛苦准备的答辩变成争执。我听了他的，微笑也没有掉下来。\n\n回到走廊，我对着饮水机站了很久。我没有砸碎任何东西，可也没能说清楚：哪一部分批评我愿意承担，哪一句话，我希望它不要再发生。"
	},
	{
		"title": "镜前自审：我不配停下来",
		"body": "洗手间的镜子比投影清楚。我试着把眼角的水擦掉，越擦越像在修改一张不合格的照片。门外有人经过，我立刻打开水龙头。\n\n我列起还来得及补救的事：重做实验，补一封邮件，再读几篇论文。每列一条，胸口就安静片刻。列表下面，有个很小的声音说，我已经很难过了。\n\n皇冠告诉我，我们还有下一次。他是真心相信那条往上的路。我点头，像只要安排好明天，今天就可以没有发生过。\n\n水声停了。我看着镜中的人，竟想不起上一次问他“你累不累”是什么时候。纸巾湿在手里，我迟迟没有把它扔掉。"
	},
	{
		"title": "终局独白：我只想做我自己",
		"body": "我重新听见杯盖落下的声音。问题还在那里，投影也没有替我换成一份无懈可击的答案。我吸了一口气，说：这一点，我需要一点时间整理。\n\n我曾以为，必须把疲惫、胆怯、怒意和眼泪都剔出去，剩下的才配站在这里。可越是剔除，我越认不出那个走了这么远的人。那些碎片让我停下、望向危险、辨认边界，也让我为失去的东西难过。它们有时会把我困住，却不必因此被永远抹去。\n\n皇冠安静地陪着我。我对他说，谢谢你一直相信我还能往前走。但今天走多远，什么时候休息，我也想听听自己的声音。他不再替我接上下一句。那一小段沉默里，我们都没有离开。\n\n我仍想把研究做好，仍会为答不上来的问题遗憾。我可以承认不知道，可以拒绝伤人的话，也要为自己伤过的人负责。感受不是一份免责的证书。\n\n答辩结束后，我把电脑合上。事情还没有全部解决。我买了一杯热水，坐在楼梯旁，直到它慢慢变温。没有新的成果需要写进这一页。\n\n今天，我只想以自己的名字，记下我在这里。"
	}
]
const DOSSIERS := [
	{
		"obstacle": "拖延", "value": "休整与留白",
		"crown": "“再等下去，我们又要赶不上了。先迈出一步，哪怕只做一点。”\n\n我记得，他曾这样陪我把空白文档写满。如今每一次停顿，他都担心我再也起不来。",
		"human": "钟声变快以后，我才听见自己一直没有喘匀的呼吸。空椅子不是对努力的否定，它也可以只是一把空椅子。\n\n我想学着分辨逃开责任与真正疲惫。该交代的事情仍要交代，但不必把每一次休息都写成下一次产出的借条。"
	},
	{
		"obstacle": "懦弱", "value": "敬畏与生存",
		"crown": "“别被还没发生的事拦住。我见过你的准备，我们有能力过去。”\n\n他把路指给我，想让我相信自己的脚步。可当我说桥下太深，他常常只听见一句不敢。",
		"human": "警示安静以后，桥缘没有因此变宽。我开始想念那一下后背发紧的提醒。\n\n害怕可以让我再看一眼落脚的地方，也可以提醒我请求帮助。我不必把每个阴影都当成灾难，更不必为证明勇敢，闭着眼睛走向危险。"
	},
	{
		"obstacle": "暴躁", "value": "守卫边界与拒绝",
		"crown": "“先别让怒气替我们回答。你准备的东西，值得被好好听见。”\n\n他想护住我的前程，替我把声音压低。后来我连一句平静的拒绝，也会先问他是否得体。",
		"human": "当撞来的身影不再被推开，我才发现自己一直在后退。那股热意曾告诉我：这里太近了，这句话伤到我了。\n\n我可以说不，可以离开，也可以把理由讲清。愤怒提醒我守住边界；它不能替辱骂、报复或伤害别人开脱。我仍要选择怎样伸出自己的手。"
	},
	{
		"obstacle": "崩溃", "value": "允许脆弱与自我悼念",
		"crown": "“抬起头，我们还能重新开始。我不想看你被这一次失误困住。”\n\n我知道他是在拉我。只是有时，我还没有向那个落空的愿望告别，他已经替我收好了行李。",
		"human": "泪水退去以后，受伤的地方没有变得坚硬。我只是失去了为它停留片刻的余地。\n\n我怀念过那个以为自己总能做到的人。允许自己为他难过，不必否定以后的路。我可以哭，可以把失落说给信任的人听；不需要先把痛苦变成成绩，才算没有白白经历。"
	}
]

static func project(archive: Dictionary, dossier: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visited: Array = archive.get("visited_realms", [])
	var defeated: Array = archive.get("defeated_realms", [])
	for index in (4 if dossier else 5):
		var final_page := index == 4
		var unlocked := bool(archive.get("reconciled", false)) if final_page else visited.has(index)
		var page := {
			"index": index, "unlocked": unlocked,
			"realm": "终页" if final_page else REALMS[index],
			"color": Color("d6c39b") if final_page else COLORS[index],
			"title": "尚未显影的页", "body": "",
			"crown": "", "human": "", "obstacle": "", "value": "",
			"human_unlocked": false,
			"hint": "抵达这段旅程的终点后，这一页才会显影。" if final_page else "初次进入%s之境，或在那里倒下后解锁。" % REALMS[index]
		}
		if unlocked:
			page.title = REALMS[index] + " · 双面档案" if dossier else DIARIES[index].title
			page.hint = "已显影 · 和解之后" if final_page else "已显影 · %s之境" % REALMS[index]
			if dossier:
				page.crown = DOSSIERS[index].crown
				page.obstacle = DOSSIERS[index].obstacle
				page.human_unlocked = defeated.has(index)
				if page.human_unlocked:
					page.human = DOSSIERS[index].human
					page.value = DOSSIERS[index].value
			else:
				page.body = DIARIES[index].body
		result.append(page)
	return result
