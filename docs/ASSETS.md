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
- 重新导出：`blender --background --python tools/export_gun_models.py`。

## 三把近战模型的导出

`knife.glb`、`axe.glb`、`tachi.glb` 都是从上面登记过的源文件里**导出**的，不是原始文件：

- 握点挪到原点，刃朝 -Z（Godot 的前方），刀面法线朝 +X。三个模型同一个约定，换一把不用改代码。
- 握点判定看的是「哪一端更窄」，但弯刀的护手比手柄宽（19 cm 对 5 cm），这条规则会把手握点判到刀尖。所以 `tools/export_melee_models.py` 里那把刀显式写 `grip_at="wide"`，导完再用截图核对握点在哪一头。
- 长度统一到手感的实际尺寸：匕首 0.46 m、斧 0.92 m、太刀 1.00 m。原始文件分别大 3.1 倍、1.1 倍、1.2 倍。
- **握点之后的部分会被切掉**（`trim_behind_grip`，目前只给斧开）：第一人称模型没有手，握点后面那截柄会吊在眼睛前面，斧的圆形柄头在挥砍全程就是一坨灰球。斧的握点定在离柄尾 20%（落在棕色木柄上），切面盖平，所以画面里看到的是柄的截面。
- 两个 FBX 自带一张内嵌贴图 `Atlas_Pirate.png`；GLB 里贴图是嵌进去的，Godot 导入时抽成 `axe_Atlas_Pirate.png` / `tachi_Atlas_Pirate.png` 放在模型旁边。这两个 PNG 是导入产物，不是新素材。
- 重新导出：`blender --background --python tools/export_melee_models.py`。改 `target_length` 或 `grip_inset` 之后要同步改 `.tres` 里的 `blade_length`（= `(1 - grip_inset) * target_length`）：匕首 0.405、斧 0.736、太刀 0.88。

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

按用户要求将已完成的 Sloth 开场任务 #45 开场放在本游戏启动前。`ui/pride_opening/assets/pride-atlas.png` 为本次项目内 imagegen 生成与编辑的六格透明图集（1024×1536），不是从 `origin` 或剧集提取的素材，不标为 CC0。仅借鉴用户给出的复古卡通表演参考，没有提交剧集截图或原角色素材。来源、提示词和手绘皇冠设计见 [生成记录](levels/sloth-opening/assets/PROMPT.md)。

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
