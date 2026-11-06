//
//  PlayerDistanceFilterTests.swift
//  PickleVisionTests
//
//  Created by Tester Worker on 2026-11-05.
//  Player Jitter Filter (< 0.05m), Metric Distance Accumulation, and Speed Tracking Verification.
//

import XCTest
import CoreGraphics
import simd
@testable import PickleVision

final class PlayerDistanceFilterTests: XCTestCase {
    
    private var playerTrack: PlayerTrack!
    
    override func setUp() {
        super.setUp()
        playerTrack = PlayerTrack(
            playerIndex: 0,
            name: "Tú",
            team: .nearTeam,
            initialCourtPosition: CGPoint(x: 3.0480, y: 1.0000)
        )
    }
    
    override func tearDown() {
        playerTrack = nil
        super.tearDown()
    }
    
    // MARK: - 1. Kiểm Thử Bộ Lọc Rung Lắc Jitter: Triệt Tiêu Biến Thiên < 0.05m
    
    func testJitterFilter_SuppressesStaticMovementUnderThreshold() {
        // Sinh 100 khung hình người chơi ĐỨNG YÊN với nhiễu rung lắc cảm biến < 0.05m (3.8cm)
        let staticSequence = MockDataFeeds.generateStaticStandingSequence(
            basePositionCourt: CGPoint(x: 3.0480, y: 1.0000),
            frameCount: 100,
            fps: 60.0,
            noiseAmplitudeMeters: 0.038 // 3.8 cm < 5 cm
        )
        
        let initialPos = playerTrack.smoothedCourtPosition
        
        for frame in staticSequence {
            playerTrack.update(
                rawCourtPosition: frame.groundContact,
                timestamp: frame.timestamp,
                boundingBox: frame.boundingBox,
                leftAnkle: frame.leftAnkle,
                rightAnkle: frame.rightAnkle
            )
        }
        
        // Vì tất cả các biến thiên delta d đều < 0.05m, bộ lọc Jitter phải triệt tiêu 100%
        XCTAssertEqual(
            playerTrack.rallyDistanceMeters,
            0.0,
            accuracy: 1e-4,
            "Bộ lọc Jitter phải triệt tiêu hoàn toàn rung lắc dưới 0.05m khi cầu thủ đứng yên"
        )
        XCTAssertEqual(
            playerTrack.totalMatchDistanceMeters,
            0.0,
            accuracy: 1e-4,
            "Tổng quãng đường tích lũy cả trận cũng phải = 0.0m khi chỉ có rung lắc cảm biến"
        )
        XCTAssertEqual(
            playerTrack.speedMps,
            0.0,
            accuracy: 1e-4,
            "Vận tốc tức thời phải là 0.0 m/s khi đứng yên"
        )
    }
    
    // MARK: - 2. Kiểm Thử Tích Lũy Quãng Đường Chạy Nước Rút Thật (Sprint Distance)
    
    func testSprintDistanceAccumulation_CalculatesTrueMetricDistance() {
        // Cầu thủ chạy nước rút thẳng từ Y = 1.0m lên Y = 4.5m (vạch bếp).
        // Quãng đường vật lý thực tế = 4.5 - 1.0 = 3.5 mét.
        let sprintSequence = MockDataFeeds.generateLinearSprintSequence(
            startX: 3.0480,
            startY: 1.0000,
            endY: 4.5000,
            durationSeconds: 1.5,
            fps: 60.0
        )
        
        for frame in sprintSequence {
            // Chiếu tọa độ pixel của frame sang mét qua ma trận đồng nhất để update
            let courtPt = CGPoint(x: 3.0480, y: 1.0 + (frame.timestamp / 1.5) * 3.5)
            playerTrack.update(
                rawCourtPosition: courtPt,
                timestamp: frame.timestamp,
                boundingBox: frame.boundingBox,
                leftAnkle: frame.leftAnkle,
                rightAnkle: frame.rightAnkle
            )
        }
        
        print(" [Distance Test] Quãng đường chạy nước rút tính được: \(playerTrack.rallyDistanceMeters) mét (Kỳ vọng: ~3.5m)")
        
        XCTAssertEqual(
            Double(playerTrack.rallyDistanceMeters),
            3.5,
            accuracy: 0.15,
            "Quãng đường tính toán phải xấp xỉ chính xác 3.5m với sai số Kalman < 15cm"
        )
        XCTAssertEqual(
            playerTrack.totalMatchDistanceMeters,
            playerTrack.rallyDistanceMeters,
            "Trong pha đầu tiên, tổng quãng đường trận phải bằng quãng đường pha"
        )
    }
    
    // MARK: - 3. Kiểm Thử Di Chuyển Ngang Hai Chiều (Lateral Shuffling)
    
    func testLateralShuffle_CalculatesBidirectionalDistance() {
        // Cầu thủ bước ngang: từ X=1.5m sang X=4.5m (+3.0m), sau đó quay về X=1.5m (+3.0m)
        // Tổng quãng đường thực tế = 6.0 mét
        let shuffleSequence = MockDataFeeds.generateLateralShuffleSequence(
            yPosition: 2.0,
            leftX: 1.5,
            rightX: 4.5,
            durationSeconds: 2.0,
            fps: 60.0
        )
        
        let totalFrames = shuffleSequence.count
        for (i, frame) in shuffleSequence.enumerated() {
            let p = Double(i) / Double(totalFrames - 1)
            let currX = (p <= 0.5) ? (1.5 + p * 2.0 * 3.0) : (4.5 - (p - 0.5) * 2.0 * 3.0)
            let courtPt = CGPoint(x: currX, y: 2.0)
            
            playerTrack.update(
                rawCourtPosition: courtPt,
                timestamp: frame.timestamp,
                boundingBox: frame.boundingBox,
                leftAnkle: frame.leftAnkle,
                rightAnkle: frame.rightAnkle
            )
        }
        
        print(" [Distance Test] Quãng đường di chuyển ngang 2 chiều: \(playerTrack.rallyDistanceMeters) mét (Kỳ vọng: ~6.0m)")
        
        XCTAssertEqual(
            Double(playerTrack.rallyDistanceMeters),
            6.0,
            accuracy: 0.25,
            "Tổng quãng đường di chuyển ngang 2 chiều phải xấp xỉ 6.0m"
        )
    }
    
    // MARK: - 4. Kiểm Thử Loại Bỏ Bước Nhảy Phi Vật Lý (Physiological Speed Limit Rejection)
    
    func testPhysiologicalSpeedLimit_RejectsTeleportationGlitches() {
        let initialDistance = playerTrack.rallyDistanceMeters
        
        // Frame 1: Cầu thủ đang ở (3.048, 1.0)
        playerTrack.update(
            rawCourtPosition: CGPoint(x: 3.048, y: 1.0),
            timestamp: 1.0,
            boundingBox: CGRect(x: 930, y: 800, width: 60, height: 120),
            leftAnkle: nil,
            rightAnkle: nil
        )
        
        // Frame 2: Sau 0.033 giây, Vision nhận diện nhầm vị trí nhảy vọt sang (3.048, 16.0) -> Dịch chuyển 15 mét!
        // Vận tốc = 15m / 0.033s = 454 m/s (> 10.5 m/s, vượt quá giới hạn sinh lý người tối đa)
        playerTrack.update(
            rawCourtPosition: CGPoint(x: 3.048, y: 16.0),
            timestamp: 1.033,
            boundingBox: CGRect(x: 930, y: 200, width: 60, height: 120),
            leftAnkle: nil,
            rightAnkle: nil
        )
        
        // Bước nhảy bất thường này phải bị loại bỏ hoàn toàn
        XCTAssertEqual(
            playerTrack.rallyDistanceMeters,
            initialDistance,
            accuracy: 1e-3,
            "Bước nhảy phi vật lý (> 10.5 m/s) phải bị loại bỏ, không được cộng dồn vào quãng đường"
        )
        
        // Frame 3..12: Cầu thủ tiếp tục chạy bình thường 10 frame (vận tốc hợp lệ 3.0 m/s)
        // Nhờ cơ chế Pre-Gating, bộ lọc Kalman không bị ô nhiễm và phục hồi bám vết ngay lập tức (không tê liệt)
        for k in 1...10 {
            let t = 1.033 + Double(k) * 0.016
            let y = 1.0 + 3.0 * (Double(k) * 0.016)
            playerTrack.update(
                rawCourtPosition: CGPoint(x: 3.048, y: y),
                timestamp: t,
                boundingBox: CGRect(x: 930, y: 800, width: 60, height: 120),
                leftAnkle: nil,
                rightAnkle: nil
            )
        }
        
        XCTAssertGreaterThan(
            playerTrack.rallyDistanceMeters,
            initialDistance + 0.35,
            "Quá trình bám vết phải phục hồi ngay lập tức sau glitch, không bị hiện tượng tê liệt bám vết"
        )
    }
    
    // MARK: - 5. Kiểm Thử Quản Lý Hai Luồng Quãng Đường Song Song (Dual Distance Tracking)
    
    func testDualDistanceTracking_RallyVsMatchDistance() {
        // Pha 1: Cầu thủ chạy 3.0 mét
        playerTrack.update(
            rawCourtPosition: CGPoint(x: 3.048, y: 4.0),
            timestamp: 0.5,
            boundingBox: .zero,
            leftAnkle: nil,
            rightAnkle: nil
        )
        let rally1Dist = playerTrack.rallyDistanceMeters
        let match1Dist = playerTrack.totalMatchDistanceMeters
        
        XCTAssertGreaterThan(rally1Dist, 0.0)
        XCTAssertEqual(rally1Dist, match1Dist)
        
        // Kết thúc pha 1, bắt đầu pha 2: Gọi resetRallyDistance()
        playerTrack.resetRallyDistance()
        
        XCTAssertEqual(playerTrack.rallyDistanceMeters, 0.0, "Quãng đường pha phải reset về 0.0m cho pha mới")
        XCTAssertEqual(playerTrack.totalMatchDistanceMeters, match1Dist, "Tổng quãng đường cả trận phải được bảo toàn nguyên vẹn")
        
        // Pha 2: Cầu thủ chạy thêm 2.0 mét nữa
        playerTrack.update(
            rawCourtPosition: CGPoint(x: 3.048, y: 2.0),
            timestamp: 1.0,
            boundingBox: .zero,
            leftAnkle: nil,
            rightAnkle: nil
        )
        
        XCTAssertGreaterThan(playerTrack.rallyDistanceMeters, 0.0)
        XCTAssertEqual(
            playerTrack.totalMatchDistanceMeters,
            match1Dist + playerTrack.rallyDistanceMeters,
            accuracy: 1e-4,
            "Tổng quãng đường trận phải bằng tổng quãng đường tích lũy qua các pha"
        )
    }
    
    // MARK: - 6. Kiểm Thử Bộ Lọc Kalman 2D Cho Tọa Độ Sân (Metric Kalman Filter)
    
    func testKalmanFilter2D_SmoothsNoisyLinearTrajectory() {
        let kalman = KalmanFilter2D(initialPosition: CGPoint(x: 1.0, y: 1.0))
        
        // Cầu thủ di chuyển đều với vận tốc vx = 2.0 m/s, vy = 1.0 m/s
        let dt = 0.05
        var currentTrueX = 1.0
        var currentTrueY = 1.0
        
        for step in 1...20 {
            currentTrueX += 2.0 * dt
            currentTrueY += 1.0 * dt
            
            // Giả lập phép đo có nhiễu Gaussian ±0.15m
            let noiseX = (step % 2 == 0 ? 0.12 : -0.12)
            let noiseY = (step % 2 == 0 ? -0.10 : 0.10)
            let noisyMeasurement = CGPoint(x: currentTrueX + noiseX, y: currentTrueY + noiseY)
            
            _ = kalman.predict(dt: dt)
            let estimated = kalman.update(measurement: noisyMeasurement)
            
            // Khoảng cách từ ước lượng của Kalman đến vị trí thực tế
            let errorFromTrue = hypot(estimated.x - currentTrueX, estimated.y - currentTrueY)
            let errorFromMeasurement = hypot(noisyMeasurement.x - currentTrueX, noisyMeasurement.y - currentTrueY)
            
            // Sau vài bước hội tụ, Kalman phải mượt hơn phép đo nhiễu
            if step > 5 {
                XCTAssertLessThanOrEqual(
                    errorFromTrue,
                    errorFromMeasurement + 0.05,
                    "Kalman Filter phải làm mượt và giảm độ lệch của quan sát nhiễu"
                )
            }
        }
    }
}
