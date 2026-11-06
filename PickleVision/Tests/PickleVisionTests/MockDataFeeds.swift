//
//  MockDataFeeds.swift
//  PickleVisionTests
//
//  Created by Tester Worker on 2026-11-05.
//  Synthetic Sensor Feeds, Ground Truth Court Coordinates, Player Pose Sequences, and Ball Parabolic Trajectories.
//

import Foundation
import CoreGraphics
import CoreVideo
import simd
@testable import PickleVision

/// Bộ sinh dữ liệu giả lập và điểm chuẩn toán học cho bộ kiểm thử PickleVision
public struct MockDataFeeds {
    
    // MARK: - 1. Tọa Độ Sân Chuẩn & Điểm Mốc Quang Học (Court Landmarks)
    
    /// Kích thước sân chuẩn USA Pickleball (mét)
    public static let courtWidth: Double = CourtDimensions.width         // 6.0960m
    public static let courtLength: Double = CourtDimensions.length       // 13.4112m
    public static let nearNVZY: Double = CourtDimensions.nearNVZY        // 4.5720m
    public static let farNVZY: Double = CourtDimensions.farNVZY          // 8.8392m
    public static let netY: Double = CourtDimensions.netY                // 6.7056m
    public static let centerLineX: Double = CourtDimensions.centerLineX  // 3.0480m
    
    /// 4 điểm chốt góc sân thực tế (Ground Truth World Points) tính bằng mét (Baseline Origin)
    /// Thứ tự: Near-Left, Near-Right, Far-Right, Far-Left
    public static let groundTruthCourtCorners: [CGPoint] = [
        CGPoint(x: 0.0000, y: 0.0000),             // Near-Left Baseline
        CGPoint(x: 6.0960, y: 0.0000),             // Near-Right Baseline
        CGPoint(x: 6.0960, y: 13.4112),            // Far-Right Baseline
        CGPoint(x: 0.0000, y: 13.4112)             // Far-Left Baseline
    ]
    
    /// Tọa độ Pixel chuẩn 1080p (1920x1080) của 4 góc sân từ camera đặt tại độ cao 2.2m sau vạch đáy
    public static let cameraPixelCorners: [CGPoint] = [
        CGPoint(x: 240.0, y: 960.0),               // Near-Left
        CGPoint(x: 1680.0, y: 960.0),              // Near-Right
        CGPoint(x: 1260.0, y: 320.0),              // Far-Right
        CGPoint(x: 660.0, y: 320.0)                // Far-Left
    ]
    
    /// 8 Điểm kiểm chứng độc lập (Independent Validation Landmarks) trên sân thực tế (mét)
    /// Dùng để kiểm tra sai số tái chiếu của ma trận Homography tại các điểm KHÔNG nằm trong 4 góc hiệu chuẩn
    public static let validationLandmarksCourt: [(name: String, court: CGPoint)] = [
        ("Near_NVZ_Left", CGPoint(x: 0.0000, y: 4.5720)),
        ("Near_NVZ_Center", CGPoint(x: 3.0480, y: 4.5720)),
        ("Near_NVZ_Right", CGPoint(x: 6.0960, y: 4.5720)),
        ("Net_Left", CGPoint(x: 0.0000, y: 6.7056)),
        ("Net_Center", CGPoint(x: 3.0480, y: 6.7056)),
        ("Net_Right", CGPoint(x: 6.0960, y: 6.7056)),
        ("Far_NVZ_Left", CGPoint(x: 0.0000, y: 8.8392)),
        ("Far_NVZ_Center", CGPoint(x: 3.0480, y: 8.8392)),
        ("Far_NVZ_Right", CGPoint(x: 6.0960, y: 8.8392)),
        ("Near_Baseline_Center", CGPoint(x: 3.0480, y: 0.0000)),
        ("Far_Baseline_Center", CGPoint(x: 3.0480, y: 13.4112))
    ]
    
    /// Chiếu điểm sân thực tế (X, Y mét) sang tọa độ pixel camera 1080p theo phép chiếu xạ ảnh phối cảnh thực tế
    public static func projectCourtToPixelExact(courtX: Double, courtY: Double) -> CGPoint {
        // Ma trận H_inv chính xác tuyệt đối chuyển đổi từ Tọa độ sân (X, Y mét) sang Tọa độ ảnh (u, v pixel)
        // Hệ số chuẩn hóa:
        let h00 = 29.5275590551
        let h01 = 12.5268470968
        let h02 = 29.9997410790
        let h11 = -1.7895490336
        let h12 = 120.0000000000
        let h21 = 0.0130487950
        let h22 = 0.1250000000
        
        let w = h21 * courtY + h22
        guard abs(w) > 1e-9 else { return .zero }
        
        let u = (h00 * courtX + h01 * courtY + h02) / w
        let v = (h11 * courtY + h12) / w
        return CGPoint(x: u, y: v)
    }
    
    // MARK: - 2. Chuỗi Tọa Độ Khớp Cổ Chân Giả Lập (Player Ankle Motion Sequences)
    
    /// Dữ liệu frame vị trí cổ chân người chơi
    public struct AnkleFrame {
        public let timestamp: TimeInterval
        public let leftAnkle: CGPoint
        public let rightAnkle: CGPoint
        public let groundContact: CGPoint
        public let boundingBox: CGRect
        
        public init(timestamp: TimeInterval, leftAnkle: CGPoint, rightAnkle: CGPoint, groundContact: CGPoint, boundingBox: CGRect) {
            self.timestamp = timestamp
            self.leftAnkle = leftAnkle
            self.rightAnkle = rightAnkle
            self.groundContact = groundContact
            self.boundingBox = boundingBox
        }
    }
    
    /// Sinh chuỗi 100 khung hình người chơi ĐỨNG YÊN với nhiễu rung lắc cảm biến < 0.05m (< 5cm)
    public static func generateStaticStandingSequence(
        basePositionCourt: CGPoint = CGPoint(x: 3.048, y: 2.0),
        frameCount: Int = 100,
        fps: Double = 60.0,
        noiseAmplitudeMeters: Double = 0.038 // 3.8 cm (< 5 cm)
    ) -> [AnkleFrame] {
        var sequence: [AnkleFrame] = []
        let dt = 1.0 / fps
        
        // Seed giả lập có tính tất định (Deterministic Pseudo-Random)
        var seed: UInt64 = 123456789
        func pseudoRandom() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let val = Double((seed >> 32) & 0xFFFFFF) / Double(0xFFFFFF)
            return (val * 2.0) - 1.0 // [-1.0, 1.0]
        }
        
        for i in 0..<frameCount {
            let t = Double(i) * dt
            let noiseX = pseudoRandom() * noiseAmplitudeMeters
            let noiseY = pseudoRandom() * noiseAmplitudeMeters
            
            let currentCourt = CGPoint(
                x: basePositionCourt.x + noiseX,
                y: basePositionCourt.y + noiseY
            )
            
            let pixelPos = projectCourtToPixelExact(courtX: currentCourt.x, courtY: currentCourt.y)
            let leftAnkle = CGPoint(x: pixelPos.x - 12.0, y: pixelPos.y)
            let rightAnkle = CGPoint(x: pixelPos.x + 12.0, y: pixelPos.y)
            let bbox = CGRect(x: pixelPos.x - 30.0, y: pixelPos.y - 120.0, width: 60.0, height: 120.0)
            
            sequence.append(AnkleFrame(
                timestamp: t,
                leftAnkle: leftAnkle,
                rightAnkle: rightAnkle,
                groundContact: pixelPos,
                boundingBox: bbox
            ))
        }
        return sequence
    }
    
    /// Sinh chuỗi chạy nước rút thẳng (Linear Sprint): từ vạch đáy (Y=1.0) lên vạch bếp (Y=4.5) -> Quãng đường = 3.5 mét
    public static func generateLinearSprintSequence(
        startX: Double = 3.048,
        startY: Double = 1.0,
        endY: Double = 4.5,
        durationSeconds: Double = 1.5,
        fps: Double = 60.0
    ) -> [AnkleFrame] {
        var sequence: [AnkleFrame] = []
        let totalFrames = Int(durationSeconds * fps)
        let dt = 1.0 / fps
        
        for i in 0...totalFrames {
            let t = Double(i) * dt
            let progress = min(1.0, t / durationSeconds)
            // Tăng tốc mượt dạng hàm sigmoid: s(p) = 3*p^2 - 2*p^3
            let smoothProgress = 3.0 * progress * progress - 2.0 * progress * progress * progress
            let currentY = startY + (endY - startY) * smoothProgress
            
            let courtPos = CGPoint(x: startX, y: currentY)
            let pixelPos = projectCourtToPixelExact(courtX: courtPos.x, courtY: courtPos.y)
            let leftAnkle = CGPoint(x: pixelPos.x - 14.0, y: pixelPos.y)
            let rightAnkle = CGPoint(x: pixelPos.x + 14.0, y: pixelPos.y)
            let bbox = CGRect(x: pixelPos.x - 35.0, y: pixelPos.y - 130.0, width: 70.0, height: 130.0)
            
            sequence.append(AnkleFrame(
                timestamp: t,
                leftAnkle: leftAnkle,
                rightAnkle: rightAnkle,
                groundContact: pixelPos,
                boundingBox: bbox
            ))
        }
        return sequence
    }
    
    /// Sinh chuỗi di chuyển ngang (Lateral Shuffling): X từ 1.5m sang 4.5m rồi quay về 1.5m (Tổng quãng đường = 6.0 mét)
    public static func generateLateralShuffleSequence(
        yPosition: Double = 2.5,
        leftX: Double = 1.5,
        rightX: Double = 4.5,
        durationSeconds: Double = 2.0,
        fps: Double = 60.0
    ) -> [AnkleFrame] {
        var sequence: [AnkleFrame] = []
        let totalFrames = Int(durationSeconds * fps)
        let dt = 1.0 / fps
        let halfFrames = totalFrames / 2
        
        for i in 0...totalFrames {
            let t = Double(i) * dt
            let currentX: Double
            if i <= halfFrames {
                let p = Double(i) / Double(halfFrames)
                currentX = leftX + (rightX - leftX) * p
            } else {
                let p = Double(i - halfFrames) / Double(halfFrames)
                currentX = rightX - (rightX - leftX) * p
            }
            
            let courtPos = CGPoint(x: currentX, y: yPosition)
            let pixelPos = projectCourtToPixelExact(courtX: courtPos.x, courtY: courtPos.y)
            let leftAnkle = CGPoint(x: pixelPos.x - 12.0, y: pixelPos.y)
            let rightAnkle = CGPoint(x: pixelPos.x + 12.0, y: pixelPos.y)
            let bbox = CGRect(x: pixelPos.x - 30.0, y: pixelPos.y - 120.0, width: 60.0, height: 120.0)
            
            sequence.append(AnkleFrame(
                timestamp: t,
                leftAnkle: leftAnkle,
                rightAnkle: rightAnkle,
                groundContact: pixelPos,
                boundingBox: bbox
            ))
        }
        return sequence
    }
    
    /// Sinh chuỗi bước nhảy lỗi cảm biến (Teleportation Glitch Step): bước nhảy đột ngột 15 mét trong 1 frame
    public static func generateGlitchStepSequence(fps: Double = 60.0) -> [AnkleFrame] {
        let dt = 1.0 / fps
        let f1 = AnkleFrame(
            timestamp: 0.0,
            leftAnkle: CGPoint(x: 950, y: 800),
            rightAnkle: CGPoint(x: 970, y: 800),
            groundContact: CGPoint(x: 960, y: 800),
            boundingBox: CGRect(x: 930, y: 680, width: 60, height: 120)
        )
        // Frame 2 nhảy vọt sang vị trí cách xa 15 mét trên sân
        let f2 = AnkleFrame(
            timestamp: dt,
            leftAnkle: CGPoint(x: 1800, y: 200),
            rightAnkle: CGPoint(x: 1820, y: 200),
            groundContact: CGPoint(x: 1810, y: 200),
            boundingBox: CGRect(x: 1780, y: 80, width: 60, height: 120)
        )
        return [f1, f2]
    }
    
    // MARK: - 3. Vector Quỹ Đạo Bóng Parabol & Chuỗi Điểm Nảy (Ball Trajectories)
    
    /// Dữ liệu một frame quan sát bóng trong quỹ đạo bay
    public struct BallTrajectoryPoint {
        public let timestamp: TimeInterval
        public let court3D: SIMD3<Float> // (X, Y, Z mét)
        public let pixel2D: CGPoint
        public let velocityKmh: Float
        public let isBounce: Bool
        
        public init(timestamp: TimeInterval, court3D: SIMD3<Float>, pixel2D: CGPoint, velocityKmh: Float, isBounce: Bool) {
            self.timestamp = timestamp
            self.court3D = court3D
            self.pixel2D = pixel2D
            self.velocityKmh = velocityKmh
            self.isBounce = isBounce
        }
    }
    
    /// Sinh quỹ đạo bóng bay parabol tự do và rơi nảy trên mặt đất
    /// - Parameters:
    ///   - startCourt: Tọa độ bắt đầu (X, Y, Z) mét
    ///   - initialVelocity: Vận tốc ban đầu (vx, vy, vz) mét/giây
    ///   - duration: Thời gian bay (giây)
    ///   - fps: Tốc độ khung hình (ví dụ 60.0 hoặc 120.0)
    public static func generateParabolicTrajectory(
        startCourt: SIMD3<Float> = SIMD3<Float>(4.5, 1.0, 1.2),
        initialVelocity: SIMD3<Float> = SIMD3<Float>(0.0, 10.0, 3.5),
        duration: Double = 1.0,
        fps: Double = 60.0
    ) -> [BallTrajectoryPoint] {
        var points: [BallTrajectoryPoint] = []
        let totalFrames = Int(duration * fps)
        let dt = Float(1.0 / fps)
        let g: Float = 9.81 // Gia tốc trọng trường
        
        var x = startCourt.x
        var y = startCourt.y
        var z = startCourt.z
        var vx = initialVelocity.x
        var vy = initialVelocity.y
        var vz = initialVelocity.z
        
        for i in 0..<totalFrames {
            let t = Double(i) * Double(dt)
            
            // Cập nhật vị trí
            x += vx * dt
            y += vy * dt
            z += vz * dt
            
            // Cập nhật vận tốc trục đứng do trọng lực
            vz -= g * dt
            
            var isBounce = false
            // Phát hiện chạm đất (Z <= 0)
            if z <= 0.0 {
                z = 0.0
                isBounce = true
                vz = -vz * 0.65 // Đổi chiều vận tốc thẳng đứng với hệ số đàn hồi 0.65
            }
            
            let speedMps = sqrt(vx * vx + vy * vy + vz * vz)
            let speedKmh = speedMps * 3.6
            
            let court3D = SIMD3<Float>(x, y, z)
            let pixelPt = projectCourtToPixelExact(courtX: Double(x), courtY: Double(y))
            // Điều chỉnh tọa độ pixel y theo độ cao z của bóng: pixel Y càng nhỏ khi bóng càng cao
            let heightAdjustment = CGFloat(z * 45.0)
            let adjustedPixel = CGPoint(x: pixelPt.x, y: pixelPt.y - heightAdjustment)
            
            points.append(BallTrajectoryPoint(
                timestamp: t,
                court3D: court3D,
                pixel2D: adjustedPixel,
                velocityKmh: speedKmh,
                isBounce: isBounce
            ))
        }
        return points
    }
    
    // MARK: - 4. Các Tình Huống Biên Cụ Thể (USA Pickleball Rule Cases)
    
    public struct RuleScenarioCase {
        public let name: String
        public let bounceCourt: CGPoint
        public let isServe: Bool
        public let targetServiceBox: ServiceBox?
        public let expectedVerdict: InOutVerdict
        public let ruleReference: String
    }
    
    /// Danh mục 100% các tình huống kiểm thử luật theo USA Pickleball Rulebook
    public static let allRuleScenarios: [RuleScenarioCase] = [
        // GIAO BÓNG (SERVE)
        RuleScenarioCase(
            name: "Giao bóng chạm vạch bếp xa (Far Kitchen Line)",
            bounceCourt: CGPoint(x: 4.5000, y: 8.8392),
            isServe: true,
            targetServiceBox: .farRight,
            expectedVerdict: .faultKitchenServe,
            ruleReference: "USAP Rule 4.A.2: The serve must clear the net and NVZ, including the NVZ lines."
        ),
        RuleScenarioCase(
            name: "Giao bóng rơi trong khu vực bếp xa (Inside Far NVZ)",
            bounceCourt: CGPoint(x: 4.5000, y: 7.5000),
            isServe: true,
            targetServiceBox: .farRight,
            expectedVerdict: .faultKitchenServe,
            ruleReference: "USAP Rule 4.A.2: Short serve into NVZ is a fault."
        ),
        RuleScenarioCase(
            name: "Giao bóng chạm vạch bếp gần (Near Kitchen Line)",
            bounceCourt: CGPoint(x: 1.5000, y: 4.5720),
            isServe: true,
            targetServiceBox: .nearLeft,
            expectedVerdict: .faultKitchenServe,
            ruleReference: "USAP Rule 4.A.2: NVZ line is not included in the service court."
        ),
        RuleScenarioCase(
            name: "Giao bóng chạm mép vạch đáy xa (Far Baseline Touch)",
            bounceCourt: CGPoint(x: 4.5000, y: 13.4112),
            isServe: true,
            targetServiceBox: .farRight,
            expectedVerdict: .inBound,
            ruleReference: "USAP Rule 6.A: Boundary lines are IN."
        ),
        RuleScenarioCase(
            name: "Giao bóng chạm vạch biên phải xa (Far Right Sideline Touch)",
            bounceCourt: CGPoint(x: 6.0960, y: 11.2000),
            isServe: true,
            targetServiceBox: .farRight,
            expectedVerdict: .inBound,
            ruleReference: "USAP Rule 6.A: Sidelines are IN."
        ),
        RuleScenarioCase(
            name: "Giao bóng chạm vạch giữa (Centerline Touch)",
            bounceCourt: CGPoint(x: 3.0480, y: 10.5000),
            isServe: true,
            targetServiceBox: .farRight,
            expectedVerdict: .inBound,
            ruleReference: "USAP Rule 4.A.2: Centerline is IN on serve."
        ),
        RuleScenarioCase(
            name: "Giao bóng sâu ra ngoài vạch đáy xa (Long Serve)",
            bounceCourt: CGPoint(x: 4.5000, y: 13.5500),
            isServe: true,
            targetServiceBox: .farRight,
            expectedVerdict: .outOfBound,
            ruleReference: "USAP Rule 6.A: Ball beyond baseline is OUT."
        ),
        RuleScenarioCase(
            name: "Giao bóng rộng ra ngoài vạch biên (Wide Serve)",
            bounceCourt: CGPoint(x: 6.2500, y: 11.0000),
            isServe: true,
            targetServiceBox: .farRight,
            expectedVerdict: .outOfBound,
            ruleReference: "USAP Rule 6.A: Ball beyond sideline is OUT."
        ),
        RuleScenarioCase(
            name: "Giao bóng nhầm ô chéo (Wrong Service Box)",
            bounceCourt: CGPoint(x: 1.5000, y: 10.5000), // Rơi vào Far-Left khi target là Far-Right
            isServe: true,
            targetServiceBox: .farRight,
            expectedVerdict: .outOfBound,
            ruleReference: "USAP Rule 4.A.2: Serve into wrong court is OUT."
        ),
        
        // PHA BÓNG SỐNG (LIVE RALLY)
        RuleScenarioCase(
            name: "Pha bóng sống rơi trong khu vực bếp (Live Ball Inside NVZ)",
            bounceCourt: CGPoint(x: 3.0480, y: 6.0000),
            isServe: false,
            targetServiceBox: nil,
            expectedVerdict: .inBound,
            ruleReference: "USAP Rule 2.B.3: During live rally, ball in kitchen is 100% legal (IN)."
        ),
        RuleScenarioCase(
            name: "Pha bóng sống chạm vạch bếp (Live Ball on NVZ Line)",
            bounceCourt: CGPoint(x: 2.0000, y: 4.5720),
            isServe: false,
            targetServiceBox: nil,
            expectedVerdict: .inBound,
            ruleReference: "USAP Rule 2.B.3: NVZ line is IN during live play."
        ),
        RuleScenarioCase(
            name: "Pha bóng sống chạm vạch biên trái (Live Sideline Touch)",
            bounceCourt: CGPoint(x: 0.0000, y: 7.2000),
            isServe: false,
            targetServiceBox: nil,
            expectedVerdict: .inBound,
            ruleReference: "USAP Rule 6.A: Line touches are IN."
        ),
        RuleScenarioCase(
            name: "Pha bóng sống chạm góc vạch đáy (Baseline Corner Touch)",
            bounceCourt: CGPoint(x: 6.0960, y: 13.4112),
            isServe: false,
            targetServiceBox: nil,
            expectedVerdict: .inBound,
            ruleReference: "USAP Rule 6.A: Baseline corner touch is IN."
        ),
        RuleScenarioCase(
            name: "Pha bóng sống rơi ngoài vạch biên (Live Out of Bounds)",
            bounceCourt: CGPoint(x: -0.0600, y: 5.5000),
            isServe: false,
            targetServiceBox: nil,
            expectedVerdict: .outOfBound,
            ruleReference: "USAP Rule 6.A: Ball completely outside boundary is OUT."
        ),
        RuleScenarioCase(
            name: "Pha bóng sống rơi ngoài vạch đáy (Live Baseline Out)",
            bounceCourt: CGPoint(x: 3.0480, y: 13.4900),
            isServe: false,
            targetServiceBox: nil,
            expectedVerdict: .outOfBound,
            ruleReference: "USAP Rule 6.A: Ball completely beyond baseline is OUT."
        )
    ]
    
    // MARK: - 5. Mock CVPixelBuffer & Frame Generator
    
    /// Tạo một CVPixelBuffer giả lập kích thước 1920x1080 định dạng 32BGRA
    /// Có thể tùy chọn vẽ một đốm màu vàng neon (quá bóng) tại vị trí chỉ định
    public static func createMockPixelBuffer(
        width: Int = 1920,
        height: Int = 1080,
        ballCenter: CGPoint? = nil,
        ballRadius: CGFloat = 8.0
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return buffer
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Tô nền xanh xám mô phỏng mặt sân pickleball
        // BGRA: B=110, G=70, R=40, A=255
        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let pixelOffset = rowOffset + x * 4
                ptr[pixelOffset] = 110     // Blue
                ptr[pixelOffset + 1] = 70  // Green
                ptr[pixelOffset + 2] = 40  // Red
                ptr[pixelOffset + 3] = 255 // Alpha
            }
        }
        
        // Vẽ đốm vàng neon (quả bóng) nếu có
        if let ball = ballCenter {
            let cx = Int(ball.x)
            let cy = Int(ball.y)
            let r = Int(ballRadius)
            let rSq = r * r
            
            let minY = max(0, cy - r)
            let maxY = min(height - 1, cy + r)
            let minX = max(0, cx - r)
            let maxX = min(width - 1, cx + r)
            
            for y in minY...maxY {
                let dy = y - cy
                let rowOffset = y * bytesPerRow
                for x in minX...maxX {
                    let dx = x - cx
                    if (dx * dx + dy * dy) <= rSq {
                        let pixelOffset = rowOffset + x * 4
                        // Màu vàng neon Optic Yellow: R=210, G=245, B=40, A=255
                        ptr[pixelOffset] = 40      // Blue
                        ptr[pixelOffset + 1] = 245 // Green
                        ptr[pixelOffset + 2] = 210 // Red
                        ptr[pixelOffset + 3] = 255 // Alpha
                    }
                }
            }
        }
        
        return buffer
    }
}
