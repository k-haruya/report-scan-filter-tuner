//
//  ParameterSweep.swift
//  FilterTuner
//
//  パラメーター組み合わせを生成
//  Division Normalization + Adaptive Thresholding + Color Preservation
//

import Foundation

/// パラメーター範囲の定義
struct ParameterRanges {

    // ========== Division Normalization ==========

    /// 背景推定用ブラー半径（文字サイズより大きく）
    static let backgroundBlurRadius: [Float] = [30, 40, 50]

    // ========== Adaptive Thresholding ==========

    /// ブラー半径（局所適応用）
    static let blurRadius: [Float] = [20, 25]

    /// 閾値オフセット（Division Normalization後は高めでOK）
    static let thresholdOffset: [Float] = [0.10, 0.15, 0.20]

    /// 閾値強度
    static let thresholdStrength: [Float] = [0.7, 0.8]

    // ========== ノイズ除去（軽量化） ==========

    /// 事前/事後メディアンは軽めでOK
    static let preMedianIteration: [Int] = [0, 1]
    static let postMedianIteration: [Int] = [0, 1]

    /// 最終シャープネス
    static let finalSharpness: [Float] = [0.4, 0.5]

    // ========== 色味強調パラメーター ==========

    /// 色を保持する彩度の閾値（低い値=より多くのピクセルの色を保持）
    static let colorSaturationThreshold: [Float] = [0.05, 0.10, 0.15, 0.25]

    /// 色保持の強度（0=完全B&W, 1=検出した色をそのまま残す）
    static let colorPreservation: [Float] = [0.7, 1.0]

    /// 彩度ブースト倍率（1.0=そのまま, 6.0=6倍に強調）
    static let colorBoost: [Float] = [3.0, 4.0, 5.0, 6.0]
}

/// パラメーター組み合わせを生成
struct ParameterSweep {

    /// 基本パイプラインのパラメータースイープ（従来通り）
    static func generateCombinations(limit: Int? = nil) -> [FilterParams] {
        var combinations: [FilterParams] = []

        for bgBlurRadius in ParameterRanges.backgroundBlurRadius {
            for blurRadius in ParameterRanges.blurRadius {
                for thresholdOffset in ParameterRanges.thresholdOffset {
                    for thresholdStrength in ParameterRanges.thresholdStrength {
                        for sharpness in ParameterRanges.finalSharpness {
                            var params = FilterParams()
                            params.backgroundBlurRadius = bgBlurRadius
                            params.blurRadius = blurRadius
                            params.thresholdOffset = thresholdOffset
                            params.thresholdStrength = thresholdStrength
                            params.preMedianIteration = 1
                            params.postMedianIteration = 1
                            params.finalSharpness = sharpness
                            params.postNoiseLevel = 0
                            combinations.append(params)
                        }
                    }
                }
            }
        }

        if let limit = limit, combinations.count > limit {
            combinations.shuffle()
            combinations = Array(combinations.prefix(limit))
        }

        return combinations
    }

    /// 色味パラメーターのスイープ（基本パイプラインは最適値で固定）
    static func generateColorCombinations(limit: Int? = nil) -> [FilterParams] {
        var combinations: [FilterParams] = []

        // まず colorPreservation = 0 (色なし) をベースラインとして1つ追加
        var baseline = FilterParams()
        baseline.colorPreservation = 0.0
        combinations.append(baseline)

        // 色味パラメーターのみスイープ
        for satThreshold in ParameterRanges.colorSaturationThreshold {
            for preservation in ParameterRanges.colorPreservation {
                for boost in ParameterRanges.colorBoost {
                    var params = FilterParams()
                    // 基本パイプラインは最適値で固定（FilterParams デフォルト値が最適値）
                    params.colorSaturationThreshold = satThreshold
                    params.colorPreservation = preservation
                    params.colorBoost = boost
                    combinations.append(params)
                }
            }
        }

        if let limit = limit, combinations.count > limit {
            // ベースラインは必ず含める
            let baselineParam = combinations.removeFirst()
            combinations.shuffle()
            combinations = [baselineParam] + Array(combinations.prefix(limit - 1))
        }

        return combinations
    }

    /// ノイズ＋文字強調チューニング（色パラメーター固定、TO/TS/CT/DF/PostMをスイープ）
    static func generateNoiseCombinations(limit: Int? = nil) -> [FilterParams] {
        var combinations: [FilterParams] = []

        let toValues: [Float] = [0.20, 0.25, 0.30]
        let ctValues: [Float] = [2.0]
        let dfValues: [Float] = [0.0, 0.65, 0.80]

        for to in toValues {
            for ct in ctValues {
                for df in dfValues {
                    var params = FilterParams()
                    params.thresholdOffset = to
                    params.thresholdStrength = 0.95
                    params.finalContrast = ct
                    params.darkFloor = df
                    params.backgroundBlurRadius = 30
                    params.preMedianIteration = 0
                    params.postMedianIteration = 1
                    // 色パラメーターは採用値で固定
                    params.colorSaturationThreshold = 0.25
                    params.colorPreservation = 1.0
                    params.colorBoost = 6.0
                    combinations.append(params)
                }
            }
        }

        if let limit = limit, combinations.count > limit {
            combinations.shuffle()
            combinations = Array(combinations.prefix(limit))
        }

        return combinations
    }

    static func generateDetailedCombinations(limit: Int? = nil) -> [FilterParams] {
        return generateCombinations(limit: limit)
    }

    static var totalNoiseCombinations: Int {
        3 * 1 * 3 // TO × CT × DF
    }

    static var totalBasicCombinations: Int {
        ParameterRanges.backgroundBlurRadius.count *
        ParameterRanges.blurRadius.count *
        ParameterRanges.thresholdOffset.count *
        ParameterRanges.thresholdStrength.count *
        ParameterRanges.finalSharpness.count
    }

    static var totalColorCombinations: Int {
        1 + // baseline (NoColor)
        ParameterRanges.colorSaturationThreshold.count *
        ParameterRanges.colorPreservation.count *
        ParameterRanges.colorBoost.count
    }

    static var totalDetailedCombinations: Int {
        totalBasicCombinations
    }
}
