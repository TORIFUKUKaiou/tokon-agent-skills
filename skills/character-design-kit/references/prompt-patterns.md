# プロンプトの組み立て方

以下は生成前に具体化するひな型。山括弧を埋め、不要な指定は消す。
英語・日本語のどちらでもよい。画像内のタイトル・文字は正確な表記で引用する。
特定ツールのオプション記法を、別ツールへそのまま渡さない。

## 共通仕様

```text
Input images:
- Image 1: character identity reference. Preserve <silhouette, proportions,
  face, colors, materials, clothing, asymmetric details and signature props>.
- Image 2, if supplied: <layout only / style only / established model sheet>.
  Borrow only the specified role; do not transfer unrelated character traits.
Character display name: <name, or omit if not supplied>.
Style and materials: <faithful to identity reference unless otherwise requested>.
Asymmetry: <character's left/right or viewer's left/right, explicitly stated>.
Do not copy unrelated poster text, scenery, characters, or card statistics.
Keep the full silhouette and accessories within generous margins.
```

## 三面図付き設定図

```text
Create a landscape character production sheet, not a scene or promotional poster.
Exactly three orthographic full-body views: FRONT, SIDE, BACK, at matching scale,
consistent proportions, aligned baseline, neutral poses, no perspective rotation
in the front or back views. Separate props that obscure the silhouette into insets.
Add a restrained lower row of color/material swatches, face detail, and signature
accessory studies. Use short readable labels: <exact labels and title>.
Background and graphic accents: <quiet palette appropriate to the character>.
Unseen surfaces are plausible inferred continuations, not established source facts.
Mark inferred views with <exact short note>. Do not mirror the face onto the back.
Avoid arbitrary new anatomy, symbols, costumes or accessories.
```

## 背景透過の単体

```text
Create one isolated full-body character PNG with a TRUE transparent background
and alpha, including interior openings and spaces between limbs and props.
Use the original identity and <model sheet reference, if available> consistently.
Pose: <one clear pose expressing this character's personality>.
Keep all extremities and signature props complete, with transparent margins.
No background, floor, cast shadow, glow, border, text, or painted checkerboard.
Preserve edge detail and the intended material texture.
```

背景透過はプロンプトだけでなく、対応する生成ツールの透過設定でも指定する。

## ポーズ集

```text
Create a character pose sheet with exactly <count> distinct full-body poses
in a <columns by rows> grid. Same character in every cell: consistent anatomy,
colors, materials, clothing, asymmetric details and props, matching the model sheet.
Poses and exact short captions in reading order:
<numbered list of action + expression + prop placement + caption>.
Background and typography: <harmonize with the character sheet>.
Keep full silhouettes inside their cells, separated by generous gutters.
Vary gesture, weight distribution and body orientation, not only facial expression.
No additional characters or unrequested props. No overlapping cells or clipped limbs.
```
