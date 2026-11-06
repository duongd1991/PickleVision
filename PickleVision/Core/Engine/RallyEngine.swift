//
//  RallyEngine.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  Rally State Machine, Side-Out Scoring Engine, Shot Exchanges, and Distance Accumulation.
//

import Foundation
import CoreGraphics
import Combine

/// Interface protocol cho RallyEngine
public protocol RallyEngineProtocol: ObservableObject {
    var state: RallyState { get }
    var telemetry: RallyTelemetry { get }
    var currentServeNumber: Int { get }
    func handleBallBounce(at courtPoint: CGPoint, isServe: Bool) -> InOutVerdict
    func recordPlayerMovement(playerId: UUID, deltaDistance: Float)
    func startRally()
    func endRally(verdict: InOutVerdict)
    func resetMatch()
}

/// Động cơ quản lý pha bóng và tính điểm thể thức USA Pickleball
public final class RallyEngine: RallyEngineProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var state: RallyState = .waitingForServe
    @Published public private(set) var telemetry: RallyTelemetry = RallyTelemetry()
    @Published public private(set) var currentScore: MatchScore = MatchScore()
    
    public var currentServeNumber: Int {
        return currentScore.serverNumber
    }
    
    // MARK: - Internal Rally State Tracking
    
    private var rallyStartTime: TimeInterval = 0.0
    private var rallyEndTime: TimeInterval = 0.0
    private var cumulativePlayTime: TimeInterval = 0.0
    
    private var rallyIndex: Int = 1
    private var shotCount: Int = 0
    private var consecutiveBouncesInSameSide: Int = 0
    private var lastBounceIsNearSide: Bool?
    
    // Lưu trữ quãng đường di chuyển của từng cầu thủ
    private var playerDistancesRally: [UUID: Float] = [:]
    private var playerDistancesTotal: [UUID: Float] = [:]
    
    // Cấu hình thể thức thi đấu (mặc định đánh đôi side-out)
    public var isDoublesMatch: Bool = true
    
    // MARK: - Initialization
    
    public init(isDoubles: Bool = true) {
        self.isDoublesMatch = isDoubles
        self.currentScore = MatchScore(
            servingTeamScore: 0,
            receivingTeamScore: 0,
            serverNumber: isDoubles ? 2 : 1, // Đánh đôi bắt đầu ở 0-0-2
            isDoubles: isDoubles,
            servingTeam: .nearTeam
        )
        refreshTelemetry()
    }
    
    // MARK: - Rally Lifecycle & State Transitions
    
    /// Bắt đầu một pha bóng mới (người giao bóng vung vợt)
    public func startRally() {
        guard state == .waitingForServe else { return }
        let now = ProcessInfo.processInfo.systemUptime
        rallyStartTime = now
        state = .serveInFlight(startTime: now)
        shotCount = 1
        consecutiveBouncesInSameSide = 0
        lastBounceIsNearSide = nil
        playerDistancesRally.removeAll()
        refreshTelemetry()
    }
    
    /// Xử lý sự kiện bóng nảy trên mặt sân
    public func handleBallBounce(at courtPoint: CGPoint, isServe: Bool) -> InOutVerdict {
        let now = ProcessInfo.processInfo.systemUptime
        let x = Double(courtPoint.x)
        let y = Double(courtPoint.y)
        let r = CourtDimensions.ballRadius
        
        // 1. Kiểm tra rơi ngoài toàn bộ sân
        if x < -r || x > (CourtDimensions.width + r) || y < -r || y > (CourtDimensions.length + r) {
            return .outOfBound
        }
        
        // 2. Kiểm tra nếu là cú giao bóng
        if isServe {
            // Nếu giao sang sân xa mà chạm vạch bếp hoặc rơi vào bếp
            if y > CourtDimensions.netY && y <= (CourtDimensions.farNVZY + r) {
                return .faultKitchenServe
            }
            // Nếu giao sang sân gần mà chạm vạch bếp hoặc rơi vào bếp
            if y < CourtDimensions.netY && y >= (CourtDimensions.nearNVZY - r) {
                return .faultKitchenServe
            }
            
            // Giao bóng hợp lệ -> chuyển trạng thái sang inProgress
            if case .serveInFlight = state {
                state = .inProgress(startTime: rallyStartTime)
            }
            consecutiveBouncesInSameSide = 1
            lastBounceIsNearSide = (y < CourtDimensions.netY)
            refreshTelemetry()
            return .inBound
        }
        
        // 3. Trong pha bóng sống (Live Rally):
        if case .inProgress = state {
            let isNearSide = (y < CourtDimensions.netY)
            
            // Kiểm tra lỗi bóng nảy 2 lần trên cùng một nửa sân (Double Bounce)
            if let lastSide = lastBounceIsNearSide, lastSide == isNearSide {
                consecutiveBouncesInSameSide += 1
                if consecutiveBouncesInSameSide >= 2 {
                    return .twoBounceFault
                }
            } else {
                consecutiveBouncesInSameSide = 1
                lastBounceIsNearSide = isNearSide
            }
        }
        
        refreshTelemetry()
        return .inBound
    }
    
    /// Ghi nhận một cú đánh bóng đổi hướng qua lưới (Shot Exchange)
    public func registerShotExchange() {
        guard case .inProgress = state else { return }
        shotCount += 1
        consecutiveBouncesInSameSide = 0
        refreshTelemetry()
    }
    
    /// Kết thúc pha bóng với phán quyết cụ thể
    public func endRally(verdict: InOutVerdict) {
        guard state.isLive else { return }
        let now = ProcessInfo.processInfo.systemUptime
        rallyEndTime = now
        let duration = max(0.0, now - rallyStartTime)
        cumulativePlayTime += duration
        
        let reason: RallyEndReason
        switch verdict {
        case .outOfBound:
            reason = .ballOut
        case .faultKitchenServe:
            reason = .kitchenFaultServe
        case .twoBounceFault:
            reason = .doubleBounce
        case .netFault:
            reason = .netFault
        case .kitchenVolleyFault:
            reason = .kitchenVolleyFault
        case .inBound:
            reason = .manualStop
        }
        
        state = .ended(reason: reason, endedTime: now)
        
        // Cập nhật điểm số theo thể thức Side-out
        applyScoring(verdict: verdict)
        refreshTelemetry()
    }
    
    /// Chuẩn bị cho pha giao bóng tiếp theo
    public func prepareNextRally() {
        guard case .ended = state else { return }
        rallyIndex += 1
        shotCount = 0
        consecutiveBouncesInSameSide = 0
        lastBounceIsNearSide = nil
        state = .waitingForServe
        refreshTelemetry()
    }
    
    // MARK: - USA Pickleball Side-Out Scoring Engine
    
    /// Tính toán điểm số theo thể thức chính thức
    private func applyScoring(verdict: InOutVerdict) {
        // Xác định đội giao bóng có thắng pha hay không
        // Giả sử nếu pha kết thúc do lỗi của đối thủ -> Đội giao thắng
        // Nếu pha kết thúc do đội giao bóng đánh hỏng (Out, vướng lưới, lỗi bếp khi giao) -> Đội giao thua
        let servingTeamWon = (verdict == .inBound || verdict == .twoBounceFault)
        
        if isDoublesMatch {
            if servingTeamWon {
                // Đội giao ghi 1 điểm
                currentScore.servingTeamScore += 1
                // Người giao tiếp tục giao, đổi ô đứng
            } else {
                // Đội giao thua pha bóng
                if currentScore.serverNumber == 1 {
                    // Chuyển sang người giao bóng số 2 của đội
                    currentScore.serverNumber = 2
                } else {
                    // Mất lượt giao bóng cả 2 người -> Side-Out sang đội đối phương!
                    let oldServing = currentScore.servingTeamScore
                    let oldReceiving = currentScore.receivingTeamScore
                    
                    currentScore.servingTeamScore = oldReceiving
                    currentScore.receivingTeamScore = oldServing
                    currentScore.serverNumber = 1
                    currentScore.servingTeam = (currentScore.servingTeam == .nearTeam) ? .farTeam : .nearTeam
                }
            }
        } else {
            // Đánh đơn (Singles)
            if servingTeamWon {
                currentScore.servingTeamScore += 1
            } else {
                // Side-Out sang đối thủ
                let oldServing = currentScore.servingTeamScore
                let oldReceiving = currentScore.receivingTeamScore
                
                currentScore.servingTeamScore = oldReceiving
                currentScore.receivingTeamScore = oldServing
                currentScore.serverNumber = 1
                currentScore.servingTeam = (currentScore.servingTeam == .nearTeam) ? .farTeam : .nearTeam
            }
        }
    }
    
    // MARK: - Distance Tracking
    
    /// Ghi nhận quãng đường di chuyển của một cầu thủ
    public func recordPlayerMovement(playerId: UUID, deltaDistance: Float) {
        guard deltaDistance >= 0.05 else { return } // Lọc jitter
        
        playerDistancesRally[playerId, default: 0.0] += deltaDistance
        playerDistancesTotal[playerId, default: 0.0] += deltaDistance
        refreshTelemetry()
    }
    
    // MARK: - Match Reset
    
    /// Reset toàn bộ trận đấu về trạng thái khởi đầu
    public func resetMatch() {
        rallyIndex = 1
        shotCount = 0
        rallyStartTime = 0.0
        rallyEndTime = 0.0
        cumulativePlayTime = 0.0
        consecutiveBouncesInSameSide = 0
        lastBounceIsNearSide = nil
        playerDistancesRally.removeAll()
        playerDistancesTotal.removeAll()
        
        currentScore = MatchScore(
            servingTeamScore: 0,
            receivingTeamScore: 0,
            serverNumber: isDoublesMatch ? 2 : 1,
            isDoubles: isDoublesMatch,
            servingTeam: .nearTeam
        )
        state = .waitingForServe
        refreshTelemetry()
    }
    
    // MARK: - Telemetry Synchronization
    
    private func refreshTelemetry() {
        let currentDuration: TimeInterval
        if state.isLive {
            currentDuration = max(0.0, ProcessInfo.processInfo.systemUptime - rallyStartTime)
        } else if case .ended(_, let endedTime) = state {
            currentDuration = max(0.0, endedTime - rallyStartTime)
        } else {
            currentDuration = 0.0
        }
        
        telemetry = RallyTelemetry(
            rallyIndex: rallyIndex,
            rallyDuration: currentDuration,
            shotCount: shotCount,
            effectivePlayTime: cumulativePlayTime,
            state: state,
            currentScore: currentScore,
            serverIndex: currentScore.serverNumber,
            peakBallSpeedKmh: 0.0,
            currentBallSpeedKmh: 0.0,
            lastBallObservation: nil,
            lastBounce: nil,
            latestVerdict: nil,
            players: [],
            trajectoryTailCourt: []
        )
    }
}
