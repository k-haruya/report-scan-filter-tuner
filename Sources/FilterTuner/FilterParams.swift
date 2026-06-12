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

    // ========== Division Normalization パラメーター ==========

    /// 背景推定用ブラー半径（文字より大きく設定: 30〜50）
    var backgroundBlurRadius: Float = 30.0

    // ========== Adaptive Thresholding パラメーター ==========

    /// ブラー半径: 局所背景推定のためのブラーサイズ
    var blurRadius: Float = 25.0

    /// 閾値オフセット: 背景輝度からどれだけ暗いと文字とみなすか
    var thresholdOffset: Float = 0.10

    /// 閾値強度: 二値化の強さ（0=元画像維持, 1=完全二値化）
    var thresholdStrength: Float = 0.8

    /// 絶対輝度フロア: DivisionNorm後でこの輝度以下なら必ずテキスト判定
    /// 「重」等の塗りつぶし部分がAdaptive Thresholdで白化されるのを防ぐ
    /// 影はDivNormで白(≈0.90)に正規化済みなので誤判定しない
    var darkFloor: Float = 0.65

    // ========== ノイズ除去パラメーター ==========

    /// 事前メディアンフィルター適用回数 (0=OFF)
    var preMedianIteration: Int = 1

    /// 事前ノイズ除去レベル: CINoiseReductionの強度（0〜0.1）
    /// iOS版では使用していない（0固定）
    var preNoiseLevel: Float = 0.0

    /// 事後ノイズ除去レベル: CINoiseReductionの強度（0〜0.1）
    var postNoiseLevel: Float = 0.0

    /// 事後メディアンフィルター適用回数 (0=OFF)
    var postMedianIteration: Int = 1

    // ========== 最終シャープネス ==========

    var finalSharpness: Float = 0.5

    // ========== 色味強調パラメーター（NEW） ==========

    /// 色を保持する彩度の閾値（これ以上の彩度のピクセルは色を残す）
    /// 低い値 = より多くのピクセルの色を保持、高い値 = はっきり色がついたものだけ保持
    var colorSaturationThreshold: Float = 0.15

    /// 色保持の強度（0=完全B&W, 1=検出した色をそのまま残す）
    var colorPreservation: Float = 0.0

    /// 彩度ブースト倍率（保持した色の彩度をさらに強調）
    /// 1.0=そのまま, 1.5=1.5倍に強調, 2.0=2倍に強調
    var colorBoost: Float = 1.0

    // ========== 最終コントラスト強調 ==========

    /// 最終コントラスト（色復元後に適用。1.0=変化なし、高い=黒が締まり白が飛ぶ）
    var finalContrast: Float = 1.0

    // ========== 従来のパラメーター（フォールバック用） ==========

    var saturation: Float = 0.8
    var brightness: Float = 0.1
    var contrast: Float = 1.05
    var toneCurvePoint0Y: CGFloat = 0.15
    var toneCurvePoint1Y: CGFloat = 0.45
    var toneCurvePoint2Y: CGFloat = 0.6
    var toneCurvePoint3Y: CGFloat = 0.85

    /// ファイル名用の短縮表記（全パラメーター）
    var description: String {
        return String(format: "BG%.0f_TO%.2f_TS%.1f_CST%.2f_CP%.1f_CB%.1f",
                      backgroundBlurRadius, thresholdOffset, thresholdStrength,
                      colorSaturationThreshold, colorPreservation, colorBoost)
    }

    /// 短いファイル名（色味パラメーターに特化）
    var shortDescription: String {
        if colorPreservation > 0 {
            return String(format: "CST%.2f_CP%.1f_CB%.1f",
                          colorSaturationThreshold, colorPreservation, colorBoost)
        } else {
            return "NoColor"
        }
    }

    /// ノイズチューニング用のファイル名
    var noiseDescription: String {
        return String(format: "TO%.2f_TS%.2f_CT%.1f_DF%.2f_PostM%d",
                      thresholdOffset, thresholdStrength, finalContrast, darkFloor, postMedianIteration)
    }
}
