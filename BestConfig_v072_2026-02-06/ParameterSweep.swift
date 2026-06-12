//
//  ParameterSweep.swift
//  FilterTuner
//
//  パラメーター組み合わせを生成
//  Division Normalization + Adaptive Thresholding
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
}

/// パラメーター組み合わせを生成
struct ParameterSweep {
    
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
    
    static func generateDetailedCombinations(limit: Int? = nil) -> [FilterParams] {
        return generateCombinations(limit: limit)
    }
    
    static var totalBasicCombinations: Int {
        ParameterRanges.backgroundBlurRadius.count *
        ParameterRanges.blurRadius.count *
        ParameterRanges.thresholdOffset.count *
        ParameterRanges.thresholdStrength.count *
        ParameterRanges.finalSharpness.count
    }
    
    static var totalDetailedCombinations: Int {
        totalBasicCombinations
    }
}
