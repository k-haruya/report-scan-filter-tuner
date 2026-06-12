# 🏆 Best Configuration: v072_BG50_TO0.20

**日付**: 2026-02-06
**バージョン**: v072
**ファイル名**: `v072_BG50_TO0.20.jpg`

---

## 最適パラメーター

| パラメーター | 値 | 説明 |
|-------------|-----|------|
| **backgroundBlurRadius** | 50 | 背景除算用の大きなブラー半径 |
| **thresholdOffset** | 0.20 | 二値化の閾値オフセット |
| blurRadius | 25 | 局所適応用ブラー半径 |
| thresholdStrength | 0.8 | 二値化の強さ |
| preMedianIteration | 1 | 事前メディアン回数 |
| postMedianIteration | 1 | 事後メディアン回数 |
| finalSharpness | 0.5 | シャープネス強度 |

---

## 処理フロー（この順序が重要！）

```
1. Perspective Correction (台形補正)
2. Division Normalization (背景除算) ← 影除去の核心
3. Pre Noise Reduction (事前ノイズ除去)
4. Sharpening (シャープネス) ← 二値化の前に適用
5. Adaptive Thresholding (適応的閾値処理)
6. Post Noise Reduction (事後ノイズ除去)
```

---

## 成功の要因

1. **Division Normalization（背景除算）**: 影成分を除算でキャンセルし、背景を均一化
2. **高いThreshold Offset（0.20）**: 正規化後は高めの閾値でも文字が消えず、ノイズが激減
3. **シャープネスを二値化の前に**: エッジ強調後に二値化することで文字が鮮明に

---

## 含まれるファイル

- `FilterParams.swift` - パラメーター定義
- `ImageProcessor.swift` - 画像処理ロジック
- `ParameterSweep.swift` - パラメーター探索
- `FilterTuner.swift` - CLIツール本体
