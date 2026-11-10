# #141 审判之瞳与失去恐惧

## 实现与可玩入口

`res://tests/fear_oculus_bench.tscn` 是真实 Player、FearRealm、FearOculus 的独立 Boss 场景。胜利会生成可走近拾取的 `PsycheShardPickup`，没有自动授予替代拾取。F6 重开。

- `FearOculus` 继承 Enemy，保留 Health/Hitbox、赐福注册、时停、硬直、难度注入与单次死亡事件。默认 1250 HP，瞳孔爆头倍率 1.5；闭瞳只承受 40% 伤害，恢复窗口承受完整伤害。
- 三个独立反向旋转的同心环由原晶体人体的 36 块真实上臂、前臂、小腿、躯干网格折叠组成，中心为有不透明狭缝瞳孔的多面体巨眼。原资产与其他角色材质不改动。
- 凝视扫描：1.4 秒前摇、真实 ±48° 扫描，11° 光锥内每 0.28 秒结算 9 伤，WORLD 掩体阻挡。
- 紫光切割：1.25 秒前摇，最后 0.4 秒锁定，±22° 横扫，真实 Hitbox 射线每次 18 伤，墙面终止射线。
- 环状冲击：1.1 秒缩瞳，释放 24 个高度 1.1 米、速度 13m/s、12 伤实体投射物；保留挥刃/反射等共同弹丸交互，可跳过。攻击后暴露 1.4 秒。
- 真正击杀后取消本体伤害、清理环波/警报，爆裂成 56 个刚体晶屑。本地陷阱警告关闭；bench 的显式流程进一步调用共享碎片组件关闭普通 HUD / 敌人预警，掉落警醒碎片。
- 拾取后独立 +15% 暴击率、+20% 冲刺恢复；普通预警保持关闭。共享契约与独立测试见 `fragment-contract.md` 和 `vigilance-fragment.log`。

数值是当前可玩默认值，尚非最终平衡锁定。

## 验证

Godot 4.7.2 原生与 headless：

```text
godot --headless --path <repo> --fixed-fps 60 res://tests/fear_oculus_test.tscn
godot --path <repo> --fixed-fps 60 res://tests/fear_oculus_proof.tscn
```

`mechanics.log` 的 27 项断言全部通过，覆盖实际 HP 变化、闭瞳减伤/恢复窗口、暂停与赐福时停、扫描角度与真实墙体遮挡、Hitbox 光束、24 枚环波实际伤血、普通预警关闭但真实伤害光束仍可见、单次死亡、56 刚体回收，以及真实 Boss 击杀→危险提示清空→世界掉落→走近拾取→独立能力启用且普通预警仍被剥离。

三张原生截图已打开查看：`01-folded-human-oculus.png` 为折叠同心环巨眼；`02-cutting-beam.png` 为真实切割；`03-physical-ring-wave.png` 为实际环波实体弹。使用生产角色、几何和攻击，仅冻结 AI 并调整取证镜头，不是概念稿。

## 集成边界

Boss 通过注入的 `arena` 调用局部剥夺，并发出 `defeated` 与 `Events.enemy_killed`。主路线 RealmStage 负责统一死亡过场、跨关剥夺、碎片入库持久化和出口门控；本提交不读取或写入 RunState。独立 bench 的局部流程不声称已验证整条主路线，后者属于 #146 的集成验收。
