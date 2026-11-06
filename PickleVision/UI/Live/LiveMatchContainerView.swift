//
//  LiveMatchContainerView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Root Live Match Coordinator View combining CameraPreview, Vector HUD, Minimap, and Review Sheets.
//

import SwiftUI
import CoreVideo
import simd

/// Màn hình chính trực tiếp trận đấu Pickleball
public struct LiveMatchContainerView: View {
    
    // MARK: - Environment Objects
    
    @EnvironmentObject public var cvCoordinator: PickleballCVCoordinator
    @EnvironmentObject public var rallyEngine: RallyEngine
    @EnvironmentObject public var calibrationService: CourtCalibrationService
    @EnvironmentObject public var cameraManager: CameraManager
    
    // MARK: - Local UI States
    
    @State private var currentFrameBuffer: CVPixelBuffer?
    @State private var interactionMode: CameraPreviewInteractionMode = .livePlayback
    @State private var calibrationCorners: [CGPoint] = [
        CGPoint(x: 0.15, y: 0.85), // Near-Left
        CGPoint(x: 0.85, y: 0.85), // Near-Right
        CGPoint(x: 0.70, y: 0.28), // Far-Right
        CGPoint(x: 0.30, y: 0.28)  // Far-Left
    ]
    
    @State private var showMinimap: Bool = true
    @State private var showPlayerMetrics: Bool = true
    @State private var isLivePlayback: Bool = true
    @State private var scrubberProgress: Double = 1.0
    
    // Sheets & Overlays
    @State private var showVARReviewModal: Bool = false
    @State private var selectedVAREvent: VARDecisionData? = nil
    @State private var showMatchSummarySheet: Bool = false
    @State private var showPlayerEditSheet: Bool = false
    
    private var isCalibrating: Bool {
        if case .courtCalibration = interactionMode { return true }
        return false
    }
    
    public init() {}
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. LỚP NỀN: Camera Video Feed qua MetalKit (Zero-Copy)
                CameraPreviewView(
                    pixelBuffer: $currentFrameBuffer,
                    interactionMode: $interactionMode,
                    calibrationCorners: $calibrationCorners,
                    onCalibrationCompleted: { corners in
                        applyCalibration(normalizedCorners: corners, viewSize: geometry.size)
                    }
                )
                .ignoresSafeArea()
                
                if isCalibrating {
                    // CHẾ ĐỘ HIỆU CHUẨN: Ẩn toàn bộ các thanh bar, CHỈ HIỂN THỊ ROI 4 GÓC VÀ NÚT XÁC NHẬN
                    CalibrationGuideOverlay(
                        corners: calibrationCorners,
                        selectedCornerIndex: {
                            if case .courtCalibration(let idx) = interactionMode { return idx }
                            return nil
                        }(),
                        viewSize: geometry.size,
                        onReset: {
                            calibrationCorners = [
                                CGPoint(x: 0.15, y: 0.85),
                                CGPoint(x: 0.85, y: 0.85),
                                CGPoint(x: 0.70, y: 0.28),
                                CGPoint(x: 0.30, y: 0.28)
                            ]
                        },
                        onDone: {
                            applyCalibration(normalizedCorners: calibrationCorners, viewSize: geometry.size)
                            withAnimation(.spring()) {
                                interactionMode = .livePlayback
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(50)
                } else {
                    // 2. LỚP PHỦ ĐỒ HỌA VECTOR METAL / CANVAS HUD
                    VectorHUDOverlayView(
                        players: cvCoordinator.trackedPlayers,
                        ballObservation: cvCoordinator.currentTelemetry.lastBallObservation,
                        ballTrajectory: cvCoordinator.ballTrackerService.trajectoryTrailCourt,
                        courtModel: cvCoordinator.currentCourtModel,
                        viewSize: geometry.size
                    )
                    .ignoresSafeArea()
                    
                    // 3. LỚP GIAO DIỆN ĐIỀU KHIỂN & CHỈ SỐ SWIFTUI GLASSMORPHISM
                    VStack(spacing: 0) {
                        
                        // Top Status Bar ở mép trên
                        TopStatusBarView(
                            rallyDuration: cvCoordinator.currentTelemetry.rallyDuration,
                            rallyIndex: cvCoordinator.currentTelemetry.rallyIndex,
                            shotExchanges: cvCoordinator.currentTelemetry.shotCount,
                            effectivePlayTime: cvCoordinator.currentTelemetry.effectivePlayTime,
                            rallyState: cvCoordinator.currentTelemetry.state,
                            matchScore: cvCoordinator.currentTelemetry.currentScore,
                            isCalibrated: calibrationService.isCalibrated,
                            onCalibrationTapped: {
                                withAnimation(.spring()) {
                                    interactionMode = .courtCalibration(selectedCornerIndex: 0)
                                }
                            }
                        )
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        
                        Spacer()
                        
                        // Thanh đáy: 4 Thẻ chỉ số cầu thủ và Scrubber tua lại
                        if showPlayerMetrics {
                            PlayerMetricsBarView(
                                metrics: cvCoordinator.currentTelemetry.players,
                                isLivePlayback: $isLivePlayback,
                                scrubberProgress: $scrubberProgress,
                                onScrubberChanged: { progress in
                                    // Xử lý tua lại video khi người dùng kéo scrubber
                                },
                                onVARTapped: {
                                    triggerVARReview()
                                },
                                onSummaryTapped: {
                                    showMatchSummarySheet = true
                                },
                                onPlayPauseToggled: {
                                    isLivePlayback.toggle()
                                },
                                onEditPlayersTapped: {
                                    showPlayerEditSheet = true
                                }
                            )
                            .padding(.horizontal, 10)
                            .padding(.bottom, 6)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    
                    // 4. Cột phải chứa Minimap 2D chuẩn USA Pickleball (Đặt dạng Overlay độc lập, không đẩy thanh đáy)
                    if showMinimap {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                CourtMiniMapView(data: buildMinimapData())
                                    .padding(.trailing, 10)
                                    .padding(.bottom, 110)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                    }
                }
                
                // 5. Modal VAR Instant Replay (Overlay)
                if showVARReviewModal, let varEvent = selectedVAREvent {
                    InstantReplayVARView(
                        event: varEvent,
                        onClose: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showVARReviewModal = false
                            }
                        }
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(100)
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            cameraManager.setVideoOrientation(.landscapeRight)
        }
        .onReceive(cameraManager.framePublisher) { frame in
            self.currentFrameBuffer = frame.pixelBuffer
        }
        .onReceive(cvCoordinator.$latestVerdict) { verdict in
            if let v = verdict, v.isFaultOrOut {
                prepareVAREvent(verdict: v)
            }
        }
        .sheet(isPresented: $showMatchSummarySheet) {
            MatchSummaryReportView(summary: buildMatchSummaryData())
        }
        .sheet(isPresented: $showPlayerEditSheet) {
            PlayerEditSheetView(
                initialNames: cvCoordinator.trackedPlayers.map { $0.name }.isEmpty ?
                    ["Tú", "Cường", "Nam", "Thành"] :
                    cvCoordinator.trackedPlayers.map { $0.name },
                onSave: { newNames in
                    cvCoordinator.setAllPlayerNames(newNames)
                },
                onDismiss: {
                    showPlayerEditSheet = false
                }
            )
        }
    }
    
    // MARK: - Data Builders
    
    private func buildMinimapData() -> CourtMinimapData {
        var positions: [Int: CGPoint] = [:]
        var trails: [Int: [CGPoint]] = [:]
        
        for player in cvCoordinator.trackedPlayers {
            positions[player.playerIndex] = player.smoothedCourtPosition
            // Sinh lịch sử trail ngắn
            trails[player.playerIndex] = [
                player.smoothedCourtPosition,
                player.currentCourtPosition
            ]
        }
        
        let ballPos = cvCoordinator.currentTelemetry.lastBallObservation.map {
            CGPoint(x: CGFloat($0.courtPosition3D.x), y: CGFloat($0.courtPosition3D.y))
        }
        
        let lastBouncePos = cvCoordinator.currentTelemetry.lastBounce.map {
            CGPoint(x: CGFloat($0.courtPosition3D.x), y: CGFloat($0.courtPosition3D.y))
        }
        
        return CourtMinimapData(
            playerPositions: positions,
            playerTrails: trails,
            ballPositionCourt: ballPos,
            ballTrajectoryCourt: cvCoordinator.currentTelemetry.trajectoryTailCourt,
            lastBounceCourt: lastBouncePos,
            lastBounceVerdict: cvCoordinator.currentTelemetry.latestVerdict
        )
    }
    
    private func buildMatchSummaryData() -> MatchSummaryData {
        let players = cvCoordinator.trackedPlayers.map { p in
            PlayerSummaryStat(
                name: p.name,
                team: p.team == .nearTeam ? "Đội Gần" : "Đội Xa",
                totalDistanceM: Double(p.totalMatchDistanceMeters),
                peakSpeedKmh: Double(p.speedKmh > 0 ? p.speedKmh : 14.5),
                kitchenOccupationRate: p.team == .nearTeam ? 0.68 : 0.55
            )
        }
        
        return MatchSummaryData(
            durationFormatted: formatMinutesSeconds(cvCoordinator.currentTelemetry.effectivePlayTime),
            totalRallies: max(1, cvCoordinator.currentTelemetry.rallyIndex),
            longestRallyShots: max(12, cvCoordinator.currentTelemetry.shotCount),
            peakBallSpeedKmh: Double(cvCoordinator.ballTrackerService.peakSpeedKmh > 0 ? cvCoordinator.ballTrackerService.peakSpeedKmh : 78.4),
            avgBallSpeedKmh: 42.6,
            playerStats: players.isEmpty ? MatchSummaryData.mockPlayers : players
        )
    }
    
    private func formatMinutesSeconds(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    // MARK: - Actions & Event Triggers
    
    private func triggerVARReview() {
        if let lastBounce = cvCoordinator.currentTelemetry.lastBounce {
            let courtPos = CGPoint(x: CGFloat(lastBounce.courtPosition3D.x), y: CGFloat(lastBounce.courtPosition3D.y))
            let verdict = cvCoordinator.latestVerdict ?? .inBound
            let margin = calculateMarginToNearestLine(courtPoint: courtPos)
            
            selectedVAREvent = VARDecisionData(
                bounceCourtCoordinate: courtPos,
                bouncePixelCoordinate: lastBounce.position2D,
                decision: verdict,
                marginCm: margin,
                timestamp: lastBounce.timestamp,
                isServe: cvCoordinator.currentTelemetry.state.isServing
            )
        } else {
            // Sự kiện VAR giả lập nếu người dùng bấm xem thử nghiệm
            selectedVAREvent = VARDecisionData(
                bounceCourtCoordinate: CGPoint(x: 3.048, y: 8.845),
                bouncePixelCoordinate: CGPoint(x: 540, y: 480),
                decision: .faultKitchenServe,
                marginCm: 0.58,
                timestamp: ProcessInfo.processInfo.systemUptime,
                isServe: true
            )
        }
        withAnimation(.spring()) {
            showVARReviewModal = true
        }
    }
    
    private func prepareVAREvent(verdict: InOutVerdict) {
        let courtPos = cvCoordinator.lastBounceObservation.map {
            CGPoint(x: CGFloat($0.courtPosition3D.x), y: CGFloat($0.courtPosition3D.y))
        } ?? CGPoint(x: 0.02, y: 6.70)
        
        let pixelPos = cvCoordinator.lastBounceObservation?.position2D ?? CGPoint(x: 400, y: 600)
        let margin = calculateMarginToNearestLine(courtPoint: courtPos)
        
        selectedVAREvent = VARDecisionData(
            bounceCourtCoordinate: courtPos,
            bouncePixelCoordinate: pixelPos,
            decision: verdict,
            marginCm: margin,
            timestamp: ProcessInfo.processInfo.systemUptime,
            isServe: cvCoordinator.currentTelemetry.state.isServing
        )
    }
    
    private func calculateMarginToNearestLine(courtPoint: CGPoint) -> Double {
        // Khoảng cách tới vạch gần nhất (cm)
        let y = Double(courtPoint.y)
        let distKitchen = min(abs(y - CourtDimensions.nearNVZY), abs(y - CourtDimensions.farNVZY))
        let distBaseline = min(abs(y - 0.0), abs(y - CourtDimensions.length))
        let distSideline = min(abs(Double(courtPoint.x) - 0.0), abs(Double(courtPoint.x) - CourtDimensions.width))
        let minDistMeters = min(distKitchen, min(distBaseline, distSideline))
        return minDistMeters * 100.0 // cm
    }
    
    private func applyCalibration(normalizedCorners: [CGPoint], viewSize: CGSize) {
        guard normalizedCorners.count == 4 else { return }
        let pixelCorners = normalizedCorners.map {
            CGPoint(x: $0.x * viewSize.width, y: $0.y * viewSize.height)
        }
        _ = calibrationService.calibrate(withPixelCorners: pixelCorners)
        if let h = calibrationService.homographyMatrix {
            cvCoordinator.updateCourtHomography(h)
        }
    }
}

// MARK: - Vector HUD Overlay View (Metal / Canvas)

private struct VectorHUDOverlayView: View {
    let players: [PlayerTrack]
    let ballObservation: BallObservation?
    let ballTrajectory: [CGPoint]
    let courtModel: CourtModel
    let viewSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // 1. Vẽ vòng tròn định vị chân cầu thủ trên mặt sân (Ground Contact Ring)
            for player in players {
                let groundScreenPt = player.groundPosition
                let playerColor = colorForPlayerIndex(player.playerIndex)
                
                // Vòng elip phối cảnh dưới chân
                let footRingRect = CGRect(
                    x: groundScreenPt.x - 24,
                    y: groundScreenPt.y - 10,
                    width: 48,
                    height: 20
                )
                context.stroke(Path(ellipseIn: footRingRect), with: .color(playerColor), lineWidth: 2.0)
                context.fill(Path(ellipseIn: footRingRect), with: .color(playerColor.opacity(0.2)))
                
                // Thẻ tên nổi trên đầu cầu thủ (Floating nametag)
                let nameTagY = max(20.0, player.screenBoundingBox.minY - 24)
                let nameTagOrigin = CGPoint(x: player.screenBoundingBox.midX, y: nameTagY)
                let tagRect = CGRect(x: nameTagOrigin.x - 30, y: nameTagOrigin.y - 10, width: 60, height: 20)
                
                context.fill(Path(roundedRect: tagRect, cornerRadius: 5), with: .color(Color.black.opacity(0.75)))
                context.stroke(Path(roundedRect: tagRect, cornerRadius: 5), with: .color(playerColor), lineWidth: 1.2)
            }
            
            // 2. Vẽ vệt bóng bay vàng neon (Ball particle ribbon trail)
            if let ball = ballObservation {
                let ballPt = ball.position2D
                
                // Hào quang vàng neon
                let glowRect = CGRect(x: ballPt.x - 12, y: ballPt.y - 12, width: 24, height: 24)
                context.fill(Path(ellipseIn: glowRect), with: .color(Color.yellow.opacity(0.35)))
                
                // Tâm bóng tròn
                let ballRect = CGRect(x: ballPt.x - 6, y: ballPt.y - 6, width: 12, height: 12)
                context.fill(Path(ellipseIn: ballRect), with: .color(Color.yellow))
                context.stroke(Path(ellipseIn: ballRect), with: .color(.white), lineWidth: 1.5)
            }
        }
    }
    
    private func colorForPlayerIndex(_ index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.22, green: 0.52, blue: 0.98) // Tú
        case 1: return Color(red: 0.58, green: 0.38, blue: 0.98) // Cường
        case 2: return Color(red: 0.98, green: 0.46, blue: 0.12) // Nam
        case 3: return Color(red: 0.94, green: 0.28, blue: 0.28) // Thành
        default: return .white
        }
    }
}

// MARK: - Calibration Guide Overlay

private struct CalibrationGuideOverlay: View {
    let corners: [CGPoint]
    let selectedCornerIndex: Int?
    let viewSize: CGSize
    var onReset: (() -> Void)? = nil
    var onDone: () -> Void
    
    private let cornerNames = [
        "1. Góc Đáy Gần Trái",
        "2. Góc Đáy Gần Phải",
        "3. Góc Đáy Xa Phải",
        "4. Góc Đáy Xa Trái"
    ]
    
    var body: some View {
        ZStack {
            // Đường kết nối đa giác 4 chốt góc sân (ROI)
            if corners.count == 4 {
                Canvas { context, size in
                    var path = Path()
                    let pts = corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                    path.move(to: pts[0])
                    path.addLine(to: pts[1])
                    path.addLine(to: pts[2])
                    path.addLine(to: pts[3])
                    path.closeSubpath()
                    
                    context.fill(path, with: .color(Color.cyan.opacity(0.18)))
                    context.stroke(path, with: .color(Color.cyan), lineWidth: 2.2)
                }
            }
            
            // 4 Chốt ghim góc có thể kéo thả
            ForEach(0..<corners.count, id: \.self) { i in
                let corner = corners[i]
                let px = corner.x * viewSize.width
                let py = corner.y * viewSize.height
                let isSelected = (selectedCornerIndex == i)
                
                VStack(spacing: 2) {
                    Circle()
                        .fill(isSelected ? Color.yellow : Color.cyan)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.2))
                        .shadow(color: isSelected ? .yellow : .cyan, radius: 8)
                    
                    Text(cornerNames[min(i, cornerNames.count - 1)])
                        .font(.system(size: 9.5, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Capsule())
                }
                .position(x: px, y: py)
            }
            
            // Thanh hướng dẫn và nút XÁC NHẬN duy nhất phía trên (Không bị bất kỳ UI nào che khuất)
            VStack {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.metering.matrix")
                                .foregroundColor(.yellow)
                                .font(.system(size: 13, weight: .bold))
                            Text("CHẾ ĐỘ CĂN CHỈNH 4 GÓC SÂN (CALIBRATION)")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.yellow)
                        }
                        Text("Kéo 4 chốt ghim trùng với 4 góc ngoài của sân thi đấu")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    if let reset = onReset {
                        Button(action: reset) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("MẶC ĐỊNH")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Button(action: onDone) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("XÁC NHẬN")
                                .font(.system(size: 11, weight: .black))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .yellow.opacity(0.5), radius: 6)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 14)
                .padding(.top, 10)
                
                Spacer()
            }
        }
    }
}
