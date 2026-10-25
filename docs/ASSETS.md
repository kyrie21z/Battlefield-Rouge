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

## 流派与完美打击的可读性

给 AC-06 / AC-08 的图标，以及完美打击的闪光。效果数值仍 Design-TBD。

| 对象 | 读法 |
| --- | --- |
| 狂战士（Berserker） | 红 + 斧头剪影 |
| 军火大亨（Arms Dealer） | 黄 + 弹药剪影 |
| 鹰眼（Hawkeye） | 青（cyan）+ 准星剪影 |
| 完美打击成功 | 白闪，并有和失败分开的反馈 |
| 完美打击失败 | 不闪白 |

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

## 代码生成的素材

| 内容 | 位置 | 许可证 |
| --- | --- | --- |
| 枪声、换弹声、空仓声 | `weapons/procedural_audio.gd`，运行时生成 | MIT，移植自 Ironline 1944 |
| 准星 | `ui/crosshair.gd`，运行时绘制 | 本项目 |
