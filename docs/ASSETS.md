# 素材登记

每个进入仓库的第三方文件都要登记在这里。原始压缩包和完整下载放在仓库外的
`../third_party_sources/`（含 `SHA256SUMS`），不提交到 Git。只拷游戏实际用到的文件。

引擎是 Godot 4.7.2。导入格式优先 glTF / `.glb`（已入库的 `.gltf` 同属 glTF）。整包二进制不进仓库。

**政策：** MVP 必须优先使用下面列出的素材包。未列入清单的素材，须先经美术（Art）和 PM 批准，才能下载或入库。未更新本文时，不另开一套美术管线。

MVP MUST prioritize these listed packs; any non-listed assets need Art + PM approval first.

## 风格

Low-poly / Toon。写实军事风和体素风不进入 MVP。配色、剪影和可读性锁在 [STYLE.md](STYLE.md)。许可证默认 CC0 / 公有领域。清单里写明的例外只有 Kenney Starter Kit FPS 的代码（MIT，素材仍是 CC0）。其他许可证或清单外的包，先经 Art + PM 批准，再写回本文。

## MVP 优先清单

| 角色 | 素材包 | 许可证 | 页面 | 用途 |
| --- | --- | --- | --- | --- |
| primary | Quaternius — Toon Shooter Game Kit | CC0 | https://poly.pizza/bundle/Toon-Shooter-Game-Kit-qraiSXoAru | 角色、敌人、武器、掩体。同一包的作者页是 https://quaternius.com/packs/toonshootergamekit.html ；已入库文件从作者页抽取。 |
| primary | Quaternius — Downtown City MegaKit | CC0 | https://quaternius.com/packs/downtowncitymegakit.html | 占点用的模块化城市建筑。只把需要的模块抽进本项目。Quaternius 的引擎工程结构不整份搬进来。 |
| primary | Kenney — Blaster Kit | CC0 | https://kenney-assets.itch.io/blaster-kit | 武器。 |
| primary | Kenney — Starter Kit FPS | 代码 MIT，素材 CC0 | https://github.com/KenneyNL/Starter-Kit-FPS | 只作对照。Starter 工程不整份放进本仓库。 |
| secondary | Poly Haven | CC0 | https://polyhaven.com/ | HDRI、天空，以及有限的 PBR 地面。写实角色不和 Toon 套件混用。 |
| secondary | itch.io | 仅 CC0，且须 Low-poly / Toon | https://itch.io/ | 只补主清单的缺口。具体包仍须 Art + PM 批准并写回本文后才能入库。 |
| defer | Mixamo | MVP 不使用 | https://www.mixamo.com/ | 动画已在 Quaternius 包内。MVP 推迟。 |
| defer | Sketchfab | 逐个核对，风险高 | https://sketchfab.com/ | MVP 推迟。每个资源的许可证单独看。 |

## 流派与完美打击的可读性（历史身份方案）

给 AC-06 / AC-08 的图标，以及完美打击的闪光。效果数值仍 Design-TBD。

| 对象 | 读法 |
| --- | --- |
| 狂战士（Berserker） | 红 + 斧头剪影 |
| 军火大亨（Arms Dealer） | 黄 + 弹药剪影 |
| 鹰眼（Hawkeye） | 青（cyan）+ 准星剪影 |
| 完美打击成功 | 白闪，并有和失败分开的反馈 |
| 完美打击失败 | 失败不用近白闪（现有成败反馈保留） |

三派身份图标在下方「本项目原创」。效果数值仍 Design-TBD。AC-08 的九条增益图标不在这里。

## 署名

Quaternius 与 Kenney 的素材是 CC0。署名不强制，欢迎保留。Quaternius 的通用许可证 QAL v1.0（2026-08-28）禁止把素材单独再分发，所以仓库里只放游戏实际用到的文件，不放整包。

## 已入库

| 仓库内文件 | 来源文件 | 素材包 | 页面 | 许可证 | 下载日期 | SHA-256（前 16 位） |
| --- | --- | --- | --- | --- | --- | --- |
| `assets/models/weapons/ak.gltf` | `Guns/glTF/AK.gltf` | Quaternius — Toon Shooter Game Kit | https://quaternius.com/packs/toonshootergamekit.html | CC0（页面标注） | 2026-10-23 | `7320d771b829e2dc` |
| `assets/models/characters/enemy.gltf` | `Characters/glTF/Character_Enemy.gltf` | Quaternius — Toon Shooter Game Kit | https://quaternius.com/packs/toonshootergamekit.html | CC0（页面标注） | 2026-10-23 | `60c77a900ddd7608` |
| `assets/models/characters/hazmat.gltf` | `Characters/glTF/Character_Hazmat.gltf` | Quaternius — Toon Shooter Game Kit | https://quaternius.com/packs/toonshootergamekit.html | CC0（页面标注） | 2026-10-23 | `43d8c6d6e7e95647` |
| `assets/models/characters/soldier.gltf` | `Characters/glTF/Character_Soldier.gltf` | Quaternius — Toon Shooter Game Kit | https://quaternius.com/packs/toonshootergamekit.html | CC0（页面标注） | 2026-10-23 | `d1395255f7cfa8f7` |
| `assets/audio/hit_body.ogg` | `Audio/impactPunch_medium_001.ogg` | Kenney — Impact Sounds | https://kenney.nl/assets/impact-sounds | CC0 | 2026-10-23 | `e71d23abcc3f10d9` |
| `assets/audio/hit_head.ogg` | `Audio/impactPlate_light_002.ogg` | Kenney — Impact Sounds | https://kenney.nl/assets/impact-sounds | CC0 | 2026-10-23 | `8ac5869ea434cf0d` |
| `assets/vfx/muzzle.png` | `PNG (Transparent)/muzzle_02.png` | Kenney — Particle Pack | https://kenney.nl/assets/particle-pack | CC0 | 2026-10-23 | `96164063353cc038` |
| `assets/vfx/spark.png` | `PNG (Transparent)/spark_05.png` | Kenney — Particle Pack | https://kenney.nl/assets/particle-pack | CC0 | 2026-10-23 | `9624ea2017b8b276` |
| `assets/vfx/puff.png` | `PNG (Transparent)/smoke_04.png` | Kenney — Particle Pack | https://kenney.nl/assets/particle-pack | CC0 | 2026-10-23 | `2db2f69874cdb1e5` |
| `assets/models/weapons/knife.glb` | `Characters/glTF/Character_Enemy.gltf` 里的 `Knife_1` 网格 | Quaternius — Toon Shooter Game Kit | https://quaternius.com/packs/toonshootergamekit.html | CC0（页面标注） | 2026-10-26 | `7d24319650c01c86` |
| `assets/models/weapons/axe.glb` | `tools/melee_sources/斧子.fbx`（`Weapon_DoubleAxe`，用户提供） | 待确认（Quaternius — Pirates 包） | 无 | **待确认**，见下 | 2026-10-26 | `2812579b6314ccda` |
| `assets/models/weapons/tachi.glb` | `tools/melee_sources/太刀.fbx`（`Weapon_Cutlass`，用户提供） | 待确认（Quaternius — Pirates 包） | 无 | **待确认**，见下 | 2026-10-26 | `81284656ec36b6d8` |
| `assets/models/weapons/shotgun.glb` | `tools/gun_sources/Shotgun.fbx`（用户提供） | Quaternius — Toon Shooter 套件 | 待确认 | **待确认**，见下 | 2026-10-26 | `a2c3383f896ba8a1` |
| `assets/models/weapons/sniper.glb` | `tools/gun_sources/Sniper_2.fbx`（用户提供） | Quaternius — Toon Shooter 套件 | 待确认 | **待确认**，见下 | 2026-10-26 | `2669f9bd65995543` |

## 角色模型

三个角色来自同一个包，骨骼（43 根）和 17 个动画完全一样，原样拷入，没有导出或改动。

- `enemy.gltf`：小怪（`actors/enemy/enemy.tscn`）。
- `hazmat.gltf`：Boss。`boss.tscn` 设 `Enemy.model_scene`，运行时换掉默认模型，挂在骨骼上的头、躯干命中框原样搬到新骨骼上。
- `soldier.gltf`：原玩家的影子身体，2026-11-03 起不再使用（玩家改成下面的灰白晶体人形）；文件保留在仓库。

截图见 `docs/proof/characters/`。

## 两把枪模型的导出

`shotgun.glb` 和 `sniper.glb` 是从用户给的 FBX **导出**的，不是原始文件（原始 FBX 在 `tools/gun_sources/`，带 `.gdignore`，Godot 不扫描）：

- 握点（扳机手的位置）挪到原点，枪口朝 Godot -Z，上方 +Y；长度按第一人称重定：霰弹枪 155 cm → 88 cm，狙击枪 175 cm → 108 cm。
- 握点取长度的 26%（从枪托那端量），所以枪托留在原点后面 23 / 28 cm，摆到镜头前时正好被近裁剪面切掉。
- 两处是**声明**而不是自动判断：`muzzle: max`（这套模型枪口朝 +X；泵动霰弹枪的枪托比前端细，窄头猜测会反）和狙击枪的 `flip_up: True`（PCA 主轴符号不确定，第一版镜筒朝下）。脚本仍会算窄头猜测、把两端半径打进日志，方向一律再用 `docs/proof/guns/` 里的侧视/腰射截图复核。
- 历史导出源码已归档到 `tools/archive/legacy_weapons/export_gun_models.py`；只用于来源追溯，重现旧导出使用归档 README 指定的旧提交。

## 三把近战模型的导出

`knife.glb`、`axe.glb`、`tachi.glb` 都是从上面登记过的源文件里**导出**的，不是原始文件：

- 握点挪到原点，刃朝 -Z（Godot 的前方），刀面法线朝 +X。三个模型同一个约定，换一把不用改代码。
- 握点判定看的是「哪一端更窄」，但弯刀的护手比手柄宽（19 cm 对 5 cm），这条规则会把手握点判到刀尖。所以 历史 `tools/archive/legacy_weapons/export_melee_models.py` 里那把刀显式写 `grip_at="wide"`，导完再用截图核对握点在哪一头。
- 长度统一到手感的实际尺寸：匕首 0.46 m、斧 0.92 m、太刀 1.00 m。原始文件分别大 3.1 倍、1.1 倍、1.2 倍。
- **握点之后的部分会被切掉**（`trim_behind_grip`，目前只给斧开）：第一人称模型没有手，握点后面那截柄会吊在眼睛前面，斧的圆形柄头在挥砍全程就是一坨灰球。斧的握点定在离柄尾 20%（落在棕色木柄上），切面盖平，所以画面里看到的是柄的截面。
- 两个 FBX 自带一张内嵌贴图 `Atlas_Pirate.png`；GLB 里贴图是嵌进去的，Godot 导入时抽成 `axe_Atlas_Pirate.png` / `tachi_Atlas_Pirate.png` 放在模型旁边。这两个 PNG 是导入产物，不是新素材。
- 历史导出源码已归档到 `tools/archive/legacy_weapons/export_melee_models.py`，不再作为当前入口。旧版改 `target_length` 或 `grip_inset` 之后要同步改 `.tres` 里的 `blade_length`（= `(1 - grip_inset) * target_length`）：匕首 0.405、斧 0.736、太刀 0.88。

**源文件位置：** 原始 FBX 放在 `tools/melee_sources/`（带 `.gdignore`，Godot 不扫描），因为这台机器的沙箱不允许写仓库外的 `../third_party_sources/`；压缩包 `Axe by Quaternius - FkzZ6I1zjT.zip`、`Cutlass by Quaternius - tzwQ8g5dBy.zip` 仍在仓库外的父目录里。有 `../third_party_sources/` 的机器可以把两个 FBX 原样搬过去，只改导出脚本里 `SOURCES` 一行。`斧子.fbx` 的 SHA-256 是 `74d2aa994826be0a`，`太刀.fbx` 是 `3bb8e530e6317132`（前 16 位）。

**待办：** 这两个 FBX 是用户直接放进仓库的，素材包和许可证明都没有登记。按本文政策，清单外素材需要 Art + PM 批准；在补上之前，这两个 GLB 不能算正式入库。

## 代码生成的素材

| 内容 | 位置 | 许可证 |
| --- | --- | --- |
| 枪声、换弹声、空仓声 | `weapons/procedural_audio.gd`，运行时生成 | MIT，移植自 Ironline 1944，许可证全文见 [`docs/licenses/ironline-1944-MIT.txt`](licenses/ironline-1944-MIT.txt) |
| 准星 | `ui/crosshair.gd`，运行时绘制 | 本项目 |

## HUD 武器剪影图标

`assets/ui/weapons/{ak,shotgun,sniper,knife,axe,tachi}.png` 由本仓库已有武器模型用 `tools/render_icons.tscn` 渲染：256×128、透明背景、不发光白色剪影、统一侧视（枪口 / 刀尖朝右）。它们不是新增第三方素材，许可证随上表对应模型。重新生成：

```bash
godot --path . res://tools/render_icons.tscn
```

护盾技能图标 `assets/ui/abilities/shield.svg` 为本项目绘制。

## 本项目原创

AC-06 的流派身份图标。Low-poly / Toon 平涂，颜色和剪影锁在 [STYLE.md](STYLE.md)。本项目绘制，不是第三方包，也不从 `../origin/` 拷贝。随本仓库使用。

| 仓库内文件 | 内容 | 许可证 |
| --- | --- | --- |
| `assets/ui/schools/berserker.svg` | 狂战士：`#E0242A` 底 + `#6E1218` 斧头剪影 | 本项目 |
| `assets/ui/schools/arms_dealer.svg` | 军火大亨：`#F5C400` 底 + `#8A6800` 弹药剪影 | 本项目 |
| `assets/ui/schools/hawkeye.svg` | 鹰眼：`#14C8D4` 底 + `#0A6670` 准星剪影 | 本项目 |

游戏里由 `SchoolBadge`（`TextureRect`）画在增益选择界面的「流派方向」一排。竖切要显示某一派时调用 `SchoolBadge.setup(school)`。对照图：`docs/proof/issue-13/`。

## 2026-10-27：九增益图标与当前身份

本次沿用用户已完成的九增益改进，当前 `SchoolCatalog` 为枪械、刀具、技能三派：枪械沿用黄色弹药身份图，刀具沿用红色斧头身份图，技能身份共用下表的紫色 `skill_unlock.svg`。上面的狂战士、军火大亨、鹰眼和旧对照图保留为历史方案；`hawkeye.svg` 仍保留，但不代表本次技能派。卡片与玩法默认值见 [Buff 当前实现](Buff当前实现.md)，接入范围见 [ADR 0006](adr/0006-nine-buffs-and-entry-choices.md)。

以下九张均从用户维护的九增益源码版迁入，为 128×128 的项目内 SVG 绘制，不是从第三方素材包或旧 `origin` 提取的图片。技能三图沿用用户已确定的紫色；`skill_unlock.svg` 按用户的黑豹面具视觉参考绘制，源文件注明 Marvel Black Panther fan icon，没有下载或嵌入官方图片，不将其登记为第三方 CC0 素材。以下 SHA-256 是本次迁入文件的完整实际哈希，日期为接入登记日，并非外部下载日期。

| 仓库内文件 | 内容与来源 | SHA-256 |
| --- | --- | --- |
| `assets/ui/buffs/firearm_damage.svg` | 危险弹匣；沿用用户版本的弹匣与爆炸 SVG | `f67648fd137b9f85b0d8465045585eaf6425b4b2c2ad6e96b7702606e3d7f9cc` |
| `assets/ui/buffs/firearm_rate.svg` | 快速扳机；沿用用户版本的子弹与速度线 SVG | `e6b0ccc35a092988fac5fcc69d52f2ded659f0d22cf4d910d6faeae9d538bdfa` |
| `assets/ui/buffs/firearm_magazine.svg` | 扩容弹匣；沿用用户版本的加号弹匣 SVG | `7798676dbff642323ef28b6fdf17e396298153b285be717befc4ae4ec2306c85` |
| `assets/ui/buffs/blade_damage.svg` | 子弹收藏家；沿用用户版本的刀刃与收藏弹头 SVG | `3a2c11173150b983e2393d4e9780ebaa2b535565a27eaee1c42f0ebdbbfb2271` |
| `assets/ui/buffs/blade_speed.svg` | 疾风连斩；沿用用户版本的多道刀光 SVG | `175666cc34ebe1022b3896cb1ed6712f645b20e68608ec546ae0321cdbdf2c6f` |
| `assets/ui/buffs/blade_range.svg` | 长刃改造；沿用用户版本的加长刀刃 SVG | `913ddac83fa22a2e617d4e0d4883939e5199b2f090fd7eea0bb6e840cef44672` |
| `assets/ui/buffs/skill_unlock.svg` | 反击护盾与技能身份；沿用用户版本的紫色自绘黑豹面具 SVG，视觉参考如上 | `2990b600034a0cab787c96ef3e849a4f1219799aa699ae7a5d035a50c6e7557b` |
| `assets/ui/buffs/skill_duration.svg` | 持久屏障；沿用用户版本的紫色计时护盾 SVG | `0c523de1decbace848d8d70344e93342d0196d1ab6a754e2a8ac19f0af75c7e7` |
| `assets/ui/buffs/skill_cooldown.svg` | 能量回流；沿用用户版本的紫色环形回流 SVG | `fd2adce06a32b4f5e016f86c199262e0be759dd64f23a8948b4034058aac027f` |

每张 SVG 的 `.import` 设置随文件提交；不提交 `.godot` 导入缓存。爆炸弹匣、收藏弹、护盾遮罩与反击波由现有组件绘制，不新增外部贴图或模型。本次保留团队两小关加 Boss 的地图与素材，没有迁入城市素材版或未来候选内容。

## 2026-11-01：Pride 开场图集

按用户要求将已完成的 Sloth 开场任务 #45 开场放在本游戏启动前。`docs/levels/sloth-opening/assets/pride-atlas.png`（#147 从旧运行目录原样归档）为本次项目内 imagegen 生成与编辑的六格透明图集（1024×1536），不是从 `origin` 或剧集提取的素材，不标为 CC0。仅借鉴用户给出的复古卡通表演参考，没有提交剧集截图或原角色素材。来源、提示词和手绘皇冠设计见 [生成记录](levels/sloth-opening/assets/PROMPT.md)。

SHA-256：`9eefbb752fb862976a6e2433841ffbea6c66ba5aebf86906fe7722f74b8a5840`。保留工程内导入设置；灰白几何、渐变材质和提示音由脚本生成，字体调用系统已有字体，未打包外部字体文件。开场资源全部在本仓库内，运行不依赖 Mind-Freak 文件夹。

概念评审图 `docs/levels/sloth-opening/assets/pride-concept.jpg` 同为本次生成，仅 JPEG 重编码；SHA-256：`87a6b70ae81c35fd982244d66800d3d440731bd206db548363576f4312e0a67b`，不被运行时代码引用。

## 2026-11-03：红晶体敌人（自有素材）

`assets/models/characters/red_crystal_enemy_*.glb` 由本项目的美术导出管线产出（源工程和导出器
在仓库外，不随仓库分发）。三份文件共用同一批网格：5,155 顶点 / 2,211 三角 / 24 骨，规格与用法见
[RED_CRYSTAL_ENEMY.md](RED_CRYSTAL_ENEMY.md)。

| 仓库内文件 | 内容 | 素材包 | 页面 | 许可证 | 导出入库日期 | SHA-256（前 16 位） |
| --- | --- | --- | --- | --- | --- | --- |
| `assets/models/characters/red_crystal_enemy_static.glb` | 11 件网格合并成 1 个，绑定姿势已烘焙 | 无（内部导出） | 无 | 项目自有 | 2026-11-03 | `3f8afcf5dd5bb816` |
| `assets/models/characters/red_crystal_enemy_rigged.glb` | 11 件蒙皮网格 + 24 根关节 | 无（内部导出） | 无 | 项目自有 | 2026-11-03 | `bfb49c86c7d7f1bd` |
| `assets/models/characters/red_crystal_enemy_parts.glb` | 11 件刚性部件，按各自主骨取枢轴 | 无（内部导出） | 无 | 项目自有 | 2026-11-03 | `2fa065d1bbe35893` |

**许可：项目自有（内部素材）。** 源工程与来源凭证不随仓库分发，由 Art 负责人归档；要做对外
物料（宣传素材、发行包）前先找 Art 负责人取凭证。三个文件现在只当**候选外观**放在
`assets/models/characters/`，**没有接进** `actors/enemy/`，也不算进 MVP 优先清单。

配套材质与着色器是本项目写的，不涉及第三方来源：`assets/materials/red_crystal_material.tres`
（`StandardMaterial3D` 近似）、`assets/materials/red_crystal_crystal.gdshader` +
`red_crystal_material_shader.tres`（菲涅尔边缘 + 自发光）。三份文件里的颜色数值
（`_Color`、`_EmissionColor`、`_SpecColor`）取自源材质。

出图与实机验证记录见 [docs/proof/crystal-enemy](proof/crystal-enemy/README.md)。

## 2026-11-03：红晶体敌人的动画与碎裂碎片（自有素材）

`assets/models/characters/red_crystal_enemy_animated.glb` 是上一节 `rigged` 的同批网格加 23 个人物
剪辑；`assets/models/characters/red_crystal_enemy_shards.glb` 是同一批面按 11 个部位切成的 56 片
碎屑。两份都由本项目的美术导出管线产出（源工程和导出器在仓库外，不随仓库分发），规格、剪辑表和
用法见 [RED_CRYSTAL_ENEMY.md](RED_CRYSTAL_ENEMY.md)。

| 仓库内文件 | 内容 | 素材包 | 页面 | 许可证 | 导出入库日期 | SHA-256（前 16 位） |
| --- | --- | --- | --- | --- | --- | --- |
| `assets/models/characters/red_crystal_enemy_animated.glb` | 11 件蒙皮网格 + 24 骨 + 23 个剪辑（30 fps） | 无（内部导出） | 无 | 项目自有 | 2026-11-03 | `c2a219a3e021b38d` |
| `assets/models/characters/red_crystal_enemy_shards.glb` | 56 片碎屑，按 `SHARD_m_<部位>_<序号>` 分组 | 无（内部导出） | 无 | 项目自有 | 2026-11-03 | `aa0d516abde333ab` |
| `assets/materials/red_crystal_crystal_shard.gdshader` | 碎屑着色器：同一套观感，菲涅尔边缘光与高光压低 | 无（本项目编写） | 无 | 项目自有 | 2026-11-03 | `0cb1c522525329d6` |
| `assets/materials/red_crystal_material_shard.tres` | 上面着色器的现成 `ShaderMaterial` | 无（本项目编写） | 无 | 项目自有 | 2026-11-03 | `dd8fb309ac6953f6` |

**许可：项目自有（内部素材）。** 源工程与来源凭证不随仓库分发，由 Art 负责人归档；要做对外物料
（宣传素材、发行包）前先找 Art 负责人取凭证。两份 GLB 仍然只当**候选外观**，**没有接进**
`actors/enemy/`：要当敌人外观用，另开一个 PR 改 `enemy.tscn` 的 `model_scene`。

校验口径与上一节一致：`python tools/crystal_enemy/check_glb.py assets/models/characters/red_crystal_enemy_animated.glb`
（会打印蒙皮后包围盒 1.687 × 1.948 × 0.394）、
`python tools/crystal_enemy/check_normals.py assets/models/characters/red_crystal_enemy_*.glb`
（缠绕与顶点法线一致率 1.000，五个 GLB 都是）；Godot 侧 `--check` 与实机图见
[docs/proof/crystal-enemy](proof/crystal-enemy/README.md)。

## 2026-11-03：玩家晶体身体（自有材质）

玩家的影子身体从 `soldier.gltf` 换成了 `red_crystal_enemy_animated.glb` 的灰白版本：
`actors/player/protagonist_body.tscn` 实例化上面已登记的 GLB（统一缩放 0.9，身高 1.75 m），
`actors/player/shadow_body.gd` 在 `SHADOWS_ONLY` 下只投影子，站着播 `idle`、移动播 `run`。
模型本身不重复登记，这里只新增材质。

| 仓库内文件 | 内容 | 素材包 | 页面 | 许可证 | 导出入库日期 | SHA-256（前 16 位） |
| --- | --- | --- | --- | --- | --- | --- |
| `assets/materials/protagonist_crystal_material.tres` | 玩家影子身体材质：复用 `red_crystal_crystal.gdshader`，灰白基色、弱自发光、冷色边缘光 | 无（本项目编写） | 无 | 项目自有 | 2026-11-03 | `dfa5b91de24cd05e` |

该着色器写 `ALPHA`，混合材质不参与阴影贴图，所以 `shadow_body.gd` 用一层不透明的灰白
`StandardMaterial3D` 当 `material_override` 负责投影，晶体材质放在 `material_overlay`
负责外观。影子身体还会按玩家手里的枪在右手上举着同一把武器模型（`ak.gltf`、`shotgun.glb`、
`sniper.glb`，均为上面已登记的既有素材，没有新增资产）。截图与复现命令见
[docs/proof/protagonist-body](proof/protagonist-body/README.md)。
这次只把 GLB 用于玩家的影子，敌人外观仍未接入 `actors/enemy/`。


## 2026-11-04 · Sloth敌人独立备用包

[备用目录](../prototypes/sloth_enemy_reserve/README.md)由.gdignore隔离，未接入正式游戏。`sloth_visual.gd`构建原创披风/链环/茧壳，`sloth_cloth.gdshader`为原创布料材质；`01-lineup.jpg`、`02-mantle-rear.jpg`为本项目Godot原生截图。来源与SHA-256见[包内登记](../prototypes/sloth_enemy_reserve/ASSETS.md)。复用既有红晶体GLB，不重复或新增第三方资源。


### Sloth备用修订：藏青与按命中点碎裂

仅在独立备用实例中改藏青，沿用已登记的56片red_crystal_enemy_shards.glb；新增sloth_shatter.gd负责当前姿态、命中点起裂、暂停和回收。新版01-lineup.jpg、02-mantle-rear.jpg、03-impact-shatter.jpg、04-cloak-throw.jpg均为原生渲染截图；文件来源与SHA-256见[备用包登记](../prototypes/sloth_enemy_reserve/ASSETS.md)。正式模型、材质和玩法不变。

### Sloth备用披风强化

新增05-cloak-evade.jpg、06-charge-lock.jpg、07-fast-release.jpg为Godot原生截图，分别展示闪避反馈、凝聚锁向和快速释放；05使用强制触发演示。只作JPEG重编码，没有新增第三方素材。最新SHA-256见[备用包登记](../prototypes/sloth_enemy_reserve/ASSETS.md)。

2026-11-05新增备用`08-windows-opengl.jpg`为Windows OpenGL实际渲染截图，仅JPEG重编码；SHA-256见[备用包登记](../prototypes/sloth_enemy_reserve/ASSETS.md)。没有新增第三方资源。


## 2026-11-08 · Sloth场景独立备案包

[场景备用预演](../prototypes/sloth_scene_reserve/README.md)基于main5292b92（已合并弹匣#88与敌人备用#92），由外层.gdignore隔离，内层viewer为独立Godot工程。新增前两关复层庭院与Boss云海圣殿的程序几何、原创地面/天空/云层材质和原生截图；来源、SHA-256及当前验证见[包内登记](../prototypes/sloth_scene_reserve/ASSETS.md)。没有新第三方素材、生成式图片或正式游戏素材替换。

## 2026-11-08 · Sloth 可玩整合草稿

本次按用户明确要求将上述两套备用中的原创内容提取为游戏运行文件，历史备用包不改。当前 `actors/enemy/sloth/sloth_visual.gd`、`sloth_shatter.gd` 和 `assets/materials/sloth_cloth.gdshader` 源自已合并敌人备用 #92；`environments/sloth/{architecture,courtyard}.gd` 及 `floor/stone/sanctum_sky/cloud_sea.gdshader` 源自已合并场景备用 #96，移除预演控制、接入真实碰撞/导航并修订。均为本项目原创程序几何与材质，由 Codex 协助修改，无新增第三方资产或生成式图片。

运行时继续复用此前登记的红晶体动画/56 片碎屑 GLB，只覆盖实例藏青材质，不改原红色资源；旧 Boss 的 Hazmat 来源仍按上方历史登记。此前“敌人未接入”的段落记录当时事实，本次草稿已接入三种 Sloth 小怪，并未替换成完整巨像 Boss。

[整合证明](proof/sloth-integration/README.md) 内 JPEG 是本轮 Godot 4.7.2 Windows Forward+ 原生 PNG 的缩放/JPEG 重编码，无重绘；四连发图使用观察相机，流程图保留真实游戏 HUD。来源文件与图像 SHA-256 见 [SHA256SUMS](proof/sloth-integration/SHA256SUMS.txt)，文本哈希使用仓库 LF 字节。

### 同日紧凑战场修订

`environments/sloth/{architecture,courtyard}.gd` 继续使用上述本项目原创程序几何，重排实际地板/碰撞/掩体与外围建筑，未新增第三方模型或材质。[紧凑战场证明](proof/sloth-compact/README.md) 的 JPEG 为本轮 Windows Forward+ 原生截图，仅缩放和JPEG重编码；当前几何源码/生成地图与新截图哈希见 [紧凑版SHA256SUMS](proof/sloth-compact/SHA256SUMS.txt)。前一节的宽场截图、源码哈希、性能和实战轨迹保留提交 `1a7b86c` 当时的历史含义，不表示当前文件字节或性能。

### 同日持续反击盾与主动敌群

沿用项目原创紫盾/反击波与服饰材质，无新增第三方模型、贴图、字体或音频。G槽蓄能弧和容量条为Godot程序绘制；新增少量掩体仍为现有几何材质。[当前4张JPEG](proof/counter-pressure/README.md)是本轮Windows Forward+原生PNG的缩放/JPEG重编码，无生成式重绘；前三张为真实选卡/G/敌弹定点验证，第四张为开场敌群观察。当前代码/地图与图片来源哈希见[SHA256SUMS](proof/counter-pressure/SHA256SUMS.txt)。紧凑版旧目录记录`47bb39f`时的低密度/旧盾结果，源码哈希与数值保留历史意义。

### 同日波次微调取证

[波次微调的2张JPEG](proof/wave-tuning/README.md)为本轮Godot4.7.2 Windows Forward+原生PNG缩放/JPEG重编码，分别为开场5名守卫和据点开放后4名增援小地图；无新美术资产或生成式重绘。来源与当前生成器/地图/增援代码哈希见[SHA256SUMS](proof/wave-tuning/SHA256SUMS.txt)。前轮`counter-pressure`目录的源码哈希和7/11/11波次对应`8a6fa90`历史提交，不能替代当前5/9/9、4人增援结果。

## Epic 1 原创几何与图标

手枪与意志短刃在 Blender 中制作，由本项目原创脚本生成网格并导出 GLB；保留 `.blend` 和 `tools/epic1_models/generate.py`。建模风格参考 SUPERHOT，未使用其模型或贴图。完整第一人称身躯直接复用上文已登记的原角色网格与骨骼、主角材质及预切碎片，不新增第三方素材，也不从旧工程拷素材。两张 SVG 为本项目原创几何剪影，与项目代码使用同一许可；Godot 在运行时生成晶体声音，无外部音频。

| 文件 | 来源 | SHA-256 |
| --- | --- | --- |
| `weapons/obsidian_pistol/pistol_icon.svg` | 本项目原创 | `e1f55a3c0332ce86b5bffd610152fd05bf4676d4425ad6ac07b3311b2058720e` |
| `weapons/mind_blade/mind_blade.svg` | 本项目原创 | `5d4a027b1a5afcae43408ff33eb6afd18222d76839e777fe3700b010b2dac684` |
| `assets/models/weapons/obsidian_pistol.glb` | 本项目原创；`tools/epic1_models/obsidian_pistol.blend` 导出，项目许可 | `db2e57cc1680c8605816581e93c1c72b69b2ac289742b11bb51915cdd86d4401` |
| `assets/models/weapons/mind_blade.glb` | 本项目原创；`tools/epic1_models/mind_blade.blend` 导出，项目许可 | `dbeb12ce0ae2780b0d5c26be1afc51bb8046a89b5cd8582b7c673c24ec3d295f` |

模型源面数、三角化数量、尺寸、轴转换与各部件原点见 [导出记录](../tools/epic1_models/manifest.json)。原始 Blender 文件枪口/刀尖朝 -Y、Z 向上，导出副本旋转并烘焙后符合 Godot -Z 向前、+Y 向上；运行时不用旋转补偿。

本次将 2026-11-03 的影子身体升级为完整第一人称身躯，仅头部保持 `SHADOWS_ONLY`，移除旧枪影副本。裂痕只沿原网格的非共面晶体接缝，统一黑色；渲染副本保留原三角形、蒙皮和顶点位置，0 级恢复原资源。原 GLB、材质与预切碎片不修改。原生截图与测试见 [Epic 1 验收记录](proof/epic1/README.md)。

### 武器多视角设计参考

以下两张为用户提供的本项目设计稿，作为 Blender 轮廓参考；精确尺寸以 `NARRATIVE_FOUNDATION.md` 第 8 节文字为准。原图保持原样，图内存在少量互相冲突的尺寸和护圈细节，不作为独立工程尺寸约束。

| 文件 | 来源 | SHA-256 |
| --- | --- | --- |
| `docs/assets/obsidian_pistol_turnaround.jpg` | 本项目设计参考，用户提供 | `7d74ab5007ece8274fa3889664ab69ff1bfdc2ff311663e2ee99aa7db2cbe7a9` |
| `docs/assets/mind_blade_turnaround.jpg` | 本项目设计参考，用户提供 | `e3beade77687cbcb505a6342f1b6dd057001a5cd3ec902d0c92ff06d84fa698f` |

## #105：原角色升级为第一人称完整身躯

复用上文登记的 `red_crystal_enemy_animated.glb`（11 个部位、24 骨）、`red_crystal_enemy_shards.glb`（56 个预切碎片）与 `protagonist_crystal_material.tres`；没有新角色素材，原文件保持不变。此前只投影的身体现在仅头部保持 `SHADOWS_ONLY`，胸腹、双臂和双腿可见，旧独立枪影副本移除。

裂缝沿原网格非共面晶体接缝，统一黑色。渲染副本保留原三角形、顶点位置、法线、UV、骨索引与权重，仅增加边距离/选择属性；0 级恢复原资源。材质与碎片姿态逐实例管理。原生取证为 Godot 4.7.2 Forward+ 直接截图，见 [#105 验收记录](proof/issue-105/README.md)。

## Epic 2：门扉与赐福身份图标

以下八张 SVG 为本项目原创代码绘制，不下载第三方图片，不从旧工程提取；许可证随本项目。对应四系徽记、双重共鸣及三种房间奖励展示。PNG 证明是 Godot 4.7.2 Forward+ 直接截图，未重绘；界面测试图使用可控 BoonData，实际关卡记录单独注明。

| 文件 | SHA-256 |
| --- | --- |
| `assets/ui/boons/dual.svg` | `7b10bbc1218ba3792afa124013910055df0567f47096e7216aa161baf1c44e32` |
| `assets/ui/boons/fear.svg` | `a1f2415e9ebd92d2d4813f181c10a6e274691cbaaf80cf8125bf1ab03fed2039` |
| `assets/ui/boons/resonance.svg` | `162e3f6b9d3440989edf94ba9ab045e2dc2a3544c342b20a8179eb8926f19856` |
| `assets/ui/boons/shop.svg` | `2a92ca59d1f9896757e21190d8bf95392d1251f82c95dc3fc48bca50854b45bd` |
| `assets/ui/boons/sloth.svg` | `73e9ad4b2ebafe3c0c00b0e7f7f6cbe6ac0d466ee6e304d959059c9516b58b9d` |
| `assets/ui/boons/sorrow.svg` | `bc81cb3150f9e589f4651e13f25fc397fabe5d32371df1c45c0154aa2b2db0b7` |
| `assets/ui/boons/vitality.svg` | `de7d2e9f494f6154f68250862a331bf225bfdfbdef328565d0adb9be282f1da4` |
| `assets/ui/boons/wrath.svg` | `e2f552e6b6494e965a4352ceaac0a937bc600d76fb3a83bc94f410f4b54b3221` |

## #147 原创皇冠与中文开场语音（2026-11-10）

`actors/crown/crown_model.gd` 是本项目原创参数化 3D 几何：普通中空六尖象牙白冠与克制的暗金边，遵循最新用户纠偏移除眼睛、手与拟人装饰，未提取旧图集或第三方模型。原始白晶人体和手枪仍使用既有登记资源，未修改原件。

六段原创项目台词使用官方 [Kokoro-82M-v1.1-zh](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh) 固定版本 `01e7505bd6a7a2ac4975463114c3a7650a9f7218` 离线生成；模型与推理代码均为 Apache-2.0。官方模型卡声明中文专业数据由 LongMaoData 获许可提供。皇冠使用标准女声 `zf_001`，面试声使用标准男声 `zm_010`，不克隆他人身份。只分发24kHz单声道PCM16输出，不分发模型/引擎，不标为CC0。原Windows SAPI输出已替换，旧脚本显式阻止再次生成。

复现脚本、固定模型/音色哈希、原文与逐句参数见 [语音生成说明](../tools/cinematic/voice_assets.md) 和 [完整manifest](../tools/cinematic/voice_assets_manifest.json)；工具Apache许可原文已保留。当前工具没有音频听感输入；波形/真实解码播放不等于人工发音与情绪验收。心跳和耳鸣仍为本项目原创数学波形。

| 文件 | 秒 | SHA-256 |
| --- | ---: | --- |
| `assets/audio/crown/opening/better.wav` | 5.825 | `a1b72f9e5f690364adedfd72270bdb03e7096fa5c0e62054836aab7a58e7b613` |
| `assets/audio/crown/opening/care.wav` | 7.050 | `e3989058caa04536db048eb7b8ddf211663e2e8d61952f60087f1387e2b7576e` |
| `assets/audio/crown/opening/interview.wav` | 7.600 | `37b0bf581011072289b12ad35869bbd1d8561f21149a76b8582e134284ea4f9a` |
| `assets/audio/crown/opening/invitation.wav` | 7.625 | `21d9fee7f7a93687a3a704c2296295f8466981bcd0f1c3e6c27058db193ace9e` |
| `assets/audio/crown/opening/obstacle.wav` | 6.725 | `cdc62d01f8785409a921c714b940db3429419ee003d2e8e3adf0efbdef9963d1` |
| `assets/audio/crown/opening/wake.wav` | 4.850 | `fbe10da257756b7316ee21fe09622eebc9921e44f554d9b18ed00455864c84d0` |

## #148 随行皇冠动态语音（2026-11-10）

11段原创项目台词使用#147登记的官方 Apache-2.0 Kokoro-82M-v1.1-zh，同一标准女声 `zf_001`，本机离线生成24kHz单声道PCM16；按句使用0.92/1.00/1.08语速表达叙事节奏，精确参数/哈希见 [manifest](../tools/cinematic/voice_assets_manifest.json)。仅分发输出，不分发模型/引擎，不标为CC0。旧SAPI生成脚本已显式阻止执行。3D冠及发光Shader仍为本项目原创。波形、时长、实际解码播放已验证，未完成人工听感验收。

| 文件 | 秒 | SHA-256 |
| --- | ---: | --- |
| `assets/audio/crown/dynamic/deep.wav` | 6.550 | `ec543a6c12c52fe1d1165b8e3a74a5e3d4c92e964a4617287e7a5d3c34eaefc0` |
| `assets/audio/crown/dynamic/deep_abyss.wav` | 6.875 | `23205e802fdd388eac97e7b24629a17fea3bb1beafe977e81d37c7534fd208c3` |
| `assets/audio/crown/dynamic/early.wav` | 6.850 | `3ccf151100439726c992094ee27c8de72e87442ffaba7a3cf71f14288bd38dac` |
| `assets/audio/crown/dynamic/early_abyss.wav` | 6.750 | `231f5ac88c951add9ec231a9b3ddeecc9b102eafbdaba6d593820ebad1b4a211` |
| `assets/audio/crown/dynamic/first.wav` | 6.950 | `a2f5a2d57260723adadb4e61d5228aebba9d185be97df352f1f43678c6c6fed6` |
| `assets/audio/crown/dynamic/floor2.wav` | 5.375 | `75c94d291eda59dd50656021a05ce149177379a4fb04e5574c3fb90b368e784c` |
| `assets/audio/crown/dynamic/floor3.wav` | 5.425 | `e978951ea4d2afe5b23e03a749f62017d8118c1322097dc5c404dabf352c2f59` |
| `assets/audio/crown/dynamic/floor4.wav` | 4.925 | `80296081db08becde9a986bffdb3ff74afc59f4cffc898428676cc7320eb1b2f` |
| `assets/audio/crown/dynamic/floor5.wav` | 5.300 | `60ff0c0aaad859c4c9b476709c292e00db1ccf2a8807e58ce7ccf0e6a9a67d47` |
| `assets/audio/crown/dynamic/veteran.wav` | 3.425 | `20eee70b053d282f6afa92c897ecf16b02b352cb90b194e0cf3e904e15ba8d61` |
| `assets/audio/crown/dynamic/veteran_abyss.wav` | 3.800 | `f865e7d60479368200bdfe28fb32c2a4fd9669f39fe3b0fc0907b352252d99b9` |

## #149 金缮重组素材（2026-11-10）

BodyReassembly复用既有原始白晶身体与56片几何，GLB不变；Shader与编排为原创。五句自我接纳台词由#147登记的官方 Apache-2.0 Kokoro-82M-v1.1-zh 标准男声 `zm_010` 离线合成24kHz单声道PCM16。只分发输出，不分发模型/引擎，不标为CC0。许可、固定revision、声线与逐句语速见 [生成说明](../tools/cinematic/voice_assets.md) / [manifest](../tools/cinematic/voice_assets_manifest.json)；旧SAPI生成入口显式阻止执行。

| 文件 | 秒 | SHA-256 |
| --- | ---: | --- |
| `assets/audio/climax/acceptance.wav` | 4.750 | `1eae27b6d41e20875e97c7127ee49e19e87611ac616873b5d2540321ed5e1487` |
| `assets/audio/climax/fear.wav` | 4.300 | `0c29e5a2a67241401922a83417e98af77d4da2fb9b1224eb6318cc3b89cd42fd` |
| `assets/audio/climax/slumber.wav` | 3.925 | `b9a21c2ceccd7e0f8e4b5fe4465e9a7642e28b1a026e45195ca17e07e17e3ef6` |
| `assets/audio/climax/sorrow.wav` | 3.875 | `8b9ba389106621f512d9f3c53f988a69ffb0a06fd5a5002ffeab091bf509f3df` |
| `assets/audio/climax/spite.wav` | 3.925 | `a8df488d0d9dc479a7ad532e8f43753a878edc1fa81cedc1478366ab05b0d3c2` |

## #150 无瑕镜像与失控对白（2026-11-10）

Boss复用已登记原始24骨晶体人形、手枪/短刃与56预切碎片，白晶Shader、打印环、护盾和超新星为本项目原创。皇冠复用#147简洁普通冠。原始GLB均未修改。

“你简直无药可救了！！”使用#147登记的官方Apache-2.0 Kokoro-82M-v1.1-zh标准女声 `zf_001` 离线生成，语速1.12，24kHz单声道PCM16，2.825秒。原桌面SAPI语音已完全替换，输出不标CC0，旧生成脚本显式拒绝执行。来源、模型哈希和全部参数见 [语音说明](../tools/cinematic/voice_assets.md)。

`assets/audio/climax/crown_breakdown.wav` SHA-256: `6c8c2003662b3e8d414949eb935a36172cbf5dc5c0c99e7ae7abef217481b828`。

## #176 怠惰程序声景（2026-11-10）

`audio/realms/realm_sound_bank.gd` 为项目原创数学音频生成器，使用仓库 MIT 许可；无外部采样或旧工程素材。暖音垫、钟摆、心跳、齿轮、秒针和延爆由正弦波、指数包络和私有固定种子噪声合成，运行时缓存 22050 Hz / PCM16 / 立体声；环境循环 4 秒、单次音效 0.8 秒。只发布生成代码，不新增音频二进制。生成源 SHA-256：`a901216c0ea0b1c8bf519a9304aaf8ead69089a67382038260facd287a9f3c92`。行为与听感验收边界见 [#176 证明](proof/issue-176/README.md)。

## #179 悲伤镜潭程序声景（2026-11-10）

`audio/realms/sorrow_sound_bank.gd` 为项目原创数学合成器，沿用仓库 MIT 许可；没有外部采样或旧工程素材。使用正弦共鸣、指数包络与私有 RNG（固定种子 179），缓存 22050 Hz / PCM16 / 单声道。雨声循环 4 秒；水钟 2.4 秒、回流水波 1.1 秒、泪晶喷射与滑水各 0.65 秒、玻璃碎响 0.42 秒、涉水 0.6 秒。生成代码 SHA-256：`19681f0238224a6a7761edccf4999a01fcea085ade2854094cec79718498dae3`。只发布代码，不新增音频二进制；触发/生命周期证据和人工听感未验收边界见 [#179 证明](proof/issue-179/README.md)。

## #170 光固化打印（2026-11-10）

打印网格、光锥、激光环、48 个 GPU 火星与 2.5 秒蜂鸣均为项目原创代码生成，遵循仓库 MIT 许可；未新增下载素材，原白晶人形、皇冠和语音原件不变。声音采用 780/1561 Hz 激光双音、118 Hz 步进振荡与 210 Hz 锁合音，复用 `ProceduralAudio` 的 PCM 输出。源文件 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `levels/climax/print_projection.gd` | `5ec627e1d6c5df0c566fc2a0fe13b9527424814803e59a741e4df705888d2b1f` |
| `levels/climax/shaders/print_slice.gdshader` | `0453a5a741adfe42593a649ce80762664f2d60015a18de73f7caf7a110adbef4` |
| `levels/climax/shaders/print_projection.gdshader` | `000ee2fe28d125d5dd66b73cbe3da7b270fc1750501c84c55968a38aa662620c` |

## #168 四系晶屑（2026-11-10）

`assets/particles/crystal_burst.gd` 以平面法线八面体、程序圆环与 GPU 粒子生成琥珀、幽紫、绯红、苍蓝四系反馈。全部为本项目原创代码，遵循仓库 MIT 许可，无第三方模型或贴图。生成源 SHA-256：`69c5f09b2afd5e74389387380c7ad427faa8bed84c822dd4bc8b8740bd761ab1`。预建 48 个 emitter、每色 12 个，满池跳过视觉，不改变伤害。原生性能与截图采集开销的区分见 [#168 证明](proof/issue-168/README.md)。

## #169 镜潭与白色细雨（2026-11-10）

水面着色器、雨丝粒子场景、共享雨滴布局与运动着色器均为本项目原创代码和程序几何，由 Codex 协助实现；许可随项目代码，不新增第三方素材许可，也不另行标为 CC0。未从旧工程或其他游戏复制模型、纹理、音频；既有角色、普通皇冠及建筑资源保持原件。

| 文件 | 来源 / 许可 | SHA-256 |
| --- | --- | --- |
| `environments/sorrow/water_mirror.gdshader` | 本项目原创 / 随项目代码 | `80b0d3299f3c3ec6d3e432472bb69753148c65ddfbffeabd22ab9c0093c2312d` |
| `environments/sorrow/rain_motion.gdshader` | 本项目原创 / 随项目代码 | `ee29297909b03199b7e02a0dfedc949237849579be4d6cd14ca2b439a912dc90` |
| `environments/sorrow/rain_layout.gdshaderinc` | 本项目原创 / 随项目代码 | `0c2c8b8fd7f60e9f656a0c50ad0ee74afa0f643d324713b9ea68e80b08dbaecb` |
| `environments/sorrow/rain_particles.tscn` | 本项目原创 / 随项目代码 | `aec0583e9876053510e143059cd2bb25d367c61860b9535467ba98ab2def52b9` |

五张证明图片是 Godot 4.7.2 Forward+ 的真实悲伤第一房原生截图，包括固定视角、固定时钟的 SSR 开关对照；来源、完整图片 SHA-256、验证与边界见 [README](proof/issue-169/README.md) 和 [manifest](proof/issue-169/manifest.json)。

## #172 皇冠眩光与暗金金缮（2026-11-10）

两套 Shader 与 `KintsugiFlow` 均为本项目原创代码，由 Codex 协助实现，许可随项目代码；没有外部贴图、模型或新音频，未新增第三方许可或另标 CC0。金缮复用既有原身体的 CUSTOM0 真实边掩码、56 碎片、11 蒙皮部位与 24 骨，原 GLB 不变；皇冠仍为 #147 登记的普通皇冠。

| 文件 | 来源 / 许可 | SHA-256 |
| --- | --- | --- |
| `ui/shaders/blinding_glare.gdshader` | 本项目原创 / 随项目代码 | `e70f196bfd87109fa4093563bac9332b9ae3364eee12c412965607ff8052ffec` |
| `actors/player/shaders/kintsugi_gold.gdshader` | 本项目原创 / 随项目代码 | `e506acf78ce7041fcd8c3f3cfacdfc5c0e21905410b5a755504e1f44f00275ed` |
| `actors/player/kintsugi_flow.gd` | 本项目原创 / 随项目代码 | `ab63fb81977169ea6121b4789913c983b1b3b62880435e2953108cc3c6a23a53` |

五张原生证明由 Godot 4.7.2 Forward+ 直接捕获，包括皇冠等级对照、原身体金缮全身/接缝近景和真实皇冠投影；外部相机仅用于审阅。图像与验证日志哈希见 [SHA256SUMS](proof/issue-172/SHA256SUMS)，行为验证与独立无截图性能采样见 [README](proof/issue-172/README.md)。

## #175 心象日记文案与界面证据（2026-11-10）

- 叙事源文件为 [`ui/codex/lore_entries.gd`](../ui/codex/lore_entries.gd)：本项目原创、AI 辅助撰写并审阅的虚构文案，包含五篇学术答辩手记与四组心魔双面档案。内容按 #175 和创作愿景编写，未摘录外部文章或使用第三方故事素材，不另声明 CC0。源文件 SHA-256：`08d8e808258394014a844aae8bea12cc3569673e69e380d77a5b57f8dd8c871e`。
- `LoreDiary` / `ArchiveReader` 的布局与控件为本项目原创实现，使用现有工程的界面与字体配置；本次没有新增下载字体、模型、贴图或配音。
- [`docs/proof/issue-175/`](proof/issue-175/) 的 16 张 PNG 来自 Godot 4.7.2 Forward+ 原生运行：14 张独立状态图由 `tests/lore_diary_proof.tscn` 生成，2 张生产入口图由 `tests/lore_modal_proof.tscn` 生成。全部使用隔离测试进度；图片用于布局/可达性验收，未伪称真实玩家的自然通关记录。
- 14 张独立图的逐文件 SHA-256 见 [screenshots.sha256](proof/issue-175/screenshots.sha256)；2 张生产图的字节数和 SHA-256 见 [production-screenshots.json](proof/issue-175/production-screenshots.json)。场景复用本项目既有资源，没有从 `../origin/` 导入素材；生成命令和人工审阅记录见 [README](proof/issue-175/README.md) 与 [集成证据](proof/issue-175/integration.md)。
