# FilterTuner - 画像フィルターパラメーターチューニングツール

iOSアプリ「ReportScan」の画像処理パラメーターを効率的にチューニングするためのmacOSコマンドラインツールです。
Version 2.0 では、より強力な影除去と文字強調を実現するためにアルゴリズムを刷新しました。

## セットアップ

```bash
cd FilterTuning
swift build
```

## 使い方

### 1. サンプル画像を配置
`samples/` フォルダにチューニング対象の画像を配置してください。

### 2. チューニング実行

```bash
# 基本パイプラインのスイープ
swift run FilterTuner --limit 50

# 色味チューニング（基本パイプライン固定、色パラメーターのみスイープ）
swift run FilterTuner --color -s ./samples -o ./outputs

# ノイズ＋文字強調チューニング（色固定、TO/TS/CT/DFをスイープ）
swift run FilterTuner --noise -s ./samples -o ./outputs

# デバッグモード（中間画像を保存）
swift run FilterTuner --limit 10 --debug

# パラメーター確認のみ
swift run FilterTuner --dry-run
```

### 3. 結果の確認
`outputs/<サンプル名>/` に生成された画像を確認し、ファイル名から最適なパラメーターを特定します。

ファイル名の例（モードにより異なる）:
- 基本: `v001_BG30_TO0.20_TS0.8_CST0.25_CP1.0_CB6.0.jpg`
- 色味: `v001_CST0.25_CP1.0_CB6.0.jpg`
- ノイズ: `v001_TO0.30_TS0.95_CT2.0_DF0.80_PostM1.jpg`

---

## アルゴリズムと試行錯誤の記録 (2025-02)

現在のアルゴリズムは **Adaptive Thresholding (適応的閾値処理)** をベースにしています。
これは局所的な明るさを計算し、各ピクセルごとに閾値を決定する手法で、影の除去に非常に効果的です。

### 課題: ごま塩ノイズ (Salt-and-Pepper Noise)
Adaptive Thresholdingにおいて、影を強力に消すために閾値オフセット(`TO`)を **0.02** 付近まで下げると、紙の繊維や微細な凹凸が黒点（ごま塩ノイズ）として顕著に現れる問題が発生しました。

### 試行策1: Morphological Closing (失敗)
*   **手法**: Dilation（最大値）で黒点を消し、Erosion（最小値）で文字の太さを戻す。
*   **結果**: ノイズと文字（特に画数の多い漢字や細い線）のサイズが近すぎたため、**ノイズを消そうとすると文字まで潰れて読めなくなる**現象が発生。採用見送り。

### 試行策2: Iterative Median Filter (効果限定的)
*   **手法**: 3x3の標準メディアンフィルタを、処理の前（Pre）と後（Post）に複数回（5〜10回）重ね掛けする。
*   **結果**: 
    *   1〜2回の適用ではノイズが取りきれない。
    *   10回適用しても劇的な改善は見られず、むしろ文字の角が丸くなる弊害が出始める。
    *   `TO=0.02` という低閾値におけるノイズ発生量が、単純なメディアンフィルタの除去能力を超えている可能性が高い。

### 解決: Division Normalization の導入 (2026-02-06)
*   **手法**: Adaptive Thresholdingの前段に Division Normalization（背景除算）を導入。大きなGaussianブラーで背景を推定し、`元画像 / 背景` で除算することで影成分をキャンセル。
*   **結果**: 影除去が劇的に改善。TO=0.20まで上げてもテキストが消えなくなり、ノイズも激減。
*   **採用**: BG50 / TO0.20 → `BestConfig_v072_2026-02-06/` に保存。

---

## 色味復元・文字強調の試行錯誤 (2026-02-08)

Division Normalization + Adaptive Thresholding のB&Wパイプラインが安定したため、以下の3つの改善に取り組んだ。

### 課題1: カラー文書の色を残したい

B&Wパイプラインでは赤スタンプや色文字が全て白黒になる。色情報を復元する仕組みが必要。

#### 試行1: DivisionNorm後の画像を色リファレンスに使用 (失敗)
*   **手法**: DivisionNorm後の画像から彩度が高いピクセルの色を抽出し、B&W処理結果にブレンド。
*   **結果**: DivisionNormは `元画像 / 背景` で除算するため、**画像全体が白に近く正規化されて彩度がほぼゼロ**に。NoColor.jpgとほぼ同一の結果。

#### 試行2: 元画像を色リファレンスに変更 (部分成功)
*   **手法**: 台形補正後・DivisionNorm前の元画像を色リファレンスとして使用。クロミナンス比率（色÷輝度）ベースで色を抽出。
*   **結果**: 色は鮮やかに復元されたが、**影の部分が黄色く**なる問題が発生。元画像の影には照明由来の暖色かぶりがあり、それが「色」として検出・増幅された。
    *   低CST（彩度閾値）+ 高CB（ブースト）で顕著: 影の暖色味が3〜6倍に増幅。

#### 試行3: ハイブリッド方式 (成功・採用)
*   **手法**: 2つの画像をそれぞれ最適な用途で使い分け。
    *   **彩度の判定**: DivisionNorm後の画像（影の色かぶり除去済み → 影エリアの彩度≈0で通過しない）
    *   **色の抽出**: 元画像（鮮やかな色情報がそのまま残っている）
*   **結果**: 影の黄色化が完全に解消。色付き領域のみ正確に検出・復元。
*   **採用パラメーター**: CST=0.25 / CP=1.0 / CB=6.0

### 課題2: 黒文字がAdobe製品と比べて弱い

Adobe Scanなどと比較すると、テキストの黒さ・くっきり感が不足していた。

#### 対策: thresholdStrength + 最終コントラスト強調
*   **thresholdStrength 0.8→0.95**: `mix(元画像, 二値化結果, TS)` のTSを上げ、テキストをより黒に。色復元はTS後に行われるため、色付き領域への影響なし。
*   **最終コントラスト（CIColorControls, contrast=2.0）**: 全処理（色復元含む）の最終段に追加。暗い部分をさらに暗く、明るい部分をさらに明るくし、Adobe風のくっきり感を実現。

### 課題3: 「重」等の塗りつぶし部分が白くなる

画数の多い漢字や太字の内部が白抜けする、B&Wパイプラインで最大の課題。

#### 原因
DivisionNormが大きな黒領域を中間グレー（≈0.67）に正規化 → Adaptive Thresholdingの局所背景も同じ明るさ → 「背景」と誤判定 → 白に。

#### 試行1: 元画像（DivisionNorm前）の絶対輝度フロア (失敗)
*   **手法**: 元画像の輝度が閾値以下なら問答無用でテキスト判定。
*   **結果**: 塗りつぶし部分は保護できたが、**影エリアも元画像では暗い（≈0.30）ため、影が全て真っ黒**になった。

#### 試行2: DivisionNorm後の輝度フロア (部分成功)
*   **手法**: DivisionNorm後の画像で輝度チェック。影はDivNormで白（≈0.90）に正規化済みなので誤判定しない。
*   **結果**: 影の黒化は解消。しかし緑文字などの色テキストもDivNorm後の輝度が低い（≈0.33）ため、darkFloorに巻き込まれて黒くなる問題が発生。

#### 試行3: DivisionNorm後の輝度フロア + 彩度チェック (成功・採用)
*   **手法**: darkFloorの条件に「DivNorm後の彩度が低い（< 0.3）」を追加。
    *   黒インクの塗りつぶし → 彩度≈0 → darkFloor適用 → 黒に保護 ✓
    *   緑文字 → 彩度≈0.61 → darkFloorスキップ → 通常のAdaptive Threshold + 色復元 ✓
    *   影エリア → DivNorm後の輝度≈0.90 → darkFloor閾値を超えない → 影響なし ✓
*   **採用パラメーター**: DF=0.80（DivNorm後の輝度フロア）、彩度チェック閾値=0.3

### ノイズ除去

*   **TO（閾値オフセット）を0.30に引き上げ**: DivisionNorm後は高い閾値でもテキストが消えず、ごま塩ノイズが激減。
*   **事後メディアン（PostM=1）**: 残ったごま塩ノイズの最終除去。事前メディアン（PreM）は効果が限定的なため0に固定。

---

## 最終採用パラメーター (2026-02-08)

| パラメーター | 値 | 説明 |
|-------------|-----|------|
| **backgroundBlurRadius** | 30 | 背景除算用ブラー半径 |
| **thresholdOffset** | 0.30 | 二値化の閾値オフセット |
| **thresholdStrength** | 0.95 | 二値化の強さ |
| **darkFloor** | 0.80 | 塗りつぶし保護の輝度フロア（DivNorm後基準） |
| **finalContrast** | 2.0 | 最終コントラスト強調 |
| blurRadius | 25 | 局所適応用ブラー半径 |
| preMedianIteration | 0 | 事前メディアン（不要） |
| postMedianIteration | 1 | 事後メディアン |
| finalSharpness | 0.5 | シャープネス強度 |
| colorSaturationThreshold | 0.25 | 色検出の彩度閾値 |
| colorPreservation | 1.0 | 色保持の強度 |
| colorBoost | 6.0 | 彩度ブースト倍率 |

### 処理フロー（8ステップ）

```
1. Perspective Correction (台形補正)
   ↓ ★ colorReference保存（色抽出用）
2. Division Normalization (背景除算)
   ↓ ★ divNormReference保存（彩度判定用 + darkFloor判定用）
3. Pre Noise Reduction → OFF (preMedian=0)
4. Sharpening (Unsharp Mask)
5. Adaptive Thresholding + darkFloor（塗りつぶし保護、彩度チェック付き）
6. Post Noise Reduction (Median Filter × 1)
7. Color Preservation（ハイブリッド方式: divNormRefで彩度判定、colorRefから色抽出）
8. Final Contrast Enhancement (contrast=2.0)
```
