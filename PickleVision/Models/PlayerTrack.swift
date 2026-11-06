//
//  PlayerTrack.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  Player Tracking Model with 2D Metric Kalman Filter and Motion Telemetry.
//

import Foundation
import CoreGraphics
import simd

/// Định danh đội của người chơi
public enum PlayerTeam: String, Codable, CaseIterable {
    case nearTeam = "Đội Gần (Near)"
    case farTeam  = "Đội Xa (Far)"
}

/// Mức độ cường độ vận động của cầu thủ
public enum WorkoutIntensityLevel: String, Codable {
    case resting    = "Nghỉ ngơi"
    case light      = "Nhẹ"
    case moderate   = "Vừa phải"
    case vigorous   = "Cường độ cao"
    case peak       = "Đỉnh cao"
}

// MARK: - Bộ Lọc Kalman 2D Cho Tọa Độ Mặt Sân Thực Tế (Metric Space)

/// Bộ lọc Kalman Filter 2D cho vị trí sân thực tế (Constant Velocity Model)
/// State vector: x = [X, Y, vX, vY]^T (mét và mét/giây)
public final class KalmanFilter2D {
    // Trạng thái hiện tại: [x, y, vx, vy]
    private var state: SIMD4<Double>
    
    // Ma trận hiệp phương sai sai số P (4x4)
    private var P: [Double]
    
    // Nhiễu quá trình Q và Nhiễu đo lường R
    private let processNoise: Double
    private let measurementNoise: Double
    
    public init(initialPosition: CGPoint, processNoise: Double = 0.5, measurementNoise: Double = 0.1) {
        self.state = SIMD4<Double>(Double(initialPosition.x), Double(initialPosition.y), 0.0, 0.0)
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
        
        // Khởi tạo ma trận P đơn vị với độ tin cậy ban đầu
        self.P = [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 5.0, 0.0,
            0.0, 0.0, 0.0, 5.0
        ]
    }
    
    /// Bước Dự đoán (Predict step) theo khoảng thời gian dt (giây)
    public func predict(dt: Double) -> CGPoint {
        guard dt > 0 else { return CGPoint(x: state.x, y: state.y) }
        
        // 1. x_pred = F * x
        let xNew = state.x + state.z * dt
        let yNew = state.y + state.w * dt
        let vxNew = state.z
        let vyNew = state.w
        state = SIMD4<Double>(xNew, yNew, vxNew, vyNew)
        
        // 2. P_pred = F * P * F^T + Q
        // F = [[1, 0, dt, 0],
        //      [0, 1, 0, dt],
        //      [0, 0, 1,  0],
        //      [0, 0, 0,  1]]
        let qVal = processNoise * dt
        var newP = P
        
        newP[0] += dt * (P[8] + P[2]) + dt * dt * P[10] + qVal
        newP[1] += dt * (P[9] + P[3]) + dt * dt * P[11]
        newP[4] += dt * (P[8] + P[6]) + dt * dt * P[10]
        newP[5] += dt * (P[9] + P[7]) + dt * dt * P[11] + qVal
        newP[10] += qVal * 2.0
        newP[15] += qVal * 2.0
        
        P = newP
        return CGPoint(x: state.x, y: state.y)
    }
    
    /// Bước Cập nhật đo lường (Update step) với tọa độ quan sát (zX, zY)
    public func update(measurement: CGPoint) -> CGPoint {
        let z = SIMD2<Double>(Double(measurement.x), Double(measurement.y))
        
        // Sai số đo lường (Innovation): y = z - H * x
        let y = SIMD2<Double>(z.x - state.x, z.y - state.y)
        
        // S = H * P * H^T + R (2x2)
        let s00 = P[0] + measurementNoise
        let s01 = P[1]
        let s10 = P[4]
        let s11 = P[5] + measurementNoise
        
        // Nghịch đảo S: inv(S)
        let detS = s00 * s11 - s01 * s10
        let invDet = abs(detS) > 1e-9 ? (1.0 / detS) : 1.0
        let invS00 =  s11 * invDet
        let invS01 = -s01 * invDet
        let invS10 = -s10 * invDet
        let invS11 =  s00 * invDet
        
        // Kalman Gain: K = P * H^T * inv(S) (4x2)
        // H = [[1, 0, 0, 0], [0, 1, 0, 0]] -> H^T là 2 cột đầu của P
        let k00 = P[0] * invS00 + P[1] * invS10
        let k01 = P[0] * invS01 + P[1] * invS11
        let k10 = P[4] * invS00 + P[5] * invS10
        let k11 = P[4] * invS01 + P[5] * invS11
        let k20 = P[8] * invS00 + P[9] * invS10
        let k21 = P[8] * invS01 + P[9] * invS11
        let k30 = P[12] * invS00 + P[13] * invS10
        let k31 = P[12] * invS01 + P[13] * invS11
        
        // Cập nhật trạng thái: x = x + K * y
        let updatedX  = state.x + (k00 * y.x + k01 * y.y)
        let updatedY  = state.y + (k10 * y.x + k11 * y.y)
        let updatedVx = state.z + (k20 * y.x + k21 * y.y)
        let updatedVy = state.w + (k30 * y.x + k31 * y.y)
        state = SIMD4<Double>(updatedX, updatedY, updatedVx, updatedVy)
        
        // Cập nhật ma trận P: P = (I - K * H) * P
        let p0 = P[0] - (k00 * P[0] + k01 * P[4])
        let p5 = P[5] - (k10 * P[1] + k11 * P[5])
        let p10 = P[10] - (k20 * P[2] + k21 * P[6])
        let p15 = P[15] - (k30 * P[3] + k31 * P[7])
        
        P[0] = max(p0, 1e-4)
        P[5] = max(p5, 1e-4)
        P[10] = max(p10, 1e-4)
        P[15] = max(p15, 1e-4)
        
        return CGPoint(x: state.x, y: state.y)
    }
    
    public var currentPosition: CGPoint {
        return CGPoint(x: state.x, y: state.y)
    }
    
    public var currentVelocity: SIMD2<Double> {
        return SIMD2<Double>(state.z, state.w)
    }
    
    public var speedMps: Double {
        return sqrt(state.z * state.z + state.w * state.w)
    }
    
    public func reset(to position: CGPoint) {
        state = SIMD4<Double>(Double(position.x), Double(position.y), 0.0, 0.0)
    }
    
    /// Triệt tiêu vận tốc ngoại suy khi cầu thủ đứng yên (Deadband filter chống Velocity Overshoot)
    public func suppressVelocity() {
        state = SIMD4<Double>(state.x, state.y, 0.0, 0.0)
    }
}

// MARK: - Cấu Trúc PlayerTrack

/// Đại diện cho một cầu thủ được bám vết trên sân
public final class PlayerTrack: Identifiable, ObservableObject {
    public let id: UUID
    public var playerIndex: Int
    public var name: String
    public var team: PlayerTeam
    
    // Tọa độ trên sân thực tế tính bằng mét (Court Metric Coordinates)
    @Published public var currentCourtPosition: CGPoint
    @Published public var smoothedCourtPosition: CGPoint
    
    // Tọa độ trên khung hình camera (Screen Coordinates)
    public var screenBoundingBox: CGRect
    public var ankleLeft: CGPoint?
    public var ankleRight: CGPoint?
    public var groundPosition: CGPoint // Trung điểm 2 cổ chân trên ảnh
    
    // Đặc trưng nhận diện Re-ID (Biểu đồ màu HSV của áo)
    public var jerseyColorHistogram: [Float]
    
    // Chỉ số vận động thể chất
    @Published public var speedMps: Float = 0.0
    @Published public var rallyDistanceMeters: Float = 0.0
    @Published public var totalMatchDistanceMeters: Float = 0.0
    @Published public var workoutIntensity: Float = 0.0 // Từ 0.0 đến 1.0
    
    public var confidence: Float = 1.0
    public var isTracking: Bool = true
    public var lastUpdateTime: TimeInterval = 0.0
    
    // Bộ lọc Kalman 2D tích hợp
    public let kalmanFilter: KalmanFilter2D
    
    public init(
        id: UUID = UUID(),
        playerIndex: Int,
        name: String,
        team: PlayerTeam,
        initialCourtPosition: CGPoint,
        screenBoundingBox: CGRect = .zero,
        jerseyColorHistogram: [Float] = []
    ) {
        self.id = id
        self.playerIndex = playerIndex
        self.name = name
        self.team = team
        self.currentCourtPosition = initialCourtPosition
        self.smoothedCourtPosition = initialCourtPosition
        self.screenBoundingBox = screenBoundingBox
        self.groundPosition = CGPoint(x: screenBoundingBox.midX, y: screenBoundingBox.maxY)
        self.jerseyColorHistogram = jerseyColorHistogram
        self.kalmanFilter = KalmanFilter2D(initialPosition: initialCourtPosition)
    }
    
    public var speedKmh: Float {
        return speedMps * 3.6
    }
    
    public var intensityLevel: WorkoutIntensityLevel {
        switch workoutIntensity {
        case ..<0.2:  return .resting
        case ..<0.4:  return .light
        case ..<0.7:  return .moderate
        case ..<0.9:  return .vigorous
        default:      return .peak
        }
    }
    
    // MARK: - Cập Nhật Vị Trí & Tích Lũy Quãng Đường
    
    /// Cập nhật tọa độ phát hiện mới, lọc rung lắc Jitter và cập nhật quãng đường
    public func update(
        rawCourtPosition: CGPoint,
        timestamp: TimeInterval,
        boundingBox: CGRect,
        leftAnkle: CGPoint?,
        rightAnkle: CGPoint?,
        colorHistogram: [Float] = []
    ) {
        let dt = lastUpdateTime > 0 ? (timestamp - lastUpdateTime) : (1.0 / 60.0)
        lastUpdateTime = timestamp
        
        self.screenBoundingBox = boundingBox
        self.ankleLeft = leftAnkle
        self.ankleRight = rightAnkle
        
        // Cập nhật vị trí tiếp đất trên màn hình
        if let l = leftAnkle, let r = rightAnkle {
            self.groundPosition = CGPoint(x: (l.x + r.x) / 2.0, y: (l.y + r.y) / 2.0)
        } else if let l = leftAnkle {
            self.groundPosition = l
        } else if let r = rightAnkle {
            self.groundPosition = r
        } else {
            self.groundPosition = CGPoint(x: boundingBox.midX, y: boundingBox.maxY)
        }
        
        // Cập nhật đặc trưng màu áo Re-ID nếu có
        if !colorHistogram.isEmpty {
            self.jerseyColorHistogram = colorHistogram
        }
        
        // 1. Tính toán độ dịch chuyển thô và vận tốc bước nhảy tức thời trước khi cập nhật bộ lọc (Pre-Gating)
        let rawDx = rawCourtPosition.x - smoothedCourtPosition.x
        let rawDy = rawCourtPosition.y - smoothedCourtPosition.y
        let rawDeltaDistance = Float(sqrt(rawDx * rawDx + rawDy * rawDy))
        let rawInstantSpeed = dt > 0 ? (rawDeltaDistance / Float(dt)) : 0.0
        
        // 2. Pre-Gating: Loại bỏ bước nhảy lỗi phi sinh lý (Teleportation Glitch > 10.5 m/s, tương đương ~38 km/h)
        // Bỏ qua cập nhật đo lường vào Kalman, chỉ chạy predict quán tính để bảo toàn trạng thái,
        // ngăn chặn triệt để hiện tượng ô nhiễm Kalman và tê liệt bám vết (Post-Glitch Tracking Paralysis).
        if rawInstantSpeed > 10.5 {
            _ = kalmanFilter.predict(dt: dt)
            self.speedMps = 0.0
            let normalizedSpeed = min(1.0, speedMps / 7.5)
            self.workoutIntensity = 0.8 * self.workoutIntensity + 0.2 * normalizedSpeed
            self.isTracking = true
            return
        }
        
        // 3. Bộ lọc Deadband / Jitter: Bỏ qua biến thiên dưới 0.05 mét (5cm)
        // Khi cầu thủ đứng yên: Khóa vị trí và triệt tiêu vận tốc ngoại suy của Kalman (Velocity Overshoot Suppression)
        if rawDeltaDistance < 0.05 {
            kalmanFilter.suppressVelocity()
            self.speedMps = 0.0
            let normalizedSpeed = min(1.0, speedMps / 7.5)
            self.workoutIntensity = 0.8 * self.workoutIntensity + 0.2 * normalizedSpeed
            self.isTracking = true
            return
        }
        
        // 4. Bước nhảy hợp lệ: Cập nhật Kalman Filter và tích lũy quãng đường thực
        _ = kalmanFilter.predict(dt: dt)
        let filteredPos = kalmanFilter.update(measurement: rawCourtPosition)
        
        let dx = filteredPos.x - smoothedCourtPosition.x
        let dy = filteredPos.y - smoothedCourtPosition.y
        let deltaDistance = Float(sqrt(dx * dx + dy * dy))
        let instantSpeed = dt > 0 ? (deltaDistance / Float(dt)) : 0.0
        
        self.smoothedCourtPosition = filteredPos
        self.currentCourtPosition = rawCourtPosition
        self.rallyDistanceMeters += deltaDistance
        self.totalMatchDistanceMeters += deltaDistance
        self.speedMps = instantSpeed
        
        // 5. Tính toán chỉ số cường độ vận động (Workout Intensity: 0.0 - 1.0)
        let normalizedSpeed = min(1.0, speedMps / 7.5)
        self.workoutIntensity = 0.8 * self.workoutIntensity + 0.2 * normalizedSpeed
        self.isTracking = true
    }
    
    /// Reset quãng đường của pha bóng hiện tại (khi bắt đầu lượt giao bóng mới)
    public func resetRallyDistance() {
        self.rallyDistanceMeters = 0.0
        self.speedMps = 0.0
        self.workoutIntensity = max(0.0, self.workoutIntensity * 0.5)
    }
    
    /// Reset toàn bộ chỉ số cả trận (khi bắt đầu trận đấu mới)
    public func resetMatchMetrics() {
        self.rallyDistanceMeters = 0.0
        self.totalMatchDistanceMeters = 0.0
        self.speedMps = 0.0
        self.workoutIntensity = 0.0
    }
}
