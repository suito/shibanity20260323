import SwiftUI
import AVFoundation
import Vision
import CoreML
import Combine
import Photos
import ARKit

// MARK: - ShibaLevel（レベル設定の一元管理）

enum ShibaLevel: Int, CaseIterable {
    case lv1 = 1, lv2, lv4 = 4, lv5, lv6, lv7, lv8, lv9

    var name: String {
        switch self {
        case .lv1: return "わんこを探そう"
        case .lv2: return "わんこだ！"
        case .lv4: return "シバの片鱗"
        case .lv5: return "柴犬風味"
        case .lv6: return "ほぼ柴犬"
        case .lv7: return "ザ・柴犬"
        case .lv8: return "柴犬100%"
        case .lv9: return "柴王"
        }
    }

    var range: Range<Int> {
        switch self {
        case .lv1: return 0..<23
        case .lv2: return 23..<66
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

    var levelName: String { shibaLevel.name }

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
    // landscape VN midX = portrait画像内の縦位置（.oriented(.right)による90°回転で変換）
    let dogCenterY: CGFloat
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
                        let size = max(c.width, c.height)
                        DogRippleView(size: size)
                            .position(x: c.midX, y: geo.size.height - c.midY)
                    }
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                HStack {
                    Text("柴犬カム")
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
                .background(Color.white)

                // アラートメッセージ（ヘッダー直下・カメラ映像上・ギザギザ前景）
                if let label = camera.screenLabel ?? camera.lidarScreenLabel {
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
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
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

            VStack(spacing: 0) {
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
                ShibaResultPanel(
                    result: panelResult,
                    peakPercentage: camera.peakPercentage,
                    onReset: { camera.clearResult() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

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
                    .padding(.vertical, 32)
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

// MARK: - DogRippleView

private struct DogRippleView: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .stroke(Color.orange.opacity(0.35), lineWidth: 4)
            .blur(radius: 2.5)
            .frame(width: size, height: size)
    }
}

// MARK: - FabricTexture

private struct FabricTexture: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 3.0

            // 経糸（縦）— サンプル参考・より強め
            var x: CGFloat = 0
            while x <= size.width {
                ctx.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.white.opacity(0.18)),
                    lineWidth: 0.8
                )
                x += spacing
            }

            // 緯糸（横）
            var y: CGFloat = 0
            while y <= size.height {
                ctx.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.white.opacity(0.11)),
                    lineWidth: 0.8
                )
                y += spacing
            }

            // グレイン（節糸・散点）
            var gx: CGFloat = 1.5
            var toggle = false
            while gx <= size.width {
                var gy: CGFloat = toggle ? 1.5 : spacing * 0.5
                while gy <= size.height {
                    let rect = CGRect(x: gx - 0.6, y: gy - 0.6, width: 1.2, height: 1.2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.07)))
                    gy += spacing * 4
                }
                gx += spacing * 3
                toggle.toggle()
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
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
            FabricTexture().ignoresSafeArea()

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

                Text("柴犬カム")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)
                    .kerning(4)
                    .padding(.top, 36)
                    .padding(.bottom, 28)

                Text("わんこ専用カメラアプリです。\n犬種判別にご協力いただいた\n越谷わんこたちとその主さまに\n感謝でございます。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, 28)

                Text("© 2026 フジイピカピ")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.bottom, 8)

                Text("Version \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))

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
                    if result.breedName != "不明" && result.breedName != "柴犬" && result.breedName != "その他の犬" {
                        Text("\(result.breedName)？")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(white: 0.35))
                    }
                    Text("SHIBA LEVEL")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(white: 0.55))
                        .kerning(1.5)
                    Text(result.levelName)
                        .font(.system(size: 24, weight: .black))
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

            // Row 2: メーターバー（ラベル付き・カメラ・認定画面で共通）
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // グレー背景（0〜100%の範囲）
                        Rectangle()
                            .fill(Color(white: 0.9))
                            .frame(width: geo.size.width, height: 3)
                            .position(x: geo.size.width / 2, y: 6)
                        // セクションラベル（十分な幅があるセクションのみ）
                        ForEach(ShibaLevel.allCases, id: \.self) { level in
                            let startPct = CGFloat(level.range.lowerBound)
                            let endPct   = CGFloat(level.range.upperBound)
                            let centerX  = geo.size.width * (startPct + endPct) / 200
                            if startPct < 100 && (endPct - startPct) >= 10 {
                                Text(level.name)
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(level == result.shibaLevel ? .orange : Color(white: 0.6))
                                    .fixedSize()
                                    .position(x: centerX, y: 23)
                            }
                        }
                        // 各SHIBA LEVELの閾値目盛り（100%未満のみ）
                        ForEach(Array(ShibaLevel.allCases.dropFirst()).filter { $0.range.lowerBound < 100 }, id: \.self) { level in
                            Rectangle()
                                .fill(Color(white: 0.68))
                                .frame(width: 1, height: 9)
                                .position(x: geo.size.width * CGFloat(level.range.lowerBound) / 100, y: 6)
                        }
                        // プログレスバー（100%超で右に突き抜ける）
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: geo.size.width * shownProgress, height: 3)
                            .position(x: geo.size.width * shownProgress / 2, y: 6)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
                        // 100%境界マーカー（正常上限の演出）
                        Rectangle()
                            .fill(Color(white: 0.2))
                            .frame(width: 2, height: 16)
                            .position(x: geo.size.width, y: 6)
                        // PEAKマーカー
                        if peakPercentage > 0 {
                            let peakX = geo.size.width * CGFloat(peakPercentage) / 100
                            Rectangle()
                                .fill(Color(white: 0.35))
                                .frame(width: 1.5, height: 10)
                                .position(x: peakX, y: 6)
                        }
                    }
                }
                .frame(height: 32)

                // リセット / PEAK（カメラ画面のみ）
                if !isStatic, onReset != nil || peakPercentage > 0 {
                    HStack {
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
                        Spacer()
                        if peakPercentage > 0 {
                            Text("PEAK \(peakPercentage)%")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(white: 0.5))
                                .kerning(0.5)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if let footnote {
                Rectangle().fill(Color(white: 0.88)).frame(height: 1)
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

// MARK: - CertificateHeaderView（CertificateView / CertificateCardView 共通ヘッダー）

private struct CertificateHeaderView: View {
    var topPadding: CGFloat = 60
    var bottomPadding: CGFloat = 16

    var body: some View {
        HStack {
            Text("認定 - CERTIFICATE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.55))
                .kerning(2)
            Spacer()
            Text(certificateFormattedDate())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(white: 0.55))
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .background(Color(white: 0.94))
    }
}

// MARK: - CertificateCoreContent（CertificateView / CertificateCardView 共通）

struct CertificateCoreContent: View {
    let data: CertificateData
    var isStatic: Bool = false
    var footnote: String? = nil

    var body: some View {
        // 写真 + waku2
        ZStack {
            // 犬の縦位置を中心に来るようにクロップ調整（1.2倍ズーム）
            GeometryReader { geo in
                let imgSize   = data.cutoutImage.size
                let zoom: CGFloat = 1.2
                let scaleX    = geo.size.width * zoom / imgSize.width
                let scaledW   = imgSize.width  * scaleX
                let scaledH   = imgSize.height * scaleX
                let excessH   = max(0, scaledH - geo.size.height)
                // カメラ画面より20%上方へシフト（フレーム高さ基準）
                let upwardShift = geo.size.height * 0.04
                let rawOffset = geo.size.height / 2 - data.dogCenterY * scaledH - upwardShift
                let clampedOffset = max(-excessH, min(0, rawOffset))

                Image(uiImage: data.cutoutImage)
                    .resizable()
                    .frame(width: scaledW, height: max(scaledH, geo.size.height))
                    .offset(x: -(scaledW - geo.size.width) / 2, y: clampedOffset)
            }
            .clipped()
            Image("waku2")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .scaleEffect(1.9)
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
                    // ヘッダー分のスペース確保
                    Color.clear.frame(height: 100)

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

            // ヘッダー（最前面）
            VStack {
                CertificateHeaderView()
                Spacer()
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

// MARK: - CertificateCardView（保存用）

struct CertificateCardView: View {
    let data: CertificateData

    var body: some View {
        ZStack {
            Color(white: 0.94)

            VStack(spacing: 0) {
                // ヘッダー高さ分の余白（最前面レイヤーのヘッダーと揃える）
                Color.clear.frame(height: 48)

                CertificateCoreContent(
                    data: data,
                    isStatic: true,
                    footnote: "上記の犬は柴犬度\(data.result.percentage)%と認定されました"
                )
                .padding(.bottom, 24)
            }

            // ヘッダー最前面（waku2のはみ出しより上に配置）
            VStack {
                CertificateHeaderView(topPadding: 14, bottomPadding: 14)
                Spacer()
            }
        }
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
        // 柴犬度ウェイト（見た目の柴犬らしさ・種別判定とは独立）
        "shiba":               1.00,  // 柴犬そのもの
        "pomeranian":          0.30,  // スピッツ系・雰囲気が近い
        "other_dog":           0.15,  // 未分類犬（和犬・日本犬の可能性あり）
        // 以下は柴犬度に寄与しない
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
        "beagle":              0.00,
        "pekingese":           0.00,
    ]

    // 画面・写真検出キーワードテーブル（定数）
    private static let screenLabels: [(keyword: String, displayName: String)] = [
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

    // 日本語犬種名マッピング（定数）
    private static let breedNameJP: [String: String] = [
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

    private func applyFallback(_ result: ShibaResult, bounds: [CGRect], generation: Int) {
        DispatchQueue.main.async {
            guard self.detectionGeneration == generation else { return }
            if !self.isDogDetected { self.isDogDetected = true }
            self.dogBounds = bounds

            let now = Date()
            guard now.timeIntervalSince(self.lastResultUpdateTime) >= self.resultUpdateInterval else { return }
            self.lastResultUpdateTime = now

            self.shibaResult = result
            if result.percentage > self.peakPercentage {
                self.peakPercentage = result.percentage
            }
        }
    }

    private func classifyDogBreed(pixelBuffer: CVPixelBuffer,
                                   colorType: String,
                                   bounds: [CGRect],
                                   generation: Int) {
        guard detectionGeneration == generation else { return }
        guard let model = dogBreedModel,
              let bbox = bounds.first else {
            applyFallback(ShibaResult.from(percentage: 30, colorType: colorType), bounds: bounds, generation: generation)
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
            applyFallback(ShibaResult.from(percentage: 30, colorType: colorType), bounds: bounds, generation: generation)
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

            // 柴犬度スコア（種別判定とは独立した見た目のSHIBA-らしさ）
            // A-1: 低信頼度クラスを除外
            let confidenceThreshold = 0.10
            let filteredResults = topResults.filter { Double($0.confidence) > confidenceThreshold }

            let rawScore = filteredResults.reduce(0.0) { sum, obs in
                let weight = CameraManager.similarityWeight[obs.identifier] ?? 0.0
                return sum + Double(obs.confidence) * weight
            }

            // × 150スケール（shiba信頼度 0.67 ≈ 柴犬100%）
            var percentage = min(Int(rawScore * 150), 120)

            // A-3: 極低信頼度（モデルがほぼ識別不能）のみ軽減
            if top1Confidence < 0.15 {
                percentage = Int(Double(percentage) * 0.8)
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
                } else if top1Class == "shiba" && top1Confidence < 0.45 {
                    // 柴犬に似ているが確信度が低め → 和犬の可能性（秋田犬・北海道犬等）
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

            self.applyFallback(result, bounds: bounds, generation: generation)
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

            // landscape VN midX = portrait画像(.oriented(.right))内の縦位置
            let dogCenterY = self.dogBounds.first.map { $0.midX } ?? 0.5

            DispatchQueue.main.async {
                self.isProcessing = false
                self.certificateData = CertificateData(
                    cutoutImage:  image,
                    result:       resultToUse,
                    screenLabel:  capturedLabel,
                    dogCenterY:   dogCenterY
                )
            }
        }
    }

    // MARK: - 画面・写真検出

    private func checkIfScreen(pixelBuffer: CVPixelBuffer) {
        let request = VNClassifyImageRequest { [weak self] req, _ in
            guard let self,
                  let results = req.results as? [VNClassificationObservation] else { return }

            var detected: String? = nil
            for obs in results {
                if obs.confidence < 0.25 { break }
                let id = obs.identifier.lowercased()
                if let match = Self.screenLabels.first(where: { id.contains($0.keyword) }) {
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
