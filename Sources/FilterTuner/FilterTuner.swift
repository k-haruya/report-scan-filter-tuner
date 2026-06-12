//
//  main.swift
//  FilterTuner
//
//  コマンドラインエントリーポイント
//

import Foundation
import ArgumentParser

@main
struct FilterTuner: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "FilterTuner",
        abstract: "画像フィルターのパラメーターをチューニングするツール",
        version: "2.0.0"
    )

    @Option(name: .shortAndLong, help: "サンプル画像のディレクトリ")
    var samples: String = "./samples"

    @Option(name: .shortAndLong, help: "出力ディレクトリ")
    var output: String = "./outputs"

    @Option(name: .shortAndLong, help: "生成するパラメーター組み合わせの最大数")
    var limit: Int = 100

    @Flag(name: .long, help: "ドライラン（画像処理せずパラメーターのみ表示）")
    var dryRun: Bool = false

    @Flag(name: .long, help: "詳細スイープ（エッジ・シャープネスも変化させる）")
    var detailed: Bool = false

    @Flag(name: .long, help: "色味チューニングモード（基本パイプライン固定、色パラメーターのみスイープ）")
    var color: Bool = false

    @Flag(name: .long, help: "ノイズチューニングモード（色パラメーター固定、ノイズ関連パラメーターをスイープ）")
    var noise: Bool = false

    @Flag(name: .long, help: "デバッグモード（中間画像を保存）")
    var debug: Bool = false

    func run() throws {
        print("🔧 FilterTuner - 画像フィルターパラメーターチューニングツール")
        print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))

        // パラメーター組み合わせを生成
        let combinations: [FilterParams]
        let mode: String
        if noise {
            combinations = ParameterSweep.generateNoiseCombinations(limit: limit)
            mode = "noise"
            print("🔇 ノイズチューニングモード (全\(ParameterSweep.totalNoiseCombinations)通りから\(combinations.count)通りを選択)")
            print("   固定: BG30 / CST0.25 / CP1.0 / CB6.0")
            print("   スイープ対象: TO(閾値), TS(二値化強度), CT(最終コントラスト), PostM(事後メディアン)")
        } else if color {
            combinations = ParameterSweep.generateColorCombinations(limit: limit)
            mode = "color"
            print("🎨 色味チューニングモード (全\(ParameterSweep.totalColorCombinations)通りから\(combinations.count)通りを選択)")
            print("   基本パイプライン: BG30 / TO0.10 / TS0.8 (固定)")
            print("   スイープ対象: colorSaturationThreshold, colorPreservation, colorBoost")
        } else if detailed {
            combinations = ParameterSweep.generateDetailedCombinations(limit: limit)
            mode = "detailed"
            print("📊 詳細スイープモード (全\(ParameterSweep.totalDetailedCombinations)通りから\(combinations.count)通りを選択)")
        } else {
            combinations = ParameterSweep.generateCombinations(limit: limit)
            mode = "basic"
            print("📊 基本スイープモード (全\(ParameterSweep.totalBasicCombinations)通りから\(combinations.count)通りを選択)")
        }

        // ドライランの場合はパラメーター一覧を表示して終了
        if dryRun {
            print("\n📋 パラメーター一覧:")
            for (index, params) in combinations.enumerated() {
                let label = labelForParams(params, mode: mode)
                print("  \(String(format: "%03d", index + 1)): \(label)")
            }
            print("\n✅ ドライラン完了 (\(combinations.count)パターン)")
            return
        }

        // サンプル画像を取得
        let samplesURL = URL(fileURLWithPath: samples)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: samples) else {
            print("❌ エラー: サンプルディレクトリが存在しません: \(samples)")
            print("💡 ヒント: samplesフォルダにサンプル画像を配置してください")
            return
        }

        let sampleFiles = try fileManager.contentsOfDirectory(at: samplesURL, includingPropertiesForKeys: nil)
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }

        if sampleFiles.isEmpty {
            print("❌ エラー: サンプル画像が見つかりません")
            print("💡 ヒント: \(samples) にJPG/PNG/HEIC形式の画像を配置してください")
            return
        }

        print("📁 サンプル画像: \(sampleFiles.count)枚")
        for file in sampleFiles {
            print("   - \(file.lastPathComponent)")
        }

        // 出力ディレクトリを作成
        try fileManager.createDirectory(atPath: output, withIntermediateDirectories: true)

        // 画像処理
        let processor = ImageProcessor()
        var processedCount = 0
        let totalOperations = sampleFiles.count * combinations.count

        print("\n🚀 処理開始 (合計 \(totalOperations) 枚)")

        for sampleFile in sampleFiles {
            let sampleName = sampleFile.deletingPathExtension().lastPathComponent
            let sampleOutputDir = "\(output)/\(sampleName)"

            try fileManager.createDirectory(atPath: sampleOutputDir,
                                            withIntermediateDirectories: true)

            guard let image = processor.loadImage(from: sampleFile.path) else {
                print("⚠️ 画像読み込み失敗: \(sampleFile.lastPathComponent)")
                continue
            }

            print("\n📷 処理中: \(sampleFile.lastPathComponent)")

            for (index, params) in combinations.enumerated() {
                let label = labelForParams(params, mode: mode)
                let outputFileName = String(format: "v%03d_%@.jpg", index + 1, label)
                let outputPath = "\(sampleOutputDir)/\(outputFileName)"

                if let processed = processor.applyFilter(to: image, params: params, debug: debug && index == 0, outputDir: sampleOutputDir) {
                    do {
                        try processor.saveImage(processed, to: outputPath)
                        processedCount += 1

                        // 進捗表示（10件ごと）
                        if processedCount % 10 == 0 || processedCount == totalOperations {
                            let progress = Double(processedCount) / Double(totalOperations) * 100
                            print("   [\(String(format: "%.0f", progress))%] \(processedCount)/\(totalOperations) 完了")
                        }
                    } catch {
                        print("⚠️ 保存失敗: \(outputFileName)")
                    }
                }
            }
        }

        print("\n" + "=".padding(toLength: 60, withPad: "=", startingAt: 0))
        print("✅ 処理完了!")
        print("📁 出力先: \(output)")
        print("📊 処理枚数: \(processedCount)/\(totalOperations)")
        print("\n💡 次のステップ:")
        print("   1. Finderで \(output) を開いて画像を比較")
        print("   2. 最適なパラメーターのファイル名を確認")
        if noise {
            print("   3. ファイル名のTO/BG/TS/PreM/PostMの値をアプリに反映")
        } else if color {
            print("   3. ファイル名のCST/CP/CBの値をアプリに反映")
            print("      CST=colorSaturationThreshold, CP=colorPreservation, CB=colorBoost")
        } else {
            print("   3. FilterConfig.swift に値を反映")
        }
    }

    private func labelForParams(_ params: FilterParams, mode: String) -> String {
        switch mode {
        case "noise": return params.noiseDescription
        case "color": return params.shortDescription
        default: return params.description
        }
    }
}
