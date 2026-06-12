//
//  ImageProcessor.swift
//  FilterTuner
//
//  CoreImage フィルター処理
//  Adaptive Thresholding + ノイズ除去
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import Vision

/// 画像処理サービス（macOS版）
class ImageProcessor {
    private let context = CIContext()
    
    // Adaptive Thresholdingのカーネル
    private lazy var adaptiveThresholdKernel: CIColorKernel? = {
        let kernelSource = """
        kernel vec4 adaptiveThreshold(__sample pixel, __sample blurred, float offset, float strength) {
            float brightness = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
            float background = dot(blurred.rgb, vec3(0.299, 0.587, 0.114));
            float threshold = background - offset;
            
            // 閾値より暗い部分を文字として検出
            float textMask = brightness < threshold ? 1.0 : 0.0;
            
            // strengthで元画像とのブレンド率を調整
            vec3 result = mix(pixel.rgb, vec3(1.0 - textMask), strength);
            
            return vec4(result, 1.0);
        }
        """
        return CIColorKernel(source: kernelSource)
    }()
    
    // Division Normalization (背景除算) のカーネル
    private lazy var divisionNormalizationKernel: CIColorKernel? = {
        let kernelSource = """
        kernel vec4 divisionNormalize(__sample original, __sample background) {
            vec4 origColor = original;
            vec4 bgColor = background;
            
            // 背景で除算して正規化（暗い影をキャンセル）
            // 0除算防止のために最小値を設定
            float minBg = 0.01;
            float r = bgColor.r > minBg ? origColor.r / bgColor.r : origColor.r;
            float g = bgColor.g > minBg ? origColor.g / bgColor.g : origColor.g;
            float b = bgColor.b > minBg ? origColor.b / bgColor.b : origColor.b;
            
            // 結果を0-1にクランプ
            return vec4(clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(b, 0.0, 1.0), 1.0);
        }
        """
        return CIColorKernel(source: kernelSource)
    }()
    
    /// サンプル画像を読み込み
    func loadImage(from path: String) -> NSImage? {
        return NSImage(contentsOfFile: path)
    }
    
    /// 処理済み画像を保存
    func saveImage(_ image: NSImage, to path: String) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw ImageProcessorError.saveFailed
        }
        
        try jpegData.write(to: URL(fileURLWithPath: path))
    }
    
    /// フィルターを適用（デバッグモード対応）
    func applyFilter(to image: NSImage, params: FilterParams, debug: Bool = false, outputDir: String = "") -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmapRep) else {
            return nil
        }
        
        guard let processed = applyDocumentScanFilter(to: ciImage, params: params, debug: debug, outputDir: outputDir),
              let cgImage = context.createCGImage(processed, from: processed.extent) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: image.size)
    }
    
    // MARK: - Private Methods
    
    /// ドキュメントスキャンフィルター
    private func applyDocumentScanFilter(to ciImage: CIImage, params: FilterParams, debug: Bool, outputDir: String) -> CIImage? {
        var currentImage = ciImage
        
        // Helper to save debug image
        func saveDebug(_ img: CIImage, step: String) {
            guard debug, !outputDir.isEmpty else { return }
            guard let cgImage = context.createCGImage(img, from: img.extent) else { return }
            let debugImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            let filename = "Step_\(step).jpg"
            let path = URL(fileURLWithPath: outputDir).appendingPathComponent(filename).path
            try? saveImage(debugImage, to: path)
        }
        
        // Step 1: 台形補正
        currentImage = applyPerspectiveCorrection(to: currentImage) ?? currentImage
        saveDebug(currentImage, step: "01_Perspective")
        
        // Step 2: Division Normalization (背景除算)
        currentImage = applyDivisionNormalization(to: currentImage, params: params) ?? currentImage
        saveDebug(currentImage, step: "02_DivisionNorm")
        
        // Step 3: 事前ノイズ除去（メディアンフィルター）
        // ポイント: 背景を白くした後に、紙のざらつきを均す
        currentImage = applyPreNoiseReduction(to: currentImage, params: params) ?? currentImage
        saveDebug(currentImage, step: "03_PreNoise")
        
        // Step 4: シャープネス（二値化の前に適用！）
        // ポイント: エッジを強調してから二値化することで、文字が鮮明になる
        currentImage = applyFinalSharpening(to: currentImage, params: params) ?? currentImage
        saveDebug(currentImage, step: "04_Sharpen")
        
        // Step 5: Adaptive Thresholding
        currentImage = applyAdaptiveThreshold(to: currentImage, params: params) ?? currentImage
        saveDebug(currentImage, step: "05_AdaptiveThreshold")
        
        // Step 6: 事後ノイズ除去 (Median Filter)
        currentImage = applyPostNoiseReduction(to: currentImage, params: params) ?? currentImage
        saveDebug(currentImage, step: "06_PostNoise")
        
        return currentImage
    }
    
    /// 背景除算 (Division Normalization)
    /// 影成分をキャンセルして画像全体を均一化する
    private func applyDivisionNormalization(to ciImage: CIImage, params: FilterParams) -> CIImage? {
        guard let kernel = divisionNormalizationKernel else { return ciImage }
        
        // 1. 背景推定: 大きなブラーで文字を消す
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = ciImage
        blur.radius = params.backgroundBlurRadius
        guard let background = blur.outputImage else { return ciImage }
        
        // 2. 除算正規化: 元画像 / 背景
        let extent = ciImage.extent
        guard let normalized = kernel.apply(
            extent: extent,
            arguments: [ciImage, background]
        ) else { return ciImage }
        
        return normalized.cropped(to: extent)
    }
    
    /// 台形補正
    private func applyPerspectiveCorrection(to ciImage: CIImage) -> CIImage? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.3
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        
        guard let results = request.results,
              let rectangle = results.first else {
            return ciImage
        }
        
        let imageSize = ciImage.extent
        let topLeft = CGPoint(
            x: rectangle.topLeft.x * imageSize.width,
            y: rectangle.topLeft.y * imageSize.height
        )
        let topRight = CGPoint(
            x: rectangle.topRight.x * imageSize.width,
            y: rectangle.topRight.y * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: rectangle.bottomLeft.x * imageSize.width,
            y: rectangle.bottomLeft.y * imageSize.height
        )
        let bottomRight = CGPoint(
            x: rectangle.bottomRight.x * imageSize.width,
            y: rectangle.bottomRight.y * imageSize.height
        )
        
        let perspectiveCorrection = CIFilter.perspectiveCorrection()
        perspectiveCorrection.inputImage = ciImage
        perspectiveCorrection.topLeft = topLeft
        perspectiveCorrection.topRight = topRight
        perspectiveCorrection.bottomLeft = bottomLeft
        perspectiveCorrection.bottomRight = bottomRight
        
        return perspectiveCorrection.outputImage
    }
    
    /// 事前ノイズ除去: メディアンフィルター + ノイズリダクション
    private func applyPreNoiseReduction(to ciImage: CIImage, params: FilterParams) -> CIImage? {
        var processed = ciImage
        
        // メディアンフィルター（紙のざらつきを除去） - Iterative
        if params.preMedianIteration > 0 {
            let median = CIFilter.median()
            for _ in 0..<params.preMedianIteration {
                median.inputImage = processed
                processed = median.outputImage ?? processed
            }
        }
        
        // 軽いノイズ除去
        if params.preNoiseLevel > 0 {
            let noise = CIFilter.noiseReduction()
            noise.inputImage = processed
            noise.noiseLevel = params.preNoiseLevel
            noise.sharpness = 0.5
            processed = noise.outputImage ?? processed
        }
        
        return processed
    }
    
    /// Adaptive Thresholding
    private func applyAdaptiveThreshold(to ciImage: CIImage, params: FilterParams) -> CIImage? {
        let originalExtent = ciImage.extent
        
        // 背景推定用ブラー
        let blur = CIFilter.boxBlur()
        blur.inputImage = ciImage
        blur.radius = params.blurRadius
        
        guard let blurred = blur.outputImage else { return ciImage }
        
        // カスタムカーネルでAdaptive Thresholding
        guard let kernel = adaptiveThresholdKernel else {
            return applyFallbackShadowRemoval(to: ciImage, params: params)
        }
        
        let arguments: [Any] = [
            ciImage,
            blurred,
            params.thresholdOffset,
            params.thresholdStrength
        ]
        
        guard let thresholded = kernel.apply(
            extent: originalExtent,
            arguments: arguments
        ) else {
            return applyFallbackShadowRemoval(to: ciImage, params: params)
        }
        
        return thresholded.cropped(to: originalExtent.integral)
    }
    
    /// 事後ノイズ除去: Post-Median Filter（黒点ノイズ除去）
    private func applyPostNoiseReduction(to ciImage: CIImage, params: FilterParams) -> CIImage? {
        var processed = ciImage
        
        // Post-Processing Median Filter (Iterative Application)
        // 回数を重ねることで実質的な半径を広げ、ノイズ除去強度を高める
        if params.postMedianIteration > 0 {
            let median = CIFilter.median()
            for _ in 0..<params.postMedianIteration {
                median.inputImage = processed
                processed = median.outputImage ?? processed
            }
        }
        
        // 追加のガウシアンノイズ除去（オプション）
        if params.postNoiseLevel > 0 {
            let noise = CIFilter.noiseReduction()
            noise.inputImage = processed
            noise.noiseLevel = params.postNoiseLevel
            noise.sharpness = 0.4
            processed = noise.outputImage ?? processed
        }
        
        return processed
    }
    
    /// 最終シャープネス
    private func applyFinalSharpening(to ciImage: CIImage, params: FilterParams) -> CIImage? {
        let sharpen = CIFilter.unsharpMask()
        sharpen.inputImage = ciImage
        sharpen.radius = 2.5
        sharpen.intensity = params.finalSharpness
        
        return sharpen.outputImage
    }
    
    /// フォールバック処理
    private func applyFallbackShadowRemoval(to ciImage: CIImage, params: FilterParams) -> CIImage? {
        let originalExtent = ciImage.extent
        
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = params.saturation
        colorControls.brightness = params.brightness
        colorControls.contrast = params.contrast
        
        guard let colorOutput = colorControls.outputImage else { return ciImage }
        
        let toneCurve = CIFilter.toneCurve()
        toneCurve.inputImage = colorOutput
        toneCurve.point0 = CGPoint(x: 0.0, y: params.toneCurvePoint0Y)
        toneCurve.point1 = CGPoint(x: 0.25, y: params.toneCurvePoint1Y)
        toneCurve.point2 = CGPoint(x: 0.5, y: params.toneCurvePoint2Y)
        toneCurve.point3 = CGPoint(x: 0.75, y: params.toneCurvePoint3Y)
        toneCurve.point4 = CGPoint(x: 1.0, y: 1.0)
        
        guard let toneOutput = toneCurve.outputImage else { return colorOutput }
        
        return toneOutput.cropped(to: originalExtent.integral)
    }
    
    enum ImageProcessorError: LocalizedError {
        case loadFailed
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .loadFailed: return "画像の読み込みに失敗しました"
            case .saveFailed: return "画像の保存に失敗しました"
            }
        }
    }
}
