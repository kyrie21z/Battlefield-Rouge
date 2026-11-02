# Pride 图像生成记录

最终版在透明边界修正后，又按用户反馈用下列提示词直接编辑本地图集，使瞳孔居中、看向玩家。中间一张偏离手绘风格的高亮金属变体未采用、未提交。

```text
Precise small edit of this EXACT image, not a redesign. Preserve every crown silhouette, six gestures, cell arrangement, scale, central dark diamonds, cream face, dark lower band, black rubber-hose arms, beige gloves, muted hand-painted gold shading and original retro ink style. The ONLY edit is within the ivory eye whites: shift the existing black pupils to the CENTRE of each eye so each face looks straight forward at the viewer, not left or right. Existing pupils must remain the same tall simple black vintage shape, NOT brown glossy irises, not a modern emoji face. In the wink pose centre the pupil of the single open eye. Do not move eyebrows, mouths, hands, or any silhouette. Keep exact original 1024x1536 PNG 2-column 3-row sprite sheet layout with transparent alpha margins. Do not add a background, eye colour, shine, glow, props or different expressions. Only pupil position changes; all else locked to the referenced original.
```

2026-11-01，使用内置 imagegen 技能与工具生成。用户提供的《洛基》截图仅作复古卡通表演参考，原截图未上传仓库。角色设计仍供团队评审。

最终文件：本目录的 `pride-concept.jpg`（概念图，仅 JPEG 重编码）以及 `ui/pride_opening/assets/pride-atlas.png`（预演实际使用的 1024×1536 RGBA 六格动作图集）。动作图经内置工具修正边界，未用脚本重绘或抠图。最终切格边缘 alpha 为 0；实际绘制面另外保留 14% 余量，六格源图与 20 个原生绘制姿态均检查外围透明。

## 概念设计

```text
Use case: stylized-concept
Asset type: original game character design sheet for Mind Freak, Pride / The Crown
Primary request: design an anthropomorphic wearable crown companion, inspired by the attached reference ONLY for friendly 1930s rubber-hose animation expressiveness and clean graphic readability. Subject is a CROWN, never a round clock. The reference image is style/mood reference, not an edit target.
Subject: a low wide five-point ivory and muted brass crown, taller middle point, charcoal bottom band, small dark diamond central emblem, expressive tall cream eyes with black pupils embedded in the front band, neat asymmetric brows, small confident smile. Tiny flexible charcoal arms with ivory three-finger mitten hands appear for dialogue gestures and tuck into side ornaments; no legs or shoes. Clearly hollow/open wearable crown in three-quarter view. A sincere encouraging guide with poise and pride, not sinister or manipulative.
Style/medium: restrained hand-inked cel animation character sheet, thick clean charcoal contour, flat warm ivory and desaturated brass shading, a little paper grain. Suitable for an abstract gray-white geometric FPS world; crown remains a graphic talking avatar rather than a human NPC.
Composition/framing: landscape light warm gray sheet; one large front view left, one smaller three-quarter wearable view upper-right, four small facial acting poses below/right (greeting, explaining, quietly waiting, encouraging). Generous whitespace. Show fully contained silhouettes and gestures.
Color palette: warm ivory #E9DFC8, muted brass #B69A56, charcoal #24282A; no orange clockface, no clock numerals or hands, no TVA symbols, no source watermark. Warm crown colour is matte surface, not a luminous healing aura.
Text: only a small heading 'PRIDE / THE CROWN', no other labels.
Constraints: keep crown silhouette consistent across views; no realistic textures, no villain face, no weapon, no humanoid torso, no feet; present as development concept, not final production asset.
```

## 六格动作图集

```text
Use case: stylized-concept / game sprite atlas
Asset type: production-ready transparent character sprite sheet for Pride / The Crown in a Godot opening animation.
Input image: the user's latest attached PRIDE / THE CROWN concept sheet is the exact character and rendering reference. Preserve its curved open crown, three visible gold ball-tipped peaks, cream curved front with very subtle paper-grain/cel shading, thick organic dark contour, central black diamond, large vintage eyes with lashes and expressive asymmetric eyebrows, dark lower rim, rubber-hose black arms and ivory glove hands. Match its warm ivory, muted shaded gold, and hand-painted dimensionality closely. No legs.
Primary request: ONE transparent PNG sprite atlas, exactly TWO columns and THREE rows, six equal-sized invisible cells, portrait canvas aspect 2:3. EACH cell contains one COMPLETE isolated crown, no text, NO cell lines and NO background. All characters at identical scale and aligned body height, centred within each cell. Keep at least 10 percent empty transparent margin to all cell edges including extended hands and crown top. Hands and contour must be fully contained, absolutely no clipped fingers or arms. Crown bodies may vary expression but maintain same identity and proportion.
Cell order, reading left-to-right:
top-left: greeting, happy small open smile, left glove waving raised up;
top-right: same greeting character and body alignment, left glove waving slightly outwards, alternate wave pose, same smile;
middle-left: explaining, one open palm pointing/presenting outward, attentive eyes, small speaking mouth;
middle-right: encouraging, confident warm smile and right glove thumbs-up;
bottom-left: quietly waiting, both gloves resting at lower rim, mild friendly smile;
bottom-right: thoughtful attentive nod, one eyebrow slightly lifted, small closed smile, both hands visible.
Style/medium: polished hand-inked retro cel-animation sprites. Keep the original's elegant gently curved crown silhouette and dimensional painted gold/ivory facets, avoid flat triangular cheap icon look.
Constraints: transparent alpha background; NO beige paper rectangle, no grey floor shadows, no labels, no checkerboard, no logo; not a clock; equal cells exactly, 2 columns x 3 rows; no parts cross cell boundaries. Use sufficiently large raster resolution so gloves and ink contour remain smooth in a 200–300px rendered character.
```

## 最终透明边界修正

```text
Edit the supplied transparent Pride sprite atlas, preserving the same character, colours, expressions, six poses, hand-painted cel texture and 1024x1536 portrait canvas. Crucial production correction: layout must be EXACTLY 2 columns x 3 rows of 512x512 cells. Shrink EACH of the six complete character silhouettes to maximum 380 pixels wide and 380 pixels tall, and centre it exactly at cell centres (256,256), (768,256), (256,768), (768,768), (256,1280), (768,1280). This leaves at least 66 pixels fully transparent on every side INSIDE EVERY CELL. All hands, gesture lines, gloves, arms and outlines must fit within that 380x380 area. Do not crop ANY character element. No silhouette may touch or cross x=0, x=512, x=1024, y=0, y=512, y=1024, y=1536. Empty margins must be alpha-zero transparent, no background haze or shadows. Keep the existing six poses in the same order; no text or cell borders. This edit only corrects spacing and scale, not the character design.
```
