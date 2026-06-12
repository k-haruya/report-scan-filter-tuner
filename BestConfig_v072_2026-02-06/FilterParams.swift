//
//  FilterParams.swift
//  FilterTuner
//
//  パラメーターチューニング用の構造体
//  Division Normalization + Adaptive Thresholding 対応
//

import Foundation
import CoreGraphics

/// チューニング対象のフィルターパラメーター
struct FilterParams: CustomStringConvertible {
    
    // ========== Division Normalization パラメーター（NEW） ==========
    
    /// 背景推定用ブラー半径（文字より大きく設定: 30〜50）
    var backgroundBlurRadius: Float = 40.0
    
    // ========== Adaptive Thresholding パラメーター ==========
    
    /// ブラー半径: 局所背景推定のためのブラーサイズ
    var blurRadius: Float = 25.0
    
    /// 閾値オフセット: 背景輝度からどれだけ暗いと文字とみなすか
    /// Division Normalization後は 0.10〜0.20 が安全
    var thresholdOffset: Float = 0.15
    
    /// 閾値強度: 二値化の強さ（0=元画像維持, 1=完全二値化）
    var thresholdStrength: Float = 0.8
    
    // ========== ノイズ除去パラメーター ==========
    
    /// 事前メディアンフィルター適用回数 (0=OFF)
    var preMedianIteration: Int = 1
    
    /// 事前ノイズ除去レベル: CINoiseReductionの強度（0〜0.1）
    var preNoiseLevel: Float = 0.02
    
    /// 事後ノイズ除去レベル: CINoiseReductionの強度（0〜0.1）
    var postNoiseLevel: Float = 0.0
    
    /// 事後メディアンフィルター適用回数 (0=OFF)
    var postMedianIteration: Int = 1
    
    // ========== 最終シャープネス ==========
    
    var finalSharpness: Float = 0.5
    
    // ========== 従来のパラメーター（フォールバック用） ==========
    
    var saturation: Float = 0.8
    var brightness: Float = 0.1
    var contrast: Float = 1.05
    var toneCurvePoint0Y: CGFloat = 0.15
    var toneCurvePoint1Y: CGFloat = 0.45
    var toneCurvePoint2Y: CGFloat = 0.6
    var toneCurvePoint3Y: CGFloat = 0.85
    
    /// ファイル名用の短縮表記
    var description: String {
        return String(format: "BG%.0f_BR%.0f_TO%.2f_TS%.1f",
                      backgroundBlurRadius, blurRadius, thresholdOffset, thresholdStrength)
    }
    
    /// 短いファイル名
    var shortDescription: String {
        return String(format: "BG%.0f_TO%.2f",
                      backgroundBlurRadius, thresholdOffset)
    }
}
