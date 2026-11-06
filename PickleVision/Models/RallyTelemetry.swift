//
//  RallyTelemetry.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  Rally Telemetry, State Machine Enums, In/Out Verdicts, and Match Telemetry Streams.
//

import Foundation
import CoreGraphics
import simd

/// Lý do kết thúc của một pha bóng
public enum RallyEndReason: String, Codable, CaseIterable {
    case ballOut            = "Bóng Ra Ngoài Sân (OUT)"
    case kitchenFaultServe  = "Lỗi Giao Bóng Vào Bếp (NVZ Fault)"
    case doubleBounce       = "Bóng Nảy Hai Lần (Double Bounce)"
    case netFault           = "Bóng Vướng Lưới (Net Fault)"
    case twoBounceFault     = "Phạm Luật 2 Lần Nảy (Two-Bounce Violation)"
    case kitchenVolleyFault = "Lỗi Vô-lê Trong Bếp (Kitchen Volley Fault)"
    case manualStop         = "Trọng Tài Dừng Pha (Manual Stop)"
}

/// Trạng thái của một pha bóng trong máy trạng thái RallyEngine
public enum RallyState: Equatable {
    case waitingForServe
    case serveInFlight(startTime: TimeInterval)
    case inProgress(startTime: TimeInterval)
    case ended(reason: RallyEndReason, endedTime: TimeInterval)
    
    public var displayText: String {
        switch self {
        case .waitingForServe:
            return "CHỜ GIAO BÓNG"
        case .serveInFlight:
            return "GIAO BÓNG ĐANG BAY"
        case .inProgress:
            return "ĐANG ĐÁNH"
        case .ended(let reason, _):
            return "KẾT THÚC (\(reason.rawValue))"
        }
    }
    
    public var isLive: Bool {
        switch self {
        case .serveInFlight, .inProgress:
            return true
        case .waitingForServe, .ended:
            return false
        }
    }
    
    public var isServing: Bool {
        switch self {
        case .waitingForServe, .serveInFlight:
            return true
        default:
            return false
        }
    }
}

/// Phán quyết tính điểm của trọng tài máy (Hawk-Eye / VAR)
public enum InOutVerdict: String, Codable, CaseIterable {
    case inBound            = "IN"
    case faultKitchenServe  = "FAULT (GIAO BÓNG VÀO BẾP)"
    case outOfBound         = "OUT"
    case netFault           = "NET (VƯỚNG LƯỚI)"
    case twoBounceFault     = "FAULT (LỖI HAI LẦN NẢY)"
    case kitchenVolleyFault = "FAULT (VÔ-LÊ TRONG BẾP)"
    
    public var isFaultOrOut: Bool {
        return self != .inBound
    }
}

/// Dữ liệu quan sát vị trí và động học của quả bóng
public struct BallObservation: Codable, Equatable {
    /// Tọa độ 2D trên khung hình camera (u, v pixel)
    public var position2D: CGPoint
    /// Tọa độ 3D trên sân (X ngang, Y dọc, Z độ cao so với mặt sàn tính bằng mét)
    public var courtPosition3D: SIMD3<Float>
    /// Vận tốc tức thời (km/h)
    public var velocityKmh: Float
    /// Có phải điểm tiếp đất (Bounce) hay không
    public var isBounce: Bool
    /// Độ tin cậy của thuật toán phát hiện điểm nảy (0.0 - 1.0)
    public var bounceConfidence: Float
    /// Thời điểm ghi nhận khung hình
    public var timestamp: TimeInterval
    
    public init(
        position2D: CGPoint,
        courtPosition3D: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
        velocityKmh: Float = 0.0,
        isBounce: Bool = false,
        bounceConfidence: Float = 0.0,
        timestamp: TimeInterval = 0.0
    ) {
        self.position2D = position2D
        self.courtPosition3D = courtPosition3D
        self.velocityKmh = velocityKmh
        self.isBounce = isBounce
        self.bounceConfidence = bounceConfidence
        self.timestamp = timestamp
    }
    
    public var courtPosition2D: CGPoint {
        return CGPoint(x: CGFloat(courtPosition3D.x), y: CGFloat(courtPosition3D.y))
    }
}

/// Tỷ số trận đấu theo thể thức Side-out Scoring của USA Pickleball
public struct MatchScore: Codable, Equatable {
    public var servingTeamScore: Int
    public var receivingTeamScore: Int
    public var serverNumber: Int // 1 hoặc 2 trong đánh đôi; 1 trong đánh đơn
    public var isDoubles: Bool
    public var servingTeam: PlayerTeam
    
    public init(
        servingTeamScore: Int = 0,
        receivingTeamScore: Int = 0,
        serverNumber: Int = 2, // Đánh đôi bắt đầu trận ở 0-0-2
        isDoubles: Bool = true,
        servingTeam: PlayerTeam = .nearTeam
    ) {
        self.servingTeamScore = servingTeamScore
        self.receivingTeamScore = receivingTeamScore
        self.serverNumber = serverNumber
        self.isDoubles = isDoubles
        self.servingTeam = servingTeam
    }
    
    /// Chuỗi hiển thị tỷ số chuẩn (ví dụ "4 - 3 - 1" hoặc "0 - 0 - 2")
    public var displayString: String {
        if isDoubles {
            return "\(servingTeamScore) - \(receivingTeamScore) - \(serverNumber)"
        } else {
            return "\(servingTeamScore) - \(receivingTeamScore)"
        }
    }
}

/// Tóm tắt chỉ số thể lực của cầu thủ cho luồng Telemetry
public struct PlayerRallyMetric: Codable, Equatable, Identifiable {
    public var id: UUID
    public var playerIndex: Int
    public var name: String
    public var team: PlayerTeam
    public var courtPosition: CGPoint
    public var rallyDistanceMeters: Float
    public var totalMatchDistanceMeters: Float
    public var currentSpeedKmh: Float
    public var workoutIntensity: Float
    
    public init(
        id: UUID,
        playerIndex: Int,
        name: String,
        team: PlayerTeam,
        courtPosition: CGPoint,
        rallyDistanceMeters: Float,
        totalMatchDistanceMeters: Float,
        currentSpeedKmh: Float,
        workoutIntensity: Float
    ) {
        self.id = id
        self.playerIndex = playerIndex
        self.name = name
        self.team = team
        self.courtPosition = courtPosition
        self.rallyDistanceMeters = rallyDistanceMeters
        self.totalMatchDistanceMeters = totalMatchDistanceMeters
        self.currentSpeedKmh = currentSpeedKmh
        self.workoutIntensity = workoutIntensity
    }
}

/// Dữ liệu viễn trắc (Telemetry) tổng hợp của trận đấu truyền tới HUD và Metal Overlay
public struct RallyTelemetry: Equatable {
    /// Số thứ tự của pha bóng hiện tại (1, 2, 3...)
    public var rallyIndex: Int
    /// Thời gian diễn ra pha bóng hiện tại (giây)
    public var rallyDuration: TimeInterval
    /// Số lần bóng chạm vợt đổi hướng qua lưới (Shot exchanges)
    public var shotCount: Int
    /// Thời gian chơi bóng thực tế tích lũy cả trận (giây)
    public var effectivePlayTime: TimeInterval
    /// Trạng thái pha bóng
    public var state: RallyState
    /// Tỷ số hiện tại
    public var currentScore: MatchScore
    /// Người giao bóng chỉ định
    public var serverIndex: Int
    
    /// Tốc độ bóng cao nhất trong pha bóng này (km/h)
    public var peakBallSpeedKmh: Float
    /// Tốc độ bóng tức thời hiện tại (km/h)
    public var currentBallSpeedKmh: Float
    
    /// Quan sát bóng mới nhất
    public var lastBallObservation: BallObservation?
    /// Điểm nảy bóng gần nhất
    public var lastBounce: BallObservation?
    /// Phán quyết In/Out mới nhất
    public var latestVerdict: InOutVerdict?
    
    /// Danh sách chỉ số 4 cầu thủ
    public var players: [PlayerRallyMetric]
    /// Chuỗi điểm tọa độ quỹ đạo bay của bóng để vẽ minimap và vệt sáng
    public var trajectoryTailCourt: [CGPoint]
    
    public init(
        rallyIndex: Int = 1,
        rallyDuration: TimeInterval = 0.0,
        shotCount: Int = 0,
        effectivePlayTime: TimeInterval = 0.0,
        state: RallyState = .waitingForServe,
        currentScore: MatchScore = MatchScore(),
        serverIndex: Int = 0,
        peakBallSpeedKmh: Float = 0.0,
        currentBallSpeedKmh: Float = 0.0,
        lastBallObservation: BallObservation? = nil,
        lastBounce: BallObservation? = nil,
        latestVerdict: InOutVerdict? = nil,
        players: [PlayerRallyMetric] = [],
        trajectoryTailCourt: [CGPoint] = []
    ) {
        self.rallyIndex = rallyIndex
        self.rallyDuration = rallyDuration
        self.shotCount = shotCount
        self.effectivePlayTime = effectivePlayTime
        self.state = state
        self.currentScore = currentScore
        self.serverIndex = serverIndex
        self.peakBallSpeedKmh = peakBallSpeedKmh
        self.currentBallSpeedKmh = currentBallSpeedKmh
        self.lastBallObservation = lastBallObservation
        self.lastBounce = lastBounce
        self.latestVerdict = latestVerdict
        self.players = players
        self.trajectoryTailCourt = trajectoryTailCourt
    }
}
