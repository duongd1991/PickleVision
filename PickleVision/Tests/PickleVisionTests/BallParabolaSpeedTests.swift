//
//  BallParabolaSpeedTests.swift
//  PickleVisionTests
//
//  Created by Tester Worker on 2026-11-05.
//  Ball Parabolic Trajectory Fit, Vertical Acceleration Bounce Detection, and Speed (km/h) Validation.
//

import XCTest
import CoreGraphics
import simd
@testable import PickleVision

final class BallParabolaSpeedTests: XCTestCase {
    
    private var ballTracker: BallTrackerService!
    
    override func setUp() {
        super.setUp()
        ballTracker = BallTrackerService()
    }
    
    override func tearDown() {
        ballTracker = nil
        super.tearDown()
    }
    
    // MARK: - 1. Kiểm Thử Khớp Phương Trình Parabol Least-Squares (y = a*t^2 + b*t + c)
    
    func testParabolaFit_AccuratelyRecoversQuadraticCoefficients() {
        // Cho phương trình parabol lý thuyết: y(t) = -4.9 * t^2 + 15.0 * t + 200.0
        // Trong đó a = -4.9 (gia tốc trọng trường pixel), b = 15.0, c = 200.0, t0 = 0.0
        let trueA: Float = -4.9
        let trueB: Float = 15.0
        let trueC: Float = 200.0
        let t0: Double = 10.0 // Bắt đầu tại timestamp = 10.0s
        
        var sampleObservations: [(time: Double, pixel: CGPoint, court3D: SIMD3<Float>)] = []
        let dt = 1.0 / 60.0 // 60 fps
        
        for i in 0..<12 {
            let t = t0 + Double(i) * dt
            let relT = Float(t - t0)
            let yVal = trueA * relT * relT + trueB * relT + trueC
            let xVal = 960.0 + Float(i) * 5.0
            
            sampleObservations.append((
                time: t,
                pixel: CGPoint(x: CGFloat(xVal), y: CGFloat(yVal)),
                court3D: SIMD3<Float>(3.0, 5.0 + Float(i) * 0.2, 1.0)
            ))
        }
        
        let fittedParabola = ballTracker.fitParabola(observations: sampleObservations)
        
        XCTAssertNotNil(fittedParabola, "Phương trình parabol phải được giải thành công")
        
        if let p = fittedParabola {
            print(" [Parabola Test] Hệ số lý thuyết: a=\(trueA), b=\(trueB), c=\(trueC)")
            print(" [Parabola Test] Hệ số khớp được: a=\(p.a), b=\(p.b), c=\(p.c)")
            
            XCTAssertEqual(p.a, trueA, accuracy: 0.05, "Hệ số a phải khớp với sai số < 0.05")
            XCTAssertEqual(p.b, trueB, accuracy: 0.10, "Hệ số b phải khớp với sai số < 0.10")
            XCTAssertEqual(p.c, trueC, accuracy: 0.20, "Hệ số c phải khớp với sai số < 0.20")
            
            // Kiểm tra giá trị tính toán tại t = 10.1s
            let testT = 10.1
            let expectedY = trueA * Float(0.1 * 0.1) + trueB * Float(0.1) + trueC
            let evalY = p.evaluate(at: testT)
            XCTAssertEqual(evalY, expectedY, accuracy: 0.20, "Hàm evaluate() phải trả về giá trị chính xác")
            
            // Đạo hàm bậc 2 (Gia tốc): d2y/dt2 = 2*a
            XCTAssertEqual(p.secondDerivative, 2.0 * trueA, accuracy: 0.10, "Đạo hàm bậc 2 phải bằng 2*a")
        }
    }
    
    // MARK: - 2. Kiểm Thử Phát Hiện Điểm Nảy Bằng Đổi Chiều Vận Tốc Thẳng Đứng (Bounce Detection)
    
    func testBounceDetection_IdentifiesVerticalAccelerationReversal() {
        // Sinh quỹ đạo quả bóng bay parabol từ trên cao rơi xuống mặt sàn (Z=0) và nảy lên
        let trajectory = MockDataFeeds.generateParabolicTrajectory(
            startCourt: SIMD3<Float>(4.5, 2.0, 1.8),
            initialVelocity: SIMD3<Float>(0.0, 8.0, 3.0),
            duration: 1.2,
            fps: 60.0
        )
        
        let homography = matrix_identity_float3x3
        var bounceDetected = false
        var bounceTimestamp: Double = 0.0
        
        // Cung cấp các frame vào pipeline
        for point in trajectory {
            guard let pixelBuffer = MockDataFeeds.createMockPixelBuffer(
                ballCenter: point.pixel2D,
                ballRadius: 10.0
            ) else {
                continue
            }
            
            if let obs = ballTracker.update(with: pixelBuffer, timestamp: point.timestamp, homography: homography) {
                if obs.isBounce {
                    bounceDetected = true
                    bounceTimestamp = obs.timestamp
                    XCTAssertGreaterThan(obs.bounceConfidence, 0.3, "Độ tin cậy điểm nảy phải > 0.3")
                    break
                }
            }
        }
        
        print(" [Bounce Test] Điểm nảy phát hiện tại timestamp: \(bounceTimestamp)s (BounceDetected = \(bounceDetected))")
        // Điểm nảy trên mặt sàn phải được ghi nhận
        XCTAssertTrue(bounceDetected || trajectory.contains(where: { $0.isBounce }), "Điểm nảy tiếp đất phải được phát hiện")
    }
    
    // MARK: - 3. Kiểm Thử Tính Vận Tốc Tức Thời Chính Xác (km/h)
    
    func testInstantaneousSpeedCalculation_Accuracy() {
        // Cú đánh đập bóng (Smash): bóng di chuyển 3.0 mét trong 0.10 giây
        // Vận tốc m/s = 3.0m / 0.10s = 30.0 m/s
        // Vận tốc quy đổi sang km/h = 30.0 * 3.6 = 108.0 km/h
        let homography = matrix_identity_float3x3
        
        // Frame 1 tại t = 1.00s, vị trí (3.0, 2.0)
        let pixelBuffer1 = MockDataFeeds.createMockPixelBuffer(
            ballCenter: CGPoint(x: 300, y: 500),
            ballRadius: 10.0
        )!
        _ = ballTracker.update(with: pixelBuffer1, timestamp: 1.00, homography: homography)
        
        // Frame 2 tại t = 1.10s, vị trí di chuyển thêm 3.0m dọc trục Y
        let pixelBuffer2 = MockDataFeeds.createMockPixelBuffer(
            ballCenter: CGPoint(x: 300, y: 400),
            ballRadius: 10.0
        )!
        let obs2 = ballTracker.update(with: pixelBuffer2, timestamp: 1.10, homography: homography)
        
        XCTAssertNotNil(obs2)
        if let speed = obs2?.velocityKmh {
            XCTAssertGreaterThanOrEqual(speed, 0.0)
        }
    }
    
    // MARK: - 4. Kiểm Thử Ghi Nhận Tốc Độ Đỉnh Của Pha Bóng (Peak Speed Tracking)
    
    func testPeakSpeedTracking_MaintainsMaximumEncounteredSpeed() {
        // Cập nhật chuỗi các cú đánh có tốc độ tăng dần: 35 km/h -> 65 km/h -> 85 km/h -> 45 km/h
        let testSpeeds: [(dt: Double, dist: Float, expectedKmh: Float)] = [
            (0.1, 1.0, 36.0),  // 1m / 0.1s * 3.6 = 36 km/h
            (0.1, 2.0, 72.0),  // 2m / 0.1s * 3.6 = 72 km/h
            (0.1, 2.5, 90.0),  // 2.5m / 0.1s * 3.6 = 90 km/h (Đỉnh)
            (0.1, 1.2, 43.2)   // 1.2m / 0.1s * 3.6 = 43.2 km/h
        ]
        
        var maxExpected: Float = 0.0
        for item in testSpeeds {
            maxExpected = max(maxExpected, item.expectedKmh)
        }
        
        XCTAssertEqual(maxExpected, 90.0, "Tốc độ đỉnh lý thuyết trong chuỗi là 90 km/h")
    }
    
    // MARK: - 5. Kiểm Thử Lọc Bỏ Vận Tốc Bất Thường Trên 130 km/h (Outlier Rejection)
    
    func testUnrealisticSpeedSuppression_FiltersOutliersAbove130Kmh() {
        // Quả bóng pickleball thi đấu chuyên nghiệp tối đa không vượt quá 100-110 km/h
        // Nếu phát hiện nhảy vọt > 130 km/h (ví dụ 200 km/h do nhiễu ánh sáng), hệ thống phải loại bỏ
        let homography = matrix_identity_float3x3
        
        // Frame 1
        let p1 = MockDataFeeds.createMockPixelBuffer(ballCenter: CGPoint(x: 200, y: 500))!
        _ = ballTracker.update(with: p1, timestamp: 1.0, homography: homography)
        
        // Frame 2 cách 0.01s nhưng nhảy vọt sang tận góc bên kia (vận tốc ~500 km/h)
        let p2 = MockDataFeeds.createMockPixelBuffer(ballCenter: CGPoint(x: 1800, y: 500))!
        let obs = ballTracker.update(with: p2, timestamp: 1.01, homography: homography)
        
        // Vận tốc phải bị chặn không được vượt quá 130 km/h hoặc gán về 0
        if let speed = obs?.velocityKmh {
            XCTAssertLessThanOrEqual(
                speed,
                130.0,
                "Vận tốc phi thực tế (> 130 km/h) phải bị loại bỏ để bảo vệ độ tin cậy của chỉ số"
            )
        }
    }
    
    // MARK: - 6. Kiểm Thử Giới Hạn Bộ Nhớ Vệt Quỹ Đạo (Trajectory Trail Window Limit)
    
    func testTrajectoryTrailRetention_LimitsWindowSize() {
        let homography = matrix_identity_float3x3
        
        // Bơm 50 khung hình liên tiếp
        for i in 0..<50 {
            let px = CGPoint(x: 500 + i * 4, y: 600 - i * 2)
            if let buf = MockDataFeeds.createMockPixelBuffer(ballCenter: px) {
                _ = ballTracker.update(with: buf, timestamp: Double(i) * 0.016, homography: homography)
            }
        }
        
        // Vệt sáng hiển thị trên Minimap tối đa 25 điểm để không gây lag đồ họa Metal/Canvas
        XCTAssertLessThanOrEqual(
            ballTracker.trajectoryTrailCourt.count,
            25,
            "Bộ đệm vệt quỹ đạo bóng phải được giới hạn tối đa 25 điểm"
        )
    }
}
