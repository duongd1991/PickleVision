//
//  BallTrackerService.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  High-speed Ball Detection, Parabolic Trajectory Fit, Speed (km/h) and Vertical Bounce Detection.
//

import Foundation
import CoreGraphics
import CoreVideo
import simd

/// Interface protocol cho module theo dõi bóng
public protocol BallTracking: AnyObject {
    func update(with pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, homography: simd_float3x3) -> BallObservation?
    func reset()
}

/// Hệ số phương trình Parabol: y(t) = a * t^2 + b * t + c
public struct ParabolaCoefficients {
    public let a: Float
    public let b: Float
    public let c: Float
    public let timeOffset: Double
    
    public func evaluate(at t: Double) -> Float {
        let dt = Float(t - timeOffset)
        return a * dt * dt + b * dt + c
    }
    
    public func derivative(at t: Double) -> Float {
        let dt = Float(t - timeOffset)
        return 2.0 * a * dt + b
    }
    
    public var secondDerivative: Float {
        return 2.0 * a
    }
}

/// Dịch vụ dò tìm và theo dõi bóng Pickleball tốc độ cao
public final class BallTrackerService: BallTracking, ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var latestObservation: BallObservation?
    @Published public private(set) var recentObservations: [BallObservation] = []
    @Published public private(set) var trajectoryTrailCourt: [CGPoint] = []
    @Published public private(set) var peakSpeedKmh: Float = 0.0
    
    // Bộ đệm 2 frame trước để trừ nền vi sai 3 khung hình
    private var previousBuffer1: CVPixelBuffer?
    private var previousBuffer2: CVPixelBuffer?
    
    // Cửa sổ trượt lưu các quan sát gần nhất để khớp parabol (5 - 12 frames)
    private var trajectoryWindow: [(time: Double, pixel: CGPoint, court3D: SIMD3<Float>)] = []
    private let maxWindowSize: Int = 12
    
    // Trạng thái phát hiện điểm nảy (chuẩn hóa cả hệ Cartesian vật lý và hệ Pixel camera)
    private var lastVerticalVelocity: Float = 0.0
    private var wasMovingDownwardCartesian: Bool = false
    private var wasMovingDownwardCamera: Bool = false
    public var wasMovingDownward: Bool {
        get { wasMovingDownwardCartesian || wasMovingDownwardCamera }
        set {
            wasMovingDownwardCartesian = newValue
            wasMovingDownwardCamera = newValue
        }
    }
    
    public init() {}
    
    // MARK: - Main Tracking Method
    
    /// Cập nhật luồng video, tìm quả bóng, khớp quỹ đạo parabol và nhận diện điểm nảy (Bounce)
    public func update(
        with pixelBuffer: CVPixelBuffer,
        timestamp: TimeInterval,
        homography: simd_float3x3
    ) -> BallObservation? {
        defer {
            // Cập nhật bộ đệm frame
            previousBuffer2 = previousBuffer1
            previousBuffer1 = pixelBuffer
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // 1. Dò tìm ứng viên tâm bóng trên khung hình (kết hợp trừ nền 3 frame và lọc màu neon)
        guard let detectedPixel = detectBallCandidate(
            currentBuffer: pixelBuffer,
            prev1: previousBuffer1,
            prev2: previousBuffer2,
            width: width,
            height: height
        ) else {
            return nil
        }
        
        // 2. Chiếu tọa độ pixel qua ma trận Homography để xác định tọa độ mặt sân
        let u = Float(detectedPixel.x)
        let v = Float(detectedPixel.y)
        let p = SIMD3<Float>(u, v, 1.0)
        let projected = homography * p
        
        guard abs(projected.z) > 1e-7 else { return nil }
        let courtX = projected.x / projected.z
        let courtY = projected.y / projected.z
        
        // 3. Quản lý cửa sổ trượt quỹ đạo
        trajectoryWindow.append((time: timestamp, pixel: detectedPixel, court3D: SIMD3<Float>(courtX, courtY, 0.0)))
        if trajectoryWindow.count > maxWindowSize {
            trajectoryWindow.removeFirst()
        }
        
        // 4. Khớp phương trình Parabol Least-Squares trên trục đứng Y của ảnh
        let parabola = fitParabola(observations: trajectoryWindow)
        
        // 5. Tính toán Vận tốc Tức thời (km/h)
        var speedKmh: Float = 0.0
        if let previous = latestObservation, previous.timestamp > 0 {
            let dt = Float(timestamp - previous.timestamp)
            if dt > 0 && dt < 0.25 {
                let dx = courtX - previous.courtPosition3D.x
                let dy = courtY - previous.courtPosition3D.y
                let distMeters = sqrt(dx * dx + dy * dy)
                
                let rawSpeed = (distMeters / dt) * 3.6
                // Giới hạn vận tốc bóng pickleball vật lý thực tế (<= 130 km/h)
                if rawSpeed <= 130.0 {
                    speedKmh = rawSpeed
                    if speedKmh > peakSpeedKmh {
                        peakSpeedKmh = speedKmh
                    }
                }
            }
        }
        
        // 6. Phát hiện Điểm Nảy (Bounce Detection)
        // Chuẩn hóa quy ước cả 2 hệ quy chiếu:
        // - Hệ Cartesian vật lý (Z/Y hướng lên trời): rơi xuống thì vy < 0, nảy lên thì vy > 0 & accel > 0 (cực tiểu quỹ đạo).
        // - Hệ Pixel camera (Y hướng xuống đất): rơi xuống thì vy > 0, nảy lên thì vy < 0 & accel < 0 (cực đại pixel Y).
        var isBounce = false
        var bounceConfidence: Float = 0.0
        
        if let para = parabola, trajectoryWindow.count >= 4 {
            let currentVy = para.derivative(at: timestamp)
            let currentAccel = para.secondDerivative
            
            // 1. Kiểm tra theo hệ Cartesian vật lý (vy đổi dấu từ âm sang dương, gia tốc dương)
            let isCartesianBounce = wasMovingDownwardCartesian && currentVy > 0.0 && currentAccel > 0.0
            
            // 2. Kiểm tra theo hệ Pixel camera (vy đổi dấu từ dương sang âm, gia tốc âm)
            let isCameraBounce = wasMovingDownwardCamera && currentVy < 0.0 && currentAccel < 0.0
            
            if isCartesianBounce || isCameraBounce {
                isBounce = true
                let accelMagnitude = abs(currentAccel)
                bounceConfidence = min(1.0, accelMagnitude / 50.0 + 0.5)
            }
            
            wasMovingDownwardCartesian = (currentVy < 0.0)
            wasMovingDownwardCamera = (currentVy > 0.0)
            lastVerticalVelocity = currentVy
        }
        
        // 7. Tạo quan sát bóng hoàn chỉnh
        let court3D = SIMD3<Float>(courtX, courtY, 0.0)
        let observation = BallObservation(
            position2D: detectedPixel,
            courtPosition3D: court3D,
            velocityKmh: speedKmh,
            isBounce: isBounce,
            bounceConfidence: bounceConfidence,
            timestamp: timestamp
        )
        
        self.latestObservation = observation
        self.recentObservations.append(observation)
        if recentObservations.count > 30 {
            recentObservations.removeFirst()
        }
        
        // Lưu vết quỹ đạo trên sân 2D (minimap)
        self.trajectoryTrailCourt.append(CGPoint(x: CGFloat(courtX), y: CGFloat(courtY)))
        if trajectoryTrailCourt.count > 25 {
            trajectoryTrailCourt.removeFirst()
        }
        
        return observation
    }
    
    // MARK: - Phát Hiện Quả Bóng (Trừ Nền 3 Frame + Lọc Màu HSV Neon)
    
    private func detectBallCandidate(
        currentBuffer: CVPixelBuffer,
        prev1: CVPixelBuffer?,
        prev2: CVPixelBuffer?,
        width: Int,
        height: Int
    ) -> CGPoint? {
        CVPixelBufferLockBaseAddress(currentBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(currentBuffer, .readOnly) }
        
        guard let currBase = CVPixelBufferGetBaseAddress(currentBuffer) else {
            return nil
        }
        let currPtr = currBase.assumingMemoryBound(to: UInt8.self)
        
        var prev1Ptr: UnsafePointer<UInt8>? = nil
        if let p1 = prev1 {
            CVPixelBufferLockBaseAddress(p1, .readOnly)
            if let p1Base = CVPixelBufferGetBaseAddress(p1) {
                prev1Ptr = UnsafePointer(p1Base.assumingMemoryBound(to: UInt8.self))
            }
        }
        defer {
            if let p1 = prev1 { CVPixelBufferUnlockBaseAddress(p1, .readOnly) }
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(currentBuffer)
        
        // Quét lấy mẫu pixel tìm blob màu vàng neon di chuyển
        var sumX: Int = 0
        var sumY: Int = 0
        var candidatePixelCount: Int = 0
        
        let step = 3 // Quét cách 3 pixel
        let startY = height / 5 // Bỏ qua phần trần nhà / khán đài trên cùng
        let endY = height - 20
        
        for y in stride(from: startY, to: endY, by: step) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: 20, to: width - 20, by: step) {
                let pixelOffset = rowOffset + x * 4
                
                let b = Float(currPtr[pixelOffset])
                let g = Float(currPtr[pixelOffset + 1])
                let r = Float(currPtr[pixelOffset + 2])
                
                // Kiểm tra màu vàng chanh/neon của quả bóng Pickleball:
                // R cao (> 140), G rất cao (> 160), B thấp hơn nhiều so với G (G - B > 50)
                guard r > 130 && g > 150 && (g - b) > 40 else { continue }
                
                // Kiểm tra vi sai chuyển động nếu có frame trước
                if let p1 = prev1Ptr {
                    let prevB = Float(p1[pixelOffset])
                    let prevG = Float(p1[pixelOffset + 1])
                    let prevR = Float(p1[pixelOffset + 2])
                    let diff = abs(r - prevR) + abs(g - prevG) + abs(b - prevB)
                    // Pixel phải có chuyển động
                    guard diff > 25.0 else { continue }
                }
                
                sumX += x
                sumY += y
                candidatePixelCount += 1
            }
        }
        
        // Cần có tối thiểu một cụm pixel (khoảng 3..150 pixel khi lấy mẫu step=3)
        guard candidatePixelCount >= 2 && candidatePixelCount <= 300 else {
            // Không thấy bóng hoặc vùng quá lớn (cầu thủ mặc áo vàng)
            return nil
        }
        
        let centerX = CGFloat(sumX) / CGFloat(candidatePixelCount)
        let centerY = CGFloat(sumY) / CGFloat(candidatePixelCount)
        return CGPoint(x: centerX, y: centerY)
    }
    
    // MARK: - Khớp Phương Trình Parabol Least-Squares
    
    /// Khớp đa thức bậc 2: y(t) = a * dt^2 + b * dt + c
    public func fitParabola(
        observations: [(time: Double, pixel: CGPoint, court3D: SIMD3<Float>)]
    ) -> ParabolaCoefficients? {
        let n = observations.count
        guard n >= 3 else { return nil }
        
        let t0 = observations[0].time
        
        // Hệ phương trình chuẩn tắc:
        // [ sum(t^4)  sum(t^3)  sum(t^2) ] [ a ]   [ sum(t^2 * y) ]
        // [ sum(t^3)  sum(t^2)  sum(t)   ] [ b ] = [ sum(t * y)   ]
        // [ sum(t^2)  sum(t)    n        ] [ c ]   [ sum(y)       ]
        var s4: Float = 0.0
        var s3: Float = 0.0
        var s2: Float = 0.0
        var s1: Float = 0.0
        let s0: Float = Float(n)
        
        var sy: Float = 0.0
        var sty: Float = 0.0
        var st2y: Float = 0.0
        
        for obs in observations {
            let dt = Float(obs.time - t0)
            let y = Float(obs.pixel.y)
            
            let dt2 = dt * dt
            let dt3 = dt2 * dt
            let dt4 = dt3 * dt
            
            s4 += dt4
            s3 += dt3
            s2 += dt2
            s1 += dt
            
            sy += y
            sty += dt * y
            st2y += dt2 * y
        }
        
        let aMatrix = simd_float3x3(rows: [
            SIMD3<Float>(s4, s3, s2),
            SIMD3<Float>(s3, s2, s1),
            SIMD3<Float>(s2, s1, s0)
        ])
        
        let bVector = SIMD3<Float>(st2y, sty, sy)
        let invA = aMatrix.inverse
        
        // Kiểm tra nghiệm hợp lệ
        guard !invA.columns.0.x.isNaN && !invA.columns.1.y.isNaN else { return nil }
        let coeffs = invA * bVector
        
        return ParabolaCoefficients(a: coeffs.x, b: coeffs.y, c: coeffs.z, timeOffset: t0)
    }
    
    // MARK: - Reset State
    
    public func reset() {
        self.latestObservation = nil
        self.recentObservations.removeAll()
        self.trajectoryTrailCourt.removeAll()
        self.trajectoryWindow.removeAll()
        self.previousBuffer1 = nil
        self.previousBuffer2 = nil
        self.lastVerticalVelocity = 0.0
        self.wasMovingDownwardCartesian = false
        self.wasMovingDownwardCamera = false
        self.peakSpeedKmh = 0.0
    }
}
