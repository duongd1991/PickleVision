//
//  PickleballCVCoordinator.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  Integrated Computer Vision Pipeline Coordinator and USA Pickleball In/Out Rules Engine.
//

import Foundation
import CoreMedia
import CoreVideo
import CoreGraphics
import Combine
import simd

/// Bộ điều phối trung tâm của toàn bộ hệ thống thị giác máy tính PickleVision
public final class PickleballCVCoordinator: NSObject, ObservableObject {
    
    // MARK: - Submodules
    
    public let courtCalibrationService: CourtCalibrationService
    public let videoStabilizer: VideoStabilizer
    public let playerTrackerService: PlayerTrackerService
    public let ballTrackerService: BallTrackerService
    public let rallyEngine: RallyEngine
    
    // MARK: - Published Properties
    
    @Published public private(set) var trackedPlayers: [PlayerTrack] = []
    @Published public private(set) var currentTelemetry: RallyTelemetry = RallyTelemetry()
    @Published public private(set) var latestVerdict: InOutVerdict?
    @Published public private(set) var lastBounceObservation: BallObservation?
    @Published public private(set) var currentCourtModel: CourtModel = CourtModel()
    
    private let processingQueue = DispatchQueue(label: "com.picklevision.cv.pipeline", qos: .userInteractive)
    private var isProcessingFrame = false
    private var lastFrameTime: TimeInterval = 0.0
    
    // Đếm số cú đánh trong pha bóng hiện tại để kiểm tra Two-Bounce Rule
    private var shotsInRally: Int = 0
    private var bounceCountInRally: Int = 0
    private var previousBallCourtY: Double? = nil
    
    // MARK: - Initialization
    
    public init(
        courtCalibrationService: CourtCalibrationService = CourtCalibrationService(),
        videoStabilizer: VideoStabilizer = VideoStabilizer(),
        playerTrackerService: PlayerTrackerService = PlayerTrackerService(),
        ballTrackerService: BallTrackerService = BallTrackerService(),
        rallyEngine: RallyEngine = RallyEngine()
    ) {
        self.courtCalibrationService = courtCalibrationService
        self.videoStabilizer = videoStabilizer
        self.playerTrackerService = playerTrackerService
        self.ballTrackerService = ballTrackerService
        self.rallyEngine = rallyEngine
        super.init()
    }
    
    // MARK: - Court Homography Update
    
    /// Cập nhật ma trận phối cảnh cho mô hình sân thi đấu
    public func updateCourtHomography(_ h: simd_float3x3) {
        var updated = currentCourtModel
        updated.updateHomography(h)
        DispatchQueue.main.async {
            self.currentCourtModel = updated
        }
    }
    
    // MARK: - Pipeline Processing Entry Point
    
    /// Tiếp nhận khung hình từ CameraManager hoặc Video Data Output
    public func processFrame(sampleBuffer: CMSampleBuffer) {
        guard !isProcessingFrame else { return } // Tránh nghẽn khung hình
        isProcessingFrame = true
        
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessingFrame = false
            return
        }
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessingFrame = false }
            
            // 1. Xác định ma trận Homography: Nếu đã hiệu chuẩn thì lấy ma trận chống rung tức thời
            var activeHomography = self.courtCalibrationService.homographyMatrix ?? matrix_identity_float3x3
            if self.courtCalibrationService.isCalibrated {
                activeHomography = self.videoStabilizer.updateStabilizedHomography(with: pixelBuffer)
            }
            
            // 2. Cập nhật Player Tracking (Vision Pose cổ chân + ByteTrack + Re-ID)
            let updatedPlayers = self.playerTrackerService.update(with: pixelBuffer, homography: activeHomography)
            
            // 3. Cập nhật Ball Tracking (Trừ nền 3 frame + Màu vàng neon + Quỹ đạo parabol)
            let ballObservation = self.ballTrackerService.update(with: pixelBuffer, timestamp: pts, homography: activeHomography)
            
            // Tăng số lượt đổi hướng: Khi bóng vượt qua mặt phẳng lưới (Y = 6.7056m)
            if let ball = ballObservation {
                let currentY = Double(ball.courtPosition3D.y)
                let netY = CourtDimensions.netY
                if let lastY = self.previousBallCourtY {
                    if (lastY < netY && currentY >= netY) || (lastY > netY && currentY <= netY) {
                        self.shotsInRally += 1
                        self.rallyEngine.registerShotExchange()
                    }
                }
                self.previousBallCourtY = currentY
            }
            
            // 4. Xử lý sự kiện điểm nảy (Bounce) & Ra phán quyết In/Out tự động
            if let ball = ballObservation, ball.isBounce {
                self.handleDetectedBounce(ball: ball)
            }
            
            // 5. Kiểm tra lỗi vô-lê trong khu vực Bếp (Kitchen Volley Check)
            self.checkKitchenVolleyFault(players: updatedPlayers, ball: ballObservation)
            
            // 6. Tổng hợp dữ liệu viễn trắc (Rally Telemetry) và cập nhật lên Main Thread
            self.updateTelemetry(players: updatedPlayers, ball: ballObservation, timestamp: pts)
        }
    }
    
    // MARK: - Phán Quyết In/Out Chuẩn USA Pickleball
    
    /// Xử lý khi phát hiện điểm nảy
    private func handleDetectedBounce(ball: BallObservation) {
        self.bounceCountInRally += 1
        let isServe = rallyEngine.state.isServing
        
        // Xác định ô giao bóng mục tiêu nếu là pha phát bóng
        var targetBox: ServiceBox? = nil
        if isServe {
            // Ví dụ người giao đứng ở Near-Right thì mục tiêu là Far-Left
            targetBox = .farLeft
        }
        
        let verdict = evaluateBounceVerdict(
            courtPos: CGPoint(x: CGFloat(ball.courtPosition3D.x), y: CGFloat(ball.courtPosition3D.y)),
            isServe: isServe,
            targetServiceBox: targetBox
        )
        
        DispatchQueue.main.async {
            self.lastBounceObservation = ball
            self.latestVerdict = verdict
        }
        
        // Gửi kết quả nảy bóng sang RallyEngine để cập nhật trạng thái trận đấu
        let engineVerdict = rallyEngine.handleBallBounce(
            at: CGPoint(x: CGFloat(ball.courtPosition3D.x), y: CGFloat(ball.courtPosition3D.y)),
            isServe: isServe
        )
        
        // Nếu là lỗi hoặc bóng ra ngoài -> ngắt pha bóng ngay
        if engineVerdict.isFaultOrOut {
            self.previousBallCourtY = nil
            self.shotsInRally = 0
            DispatchQueue.main.async {
                self.rallyEngine.endRally(verdict: engineVerdict)
            }
        }
    }
    
    /// Thuật toán đánh giá phán quyết điểm nảy theo chuẩn luật USA Pickleball
    public func evaluateBounceVerdict(
        courtPos: CGPoint,
        isServe: Bool,
        targetServiceBox: ServiceBox? = nil
    ) -> InOutVerdict {
        let x = Double(courtPos.x)
        let y = Double(courtPos.y)
        let r = CourtDimensions.ballRadius
        
        // 1. Kiểm tra rơi ngoài toàn bộ sân (Vạch bao quanh ngoài cùng)
        // Vạch biên ngoài (Sidelines: X=0..6.096) và Vạch đáy (Baselines: Y=0..13.4112)
        // Luật USAP: Chạm vào bất kỳ phần nào của vạch biên/đáy (dung sai bán kính bóng r) là IN
        if x < -r || x > (CourtDimensions.width + r) || y < -r || y > (CourtDimensions.length + r) {
            return .outOfBound
        }
        
        // 2. Trường hợp GIAO BÓNG (SERVE):
        // Luật USAP khắt khe: Vạch bếp (Kitchen Line) và Khu vực bếp (NVZ) KHÔNG thuộc ô giao bóng hợp lệ!
        if isServe {
            // Giả định cú giao bóng bay từ Near Side sang Far Side (hoặc kiểm tra targetServiceBox)
            let isTargetFarCourt = y > CourtDimensions.netY
            
            if isTargetFarCourt {
                // Sân xa: Vạch bếp nằm ở Y = 8.8392m
                // Nếu bóng chạm vạch bếp (Y <= 8.8392 + r) hoặc rơi trong khu vực bếp -> FAULT NGAY!
                if y <= (CourtDimensions.farNVZY + r) {
                    return .faultKitchenServe
                }
                
                // Kiểm tra ô giao bóng chéo (ví dụ Far Left: X: 0..3.048, Far Right: X: 3.048..6.096)
                if let target = targetServiceBox {
                    let minX = target.bounds.minX - r
                    let maxX = target.bounds.maxX + r
                    let maxY = target.bounds.maxY + r
                    
                    if x >= minX && x <= maxX && y <= maxY {
                        return .inBound
                    } else {
                        return .outOfBound
                    }
                }
            } else {
                // Sân gần: Vạch bếp nằm ở Y = 4.5720m
                // Nếu bóng chạm vạch bếp (Y >= 4.5720 - r) hoặc rơi trong khu vực bếp -> FAULT NGAY!
                if y >= (CourtDimensions.nearNVZY - r) {
                    return .faultKitchenServe
                }
                
                // Kiểm tra ô giao bóng chéo sân gần (Near Left: X: 0..3.048, Near Right: X: 3.048..6.096, Y: 0..4.572)
                if let target = targetServiceBox {
                    let minX = target.bounds.minX - r
                    let maxX = target.bounds.maxX + r
                    let minY = target.bounds.minY - r
                    let maxY = target.bounds.maxY + r
                    
                    if x >= minX && x <= maxX && y >= minY && y <= maxY {
                        return .inBound
                    } else {
                        return .outOfBound
                    }
                }
            }
            
            // Nếu không vi phạm vạch bếp và trong sân -> IN
            return .inBound
        }
        
        // 3. Trường hợp PHA BÓNG BÌNH THƯỜNG (LIVE RALLY):
        // Luật USAP: Bóng rơi vào khu vực bếp hoặc chạm vạch bếp HOÀN TOÀN HỢP LỆ (IN)!
        return .inBound
    }
    
    // MARK: - Kiểm Tra Lỗi Quy Tắc Bổ Trợ
    
    /// Kiểm tra lỗi bước chân giẫm bếp khi đánh vô-lê (Kitchen Volley Fault)
    private func checkKitchenVolleyFault(players: [PlayerTrack], ball: BallObservation?) {
        guard let b = ball, b.velocityKmh > 15.0, !b.isBounce else { return }
        
        // Khi có sự kiện đánh bóng khi chưa nảy (Volley):
        for player in players {
            let px = Double(player.currentCourtPosition.x)
            let py = Double(player.currentCourtPosition.y)
            let bx = Double(b.courtPosition3D.x)
            let by = Double(b.courtPosition3D.y)
            
            // Điều kiện khoảng cách tương tác: Cầu thủ phải ở gần bóng (khoảng cách <= 1.5m) mới là người thực hiện cú vô-lê
            let distToBall = hypot(px - bx, py - by)
            guard distToBall <= 1.5 else { continue }
            
            let isNearTeam = (player.team == .nearTeam)
            
            // Nếu là đội gần: vạch bếp là Y = 4.5720m. Giẫm bếp là Y >= 4.5720
            // Nếu là đội xa: vạch bếp là Y = 8.8392m. Giẫm bếp là Y <= 8.8392
            let isTouchingKitchen = isNearTeam ?
                (py >= (CourtDimensions.nearNVZY - 0.05)) :
                (py <= (CourtDimensions.farNVZY + 0.05))
            
            if isTouchingKitchen {
                // Phát hiện lỗi vô-lê trong bếp!
                DispatchQueue.main.async {
                    self.latestVerdict = .kitchenVolleyFault
                    self.rallyEngine.endRally(verdict: .kitchenVolleyFault)
                }
                break
            }
        }
    }
    
    // MARK: - Tổng Hợp Telemetry
    
    private func updateTelemetry(players: [PlayerTrack], ball: BallObservation?, timestamp: TimeInterval) {
        let playerMetrics = players.map { track in
            PlayerRallyMetric(
                id: track.id,
                playerIndex: track.playerIndex,
                name: track.name,
                team: track.team,
                courtPosition: track.smoothedCourtPosition,
                rallyDistanceMeters: track.rallyDistanceMeters,
                totalMatchDistanceMeters: track.totalMatchDistanceMeters,
                currentSpeedKmh: track.speedKmh,
                workoutIntensity: track.workoutIntensity
            )
        }
        
        let telemetry = RallyTelemetry(
            rallyIndex: rallyEngine.telemetry.rallyIndex,
            rallyDuration: rallyEngine.telemetry.rallyDuration,
            shotCount: rallyEngine.telemetry.shotCount,
            effectivePlayTime: rallyEngine.telemetry.effectivePlayTime,
            state: rallyEngine.state,
            currentScore: rallyEngine.telemetry.currentScore,
            serverIndex: rallyEngine.telemetry.serverIndex,
            peakBallSpeedKmh: ballTrackerService.peakSpeedKmh,
            currentBallSpeedKmh: ball?.velocityKmh ?? 0.0,
            lastBallObservation: ball,
            lastBounce: lastBounceObservation,
            latestVerdict: latestVerdict,
            players: playerMetrics,
            trajectoryTailCourt: ballTrackerService.trajectoryTrailCourt
        )
        
        DispatchQueue.main.async {
            self.trackedPlayers = players
            self.currentTelemetry = telemetry
        }
    }
    
    /// Reset toàn bộ pipeline cho pha bóng mới
    public func resetRally() {
        self.ballTrackerService.reset()
        self.playerTrackerService.reset()
        self.latestVerdict = nil
        self.lastBounceObservation = nil
        self.shotsInRally = 0
        self.bounceCountInRally = 0
    }
}
