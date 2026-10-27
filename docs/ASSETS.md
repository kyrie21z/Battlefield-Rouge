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
