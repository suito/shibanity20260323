import SwiftUI
import AVFoundation
import Vision
import CoreML
import Combine
import Photos
import ARKit

// MARK: - ShibaLevel（レベル設定の一元管理）

enum ShibaLevel: Int, CaseIterable {
    case lv1 = 1, lv2, lv3, lv4, lv5, lv6, lv7, lv8, lv9, lv10, lv11, lv12

    var name: String {
        switch self {
        case .lv1:  return "未判定"
        case .lv2:  return "わんこ"
        case .lv3:  return "柴犬以外"
        case .lv4:  return "ニセ柴"
        case .lv5:  return "シバの片鱗"
        case .lv6:  return "シバもどき"
        case .lv7:  return "柴犬風味"
        case .lv8:  return "準柴犬"
        case .lv9:  return "ほぼ柴犬"
        case .lv10: return "ザ・柴犬"
        case .lv11: return "柴犬100%"
        case .lv12: return "柴王"
        }
    }

    var color: Color {
        switch self {
        case .lv1, .lv2:   return Color(white: 0.55)
        case .lv3, .lv4:   return .blue
        case .lv5, .lv6:   return Color(red: 0.2, green: 0.6, blue: 0.6)
        case .lv7, .lv8:   return .green
        case .lv9, .lv10:  return .orange
        case .lv11, .lv12: return .red
        }
    }

    var range: Range<Int> {
        switch self {
        case .lv1:  return 0..<1
        case .lv2:  return 1..<9
        case .lv3:  return 9..<17
        case .lv4:  return 17..<26
        case .lv5:  return 26..<35
        case .lv6:  return 35..<44
        case .lv7:  return 44..<53
        case .lv8:  return 53..<63
        case .lv9:  return 63..<74
        case .lv10: return 74..<84
        case .lv11: return 84..<93
        case .lv12: return 93..<101
        }
    }

    static func from(percentage: Int) -> ShibaLevel {
        ShibaLevel.allCases.first { $0.range.contains(percentage) } ?? .lv1
    }
}

// MARK: - ShibaResult

struct ShibaResult {
    let shibaLevel: ShibaLevel
    let percentage: Int
    let colorType: String
    let breedName: String

    var level: Int        { shibaLevel.rawValue }
    var levelName: String { shibaLevel.name }

    var displayName: String {
        guard breedName != "不明" && breedName != "柴犬" && breedName != "その他の犬" else {
            return levelName
        }
        return "\(breedName)？"
    }

    static func from(percentage: Int,
                     colorType: String,
                     breedName: String = "不明") -> ShibaResult {
        ShibaResult(
            shibaLevel: ShibaLevel.from(percentage: percentage),
            percentage: percentage,
            colorType: colorType,
            breedName: breedName
        )
    }
}

// MARK: - DogSize

struct DogSize {
    let widthCm: Int
    let heightCm: Int
    let distanceM: Double

    var label: String {
        "約\(widthCm)×\(heightCm)cm  \(String(format: "%.1f", distanceM))m先"
    }
}

// MARK: - CertificateData

struct CertificateData: Identifiable {
    let id = UUID()
    let cutoutImage: UIImage
    let result: ShibaResult
    let screenLabel: String?
    let dogSize: DogSize?
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @State private var wakuAngle: Double = 3

    var body: some View {
        ZStack {
            if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            }

            if camera.isDogDetected {
                GeometryReader { geo in
                    // 回転時に端が切れないよう画面より大きいサイズで配置
                    let scale: CGFloat = 1.2
                    Image("waku3")
                        .resizable()
                        .frame(width: geo.size.width * scale, height: geo.size.height * scale)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .rotationEffect(.degrees(wakuAngle))
                        .animation(nil, value: wakuAngle)
                        .allowsHitTesting(false)
                }
                .clipped()
                .ignoresSafeArea()
                .onAppear {
                    wakuAngle = 3
                    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                        guard camera.isDogDetected else { timer.invalidate(); return }
                        wakuAngle = wakuAngle == 3 ? -3 : 3
                    }
                }
            }

            if camera.isDogDetected {
                GeometryReader { geo in
                    ForEach(camera.dogBounds, id: \.self) { rect in
                        let c = VNImageRectForNormalizedRect(
                            rect, Int(geo.size.width), Int(geo.size.height)
                        )
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange, lineWidth: 3)
                            .frame(width: c.width, height: c.height)
                            .position(x: c.midX, y: geo.size.height - c.midY)
                    }
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                HStack {
                    Text("SHIBANITY")
                        .font(.system(.title2, design: .default, weight: .black))
                        .foregroundColor(Color(white: 0.08))
                    Spacer()
                    if let size = camera.dogSize {
                        HStack(spacing: 4) {
                            Image(systemName: "ruler")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.45))
                            Text(size.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(white: 0.45))
                        }
                    }
                    if camera.isLiDARAvailable {
                        Text("LiDAR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 12)
                .background(Color.white.opacity(0.92))

                Spacer()

                if camera.isSetupFailed {
                    Text("カメラの起動に失敗しました")
                        .foregroundColor(.red)
                        .padding()
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                }

                let panelResult = camera.shibaResult ?? ShibaResult.from(percentage: 0, colorType: "不明")
                // Vision検出とLiDAR平面検出を統合表示
                let displayLabel = camera.screenLabel ?? camera.lidarScreenLabel
                if let label = displayLabel {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11, weight: .bold))
                        Text("\(label)が検出されました")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(white: 0.15))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                ShibaResultPanel(
                    result: panelResult,
                    peakPercentage: camera.peakPercentage,
                    onReset: { camera.clearResult() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Spacer().frame(height: 90)
            }

            if !camera.isDogDetected {
                VStack {
                    Text("SEARCHING...")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(white: 0.2))
                        .kerning(2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.78), lineWidth: 1))
                        .padding(.top, 180)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            VStack {
                Spacer()
                Button(action: { camera.capturePhoto() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("写真を撮る")
                            .font(.system(size: 15, weight: .black))
                            .kerning(0.5)
                    }
                    .foregroundColor(camera.isDogDetected ? .white : Color(white: 0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(camera.isDogDetected ? Color.black : Color(white: 0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!camera.isDogDetected)
                .padding(.horizontal, 16)
                .padding(.bottom, 50)
            }

            if camera.isProcessing {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("処理中...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: camera.isDogDetected)
        .animation(.easeInOut(duration: 0.3), value: camera.isProcessing)
        .onAppear { camera.requestPermissionAndStart() }
        .fullScreenCover(item: $camera.certificateData) { data in
            CertificateView(data: data) {
                camera.certificateData = nil
            }
        }
    }
}

// MARK: - ShibaResultPanel

struct ShibaResultPanel: View {
    let result: ShibaResult
    let peakPercentage: Int
    var onReset: (() -> Void)? = nil
    var isStatic: Bool = false
    var footnote: String? = nil

    @State private var displayedPercentage: Int = 0
    @State private var animatedProgress: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    private var shownPercentage: Int {
        isStatic ? result.percentage : displayedPercentage
    }
    private var shownProgress: CGFloat {
        isStatic ? CGFloat(result.percentage) / 100 : animatedProgress
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: レベル名 + 大きな柴犬度数字
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SHIBA LEVEL")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(white: 0.55))
                        .kerning(1.5)
                    Text(result.displayName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(Color(white: 0.08))
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(shownPercentage)")
                        .font(.system(size: 52, weight: .black))
                        .foregroundColor(Color(white: 0.08))
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.6), value: displayedPercentage)
                    Text("%")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.bottom, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle().fill(Color(white: 0.88)).frame(height: 1)

            if !isStatic {
                // Row 2: リセット | プログレスバー | PEAK
                HStack(spacing: 10) {
                    if let onReset {
                        Button(action: onReset) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("リセット")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(Color(white: 0.35))
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color(white: 0.9)).frame(height: 3)
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: geo.size.width * shownProgress, height: 3)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
                            if peakPercentage > 0 {
                                let peakX = geo.size.width * CGFloat(peakPercentage) / 100
                                Rectangle()
                                    .fill(Color(white: 0.35))
                                    .frame(width: 1.5, height: 10)
                                    .position(x: peakX, y: 5)
                            }
                        }
                    }
                    .frame(height: 3)

                    if peakPercentage > 0 {
                        Text("PEAK \(peakPercentage)%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(white: 0.5))
                            .kerning(0.5)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Rectangle().fill(Color(white: 0.88)).frame(height: 1)

                // Row 3: 12段階タブ（横スクロール・アクティブ自動追従）
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ShibaLevel.allCases, id: \.self) { level in
                                Text(level.name)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(level == result.shibaLevel ? .white : Color(white: 0.45))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(level == result.shibaLevel ? Color.black : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(level == result.shibaLevel ? Color.clear : Color(white: 0.78), lineWidth: 1)
                                    )
                                    .id(level)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .onChange(of: result.shibaLevel) { _, newLevel in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newLevel, anchor: .center)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(result.shibaLevel, anchor: .center)
                    }
                }

                if let footnote {
                    Rectangle().fill(Color(white: 0.88)).frame(height: 1)
                }
            }

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: result.percentage) { _, newValue in
            animateToValue(newValue)
        }
        .onAppear {
            animateToValue(result.percentage)
        }
    }

    private func animateToValue(_ target: Int) {
        animationTask?.cancel()
        animatedProgress = CGFloat(target) / 100.0
        let start = displayedPercentage
        let steps = abs(target - start)
        guard steps > 0 else { return }
        let intervalNs = UInt64(500_000_000 / steps)
        animationTask = Task { @MainActor in
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: intervalNs)
                guard !Task.isCancelled else { return }
                displayedPercentage = target > start ? start + i : start - i
            }
        }
    }
}

// MARK: - 共有ユーティリティ

private func certificateFormattedDate() -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = "yyyy年M月d日 認定"
    return f.string(from: Date())
}

// MARK: - CertificateCoreContent（CertificateView / CertificateCardView 共通）

struct CertificateCoreContent: View {
    let data: CertificateData
    var isStatic: Bool = false
    var footnote: String? = nil

    var body: some View {
        // 写真 + waku2
        ZStack {
            Image(uiImage: data.cutoutImage)
                .resizable()
                .scaledToFill()
                .frame(height: 260)
                .clipped()
            Image("waku2")
                .resizable()
                .scaledToFill()
                .frame(height: 260)
                .clipped()
                .allowsHitTesting(false)
        }
        .frame(height: 260)
        .padding(.horizontal, 16)

        // 結果パネル
        ShibaResultPanel(result: data.result, peakPercentage: 0, isStatic: isStatic, footnote: footnote)
            .padding(.horizontal, 16)
            .padding(.top, 12)

        // 警告ラベル
        if let label = data.screenLabel {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 11, weight: .bold))
                Text("\(label)が検出されました。認定証が仮のものになります")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.15))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.orange.opacity(0.5), lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

// MARK: - CertificateView

struct CertificateView: View {
    let data: CertificateData
    let onClose: () -> Void

    @State private var isSaved = false
    @State private var saveFailed = false
    @State private var stampVisible = false

    var body: some View {
        ZStack {
            Color(white: 0.94).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Text("CERTIFICATE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(white: 0.55))
                            .kerning(2)
                        Spacer()
                        Text(certificateFormattedDate())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(white: 0.55))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 16)

                    CertificateCoreContent(data: data)

                    // 保存ボタン
                    Button(action: saveImage) {
                        HStack(spacing: 8) {
                            Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                                .font(.system(size: 13, weight: .bold))
                            Text(isSaved ? "保存しました" : "保存する")
                                .font(.system(size: 15, weight: .black))
                                .kerning(0.5)
                        }
                        .foregroundColor(isSaved ? Color(white: 0.45) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isSaved ? Color(white: 0.88) : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isSaved)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .animation(.easeInOut(duration: 0.2), value: isSaved)

                    // 保存失敗メッセージ
                    if saveFailed {
                        Text("保存に失敗しました（写真へのアクセスを確認してください）")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .transition(.opacity)
                    }

                    // 撮り直すボタン
                    Button(action: onClose) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .bold))
                            Text("撮り直す")
                                .font(.system(size: 15, weight: .black))
                                .kerning(0.5)
                        }
                        .foregroundColor(Color(white: 0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.78), lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 50)
                }
            }

            // スタンプオーバーレイ
            if stampVisible {
                VStack {
                    HStack {
                        Spacer()
                        StampView(result: data.result)
                            .rotationEffect(.degrees(-15))
                            .padding(.top, 100)
                            .padding(.trailing, 36)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    stampVisible = true
                }
            }
        }
    }

    private func saveImage() {
        let renderer = ImageRenderer(content:
            CertificateCardView(data: data)
                .frame(width: 360)
        )
        renderer.scale = 3.0
        guard let image = renderer.uiImage,
              let imageData = image.jpegData(compressionQuality: 0.95) else { return }

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
        }) { success, _ in
            DispatchQueue.main.async {
                withAnimation {
                    if success { isSaved = true } else { saveFailed = true }
                }
            }
        }
    }
}

// MARK: - StampView

struct StampView: View {
    let result: ShibaResult

    var stampColor: Color {
        result.level >= 4
            ? Color(red: 0.8, green: 0.1, blue: 0.1)
            : Color(red: 0.1, green: 0.4, blue: 0.7)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(stampColor, lineWidth: 4)
                .frame(width: 90, height: 90)
            Circle()
                .stroke(stampColor, lineWidth: 2)
                .frame(width: 80, height: 80)
            VStack(spacing: 0) {
                Text("認定")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundColor(stampColor)
                Text("Lv.\(result.level)")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(stampColor)
                Text(result.levelName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(stampColor)
            }
        }
        .opacity(0.85)
    }
}

// MARK: - CertificateCardView（保存用）

struct CertificateCardView: View {
    let data: CertificateData

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CERTIFICATE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.55))
                    .kerning(2)
                Spacer()
                Text(certificateFormattedDate())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(white: 0.55))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            CertificateCoreContent(
                data: data,
                isStatic: true,
                footnote: "上記の犬は柴犬度\(data.result.percentage)%と認定されました"
            )
            .padding(.bottom, 24)
        }
        .background(Color(white: 0.94))
    }
}

// MARK: - CameraManager

class CameraManager: NSObject, ObservableObject, ARSessionDelegate {

    @Published var isAuthorized = false
    @Published var isSetupFailed = false
    @Published var dogBounds: [CGRect] = []
    @Published var isDogDetected = false
    @Published var shibaResult: ShibaResult?
    @Published var isProcessing = false
    @Published var certificateData: CertificateData?
    @Published var peakPercentage: Int = 0
    @Published var screenLabel: String? = nil       // Vision による画面検出
    @Published var lidarScreenLabel: String? = nil  // LiDAR 平面検出・平面アンカー検出
    @Published var dogSize: DogSize? = nil          // LiDAR による犬のサイズ

    private var lastResultUpdateTime: Date = .distantPast
    private let resultUpdateInterval: TimeInterval = 1.5

    // 検出スロットリング（1秒5回 = 200ms間隔）
    private var lastDetectionTime: Date = .distantPast
    private let detectionInterval: TimeInterval = 0.2

    // リセット後のインフライトリクエスト無効化用
    private var detectionGeneration: Int = 0

    // 犬消失後のホールドタイマー（ちらつき防止）
    private var dogLostTimer: Timer?
    private let dogLostHoldInterval: TimeInterval = 2.0

    // スレッドセーフな lastPixelBuffer
    private let pixelBufferLock = NSLock()
    private var _lastPixelBuffer: CVPixelBuffer?
    private var lastPixelBuffer: CVPixelBuffer? {
        get { pixelBufferLock.withLock { _lastPixelBuffer } }
        set { pixelBufferLock.withLock { _lastPixelBuffer = newValue } }
    }

    // スレッドセーフな bestResult
    private let bestResultLock = NSLock()
    private var _bestResult: ShibaResult?
    private var bestResult: ShibaResult? {
        get { bestResultLock.withLock { _bestResult } }
        set { bestResultLock.withLock { _bestResult = newValue } }
    }

    let session = ARSession()
    private let visionQueue = DispatchQueue(label: "vision.queue")
    private let ciContext = CIContext()

    private var lastColorAnalysisTime: Date = .distantPast
    private let colorAnalysisInterval: TimeInterval = 1.5
    private var lastScreenCheckTime: Date = .distantPast
    private let screenCheckInterval: TimeInterval = 2.0

    var isLiDARAvailable: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    // 柴犬類似度ウェイトテーブル（定数）
    private static let similarityWeight: [String: Double] = [
        "shiba":               1.00,
        "kishu":               0.85,
        "shikoku":             0.85,
        "hokkaido":            0.85,
        "kai":                 0.80,
        "akita":               0.75,
        "ryukyu":              0.75,
        "american_akita":      0.70,
        "finnish_spitz":       0.80,
        "jindo":               0.75,
        "basenji":             0.60,
        "norwegian_elkhound":  0.55,
        "chow":                0.50,
        "pomeranian":          0.45,
        "husky":               0.35,
        "samoyed":             0.30,
        "other_dog":           0.00
    ]

    // 日本語犬種名マッピング（定数）
    private static let breedNameJP: [String: String] = [
        "shiba":               "柴犬",
        "kishu":               "紀州犬",
        "shikoku":             "四国犬",
        "hokkaido":            "北海道犬",
        "kai":                 "甲斐犬",
        "akita":               "秋田犬",
        "ryukyu":              "琉球犬",
        "american_akita":      "アメリカンアキタ",
        "finnish_spitz":       "フィニッシュスピッツ",
        "jindo":               "珍島犬",
        "basenji":             "バセンジー",
        "norwegian_elkhound":  "ノルウェジアンエルクハウンド",
        "chow":                "チャウチャウ",
        "pomeranian":          "ポメラニアン",
        "husky":               "シベリアンハスキー",
        "samoyed":             "サモエド",
        "other_dog":           "その他の犬"
    ]

    // MARK: - 操作

    func clearResult() {
        dogLostTimer?.invalidate()
        dogLostTimer = nil
        detectionGeneration += 1   // インフライトリクエストを無効化
        lastResultUpdateTime = .distantPast
        shibaResult = nil
        peakPercentage = 0
        bestResult = nil
        isDogDetected = false
        dogBounds = []
        dogSize = nil
        lidarScreenLabel = nil
    }

    // MARK: - ShibaClassifierモデル

    private lazy var dogBreedModel: VNCoreMLModel? = {
        guard let model = try? ShibaClassifier20260318(configuration: MLModelConfiguration()).model,
              let vnModel = try? VNCoreMLModel(for: model) else {
            print("⚠️ ShibaClassifierモデルの読み込みに失敗しました")
            return nil
        }
        return vnModel
    }()

    // MARK: - セットアップ

    func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupARSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupARSession() }
                    else { self?.isSetupFailed = true }
                }
            }
        default:
            isSetupFailed = true
        }
    }

    private func setupARSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            DispatchQueue.main.async { self.isSetupFailed = true }
            return
        }

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]

        if isLiDARAvailable {
            config.sceneReconstruction = .mesh
            config.frameSemantics = .sceneDepth
        }

        // デリゲートを visionQueue で受信してスレッドモデルを維持
        session.delegateQueue = visionQueue
        session.delegate = self
        session.run(config, options: [.resetTracking, .removeExistingAnchors])

        DispatchQueue.main.async { self.isAuthorized = true }
    }

    // MARK: - ARSessionDelegate: フレーム更新（visionQueue で受信）

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        lastPixelBuffer = pixelBuffer

        // 画面・写真検出（2秒間隔で間引き）
        let screenNow = Date()
        if screenNow.timeIntervalSince(lastScreenCheckTime) > screenCheckInterval {
            lastScreenCheckTime = screenNow
            checkIfScreen(pixelBuffer: pixelBuffer)
        }

        let detectNow = Date()
        guard detectNow.timeIntervalSince(lastDetectionTime) >= detectionInterval else { return }
        lastDetectionTime = detectNow
        detectDogs(pixelBuffer: pixelBuffer, frame: frame)
    }

    // MARK: - ARSessionDelegate: 平面アンカー検出（visionQueue で受信）

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let currentFrame = session.currentFrame else { return }
        let cameraPos = SIMD3<Float>(
            currentFrame.camera.transform.columns.3.x,
            currentFrame.camera.transform.columns.3.y,
            currentFrame.camera.transform.columns.3.z
        )

        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  planeAnchor.alignment == .vertical else { continue }

            let planePos = SIMD3<Float>(
                planeAnchor.transform.columns.3.x,
                planeAnchor.transform.columns.3.y,
                planeAnchor.transform.columns.3.z
            )
            let distance = simd_distance(cameraPos, planePos)

            // 3m以内の垂直平面はモニター・スクリーンの可能性
            if distance < 3.0 {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.screenLabel == nil else { return }
                    self.lidarScreenLabel = "垂直面（LiDAR）"
                }
                break
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.isSetupFailed = true }
    }

    // MARK: - Vision 犬検出（Stage 1）

    private func detectDogs(pixelBuffer: CVPixelBuffer, frame: ARFrame) {
        let capturedGeneration = detectionGeneration
        let request = VNRecognizeAnimalsRequest { [weak self] request, _ in
            guard let self,
                  let results = request.results as? [VNRecognizedObjectObservation] else { return }
            guard self.detectionGeneration == capturedGeneration else { return } // リセット後は破棄

            let dogResults = results.filter { obs in
                obs.labels.contains { $0.identifier == "Dog" && $0.confidence > 0.5 }
            }

            guard !dogResults.isEmpty else {
                DispatchQueue.main.async {
                    // 既にタイマー起動中なら二重起動しない
                    guard self.dogLostTimer == nil else { return }
                    self.dogLostTimer = Timer.scheduledTimer(
                        withTimeInterval: self.dogLostHoldInterval,
                        repeats: false
                    ) { [weak self] _ in
                        guard let self else { return }
                        self.dogLostTimer = nil
                        self.isDogDetected = false
                        self.dogBounds = []
                        self.dogSize = nil
                        self.clearResult()
                    }
                }
                return
            }

            // 犬を検出したのでホールドタイマーをキャンセル
            DispatchQueue.main.async {
                self.dogLostTimer?.invalidate()
                self.dogLostTimer = nil
            }

            let bounds = dogResults.map { $0.boundingBox }

            var colorType = self.shibaResult?.colorType ?? "不明"
            let colorNow = Date()
            if colorNow.timeIntervalSince(self.lastColorAnalysisTime) > self.colorAnalysisInterval {
                self.lastColorAnalysisTime = colorNow
                colorType = self.detectColorType(from: pixelBuffer,
                                                  boundingBox: bounds.first ?? .zero)
            }

            // LiDAR 処理 → 犬種分類
            self.processLiDAR(
                frame: frame,
                dogBoundingBox: bounds.first ?? .zero,
                bounds: bounds,
                colorType: colorType,
                pixelBuffer: pixelBuffer,
                generation: capturedGeneration
            )
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    // MARK: - LiDAR処理

    private func processLiDAR(frame: ARFrame,
                               dogBoundingBox: CGRect,
                               bounds: [CGRect],
                               colorType: String,
                               pixelBuffer: CVPixelBuffer,
                               generation: Int) {
        guard isLiDARAvailable, let sceneDepth = frame.sceneDepth else {
            classifyDogBreed(pixelBuffer: pixelBuffer, colorType: colorType, bounds: bounds, generation: generation)
            return
        }

        if let depthResult = analyzeDepth(depthMap: sceneDepth.depthMap,
                                          boundingBox: dogBoundingBox) {
            // 深度の平坦性でモニター/写真を判定
            // 標準偏差が小さい（＝平面的）→ 写真・モニターの可能性が高い
            DispatchQueue.main.async { [weak self] in
                guard let self, self.screenLabel == nil else { return }
                self.lidarScreenLabel = depthResult.isFlat ? "平面（LiDAR）" : nil
            }

            // 犬のサイズ計算
            let size = calculateDogSize(
                frame: frame,
                dogBoundingBox: dogBoundingBox,
                distanceM: depthResult.distanceM
            )
            DispatchQueue.main.async { [weak self] in
                self?.dogSize = size
            }
        }

        classifyDogBreed(pixelBuffer: pixelBuffer, colorType: colorType, bounds: bounds, generation: generation)
    }

    /// LiDAR 深度マップを分析して距離と平坦性を返す
    private func analyzeDepth(depthMap: CVPixelBuffer,
                               boundingBox: CGRect) -> (distanceM: Float, isFlat: Bool)? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let depthW = CVPixelBufferGetWidth(depthMap)
        let depthH = CVPixelBufferGetHeight(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatBuffer = base.assumingMemoryBound(to: Float32.self)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size

        // Vision bbox は Y 軸が下→上なので depthMap 座標にフリップ
        let startX = max(Int(boundingBox.minX * CGFloat(depthW)), 0)
        let startY = max(Int((1 - boundingBox.maxY) * CGFloat(depthH)), 0)
        let boxW   = Int(boundingBox.width  * CGFloat(depthW))
        let boxH   = Int(boundingBox.height * CGFloat(depthH))
        let step   = max(max(boxW, boxH) / 12, 1)

        var depthValues: [Float] = []
        for y in stride(from: startY, to: min(startY + boxH, depthH), by: step) {
            for x in stride(from: startX, to: min(startX + boxW, depthW), by: step) {
                let depth = floatBuffer[y * floatsPerRow + x]
                if depth > 0.1 && depth < 8.0 {  // 有効範囲: 0.1〜8m
                    depthValues.append(depth)
                }
            }
        }

        guard depthValues.count >= 4 else { return nil }

        // 外れ値に強い中央値を距離として採用
        let sorted = depthValues.sorted()
        let median = sorted[sorted.count / 2]

        // 標準偏差で平坦性を判定（3cm 未満 → 平面と判断）
        let mean = depthValues.reduce(0, +) / Float(depthValues.count)
        let variance = depthValues.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
                       / Float(depthValues.count)
        let stdDev = sqrt(variance)

        return (distanceM: median, isFlat: stdDev < 0.03)
    }

    /// カメラ内部パラメータと深度から犬の実寸を推定
    private func calculateDogSize(frame: ARFrame,
                                   dogBoundingBox: CGRect,
                                   distanceM: Float) -> DogSize {
        let intrinsics = frame.camera.intrinsics
        let resolution = frame.camera.imageResolution

        let fx = intrinsics[0][0]  // X方向の焦点距離（ピクセル単位）
        let fy = intrinsics[1][1]  // Y方向の焦点距離（ピクセル単位）

        let pixelW = dogBoundingBox.width  * resolution.width
        let pixelH = dogBoundingBox.height * resolution.height

        // 実サイズ = ピクセルサイズ × 距離 ÷ 焦点距離
        let widthM  = Double(pixelW) * Double(distanceM) / Double(fx)
        let heightM = Double(pixelH) * Double(distanceM) / Double(fy)

        return DogSize(
            widthCm:   max(1, Int(widthM  * 100)),
            heightCm:  max(1, Int(heightM * 100)),
            distanceM: Double(distanceM)
        )
    }

    // MARK: - 犬種分類（Stage 2）

    private func classifyDogBreed(pixelBuffer: CVPixelBuffer,
                                   colorType: String,
                                   bounds: [CGRect],
                                   generation: Int) {
        guard detectionGeneration == generation else { return }
        guard let model = dogBreedModel,
              let bbox = bounds.first else {
            let fallback = ShibaResult.from(percentage: 30, colorType: colorType)
            DispatchQueue.main.async {
                guard self.detectionGeneration == generation else { return }
                self.isDogDetected = true
                self.dogBounds = bounds

                let now = Date()
                guard now.timeIntervalSince(self.lastResultUpdateTime) >= self.resultUpdateInterval else { return }
                self.lastResultUpdateTime = now

                self.shibaResult = fallback
                if fallback.percentage > self.peakPercentage {
                    self.peakPercentage = fallback.percentage
                }
            }
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imageWidth  = ciImage.extent.width
        let imageHeight = ciImage.extent.height

        let cropRect = CGRect(
            x: bbox.minX * imageWidth,
            y: bbox.minY * imageHeight,
            width:  bbox.width  * imageWidth,
            height: bbox.height * imageHeight
        )

        let croppedCI = ciImage.cropped(to: cropRect)
        guard let cgImage = ciContext.createCGImage(croppedCI, from: croppedCI.extent) else {
            let fallback = ShibaResult.from(percentage: 30, colorType: colorType)
            DispatchQueue.main.async {
                guard self.detectionGeneration == generation else { return }
                self.isDogDetected = true
                self.dogBounds = bounds
                self.shibaResult = fallback
            }
            return
        }

        let request = VNCoreMLRequest(model: model) { [weak self] req, _ in
            guard let self = self,
                  let results = req.results as? [VNClassificationObservation] else { return }
            guard self.detectionGeneration == generation else { return }

            let topResults = Array(results.prefix(17))

            let similarityScore = topResults.reduce(0.0) { sum, obs in
                let weight = CameraManager.similarityWeight[obs.identifier] ?? 0.0
                return sum + Double(obs.confidence) * weight
            }

            let percentage = min(Int(similarityScore * 100), 100)
            let topClass   = topResults.first?.identifier ?? "other_dog"
            let breedName  = CameraManager.breedNameJP[topClass] ?? "その他の犬"

            let result = ShibaResult.from(
                percentage: percentage,
                colorType:  colorType,
                breedName:  breedName
            )

            if self.bestResult == nil || percentage > (self.bestResult?.percentage ?? 0) {
                self.bestResult = result
            }

            let capturedResult     = result
            let capturedPercentage = percentage
            DispatchQueue.main.async {
                guard self.detectionGeneration == generation else { return }
                self.isDogDetected = true
                self.dogBounds = bounds

                let now = Date()
                guard now.timeIntervalSince(self.lastResultUpdateTime) >= self.resultUpdateInterval else { return }
                self.lastResultUpdateTime = now

                self.shibaResult = capturedResult
                if capturedPercentage > self.peakPercentage {
                    self.peakPercentage = capturedPercentage
                }
            }
        }

        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("❌ VNCoreMLRequest エラー: \(error)")
        }
    }

    // MARK: - 撮影

    func capturePhoto() {
        isProcessing = true
        guard let frame = session.currentFrame else {
            isProcessing = false
            return
        }

        let pixelBuffer = frame.capturedImage

        visionQueue.async { [weak self] in
            guard let self else { return }

            // 撮影時点での画面検出を更新
            self.checkIfScreen(pixelBuffer: pixelBuffer)

            // ARKit の capturedImage はランドスケープ形式 → ポートレートに回転
            let ciImage  = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
            guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                DispatchQueue.main.async { self.isProcessing = false }
                return
            }

            let image         = UIImage(cgImage: cgImage)
            let resultToUse   = self.shibaResult
                                ?? ShibaResult.from(percentage: 50, colorType: "不明")
            let capturedLabel = self.screenLabel ?? self.lidarScreenLabel
            let capturedSize  = self.dogSize

            DispatchQueue.main.async {
                self.isProcessing = false
                self.certificateData = CertificateData(
                    cutoutImage:  image,
                    result:       resultToUse,
                    screenLabel:  capturedLabel,
                    dogSize:      capturedSize
                )
            }
        }
    }

    // MARK: - 画面・写真検出

    private func checkIfScreen(pixelBuffer: CVPixelBuffer) {
        let request = VNClassifyImageRequest { [weak self] req, _ in
            guard let self,
                  let results = req.results as? [VNClassificationObservation] else { return }

            let screenLabels: [(keyword: String, displayName: String)] = [
                ("screen",      "モニター"),
                ("monitor",     "モニター"),
                ("television",  "モニター"),
                ("display",     "モニター"),
                ("computer",    "モニター"),
                ("laptop",      "モニター"),
                ("smartphone",  "モニター"),
                ("tablet",      "モニター"),
                ("photograph",  "写真"),
                ("photo",       "写真"),
                ("picture",     "写真"),
                ("poster",      "写真"),
                ("print",       "写真"),
                ("book",        "写真"),
            ]

            var detected: String? = nil
            for obs in results {
                if obs.confidence < 0.25 { break }
                let id = obs.identifier.lowercased()
                if let match = screenLabels.first(where: { id.contains($0.keyword) }) {
                    detected = match.displayName
                    break
                }
            }

            DispatchQueue.main.async {
                self.screenLabel = detected
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    // MARK: - 色タイプ判定

    private func detectColorType(from pixelBuffer: CVPixelBuffer,
                                  boundingBox: CGRect) -> String {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return "不明" }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = base.assumingMemoryBound(to: UInt8.self)

        let startX = Int(boundingBox.minX * CGFloat(width))
        let startY = Int((1 - boundingBox.maxY) * CGFloat(height))
        let boxW   = Int(boundingBox.width  * CGFloat(width))
        let boxH   = Int(boundingBox.height * CGFloat(height))
        let step   = max(boxW / 8, 1)

        var totalR: Double = 0, totalG: Double = 0, totalB: Double = 0
        var count = 0

        for y in stride(from: startY, to: min(startY + boxH, height), by: step) {
            for x in stride(from: startX, to: min(startX + boxW, width), by: step) {
                let offset = y * bytesPerRow + x * 4
                totalB += Double(buffer[offset])
                totalG += Double(buffer[offset + 1])
                totalR += Double(buffer[offset + 2])
                count += 1
            }
        }

        guard count > 0 else { return "不明" }
        let r = totalR / Double(count) / 255.0
        let g = totalG / Double(count) / 255.0
        let b = totalB / Double(count) / 255.0

        let maxC  = max(r, g, b)
        let minC  = min(r, g, b)
        let delta = maxC - minC
        let s = maxC == 0 ? 0.0 : delta / maxC
        let v = maxC
        var h: Double = 0
        if delta > 0 {
            if maxC == r      { h = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6)) }
            else if maxC == g { h = 60 * ((b - r) / delta + 2) }
            else              { h = 60 * ((r - g) / delta + 4) }
            if h < 0 { h += 360 }
        }

        if v > 0.75 && s < 0.25 { return "白" }
        if v < 0.25              { return "黒" }
        // 赤柴：赤系かつ彩度高め
        if h >= 15 && h <= 45 && s > 0.3  { return "赤" }
        // ゴマ柴：赤系だが彩度低め
        if h >= 15 && h <= 50 && s > 0.15 { return "ゴマ" }
        return "不明"
    }
}
