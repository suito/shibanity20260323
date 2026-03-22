import SwiftUI
import AVFoundation
import Vision
import CoreML
import Combine
import Photos
import ARKit

// MARK: - ShibaLevel（レベル設定の一元管理）

enum ShibaLevel: Int, CaseIterable {
    case lv1 = 1, lv2, lv3, lv4, lv5, lv6, lv7, lv8, lv9

    var name: String {
        switch self {
        case .lv1: return "わんこ"
        case .lv2: return "柴犬以外"
        case .lv3: return "ニセ柴"
        case .lv4: return "シバの片鱗"
        case .lv5: return "柴犬風味"
        case .lv6: return "ほぼ柴犬"
        case .lv7: return "ザ・柴犬"
        case .lv8: return "柴犬100%"
        case .lv9: return "柴王"
        }
    }

    var color: Color {
        switch self {
        case .lv1:          return Color(white: 0.55)
        case .lv2, .lv3:   return .blue
        case .lv4, .lv5:   return Color(red: 0.2, green: 0.6, blue: 0.6)
        case .lv6, .lv7:   return .orange
        case .lv8, .lv9:   return .red
        }
    }

    var range: Range<Int> {
        switch self {
        case .lv1: return 0..<23
        case .lv2: return 23..<45
        case .lv3: return 45..<66
        case .lv4: return 66..<79
        case .lv5: return 79..<90
        case .lv6: return 90..<96
        case .lv7: return 96..<100
        case .lv8: return 100..<116
        case .lv9: return 116..<121
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
    @State private var showInfo = false

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
                    Image("waku7")
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

            // 左下 i ボタン（スプラッシュをモーダルで開く）
            VStack {
                Spacer()
                HStack {
                    Button(action: { showInfo = true }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(white: 0.85))
                            .shadow(radius: 4)
                    }
                    .padding(.leading, 24)
                    .padding(.bottom, 58)
                    Spacer()
                }
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
        .sheet(isPresented: $showInfo) {
            SplashView()
        }
    }
}

// MARK: - SplashView

struct SplashView: View {
    /// 起動時スプラッシュ: autoClose=true → 3秒後に自動遷移
    /// モーダル呼び出し: autoClose=false → タップ or iボタンで閉じる
    var autoClose: Bool = false
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    private let bg = Color(red: 0.23, green: 0.29, blue: 0.42)
    private let autoCloseDelay: Double = 3.0

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func doClose() {
        if let d = onDismiss { d() } else { dismiss() }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            // 画面タップで閉じる
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { doClose() }

            // 中央コンテンツ
            VStack(spacing: 0) {
                Spacer()

                Image("splash_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))

                Text("SHIBANITY")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)
                    .kerning(4)
                    .padding(.top, 36)
                    .padding(.bottom, 28)

                Text("© 2026 3cm")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.bottom, 10)

                Text("Version \(appVersion)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.40))

                Spacer()
            }
            .allowsHitTesting(false)

            // 左下の i ボタン
            VStack {
                Spacer()
                HStack {
                    Button(action: doClose) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.70))
                    }
                    .padding(.leading, 28)
                    .padding(.bottom, 50)
                    Spacer()
                }
            }
        }
        .onAppear {
            guard autoClose else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + autoCloseDelay) {
                doClose()
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

                if footnote != nil {
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
    @State private var showInfo = false

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

            // 左下の i ボタン
            VStack {
                Spacer()
                HStack {
                    Button(action: { showInfo = true }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(white: 0.55))
                            .shadow(radius: 2)
                    }
                    .padding(.leading, 24)
                    .padding(.bottom, 58)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showInfo) {
            SplashView()
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

// MARK: - StampView 補助 Shape

private struct ScallopedBorder: Shape {
    let count: Int
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let r   = min(rect.width, rect.height) / 2.0
        let bump = r * 0.078
        let step = 2.0 * Double.pi / Double(count)
        var path = Path()
        for i in 0..<count {
            let a1 = Double(i)     * step - Double.pi / 2.0
            let a2 = Double(i + 1) * step - Double.pi / 2.0
            let am = (a1 + a2) / 2.0
            let p1 = CGPoint(x: cx + r * CGFloat(cos(a1)), y: cy + r * CGFloat(sin(a1)))
            let p2 = CGPoint(x: cx + r * CGFloat(cos(a2)), y: cy + r * CGFloat(sin(a2)))
            let ct = CGPoint(x: cx + (r + bump) * CGFloat(cos(am)),
                             y: cy + (r + bump) * CGFloat(sin(am)))
            if i == 0 { path.move(to: p1) } else { path.addLine(to: p1) }
            path.addQuadCurve(to: p2, control: ct)
        }
        path.closeSubpath()
        return path
    }
}

private struct StarPath: Shape {
    let points: Int
    let innerRatio: CGFloat
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let outerR = min(rect.width, rect.height) / 2.0
        let innerR = outerR * innerRatio
        let step = Double.pi / Double(points)
        var path = Path()
        for i in 0..<(points * 2) {
            let a = Double(i) * step - Double.pi / 2.0
            let r = i % 2 == 0 ? Double(outerR) : Double(innerR)
            let p = CGPoint(x: cx + CGFloat(r * cos(a)), y: cy + CGFloat(r * sin(a)))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

private struct SunburstShape: Shape {
    let rays: Int
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let outerR = Double(min(rect.width, rect.height) / 2.0)
        let innerR = outerR * 0.06
        let step = 2.0 * Double.pi / Double(rays)
        var path = Path()
        for i in 0..<rays {
            let a = Double(i) * step
            path.move(to:    CGPoint(x: cx + CGFloat(innerR * cos(a)), y: cy + CGFloat(innerR * sin(a))))
            path.addLine(to: CGPoint(x: cx + CGFloat(outerR * cos(a)), y: cy + CGFloat(outerR * sin(a))))
        }
        return path
    }
}

// MARK: - StampView

struct StampView: View {
    let result: ShibaResult

    private let stampBlue = Color(red: 0.17, green: 0.33, blue: 0.50)
    private let stampRed  = Color(red: 0.72, green: 0.10, blue: 0.13)
    private let sz: CGFloat = 200

    // 上部・下部の星の角度（度）
    private let topAngles: [Double] = [-150, -120, -90, -60, -30]
    private let botAngles: [Double] = [210, 240, 270, 300, 330]

    var body: some View {
        ZStack {
            // 外周スカラップ縁
            ScallopedBorder(count: 22)
                .stroke(stampBlue, lineWidth: 5.5)
                .frame(width: sz, height: sz)

            // 外側二重円
            Circle()
                .stroke(stampBlue, lineWidth: 4)
                .frame(width: sz * 0.83, height: sz * 0.83)
            Circle()
                .stroke(stampBlue, lineWidth: 2)
                .frame(width: sz * 0.75, height: sz * 0.75)

            // 上部の星（5個）
            ForEach(topAngles.indices, id: \.self) { i in
                StarPath(points: 5, innerRatio: 0.42)
                    .fill(stampBlue)
                    .frame(width: 17, height: 17)
                    .offset(
                        x: sz * 0.36 * CGFloat(cos(topAngles[i] * Double.pi / 180)),
                        y: sz * 0.36 * CGFloat(sin(topAngles[i] * Double.pi / 180))
                    )
            }

            // 下部の星（5個）
            ForEach(botAngles.indices, id: \.self) { i in
                StarPath(points: 5, innerRatio: 0.42)
                    .fill(stampBlue)
                    .frame(width: 17, height: 17)
                    .offset(
                        x: sz * 0.36 * CGFloat(cos(botAngles[i] * Double.pi / 180)),
                        y: sz * 0.36 * CGFloat(sin(botAngles[i] * Double.pi / 180))
                    )
            }

            // サンバースト放射線
            SunburstShape(rays: 28)
                .stroke(stampBlue.opacity(0.45), lineWidth: 0.8)
                .frame(width: sz * 0.56, height: sz * 0.56)

            // CERTIFIED バナー
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.68))
                    .frame(width: sz * 0.88, height: sz * 0.25)
                RoundedRectangle(cornerRadius: 3)
                    .stroke(stampBlue, lineWidth: 2.5)
                    .frame(width: sz * 0.88, height: sz * 0.25)
                RoundedRectangle(cornerRadius: 2)
                    .stroke(stampBlue.opacity(0.55), lineWidth: 1)
                    .frame(width: sz * 0.81, height: sz * 0.18)
                Text("CERTIFIED")
                    .font(.system(size: sz * 0.152, weight: .black))
                    .foregroundColor(stampRed)
                    .kerning(1.2)
            }
        }
        .frame(width: sz, height: sz)
        .opacity(0.92)
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
        // 日本犬（柴犬度スコアに寄与）
        "shiba":               1.00,
        // 西洋犬種（柴犬度スコアに寄与しない）
        "golden_retriever":    0.00,
        "labrador_retriever":  0.00,
        "poodle":              0.00,
        "french_bulldog":      0.00,
        "maltese":             0.00,
        "miniature_schnauzer": 0.00,
        "shih_tzu":            0.00,
        "welsh_corgi":         0.00,
        "border_collie":       0.00,
        "cavalier":            0.00,
        "german_shepherd":     0.00,
        "papillon":            0.00,
        "chihuahua":           0.00,
        "pug":                 0.00,
        "boxer":               0.00,
        "yorkshire_terrier":   0.00,
        "pomeranian":          0.00,
        "beagle":              0.00,
        "pekingese":           0.00,
    ]

    // 日本語犬種名マッピング（定数）
    private static let breedNameJP: [String: String] = [
        // 日本犬
        "shiba":               "柴犬",
        // 西洋犬種
        "golden_retriever":    "ゴールデンレトリーバー",
        "labrador_retriever":  "ラブラドールレトリーバー",
        "poodle":              "トイプードル",
        "french_bulldog":      "フレンチブルドッグ",
        "maltese":             "マルチーズ",
        "miniature_schnauzer": "ミニチュアシュナウザー",
        "shih_tzu":            "シーズー",
        "welsh_corgi":         "ウェルシュコーギー",
        "border_collie":       "ボーダーコリー",
        "cavalier":            "キャバリア",
        "german_shepherd":     "ジャーマンシェパード",
        "papillon":            "パピヨン",
        "chihuahua":           "チワワ",
        "pug":                 "パグ",
        "boxer":               "ボクサー",
        "yorkshire_terrier":   "ヨークシャーテリア",
        "pomeranian":          "ポメラニアン",
        "beagle":              "ビーグル",
        "pekingese":           "ペキニーズ",
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
        guard let model = try? ShibaClassifier10(configuration: MLModelConfiguration()).model,
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

            let top1 = topResults.first
            let top1Class      = top1?.identifier ?? "other_dog"
            let top1Confidence = Double(top1?.confidence ?? 0)

            // A-1: 信頼度閾値 — 低信頼度クラスをスコアから除外
            let confidenceThreshold = 0.15
            let filteredResults = topResults.filter { Double($0.confidence) > confidenceThreshold }

            let similarityScore = filteredResults.reduce(0.0) { sum, obs in
                let weight = CameraManager.similarityWeight[obs.identifier] ?? 0.0
                return sum + Double(obs.confidence) * weight
            }

            var percentage = min(Int(similarityScore * 120), 120)

            // A-2: Top-1 が other_dog で高信頼度 → スコアを上限30に抑制
            if top1Class == "other_dog" && top1Confidence >= 0.40 {
                percentage = min(percentage, 30)
            }

            // A-3: Top-1 の信頼度が低い（モデルが迷っている）→ スコアを半減
            if top1Confidence < 0.25 {
                percentage = percentage / 2
            }

            // displayName用: 信頼度が十分高い場合のみ犬種名を表示
            let breedName: String
            // 子犬に誤判定されやすい小型犬クラス（LiDARサイズで補正）
            let smallBreedClasses: Set<String> = [
                "pomeranian", "maltese", "chihuahua", "yorkshire_terrier",
                "shih_tzu", "papillon", "miniature_schnauzer"
            ]
            let isPuppySuspect: Bool = {
                guard let h = self.dogSize?.heightCm, h < 35 else { return false }
                return smallBreedClasses.contains(top1Class) && top1Confidence < 0.70
            }()

            if top1Class != "other_dog" && top1Confidence >= 0.35 {
                if isPuppySuspect {
                    breedName = "子犬"
                } else if top1Class == "shiba" && top1Confidence < 0.60 {
                    // 柴犬に似ているが確信度が中程度 → 和犬の可能性（秋田犬・北海道犬等）
                    breedName = "和犬"
                } else {
                    breedName = CameraManager.breedNameJP[top1Class] ?? "その他の犬"
                }
            } else {
                breedName = "不明"
            }

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
